// Lumen Tale — the loop that drains the queue, and what it deliberately does not know.
//
// `5-1` § 2.2. Implemented by `data/downloads/serial_download_queue_runner.dart`.
//
// ## ⚠️ SERIAL BY CONSTRUCTION, AND THAT IS THE WHOLE OF B18's FIRST CLAUSE
//
// B18: *"Downloading a novel enqueues its chapters **one at a time** in reading order."*
// `architecture.md` § 4.5 deleted the concurrency column to make this unchangeable —
// "a constant expressed as a column is something an implementation could change" — and
// `test/core/database/app_database_test.dart` asserts that column's **absence**. So this
// interface offers no concurrency knob, no `take(n)`, and no batch call: the only way to
// run the loop is `while` + `pending().first`.
//
// ## ⚠️ IT KNOWS NOTHING OF PAUSING
//
// `5-1` takes the next chapter, fetches it, writes it, and moves on. `5-2` adds the
// pause gate and the cancellation **on top**, and `5-3` decides, per cause, whether a
// lost connection stops the queue while an unreadable chapter does not. Neither decision
// belongs here: writing `if (reason is NoConnection) break` in this slice would be
// `5-3`'s work in the wrong file, untested by `5-3`'s tests.

import 'package:lumen_tale/domain/downloads/queue_entry.dart';

/// The drain loop.
abstract interface class DownloadQueueRunner {
  /// Starts — or wakes — the loop. **Idempotent**: calling it twice does not start two
  /// loops, because two loops over one queue is exactly the parallelism B18 forbids and
  /// a reader who taps *Download* twice would see a chapter fetched twice.
  void start();

  /// Is the loop moving right now?
  ///
  /// ⚠️ **`false` when a session opens, always** (E7, § 7). It is session state and never
  /// derived from the database, so **no automatic resume is possible even by accident** —
  /// which is the property E15 needs and the reason this is a field rather than
  /// `queue_items.state != done`.
  bool get isRunning;

  /// The chapter being fetched, or `null`.
  QueueEntry? get activeItem;

  /// Waits for the loop in progress to end, **and rethrows what ended it**.
  ///
  /// ⚠️ **Used by the tests and by `5-2`'s cancel.** A storage failure must reach
  /// `5-3` (§ 3.3's last row) — swallowed here it would leave an item `downloading` with
  /// no explanation anywhere, and a queue that stops without saying why is E7's over-
  /// promise in miniature.
  Future<void> drain();
}
