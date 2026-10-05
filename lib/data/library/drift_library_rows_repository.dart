// Lumen Tale — `LibraryRowsRepository` over drift.
//
// `6-6` Phase 1. `data/` → `core` + `domain` (`02-architecture.md`).
//
// ## ⚠️ ZERO NETWORK REACHABILITY IS STRUCTURAL, NOT ASSERTED
//
// There is no `dio`, no `SourceManager` and no `Source` import in this file, so C14 (*no
// network call may be required to open the library*) holds because there is no capability
// to call with — not because a comment says so. `18-external-contracts.md` has no entry
// here, and there is nothing to record about a site this slice never asks.

import 'package:drift/drift.dart';

import 'package:lumen_tale/core/database/app_database.dart';
import 'package:lumen_tale/data/library/library_queries.dart';
import 'package:lumen_tale/domain/library/library_row.dart';
import 'package:lumen_tale/domain/library/library_rows_repository.dart';
import 'package:lumen_tale/domain/library/library_search.dart';

/// ⚠️ **Resolved by the registry, never by a column** (ADR-013) — the same typedef and the
/// same reason as `drift_library_repository.dart`: a stored source name freezes, and a site
/// that renamed would keep answering with the old thing.
typedef LibrarySourceNameResolver = String? Function(String sourceId);

final class DriftLibraryRowsRepository implements LibraryRowsRepository {
  DriftLibraryRowsRepository(
    this._db, {
    LibrarySourceNameResolver? sourceNameOf,
  }) : _sourceNameOf = sourceNameOf ?? _unknownSource;

  final AppDatabase _db;
  final LibrarySourceNameResolver _sourceNameOf;

  /// ⚠️ **`unknown`, never the id.** An MD5 printed where a site name belongs tells a
  /// reader nothing they can act on and puts an internal identifier on screen.
  static String _unknownSource(String sourceId) => 'unknown';

  @override
  Stream<List<LibraryRow>> watchRows() {
    return _db
        .customSelect(
          unopenedCountsSql,
          variables: const <Variable<Object>>[Variable<bool>(true)],
          readsFrom: _readsFrom,
        )
        .watch()
        .map((List<QueryRow> rows) => rows.map(_rowOf).toList(growable: false));
  }

  @override
  Stream<List<String>> watchMatchingNovelIds(TitleSearch query) {
    // ⚠️ **Refused, not answered.** `TitleSearch.isEmpty` reaching this method means the
    // caller skipped § 3.1 branch 1, and `LIKE '%%'` would quietly return the whole library
    // through the *search* path — two answers to "what does an empty query do", and the one
    // that fails silently is the one nobody tests.
    if (query.isEmpty) {
      throw StateError(
        'watchMatchingNovelIds is for a query that restricts something; an empty one '
        'renders the whole library through watchRows.',
      );
    }
    return _db
        .customSelect(
          titleSearchSql,
          variables: <Variable<Object>>[
            const Variable<bool>(true),
            Variable<String>(query.bindValue),
          ],
          // ⚠️ `readsFrom` for a title search is **`novels` alone.** `chapters`,
          // `queue_items` and `reading_positions` cannot change which novel ids match a
          // title, and listing them would re-run this query on every chapter the reader
          // opens — one search per keystroke, times every read.
          readsFrom: <ResultSetImplementation<dynamic, dynamic>>{_db.novels},
        )
        .watch()
        .map(
          (List<QueryRow> rows) => rows
              .map((QueryRow row) => row.read<String>('novel_id'))
              .toList(growable: false),
        );
  }

  LibraryRow _rowOf(QueryRow row) {
    final String sourceId = row.read<String>('source_id');
    final int chapterCount = row.read<int>('total');
    final int downloadedCount = row.read<int>('downloaded');
    final String? queueError = row.read<String?>('queue_error_code');
    final int running = row.read<int>('queue_running');
    final int failed = row.read<int>('queue_failed');
    final String? sourceError = row.read<String?>('last_error_code');

    return LibraryRow(
      novelId: row.read<String>('novel_id'),
      title: row.read<String>('title'),
      author: row.read<String?>('author'),
      coverUrl: row.read<String?>('cover_url'),
      sourceName: _sourceNameOf(sourceId) ?? _unknownSource(sourceId),
      // ⚠️ **`unopened` is `is_read = 0` over EVERY chapter row**, which is B14's sentence
      // and `6-3`'s number. It is NOT `LibraryEntry.unopenedCount`, which `2-5` chose to
      // read as *unread among downloaded*; `library_row.dart`'s header says why the two
      // differ and why neither was moved.
      unopenedCount: row.read<int>('unopened'),
      chapterCount: chapterCount,
      downloadedCount: downloadedCount,
      lastCheckedAt: row.read<DateTime?>('last_checked_at'),
      // ⚠️ **B22 — the check failure does NOT touch `unopenedCount`.** Both are read from
      // one row and one is about a site while the other is about the phone; the test that
      // holds them apart writes `sources.last_error_code` and re-reads the badge.
      lastCheckError: sourceError == null || sourceError.isEmpty
          ? null
          : sourceError,
      download: resolveDownloadPresentation(
        downloadedCount: downloadedCount,
        chapterCount: chapterCount,
        // ⚠️ **`isRunning` and `stoppedBecause` are never both set.** A row reporting both
        // would have no label, and E6's whole content is that a stopped queue is never
        // rendered as working — so while any item is downloading, the cause stays `null`.
        //
        // ⚠️ **A FAILED ITEM WITH NO `error_code` IS STILL `otherCause`.** Reading the
        // cause as the stop signal would render an interrupted transfer as a queue that has
        // not started — E6 exactly, on a novel the reader watched stall.
        activity: DownloadActivity(
          isRunning: running > 0,
          stoppedBecause: running > 0
              ? null
              : failed > 0
              ? stopCauseOf(queueError ?? '') ?? DownloadStopCause.otherCause
              : null,
        ),
      ),
      addedAt: row.read<DateTime?>('added_at'),
      lastReadAt: row.read<DateTime?>('last_read_at'),
    );
  }

  /// ⚠️ **ALL FIVE, and the title row omits four of them on purpose** — see
  /// [watchMatchingNovelIds]. drift needs to be told which tables invalidate a stream, and
  /// a table listed here that the query does not read costs a re-run per write to it.
  late final Set<ResultSetImplementation<dynamic, dynamic>> _readsFrom =
      <ResultSetImplementation<dynamic, dynamic>>{
        _db.novels,
        _db.chapters,
        _db.sources,
        _db.queueItems,
        _db.readingPositions,
      };
}
