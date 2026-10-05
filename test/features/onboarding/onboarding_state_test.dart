// forge:slice 3-4
// Lumen Tale — `3-4` § 3.3, the six branches of the flow, and § 3.4's one boolean.
//
// ## Why this file has no widget
//
// Every branch of § 3.3 is a question about **what the state machine does**, and a widget
// test can only answer it by rendering something and hoping the tree says something. A
// `ProviderContainer` answers them directly, which is `05-state-management.md`'s P1 and the
// reason `OnboardingRouter` is an interface at all.
//
// ## ⚠️ EVERY `expect` HERE IS ATTACHED TO A BRANCH OF § 3.3
//
// A row that merely checked "the state is `promise`" would pass for a notifier that also
// wrote the flag on the way there, because the state is the same either way. The rows below
// name the branch they are the witness for, and the ones that matter most are the ones that
// assert something **did not** happen: `next()` writing nothing, a failed write still
// transitioning, a second tap writing nothing.

import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumen_tale/core/storage/onboarding_seen.dart';
import 'package:lumen_tale/features/onboarding/domain/onboarding_state.dart';
import 'package:lumen_tale/features/onboarding/providers/onboarding_seen.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A store that counts its calls and can be told to fail a write — which the real one can
/// also be told to do, and always answers `false` rather than throwing.
final class _SpyStore implements OnboardingSeenStore {
  _SpyStore({this.failWrite = false});

  bool seen = false;
  bool failWrite;

  int readCalls = 0;
  int writeCalls = 0;

  @override
  Future<bool> readFailsOpen() async {
    readCalls++;
    return seen;
  }

  @override
  Future<bool> write() async {
    writeCalls++;
    if (failWrite) {
      return false;
    }
    seen = true;
    return true;
  }
}

/// A router that records the exits instead of navigating.
final class _RecordingRouter implements OnboardingRouter {
  final List<OnboardingExit> exits = <OnboardingExit>[];

  @override
  void goToLibrary(OnboardingExit exit) => exits.add(exit);
}

/// A container with both providers wired to the fakes.
ProviderContainer _container({
  required OnboardingSeenStore store,
  required OnboardingRouter router,
  OnboardingStep entry = OnboardingStep.promise,
}) {
  final ProviderContainer container = ProviderContainer(
    overrides: [
      onboardingSeenStoreProvider.overrideWithValue(store),
      onboardingRouterProvider.overrideWithValue(router),
      onboardingInitialStepProvider.overrideWithValue(entry),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  group('the step enum has exactly two values, and a third cannot be written', () {
    test('there are two, and the analyzer fails if a third is added', () {
      // Two screens. `step 3` is not a state this product has, and an `int` would let it be
      // written — which is why this is an `enum` and why the count is asserted rather than
      // assumed.
      expect(
        OnboardingStep.values,
        <OnboardingStep>[OnboardingStep.promise, OnboardingStep.disclosure],
        reason:
            'the flow is a promise and a consequence; a third value would be a step with no '
            'copy, no skip rule and no back rule',
      );
      expect(OnboardingStep.values, hasLength(2));
      // And each has an index, which is what the dot pair renders — so `index` cannot exceed
      // the count without a row failing.
      expect(OnboardingStep.promise.index, 0);
      expect(OnboardingStep.disclosure.index, 1);
    });

    test('the exit enum names both destinations apart', () {
      expect(OnboardingExit.values, hasLength(2));
      expect(OnboardingExit.values, <OnboardingExit>[
        OnboardingExit.libraryFromSkip,
        OnboardingExit.libraryFromDisclosure,
      ]);
    });
  });

  group('the first-run state — E11', () {
    test('step 1: skippable, and back LEAVES', () {
      const OnboardingState state = OnboardingState.firstRun();
      expect(state.step, OnboardingStep.promise);
      // `Skip` exists here and only here. § 2.1 decision 2.
      expect(state.skippable, isTrue);
      // The back gesture is `Skip` — it leaves — and there is no confirmation dialog.
      expect(state.canGoBack, isFalse);
      expect(state.exiting, isFalse);
    });

    test(
      'a re-read from Settings opens on step 2: not skippable, back STAYS',
      () {
        const OnboardingState state = OnboardingState.replay();
        expect(state.step, OnboardingStep.disclosure);
        // Step 2 has no `Skip` at all. Permitting one is "displaying", not "disclosing".
        expect(state.skippable, isFalse);
        // And back goes BACKWARDS rather than out of the app.
        expect(state.canGoBack, isTrue);
      },
    );
  });

  group('§ 3.3 branch 3 — `next()` advances and writes NOTHING', () {
    test('promise → disclosure, and `skippable` becomes false', () {
      final _SpyStore store = _SpyStore();
      final ProviderContainer container = _container(
        store: store,
        router: _RecordingRouter(),
      );
      final OnboardingStepNotifier notifier = container.read(
        onboardingStepProvider.notifier,
      );
      expect(
        container.read(onboardingStepProvider).step,
        OnboardingStep.promise,
      );

      notifier.next();

      final OnboardingState after = container.read(onboardingStepProvider);
      expect(after.step, OnboardingStep.disclosure);
      expect(
        after.skippable,
        isFalse,
        reason:
            'step 2 must not be skippable, or the disclosure could be dismissed before it '
            'was read — the whole of § 2.1 decision 2',
      );
      expect(after.canGoBack, isTrue);
    });

    test('⚠️ ZERO calls to write() — the flag is posed at the EXIT', () {
      // ⚠️ **THE LOAD-BEARING ROW OF THIS GROUP.** Posing the flag when step 2 is *displayed*
      // would make the exit of step 2 — including the reader switching their phone off
      // halfway through the disclosure — a non-event, and the disclosure would be skipped
      // next launch.
      final _SpyStore store = _SpyStore();
      final ProviderContainer container = _container(
        store: store,
        router: _RecordingRouter(),
      );

      container.read(onboardingStepProvider.notifier).next();

      expect(
        store.writeCalls,
        0,
        reason:
            'the flag is written on the way OUT, never on the way IN; a write here would '
            'record the disclosure as seen before the reader has seen it',
      );
      expect(store.seen, isFalse);
    });
  });

  group('§ 3.3 branch 1 — `skip()` writes the flag and leaves', () {
    test('exactly one write, and `libraryFromSkip`', () async {
      final _SpyStore store = _SpyStore();
      final _RecordingRouter router = _RecordingRouter();
      final ProviderContainer container = _container(
        store: store,
        router: router,
      );

      await container.read(onboardingStepProvider.notifier).skip();

      expect(store.writeCalls, 1);
      expect(store.seen, isTrue);
      expect(router.exits, <OnboardingExit>[OnboardingExit.libraryFromSkip]);
    });

    test(
      '⚠️ step 2 is NEVER reached: `skip()` does not touch the step',
      () async {
        final ProviderContainer container = _container(
          store: _SpyStore(),
          router: _RecordingRouter(),
        );
        await container.read(onboardingStepProvider.notifier).skip();
        expect(
          container.read(onboardingStepProvider).step,
          OnboardingStep.promise,
          reason:
              '`Skip` leaves without building step 2 — § 3.3 branch 1. There is no "behind" '
              'for the disclosure to be shown in.',
        );
      },
    );
  });

  group('§ 3.3 branch 2 — the back gesture, and its two behaviours', () {
    test('⚠️ from `promise` it is EXACTLY `skip()`', () async {
      final _SpyStore store = _SpyStore();
      final _RecordingRouter router = _RecordingRouter();
      final ProviderContainer container = _container(
        store: store,
        router: router,
      );

      await container.read(onboardingStepProvider.notifier).back();

      expect(store.writeCalls, 1, reason: 'the same single write as `skip()`');
      expect(router.exits, <OnboardingExit>[OnboardingExit.libraryFromSkip]);
    });

    test('⚠️ from `disclosure` it goes BACKWARDS and does not leave', () async {
      final _SpyStore store = _SpyStore();
      final _RecordingRouter router = _RecordingRouter();
      final ProviderContainer container = _container(
        store: store,
        router: router,
        entry: OnboardingStep.disclosure,
      );

      await container.read(onboardingStepProvider.notifier).back();

      expect(
        router.exits,
        isEmpty,
        reason:
            'back on step 2 returns to the promise. Leaving the app from the disclosure is '
            'the one thing § 3.3 branch 2 forbids — the disclosure must not be dismissible '
            'by a stray gesture',
      );
      expect(
        store.writeCalls,
        0,
        reason: 'nothing was exited, so nothing was written',
      );
      final OnboardingState after = container.read(onboardingStepProvider);
      expect(after.step, OnboardingStep.promise);
      expect(after.skippable, isTrue, reason: 'step 1 is skippable');
    });

    test('⚠️ NO confirmation dialog is involved, on either step', () async {
      // There is no dialog to find here: the notifier has no `BuildContext` and the
      // signature has nowhere to put one. The row is here because "are you sure you want to
      // skip?" is the specific dialog `onboarding.md` § 5 forbids by name, and the cheapest
      // way to keep it out is for no layer that could show it to exist.
      final ProviderContainer container = _container(
        store: _SpyStore(),
        router: _RecordingRouter(),
      );
      final OnboardingStepNotifier notifier = container.read(
        onboardingStepProvider.notifier,
      );
      await notifier.back();
      expect(container.read(onboardingStepProvider).exiting, isTrue);
    });
  });

  group('§ 3.3 branch 4 — `startReading()` writes the flag and leaves', () {
    test('exactly one write, and `libraryFromDisclosure`', () async {
      final _SpyStore store = _SpyStore();
      final _RecordingRouter router = _RecordingRouter();
      final ProviderContainer container = _container(
        store: store,
        router: router,
        entry: OnboardingStep.disclosure,
      );

      await container.read(onboardingStepProvider.notifier).startReading();

      expect(store.writeCalls, 1);
      expect(router.exits, <OnboardingExit>[
        OnboardingExit.libraryFromDisclosure,
      ]);
    });
  });

  group('⚠️ § 3.3 branch 5 — a failed write STILL transitions', () {
    test('`write()` answers false, and the exit happens anyway', () async {
      final _SpyStore store = _SpyStore(failWrite: true);
      final _RecordingRouter router = _RecordingRouter();
      final ProviderContainer container = _container(
        store: store,
        router: router,
      );

      await container.read(onboardingStepProvider.notifier).skip();

      expect(
        router.exits,
        <OnboardingExit>[OnboardingExit.libraryFromSkip],
        reason:
            'not exiting is a trap. The cost of a failed write is that onboarding replays '
            'ONCE next launch, and ten seconds of replay is recoverable; a reader stuck in '
            'onboarding is not a reader.',
      );
      expect(store.seen, isFalse, reason: 'and the flag really was not posed');
    });

    test('a store that THROWS is treated as a failed write, and STILL exits', () async {
      // ⚠️ **§ 3.3 BRANCH 5 NAMES BOTH FAILURE MODES** — *"store.write() rend false, ou
      // lève capturé en interne"* — so the capture is required by the plan and not merely
      // defensive. The interface says the store returns a `bool`, which makes the throw arm
      // unreachable through the real store; what makes it load-bearing is the consequence
      // of it being reachable: an uncaught error out of a button callback leaves `exiting`
      // `true` and **both buttons permanently disabled**, which is the trap branch 5 exists
      // to prevent and which nothing in the happy path shows.
      final _RecordingRouter router = _RecordingRouter();
      final ProviderContainer container = ProviderContainer(
        overrides: [
          onboardingSeenStoreProvider.overrideWithValue(_ThrowingStore()),
          onboardingRouterProvider.overrideWithValue(router),
        ],
      );
      addTearDown(container.dispose);

      await container.read(onboardingStepProvider.notifier).startReading();

      expect(
        router.exits,
        <OnboardingExit>[OnboardingExit.libraryFromDisclosure],
        reason:
            'a store that throws must land in exactly the same place as one that returns '
            'false — the reader leaves, and onboarding replays once',
      );
    });

    test('⚠️ and NO message reaches the reader', () async {
      // The notifier holds no `BuildContext`, so there is nowhere to show a SnackBar or a
      // dialog even if it wanted to. § 3.3 branch 5's second clause — *"on ne dit rien au
      // lecteur"* — is enforced by the shape rather than by a decision.
      final _SpyStore store = _SpyStore(failWrite: true);
      final ProviderContainer container = _container(
        store: store,
        router: _RecordingRouter(),
        entry: OnboardingStep.disclosure,
      );
      await container.read(onboardingStepProvider.notifier).startReading();
      expect(store.writeCalls, 1);
      expect(
        container.read(onboardingStepProvider),
        const OnboardingState.replay().exitingNow,
        reason:
            'the only state change on a failed write is `exiting` — no error field exists on '
            '`OnboardingState`, so there is nothing for a message to read',
      );
    });
  });

  group('⚠️ one tap, one write — the `exiting` guard', () {
    test('a double tap writes the flag ONCE and leaves ONCE', () async {
      final _SpyStore store = _SpyStore();
      final _RecordingRouter router = _RecordingRouter();
      final ProviderContainer container = _container(
        store: store,
        router: router,
      );
      final OnboardingStepNotifier notifier = container.read(
        onboardingStepProvider.notifier,
      );

      // ⚠️ **BOTH CALLS ARE ISSUED BEFORE THE FIRST `await` COMPLETES.** Awaiting them in
      // sequence would prove nothing: the second would arrive after the first had finished
      // and the navigation had already replaced the widget tree.
      final Future<void> first = notifier.skip();
      final Future<void> second = notifier.skip();
      await Future.wait<void>(<Future<void>>[first, second]);

      expect(
        store.writeCalls,
        1,
        reason:
            'the guard is posed BEFORE the await. A guard after it would let two taps in '
            'one frame both pass, which is exactly the shape the acceptance criterion exists '
            'to catch',
      );
      expect(router.exits, <OnboardingExit>[OnboardingExit.libraryFromSkip]);
    });

    test('`next()` is also inert while an exit is in flight', () async {
      final ProviderContainer container = _container(
        store: _SpyStore(failWrite: true),
        router: _RecordingRouter(),
      );
      final OnboardingStepNotifier notifier = container.read(
        onboardingStepProvider.notifier,
      );
      final Future<void> leaving = notifier.skip();
      notifier.next();
      await leaving;
      expect(
        container.read(onboardingStepProvider).step,
        OnboardingStep.promise,
        reason:
            'a step change during an exit would move the content under a reader who has '
            'already asked to leave',
      );
    });
  });

  group('the `exiting` state is derived, never set from outside', () {
    test('`exitingNow` keeps the step and both flags', () {
      const OnboardingState state = OnboardingState.firstRun();
      final OnboardingState exiting = state.exitingNow;
      expect(exiting.step, state.step);
      expect(exiting.skippable, state.skippable);
      expect(exiting.canGoBack, state.canGoBack);
      expect(exiting.exiting, isTrue);
    });

    test(
      '`withStep` derives the whole state from the step, never copies flags',
      () {
        const OnboardingState disclosing = OnboardingState.replay();
        final OnboardingState promised = disclosing.withStep(
          OnboardingStep.promise,
        );
        expect(promised, const OnboardingState.firstRun());
        expect(
          promised.exiting,
          isFalse,
          reason:
              'a step change starts a clean step — `exiting` belongs to an exit, not a step',
        );
        expect(
          disclosing.withStep(OnboardingStep.disclosure),
          disclosing,
          reason:
              'the disclosure state is reached the same way however it was entered',
        );
      },
    );

    test(
      'two equal states are equal, so a test comparing them means something',
      () {
        expect(
          const OnboardingState.firstRun(),
          const OnboardingState.firstRun(),
        );
        expect(
          const OnboardingState.firstRun().hashCode,
          const OnboardingState.firstRun().hashCode,
        );
        expect(
          const OnboardingState.firstRun(),
          isNot(const OnboardingState.replay()),
        );
      },
    );
  });

  group('§ 3.4 — ONE boolean, and nothing else', () {
    setUp(TestWidgetsFlutterBinding.ensureInitialized);

    test('a complete run leaves exactly one key in shared_preferences', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final SharedPreferences prefs = await SharedPreferences.getInstance();

      final ProviderContainer container = ProviderContainer(
        overrides: [
          onboardingSeenStoreProvider.overrideWithValue(
            SharedPreferencesOnboardingSeenStore(prefs),
          ),
          onboardingRouterProvider.overrideWithValue(_RecordingRouter()),
        ],
      );
      addTearDown(container.dispose);

      // ⚠️ **THE WHOLE RUN: step 1 → step 2 → out.** `next()` then `startReading()` is the
      // longest path through the flow, and `Skip` is a strictly shorter one that writes the
      // same single key.
      final OnboardingStepNotifier notifier = container.read(
        onboardingStepProvider.notifier,
      );
      notifier.next();
      await notifier.startReading();

      expect(
        prefs.getKeys().toList(),
        <String>[onboardingSeenKey],
        reason:
            '§ 3.4: a boolean, and nothing else. No version, no date, no step reached, no '
            '"saw the disclosure" — one of those would be a mini-state machine that would '
            'then need an expiry rule nobody has written.',
      );
    });

    test('the key is the one § 2.1 names', () {
      expect(onboardingSeenKey, 'onboarding.seen');
    });
  });

  group('the store — `readFailsOpen` and `write` both fail OPEN', () {
    setUp(TestWidgetsFlutterBinding.ensureInitialized);

    test('false on the first launch, true after a write', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final SharedPreferencesOnboardingSeenStore store =
          SharedPreferencesOnboardingSeenStore(prefs);

      expect(await store.readFailsOpen(), isFalse, reason: 'first run');
      expect(await store.write(), isTrue);
      expect(await store.readFailsOpen(), isTrue, reason: 'second run');
    });

    test(
      '⚠️ a value of the WRONG TYPE reads as `false`, not as an exception',
      () async {
        // `getBool` throws a cast error when the key holds something else, and the key is a
        // plain string in a file a future build could write a different type into. A cast
        // error is a read failure, and a read failure must show the disclosure.
        SharedPreferences.setMockInitialValues(<String, Object>{
          onboardingSeenKey: 'yes',
        });
        final SharedPreferences prefs = await SharedPreferences.getInstance();
        final SharedPreferencesOnboardingSeenStore store =
            SharedPreferencesOnboardingSeenStore(prefs);

        expect(await store.readFailsOpen(), isFalse);
      },
    );

    test('the interface has exactly the two methods § 2.1 names', () {
      // ⚠️ **READ OFF THE SOURCE, NOT REIMPLEMENTED HERE.** Dart has no reflection and
      // `dart:mirrors` is unavailable in Flutter, so the members are counted in the
      // declaration — and spelling the two names again in this test would make the
      // assertion compare the test with itself.
      final String source = File(
        'lib/core/storage/onboarding_seen.dart',
      ).readAsStringSync();
      final int start = source.indexOf(
        'abstract interface class OnboardingSeenStore',
      );
      final int end = source.indexOf('/// The store, over the');
      expect(
        start,
        greaterThan(-1),
        reason: 'the interface declaration must still be findable by this row',
      );
      expect(
        end,
        greaterThan(start),
        reason: 'and the row must find where it stops',
      );

      final Set<String> declared = RegExp(r'Future<bool>\s+(\w+)\(')
          .allMatches(source.substring(start, end))
          .map((Match m) => m.group(1)!)
          .toSet();

      expect(
        declared,
        <String>{'readFailsOpen', 'write'},
        reason:
            '`OnboardingSeenStore` is a flag, not a settings object. A third method would be '
            'state § 3.4 did not agree to, and § 3.3 would need a branch for it.',
      );
    });
  });

  group('§ 3.3 branch 6 — the process dies before the exit', () {
    test('⚠️ an absent flag means the flow starts again at step 1', () async {
      // ⚠️ **BRANCH 6 HAS NO CODE, AND THIS IS ITS WHOLE WITNESS.** The reader switches their
      // phone off on step 2: no callback runs, nothing is written. What the next launch must
      // do is therefore a question about the *absence* of a key, and this is the only row
      // that can show it.
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final SharedPreferences prefs = await SharedPreferences.getInstance();

      final ProviderContainer container = ProviderContainer(
        overrides: [
          onboardingSeenStoreProvider.overrideWithValue(
            SharedPreferencesOnboardingSeenStore(prefs),
          ),
          onboardingRouterProvider.overrideWithValue(_RecordingRouter()),
        ],
      );
      addTearDown(container.dispose);

      expect(
        await container.read(onboardingSeenProvider.future),
        isFalse,
        reason:
            'replaying two screens for ten seconds is a nuisance; skipping a disclosure the '
            'reader never saw is an irreversible loss. That asymmetry is § 3.4 in one row.',
      );
      expect(
        container.read(onboardingStepProvider).step,
        OnboardingStep.promise,
        reason: 'and the replay starts at step 1, not at the disclosure',
      );
    });

    test(
      'the flag provider is `keepAlive`, so two readers cannot disagree',
      () async {
        SharedPreferences.setMockInitialValues(<String, Object>{
          onboardingSeenKey: true,
        });
        final SharedPreferences prefs = await SharedPreferences.getInstance();
        final ProviderContainer container = ProviderContainer(
          overrides: [
            onboardingSeenStoreProvider.overrideWithValue(
              SharedPreferencesOnboardingSeenStore(prefs),
            ),
          ],
        );
        addTearDown(container.dispose);

        expect(await container.read(onboardingSeenProvider.future), isTrue);
        expect(container.read(onboardingSeenProvider), isA<AsyncValue<bool>>());
        // Two reads of the same provider, and the second did not re-query.
        expect(
          container.read(onboardingSeenProvider.future),
          completion(isTrue),
        );
      },
    );
  });

  group('no persistence file mentions anything but the one flag', () {
    test('the store reads and writes only `onboarding.seen`', () {
      // A structural row, because the alternative is a future store that also remembers
      // *which step* the reader reached — which is § 3.4's forbidden second value, and it
      // would arrive as one extra `setString` that no behavioural test would fail.
      final String source = File(
        'lib/core/storage/onboarding_seen.dart',
      ).readAsStringSync();
      expect(
        source,
        contains("const String onboardingSeenKey = 'onboarding.seen';"),
      );
      final List<String> otherKeys = RegExp(
        r"'(?!onboarding\.seen)[a-z]+\.[a-zA-Z.]+'",
      ).allMatches(source).map((Match m) => m.group(0)!).toList();
      expect(
        otherKeys,
        isEmpty,
        reason:
            'this store owns one key. A second dotted key here would be the start of the '
            '`seenStep` scheme § 3.4 refuses: $otherKeys',
      );
    });
  });
}

/// A store that breaks its own contract, to prove the notifier survives it.
final class _ThrowingStore implements OnboardingSeenStore {
  @override
  Future<bool> readFailsOpen() async => false;

  @override
  Future<bool> write() => Future<bool>.error(StateError('disk is full'));
}
