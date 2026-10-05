// Lumen Tale — the queue's interface, and the one thing it may never write.
//
// `5-1` § 2.2. Implemented by `data/downloads/drift_download_queue_repository.dart`.
//
// ## ⚠️ NO METHOD HERE WRITES `chapters.downloadedAt`. NONE. EVER.
//
// This is `5-1`'s central structural claim, and it is B19's first half made
// unreachable: *"Paused, cancelled and unfinished chapters are never marked as
// downloaded."* The mark is written by `2-3` — `FileChapterStore.store()` — **after** the
// atomic rename, and the ORDER of those two writes **is** B6 (ADR-022). A `state =
// 'done'` written before the file would produce a chapter marked downloaded that no
// fetch has written, which is precisely the state the column exists to prevent.
//
// So the consequences are mechanical rather than promised:
//
// * an item `queued`, `downloading` or `failed` **always** has `downloadedAt == null`;
// * `downloadedAt != null` with a `queued` item is unreachable, because
//   `resolveBulkChoice` excludes stored chapters.
//
// `test/domain/downloads/queue_marking_isolation_test.dart` greps `lib/` so that a third
// write site cannot be added quietly.
//
// ## ⚠️ `pending()` HAS NO `LIMIT`, AND THE LOOP TAKES ONE
//
// § 3.3 reads the head with `pending().first`, and § 9 says the `LIMIT 1` belongs **at
// the call site** so that a test can read ten items at once. A limit inside the query
// would make "the queue is in `queue_position` order" untestable — and § 10's criterion
// is exactly that.

import 'package:lumen_tale/domain/downloads/queue_entry.dart';
import 'package:lumen_tale/domain/downloads/queue_failure_code.dart';

/// The download queue, as the loop and the screens read it.
abstract interface class DownloadQueueRepository {
  /// The whole queue, **reactive** — a drift `Stream`, never a manual refresh
  /// (`05-state-management.md` rule 4).
  ///
  /// Ordered by `queue_position ASC`, because that is the reader's order and B18 is a
  /// promise about it.
  Stream<List<QueueEntry>> watchQueue();

  /// The chapters still to do, in queue order: `state = 'queued'`, `ORDER BY
  /// queue_position ASC`, **no `LIMIT`**.
  ///
  /// ⚠️ **`downloading` and `failed` are NOT returned.** B19: a paused queue is
  /// `queued` **with the queue stopped**, not a fourth state — so an in-flight row is
  /// resumed by putting it back to `queued` (`5-2`), and returning it here would make
  /// the queue re-enter the item it is already in the middle of.
  Future<List<QueueEntry>> pending();

  /// Appends [chapterIds] **in the order received**, from [firstPosition].
  ///
  /// ⚠️ **`firstPosition` defaults to the GLOBAL maximum + 1**, not the novel's: the
  /// queue is one queue, `queue_items` has no `novel_id` column and
  /// `architecture.md` § 4.5 does not provide one.
  ///
  /// ⚠️ **Returns the rows actually inserted.** A chapter that is already in the queue is
  /// **skipped, never duplicated** (§ 3.2 branch 4) — the reader tapping *Download*
  /// twice must not see a chapter twice — so the count that comes back is smaller than
  /// the count that went in, and it is the honest one.
  Future<List<QueueEntry>> enqueue(
    List<String> chapterIds, {
    int? firstPosition,
  });

  /// `queued → downloading`, `attempts += 1`, `startedAt = now`.
  ///
  /// ⚠️ **AN ITEM ALREADY `downloading` COMES BACK UNCHANGED, `attempts` included**
  /// (§ 3.3). `attempts` is B20's only record of what has been tried, so an increment
  /// here would turn a resume into a second attempt and lose the distinction E15 needs.
  Future<QueueEntry> markDownloading(String queueItemId);

  /// `downloading → done`, `finishedAt = now`, `errorCode = ''`.
  ///
  /// ⚠️ **`done` IS WRITTEN AFTER `2-3`'s `store()`, NEVER BEFORE** (§ 7). In the other
  /// order a storage exception leaves a `done` row for a chapter that is not on the
  /// disk, and C8's `12 of 50 downloaded` becomes a lie.
  Future<void> markDone(String queueItemId);

  /// `downloading → failed`, `finishedAt = now`, `errorCode = code`.
  ///
  /// ⚠️ **The code is the enum, not a `String`.** The column is text, but the value is
  /// typed at every call site so "failed" can always be read aloud (B24, C12).
  ///
  /// ⚠️ **`failed` DOES NOT CLEAR `downloadedAt`** — and there is nothing to clear: a
  /// stored chapter never enters the queue (rule 3, *do not refetch*), and a chapter
  /// that was never stored has no mark to remove. The state transition is the whole of
  /// the method.
  Future<void> markFailed(String queueItemId, QueueFailureCode code);

  /// Removes every row that is **not** `done`, and returns how many went.
  ///
  /// Used by `5-2`'s cancel and by *clear the failed list*. **Never touches
  /// `chapters`** — B32: removing a novel from the library keeps its downloaded
  /// chapters, and a queue row is state, not content.
  Future<int> clearUnfinished();

  /// ⚠️ **`5-2` § 3.1's ONE ALGORITHM: bring every in-flight row back to `queued`, once per
  /// session, and start nothing.**
  ///
  /// - `state = 'queued'`
  /// - `started_at = NULL`
  /// - **`attempts` is KEPT** — B20 counts attempts, it does not reset them
  /// - `error_code` is KEPT — an interruption is not a failure
  /// - **`downloadedAt` is not touched**, and it never could be: nothing here writes
  ///   `chapters`, and an interrupted item was never marked (ADR-022)
  ///
  /// Returns how many rows were brought back.
  ///
  /// ⚠️ **THE ABSENCE OF A `start()` IN ITS NEIGHBOURHOOD IS THE SLICE.** After this call
  /// there are `queued` rows, and the temptation is to run the loop — that is precisely the
  /// automatic resume E7 forbids (*"It does not resume on its own … The reader resumes it"*).
  /// The caller resets and returns.
  Future<int> resetInterruptedToQueued();

  /// ⚠️ **`5-3` § 3.5's `Retry`: ONE chapter, put back at the END of the queue.**
  ///
  /// - `state = 'queued'`
  /// - `queue_position = MAX(queue_position) + 1` — the last, i.e. the back of the reading
  ///   order, which is what `downloads.md` § 5 means by *"it re-enters the queue and runs
  ///   in reading order among the others"*
  /// - **`attempts` is KEPT** and incremented by the next `markDownloading` — B20
  /// - `error_code` is cleared — the reason belonged to the previous attempt
  /// - `finished_at` is cleared — the chapter is no longer finished
  ///
  /// Returns `false` and writes nothing when the row is **not** `failed`. `downloads.md`
  /// § 4's *Read-only* state is why: a `downloading` row has nothing to replay and a `done`
  /// row is a stored chapter whose removal is B33, not a Retry.
  Future<bool> retry(String queueItemId);
}
