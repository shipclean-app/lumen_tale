// Lumen Tale — where a route's screen is looked up, and why it is not a direct import.
//
// `architecture.md` § 3.1a: **"`app/` imports no `features/` code beyond the shell."**
// And yet *"a screen is a route and a route is a row in this table"* — so every screen
// slice has to be able to fill its own row. Those two statements cannot both be
// satisfied by an import, and the way out is a registry: `app/` owns the lookup, the
// feature slice registers itself, and neither imports the other.
//
// ## Keyed by PATH, not by destination
//
// The first version keyed by `AppNavDestination`, which covered the five branch roots
// and nothing else. `/more/settings/about` is a **sub-route**, it has no destination,
// and `3-5` could not register it — so the key had to become the path `AppRoutes`
// already gives every route one spelling of. One table, both call sites, and a branch
// root is just the route whose path happens to be a branch.
//
// ## A top-level mutable map, and that is not sloppiness
//
// It is the **composition root's** job. `main.dart` is the one file whose purpose is to
// know about every layer at once, and it already overrides providers drawn from three
// different layers. Registration belongs in the same list, for the same reason, and it
// fails at the same moment: a screen slice that exists but was never registered shows a
// placeholder on its own route, which is visible in one second of running the app.
//
// ## An unregistered route is a PLACEHOLDER, never a throw
//
// The alternative — a `!` on the lookup — would mean an unwired slice crashes the app on
// launch, in a way that reads as a provider bug. A placeholder says *"not written yet"*
// where the reader can see it, and `PlaceholderScreen` is already the app's vocabulary
// for that.

import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart' show GoRouterState;

import 'package:lumen_tale/app/router/placeholder_screen.dart';

/// A screen builder takes the `GoRouterState` as well as the context, because a route
/// table hands one to every builder — and a screen that ignores it must still be
/// callable through the same shape as one that reads it.
typedef ScreenBuilder =
    Widget Function(BuildContext context, GoRouterState state);

final Map<String, ScreenBuilder> _screens = <String, ScreenBuilder>{};

/// Registers the screen that fills [path].
///
/// Calling it twice for the same path **replaces** the entry, and `test/app/router/`
/// asserts the table's contents — a duplicate registration is not an error at runtime,
/// it is two answers to one question, and the second would be the one nobody reviewed.
void registerScreen(String path, ScreenBuilder builder) {
  _screens[path] = builder;
}

/// The whole table, unmodifiable, for `main.dart` and for the test that reads it.
Map<String, ScreenBuilder> get registeredScreens =>
    Map<String, ScreenBuilder>.unmodifiable(_screens);

/// The builder for [path], or a [PlaceholderScreen] if none is registered.
///
/// ⚠️ **`PlaceholderScreen(screenKey: path)` and not a constant.** The placeholder names
/// the route it stands in for, so a reader who reaches an unwired route can see which
/// one it was.
ScreenBuilder screenBuilderFor(String path) {
  return _screens[path] ??
      (BuildContext context, GoRouterState state) =>
          PlaceholderScreen(screenKey: path);
}

/// Routes that live **outside** the shell: `/reader/…` and `/onboarding`.
///
/// ## Why a SECOND table rather than an exception in the first
///
/// `app/` may not import `features/`, and the reader is a feature. The same reasoning that
/// produced [registerScreen] applies unchanged — so the reader uses the same mechanism
/// rather than a special case inside `app_router.dart` that would be the one place in the
/// app where a feature *is* named.
///
/// A separate map, not a flag on the same entry: a shell destination and a standalone route
/// differ in what the router does around them (branches, tabs, transitions), and encoding
/// that as a boolean on a builder would put the difference where it is easiest to forget.
final Map<String, ScreenBuilder> _standaloneRoutes = <String, ScreenBuilder>{};

/// Registers the screen that fills the standalone route at [path].
void registerStandaloneRoute(String path, ScreenBuilder builder) {
  _standaloneRoutes[path] = builder;
}

/// The whole standalone table, unmodifiable.
Map<String, ScreenBuilder> get registeredStandaloneRoutes =>
    Map<String, ScreenBuilder>.unmodifiable(_standaloneRoutes);

/// The builder for the standalone route at [path], or a placeholder naming the path.
///
/// ⚠️ **A placeholder here costs a blank screen on the reader's most important route.**
/// `/reader/…` is reached by `push` from four places, so an unregistered reader is a dead
/// end rather than a visible placeholder — which is why `test/app/router/` asserts this
/// table contains `/reader` as well as the shell's own entries.
ScreenBuilder standaloneRouteBuilderFor(String path) {
  return _standaloneRoutes[path] ??
      (BuildContext context, GoRouterState state) =>
          PlaceholderScreen(screenKey: path);
}

/// Clears both tables. **Tests only** — the app registers once, at the bootstrap.
@visibleForTesting
void clearRegisteredScreens() {
  _screens.clear();
  _standaloneRoutes.clear();
}
