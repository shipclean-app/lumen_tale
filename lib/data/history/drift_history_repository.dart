// Lumen Tale — B46, rendered as SQL: clearing the journal must not move the reader.
//
// `data/` → `core` + `domain` (`02-architecture.md`).
//
// ## The whole of B46 is the SHAPE of two statements
//
// ```
// clearAll()        DELETE FROM history_entries
// purgeOlderThan(t) DELETE FROM history_entries WHERE opened_at < :cutoff
// ```
//
// No join with `reading_positions`. Not "a join we decided against" — **no join**.
// A join would be readable, reversible, testable, and would still destroy the
// reader's place in a product with no remote copy of anything (C8, ADR-010). The
// absence is the requirement, so the absence is what the code shows.
//
// And [readResumePoints] is the other half: it reads `reading_positions ⋈ chapters ⋈
// novels` and **no row of `history_entries`**. Deriving "last chapter read" from the
// journal is the one implementation that looks reasonable and is wrong — clearing the
// journal would then clear where the reader was, which is the single most destructive
// thing this app could do and the one no test would object to.
//
// ## No `LIMIT`, ever
//
// B47 bounds the journal by **time**. A count bound is what B47 refuses, and it
// punishes the intensive reader — who is this product's user. There is no `limit`
// parameter on [readEntries] and there will not be one: if a screen needs fewer rows
// it builds fewer rows, which is a rendering decision.

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:lumen_tale/core/database/app_database.dart';
import 'package:lumen_tale/domain/history/history_entry.dart';
import 'package:lumen_tale/domain/history/history_repository.dart';
import 'package:lumen_tale/domain/sources/source_id.dart';

final class DriftHistoryRepository implements HistoryRepository {
  DriftHistoryRepository(this._db);

  final AppDatabase _db;

  /// The tables a journal read depends on, so `watch` invalidates on the right ones.
  ///
  /// Instance-level because it needs the `ResultSetImplementation`s, which is what
  /// `readsFrom` takes. `history_entries` is the subject; `novels` and `chapters` are
  /// joined for their **titles**, and a title change must re-render the row — omitting
  /// them is how a stream emits once and never again when a title is edited.
  ///
  /// ⚠️ `readingPositions` is deliberately **absent**: a position change cannot alter a
  /// journal row, because a journal row carries no position (B46). Listing it would
  /// make a scroll write re-query the journal and re-render the list under the
  /// reader's thumb.
  late final Set<ResultSetImplementation<dynamic, dynamic>> _entryReads =
      <ResultSetImplementation<dynamic, dynamic>>{
        _db.historyEntries,
        _db.novels,
        _db.chapters,
      };

  /// ⚠️ Also **no** `historyEntries`: a resume point comes from a position, and tying
  /// the two together is the bug B46 is made of.
  late final Set<ResultSetImplementation<dynamic, dynamic>> _resumeReads =
      <ResultSetImplementation<dynamic, dynamic>>{
        _db.readingPositions,
        _db.chapters,
        _db.novels,
      };

  @override
  Future<List<HistoryEntry>> readEntries({required DateTime cutoff}) async {
    final List<QueryRow> rows = await _db
        .customSelect(
          _entriesSql,
          variables: <Variable<Object>>[Variable<DateTime>(cutoff)],
          readsFrom: _entryReads,
        )
        .get();

    return List<HistoryEntry>.unmodifiable(rows.map(_toEntry));
  }

  @override
  Future<void> recordOpened({
    required String novelId,
    required String chapterId,
    required DateTime openedAt,
  }) async {
    // ⚠️ **No unique key on `(novel_id, chapter_id)`, deliberately.** Re-opening a
    // chapter writes a second line: it is a journal of what was opened, and
    // `history.md` § 4 requires a fresh entry at the new date. B47's window then
    // removes the older of the two first, which is correct rather than a
    // de-duplication bug. Merging them would erase the fact that a reading happened
    // twice.
    //
    // The id is derived from the instant **and** the chapter, not from the chapter
    // alone: two opens in the same millisecond must be two rows, and an id built from
    // `chapter_id` alone would collide on the primary key — turning "reads twice" into
    // "fails the second time".
    await _db
        .into(_db.historyEntries)
        .insert(
          HistoryEntriesCompanion.insert(
            id: _entryId(chapterId: chapterId, openedAt: openedAt),
            novelId: novelId,
            chapterId: chapterId,
            openedAt: openedAt,
          ),
        );
  }

  @override
  Future<int> purgeOlderThan(DateTime cutoff) {
    // ⚠️ ONE statement, one table. See the file header: this shape IS B46.
    //
    // ⚠️ **No `ORDER BY`.** SQLite deletes in one pass and "oldest first" is a
    // *consequence* of the predicate, not an order to write. Adding one would suggest
    // the rows are deleted one at a time, which is not what happens.
    return (_db.delete(
      _db.historyEntries,
    )..where((HistoryEntries h) => h.openedAt.isSmallerThanValue(cutoff))).go();
  }

  @override
  Future<int> clearAll() {
    // ⚠️ THE LINE. No `where`, no join, no reference to `readingPositions`.
    // A test asserts the positions are untouched afterwards; a regression that added a
    // join here would pass every other test in the project.
    return _db.delete(_db.historyEntries).go();
  }

  @override
  Future<List<NovelResumePoint>> readResumePoints() async {
    // B17's second sentence, and the query that keeps "resume where I stopped" working
    // after the reader clears their journal — which is the one action guaranteed to
    // expose a journal-derived implementation.
    final List<QueryRow> rows = await _db
        .customSelect(_resumeSql, readsFrom: _resumeReads)
        .get();

    return List<NovelResumePoint>.unmodifiable(
      rows.map(
        (QueryRow row) => NovelResumePoint(
          novelId: row.read<String>('novel_id'),
          chapterId: row.read<String>('chapter_id'),
          chapterTitle: row.read<String>('chapter_name'),
          offset: row.read<double>('offset'),
          updatedAt: row.read<DateTime>('updated_at'),
        ),
      ),
    );
  }

  /// One entry per reading, joined for the two titles the row displays.
  ///
  /// `LEFT JOIN` on both titles, deliberately: `novel_id` is `RESTRICT` and
  /// `chapter_id` is `CASCADE` **with `PRAGMA foreign_keys = ON`**
  /// (`AppDatabase.forTesting` enforces it per connection), so a row cannot lose its
  /// novel or chapter to a cascade. An inner join would therefore be equivalent today
  /// and would become a **silent row loss** the day foreign keys were ever off.
  static const String _entriesSql = '''
      SELECT h.id                AS id,
             h.novel_id          AS novel_id,
             n.title             AS novel_title,
             h.chapter_id        AS chapter_id,
             c.name              AS chapter_name,
             h.opened_at         AS opened_at
      FROM history_entries h
      LEFT JOIN novels   n ON n.id = h.novel_id
      LEFT JOIN chapters c ON c.id = h.chapter_id
      WHERE h.opened_at >= ?
      ORDER BY h.opened_at DESC
  ''';

  /// ⚠️ **No `history_entries` anywhere in this statement.** That absence is what keeps
  /// "resume where I stopped" independent of the journal, and `6-5` § 3.1 says so
  /// explicitly.
  ///
  /// `updated_at DESC` is the ordering, per B17. There is deliberately no
  /// `tiebreaker`: two positions written in the same millisecond have an indeterminate
  /// relative order and inventing one would be a fact this query does not have.
  static const String _resumeSql = '''
      SELECT n.id            AS novel_id,
             c.id            AS chapter_id,
             c.name          AS chapter_name,
             p.offset        AS offset,
             p.updated_at    AS updated_at
      FROM reading_positions p
      JOIN chapters c ON c.id = p.chapter_id
      JOIN novels   n ON n.id = c.novel_id
      ORDER BY p.updated_at DESC
  ''';

  HistoryEntry _toEntry(QueryRow row) {
    return HistoryEntry(
      id: row.read<String>('id'),
      novelId: row.read<String>('novel_id'),
      // ⚠️ `?? ''` and never a placeholder title: a novel that has gone would render
      // as *Untitled*, which is what `history.md` § 4 asks for, and inventing "Novel"
      // would be a sentence this app never learned.
      novelTitle: row.readNullable<String>('novel_title') ?? '',
      chapterId: row.read<String>('chapter_id'),
      chapterTitle: row.readNullable<String>('chapter_name') ?? '',
      openedAt: row.read<DateTime>('opened_at'),
    );
  }

  /// An id that is unique per **opening**, not per chapter.
  ///
  /// ## The resolution here is the SECOND, and that is not a choice
  ///
  /// `opened_at` is a `DateTime`, and drift stores a `DateTime` as **epoch seconds** —
  /// `millisecondsSinceEpoch ~/ 1000` (`drift/lib/src/runtime/types/mapping.dart`,
  /// read in the installed 2.35.1, not from memory). So two openings a millisecond apart
  /// are **the same value in the database**, and an id derived from a finer resolution
  /// would collide on the primary key while looking correct in Dart.
  ///
  /// The first version used `microsecondsSinceEpoch` and the test
  /// *two openings in the same millisecond are still two rows* failed with
  /// `UNIQUE constraint failed: history_entries.id`. The failure is right and the code
  /// was wrong: a distinction the column cannot hold cannot be made in the id either.
  ///
  /// ## So what makes two openings distinguishable?
  ///
  /// Nothing in the id, and **that is the honest answer**: within one second the
  /// journal cannot tell two openings apart, and pretending otherwise would produce an
  /// id that looks distinct in memory and is not distinct on disk. Re-opening a chapter
  /// twice inside one second is not a gesture a reader makes — the minimum is a tap,
  /// a load, and a scroll.
  ///
  /// What *is* guaranteed, and is what the tests assert: two openings **a second or
  /// more apart** are two rows, because that is the resolution the schema holds. The
  /// id carries the second, so a reader who re-opens a chapter tomorrow gets a row, and
  /// B47's window then removes the older of the two first.
  /// Exposed for the row that pins the resolution, and for nothing else.
  ///
  /// ⚠️ A test hook rather than a duplicate derivation **on purpose**: a copy of
  /// `md5('c1/$seconds')` in the test would pass whatever `_entryId` does, and the
  /// whole point of the row is to compare the two against the drift behaviour rather
  /// than against each other.
  @visibleForTesting
  static String entryIdForTest({
    required String chapterId,
    required DateTime openedAt,
  }) => _entryId(chapterId: chapterId, openedAt: openedAt);

  static String _entryId({
    required String chapterId,
    required DateTime openedAt,
  }) {
    // ⚠️ `~/ 1000` deliberately, and it is the SAME expression drift applies on the way
    // in. Using the raw `microsecondsSinceEpoch` here would make the id depend on a
    // precision the column discards two lines later.
    final int seconds = openedAt.millisecondsSinceEpoch ~/ 1000;
    return SourceId.md5Hex('$chapterId/$seconds');
  }
}
