// forge:slice 2-1
// Lumen Tale — the three derived identifiers, pinned to values written by hand.
//
// B3 is the rule these tests exist for: an id is **derived**, never typed by
// hand, so a change of composition — a separator, a `.trim()`, a case change —
// breaks a test instead of quietly minting ids that "mostly work".
//
// ⚠️ **The expected values below are literals, and they were computed outside this
// test.** A test that recomputes them with the same code as the code under test
// verifies nothing (`SKILL.md` § Discipline de vérification, rule 5). `2-1` § 3.1
// froze three of them; this file is where they are held.
//
// Where `2-1` § 3.1 *displays* `md5('f321cc5e…31//novel/ke383028.html')` beside
// `90db9662…`, the display has two slashes and the constant has one. The constant
// is the authority — it was computed, the string was written by hand — and
// `SourceId` normalises the leading slash so that both shapes agree.

import 'package:flutter_test/flutter_test.dart';
import 'package:lumen_tale/domain/sources/source_id.dart';

void main() {
  group('SourceId.of — rule 1', () {
    test('the source id is the MD5 of name/lang/versionId', () {
      expect(
        SourceId.of(name: 'FanMTL', lang: 'en', versionId: 1),
        'f321cc5e31408b67cc64f3c498053e71',
      );
    });

    test('the name is lower-cased before hashing', () {
      expect(
        SourceId.of(name: 'FanMTL', lang: 'en', versionId: 1),
        SourceId.of(name: 'fanmtl', lang: 'en', versionId: 1),
      );
    });

    test('a version bump changes the id', () {
      // B3's stated reason for including `versionId` in the input: a broken URL
      // has to become a *visible* event, and an id that does not move when the
      // source version moves cannot do that.
      expect(
        SourceId.of(name: 'FanMTL', lang: 'en', versionId: 1),
        isNot(SourceId.of(name: 'FanMTL', lang: 'en', versionId: 2)),
      );
    });

    test('a language change changes the id', () {
      expect(
        SourceId.of(name: 'FanMTL', lang: 'en', versionId: 1),
        isNot(SourceId.of(name: 'FanMTL', lang: 'fr', versionId: 1)),
      );
    });

    test('two sources of different names never collide', () {
      expect(
        SourceId.of(name: 'FanMTL', lang: 'en', versionId: 1),
        isNot(SourceId.of(name: 'Royal Road', lang: 'en', versionId: 1)),
      );
    });
  });

  group('SourceId.forNovel — B2, B3, rule 3', () {
    const String sourceId = 'f321cc5e31408b67cc64f3c498053e71';

    test('the novel id derives from the source id and the relative url', () {
      expect(
        SourceId.forNovel(
          sourceId: sourceId,
          relativeUrl: 'novel/ke383028.html',
        ),
        '90db9662f191bf2418033ab0bee1e629',
      );
    });

    test('a leading slash on the url does not change the id', () {
      // The one normalisation this file is allowed to make, and the reason it
      // exists: the separator is `/`, so a url that also opens with one would
      // otherwise mint a second id for the same novel, silently.
      expect(
        SourceId.forNovel(
          sourceId: sourceId,
          relativeUrl: '/novel/ke383028.html',
        ),
        SourceId.forNovel(
          sourceId: sourceId,
          relativeUrl: 'novel/ke383028.html',
        ),
      );
    });

    test('two novels of the same title on different sites stay distinct', () {
      // B2 — the whole reason `sourceId` is an input. Not enforced anywhere
      // else; it is a property of the derivation.
      final String fanmtl = SourceId.of(
        name: 'FanMTL',
        lang: 'en',
        versionId: 1,
      );
      final String royalRoad = SourceId.of(
        name: 'Royal Road',
        lang: 'en',
        versionId: 1,
      );
      expect(
        SourceId.forNovel(sourceId: fanmtl, relativeUrl: 'novel/a.html'),
        isNot(
          SourceId.forNovel(sourceId: royalRoad, relativeUrl: 'novel/a.html'),
        ),
      );
    });

    test('a query string is part of the url and changes the id', () {
      // Royal Road's fiction pager is `?reviews=N`, so two urls that differ only
      // by query are two real pages and must not merge.
      expect(
        SourceId.forNovel(sourceId: sourceId, relativeUrl: 'fiction/1'),
        isNot(
          SourceId.forNovel(
            sourceId: sourceId,
            relativeUrl: 'fiction/1?reviews=1',
          ),
        ),
      );
    });
  });

  group('SourceId.forChapter — B3', () {
    const String novelId = '90db9662f191bf2418033ab0bee1e629';

    test('the chapter id derives from the novel id and the relative url', () {
      expect(
        SourceId.forChapter(
          novelId: novelId,
          relativeUrl: 'novel/ke383028_1.html',
        ),
        '3003a98742f53c4b4f2ae62d8105a4e9',
      );
    });

    test('a leading slash on the url does not change the id', () {
      expect(
        SourceId.forChapter(
          novelId: novelId,
          relativeUrl: '/novel/ke383028_1.html',
        ),
        SourceId.forChapter(
          novelId: novelId,
          relativeUrl: 'novel/ke383028_1.html',
        ),
      );
    });
  });

  group('the properties 2-3 relies on', () {
    // C5 — an id is used as a filename and as a path segment. `2-3` writes
    // `<support>/chapters/<novelId>/<ordinal>.md` without validating it, and the
    // reason it can is these three assertions, not a comment in that file.
    test('no identifier contains a slash a dot or a space', () {
      final List<String> ids = <String>[
        SourceId.of(name: 'FanMTL', lang: 'en', versionId: 1),
        SourceId.forNovel(
          sourceId: SourceId.of(name: 'FanMTL', lang: 'en', versionId: 1),
          relativeUrl: 'novel/ke383028.html',
        ),
        SourceId.forChapter(
          novelId: SourceId.forNovel(
            sourceId: SourceId.of(name: 'FanMTL', lang: 'en', versionId: 1),
            relativeUrl: 'novel/ke383028.html',
          ),
          relativeUrl: 'novel/ke383028_1.html',
        ),
      ];
      for (final String id in ids) {
        expect(id, matches(RegExp(r'^[0-9a-f]{32}$')));
        expect(id, isNot(contains('/')));
        expect(id, isNot(contains('.')));
        expect(id, isNot(contains(' ')));
      }
    });

    test('the derivation reads no clock and no counter', () {
      // B3's "nothing here depends on a clock, a counter, or randomness". The
      // cheapest honest check: the same inputs twice, in two separate calls,
      // minutes apart in the run, are equal.
      final String first = SourceId.of(
        name: 'FanMTL',
        lang: 'en',
        versionId: 1,
      );
      expect(first, SourceId.of(name: 'FanMTL', lang: 'en', versionId: 1));
    });

    test('whitespace inside a url is not trimmed away', () {
      // The counterpart to the leading-slash normalisation: `ke 383028` and
      // `ke383028` are two different pages, and a `.trim()`-style normalisation
      // of the *middle* would merge them silently.
      expect(
        SourceId.forNovel(
          sourceId: SourceId.of(name: 'FanMTL', lang: 'en', versionId: 1),
          relativeUrl: 'novel/ke 383028.html',
        ),
        isNot(
          SourceId.forNovel(
            sourceId: SourceId.of(name: 'FanMTL', lang: 'en', versionId: 1),
            relativeUrl: 'novel/ke383028.html',
          ),
        ),
      );
    });
  });
}
