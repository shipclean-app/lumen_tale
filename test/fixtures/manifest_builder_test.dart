// forge:slice 0-1
// Lumen Tale — `0-1` § 11.1, the manifest BUILDER's refusals.
//
// `tool/build_manifest.py` turns files dropped into a fixture folder into a
// manifest. It is the tool that computes `bytes` and `sha256`, so it is also the
// tool that could quietly get them wrong.
//
// ⚠️ **Every refusal in this file was written because the check was found NOT to
// fire.** A validator that has never rejected anything is unknown, not validated,
// and this project has shipped four of them. Each row below therefore states the
// escape it closes, and each was proven by running the tool against a staged
// fixture folder — not by reading the code.
//
// Three real escapes were found and fixed this way:
//
//  1. **`capturedAt` was only checked per entry**, so a malformed value at the TOP
//     level of `manifest.in.json` was accepted while the same value on an entry was
//     refused. Guarding with `is not None` compounded it: omitting the key skipped
//     the check entirely.
//  2. **The browser-save wrapper check required a specific byte adjacency**
//     (`<!doctype html>` then the comment). Chrome emits the comment FIRST, so a
//     real browser save was accepted — the exact artefact the check exists to
//     catch.
//  3. The `.mht` and session-cookie refusals held on the first run.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const String tool = 'tool/build_manifest.py';
const String fixtureRoot = 'test/fixtures/sources';

/// Runs the builder against a staged site, in a temp location, and reports
/// whether it refused and whether it wrote a manifest.
class _Result {
  _Result(this.refused, this.wrote, this.output);

  final bool refused;
  final bool wrote;
  final String output;

  String get firstRefusal {
    for (final line in output.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.startsWith('- ')) return trimmed.substring(2);
    }
    return '(the tool refused without naming a reason)';
  }
}

/// Stages a minimal site, mutates it, runs the builder, and cleans up.
///
/// Everything happens under a `probe` site directory so a refusal can never touch
/// a real capture: `main()` refuses to run against `royalroad` or `fanmtl`.
Future<_Result> _runBuilder({
  required Map<String, dynamic> spec,
  Map<String, String> files = const <String, String>{},
}) async {
  final dir = Directory('$fixtureRoot/probe');
  if (dir.existsSync()) dir.deleteSync(recursive: true);
  dir.createSync(recursive: true);

  File('${dir.path}/manifest.in.json').writeAsStringSync(_json(spec));
  files.forEach((String name, String body) {
    File('${dir.path}/$name').writeAsStringSync(body);
  });

  final result = await Process.run('python3', <String>[tool, 'probe']);

  final output = '${result.stdout}${result.stderr}';
  return _Result(
    result.exitCode != 0,
    File('$fixtureRoot/probe/manifest.json').existsSync(),
    output,
  );
}

/// A spec with one `robots` entry — the simplest thing that can be accepted.
Map<String, dynamic> _validSpec() => <String, dynamic>{
  'baseUrl': 'https://example.test',
  'capturedBy': '0-1',
  'entries': <Map<String, dynamic>>[
    <String, dynamic>{
      'key': 'robots',
      'file': 'robots.txt',
      'url': '/robots.txt',
      'httpStatus': 200,
      'contentType': 'text/plain; charset=utf-8',
      'kind': 'robots',
      'notes': "The site's own robots.txt.",
    },
  ],
};

Map<String, dynamic> _withEntry(Map<String, dynamic> extra) {
  final spec = _validSpec();
  (spec['entries'] as List<Map<String, dynamic>>).add(extra);
  return spec;
}

String _json(Object value) => const JsonEncoder().encode(value);

void main() {
  const robots = 'User-agent: *\nDisallow: /private/\n';

  tearDown(() {
    final dir = Directory('$fixtureRoot/probe');
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  group('the happy path', () {
    test('a well-formed spec produces a manifest with MEASURED values', () async {
      final result = await _runBuilder(
        spec: _validSpec(),
        files: <String, String>{'robots.txt': robots},
      );
      expect(result.refused, isFalse, reason: result.output);
      expect(result.wrote, isTrue);

      final manifest = File(
        '$fixtureRoot/probe/manifest.json',
      ).readAsStringSync();
      // The two measured fields are present...
      expect(manifest, contains('"bytes"'));
      expect(manifest, contains('"sha256"'));
      // ...and they are the file's own, not a placeholder. The builder computes
      // them; nothing supplied them.
      expect(manifest, contains('"bytes": ${robots.length}'));
    });

    test('bytes and sha256 must NOT be supplied — they are measured', () async {
      // § 3.2: `bytes` is the ONE field an automatic guard asserts, so a
      // hand-typed one is a promise that can disagree with the file.
      final spec = _validSpec();
      (spec['entries'] as List<Map<String, dynamic>>).first['sha256'] =
          '0' * 64;
      final result = await _runBuilder(
        spec: spec,
        files: <String, String>{'robots.txt': robots},
      );
      expect(result.refused, isTrue);
      expect(result.wrote, isFalse);
      expect(result.firstRefusal, contains('must not be supplied'));
    });
  });

  group('the refusals, each one proven to fire', () {
    test('an absolute url is refused', () async {
      final spec = _validSpec();
      (spec['entries'] as List<Map<String, dynamic>>).first['url'] =
          'https://example.test/robots.txt';
      final result = await _runBuilder(
        spec: spec,
        files: <String, String>{'robots.txt': robots},
      );
      expect(result.refused, isTrue, reason: result.output);
      expect(result.firstRefusal, contains('is absolute'));
    });

    test('a kind outside the closed list is refused', () async {
      final spec = _validSpec();
      (spec['entries'] as List<Map<String, dynamic>>).first['kind'] =
          'whatever';
      final result = await _runBuilder(
        spec: spec,
        files: <String, String>{'robots.txt': robots},
      );
      expect(result.refused, isTrue);
      expect(result.firstRefusal, contains('not in the closed list'));
    });

    test('empty notes are refused', () async {
      final spec = _validSpec();
      (spec['entries'] as List<Map<String, dynamic>>).first['notes'] = '   ';
      final result = await _runBuilder(
        spec: spec,
        files: <String, String>{'robots.txt': robots},
      );
      expect(result.refused, isTrue);
      expect(result.firstRefusal, contains('notes is empty'));
    });

    test('a malformed capturedAt at the TOP LEVEL is refused', () async {
      // ⚠️ The escape this row closes. The check originally lived only in the
      // per-entry loop, so a bad value at the top level of the spec was never
      // looked at.
      final spec = _validSpec()..['capturedAt'] = 'yesterday';
      final result = await _runBuilder(
        spec: spec,
        files: <String, String>{'robots.txt': robots},
      );
      expect(result.refused, isTrue, reason: result.output);
      expect(result.firstRefusal, contains('ISO 8601'));
    });

    test('a malformed capturedAt on an ENTRY is refused', () async {
      final spec = _validSpec();
      (spec['entries'] as List<Map<String, dynamic>>).first['capturedAt'] =
          '03/10/2026';
      final result = await _runBuilder(
        spec: spec,
        files: <String, String>{'robots.txt': robots},
      );
      expect(result.refused, isTrue);
      expect(result.firstRefusal, contains('ISO 8601'));
    });

    test('an OMITTED capturedAt is accepted and stamped', () async {
      // The counterpart: the key is optional, and omitting it must not trip the
      // format check. The first version guarded with `is not None`, which made
      // omission and malformation indistinguishable to the reader.
      final result = await _runBuilder(
        spec: _validSpec(),
        files: <String, String>{'robots.txt': robots},
      );
      expect(result.refused, isFalse, reason: result.output);
      final manifest = File(
        '$fixtureRoot/probe/manifest.json',
      ).readAsStringSync();
      expect(manifest, matches(RegExp(r'"capturedAt": "\d{4}-\d{2}-\d{2}T')));
    });

    test('a declared file that is absent is refused', () async {
      final result = await _runBuilder(spec: _validSpec());
      expect(result.refused, isTrue);
      expect(result.firstRefusal, contains('absent from'));
    });

    test('an MHTML save is refused', () async {
      // MHTML is a MIME envelope, not HTML. Unwrapping it by hand is an edit
      // nobody recorded.
      final result = await _runBuilder(
        spec: _withEntry(<String, dynamic>{
          'key': 'saved',
          'file': 'page.mht',
          'url': '/x',
          'httpStatus': 200,
          'kind': 'chapter',
          'notes': 'An MHTML save.',
        }),
        files: <String, String>{
          'robots.txt': robots,
          'page.mht': 'MIME-Version: 1.0\nContent-Type: multipart/related\n',
        },
      );
      expect(result.refused, isTrue);
      expect(result.firstRefusal, contains('MHTML'));
    });

    test('a session cookie in a fixture is refused — C2, B4', () async {
      for (final secret in <String>[
        'Set-Cookie: sessionid=abc',
        'cf_clearance=xyz',
        'PHPSESSID=deadbeef',
        '<meta name="csrf-token" content="t">',
      ]) {
        final result = await _runBuilder(
          spec: _withEntry(<String, dynamic>{
            'key': 'leaky',
            'file': 'leak.html',
            'url': '/x',
            'httpStatus': 200,
            'kind': 'chapter',
            'notes': 'A page carrying a token.',
          }),
          files: <String, String>{
            'robots.txt': robots,
            'leak.html': '<html><body>$secret</body></html>',
          },
        );
        expect(
          result.refused,
          isTrue,
          reason:
              'a fixture containing "$secret" was accepted, which is C2 and '
              'B4 breached in the repository',
        );
      }
    });
  });

  group('a browser save is detected in every shape Chrome emits', () {
    // ⚠️ The second escape this file closes. The check originally required
    // `<!doctype html>` IMMEDIATELY followed by the comment; Chrome emits the
    // comment first, so a real save was accepted. Each shape below is a real
    // Chrome output form.
    const shapes = <String, String>{
      'comment before doctype':
          '<!-- saved by Chrome 140 -->\n<!DOCTYPE html><html><body>x</body></html>',
      'doctype then comment':
          '<!DOCTYPE html>\n<!-- saved by Chrome 140 -->\n<html><body>x</body></html>',
      'bare saved-by marker':
          '<!DOCTYPE html>\n<!-- saved by -->\n<html><body>x</body></html>',
    };

    for (final entry in shapes.entries) {
      test('refused: ${entry.key}', () async {
        final result = await _runBuilder(
          spec: _withEntry(<String, dynamic>{
            'key': 'saved',
            'file': 'saved.html',
            'url': '/x',
            'httpStatus': 200,
            'kind': 'chapter',
            'notes': 'A browser save.',
          }),
          files: <String, String>{
            'robots.txt': robots,
            'saved.html': entry.value,
          },
        );
        expect(result.refused, isTrue, reason: result.output);
        expect(result.firstRefusal, contains('wrapper'));
      });
    }

    test('a genuine site page is NOT mistaken for a wrapper', () async {
      // The counterpart. A wrapper check that refuses everything is as useless as
      // one that refuses nothing, and this row is what distinguishes them.
      final result = await _runBuilder(
        spec: _withEntry(<String, dynamic>{
          'key': 'real',
          'file': 'real.html',
          'url': '/x',
          'httpStatus': 200,
          'kind': 'chapter',
          'notes': 'A page as the server sent it.',
        }),
        files: <String, String>{
          'robots.txt': robots,
          'real.html':
              '<!DOCTYPE html>\n<html><head><title>Real</title></head>'
              '<body><div class="chapter-content">ok</div></body></html>',
        },
      );
      expect(result.refused, isFalse, reason: result.output);
      expect(result.wrote, isTrue);
    });
  });
}

/// Minimal JSON writer, so a spec can be staged without pulling in a dev
/// dependency for four fixture-shaped maps.
///
/// `dart:convert`'s `jsonEncode` would do, and this file already imports
/// `dart:io` — but a hand-rolled writer keeps the test hermetic and makes the
/// escaping rules explicit, which matters because several refusals are about
/// text that would break naive quoting.
class JsonEncoder {
  const JsonEncoder();

  String encode(Object? value) {
    final buffer = StringBuffer();
    _write(buffer, value);
    return buffer.toString();
  }

  void _write(StringBuffer out, Object? value) {
    if (value == null) {
      out.write('null');
    } else if (value is String) {
      out.write('"${_escape(value)}"');
    } else if (value is num || value is bool) {
      out.write('$value');
    } else if (value is List) {
      out.write('[');
      for (var i = 0; i < value.length; i++) {
        if (i > 0) out.write(',');
        _write(out, value[i]);
      }
      out.write(']');
    } else if (value is Map) {
      out.write('{');
      var first = true;
      value.forEach((Object? k, Object? v) {
        if (!first) out.write(',');
        first = false;
        out.write('"${_escape('$k')}":');
        _write(out, v);
      });
      out.write('}');
    } else {
      throw ArgumentError('cannot encode ${value.runtimeType}');
    }
  }

  String _escape(String value) => value
      .replaceAll('\\', '\\\\')
      .replaceAll('"', '\\"')
      .replaceAll('\n', '\\n')
      .replaceAll('\r', '\\r')
      .replaceAll('\t', '\\t');
}
