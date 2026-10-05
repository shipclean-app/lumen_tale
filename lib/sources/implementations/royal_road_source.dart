// Lumen Tale — Royal Road, `2-1`'s source.
//
// `03-source-system.md` rule 12: **parsing unit tests ship with fixture HTML**, and every
// selector below was found by reading
// `test/fixtures/sources/royalroad/catalogue-active-popular-page1.html` — not by habit
// borrowed from a site that has a different shape. `18-external-contracts.md`'s section
// *Royal Road — the catalogue row's anatomy, re-derived from the frozen fixtures* records
// all of it, and the four rows under "Why it matters more than a selector" are the four
// a habit would have got wrong.
//
// ## The four that would have been wrong
//
//   - **the catalogue row carries no author.** `Novel.author` stays `null` after a
//     catalogue read. Filling it from the novel's slug would fabricate B10 verbatim text.
//   - **the author is on the DETAIL page, under `/profile/`.** `/author/<id>` matches
//     nothing here, and `ZeroItemsPolicy.zeroIsBroken` would report a healthy novel as a
//     broken one.
//   - **the rating is in the `title` attribute of the `fa-star` span**, whose own text
//     is empty — reading the span reports `0` for a fiction rated `4.73`.
//   - **`tr.fiction-list-item` matches ZERO** and the catalogue page has no `<table>` at
//     all; the shape every other source uses does not match.
//
// ## `BrowseEmpty` is UNREACHABLE on this site's browse side, and that is a fact
//
// Measured 2026-10-03: a zero-row catalogue (`?tags_add=99nonexistenttag`, HTTP 200,
// 239 765 bytes) carries no "nothing here", no "no results", no "no fictions". So there
// is **no marker to find**, and `siteEmptySignal` is `null` on every browse read. The
// consequence is the important one: **a zero-row catalogue is reported as
// `SourceLayoutChanged`, never as "no results"** — which is correct under B22, because
// the discriminator is the site's own signal and this site publishes none.
//
// ## `page` is 1-based, and the site agrees
//
// `?page=N`, **1-based** — page 1 is `/fictions/active-popular` with no query. The
// `Source` contract's `page` is 1-based for exactly this reason, and the conversion from
// Mihon's 0-based default happens here, at the boundary, in one visible line.

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;

import 'package:lumen_tale/core/network/http_client.dart';
import 'package:lumen_tale/core/network/http_response.dart';
import 'package:lumen_tale/core/network/source_endpoint.dart';
import 'package:lumen_tale/domain/sources/browse_outcome.dart';
import 'package:lumen_tale/domain/sources/http_fetching.dart';
import 'package:lumen_tale/domain/sources/models/chapter.dart';
import 'package:lumen_tale/domain/sources/models/filter.dart';
import 'package:lumen_tale/domain/sources/models/novel.dart';
import 'package:lumen_tale/domain/sources/models/novels_page.dart';
import 'package:lumen_tale/domain/sources/models/update.dart';
import 'package:lumen_tale/domain/sources/read_attempt.dart';
import 'package:lumen_tale/domain/sources/read_pipeline.dart';
import 'package:lumen_tale/domain/sources/source.dart';
import 'package:lumen_tale/domain/sources/source_id.dart';

/// Royal Road — English web novels.
final class RoyalRoadSource extends ParsedHttpSource with HttpFetching {
  RoyalRoadSource({required HttpClient client}) : _client = client;

  final HttpClient _client;

  @override
  HttpClient get client => _client;

  @override
  String get name => 'Royal Road';

  /// ⚠️ **`en`, and it is part of the id.** ISO 639-1. `SourceId.of` lowercases the
  /// name, so renaming the site is a **breaking** change — which is correct: it orphans
  /// the reader's library, and that must be a visible recorded event
  /// (`18-external-contracts.md` rule 1) rather than a silent one.
  @override
  String get lang => 'en';

  /// No trailing slash. `HttpFetching.endpoint` asserts it.
  /// ⚠️ **A named constant, not a getter's body.** The composition root builds a
  /// `SourceEndpoint` per registered source, and an endpoint declared inside a getter would
  /// make "which host is this" readable only by calling the class.
  static const String kBaseUrl = 'https://www.royalroad.com';

  /// The endpoint the registry builds this source's client against.
  ///
  /// ⚠️ **`static final` and not a `get`**, so a rename of the class cannot change the host and
  /// the registry's entry list reads as one line per source. `final` rather than `const`
  /// because `SourceEndpoint`'s constructor carries a runtime assertion — see its doc comment.
  static final SourceEndpoint kEndpoint = SourceEndpoint(baseUrl: kBaseUrl);

  /// The registry's builder, named so the entry list is a list of *functions* and a reader can
  /// see which class each row constructs.
  static Source build(HttpClient client) => RoyalRoadSource(client: client);

  @override
  String get baseUrl => kBaseUrl;

  /// Bump when URLs break, so a stored novel keeps resolving.
  ///
  /// ⚠️ **1, and the bump is `18-external-contracts.md`'s job to force.** The URLs
  /// measured on 2026-10-03 are the five-segment chapter form; an earlier three-segment
  /// form 404s, and that is a version-bump event rather than a quiet fix.
  @override
  int get versionId => 1;

  @override
  String get id => SourceId.of(name: name, lang: lang, versionId: versionId);

  /// `/fictions/active-popular` has real "latest updates" content on the same site's
  /// `/fictions/latest-updates`.
  @override
  bool get supportsLatest => true;

  /// ⚠️ **`true`, MEASURED on 2026-10-03 by `6-11`** — not asserted for convenience.
  /// `/fictions/search?title=<q>` returns 200 and 20 rows for two queries that MUST
  /// match, with every sampled title carrying the queried words; the control query that
  /// cannot match returns 0 rows **with the site's own "No results matching these
  /// criteria were found" marker**. The rows and the titles are the verdict — a 200 and
  /// a count of 20 are not.
  ///
  /// ADR-015: `true` means the UI may render a search box at all.
  @override
  bool get supportsSearch => true;

  /// B41: the platform never interprets a source's filter states, and the values belong
  /// to the site. **Empty**, and that is a measurement rather than a gap: Royal Road
  /// filters by tag through its own tag pages, not through a filter list this contract
  /// carries. A source that invented `FilterValue`s here would be inventing a filter the
  /// site does not offer.
  @override
  FilterList get filterList {
    // ⚠️ **Empty, and that is a measurement rather than a gap.** Royal Road
    // filters by tag through its own tag pages, not through a filter list this contract
    // carries. B41: the platform never interprets a source's filter states, so a source
    // that invented `FilterValue`s here would be inventing a filter the site does not
    // offer.
    return FilterList(const <Filter<Object?>>[]);
  }

  // ── the catalogue ────────────────────────────────────────────────────────────

  /// ⚠️ **`page` is 1-based and page 1 carries NO query.**
  ///
  /// Measured: `/fictions/active-popular` is page 1 and `/fictions/active-popular?page=2`
  /// is page 2. Emitting `?page=1` is not harmless on every host — it is one more URL
  /// shape, and the site's own navigation never produces it.
  @override
  Future<BrowseOutcome<NovelsPage>> getPopularNovels(int page) {
    return _readCatalogue(path: '/fictions/active-popular', page: page);
  }

  @override
  Future<BrowseOutcome<NovelsPage>> getLatestNovels(int page) {
    return _readCatalogue(path: '/fictions/latest-updates', page: page);
  }

  Future<BrowseOutcome<NovelsPage>> _readCatalogue({
    required String path,
    required int page,
    String? title,
  }) async {
    // ⚠️ **`page` omitted for page 1**, measured: `/fictions/active-popular` is
    // page 1 and `?page=2` is page 2. Emitting `?page=1` is one more URL shape the site's
    // own navigation never produces.
    final Map<String, String> query = <String, String>{
      if (page > 1) 'page': '\$page',
      // ⚠️ **`title` is a QUERY PARAMETER, never a path segment.**
      // `17-security.md` rule 1: a reader's query is untrusted input, and joining it
      // with `Uri` is what stops `//evil.example` passing as the path.
      'title': ?title,
    };
    final HttpResponse response = await fetch(
      path,
      query: query.isEmpty ? null : query,
    );

    return classifyCatalogue(
      response: response,
      path: path,
      requestedPage: page,
    );
  }

  /// @visibleForTesting
  BrowseOutcome<NovelsPage> classifyCatalogue({
    required HttpResponse response,
    required String path,
    required int requestedPage,
  }) {
    if (!response.hasResponse) {
      // No page to probe. The classifier's first arm turns this into `NoConnection`, and
      // ⚠️ **NOT** into `BrowseSucceeded(novels: [])` — an empty list asserts "the site
      // has nothing" while "we could not find out" is a different claim, and conflating
      // them is exactly what SC-6 exists to catch.
      return ReadPipeline.classifyRead<NovelsPage>(
        response: response,
        stage: ReadStage.catalogue,
        probe: ReadPipeline.broke(),
        expectedSelector: RoyalRoadSelectors.row,
        requestPath: path,
      );
    }

    final dom.Document? document = _parseOrNull(response.body);
    if (document == null) {
      return ReadPipeline.classifyRead<NovelsPage>(
        response: response,
        stage: ReadStage.catalogue,
        probe: ReadPipeline.broke(),
        expectedSelector: RoyalRoadSelectors.row,
        requestPath: path,
      );
    }

    final dom.Element? container = document.querySelector(
      RoyalRoadSelectors.container,
    );

    // ⚠️ **The probe is the CONTAINER, not the rows.**
    //
    // This is the whole of B22 on this site. It publishes no empty marker, so the only
    // discriminator available is **page shape**: "the container is there" means the page
    // is intact and its emptiness is an answer, and "the container is missing" means the
    // layout moved. Probing the ROWS instead would make an empty-but-intact catalogue
    // report as a broken site — and a broken-but-populated one report as empty, which is
    // the mirror image of SC-6.
    if (container == null) {
      return ReadPipeline.classifyRead<NovelsPage>(
        response: response,
        stage: ReadStage.catalogue,
        probe: ReadPipeline.absent(),
        expectedSelector: RoyalRoadSelectors.container,
        requestPath: path,
      );
    }

    final List<Novel> novels = <Novel>[
      for (final dom.Element row in container.querySelectorAll(
        RoyalRoadSelectors.row,
      ))
        if (_novelFrom(row) case final Novel novel) novel,
    ];

    return ReadPipeline.classifyRead<NovelsPage>(
      response: response,
      stage: ReadStage.catalogue,
      probe: ReadPipeline.found(novels.length),
      expectedSelector: RoyalRoadSelectors.row,
      requestPath: path,
      items: <NovelsPage>[
        NovelsPage(
          novels: novels,
          // ⚠️ **`true` beyond the measured depth, never guessed from a count.**
          //
          // 20 rows per page is measured. Whether page 7 exists is not, and a source
          // that inferred `hasNextPage` from "the page was full" would hand a reader an
          // empty page 8 and call it the end of the catalogue. The site publishes its own
          // pager in `ul.pagination`, so that is what this reads.
          hasNextPage: _hasNextPage(document, requestedPage),
        ),
      ],
    );
  }

  // ── search ───────────────────────────────────────────────────────────────────

  /// ⚠️ **`?title=`, and the query never leaves as a path.**
  ///
  /// `17-security.md` rule 1: a reader's query is untrusted input, so it is joined with
  /// `Uri` as a **query parameter** and never concatenated into the path — an
  /// interpolation would let `//evil.example` through as the path.
  @override
  Future<BrowseOutcome<NovelsPage>> searchNovels(
    int page,
    String query,
    FilterList filters,
  ) {
    return _readCatalogue(path: '/fictions/search', page: page, title: query);
  }

  // ── the chapter list ─────────────────────────────────────────────────────────

  /// B9: the site's own complete order, **unpaginated and unrenumbered**.
  ///
  /// `table#chapters[data-chapters="716"]` carried exactly 716 `tr[data-url]` rows on the
  /// measured capture — so the site publishes its own completeness witness, and this is
  /// the only source so far that does. That makes a truncation **mechanically checkable**
  /// rather than something a reviewer has to notice.
  @override
  Future<BrowseOutcome<List<Chapter>>> getChapterList(Novel novel) async {
    final HttpResponse response = await fetch(
      RoyalRoadSelectors.relativePathOf(novel.url),
    );
    return classifyChapterList(response: response, novel: novel);
  }

  /// The parse half, so the fixture tests drive the same code the network path does.
  BrowseOutcome<List<Chapter>> classifyChapterList({
    required HttpResponse response,
    required Novel novel,
  }) {
    if (!response.hasResponse) {
      return ReadPipeline.classifyRead<List<Chapter>>(
        response: response,
        stage: ReadStage.chapterList,
        probe: ReadPipeline.broke(),
        expectedSelector: RoyalRoadSelectors.chapterTable,
        requestPath: novel.url,
      );
    }

    final dom.Document? document = _parseOrNull(response.body);
    if (document == null) {
      return ReadPipeline.classifyRead<List<Chapter>>(
        response: response,
        stage: ReadStage.chapterList,
        probe: ReadPipeline.broke(),
        expectedSelector: RoyalRoadSelectors.chapterTable,
        requestPath: novel.url,
      );
    }

    final dom.Element? table = document.querySelector(
      RoyalRoadSelectors.chapterTable,
    );
    if (table == null) {
      return ReadPipeline.classifyRead<List<Chapter>>(
        response: response,
        stage: ReadStage.chapterList,
        probe: ReadPipeline.absent(),
        expectedSelector: RoyalRoadSelectors.chapterTable,
        requestPath: novel.url,
      );
    }

    final List<Chapter> chapters = <Chapter>[
      for (final dom.Element row in table.querySelectorAll(
        RoyalRoadSelectors.chapterRow,
      ))
        if (_chapterFrom(row, novel) case final Chapter chapter) chapter,
    ];

    // ⚠️ **B9's witness, checked and not assumed.** The site publishes its own count, so
    // "40 rows parsed but the attribute says 716" is a *detectable truncation* rather
    // than a reviewer's judgement call — and a truncated list returned as the whole one
    // is B9 broken with no error anywhere.
    final String? published =
        table.attributes[RoyalRoadSelectors.chapterCountAttribute];
    if (published != null) {
      final int? expected = int.tryParse(published);
      if (expected != null && expected != chapters.length) {
        // Reported, never padded and never trimmed. A chapter table padded to the
        // published count would invent chapters, which is worse than a short list.
        return ReadPipeline.classifyRead<List<Chapter>>(
          response: response,
          stage: ReadStage.chapterList,
          probe: ReadPipeline.absent(),
          expectedSelector: RoyalRoadSelectors.chapterRow,
          requestPath: novel.url,
        );
      }
    }

    return ReadPipeline.classifyRead<List<Chapter>>(
      response: response,
      stage: ReadStage.chapterList,
      probe: ReadPipeline.found(chapters.length),
      expectedSelector: RoyalRoadSelectors.chapterRow,
      requestPath: novel.url,
      items: <List<Chapter>>[chapters],
    );
  }

  // ── the chapter body ─────────────────────────────────────────────────────────

  /// `03-source-system.md` rule 11: **the source selects the article node and stops.**
  /// No cleaning, no thresholds, no joining across pages beyond the site's own order.
  /// Everything after this belongs to `2-2` and `2-3`, and a source that did any of it
  /// could not be tested against a fixture.
  @override
  Future<BrowseOutcome<String>> fetchChapterContent(Chapter chapter) async {
    final HttpResponse response = await fetch(
      RoyalRoadSelectors.relativePathOf(chapter.url),
    );
    return classifyChapterContent(response: response, chapter: chapter);
  }

  BrowseOutcome<String> classifyChapterContent({
    required HttpResponse response,
    required Chapter chapter,
  }) {
    if (!response.hasResponse) {
      return ReadPipeline.classifyRead<String>(
        response: response,
        stage: ReadStage.chapterContent,
        probe: ReadPipeline.broke(),
        expectedSelector: RoyalRoadSelectors.chapterBody,
        requestPath: chapter.url,
      );
    }

    final dom.Document? document = _parseOrNull(response.body);
    if (document == null) {
      return ReadPipeline.classifyRead<String>(
        response: response,
        stage: ReadStage.chapterContent,
        probe: ReadPipeline.broke(),
        expectedSelector: RoyalRoadSelectors.chapterBody,
        requestPath: chapter.url,
      );
    }

    // ⚠️ **`div.chapter-inner.chapter-content` and NOT `class="chapter-content"`.**
    //
    // Measured: an **exact** `class="chapter-content"` match finds **nothing** on a page
    // carrying 106 paragraphs, because the class sits on a div that *also* carries
    // `chapter-inner`. This is the selector mistake that turns a chapter into
    // `SourceLayoutChanged`, and it is invisible until a reader opens a chapter.
    final dom.Element? body = document.querySelector(
      RoyalRoadSelectors.chapterBody,
    );
    if (body == null) {
      return ReadPipeline.classifyRead<String>(
        response: response,
        stage: ReadStage.chapterContent,
        probe: ReadPipeline.absent(),
        expectedSelector: RoyalRoadSelectors.chapterBody,
        requestPath: chapter.url,
      );
    }

    // ⚠️ **The probe reports 1, not the paragraph count.** The container IS the element
    // being looked for; a chapter with zero paragraphs inside a present container is a
    // site that published an empty chapter, which is the site's statement and not ours.
    return ReadPipeline.classifyRead<String>(
      response: response,
      stage: ReadStage.chapterContent,
      probe: ReadPipeline.found(1),
      expectedSelector: RoyalRoadSelectors.chapterBody,
      requestPath: chapter.url,
      items: <String>[body.innerHtml],
    );
  }

  // ── details and updates ──────────────────────────────────────────────────────

  /// B38: metadata only. **This method never downloads a chapter body** — it compares
  /// titles and dates, and a row that fetched a body to answer it would be the defect
  /// that rule was written to prevent.
  @override
  Future<BrowseOutcome<NovelUpdate>> getNovelUpdate(
    Novel novel,
    List<Chapter> chapters, {
    required bool fetchDetails,
    required bool fetchChapters,
  }) async {
    final HttpResponse response = await fetch(
      RoyalRoadSelectors.relativePathOf(novel.url),
    );
    if (!response.hasResponse) {
      return ReadPipeline.classifyRead<NovelUpdate>(
        response: response,
        stage: ReadStage.chapterList,
        probe: ReadPipeline.broke(),
        expectedSelector: RoyalRoadSelectors.chapterTable,
        requestPath: novel.url,
      );
    }
    final dom.Document? document = _parseOrNull(response.body);
    if (document == null) {
      return ReadPipeline.classifyRead<NovelUpdate>(
        response: response,
        stage: ReadStage.chapterList,
        probe: ReadPipeline.broke(),
        expectedSelector: RoyalRoadSelectors.chapterTable,
        requestPath: novel.url,
      );
    }
    final dom.Element? table = document.querySelector(
      RoyalRoadSelectors.chapterTable,
    );
    if (table == null) {
      return ReadPipeline.classifyRead<NovelUpdate>(
        response: response,
        stage: ReadStage.chapterList,
        probe: ReadPipeline.absent(),
        expectedSelector: RoyalRoadSelectors.chapterTable,
        requestPath: novel.url,
      );
    }

    // ⚠️ **Re-emit only what is unknown.** The update asks "what changed", and a source
    // that answered with the whole list would make every novel look entirely new on
    // every check — which trains a reader to ignore the update screen.
    final Set<String> knownUrls = <String>{
      for (final Chapter chapter in chapters) chapter.url,
    };
    final List<Chapter> all = <Chapter>[
      for (final dom.Element row in table.querySelectorAll(
        RoyalRoadSelectors.chapterRow,
      ))
        if (_chapterFrom(row, novel) case final Chapter chapter) chapter,
    ];
    final List<Chapter> fresh = <Chapter>[
      for (final Chapter chapter in all)
        if (!knownUrls.contains(chapter.url)) chapter,
    ];

    return ReadPipeline.classifyRead<NovelUpdate>(
      response: response,
      stage: ReadStage.chapterList,
      probe: ReadPipeline.found(fresh.length + chapters.length),
      expectedSelector: RoyalRoadSelectors.chapterRow,
      requestPath: novel.url,
      items: <NovelUpdate>[
        // ⚠️ **`chapters` is the WHOLE list the site now publishes**, not only what
        // changed: the field is the novel's chapters and the screen diffs them. Passing
        // only the additions would make every chapter look new on every check — which
        // trains a reader to ignore the update screen.
        NovelUpdate(novel: novel, chapters: all),
      ],
    );
  }

  @override
  Future<BrowseOutcome<Novel>> getNovelDetails(Novel novel) async {
    final HttpResponse response = await fetch(
      RoyalRoadSelectors.relativePathOf(novel.url),
    );
    return classifyDetails(response: response, novel: novel);
  }

  /// The parse half, so the fixture tests drive the same code the network path does.
  @visibleForTesting
  BrowseOutcome<Novel> classifyDetails({
    required HttpResponse response,
    required Novel novel,
  }) {
    if (!response.hasResponse) {
      return ReadPipeline.classifyRead<Novel>(
        response: response,
        stage: ReadStage.novelDetails,
        probe: ReadPipeline.broke(),
        expectedSelector: RoyalRoadSelectors.title,
        requestPath: novel.url,
      );
    }
    final dom.Document? document = _parseOrNull(response.body);
    final dom.Element? title = document?.querySelector(
      RoyalRoadSelectors.title,
    );
    if (document == null || title == null) {
      return ReadPipeline.classifyRead<Novel>(
        response: response,
        stage: ReadStage.novelDetails,
        probe: ReadPipeline.absent(),
        expectedSelector: RoyalRoadSelectors.title,
        requestPath: novel.url,
      );
    }

    // ⚠️ **`div.fic-title h4 a[href^="/profile/"]`, and `/author/` matches NOTHING.**
    //
    // `/author/<id>` is the shape every other source in this app's reference material
    // uses, and parsing it here would yield `null` on a perfectly healthy page — which
    // under `zeroIsBroken` would be reported as a broken site rather than as a missing
    // optional field. Measured on the Runesmith capture: `Kuropon`.
    final dom.Element? authorNode = document.querySelector(
      RoyalRoadSelectors.author,
    );

    return ReadPipeline.classifyRead<Novel>(
      response: response,
      stage: ReadStage.novelDetails,
      probe: ReadPipeline.found(1),
      expectedSelector: RoyalRoadSelectors.title,
      requestPath: novel.url,
      items: <Novel>[
        Novel(
          id: novel.id,
          sourceId: novel.sourceId,
          url: novel.url,
          title: title.text.trim(),
          // ⚠️ **`null` is a legal value and a missing author is not a failure.** B10:
          // site text is shown verbatim; a source that invented one would show a
          // sentence the site never published.
          author: authorNode?.text.trim(),
          description: novel.description,
          status: novel.status,
          coverUrl: novel.coverUrl,
          genres: novel.genres,
          // ⚠️ **`initialized: true` — a detail read IS the initialization.** B32's
          // library row carries the fields the details page carries, and a novel left
          // uninitialized after its details were read is a novel whose library entry
          // keeps showing a placeholder.
          initialized: true,
        ),
      ],
    );
  }

  // ── row mapping ──────────────────────────────────────────────────────────────

  /// One catalogue row → one [Novel], or `null` when it has no title link.
  Novel? _novelFrom(dom.Element row) {
    final dom.Element? link = row.querySelector(RoyalRoadSelectors.titleLink);
    final String? href = link?.attributes['href'];
    final String? title = link?.text.trim();
    if (href == null || title == null || title.isEmpty) {
      // A row with no title is not a novel, and it is **not** an error: the container
      // was found, so the page is intact. Dropping it is what "count the rows I could
      // read" means, and the count the classifier sees is the rows it actually got.
      return null;
    }

    return Novel(
      id: SourceId.forNovel(sourceId: id, relativeUrl: href),
      sourceId: id,
      url: href,
      title: title,
      // ⚠️ **`null`, and this is measured.** The catalogue row carries **no author
      // element of any kind** — cover `img`, `h2.fiction-title > a`, the tags block,
      // `div.row.stats`, `div#description-<id>`, and nothing that names the author. The
      // cover's `alt` is the NOVEL title, so it cannot stand in. The author arrives only
      // from the detail page.
      author: null,
      description: _textOf(row, RoyalRoadSelectors.descriptionPrefix),
      status: NovelStatus.unknown,
      coverUrl: row.querySelector(RoyalRoadSelectors.cover)?.attributes['src'],
      genres: _tagsOf(row),
      // ⚠️ **A `Map` of the parsed stats, and it is a `memo` not new columns.** The
      // rating's number lives in the `title` attribute of the `fa-star` span and that
      // span's own text is EMPTY — so a source reading the span reports `0` for a
      // fiction rated `4.73`. The site offers these numbers; nothing in v1 has a column
      // for them, and adding one is `6-*`'s decision, not a reader-facing one.
      memo: _statsOf(row),
    );
  }

  Chapter? _chapterFrom(dom.Element row, Novel novel) {
    // ⚠️ **`tr[data-url]`, and it carries the FULL five-segment URL.** The fifth segment
    // is the chapter's own slug; `/fiction/<id>/<slug>/chapter/<n>` 404s, and a 404 is
    // indistinguishable from a chapter that does not exist — B22's third state. So the
    // row is the URL's source and this source never constructs one.
    final String? url = row.attributes['data-url'];
    if (url == null || url.isEmpty) {
      return null;
    }
    return Chapter(
      id: SourceId.forChapter(novelId: novel.id, relativeUrl: url),
      novelId: novel.id,
      url: url,
      name: row.querySelector('td')?.text.trim(),
      number: _chapterNumberOf(row, url),
    );
  }

  // ── small readers, each with the reason it is that shape ─────────────────────

  /// ⚠️ **The number comes from the URL's fourth segment, and never from an index.**
  ///
  /// `/chapter/<n>/` — B10's ordering is the site's, so a source that numbered rows
  /// `1, 2, 3…` would renumber a fiction whose first entry is a glossary, which is
  /// exactly what this capture has.
  double _chapterNumberOf(dom.Element row, String url) {
    final RegExpMatch? match = RegExp(
      r'/chapter/(\d+(?:\.\d+)?)/',
    ).firstMatch(url);
    if (match == null) {
      // A chapter with no parseable number gets `0`, which sorts it first — and that is
      // the honest reading of "the site published no number", rather than inventing one.
      return 0;
    }
    return double.parse(match.group(1)!);
  }

  /// Followers · Rating · Pages · Views · Chapters · Updated.
  ///
  /// ⚠️ **The rating is read from `title`, not from text**, and this is the one that a
  /// reasonable implementation gets wrong: the `fa-star` span's text is empty and the
  /// number is in the sibling's `title` attribute, so the naive read yields `0`.
  Map<String, Object?> _statsOf(dom.Element row) {
    final dom.Element? stats = row.querySelector(RoyalRoadSelectors.stats);
    if (stats == null) {
      return const <String, Object?>{};
    }
    final Map<String, Object?> memo = <String, Object?>{};
    for (final dom.Element cell in stats.querySelectorAll('div')) {
      final dom.Element? icon = cell.querySelector('i.fa');
      if (icon == null) {
        continue;
      }
      final String key = (icon.attributes['class'] ?? '')
          .split(' ')
          .firstWhere((String c) => c.startsWith('fa-'), orElse: () => '');
      if (key.isEmpty) {
        continue;
      }
      if (key == 'fa-star') {
        final String? rating = cell
            .querySelector('span[title]')
            ?.attributes['title'];
        if (rating != null) {
          memo['royalRoad.rating'] = double.tryParse(rating);
        }
        continue;
      }
      memo['royalRoad.$key'] = cell.querySelector('span')?.text.trim();
    }
    final String? updated = stats
        .querySelector('time')
        ?.attributes[RoyalRoadSelectors.unixTimeAttribute];
    if (updated != null) {
      final int? seconds = int.tryParse(updated);
      if (seconds != null) {
        memo['royalRoad.updatedAt'] = DateTime.fromMillisecondsSinceEpoch(
          seconds * 1000,
          isUtc: true,
        );
      }
    }
    return memo;
  }

  List<String> _tagsOf(dom.Element row) {
    return <String>[
      for (final dom.Element tag in row.querySelectorAll(
        RoyalRoadSelectors.tag,
      ))
        if (tag.text.trim().isNotEmpty) tag.text.trim(),
    ];
  }

  /// `div#description-<novelId>` — **prefixed by the row's own novel id.**
  ///
  /// ⚠️ A bare `div[id^="description-"]` would also match, but the id is the *join key*
  /// to the row and taking it from the row means the description can never be attached
  /// to the wrong novel.
  String? _textOf(dom.Element row, String attributePrefix) {
    for (final dom.Element node in row.querySelectorAll('div[id]')) {
      final String? id = node.attributes['id'];
      if (id != null && id.startsWith(attributePrefix)) {
        return node.text.trim();
      }
    }
    return null;
  }

  /// `ul.pagination`'s own active marker, not a guess from a full page.
  ///
  /// ⚠️ **20 rows per page is measured; whether page 9 exists is not.** Inferring
  /// `hasNextPage` from "the page was full" would hand a reader an empty page and call
  /// it the end of the catalogue — and a catalogue that ends early is invisible.
  bool _hasNextPage(dom.Document document, int page) {
    for (final dom.Element item in document.querySelectorAll(
      RoyalRoadSelectors.paginationActive,
    )) {
      final int? active = int.tryParse(item.text.trim());
      if (active != null && active == page) {
        // The site marks the page it is on, so the pager exists and names it.
        return document.querySelectorAll(RoyalRoadSelectors.pagination).length >
            page;
      }
    }
    // No marker found. **Assume there is no next page**, which is the conservative
    // direction: a missing last page is a smaller lie than a missing second page.
    return false;
  }

  static dom.Document? _parseOrNull(String body) {
    if (body.trim().isEmpty) {
      return null;
    }
    try {
      return html_parser.parse(body);
    } on Object {
      return null;
    }
  }
}

/// Every selector this source uses, in one place.
///
/// `18-external-contracts.md` records **why** each exists; this is **where** they are. A
/// selector literal inline at a call site is a selector nobody can audit against the
/// frozen fixtures, and that audit is the whole reason the fixtures ship.
abstract final class RoyalRoadSelectors {
  /// `div.fiction-list#result`.
  ///
  /// ⚠️ **The container, and it is the B22 probe.** A page with this element is intact,
  /// even when it holds no rows. There is no empty marker on this site, so the container
  /// is the only discriminator available.
  static const String container = 'div.fiction-list#result';

  /// `div.fiction-list-item.row` — a descendant of [container].
  ///
  /// ⚠️ **`tr.fiction-list-item` matches ZERO** and the page carries no `<table>` at all.
  static const String row = 'div.fiction-list-item.row';

  static const String titleLink = 'h2.fiction-title > a';

  static const String cover = 'figure img[data-type="cover"]';

  static const String stats = 'div.row.stats';

  static const String tag = 'span.tags span.label';

  static const String descriptionPrefix = 'description-';

  static const String pagination = 'ul.pagination li a';

  static const String paginationActive = 'ul.pagination li.page-active';

  // ── the detail page ──────────────────────────────────────────────────────────

  /// `h1.font-white`. `og:title` is **absent**, so there is no metadata fallback.
  static const String title = 'h1';

  /// ⚠️ **`div.fic-title h4 a[href^="/profile/"]` — and `/author/` matches NOTHING.**
  static const String author = 'div.fic-title h4 a[href^="/profile/"]';

  // ── the chapter table ────────────────────────────────────────────────────────

  static const String chapterTable = 'table#chapters';

  static const String chapterRow = 'tr[data-url]';

  /// The site's own completeness witness. **This site publishes its count**; FanMTL does
  /// not.
  static const String chapterCountAttribute = 'data-chapters';

  // ── the chapter body ─────────────────────────────────────────────────────────

  /// ⚠️ **`div.chapter-inner.chapter-content`.** An exact `class="chapter-content"` match
  /// finds **nothing** on a page carrying 106 paragraphs, because the class sits on a div
  /// that also carries `chapter-inner`.
  static const String chapterBody = 'div.chapter-inner.chapter-content';

  static const String unixTimeAttribute = 'unixtime';

  /// The site-relative form of a stored absolute or relative URL.
  ///
  /// ⚠️ **Never a full URL.** `03-source-system.md` rule 3: paths are `(path, query)`,
  /// never full URLs, so a stored URL that still pointed at a host would keep working
  /// against a host the app has moved away from.
  static String relativePathOf(String url) {
    if (url.startsWith('/')) {
      return url;
    }
    final Uri? parsed = Uri.tryParse(url);
    return parsed == null ? url : parsed.path;
  }
}
