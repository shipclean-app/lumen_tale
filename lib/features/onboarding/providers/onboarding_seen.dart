// Lumen Tale — the four things `/onboarding` needs that the screen cannot hold for itself.
//
// ## Why these four live in ONE file
//
// `3-4` § 4.2's table puts them together, and the table is right for a reason it does not
// state: **the step notifier's entire contract is one call on the flag store.** Split them
// and `onboardingStepProvider` would be a notifier in one file that imports a store
// provider from another, which is the shape of two features wearing one name.
//
// ## ⚠️ `onboardingStepProvider` is `autoDispose`, AND IT MUST BE
//
// `05-state-management.md` rule 10. The reason is `onboarding.md` § 4: re-entering
// `/onboarding` from Settings must open on **step 2**. A `keepAlive` provider would
// remember that the reader already reached step 2 — and, worse, that they already reached
// step 1 — so the re-entry would replay whatever the previous visit ended on. The screen's
// lifetime and the state machine's lifetime are the same by construction, which is what
// makes "re-entry opens on step 2" a property rather than a hope.
//
// ## ⚠️ `onboardingSeenProvider` is `keepAlive`, FOR THE OPPOSITE REASON
//
// Two readers of one boolean must not disagree. The router's startup decision (§ 3.1) and
// the screen both read the flag, and two `FutureProvider`s over the same key could resolve
// on either side of a `write()` — producing two different answers to "has this reader seen
// the disclosure" in one process.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:lumen_tale/app/router/app_routes.dart';
import 'package:lumen_tale/core/storage/onboarding_seen.dart';
import 'package:lumen_tale/core/storage/shared_preferences_provider.dart';
import 'package:lumen_tale/features/onboarding/domain/onboarding_state.dart';

/// The flag store, built over the instance `main()` already resolved.
final onboardingSeenStoreProvider = Provider<OnboardingSeenStore>(
  (Ref ref) => SharedPreferencesOnboardingSeenStore(
    ref.watch(sharedPreferencesProvider),
  ),
);

/// "Has this reader already seen the first launch?" — **`keepAlive`**; see the header.
final onboardingSeenProvider = FutureProvider<bool>(
  (Ref ref) => ref.watch(onboardingSeenStoreProvider).readFailsOpen(),
);

/// Overridden by [OnboardingScreen], which is the only element with a `BuildContext`
/// under the router.
///
/// Throws rather than defaulting: a default would be a real `GoRouter` lookup that returns
/// nothing in a test, and the six exit branches are exactly the rows a fake has to prove.
final onboardingRouterProvider = Provider<OnboardingRouter>(
  (Ref ref) => throw UnimplementedError(
    'onboardingRouterProvider is overridden by OnboardingScreen, the only element '
    'that sits under the router',
  ),
);

/// Which step **this visit** opens on.
///
/// ⚠️ **DEFAULT STEP 1, AND THE SCREEN OVERRIDES IT.** It is a `Provider` rather than a
/// constructor argument on the notifier because the notifier's initial state must be
/// derived from something the scope owns: `Notifier.build()` takes no arguments, so a
/// notifier told "start at step 2" would need a second notifier class, and two classes
/// whose difference is one enum value is one rule written twice.
final onboardingInitialStepProvider = Provider<OnboardingStep>(
  (Ref ref) => OnboardingStep.promise,
);

/// The step machine — **`autoDispose`**, four public methods, and nothing else.
///
/// ## ⚠️ `dependencies:` IS DECLARED, AND RIVERPOD 3 NEEDS IT SAYED OUT LOUD
///
/// A nested `ProviderScope`'s overrides only reach a provider that Riverpod knows to
/// **mount inside that scope**, and it decides that from the provider's declared
/// `dependencies` — not from what `build()` happens to `ref.watch`. That is
/// `ProviderContainer._getTargetContainer`'s
/// `findDeepestTransitiveDependencyProviderContainer(provider)`, and the fallback when a
/// provider declares none is `container._root`: **the root container**, so its `ref` would
/// resolve the sibling overrides against the wrong scope entirely.
///
/// The first draft declared nothing, and the symptom was a screen that ignored *both* of its
/// own overrides — it opened on step 1 when the URL said step 2, and its exit threw
/// `UnimplementedError` from the very provider the screen had overridden. Three lines here
/// are what make the scope work.
final onboardingStepProvider =
    NotifierProvider.autoDispose<OnboardingStepNotifier, OnboardingState>(
      OnboardingStepNotifier.new,
      dependencies: <Provider<dynamic>>[
        onboardingInitialStepProvider,
        onboardingSeenStoreProvider,
        onboardingRouterProvider,
      ],
    );

/// `next`, `skip`, `back`, `startReading` — and **nothing else**, because each one of the
/// six branches of § 3.3 is one of these four calls.
class OnboardingStepNotifier extends Notifier<OnboardingState> {
  /// ⚠️ **THE INITIAL STATE IS THE SCOPE'S ANSWER, DERIVED THROUGH A `switch`.** Each arm
  /// names the **whole** state rather than copying `skippable`/`canGoBack` across from the
  /// other step, so the two booleans can never arrive in a combination the design never
  /// named — step 2 skippable is exactly the defect § 2.1 decision 2 forbids, and nothing
  /// downstream would complain about it.
  @override
  OnboardingState build() => switch (ref.watch(onboardingInitialStepProvider)) {
    OnboardingStep.promise => const OnboardingState.firstRun(),
    OnboardingStep.disclosure => const OnboardingState.replay(),
  };

  /// § 3.3 branch 3: `promise → disclosure`, **in place**.
  ///
  /// ⚠️ **NO FLAG IS WRITTEN HERE.** The flag is posed at the **exit**, not at the moment
  /// step 2 is displayed. Posing it here would make the exit of step 2 — *including the
  /// process being killed while the reader reads the disclosure* — a non-event, and a
  /// reader who turns their phone off halfway through the disclosure would find it skipped
  /// next launch.
  void next() {
    if (state.exiting) {
      return;
    }
    state = state.withStep(OnboardingStep.disclosure);
  }

  /// § 3.3 branch 1: `Skip`. Writes the flag, then goes to `/library`.
  Future<void> skip() => _exit(OnboardingExit.libraryFromSkip);

  /// § 3.3 branch 2 from step 1 — **exactly** [skip], with no dialog in between.
  ///
  /// § 3.3 branch 2′ from step 2: back to the promise, and **the app is not left**.
  Future<void> back() async {
    switch (state.step) {
      // ⚠️ **BRANCH 2 AND BRANCH 2′, AND THEY SHARE A `switch` ON THE STEP.** Two
      // functions with two bodies is two places a future edit could make them differ, and
      // the design requires them to be the *same* branch: step 1's back is `Skip`
      // verbatim, and step 2's back is a step change that does not leave.
      case OnboardingStep.promise:
        await _exit(OnboardingExit.libraryFromSkip);
      case OnboardingStep.disclosure:
        if (!state.exiting) {
          state = state.withStep(OnboardingStep.promise);
        }
    }
  }

  /// § 3.3 branch 4: `Start reading`. Writes the flag, then goes to `/library`.
  Future<void> startReading() => _exit(OnboardingExit.libraryFromDisclosure);

  /// ⚠️ **THE ONLY PLACE THE FLAG IS EVER WRITTEN.** Three callers — `skip`, `back` from
  /// step 1, `startReading` — and one implementation, so "exactly one write point" is a
  /// fact about the code rather than a convention about it.
  Future<void> _exit(OnboardingExit exit) async {
    // ⚠️ **THE GUARD IS FIRST, BEFORE THE `await`.** Two taps in the same frame would
    // otherwise both pass it, and the flag would be written twice — which is the
    // acceptance criterion a counter exists to catch.
    if (state.exiting) {
      return;
    }
    state = state.exitingNow;

    // ⚠️ **BOTH FAILURE MODES ARE SWALLOWED, AND § 3.3 BRANCH 5 NAMES BOTH.**
    //
    //     "store.write() rend false, ou lève capturé en interne"
    //
    // The interface promises a `bool`, so the `catch` is unreachable *through the store* — and
    // it stays because the cost of it being reachable is a reader stuck on a screen with no
    // way forward: an uncaught error here propagates out of a button callback, the navigation
    // never happens, and `exiting` stays `true`, so **both buttons are then permanently
    // disabled**. That is the trap § 3.3 branch 5 exists to prevent, and it is not visible in
    // the happy path.
    try {
      await ref.read(onboardingSeenStoreProvider).write();
    } on Object {
      // ⚠️ **NOTHING IS SAID, AND NOTHING IS RETRIED.** The reader's "retry" would be "skip
      // again", which is what they just did; and the only possible failure is "I cannot
      // remember that I saw this", which is not a preference the reader has.
    }

    ref.read(onboardingRouterProvider).goToLibrary(exit);
  }
}

/// The router-backed [OnboardingRouter].
///
/// ⚠️ **`go`, NOT `push`, AND THE REASON IS STRUCTURAL.** `/onboarding` is a **root**
/// route (a sibling of the shell), so pushing `/library` would *append* rather than
/// replace: the resulting match list is `[/onboarding, shell→/library]`, which mounts the
/// tab bar **underneath** a screen that is required to have none (`design-system.md` § 3.5),
/// and re-runs the startup decision against a location that is not the cold start. `go`
/// replaces the root page list, which is also what § 3.1's cold-start branch 3 does, so
/// both arrivals at `/library` look identical to the reader.
final class GoRouterOnboardingRouter implements OnboardingRouter {
  /// ⚠️ **THE `GoRouter` IS RESOLVED HERE, AT BUILD TIME, AND HELD.**
  /// `goToLibrary` runs after an `await`, so resolving it from a `BuildContext` at call
  /// time would need a `mounted` check on a context this object does not own — and a
  /// notifier holding a `BuildContext` is a notifier that outlives the screen.
  GoRouterOnboardingRouter(BuildContext context)
    : _router = GoRouter.of(context);

  final GoRouter _router;

  @override
  void goToLibrary(OnboardingExit exit) {
    // ⚠️ **`exit` is received and deliberately not branched on.** Both destinations are
    // `/library`; the enum exists so a caller, a test and a future reader can see that the
    // two exits were decided apart, and so a second destination would be one `switch`
    // instead of a second call site.
    _router.go(AppRoutes.library);
  }
}
