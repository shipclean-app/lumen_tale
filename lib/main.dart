import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lumen_tale/app/router/app_router.dart';
import 'package:lumen_tale/app/theme/app_theme.dart';
import 'package:lumen_tale/app/theme/app_theme_preferences.dart';
import 'package:lumen_tale/app/theme/theme_providers.dart';
import 'package:lumen_tale/l10n/generated/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Bootstrap for Lumen Tale.
///
/// Wiring only: localisation, theme, router. Feature code lives under `features/`
/// and is reachable only through `app/router/app_router.dart`.
///
/// ## `main` is `async` and it AWAITS — load-bearing, not stylistic
///
/// `theme_providers.dart` declares
/// `appThemePreferencesProvider = Provider((ref) => throw
/// UnimplementedError('overridden at the bootstrap by 0-5'))`, and **this file is
/// the only place that override exists**. A synchronous `runApp` leaves the throw
/// live, and the first read of the theme is the first frame — so the app dies on
/// launch, in a way that looks like a provider bug rather than a missing override.
///
/// Two consequences, and both are the point:
///
/// - `SharedPreferences` is resolved **once**, before any route exists, so every
///   later read is synchronous. A settings-store load error is therefore
///   **unreachable** as a screen state — the failure is a *bootstrap* failure,
///   which is why `settings.md` § 4 struck that state.
/// - `MissingPluginException` is **not** caught. An app that cannot persist a
///   setting must not pretend it can; swallowing this would give the reader a
///   switch that silently does nothing.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final SharedPreferences prefs = await SharedPreferences.getInstance();

  runApp(
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

/// Root widget.
class LumenTaleApp extends StatelessWidget {
  const LumenTaleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      // `go_router` holds the one instance. **Not a provider**: navigation state
      // is the router's, and `05-state-management.md` forbids a provider
      // modifying another one's state. It is also a top-level `final`
      // (`app_router.dart`), so E12's language switch cannot rebuild it.
      routerConfig: appRouter,
      onGenerateTitle: (BuildContext context) =>
          AppLocalizations.of(context).appTitle,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      // ⚠️ `localeListResolutionCallback`, **never** `localeResolutionCallback`:
      // the latter sees only the first preferred locale, so `fr_CA` would never
      // reach `fr` by language code and B28's French fallback would only apply to
      // the crudest cases.
      localeListResolutionCallback: _resolveLocale,
      theme: AppTheme.day(),
      darkTheme: AppTheme.night(),
      // `themeMode` is deliberately absent, so it is `ThemeMode.system` and the
      // phone's setting is honoured (E13). `themeOverride` — B26's explicit
      // permission for an in-app override — is applied by `2-8`, which reads the
      // provider this bootstrap overrides.
    );
  }
}

/// **B28's fallback chain.** French is this project's primary locale, so an
/// unrecognised system locale resolves to French rather than silently falling back
/// to the ARB template (`en`).
///
/// Unchanged from the pre-`0-5` bootstrap, and it stays here on purpose:
/// `16-i18n.md` rule 5 names this function and this file, and
/// `architecture.md` § 3.1a says the router keeps the existing
/// `localeListResolutionCallback`. Moving it into `app/` would violate a named rule
/// for no gain.
Locale _resolveLocale(
  Iterable<Locale>? preferredLocales,
  Iterable<Locale> supportedLocales,
) {
  for (final Locale preferred in preferredLocales ?? const <Locale>[]) {
    for (final Locale supported in supportedLocales) {
      // ⚠️ **By language code, never by string equality.** `"fr_CA"` does not equal
      // `Locale('fr')`, and comparing the whole string is exactly the mistake that
      // would send Canadian French to the English ARB template.
      if (preferred.languageCode == supported.languageCode) {
        return supported;
      }
    }
  }
  return const Locale('fr');
}

/// Exposed for `test/app/router/app_router_test.dart`.
///
/// The function is **byte for byte** the one above, unchanged since the
/// localisation bootstrap, and it is exported rather than duplicated: a test that
/// re-implements it would assert a copy, and a copy is free to drift.
@visibleForTesting
Locale resolveLocaleForTesting(
  Iterable<Locale>? preferredLocales,
  Iterable<Locale> supportedLocales,
) => _resolveLocale(preferredLocales, supportedLocales);
