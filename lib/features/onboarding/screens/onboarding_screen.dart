// Lumen Tale — `/onboarding`: two steps, a promise and a consequence, and no way past
// the second one.
//
// `onboarding.md`. **Outside the shell** — no tab bar, no title bar — so it is registered
// as a standalone route and reaches `app/` by its path alone (`app_router.dart`'s header
// says why).
//
// ## ⚠️ FOUR DECISIONS, EACH OF WHICH COULD HAVE GONE THE OTHER WAY
//
// 1. **No swipe.** The steps advance by buttons. A horizontal pager fights Android's back
//    gesture, and a reader swiping back from step 2 expects to leave the app and gets a
//    step change instead. The dot pair says *"there are exactly two"*, which is the only
//    thing a pager would have communicated.
// 2. **`Skip` is on step 1 only.** Step 2 *is* the disclosure; skipping a disclosure while
//    showing it is a contradiction. The reader is therefore never offered a way to dismiss
//    it without reading it.
// 3. **The primary action on step 1 is `Next`, not `Get started`.** A button that reads
//    "Get started" in front of a second step teaches the reader that the button lied.
// 4. **No settings, no questions, no permissions.** Every setting keeps its default, and
//    every default is visible and changeable in Settings afterwards. ADR-023 withdrew the
//    one schedule whose first firing would have needed a permission, so at first run there
//    is nothing the reader has decided they want — and a first-run permissions screen would
//    be requesting something nobody asked for.
//
// ## ⚠️ NO EMPTY LIBRARY HERE, NO LOADING STATE, NO ERROR STATE
//
// `onboarding.md` § 4 gives a rendering to all nine states and **four of them have none**,
// each with a reason: nothing loads (the strings are compiled ARB resources), there is no
// data to be empty, the only submission is one boolean and a failure to write it still
// transitions, and step 1 configures nothing. The nearest thing to an empty state is the
// app's own empty library, and this screen deliberately does not render it — `/library`'s
// `library-empty` is the design system's named rendering of that fact.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:lumen_tale/app/theme/lumen_colors.dart';
import 'package:lumen_tale/app/theme/lumen_radius.dart';
import 'package:lumen_tale/app/theme/lumen_spacing.dart';
import 'package:lumen_tale/core/ui/app_scaffold.dart';
import 'package:lumen_tale/features/onboarding/domain/onboarding_state.dart';
import 'package:lumen_tale/features/onboarding/providers/onboarding_seen.dart';
import 'package:lumen_tale/features/onboarding/widgets/disclosure_block.dart';
import 'package:lumen_tale/features/onboarding/widgets/onboarding_type.dart';
import 'package:lumen_tale/l10n/generated/app_localizations.dart';

/// `/onboarding`, and the only place the router's startup decision becomes a widget.
///
/// ## ⚠️ THE `initialStep` IS AN ARGUMENT, NOT A FLAG READ
///
/// The router redirects a first run to `/onboarding`; Settings pushes
/// `/onboarding?step=disclosure`. The difference is **handed to** the screen rather than
/// worked out inside it, so there is one place that knows what a re-entry is and no second
/// one that could decide otherwise — and so the screen can be pumped at either step in a
/// test with no preferences and no store.
class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key, required this.initialStep});

  /// **Step 1 on a first run, step 2 on a re-read from Settings.**
  final OnboardingStep initialStep;

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      // ⚠️ **A NESTED `ProviderScope` IS HOW THE ROUTER GETS IN.** `05-state-management.md`
      // rule 7 prefers an explicit override over a global singleton, and
      // `onboardingRouterProvider` needs a `BuildContext` that only an element under the
      // router has. The scope is nested rather than passed down because the notifier is
      // read several levels below, and threading a context to it would make the state
      // machine depend on its screen's tree shape.
      overrides: [
        onboardingRouterProvider.overrideWithValue(
          GoRouterOnboardingRouter(context),
        ),
        // ⚠️ **AND THE ENTRY STEP, WHICH IS THE OTHER HALF OF THE SAME OVERRIDE LIST.** The
        // notifier's initial state is derived from this provider rather than from a
        // constructor argument, because `Notifier.build()` takes none — and deriving it
        // means each step's *whole* state (including `skippable` and `canGoBack`) is named
        // in one place instead of being assembled here from two flags that could arrive in
        // a combination the design never described.
        onboardingInitialStepProvider.overrideWithValue(initialStep),
      ],
      child: const OnboardingBody(),
    );
  }
}

/// The frame — **no title bar, no tab bar, and the system back gesture intercepted**.
///
/// `design-system.md` § 2.8's six slots with two of them empty. The reason is in the file
/// header: this is a first-run flow outside the tab structure, and a title bar carrying
/// the app's name above a page whose own kicker already says it would say the same thing
/// twice.
class OnboardingBody extends ConsumerWidget {
  const OnboardingBody({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppScaffold(
      // ⚠️ **NEITHER SLOT IS PASSED, AND `state` STAYS `normal`.** Both are `null`/`true`
      // defaults, so omitting them is what says "empty" — writing `titleBar: null` reads as
      // an oversight of the same shape as the omission, and `avoid_redundant_argument_values`
      // is right that they say the same thing. `immersive` would also suppress the bar, but
      // it names the reader's chrome: this screen has no chrome, it has two words and two
      // buttons.
      content: PopScope<Object?>(
        // ⚠️ **`canPop: false` ON **BOTH** STEPS, AND THIS IS THE WHOLE OF THE BACK RULE.**
        //
        // The system back gesture is **not** a route pop on this screen, and neither step
        // lets it be:
        //
        // - step 2: back goes **backwards** to the promise. Popping would leave the
        //   onboarding flow — or, on a first run, leave the app — and the disclosure must
        //   not be dismissible by a stray gesture.
        // - step 1: back is **`Skip` verbatim**, and `Skip` writes the flag and goes to
        //   `/library`. Letting it pop would exit the app instead, so the reader would
        //   never see the library the promise was about.
        //
        // `canPop: false` is what makes this work: it vetoes `Navigator.maybePop`, which is
        // what the back button and the gesture both call, and `onPopInvokedWithResult` is
        // then told the pop was **cancelled** (`didPop == false`). Using `BackButton` here
        // would have been the obvious alternative and it is forbidden: it renders an
        // `Icon`, and § 2.1 says *"No icon is rendered on either step."*
        canPop: false,
        onPopInvokedWithResult: (bool didPop, Object? _) {
          // ⚠️ **`didPop` IS GUARDED EVEN THOUGH `canPop: false` MAKES IT ALWAYS FALSE.**
          // A guard that reads as redundant is the guard that survives a future edit to
          // `canPop`; without it, the day somebody lets this route pop, the screen would
          // write the flag *and* be dismissed by the same gesture.
          if (didPop) {
            return;
          }
          ref.read(onboardingStepProvider.notifier).back();
        },
        child: const _Page(),
      ),
    );
  }
}

/// Watches the one provider and forwards its four methods. **No decisions.**
class _Page extends ConsumerWidget {
  const _Page();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final OnboardingStepNotifier notifier = ref.read(
      onboardingStepProvider.notifier,
    );
    final OnboardingState state = ref.watch(onboardingStepProvider);

    return OnboardingPage(
      step: state.step,
      exiting: state.exiting,
      onNext: notifier.next,
      onSkip: notifier.skip,
      onBack: notifier.back,
      onStartReading: notifier.startReading,
    );
  }
}

/// One column, the measure capped, the controls **at the end of the content**.
///
/// ⚠️ **`ListView`, NOT A `COLUMN` WITH A `SPACER`.** "Put the controls in the bottom third"
/// is a layout *preference*; at 200% text scale the content is taller than the screen, and
/// a `Spacer` inside a scroll view's column is unbounded in the scroll direction — the
/// buttons would be pushed past the end of an unbounded page. Ending the content with the
/// controls satisfies the design at the default size and keeps them **below** the text
/// rather than over it at any size.
///
/// ⚠️ **THE CAP IS A CONSTANT, NOT A BREAKPOINT.** `design-system.md` § 6: past
/// `--bp-mobile` the layout *"simply stops widening"* (ADR-019 — no tablet layout, no rail,
/// no two panes).
class _OnboardingColumn extends StatelessWidget {
  const _OnboardingColumn({
    required this.children,
    required this.dots,
    required this.control,
  });

  final List<Widget> children;
  final Widget dots;
  final Widget control;

  /// `--space-lg` of page margin on a 360dp phone leaves ~328dp of measure, which is the
  /// band `design-system.md` § 6 names. A constant, so the cap is one number rather than a
  /// subtraction that a padding change could silently alter.
  static const double maxMeasure = 360;

  @override
  Widget build(BuildContext context) {
    final LumenSpacing spacing = LumenSpacing.of(context);

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: maxMeasure),
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            spacing.lg,
            spacing.xl3,
            spacing.lg,
            spacing.xl3,
          ),
          children: <Widget>[
            dots,
            SizedBox(height: spacing.xl),
            ...children,
            SizedBox(height: spacing.xl3),
            control,
          ],
        ),
      ),
    );
  }
}

/// The two renderings, as data the page draws. **No `PageView`, no `AnimatedSwitcher`.**
///
/// ⚠️ **THE STEP CHANGE IS AN INSTANT CONTENT SWAP.** `onboarding.md` § 5 allows
/// `--duration-normal` 200ms for it, and this screen uses **no** animation at all: a
/// cross-fade would put the disclosure behind a half-drawn fade, and E11's whole claim is
/// that the reader must see it. Reduce-motion is therefore honoured trivially — there is
/// nothing to disable — and `tester.pumpAndSettle` cannot hang on a future animation
/// nobody asked for.
class OnboardingPage extends StatelessWidget {
  const OnboardingPage({
    super.key,
    required this.step,
    required this.exiting,
    required this.onNext,
    required this.onSkip,
    required this.onBack,
    required this.onStartReading,
  });

  final OnboardingStep step;

  /// Whether an exit is in flight — the button's loading state (`3-4` § 3.3 branch 5).
  final bool exiting;

  final VoidCallback onNext;
  final VoidCallback onSkip;
  final VoidCallback onBack;
  final VoidCallback onStartReading;

  @override
  Widget build(BuildContext context) {
    return switch (step) {
      OnboardingStep.promise => _PromiseStep(
        exiting: exiting,
        onNext: onNext,
        onSkip: onSkip,
      ),
      // ⚠️ **`onBack` IS NOT PASSED TO THE DISCLOSURE STEP'S RENDERING.** The back gesture
      // is handled once, by the `PopScope` in `_Frame`, so it cannot be satisfied twice —
      // and the step-2 rendering has no back *control* to wire, because § 2.1 forbids a
      // dismiss affordance of any kind there.
      OnboardingStep.disclosure => _DisclosureStep(
        exiting: exiting,
        onStartReading: onStartReading,
      ),
    };
  }
}

/// The shared page: dots, the content, and the control block.
class _PageColumn extends StatelessWidget {
  const _PageColumn({
    required this.activeStep,
    required this.exiting,
    required this.children,
    required this.primaryLabel,
    required this.primaryOnPressed,
    this.skip,
  });

  final OnboardingStep activeStep;
  final bool exiting;
  final List<Widget> children;

  final String primaryLabel;
  final VoidCallback? primaryOnPressed;

  /// The `Skip` control, or **`null` on step 2** — see `_ControlBlock`.
  final Widget? skip;

  @override
  Widget build(BuildContext context) {
    return _OnboardingColumn(
      dots: StepDots(active: activeStep.index),
      control: _ControlBlock(
        exiting: exiting,
        skip: skip,
        primaryLabel: primaryLabel,
        primaryOnPressed: primaryOnPressed,
      ),
      children: children,
    );
  }
}

/// Step 1 — **B7**, the promise.
class _PromiseStep extends StatelessWidget {
  const _PromiseStep({
    required this.exiting,
    required this.onNext,
    required this.onSkip,
  });

  final bool exiting;
  final VoidCallback onNext;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final LumenColors colors = LumenColors.of(context);
    final LumenSpacing spacing = LumenSpacing.of(context);

    return _PageColumn(
      activeStep: OnboardingStep.promise,
      exiting: exiting,
      primaryLabel: l10n.onboardingButtonNext,
      primaryOnPressed: exiting ? null : onNext,
      // ⚠️ **THE `Skip` LABEL IS `--color-accent`, THE CONTROL IS 48dp, AND IT IS
      // **LEFT-ALIGNED**.** `onboarding.md` § 3 and § 6 both say *"left-aligned"* — a
      // `TextButton` in a `stretch` column centres its label by default, so the first draft
      // rendered "Skip" in the middle of a full-width row directly above a full-width
      // primary. That is a centred column of controls, which is the one thing § 2.1's
      // anti-generic list refuses: the page's whole argument is a left-aligned single
      // column, and a centred control above a left-aligned edge is two columns.
      skip: TextButton(
        onPressed: exiting ? null : onSkip,
        style: TextButton.styleFrom(
          foregroundColor: colors.accent,
          alignment: Alignment.centerLeft,
          minimumSize: const Size.fromHeight(kOnboardingControlHeight),
        ),
        child: Text(
          l10n.onboardingButtonSkip,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: colors.accent,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      children: <Widget>[
        Kicker(text: l10n.onboardingStep1Kicker),
        SizedBox(height: spacing.lg),
        // ⚠️ **`OnboardingType.textH1`, AND IT IS THE ONLY `--text-h1` IN THE APP.**
        // `onboarding.md` § 2: *"A first-run screen that renders its promise in body text
        // has already decided it is not the point of the app."* B7 is the one thing a
        // reader cannot guess, because offline reading is announced nowhere in this app on
        // purpose — a reader who never tries never finds out.
        PromisedHeadline(text: l10n.onboardingStep1Headline),
        SizedBox(height: spacing.xl),
        Text(
          l10n.onboardingStep1Body,
          // ⚠️ **`bodyLarge` = `--text-body` 16 / 24**, which is also the floor the design
          // refuses to go below on mobile. The clause naming *"no account, no server"* is
          // in this paragraph and nowhere else: a reader who was lent this file is looking
          // for a sign-in wall, and finding none is worth saying out loud (B4, B29).
          style: Theme.of(
            context,
          ).textTheme.bodyLarge?.copyWith(color: colors.textPrimary),
        ),
      ],
    );
  }
}

/// Step 2 — **E11**, the consequence, and the step with **no way out but forwards**.
class _DisclosureStep extends StatelessWidget {
  const _DisclosureStep({required this.exiting, required this.onStartReading});

  final bool exiting;
  final VoidCallback onStartReading;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final LumenColors colors = LumenColors.of(context);
    final LumenSpacing spacing = LumenSpacing.of(context);

    return _PageColumn(
      activeStep: OnboardingStep.disclosure,
      exiting: exiting,
      primaryLabel: l10n.onboardingButtonStart,
      primaryOnPressed: exiting ? null : onStartReading,
      children: <Widget>[
        Kicker(text: l10n.onboardingStep2Kicker),
        SizedBox(height: spacing.lg),
        // ⚠️ **`textH2`, NOT `textH1`.** The promise is 31 / 38; the consequence is
        // 25 / 32. The hierarchy is part of the argument: the screen's biggest words belong
        // to the thing it is selling, and the thing it owes the reader is deliberately
        // smaller — it is a warning, not a headline.
        Text(
          l10n.onboardingStep2Headline,
          style: OnboardingType.textH2.copyWith(color: colors.textPrimary),
        ),
        SizedBox(height: spacing.xl),
        // ⚠️ **`onLink` IS OMITTED, SO THERE IS NO GHOST LINK ON STEP 2.** The reader is on
        // their way out and the only destination is the library; a link here would be a
        // second exit from a disclosure § 2.1 says has exactly one.
        const DisclosureBlock(showFootnote: true),
      ],
    );
  }
}

/// The two controls, and **only** the two.
class _ControlBlock extends StatelessWidget {
  const _ControlBlock({
    required this.exiting,
    required this.primaryLabel,
    required this.primaryOnPressed,
    this.skip,
  });

  final bool exiting;
  final String primaryLabel;
  final VoidCallback? primaryOnPressed;

  /// `null` on step 2, and **that null is the rule**: `3-4` § 7, *"skipping a disclosure
  /// while showing it is a contradiction"*. A `bool showSkip` would let a caller render an
  /// empty row where the button is not.
  final Widget? skip;

  @override
  Widget build(BuildContext context) {
    final LumenColors colors = LumenColors.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (skip != null) ...<Widget>[
          skip!,
          SizedBox(height: LumenSpacing.of(context).sm),
        ],
        // ⚠️ **NO DISMISS ICON, NO CLOSE BUTTON, NO CHECKBOX, NO TOGGLE, NO `Get started`.**
        // `C5`: the screen presents **no** setting control and no choice — `Skip` and
        // `Next` / `Start reading` are the only interactive widgets, and the test counts
        // them rather than trusting this comment.
        FilledButton(
          onPressed: primaryOnPressed,
          style: FilledButton.styleFrom(
            // ⚠️ **`accent` / `textInverse` FROM THE TOKENS, NOT INHERITED.** The theme's
            // scheme already maps `primary → accent` and `onPrimary → textInverse`, so this
            // is redundant *today*; writing it makes `--color-accent` appear exactly where
            // § 2 permits it — the pressed button, the active dot, the focus ring — and
            // makes the test that looks for the accent findable.
            backgroundColor: colors.accent,
            foregroundColor: colors.textInverse,
            minimumSize: const Size.fromHeight(kOnboardingControlHeight),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(LumenRadius.of(context).md),
            ),
          ),
          child: Text(primaryLabel),
        ),
      ],
    );
  }
}

/// `--text-overline` 11 / 16 at 600 with 0.08em tracking, upper case.
class Kicker extends StatelessWidget {
  const Kicker({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final LumenSpacing spacing = LumenSpacing.of(context);

    return Padding(
      padding: EdgeInsets.only(bottom: spacing.sm),
      child: Semantics(
        // ⚠️ **`header: true` AND AN EXPLICIT `label`.** The flag alone leaves
        // `properties.label` null, so the text arrives as a separate child node and
        // anything reading the tree gets a heading with no name. `settings_rows.dart` makes
        // this exact pair for the same reason.
        header: true,
        label: text,
        child: ExcludeSemantics(
          child: Text(
            text.toUpperCase(),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: LumenColors.of(context).textSecondary,
              fontWeight: OnboardingType.overlineWeight,
              letterSpacing: OnboardingType.overlineTracking,
            ),
          ),
        ),
      ),
    );
  }
}

/// The promise, at `--text-h1`. **Its own widget so the acceptance criterion can find it.**
class PromisedHeadline extends StatelessWidget {
  const PromisedHeadline({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      label: text,
      child: ExcludeSemantics(
        child: Text(
          text,
          style: OnboardingType.textH1.copyWith(
            color: LumenColors.of(context).textPrimary,
          ),
        ),
      ),
    );
  }
}
