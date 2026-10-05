// Lumen Tale — « where do I resume this chapter? », as a pure function.
//
// This is the whole of B27's logic and it lives here, with no `ScrollController`, no
// widget, no clock and no database — because the interesting cases are all arithmetic
// and arithmetic is cheap to test exhaustively.
//
// ## The one thing that decides which answer applies
//
// **Did the row keep the height its offset was measured against?**
//
// * Yes → the fraction of the chapter survives a text-size change, so re-anchor by
//   ratio onto whatever the extent is now.
// * No  → there is nothing to re-anchor *to*, so use the pixel as-is and clamp.
//   Never invent a ratio.
//
// ## Why a scroll settle is not a read
//
// `updatedAt` moves on overscroll and on a thumb release — events where the reader
// did not advance. It is still the right column for "most recent chapter", because a
// finished chapter produces no further writes and so never climbs: the last place
// the scroll stopped is, in almost every case, the chapter being read. Turning that
// column into « last time read » would need a separate table and would be wrong at
// exactly the moment it mattered — a reader who reopened a chapter they had finished.

import 'package:lumen_tale/domain/library/reading_position.dart';

/// The answer to « where do I resume this chapter? ».
///
/// **Sealed**, because "no row" and "a row at zero" are different facts and the whole
/// point of the type is that a caller cannot tell them apart by accident. Same shape
/// `failure-discriminator` gives a read.
sealed class ResumePoint {
  const ResumePoint();
}

/// No row. The chapter was never opened, or its position went with its chapter.
///
/// `novel-details.md` § 8: the `current` tile and « Jump to current chapter » are
/// **absent**, not rendered empty — so the reader never sees "chapter 0".
final class NoPosition extends ResumePoint {
  const NoPosition();
}

/// A stored position, resolved against the content that exists now.
final class ResumeAt extends ResumePoint {
  const ResumeAt({
    required this.offset,
    required this.updatedAt,
    required this.wasClamped,
    required this.anchoredByRatio,
  });

  /// Where to scroll, in logical pixels of the extent that was supplied.
  final double offset;

  /// The row's own timestamp, carried through so a caller can show « last read » and
  /// so B17's ordering needs no second lookup.
  final DateTime updatedAt;

  /// **True when the position could not be placed inside the content that exists now**
  /// and was pulled back to its end. Two ways that happens: the offset was already
  /// past the current extent, or the re-anchored ratio was.
  ///
  /// Not a detail: the reader must be told the chapter opened at its end rather than
  /// at their paragraph. B24's "an error the user can read and act on", applied to a
  /// silent inaccuracy.
  final bool wasClamped;

  /// **True when the offset was projected by ratio** — the row carried a
  /// `contentHeight` and the stored pixel was scaled onto the height on screen now.
  /// `false` means the stored pixel was used as-is.
  ///
  /// An estimate, not an exact pixel: the fraction of a chapter someone consumed
  /// survives a text-size change, the exact line does not. It is **not** surfaced as
  /// an error — changing the text size is not something the reader did wrong — but it
  /// must never be reported as an exact restore either.
  final bool anchoredByRatio;

  @override
  bool operator ==(Object other) =>
      other is ResumeAt &&
      other.offset == offset &&
      other.updatedAt == updatedAt &&
      other.wasClamped == wasClamped &&
      other.anchoredByRatio == anchoredByRatio;

  @override
  int get hashCode =>
      Object.hash(offset, updatedAt, wasClamped, anchoredByRatio);

  @override
  String toString() =>
      'ResumeAt($offset, clamped=$wasClamped, byRatio=$anchoredByRatio)';
}

/// Restores a stored position against the extent on screen **right now**.
///
/// [currentScrollExtent] is supplied by the caller because only whoever holds the
/// widget can measure it, and it is the argument that makes a font-size change
/// survivable. Treat a non-positive extent as "nothing is measurable yet" rather than
/// clamping to it: a zero extent means the chapter has not been laid out, and clamping
/// a real position to zero would throw away the reader's place.
ResumePoint restorePosition({
  required ReadingPosition? stored,
  required double currentScrollExtent,
}) {
  // ── branch 1: no row ──────────────────────────────────────────────────
  if (stored == null) {
    return const NoPosition();
  }

  final double raw = stored.offset;

  // ── branch 2: a null or negative offset ───────────────────────────────
  //
  // ⚠️ No "clamp to the top" here. `0` is a **legitimate** value: the reader opened
  // the chapter, did not scroll, and closed it. That position exists and is worth 0.
  // The `<= 0` test exists only to defend against a negative value that should never
  // arrive — it is not an instruction to discard a position.
  if (raw <= 0) {
    return ResumeAt(
      offset: 0,
      updatedAt: stored.updatedAt,
      wasClamped: false,
      anchoredByRatio: false,
    );
  }

  // Not laid out yet. Return what is stored, un-clamped and un-projected, so the
  // caller re-runs this once it has an extent. Throwing away a position because a
  // frame has not been measured yet would be a data loss caused by a timing detail.
  if (currentScrollExtent <= 0) {
    return ResumeAt(
      offset: raw,
      updatedAt: stored.updatedAt,
      wasClamped: false,
      anchoredByRatio: false,
    );
  }

  // ── branch 3: the height was recorded → re-anchor by ratio ───────────
  //
  // What survives a text-size change is not the pixel; it is the fraction of the
  // chapter already read.
  final int? storedHeight = stored.contentHeight;
  if (storedHeight != null && storedHeight > 0) {
    final double fraction = raw / storedHeight;
    final double reanchored = fraction * currentScrollExtent;

    // ⚠️ THE CLAMP IS ALWAYS THE LAST WORD. A chapter that shrank — the reader
    // leaving a very large text size — yields a fraction beyond the new extent, and
    // the end of the chapter is then the least-wrong estimate. It is also disclosed,
    // because a confident wrong position is worse than a bounded one (ADR-022).
    if (reanchored > currentScrollExtent) {
      return ResumeAt(
        offset: currentScrollExtent,
        updatedAt: stored.updatedAt,
        wasClamped: true,
        anchoredByRatio: true,
      );
    }
    return ResumeAt(
      offset: reanchored,
      updatedAt: stored.updatedAt,
      wasClamped: false,
      anchoredByRatio: true,
    );
  }

  // ── branch 4: no height recorded → the pixel as-is, clamped and DISCLOSED ──
  //
  // ⚠️ This is the common case for every row written before `contentHeight` existed.
  // The offset was measured in pixels against a height nobody kept, so there is
  // nothing to re-anchor by. Using the pixel is the best available answer and the
  // only honest one: a clamped guess built from an assumed ratio would be a number
  // that looks measured and is not.
  if (raw > currentScrollExtent) {
    return ResumeAt(
      offset: currentScrollExtent,
      updatedAt: stored.updatedAt,
      wasClamped: true,
      anchoredByRatio: false,
    );
  }
  return ResumeAt(
    offset: raw,
    updatedAt: stored.updatedAt,
    wasClamped: false,
    anchoredByRatio: false,
  );
}
