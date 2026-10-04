import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumen_tale/app/theme/app_theme_preferences.dart';
import 'package:lumen_tale/app/theme/theme_providers.dart';
import 'package:lumen_tale/l10n/generated/app_localizations.dart';
import 'package:lumen_tale/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('LumenTaleApp bootstrap', () {
    /// ⚠️ **THE SCOPE AND THE OVERRIDE ARE BOTH PART OF WHAT IS BEING TESTED.**
    ///
    /// `LumenTaleApp` is a `ConsumerWidget` — it became one when `2-8` applied B26 here and
    /// only here — so it reads its `themeMode` from a provider. Two things follow, and both
    /// are properties of the real tree rather than scaffolding:
    ///
    /// 1. a `ConsumerWidget` with no `ProviderScope` above it throws
    ///    `Bad state: No ProviderScope found` **while building**, so the scope is required;
    /// 2. `appThemePreferencesProvider` is declared
    ///    `throw UnimplementedError('overridden at the bootstrap by 0-5')`, and `main()` is
    ///    **the only** place that override exists. Reading the theme without it is an
    ///    `UnimplementedError`, not a default.
    ///
    /// So this mounts exactly what production mounts: a `ProviderScope` carrying
    /// `SharedPrefsThemePreferences` over an empty in-memory store. The empty store is what
    /// makes the second row's `ThemeMode.system` assertion true — it is the real
    /// no-preference-yet answer, read through the real reader.
    Future<void> pumpBootstrap(WidgetTester tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appThemePreferencesProvider.overrideWithValue(
              SharedPrefsThemePreferences(prefs),
            ),
          ],
          child: const LumenTaleApp(),
        ),
      );
    }

    testWidgets('configures localization for both supported locales', (
      WidgetTester tester,
    ) async {
      await pumpBootstrap(tester);

      final MaterialApp app = tester.widget<MaterialApp>(
        find.byType(MaterialApp),
      );

      expect(
        app.localizationsDelegates,
        isNotNull,
        reason: '16-i18n.md: delegates must be wired in main.dart',
      );
      expect(
        app.supportedLocales,
        containsAll(<Locale>[const Locale('en'), const Locale('fr')]),
      );
    });

    // ⚠️ **THIS ROW USED TO ASSERT `ThemeMode.system`, AND `2-8` DELETED THAT CONTRACT.**
    //
    // `themeMode` is now `themeOverride.resolve(MediaQuery.platformBrightnessOf(context))` —
    // the system choice is **resolved into a concrete mode** rather than handed to the
    // framework unresolved. That is deliberate: the platform brightness has to be read
    // *above* the `MaterialApp`, and the resolution has to happen where that value still
    // exists. So `system` is no longer a value this app ever passes.
    //
    // Asserting a literal `system` would be asserting the old contract, and asserting only
    // `light` would pass on a build that ignored the platform entirely. **Both platforms**
    // is what actually says "honours the system mode", so that is what is asserted.
    Future<MaterialApp> pumpOnPlatform(
      WidgetTester tester,
      Brightness brightness,
    ) async {
      tester.platformDispatcher.platformBrightnessTestValue = brightness;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appThemePreferencesProvider.overrideWithValue(
              SharedPrefsThemePreferences(prefs),
            ),
          ],
          child: const LumenTaleApp(),
        ),
      );
      return tester.widget<MaterialApp>(find.byType(MaterialApp));
    }

    testWidgets('provides light and dark themes and honours the system mode', (
      WidgetTester tester,
    ) async {
      final MaterialApp onLight = await pumpOnPlatform(
        tester,
        Brightness.light,
      );
      final MaterialApp onDark = await pumpOnPlatform(tester, Brightness.dark);

      expect(
        onLight.theme,
        isNotNull,
        reason: '14-design-tokens.md: light theme',
      );
      expect(
        onDark.darkTheme,
        isNotNull,
        reason: '14-design-tokens.md: dark theme',
      );
      expect(
        onLight.themeMode,
        ThemeMode.light,
        reason:
            'an EMPTY preference store means "follow the platform", so on a light platform '
            'the app resolves to light — not to a literal `system`, which it no longer emits',
      );
      expect(
        onDark.themeMode,
        ThemeMode.dark,
        reason:
            'and the SAME empty store on a dark platform resolves to dark. Together these '
            'two are what "honours the system mode" means; either alone would pass on a '
            'build that ignored the platform',
      );
    });
  });

  group('AppLocalizations', () {
    Future<void> pumpIn(WidgetTester tester, Locale locale) async {
      await tester.pumpWidget(
        MaterialApp(
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (BuildContext context) {
              return Text(AppLocalizations.of(context).navLibrary);
            },
          ),
        ),
      );
    }

    testWidgets('resolves English strings', (WidgetTester tester) async {
      await pumpIn(tester, const Locale('en'));
      expect(find.text('Library'), findsOneWidget);
    });

    testWidgets('resolves French strings', (WidgetTester tester) async {
      await pumpIn(tester, const Locale('fr'));
      expect(find.text('Bibliothèque'), findsOneWidget);
    });

    testWidgets('plural forms are wired for both locales', (
      WidgetTester tester,
    ) async {
      await pumpIn(tester, const Locale('en'));
      final AppLocalizations en = await AppLocalizations.delegate.load(
        const Locale('en'),
      );
      expect(en.chapterCount(0), 'No chapters');
      expect(en.chapterCount(1), '1 chapter');
      expect(en.chapterCount(12), '12 chapters');

      final AppLocalizations fr = await AppLocalizations.delegate.load(
        const Locale('fr'),
      );
      expect(fr.chapterCount(0), 'Aucun chapitre');
      expect(fr.chapterCount(1), '1 chapitre');
      expect(fr.chapterCount(12), '12 chapitres');
    });
  });
}
