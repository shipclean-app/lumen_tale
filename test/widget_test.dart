import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumen_tale/l10n/generated/app_localizations.dart';
import 'package:lumen_tale/main.dart';

void main() {
  group('LumenTaleApp bootstrap', () {
    testWidgets('configures localization for both supported locales', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(const LumenTaleApp());

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

    testWidgets('provides light and dark themes and honours the system mode', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(const LumenTaleApp());

      final MaterialApp app = tester.widget<MaterialApp>(
        find.byType(MaterialApp),
      );

      expect(app.theme, isNotNull, reason: '14-design-tokens.md: light theme');
      expect(
        app.darkTheme,
        isNotNull,
        reason: '14-design-tokens.md: dark theme',
      );
      expect(app.themeMode, ThemeMode.system);
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
