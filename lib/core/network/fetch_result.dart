// Lumen Tale — the transport discriminant.
//
// ⚠️ THIS FILE BELONGS TO THIS PLAN, NOT TO THE CLASSIFIER.
//
// `http-client` is wave 0 and `failure-discriminator` is wave 2, which declares
// it in `depends_on`. A producer that did not write the type its consumer needs
// would invert the dependency: wave 2 would import a type it had defined itself.
// So **this foundation writes `FetchResult`**, and `failure-discriminator` does
// `import 'package:lumen_tale/core/network/fetch_result.dart';` without
// touching it.
//
// What the type is: the discriminant of the transport. It says what the
// transport did, never what the site answered — `HttpResponse` (§ 2.2) carries
// the response. The two travel together and `FetchResult` never moves alone.
//
// A 4xx or 5xx is **not** a distinct case here: it arrives as `FetchSucceeded`
// with its status, and the classifier decides. Deciding "this is a refusal" at
// the transport would put B22's taxonomy in two places.

sealed class FetchResult {
  const FetchResult();
}

/// A response was received. [status] may be any HTTP status; 2xx is the only
/// range the classifier reads as content.
final class FetchSucceeded extends FetchResult {
  const FetchSucceeded({required this.status});

  final int status;
}

/// No response was received at all. E5.
final class FetchTransportFailed extends FetchResult {
  const FetchTransportFailed({required this.host});

  final String host;
}

/// 429, or any status the shared limiter turned into a backoff.
/// `17-security.md` rule 6: `Retry-After` is honoured.
///
/// ⚠️ **No `host`, and above all no `sourceId`.** A 429 belongs to a HOST, not to
/// a source: two sources can share a `baseUrl`, and one host can serve both. The
/// host is already a key in the limiter's slot table (§ 3.2); carrying it here
/// too would be a second copy of a fact that exists, free to diverge.
/// `architecture.md` § 5.2 says the same in the same terms.
final class FetchRateLimited extends FetchResult {
  const FetchRateLimited({required this.retryAfter, required this.status});

  final Duration retryAfter;
  final int status;
}
