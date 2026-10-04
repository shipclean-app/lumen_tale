// forge:slice 5-1
// Lumen Tale — `ChapterSelectionBar`, B18's sixth choice, and its two absences.
//
// `5-1` § 11.2, from `novel-details.md` § 11.3.
//
// ## ⚠️ **THIS FILE IS MOSTLY ABOUT WHAT IS *NOT* THERE**
//
// § 11.3 names three things the bar may never have:
//
//  1. **no "select all"** — B18 reserves *"every chapter including ones already read"* for
//     a **deliberate** selection, and a select-all button is the exact opposite of
//     deliberate;
//  2. **no "add to library"** — a selection is a download instrument, and membership is one
//     act on one screen (B11);
//  3. **no reordering** — which is why the ids are a `List` and why
//     `resolveBulkChoice`'s `HandPicked` branch preserves the caller's order.
//
// An absence cannot be tested by calling the thing that is there. It is tested by counting
// the things that ARE there, and by refusing the shape the absence forbids.
//
// ## ⚠️ **THE SELECTED TILE BORROWS `NovelRow`'s GRAMMAR**
//
// § 11.3: *"`ChapterListTile` declares no `selected` state … this screen renders selection
// with the app's single selection grammar, `NovelRow`'s declared `selected` presentation."*
// Adding `selected` to `ChapterListTile` would be a decision for the design system's owner,
// and a local variant would give the app two grammaries for one meaning.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumen_tale/app/theme/app_theme.dart';
import 'package:lumen_tale/app/theme/lumen_colors.dart';
import 'package:lumen_tale/domain/downloads/bulk_choice_resolver.dart';
import 'package:lumen_tale/domain/downloads/bulk_choice_rows.dart';
import 'package:lumen_tale/features/novel_details/widgets/chapter_selection_bar.dart';
import 'package:lumen_tale/l10n/generated/app_localizations.dart';

Future<void> pumpBar(
  WidgetTester tester, {
  required int selectedCount,
  VoidCallback? onDownload,
  VoidCallback? onClear,
}) => tester.pumpWidget(
  MaterialApp(
    theme: AppTheme.day(),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: ChapterSelectionBar(
        selectedCount: selectedCount,
        onDownload: onDownload ?? () {},
        onClear: onClear ?? () {},
        // ⚠️ **A REAL SENTENCE, PASSED IN.** The bar's wording is the screen's; a test may
        // spell it in English, and the app must not hard-code it.
        selectedLabel: '$selectedCount selected',
      ),
    ),
  ),
);

void main() {
  group('§ 11.3 Filled — `3 selected · Download · Cancel`', () {
    testWidgets('⚠️ the bar renders exactly three things', (
      WidgetTester tester,
    ) async {
      await pumpBar(tester, selectedCount: 3);

      expect(
        find.text('3 selected'),
        findsOneWidget,
        reason: 'the count comes first',
      );
      expect(
        find.text('Download'),
        findsOneWidget,
        reason:
            '§ 11.3: `n selected · Download · Cancel`. The count is what makes the tap a '
            'decision rather than a leap — a label of "Download" alone tells a '
            'screen-reader user nothing about what is about to happen',
      );
      expect(
        find.text('Cancel'),
        findsOneWidget,
        reason: 'and Cancel clears the selection',
      );
      expect(
        find.byType(FilledButton),
        findsOneWidget,
        reason:
            '⚠️ **THREE THINGS, NOT FOUR.** § 11.3 refuses *select all* (B18 reserves '
            '"every chapter including ones already read" for a deliberate selection) and '
            '*add to library* (a selection is a download instrument; B11 makes membership '
            'one act on one screen). Counting the buttons is what makes those two absences '
            'testable',
      );
      expect(
        find.byType(TextButton),
        findsOneWidget,
        reason: 'one TextButton — Cancel — and no second one hiding a shortcut',
      );
    });

    testWidgets('⚠️ Download hands the selection over and Cancel drops it', (
      WidgetTester tester,
    ) async {
      int downloads = 0;
      int clears = 0;
      await pumpBar(
        tester,
        selectedCount: 3,
        onDownload: () => downloads += 1,
        onClear: () => clears += 1,
      );

      await tester.tap(find.text('Download'));
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(downloads, 1, reason: 'Download emits the selection');
      expect(clears, 1, reason: 'and Cancel emits the clear');
    });

    testWidgets('⚠️ at zero, Download is DISABLED and the bar does not reflow', (
      WidgetTester tester,
    ) async {
      await pumpBar(tester, selectedCount: 0);

      final FilledButton download = tester.widget<FilledButton>(
        find.ancestor(
          of: find.text('Download'),
          matching: find.byType(FilledButton),
        ),
      );
      expect(
        download.onPressed,
        isNull,
        reason:
            'C11 and `pinned_action_row.dart`\'s rule: a control that DISAPPEARS moves '
            'its neighbours, and the last selected tile is exactly when a reader reaches '
            'for the bar. The button stays, greyed, saying there is nothing to act on',
      );
      expect(
        find.text('Cancel'),
        findsOneWidget,
        reason:
            'and Cancel is still there, because cancelling an empty selection is '
            'still a way out',
      );
    });
  });

  group('§ 11.3 — the absence of REORDERING, and why the ids are a list', () {
    testWidgets('⚠️ the bar offers no drag, no sort and no move', (
      WidgetTester tester,
    ) async {
      await pumpBar(tester, selectedCount: 3);

      expect(
        find.byType(ReorderableListView),
        findsNothing,
        reason:
            '§ 11.3 declares NO reordering gesture in the selection bar, which is why the '
            'reader\'s insertion order IS the queue order — and why `resolveBulkChoice`\'s '
            '`HandPicked` branch preserves the caller\'s order instead of sorting it',
      );
      expect(
        find.byType(ReorderableDragStartListener),
        findsNothing,
        reason: 'and no drag handle of any kind',
      );
      expect(
        find.byIcon(Icons.drag_handle),
        findsNothing,
        reason:
            '⚠️ **THE ICON ROW, BECAUSE A HANDLING BUTTON IS THE EASIEST ABSENCE TO ADD '
            'BACK.** § 11.3 refuses the gesture, and an affordance is a gesture',
      );
    });

    test('⚠️ and the ORDER survives from the tap to the choice', () {
      // ⚠️ **THE PURE HALF, IN A PLAIN `test()`.** No widget, no database: the property is
      // that a list in, the same list out.
      final List<DownloadableChapter> chapters = <DownloadableChapter>[
        for (int i = 0; i < 5; i++)
          DownloadableChapter(
            id: 'c$i',
            ordinal: i,
            isRead: false,
            downloadedAt: null,
          ),
      ];
      final HandPickedSelection selection = HandPickedSelection(<String>[
        'c4',
        'c0',
        'c2',
      ]);

      expect(
        resolveBulkChoice(selection.toChoice(), chapters: chapters),
        <String>['c4', 'c0', 'c2'],
        reason:
            'B18 + § 11.3: the bar has no reordering gesture, so the reader\'s insertion '
            'order is the queue order. A resolver that sorted by `ordinal` would discard '
            'the only thing the reader expressed, and this slice is where that would '
            'happen — not in the bar',
      );
    });
  });

  group('design-system.md § 2.1 — the borrowed `selected` grammar', () {
    testWidgets(
      '⚠️ the selected tile is a 2dp `--color-border-strong` edge + 10% accent',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.day(),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Scaffold(
              body: SelectedChapterTile(
                child: ListTile(title: Text('Chapter 3'), selected: true),
              ),
            ),
          ),
        );

        final DecoratedBox box = tester.widget<DecoratedBox>(
          find
              .descendant(
                of: find.byType(SelectedChapterTile),
                matching: find.byType(DecoratedBox),
              )
              .first,
        );
        final BoxDecoration decoration = box.decoration as BoxDecoration;

        expect(
          (decoration.border as Border).left.width,
          2,
          reason:
              '§ 11.3 quotes `NovelRow`\'s declared `selected` presentation verbatim: "a 2dp '
              '`--color-border-strong` leading edge plus a `--color-accent` 10% fill, '
              'identical to a selected library row". One grammar for one meaning across the '
              'app is worth more than a locally invented variant',
        );
        expect(
          decoration.color,
          LumenColors.day().accent.withValues(alpha: 0.1),
          reason:
              'and the 10% accent fill, the other half of the borrowed grammar',
        );
        expect(
          decoration.boxShadow,
          isNull,
          reason:
              '⚠️ **NO SHADOW.** `downloads.md` § 2.1: flat rows and a border rule; the app '
              'keeps exactly two shadows and a selected tile is not one of them',
        );
      },
    );

    testWidgets('⚠️ the tile underneath is still the tile — no local variant', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.day(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(
            body: SelectedChapterTile(
              child: ListTile(title: Text('Chapter 3')),
            ),
          ),
        ),
      );

      expect(
        find.text('Chapter 3'),
        findsOneWidget,
        reason:
            '⚠️ **SELECTION COMPOSES WITH THE TILE\'S OWN STATES.** § 11.3: "a tile can be '
            '*read and selected*, or *unread and selected*, so selection is orthogonal to '
            'every state the component declares". The wrapper supplies selection and nothing '
            'else, so `read`, `failed` and `downloading` keep working underneath',
      );
      expect(
        find.byType(SelectedChapterTile),
        findsOneWidget,
        reason:
            'and the wrapper is a separate widget rather than a `ChapterListTile` state — '
            '`design-check component-parity` would flag an invented variant, and two '
            'grammars for one meaning is the defect § 11.3 records',
      );
    });
  });
}
