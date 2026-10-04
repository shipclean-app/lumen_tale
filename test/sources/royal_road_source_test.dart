// Lumen Tale — `2-1`'s source, against the **frozen** captures.
//
// `03-source-system.md` rule 12: parsing unit tests ship with fixture HTML. Every row
// below runs the same `classify*` methods the network path runs, so a selector that works
// here works in the app — and a selector that works here and not against the live site is
// a bug in the capture, not in the source.
//
// ## The four rows that would have been wrong, restated as rows
//
//   the catalogue row carries **no author** · the author is under **`/profile/`**, not
//   `/author/` · the rating is in the **`title` attribute** of the `fa-star` span ·
//   **`tr.fiction-list-item` matches zero**.
//
// Each is a row below, and each has a sabotage that breaks it.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumen_tale/core/error/source_failure.dart';
import 'package:lumen_tale/core/network/fetch_result.dart';
import 'package:lumen_tale/core/network/http_client.dart';
import 'package:lumen_tale/core/network/http_response.dart';
import 'package:lumen_tale/domain/sources/browse_outcome.dart';
import 'package:lumen_tale/domain/sources/models/chapter.dart';
import 'package:lumen_tale/domain/sources/models/novel.dart';
import 'package:lumen_tale/domain/sources/models/novels_page.dart';
import 'package:lumen_tale/domain/sources/source.dart';
import 'package:lumen_tale/domain/sources/source_id.dart';
import 'package:lumen_tale/sources/implementations/royal_road_source.dart';
import 'package:lumen_tale/sources/implementations/source_registry.dart';

/// A capture, read once.
String fixture(String name) =>
    File('test/fixtures/sources/royalroad/$name').readAsStringSync();

/// A 200 with the fixture's body.
HttpResponse page(String name) => HttpResponse(
  outcome: const FetchSucceeded(status: 200),
  status: 200,
  body: fixture(name),
  contentType: 'text/html; charset=utf-8',
);

/// An `HttpClient` that never runs: every test here drives the classify half directly,
/// so a fetch would be a second code path with a second answer.
final class UnusedClient implements HttpClient {
  @override
  Future<HttpResponse> get(String relativePath, {Map<String, String>? query}) {
    throw StateError(
      'no test in this file may fetch: the fixtures are the site',
    );
  }

  @override
  Uri resolve(String relativePath) => Uri.parse(relativePath);
}

RoyalRoadSource source() => RoyalRoadSource(client: UnusedClient());

/// The novel the detail capture is of, as the catalogue would have produced it.
Novel runesmith() => Novel(
  id: SourceId.forNovel(
    sourceId: source().id,
    relativeUrl: '/fiction/33844/the-runesmith',
  ),
  sourceId: source().id,
  url: '/fiction/33844/the-runesmith',
  title: 'The Runesmith',
  author: null,
  description: null,
  status: NovelStatus.unknown,
  coverUrl: null,
  genres: const <String>[],
);

void main() {
  group('the catalogue', () {
    test('page 1 yields exactly 20 novels, as the manifest records', () {
      final BrowseOutcome<NovelsPage> outcome = source().classifyCatalogue(
        response: page('catalogue-active-popular-page0.html'),
        path: '/fictions/active-popular',
        requestedPage: 1,
      );
      expect(outcome, isA<BrowseSucceeded<NovelsPage>>());
      expect(
        (outcome as BrowseSucceeded<NovelsPage>).items.single.novels,
        hasLength(20),
      );
    });

    test('the two pages share no novel, so ?page=N is really pagination', () {
      // The measurement that distinguishes "20 rows per page" from "20 rows, always".
      final Set<String> page1 = _novelUrls(
        'catalogue-active-popular-page0.html',
      );
      final Set<String> page2 = _novelUrls(
        'catalogue-active-popular-page1.html',
      );
      expect(page1, hasLength(20));
      expect(page2, hasLength(20));
      expect(page1.intersection(page2), isEmpty);
    });

    test(
      'every novel id is the MD5 of its own derivation, never hand-written',
      () {
        for (final Novel novel in _novels(
          'catalogue-active-popular-page0.html',
        )) {
          expect(
            novel.id,
            SourceId.forNovel(sourceId: source().id, relativeUrl: novel.url),
            reason: novel.title,
          );
        }
      },
    );

    test('the source id is the MD5 of name/lang/version', () {
      final HttpSource s = source();
      expect(
        s.id,
        SourceId.of(name: s.name, lang: s.lang, versionId: s.versionId),
      );
      expect(s.lang, 'en');
      expect(
        s.baseUrl.endsWith('/'),
        isFalse,
        reason: '03-source-system.md rule 2',
      );
    });

    test('⚠️ the catalogue row carries NO author, and none is invented', () {
      // Measured: a row holds cover `img`, `h2.fiction-title > a`, the tags block,
      // `div.row.stats` and `div#description-<id>` — and nothing that names the author.
      // `Novel.author` is `String?` and stays null. Filling it from the slug would
      // fabricate B10 verbatim site text.
      for (final Novel novel in _novels(
        'catalogue-active-popular-page0.html',
      )) {
        expect(
          novel.author,
          isNull,
          reason: '${novel.title} was given an author the site did not publish',
        );
      }
    });

    test(
      '⚠️ the rating comes from the title attribute, not from the span text',
      () {
        // The `fa-star` span's own text is EMPTY and the number is its `title`. The naive
        // read reports 0 for a fiction rated 4.73.
        final Novel novel = _novels(
          'catalogue-active-popular-page1.html',
        ).firstWhere((Novel n) => n.url.startsWith('/fiction/21322/'));
        expect(novel.memo['royalRoad.rating'], 4.73);
      },
    );

    test(
      '⚠️ tr.fiction-list-item matches nothing, and the page has no table',
      () {
        // The cross-site shape every other source uses is the one that does not match here.
        final String body = fixture('catalogue-active-popular-page0.html');
        expect(body.contains('tr class="fiction-list-item'), isFalse);
        expect(body.contains('<table'), isFalse);
        expect(body.contains('div class="fiction-list-item row"'), isTrue);
      },
    );

    test('the description is joined on the row\'s OWN novel id', () {
      final Novel novel = _novels(
        'catalogue-active-popular-page1.html',
      ).firstWhere((Novel n) => n.url.startsWith('/fiction/21322/'));
      expect(novel.description, contains('MRI mishap'));
    });

    test(
      'a page with no container is SourceLayoutChanged, NOT an empty list',
      () {
        // B22 / SC-6 on a site with **no empty marker**: page shape is the only
        // discriminator available, and this site publishes none.
        final BrowseOutcome<NovelsPage> outcome = source().classifyCatalogue(
          response: const HttpResponse(
            outcome: FetchSucceeded(status: 200),
            status: 200,
            body:
                '<html><body><div class="something-else">hi</div></body></html>',
            contentType: 'text/html',
          ),
          path: '/fictions/active-popular',
          requestedPage: 1,
        );
        expect(outcome, isA<BrowseFailed<NovelsPage>>());
        expect(
          (outcome as BrowseFailed<NovelsPage>).reason,
          isA<SourceLayoutChanged>(),
        );
        expect(outcome.retriable, isFalse);
      },
    );

    test('a container with zero rows is ALSO SourceLayoutChanged here', () {
      // ⚠️ **And this is the uncomfortable one.** With no site-supplied signal,
      // `ZeroItemsPolicy.zeroIsBroken` means an empty-but-intact catalogue cannot be
      // reported as "no results" — B22 says the discriminator is the site's own signal,
      // and this site publishes none. Reporting it as broken is the correct answer under
      // the rule, and it is recorded rather than worked around.
      final BrowseOutcome<NovelsPage> outcome = source().classifyCatalogue(
        response: const HttpResponse(
          outcome: FetchSucceeded(status: 200),
          status: 200,
          body:
              '<html><body><div class="fiction-list" id="result"></div></body></html>',
          contentType: 'text/html',
        ),
        path: '/fictions/active-popular',
        requestedPage: 1,
      );
      expect(outcome, isA<BrowseFailed<NovelsPage>>());
    });

    test('a transport failure is NoConnection and is retriable', () {
      final BrowseOutcome<NovelsPage> outcome = source().classifyCatalogue(
        response: const HttpResponse(
          outcome: FetchTransportFailed(host: 'www.royalroad.com'),
          status: 0,
          body: '',
          contentType: null,
        ),
        path: '/fictions/active-popular',
        requestedPage: 1,
      );
      expect((outcome as BrowseFailed<NovelsPage>).reason, isA<NoConnection>());
      expect(outcome.retriable, isTrue);
    });

    test('a 404 is SourceUnavailable, not an empty page', () {
      final BrowseOutcome<NovelsPage> outcome = source().classifyCatalogue(
        response: const HttpResponse(
          outcome: FetchSucceeded(status: 404),
          status: 404,
          body: '<html><body>Not Found</body></html>',
          contentType: 'text/html',
        ),
        path: '/fictions/active-popular',
        requestedPage: 99,
      );
      expect(
        (outcome as BrowseFailed<NovelsPage>).reason,
        isA<SourceUnavailable>(),
      );
    });
  });

  group('the chapter list — B9, with the site\'s own witness', () {
    test('the capture has 716 rows and publishes data-chapters="716"', () {
      final BrowseOutcome<List<Chapter>> outcome = source().classifyChapterList(
        response: page('novel-detail-runesmith.html'),
        novel: runesmith(),
      );
      expect(outcome, isA<BrowseSucceeded<List<Chapter>>>());
      expect(
        (outcome as BrowseSucceeded<List<Chapter>>).items.single,
        hasLength(716),
      );
    });

    test('every chapter id is the MD5 of its own derivation', () {
      for (final Chapter chapter in _chapters('novel-detail-runesmith.html')) {
        expect(
          chapter.id,
          SourceId.forChapter(
            novelId: runesmith().id,
            relativeUrl: chapter.url,
          ),
        );
      }
    });

    test('⚠️ the order is the TABLE order, and it is NOT ascending by number', () {
      // ⚠️ **This row exists because it FAILED with the opposite expectation.**
      //
      // The capture's first three numbers are `526587`, `568159`, `520102` — measured,
      // and **not ascending**. Royal Road orders its chapter table by publication date,
      // not by chapter number, so a source that sorted by number, or renumbered rows
      // `1, 2, 3…`, would produce an order the site never published. That is B9 broken with
      // no error anywhere: every chapter is present and the list is still wrong.
      //
      // The capture's FIRST row is a glossary (`data-content="0"`), so renumbering would
      // also silently claim the glossary is chapter 1.
      final List<Chapter> chapters = _chapters('novel-detail-runesmith.html');
      expect(chapters.first.url, contains('/chapter/526587/'));
      expect(chapters.map((Chapter c) => c.url).toSet(), hasLength(716));

      final List<double> first = chapters
          .take(3)
          .map((Chapter c) => c.number)
          .toList();
      expect(first, <double>[526587, 568159, 520102]);
      expect(
        first,
        isNot(orderedEquals(<double>[...first]..sort())),
        reason:
            'if this ever becomes ascending, the site changed its order and this row '
            'must be re-measured rather than deleted',
      );
    });

    test(
      '⚠️ a truncated table is reported, never padded and never returned short',
      () {
        // The site publishes its own count, so B9 is **mechanically checkable** instead of
        // asserted. This is the only source so far that offers a completeness witness.
        final String body = fixture('novel-detail-runesmith.html');
        final String truncated = body.replaceFirst(
          'data-chapters="716"',
          'data-chapters="999"',
        );
        final BrowseOutcome<List<Chapter>> outcome = source()
            .classifyChapterList(
              response: HttpResponse(
                outcome: const FetchSucceeded(status: 200),
                status: 200,
                body: truncated,
                contentType: 'text/html',
              ),
              novel: runesmith(),
            );
        expect(outcome, isA<BrowseFailed<List<Chapter>>>());
        expect(
          (outcome as BrowseFailed<List<Chapter>>).reason,
          isA<SourceLayoutChanged>(),
          reason:
              'a short list returned as the whole one is B9 broken with no error',
        );
      },
    );

    test('a fiction page with no chapter table is SourceLayoutChanged', () {
      final BrowseOutcome<List<Chapter>> outcome = source().classifyChapterList(
        response: const HttpResponse(
          outcome: FetchSucceeded(status: 200),
          status: 200,
          body: '<html><body><h1>No chapters here</h1></body></html>',
          contentType: 'text/html',
        ),
        novel: runesmith(),
      );
      expect(outcome, isA<BrowseFailed<List<Chapter>>>());
    });
  });

  group('the chapter body', () {
    test('the body comes from div.chapter-inner.chapter-content', () {
      // ⚠️ **An exact `class="chapter-content"` match finds NOTHING** on a page carrying
      // 106 paragraphs, because the class sits on a div that also carries
      // `chapter-inner`. This is the selector mistake that turns every chapter into
      // `SourceLayoutChanged`, and it is invisible until a reader opens one.
      final BrowseOutcome<String> outcome = source().classifyChapterContent(
        response: page('chapter-glossary.html'),
        chapter: _firstChapter(),
      );
      expect(outcome, isA<BrowseSucceeded<String>>());
      final String html = (outcome as BrowseSucceeded<String>).items.single;
      expect(html, isNotEmpty);
      expect(html.length, greaterThan(500));
    });

    test(
      '⚠️ an exact class="chapter-content" match really does find nothing',
      () {
        // The negative control for the row above, on the same bytes.
        final String body = fixture('chapter-glossary.html');
        expect(body.contains('class="chapter-content"'), isFalse);
        expect(body.contains('chapter-inner'), isTrue);
        expect(
          body.contains('chapter-content'),
          isTrue,
          reason:
              'the class is present, on a div that ALSO carries chapter-inner',
        );
      },
    );

    test('a chapter page with no body container is SourceLayoutChanged', () {
      final BrowseOutcome<String> outcome = source().classifyChapterContent(
        response: const HttpResponse(
          outcome: FetchSucceeded(status: 200),
          status: 200,
          body:
              '<html><body><div class="chapter-inner">nope</div></body></html>',
          contentType: 'text/html',
        ),
        chapter: _firstChapter(),
      );
      expect(outcome, isA<BrowseFailed<String>>());
      expect(
        (outcome as BrowseFailed<String>).reason,
        isA<SourceLayoutChanged>(),
      );
    });

    test('a present-but-empty container is NOT a failure', () {
      // The container IS the element being looked for; a chapter the site published with
      // nothing in it is the site's statement, and inventing a failure for it would be
      // the app overruling the site.
      final BrowseOutcome<String> outcome = source().classifyChapterContent(
        response: const HttpResponse(
          outcome: FetchSucceeded(status: 200),
          status: 200,
          body:
              '<html><body><div class="chapter-inner chapter-content"></div></body></html>',
          contentType: 'text/html',
        ),
        chapter: _firstChapter(),
      );
      expect(outcome, isA<BrowseSucceeded<String>>());
    });
  });

  group('the novel detail page', () {
    test('⚠️ the author is under /profile/, and /author/ matches nothing', () {
      // The shape every other source uses would parse null here — and under
      // `zeroIsBroken` that would report a healthy novel as a broken one.
      final String body = fixture('novel-detail-runesmith.html');
      expect(body.contains('href="/profile/143496"'), isTrue);
      expect(body.contains('href="/author/'), isFalse);

      final BrowseOutcome<Novel> outcome = source().classifyDetails(
        response: page('novel-detail-runesmith.html'),
        novel: runesmith(),
      );
      final Novel novel = (outcome as BrowseSucceeded<Novel>).items.single;
      expect(novel.author, 'Kuropon');
      expect(novel.title, 'The Runesmith');
      expect(novel.initialized, isTrue);
    });

    test('a page with no h1 is SourceLayoutChanged', () {
      final BrowseOutcome<Novel> outcome = source().classifyDetails(
        response: const HttpResponse(
          outcome: FetchSucceeded(status: 200),
          status: 200,
          body: '<html><body><div>nothing I look for</div></body></html>',
          contentType: 'text/html',
        ),
        novel: runesmith(),
      );
      expect(outcome, isA<BrowseFailed<Novel>>());
    });
  });

  group('the registry', () {
    test('it ships Royal Road and nothing that cannot be read', () {
      final List<Source> sources = buildSourceRegistry(UnusedClient());
      expect(sources, hasLength(1));
      expect(sources.single, isA<RoyalRoadSource>());
      // ⚠️ **FanMTL and Novel Fire are absent by decision.** FanMTL answers 403 with a
      // Cloudflare challenge (ADR-014 rejected impersonation, no bypass will be built);
      // Novel Fire is UNMEASURED, and registering it would claim a measurement nobody
      // took.
      expect(sources.where((Source s) => s.name.contains('FanMTL')), isEmpty);
      expect(
        sources.where((Source s) => s.name.contains('Novel Fire')),
        isEmpty,
      );
    });

    test(
      'supportsSearch is true, and it was MEASURED rather than asserted',
      () {
        expect(source().supportsSearch, isTrue);
      },
    );

    test(
      'a source with no filters declares an empty list, not invented values',
      () {
        // B41: the platform never interprets a source's filter states, so inventing
        // FilterValues would be inventing a filter the site does not offer.
        expect(source().filterList, isEmpty);
      },
    );
  });
}

List<Novel> _novels(String fixtureName) {
  final BrowseOutcome<NovelsPage> outcome = source().classifyCatalogue(
    response: page(fixtureName),
    path: '/fictions/active-popular',
    requestedPage: 1,
  );
  return (outcome as BrowseSucceeded<NovelsPage>).items.single.novels;
}

Set<String> _novelUrls(String fixtureName) => <String>{
  for (final Novel n in _novels(fixtureName)) n.url,
};

List<Chapter> _chapters(String fixtureName) {
  final BrowseOutcome<List<Chapter>> outcome = source().classifyChapterList(
    response: page(fixtureName),
    novel: runesmith(),
  );
  return (outcome as BrowseSucceeded<List<Chapter>>).items.single;
}

Chapter _firstChapter() => Chapter(
  id: SourceId.forChapter(
    novelId: runesmith().id,
    relativeUrl:
        '/fiction/33844/the-runesmith/chapter/526587/glossary-of-terms',
  ),
  novelId: runesmith().id,
  url: '/fiction/33844/the-runesmith/chapter/526587/glossary-of-terms',
  name: 'Glossary of terms',
  number: 526587,
);
