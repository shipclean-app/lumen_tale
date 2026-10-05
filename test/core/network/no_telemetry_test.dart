// Lumen Tale — `http-client` § 11.1, the posture rows.
//
// These are **grep tests**. Each asserts a claim about the shape of the source
// rather than about its runtime behaviour, which is the only way to assert "this
// layer never logs" and "this layer never bypasses TLS".
//
// A grep test has one failure mode that matters: it passes because its own
// pattern is wrong. Every row therefore carries a **witness** — a string that
// deliberately matches, asserted to match — so a broken pattern fails loudly
// instead of reporting a permanent, meaningless green.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The files that make up the network layer.
List<File> _networkLayerFiles() {
  final dir = Directory('lib/core/network');
  expect(dir.existsSync(), isTrue, reason: 'lib/core/network must exist');
  final files =
      dir
          .listSync()
          .whereType<File>()
          .where((File f) => f.path.endsWith('.dart'))
          .toList()
        ..sort((File a, File b) => a.path.compareTo(b.path));
  expect(files, isNotEmpty);
  return files;
}

String _readAll(List<File> files) =>
    files.map((File f) => f.readAsStringSync()).join('\n');

/// Whether the line a hit points at is a comment.
///
/// Comments are excluded, and necessarily so: this layer documents *why* there is
/// no `badCertificateCallback`, and a grep that counted its own prohibition would
/// report a permanent red for a layer that is correct.
///
/// The exclusion is line-based and narrow — a line whose first non-space
/// characters open a comment. A prohibition therefore cannot hide a use, because
/// a use sits on code.
bool _isComment(File file, int lineNumber) {
  final line = file.readAsStringSync().split('\n')[lineNumber - 1].trimLeft();
  return line.startsWith('//') || line.startsWith('*') || line.startsWith('/*');
}

/// Every **executable** line in [files] matching [pattern], as `path:line`.
List<String> _grepCode(List<File> files, RegExp pattern) {
  final hits = <String>[];
  for (final file in files) {
    final lines = file.readAsStringSync().split('\n');
    for (var i = 0; i < lines.length; i++) {
      if (pattern.hasMatch(lines[i]) && !_isComment(file, i + 1)) {
        hits.add('${file.path}:${i + 1}');
      }
    }
  }
  return hits;
}

void _assertNoMatch(List<File> files, RegExp pattern, String reason) {
  final hits = _grepCode(files, pattern);
  expect(hits, isEmpty, reason: '$reason — found in $hits');
}

void main() {
  // Opened in `setUpAll`, not at `main()` scope: `expect` is illegal outside a
  // test, and calling it while the file loads throws `OutsideTestException`
  // rather than failing a row. A checker that cannot run at all is not a checker.
  late List<File> files;
  late String source;

  setUpAll(() {
    files = _networkLayerFiles();
    source = _readAll(files);
  });

  group('Posture', () {
    test('the network layer logs nothing', () {
      // B29, C2: no telemetry, and nothing written anywhere the reader could
      // not see. `print` and `debugPrint` are the two that actually reach a
      // device console in a release build.
      _assertNoMatch(files, RegExp(r'\bprint\s*\('), 'no print — B29');
      _assertNoMatch(
        files,
        RegExp(r'\bdebugPrint\s*\('),
        'no debugPrint — B29',
      );
      _assertNoMatch(
        files,
        RegExp(r'\b(log|logger)\s*\.\s*(d|i|v|w|e)\s*\('),
        'no logger calls — B29',
      );

      // Witness: the greps can actually match a print when one exists.
      expect(RegExp(r'\bprint\s*\(').hasMatch('print(1);'), isTrue);
      expect(RegExp(r'\bdebugPrint\s*\(').hasMatch('debugPrint(1);'), isTrue);
    });

    test('the network layer carries no telemetry client', () {
      for (final banned in <String>[
        'analytics',
        'crashlytics',
        'sentry',
        'firebase',
        'bugsnag',
        'mixpanel',
      ]) {
        _assertNoMatch(
          files,
          RegExp(banned, caseSensitive: false),
          'no $banned — B29 forbids transmitting reading data off the phone',
        );
      }
      // Witness.
      expect(
        RegExp('analytics', caseSensitive: false).hasMatch('Analytics.x'),
        isTrue,
      );
    });

    test('the network layer disables no certificate validation', () {
      // `17-security.md` rule 7: TLS only. A `badCertificateCallback` is exactly
      // the shape of "make TLS failures go away", and C7 requires a rejected
      // certificate to be reported rather than bypassed.
      _assertNoMatch(
        files,
        RegExp('badCertificateCallback'),
        'no certificate callback — rule 7 is TLS only',
      );
      _assertNoMatch(
        files,
        RegExp('trustAll|trustAllCertificates|acceptAll'),
        'no trust-all — rule 7 is TLS only',
      );
      _assertNoMatch(
        files,
        RegExp(r'\bproxy\b', caseSensitive: false),
        'no proxy configuration in core/network',
      );
      // Witness.
      expect(
        RegExp('badCertificateCallback').hasMatch('x.badCertificateCallback'),
        isTrue,
      );
    });

    test('the network layer imports nothing from another layer', () {
      // `02-architecture.md`: `core` may depend on external packages only.
      //
      // `core/network` and `core/error` are siblings under `core/`, so importing
      // `core/error/…` is legal — it is how the typed exceptions arrive. What
      // must never appear is an import of `domain/`, `data/`, `features/`,
      // `app/` or `sources/`.
      _assertNoMatch(
        files,
        RegExp('package:lumen_tale/(domain|data|features|app|sources)/'),
        'core/ must not import another layer',
      );

      // And the sibling import that IS legal is genuinely present, which is what
      // keeps the check above from being vacuously true.
      expect(
        source,
        contains('package:lumen_tale/core/error/app_exception.dart'),
        reason: 'the typed exceptions are expected to be imported',
      );
    });

    test('the network layer has no retry', () {
      // § 3.6: no retry policy, as a decision. A retry is a *decision* and
      // belongs to the caller that can justify it (`architecture.md` § 2.3).
      //
      // Note what is NOT forbidden: the limiter and `Retry-After` both contain
      // the substring "retry". These patterns target the MECHANISMS — dio's own
      // retry interceptor, and an `onError` handler that re-issues.
      _assertNoMatch(
        files,
        RegExp('retryInterceptor|dio\\.retry|RetryInterceptor'),
        'no retry interceptor — § 3.6',
      );
      _assertNoMatch(
        files,
        RegExp(r'\bonError\s*\('),
        'no onError handler that could re-issue a request — § 3.6',
      );
      // Witness.
      expect(
        RegExp('retryInterceptor').hasMatch('dio.retryInterceptor()'),
        isTrue,
      );
    });

    test(
      'the network layer sets an honest User-Agent and no impersonation',
      () {
        // ADR-014 measured this: an honest agent gets 200 where a
        // browser-impersonating one gets challenged. C7 asks for honesty.
        expect(source, contains('LumenTale/'));
        for (final impersonation in <String>[
          'Mozilla',
          'Chrome/',
          'Safari/',
          'WebKit',
        ]) {
          _assertNoMatch(
            files,
            RegExp(impersonation),
            'no $impersonation outside a comment forbidding it — ADR-014',
          );
        }
        // Witness.
        expect(RegExp('Mozilla').hasMatch("'Mozilla/5.0'"), isTrue);
      },
    );
  });
}
