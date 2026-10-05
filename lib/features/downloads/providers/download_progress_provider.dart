// Lumen Tale — the queue's byte progress, as one provider for three surfaces.
//
// `5-3` § 4.2. `features/downloads/providers/`, for `5-1`'s reason: these are UI-facing
// handles, and the tracker they wrap is orchestration.
//
// ## ⚠️ **ONE PROVIDER, THREE READERS, AND THAT IS A RULE NOT AN OPTIMISATION**
//
// `07-downloads-offline.md` rule 2: *"expose a Riverpod provider streaming per-chapter
// download progress and reuse it in the UI"*. `design-system.md` § 3.2 lists exactly three
// places the progress may appear — the library row, the novel's page and
// `AppScaffold`'s `persistentStatus` — and this screen is where the reader *goes*, not a
// fourth place a bar is duplicated into. A second provider would be a second counter, and
// the two would disagree the moment one of them missed an emission.
//
// ## ⚠️ **`keepAlive` FOR THE SAME REASON AS THE REST OF THE QUEUE**
//
// A download must survive the reader navigating away (`5-1`'s header, E15). An
// `autoDispose` stream would be torn down with the screen that first listened to it, and the
// loop's next `report` would land on a closed subscription — the progress bar would freeze
// at a fraction while chapters kept arriving.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lumen_tale/data/downloads/queue_progress_tracker.dart';
import 'package:lumen_tale/domain/downloads/chapter_progress.dart';
import 'package:lumen_tale/domain/downloads/queue_progress_reporter.dart';

/// The one tracker. Built once and held for the session — see the header.
final queueProgressTrackerProvider = Provider<QueueProgressTracker>((Ref ref) {
  final QueueProgressTracker tracker = QueueProgressTracker();
  // ⚠️ **`ref.onDispose` AND NOT A TIMER SOMEONE ELSE OWNS.** The tracker holds a
  // `Timer.periodic`; a disposed provider that left it running would keep the isolate's event
  // queue busy and keep pushing values nobody listens to.
  ref.onDispose(tracker.dispose);
  return tracker;
});

/// The port the loop reports through. `data/downloads/serial_download_queue_runner.dart`
/// takes this rather than the tracker, so the loop never learns that a cadence exists.
final queueProgressReporterProvider = Provider<ChapterProgressReporter>(
  (Ref ref) => ref.watch(queueProgressTrackerProvider),
);

/// The stream the three surfaces read.
///
/// ⚠️ **`StreamProvider`, AND `loading` IS THE ONLY NON-DATA STATE.** There is no error
/// state to handle: a progress stream cannot fail, and giving it one would mean a screen
/// writing an error path for something that has no failure mode.
final downloadProgressProvider = StreamProvider<ChapterProgress>(
  (Ref ref) => ref.watch(queueProgressTrackerProvider).progress,
);
