// Lumen Tale — the shared behaviour of a source that fetches over HTTP.
//
// `03-source-system.md`. `source.dart` declares `HttpSource` as an **interface** —
// `baseUrl`, `versionId` — and this file is the mixin that gives it the one thing every
// HTTP source does and no pure source does: a `GET` against its own base URL.
//
// ## Why a mixin and not a base class
//
// `HttpSource` is an abstract **class** in `source.dart`, so a source could extend it.
// It does not, because `Source` is also an abstract class and Dart has no multiple
// inheritance: `class RoyalRoadSource extends HttpSource` would work today and would stop
// working the moment a source needed a second base. A mixin composes, and `lib/domain/`
// stays free of any implementation detail — this file imports `core/network`, which
// `02-architecture.md`'s table permits for `domain/`, and nothing else.
//
// ## It owns no selector and must never grow one
//
// `18-external-contracts.md` records the selectors; `03-source-system.md` rule 12 says
// parsing unit tests ship with fixture HTML. A foundation that knew
// `.fiction-list-item` would depend on a site, and `manufactured/broken-layout.html`
// would stop being a generic test.

import 'package:flutter/foundation.dart' show protected;
import 'package:lumen_tale/core/network/http_client.dart';
import 'package:lumen_tale/core/network/http_response.dart';
import 'package:lumen_tale/core/network/source_endpoint.dart';
import 'package:lumen_tale/domain/sources/source.dart';

/// Transport for a [HttpSource].
mixin HttpFetching on HttpSource {
  /// Injected, never constructed here: a source owns its policy and `core/network` owns
  /// the socket.
  HttpClient get client;

  /// ⚠️ **No trailing slash.** `SourceEndpoint` asserts it rather than throwing at
  /// runtime, because a trailing slash produces `https://host//fictions/x` — a silent
  /// 404 on some hosts and a working URL on others, which is the worst kind of bug.
  SourceEndpoint get endpoint => SourceEndpoint(baseUrl: baseUrl);

  /// The one place an absolute URL is composed in this project.
  Uri absoluteUrlOf(String relativePath) => endpoint.resolve(relativePath);

  /// `GET` of a **relative** path.
  ///
  /// [query] is joined with `Uri`, never by string concatenation: a reader's query is
  /// untrusted input (`17-security.md` rule 1), and an interpolation would let
  /// `//evil.example` through as a path.
  ///
  /// ⚠️ **Never throws** for a network failure, a missing connection, a refusal or a
  /// 429 — those are [HttpResponse] values, because B22 requires the caller to be able
  /// to tell them from a success. The only throw is `CancelledException`, which the
  /// platform owns.
  @protected
  Future<HttpResponse> fetch(
    String relativePath, {
    Map<String, String>? query,
  }) {
    return client.get(relativePath, query: query);
  }
}
