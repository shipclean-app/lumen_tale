// forge:slice 3-3
// Lumen Tale — § 4.3.2 and § 4.3.3: the outcome → rendering table, and the two widgets.
//
// ## Why this file exists
//
// § 4.3.2 gives six enqueue arms **one exact rendering each**, and § 4.3.3 four delete arms,
// and every row also names what that rendering must NOT do. Written inside a tile's `build`,
// none of it is testable without a provider scope and a fake repository — and the mapping is
// the part that drifts. So it is a **pure function** and this file is a table test over it.
//
// ## The rows
//
// | rule | the row |
// |---|---|
// | B6 — an already-stored chapter changes NOTHING | *`mutatesTile` is false and the copy offers Open* |
// | E20 — the refusal is a DIALOGUE with both numbers | *never a snackbar* |
// | § 4.3.3 — a no-op delete does NOT say "deleted" | *and never says "0 KB freed"* |
// | § 4.3.3 — a failed delete leaves the tile DOWNLOADED | *`mutatesTile` is false* |
// | B22 — a write failure retries THIS chapter only | *and only it* |
// | C12 — a failure with nothing to offer shows NO button | *`sourceLayoutChanged` has none* |

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumen_tale/core/error/source_failure.dart';
import 'package:lumen_tale/domain/downloads/download_request.dart';
import 'package:lumen_tale/features/downloads/chapter_action_feedback.dart';
import 'package:lumen_tale/features/downloads/widgets/chapter_progress_line.dart';
import 'package:lumen_tale/features/downloads/widgets/failed_chapter_retry.dart';
import 'package:lumen_tale/l10n/generated/app_localizations.dart';

const int k41 = 41 * 1024;

String plainFormat(int bytes) => '$bytes B';

void main() {
  group('§ 4.3.2 — the six enqueue renderings', () {
    test('⚠️ an ACCEPTED enqueue is a snackbar and the tile MOVES', () {
      final ({ChapterActionFeedback feedback, bool retryThisChapterOnly})
      result = enqueueFeedback(
        const EnqueueQueued(queued: 3),
        formatBytes: plainFormat,
      );

      expect(
        result.feedback.kind,
        ActionFeedback.messageOnly,
        reason:
            'an accepted enqueue is one sentence, and the tile turns into its new state',
      );
      expect(
        result.retryThisChapterOnly,
        isFalse,
        reason: 'nothing failed, so nothing is being retried',
      );
    });

    // ⚠️ **THE ROW FOR § 4.3.2's "LA TUILE NE CHANGE PAS".** Four of the six say it. A
    // convention would not be checkable; a property on the value is.
    test('⚠️ ALREADY STORED offers Open and the tile DOES NOT CHANGE', () {
      final ({ChapterActionFeedback feedback, bool retryThisChapterOnly})
      result = enqueueFeedback(
        const EnqueueAlreadyStored(),
        formatBytes: plainFormat,
      );

      expect(
        result.feedback.kind,
        ActionFeedback.messageAndOpen,
        reason:
            'the copy is already here, so the useful action is to read it — not to fetch it '
            'again over an intact file',
      );
      expect(
        result.feedback.message,
        'downloadAlreadyStoredSnackbar',
        reason:
            'and the sentence names the fact rather than claiming a new download',
      );
    });

    // ⚠️ **E20'S REFUSAL IS NOT A SNACKBAR.** A snackbar is dismissable into a shrug; the
    // reader would see "not enough space" flash and then a tile that silently did nothing.
    test('⚠️ a SPACE REFUSAL is a DIALOGUE carrying both numbers', () {
      final ({ChapterActionFeedback feedback, bool retryThisChapterOnly})
      result = enqueueFeedback(
        const EnqueueRefusedForSpace(requiredBytes: k41, freeBytes: 1024),
        formatBytes: plainFormat,
      );

      expect(
        result.feedback.kind,
        ActionFeedback.spaceRefused,
        reason:
            '§ 4.3.2: the refusal is the E20 dialogue, never a snackbar — a snackbar is '
            'dismissable into a shrug and the tile would then silently not have changed',
      );
      expect(
        result.feedback.dialog?.requiredBytes,
        k41,
        reason: 'and the dialogue names what the download NEEDS',
      );
      expect(
        result.feedback.dialog?.freeBytes,
        1024,
        reason:
            'as well as what the phone HAS — one number alone is not actionable',
      );
    });

    test('⚠️ a WRITE FAILURE says NOTHING WAS CHANGED and retries ONE chapter', () {
      final ({ChapterActionFeedback feedback, bool retryThisChapterOnly})
      result = enqueueFeedback(
        const EnqueueFailed(NoConnection(host: 'example.invalid')),
        formatBytes: plainFormat,
      );

      expect(
        result.feedback.message,
        'downloadWriteFailedSnackbar',
        reason:
            '§ 4.3.2: "The download could not be added. Nothing was changed." A tile '
            'showing `downloading` while nothing is queued is the lie this avoids',
      );
      expect(
        result.retryThisChapterOnly,
        isTrue,
        reason:
            'B22: a `failed` chapter is retried ALONE. A failed state is a typed '
            'error_code, so the siblings are not broken',
      );
      expect(
        result.feedback.failure,
        isA<NoConnection>(),
        reason:
            'B24: the typed cause is CARRIED even though § 4.3.2 gives it one sentence — '
            '"report this bug" needs it, and dropping it here would lose the only typed '
            'value the screen has',
      );
    });
  });

  group('§ 4.3.3 — the four delete renderings', () {
    test('⚠️ a REMOVED copy reports the MEASURED bytes and the tile moves', () {
      final DeleteFeedback feedback = deleteFeedback(
        const DeleteOneRemoved(freedBytes: k41),
      );

      expect(
        feedback.freedBytes,
        k41,
        reason:
            'measured BEFORE the unlink. Afterwards it is zero, and a confirmation '
            'reporting zero freed teaches a reader that deletions do nothing',
      );
      expect(
        feedback.mutatesTile,
        isTrue,
        reason: 'the file is gone, so the tile must stop saying downloaded',
      );
    });

    // ⚠️ **THE ROW FOR "NI 'SUPPRIMÉ', NI '0 KO LIBÉRÉS'".** Both are forbidden by § 4.3.3,
    // and the second is the one that is tempting to reuse from the success row.
    test(
      '⚠️ NOTHING TO REMOVE does NOT say "deleted" and does NOT say "0 freed"',
      () {
        final DeleteFeedback feedback = deleteFeedback(
          const DeleteOneNothingToRemove(),
        );

        expect(
          feedback.messageKey,
          'downloadNotStoredSnackbar',
          reason:
              '§ 4.3.3: a confirmation for a no-op teaches a reader that confirmations are '
              'decorative. The honest sentence names the absence',
        );
        expect(
          feedback.mutatesTile,
          isFalse,
          reason: 'and the tile does not change, because nothing happened',
        );
        expect(
          feedback.messageKey,
          isNot('downloadDeletedSnackbar'),
          reason: 'specifically: it is NOT the success sentence',
        );
      },
    );

    // ⚠️ **THE REVERSE LIE.** The unlink failed, so the file is still on disk. A tile that
    // reads "not downloaded" over a surviving file is the mirror image of B6's.
    test('⚠️ a FAILED delete leaves the tile DOWNLOADED', () {
      final DeleteFeedback feedback = deleteFeedback(
        const DeleteOneFailed(NoConnection(host: 'local storage')),
      );

      expect(
        feedback.mutatesTile,
        isFalse,
        reason:
            'the file survived, so the copy is still there. Showing "not downloaded" would '
            'be the REVERSE lie of the one B6 prevents',
      );
      expect(
        feedback.messageKey,
        'deleteStoredFailedSnackbar',
        reason: 'and the sentence says the operation changed nothing',
      );
    });
  });

  group('ChapterProgressLine', () {
    // ⚠️ **A DETERMINATE BAR IS A PROMISE THAT IT MOVES.** `null` means the amount is
    // unknown, and unknown is not a small amount — so the bar is hidden, not animated.
    testWidgets('⚠️ an UNKNOWN progress renders NOTHING, not an empty bar', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: ChapterProgressLine(progress: null)),
        ),
      );

      expect(
        find.byType(LinearProgressIndicator),
        findsNothing,
        reason:
            'a determinate bar with no value still occupies space and still animates; a '
            'reader watching it is being told a specific falsehood',
      );
    });

    testWidgets('⚠️ a progress of `0.0` renders an EMPTY bar, not nothing', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: ChapterProgressLine(progress: 0)),
        ),
      );

      expect(
        find.byType(LinearProgressIndicator),
        findsOneWidget,
        reason:
            'zero is a MEASURED amount and the row is on screen. Hiding it would make a '
            'freshly started download look absent',
      );
    });

    // ⚠️ **A ROUNDING ARTEFACT MUST NOT TAKE THE TILE DOWN.** `LinearProgressIndicator`
    // throws on a value outside `[0, 1]`, so a ratio of two counters computed during a
    // rebuild could crash the tile over 1.0000001.
    testWidgets('⚠️ a value ABOVE 1 is CLAMPED, never asserted', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: ChapterProgressLine(progress: 1.0000001)),
        ),
      );

      expect(
        tester.takeException(),
        isNull,
        reason:
            'a provider computing a ratio of two counters can produce 1.0000001 during a '
            'rebuild, and LinearProgressIndicator throws outside [0, 1]. Clamping is the '
            'honest response: the bar is already at its end',
      );
    });

    testWidgets('⚠️ the PERCENTAGE is in the semantics label, not drawn', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: ChapterProgressLine(progress: 0.42)),
        ),
      );

      expect(
        find.bySemanticsLabel('42%'),
        findsOneWidget,
        reason:
            '§ 4.3.1: the percentage belongs in the semantics label. Text drawn at 2dp over '
            'a title is unreadable and untranslatable in any layout without that free space',
      );
    });
  });

  group(
    'FailedChapterRetry — C12: a failure state is ACTIONABLE, or it says why not',
    () {
      Future<void> pump(WidgetTester tester, SourceFailure failure) =>
          tester.pumpWidget(
            MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: FailedChapterRetry(failure: failure, onRetry: () {}),
              ),
            ),
          );

      testWidgets('⚠️ a LAYOUT CHANGE offers NO retry, because nothing repairs it', (
        WidgetTester tester,
      ) async {
        await pump(
          tester,
          const SourceLayoutChanged(
            failedSelector: '.chapter-body',
            status: 200,
          ),
        );

        expect(
          find.text('Cancel'),
          findsNothing,
          reason:
              'C12: a `null` recovery is a deliberate blank where a Retry button would be a '
              'lie. No retry repairs a site that has moved its markup, and offering one '
              'sends the reader round a loop',
        );
        expect(
          find.byIcon(Icons.error_outline),
          findsOneWidget,
          reason:
              'but the failure is still SHOWN — a blank is not the same as nothing',
        );
      });

      testWidgets(
        '⚠️ a LOST CONNECTION DOES offer Retry, and pressing it fires once',
        (WidgetTester tester) async {
          int pressed = 0;
          await tester.pumpWidget(
            MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: FailedChapterRetry(
                  failure: const NoConnection(host: 'example.invalid'),
                  onRetry: () => pressed++,
                ),
              ),
            ),
          );

          await tester.tap(find.text('Retry'));
          expect(
            pressed,
            1,
            reason: 'B22: the control re-queues THIS chapter and nothing else',
          );
        },
      );
    },
  );
}
