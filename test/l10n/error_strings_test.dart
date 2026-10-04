// forge:slice 6-7
// Lumen Tale — `6-7` § 11.1: every `AppErrorString` arm has a sentence, in both languages.
//
// ## What this file owns, and what it deliberately does not repeat
//
// `test/core/ui/app_error_copy_test.dart` (also `6-7`) tests the **library**: that `message()`
// is total, that the action matches the cause, that no sentence leaks a class name, that the
// rate-limit duration is read and not guessed. Those rows are the right home for them and
// they stay there.
//
// What is left — and what is *this* slice's own criterion, § 10.5 — is the sentence rule over
// the enum: **every arm carries words, not a label, and each language carries its own.** That
// is a statement about the ARB **through** the enum, so it belongs on the enum's side of the
// line, and it is a different assertion from "not empty": `Downloaded` is not empty and is not
// a sentence either.
//
// ## ⚠️ Why four arms are exempt, and why that is not a widened rule
//
// § 10.5 asks that "each contains at least two clauses". Taken literally that fails four arms,
// and the four are exactly the ones § 3.2 itself specifies as **labels or as nothing at all**:
// `Queued`, `Downloading`, `Downloaded`, and — for `browseSucceeded` — the note *« a result has
// no message »*. A rule that cannot be applied to the values the plan itself specifies is not
// the rule the plan meant, so the sentence threshold is applied to the arms the plan specifies
// as sentences and the four labels are declared, each with its reason, in
// `expected_keys.dart`. The row below asserts that reason is non-empty, so an exemption cannot
// be added without stating why — and it asserts the two lists are **disjoint and together
// exhaustive**, so an arm cannot fall out of both and stop being checked at all.

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumen_tale/core/ui/app_error_copy.dart';
import 'package:lumen_tale/l10n/generated/app_localizations.dart';

import 'expected_keys.dart';

/// The same threshold `translation_completeness_test.dart` applies on the ARB side.
///
/// ⚠️ **One constant, two files, deliberately not shared through a library.** A test that
/// imports its threshold can be edited by whoever next touches the library, and the two rows
/// would then disagree about the same product. They are stated in both files instead: the cost
/// is a number appearing twice, and the benefit is that changing either threshold is a visible
/// two-file change rather than one edit that silently moves two gates.
const int minimumSentenceWords = 4;

Future<AppLocalizations> l10nOf(Locale locale) =>
    AppLocalizations.delegate.load(locale);

/// The ARB key each status arm resolves to, so `statusLabelKeys` can be checked against the
/// enum rather than against a list of strings that might have drifted from it.
const Map<AppErrorString, String> statusArmToArbKey = <AppErrorString, String>{
  AppErrorString.browseSucceeded: 'browseSucceeded',
  AppErrorString.downloadQueued: 'downloadQueued',
  AppErrorString.downloadDownloading: 'downloadDownloading',
  AppErrorString.downloadDone: 'downloadDone',
  AppErrorString.checkCancelled: 'checkCancelled',
};

/// Every arm is a sentence **or** a declared label — never neither.
const Set<AppErrorString> sentenceArms = <AppErrorString>{
  AppErrorString.noConnection,
  AppErrorString.rateLimited,
  AppErrorString.sourceLayoutChanged,
  AppErrorString.sourceUnavailable,
  AppErrorString.itemRemovedAtSource,
  AppErrorString.storageFull,
  AppErrorString.parseFailed,
  AppErrorString.causeUnknown,
  AppErrorString.databaseUnavailable,
  AppErrorString.chapterNotAvailable,
  AppErrorString.settingsWriteFailed,
  AppErrorString.settingsLoadFailed,
  AppErrorString.browseEmpty,
  AppErrorString.browseFailed,
  AppErrorString.downloadFailed,
  AppErrorString.historyClearFailed,
  AppErrorString.historyCountUnavailable,
  AppErrorString.notificationPermissionDenied,
};

void main() {
  late AppLocalizations en;
  late AppLocalizations fr;

  setUpAll(() async {
    en = await l10nOf(const Locale('en'));
    fr = await l10nOf(const Locale('fr'));
  });

  group('the arms are classified, and the classification is complete', () {
    test('every arm is a sentence or a declared label, and never both', () {
      // The check that keeps the exemption list honest: an arm added without a sentence
      // and without a reason would stop being examined by the rows below.
      final Set<AppErrorString> unclassified = AppErrorString.values
          .toSet()
          .difference(<AppErrorString>{
            ...sentenceArms,
            ...statusArmToArbKey.keys,
          });
      expect(
        unclassified,
        isEmpty,
        reason:
            'AppErrorString gained ${unclassified.map((a) => a.name).toList()} and '
            'nothing says whether it is a sentence or a label. § 10.5 asks about '
            'every arm, so an unclassified arm is an unchecked arm.',
      );
      expect(
        sentenceArms.intersection(statusArmToArbKey.keys.toSet()),
        isEmpty,
        reason: 'an arm cannot be a sentence and a label at once',
      );
      expect(
        AppErrorString.values.length,
        sentenceArms.length + statusArmToArbKey.length,
        reason:
            'witness — the enum is fully partitioned, and its size is a fact',
      );
    });

    test('every declared status label states why it is one', () {
      for (final String key in statusArmToArbKey.values) {
        expect(
          statusLabelKeys[key],
          isNotNull,
          reason:
              '$key is an exempt arm, so it needs a reason in expected_keys.dart',
        );
        expect(
          statusLabelKeys[key]!.trim(),
          isNotEmpty,
          reason: '$key is exempt from the sentence rule and states no reason',
        );
      }
      // And the map is keyed by the enum, so an arm renamed cannot keep the exemption.
      expect(
        statusArmToArbKey.values.toSet(),
        statusLabelKeys.keys.toSet(),
        reason:
            'the enum view and the ARB view of the four labels are the same four, or '
            'one of them is describing arms that no longer exist',
      );
    });
  });

  group('every failure arm is a sentence a reader can describe out loud', () {
    test('each sentence clears four words, in English and in French', () {
      // § 10.5 and C12. The word count is measured on the RENDERED sentence, so a
      // placeholder's value counts as the one word it is — `{source}` is a name, not
      // three words, and a sentence padded with names would not become more sayable.
      for (final AppErrorString arm in sentenceArms) {
        for (final AppLocalizations l10n in <AppLocalizations>[en, fr]) {
          expect(
            _wordsIn(l10n.message(arm)),
            greaterThanOrEqualTo(minimumSentenceWords),
            reason:
                '${arm.name} renders "${l10n.message(arm)}" in ${l10n.localeName} — '
                'C12 asks for a failure state a reader can DESCRIBE, and a label that '
                'short is not describable',
          );
        }
      }
    });

    test('a sentence is never one word — the threshold has teeth', () {
      // Witness for the row above, whose loop could pass by finding nothing.
      expect(_wordsIn('Erreur.'), lessThan(minimumSentenceWords));
      expect(_wordsIn('Failed.'), lessThan(minimumSentenceWords));
      expect(
        _wordsIn('No connection. Your downloaded chapters stay readable.'),
        greaterThanOrEqualTo(minimumSentenceWords),
      );
    });

    test(
      'a declared label still exists, and still differs from its siblings',
      () {
        // An exempt arm is not an unchecked arm: it must render, and four labels that all
        // said "Done" would pass the exemption and tell a reader nothing.
        for (final AppErrorString arm in statusArmToArbKey.keys) {
          expect(
            en.message(arm).trim(),
            isNotEmpty,
            reason: '${arm.name} is a label and renders nothing',
          );
          expect(
            fr.message(arm).trim(),
            isNotEmpty,
            reason: '${arm.name} has no French rendering',
          );
        }
        for (final AppErrorString a in statusArmToArbKey.keys) {
          for (final AppErrorString b in statusArmToArbKey.keys) {
            if (a == b) continue;
            expect(
              en.message(a),
              isNot(en.message(b)),
              reason: '${a.name} and ${b.name} render the same English string',
            );
          }
        }
      },
    );
  });

  group('the two languages say different things — E12', () {
    test('every arm renders a different sentence in French than in English', () {
      // E12 and § 11.1's row. If `fr` resolved to the English bundle — a broken delegate,
      // a wrong `@@locale` — every "not empty" row above would still pass. This is the
      // row that notices, and it is why it is written over ALL arms rather than a sample.
      final List<String> identical = <String>[
        for (final AppErrorString arm in AppErrorString.values)
          if (en.message(arm) == fr.message(arm)) arm.name,
      ];
      expect(
        identical,
        isEmpty,
        reason:
            'B28 — these arms render identically in both locales, so one of the two '
            'bundles is not being used: $identical',
      );
    });

    test('the two locales really are two locales', () {
      // Witness for the row above: without it, a delegate that ignored the locale and
      // returned English twice would make the row above pass for the wrong reason.
      expect(en.localeName, 'en');
      expect(fr.localeName, 'fr');
      expect(en.navLibrary, isNot(fr.navLibrary));
    });
  });
}

/// Words in a rendered sentence, counting each interpolated value as the one name it is.
int _wordsIn(String sentence) =>
    RegExp(r'[\p{L}\p{N}]+', unicode: true).allMatches(sentence).length;
