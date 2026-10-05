// forge:slice 6-10
// Lumen Tale — the isolate boundary: what crosses it, and what is refused at it.
//
// ## ⚠️ `6-10` § 10's C2 ROW, IN FULL
//
// *"reportProgress ne transporte que des entiers ; un test échoue si une `String` apparaît
// dans la carte de progression."* The plan asks for the test; this file is the reason it can
// pass. `CheckJobEngine`'s methods take **typed** values, so a `String` cannot reach
// `workmanager`'s `Map<String, dynamic>` through this app at all — and the rows below assert
// that on every builder the repository owns.
//
// ## ⚠️ WHY THE LISTENER IS DRIVEN DIRECTLY
//
// `publishCheckJobSignalFromPlatform` is the exact function `main()` hands to
// `Workmanager().setProgressListener`, and it is a top-level function with **no plugin
// import** — so the whole app-facing half of the boundary is drivable on the host. A test
// that reached past it into a private method would prove the shortcut rather than the path.
//
// | rule | the row |
// |---|---|
// | **C2** | every payload value is an `int`, for all three payloads |
// | **C2** | a payload carrying a `String` produces **no** signal at all |
// | **C12** | an unrecognised reason is dropped, not rendered as *unknown* |
// | **C8** | a terminal payload suppresses the counter for the same delivery |
// | **B39** | a counter payload round-trips as the two integers that went in |

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumen_tale/core/background/check_job_engine.dart';
import 'package:lumen_tale/core/background/check_job_progress_payload.dart';
import 'package:lumen_tale/core/background/check_job_signals.dart';
import 'package:lumen_tale/domain/updates/check_job.dart';
import 'package:lumen_tale/domain/updates/check_stop_reason.dart';

const CheckJobProgress _progress = CheckJobProgress(done: 7, total: 23);

/// Everything on the wire for one pass, as the three builders produce it.
List<Map<String, dynamic>> allPayloads() => <Map<String, dynamic>>[
  checkJobProgressPayload(_progress),
  checkJobSucceededPayload(
    const CheckJobSucceeded(
      checkedNovelCount: 19,
      failedNovelCount: 4,
      discovered: 12,
    ),
    _progress,
  ),
  for (final CheckStopReason reason in CheckStopReason.values)
    checkJobInterruptedPayload(reason, _progress),
  checkJobInterruptedPayload(null, _progress),
];

void main() {
  group('C2 — nothing but integers crosses the isolate boundary', () {
    test('every value of every payload is an int', () {
      for (final Map<String, dynamic> payload in allPayloads()) {
        for (final MapEntry<String, dynamic> entry in payload.entries) {
          expect(
            entry.value,
            isA<int>(),
            reason:
                'C2 / `17-security.md` rule 4: Android draws the check\'s notification on a '
                'locked screen, so `${entry.key}: ${entry.value}` is a surface only a count '
                'may reach. A `String` here is a leak toward whoever is holding the phone',
          );
        }
      }
    });

    test('the keys are only done, total and the three terminal markers', () {
      // ⚠️ **THE KEY SET IS ASSERTED, NOT THE SIZE.** A fourth key carrying the novel being
      // read would leave `length` at three while the map grows.
      const Set<String> allowed = <String>{
        'done',
        'total',
        'finished',
        'checked',
        'failed',
        'discovered',
        'stopped',
        'cancelled',
      };
      for (final Map<String, dynamic> payload in allPayloads()) {
        expect(
          payload.keys.toSet().difference(allowed),
          isEmpty,
          reason:
              'a key outside this set is a value `6-10` never authorised. `6-4`\'s own '
              '`LibraryCheckProgress` carries an `inFlightNovelId` and its header says it '
              'never leaves the process; this map is the place that promise is enforced',
        );
      }
      expect(
        checkJobProgressPayload(_progress).keys.toSet(),
        <String>{'done', 'total'},
        reason:
            'B39: the counter is the pass\'s only visible proof, and it is two integers. '
            'Nothing else is reported while the pass runs',
      );
    });

    test('a payload carrying a String produces NO signal', () async {
      final List<CheckJobSignal> seen = <CheckJobSignal>[];
      final StreamSubscription<CheckJobSignal> sub = CheckJobSignalBus.signals
          .listen(seen.add);
      addTearDown(sub.cancel);

      // ⚠️ **THE THREE SHAPES OF "NOT A COUNT".** A quoted number, a title and a novel id:
      // each is something a caller might plausibly write, and each must be refused rather
      // than coerced. `"7"` is the dangerous one — parsing it would make the type system a
      // suggestion and a counter would move on a payload nothing here wrote.
      publishCheckJobSignalFromPlatform(checkJobUniqueName, <String, dynamic>{
        'done': '7',
        'total': '23',
      });
      publishCheckJobSignalFromPlatform(checkJobUniqueName, <String, dynamic>{
        'done': 7,
        'total': 23,
        'inFlightNovelId': 'n-42',
      });
      publishCheckJobSignalFromPlatform(checkJobUniqueName, <String, dynamic>{
        'done': 7,
        'total': 23,
        'novel': 'The Wandering Inn',
      });
      await pumpEventQueue();

      expect(
        seen,
        isEmpty,
        reason:
            'a counter that renders a string is a counter that can be moved by a payload '
            'this app never wrote, and a novel title on a locked screen is a leak (C2). '
            'Refusing is the only safe direction',
      );
    });

    test('a double is accepted, because Android\'s codec may hand one', () async {
      final List<CheckJobSignal> seen = <CheckJobSignal>[];
      final StreamSubscription<CheckJobSignal> sub = CheckJobSignalBus.signals
          .listen(seen.add);
      addTearDown(sub.cancel);

      publishCheckJobSignalFromPlatform(checkJobUniqueName, <String, dynamic>{
        'done': 7.0,
        'total': 23.0,
      });
      await pumpEventQueue();

      expect(
        seen,
        <CheckJobSignal>[
          const CheckJobProgressSignal(CheckJobProgress(done: 7, total: 23)),
        ],
        reason:
            'B39: the pigeon codec can decode a whole number as a `double`, and a progress '
            'line that stopped rendering because `7` arrived as `7.0` would fail exactly '
            'when a phone is least cooperative',
      );
    });
  });

  group('B39 / C8 — the payloads round-trip into the right arms', () {
    test('a counter payload returns a progress with the same two numbers', () {
      expect(
        parseCheckJobProgress(checkJobProgressPayload(_progress)),
        _progress,
        reason:
            'B39: "Checking 7 of 23 novels" is the pass\'s visible proof, and it must '
            'survive the crossing unchanged',
      );
    });

    test('a success payload returns the three counts and BOTH numbers', () {
      expect(
        parseCheckJobOutcome(
          checkJobSucceededPayload(
            const CheckJobSucceeded(
              checkedNovelCount: 19,
              failedNovelCount: 4,
              discovered: 12,
            ),
            _progress,
          ),
        ),
        const CheckJobSucceeded(
          checkedNovelCount: 19,
          failedNovelCount: 4,
          discovered: 12,
        ),
        reason:
            '§ 3.3 branch 1: the terminal line says what was FOUND, not "it worked". B22 '
            'keeps the failure count beside the success count and never inside it',
      );
    });

    test(
      'every stop reason round-trips into CheckJobInterrupted with both numbers',
      () {
        for (final CheckStopReason reason in CheckStopReason.values) {
          expect(
            parseCheckJobOutcome(checkJobInterruptedPayload(reason, _progress)),
            CheckJobInterrupted(
              reason: reason,
              reachedNovelCount: 7,
              totalNovelCount: 23,
            ),
            reason:
                '§ 10 / C8: an interrupted pass is never rendered as a successful one, and it '
                'carries `reachedNovelCount` and `totalNovelCount` so the screen can say '
                '"Check stopped at 7 of 23 novels". Every one of the ten reasons must reach '
                'the reader',
          );
        }
      },
    );

    test('a reader cancellation round-trips as reason: null, not as a failure', () {
      final CheckJobOutcome? parsed = parseCheckJobOutcome(
        checkJobInterruptedPayload(null, _progress),
      );
      expect(
        parsed,
        isA<CheckJobInterrupted>().having(
          (CheckJobInterrupted o) => o.reason,
          'reason',
          isNull,
        ),
        reason:
            '`13-error-handling.md` rule 7: the reader\'s own gesture is not a failure. '
            'Rendering it as `unknown` would tell them "Android did not say why" about a '
            'cancellation they performed',
      );
      expect(
        (parsed! as CheckJobInterrupted).cancelledByReader,
        isTrue,
        reason:
            'and the predicate reads `reason == null` rather than '
            '`reason == cancelledByApp`, because `cancel()` releases the interlock BEFORE '
            'it asks the platform to stop — so the loop usually ends with no reason at all',
      );
    });

    test('an unrecognised stop reason is DROPPED, not shown as unknown', () {
      expect(
        parseCheckJobOutcome(<Object?, Object?>{
          'done': 7,
          'total': 23,
          'stopped': 99,
        }),
        isNull,
        reason:
            'C12: "Android said nothing" and "Android said something this build has never '
            'heard of" are two different facts, and § 7\'s last trap is a `switch` that '
            'collapses them into one sentence. Dropping the payload leaves the last real '
            'progress standing, which is the honest state',
      );
    });

    test('a payload that is neither terminal nor a counter produces nothing', () {
      expect(
        parseCheckJobOutcome(<Object?, Object?>{'done': 7}),
        isNull,
        reason:
            'a half-written payload must not become a counter that moves on its own (C8). '
            'Both numbers are required, always',
      );
    });
  });

  group('C8 — a terminal payload suppresses the counter for that delivery', () {
    test(
      'one interrupted delivery produces ONE signal, and it is the outcome',
      () async {
        final List<CheckJobSignal> seen = <CheckJobSignal>[];
        final StreamSubscription<CheckJobSignal> sub = CheckJobSignalBus.signals
            .listen(seen.add);
        addTearDown(sub.cancel);

        publishCheckJobSignalFromPlatform(
          checkJobUniqueName,
          checkJobInterruptedPayload(CheckStopReason.timeout, _progress),
        );
        await pumpEventQueue();

        expect(
          seen,
          <CheckJobSignal>[
            const CheckJobOutcomeSignal(
              CheckJobInterrupted(
                reason: CheckStopReason.timeout,
                reachedNovelCount: 7,
                totalNovelCount: 23,
              ),
            ),
          ],
          reason:
              'a progress payload and an outcome payload share the same `done`/`total` pair, '
              'so emitting both would leave the progress line drawing "Checking 7 of 23" '
              'underneath a finished pass — the exact mistake `6-4`\'s notifier avoids by '
              'clearing the line AFTER the result',
        );
      },
    );

    test('a signal for another task is dropped before it is parsed', () async {
      final List<CheckJobSignal> seen = <CheckJobSignal>[];
      final StreamSubscription<CheckJobSignal> sub = CheckJobSignalBus.signals
          .listen(seen.add);
      addTearDown(sub.cancel);

      publishCheckJobSignalFromPlatform(
        'lumen.downloads.queue',
        checkJobProgressPayload(_progress),
      );
      await pumpEventQueue();

      expect(
        seen,
        isEmpty,
        reason:
            'the plugin delivers progress for every task it runs. One task exists today; '
            'the filter is what keeps a second one from driving the check\'s counter',
      );
    });
  });
}
