// Lumen Tale — `/novel/:novelId`'s nine chapter-list states.
//
// `3-2` § 2.2. SC-6 again, at a smaller scale: `novel-details.md` § 4 splits three of the nine
// into three consequences each, and every one of those splits is a distinction B22 demands.
//
// | the site / the disk said | the reader is shown | why it is not another state |
// |---|---|---|
// | the list is stored | the list, at the first frame | C14: zero network on every open after the first |
// | **nothing stored, nothing asked** | *Load the chapter list* — **not** an empty list | B12: a deferred entry is not an empty one |
// | **nothing stored, no connection** | *No connection* — **not** an error | E5: nothing failed; a precondition is missing |
// | **nothing stored, and the site said it has none** | *The site publishes no chapters* | B22: the only place "empty" is a real answer |
// | **the site could not be read** | the failure's own sentence | E4 / E8: never "0 chapters" |
// | the local copy could not be read | *this app cannot read its own copy* | a third cause needs a third sentence |
// | the download was refused for space | *free space, then retry* | E20: no tile shows progress, because none is queued |
// | a read mark names a chapter that is gone | *the app's records disagree* | B13 / B14: an invariant a reader must be able to see |
//
// ## ⚠️ `ChapterListNeverLoaded` and `ChapterListEmptyAtSource` are NOT the same screen
//
// The first is a *precondition*: nothing was asked, so nothing is missing. The second is an
// *answer*: the site said, in its own words, that it has none. Rendering them alike teaches a
// reader that "not loaded" means "nothing there", which is the one inference B12 exists to stop.

import 'package:lumen_tale/core/error/source_failure.dart';
import 'package:lumen_tale/domain/library/chapter_entry.dart';

/// The chapter list's state, as a type.
sealed class ChapterListViewState {
  const ChapterListViewState();

  /// Whether this screen offers the reader something to do about the list.
  ///
  /// ⚠️ **A getter on the sealed hierarchy, not a `switch` at each call site.** "Can I load
  /// this?" is asked by the pinned action row and by the tail marker, and two answers to one
  /// question is how a screen grows a button the state does not support.
  bool get canLoad => false;
}

/// The list is stored and is streaming in. **A skeleton, not a spinner.**
final class ChapterListLoading extends ChapterListViewState {
  const ChapterListLoading();
}

/// The list is here. **Zero network on every open after the first** (C14).
final class ChapterListFilled extends ChapterListViewState {
  const ChapterListFilled({
    required this.chapters,
    required this.unopenedCount,
    this.currentChapterId,
  });

  final List<ChapterEntry> chapters;

  /// B14 — derived from [chapters], never a second query and never a column.
  final int unopenedCount;

  /// `null` → no `current` tile is drawn **and *Go to current chapter* is not rendered at
  /// all** — not rendered empty (B16). A button that navigates nowhere is a button that lies.
  final String? currentChapterId;

  bool get hasCurrent => currentChapterId != null;

  @override
  bool get canLoad => true;
}

/// B12 / B5 — the novel is reachable **without** its chapters having been asked for.
final class ChapterListNeverLoaded extends ChapterListViewState {
  const ChapterListNeverLoaded();

  @override
  bool get canLoad => true;
}

/// B22 — the site answered **and carries its own empty-result signal**. The only real "empty".
final class ChapterListEmptyAtSource extends ChapterListViewState {
  const ChapterListEmptyAtSource({
    required this.sourceName,
    this.siteSuppliedSignal = '',
  });

  final String sourceName;

  /// The site's own words, kept verbatim when it published any.
  final String siteSuppliedSignal;

  @override
  bool get canLoad => true;
}

/// B22 / E4 / E8 — **the site could not be read.** Never rendered as "0 chapters".
final class ChapterListSiteUnreadable extends ChapterListViewState {
  const ChapterListSiteUnreadable({
    required this.sourceName,
    required this.failure,
  });

  final String sourceName;
  final SourceFailure failure;

  /// ⚠️ **A second attempt is worth making only when the cause says so.**
  bool get canRetry => failure.isRetriable;

  @override
  bool get canLoad => true;
}

/// E5 — the list was never requested and there is no connection.
///
/// ⚠️ **NOT an error, and NOT `ChapterListSiteUnreadable`.** Nothing failed: a precondition is
/// missing. Telling a reader a site could not be read when the app never asked it sends them to
/// look for a site problem they are not having.
final class ChapterListNotLoadedNoConnection extends ChapterListViewState {
  const ChapterListNotLoadedNoConnection();

  /// ⚠️ **No load is offered.** Offering *Load* with no connection offers a tap that will fail
  /// for the same reason it just did.
  @override
  bool get canLoad => false;
}

/// B22 — **the local copy** could not be read. A third cause, so a third sentence.
final class ChapterListStoredUnreadable extends ChapterListViewState {
  const ChapterListStoredUnreadable();

  /// ⚠️ **No load is offered.** Loading from the site would *replace* the stored copy with a
  /// second truth, and this state exists precisely because the first one could not be read.
  @override
  bool get canLoad => false;
}

/// E20 — the download was refused for storage.
///
/// ⚠️ **`requiredBytes` is shown, because "not enough space" without a size is an excuse.**
final class ChapterListDownloadRefusedForSpace extends ChapterListViewState {
  const ChapterListDownloadRefusedForSpace({required this.requiredBytes});

  final int requiredBytes;

  @override
  bool get canLoad => true;
}

/// B13 / B14 — a read mark names a chapter that is not in the list.
///
/// ⚠️ **An invariant a reader can SEE, not a silent repair.** Deleting the mark would make the
/// app tidy and the reader's unread count wrong again tomorrow; saying so is the only version
/// that does not quietly change the answer.
final class ChapterListMarkedReadFailed extends ChapterListViewState {
  const ChapterListMarkedReadFailed({required this.missingChapterId});

  final String missingChapterId;

  @override
  bool get canLoad => true;
}

/// What the screen is reading, before any state is chosen.
enum ChapterListSource {
  /// The stored rows, and their counts. **The whole of the screen in steady state.**
  stored,

  /// One explicit read of the site, after a tap.
  fromSite,
}

/// The TOTAL mapping from the stored stream plus a site answer to a view state.
///
/// ⚠️ **`ChapterListNeverLoaded` is the default and it is not an error.** Three of the nine
/// states are preconditions rather than failures, so the "nothing to show" answer is a state the
/// reader can act on — *Load the chapter list* — and never a blank list.
ChapterListViewState mapChapterList({
  required List<ChapterEntry> chapters,
  required int unopenedCount,
  required ChapterListSource source,
  String? currentChapterId,
  String sourceName = 'the source',
  SourceFailure? siteFailure,
  String siteSuppliedSignal = '',
  bool hasConnection = true,
}) {
  // ⚠️ **THE ORDER IS THE RULE.** A failure outranks a list, a stored list outranks "never
  // loaded", and "never loaded" outranks everything else. Written as an explicit ladder rather
  // than a `switch` on an outcome because three of the nine states are decided by conditions a
  // switch cannot see.
  if (source == ChapterListSource.fromSite && siteFailure != null) {
    return ChapterListSiteUnreadable(
      sourceName: sourceName,
      failure: siteFailure,
    );
  }
  if (source == ChapterListSource.fromSite && chapters.isEmpty) {
    // ⚠️ **A success carrying no chapters is only "empty" because the site said so.** The
    // discriminator already decided that — a `BrowseSucceeded` with zero entries would have been
    // classified as a failure and arrived here as `siteFailure`. So this arm is reachable only
    // with a marker, and reaching it without one is not expressible.
    return ChapterListEmptyAtSource(
      sourceName: sourceName,
      siteSuppliedSignal: siteSuppliedSignal,
    );
  }
  if (chapters.isNotEmpty) {
    return ChapterListFilled(
      chapters: chapters,
      unopenedCount: unopenedCount,
      currentChapterId: currentChapterId,
    );
  }
  if (!hasConnection) {
    // ⚠️ **Before "never loaded", and that ordering is the point.** "You have no connection and
    // have not asked" and "you have not asked" are different sentences, and a reader who is in a
    // tunnel needs the first one to know why the tap did nothing.
    // ⚠️ **`const`, and its OWN class.** Not `ChapterListSiteUnreadable` — nothing failed, and
    // naming a site as unreadable when the app never asked it sends the reader looking for a
    // site problem they are not having.
    return const ChapterListNotLoadedNoConnection();
  }
  return const ChapterListNeverLoaded();
}
