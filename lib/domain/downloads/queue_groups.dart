// Lumen Tale — one novel's slice of the queue, and the structural answer to E17.
//
// `5-3` § 3.6. Pure Dart.
//
// ## ⚠️ **GROUPED BY `novelId`, AND NEVER BY TITLE**
//
// E17: *"Two novels with the same title, from different sites … they remain two distinct
// novels … they are never merged (B2)."* The grouping key is the id, and `title` appears in
// this file **only** as the label to display. A `GROUP BY title` anywhere in the queue
// would merge `Mother of Learning` at Royal Road with `Mother of Learning` at FanMTL into
// one 96-chapter download, and every figure on the screen would be a lie about both.
//
// ## ⚠️ **THE GROUPING IS STRUCTURAL, NOT A SCREEN CONVENTION**
//
// `chapterId` derives from `novelId`, which derives from `sourceId` (`architecture.md`
// § 4.1, B2) — so two same-titled novels produce six distinct queue rows in six distinct
// chapters, and this function returns two groups. `5-3` § 10 asserts both, and
// `grep 'chapters.title' lib/features/downloads/` asserts the negative.
//
// ## ⚠️ **EACH GROUP CARRIES ITS OWN COUNTS.** § 3.6: *"a '12 of 50' counter per queue —
// never a total aggregated over two same-named novels."* The counts are therefore derived
// per group and never from the flat list.

import 'package:lumen_tale/domain/downloads/queue_entry.dart';
import 'package:lumen_tale/domain/downloads/queue_progress_counts.dart';

/// One novel's rows, with its own header figures.
final class NovelQueueGroup {
  const NovelQueueGroup({
    required this.novelId,
    required this.novelTitle,
    required this.sourceId,
    required this.entries,
  });

  final String novelId;

  /// ⚠️ **DISPLAY ONLY.** See the header: this string is never a key, and grouping by it is
  /// the defect E17 exists to forbid.
  final String novelTitle;

  /// B2 — the one site this novel came from. Carried so a collapsed source failure can name
  /// the site rather than a hash.
  final String sourceId;

  /// In `queue_position` order, which is the reading order (B18).
  final List<QueueEntry> entries;

  /// `count(state='done')` over **this group only**.
  QueueProgressCounts get counts => QueueProgressCounts.of(entries);

  @override
  String toString() =>
      'NovelQueueGroup($novelId, "$novelTitle", ${entries.length} rows, $counts)';
}

/// Splits a flat queue into one group per novel, in first-appearance order.
///
/// ⚠️ **ORDER IS THE ORDER THE ROWS ARRIVE IN**, which is `queue_position` order — the
/// order the reader asked for. Re-sorting the groups by title would be the E17 defect in a
/// different shape.
List<NovelQueueGroup> groupQueueByNovel(List<QueueEntry> entries) {
  final Map<String, List<QueueEntry>> byNovel = <String, List<QueueEntry>>{};
  for (final QueueEntry entry in entries) {
    byNovel.putIfAbsent(entry.novelId, () => <QueueEntry>[]).add(entry);
  }
  return <NovelQueueGroup>[
    for (final MapEntry<String, List<QueueEntry>> group in byNovel.entries)
      NovelQueueGroup(
        novelId: group.key,
        // ⚠️ **THE TITLE OF THE **FIRST** ROW, and a queue row cannot disagree with itself.**
        // Two rows of one novel carry the same title because both joined `novels`; taking
        // the first is a total function on rows that are equal in this field, whereas
        // "the most common" would be an algorithm nobody asked for.
        novelTitle: group.value.first.novelTitle,
        sourceId: group.value.first.sourceId,
        entries: List<QueueEntry>.unmodifiable(group.value),
      ),
  ];
}
