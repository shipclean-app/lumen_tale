// Lumen Tale — the contract `sources/implementations` consumes.
//
// `architecture.md` § 2.3, and the signature plan `2-1` § 2.3 already expects.

import 'package:lumen_tale/core/network/http_response.dart';

/// The contract a source uses to reach its site.
///
/// Rule 3 of `03-source-system.md`, in one place. `setUrlWithoutDomain` and
/// `SourceEndpoint.resolve` are the two halves of one contract: one composes, the
/// other decomposes. They live in one file **because two implementations of the
/// same rule would be two answers to "what is the canonical form of a URL?"**.
abstract interface class HttpClient {
  /// `GET` of a **relative** path, resolved against this source's `baseUrl`.
  ///
  /// Never throws for a network failure, a missing connection, a refusal by the
  /// site, or a 429: those four are [FetchResult]s rather than exceptions,
  /// because B22 requires the caller to be able to tell them from a success.
  ///
  /// The only thing it throws is `CancelledException` — a cancellation is not a
  /// failure and must never become `NoConnection` on the screen.
  ///
  /// [query] is joined with `Uri`, never by string concatenation.
  Future<HttpResponse> get(String relativePath, {Map<String, String>? query});

  /// Resolves a relative path against this source's `baseUrl`.
  ///
  /// `03-source-system.md` rule 2: **no trailing slash** on `baseUrl`, and this
  /// is — and nowhere else in the project — where an absolute URL is composed.
  Uri resolve(String relativePath);
}

/// The canonical relative form of a URL this app will store.
///
/// What is stored is a path plus a query, never a full URL. Hosts change, and a
/// stored absolute URL breaks silently.
///
/// This is the only place in the project that turns an absolute URL back into a
/// relative one, because two implementations of the same rule would be two
/// answers to the same question.
String setUrlWithoutDomain(Uri absolute) {
  final relative = absolute.path;
  // An empty path is a real case (`https://host` → the catalogue root) and must
  // become `/` rather than "", or `resolve('')` would concatenate onto the
  // baseUrl without a separator.
  if (relative.isEmpty) return absolute.hasQuery ? '/?${absolute.query}' : '/';
  return absolute.hasQuery ? '$relative?${absolute.query}' : relative;
}
