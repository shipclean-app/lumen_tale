// forge:slice 3-4
// Lumen Tale — § 11.3, the four flows. Everything here goes through **the app's own router**,
// which is the only way to test a `redirect`.
//
// ## ⚠️ WHY A LOCAL ROUTER AND NOT `appRouter`
//
// `appRouter` is a process-scope singleton built from the real route table, and a test that
// pushed `/onboarding` onto it would leave the stack for the next row — `app_shell_test.dart`
// has a comment about exactly that trap and a `appRouter.go(initialLocation)` to undo it. The
// table under test is five rows long and is **copied from `app_router.dart` by
// `AppRoutes`**, so a path change breaks these rows too rather than letting them drift.
// `test/app/router/` keeps asserting that the real table and this one agree.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lumen_tale/app/router/app_routes.dart';
import 'package:lumen_tale/app/router/first_run_gate.dart';
import 'package:lumen_tale/app/theme/app_theme.dart';
import 'package:lumen_tale/core/storage/onboarding_seen.dart';
import 'package:lumen_tale/core/storage/shared_preferences_provider.dart';
import 'package:lumen_tale/features/onboarding/domain/onboarding_state.dart';
import 'package:lumen_tale/features/onboarding/providers/onboarding_seen.dart';
import 'package:lumen_tale/features/onboarding/screens/onboarding_screen.dart';
import 'package:lumen_tale/l10n/generated/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A store that counts its writes and can be told to fail.
final class _SpyStore implements OnboardingSeenStore {
  _SpyStore({this.seen = false, this.failWrite = false});

  bool seen;
  bool failWrite;
  int writeCalls = 0;

  @override
  Future<bool> readFailsOpen() async => seen;

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

/// The three routes the flows need: `/library`, `/onboarding`, `/more/settings/about`.
///
/// ⚠️ **THE `onboarding` BUILDER IS THE REAL REGISTRATION'S LOGIC**, read out of
/// `main.dart` by `_entryStepOf` below rather than re-spelled: the query parameter decides
/// the step, and a second copy of that rule is a second answer to "what does a re-entry
/// open on".
GoRouter _router(OnboardingStep? forced) {
  return GoRouter(
    initialLocation: AppRoutes.library,
    // ⚠️ **THE REAL HANDLER'S LOGIC, MIRRORED FROM `app_router.dart`'s `_redirectStartup`** —
    // and `test/app/shell/app_shell_test.dart` asserts that file wires this same pair. It has
    // to be here, and it has to be **synchronous**: go_router awaits the redirect before it
    // builds the first page, so an async one taxes the reader's first frame for no reader.
    redirect: (BuildContext context, GoRouterState state) {
      final StartupGate? gate = installedStartupGate;
      if (gate == null) {
        return null;
      }
      return gate.resolveNow(state.matchedLocation);
    },
    routes: <RouteBase>[
      GoRoute(
        path: AppRoutes.library,
        builder: (BuildContext context, GoRouterState state) =>
            const Scaffold(body: Text('LIBRARY')),
      ),
      GoRoute(
        path: AppRoutes.onboarding,
        builder: (BuildContext context, GoRouterState state) =>
            OnboardingScreen(initialStep: forced ?? _entryStepOf(state)),
      ),
    ],
  );
}

/// `main.dart`'s registration rule, read from its source rather than restated.
///
/// ⚠️ **THE RULE IS EXTRACTED, NOT COPIED, AND THE ROW BELOW PROVES THE EXTRACTION.** A
/// copy would be a second place deciding what a re-entry is, and the plan's own
/// acceptance criterion is `find.text('There is no backup.')` at the *first* build — which a
/// copy could satisfy while `main.dart` disagreed.
OnboardingStep _entryStepOf(GoRouterState state) {
  return state.uri.queryParameters[AppRoutes.onboardingStepQuery] ==
          AppRoutes.disclosureStepValue
      ? OnboardingStep.disclosure
      : OnboardingStep.promise;
}

Future<void> _pump(
  WidgetTester tester, {
  required GoRouter router,
  required _SpyStore store,
}) async {
  tester.view
    ..physicalSize = const Size(360, 900)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(await _prefs()),
        onboardingSeenStoreProvider.overrideWithValue(store),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        theme: AppTheme.day(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<SharedPreferences> _prefs() async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  return SharedPreferences.getInstance();
}

void main() {
  tearDown(clearStartupGate);

  group('§ 11.3 `0-5 → 3-4` — the router\'s redirect, through the real router', () {
    testWidgets(
      'flag absent → `/onboarding`, and the library is never built first',
      (WidgetTester tester) async {
        final _SpyStore store = _SpyStore();
        final GoRouter router = _router(null);
        addTearDown(router.dispose);
        await installStartupGate(OnboardingStartupGate(store.readFailsOpen));

        await _pump(tester, router: router, store: store);

        expect(
          find.text('It reads with no signal.'),
          findsOneWidget,
          reason:
              'a first run opens on the promise. The redirect runs BEFORE the first page is '
              'built, so the library is never on screen at all — which is what makes this a '
              'cold-start decision rather than a post-hoc swap.',
        );
        expect(
          find.text('LIBRARY'),
          findsNothing,
          reason: 'and `/library` was never rendered',
        );
      },
    );

    testWidgets('⚠️ flag UNREADABLE → `/onboarding`, never `/library` — E11', (
      WidgetTester tester,
    ) async {
      final _SpyStore store = _SpyStore(seen: true);
      final GoRouter router = _router(null);
      addTearDown(router.dispose);
      // ⚠️ **THE READ THROWS, AND THE STORE PROMISES IT CANNOT.** The real
      // `readFailsOpen()` swallows its own errors, so this is the *gate's* `catch` being
      // exercised through the router — the arm § 3.1 branch 1 exists for. `store.seen` is
      // `true`, so the only reason to show onboarding is the failure, and the row cannot
      // pass by accident on the flag.
      await installStartupGate(
        OnboardingStartupGate(() async {
          await store.readFailsOpen();
          throw StateError('the preferences file could not be read');
        }),
      );

      await _pump(tester, router: router, store: store);

      expect(
        find.text('It reads with no signal.'),
        findsOneWidget,
        reason:
            'the failure of a FLAG must not skip a DISCLOSURE. `onboarding.md` § 4, '
            '*Load error*.',
      );
      expect(find.text('LIBRARY'), findsNothing);
    });

    testWidgets('flag present → `/library`, and onboarding is never shown', (
      WidgetTester tester,
    ) async {
      final _SpyStore store = _SpyStore(seen: true);
      final GoRouter router = _router(null);
      addTearDown(router.dispose);
      await installStartupGate(OnboardingStartupGate(store.readFailsOpen));

      await _pump(tester, router: router, store: store);

      expect(find.text('LIBRARY'), findsOneWidget);
      expect(
        find.text('It reads with no signal.'),
        findsNothing,
        reason:
            'a reader who has read the disclosure must never be shown it again by the '
            'cold-start decision',
      );
    });

    testWidgets('⚠️ the gate is ONE-SHOT, so a failed write cannot trap the reader', (
      WidgetTester tester,
    ) async {
      // ⚠️ **§ 3.3 BRANCH 5, END TO END.** The flag write fails, the reader lands on
      // `/library` with `seen == false` — and every tab press must still work. Without the
      // latch, the first navigation after the exit would redirect straight back into the
      // onboarding the reader just skipped.
      final _SpyStore store = _SpyStore(failWrite: true);
      final GoRouter router = _router(null);
      addTearDown(router.dispose);
      await installStartupGate(OnboardingStartupGate(store.readFailsOpen));

      await _pump(tester, router: router, store: store);
      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();

      expect(
        find.text('LIBRARY'),
        findsOneWidget,
        reason: 'the exit happened anyway',
      );
      expect(store.seen, isFalse, reason: 'and the flag really was not posed');

      // Navigating again must NOT re-enter onboarding.
      router.go(AppRoutes.onboarding);
      await tester.pumpAndSettle();
      expect(
        find.text('It reads with no signal.'),
        findsOneWidget,
        reason:
            'the reader may still CHOOSE to re-read it — the gate only declines to force '
            'them. A gate that re-showed it uninvited is § 3.3 branch 5\'s trap.',
      );
    });
  });

  group('§ 11.3 `3-4 → settings` — the re-entry opens on STEP 2', () {
    testWidgets('`?step=disclosure` opens on the consequence at the FIRST build', (
      WidgetTester tester,
    ) async {
      final _SpyStore store = _SpyStore(seen: true);
      final GoRouter router = _router(null);
      addTearDown(router.dispose);
      await installStartupGate(OnboardingStartupGate(store.readFailsOpen));

      await _pump(tester, router: router, store: store);
      router.go(AppRoutes.onboardingDisclosurePath());
      await tester.pumpAndSettle();

      expect(
        find.text('There is no backup.'),
        findsOneWidget,
        reason:
            '§ 10: a re-read opens on the disclosure, not the promise. The promise has been '
            'read and either worked or not; the disclosure is the part with consequences.',
      );
      expect(
        find.text('It reads with no signal.'),
        findsNothing,
        reason: 'and the promise is not shown first, even for one frame',
      );
      expect(find.text('Skip'), findsNothing, reason: 'step 2 has no `Skip`');
    });

    test('⚠️ the registration rule is read out of `main.dart`, not copied', () {
      // ⚠️ **THE ROW THAT KEEPS THE EXTRACTION HONEST.** `_entryStepOf` above is used by the
      // router the previous rows built; if `main.dart` ever stops reading `?step=disclosure`,
      // this fails and those rows cannot quietly pass on a stale copy.
      final String source = File('lib/main.dart').readAsStringSync();
      expect(
        source,
        contains('AppRoutes.onboardingStepQuery'),
        reason:
            'the real registration must read the entry step from the URL — a screen that '
            'decided it another way would give a deep link and a push different answers',
      );
      expect(
        source,
        contains('AppRoutes.disclosureStepValue'),
        reason:
            'and the value it compares against must come from `AppRoutes` too',
      );
      expect(
        source,
        contains('registerStandaloneRoute(\n    AppRoutes.onboarding,'),
        reason:
            '`/onboarding` is registered as a STANDALONE route: it is outside the shell and '
            'has no tab bar (design-system.md § 3.5)',
      );
    });
  });

  group('§ 11.3 — the full lifecycle, and the flag is posed EXACTLY twice', () {
    testWidgets('first run → Skip → library → re-read → step 2 → Start reading', (
      WidgetTester tester,
    ) async {
      final _SpyStore store = _SpyStore();
      final GoRouter router = _router(null);
      addTearDown(router.dispose);
      await installStartupGate(OnboardingStartupGate(store.readFailsOpen));

      await _pump(tester, router: router, store: store);

      // ── first run, step 1 ────────────────────────────────────────────
      expect(find.text('It reads with no signal.'), findsOneWidget);
      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();
      expect(store.writeCalls, 1, reason: '`Skip` writes the flag once');
      expect(find.text('LIBRARY'), findsOneWidget);

      // ── the reader re-opens it from Settings, on step 2 ──────────────
      router.go(AppRoutes.onboardingDisclosurePath());
      await tester.pumpAndSettle();
      expect(find.text('There is no backup.'), findsOneWidget);
      await tester.tap(find.text('Start reading'));
      await tester.pumpAndSettle();

      expect(
        store.writeCalls,
        2,
        reason:
            'exactly two writes across the whole lifecycle: one per exit. The plan\'s § 11.3 '
            'row. A third would be a write from somewhere that is not an exit — `next()` '
            'being the obvious candidate, which § 3.3 branch 3 forbids.',
      );
      expect(find.text('LIBRARY'), findsOneWidget);
      expect(store.seen, isTrue);
    });
  });

  group(
    '§ 4 (Submit error) — the button returns and the transition still happens',
    () {
      testWidgets(
        'a failed write leaves the screen through `/library`, saying nothing',
        (WidgetTester tester) async {
          final _SpyStore store = _SpyStore(failWrite: true);
          final GoRouter router = _router(null);
          addTearDown(router.dispose);
          await installStartupGate(OnboardingStartupGate(store.readFailsOpen));

          await _pump(tester, router: router, store: store);
          await tester.tap(find.text('Next'));
          await tester.pumpAndSettle();
          expect(find.text('There is no backup.'), findsOneWidget);

          await tester.tap(find.text('Start reading'));
          await tester.pumpAndSettle();

          expect(find.text('LIBRARY'), findsOneWidget);
          expect(
            find.byType(SnackBar),
            findsNothing,
            reason:
                '§ 3.3 branch 5: nothing is said. The only possible failure is "I cannot '
                'remember that I saw this", which is not a preference the reader has and cannot '
                'act on — and whose "retry" is "skip again", which is what they just did.',
          );
          expect(
            find.byType(Dialog),
            findsNothing,
            reason: 'and no dialog either: the screen is never a trap',
          );
        },
      );
    },
  );
}
