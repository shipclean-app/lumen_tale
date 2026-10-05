// Lumen Tale — everything the classifier is allowed to look at.
//
// ⚠️ Four fields, each documented. A classifier that needed a fifth fact would
// need a fifth field here, and that is the point: **the inputs are enumerable**.
// The alternative is a classifier that reaches for whatever is in scope, and a
// classifier that reaches decides about things it cannot see.

import 'package:lumen_tale/core/network/fetch_result.dart';

/// What was being read when the read failed.
///
/// `source-unavailable.md` § 8 names this field `whatWasBeingRead` and lists four
/// values; `searchResults` is a fifth, required by B50 — a source that declares
/// search and then returns nothing is a broken source, and it needs its own
/// evidence line.
enum ReadStage {
  catalogue,
  genreListing,
  novelDetails,
  chapterList,
  chapterContent,
  searchResults,
}

/// What zero items means for a given stage.
///
/// **Declared by the source that made the request** — B41: the platform never
/// interprets a source's values, and a stage's legitimate zero is a property of
/// the site, not of the app.
enum ZeroItemsPolicy {
  /// The site can legitimately publish nothing here.
  ///
  /// `browse-genre.md` § 4 "Empty — no data" is this case: a tag index read
  /// cleanly and held no tag. A real state, not an error, and not a broken source.
  zeroIsGenuine,

  /// Zero here is a suspected break, never an answer. B22's second arm, E8.
  zeroIsBroken,
}

/// The default policy per stage.
///
/// The source overrides it per call by passing a [ReadAttempt] with its own
/// [ReadAttempt.zeroItemsPolicy]. This table is what a stage gets when a caller
/// forgets, and it is the **conservative** direction on every stage where the two
/// differ — because the costs are asymmetric. Reporting a genuinely empty page as
/// broken costs the reader a list; the reverse tells them a dead site has nothing,
/// which B22 and SC-6 forbid outright.
const Map<ReadStage, ZeroItemsPolicy>
kZeroItemsPolicyByStage = <ReadStage, ZeroItemsPolicy>{
  // The only genuine zero in the default table. `browse-genre.md` § 4
  // specifies it: a source declaring no genres at all is a real state.
  ReadStage.genreListing: ZeroItemsPolicy.zeroIsGenuine,
  // Every remaining stage. B22: the discriminator is the site's own signal,
  // "never the absence of a match" — so with no signal, zero cannot be shown
  // to mean "genuinely nothing" and is reported instead.
  ReadStage.catalogue: ZeroItemsPolicy.zeroIsBroken,
  ReadStage.novelDetails: ZeroItemsPolicy.zeroIsBroken,
  ReadStage.chapterList: ZeroItemsPolicy.zeroIsBroken,
  ReadStage.chapterContent: ZeroItemsPolicy.zeroIsBroken,
  ReadStage.searchResults: ZeroItemsPolicy.zeroIsBroken,
};

/// What the source's own selectors found in the body.
///
/// Produced by a source — `03-source-system.md` rule 12: parsing unit tests ship
/// with fixture HTML — and never by this foundation, which has no selector and
/// must not grow one. A foundation that knew `.chapter-content` would depend on a
/// site, and the manufactured fixture would stop being a generic test.
sealed class ContentProbe {
  const ContentProbe();
}

/// The elements the source expected were present.
///
/// [itemCount] is how many were found. For a single article node the probe
/// reports `1`, because the container *is* the element being looked for.
final class ExpectedContentFound extends ContentProbe {
  const ExpectedContentFound(this.itemCount);

  final int itemCount;
}

/// The body parsed, and none of the expected elements were in it.
///
/// **E4, E8, SC-6.** This is the shape a broken-layout fixture produces: a
/// well-formed page, HTTP 200, non-empty, and nothing the app looks for.
final class ExpectedContentAbsent extends ContentProbe {
  const ExpectedContentAbsent();
}

/// The body could not be turned into elements at all. B22's "a parse error".
final class ParseBroke extends ContentProbe {
  const ParseBroke();
}

/// Everything the classifier is allowed to look at, and nothing else.
final class ReadAttempt {
  const ReadAttempt({
    required this.stage,
    required this.fetch,
    required this.content,
    this.siteEmptySignal,
    this.zeroItemsPolicy,
    this.expectedSelector,
    this.requestPath,
  });

  final ReadStage stage;

  /// What the transport did — **the discriminant, not the response**.
  ///
  /// `http-client` hands the caller an `HttpResponse` whose `.outcome` is this
  /// value and whose `.body` is the page. The classifier is given **only** the
  /// first. A source reads the body itself, probes it with its own selectors, and
  /// puts the verdict in [content].
  ///
  /// ⚠️ This field is a `FetchResult` and not a body on purpose. A `ReadAttempt`
  /// carrying the body would make this foundation a second source of truth about a
  /// site's HTML, and the classifier would start deciding about things it cannot
  /// see.
  final FetchResult fetch;

  /// What the source's selectors found.
  ///
  /// `null` only when the transport produced no body to parse — which does not
  /// happen on a 2xx. It is classified as a parse failure rather than as an
  /// absence, because a `null` here must never degenerate into "no results".
  final ContentProbe? content;

  /// **The site's own explicit empty-result marker, verbatim, or `null`.**
  ///
  /// The single most important field in this file. B22: "The discriminator is the
  /// site's own empty-result signal, never the absence of a match."
  ///
  /// The *source* decides whether a marker is present, because only the source
  /// knows its own site's wording (B41 again). What was measured on Royal Road:
  /// **there is no such marker** — a zero-row catalogue page is an ordinary page,
  /// so on that site `BrowseEmpty` is unreachable at `ReadStage.catalogue` and the
  /// page shape is the only discriminator available.
  final String? siteEmptySignal;

  /// Overrides [kZeroItemsPolicyByStage] for this call. `null` = use the table.
  final ZeroItemsPolicy? zeroItemsPolicy;

  /// The selector the source used, echoed into the failure's evidence so the
  /// owner can read it against the fixture. Required by `SourceLayoutChanged`.
  final String? expectedSelector;

  /// The site-relative request path, for `ParseFailed`.
  ///
  /// Never absolute, and never carrying a reader-supplied query (C5,
  /// `17-security.md` rule 1).
  final String? requestPath;
}
