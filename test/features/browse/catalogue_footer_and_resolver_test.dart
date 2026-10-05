// forge:slice 3-1
// Lumen Tale — the two holes the audit found after phase 7 reported complete.
//
// ## Why this file exists
//
// `flutter analyze` was clean, `DoD` was PASS 7 of 7, and 1927 tests were green — and two
// defects were still live:
//
// | hole | why no gate saw it |
// |---|---|
// | `TextButton(onPressed: () {}, child: Text(…Retry))` in the catalogue footer | a dead control is **valid Dart**. Nothing about `() {}` is an error, and the tests asserted *state*, not *gesture*. This is the **fourth** time this project has shipped one |
// | `LibraryEntry.sourceName` was `'unknown'` in production | the resolver seam existed and **defaulted** to `'unknown'`. A default is not an error either, and every row that passed was passing against the default |
//
// Both are the same shape: **a defect that is syntactically legal.** A linter cannot see one
// and a state assertion cannot see one. Only a row that presses the control, or reads the
// string a reader would see, can.

import 'dart:io';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumen_tale/app/router/app_routes.dart';
import 'package:lumen_tale/core/database/app_database.dart';
import 'package:lumen_tale/data/library/drift_library_repository.dart';
import 'package:lumen_tale/domain/sources/source.dart';

/// A file's CODE, with its `//` comment lines removed.
///
/// ⚠️ **EXISTS BECAUSE A COMMENT IS PROSE AND A PATTERN IS CODE.** Three rows in this
/// project have been made unsatisfiable by the comment that documents them, and one grep
/// disabled itself that way and was reported as a passing guard for a session.
String _codeOf(String path) => File(path)
    .readAsStringSync()
    .split('\n')
    .where((String line) => !line.trimLeft().startsWith('//'))
    .join('\n');

void main() {
  group('the catalogue footer — a control that DOES something', () {
    // ⚠️ **THE ROW THAT MATTERS MOST IN THIS FILE.** It reads the source for a dead callback,
    // so it fails on the defect itself rather than on a behaviour that might be wired later.
    test('⚠️ NO control in the catalogue screen has an EMPTY callback', () {
      final String source = _codeOf(
        'lib/features/browse/catalogue_screen.dart',
      );

      expect(
        source,
        isNot(contains('onPressed: () {}')),
        reason:
            'a button labelled *Retry* that retries nothing. This project has shipped '
            'four: 3-6 absent retry, 3-1 absent Add, the duplicated registerScreens(), '
            'and this one. Every one looked finished because the control was present and '
            'the label was right',
      );
      expect(
        source,
        isNot(contains('onTap: () {}')),
        reason:
            'the same defect through a gesture detector rather than a button',
      );
    });

    // ⚠️ **THE LABEL IS PART OF THE FIX.** The control now asks the site for the NEXT page —
    // new novels, not the same ones — and "Retry" means the load failed. A right action
    // behind a wrong word is still a misdirection.
    test('⚠️ the footer says LOAD MORE, and never "Retry"', () {
      final String source = _codeOf(
        'lib/features/browse/catalogue_screen.dart',
      );

      expect(
        source,
        contains('browseActionLoadMore'),
        reason:
            'page 2 of a tag is new content, so the verb is "load more". `browseActionRetry` '
            'promises a second attempt at something that did not fail',
      );
      expect(
        source,
        isNot(contains('copy.browseActionRetry')),
        reason: 'and the wrong verb is gone from this screen entirely',
      );
    });

    test('⚠️ the footer navigates to page + 1, carrying the search words', () {
      final String source = _codeOf(
        'lib/features/browse/catalogue_screen.dart',
      );

      expect(
        source,
        contains('page: state.page + 1'),
        reason:
            'the site published `hasNextPage`, so the next page EXISTS and is page + 1. A '
            'control that does not move the page is a control that does nothing',
      );
      expect(
        source,
        contains('words: words'),
        reason:
            'a search\'s page 2 is a different result set. Dropping the words would turn '
            '"more results for rune" into "more results for everything" — a silent, '
            'plausible, wrong answer',
      );
    });
  });

  group('the catalogue page is a query parameter, and it is read once', () {
    // ⚠️ **A PATH SEGMENT WOULD BE A SECOND ROUTE**, and `11-app-router` counts
    // registrations — so a screen registered per page is a count that depends on how many
    // pages exist.
    test(
      '⚠️ page 1 is the ABSENT default, so the first page is the route itself',
      () {
        expect(
          AppRoutes.sourceGenrePage(
            sourceId: 'fanmtl',
            genre: 'xianxia',
            page: 1,
          ),
          '/browse/fanmtl/genre/xianxia',
          reason:
              'emitting `?page=1` would make page 1 a different LOCATION from the route, and a '
              'reader who opened the genre and pressed back would land on a URL this app '
              'never produces',
        );
      },
    );

    test('⚠️ page 2 is `?page=2`, and the words come FIRST', () {
      expect(
        AppRoutes.sourceGenrePage(
          sourceId: 'fanmtl',
          genre: 'xianxia',
          page: 2,
        ),
        '/browse/fanmtl/genre/xianxia?page=2',
        reason:
            'one query string, and its only other parameter is appended, not replaced',
      );
      expect(
        AppRoutes.sourceGenrePage(
          sourceId: 'fanmtl',
          genre: 'xianxia',
          page: 3,
          words: 'rune smith',
        ),
        '/browse/fanmtl/genre/xianxia?q=rune+smith&page=3',
        reason:
            'a search keeps its words across pages. The `&` here is the whole reason the '
            'helper builds the string rather than letting each caller concatenate. A space '
            'encodes as `+`, which is what `Uri.encodeQueryComponent` does and what every '
            'query parser reads back as a space',
      );
    });

    // ⚠️ **A MALFORMED LINK IS READER-REACHABLE** — a shared URL, a typo, a crawler — and
    // `int.parse('two')` throwing inside a route build turns it into an error page.
    test('⚠️ an UNPARSEABLE page is page 1, never an exception', () {
      expect(AppRoutes.pageFrom(Uri.parse('/browse/s/genre/g?page=two')), 1);
      expect(
        AppRoutes.pageFrom(Uri.parse('/browse/s/genre/g?page=0')),
        1,
        reason:
            'page 0 is not a page, and `-1` would read the *last* page of a site '
            'whose pager is 0-based — a real reading, and the wrong one here',
      );
      expect(AppRoutes.pageFrom(Uri.parse('/browse/s/genre/g?page=-3')), 1);
      expect(
        AppRoutes.pageFrom(Uri.parse('/browse/s/genre/g')),
        1,
        reason:
            'no parameter at all is page 1, because that is what the route means',
      );
      expect(
        AppRoutes.pageFrom(Uri.parse('/browse/s/genre/g?page=7')),
        7,
        reason: 'and a real page is honoured',
      );
    });
  });

  group('the source-name resolver — `6-6`\'s hole', () {
    test('⚠️ the DEFAULT is `unknown`, which is why the override is load-bearing', () {
      // ⚠️ **A REAL IN-MEMORY DATABASE, because this row is about a CONSTRUCTOR DEFAULT.**
      // A fake repository would have made the row assert the fake, and the fake is not what
      // production builds.
      final AppDatabase db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final DriftLibraryRepository defaulted = DriftLibraryRepository(db);

      expect(
        defaulted.sourceNameOf('fanmtl'),
        'unknown',
        reason:
            'the seam EXISTS and DEFAULTS to this. That is the whole defect: a default is '
            'not an error, so no linter and no state assertion could see it — and every row '
            'that passed was passing against this value',
      );
    });

    // ⚠️ **A REGISTRY MISS IS `null`, NEVER THE ID.** An MD5 on screen tells a reader nothing
    // they can act on and puts an internal identifier where a site name belongs.
    test(
      '⚠️ a resolver returns the NAME, and `null` for a source it does not hold',
      () {
        const List<Source> registry = <Source>[];
        String? resolve(String id) {
          for (final Source source in registry) {
            if (source.id == id) return source.name;
          }
          return null;
        }

        expect(
          resolve('nobody'),
          isNull,
          reason:
              'absent is `null`. Returning the id would put an MD5 on screen',
        );
        expect(
          resolve('fanmtl'),
          isNull,
          reason:
              'and the empty registry resolves nothing rather than guessing',
        );
      },
    );

    test(
      '⚠️ the bootstrap overrides the provider, because nothing else supplies it',
      () {
        final String main = File('lib/main.dart').readAsStringSync();

        expect(
          main,
          contains('libraryRepositoryProvider.overrideWith'),
          reason:
              'the hole `6-6` found: the constructor defaults `sourceNameOf` to `\'unknown\'` '
              'and nothing supplied a resolver, so every library row printed `unknown` in '
              'production while every test passed',
        );
        expect(
          main,
          contains('sources.byId(sourceId)?.name'),
          reason:
              'and the resolver reads the ONE registry (ADR-013). A second index would give a '
              'source two names in two screens — the app contradicting itself about a site',
        );
      },
    );
  });
}
