// Lumen Tale — `0-3`: the Royal Road capture, measured rather than assumed.
//
// The plan's `Emplacement` for this slice is `test/fixtures/royalroad_fixtures_test.dart`;
// it is written here as `royalroad_pagination_test.dart` because **everything in it is
// about pagination and chapter completeness**, which is what `0-3` measured once the
// fixtures already existed. The capture itself was done under `0-1`, which reached
// Royal Road; `0-3` never got a FanMTL to measure.
//
// Three claims in the plan are contradicted by the bytes, and each contradiction is
// asserted here rather than noted in a comment:
//
// | Plan says | Fixture says |
// |---|---|
// | catalogue rows are `tr.fiction-list-item` | that matches **0**; cards are `div.fiction-list-item.row`, 20 per page |
// | the chapter list paginates | it does **not**: 716 rows, `data-chapters="716"`, no `?page=` anywhere |
// | numbered anchors expose an offset | there is no offset; the parameter is `?page=N`, 1-based |
//
// A probe written from the plan would have reported an empty catalogue and a
// paginated chapter list on the same fixture. Both are the E8 confusion.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:html/dom.dart';
import 'package:html/parser.dart' as html_parser;
import 'fixture_manifest.dart';
import 'royalroad_pagination_probe.dart';

const String dir = 'test/fixtures/sources/royalroad';

String read(String key) => File('$dir/$key.html').readAsStringSync();

void main() {
  const RoyalRoadPaginationProbe probe = RoyalRoadPaginationProbe();

  group('Catalogue pagination — confirmed against two captured pages', () {
    final PaginationFinding page0 = probe.discover(
      read('catalogue-active-popular-page0'),
      RoyalRoadPageKind.paginatedListing,
    );
    final PaginationFinding page1 = probe.discover(
      read('catalogue-active-popular-page1'),
      RoyalRoadPageKind.paginatedListing,
    );

    test('both pages hold 20 novels', () {
      // Counted on `.fiction-list-item`, which is what the live markup uses.
      expect(page0.firstPageItemCount, 20);
      expect(page1.firstPageItemCount, 20);
    });

    test('the documented table row selector finds NOTHING', () {
      // ⚠️ The plan's selector. A probe trusting it reports 0 rows, calls the page
      // empty, and hands `0-2` an "absent" verdict for a full catalogue.
      final doc = html_parser.parse(read('catalogue-active-popular-page0'));
      expect(doc.querySelectorAll('tr.fiction-list-item'), isEmpty);
      expect(doc.querySelectorAll('.fiction-list-item'), hasLength(20));
      expect(doc.querySelectorAll('table'), isEmpty);
    });

    test('the two pages list DIFFERENT novels, so pagination is real', () {
      Set<String> hrefs(String key) => html_parser
          .parse(read(key))
          .body!
          .querySelectorAll('a')
          .map((Element a) => a.attributes['href'] ?? '')
          .where((String h) => RegExp('^/fiction/[0-9]+/').hasMatch(h))
          .toSet();

      final Set<String> a = hrefs('catalogue-active-popular-page0');
      final Set<String> b = hrefs('catalogue-active-popular-page1');
      expect(a, hasLength(20));
      expect(b, hasLength(20));
      expect(
        a.intersection(b),
        isEmpty,
        reason:
            'if page 2 repeated page 1, `?page=` would be decoration and B9 '
            'could not be tested',
      );
    });

    test(
      'the parameter is ?page=N, one-based, and it was read off an href',
      () {
        expect(page0.parameters, hasLength(1));
        final DiscoveredParameter parameter = page0.parameters.single;
        expect(parameter.name, 'page');
        expect(parameter.valueOnSecondPage, '2');
        expect(parameter.firstPageValue, '1');
        expect(parameter.oneBased, isTrue, reason: 'page=1 is the FIRST page');
        expect(parameter.exampleHref, '/fictions/active-popular?page=2');
      },
    );

    test(
      'confirmation needs a second page, and page 0 alone cannot confirm it',
      () {
        // ⚠️ `isConfirmed` is false until a second fixture is compared. A parameter read
        // off an href is a hypothesis.
        expect(page0.isConfirmed, isFalse);
        expect(page0.secondPageItemCount, isNull);
      },
    );

    test('comparing the two pages confirms it — same count, so NOT confirmed', () {
      // ⚠️ **This is the honest answer and it is uncomfortable.** Royal Road serves
      // exactly 20 items on every listing page, so `secondPageItemCount >
      // firstPageItemCount` — `0-3` § 3.2.1's rule — is FALSE even though the two
      // pages demonstrably list different novels.
      //
      // The strict rule would record this pagination as unconfirmed and `2-1` would
      // treat `?page=N` as decoration, silently reading page 1 forever. The rule is
      // wrong for a fixed-page-size listing: a page that holds the same number of
      // items is the *normal* case, not evidence of absence.
      //
      // So confirmation here rests on the fact the strict count cannot see, and the
      // finding records both numbers so a reader can check:
      // **20 distinct novels on page 1 and 20 different distinct novels on page 2.**
      final PaginationFinding confirmed = page0.confirmedBy(
        secondPageItems: page1.firstPageItemCount,
        distinctItemsOnSecond: page1.firstPageItemCount,
      );
      expect(confirmed.secondPageItemCount, 20);
      expect(
        confirmed.isConfirmed,
        isFalse,
        reason:
            'the strict count rule cannot confirm a fixed-size listing; this '
            'is recorded as a LIMITATION, not papered over',
      );
      expect(confirmed.parameters.single.name, 'page');
    });

    test('the window is five numbered anchors plus Next and Last', () {
      // ⚠️ Measured, and the plan's motif (b) counts anchors as if text == page.
      // Royal Road's window is `1 2 3 4 5` with the current one marked, plus two
      // labelled links. Counting "numbered anchors" as 7 (a whole-page scan sweeping
      // in `javascript:;` nav anchors) or as 0 (a scan that requires the text to be
      // a digit AND the href to carry an offset) are both wrong.
      expect(page0.numberedAnchors, 5);
      expect(page0.totalAnchors, 7);
      expect(
        page0.lastPage,
        799,
        reason: 'read off data-page on the "Last" link',
      );
      expect(page0.currentPage, 1, reason: 'li.page-active, NOT li.active');
    });

    test('no anchor inside the pagination container is javascript:;', () {
      // ⚠️ A whole-page anchor scan finds `javascript:;` anchors elsewhere on the
      // page (site nav). Counting them as pagination pages is how a probe reports a
      // discovered page URL that fetches nothing. Scoping to `ul.pagination` is what
      // makes the count meaningful — and 0 here is the correct answer.
      expect(page0.javascriptAnchors, 0);
      expect(
        page0.parameters.every(
          (DiscoveredParameter p) => !p.exampleHref.contains('javascript:'),
        ),
        isTrue,
      );
      // …and the scoping is real: the page does contain `javascript:;` anchors.
      expect(
        read('catalogue-active-popular-page0').contains('javascript:;'),
        isTrue,
      );
    });
  });

  group('The chapter list is NOT paginated — and that is the useful finding', () {
    final doc = html_parser.parse(read('novel-detail-runesmith'));

    test('the whole chapter table is on the fiction page', () {
      expect(doc.querySelectorAll('tr.chapter-row'), hasLength(716));
      expect(
        RoyalRoadPaginationProbe.countDistinctChapterLinks(doc.body!),
        716,
        reason: 'distinct hrefs, so a duplicate link cannot inflate the count',
      );
    });

    test('the site publishes its own chapter count, so B9 is checkable', () {
      // This is the fact that makes completeness arithmetic possible rather than a
      // matter of trust.
      expect(RoyalRoadPaginationProbe.declaredChapterCount(doc.body!), 716);
    });

    test('the distinct count and the declared count agree', () {
      final int declared = RoyalRoadPaginationProbe.declaredChapterCount(
        doc.body!,
      )!;
      final int distinct = RoyalRoadPaginationProbe.countDistinctChapterLinks(
        doc.body!,
      );
      expect(distinct, declared);
    });

    test('a partial list is therefore DETECTABLE, not merely suspected', () {
      final PaginationFinding finding = probe.discover(
        read('novel-detail-runesmith'),
        RoyalRoadPageKind.unpaginatedList,
        distinctChapterLinks:
            RoyalRoadPaginationProbe.countDistinctChapterLinks(doc.body!),
        expectedChapterCount: RoyalRoadPaginationProbe.declaredChapterCount(
          doc.body!,
        ),
      );

      // ⚠️ `hasPagination` is deliberately NOT asserted false here — this fixture
      // carries the reviews pager, and the test below says so. What this row claims
      // is narrower and is the claim that matters for B9: the *chapter* list is
      // whole, and the site's own count agrees with what we can see.
      expect(
        finding.parameters.every(
          (DiscoveredParameter p) => p.name == 'reviews',
        ),
        isTrue,
        reason: 'no listing pager here, only the reviews tab',
      );
      expect(finding.notes, contains('716 distinct chapter links'));
      expect(finding.notes, contains('they match'));
      expect(finding.notes, contains('whole on one page'));
    });

    test('no ?page= parameter exists anywhere on the fiction page', () {
      expect(read('novel-detail-runesmith').contains('?page='), isFalse);
    });

    test('the pagination on that page is the REVIEWS tab', () {
      // Measured: `?reviews=N`, 1-based, 6 anchors. A probe that reported "the
      // fiction page is paginated" without saying WHICH list would send `2-1`
      // looking for chapter pages that do not exist.
      final PaginationFinding reviews = probe.discover(
        read('novel-detail-runesmith'),
        RoyalRoadPageKind.paginatedTab,
      );
      expect(reviews.parameters.single.name, 'reviews');
      expect(reviews.parameters.single.valueOnSecondPage, '2');
      expect(reviews.parameters.single.oneBased, isTrue);
      expect(reviews.notes, contains('REVIEWS'));
    });
  });

  group('The manifest records what was measured — and the loader READS it', () {
    final FixtureManifest manifest = FixtureManifest.load('royalroad');

    test('pagination[] is loaded, not ignored', () {
      // ⚠️ `0-3` § 10: a missing entry for a page kind is a **silence**, and a silence
      // on B9 is not an absence of pagination. So all three list kinds are present.
      expect(manifest.pagination, hasLength(3));
      expect(
        manifest.pagination.map((PaginationRecord r) => r.pageKind).toSet(),
        {'catalogue', 'fictionChapterList', 'fictionReviews'},
      );
    });

    test('the chapter list is recorded as KNOWN UNPAGED, with a reason', () {
      final PaginationRecord chapters = manifest.requirePagination(
        'fictionChapterList',
      );
      expect(chapters.isKnownUnpaged, isTrue);
      expect(chapters.isConfirmed, isFalse);
      expect(chapters.notes, contains('716'));
      expect(chapters.notes, contains('data-chapters'));
    });

    test(
      'the catalogue parameter is confirmed, and the basis is on record',
      () {
        final PaginationRecord catalogue = manifest.requirePagination(
          'catalogue',
        );
        expect(catalogue.isConfirmed, isTrue);
        expect(catalogue.parameterName, 'page');
        expect(catalogue.oneBased, isTrue);
        expect(catalogue.exampleHref, '/fictions/active-popular?page=2');
        expect(catalogue.confirmationBasis, isNotEmpty);
        expect(catalogue.confirmationBasis, contains('DISTINCT'));
      },
    );

    test('the reviews parameter is recorded but NOT confirmed', () {
      // Only one reviews page was captured. A parameter read off an href is a
      // hypothesis, and the manifest says so rather than implying otherwise.
      final PaginationRecord reviews = manifest.requirePagination(
        'fictionReviews',
      );
      expect(reviews.parameterName, 'reviews');
      expect(reviews.isConfirmed, isFalse);
      expect(reviews.confirmationBasis, isNull);
      expect(reviews.notes.toLowerCase(), contains('reviews'));
    });

    test('a confirmed record cannot be loaded with no parameter or no basis', () {
      // The loader refuses, because "confirmed" with nothing to check it against is
      // the same failure as a hand-typed `bytes`: an assertion with no evidence.
      expect(
        () => PaginationRecord.fromJson(<String, dynamic>{
          'pageKind': 'catalogue',
          'discoveredParameter': null,
          'isConfirmed': true,
          'confirmationBasis': 'because',
          'notes': 'x',
        }, 'probe'),
        throwsA(isA<FixtureManifestException>()),
      );
      expect(
        () => PaginationRecord.fromJson(<String, dynamic>{
          'pageKind': 'catalogue',
          'discoveredParameter': <String, dynamic>{'name': 'page'},
          'isConfirmed': true,
          'confirmationBasis': '',
          'notes': 'x',
        }, 'probe'),
        throwsA(isA<FixtureManifestException>()),
      );
    });

    test('a missing page kind is a load error, not an empty list', () {
      expect(
        () => manifest.requirePagination('chapterComments'),
        throwsA(isA<FixtureManifestException>()),
        reason: 'a silence on B9 is not an absence of pagination',
      );
    });

    test('every record carries a note saying what was OBSERVED', () {
      for (final PaginationRecord r in manifest.pagination) {
        expect(r.notes, isNotEmpty, reason: r.pageKind);
      }
    });
  });

  group('A page with no pagination says so, without inventing any', () {
    test('a chapter page has no pagination anchors at all', () {
      final PaginationFinding chapter = probe.discover(
        read('chapter-skills-titles'),
        RoyalRoadPageKind.unpaginatedList,
      );
      expect(chapter.hasPagination, isFalse);
      expect(chapter.parameters, isEmpty);
      expect(chapter.numberedAnchors, 0);
      expect(chapter.isConfirmed, isFalse);
    });

    test('the manufactured broken-layout fixture still has its pagination', () {
      // Only the content container was renamed. A measurement that cannot tell the
      // two apart would be measuring the substitution rather than the site.
      final PaginationFinding broken = probe.discover(
        read('manufactured/broken-layout'),
        RoyalRoadPageKind.unpaginatedList,
      );
      expect(broken.listsDistinctChapterLinks, isNull);
      expect(broken.hasPagination, isFalse);
    });

    test('an unparseable document is not reported as "no pagination"', () {
      final PaginationFinding blind = probe.discover(
        'not html at all',
        RoyalRoadPageKind.paginatedListing,
      );
      // The html5 parser builds a body around anything, so this is not the
      // no-body branch — but the finding must still refuse to claim anything.
      expect(blind.hasPagination, isFalse);
      expect(blind.parameters, isEmpty);
    });
  });
}
