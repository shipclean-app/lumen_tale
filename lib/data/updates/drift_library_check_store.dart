// Lumen Tale — the check's writes, on drift.
//
// `data/` → `core` + `domain` (`02-architecture.md`).
//
// ## ⚠️ THREE WRITES AND THREE THINGS THIS FILE MAY NOT WRITE
//
// The prohibitions are the file, not the absence of code in it:
//
// | never | why |
// |---|---|
// | `DELETE` on any table | B32/B33 — a check removes nothing. A novel's chapters and its `.md` files survive it untouched. |
// | `chapters.is_read` / `read_at` | B13 — opening the chapter is the only gesture that writes those. |
// | `chapters.downloaded_at` | B6 / ADR-022 — `2-3` writes it after the atomic rename, and B38 forbids a check from touching it. |
// | a `queue_items` row | B38 — `5-1` is the only producer, and this class has no path to it. |
// | `novels.in_library` | B11/B12 — the reader decides membership. |
//
// `test/data/updates/check_never_downloads_test.dart` renders the first four as grep
// assertions over this file, because "it never does" is otherwise only an intention.
//
// ## ⚠️ `INSERT OR IGNORE`, NOT `insertOnConflictUpdate`
//
// The sibling `drift_chapter_list_repository.dart` replaces a list with delete-then-insert
// inside a transaction, because it is the **loader** and the first open of a novel is the
// one that establishes its list. This is a **check**, and it must not run that code:
// `INSERT OR IGNORE` leaves an existing row byte for byte as it was, so a chapter the
// reader has opened stays opened and a chapter on the phone stays downloaded. One novel
// therefore has two writers with opposite policies, and which one runs decides whether a
// reader's progress survives. That asymmetry is B13 and B6, expressed in SQL.

import 'package:drift/drift.dart';

import 'package:lumen_tale/core/database/app_database.dart';
import 'package:lumen_tale/domain/library/library_repository.dart';
import 'package:lumen_tale/domain/updates/library_check.dart';

final class DriftLibraryCheckStore implements LibraryCheckStore {
  DriftLibraryCheckStore(this._db);

  final AppDatabase _db;

  /// ⚠️ **`ORDER BY (added_at IS NULL), added_at ASC, id ASC`** — the same three keys the
  /// counting query uses, and for the same reason: two library novels with the same count
  /// must keep one order across a rebuild, or a reader scrolling the list watches rows swap.
  @override
  Future<List<LibraryNovelRef>> listLibraryNovels() async {
    final List<NovelRow> rows =
        await (_db.select(_db.novels)
              ..where(($NovelsTable t) => t.inLibrary.equals(true))
              ..orderBy(<OrderingTerm Function($NovelsTable)>[
                // Nulls LAST: a library novel with no `added_at` is older than nothing, and
                // B49's "never checked" is about the check, not about the order.
                ($NovelsTable t) => OrderingTerm.asc(t.addedAt.isNull()),
                ($NovelsTable t) => OrderingTerm.asc(t.addedAt),
                ($NovelsTable t) => OrderingTerm.asc(t.id),
              ]))
            .get();
    return List<LibraryNovelRef>.unmodifiable(
      rows.map(
        (NovelRow r) => LibraryNovelRef(
          novelId: r.id,
          sourceId: r.sourceId,
          title: r.title,
          url: r.url,
        ),
      ),
    );
  }

  @override
  Future<void> recordChecked(String novelId, DateTime at) async {
    await (_db.update(_db.novels)
          ..where(($NovelsTable t) => t.id.equals(novelId)))
        .write(NovelsCompanion(lastCheckedAt: Value(at)));

    // ⚠️ **THE CLEAR IS HERE, AND IT IS SCOPED TO THIS NOVEL'S SOURCE.** § 3.2 branch 6:
    // a successful check means "this site answered", so its own `last_error_code` goes.
    // It does **not** mean anything about the other sites, and a global clear would let a
    // broken site's novels report *Could not check* no more — B23's "a failure on one site
    // never blocks the others" inverted into a failure that hides itself.
    final String? sourceId = await _sourceIdOf(novelId);
    if (sourceId != null) {
      await (_db.update(_db.sources)
            ..where(($SourcesTable t) => t.id.equals(sourceId)))
          .write(const SourcesCompanion(lastErrorCode: Value('')));
    }
  }

  @override
  Future<void> recordCheckFailure(String novelId, CheckFailureKind kind) async {
    final String? sourceId = await _sourceIdOf(novelId);
    if (sourceId == null) {
      // ⚠️ **A novel with no source row records nothing, and that is not a silent failure.**
      // `novels.source_id` is not a foreign key to `sources` — the registry is code
      // (ADR-013) and a `sources` row exists only once something has been said about it.
      // There is nothing to write a code *onto*, and inventing one would be a row whose only
      // content is a failure nobody can read.
      return;
    }

    // ⚠️ **A COLUMN-LEVEL UPSERT, NOT `insertOnConflictUpdate`.** Drift's
    // `insertOnConflictUpdate` rewrites the WHOLE row from the companion, so a
    // `SourcesCompanion.insert(id: …, enabled: Value(true), …)` would switch a source
    // the reader had turned **off** back on as a side effect of reporting a failure on
    // it — B41's "the platform never overwrites a source's own settings", violated by a
    // failure report. `ON CONFLICT(id) DO UPDATE SET last_error_code` touches that one
    // column and leaves `enabled`, `settings` and `last_checked_at` exactly as they
    // were.
    await _db.customStatement(
      'INSERT INTO sources (id, last_error_code) VALUES (?, ?) '
      'ON CONFLICT(id) DO UPDATE SET last_error_code = excluded.last_error_code',
      <Object?>[sourceId, kind.name],
    );

    // ⚠️ **`novels.last_checked_at` is NOT written here, and its absence is B49.**
    // "Could not look" must not render as "looked, found nothing".
  }

  @override
  Future<bool> isSourceEnabled(String sourceId) async {
    final SourceRow? row = await (_db.select(
      _db.sources,
    )..where(($SourcesTable t) => t.id.equals(sourceId))).getSingleOrNull();
    // ⚠️ **ABSENT MEANS ENABLED.** `sources` is populated by the first thing that has
    // something to say about a source; a source nobody has ever failed has no row, and
    // treating that as "off" would make every novel fail its very first check.
    return row?.enabled ?? true;
  }

  @override
  Future<int> mergeChapterList(String novelId, List<NewChapter> fresh) async {
    if (fresh.isEmpty) return 0;

    // ⚠️ **THE COUNT IS TAKEN FIRST, ON THE IDS THIS CALL SUPPLIED, AND NOTHING
    // ELSE.**
    //
    // drift's `insertOrIgnore` reports no per-row outcome, so the number of rows *added* is
    // the number supplied minus the number already present. Differencing the novel's whole
    // list instead would report another writer's concurrent rows as this call's discovery,
    // and a "found 40 new chapters" announcement that is 40 too high teaches the reader to
    // distrust the next one (E16).
    //
    // Both statements sit in ONE transaction so a `watch()` stream can never observe the
    // moment between "these rows count as known" and "these rows exist".
    return _db.transaction<int>(() async {
      final Set<String> supplied = <String>{
        for (final NewChapter c in fresh) c.id,
      };
      final int alreadyKnown = await _countPresent(novelId, supplied);

      await _db.batch((Batch batch) {
        batch.insertAll(
          _db.chapters,
          fresh
              .map(
                (NewChapter c) => ChaptersCompanion.insert(
                  id: c.id,
                  novelId: novelId,
                  name: c.name,
                  // ⚠️ **`-1` is stored as `-1`.** `ChapterRecognition.unparseable`
                  // means "the site published no number", and `0` is a real chapter — an
                  // extra, an omake, a note. Coercing would make chapter 0 and "no number"
                  // share a row.
                  number: Value<double>(c.number),
                  url: c.url,
                  // ⚠️ **`is_read` and `downloaded_at` are NOT in the companion.**
                  // Their absence IS B13 and B6: a discovered chapter is unopened and not on
                  // the phone, and a row that already exists is left alone by `IGNORE`.
                  ordinal: c.ordinal,
                ),
              )
              .toList(growable: false),
          // ⚠️ **THE ONE `INSERT OR IGNORE` IN THE APP.** See the class header.
          mode: InsertMode.insertOrIgnore,
        );
      });

      return supplied.length - alreadyKnown;
    });
  }

  /// How many of [ids] already exist for [novelId].
  ///
  /// ⚠️ **BOUND VARIABLES, NOT `json_each`.** The ids are MD5 hex the app minted, and
  /// splicing them into an `IN (…)` list would be the shape `17-security.md` rule 1
  /// forbids; SQLite has no array parameter, so one `?` per id is both the safe spelling
  /// and the one that needs no JSON extension to be compiled in.
  Future<int> _countPresent(String novelId, Set<String> ids) async {
    if (ids.isEmpty) return 0;
    final List<String> ordered = ids.toList(growable: false)..sort();
    final QueryRow row = await _db
        .customSelect(
          'SELECT COUNT(c.id) AS total FROM chapters c WHERE c.novel_id = ? '
          'AND c.id IN (${List<String>.filled(ordered.length, '?').join(', ')})',
          variables: <Variable<Object>>[
            Variable<String>(novelId),
            for (final String id in ordered) Variable<String>(id),
          ],
          readsFrom: <ResultSetImplementation<Object, Object?>>{_db.chapters},
        )
        .getSingle();
    return row.read<int>('total');
  }

  Future<String?> _sourceIdOf(String novelId) async {
    final NovelRow? row = await (_db.select(
      _db.novels,
    )..where(($NovelsTable t) => t.id.equals(novelId))).getSingleOrNull();
    return row?.sourceId;
  }
}
