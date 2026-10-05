// Lumen Tale — the queue's run state as the screen sees it: **derived, never stored**.
//
// `5-2` § 2.2. Pure Dart, no Flutter import (`02-architecture.md`).
//
// ## ⚠️ **NOTHING HERE IS A COLUMN, AND THE ABSENCE IS THE SLICE'S CENTRAL CLAIM**
//
// `queue_items` has `state`, `error_code` and `attempts` — nine columns in all — and
// **no `paused`, no `cancelled`, no `last_stop_reason`**. All three concepts are derived:
//
//   * **paused** is `queued` rows with the *loop* not running (`isRunning`, session state);
//   * **cancelled** is a **deletion** of the non-`done` rows (§ 3.4), not a flag;
//   * **stopped** is `error_code` on the last `failed` row, or a session stop reason.
//
// So `schemaVersion` stays at 1, no migration is written, and `downloads.md` § 8's
// `queue.status` / `queue.stopReason` columns are honoured as **values** rather than
// invented as storage.
//
// ## ⚠️ THE FIRST THREE ARE SESSION STATE AND THE LAST TWO ARE DATABASE STATE
//
// That boundary **is** B21. What is in the database survives the process being killed;
// what is in the session survives nothing — and there is no background executor that
// could put it back (E7). A `paused` queue on reopen is therefore the *correct* rendering,
// not a degraded one: the definition of the queue survived and its execution did not.
//
// ## ⚠️ `running` IS UNREACHABLE AT A SESSION'S FIRST FRAME, AND THAT IS THE POINT
//
// E7: *"It does not resume on its own when the connection returns … The reader resumes
// it."* Nothing in `lib/` sets `isRunning = true` except a tap on *Resume*, so a session
// that opens onto a running queue would be a defect with no code path that could cause it.

import 'package:lumen_tale/domain/downloads/queue_entry.dart';

/// The queue's state as the screen sees it.
///
/// ⚠️ **`interrupted` is a DOMAIN value and never a RENDERED one.** `downloads.md` § 8:
/// *"interrupted is the state after the process died and is **always reset to paused** on
/// open, never to running."* It exists so `5-2` § 3.1's reset is testable, and the screen
/// never shows it — a reader reopening the app would see *interrupted* and believe a
/// second thing had happened.
enum QueueRunState {
  /// The loop is moving. **Unreachable at the opening of a session** — E7.
  running,

  /// The reader paused it. Distinguishable from [stopped] by having a *Resume* control
  /// that resumes **without an explanation**; [stopped] has to say why.
  paused,

  /// Stopped for a reason that must be named: no connection, a full disk, a site that can
  /// no longer be read. This is E7's usual state.
  stopped,

  /// **The process died mid-item.** Not a persisted state — it is the *observation* that a
  /// `downloading` row exists at the moment the app is opened. § 3.1 converts it to
  /// [paused] on the first read, so it is transient by construction.
  interrupted,

  /// Nothing to do: every row is `done`. The queue section is **not rendered at all**.
  idle,
}

/// Why the queue stopped. **Not a column** — it is the `error_code` of the row that
/// stopped it, plus the observation that the process is no longer running.
///
/// ⚠️ **`unknown` IS A VALUE AND NOT A DEFAULT FALLBACK.** § 11.1's last row asserts that
/// an unreadable `error_code` yields `unknown` **without throwing**: a column written by an
/// older build is not "unknown", it is *unreadable*, and the screen then prints the generic
/// stopped sentence rather than inventing a cause (B24).
enum QueueStopReason {
  /// E7/E5 — the connection dropped, the DNS failed, the request timed out.
  noConnection('no_connection'),

  /// E20 — the phone is out of space. `5-3`'s `StorageFullException`.
  outOfStorage('storage_full'),

  /// B19 — the reader cancelled, and `5-2` § 3.4 deleted the unfinished rows.
  cancelled('cancelled'),

  /// B22/E4 — a site this build can no longer read. **Forty-eight chapters failing for this
  /// reason is ONE broken site, not forty-eight faults** (see `5-3` § 3.2).
  sourceUnreadable('source_layout_changed'),

  /// `17-security.md` rule 6 — the site sent `429` with a `Retry-After`, and the answer is
  /// to wait rather than to hammer. `5-3`'s addition: the *time* comes from
  /// `RateLimited.retryAfter`, never from a guess.
  rateLimited('rate_limited'),

  /// Nothing the queue can name.
  unknown('');

  const QueueStopReason(this.code);

  /// What `queue_items.error_code` holds for this reason. `unknown` is the empty string —
  /// which is the column's declared default, so "no reason recorded" and "unknown" are the
  /// same value rather than two.
  final String code;

  /// ⚠️ **THE OTHER DIRECTION, AND IT IS USED BY THE SCREEN.** `parse` answers "which
  /// reason does this code name"; `ofCode` answers "what code does this reason write", and
  /// `unknown` maps to `''` rather than to a synthetic code nobody would ever write.
  static QueueStopReason ofCode(String code) =>
      QueueStopReason.values.firstWhere(
        (QueueStopReason reason) => reason.code == code,
        orElse: () => QueueStopReason.unknown,
      );
}

/// The one object a screen consumes.
///
/// ⚠️ **ASSEMBLED BY `deriveQueueRunState` AND NOWHERE ELSE.** Three widgets reading three
/// queries and each deriving "is the queue paused" is how two of them end up disagreeing,
/// and the queue's numbers are exactly the thing C8 forbids drifting.
final class QueueRun {
  const QueueRun({
    required this.state,
    required this.stopReason,
    required this.totalCount,
    required this.doneCount,
    required this.failedCount,
    required this.activeItem,
  });

  final QueueRunState state;
  final QueueStopReason stopReason;

  /// The header's second number, **exact** (C8): `count(state = 'done')`, never 13 after a
  /// failure and never 11 after a cancellation.
  final int doneCount;

  /// How many chapters this queue covers. `entries.length`, never an estimate.
  final int totalCount;

  final int failedCount;

  /// B18 — **at most one**, because the queue is serial by construction. `null` in every
  /// state but [QueueRunState.running].
  final QueueEntry? activeItem;

  /// ⚠️ **CONVENIENCES, NOT NEW STATE.** A screen asks *"can I pause?"* and *"can I
  /// resume?"*; deriving each of those from [state] at four call sites would be four places
  /// to get the same condition wrong, and `downloads.md` § 4's rule — a control is
  /// **absent**, never disabled — is a statement about exactly these two.
  bool get canPause => state == QueueRunState.running;

  /// Every state but [QueueRunState.running] offers *Resume*, and [QueueRunState.idle]
  /// offers nothing at all because the section is not rendered.
  bool get canResume =>
      state == QueueRunState.paused || state == QueueRunState.stopped;

  /// ⚠️ **`interrupted` IS DELIBERATELY NOT A "CAN RESUME" STATE.** By the time anything
  /// reads this object in the app, § 3.1's reset has already turned it into `paused` — and
  /// a control that appeared for `interrupted` would be a control for a state the reader
  /// is never shown.
  @override
  String toString() =>
      'QueueRun(${state.name}, ${stopReason.code}, $doneCount/$totalCount done, '
      '$failedCount failed)';
}
