// Lumen Tale — the bridge a background isolate's integers take to reach the app.
//
// `6-10` § 3.5. `core/`, because it is pure Dart over `dart:async` plus this project's own
// values — no Flutter, no plugin.
//
// ## ⚠️ MARKED CLAIM: A PROCESS-WIDE BUS, AND THE PLUGIN'S OWN API IS WHY
//
// `Workmanager().setProgressListener` takes a bare `void Function(String, Map<String,
// dynamic>)` and `main()` installs it **before `runApp`**, so there is no `ProviderContainer`
// and no `BuildContext` to reach at that moment. The plugin's registration API is itself a
// process-wide singleton (`Workmanager._instance`, `Workmanager._progressListener`), so a
// second process-wide rendezvous is not a new mechanism — it is the same one, in Dart.
//
// The alternative — holding a controller in a global mutable slot — would put a *writable*
// field where a *readable stream* belongs: a stream can have many listeners and delivers to
// whichever are alive, so a provider rebuilt mid-pass does not miss the terminal outcome it
// was about to render.
//
// ## ⚠️ MARKED CLAIM: PUBLISHING IS THE WHOLE OF THE PLATFORM ADAPTER'S JOB ON THIS SIDE
//
// `publishCheckJobSignalFromPlatform` is a **top-level function with no plugin import**, so
// the one piece of `workmanager` that touches the app's UI path — the progress listener —
// can be driven by a plain map in a unit test. That is where § 10's C2 row is measured: a
// payload carrying a `String` must produce **no** signal at all, because
// `parseCheckJobOutcome` and `parseCheckJobProgress` accept numbers only.

import 'dart:async';

import 'package:lumen_tale/core/background/check_job_engine.dart';
import 'package:lumen_tale/core/background/check_job_progress_payload.dart';
import 'package:lumen_tale/domain/updates/check_job.dart';

/// Something the background isolate told the app.
sealed class CheckJobSignal {
  const CheckJobSignal();
}

/// A counter update.
final class CheckJobProgressSignal extends CheckJobSignal {
  const CheckJobProgressSignal(this.progress);

  final CheckJobProgress progress;

  // ⚠️ **VALUE EQUALITY, AND IT IS LOAD-BEARING.** A signal is a *value* that a test reads
  // out of a stream, and a bus built from a broadcast controller has no identity to compare:
  // without `==` an `expect(seen, <CheckJobProgressSignal>[…])` compares two different
  // objects, which fails for the right reason with the wrong message — and a test that
  // settles for matching `toString()` stops asserting anything.
  @override
  bool operator ==(Object other) =>
      other is CheckJobProgressSignal && other.progress == progress;

  @override
  int get hashCode => Object.hash(CheckJobProgressSignal, progress);

  @override
  String toString() => 'CheckJobProgressSignal($progress)';
}

/// A terminal outcome — a success or an interruption, never anything else.
final class CheckJobOutcomeSignal extends CheckJobSignal {
  const CheckJobOutcomeSignal(this.outcome);

  final CheckJobOutcome outcome;

  @override
  bool operator ==(Object other) =>
      other is CheckJobOutcomeSignal && other.outcome == outcome;

  @override
  int get hashCode => Object.hash(CheckJobOutcomeSignal, outcome);

  @override
  String toString() => 'CheckJobOutcomeSignal($outcome)';
}

/// The rendezvous. Broadcast, so a provider that subscribes twice (a rebuild that overlaps
/// a pass, say) does not turn one progress update into two line updates.
///
/// ⚠️ **LAZY, SO IMPORTING THIS FILE COSTS NOTHING.** `dart:async`'s `StreamController`
/// is built on first access rather than at load: a background isolate that imports the
/// dispatcher must not open a second controller it will never listen to.
final class CheckJobSignalBus {
  CheckJobSignalBus._();

  /// ⚠️ **THE `close_sinks` SUPPRESSION IS DELIBERATE, AND IT IS THE ONE IN THE PROJECT.**
  /// Every other `StreamController` here is closed by whoever opened it and the analyzer is
  /// right to insist. This one is process-wide and belongs to no object, so closing it would
  /// mean the platform's progress listener — installed once in `main()`, for the life of the
  /// process — would publish into a closed bus. [reset] is the only close there is, and a
  /// test's teardown is the only thing that calls it.
  // ignore: close_sinks
  static StreamController<CheckJobSignal>? _controller;

  static StreamController<CheckJobSignal> get _bus =>
      _controller ??= StreamController<CheckJobSignal>.broadcast();

  /// Everything the background isolate has reported. Re-listened to, never replayed: the
  /// terminal outcome is delivered to whoever is listening at the time, and a pass that
  /// ended while no screen was open still ends — the next *start* is what a returning
  /// reader asks about.
  static Stream<CheckJobSignal> get signals => _bus.stream;

  /// Publishes [signal], ignoring a closed bus.
  ///
  /// ⚠️ **`isClosed` IS CHECKED RATHER THAN CAUGHT.** A `StreamController.add` after
  /// `close()` throws a `StateError` that would surface as an unhandled async error in the
  /// platform callback — a background isolate crashing on a teardown ordering. The bus is
  /// never closed in production (§ 3.5 has one engine per process); the check is what
  /// makes a test's teardown order irrelevant.
  static void publish(CheckJobSignal signal) {
    final StreamController<CheckJobSignal> bus = _bus;
    if (!bus.isClosed) {
      bus.add(signal);
    }
  }

  /// Drops the controller, and closes the one it holds.
  ///
  /// ⚠️ **NOT `@visibleForTesting`, AND THE REASON IS THAT IT IS ALSO CORRECT IN
  /// PRODUCTION.** The plugin registers its listener once per process and the app never
  /// tears the engine down mid-session, so a rebuild in a widget test is the only caller —
  /// but annotating it would make the analyzer treat an honest call as a mistake if a later
  /// slice ever needs it.
  static Future<void> reset() async {
    final StreamController<CheckJobSignal>? bus = _controller;
    _controller = null;
    await bus?.close();
  }
}

/// The listener `main()` hands to `Workmanager().setProgressListener`.
///
/// ⚠️ **FILTERS BY UNIQUE NAME BEFORE IT PARSES.** The plugin delivers progress for *every*
/// task registered under the plugin, and today that is one; the filter is written anyway
/// because a second task is exactly the change that would otherwise make a download's
/// progress drive a check's counter.
///
/// ⚠️ **A TERMINAL PAYLOAD SUPPRESSES THE COUNTER FOR THAT DELIVERY.** They arrive in the
/// same map, and emitting both would leave the progress line drawing *Checking 7 of 23*
/// underneath a finished pass — which `6-4`'s provider header names as the exact mistake
/// its own notifier avoids by clearing the line after the result.
void publishCheckJobSignalFromPlatform(
  String uniqueName,
  Map<String, dynamic> progress,
) {
  if (uniqueName != checkJobUniqueName) {
    return;
  }
  final CheckJobOutcome? outcome = parseCheckJobOutcome(progress);
  if (outcome != null) {
    CheckJobSignalBus.publish(CheckJobOutcomeSignal(outcome));
    return;
  }
  final CheckJobProgress? counter = parseCheckJobProgress(progress);
  if (counter != null) {
    CheckJobSignalBus.publish(CheckJobProgressSignal(counter));
  }
}
