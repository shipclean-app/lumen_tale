// forge:slice 0-1
// Lumen Tale — `0-1` § 11.1, the manifest rows.
//
// ⚠️ **Every row below is currently INACTIVE, and that is the honest state, not a
// defect in the file.** `0-1` exists to capture real FanMTL fixtures, and on
// 2026-10-03 FanMTL answered **403 with a Cloudflare interstitial to an honest
// User-Agent** on every path — `/`, `/robots.txt`, the catalogue path, and
// `/browsetags/`, which is the one path `18-external-contracts.md` records as
// working. Royal Road's catalogue and chapter paths answered **404** the same day.
//
// Wave 0 exists precisely to capture fixtures *before* any feature code, so this
// suite cannot be written until a capture succeeds. Rather than fabricate HTML and
// call it a capture — which is exactly what `kind: manufactured` exists to prevent —
// the rows are written against the manifest API and **skip loudly** when the
// fixtures are absent, naming the reason.
//
// The skip is deliberate and visible. A green `0-1` with manufactured fixtures
// standing in for captures would hand `2-1` a selector contract validated against
// nothing, which is the failure `0-1` was created to avoid. Findings **F-012** and
// **F-013** record the measurement.

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'fixture_manifest.dart';

void main() {
  // The manifest is the only artefact under test that can be absent, and its
  // absence has a measured cause rather than a hypothetical one.
  final manifestExists = File(
    'test/fixtures/sources/fanmtl/manifest.json',
  ).existsSync();

  group('the manifest', () {
    test('a missing manifest is REFUSED, never returned empty', () async {
      // C1 and `18-external-contracts.md` rule 1. A partial manifest is worse
      // than none: it lets a test pass against a file nobody declared.
      // `FixtureManifest.load` is on a static method, so this runs without any
      // fixture on disk.
      expect(
        () => FixtureManifest.load('does-not-exist'),
        throwsA(isA<FixtureManifestException>()),
        reason:
            'a lookup that returns an empty manifest turns a missing capture '
            'into a silently passing suite',
      );
    });

    test('a missing entry is REFUSED, never returned null', () async {
      // Same reason: a null turns "nobody captured this" into "nothing to
      // assert", which reads green.
      final FixtureManifest manifest = _inMemoryManifest();
      expect(
        () => manifest.require('no-such-key'),
        throwsA(isA<FixtureManifestException>()),
      );
      // A key that IS declared resolves.
      expect(
        manifest.require('catalogue-genre-page0').key,
        'catalogue-genre-page0',
      );
    });

    test('kind is a closed list, and an entry outside it is refused', () {
      // A free string becomes a taxonomy nobody maintains.
      expect(FixtureEntry.kinds, contains('catalogue'));
      expect(FixtureEntry.kinds, contains('manufactured'));
      // ⚠️ **Nine, not eight** — `6-11` added `search`. The count is asserted as a
      // NUMBER rather than as a membership list so that adding a kind is a visible
      // edit here, which is the point of closing the list: a `String` that appears
      // without anyone deciding it is how a taxonomy starts growing by accident.
      expect(
        FixtureEntry.kinds,
        hasLength(9),
        reason:
            'a new kind of captured page needs a decision in this file, not just an '
            'addition to FixtureEntry.kinds',
      );
      expect(FixtureEntry.kinds, contains('search'));

      expect(
        () => FixtureEntry.fromJson(
          _entryJson()..['kind'] = 'whatever',
          Directory('test/fixtures/sources/fanmtl'),
        ),
        throwsA(isA<FixtureManifestException>()),
        reason: 'a kind outside the closed list must not be accepted',
      );
    });

    test('every mandatory field is required', () {
      for (final field in FixtureEntry.requiredFields) {
        final json = _entryJson()..remove(field);
        expect(
          () => FixtureEntry.fromJson(
            json,
            Directory('test/fixtures/sources/fanmtl'),
          ),
          throwsA(isA<FixtureManifestException>()),
          reason:
              '"$field" is declared mandatory, so omitting it must fail '
              'rather than default',
        );
      }
    });

    test('the eleven mandatory fields are the eleven the plan names', () {
      // A field nothing reads is a promise nobody made; a mandatory field that
      // drifts out of the list is a manifest that stopped being checked.
      expect(FixtureEntry.requiredFields, hasLength(11));
      expect(FixtureEntry.requiredFields, <String>[
        'key',
        'file',
        'url',
        'httpStatus',
        'contentType',
        'capturedAt',
        'bytes',
        'sha256',
        'kind',
        'expected',
        'notes',
      ]);
    });
  });

  group('the captured fixtures', () {
    test('the manifest exists', () {
      if (!manifestExists) {
        markTestSkipped(
          'F-012/F-013: FanMTL answered 403 (Cloudflare) and Royal Road 404 to '
          'an honest UA on 2026-10-03, so no capture could be made. Wave 0 '
          'cannot proceed until a capture succeeds.',
        );
      }
      final manifest = FixtureManifest.load('fanmtl');
      expect(manifest.site, 'fanmtl');
    }, skip: !manifestExists ? 'no capture yet — see F-012' : null);

    test('every declared file exists on disk, and every file is declared', () {
      if (!manifestExists) {
        markTestSkipped('F-012/F-013: no capture yet.');
      }
      final manifest = FixtureManifest.load('fanmtl');

      for (final entry in manifest.entries) {
        expect(
          entry.fileOnDisk.existsSync(),
          isTrue,
          reason: '${entry.key} declares ${entry.file}, which is not on disk',
        );
      }

      final declared = manifest.entries.map((FixtureEntry e) => e.file).toSet();
      final onDisk = manifest.dir
          .listSync()
          .whereType<File>()
          .where(
            (File f) => f.path.endsWith('.html') || f.path.endsWith('.txt'),
          )
          .map((File f) => f.path.split('/').last)
          .toSet();
      expect(
        onDisk.difference(declared),
        isEmpty,
        reason:
            'B9/C1 — a fixture nobody declared is a test nobody can rely on',
      );
    }, skip: !manifestExists ? 'no capture yet — see F-012' : null);

    test('bytesOnDisk equals the declared length, on every entry', () {
      if (!manifestExists) {
        markTestSkipped('F-012/F-013: no capture yet.');
      }
      // B9, E1. This is the ONE field the automatic guard asserts, per § 3.2.
      for (final entry in FixtureManifest.load('fanmtl').entries) {
        expect(
          entry.fileOnDisk.lengthSync(),
          entry.bytes,
          reason: '${entry.key}: the declared length and the file disagree',
        );
      }
    }, skip: !manifestExists ? 'no capture yet — see F-012' : null);

    test('no declared url is absolute', () {
      if (!manifestExists) {
        markTestSkipped('F-012/F-013: no capture yet.');
      }
      // `03-source-system.md` rules 2-3, and C1: a stored absolute URL breaks
      // silently when the host changes.
      for (final entry in FixtureManifest.load('fanmtl').entries) {
        expect(
          entry.url,
          isNot(contains('://')),
          reason: '${entry.key} stores an absolute URL: ${entry.url}',
        );
      }
    }, skip: !manifestExists ? 'no capture yet — see F-012' : null);

    test('no fixture carries a session cookie', () {
      if (!manifestExists) {
        markTestSkipped('F-012/F-013: no capture yet.');
      }
      // C2, B4: no account, no server, and reading data never leaves the phone.
      // A captured session cookie would be the one artefact that could.
      for (final entry in FixtureManifest.load('fanmtl').entries) {
        if (!entry.fileOnDisk.existsSync()) continue;
        final text = entry.fileOnDisk.readAsStringSync();
        for (final secret in <String>[
          'Set-Cookie',
          'sessionid',
          'PHPSESSID',
          'csrf',
        ]) {
          expect(
            text.toLowerCase(),
            isNot(contains(secret.toLowerCase())),
            reason:
                '${entry.key} appears to carry "$secret" — C2 forbids it in '
                'a committed fixture',
          );
        }
      }
    }, skip: !manifestExists ? 'no capture yet — see F-012' : null);

    test('every entry has provenance: non-empty notes and an ISO 8601 date', () {
      if (!manifestExists) {
        markTestSkipped('F-012/F-013: no capture yet.');
      }
      final manifest = FixtureManifest.load('fanmtl');
      // `18-external-contracts.md` rule 1. `notes` records what was OBSERVED, not
      // the workaround, and an empty string is forbidden.
      final iso = RegExp(r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$');
      for (final entry in manifest.entries) {
        expect(entry.notes.trim(), isNotEmpty, reason: entry.key);
        expect(
          iso.hasMatch(entry.capturedAt),
          isTrue,
          reason: '${entry.key}: ${entry.capturedAt} is not ISO 8601 UTC',
        );
      }

      // `capturedBy` is a MANIFEST-level field, not per-entry, so it is read once
      // here rather than inside the loop. A first draft asserted
      // `entry.capturedBy`, which does not exist — § 2.2 puts the field on the
      // manifest object.
      expect(
        manifest.capturedBy,
        '0-1',
        reason: 'a re-captured fixture keeps 0-1 plus a new date',
      );
    }, skip: !manifestExists ? 'no capture yet — see F-012' : null);

    test(
      'the manufactured broken-layout fixture differs by one substitution',
      () {
        if (!manifestExists) {
          markTestSkipped('F-012/F-013: no capture yet.');
        }
        // E4 and SC-6. The manufactured artefact is the ONLY one `0-1` may
        // fabricate, and § 3.2 makes the edit mechanically checkable:
        // `chapter-content` → `chapter-content-v2`, applied literally, nothing else
        // changed.
        final manifest = FixtureManifest.load('fanmtl');
        final broken = manifest.ofKind('manufactured');
        expect(broken, isNotEmpty, reason: 'E4 needs a manufactured fixture');

        for (final entry in broken) {
          expect(
            entry.file,
            isNot(contains('chapter-content-v2')),
            reason: 'the file name is unchanged — only the class is',
          );
          if (!entry.fileOnDisk.existsSync()) continue;
          final text = entry.fileOnDisk.readAsStringSync();
          expect(text, contains('chapter-content-v2'));
          expect(
            text,
            isNot(contains('class="chapter-content"')),
            reason:
                'the renamed container must be gone, or the fixture is not '
                'the failure it claims to be',
          );
          expect(
            text,
            contains('<script'),
            reason:
                'the advertising <script> is NOT removed — a fixture that '
                'silently tidies the page is not a real page',
          );
        }
      },
      skip: !manifestExists ? 'no capture yet — see F-012' : null,
    );

    test('the catalogue fixture pair exists with distinct page URLs', () {
      if (!manifestExists) {
        markTestSkipped('F-012/F-013: no capture yet.');
      }
      // B9: pagination must be two real pages, not one page twice.
      final manifest = FixtureManifest.load('fanmtl');
      final pages = manifest
          .ofKind('catalogue')
          .where((FixtureEntry e) => e.key.startsWith('catalogue-genre-'))
          .toList();
      expect(
        pages.map((FixtureEntry e) => e.key),
        containsAll(<String>['catalogue-genre-page0', 'catalogue-genre-page1']),
      );

      final urls = pages.map((FixtureEntry e) => e.url).toSet();
      expect(
        urls,
        hasLength(pages.length),
        reason: 'each page needs its own URL',
      );
      expect(urls.any((String u) => u.endsWith('-0.html')), isTrue);
      expect(urls.any((String u) => u.endsWith('-1.html')), isTrue);
    }, skip: !manifestExists ? 'no capture yet — see F-012' : null);

    test('both a short and a long chapter fixture are declared', () {
      if (!manifestExists) {
        markTestSkipped('F-012/F-013: no capture yet.');
      }
      // E22 and E18: "short" and "broken" must not be confusable, and the 100
      // character threshold only means something against a known-short page.
      final manifest = FixtureManifest.load('fanmtl');
      final chapters = manifest
          .ofKind('chapter')
          .map((FixtureEntry e) => e.key);
      expect(chapters, contains('chapter-short'));
      expect(chapters, contains('chapter-long'));
    }, skip: !manifestExists ? 'no capture yet — see F-012' : null);
  });
}

/// A minimal well-formed manifest, so the API rows run with no fixture on disk.
FixtureManifest _inMemoryManifest() {
  final dir = Directory('test/fixtures/sources/fanmtl');
  return FixtureManifest(
    site: 'fanmtl',
    baseUrl: 'https://www.fanmtl.com',
    dir: dir,
    entries: <FixtureEntry>[FixtureEntry.fromJson(_entryJson(), dir)],
  );
}

/// One well-formed entry, matching § 2.2 exactly.
Map<String, dynamic> _entryJson() => <String, dynamic>{
  'key': 'catalogue-genre-page0',
  'file': 'catalogue-genre-page0.html',
  'url': '/list/xianxia/all-lastdotime-0.html',
  'httpStatus': 200,
  'contentType': 'text/html; charset=utf-8',
  'capturedAt': '2026-10-02T21:40:11Z',
  'bytes': 118402,
  'sha256': '<captured by sha256sum>',
  'kind': 'catalogue',
  'expected': <String, dynamic>{'novelRowsAtLeast': 30, 'novelRowsExact': null},
  'notes': 'Page 0 du genre xianxia, as observed on 2026-10-02.',
};
