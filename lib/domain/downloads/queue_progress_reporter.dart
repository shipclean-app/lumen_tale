// Lumen Tale — the narrow port the loop uses to publish one chapter's byte progress.
//
// `5-3` § 3.1. `domain/`, because both ends need it: `data/downloads/` produces it and
// `features/downloads/` consumes it, and neither may import the other.
//
// ## ⚠️ **THE LOOP DOES NOT KNOW ABOUT CADENCE, AND THAT IS THE WHOLE DESIGN**
//
// `prd.md` § 7.1's 500 ms is a property of what a **widget** can be rebuilt at, not of what
// the transport observed. So the loop reports raw byte counts through this three-scalar port
// and `data/downloads/queue_progress_tracker.dart` decides what leaves. A loop that
// rate-limited its own reporting would put a UI budget inside an orchestration.
//
// ## ⚠️ **`totalBytes` IS `int?` BECAUSE `0` AND "ABSENT" ARE NOT THE SAME CLAIM**
//
// `downloads.md` § 8: a server that sends no `Content-Length` leaves the byte figure
// **omitted**, because `0` says "nothing at all". The port therefore cannot express `0` as
// a total — a caller with no total passes `null`, and the tracker normalises a non-positive
// total to `null` as well, so a lie has to be told deliberately.

/// What the loop reports, with no cadence and no policy.
abstract interface class ChapterProgressReporter {
  /// [totalBytes] is `null` when the server did not say how big the chapter is.
  void reportChapterProgress({
    required String queueItemId,
    required String chapterId,
    required String chapterName,
    required int receivedBytes,
    required int? totalBytes,
  });

  /// The chapter in flight is over. `5-3` § 3.1: the heartbeat ends **here** — a live timer
  /// whose chapter is finished is a row that rebuilds for ever with nothing to show.
  void endChapterProgress();
}
