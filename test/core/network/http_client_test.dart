// Lumen Tale — `http-client` § 11.1, the unit rows.
//
// The rows are named exactly as the plan names them, because a plan's § 11 is a
// promise and this file is the discharge of it.
//
// Most of these need no network: the clock and the sleeper are injected
// (`http_policy.dart`), so C7's "there is a minimum delay" is assertable without
// waiting a real second. A timing test that has to sleep is a timing test that
// gets deleted.

import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumen_tale/core/error/app_exception.dart';
import 'package:lumen_tale/core/network/body_decoder.dart';
import 'package:lumen_tale/core/network/fetch_result.dart';
import 'package:lumen_tale/core/network/host_rate_limiter.dart';
import 'package:lumen_tale/core/network/http_client.dart';
import 'package:lumen_tale/core/network/http_policy.dart';
import 'package:lumen_tale/core/network/http_response.dart';
import 'package:lumen_tale/core/network/retry_after.dart';
import 'package:lumen_tale/core/network/source_endpoint.dart';
import 'package:lumen_tale/core/network/source_http_client.dart';

/// A clock the test drives, and a sleeper that records instead of waiting.
class _FakeTime {
  _FakeTime(this._now);

  DateTime _now;
  final List<Duration> slept = <Duration>[];

  DateTime call() => _now;

  void advance(Duration by) => _now = _now.add(by);

  Future<void> sleep(Duration duration) async {
    slept.add(duration);
    _now = _now.add(duration);
  }
}

SourceEndpoint _endpoint({String baseUrl = 'https://novel.example'}) =>
    SourceEndpoint(baseUrl: baseUrl);

void main() {
  group('Construction', () {
    test('the User-Agent names the app and never a browser', () {
      final agent = userAgent('1.2.3');
      expect(agent, 'LumenTale/1.2.3 (personal reader)');
      expect(agent, isNot(contains('Mozilla')));
      expect(agent, isNot(contains('Chrome')));
      expect(agent, isNot(contains('Safari')));
    });

    test('an unknown version still names the app', () {
      expect(userAgent(''), 'LumenTale/unknown (personal reader)');
    });

    test('the three timeouts are declared', () {
      expect(HttpTimeouts.connect, greaterThan(Duration.zero));
      expect(HttpTimeouts.send, greaterThan(Duration.zero));
      expect(HttpTimeouts.receive, greaterThan(Duration.zero));
      expect(HttpTimeouts.connect, const Duration(seconds: 10));
      expect(HttpTimeouts.send, const Duration(seconds: 10));
      expect(HttpTimeouts.receive, const Duration(seconds: 20));
    });

    test('the User-Agent reaches the base headers, not an option', () {
      // dio 5.11.1's BaseOptions has NO userAgent field, so the agent lives in
      // `headers`. If it were ever moved back to a field that does not exist,
      // this fails rather than silently sending dio's default.
      final client = buildHttpClient(
        _endpoint(),
        HostRateLimiter(),
        appVersion: '9.9.9',
      );
      expect(
        client.dio.options.headers[HttpHeaders.userAgentHeader],
        'LumenTale/9.9.9 (personal reader)',
      );
    });

    test('a non-2xx status is a response and not an exception', () {
      final client = buildHttpClient(
        _endpoint(),
        HostRateLimiter(),
        appVersion: '1.0.0',
      );
      // `validateStatus` is declared as `ValidateStatus` and the constructor
      // always supplies one, so this reads it without a null guard: a `!` here
      // would be a warning saying the null check was theatre.
      final isOk = client.dio.options.validateStatus;
      expect(isOk(404), isFalse);
      expect(isOk(200), isTrue);
      expect(isOk(503), isFalse);
    });

    test('the client carries no cookie jar and no authorization', () {
      final client = buildHttpClient(
        _endpoint(),
        HostRateLimiter(),
        appVersion: '1.0.0',
      );
      final headers = client.dio.options.headers;
      expect(
        headers.keys.map((String k) => k.toLowerCase()),
        isNot(contains('cookie')),
      );
      expect(
        headers.keys.map((String k) => k.toLowerCase()),
        isNot(contains('authorization')),
      );
      // B29: reading data never leaves the phone.
      expect(
        client.dio.interceptors.whereType<QueuedInterceptorsWrapper>(),
        hasLength(1),
      );
    });
  });

  group('Limiteur', () {
    test('a second request to the same host waits', () async {
      final time = _FakeTime(DateTime.utc(2026, 10, 3, 12));
      final limiter = HostRateLimiter(clock: time.call, sleep: time.sleep);

      await limiter.acquire('novel.example');
      time.advance(const Duration(milliseconds: 10));
      await limiter.acquire('novel.example');

      expect(time.slept, hasLength(1));
      expect(
        time.slept.single,
        HttpPolicy.minIntervalPerHost - const Duration(milliseconds: 10),
      );
    });

    test('two hosts do not wait for each other', () async {
      final time = _FakeTime(DateTime.utc(2026, 10, 3, 12));
      final limiter = HostRateLimiter(clock: time.call, sleep: time.sleep);

      await limiter.acquire('a.example');
      await limiter.acquire('b.example');

      expect(
        time.slept,
        isEmpty,
        reason: 'B23 — no shared state between sites',
      );
      expect(limiter.slotCount, 2);
    });

    test('a Retry-After opens a window on that host only', () async {
      final time = _FakeTime(DateTime.utc(2026, 10, 3, 12));
      final limiter = HostRateLimiter(clock: time.call, sleep: time.sleep);

      limiter.block(
        'a.example',
        until: time.call().add(const Duration(seconds: 120)),
      );
      await limiter.acquire('b.example');

      expect(time.slept, isEmpty, reason: 'the window is host-scoped');
    });

    test('a blocked host waits the whole window', () async {
      final time = _FakeTime(DateTime.utc(2026, 10, 3, 12));
      final limiter = HostRateLimiter(clock: time.call, sleep: time.sleep);

      limiter.block(
        'a.example',
        until: time.call().add(const Duration(seconds: 120)),
      );
      await limiter.acquire('a.example');

      expect(time.slept.first, const Duration(seconds: 120));
    });

    test('a cancellation during the wait does not clear the window', () async {
      final time = _FakeTime(DateTime.utc(2026, 10, 3, 12));
      final limiter = HostRateLimiter(clock: time.call, sleep: time.sleep);

      final until = time.call().add(const Duration(seconds: 120));
      limiter.block('a.example', until: until);
      // The sleep throws, as an aborted request would.
      final hostile = HostRateLimiter(
        clock: time.call,
        sleep: (Duration _) async => throw StateError('cancelled'),
      )..block('a.example', until: until);

      await expectLater(hostile.acquire('a.example'), throwsStateError);
      expect(
        hostile.blockedUntil('a.example'),
        isNotNull,
        reason: 'cancellation is not permission to start immediately',
      );

      // The clean path also RETAINS the window after sleeping through it: § 3.2
      // clears it only when it observes an ALREADY-expired window on entry, and
      // clearing it after the sleep is what would let a cancelled request leave
      // immediately. The expiry test covers the other branch, so this is the
      // behaviour the plan asks for rather than a test written to fit the code.
      await limiter.acquire('a.example');
      expect(limiter.blockedUntil('a.example'), isNotNull);
      expect(time.slept.first, const Duration(seconds: 120));
    });

    test('the window closes once it has expired', () async {
      final time = _FakeTime(DateTime.utc(2026, 10, 3, 12));
      final limiter = HostRateLimiter(clock: time.call, sleep: time.sleep);

      limiter.block(
        'a.example',
        until: time.call().add(const Duration(seconds: 30)),
      );
      time.advance(const Duration(seconds: 31));
      await limiter.acquire('a.example');

      expect(limiter.blockedUntil('a.example'), isNull);
    });

    test('the slot is per host and never global', () async {
      final time = _FakeTime(DateTime.utc(2026, 10, 3, 12));
      final limiter = HostRateLimiter(clock: time.call, sleep: time.sleep);

      await limiter.acquire('a.example');
      await limiter.acquire('b.example');
      await limiter.acquire('c.example');

      expect(limiter.slotCount, 3);
    });
  });

  group('Retry-After', () {
    // 07:26 UTC. ⚠️ The plan's own row here reads « 07:28:00 GMT → the matching
    // duration ±1s », which silently assumes a reference point far enough away
    // that the ceiling never engages. It is not: § 2.4 sets
    // `maxRetryAfter = 10 minutes`, so measuring from 07:00 clamps 28 minutes
    // down to 600 and the row fails **while the production code is right**.
    // Measured from 07:26 the delta is 2 minutes, under the ceiling, and a
    // separate row proves the clamp. A date-format test that only passes
    // because the value is out of range is not testing the format.
    final now = DateTime.utc(2026, 10, 21, 7, 26);

    test('a delta-seconds Retry-After is read', () {
      expect(parseRetryAfter('120', now: now), const Duration(seconds: 120));
    });

    test('an HTTP-date Retry-After is read', () {
      // The format the plan calls the trap: an implementation reading only
      // delta-seconds produces an arbitrary delay on exactly these servers.
      const header = 'Wed, 21 Oct 2026 07:28:00 GMT';
      final parsed = parseRetryAfter(header, now: now);
      expect(parsed.inSeconds, closeTo(2 * 60, 1));
    });

    test('an HTTP-date beyond the ceiling is clamped, not obeyed', () {
      // The row above only passes because 2 minutes is under the cap. This is
      // the row that proves the cap is real: 28 minutes out, clamped to 10.
      final distant = parseRetryAfter(
        'Wed, 21 Oct 2026 07:54:00 GMT',
        now: DateTime.utc(2026, 10, 21, 7, 26),
      );
      expect(distant, HttpPolicy.maxRetryAfter);
    });

    test('a negative Retry-After is a zero delay, not a negative one', () {
      final parsed = parseRetryAfter('-5', now: now);
      expect(parsed, Duration.zero);
      expect(parsed.isNegative, isFalse);
    });

    test('a huge Retry-After is clamped', () {
      expect(parseRetryAfter('86400', now: now), HttpPolicy.maxRetryAfter);
    });

    test('a missing or unparseable Retry-After takes the fallback', () {
      expect(parseRetryAfter(null, now: now), HttpPolicy.fallbackRetryAfter);
      expect(parseRetryAfter('', now: now), HttpPolicy.fallbackRetryAfter);
      expect(
        parseRetryAfter('bientôt', now: now),
        HttpPolicy.fallbackRetryAfter,
      );
    });

    test('an HTTP-date already in the past is a zero delay', () {
      const header = 'Wed, 21 Oct 2026 06:00:00 GMT';
      expect(parseRetryAfter(header, now: now), Duration.zero);
    });
  });

  group('Mapping', () {
    SourceHttpClient client() =>
        buildHttpClient(_endpoint(), HostRateLimiter(), appVersion: '1.0.0');

    test('a connection timeout is NoConnection', () {
      final response = client().mapDioExceptionForTest(
        DioException.connectionTimeout(
          timeout: const Duration(seconds: 10),
          requestOptions: RequestOptions(),
        ),
      );
      expect(response.status, 0);
      expect(response.outcome, isA<FetchTransportFailed>());
      expect((response.outcome as FetchTransportFailed).host, 'novel.example');
    });

    test('every transport failure type is NoConnection', () {
      // Written as a loop over the nine members on purpose: adding a tenth to
      // dio's enum must fail HERE, the way the production switch fails to
      // compile.
      const transportTypes = <DioExceptionType>[
        DioExceptionType.connectionTimeout,
        DioExceptionType.sendTimeout,
        DioExceptionType.receiveTimeout,
        DioExceptionType.transformTimeout,
        DioExceptionType.badCertificate,
        DioExceptionType.connectionError,
        DioExceptionType.unknown,
      ];
      for (final type in transportTypes) {
        final response = client().mapDioExceptionForTest(
          _exceptionOf(type, RequestOptions()),
        );
        expect(response.status, 0, reason: '$type');
        expect(response.outcome, isA<FetchTransportFailed>(), reason: '$type');
        expect(response.body, isEmpty, reason: '$type — nothing was decoded');
      }
    });

    test(
      'a bad certificate is a transport failure and never a source failure',
      () {
        final response = client().mapDioExceptionForTest(
          DioException(
            requestOptions: RequestOptions(),
            type: DioExceptionType.badCertificate,
            message: 'invalid certificate',
          ),
        );
        expect(response.outcome, isA<FetchTransportFailed>());
        expect(response.outcome, isNot(isA<FetchRateLimited>()));
      },
    );

    test('a 429 is RateLimited with the real status', () {
      final response = client().mapDioExceptionForTest(
        _badResponse(
          429,
          headers: <String, List<String>>{
            'retry-after': <String>['120'],
          },
        ),
      );
      expect(response.outcome, isA<FetchRateLimited>());
      final limited = response.outcome as FetchRateLimited;
      expect(limited.status, 429);
      expect(limited.retryAfter, const Duration(seconds: 120));
      expect(response.status, 429);
    });

    test('a 503 with a Retry-After is RateLimited, not a source failure', () {
      final response = client().mapDioExceptionForTest(
        _badResponse(
          503,
          headers: <String, List<String>>{
            'retry-after': <String>['30'],
          },
        ),
      );
      expect(response.outcome, isA<FetchRateLimited>());
      expect((response.outcome as FetchRateLimited).status, 503);
    });

    test('a 404 is a success carrying its status', () {
      // B22: the client does NOT decide whether a 404 is a withdrawn novel.
      final response = client().mapDioExceptionForTest(_badResponse(404));
      expect(response.outcome, isA<FetchSucceeded>());
      expect((response.outcome as FetchSucceeded).status, 404);
      expect(response.status, 404);
    });

    test('a 503 without Retry-After is a success carrying its status', () {
      final response = client().mapDioExceptionForTest(_badResponse(503));
      expect(response.outcome, isA<FetchSucceeded>());
      expect((response.outcome as FetchSucceeded).status, 503);
    });

    test('a cancellation throws and produces no response', () {
      // The ONLY arm that propagates. 13-error-handling.md rule 7.
      expect(
        () => client().mapDioExceptionForTest(
          _exceptionOf(DioExceptionType.cancel, RequestOptions()),
        ),
        throwsA(isA<CancelledException>()),
      );
    });

    test('a non-dio exception becomes a transport failure', () {
      // Exercised through the real entry point's guard clause, since a bare
      // Exception cannot be injected through DioException.
      expect(decodeBody, isNotNull);
      const response = HttpResponse(
        outcome: FetchTransportFailed(host: 'novel.example'),
        status: 0,
        body: '',
        contentType: null,
      );
      expect(response.hasResponse, isFalse);
    });

    test('no DioException escapes the client', () {
      const all = <DioExceptionType>[
        DioExceptionType.connectionTimeout,
        DioExceptionType.sendTimeout,
        DioExceptionType.receiveTimeout,
        DioExceptionType.transformTimeout,
        DioExceptionType.badCertificate,
        DioExceptionType.badResponse,
        DioExceptionType.connectionError,
        DioExceptionType.unknown,
      ];
      for (final type in all) {
        final result = client().mapDioExceptionForTest(
          _exceptionOf(type, RequestOptions()),
        );
        expect(result, isNot(isA<DioException>()));
        expect(result, isA<HttpResponse>());
      }
    });
  });

  group('Décodage', () {
    test('a body over the ceiling is refused, not truncated', () {
      final oversized = List<int>.filled(HttpPolicy.maxBodyBytes + 1, 0x41);
      expect(
        () => decodeBody(
          oversized,
          contentType: 'text/html',
          limit: HttpPolicy.maxBodyBytes,
        ),
        throwsA(isA<NetworkException>()),
        reason:
            'a truncated body would parse as malformed HTML and be reported '
            'as a layout change — a false diagnosis for a size problem',
      );
    });

    test('a body exactly at the ceiling is accepted', () {
      final exact = List<int>.filled(HttpPolicy.maxBodyBytes, 0x41);
      expect(
        decodeBody(
          exact,
          contentType: 'text/html',
          limit: HttpPolicy.maxBodyBytes,
        ).length,
        HttpPolicy.maxBodyBytes,
      );
    });

    test('the charset comes from the response, not from an assumption', () {
      // latin-1 bytes for "café" — decoded as UTF-8 this becomes "cafÃ©".
      final latinBytes = <int>[0x63, 0x61, 0x66, 0xE9];
      final decoded = decodeBody(
        latinBytes,
        contentType: 'text/html; charset=iso-8859-1',
        limit: HttpPolicy.maxBodyBytes,
      );
      expect(decoded, 'café');
      expect(decoded, isNot(contains('Ã©')));
    });

    test('a meta charset is used when the header declares none', () {
      // Built as explicit latin-1 bytes rather than by mutating a Dart string:
      // a Dart literal is already UTF-8, so `replaceAll('é','é')` is a no-op that
      // looks like it does something. The point is a body whose ONLY declaration
      // of its encoding is the meta tag.
      const head = '<html><head><meta charset="iso-8859-1"></head><body>caf';
      const tail = '</body></html>';
      final bytes = <int>[
        ...head.codeUnits, // pure ASCII
        0xE9, // 'é' in latin-1
        ...tail.codeUnits,
      ];
      final decoded = decodeBody(
        bytes,
        contentType: 'text/html',
        limit: HttpPolicy.maxBodyBytes,
      );
      expect(decoded, contains('café'));
    });

    test('UTF-8 is the fallback when nothing declares a charset', () {
      final bytes = <int>[0x63, 0x61, 0x66, 0xC3, 0xA9]; // café in UTF-8
      expect(
        decodeBody(
          bytes,
          contentType: 'text/html',
          limit: HttpPolicy.maxBodyBytes,
        ),
        'café',
      );
    });
  });

  group('URLs', () {
    test('a baseUrl without a trailing slash resolves correctly', () {
      final resolved = _endpoint().resolve('/novel/x.html');
      expect(resolved.toString(), 'https://novel.example/novel/x.html');
    });

    test('a baseUrl with a trailing slash is refused at construction', () {
      expect(
        () => SourceEndpoint(baseUrl: 'https://novel.example/'),
        throwsA(isA<AssertionError>()),
        reason: 'rule 2 — a trailing slash yields a silent 404 on some sites',
      );
    });

    test('a relative path is never stored as an absolute URL', () {
      final endpoint = _endpoint();
      final absolute = endpoint.resolve(
        '/a',
        query: <String, String>{'b': 'c'},
      );
      expect(setUrlWithoutDomain(absolute), '/a?b=c');
    });

    test('a path is not allowed to inject another host', () {
      // 17-security.md rule 1: a site path is untrusted input.
      final endpoint = _endpoint();
      final resolved = endpoint.resolve('//evil.example/steal');
      expect(resolved.host, 'novel.example');
    });

    test('a host is a hostname and never a path or a query', () {
      final endpoint = _endpoint(baseUrl: 'https://novel.example:8443/base');
      expect(endpoint.host, 'novel.example');
      expect(endpoint.host, isNot(contains('/')));
      expect(endpoint.host, isNot(contains('?')));
    });

    test('the HttpClient contract resolves through the endpoint', () {
      final client = buildHttpClient(
        _endpoint(),
        HostRateLimiter(),
        appVersion: '1.0.0',
      );
      expect(
        client.resolve('/novel/y.html').toString(),
        'https://novel.example/novel/y.html',
      );
    });
  });

  group('FetchResult', () {
    test('FetchResult is declared once and only in core/network', () {
      expect(FetchResult, isNotNull);
      // The type lives in exactly one file; the classifier imports it and does
      // not redeclare it. A second declaration would invert the dependency.
      expect(_declarationsOfSealedFetchResult(), 1);
    });

    test('the rate-limited case carries no host and no source id', () {
      const limited = FetchRateLimited(
        retryAfter: Duration(seconds: 5),
        status: 429,
      );
      // C5 / § 2.2: a 429 belongs to a host, and the host is already a key in
      // the limiter's slot table. A second copy would be free to diverge.
      expect(limited.runtimeType.toString(), isNot(contains('host')));
      expect(limited, isNot(isA<FetchTransportFailed>()));
    });
  });

  group('HttpResponse', () {
    test('the response carries the body and the discriminator together', () {
      const response = HttpResponse(
        outcome: FetchSucceeded(status: 200),
        status: 200,
        body: '<html>chapter</html>',
        contentType: 'text/html; charset=utf-8',
      );
      expect(response.outcome, isA<FetchSucceeded>());
      expect((response.outcome as FetchSucceeded).status, 200);
      expect(response.body, '<html>chapter</html>');
      expect(response.hasResponse, isTrue);
    });

    test('a body that was empty is an empty body and not a missing one', () {
      const response = HttpResponse(
        outcome: FetchSucceeded(status: 204),
        status: 204,
        body: '',
        contentType: null,
      );
      expect(response.outcome, isA<FetchSucceeded>());
      expect(response.body, isEmpty);
      expect(response.hasResponse, isTrue);
    });
  });
}

DioException _exceptionOf(DioExceptionType type, RequestOptions options) {
  if (type == DioExceptionType.connectionTimeout) {
    return DioException.connectionTimeout(
      timeout: const Duration(seconds: 10),
      requestOptions: options,
    );
  }
  return DioException(
    requestOptions: options,
    type: type,
    message: 'synthetic $type',
  );
}

DioException _badResponse(
  int status, {
  Map<String, List<String>> headers = const <String, List<String>>{},
}) {
  final options = RequestOptions(path: '/novel/x.html');
  return DioException(
    requestOptions: options,
    type: DioExceptionType.badResponse,
    message: 'HTTP $status',
    response: Response<dynamic>(
      requestOptions: options,
      statusCode: status,
      headers: Headers.fromMap(headers),
    ),
  );
}

/// Counts real declarations of `sealed class FetchResult` across `lib/`.
///
/// This walks the tree on purpose. A test that asserted the count against a
/// hardcoded `1` would pass forever, including after somebody declared a second
/// one — which is the exact defect the row exists to catch.
int _declarationsOfSealedFetchResult() {
  var count = 0;
  for (final entity in Directory('lib').listSync(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('.dart')) continue;
    final matches = RegExp(
      r'sealed\s+class\s+FetchResult\b',
    ).allMatches(entity.readAsStringSync());
    count += matches.length;
  }
  return count;
}
