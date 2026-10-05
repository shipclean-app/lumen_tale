// Lumen Tale — the decision B37 is made of, with no plugin anywhere in this file.
//
// `6-10` § 2.2 / § 3.1 / § 3.4. The implementation of `domain/updates/check_job_controller.dart`.
//
// ## ⚠️ MARKED CLAIM: THE PLUGIN IS ONE CONSTRUCTOR PARAMETER AWAY, NOT AN IMPORT
//
// `6-10` § 2.2 puts this class in the same file as `callbackDispatcher` and calls it
// *the only place in the repository that imports `package:workmanager`*. Taking the
// [CheckJobEngine] as a parameter instead is what lets `6-10`'s rules be tested at all:
// `workmanager` builds a singleton, resolves a platform implementation from
// `Platform.isAndroid`, and speaks Pigeon over a messenger that does not exist under
// `flutter test` — and it re-exports a surface that imports `flutter/services.dart`. The
// plugin now lives in `workmanager_check_job_engine.dart`, which is still the **only** file
// that imports it, and this file — where every branch of § 3.1 and § 3.4 is decided —
// imports nothing that cannot run on the host.
//
// ## ⚠️ MARKED CLAIM: THE TWO PASSES NEVER RUN TOGETHER, AND THE ORDER IS THE PROOF
//
// `6-10` § 1 and § 3.4 call this the most important property of the slice. It is not a
// comment here, it is the order of six statements:
//
//   1. refuse if the interlock is held (§ 3.1's single-flight gate);
//   2. take the interlock **before** registering (§ 3.1's `setBool` before the call);
//   3. register — the only call that can produce a foreground job;
//   4. on a throw, **release** and only then fall back in-process.
//
// A pass can therefore never be in the background isolate and the main one at once: the
// fallback happens after the release, and the background pass only exists while the flag is
// held.

import 'dart:async';

import 'package:lumen_tale/core/background/check_job_engine.dart';
import 'package:lumen_tale/core/background/check_job_interlock.dart';
import 'package:lumen_tale/core/background/check_job_signals.dart';
import 'package:lumen_tale/core/background/notification_permission_probe.dart';
import 'package:lumen_tale/core/utils/logger.dart';
import 'package:lumen_tale/domain/updates/check_job.dart';
import 'package:lumen_tale/domain/updates/check_job_controller.dart';

/// B37's envelope: one pass, one notification, one cancel, and nine ways to end.
final class ForegroundCheckJobController implements CheckJobController {
  ForegroundCheckJobController({
    required CheckJobEngine engine,
    required CheckJobInterlock interlock,
    required NotificationPermissionProbe permissions,
    required CheckJobFallback fallback,
    Map<String, Object?> inputData = const <String, Object?>{},
  }) : _engine = engine,
       _interlock = interlock,
       _permissions = permissions,
       _fallback = fallback,
       _inputData = inputData {
    // ⚠️ **THE BUS, NOT THE ENGINE.** `CheckJobEngine` is deliberately outbound-only: the
    // platform's progress listener is installed once in `main()` — before `runApp`, before
    // any container exists — so it cannot capture a controller. It publishes to
    // `CheckJobSignalBus`, and this is the app-side end of that rendezvous.
    _subscription = CheckJobSignalBus.signals.listen(_onSignal);
  }

  final CheckJobEngine _engine;
  final CheckJobInterlock _interlock;
  final NotificationPermissionProbe _permissions;
  final CheckJobFallback _fallback;

  /// ⚠️ **CARRIED VERBATIM INTO [CheckJobRequest.inputData] AND NOWHERE ELSE.** The
  /// background isolate needs one string it cannot read for itself — the User-Agent's
  /// version — because `data/` may not import `app/`. It is task metadata, never a
  /// notification field and never part of the progress map.
  final Map<String, Object?> _inputData;

  late final StreamSubscription<CheckJobSignal> _subscription;

  final StreamController<CheckJobProgress> _progress =
      StreamController<CheckJobProgress>.broadcast();

  final StreamController<CheckJobOutcome> _outcomes =
      StreamController<CheckJobOutcome>.broadcast();

  /// The one flag `6-10` § 3.1 hangs the whole single-flight property on, plus a local
  /// guard.
  ///
  /// ⚠️ **BOTH HALVES OF ONE GATE, AND THE IN-PROCESS ONE IS SET FIRST.** The interlock is a
  /// file two isolates share; `_starting` is this isolate's own window, taken **before the
  /// first `await`** so it covers the permission read and the dialog. `6-10` § 10's C7 row
  /// is the row that measures the pair: one of the two is the cross-process rule and the
  /// other is the in-process one, and neither can stand in for the other.
  bool _starting = false;

  @override
  Future<CheckJobOutcome?> start({
    required CheckJobNotificationCopy notification,
  }) async {
    // ⚠️ **SET BEFORE THE FIRST `await`, NOT AFTER THE GATE.** The first version checked
    // `_starting`, then awaited `isHeld()`, and only then set the flag — which left the
    // whole permission read outside the guard, so two taps either side of a dialog both
    // passed it. A test row (*a second tap while the first is still asking for permission
    // registers ONCE*) caught it, and it is the same defect as the one the interlock cannot
    // see: an `async` function runs synchronously up to its first suspension, so the guard
    // has to be taken before there is one.
    if (_starting) {
      // ⚠️ **NOT AN ERROR.** A pass is already being started and the button is already in
      // its loading state; C7 is why a second pass must not start.
      return null;
    }
    _starting = true;

    try {
      if (await _interlock.isHeld()) {
        // ⚠️ **ALSO NOT AN ERROR, AND THIS IS THE CROSS-ISOLATE HALF.** The background pass
        // holds the flag; a tap while it runs returns `null` and changes nothing.
        return null;
      }

      final NotificationPermission permission = await _permissions.read();
      switch (permission) {
        // Branch 1 — granted. No dialog, straight to the job.
        case NotificationPermission.granted:
          return await _registerAndRun(notification);

        // Branch 3 — refused for good. ⚠️ **THE PASS RUNS ANYWAY.**
        case NotificationPermission.refusedPermanently:
          // B37 says *visible*, not *blocking*: the pass runs and `settings.md` § 4's
          // warning row explains that nothing will announce the end. Blocking it would make
          // B37 stronger than the rule is, and would take away the one thing the reader
          // asked for. **No dialog** — Android will not show one, so asking would be a
          // gesture that does nothing.
          return await _registerAndRun(notification);

        // Branch 4 — Android 12 and earlier. No permission exists, no request is made.
        case NotificationPermission.notApplicable:
          return await _registerAndRun(notification);

        // Branch 2 — refused, and a dialog is still available.
        case NotificationPermission.canAskAgain:
          final NotificationPermission answered = await _permissions.request();
          if (answered == NotificationPermission.granted) {
            return await _registerAndRun(notification);
          }
          // ⚠️ **A REFUSAL IS A REFUSAL — ONE ASK, NEVER A LOOP.** Reposing the question
          // immediately is the fastest route to `refusedPermanently`, the one state with
          // no dialog left in it. And the in-process fallback runs: the reader asked for a
          // check, and B37 does not say a missing *notification* is a missing check.
          return await _fallBack('the notification permission was refused');
      }
    } finally {
      // ⚠️ **CLEARED HERE AND NOT IN THE SUCCESS PATH ONLY.** `_registerAndRun` has
      // already taken the *interlock* by the time this runs, and this field guards only
      // this isolate's start window — releasing it in `finally` is what lets a second tap
      // work after a first one failed.
      _starting = false;
    }
  }

  /// Registers the one foreground job, or falls back in-process.
  Future<CheckJobOutcome?> _registerAndRun(
    CheckJobNotificationCopy notification,
  ) async {
    if (!await _interlock.acquire()) {
      // ⚠️ **LOST THE RACE.** `acquire` writes and reads back, and the read-back is the
      // witness; a `false` here means the background isolate got there first.
      return null;
    }

    try {
      await _engine.registerCheck(
        CheckJobRequest(
          uniqueName: checkJobUniqueName,
          taskName: checkJobTaskName,
          notificationId: checkJobNotificationId,
          notificationChannelId: checkJobNotificationChannelId,
          notificationChannelName: notification.channelName,
          notificationTitle: notification.title,
          notificationText: notification.text,
          // ⚠️ `shortService`, and the enum has no other value. See
          // `CheckForegroundServiceType`.
          foregroundServiceType: CheckForegroundServiceType.shortService,
          networkRequirement: CheckNetworkRequirement.connected,
          existingWorkPolicy: CheckExistingWorkPolicy.keep,
          inputData: _inputData,
        ),
      );
      // ⚠️ **`null`, NOT A RESULT.** The pass has started; how it ends arrives on
      // [outcomes] from the background isolate. Returning a "succeeded" here would be C8's
      // failure in its most literal form: a job that has not run yet reported as done.
      return null;
    } on Object catch (error) {
      // Branch 6 — § 3.1. The registration itself failed.
      // ⚠️ **RELEASE BEFORE THE FALLBACK, AND THAT ORDER IS BOTH RULES AT ONCE.** The
      // fallback runs in THIS isolate, and the flag is what tells a future tap that a pass
      // is in flight; releasing it first means a second tap arriving during the fallback
      // waits its turn instead of starting a third pass.
      await _interlock.release();
      logError('the check job could not be registered', error);
      return _fallBack('the check job could not be registered');
    }
  }

  /// Runs `6-4`'s pass in this isolate — **once**, and only after the flag is free.
  Future<CheckJobOutcome> _fallBack(String reason) async {
    await _fallback.runInProcess();
    return CheckJobCouldNotStart(reason, canFallBackInProcess: true);
  }

  @override
  Future<void> cancel() async {
    // ⚠️ **RELEASE FIRST, THEN CANCEL — AND THE ORDER IS ASSERTED BY A SPY.** A background
    // isolate killed by the system runs no `finally`, so a design that relied on
    // `onTaskStopped` to let go would leave the flag set for ever and refuse every later
    // pass with no explanation. Releasing first also means the pass's own cancellation gate
    // sees the gesture even if the platform never calls back.
    await _interlock.release();
    await _engine.cancelCheck(checkJobUniqueName);
  }

  @override
  Future<NotificationPermission> permissionState() => _permissions.read();

  @override
  Stream<CheckJobProgress> get progress => _progress.stream;

  @override
  Stream<CheckJobOutcome> get outcomes => _outcomes.stream;

  /// ⚠️ **GUARDS THE CLOSED STATE ON BOTH STREAMS.** The bus outlives the controller — it
  /// is process-wide, and the platform can deliver one last progress update after a
  /// container has been disposed — and `add` on a closed controller throws a `StateError`
  /// inside a platform callback, which surfaces as an unhandled async error rather than
  /// as anything a reader would recognise.
  void _onSignal(CheckJobSignal signal) {
    switch (signal) {
      case CheckJobProgressSignal(:final CheckJobProgress progress):
        if (!_progress.isClosed) {
          _progress.add(progress);
        }
      case CheckJobOutcomeSignal(:final CheckJobOutcome outcome):
        if (!_outcomes.isClosed) {
          _outcomes.add(outcome);
        }
    }
  }

  @override
  void dispose() {
    _subscription.cancel();
    _progress.close();
    _outcomes.close();
  }
}
