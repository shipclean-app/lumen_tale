// Lumen Tale — where a branch root's screen is looked up, and why it is not a direct
// import.
//
// `architecture.md` § 3.1a: **"`app/` imports no `features/` code beyond the shell."**
// And yet *"a screen is a route and a route is a row in this table"* — so every screen
// slice has to be able to fill its own row. Those two statements cannot both be
// satisfied by an import, and the way out is a registry: `app/` owns the lookup, the
// feature slice registers itself, and neither imports the other.
//
// ## A top-level mutable map, and that is not sloppiness
//
// It is the **composition root's** job. `main.dart` is the one file whose purpose is
// to know about every layer at once, and it already overrides three providers drawn
// from three different layers. Registration belongs in the same list, for the same
// reason, and it fails at the same moment: a screen slice that exists but was never
// registered shows a placeholder on its tab, which is visible in one second of
// running the app.
//
// ## An unregistered destination is a PLACEHOLDER, never a throw
//
// The alternative — a `!` on the lookup — would mean an unwired slice crashes the app
// on launch, in a way that reads as a provider bug. A placeholder says *"not written
// yet"* where the reader can see it, and `PlaceholderScreen` is already the app's
// vocabulary for that.

import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart' show GoRouterState;

import 'package:lumen_tale/app/router/app_nav_destinations.dart';
import 'package:lumen_tale/app/router/placeholder_screen.dart';

/// A screen builder takes the `GoRouterState` as well as the context, because a route
/// table hands one to every builder — and a screen that ignores it must still be
/// callable through the same shape as one that reads it.
typedef ScreenBuilder =
    Widget Function(BuildContext context, GoRouterState state);

final Map<AppNavDestination, ScreenBuilder> _screens =
    <AppNavDestination, ScreenBuilder>{};

/// Registers the screen that fills [destination]'s branch root.
///
/// Calling it twice for the same destination **replaces** the entry, and a test
/// asserts that — a duplicate registration is not an error at runtime, it is two
/// answers to one question, and the second would be the one nobody reviewed.
void registerScreen(AppNavDestination destination, ScreenBuilder builder) {
  _screens[destination] = builder;
}

/// Registered builders, for `main.dart` and for the test that reads the table.
///
/// Exposed so a test can assert **which** destinations have real screens, rather than
/// inferring it from what renders.
Map<AppNavDestination, ScreenBuilder> get registeredScreens =>
    Map<AppNavDestination, ScreenBuilder>.unmodifiable(_screens);

/// The builder for [destination], or a [PlaceholderScreen] if none is registered.
///
/// ⚠️ **`PlaceholderScreen(screenKey: destination.path)` and not a constant.** The
/// placeholder names the route it stands in for, so a reader who reaches an unwired
/// tab can see which one it was.
ScreenBuilder screenBuilderFor(AppNavDestination destination) {
  return _screens[destination] ??
      (BuildContext context, GoRouterState state) =>
          PlaceholderScreen(screenKey: destination.path);
}

/// Clears the registry. **Tests only** — the app registers once, at the bootstrap.
@visibleForTesting
void clearRegisteredScreens() => _screens.clear();
