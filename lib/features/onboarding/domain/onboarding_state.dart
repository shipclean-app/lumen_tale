// Lumen Tale — the two steps, the state one step of screen holds, and the two ways out.
//
// `3-4` § 2.2. **No Flutter import, no `SharedPreferences`, no router**: this file is
// the part of the flow that can be reasoned about without pumping a widget, and the
// reason the six exit branches of § 3.3 are testable at all.
//
// ## ⚠️ `OnboardingStep` IS AN `enum`, AND THAT IS THE WHOLE ARGUMENT
//
// The natural shape is `int step = 0`. It permits `state.step = 3`, which does not
// exist, and the compiler says nothing — the reader arrives at a screen that is neither
// the promise nor the consequence, with no `Skip` and no way back. Two values that are
// written by name cannot be written wrongly, and an `exhaustive switch` over them
// makes a third one a compile error rather than a blank space.

/// The two steps, and **two**.
enum OnboardingStep {
  /// **B7** — the promise. "It reads with no signal." The one thing a reader cannot
  /// guess, because this app announces offline reading **nowhere**, on purpose.
  promise,

  /// **E11** — the consequence. The disclosure. **No `Skip` lives here**, and its
  /// absence is a decision rather than an omission: skipping a disclosure while showing
  /// it is the difference between *disclosing* and *displaying*.
  disclosure,
}

/// One step's worth of screen state, **without the router**.
///
/// The two booleans are not flags; they are the two hand-written renderings of the
/// screen's rules, and `onboarding.md` § 2.1 argues for both.
final class OnboardingState {
  const OnboardingState({
    required this.step,
    required this.skippable,
    required this.canGoBack,
    this.exiting = false,
  });

  /// **The first launch.** Step 1: skippable, and the back gesture **leaves**.
  const OnboardingState.firstRun()
    : step = OnboardingStep.promise,
      skippable = true,
      canGoBack = false,
      exiting = false;

  /// **Re-entry from Settings.** Step 2: not skippable, and back goes **backwards**.
  ///
  /// ⚠️ **THE DISCLOSURE IS STEP 2 HERE, NOT STEP 1**, and `onboarding.md` § 4 gives the
  /// reason: *"the re-entry path is **better** than the first-run path"*. The promise has
  /// been read and either worked or not; the disclosure is the part a re-reader may have
  /// skipped, and it is the part with consequences. A "replay the tutorial" button that
  /// replays the tutorial in the same order teaches the reader that the screen is a loop.
  const OnboardingState.replay()
    : step = OnboardingStep.disclosure,
      skippable = false,
      canGoBack = true,
      exiting = false;

  final OnboardingStep step;

  /// `true` on [OnboardingStep.promise] only. § 2.1, decision 2.
  final bool skippable;

  /// Whether the back gesture **stays on the screen**.
  ///
  /// ⚠️ **`false` on step 1, and the back gesture there is `Skip` verbatim** — no "are
  /// you sure you want to skip?", because that dialog exists only to make somebody feel
  /// they have chosen. `true` on step 2, and back returns to the promise rather than
  /// leaving: the one place in this app where back does not mean *leave*, because the
  /// disclosure must not be dismissible by a stray gesture.
  final bool canGoBack;

  /// An exit is in flight: the flag is being written.
  ///
  /// ⚠️ **A FOURTH FIELD, AND `3-4` § 2.2 lists three.** It exists because
  /// `onboarding.md` § 4 (*Submit error*) requires the button to return from its
  /// `loading` state over `--duration-fast`, and because § 3.3 writes the flag at the
  /// **exit**, which is behind an `await`. Without it a double tap runs two exits, and
  /// the acceptance criterion "a call counter proves `write()` ran exactly once" would be
  /// true only because the tests tap once.
  final bool exiting;

  /// The state this step has, with no exit in flight.
  ///
  /// ⚠️ **Derived from the STEP rather than copied from the current state**, so the two
  /// booleans cannot drift into a combination the design never named. A `withStep` that
  /// copied `skippable` across would let step 2 arrive skippable — the exact defect
  /// § 2.1 decision 2 forbids, and one nothing downstream would complain about.
  OnboardingState withStep(OnboardingStep next) => switch (next) {
    OnboardingStep.promise => const OnboardingState.firstRun(),
    OnboardingStep.disclosure => const OnboardingState.replay(),
  };

  /// The same state with [exiting] posed, and the **only** way to pose it.
  OnboardingState get exitingNow => OnboardingState(
    step: step,
    skippable: skippable,
    canGoBack: canGoBack,
    exiting: true,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OnboardingState &&
          runtimeType == other.runtimeType &&
          step == other.step &&
          skippable == other.skippable &&
          canGoBack == other.canGoBack &&
          exiting == other.exiting;

  @override
  int get hashCode => Object.hash(step, skippable, canGoBack, exiting);

  @override
  String toString() =>
      'OnboardingState(${step.name}, skippable: $skippable, canGoBack: $canGoBack, '
      'exiting: $exiting)';
}

/// Where the flow ends. **Two destinations, and the difference is recorded** because it
/// is the only thing that distinguishes them.
enum OnboardingExit {
  /// `Skip` on step 1, **or** the back gesture on step 1 — the same branch verbatim.
  ///
  /// ⚠️ **STEP 2 IS NEVER BUILT.** That is the point: the disclosure is made on the next
  /// launch if the flag write failed, and a write that failed is a write that did not
  /// happen. There is nothing to "come back to", so nothing is stacked and nothing is
  /// animated.
  libraryFromSkip,

  /// `Start reading` on step 2. The reader has read the consequence and accepted it.
  libraryFromDisclosure,
}

/// The one navigation this screen performs.
///
/// ⚠️ **AN INTERFACE, AND THAT IS WHAT MAKES THE NOTIFIER TESTABLE.** `05-state-management.md`
/// forbids navigation logic in a provider, and the way to have both is for the provider to
/// call an interface the *screen* supplies — the screen is the only element that has a
/// `BuildContext` under the router.
///
/// ⚠️ **THE SCREEN DOES NOT RENDER THE EMPTY LIBRARY.** The destination is `/library`,
/// whose `library-empty` state is the design system's named rendering of an empty
/// library, with its own *Browse sources* call to action. A second rendering of that fact
/// on the onboarding screen is a second thing to keep true, and `onboarding.md` § 4
/// (*Empty — no data*) refuses it by name.
abstract interface class OnboardingRouter {
  /// Leaves onboarding for `/library`.
  void goToLibrary(OnboardingExit exit);
}
