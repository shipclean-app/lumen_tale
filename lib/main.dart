import 'package:flutter/material.dart';

import 'package:lumen_tale/l10n/generated/app_localizations.dart';

/// Bootstrap for Lumen Tale.
///
/// This file wires localization and the theme shell only. Features, routing,
/// and the layered directories described in `02-architecture.md` do not exist
/// yet — do not read this as the finished app.
void main() {
  runApp(const LumenTaleApp());
}

/// Root widget.
///
/// Theme tokens live in `app/theme/` per `14-design-tokens.md`; that
/// directory is not created yet, so the two schemes below are the seed the
/// token layer will replace. Keep this file free of feature logic.
class LumenTaleApp extends StatelessWidget {
  const LumenTaleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      localeListResolutionCallback: _resolveLocale,
      theme: _theme(Brightness.light),
      darkTheme: _theme(Brightness.dark),
    );
  }

  ThemeData _theme(Brightness brightness) {
    return ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF4A5D9E),
        brightness: brightness,
      ),
    );
  }
}

/// French is this project's primary locale, so an unsupported system locale
/// resolves to French rather than silently falling back to the ARB template
/// (`16-i18n.md` rule 5).
Locale _resolveLocale(
  Iterable<Locale>? preferredLocales,
  Iterable<Locale> supportedLocales,
) {
  for (final Locale preferred in preferredLocales ?? const <Locale>[]) {
    for (final Locale supported in supportedLocales) {
      if (preferred.languageCode == supported.languageCode) {
        return supported;
      }
    }
  }
  return const Locale('fr');
}
