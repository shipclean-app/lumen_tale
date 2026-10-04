// Lumen Tale — drift's side of `3-3`: enqueue, delete one stored copy, cancel.
//
// ## ⚠️ THE ORDER OF THE TWO WRITES IN `deleteStoredCopy`, and it is B33
//
// 1. **measure the file's size** — it must be read BEFORE the unlink, because
//    `File.lengthSync()` after the file is gone is zero, and a delete confirmation that
//    reports zero freed teaches a reader that deletions do nothing;
// 2. **delete the file**;
// 3. **null `downloadedAt`**, keeping the row.
//
// If the unlink fails, `downloadedAt` is **not** touched: a file that survived must keep its
// mark, or the tile claims a copy that is still on disk — the reverse lie of the one B6
// prevents.

import 'dart:io';

import 'package:drift/drift.dart';
import 'package:lumen_tale/core/database/app_database.dart';
import 'package:lumen_tale/core/error/source_failure.dart';
import 'package:lumen_tale/domain/downloads/chapter_action_repository.dart';
import 'package:lumen_tale/domain/downloads/download_request.dart';
import 'package:lumen_tale/features/downloads/domain/chapter_store.dart';

/// How much the space probe will write before it gives up.
///
/// ⚠️ **8 MiB, and it was 64.** The first version wrote up to 64 MiB and did so on EVERY
/// `enqueue`, which made a unit test of the repository time out at 30 minutes. Two lessons
/// in one: a measurement that costs real I/O has to be bounded tightly, and a measurement
/// that does not change between calls has to be **cached** rather than repeated.
///
/// 8 MiB is far above a chapter (tens of KB) and far below the point where the probe is
/// noticeable, and a device with more room than that reports the ceiling — which makes
/// `required > free` false, the safe direction.
const int _kSpaceProbeCeiling = 8 * 1024 * 1024;

/// How much one probe step writes. Large enough that the ceiling is a handful of steps.
const int _kSpaceProbeChunk = 1024 * 1024;

final class DriftChapterActionRepository implements ChapterActionRepository {
  DriftChapterActionRepository({
    required AppDatabase database,
    required ChapterStore store,
    Directory? probeDirectory,
    Future<int> Function()? freeBytesProbe,
  }) : _db = database,
       _store = store,
       _probeDirectory = probeDirectory,
       _freeBytesProbe = freeBytesProbe;

  final AppDatabase _db;
  final ChapterStore _store;

  /// Where the space probe writes. Nullable so a test can point it at a temp dir.
  final Directory? _probeDirectory;

  /// ⚠️ **INJECTABLE, because the probe costs REAL I/O and a unit test must not pay it.**
  ///
  /// The default writes megabytes to disk to answer "is there room", which is the honest
  /// measurement available without a platform channel — and which made this repository's own
  /// tests time out. A test injects a number; production measures. Both are the same number,
  /// and only one of them is slow.
  final Future<int> Function()? _freeBytesProbe;

  @override
  Future<EnqueueOutcome> enqueue(DownloadRequest request) async {
    if (request.isEmpty) return const EnqueueQueued(queued: 0);

    // ⚠️ **READ `chapters`. NEVER WRITE IT.** This SELECT is how the already-stored check
    // below is possible at all — and a test asserts that no statement this repository emits
    // *writes* the table, because the mark belongs to `2-3` after its atomic rename.
    final List<ChapterRow> rows = await (_db.select(
      _db.chapters,
    )..where(($ChaptersTable t) => t.id.isIn(request.chapterIds))).get();
    final Set<String> stored = <String>{
      for (final ChapterRow row in rows)
        if (row.downloadedAt != null) row.id,
    };

    // B6 — an item is never created for a chapter that already has a copy.
    if (stored.length == request.length) return const EnqueueAlreadyStored();

    final List<String> queueable = request.chapterIds
        .where((String id) => !stored.contains(id))
        .toList(growable: false);
    final int skipped = request.length - queueable.length;

    // E20 — measured against measured. Unknown required bytes does not become a refusal.
    //
    // ⚠️ **THE NOVEL ID COMES FROM THE ROWS.** A request is a list of chapter ids and a
    // chapter id says nothing about its novel, so passing one here would have been a
    // category error that happened to compile.
    final String? novelId = rows.isEmpty ? null : rows.first.novelId;
    if (queueable.isNotEmpty && novelId != null) {
      final int? required = await measuredChapterBytes(novelId);
      if (required != null) {
        final int free = await freeBytes();
        // ⚠️ **BOTH NUMBERS, and only when it genuinely does not fit.** `required <= free` is
        // the boundary, so a download that exactly fills the remaining space is allowed —
        // the filesystem will say so itself, with a real error, if it disagrees.
        if (required > free) {
          return EnqueueRefusedForSpace(
            requiredBytes: required,
            freeBytes: free,
          );
        }
      }
    }

    // B18 — `queuePosition` follows the REQUEST's order, never `chapters.ordinal`. The
    // reader's hand-picked sequence is the sequence the queue runs.
    await _db.batch((Batch batch) {
      batch.insertAll(_db.queueItems, <QueueItemsCompanion>[
        for (int i = 0; i < queueable.length; i++)
          QueueItemsCompanion.insert(
            id: 'q-${queueable[i]}',
            chapterId: queueable[i],
            // ⚠️ **The STRING `'queued'`, never `DownloadState.queued.index`.** The column
            // is a text column with a name-based converter; writing the ordinal would make
            // a raw query read `0`, and every future state name would silently shift.
            state: const Value<DownloadState>(DownloadState.queued),
            queuePosition: i,
            addedAt: DateTime.now().toUtc(),
          ),
      ], mode: InsertMode.insertOrIgnore);
    });

    return skipped == 0
        ? EnqueueQueued(queued: queueable.length)
        : EnqueuePartlyStored(queued: queueable.length, skipped: skipped);
  }

  @override
  Future<DeleteOneOutcome> deleteStoredCopy(String chapterId) async {
    final ChapterRow? row = await (_db.select(
      _db.chapters,
    )..where(($ChaptersTable t) => t.id.equals(chapterId))).getSingleOrNull();

    // B33 — nothing stored means **zero writes** and an outcome that is not "removed". A
    // confirmation for a no-op teaches a reader confirmations are decorative.
    if (row == null || row.downloadedAt == null) {
      return const DeleteOneNothingToRemove();
    }

    final ChapterRecord record = ChapterRecord(
      id: row.id,
      novelId: row.novelId,
      ordinal: row.ordinal,
    );

    // ⚠️ **MEASURE FIRST.** See the file header: after the unlink the size is zero.
    int freed = 0;
    final File? file = await _store.fileFor(record);
    if (file != null && file.existsSync()) {
      freed = file.lengthSync();
    }

    try {
      await _store.deleteOne(record);
    } on ChapterStoreException {
      // ⚠️ **THE MARK IS NOT TOUCHED.** The file survived, so the copy is still there, and a
      // tile claiming otherwise is the reverse lie of B6's.
      //
      // B24 wants a TYPED cause, and `NoConnection` is the right one: the filesystem refused,
      // which is a reachability failure the reader can act on (free space, permissions).
      return const DeleteOneFailed(NoConnection(host: 'local storage'));
    }

    // B33 — null the MARK, never the row. B9 requires the list to stay complete whatever its
    // length, and the row is the parent `history_entries` and `reading_positions` hang from.
    await (_db.update(_db.chapters)
          ..where(($ChaptersTable t) => t.id.equals(chapterId)))
        .write(const ChaptersCompanion(downloadedAt: Value<DateTime?>(null)));

    return DeleteOneRemoved(freedBytes: freed);
  }

  @override
  Future<CancelOutcome> cancelIfNotStarted(String queueItemId) async {
    final QueueRow? item =
        await (_db.select(_db.queueItems)
              ..where(($QueueItemsTable t) => t.id.equals(queueItemId)))
            .getSingleOrNull();
    if (item == null) return const CancelTooLate();

    // B6 — a fetch already under way would leave a half-written file whose completion
    // nothing is watching. No file is touched and `downloadedAt` is unchanged: the item
    // finishes and the chapter becomes stored normally.
    if (item.state != DownloadState.queued) return const CancelTooLate();

    await (_db.delete(
      _db.queueItems,
    )..where(($QueueItemsTable t) => t.id.equals(queueItemId))).go();
    return const CancelRemoved();
  }

  /// ⚠️ **CACHED.** Free space does not change between two taps a second apart, and a
  /// repository that re-probed on every `enqueue` would write megabytes to learn a number it
  /// already had.
  int? _freeBytesCache;

  @override
  Future<int> freeBytes() async {
    final int? cached = _freeBytesCache;
    if (cached != null) return cached;

    final Future<int> Function()? injected = _freeBytesProbe;
    if (injected != null) {
      final int measured = await injected();
      _freeBytesCache = measured;
      return measured;
    }

    final Directory dir = _probeDirectory ?? Directory.systemTemp;
    // ⚠️ **MEASURED BY WRITING, NOT ESTIMATED, and BOUNDED.** Dart exposes no statvfs, so the
    // honest measurement is to put bytes down and see when the filesystem refuses. The
    // ceiling is a bound on the PROBE, never on the answer: if the device has more room
    // than the ceiling, this reports the ceiling and `required > free` is simply false,
    // which is the safe direction.
    int written = 0;
    final File probe = File('${dir.path}/.lumen_space_probe');
    try {
      while (written < _kSpaceProbeCeiling) {
        await probe.writeAsBytes(
          List<int>.filled(_kSpaceProbeChunk, 0),
          mode: FileMode.append,
        );
        written += _kSpaceProbeChunk;
      }
      _freeBytesCache = written;
      return written;
    } on FileSystemException {
      // The write that failed is the first byte that did not fit — so the answer is what
      // DID fit, which is the free space this process had.
      _freeBytesCache = written;
      return written;
    } finally {
      if (probe.existsSync()) probe.deleteSync();
    }
  }

  @override
  Future<int?> measuredChapterBytes(String novelId) async {
    // ⚠️ **A REAL FILE'S SIZE, or `null`.** Never an average, never a per-character
    // estimate. An implementation that returned `0` here would refuse every first download.
    final List<ChapterRow> rows =
        await (_db.select(_db.chapters)..where(
              ($ChaptersTable t) =>
                  t.novelId.equals(novelId) & t.downloadedAt.isNotNull(),
            ))
            .get();
    for (final ChapterRow row in rows) {
      final File? file = await _store.fileFor(
        ChapterRecord(id: row.id, novelId: row.novelId, ordinal: row.ordinal),
      );
      if (file != null && file.existsSync()) return file.lengthSync();
    }
    return null;
  }
}
