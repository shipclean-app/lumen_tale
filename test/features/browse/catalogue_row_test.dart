// forge:slice 3-1
// Lumen Tale — the catalogue ROW's two actions, which is where the discovery loop closes.
//
// ## What this file exists for
//
// `3-1` built the catalogue and left its row's trailing control as
// `TextButton(onPressed: () {})` — a button labelled *add this novel* that **added
// nothing**. A green suite had nothing to say about it, because a widget that renders an
// empty closure is indistinguishable from a widget that renders a working one until a
// reader presses it.
//
// ## The rows
//
// | rule | the row |
// |---|---|
// | B40 — the row opens THE novel in the row | *the tap carries this novel's id, not one looked up by title* |
// | B12 — the add reaches the novel's own screen | *the button goes somewhere real* |
// | B11 — a kept row's Add is ABSENT, not disabled | *kept rows carry the marker and no button* |
// | B12 — no swipe, no long-press | *the row has no second gesture* |

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumen_tale/domain/sources/models/novel.dart';
import 'package:lumen_tale/features/browse/catalogue_screen.dart';
import 'package:lumen_tale/l10n/generated/app_localizations.dart';

Novel novel({String id = 'n1', String title = 'The Rune Smith'}) => Novel(
  id: id,
  sourceId: 'rr',
  url: '/fiction/1/$id',
  title: title,
  author: 'A. Writer',
  description: '',
  status: NovelStatus.ongoing,
  coverUrl: '',
  genres: const <String>[],
);

/// What the row did, recorded — because a callback that is never invoked must be
/// distinguishable from one that is invoked with the wrong novel.
final List<String> log = <String>[];

Widget host(Widget child) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: child),
);

CatalogueRow row({
  Novel? item,
  bool isKept = false,
  void Function(Novel)? onOpen,
  void Function(Novel)? onAdd,
}) => CatalogueRow(
  novel: item ?? novel(),
  isKept: isKept,
  // ⚠️ **The callback takes the NOVEL, and the default records which one.** A row whose
  // action ignored its argument would pass an assertion that only checked "something
  // happened" — and B40 is entirely about the novel being the RIGHT one.
  onOpen: onOpen ?? (Novel n) => log.add('open:${n.id}'),
  onAdd: onAdd ?? (Novel n) => log.add('add:${n.id}'),
);

void main() {
  setUp(log.clear);

  group('B40 — the row opens THE novel it is showing', () {
    testWidgets('⚠️ the TAP opens this row\'s novel, by its own id', (
      WidgetTester tester,
    ) async {
      final List<String> opened = <String>[];
      await tester.pumpWidget(
        host(
          row(
            item: novel(id: 'n7'),
            onOpen: (Novel n) => opened.add(n.id),
          ),
        ),
      );

      await tester.tap(find.text('The Rune Smith'));
      await tester.pumpAndSettle();

      expect(
        opened,
        <String>['n7'],
        reason:
            'B40 says "the novel in the row, never one with a similar title". A row that '
            're-derived the novel from its title would open the wrong one of two identically '
            'named novels — which is the entire case B40 exists for',
      );
    });

    // ⚠️ **TWO ROWS, SAME TITLE, TWO DIFFERENT DESTINATIONS.** The identity row above can
    // pass with an implementation that looks the novel up by title, because there is only
    // one novel with that title in the test. This is the row that closes it.
    testWidgets('⚠️ two novels with the SAME title open two different places', (
      WidgetTester tester,
    ) async {
      final List<String> opened = <String>[];
      await tester.pumpWidget(
        host(
          Column(
            children: <Widget>[
              row(
                item: novel(id: 'first', title: 'Regression'),
                onOpen: (Novel n) => opened.add(n.id),
              ),
              row(
                item: novel(id: 'second', title: 'Regression'),
                onOpen: (Novel n) => opened.add(n.id),
              ),
            ],
          ),
        ),
      );

      await tester.tap(find.text('Regression').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Regression').last);
      await tester.pumpAndSettle();

      expect(
        opened,
        <String>['first', 'second'],
        reason:
            'two novels, one title, two destinations — the anti-merge case, asserted as two '
            'taps rather than one',
      );
    });
  });

  group('B12 — the add control goes somewhere real', () {
    // ⚠️ **THIS IS THE ROW THAT WOULD HAVE CAUGHT THE `() {}`.** It pressed the button that
    // shipped and asserted an action came out; nothing came out, so the row fails.
    testWidgets(
      '⚠️ pressing Add does SOMETHING — the button that shipped did nothing',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          host(row(onAdd: (Novel n) => log.add('add:${n.id}'))),
        );

        await tester.tap(find.text('Add'));
        await tester.pumpAndSettle();

        expect(
          log,
          <String>['add:n1'],
          reason:
              'the trailing control is labelled *add this novel*; an empty onPressed rendered a '
              'promise and broke it. A control that navigates to nothing is a button that lies',
        );
      },
    );

    testWidgets('⚠️ Add and the row TAP are SEPARATE actions, both present', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(host(row()));

      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();
      expect(log, <String>['add:n1'], reason: 'the button does the add path');

      await tester.tap(find.text('The Rune Smith'));
      await tester.pumpAndSettle();
      expect(log, <String>[
        'add:n1',
        'open:n1',
      ], reason: 'and the row opens the novel');
    });
  });

  group('B11 — a kept row carries the MARKER, not a disabled button', () {
    testWidgets('⚠️ a KEPT row has no Add at all — ABSENT, not disabled', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(host(row(isKept: true)));

      expect(find.text('In your library'), findsOneWidget);
      expect(
        find.text('Add'),
        findsNothing,
        reason:
            'B11, and `browse-catalogue.md`: absent, NOT disabled. A greyed *Add* on a row '
            'the reader can still open invites them to work out what they are missing — and '
            'on this screen there is nothing they could do about it',
      );
      expect(find.byType(TextButton), findsNothing);
    });

    // ⚠️ **AND THE ROW STILL OPENS.** The design says so explicitly: "What remains available
    // on the row is reading." A kept row that became inert would strand a reader who wants
    // to open a novel they already keep.
    testWidgets('⚠️ a KEPT row still OPENS the novel', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(host(row(isKept: true)));

      await tester.tap(find.text('The Rune Smith'));
      await tester.pumpAndSettle();

      expect(
        log,
        <String>['open:n1'],
        reason:
            'keeping and following are the same thing, but neither one stops the reader '
            'reading the novel — this row is the only way in from here',
      );
    });
  });

  group('B12 — and no second gesture that KEEPS anything', () {
    // ⚠️ **LONG-PRESS OPENS THE NOVEL, AND THAT IS CORRECT.** The first version of this row
    // asserted a long press does *nothing* at all, and it failed — because with no long-press
    // handler, `ListTile`'s tap recogniser wins the gesture arena and fires `onTap`. That is
    // Material's documented behaviour, not a defect.
    //
    // So the row states the rule B12 actually cares about: a long press must not **ADD**.
    // The failure mode the design names is "a gesture that fires while the list is scrolling
    // would keep novels the reader never looked at" — keeping, not opening. Opening is inert.
    testWidgets('⚠️ a long press OPENS, and never ADDS', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(host(row()));

      await tester.longPress(find.text('The Rune Smith'));
      await tester.pumpAndSettle();

      expect(
        log,
        <String>['open:n1'],
        reason:
            'long-press resolves to the same tap, which is Material\'s own behaviour with no '
            'long-press handler installed — and opening a novel the reader is looking at is '
            'inert',
      );
      expect(
        log.where((String e) => e.startsWith('add')),
        isEmpty,
        reason:
            'and NOTHING was kept. The failure the design names is a gesture that fires '
            'while the list scrolls adding novels nobody looked at — so the assertion is on '
            'the ADD, not on the tap',
      );
    });

    testWidgets(
      '⚠️ there is NO swipe-to-add and NO checkbox anywhere on the row',
      (WidgetTester tester) async {
        await tester.pumpWidget(host(row()));

        expect(
          find.byType(Checkbox),
          findsNothing,
          reason:
              'B12: no checkbox. A row that could be ticked while scrolling would be a '
              'selection gesture disguised as a membership one',
        );
        expect(
          find.byType(Dismissible),
          findsNothing,
          reason: 'and no swipe-to-add: the same argument, with a side effect',
        );
        expect(
          find.byType(CheckboxListTile),
          findsNothing,
          reason: 'nor a checkbox row wearing a different widget name',
        );
      },
    );
  });
}
