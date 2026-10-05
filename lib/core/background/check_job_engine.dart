// Lumen Tale — what a foreground check *would* be asked to do, as pure Dart.
//
// `6-10` § 2.3, and the reason this file exists at all.
//
// ## ⚠️ MARKED CLAIM: THIS IS A SEAM, NOT A WRAPPER, AND IT IS WHAT MAKES THE SLICE TESTABLE
//
// `workmanager` cannot be exercised in a unit test: `Workmanager()` builds a singleton
// whose constructor picks a platform implementation from `Platform.isAndroid`, every method
// is a Pigeon call over a binary messenger that does not exist under `flutter test`, and
// the plugin re-exports `workmanager_api.g.dart` — so `package:flutter/services.dart`
// arrives with it. A test that imported the plugin would therefore either throw
// `MissingPluginException` or, worse, pass vacuously.
//
// So the **decision** is expressed here, in values this repository owns, and the file that
// actually calls the plugin (`workmanager_check_job_engine.dart`) is the only one that
// imports it. A test asserts *the request this slice would send* — the foreground type,
// the notification id, the channel, the absence of a schedule — and the plugin call is a
// translation of a value it already holds.
//
// ## ⚠️ MARKED CLAIM: THERE IS NO `cancelAll()` ON THIS INTERFACE, AND THAT IS THE RULE
//
// `6-10` § 7: `cancelAll()` reaches past this app's one task into whatever else the plugin
// is running. It is a no-op today (E7 — the download queue is in-process) and a silent
// break the day anything else uses `workmanager`. A method that cannot be called is a
// stronger guarantee than a test asserting it is not, so the interface does not have one.

import 'package:lumen_tale/domain/updates/check_job.dart';
import 'package:lumen_tale/domain/updates/check_stop_reason.dart';

/// The task name the background dispatcher switches on. `6-10` § 2.2: **a constant, never
/// a literal at a call site**, because it is the key `executeTask` compares against.
const String checkJobTaskName = 'lumen.check.library';

/// The unique name of the registered work — the key `cancelCheck` targets.
///
/// ⚠️ **A SECOND CONSTANT FROM [checkJobTaskName], AND THE DIFFERENCE IS LOAD-BEARING.**
/// The task name is what the dispatcher *dispatches on*; the unique name is what
/// WorkManager *enqueues and cancels*. Collapsing them into one constant would be tidier
/// and would make "cancel the check" and "which check is this" the same string, so a
/// future second task would either be uncancellable or would cancel the check.
const String checkJobUniqueName = 'lumen.check.library.manual';

/// The foreground notification's id.
///
/// ⚠️ **A FIXED SMALL INTEGER, `6-10` § 2.2's number, AND A CONSTANT RATHER THAN A FIELD.**
/// Two notifications sharing an id replace one another; two different ids could leave one
/// orphaned in the drawer after a cancellation. There is exactly one notification in this
/// app, so the id is a constant of the feature rather than something a caller may vary.
const int checkJobNotificationId = 4100;

/// The `inputData` key carrying the build version into the background isolate.
///
/// ⚠️ **DECLARED HERE, NOT IN `data/background/check_job_entry_point.dart`, SO A TEST CAN
/// NAME IT WITHOUT THE PLUGIN.** The background isolate cannot read `readBuildVersion()`
/// itself — `data/` may not import `app/` — so `main.dart` passes the one string it cannot
/// obtain, as task input. It is the only string this slice puts into a platform message, and
/// it never reaches a notification: `inputData` is task metadata, whereas the progress map
/// is the surface `17-security.md` rule 4 governs.
const String checkJobAppVersionKey = 'appVersion';

/// The foreground notification's channel id.
///
/// ⚠️ **STABLE, AND IT IS ALSO PART OF THE ACCEPTANCE CRITERION** (`6-10` § 10 names
/// `lumen_check`). Android creates a channel the first time it is used and shows it in the
/// reader's own settings under its *localised* name; a per-pass id would leave one channel
/// per check behind in system settings.
const String checkJobNotificationChannelId = 'lumen_check';

/// The foreground service type this app asks for.
///
/// ⚠️ **ONE VALUE, AND IT IS `shortService`.** Android defines it as *"short, critical
/// work that the user is aware of and that must complete quickly (a few minutes at most)"*
/// — which is a manual pass over a personal library. `dataSync` is the other candidate and
/// it is **not available**: `workmanager_android` declares
/// `FOREGROUND_SERVICE_DATA_SYNC` only when `gradle.properties` sets
/// `workmanager.enableDataSyncForegroundService=true`, and its
/// `ForegroundServiceUtils.requireForegroundServicePermission()` throws
/// `IllegalStateException` when the merged manifest lacks the permission. Declaring an
/// enum with a value the plugin would reject would be a value nothing can reach.
enum CheckForegroundServiceType {
  /// Android's short-service category. ⚠️ The **only** value, deliberately: `6-10` § 7
  /// names `dataSync` as the mistake this enum exists to make impossible.
  shortService,
}

/// Whether the work may start offline.
///
/// ⚠️ **`connected`, BECAUSE A CHECK WITHOUT A CONNECTION IS NOT SLOW, IT IS FAILED.**
/// Every novel would take a `noConnection` branch and be reported as *could not be
/// checked* — so a reader in aeroplane mode who taps *Check* offline would watch 23 sites
/// fail one after another. C7 as well: the work is enqueued and waits, rather than burning
/// the request.
enum CheckNetworkRequirement { connected }

/// What happens to work already **pending** under [checkJobUniqueName].
///
/// ⚠️ **`keep`, AND THE OTHER TWO ARE NAMED SO THE CHOICE IS REVIEWABLE.**
/// `replace` would cancel pending work as a *side effect of registering*, which is the
/// cancel gesture and must not be a consequence of a button press; `append` would stack a
/// second pass and double the traffic to every site (C7). And `keep` does not touch work
/// that is already **running** — WorkManager applies the policy to pending work only,
/// which is right, because the interlock flag is what governs the running case.
enum CheckExistingWorkPolicy { keep }

/// Everything `6-10` asks the plugin to register, as values this repository owns.
///
/// ⚠️ **NO `initialDelay`, NO `frequency`, NO `expedited`, AND NO `PERIODIC` FIELDS.** ADR-023
/// withdrew B35: there is no interval picker and therefore no schedule in any version.
/// Their absence from this class is what makes a schedule unrepresentable rather than
/// merely unwritten — § 10's row is a `grep`, and a `grep` can be satisfied by a comment.
final class CheckJobRequest {
  const CheckJobRequest({
    required this.uniqueName,
    required this.taskName,
    required this.notificationId,
    required this.notificationChannelId,
    required this.notificationChannelName,
    required this.notificationTitle,
    required this.notificationText,
    required this.foregroundServiceType,
    required this.networkRequirement,
    required this.existingWorkPolicy,
    this.inputData = const <String, Object?>{},
  });

  /// ⚠️ **CARRIES THE BUILD VERSION AND NOTHING ELSE.** The background isolate needs one
  /// string it cannot read for itself — the User-Agent's version — because
  /// `data/` may not import `app/` where `readBuildVersion()` lives. It arrives as task
  /// input rather than as a global, because a global would be a second thing to keep in
  /// step. It is **not** the progress map: `6-10` § 10's C2 row forbids a `String` in the
  /// *progress*, which is drawn on a locked screen; task input is never displayed.
  final Map<String, Object?> inputData;

  final String uniqueName;
  final String taskName;

  /// The one notification's id — [checkJobNotificationId], and required rather than
  /// defaulted so a caller cannot forget it.
  final int notificationId;

  /// The one channel — [checkJobNotificationChannelId].
  final String notificationChannelId;

  /// ⚠️ **THE ONLY THREE STRINGS THIS SLICE PUTS INTO A SYSTEM SURFACE**, and all three
  /// come from `AppLocalizations`. A literal in `core/` would be an English sentence in a
  /// French application (B28), which is why they are a constructor parameter rather than a
  /// constant here.
  final String notificationChannelName;
  final String notificationTitle;
  final String notificationText;

  final CheckForegroundServiceType foregroundServiceType;
  final CheckNetworkRequirement networkRequirement;
  final CheckExistingWorkPolicy existingWorkPolicy;

  @override
  String toString() =>
      'CheckJobRequest($uniqueName, $taskName, notification: $notificationId, '
      'channel: $notificationChannelId, fgs: ${foregroundServiceType.name})';
}

/// What the background isolate reports, and what the app hears.
///
/// ⚠️ **`reportProgress` TAKES A TYPED VALUE, SO A STRING CANNOT TRAVEL.** This is the C2
/// claim made structural: `6-10` § 10 asks for a test that fails when a `String` appears in
/// the progress map, and a typed parameter fails earlier — the code will not compile. The
/// map the plugin finally receives is built by
/// `core/background/check_job_progress_payload.dart`, which is where the int-only rule is
/// asserted.
abstract interface class CheckJobEngine {
  /// Registers **one** foreground pass. Throws on failure, and the caller turns a throw
  /// into `CheckJobCouldNotStart` plus the in-process fallback (`6-10` § 3.4).
  Future<void> registerCheck(CheckJobRequest request);

  /// Cancels the work registered under [uniqueName]. ⚠️ **Named, never global** — see the
  /// header's note on the absent `cancelAll()`.
  Future<void> cancelCheck(String uniqueName);

  /// The counter. Two integers, and nothing else may cross.
  Future<void> reportProgress(CheckJobProgress progress);

  /// The pass visited every novel.
  ///
  /// ⚠️ **[progress] IS PASSED RATHER THAN DERIVED.** The payload has the same shape as the
  /// counter's, and a synthetic `total` invented here would put *"Checking 0 of 0"* on
  /// screen for the frame between the last progress and the terminal line — the one
  /// artefact `6-10` § 4.3 promises never appears. The background isolate knows both
  /// numbers; they are not reconstructed.
  Future<void> reportSucceeded(
    CheckJobSucceeded outcome,
    CheckJobProgress progress,
  );

  /// The pass stopped early.
  ///
  /// ⚠️ **[reason] IS NULLABLE, AND `null` MEANS THE READER.** `cancel()` releases the
  /// interlock before it asks the platform to stop, so the pass normally ends at its own
  /// next cancellation gate and no platform reason ever arrives. `13-error-handling.md`
  /// rule 7: the reader's own gesture is not a failure and must not be dressed as one.
  /// A `reason` crosses as its `wireValue`, an integer.
  Future<void> reportInterrupted(
    CheckStopReason? reason,
    CheckJobProgress progress,
  );
}
