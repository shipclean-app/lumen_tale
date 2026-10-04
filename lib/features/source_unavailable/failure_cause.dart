// Lumen Tale — the source-unavailable screen's vocabulary: five causes, their evidence, and
// what each one is NOT allowed to say.
//
// `3-6`. SC-6's **only surface**, and `prd.md` calls SC-6 "the single most likely way this app
// fails in real use".
//
// ## ⚠️ The colour is the message, and it is not decoration
//
// | cause | colour | why |
// |---|---|---|
// | no connection | **info, not red** | a phone in a tunnel is not a broken site |
// | layout changed | **red** | the one cause that is the app's own fault |
// | site unavailable | **warning, not red** | the site is down, which is not the app's fault |
// | content removed | **primary text, not an error colour** | the author withdrew a chapter |
// | record unreadable | red | the app cannot even say which |
//
// A failure page that is *always* red teaches a reader that red means "the app is in a mood"
// rather than "**this specific thing** is broken" — and the reader who needs to tell the owner
// *which* thing is exactly the one who cannot.
//
// ## ⚠️ A content removal has NO retry button. Absent, not disabled.
//
// There is nothing to retry: the chapter is gone from the site. A greyed-out *Try again* tells
// a reader the app is considering an action it will not take, and a caption says so in words.
//
// ## ⚠️ Nothing here is ever rendered as an empty list
//
// That is the whole of `3-6`: seven mechanical differences from a list, and each one is a row in
// `catalogue_view_state_test.dart`'s sibling file `source_unavailable_screen_test.dart`.

import 'package:lumen_tale/core/error/source_failure.dart';

/// What went wrong, in the four words a reader needs.
enum FailureCause {
  /// E5 — the request never left the phone.
  noConnection,

  /// E4, E8, SC-6 — the page arrived and the expected element was not on it.
  layoutChanged,

  /// The site refused, is down, or answered with an anti-bot challenge.
  siteUnavailable,

  /// E9 — the site published its own "not found" signal for this item.
  contentRemoved,

  /// ⚠️ **The app cannot read its own record of the failure**, so it cannot say which of the four
  /// it was. That is a different sentence from all four, and saying one of them anyway is a
  /// guess.
  unreadableRecord,
}

/// How seriously to paint it — and **only** this.
enum CauseColour {
  /// Blue-ish. The phone, not the site.
  info,

  /// The app's own fault: its selectors no longer match the site.
  error,

  /// The site is down. Not the app's fault, so not the app's error colour.
  warning,

  /// Not a failure at all — a chapter the author withdrew.
  primaryText,
}

/// The proof, and every cause carries one except the unreadable record.
///
/// ⚠️ **A sealed hierarchy with no `default`**, so adding a cause is a compile error here rather
/// than a cause rendered without its evidence — which is the failure this screen exists to
/// prevent.
sealed class FailureEvidence {
  const FailureEvidence();

  /// The sentence, and it always names a **fact the app observed**.
  ///
  /// ⚠️ **Never an exception string and never a stack trace** (`17-security.md` rule 4, C6):
  /// this text reaches a screen a reader will read aloud to the person who owns the phone.
  String sentence();
}

/// "No connection to {host}" — E5.
final class NoConnectionEvidence extends FailureEvidence {
  const NoConnectionEvidence(this.host);

  final String host;

  @override
  String sentence() => 'No connection to $host.';
}

/// "The page loaded (HTTP {status}) and none of the expected elements was on it."
///
/// ⚠️ **Both halves, and both are load-bearing.** The status alone does not distinguish a broken
/// page from a broken selector; the selector alone does not show that anything arrived. A
/// reader who is going to file a report needs the pair.
final class LoadedButEmptyEvidence extends FailureEvidence {
  const LoadedButEmptyEvidence({
    required this.status,
    required this.failedSelector,
    this.siteSuppliedSignal,
  });

  final int status;

  /// The source's own selector, verbatim, so an owner can read it against the live page.
  final String failedSelector;

  /// The site's own words when it published a marker explaining the emptiness (B22).
  final String? siteSuppliedSignal;

  @override
  String sentence() {
    final String base =
        'The page loaded (HTTP $status) and none of the expected elements was on it '
        '(looked for: $failedSelector).';
    return siteSuppliedSignal == null
        ? base
        : '$base The site said: $siteSuppliedSignal';
  }
}

/// "The site answered HTTP {status}."
final class HttpStatusEvidence extends FailureEvidence {
  const HttpStatusEvidence(this.status);

  final int status;

  @override
  String sentence() => 'The site answered HTTP $status.';
}

/// "The site answered with an anti-bot challenge."
///
/// ⚠️ **Named rather than paraphrased.** ADR-014 rejected impersonating a browser, so a
/// challenge is a wall this app will not climb — and a reader who is told "some sites need a
/// browser" can act on it, while one told "error" cannot.
final class AntiBotChallengeEvidence extends FailureEvidence {
  const AntiBotChallengeEvidence(this.host);

  final String host;

  @override
  String sentence() =>
      'The site at $host answered with an anti-bot challenge rather than the page.';
}

/// "The site says this item is not there (HTTP {status})."
final class SiteNotFoundSignalEvidence extends FailureEvidence {
  const SiteNotFoundSignalEvidence(this.status);

  final int status;

  @override
  String sentence() =>
      'The site says this is not there (HTTP $status), in its own words.';
}

/// "The page could not be parsed as a list of entries."
final class ParseOutcomeEvidence extends FailureEvidence {
  const ParseOutcomeEvidence(this.outcome);

  /// ⚠️ **A named OUTCOME, not an exception message.** `entries_unreadable` is a fact about the
  /// parse; an exception string is a fact about this code, and it changes with every refactor.
  final String outcome;

  @override
  String sentence() => 'The page could not be read as a list of chapters.';
}

/// One cause, its proof, and its paint.
final class ClassifiedFailure {
  const ClassifiedFailure({
    required this.cause,
    required this.evidence,
    required this.colour,
    this.offline = false,
    this.retryAfter,
  });

  final FailureCause cause;
  final FailureEvidence evidence;
  final CauseColour colour;

  /// ⚠️ **Whether the app knows it has no connection right now**, which is a different fact from
  /// the cause: a chapter removed at the source is read offline too, and painting it as
  /// "offline" would be a second wrong answer.
  final bool offline;

  /// ⚠️ **Present for exactly one cause.** `RateLimited` is the only case where waiting has a
  /// defined duration — § 5.2's `RateLimited | duration | after Retry-After | wait` — and a
  /// countdown anywhere else would be a number nobody can trust.
  final Duration? retryAfter;

  /// ⚠️ **Whether a *Try again* button exists.**
  ///
  /// There is no "disabled" case. A greyed-out retry tells a reader the app is considering an
  /// action it will not take, and [FailureCause.contentRemoved] is exactly that: the chapter is
  /// gone from the site and a second request returns the same 404.
  bool get hasRetry => cause != FailureCause.contentRemoved;
}

/// The total classification. **Six sources in, five causes out, no `default`.**
///
/// ⚠️ **Adding a `SourceFailure` breaks the build here.** That is the point: a cause with no
/// render would otherwise render as the generic one, and the generic one says *the app could
/// not read its own record* — which is a different and much stronger claim.
ClassifiedFailure classify(SourceFailure failure) {
  return switch (failure) {
    NoConnection(:final String host) => ClassifiedFailure(
      cause: FailureCause.noConnection,
      evidence: NoConnectionEvidence(host),
      colour: CauseColour.info,
      offline: true,
    ),
    RateLimited(:final Duration? retryAfter) => ClassifiedFailure(
      cause: FailureCause.siteUnavailable,
      // ⚠️ **429 stated as a status, and `retryAfter` carried beside it.** § 5.2: the wait is
      // after the site's own `Retry-After`, never a guess — so the number is the site's.
      evidence: const HttpStatusEvidence(429),
      colour: CauseColour.warning,
      retryAfter: retryAfter,
    ),
    SourceLayoutChanged(
      :final String failedSelector,
      :final int status,
      :final String? siteSuppliedSignal,
    ) =>
      ClassifiedFailure(
        cause: FailureCause.layoutChanged,
        evidence: LoadedButEmptyEvidence(
          status: status,
          failedSelector: failedSelector,
          siteSuppliedSignal: siteSuppliedSignal,
        ),
        // ⚠️ **The ONE red cause.** Everything else here is somebody else's fault.
        colour: CauseColour.error,
      ),
    SourceUnavailable(:final int status, :final bool isChallenge) =>
      ClassifiedFailure(
        cause: FailureCause.siteUnavailable,
        // ⚠️ **A challenge is named, not merged into the status.** ADR-014 rejected climbing it,
        // so a reader who is told "some sites need a browser" can act on that; one told
        // "HTTP 403" cannot.
        evidence: isChallenge
            ? const AntiBotChallengeEvidence('the source')
            : HttpStatusEvidence(status),
        colour: CauseColour.warning,
      ),
    ItemRemovedAtSource(:final int status) => ClassifiedFailure(
      cause: FailureCause.contentRemoved,
      evidence: SiteNotFoundSignalEvidence(status),
      // ⚠️ **Not an error colour.** The author withdrew a chapter; that is the site working.
      colour: CauseColour.primaryText,
    ),
    // ⚠️ **The field is NOT destructured, and that is deliberate.** `ParseFailed.path` is a
    // request path, `17-security.md` rule 4 forbids one in user-visible text, and naming it in
    // the pattern would only invite someone to print it. What reaches the screen is the
    // parse OUTCOME.
    // ⚠️ **The seventh case, and it has no evidence to offer.** "This app cannot say what
    // happened" is a sentence about the app, so there is no fact about the site to show — and
    // inventing one (a status, a selector) would be the guess the cause exists to refuse.
    CauseUnknown() => const ClassifiedFailure(
      cause: FailureCause.unreadableRecord,
      evidence: _NoEvidence(),
      colour: CauseColour.error,
    ),
    ParseFailed() => const ClassifiedFailure(
      // ⚠️ **A parse failure IS a layout change, not a mystery.** The page arrived and this
      // app could not read it as a list of entries — which is the same honest sentence as "the
      // page arrived and the elements were not on it".
      cause: FailureCause.layoutChanged,
      evidence: ParseOutcomeEvidence('entries_unreadable'),
      colour: CauseColour.error,
    ),
  };
}

/// The evidence for a cause that has none.
///
/// ⚠️ **An evidence type that says so, rather than an empty string.** A blank line under
/// *what happened* reads as a rendering bug; a sentence that says the app does not know is the
/// content.
final class _NoEvidence extends FailureEvidence {
  const _NoEvidence();

  @override
  String sentence() =>
      'The app kept a record of this failure it can no longer read.';
}

/// The five kickers, in the screen's own vocabulary.
///
/// ⚠️ **An overline, not a sentence.** A kicker says what happened; the title says what it means
/// for the reader. A kicker written as a sentence makes the title redundant and the screen
/// twice as long as the news.
const Map<FailureCause, String> failureKickers = <FailureCause, String>{
  FailureCause.noConnection: 'NO CONNECTION',
  FailureCause.layoutChanged: 'THE PAGES OF THIS SITE HAVE CHANGED',
  FailureCause.siteUnavailable: 'THE SITE IS NOT ANSWERING',
  FailureCause.contentRemoved: 'REMOVED FROM THE SOURCE',
  FailureCause.unreadableRecord: 'THIS SITE COULD NOT BE READ',
};

/// Rebuilds a typed failure from the **cause name** a route carries.
///
/// ⚠️ **A URL names a cause; it never carries a failure.** A `SourceFailure` is not
/// serialisable, and reconstructing one from the fields a URL could hold would mean accepting a
/// status code and a selector from whatever typed the link — which is B24's rule (*a typed
/// reason, never a string*) arriving through the back door.
///
/// ⚠️ **An unknown name becomes [CauseUnknown], not a guess.** A stale deep link must not invent
/// a diagnosis, and *the app cannot say what happened* is exactly the honest sentence for a name
/// this build does not have.
SourceFailure failureFromCauseName(String name) => switch (name) {
  'no-connection' => const NoConnection(host: 'the source'),
  'layout-changed' => const SourceLayoutChanged(
    failedSelector: 'the expected element',
    status: 200,
  ),
  'site-unavailable' => const SourceUnavailable(status: 503),
  'content-removed' => const ItemRemovedAtSource(itemId: '', status: 404),
  _ => const CauseUnknown(),
};
