// Lumen Tale — `theme-type` § 11.1, the reader scale rows.
//
// B27 has **two** sources — the reader's step and the phone's font scale — and
// § 3.2 composes them. Every figure in § 3.2's table is reproduced here as a test,
// because the table is a specification and a specification nobody runs is a guess.

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumen_tale/app/theme/reader_scale.dart';

void main() {
  group('the five steps', () {
    test('they are 16, 18, 20, 23, 26 with the line heights § 1.2 tabulates', () {
      // The five pairs are `design-system.md` § 1.2's table, verbatim. The table
      // is the specification — a reader sees 27/31/34/39/44, not a ratio.
      expect(
        ReaderTextScale.values.map((ReaderTextScale s) => s.fontSize),
        <double>[16, 18, 20, 23, 26],
      );
      expect(
        ReaderTextScale.values.map((ReaderTextScale s) => s.lineHeight),
        <double>[27, 31, 34, 39, 44],
      );
    });

    test('the reading rhythm is constant within 0.04, not exactly 1.72', () {
      // ⚠️ § 1.2 states 1.72 in prose AND tabulates five pairs that are 1.6875,
      // 1.7222, 1.7000, 1.6957 and 1.6923. Both are in the design system and they
      // disagree. The table wins — it is what renders — so this asserts the SPREAD
      // rather than a figure the table refutes.
      //
      // A first draft asserted `closeTo(1.72, 0.01)` per step and failed on three
      // of five. Writing 1.72 to make it pass would have meant editing the table to
      // match the prose, which is rewriting the design system to fit a test.
      final ratios = ReaderTextScale.values
          .map((ReaderTextScale s) => s.designRatio)
          .toList();
      // Band, not a point: § 1.2's prose says 1.72 and its table spans 1.6875
      // (sm) to 1.7222 (md), so the furthest entry sits 0.0325 BELOW the stated
      // figure. A tolerance under 0.033 would exclude a value the design system
      // itself prints, so the band is 0.04 — the widest the table actually
      // reaches, and not a rounder number that would have to reject `sm`.
      for (final entry in ReaderTextScale.values) {
        expect(
          entry.designRatio,
          closeTo(1.72, 0.04),
          reason:
              '${entry.name} is ${entry.designRatio}, outside the band '
              'around § 1.2\'s stated 1.72',
        );
      }
      final spread = ratios.reduce(math.max) - ratios.reduce(math.min);
      expect(
        spread,
        lessThan(0.04),
        reason:
            'the rhythm varies by $spread across the five steps, and § 1.2 '
            'holds it constant on purpose',
      );
    });

    test('md is the default', () {
      expect(ReaderTextScale.fromStorage(null), ReaderTextScale.md);
      expect(ReaderTextScale.fromStorage('md'), ReaderTextScale.md);
    });

    test('an unknown stored value falls back to md without throwing', () {
      // The value comes from shared_preferences and may have been written by a
      // version that no longer exists. A display setting must never stop the app
      // from starting.
      expect(ReaderTextScale.fromStorage('enormous'), ReaderTextScale.md);
      expect(ReaderTextScale.fromStorage(''), ReaderTextScale.md);
      expect(ReaderTextScale.fromStorage('12'), ReaderTextScale.md);
    });

    test('every step round-trips through storage', () {
      for (final step in ReaderTextScale.values) {
        expect(ReaderTextScale.fromStorage(step.name), step);
      }
    });

    test('fromIndex clamps rather than throwing', () {
      expect(ReaderTextScale.fromIndex(0), ReaderTextScale.sm);
      expect(ReaderTextScale.fromIndex(4), ReaderTextScale.xxl);
      expect(ReaderTextScale.fromIndex(-3), ReaderTextScale.sm);
      expect(ReaderTextScale.fromIndex(99), ReaderTextScale.xxl);
    });

    test('stepIndex follows the declaration order', () {
      expect(ReaderTextScale.sm.stepIndex, 0);
      expect(ReaderTextScale.md.stepIndex, 1);
      expect(ReaderTextScale.xxl.stepIndex, 4);
    });
  });

  group(
    'B27 — the step and the phone scale are composed, not chosen between',
    () {
      // § 3.2's table, verbatim: step × phone scale, then clamped to 16..40.
      test('100% phone scale', () {
        expect(_size(ReaderTextScale.sm, 1), 16);
        expect(_size(ReaderTextScale.md, 1), 18);
        expect(_size(ReaderTextScale.lg, 1), 20);
        expect(_size(ReaderTextScale.xl, 1), 23);
        expect(_size(ReaderTextScale.xxl, 1), 26);
      });

      test('130% phone scale', () {
        expect(_size(ReaderTextScale.sm, 1.3), closeTo(20.8, 0.05));
        expect(_size(ReaderTextScale.md, 1.3), closeTo(23.4, 0.05));
        expect(_size(ReaderTextScale.lg, 1.3), closeTo(26, 0.05));
        expect(_size(ReaderTextScale.xl, 1.3), closeTo(29.9, 0.05));
        expect(_size(ReaderTextScale.xxl, 1.3), closeTo(33.8, 0.05));
      });

      test('200% phone scale hits the ceiling where § 3.2 says it does', () {
        expect(_size(ReaderTextScale.sm, 2), 32);
        expect(_size(ReaderTextScale.md, 2), 36);
        // lg/xl/xxl all reach 40 — the ceiling, not their own product.
        expect(_size(ReaderTextScale.lg, 2), 40);
        expect(_size(ReaderTextScale.xl, 2), 40);
        expect(_size(ReaderTextScale.xxl, 2), 40);
      });
    },
  );

  group('E14 — the ceiling is real and the floor is never breached', () {
    test('nothing ever renders below 16px, however small the scale', () {
      // The floor is on the PRODUCT, so it cannot bite below the smallest step —
      // which is exactly why E14 ("no clipped text at the largest size") and
      // "never below 16px" cannot both be violated.
      for (final step in ReaderTextScale.values) {
        for (final scale in <double>[0.5, 0.8, 1]) {
          expect(
            _size(step, scale),
            greaterThanOrEqualTo(16),
            reason: '${step.name} at ${scale * 100}% went under the floor',
          );
        }
      }
    });

    test('nothing ever exceeds 40px, however large the scale', () {
      for (final step in ReaderTextScale.values) {
        for (final scale in <double>[2, 3, 5]) {
          expect(
            _size(step, scale),
            lessThanOrEqualTo(40),
            reason:
                '${step.name} at ${scale * 100}% passed the ceiling — the '
                'reader would be following the cursor to follow the line',
          );
        }
      }
    });

    test('the ceiling is what a 52px xxl at 200% would have been', () {
      // 26 x 2 = 52 without the clamp, in a 328dp column: about twelve
      // characters per line.
      expect(52.0, 52);
      expect(_size(ReaderTextScale.xxl, 2), 40);
    });
  });

  group('the line height ratio is recomputed, never copied in pixels', () {
    test('every step keeps its own ratio whatever the clamped size', () {
      for (final step in ReaderTextScale.values) {
        for (final scale in <double>[1, 1.3, 2]) {
          final style = resolveProse(step, TextScaler.linear(scale));
          expect(
            style.height,
            closeTo(step.designRatio, 0.0001),
            reason:
                '${step.name} at ${scale * 100}% must keep its ratio — the '
                'clamp changes the size, never the rhythm',
          );
        }
      }
    });

    test(
      'copying step.lineHeight as PIXELS would overlap lines — and does not',
      () {
        // The trap § 3.2 names: taking 44px onto a recomputed 40px gives a ratio of
        // 1.10, and the lines overlap. Asserting the ratio is not enough on its own,
        // so the wrong answer is computed here and shown to be different.
        final style = resolveProse(
          ReaderTextScale.xxl,
          const TextScaler.linear(2),
        );
        expect(style.fontSize, 40);

        final wrongRatio = ReaderTextScale.xxl.lineHeight / style.fontSize!;
        expect(wrongRatio, closeTo(1.1, 0.01));
        expect(style.height, isNot(closeTo(wrongRatio, 0.01)));
        expect(style.height, closeTo(ReaderTextScale.xxl.designRatio, 0.0001));
      },
    );

    test('the resulting leading is a function of the clamped size', () {
      final small = resolveProse(ReaderTextScale.sm, TextScaler.noScaling);
      final large = resolveProse(
        ReaderTextScale.xxl,
        const TextScaler.linear(2),
      );
      expect(
        large.fontSize! * large.height!,
        greaterThan(small.fontSize! * small.height!),
      );
    });
  });

  group('ADR-017 — the serif chain, nothing embedded', () {
    test('the chain prefers a serif and ends on the platform sans', () {
      final chain = LumenReaderProse.standard().familyFallbackOrDefault;
      expect(chain, contains('Noto Serif'));
      expect(chain, contains('Roboto Slab'));
      // The last entry must be a generic family, so a missing face degrades to
      // readable text and never to squares.
      expect(chain.last, contains('sans-serif'));
    });

    test('resolveProse carries the chain into the style', () {
      final style = resolveProse(ReaderTextScale.md, TextScaler.noScaling);
      expect(style.fontFamilyFallback, contains('Noto Serif'));
      // No fontFamily: nothing is embedded, so there is no bundled asset to drift.
      expect(style.fontFamily, isNull);
    });
  });
}

/// The size § 3.2 computes, read back out of the produced style.
double _size(ReaderTextScale step, double phoneScale) =>
    resolveProse(step, TextScaler.linear(phoneScale)).fontSize!;
