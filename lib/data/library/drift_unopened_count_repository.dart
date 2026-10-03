// Lumen Tale — B48's counting model, derived in SQL and never stored.
//
// `data/` → `core` + `domain` (`02-architecture.md`).
//
// ## The decision this file exists to make true
//
// **There is no `unreadCount` column.** `architecture.md` § 4.7: *a stored count is a
// second source of truth free to disagree with the rows it counts — B14 violated by
// construction.* Every number below comes out of a `COUNT` over rows that are already
// there, so it cannot go stale, cannot need a migration, and cannot survive a table edit
// with the wrong value still sitting in it.
//
// ## Why this is `customSelect` and not drift's query builder
//
// The plan's query is `SUM(CASE WHEN is_read = 0 THEN 1 ELSE 0 END)` inside a group by
// over a `LEFT JOIN`. drift's expression builder has no clean spelling for a conditional
// aggregate — the first attempt fought it for twenty minutes and produced a cast soup
// that nobody could read. **The SQL is the specification here, and the part of the
// specification drift's builder cannot express is exactly the part that matters.** A
// readable query that is right beats an elegant builder call that has to be decoded
// twice; `06-database.md` rule 8 forbids the Dart-side chapter loop, and this is the
// other way of not doing that.
//
// `readsFrom` is what makes `watch()` work: drift must know which tables invalidate the
// result, or a stream would emit once and never again.
//
// ## The four decisions in the query
//
// 1. **`LEFT JOIN`, not `INNER JOIN`.** A library novel whose chapter list has not been
//    fetched yet must appear with `unopened = 0`, not disappear. `novel-details.md` § 8:
//    *the first open fetches the chapter list once*. Before that first fetch the novel is
//    in the library and its count is zero. An `INNER JOIN` would make a novel the reader
//    is keeping invisible because the app has not asked yet — which is B48 missed: the
//    count must be a local fact, and "I have not asked" is not "there are none".
// 2. **`COALESCE(SUM(…), 0)` AND `ELSE 0` inside the `CASE` — and they are
//    redundant with each other.** A `LEFT JOIN` with no match yields one row whose
//    `is_read` is NULL. With `ELSE 0` in the CASE, that row contributes 0 and `SUM`
//    returns 0; without the `ELSE`, `NULL = 0` is NULL and `SUM` returns NULL, which
//    arrives in Dart as `null` rather than `0` — and a nullable counter makes the
//    display a screen's decision, which is exactly what has to be decided here.
//
//    **Both guards are kept and a test that distinguishes them does not exist, because
//    there is nothing to distinguish.** Removing `COALESCE` was tried and every row
//    stayed green; so was removing the `ELSE`. Claiming a test proves `COALESCE` is
//    required would be claiming something false. They are kept as two cheap guards on
//    one property, and the property — `unopened` is `0`, never `null` — is asserted.
// 3. **`is_read = 0`, not `NOT is_read`.** The column is an integer boolean; the test
//    reads the value and does not interpret a negation.
// 4. **A deterministic second sort key.** `updates.md` § 4: *Novels are ordered by
//    unopened count, descending; ties keep library order.* Without the tiebreak two
//    novels with equal counts swap on every rebuild and the list flickers.
//
// ## No clock, no connection flag
//
// Neither appears in [UnopenedCountRepository], and their absence is the design. B38
// (*a check never downloads*) holds because this file has **no path to `queue_items`**,
// and every timestamp is an input, so a fact's freshness is something a caller decided
// rather than something a clock supplied.

import 'package:drift/drift.dart';
import 'package:lumen_tale/core/database/app_database.dart';
import 'package:lumen_tale/domain/library/library_update_fact.dart';

final class DriftUnopenedCountRepository implements UnopenedCountRepository {
  DriftUnopenedCountRepository(this._db);

  final AppDatabase _db;

  @override
  Future<LibraryUpdateFact?> factFor(String novelId) async {
    final List<LibraryUpdateFact> facts = await _select(<Object?>[novelId]);
    return facts.isEmpty ? null : facts.first;
  }

  @override
  Stream<List<LibraryUpdateFact>> watchLibraryFacts() => _db
      .customSelect(
        _countSql(single: false),
        variables: const <Variable<Object>>[Variable<bool>(true)],
        readsFrom: _readsFrom,
      )
      .watch()
      .map((List<QueryRow> rows) => rows.map(_toFact).toList(growable: false));

  @override
  Future<void> markOpened(String chapterId, {required DateTime at}) async {
    final ChapterRow? row = await (_db.select(
      _db.chapters,
    )..where((Chapters t) => t.id.equals(chapterId))).getSingleOrNull();

    // ⚠️ No row: write nothing, create nothing, throw nothing.
    //
    // `markOpened` is called by the reader with the ids of the row they are reading. If
    // the row is missing, the local store is in a state this slice does not repair and
    // must not paper over. Creating a `chapters` row from an id alone would produce a
    // chapter with no url and no ordinal — a row that can neither open nor count
    // correctly. The novel's count stays right either way: the chapter does not exist,
    // so it cannot be unopened.
    if (row == null) return;

    // ⚠️ Already read: write the row, change nothing.
    //
    // `readAt` is *when the chapter became read* — a fact, not a counter. Re-reading is
    // very common, and a `read_at` that moves on every read has lost its only meaning.
    // This is also why the `6-3 → 5-2` edge was removed: a fact that moves on every read
    // is a fact someone will eventually compare against something by accident.
    if (row.isRead) return;

    await (_db.update(_db.chapters)
          ..where((Chapters t) => t.id.equals(chapterId)))
        .write(ChaptersCompanion(isRead: const Value(true), readAt: Value(at)));
  }

  @override
  Future<int> markAllOpened(String novelId, {required DateTime at}) async {
    // ⚠️ `is_read` and `read_at` ONLY. Never `novels.last_checked_at`: a bulk local
    // write is not a check, and B49 says a novel is only ever *checked* when the app
    // looked at its site.
    //
    // `readAt` is `at` for the whole batch, which is one caller-supplied value — a loop
    // would only introduce a per-row clock nobody asked for. Already-read chapters are
    // excluded, so a bulk mark preserves every first-read time, exactly as `markOpened`
    // does.
    return (_db.update(_db.chapters)..where(
          (Chapters t) => t.novelId.equals(novelId) & t.isRead.equals(false),
        ))
        .write(ChaptersCompanion(isRead: const Value(true), readAt: Value(at)));
  }

  /// The derived query. One row per library novel, `LEFT JOIN`ed chapters.
  ///
  /// [args] is empty for "the whole library" or holds one novel id for `factFor`. An
  /// empty argument list and a list holding `null` are **not** the same thing, so the
  /// WHERE clause is assembled from a `Variable` rather than by splicing a string —
  /// splicing an id into SQL text is exactly what `17-security.md` rule 1 forbids, even
  /// when the id currently comes from the database rather than from a reader.
  Future<List<LibraryUpdateFact>> _select(List<Object?> args) => _db
      .customSelect(
        _countSql(single: args.isNotEmpty),
        variables: <Variable<Object>>[
          const Variable<bool>(true),
          if (args.isNotEmpty) Variable<String>(args.single! as String),
        ],
        readsFrom: _readsFrom,
      )
      .map(_toFact)
      .get();

  /// The tables whose change invalidates the count. Instance-level because it needs the
  /// two [TableInfo]s, and `TableInfo` is what `readsFrom` takes.
  late final Set<ResultSetImplementation<dynamic, dynamic>> _readsFrom =
      <ResultSetImplementation<dynamic, dynamic>>{_db.novels, _db.chapters};

  /// The derived count, as SQL.
  ///
  /// One place, read by both `factFor` and `watchLibraryFacts`, because two copies of a
  /// `SUM(CASE …)` are two numbers free to disagree — and the whole point of this slice
  /// is that there is exactly one way to count.
  static String _countSql({required bool single}) =>
      '''
          SELECT n.id                                        AS novel_id,
                 n.last_checked_at                           AS last_checked_at,
                 COUNT(c.id)                                 AS total,
                 COALESCE(SUM(CASE WHEN c.is_read = 0
                                   THEN 1 ELSE 0 END), 0)    AS unopened,
                 COALESCE(SUM(CASE WHEN c.is_read = 0
                                     AND c.downloaded_at IS NOT NULL
                                   THEN 1 ELSE 0 END), 0)    AS unopened_downloaded
          FROM novels n
          LEFT JOIN chapters c ON c.novel_id = n.id
          WHERE n.in_library = ?
            ${single ? 'AND n.id = ?' : ''}
          GROUP BY n.id, n.added_at
          ORDER BY unopened DESC,
                   -- ⚠️ NOT `COALESCE(n.added_at, 0)`. The plan writes that, and
                   -- explains it as "a library novel with no added_at ... must not sort
                   -- first everywhere" — which is the exact opposite of what it does.
                   -- COALESCE maps NULL to the epoch, and the epoch sorts FIRST, so the
                   -- plan's SQL sorts untimestamped novels to the top while claiming to
                   -- prevent it. The boolean puts nulls LAST, which is what the prose
                   -- asked for and what a reader expects from "ties keep library order".
                   (n.added_at IS NULL),
                   n.added_at ASC,
                   n.id ASC
          ''';

  LibraryUpdateFact _toFact(QueryRow row) {
    final DateTime? lastChecked = row.read<DateTime?>('last_checked_at');
    return LibraryUpdateFact(
      novelId: row.read<String>('novel_id'),
      totalCount: row.read<int>('total'),
      unopenedCount: row.read<int>('unopened'),
      downloadedUnopenedCount: row.read<int>('unopened_downloaded'),
      // B49: the verification is a **type** chosen from what is actually known, never a
      // default. `lastCheckedAt == null` is `NeverChecked`, not "epoch 0" — and it is
      // read here, in the repository, so no screen has to decide.
      verification: lastChecked == null
          ? const NeverChecked()
          : CheckedAt(lastChecked.toUtc()),
    );
  }
}
