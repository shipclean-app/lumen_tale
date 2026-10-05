// forge:slice 2-8
// Lumen Tale — `2-8` § 11.1: the seam the reader's controls write through.
//
// ## Scope, stated so this file is not read as more than it is
//
// `theme-type` already owns the store rows — the round trip, the by-name key, the unknown
// value and the write-then-mutate contract — and
// `test/app/theme/app_theme_preferences_test.dart` asserts all four. Repeating them here
// would be a second suite for a second file, and a suite that can drift from the one that
// owns the claim.
//
// So this file asserts what is **`2-8`'s and nobody else's**: that `ReaderPreferencesController`
// is a *pass-through* rather than a second stack, in both directions and across a restart.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumen_tale/app/theme/app_theme_preferences.dart';
import 'package:lumen_tale/app/theme/reader_scale.dart';
import 'package:lumen_tale/app/theme/theme_override.dart';
import 'package:lumen_tale/app/theme/theme_providers.dart';
import 'package:lumen_tale/features/reader/domain/reader_preferences_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A store that keeps its bytes in memory and can be told to refuse once.
final class FlakyPreferences implements AppThemePreferences {
  final Map<String, String> bytes = <String, String>{};

  /// When set, the next write refuses and clears the flag.
  bool refuse = false;

  @override
  ReaderTextScale readReaderScale() => ReaderTextScale.fromStorage(
    bytes[SharedPrefsThemePreferences.readerScaleKey],
  );

  @override
  ThemeOverride readThemeOverride() => ThemeOverride.fromStorage(
    bytes[SharedPrefsThemePreferences.themeOverrideKey],
  );

  @override
  Future<void> writeReaderScale(ReaderTextScale value) async {
    if (refuse) {
      refuse = false;
      throw ThemePersistenceException(
        SharedPrefsThemePreferences.readerScaleKey,
        value.name,
        null,
      );
    }
    bytes[SharedPrefsThemePreferences.readerScaleKey] = value.name;
  }

  @override
  Future<void> writeThemeOverride(ThemeOverride value) async {
    if (refuse) {
      refuse = false;
      throw ThemePersistenceException(
        SharedPrefsThemePreferences.themeOverrideKey,
        value.name,
        null,
      );
    }
    bytes[SharedPrefsThemePreferences.themeOverrideKey] = value.name;
  }
}

/// A fresh container over [store] — disposed when the current test ends.
ProviderContainer containerOver(AppThemePreferences store) {
  final ProviderContainer container = ProviderContainer(
    overrides: [appThemePreferencesProvider.overrideWithValue(store)],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('the seam reads THROUGH `theme-type`', () {
    test('its two values ARE the two providers, not copies', () {
      final ProviderContainer container = containerOver(FlakyPreferences());
      final ReaderPreferencesController controller = container.read(
        readerPreferencesControllerProvider,
      );

      expect(controller.scale, container.read(readerTextScaleProvider));
      expect(controller.themeOverride, container.read(themeOverrideProvider));
      expect(
        controller,
        isA<ReaderPreferencesController>(),
        reason: 'and it is the interface the widgets program against',
      );
    });

    test('a write made ANYWHERE is what the reader reads back', () async {
      // **The two doors, from the reader's side.** The values were written by the
      // foundation's own notifiers — which is exactly what `/more/settings/reader` does —
      // and the reader must see them. A seam holding its own copy passes every row that
      // writes through it and fails this one.
      final ProviderContainer container = containerOver(FlakyPreferences());
      await container
          .read(themeOverrideProvider.notifier)
          .select(ThemeOverride.night);
      await container
          .read(readerTextScaleProvider.notifier)
          .select(ReaderTextScale.xxl);

      final ReaderPreferencesController controller = container.read(
        readerPreferencesControllerProvider,
      );
      expect(controller.scale, ReaderTextScale.xxl);
      expect(controller.themeOverride, ThemeOverride.night);
    });
  });

  group('B27 — a write through the seam survives the app being killed', () {
    test('all five steps come back in a brand-new container', () async {
      // **A new container, never a re-read of a field.** A container that merely outlived
      // its screen would pass this without anything having been written, which is why the
      // second one is built from the store and nothing else.
      final FlakyPreferences store = FlakyPreferences();
      for (final ReaderTextScale step in ReaderTextScale.values) {
        await containerOver(
          store,
        ).read(readerPreferencesControllerProvider).selectScale(step);

        expect(
          containerOver(store).read(readerTextScaleProvider),
          step,
          reason:
              '${step.name} was written; a fresh container must read it back',
        );
      }
    });

    test('all three themes come back too', () async {
      final FlakyPreferences store = FlakyPreferences();
      for (final ThemeOverride value in ThemeOverride.values) {
        await containerOver(
          store,
        ).read(readerPreferencesControllerProvider).selectOverride(value);
        expect(containerOver(store).read(themeOverrideProvider), value);
      }
    });

    test(
      'the real SharedPreferences file holds the NAME, and it is read back',
      () async {
        // **The real store, once.** An in-memory double proves the seam; only
        // `SharedPreferences` proves the KEY is the thing that survives a process death — and
        // the raw string is what an earlier version wrote and a later one must still read.
        SharedPreferences.setMockInitialValues(<String, Object>{});
        final SharedPreferences prefs = await SharedPreferences.getInstance();
        final SharedPrefsThemePreferences store = SharedPrefsThemePreferences(
          prefs,
        );

        await containerOver(store)
            .read(readerPreferencesControllerProvider)
            .selectScale(ReaderTextScale.xl);
        await containerOver(store)
            .read(readerPreferencesControllerProvider)
            .selectOverride(ThemeOverride.night);

        expect(
          prefs.getString(SharedPrefsThemePreferences.readerScaleKey),
          'xl',
          reason:
              'the name, not the index: an index remaps every value on a reorder',
        );
        expect(
          containerOver(store).read(readerTextScaleProvider),
          ReaderTextScale.xl,
        );
        expect(
          containerOver(store).read(themeOverrideProvider),
          ThemeOverride.night,
        );
      },
    );
  });

  group('B24 — the seam propagates the refusal instead of swallowing it', () {
    test('a refused scale write THROWS, and the state never moved', () async {
      final FlakyPreferences store = FlakyPreferences();
      final ProviderContainer container = containerOver(store);
      final ReaderPreferencesController controller = container.read(
        readerPreferencesControllerProvider,
      );
      await controller.selectScale(ReaderTextScale.lg);

      store.refuse = true;
      // **The `Future<bool>` shape is the trap this row exists for.** A boolean a caller
      // forgets to read is a preference that silently did not save, and the reader finds out
      // at the next launch.
      await expectLater(
        controller.selectScale(ReaderTextScale.sm),
        throwsA(isA<ThemePersistenceException>()),
      );

      expect(
        controller.scale,
        ReaderTextScale.lg,
        reason:
            'write-then-mutate is B24: a control that mutated first would display a setting '
            'it cannot keep',
      );
      expect(
        container.read(readerTextScaleProvider),
        ReaderTextScale.lg,
        reason: 'and the provider agrees with the seam — one state, not two',
      );
    });

    test('a refused THEME write leaves the override where it was', () async {
      final FlakyPreferences store = FlakyPreferences();
      final ProviderContainer container = containerOver(store);
      final ReaderPreferencesController controller = container.read(
        readerPreferencesControllerProvider,
      );
      await controller.selectOverride(ThemeOverride.night);

      store.refuse = true;
      await expectLater(
        controller.selectOverride(ThemeOverride.day),
        throwsA(isA<ThemePersistenceException>()),
      );
      expect(
        container.read(themeOverrideProvider),
        ThemeOverride.night,
        reason: 'a theme the app did not store must never be the one on screen',
      );
    });
  });
}
