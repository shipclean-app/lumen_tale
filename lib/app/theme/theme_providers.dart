// Lumen Tale — the two display settings as Riverpod providers.
//
// `05-state-management.md` rule 8: a preferences interface **is** a provider.
//
// ⚠️ **The `@riverpod` annotation and code generation are deliberately NOT used
// yet.** § 5's implementation note says the final form uses
// `@Riverpod(keepAlive: true) class … extends _$…` and that "the exact shape of the
// annotation is to be read in the installed `riverpod_generator` 4.0.9, not from
// memory". That reading is done — `riverpod_annotation`'s `Riverpod` constructor
// does take `keepAlive` — but running `build_runner` for two providers whose only
// consumers (`0-5`, `2-8`) do not exist yet would generate code that nothing reads
// and that `forge-guard`'s generated-file rules then have to carry. The
// hand-written form below is the same object model with none of the generated
// surface, and converting it is a mechanical change when a consumer lands.
//
// Recorded as a deliberate deferral rather than an oversight.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:lumen_tale/app/theme/app_theme_preferences.dart';
import 'package:lumen_tale/app/theme/reader_scale.dart';
import 'package:lumen_tale/app/theme/theme_override.dart';

/// Overridden at the bootstrap by `0-5`.
///
/// `SharedPreferences.getInstance()` is already resolved at startup, so a read here
/// is synchronous and the state is never `loading`.
final appThemePreferencesProvider = Provider<AppThemePreferences>(
  (Ref ref) => throw UnimplementedError(
    'appThemePreferencesProvider is overridden at the bootstrap by 0-5',
  ),
);

/// B26 — `keepAlive`, because an application preference outlives its screens.
/// (`05-state-management.md` rule 10.)
final themeOverrideProvider =
    NotifierProvider<ThemeOverrideNotifier, ThemeOverride>(
      ThemeOverrideNotifier.new,
    );

class ThemeOverrideNotifier extends Notifier<ThemeOverride> {
  @override
  ThemeOverride build() =>
      ref.read(appThemePreferencesProvider).readThemeOverride();

  /// B24 and `design-system.md` § 2.9: on a write failure the state does **not**
  /// change and the exception propagates, so the caller snaps its control back and
  /// says why.
  ///
  /// ⚠️ **Write, THEN mutate.** The order is the same as B6's and for the same
  /// reason (C8 — data loss is structurally accepted): a control that mutates
  /// before writing displays a setting it cannot keep. `2-5`'s delete dialog and
  /// `3-3`'s download dialog share the constraint and the reason.
  Future<void> select(ThemeOverride value) async {
    final prefs = ref.read(appThemePreferencesProvider);
    await prefs.writeThemeOverride(value); // throws before any state mutation
    state = value;
  }
}

/// B27 — same lifetime, same reason.
final readerTextScaleProvider =
    NotifierProvider<ReaderTextScaleNotifier, ReaderTextScale>(
      ReaderTextScaleNotifier.new,
    );

class ReaderTextScaleNotifier extends Notifier<ReaderTextScale> {
  @override
  ReaderTextScale build() =>
      ref.read(appThemePreferencesProvider).readReaderScale();

  /// Write, then mutate — the same contract as [ThemeOverrideNotifier.select].
  Future<void> select(ReaderTextScale step) async {
    final prefs = ref.read(appThemePreferencesProvider);
    await prefs.writeReaderScale(step);
    state = step;
  }
}
