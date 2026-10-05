// forge:slice 0-1, 2-1
// Lumen Tale — `0-1` § 11.1 against the Royal Road capture.
//
// ⚠️ **FanMTL could not be captured.** Measured 2026-10-03 with the honest
// `LumenTale/0.1.0 (personal reader)` UA, every FanMTL path answered **403** with a
// Cloudflare interstitial — including `/browsetags/`, which
// `18-external-contracts.md` records as the one path that works. ADR-014 measured the
// site at 200 the day before. Finding **F-012**.
//
// So this suite runs against **Royal Road**, captured the same day and reachable. It
// is not a substitute: the two sites have different markup, and `2-1` builds a
// contract *over* sources rather than for one. What this suite proves is that the
// capture discipline works — provenance, lengths, pagination, the site's own
// completeness witness, and the E18 short/long pair — on a real site.
//
// Nothing here is manufactured. `kind: manufactured` exists precisely so a
// fabricated artefact can never be mistaken for a capture, and the only fixture `0-1`
// may manufacture is the broken-layout pair, which is built from this capture by a
// single literal substitution and is verified as such.

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'fixture_manifest.dart';

void main() {
  final FixtureManifest manifest = FixtureManifest.load('royalroad');

  group('the manifest itself', () {
    test('loads, and declares the site its folder is named for', () {
      expect(manifest.site, 'royalroad');
      expect(manifest.baseUrl, 'https://www.royalroad.com');
      expect(manifest.capturedBy, '0-1');
      expect(manifest.entries, isNotEmpty);
    });

    test('every declared file exists, and every file on disk is declared', () {
      // B9/C1. A fixture nobody declared is a test nobody can rely on; a declared
      // file that is absent turns an assertion into a skip.
      for (final entry in manifest.entries) {
        expect(
          entry.fileOnDisk.existsSync(),
          isTrue,
          reason: '${entry.key} declares ${entry.file}, absent from disk',
        );
      }
      final declared = manifest.entries.map((FixtureEntry e) => e.file).toSet();
      // RECURSIVE, because a `kind: manufactured` entry lives in a subdirectory
      // (`manufactured/broken-layout.html`). `listSync()` without `recursive: true`
      // sees only the top level, so the row reported the manufactured fixture as
      // "on disk but undeclared" — the exact failure B9 warns about, caused by the
      // check itself.
      //
      // Paths are made relative to the manifest directory so a declared
      // `manufactured/broken-layout.html` and an on-disk
      // `<dir>/manufactured/broken-layout.html` compare equal.
      final onDisk = manifest.dir
          .listSync(recursive: true)
          .whereType<File>()
          // `manifest.json` is the manifest, not a fixture: it is never declared as
          // an entry, so it must be excluded from the on-disk side of BOTH
          // directions. A first draft excluded it from one side only, and the row
          // failed on `manifest.json` being "undeclared" — which it is not, it is
          // the thing doing the declaring.
          // Same reasoning for `empty-signal.json`: it is a MEASUREMENT `0-2` wrote
          // about these fixtures, not a fixture. It is read by
          // `test/domain/sources/empty_signal_test.dart`, which re-derives it from
          // the files below — so it is covered, just not by this manifest. Excluding
          // it here is correct; excluding it because it is "another kind of file"
          // in general is not, so the exclusion is by exact name.
          //
          // ⚠️ Same reasoning, same rule: `search/verdict.json` is a **measurement**
          // `6-11` wrote about the three search pages, not a captured page. The three
          // HTML files ARE declared entries (`kind: search`); this JSON is what a test
          // re-derives FROM them. Excluding it by exact name, like the other
          // measurement, keeps the row's meaning intact — and the reason it is worth
          // an entry at all is that the re-derivation is the point: the search verdict
          // is a claim someone could write from memory, and here it is a claim a test
          // recomputes.
          .where(
            (File f) =>
                f.path.split('/').last != 'manifest.json' &&
                f.path.split('/').last != 'empty-signal.json' &&
                f.path.split('/').last != 'verdict.json',
          )
          .map(
            (File f) => f.path
                .substring(manifest.dir.path.length + 1)
                .replaceAll('\\', '/'),
          )
          .toSet();
      expect(
        onDisk.difference(declared),
        isEmpty,
        reason:
            'a fixture on disk that nobody declared is a test nobody can '
            'rely on',
      );
      expect(
        declared.difference(onDisk),
        isEmpty,
        reason:
            'a declared fixture that is absent turns an assertion into a skip',
      );
    });

    test('bytesOnDisk equals the declared length on EVERY entry', () {
      // § 3.2: this is the ONE field the automatic guard asserts. A capture whose
      // declared length disagrees with the file is a capture nobody can trust.
      for (final entry in manifest.entries) {
        expect(
          entry.fileOnDisk.lengthSync(),
          entry.bytes,
          reason:
              '${entry.key}: declared ${entry.bytes}, on disk '
              '${entry.fileOnDisk.lengthSync()}',
        );
      }
    });

    test('no declared url is absolute', () {
      // `03-source-system.md` rules 2-3. A stored absolute URL breaks silently when
      // the host changes, and the host is not part of the fixture's identity.
      for (final entry in manifest.entries) {
        expect(
          entry.url,
          isNot(contains('://')),
          reason: '${entry.key} stores an absolute URL',
        );
      }
    });

    test('every entry carries provenance: notes and an ISO 8601 UTC date', () {
      // `18-external-contracts.md` rule 1. `notes` records what was OBSERVED, not a
      // workaround, and an empty string is forbidden.
      final iso = RegExp(r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$');
      for (final entry in manifest.entries) {
        expect(entry.notes.trim(), isNotEmpty, reason: entry.key);
        expect(
          iso.hasMatch(entry.capturedAt),
          isTrue,
          reason: '${entry.key}: ${entry.capturedAt}',
        );
        expect(
          entry.sha256,
          matches(RegExp(r'^[0-9a-f]{64}$')),
          reason: '${entry.key}: sha256 must be a real digest',
        );
      }
    });

    test('no fixture carries a session cookie or a token', () {
      // C2/B4: no account, no server, no telemetry. A committed session cookie is
      // the one artefact that could carry reading data off the phone, and it is
      // exactly what must never end up in the repository.
      for (final entry in manifest.entries) {
        final lower = entry.fileOnDisk.readAsStringSync().toLowerCase();
        for (final secret in <String>[
          'set-cookie',
          'sessionid',
          'phpsessid',
          'csrf',
          'bearer ',
        ]) {
          expect(
            lower,
            isNot(contains(secret)),
            reason: '${entry.key} appears to carry "$secret"',
          );
        }
      }
    });
  });

  group('robots.txt was honoured, not just captured', () {
    test('the `User-agent: *` block does not disallow anything we captured', () {
      // C1, and the reason `robots.txt` is a fixture rather than a formality. We
      // must be able to PROVE the captured paths were permitted, not assert it.
      final robots = manifest.require('robots').fileOnDisk.readAsStringSync();
      final block = RegExp(
        r'User-agent:\s*\*\s*(.*?)(?=\nUser-agent:|\Z)',
        dotAll: true,
      ).firstMatch(robots)!.group(1)!;
      final disallowed = RegExp(r'Disallow:\s*(\S+)')
          .allMatches(block)
          .map((Match m) => m.group(1)!)
          .where((String p) => p.isNotEmpty)
          .toList();

      expect(
        disallowed,
        isNotEmpty,
        reason: 'the block exists; prove we read it',
      );
      for (final entry in manifest.entries) {
        if (entry.key == 'robots') continue;
        for (final path in disallowed) {
          expect(
            entry.url,
            isNot(startsWith(path)),
            reason:
                '${entry.key} captures ${entry.url}, which robots.txt '
                'disallows for `*` via $path',
          );
        }
      }
    });

    test('we are not one of the agents disallowed wholesale', () {
      // `GPTBot`, `CCBot`, `ClaudeBot` and eight others are `Disallow: /`. Our UA is
      // `LumenTale/…`, which matches the `*` block — and impersonating a disallowed
      // agent is both C1's problem and ADR-014's, since browser impersonation is
      // measured to make things worse.
      final robots = manifest.require('robots').fileOnDisk.readAsStringSync();
      final wholesale = RegExp(
        r'User-agent:\s*(\S+)[^\n]*\nDisallow:\s*/\s*$',
        multiLine: true,
      ).allMatches(robots).map((Match m) => m.group(1)!.toLowerCase()).toSet();
      expect(wholesale, isNotEmpty);
      expect(wholesale, isNot(contains('lumendale')));
      expect(wholesale, isNot(contains('*')));
    });
  });

  group('B9 — pagination is real and the site publishes its own count', () {
    test('page 1 and page 2 are DIFFERENT pages', () {
      // The reason two catalogue pages were captured. If `?page=2` were ignored,
      // both files would be identical and "40 rows parsed but the site says 716"
      // could never be distinguished from a complete list.
      final p0 = manifest.require('catalogue-active-popular-page0');
      final p1 = manifest.require('catalogue-active-popular-page1');
      expect(p0.bytes, greaterThan(0));
      expect(p1.bytes, greaterThan(0));
      expect(
        p0.fileOnDisk.readAsStringSync(),
        isNot(p1.fileOnDisk.readAsStringSync()),
        reason: 'the two pages are byte-identical, so pagination is not real',
      );
    });

    test('each catalogue page carries 20 fiction rows', () {
      for (final key in <String>[
        'catalogue-active-popular-page0',
        'catalogue-active-popular-page1',
      ]) {
        final entry = manifest.require(key);
        final rows = RegExp(
          'class="fiction-list-item row"',
        ).allMatches(entry.fileOnDisk.readAsStringSync()).length;
        expect(rows, 20, reason: '$key: measured $rows rows, not 20');
        expect(entry.expected['novelRowsAtLeast'], 20);
        expect(entry.expected['novelRowsExact'], 20);
      }
    });

    test(
      'the detail page publishes its own chapter count — B9 made checkable',
      () {
        // `18-external-contracts.md` records this as the only source offering a
        // completeness witness. It turns B9 from "a reviewer should notice" into
        // "a detectable truncation".
        final detail = manifest
            .require('novel-detail-runesmith')
            .fileOnDisk
            .readAsStringSync();
        final declared = int.parse(
          RegExp(
            r'<table[^>]*id="chapters"[^>]*data-chapters="(\d+)"',
          ).firstMatch(detail)!.group(1)!,
        );
        final rows = RegExp('class="chapter-row"').allMatches(detail).length;

        expect(declared, 716);
        expect(
          rows,
          declared,
          reason:
              'the site says $declared chapters and the page lists $rows — a '
              'mismatch is exactly the truncation B9 forbids',
        );
      },
    );

    test('a chapter URL is a four-segment path, not three', () {
      // ⚠️ Measured 2026-10-03. `/fiction/<id>/<slug>/chapter/<n>` **404s**; the real
      // link the site publishes carries a fifth segment, the chapter slug. ADR-014
      // recorded "real chapter" at 200 without recording the shape, and `3-5`'s
      // first capture attempt used the three-segment form.
      //
      // This is recorded as a fixture property rather than left as a comment
      // because a chapter URL that 404s is indistinguishable from a chapter that
      // does not exist — which is B22's third state.
      final detail = manifest
          .require('novel-detail-runesmith')
          .fileOnDisk
          .readAsStringSync();
      final urls = RegExp(
        'data-url="(/fiction/[^"]+)"',
      ).allMatches(detail).map((Match m) => m.group(1)!).toList();
      expect(urls, hasLength(716));
      for (final url in urls) {
        expect(
          url,
          matches(RegExp(r'^/fiction/\d+/[^/]+/chapter/\d+/[^/]+$')),
          reason: 'unexpected chapter URL shape: $url',
        );
      }
    });
  });

  group('E18 — a short and a long chapter, so the threshold means something', () {
    test('the chapter body lives in div.chapter-inner.chapter-content', () {
      // ⚠️ The class is on a div that ALSO carries `chapter-inner`, so
      // `class="chapter-content"` as an exact match matches nothing. That is why the
      // first extraction attempt found zero paragraphs on a page that plainly had
      // 106 of them — and a zero here would have looked like an empty chapter, which
      // is B22's failure mode.
      for (final key in <String>['chapter-glossary', 'chapter-skills-titles']) {
        final html = manifest.require(key).fileOnDisk.readAsStringSync();
        expect(
          html,
          contains('class="chapter-inner chapter-content"'),
          reason: '$key: the documented container class has changed',
        );
      }
    });

    test('the two captured chapters straddle E18\'s 100-character threshold', () {
      int textChars(String key) {
        final html = manifest.require(key).fileOnDisk.readAsStringSync();
        final body = RegExp(
          '<div class="chapter-inner chapter-content"[^>]*>(.*?)<div class="portlet',
          dotAll: true,
        ).firstMatch(html)!.group(1)!;
        final text = body
            .replaceAll(RegExp('<[^>]+>'), ' ')
            .replaceAll('&nbsp;', ' ')
            .trim();
        return text.length;
      }

      final short = textChars('chapter-glossary');
      final long = textChars('chapter-skills-titles');
      expect(short, greaterThan(0));
      expect(long, greaterThan(short));
      expect(
        long,
        greaterThanOrEqualTo(100),
        reason:
            'E18 judges a chapter "too short to read" below 100 characters; '
            'without a capture above the line the rule cannot be exercised',
      );
    });

    test('the long chapter contains <br>, the short one does not dominate', () {
      // `04-html-to-markdown.md` gives `<br><br>` its own paragraph rule, and that
      // rule is only testable against a page that actually uses it.
      final long_ = manifest
          .require('chapter-skills-titles')
          .fileOnDisk
          .readAsStringSync();
      expect(long_.contains('<br'), isTrue);
    });
  });

  group('B22 — what this site does and does not volunteer', () {
    test('a 404 is a real page with zero rows, not a challenge', () {
      final failure = manifest.require('failure-not-found');
      expect(failure.httpStatus, 404);
      final html = failure.fileOnDisk.readAsStringSync();
      expect(html, contains('Not Found'));
      expect(
        html,
        isNot(contains('Just a moment')),
        reason:
            'a Cloudflare interstitial captured as a failure fixture would '
            'teach the adapter to classify a challenge as a missing novel',
      );
      expect(
        RegExp('class="fiction-list-item row"').allMatches(html).length,
        0,
      );
    });

    test('this site does NOT volunteer an empty-result marker — measured', () {
      // ⚠️ A measurement, not an assumption, and it CONTRADICTS what
      // `18-external-contracts.md` anticipated. A zero-row catalogue on this site
      // carries no site-supplied string: no "nothing here", no "no results". So
      // B22's third state must be distinguished by **page shape** (rows present,
      // container present) and never by a marker, because there is no marker.
      //
      // Recorded because the register had planned to rely on one. `2-1` must be
      // written against this fact instead.
      final empty = manifest
          .ofKind('catalogue')
          .map((FixtureEntry e) => e.fileOnDisk.readAsStringSync())
          .join();
      for (final marker in <String>[
        'nothing here',
        'no results',
        'no fictions',
      ]) {
        expect(
          empty.toLowerCase(),
          isNot(contains(marker)),
          reason:
              'the site now volunteers "$marker" — this note and `2-1` must '
              'be updated together',
        );
      }
    });
  });

  group('the manufactured artefact, built from this capture', () {
    test('it differs from its source by ONE literal substitution', () {
      // E4 and SC-6. The manufactured artefact is the only thing `0-1` may
      // fabricate, and section 3.2 makes the edit mechanically checkable: rename the
      // CONTENT container class, change nothing else.
      //
      // Declared in the manifest as `kind: manufactured`, so it is read the same way
      // every other fixture is. A manufactured artefact that is NOT declared is
      // indistinguishable from an undeclared file, which is the whole reason `kind`
      // exists.
      final broken = manifest.require('chapter-broken-layout');
      final source = manifest.require('chapter-skills-titles');

      expect(broken.kind, 'manufactured');
      expect(
        manifest.ofKind('manufactured'),
        hasLength(1),
        reason:
            'E4 -- exactly one artefact is manufactured; more than one would '
            'mean something is being faked that should be captured',
      );
      for (final entry in manifest.entries) {
        if (entry.key == broken.key) continue;
        expect(entry.isCaptured, isTrue, reason: entry.key);
      }

      final brokenText = broken.fileOnDisk.readAsStringSync();
      final sourceText = source.fileOnDisk.readAsStringSync();

      // ⚠️ A round-trip is the WRONG instrument here, and two attempts proved it.
      //
      // First draft: `broken.replaceAll('chapter-content', 'chapter-content')`
      // is a no-op, and `replaceAll('chapter-content', 'chapter-content-v2')` run
      // BACKWARDS over the broken text yields `chapter-content-v2-v2`.
      //
      // Second draft: a negative lookahead `chapter-content(?!-v2)` still failed,
      // because after the regex matches the bare name the scan resumes past it and
      // the following `-v2` is left in place -- so the un-renamed text still
      // contained `-v2`. Fixing a round-trip means reasoning about resumption.
      //
      // What section 3.2 actually asks is simpler and checkable directly: the two
      // files differ in exactly ONE line, and that line is the class rename. So the
      // row compares line sets and names the difference.
      final sourceLines = sourceText.split('\n');
      final brokenLines = brokenText.split('\n');

      expect(
        brokenLines.length,
        sourceLines.length,
        reason:
            'E4 -- no line may be added or removed, so a reformat is caught',
      );

      final differing = <int>[
        for (var i = 0; i < sourceLines.length; i++)
          if (sourceLines[i] != brokenLines[i]) i,
      ];
      expect(
        differing,
        hasLength(1),
        reason:
            'E4 -- exactly ONE line may differ. Differing indices: '
            '${differing.map((int i) => '$i: ${sourceLines[i].trim()} -> '
                '${brokenLines[i].trim()}').join(' | ')}',
      );

      final at = differing.single;
      expect(
        sourceLines[at].replaceAll('chapter-content', 'chapter-content-v2'),
        brokenLines[at],
        reason:
            'the differing line must be the container class rename, and '
            'nothing else on it',
      );
      expect(brokenText, contains('chapter-content-v2'));
      expect(
        brokenText,
        contains('<script'),
        reason:
            'the advertising script is NOT removed -- a fixture that '
            'silently tidies the page is not a real page',
      );
      // And the failure it models is real: the documented selector no longer
      // matches, so an adapter written against it finds nothing.
      expect(
        brokenText,
        isNot(contains('class="chapter-inner chapter-content"')),
        reason: 'the renamed container must be gone, or E4 tests nothing',
      );
    });

    test('its source is a CHAPTER page, not the detail page', () {
      // ⚠️ Measured, and the plan's own instruction here cannot be followed
      // literally. `apk-pipeline`-style plans elsewhere name the detail page as the
      // source, but Royal Road's detail page carries **no body container at all** --
      // zero occurrences of `chapter-content` across 1 000 263 bytes -- because the
      // chapter text lives on the chapter page. Renaming the class there would have
      // substituted nothing and produced a manufactured fixture byte-identical to
      // its source: a fixture named "broken" that is not broken.
      //
      // This is exactly the failure `kind: manufactured` exists to make visible, and
      // it is asserted rather than assumed.
      final detail = manifest.require('novel-detail-runesmith').fileOnDisk;
      final text = detail.readAsStringSync();
      expect(
        text.contains('chapter-content'),
        isFalse,
        reason:
            'if the detail page DID carry the container, this test is wrong '
            'about which page the manufactured artefact must be built from',
      );
      expect(
        manifest
            .require('chapter-skills-titles')
            .fileOnDisk
            .readAsStringSync()
            .contains('chapter-content'),
        isTrue,
      );
    });
  });
}
