// Lumen Tale — the queue's ONE progress stream, shared by every surface.
//
// `5-3` § 2.2. Pure Dart.
//
// ## ⚠️ **ONE STREAM, THREE SURFACES, AND THAT IS A RULE**
//
// `07-downloads-offline.md` rule 2: *"expose a Riverpod provider streaming per-chapter
// download progress and reuse it in the UI"*. `design-system.md` § 3.2 forbids showing the
// same progress in a fourth place. A second stream would be a second copy of the same
// counter, and the two would disagree the moment one of them rate-limited differently.
//
// ## ⚠️ **`ChapterProgress` IS RE-EXPORTED, AND THAT IS DELIBERATE**
//
// An interface that names a type in its own signature should hand that type to its callers.
// A second `import` per call site would be a second decision to make every time, and
// `12-ai-agent-workflow.md`'s "one dialect per concern" is easier to keep when a consumer of
// this file cannot get it half-right.

import 'package:lumen_tale/domain/downloads/chapter_progress.dart';

export 'package:lumen_tale/domain/downloads/chapter_progress.dart'
    show ChapterProgress;

/// The queue's progress, as a stream of one chapter's bytes.
abstract interface class DownloadProgressSource {
  /// ⚠️ **A BROADCAST STREAM, OR A LATE LISTENER WOULD KILL THE DOWNLOAD.** The loop starts
  /// before any widget exists (a novel can be queued from a sheet that has already been
  /// popped), and a single-subscription controller closes on its first listener's
  /// departure — which for a `StreamProvider` disposed during a navigation would take the
  /// progress channel with it.
  Stream<ChapterProgress> get progress;
}
