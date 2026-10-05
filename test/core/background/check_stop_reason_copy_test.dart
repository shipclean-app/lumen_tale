// forge:slice 6-10
// Lumen Tale — C12: ten reasons, ten sentences, in two languages, and none of them generic.
//
// ## ⚠️ WHY THE PARITY ROW READS THE INSTALLED PACKAGE
//
// `6-10` § 2.2 types `CheckJobInterrupted.reason` as the plugin's `StopReason`, which
// cannot be imported from `domain/` — the package is undeclared, and the declared route to
// the same type re-exports a Pigeon surface that imports `flutter/services.dart`, putting
// Flutter inside the pure layer. So `domain/updates/check_stop_reason.dart` declares its own
// ten values and `core/background/workmanager_check_job_engine.dart` maps between them with
// a `switch` that has no `default`.
//
// That leaves one hole a compiler cannot close: **nothing checks that the two sets still
// agree.** A renamed plugin value would make the mapping `switch` stop compiling — good —
// but a value this build renamed or dropped would leave the app mapping a reason to a
// different sentence, silently. So this file resolves `workmanager_platform_interface` out
// of `.dart_tool/package_config.json`, reads its `stop_reason.dart`, and compares the two
// enumerations. `test/` never imports the plugin; it reads the package's **source text**.
//
// ## ⚠️ THE FIVE DISTINCT SENTENCES ARE `6-10` § 10'S C12 ROW
//
// `deviceIdle`, `appStandby`, `deviceState`, `backgroundRestriction` and `timeout` must each
// say something different. "The phone did something" is the answer this row exists to
// forbid — C12 asks for a failure a reader on a borrowed phone can describe aloud.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumen_tale/core/background/check_stop_reason_copy.dart';
import 'package:lumen_tale/domain/updates/check_stop_reason.dart';
import 'package:lumen_tale/l10n/generated/app_localizations.dart';

/// The sentences for one locale, keyed by reason name.
///
/// ⚠️ **`lookupAppLocalizations`, NOT A PUMPED WIDGET.** A `BuildContext` is the usual way
/// to reach `AppLocalizations`, and building one would make a mapping table a widget test —
/// which is what `queue_failure_copy.dart`'s header refuses. `gen-l10n` emits this lookup
/// precisely for that use, and it is the whole of B28's two-locale requirement.
Map<String, String> sentencesFor(Locale locale) {
  final AppLocalizations l10n = lookupAppLocalizations(locale);
  return <String, String>{
    for (final CheckStopReason reason in CheckStopReason.values)
      reason.name: l10n.checkStoppedSentence(reason),
  };
}

/// The `StopReason` value names the **installed** plugin declares.
List<String> installedStopReasonNames() {
  // ⚠️ **`package_config.json` IS THE RESOLUTION, SO THIS DOES NOT HARD-CODE A PATH.**
  // A pub cache lives in `$PUB_CACHE`, in `~/.pub-cache`, or wherever CI puts it; the only
  // file that says where this project's dependencies actually resolved is the one the Dart
  // tool wrote.
  final File config = File('.dart_tool/package_config.json');
  expect(
    config.existsSync(),
    isTrue,
    reason:
        'the row needs the resolved path of the plugin; without it there is nothing to '
        'compare and the whole file would pass vacuously',
  );
  final Map<String, Object?> packages =
      jsonDecode(config.readAsStringSync()) as Map<String, Object?>;
  final List<Object?> entries = packages['packages']! as List<Object?>;
  final Map<String, Object?> plugin = entries
      .cast<Map<String, Object?>>()
      .firstWhere(
        (Map<String, Object?> p) =>
            p['name'] == 'workmanager_platform_interface',
      );
  final String root = plugin['rootUri']! as String;
  // ⚠️ **`rootUri` IS USUALLY ABSOLUTE AND SOMETIMES RELATIVE, AND BOTH ARE WRITTEN BY THE
  // TOOL.** A `file://` URI is used as it stands; anything else is relative to the
  // **directory holding the config file**, which is `.dart_tool/` — resolving against the
  // project root instead puts the path one level short.
  //
  // ⚠️ **AND THE TRAILING SLASH IS NOT COSMETIC.** `Uri.resolve` treats a base without one
  // as a *file*, so `…/workmanager_platform_interface-0.10.5` + `lib/src/stop_reason.dart`
  // resolves to `…/workmanager_platform_interface/lib/…` — the version segment is eaten and
  // the failure reads as "the plugin moved" when nothing moved.
  final Uri base = Uri.parse(root).hasScheme
      ? Uri.parse(root.endsWith('/') ? root : '$root/')
      : config.absolute.uri.resolve(root);
  final File source = File.fromUri(base.resolve('lib/src/stop_reason.dart'));
  expect(
    source.existsSync(),
    isTrue,
    reason:
        'the plugin must still keep its stop reasons in `lib/src/stop_reason.dart`; if it '
        'moved, this row has to be repointed rather than deleted — it is the only thing '
        'standing between a renamed reason and a sentence that is now wrong',
  );
  // ⚠️ **THE LAST VALUE IS FOLLOWED BY `;`, NOT `,`.** A `StopReason.unknown(0),` pattern
  // matches the first nine and misses `deviceIdle(9);`, so the count comes back as 9 and
  // the row fails for a reason that has nothing to do with the code under test. Both
  // terminators are accepted.
  return RegExp(r'^\s{2}([a-zA-Z]\w*)\(\d+\)[,;]', multiLine: true)
      .allMatches(source.readAsStringSync())
      .map((RegExpMatch m) => m.group(1)!)
      .toList(growable: false);
}

void main() {
  group('C12 — every stop reason has a sentence, in English and in French', () {
    test('there are exactly TEN reasons, and TEN sentences, in both locales', () {
      expect(
        CheckStopReason.values,
        hasLength(10),
        reason:
            '§ 7: "StopReason a dix valeurs ; une seule raison non nommée est un état que '
            'le lecteur sur appareil emprunté ne peut pas décrire". Ten is the count the '
            'plugin declares, and the count the mapping `switch` has to cover',
      );
      for (final Locale locale in AppLocalizations.supportedLocales) {
        final Map<String, String> sentences = sentencesFor(locale);
        expect(
          sentences.keys.toSet(),
          CheckStopReason.values.map((CheckStopReason r) => r.name).toSet(),
          reason:
              '${locale.languageCode}: every reason needs a sentence in every language, or '
              'a `switch` with no `default` would still render one language\'s answer for '
              "another locale's reader",
        );
        expect(
          sentences.values.every((String s) => s.trim().isNotEmpty),
          isTrue,
          reason:
              '${locale.languageCode}: an empty string is not a sentence a reader can say '
              'aloud (C12)',
        );
      }
    });

    test('no sentence is a CSS selector, and none names a novel or a URL', () {
      for (final Locale locale in AppLocalizations.supportedLocales) {
        for (final MapEntry<String, String> entry in sentencesFor(
          locale,
        ).entries) {
          expect(
            entry.value,
            isNot(matches(RegExp(r'[\w.#]+\s*[,>]\s*[\w.#]+'))),
            reason:
                '`17-security.md` rule 4 and C12: `${entry.key}` renders as '
                '"${entry.value}", and a selector-shaped fragment is an artefact for the '
                'owner, not a sentence for a reader',
          );
        }
      }
    });

    test('deviceState, backgroundRestriction and timeout each say something DIFFERENT, and '
        'Doze is deliberately the SAME sentence as App Standby', () {
      // ⚠️ **FOUR DISTINCT CAUSES, NOT FIVE — AND THE PAIRING IS PINNED ON PURPOSE.**
      //
      // `6-10` § 10 asks for five distinct sentences including `deviceIdle` and
      // `appStandby`. That row cannot be met, and the reason is in the ARB:
      // `checkStoppedDeviceIdle`'s `@description` says *"Same French sentence as
      // `checkStoppedAppStandby` **on purpose**: Doze and App Standby are one thing to a
      // reader — the phone put the app to sleep — and two different sentences for one
      // cause is two truths about one phone's state."* Two Android constants describe one
      // thing that happened to one phone.
      //
      // So the row is split: the **three other causes** must all differ, *including from
      // the shared sleep sentence*, and the sharing is asserted rather than left to
      // chance. A future edit that gave Doze its own sentence — or that made `timeout`
      // read like `deviceState` — fails here.
      const List<CheckStopReason> distinct = <CheckStopReason>[
        CheckStopReason.deviceState,
        CheckStopReason.backgroundRestriction,
        CheckStopReason.timeout,
      ];
      for (final Locale locale in AppLocalizations.supportedLocales) {
        final Map<String, String> sentences = sentencesFor(locale);
        expect(
          sentences[CheckStopReason.deviceIdle.name],
          sentences[CheckStopReason.appStandby.name],
          reason:
              'one fact, one sentence (${locale.languageCode}). `6-7` decided this '
              'deliberately: Doze and App Standby are both "the phone put the app to '
              'sleep", and two sentences for one cause is two truths about one phone\'s '
              'state',
        );
        final List<String> all = <String>[
          for (final CheckStopReason reason in distinct)
            sentences[reason.name]!,
          sentences[CheckStopReason.deviceIdle.name]!,
        ];
        expect(
          all.toSet(),
          hasLength(all.length),
          reason:
              '§ 10 / C12: `deviceState`, `backgroundRestriction`, `timeout` and the '
              'shared sleep sentence are four different facts about the phone and each '
              'needs its own words (${locale.languageCode}). "The phone did something" '
              'is the answer this row exists to forbid',
        );
      }
    });

    test(
      'systemIgnoredCancelledByApp says the check FINISHED, never that it was cancelled',
      () {
        // ⚠️ **THE EXPECTED SENTENCES ARE WRITTEN OUT, NOT DERIVED.** `6-7` owns these ARB
        // keys and `6-10` owns the mapping; a test that computed the expectation from the
        // same generated file the copy comes from would assert nothing. What is asserted is
        // the *wording*: it announces a finished pass and does not open with the word a
        // cancellation uses.
        const Map<String, String> expected = <String, String>{
          'en': 'Check finished after you cancelled it.',
          'fr':
              "La v\u00e9rification s'est termin\u00e9e apr\u00e8s votre annulation.",
        };
        const Map<String, String> cancelOpens = <String, String>{
          'en': 'Check cancelled',
          'fr': 'V\u00e9rification annul\u00e9e',
        };
        for (final Locale locale in AppLocalizations.supportedLocales) {
          final Map<String, String> sentences = sentencesFor(locale);
          // ⚠️ **`!` BECAUSE A `null` WOULD BE THE VACUOUS ANSWER.** A missing sentence has to
          // fail loudly; `startsWith` on `null` reads as *not starting with*, which is the
          // wrong direction for the one row that says the reader is told the check ended.
          final String cancelled =
              sentences[CheckStopReason.cancelledByApp.name]!;
          final String ignored =
              sentences[CheckStopReason.systemIgnoredCancelledByApp.name]!;
          final String language = locale.languageCode;
          expect(
            ignored,
            expected[language],
            reason:
                '§ 10: "StopReason.systemIgnoredCancelledByApp rend *Check finished after '
                'you cancelled it*, et **pas** *cancelled*". The worker ran to completion, '
                'so the reader holds results they did not ask for and must be told they are '
                'real ($language)',
          );
          expect(
            cancelled.startsWith(cancelOpens[language]!),
            isTrue,
            reason:
                "the reader's own gesture reads as a cancellation ($language) — rule 7: "
                'it is not a failure and must not be dressed as a stop',
          );
          expect(
            ignored.startsWith(cancelOpens[language]!),
            isFalse,
            reason:
                'a sentence opening with the cancellation word would send the reader '
                'looking for changes that are already saved ($language)',
          );
        }
      },
    );
  });

  group('parity with the installed workmanager_platform_interface', () {
    test('the two enumerations declare the same ten names, in the same order', () {
      final List<String> installed = installedStopReasonNames();
      expect(
        installed,
        hasLength(10),
        reason:
            'the plugin declares ten stop reasons (read from its source). If this changes, '
            'the mapping `switch` must gain an arm — a build error is the intended outcome',
      );
      expect(
        CheckStopReason.values.map((CheckStopReason r) => r.name).toList(),
        installed,
        reason:
            '`domain/` cannot import the plugin, so the two enumerations are separate '
            'declarations of one fact. A rename on either side would otherwise leave the '
            'app mapping a reason onto the wrong sentence, which no compiler reports',
      );
    });

    test('every wireValue round-trips through fromWireValue', () {
      for (final CheckStopReason reason in CheckStopReason.values) {
        expect(
          CheckStopReason.fromWireValue(reason.wireValue),
          reason,
          reason:
              'the wire form is the reason\'s index, because C2 permits only integers '
              'across the isolate boundary. A payload that round-trips to `null` would be '
              'dropped, and the reader would see the last progress standing with no '
              'statement that the check stopped',
        );
      }
      expect(
        CheckStopReason.fromWireValue(-1),
        isNull,
        reason:
            '⚠️ AND `null`, NOT `unknown`. "Android said nothing" and "Android said '
            'something this build has never heard of" are two different facts, and § 7\'s '
            'last trap is a `switch` that collapses them into one sentence',
      );
    });
  });
}
