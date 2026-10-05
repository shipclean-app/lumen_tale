// forge:slice 5-3
// Lumen Tale — `prd.md` § 7.1's 500 ms cadence, and the bar that must NOT move because of it.
//
// `5-3` § 3.1 and § 11.2's two cadence rows. The clock and the timer are **injected**, which
// is what makes the project's only CI-provable performance objective provable at all.
//
// | rule | the row |
// |---|---|
// | `prd.md` § 7.1 | 600 ms with **no** byte arriving → at least one emission, value unchanged |
// | `prd.md` § 7.1, `15-performance.md` | a fast connection emits **one** changed value per 500 ms |
// | `downloads.md` § 8 | `total <= 0` becomes `null`, never `0` |
// | `5-3` § 3.1 | the heartbeat ends when the chapter does |
// | B18 | a **new chapter** is not delayed by the rate limit |

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumen_tale/data/downloads/queue_progress_tracker.dart';
import 'package:lumen_tale/domain/downloads/chapter_progress.dart';

/// A clock the test moves by hand.
///
/// ⚠️ **A REAL `DateTime` WOULD MAKE THIS ROW A SLEEP.** `prd.md` § 7.1's 500 ms is the only
/// performance objective the project claims is provable in CI, and a provable objective is one
/// that does not need a wall clock: `QueueProgressTracker`'s constructor takes `now` for
/// exactly this.
DateTime clockAt(int millis) =>
    DateTime.utc(2026, 10, 4, 12).add(Duration(milliseconds: millis));

/// A `Timer.periodic` the test fires by hand, and which records its own interval so a wrong
/// constant cannot pass unnoticed.
final class ManualTimers {
  final List<ManualTimer> created = <ManualTimer>[];

  Timer create(Duration interval, void Function(Timer) callback) {
    final ManualTimer timer = ManualTimer(interval, callback);
    created.add(timer);
    return timer;
  }

  int get liveCount => created.where((ManualTimer t) => !t.cancelled).length;

  /// Fires every live timer once.
  void tick() {
    for (final ManualTimer timer in created) {
      if (!timer.cancelled) {
        timer.callback(timer);
      }
    }
  }
}

/// ⚠️ **IMPLS `Timer` AND IS FIRED BY HAND.** `Timer.periodic` is the real thing and it would
/// make every row in this file a sleep; the whole point of injecting it is that
/// `prd.md` § 7.1 is provable in CI *without* waiting 500 ms.
final class ManualTimer implements Timer {
  ManualTimer(this.interval, this.callback);

  /// ⚠️ **NEITHER IS `@override`.** `Timer` in this SDK declares `cancel()` and `isActive` but
  /// carries `interval` and `callback` as *constructor-assigned fields* of its own subclasses,
  /// so annotating them would be a claim the interface does not back.
  final Duration interval;
  final void Function(Timer) callback;

  bool cancelled = false;

  @override
  void cancel() => cancelled = true;

  @override
  bool get isActive => !cancelled;

  @override
  int get tick => 0;
}

void main() {
  group('`prd.md` § 7.1 — at least one emission per 500 ms window', () {
    test(
      '⚠️ 600 ms with NO byte arriving → ≥1 emission, and the VALUE IS UNCHANGED',
      () async {
        final ManualTimers timers = ManualTimers();
        int now = 0;
        final QueueProgressTracker tracker = QueueProgressTracker(
          now: () => clockAt(now),
          periodic: timers.create,
        );
        addTearDown(tracker.dispose);
        final List<ChapterProgress> seen = <ChapterProgress>[];
        final StreamSubscription<ChapterProgress> subscription = tracker
            .progress
            .listen(seen.add);
        addTearDown(subscription.cancel);

        tracker.report(
          queueItemId: 'q1',
          chapterId: 'c1',
          chapterName: 'Chapter 13',
          receivedBytes: 4096,
          totalBytes: 10 * 1024,
        );
        // ⚠️ **A BROADCAST STREAM DELIVERS ASYNCHRONOUSLY**, so the assertion has to let the
        // event queue turn first. A synchronous `expect` here reads an empty list and would
        // have "proved" the tracker emits nothing — which is how a green row can measure a
        // defect.
        await pumpEventQueue();
        expect(
          seen,
          hasLength(1),
          reason: 'the first value leaves immediately',
        );

        // ⚠️ **600 ms, AND NOT ONE BYTE.** The whole requirement is that a line the reader is
        // looking at proves it is alive **without** the app inventing progress.
        now = 600;
        timers.tick();
        // ⚠️ **AND THE SAME ONE-TURN WAIT**, because a broadcast stream delivers
        // asynchronously whether the value came from `report` or from the heartbeat.
        await pumpEventQueue();

        expect(
          seen.length,
          greaterThanOrEqualTo(2),
          reason:
              '⚠️ **`prd.md` § 7.1: "moves at least every 500ms while an item is active".** The '
              'heartbeat is what satisfies it, and it is a `Timer.periodic` the loop starts at '
              '`queued → downloading`. Without it this row fails, and the requirement is unmet',
        );
        expect(
          seen.last.receivedBytes,
          4096,
          reason:
              '⚠️ **AND THE VALUE IS **UNCHANGED** — THAT IS THE OTHER HALF.** `downloads.md` § 5: '
              '"a bar that moves when nothing is being fetched **is a lie**". The heartbeat '
              're-emits the *current* value, so the row rebuilds and the fraction does not move. '
              'A tracker that nudged the value to "show life" would be lying about the download',
        );
        expect(
          seen.every((ChapterProgress p) => p.receivedBytes == 4096),
          isTrue,
          reason:
              'and **every** emission in the window carried the same figure, not just the '
              'last one',
        );
      },
    );

    test(
      '⚠️ the heartbeat uses the 500 ms constant, not "some interval"',
      () async {
        final ManualTimers timers = ManualTimers();
        final QueueProgressTracker tracker = QueueProgressTracker(
          now: () => clockAt(0),
          periodic: timers.create,
        );
        addTearDown(tracker.dispose);

        tracker.report(
          queueItemId: 'q1',
          chapterId: 'c1',
          chapterName: 'Chapter 13',
          receivedBytes: 1,
          totalBytes: 2,
        );
        await pumpEventQueue();

        expect(
          timers.created.map((ManualTimer t) => t.interval),
          <Duration>[const Duration(milliseconds: 500)],
          reason:
              '`prd.md` § 7.1 names **500 ms**, and `downloads.md` § 5 says the line "moves at the '
              'cadence the download reports". A different constant would be a different promise, '
              'and this is the only row that can see the constant',
        );
      },
    );
  });

  group('`15-performance.md` § Lists — the rate limit is on CHANGED values', () {
    test('⚠️ twelve byte counts inside one window → exactly ONE emission', () async {
      final ManualTimers timers = ManualTimers();
      int now = 0;
      final QueueProgressTracker tracker = QueueProgressTracker(
        now: () => clockAt(now),
        periodic: timers.create,
      );
      addTearDown(tracker.dispose);
      final List<ChapterProgress> seen = <ChapterProgress>[];
      final StreamSubscription<ChapterProgress> subscription = tracker.progress
          .listen(seen.add);
      addTearDown(subscription.cancel);

      tracker.report(
        queueItemId: 'q1',
        chapterId: 'c1',
        chapterName: 'Chapter 13',
        receivedBytes: 1,
        totalBytes: 4096,
      );
      await pumpEventQueue();
      expect(seen, hasLength(1), reason: 'the first value leaves immediately');

      for (int bytes = 2; bytes <= 12; bytes++) {
        now += 10; // twelve reports across 110 ms — a fast connection
        tracker.report(
          queueItemId: 'q1',
          chapterId: 'c1',
          chapterName: 'Chapter 13',
          receivedBytes: bytes,
          totalBytes: 4096,
        );
      }

      // ⚠️ **THE ONE-TURN WAIT IS LOAD-BEARING **HERE**, AND A SABOTAGE PROVED IT.**
      //
      // A broadcast controller delivers asynchronously, so without this the assertion reads a
      // list that has not received ANY of the twelve emissions yet — and it would have passed
      // with the 500 ms window deleted. `tool/sabotage_5_2_5_3.py`'s `5-3-d` row is the proof:
      // breaking the rate limit left this test green until this line was added.
      await pumpEventQueue();

      expect(
        seen.length,
        1,
        reason:
            '⚠️ **THE BOUND, AND IT IS THE POINT OF THE FUNCTION.** `15-performance.md` '
            '§Lists: "Row items must be cheap." A fast connection calls `onReceiveProgress` '
            'hundreds of times a second and each emission rebuilds the running row, so the '
            'rate limit is on **changed values** and the timer — not the network — decides '
            'when the next one leaves',
      );
      expect(
        seen.single.receivedBytes,
        1,
        reason: 'and the value that left is the FIRST one, not the last',
      );
    });

    test('⚠️ the window closing lets the NEXT changed value through', () async {
      final ManualTimers timers = ManualTimers();
      int now = 0;
      final QueueProgressTracker tracker = QueueProgressTracker(
        now: () => clockAt(now),
        periodic: timers.create,
      );
      addTearDown(tracker.dispose);
      final List<ChapterProgress> seen = <ChapterProgress>[];
      final StreamSubscription<ChapterProgress> subscription = tracker.progress
          .listen(seen.add);
      addTearDown(subscription.cancel);

      tracker.report(
        queueItemId: 'q1',
        chapterId: 'c1',
        chapterName: 'Chapter 13',
        receivedBytes: 1,
        totalBytes: 4096,
      );
      now = 700;
      tracker.report(
        queueItemId: 'q1',
        chapterId: 'c1',
        chapterName: 'Chapter 13',
        receivedBytes: 2,
        totalBytes: 4096,
      );
      await pumpEventQueue();

      expect(
        seen.map((ChapterProgress p) => p.receivedBytes),
        <int>[1, 2],
        reason:
            '§ 3.1: "at most one emission of **value modified** per 500 ms window" — and the '
            'window is **500 ms from the last emission**, not from the start of the download. '
            'A limit anchored at the download would freeze a long chapter after one frame',
      );
    });

    test(
      '⚠️ a NEW CHAPTER is not delayed by the previous one`s window (B18)',
      () async {
        final ManualTimers timers = ManualTimers();
        int now = 0;
        final QueueProgressTracker tracker = QueueProgressTracker(
          now: () => clockAt(now),
          periodic: timers.create,
        );
        addTearDown(tracker.dispose);
        final List<ChapterProgress> seen = <ChapterProgress>[];
        final StreamSubscription<ChapterProgress> subscription = tracker
            .progress
            .listen(seen.add);
        addTearDown(subscription.cancel);

        tracker.report(
          queueItemId: 'q1',
          chapterId: 'c1',
          chapterName: 'Chapter 13',
          receivedBytes: 4000,
          totalBytes: 4096,
        );
        now += 10;
        tracker.report(
          queueItemId: 'q2',
          chapterId: 'c2',
          chapterName: 'Chapter 14',
          receivedBytes: 16,
          totalBytes: 4096,
        );
        await pumpEventQueue();

        expect(
          seen.map((ChapterProgress p) => p.queueItemId),
          <String>['q1', 'q2'],
          reason:
              '⚠️ **THE ROW THAT STOPS THE RATE LIMIT FROM BECOMING A LIE.** The new value is not '
              '"the same value changed" — it is a **different chapter on a different row**. '
              'Delaying it by up to 500 ms would show chapter 14 at chapter 13`s percentage, and '
              'B18 makes the queue serial so a reader would see that as the download going '
              'backwards',
        );
        expect(
          seen.last.receivedBytes,
          16,
          reason:
              'and the value that left is the new chapter`s, not the old one`s',
        );
      },
    );
  });

  group('`downloads.md` § 8 — `0` is a claim, and a missing total is not `0`', () {
    test('⚠️ `totalBytes: 0` becomes `null`, so `fraction` is `null`', () async {
      final ManualTimers timers = ManualTimers();
      final QueueProgressTracker tracker = QueueProgressTracker(
        now: () => clockAt(0),
        periodic: timers.create,
      );
      addTearDown(tracker.dispose);
      ChapterProgress? last;
      final StreamSubscription<ChapterProgress> subscription = tracker.progress
          .listen((ChapterProgress p) => last = p);
      addTearDown(subscription.cancel);

      tracker.report(
        queueItemId: 'q1',
        chapterId: 'c1',
        chapterName: 'Chapter 13',
        receivedBytes: 100,
        totalBytes: 0,
      );
      await pumpEventQueue();

      expect(
        last!.totalBytes,
        isNull,
        reason:
            '⚠️ **`downloads.md` § 8: "Absent → the byte figure is **omitted** rather than '
            'showing `0`, which is a claim."** A server that sent no `Content-Length` and a '
            'server that sent `Content-Length: 0` are different facts and the widget must not '
            'be told they are the same',
      );
      expect(
        last!.fraction,
        isNull,
        reason:
            'and so no percentage bar is drawn at all — § 4.3: "no percentage bar", and '
            '`3-3`’s `ChapterProgressLine` renders nothing for a `null` fraction rather than a '
            'bar at zero that never moves',
      );
    });

    test('⚠️ a NEGATIVE total is dropped too, and never divides', () {
      const ChapterProgress p = ChapterProgress(
        queueItemId: 'q1',
        chapterId: 'c1',
        chapterName: 'Chapter 13',
        receivedBytes: 10,
        totalBytes: -1,
      );

      expect(
        p.fraction,
        isNull,
        reason:
            '⚠️ **A NEGATIVE TOTAL IS NOT A CLAIM EITHER.** `byte_format.dart` says the same '
            'about a negative size — "a subtraction that underflowed is a bug upstream" — and a '
            'fraction of `-10` clamped to `0.0` would draw a bar at zero, which is the lie '
            '§ 8 refuses',
      );
    });

    test('⚠️ a KNOWN total gives a clamped fraction', () {
      const ChapterProgress p = ChapterProgress(
        queueItemId: 'q1',
        chapterId: 'c1',
        chapterName: 'Chapter 13',
        receivedBytes: 4100,
        totalBytes: 4096,
      );

      expect(
        p.fraction,
        1.0,
        reason:
            'B20 + `3-3`’s note: a ratio above 1 happens when the server under-reports the '
            'length, and the bar is already at its end. Clamping is the honest response — a '
            'value outside `[0, 1]` would make `LinearProgressIndicator` throw and take the '
            'tile down over a rounding artefact',
      );
    });
  });

  group('§ 3.1 — the heartbeat has exactly three states', () {
    test('⚠️ one timer per in-flight chapter, and `stop()` ends it', () async {
      final ManualTimers timers = ManualTimers();
      final QueueProgressTracker tracker = QueueProgressTracker(
        now: () => clockAt(0),
        periodic: timers.create,
      );
      addTearDown(tracker.dispose);

      tracker.report(
        queueItemId: 'q1',
        chapterId: 'c1',
        chapterName: 'Chapter 13',
        receivedBytes: 1,
        totalBytes: 4096,
      );
      tracker.report(
        queueItemId: 'q1',
        chapterId: 'c1',
        chapterName: 'Chapter 13',
        receivedBytes: 2,
        totalBytes: 4096,
      );

      expect(
        timers.created,
        hasLength(1),
        reason:
            '⚠️ **`if (_heartbeat != null) return`.** Two timers would double the emission rate '
            'for no reason, and `prd.md` § 7.1 bounds the cadence from **above** as well as '
            'from below',
      );

      tracker.endChapterProgress();

      expect(
        timers.liveCount,
        0,
        reason:
            '§ 3.1 `stopHeartbeat`: "the heartbeat ends at the end of a chapter, and at a queue '
            'stop". A live timer whose chapter is finished is a row that rebuilds for ever with '
            'nothing to show — and a test that leaks one keeps the isolate busy for the rest of '
            'the run',
      );
    });

    test('⚠️ after `stop()` the next chapter starts a FRESH timer', () async {
      final ManualTimers timers = ManualTimers();
      int now = 0;
      final QueueProgressTracker tracker = QueueProgressTracker(
        now: () => clockAt(now),
        periodic: timers.create,
      );
      addTearDown(tracker.dispose);
      final List<ChapterProgress> seen = <ChapterProgress>[];
      final StreamSubscription<ChapterProgress> subscription = tracker.progress
          .listen(seen.add);
      addTearDown(subscription.cancel);

      tracker.report(
        queueItemId: 'q1',
        chapterId: 'c1',
        chapterName: 'Chapter 13',
        receivedBytes: 4096,
        totalBytes: 4096,
      );
      await pumpEventQueue();
      tracker.endChapterProgress();
      final int seenAfterStop = seen.length;
      now = 600;
      timers.tick();
      await pumpEventQueue();
      expect(
        seen.length,
        seenAfterStop,
        reason:
            'witness — a stopped heartbeat emits nothing, which is what "the chapter is '
            'over" means',
      );

      tracker.report(
        queueItemId: 'q2',
        chapterId: 'c2',
        chapterName: 'Chapter 14',
        receivedBytes: 8,
        totalBytes: 4096,
      );
      await pumpEventQueue();

      expect(
        timers.created,
        hasLength(2),
        reason:
            'and the next chapter gets its own — § 3.1: `startHeartbeat()` is called at the '
            '`queued → downloading` transition, so it is per chapter and not per queue',
      );
    });
  });
}
