// Lumen Tale — the route table, and nothing else.
//
// ⚠️ **This is the only file in the project where a `GoRoute` exists.** Features
// push `AppRoutes.readerFor(…)` through [openReader] and nothing else; that is the
// whole of `09-widgets-ui.md` convention 10.
//
// ## `appRouter` is a top-level `final`, not a value built in `build()`
//
// E12: *the phone's language changes — the app's text follows, **with no loss of
// library, downloads or progress**.* A `GoRouter` built inside the root widget's
// `build` is rebuilt the moment the root rebuilds, and the root rebuilds the
// instant the locale changes. The new router starts at `initialLocation`, so the
// reader loses the stack they were in — the reader's place in the app, lost to a
// language switch. Nothing errors, so nothing reports it.
//
// The fix is not subtle, which is why it is written here rather than left for a
// reader to infer: build it once, at process scope.
//
// ## The reader is **pushed**, not `go`-n — and that is a structural requirement
//
// `/reader/…` is outside the shell: no tab bar (`design-system.md` § 3.5). The
// only way to render outside a `StatefulShellRoute` in go_router is to place the
// route at the **root**, as a sibling of the shell.
//
// `GoRouter.go` **replaces** the root page list. Navigating to a root-level route
// with `go` therefore unmounts the shell: the reader loses the tab it came from,
// that tab's back stack, its scroll position, and `pop` then has nothing to pop —
// a reader who opens a chapter from *Updates* and presses back leaves the app.
//
// `GoRouter.push` **appends** to the root page list
// (`RouteMatchList.push` → `_createNewMatchUntilIncompatible` adds the
// imperative match after the shell match, verified in go_router 18.0.2
// `lib/src/match.dart`). So the shell stays mounted underneath, and `pop` returns
// to exactly where the reader came from.
//
// Therefore [openReader] and [openOnboarding] exist and use `push`. A feature that
// wrote `context.go(AppRoutes.readerFor(…))` would compile, work on the happy path,
// and silently destroy the navigation stack — so the capability is exposed as a
// function that only contains the correct call.

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:lumen_tale/app/router/app_nav_destinations.dart';
import 'package:lumen_tale/app/router/app_routes.dart';
import 'package:lumen_tale/app/router/placeholder_screen.dart';
import 'package:lumen_tale/app/router/screen_registry.dart';
import 'package:lumen_tale/app/shell/app_shell.dart';

/// The root navigator's key.
///
/// ⚠️ **Assigned, not referenced by a `parentNavigatorKey`.** `parentNavigatorKey`
/// must name a shell's key or this one, and every route that renders outside the
/// shell is a root route, so nothing needs it. The key exists because go_router
/// asserts on it and because a shell branch that ever needs a root-pushed route
/// will need it by name rather than by discovering the constraint at the gate.
final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>(
  debugLabel: 'root',
);

/// One navigator key per bottom-nav branch.
///
/// `StatefulShellRoute.indexedStack` keeps one `Navigator` per branch, and the keys
/// are indexed by [AppNavDestination.rank] so a branch and its key cannot drift
/// apart.
final List<GlobalKey<NavigatorState>> branchKeys =
    List<GlobalKey<NavigatorState>>.generate(
      AppNavDestination.values.length,
      (int index) => GlobalKey<NavigatorState>(debugLabel: 'branch-$index'),
      growable: false,
    );

/// The app's single router, built once for the life of the process.
final GoRouter appRouter = _build();

/// ADR-018: **Library first**, because it has the highest frequency and is the only
/// screen that can *open* the loop. `design-system.md` § 3.2 refuses an "écran
/// d'accueil qui est un sommaire".
const String initialLocation = AppRoutes.library;

/// Opens the reader, **on top of** the shell.
///
/// See the file header for why this is `push` and not `go`: with `go` the shell is
/// unmounted and the reader's place in the app is destroyed.
Future<Object?> openReader(
  BuildContext context, {
  required String novelId,
  required String chapterId,
}) {
  return GoRouter.of(context).push(AppRoutes.readerFor(novelId, chapterId));
}

/// Opens onboarding, **on top of** the shell, for the same reason.
///
/// `settings.md` § 5 opens it at **step 2** — the step-1 promise has already been
/// read — which is why there is **no startup redirect to it**. E11 requires the
/// "nothing here is backed up" disclosure to be made *before* an uninstall, and the
/// only moment the shell could decide that alone is first run. This slice does not
/// decide it: the trigger belongs to whichever slice writes `3-4`, and inventing a
/// preferences flag here for "do not miss anything" would be the false promise E11
/// forbids. `0-5` § 7 question 6 records that gap rather than papering over it.
Future<Object?> openOnboarding(BuildContext context) {
  return GoRouter.of(context).push(AppRoutes.onboarding);
}

/// Opens a novel's details, **on top of** the branch the reader is already on.
///
/// `push`, not `go`, and the reason is different from [openReader]'s: this route
/// *is* inside the shell, so `go` would work — but it would replace the branch's page
/// list, so the reader who opened a novel from *History* and pressed back would land
/// nowhere useful. A sibling detail page is a stack push; the tab is a branch switch.
Future<Object?> openNovelDetails(
  BuildContext context, {
  required String novelId,
}) {
  return GoRouter.of(context).push(AppRoutes.novelDetailsFor(novelId));
}

/// Switches to the **Browse** branch, replacing its page list.
///
/// ⚠️ **`go`, and unlike [openReader] that is correct.** `/browse` is a sibling
/// branch of a `StatefulShellRoute.indexedStack`, so switching branches means moving
/// between navigators — there is nothing to push on top of a branch the reader has not
/// visited, and `push` on a branch root that does not exist yet produces a route with
/// no navigator beneath it.
void openBrowse(BuildContext context) {
  GoRouter.of(context).go(AppRoutes.browse);
}

GoRouter _build() {
  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: initialLocation,
    routes: <RouteBase>[
      // ── the shell: five branches, ADR-018's order ─────────────────────
      StatefulShellRoute.indexedStack(
        builder:
            (
              BuildContext context,
              GoRouterState state,
              StatefulNavigationShell shell,
            ) => AppShell(navigationShell: shell),
        branches: <StatefulShellBranch>[
          _branch(AppNavDestination.library),
          _branch(AppNavDestination.updates),
          _branch(AppNavDestination.history),
          _branch(AppNavDestination.browse),
          _branch(AppNavDestination.more),
        ],
      ),

      // ── OUTSIDE the shell: no tab bar, no tab's back stack ───────────
      //
      // `design-system.md` § 3.4: **the reader has no transition in.** Opening a
      // chapter does not slide — the text is simply there, because on the one screen
      // where waiting is the whole cost, a slide makes the reader wait.
      //
      // `onboarding` *does* slide: it is a lateral push from Settings like any other
      // destination, and it is the reader, not this screen, that opted out of the
      // transition.
      GoRoute(
        path: AppRoutes.reader,
        // ⚠️ **A builder from the standalone registry, and never a named feature screen.**
        // `app/` may not import `features/`; the composition root registers and this table
        // resolves. `NoTransitionPage` is kept for the reason in the comment above.
        pageBuilder: (BuildContext context, GoRouterState state) =>
            NoTransitionPage<void>(
              child: standaloneRouteBuilderFor(AppRoutes.reader)(
                context,
                state,
              ),
            ),
      ),
      GoRoute(
        path: AppRoutes.onboarding,
        builder: standaloneRouteBuilderFor(AppRoutes.onboarding),
      ),
    ],

    // B24: "no action fails silently to a blank screen or a silent spinner".
    // Every key used here already exists in both ARB files, so the error screen
    // adds no orphan key when it is eventually deleted.
    errorBuilder: (BuildContext context, GoRouterState state) =>
        const PlaceholderScreen(screenKey: 'unknown-route'),
  );
}

/// One branch: a tab root, plus the routes that hang below it.
///
/// Sub-routes are declared **relative** (`'novel/:novelId'`, not the full path).
/// `go_router` resolves them against the branch root, so writing the full path here
/// would produce `/library/library/novel/x` — a route that exists, matches nothing,
/// and is reached by nothing.
StatefulShellBranch _branch(AppNavDestination destination) {
  return StatefulShellBranch(
    navigatorKey: branchKeys[destination.rank - 1],
    routes: <RouteBase>[
      GoRoute(
        path: destination.path,
        // ⚠️ **`screenBuilderFor`, not a direct import of a screen.**
        //
        // `architecture.md` § 3.1a: `app/` imports no `features/` code beyond the
        // shell — while *"a screen is a route and a route is a row in this table"*.
        // The registry is what lets both hold: `app/` owns the lookup, the feature
        // slice registers itself, and neither imports the other.
        builder: (BuildContext context, GoRouterState state) =>
            screenBuilderFor(destination.path)(context, state),
        routes: _subRoutesFor(destination),
      ),
    ],
  );
}

/// The routes under [destination].
///
/// ⚠️ **Updates and History return an empty list, and that is a verified fact, not
/// a gap.** `design-system.md` § 3.5's table is reconciled against the eighteen
/// screen files in *both* directions, so a sub-route missing from here is missing
/// because **no screen pushes one** — not because nobody got to it. An empty list
/// says "checked, none", which is a different claim from "not written yet", and the
/// distinction is the whole reason the reconciliation runs both ways.
List<RouteBase> _subRoutesFor(AppNavDestination destination) {
  switch (destination) {
    case AppNavDestination.library:
      return <RouteBase>[
        GoRoute(
          path: 'novel/:novelId',
          // ⚠️ **`screenBuilderFor`, like `settings` below — and this line is the fix
          // for four slices that were implemented, registered, tested and marked
          // validated… and unreachable.**
          //
          // `registerScreens()` registered a builder for `AppRoutes.novelDetails`,
          // `AppRoutes.sourceGenre` and `AppRoutes.sourceUnavailable`, and this table
          // rendered `PlaceholderScreen` for all three. The registration was real and
          // the route never consulted it, so `3-1`, `6-2`, `3-6` and `3-2` opened a
          // placeholder naming the route. Nothing failed: the registration test
          // asserted the TABLE contained the path, and it did.
          //
          // That is the hazard `registerScreens`' own doc comment names — "a
          // registration that can only happen by running the app cannot be asserted" —
          // except here the registration WAS assertable and nobody asserted the half
          // that matters: that the route RESOLVES it.
          builder: (BuildContext context, GoRouterState state) =>
              screenBuilderFor(AppRoutes.novelDetails)(context, state),
        ),
      ];

    case AppNavDestination.browse:
      return <RouteBase>[
        GoRoute(
          // ⚠️ **`3-1` and `6-2`'s catalogue. It was a placeholder while both slices
          // were validated.** See the library branch above for the whole story.
          path: ':sourceId',
          builder: (BuildContext context, GoRouterState state) =>
              screenBuilderFor(AppRoutes.sourceBrowse)(context, state),
          routes: <RouteBase>[
            GoRoute(
              path: 'genre/:genre',
              // ⚠️ **The FULL route path as the key, never the relative one.** The
              // table is keyed by what `AppRoutes` spells out, so a relative path
              // registers under a key nothing looks up — a screen that reported itself
              // registered and rendered a placeholder. Same reason as `about` below.
              builder: (BuildContext context, GoRouterState state) =>
                  screenBuilderFor(AppRoutes.sourceGenre)(context, state),
            ),
            GoRoute(
              path: 'unavailable',
              // ⚠️ **`3-6` — SC-6's only surface — was a placeholder too.**
              builder: (BuildContext context, GoRouterState state) =>
                  screenBuilderFor(AppRoutes.sourceUnavailable)(context, state),
            ),
          ],
        ),
      ];

    case AppNavDestination.more:
      return <RouteBase>[
        GoRoute(
          path: 'downloads',
          builder: (BuildContext context, GoRouterState state) =>
              const PlaceholderScreen(screenKey: AppRoutes.downloads),
        ),
        GoRoute(
          path: 'settings',
          builder: (BuildContext context, GoRouterState state) =>
              screenBuilderFor(AppRoutes.settings)(context, state),
          routes: <RouteBase>[
            // ⚠️ **`screenBuilderFor` with the FULL route path, not the relative one.**
            //
            // The table is keyed by what `AppRoutes` spells out, and the relative
            // `'about'` would register under a key nothing looks up — a screen that
            // reported itself registered and rendered a placeholder.
            GoRoute(
              path: 'reader',
              builder: (BuildContext context, GoRouterState state) =>
                  screenBuilderFor(AppRoutes.settingsReader)(context, state),
            ),
            GoRoute(
              path: 'about',
              builder: (BuildContext context, GoRouterState state) =>
                  screenBuilderFor(AppRoutes.settingsAbout)(context, state),
            ),
          ],
        ),
      ];

    // Updates and History have no sub-route in § 3.5's table, and no screen
    // pushes one. See [_subRoutesFor].
    case AppNavDestination.updates:
    case AppNavDestination.history:
      return const <RouteBase>[];
  }
}
