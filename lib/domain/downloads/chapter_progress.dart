// Lumen Tale — one chapter's progress, and the fraction that is deliberately absent.
//
// `5-3` § 2.2. Pure Dart; `domain/` carries no Flutter import (`02-architecture.md`).
//
// ## ⚠️ **A PROGRESS OF ONE CHAPTER, NEVER OF THE NOVEL**
//
// `downloads.md` § 2.1: *"progress is never a single aggregate bar over the novel — a
// single bar would imply a parallelism the app does not have."* B18 makes the queue serial
// **by construction** (`architecture.md` § 4.5 deleted the concurrency column so it could
// not be changed), so a total would be a claim about work the app is not doing.
//
// ## ⚠️ **`totalBytes == null` IS INFORMATION, AND `fraction == null` IS THE HONEST ANSWER**
//
// `downloads.md` § 8: *"Absent → the byte figure is omitted rather than showing `0`, which
// is a claim."* A server that sends no `Content-Length` leaves us unable to say how much is
// left; `0` would say "nothing at all" and `0.0` would draw a bar at zero that never moves,
// which is a bar that lies.
//
// ## ⚠️ **`==` AND `hashCode` ARE HAND-WRITTEN**, for `queue_entry.dart`'s reason: this is a
// value carrier the deriver compares with `!=` to decide whether an emission is a *change*,
// and identity comparison would report every byte as new.

/// One chapter's byte progress.
final class ChapterProgress {
  const ChapterProgress({
    required this.queueItemId,
    required this.chapterId,
    required this.chapterName,
    required this.receivedBytes,
    required this.totalBytes,
  });

  /// ⚠️ **THE QUEUE ITEM's ID, NOT THE CHAPTER's.** Two queue rows of the same chapter can
  /// coexist (`3-3`'s explicit re-download), and progress belongs to the *attempt*; a
  /// consumer keying on `chapterId` would merge two downloads into one bar.
  final String queueItemId;

  final String chapterId;

  /// B10 — the site's own title, verbatim, because it is the row's identity.
  final String chapterName;

  final int receivedBytes;

  /// `null` when the server sent no `Content-Length`. **Never `0`** — see the header.
  final int? totalBytes;

  /// `null` when [totalBytes] is `null`, **and `null` again when it is zero or negative.**
  ///
  /// ⚠️ **BOTH `0` AND A NEGATIVE ARE REFUSED, NOT ONLY `0`.** A zero total is a claim about
  /// the response rather than about the chapter, and dividing by it would produce infinity;
  /// a *negative* total is a bug upstream (`byte_format.dart` says the same about a negative
  /// size), and `10 / -1` clamped to `[0, 1]` is `0.0` — **a bar drawn at zero**, which is
  /// exactly the lie `downloads.md` § 8 refuses. The tracker already normalises a non-positive
  /// total to `null`; this is the second half, for a value constructed directly.
  double? get fraction {
    final int? total = totalBytes;
    if (total == null || total <= 0) {
      return null;
    }
    return (receivedBytes / total).clamp(0.0, 1.0);
  }

  @override
  bool operator ==(Object other) =>
      other is ChapterProgress &&
      other.queueItemId == queueItemId &&
      other.chapterId == chapterId &&
      other.chapterName == chapterName &&
      other.receivedBytes == receivedBytes &&
      other.totalBytes == totalBytes;

  @override
  int get hashCode => Object.hash(
    queueItemId,
    chapterId,
    chapterName,
    receivedBytes,
    totalBytes,
  );

  /// ⚠️ **IDS AND THE CHAPTER's OWN NAME, NEVER THE TEXT.** `13-error-handling.md` rule 6
  /// and `5-3` § 7's last row: a log line is read aloud to whoever maintains the app, and a
  /// chapter's prose is not evidence.
  @override
  String toString() =>
      'ChapterProgress($chapterName, $receivedBytes'
      '${totalBytes == null ? '/?' : '/$totalBytes'} bytes)';
}
