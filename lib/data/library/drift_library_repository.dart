// Lumen Tale — the library over drift, and the UPDATE that is B32.
//
// ## ⚠️ `removeFromLibrary` writes ONE COLUMN and deletes NOTHING
//
// `chapters.novelId` is `ON DELETE CASCADE` and `history_entries.novelId` is
// `ON DELETE RESTRICT`. So `DELETE FROM novels` would erase the chapter metadata B14/B48
// count, and would **fail outright** the first time a chapter had been opened. B32 says the
// downloads stay. All three facts hold simultaneously only because the removal is
// `inLibrary = false`.
//
// Five things are deliberately NOT written, and the list is the function's real content:
//
// ```text
// ✗ DELETE FROM novels         CASCADE on chapters, RESTRICT on history_entries
// ✗ the .md files              B32
// ✗ history_entries            B32: the record of what was read survives
// ✗ reading_positions          B46: a position is never cut by any retention rule
// ✗ queue_items                B21: the queue continues chapter by chapter
// ✗ lastCheckedAt              B49: "never checked" stays true
// ```
//
// ⚠️ **There is no `if (downloadedCount > 0)` branch**, and that is the trap: an
// implementation in a hurry adds one, and the branch is what makes a removal silently delete
// downloads. A row asserts the absence.

import 'package:drift/drift.dart';

import 'package:lumen_tale/core/database/app_database.dart';
import 'package:lumen_tale/domain/library/library_entry.dart';
import 'package:lumen_tale/domain/library/library_repository.dart';
import 'package:lumen_tale/domain/library/similar_title.dart';
import 'package:lumen_tale/domain/sources/models/novel.dart';

/// ⚠️ **Resolved by the registry, never by a column** (ADR-013). A callback rather than a
/// `SourceManager` so `data/library` does not depend on `data/sources` and a row can be shown
/// with a name the caller supplies.
typedef SourceNameResolver = String? Function(String sourceId);

final class DriftLibraryRepository implements LibraryRepository {
  DriftLibraryRepository(this._db, {SourceNameResolver? sourceNameOf})
    : _sourceNameOf = sourceNameOf ?? _unknownSource;

  final AppDatabase _db;
  final SourceNameResolver _sourceNameOf;

  /// ⚠️ **`unknown` and never the id itself.** Printing a raw MD5 where a site name belongs
  /// tells a reader nothing they can act on, and it puts an internal identifier on screen.
  static String _unknownSource(String sourceId) => 'unknown';

  @override
  String? sourceNameOf(String sourceId) => _sourceNameOf(sourceId);

  @override
  Stream<List<LibraryEntry>> watchLibrary() {
    // ⚠️ **ONE stream, ONE query.** No pagination and no "load more": a novel's unopened and
    // downloaded counts are **aggregates over its chapters**, and a library of 200 novels is
    // 200 aggregates — which on the chapter indexes `06-database.md` declares is a list
    // operation, not a scan.
    final SimpleSelectStatement<$NovelsTable, NovelRow> query =
        _db.select(_db.novels)
          ..where(($NovelsTable table) => table.inLibrary.equals(true))
          ..orderBy(<OrderClauseGenerator<$NovelsTable>>[
            ($NovelsTable table) => OrderingTerm.desc(table.addedAt),
          ]);
    return query.watch().asyncMap(_entriesFor);
  }

  /// ⚠️ **The counts are read per novel, by aggregate, never by iterating chapters.**
  ///
  /// A novel can carry 10 000 chapter rows and B9 requires that list to stay complete whatever
  /// its length, so a loop here would be a scan per novel.
  Future<List<LibraryEntry>> _entriesFor(List<NovelRow> rows) async {
    final List<LibraryEntry> entries = <LibraryEntry>[];
    for (final NovelRow row in rows) {
      final ChapterCounts counts = await _countsFor(row.id);
      entries.add(_entryOf(row, counts));
    }
    return entries;
  }

  LibraryEntry _entryOf(NovelRow row, ChapterCounts counts) {
    return LibraryEntry(
      id: row.id,
      sourceId: row.sourceId,
      sourceName: _sourceNameOf(row.sourceId) ?? _unknownSource(row.sourceId),
      title: row.title,
      author: row.author,
      coverUrl: row.coverUrl,
      inLibrary: row.inLibrary,
      addedAt: row.addedAt,
      lastCheckedAt: row.lastCheckedAt,
      unopenedCount: counts.unopened,
      chapterCount: counts.known,
      downloadedCount: counts.downloaded,
    );
  }

  /// The three counts, each by SQL aggregate.
  ///
  /// ⚠️ **`downloaded_at IS NOT NULL`, and not "the file exists".** ADR-022 makes the mark the
  /// fact; B33 clears it on a deliberate deletion, so an existence probe could not tell
  /// "removed on purpose" from "lost", and E6 guarantees an interrupted download has no mark.
  ///
  /// ⚠️ **THREE AGGREGATES, NOT A LOOP.** A novel can carry 10 000 chapter rows and B9 requires
  /// that list to stay complete whatever its length, so iterating them here would be a scan
  /// per novel on every rebuild of the library.
  ///
  /// ⚠️ **The unopened count is `unread among DOWNLOADED`, and that is deliberate.** B14
  /// counts the new chapters a reader can still act on, and a chapter that is not on the phone
  /// cannot be opened — so counting unread chapters of an undownloaded novel would put a badge
  /// on a tile whose contents the reader does not have.
  Future<ChapterCounts> _countsFor(String novelId) async {
    return ChapterCounts(
      unopened: await _countWhere(
        novelId,
        _db.chapters.isRead.equals(false) &
            _db.chapters.downloadedAt.isNotNull(),
      ),
      downloaded: await _countWhere(
        novelId,
        _db.chapters.downloadedAt.isNotNull(),
      ),
      known: await _countWhere(novelId, const Constant(true)),
    );
  }

  /// `count(*)` over this novel's chapters matching [filter], as one aggregate.
  Future<int> _countWhere(String novelId, Expression<bool> filter) async {
    final Expression<int> count = _db.chapters.id.count();
    final TypedResult row =
        await (_db.selectOnly(_db.chapters)
              ..addColumns(<Expression<Object>>[count])
              ..where(_db.chapters.novelId.equals(novelId) & filter))
            .getSingle();
    return row.read(count) ?? 0;
  }

  @override
  Future<int> countDownloadedChapters(String novelId) async {
    final ChapterCounts counts = await _countsFor(novelId);
    return counts.downloaded;
  }

  @override
  Future<AddOutcome> addFromCatalogue({
    required Novel novel,
    required Future<SimilarTitleVerdict> Function(List<SimilarTitle> similar)
    onSimilarTitle,
  }) async {
    // ── guard 1: B12/B10 — the novel must be displayable and reopenable ──
    // ⚠️ **A rejection with zero writes.** A novel with no name is not displayable, and one
    // with no URL cannot be reopened — so neither is a discovery.
    if (novel.title.trim().isEmpty || novel.url.isEmpty) {
      return const AddOutcome.rejected(AddRejection.emptyTitle);
    }

    // ── guard 2: B11 — already kept? Idempotent, not an error ─────────────
    final NovelRow? existing = await _rowFor(novel.id);
    if (existing != null && existing.inLibrary) {
      return const AddOutcome.added(alreadyInLibrary: true);
    }

    // ── guard 3: B40 — the warning comes BEFORE any write ─────────────────
    final List<SimilarTitle> similar = await findSimilarTitles(novel);
    if (similar.isNotEmpty) {
      final SimilarTitleVerdict verdict = await onSimilarTitle(similar);
      switch (verdict) {
        case SimilarTitleVerdict.addAnyway:
          break;
        // ⚠️ **Dismissed, declined and "open the existing" all decline.** The default has to be
        // the safe one: the easiest gesture on a device with no backup (C8) must not be the
        // one that adds a second copy of a novel the reader already has.
        case SimilarTitleVerdict.dismissed:
        case SimilarTitleVerdict.declined:
        case SimilarTitleVerdict.openExisting:
          return AddOutcome.rejected(
            AddRejection.declinedForSimilarTitle,
            similarTitles: similar,
          );
      }
    }

    try {
      await _db
          .into(_db.novels)
          .insertOnConflictUpdate(
            NovelsCompanion.insert(
              id: novel.id,
              sourceId: novel.sourceId,
              url: novel.url,
              title: novel.title,
              // ⚠️ **NOT `lastCheckedAt`.** B49: null means "never checked", and browsing a
              // catalogue is not a check of this novel.
              author: Value(novel.author),
              coverUrl: Value(novel.coverUrl),
              inLibrary: const Value(true),
              addedAt: Value<DateTime?>(DateTime.now()),
            ),
          );
    } on Object {
      // ⚠️ **Nothing is optimistic.** `library.md` § 4 *Submit error*: the row is **still
      // there**, at `inLibrary == false`, and the dialog says so with a retry.
      return const AddOutcome.rejected(AddRejection.storeUnwritable);
    }

    return AddOutcome.added(despiteSimilarTitle: similar.isNotEmpty);
  }

  /// B40 — the entries already in the library whose normalised title equals the incoming one.
  ///
  /// ⚠️ **The filter is `inLibrary = true`.** A removed novel occupies no space and B32 says
  /// it can be put back without hindrance — so it must not collide with someone else's add.
  Future<List<SimilarTitle>> findSimilarTitles(Novel incoming) async {
    final String key = normalizeForSimilarity(incoming.title);
    if (key.isEmpty) {
      return <SimilarTitle>[];
    }

    final List<NovelRow> rows =
        await (_db.select(_db.novels)..where(
              ($NovelsTable table) =>
                  table.inLibrary.equals(true) &
                  table.id.equals(incoming.id).not(),
            ))
            .get();

    // ⚠️ **The comparison is in Dart, over the normalised key.** SQLite has no accent folding
    // that matches this one, so a SQL `lower()`/`replace()` chain would be a second, subtly
    // different normalisation — and two normalisations are two answers to "is this the same
    // novel?".
    return <SimilarTitle>[
      for (final NovelRow row in rows)
        if (normalizeForSimilarity(row.title) == key)
          SimilarTitle(
            existingNovelId: row.id,
            existingTitle: row.title,
            existingSourceName:
                _sourceNameOf(row.sourceId) ?? _unknownSource(row.sourceId),
            incomingTitle: incoming.title,
            incomingSourceName:
                _sourceNameOf(incoming.sourceId) ??
                _unknownSource(incoming.sourceId),
          ),
    ];
  }

  @override
  Future<RemoveOutcome> removeFromLibrary(String novelId) async {
    final NovelRow? row = await _rowFor(novelId);
    if (row == null) {
      // ⚠️ **A stale identifier in a restored navigation stack is a state of the world**, and it
      // must not be reported as a storage failure.
      throw const LibraryEntryAbsent();
    }
    if (!row.inLibrary) {
      // ⚠️ **No write and no confirmation.** Two library extinctions must not produce two
      // confirmations — and the second one has nothing to report.
      return RemoveOutcome(
        downloadedChapterCount: await countDownloadedChapters(novelId),
        wasAlreadyRemoved: true,
      );
    }

    // ⚠️ **Counted BEFORE the write**, because the dialog quotes this figure and the reader
    // must be asked about what was true when they were asked.
    final int downloaded = await countDownloadedChapters(novelId);

    // ⚠️ **THE WRITE. One UPDATE, two columns.** See the file header for the five things that
    // are deliberately not written.
    await (_db.update(
      _db.novels,
    )..where(($NovelsTable table) => table.id.equals(novelId))).write(
      const NovelsCompanion(
        inLibrary: Value<bool>(false),
        // ⚠️ **`addedAt` is nulled**, per `architecture.md` § 4.1: null while `inLibrary` is
        // false. That is also why [restoreToLibrary] cannot recover the original instant.
        addedAt: Value<DateTime?>(null),
      ),
    );

    return RemoveOutcome(
      downloadedChapterCount: downloaded,
      wasAlreadyRemoved: false,
    );
  }

  @override
  Future<void> restoreToLibrary(String novelId) async {
    final NovelRow? row = await _rowFor(novelId);
    if (row == null) {
      throw const LibraryEntryAbsent();
    }
    if (row.inLibrary) {
      return;
    }

    // ⚠️ **`addedAt` becomes NOW, not the previous value.** § 4.1 required it to be nulled on
    // removal, so the old instant is gone — and the consequence is named rather than
    // discovered: after a remove-and-restore the novel sorts as *recently added*. No rule
    // (B11, B12, B32, B40) says otherwise, and saying so here is worth more than finding out.
    await (_db.update(
      _db.novels,
    )..where(($NovelsTable table) => table.id.equals(novelId))).write(
      NovelsCompanion(
        inLibrary: const Value<bool>(true),
        addedAt: Value<DateTime?>(DateTime.now()),
      ),
    );
  }

  Future<NovelRow?> _rowFor(String novelId) {
    // ⚠️ **`getSingleOrNull`, never `getSingle`.** A stale identifier is ordinary, and
    // `getSingle()` turns it into an exception the caller would have to catch to express
    // [LibraryEntryAbsent].
    return (_db.select(_db.novels)
          ..where(($NovelsTable table) => table.id.equals(novelId)))
        .getSingleOrNull();
  }

  @override
  Future<Novel?> readNovel(String novelId) async {
    final NovelRow? row = await _rowFor(novelId);
    if (row == null) return null;
    return _novelOf(row);
  }

  /// A stored row as the source-domain [Novel] `addFromCatalogue` takes.
  ///
  /// ⚠️ **`genres` is EMPTY, and it has to be.** `genres` is a *discovery* hint — it is what
  /// a catalogue browse filtered on — and the `novels` table has no column for it, because
  /// nothing in the library ever filters by genre. Inventing one from the row's `status`, or
  /// re-fetching the site to recover it, would make "read the novel I already have" cost a
  /// network call, which is B5's exact prohibition on a read path. An empty list is the
  /// honest answer: this app does not know the genres of a novel it has already stored.
  Novel _novelOf(NovelRow row) => Novel(
    id: row.id,
    sourceId: row.sourceId,
    url: row.url,
    title: row.title,
    author: row.author,
    description: row.description,
    status: _statusOf(row.status),
    coverUrl: row.coverUrl,
    genres: const <String>[],
  );

  /// The stored status string back to the enum, and **never a throw**.
  ///
  /// ⚠️ **THE COLUMN IS EMPTY IN PRACTICE.** `addFromCatalogue` never writes `status`, so
  /// every stored row carries the column default `''`. `NovelStatus.values.byName('')` throws
  /// — and `13-error-handling.md`'s rule is that a typed value is *returned*, never thrown:
  /// an unrecognised status is `NovelStatus.unknown`, whose own doc comment is "the site
  /// published no status". That is exactly the case here, so the fallback is not a
  /// consolation, it is the correct reading.
  static NovelStatus _statusOf(String stored) {
    for (final NovelStatus candidate in NovelStatus.values) {
      if (candidate.name == stored) return candidate;
    }
    return NovelStatus.unknown;
  }
}

/// Three counts, read together.
final class ChapterCounts {
  const ChapterCounts({
    required this.unopened,
    required this.downloaded,
    required this.known,
  });

  final int unopened;
  final int downloaded;

  /// The number of chapter **rows**, which is the site's list and not the downloads.
  final int known;
}

/// A novel id that is not in the database: a stale deep link, a restored stack.
///
/// ⚠️ **Not an `AppException`.** That hierarchy is for failures the UI maps to a message by
/// cause, and "the row is not there" is a state of the world, not a failure of anything.
final class LibraryEntryAbsent implements Exception {
  const LibraryEntryAbsent();

  @override
  String toString() => 'LibraryEntryAbsent: the novel is not in the database';
}
