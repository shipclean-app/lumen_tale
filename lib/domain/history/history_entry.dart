// Lumen Tale — one line of the journal, and the one thing it deliberately lacks.
//
// `06-database.md` and the `6-5` plan agree that **the object the history screen
// renders is incapable of showing where the reader stopped**, because it does not
// know. That absence is B46 in mechanical form: *"a reading position is not a
// history entry"*.
//
// A field here — `offset`, `percent`, `progress` — would not be unused. It would be
// *displayed*, and a journal row showing "62%" is the reader believing two facts
// came from one record when they came from two files with two retention rules, one of
// which B47 bounds and the other of which nothing bounds at all.
//
// Pure Dart. No Flutter import (`02-architecture.md`).

/// One chapter, opened, at one instant.
///
/// ⚠️ **No unique key on `(novel_id, chapter_id)`** — deliberately, and this class
/// is where that becomes visible. Opening the same chapter twice writes **two**
/// entries with two `openedAt`: it is a journal of what was opened, and
/// `history.md` § 4 requires that re-opening a chapter show a fresh entry at its
/// new date. B47's window then removes the older of the two first, which is the
/// correct outcome rather than a de-duplication bug.
final class HistoryEntry {
  const HistoryEntry({
    required this.id,
    required this.novelId,
    required this.novelTitle,
    required this.chapterId,
    required this.chapterTitle,
    required this.openedAt,
  });

  final String id;

  final String novelId;

  /// The site's own title, verbatim. B10: never title-cased, never corrected.
  final String novelTitle;

  final String chapterId;

  /// The site's own label, verbatim. **Empty at the source renders as *Untitled*** —
  /// never as an index, and never as a generated number.
  final String chapterTitle;

  /// B17 — the ordering column, descending. An **instant**, never a stored day: the
  /// header a reader sees is computed from this at read time, so a timezone or clock
  /// change re-labels the groups instead of stranding a row under yesterday's
  /// header.
  final DateTime openedAt;

  @override
  String toString() => 'HistoryEntry($id)';
}

/// Where the reader stopped, **for one novel**.
///
/// B17's second sentence: *"the chapter read most recently for a novel comes from
/// the position record, not from this list"*. The two files are dissimilar by
/// construction — the journal is bounded and erasable, the position is neither — so
/// "resume where I was" is **two separate queries** and cannot be a join.
///
/// ⚠️ [offset] is a **scroll offset**, not a page index (ADR-009), and it is the only
/// place in the product where a position is read in order to be *displayed*.
final class NovelResumePoint {
  const NovelResumePoint({
    required this.novelId,
    required this.chapterId,
    required this.chapterTitle,
    required this.offset,
    required this.updatedAt,
  });

  final String novelId;
  final String chapterId;

  /// The site's own label, verbatim — B10, as everywhere.
  final String chapterTitle;

  /// B16 / ADR-009 — a scroll offset in pixels.
  final double offset;

  /// When the position was last written. `2-6` stamps this from the **store**, not
  /// from a parameter, so a caller cannot back-date a position it just saved.
  final DateTime updatedAt;

  @override
  String toString() => 'NovelResumePoint($novelId)';
}
