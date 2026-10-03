// Lumen Tale — the dio-backed transport.
//
// The heart of this foundation is § 3.4: every `DioExceptionType` in dio 5.11.1
// is mapped one by one, with no "and a few others". dio has exactly nine
// members — connectionTimeout, sendTimeout, receiveTimeout, transformTimeout,
// badCertificate, badResponse, cancel, connectionError, unknown — and the
// compiler performs the tenth check: adding a member to the enum breaks this
// switch at compile time.
//
// There is deliberately **no `default:`**. A default would make the file tolerant
// of an inventory error, which is precisely the defect an exhaustive mapping
// exists to catch.
//
// There is also no retry interceptor, no cookie jar, and no certificate
// callback. § 3.6 says why the absence of a retry is a decision.

import 'dart:io' show HttpHeaders;

import 'package:dio/dio.dart';

import 'package:lumen_tale/core/error/app_exception.dart';
import 'package:lumen_tale/core/network/body_decoder.dart';
import 'package:lumen_tale/core/network/fetch_result.dart';
import 'package:lumen_tale/core/network/host_rate_limiter.dart';
import 'package:lumen_tale/core/network/http_client.dart';
import 'package:lumen_tale/core/network/http_policy.dart';
import 'package:lumen_tale/core/network/http_response.dart';
import 'package:lumen_tale/core/network/retry_after.dart';
import 'package:lumen_tale/core/network/source_endpoint.dart';

/// Builds a client for one source.
///
/// [rateLimiter] is a parameter and not a global: the limiter holds per-host
/// state, so two clients must not share one (B23, § 3.2).
SourceHttpClient buildHttpClient(
  SourceEndpoint endpoint,
  HostRateLimiter rateLimiter, {
  required String appVersion,
  Dio? dio,
}) {
  assert(
    !endpoint.baseUrl.endsWith('/'),
    '03-source-system.md rule 2: baseUrl carries no trailing slash.',
  );

  final client = dio ?? Dio();
  final agent = userAgent(appVersion);
  client.options = BaseOptions(
    baseUrl: endpoint.baseUrl,
    connectTimeout: HttpTimeouts.connect,
    sendTimeout: HttpTimeouts.send,
    receiveTimeout: HttpTimeouts.receive,

    // ── The User-Agent is a HEADER, not an option ──────────────────────────
    // dio 5.11.1's `BaseOptions` has no `userAgent` field (verified in
    // `options.dart`), so it goes in `headers` — and that has a consequence
    // checked below, because a request-level `headers` REPLACES these.
    headers: <String, Object?>{HttpHeaders.userAgentHeader: agent},

    // ── A 4xx/5xx is a RESPONSE, not a dio exception ─────────────────────
    validateStatus: (status) => status != null && status >= 200 && status < 300,
    // This choice is what makes § 3.4 possible. Without it dio swallows the body
    // of a 429 and only surfaces `DioExceptionType.badResponse` with no usable
    // payload. With it, every non-2xx reaches the mapper WITH its body, which is
    // what reading `Retry-After` requires and what separates a 404 "not found"
    // from a refusal page.

    // ── TLS only (17-security.md rule 7). Nothing is configured here, and that
    // is the point: no badCertificateCallback, no validation disabled. A test
    // greps this file and fails if the word appears.
    followRedirects: true,
    maxRedirects: 5,
  );

  // `httpClientAdapter` is deliberately left untouched: no webview, no proxy, no
  // `_certificate`, no trust-all.

  client.interceptors.add(
    QueuedInterceptorsWrapper(
      onRequest: (options, handler) async {
        // ── C7: the one and only entrance to the network ───────────────────
        await rateLimiter.acquire(endpoint.host);
        handler.next(options);
      },
    ),
  );

  return SourceHttpClient(client, endpoint, rateLimiter);
}

/// `17-security.md` rule 5 / `architecture.md` § 5.3: `LumenTale/VERSION
/// (personal reader)`.
///
/// Never `Mozilla/5.0`, never `Chrome/`, never `Safari/`. ADR-014: impersonation
/// is measured, and it produces a 403 exactly where honesty produces a 200.
///
/// ⚠️ The version arrives as a PARAMETER and not by a second read of
/// `String.fromEnvironment`. `3-5` reads `kBuildName` in
/// `lib/core/app/app_version.dart`; if this foundation read the same
/// `--dart-define`, there would be two readers of one compile-time constant in
/// two directories, and http-client (wave 0) would depend on a file written by
/// 3-5 (wave 1). A parameter removes the ordering constraint.
String userAgent(String appVersion) =>
    'LumenTale/${appVersion.isEmpty ? 'unknown' : appVersion} (personal reader)';

/// The dio-backed implementation of [HttpClient].
final class SourceHttpClient implements HttpClient {
  SourceHttpClient(this._dio, this._endpoint, this._rateLimiter);

  final Dio _dio;
  final SourceEndpoint _endpoint;
  final HostRateLimiter _rateLimiter;

  /// The underlying client, so a test can inspect what was configured — the
  /// User-Agent, the timeouts, `validateStatus`, the absence of a cookie jar.
  ///
  /// Nothing outside a test should reach through this: a source has the
  /// [HttpClient] contract and no business configuring dio.
  Dio get dio => _dio;

  @override
  Uri resolve(String relativePath) => _endpoint.resolve(relativePath);

  @override
  Future<HttpResponse> get(
    String relativePath, {
    Map<String, String>? query,
  }) async {
    // ── before anything else: URL resolution, which cannot fail ────────────
    final uri = _endpoint.resolve(relativePath, query: query);

    try {
      final response = await _dio.get<List<int>>(
        uri.toString(),
        options: Options(
          responseType: ResponseType.bytes, // decoding is ours (§ 3.5)
          // ⚠️ dio 5.11.1 `Options.compose` does `headers: headers ??
          // effectiveHeaders` — a non-null request-level map REPLACES the base
          // headers outright, it does not merge. Passing only
          // `Accept-Encoding` here would silently drop the User-Agent, and a
          // dropped User-Agent is a 403 on exactly the sites ADR-014 measured.
          // So the base headers are merged forward explicitly.
          headers: <String, Object?>{
            ..._dio.options.headers,
            HttpHeaders.acceptEncodingHeader: 'gzip',
          },
        ),
      );

      // ── branch 1: the response arrived ─────────────────────────────────
      final status = response.statusCode ?? 0;
      final contentType = _contentTypeOf(response);
      return HttpResponse(
        outcome: FetchSucceeded(status: status),
        status: status,
        body: decodeBody(
          asBytes(response.data ?? const <int>[]),
          contentType: contentType,
          limit: HttpPolicy.maxBodyBytes,
        ),
        contentType: contentType,
      );
    } on DioException catch (e) {
      return _mapDioException(e);
    } on AppException catch (e) {
      // Already typed — decodeBody's oversize refusal arrives here. It is a
      // transport failure by § 3.4, and it must not be re-wrapped in a second
      // NetworkException that loses the reason.
      return _transportFailure(_endpoint.host, e);
    } on Object catch (e) {
      // A decoder, a transformer, or something in the platform stack. Rule 1 of
      // `13-error-handling.md`: nothing raw crosses this boundary.
      return _transportFailure(_endpoint.host, e);
    }
  }

  /// The exhaustive mapping, reachable without a live socket.
  ///
  /// Present so § 3.4's nine arms can be tested directly rather than through a
  /// server that would have to produce nine different failures on demand.
  /// Production code has no reason to call it: [get] is the entry point.
  HttpResponse mapDioExceptionForTest(DioException exception) =>
      _mapDioException(exception);

  /// The exhaustive mapping. One arm per `DioExceptionType`, no `default`.
  HttpResponse _mapDioException(DioException e) {
    final host = _endpoint.host;

    switch (e.type) {
      // 1 ── the site never answered the connection handshake. E5: "no
      // connection" is a CAUSE, not an empty page.
      case DioExceptionType.connectionTimeout:
        return _transportFailure(host, e);

      // 2 ── same class, same screen, same action: the phone has no usable
      // connection. Merging 1 and 2 would be correct; writing them separately
      // says why the mapping is exhaustive.
      case DioExceptionType.sendTimeout:
        return _transportFailure(host, e);

      // 3 ── the connection opened and nothing came back in time. SAME outcome
      // as 1 and 2: the screen cannot tell those three apart, so it must not
      // pretend to.
      case DioExceptionType.receiveTimeout:
        return _transportFailure(host, e);

      // 4 ── the response arrived but could not be transformed. The transport
      // cannot know whether that is a delay or a broken decoder, so it says the
      // only true thing: no usable content came back.
      case DioExceptionType.transformTimeout:
        return _transportFailure(host, e);

      // 5 ── 17-security.md rule 7: TLS only. An invalid certificate is NOT a
      // network failure and must never be replayed, bypassed, or "fixed" with a
      // badCertificateCallback.
      //
      // ⚠️ The cause does NOT become a "source unavailable": a rejected
      // certificate is a problem with this device, and C12 requires the screen to
      // say so in words.
      case DioExceptionType.badCertificate:
        return _transportFailure(
          host,
          NetworkException('TLS certificate rejected', cause: e, host: host),
        );

      // 6 ── the only arm that can carry a status, and only BECAUSE
      // validateStatus rejects every non-2xx (§ 3.1).
      case DioExceptionType.badResponse:
        final response = e.response;
        final status = response?.statusCode ?? 0;
        final retryAfterHeader = _headerOf(response, 'retry-after');

        // 6a. 429, or any status carrying a Retry-After → C7 / rule 6.
        if (status == 429 || retryAfterHeader != null) {
          final wait = parseRetryAfter(retryAfterHeader, now: DateTime.now());
          _rateLimiter.block(host, until: DateTime.now().add(wait));
          return HttpResponse(
            outcome: FetchRateLimited(retryAfter: wait, status: status),
            status: status,
            body: _bodyOf(response),
            contentType: _contentTypeOf(response),
          );
        }

        // 6b. Any other non-2xx → this is NOT a transport error.
        // `failure-discriminator` § 2.2 said it: a 4xx or 5xx arrives as
        // FetchSucceeded with its status and the classifier decides. The client
        // does NOT decide whether a 404 is a withdrawn novel or a 503 is a busy
        // site.
        return HttpResponse(
          outcome: FetchSucceeded(status: status),
          status: status,
          body: _bodyOf(response),
          contentType: _contentTypeOf(response),
        );

      // 7 ── 13-error-handling.md rule 7. ⚠️ The ONLY arm that propagates: it
      // produces no FetchResult. A cancellation turned into
      // FetchTransportFailed would show "no connection" to a reader who just
      // pressed cancel, which is the worst of the three possible answers.
      case DioExceptionType.cancel:
        throw CancelledException(cause: e);

      // 8 ── socket, DNS, device network. E5, word for word.
      case DioExceptionType.connectionError:
        return _transportFailure(host, e);

      // 9 ── the only case dio cannot name. Treated as a transport failure —
      // NOT as a success and NOT as an empty page — carrying its cause so the
      // owner can read it.
      case DioExceptionType.unknown:
        return _transportFailure(host, e);
    }
  }

  HttpResponse _transportFailure(String host, Object cause) => HttpResponse(
    outcome: FetchTransportFailed(host: host),
    status: 0,
    // Empty, because nothing was decoded: an empty body presented as a read
    // body would be the mirror defect of E8.
    body: '',
    contentType: null,
  );
}

String? _contentTypeOf(Response<dynamic>? response) {
  final value = response?.headers.value('content-type');
  return value == null || value.isEmpty ? null : value;
}

String? _headerOf(Response<dynamic>? response, String name) {
  final value = response?.headers.value(name);
  return value == null || value.isEmpty ? null : value;
}

/// The body of a `badResponse`, decoded defensively.
///
/// A refusal page is still bytes that need decoding, and a decoding failure here
/// must not replace the status — the status is the fact the caller needs. An
/// unreadable body therefore yields `''` while the status survives intact.
String _bodyOf(Response<dynamic>? response) {
  final data = response?.data;
  if (data == null) return '';
  if (data is String) return data;
  if (data is List<int>) {
    try {
      return decodeBody(
        asBytes(data),
        contentType: _contentTypeOf(response),
        limit: HttpPolicy.maxBodyBytes,
      );
    } on AppException {
      return '';
    }
  }
  return '';
}
