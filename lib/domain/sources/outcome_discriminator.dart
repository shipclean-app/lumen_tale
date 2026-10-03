// Lumen Tale — the one decision that keeps four outcomes apart.
//
// `architecture.md` § 2.2 calls this "the single most load-bearing foundation, and
// the one that cannot be built from a library". Every branch is written out below
// and every branch returns; there is no fall-through and no throw.
//
// ⚠️ **A pure function.** No cache, no clock, no I/O, no field. Two calls for two
// different sites therefore share nothing, which is B23's first clause expressed
// as a property of the code rather than as a promise in a document.

import 'package:lumen_tale/core/error/source_failure.dart';
import 'package:lumen_tale/core/network/fetch_result.dart';
import 'package:lumen_tale/domain/sources/browse_outcome.dart';
import 'package:lumen_tale/domain/sources/read_attempt.dart';

final class OutcomeDiscriminator {
  const OutcomeDiscriminator();

  /// Classifies one read attempt into exactly one of the three states.
  ///
  /// [items] is what the source found. It is **only** used on the success branch;
  /// the classifier never infers items of its own, because it has no selector and
  /// the count it was given is a count and not a list.
  BrowseOutcome<T> classify<T>(
    ReadAttempt attempt, {
    List<T> items = const [],
  }) {
    final policy =
        attempt.zeroItemsPolicy ??
        kZeroItemsPolicyByStage[attempt.stage] ??
        ZeroItemsPolicy.zeroIsBroken;

    // ── ARM 1 — no transport ─────────────────────────────────────────────
    final FetchResult fetch = attempt.fetch;
    if (fetch is FetchTransportFailed) {
      // E5. ⚠️ NOT BrowseSucceeded(items: []): an empty list asserts "the site has
      // nothing" while an exception says "we could not find out". Returning the
      // first when the second happened is the exact defect SC-6 exists to catch.
      return BrowseFailed<T>(NoConnection(host: fetch.host), retriable: true);
    }
    if (fetch is FetchRateLimited) {
      // `17-security.md` rule 6. Retry-After is honoured, never guessed.
      return BrowseFailed<T>(
        RateLimited(retryAfter: fetch.retryAfter),
        retriable: true,
      );
    }

    // From here the transport succeeded. `FetchSucceeded` is the only remaining
    // case because the hierarchy is sealed; anything else would not compile.
    final FetchSucceeded succeeded = fetch as FetchSucceeded;
    final int status = succeeded.status;

    // ── ARM 2 — a status that is not a success ────────────────────────────
    if (status < 200 || status >= 300) {
      // B22: "a non-success status → the site could not be read".
      return BrowseFailed<T>(
        SourceUnavailable(status: status),
        retriable: true,
      );
    }

    // ── ARM 3 — the response succeeded but the body did not survive ───────
    final ContentProbe? content = attempt.content;
    if (content is ParseBroke) {
      // B22: "a parse error → the site could not be read".
      return BrowseFailed<T>(
        ParseFailed(path: attempt.requestPath ?? ''),
        retriable: false,
      );
    }
    if (content == null) {
      // A 2xx with no parseable body. Unreachable in practice, and treated as a
      // read failure rather than as an absence: a `null` here must NEVER
      // degenerate into "no results".
      return BrowseFailed<T>(
        ParseFailed(path: attempt.requestPath ?? ''),
        retriable: false,
      );
    }

    // ── ARM 4 — the body is usable ────────────────────────────────────────
    if (content is ExpectedContentAbsent) {
      // E4 / E8 / SC-6. The page answered 200, parsed, and held none of the
      // expected elements. The site's own signal is KEPT if there was one — it is
      // what explains to the reader why the page reads as empty.
      return BrowseFailed<T>(
        SourceLayoutChanged(
          failedSelector: attempt.expectedSelector ?? _undeclaredSelector,
          status: status,
          siteSuppliedSignal: attempt.siteEmptySignal,
        ),
        retriable: false,
      );
    }

    final ExpectedContentFound found = content as ExpectedContentFound;

    // ── THE ORDER OF THE THREE VERDICTS, and it is fixed ───────────────────
    // 1. The site's signal first. B22 verbatim: "the response parsed successfully
    //    AND carries the site's own explicit empty-result signal → genuine
    //    nothing". Putting this second is the mistake an implementer makes: a site
    //    can carry a "nothing found" marker in a *footer* on a page full of
    //    results, and reading the string's presence as proof of emptiness
    //    produces "no results" on a full page — the mirror image of SC-6.
    if (attempt.siteEmptySignal case final String signal) {
      return BrowseEmpty<T>(siteSuppliedSignal: signal);
    }

    // 2. Then the count. An intact site with entries is a success.
    if (found.itemCount > 0) {
      return BrowseSucceeded<T>(List<T>.unmodifiable(items));
    }

    // 3. And only then, zero.
    if (policy == ZeroItemsPolicy.zeroIsGenuine) {
      // The only way to reach BrowseSucceeded(items: []): the site was read, it is
      // intact, and it has nothing.
      return BrowseSucceeded<T>(List<T>.unmodifiable(const <Never>[]));
    }

    return BrowseFailed<T>(
      SourceLayoutChanged(
        failedSelector: attempt.expectedSelector ?? _undeclaredSelector,
        status: status,
      ),
      retriable: false,
    );
  }

  /// Stands in for a selector the source failed to declare. A visible sentinel
  /// rather than an empty string, because an empty string in an evidence line
  /// reads as "there was no selector" and as "the selector was empty" at once.
  static const String _undeclaredSelector = '(non déclaré)';
}
