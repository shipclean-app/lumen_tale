// Lumen Tale — THE ONLY FILE IN THIS REPOSITORY THAT IMPORTS `package:workmanager`.
//
// `6-10` § 2.2 / § 2.3. Everything the plugin can be asked to do is stated here, and
// nowhere else; `core/background/check_job_engine.dart` holds the decision and this file
// holds the translation.
//
// ## ⚠️ MARKED CLAIM: THE `StopReason` SWITCH LIVES HERE AND HAS NO `default`
//
// `6-10` § 2.2 puts `import
// 'package:workmanager_platform_interface/…' show StopReason;` inside `domain/`, which
// cannot be built — the package is not declared (so `depend_on_referenced_packages` fires)
// and the declared route to the same type, `package:workmanager/workmanager.dart`,
// re-exports `workmanager_api.g.dart` and therefore `package:flutter/services.dart`, which
// would put Flutter inside the pure layer. `domain/updates/check_stop_reason.dart`
// therefore declares its own ten values, and this is the one place the two vocabularies
// meet.
//
// The switch is **exhaustive with no `default`**, and that is `6-10` § 7's last trap made
// into a build error: a new WorkManager stop reason breaks compilation here instead of
// reaching a reader as the generic *"stopped"*. `test/core/background/
// check_stop_reason_parity_test.dart` reads the installed package and asserts the two sets
// of names are equal, so a rename breaks a test rather than a release.

import 'package:lumen_tale/core/background/check_job_engine.dart';
import 'package:lumen_tale/core/background/check_job_progress_payload.dart';
import 'package:lumen_tale/domain/updates/check_job.dart';
import 'package:lumen_tale/domain/updates/check_stop_reason.dart';
import 'package:workmanager/workmanager.dart';

/// The plugin's `StopReason`, as this app's own enum.
///
/// ⚠️ **TEN ARMS, NO `default`, ONE PER VALUE.** See the header.
CheckStopReason toCheckStopReason(StopReason reason) => switch (reason) {
  // Android 11 and earlier always report this, and it is genuinely "we do not know" —
  // the sentence says so.
  StopReason.unknown => CheckStopReason.unknown,
  StopReason.timeout => CheckStopReason.timeout,
  StopReason.preempt => CheckStopReason.preempt,
  // ⚠️ **THIS ONE IS *US*.** `cancel()` calls `cancelByUniqueName`, so a
  // `cancelledByApp` here is this app's own gesture arriving back from the platform.
  StopReason.cancelledByApp => CheckStopReason.cancelledByApp,
  // ⚠️ **NOT AN INTERRUPTION.** The worker ran to completion despite the cancellation, so
  // `data/background/background_check_runner.dart` treats this reason as *nothing to
  // report*: the pass's own success is the truth, and the reader is told the pass finished
  // after they cancelled it.
  StopReason.systemIgnoredCancelledByApp =>
    CheckStopReason.systemIgnoredCancelledByApp,
  StopReason.backgroundRestriction => CheckStopReason.backgroundRestriction,
  StopReason.estimatedAppGpuLimit => CheckStopReason.estimatedAppGpuLimit,
  StopReason.deviceState => CheckStopReason.deviceState,
  StopReason.appStandby => CheckStopReason.appStandby,
  StopReason.deviceIdle => CheckStopReason.deviceIdle,
};

/// `workmanager`, as this app's [CheckJobEngine].
final class WorkmanagerCheckJobEngine implements CheckJobEngine {
  WorkmanagerCheckJobEngine({Workmanager? workmanager})
    : _workmanager = workmanager ?? Workmanager();

  final Workmanager _workmanager;

  @override
  Future<void> registerCheck(CheckJobRequest request) {
    // ⚠️ **`foregroundServiceConfig` IS NOT OPTIONAL HERE.** It is what promotes the worker
    // to a foreground service, which is what keeps the process alive and draws the
    // notification B37 asks for. Omitting it would produce a background job that Android
    // may stop mid-pass — the *only* case where § 10's first row could pass by accident.
    //
    // ⚠️ **AND `shortService`, WHICH IS THE ONLY VALUE THE ENUM CAN HOLD.**
    // `dataSync` requires `workmanager.enableDataSyncForegroundService=true` in
    // `gradle.properties`; without it the merged manifest has no
    // `FOREGROUND_SERVICE_DATA_SYNC` and `ForegroundServiceUtils`'s
    // `requireForegroundServicePermission()` throws `IllegalStateException` at runtime.
    return _workmanager.registerOneOffTask(
      request.uniqueName,
      request.taskName,
      inputData: request.inputData,
      // ⚠️ **NO `initialDelay` AND NO `expedited`.** ADR-023 withdrew the schedule, so a
      // delayed job is a job the reader did not ask to happen yet, and `expedited` would
      // run it as a shortService *and* claim quota this app has not been given.
      existingWorkPolicy: _existingWorkPolicy(request.existingWorkPolicy),
      constraints: Constraints(
        networkType: _networkType(request.networkRequirement),
      ),
      foregroundServiceConfig: ForegroundServiceConfig(
        notificationId: request.notificationId,
        notificationChannelId: request.notificationChannelId,
        notificationChannelName: request.notificationChannelName,
        notificationTitle: request.notificationTitle,
        notificationText: request.notificationText,
        foregroundServiceType: _foregroundServiceType(
          request.foregroundServiceType,
        ),
      ),
    );
  }

  @override
  Future<void> cancelCheck(String uniqueName) =>
      // ⚠️ **NAMED, NEVER `cancelAll()`.** See `check_job_engine.dart`'s header: nothing
      // else uses this plugin today, and a global cancel would start killing whatever does
      // the day it does.
      _workmanager.cancelByUniqueName(uniqueName);

  @override
  Future<void> reportProgress(CheckJobProgress progress) =>
      _workmanager.reportProgress(checkJobProgressPayload(progress));

  @override
  Future<void> reportSucceeded(
    CheckJobSucceeded outcome,
    CheckJobProgress progress,
  ) => _workmanager.reportProgress(checkJobSucceededPayload(outcome, progress));

  @override
  Future<void> reportInterrupted(
    CheckStopReason? reason,
    CheckJobProgress progress,
  ) =>
      _workmanager.reportProgress(checkJobInterruptedPayload(reason, progress));
}

ExistingWorkPolicy _existingWorkPolicy(CheckExistingWorkPolicy policy) =>
    switch (policy) {
      // `keep` and nothing else. See `CheckExistingWorkPolicy`'s doc comment.
      CheckExistingWorkPolicy.keep => ExistingWorkPolicy.keep,
    };

NetworkType _networkType(CheckNetworkRequirement requirement) =>
    switch (requirement) {
      CheckNetworkRequirement.connected => NetworkType.connected,
    };

ForegroundServiceType _foregroundServiceType(
  CheckForegroundServiceType type,
) => switch (type) {
  // ⚠️ **`shortService`, AND `dataSync` IS NOT REACHABLE FROM HERE.** The enum has one
  // value on purpose; see `CheckForegroundServiceType`.
  CheckForegroundServiceType.shortService => ForegroundServiceType.shortService,
};
