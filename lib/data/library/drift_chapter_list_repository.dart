// Lumen Tale — the chapter list, read from drift, and the one read of the site.
//
// `3-2`. `data/` → `core` + `domain` (`02-architecture.md`).
//
// ## ⚠️ THE INTERFACE HAS NO WRITE, AND THE CLASS HAS EXACTLY ONE
//
// `ChapterListRepository` is read-only by design. The single write here,
// [storeChapterList], is on **this class and not on the interface**, because the interface's
// users are screens that display and the writer is the list loader. Widening the interface to
// carry it would put a write behind every screen that only ever draws.
//
// ## ⚠️ `-1` BECOMES `null`, AND 0 STAYS 0
//
// The column's `-1` is a storage fact and never reaches a tile: `03-source-system.md` rule 9
// says `-1` means *unparseable*, and 0 is a real chapter — an extra, an omake, an author's note.
// Collapsing the two is a B10 violation, and the mapping lives here so exactly one place knows
// the sentinel.
//
// ## ⚠️ `[ordinal]` IS THE SITE'S LIST POSITION, NEVER THE PARSED NUMBER
//
// B9. `number` is `-1` when the site published something unreadable and restarts at zero in
// every volume, so sorting by it interleaves volumes and loses chapters. The position in the
// list the site published is the only order that is the site's own.
//
// ## ⚠️ `downloadedAt` IS THE ONLY DISCRIMINATOR, and the disk is not touched
//
// `isDownloaded` is `downloadedAt != null` and nothing else. ADR-022 writes the mark after the
// atomic rename, so an interrupted download has no mark (E6) and a deliberate deletion clears
// one (B33) — which a per-row existence probe could not tell from a lost file. `2-4`'s reader
// already established this; a second probe here would reintroduce the exact defect ADR-022
// removed.

import 'package:drift/drift.dart';

import 'package:lumen_tale/core/database/app_database.dart';
import 'package:lumen_tale/core/error/source_failure.dart';
import 'package:lumen_tale/domain/library/chapter_entry.dart';
import 'package:lumen_tale/domain/library/chapter_list_repository.dart';
import 'package:lumen_tale/domain/sources/browse_outcome.dart';
import 'package:lumen_tale/domain/sources/models/chapter.dart';

/// Drift's chapter list, plus the one network call.
final class DriftChapterListRepository implements ChapterListRepository {
  DriftChapterListRepository(this._db);

  final AppDatabase _db;

  @override
  Stream<List<ChapterEntry>> watchChapters(String novelId) {
    final SimpleSelectStatement<$ChaptersTable, ChapterRow> query =
        _db.select(_db.chapters)
          ..where(($ChaptersTable t) => t.novelId.equals(novelId))
          ..orderBy(<OrderingTerm Function($ChaptersTable)>[
            ($ChaptersTable t) => OrderingTerm.asc(t.ordinal),
          ]);

    return query.watch().map(
      (List<ChapterRow> rows) => rows.map(_toEntry).toList(growable: false),
    );
  }

  /// B14 / B48 — a `COUNT` in SQL.
  ///
  /// ⚠️ **`customSelect` rather than drift's builder, and the sibling file already decided
  /// this.** `drift_unopened_count_repository.dart` § "Why this is `customSelect`": the part of
  /// the specification drift's expression builder cannot express cleanly is exactly the part that
  /// matters, and the SQL *is* the specification. A readable query that is right beats an
  /// elegant builder call that has to be decoded twice.
  @override
  Future<int> countUnopened(String novelId) =>
      _count(novelId, whereUnread: true);

  @override
  Future<int> countAll(String novelId) => _count(novelId, whereUnread: false);

  Future<int> _count(String novelId, {required bool whereUnread}) async {
    final QueryRow row = await _db
        .customSelect(
          'SELECT COUNT(c.id) AS total FROM chapters c '
          'WHERE c.novel_id = ?${whereUnread ? ' AND c.is_read = 0' : ''}',
          variables: <Variable<Object>>[Variable<String>(novelId)],
          readsFrom: <ResultSetImplementation<Object, Object?>>{_db.chapters},
        )
        .getSingle();
    // ⚠️ **`COUNT` is never NULL in SQLite**, so this has no `?? 0` fallback: a defensive
    // default here would be a branch nothing can reach, and a reader of this file would have to
    // work out why it exists.
    return row.read<int>('total');
  }

  /// The one network path, and B12 is its precondition.
  ///
  /// ⚠️ **[read] is passed in rather than resolved here.** A repository that reached for a
  /// registry would be reaching up a layer; the screen owns which source this novel came from
  /// and hands the read over. It also means this class holds **no client**, so a row can prove
  /// the mapping with no network at all.
  ///
  /// ⚠️ **A `SourceFailure` that escaped the source is re-typed, not stringified.**
  /// `13-error-handling.md`: the caller needs one vocabulary, and a `catch (e)` here would
  /// invent a second one that no `switch` in this codebase could be exhaustive over.
  @override
  Future<BrowseOutcome<ChapterListFetchResult>> fetchChapterListOnce(
    String novelId, {
    Future<BrowseOutcome<List<Chapter>>> Function()? read,
  }) async {
    if (read == null) {
      // ⚠️ **No read supplied is a failure of THIS app's wiring, not of the site.** It is still
      // typed, so the screen has one vocabulary rather than a second one for "the repository was
      // misconfigured" and a third for "the site is broken".
      return const BrowseFailed<ChapterListFetchResult>(
        SourceUnavailable(status: 0),
        retriable: false,
      );
    }

    final BrowseOutcome<List<Chapter>> outcome;
    try {
      outcome = await read();
    } on SourceFailure catch (failure) {
      return BrowseFailed<ChapterListFetchResult>(
        failure,
        retriable: failure.isRetriable,
      );
    }

    return switch (outcome) {
      BrowseSucceeded(items: final List<List<Chapter>> pages) =>
        _toFetchOutcome(pages, novelId),
      // ⚠️ **The site's own marker, kept verbatim.** B22's whole point, and the only path to an
      // "empty" answer a reader should ever see.
      BrowseEmpty(:final String siteSuppliedSignal) =>
        BrowseEmpty<ChapterListFetchResult>(
          siteSuppliedSignal: siteSuppliedSignal,
        ),
      BrowseFailed(:final SourceFailure reason) =>
        BrowseFailed<ChapterListFetchResult>(
          reason,
          retriable: reason.isRetriable,
        ),
    };
  }

  /// ⚠️ **E3: the pages the site split a chapter across are ONE entry each.** `2-2`'s page
  /// joining has already happened by the time a `Chapter` exists; what arrives here is a list of
  /// them, and a list is a list.
  BrowseOutcome<ChapterListFetchResult> _toFetchOutcome(
    List<List<Chapter>> pages,
    String novelId,
  ) {
    final List<ChapterEntry> entries = <ChapterEntry>[];
    // ⚠️ **The ordinal counts across PAGES, not within one.** A page boundary is a fetch
    // artefact; the site's chapter order runs through it, and a per-page index would restart the
    // sequence at every boundary and make every page the same order.
    int ordinal = 0;
    for (final List<Chapter> page in pages) {
      for (final Chapter chapter in page) {
        entries.add(_toEntryFromSource(chapter, novelId, ordinal++));
      }
    }
    return BrowseSucceeded<ChapterListFetchResult>(<ChapterListFetchResult>[
      ChapterListFetchResult(entries: entries),
    ]);
  }

  ChapterEntry _toEntry(ChapterRow row) => ChapterEntry(
    id: row.id,
    name: row.name,
    // ⚠️ **The sentinel, in the one place that knows it.** -1 → null; 0 → 0.
    number: row.number == -1 ? null : row.number,
    ordinal: row.ordinal,
    isRead: row.isRead,
    // ⚠️ **The MARK, never a probe.** See the class doc comment.
    isDownloaded: row.downloadedAt != null,
  );

  ChapterEntry _toEntryFromSource(
    Chapter chapter,
    String novelId,
    int ordinal,
  ) => ChapterEntry(
    id: chapter.id,
    // ⚠️ **The site's own text, and an absent title is the EMPTY STRING, never a number.** B10:
    // a fabricated title is a sentence the app invented and the reader would believe. The tile
    // renders *Untitled* for it — see `chapterTitleLabel`.
    name: chapter.name ?? '',
    number: chapter.number == -1 ? null : chapter.number,
    ordinal: ordinal,
    isRead: false,
    isDownloaded: false,
  );

  /// Writes the fetched list, **replacing** what was there.
  ///
  /// ⚠️ **`delete` then `insert`, inside one transaction.** A replace that deleted afterwards
  /// would leave a window where a novel carries both the old list and the new one, and a stream
  /// would emit that state to a reader scrolling it. A transaction makes the intermediate state
  /// unobservable — which is the whole reason the list is watchable.
  ///
  /// ⚠️ **`is_read` and `downloaded_at` are RESET, and that is deliberate.** B13's mark is about
  /// *this* novel in *this* library; carrying an old mark onto a re-fetched row would let a
  /// re-fetch silently reset a reader's progress, and `2-6` re-seeds the position afterwards.
  Future<void> storeChapterList(
    String novelId,
    List<ChapterListFetchResult> pages,
  ) async {
    final List<ChapterEntry> entries = <ChapterEntry>[];
    int ordinal = 0;
    for (final ChapterListFetchResult page in pages) {
      for (final ChapterEntry entry in page.entries) {
        entries.add(entry.copyWithOrdinal(ordinal++));
      }
    }

    await _db.transaction(() async {
      await (_db.delete(
        _db.chapters,
      )..where(($ChaptersTable t) => t.novelId.equals(novelId))).go();
      if (entries.isEmpty) return;
      await _db.batch((Batch batch) {
        batch.insertAll(
          _db.chapters,
          entries
              .map(
                (ChapterEntry e) => ChaptersCompanion.insert(
                  id: e.id,
                  novelId: novelId,
                  name: e.name,
                  number: Value<double>(e.number ?? -1),
                  url: '',
                  ordinal: e.ordinal,
                ),
              )
              .toList(growable: false),
        );
      });
    });
  }
}
