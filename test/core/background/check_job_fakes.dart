// Lumen Tale — the three doubles `6-10`'s tests share.
//
// ⚠️ **NOT A TEST FILE.** It carries no `// forge:slice` marker on purpose: the Forge guard
// resolves a slice's tests through that marker, and a file with no `test()` in it would
// otherwise count as a file that declares the slice and verifies nothing. `6-4`'s
// `check_fakes.dart` says the same about itself.
//
// ## ⚠️ WHY A HAND-WRITTEN SPY AND NOT `mocktail`
//
// Every one of these has to do something no mock can: **record the order of two calls
// across two objects** (B37's "release the flag *before* `cancelByUniqueName`"), and **hold
// an ordered log** so C7's "two taps, one registration" is a count rather than an
// inspection. `10-testing.md` §4 prefers in-memory fakes for exactly this.
//
// ## ⚠️ **NONE OF THEM IMPORTS `package:workmanager`, AND THAT IS THE POINT**
//
// The plugin cannot be constructed in a unit test (`Workmanager()` resolves a platform
// implementation from `Platform.isAndroid` and every call is a Pigeon message over a
// messenger that does not exist), so the tests assert the **decision** through
// `CheckJobEngine` and never touch the plugin — not even to name a type.

import 'package:lumen_tale/core/background/check_job_engine.dart';
import 'package:lumen_tale/core/background/notification_permission_probe.dart';
import 'package:lumen_tale/domain/updates/check_job.dart';
import 'package:lumen_tale/domain/updates/check_job_controller.dart';
import 'package:lumen_tale/domain/updates/check_stop_reason.dart';

/// A log of what the app asked the platform to do, in the order it asked.
///
/// ⚠️ **ONE ORDERED STRING LOG, NOT FOUR COLLECTIONS.** B37's ordering rule and C7's
/// "one pass per tap" are both statements about *sequence*, and four separate counters
/// cannot answer either: a cancel that released the flag after the platform call would look
/// identical to one that released it first if each side kept its own list.
final class RecordingEngine implements CheckJobEngine {
  RecordingEngine({List<String>? journal}) : journal = journal ?? <String>[];

  /// ⚠️ **ONE ORDERED LOG, SHARED WITH THE INTERLOCK — AND THIS IS WHY.**
  ///
  /// B37's ordering rule ("release the flag *before* `cancelByUniqueName`") is a statement
  /// about *time across two objects*. Two separate logs concatenated afterwards say nothing
  /// about it: `[...interlockLog, ...engineLog]` reads identically whether the release came
  /// first or second. The first version of that row did exactly this, and a sabotage that
  /// swapped the two calls still passed it — the row was decorative.
  final List<String> journal;

  final List<CheckJobRequest> registrations = <CheckJobRequest>[];

  /// ⚠️ **A TYPED `Exception`, NOT `Object`.** `analysis_options.yaml` forbids throwing a
  /// bare `Exception` from *production* code; a double that reproduces the defect has to be
  /// able to reproduce it deliberately, and the type keeps `only_throw_errors` honest.
  Exception? throwOnRegister;

  final List<CheckJobProgress> reported = <CheckJobProgress>[];
  final List<CheckJobOutcome> reportedOutcomes = <CheckJobOutcome>[];

  @override
  Future<void> registerCheck(CheckJobRequest request) async {
    journal.add('register:${request.uniqueName}');
    registrations.add(request);
    final Exception? failure = throwOnRegister;
    if (failure != null) {
      throw failure;
    }
  }

  @override
  Future<void> cancelCheck(String uniqueName) async {
    journal.add('cancel:$uniqueName');
  }

  @override
  Future<void> reportProgress(CheckJobProgress progress) async {
    journal.add('progress:${progress.done}/${progress.total}');
    reported.add(progress);
  }

  @override
  Future<void> reportSucceeded(
    CheckJobSucceeded outcome,
    CheckJobProgress progress,
  ) async {
    journal.add('succeeded:${outcome.checkedNovelCount}');
    reportedOutcomes.add(outcome);
  }

  @override
  Future<void> reportInterrupted(
    CheckStopReason? reason,
    CheckJobProgress progress,
  ) async {
    journal.add('interrupted:${reason?.name ?? 'reader'}');
    reportedOutcomes.add(
      CheckJobInterrupted(
        reason: reason,
        reachedNovelCount: progress.done,
        totalNovelCount: progress.total,
      ),
    );
  }
}

/// A probe that answers whatever the test says, and counts how often it was asked.
///
/// ⚠️ **[requests] IS COUNTED, BECAUSE § 3.1 BRANCH 2'S RULE IS ABOUT A *SECOND* ASK.**
/// A refusal that was handled by asking again would produce the same single outcome as one
/// that was not, so the assertion "no second dialog" needs a counter and not an outcome.
final class ScriptedPermissionProbe implements NotificationPermissionProbe {
  ScriptedPermissionProbe({
    this.current = NotificationPermission.granted,
    this.answer = NotificationPermission.granted,
  });

  NotificationPermission current;
  NotificationPermission answer;
  int reads = 0;
  int requests = 0;

  @override
  Future<NotificationPermission> read() async {
    reads++;
    return current;
  }

  @override
  Future<NotificationPermission> request() async {
    requests++;
    return answer;
  }
}

/// The in-process fallback, counted.
///
/// ⚠️ **IT RUNS NOTHING.** `6-10` § 3.4's rule is that the fallback calls `6-4`'s *own*
/// notifier — and a double that implemented the loop itself would be the second
/// implementation the plan forbids. What the test needs is the count, and a body that would
/// also be wrong in production is the cheapest way to make the point.
final class CountingFallback implements CheckJobFallback {
  int calls = 0;

  /// ⚠️ **TRUE WHILE IT RUNS**, so a test can catch an overlap between the fallback and a
  /// registered job rather than inferring one from the final count.
  bool running = false;

  @override
  Future<void> runInProcess() async {
    calls++;
    running = true;
  }
}

/// The localised strings, in a language that is obviously not one.
const CheckJobNotificationCopy kCopy = CheckJobNotificationCopy(
  title: 'Checking your library',
  text: 'Checking {done} of {total} novels',
  channelName: 'Library checks',
);
