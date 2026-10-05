// Lumen Tale — `theme-type` § 11.1, the preferences rows.
//
// The two properties worth stating before the rows:
//
//   **The default is the ABSENCE of a key.** Writing `system` on first run would
//   make "has the reader chosen anything?" unanswerable, so every row here asserts
//   that a *read* creates nothing.
//
//   **Write, THEN mutate.** The same order as B6, for the same reason (C8): a
//   control that shows a value it could not store is worse than one that snaps
//   back. These rows inject a refusing store and check the state never moved.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumen_tale/app/theme/app_theme_preferences.dart';
import 'package:lumen_tale/app/theme/reader_scale.dart';
import 'package:lumen_tale/app/theme/theme_override.dart';
import 'package:lumen_tale/app/theme/theme_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  Future<SharedPrefsThemePreferences> newStore() async =>
      SharedPrefsThemePreferences(await SharedPreferences.getInstance());

  group('default reads', () {
    test('an empty store reads system and md, and creates no key', () async {
      final store = await newStore();
      expect(store.readThemeOverride(), ThemeOverride.system);
      expect(store.readReaderScale(), ReaderTextScale.md);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getKeys(), isEmpty);
    });

    test(
      'a nominal write reads back, and stores the STRING not the ordinal',
      () async {
        final store = await newStore();
        await store.writeReaderScale(ReaderTextScale.xxl);

        final prefs = await SharedPreferences.getInstance();
        // B27: the string, because the enum's name is the contract with the file.
        // Writing `4` would bind the storage format to the enum's order.
        expect(
          prefs.getString(SharedPrefsThemePreferences.readerScaleKey),
          'xxl',
        );
        expect(
          prefs.getString(SharedPrefsThemePreferences.readerScaleKey),
          isNot('4'),
        );
        expect(store.readReaderScale(), ReaderTextScale.xxl);
      },
    );
  });

  group('invalid values fall back, and never throw', () {
    test('a scale key holding a theme value falls back to md', () async {
      final prefs = await SharedPreferences.getInstance();
      // A value written by a version whose scale enum had different members.
      await prefs.setString(
        SharedPrefsThemePreferences.readerScaleKey,
        'night',
      );

      final store = SharedPrefsThemePreferences(prefs);
      expect(store.readReaderScale(), ReaderTextScale.md);
    });

    test('a theme key holding "system" is the default, not an error', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        SharedPrefsThemePreferences.themeOverrideKey,
        'system',
      );
      final store = SharedPrefsThemePreferences(prefs);
      expect(store.readThemeOverride(), ThemeOverride.system);
    });

    test('every unrecognised value resolves, in both keys', () async {
      final prefs = await SharedPreferences.getInstance();
      for (final junk in <String>['largest', 'sombre', '', 'DARK']) {
        await prefs.setString(SharedPrefsThemePreferences.readerScaleKey, junk);
        await prefs.setString(
          SharedPrefsThemePreferences.themeOverrideKey,
          junk,
        );
        final store = SharedPrefsThemePreferences(prefs);
        expect(store.readReaderScale(), ReaderTextScale.md, reason: junk);
        expect(store.readThemeOverride(), ThemeOverride.system, reason: junk);
      }
    });
  });

  group('a refused write is visible', () {
    test('setString returning false throws and leaves the key unchanged', () async {
      final prefs = await SharedPreferences.getInstance();
      final store = SharedPrefsThemePreferences(prefs);
      await store.writeThemeOverride(ThemeOverride.day);

      // `shared_preferences`' mock always succeeds, so the refusal is injected
      // through the interface rather than by breaking the platform — which is the
      // point: the row tests the store's handling of `false`, not the plugin's.
      final refusing = _RefusingStore(written: ThemeOverride.day);
      await expectLater(
        refusing.writeThemeOverride(ThemeOverride.night),
        throwsA(isA<ThemePersistenceException>()),
      );
      expect(
        store.readThemeOverride(),
        ThemeOverride.day,
        reason: 'nothing was written, so the stored value is unchanged',
      );
    });
  });

  group('the notifiers: write THEN mutate', () {
    test('a successful select updates both the store and the state', () async {
      final store = await newStore();
      final container = ProviderContainer(
        overrides: [appThemePreferencesProvider.overrideWithValue(store)],
      );
      addTearDown(container.dispose);

      expect(container.read(themeOverrideProvider), ThemeOverride.system);

      await container
          .read(themeOverrideProvider.notifier)
          .select(ThemeOverride.night);
      expect(container.read(themeOverrideProvider), ThemeOverride.night);
      expect(store.readThemeOverride(), ThemeOverride.night);

      await container
          .read(readerTextScaleProvider.notifier)
          .select(ReaderTextScale.lg);
      expect(container.read(readerTextScaleProvider), ReaderTextScale.lg);
      expect(store.readReaderScale(), ReaderTextScale.lg);
    });

    test('a refused select throws AND leaves the state on the old value', () async {
      // § 5 and `design-system.md` § 2.9. Both halves matter: an exception with
      // the state already mutated would show a setting the app does not have, and
      // a silent state with no exception would hide the failure entirely.
      // ⚠️ Seeded through the STORE, not through a prior `select`. The refusing store
      // refuses every write, so a seeding `select` would throw here and the row
      // would be testing its own setup.
      final refusing = _RefusingStore(written: ThemeOverride.day);
      final container = ProviderContainer(
        overrides: [appThemePreferencesProvider.overrideWithValue(refusing)],
      );
      addTearDown(container.dispose);

      expect(
        container.read(themeOverrideProvider),
        ThemeOverride.day,
        reason: 'the notifier read the store on build',
      );

      await expectLater(
        container
            .read(themeOverrideProvider.notifier)
            .select(ThemeOverride.night),
        throwsA(isA<ThemePersistenceException>()),
      );
      expect(
        container.read(themeOverrideProvider),
        ThemeOverride.day,
        reason:
            'the write failed, so the state never moved — the Switch snaps '
            'back rather than showing "night" with nothing stored',
      );
    });

    test('the preference survives a container restart', () async {
      // `05-state-management.md` rule 10: an application preference outlives the
      // container that read it. `build()` re-reads the store rather than defaulting.
      final store = await newStore();
      await store.writeReaderScale(ReaderTextScale.xl);
      await store.writeThemeOverride(ThemeOverride.night);

      final first = ProviderContainer(
        overrides: [appThemePreferencesProvider.overrideWithValue(store)],
      );
      expect(first.read(readerTextScaleProvider), ReaderTextScale.xl);
      expect(first.read(themeOverrideProvider), ThemeOverride.night);
      first.dispose();

      final second = ProviderContainer(
        overrides: [appThemePreferencesProvider.overrideWithValue(store)],
      );
      addTearDown(second.dispose);
      expect(
        second.read(readerTextScaleProvider),
        ReaderTextScale.xl,
        reason: 'the value comes from the store, not from a previous container',
      );
      expect(second.read(themeOverrideProvider), ThemeOverride.night);
    });

    test('an un-overridden preferences provider is loud, not a silent default', () async {
      // A bootstrap that forgets the override must fail HERE, loudly, rather
      // than serve a default theme forever.
      //
      // ⚠️ How the body is forced was measured, not guessed, and the three
      // candidates behave differently:
      //   `read(provider)`         -> throws ProviderException (body runs)
      //   `read(provider.notifier)` -> returns the notifier, NO throw
      //   `listen(..., fireImmediately: true)` -> NO throw
      //
      // The first draft asserted on the notifier read and received
      // `<Closure: () => ThemeOverride>`, so the row failed for a reason that had
      // nothing to do with the product. Riverpod wraps the body error in a
      // `ProviderException`, so that — not a bare `UnimplementedError` — is what
      // actually crosses this boundary, and a bootstrap reading it sees the cause.
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Riverpod 3.4.3 wraps a provider body's error in a `ProviderException`,
      // which lives in `package:riverpod/src/common/stack_trace.dart` and is
      // marked `@publicInMisc` but is **not re-exported** by
      // `package:flutter_riverpod/flutter_riverpod.dart`. So the wrapper cannot
      // be named here, and the row asserts on the message plus the fact that it
      // throws at all — which is what a bootstrap actually experiences.
      for (final name in <String>['themeOverride', 'readerTextScale']) {
        Object? caught;
        try {
          switch (name) {
            case 'themeOverride':
              // ignore: avoid_print
              container.read(themeOverrideProvider);
            case 'readerTextScale':
              // ignore: avoid_print
              container.read(readerTextScaleProvider);
          }
        } on Object catch (e) {
          caught = e;
        }
        expect(caught, isNotNull, reason: '$name must fail loudly');
        expect(
          caught.toString(),
          contains('overridden at the bootstrap'),
          reason:
              '$name must name the missing override, so the bootstrap '
              'failure is diagnosable rather than mysterious',
        );
      }
    });
  });
}

/// A store whose platform refuses every write.
final class _RefusingStore implements AppThemePreferences {
  _RefusingStore({required this.written});

  final ThemeOverride written;

  @override
  ThemeOverride readThemeOverride() => written;

  @override
  ReaderTextScale readReaderScale() => ReaderTextScale.md;

  @override
  Future<void> writeThemeOverride(ThemeOverride value) async {
    throw ThemePersistenceException('themeOverride', value.name, null);
  }

  @override
  Future<void> writeReaderScale(ReaderTextScale value) async {
    throw ThemePersistenceException('readerScale', value.name, null);
  }
}
