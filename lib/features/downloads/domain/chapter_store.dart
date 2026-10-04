// Lumen Tale — where a chapter's `.md` lives, and the two operations that put it there or
// take it away.
//
// `2-3` § 2.2. `features/downloads/domain/` — **domain, not the `data/` half**, because
// this is the interface `5-1`'s queue and `2-4`'s reader both program against, and neither
// of them should know that the implementation is a filesystem.

import 'dart:io';

/// Where a chapter's file is, and how one is stored or deleted.
///
/// ## `ChapterRecord` is NOT `Chapter`
///
/// It is the minimum this slice needs: id, novel, ordinal. A storage function that took a
/// drift row could not be tested without a database, and "does a rename happen" is a
/// question about the filesystem.
abstract interface class ChapterStore {
  /// Writes [markdown] for [chapter] and marks it downloaded.
  ///
  /// Returns the instant the file became complete.
  ///
  /// ⚠️ **Throws [ChapterStoreException] on any failure and never returns a
  /// partially-stored chapter.** B6 is "completely present and marked", and a return value
  /// for a half-written chapter would be the one way to break it.
  Future<DateTime> store({
    required ChapterRecord chapter,
    required String markdown,
  });

  /// The chapter's file, or `null` when it is not present. Used by `2-4`.
  ///
  /// ⚠️ **`Future<File?>`, and the future is not incidental.** The root is
  /// `getApplicationSupportDirectory()`, which is asynchronous, so a synchronous getter
  /// could only be synchronous by having already resolved the directory — which is
  /// exactly the assumption that breaks on a cold start.
  Future<File?> fileFor(ChapterRecord chapter);

  /// B33 — delete one chapter's copy and clear its mark.
  ///
  /// ⚠️ **Never touches the novel row, never touches sibling chapters, and never deletes
  /// the `chapters` row.** B9 requires the list to stay complete whatever its length, and a
  /// deleted row would lose a 10 000-chapter novel's list because one file was removed.
  Future<void> deleteOne(ChapterRecord chapter);
}

/// The minimum this slice needs to know about a chapter.
final class ChapterRecord {
  const ChapterRecord({
    required this.id,
    required this.novelId,
    required this.ordinal,
  });

  final String id;
  final String novelId;

  /// The site's own order (B9). **The filename is built from this and never from
  /// `number`.**
  ///
  /// ⚠️ `number` is `-1` when unparseable and restarts per volume, so a filename built
  /// from it collides across volumes — two chapters, one file, and one of them silently
  /// replaced. That reordering "was already deleted once" (§ 3.3); this is the reason it
  /// stays deleted.
  final int ordinal;

  @override
  bool operator ==(Object other) =>
      other is ChapterRecord &&
      other.id == id &&
      other.novelId == novelId &&
      other.ordinal == ordinal;

  @override
  int get hashCode => Object.hash(id, novelId, ordinal);

  @override
  String toString() => 'ChapterRecord($novelId/$ordinal)';
}

/// A storage failure, **typed**.
///
/// ⚠️ **Not an `AppException`.** That hierarchy is for failures the UI maps to a message
/// *by cause* (B22), and "the filesystem said no" is a cause the reader has no sentence
/// for — `errorStorageFull` is `5-3`'s to classify, and it classifies this.
final class ChapterStoreException implements Exception {
  const ChapterStoreException(this.reason, {this.cause});

  /// A developer-facing word, never a path and never a reader's input.
  final ChapterStoreFailure reason;

  final Object? cause;

  @override
  String toString() =>
      'ChapterStoreException(${reason.name}${cause == null ? '' : ', $cause'})';
}

/// Why a store failed. Three, and the third is the one B6 is about.
enum ChapterStoreFailure {
  /// `mkdir` or `write` refused — storage full, or the directory is not writable.
  cannotWrite,

  /// The temporary file vanished between `write` and `rename`.
  ///
  /// ⚠️ **Its own case, and it is the "misleading success" B6 names.** A `write` that
  /// reports success and produces no file is not a success; without this case a caller
  /// would go on to mark the chapter downloaded.
  temporaryFileMissing,

  /// `rename` failed.
  renameFailed,
}
