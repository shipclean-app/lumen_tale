// Lumen Tale — the named entry point the platform invokes, and the one place the
// background isolate is assembled.
//
// `6-10` § 2.2 / § 3.2 / § 3.5. `data/`, because this file builds `AppDatabase`,
// `SourceManager` and `DriftCheckLibrary`, and `data/` is the layer that may name all
// three. The plugin itself is reached through `core/background/
// workmanager_check_job_engine.dart`; this file is the second of the two files that touch
// it, and neither is a feature.
//
// ## ⚠️ MARKED CLAIM: TOP-LEVEL, `@pragma('vm:entry-point')`, AND A `switch` WITH NO BLIND
// BRANCH
//
// `workmanager` invokes [checkJobCallbackDispatcher] **by name** from a fresh engine; a
// method or a local closure would be tree-shaken and the name would not exist at runtime.
// The second half of the same rule is the dispatch `switch`: a `default` that quietly ran
// the check would mean a future task — and the download queue is *not* one, E7 — silently
// checking the reader's library. It throws instead (`13-error-handling.md` rule 4).

import 'dart:async';

import 'package:lumen_tale/core/background/check_job_engine.dart';
import 'package:lumen_tale/core/background/check_job_interlock.dart';
import 'package:lumen_tale/core/background/check_job_signals.dart';
import 'package:lumen_tale/core/background/workmanager_check_job_engine.dart';
import 'package:lumen_tale/core/database/app_database.dart';
import 'package:lumen_tale/core/network/host_rate_limiter.dart';
import 'package:lumen_tale/data/background/background_check_runner.dart';
import 'package:lumen_tale/data/sources/source_manager.dart';
import 'package:lumen_tale/data/updates/drift_check_library.dart';
import 'package:lumen_tale/data/updates/drift_library_check_store.dart';
import 'package:lumen_tale/domain/updates/check_job.dart';
import 'package:lumen_tale/sources/implementations/source_registry.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

/// The run currently executing in this isolate, so `onTaskStopped` can report how far it
/// got.
///
/// ⚠️ **NULL MEANS *NEVER STARTED*, AND THAT IS A REAL CASE.** A task can be stopped before
/// its Dart body runs, and then `onTaskStopped` is the only callback that fires. It reports
/// `0 of 0` — an interruption at the first gate — which is honest: nothing was looked at.
BackgroundCheckRun? _activeRun;

/// The platform's entry point. **Called by name; never renamed.**
@pragma('vm:entry-point')
void checkJobCallbackDispatcher() {
  Workmanager().executeTask(
    _dispatch,
    // ⚠️ **ANDROID ONLY, AND IT IS THE ONLY RELIABLE SIGNAL THAT THE PLATFORM STOPPED US.**
    // A background isolate the system kills runs no `finally` — so `execute()`'s release
    // never happens on that path, and this callback is what performs it. That is why the
    // flag is released *here* as well as there, and why `release()` is idempotent.
    onTaskStopped: _onTaskStopped,
  );
}

/// Hands the engine's listeners to the app before `runApp`.
///
/// ⚠️ **CALLED BEFORE `runApp`, AND THAT ORDER IS `6-10` § 3.5'S WHOLE ARGUMENT.**
/// `executeTask` registers its handlers on the isolate's messenger and the platform calls
/// the dispatcher afterwards; a task that ran before the handlers existed would find a
/// background isolate with nothing to receive it. So the engine is initialised here, in
/// `main()`, and nowhere else.
///
/// ⚠️ **`setProgressListener` IS THE APP-SIDE HALF OF THE ISOLATE BRIDGE.** It is installed
/// with a **top-level function**, not a closure over anything, because there is no container
/// yet — and it filters by unique name inside
/// `publishCheckJobSignalFromPlatform`.
Future<void> initializeBackgroundCheckEngine() async {
  await Workmanager().initialize(checkJobCallbackDispatcher);
  await Workmanager().setProgressListener(publishCheckJobSignalFromPlatform);
}

/// ⚠️ **ONE TASK, ONE CASE, AND A THROW FOR ANYTHING ELSE.**
Future<bool> _dispatch(String taskName, Map<String, dynamic>? inputData) {
  switch (taskName) {
    case checkJobTaskName:
      return _runCheck(inputData);
    default:
      // ⚠️ **LOUD, NOT SILENT.** `13-error-handling.md` rule 4. A `default` that ran the
      // check would mean any future task through this plugin checks the reader's library
      // without being asked — B36 and C7, with a plausible-looking result.
      throw UnimplementedError('unknown workmanager task: $taskName');
  }
}

/// Builds **everything this isolate needs**, and runs the pass.
///
/// ⚠️ **A NEW `AppDatabase()` OBJECT, NOT THE MAIN ISOLATE'S, AND THE SAME `_setup`.**
/// Two isolates cannot share one drift handle, so the object is new — but the *file* is the
/// same, and the connection hook is the same: `AppDatabase()`'s lazy path passes
/// `setup: _setup`, which is the `PRAGMA foreign_keys = ON` that B32's only enforcement
/// depends on. A background connection built any other way would silently stop applying
/// `history_entries`'s `RESTRICT`, and nothing about that failure would look like a
/// database bug.
///
/// ⚠️ **ONE RATE LIMITER PER ISOLATE, SHARED WITH THE SOURCES BUILT IN THE SAME CALL.**
/// C7 — the limiter a pass feeds is the one the HTTP clients acquire from, or the
/// `Retry-After` it records is honoured by nobody. A second isolate gets its own limiter,
/// which is correct: there is exactly one of everything *within* this process, and there is
/// only one pass.
Future<bool> _runCheck(Map<String, dynamic>? inputData) async {
  final AppDatabase db = AppDatabase();
  try {
    final CheckJobInterlock interlock = SharedPreferencesCheckJobInterlock(
      await SharedPreferences.getInstance(),
    );
    final HostRateLimiter limiter = HostRateLimiter();
    final SourceManager sources = buildSourceManager(
      appVersion: inputData?[checkJobAppVersionKey] as String? ?? '',
      limiter: limiter,
    );

    final BackgroundCheckRun run = BackgroundCheckRun(
      check: DriftCheckLibrary(
        store: DriftLibraryCheckStore(db),
        sources: sources,
        rateLimiter: limiter,
        clock: DateTime.now,
      ),
      interlock: interlock,
      engine: WorkmanagerCheckJobEngine(),
    );
    _activeRun = run;
    return await run.execute();
  } finally {
    // ⚠️ **THE CONNECTION IS CLOSED ON EVERY PATH THAT RETURNS.** drift's background
    // executor holds a file handle; leaving it open across the rest of the engine's life
    // would keep a second connection to the same SQLite file alive while the main isolate
    // holds the first. (A killed isolate never reaches this, and the OS reclaims it.)
    await db.close();
    _activeRun = null;
  }
}

/// The platform stopped this task. `6-10` § 3.3 branches 2–6.
Future<void> _onTaskStopped(String taskName, StopReason reason) async {
  // ⚠️ **FILTERED BY TASK NAME.** The plugin delivers this for every task it runs, and
  // reacting to another task's stop by releasing *our* flag would clear the interlock
  // while a check was still going.
  if (taskName != checkJobTaskName) {
    return;
  }
  final BackgroundCheckRun? run = _activeRun;
  if (run != null) {
    await run.onStopped(toCheckStopReason(reason));
    return;
  }

  // ⚠️ **STOPPED BEFORE THE BODY RAN: `0 of 0`, RELEASED, AND NOTHING INVENTED.** The
  // interlock goes back so the next tap works (`6-10` § 3.3 branches 7 and 8), and the
  // interruption carries no counts because none exist.
  await SharedPreferencesCheckJobInterlock(
    await SharedPreferences.getInstance(),
  ).release();
  await WorkmanagerCheckJobEngine().reportInterrupted(
    toCheckStopReason(reason),
    const CheckJobProgress(done: 0, total: 0),
  );
}
