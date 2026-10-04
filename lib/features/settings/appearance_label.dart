// Lumen Tale — `Day · Medium (18pt)`, the value line on Settings' appearance row.
//
// ## Why this is its own file and not a method on the screen
//
// The row joins **three** facts — the theme, the size *step*, and the point size that
// step *resolves to* — and the third is `settings-reader.md`'s, not this screen's.
//
// `ReaderTextScale` carries a pair (prose, UI) per step, and the number a reader would
// call "my text size" is neither. It is the step's own figure, so the mapping lives
// beside the enum: a screen that repeated the table would be a **second place that
// knows what "Medium" means**, and the two would be free to disagree about the reader's
// text size — which is the one value on the page a reader is most likely to trust.

import 'package:lumen_tale/app/theme/reader_scale.dart';
import 'package:lumen_tale/app/theme/theme_override.dart';
import 'package:lumen_tale/l10n/generated/app_localizations.dart';

/// `Day · Medium (18pt)`.
///
/// ⚠️ **All three parts are localized, and none of them is a Dart `name`.**
/// `ThemeOverride.day` in a French sentence is a string the app learned from its own
/// code, and `Medium` is a word with an article.
String appearanceLabel(
  AppLocalizations l10n,
  ThemeOverride theme,
  ReaderTextScale scale,
) {
  final String themeName = switch (theme) {
    ThemeOverride.system => l10n.settingsThemeSystem,
    ThemeOverride.day => l10n.settingsThemeDay,
    ThemeOverride.night => l10n.settingsThemeNight,
  };
  final String sizeName = switch (scale) {
    ReaderTextScale.sm => l10n.settingsSizeSm,
    ReaderTextScale.md => l10n.settingsSizeMd,
    ReaderTextScale.lg => l10n.settingsSizeLg,
    ReaderTextScale.xl => l10n.settingsSizeXl,
    ReaderTextScale.xxl => l10n.settingsSizeXxl,
  };
  return l10n.settingsRowAppearanceValue(
    themeName,
    sizeName,
    pointSizeOf(scale).toString(),
  );
}

/// The point size a step *is*, for the value line.
///
/// ⚠️ **The step's own figure, not the prose scale and not the UI scale.** A row
/// reading *"Medium (27 pt)"* while the reader sees 18 pt in the chapter would report a
/// text size the reader can disprove on the next screen — and the row's whole purpose
/// is to be checked against something.
///
/// The mapping is `step: 16 / 18 / 20 / 22 / 24`, declared here because
/// `settings-reader.md`'s ladder is the ladder's owner and this is the one place that
/// has to *print* it. A row asserts each step's figure.
int pointSizeOf(ReaderTextScale scale) => switch (scale) {
  ReaderTextScale.sm => 16,
  ReaderTextScale.md => 18,
  ReaderTextScale.lg => 20,
  ReaderTextScale.xl => 22,
  ReaderTextScale.xxl => 24,
};
