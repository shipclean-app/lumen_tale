// Lumen Tale — `3-3`'s domain contract: what the reader asked for, and what came back.
//
// ## ⚠️ `DownloadRequest` TAKES A LIST, AND THAT IS THE WHOLE POINT
//
// B18 says the sixth download scope is "a hand-picked set". A **range** — `from`, `to`,
// `count` — is an *intention*: it is only correct while the list behind it does not move,
// and a novel's chapter list grows, shrinks and reorders at the site. A list is a **fact**:
// it was true when the reader tapped, and the queue executes exactly it.
//
// So "the next 25 chapters" is converted to a list **once**, at the tap, and is never
// re-derived. That is why this type has no `from`, no `to` and no `count` field — and a row
// asserts their absence, because a range that crept in would be invisible.
//
// ## ⚠️ THE TWO PROHIBITIONS LIVE IN `data/`, NOT HERE
//
// The UI **never** writes `chapters.downloadedAt`. That column is written by `2-3`, *after*
// the atomic rename, and the ORDER of those two writes **is** B6 (ADR-022). A tile that
// showed "downloaded" before the file was complete would be exactly the state the column
// exists to make unreachable — and the interface is the only place it could be produced
// without touching the disk.
//
// Second: deleting a chapter's copy does **not** delete its row. It removes the file and
// nulls `downloadedAt`. B9 requires the list to stay complete whatever its length, and
// deleting the row would lose a 10 000-chapter novel's list because one file was erased.

import 'package:lumen_tale/core/error/source_failure.dart';

/// **What the reader asked for.** A value, not a procedure.
///
/// ⚠️ **One type for every scope, and not an enum of six.** "The next chapter" and "the 25
/// I picked" are the *same* action at different scales; reducing them to six enum values
/// would give six code paths, and five of them are not actions a reader performs.
final class DownloadRequest {
  const DownloadRequest({required this.chapterIds});

  /// `List.unmodifiable`, because a request is a value and a caller that mutates one has
  /// turned a read into an edit.
  factory DownloadRequest.of(Iterable<String> ids) =>
      DownloadRequest(chapterIds: List<String>.unmodifiable(ids));

  /// B18 — an **explicit list, in this order**, never a computed range.
  final List<String> chapterIds;

  bool get isEmpty => chapterIds.isEmpty;

  int get length => chapterIds.length;

  @override
  bool operator ==(Object other) {
    if (other is! DownloadRequest) return false;
    if (other.chapterIds.length != chapterIds.length) return false;
    // ⚠️ **AN INDEXED COMPARISON, not a set comparison.** Two requests naming the same
    // chapters in a DIFFERENT order are different requests: B18 says `queuePosition` follows
    // `inThisOrder`, so equality has to see the order or two different queue plans would
    // compare equal and a cache could serve one for the other.
    for (int i = 0; i < chapterIds.length; i++) {
      if (chapterIds[i] != other.chapterIds[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll(chapterIds);

  @override
  String toString() => 'DownloadRequest(${chapterIds.length} chapters)';
}

/// Why an enqueue did not happen.
///
/// ⚠️ **A value per reason, never a bool.** "It did not work" is the sentence B22 exists to
/// end, and the interface cannot tell the reader *which* of these it was without a reason it
/// can name.
sealed class EnqueueOutcome {
  const EnqueueOutcome();
}

/// The rows are in `queue_items`, and this request is queued.
final class EnqueueQueued extends EnqueueOutcome {
  const EnqueueQueued({required this.queued});

  /// How many rows were written. ⚠️ **Not `chapterIds.length`** — a request can be partly
  /// refused, and reporting the request's size would claim work the queue never accepted.
  final int queued;

  @override
  String toString() => 'EnqueueQueued($queued)';
}

/// Every chapter in the request is already stored (B6) — **nothing was written at all.**
final class EnqueueAlreadyStored extends EnqueueOutcome {
  const EnqueueAlreadyStored();
}

/// Some chapters are already stored and some are not: the stored ones were **skipped**, the
/// rest queued. ⚠️ **A partial result is its own value**, because "nothing happened" and
/// "some happened" are different sentences and a count of zero covers both.
final class EnqueuePartlyStored extends EnqueueOutcome {
  const EnqueuePartlyStored({required this.queued, required this.skipped});

  final int queued;
  final int skipped;

  @override
  String toString() =>
      'EnqueuePartlyStored(queued: $queued, skipped: $skipped)';
}

/// E20 — not enough free space to promise the download.
///
/// ⚠️ **BOTH NUMBERS, and both MEASURED.** `requiredBytes` and `freeBytes` are the two
/// things a reader can act on: "you need this much, you have that much". ⚠️ **Never an
/// estimate** — `grep` asserts no `~`, no `≈` and no "estimate" in this feature, because a
/// guessed size cannot be the basis of a refusal and cannot be the basis of a promise.
final class EnqueueRefusedForSpace extends EnqueueOutcome {
  const EnqueueRefusedForSpace({
    required this.requiredBytes,
    required this.freeBytes,
  });

  final int requiredBytes;
  final int freeBytes;

  @override
  String toString() =>
      'EnqueueRefusedForSpace(need $requiredBytes, have $freeBytes)';
}

/// A typed failure, so the UI can say WHY (B24) rather than "failed".
final class EnqueueFailed extends EnqueueOutcome {
  const EnqueueFailed(this.failure);

  final SourceFailure failure;

  @override
  String toString() => 'EnqueueFailed($failure)';
}

/// Why a delete did not happen.
sealed class DeleteOneOutcome {
  const DeleteOneOutcome();
}

/// The file is gone, `downloadedAt` is null, **and the `chapters` row still exists.**
final class DeleteOneRemoved extends DeleteOneOutcome {
  const DeleteOneRemoved({required this.freedBytes});

  /// ⚠️ **The MEASURED size, read before the unlink.** `File.lengthSync()` after the file is
  /// gone is zero, and reporting zero would tell a reader they got no space back when they
  /// did. It is also the only figure that can be true: the file's size on disk is what the
  /// filesystem actually reclaimed.
  final int freedBytes;

  @override
  String toString() => 'DeleteOneRemoved($freedBytes bytes)';
}

/// There was no stored copy. ⚠️ **Zero writes**, and the UI must not say "deleted" — nothing
/// was deleted, and a confirmation for a no-op teaches a reader that confirmations are
/// decorative.
final class DeleteOneNothingToRemove extends DeleteOneOutcome {
  const DeleteOneNothingToRemove();
}

/// The file could not be removed.
///
/// ⚠️ **The tile stays in its downloaded state.** The mark is written after the file, and a
/// file that survived must keep its mark — the alternative is a tile claiming a copy that is
/// still on the disk, which is the reverse lie of the one B6 prevents.
final class DeleteOneFailed extends DeleteOneOutcome {
  const DeleteOneFailed(this.failure);

  final SourceFailure failure;

  @override
  String toString() => 'DeleteOneFailed($failure)';
}

/// Why a cancel did not happen.
sealed class CancelOutcome {
  const CancelOutcome();
}

/// The item had not started, so it was removed from the queue.
final class CancelRemoved extends CancelOutcome {
  const CancelRemoved();
}

/// B6 — the fetch has already begun, so cancelling would leave a half-written file whose
/// completion nothing is watching.
///
/// ⚠️ **No file is touched and `downloadedAt` is unchanged.** The item finishes, and the
/// chapter becomes stored normally: a cancel that arrived one moment too late costs the
/// reader their cancel, not their chapter.
final class CancelTooLate extends CancelOutcome {
  const CancelTooLate();
}
