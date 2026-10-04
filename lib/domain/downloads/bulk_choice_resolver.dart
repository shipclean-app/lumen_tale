// Lumen Tale — B18's six choices resolved into an ordered list of chapter ids.
//
// `5-1` § 3.1. **A pure function**: no I/O, no provider, no database, no clock. That is
// what makes the rule testable — `10-testing.md` rule 4 says a pure function is tested
// without a database, and this one is the rule B18 is written in.
//
// ## ⚠️ READING ORDER IS QUEUE ORDER, AND IT IS `ordinal`
//
// The list is sorted by `DownloadableChapter.ordinal` — the site's own order (B9) — and
// **never** by `number`: `number` is `-1` when the site published something unreadable
// and it restarts at zero in every volume, so sorting by it interleaves the volumes and
// produces a queue that does not read in order. A novel whose fifth chapter has
// `number = -1` therefore keeps that chapter **in fifth place**.
//
// ## ⚠️ `HandPicked` KEEPS THE CALLER'S ORDER, AND THAT IS THE OPPOSITE RULE
//
// Every other branch sorts; this one must not. `novel-details.md` § 11.3 forbids a
// reordering gesture in the selection bar, so the order the reader tapped is the only
// order there is, and sorting it by `ordinal` would throw away the one thing they
// expressed. The two orders coexist on purpose and a test holds each in place.

import 'package:lumen_tale/domain/downloads/bulk_choice.dart';

/// The only thing a choice needs to know about a chapter.
///
/// ⚠️ **DELIBERATELY NOT A drift ROW.** The resolver is a pure function; a parameter that
/// carried `ChapterRow` would make it untestable without a database and would put a
/// `data/` type in `domain/`'s signature. Four fields, three of which are facts about
/// the chapter and one of which is B6's mark.
final class DownloadableChapter {
  const DownloadableChapter({
    required this.id,
    required this.ordinal,
    required this.isRead,
    required this.downloadedAt,
  });

  final String id;

  /// The site's own order (B9). **Never `number`.**
  final int ordinal;

  /// B13 — the reader has opened it.
  final bool isRead;

  /// ⚠️ **B6's MARK, and `null` is the answer that matters.** Non-null means `2-3`
  /// finished writing the file *before* writing the mark, so a stored chapter is one
  /// that can be opened. It is never a filesystem probe: ADR-022 made the mark the
  /// discriminator precisely so a deleted copy and a lost file can be told apart.
  final DateTime? downloadedAt;

  /// `07-downloads-offline.md` rule 3 — *do not refetch*. A chapter with a stored copy
  /// is never enqueued again by any of the six choices.
  bool get isStored => downloadedAt != null;

  @override
  bool operator ==(Object other) =>
      other is DownloadableChapter &&
      other.id == id &&
      other.ordinal == ordinal &&
      other.isRead == isRead &&
      other.downloadedAt == downloadedAt;

  @override
  int get hashCode => Object.hash(id, ordinal, isRead, downloadedAt);

  @override
  String toString() => 'DownloadableChapter($id, ordinal: $ordinal)';
}

/// The chapter ids to enqueue for [choice], **in queue order**.
///
/// ⚠️ **AN EMPTY RESULT IS A RESULT, NOT A FAILURE.** A novel whose every chapter is
/// stored answers `[]`, a novel the reader has opened in full answers `[]` for
/// `AllUnopened`, and neither is an error: the sheet says there is nothing left to
/// download and no dialog appears. § 3.1's second half is these cases.
List<String> resolveBulkChoice(
  BulkChoice choice, {
  required List<DownloadableChapter> chapters,
}) {
  // ⚠️ **A COPY BEFORE THE SORT.** Sorting the caller's list in place would reorder a
  // provider's cached chapter list — `watchChapters` hands out the very list a screen
  // rebuilds from — and a pure function with a side effect on its argument is not pure.
  final List<DownloadableChapter> byReadingOrder =
      <DownloadableChapter>[...chapters]..sort(
        (DownloadableChapter a, DownloadableChapter b) =>
            a.ordinal.compareTo(b.ordinal),
      );

  return switch (choice) {
    // ⚠️ **FILTERS ON `isStored` AND NOTHING ELSE** — `Next chapter` stays available on a
    // novel whose chapters have all been opened, which is what `novel-details.md` § 11.1
    // requires and what `isRead == false` here would make impossible.
    NextChapter() => <String>[
      for (final DownloadableChapter c in byReadingOrder)
        if (!c.isStored) c.id,
    ].take(1).toList(growable: false),

    // ⚠️ **`take(count)` and NOT `min(count, total)`.** The sheet's displayed count is
    // `resolveBulkChoice(choice).length` — the same call — so the number a reader sees
    // and the number the queue applies cannot come from two spellings of the same idea.
    NextChapters(:final int count) => <String>[
      for (final DownloadableChapter c in byReadingOrder)
        if (!c.isStored) c.id,
    ].take(count).toList(growable: false),

    // ⚠️ **THE ONLY BRANCH THAT MENTIONS `isRead`.** Not read **and** not stored: a
    // chapter that was opened and then downloaded is not fetched again
    // (`07-downloads-offline.md` rule 3).
    AllUnopened() => <String>[
      for (final DownloadableChapter c in byReadingOrder)
        if (!c.isRead && !c.isStored) c.id,
    ],

    // ⚠️ **THE CALLER'S ORDER, AND THE CALLER'S SET.**
    //
    // * `firstWhere`, not a map lookup: an id the caller never displayed is a **caller
    //   defect**, and it must fail loudly rather than be silently dropped. The
    //   selection bar offers only ids it rendered and `novel-details.md` § 11.3 forbids
    //   it inventing one, so this is unreachable through the interface.
    // * the `seen` set is § 3.2's branch 5 — a repeated id yields **one** row. The
    //   selection bar is a toggle and cannot produce a duplicate; the guarantee is here
    //   so the queue holds it even if a future caller can.
    HandPicked(:final List<String> chapterIds) => _handPicked(
      chapterIds,
      chapters,
    ),
  };
}

List<String> _handPicked(
  List<String> chapterIds,
  List<DownloadableChapter> chapters,
) {
  final List<String> picked = <String>[];
  final Set<String> seen = <String>{};
  for (final String id in chapterIds) {
    if (!seen.add(id)) {
      continue;
    }
    final DownloadableChapter chapter = chapters.firstWhere(
      (DownloadableChapter c) => c.id == id,
    );
    if (chapter.isStored) {
      continue;
    }
    picked.add(id);
  }
  return List<String>.unmodifiable(picked);
}
