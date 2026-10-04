// Lumen Tale — `Day · Medium (18pt)`, the value line on Settings' appearance row.
//
// ## Why this is its own file and not a method on the screen
//
// The row joins **three** facts — the theme, the size *step*, and the point size that
// step *resolves to* — and none of the three is this screen's to decide.
//
// ## ⚠️ The mapping now lives in `app/theme/reader_display_copy.dart`, and it used to live here
//
// `settings-reader.md` § 2.1 calls this screen and the reader's `sizeButton` **two doors
// to one value**, and the two files each carried their own `switch` over `ThemeOverride`
// and `ReaderTextScale`. Two switches over one enum are two truths about what "Medium"
// means, and `2-8`'s size sheet needed a third copy that could not be written here —
// `02-architecture.md` forbids importing another feature, so the reader's copy would have
// had to be a duplicate by force of the architecture rather than by accident.
//
// The words therefore moved to the layer both features may import, and this file keeps
// only the composition that is genuinely Settings' own: `theme · size (N pt)`.

import 'package:lumen_tale/app/theme/reader_display_copy.dart';
import 'package:lumen_tale/app/theme/reader_scale.dart';
import 'package:lumen_tale/app/theme/theme_override.dart';
import 'package:lumen_tale/l10n/generated/app_localizations.dart';

/// `Day · Medium (18pt)`.
///
/// ⚠️ **All three parts are localized, and none of them is a Dart `name`.**
/// `ThemeOverride.day` in a French sentence is a string the app learned from its own
/// code, and `Medium` is a word with an article. Both names come from
/// `ReaderDisplayCopy`, so this row and the reader's `sizeButton` read the same words out
/// of the same switch.
String appearanceLabel(
  AppLocalizations l10n,
  ThemeOverride theme,
  ReaderTextScale scale,
) {
  return l10n.settingsRowAppearanceValue(
    l10n.themeLabel(theme),
    l10n.readerSizeLabel(scale),
    pointSizeOf(scale).toString(),
  );
}
