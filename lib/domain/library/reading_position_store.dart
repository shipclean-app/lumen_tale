// Lumen Tale — the interface `domain` owns for reading positions.
//
// `02-architecture.md` § Repository pattern: features depend on this, never on drift.
// `data/` implements it. One row per chapter, keyed by `chapterId` alone, so the
// upsert decision is not something a caller can get wrong.

import 'package:lumen_tale/domain/library/reading_position.dart';

abstract interface class ReadingPositionStore {
  /// The position for [chapterId], or `null` if there is none.
  ///
  /// This `null` is the **only** place a missing position is expressed, and it becomes
  /// `NoPosition` at the boundary — so a caller cannot read it as an offset of 0.
  Future<ReadingPosition?> read(String chapterId);

  /// **Upsert.** Writing an existing row updates it.
  ///
  /// [contentHeight] is the scroll extent [offset] was measured against —
  /// `ScrollController.position.maxScrollExtent`. It is a **required named argument**,
  /// because a save that omits it produces a position that can never be re-anchored
  /// and the height of that day is lost for good. There is no second chance to recover
  /// it later.
  ///
  /// An extent of `0` or less is not a measurement — the chapter is shorter than the
  /// viewport, or the first frame has not measured — so implementations write `null`
  /// instead, and `null` is what [restorePosition] has to handle.
  Future<void> write(
    String chapterId,
    double offset, {
    required double contentHeight,
  });

  /// Drop the position for [chapterId].
  ///
  /// Called by nothing in v1: **B46** forbids trimming a position by any retention
  /// rule. It exists so the repository is complete, and so "the only code path that
  /// deletes a position" is a named, greppable thing rather than an absence.
  Future<void> clear(String chapterId);

  /// The most recent position among [chapterIds], or `null`.
  ///
  /// This is B17's « most recently read chapter », and it comes from **this table, not
  /// from `history_entries`** — `prd.md` B17 is explicit: the history list is bounded
  /// by B47 and can be cleared, while a position never is.
  Future<ReadingPosition?> mostRecentAmong(List<String> chapterIds);
}
