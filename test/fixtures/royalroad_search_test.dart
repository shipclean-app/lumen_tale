// Lumen Tale — `6-11`: is the search a reader would call useful?
//
// ADR-015, word for word: *set `supportsSearch = true` only after you have fetched
// the site's own search and seen results a reader would call useful.* The gate is
// **the results**, and this file is where the recorded verdict is **re-derived from
// the captured pages** rather than believed — the `0-2` / `0-3` idiom, and the reason
// it is one: a verdict nobody re-derives is a comment, and `supportsSearch` decides
// whether a search box is rendered at all.
//
// The negative query is the control that makes the positive one mean something. Without
// it, "20 rows for `litrpg`" and "20 rows because the page always shows 20 rows" are
// the same observation, and the second is a source that would ship a search box and
// then show the reader a random catalogue forever.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;

/// The row selector `0-1` measured on the **catalogue**, reused here on the search
/// pages. ⚠️ Reusing it is a claim, not a convenience: if the two pages were built by
/// different templates, the search count would be measuring something else. The
/// `a zero-row page uses the same shell` row below is what keeps the claim honest.
const String rowSelector = 'div.fiction-list-item.row';

final File verdictFile = File(
  'test/fixtures/sources/royalroad/search/verdict.json',
);

Map<String, Object?> verdictJson = <String, Object?>{};

File fixtureFor(String name) =>
    File('test/fixtures/sources/royalroad/search/$name');

/// How many times [literal] appears in [html]'s **VISIBLE text**.
///
/// Visible, not raw: `package:html` synthesises a `<body>`, a `<script>` body is
/// not something a reader was shown, and an HTML comment is not visible either. A
/// marker measured on the raw document can be an artefact of the page's own JavaScript
/// — which is exactly what `0-2`'s `EmptySignalProbe` was written to rule out, and why
/// this is the same measurement a second time rather than a new one.
///
/// ⚠️ The witness is at the bottom: a counter that always returns zero would make
/// every marker row pass.
int _visibleTextOccurrences(String html, String literal) {
  final dom.Document document = html_parser.parse(html);
  final List<String> invisible = <String>['script', 'style'];
  for (final String tag in invisible) {
    for (final dom.Element element in document.querySelectorAll(tag)) {
      element.remove();
    }
  }
  final String text = document.body?.text ?? '';
  final String collapsed = text.replaceAll(RegExp(r'\s+'), ' ');
  return RegExp(RegExp.escape(literal)).allMatches(collapsed).length;
}

/// The rows a page actually carries, parsed rather than counted by substring.
///
/// `grep` would count `fiction-list-item` inside a comment or a template string; the
/// selector counts elements, which is what "results" means.
List<dom.Element> rowsIn(String html) =>
    html_parser.parse(html).querySelectorAll(rowSelector);

/// The visible title of each row. A row without a title is still a row, and the
/// rows-without-titles count is asserted separately — a page of 20 empty rows would
/// otherwise read as a working search.
List<String> titlesIn(String html) {
  return html_parser
      .parse(html)
      .querySelectorAll(rowSelector)
      .map(
        (dom.Element row) =>
            row
                .querySelector('h2.fiction-title')
                ?.text
                .trim()
                .replaceAll(RegExp(r'\s+'), ' ') ??
            '',
      )
      .toList();
}

void main() {
  // ⚠️ **Parsed at file-scope, not in `setUpAll`.** The per-query rows below are
  // declared by a `for` loop over the queries, and a loop in a `group` body runs when
  // `main()` runs — long before any `setUpAll`. The first draft read `verdictJson` in
  // `setUpAll` and every one of those rows was generated from `null`, which surfaced
  // as a load failure rather than as the "the fixture moved" failure it actually was.
  if (!verdictFile.existsSync()) {
    throw StateError(
      'the recorded verdict must exist at ${verdictFile.path} — a measurement '
      'nobody kept is a measurement nobody can check, and this file exists so it '
      'can be re-derived',
    );
  }
  verdictJson =
      jsonDecode(verdictFile.readAsStringSync()) as Map<String, Object?>;
  final List<Map<String, Object?>> queries =
      (verdictJson['queries']! as List<Object?>).cast<Map<String, Object?>>();

  group('the measurement helper itself', () {
    test('the visible-text counter can still find a marker', () {
      // ⚠️ **The witness.** A counter that always returned 0 would make every marker
      // row pass, and "the marker is absent from both result pages" is the row that
      // decides whether BrowseEmpty is reachable. A check that cannot fail proves
      // nothing — and this check has already been written once from the conclusion
      // instead of from the page, so it gets the witness the first version lacked.
      expect(
        _visibleTextOccurrences(
          '<html><body><h4>No results matching these criteria were found</h4>'
              '</body></html>',
          'No results matching these criteria were found',
        ),
        1,
      );
    });

    test('it excludes what is not visible — a script is not a marker', () {
      expect(
        _visibleTextOccurrences(
          '<html><body><script>var x = "No results";</script></body></html>',
          'No results',
        ),
        0,
        reason:
            'a literal inside a script is not a site-supplied empty signal — it is '
            'the page describing itself, which is exactly what 0-2 ruled out',
      );
    });
  });

  group('the recorded verdict exists and is complete', () {
    test('the file names the site, the date, the UA and the method', () {
      expect(verdictJson['site'], 'Royal Road');
      expect(verdictJson['measuredAt'], isA<String>());
      expect(
        verdictJson['measuredAt'],
        matches(RegExp(r'^\d{4}-\d{2}-\d{2}$')),
        reason: 'an undated measurement cannot go stale visibly',
      );
      expect(verdictJson['userAgent'], contains('LumenTale/'));
      for (final String impersonation in <String>[
        'Mozilla',
        'Chrome/',
        'Safari/',
        'WebKit',
      ]) {
        expect(
          verdictJson['userAgent'].toString(),
          isNot(contains(impersonation)),
          reason: 'ADR-014: an honest agent, never a browser pretending',
        );
      }
      expect(
        verdictJson['method'].toString(),
        contains('MUST match'),
        reason:
            'a measurement with only a matching query cannot distinguish a search '
            'from a page that always lists something',
      );
    });

    test('there is at least one query that must match and one that must not', () {
      final List<Object?> queries = verdictJson['queries']! as List<Object?>;
      expect(
        queries.where(
          (Object? q) => (q! as Map<String, Object?>)['mustMatch'] == true,
        ),
        isNotEmpty,
      );
      expect(
        queries.where(
          (Object? q) => (q! as Map<String, Object?>)['mustMatch'] == false,
        ),
        isNotEmpty,
        reason:
            'without a control query the positive result proves nothing — the page '
            'might always show N rows',
      );
    });
  });

  group('THE GUARD — the recorded verdict is re-derived from the fixtures', () {
    late List<Map<String, Object?>> queries;

    setUpAll(() {
      queries = (verdictJson['queries']! as List<Object?>)
          .cast<Map<String, Object?>>();
    });

    for (final Map<String, Object?> query
        in (verdictJson['queries'] as List<Object?>)
            .cast<Map<String, Object?>>()) {
      final String label =
          '${query['query']} (mustMatch: ${query['mustMatch']})';

      test('$label — the row count in the fixture is the row count recorded', () {
        final File fixture = fixtureFor('${query['fixture']}'.split('/').last);
        expect(
          fixture.existsSync(),
          isTrue,
          reason: '$fixture must be captured',
        );

        final int recorded = query['rows']! as int;
        expect(
          rowsIn(fixture.readAsStringSync()).length,
          recorded,
          reason:
              'the fixture no longer holds the rows the verdict was derived from — '
              'the page changed, or the fixture was replaced',
        );
      });

      test('$label — the HTTP status recorded is a success', () {
        final int status = query['httpStatus']! as int;
        expect(
          status,
          inInclusiveRange(200, 299),
          reason:
              'rule 5a: a 404, a meta-refresh, a timeout or a 5xx means the endpoint '
              'is not there, whatever the body says',
        );
      });

      test('$label — the byte count recorded is the byte count captured', () {
        final File fixture = fixtureFor('${query['fixture']}'.split('/').last);
        expect(
          fixture.lengthSync(),
          query['bytes'],
          reason:
              'a changed byte count means the page changed since the verdict; the '
              'verdict may still hold, but nobody has looked',
        );
      });
    }

    test('every matching query returned rows that CARRY the queried words', () {
      // ADR-015's actual criterion: results **a reader would call useful**. A count
      // of 20 is not that. The titles have to contain the words the reader typed,
      // because the site offers no relevance signal we can read.
      for (final Map<String, Object?> query in queries) {
        if (query['mustMatch'] != true) continue;

        final List<String> words = (query['query']! as String)
            .split('+')
            .expand((String w) => w.split(' '))
            .map((String w) => w.toLowerCase())
            .where((String w) => w.length > 2)
            .toList();
        expect(words, isNotEmpty, reason: 'a control needs a real word');

        final List<String> titles = titlesIn(
          fixtureFor('${query['fixture']}'.split('/').last).readAsStringSync(),
        );
        final int relevant = titles
            .where(
              (String title) =>
                  words.any((String w) => title.toLowerCase().contains(w)),
            )
            .length;

        expect(
          relevant,
          greaterThanOrEqualTo(5),
          reason:
              'only $relevant of ${titles.length} titles for "${query['query']}" '
              'carry a queried word. Under ADR-015 that is a page listing '
              'something, not a search.',
        );
      }
    });

    test('every row on a matching query has a title', () {
      for (final Map<String, Object?> query in queries) {
        if (query['mustMatch'] != true) continue;
        final List<String> titles = titlesIn(
          fixtureFor('${query['fixture']}'.split('/').last).readAsStringSync(),
        );
        expect(
          titles.where((String t) => t.isEmpty).toList(),
          isEmpty,
          reason: 'a row with no title is not a result a reader can choose',
        );
      }
    });

    test('the non-matching query returned NO rows', () {
      final Map<String, Object?> control = queries.firstWhere(
        (Map<String, Object?> q) => q['mustMatch'] == false,
      );
      expect(control['rows'], 0);
      expect(
        rowsIn(
          fixtureFor(
            '${control['fixture']}'.split('/').last,
          ).readAsStringSync(),
        ),
        isEmpty,
      );
    });
  });

  group('the zero-row page DOES carry the site own empty marker', () {
    test('the marker appears once on the control and nowhere on a result page', () {
      // ⚠️ **This group is the correction of the first reading of this file.**
      // The first version listed `'No results'` among the markers it checked and then
      // asserted that **no checked marker was present** — the list contained its own
      // answer, and the assertion was written from the conclusion rather than from
      // the page. It failed on the first run against the capture it was written
      // from, which is the only reason this is a correction and not a silent wrong
      // turn that shipped.
      //
      // The measurement is a **discriminator**, so it is checked on both sides:
      // present once on the zero-row page, absent from BOTH 20-row pages. A literal
      // that appears everywhere discriminates nothing.
      final Map<String, Object?> control = queries.firstWhere(
        (Map<String, Object?> q) => q['mustMatch'] == false,
      );
      final String marker = control['emptyMarker']! as String;

      expect(
        marker,
        isNotEmpty,
        reason: 'a recorded marker that is empty proves nothing',
      );
      expect(control['carriesEmptyMarker'], isTrue);

      expect(
        _visibleTextOccurrences(
          fixtureFor(
            '${control['fixture']}'.split('/').last,
          ).readAsStringSync(),
          marker,
        ),
        1,
        reason:
            'the marker must appear in VISIBLE text on the zero-row page — a marker '
            'inside a script or a comment is not something a reader was shown',
      );

      for (final Map<String, Object?> query in queries) {
        if (query['mustMatch'] != true) continue;
        expect(
          _visibleTextOccurrences(
            fixtureFor(
              '${query['fixture']}'.split('/').last,
            ).readAsStringSync(),
            marker,
          ),
          0,
          reason:
              'the marker appears on a page WITH results for "${query['query']}" — '
              'then it discriminates nothing and BrowseEmpty must stay unreachable',
        );
      }
    });

    test('the marker sits inside the container the site puts it in', () {
      // Recorded so a later slice that has to SELECT the marker does not grep for the
      // text and find the site's own scripts on the way.
      final Map<String, Object?> control = queries.firstWhere(
        (Map<String, Object?> q) => q['mustMatch'] == false,
      );
      final dom.Document document = html_parser.parse(
        fixtureFor('${control['fixture']}'.split('/').last).readAsStringSync(),
      );
      final dom.Element? holder = document.querySelector(
        control['emptyMarkerSelector']! as String,
      );
      expect(
        holder,
        isNotNull,
        reason:
            'the recorded selector must still resolve — '
            '${control['emptyMarkerSelector']}',
      );
      expect(
        _visibleTextOccurrences(
          holder!.outerHtml,
          control['emptyMarker']! as String,
        ),
        1,
      );
    });

    test('a zero-row page uses the SAME shell as a page with rows', () {
      // 97 498 bytes against 250 980 — the difference is the rows, not a different or
      // error page. This is what makes the zero-row case *distinguishable* from a
      // broken source at all, and it is asserted from the fixtures rather than from
      // the recorded byte counts, so it re-derives.
      final Map<String, Object?> control = queries.firstWhere(
        (Map<String, Object?> q) => q['mustMatch'] == false,
      );
      final Map<String, Object?> matching = queries.firstWhere(
        (Map<String, Object?> q) => q['mustMatch'] == true,
      );

      final String emptyHtml = fixtureFor(
        '${control['fixture']}'.split('/').last,
      ).readAsStringSync();
      final String fullHtml = fixtureFor(
        '${matching['fixture']}'.split('/').last,
      ).readAsStringSync();

      expect(fullHtml.length, greaterThan(emptyHtml.length));
      expect(emptyHtml, contains('<html'));
      expect(emptyHtml.toLowerCase(), contains('royal road'));
      expect(emptyHtml, isNot(contains('Just a moment')));
      expect(emptyHtml, isNot(contains('challenges.cloudflare.com')));
    });

    test('the BROWSE side still has no marker — the 0-2 retraction stands', () {
      // The two are different pages, and one measurement must not become a policy on
      // both. `0-2` measured the catalogue; this row exists so a later session
      // reading "Royal Road has an empty marker" does not apply it to browse.
      final File catalogue = File(
        'test/fixtures/sources/royalroad/catalogue-active-popular-page0.html',
      );
      expect(catalogue.existsSync(), isTrue);
      final String catalogueHtml = catalogue.readAsStringSync();

      for (final Map<String, Object?> query in queries) {
        if (query['mustMatch'] != false) continue;
        expect(
          _visibleTextOccurrences(
            catalogueHtml,
            query['emptyMarker']! as String,
          ),
          0,
          reason:
              'the search marker appears on a BROWSE page too — then the two stages '
              'are not independent and 0-2 needs re-measuring',
        );
      }
      expect(
        _visibleTextOccurrences(catalogueHtml, 'There is nothing here'),
        0,
        reason:
            '0-2 retracted this literal after measuring it against a live catalogue; '
            'if it is back, that retraction is stale',
      );
    });
  });
  group('the verdict', () {
    test('supportsSearch is true, and the basis is recorded', () {
      final Map<String, Object?> verdict =
          verdictJson['verdict']! as Map<String, Object?>;
      expect(verdict['supportsSearch'], isTrue);
      expect(
        verdict['basis'].toString().length,
        greaterThan(80),
        reason:
            'a bare `true` is not a verdict; ADR-015 asks for the basis and this '
            'file exists so the basis survives',
      );
    });

    test('the consequence for BrowseEmpty is written down', () {
      // The reader of this file has to be able to act on it without re-deriving. A
      // verdict that does not say what it changes is a verdict that gets applied to
      // nothing.
      final List<Object?> consequences =
          verdictJson['consequences']! as List<Object?>;
      expect(consequences, isNotEmpty);
      expect(
        consequences.any((Object? c) => c.toString().contains('BrowseEmpty')),
        isTrue,
        reason:
            'the measured consequence is that BrowseEmpty is unreachable — if that '
            'is not written down, a later slice will make it reachable by accident',
      );
    });

    test('what was NOT measured is recorded, not left implied', () {
      // § 9 of the skill: an assumption that was never verified has to be visible.
      expect(verdictJson['notMeasured'], isA<List<Object?>>());
      expect(verdictJson['notMeasured'], isNotEmpty);
    });
  });

  group('Novel Fire was not measurable at all', () {
    test('the file says so instead of claiming false', () {
      // ⚠️ A Cloudflare challenge is **not** "no results" and **not** "a broken
      // search endpoint". Writing `supportsSearch = false` from a 403 would be a
      // claim the evidence does not support, and ADR-015's whole purpose is to stop
      // flags being set from guesses.
      //
      // Recorded 2026-10-03 with the honest UA: every path answers 403 with a
      // `Just a moment...` interstitial carrying `challenges.cloudflare.com` —
      // the same wall FanMTL hit the same day (F-012). ADR-014 measured Novel Fire at
      // 200 on 2026-10-02, so **the site changed and the client did not.**
      //
      // No bypass will be built. A challenge is the site declining; the correct
      // response is to record it.
      final List<Object?> consequences =
          verdictJson['consequences']! as List<Object?>;
      expect(
        consequences.last.toString(),
        contains('Novel Fire'),
        reason:
            'the unmeasured site must be named where the verdict is read, or a later '
            'session will read `supportsSearch: true` as covering the whole registry',
      );
    });
  });
}
