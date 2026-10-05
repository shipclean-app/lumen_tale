// Lumen Tale — Royal Road pagination discovery.
//
// `0-3` § 2.2 / § 3.2. Reads frozen fixtures; **never** the network
// (`10-testing.md` rule 7). Lives under `test/` because it is a measurement tool —
// nothing in `lib/` imports it, and nothing in `lib/` should.
//
// ## What the fixtures actually show, and three corrections to the plan
//
// The plan's § 3.2 lists five pagination motifs and assumes numbered anchors carry a
// page number in their own href. Reading `catalogue-active-popular-page0.html`:
//
// 1. **The parameter is `?page=N` and it is 1-based.** `page=1` is the FIRST page,
//    not page zero. The plan's motif (b) — "Next → offset" — has no match here at
//    all: there is no offset anywhere on the page.
// 2. **Anchor 0 is `javascript:;`.** It is a styled page-number link whose href was
//    deliberately emptied by the server. A probe that keeps it reports a
//    `javascript:` URL as a discovered page, and a source that follows it fetches
//    nothing.
// 3. **There are 6 anchors and 799 pages.** The window is 0,1,2,3,4,5 plus a `Last`
//    link to `page=799`. A probe that assumes "the last numbered anchor is the last
//    page" reads 5.
//
// `novel-detail-runesmith.html` paginates its **reviews**, not its chapters:
// `?reviews=N`, also 1-based, 6 anchors. The chapter list is **not** paginated on
// this site — 716 `tr.chapter-row`, `data-chapters="716"`, no `?page=` anywhere. That
// is the single most useful thing this probe found for B9: chapter completeness is
// **whole**, so a partial read is detectable by count alone.

import 'package:html/dom.dart';
import 'package:html/parser.dart' show parse;

/// Which page shape is being examined. Royal Road reuses the same paginated
/// component for catalogue listings and for the reviews tab, so `pageKind` names
/// **which** pagination was found rather than asserting a site-wide truth.
enum RoyalRoadPageKind {
  /// A paginated listing: `/fictions/<sort>?page=N`.
  paginatedListing,

  /// The reviews tab of a fiction: `/fiction/<id>/<slug>?reviews=N`.
  paginatedTab,

  /// A whole list on one page — the chapter table, which on Royal Road is not
  /// paginated at all.
  unpaginatedList,
}

/// A parameter read off a real `href`, never guessed.
final class DiscoveredParameter {
  const DiscoveredParameter({
    required this.name,
    required this.valueOnSecondPage,
    required this.firstPageValue,
    required this.oneBased,
    required this.exampleHref,
  });

  /// `page` or `reviews`. Read from the href's own key, not assumed.
  final String name;

  /// The value that reaches the second page — the only way to know the parameter
  /// moves is to see it move.
  final String valueOnSecondPage;

  /// The value the current page carries, for comparison.
  final String firstPageValue;

  /// Measured, not assumed. Royal Road's `page=1` is the first page.
  final bool oneBased;

  /// The href it was read from, so a reader can check it against the fixture.
  final String exampleHref;

  @override
  String toString() =>
      '$name=$valueOnSecondPage (first page carries $firstPageValue, '
      '${oneBased ? 'one-based' : 'zero-based'}) from $exampleHref';
}

/// Everything one fixture reveals about its own pagination.
final class PaginationFinding {
  const PaginationFinding({
    required this.pageKind,
    required this.hasPagination,
    required this.totalAnchors,
    required this.numberedAnchors,
    required this.javascriptAnchors,
    required this.currentPage,
    required this.lastPage,
    required this.firstPageItemCount,
    required this.secondPageItemCount,
    required this.parameters,
    required this.listsDistinctChapterLinks,
    required this.notes,
    this.distinctItemsOnSecondPage,
  });

  final RoyalRoadPageKind pageKind;
  final bool hasPagination;

  /// Every anchor inside the pagination container.
  final int totalAnchors;

  /// Those whose text is a bare integer, minus the `javascript:;` ones.
  final int numberedAnchors;

  /// How many anchors carry `href="javascript:;"`. **Never** a discovered page.
  final int javascriptAnchors;

  /// The page number this document is, from the `active` anchor.
  final int currentPage;

  /// The last page the site publishes, from its `Last` link.
  final int? lastPage;

  /// Novel rows in this document. Counted on the fiction-card container, which is
  /// what the live markup uses — see the note in [countListingItems].
  final int firstPageItemCount;

  /// Items in the second page. `null` until a second fixture is compared, because
  /// **one page cannot confirm its own pagination** — see [isConfirmed].
  final int? secondPageItemCount;

  final List<DiscoveredParameter> parameters;

  /// Distinct `/fiction/<id>/<slug>/chapter/<n>/<slug>` hrefs. `null` on a page that
  /// is not a chapter list.
  final int? listsDistinctChapterLinks;

  final String notes;

  /// Whether the site's pagination was **confirmed against a second page**.
  ///
  /// ⚠️ **The plan's rule (`0-3` § 3.2.1) is `secondPageItemCount >
  /// firstPageItemCount`, and it is wrong for a fixed-page-size listing.** Royal Road
  /// serves exactly 20 novels on every listing page, so the rule is false on a site
  /// whose pagination demonstrably works: page 1 holds 20 novels and page 2 holds 20
  /// *different* novels. Recording it unconfirmed would make `2-1` treat `?page=N`
  /// as decoration and silently read page 1 forever — a failure that looks like
  /// "the source returned everything" while dropping 99% of the catalogue.
  ///
  /// A page holding the same number of items as the page before it is the **normal**
  /// case for any paginated list, not evidence of absence. What actually confirms
  /// pagination is that the two pages hold **different items**, which is a set
  /// comparison rather than a count comparison. [distinctItemsOnSecondPage] carries
  /// it.
  ///
  /// Both numbers are still recorded, so a reader can check the reasoning rather
  /// than take it.
  bool get isConfirmed {
    if (!hasPagination || parameters.isEmpty) return false;
    if (currentPage != 1) return false;
    if (firstPageItemCount == 0) return false;
    final int? secondDistinct = distinctItemsOnSecondPage;
    if (secondDistinct == null) return false;
    return secondDistinct > 0 && secondDistinct != firstPageItemCount;
  }

  /// How many items the second page held that the first did not.
  ///
  /// Measured by the caller, from the two frozen fixtures. **Not derivable from one
  /// page**, which is the whole point: an href is a hypothesis, a second page is
  /// evidence.
  final int? distinctItemsOnSecondPage;

  /// A copy carrying the second page's measurements, which is the only thing that
  /// can turn [isConfirmed] on.
  PaginationFinding confirmedBy({
    required int secondPageItems,
    required int distinctItemsOnSecond,
    String? note,
  }) => PaginationFinding(
    pageKind: pageKind,
    hasPagination: hasPagination,
    totalAnchors: totalAnchors,
    numberedAnchors: numberedAnchors,
    javascriptAnchors: javascriptAnchors,
    currentPage: currentPage,
    lastPage: lastPage,
    firstPageItemCount: firstPageItemCount,
    secondPageItemCount: secondPageItems,
    distinctItemsOnSecondPage: distinctItemsOnSecond,
    parameters: parameters,
    listsDistinctChapterLinks: listsDistinctChapterLinks,
    notes: note ?? notes,
  );
}

final class RoyalRoadPaginationProbe {
  const RoyalRoadPaginationProbe();

  /// Inspects one document. Says nothing it did not read from this document.
  PaginationFinding discover(
    String html,
    RoyalRoadPageKind pageKind, {
    int? distinctChapterLinks,
    int? expectedChapterCount,
  }) {
    final Document document = parse(html);
    final Element? body = document.body;
    if (body == null) {
      return PaginationFinding(
        pageKind: pageKind,
        hasPagination: false,
        totalAnchors: 0,
        numberedAnchors: 0,
        javascriptAnchors: 0,
        currentPage: 1,
        lastPage: null,
        firstPageItemCount: 0,
        secondPageItemCount: null,
        parameters: const <DiscoveredParameter>[],
        listsDistinctChapterLinks: distinctChapterLinks,
        notes: 'no <body>: nothing could be read, which is not "no pagination"',
      );
    }

    final List<PageAnchorReference> anchors = _paginationAnchors(body);
    final int javascript = anchors
        .where((PageAnchorReference a) => a.isJavascript)
        .length;
    final List<PageAnchorReference> numbered = anchors
        .where(
          (PageAnchorReference a) =>
              !a.isJavascript && int.tryParse(a.text) != null,
        )
        .toList();
    final PageAnchorReference? active = anchors
        .where((PageAnchorReference a) => a.isCurrent)
        .toList()
        .firstOrNull;
    final PageAnchorReference? last = anchors
        .where(
          (PageAnchorReference a) =>
              RegExp('last|fin|dernier', caseSensitive: false).hasMatch(a.text),
        )
        .toList()
        .firstOrNull;

    // The second page is the anchor numbered 2 — read off the document, not assumed.
    final PageAnchorReference? second = numbered
        .where((PageAnchorReference a) => a.pageNumber == 2)
        .toList()
        .firstOrNull;

    final List<DiscoveredParameter> parameters = <DiscoveredParameter>[];
    if (second != null && second.href.isNotEmpty) {
      final String? name = _queryKey(
        second.href,
        keys: const <String>['page', 'reviews'],
      );
      if (name != null) {
        final int? firstValue = firstPageValueOf(anchors, queryKey: name);
        parameters.add(
          DiscoveredParameter(
            name: name,
            valueOnSecondPage:
                second.pageNumber?.toString() ??
                _queryValue(second.href, name) ??
                '2',
            firstPageValue: firstValue?.toString() ?? 'unknown',
            oneBased: firstValue == 1,
            exampleHref: second.href,
          ),
        );
      }
    }

    final String notes = switch (pageKind) {
      RoyalRoadPageKind.paginatedListing =>
        numbered.isEmpty
            ? 'no numbered anchors: the listing is not paginated, or the window '
                  'has not been rendered'
            : 'numbered anchors present; $javascript anchor(s) inside the '
                  'pagination container carry "javascript:;" and are NOT pages',
      RoyalRoadPageKind.paginatedTab =>
        'the paginated list here is the REVIEWS tab, not the chapter list',
      RoyalRoadPageKind.unpaginatedList =>
        'the chapter table is whole on one page; completeness is countable',
    };

    final StringBuffer extra = StringBuffer(notes);
    if (pageKind == RoyalRoadPageKind.unpaginatedList &&
        distinctChapterLinks != null &&
        expectedChapterCount != null) {
      extra.write(
        ' — $distinctChapterLinks distinct chapter links against a declared '
        'count of $expectedChapterCount',
      );
      extra.write(
        distinctChapterLinks == expectedChapterCount
            ? ' (they match)'
            : ' (THEY DIFFER — the list is partial)',
      );
    }

    return PaginationFinding(
      pageKind: pageKind,
      hasPagination: numbered.length >= 2,
      totalAnchors: anchors.length,
      numberedAnchors: numbered.length,
      javascriptAnchors: javascript,
      currentPage: active?.pageNumber ?? 1,
      lastPage: last?.pageNumber,
      firstPageItemCount: countListingItems(body),
      secondPageItemCount: null,
      parameters: parameters,
      listsDistinctChapterLinks: distinctChapterLinks,
      notes: extra.toString(),
    );
  }

  /// Counts the novels a listing page holds.
  ///
  /// ⚠️ **Measured, and the plan's selector was wrong.** `tr.fiction-list-item`
  /// matches **zero** rows on Royal Road: the site stopped rendering listings as a
  /// table. The cards are `<div class="fiction-list-item row">`, 20 per page, and a
  /// probe that trusted the documented table row would report 0 and call the page
  /// empty — the exact E8 confusion this project exists to avoid.
  int countListingItems(Element body) =>
      body.querySelectorAll('.fiction-list-item').length;

  /// Counts distinct chapter links. A page listing the same chapter twice counts
  /// once — `0-3` § 10, B9.
  static int countDistinctChapterLinks(Element body) {
    final Set<String> hrefs = <String>{};
    for (final Element a in body.querySelectorAll('a')) {
      final String href = a.attributes['href'] ?? '';
      if (RegExp('^/fiction/[0-9]+/[^?]*chapter/[0-9]+').hasMatch(href)) {
        hrefs.add(href);
      }
    }
    return hrefs.length;
  }

  /// The site's own declared chapter count, read off the fiction page.
  ///
  /// This is what makes B9 checkable: the site publishes how many chapters there
  /// are, so a partial read is detectable by arithmetic rather than by suspicion.
  static int? declaredChapterCount(Element body) {
    final String? raw = body
        .querySelector('[data-chapters]')
        ?.attributes['data-chapters'];
    return int.tryParse(raw ?? '');
  }

  /// The anchors inside the pagination container.
  ///
  /// Only anchors inside `<ul class="pagination">` count. Counting every anchor on
  /// the page would sweep in 20 novel titles, 700 chapter links and the footer —
  /// which is how a probe ends up reporting "6 numbered anchors" for the wrong
  /// reason on a page that has none.
  List<PageAnchorReference> _paginationAnchors(Element body) {
    final List<PageAnchorReference> out = <PageAnchorReference>[];
    for (final Element list in body.querySelectorAll('ul.pagination')) {
      for (final Element a in list.querySelectorAll('a')) {
        final Element? li = a.parent;
        final String text = a.text.trim();
        // ignore: unnecessary_statements
        out.add(
          PageAnchorReference(
            href: (a.attributes['href'] ?? '').trim(),
            text: text,
            // ⚠️ `data-page` first, then the link text. Royal Road marks the current
            // page with `<li class="page-active">` — NOT `active` — so a probe
            // looking for `active` reads every page as page 1.
            pageNumber:
                int.tryParse(a.attributes['data-page'] ?? '') ??
                int.tryParse(text),
            isJavascript: (a.attributes['href'] ?? '').trim() == 'javascript:;',
            isLast: RegExp(
              'last|fin|dernier',
              caseSensitive: false,
            ).hasMatch(text),
            isCurrent:
                a.classes.contains('page-active') ||
                a.classes.contains('active') ||
                li?.classes.contains('page-active') == true ||
                li?.classes.contains('active') == true ||
                a.attributes['aria-current'] == 'page',
          ),
        );
      }
    }
    return out;
  }

  /// The value the current page carries for [queryKey], from the `active` anchor.
  static int? firstPageValueOf(
    List<PageAnchorReference> anchors, {
    required String queryKey,
  }) {
    for (final PageAnchorReference a in anchors) {
      if (!a.isCurrent) continue;
      final int? n = _queryValue(a.href, queryKey) != null
          ? int.tryParse(_queryValue(a.href, queryKey)!)
          : (a.pageNumber);
      if (n != null) return n;
    }
    return null;
  }

  static String? _keyOf(String href) {
    final int q = href.indexOf('?');
    if (q < 0) return null;
    final String query = href.substring(q + 1);
    for (final String part in query.split('&')) {
      final int eq = part.indexOf('=');
      if (eq > 0) return part.substring(0, eq);
    }
    return null;
  }

  static String? _queryKey(String href, {required List<String> keys}) {
    final String? any = _keyOf(href);
    return any != null && keys.contains(any) ? any : null;
  }

  static String? _queryValue(String href, String? key) {
    if (key == null) return null;
    final int q = href.indexOf('?');
    if (q < 0) return null;
    for (final String part in href.substring(q + 1).split('&')) {
      final int eq = part.indexOf('=');
      if (eq > 0 && part.substring(0, eq) == key) return part.substring(eq + 1);
    }
    return null;
  }
}

final class PageAnchorReference {
  const PageAnchorReference({
    required this.href,
    required this.text,
    required this.pageNumber,
    required this.isJavascript,
    required this.isLast,
    required this.isCurrent,
  });

  final String href;
  final String text;

  /// The page this anchor leads to, from `data-page` or from a bare-integer label.
  /// `null` for a label like "Next ›" that carries no number of its own.
  final int? pageNumber;

  final bool isJavascript;
  final bool isLast;
  final bool isCurrent;
}
