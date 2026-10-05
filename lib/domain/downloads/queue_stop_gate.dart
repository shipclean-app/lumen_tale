// Lumen Tale — the session half of the queue's control: what the reader asked for, and
// what the loop is allowed to do next.
//
// `5-2` § 3.2 / § 3.3 / § 3.4, and `5-3` § 3.2 rows 10–11.
//
// ## ⚠️ **THIS IS SESSION STATE, AND THAT IS WHY IT IS NOT IN THE DATABASE**
//
// `5-2` § 5's table is the answer to *"what survives the app closing"*: the rows are in
// `queue_items` and survive; `isRunning`, the pause request and the cancellation are here
// and survive **nothing**. That is not a limitation — it is exactly what E7 asks for, and
// the worst possible defect would be a persisted `isRunning` that restarted a fifty-chapter
// download by itself.
//
// ## ⚠️ **TWO FLAGS, BECAUSE THEY ARE CONSULTED AT TWO DIFFERENT PLACES**
//
// B19 says a pause *"stops before the next chapter"* and that a cancellation *"takes effect
// without a further action, and no further chapter is fetched after it"* — and the second
// clause is about the chapter **already in flight**. One flag cannot express both:
//
//   * `blocksNext` — consulted at the top of the loop, before `pending().first`. A pause
//     sets it and the chapter in flight is allowed to finish;
//   * `blocksWrite` — consulted after the fetch returns and **before** `store()`. Only a
//     cancellation sets it, because a cancelled chapter must not be written and marked.
//
// Merging them would either abandon a chapter the reader was told would finish, or write a
// chapter the reader cancelled.

import 'package:lumen_tale/domain/downloads/queue_run_state.dart';

/// The reader's gestures and the loop's reason for stopping, for one session.
final class QueueStopGate {
  /// ⚠️ **CALLED AFTER EVERY WRITE, AND THAT IS HOW A LOOP-DECIDED STOP REACHES THE SCREEN.**
  ///
  /// `pause()`, `resume()` and `cancel()` are notifier methods, so they can update the state
  /// they own. `storageFull()` and `stopped()` are called by the **runner**, from inside its own
  /// async turn, at a moment when no row changes — the item stays `downloading` and the drift
  /// stream emits nothing. Without this hook a queue that stopped because the disk filled would
  /// keep drawing *Paused* until something else happened to rebuild the screen.
  ///
  /// Pure Dart and a bare closure, not a `Listenable`: `domain/` may import
  /// `package:flutter/foundation` only where strictly needed, and a plain function is all the
  /// wiring this needs.
  void Function()? onWrite;

  bool _wantPause = false;
  bool _cancelled = false;

  /// `null` — never "unknown". A queue that has not stopped has **no** reason.
  QueueStopReason? _stoppedFor;

  /// `RateLimited.retryAfter` measured from the moment the 429 arrived, and **not
  /// persisted**: `queue_items.error_code` holds a code, not a clock reading, and E7's row
  /// says the screen must name the *time*. Session state is the only honest home for it.
  DateTime? _resumeNotBefore;

  /// ⚠️ **E20'S ONE MEASURED FIGURE, AND IT IS SESSION STATE FOR THE SAME REASON AS
  /// `_resumeNotBefore`.** `queue_items.error_code` holds `storage_full`; it cannot hold how
  /// many bytes the chapter needed, and adding a column for one figure is the schema change
  /// `5-2` § 2.1 refuses. `null` whenever the queue did not stop for a full disk, and
  /// `null` is rendered as **no figure at all** rather than as `0` (C8).
  int? _storageBytesNeeded;

  bool get wantPause => _wantPause;

  /// B19 — the reader cancelled. `true` even after the loop has already stopped, because
  /// § 3.5's failure branch has to be able to tell the two situations apart.
  bool get cancelled => _cancelled;

  /// Why the queue is stopped, or `null`. Set by `resume()` refusing offline and by the
  /// loop when a `store()` threw — the two cases § 3.2's table gives no `failed` row for.
  QueueStopReason? get stoppedFor => _stoppedFor;

  /// When the site said to try again, or `null`. Rendered as a clock time so the reader is
  /// not told merely "later".
  DateTime? get resumeNotBefore => _resumeNotBefore;

  /// What the chapter the app was writing needed, in bytes, or `null`.
  int? get storageBytesNeeded => _storageBytesNeeded;

  /// ⚠️ **READ AT THE TOP OF THE LOOP, BEFORE `pending().first`.** This is the *only* place
  /// B19's *"no further chapter is fetched after it"* is enforceable, and a gate consulted
  /// after the fetch would have already spent the request.
  bool get blocksNext => _cancelled || _wantPause;

  /// ⚠️ **READ AFTER THE FETCH AND BEFORE `store()`.** A cancelled chapter leaves the
  /// device with no file and no mark, which is the direction B6 and C8 both want: the
  /// chapter offers itself for download again rather than opening as complete.
  bool get blocksWrite => _cancelled;

  /// B19 — pause. Idempotent, and it writes nothing: the flag lives here and in memory.
  void requestPause() {
    _wantPause = true;
    onWrite?.call();
  }

  /// B19 — cancel. § 3.4's step 2 runs **before** the database write, so a write that fails
  /// can put the loop back (§ 3.5).
  void cancel() {
    _cancelled = true;
    _stoppedFor = QueueStopReason.cancelled;
    onWrite?.call();
  }

  /// E7/E5 — `resume()` was refused because the phone has no connection. **No chapter is
  /// started**, and the queue reads `stopped` rather than silently doing nothing.
  void blockFor(QueueStopReason reason, {DateTime? notBefore}) {
    _stoppedFor = reason;
    _resumeNotBefore = notBefore;
    onWrite?.call();
  }

  /// E20 — the disk is full and here is the one figure the app can state.
  void storageFull(int bytesNeeded) {
    _stoppedFor = QueueStopReason.outOfStorage;
    _storageBytesNeeded = bytesNeeded;
    onWrite?.call();
  }

  /// The loop stopped for a cause of its own (`5-3` § 3.2 rows 10 and 11).
  void stopped(QueueStopReason reason, {DateTime? notBefore}) {
    _stoppedFor = reason;
    _resumeNotBefore = notBefore;
    _storageBytesNeeded = null;
    onWrite?.call();
  }

  /// *Resume*, and the one place a stop reason is forgotten.
  ///
  /// ⚠️ **CLEARING `_stoppedFor` IS NOT OPTIONAL.** A stale `outOfStorage` reason would
  /// keep rendering *the phone is out of storage* after the reader freed space and pressed
  /// *Resume* — a queue stopped for yesterday, on a phone that is fine today.
  void clearStop() {
    _wantPause = false;
    _cancelled = false;
    _stoppedFor = null;
    _resumeNotBefore = null;
    _storageBytesNeeded = null;
    onWrite?.call();
  }

  /// ⚠️ **A DEBUG-FREE `toString`, and it names the flags rather than the class.** A log
  /// line about the queue is something an owner reads aloud, and `QueueStopGate` carries no
  /// chapter text, no title and no URL (`13-error-handling.md` rule 6).
  @override
  String toString() =>
      'QueueStopGate(pause: $_wantPause, cancelled: $_cancelled, stoppedFor: '
      '${_stoppedFor?.code ?? 'none'})';
}
