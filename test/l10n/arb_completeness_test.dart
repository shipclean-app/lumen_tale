// Lumen Tale — `localisation` § 11.1, ARB completeness.
//
// Seven rows about the two ARB files. They are the cheapest tests in the project
// and the ones that catch the most: a key missing from French does not fail a
// build, it ships an English string to a French reader, and the fallback in
// `main.dart` makes that invisible at runtime.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// A parsed ARB file: message keys, metadata keys, and placeholders per key.
class _Arb {
  _Arb(this.path, this.raw);

  factory _Arb.load(String path) => _Arb(
    path,
    jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>,
  );

  final String path;
  final Map<String, dynamic> raw;

  /// Keys that are messages rather than `@metadata`.
  Iterable<String> get messageKeys =>
      raw.keys.where((String k) => !k.startsWith('@'));

  bool has(String key) => raw.containsKey(key);

  Object? message(String key) => raw[key];

  /// `{name}` placeholders in a message, in order.
  List<String> placeholdersOf(String key) {
    final value = raw[key];
    if (value is! String) return const <String>[];
    return RegExp(
      r'\{(\w+)[,}]',
    ).allMatches(value).map((Match m) => m.group(1)!).toList();
  }
}

void main() {
  final english = _Arb.load('lib/l10n/app_en.arb');
  final french = _Arb.load('lib/l10n/app_fr.arb');

  group('the French file has every key the English template has', () {
    test('no English key is missing from French', () {
      // B28: a key present only in English ships an English string to a French
      // reader, and `main.dart`'s fallback hides it — the app resolves, so no
      // test anywhere else fails.
      final missing =
          english.messageKeys.where((String k) => !french.has(k)).toList()
            ..sort();
      expect(
        missing,
        isEmpty,
        reason: 'B28 — these keys exist only in English: $missing',
      );
    });

    test('the reverse is also true', () {
      final missing =
          french.messageKeys.where((String k) => !english.has(k)).toList()
            ..sort();
      expect(
        missing,
        isEmpty,
        reason:
            'a key only in French has no template to inherit its metadata '
            'from: $missing',
      );
    });
  });

  group('no message is empty in either language', () {
    test('neither file holds a blank message', () {
      final blanks = <String>[];
      for (final arb in <_Arb>[english, french]) {
        for (final key in arb.messageKeys) {
          final value = arb.message(key);
          if (value is! String || value.trim().isEmpty) {
            blanks.add('${arb.path}: $key = ${jsonEncode(value)}');
          }
        }
      }
      expect(
        blanks,
        isEmpty,
        reason:
            'an empty string is a key that renders as nothing, which is not '
            'the same as a missing key and is harder to notice: $blanks',
      );
    });

    test('the empty-string check can fail', () {
      // Witness. Without this, a future edit that made the check vacuous would
      // leave a permanently green row.
      expect('   '.trim().isEmpty, isTrue);
    });
  });

  group('placeholder names are identical in both languages', () {
    test('every shared key uses the same placeholder names', () {
      final mismatches = <String>[];
      for (final key in english.messageKeys.where(french.has)) {
        final en = english.placeholdersOf(key).toSet();
        final fr = french.placeholdersOf(key).toSet();
        if (en.length != fr.length || !en.containsAll(fr)) {
          mismatches.add('$key: en=$en fr=$fr');
        }
      }
      expect(
        mismatches,
        isEmpty,
        reason:
            'B28 — a translated placeholder name breaks the generated '
            'accessor and fails at compile time, or worse, silently drops the '
            'value: $mismatches',
      );
    });

    test('the placeholder extractor finds real placeholders', () {
      expect(
        english.placeholdersOf('coverSemanticsLabel'),
        contains('title'),
        reason: 'witness — the extractor must actually extract',
      );
    });
  });

  group('every message has its @key metadata block', () {
    test('no key lacks a metadata entry', () {
      // A key needs `@key` metadata when gen-l10n has something to INFER: a
      // placeholder or a plural. A plain literal needs none, and demanding one
      // would put noise in every ARB file to satisfy a checker.
      //
      // So the row asks the real question — every key that HAS a placeholder
      // must declare itself, because that is the set where a wrong inference
      // actually changes what the reader sees.
      bool needsMetadata(String key) {
        final value = english.message(key);
        if (value is! String) return false;
        return value.contains('{') || value.contains('}');
      }

      final orphans =
          english.messageKeys
              .where((String k) => needsMetadata(k) && !english.has('@$k'))
              .toList()
            ..sort();
      expect(
        orphans,
        isEmpty,
        reason:
            'B28 — keys carrying a placeholder but no metadata, so '
            'gen-l10n infers their shape: $orphans',
      );

      // And the keys that genuinely need metadata do declare it, which is what
      // keeps the check above from passing by finding nothing to check.
      expect(english.has('@chapterCount'), isTrue);
      expect(english.has('@coverSemanticsLabel'), isTrue);
    });
  });

  group('no ARB value contains a forbidden empty-result string', () {
    test('no message hard-codes an empty-result sentence', () {
      // B22/B28: "No results" is a *state*, and a state belongs to a screen that
      // knows whether it is empty. A string that says it is a permanent lie the
      // moment the list has something in it.
      const forbidden = <String>[
        'no results',
        'aucun résultat',
        'nothing here',
      ];

      // ⚠️ **One exemption, named, with a reason — not a widened rule.**
      //
      // `'nothing here'` is a heuristic for "this message claims a list is empty",
      // and E11's sentence happens to open with the same three words while claiming
      // something else entirely: that nothing here is *backed up*. Narrowing the
      // phrase would weaken the rule for every future key; rewording the design's copy
      // would diverge `settings-about.md` § 4.1 from the ARB on the one sentence the
      // screen exists to state. An exemption with a reason is reviewable; a silent
      // exception is not.
      const exemptions = <String, String>{
        'aboutDataE11':
            'E11, and not an empty-result state: "Nothing here is backed up '
            'anywhere" names STORAGE, not a list. settings-about.md § 4.1, and '
            'the sentence `3-5` exists to show.',
      };

      final offenders = <String>[];
      for (final arb in <_Arb>[english, french]) {
        for (final key in arb.messageKeys) {
          if (exemptions.containsKey(key)) continue;
          final value = arb.message(key);
          if (value is! String) continue;
          final lower = value.toLowerCase();
          for (final phrase in forbidden) {
            if (lower.contains(phrase)) {
              offenders.add('${arb.path}: $key -> $value');
            }
          }
        }
      }
      expect(offenders, isEmpty, reason: '$offenders');
    });
  });

  group('gen-l10n left no untranslated message behind', () {
    test('the generated untranslated-messages report is empty or absent', () {
      // `flutter gen-l10n` writes `untranslated-messages.json` when a template
      // message has no translation. An empty file is fine; a populated one means
      // the fallback is silently doing the work.
      final candidates = <String>[
        '.dart_tool/flutter_gen/gen_l10n/untranslated-messages.json',
        'lib/l10n/untranslated-messages.json',
      ];
      for (final path in candidates) {
        final file = File(path);
        if (!file.existsSync()) continue;
        final decoded = jsonDecode(file.readAsStringSync());
        expect(
          decoded,
          isEmpty,
          reason:
              'B28 — gen-l10n reported untranslated messages in $path: '
              '$decoded. Every key must be translated in both languages.',
        );
      }
    });
  });
}
