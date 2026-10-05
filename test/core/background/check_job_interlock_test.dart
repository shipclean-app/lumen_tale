// forge:slice 6-10
// Lumen Tale — the one boolean two isolates share, and the recovery that clears it.
//
// ## ⚠️ WHY THESE ROWS USE THE REAL `shared_preferences`
//
// The flag's whole purpose is that it is the **only** storage both the main isolate and the
// background isolate can see. A double's field would carry the *rule* but not the *fact*, and
// the fact is the reason `SharedPreferences` is used at all: `drift` is reachable from the
// background isolate too, and a lock in the table a pass writes would be the worst of both
// worlds. So these rows drive the production implementation against the plugin's in-memory
// store, which is the real thing minus a file.
//
// ## ⚠️ `test()`, NEVER `testWidgets()`
//
// `SharedPreferences.getInstance()` is awaited here. Under `testWidgets` the body runs in a
// fake-async zone where a real platform-channel future never completes, so the test hangs and
// takes the suite with it.
//
// | rule | the row |
// |---|---|
// | **C7** | `acquire` succeeds once and then refuses |
// | **B37** | `release` twice does not throw — the Android 11 double-callback case |
// | **§ 3.3** | `releaseStaleCheckJobFlag` reports whether it found anything |
// | **§ 2.1** | the flag is a boolean and nothing else — the key holds `true` or nothing |

import 'package:flutter_test/flutter_test.dart';
import 'package:lumen_tale/core/background/check_job_interlock.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<SharedPreferencesCheckJobInterlock> anInterlock({
  Map<String, Object> initial = const <String, Object>{},
}) async {
  SharedPreferences.setMockInitialValues(initial);
  return SharedPreferencesCheckJobInterlock(
    await SharedPreferences.getInstance(),
  );
}

void main() {
  group('C7 — one pass at a time', () {
    test('acquire succeeds on a free flag and refuses once it is held', () async {
      final SharedPreferencesCheckJobInterlock interlock = await anInterlock();

      expect(
        await interlock.isHeld(),
        isFalse,
        reason: 'an ordinary launch holds nothing',
      );
      expect(
        await interlock.acquire(),
        isTrue,
        reason:
            '§ 3.1: the flag is taken BEFORE the registration, so a registration that fails '
            'still leaves evidence that something was in flight',
      );
      expect(
        await interlock.acquire(),
        isFalse,
        reason:
            'C7: a second pass would double the traffic to every site and interleave two '
            'writers of `last_checked_at`. A `false` is not an error — a pass is already '
            'running',
      );
      expect(
        await interlock.isHeld(),
        isTrue,
        reason: 'the flag survives the refused acquire: nothing released it',
      );
    });

    test('release frees the flag and can be called twice', () async {
      final SharedPreferencesCheckJobInterlock interlock = await anInterlock();
      await interlock.acquire();

      await interlock.release();
      expect(
        await interlock.isHeld(),
        isFalse,
        reason: 'the pass ended, so the next tap must work',
      );

      // ⚠️ **THE SECOND CALL IS THE ROW THAT MATTERS.** `cancel()`, the normal end of the
      // pass and `onTaskStopped` all reach `release()`, and on Android 11 and earlier two of
      // those callbacks can arrive for one stop. A `release()` that threw would turn "the
      // pass ended" into "the app crashed" — § 3.3 branches 7 and 8 failing to do the only
      // thing they exist for.
      await expectLater(
        interlock.release(),
        completes,
        reason:
            '§ 2.1: `release` is idempotent, because two callbacks can reach it for one '
            'stop and a throw would crash a background isolate',
      );
      expect(
        await interlock.isHeld(),
        isFalse,
        reason: 'and the flag stays free',
      );
    });

    test('a pass can start again after a cancel', () async {
      final SharedPreferencesCheckJobInterlock interlock = await anInterlock();
      await interlock.acquire();
      expect(
        await interlock.acquire(),
        isFalse,
        reason: 'precondition: the flag is held',
      );

      await interlock.release();

      expect(
        await interlock.acquire(),
        isTrue,
        reason:
            'B37: a reader who cancels and immediately taps again must get a second pass, '
            'not a refusal with no explanation',
      );
    });
  });

  group('§ 2.1 — the flag is a boolean and nothing else', () {
    test('the key holds `true` while a pass runs, and no other value', () async {
      final SharedPreferencesCheckJobInterlock interlock = await anInterlock();
      await interlock.acquire();

      final SharedPreferences prefs = await SharedPreferences.getInstance();
      expect(
        prefs.get(checkRunningKey),
        isTrue,
        reason:
            '§ 2.1: "PAS de valeur « timestamp », PAS de valeur « roman courant », PAS de '
            'valeur « compteurs ». Un drapeau qui contient autre chose qu\'un booléen '
            'finit par être un deuxième état de la vérification"',
      );
      expect(
        prefs.getKeys(),
        <String>[checkRunningKey],
        reason:
            'and nothing else is written. A second key would be a second piece of state the '
            'two isolates could disagree about, which is the drift this design exists to '
            'avoid',
      );
      expect(
        checkRunningKey,
        'check.job.running',
        reason:
            'the key is a named constant so the two isolates cannot disagree about its '
            'spelling — a typo in one of them is a lock neither side can see',
      );
    });
  });

  group('§ 3.3 branches 7 and 8 — a killed isolate leaves only the flag', () {
    test('the cleanup releases a held flag and says it found one', () async {
      final SharedPreferencesCheckJobInterlock interlock = await anInterlock(
        initial: <String, Object>{checkRunningKey: true},
      );

      expect(
        await releaseStaleCheckJobFlag(interlock),
        isTrue,
        reason:
            'branches 7 and 8: an isolate the system kills runs no `finally` and fires no '
            '`onTaskStopped`, so the flag is the only evidence a pass was in flight. '
            'Releasing it makes the next tap work',
      );
      expect(
        await interlock.isHeld(),
        isFalse,
        reason:
            'and the next pass is possible. Nothing is resumed (B20: an interrupted '
            'operation is done again from the start) and nothing is registered (B36: '
            'opening the app is not a trigger, and ADR-023 withdrew the schedule)',
      );
    });

    test('the cleanup is quiet on an ordinary launch', () async {
      final SharedPreferencesCheckJobInterlock interlock = await anInterlock();

      expect(
        await releaseStaleCheckJobFlag(interlock),
        isFalse,
        reason:
            'the `false` is what distinguishes the recovery path from a normal start, and '
            'it is the only way a caller can tell the two apart without a log',
      );
    });
  });
}
