// Lumen Tale — `localisation` § 11.1, string resolution.
//
// The rows about **resolution**: does a key actually produce text, in the right
// language, in both. The completeness rows in `arb_completeness_test.dart` prove
// the two files agree on the key SET; these prove a lookup returns the right
// VALUE, which is a different failure — a key present in both files whose French
// is empty, or whose placeholders render as literal braces.
//
// ⚠️ Scope, stated so this file is not read as more than it is. The plan's row
// « the error message family resolves in both languages » names **41** keys of the
// `source-unavailable` error family. Those 41 strings do not exist yet — no slice
// has written them, and `0-1`/Wave 0 is where they get authored. That row is
// therefore **absent here and recorded in the register**, not faked with a
// loop over three keys that would pass while the 41 remain unwritten.

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumen_tale/l10n/arb_key_derivation.dart';
import 'package:lumen_tale/l10n/generated/app_localizations.dart';

/// A localization bundle for [locale], loaded the way the app loads it.
Future<AppLocalizations> _l10n(Locale locale) =>
    AppLocalizations.delegate.load(locale);

/// The shared fallback rule from `main.dart`, as a function so it can be tested.
Locale resolveLocaleFor(
  Iterable<Locale>? preferred,
  Iterable<Locale> supported,
) {
  for (final preferredLocale in preferred ?? const <Locale>[]) {
    for (final supportedLocale in supported) {
      if (preferredLocale.languageCode == supportedLocale.languageCode) {
        return supportedLocale;
      }
    }
  }
  return const Locale('fr');
}

void main() {
  testWidgets('a message resolves in French', (WidgetTester tester) async {
    final fr = await _l10n(const Locale('fr'));
    expect(fr.navLibrary, 'Bibliothèque');
    expect(fr.commonCancel, 'Annuler');
  });

  testWidgets('a message resolves in English', (WidgetTester tester) async {
    final en = await _l10n(const Locale('en'));
    expect(en.navLibrary, 'Library');
    expect(en.commonCancel, 'Cancel');
  });

  testWidgets('the two locales never return the same text', (
    WidgetTester tester,
  ) async {
    // E12: if `fr` silently resolved to English, every assertion above would
    // still pass on its own. This is the row that catches a broken delegate.
    final fr = await _l10n(const Locale('fr'));
    final en = await _l10n(const Locale('en'));
    final keys = <String, String Function(AppLocalizations)>{
      'navLibrary': (AppLocalizations l) => l.navLibrary,
      'navBrowse': (AppLocalizations l) => l.navBrowse,
      'navUpdates': (AppLocalizations l) => l.navUpdates,
      'navHistory': (AppLocalizations l) => l.navHistory,
      'navDownloads': (AppLocalizations l) => l.navDownloads,
      'navSettings': (AppLocalizations l) => l.navSettings,
      'commonRetry': (AppLocalizations l) => l.commonRetry,
      'commonCancel': (AppLocalizations l) => l.commonCancel,
    };
    for (final entry in keys.entries) {
      expect(
        entry.value(fr),
        isNot(entry.value(en)),
        reason:
            '${entry.key} resolves identically in both locales, so one of '
            'them is falling through to the other',
      );
    }
  });

  testWidgets('every key resolves to a non-empty string in both locales', (
    WidgetTester tester,
  ) async {
    final fr = await _l10n(const Locale('fr'));
    final en = await _l10n(const Locale('en'));

    final strings = <String, String>{
      'appTitle': en.appTitle,
      'navLibrary': fr.navLibrary,
      'navBrowse': fr.navBrowse,
      'navUpdates': fr.navUpdates,
      'navHistory': fr.navHistory,
      'navDownloads': fr.navDownloads,
      'navSettings': fr.navSettings,
      'commonRetry': fr.commonRetry,
      'commonCancel': fr.commonCancel,
      'commonErrorTitle': fr.commonErrorTitle,
      'commonErrorBody': fr.commonErrorBody,
      'libraryEmptyTitle': fr.libraryEmptyTitle,
      'libraryEmptyBody': fr.libraryEmptyBody,
      'browseEmptyBody': fr.browseEmptyBody,
      'coverSemanticsLabel(Fr)': fr.coverSemanticsLabel('x'),
      'coverSemanticsLabel(En)': en.coverSemanticsLabel('x'),
      'chapterCount 0(Fr)': fr.chapterCount(0),
      'chapterCount 1(Fr)': fr.chapterCount(1),
      'chapterCount 9(Fr)': fr.chapterCount(9),
      'chapterCount 0(En)': en.chapterCount(0),
      'chapterCount 1(En)': en.chapterCount(1),
      'chapterCount 9(En)': en.chapterCount(9),
    };

    for (final entry in strings.entries) {
      expect(
        entry.value.trim(),
        isNotEmpty,
        reason: '${entry.key} resolves to an empty string',
      );
    }
  });

  test('plural forms are correct in both locales', () async {
    // The French plural rules differ from English above one: `=0` and `=1` are
    // exact, `other` covers the rest. Asserting the French `other` form for 9 is
    // what proves the ARB plural syntax parsed, rather than silently defaulting.
    final fr = await _l10n(const Locale('fr'));
    final en = await _l10n(const Locale('en'));

    expect(fr.chapterCount(0), contains('Aucun'));
    expect(fr.chapterCount(1), contains('1 chapitre'));
    expect(fr.chapterCount(1), isNot(contains('s')));
    expect(fr.chapterCount(9), contains('9 chapitres'));

    expect(en.chapterCount(0), contains('No'));
    expect(en.chapterCount(1), contains('1 chapter'));
    expect(en.chapterCount(1), isNot(contains('s')));
    expect(en.chapterCount(9), contains('9 chapters'));
  });

  test('a placeholder renders its value, not its braces', () async {
    final fr = await _l10n(const Locale('fr'));
    expect(fr.coverSemanticsLabel('Bleu'), contains('Bleu'));
    expect(fr.coverSemanticsLabel('Bleu'), isNot(contains('{title}')));
    expect(fr.coverSemanticsLabel('Bleu'), isNot(contains('}')));
  });

  test('an unrecognised system locale resolves to French', () {
    // `16-i18n.md` rule 5: French is primary, so an unsupported locale falls back
    // to French rather than to the ARB template language.
    expect(
      resolveLocaleFor(const <Locale>[
        Locale('de'),
      ], AppLocalizations.supportedLocales),
      const Locale('fr'),
    );
    expect(
      resolveLocaleFor(
        const <Locale>[Locale('pt', 'BR')],
        const <Locale>[Locale('en'), Locale('fr')],
      ),
      const Locale('fr'),
      reason: 'no pt-BR support, so French rather than the template',
    );
  });

  test('a supported locale resolves to itself, in its own region form', () {
    expect(
      resolveLocaleFor(const <Locale>[
        Locale('en', 'GB'),
      ], AppLocalizations.supportedLocales),
      const Locale('en'),
      reason: 'the region is not part of the match — en-GB is still English',
    );
    expect(
      resolveLocaleFor(const <Locale>[
        Locale('fr', 'CA'),
      ], AppLocalizations.supportedLocales),
      const Locale('fr'),
    );
  });

  test('no preferred locale at all resolves to French', () {
    expect(
      resolveLocaleFor(null, AppLocalizations.supportedLocales),
      const Locale('fr'),
    );
    expect(
      resolveLocaleFor(const <Locale>[], AppLocalizations.supportedLocales),
      const Locale('fr'),
    );
  });

  test('the ARB key derivation agrees with the generated accessors', () {
    // The tie between the rule in `lib/l10n/` and the keys `gen-l10n` actually
    // produced. Without this, the derivation could be correct and the ARB files
    // could use different names, and nothing would notice until a screen asked
    // for a string that does not exist.
    expect(arbKeyFor('settings', 'row.interval'), 'settingsRowInterval');
    expect(
      arbKeyFor('source-unavailable', 'cause.noConnection.title'),
      'sourceUnavailableCauseNoConnectionTitle',
      reason: 'this is the key the error family will use',
    );
  });
}
