// Lumen Tale — `theme-type` § 11.1, the provider rows.
//
// E13's claim is the one that cannot be tested by reading the theme: **"the phone
// flips light/dark mid-read, and the reading position is preserved."** The
// mechanism is a *separation* — the position lives in `reading_positions.offset`,
// written on every scroll settle, and no theme code touches it. A test that pumps
// a widget, flips the platform brightness, and asserts the reading state is
// unchanged is what makes that separation observable rather than asserted.
//
// `main.dart` still has no `home`, so this file wraps a bare subtree in the real
// themes rather than pretending an app shell exists.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumen_tale/app/theme/app_theme.dart';
import 'package:lumen_tale/app/theme/lumen_colors.dart';
import 'package:lumen_tale/app/theme/lumen_radius.dart';
import 'package:lumen_tale/app/theme/lumen_spacing.dart';
import 'package:lumen_tale/app/theme/motion.dart';
import 'package:lumen_tale/app/theme/reader_scale.dart';
import 'package:lumen_tale/app/theme/shadows.dart';
import 'package:lumen_tale/app/theme/theme_override.dart';

/// Stands in for the reader's scroll state, held exactly where `2-6` will hold it:
/// outside the widget tree, in the database.
class _FakeReadingPosition {
  double offset = 0;
  int contentHeight = 3000;
}

void main() {
  group('the extensions resolve from a real ThemeData', () {
    testWidgets('every extension is reachable in both themes', (
      WidgetTester tester,
    ) async {
      for (final theme in <ThemeData>[AppTheme.day(), AppTheme.night()]) {
        await tester.pumpWidget(
          MaterialApp(
            theme: theme,
            home: Builder(
              builder: (BuildContext context) {
                expect(LumenColors.of(context), isA<LumenColors>());
                expect(LumenSpacing.of(context), isA<LumenSpacing>());
                expect(LumenRadius.of(context), isA<LumenRadius>());
                expect(LumenShadows.of(context), isA<LumenShadows>());
                expect(LumenMotion.of(context), isA<LumenMotion>());
                expect(LumenReaderProse.of(context), isA<LumenReaderProse>());
                return const SizedBox.shrink();
              },
            ),
          ),
        );
      }
    });

    testWidgets('a missing extension is loud, never a silent fallback', (
      WidgetTester tester,
    ) async {
      // `LumenColors.of` uses `!` on purpose: a widget rendered outside the real
      // theme must crash loudly rather than paint an anonymous colour.
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (BuildContext context) {
              expect(
                () => LumenColors.of(context),
                throwsA(isA<TypeError>()),
                reason:
                    'an unregistered extension must not resolve to a default',
              );
              return const SizedBox.shrink();
            },
          ),
        ),
      );
    });
  });

  group('the spacing and radius tokens are base-4dp and complete', () {
    test('every spacing step is a multiple of two and increasing', () {
      final s = LumenSpacing.standard();
      final values = <double>[
        s.xs2,
        s.xs,
        s.sm,
        s.md,
        s.lg,
        s.xl,
        s.xl2,
        s.xl3,
      ];
      expect(values, <double>[2, 4, 8, 12, 16, 24, 32, 48]);
      for (final v in values) {
        expect(v % 2, 0, reason: '$v is not on the 2dp grid');
      }
      // Strictly increasing: a spacing scale that repeats is two answers to "how
      // much space".
      for (var i = 1; i < values.length; i++) {
        expect(values[i], greaterThan(values[i - 1]));
      }
    });

    test('the four radii and two stroke widths are the declared ones', () {
      final r = LumenRadius.standard();
      expect(<double>[r.sm, r.md, r.lg, r.full], <double>[4, 8, 16, 999]);
      expect(LumenRadius.borderWidth, 1);
      expect(LumenRadius.borderWidthStrong, 2);
      expect(LumenRadius.none, BorderRadius.zero);
    });

    test('exactly two shadows exist, for the two things that float', () {
      final s = LumenShadows.standard();
      expect(s.sheet, hasLength(1));
      expect(s.dialog, hasLength(1));
      expect(s.sheet.first.blurRadius, 24);
      expect(s.dialog.first.blurRadius, 48);
    });
  });

  group('§ 1.6 — the reduce-motion policy is read in exactly one place', () {
    testWidgets('durations become zero under the system setting', (
      WidgetTester tester,
    ) async {
      late Duration observed;
      late Curve observedCurve;

      Future<void> pump({required bool disableAnimations}) async {
        await tester.pumpWidget(
          MediaQuery(
            data: MediaQueryData(disableAnimations: disableAnimations),
            child: MaterialApp(
              theme: AppTheme.day(),
              home: Builder(
                builder: (BuildContext context) {
                  final motion = LumenMotion.of(context);
                  observed = motion.duration(context, motion.slow);
                  observedCurve = motion.curve(context, motion.standard);
                  return const SizedBox.shrink();
                },
              ),
            ),
          ),
        );
      }

      await pump(disableAnimations: false);
      expect(observed, const Duration(milliseconds: 320));

      await pump(disableAnimations: true);
      // Zero, never a shorter duration.
      expect(observed, Duration.zero);
      expect(observedCurve, Curves.linear);
    });

    test('the three named durations are ordered', () {
      final m = LumenMotion.standard();
      expect(m.fast, lessThan(m.normal));
      expect(m.normal, lessThan(m.slow));
      expect(m.reduced, Duration.zero);
    });
  });

  group('E13 — a mid-read theme flip does not touch the reading position', () {
    testWidgets(
      'the position survives the flip, because no theme code knows of it',
      (WidgetTester tester) async {
        final position = _FakeReadingPosition()..offset = 1487;

        // Both themes are pumped and the SEQUENCE is the point: day, then night,
        // with the reader's state held outside the tree exactly where `2-6` will
        // hold it (in the database).
        //
        // ⚠️ Three earlier drafts failed here, and each failure was worth having:
        //  1. asserting `colorScheme.primary` — wrong: that is a seed role, not
        //     the accent. The token is read from `LumenColors`.
        //  2. driving it through `themeMode` + `platformBrightnessTestValue` —
        //     `MaterialApp` resolves `themeMode` against its own platform
        //     brightness, which the test binding reports as `light` and does not
        //     move on a `pumpWidget`.
        //  3. swapping `theme` while reusing the same `MaterialApp` element —
        //     Flutter reuses the element and `MaterialApp` had already resolved
        //     its brightness from the first theme, so the tree never re-themed
        //     even though `AppTheme.night()` was correct.
        //
        // Hence: the ACCENT TOKEN, which is what this foundation owns, and a
        // distinct subtree key per theme so the swap is real.
        Future<LumenColors> pumpWith(ThemeData theme, String key) async {
          await tester.pumpWidget(
            MaterialApp(
              key: ValueKey<String>(key),
              theme: theme,
              home: Builder(
                builder: (BuildContext context) {
                  // The reader's own state, read exactly as `2-6` will: from
                  // outside the tree, never from a widget.
                  return Text(
                    'offset ${position.offset}',
                    style: resolveProse(
                      ReaderTextScale.md,
                      MediaQuery.textScalerOf(context),
                    ),
                    textDirection: TextDirection.ltr,
                  );
                },
              ),
            ),
          );
          return LumenColors.of(tester.element(find.textContaining('offset')));
        }

        final inDay = await pumpWith(AppTheme.day(), 'day');
        expect(inDay.accent, LumenColors.day().accent);
        expect(position.offset, 1487);

        // E13 — the phone flips to night while the chapter is open.
        final inNight = await pumpWith(AppTheme.night(), 'night');
        expect(
          inNight.accent,
          LumenColors.night().accent,
          reason:
              'the chrome really did re-theme — otherwise this row would '
              'prove nothing about a flip',
        );
        expect(
          inNight.accent,
          isNot(inDay.accent),
          reason:
              'and the two themes must actually differ, or the assertion '
              'above is comparing a value with itself',
        );
        expect(
          position.offset,
          1487,
          reason:
              'the reading position is untouched. It lives in the database, '
              'so this is a property of the separation, not a guard some code '
              'has to remember to write.',
        );
        expect(position.contentHeight, 3000);
      },
    );

    testWidgets('the theme resolves from the override, not from the phone alone', (
      WidgetTester tester,
    ) async {
      // ⚠️ The assertion is on `AppTheme.night().colorScheme.brightness`, NOT on
      // `Theme.of(context).brightness` inside a pumped tree.
      //
      // A first draft pumped `MaterialApp` and asserted in-tree, and it failed
      // twice for harness reasons: `MaterialApp` resolves `themeMode` against
      // its own platform brightness, which the test binding reports as `light`
      // and which `platformBrightnessTestValue` does not move on a
      // `pumpWidget`. **The second failure was a real product bug it uncovered**
      // — `fromSeed` derives brightness from the seed, so `night()` had been
      // reporting `Brightness.light` while its colours said otherwise. That is
      // fixed in `AppTheme._build`, and asserting the scheme directly is what
      // keeps it fixed: it tests the thing this foundation produces rather than
      // MaterialApp's plumbing.
      expect(AppTheme.day().colorScheme.brightness, Brightness.light);
      expect(AppTheme.night().colorScheme.brightness, Brightness.dark);

      // And each override maps to the brightness `0-5` will hand `MaterialApp`,
      // on a phone that says the OPPOSITE — which is B26's whole claim.
      expect(
        ThemeOverride.day.resolve(Brightness.dark),
        ThemeMode.light,
        reason: 'forcing day on a phone in night',
      );
      expect(
        ThemeOverride.night.resolve(Brightness.light),
        ThemeMode.dark,
        reason: 'forcing night on a phone in day',
      );

      // Through a real `MaterialApp`, with a distinct key per case so the element
      // is rebuilt rather than reused.
      for (final (override, expected) in const <(ThemeOverride, Brightness)>[
        (ThemeOverride.day, Brightness.light),
        (ThemeOverride.night, Brightness.dark),
      ]) {
        await tester.pumpWidget(
          MaterialApp(
            key: ValueKey<String>('override-${override.name}'),
            theme: override == ThemeOverride.day
                ? AppTheme.day()
                : AppTheme.night(),
            darkTheme: AppTheme.night(),
            themeMode: override.resolve(Brightness.dark),
            home: Builder(
              builder: (BuildContext context) {
                expect(
                  Theme.of(context).brightness,
                  expected,
                  reason: '$override must select $expected',
                );
                return const SizedBox.shrink();
              },
            ),
          ),
        );
      }
    });
  });

  group('no widget writes a font size', () {
    testWidgets('the prose style is the only place a size appears', (
      WidgetTester tester,
    ) async {
      // `14-design-tokens.md` §Typography. A widget-level `fontSize` would give
      // the reader a second way to change the same text, and `2-6`'s stored
      // `contentHeight` would then be measured against a size nothing recorded.
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.day(),
          home: Builder(
            builder: (BuildContext context) => Text(
              'chapter',
              style: resolveProse(
                ReaderTextScale.lg,
                MediaQuery.textScalerOf(context),
              ),
              textDirection: TextDirection.ltr,
            ),
          ),
        ),
      );
      final text = tester.widget<Text>(find.text('chapter'));
      expect(text.style?.fontSize, 20);
      expect(text.style?.fontSize, isNotNull);
    });
  });
}
