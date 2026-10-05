// Lumen Tale — the one adapter between the queue's port and `2-3`'s store, and the only
// place a full disk becomes a **typed** cause.
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
// builds the filename from it and **never** from `number`, which is `-1` when unreadable
// and restarts per volume — two chapters, one file, one silently replaced. This adapter
// therefore passes [ordinal] through untouched; the only thing it does with
// `chapterNumber` is not use it.
//
// ## ⚠️ **`5-3` § 7.6: THIS IS THE `catch` THAT JUSTIFIES `StorageFullException`**
//
// `13-error-handling.md` adds a subclass "only when a caller needs to `on X catch` it
// specifically", and the loop needs three things this classification makes possible: stop
// the queue; say *free up some space, then resume* instead of *try again* (C12 requires
// those to be different sentences); and carry a byte figure. Without the subclass the loop
// would have to catch `ChapterStoreException` and inspect a message — which is free text in
// a `switch`, and explicitly forbidden.

import 'dart:convert';
import 'dart:io';

import 'package:lumen_tale/core/error/storage_full_exception.dart';
import 'package:lumen_tale/domain/downloads/chapter_writer.dart';
import 'package:lumen_tale/features/downloads/domain/chapter_store.dart';

/// Delegates to `ChapterStore`, classifies a full disk, and adds nothing else.
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
    try {
      await _store.store(
        chapter: ChapterRecord(
          id: chapterId,
          novelId: novelId,
          ordinal: ordinal,
        ),
        markdown: markdown,
      );
    } on ChapterStoreException catch (failure) {
      // ⚠️ **THE `if` IS **CAUSE**, NOT SEVERITY — AND IT IS AN `errno`, NOT A WORD MATCH.**
      //
      // A `cannotWrite` covers three unrelated things: a missing directory, a read-only
      // volume and `ENOSPC`. Only the last one is *"the phone is out of storage"*, and the
      // OS says which it is in `OSError.errorCode`. Testing `message.contains('space')` is
      // what § 7.6 refuses, and it would also be wrong in the reader's language.
      //
      // When the cause is **not** out of space, the original exception is rethrown untouched
      // and the loop takes `5-3` § 3.2 row 11: the item stays `downloading`, the queue
      // stops, and the screen says something that does not guess.
      if (failure.reason != ChapterStoreFailure.cannotWrite ||
          !_isOutOfSpace(failure.cause)) {
        rethrow;
      }
      throw StorageFullException(
        // ⚠️ **THE CHAPTER'S OWN ENCODODED LENGTH, MEASURED — NOT THE QUEUE'S AND NOT
        // `0`.** It is the one figure this layer can state honestly: what the file it was
        // about to write needs. It is **not** free space, which `downloads.md` § 9 refuses to
        // display at all.
        utf8.encode(markdown).length,
        cause: failure,
      );
    }
  }

  /// ⚠️ **THE TWO `errno`s THAT MEAN "MAKE ROOM", PER PLATFORM, AND WHY THEY ARE WRITTEN
  /// OUT.** `dart:io` exposes `OSError` but no `Errno` enum, so the numbers are literals
  /// with the platform named beside each one:
  ///
  ///  * **Linux / Android** — `ENOSPC` = 28, `EDQUOT` = 122 (a per-user quota, which on a
  ///    phone is how a vendor storage policy presents itself);
  ///  * **Windows** — `ERROR_DISK_FULL` = 112 (never a v1 target; present so the adapter is
  ///    not Linux-only by accident).
  ///
  /// `macOS`'s numbers coincide with Linux's for both codes, which is why there is no third
  /// list.
  static bool _isOutOfSpace(Object? cause) {
    if (cause is! FileSystemException) {
      return false;
    }
    final int? code = cause.osError?.errorCode;
    return code == 28 || code == 122 || code == 112;
  }
}
