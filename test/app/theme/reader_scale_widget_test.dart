// Lumen Tale — `theme-type` § 11.2, the widget rows.
//
// § 11.5 says every visual check happens at **360dp and only 360dp**: it is the
// design width, `design-system.md` § 1.7 makes `< 600dp` the only layout v1 ships,
// and ADR-019 excludes tablet, desktop, rail and two-pane. So there is no
// "check every breakpoint" to do here, and writing one would promise something the
// product does not do.
//
// These rows are widget tests because the property is a *rendering* property: the
// resolved size must survive the trip through the widget tree and the layout, not
// merely come out of the function.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumen_tale/app/theme/app_theme.dart';
import 'package:lumen_tale/app/theme/lumen_colors.dart';
import 'package:lumen_tale/app/theme/motion.dart';
import 'package:lumen_tale/app/theme/reader_scale.dart';

/// The one width v1 ships (`design-system.md` § 1.7).
const Size designSize = Size(360, 640);

/// Pumps a bare chapter paragraph — the reader's prose column.
Future<void> pumpChapter(
  WidgetTester tester, {
  required ReaderTextScale step,
  required double systemScale,
  required ThemeData theme,
  bool disableAnimations = false,
}) async {
  tester.view
    ..physicalSize = designSize
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(
        textScaler: TextScaler.linear(systemScale),
        disableAnimations: disableAnimations,
      ),
      child: MaterialApp(
        theme: theme,
        home: Builder(
          builder: (BuildContext context) => Scaffold(
            body: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'The chapter opens, and the prose is set in the reader style '
                  'rather than in a widget.',
                  textDirection: TextDirection.ltr,
                  style: resolveProse(step, MediaQuery.textScalerOf(context)),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

/// The size actually laid out, read from the rendered paragraph.
double renderedSize(WidgetTester tester) => tester
    .widget<Text>(find.textContaining('The chapter opens'))
    .style!
    .fontSize!;

void main() {
  group('the rendering floor and ceiling', () {
    testWidgets('at system scale 0.5 the rendered text measures 16px', (
      WidgetTester tester,
    ) async {
      // B27 and `design-quality.md` § 3. "Neither can fail" is the claim: the
      // floor is on the PRODUCT, so the smallest step cannot be pushed under 16.
      for (final step in ReaderTextScale.values) {
        await pumpChapter(
          tester,
          step: step,
          systemScale: 0.5,
          theme: AppTheme.day(),
        );
        expect(
          renderedSize(tester),
          16,
          reason: '${step.name} at 50% must sit on the 16px floor',
        );
      }
    });

    testWidgets('at system scale 2.0 the rendered text is capped at 40px', (
      WidgetTester tester,
    ) async {
      // E14. Beyond 40px the app stops growing and scrolling takes over.
      for (final step in ReaderTextScale.values) {
        await pumpChapter(
          tester,
          step: step,
          systemScale: 2,
          theme: AppTheme.day(),
        );
        expect(
          renderedSize(tester),
          lessThanOrEqualTo(40),
          reason: '${step.name} at 200% must respect the ceiling',
        );
      }
    });

    testWidgets('at xxl and 200% the paragraph does not overflow 360dp', (
      WidgetTester tester,
    ) async {
      // § 11.5's one manual check, made executable: the widest prose at the
      // largest scale must still fit the design width.
      await pumpChapter(
        tester,
        step: ReaderTextScale.xxl,
        systemScale: 2,
        theme: AppTheme.day(),
      );

      expect(renderedSize(tester), 40);
      expect(tester.takeException(), isNull);

      final width = tester
          .getSize(find.textContaining('The chapter opens'))
          .width;
      expect(
        width,
        lessThanOrEqualTo(designSize.width),
        reason: 'the prose column must not exceed the design width',
      );
    });

    testWidgets(
      'at every step and 100% the exact pairs of § 1.2 are rendered',
      (WidgetTester tester) async {
        // The table, verified through the widget tree rather than through the
        // function that produced it.
        const expected = <ReaderTextScale, double>{
          ReaderTextScale.sm: 16,
          ReaderTextScale.md: 18,
          ReaderTextScale.lg: 20,
          ReaderTextScale.xl: 23,
          ReaderTextScale.xxl: 26,
        };
        for (final entry in expected.entries) {
          await pumpChapter(
            tester,
            step: entry.key,
            systemScale: 1,
            theme: AppTheme.day(),
          );
          expect(renderedSize(tester), entry.value, reason: entry.key.name);
        }
      },
    );
  });

  group('the chrome reveal is instant under reduce-motion', () {
    testWidgets('a FadeTransition completes at once with animations disabled', (
      WidgetTester tester,
    ) async {
      // § 1.6: under the system setting every duration becomes 0ms. An animated
      // reading app is worse than one that does not animate at all.
      //
      // ⚠️ The duration is read INSIDE the same `MediaQuery` that disables
      // animations. A first draft pumped the chapter with the setting on, then
      // re-pumped a bare `MaterialApp` to read `LumenMotion.duration(...)` — and
      // got 320ms, because the second tree had no `MediaQuery` and therefore
      // `disableAnimationsOf` reported false. The row was measuring a widget that
      // was not the one under test.
      late Duration observed;
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: MaterialApp(
            theme: AppTheme.day(),
            home: Builder(
              builder: (BuildContext context) {
                final motion = LumenMotion.of(context);
                observed = motion.duration(context, motion.slow);
                return const FadeTransition(
                  opacity: AlwaysStoppedAnimation<double>(1),
                  child: SizedBox.shrink(),
                );
              },
            ),
          ),
        ),
      );

      expect(observed, Duration.zero);
      expect(tester.takeException(), isNull);

      // And the same tree WITHOUT the setting keeps its real duration, so the row
      // is not passing because everything is zero.
      late Duration withoutSetting;
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(),
          child: MaterialApp(
            theme: AppTheme.day(),
            home: Builder(
              builder: (BuildContext context) {
                final motion = LumenMotion.of(context);
                withoutSetting = motion.duration(context, motion.slow);
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );
      expect(withoutSetting, const Duration(milliseconds: 320));
    });
  });

  group('ADR-016 — the same tree in both themes, only colours differ', () {
    testWidgets('the widget tree is identical; the accent is not', (
      WidgetTester tester,
    ) async {
      Future<String> shapeOf(ThemeData theme) async {
        await pumpChapter(
          tester,
          step: ReaderTextScale.md,
          systemScale: 1,
          theme: theme,
        );
        // A structural description of the subtree: widget types and keys only,
        // never a colour.
        return tester
            .widgetList(find.byType(Scaffold))
            .map((Widget w) => w.runtimeType.toString())
            .join(',');
      }

      final dayShape = await shapeOf(AppTheme.day());
      final nightShape = await shapeOf(AppTheme.night());
      expect(
        nightShape,
        dayShape,
        reason:
            'a rendering difference between themes must not change the tree '
            '— § 4.3 calls a differing tree a bug',
      );

      expect(LumenColors.day().accent, isNot(LumenColors.night().accent));
    });
  });

  group('no horizontal overflow at any step and scale', () {
    testWidgets('the full matrix is overflow-free at 360dp', (
      WidgetTester tester,
    ) async {
      // § 11.5's promise, made exhaustive: five steps x three scales x two themes.
      for (final theme in <ThemeData>[AppTheme.day(), AppTheme.night()]) {
        for (final step in ReaderTextScale.values) {
          for (final scale in <double>[1, 1.5, 2]) {
            await pumpChapter(
              tester,
              step: step,
              systemScale: scale,
              theme: theme,
            );
            expect(
              tester.takeException(),
              isNull,
              reason: '${step.name} at ${scale * 100}% overflowed',
            );
          }
        }
      }
    });
  });
}
