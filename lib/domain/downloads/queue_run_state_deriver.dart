// Lumen Tale — the ONE pure function that decides what the downloads screen says.
//
// `5-2` § 2.2, and § 11.1's nine rows.
//
// ## ⚠️ **THE ORDER OF THE BRANCHES IS LOAD-BEARING, AND IT IS WRITTEN IN THIS ORDER ON
// PURPOSE**
//
// `5-2` § 2.2 wrote five branches in a fixed order, and two of them still govern:
//
//   * **`idle` first of all** — a queue with nothing unfinished has nothing to say, and every
//     other branch would be describing a chapter that does not exist;
//   * **`downloading` before the `failed` branch** — a row in flight outranks a row that
//     failed, because the loop reached the in-flight row *after* the failure and B18 fixes
//     the order as reading order.
//
// And one branch `5-2` could not have anticipated:
//
//   * **a session stop reason before `interrupted`** — `5-3` § 3.2 row 10 leaves an item
//     `downloading` **on purpose** when the disk fills, and read as `interrupted` that is
//     indistinguishable from a process death. A reason that exists can only have come from a
//     **live** process, so it is authoritative; `interrupted` asserts the opposite.
//
// ## ⚠️ **PURE, AND THAT IS WHAT MAKES TWELVE CASES TESTABLE**
//
// `5-3` § 3.2 needed twelve outcomes for the loop's decision, and it got them by making
// *that* function pure. This one is the same move: no database, no clock, no file, so every
// branch is reachable from a literal list of rows.

import 'package:lumen_tale/core/database/app_database.dart';
import 'package:lumen_tale/domain/downloads/queue_entry.dart';
import 'package:lumen_tale/domain/downloads/queue_run_state.dart';

/// The queue's run state, derived from the rows and the process.
///
/// [sessionStopReason] is the queue's **session** stop reason — the two cases where no
/// `failed` row exists to be read: `resume()` refused because the phone is offline, and a
/// `store()` that threw (`5-3` § 3.2 rows 10 and 11). Those are judgements about the
/// **queue**, not about a chapter, and B22 says the two must not be confused.
///
/// ⚠️ **IT IS CHECKED AFTER `isRunning` AND BEFORE THE `failed` BRANCH.** A stopped session
/// reason means no chapter was judged to have failed, so there is no `failed` row for the
/// fourth branch to read — and putting it earlier would let a stale session reason outlive
/// the `failed` row that superseded it.
QueueRun deriveQueueRunState({
  required List<QueueEntry> entries,
  required bool isRunning,
  QueueStopReason? sessionStopReason,
}) {
  final List<QueueEntry> unfinished = entries
      .where((QueueEntry e) => e.state != DownloadState.done)
      .toList();
  final int done = entries
      .where((QueueEntry e) => e.state == DownloadState.done)
      .length;
  final List<QueueEntry> failed = entries
      .where((QueueEntry e) => e.state == DownloadState.failed)
      .toList();
  final List<QueueEntry> downloading = entries
      .where((QueueEntry e) => e.state == DownloadState.downloading)
      .toList();

  // ── 1. nothing to do ──────────────────────────────────────────────────────
  if (unfinished.isEmpty) {
    return QueueRun(
      state: QueueRunState.idle,
      stopReason: QueueStopReason.unknown,
      totalCount: entries.length,
      doneCount: done,
      failedCount: 0,
      activeItem: null,
    );
  }

  // ── 3. the loop is moving ─────────────────────────────────────────────────
  if (isRunning) {
    return QueueRun(
      state: QueueRunState.running,
      stopReason: QueueStopReason.unknown,
      totalCount: entries.length,
      doneCount: done,
      failedCount: failed.length,
      // ⚠️ **`first`, NOT THE ONLY ONE.** B18 makes the queue serial *by construction*, so
      // there is at most one — but `first` is what keeps a second one from ever being the
      // name of the running chapter.
      activeItem: downloading.isEmpty ? null : downloading.first,
    );
  }

  // ── 4. the loop is not moving and **the process decided that** ────────────
  // ⚠️ **⚠️ `5-3` MOVED THIS ABOVE THE `interrupted` BRANCH, AND IT HAD TO BE MOVED.**
  //
  // § 2.2 places the `downloading` observation second and says nothing about a session
  // reason — because in `5-2` there was no session reason to place. `5-3` § 3.2 row 10 adds
  // one: a `store()` that hit `ENOSPC` leaves the item **`downloading` on purpose** and stops
  // the queue. Read as `interrupted`, that state is indistinguishable from a process death —
  // and the reader is told nothing about a phone that has no space.
  //
  // The two are categorically different: `interrupted` means *nothing here is running*,
  // while a session reason means *the process is alive and it stopped*. A reason that exists
  // can only come from a live process, so it is authoritative.
  if (sessionStopReason != null) {
    return QueueRun(
      state: QueueRunState.stopped,
      stopReason: sessionStopReason,
      totalCount: entries.length,
      doneCount: done,
      failedCount: failed.length,
      activeItem: null,
    );
  }

  // ── 5. the process died mid-item ──────────────────────────────────────────
  // ⚠️ **`downloading` BEFORE THE `failed` BRANCH.** See the file header for why it is before
  // `isRunning`, and § 3.1 for why `isRunning` never reaches here with a `downloading` row.
  if (downloading.isNotEmpty) {
    return QueueRun(
      state: QueueRunState.interrupted,
      stopReason: QueueStopReason.unknown,
      totalCount: entries.length,
      doneCount: done,
      failedCount: failed.length,
      activeItem: null,
    );
  }

  // ── 6. the loop is not moving and a chapter failed ─────────────────────────
  if (failed.isNotEmpty) {
    final QueueEntry lastFailure = failed.last;
    return QueueRun(
      state: QueueRunState.stopped,
      stopReason: queueStopReasonFromCode(lastFailure.errorCode),
      totalCount: entries.length,
      doneCount: done,
      failedCount: failed.length,
      activeItem: null,
    );
  }

  // ── 7. not moving, nothing failed → paused on purpose ─────────────────────
  // ⚠️ **NOT `stopped`, AND THE REASON IS WORTH WRITING DOWN.** A stopped queue needs a
  // reason it can say out loud (C12). A reader who paused their own queue does not need a
  // reason — and rendering `stopped` here would show a *fault* for a deliberate act.
  return QueueRun(
    state: QueueRunState.paused,
    stopReason: QueueStopReason.unknown,
    totalCount: entries.length,
    doneCount: done,
    failedCount: 0,
    activeItem: null,
  );
}

/// The reason a stored `error_code` names.
///
/// ⚠️ **`QueueFailureCode.parse` ANSWERS `null` FOR A CODE IT DOES NOT KNOW, AND THIS MAPS
/// `null` TO `unknown` RATHER THAN THROWING.** B24: an unrecognised code must still produce
/// a screen, and the screen's generic stopped sentence says *"nothing is downloading"*
/// without guessing a cause. A `StateError` here would take the downloads screen down
/// because one row carried a value an older build wrote.
QueueStopReason queueStopReasonFromCode(String errorCode) {
  // ⚠️ **`item_removed_at_source` AND `source_unavailable` ARE *ALSO* A BROKEN SITE.**
  // § 3.2's table names four stopping causes and the enum names the words; these two say
  // the same thing about the same thing (B22: forty-eight identical failures are ONE
  // broken site), so a reader is told *why* rather than being shown forty-eight rows.
  return switch (errorCode) {
    'no_connection' => QueueStopReason.noConnection,
    'rate_limited' => QueueStopReason.rateLimited,
    'source_layout_changed' => QueueStopReason.sourceUnreadable,
    'source_unavailable' => QueueStopReason.sourceUnreadable,
    'storage_full' => QueueStopReason.outOfStorage,
    'cancelled' => QueueStopReason.cancelled,
    _ => QueueStopReason.unknown,
  };
}
