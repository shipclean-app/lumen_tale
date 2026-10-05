// Lumen Tale — the queue's half of the atomic write, stated as an interface it can hold.
//
// `5-1` § 3.3. The loop calls this and **must not** know it is a filesystem.
//
// ## ⚠️ WHY THIS EXISTS RATHER THAN THE LOOP HOLDING `ChapterStore` DIRECTLY
//
// `ChapterStore` lives in `features/downloads/domain/`, and `02-architecture.md`'s
// dependency table says `data` must not depend on `features`. `data/downloads/` already
// has one such import (`drift_chapter_action_repository.dart`, from `3-3`) and it is
// that slice's debt to close, not a licence for a second one. So the runner — which is
// orchestration, and lives in `data/` — programs against **this** port, and
// `features/downloads/stored_chapter_writer.dart` is the one adapter that bridges it to
// `ChapterStore`. Same call sequence, same exceptions, no new `data/` → `features/` edge.
//
// ## ⚠️ `ordinal` IS THE FILENAME, AND THIS PORT IS WHY THAT IS UNMISSABLE
//
// `2-3` writes `<ordinal>.md`, never `<number>.md`: `number` is `-1` when unreadable and
// restarts per volume, so a filename built from it collides across volumes — two
// chapters, one file, one of them silently replaced.

/// Writes one chapter's Markdown and marks it stored.
///
/// ⚠️ **THROWS, AND NEVER REPORTS A PARTIAL CHAPTER** — the exception is what stops the
/// loop writing `done`, and a method that swallowed it would produce a `done` row for a
/// chapter that is not on the disk (B6).
abstract interface class ChapterWriter {
  /// `2-3`'s `store()`: write the file atomically, **then** write `downloadedAt`.
  ///
  /// ⚠️ **THE ORDER IS THE CONTRACT, and it is B6/ADR-022.** A crash between the two
  /// steps leaves a file with no mark — the safe direction, because the chapter then
  /// offers itself for download instead of opening as complete. A mark with no file is
  /// unreachable, which is what makes the rule expressible rather than merely true on
  /// the happy path.
  Future<void> writeChapter({
    required String chapterId,
    required String novelId,
    required int ordinal,
    required String markdown,
  });
}
