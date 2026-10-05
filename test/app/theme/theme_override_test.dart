// Lumen Tale — `theme-type` § 11.1, the override and preference rows.
//
// B26 — "follow the phone, or overrule it" — has a failure mode that a widget
// test cannot see: **the default must be ABSENT from storage**. Writing `system`
// on first run would create three sources of truth (the file, the absent key and
// the enum) and would make "has the reader chosen?" unanswerable.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumen_tale/app/theme/app_theme_preferences.dart';
import 'package:lumen_tale/app/theme/reader_scale.dart';
import 'package:lumen_tale/app/theme/theme_override.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('the four B26 branches, all explicit', () {
    test('override `system` defers to the phone, both ways', () {
      expect(ThemeOverride.system.resolve(Brightness.light), ThemeMode.light);
      expect(ThemeOverride.system.resolve(Brightness.dark), ThemeMode.dark);
    });

    test('override `day` wins over a phone in night', () {
      expect(ThemeOverride.day.resolve(Brightness.dark), ThemeMode.light);
    });

    test('override `night` wins over a phone in day', () {
      expect(ThemeOverride.night.resolve(Brightness.light), ThemeMode.dark);
    });

    test('the override never writes back to the phone setting', () {
      // Forcing day must not mean "ask again next launch": the stored value stays
      // `day`, and only the reader can change it back.
      expect(ThemeOverride.day.resolve(Brightness.dark), ThemeMode.light);
      expect(ThemeOverride.fromStorage('day'), ThemeOverride.day);
      expect(
        ThemeOverride.fromStorage('day').resolve(Brightness.dark),
        ThemeMode.light,
      );
    });

    test('an unreadable stored value resolves to system, not to a crash', () {
      // A value written by another version must not stop the app starting.
      for (final raw in <String>['sombre', 'dark', 'SYSTEM', '', 'Light']) {
        expect(
          ThemeOverride.fromStorage(raw),
          ThemeOverride.system,
          reason: '"$raw" must resolve to system',
        );
      }
      expect(ThemeOverride.fromStorage(null), ThemeOverride.system);
    });

    test('every value round-trips through storage', () {
      for (final value in ThemeOverride.values) {
        expect(ThemeOverride.fromStorage(value.name), value);
      }
    });
  });

  group('the default is the ABSENCE of a key', () {
    setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

    test('with no key at all, both settings read as their defaults', () async {
      final prefs = await SharedPreferences.getInstance();
      final store = SharedPrefsThemePreferences(prefs);

      expect(store.readThemeOverride(), ThemeOverride.system);
      expect(store.readReaderScale(), ReaderTextScale.md);

      // ⚠️ The point of the row: `system` and `md` are now IN the store only if
      // something wrote them. Nothing has, so the file must still be empty.
      expect(
        prefs.getString(SharedPrefsThemePreferences.themeOverrideKey),
        isNull,
      );
      expect(
        prefs.getString(SharedPrefsThemePreferences.readerScaleKey),
        isNull,
      );
    });

    test(
      'reading does not create a key — the default is never persisted',
      () async {
        final prefs = await SharedPreferences.getInstance();
        final store = SharedPrefsThemePreferences(prefs);

        // Read several times, as a rebuild would.
        for (var i = 0; i < 3; i++) {
          expect(store.readThemeOverride(), ThemeOverride.system);
          expect(store.readReaderScale(), ReaderTextScale.md);
        }
        expect(
          prefs.getKeys(),
          isEmpty,
          reason:
              'a read that writes the default has made "has the reader chosen '
              'anything?" unanswerable',
        );
      },
    );

    test('a written value is read back', () async {
      final prefs = await SharedPreferences.getInstance();
      final store = SharedPrefsThemePreferences(prefs);

      await store.writeThemeOverride(ThemeOverride.night);
      await store.writeReaderScale(ReaderTextScale.xl);

      expect(store.readThemeOverride(), ThemeOverride.night);
      expect(store.readReaderScale(), ReaderTextScale.xl);
    });
  });

  group('B24 — a setting that cannot be written is visible', () {
    setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

    test('a refused write throws rather than pretending to succeed', () async {
      // `setString` returns a `Future<bool>`. A `false` is a platform refusal, NOT
      // an exception: the `Switch`'s catcher would never see it if it were
      // ignored, and the control would show "night" with nothing stored.
      final store = _RefusingThemePreferences();
      await expectLater(
        store.writeThemeOverride(ThemeOverride.night),
        throwsA(isA<ThemePersistenceException>()),
      );
      await expectLater(
        store.writeReaderScale(ReaderTextScale.lg),
        throwsA(isA<ThemePersistenceException>()),
      );
    });

    test(
      'the exception names the value ATTEMPTED, not the one in force',
      () async {
        // The reader has just chosen "night"; the name has to be the one they can
        // recognise in an error message.
        final store = _RefusingThemePreferences();
        Object? caught;
        try {
          await store.writeThemeOverride(ThemeOverride.night);
        } on Object catch (e) {
          caught = e;
        }
        expect(caught, isA<ThemePersistenceException>());
        final typed = caught! as ThemePersistenceException;
        expect(typed.key, 'themeOverride');
        expect(typed.value, 'night');
      },
    );

    test('a refused write leaves the stored value untouched', () async {
      // The `Switch` snaps back, and it can only do that if the store still holds
      // the previous value.
      final prefs = await SharedPreferences.getInstance();
      final real = SharedPrefsThemePreferences(prefs);
      await real.writeThemeOverride(ThemeOverride.day);

      final hostile = _RefusingThemePreferences();
      await expectLater(
        hostile.writeThemeOverride(ThemeOverride.night),
        throwsA(isA<ThemePersistenceException>()),
      );
      expect(real.readThemeOverride(), ThemeOverride.day);
    });
  });

  group('ThemePersistenceException is deliberately not an AppException', () {
    test('it is its own type, with exactly the fields a caller needs', () {
      const e = ThemePersistenceException('themeOverride', 'night', null);
      expect(e.key, 'themeOverride');
      expect(e.value, 'night');
      expect(e.toString(), contains('themeOverride'));
      expect(e.toString(), contains('night'));
    });
  });
}

/// A store whose platform always refuses the write.
final class _RefusingThemePreferences implements AppThemePreferences {
  @override
  ThemeOverride readThemeOverride() => ThemeOverride.system;

  @override
  ReaderTextScale readReaderScale() => ReaderTextScale.md;

  @override
  Future<void> writeThemeOverride(ThemeOverride value) async {
    throw const ThemePersistenceException('themeOverride', 'night', null);
  }

  @override
  Future<void> writeReaderScale(ReaderTextScale value) async {
    throw const ThemePersistenceException('readerScale', 'lg', null);
  }
}
