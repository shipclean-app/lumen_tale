// Lumen Tale — rule 2 of `03-source-system.md`, applied once and for all.

/// The network endpoint of **one** source: its `baseUrl`.
///
/// `versionId` does not belong to this class and is not read here: it is read by
/// `03-source-system.md` rule 1 to **compute the source's id**. This foundation
/// therefore has no access to `versionId`, and that is correct — if it had one,
/// it could rewrite an identity.
final class SourceEndpoint {
  /// ⚠️ **NOT `const`, and the reason is worth recording.** A `const` constructor would let the
  /// registry's entry list be a literal, which reads better — but the trailing-slash assertion
  /// calls `String.endsWith`, which is not permitted in a constant expression, so `const` here
  /// would mean dropping the assertion. The assertion is the rule that catches the silent
  /// `//novel/x.html` 404; the syntax sugar is not worth it.
  SourceEndpoint({required this.baseUrl})
    : assert(
        !baseUrl.endsWith('/'),
        '03-source-system.md rule 2: baseUrl carries no trailing slash. A '
        'trailing slash produces https://host//novel/x.html, which is a silent '
        '404 on some sites.',
      );

  /// Without a trailing slash. An assertion checks it, not a runtime throw: this
  /// is a programming error, caught before the app ships rather than as a 404
  /// the reader has to diagnose.
  final String baseUrl;

  /// `https://www.fanmtl.com` + `/novel/ke383028.html`.
  ///
  /// The join happens **here**, with `Uri`, never by string interpolation: a site
  /// path is untrusted input (`17-security.md` rule 1), and an interpolation
  /// would let a `//evil.example` through as the path.
  Uri resolve(String relativePath, {Map<String, String>? query}) {
    final base = Uri.parse(baseUrl);
    return base.replace(
      path: '${base.path}$relativePath',
      queryParameters: (query == null || query.isEmpty) ? null : query,
    );
  }

  /// The hostname alone, for the limiter and for `NoConnection.host`.
  ///
  /// `Uri.host` is already the hostname: never `Uri.toString()`, never
  /// `Uri.path`. That is what guarantees no cause can carry a reader's query.
  String get host => Uri.parse(baseUrl).host;
}
