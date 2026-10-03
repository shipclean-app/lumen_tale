// Lumen Tale — B26, "follow the phone, or overrule it".

import 'package:flutter/material.dart';

enum ThemeOverride {
  /// Follows `MediaQuery.platformBrightnessOf`. **The default**, and the only
  /// value that honours the phone's setting without internal state replacing it.
  system,

  /// Day forced: warm paper.
  day,

  /// Night forced: cold ink.
  night;

  /// ⚠️ The default is `system`, and it is **absent from storage**.
  ///
  /// A missing key and a key whose value is `system` are the same state, so
  /// `system` is never written to mean "default" — writing it would create a third
  /// source of truth alongside the enum and the absent key.
  static ThemeOverride fromStorage(String? raw) {
    for (final value in ThemeOverride.values) {
      if (value.name == raw) return value;
    }
    // An unreadable value — "sombre", or "dark" from another version — resolves
    // to `system`. An earlier version must not prevent the app from starting.
    return ThemeOverride.system;
  }

  /// The **only** place in the project that translates the override into a
  /// `ThemeMode`. `0-5` does not do it itself: two translations of one value are
  /// two answers to "which night is it?".
  ThemeMode resolve(Brightness platformBrightness) => switch (this) {
    ThemeOverride.system =>
      platformBrightness == Brightness.dark ? ThemeMode.dark : ThemeMode.light,
    ThemeOverride.day => ThemeMode.light,
    ThemeOverride.night => ThemeMode.dark,
  };
}
