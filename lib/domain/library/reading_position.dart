// Lumen Tale — where the reader stopped inside one chapter. B16.
//
// **Per chapter, never per novel.** Reading chapter 12 must not move the remembered
// position in chapter 13 — `library.md` § 8 and `novel-details.md` § 8 both depend on
// this being keyed by chapter, and a per-novel position cannot express "I am 40 %
// through chapter 12" at all.
//
// Pure Dart. `domain` carries no Flutter import (`02-architecture.md`), which is what
// lets [restorePosition] be tested with no widget binding.

/// Where the reader stopped inside one chapter.
///
/// Immutable and free of drift, because it is a value the reader's place in a text
/// *is*, not a row in a table. `data/` holds the row; `domain` holds this.
final class ReadingPosition {
  const ReadingPosition({
    required this.chapterId,
    required this.offset,
    required this.updatedAt,
    required this.contentHeight,
  });

  final String chapterId;

  /// A **scroll offset** in logical pixels of the scrollable content — not a page
  /// index, not a page number. ADR-009: paged modes are v2, and an offset is the only
  /// representation v2 can resume from without converting it.
  final double offset;

  /// **When this row was written**, which is not the same as when the reader last
  /// *read*: a scroll settles on overscroll and on a thumb release, so `updatedAt`
  /// advances while the reader does not. See `position_restore.dart` for why that is
  /// still the right column to sort history by.
  final DateTime updatedAt;

  /// The content height this offset was measured against, or `null` when it was
  /// never recorded.
  ///
  /// **`null` is not `0`.** `0` would be a measurement — a chapter shorter than the
  /// viewport, which is a real fact — and `null` is the absence of one. That
  /// distinction is the whole of the restore split: with a height, the position
  /// re-anchors by ratio; without one, it clamps **and says so**.
  final int? contentHeight;

  @override
  bool operator ==(Object other) =>
      other is ReadingPosition &&
      other.chapterId == chapterId &&
      other.offset == offset &&
      other.updatedAt == updatedAt &&
      other.contentHeight == contentHeight;

  @override
  int get hashCode => Object.hash(chapterId, offset, updatedAt, contentHeight);

  @override
  String toString() =>
      'ReadingPosition($chapterId, offset=$offset, height=$contentHeight)';
}
