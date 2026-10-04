// Lumen Tale — the two numbers the queue header prints, derived and never stored.
//
// `5-1` § 5 and § 10's C8 criterion.
//
// ## ⚠️ **DERIVED, AND THAT IS THE RULE**
//
// `12 of 50 downloaded` is `count(state = 'done')` over `count(distinct chapter_id)`.
// It is **not** two columns, and § 5 is explicit about why: *"B14/B48 have already
// forbidden this kind of stored total for unread counts; the logic is identical and the
// reason too — a stored total is a second source of truth free to drift from the rows it
// counts."* A stored counter that is one `markDone` behind is a counter that tells a
// reader their chapter is missing while they are reading it.
//
// ## ⚠️ **`downloaded` COUNTS `done` AND NOTHING ELSE
//
// C8 names both failure directions: **never 13 after a failure**, and **never 11 after a
// cancellation**. A `downloading` item is not downloaded, a `failed` item is not
// downloaded, and a `queued` item is not downloaded. Only a row whose `state` is `done`
// counts, and `done` is written **after** `2-3` finished the file.

import 'package:lumen_tale/core/database/app_database.dart';
import 'package:lumen_tale/domain/downloads/queue_entry.dart';

/// Exactly what the header says: how many are stored, how many the reader asked for,
/// and how many are moving.
final class QueueProgressCounts {
  const QueueProgressCounts({
    required this.downloaded,
    required this.total,
    required this.inProgress,
  });

  /// Counts from the queue rows themselves. No clock, no I/O, no estimation.
  factory QueueProgressCounts.of(Iterable<QueueEntry> entries) {
    int downloaded = 0;
    int inProgress = 0;
    final Set<String> chapters = <String>{};
    for (final QueueEntry entry in entries) {
      chapters.add(entry.chapterId);
      switch (entry.state) {
        case DownloadState.done:
          downloaded += 1;
        case DownloadState.downloading:
          inProgress += 1;
        case DownloadState.queued:
          break;
        case DownloadState.failed:
          // ⚠️ **COUNTED IN NEITHER FIGURE, ON PURPOSE.** A failure is not a download
          // (C8), and it is not an item the reader asked to have twice.
          break;
      }
    }
    return QueueProgressCounts(
      downloaded: downloaded,
      // ⚠️ **DISTINCT CHAPTER IDS, and a reason for it.** Two queues of the same chapter
      // can coexist (§ 3.2 branch 4's generated ids), so `entries.length` would report a
      // novel as having more chapters than it has — and C8's "exact" would be exact
      // about the wrong number.
      total: chapters.length,
      inProgress: inProgress,
    );
  }

  /// `count(state = 'done')`. Never 13 after a failure, never 11 after a cancellation.
  final int downloaded;

  /// How many distinct chapters this queue covers.
  final int total;

  /// How many are being fetched **right now** — and B18 makes that at most one.
  final int inProgress;

  @override
  bool operator ==(Object other) =>
      other is QueueProgressCounts &&
      other.downloaded == downloaded &&
      other.total == total &&
      other.inProgress == inProgress;

  @override
  int get hashCode => Object.hash(downloaded, total, inProgress);

  @override
  String toString() =>
      'QueueProgressCounts($downloaded of $total downloaded, $inProgress in progress)';
}
