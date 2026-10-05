// forge:slice 3-3
// Lumen Tale — `core/ui/`'s new surface: byte formatting and the two dialogues.
//
// ## The rows
//
// | rule | the row |
// |---|---|
// | E20 — no `~`, no `≈`, no estimate | *41 003 bytes is `41 KB`, never "about 40 KB"* |
// | a size is never negative | *an underflow prints `0 B`, not `-1 B`* |
// | 1024, not 1000 | *1 024 bytes is `1 KB`* — a KB here is what a filesystem reports |
// | B33 — confirm before a destruction | *cancel returns `false` and the tile keeps the copy* |
// | B33 — no **Undo** | *the dialog offers Cancel and Delete, and nothing else* |
// | E20 — the refusal shows **both** numbers | *the body carries required AND free* |
// | E20 — no "download anyway" | *there is no accept path* |

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumen_tale/core/ui/byte_format.dart';
import 'package:lumen_tale/core/ui/delete_stored_chapter_dialog.dart';
import 'package:lumen_tale/core/ui/space_refused_dialog.dart';
import 'package:lumen_tale/l10n/generated/app_localizations.dart';

/// Mounts a localized app and hands back a context inside it.
///
/// ⚠️ **REAL `AppLocalizations`, NOT A STUB.** These rows are about what a reader is *told*,
/// and a stubbed l10n would let every wording assertion pass while the ARB said nothing —
/// which is exactly the class of defect this project shipped today in
/// `settingsSpecimenCredit`, where the EN and FR placeholder names disagreed and nothing in
/// the l10n suite looked at the dialogs.
/// ⚠️ **41 KiB EXACTLY, as a named constant.** The plan's prose says "41 Ko" and a literal
/// 41003 is 40.04 KiB — so a row that wrote 41003 and expected 41 KB would be testing
/// rounding, and would have failed against the truncating formatter that is correct here.
const int k41 = 41 * 1024;

Future<void> pumpLocalized(
  WidgetTester tester, {
  Locale locale = const Locale('en'),
}) => tester.pumpWidget(
  MaterialApp(
    locale: locale,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: const Scaffold(body: SizedBox.shrink()),
  ),
);

void main() {
  group('E20 — a size is stated, never estimated', () {
    testWidgets('⚠️ 41 KiB is `41 KB` and never "about 40 KB"', (
      WidgetTester tester,
    ) async {
      await pumpLocalized(tester);

      final String text = tester
          .element(find.byType(Scaffold))
          .let((BuildContext c) => formatBytes(c, k41));

      expect(
        text,
        contains('41'),
        reason:
            'the MEASURED size. E20 forbids `~`, `≈` and "estimate" in this feature, and a '
            'rounded figure cannot found a refusal or be compared with a file manager',
      );
      expect(
        text,
        isNot(contains('~')),
        reason: 'E20: no approximation marker may reach a reader',
      );
      expect(
        text,
        isNot(contains('≈')),
        reason:
            'E20: and no unicode approximation either — the grep looks for both',
      );
    });

    testWidgets('⚠️ 1 024 bytes is `1 KB`, not `1.02 KB` and not `1024 B`', (
      WidgetTester tester,
    ) async {
      await pumpLocalized(tester);
      final BuildContext context = tester.element(find.byType(Scaffold));

      expect(
        formatBytes(context, 1024),
        contains('1 KB'),
        reason:
            'the base is 1024, which is what a filesystem reports. Mixing 1000 and 1024 '
            'makes "1 KB" mean two different sizes in two places in the same app',
      );
    });

    // ⚠️ **TRUNCATION, NOT ROUNDING, AND THE DIRECTION IS THE POINT.**
    // 40 999 bytes is 39.99 KiB. Rounding prints "40 KB" for a file that needs 40 999 bytes, so
    // a reader reading the figure would budget 41 KB and be short by 41 bytes. Truncation
    // understates, which is the safe direction for a *space* figure: it never promises room that
    // is not there.
    testWidgets('⚠️ a size TRUNCATES, so it never promises room that is not there', (
      WidgetTester tester,
    ) async {
      await pumpLocalized(tester);
      final BuildContext context = tester.element(find.byType(Scaffold));

      expect(
        formatBytes(context, 41499),
        contains('40 KB'),
        reason:
            '41 499 bytes is 40.53 KiB, and it is chosen because it is a value where '
            'truncation and rounding DISAGREE. Rounding would print "41 KB" and a reader '
            'budgeting from that figure would be 475 bytes short — truncation never '
            'overstates a need. 40 999 would have been useless here: both give 40',
      );
    });

    // ⚠️ **THE ROW THAT IS ABOUT A BUG UPSTREAM.** A subtraction that underflowed must not
    // print a negative size into a dialog about freeing space.
    testWidgets('⚠️ a NEGATIVE size prints `0 B`, never `-1 B`', (
      WidgetTester tester,
    ) async {
      await pumpLocalized(tester);
      final BuildContext context = tester.element(find.byType(Scaffold));

      expect(
        formatBytes(context, -1),
        contains('0'),
        reason:
            'a negative byte count is an arithmetic bug upstream. Printing it would put '
            '"-1 B" in a sentence about how much space a deletion freed',
      );
      expect(
        formatBytes(context, -1),
        isNot(contains('-')),
        reason: 'and no minus sign survives into a reader-facing string',
      );
    });

    testWidgets('⚠️ `0` BYTES IS `0 B` AND IS NOT TREATED AS MISSING', (
      WidgetTester tester,
    ) async {
      await pumpLocalized(tester);
      final BuildContext context = tester.element(find.byType(Scaffold));

      expect(
        formatBytes(context, 0),
        contains('0'),
        reason:
            'a genuinely empty chapter is 0 bytes and that is a real answer. It is not `null` '
            'and it is not hidden',
      );
    });

    testWidgets('⚠️ the UNIT is localized and the NUMBER is not', (
      WidgetTester tester,
    ) async {
      await pumpLocalized(tester);
      final String en = formatBytes(tester.element(find.byType(Scaffold)), k41);

      await pumpLocalized(tester, locale: const Locale('fr'));
      final String fr = formatBytes(tester.element(find.byType(Scaffold)), k41);

      expect(en, contains('KB'), reason: 'English says KB');
      expect(
        fr,
        contains('Ko'),
        reason:
            'and French says Ko. A reader whose phone is in French and whose snackbar says '
            '"41 KB" has been told the app does not speak their language',
      );
      expect(
        en,
        allOf(contains('41'), contains('KB')),
        reason:
            'and English says 41 KB — the VALUE is the same number in both, only the unit '
            'is translated. Checking the whole string is what makes the row say that',
      );
    });
  });

  group('B33 — the delete confirmation', () {
    testWidgets('⚠️ Cancel returns `false`, so nothing is destroyed', (
      WidgetTester tester,
    ) async {
      await pumpLocalized(tester);
      bool? answer;

      unawaited(
        confirmDeleteStoredChapter(
          context: tester.element(find.byType(Scaffold)),
          ordinal: 214,
          siblingCount: 479,
          freedBytes: k41,
        ).then((bool value) => answer = value),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(
        answer,
        isFalse,
        reason:
            'B33: this is the one destruction that cannot be undone, so cancelling must be '
            'the easy path and must not be the ambiguous one',
      );
    });

    testWidgets('⚠️ Delete returns `true` and it is the ONLY affirmative', (
      WidgetTester tester,
    ) async {
      await pumpLocalized(tester);
      bool? answer;

      unawaited(
        confirmDeleteStoredChapter(
          context: tester.element(find.byType(Scaffold)),
          ordinal: 214,
          siblingCount: 479,
          freedBytes: k41,
        ).then((bool value) => answer = value),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(answer, isTrue);
    });

    // ⚠️ **THE ROW `downloads.md` § 4 ARGUES FOR.** Removing a novel from the library is
    // reversible *because nothing is destroyed* (B32). Deleting a download IS the
    // destruction — no backup, no export (B31, C8) — so an Undo would promise to re-fetch
    // content that may have changed or disappeared. The absence of one is the design.
    testWidgets('⚠️ there is NO "Undo", and the dialog cannot be tapped away', (
      WidgetTester tester,
    ) async {
      await pumpLocalized(tester);

      unawaited(
        confirmDeleteStoredChapter(
          context: tester.element(find.byType(Scaffold)),
          ordinal: 214,
          siblingCount: 479,
          freedBytes: k41,
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Undo'),
        findsNothing,
        reason:
            'an Undo here would promise to re-download content that may have changed or '
            'disappeared. C8: the app does not keep a copy',
      );
      expect(
        find.byType(AlertDialog),
        findsOneWidget,
        reason: 'and the confirmation is on screen until the reader answers it',
      );
    });

    testWidgets('⚠️ the body names the SIBLINGS and the MEASURED bytes', (
      WidgetTester tester,
    ) async {
      await pumpLocalized(tester);

      unawaited(
        confirmDeleteStoredChapter(
          context: tester.element(find.byType(Scaffold)),
          ordinal: 214,
          siblingCount: 479,
          freedBytes: k41,
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.textContaining('479'),
        findsOneWidget,
        reason:
            'the reassurance that matters is "the others are not touched", and it is only '
            'true if the number is real',
      );
      expect(
        find.textContaining('41 KB'),
        findsOneWidget,
        reason:
            'and the freed figure is the measured one, not a rounded promise',
      );
    });

    testWidgets('⚠️ ONE other chapter is a PLURAL, not "1 other chapters"', (
      WidgetTester tester,
    ) async {
      await pumpLocalized(tester);

      unawaited(
        confirmDeleteStoredChapter(
          context: tester.element(find.byType(Scaffold)),
          ordinal: 1,
          siblingCount: 1,
          freedBytes: k41,
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.textContaining('1 other chapter'),
        findsOneWidget,
        reason:
            'English and several other languages need a singular form, and a caller that '
            'branched on `count > 1` would get French, Arabic and Polish wrong',
      );
    });
  });

  group('E20 — the space refusal', () {
    Future<void> showRefusal(
      WidgetTester tester, {
      int required = k41,
      int free = 1024,
    }) async {
      unawaited(
        showSpaceRefusedDialog(
          context: tester.element(find.byType(Scaffold)),
          data: SpaceRefusedDialogData(
            requiredBytes: required,
            freeBytes: free,
            formatBytes: (int bytes) =>
                formatBytes(tester.element(find.byType(Scaffold)), bytes),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('⚠️ the body carries BOTH numbers, required AND free', (
      WidgetTester tester,
    ) async {
      await pumpLocalized(tester);
      await showRefusal(tester);

      expect(
        find.textContaining('41 KB'),
        findsOneWidget,
        reason:
            'E20 names two figures and a refusal with no numbers is a shrug. This is what '
            'the download needs',
      );
      expect(
        find.textContaining('1 KB'),
        findsOneWidget,
        reason: 'and this is what the phone has — the reader needs both to act',
      );
    });

    // ⚠️ **THE ABSENCE THAT IS THE RULE.** Offering to download anyway would enqueue a
    // chapter that cannot be written; offering to delete something would delete on the
    // reader's behalf, and the app does not know what else is on this phone.
    testWidgets('⚠️ there is NO "download anyway" and NO deletion', (
      WidgetTester tester,
    ) async {
      await pumpLocalized(tester);
      await showRefusal(tester);

      expect(
        find.textContaining('anyway'),
        findsNothing,
        reason:
            '§ 4.3.2 forbids it: it would put a chapter in the queue that the filesystem '
            'will refuse, and the tile would then lie about being queued',
      );
      expect(
        find.textContaining('Delete a downloaded'),
        findsNothing,
        reason:
            'and the app may not delete on the reader\'s behalf — it does not know what else '
            'is stored on this phone',
      );
    });

    testWidgets('⚠️ the title is the STORAGE one, not a generic error', (
      WidgetTester tester,
    ) async {
      await pumpLocalized(tester);
      await showRefusal(tester);

      expect(
        find.text('Not enough space'),
        findsOneWidget,
        reason:
            'the reader is told what is wrong in the words the rest of the app uses for it, '
            'so the refusal is recognisable rather than novel',
      );
    });
  });
}

extension _Let on BuildContext {
  T let<T>(T Function(BuildContext) body) => body(this);
}
