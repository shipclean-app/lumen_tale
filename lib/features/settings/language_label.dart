// Lumen Tale — the `Language` row's value, and why it is a `switch`.
//
// ## The row is READ-ONLY, so there is no picker to disagree with
//
// B28: the app follows the phone, and an unrecognised system locale resolves to French
// (`main.dart`'s `_resolveLocale`). The row therefore reports *the phone's language*,
// and the only two the phone can be in — by the time this row renders — are English and
// French.
//
// ## Why a `switch` and not a lookup table
//
// The tempting version is a `Map<Locale, String>` from `supportedLocales`. That is a
// **second source of truth** for the same fact, and it would be free to disagree with
// the ARB: adding a third language would need a map entry, an ARB pair, and a reviewer to
// notice the two lists matched. A `switch` over the language code makes the ARB pair the
// only place a name lives, and makes an unhandled code a compile error rather than a
// blank value line.

import 'package:flutter/widgets.dart';
import 'package:lumen_tale/l10n/generated/app_localizations.dart';

/// The name the phone's language goes by **in that language**.
///
/// ⚠️ **`Français` in the English file too, and `English` in the French one.** That looks
/// like a mistake and is the opposite: the row says what the *phone* is set to, and a
/// reader reading an English UI with a French phone should see *Français*. Both strings
/// are therefore identical in both files, which is why they live here and not as an
/// ordinary `settings.*` key pair a translator would helpfully localize.
String languageLabel(AppLocalizations l10n, Locale locale) {
  return switch (locale.languageCode) {
    'en' => l10n.settingsLanguageEnglish,
    'fr' => l10n.settingsLanguageFrench,
    // ⚠️ **Unreachable, and it is still answered.** `main.dart`'s chain resolves an
    // unrecognised locale to `fr` before any route exists, so this arm cannot fire in
    // the app — but a `switch` with no default on a `String` is a non-exhaustive
    // statement, and the alternative (a fallback that guesses) is the thing this file
    // argues against.
    _ => l10n.settingsLanguageFrench,
  };
}
