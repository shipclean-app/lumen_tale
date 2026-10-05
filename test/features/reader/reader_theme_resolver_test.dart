// forge:slice 2-8
// Lumen Tale — `2-8` § 11.1: B26's cycle, and the one translation the project is allowed.
//
// ## Why there is no `resolveThemeMode` row
//
// The plan's § 2.2 prints one, and § 2.2's own table says `ThemeOverride` provides
// `resolve(Brightness)` and is *"the only place in the project that translates the override
// into a ThemeMode"*. A row here that re-derived the translation would be testing a second
// copy of a value that already has an owner — so the rows below go THROUGH `resolve`, which
// is what makes this file a check on the cycle and not a competing definition of it.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lumen_tale/app/theme/theme_override.dart';
import 'package:lumen_tale/features/reader/domain/reader_theme_resolver.dart';

void main() {
  group('the cycle is day, night, system — and it is a ring', () {
    test('from `system` the three taps are day, night, system', () {
      expect(cycleThemeOverride(ThemeOverride.system), ThemeOverride.day);
      expect(cycleThemeOverride(ThemeOverride.day), ThemeOverride.night);
      expect(cycleThemeOverride(ThemeOverride.night), ThemeOverride.system);
    });

    test('after three taps of any start, the value is the same one', () {
      // **The closed-ring property**, and the row that would catch a `switch` whose last arm
      // returned the input: a reader three taps in would find nothing had happened.
      for (final ThemeOverride start in ThemeOverride.values) {
        ThemeOverride value = start;
        for (int tap = 0; tap < 3; tap++) {
          value = cycleThemeOverride(value);
        }
        expect(
          value,
          start,
          reason: 'three taps of the themeButton must return to ${start.name}',
        );
      }
    });

    test('one tap is never a no-op — every value has a successor', () {
      for (final ThemeOverride value in ThemeOverride.values) {
        expect(
          cycleThemeOverride(value),
          isNot(value),
          reason:
              '${value.name} cycles to itself: tapping the button would appear to do '
              'nothing at all',
        );
      }
    });
  });

  group('the segment order is the design\'s, and holds the same three members', () {
    test('follow the phone, then day, then night', () {
      expect(themeOverrideOrder, <ThemeOverride>[
        ThemeOverride.system,
        ThemeOverride.day,
        ThemeOverride.night,
      ]);
    });

    test('it is the enum, so a fourth override cannot be forgotten', () {
      expect(
        themeOverrideOrder.toSet(),
        ThemeOverride.values.toSet(),
        reason:
            'a segment control missing a value would offer the reader a choice the app '
            'cannot store',
      );
    });

    test('⚠️ the segment order and the cycle order DIFFER, on purpose', () {
      // **Two questions, two orders.** The cycle is what one tap does; the segments are
      // what the settings page draws left to right. They are not required to agree, and a
      // row that demanded they did would be asking for one of them to be wrong.
      expect(themeOverrideOrder.first, ThemeOverride.system);
      expect(cycleThemeOverride(ThemeOverride.system), ThemeOverride.day);
    });
  });

  group('B26 — the cycle maps to the ThemeMode the root will be given', () {
    test(
      'each value resolves as B26 claims, on a phone that says the opposite',
      () {
        expect(ThemeOverride.day.resolve(Brightness.dark), ThemeMode.light);
        expect(ThemeOverride.night.resolve(Brightness.light), ThemeMode.dark);
      },
    );

    test('`system` follows the platform on BOTH sides', () {
      expect(ThemeOverride.system.resolve(Brightness.dark), ThemeMode.dark);
      expect(ThemeOverride.system.resolve(Brightness.light), ThemeMode.light);
    });

    test(
      'walking the cycle from `system` visits every resolved night exactly once',
      () {
        // **The round trip and the values in one row**, because the acceptance criterion is
        // about both: "the themeButton cycles day, night, system, day, in that order, and the
        // settings page shows the same checked value".
        ThemeOverride value = ThemeOverride.system;
        final List<ThemeOverride> visited = <ThemeOverride>[value];
        for (int tap = 0; tap < 3; tap++) {
          value = cycleThemeOverride(value);
          visited.add(value);
        }
        expect(visited.toSet(), ThemeOverride.values.toSet());
        expect(
          visited.map((ThemeOverride v) => v.resolve(Brightness.dark)),
          <ThemeMode>[
            ThemeMode.dark,
            ThemeMode.light,
            ThemeMode.dark,
            ThemeMode.dark,
          ],
          reason:
              'from `system` on a night phone: dark, then day, then night, then back to the '
              'platform — which is the cycle the reader feels',
        );
      },
    );
  });
}
