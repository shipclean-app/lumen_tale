// Lumen Tale — the sixteen colour tokens, two values each.
//
// `design-system.md` § 1.1.
//
// **One class, two sets of values — not two classes suffixed `_light`/`_dark`.**
// The design system explains why in § 1.1: written as two tables, every token
// name appears twice, `design-check contrast` resolves to the *last* occurrence
// and therefore measures only the night column, and `tokens-used` reports the day
// table as eighteen screens disagreeing with the design system — which is the
// file disagreeing with itself.

import 'package:flutter/material.dart';

@immutable
class LumenColors extends ThemeExtension<LumenColors> {
  const LumenColors({
    required this.background,
    required this.surface,
    required this.surfaceRaised,
    required this.surfaceSunken,
    required this.textPrimary,
    required this.textSecondary,
    required this.textDisabled,
    required this.textInverse,
    required this.accent,
    required this.success,
    required this.warning,
    required this.error,
    required this.info,
    required this.border,
    required this.borderField,
    required this.borderFocus,
    required this.borderStrong,
  });

  /// § 1.1, Day column. `--color-background` is warm paper `#F5F2ED`, and **never**
  /// `#FFFFFF`: pure white is an anonymous default, not a choice.
  factory LumenColors.day() => const LumenColors(
    background: Color(0xFFF5F2ED),
    surface: Color(0xFFFBF9F6),
    surfaceRaised: Color(0xFFFEFCF9),
    surfaceSunken: Color(0xFFEBE7E0),
    textPrimary: Color(0xFF1A1714),
    textSecondary: Color(0xFF5A524A),
    textDisabled: Color(0xFF6E665C),
    textInverse: Color(0xFFFDFAF6),
    accent: Color(0xFF8A4B12),
    success: Color(0xFF40713A),
    warning: Color(0xFF8A5A12),
    error: Color(0xFF8A3228),
    info: Color(0xFF426986),
    border: Color(0xFFD9D3C9),
    borderField: Color(0xFF8F8778),
    borderFocus: Color(0xFF8A4B12),
    borderStrong: Color(0xFF6B645E),
  );

  /// § 1.1, Night column. **Cold** field, **warm** text — ADR-016.
  ///
  /// ⚠️ This is a constant, NOT `day().lerp(null, 1)` and NOT a `copyWith` of the
  /// four surfaces. § 3.3 records that seven tokens are *inverted* between the two
  /// columns — `error` most of all — so deriving one column from the other would
  /// make the night error unreadable. All sixteen values are written out, and a
  /// test compares them field by field against § 1.1, because the only way to
  /// introduce a third value by accident is to write one in terms of the other.
  factory LumenColors.night() => const LumenColors(
    background: Color(0xFF121315),
    surface: Color(0xFF1A1C1F),
    surfaceRaised: Color(0xFF232629),
    surfaceSunken: Color(0xFF0C0D0F),
    textPrimary: Color(0xFFE8E4DD),
    textSecondary: Color(0xFFA8A29A),
    textDisabled: Color(0xFF948E87),
    textInverse: Color(0xFF17181A),
    accent: Color(0xFFE3A857),
    success: Color(0xFF7FBE72),
    warning: Color(0xFFE0AC47),
    error: Color(0xFFEE8B76),
    info: Color(0xFF7FB3DA),
    border: Color(0xFF2E3237),
    borderField: Color(0xFF6B6560),
    borderFocus: Color(0xFFE3A857),
    borderStrong: Color(0xFF8A8885),
  );

  final Color background;
  final Color surface;
  final Color surfaceRaised;
  final Color surfaceSunken;
  final Color textPrimary;
  final Color textSecondary;
  final Color textDisabled;
  final Color textInverse;
  final Color accent;
  final Color success;
  final Color warning;
  final Color error;
  final Color info;

  /// `exempt` in the sense of § 0.0: a decorative rule between two list rows. It
  /// carries no information and is not a component boundary, so WCAG 1.4.11 does
  /// not apply. **Not promoted to `nontext` to make it measurable** — measuring it
  /// would require lying about what it is.
  final Color border;

  /// Component boundaries: WCAG 1.4.11, threshold 3:1.
  final Color borderField;
  final Color borderFocus;
  final Color borderStrong;

  /// Read as `Theme.of(context).extension<LumenColors>()!`.
  ///
  /// A missing extension is a registration bug, never an acceptable fallback
  /// value: the `!` makes it loud instead of silent.
  static LumenColors of(BuildContext context) =>
      Theme.of(context).extension<LumenColors>()!;

  @override
  LumenColors copyWith({
    Color? background,
    Color? surface,
    Color? surfaceRaised,
    Color? surfaceSunken,
    Color? textPrimary,
    Color? textSecondary,
    Color? textDisabled,
    Color? textInverse,
    Color? accent,
    Color? success,
    Color? warning,
    Color? error,
    Color? info,
    Color? border,
    Color? borderField,
    Color? borderFocus,
    Color? borderStrong,
  }) {
    return LumenColors(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceRaised: surfaceRaised ?? this.surfaceRaised,
      surfaceSunken: surfaceSunken ?? this.surfaceSunken,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textDisabled: textDisabled ?? this.textDisabled,
      textInverse: textInverse ?? this.textInverse,
      accent: accent ?? this.accent,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      error: error ?? this.error,
      info: info ?? this.info,
      border: border ?? this.border,
      borderField: borderField ?? this.borderField,
      borderFocus: borderFocus ?? this.borderFocus,
      borderStrong: borderStrong ?? this.borderStrong,
    );
  }

  /// Interpolation required by `ThemeExtension`.
  ///
  /// It serves exactly **one** real case: the shell's theme transition
  /// (`AnimatedTheme`). It interpolates in Flutter's ARGB space, which is not
  /// perceptually uniform — acceptable here because no theme animation outlasts
  /// `--duration-normal`, so the mixture is never actually seen.
  @override
  LumenColors lerp(covariant LumenColors? other, double t) {
    if (other == null) return this;
    return LumenColors(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceRaised: Color.lerp(surfaceRaised, other.surfaceRaised, t)!,
      surfaceSunken: Color.lerp(surfaceSunken, other.surfaceSunken, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textDisabled: Color.lerp(textDisabled, other.textDisabled, t)!,
      textInverse: Color.lerp(textInverse, other.textInverse, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      error: Color.lerp(error, other.error, t)!,
      info: Color.lerp(info, other.info, t)!,
      border: Color.lerp(border, other.border, t)!,
      borderField: Color.lerp(borderField, other.borderField, t)!,
      borderFocus: Color.lerp(borderFocus, other.borderFocus, t)!,
      borderStrong: Color.lerp(borderStrong, other.borderStrong, t)!,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LumenColors &&
          runtimeType == other.runtimeType &&
          background == other.background &&
          surface == other.surface &&
          surfaceRaised == other.surfaceRaised &&
          surfaceSunken == other.surfaceSunken &&
          textPrimary == other.textPrimary &&
          textSecondary == other.textSecondary &&
          textDisabled == other.textDisabled &&
          textInverse == other.textInverse &&
          accent == other.accent &&
          success == other.success &&
          warning == other.warning &&
          error == other.error &&
          info == other.info &&
          border == other.border &&
          borderField == other.borderField &&
          borderFocus == other.borderFocus &&
          borderStrong == other.borderStrong;

  @override
  int get hashCode => Object.hash(
    background,
    surface,
    surfaceRaised,
    surfaceSunken,
    textPrimary,
    textSecondary,
    textDisabled,
    textInverse,
    accent,
    success,
    warning,
    error,
    info,
    border,
    borderField,
    borderFocus,
    borderStrong,
  );
}
