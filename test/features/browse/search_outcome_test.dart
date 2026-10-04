// Lumen Tale — `6-2`: one route, two modes, and one impossible sentence.
//
// ## The rows that carry the slice
//
// | rule | row |
// |---|---|
// | B41 — the words leave **byte for byte** | *double spaces survive* · *case survives* · *an ampersand is ONE parameter* |
// | B50 — a source that declares search and returns nothing usable is a **broken source** | *a typed failure is SearchUnusable* |
// | E19 — "no results" is visibly distinct from a failure | *SearchNothing has no icon, no retry and no error colour* |
// | E8 — a **silent** empty page cannot become "no results" | *BrowseSucceeded with no rows THROWS* |
// | § 3.1 — the field is rendered or absent | *rendersQueryField is a predicate, not a disabled widget* |

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumen_tale/core/error/source_failure.dart';
import 'package:lumen_tale/domain/sources/browse_outcome.dart';
import 'package:lumen_tale/domain/sources/models/chapter.dart';
import 'package:lumen_tale/domain/sources/models/filter.dart';
import 'package:lumen_tale/domain/sources/models/novel.dart';
import 'package:lumen_tale/domain/sources/models/novels_page.dart';
import 'package:lumen_tale/domain/sources/models/update.dart';
import 'package:lumen_tale/domain/sources/source.dart';
import 'package:lumen_tale/features/browse/browse_repository.dart';
import 'package:lumen_tale/features/browse/search_outcome.dart';
import 'package:lumen_tale/features/browse/widgets/catalogue_query_field.dart';

Novel novel(String id) => Novel(
  id: id,
  sourceId: 'royalroad',
  url: '/fiction/$id/x',
  title: 'Novel $id',
  author: null,
  coverUrl: null,
  description: '',
  genres: const <String>[],
  status: NovelStatus.ongoing,
);

BrowseOutcome<NovelsPage> withNovels(List<Novel> novels) =>
    BrowseSucceeded<NovelsPage>(<NovelsPage>[
      NovelsPage(novels: novels, hasNextPage: false),
    ]);

void main() {
  group('§ 3.1 — the field is RENDERED or ABSENT, never disabled', () {
    test('⚠️ the predicate is the decision, and it is one boolean', () {
      expect(rendersQueryField(supportsSearch: true), isTrue);
      expect(rendersQueryField(supportsSearch: false), isFalse);
    });

    testWidgets('⚠️ with no search, NO field is on screen', (
      WidgetTester tester,
    ) async {
      // ⚠️ **The least ambiguous assertion in the slice**, and it is a `find` on the widget
      // type rather than an `if` to be read: a disabled field would still be *found*.
      await _pumpField(tester, supportsSearch: false, initialWords: '');

      expect(find.byType(CatalogueQueryField), findsNothing);
      expect(find.byType(TextField), findsNothing);
    });

    testWidgets('with search, the field is there and holds the query', (
      WidgetTester tester,
    ) async {
      await _pumpField(
        tester,
        supportsSearch: true,
        initialWords: 'mother  of learning',
      );

      expect(find.byType(CatalogueQueryField), findsOneWidget);
      // ⚠️ **Verbatim, so a typo is visible and correctable** rather than silently re-read.
      expect(find.text('mother  of learning'), findsOneWidget);
    });

    testWidgets('⚠️ the field NEVER carries an error state', (
      WidgetTester tester,
    ) async {
      // ⚠️ **`browse-catalogue.md` § 4: the field never turns red.** The query was well-formed
      // and accepted; what failed is the site's answer. Marking the input as errored tells the
      // reader they typed something wrong, which is the one thing that is not true.
      await _pumpField(tester, supportsSearch: true, initialWords: 'anything');

      final InputDecoration decoration = tester
          .widget<TextField>(find.byType(TextField))
          .decoration!;
      expect(decoration.errorText, isNull);
      expect(decoration.error, isNull);
      expect(decoration.enabledBorder, isNull);
      expect(decoration.focusedErrorBorder, isNull);
    });
  });

  group('§ 3.2 — B41: the words leave BYTE FOR BYTE', () {
    test('⚠️ double spaces survive', () {
      // ⚠️ `trim()` would answer a question the reader did not ask, and "mother  of" is a
      // different string from "mother of" — the site may treat them differently.
      expect(
        searchQueryFor(
          sourceId: 'rr',
          words: 'mother  of',
        ).queryParameters['q'],
        'mother  of',
      );
    });

    test('⚠️ case survives', () {
      // ⚠️ `toLowerCase()` is a guess about the site's collation, and this app has no evidence
      // about it.
      expect(
        searchQueryFor(sourceId: 'rr', words: 'Mother Of').queryParameters['q'],
        'Mother Of',
      );
    });

    test('⚠️ leading and trailing spaces survive', () {
      expect(
        searchQueryFor(sourceId: 'rr', words: ' spaced ').queryParameters['q'],
        ' spaced ',
      );
    });

    test('⚠️ an ampersand is ONE parameter, not two', () {
      // ⚠️ **String concatenation would put `&title=a&b` in a URL and the site would read `a`.**
      // That is a silently wrong search rather than an error, which is the worst kind.
      final Uri uri = searchQueryFor(sourceId: 'rr', words: 'a & b');
      expect(uri.queryParameters['q'], 'a & b');
      expect(
        uri.queryParameters.keys,
        <String>['q'],
        reason: 'one parameter, because `Uri` encodes rather than concatenates',
      );
      expect(
        uri.query.contains('&'),
        isFalse,
        reason: 'the ampersand is encoded, not structural',
      );
    });

    test('a page past the first carries it, and page 1 does not', () {
      expect(
        searchQueryFor(
          sourceId: 'rr',
          words: 'x',
        ).queryParameters.containsKey('page'),
        isFalse,
      );
      expect(
        searchQueryFor(
          sourceId: 'rr',
          words: 'x',
          page: 2,
        ).queryParameters['page'],
        '2',
      );
    });

    test('⚠️ the route carries the words under `q`, not under `tag`', () {
      final Uri uri = searchQueryFor(sourceId: 'rr', words: 'litrpg');
      expect(uri.path, '/browse/rr/genre/search');
      expect(uri.queryParameters.containsKey('tag'), isFalse);
    });
  });

  group('§ 3.3 — four outcomes, and one of them RAISES', () {
    test('rows → SearchResults', () {
      final SearchOutcome outcome = classifySearch(
        outcome: withNovels(<Novel>[novel('a')]),
        words: 'x',
      );
      expect(outcome, isA<SearchResults>());
      expect((outcome as SearchResults).words, 'x');
    });

    test('⚠️ the SITE\'s own marker → SearchNothing, and the words are kept', () {
      // ⚠️ **The only path to "no results" there is**, because `BrowseEmpty` is reachable only
      // where the site supplied a signal. Royal Road's three frozen search captures prove both
      // directions: a query that must match returns 20 rows, and one that must not returns the
      // marker.
      final SearchOutcome outcome = classifySearch(
        outcome: const BrowseEmpty<NovelsPage>(
          siteSuppliedSignal: 'There is nothing here :(',
        ),
        words: 'zzzqqqxxnotanovelname',
      );
      expect(outcome, isA<SearchNothing>());
      final SearchNothing nothing = outcome as SearchNothing;
      expect(nothing.words, 'zzzqqqxxnotanovelname');
      expect(nothing.siteSuppliedSignal, 'There is nothing here :(');
    });

    test('⚠️ a typed failure → SearchUnusable, NEVER SearchNothing', () {
      // ⚠️ **B50: a source that declares search and returns nothing usable is a broken source.**
      for (final SourceFailure failure in <SourceFailure>[
        const SourceLayoutChanged(failedSelector: 'tr', status: 200),
        const SourceUnavailable(status: 503),
        const NoConnection(host: 'x'),
      ]) {
        final SearchOutcome outcome = classifySearch(
          outcome: BrowseFailed<NovelsPage>(failure, retriable: false),
          words: 'x',
        );
        expect(outcome, isA<SearchUnusable>(), reason: failure.toString());
        expect(outcome, isNot(isA<SearchNothing>()));
      }
    });

    test('⚠️ E8: a SILENT empty page THROWS, and there is no third answer', () {
      // ⚠️ **The row the whole file exists for.** A `BrowseSucceeded` with zero rows and no
      // marker cannot be "no results" — the site never said so — and it cannot be an error
      // either, because nothing the reader can see went wrong. So it raises: a source defect
      // must not be dressed as a screen state.
      for (final BrowseOutcome<NovelsPage> outcome
          in <BrowseOutcome<NovelsPage>>[
            const BrowseSucceeded<NovelsPage>(<NovelsPage>[]),
            BrowseSucceeded<NovelsPage>(<NovelsPage>[
              NovelsPage(novels: const <Novel>[], hasNextPage: false),
            ]),
          ]) {
        expect(
          () => classifySearch(outcome: outcome, words: 'x'),
          throwsA(isA<SilentEmptySearchPage>()),
          reason: outcome.toString(),
        );
      }
    });

    test('⚠️ the exception carries the words and never reaches a reader', () {
      // ⚠️ A query is the reader's own words (`17-security.md` rule 4), and this is exactly the
      // exception that ends up in a crash report.
      const SilentEmptySearchPage failure = SilentEmptySearchPage(
        'mother of learning',
      );
      expect(failure.words, 'mother of learning');
      expect(failure.toString(), contains('SilentEmptySearchPage'));
      expect(failure.toString(), contains('E8'));
    });
  });

  group('the repository routes a search to the SEARCH door', () {
    test(
      '⚠️ a SearchCatalogueRequest calls searchNovels, never getPopularNovels',
      () async {
        // ⚠️ **The row a sabotage earned.** Removing the `searchNovels` branch from
        // `BrowseRepository.readCatalogue` left all 69 rows green, because every other row tests
        // what the classification does with an outcome and none tests which door it came through.
        // A search answered by the site's popular list is a confidently wrong list — not an
        // error, which is what makes it dangerous.
        final RecordingSource source = RecordingSource()
          ..novels = <Novel>[novel('a')];
        final BrowseRepository repository = BrowseRepository(
          sourceById: (String id) => source,
        );

        final BrowseOutcome<NovelsPage> outcome = await repository
            .readCatalogue(
              const SearchCatalogueRequest(sourceId: 'rec', words: 'litrpg'),
            );

        expect(source.calls, contains('searchNovels'));
        expect(source.calls, isNot(contains('getPopularNovels')));
        expect(source.calls, contains('query=litrpg'));
        expect(outcome, isA<BrowseSucceeded<NovelsPage>>());
      },
    );

    test('a TagCatalogueRequest still calls getPopularNovels', () async {
      final RecordingSource source = RecordingSource()
        ..novels = <Novel>[novel('a')];
      final BrowseRepository repository = BrowseRepository(
        sourceById: (String id) => source,
      );

      await repository.readCatalogue(
        const TagCatalogueRequest(sourceId: 'rec', tag: 'litrpg'),
      );

      expect(source.calls, contains('getPopularNovels'));
      expect(source.calls, isNot(contains('searchNovels')));
    });

    test(
      '⚠️ the words reach the source byte for byte, at the CALL SITE too',
      () async {
        // ⚠️ **B41 asserted at a second hop.** The URI builder row and this row are different
        // places: a refactor could build a correct URL and then normalise the string on its way to
        // `searchNovels`, and only one of the two would notice.
        final RecordingSource source = RecordingSource()
          ..novels = <Novel>[novel('a')];
        final BrowseRepository repository = BrowseRepository(
          sourceById: (String id) => source,
        );

        await repository.readCatalogue(
          const SearchCatalogueRequest(sourceId: 'rec', words: '  Mother  Of '),
        );

        expect(source.calls, contains('query=  Mother  Of '));
      },
    );

    test(
      '⚠️ an unregistered id is a typed BrowseFailed, not an empty list',
      () async {
        // ⚠️ **A source this build does not ship is a failure of the REGISTRY, not of a site** —
        // and it is still typed, so the screen has one vocabulary for "the catalogue is not
        // available" instead of a second one for "no source by that id".
        final BrowseRepository repository = BrowseRepository(
          sourceById: (String id) => null,
        );

        final BrowseOutcome<NovelsPage> outcome = await repository
            .readCatalogue(
              const TagCatalogueRequest(sourceId: 'gone', tag: 'x'),
            );

        expect(outcome, isA<BrowseFailed<NovelsPage>>());
        expect(outcome, isNot(isA<BrowseSucceeded<NovelsPage>>()));
        expect(
          (outcome as BrowseFailed<NovelsPage>).reason,
          isA<SourceUnavailable>(),
          reason:
              'and it is NOT retriable — a second attempt finds nothing new',
        );
        expect(outcome.retriable, isFalse);
      },
    );

    test('⚠️ a layout change offers no retry either', () {
      expect(
        _withRetry(
          classifySearch(
            outcome: const BrowseFailed<NovelsPage>(
              SourceLayoutChanged(failedSelector: 'tr', status: 200),
              retriable: false,
            ),
            words: 'q',
          ),
        ),
        isFalse,
      );
    });
  });
}

/// The screen's own shape for the field row — the same `if (rendersQueryField(...))` the
/// catalogue screen writes, so the row tests the decision rather than a hand-built copy.
Future<void> _pumpField(
  WidgetTester tester, {
  required bool supportsSearch,
  required String initialWords,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Column(
          children: <Widget>[
            if (rendersQueryField(supportsSearch: supportsSearch))
              CatalogueQueryField(
                initialWords: initialWords,
                onSubmitted: _neverSubmitted,
              ),
          ],
        ),
      ),
    ),
  );
}

/// A source that records **which method was called**, because the routing is the hazard.
///
/// ⚠️ **This is the row `6-2` was missing.** Routing a search to `getPopularNovels` returns
/// whatever the site ranks first and calls it results — a *confidently wrong list* rather than an
/// error, which is the worst kind and the one `browse-catalogue.md` § 4 warns about. Every other
/// row in this file tests what the classification does with an outcome; none of them test which
/// door the outcome came through, and a sabotage proved it: removing the `searchNovels` branch
/// entirely left all 69 rows passing.
final class RecordingSource implements Source {
  RecordingSource();

  final List<String> calls = <String>[];
  SourceFailure? failure;
  List<Novel> novels = const <Novel>[];

  /// ⚠️ **A getter, not a `const`.** `FilterList` is a `ListBase` wrapper whose constructor wraps
  /// its input in an unmodifiable list — a runtime call — so a `const` here would not compile,
  /// and caching it in a `final` would share one mutable-looking object across every call.
  FilterList get _noFilters => FilterList(const <Filter<Object?>>[]);

  @override
  String get id => 'rec';

  @override
  String get name => 'Recording Source';

  @override
  String get lang => 'en';

  @override
  bool get supportsSearch => true;

  @override
  bool get supportsLatest => false;

  @override
  FilterList get filterList => _noFilters;

  BrowseOutcome<NovelsPage> _answer() {
    if (failure case final SourceFailure f) {
      return BrowseFailed<NovelsPage>(f, retriable: false);
    }
    return BrowseSucceeded<NovelsPage>(<NovelsPage>[
      NovelsPage(novels: novels, hasNextPage: false),
    ]);
  }

  @override
  Future<BrowseOutcome<NovelsPage>> getPopularNovels(int page) {
    calls.add('getPopularNovels');
    return Future<BrowseOutcome<NovelsPage>>.value(_answer());
  }

  @override
  Future<BrowseOutcome<NovelsPage>> getLatestNovels(int page) {
    calls.add('getLatestNovels');
    return Future<BrowseOutcome<NovelsPage>>.value(_answer());
  }

  @override
  Future<BrowseOutcome<NovelsPage>> searchNovels(
    int page,
    String query,
    FilterList filters,
  ) {
    calls.add('searchNovels');
    // ⚠️ **The query is recorded too**, so B41 is asserted at the *call site* and not only at
    // the URI builder — the two are different hops and a refactor could break either.
    calls.add('query=$query');
    return Future<BrowseOutcome<NovelsPage>>.value(_answer());
  }

  @override
  Future<BrowseOutcome<NovelUpdate>> getNovelUpdate(
    Novel novel,
    List<Chapter> chapters, {
    required bool fetchDetails,
    required bool fetchChapters,
  }) => throw UnimplementedError();

  @override
  Future<BrowseOutcome<Novel>> getNovelDetails(Novel novel) =>
      throw UnimplementedError();

  @override
  Future<BrowseOutcome<List<Chapter>>> getChapterList(Novel novel) =>
      throw UnimplementedError();
}

bool _withRetry(SearchOutcome outcome) =>
    outcome is SearchUnusable ? outcome.canRetry : false;

void _neverSubmitted(String _) {
  throw StateError('this row does not submit');
}
