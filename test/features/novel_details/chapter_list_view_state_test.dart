// Lumen Tale — `3-2`: nine chapter-list states, and the three rows where a reader could not
// tell two of them apart.
//
// ## The rows that carry the slice
//
// | the rule | the row |
// |---|---|
// | B12 — a list nobody asked for is **not** an empty list | *never loaded offers Load and is NOT an error* |
// | E5 — *not asked* + *no connection* is a **precondition**, not a failure | *it is its own class, and offers NO load* |
// | B22 — an unreadable site is never "0 chapters" | *the unreadable state never says a count* |
// | B9 — the order is the site's, never re-derived | *the ordinal is the site's list position* |
// | B10 — `-1` never reaches a tile, `0` stays `0` | *an unreadable number is an em dash* |

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumen_tale/core/error/source_failure.dart';
import 'package:lumen_tale/domain/library/chapter_entry.dart';
import 'package:lumen_tale/domain/library/chapter_list_repository.dart';
import 'package:lumen_tale/domain/sources/browse_outcome.dart';
import 'package:lumen_tale/domain/sources/models/chapter.dart';
import 'package:lumen_tale/features/novel_details/chapter_list_view_state.dart';
import 'package:lumen_tale/features/novel_details/novel_details_screen.dart';
import 'package:lumen_tale/features/novel_details/providers/novel_details_providers.dart';
import 'package:lumen_tale/l10n/generated/app_localizations.dart';

ChapterEntry chapter(
  String id, {
  String name = 'Chapter',
  double? number = 1,
  int ordinal = 0,
  bool isRead = false,
  bool isDownloaded = false,
}) => ChapterEntry(
  id: id,
  name: name,
  number: number,
  ordinal: ordinal,
  isRead: isRead,
  isDownloaded: isDownloaded,
);

ChapterListViewState map({
  List<ChapterEntry>? chapters,
  int unopenedCount = 0,
  ChapterListSource source = ChapterListSource.stored,
  String? currentChapterId,
  SourceFailure? siteFailure,
  String siteSuppliedSignal = '',
  bool hasConnection = true,
}) {
  return mapChapterList(
    chapters: chapters ?? const <ChapterEntry>[],
    unopenedCount: unopenedCount,
    source: source,
    currentChapterId: currentChapterId,
    siteFailure: siteFailure,
    siteSuppliedSignal: siteSuppliedSignal,
    hasConnection: hasConnection,
  );
}

Future<void> pumpBody(
  WidgetTester tester,
  ChapterListViewState state, {
  bool isLoading = false,
}) async {
  var loads = 0;
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: ChapterListBody(
          state: state,
          sourceName: 'Royal Road',
          isLoading: isLoading,
          onLoad: () => loads++,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('§ 3.1 — B12: a list nobody asked for is NOT an empty list', () {
    test('nothing stored and nothing asked → *Load*, never an empty list', () {
      final ChapterListViewState state = map();
      expect(state, isA<ChapterListNeverLoaded>());
      // ⚠️ **The state's OWN answer to "can I load this?" is true.** Two call sites ask that
      // question — the notice's button and the header — and two answers to one question is how a
      // screen grows a button its state does not support.
      expect(state.canLoad, isTrue);
      expect(state, isNot(isA<ChapterListFilled>()));
      expect(state, isNot(isA<ChapterListEmptyAtSource>()));
    });

    testWidgets('the notice offers Load, and NOT a count', (
      WidgetTester tester,
    ) async {
      await pumpBody(tester, map());
      expect(find.text('Load the chapter list'), findsOneWidget);
      expect(find.text('The chapters were never loaded'), findsOneWidget);
      // ⚠️ **No "0 chapters" anywhere.** That is the sentence B12 forbids.
      expect(find.textContaining('0 chapters'), findsNothing);
      expect(find.byType(ListView), findsNothing);
    });

    testWidgets('⚠️ tapping Load calls the loader exactly once', (
      WidgetTester tester,
    ) async {
      var loads = 0;
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: ChapterListBody(
              state: map(),
              sourceName: 'Royal Road',
              isLoading: false,
              onLoad: () => loads++,
            ),
          ),
        ),
      );

      await tester.tap(find.text('Load the chapter list'));
      await tester.pumpAndSettle();

      expect(loads, 1, reason: 'one tap, one read — B12 has no other caller');
    });
  });

  group('§ 3.2 — E5: not-asked + no connection is a PRECONDITION, not a failure', () {
    test('⚠️ it is its own class, and it offers NO load', () {
      final ChapterListViewState state = map(hasConnection: false);
      // ⚠️ **A separate class, not `ChapterListSiteUnreadable`.** Nothing failed: a precondition
      // is missing. Naming a site as unreadable when the app never asked it sends the reader
      // looking for a site problem they are not having.
      expect(state, isA<ChapterListNotLoadedNoConnection>());
      expect(state, isNot(isA<ChapterListSiteUnreadable>()));
      expect(
        state.canLoad,
        isFalse,
        reason:
            'offering Load with no connection offers a tap that will fail identically',
      );
    });

    testWidgets('⚠️ and NO Load button is rendered', (
      WidgetTester tester,
    ) async {
      await pumpBody(tester, map(hasConnection: false));
      expect(find.text('No connection'), findsOneWidget);
      expect(find.text('Load the chapter list'), findsNothing);
      expect(
        find.textContaining('Nothing about your library is affected'),
        findsOneWidget,
      );
    });

    test('⚠️ the ordering is what makes them different states', () {
      // ⚠️ **No connection is checked BEFORE "never loaded".** "You have no connection and have
      // not asked" and "you have not asked" are different sentences, and a reader in a tunnel
      // needs the first one to know why the tap did nothing.
      expect(map(), isA<ChapterListNeverLoaded>());
      expect(
        map(hasConnection: false),
        isA<ChapterListNotLoadedNoConnection>(),
      );
    });
  });

  group('§ 3.3 — B22: the four site answers, and only one is "empty"', () {
    test('rows stored → the list', () {
      final ChapterListViewState state = map(
        chapters: <ChapterEntry>[chapter('a'), chapter('b')],
        unopenedCount: 2,
      );
      expect(state, isA<ChapterListFilled>());
      final ChapterListFilled filled = state as ChapterListFilled;
      expect(filled.chapters, hasLength(2));
      expect(filled.unopenedCount, 2);
    });

    test('⚠️ the SITE said it has none → its own class', () {
      final ChapterListViewState state = map(
        source: ChapterListSource.fromSite,
        siteSuppliedSignal: 'There is nothing here :(',
      );
      expect(state, isA<ChapterListEmptyAtSource>());
      // ⚠️ **And it is NOT `ChapterListNeverLoaded`.** "The app has not asked" and "the site
      // said there is nothing" are different claims about the world.
      expect(state, isNot(isA<ChapterListNeverLoaded>()));
    });

    testWidgets(
      '⚠️ the empty-at-source state uses an ICON, not an error icon',
      (WidgetTester tester) async {
        await pumpBody(
          tester,
          map(
            source: ChapterListSource.fromSite,
            siteSuppliedSignal: 'There is nothing here :(',
          ),
        );
        expect(find.text('Royal Road publishes no chapters'), findsOneWidget);
        expect(find.byIcon(Icons.inbox_outlined), findsOneWidget);
        expect(find.byIcon(Icons.cloud_off_outlined), findsNothing);
      },
    );

    test('⚠️ a TYPED failure → unreadable, and NEVER a count of zero', () {
      for (final SourceFailure failure in <SourceFailure>[
        const SourceLayoutChanged(failedSelector: 'tr', status: 200),
        const SourceUnavailable(status: 503),
        const NoConnection(host: 'x'),
        const ParseFailed(path: '/fiction/1/x/chapter/2'),
      ]) {
        final ChapterListViewState state = map(
          source: ChapterListSource.fromSite,
          siteFailure: failure,
        );
        expect(
          state,
          isA<ChapterListSiteUnreadable>(),
          reason: failure.toString(),
        );
        expect(state, isNot(isA<ChapterListEmptyAtSource>()));
        expect(state, isNot(isA<ChapterListNeverLoaded>()));
      }
    });

    testWidgets('⚠️ the unreadable state never renders a chapter count', (
      WidgetTester tester,
    ) async {
      // ⚠️ **SC-6 at one novel's scale.** "0 chapters" here is the exact sentence B22 forbids.
      await pumpBody(
        tester,
        map(
          source: ChapterListSource.fromSite,
          siteFailure: const SourceLayoutChanged(
            failedSelector: 'tr',
            status: 200,
          ),
        ),
      );
      expect(find.textContaining('0 chapters'), findsNothing);
      expect(find.textContaining('Your library is untouched'), findsOneWidget);
      expect(find.byType(ListView), findsNothing);
    });

    test('⚠️ retry only where the CAUSE says a second attempt is honest', () {
      final ChapterListViewState layout = map(
        source: ChapterListSource.fromSite,
        siteFailure: const SourceLayoutChanged(
          failedSelector: 'tr',
          status: 200,
        ),
      );
      final ChapterListViewState down = map(
        source: ChapterListSource.fromSite,
        siteFailure: const SourceUnavailable(status: 503),
      );
      expect(
        (layout as ChapterListSiteUnreadable).canRetry,
        isFalse,
        reason: 'a layout change will answer 200 with the same markup tomorrow',
      );
      expect((down as ChapterListSiteUnreadable).canRetry, isTrue);
    });
  });

  group('§ 3.4 — the states that are NOT about the site', () {
    testWidgets('the stored copy unreadable offers NO load at all', (
      WidgetTester tester,
    ) async {
      // ⚠️ **Loading again would REPLACE the copy with a second truth** — and this state exists
      // precisely because the first truth could not be read. A button here would quietly
      // discard the unread marks along with it.
      await pumpBody(tester, const ChapterListStoredUnreadable());
      expect(find.text('This app cannot read its own copy'), findsOneWidget);
      expect(find.text('Load the chapter list'), findsNothing);
      expect(find.textContaining('the app has not done that'), findsOneWidget);
    });

    testWidgets('the space refusal says HOW MUCH, never "0"', (
      WidgetTester tester,
    ) async {
      await pumpBody(
        tester,
        const ChapterListDownloadRefusedForSpace(
          requiredBytes: 5 * 1024 * 1024,
        ),
      );
      expect(find.text('Not enough space'), findsOneWidget);
      // ⚠️ **Rounded UP, so the number is never below the truth** and never zero.
      expect(find.textContaining('about 5 MB'), findsOneWidget);
      expect(find.textContaining('Nothing was queued'), findsOneWidget);
    });

    testWidgets('⚠️ the marked-read failure says progress was NOT deleted', (
      WidgetTester tester,
    ) async {
      await pumpBody(
        tester,
        const ChapterListMarkedReadFailed(missingChapterId: 'c1'),
      );
      expect(find.text("The app's records disagree"), findsOneWidget);
      expect(
        find.textContaining('has not deleted your progress'),
        findsOneWidget,
      );
    });
  });

  group('B16 — the jump button is ABSENT, not rendered empty', () {
    testWidgets('no current chapter → no button at all', (
      WidgetTester tester,
    ) async {
      await pumpBody(
        tester,
        map(chapters: <ChapterEntry>[chapter('a')], unopenedCount: 1),
      );
      expect(find.text('Go to the current chapter'), findsNothing);
    });

    testWidgets('a current chapter → the button is there', (
      WidgetTester tester,
    ) async {
      await pumpBody(
        tester,
        map(
          chapters: <ChapterEntry>[chapter('a')],
          unopenedCount: 1,
          currentChapterId: 'a',
        ),
      );
      expect(find.text('Go to the current chapter'), findsOneWidget);
    });
  });

  group("B9 — the order is the SITE's, never re-derived", () {
    test("⚠️ the list is emitted in the site's order and nothing re-sorts it", () {
      // ⚠️ **The fixture is deliberately hostile to a re-sort.** It has an *Extra* at number 0,
      // a chapter whose number is `null` because the site published something unreadable, and
      // **two volumes**. Sorting by `number` would move the unreadable one to the front (or
      // crash), and it would interleave the volumes. `ordinal` is the site's order and the only
      // order this app has.
      final List<ChapterEntry> siteOrder = <ChapterEntry>[
        chapter('vol1-ch12-extra', name: 'Extra', number: 0),
        chapter('vol1-ch13', name: 'Chapter 13', number: 13, ordinal: 1),
        chapter('vol1-chomake', name: 'Omake', number: null, ordinal: 2),
        chapter('vol2-ch1', name: 'Vol 2 Chapter 1', ordinal: 3),
        chapter('vol2-ch2', name: 'Vol 2 Chapter 2', number: 2, ordinal: 4),
      ];

      final ChapterListFilled filled =
          map(chapters: siteOrder) as ChapterListFilled;

      expect(filled.chapters.map((ChapterEntry c) => c.id), <String>[
        'vol1-ch12-extra',
        'vol1-ch13',
        'vol1-chomake',
        'vol2-ch1',
        'vol2-ch2',
      ]);
      expect(filled.chapters.map((ChapterEntry c) => c.ordinal), <int>[
        0,
        1,
        2,
        3,
        4,
      ], reason: "the site's own positions, not a re-derivation");
    });
  });

  group('B10 — the `-1` sentinel, and `0`', () {
    test('⚠️ null number renders an EM DASH, never a 0 and never -1', () {
      expect(chapter('a', number: null).numberLabel, '—');
      expect(chapter('a', number: null).numberLabel, isNot('-1'));
    });

    test('⚠️ 0 stays 0 — it is a real chapter', () {
      // ⚠️ **0 is an extra, an omake, an author's note.** Collapsing it into "unknown" is a B10
      // violation, and it is the mistake a `-1`→null mapping invites.
      expect(chapter('a', number: 0).numberLabel, '0');
    });

    test('a whole number drops its decimal point', () {
      expect(chapter('a', number: 12).numberLabel, '12');
    });

    test('⚠️ a fractional number is shown as the site published it', () {
      expect(chapter('a', number: 12.5).numberLabel, '12.5');
    });

    testWidgets('an untitled chapter reads *Untitled*, never an index', (
      WidgetTester tester,
    ) async {
      // ⚠️ B10: a fabricated title is a sentence the app invented and the reader would believe.
      await pumpBody(
        tester,
        map(chapters: <ChapterEntry>[chapter('a', name: '')], unopenedCount: 1),
      );
      expect(find.text('Untitled'), findsOneWidget);
      expect(find.text('Chapter'), findsNothing);
    });
  });

  group('the answer the screen owns', () {
    test('⚠️ a success is NO answer, not an empty one', () {
      // ⚠️ **A success means the rows are now in the database**, and the stored list is the
      // truth. Keeping a "and it was fine" marker beside it would be a second thing to keep in
      // step.
      final ChapterListSiteAnswer? answer = ChapterListSiteAnswer.of(
        const BrowseSucceeded<ChapterListFetchResult>(
          <ChapterListFetchResult>[],
        ),
      );
      expect(answer, isNull);
    });

    test(
      '⚠️ a failure is recorded as a FAILURE, never replaced by an empty success',
      () {
        final ChapterListSiteAnswer? answer = ChapterListSiteAnswer.of(
          const BrowseFailed<ChapterListFetchResult>(
            SourceLayoutChanged(failedSelector: 'tr', status: 200),
            retriable: false,
          ),
        );
        expect(answer, isNotNull);
        expect(answer!.failure, isA<SourceLayoutChanged>());
        expect(answer.saysNothing, isFalse);
      },
    );

    test("the site's own marker is kept verbatim", () {
      final ChapterListSiteAnswer? answer = ChapterListSiteAnswer.of(
        const BrowseEmpty<ChapterListFetchResult>(
          siteSuppliedSignal: 'There is nothing here :(',
        ),
      );
      expect(answer!.siteSuppliedSignal, 'There is nothing here :(');
      expect(answer.failure, isNull);
    });
  });

  group('B5/B12 — the stream never fetches, and the loader fetches once', () {
    test('⚠️ watching the list reads STORAGE and touches nothing else', () async {
      // ⚠️ **B5: a fetch inside a `build` is speculative background work**, and it would make
      // this screen identical whether opened from the library — where the reader asked for it —
      // or from a restored navigation stack, where they did not. So the stream provider's
      // repository is a fake that COUNTS, and the row asserts the count afterwards.
      final CountingRepository repository = CountingRepository();
      final ProviderContainer container = ProviderContainer(
        overrides: [
          chapterListRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);

      // ⚠️ **A `Completer`, not `read().future`.** A `StreamProvider` in Riverpod 3 is a
      // `Refreshable`, and its first value exists only once the stream has emitted — so the row
      // waits for that emission rather than reading a value that is not there yet.
      final Completer<void> emitted = Completer<void>();
      container.listen<AsyncValue<List<ChapterEntry>>>(
        chapterListProvider('n1'),
        (_, AsyncValue<List<ChapterEntry>> next) {
          if (next.hasValue && !emitted.isCompleted) emitted.complete();
        },
        onError: (_, _) {
          if (!emitted.isCompleted) emitted.complete();
        },
      );
      await emitted.future;

      expect(
        repository.fetches,
        0,
        reason: 'watching the stored list asked the site for NOTHING',
      );
      expect(repository.watches, 1);
    });

    test(
      '⚠️ the loader is the ONLY fetch, and it is called once per tap',
      () async {
        // ⚠️ **A provider that fetched on read would be a fetch nobody asked for**, which is the
        // same defect with one more layer in it.
        final CountingRepository repository = CountingRepository();
        final ProviderContainer container = ProviderContainer(
          overrides: [
            chapterListRepositoryProvider.overrideWithValue(repository),
          ],
        );
        addTearDown(container.dispose);

        await container.read(chapterListLoaderProvider)('n1');

        expect(repository.fetches, 1);
        expect(repository.fetchesFor, <String>['n1']);
      },
    );

    test('⚠️ and the tap records the site answer, not the count', () async {
      final CountingRepository repository = CountingRepository(
        outcome: const BrowseFailed<ChapterListFetchResult>(
          SourceLayoutChanged(failedSelector: 'tr', status: 200),
          retriable: false,
        ),
      );
      final ProviderContainer container = ProviderContainer(
        overrides: [
          chapterListRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);

      final BrowseOutcome<ChapterListFetchResult> outcome = await container
          .read(chapterListLoaderProvider)('n1');
      final ChapterListSiteAnswer? answer = ChapterListSiteAnswer.of(outcome);

      // ⚠️ **A failure is kept as a failure.** Replacing it with an empty success is SC-6 in the
      // shape of a stale field.
      expect(answer!.failure, isA<SourceLayoutChanged>());
      expect(
        map(source: ChapterListSource.fromSite, siteFailure: answer.failure),
        isA<ChapterListSiteUnreadable>(),
      );
    });
  });
}

/// A repository that COUNTS, so a row can assert what was and was not asked for.
final class CountingRepository implements ChapterListRepository {
  CountingRepository({this.outcome});

  BrowseOutcome<ChapterListFetchResult>? outcome;

  int watches = 0;
  int fetches = 0;
  final List<String> fetchesFor = <String>[];

  @override
  Stream<List<ChapterEntry>> watchChapters(String novelId) {
    watches++;
    return Stream<List<ChapterEntry>>.value(const <ChapterEntry>[]);
  }

  @override
  Future<int> countUnopened(String novelId) async => 0;

  @override
  Future<int> countAll(String novelId) async => 0;

  @override
  Future<BrowseOutcome<ChapterListFetchResult>> fetchChapterListOnce(
    String novelId, {
    Future<BrowseOutcome<List<Chapter>>> Function()? read,
  }) async {
    fetches++;
    fetchesFor.add(novelId);
    return outcome ??
        const BrowseSucceeded<ChapterListFetchResult>(
          <ChapterListFetchResult>[],
        );
  }
}
