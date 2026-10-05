// Lumen Tale — the reader's three controls over the queue: pause, resume, cancel.
//
// `5-2` § 4.2 / § 5, plus `5-3` § 3.5's `retry`. `features/downloads/providers/`, because
// these are **UI-facing** handles; the orchestration they drive lives in `data/`
// (`02-architecture.md`: orchestration is not a presentation).
//
// ## ⚠️ **`keepAlive`, AND THE REASON IS E7 RATHER THAN CONVENIENCE**
//
// `05-state-management.md` rule 10: *"Never `keepAlive` a provider without a stated
// reason."* Two reasons, and the second costs:
//
//  1. the gate holds `isRunning`, which is **session** state, so `autoDispose` would flip it
//     to `false` when the reader popped the downloads screen and present a running queue as
//     a stopped one — a lie C8 and C12 both forbid;
//  2. `5-1`'s runner is built once for the session, and a control notifier that died with
//     its last screen would leave `downloadQueueRunnerProvider`'s loop with nothing to stop
//     it.
//
// ## ⚠️ **THE SESSION RESET RUNS ONCE, AND IT STARTS NOTHING**
//
// § 3.1's table has four openings and the correct behaviour in every one of them is the
// same: bring the in-flight rows back to `queued`, keep `attempts`, **and do not start the
// loop**. The temptation is right there in the code — after the reset there are `queued`
// rows, and the instinct says *go on then*. That is exactly the promise E7 forbids:
// *"It does not resume on its own when the connection returns … The reader resumes it."*
//
// ## ⚠️ **`cancel()` SETS THE FLAG **BEFORE** THE DATABASE WRITE, AND THAT ORDER IS § 3.5**
//
// A cancellation whose write fails must leave the reader looking at a **running** queue plus
// the sentence *"Could not cancel. The download is still running."* — the one submission in
// the app whose failure has to *invert* the display, because a queue shown as cancelled
// while chapters keep landing on the phone is exactly what B19 forbids. Putting the flag
// first means the loop has already stopped by the time the write is attempted, and the
// recovery is a single `start()`.

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lumen_tale/core/database/app_database.dart';
import 'package:lumen_tale/core/error/app_exception.dart';
import 'package:lumen_tale/domain/downloads/connection_probe.dart';
import 'package:lumen_tale/domain/downloads/download_queue_repository.dart';
import 'package:lumen_tale/domain/downloads/download_queue_runner.dart';
import 'package:lumen_tale/domain/downloads/queue_entry.dart';
import 'package:lumen_tale/domain/downloads/queue_run_state.dart';
import 'package:lumen_tale/domain/downloads/queue_stop_gate.dart';
import 'package:lumen_tale/features/downloads/domain/chapter_store.dart';
import 'package:lumen_tale/features/downloads/providers.dart';
import 'package:lumen_tale/features/downloads/providers/download_queue_provider.dart';

/// E7/E5 — replaced at the bootstrap and in tests. See `connection_probe.dart` for why the
/// production answer is "no evidence against trying" and why that is not a claim of network.
final connectionProbeProvider = Provider<ConnectionProbe>(
  (Ref ref) => const OptimisticConnectionProbe(),
);

/// The gate. **One instance for the session** — the loop and this notifier must read the
/// same flags, and a second gate would be a queue the reader cannot stop.
final queueStopGateProvider = Provider<QueueStopGate>(
  (Ref ref) => QueueStopGate(),
);

/// What the reader's controls are currently doing.
final class QueueControlState {
  const QueueControlState({
    required this.isRunning,
    required this.wantPause,
    required this.stoppedFor,
    required this.resumeNotBefore,
    required this.storageBytesNeeded,
  });

  /// E7 — session state, never the database. `false` at a session's first frame, always.
  final bool isRunning;

  /// B19 — a pause has been asked for and the loop will stop before the next chapter.
  final bool wantPause;

  /// ⚠️ **`null` WHEN NOTHING STOPPED IT.** Not [QueueStopReason.unknown]: "no reason" and
  /// "a reason we cannot name" are different facts, and conflating them would print a
  /// fault for a queue the reader simply paused.
  final QueueStopReason? stoppedFor;

  /// `17-security.md` rule 6 — the site sent `Retry-After` and the screen names the time.
  final DateTime? resumeNotBefore;

  /// E20 — what the chapter the app was writing needed, in bytes, or `null`. **Never
  /// free space**: `downloads.md` § 9 refuses to display it and a stale number is worse
  /// than none. `null` renders no figure at all rather than `0`.
  final int? storageBytesNeeded;

  QueueControlState copyWith({
    bool? isRunning,
    bool? wantPause,
    QueueStopReason? stoppedFor,
    DateTime? resumeNotBefore,
    int? storageBytesNeeded,
    bool clearStoppedFor = false,
    bool clearResumeNotBefore = false,
    bool clearStorageBytesNeeded = false,
  }) => QueueControlState(
    isRunning: isRunning ?? this.isRunning,
    wantPause: wantPause ?? this.wantPause,
    storageBytesNeeded: clearStorageBytesNeeded
        ? null
        : (storageBytesNeeded ?? this.storageBytesNeeded),
    // ⚠️ **THE TWO `clear` FLAGS EXIST BECAUSE `null` IS A VALUE HERE.** A `copyWith`
    // cannot distinguish "leave it" from "clear it", and *Resume* must clear a stop reason
    // — otherwise a queue stopped yesterday for a full disk keeps saying so today.
    stoppedFor: clearStoppedFor ? null : (stoppedFor ?? this.stoppedFor),
    resumeNotBefore: clearResumeNotBefore
        ? null
        : (resumeNotBefore ?? this.resumeNotBefore),
  );

  @override
  String toString() =>
      'QueueControlState(running: $isRunning, pause: $wantPause, stoppedFor: '
      '${stoppedFor?.code ?? 'none'})';
}

/// The three controls, and nothing else.
final downloadQueueControlProvider =
    NotifierProvider<QueueQueueControl, QueueControlState>(
      QueueQueueControl.new,
    );

/// ⚠️ **`QueueQueueControl` IS AN AWKWARD NAME AND IT IS CORRECT.** Riverpod 3 derives the
/// provider's generic from the notifier type, and `DownloadQueueControl` would collide with
/// the sibling `DownloadQueueNotifier` from `5-1` in every reader's mental file. The name
/// says what it is — the **queue**'s control — and a collision avoided at the type level is
/// cheaper than a collision discovered in a screen.
class QueueQueueControl extends Notifier<QueueControlState> {
  /// § 3.1's once-per-session reset. **`null` until first asked**, and that is what makes
  /// "once" a property of the object rather than of a call site remembering.
  Future<void>? _sessionReset;

  DownloadQueueRepository get _queue =>
      ref.read(downloadQueueRepositoryProvider);

  DownloadQueueRunner get _runner => ref.read(downloadQueueRunnerProvider);

  QueueStopGate get _gate => ref.read(queueStopGateProvider);

  @override
  QueueControlState build() {
    // ⚠️ **THE RESET IS FIRED FROM `build()` AND ITS FUTURE IS KEPT.** It runs once, at the
    // first read of this provider, which is the first screen that looks at the queue — and
    // § 3.1 says it runs "once per session, at the first watch of the provider, and never
    // otherwise". A test needs to *await* it, so it is stored rather than floated away.
    unawaited(onSessionStart());
    return const QueueControlState(
      isRunning: false,
      wantPause: false,
      stoppedFor: null,
      resumeNotBefore: null,
      storageBytesNeeded: null,
    );
  }

  /// ⚠️ **RESET, DO NOT START.** The whole of § 3.1, and the one line a future session is
  /// most likely to "fix" in the wrong direction.
  Future<void> onSessionStart() => _sessionReset ??= _queue
      .resetInterruptedToQueued()
      .then<void>((int _) {});

  /// Re-reads the gate into the state, after a write the **loop** made.
  ///
  /// ⚠️ **THE GATE IS THE SINGLE SOURCE OF TRUTH AND THIS IS ITS PROJECTION.** Every field of
  /// [QueueControlState] that describes a *stop* comes from here rather than from whichever
  /// method happened to be called — so a stop reached through the runner and a stop reached
  /// through `resume()` produce the same state, and a test can assert one of them and read
  /// about the other.
  void syncFromGate() {
    state = QueueControlState(
      isRunning: _runner.isRunning,
      wantPause: _gate.wantPause,
      stoppedFor: _gate.stoppedFor,
      resumeNotBefore: _gate.resumeNotBefore,
      storageBytesNeeded: _gate.storageBytesNeeded,
    );
  }

  /// B19 — *"Stop before the next chapter."*
  ///
  /// ⚠️ **IDEMPOTENT, AND IT WRITES NOTHING.** § 3.2's fourth row: a pause on a queue that
  /// is already paused produces no database write at all, because a paused queue is
  /// `queued` rows with the loop stopped — there is no flag in the table to set.
  ///
  /// ⚠️ **IT DOES NOT INTERRUPT THE CHAPTER IN FLIGHT.** § 3.2's second row: that chapter
  /// finishes, is stored and is marked, and then nothing more is fetched. Interrupting it
  /// would leave a `.part` behind and — worse — a row `downloading` with no loop running,
  /// which is exactly the `interrupted` state E15 reserves for a **process death**. A
  /// reader who paused could no longer tell "I paused this" from "this crashed".
  void pause() {
    // ⚠️ **`_runner.isRunning`, NOT `state.isRunning`.** The mirrored flag is written by
    // `resume()` and `cancel()` only, so a queue started by `5-1`'s `enqueueChoice` — from
    // the novel's bulk-download sheet — is running while the state says `false`. Reading
    // the mirror would make *Pause* do nothing on exactly the queue a reader most recently
    // started, which is the defect `AGENTS.md` § Hard rules 9 exists for.
    if (!_runner.isRunning) {
      return; // § 3.2 row 4: no write of any kind
    }
    _gate.requestPause();
    state = state.copyWith(wantPause: true);
  }

  /// B21/E7 — continue **from the chapter it stopped at**, never from chapter one.
  ///
  /// ⚠️ **THE FOUR STEPS, IN THIS ORDER, AND STEP 2 IS THE ONE THAT IS EASY TO SKIP.**
  Future<void> resume() async {
    final List<QueueEntry> entries = ref.read(downloadQueueProvider).entries;
    // Step 1 — nothing to do. § 3.3 row 3: the button is not rendered in this case, so this
    // is the silent no-op a direct caller could otherwise reach.
    if (!entries.any((QueueEntry e) => !e.isDone)) {
      return;
    }

    // Step 2 — the connection check, and it lives HERE rather than in `enqueue`.
    // ⚠️ **NO CHAPTER IS STARTED WHEN THIS REFUSES.** § 3.3 row 2: the result is `stopped`
    // + *No connection*, not a silent no-op (B24) and not a queue that appears to run and
    // produces nothing.
    if (!ref.read(connectionProbeProvider).hasConnection) {
      _gate.blockFor(QueueStopReason.noConnection);
      state = state.copyWith(
        stoppedFor: QueueStopReason.noConnection,
        isRunning: false,
      );
      return;
    }

    // Step 3 — clear the stop and start at the right place. § 3.3 row 1: `pending()` is
    // `ORDER BY queue_position ASC WHERE state = 'queued'`, so the first chapter still to do
    // is the one the queue stopped at — the `downloading` row `onSessionStart` brought back
    // to `queued`, **not chapter one**, and B20's `attempts` is already 1 from the attempt
    // the process died in the middle of.
    _gate.clearStop();
    state = state.copyWith(
      wantPause: false,
      clearStoppedFor: true,
      clearResumeNotBefore: true,
      clearStorageBytesNeeded: true,
    );
    _runner.start();
    state = state.copyWith(isRunning: _runner.isRunning);
  }

  /// B19 — cancel, and **the flag goes first**.
  ///
  /// ⚠️ **THE RETURN VALUE IS `NULL` WHEN THE WRITE FAILED**, and the screen's whole job
  /// then is to say so. § 3.5: *"the queue keeps running, the switch springs back, and a
  /// snackbar says 'Could not cancel. The download is still running.'"*
  ///
  /// Returns how many rows were removed, or `null` on a failed write.
  Future<int?> cancel() async {
    // Step 1 — confirmation happened in the dialogue, before this was called.
    // Step 2 — the flag, before any write.
    _gate.cancel();

    final QueueEntry? inFlight = _inFlightEntry();
    try {
      // Step 3 — the cancellation IS a deletion. `clearUnfinished` removes every non-`done`
      // row and **never touches `chapters`**, so B32 holds: the downloaded chapters, their
      // files and their `downloadedAt` all survive.
      final int removed = await _queue.clearUnfinished();

      // Step 4 — the partial file of the chapter in flight. `2-3` would delete it on the
      // next `store()` of the same chapter anyway; doing it here makes the cancellation
      // instant and stops a `.part` from surviving for weeks.
      if (inFlight != null) {
        await ref
            .read(chapterPartialDiscarderProvider)
            .discardPartial(
              ChapterRecord(
                id: inFlight.chapterId,
                novelId: inFlight.novelId,
                ordinal: inFlight.ordinal,
              ),
            );
      }
      // Step 5 — what stays: the `done` rows, their files, their marks.
      state = state.copyWith(
        isRunning: false,
        wantPause: false,
        stoppedFor: QueueStopReason.cancelled,
      );
      return removed;
    } on AppException {
      // ⚠️ **§ 3.5: THE LOOP RESTARTS AND THE DISPLAY INVERTS.** Nothing was deleted (the
      // delete is one statement), so the queue is exactly as it was — and the reader is
      // told that, because a queue drawn as cancelled while it keeps writing chapters is
      // the one display B19 forbids outright.
      _gate.clearStop();
      _runner.start();
      state = state.copyWith(
        isRunning: _runner.isRunning,
        clearStoppedFor: true,
      );
      return null;
    }
  }

  /// B24/C12 — re-fetch **this chapter alone**, and only that one.
  ///
  /// ⚠️ **NOT "EMPTY THE QUEUE AND RELAUNCH".** § 3.5: it re-enters the queue at the **back**
  /// (`queue_position = MAX + 1`) with `attempts` preserved, so a chapter that failed twice
  /// and is retried reads `attempts == 3` on the screen — which is the whole reason the
  /// count is displayed at all.
  ///
  /// Returns `false` when the row was not `failed`: a `downloading` row has nothing to
  /// replay and a `done` row is a stored chapter, and re-queueing that would download a file
  /// that is already whole (`3-3`'s explicit re-download, B33's deletion — neither is this).
  Future<bool> retry(String queueItemId) async {
    if (!ref.read(connectionProbeProvider).hasConnection) {
      // ⚠️ **§ 3.5 ROW 5: OFFLINE RETRY IS A `stopped` QUEUE AND NO FETCH.** The row keeps
      // its `failed` state and its reason; only the queue's state changes, so the reader is
      // not shown a *Retry* that did nothing.
      _gate.blockFor(QueueStopReason.noConnection);
      state = state.copyWith(stoppedFor: QueueStopReason.noConnection);
      return false;
    }

    final bool requeued = await _queue.retry(queueItemId);
    if (!requeued) {
      return false;
    }
    _gate.clearStop();
    state = state.copyWith(
      wantPause: false,
      clearStoppedFor: true,
      clearResumeNotBefore: true,
      clearStorageBytesNeeded: true,
    );
    _runner.start();
    state = state.copyWith(isRunning: _runner.isRunning);
    return true;
  }

  /// The row the loop is in the middle of, or `null`.
  ///
  /// ⚠️ **READ FROM THE **ROWS**, NOT FROM `runner.activeItem`.** `clearUnfinished()` is about
  /// to delete the row, and the reader needs the chapter's *ordinal* — which only the row
  /// carries — in order to name the partial file being discarded.
  QueueEntry? _inFlightEntry() {
    for (final QueueEntry entry in ref.read(downloadQueueProvider).entries) {
      if (entry.state == DownloadState.downloading) {
        return entry;
      }
    }
    return null;
  }
}
