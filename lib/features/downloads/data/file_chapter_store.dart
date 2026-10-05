// Lumen Tale — the atomic chapter write. B6, E15, ADR-022.
//
// `07-downloads-offline.md` and `2-3` § 3.1. The two-write order **is** the rule:
//
//   1. the file — into a temporary in the SAME directory, fsynced, then `rename`d;
//   2. the mark.
//
// ## Why the temporary file is in the same directory
//
// `rename()` is atomic only within one filesystem. A temporary in a cache directory
// renamed into support crosses two, which turns the rename into a copy — and a copy is
// not atomic, so a kill mid-copy leaves a half-written chapter that the mark says is
// complete.
//
// ## Why the FILE is written before the MARK
//
// ⚠️ **This direction, and only this one, is what makes B6 expressible.** A crash between
// the two steps leaves a file **without** a mark — so the chapter offers itself for
// download again instead of opening as complete. The reverse leaves a mark **without** a
// file, and the reader opens a chapter that is not there.
//
// `downloadedAt` is written by the caller through [ChapterMarker], because the database
// is not this slice's to construct: `2-3` produces a storage function and its test, and
// the row update belongs to whoever holds the executor.

import 'dart:io';

import 'package:lumen_tale/features/downloads/domain/chapter_store.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// The filesystem implementation.
final class FileChapterStore implements ChapterStore, PartialChapterDiscarder {
  FileChapterStore({
    required ChapterMarker marker,
    Future<Directory> Function()? supportDirectory,
  }) : _marker = marker,
       _supportDirectory = supportDirectory ?? getApplicationSupportDirectory;

  /// The database side of the two-write order. A function rather than a database, so a
  /// test can prove the order without an executor.
  final ChapterMarker _marker;

  final Future<Directory> Function() _supportDirectory;

  /// `2-3` § 4.2: the **support** directory, never the cache directory.
  ///
  /// ⚠️ The OS may evict a cache directory at any time, and B7 requires a stored chapter
  /// to stay readable. A chapter in a cache directory is a chapter the reader can lose
  /// without uninstalling anything.
  Future<Directory> root() async =>
      Directory(p.join((await _supportDirectory()).path, 'chapters'));

  /// `chapters/<novelId>/<ordinal>.md`, or `null` when it is not there.
  ///
  /// ⚠️ **`ordinal` and never `number`.** See [ChapterRecord.ordinal].
  @override
  Future<File?> fileFor(ChapterRecord chapter) async {
    final File file = File(
      p.join((await root()).path, chapter.novelId, '${chapter.ordinal}.md'),
    );
    // ⚠️ **`existsSync` here, and the reason is that a miss is not exceptional.** `fileFor`
    // returns `null` for the ordinary case of a chapter that was never downloaded, and
    // `2-4` calls it once per chapter on the path to the reader — so this predicate runs
    // in a loop and a synchronous stat is the whole cost.
    return file.existsSync() ? file : null;
  }

  @override
  Future<DateTime> store({
    required ChapterRecord chapter,
    required String markdown,
  }) async {
    final Directory novelDir = Directory(
      p.join((await root()).path, chapter.novelId),
    );

    try {
      // ⚠️ **Recursive.** A `novelId` is an MD5 today and could nest after a future
      // change; a single-level `mkdir` would fail on the first novel whose id contains a
      // separator.
      await novelDir.create(recursive: true);
    } on FileSystemException catch (error) {
      // ⚠️ **E20 belongs to `5-3`, but the failure surfaces HERE**, so it is raised here
      // and classified there. A silent failure would let the mark be written for a file
      // that does not exist.
      throw ChapterStoreException(
        ChapterStoreFailure.cannotWrite,
        cause: error,
      );
    }

    final File final_ = File(p.join(novelDir.path, '${chapter.ordinal}.md'));
    // ⚠️ **The SAME directory.** See the file header.
    final File temp = File(
      p.join(novelDir.path, '.${chapter.ordinal}.md.part'),
    );

    try {
      // ⚠️ **`flush: true` is the load-bearing half**, and utf8 is the default. Without
      await temp.writeAsString(markdown, flush: true);
      // an fsync a crash can leave the file empty while the write reported success.
    } on FileSystemException catch (error) {
      throw ChapterStoreException(
        ChapterStoreFailure.cannotWrite,
        cause: error,
      );
    }

    // ⚠️ **"A write that reports success and produces no file is a MISLEADING SUCCESS."**
    // This is the one check that makes B6's first half true on its own: the file exists
    // before anything is renamed or marked.
    if (!temp.existsSync()) {
      throw const ChapterStoreException(
        ChapterStoreFailure.temporaryFileMissing,
      );
    }

    try {
      // ⚠️ **The rename IS the atomicity.** Overwriting an existing chapter is
      // idempotent, which is what makes re-downloading safe.
      await temp.rename(final_.path);
    } on FileSystemException catch (error) {
      throw ChapterStoreException(
        ChapterStoreFailure.renameFailed,
        cause: error,
      );
    }

    // ── step 2, and only now ────────────────────────────────────────────
    final DateTime storedAt = DateTime.now();
    await _marker.markDownloaded(chapter, storedAt);
    return storedAt;
  }

  @override
  Future<void> discardPartial(ChapterRecord chapter) async {
    final File temp = File(
      p.join(
        (await root()).path,
        chapter.novelId,
        // ⚠️ **THE SAME NAME `store()` WRITES, SPELLED ONCE HERE AND IN `store()` ABOVE.**
        // A `.part` whose name this method guessed differently from the writer's would make
        // a cancellation delete nothing while appearing to — the worst kind of half-fix.
        '.${chapter.ordinal}.md.part',
      ),
    );
    // ⚠️ **`existsSync`, LIKE `fileFor`.** A cancellation on a chapter that was never
    // mid-write is the ordinary case, not an error, and `File.delete` throws on a missing
    // path — so the predicate is what makes "nothing to discard" a state rather than a
    // crash inside `5-2`'s `cancel()`.
    if (temp.existsSync()) {
      await temp.delete();
    }
    // ⚠️ **AND NOTHING ELSE.** No mark, no row, no `.md`. `discardPartial` is a courtesy
    // call and must never become a second deletion path (B32/C4).
  }

  @override
  Future<void> deleteOne(ChapterRecord chapter) async {
    final File? file = await fileFor(chapter);
    if (file != null) {
      // ⚠️ **A missing file is NOT an error** — `fileFor` returned `null` and the outcome
      // the reader asked for is the state they are already in.
      await file.delete();
    }
    // ⚠️ **And the `chapters` row stays.** B9 requires the list to remain complete
    // whatever its length; deleting the row would lose a 10 000-chapter novel's list
    // because one file went.
    await _marker.clearDownloaded(chapter);
  }
}

/// The database half of [ChapterStore.store]'s two-write order.
///
/// ⚠️ **An interface with two methods, not a database**, so the order can be asserted by a
/// test that records call order — which is the only way ADR-022's rule is checkable.
abstract interface class ChapterMarker {
  /// Sets `downloaded_at` for [chapter]. Throws on failure, and the caller has **already
  /// written the file** by then.
  Future<void> markDownloaded(ChapterRecord chapter, DateTime at);

  /// Sets `downloaded_at` back to null. Never deletes the row (B9).
  Future<void> clearDownloaded(ChapterRecord chapter);
}

/// [ChapterMarker] over two closures, and no database type anywhere near it.
///
/// ⚠️ **Closures rather than an `AppDatabase`, on purpose.** This slice's tests must be able
/// to assert the *order* of the two writes — which is ADR-022's whole rule — and a test
/// that needs an executor to check a call sequence has already lost the thing it was built
/// to prove. `2-4` and `5-1` wire the real drift calls in.
final class CallbackChapterMarker implements ChapterMarker {
  const CallbackChapterMarker({required this.onMark, required this.onClear});

  /// `downloadedAt` is `null` when clearing, so one closure serves both and the two can
  /// never drift into calling different code.
  final Future<void> Function(ChapterRecord chapter, DateTime? downloadedAt)
  onMark;
  final Future<void> Function(ChapterRecord chapter) onClear;

  @override
  Future<void> markDownloaded(ChapterRecord chapter, DateTime at) =>
      onMark(chapter, at);

  @override
  Future<void> clearDownloaded(ChapterRecord chapter) => onClear(chapter);
}
