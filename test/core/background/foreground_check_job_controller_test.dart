// forge:slice 6-10
// Lumen Tale — `6-10`: every branch of § 3.1 and § 3.4, decided without the plugin.
//
// ## ⚠️ WHY THIS FILE CAN TEST A FOREGROUND JOB AT ALL
//
// `workmanager` builds a singleton, resolves a platform implementation from
// `Platform.isAndroid`, and speaks Pigeon over a binary messenger that does not exist under
// `flutter test`. So the **decision** lives in `core/background/foreground_check_job.dart`
// and the plugin lives behind `CheckJobEngine`; these rows read what the job *would* be
// asked to do. The plugin is not imported here, not even to name a type.
//
// ## ⚠️ AND `main()` IS NEVER CALLED
//
// `main()` installs `Workmanager().initialize`, which is a platform call. Every row drives
// the controller directly, which is the only way a decision can be asserted on a host; § 3.5's
// ordering is asserted by *reading `main.dart`* in `check_job_structure_test.dart`.
//
// | rule | the row |
// |---|---|
// | **B37** | a granted permission registers **once**, with `shortService`, and asks nothing |
// | **B37** | `notApplicable` registers once and asks nothing |
// | **B37** | `refusedPermanently` **still registers** — visible is not blocking |
// | **B37** | `canAskAgain` asks **once**; granted registers, refused does not |
// | **B37** | the notification is id `4100` on channel `lumen_check`, with localised text |
// | **B37** | `cancel` releases the flag **before** `cancelCheck`, in that order |
// | **B37** | `cancel` targets the unique name, and the seam has no `cancelAll` |
// | **C7** | two `start()`s → one registration |
// | **B36** | a held flag refuses a pass and registers nothing |
// | **B36** | a stale flag is released at start-up and nothing is registered |
// | **C8** | a refused permission or a failed registration ends in `CheckJobCouldNotStart` |
// | **C8** | the fallback runs exactly once, and only after the flag is free |
//
// ## ⚠️ `test()`, NEVER `testWidgets()`
//
// `SharedPreferences.getInstance()` is awaited by three rows below. Under `testWidgets` the
// body runs in a fake-async zone where a real platform-channel future never completes, so
// such a test hangs and takes the suite with it — a mistake this project has made before.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumen_tale/core/background/check_job_engine.dart';
import 'package:lumen_tale/core/background/check_job_interlock.dart';
import 'package:lumen_tale/core/background/check_job_signals.dart';
import 'package:lumen_tale/core/background/foreground_check_job.dart';
import 'package:lumen_tale/domain/updates/check_job.dart';
import 'package:lumen_tale/domain/updates/check_job_controller.dart';
import 'package:lumen_tale/domain/updates/check_stop_reason.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'check_job_fakes.dart';
import 'code_grep.dart';

/// A failure a `workmanager` registration could plausibly produce on a real phone.
///
/// ⚠️ **IMPLEMENTS `Exception`, NOT A BARE `Exception`.** `analysis_options.yaml` enables
/// `only_throw_errors`, and a double that reproduced the defect by throwing the *narrowest*
/// type would be testing a shape production cannot produce.
final class _RegistrationFailed implements Exception {
  const _RegistrationFailed();
}

/// An interlock the test can inspect without going through `shared_preferences`.
///
/// ⚠️ **THE FLAG IS STILL WRITTEN THROUGH THE SAME INTERFACE.** The point of the double is to
/// see the state at a chosen moment — during the fallback — not to replace the rule.
/// `check_job_interlock_test.dart` drives the real `SharedPreferencesCheckJobInterlock`.
final class _ProbeInterlock implements CheckJobInterlock {
  _ProbeInterlock(this.journal);

  bool held = false;

  /// ⚠️ **THE ENGINE'S OWN LIST, NOT A SECOND ONE.** See `RecordingEngine.journal`: B37's
  /// ordering rule is about time *across two objects*, so two separate logs concatenated
  /// afterwards cannot measure it — and a sabotage that swapped the two calls passed the
  /// first version of that row.
  final List<String> journal;

  @override
  Future<bool> acquire() async {
    journal.add('acquire');
    if (held) {
      return false;
    }
    held = true;
    return true;
  }

  @override
  Future<void> release() async {
    journal.add('release');
    held = false;
  }

  @override
  Future<bool> isHeld() async {
    journal.add('isHeld');
    return held;
  }
}

/// A fallback that reports the flag's state **while it runs**.
///
/// ⚠️ **THIS IS THE ROW THAT MEASURES § 3.4.** "The two passes never run together" cannot be
/// checked after `start()` returns — the final state is the same either way — so the
/// observation has to happen inside the fallback.
final class _ObservingFallback implements CheckJobFallback {
  _ObservingFallback({required this.onRun});

  int calls = 0;
  final void Function() onRun;

  @override
  Future<void> runInProcess() async {
    calls++;
    onRun();
  }
}

/// One rig: the controller, its engine, its probe, its fallback and its flag.
final class _Rig {
  _Rig({
    NotificationPermission? permission,
    NotificationPermission answer = NotificationPermission.granted,
  }) : probe = ScriptedPermissionProbe(
         current: permission ?? NotificationPermission.granted,
         answer: answer,
       ) {
    interlock = _ProbeInterlock(engine.journal);
    controller = ForegroundCheckJobController(
      engine: engine,
      interlock: interlock,
      permissions: probe,
      fallback: fallback,
    );
  }

  /// ⚠️ **ONE ORDERED JOURNAL FOR BOTH COLLABORATORS** — [RecordingEngine.journal], which
  /// the interlock is handed in the constructor body. "Release before cancel" is a statement
  /// about the order things *happened*, and two separate lists printed one after the other
  /// say nothing about that: the first version of the row concatenated them and a sabotage
  /// that swapped the two calls passed it.
  final RecordingEngine engine = RecordingEngine();
  late final _ProbeInterlock interlock;
  final ScriptedPermissionProbe probe;
  final _ObservingFallback fallback = _ObservingFallback(onRun: () {});
  late final ForegroundCheckJobController controller;

  void dispose() => controller.dispose();
}

void main() {
  group('B37 — a granted permission starts one foreground job and asks nothing', () {
    test('the registration carries shortService, id 4100 and channel lumen_check', () async {
      final _Rig rig = _Rig();
      addTearDown(rig.dispose);

      final CheckJobOutcome? outcome = await rig.controller.start(
        notification: kCopy,
      );

      // ⚠️ **`null` IS THE ASSERTED VALUE, NOT A MISSING ONE.** § 3.1's `_registerAndRun`
      // ends in `return null` because the terminal result arrives on a stream — returning
      // a success here would report a job that has not run as one that has (C8).
      expect(
        outcome,
        isNull,
        reason:
            'C8: `start` returns as soon as the job is registered. Anything else here '
            'would render "Checked 23 novels" for a pass that has not begun',
      );
      expect(
        rig.engine.registrations,
        hasLength(1),
        reason: 'B37: one tap, one pass',
      );

      final CheckJobRequest request = rig.engine.registrations.single;
      expect(
        request.foregroundServiceType,
        CheckForegroundServiceType.shortService,
        reason:
            '§ 7: `dataSync` is in the merged manifest only when '
            '`workmanager.enableDataSyncForegroundService=true`, and '
            '`ForegroundServiceUtils.requireForegroundServicePermission()` throws '
            '`IllegalStateException` without it. `shortService` is the category the '
            'plugin always declares',
      );
      expect(
        request.notificationId,
        4100,
        reason:
            '§ 10: one fixed id, so a second notification replaces the first instead of '
            'leaving one orphaned in the drawer',
      );
      expect(
        request.notificationChannelId,
        'lumen_check',
        reason:
            '§ 10 names the channel. A per-pass id would leave one channel per check in '
            "the reader's system settings",
      );
      expect(
        <String>[
          request.notificationTitle,
          request.notificationText,
          request.notificationChannelName,
        ],
        <String>[kCopy.title, kCopy.text, kCopy.channelName],
        reason:
            'B28 / § 11.3: the three strings come from `AppLocalizations`, and this row '
            'fails if `core/background/` ever grows a literal of its own',
      );
      expect(
        request.uniqueName,
        'lumen.check.library.manual',
        reason:
            '§ 10: the cancel gesture targets this exact string. A second literal for '
            'the unique name would be a job nothing can cancel',
      );
      expect(
        request.existingWorkPolicy,
        CheckExistingWorkPolicy.keep,
        reason:
            '§ 3.1: `replace` would cancel pending work as a side effect of registering '
            'and `append` would stack a second pass (C7). `keep` leaves the running case '
            'to the interlock',
      );
      expect(
        request.networkRequirement,
        CheckNetworkRequirement.connected,
        reason:
            'C7: `Constraints(networkType: connected)` keeps the work from starting '
            'offline, where every novel would take the `noConnection` branch and be '
            'reported as a site failure',
      );
    });

    test('the permission is read and NEVER requested', () async {
      final _Rig rig = _Rig();
      addTearDown(rig.dispose);

      await rig.controller.start(notification: kCopy);

      expect(rig.probe.reads, 1, reason: '§ 3.1 branch 1 reads the state once');
      expect(
        rig.probe.requests,
        0,
        reason:
            'A granted permission must not open a dialog: `settings.md` § 11 lists asking '
            'on entry among the deliberate absences, and a granted state has nothing to ask',
      );
    });

    test('the request has no schedule in it, and the seam has no cancelAll', () async {
      // ⚠️ **A GREP, BECAUSE THE FIELDS DO NOT EXIST AND DART CANNOT ASK.** There is no
      // `initialDelay`, no `frequency` and no `cancelAll` — Dart has no reflection without
      // mirrors, so reading the declaration is the only way to fail when one is added.
      final String engine = codeOf('lib/core/background/check_job_engine.dart');

      for (final String forbidden in <String>[
        'initialDelay',
        'frequency',
        'periodic',
        'cancelAll',
      ]) {
        expect(
          engine,
          isNot(contains(forbidden)),
          reason:
              'ADR-023 withdrew B35: there is no interval picker and therefore no schedule '
              'in any version, and § 7 forbids `cancelAll()` because it reaches past this '
              "app's one task. `$forbidden` on the seam would put one back",
        );
      }
    });
  });

  group('B37 — the three other permission states', () {
    test('Android 12 and earlier: one registration, and no request', () async {
      final _Rig rig = _Rig(permission: NotificationPermission.notApplicable);
      addTearDown(rig.dispose);

      await rig.controller.start(notification: kCopy);

      expect(
        rig.engine.registrations,
        hasLength(1),
        reason:
            '§ 3.1 branch 4: the permission does not exist, so nothing is asked',
      );
      expect(
        rig.probe.requests,
        0,
        reason:
            '`settings.md` § 11: asking for something the phone has no concept of is a '
            'dialog that does nothing',
      );
    });

    test('refused for good: the pass STILL RUNS', () async {
      final _Rig rig = _Rig(
        permission: NotificationPermission.refusedPermanently,
      );
      addTearDown(rig.dispose);

      await rig.controller.start(notification: kCopy);

      expect(
        rig.engine.registrations,
        hasLength(1),
        reason:
            '§ 3.1 branch 3 and § 7: B37 says *visible*, not *blocking*. A refused '
            'notification removes the announcement, not the check, and blocking it would '
            'take away the only thing the reader asked for',
      );
      expect(
        rig.probe.requests,
        0,
        reason:
            'Android will not show another dialog for a permanent refusal, so asking would '
            'be a gesture that does nothing — rule 9',
      );
    });

    test('refusable and granted: one dialog, then one registration', () async {
      final _Rig rig = _Rig(permission: NotificationPermission.canAskAgain);
      addTearDown(rig.dispose);

      await rig.controller.start(notification: kCopy);

      expect(
        rig.probe.requests,
        1,
        reason:
            '§ 3.1 branch 2: the dialog is the one the reader has not seen yet',
      );
      expect(
        rig.engine.registrations,
        hasLength(1),
        reason: 'B37: granted means the pass runs',
      );
      expect(
        rig.fallback.calls,
        0,
        reason:
            '§ 3.4: the two paths never both run. The foreground job was registered, so '
            'the in-process pass must not start',
      );
    });

    test(
      'refusable and refused: ONE dialog, no registration, and the fallback runs',
      () async {
        final _Rig rig = _Rig(
          permission: NotificationPermission.canAskAgain,
          answer: NotificationPermission.canAskAgain,
        );
        addTearDown(rig.dispose);

        final CheckJobOutcome? outcome = await rig.controller.start(
          notification: kCopy,
        );

        expect(
          outcome,
          isA<CheckJobCouldNotStart>(),
          reason:
              '§ 3.1 branch 2 ends in `CheckJobCouldNotStart` with '
              '`canFallBackInProcess` — the permission path is a failure of the '
              '*envelope*, and § 3.4 takes over',
        );
        expect(
          (outcome! as CheckJobCouldNotStart).canFallBackInProcess,
          isTrue,
          reason:
              '§ 3.1: the app is in the foreground — it just answered a tap — so the '
              'in-process path can run',
        );
        expect(
          rig.probe.requests,
          1,
          reason:
              '§ 3.1: "AUCUNE relance en boucle. Une demande refusée EST un refus." A '
              'second ask is the fastest route to `refusedPermanently`, the one state with '
              'no dialog left in it',
        );
        expect(
          rig.engine.registrations,
          isEmpty,
          reason:
              'B37: a foreground job without a permission to show its notification would '
              'be invisible work, which is the half of B37 that cannot be honoured',
        );
        expect(
          rig.fallback.calls,
          1,
          reason:
              '§ 3.4: the pass still happens, in-process, through `6-4` — the reader asked '
              'for a check and B37 does not make a notification a precondition',
        );
      },
    );

    test('permissionState() answers all four values without throwing', () async {
      for (final NotificationPermission state
          in NotificationPermission.values) {
        final _Rig rig = _Rig(permission: state);
        addTearDown(rig.dispose);

        expect(
          await rig.controller.permissionState(),
          state,
          reason:
              '`settings.md` § 4 renders a warning row from this, and § 10 asks for all '
              'four values to be readable. An enum value with no sentence is a state C12 '
              'forbids',
        );
      }
    });
  });

  group('C7 — one pass per tap', () {
    test('two start() calls without an ending between them register ONCE', () async {
      final _Rig rig = _Rig();
      addTearDown(rig.dispose);

      await rig.controller.start(notification: kCopy);
      // ⚠️ **NO ENDING IN BETWEEN.** The interlock is still held — the background pass has
      // not finished — so this is § 3.1's single-flight gate, not a serial queue.
      final CheckJobOutcome? second = await rig.controller.start(
        notification: kCopy,
      );

      expect(
        rig.engine.registrations,
        hasLength(1),
        reason:
            'C7: a second pass would double the traffic to every site and interleave two '
            'writers of `last_checked_at`. § 10 counts the registrations, because a pass '
            'that merely looked busy would satisfy a weaker assertion',
      );
      expect(
        second,
        isNull,
        reason:
            '§ 2.2: the second call returns `null` and does nothing. It is NOT an error — a '
            'pass is already running and the button is already in its loading state',
      );
      expect(
        rig.interlock.held,
        isTrue,
        reason:
            'the flag is taken BEFORE the registration and released at the end of the '
            'pass, so a background pass and an in-process one can never overlap',
      );
    });

    test(
      'a second tap while the first is still asking for permission registers ONCE',
      () async {
        final _Rig rig = _Rig(permission: NotificationPermission.canAskAgain);
        addTearDown(rig.dispose);

        // ⚠️ **THE TWO CALLS OVERLAP.** `start` awaits the dialog before it takes the
        // interlock, so without the in-process `_starting` guard both taps would pass the
        // file-backed gate. This is the half of C7 the interlock alone cannot cover.
        final Future<CheckJobOutcome?> first = rig.controller.start(
          notification: kCopy,
        );
        final Future<CheckJobOutcome?> second = rig.controller.start(
          notification: kCopy,
        );
        await Future.wait(<Future<CheckJobOutcome?>>[first, second]);

        expect(
          rig.engine.registrations,
          hasLength(1),
          reason:
              'C7: two taps while a permission dialog is up must produce one pass. The '
              'interlock is a file two isolates share and says nothing about this '
              "isolate's own async window",
        );
        expect(
          rig.probe.requests,
          1,
          reason:
              'and the dialog is asked once — a second one is the fastest route to a '
              'permanent refusal (§ 3.1)',
        );
      },
    );

    test('a flag already held by the BACKGROUND pass refuses a tap', () async {
      final _Rig rig = _Rig();
      addTearDown(rig.dispose);
      rig.interlock.held = true;

      final CheckJobOutcome? outcome = await rig.controller.start(
        notification: kCopy,
      );

      expect(
        outcome,
        isNull,
        reason:
            '§ 3.1: "PAS une erreur. Une passe est déjà en cours." The notification is on '
            'screen and the progress line is counting',
      );
      expect(
        rig.engine.registrations,
        isEmpty,
        reason:
            'C7 / C8: a second pass would double the traffic and interleave two writers of '
            '`last_checked_at`',
      );
      expect(
        rig.probe.reads,
        0,
        reason:
            'the gate comes before the permission read — asking a question about a pass '
            'that is already running is a dialog for nothing',
      );
    });
  });

  group('B37 — the cancel gesture', () {
    test('the flag is released BEFORE cancelCheck, and the order is asserted', () async {
      final _Rig rig = _Rig();
      addTearDown(rig.dispose);
      await rig.controller.start(notification: kCopy);
      rig.engine.journal.clear();

      await rig.controller.cancel();

      // ⚠️ **THE ORDER IS THE RULE, AND A SET WOULD NOT MEASURE IT.** § 7: a background
      // isolate killed by the system runs no `finally`, so a design that relied on
      // `onTaskStopped` to let go would leave the flag set for ever and refuse every later
      // pass with no explanation. Asserting that both calls happened would pass either
      // order.
      expect(
        rig.engine.journal,
        <String>['release', 'cancel:lumen.check.library.manual'],
        reason:
            'B37: releasing first makes the pass\'s own cancellation gate see the gesture '
            'even if the platform never calls `onTaskStopped` back',
      );
      expect(
        rig.interlock.held,
        isFalse,
        reason:
            'after a cancel the flag is free, so the reader can start another pass — and a '
            'second tap is not refused with no explanation',
      );
    });

    test('the cancel is targeted by unique name', () async {
      final _Rig rig = _Rig();
      addTearDown(rig.dispose);
      await rig.controller.start(notification: kCopy);
      rig.engine.journal.clear();

      await rig.controller.cancel();

      expect(
        rig.engine.journal,
        <String>['release', 'cancel:lumen.check.library.manual'],
        reason:
            '§ 10: `cancelByUniqueName(\'lumen.check.library.manual\')` and never '
            '`cancelAll()`',
      );
      expect(
        rig.engine.journal.where(
          (String entry) => !entry.startsWith('release'),
        ),
        <String>['cancel:lumen.check.library.manual'],
        reason:
            'a cancel that reached anything but this app\'s one named task would be a global '
            'cancel wearing a name — E7, the queue is in-process and must stay untouched',
      );
    });
  });

  group('C8 — a pass that never starts is never reported as one that did', () {
    test('a registration that throws releases the flag, then falls back once', () async {
      final _Rig rig = _Rig();
      addTearDown(rig.dispose);
      rig.engine.throwOnRegister = const _RegistrationFailed();

      final CheckJobOutcome? outcome = await rig.controller.start(
        notification: kCopy,
      );

      expect(
        outcome,
        isA<CheckJobCouldNotStart>(),
        reason:
            '§ 3.1 branch 6: the job could not be registered, so no foreground pass exists',
      );
      expect(
        rig.fallback.calls,
        1,
        reason: '§ 3.4: the fallback runs, and exactly once',
      );
      expect(
        rig.interlock.held,
        isFalse,
        reason:
            '§ 3.4 step 1: "relâcher le drapeau que `_registerAndRun` a déjà posé". A flag '
            'left set would refuse the next tap with no explanation — the defect § 7 calls '
            'out',
      );
      final CheckJobCouldNotStart couldNot = outcome! as CheckJobCouldNotStart;
      expect(
        couldNot.canFallBackInProcess,
        isTrue,
        reason:
            '§ 3.1: the app is in the foreground, so the in-process path can run',
      );
      expect(
        couldNot.reason,
        isNot(contains('RegistrationFailed')),
        reason:
            '`13-error-handling.md` rule 3: no `e.toString()` may reach anything a screen '
            'can show. C12 asks for a sentence a reader can say aloud; the typed cause is '
            'logged at the site that caught it',
      );
    });

    test('the flag is free *during* the fallback, not only after it', () async {
      final _Rig rig = _Rig();
      rig.engine.throwOnRegister = const _RegistrationFailed();
      bool heldDuringFallback = true;
      final ForegroundCheckJobController controller =
          ForegroundCheckJobController(
            engine: rig.engine,
            interlock: rig.interlock,
            permissions: rig.probe,
            fallback: _ObservingFallback(
              onRun: () => heldDuringFallback = rig.interlock.held,
            ),
          );
      addTearDown(controller.dispose);

      await controller.start(notification: kCopy);

      expect(
        heldDuringFallback,
        isFalse,
        reason:
            '§ 3.4: the release happens BEFORE the fallback, so the in-process pass is not '
            'shadowed by a flag the foreground job left set',
      );
    });

    test(
      'a successful start leaves the flag held for the pass to release',
      () async {
        final _Rig rig = _Rig();
        addTearDown(rig.dispose);

        await rig.controller.start(notification: kCopy);

        expect(
          rig.interlock.held,
          isTrue,
          reason:
              'the flag is released by `BackgroundCheckRun.execute()` or by '
              '`onTaskStopped` — whoever ends the pass first. This controller does not '
              'release it on the success path, because the pass is still running',
        );
        expect(
          rig.fallback.calls,
          0,
          reason: '§ 3.4: nothing fell back, so nothing may fall back',
        );
      },
    );
  });

  group('B36 — a stale flag is cleaned up at start-up and registers nothing', () {
    test('a held flag is released, and no job is registered', () async {
      // ⚠️ **THE REAL INTERLOCK, AGAINST THE REAL PLUGIN'S IN-MEMORY STORE.** § 3.3 branches
      // 7 and 8 are about a background isolate the system killed, which leaves the flag set;
      // a double's field would not carry the fact that this is the one value two isolates
      // share.
      SharedPreferences.setMockInitialValues(<String, Object>{
        checkRunningKey: true,
      });
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final SharedPreferencesCheckJobInterlock interlock =
          SharedPreferencesCheckJobInterlock(prefs);

      expect(
        await interlock.isHeld(),
        isTrue,
        reason:
            'a killed isolate leaves exactly this: a flag with no pass behind it',
      );

      final bool cleaned = await releaseStaleCheckJobFlag(interlock);

      expect(
        cleaned,
        isTrue,
        reason:
            'the cleanup reports that it found something, so a test can tell the cleanup '
            'path from the quiet one instead of asserting nothing happened',
      );
      expect(
        await interlock.isHeld(),
        isFalse,
        reason:
            '§ 3.3 branches 7 and 8: released at start-up so the next pass is possible. '
            'Nothing is resumed (B20) and nothing is registered (B36)',
      );
    });

    test('a free flag is left alone, and the cleanup says so', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final SharedPreferencesCheckJobInterlock interlock =
          SharedPreferencesCheckJobInterlock(prefs);

      expect(
        await releaseStaleCheckJobFlag(interlock),
        isFalse,
        reason:
            'the second half of § 3.3 branches 7–8: an ordinary launch has no flag to '
            'clean, and the `false` is what distinguishes it from the recovery path',
      );
    });
  });

  group('the controller streams — a stopped pass is never left mid-sentence', () {
    test(
      'a progress signal reaches the progress stream, a terminal one does not',
      () async {
        final _Rig rig = _Rig();
        addTearDown(rig.dispose);
        final List<CheckJobProgress> seen = <CheckJobProgress>[];
        final List<CheckJobOutcome> ended = <CheckJobOutcome>[];
        final StreamSubscription<CheckJobProgress> progressSub = rig
            .controller
            .progress
            .listen(seen.add);
        final StreamSubscription<CheckJobOutcome> outcomeSub = rig
            .controller
            .outcomes
            .listen(ended.add);
        addTearDown(progressSub.cancel);
        addTearDown(outcomeSub.cancel);

        // ⚠️ **PUBLISHED THROUGH THE PLATFORM'S LISTENER, NOT THROUGH A PRIVATE METHOD.**
        // `publishCheckJobSignalFromPlatform` is the function `main()` hands to
        // `Workmanager().setProgressListener`, so driving it here proves the whole
        // isolate-boundary path rather than a shortcut past it.
        publishCheckJobSignalFromPlatform(checkJobUniqueName, <String, dynamic>{
          'done': 7,
          'total': 23,
        });
        publishCheckJobSignalFromPlatform(checkJobUniqueName, <String, dynamic>{
          'done': 7,
          'total': 23,
          'stopped': CheckStopReason.backgroundRestriction.wireValue,
        });
        await pumpEventQueue();

        expect(
          seen,
          <CheckJobProgress>[const CheckJobProgress(done: 7, total: 23)],
          reason:
              'B39: the counter is the pass\'s only visible proof, and it arrives as the two '
              'integers the background isolate sent',
        );
        expect(
          ended,
          <CheckJobOutcome>[
            const CheckJobInterrupted(
              reason: CheckStopReason.backgroundRestriction,
              reachedNovelCount: 7,
              totalNovelCount: 23,
            ),
          ],
          reason:
              'C8: a stopped pass arrives as the arm that says it stopped, carrying both '
              'numbers so the screen can say "Check stopped at 7 of 23 novels". Without this '
              'stream the reader would watch the line freeze at 7 of 23',
        );
      },
    );

    test('a payload for another task is ignored', () async {
      final _Rig rig = _Rig();
      addTearDown(rig.dispose);
      final List<CheckJobOutcome> ended = <CheckJobOutcome>[];
      final StreamSubscription<CheckJobOutcome> sub = rig.controller.outcomes
          .listen(ended.add);
      addTearDown(sub.cancel);

      publishCheckJobSignalFromPlatform('some.other.task', <String, dynamic>{
        'done': 1,
        'total': 2,
        'finished': 1,
      });
      await pumpEventQueue();

      expect(
        ended,
        isEmpty,
        reason:
            'the plugin delivers progress for every task it runs. Filtering by unique name '
            "is what keeps a future task from driving the check's counter",
      );
    });
  });
}
