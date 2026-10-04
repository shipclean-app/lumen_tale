// Lumen Tale — the one adapter between the queue's port and `2-3`'s store.
//
// ## ⚠️ WHY AN ADAPTER EXISTS AT ALL
//
// `ChapterStore` is `2-3`'s interface and it lives in `features/downloads/domain/`.
// `SerialDownloadQueueRunner` lives in `data/downloads/`, and `02-architecture.md`'s
// dependency table says **`data` must not depend on `features`**.
//
// That table is not decorative, and this file is the honest way round it: the runner
// programs against `domain/downloads/chapter_writer.dart` — a port of three scalars —
// and *this* file, which lives inside `features/downloads/` and may therefore import
// both `domain/` and its own feature's domain, is the single place the two meet.
//
// `data/downloads/drift_chapter_action_repository.dart` has the opposite edge, from
// `3-3`. That is `3-3`'s debt to close, not a precedent, and duplicating it here would
// have meant a second `data` → `features` crossing for a file whose only job is to not
// exist.
//
// ## ⚠️ **ONE FIELD, THREE SCALARS, NO RE-INTERPRETATION**
//
// `ChapterRecord` is id, novel and ordinal. The ordinal is the one that matters: `2-3`
// builds the filename from it and **never** from `number`, which is `-1` when
// unreadable and restarts per volume — two chapters, one file, one silently replaced.
// This adapter therefore passes [ordinal] through untouched; the only thing it does
// with `chapterNumber` is not use it.

import 'package:lumen_tale/domain/downloads/chapter_writer.dart';
import 'package:lumen_tale/features/downloads/domain/chapter_store.dart';

/// Delegates to `ChapterStore`, and adds nothing.
///
/// ⚠️ **THE EXCEPTION IS NOT CAUGHT.** `2-3` raises `ChapterStoreException` when the
/// filesystem refused, and B6 says the queue must learn about it: the loop leaves the
/// item `downloading`, writes no `done`, and lets the failure reach `5-3`, which is the
/// slice that classifies `storage_full`. An adapter that swallowed it would produce a
/// `done` row for a chapter that is not on the disk.
final class StoredChapterWriter implements ChapterWriter {
  const StoredChapterWriter(this._store);

  final ChapterStore _store;

  @override
  Future<void> writeChapter({
    required String chapterId,
    required String novelId,
    required int ordinal,
    required String markdown,
  }) async {
    await _store.store(
      chapter: ChapterRecord(id: chapterId, novelId: novelId, ordinal: ordinal),
      markdown: markdown,
    );
  }
}
