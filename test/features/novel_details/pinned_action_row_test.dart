// forge:slice 3-2
// Lumen Tale — `3-2`'s pinned action row, and the three things it is not allowed to become.
//
// ## What this file is for
//
// B11 fixes the row at **exactly three** action controls, and the reason is a rule rather
// than a layout preference: no share (B30), no star (keeping IS following — a second
// marker is a second list wearing a different icon), no "mark as finished" (no rule defines
// a finished state; B39's note records that the check lost its finished flag for exactly
// that reason).
//
// ## The rows
//
// | rule | the row |
// |---|---|
// | B11 — exactly three, never four | *the resting row counts three action controls* |
// | B11 — a running queue adds no fourth | *a running download is a BAR, not a button* |
// | B12 — membership first | *not in the library means the row's first slot offers to add* |
// | B12/B10 — *Continue* is labelled and announced differently | *the label is one word, the semantics name the chapter and the percentage* |
// | B13 — zero unopened DISABLES, never removes | *nothing unopened leaves the row exactly as tall and as wide* |
// | B13 — the tap writes what opening writes | *the callback is the only way anything is marked* |

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumen_tale/features/novel_details/widgets/pinned_action_row.dart';
import 'package:lumen_tale/l10n/generated/app_localizations.dart';

/// Every control in the row that a reader can tap — which is what B11 counts.
Finder actionControls() => find.byWidgetPredicate(
  (Widget w) => w is FilledButton || w is OutlinedButton || w is TextButton,
  description: 'an action control',
);

Widget host(Widget child, {Size size = const Size(360, 640)}) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(
    body: SizedBox.fromSize(size: size, child: child),
  ),
);

/// The row in its resting state: nothing queued, something unread, not in the library.
PinnedActionRow resting({
  MembershipSlot membership = const OfferToAdd(),
  DownloadSlot download = const DownloadIdle(),
  int unopenedCount = 12,
  VoidCallback? onAdd,
  VoidCallback? onReadFromStart,
  VoidCallback? onContinue,
  VoidCallback? onDownload,
  VoidCallback? onMarkAllRead,
}) => PinnedActionRow(
  membership: membership,
  download: download,
  unopenedCount: unopenedCount,
  onAdd: onAdd ?? () {},
  onReadFromStart: onReadFromStart ?? () {},
  onContinue: onContinue ?? () {},
  onDownload: onDownload ?? () {},
  onMarkAllRead: onMarkAllRead ?? () {},
);

void main() {
  group('B11 — the row is three controls, and never a fourth', () {
    testWidgets('⚠️ the RESTING row counts exactly three action controls', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(host(resting()));

      expect(
        actionControls(),
        findsNWidgets(3),
        reason:
            'B11 fixes three slots and the count is a RULE: a fourth control is a feature '
            'nobody costed, and B11 names the three that were — share (B30), star, and a '
            '"finished" state no rule defines',
      );
    });

    // ⚠️ **This is the row that keeps the count true WHILE A DOWNLOAD RUNS.** A progress bar
    // rendered as a disabled button would add a fourth tap target that cannot be pressed —
    // and three rows that each pass B11 on their own, and one screen where the reader
    // cannot tell which control is live.
    testWidgets('⚠️ a RUNNING queue adds no fourth control — it is a BAR', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        host(resting(download: const DownloadRunning(done: 212, total: 480))),
      );

      expect(
        actionControls(),
        findsNWidgets(2),
        reason:
            'the bar replaces the download BUTTON, so the row still offers exactly two taps '
            '— and never a greyed one that cannot be pressed',
      );
      expect(
        find.byType(LinearProgressIndicator),
        findsOneWidget,
        reason:
            'and it says how far along it is, in the chapter counts the site gave',
      );
      expect(
        find.text('212 / 480'),
        findsOneWidget,
        reason: 'a bar with no figure is a mood, not a progress',
      );
    });

    testWidgets('⚠️ DONE and STOPPED are chips, and STOPPED says WHY', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(host(resting(download: const DownloadDone())));
      expect(
        actionControls(),
        findsNWidgets(2),
        reason: 'a finished download has nothing left to tap',
      );

      await tester.pumpWidget(
        host(
          resting(
            download: const DownloadStopped(
              reason: 'No space left on the device',
            ),
          ),
        ),
      );
      expect(
        actionControls(),
        findsNWidgets(2),
        reason:
            'and a stopped one offers to start again, not to tap a stopped chip',
      );
      expect(
        find.text('No space left on the device'),
        findsOneWidget,
        reason:
            'the REASON is the label — "stopped" alone leaves the reader choosing between '
            '"the site refused", "no space" and "I cancelled it", which want three '
            'different actions',
      );
    });
  });

  group('B12 — membership is slot 1, and it is the only way in', () {
    testWidgets('⚠️ NOT in the library offers to add, as the FIRST control', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(host(resting()));

      expect(find.text('Add to library'), findsOneWidget);
      // ⚠️ **FIRST, and FILLED** — asserted as a RELATIONSHIP between the label and the
      // control. "It is the first control" and "the label sits on a filled button" are two
      // different claims, and either alone would pass while the other was false.
      expect(
        find.ancestor(
          of: find.text('Add to library'),
          matching: find.byType(FilledButton),
        ),
        findsOneWidget,
        reason:
            'B12 puts it Filled: it is the reason a reader opened this screen from a '
            'catalogue, and a screen that makes them hunt has answered a different question '
            'than the one they asked',
      );
      // ⚠️ **`expect(finderA, finderB)` COMPARES FINDER IDENTITY, not what they find.**
      // The first version asserted `actionControls().first == find.ancestor(...)` and failed
      // on two objects that were never going to be equal. The claim wanted is a RELATIONSHIP
      // — does the FIRST control hold this label — so it is asserted as one.
      expect(
        find.descendant(
          of: actionControls().first,
          matching: find.text('Add to library'),
        ),
        findsOneWidget,
        reason:
            'B12 puts it first and Filled: it is the reason a reader opened this screen '
            'from a catalogue, and a screen that makes them hunt has answered a different '
            'question than the one they asked',
      );
    });

    // ⚠️ **THE DELEGATION ROW.** B12's criterion is not "a button exists" — it is that the
    // tap reaches `2-5.addFromCatalogue` and NOT a direct write, because that is the only
    // way B40's similar-title question can fire BEFORE anything is stored.
    testWidgets('⚠️ the tap is a CALLBACK, and this row does not write anything', (
      WidgetTester tester,
    ) async {
      int adds = 0;
      await tester.pumpWidget(host(resting(onAdd: () => adds++)));

      await tester.tap(find.text('Add to library'));
      await tester.pumpAndSettle();

      expect(
        adds,
        1,
        reason:
            'exactly one add, from one tap — the row emits an intent and `2-5` owns the '
            'question and the write, so there is no second path that could skip B40',
      );
    });

    testWidgets('⚠️ in the library with NO position offers the FIRST chapter', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        host(resting(membership: const OfferReadFromStart())),
      );
      expect(find.text('Read from the start'), findsOneWidget);
      expect(
        find.text('Add to library'),
        findsNothing,
        reason:
            'a novel already in the library must not offer to be added again — the button '
            'that created the row disappears and its slot becomes the way back into the book',
      );
    });

    // ⚠️ **The label and the semantics carry DIFFERENT facts, and the difference is the
    // row.** "Continue" is the right thing to put on a button — the chapter's own title in
    // the visible label would be a second title competing with the novel's. It is also
    // useless to a screen-reader user: not which chapter, not how far in.
    testWidgets(
      '⚠️ *Continue* is one word on screen, and two facts in the semantics',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          host(
            resting(
              membership: const OfferContinue(
                chapterName: 'Chapter 214',
                percent: 41,
              ),
            ),
          ),
        );

        expect(
          find.text('Continue'),
          findsOneWidget,
          reason:
              'the visible label stays the single word the reader is reaching for',
        );
        expect(
          find.bySemanticsLabel(
            'Continue, Chapter 214, 41 through this chapter',
          ),
          findsOneWidget,
          reason:
              'and the announcement names the chapter and the position in it, because those '
              'two facts are what make resuming a DECISION rather than a leap',
        );
      },
    );
  });

  group('B13 — zero unopened disables slot 3, and the row does not move', () {
    testWidgets('⚠️ nothing unopened says so, DISABLED, and keeps its 48dp', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(host(resting(unopenedCount: 0)));

      expect(find.text('Nothing unopened'), findsOneWidget);
      expect(
        actionControls(),
        findsNWidgets(3),
        reason:
            'the control STAYS. A button that vanishes at zero slides Download sideways '
            'under a thumb that was already on its way — the row is three things at every '
            'counter value',
      );

      final Size zero = tester.getSize(actionControls().at(2));
      expect(
        zero.height,
        greaterThanOrEqualTo(kActionRowControlHeight),
        reason:
            'and it keeps ${kActionRowControlHeight}dp while disabled, so reaching zero '
            'does not reflow the row',
      );
    });

    // ⚠️ **A DISABLED CONTROL THAT IS STILL LIVE IS THE BUG.** This row is the difference
    // between "there is nothing left to mark" and "marking all read wrote every mark".
    testWidgets('⚠️ a DISABLED mark-all-read does NOT fire its callback', (
      WidgetTester tester,
    ) async {
      int marks = 0;
      // ⚠️ **`unopenedCount: 0` IS THE POINT OF THIS ROW.** It was dropped as "redundant"
      // because the helper defaults to 12 — which left the button ENABLED, and then the row
      // asserted that a live button does not fire. That is false, and it failed. A lint
      // fixed by deleting the argument that gave the test its meaning is not a fix.
      await tester.pumpWidget(
        host(resting(unopenedCount: 0, onMarkAllRead: () => marks++)),
      );

      await tester.tap(find.text('Nothing unopened'), warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(
        marks,
        0,
        reason:
            'B13 writes the same field opening a chapter writes — and a greyed control that '
            'still fired would mark every chapter read while telling the reader it did '
            'nothing',
      );
    });

    testWidgets('⚠️ something unopened DOES fire, and says what it will mark', (
      WidgetTester tester,
    ) async {
      int marks = 0;
      await tester.pumpWidget(host(resting(onMarkAllRead: () => marks++)));

      expect(find.text('Mark all as read'), findsOneWidget);
      await tester.tap(find.text('Mark all as read'));
      await tester.pumpAndSettle();
      expect(marks, 1, reason: 'the reader asked for it');
    });

    // ⚠️ **The confirmation NAMES ITS COUNT**, because § 3.5 puts it in the TITLE and a
    // title is what a reader reads first. "Are you sure?" does not say what is about to
    // change, and the count is the whole content of the change.
    testWidgets('⚠️ the mark-all confirmation names the COUNT it will mark', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        host(
          Builder(
            builder: (BuildContext context) => Text(
              AppLocalizations.of(context).chapterListMarkAllReadConfirm(12),
            ),
          ),
        ),
      );

      expect(
        find.text('Mark the 12 chapters you have not opened as read?'),
        findsOneWidget,
        reason:
            'the sentence carries the figure — a confirmation whose content is invisible is '
            'a confirmation the reader can only obey, not consent to',
      );
    });
  });
}
