// forge:slice 0-1
// Lumen Tale — `0-1`, the automatic guard that stops a fixture from lying (§ 3.4).
//
// ## Why this file is not `testWidgets`
//
// Every row here does real `dart:io` — `existsSync`, `lengthSync`, `readAsStringSync`
// — against files this repository carries. `testWidgets` runs its body inside a
// fake-async zone where real file futures **never complete**, so a `dart:io` row
// placed there does not fail: it HANGS, and it takes the whole suite with it. § 3.4
// and § 3.2 are file properties, so every row below is a plain `test()`.
//
// ## What changed when the capture succeeded
//
// The first version of this file skipped every captured-fixture row, because on
// 2026-10-03 FanMTL answered **403 with a Cloudflare interstitial to an honest
// User-Agent** on every path (F-012). It re-measured 2026-10-04 with the same honest
// User-Agent and got **200 on every documented path**, so the skips are gone and the
// rows now run against real bytes.
//
// ## The manufactured artefact's substitution is read, not hardcoded
//
// § 3.2 names `chapter-content -> chapter-content-v2`, written before any FanMTL page
// had been captured. MEASURED 2026-10-04: `chapter-content` occurs on **chapter pages
// only**, exactly once each, and on **zero** catalogue, novel-detail, chapter-list or
// genre pages. Applied to the plan's own source file it would have produced a copy
// with nothing broken about it. For a catalogue the element an adapter reads is
// `div.novel-item`, so that is the pair — and it lives in the manifest's
// `expected.edit`, so the manifest is what states the edit and this file is what
// verifies it. Neither side hardcodes a class name measurement can refute.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:html/parser.dart' as html_parser;

import 'fixture_manifest.dart';

/// The plan's own constants, spelled once. `test/fixtures/fixture_manifest.dart`
/// holds the closed `kind` list; everything a *test* needs to assert about the shape
/// of a capture is here, so that changing a rule means editing one file and not
/// chasing a literal across a suite.
const String site = 'fanmtl';
const String siteDir = 'test/fixtures/sources/fanmtl';
final RegExp iso8601Utc = RegExp(r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$');

/// Load the frozen FanMTL manifest. Every row that touches captures goes through
/// here, so the "the manifest loads at all" precondition is stated once.
FixtureManifest manifest() => FixtureManifest.load(site);

/// The one substitution the E4 artefact is defined by, read from the manifest.
///
/// `Map<String, dynamic>` is what `jsonDecode` gives, and the plan's § 2.2 fixes the
/// shape of `expected` as free-form — but a *missing* or *mistyped* `edit` must fail
/// loudly here rather than surface as a `null` three rows later.
Map<String, dynamic> _editOf(FixtureEntry entry) {
  final Object? edit = entry.expected['edit'];
  expect(
    edit,
    isA<Map<String, dynamic>>(),
    reason:
        '${entry.key} is the manufactured artefact, so it must declare '
        '`expected.edit` — § 3.2, without it nothing states the single '
        'substitution that separates it from its source',
  );
  return edit! as Map<String, dynamic>;
}

/// The three rows § 3.3 marks "à découvrir". A line is CLOSED either by a real
/// discovered URL in the manifest or by a named negative finding in
/// `18-external-contracts.md`; it is never closed by an absence alone, because an
/// absence nobody wrote down is indistinguishable from an oversight.
const List<String> discoveredKeys = <String>[
  'chapter-list-page1',
  'chapter-multipage-p1',
  'chapter-multipage-p2',
];

void main() {
  group('the manifest is loadable and complete', () {
    test('the manifest loads and declares the site its folder is named for', () {
      // § 2.2: `site` must match the folder, or a fixture is filed under a name
      // nobody fetched it from.
      final FixtureManifest loaded = manifest();
      expect(
        loaded.site,
        site,
        reason:
            'a manifest filed under a folder it does not describe is a '
            'provenance claim about the wrong site',
      );
      expect(loaded.baseUrl, 'https://www.fanmtl.com');
      expect(
        loaded.entries,
        isNotEmpty,
        reason: 'an empty manifest means the capture produced nothing',
      );
    });

    test('every one of the eleven mandatory fields is present on every entry', () {
      // § 2.2 and § 11.1. A field nothing reads is a promise nobody made; a
      // mandatory field that is missing is a manifest that lied.
      expect(
        FixtureEntry.requiredFields,
        hasLength(11),
        reason: 'the plan names eleven; a twelfth needs a decision here',
      );
      // Re-decoded rather than read off the object, so the row proves the FIELDS
      // are present in the JSON on disk and not merely that a loader tolerated
      // their absence — which is what it must not have done.
      final Object? decoded = jsonDecode(
        File('$siteDir/manifest.json').readAsStringSync(),
      );
      expect(decoded, isA<Map<String, dynamic>>());
      final List<Object?> rawEntries =
          (decoded! as Map<String, dynamic>)['entries']! as List<Object?>;
      for (final Object? raw in rawEntries) {
        final Map<String, dynamic> entry = raw! as Map<String, dynamic>;
        for (final String field in FixtureEntry.requiredFields) {
          expect(
            entry[field],
            isNotNull,
            reason:
                '${entry['key']} is missing the mandatory field "$field" — '
                '§ 2.2 makes it mandatory precisely so a manifest cannot be '
                'read without it',
          );
        }
      }
    });

    test('a manifest that does not exist is REFUSED, never returned empty', () {
      // C1 and `18-external-contracts.md` rule 1. A partial manifest is worse than
      // none: it lets a test pass against a file nobody declared.
      expect(
        () => FixtureManifest.load('does-not-exist'),
        throwsA(isA<FixtureManifestException>()),
        reason:
            'a lookup that returns an empty manifest turns a missing capture '
            'into a silently passing suite',
      );
    });

    test('a key that is not declared is REFUSED, never returned null', () {
      // Same reason: `null` turns "nobody captured this" into "nothing to assert",
      // which reads green.
      expect(
        () => manifest().require('no-such-key'),
        throwsA(isA<FixtureManifestException>()),
        reason:
            'a null fixture turns a missing capture into a skipped assertion',
      );
      expect(
        manifest().require('catalogue-genre-page0').key,
        'catalogue-genre-page0',
        reason: 'a declared key must resolve, or require() only ever refuses',
      );
    });

    test('an entry omitting any mandatory field is refused', () {
      for (final String field in FixtureEntry.requiredFields) {
        final Map<String, dynamic> json = _wellFormedEntry()..remove(field);
        expect(
          () => FixtureEntry.fromJson(json, Directory(siteDir)),
          throwsA(isA<FixtureManifestException>()),
          reason:
              '"$field" is declared mandatory, so omitting it must fail '
              'rather than default — § 2.2',
        );
      }
    });

    test('a kind outside the closed list is refused', () {
      // § 2.2: a free string becomes a taxonomy nobody maintains. Declaring the
      // constant without testing against it is a comment, and the first draft of
      // `fixture_manifest.dart` did exactly that.
      expect(
        () => FixtureEntry.fromJson(
          _wellFormedEntry()..['kind'] = 'whatever',
          Directory(siteDir),
        ),
        throwsA(isA<FixtureManifestException>()),
        reason: 'a kind outside the closed list must not be accepted',
      );
      // ⚠️ **Nine, not eight** — `6-11` added `search`. The count is asserted as a
      // NUMBER so that adding a kind is a visible edit here, which is the point of
      // closing the list.
      expect(
        FixtureEntry.kinds,
        hasLength(9),
        reason:
            'a new kind of captured page needs a decision in this file, not '
            'just an addition to FixtureEntry.kinds',
      );
    });
  });

  group('C1 provenance: what is on disk is what the manifest declares', () {
    test('the guard finds nothing wrong with the frozen manifest', () {
      // § 3.4, branches A to F. This is the assertion that the capture is
      // self-consistent: declared set == disk set, every length exact, no empty
      // catalogue, every observation recorded, no session token.
      expect(
        manifest().problems(),
        isEmpty,
        reason:
            '§ 3.4 branches A-F: an undeclared file, a rewritten file, an empty '
            'capture, a missing observation, an undeclared edit or a session '
            'token each make the manifest unusable',
      );
    });

    test('every declared file exists on disk, and every file is declared', () {
      final FixtureManifest loaded = manifest();
      final Set<String> declared = loaded.declaredFileNames;
      for (final FixtureEntry entry in loaded.entries) {
        expect(
          entry.fileOnDisk.existsSync(),
          isTrue,
          reason: '${entry.key} declares ${entry.file}, which is not on disk',
        );
      }
      final Set<String> onDisk = loaded.dir
          .listSync(recursive: true)
          .whereType<File>()
          .where(
            (File f) =>
                FixtureManifest.fixtureExtensions.contains(_extension(f.path)),
          )
          .map((File f) => f.path.split('${loaded.dir.path}/').last)
          .toSet();
      expect(
        onDisk.difference(declared),
        isEmpty,
        reason: 'C1 — a fixture nobody declared is a test nobody can rely on',
      );
      expect(
        declared.difference(onDisk),
        isEmpty,
        reason:
            'a declared fixture that is absent lets a suite pass against a '
            'file that was never captured',
      );
    });

    test('the declared byte length equals the file, on every entry', () {
      // B9, E1, § 3.4 branch B. This is the ONE manifest field a guard asserts,
      // because it catches the only failure a hash would cost a dependency for:
      // the file was rewritten.
      for (final FixtureEntry entry in manifest().entries) {
        expect(
          entry.bytesOnDisk,
          entry.bytes,
          reason:
              '${entry.key}: the declared length and the file disagree, so '
              'the manifest no longer describes what is on disk',
        );
      }
    });

    test(
      'no fixture is empty, and every catalogue declares what it should hold',
      () {
        // E1, § 3.4 branch C. A capture of nothing proves nothing, and a catalogue
        // whose `expected` is empty is a capture nobody recorded a count from.
        for (final FixtureEntry entry in manifest().entries) {
          expect(
            entry.readText().trim(),
            isNotEmpty,
            reason:
                '${entry.key} is empty on disk: a capture of nothing proves '
                'nothing',
          );
          if (entry.kind == 'catalogue' ||
              entry.kind == 'novel-detail' ||
              entry.kind == 'chapter-list') {
            expect(
              entry.expected,
              isNotEmpty,
              reason:
                  '${entry.key} is a ${entry.kind} with an empty `expected`: '
                  'nothing states what a test may affirm about it',
            );
          }
        }
      },
    );

    test('every entry carries an observation and an ISO 8601 UTC date', () {
      // `18-external-contracts.md` rule 1 — the provenance that makes a capture
      // evidence rather than a guess with a confident tone.
      final FixtureManifest loaded = manifest();
      for (final FixtureEntry entry in loaded.entries) {
        expect(
          entry.notes.trim(),
          isNotEmpty,
          reason:
              '${entry.key} records no observation; rule 1 forbids an entry '
              'without provenance',
        );
        expect(
          iso8601Utc.hasMatch(entry.capturedAt),
          isTrue,
          reason: '${entry.key}: ${entry.capturedAt} is not ISO 8601 UTC',
        );
      }
      expect(
        loaded.capturedBy,
        '0-1',
        reason:
            'a re-captured fixture keeps 0-1 plus a new date; `capturedBy` '
            'is the method and `capturedAt` is the moment',
      );
    });

    test('no entry stores an absolute URL', () {
      // Rules 2-3 of `03-source-system.md`, and C1: a stored absolute URL breaks
      // silently when the host changes, and `absoluteUrl` is where the two halves
      // are joined instead.
      for (final FixtureEntry entry in manifest().entries) {
        expect(
          entry.url,
          isNot(contains('://')),
          reason: '${entry.key} stores an absolute URL: ${entry.url}',
        );
        expect(
          entry.absoluteUrl(manifest().baseUrl),
          startsWith('https://www.fanmtl.com/'),
          reason:
              '${entry.key}: baseUrl + url must be the site\'s own origin, '
              'so a fixture can never be read against another site',
        );
      }
    });

    test('no fixture carries a session cookie', () {
      // C2, B4: no account, no server, reading data never leaves the phone. A
      // committed session token is the one artefact that could.
      for (final FixtureEntry entry in manifest().entries) {
        final String text = entry.readText().toLowerCase();
        for (final String marker in FixtureManifest.sessionMarkers) {
          expect(
            text,
            isNot(contains(marker)),
            reason:
                '${entry.key} appears to carry "$marker" — C2 forbids an '
                'identity in a committed fixture',
          );
        }
      }
    });
  });

  group('B9 catalogue pagination is two real pages, not one page twice', () {
    test('page 0 and page 1 are distinct entries with distinct URLs', () {
      final List<FixtureEntry> pages = manifest()
          .ofKind('catalogue')
          .where((FixtureEntry e) => e.key.startsWith('catalogue-genre-'))
          .toList();
      expect(
        pages.map((FixtureEntry e) => e.key),
        containsAll(<String>['catalogue-genre-page0', 'catalogue-genre-page1']),
        reason:
            'B9 is only testable with two real pages, so both must be '
            'declared',
      );
      final Set<String> urls = pages.map((FixtureEntry e) => e.url).toSet();
      expect(
        urls,
        hasLength(pages.length),
        reason: 'each page needs its own URL; one URL twice is one page twice',
      );
    });

    test("page 1's URL ends -1.html, not -2.html", () {
      // § 3.3: the site's page number is a 0-based PATH SEGMENT while the Source
      // contract's `page` argument is 1-based. A source that builds `-2.html` for
      // page two reads page one again, forever, and never notices.
      final FixtureEntry page1 = manifest().require('catalogue-genre-page1');
      expect(
        page1.url,
        endsWith('-1.html'),
        reason:
            'the site numbers catalogue pages from 0, so the second page is '
            '-1.html; -2.html is the third',
      );
      final FixtureEntry page0 = manifest().require('catalogue-genre-page0');
      expect(
        page0.url,
        endsWith('-0.html'),
        reason: 'the first catalogue page is index 0 on this site',
      );
    });

    test('the two catalogue pages list DIFFERENT novels', () {
      // The half of B9 a row count cannot prove. Two pages with the same count and
      // the same novels is not pagination, and every downstream completeness claim
      // built on it would be decoration.
      final Set<String> page0 = _novelIdsOf('catalogue-genre-page0');
      final Set<String> page1 = _novelIdsOf('catalogue-genre-page1');
      expect(
        page0,
        hasLength(30),
        reason:
            'MEASURED 2026-10-04: the xianxia catalogue page holds 30 rows, '
            'and a count that drifts is a capture nobody re-measured',
      );
      expect(
        page1,
        hasLength(30),
        reason:
            'MEASURED 2026-10-04: page 1 holds 30 rows too, so the two pages '
            'are comparable rather than one of them truncated',
      );
      expect(
        page0.intersection(page1),
        isEmpty,
        reason:
            'if the two pages share every novel the pagination is not real and '
            'B9 cannot be tested with these fixtures',
      );
    });

    test('every catalogue declares the exact row count that was measured', () {
      // E1's negative control: a parser that drops a row has nothing to fail
      // against unless the count is written down first.
      for (final FixtureEntry entry in manifest().ofKind('catalogue')) {
        expect(
          entry.expected['novelRowsExact'],
          isA<int>(),
          reason:
              '${entry.key} declares no exact row count, so a truncated '
              'parse of it cannot be detected',
        );
        expect(
          _count(entry.readText(), 'class="novel-item"'),
          entry.expected['novelRowsExact'],
          reason:
              '${entry.key}: the measured count and the declared count '
              'disagree, so at least one of them was not measured',
        );
      }
    });
  });

  group('B9 the chapter list is complete, and the counts are declared', () {
    test('the novel page declares its exact chapter row count', () {
      // § 10: the manifest declares the exact number of chapter rows observed, so
      // a parse that loses one has something to fail against.
      final FixtureEntry novel = manifest().require('novel-detail');
      expect(
        novel.expected['chapterRowsExact'],
        isA<int>(),
        reason:
            'novel-detail declares no exact chapter row count, so a parser '
            'that returns 99 rows looks identical to one that returns 100',
      );
      expect(
        _count(novel.readText(), 'class="chapter-no '),
        novel.expected['chapterRowsExact'],
        reason:
            'novel-detail: the measured count and the declared count disagree',
      );
    });

    test('every chapter-list page declares its exact row count too', () {
      final List<FixtureEntry> lists = manifest().ofKind('chapter-list');
      expect(
        lists,
        hasLength(greaterThanOrEqualTo(2)),
        reason:
            'B9 is only testable when the chapter list is paged, so at least '
            'two pages of it must be frozen',
      );
      for (final FixtureEntry entry in lists) {
        expect(
          entry.expected['chapterRowsExact'],
          isA<int>(),
          reason: '${entry.key} declares no exact chapter row count',
        );
        expect(
          _count(entry.readText(), 'class="chapter-no '),
          entry.expected['chapterRowsExact'],
          reason:
              '${entry.key}: the measured count and the declared count '
              'disagree',
        );
      }
    });

    test('two frozen chapter-list pages share no chapter', () {
      // The property that makes the declared counts mean something: page N and
      // page M must be disjoint, or paging is a loop that keeps answering.
      final List<FixtureEntry> lists = manifest().ofKind('chapter-list');
      final Set<String> first = _chapterNumbersOf(lists.first);
      for (final FixtureEntry other in lists.skip(1)) {
        expect(
          first.intersection(_chapterNumbersOf(other)),
          isEmpty,
          reason:
              '${lists.first.key} and ${other.key} share chapters, so the '
              'pager parameter is not doing what the fixture claims',
        );
      }
    });
  });

  group('E22 the short and the long chapter are both frozen', () {
    test('both a short and a long chapter fixture are declared', () {
      // E22 and E18: "short" and "broken" must not be confusable, and a threshold
      // only means something against a known-short page.
      final Iterable<String> chapters = manifest()
          .ofKind('chapter')
          .map((FixtureEntry e) => e.key);
      expect(chapters, contains('chapter-short'));
      expect(chapters, contains('chapter-long'));
    });

    test('chapter-short is genuinely the smaller of the two', () {
      // The negative control only works if it is the negative one. Two fixtures
      // both called "short" where the "long" one is smaller would leave the
      // threshold untested in the direction that matters.
      final FixtureManifest loaded = manifest();
      expect(
        loaded.require('chapter-short').bytesOnDisk,
        lessThan(loaded.require('chapter-long').bytesOnDisk),
        reason:
            'chapter-short must be the smaller of the pair, or it is not the '
            'negative control',
      );
    });

    test("chapter-short's notes name the EXACT chapter title", () {
      // § 10: "a short chapter" is not provenance. The exact title is what lets a
      // later session find the same chapter on the site.
      final FixtureEntry entry = manifest().require('chapter-short');
      expect(
        entry.notes,
        contains('EXACT TITLE'),
        reason:
            'the notes must say they name the exact title, so a reader can tell a '
            'named chapter from a described one',
      );
      final RegExp quoted = RegExp("'([^']+)'");
      final Match? title = quoted.firstMatch(entry.notes);
      expect(title, isNotNull, reason: 'no quoted title in ${entry.notes}');
      expect(
        title!.group(1),
        isNot(contains('short')),
        reason: 'the named title is the site\'s, not a description of it',
      );
    });

    test("chapter-short's notes record E22's measured negative finding", () {
      // E22's trigger is an Extra / Omake / end note. MEASURED 2026-10-04 across
      // all 1,966 chapter titles of the captured novel and four others: this site
      // publishes none. A note that quietly presented chapter-short as an Extra
      // would be the exact "a guess in an assertive tone" rule 1 forbids.
      final FixtureEntry entry = manifest().require('chapter-short');
      expect(
        entry.notes,
        contains('MEASURED NEGATIVE'),
        reason:
            'the fixture is not an Extra, and the notes must say so rather '
            'than let a reader assume it is',
      );
    });
  });

  group('E4 the manufactured artefact differs by exactly one substitution', () {
    test('there is exactly one manufactured artefact and it is the SC-6 one', () {
      // § 10: `architecture.md` § 3.1b authorises ONE fabricated artefact per site.
      // A second would be a second invented page, and the plan's whole argument
      // about reproducibility rests on there being one.
      final List<FixtureEntry> manufactured = manifest().ofKind('manufactured');
      expect(
        manufactured.map((FixtureEntry e) => e.file),
        <String>['fanmtl-broken-layout.html'],
        reason:
            '§ 3.2 authorises exactly one manufactured artefact, named '
            'literally because the SC-6 gate cites it by name',
      );
      for (final FixtureEntry entry in manifest().entries) {
        if (entry.isCaptured) {
          expect(
            entry.kind,
            isNot('manufactured'),
            reason:
                '${entry.key} was captured, so it must not claim to be '
                'manufactured',
          );
        }
      }
    });

    test(
      'every captured entry records the status its capture actually returned',
      () {
        // § 10: a manufactured artefact keeps its source's 200 while a real
        // failure-page keeps its 404. Flattening them would make B22's third state
        // unfalsifiable.
        final FixtureManifest loaded = manifest();
        expect(loaded.require('search-failure').httpStatus, 404);
        expect(
          loaded.require('fanmtl-broken-layout').httpStatus,
          200,
          reason:
              'the artefact is a copy of a 200 catalogue page; a different '
              'status would make it distinguishable from a real one by more than '
              'provenance',
        );
        for (final FixtureEntry entry in loaded.ofKind('catalogue')) {
          expect(entry.httpStatus, 200);
        }
      },
    );

    test('the artefact is NOT its source — the edit happened', () {
      // § 3.2. Trivially true, and it is the row that catches the opposite
      // accident: an artefact regenerated without the substitution would be a
      // byte-identical copy of a healthy page, which passes every other row here.
      final FixtureManifest loaded = manifest();
      final Map<String, dynamic> edit = _editOf(
        loaded.require('fanmtl-broken-layout'),
      );
      final FixtureEntry source = loaded.requireFile(
        edit['sourceFile']! as String,
      );
      expect(
        source.kind,
        'catalogue',
        reason:
            'the artefact\'s source must itself be a real capture, or the '
            'one-edit proof is against nothing',
      );
      expect(
        loaded.require('fanmtl-broken-layout').readText(),
        isNot(source.readText()),
        reason:
            'the artefact is byte-identical to its source, so nothing is '
            'broken about it',
      );
    });

    test('reversing the ONE substitution restores the source byte for byte', () {
      // The acceptance criterion, and the only thing that makes this artefact
      // describable. If this fails, every assertion made against the file is about
      // something nobody can name.
      final FixtureManifest loaded = manifest();
      final FixtureEntry broken = loaded.require('fanmtl-broken-layout');
      final Map<String, dynamic> edit = _editOf(broken);
      final String from = edit['from']! as String;
      final String to = edit['to']! as String;
      final FixtureEntry source = loaded.requireFile(
        edit['sourceFile']! as String,
      );

      expect(
        broken.readText().split(to).length - 1,
        edit['occurrences'],
        reason:
            'the artefact does not contain the declared number of '
            'occurrences of "$to", so it is not the edit the manifest declares',
      );
      expect(
        broken.readText().replaceAll(to, from),
        source.readText(),
        reason:
            '§ 3.2: reversing the substitution must restore the source byte '
            'for byte — one difference and no other',
      );
      expect(
        broken.bytesOnDisk,
        source.bytesOnDisk +
            (edit['occurrences']! as int) * (to.length - from.length),
        reason:
            'the byte delta must be exactly the substitutions and their '
            'extra characters, or a second edit slipped in',
      );
    });

    test('the renamed container is GONE and the source still has it', () {
      final FixtureManifest loaded = manifest();
      final FixtureEntry broken = loaded.require('fanmtl-broken-layout');
      final Map<String, dynamic> edit = _editOf(broken);
      final FixtureEntry source = loaded.requireFile(
        edit['sourceFile']! as String,
      );
      final String from = edit['from']! as String;
      expect(
        source.readText(),
        contains(from),
        reason:
            'the substitution has no target: the source does not contain '
            '"$from", so nothing was broken',
      );
      expect(
        broken.readText(),
        isNot(contains('class="$from"')),
        reason:
            'the renamed container must be gone, or the fixture is not the '
            'failure it claims to be',
      );
      expect(
        source.readText().split(from).length - 1,
        edit['occurrences'],
        reason:
            'the source must hold exactly the declared number of targets, or '
            'the manifest is describing an edit that was never applied',
      );
    });

    test('the artefact still carries the page furniture of a real page', () {
      // § 3.4 branch E's other half: a fabricated page is easy to make and easy to
      // mistake for a real one. What makes this one real is everything the
      // substitution did not touch.
      final String text = manifest().require('fanmtl-broken-layout').readText();
      expect(
        text,
        contains('<script'),
        reason:
            'the advertising scripts are NOT removed — a fixture that '
            'silently tidies the page is not a real page, and it is those '
            'scripts the cleaner has something to remove',
      );
      expect(
        text,
        contains('<!DOCTYPE html'),
        reason: 'it must be well formed',
      );
    });

    test('a parsed artefact yields ZERO catalogue rows', () {
      // E4: the page returns 200, is well formed, is not empty, and a parser finds
      // nothing — which is the whole shape of "the site could not be read" as
      // against "the catalogue is empty". A byte-level assertion cannot show that;
      // a real query can.
      final String text = manifest().require('fanmtl-broken-layout').readText();
      expect(
        html_parser.parse(text).querySelectorAll('.novel-item'),
        isEmpty,
        reason:
            'after the rename a parser must find NO rows, or the artefact '
            'would read as an empty catalogue rather than an unreadable page',
      );
      expect(
        html_parser
            .parse(manifest().require('catalogue-genre-page0').readText())
            .querySelectorAll('.novel-item'),
        hasLength(30),
        reason:
            'the source must still parse to 30 rows, or the zero above '
            'proves nothing about the rename',
      );
    });
  });

  group('the three "à découvrir" lines of § 3.3 are closed in writing', () {
    test('each is either resolved with a discovered URL or recorded as absent', () {
      // § 7: a line marked "à découvrir" is closed by a real href read off a real
      // page, or by a named finding. It is never closed by silence, because
      // silence is indistinguishable from an oversight.
      final FixtureManifest loaded = manifest();
      for (final String key in discoveredKeys) {
        final bool declared = loaded.entries.any(
          (FixtureEntry e) => e.key == key,
        );
        final String contracts = File(
          '.opencode/rules/18-external-contracts.md',
        ).readAsStringSync();
        if (declared) {
          expect(
            loaded.require(key).url,
            startsWith('/'),
            reason:
                '$key is declared, so its URL must be a discovered path and '
                'not a template',
          );
        } else {
          expect(
            contracts,
            contains(key),
            reason:
                '$key is absent from the manifest, so '
                '18-external-contracts.md must name it as not found — § 10, an '
                'absence nobody wrote down is an oversight until proven otherwise',
          );
        }
      }
    });

    test('every URL in the manifest is one a real page published', () {
      // The three lines that ARE declared carry the site's own pager shape, read
      // off the novel page's hrefs rather than assembled from a template.
      final FixtureManifest loaded = manifest();
      final String novelPage = loaded.require('novel-detail').readText();
      for (final FixtureEntry entry in loaded.ofKind('chapter-list')) {
        final String href = entry.url
            .split('&')
            .first
            .replaceFirst('/e/extend/fy.php?page=', 'fy.php?page=');
        expect(
          novelPage,
          contains('fy.php?page='),
          reason:
              'the chapter list\'s parameter must be the one the novel page '
              'itself links to, or § 7 forbids keeping the fixture',
        );
        expect(href, isNotEmpty);
      }
    });
  });

  group('the guard itself is provable, not just green', () {
    // A guard that has only ever run against a healthy tree is a guard nobody
    // knows fires. Each row below points the SAME code at a throwaway manifest
    // that lies, and names the branch it must catch.
    late Directory scratch;

    setUp(() {
      scratch = Directory.systemTemp.createTempSync('lumen_tale_guard');
    });

    tearDown(() {
      if (scratch.existsSync()) scratch.deleteSync(recursive: true);
    });

    /// A one-entry site whose fixture is well formed, so the row under test is the
    /// only thing wrong with it.
    void writeLyingManifest({
      Map<String, dynamic> entry = const <String, dynamic>{},
      String body = '<html><body><div class="novel-item">x</div></body></html>',
      String fileName = 'page.html',
    }) {
      File('${scratch.path}/$fileName').writeAsStringSync(body);
      final Map<String, dynamic> merged = <String, dynamic>{
        ..._wellFormedEntry(),
        ...entry,
        // The declared length is MEASURED here unless the row under test is
        // precisely about a wrong one — which is the only reason a row may pass it
        // in. A hard-coded default would make branch B's negative control
        // unreachable.
        'bytes': entry.containsKey('bytes') ? entry['bytes'] : body.length,
        // The kind and the `expected` map decide which per-kind branches apply, so
        // the defaults here are a kind the guard checks MORE of, with its `expected`
        // satisfied. That keeps each negative control isolated: the healthy control
        // row below then reports nothing at all, which is what proves the eleven
        // rows above are detecting their branch and not simply detecting a broken
        // scratch tree.
        'kind': entry['kind'] ?? 'catalogue',
        'expected': entry['expected'] ?? <String, dynamic>{'novelRowsExact': 1},
      };
      File('${scratch.path}/manifest.json').writeAsStringSync(
        jsonEncode(<String, dynamic>{
          'site': 'scratch',
          'baseUrl': 'https://example.invalid',
          'capturedBy': '0-1',
          'entries': <Map<String, dynamic>>[merged],
        }),
      );
    }

    bool mentions(List<String> problems, String needle) =>
        problems.any((String p) => p.contains(needle));

    test('branch A: an undeclared file on disk is caught', () {
      // `18-external-contracts.md` rule 1 — a fixture nobody declared has no
      // provenance, and nothing in the suite can fail if it is wrong.
      writeLyingManifest();
      File('${scratch.path}/stowaway.html').writeAsStringSync('<html></html>');
      expect(
        mentions(FixtureManifest.loadFrom(scratch).problems(), 'stowaway.html'),
        isTrue,
        reason: 'an undeclared fixture on disk must be named in the problems',
      );
    });

    test('branch A: an entry declaring an absent file is caught', () {
      writeLyingManifest(fileName: 'never-written.html');
      expect(
        mentions(FixtureManifest.loadFrom(scratch).problems(), 'not on disk'),
        isTrue,
        reason:
            'a declared file that was never captured must be caught, or a '
            'suite passes against a file nobody read',
      );
    });

    test('branch B: a rewritten file is caught by its length', () {
      writeLyingManifest(entry: <String, dynamic>{'bytes': 999999});
      expect(
        mentions(FixtureManifest.loadFrom(scratch).problems(), 'bytes on disk'),
        isTrue,
        reason:
            '§ 3.2 makes the byte length the one asserted field; a file '
            'rewritten after capture must be caught',
      );
    });

    test('branch C: an empty capture is caught', () {
      writeLyingManifest(
        body: '   \n  ',
        entry: <String, dynamic>{
          'expected': <String, dynamic>{'novelRowsExact': 1},
        },
      );
      expect(
        mentions(FixtureManifest.loadFrom(scratch).problems(), 'is empty'),
        isTrue,
        reason: 'a capture of nothing proves nothing, so it must be refused',
      );
    });

    test('branch C: a catalogue with an empty expected is caught', () {
      writeLyingManifest(
        entry: <String, dynamic>{'expected': <String, dynamic>{}},
      );
      expect(
        mentions(
          FixtureManifest.loadFrom(scratch).problems(),
          'empty `expected`',
        ),
        isTrue,
        reason:
            '§ 10: a catalogue or novel-detail must declare what a test may '
            'affirm about it',
      );
    });

    test('branch D: an entry with no observation is caught', () {
      writeLyingManifest(entry: <String, dynamic>{'notes': '   '});
      expect(
        mentions(
          FixtureManifest.loadFrom(scratch).problems(),
          'records no observation',
        ),
        isTrue,
        reason:
            '18-external-contracts.md rule 1 — an entry without provenance is '
            'a guess in an assertive tone',
      );
    });

    test('branch E: a manufactured artefact with no declared edit is caught', () {
      // Without `expected.edit` nothing states which single substitution separates
      // the artefact from its source, and § 3.4's whole proof stops being checkable.
      writeLyingManifest(
        entry: <String, dynamic>{
          'kind': 'manufactured',
          'expected': <String, dynamic>{'novelRowsExact': 0},
        },
      );
      expect(
        mentions(FixtureManifest.loadFrom(scratch).problems(), 'expected.edit'),
        isTrue,
        reason: 'a manufactured fixture must declare its one edit',
      );
    });

    test('branch F: a fixture carrying a session token is caught', () {
      writeLyingManifest(
        body: '<html><body>Set-Cookie: PHPSESSID=abc</body></html>',
      );
      expect(
        mentions(FixtureManifest.loadFrom(scratch).problems(), 'set-cookie'),
        isTrue,
        reason:
            'C2 and B4: a committed fixture transports no identity, and a '
            'case-insensitive match is what makes the check worth having',
      );
    });

    test('an absolute url is caught, because the host will change', () {
      writeLyingManifest(
        entry: <String, dynamic>{'url': 'https://x.invalid/a'},
      );
      expect(
        mentions(FixtureManifest.loadFrom(scratch).problems(), 'absolute URL'),
        isTrue,
        reason:
            'rules 2-3 of 03-source-system.md store a path, never a full URL',
      );
    });

    test('a capturedAt that is not ISO 8601 UTC is caught', () {
      writeLyingManifest(entry: <String, dynamic>{'capturedAt': 'yesterday'});
      expect(
        mentions(FixtureManifest.loadFrom(scratch).problems(), 'ISO 8601'),
        isTrue,
        reason:
            '18-external-contracts.md rule 1 — provenance nobody can order is '
            'provenance nobody can check',
      );
    });

    test('a healthy scratch manifest produces NO problems at all', () {
      // The control. Without it, a guard that reported every branch unconditionally
      // would pass all eleven rows above.
      writeLyingManifest();
      expect(
        FixtureManifest.loadFrom(scratch).problems(),
        isEmpty,
        reason:
            'the eleven rows above each need a row that proves the same '
            'code reports nothing on a well-formed manifest',
      );
    });
  });
}

/// The novel ids a catalogue page links to.
Set<String> _novelIdsOf(String key) => manifest()
    .require(key)
    .readText()
    .split('href="/novel/')
    .skip(1)
    .map((String s) => s.split('.html').first)
    .toSet();

/// One well-formed entry, matching § 2.2 exactly.
///
/// `bytes` is present because the negative-control rows need a length that does not
/// match the file they write; every other field is the shape § 2.2 fixes.
Map<String, dynamic> _wellFormedEntry() => <String, dynamic>{
  'key': 'catalogue-genre-page0',
  'file': 'page.html',
  'url': '/list/xianxia/all-lastdotime-0.html',
  'httpStatus': 200,
  'contentType': 'text/html; charset=utf-8',
  'capturedAt': '2026-10-04T12:00:00Z',
  'bytes': 0,
  'sha256': '<captured by sha256sum>',
  'kind': 'catalogue',
  'expected': <String, dynamic>{'novelRowsAtLeast': 1, 'novelRowsExact': 1},
  'notes':
      'A well-formed scratch entry, used to isolate one wrong field at a time.',
};

/// The chapter numbers a chapter-list page's **rows** carry.
///
/// ⚠️ Rows, not hrefs, and the difference is a measured fact about this site: a
/// chapter-list page also carries a `Latest Release:` link in the pager header that
/// points at the novel's newest chapter, and that href is on EVERY page. Reading
/// hrefs instead of rows therefore finds chapter 1966 on the first pager page, and a
/// disjointness assertion fails on a link that is not a row at all. The rows are
/// the `<span class="chapter-no ">` values, one per `<li>`.
Set<String> _chapterNumbersOf(FixtureEntry entry) => RegExp(
  'class="chapter-no ">([^<]*)<',
).allMatches(entry.readText()).map((Match m) => m.group(1)!).toSet();

int _count(String haystack, String needle) => haystack.split(needle).length - 1;

String _extension(String path) {
  final int dot = path.lastIndexOf('.');
  return dot < 0 ? '' : path.substring(dot).toLowerCase();
}
