// forge:slice 5-2, 5-3
// Lumen Tale — the Downloads screen and the widgets it renders.
//
// `5-2` § 11.2 and `5-3` § 11.2, driven through a real `ProviderContainer` and a real
// in-memory drift database.
//
// ## ⚠️ **`testWidgets`, AND NOTHING HERE TOUCHES `dart:io`**
//
// This file is widgets only. Every test drives `QueueSection` / `FailedSection` /
// `ChapterProgressLine` with values, so there is no real file anywhere — which is why
// `testWidgets` is safe here and would NOT be safe in `download_queue_control_test.dart`.
//
// | rule | the row |
// |---|---|
// | E7 | `InProcessNotice` is present in EVERY state, including `idle` and empty |
// | B19 | the paused row: icon **and** word **and** *Resume*; no colour-only signal |
// | E7, B24 | the stopped row: reason in words + "will not continue" + *Resume* |
// | B20 | the running row carries **no** per-chapter controls |
// | B19, C12 | the cancel dialog names the in-flight chapter and the kept count |
// | B19, B24 | the failure snackbar's exact sentence |
// | E7 | no automatic resume: `pumpAndSettle` fetches nothing |
// | E17 | two same-titled novels → two sections, two counters |

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumen_tale/app/theme/app_theme.dart';
import 'package:lumen_tale/core/database/app_database.dart';
import 'package:lumen_tale/core/ui/cancel_queue_dialog.dart';
import 'package:lumen_tale/domain/downloads/queue_entry.dart';
import 'package:lumen_tale/domain/downloads/queue_failure_code.dart';
import 'package:lumen_tale/domain/downloads/queue_groups.dart';
import 'package:lumen_tale/domain/downloads/queue_run_state.dart';
import 'package:lumen_tale/domain/downloads/queue_run_state_deriver.dart';
import 'package:lumen_tale/features/downloads/widgets/chapter_progress_line.dart';
import 'package:lumen_tale/features/downloads/widgets/failed_row.dart';
import 'package:lumen_tale/features/downloads/widgets/in_process_notice.dart';
import 'package:lumen_tale/features/downloads/widgets/queue_actions.dart';
import 'package:lumen_tale/features/downloads/widgets/queue_run_state_row.dart';
import 'package:lumen_tale/l10n/generated/app_localizations.dart';

/// One row, built by hand. The widgets under test take values, so no database is involved —
/// which is the point: `downloads.md` § 8's data is local and the *rendering* is the subject.
QueueEntry row(
  String chapterId, {
  DownloadState state = DownloadState.queued,
  String errorCode = '',
  int attempts = 0,
  String novelId = 'n1',
  String novelTitle = 'The Rune Smith',
  String chapterName = '',
  int position = 1,
}) => QueueEntry(
  id: 'q-$chapterId',
  chapterId: chapterId,
  novelId: novelId,
  novelTitle: novelTitle,
  chapterName: chapterName.isEmpty ? 'Chapter $chapterId' : chapterName,
  sourceId: 'rr',
  chapterUrl: '/fiction/1/$novelId/$chapterId',
  ordinal: 1,
  chapterNumber: 1,
  state: state,
  queuePosition: position,
  addedAt: DateTime.utc(2026),
  attempts: attempts,
  errorCode: errorCode,
);

/// Wraps [child] in the app's theme, its localisations and a `MediaQuery`, which is the
/// minimum `LumenColors.of(context)` and `AppLocalizations.of(context)` will resolve.
Widget harness(Widget child, {Locale locale = const Locale('en')}) {
  return MaterialApp(
    locale: locale,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    theme: AppTheme.day(),
    home: Scaffold(body: SingleChildScrollView(child: child)),
  );
}

QueueRun runOf(
  List<QueueEntry> entries, {
  bool isRunning = false,
  QueueStopReason? sessionStopReason,
}) => deriveQueueRunState(
  entries: entries,
  isRunning: isRunning,
  sessionStopReason: sessionStopReason,
);

void main() {
  group('E7 — the standing notice is in EVERY state', () {
    testWidgets('⚠️ it is rendered on its own, with no queue at all', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(harness(const InProcessNotice()));

      expect(
        find.text('Downloads continue only while the app is open.'),
        findsOneWidget,
        reason:
            'E7 + `downloads.md` § 2.1: "it is the first line under the title, it is always '
            'there". `flows.md` § 4.4 calls this the single most likely over-promise in the '
            'product, and a notice that appears only when a queue is running is a notice that '
            'appears **after** the reader has already been misled',
      );
    });

    testWidgets('⚠️ it survives a **larger** text scale without overflowing', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(360 * 3, 2000 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: harness(const InProcessNotice()),
        ),
      );

      expect(
        tester.takeException(),
        isNull,
        reason:
            'C11/ADR-019: at 360dp in the largest OS text scale the sentence wraps onto more '
            'lines. It must WRAP — a row that cannot grow is a row that clips, and a clipped '
            'notice is a notice that is not there',
      );
    });

    testWidgets('⚠️ it exists in French too (B28)', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        harness(const InProcessNotice(), locale: const Locale('fr')),
      );

      expect(
        find.text(
          // ⚠️ **AN ASCII APOSTROPHE, NOT A TYPOGRAPHIC ONE.** The French ARB string uses
          // U+0027, and a test that typed U+2019 reports "0 widgets" for a message that is
          // perfectly translated — a false failure that trains a reader to ignore this row.
          "Les téléchargements ne continuent que tant que l'application est ouverte.",
        ),
        findsOneWidget,
        reason:
            'B28: every user-visible string exists in both languages. `16-i18n.md` rule 2 makes '
            'an entry present in one file and missing from the other "a defect, not a fallback"',
      );
    });
  });

  group('B19 — the paused row carries an ICON, a WORD and a *Resume*', () {
    testWidgets('⚠️ nothing on the row depends on colour alone', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        harness(
          QueueRunStateRow(
            run: runOf(<QueueEntry>[
              for (int i = 0; i < 12; i++)
                row('c$i', state: DownloadState.done),
              row('c12'),
            ]),
            onResume: () {},
          ),
        ),
      );

      expect(
        find.text('Paused'),
        findsOneWidget,
        reason:
            '§ 4.3: "a `primary` **Resume**" and `--color-warning` + icon + the word *Paused*. '
            '`14-design-tokens.md` § Accessibility: "No color-only state indicators … pair '
            'color with an icon or label". The WORD is the third channel, after the icon',
      );
      expect(
        find.byIcon(Icons.pause_circle_outline),
        findsOneWidget,
        reason:
            'and the icon is there so a greyscale print still distinguishes it',
      );
      expect(
        find.text('Resume'),
        findsOneWidget,
        reason:
            'B19/§ 3.3: *Resume* is what distinguishes `paused` from `stopped` — it resumes '
            '**without an explanation**. A control that is absent is not a promise the app '
            'cannot keep',
      );
      expect(
        find.text('Stopped'),
        findsNothing,
        reason:
            '⚠️ **AND NOT "STOPPED".** C12: a stopped queue needs a reason it can say out '
            'loud, and a reader who paused their own queue has none. Showing a *fault* for a '
            'deliberate act is the defect',
      );
    });

    testWidgets(
      '⚠️ *Resume* IS A FILLED BUTTON — the one accented control on the screen',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          harness(
            QueueRunStateRow(
              run: runOf(<QueueEntry>[row('c0')]),
              onResume: () {},
            ),
          ),
        );

        final FilledButton button = tester.widget<FilledButton>(
          find.ancestor(
            of: find.text('Resume'),
            matching: find.byType(FilledButton),
          ),
        );
        expect(
          button,
          isNotNull,
          reason:
              '`downloads.md` § 2: "--color-accent … **only** … on the `primary` **Resume** '
              'button. Not on section labels, not on completed rows, not on the counts." A '
              'paused queue’s one useful act is the accented button',
        );
      },
    );

    testWidgets('⚠️ tapping *Resume* REACHES THE CALLBACK (no dead control)', (
      WidgetTester tester,
    ) async {
      int resumes = 0;
      await tester.pumpWidget(
        harness(
          QueueRunStateRow(
            run: runOf(<QueueEntry>[row('c0')]),
            onResume: () => resumes += 1,
          ),
        ),
      );

      await tester.tap(find.text('Resume'));
      await tester.pump();

      expect(
        resumes,
        1,
        reason:
            '⚠️ **`TextButton(onPressed: () {})` LABELLED *RETRY* HAS SHIPPED THREE TIMES IN '
            'THIS PROJECT** (`AGENTS.md` § Hard rules 9). The assertion is on the **gesture**, '
            'not on the button being present: a control that renders and does nothing is '
            'indistinguishable from one that works until a reader presses it',
      );
    });
  });

  group(
    'E7 / B24 — the stopped row says WHY, and that it will not restart by itself',
    () {
      testWidgets('⚠️ `no_connection`: reason, the trap-closing sentence, and *Resume*', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(
          harness(
            QueueRunStateRow(
              run: runOf(<QueueEntry>[
                for (int i = 0; i < 12; i++)
                  row('c$i', state: DownloadState.done),
                row(
                  'c12',
                  state: DownloadState.failed,
                  errorCode: 'no_connection',
                ),
              ]),
              onResume: () {},
            ),
          ),
        );

        expect(
          find.text('Stopped'),
          findsOneWidget,
          reason: '§ 4.3: `--color-error` + icon + word',
        );
        expect(
          find.byIcon(Icons.error_outline),
          findsOneWidget,
          reason:
              'and an icon beside the words, for the same reason `Paused` has one',
        );
        expect(
          find.text('No connection'),
          findsOneWidget,
          reason:
              'C12: "the downloads stopped, the network went" is a sentence a borrowed-device '
              'reader can say out loud. A stopped row with no reason is the state B22 exists to '
              'prevent',
        );
        expect(
          find.text(
            'It will not continue on its own when the signal comes back.',
          ),
          findsOneWidget,
          reason:
              '⚠️ **E7, THE SENTENCE THAT CLOSES THE TRAP.** `downloads.md` § 4 puts it directly '
              'beneath the reason, "where the reader is most likely to wonder". Without it a '
              'reader whose queue stopped will assume the app picks it up when the bar improves — '
              'and be wrong for ever',
        );
        expect(
          find.text('Resume'),
          findsOneWidget,
          reason:
              'B24: every failure has "a way to try again", and here the action is a button',
        );
      });

      testWidgets(
        '⚠️ a BROKEN SITE names the site, never a `sourceId` hash (B22, C12)',
        (WidgetTester tester) async {
          await tester.pumpWidget(
            harness(
              QueueRunStateRow(
                run: runOf(<QueueEntry>[
                  row(
                    'c0',
                    state: DownloadState.failed,
                    errorCode: 'source_layout_changed',
                  ),
                  row('c1'),
                ]),
                sourceName: 'Royal Road',
                onResume: () {},
              ),
            ),
          );

          expect(
            find.text('Lumen Tale could not read Royal Road.'),
            findsOneWidget,
            reason:
                'B22: forty-eight chapters failing for this reason is ONE broken site, and § 3.2 '
                'gives the screen "**une seule ligne**: *Lumen Tale could not read Royal Road*". '
                'The `sourceId` is a 32-character MD5 and a hash cannot be reported to anyone',
          );
        },
      );

      testWidgets('⚠️ a full disk does NOT claim the signal is coming back (E20)', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(
          harness(
            QueueRunStateRow(
              run: runOf(<QueueEntry>[
                row('c0', state: DownloadState.downloading),
              ], sessionStopReason: QueueStopReason.outOfStorage),
              storageBytesNeeded: 4096,
              onResume: () {},
            ),
          ),
        );

        expect(
          find.text(
            'The phone is out of storage. Free up some space, then resume.',
          ),
          findsOneWidget,
          reason:
              'E20: the queue stops, says why, and the resume action says "free up some space, '
              'then resume". § 7 warns specifically against a *Retry* here — the next request '
              'would fail identically',
        );
        expect(
          find.text(
            'It will not continue on its own when the signal comes back.',
          ),
          findsNothing,
          reason:
              '⚠️ **THE SENTENCE IS **FALSE** FOR A FULL DISK, AND IT IS NOT PRINTED.** "when the '
              'signal comes back" claims the signal is what is wrong. It is not — the disk is, '
              'and the reader has a concrete action to take. A notice that is wrong in the one '
              'state where acting is possible is worse than no notice',
        );
        expect(
          find.text('This chapter needs 4 KB.'),
          findsOneWidget,
          reason:
              '`architecture.md` § 5.2: `StorageFull` carries "bytes needed", and the figure is '
              'beside the chapter. It is NOT free space — `downloads.md` § 9 refuses to display '
              'free space at all',
        );
      });

      testWidgets(
        '⚠️ NO free-space figure appears anywhere on the storage notice (E20, § 9)',
        (WidgetTester tester) async {
          await tester.pumpWidget(
            harness(
              QueueRunStateRow(
                run: runOf(<QueueEntry>[
                  row('c0', state: DownloadState.downloading),
                ], sessionStopReason: QueueStopReason.outOfStorage),
                onResume: () {},
              ),
            ),
          );

          expect(
            find.textContaining('free'),
            findsNothing,
            reason:
                '⚠️ **`downloads.md` § 9, VERBATIM: "Free space is not displayed — the app has no '
                'honest way to read it without a platform channel it has not earned."** A number '
                'that goes stale in the seconds between rendering it and the reader looking up is '
                'worse than no number (C12: a failure state must be TRUE)',
          );
        },
      );

      testWidgets('⚠️ `rate_limited` NAMES THE SITE’S OWN TIME when it has one', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(
          harness(
            QueueRunStateRow(
              run: runOf(<QueueEntry>[
                row(
                  'c0',
                  state: DownloadState.failed,
                  errorCode: 'rate_limited',
                ),
              ]),
              notBefore: DateTime(2026, 10, 4, 14, 5),
              onResume: () {},
            ),
          ),
        );

        expect(
          find.textContaining('2:05'),
          findsOneWidget,
          reason:
              '`17-security.md` rule 6 and `downloads.md` § 8: the stopped row names the time '
              'from `Retry-After`. § 3.2 writes "*Stopped — the site asked us to wait. Try again '
              'after 14:05.*" and a clock time is what a reader can plan around',
        );
      });
    },
  );

  group('B20 / C8 — the running row carries NO per-chapter controls', () {
    testWidgets('⚠️ *Pause* is **ABSENT**, not disabled, while the queue runs', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        harness(QueueActions(canPause: true, onPause: () {}, onCancel: () {})),
      );
      expect(
        find.text('Pause'),
        findsOneWidget,
        reason: 'witness — it renders when running',
      );

      await tester.pumpWidget(
        harness(QueueActions(canPause: false, onPause: () {}, onCancel: () {})),
      );
      expect(
        find.text('Pause'),
        findsNothing,
        reason:
            '§ 4.3 / § 11: a control is **absent**, not disabled. `downloads.md` § 11: "a '
            'disabled control is a promise about a version that does not exist", and § 6 '
            'allows exactly one class of disabled control — a `Pause` on a queue that is not '
            'running — which is what this is',
      );
    });

    testWidgets(
      '⚠️ *Cancel* renders while PAUSED, which is when the reader decides',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          harness(
            QueueActions(canPause: false, onPause: () {}, onCancel: () {}),
          ),
        );

        expect(
          find.text('Cancel download'),
          findsOneWidget,
          reason:
              'B19: the reader may abandon the queue from any state it can be in, and a control '
              'that appeared only while running would take that away exactly when they are '
              'deciding whether to',
        );
      },
    );

    testWidgets('⚠️ tapping *Pause* and *Cancel* REACH their callbacks', (
      WidgetTester tester,
    ) async {
      int pauses = 0;
      int cancels = 0;
      await tester.pumpWidget(
        harness(
          QueueActions(
            canPause: true,
            onPause: () => pauses += 1,
            onCancel: () => cancels += 1,
          ),
        ),
      );

      await tester.tap(find.text('Pause'));
      await tester.tap(find.text('Cancel download'));
      await tester.pump();

      expect(
        pauses,
        1,
        reason: 'the gesture, not the rendering — see hard rule 9',
      );
      expect(cancels, 1, reason: 'and the destructive one is no exception');
    });

    testWidgets('⚠️ every control on this screen is at least 48dp tall (C11)', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        harness(QueueActions(canPause: true, onPause: () {}, onCancel: () {})),
      );

      for (final String label in <String>['Pause', 'Cancel download']) {
        final Size size = tester.getSize(
          find.ancestor(
            of: find.text(label),
            matching: find.byType(TextButton),
          ),
        );
        expect(
          size.height,
          greaterThanOrEqualTo(48),
          reason:
              'C11: "Reading happens one-handed, on a phone, at night or in transit" and '
              '`14-design-tokens.md` § Accessibility: "Touch targets: ≥ 48 × 48 logical px". '
              '$label is ${size.height}dp tall',
        );
      }
    });
  });

  group('B19 / C12 — the cancel dialogue names the chapter and the survivors', () {
    testWidgets('⚠️ with a chapter in flight, BOTH the name and the kept count appear', (
      WidgetTester tester,
    ) async {
      bool confirmed = false;
      await tester.pumpWidget(
        harness(
          Builder(
            builder: (BuildContext context) => TextButton(
              onPressed: () async {
                confirmed = await confirmCancelQueue(
                  context: context,
                  data: const CancelQueueDialogData(
                    keptCount: 12,
                    activeChapterTitle: 'Chapter 13 — The Wound',
                  ),
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Chapter 13 — The Wound'),
        findsOneWidget,
        reason:
            '⚠️ **`downloads.md` § 7: "Destructive actions are confirmed and **named**: the '
            'dialog names the chapter, so the confirmation is a statement about a specific '
            'thing rather than a generic *Are you sure?*"** The chapter title is the SITE’s '
            'own (B10) because it is the reader’s own words',
      );
      expect(
        find.textContaining('12 chapters already downloaded are kept'),
        findsOneWidget,
        reason:
            'B19: cancelling "keeps every chapter already completed", and the reader needs to '
            'know **how many** — that is what turns the promise into something they can check '
            'afterwards. § 3.4 also wants the number, and it is passed as a count rather than a '
            'pre-built phrase so no caller can decorate it',
      );

      await tester.tap(find.text('Cancel the download'));
      await tester.pumpAndSettle();
      expect(confirmed, isTrue, reason: 'and the confirm actually confirms');
    });

    testWidgets(
      '⚠️ with nothing in flight the dialogue does NOT invent a chapter',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          harness(
            Builder(
              builder: (BuildContext context) => TextButton(
                onPressed: () => confirmCancelQueue(
                  context: context,
                  data: const CancelQueueDialogData(
                    keptCount: 12,
                    activeChapterTitle: null,
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        );

        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();

        expect(
          find.textContaining('12 chapters already downloaded are kept'),
          findsOneWidget,
          reason: 'the kept count is always present',
        );
        expect(
          find.textContaining('Chapter 13'),
          findsNothing,
          reason:
              '⚠️ **NO PLACEHOLDER CHAPTER NAME.** `downloads.md` § 5 names the chapter when '
              'there IS one; naming "Chapter —" when there is not would be a dialogue about a '
              'chapter that does not exist',
        );
      },
    );

    testWidgets('⚠️ the dialogue cannot be dismissed into consent (B19)', (
      WidgetTester tester,
    ) async {
      bool? answer;
      await tester.pumpWidget(
        harness(
          Builder(
            builder: (BuildContext context) => TextButton(
              onPressed: () async {
                answer = await confirmCancelQueue(
                  context: context,
                  data: const CancelQueueDialogData(
                    keptCount: 3,
                    activeChapterTitle: null,
                  ),
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(
        find.byType(AlertDialog),
        findsOneWidget,
        reason: 'witness — it is open',
      );

      await tester.tapAt(const Offset(8, 8)); // the barrier
      await tester.pumpAndSettle();
      expect(
        find.byType(AlertDialog),
        findsOneWidget,
        reason:
            '⚠️ **THE DIALOGUE IS **STILL OPEN**, AND THAT IS THE RULE.** '
            '`barrierDismissible: false` means a stray tap outside cannot dismiss it, so a '
            'cancellation can never fire on its own. The assertion is `findsOneWidget` and not '
            '`findsNothing` deliberately: "a tap that was not consent dismissed it" and "it '
            'was never closable" are the same failure from the reader side',
      );
      expect(
        find.text('Cancel'),
        findsOneWidget,
        reason:
            'and a real *Cancel* button is there, so `barrierDismissible: false` costs the '
            'reader nothing — two exits, one of them primary, no dead end',
      );

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(
        answer,
        isFalse,
        reason:
            'and the real cancel answers `false`, which is what the caller checks. A dismissed '
            'dialogue answers `null`, and the method maps that to `false`, so a future escape '
            'route cannot become consent',
      );
    });
  });

  group('5-3 — the failed rows: one per chapter, ONE for a broken site', () {
    testWidgets('⚠️ a failed row has an ICON, the CHAPTER, the reason and *Retry*', (
      WidgetTester tester,
    ) async {
      int retries = 0;
      await tester.pumpWidget(
        harness(
          FailedSection(
            entries: <QueueEntry>[
              row(
                'c7',
                state: DownloadState.failed,
                errorCode: QueueFailureCode.noRealText.stored,
                attempts: 2,
                chapterName: 'Chapter 7 — An Afterword',
              ),
            ],
            onRetry: (_) => retries += 1,
            onOpenNovel: (_) {},
          ),
        ),
      );

      expect(
        find.byIcon(Icons.error_outline),
        findsOneWidget,
        reason:
            '`14-design-tokens.md`: an icon **and** the words, never red text alone',
      );
      expect(
        find.text('Chapter: Chapter 7 — An Afterword'),
        findsOneWidget,
        reason:
            '⚠️ **`downloads.md` § 4: "Every failed row names the **chapter**, not just the '
            'novel."** A reader with three queued novels has to know which chapter of which '
            '— and the title is the SITE’s own (B10)',
      );
      expect(
        find.textContaining('had no readable text'),
        findsOneWidget,
        reason:
            'E18 + C12: a sentence the reader can describe out loud. It is about **this '
            'chapter**, because E22 forbids treating a short chapter as a broken one',
      );
      expect(
        find.text('Tried 2 times'),
        findsOneWidget,
        reason:
            '⚠️ **`downloads.md` § 9: "The attempt count is shown, because a threshold being '
            'applied is a thing the reader deserves to know about."** It is shown even at 2, '
            'and even at 1 — printing it only from two would make the second failure the '
            'first thing the reader ever saw of it',
      );
      expect(
        find.text('Retry this chapter'),
        findsOneWidget,
        reason:
            'B24: "together with a way to try again", and § 5: "Re-fetch that chapter alone, '
            'and only that one"',
      );

      await tester.tap(find.text('Retry this chapter'));
      await tester.pump();
      expect(
        retries,
        1,
        reason:
            '⚠️ **THE GESTURE, NOT THE BUTTON.** `AGENTS.md` hard rule 9: a control wired to '
            'nothing has shipped three times in this project. A *Retry* that renders and does '
            'nothing is indistinguishable from one that works until a reader presses it',
      );
    });

    testWidgets('⚠️ a BROKEN SITE is **ONE** row however many chapters failed (B22)', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        harness(
          FailedSection(
            entries: <QueueEntry>[
              for (int i = 0; i < 48; i++)
                row(
                  'c$i',
                  state: DownloadState.failed,
                  errorCode: QueueFailureCode.sourceLayoutChanged.stored,
                ),
            ],
            onRetry: (_) {},
            onOpenNovel: (_) {},
            sourceNameOf: (_) => 'Royal Road',
          ),
        ),
      );

      expect(
        find.text('Lumen Tale could not read Royal Road.'),
        findsOneWidget,
        reason:
            '⚠️ **THE ROW THAT IS WORTH A HUNDRED.** B22: "every download from one source '
            'failing is reported as one source failure, not as forty-eight failed chapters". '
            'Forty-eight identical rows say the same thing forty-eight times and the reader can '
            'act on none of them',
      );
      expect(
        find.byIcon(Icons.cloud_off_outlined),
        findsOneWidget,
        reason:
            '⚠️ **`--color-info`, NOT `--color-error`.** `downloads.md` § 12 assigns '
            '`--color-info` to "the single-source-failure row’s icon — a notice about the site, '
            'not an error in the queue"',
      );
      expect(
        find.byIcon(Icons.error_outline),
        findsNothing,
        reason:
            'and there is no per-chapter error icon, because there is no per-chapter row',
      );
    });

    testWidgets('⚠️ an EMPTY section renders **nothing at all**', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        harness(
          FailedSection(
            entries: <QueueEntry>[
              row('c0', state: DownloadState.done),
              row('c1'),
            ],
            onRetry: (_) {},
            onOpenNovel: (_) {},
          ),
        ),
      );

      expect(
        find.text('COULD NOT DOWNLOAD'),
        findsNothing,
        reason:
            '⚠️ **`downloads.md` § 3: "FailedSection — only when non-empty".** A section '
            'label over zero rows is a heading that lies about its own contents, and B22 '
            'wants an empty state to be a *sentence* rather than a decoration',
      );
    });

    testWidgets(
      '⚠️ `downloading` and `done` rows carry NO *Retry* at all (B33, Read-only)',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          harness(
            FailedRow(
              entry: row('c0', state: DownloadState.done),
              onRetry: () {},
              onOpenNovel: () {},
            ),
          ),
        );

        expect(
          find.text('Retry this chapter'),
          findsNothing,
          reason:
              '⚠️ **`downloads.md` § 4 *Read-only* and § 5: a control is **absent**, not '
              'disabled.** A `done` row is a **stored** chapter; deleting it and downloading it '
              'again is B33’s explicit, confirmed choice, and a Retry here would re-fetch a '
              'whole file with no confirmation at all',
        );
      },
    );

    testWidgets('⚠️ EVERY typed code produces a sentence AND an action (B24)', (
      WidgetTester tester,
    ) async {
      for (final QueueFailureCode code in QueueFailureCode.values) {
        await tester.pumpWidget(
          harness(
            FailedRow(
              entry: row(
                'c0',
                state: DownloadState.failed,
                errorCode: code.stored,
              ),
              onRetry: () {},
              onOpenNovel: () {},
            ),
          ),
        );

        expect(
          find.byType(TextButton),
          findsOneWidget,
          reason:
              '⚠️ **B24: "Any action that can fail shows an error the user can read and act on, '
              'together with a way to try again."** `${code.stored}` produced NO control, so '
              'this code has a state the reader cannot get out of',
        );
        expect(
          find.byType(Text),
          findsWidgets,
          reason:
              'and a sentence — `queue_failure_copy.dart`’s `switch` has no `default`, '
              'so a code with no words cannot compile',
        );
      }
    });
  });

  group('E17 — two same-titled novels are TWO sections with TWO counters', () {
    testWidgets(
      '⚠️ `groupQueueByNovel` splits by `novelId`, and each group keeps its counts',
      (WidgetTester tester) async {
        final List<NovelQueueGroup> groups = groupQueueByNovel(<QueueEntry>[
          for (int i = 0; i < 3; i++)
            row(
              'a$i',
              novelId: 'n-rr',
              novelTitle: 'Mother of Learning',
              position: i,
            ),
          for (int i = 0; i < 3; i++)
            row(
              'b$i',
              novelId: 'n-fm',
              novelTitle: 'Mother of Learning',
              position: 10 + i,
            ),
        ]);

        expect(
          groups,
          hasLength(2),
          reason:
              '⚠️ **E17: "The library or a catalogue holds two identically titled novels. They '
              'remain two distinct novels … and they are **never merged** (B2)."** Both rows '
              'carry the title `Mother of Learning`, so any grouping by title would return ONE '
              'group of six',
        );
        expect(
          groups.map((NovelQueueGroup g) => g.novelId),
          <String>['n-rr', 'n-fm'],
          reason:
              'and the key is the **novel id**, which derives from the `sourceId` (B2)',
        );
        expect(
          groups.map((NovelQueueGroup g) => g.counts.total),
          <int>[3, 3],
          reason:
              '§ 3.6: "a ‘12 sur 50’ counter **per queue** — never a total aggregated over two '
              'same-named novels". Six chapters, two counters of three each',
        );
      },
    );

    testWidgets('⚠️ the library and `lib/features/downloads/` never group by TITLE', (
      WidgetTester tester,
    ) async {
      // ⚠️ **A GREP, RUN AS A TEST, AND IT IS THE **NEGATIVE** HALF OF E17.**
      //
      // The grouping test above proves the function splits by id. This proves there is no
      // *other* place that aggregates by title — because a second implementation is exactly
      // how a rule gets satisfied in one file and broken in another.
      final List<String> offenders = <String>[];
      for (final File file
          in Directory('lib/features/downloads')
              .listSync(recursive: true)
              .whereType<File>()
              .where((File f) => f.path.endsWith('.dart'))) {
        for (final String line in file.readAsStringSync().split('\n')) {
          final String trimmed = line.trimLeft();
          if (trimmed.startsWith('//') || trimmed.startsWith('*')) {
            continue;
          }
          if (trimmed.contains('chapters.title') ||
              trimmed.contains('groupBy')) {
            offenders.add('${file.path}: $trimmed');
          }
        }
      }

      expect(
        offenders,
        isEmpty,
        reason:
            '⚠️ **`5-3` § 10: `grep -rn \'chapters.title\' lib/features/downloads/` returns '
            'nothing.** A `GROUP BY title` anywhere in the queue would merge two novels that '
            'happen to share a name and report one figure for both — and E17/B2 make those '
            'two novels distinct. Found: $offenders',
      );
    });
  });

  group('C8 — `totalBytes == null` renders no percentage and no zero', () {
    testWidgets('⚠️ an unknown total renders **nothing** (downloads.md § 8)', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        harness(const ChapterProgressLine(progress: null)),
      );

      expect(
        find.byType(LinearProgressIndicator),
        findsNothing,
        reason:
            '⚠️ **C8: an absent `Content-Length` means the figure is **omitted** rather than '
            'showing `0`, "which is a claim".** A bar at zero that never moves is a bar that '
            'lies, and `3-3`’s `ChapterProgressLine` header says the same thing about '
            'determinate bars in general',
      );
    });

    testWidgets('⚠️ a KNOWN total renders the bar AND the spoken percentage', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        harness(
          const ChapterProgressLine(
            progress: 0.41,
            spokenValue: 'Chapter 13 of 50, 41 per cent',
          ),
        ),
      );

      expect(
        find.byType(LinearProgressIndicator),
        findsOneWidget,
        reason: 'the determinate line is 2dp and never animates on its own',
      );
      expect(
        find.bySemanticsLabel('Chapter 13 of 50, 41 per cent'),
        findsOneWidget,
        reason:
            '⚠️ **`downloads.md` § 7: "The progress line has a spoken equivalent … *Chapter 13 '
            'of 50, 41 per cent*".** A percentage inside a ring is unreadable by a screen '
            'reader and useless at 2dp — the spoken value is the accessible form, and the '
            'position and total are facts the bar does not carry',
      );
      expect(
        find.text('41%'),
        findsNothing,
        reason:
            'and the percentage is **not drawn inside the bar** — 6dp text over a title is '
            'unreadable on a low-contrast background and untranslatable in any layout without '
            'that exact free space',
      );
    });
  });
}
