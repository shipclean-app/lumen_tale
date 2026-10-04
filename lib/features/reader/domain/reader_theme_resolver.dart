// forge:slice 2-8
// Lumen Tale — B26's two moving parts: the order of the three themes, and nothing else.
//
// ## ⚠️ There is deliberately NO `resolveThemeMode` here, and that is the point
//
// The plan's § 2.2 prints one. § 2.2's **own table**, four lines above it, says
// `ThemeOverride` provides `resolve(Brightness)` and that it is *"the only place in the
// project that translates the override into a `ThemeMode`"*, and `theme_override.dart`
// says the same thing with a reason: *"two translations of one value are two answers to
// 'which night is it?'"*. Writing a second one here would satisfy the code block and
// contradict the table, the enum and the ADR that `0-5` already shipped against.
//
// So this file owns exactly what is genuinely not written down anywhere else: **the cycle
// order**, and the order the three segments appear in. `resolve` stays the only
// translation, and `main.dart` calls it.
//
// ## ⚠️ The cycle is NORMATIVE: day → night → system → day
//
// `settings-reader.md` § 11: *"the reader's `themeButton` cycles the same three values in
// the same order"* as the settings page's segments. `system` is where the cycle starts
// **only** because `fromStorage` resolves an absent key to it — the cycle itself is a
// ring, so wherever a reader is when they first tap, the three taps ahead are the same
// three values.

import 'package:lumen_tale/app/theme/theme_override.dart';

/// The next value the reader's `themeButton` selects.
///
/// ⚠️ **A closed ring over the three members, exhaustive with no `default`.** A fourth
/// member is a compile error here rather than a fourth behaviour nobody designed — the
/// same rule `13-error-handling.md` applies to its own closed enums.
ThemeOverride cycleThemeOverride(ThemeOverride current) => switch (current) {
  ThemeOverride.day => ThemeOverride.night,
  ThemeOverride.night => ThemeOverride.system,
  ThemeOverride.system => ThemeOverride.day,
};

/// The three segments, in the design's order: **follow the phone, day, night**.
///
/// ⚠️ **Different from the cycle's order, and that is not an inconsistency.** The cycle is
/// what one tap does; this is what the settings page shows left to right, and
/// `settings-reader.md` § 3 draws them `Follow the phone · Day · Night`. Two orders for
/// two different questions — but the same **members**, which is the part the reader can
/// check.
const List<ThemeOverride> themeOverrideOrder = <ThemeOverride>[
  ThemeOverride.system,
  ThemeOverride.day,
  ThemeOverride.night,
];
