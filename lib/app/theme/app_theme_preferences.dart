// Lumen Tale — the two display settings this foundation owns, and nothing else.
//
// `architecture.md` § 4.7: reading settings live in `shared_preferences`, not in a
// drift table. This class stores exactly two keys.
//
// **No default value is written at construction.** The default is the *absence* of
// a key, and absence resolves to `system` / `md`. Writing a 'default' on first run
// would create a third source of truth: the file, the absent key, and the enum.

import 'package:lumen_tale/app/theme/reader_scale.dart';
import 'package:lumen_tale/app/theme/theme_override.dart';
import 'package:shared_preferences/shared_preferences.dart';

abstract interface class AppThemePreferences {
  ThemeOverride readThemeOverride();
  ReaderTextScale readReaderScale();
  Future<void> writeThemeOverride(ThemeOverride value);
  Future<void> writeReaderScale(ReaderTextScale value);
}

final class SharedPrefsThemePreferences implements AppThemePreferences {
  const SharedPrefsThemePreferences(this._prefs);

  final SharedPreferences _prefs;

  static const String themeOverrideKey = 'app.themeOverride';
  static const String readerScaleKey = 'reader.textScale';

  /// `SharedPreferences` is already loaded at startup (`getInstance()` is a future
  /// resolved once), so a read here is **synchronous** and cannot be an
  /// `AsyncValue`. `14-design-tokens.md`'s `Switch` relies on exactly that to
  /// justify having no loading state.
  @override
  ThemeOverride readThemeOverride() =>
      ThemeOverride.fromStorage(_prefs.getString(themeOverrideKey));

  @override
  ReaderTextScale readReaderScale() =>
      ReaderTextScale.fromStorage(_prefs.getString(readerScaleKey));

  @override
  Future<void> writeThemeOverride(ThemeOverride value) async {
    // `setString` returns a `Future<bool>`. A `false` is a platform refusal, not an
    // exception: the `Switch`'s catcher would never see the failure if it were
    // ignored, and the control would display "night" while nothing was written.
    // B24: the failure must be **visible**.
    final ok = await _prefs.setString(themeOverrideKey, value.name);
    if (!ok) {
      throw ThemePersistenceException('themeOverride', value.name, null);
    }
  }

  @override
  Future<void> writeReaderScale(ReaderTextScale value) async {
    final ok = await _prefs.setString(readerScaleKey, value.name);
    if (!ok) {
      throw ThemePersistenceException('readerScale', value.name, null);
    }
  }
}

/// A display setting that could not be written.
///
/// **Distinct from `AppException`, and deliberately so**: `13-error-handling.md`
/// requires "a subclass only when a caller needs `on X catch`". Exactly one does:
/// the `Switch`'s `failed` state in `design-system.md` § 2.9, which must **snap
/// back** and say so. No other caller has a branch to write.
final class ThemePersistenceException implements Exception {
  const ThemePersistenceException(this.key, this.value, this.cause);

  final String key;

  /// The value **attempted**, not the one in force — that is what the reader just
  /// chose, and what has to be named back to them.
  final String value;

  final Object? cause;

  @override
  String toString() => 'ThemePersistenceException: $key=$value not written';
}
