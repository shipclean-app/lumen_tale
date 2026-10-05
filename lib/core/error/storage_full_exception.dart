// Lumen Tale — E20: the phone has no room left.
//
// `5-3` § 2.2. `core/error/`, beside the other typed failures.
//
// ## ⚠️ **A STANDALONE `Exception`, NOT A SUBCLASS OF `AppException` — AND HERE IS WHY**
//
// `13-error-handling.md` permits a subclass "only when a caller needs to `on X catch` it
// specifically", and `2-3`'s `ChapterStoreException` is already a standalone type with its own
// documented reason: *"that hierarchy is for failures the UI maps to a message **by cause**,
// and 'the filesystem said no' is a cause the reader has no sentence for."*
//
// The first version of this file extended `AppException` — and `AppException` is **`sealed`**,
// so every exhaustive `switch` over it in the codebase became non-exhaustive. Two of them
// (`core/ui/app_error_copy.dart` and `data/updates/drift_check_library.dart`) had to grow an
// arm, and the second belongs to a slice this one does not own. **A sealed hierarchy charges
// every addition to every reader of it**, and a full disk is a *write* failure that never
// arrives as a `BrowseFailed`.
//
// ## ⚠️ **THE ONE `catch` THAT JUSTIFIES THE TYPE AT ALL**
//
// ```dart
// } on StorageFullException catch (e) {
//   1) STOP the queue — impossible without the class, because `ChapterStoreException`
//      covers a missing directory and a failed rename just as well as ENOSPC;
//   2) say "free up some space, then resume" INSTEAD OF "try again" — C12 requires those
//      to be two different sentences, and a reader who follows "try again" twice has been
//      misinformed;
//   3) show `bytesNeeded` — `architecture.md` § 5.2 says `StorageFull` *carries* it.
// }
// ```
//
// The opposite arrangement is explicitly refused in `5-3` § 7.6: catching `Exception` and
// testing `e.message.contains('space')` is free text in a `switch`, and `13-error-handling.md`
// rule 5 forbids exactly that.
//
// ## ⚠️ **`bytesNeeded` IS AN ESTIMATE OF ONE CHAPTER, NOT OF THE QUEUE**
//
// A full disk is a whole-queue condition and this is a per-chapter figure: the number of
// bytes the chapter the app was writing needs. It is **not** free space — `downloads.md` § 9
// refuses to display free space at all, because the app has no honest way to read it without
// a platform channel it has not earned, and a number that goes stale in seconds is worse
// than no number. What is honest is *"this chapter needs this much"* and *"the phone has run
// out"*.

import 'package:lumen_tale/core/utils/logger.dart';

/// The phone is out of storage, or the system refused the write.
final class StorageFullException implements Exception {
  const StorageFullException(this.bytesNeeded, {this.cause});

  /// What the chapter the app was writing needs, in bytes.
  ///
  /// ⚠️ **NEVER `0` AS "UNKNOWN".** A caller that cannot estimate the size has no reason to
  /// construct this exception at all — the generic storage path (`5-3` § 3.2 row 11) exists
  /// for that, and it renders a sentence that does not guess.
  final int bytesNeeded;

  /// The primitive error underneath, kept for on-device diagnosis. `13-error-handling.md`
  /// rule 2 — a `FileSystemException` never crosses into the queue's own vocabulary.
  final Object? cause;

  /// ⚠️ **LOGGED WITH THE LOGGER, NOT `toString()`'d BY A CALLER.** `13-error-handling.md`
  /// rule 6 requires `logger`, and the line names the size and nothing else: no chapter text,
  /// no title, no path.
  void logStoppedWriting(String queueItemId) => logError(
    'download queue stopped: storage full writing $queueItemId',
    this,
    cause: cause,
    name: 'lumen.queue',
  );

  @override
  String toString() => 'StorageFullException: need ${bytesNeeded}B';
}
