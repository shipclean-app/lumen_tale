// Lumen Tale — the catalogue screen's view states, and the TOTAL mapping from `BrowseOutcome`.
//
// ## Why this file exists rather than a `switch` inside the screen
//
// B22 is SC-6, and SC-6 is "a site that cannot be read looks like a site with nothing in
// it". The defence against that is **exhaustiveness the compiler enforces**, so the mapping
// lives in a sealed hierarchy whose cases cannot be added without this file changing — and the
// screen's `switch` over it has no `default`.
//
// | the site said | the reader is shown |
// |---|---|
// | a page with novels | the list |
// | a page with none, **page 1** | "this tag has no novels", and the reason |
// | a page with none, **page 2 or later** | **the site could not be read** |
// | its own "nothing here" marker | "nothing here", quoting the site |
// | a typed failure | the failure's own sentence, never "0 results" |
//
// ⚠️ **The third row is the one that carries SC-6.** "No results" is never said of page 2 of
// a tag that had thirty on page 1: that would erase half the list in front of a reader
// scrolling. An empty page past the first is the exact signature of a layout change.

import 'package:lumen_tale/core/error/source_failure.dart';
import 'package:lumen_tale/domain/library/library_entry.dart';
import 'package:lumen_tale/domain/sources/browse_outcome.dart';
import 'package:lumen_tale/domain/sources/models/novel.dart';
import 'package:lumen_tale/domain/sources/models/novels_page.dart';

/// What the catalogue screen shows, as a **type**.
sealed class CatalogueViewState {
  const CatalogueViewState();
}

/// The list, with the site's own order and no sort applied by this app.
///
/// ⚠️ **`page` and `hasMore` are carried, not recomputed.** `hasMore` is the SITE's pagination
/// signal, and its absence with a full page means "no more" — the app never invents the end
/// of a list it has not reached.
final class CatalogueFilled extends CatalogueViewState {
  const CatalogueFilled({
    required this.items,
    required this.page,
    required this.hasMore,
    this.appended = false,
    this.inLibraryIds = const <String>{},
  });

  final List<Novel> items;
  final int page;
  final bool hasMore;

  /// ⚠️ **A flag, not a second list.** One controller, one list: appending means the tail
  /// changed, and a screen holding two lists would have to decide which one to draw.
  final bool appended;

  /// B11 — which of these the reader already keeps, so a tile can say so instead of offering
  /// an add that would be a no-op.
  final Set<String> inLibraryIds;

  bool isKept(Novel novel) => inLibraryIds.contains(novel.id);

  CatalogueFilled withLibrary(Set<String> ids) => CatalogueFilled(
    items: items,
    page: page,
    hasMore: hasMore,
    appended: appended,
    inLibraryIds: ids,
  );
}

/// The tag has no novels, **and that is a fact about the tag**.
final class CatalogueEmptyTag extends CatalogueViewState {
  const CatalogueEmptyTag({required this.sourceName, required this.tag});

  final String sourceName;

  /// What the reader asked for, so the sentence can name it back.
  final String tag;
}

/// The site published its **own** "nothing here" marker.
///
/// ⚠️ **Separate from [CatalogueEmptyTag] on purpose.** "This tag is empty" and "the site told
/// us it has nothing for this search" are different claims, and only the second one quotes a
/// string the site itself chose to print.
final class CatalogueSiteSaidNothing extends CatalogueViewState {
  const CatalogueSiteSaidNothing({
    required this.sourceName,
    this.siteSuppliedSignal,
  });

  final String sourceName;

  /// The site's own words, shown verbatim — never translated, never paraphrased, because a
  /// reader comparing what they searched for with what came back needs the site's own claim.
  final String? siteSuppliedSignal;
}

/// The site could not be read, and the reader is told so.
///
/// ⚠️ **Never renders "0 results", never renders a list footer, and never renders a retry as
/// though the list were merely incomplete.** `browse-catalogue.md` § 4: *zéro ligne de roman
/// n'est rendue, et la page ne défile pas*.
final class CatalogueSourceUnreadable extends CatalogueViewState {
  const CatalogueSourceUnreadable({
    required this.sourceName,
    required this.tag,
    required this.failure,
  });

  final String sourceName;
  final String tag;

  /// Typed, never a string (B24) — the sentence comes from the enum's own copy, so it cannot
  /// drift from the branch that produced it.
  final SourceFailure failure;

  /// Whether offering *Retry* is honest. A layout change is not retriable: the page will
  /// answer 200 with the same markup tomorrow.
  bool get canRetry => failure.isRetriable;
}

/// No connection, **and the repository could not tell whether the site is fine**.
///
/// ⚠️ **Distinct from [CatalogueSourceUnreadable].** "The site is broken" and "we could not
/// ask the site" are different facts, and collapsing them is how a reader ends up blaming a
/// site for their own tunnel.
final class CatalogueNoConnection extends CatalogueViewState {
  const CatalogueNoConnection({required this.sourceName});

  final String sourceName;
}

/// The library's own entries, so a catalogue tile can say "kept" without a second query.
typedef LibraryIds = Set<String>;

/// The total mapping. **`[outcome]` never produces an empty-list state from a failure.**
///
/// ⚠️ **`page.page <= 1` is the whole of the "empty page" rule**, and it is here rather than in
/// the controller so that no caller can reach a list-shaped state from a failure.
/// ⚠️ **[requestedPage] is a PARAMETER and not read from [outcome], and that is forced by the
/// type.** `NovelsPage` carries `novels` and `hasNextPage` — the site publishes a *list*, not
/// a page number, so its index lives in the request that produced it and nowhere else.
///
/// Reading it from the response would mean inventing it, and inventing "which page am I on"
/// is how a caller ends up treating page 2's emptiness as a tag with nothing in it.
///
/// ⚠️ **[hasMore] is a parameter for the same reason.** `BrowseSucceeded` hands over the list
/// and nothing else, so the site's own pagination signal travels beside the outcome rather than
/// inside it — and a caller that cannot see it cannot guess it, which is the correct default
/// (the app never invents the end of a list it has not reached).
CatalogueViewState mapBrowseOutcome({
  required BrowseOutcome<NovelsPage> outcome,
  required String sourceName,
  required String tag,
  required int requestedPage,
  bool? hasMore,
  LibraryIds inLibraryIds = const <String>{},
}) {
  // ⚠️ **`BrowseOutcome<NovelsPage>` carries `List<NovelsPage>` — a list holding one page.**
  //
  // That is `2-1`'s shape and it is validated by 26 fixture rows, so this slice reads it rather
  // than re-declaring a second generic. The consequence is explicit here: a catalogue read
  // yields **one** page, and a `BrowseSucceeded` whose `items` is itself empty has already been
  // classified as broken by `OutcomeDiscriminator` (`zeroIsBroken` for the catalogue stage), so
  // it cannot reach this function as an empty list.
  return switch (outcome) {
    BrowseSucceeded(items: final List<NovelsPage> pages) => _mapPage(
      pages,
      sourceName,
      tag,
      requestedPage,
      hasMore,
      inLibraryIds,
    ),
    BrowseEmpty(:final String? siteSuppliedSignal) => CatalogueSiteSaidNothing(
      sourceName: sourceName,
      siteSuppliedSignal: siteSuppliedSignal,
    ),
    BrowseFailed(:final SourceFailure reason) => CatalogueSourceUnreadable(
      sourceName: sourceName,
      tag: tag,
      failure: reason,
    ),
  };
}

/// The one page a catalogue read produced.
CatalogueViewState _mapPage(
  List<NovelsPage> pages,
  String sourceName,
  String tag,
  int requestedPage,
  bool? hasMore,
  LibraryIds inLibraryIds,
) {
  if (pages.isEmpty) {
    // ⚠️ **Unreachable by a well-behaved source, and it maps to BROKEN rather than to
    // empty.** If a source ever does hand over zero pages, the honest reading is "we could not
    // read a page", and "this tag has no novels" is a claim about the site this app has no
    // evidence for.
    return CatalogueSourceUnreadable(
      sourceName: sourceName,
      tag: tag,
      failure: const SourceLayoutChanged(
        failedSelector: 'catalogue page',
        status: 200,
      ),
    );
  }
  final NovelsPage page = pages.single;
  if (page.novels.isEmpty) {
    // ⚠️ **An empty page past the first is a LAYOUT CHANGE, not an empty tag.** "No results" is
    // never said of page 2 of a tag that had thirty on page 1 — that would erase half the list
    // in front of a reader who is scrolling.
    //
    // ⚠️ **The selector is named, so the owner can go and look.** `SourceLayoutChanged` exists
    // to be actionable, and a detail string with no selector in it is a sentence nobody can
    // act on.
    return requestedPage > 1
        ? CatalogueSourceUnreadable(
            sourceName: sourceName,
            tag: tag,
            failure: const SourceLayoutChanged(
              failedSelector: 'catalogue rows',
              status: 200,
            ),
          )
        : CatalogueEmptyTag(sourceName: sourceName, tag: tag);
  }
  return CatalogueFilled(
    items: page.novels,
    page: requestedPage,
    // ⚠️ **`hasMore` is the SITE's signal and the app never invents one.** A caller that did not
    // pass it gets `false`, which renders no footer — the conservative direction, because an
    // invented "load more" offers a page that does not exist.
    hasMore: page.hasNextPage && (hasMore ?? true),
    inLibraryIds: inLibraryIds,
  );
}

/// ⚠️ **The error branch is here, and it is NOT a list state.**
///
/// `AsyncValue.guard` turns a throw into `AsyncError`, so a caller that forgets to inspect
/// the error would draw an empty list — the exact confusion B22 exists to prevent. This
/// function is the only way from an `AsyncError` to a view state, and it cannot return one
/// that draws a list.
CatalogueViewState mapAsyncError({
  required String sourceName,
  required String tag,
  required Object error,
}) {
  // ⚠️ **`CatalogueNoConnection` and NEVER `CatalogueEmptyTag`.** The default of "no
  // connection" is a guess; the alternative guess is "this tag has no novels", and that one
  // erases a working feature in the reader's head.
  return CatalogueNoConnection(sourceName: sourceName);
}

/// The library ids as a set, for [CatalogueFilled.inLibraryIds].
LibraryIds libraryIdsOf(List<LibraryEntry> entries) => <String>{
  for (final LibraryEntry entry in entries)
    if (entry.inLibrary) entry.id,
};
