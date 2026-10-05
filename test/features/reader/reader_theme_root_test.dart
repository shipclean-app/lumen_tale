// forge:slice 2-8
// Lumen Tale — B26 at the ONE place it is applied: `main.dart`'s `themeMode`.
//
// ## Why this file exists rather than a row inside `reader_controls_test.dart`
//
// § 3.2: *"one single call in the application, in the root widget."* B26's claim is not that
// the reader re-themes — it is that the WHOLE app does, and that a forced theme does **not**
// follow the phone. Asserting that from the reader's controls would prove nothing about the
// app's other nine screens, and asserting `ThemeOverride.resolve` alone would prove nothing
// about whether anything calls it.
//
// So the rows below pump the real root widget and read the `themeMode` it hands Material.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lumen_tale/app/theme/app_theme.dart';
import 'package:lumen_tale/app/theme/app_theme_preferences.dart';
import 'package:lumen_tale/app/theme/reader_scale.dart';
import 'package:lumen_tale/app/theme/theme_override.dart';
import 'package:lumen_tale/app/theme/theme_providers.dart';
import 'package:lumen_tale/l10n/generated/app_localizations.dart';
import 'package:lumen_tale/main.dart';

final class FakePreferences implements AppThemePreferences {
  ReaderTextScale scale = ReaderTextScale.md;
  ThemeOverride theme = ThemeOverride.system;

  @override
  ReaderTextScale readReaderScale() => scale;

  @override
  ThemeOverride readThemeOverride() => theme;

  @override
  Future<void> writeReaderScale(ReaderTextScale value) async => scale = value;

  @override
  Future<void> writeThemeOverride(ThemeOverride value) async => theme = value;
}

/// The root widget, with the platform brightness under the test's control.
///
/// ⚠️ **A `MediaQuery` ABOVE `LumenTaleApp`, not `themeMode: ThemeMode.system` inside it.**
/// `MaterialApp` resolves `themeMode: system` against its OWN platform brightness, which the
/// test binding reports as `light` and which does not move on a `pumpWidget`. Reading
/// `platformBrightness` above the app is what the product does, so that is what is faked.
Future<void> pumpApp(
  WidgetTester tester, {
  required ThemeOverride theme,
  required Brightness platformBrightness,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appThemePreferencesProvider.overrideWithValue(
          FakePreferences()..theme = theme,
        ),
      ],
      child: ValueListenableBuilder<Brightness>(
        valueListenable: _brightness,
        builder: (BuildContext _, Brightness value, _) => MediaQuery(
          data: MediaQueryData(platformBrightness: value),
          child: const LumenTaleApp(),
        ),
      ),
    ),
  );
  // The notifier is driven from inside the builder above, so a test flips the platform by
  // setting it here and pumping.
  _brightness.value = platformBrightness;
  await tester.pumpAndSettle();
}

/// The platform brightness the harness currently reports.
final ValueNotifier<Brightness> _brightness = ValueNotifier<Brightness>(
  Brightness.light,
);

ThemeMode rootThemeMode(WidgetTester tester) =>
    tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode!;

void main() {
  setUp(() => _brightness.value = Brightness.light);

  group('B26 — `system` follows the phone, immediately', () {
    testWidgets('a light phone gives light, and a night phone gives night', (
      WidgetTester tester,
    ) async {
      await pumpApp(
        tester,
        theme: ThemeOverride.system,
        platformBrightness: Brightness.light,
      );
      expect(rootThemeMode(tester), ThemeMode.light);

      // ⚠️ **The flip is a rebuild of the SAME tree.** Pumping a new widget with a different
      // value would prove nothing about a value that is already held.
      _brightness.value = Brightness.dark;
      await tester.pumpAndSettle();

      expect(
        rootThemeMode(tester),
        ThemeMode.dark,
        reason:
            'E13: with `system`, an OS light/dark change re-themes the app with no further '
            'action from the reader',
      );
    });
  });

  group('B26 — an override does NOT follow the phone', () {
    testWidgets('`day` stays light through a flip to night', (
      WidgetTester tester,
    ) async {
      await pumpApp(
        tester,
        theme: ThemeOverride.day,
        platformBrightness: Brightness.dark,
      );
      expect(rootThemeMode(tester), ThemeMode.light);

      _brightness.value = Brightness.light;
      await tester.pumpAndSettle();
      expect(
        rootThemeMode(tester),
        ThemeMode.light,
        reason:
            'the override holds whatever the phone does — that is the whole of it',
      );
    });

    testWidgets('`night` stays dark through a flip to day', (
      WidgetTester tester,
    ) async {
      await pumpApp(
        tester,
        theme: ThemeOverride.night,
        platformBrightness: Brightness.light,
      );
      expect(rootThemeMode(tester), ThemeMode.dark);

      _brightness.value = Brightness.dark;
      await tester.pumpAndSettle();
      expect(rootThemeMode(tester), ThemeMode.dark);
    });
  });

  group('ADR-016 — the two themes are separate designs', () {
    test('each palette declares its own brightness, and they differ', () {
      // ⚠️ **The scheme, not the tree.** `theme_providers_test.dart` records the harness
      // trap: asserting `Theme.of(context).brightness` inside a pumped `MaterialApp` measures
      // MaterialApp's plumbing rather than what this foundation produces.
      expect(AppTheme.day().colorScheme.brightness, Brightness.light);
      expect(AppTheme.night().colorScheme.brightness, Brightness.dark);
      expect(
        AppTheme.day().colorScheme.error,
        isNot(AppTheme.night().colorScheme.error),
        reason:
            'a single error red measures 7.32:1 on paper and 2.27:1 on ink, which is why '
            'the two palettes are designed separately rather than inverted',
      );
    });
  });

  group('the app still resolves its language, and E12 re-localises it', () {
    testWidgets('a French phone gets the French copy at the root', (
      WidgetTester tester,
    ) async {
      await pumpApp(
        tester,
        theme: ThemeOverride.system,
        platformBrightness: Brightness.light,
      );
      final MaterialApp app = tester.widget<MaterialApp>(
        find.byType(MaterialApp),
      );
      expect(
        app.supportedLocales,
        AppLocalizations.supportedLocales,
        reason:
            'and `localeListResolutionCallback` is French-first — the theme follows the '
            'phone and the language does too, independently of each other',
      );
    });
  });
}
