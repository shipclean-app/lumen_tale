// Lumen Tale — `3-3`'s repository: two actions on one chapter, and two prohibitions.
//
// ## ⚠️ THE FIRST PROHIBITION: THIS NEVER WRITES `chapters.downloadedAt`
//
// `downloadedAt` is written by `2-3`, **after** the atomic rename, and the ORDER of those
// two writes **is** B6 (ADR-022). A tile that showed *downloaded* before the file was
// complete would be exactly the state the column exists to make unreachable — and this
// repository is the only place `enqueue` could produce it without touching the disk.
//
// So `enqueue` writes `queue_items` and **nothing else**. A test records the SQL log and
// asserts no statement mentions `chapters` — not "no UPDATE", which a rename would pass,
// but no reference at all.
//
// ## ⚠️ THE SECOND PROHIBITION: DELETING DOES NOT DELETE THE ROW
//
// `deleteStoredCopy` removes the **file** and nulls `downloadedAt`. It **keeps** the
// `chapters` row. B9 requires the list to stay complete whatever its length, and deleting the
// row would lose a 10 000-chapter novel's list because one file was erased. Worse: the row
// is the parent that `history_entries` and `reading_positions` hang from.
//
// ## ⚠️ `requiredBytes` IS MEASURED OR IT IS NOT USED
//
// E20 forbids `~`, `≈` and `estimate` in this feature, so a space refusal may not be founded
// on a guess. The honest source is a copy **already on disk**: the size of a downloaded
// sibling is a real measurement of what this novel's chapters cost. Where there is none, the
// answer is "unknown" — and unknown does not become a refusal.

import 'package:lumen_tale/domain/downloads/download_request.dart';

/// The two actions `3-3` renders, and nothing else.
///
/// ⚠️ **THREE METHODS, NOT A QUEUE.** `5-1` owns the queue and resumes it; this slice is a
/// single enqueue, a single delete, and a cancel of a single item. A repository that grew a
/// `startNext()` here would put the lifecycle in two places.
abstract interface class ChapterActionRepository {
  /// B18 — writes `queue_items` rows for [request], in its order.
  ///
  /// ⚠️ **Never writes `chapters`.** See the file header.
  Future<EnqueueOutcome> enqueue(DownloadRequest request);

  /// B33 — removes the stored copy and **keeps the row**.
  Future<DeleteOneOutcome> deleteStoredCopy(String chapterId);

  /// B6 — removes a `queued` item; refuses once the fetch has begun.
  Future<CancelOutcome> cancelIfNotStarted(String queueItemId);

  /// E20 — free space on the device, **measured**.
  ///
  /// ⚠️ **A separate method, because a refusal needs both figures and neither implies the
  /// other.** `requiredBytes` is what a download needs; `freeBytes` is what the phone has.
  /// Collapsing them into one "fits?" boolean is how a dialog ends up saying "not enough
  /// space" with no numbers to act on.
  Future<int> freeBytes();

  /// The measured size of a stored copy of this novel's chapters, or `null` when this app
  /// has never stored one and therefore cannot know.
  ///
  /// ⚠️ **`null` MEANS UNKNOWN, and unknown never becomes a refusal.** It is not a zero and
  /// it is not an estimate; an implementation that coerced it to `0` would refuse every
  /// first download of every novel.
  Future<int?> measuredChapterBytes(String novelId);
}
