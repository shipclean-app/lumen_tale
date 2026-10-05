// forge:slice 2-5, 6-6
// Lumen Tale — `/library`: `2-5`'s five states and its removal dialog, plus `6-6`'s three
// additions — the badge (B14), the title-only search (B45) and the sort/filter sheet.
//
// ## What these rows hold the screen to
//
// | promise | rule |
// |---|---|
// | an empty library is NOT an error and never says "0 results" | B12, B22 |
// | *never visited*, *nothing matched* and *nothing passed the filters* are THREE sentences | B45 |
// | the badge is an exact integer, and **nothing at all at zero** | B14 |
// | a stopped download reads "12 of 480 downloaded" — never a bar, never "complete" | E6, C8 |
// | a broken site is a chip with an icon AND words, and the count does not move | B22, B48 |
// | *Never checked* is rendered in words | B49 |
// | the dialog's default gesture is the one that adds nothing | B40, C8 |
//
// ## ⚠️ THE ROWS ARE INJECTED TWICE, AND THE TWO INJECTIONS ARE NOT INTERCHANGEABLE
//
// - **`libraryRowsStreamProvider`** — `6-6`'s rows, and what the screen renders. Overriding
//   it keeps the widget test free of a database, which is what `10-testing.md` rule 4 asks
//   for.
// - **`libraryRepositoryProvider`** — `2-5`'s repository, and what the removal dialog reads
//   its count from. It is a separate provider because `LibraryRow` is `6-6`'s type and
//   `LibraryEntry` is `2-5`'s; `library_row.dart`'s header says why they differ.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumen_tale/app/theme/app_theme.dart';
import 'package:lumen_tale/core/ui/library_dialogs.dart';
import 'package:lumen_tale/data/library/library_providers.dart';
import 'package:lumen_tale/domain/library/library_entry.dart';
import 'package:lumen_tale/domain/library/library_repository.dart';
import 'package:lumen_tale/domain/library/library_row.dart';
import 'package:lumen_tale/domain/library/library_rows_repository.dart';
import 'package:lumen_tale/domain/library/library_search.dart';
import 'package:lumen_tale/domain/library/similar_title.dart';
import 'package:lumen_tale/domain/sources/models/novel.dart';
import 'package:lumen_tale/features/library/library_screen.dart';
import 'package:lumen_tale/features/library/providers/library_sort_filter.dart';
import 'package:lumen_tale/features/library/widgets/library_novel_row.dart';
import 'package:lumen_tale/l10n/generated/app_localizations.dart';

/// A repository that reports whatever the test hands it and records every call.
final class FakeLibrary implements LibraryRepository {
  FakeLibrary({this.downloaded = 0});

  int downloaded;

  // ignore: close_sinks
  final StreamController<List<LibraryEntry>> controller =
      StreamController<List<LibraryEntry>>.broadcast();

  final List<String> calls = <String>[];
  final List<RemoveOutcome> removals = <RemoveOutcome>[];

  @override
  Future<AddOutcome> addFromCatalogue({
    required Novel novel,
    required Future<SimilarTitleVerdict> Function(List<SimilarTitle> similar)
    onSimilarTitle,
  }) async {
    calls.add('add:${novel.id}');
    return const AddOutcome.added();
  }

  @override
  Stream<List<LibraryEntry>> watchLibrary() {
    calls.add('watch');
    return controller.stream;
  }

  @override
  Future<Novel?> readNovel(String novelId) async {
    calls.add('read:$novelId');
    return null;
  }

  @override
  Future<RemoveOutcome> removeFromLibrary(String novelId) async {
    calls.add('remove:$novelId');
    final RemoveOutcome outcome = RemoveOutcome(
      downloadedChapterCount: downloaded,
      wasAlreadyRemoved: false,
    );
    removals.add(outcome);
    return outcome;
  }

  @override
  Future<int> countDownloadedChapters(String novelId) async {
    calls.add('count:$novelId');
    return downloaded;
  }

  @override
  Future<void> restoreToLibrary(String novelId) async =>
      calls.add('restore:$novelId');

  @override
  String? sourceNameOf(String sourceId) => sourceId;
}

/// `6-6`'s rows, injected instead of a database.
final class FakeLibraryRows implements LibraryRowsRepository {
  FakeLibraryRows({required this.rows, this.fail = false});

  List<LibraryRow> rows;

  /// Emits an error instead of the rows. `library.md` § 4: *this is a storage failure*.
  final bool fail;

  // ⚠️ **BROADCAST, because the screen watches and the test may listen.** A
  /// single-subscription controller throws on a second `watchLibrary`, which is a harness
  /// limitation dressed as a product defect.
  // ignore: close_sinks
  final StreamController<List<LibraryRow>> controller =
      StreamController<List<LibraryRow>>.broadcast();

  final List<String> searches = <String>[];

  @override
  Stream<List<LibraryRow>> watchRows() => fail
      ? Stream<List<LibraryRow>>.error(StateError('the store is unreadable'))
      : controller.stream;

  @override
  Stream<List<String>> watchMatchingNovelIds(TitleSearch query) {
    searches.add(query.normalised);
    // ⚠️ **TITLE ONLY, ON PURPOSE.** This fake answers the question B45 is about: a query
    // present in the author alone matches nothing. A fake that filtered on the whole row
    // would make every B45 widget row pass for the wrong reason.
    return Stream<List<String>>.value(<String>[
      for (final LibraryRow row in rows)
        if (row.title.toLowerCase().contains(query.normalised)) row.novelId,
    ]);
  }
}

/// One row, with the defaults `2-5`'s fixture used.
LibraryRow row({
  String id = 'n1',
  String title = 'The Rune Smith',
  String sourceName = 'Royal Road',
  String? author = 'An Author',
  int unopened = 0,
  int downloaded = 0,
  int chapters = 480,
  DateTime? lastCheckedAt,
  String? lastCheckError,
  DownloadPresentation download = DownloadPresentation.none,
}) {
  return LibraryRow(
    novelId: id,
    title: title,
    sourceName: sourceName,
    author: author,
    unopenedCount: unopened,
    chapterCount: chapters,
    downloadedCount: downloaded,
    lastCheckedAt: lastCheckedAt,
    lastCheckError: lastCheckError,
    // ⚠️ **DERIVED, NOT DECLARED.** The fixture says how many chapters are on the phone and
    // what the queue is doing; the presentation is what the product computes. A fixture
    // that passed `DownloadPresentation` by hand could hold the model to a value the real
    // resolver would never produce.
    download: download == DownloadPresentation.none && downloaded > 0
        ? DownloadPresentation.running
        : download,
  );
}

/// Pumps `/library` with both repositories injected.
Future<FakeLibraryRows> pumpLibrary(
  WidgetTester tester, {
  List<LibraryRow> rows = const <LibraryRow>[],
  LibraryRepository? library,
  bool failRows = false,
  Size size = const Size(360, 800),
  double textScale = 1,
}) async {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  // ⚠️ **`failRows` AND NOT A SEPARATE FAKE CLASS.** The screen's *Load error* state
  // is `libraryRowsProvider`'s error, which is `6-6`'s stream — a fake that failed
  // `LibraryRepository.watchLibrary` instead would assert that `2-5`'s error path still
  // renders, which is a different promise and one nothing here claims.
  final FakeLibraryRows rowSource = FakeLibraryRows(rows: rows, fail: failRows);
  final LibraryRepository repository = library ?? FakeLibrary();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        libraryRowsRepositoryProvider.overrideWithValue(rowSource),
        libraryRepositoryProvider.overrideWithValue(repository),
      ],
      child: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
        child: const _App(),
      ),
    ),
  );
  await tester.pump();
  rowSource.controller.add(rowSource.rows);
  await tester.pumpAndSettle();
  return rowSource;
}

class _App extends StatelessWidget {
  const _App();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      // ⚠️ **`AppTheme.day()`, AND NOT A DEFAULT `MaterialApp`.** `LumenSpacing`,
      // `LumenColors`, `LumenRadius` and `LumenShadows` are `ThemeExtension`s, and
      // `14-design-tokens.md` makes the extension the token source — so a test harness
      // without the app theme throws a null-check error inside the widget rather than
      // showing a wrong colour, which is the better of the two failures.
      theme: AppTheme.day(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const LibraryScreen(),
    );
  }
}

void main() {
  group('B12 — an empty library names the NEXT STEP, not a result count', () {
    testWidgets(
      'never visited renders *Your library is empty* and *Browse a source*',
      (WidgetTester tester) async {
        // ⚠️ **"0 novels" WOULD BE A REPORT ABOUT A QUERY.** An empty library is the state
        // every reader is in until they browse once, so the screen says what to do.
        await pumpLibrary(tester);

        expect(find.text('Your library is empty'), findsOneWidget);
        expect(
          find.text('Add a novel from Browse to start reading.'),
          findsOneWidget,
        );
        expect(
          find.widgetWithText(FilledButton, 'Browse a source'),
          findsOneWidget,
        );
        expect(find.textContaining('0 '), findsNothing);
      },
    );

    testWidgets('⚠️ a FILLED library renders one row per entry', (
      WidgetTester tester,
    ) async {
      await pumpLibrary(
        tester,
        rows: <LibraryRow>[
          row(id: 'a', title: 'First', unopened: 3, downloaded: 12),
          row(id: 'b', title: 'Second'),
        ],
      );

      expect(find.text('First'), findsOneWidget);
      expect(find.text('Second'), findsOneWidget);
    });

    testWidgets('⚠️ a LOAD FAILURE names what still works', (
      WidgetTester tester,
    ) async {
      // ⚠️ **B24: a storage failure is not "something went wrong".** The sentence has to say
      // what survives it, because "an operation failed" leaves the reader with no idea
      // whether their chapters are still readable.
      await pumpLibrary(tester);
      await pumpLibrary(tester, failRows: true);

      expect(find.text('Your library could not be read'), findsOneWidget);
      expect(
        find.textContaining('still on this phone and still readable'),
        findsOneWidget,
      );
      expect(find.widgetWithText(TextButton, 'Retry'), findsOneWidget);
      expect(
        find.byTooltip('Check for new chapters'),
        findsOneWidget,
        reason:
            'the app bar carries `6-4`\'s labelled hole and names the action; a glyph with '
            'no word is a puzzle, and "Retry" is the load error\'s own verb',
      );
    });
  });

  group('B14 — the badge is an exact integer, and nothing at all at zero', () {
    testWidgets('a count of 0 puts NO badge in the widget tree', (
      WidgetTester tester,
    ) async {
      // ⚠️ **THE TREE, NOT THE PIXELS.** A pill at zero is a permanent alarm; and a widget
      // that exists in the tree is one a screen reader announces and a `find.byType` can
      // see, so "no badge" has to be true of the tree.
      await pumpLibrary(tester, rows: <LibraryRow>[row()]);

      expect(find.byType(UnopenedBadge), findsNothing);
      expect(find.text('0'), findsNothing);
    });

    testWidgets('a count of 12 renders the NUMBER, never "a few"', (
      WidgetTester tester,
    ) async {
      await pumpLibrary(tester, rows: <LibraryRow>[row(unopened: 12)]);

      expect(find.byType(UnopenedBadge), findsOneWidget);
      expect(find.text('12'), findsWidgets);
      expect(
        find.textContaining('few'),
        findsNothing,
        reason:
            'B14: "some chapters" is unfalsifiable, and the number is checkable',
      );
    });

    testWidgets('the badge is ANNOUNCED with its number', (
      WidgetTester tester,
    ) async {
      // ⚠️ **§ 7: a screen-reader user cannot infer a pill from a list.** `library.md`'s own
      // sentence is *"12 chapters you have not opened"*, which is the shipped ARB string.
      // ⚠️ **THE BADGE PUMPED ON ITS OWN, AND THAT IS THE POINT.** `LibraryNovelRow`
      // wraps itself in `Semantics(excludeSemantics: true)` so the row is ONE node, which by
      // construction drops the badge's own node — correctly, because the row's label
      // already carries the count. Asserting the badge inside the row would therefore prove
      // nothing; asserting it standalone proves the badge is never announced as bare
      // "new".
      final SemanticsHandle handle = tester.ensureSemantics();
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.day(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(body: UnopenedBadge(count: 12)),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.bySemanticsLabel('12 chapters you have not opened'),
        findsOneWidget,
        reason:
            'the count is INSIDE the label, because a badge is not a number a listener can '
            'derive from a colour',
      );
      expect(
        find.bySemanticsLabel('new'),
        findsNothing,
        reason: '"new" alone is unfalsifiable; the figure is the information',
      );
      // ⚠️ **DISPOSED HERE AND NOT IN `addTearDown`.** flutter_test verifies at the end
      // of the body that no `SemanticsHandle` is still open, and a teardown callback runs
      // *after* that check — so the disposal has to be the last statement.
      handle.dispose();
    });

    testWidgets('a novel with NO chapters shows 0 / 0 and no badge', (
      WidgetTester tester,
    ) async {
      // ⚠️ **WHAT `COUNT(*)` WOULD HAVE SHOWN: "1 unopened".** A wrong number is worse than
      // an absent one, which is why § 3.2's SQL counts `c.id` and not `*`.
      await pumpLibrary(tester, rows: <LibraryRow>[row(chapters: 0)]);

      expect(find.text('0 / 0'), findsOneWidget);
      expect(find.byType(UnopenedBadge), findsNothing);
    });
  });

  group('E6 / E7 — an interrupted download, on the row', () {
    testWidgets('⚠️ a stopped queue reads "12 of 480 downloaded", and NO bar', (
      WidgetTester tester,
    ) async {
      // ⚠️ **C8: nothing partial may be shown as complete.** A determinate bar that is not
      // moving reads as a bar that has finished, so the row has no `LinearProgressIndicator`
      // at all — that absence is the assertion.
      await pumpLibrary(
        tester,
        rows: <LibraryRow>[
          row(
            unopened: 3,
            downloaded: 12,
            download: DownloadPresentation.stopped,
          ),
        ],
      );

      expect(find.text('12 of 480 downloaded'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(find.text('Stopped'), findsOneWidget);
      expect(
        find.text('All chapters downloaded'),
        findsNothing,
        reason: 'C8/B6: an interrupted download is never presented as complete',
      );
    });

    testWidgets('⚠️ a lost connection says STOPPED and never PAUSED', (
      WidgetTester tester,
    ) async {
      // ⚠️ **E7 EXACTLY.** A queue stopped by a lost connection does not resume on its own
      // when the connection returns; "paused" promises a resume the app will not perform.
      await pumpLibrary(
        tester,
        rows: <LibraryRow>[
          row(
            unopened: 3,
            downloaded: 12,
            download: DownloadPresentation.stoppedByConnectionLost,
          ),
        ],
      );

      expect(find.textContaining('Stopped'), findsOneWidget);
      expect(
        find.textContaining('paused'),
        findsNothing,
        reason:
            'E7: "paused" promises a resume that E7 says will not happen on its own',
      );
      expect(find.textContaining('no connection'), findsOneWidget);
      expect(
        find.text('12 of 480 downloaded'),
        findsOneWidget,
        reason:
            'E7: the chapters already finished stay counted and stay readable',
      );
    });

    testWidgets('a full disk is named, because the next action differs', (
      WidgetTester tester,
    ) async {
      await pumpLibrary(
        tester,
        rows: <LibraryRow>[
          row(
            downloaded: 12,
            download: DownloadPresentation.stoppedOutOfStorage,
          ),
        ],
      );

      expect(find.textContaining('storage full'), findsOneWidget);
    });
  });

  group('B22 / B48 / B49 — the verification beside the count', () {
    testWidgets('a broken site is a chip with an ICON and the WORDS', (
      WidgetTester tester,
    ) async {
      // ⚠️ **B22 + `14-design-tokens.md`.** A red word alone is a colour a colour-blind
      // reader cannot use as a channel; § 2.5 says the `failed` chip carries both.
      await pumpLibrary(
        tester,
        rows: <LibraryRow>[
          row(unopened: 7, lastCheckError: 'source_layout_changed'),
        ],
      );

      expect(find.text('Could not check'), findsOneWidget);
      expect(
        find.byIcon(Icons.cloud_off_outlined),
        findsOneWidget,
        reason: 'no state is carried by colour alone',
      );
      expect(
        find.text('7'),
        findsOneWidget,
        reason:
            'B48: losing contact with a site changes the VERIFICATION, never a local count',
      );
    });

    testWidgets(
      '⚠️ `lastCheckedAt == null` renders *Never checked*, in words',
      (WidgetTester tester) async {
        await pumpLibrary(tester, rows: <LibraryRow>[row()]);

        expect(find.text('Never checked'), findsOneWidget);
        expect(
          find.textContaining('just now'),
          findsNothing,
          reason: 'B49: the app never implies it looked when it did not',
        );
      },
    );

    testWidgets('a checked novel does NOT render *Never checked*', (
      WidgetTester tester,
    ) async {
      await pumpLibrary(
        tester,
        rows: <LibraryRow>[row(lastCheckedAt: DateTime.utc(2026, 10))],
      );

      expect(find.text('Never checked'), findsNothing);
    });
  });

  group('ADR-024 — the author is displayed, never searched, never sorted on', () {
    testWidgets('a row with no author COLLAPSES the subtitle', (
      WidgetTester tester,
    ) async {
      // ⚠️ **A COLLAPSED SLOT, NOT A DASH.** `library.md` § 8: `author` absent → *the
      // subtitle slot renders empty and the row keeps its 72dp*. A dash would be a fact the
      // site never stated.
      await pumpLibrary(tester, rows: <LibraryRow>[row(author: null)]);

      expect(find.textContaining('Author unknown'), findsNothing);
      expect(find.textContaining('—'), findsNothing);

      // ⚠️ **THE ROW IS SHORTER WITHOUT THE AUTHOR, AND STILL AT LEAST 72dp.** § 8
      // says *the `subtitle` slot renders empty and the row keeps its 72dp*; what proves the
      // slot COLLAPSED rather than being padded is that the row is smaller than the same row
      // with an author, so both halves are asserted rather than only the token.
      final double withoutAuthor = tester
          .getSize(find.byType(LibraryNovelRow))
          .height;
      expect(
        withoutAuthor,
        greaterThanOrEqualTo(LibraryNovelRow.height),
        reason: '72dp is a FLOOR: § 6 also asks for no overflow at 200% text',
      );

      await pumpLibrary(tester, rows: <LibraryRow>[row(author: 'Ilan W.')]);
      final double withAuthor = tester
          .getSize(find.byType(LibraryNovelRow))
          .height;
      expect(
        withAuthor,
        greaterThan(withoutAuthor),
        reason:
            'an absent author takes the slot away instead of filling it with a dash, so the '
            'two rows must not measure the same',
      );
    });

    testWidgets('the author IS shown beside the site name', (
      WidgetTester tester,
    ) async {
      await pumpLibrary(tester, rows: <LibraryRow>[row(author: 'Ilan W.')]);

      expect(find.textContaining('Ilan W.'), findsOneWidget);
      expect(find.textContaining('Royal Road'), findsWidgets);
    });

    testWidgets('the whole row is ONE semantics node carrying the facts', (
      WidgetTester tester,
    ) async {
      // ⚠️ **§ 7'S SENTENCE, ASSEMBLED.** "Title, by author, source, count, verification,
      // downloaded of total" — the count and the timestamp are INSIDE the label.
      await pumpLibrary(
        tester,
        rows: <LibraryRow>[
          row(
            unopened: 12,
            downloaded: 148,
            lastCheckedAt: DateTime.utc(2026, 10),
          ),
        ],
      );

      // ⚠️ **THE ROW'S OWN `Semantics`, FOUND FROM THE ROW.** `find.ancestor` returns
      // the NEAREST ancestor — and the nearest one here is a `Text`'s, whose
      // `excludeSemantics` is false. The node this row contributes is the one it builds, so
      // the finder starts at the row.
      final Semantics node = tester.widget<Semantics>(
        find
            .descendant(
              of: find.byType(LibraryNovelRow),
              matching: find.byWidgetPredicate(
                (Widget w) => w is Semantics && w.excludeSemantics == true,
              ),
            )
            .first,
      );
      expect(node.excludeSemantics, isTrue, reason: 'one node, not six');
      expect(
        node.properties.label,
        allOf(
          contains('The Rune Smith'),
          contains('An Author'),
          contains('Royal Road'),
          contains('12'),
          contains('148'),
          contains('480'),
        ),
      );
    });
  });

  group('B45 — the title-only search', () {
    testWidgets('the placeholder says *Search by title*', (
      WidgetTester tester,
    ) async {
      // ⚠️ **THE PLACEHOLDER IS THE PROMISE.** A field shown next to an author line teaches
      // that the box searches it (`library.md` § 2.1).
      await pumpLibrary(tester, rows: <LibraryRow>[row()]);
      await tester.tap(find.byKey(const Key('library.search-button')));
      await tester.pumpAndSettle();

      expect(find.text('Search by title'), findsOneWidget);
    });

    testWidgets('the helper count EQUALS the number of rows shown', (
      WidgetTester tester,
    ) async {
      // ⚠️ **§ 3.1 branch 11: two numbers on one page must not disagree.** The helper says
      // *3 novels* and the list has three rows, or B22 in another costume.
      await pumpLibrary(
        tester,
        rows: <LibraryRow>[
          row(id: 'a', title: 'Alpha'),
          row(id: 'b', title: 'Beta'),
          row(id: 'c', title: 'Gamma'),
        ],
      );
      await tester.tap(find.byKey(const Key('library.search-button')));
      await tester.pumpAndSettle();

      expect(find.text('3 novels'), findsOneWidget);
      expect(find.byType(LibraryNovelRow), findsNWidgets(3));
    });

    testWidgets('typing narrows the list by TITLE', (
      WidgetTester tester,
    ) async {
      final FakeLibraryRows source = await pumpLibrary(
        tester,
        rows: <LibraryRow>[
          row(id: 'a', title: 'The Vow of Embers', author: 'Ilan W.'),
          row(id: 'b', title: 'Ashes'),
        ],
      );
      await tester.tap(find.byKey(const Key('library.search-button')));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('library.search-field')),
        'vow',
      );
      await tester.pumpAndSettle();

      expect(find.text('The Vow of Embers'), findsOneWidget);
      expect(find.text('Ashes'), findsNothing);
      expect(source.searches, contains('vow'));
    });

    testWidgets('⚠️ a query in the AUTHOR alone matches nothing', (
      WidgetTester tester,
    ) async {
      // ⚠️ **B45 MADE VISIBLE.** The reader can see *Ilan W.* on the row and typing *ilan*
      // returns nothing: that is the rule, not a bug, and the screen must be the one that
      // made it checkable.
      await pumpLibrary(
        tester,
        rows: <LibraryRow>[row(id: 'a', title: 'Ashes', author: 'Ilan W.')],
      );
      await tester.tap(find.byKey(const Key('library.search-button')));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('library.search-field')),
        'ilan',
      );
      await tester.pumpAndSettle();

      expect(find.text('Ashes'), findsNothing);
      expect(find.text('No kept novel matches "ilan"'), findsOneWidget);
    });

    testWidgets(
      '⚠️ nothing matching says *No kept novel matches* and NEVER "0 results"',
      (WidgetTester tester) async {
        // ⚠️ **B22/E19.** "0 results" is the register of a failed **site** query. The library
        // is local and has no site to have lost, so the phrase would be a lie about where the
        // answer came from.
        await pumpLibrary(tester, rows: <LibraryRow>[row()]);
        await tester.tap(find.byKey(const Key('library.search-button')));
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byKey(const Key('library.search-field')),
          'zzz',
        );
        await tester.pumpAndSettle();

        expect(find.text('No kept novel matches "zzz"'), findsOneWidget);
        expect(find.textContaining('0 results'), findsNothing);
        expect(
          find.widgetWithText(FilledButton, 'Clear search'),
          findsOneWidget,
          reason:
              'the sentence says what excluded everything, and offers the undo',
        );
      },
    );

    testWidgets(
      '⚠️ *Clear search* restores the WHOLE library, not an empty list',
      (WidgetTester tester) async {
        // ⚠️ **§ 3.1 branch 1.** An empty query is the whole library; rendering it as an empty
        // list is a state the reader cannot tell from a bug.
        await pumpLibrary(
          tester,
          rows: <LibraryRow>[
            row(id: 'a', title: 'Alpha'),
            row(id: 'b', title: 'Beta'),
          ],
        );
        await tester.tap(find.byKey(const Key('library.search-button')));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const Key('library.search-field')),
          'zzz',
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('library.search-clear')));
        await tester.pumpAndSettle();

        expect(find.byType(LibraryNovelRow), findsNWidgets(2));
        expect(find.text('No kept novel matches'), findsNothing);
      },
    );

    testWidgets('the search and the REMOVAL are separate concerns', (
      WidgetTester tester,
    ) async {
      // ⚠️ **THE EMPTY STATE AFTER A FILTER IS A THIRD SENTENCE**, distinct from both
      // *never visited* and *nothing matched*.
      await pumpLibrary(
        tester,
        rows: <LibraryRow>[row(id: 'a', title: 'Alpha')],
      );
      await tester.tap(find.byKey(const Key('library.search-button')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('library.search-field')),
        'alpha',
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('library.search-clear')));
      await tester.pumpAndSettle();
      expect(find.byType(LibraryNovelRow), findsOneWidget);
    });
  });

  group('§ 4.3 — the two (three) empty states are DISTINCT sentences', () {
    testWidgets('facets that exclude everything name the FILTERS, not the query', (
      WidgetTester tester,
    ) async {
      final FakeLibraryRows source = await pumpLibrary(
        tester,
        // ⚠️ **A TALL VIEWPORT, AND THE REASON IS THE SHEET'S HEIGHT.** Five radio rows,
        // the scope line and four chips do not fit a 360×800 phone at 1× text, so the chips
        // sit inside the sheet's scroll view and OFF-SCREEN — and a tap at a widget's centre
        // then lands on whatever is at those coordinates. The *layout* claims about 360dp
        // and 320dp are asserted in the sheet's own rows; this row is about behaviour.
        size: const Size(360, 1600),
        rows: <LibraryRow>[row(id: 'a', title: 'Alpha')],
      );
      addTearDown(source.controller.close);

      await tester.tap(find.byKey(const Key('library.sort-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('library.facet.downloaded')));
      await tester.pumpAndSettle();
      // ⚠️ **THE BARRIER, NOT A *CANCEL*.** § 11.1: the sheet has no Apply and no Cancel —
      // facets apply live, so a *Done* button would be a control that implies a choice the
      // reader has already made.
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();

      // ⚠️ **THE SHIPPED WORDING OF `libraryNoDataTitle`.** The plan's § 4.3 quoted
      // *No kept novel is downloaded*; the ARB that was frozen before this slice says
      // *No kept novel matches the filters*, which is better — it names the FACET rather
      // than asserting a fact about one novel — and the ARB is the string the app ships.
      expect(find.text('No kept novel matches the filters'), findsOneWidget);
      expect(find.textContaining('Clear filters'), findsOneWidget);
      expect(
        find.textContaining('Your library is empty'),
        findsNothing,
        reason:
            'the reader HAS novels; saying the library is empty would be the one state '
            'this screen is most often wrong about',
      );
    });
  });

  group('B45 / B39 — the sort and filter sheet', () {
    testWidgets('it draws FIVE sorts, FOUR facets and the scope line', (
      WidgetTester tester,
    ) async {
      await pumpLibrary(
        tester,
        rows: <LibraryRow>[row(id: 'a', title: 'Alpha')],
      );
      await tester.tap(find.byKey(const Key('library.sort-button')));
      await tester.pumpAndSettle();

      for (final LibrarySort sort in LibrarySort.values) {
        expect(
          find.byKey(Key('library.sort.${sort.name}')),
          findsOneWidget,
          reason:
              '§ 11.1 names five orders and a missing one is an invisible feature',
        );
      }
      for (final LibraryFacet facet in LibraryFacet.values) {
        expect(find.byKey(Key('library.facet.${facet.name}')), findsOneWidget);
      }
      expect(
        find.byKey(const Key('library.scope-line')),
        findsOneWidget,
        reason:
            'B45: a reader who finds no author facet is entitled to think it is elsewhere, '
            'and the sheet is where that is answered',
      );
      expect(find.text('Title A–Z'), findsOneWidget);
      expect(find.text('Unopened chapters'), findsOneWidget);
    });

    testWidgets('⚠️ `Clear all` is DISABLED when nothing is set', (
      WidgetTester tester,
    ) async {
      // ⚠️ **A LIVE-LOOKING BUTTON THAT DOES NOTHING IS THE DEFECT `2-5` DOCUMENTED** for
      // its own un-wired check button. § 11.1: the sheet is never empty.
      await pumpLibrary(tester, rows: <LibraryRow>[row()]);
      await tester.tap(find.byKey(const Key('library.sort-button')));
      await tester.pumpAndSettle();

      final TextButton clear = tester.widget<TextButton>(
        find.byKey(const Key('library.clear-filters')),
      );
      expect(clear.onPressed, isNull);
    });

    testWidgets('the scope line wraps at 320dp rather than truncating', (
      WidgetTester tester,
    ) async {
      // ⚠️ **A SCOPE LINE THAT TRUNCATES HAS STOPPED ARGUING**, which is the whole job of it.
      await pumpLibrary(
        tester,
        rows: <LibraryRow>[row()],
        size: const Size(320, 900),
      );
      await tester.tap(find.byKey(const Key('library.sort-button')));
      await tester.pumpAndSettle();

      final Text scope = tester.widget<Text>(
        find.byKey(const Key('library.scope-line')),
      );
      expect(scope.maxLines, isNull, reason: 'no maxLines: it wraps');
      expect(scope.overflow, isNull, reason: 'no ellipsis: it wraps');
      expect(tester.takeException(), isNull, reason: 'no overflow at 320dp');
    });
  });

  group('B32 — the removal dialog, and C8\'s reassurance', () {
    testWidgets('⚠️ the dialog quotes the count, read BEFORE the write', (
      WidgetTester tester,
    ) async {
      final FakeLibrary repository = FakeLibrary(downloaded: 148);
      await pumpLibrary(
        tester,
        rows: <LibraryRow>[row(downloaded: 148)],
        library: repository,
      );

      await tester.tap(find.byIcon(Icons.remove_circle_outline));
      await tester.pumpAndSettle();

      expect(find.text('Remove from library?'), findsOneWidget);
      expect(find.textContaining('148 downloaded chapters'), findsOneWidget);
      expect(repository.calls, contains('count:n1'));
      expect(
        repository.calls,
        isNot(contains('remove:n1')),
        reason: 'nothing is written until the reader confirms',
      );
    });

    testWidgets('⚠️ dismissing the dialog removes NOTHING', (
      WidgetTester tester,
    ) async {
      // ⚠️ **C8: on a device with no cloud backup the easiest gesture must not be the
      // destructive one.** Closing a confirmation is not agreeing to it.
      final FakeLibrary repository = FakeLibrary();
      await pumpLibrary(tester, rows: <LibraryRow>[row()], library: repository);

      await tester.tap(find.byIcon(Icons.remove_circle_outline));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();

      expect(repository.calls, isNot(contains('remove:n1')));
    });

    testWidgets('confirming removes, and says what SURVIVED', (
      WidgetTester tester,
    ) async {
      final FakeLibrary repository = FakeLibrary(downloaded: 148);
      await pumpLibrary(
        tester,
        rows: <LibraryRow>[row(downloaded: 148)],
        library: repository,
      );

      await tester.tap(find.byIcon(Icons.remove_circle_outline));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Remove'));
      await tester.pumpAndSettle();

      expect(repository.calls, contains('remove:n1'));
      expect(repository.removals, hasLength(1));
      expect(
        find.text('Nothing was deleted. The chapters are still here.'),
        findsOneWidget,
        reason:
            'B32 said out loud: a promise the reader can see rather than trust',
      );
    });
  });

  group('B40 — the similar-title dialog is BLOCKING and has no default action', () {
    testWidgets('⚠️ dismissing answers DISMISSED, and DISMISSED writes nothing', (
      WidgetTester tester,
    ) async {
      // ⚠️ **THE MOST CASUAL GESTURE ON THE SCREEN.** A dialog that answered "add anyway"
      // on dismissal would make a double-tap the way to write a duplicate.
      SimilarTitleVerdict? verdict;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.day(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (BuildContext context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  verdict = await showSimilarTitleDialog(
                    context,
                    similar: candidates,
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();

      expect(verdict, SimilarTitleVerdict.dismissed);
    });

    testWidgets('⚠️ the dialog names BOTH novels and BOTH sites', (
      WidgetTester tester,
    ) async {
      // ⚠️ **E17.** "Is this the same novel?" is unanswerable without knowing which site
      // published which — which is why the body repeats for every candidate.
      await _openDialog(tester);

      expect(find.textContaining('Royal Road'), findsOneWidget);
      expect(find.textContaining('FanMTL'), findsOneWidget);
      expect(find.text('Add anyway'), findsOneWidget);
    });

    testWidgets('⚠️ the dialog never offers to MERGE or to REPLACE', (
      WidgetTester tester,
    ) async {
      // ⚠️ **THE WORD "Merge" DOES NOT EXIST IN THIS PRODUCT.** And "Replace" is B2's
      // failure in a button: two sites publishing a title are two books, and no control on
      // this dialog may propose deleting one.
      await _openDialog(tester);

      expect(find.textContaining('Merge'), findsNothing);
      expect(find.textContaining('Replace'), findsNothing);
      expect(find.text('Open the existing one'), findsOneWidget);
      expect(
        find.text('Nothing will be merged — they stay two separate novels.'),
        findsOneWidget,
        reason:
            'the warning is ON the dialog, because after it there is nowhere to say it',
      );
    });

    testWidgets('the three verdicts are all reachable', (
      WidgetTester tester,
    ) async {
      for (final (String label, SimilarTitleVerdict expected)
          in <(String, SimilarTitleVerdict)>[
            ('Cancel', SimilarTitleVerdict.dismissed),
            ('Open the existing one', SimilarTitleVerdict.openExisting),
            ('Add anyway', SimilarTitleVerdict.addAnyway),
          ]) {
        SimilarTitleVerdict? verdict;
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.day(),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Builder(
              builder: (BuildContext context) => Scaffold(
                body: TextButton(
                  onPressed: () async {
                    verdict = await showSimilarTitleDialog(
                      context,
                      similar: candidates,
                    );
                  },
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();
        await tester.tap(find.text(label));
        await tester.pumpAndSettle();

        expect(verdict, expected, reason: label);
      }
    });
  });

  group('accessibility — 360dp and a 200% text scale', () {
    testWidgets('nothing overflows, and only the title truncates', (
      WidgetTester tester,
    ) async {
      // ⚠️ **THE ONE ACCEPTED LOSS IS THE TITLE.** `library.md` § 6: every text slot
      // truncates rather than wraps, and the full title is on the novel's chapter list.
      await pumpLibrary(
        tester,
        size: const Size(360, 900),
        textScale: 2,
        rows: <LibraryRow>[
          row(
            title: 'The Ascension of the Ninth Son, volume the eleventh',
            unopened: 12,
            downloaded: 148,
            lastCheckedAt: DateTime.utc(2026, 10),
          ),
        ],
      );

      expect(
        tester.takeException(),
        isNull,
        reason: 'no RenderFlex overflow at 200%',
      );
      final Text title = tester.widget<Text>(
        find.textContaining('The Ascension'),
      );
      expect(
        title.maxLines,
        2,
        reason:
            'the title is the one slot allowed to truncate, and at two lines',
      );
    });

    testWidgets(
      'the status line is a Wrap, so an RTL locale REORDERS without losing a fact',
      (WidgetTester tester) async {
        // ⚠️ **`library.md` § 7: no row assumes LTR.** The facts are a `Wrap` of widgets, not
        // one concatenated string — a joined string would reorder its own words instead.
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              libraryRowsRepositoryProvider.overrideWithValue(
                FakeLibraryRows(
                  rows: <LibraryRow>[row(unopened: 12, downloaded: 148)],
                ),
              ),
              libraryRepositoryProvider.overrideWithValue(FakeLibrary()),
            ],
            child: MaterialApp(
              theme: AppTheme.day(),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                // ⚠️ **THE DIRECTION IS SET ON THE `Scaffold`'S BODY SLOT AND NOT IN A
                // BARE `Directionality`.** `MaterialApp` resolves its own direction from the
                // locale, so a `Directionality` under `home` is what a real RTL locale would
                // produce — and it needs a `Material` ancestor for `InkWell` and the chips.
                body: Directionality(
                  textDirection: TextDirection.rtl,
                  child: LibraryNovelRow(
                    row: row(unopened: 12, downloaded: 148),
                    onTap: () {},
                    onRemove: () {},
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(
          find.text('12'),
          findsOneWidget,
          reason: 'the count survives the direction',
        );
        expect(
          find.text('148 of 480 downloaded'),
          findsOneWidget,
          reason: 'the pair is one fact and is not split by a direction change',
        );
      },
    );
  });

  group('B36 — the check action is `6-4`\'s, and it is a LABELLED HOLE', () {
    testWidgets('⚠️ it is DISABLED, not a live button that does nothing', (
      WidgetTester tester,
    ) async {
      await pumpLibrary(tester, rows: <LibraryRow>[row()]);

      final IconButton check = tester.widget<IconButton>(
        find.byKey(const Key('library.check-button')),
      );
      expect(
        check.onPressed,
        isNull,
        reason:
            'B36/B38/B39\'s wire is `6-4`\'s; a live-looking button that silently does '
            'nothing is worse than a disabled one',
      );
    });
  });
}

/// The candidates a B40 dialog is shown.
final List<SimilarTitle> candidates = <SimilarTitle>[
  const SimilarTitle(
    existingNovelId: 'royal-1',
    existingTitle: 'The Rune Smith',
    existingSourceName: 'Royal Road',
    incomingTitle: 'the rune smith',
    incomingSourceName: 'FanMTL',
  ),
];

/// Opens the B40 dialog and settles it.
Future<void> _openDialog(WidgetTester tester) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.day(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (BuildContext context) => Scaffold(
          body: TextButton(
            onPressed: () =>
                showSimilarTitleDialog(context, similar: candidates),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}
