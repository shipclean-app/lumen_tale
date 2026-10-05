// Lumen Tale — theme assembly. The one place a `ThemeData` is built.
//
// `design-system.md` § 1.8 (the Flutter mapping) and `14-design-tokens.md`.
//
// § 3.4 is the nuance that matters here, and it is a trap rather than a detail:
// `ColorScheme.fromSeed` supplies the Material 3 **roles** and nothing else. It
// does NOT supply `error`, `warning`, `info` or `success`, and it has no notion of
// `surfaceRaised`/`surfaceSunken` or of the three border tokens — those are
// components, not roles.
//
// `error` is the decisive one: a seed-derived `error` would come out of the amber
// and land on the red-orange that collides with the accent, which § 0.3 of the
// design system refuses outright. So the semantic colours and both raised/sunken
// surfaces are copied from `LumenColors` after the seed has done its work.

import 'package:flutter/material.dart';

import 'package:lumen_tale/app/theme/lumen_colors.dart';
import 'package:lumen_tale/app/theme/lumen_radius.dart';
import 'package:lumen_tale/app/theme/lumen_spacing.dart';
import 'package:lumen_tale/app/theme/motion.dart';
import 'package:lumen_tale/app/theme/reader_scale.dart';
import 'package:lumen_tale/app/theme/shadows.dart';

abstract final class AppTheme {
  /// The seed both themes derive from: the day accent.
  ///
  /// `ColorScheme.fromSeed` then produces `primary`, `onPrimary`, `secondary`,
  /// `surface`, `outline` and friends. It is given the **day** accent in both
  /// themes so the two schemes share one derivation, and everything that must
  /// differ is overridden in [_build].
  static const Color _seed = Color(0xFF8A4B12);

  /// Warm paper.
  static ThemeData day() => _build(LumenColors.day(), Brightness.light);

  /// Cold ink.
  static ThemeData night() => _build(LumenColors.night(), Brightness.dark);

  static ThemeData _build(LumenColors tokens, Brightness brightness) {
    // ⚠️ `brightness` MUST be passed to `fromSeed`.
    //
    // `ColorScheme.fromSeed` derives `brightness` from the seed's own luminance,
    // and the seed is the **day** amber in both themes — so without this argument
    // `AppTheme.night()` returned a scheme reporting `Brightness.light`, and every
    // consumer of `Theme.of(context).brightness` was wrong while the colours looked
    // correct. The tokens said night; the scheme said day; nothing complained.
    //
    // This is the same failure shape as `http-client`'s dropped User-Agent: a
    // default that silently disagrees with the thing it configures. Found by the
    // E13 row, which asked whether the chrome re-themed and got "no" for the
    // wrong reason.
    final seedScheme = ColorScheme.fromSeed(
      seedColor: _seed,
      brightness: brightness,
    );

    // ⚠️ § 3.4. `error` / `warning` / `info` / `success` are NOT roles the seed
    // provides, and the surface containers and border tokens are not roles at all.
    // Each one is taken from `LumenColors` rather than left to the seed, because a
    // seed-derived `error` is exactly the accent collision § 0.3 forbids.
    final scheme = seedScheme.copyWith(
      primary: tokens.accent,
      onPrimary: tokens.textInverse,
      error: tokens.error,
      surface: tokens.background,
      onSurface: tokens.textPrimary,
      // `surfaceContainer*` are Material 3's elevation roles. `surfaceRaised` and
      // `surfaceSunken` are the product's own two steps, and they are the ones
      // widgets read — the container roles are mapped so nothing falls back to the
      // seed's grey.
      surfaceContainerLowest: tokens.surfaceSunken,
      surfaceContainerLow: tokens.surfaceSunken,
      surfaceContainer: tokens.surface,
      surfaceContainerHigh: tokens.surfaceRaised,
      surfaceContainerHighest: tokens.surfaceRaised,
      outline: tokens.borderField,
      outlineVariant: tokens.border,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      // ⚠️ `ThemeData.brightness` is **not** set. It is derived from the scheme,
      // so there is exactly one source of truth for "which theme is this" —
      // passing both would be a second one, free to disagree.
      scaffoldBackgroundColor: tokens.background,
      canvasColor: tokens.surface,
      dividerColor: tokens.border,
      focusColor: tokens.borderFocus,
      splashFactory: InkSparkle.splashFactory,

      textTheme: _textTheme(tokens),

      extensions: <ThemeExtension<dynamic>>[
        tokens,
        LumenSpacing.standard(),
        LumenRadius.standard(),
        LumenShadows.standard(),
        LumenMotion.standard(),
        LumenReaderProse.standard(),
      ],
    );
  }

  /// The chrome type. Material 3 slots only — **no `fontSize` is written in a
  /// widget anywhere in this app**, which is `14-design-tokens.md` §Typography.
  ///
  /// The reader's prose is deliberately absent: it is [resolveProse]'s job, and
  /// putting a prose size in a Material slot would give the reader two ways to
  /// change the same text.
  static TextTheme _textTheme(LumenColors tokens) {
    final base = ThemeData.light(useMaterial3: true).textTheme;
    return base.copyWith(
      bodyLarge: base.bodyLarge?.copyWith(color: tokens.textPrimary),
      bodyMedium: base.bodyMedium?.copyWith(color: tokens.textPrimary),
      bodySmall: base.bodySmall?.copyWith(color: tokens.textSecondary),
      labelLarge: base.labelLarge?.copyWith(color: tokens.textPrimary),
      labelMedium: base.labelMedium?.copyWith(color: tokens.textSecondary),
      labelSmall: base.labelSmall?.copyWith(color: tokens.textDisabled),
      titleLarge: base.titleLarge?.copyWith(color: tokens.textPrimary),
      titleMedium: base.titleMedium?.copyWith(color: tokens.textPrimary),
      titleSmall: base.titleSmall?.copyWith(color: tokens.textSecondary),
    );
  }
}
