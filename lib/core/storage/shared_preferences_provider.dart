// Lumen Tale — the one `SharedPreferences` instance, as a provider.
//
// `02-architecture.md`: `core/storage` owns *where a preference lives*, and this is
// that fact expressed once.
//
// ## Why the instance is resolved at the bootstrap and not here
//
// `SharedPreferences.getInstance()` is asynchronous, and `main.dart` already awaits it
// before any route exists — so a later read is synchronous and a settings-store load
// error is a **bootstrap** failure rather than a screen state. This provider is the
// declared place that promise is cashed in: it holds the instance, it never awaits,
// and a second `getInstance()` anywhere would produce a second object over the same
// file — two caches that disagree, with no error and no trace.
//
// ## Why it throws instead of building one
//
// A provider that called `getInstance()` itself would be a provider that can be read
// during a build and suspend the widget tree — and `MissingPluginException` on a
// platform with no plugin would arrive as a blank screen rather than as a failed
// launch. `main.dart` already explains this for the theme; the rule is the same, and
// the override lives next to `appThemePreferencesProvider`'s.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Overridden at the bootstrap by `main.dart`, with the instance it awaited.
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (Ref ref) => throw UnimplementedError(
    'sharedPreferencesProvider is overridden at the bootstrap by main(), which is '
    'the only place that awaits getInstance()',
  ),
);
