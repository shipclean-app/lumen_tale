// Lumen Tale — B37's four providers, in `data/` because three screens read them.
//
// `6-10` § 4.1 / § 4.2. The plan puts these in `features/updates/providers/`; the header of
// `data/updates/check_library_providers.dart` explains why that cannot be, and the argument
// applies verbatim here: `updates.md` § 5, `library.md` § 5 and `settings.md` § 4 all read
// the check's progress, and `02-architecture.md` forbids `features/*` importing another
// `features/*`. A shared provider in a feature is F-018 again, and
// `tool/check_boundaries.py` exists because F-018 was invisible.
//
// ## ⚠️ MARKED CLAIM: `checkJobControllerProvider` IS `keepAlive`, AND THE WRITTEN REASON IS
// `updates.md` § 5
//
// A *back* gesture **does not cancel** the check — it is a foreground job with its own
// notification and its own cancel (B37) — and `library.md` shows the same progress from
// another tab. An `autoDispose` controller would close its two streams the moment the last
// listener went away, and the terminal outcome would arrive with nowhere to land: the reader
// would see the progress line freeze at *"Checking 7 of 23"* with no statement that it never
// finished. `05-state-management.md` rule 10 asks for this reason in writing; this is it.
//
// ## ⚠️ MARKED CLAIM: THE FALLBACK CALLS `6-4`'s NOTIFIER, AND THIS FILE IS THE ONLY PLACE
// THAT NAME APPEARS
//
// `6-10` § 3.4: the fallback runs **exactly the same interactor in the main isolate**, and
// forbids a second implementation "for the background isolate" — two implementations of a
// rule SC-3 depends on diverge invisibly, because both produce a plausible result. The seam
// is `CheckJobFallback`, and its production body is one line into `libraryCheckProvider`.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lumen_tale/core/background/check_job_engine.dart';
import 'package:lumen_tale/core/background/check_job_interlock.dart';
import 'package:lumen_tale/core/background/foreground_check_job.dart';
import 'package:lumen_tale/core/background/notification_permission_probe.dart';
import 'package:lumen_tale/core/background/workmanager_check_job_engine.dart';
import 'package:lumen_tale/core/storage/shared_preferences_provider.dart';
import 'package:lumen_tale/data/updates/check_library_providers.dart';
import 'package:lumen_tale/domain/updates/check_job.dart';
import 'package:lumen_tale/domain/updates/check_job_controller.dart';

/// The one boolean both isolates share.
final checkJobInterlockProvider = Provider<CheckJobInterlock>(
  (Ref ref) =>
      SharedPreferencesCheckJobInterlock(ref.watch(sharedPreferencesProvider)),
);

/// `workmanager`, behind the seam. ⚠️ **Constructed here and nowhere else**, so a test that
/// must not reach the plugin overrides one provider rather than a constructor.
final checkJobEngineProvider = Provider<CheckJobEngine>(
  (Ref ref) => WorkmanagerCheckJobEngine(),
);

/// ⚠️ **OVERRIDDABLE, AND IT SHIPS UNABLE TO ANSWER.** See
/// `UndeclaredNotificationPermissionProbe`'s header: reading `POST_NOTIFICATIONS` needs a
/// plugin or a native handler, v1 has neither, and the probe says so rather than guessing.
/// A slice that can read it replaces this one value and nothing else — the four branches of
/// `6-10` § 3.1 are already written.
final notificationPermissionProbeProvider =
    Provider<NotificationPermissionProbe>(
      (Ref ref) => const UndeclaredNotificationPermissionProbe(),
    );

/// The task input handed to the background isolate.
///
/// ⚠️ **EMPTY BY DEFAULT, AND `main.dart` OVERRIDES IT WITH THE BUILD VERSION.** The
/// background isolate needs one string it cannot read for itself — `readBuildVersion()`
/// lives in `app/`, which `data/` may not import — so the composition root passes it. Empty
/// is a valid answer: `User-Agent` falls back to *unknown* on an empty name rather than
/// inventing one, and a check with no version in its User-Agent is a check this app would
/// rather not ship.
final checkJobInputDataProvider = Provider<Map<String, Object?>>(
  (Ref ref) => const <String, Object?>{},
);

/// The in-process fallback: `6-4`'s own notifier, called once, after the flag is free.
final checkJobFallbackProvider = Provider<CheckJobFallback>(
  _LibraryCheckFallback.new,
);

/// ⚠️ **`Ref` IS HELD, AND THE FALLBACK IS READ WITHIN THE PROVIDER'S OWN LIFETIME.**
/// A container that has been disposed throws on `read`, so a stale fallback cannot start a
/// pass against a dead scope — which is the correct answer, because a pass started after the
/// app's providers are gone has no screen to report to.
final class _LibraryCheckFallback implements CheckJobFallback {
  _LibraryCheckFallback(this._ref);

  final Ref _ref;

  @override
  Future<void> runInProcess() =>
      _ref.read(libraryCheckProvider.notifier).start();
}

/// **The one controller three buttons use.** `6-10` § 10's last row is a fact about this
/// declaration: three screens, one object, so a second pass is impossible by construction
/// rather than by discipline.
final checkJobControllerProvider = Provider<CheckJobController>((Ref ref) {
  final ForegroundCheckJobController controller = ForegroundCheckJobController(
    engine: ref.watch(checkJobEngineProvider),
    interlock: ref.watch(checkJobInterlockProvider),
    permissions: ref.watch(notificationPermissionProbeProvider),
    fallback: ref.watch(checkJobFallbackProvider),
    inputData: ref.watch(checkJobInputDataProvider),
  );
  // ⚠️ **THE STREAMS ARE CLOSED WITH THE CONTAINER.** The controller opens two
  // broadcast controllers and the composition root owns their lifetime;
  // `CheckJobController.dispose()` documents why the teardown is on the interface.
  ref.onDispose(controller.dispose);
  return controller;
});

/// The counter line for `AppScaffold.persistentStatus`: *Checking 7 of 23 novels · nothing
/// is downloaded*.
///
/// ⚠️ **`StreamProvider`, NOT A `NotifierProvider` WITH A FIELD.** The value's only writer
/// is the background isolate's `reportProgress`; a notifier would add a second place that
/// can hold it, and two places holding one number is B48's defect one layer up.
final checkJobProgressProvider = StreamProvider<CheckJobProgress>(
  (Ref ref) => ref.watch(checkJobControllerProvider).progress,
);

/// The terminal outcome — *including* the endings that are not successes (C8).
final checkJobOutcomeProvider = StreamProvider<CheckJobOutcome>(
  (Ref ref) => ref.watch(checkJobControllerProvider).outcomes,
);

/// `settings.md` § 4's warning row: the permission, as far as the app can observe it.
final notificationPermissionProvider = FutureProvider<NotificationPermission>(
  (Ref ref) => ref.watch(checkJobControllerProvider).permissionState(),
);
