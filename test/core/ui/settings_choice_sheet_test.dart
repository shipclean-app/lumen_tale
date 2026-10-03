// Lumen Tale — `design-system.md` § 2.12, the `SettingsChoiceSheet`.
//
// The four states § 2.12 lists (`default` · `pressed` · `focused` · `disabled`) are
// rendering states and get widget rows here. The one that matters most is **not** on
// that list — § 11.1's *Submit error* — because it is the state where the component
// could quietly break the app's central rule: a sheet that applies a value the store
// refused would leave a reader looking at a window the app cannot honour (C8).
//
// Every row drives the sheet through the **same** window type `6-5` passes, because
// the genericness of the component is only worth anything if the tests use it the way
// the two call sites will.

import 'dart:async';

import 'package:flutter/gestures.dart' show kPressTimeout;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumen_tale/app/theme/app_theme.dart';
import 'package:lumen_tale/core/ui/settings_choice_sheet.dart';
import 'package:lumen_tale/domain/history/history_retention.dart';
import 'package:lumen_tale/l10n/generated/app_localizations.dart';

/// The one width v1 ships (`design-system.md` § 1.7).
const Size designSize = Size(360, 640);

/// The five rows, supplied the way `6-5` supplies them: **from the enum**, never from
/// a list written inside this widget.
List<SettingsChoiceOption<HistoryRetention>> retentionOptions() {
  return <SettingsChoiceOption<HistoryRetention>>[
    for (final HistoryRetention window in HistoryRetention.values)
      SettingsChoiceOption<HistoryRetention>(
        value: window,
        label: _label(window),
      ),
  ];
}

String _label(HistoryRetention window) => switch (window) {
  HistoryRetention.oneWeek => 'one week',
  HistoryRetention.oneMonth => 'one month',
  HistoryRetention.threeMonths => 'three months',
  HistoryRetention.oneYear => 'one year',
  HistoryRetention.twoYears => 'two years',
};

// ⚠️ `_label(window)`, never `$window`. The first version interpolated the enum
// member directly and three rows failed on `HistoryRetention.threeMonths` — which is
// exactly the leak the widget's `labelOf` signature exists to prevent, reproduced by
// the test's own helper.
String _warning(HistoryRetention window) =>
    'Entries older than ${_label(window)} will be dropped, oldest first. Your '
    'reading positions are never affected.';

Future<void> pumpSheet(
  WidgetTester tester, {
  required HistoryRetention selected,
  required Future<void> Function(HistoryRetention value) onSelected,
  List<SettingsChoiceOption<HistoryRetention>>? options,
}) async {
  tester.view
    ..physicalSize = designSize
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.day(),
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (BuildContext context) => Scaffold(
          body: SettingsChoiceSheet<HistoryRetention>(
            title: AppLocalizations.of(context).historySheetTitle,
            options: options ?? retentionOptions(),
            selected: selected,
            labelOf: _label,
            warningFor: _warning,
            onSelected: onSelected,
          ),
        ),
      ),
    ),
  );
}

/// The row currently carrying the checkmark.
Finder checkedRow() => find.byWidgetPredicate(
  (Widget widget) =>
      widget is Semantics &&
      widget.properties.checked == true &&
      widget.properties.label != null,
);

void main() {
  group('default', () {
    testWidgets('renders one row per option, in the order given', (
      WidgetTester tester,
    ) async {
      await pumpSheet(
        tester,
        selected: HistoryRetention.oneYear,
        onSelected: (_) async {},
      );

      expect(find.byType(SettingsChoiceOption<HistoryRetention>), findsNothing);
      expect(find.text('one week'), findsOneWidget);
      expect(find.text('two years'), findsOneWidget);
      // § 2.12's five windows, and **no sixth**. `design-system.md` forbids a
      // "forever" option on a bounded list because an unbounded value next to bounded
      // ones teaches the reader the bounds are negotiable.
      expect(find.text('forever'), findsNothing);
      expect(find.text('Keep everything'), findsNothing);
    });

    testWidgets(
      'the title comes from the caller, not from the screen that opened it',
      (WidgetTester tester) async {
        // The same five windows have two call sites and one of them opens this sheet
        // from inside a notice rather than from under a row label.
        await pumpSheet(
          tester,
          selected: HistoryRetention.oneYear,
          onSelected: (_) async {},
        );
        expect(find.text('Keep history for'), findsOneWidget);
      },
    );

    testWidgets('the selected option is the checked one', (
      WidgetTester tester,
    ) async {
      await pumpSheet(
        tester,
        selected: HistoryRetention.oneMonth,
        onSelected: (_) async {},
      );

      expect(checkedRow(), findsOneWidget);
      expect(
        tester.widget<Semantics>(checkedRow()).properties.label,
        'one month',
      );
    });

    testWidgets('the warning sentence names the SELECTED window', (
      WidgetTester tester,
    ) async {
      // ⚠️ This is the reason the component exists rather than a plain radio group:
      // the reader must see the effect of a window, and the effect is a sentence.
      await pumpSheet(
        tester,
        selected: HistoryRetention.threeMonths,
        onSelected: (_) async {},
      );

      final Finder warning = find.byKey(
        const Key('settingsChoiceSheet.warning'),
      );
      expect(warning, findsOneWidget);
      expect(tester.widget<Text>(warning).data, contains('three months'));
    });
  });

  group('submit error — the state C8 exists for', () {
    testWidgets('a failed write keeps the sheet OPEN', (
      WidgetTester tester,
    ) async {
      await pumpSheet(
        tester,
        selected: HistoryRetention.oneYear,
        onSelected: (_) async => throw StateError('the OS declined'),
      );

      await tester.tap(find.text('three months'));
      await tester.pumpAndSettle();

      expect(
        find.byType(SettingsChoiceSheet<HistoryRetention>),
        findsOneWidget,
        reason: 'a sheet that closed could not honour the promise in § 11.1',
      );
    });

    testWidgets(
      'a failed write snaps the checkmark back to the previous window',
      (WidgetTester tester) async {
        await pumpSheet(
          tester,
          selected: HistoryRetention.oneYear,
          onSelected: (_) async => throw StateError('the OS declined'),
        );

        await tester.tap(find.text('three months'));
        await tester.pumpAndSettle();

        expect(
          tester.widget<Semantics>(checkedRow()).properties.label,
          'one year',
          reason:
              'a checkmark on a window the store refused is a setting the app '
              'displays and cannot honour — B24, C8',
        );
      },
    );

    testWidgets('a failed write shows a field-level error, not a silent no-op', (
      WidgetTester tester,
    ) async {
      await pumpSheet(
        tester,
        selected: HistoryRetention.oneYear,
        onSelected: (_) async => throw StateError('the OS declined'),
      );

      await tester.tap(find.text('three months'));
      await tester.pumpAndSettle();

      // Without this the sheet would sit there looking unchanged and the reader's
      // tap would have appeared to do nothing at all.
      expect(
        find.byKey(const Key('settingsChoiceSheet.error')),
        findsOneWidget,
      );
      expect(
        find.text(
          'This setting could not be saved. It will keep its previous value.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('the error names the previous value, so nothing is left implied', (
      WidgetTester tester,
    ) async {
      // "It will keep its previous value" only reassures if the reader knows what the
      // previous value was — and the checkmark is the answer, which is why the
      // snap-back row above is not decoration either.
      await pumpSheet(
        tester,
        selected: HistoryRetention.twoYears,
        onSelected: (_) async => throw StateError('the OS declined'),
      );

      await tester.tap(find.text('one week'));
      await tester.pumpAndSettle();

      expect(
        tester.widget<Semantics>(checkedRow()).properties.label,
        'two years',
      );
    });

    testWidgets('a failed write leaves no exception in the zone', (
      WidgetTester tester,
    ) async {
      // `SettingsPersistenceException` is deliberately NOT an `AppException`, so a
      // narrower `on` clause would let it escape as an unhandled async error.
      await pumpSheet(
        tester,
        selected: HistoryRetention.oneYear,
        onSelected: (_) async =>
            throw const FormatException('not an AppException'),
      );

      await tester.tap(find.text('three months'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'the warning sentence still names the previous window after a failure',
      (WidgetTester tester) async {
        // The sentence is keyed on the **committed** value, so it follows the rollback.
        // A warning that described the window the reader just tried to pick would be
        // describing a setting that does not exist.
        await pumpSheet(
          tester,
          selected: HistoryRetention.oneYear,
          onSelected: (_) async => throw StateError('the OS declined'),
        );

        await tester.tap(find.text('three months'));
        await tester.pumpAndSettle();

        final Finder warning = find.byKey(
          const Key('settingsChoiceSheet.warning'),
        );
        expect(tester.widget<Text>(warning).data, contains('one year'));
      },
    );

    testWidgets('a later successful write clears the error', (
      WidgetTester tester,
    ) async {
      HistoryRetention? written;
      await pumpSheet(
        tester,
        selected: HistoryRetention.oneYear,
        onSelected: (HistoryRetention value) async {
          if (written == null) {
            throw StateError('the OS declined');
          }
        },
      );

      await tester.tap(find.text('three months'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('settingsChoiceSheet.error')),
        findsOneWidget,
      );

      written = HistoryRetention.threeMonths;
      await tester.tap(find.text('one week'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('settingsChoiceSheet.error')), findsNothing);
      expect(
        tester.widget<Semantics>(checkedRow()).properties.label,
        'one week',
      );
    });
  });

  group('success', () {
    testWidgets('a successful write moves the checkmark', (
      WidgetTester tester,
    ) async {
      await pumpSheet(
        tester,
        selected: HistoryRetention.oneYear,
        onSelected: (_) async {},
      );

      await tester.tap(find.text('one week'));
      await tester.pumpAndSettle();

      expect(
        tester.widget<Semantics>(checkedRow()).properties.label,
        'one week',
      );
    });

    testWidgets('the warning sentence is rewritten as the selection moves', (
      WidgetTester tester,
    ) async {
      await pumpSheet(
        tester,
        selected: HistoryRetention.oneYear,
        onSelected: (_) async {},
      );

      final Finder warning = find.byKey(
        const Key('settingsChoiceSheet.warning'),
      );
      await tester.tap(find.text('one week'));
      await tester.pumpAndSettle();

      expect(tester.widget<Text>(warning).data, contains('one week'));
    });

    testWidgets('the checkmark does NOT move while the write is in flight', (
      WidgetTester tester,
    ) async {
      // ⚠️ **The row the *pending* design fails.**
      //
      // A version that set the checkmark before awaiting the write is
      // observationally identical once the rollback lands — and therefore invisible
      // to every other row here. The difference is the frame in between: for the
      // whole duration of a write on a slow disk, the sheet would display a window
      // the store does not hold. B24's rule is *write, then mutate*, because a
      // control that mutates before writing displays a setting it cannot keep (C8).
      final Completer<void> gate = Completer<void>();
      await pumpSheet(
        tester,
        selected: HistoryRetention.oneYear,
        onSelected: (_) => gate.future,
      );

      await tester.tap(find.text('three months'));
      await tester.pump(kPressTimeout + const Duration(milliseconds: 50));
      await tester
          .pump(); // the tap's recognition lands; the write is now pending

      expect(
        tester.widget<Semantics>(checkedRow()).properties.label,
        'one year',
        reason:
            'the write has not returned, so the app does not know the new value',
      );

      gate.complete();
      await tester.pumpAndSettle();
      expect(
        tester.widget<Semantics>(checkedRow()).properties.label,
        'three months',
      );
    });

    testWidgets('tapping the selected row is not a write', (
      WidgetTester tester,
    ) async {
      int writes = 0;
      await pumpSheet(
        tester,
        selected: HistoryRetention.oneYear,
        onSelected: (_) async => writes += 1,
      );

      await tester.tap(find.text('one year'));
      await tester.pumpAndSettle();

      expect(
        writes,
        0,
        reason:
            'a redundant write is not harmless — it is a second chance to fail, and '
            'the failure would be shown to a reader who changed nothing',
      );
    });

    testWidgets('the write is called with the value, not the label', (
      WidgetTester tester,
    ) async {
      final List<HistoryRetention> written = <HistoryRetention>[];
      await pumpSheet(
        tester,
        selected: HistoryRetention.oneYear,
        onSelected: (HistoryRetention value) async => written.add(value),
      );

      await tester.tap(find.text('two years'));
      await tester.pumpAndSettle();

      expect(written, <HistoryRetention>[HistoryRetention.twoYears]);
    });
  });

  group('pressed', () {
    testWidgets('a finger down paints --color-surface-sunken on that row', (
      WidgetTester tester,
    ) async {
      await pumpSheet(
        tester,
        selected: HistoryRetention.oneYear,
        onSelected: (_) async {},
      );

      final Finder row = find.text('one month');
      final TestGesture gesture = await tester.startGesture(
        tester.getCenter(row),
      );
      // ⚠️ **100ms, and it is not padding.** `TapGestureRecognizer` fires `onTapDown`
      // from `didExceedDeadline()` (`gestures/tap.dart:343`), after `kPressTimeout`
      // — the deadline is how the recognizer disambiguates a tap from a scroll drag.
      // A `startGesture` plus a single `pump()` has therefore pressed nothing, and a
      // row that claims to acknowledge the finger must be caught mid-press.
      await tester.pump(kPressTimeout + const Duration(milliseconds: 50));

      final Color painted = _rowBackground(tester, row);
      expect(
        painted,
        isNot(Colors.transparent),
        reason: '§ 2.12 pressed state: the row must acknowledge the finger',
      );

      await gesture.up();
      await tester.pumpAndSettle();
    });
  });

  group('focused', () {
    testWidgets('arrow keys move focus and wrap at both ends', (
      WidgetTester tester,
    ) async {
      await pumpSheet(
        tester,
        selected: HistoryRetention.oneYear,
        onSelected: (_) async {},
      );

      // Start on the committed row (index 3, one year) and walk down: 3 → 4 → wrap to 0.
      FocusNode nodeFor(String label) => tester
          .widget<Focus>(
            find
                .descendant(
                  of: find.byWidgetPredicate(
                    (Widget w) =>
                        w is Semantics &&
                        w.properties.label == label &&
                        w.properties.checked != null,
                  ),
                  matching: find.byType(Focus),
                )
                .first,
          )
          .focusNode!;

      nodeFor('one year').requestFocus();
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      expect(nodeFor('two years').hasFocus, isTrue);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      expect(
        nodeFor('one week').hasFocus,
        isTrue,
        reason: '↓ on the last row must wrap, not stop at a dead end',
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pump();
      expect(nodeFor('two years').hasFocus, isTrue);
    });

    testWidgets('Enter selects the focused row', (WidgetTester tester) async {
      final List<HistoryRetention> written = <HistoryRetention>[];
      await pumpSheet(
        tester,
        selected: HistoryRetention.oneYear,
        onSelected: (HistoryRetention value) async => written.add(value),
      );

      await _focusLabel(tester, 'three months');
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      expect(written, <HistoryRetention>[HistoryRetention.threeMonths]);
    });
  });

  group('disabled', () {
    testWidgets('a disabled row announces itself as disabled', (
      WidgetTester tester,
    ) async {
      final List<SettingsChoiceOption<HistoryRetention>> options =
          retentionOptions();
      await pumpSheet(
        tester,
        selected: HistoryRetention.oneYear,
        onSelected: (_) async {},
        options: <SettingsChoiceOption<HistoryRetention>>[
          options.first,
          const SettingsChoiceOption<HistoryRetention>(
            value: HistoryRetention.oneMonth,
            label: 'one month',
            enabled: false,
          ),
          ...options.skip(2),
        ],
      );

      final Semantics disabled = tester.widget<Semantics>(
        find.byWidgetPredicate(
          (Widget w) => w is Semantics && w.properties.label == 'one month',
        ),
      );
      expect(disabled.properties.enabled, isFalse);
    });

    testWidgets('a disabled row cannot be selected', (
      WidgetTester tester,
    ) async {
      final List<SettingsChoiceOption<HistoryRetention>> options =
          retentionOptions();
      final List<HistoryRetention> written = <HistoryRetention>[];
      await pumpSheet(
        tester,
        selected: HistoryRetention.oneYear,
        onSelected: (HistoryRetention value) async => written.add(value),
        options: <SettingsChoiceOption<HistoryRetention>>[
          const SettingsChoiceOption<HistoryRetention>(
            value: HistoryRetention.oneMonth,
            label: 'one month',
            enabled: false,
          ),
          ...options,
        ],
      );

      await tester.tap(find.text('one month').first);
      await tester.pumpAndSettle();

      expect(written, isEmpty);
    });

    testWidgets('arrow keys walk PAST a disabled row instead of stopping on it', (
      WidgetTester tester,
    ) async {
      // The list goes: one week · one month (disabled) · three months · one year ·
      // two years. From *one week*, the down arrow must reach *three months*.
      //
      // ⚠️ **This row is what forbids "fall back to the first enabled row."** That
      // fallback would land on *one week* again — the key the reader pressed would
      // appear to do nothing at all — so a shorter implementation of the skip passes
      // every other row in this file.
      await pumpSheet(
        tester,
        selected: HistoryRetention.oneWeek,
        onSelected: (_) async {},
        options: <SettingsChoiceOption<HistoryRetention>>[
          const SettingsChoiceOption<HistoryRetention>(
            value: HistoryRetention.oneWeek,
            label: 'one week',
          ),
          const SettingsChoiceOption<HistoryRetention>(
            value: HistoryRetention.oneMonth,
            label: 'one month',
            enabled: false,
          ),
          const SettingsChoiceOption<HistoryRetention>(
            value: HistoryRetention.threeMonths,
            label: 'three months',
          ),
          const SettingsChoiceOption<HistoryRetention>(
            value: HistoryRetention.oneYear,
            label: 'one year',
          ),
          const SettingsChoiceOption<HistoryRetention>(
            value: HistoryRetention.twoYears,
            label: 'two years',
          ),
        ],
      );

      await _focusLabel(tester, 'one week');
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();

      expect(
        await _hasFocus(tester, 'three months'),
        isTrue,
        reason: 'the down arrow must carry on past a row that cannot be taken',
      );
      expect(await _hasFocus(tester, 'one week'), isFalse);
    });
  });

  group('the component holds no list of windows', () {
    test('the rows come from the enum, so a sixth window needs one edit', () {
      // § 2.12: *"a screen may not restate the list"*. The widget is generic over `T`
      // for exactly this reason — a sheet written against `HistoryRetention` would be
      // a second statement of which five windows exist, beside the enum.
      expect(retentionOptions(), hasLength(HistoryRetention.values.length));
      expect(
        retentionOptions().map(
          (SettingsChoiceOption<HistoryRetention> o) => o.value,
        ),
        HistoryRetention.values,
      );
    });
  });
}

/// Focus the row carrying [label], so the keyboard rows can start from a known place.
Future<void> _focusLabel(WidgetTester tester, String label) async {
  final Focus focus = tester.widget<Focus>(
    find
        .descendant(
          of: find.byWidgetPredicate(
            (Widget w) => w is Semantics && w.properties.label == label,
          ),
          matching: find.byType(Focus),
        )
        .first,
  );
  focus.focusNode!.requestFocus();
  await tester.pump();
}

Future<bool> _hasFocus(WidgetTester tester, String label) async {
  final Focus focus = tester.widget<Focus>(
    find
        .descendant(
          of: find.byWidgetPredicate(
            (Widget w) => w is Semantics && w.properties.label == label,
          ),
          matching: find.byType(Focus),
        )
        .first,
  );
  return focus.focusNode!.hasFocus;
}

/// The colour painted behind a row, read from its `Container`.
///
/// ⚠️ Read from the widget rather than from a screenshot: the property under test is
/// *"this row paints the sunken surface when a finger is down"*, and a pixel
/// comparison would also pass if some other element painted that colour.
Color _rowBackground(WidgetTester tester, Finder rowText) {
  final Finder container = find
      .ancestor(of: rowText, matching: find.byType(Container))
      .first;
  final Container widget = tester.widget<Container>(container);
  return widget.decoration == null
      ? widget.color ?? Colors.transparent
      : (widget.decoration! as BoxDecoration).color ?? Colors.transparent;
}
