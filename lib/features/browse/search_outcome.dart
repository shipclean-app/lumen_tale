// Lumen Tale — what a search did, as a type. `6-2`, B50, E19, E8.
//
// ## ⚠️ There is NO path from a silent empty page to "no results"
//
// This file's whole reason to exist. Four outcomes, and one of them is a **throw**:
//
// | the site said | the screen shows | why |
// |---|---|---|
// | rows | the list | the normal case |
// | **its own** "nothing here" marker | `SearchNothing` — silent, centred, **no icon, no colour, no retry** | E19: this is the only one that is a **result** |
// | a typed failure | `SearchUnusable` — an error state, with *Check again* | B50: a source that declares search and returns nothing usable is a **broken source** |
// | **`BrowseSucceeded` with zero rows** | **THROWS** | E8: a silent empty page cannot become "no results". A throw is a **source defect**, not a screen state, and rendering it would be lying |
//
// ⚠️ **That last row is the load-bearing one.** `BrowseEmpty` is reachable **only** where the
// site supplied its own marker — Royal Road's three frozen search captures prove both directions:
// a query that must match returns 20 rows, and a query that must NOT match returns the marker.
// A search that finds nothing and says nothing is therefore `SearchUnusable`, never
// `SearchNothing`, and there is **no code path** that could say otherwise.
//
// ## ⚠️ The field NEVER turns red
//
// `browse-catalogue.md` § 4: the query was well-formed and accepted; what failed is the site's
// answer. Marking the input as errored tells the reader they typed something wrong, which is
// the one thing that is not true.

import 'package:lumen_tale/core/error/source_failure.dart';
import 'package:lumen_tale/domain/sources/browse_outcome.dart';
import 'package:lumen_tale/domain/sources/models/filter.dart';
import 'package:lumen_tale/domain/sources/models/novels_page.dart';

/// Thrown when a source returns `BrowseSucceeded` with no rows and no marker of its own.
///
/// ⚠️ **A source defect, not a screen state.** `SearchUnusable` would show the reader a
/// "something went wrong" sentence, which is *also* wrong — nothing went wrong that the reader
/// can see. So this raises, and a test or a development build says so plainly.
final class SilentEmptySearchPage implements Exception {
  const SilentEmptySearchPage(this.words);

  /// The words as the reader typed them, for a developer-facing message.
  ///
  /// ⚠️ **Never shown to a reader and never logged.** A query is the reader's own words
  /// (`17-security.md` rule 4), and this exception is the kind that ends up in a crash report.
  final String words;

  @override
  String toString() =>
      'SilentEmptySearchPage: the source returned 200 with zero rows and no empty marker. '
      'E8 says this cannot be rendered as "no results".';
}

/// The three renders, as a sealed type.
sealed class SearchOutcome {
  const SearchOutcome();
}

/// The site answered with novels.
final class SearchResults extends SearchOutcome {
  const SearchResults({
    required this.page,
    required this.hasMore,
    required this.words,
  });

  final NovelsPage page;

  /// ⚠️ **The site's own signal, carried through unchanged.** A search paginates by repeating
  /// the same words with the site's offset — which is a **pagination**, not an unbounded
  /// auto-loading scroll (`15-performance.md` § Lists).
  final bool hasMore;

  /// ⚠️ **The words the READER typed, byte for byte.** See [searchQueryFor].
  final String words;
}

/// The site published its **own** "nothing here" marker — the only "no results" there is.
final class SearchNothing extends SearchOutcome {
  const SearchNothing({required this.words, this.siteSuppliedSignal});

  final String words;

  /// The site's own words, shown **verbatim**. A paraphrase is a translation, and the value of
  /// this state is that the SITE said it.
  final String? siteSuppliedSignal;
}

/// The source declared search and returned something unusable. **Not a result.**
final class SearchUnusable extends SearchOutcome {
  const SearchUnusable({required this.words, required this.failure});

  final String words;
  final SourceFailure failure;

  /// A second attempt is worth making, because the cause says so.
  bool get canRetry => failure.isRetriable;
}

/// The URL a search reads, and **the words are not interpreted**.
///
/// ## ⚠️ What is deliberately NOT done to [words] (B41)
///
/// ```text
/// ✗ words.trim()            — "mother  of" is what the reader typed, and trimming it
///                             answers a question they did not ask
/// ✗ words.toLowerCase()     — the site may be case-sensitive, and this app does not know
/// ✗ words.split(' ')        — B41 forbids splitting a query into fields
/// ✗ adding the genre to the scope
/// ✗ composing a relevance query
/// ```
///
/// The words are the reader's, and the app's only job is to carry them to the site.
///
/// ## ⚠️ **Encoding is `Uri`'s, not a hand-built `%20`.**
///
/// A query with an ampersand, a `#` or a `+` in it must arrive as one parameter. String
/// concatenation puts a `&title=a&b` in a URL and the site reads `a`, which is a silently
/// wrong search rather than an error.
Uri searchQueryFor({
  required String sourceId,
  required String words,
  int page = 1,
}) {
  return Uri(
    path: '/browse/$sourceId/genre/search',
    queryParameters: <String, String>{
      'q': words,
      if (page > 1) 'page': '$page',
    },
  );
}

/// The outcome of a search read, and the one case that RAISES.
///
/// ⚠️ **`BrowseSucceeded` with no rows and no marker throws.** E8, and it is the whole point of
/// this function: a silent empty page cannot be rendered as "no results", and it cannot be
/// rendered as an error either — nothing the reader can see went wrong. So it is a defect, named.
SearchOutcome classifySearch({
  required BrowseOutcome<NovelsPage> outcome,
  required String words,
}) {
  return switch (outcome) {
    BrowseSucceeded(items: final List<NovelsPage> pages) => _fromPages(
      pages,
      words,
    ),
    // ⚠️ **`BrowseEmpty` is reachable only because the SITE supplied a marker**, which is why
    // this arm is the only source of `SearchNothing` and why a silence cannot become one.
    BrowseEmpty(:final String? siteSuppliedSignal) => SearchNothing(
      words: words,
      siteSuppliedSignal: siteSuppliedSignal,
    ),
    BrowseFailed(:final SourceFailure reason) => SearchUnusable(
      words: words,
      failure: reason,
    ),
  };
}

SearchOutcome _fromPages(List<NovelsPage> pages, String words) {
  if (pages.isEmpty) {
    throw SilentEmptySearchPage(words);
  }
  final NovelsPage page = pages.single;
  if (page.novels.isEmpty) {
    // ⚠️ **Same rule as the catalogue, and for the same reason.** The site published a page and
    // it held nothing, with no marker — which is what a changed layout looks like from here.
    // "No results" would be an answer the site never gave.
    throw SilentEmptySearchPage(words);
  }
  return SearchResults(page: page, hasMore: page.hasNextPage, words: words);
}

/// The filter list a search sends, which is **always empty**.
///
/// ⚠️ **`FilterList` is a parameter of `searchNovels` and this is its only value.** B41: the
/// platform never interprets a source's filter states and the values belong to the site — so
/// inventing filters here would be the app deciding what the reader meant.
/// ⚠️ **A getter, not a `const`.** `FilterList` is a `ListBase` wrapper whose constructor
/// wraps its input in an unmodifiable list, and that is a runtime call — so a `const` here
/// would not compile, and caching it in a `final` would share one mutable-looking object
/// across every search. It is cheap enough to build per call.
FilterList get kNoSearchFilters => FilterList(const <Filter<Object?>>[]);
