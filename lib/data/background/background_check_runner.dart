// Lumen Tale — the pass, as it runs in the background isolate.
//
// `6-10` § 3.2. `data/`, because it builds `DriftCheckLibrary` over a **fresh**
// `AppDatabase` and that is orchestration.
//
// ## ⚠️ MARKED CLAIM: PURE DART, NO PLUGIN, AND THAT IS THE WHOLE POINT
//
// This file imports no `workmanager`, no Flutter and no path_provider. The plugin-facing
// dispatcher in `check_job_entry_point.dart` builds this object and hands it a
// [CheckJobEngine], and everything in between — the pass, the cancellation gate, the two
// terminal branches — is therefore drivable by a unit test on the host with an in-memory
// database. `6-10` § 11.3's `6-4 → 6-10` row (*the same `CheckLibrary` produces the same
// result in both isolates*) is measured here, not on a phone.
//
// ## ⚠️ MARKED CLAIM: THE CANCELLATION GATE IS THE INTERLOCK, AND NOTHING ELSE
//
// `6-10` § 3.2: `cancellation: () async => !(await interlock.isHeld())`. One boolean in a
// file both isolates can see, and the gate is polled **twice per novel** by `6-4`'s own
// loop. A platform cancellation that arrives only as `onTaskStopped` is the wrong order —
// `onTaskStopped` fires *after* the engine is torn down, so a pass that waited for it would
// take one more novel than it had. The flag is released by `cancel()` **before** the
// platform is asked, which is what makes this gate fire at all.

import 'dart:async';

import 'package:lumen_tale/core/background/check_job_engine.dart';
import 'package:lumen_tale/core/background/check_job_interlock.dart';
import 'package:lumen_tale/core/utils/logger.dart';
import 'package:lumen_tale/domain/updates/check_job.dart';
import 'package:lumen_tale/domain/updates/check_library.dart';
import 'package:lumen_tale/domain/updates/check_stop_reason.dart';
import 'package:lumen_tale/domain/updates/library_check.dart';

/// One foreground pass, and every way it can end.
///
/// ⚠️ **ONE OBJECT PER ISOLATE INVOCATION, AND `onTaskStopped` NEEDS THE SAME ONE.** The
/// platform's stopped-callback and the task body run in the same engine, and the callback
/// has to report how far the pass got — which is a field. Two objects would be two
/// progress records, and the second would say *"0 of 0"* about a pass that had reached
/// novel seven.
final class BackgroundCheckRun {
  BackgroundCheckRun({
    required CheckLibrary check,
    required CheckJobInterlock interlock,
    required CheckJobEngine engine,
  }) : _check = check,
       _interlock = interlock,
       _engine = engine;

  final CheckLibrary _check;
  final CheckJobInterlock _interlock;
  final CheckJobEngine _engine;

  /// The last counter reported. ⚠️ **The starting value is `0 of 0`, never `0 of -1`**:
  /// `0 of 0` is what an empty library legitimately looks like (B12 — "nothing is kept" is
  /// a real first-run state), whereas a negative total is a state no pass can be in.
  CheckJobProgress _last = const CheckJobProgress(done: 0, total: 0);

  /// Progress reports are **chained**, not fired and forgotten.
  ///
  /// ⚠️ **THE CHAIN IS WHY A TERMINAL REPORT CANNOT OVERTAKE A COUNTER.** `reportProgress`
  /// is a platform call and the terminal payload carries the same two numbers; two
  /// concurrent calls to the same notification could arrive in either order, and the
  /// reader would see *"Checking 23 of 23"* land *after* *"Check stopped at 7 of 23"*. A
  /// chain costs one field and makes the order the only order.
  Future<void> _pending = Future<void>.value();

  /// Runs the pass. Returns `true` on success — and `true` even for a pass the reader
  /// stopped, because B20 says an interrupted pass is **done again from the start** when
  /// the reader asks, and returning `false` would make WorkManager retry it on its own
  /// (a background trigger, which B36 forbids).
  Future<bool> execute() async {
    final LibraryCheckResult result = await _check.run(
      onProgress: _onProgress,
      cancellation: _isCancelled,
    );

    // ⚠️ **THE INTERLOCK IS RELEASED BEFORE THE TERMINAL REPORT, NOT AFTER IT.** A reader
    // who opens the app between the two must find the button live; and if this isolate is
    // killed between the two, `onTaskStopped` releases it anyway — which is why both paths
    // call the idempotent `release()`.
    await _interlock.release();

    if (result.interrupted) {
      // ⚠️ **BRANCH 2: `reason: null`, AND NEVER `CheckJobSucceeded`.** A pass that stopped
      // at novel seven is not a pass that checked seven novels — C8 in one branch, and the
      // arm carries both numbers so the screen can say *"stopped at 7 of 23"*.
      await _reportTerminal(
        () => _engine.reportInterrupted(
          null,
          CheckJobProgress(done: result.perNovel.length, total: result.total),
        ),
      );
      return true;
    }

    // ⚠️ **`done == total`, AND THE TOTAL IS `6-4`'s OWN SNAPSHOT.** Not a re-count: B39's
    // promise is the count the reader was shown when they tapped, and re-deriving it here
    // would be a second answer to a question the interactor already answered.
    await _reportTerminal(
      () => _engine.reportSucceeded(
        CheckJobSucceeded(
          checkedNovelCount: result.checkedCount,
          failedNovelCount: result.failedCount,
          discovered: result.discoveredChapters,
        ),
        CheckJobProgress(done: result.total, total: result.total),
      ),
    );
    return true;
  }

  /// The platform stopped the work before it finished. `6-10` § 3.3 branches 3–6.
  ///
  /// ⚠️ **`systemIgnoredCancelledByApp` REPORTS NOTHING, AND THAT IS THE WHOLE OF BRANCH 6.**
  /// That reason means the worker **ran to completion** in spite of the cancellation, so
  /// the pass's own `execute()` will publish the real result a moment later. Reporting an
  /// interruption here would tell the reader their check was stopped when it finished —
  /// and § 10's row demands *Check finished after you cancelled it*, never *cancelled*.
  /// The interlock is still released, because the pass may never have started at all.
  Future<void> onStopped(CheckStopReason reason) async {
    await _interlock.release();
    if (reason == CheckStopReason.systemIgnoredCancelledByApp) {
      return;
    }
    await _reportTerminal(() => _engine.reportInterrupted(reason, _last));
  }

  void _onProgress(LibraryCheckProgress progress) {
    _last = CheckJobProgress(done: progress.done, total: progress.total);
    _chain(() => _engine.reportProgress(_last));
  }

  Future<bool> _isCancelled() async => !await _interlock.isHeld();

  /// Queues [report] behind every counter already sent.
  ///
  /// ⚠️ **A FAILURE HERE IS LOGGED AND SWALLOWED, WITH THE REASON WRITTEN DOWN.** A
  /// platform that cannot accept a progress update must not abort a pass over 23 novels —
  /// the pass's *result* is what the reader needs, and the counter is a courtesy. Rule 4
  /// forbids swallowing silently; `logError` is what makes this an allowed swallow.
  void _chain(Future<void> Function() report) {
    _pending = _pending.then((_) => report()).catchError((Object error) {
      logError('the check progress could not be reported', error);
    });
  }

  /// Waits for the counter chain, then sends the terminal report **outside** the chain —
  /// so a throwing counter cannot swallow the ending, which is the one thing the reader
  /// must be told.
  Future<void> _reportTerminal(Future<void> Function() report) async {
    await _pending;
    await report();
  }
}
