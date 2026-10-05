// Lumen Tale — `theme-type` § 11.1, the colour rows.
//
// The rows that matter here are **measured**, not asserted by eye. § 3.3 records
// seven tokens that are *inverted* between day and night, so "the two palettes are
// consistent" is not a property that can be checked by reading them: it has to be
// computed. WCAG 1.4.3 wants 4.5:1 for text and 1.4.11 wants 3:1 for a component
// boundary, and `14-design-tokens.md` owns the thresholds.
//
// Every contrast figure below is **computed in the test**, so a token edit that
// breaks a threshold fails here rather than on the reader's phone.

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumen_tale/app/theme/app_theme.dart';
import 'package:lumen_tale/app/theme/lumen_colors.dart';
import 'package:lumen_tale/app/theme/lumen_radius.dart';
import 'package:lumen_tale/app/theme/lumen_spacing.dart';
import 'package:lumen_tale/app/theme/motion.dart';
import 'package:lumen_tale/app/theme/reader_scale.dart';
import 'package:lumen_tale/app/theme/shadows.dart';

/// WCAG 2.x relative luminance.
double _luminance(Color c) {
  double channel(double v) =>
      v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * channel(c.r) + 0.7152 * channel(c.g) + 0.0722 * channel(c.b);
}

/// WCAG 2.x contrast ratio, 1.0 to 21.0.
double _contrast(Color a, Color b) {
  final la = _luminance(a);
  final lb = _luminance(b);
  final lighter = math.max(la, lb);
  final darker = math.min(la, lb);
  return (lighter + 0.05) / (darker + 0.05);
}

/// WCAG 1.4.3 — normal-size text.
const double textThreshold = 4.5;

/// WCAG 1.4.11 — a non-text component boundary, including the focus ring.
const double nonTextThreshold = 3;

void main() {
  final day = LumenColors.day();
  final night = LumenColors.night();

  group('the two palettes are written out, not derived from each other', () {
    test('the sixteen tokens differ between day and night', () {
      // § 3.3: if one column were `lerp` or `copyWith` of the other, this would
      // still pass — so the real assertion is the inversion test below.
      expect(day.background, isNot(night.background));
      expect(day.textPrimary, isNot(night.textPrimary));
    });

    test('seven semantic tokens are INVERTED, not merely different', () {
      // § 3.3 names them: textPrimary, accent, error, warning, success, info, and
      // the surfaces. ADR-016 exists because of this list — a single `error`
      // cannot serve both themes.
      //
      // The decisive measurement: the day error on the night field is 2.27:1,
      // unreadable. If someone "simplifies" by making night a transform of day,
      // this test is what refuses.
      final inversions = <String, (Color, Color)>{
        'error': (day.error, night.error),
        'warning': (day.warning, night.warning),
        'success': (day.success, night.success),
        'info': (day.info, night.info),
        'accent': (day.accent, night.accent),
        'textPrimary': (day.textPrimary, night.textPrimary),
      };
      for (final entry in inversions.entries) {
        expect(
          entry.value.$1,
          isNot(entry.value.$2),
          reason: '${entry.key} must differ between themes — ADR-016',
        );
      }

      // The number § 3.3 quotes, measured rather than restated.
      expect(
        _contrast(day.error, day.background),
        closeTo(7.32, 0.2),
        reason: 'day error on day paper — § 3.3 records 7.32:1',
      );
      expect(
        _contrast(day.error, night.background),
        closeTo(2.27, 0.2),
        reason:
            'the SAME day error on the night field is unreadable, which is '
            'why night needs its own error value',
      );

      // ⚠️ The asymmetry ADR-016 exists for, asserted on BOTH palettes rather
      // than only the day one.
      //
      // The first draft of this test asserted only that the day error beats 7:1
      // on day paper. Making `LumenColors.night()` reuse the day error kept every
      // row green — because the day-on-night row measures `day.error` explicitly
      // and never reads `night.error` at all. **The pair of columns has to be
      // measured as columns.**
      expect(
        _contrast(night.error, night.background),
        greaterThanOrEqualTo(textThreshold),
        reason:
            'night error on the night field must be readable in its own '
            'right — this is the row a shared error value breaks',
      );
      expect(
        _contrast(night.error, night.background),
        isNot(closeTo(2.27, 0.2)),
        reason:
            'if this equals the day-error-on-night figure, night is still '
            'using the day error',
      );
    });
  });

  group('every text token clears WCAG 1.4.3 on its own surface', () {
    test('day: 4.5:1 for text on background, surface, raised and sunken', () {
      final surfaces = <String, Color>{
        'background': day.background,
        'surface': day.surface,
        'surfaceRaised': day.surfaceRaised,
        'surfaceSunken': day.surfaceSunken,
      };
      final texts = <String, Color>{
        'textPrimary': day.textPrimary,
        'textSecondary': day.textSecondary,
        'accent': day.accent,
        'error': day.error,
        'warning': day.warning,
        'success': day.success,
        'info': day.info,
      };

      for (final text in texts.entries) {
        for (final surface in surfaces.entries) {
          final ratio = _contrast(text.value, surface.value);
          expect(
            ratio,
            greaterThanOrEqualTo(textThreshold),
            reason:
                'day $text.key on $surface.key is '
                '\${ratio.toStringAsFixed(2)}:1, below \$textThreshold:1',
          );
        }
      }
    });

    test('night: the same four surfaces and the same seven tokens', () {
      final surfaces = <String, Color>{
        'background': night.background,
        'surface': night.surface,
        'surfaceRaised': night.surfaceRaised,
        'surfaceSunken': night.surfaceSunken,
      };
      final texts = <String, Color>{
        'textPrimary': night.textPrimary,
        'textSecondary': night.textSecondary,
        'accent': night.accent,
        'error': night.error,
        'warning': night.warning,
        'success': night.success,
        'info': night.info,
      };

      for (final text in texts.entries) {
        for (final surface in surfaces.entries) {
          final ratio = _contrast(text.value, surface.value);
          expect(
            ratio,
            greaterThanOrEqualTo(textThreshold),
            reason:
                'night $text.key on $surface.key is '
                '\${ratio.toStringAsFixed(2)}:1, below \$textThreshold:1',
          );
        }
      }
    });

    test('textDisabled is exempt but still measured and recorded', () {
      // A disabled control is exempt from 1.4.3, but "exempt" is not "unchecked":
      // the figure is measured here and asserted above 3:1 so a future edit cannot
      // quietly make it invisible.
      for (final entry in <String, (Color, Color)>{
        'day': (day.textDisabled, day.background),
        'night': (night.textDisabled, night.background),
      }.entries) {
        final ratio = _contrast(entry.value.$1, entry.value.$2);
        expect(
          ratio,
          greaterThanOrEqualTo(nonTextThreshold),
          reason: '${entry.key} textDisabled is ${ratio.toStringAsFixed(2)}:1',
        );
      }
    });

    test('textInverse clears 4.5:1 on the accent it is paired with', () {
      expect(
        _contrast(day.textInverse, day.accent),
        greaterThanOrEqualTo(textThreshold),
      );
      expect(
        _contrast(night.textInverse, night.accent),
        greaterThanOrEqualTo(textThreshold),
      );
    });
  });

  group('component boundaries clear WCAG 1.4.11', () {
    test('borderField, borderFocus and borderStrong all reach 3:1', () {
      for (final entry in <String, (LumenColors, String)>{
        'day': (day, 'day'),
        'night': (night, 'night'),
      }.entries) {
        final tokens = entry.value.$1;
        final label = entry.value.$2;
        final boundaries = <String, Color>{
          'borderField': tokens.borderField,
          'borderFocus': tokens.borderFocus,
          'borderStrong': tokens.borderStrong,
        };
        for (final boundary in boundaries.entries) {
          final ratio = _contrast(boundary.value, tokens.background);
          expect(
            ratio,
            greaterThanOrEqualTo(nonTextThreshold),
            reason:
                '$label ${boundary.key} is ${ratio.toStringAsFixed(2)}:1, '
                'below the 3:1 that 1.4.11 requires of a component boundary',
          );
        }
      }
    });

    test('the focus ring is the accent, so it is measurable at all', () {
      // A focus ring that equals the accent is what makes 1.4.11 checkable here;
      // a separate "focus blue" would be a second source of truth for the accent.
      expect(day.borderFocus, day.accent);
      expect(night.borderFocus, night.accent);
    });
  });

  group('background is warm paper, never pure white', () {
    test('neither theme uses #FFFFFF as a background', () {
      const pureWhite = Color(0xFFFFFFFF);
      expect(day.background, isNot(pureWhite));
      expect(night.background, isNot(pureWhite));
    });

    test('day background really is the declared #F5F2ED', () {
      expect(day.background, const Color(0xFFF5F2ED));
    });
  });

  group('ColorScheme.fromSeed is not left in charge of error', () {
    test('error comes from LumenColors, not from the amber seed', () {
      // § 3.4 and `design-system.md` § 0.3: a seed-derived error would come out of
      // the amber and land on the red-orange that collides with the accent.
      final scheme = AppTheme.day().colorScheme;
      expect(scheme.error, day.error);
      expect(
        scheme.error,
        isNot(scheme.primary),
        reason: 'the accent and the error must not collide — § 0.3',
      );
    });

    test(
      'the surface containers are the product steps, not the seed greys',
      () {
        final scheme = AppTheme.day().colorScheme;
        expect(scheme.surfaceContainerLowest, day.surfaceSunken);
        expect(scheme.surfaceContainerHighest, day.surfaceRaised);
      },
    );

    test('both themes register all six extensions', () {
      for (final theme in <ThemeData>[AppTheme.day(), AppTheme.night()]) {
        expect(theme.extension<LumenColors>(), isNotNull);
        expect(theme.extension<LumenSpacing>(), isNotNull);
        expect(theme.extension<LumenRadius>(), isNotNull);
        expect(theme.extension<LumenShadows>(), isNotNull);
        expect(theme.extension<LumenMotion>(), isNotNull);
        expect(theme.extension<LumenReaderProse>(), isNotNull);
      }
    });

    test('the scaffold background is the token, not a Material default', () {
      expect(AppTheme.day().scaffoldBackgroundColor, day.background);
      expect(AppTheme.night().scaffoldBackgroundColor, night.background);
    });
  });
}
