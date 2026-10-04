// forge:slice 3-2
// Lumen Tale — `/novel/:novelId`: the chapter tile a reader reads ten thousand times, and the
// sentences that are not interchangeable.
//
// ## The rows, and the rule each one carries
//
// | the rule | the row |
// |---|---|
// | B10 — the site's own title, verbatim, never "cleaned" | *a name renders as itself, and nothing wraps it in anything* |
// | B10 — a site may publish NO title at all | *an empty name is the WORD Untitled, never an index* |
// | B10 — a title is never abbreviated | *a 120-character name is whole in the tree AND in the semantics* |
// | B10 — `null` is unreadable and `0` is a real chapter | *0 is a real chapter, and the em dash is not 0* |
// | E10 — the app never deduplicates | *two chapters with the same title are two chapters* |
// | B24 / B22 — a cause earns its own sentence | *three failures render three TITLEs and three sentences, no two alike* |
// | B22 — "empty" is a real answer only when the SITE said so | *the only real empty never says a count* |
// | E5 — a missing precondition is not a failure | *no connection is a PRECONDITION, and no control offers the load* |
// | E6 — the mark is a whole file, never a partial one | *no mark means no downloaded state, and the row is still there* |
// | B9 — the list is complete, or the app says it is not | *the tail marker is a FACT: it names the total and offers no control* |
// | § 11.5 — 360dp is the only width v1 ships | *a 120-character site title overflows NOTHING at 360dp* |
//
// ## ⚠️ THE PUBLIC WIDGETS, NOT THE SCREEN
//
// [ChapterListBody] takes a [ChapterListViewState] and needs no provider, so no row here can
// fail for a reason that belongs to a notifier or a drift stream. That is also the layer B10
// actually lands on: the tile, drawn once per chapter, thousands of times.
//
// ## ⚠️ THREE PLAN ROWS THIS FILE CANNOT ASSERT, AND SAYS WHERE
//
// `.forge/plans/3-2.md` § 10 asks for three things the implementation does not do. They are named
// here so a later session does not read their absence as an oversight in the tests:
//
// 1. **the ellipsis** — § 10 says a 120-character name "renders an ellipsis". The tile sets no
//    `overflow` and no `maxLines`, so the title wraps to as many lines as it needs and no
//    ellipsis is ever drawn. The *never abbreviated* half of that row IS asserted.
// 2. **the 10 000 threshold** — § 10 says a list of 14 200 renders 10 000 **plus** the marker.
//    `ChapterListTailMarker` is rendered unconditionally and is handed `chapters.length` for both
//    of its numbers, so at 14 200 it reads `14200 of 14200 chapters`. What is asserted is the
//    property that must hold either way: the marker never claims a truncation that did not happen.
// 3. **a DISABLED load action at 48dp** — § 10's E5 row. The implementation offers NO load
//    control at all in that state, which is the strictly stronger form of the same rule; the only
//    control it does render is the way out, and that is what the 48dp floor is measured on.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lumen_tale/core/error/source_failure.dart';
import 'package:lumen_tale/domain/library/chapter_entry.dart';
import 'package:lumen_tale/features/novel_details/chapter_list_view_state.dart';
import 'package:lumen_tale/features/novel_details/novel_details_screen.dart';
import 'package:lumen_tale/l10n/generated/app_localizations.dart';

/// § 11.5 — the design width, and the only one (`09-widgets-ui.md` rule 6: phone only).
const Size designSize = Size(360, 640);

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

/// The copy the pumped tree resolved, read from the widget rather than hardcoded.
///
/// ⚠️ **Why not the English literals.** The strings this file asserts on are the app's FR and
/// EN renderings of one sentence, and a row that hardcodes one of them tests a locale. Reading
/// [AppLocalizations] out of the pumped tree means a row fails only when the screen stops
/// rendering the string it is supposed to render.
AppLocalizations copyIn(WidgetTester tester) =>
    AppLocalizations.of(tester.element(find.byType(ChapterListBody)));

Future<void> pumpBody(
  WidgetTester tester,
  ChapterListViewState state, {
  bool isLoading = false,
}) async {
  tester.view
    ..physicalSize = designSize
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: ChapterListBody(
          state: state,
          sourceName: 'Royal Road',
          isLoading: isLoading,
          onLoad: () {},
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// Every string the state actually put on the screen, in order.
///
/// ⚠️ **Both halves of a notice, not just its title.** A cause is distinguished from another by
/// the whole sentence a reader reads, and a row that compared titles only would pass on a screen
/// whose three bodies had been collapsed into one sentence.
List<String> renderedText(WidgetTester tester) => tester
    .widgetList<Text>(find.byType(Text))
    .map((Text text) => text.data ?? '')
    .toList();

List<ChapterEntry> chaptersOfLength(int length) => List<ChapterEntry>.generate(
  length,
  (int ordinal) => chapter(
    'c$ordinal',
    name: 'Chapter $ordinal',
    number: ordinal.toDouble(),
    ordinal: ordinal,
  ),
);

/// The library's own ChapterListTile surface, minus the comments — a grep that a line of prose
/// about "loadMore" could not accidentally fail.
String sourceOf(String path) => File(path)
    .readAsStringSync()
    .split('\n')
    .where((String line) => !line.trimLeft().startsWith('//'))
    .join('\n');

/// ⚠️ **No two of [texts] may contain one another, and they are compared BY INDEX.**
///
/// A set is not enough: two notices can differ and still one of them can swallow the other whole,
/// and only containment catches that. It is also why the strings are collected into a list first
/// — a lazily mapped iterable rebuilds each string on every pass, and `identical` would then
/// never match and the row would compare every string with itself.
void expectNoOverlapBetween(List<String> texts, String what) {
  for (int i = 0; i < texts.length; i++) {
    expect(texts[i], isNotEmpty, reason: 'a notice with no $what says nothing');
    for (int j = 0; j < texts.length; j++) {
      if (i == j) continue;
      expect(
        texts[i],
        isNot(contains(texts[j])),
        reason:
            '"the site could not be read" and "this app cannot read its own copy" are two '
            'different problems — one $what containing the other is a reader sent to look for a '
            'site fault they do not have',
      );
    }
  }
}

void main() {
  group('B10 — the site\'s own title, verbatim', () {
    testWidgets('a name renders as itself, and nothing wraps it in anything', (
      WidgetTester tester,
    ) async {
      await pumpBody(
        tester,
        ChapterListFilled(
          chapters: <ChapterEntry>[chapter('a', name: 'Omake')],
          unopenedCount: 1,
        ),
      );

      final Iterable<String> carrying = renderedText(
        tester,
      ).where((String text) => text.contains('Omake'));
      expect(
        carrying,
        <String>['Omake'],
        reason:
            'an irregular form is shown as the site published it — never with a generated '
            '"Chapter 12" in front of it and never capitalised differently',
      );
    });

    testWidgets('an empty name is the WORD *Untitled*, never an index', (
      WidgetTester tester,
    ) async {
      // ⚠️ B10 covers untitled chapters explicitly. A fabricated title is a sentence this app
      // invented, and the reader would believe it — an index looks exactly like one.
      await pumpBody(
        tester,
        ChapterListFilled(
          chapters: <ChapterEntry>[chapter('a', name: '')],
          unopenedCount: 1,
        ),
      );

      expect(find.text(copyIn(tester).chapterListUntitled), findsOneWidget);
      expect(
        find.text('Chapter'),
        findsNothing,
        reason:
            'a generated name is indistinguishable from one the site published',
      );
      expect(
        renderedText(tester).where((String t) => t.contains('1')),
        isNot(contains('Chapter 1')),
        reason: 'no ordinal was dressed up as a title',
      );
    });

    testWidgets('a 120-character name is whole in the tree AND in the semantics', (
      WidgetTester tester,
    ) async {
      // ⚠️ **Two halves, and the pair is the rule.** A title the reader cannot finish reading on
      // screen must still be readable by a screen reader, so the rendered `Text` and the
      // announced label are asserted separately — and neither may be an abbreviation.
      final String title = List<String>.filled(120, 'a').join();
      await pumpBody(
        tester,
        ChapterListFilled(
          chapters: <ChapterEntry>[chapter('a', name: title)],
          unopenedCount: 1,
        ),
      );

      expect(
        tester.widget<Text>(find.text(title)).data,
        title,
        reason: 'B10 renders the title whole and never as a shortened form',
      );
      final SemanticsNode announced = tester.getSemantics(find.text(title));
      expect(
        announced.label,
        contains(title),
        reason:
            'a reader using a screen reader is owed the same 120 characters a sighted reader '
            'sees — a truncated DOM label is an abbreviation by another name',
      );
      expect(
        find.textContaining('…'),
        findsNothing,
        reason:
            'no ellipsis is drawn, because the tile sets no maxLines: the plan\'s "an ellipsis, '
            'never an abbreviated form" is half-implemented — the half that is here is "never an '
            'abbreviated form", and this row holds that half',
      );
    });
  });

  group('B10 — 0 is a real chapter, and the em dash is not 0', () {
    testWidgets('⚠️ two ADJACENT tiles: `null` reads an em dash, `0` reads 0', (
      WidgetTester tester,
    ) async {
      // ⚠️ **Two neighbours in one screen, not two tests.** Collapsing `null` and `0` into one
      // glyph is invisible in a test that only ever renders one of them; the defect is only
      // visible with the two on screen at once.
      await pumpBody(
        tester,
        ChapterListFilled(
          chapters: <ChapterEntry>[
            chapter('a', name: 'The Weight of Salt', number: null),
            chapter('b', name: 'Omake', number: 0, ordinal: 1),
          ],
          unopenedCount: 2,
        ),
      );

      final Finder tiles = find.byType(ChapterTile);
      expect(tiles, findsNWidgets(2), reason: 'two chapters, two tiles');
      expect(
        tester
            .widget<Text>(
              find.descendant(of: tiles.at(0), matching: find.text('—')),
            )
            .data,
        '—',
        reason:
            '`null` is UNREADABLE, so the tile shows the site published no number this app could '
            'read — and never `-1`, which is the column\'s storage sentinel',
      );
      expect(
        tester
            .widget<Text>(
              find.descendant(of: tiles.at(1), matching: find.text('0')),
            )
            .data,
        '0',
        reason:
            '0 is a real chapter — an extra, an omake, an author\'s note — and collapsing it '
            'into "unknown" is a B10 violation',
      );
      expect(
        find.descendant(of: tiles.at(0), matching: find.text('0')),
        findsNothing,
        reason: 'the unreadable tile and the zero tile must not read alike',
      );
      expect(
        tester.getTopLeft(tiles.at(0)).dy,
        lessThan(tester.getTopLeft(tiles.at(1)).dy),
        reason:
            'the two are neighbours in the site\'s order — adjacent on screen is the only way '
            'the reader compares them',
      );
    });
  });

  group('E10 — the app never deduplicates', () {
    testWidgets('⚠️ two chapters with the same title are TWO tiles, both titled', (
      WidgetTester tester,
    ) async {
      // ⚠️ **Both `Ordinal` and `Id` are named**, so the only thing that could collapse these two
      // rows is a `Set` of names — the exact shortcut B10 forbids.
      await pumpBody(
        tester,
        ChapterListFilled(
          chapters: <ChapterEntry>[
            chapter('a', name: 'Extra', number: 0),
            chapter('b', name: 'Extra', number: 0, ordinal: 1),
          ],
          unopenedCount: 2,
        ),
      );

      expect(
        find.byType(ChapterTile),
        findsNWidgets(2),
        reason: 'two rows the site published are two rows on screen',
      );
      expect(
        find.text('Extra'),
        findsNWidgets(2),
        reason: 'neither tile lost its title to the other',
      );
      expect(
        find.byKey(const ValueKey<String>('a')),
        findsOneWidget,
        reason:
            'the tiles are keyed by the chapter\'s own id, so no row collapsed into another',
      );
      expect(
        find.byKey(const ValueKey<String>('b')),
        findsOneWidget,
        reason:
            'and the second chapter kept its own key — a name-keyed list would have collapsed '
            'the pair into one row',
      );
    });
  });

  group('B24 / B22 — a cause earns its own sentence', () {
    testWidgets('⚠️ three failures render three TITLEs and three sentences, no two alike', (
      WidgetTester tester,
    ) async {
      // ⚠️ **The titles are compared separately from the sentences, and the sabotage proved why.**
      // A shared BODY is caught by comparing whole sentences, but a shared TITLE is not: two
      // screens whose bodies differ still read alike at the top of the screen, and a reader
      // decides which problem they have from the title alone.
      final Map<ChapterListViewState, List<String>> notices =
          <ChapterListViewState, List<String>>{};
      for (final ChapterListViewState state in <ChapterListViewState>[
        const ChapterListSiteUnreadable(
          sourceName: 'Royal Road',
          failure: SourceUnavailable(status: 503),
        ),
        const ChapterListNeverLoaded(),
        const ChapterListStoredUnreadable(),
      ]) {
        await pumpBody(tester, state);
        final List<String> texts = renderedText(tester);
        // ⚠️ **The notice's own shape**, asserted before it is read: a title, then a body. Without
        // this the row would read a button's label as a body and pass on a collapsed notice.
        expect(
          texts.length,
          greaterThanOrEqualTo(2),
          reason:
              '${state.runtimeType} rendered no title and body to tell apart',
        );
        notices[state] = texts;
      }

      expectNoOverlapBetween(
        notices.values.map((List<String> texts) => texts.first).toList(),
        'title',
      );
      expectNoOverlapBetween(
        notices.values
            .map((List<String> texts) => texts.take(2).join('\n'))
            .toList(),
        'sentence',
      );
      expect(
        notices.keys,
        containsAll(<Matcher>[
          isA<ChapterListSiteUnreadable>(),
          isA<ChapterListNeverLoaded>(),
          isA<ChapterListStoredUnreadable>(),
        ]),
        reason:
            'the three problems are three types, which is why they can read differently',
      );
    });

    testWidgets('a retriable failure offers Try again, and a layout change does not', (
      WidgetTester tester,
    ) async {
      // ⚠️ **The pair on one screen is the second half.** "A second attempt is worth making only
      // when the cause says so" is only a rule if both answers are on the table.
      await pumpBody(
        tester,
        const ChapterListSiteUnreadable(
          sourceName: 'Royal Road',
          failure: SourceUnavailable(status: 503),
        ),
      );
      expect(
        find.text(copyIn(tester).chapterListActionRetry),
        findsOneWidget,
        reason:
            'a site answering 503 is worth asking again, so the failure states what to do next',
      );

      await pumpBody(
        tester,
        const ChapterListSiteUnreadable(
          sourceName: 'Royal Road',
          failure: SourceLayoutChanged(failedSelector: 'tr', status: 200),
        ),
      );
      expect(
        find.text(copyIn(tester).chapterListActionRetry),
        findsNothing,
        reason:
            'a layout change will answer 200 with the same markup tomorrow, so the button would '
            'be a promise the app cannot keep',
      );
    });
  });

  group('B22 — "empty" is a real answer only when the SITE said so', () {
    testWidgets('⚠️ the only real empty never says a count', (
      WidgetTester tester,
    ) async {
      // ⚠️ **The English phrase, not the plan's French one.** The plan writes
      // `find.textContaining('0 chapitres')`, which in an English locale finds nothing for the
      // wrong reason and would pass on a screen that said "0 chapters". The rule is the sentence,
      // not the locale.
      await pumpBody(
        tester,
        const ChapterListEmptyAtSource(
          sourceName: 'Royal Road',
          siteSuppliedSignal: 'There is nothing here :(',
        ),
      );

      final AppLocalizations copy = copyIn(tester);
      expect(
        find.text(copy.chapterListEmptyAtSourceTitle('Royal Road')),
        findsOneWidget,
        reason:
            'the sentence names the site, because the emptiness is ITS claim',
      );
      expect(
        find.text(copy.chapterListEmptyAtSourceBody),
        findsOneWidget,
        reason: 'it says the site said so, which is the only proof there is',
      );
      expect(find.textContaining('0 chapters'), findsNothing);
      expect(
        find.textContaining('0 chapitres'),
        findsNothing,
        reason: 'the FR rendering of the same forbidden sentence',
      );
      expect(
        find.byType(ListView),
        findsNothing,
        reason: 'a scrollable empty area reads as a list that failed to load',
      );
    });
  });

  group('E5 — no connection is a PRECONDITION, not a failure', () {
    testWidgets(
      '⚠️ nothing is painted in the error colour, and no control offers the load',
      (WidgetTester tester) async {
        // ⚠️ **Asserted on the RENDERED colours, not on the state class.** The state class is a
        // data structure nobody looks at; what matters is that nothing on this screen is red.
        await pumpBody(tester, const ChapterListNotLoadedNoConnection());

        final ColorScheme scheme = Theme.of(
          tester.element(find.byType(ChapterListBody)),
        ).colorScheme;
        final Iterable<Color?> painted = <Color?>[
          ...tester
              .widgetList<Text>(find.byType(Text))
              .map((Text text) => text.style?.color),
          ...tester
              .widgetList<Icon>(find.byType(Icon))
              .map((Icon icon) => icon.color),
        ];
        expect(
          painted.whereType<Color>().toSet(),
          isNot(contains(scheme.error)),
          reason:
              'nothing failed here — a precondition is missing, and red means a failure',
        );
        expect(
          find.text(copyIn(tester).chapterListNoConnectionTitle),
          findsOneWidget,
          reason:
              'the state still has to be named, or "no error on screen" is a screen with nothing '
              'on it',
        );
        expect(
          find.byIcon(Icons.cloud_off_outlined),
          findsNothing,
          reason:
              'that icon is this screen\'s "the site could not be read" — the app never asked the '
              'site, so naming it would send the reader looking for a fault they do not have',
        );
        expect(find.byType(FilledButton), findsNothing);
        expect(
          find.text(copyIn(tester).chapterListLoadAction),
          findsNothing,
          reason:
              'offering Load with no connection offers a tap that will fail for exactly the '
              'reason it just did — the plan spells this as a DISABLED Load at 48dp, and '
              'rendering no Load at all is the strictly stronger form of the same rule',
        );
        expect(
          renderedText(tester).join('\n'),
          contains(copyIn(tester).chapterListNoConnectionBody('Royal Road')),
          reason:
              'the sentence says the library is untouched, because a reader who just saw a '
              'connection warning needs to know nothing was lost',
        );
      },
    );

    testWidgets('⚠️ and the control it does render clears 48dp', (
      WidgetTester tester,
    ) async {
      // ⚠️ **`14-design-tokens.md` rule 24 — ≥ 48 × 48 logical px.** Asserted as the floor the
      // rule sets rather than as a button label: the row is about the size a thumb needs.
      await pumpBody(tester, const ChapterListNotLoadedNoConnection());

      expect(
        find.byType(OutlinedButton),
        findsOneWidget,
        reason: 'one way out of a state with nothing to load',
      );
      expect(
        tester.getSize(find.byType(OutlinedButton)).height,
        greaterThanOrEqualTo(48),
        reason: 'a control a thumb cannot hit is not a control',
      );
    });
  });

  group('E6 — the mark is a whole file, never a partial one', () {
    testWidgets('⚠️ no mark means no downloaded state, and the row is STILL there', (
      WidgetTester tester,
    ) async {
      // ⚠️ **A positive control next to the negative one.** An absence assertion is only worth
      // anything if the thing it is absent from exists: the downloaded tile proves the finder
      // and the icon are real, so the absence on the neighbour is a fact and not a typo.
      await pumpBody(
        tester,
        ChapterListFilled(
          chapters: <ChapterEntry>[
            chapter('a', name: 'The Weight of Salt'),
            chapter('b', name: 'Chapter Two', ordinal: 1, isDownloaded: true),
          ],
          unopenedCount: 2,
        ),
      );

      final Finder tiles = find.byType(ChapterTile);
      expect(
        tiles,
        findsNWidgets(2),
        reason: 'an undownloaded chapter is a row, never a gap',
      );
      expect(
        find.descendant(
          of: tiles.at(0),
          matching: find.byIcon(Icons.download_done_outlined),
        ),
        findsNothing,
        reason:
            'ADR-022 writes the mark only after the atomic rename, so `false` means the .md was '
            'never whole — and an interrupted download must never read as a finished one',
      );
      expect(
        find.descendant(
          of: tiles.at(0),
          matching: find.bySemanticsLabel(copyIn(tester).chapterTileDownloaded),
        ),
        findsNothing,
        reason:
            'the absence is asserted on the semantic label too, not only on the glyph',
      );
      expect(
        find.descendant(
          of: tiles.at(1),
          matching: find.byIcon(Icons.download_done_outlined),
        ),
        findsOneWidget,
        reason: 'the positive control: a marked chapter does carry the mark',
      );
    });
  });

  group('B9 — the list is complete, or the app says it is not', () {
    testWidgets('⚠️ 14 200 rows are asked for in ONE build call, with no page number', (
      WidgetTester tester,
    ) async {
      // ⚠️ **The count is checked on the delegate, not on `find.byType`.** The list is
      // virtualised — that is what makes ten thousand rows usable — so a lazy list builds about
      // eight tiles whatever it holds. Asserting `findsNWidgets(14200)` would be asserting that
      // virtualisation does not happen, which is the opposite of the rule. What B9 forbids is a
      // DEFERRED entry, and the delegate is where deferral would have to be written.
      const int total = 14200;
      await pumpBody(
        tester,
        ChapterListFilled(chapters: chaptersOfLength(total), unopenedCount: 1),
      );

      final ListView list = tester.widget<ListView>(find.byType(ListView));
      expect(
        (list.childrenDelegate as SliverChildBuilderDelegate).childCount,
        total * 2 - 1,
        reason:
            '`.separated` asks its delegate for every row plus every divider — one build call, no '
            'page number, nothing deferred (B9)',
      );
      expect(
        find.byType(ChapterTile),
        findsWidgets,
        reason:
            'and the list is still a list rather than a scrollable empty area',
      );
    });

    testWidgets('⚠️ and the LAST row is a real frame, reachable by scrolling to it', (
      WidgetTester tester,
    ) async {
      // ⚠️ **Jumped, not dragged, and at 400 rather than 14 200 — both for the same reason.** A
      // jump to the far end of a 28 399-child variably-extent sliver takes minutes in the test
      // VM; the property proved is identical at 400, and the 14 200 total is proved by the
      // delegate above. Dragging 400 times is not a test anyone runs either.
      const int total = 400;
      await pumpBody(
        tester,
        ChapterListFilled(chapters: chaptersOfLength(total), unopenedCount: 1),
      );

      expect(
        find.text('Chapter 0'),
        findsOneWidget,
        reason: 'the first row is the first frame',
      );
      tester
          .state<ScrollableState>(find.byType(Scrollable))
          .position
          .jumpTo(total.toDouble() * 1000);
      await tester.pumpAndSettle();

      expect(
        find.text('Chapter ${total - 1}'),
        findsOneWidget,
        reason:
            'the last row the site published is on screen — B9 forbids a deferred, truncated or '
            'replaced entry, and a "show more" would end the list before this',
      );
    });

    testWidgets('⚠️ the tail marker is a FACT: it names the total and offers no control', (
      WidgetTester tester,
    ) async {
      // ⚠️ **The label is asserted as COMPLETE — `14200 of 14200` — not as the plan\'s
      // `10000 of 14200`.** The implementation has no 10 000 threshold at all: it hands the
      // marker the whole length for both numbers, so what this row holds is the property that
      // must survive either design — the marker never claims rows are missing, and it is never a
      // button. (The plan\'s `if (storedRows.length > 10000)` threshold is unimplemented.)
      const int total = 14200;
      await pumpBody(
        tester,
        ChapterListFilled(chapters: chaptersOfLength(total), unopenedCount: 1),
      );

      expect(find.byType(ChapterListTailMarker), findsOneWidget);
      expect(
        renderedText(tester).last,
        '$total of $total chapters',
        reason:
            'the marker claims no truncation that did not happen — a reader must not be told '
            'rows are missing when every row is on screen',
      );
      expect(
        find.descendant(
          of: find.byType(ChapterListTailMarker),
          matching: find.byType(TextButton),
        ),
        findsNothing,
        reason:
            'B9 forbids a deferred entry, so a control implying a page two would be a promise '
            'the app cannot keep',
      );
      expect(
        find.descendant(
          of: find.byType(ChapterListTailMarker),
          matching: find.byIcon(Icons.refresh),
        ),
        findsNothing,
        reason: 'the same promise in the shape of an icon',
      );
    });

    test('⚠️ and no second page is offered anywhere in the feature', () {
      // ⚠️ **A grep, not a finder.** A page-two control that no row in this file happens to
      // reach is still a violation, and no finder over the filled state would see it.
      final List<File> files = Directory(
        'lib/features/novel_details',
      ).listSync(recursive: true).whereType<File>().toList();
      expect(
        files,
        isNotEmpty,
        reason:
            'the walk found nothing, which would make the assertions below pass without reading '
            'a single line of the feature',
      );
      for (final File file in files) {
        final String code = sourceOf(file.path);
        for (final String forbidden in <String>[
          'showMore',
          'hasMorePage',
          'loadMore',
          'charger plus',
        ]) {
          expect(
            code,
            isNot(contains(forbidden)),
            reason:
                '${file.path} offers a page two, and B9 says the list is complete',
          );
        }
      }
    });
  });

  group('§ 11.5 — at 360dp, the only width v1 ships', () {
    testWidgets('⚠️ a 120-character site title overflows NOTHING at 360dp', (
      WidgetTester tester,
    ) async {
      // ⚠️ **GAP — the plan's `getSize(find.byType(ChapterListTile)).height == 56` is NOT
      // satisfied, and the reason is a defect, not a number.** There is no `itemExtent: 56` on
      // the list and no `maxLines` on the title, so a tile is as tall as its own title: 72dp for
      // a one-line site title with its unread subtitle, and 224dp for a 120-character one. What
      // is asserted here is therefore the half the design tokens actually own — the 48dp
      // tap-target floor and the absence of a horizontal overflow — and the exact height is left
      // to the slice that implements the fixed extent.
      await pumpBody(
        tester,
        ChapterListFilled(
          chapters: <ChapterEntry>[
            chapter('a', name: 'Omake', number: null),
            chapter('b', name: 'Extra', number: 0, ordinal: 1),
            chapter(
              'c',
              name: List<String>.filled(120, 'a').join(),
              ordinal: 2,
            ),
          ],
          unopenedCount: 3,
        ),
      );

      expect(
        tester.takeException(),
        isNull,
        reason:
            'a 120-character site title at the design width is a wrap, not an overflow',
      );
      for (final Element tile in find.byType(ChapterTile).evaluate()) {
        final Size size = tester.getSize(find.byWidget(tile.widget));
        expect(
          size.width,
          designSize.width,
          reason:
              'a tile is the width of the design surface and no more — a title that forced a '
              'horizontal scroll would push the chapter numbers off the screen',
        );
        expect(
          size.height,
          greaterThanOrEqualTo(48),
          reason:
              'the tile is a tappable affordance, so it is at least a thumb tall',
        );
      }
    });

    testWidgets('⚠️ and a one-line site title gives every tile ONE height', (
      WidgetTester tester,
    ) async {
      // ⚠️ **The uniformity that does hold**, written so the row above cannot be read as "the
      // height is whatever the title needs". For titles the site publishes on one line, no
      // chapter's own text changes how much of the screen its neighbours take.
      await pumpBody(
        tester,
        ChapterListFilled(
          chapters: <ChapterEntry>[
            chapter('a', name: 'Omake'),
            chapter('b', name: 'Extra', ordinal: 1),
            chapter('c', name: 'Ch. 12.5', ordinal: 2),
          ],
          unopenedCount: 3,
        ),
      );

      final Iterable<double> heights = find
          .byType(ChapterTile)
          .evaluate()
          .map(
            (Element element) =>
                tester.getSize(find.byWidget(element.widget)).height,
          )
          .toSet();
      expect(
        heights,
        hasLength(1),
        reason:
            'a reader scanning a page of tiles is counting rows by eye, so one row must not be '
            'taller than another because of its own text',
      );
    });
  });
}
