// Lumen Tale — `/novel/:novelId`'s providers, and what each one's lifetime says.
//
// `3-2`.
//
// ## ⚠️ `autoDispose` on the list, and it is a MEMORY decision
//
// A novel with ten thousand chapters is ten thousand entries held in memory for as long as
// something watches them. `05-state-management.md` rule 10: a screen's state is released at the
// pop. The registry (`libraryStreamProvider`, `2-5`) is `keepAlive` because it is the app's
// spine; this is one novel, and holding it costs what holding it costs.
//
// ## ⚠️ THE STREAM CANNOT FETCH, AND THE ANSWER IS NOT A PROVIDER
//
// Rule 4: reactive data driven by drift is a stream. The one network call is
// [chapterListLoaderProvider], and it is called from **one tap** — a fetch inside a `build` is
// exactly the speculative background work B5 forbids.
//
// ⚠️ **The site's last answer is held by the SCREEN, in its own `State`.** Not a notifier, and
// not a field on the stream. Two reasons, and the second is the one that matters:
//
// 1. it is true only from the tap until the next tap, which is the lifetime of the screen's own
//    ephemeral state and nothing longer;
// 2. a shared holder would leak a novel's answer onto another novel's screen — two detail screens
//    can be on the stack at once, and "the site said it has no chapters" for a *different* novel
//    is a sentence that would be believed.
//
// So the derivation is a **pure function** ([mapChapterList]) the screen calls with its own
// answer, which also means every row of its test needs no `ProviderScope` at all.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:lumen_tale/core/error/source_failure.dart';
import 'package:lumen_tale/data/library/drift_chapter_list_repository.dart';
import 'package:lumen_tale/domain/library/chapter_entry.dart';
import 'package:lumen_tale/domain/library/chapter_list_repository.dart';
import 'package:lumen_tale/domain/sources/browse_outcome.dart';
import 'package:lumen_tale/features/history/history_providers.dart'
    show appDatabaseProvider;

/// Overridden in the composition root, because it is the database.
final chapterListRepositoryProvider = Provider<ChapterListRepository>(
  (Ref ref) => DriftChapterListRepository(ref.watch(appDatabaseProvider)),
);

/// The stored rows, in the site's order. **`autoDispose`** — see the file doc comment.
final chapterListProvider = StreamProvider.autoDispose
    .family<List<ChapterEntry>, String>((Ref ref, String novelId) {
      return ref.watch(chapterListRepositoryProvider).watchChapters(novelId);
    });

/// B14 — the unread count as SQL computes it, never as the list is walked.
final chapterUnopenedCountProvider = FutureProvider.autoDispose
    .family<int, String>((Ref ref, String novelId) {
      return ref.watch(chapterListRepositoryProvider).countUnopened(novelId);
    });

/// ⚠️ **The loader, and it is a FUNCTION provider so a row can watch what was asked for.**
///
/// It holds no state: B12's precondition is the tap, and the tap is the only caller. A provider
/// that fetched on read would be a fetch nobody asked for, which is the same defect with one
/// more layer in it.
final chapterListLoaderProvider =
    Provider<Future<BrowseOutcome<ChapterListFetchResult>> Function(String)>((
      Ref ref,
    ) {
      return (String novelId) =>
          ref.read(chapterListRepositoryProvider).fetchChapterListOnce(novelId);
    });

/// What the site last said about this novel's chapter list.
///
/// ⚠️ **A value the screen owns, and there is deliberately no provider for it.** See the file
/// doc comment: a shared holder leaks one novel's answer onto another novel's screen.
final class ChapterListSiteAnswer {
  const ChapterListSiteAnswer({this.failure, this.siteSuppliedSignal = ''});

  /// `null` and an empty signal together mean **the site has not been asked**, which is the
  /// only reading of the pair that is not a claim about the site.
  final SourceFailure? failure;
  final String siteSuppliedSignal;

  /// Whether this answer says anything at all.
  bool get saysNothing => failure == null && siteSuppliedSignal.isEmpty;

  /// What the site's answer is, once recorded.
  ///
  /// ⚠️ **A success is `null`, never an empty answer.** A success means the site's rows are now
  /// in the database, and the stored list is the truth; keeping a "and it was fine" marker
  /// beside it would be a second thing to keep in step.
  static ChapterListSiteAnswer? of(
    BrowseOutcome<ChapterListFetchResult> outcome,
  ) {
    return switch (outcome) {
      BrowseFailed(:final SourceFailure reason) => ChapterListSiteAnswer(
        failure: reason,
      ),
      BrowseEmpty(:final String siteSuppliedSignal) => ChapterListSiteAnswer(
        siteSuppliedSignal: siteSuppliedSignal,
      ),
      BrowseSucceeded() => null,
    };
  }
}

/// The unread count from the list itself, for when the SQL count has not arrived.
///
/// ⚠️ **`?? chapters.length` would be wrong, and the difference is visible.** A chapter marked
/// read in a write the stream has not observed yet would make the badge disagree with the tiles
/// under it — and the reader can see both at once.
int countUnreadIn(List<ChapterEntry> chapters) =>
    chapters.where((ChapterEntry chapter) => !chapter.isRead).length;
