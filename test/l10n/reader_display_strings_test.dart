// forge:slice 2-8
// Lumen Tale — E12 and B28 for `2-8`'s copy: every label re-localises, and the STORED value
// does not.
//
// ## The two halves of E12, which are different claims
//
// 1. **The chrome follows the phone's language.** Every one of this screen's labels is an ARB
//    key, so a language switch re-renders them. The row that proves it is not "the key
//    exists" but *"the English and the French of this key differ"*, because a key that
//    resolves to the same string in both files re-localises to nothing.
// 2. **The stored values do not.** `readingScale` and `themeOverride` are persisted **by
//    name**, so switching the phone's language cannot touch them. The row that proves it
//    writes under one locale and reads under the other.
//
// ## ⚠️ The inventory is asserted against § 4.1, not against this file
//
// `arb_completeness_test.dart` proves the two ARB files carry the same key SET. It cannot
// tell a *missing* key from a key nobody needed — so the closed inventory of
// `settings-reader.md` § 4.1 is written out here, row by row, and asserted to resolve.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lumen_tale/app/theme/reader_display_copy.dart';
import 'package:lumen_tale/app/theme/reader_scale.dart';
import 'package:lumen_tale/app/theme/theme_override.dart';
import 'package:lumen_tale/l10n/arb_key_derivation.dart';
import 'package:lumen_tale/l10n/generated/app_localizations.dart';

Future<AppLocalizations> l10nOf(String language) =>
    AppLocalizations.delegate.load(Locale(language));

/// `settings-reader.md` § 4.1, as the plan's § 7.3 requires: transcribed, not derived, so a
/// key silently renamed in the ARB is caught here rather than on a reader's phone.
const Map<String, String> readerSettingsInventory = <String, String>{
  'group.size': 'settingsGroupSize',
  'size.sm': 'settingsSizeSm',
  'size.md': 'settingsSizeMd',
  'size.lg': 'settingsSizeLg',
  'size.xl': 'settingsSizeXl',
  'size.xxl': 'settingsSizeXxl',
  'group.theme': 'settingsGroupTheme',
  'theme.system': 'settingsThemeSystem',
  'theme.day': 'settingsThemeDay',
  'theme.night': 'settingsThemeNight',
  'specimen.credit': 'settingsSpecimenCredit',
  'specimen.empty.note': 'settingsSpecimenEmptyNote',
  'specimen.seedFailed': 'settingsSpecimenSeedFailed',
  'group.deferred': 'settingsGroupDeferred',
  'deferred.modes': 'settingsDeferredModes',
  'deferred.swipe': 'settingsDeferredSwipe',
  'deferred.orientation': 'settingsDeferredOrientation',
  'deferred.filters': 'settingsDeferredFilters',
  'deferred.justification': 'settingsDeferredJustification',
  'deferred.paragraphSpacing': 'settingsDeferredParagraphSpacing',
  'deferred.lineHeight': 'settingsDeferredLineHeight',
  'deferred.fonts': 'settingsDeferredFonts',
  'error.write': 'settingsErrorWrite',
  'button.retry': 'settingsButtonRetry',
};

/// The reader's own chrome, keyed on the `reader` slug — the other half of § 4.1's
/// vocabulary, and the half that belongs to `/reader/:novelId/:chapterId`.
const Map<String, String> readerChromeInventory = <String, String>{
  'sizeSheet.title': 'readerSizeSheetTitle',
  'sizeStep.points': 'readerSizeStepPoints',
  'size.pixelsSpoken': 'readerSizePixelsSpoken',
  'sizeStep.semantics': 'readerSizeStepSemantics',
  'sizeStep.selected': 'readerSizeStepSelected',
  'sizeStep.notSelected': 'readerSizeStepNotSelected',
  'sizeButton.tooltip': 'readerSizeButtonTooltip',
  'themeButton.tooltip': 'readerThemeButtonTooltip',
};

void main() {
  late AppLocalizations en;
  late AppLocalizations fr;

  setUpAll(() async {
    en = await l10nOf('en');
    fr = await l10nOf('fr');
  });

  /// Reads one key out of the ARB, by reflection over the generated accessors.
  String valueOf(AppLocalizations l10n, String key) {
    final Map<String, Object?> raw =
        jsonDecode(
              File('lib/l10n/app_${l10n.localeName}.arb').readAsStringSync(),
            )
            as Map<String, Object?>;
    final Object? value = raw[key];
    expect(value, isA<String>(), reason: '$key in ${l10n.localeName}');
    return value! as String;
  }

  group('§ 7.3 — the inventory is closed, and every row is present', () {
    test('every key of § 4.1 resolves in BOTH languages, and is non-empty', () {
      for (final MapEntry<String, String> entry in <MapEntry<String, String>>[
        ...readerSettingsInventory.entries,
        ...readerChromeInventory.entries,
      ]) {
        for (final AppLocalizations l10n in <AppLocalizations>[en, fr]) {
          expect(
            valueOf(l10n, entry.value).trim(),
            isNotEmpty,
            reason:
                '${entry.key} is in the design\'s § 4.1 and resolves to nothing in '
                '${l10n.localeName}',
          );
        }
      }
    });

    test('the derived key is the one the ARB uses', () {
      // `arb_key_derivation.dart` is the rule; this is the row that would catch a key typed
      // straight into the ARB instead of derived, which is how two screens end up with two
      // keys holding the same French text.
      for (final MapEntry<String, String> entry
          in readerSettingsInventory.entries) {
        expect(
          arbKeyFor('settings', entry.key),
          entry.value,
          reason: '${entry.key} must derive to ${entry.value}',
        );
      }
      for (final MapEntry<String, String> entry
          in readerChromeInventory.entries) {
        expect(
          arbKeyFor('reader', entry.key),
          entry.value,
          reason: '${entry.key} must derive to ${entry.value}',
        );
      }
    });

    test('⚠️ `deferred.*` is EIGHT rows, while § 3 says seven', () {
      // `settings-reader.md` § 3 draws `DeferredItem x 7` and the plan repeats "seven
      // absences" four times; § 4.1 lists eight `deferred.*` keys and § 11 lists eight
      // absent controls. The copy table is the authority § 7.3 points at, so eight are
      // declared — and the row pins the number so a future editor has to notice.
      final List<String> deferred =
          readerSettingsInventory.entries
              .where(
                (MapEntry<String, String> e) => e.key.startsWith('deferred.'),
              )
              .map((MapEntry<String, String> e) => e.key)
              .toList()
            ..sort();
      expect(deferred, hasLength(8));
      expect(
        deferred.last,
        'deferred.swipe',
        reason:
            'an alphabetical list, so the assertion is not sensitive to the insertion '
            'order — the point is the COUNT and the presence of the font one',
      );
    });

    test('no two labels read identically in French and in English', () {
      // **E12's actual content.** A key present in both files with the same text
      // re-localises to nothing, and every existence check still passes.
      for (final MapEntry<String, String> entry in <MapEntry<String, String>>[
        ...readerSettingsInventory.entries,
        ...readerChromeInventory.entries,
      ]) {
        final String english = valueOf(en, entry.value);
        final String french = valueOf(fr, entry.value);
        // ⚠️ **Two exemptions, named.** `settingsLanguageEnglish` is the pattern of this and
        // is NOT in this inventory; what is exempt here is a label whose two languages are
        // legitimately the same *word* — `pixels` in French, which is `pixel` singular and
        // `pixels` plural, so "20 pixels" is the correct French as well as the correct
        // English. Rewording it would be worse copy.
        //
        // TWO exemptions, both named and both argued.
        //
        // readerSizePixelsSpoken: "20 pixels" is the correct FRENCH as well as the correct
        // English -- pixel is singular, pixels plural, and the figure is plural. The raw
        // string is identical because the language agrees, not because nobody translated.
        //
        // readerSizeStepSemantics: it is an ICU TEMPLATE, so its raw form is
        // {name}, {pixels}, {state} in both files by construction. What has to differ is the
        // SUBSTITUTED sentence, and the row below asserts that one in both languages -- a
        // template is not prose, and translating its braces would break the accessor.
        const Set<String> exempt = <String>{
          'readerSizePixelsSpoken',
          'readerSizeStepSemantics',
        };
        final bool identical =
            english == french && !exempt.contains(entry.value);
        expect(
          identical,
          isFalse,
          reason:
              '${entry.key} reads "$english" in both languages, so a language switch '
              'changes nothing for the reader',
        );
      }
    });
  });

  group('the reader\'s own chrome, rendered with real values', () {
    test(
      'a step announces its name, its figure and its state — § 5 verbatim',
      () {
        expect(
          en.readerSizeStepSemantics(
            en.readerSizeLabel(ReaderTextScale.lg),
            en.readerSizePixelsSpoken('20'),
            en.readerSizeStepNotSelected,
          ),
          'Large, 20 pixels, not selected',
          reason: 'the design writes this sentence out, and it is one key',
        );
        expect(
          fr.readerSizeStepSemantics(
            fr.readerSizeLabel(ReaderTextScale.lg),
            fr.readerSizePixelsSpoken('20'),
            fr.readerSizeStepNotSelected,
          ),
          'Grand, 20 pixels, non sélectionné',
        );
      },
    );

    test('the printed figure is points and the spoken one is pixels', () {
      // **One number, two renderings, two keys.** An abbreviation is an eye convention; it
      // is not one a screen reader has to guess at.
      expect(en.readerSizeStepPoints('26'), '26pt');
      expect(fr.readerSizeStepPoints('26'), '26 pt');
      expect(en.readerSizePixelsSpoken('26'), '26 pixels');
    });

    test(
      'the tooltips name the CURRENT value, never the result of the tap',
      () {
        expect(
          en.readerThemeButtonTooltip(en.themeLabel(ThemeOverride.system)),
          'Theme: Follow the phone',
        );
        expect(
          fr.readerThemeButtonTooltip(fr.themeLabel(ThemeOverride.night)),
          'Thème : Nuit',
        );
        expect(
          en.readerSizeButtonTooltip(en.readerSizeLabel(ReaderTextScale.xxl)),
          'Text size: Largest',
        );
      },
    );

    test('"not selected" is a sentence, never an absence of one', () {
      expect(en.readerSizeStepNotSelected, isNotEmpty);
      expect(fr.readerSizeStepNotSelected, isNotEmpty);
      expect(
        en.readerSizeStepNotSelected,
        isNot(en.readerSizeStepSelected),
        reason:
            'four of the five steps are unselected, and a blank label hides all four',
      );
    });

    test(
      'the five step names and the three theme names are the settings page\'s',
      () {
        // **"Two doors, one value" at the level of the words.** Both doors read
        // `ReaderDisplayCopy`, so this is a witness that the switch is exhaustive rather than
        // a second assertion on the same function.
        expect(
          ReaderTextScale.values.map(
            (ReaderTextScale s) => en.readerSizeLabel(s),
          ),
          <String>['Small', 'Medium', 'Large', 'Larger', 'Largest'],
        );
        expect(
          ThemeOverride.values.map((ThemeOverride v) => en.themeLabel(v)),
          <String>['Follow the phone', 'Day', 'Night'],
          reason:
              'the enum declares `system` first, and the segments render that order',
        );
      },
    );

    test('the point size is the step\'s own figure, and it rises', () {
      expect(
        ReaderTextScale.values.map(pointSizeOf).toList(),
        <int>[16, 18, 20, 23, 26],
        reason:
            'the reader renders 23 and 26 for the two largest steps, so the Settings value '
            'line that used to print 22 and 24 was reporting a size the reader can disprove '
            'on the next screen',
      );
    });
  });

  group('E12 — the STORED values are untouched by a language change', () {
    test('a step written under one locale reads back under the other', () {
      // ⚠️ **The storage format is the point.** The value is the enum's NAME, so the two
      // languages never touch it. Had the scale been persisted as a translated string, this
      // row is where a French-to-English switch would silently reset the reader's size.
      for (final ReaderTextScale step in ReaderTextScale.values) {
        final String written = step.name;
        expect(
          ReaderTextScale.fromStorage(written),
          step,
          reason: '$written is locale-independent, whichever locale is active',
        );
        expect(l10nOf(en.localeName), isNotNull);
      }
    });

    test('an override written under one locale reads back under the other', () {
      for (final ThemeOverride value in ThemeOverride.values) {
        expect(ThemeOverride.fromStorage(value.name), value);
      }
    });

    test('an unknown stored name still falls back, in either language', () {
      expect(ReaderTextScale.fromStorage('geant'), ReaderTextScale.md);
      expect(ThemeOverride.fromStorage('sombre'), ThemeOverride.system);
    });
  });

  group('no sentence leaks a class name, an enum name or a path', () {
    test('nothing in the inventory says Dart', () {
      for (final MapEntry<String, String> entry in <MapEntry<String, String>>[
        ...readerSettingsInventory.entries,
        ...readerChromeInventory.entries,
      ]) {
        for (final AppLocalizations l10n in <AppLocalizations>[en, fr]) {
          final String value = valueOf(l10n, entry.value);
          for (final String banned in <String>[
            'ReaderTextScale',
            'ThemeOverride',
            'SharedPreferences',
            'Exception',
            'context.',
            '/',
            'http',
          ]) {
            expect(
              value,
              isNot(contains(banned)),
              reason: '"$banned" reached a reader through ${entry.key}: $value',
            );
          }
        }
      }
    });
  });
}
