// Lumen Tale — the WORDS for the two display settings, in one place.
//
// ## ⚠️ Why this file exists: `settings-reader.md` § 2.1, "two doors to one value"
//
// "Medium" is a word, and a word that two features spell separately is two truths about
// the reader's text size — which is the one value on the settings page a reader is most
// likely to check against the chapter they just opened. `appearance_label.dart` already
// carried the mapping, and `2-8`'s size sheet needs the same three names and the same
// three theme names. Importing it from `features/settings/` would be a **cross-feature
// import**, which `02-architecture.md` forbids and `tool/check_boundaries.py` fails on, so
// the mapping was neither duplicated in the reader nor reached across features: it moved
// to the layer both may import.
//
// `02-architecture.md` §Directory authorities puts theme assembly and tokens in
// `app/theme/`, and the reader's step and the app's override are the two values this file
// names. It is the one place a *label* for them can live.
//
// ## ⚠️ The point size is `step.fontSize`, and it was not always
//
// `appearance_label.dart`'s own header says a row reading *"Medium (27 pt)"* while the
// reader shows 18 px "would report a text size the reader can disprove on the next
// screen" — and its table printed `16 / 18 / 20 / 22 / 24` for a ladder that is
// `16 / 18 / 20 / 23 / 26`. The fifth and sixth rungs were two pixels low, so the Settings
// value line disagreed with the reader it claims to describe, and `2-8`'s size sheet would
// have had to choose between contradicting the reader and contradicting Settings.
//
// Deriving from [ReaderTextScale.fontSize] leaves no table to fall behind: the enum is the
// ladder's only owner, and this file only asks it for its figure.

import 'package:lumen_tale/app/theme/reader_scale.dart';
import 'package:lumen_tale/app/theme/theme_override.dart';
import 'package:lumen_tale/l10n/generated/app_localizations.dart';

/// The reader-facing names of the two display settings.
///
/// ⚠️ **An extension on [AppLocalizations], and not functions taking it.** E12: the locale
/// belongs to the phone, and a `String Function(AppLocalizations, …)` would let a caller
/// hold an English name while the app renders in French. The extension makes the locale a
/// property of the receiver, so a stale one is a type error rather than a screenshot.
extension ReaderDisplayCopy on AppLocalizations {
  /// `Small` … `Largest`.
  ///
  /// ⚠️ **From the enum's own members**, in declaration order, and exhaustive over
  /// [ReaderTextScale] — a sixth step is a compile error here rather than a step the
  /// reader cannot name.
  String readerSizeLabel(ReaderTextScale step) => switch (step) {
    ReaderTextScale.sm => settingsSizeSm,
    ReaderTextScale.md => settingsSizeMd,
    ReaderTextScale.lg => settingsSizeLg,
    ReaderTextScale.xl => settingsSizeXl,
    ReaderTextScale.xxl => settingsSizeXxl,
  };

  /// `Follow the phone` / `Day` / `Night`.
  String themeLabel(ThemeOverride value) => switch (value) {
    ThemeOverride.system => settingsThemeSystem,
    ThemeOverride.day => settingsThemeDay,
    ThemeOverride.night => settingsThemeNight,
  };
}

/// The point size a step *is* — the figure the reader compares with their phone's slider.
///
/// ⚠️ **`step.fontSize`, never a table.** See the file header: the previous table printed
/// 22 and 24 for the two largest steps, and the reader renders 23 and 26. The value line is
/// only worth anything while it agrees with the chapter.
int pointSizeOf(ReaderTextScale step) => step.fontSize.round();
