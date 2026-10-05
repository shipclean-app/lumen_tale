// Lumen Tale — byte sizes, formatted.
//
// ## ⚠️ THE UNIT IS LOCALIZED AND THE NUMBER NEVER IS
//
// A snackbar that says "41 Ko" to a reader whose phone is set to English is a sentence the
// app got wrong about itself, and the *value* is the same everywhere. So only the unit comes
// from the ARB; the count is formatted with `intl` so the grouping separators match the
// locale too.
//
// ## ⚠️ IT IS NOT A PERCENTAGE, AND IT NEVER GUESSES A UNIT
//
// E20 forbids an estimated size, and this is the function that would print one. It formats
// **exactly** the bytes it is given: 41 003 bytes is `41 KB`, never "about 40 KB". There is
// no rounding hint and no `~` — a size the app cannot state exactly should not reach a reader
// through this door, and E20's refusal path is the other door.

import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';
import 'package:lumen_tale/l10n/generated/app_localizations.dart';

/// Formats [bytes] with the largest unit that leaves a whole number ≥ 1, localized.
///
/// ⚠️ **1024, NOT 1000.** A KB here is a kibibyte, which is what a filesystem reports; a
/// reader comparing this to a file manager is comparing like with like, and mixing the two
/// bases makes "1 KB" mean two different sizes in two places in the same app.
String formatBytes(BuildContext context, int bytes) {
  final AppLocalizations l10n = AppLocalizations.of(context);
  final NumberFormat number = NumberFormat.decimalPattern(l10n.localeName);

  // ⚠️ **NEGATIVE BYTES ARE NOT A SIZE.** A subtraction that underflowed is a bug upstream;
  // printing it would put "-1 B" in a dialog about freeing space. Zero is a legitimate answer
  // — a genuinely empty chapter — so only negatives are clamped.
  final int value = bytes < 0 ? 0 : bytes;

  if (value < 1024) {
    return l10n.unitBytes(number.format(value));
  }
  if (value < 1024 * 1024) {
    return l10n.unitKilobytes(number.format(value ~/ 1024));
  }
  if (value < 1024 * 1024 * 1024) {
    return l10n.unitMegabytes(number.format(value ~/ (1024 * 1024)));
  }
  return l10n.unitGigabytes(number.format(value ~/ (1024 * 1024 * 1024)));
}

/// "The 479 other chapters", with the **plural form chosen by the number**.
///
/// ⚠️ **A PLURAL, NOT TWO STRINGS PICKED BY THE CALLER.** English needs two forms and so do
/// several other languages, and a caller that branches on `count > 1` gets French, Arabic and
/// Polish wrong in ways no test in this project would catch.
String describeSiblingCount(BuildContext context, int count) {
  final AppLocalizations l10n = AppLocalizations.of(context);
  return count == 1
      ? l10n.chapterCountSingular
      : l10n.chapterCountPlural(count);
}
