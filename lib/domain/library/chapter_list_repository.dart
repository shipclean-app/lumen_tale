// Lumen Tale — the chapter list's reads, and **nothing else**.
//
// `3-2` § 2.2.
//
// ## ⚠️ NO WRITE METHOD, and that is the load-bearing part of the interface
//
// Not `markRead`, not `setDownloaded`, not `deleteChapter`. A repository that writes what a
// screen displays produces two sources of truth for the same fact, and the second one drifts.
// The product's three writes are owned elsewhere and this screen calls their interactors:
//
// | the write | its owner |
// |---|---|
// | membership (`addFromCatalogue`) | `2-5` |
// | the download mark | `3-3` (the interactor `2-3` already wrote to) |
// | the reading position | `2-6` |
//
// ## ⚠️ `watchChapters` has NO page parameter, and that is B9
//
// A paginated list is a deferred entry, and B9 forbids an entry being deferred, truncated, or
// replaced by a *show more*. A `Stream` that re-emits when a chapter is opened is
// **reactivity**, not pagination, and it is why this is `watch` *and* takes no page: there is
// no page to ask for.
//
// ## ⚠️ `fetchChapterListOnce` is the ONLY network path, and B12 is its precondition
//
// The list is never requested implicitly. The novel is reachable without its chapters — a
// restored navigation stack, a deep link, a notification — and in each of those the reader has
// not asked for a list of up to ten thousand rows, so nothing is stored and nothing is asked
// for. The method is called from one tap and from nowhere else. **Never from `build`.**

import 'package:lumen_tale/domain/library/chapter_entry.dart';
import 'package:lumen_tale/domain/sources/browse_outcome.dart';

/// The chapter list, read-only.
abstract interface class ChapterListRepository {
  /// ⚠️ **ONE emission stream per novel, and never a page.** See the class doc comment.
  Stream<List<ChapterEntry>> watchChapters(String novelId);

  /// B14 / B48 — a SQL aggregate, never a client-side sum and **never a column**.
  ///
  /// `architecture.md` § 4.7: a stored count is a second source of truth free to contradict the
  /// rows it counts.
  Future<int> countUnopened(String novelId);

  Future<int> countAll(String novelId);

  /// B12 — the sole network path, and it is called only after an explicit tap.
  Future<BrowseOutcome<ChapterListFetchResult>> fetchChapterListOnce(
    String novelId,
  );
}
