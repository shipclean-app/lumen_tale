// Lumen Tale — `prd.md` § 7.1's 500 ms cadence, and the bar that must not move because of
// it.
//
// `5-3` § 3.1. `data/downloads/`, because the loop is orchestration and orchestration is not
// presentation (`02-architecture.md` § Dependency rules).
//
// ## ⚠️ **TWO REQUIREMENTS THAT LOOK LIKE ONE AND ARE NOT**
//
//   * *"moves at least every 500 ms while an item is active"* — about **emissions**;
//   * *"a bar that moves when nothing is being fetched is a lie"* (`downloads.md` § 5) —
//     about **values**.
//
// They are satisfied simultaneously by the heartbeat: it **re-emits the current value**,
// which is identical, so a line that rebuilds renders the same fraction and the bar stands
// still while the row is visibly alive.
//
// ## ⚠️ **AT MOST ONE *CHANGED* VALUE PER 500 ms WINDOW, AND THE BOUND IS THE POINT**
//
// A fast connection calls `onReceiveProgress` hundreds of times a second, and every emission
// rebuilds the row that is running. Emitting each one would be `15-performance.md`
// §Lists' *"row items must be cheap"* violated fifty times over, so the **rate limit is on
// changed values**, and the timer — not the network — decides when the next one leaves.
//
// ## ⚠️ **THE CLOCK IS INJECTED, AND THAT IS WHAT MAKES IT TESTABLE**
//
// `prd.md` § 7.1's 500 ms is *"the only performance objective of the project provable in
// CI"*, and a test can prove it only if it can move time without waiting. [now] and
// [periodic] are therefore constructor parameters; production passes the real clock and
// `Timer.periodic`.

import 'dart:async';

import 'package:lumen_tale/domain/downloads/download_progress_source.dart';
import 'package:lumen_tale/domain/downloads/queue_progress_reporter.dart';

/// The cadence. `prd.md` § 7.1.
const Duration kDownloadProgressCadence = Duration(milliseconds: 500);

/// Turns a stream of byte counts into a bounded stream of *changed* values, with a heartbeat
/// that proves the chapter is still in flight.
final class QueueProgressTracker
    implements DownloadProgressSource, ChapterProgressReporter {
  QueueProgressTracker({
    DateTime Function()? now,
    Timer Function(Duration, void Function(Timer))? periodic,
  }) : _now = now ?? DateTime.now,
       _periodic = periodic ?? Timer.periodic;

  final DateTime Function() _now;
  final Timer Function(Duration, void Function(Timer)) _periodic;

  final StreamController<ChapterProgress> _sink =
      StreamController<ChapterProgress>.broadcast();

  /// ⚠️ **A BROADCAST CONTROLLER**, and `DownloadProgressSource`'s doc says why: the loop
  /// runs before any widget exists, and a single-subscription controller would be torn down
  /// by the first listener's departure.
  @override
  Stream<ChapterProgress> get progress => _sink.stream;

  ChapterProgress? _current;
  ChapterProgress? _lastEmitted;
  DateTime? _lastEmittedAt;
  Timer? _heartbeat;

  /// How many *changed* values have left. **Not the heartbeat's count** — that is the point
  /// of the split, and a row asserting on the wrong counter would pass for the wrong reason.
  int emittedChanges = 0;

  /// Reports [receivedBytes] / [totalBytes] for the chapter currently being fetched.
  ///
  /// ⚠️ **`total <= 0` BECOMES `null`, AND NEVER `0`.** `downloads.md` § 8: a missing
  /// `Content-Length` means the byte figure is *omitted*, because `0` is a claim.
  @override
  void reportChapterProgress({
    required String queueItemId,
    required String chapterId,
    required String chapterName,
    required int receivedBytes,
    required int? totalBytes,
  }) {
    report(
      queueItemId: queueItemId,
      chapterId: chapterId,
      chapterName: chapterName,
      receivedBytes: receivedBytes,
      totalBytes: totalBytes,
    );
  }

  /// The in-flight chapter is over, and its heartbeat with it.
  @override
  void endChapterProgress() => stop();

  /// The reporting entry point, also callable directly by a test that drives the cadence
  /// without a queue behind it.
  void report({
    required String queueItemId,
    required String chapterId,
    required String chapterName,
    required int receivedBytes,
    required int? totalBytes,
  }) {
    final ChapterProgress next = ChapterProgress(
      queueItemId: queueItemId,
      chapterId: chapterId,
      chapterName: chapterName,
      receivedBytes: receivedBytes,
      totalBytes: (totalBytes == null || totalBytes <= 0) ? null : totalBytes,
    );
    // ⚠️ **A DIFFERENT `queueItemId` IS A DIFFERENT ATTEMPT, EVEN WITHIN THE WINDOW.**
    //
    // Two queue rows can hold the same chapter (`3-3`'s explicit re-download), so progress
    // belongs to the *attempt*. Chapter 14's first value is not "chapter 13's value, changed",
    // and rate-limiting it would draw chapter 14 at chapter 13's percentage — which B18's
    // serial queue makes look like the download going backwards.
    final bool sameAttempt =
        _lastEmitted != null && _lastEmitted!.queueItemId == queueItemId;
    _current = next;

    // ⚠️ **THE HEARTBEAT STARTS ON **EVERY** REPORT, INCLUDING THE FIRST ONE.**
    //
    // § 3.1: `startHeartbeat()` is called at the `queued → downloading` transition, and the
    // first report *is* that transition. The first version started it only on the path that
    // did **not** emit, so a chapter whose server sent one chunk and then went quiet produced
    // nothing at all — the exact case `prd.md` § 7.1's "moves at least every 500ms while an
    // item is active" is written for.
    _startHeartbeat();

    final DateTime now = _now();
    if (!sameAttempt) {
      _emit(next, now);
      return;
    }
    if (next == _lastEmitted) {
      return; // unchanged: the heartbeat will carry it
    }
    final DateTime? last = _lastEmittedAt;
    if (last == null || now.difference(last) >= kDownloadProgressCadence) {
      _emit(next, now);
    }
  }

  /// ⚠️ **THE HEARTBEAT RE-EMITS `_current` UNCHANGED.** This one method is what satisfies
  /// both halves of `prd.md` § 7.1: the row rebuilds, and because the value is identical
  /// the bar does not move by one pixel. Nudging the value to "show life" would be a lie
  /// about how much has been downloaded.
  void _emit(ChapterProgress value, DateTime now) {
    _lastEmitted = value;
    _lastEmittedAt = now;
    emittedChanges += 1;
    if (!_sink.isClosed) {
      _sink.add(value);
    }
  }

  /// `queued → downloading`. ⚠️ **`if (_heartbeat != null) return`** — one timer per
  /// in-flight chapter, and a second one would double the emission rate for no reason.
  void _startHeartbeat() {
    if (_heartbeat != null) {
      return;
    }
    _heartbeat = _periodic(kDownloadProgressCadence, (Timer timer) {
      final ChapterProgress? value = _current;
      // ⚠️ **`_emit` AND NOT A RAW `add`.** The rate limit is on *changed* values, and the
      // heartbeat's emissions must not reset the window or count as changes.
      if (value != null) {
        if (!_sink.isClosed) {
          _sink.add(value);
        }
      }
    });
  }

  /// ⚠️ **CALLED AT THE END OF EVERY CHAPTER AND AT EVERY STOP.** A live timer whose chapter
  /// is finished is a widget that rebuilds for ever with nothing to show, and a test that
  /// leaks one keeps the isolate's event queue busy for the rest of the run.
  void stop() {
    _heartbeat?.cancel();
    _heartbeat = null;
    _current = null;
    _lastEmitted = null;
    _lastEmittedAt = null;
  }

  /// Releases the controller. The stream is **never closed while a chapter is in flight**
  /// (§ 3.1's third state), and `dispose` is the one caller that is allowed to.
  void dispose() {
    stop();
    _sink.close();
  }
}
