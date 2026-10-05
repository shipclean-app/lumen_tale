// forge:slice 2-8
// Lumen Tale — `2-8` § 11.2: the reader's two controls, as the reader meets them.
//
// ## The claims that are invisible in a screenshot, and are therefore asserted here
//
// | claim | how it is observed |
// |---|---|
// | the chosen size is on the **same frame**, with no tween | one `pump()`, then read the size — a tween would still be mid-flight |
// | the Markdown is **not re-parsed** | the repository is read once, before and after |
// | a refused write leaves the check on the **stored** step | the sheet's checked row after the throw |
// | the chrome reveal is instant under reduce-motion | the fade's value after one frame |

import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumen_tale/app/theme/app_theme.dart';
import 'package:lumen_tale/app/theme/app_theme_preferences.dart';
import 'package:lumen_tale/app/theme/lumen_spacing.dart';
import 'package:lumen_tale/app/theme/motion.dart';
import 'package:lumen_tale/app/theme/reader_display_copy.dart';
import 'package:lumen_tale/app/theme/reader_scale.dart';
import 'package:lumen_tale/app/theme/theme_override.dart';
import 'package:lumen_tale/app/theme/theme_providers.dart';
import 'package:lumen_tale/domain/library/chapter_entry.dart';
import 'package:lumen_tale/domain/library/reading_position.dart';
import 'package:lumen_tale/domain/library/reading_position_store.dart';
import 'package:lumen_tale/domain/reader/chapter_document.dart';
import 'package:lumen_tale/domain/reader/chapter_reader_repository.dart';
import 'package:lumen_tale/features/novel_details/novel_details_screen.dart';
import 'package:lumen_tale/features/reader/reader_providers.dart';
import 'package:lumen_tale/features/reader/reader_screen.dart';
import 'package:lumen_tale/features/reader/widgets/chapter_prose.dart';
import 'package:lumen_tale/features/reader/widgets/reader_controls.dart';
import 'package:lumen_tale/l10n/generated/app_localizations.dart';

/// The design width, and the only one v1 ships (`design-system.md` § 1.7).
const Size phone = Size(360, 640);

const ChapterText chapter = ChapterText(
  chapterId: 'c1',
  chapterName: 'Glossary',
  number: 12,
  ordinal: 1,
  markdown:
      'A term is a word the author has defined once.\n\nA second paragraph.',
  byteLength: 61,
);

final Finder proseArea = find.byKey(
  const ValueKey<String>('reader-prose-area'),
);

final Finder sizeButton = find.byKey(
  const ValueKey<String>('reader-controls.size'),
);

final Finder themeButton = find.byKey(
  const ValueKey<String>('reader-controls.theme'),
);

Finder stepRow(ReaderTextScale step) =>
    find.byKey(ValueKey<String>('reader-size-step-${step.name}'));

/// An in-memory preferences store, and the values written through it.
final class FakePreferences implements AppThemePreferences {
  ReaderTextScale scale = ReaderTextScale.md;
  ThemeOverride theme = ThemeOverride.system;

  /// How many of the next writes must refuse. **A count, not a flag**, so "the first tap
  /// fails and the retry succeeds" is expressible — a boolean can only say "refuse
  /// everything" or "refuse once".
  int refuseNext = 0;

  @override
  ReaderTextScale readReaderScale() => scale;

  @override
  ThemeOverride readThemeOverride() => theme;

  @override
  Future<void> writeReaderScale(ReaderTextScale value) async {
    if (refuseNext > 0) {
      refuseNext--;
      throw ThemePersistenceException('readerScale', value.name, null);
    }
    scale = value;
  }

  @override
  Future<void> writeThemeOverride(ThemeOverride value) async {
    if (refuseNext > 0) {
      refuseNext--;
      throw ThemePersistenceException('themeOverride', value.name, null);
    }
    theme = value;
  }
}

final class FakeRepository implements ChapterReaderRepository {
  int reads = 0;

  @override
  Future<ChapterDocument> readChapter({
    required String chapterId,
    required bool hasConnection,
  }) async {
    reads++;
    return chapter;
  }

  @override
  Future<void> markOpened(String chapterId) async {}

  @override
  Future<ChapterNeighbour?> neighbour({
    required String chapterId,
    required NeighbourDirection direction,
  }) async => null;

  @override
  final RecordingPositions positions = RecordingPositions();
}

final class RecordingPositions implements ReadingPositionStore {
  @override
  Future<void> write(
    String chapterId,
    double offset, {
    required double contentHeight,
  }) async {}

  @override
  Future<void> clear(String chapterId) async {}

  @override
  Future<ReadingPosition?> mostRecentAmong(List<String> chapterIds) async =>
      null;

  @override
  Future<ReadingPosition?> read(String chapterId) async => null;
}

/// The reader, in the real theme, at the design width.
///
/// Returns the store and the repository, so a row can ask what was written and what was read.
///
/// ⚠️ **The stored values are parameters, not mutations after the pump.** The scale is read
/// by the notifier's `build`, so a row that set `prefs.scale` after `pumpWidget` would be
/// asserting against a store the provider has already read past — and the sheet would
/// correctly show `md` while the row expected `lg`.
Future<(FakePreferences, FakeRepository)> pumpReader(
  WidgetTester tester, {
  double systemScale = 1,
  bool disableAnimations = false,
  ReaderTextScale scale = ReaderTextScale.md,
  ThemeOverride theme = ThemeOverride.system,
}) async {
  final FakePreferences prefs = FakePreferences()
    ..scale = scale
    ..theme = theme;
  final FakeRepository repository = FakeRepository();
  tester.view
    ..physicalSize = phone
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appThemePreferencesProvider.overrideWithValue(prefs),
        chapterReaderRepositoryProvider.overrideWithValue(repository),
      ],
      child: MediaQuery(
        data: MediaQueryData(
          textScaler: TextScaler.linear(systemScale),
          disableAnimations: disableAnimations,
        ),
        child: MaterialApp(
          theme: AppTheme.day(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const ReaderScreen(chapterId: 'c1'),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return (prefs, repository);
}

/// Runs [body] with the semantics tree on, and disposes the handle.
///
/// ⚠️ **`dispose` inside the helper, not in an `addTearDown`.** Flutter's end-of-test check
/// runs BEFORE tear-downs, so a handle registered the usual way is reported as leaked and
/// fails every row that opened one.
Future<void> withSemantics(
  WidgetTester tester,
  Future<void> Function() body,
) async {
  final SemanticsHandle handle = tester.ensureSemantics();
  try {
    await body();
  } finally {
    handle.dispose();
  }
}

/// Reveals the chrome. **The tap is on the reading zone**, which is the gesture `2-4`
/// defined — tapping the button directly would test the button in a state the reader cannot
/// reach.
Future<void> reveal(WidgetTester tester) async {
  await tester.tap(proseArea);
  await tester.pumpAndSettle();
}

/// The prose size actually rendered, read back out of the Markdown style sheet.
double _proseSize(WidgetTester tester) => tester
    .widget<MarkdownBody>(find.byType(MarkdownBody).first)
    .styleSheet!
    .p!
    .fontSize!;

/// The step whose row is marked selected in the semantics tree, or `null`.
ReaderTextScale? _selectedStep(WidgetTester tester) {
  for (final ReaderTextScale each in ReaderTextScale.values) {
    if (stepRow(each).evaluate().isEmpty) {
      continue;
    }
    if (tester.widget<ListTile>(stepRow(each)).selected == true) {
      return each;
    }
  }
  return null;
}

void main() {
  group('B27 — `sizeButton`', () {
    testWidgets('the sheet offers FIVE steps and checks the current one', (
      WidgetTester tester,
    ) async {
      await pumpReader(tester, scale: ReaderTextScale.lg);
      await reveal(tester);

      await tester.tap(sizeButton);
      await tester.pumpAndSettle();

      expect(find.text('Text size'), findsOneWidget);
      for (final ReaderTextScale each in ReaderTextScale.values) {
        expect(
          stepRow(each),
          findsOneWidget,
          reason: '${each.name} is one of the five steps, taken from the enum',
        );
      }
      expect(
        _selectedStep(tester),
        ReaderTextScale.lg,
        reason:
            'the check is on the STORED step — § 4: the screen never shows a size it does '
            'not hold',
      );
    });

    testWidgets('each step announces name, figure and selection — § 5 exactly', (
      WidgetTester tester,
    ) async {
      await withSemantics(tester, () async {
        await pumpReader(tester);
        await reveal(tester);
        await tester.tap(sizeButton);
        await tester.pumpAndSettle();

        // **The design's own sentence.** `settings-reader.md` § 5: *"Large, 20 pixels, not
        // selected"* — one focusable node carrying all three facts, rather than three nodes a
        // screen reader has to reassemble.
        expect(
          tester.getSemantics(stepRow(ReaderTextScale.lg)).label,
          'Large, 20 pixels, not selected',
        );
        expect(
          tester.getSemantics(stepRow(ReaderTextScale.md)).label,
          'Medium, 18 pixels, selected',
        );
        expect(
          tester.getSemantics(stepRow(ReaderTextScale.xxl)).label,
          'Largest, 26 pixels, not selected',
        );
      });
    });

    testWidgets('the prose is at the new size on the SAME frame, no tween', (
      WidgetTester tester,
    ) async {
      await pumpReader(tester);
      expect(_proseSize(tester), 18, reason: '`md` is the default');

      await reveal(tester);
      await tester.tap(sizeButton);
      await tester.pumpAndSettle();
      await tester.tap(stepRow(ReaderTextScale.xxl));
      // ⚠️ **ONE pump, no elapsed duration.** A `TweenAnimationBuilder` or an
      // `AnimatedSize` would still be at its starting value here, so this row is what
      // separates "applied" from "animating towards".
      await tester.pump();

      expect(
        _proseSize(tester),
        26,
        reason:
            'a reader judging a character needs to see it BE the new size, not become it — '
            '§ 3.3 gives a size change 0 ms and forbids a cross-fade',
      );
    });

    testWidgets('choosing a size does NOT re-read the chapter from disk', (
      WidgetTester tester,
    ) async {
      final (_, FakeRepository repository) = await pumpReader(tester);
      final int before = repository.reads;

      await reveal(tester);
      await tester.tap(sizeButton);
      await tester.pumpAndSettle();
      await tester.tap(stepRow(ReaderTextScale.xl));
      await tester.pumpAndSettle();

      expect(
        repository.reads,
        before,
        reason:
            're-reading the file would re-run the Markdown conversion; a size tap is not a '
            'reason to pay for it again, and `2-4` says the document is read once per '
            'opening',
      );
      expect(find.byType(MarkdownBody), findsOneWidget);
    });

    testWidgets('the sheet closes on Cancel and changes nothing', (
      WidgetTester tester,
    ) async {
      final (FakePreferences prefs, _) = await pumpReader(tester);
      await reveal(tester);
      await tester.tap(sizeButton);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(prefs.scale, ReaderTextScale.md);
      expect(find.text('Text size'), findsNothing);
    });

    testWidgets('a refused write leaves the control on the STORED step, and says why', (
      WidgetTester tester,
    ) async {
      // Section 3.4, and the invariant in prose: the screen never shows a size or a theme
      // it does not hold. The specimen is on the same stored value, so a control showing
      // 26 while the app holds 18 is a reader who will be at 18 when the chapter opens.
      final (FakePreferences prefs, _) = await pumpReader(tester);
      prefs.refuseNext = 1;
      await reveal(tester);
      await tester.tap(sizeButton);
      await tester.pumpAndSettle();
      await tester.tap(stepRow(ReaderTextScale.xxl));
      await tester.pumpAndSettle();

      expect(
        prefs.scale,
        ReaderTextScale.md,
        reason: 'nothing was written, so nothing was adopted',
      );
      expect(
        _selectedStep(tester),
        ReaderTextScale.md,
        reason: 'the check came back to the stored step',
      );
      expect(
        _proseSize(tester),
        18,
        reason:
            'and the prose never moved -- the specimen would not have either',
      );
      expect(
        find.text(
          'This setting could not be saved. It will keep its previous value.',
        ),
        findsOneWidget,
        reason:
            'the failure is named. Section 4 forbids naming it by tinting the control: a '
            'red step reads as "this size is broken", not "this size was not saved"',
      );
      expect(
        find.widgetWithText(SnackBarAction, 'Retry'),
        findsOneWidget,
        reason: 'and C12 asks for a failure the reader can act on',
      );
    });

    testWidgets('the sheet stays open after a failure, so the reader can retry', (
      WidgetTester tester,
    ) async {
      final (FakePreferences prefs, _) = await pumpReader(tester);
      prefs.refuseNext = 1;
      await reveal(tester);
      await tester.tap(sizeButton);
      await tester.pumpAndSettle();
      await tester.tap(stepRow(ReaderTextScale.lg));
      await tester.pumpAndSettle();
      expect(
        find.text('Text size'),
        findsOneWidget,
        reason:
            'a sheet that popped before the write landed has nowhere to show the failure '
            'or the retry; section 4 keeps it open on the previous value',
      );

      // The SnackBar is allowed to leave first. It covers the bottom of the sheet, so a
      // tap meant for a step would land on it -- which is a real interaction, not a test
      // artefact, and the reason the retry ACTION exists as well.
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();

      await tester.tap(stepRow(ReaderTextScale.lg));
      await tester.pumpAndSettle();
      expect(
        prefs.scale,
        ReaderTextScale.lg,
        reason: 'the second tap is a fresh write and it lands',
      );
      expect(
        _selectedStep(tester),
        ReaderTextScale.lg,
        reason: 'and now the check follows, because the value is real',
      );
    });
  });

  group('B26 — `themeButton`', () {
    testWidgets('one tap cycles, in the normative order', (
      WidgetTester tester,
    ) async {
      final (FakePreferences prefs, _) = await pumpReader(tester);
      await reveal(tester);

      await tester.tap(themeButton);
      await tester.pumpAndSettle();
      expect(prefs.theme, ThemeOverride.day);

      await tester.tap(themeButton);
      await tester.pumpAndSettle();
      expect(prefs.theme, ThemeOverride.night);

      await tester.tap(themeButton);
      await tester.pumpAndSettle();
      expect(
        prefs.theme,
        ThemeOverride.system,
        reason: 'day, night, system — and the ring closes after three',
      );
    });

    testWidgets('the tooltip names the CURRENT value, never the next one', (
      WidgetTester tester,
    ) async {
      final (FakePreferences prefs, _) = await pumpReader(tester);
      await reveal(tester);

      expect(
        tester.widget<IconButton>(themeButton).tooltip,
        'Theme: Follow the phone',
        reason:
            'naming the RESULT of the tap would be true for one press and false for the '
            'next two, and a reader mid-chapter cannot see which it is',
      );
      await tester.tap(themeButton);
      await tester.pumpAndSettle();
      expect(tester.widget<IconButton>(themeButton).tooltip, 'Theme: Day');
      expect(
        prefs.scale,
        ReaderTextScale.md,
        reason: 'the size is untouched by a theme tap',
      );
    });

    testWidgets('a refused write keeps the old theme AND offers Try again', (
      WidgetTester tester,
    ) async {
      // § 3.4: the theme button has no surface of its own to put a field-level error on, so
      // the failure has to be a sentence that survives the chrome being dismissed.
      final (FakePreferences prefs, _) = await pumpReader(tester);
      prefs.refuseNext = 1;
      await reveal(tester);

      await tester.tap(themeButton);
      await tester.pumpAndSettle();

      expect(prefs.theme, ThemeOverride.system);
      expect(
        find.text(
          'This setting could not be saved. It will keep its previous value.',
        ),
        findsOneWidget,
      );
      expect(
        tester.widget<IconButton>(themeButton).tooltip,
        'Theme: Follow the phone',
        reason: 'the button still shows the value the app holds',
      );

      final Finder action = find.widgetWithText(SnackBarAction, 'Retry');
      expect(
        action,
        findsOneWidget,
        reason: 'C12: a failure the reader can act on',
      );

      await tester.tap(action);
      await tester.pumpAndSettle();
      expect(
        prefs.theme,
        ThemeOverride.day,
        reason:
            'Try again performs the operation that just failed, not a re-read',
      );
    });
  });

  group('the two doors agree — `settings-reader.md` § 2.1', () {
    testWidgets('a size written in the reader is the word Settings will print', (
      WidgetTester tester,
    ) async {
      // **Written by one door, read by the other.** The value line is produced by
      // `appearanceLabel` from the same providers the sheet wrote; if the reader kept a
      // second copy of the value, this is the assertion that would separate them.
      final (FakePreferences prefs, _) = await pumpReader(tester);
      await reveal(tester);
      await tester.tap(sizeButton);
      await tester.pumpAndSettle();
      await tester.tap(stepRow(ReaderTextScale.xl));
      await tester.pumpAndSettle();

      final ProviderContainer container = ProviderScope.containerOf(
        tester.element(find.byType(ReaderControls)),
      );
      final AppLocalizations l10n = await AppLocalizations.delegate.load(
        const Locale('en'),
      );
      expect(
        l10n.readerSizeLabel(container.read(readerTextScaleProvider)),
        'Larger',
        reason: 'so the settings row will read "Larger (23 pt)"',
      );
      expect(
        l10n.readerSizeLabel(container.read(readerTextScaleProvider)),
        l10n.readerSizeLabel(ReaderTextScale.xl),
        reason: 'and it is the step the reader tapped, not a neighbour of it',
      );
      expect(prefs.scale, ReaderTextScale.xl);
    });
  });

  group('§ 3.3 and § 1.6 — what animates, and what must not', () {
    testWidgets('the chrome reveal is INSTANT under reduce-motion', (
      WidgetTester tester,
    ) async {
      // ⚠️ **A `MediaQuery` above the app is required.** `LumenMotion.duration` reads
      // `MediaQuery.disableAnimationsOf`, and a bare `MaterialApp` reports false — which
      // is how an earlier version of this row measured a widget that was not under test.
      await pumpReader(tester, disableAnimations: true);

      final BuildContext context = tester.element(proseArea);
      expect(
        LumenMotion.of(context).duration(context, LumenMotion.of(context).slow),
        Duration.zero,
        reason: '§ 1.6: every duration becomes 0 ms, never a shorter one',
      );

      await tester.tap(proseArea);
      // ⚠️ **A SINGLE frame, no elapsed duration.** With the 320 ms reveal this would be at
      // zero; with `--duration-reduced` it is already at one.
      await tester.pump();

      final FadeTransition fade = tester.widget<FadeTransition>(
        find
            .descendant(
              of: find.byKey(const ValueKey<String>('reader-controls.reveal')),
              matching: find.byType(FadeTransition),
            )
            .first,
      );
      expect(
        fade.opacity.value,
        1.0,
        reason: 'the chrome appeared rather than arriving',
      );
      expect(
        find.byKey(const ValueKey<String>('reader-controls.size')),
        findsOneWidget,
      );
    });

    testWidgets('without the setting the reveal still takes 320 ms', (
      WidgetTester tester,
    ) async {
      // **The companion row**, so the one above cannot pass because everything is zero.
      await pumpReader(tester);

      final BuildContext context = tester.element(proseArea);
      expect(
        LumenMotion.of(context).duration(context, LumenMotion.of(context).slow),
        const Duration(milliseconds: 320),
      );

      await reveal(tester);
      final FadeTransition fade = tester.widget<FadeTransition>(
        find
            .descendant(
              of: find.byKey(const ValueKey<String>('reader-controls.reveal')),
              matching: find.byType(FadeTransition),
            )
            .first,
      );
      expect(
        fade.opacity.value,
        1.0,
        reason:
            'and after settling it is fully shown, whatever the duration was',
      );
    });

    testWidgets('the prose carries NO animation, at any step', (
      WidgetTester tester,
    ) async {
      // The absence, asserted on the tree, and the predicate is SPELLED OUT. `2-8` is the
      // slice most likely to introduce one, because it is the slice that adds a control
      // whose whole subject is the size. The widgets below are the ones a cross-fade or a
      // tween would actually be built from. `AnimatedBuilder` is deliberately absent from
      // the list: it is a mechanism the framework uses ABOVE the reader (the MaterialApp
      // overlay's modal scope), so naming it would make this row describe the framework
      // rather than this slice.
      await pumpReader(tester);
      expect(
        find.descendant(
          of: find.byType(ChapterProse),
          matching: find.byWidgetPredicate(
            (Widget w) =>
                w is ImplicitlyAnimatedWidget ||
                w is TweenAnimationBuilder<Object?> ||
                w is FadeTransition ||
                w is AnimatedCrossFade ||
                w is AnimatedDefaultTextStyle,
          ),
        ),
        findsNothing,
        reason:
            'nothing cross-fades or tweens the prose; section 3.3 gives a size change 0 ms '
            'and a theme change 0 ms, and the only animated widgets are the chrome reveal',
      );
    });
  });

  group('E10 — two chapters of the same title stay two chapters', () {
    testWidgets('the scale never merges them, and both keep the full title', (
      WidgetTester tester,
    ) async {
      // The reader is not a chapter list, so `ChapterTile` -- `3-2`'s row, the one that
      // truncates -- is pumped directly, twice, with the SAME title. The claim is that
      // **this slice** de-duplicates nothing, and that its five steps change nothing about
      // what a row says about itself.
      const String long =
          'A chapter title the site published at more than one line so that the row has '
          'to ellipsize it and the label still has to carry all of it';
      await withSemantics(tester, () async {
        await tester.pumpWidget(
          MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: MaterialApp(
              theme: AppTheme.day(),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: ListView(
                  children: <Widget>[
                    for (int i = 0; i < 2; i++)
                      ChapterTile(
                        chapter: ChapterEntry(
                          id: 'c$i',
                          name: long,
                          ordinal: i,
                          isRead: true,
                          isDownloaded: true,
                        ),
                        isCurrent: false,
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.byType(ChapterTile),
          findsNWidgets(2),
          reason:
              'B10: a site listing the same title twice means two chapters, and nothing in '
              'this slice may collapse them into one row',
        );
        for (int i = 0; i < 2; i++) {
          expect(
            tester.getSemantics(find.byType(ChapterTile).at(i)).label,
            contains(long),
            reason:
                'row $i carries the WHOLE title in its accessible label, not the '
                'ellipsised pixels -- two rows that look identical must still be '
                'distinguishable by a screen reader',
          );
        }
        expect(
          tester.takeException(),
          isNull,
          reason: 'and nothing overflowed at 200%',
        );
      });
    });
  });

  group(
    'the spacing token, because a token nobody uses is a token that drifted',
    () {
      test('the chrome is padded from `LumenSpacing`', () {
        expect(LumenSpacing.standard().xs2, 2);
        expect(LumenSpacing.standard().sm, 8);
      });
    },
  );
}
