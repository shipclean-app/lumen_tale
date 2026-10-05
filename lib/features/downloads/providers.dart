// Lumen Tale — `3-3`'s wiring, in the feature that owns the store.
//
// ## ⚠️ WHY THE PROVIDER IS HERE AND NOT IN `data/`
//
// `DriftChapterActionRepository` lives in `data/downloads/`, and the obvious thing is to
// declare its provider beside it. That does not compile against this project's boundary
// rule: the repository's constructor takes a **`ChapterStore`**, and `FileChapterStore`
// implements it from **`features/downloads/data/`** — and `data/` may import a feature's
// `domain/`, never its `data/`. So a provider in `data/` would need the concrete store and
// could not have it.
//
// Putting the provider in the feature that owns the store is the arrangement the architecture
// already uses, and it is why **the tile takes its actions as parameters** rather than
// importing this provider: `features/novel_details` must not import `features/downloads`
// either. The tile is handed callbacks; the composition root supplies them.
//
// ## ⚠️ ONE STORE, ONE MARKER, ONE ORDER
//
// `5-1`'s queue and `3-3`'s tile must write `downloadedAt` through **the same** marker. Two
// markers would mean two writers, and B6's order — the mark strictly after the atomic rename
// — would then depend on which one ran last.

import 'dart:io';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lumen_tale/core/database/app_database.dart';
import 'package:lumen_tale/core/database/app_database_provider.dart';
import 'package:lumen_tale/data/downloads/drift_chapter_action_repository.dart';
import 'package:lumen_tale/domain/downloads/chapter_action_repository.dart';
import 'package:lumen_tale/features/downloads/data/file_chapter_store.dart';
import 'package:lumen_tale/features/downloads/domain/chapter_store.dart';

/// The drift marker: the one writer of `chapters.downloadedAt`.
///
/// ⚠️ **CLEARING IS THE SAME CLOSURE WITH `null`.** `CallbackChapterMarker` already takes
/// one closure for both, and this supplies it, so "mark" and "clear" cannot drift into two
/// SQL statements that disagree about which columns they touch.
final Provider<ChapterMarker> chapterMarkerProvider = Provider<ChapterMarker>((
  Ref ref,
) {
  final AppDatabase db = ref.watch(appDatabaseProvider);
  return CallbackChapterMarker(
    onMark: (ChapterRecord chapter, DateTime? downloadedAt) async {
      await (db.update(
        db.chapters,
      )..where(($ChaptersTable t) => t.id.equals(chapter.id))).write(
        ChaptersCompanion(downloadedAt: Value<DateTime?>(downloadedAt)),
      );
    },
    onClear: (ChapterRecord chapter) async {
      // B33 — never deletes the row; `onMark(…, null)` is the same statement.
    },
  );
});

/// The one store, shared by the queue and the tile.
final Provider<ChapterStore> chapterStoreProvider = Provider<ChapterStore>(
  (Ref ref) => FileChapterStore(marker: ref.watch(chapterMarkerProvider)),
);

/// ⚠️ **`5-2`'s CANCELLATION PORT, AND IT IS A SEPARATE PROVIDER ON PURPOSE.**
///
/// `PartialChapterDiscarder` is its own one-method interface (`chapter_store.dart` says
/// why), so this provider is typed on **it** rather than on `ChapterStore`. Reading
/// `ChapterStore` and casting would put the cast at the one call site that matters, and the
/// compiler would no longer be able to tell that `cancel()` really needs the second method.
///
/// Two providers over one `FileChapterStore` is fine and intentional: each is read through
/// the capability its caller uses, and `chapterStoreProvider` is not rebuilt by this.
final Provider<PartialChapterDiscarder> chapterPartialDiscarderProvider =
    Provider<PartialChapterDiscarder>(
      (Ref ref) => FileChapterStore(marker: ref.watch(chapterMarkerProvider)),
    );

/// ⚠️ **THE PROBE WRITES WHERE DOWNLOADS GO.** It is the **support** directory's parent, not
/// `systemTemp`: measuring a different filesystem than the one chapters land on would make
/// E20's two numbers describe two different volumes, and the refusal would be arithmetic on
/// the wrong pair.
final Provider<Directory?> spaceProbeDirectoryProvider = Provider<Directory?>(
  (Ref ref) => null,
);

/// `3-3`'s repository — typed on the **interface**, so a widget row can hand the tile a stub
/// without building a database.
final Provider<ChapterActionRepository> chapterActionRepositoryProvider =
    Provider<ChapterActionRepository>(
      (Ref ref) => DriftChapterActionRepository(
        database: ref.watch(appDatabaseProvider),
        store: ref.watch(chapterStoreProvider),
        probeDirectory: ref.watch(spaceProbeDirectoryProvider),
      ),
    );
