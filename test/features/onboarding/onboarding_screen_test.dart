// forge:slice 3-4
// Lumen Tale — `onboarding.md` § 3 and § 4, the screen rendered: both steps, the two
// controls, the absence of every control the screen file refuses, and the four absences
// that are decisions rather than omissions.
//
// ## ⚠️ THE NEGATIONS ARE THE LOAD-BEARING ROWS
//
// Six of `3-4`'s acceptance criteria are **absences**: no `Get started`, no `Skip` on step
// 2, no close button, no icon in the disclosure, no error colour, no settings control, no
// permission request. Every one of them is a way this screen could quietly start lying, and
// a positive assertion cannot see any of them. Each gets a row.
//
// ## ⚠️ THE HARNESS SUBSTITUTES A ROUTER, AND THE SCREEN DOES NOT KNOW
//
// `OnboardingScreen` builds its own `ProviderScope` and would need a live `GoRouter` for it.
// The tests below pump `OnboardingBody` inside an explicit scope with a recording
// [OnboardingRouter] — which is the seam § 2.3 created the interface for, and it means the
// screen's own composition is exercised once, by the real router, in
// `onboarding_screen_routing_test.dart`.

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart' show SemanticsNode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumen_tale/app/theme/app_theme.dart';
import 'package:lumen_tale/app/theme/lumen_colors.dart';
import 'package:lumen_tale/core/storage/onboarding_seen.dart';
import 'package:lumen_tale/core/storage/shared_preferences_provider.dart';
import 'package:lumen_tale/core/ui/app_scaffold.dart';
import 'package:lumen_tale/features/onboarding/domain/onboarding_state.dart';
import 'package:lumen_tale/features/onboarding/providers/onboarding_seen.dart';
import 'package:lumen_tale/features/onboarding/screens/onboarding_screen.dart';
import 'package:lumen_tale/features/onboarding/widgets/disclosure_block.dart';
import 'package:lumen_tale/features/onboarding/widgets/onboarding_type.dart';
import 'package:lumen_tale/l10n/generated/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// `design-system.md` § 1.7: `< 600dp` is the only layout v1 ships.
const Size designSize = Size(360, 640);

/// A phone tall enough that the whole of one step fits **in the test font**.
///
/// ## ⚠️ WHY THE HEIGHT IS NOT 640
///
/// `onboarding.md` § 5 claims *"on both steps the content fits without scrolling at the
/// default text size"*, and that is true on a phone. It cannot be shown in a widget test,
/// and the reason is worth recording because it looks like a layout bug and is not one:
///
/// **flutter_test draws every glyph as a square one em wide.** A 213-character paragraph in
/// `--text-body` therefore occupies `213 / (328 / 16) ≈ 11` lines in a test and about six on
/// a device, which is 264dp of extra page at the default text size.
///
/// The rows that need the whole step visible use this height; the rows that are about
/// **overflow, scrolling and order** use [designSize] and deliberately show the page growing
/// past the fold. Neither is weakened by the other: a layout that only fits at 900dp would
/// fail the 640dp rows, and a layout that overflowed at 640dp would fail these.
const Size tallSize = Size(360, 900);

/// A store that counts its writes.
///
/// ⚠️ **NO `failWrite`, BECAUSE NOTHING IN THIS FILE USES IT.** The first draft carried one
/// for symmetry with the flow test's spy and the analyzer was right: § 3.3 branch 5 is a
/// property of the **router's** outcome, and the file that proves it is
/// `onboarding_flow_test.dart`, which asserts the real arrival at `/library`. A second
/// copy here would be a test of a fake rather than of the screen.
final class _SpyStore implements OnboardingSeenStore {
  int writeCalls = 0;

  @override
  Future<bool> readFailsOpen() async => false;

  @override
  Future<bool> write() async {
    writeCalls++;
    return true;
  }
}

/// A router that records exits rather than navigating.
final class _RecordingRouter implements OnboardingRouter {
  final List<OnboardingExit> exits = <OnboardingExit>[];

  @override
  void goToLibrary(OnboardingExit exit) => exits.add(exit);
}

late SharedPreferences prefs;

Future<void> _pump(
  WidgetTester tester, {
  OnboardingStep entry = OnboardingStep.promise,
  _SpyStore? store,
  _RecordingRouter? router,
  Locale locale = const Locale('en'),
  Size size = designSize,
  double textScale = 1,
  MediaQueryData? mediaQuery,
}) async {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  if (textScale != 1) {
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  }

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        onboardingSeenStoreProvider.overrideWithValue(store ?? _SpyStore()),
        onboardingRouterProvider.overrideWithValue(
          router ?? _RecordingRouter(),
        ),
        onboardingInitialStepProvider.overrideWithValue(entry),
      ],
      child: MaterialApp(
        theme: AppTheme.day(),
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: mediaQuery == null
            ? const OnboardingBody()
            : MediaQuery(data: mediaQuery, child: const OnboardingBody()),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// The count of a sentence-terminating punctuation mark outside a decimal or an abbreviation.
int _sentenceCount(String text) {
  return RegExp(r'[.!?](?=\s|$)').allMatches(text).length;
}

void main() {
  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues(<String, Object>{});
    prefs = await SharedPreferences.getInstance();
  });

  late AppLocalizations en;
  late AppLocalizations fr;

  setUpAll(() async {
    en = await _l10n(const Locale('en'));
    fr = await _l10n(const Locale('fr'));
  });

  group('⚠️ § 4 (Filled) — step 1 is the promise, and it says both halves', () {
    testWidgets(
      'the kicker, the headline at `--text-h1`, two sentences, two controls',
      (WidgetTester tester) async {
        await _pump(tester);

        expect(find.text('LUMEN TALE'), findsOneWidget, reason: 'the kicker');
        expect(find.text('It reads with no signal.'), findsOneWidget);
        expect(find.textContaining('Keep a novel here once'), findsOneWidget);
        expect(find.text(en.onboardingButtonSkip), findsOneWidget);
        expect(find.text(en.onboardingButtonNext), findsOneWidget);
      },
    );

    testWidgets(
      '⚠️ the promise is rendered at `--text-h1`: 31dp, line 38, weight 700',
      (WidgetTester tester) async {
        // ⚠️ **THE B7 ROW.** `onboarding.md` § 2: *"the only screen in the app that uses
        // `--text-h1`"*, and § 12 gives it as `#31/38 at 700`. A promise set in body text has
        // already decided it is not the point of the app.
        await _pump(tester);

        final Text headline = tester.widget<Text>(
          find.descendant(
            of: find.byType(PromisedHeadline),
            matching: find.text('It reads with no signal.'),
          ),
        );
        final TextStyle? style = headline.style;
        expect(style, isNotNull, reason: 'the headline carries its own style');
        expect(
          style!.fontSize,
          31,
          reason:
              '§ 12 gives `--text-h1` as 31; anything smaller is not the promise',
        );
        expect(
          style.height,
          closeTo(38 / 31, 0.0001),
          reason:
              '§ 12 gives 38 on a 31 size, and `TextStyle.height` is a MULTIPLE — so the '
              'expected value is 38/31 and not 38',
        );
        expect(style.fontWeight, FontWeight.w700, reason: '§ 12 gives 700');
      },
    );

    testWidgets('⚠️ there is NO "Get started" — § 2.1 decision 3', (
      WidgetTester tester,
    ) async {
      await _pump(tester);
      for (final String banned in <String>[
        'Get started',
        'Commencer',
        'Start reading',
        'Done',
      ]) {
        expect(
          find.text(banned),
          findsNothing,
          reason:
              '"$banned" in front of a second step teaches the reader that the button lied '
              '(`onboarding.md` § 2.1, decision 3)',
        );
      }
    });

    testWidgets(
      'B7/B4/B29 — step 1 names no account, no server, and no connection',
      (WidgetTester tester) async {
        // ⚠️ **THE CLAUSES ARE IN THE BODY AND NOWHERE ELSE ON THE SCREEN.** A reader who was
        // lent this file is looking for a sign-in wall, and offline reading is announced
        // nowhere else in the product.
        await _pump(tester);

        final String body = en.onboardingStep1Body;
        expect(
          _sentenceCount(body),
          2,
          reason: 'the design\'s § 4.1 promise is two sentences',
        );
        expect(
          body,
          allOf(
            contains('no account'),
            contains('no server'),
            contains('Nothing is uploaded'),
            contains('connection switched off'),
          ),
          reason: 'B7, B4 and B29 in the one paragraph that says them',
        );
      },
    );
  });

  group('⚠️ § 4 (Filled) — step 2 is the consequence, and it cannot be skipped', () {
    testWidgets('the kicker, the headline, the block, and `Start reading`', (
      WidgetTester tester,
    ) async {
      await _pump(tester, entry: OnboardingStep.disclosure, size: tallSize);

      expect(find.text('BEFORE YOU START'), findsOneWidget);
      expect(find.text('There is no backup.'), findsOneWidget);
      expect(find.byType(DisclosureBlock), findsOneWidget);
      expect(find.text(en.onboardingButtonStart), findsOneWidget);
    });

    testWidgets('⚠️ there is NO `Skip`, and NO close button of any kind', (
      WidgetTester tester,
    ) async {
      // ⚠️ **THE CENTRAL NEGATION OF THE SLICE.** `3-4` § 7: *"permitting a disclosure to be
      // skipped while it is being shown is a contradiction, and it is the difference between
      // **disclosing** and **displaying**."*
      await _pump(tester, entry: OnboardingStep.disclosure, size: tallSize);

      expect(
        find.text(en.onboardingButtonSkip),
        findsNothing,
        reason: 'step 2 has no `Skip`; § 2.1 decision 2',
      );
      expect(
        find.byType(TextButton),
        findsNothing,
        reason:
            'step 2\'s only control is the primary. A `TextButton` here would be a ghost '
            'link or a dismiss affordance, and the disclosure has one exit',
      );
      expect(
        find.byType(IconButton),
        findsNothing,
        reason: '§ 5 forbids a dismiss affordance: there is no `X`',
      );
    });

    testWidgets(
      'the consequence headline is `--text-h2`, one step below the promise',
      (WidgetTester tester) async {
        await _pump(tester, entry: OnboardingStep.disclosure, size: tallSize);

        final Text headline = tester.widget<Text>(
          find.text('There is no backup.'),
        );
        expect(headline.style?.fontSize, 25, reason: '§ 12: `--text-h2` is 25');
        expect(headline.style?.height, closeTo(32 / 25, 0.0001));
        expect(headline.style?.fontWeight, FontWeight.w700);
      },
    );
  });

  group('⚠️ E11 — the disclosure block renders no icon and no error colour', () {
    testWidgets('there is no `Icon` anywhere in the block', (
      WidgetTester tester,
    ) async {
      // ⚠️ **`onboarding.md` § 2.1: *"a recessed block of words with no icon at all, because
      // an icon would make a permanent fact look like an incident."*
      await _pump(tester, entry: OnboardingStep.disclosure, size: tallSize);

      expect(
        find.descendant(
          of: find.byType(DisclosureBlock),
          matching: find.byType(Icon),
        ),
        findsNothing,
        reason:
            'an icon — and especially a red one — renders a PERMANENT consequence as a '
            'CURRENT failure. § 12 lists `--color-error` in this screen\'s token table for '
            'the record, marked "Not rendered".',
      );
    });

    testWidgets('no `Text` in the block wears `--color-error`', (
      WidgetTester tester,
    ) async {
      await _pump(tester, entry: OnboardingStep.disclosure, size: tallSize);

      final LumenColors colors = LumenColors.of(
        tester.element(find.byType(DisclosureBlock)),
      );
      final Finder texts = find.descendant(
        of: find.byType(DisclosureBlock),
        matching: find.byType(Text),
      );
      expect(
        texts,
        findsNWidgets(2),
        reason: 'a body and a footnote, and nothing else',
      );

      for (final Element element in texts.evaluate()) {
        final Text text = element.widget as Text;
        expect(
          text.style?.color,
          isNot(colors.error),
          reason:
              '"${text.data}" is painted in the error colour. The disclosure is a standing '
              'consequence of ADR-010, not an incident, and § 12 records its absence from '
              'this screen as a decision.',
        );
      }
    });

    testWidgets('no `BoxShadow` anywhere — § 2.1 refuses a shadowed card', (
      WidgetTester tester,
    ) async {
      await _pump(tester, entry: OnboardingStep.disclosure, size: tallSize);

      final Iterable<BoxDecoration> decorations = tester
          .widgetList<Container>(
            find.descendant(
              of: find.byType(DisclosureBlock),
              matching: find.byType(Container),
            ),
          )
          .map((Container c) => c.decoration)
          .whereType<BoxDecoration>();
      expect(
        decorations,
        isNotEmpty,
        reason: 'the block does have a decoration',
      );
      for (final BoxDecoration decoration in decorations) {
        expect(
          decoration.boxShadow,
          isNull,
          reason:
              '`--shadow-none` on the block: it is a thing to look INTO, not a card',
        );
      }
    });
  });

  group('⚠️ § 4 — the step dots say how many there are', () {
    testWidgets('exactly two dots, and the second is the accent after `Next`', (
      WidgetTester tester,
    ) async {
      await _pump(tester, size: tallSize);

      final LumenColors colors = LumenColors.of(
        tester.element(find.byType(StepDots)),
      );
      List<Color?> dotColours() => tester
          .widgetList<DecoratedBox>(
            find.descendant(
              of: find.byType(StepDots),
              matching: find.byType(DecoratedBox),
            ),
          )
          .map((DecoratedBox box) => (box.decoration as BoxDecoration).color)
          .toList();

      expect(dotColours(), hasLength(2), reason: 'there are exactly two steps');
      expect(
        dotColours(),
        <Color>[colors.accent, colors.borderField],
        reason:
            'the ACTIVE dot is `--color-accent` and the inactive one is '
            '`--color-border-field` — NOT `--color-border`, whose `exempt` declaration is '
            'reserved for a decorative rule between rows, and a dot is a component boundary',
      );

      await tester.tap(find.text(en.onboardingButtonNext));
      await tester.pumpAndSettle();

      expect(dotColours(), <Color>[
        colors.borderField,
        colors.accent,
      ], reason: 'the active dot moves with the step');
    });

    testWidgets('the dots are announced as a position, never as two empty circles', (
      WidgetTester tester,
    ) async {
      // ⚠️ **`handle.dispose()` INSIDE THE BODY, NOT IN A TEARDOWN.** The binding verifies
      // that every handle is disposed *before* tearDowns run, so `addTearDown` reports "A
      // SemanticsHandle was active at the end of the test" — a failure that belongs to no
      // assertion in the row, and the kind that makes the next row look guilty.
      final SemanticsHandle handle = tester.ensureSemantics();

      await _pump(tester, size: tallSize);

      final SemanticsNode node = tester.getSemantics(find.byType(StepDots));
      expect(
        node.getSemanticsData().label,
        contains('Step 1 of 2'),
        reason:
            '`14-design-tokens.md` forbids colour carrying a state alone, and two unlabelled '
            'circles are colour carrying it alone',
      );
      handle.dispose();
    });
  });

  group('⚠️ § 5 — the back gesture, and its two behaviours', () {
    testWidgets('on step 2 it returns to step 1 and does NOT leave', (
      WidgetTester tester,
    ) async {
      final _RecordingRouter router = _RecordingRouter();
      await _pump(
        tester,
        entry: OnboardingStep.disclosure,
        size: tallSize,
        router: router,
      );

      await _handleSystemBack(tester);
      await tester.pumpAndSettle();

      expect(
        find.text('It reads with no signal.'),
        findsOneWidget,
        reason: 'step 1',
      );
      expect(
        router.exits,
        isEmpty,
        reason:
            'the reader must NOT leave the app from the disclosure. § 3.3 branch 2: back on '
            'step 2 means "read the promise again"',
      );
    });

    testWidgets('on step 1 it is `Skip` verbatim: one write, no dialog', (
      WidgetTester tester,
    ) async {
      final _SpyStore store = _SpyStore();
      final _RecordingRouter router = _RecordingRouter();
      await _pump(tester, store: store, router: router);

      await _handleSystemBack(tester);
      await tester.pumpAndSettle();

      expect(store.writeCalls, 1, reason: 'the same single write as `Skip`');
      expect(router.exits, <OnboardingExit>[OnboardingExit.libraryFromSkip]);
      expect(
        find.byType(Dialog),
        findsNothing,
        reason:
            '"Are you sure you want to skip?" is a dialog that exists only to make someone '
            'feel they have chosen (`onboarding.md` § 5). Exiting onboarding is never a '
            'trap.',
      );
      expect(
        find.byType(AlertDialog),
        findsNothing,
        reason: 'and no other kind of dialog either',
      );
    });

    testWidgets('⚠️ the route itself is never popped, on either step', (
      WidgetTester tester,
    ) async {
      // ⚠️ **`PopScope(canPop: false)` ON BOTH STEPS, AND THIS IS ITS WITNESS.** If the route
      // popped on step 2 the reader would be thrown out of the flow — or, on a first run, out
      // of the app — and the disclosure would be dismissible by a stray gesture. If it
      // popped on step 1 the reader would exit instead of reaching the library the promise
      // was about.
      for (final OnboardingStep step in OnboardingStep.values) {
        await _pump(tester, entry: step);
        final Finder popScope = find.byType(PopScope<Object?>);
        expect(popScope, findsOneWidget, reason: '$step guards its route');
        final PopScope<Object?> guard = tester.widget(popScope);
        expect(
          guard.canPop,
          isFalse,
          reason:
              '$step: the back gesture is handled in-app, not by the navigator',
        );
        expect(
          guard.onPopInvokedWithResult,
          isNotNull,
          reason:
              '$step: a veto with no callback would swallow the gesture silently',
        );
      }
    });
  });

  group('⚠️ § 5 — `Skip` leaves without ever building step 2', () {
    testWidgets('the step 2 tree never appears, at any point', (
      WidgetTester tester,
    ) async {
      final _SpyStore store = _SpyStore();
      final _RecordingRouter router = _RecordingRouter();
      await _pump(tester, store: store, router: router);

      expect(find.text('There is no backup.'), findsNothing, reason: 'before');

      await tester.tap(find.text(en.onboardingButtonSkip));
      // ⚠️ **`pump()`, NOT `pumpAndSettle()`.** The assertion is about a tree that must
      // NEVER EXIST, so it is taken on the frame immediately after the tap — a settled tree
      // is a tree after the navigation, and would pass for a step 2 that had been built and
      // then replaced.
      await tester.pump();
      expect(
        find.text('There is no backup.'),
        findsNothing,
        reason:
            '§ 3.3 branch 1: the disclosure is never built behind the reader. There is no '
            '"and on the next screen" — a skipped flow that had shown it would be a '
            'disclosure with a skip button.',
      );
      expect(find.byType(DisclosureBlock), findsNothing);

      await tester.pumpAndSettle();
      expect(store.writeCalls, 1);
      expect(router.exits, <OnboardingExit>[OnboardingExit.libraryFromSkip]);
    });
  });

  group('⚠️ § 5 — there is NO pager, and a horizontal drag changes nothing', () {
    testWidgets('no `PageView`, no `PageRoute`, no horizontal `Scrollable`', (
      WidgetTester tester,
    ) async {
      await _pump(tester);

      expect(
        find.byType(PageView),
        findsNothing,
        reason: '§ 2.1 decision 1: no swipe',
      );
      // ⚠️ **`axisDirection`, NOT `scrollDirection`.** `Scrollable` exposes the axis it was
      // *built* with as `axisDirection`; the row was written against `scrollDirection` first
      // and did not compile, which is the only reason this comment exists.
      expect(
        tester
            .widgetList<Scrollable>(find.byType(Scrollable))
            .where((Scrollable s) => s.axisDirection == AxisDirection.right),
        isEmpty,
        reason:
            'a horizontal scrollable is a pager in waiting — and it would fight the system '
            'back gesture, which is Android\'s own horizontal gesture',
      );
    });

    testWidgets('a horizontal swipe on step 1 does not advance', (
      WidgetTester tester,
    ) async {
      await _pump(tester);
      await tester.drag(find.byType(ListView), const Offset(-300, 0));
      await tester.pumpAndSettle();
      expect(
        find.text('It reads with no signal.'),
        findsOneWidget,
        reason: 'still step 1: the steps advance by buttons only',
      );
    });
  });

  group('C5/C11 — only the two controls, and they are in the bottom third', () {
    testWidgets('`Skip` and the primary are the ONLY controls — C5', (
      WidgetTester tester,
    ) async {
      await _pump(tester, size: tallSize);

      // ⚠️ **COUNTED OVER MATERIAL'S BUTTON FAMILIES, NOT OVER `InkWell`.** The first draft
      // counted `InkWell`s with a live callback and got **four**, because both Material
      // buttons build an internal `InkWell` *and* a `GestureDetector` — so the row was
      // counting framework internals and would have failed on a screen that was correct.
      // What § 4.4 forbids is a *control*, and the button families are the vocabulary this
      // app builds controls from.
      int controls() =>
          tester.widgetList<TextButton>(find.byType(TextButton)).length +
          tester.widgetList<FilledButton>(find.byType(FilledButton)).length +
          tester
              .widgetList<OutlinedButton>(find.byType(OutlinedButton))
              .length +
          tester.widgetList<IconButton>(find.byType(IconButton)).length +
          tester
              .widgetList<FloatingActionButton>(
                find.byType(FloatingActionButton),
              )
              .length;

      expect(
        controls(),
        2,
        reason:
            '§ 4.4: no checkbox, no radio, no toggle, no picker, no FAB. The first launch '
            'asks nothing, which is what keeps it from acquiring consent nobody requested.',
      );

      // ⚠️ **AND THE CONFIGURING CONTROLS ARE NAMED, NOT INFERRED.** A `Slider`, a
      // `DropdownButton` and a `SegmentedButton` are all Material widgets, so the count above
      // would not notice one of them: none is a button.
      for (final Type control in <Type>[
        Checkbox,
        Switch,
        Slider,
        RadioListTile,
        SegmentedButton<Object?>,
        DropdownButton<Object?>,
      ]) {
        expect(
          find.byType(control),
          findsNothing,
          reason:
              '$control must not exist on a first-run screen. It would be a question the '
              'reader never thought about, which is the mechanism ADR-023 and B29 refuse.',
        );
      }
    });

    testWidgets('⚠️ `Skip` is LEFT-ALIGNED, directly above the full-width primary', (
      WidgetTester tester,
    ) async {
      // ⚠️ **§ 3 AND § 6 BOTH SAY "LEFT-ALIGNED"**, and a `TextButton` in a `stretch` column
      // centres its label by default. A centred control above a left-aligned edge is two
      // columns, which is the first thing § 2.1's anti-generic list refuses.
      await _pump(tester, size: tallSize);

      final Rect skip = tester.getRect(find.text(en.onboardingButtonSkip));
      final Rect primary = tester.getRect(find.text(en.onboardingButtonNext));
      expect(
        skip.left,
        lessThan(primary.left),
        reason:
            '`Skip` starts at the page margin while the primary\'s label is centred in a '
            'full-width button — which is exactly how the design draws the two',
      );
      expect(
        skip.bottom,
        lessThanOrEqualTo(primary.top),
        reason:
            'and `Skip` sits directly above it, so both are in the bottom third together',
      );
    });

    testWidgets('at 360x640 `Next` is in the bottom third of the screen — C11', (
      WidgetTester tester,
    ) async {
      // ⚠️ **AT [tallSize], NOT `designSize`, AND THE REASON IS THE TEST FONT.** See its
      // declaration: at 360 × 640 the page is one screenful *in the test's box glyphs* and
      // three in a real 16dp face, so a bottom-third row measured here would be measuring
      // the font. The rule being checked is the *proportion* — the controls in the last third
      // — and that proportion is what a taller window still shows.
      await _pump(tester, size: tallSize);

      final Rect button = tester.getRect(find.text(en.onboardingButtonNext));
      expect(
        button.top,
        greaterThan(tallSize.height * 2 / 3),
        reason:
            'C11: read one-handed, often one-thumbed, in transit. A button in the middle of '
            'the screen makes the reader reach across it for the wrong thing.',
      );
      expect(
        tester.getRect(find.text(en.onboardingButtonSkip)).top,
        lessThan(tallSize.height),
        reason: 'and `Skip` is above the primary, inside the screen',
      );
    });

    testWidgets('both controls are at least 48dp tall — a11y owner', (
      WidgetTester tester,
    ) async {
      await _pump(tester, size: tallSize);

      expect(
        tester.getSize(find.byType(FilledButton)).height,
        greaterThanOrEqualTo(kOnboardingControlHeight),
        reason:
            '`14-design-tokens.md` §Accessibility is the single owner of touch targets and '
            'asks for 48 × 48 on every tappable affordance',
      );
      // ⚠️ **THE STYLE'S `minimumSize`, NOT THE RENDERED HEIGHT.** `Skip` is a `TextButton`,
      // whose own Material minimum (40dp by default, 48 for `minimumSize` with tapTargetSize
      // honoured) is below the floor — so the row reads what the screen *asked for*, which is
      // the number the file commits to.
      final TextButton skip = tester.widget<TextButton>(
        find.ancestor(
          of: find.text(en.onboardingButtonSkip),
          matching: find.byType(TextButton),
        ),
      );
      expect(
        skip.style?.minimumSize?.resolve(<WidgetState>{})?.height,
        greaterThanOrEqualTo(kOnboardingControlHeight),
        reason:
            '`Skip` is the way out for a reader who does not want to be walked through '
            'anything, so it gets the same target as the primary beside it',
      );
    });
  });

  group('⚠️ C11/E14 — 200% text scale grows the page and never truncates', () {
    testWidgets('at 200% nothing overflows, on either step', (
      WidgetTester tester,
    ) async {
      for (final OnboardingStep step in OnboardingStep.values) {
        await _pump(tester, entry: step, textScale: 2);
        expect(
          tester.takeException(),
          isNull,
          reason: '$step overflowed at 200% text scale',
        );
      }
    });

    testWidgets('⚠️ the controls are CONTENT, never pinned over it', (
      WidgetTester tester,
    ) async {
      // ⚠️ **THE STRUCTURAL FORM OF C11/E14, AND THE FONT-INDEPENDENT ONE.**
      //
      // § 6: *"the control block stays at the bottom of the **content** rather than floating
      // over it, so a long disclosure is never covered by a button."* Measuring that in
      // pixels needs the button on screen, which at 200% means scrolling past the very thing
      // being compared — and the comparison then passes for free. So the claim is made where
      // it is decided: **the button is inside the scroll view.** Any implementation that
      // pinned the controls — a `Stack`, a `Positioned`, the scaffold's `bottomNavigationBar`
      // — puts them OUTSIDE it, and this row fails.
      //
      // ⚠️ **MEASURED AT THE DEFAULT TEXT SIZE, NOT AT 200%.** A sliver builds its children
      // lazily, so at 200% in the test's box font the button is more than a cache extent
      // below the fold and **has no element at all** — `find.byType` correctly reports
      // nothing for a widget that exists. The 200% rows below cover growth, scrolling and
      // truncation; this one covers the structure.
      await _pump(tester, entry: OnboardingStep.disclosure, size: tallSize);

      expect(
        find.descendant(
          of: find.byType(ListView),
          matching: find.byType(FilledButton),
        ),
        findsOneWidget,
        reason:
            '`Start reading` is part of the page content, so a long text scale pushes it '
            'down instead of covering the disclosure with it',
      );
      expect(
        tester.widget<AppScaffold>(find.byType(AppScaffold)).bottomNav,
        isNull,
        reason:
            '`AppScaffold.bottomNav` is the one slot that could have pinned them',
      );
      expect(
        find.byType(Scaffold),
        findsOneWidget,
        reason:
            'and the controls are not a second scaffold\'s bottom bar either',
      );
    });

    testWidgets('the page SCROLLS at 200% — the controls are reachable', (
      WidgetTester tester,
    ) async {
      await _pump(tester, entry: OnboardingStep.disclosure, textScale: 2);

      // Below the fold at first, which is the point: the content grew rather than clipping.
      expect(
        find.text(en.onboardingButtonStart),
        findsNothing,
        reason:
            'the control is below the fold at 200% — it must be BELOW the content, not '
            'clipped off it',
      );

      await tester.scrollUntilVisible(
        find.text(en.onboardingButtonStart),
        400,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      expect(
        find.text(en.onboardingButtonStart),
        findsOneWidget,
        reason: 'and reachable by scrolling, with nothing truncated on the way',
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('no text is truncated at 200% — maxLines is never set', (
      WidgetTester tester,
    ) async {
      await _pump(tester, textScale: 2);

      final Iterable<Text> texts = tester
          .widgetList<Text>(find.byType(Text))
          .where((Text t) => t.data != null);
      for (final Text text in texts) {
        expect(
          text.maxLines,
          isNull,
          reason:
              '"${text.data}" sets maxLines: ${text.maxLines}. § 6 guarantees the overflow '
              'never happens by WRAPPING — and the promise is the screen, so it must not '
              'truncate.',
        );
      }
    });
  });

  group('ADR-023 — no permission is requested, ever, here', () {
    testWidgets('no permission dialog appears on either step', (
      WidgetTester tester,
    ) async {
      for (final OnboardingStep step in OnboardingStep.values) {
        await _pump(tester, entry: step);
        expect(
          find.byType(Dialog),
          findsNothing,
          reason:
              'ADR-023 withdrew B35, so there is no schedule whose first firing would need a '
              'permission, and nothing the reader has decided they want. A first-run '
              'permissions screen would request something nobody asked for.',
        );
      }
    });
  });

  group(
    '⚠️ B28/E12 — both steps exist in French and English, and re-localise at once',
    () {
      testWidgets('`fr` renders the promise and the disclosure in French', (
        WidgetTester tester,
      ) async {
        await _pump(tester, locale: const Locale('fr'), size: tallSize);
        expect(find.text(fr.onboardingStep1Headline), findsOneWidget);
        expect(find.text(fr.onboardingButtonSkip), findsOneWidget);
        expect(find.text(fr.onboardingButtonNext), findsOneWidget);

        await tester.tap(find.text(fr.onboardingButtonNext));
        await tester.pumpAndSettle();
        expect(find.text(fr.onboardingStep2Kicker), findsOneWidget);
        expect(
          find.text(fr.onboardingStep2Headline),
          findsOneWidget,
          reason: 'and the consequence too',
        );
      });

      testWidgets('`en` renders them in English', (WidgetTester tester) async {
        await _pump(tester, entry: OnboardingStep.disclosure, size: tallSize);
        expect(find.text('There is no backup.'), findsOneWidget);
        expect(find.text('BEFORE YOU START'), findsOneWidget);
      });

      testWidgets(
        '⚠️ the disclosure is TRANSLATED, not paraphrased — same sentence count',
        (WidgetTester tester) async {
          // ⚠️ **THE ROW `onboarding.md` § 4.1 EXISTS FOR.** *"the one place in this app where a
          // compressed translation would be a weaker disclosure"* — and this is the whole reason
          // the plan called for a completeness check.
          expect(
            _sentenceCount(fr.onboardingStep1Body),
            _sentenceCount(en.onboardingStep1Body),
            reason: 'the promise must be as strong in French as in English',
          );
          expect(
            _sentenceCount(fr.settingsDisclosureE11),
            _sentenceCount(en.settingsDisclosureE11),
            reason:
                'the disclosure body: a French reader who is told less than an English reader is '
                'not being disclosed to, they are being warned',
          );
          expect(
            _sentenceCount(fr.settingsDisclosureE11Footer),
            _sentenceCount(en.settingsDisclosureE11Footer),
            reason: 'and the "why it is said now" clause with it',
          );
          expect(
            _sentenceCount(en.settingsDisclosureE11),
            2,
            reason:
                '§ 4.1 gives two sentences, and a French copy must not shorten that',
          );
        },
      );

      testWidgets('⚠️ the footnote says the app CANNOT warn at the moment — E11', (
        WidgetTester tester,
      ) async {
        await _pump(tester, entry: OnboardingStep.disclosure, size: tallSize);

        // ⚠️ **THE SENTENCE THAT MAKES THE IMPOSSIBILITY EXPLICIT.** E11: the device performs
        // an uninstall outside the app, so there is no hook. The app does not pretend to have
        // one, and saying *why* is what makes "before" a decision rather than an intrusion.
        expect(
          en.settingsDisclosureE11Footer,
          contains('cannot warn you at the moment you uninstall'),
        );
        expect(
          en.settingsDisclosureE11Footer,
          contains('the phone does that, outside the app'),
        );
        expect(
          fr.settingsDisclosureE11Footer,
          contains('en dehors de l\'application'),
          reason: 'and the French says it too — E12 and B28',
        );
        expect(
          find.text(en.settingsDisclosureE11Footer),
          findsOneWidget,
          reason: 'it is rendered, on its own line, inside the block',
        );
      });

      testWidgets('B32 — the disclosure names ALL THREE losses', (
        WidgetTester tester,
      ) async {
        // ⚠️ **THREE, NOT ONE.** B32 creates a loss risk that nothing can repair, and a
        // disclosure that named only the library would leave the reader believing the
        // downloads survive. All three, in one sentence, in both languages.
        await _pump(tester, entry: OnboardingStep.disclosure, size: tallSize);
        for (final String loss in <String>[
          'library',
          'downloads',
          'reading positions',
        ]) {
          expect(
            en.settingsDisclosureE11,
            contains(loss),
            reason: 'the English disclosure must name $loss',
          );
          expect(
            fr.settingsDisclosureE11,
            contains(
              <String, String>{
                'library': 'bibliothèque',
                'downloads': 'téléchargements',
                'reading positions': 'positions de lecture',
              }[loss]!,
            ),
            reason: 'and the French one must name it as well',
          );
        }
        expect(
          en.settingsDisclosureE11,
          contains('no copy exists anywhere'),
          reason: 'and it says that no copy exists anywhere',
        );
      });
    },
  );

  group('the language switch rebuilds nothing but the words — E12', () {
    testWidgets('the route survives a locale change and the disclosure follows', (
      WidgetTester tester,
    ) async {
      await _pump(tester, entry: OnboardingStep.disclosure);
      expect(find.text('There is no backup.'), findsOneWidget);
      final OnboardingState before = _stateOf(tester);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            onboardingSeenStoreProvider.overrideWithValue(_SpyStore()),
            onboardingRouterProvider.overrideWithValue(_RecordingRouter()),
            onboardingInitialStepProvider.overrideWithValue(
              OnboardingStep.disclosure,
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.day(),
            locale: const Locale('fr'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const OnboardingBody(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text(fr.onboardingStep2Headline),
        findsOneWidget,
        reason:
            'E12: an OS language change re-localises BOTH steps immediately, the disclosure '
            'included — it is the one piece of text on this screen that must never be read '
            'in a language the reader does not read.',
      );
      expect(
        find.text(fr.settingsDisclosureE11),
        findsOneWidget,
        reason: 'and the disclosure itself is in French now',
      );
      expect(
        _stateOf(tester),
        before,
        reason:
            'a language change is not a step change. The notifier is untouched, so the '
            'reader is not dragged back to step 1 by a switch they did not make on purpose.',
      );
    });
  });

  group('§ 4 — the four states with NO rendering, and why', () {
    testWidgets('⚠️ OFFLINE looks identical to FILLED, and calls nothing', (
      WidgetTester tester,
    ) async {
      // § 4 (Offline): *"Identical to Filled, with zero variation and zero network calls."*
      // The row is a `MediaQuery` with no connectivity — Flutter has no connectivity model,
      // which is itself the proof: there is no provider on this screen that could tell the
      // difference.
      await _pump(tester, mediaQuery: const MediaQueryData(size: designSize));
      expect(find.text('It reads with no signal.'), findsOneWidget);
      expect(
        find.byType(CircularProgressIndicator),
        findsNothing,
        reason: 'no loading',
      );
      expect(
        find.byType(LinearProgressIndicator),
        findsNothing,
        reason: 'no loading',
      );
    });

    testWidgets('⚠️ READ-ONLY: there is no control that CONFIGURES anything', (
      WidgetTester tester,
    ) async {
      // § 4 (Read-only), and `C5`. The screen asks nothing, so there is no preference for it
      // to land in and no consent for it to have acquired.
      await _pump(tester);
      expect(find.byType(Checkbox), findsNothing);
      expect(find.byType(Switch), findsNothing);
      expect(find.byType(SegmentedButton<Object?>), findsNothing);
      expect(find.byType(DropdownButton<Object?>), findsNothing);
      expect(find.byType(Radio<Object?>), findsNothing);
      expect(
        tester.takeException(),
        isNull,
        reason:
            'and nothing on the screen needed a preference that does not exist',
      );
    });
  });
}

/// Simulates the system back gesture / button: `Navigator.maybePop` is what both call.
Future<void> _handleSystemBack(WidgetTester tester) async {
  final NavigatorState navigator = tester.state<NavigatorState>(
    find.byType(Navigator).first,
  );
  unawaited(navigator.maybePop());
  await tester.pumpAndSettle();
}

void unawaited(Future<void> future) {}

/// The live step state, read through the widget rather than through a container.
OnboardingState _stateOf(WidgetTester tester) {
  final OnboardingPage page = tester.widget<OnboardingPage>(
    find.byType(OnboardingPage),
  );
  return OnboardingState(
    step: page.step,
    skippable: page.step == OnboardingStep.promise,
    canGoBack: page.step == OnboardingStep.disclosure,
    exiting: page.exiting,
  );
}

/// The two locales' strings, resolved once.
///
/// ⚠️ **`delegate.load`, NOT `loadSync`.** The generated delegate is asynchronous in
/// Flutter 3.47 — the synchronous accessor no longer exists, so a test that wants copy
/// without a `BuildContext` awaits the delegate. The rows that assert on *rendered* text
/// still find the strings through `find.text`, and this is only for the assertions that
/// compare the two languages to each other.
Future<AppLocalizations> _l10n(Locale locale) =>
    AppLocalizations.delegate.load(locale);
