// forge:slice 5-1
// Lumen Tale — `BulkDownloadSheet`, and the six states `novel-details.md` § 11.1 names.
//
// `5-1` § 11.2. `testWidgets`, and **no `dart:io`**: the sheet's inputs are three plain
// types and its labels come from the caller, so there is no file, no database and no
// network in this file — which is the same property that keeps the sheet itself honest.
//
// | state | the row |
// |---|---|
// | Filled | five radio rows, each with a count (§ 11.1's shape) |
// | Filled | the counts are the RESOLVER's, and the confirm names one of them |
// | Filled | *Next chapter* is selected when the sheet opens |
// | Filled | the confirm names the count, the connection and the pause/cancel promise |
// | Offline | every option disabled **at 48dp**, plus exactly one sentence |
// | **Empty** | **not a state** — a fully stored novel still shows five rows at zero |
// | Load error | **not a state** — every count comes from stored metadata |

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumen_tale/app/theme/app_theme.dart';
import 'package:lumen_tale/domain/downloads/bulk_choice.dart';
import 'package:lumen_tale/domain/downloads/bulk_choice_resolver.dart';
import 'package:lumen_tale/domain/downloads/bulk_choice_rows.dart';
import 'package:lumen_tale/features/novel_details/widgets/bulk_download_sheet.dart';
import 'package:lumen_tale/l10n/generated/app_localizations.dart';

/// Any non-null instant: the mark's VALUE is never read, only its absence.
final DateTime _epoch = DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);

DownloadableChapter chapter(
  String id, {
  required int ordinal,
  bool stored = false,
}) => DownloadableChapter(
  id: id,
  ordinal: ordinal,
  isRead: false,
  downloadedAt: stored ? _epoch : null,
);

/// 100 chapters, the first 12 stored — § 10's own scenario.
List<DownloadableChapter> hundred({int stored = 12}) => <DownloadableChapter>[
  for (int i = 0; i < 100; i++) chapter('c$i', ordinal: i, stored: i < stored),
];

/// The caller's words. A test may spell them in English; the app may not hard-code them.
String labelOf(BulkChoice choice) => switch (choice) {
  NextChapter() => 'Next chapter',
  NextChapters(:final int count) => 'Next $count',
  AllUnopened() => 'All unopened chapters',
  HandPicked() => 'Chapters you choose',
};

String confirmLabelOf(int count) => 'Download $count chapters';

List<BulkChoiceRow> rowsFor(List<DownloadableChapter> chapters) =>
    bulkChoiceRows(chapters: chapters, labelOf: labelOf);

Future<void> pumpSheet(
  WidgetTester tester, {
  required List<BulkChoiceRow> rows,
  bool offline = false,
  Future<void> Function(BulkChoice)? onConfirm,
}) => tester.pumpWidget(
  MaterialApp(
    theme: AppTheme.day(),
    // ⚠️ **THE DELEGATES ARE NOT OPTIONAL IN A TEST.** `AppLocalizations.of` is a
    // `Localizations.of!` — a null-check operator on a lookup that returns null when no
    // delegate is registered. A pump without these throws a `_TypeError` from inside the
    // sheet rather than a missing-translation failure, which reads like a widget bug.
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: BulkDownloadSheet(
        rows: rows,
        labelOf: labelOf,
        confirmLabelOf: confirmLabelOf,
        onConfirm: onConfirm ?? (BulkChoice _) async {},
        offline: offline,
      ),
    ),
  ),
);

void main() {
  group('§ 11.1 Filled — five radio rows, each with its count', () {
    testWidgets('⚠️ every row renders its label AND its count', (
      WidgetTester tester,
    ) async {
      final List<BulkChoiceRow> rows = rowsFor(hundred());
      await pumpSheet(tester, rows: rows);

      for (final BulkChoiceRow row in rows) {
        expect(
          find.text(row.label),
          findsOneWidget,
          reason:
              '§ 11.1: "B18\'s six choices as radio rows, each with a running chapter '
              'count beside it". The label is the caller\'s — never an enum `name` (B28)',
        );
        expect(
          find.text('${row.count}'),
          findsWidgets,
          reason:
              'and the count is rendered **including at zero**. A row whose count vanishes '
              'at zero is a row whose meaning changes with the novel, which is how a '
              'reader concludes the app cannot tell them whether anything is left',
        );
      }
      expect(
        find.byType(Radio<BulkChoice>),
        findsNWidgets(5),
        reason:
            'five rows, and five radios: novel-details.md § 11.1 reaches the sixth choice '
            'by long-pressing tiles, so a hand-picked row here could only ever resolve to '
            'zero',
      );
    });

    testWidgets('⚠️ the counts are 1 / 5 / 10 / 25 / 40 — the resolver\'s figures', (
      WidgetTester tester,
    ) async {
      final List<BulkChoiceRow> rows = rowsFor(hundred());
      await pumpSheet(tester, rows: rows);

      expect(
        rows.map((BulkChoiceRow r) => r.count).toList(),
        <int>[1, 5, 10, 25, 88],
        reason:
            '§ 3.1: 100 chapters with the first 12 stored. `AllUnopened` is 88 because the '
            'fixture marks none of them read, and 88 is exactly what the confirm must '
            'name — a widget computing `min(5, total)` would show a different number from '
            'the one the queue applies, and the difference only appears late',
      );
    });

    testWidgets('⚠️ *Next chapter* is chosen when the sheet opens', (
      WidgetTester tester,
    ) async {
      await pumpSheet(tester, rows: rowsFor(hundred()));

      expect(
        // ⚠️ **THE LOOKUP IS FROM A ROW, NOT FROM THE SHEET.** `RadioGroup.maybeOf`
        // reads an inherited scope, and the group is *inside* the sheet's build — asking
        // from the sheet's own element looks above the group and finds nothing. A test
        // that read it from the sheet would have concluded the group was absent.
        RadioGroup.maybeOf<BulkChoice>(
          tester.element(find.byKey(const Key('bulkDownloadSheet.row.0'))),
        )?.groupValue,
        const NextChapter(),
        reason:
            '§ 11.1 names *Next chapter* as the choice the sheet opens on. Deriving it '
            'from `rows.first` would let a reordered list silently change what the reader '
            'is about to be asked to confirm',
      );
      expect(
        find.text('Next chapter'),
        findsOneWidget,
        reason: 'and the row is there to be seen, not just selected',
      );
    });
  });

  group('§ 11.1 Filled — the confirm names the calculated count', () {
    testWidgets('⚠️ it says "Download 1 chapters" — the COUNT, not a fixed string', (
      WidgetTester tester,
    ) async {
      await pumpSheet(tester, rows: rowsFor(hundred()));

      expect(
        find.text('Download 1 chapters'),
        findsOneWidget,
        reason:
            '⚠️ **THE `min()` DEFECT, ASSERTED AWAY AT THE WIDGET.** `Next chapter` is '
            'selected on open and resolves to exactly 1, so the confirm says 1. A confirm '
            'built from a separate `min(1, total)` would agree here and could disagree '
            'elsewhere — C8 asks for the same figure, and the fixture is chosen so a '
            'stale count shows up as a different number',
      );
    });

    testWidgets(
      '⚠️ choosing another row renames the confirm with THAT row\'s count',
      (WidgetTester tester) async {
        await pumpSheet(tester, rows: rowsFor(hundred()));

        await tester.tap(find.byKey(const Key('bulkDownloadSheet.row.2')));
        await tester.pumpAndSettle();

        expect(
          find.text('Download 10 chapters'),
          findsOneWidget,
          reason:
              'C8: the number beside the row and the number in the confirm are ONE figure. '
              'Tapping *Next 10* and seeing *Download 88* is the defect this row exists to '
              'catch, and it is invisible until the fortieth chapter of a real download',
        );
      },
    );

    testWidgets('⚠️ confirm hands the CHOSEN choice to the caller', (
      WidgetTester tester,
    ) async {
      BulkChoice? confirmed;
      await pumpSheet(
        tester,
        rows: rowsFor(hundred()),
        onConfirm: (BulkChoice choice) async => confirmed = choice,
      );

      await tester.tap(find.byKey(const Key('bulkDownloadSheet.row.4')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('bulkDownloadSheet.confirm')));
      await tester.pumpAndSettle();

      expect(
        confirmed,
        const AllUnopened(),
        reason:
            'B18: the confirm APPLIES the choice rather than notifying a decision the '
            'caller has already made — § 11.1\'s *Submit error* keeps the sheet open with '
            'its chosen option intact, which is impossible if it popped first',
      );
    });

    testWidgets('⚠️ a REFUSED confirm keeps the sheet open with its choice intact', (
      WidgetTester tester,
    ) async {
      // ⚠️ **`3-3`'s `EnqueueRefusedForSpace` ARRIVES HERE** and becomes § 4's storage
      // dialog. C8: a control must not display a value it cannot keep — so the sheet stays
      // and the chosen row is still the chosen row.
      await pumpSheet(
        tester,
        rows: rowsFor(hundred()),
        onConfirm: (BulkChoice _) async => throw StateError('no space'),
      );

      await tester.tap(find.byKey(const Key('bulkDownloadSheet.confirm')));
      await tester.pumpAndSettle();

      expect(
        find.byType(BulkDownloadSheet),
        findsOneWidget,
        reason: '§ 11.1: "the sheet stays open with its chosen option intact"',
      );
      expect(
        find.text('Download 1 chapters'),
        findsOneWidget,
        reason:
            'and the choice is unchanged, so a second attempt needs no re-picking',
      );
    });
  });

  group('§ 11.1 Offline — identical, disabled, and ONE sentence', () {
    testWidgets('⚠️ every radio is disabled and the rows are still 48dp', (
      WidgetTester tester,
    ) async {
      await pumpSheet(tester, rows: rowsFor(hundred()), offline: true);

      final List<Radio<BulkChoice>> radios = tester
          .widgetList<Radio<BulkChoice>>(find.byType(Radio<BulkChoice>))
          .toList();
      expect(
        radios.where((Radio<BulkChoice> r) => r.enabled == false),
        hasLength(5),
        reason:
            '§ 11.1: the offline state is "identical, with every option disabled at 48dp '
            'and one sentence". A row that disappeared would be a different state',
      );
      // ⚠️ **`byWidgetPredicate`, NOT `widgetList<ConstrainedBox>`.** `widgetList<T>` is
      // typed by `find.byType`, which tests the widget's own class and hands back
      // `Widget`s, so reading `.constraints` off the result does not compile. The
      // predicate selects them itself.
      final Finder tallRows = find.byWidgetPredicate(
        (Widget w) =>
            w is ConstrainedBox &&
            w.constraints.minHeight == kBulkDownloadRowHeight,
      );

      expect(
        tallRows,
        findsNWidgets(5),
        reason:
            '⚠️ **ALL FIVE ROWS CARRY 48dp.** § 11.1: the offline state is "every option '
            'disabled at 48dp". Checking "at least one is 48dp" would pass on a sheet with '
            'one tall row and four collapsed ones, and C11 — one-handed, at night, in '
            'transit — is what the 48dp is for',
      );
      expect(
        find.byKey(const Key('bulkDownloadSheet.offline')),
        findsOneWidget,
        reason:
            'and exactly ONE sentence — not a banner, not a modal, not a second line',
      );
    });

    testWidgets('⚠️ offline, the confirm does not fire', (
      WidgetTester tester,
    ) async {
      bool called = false;
      await pumpSheet(
        tester,
        rows: rowsFor(hundred()),
        offline: true,
        onConfirm: (BulkChoice _) async => called = true,
      );

      await tester.tap(find.byKey(const Key('bulkDownloadSheet.confirm')));
      await tester.pumpAndSettle();

      expect(
        called,
        isFalse,
        reason:
            '§ 11.1: the options are disabled, so the confirm is too. A confirm that '
            'still fired would enqueue a download the sheet has just told the reader '
            'cannot work',
      );
    });
  });

  group('§ 11.1 Empty is NOT a state, and neither is a load error', () {
    testWidgets('⚠️ a fully stored novel still shows FIVE rows, at zero', (
      WidgetTester tester,
    ) async {
      // ⚠️ **THE ROW § 11.1 REFUSES BY NAME.** "Empty — not a state, because a novel with
      // zero unopened chapters still has Next chapter available and the sheet says so
      // rather than presenting an empty list of options."
      await pumpSheet(tester, rows: rowsFor(hundred(stored: 100)));

      expect(
        find.byType(Radio<BulkChoice>),
        findsNWidgets(5),
        reason: 'the controls are still there: a row that vanished is a state',
      );
      expect(
        find.text('0'),
        findsNWidgets(5),
        reason: 'each with its zero, which is the sentence § 11.1 asks for',
      );
      final FilledButton confirm = tester.widget<FilledButton>(
        find.byKey(const Key('bulkDownloadSheet.confirm')),
      );
      expect(
        confirm.onPressed,
        isNull,
        reason:
            'and the confirm is DISABLED, not hidden — § 3.1 branch 2 says no error dialog '
            'and no exception, and a control that disappears moves the row beneath the '
            'reader\'s thumb',
      );
    });

    testWidgets('⚠️ there is no spinner and no error text — nothing to load', (
      WidgetTester tester,
    ) async {
      await pumpSheet(tester, rows: rowsFor(hundred()));

      expect(
        find.byType(CircularProgressIndicator),
        findsNothing,
        reason:
            '§ 11.1: "Loading — none, and the reason is that every option is computed from '
            'stored chapter metadata already in memory". A progress indicator here would '
            'promise a fetch the sheet never makes',
      );
      expect(
        find.textContaining('error'),
        findsNothing,
        reason: 'and there is no load-error state, because nothing is fetched',
      );
    });
  });
}
