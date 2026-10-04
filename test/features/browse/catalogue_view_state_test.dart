// Lumen Tale — `3-1`: B22 made visible. SC-6 is "a site that cannot be read looks like a
// site with nothing in it".
//
// ## Every row here is about one thing a reader cannot tell apart by looking
//
// | the screen could draw | the reader concludes |
// |---|---|
// | an empty list | this tag has no novels |
// | a failure list | this tag has no novels, **and the site is fine** |
//
// The defence is a **total mapping** the compiler enforces, so this file tests the mapping and
// the screens that render it — never a `switch` that could forget a case.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lumen_tale/core/error/source_failure.dart';
import 'package:lumen_tale/domain/sources/browse_outcome.dart';
import 'package:lumen_tale/domain/sources/models/novel.dart';
import 'package:lumen_tale/domain/sources/models/novels_page.dart';
import 'package:lumen_tale/features/browse/catalogue_states.dart';
import 'package:lumen_tale/features/browse/catalogue_view_state.dart';
import 'package:lumen_tale/l10n/generated/app_localizations.dart';

Novel novel(String id, {String? author}) => Novel(
  id: id,
  sourceId: 'royalroad',
  url: '/fiction/$id/x',
  title: 'Novel $id',
  author: author,
  coverUrl: null,
  description: 'A description.',
  genres: const <String>[],
  status: NovelStatus.ongoing,
);

BrowseOutcome<NovelsPage> succeeded(
  List<Novel> novels, {
  bool hasNext = false,
}) {
  return BrowseSucceeded<NovelsPage>(<NovelsPage>[
    NovelsPage(novels: novels, hasNextPage: hasNext),
  ]);
}

CatalogueViewState map(
  BrowseOutcome<NovelsPage> outcome, {
  int requestedPage = 1,
  String tag = 'litrpg',
}) {
  return mapBrowseOutcome(
    outcome: outcome,
    sourceName: 'Royal Road',
    tag: tag,
    requestedPage: requestedPage,
  );
}

void main() {
  group('the mapping is TOTAL, and a failure never becomes a list', () {
    test('a page with novels is the list', () {
      final CatalogueViewState state = map(succeeded(<Novel>[novel('a')]));
      expect(state, isA<CatalogueFilled>());
      expect((state as CatalogueFilled).items, hasLength(1));
      expect(state.page, 1);
    });

    test('⚠️ a TYPED failure is NOT an empty list, ever', () {
      // ⚠️ **The row SC-6 exists for.** `BrowseFailed` with a layout change is a site the app
      // could not read; drawing a list — or an empty one — tells the reader the opposite.
      for (final SourceFailure failure in <SourceFailure>[
        const SourceLayoutChanged(failedSelector: 'tr', status: 200),
        const SourceUnavailable(status: 503),
        const NoConnection(host: 'www.royalroad.com'),
        const ParseFailed(path: '/fictions/active-popular'),
      ]) {
        final CatalogueViewState state = map(
          BrowseFailed<NovelsPage>(failure, retriable: false),
        );
        expect(
          state,
          isA<CatalogueSourceUnreadable>(),
          reason: failure.toString(),
        );
        expect(state, isNot(isA<CatalogueFilled>()));
        expect(state, isNot(isA<CatalogueEmptyTag>()));
      }
    });

    test('⚠️ an empty page 1 is an EMPTY TAG, and says which', () {
      final CatalogueViewState state = map(succeeded(const <Novel>[]));
      expect(state, isA<CatalogueEmptyTag>());
      expect((state as CatalogueEmptyTag).tag, 'litrpg');
      expect(state.sourceName, 'Royal Road');
    });

    test('⚠️ an empty page 2 is a LAYOUT CHANGE, not an empty tag', () {
      // ⚠️ **The row that carries SC-6's harder half.** "No results" is never said of page 2
      // of a tag that had thirty on page 1: that would erase half the list in front of a
      // reader who is scrolling.
      final CatalogueViewState state = map(
        succeeded(const <Novel>[]),
        requestedPage: 2,
      );
      expect(state, isA<CatalogueSourceUnreadable>());
      expect(
        (state as CatalogueSourceUnreadable).failure,
        isA<SourceLayoutChanged>(),
      );
    });

    test("⚠️ the site's OWN marker is a separate state and is kept verbatim", () {
      // ⚠️ **"This tag is empty" and "the site said it has nothing" are different claims**, and
      // the whole value of the second is the site's own words — quoted, never paraphrased.
      const String marker = 'There is nothing here :(';
      final CatalogueViewState state = map(
        const BrowseEmpty<NovelsPage>(siteSuppliedSignal: marker),
      );
      expect(state, isA<CatalogueSiteSaidNothing>());
      expect((state as CatalogueSiteSaidNothing).siteSuppliedSignal, marker);
    });

    test('⚠️ an AsyncError is NO CONNECTION, and never an empty tag', () {
      // ⚠️ **The tempting branch.** "We could not reach the site" and "this tag has nothing"
      // are both short sentences, and the second one is a lie that erases a working feature
      // from the reader's head.
      final CatalogueViewState state = mapAsyncError(
        sourceName: 'Royal Road',
        tag: 'litrpg',
        error: StateError('boom'),
      );
      expect(state, isA<CatalogueNoConnection>());
      expect(state, isNot(isA<CatalogueEmptyTag>()));
      expect(state, isNot(isA<CatalogueFilled>()));
    });

    test('⚠️ a SUCCESS carrying ZERO PAGES is broken, not empty', () {
      // ⚠️ **Unreachable from a well-behaved source**, because the discriminator classifies
      // zero items as broken for the catalogue stage. But if a source ever hands it over, the
      // honest reading is "we could not read a page" — and "this tag has no novels" is a claim
      // about the site this app has no evidence for.
      final CatalogueViewState state = map(
        const BrowseSucceeded<NovelsPage>(<NovelsPage>[]),
      );
      expect(state, isA<CatalogueSourceUnreadable>());
    });
  });

  group('hasMore is the SITE\'s signal and is never invented', () {
    test('the site said there is more', () {
      final CatalogueViewState state = map(
        succeeded(<Novel>[novel('a')], hasNext: true),
      );
      expect((state as CatalogueFilled).hasMore, isTrue);
    });

    test('the site said there is not', () {
      final CatalogueViewState state = map(succeeded(<Novel>[novel('a')]));
      expect((state as CatalogueFilled).hasMore, isFalse);
    });

    test('⚠️ an unset signal renders NO footer, never a guess', () {
      // ⚠️ `mapBrowseOutcome` takes `hasMore` as a parameter because `BrowseSucceeded` hands
      // over a list and nothing else. A caller that did not pass it gets "no more" — the
      // conservative direction, because an invented "load more" offers a page that is not there.
      final CatalogueViewState state = mapBrowseOutcome(
        outcome: succeeded(<Novel>[novel('a')], hasNext: true),
        sourceName: 'Royal Road',
        tag: 'litrpg',
        requestedPage: 1,
      );
      expect((state as CatalogueFilled).hasMore, isTrue);
    });
  });

  group('retry is offered only where a second attempt is honest', () {
    test('⚠️ a LAYOUT CHANGE offers NO retry', () {
      // ⚠️ **A retry button on a layout change teaches a reader that the app does not know what
      // it is doing** — the page will answer 200 with the same markup tomorrow.
      final CatalogueSourceUnreadable state =
          map(
                const BrowseFailed<NovelsPage>(
                  SourceLayoutChanged(failedSelector: 'tr', status: 200),
                  retriable: false,
                ),
              )
              as CatalogueSourceUnreadable;
      expect(state.canRetry, isFalse);
    });

    test('no connection IS retriable', () {
      final CatalogueSourceUnreadable state =
          map(
                const BrowseFailed<NovelsPage>(
                  NoConnection(host: 'x'),
                  retriable: true,
                ),
              )
              as CatalogueSourceUnreadable;
      expect(state.canRetry, isTrue);
    });
  });

  group('the screens, and what each one says first', () {
    Future<void> pumpState(WidgetTester tester, CatalogueViewState state) {
      return tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: CatalogueStates.forState(state)),
        ),
      );
    }

    testWidgets('the unreadable state leads with what is NOT wrong', (
      WidgetTester tester,
    ) async {
      // ⚠️ **SC-6's only surface, and the sentence that defuses it.** A reader whose catalogue
      // failed assumes the APP is broken and that the failure ate their downloads; both are
      // wrong and neither is self-correcting.
      await pumpState(
        tester,
        const CatalogueSourceUnreadable(
          sourceName: 'Royal Road',
          tag: 'litrpg',
          failure: SourceLayoutChanged(failedSelector: 'tr', status: 200),
        ),
      );

      expect(find.textContaining('could not be read'), findsOneWidget);
      expect(
        find.textContaining('Nothing is wrong with your library'),
        findsOneWidget,
      );
      expect(find.textContaining('nothing was downloaded'), findsOneWidget);
      // ⚠️ **And it never says "0".**
      expect(find.textContaining('0 '), findsNothing);
    });

    testWidgets('⚠️ the unreadable state offers NO retry for a layout change', (
      WidgetTester tester,
    ) async {
      await pumpState(
        tester,
        const CatalogueSourceUnreadable(
          sourceName: 'Royal Road',
          tag: 'litrpg',
          failure: SourceLayoutChanged(failedSelector: 'tr', status: 200),
        ),
      );

      expect(find.widgetWithText(FilledButton, 'Retry'), findsNothing);
      expect(find.text('Open library'), findsOneWidget);
    });

    testWidgets('no connection says the LIBRARY is fine', (
      WidgetTester tester,
    ) async {
      await pumpState(
        tester,
        const CatalogueNoConnection(sourceName: 'Royal Road'),
      );

      expect(find.text('No connection'), findsOneWidget);
      expect(find.textContaining('Your library is unaffected'), findsOneWidget);
    });

    testWidgets('the empty-tag state echoes the tag and is NOT an error', (
      WidgetTester tester,
    ) async {
      // ⚠️ **An inbox icon and no retry.** A warning triangle on "this tag is empty" teaches a
      // reader that an empty tag is a fault, and the next one gets dismissed unread.
      await pumpState(
        tester,
        const CatalogueEmptyTag(sourceName: 'Royal Road', tag: 'litrpg'),
      );

      expect(find.text('Nothing tagged litrpg'), findsOneWidget);
      expect(find.byIcon(Icons.inbox_outlined), findsOneWidget);
      expect(find.byIcon(Icons.cloud_off_outlined), findsNothing);
    });

    testWidgets('the site\'s own marker is shown QUOTED', (
      WidgetTester tester,
    ) async {
      await pumpState(
        tester,
        const CatalogueSiteSaidNothing(
          sourceName: 'Royal Road',
          siteSuppliedSignal: 'There is nothing here :(',
        ),
      );

      expect(find.textContaining('There is nothing here :('), findsOneWidget);
    });

    testWidgets(
      '⚠️ a FILLED state routed here throws rather than drawing nothing',
      (WidgetTester tester) async {
        // ⚠️ **A wrong route is a bug, and saying so is better than a blank screen.** A reader
        // looking at an empty area has no idea anything failed; a thrown StateError in a test
        // points straight at the dispatcher.
        expect(
          () => CatalogueStates.forState(map(succeeded(<Novel>[novel('a')]))),
          throwsStateError,
        );
      },
    );
  });

  group('the screen cannot reach the network by another route', () {
    test('⚠️ the catalogue names no client and no source directly', () {
      // ⚠️ **B22 is one mapping, and a screen that reached a `Source` would own a second.**
      final String code = _codeOf('lib/features/browse/catalogue_screen.dart');
      expect(code, isNot(contains('dio')));
      expect(code, isNot(contains('HttpClient')));
      expect(code, isNot(contains('RoyalRoadSource')));
      // ⚠️ **And no connectivity probe**: whether the site answered is the source attempt's own
      // report, and a probe that says "online" beside a site that timed out produces two
      // answers to one question.
      expect(code.toLowerCase(), isNot(contains('connectivity')));
    });
  });
}

String _codeOf(String path) {
  return File(path)
      .readAsStringSync()
      .split('\n')
      .where((String line) => !line.trimLeft().startsWith('//'))
      .join('\n');
}
