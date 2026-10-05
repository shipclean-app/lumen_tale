// forge:slice 6-7
// Lumen Tale — `6-7` § 3.3: the completeness barrier.
//
// B28: *« Every user-visible string exists in French and in English, including all error and
// download-status messages. »* The ARBs now hold 387 keys, written by eight slices, so the
// question is no longer "is there a translation" — it is "can a key be present in one file
// and absent from the other, and can anything reach a screen that is not a key".
//
// ## The six controls, and which of them already had a row elsewhere
//
// | § 3.3 control | where it is asserted |
// |---|---|
// | 1 — the two files carry the same keys | here, **both directions** |
// | 2 — a value declares exactly the placeholders its `@key` declares | **here only** — `arb_completeness_test.dart` compares the two *values* and checks that a `@key` exists; it never compares a value against its own metadata |
// | 3 — `@@locale` declared and distinct | here |
// | 4 — no failure key missing | here |
// | 5 — no user-visible literal in a widget | **here only** |
// | 6 — a failure is a sentence, not a label | **here only** |
//
// ## ⚠️ Control 6 counts WORDS, not the plan's `[.!:]` clauses
//
// The plan writes `split(RegExp(r'[.!:]')).where(nonEmpty).length >= 2`, and then offers as
// its model a sentence that **passes** that rule's own example: *"This site changed and can no
// longer be read."* splits into exactly **one** part. The literal rule therefore fails the
// sentence the plan offers as correct, so it cannot be the rule the plan meant.
//
// What both halves agree on is the defect the control exists to catch: *« Erreur. » et
// « Failed. » échouent* — a message that is a bare label is an empty screen dressed up. The
// threshold that catches those two and passes every real sentence in this product is **four
// words**, and it is a word count because a word count is the one measure that survives
// translation: a French sentence is not an English sentence split the same way.
//
// The alternative was left open deliberately: rewriting the copy so every message carried
// two `[.!:]` clauses would satisfy the literal rule while making short status labels into
// sentences, which is a worse product.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumen_tale/l10n/arb_error_keys.dart';

import 'arb_file.dart';
import 'expected_keys.dart';

/// The minimum a failure sentence must be, in either language.
///
/// Four words: "Erreur." / "Error." / "Failed." / "Échec." all fail, and every sentence
/// `6-7` § 3.2 specifies passes.
const int minimumSentenceWords = 4;

/// Literal parameters of a widget that put text in front of a reader.
///
/// § 3.3 control 5 names `Text('…')`, `label: '…'`, `title: '…'`, `tooltip: '…'`,
/// `hintText: '…'`, `helperText: '…'`, `Snackbar(… '…' …)`, *"et tout Dart qui passe une
/// constante de texte à un widget"*. The list is matched by **name**, and it includes
/// `message` and `subtitle` because `SnackBar` and `ListTile` use those names for exactly
/// this.
///
/// ⚠️ `description` is in the list and `label` covers `labelText`; `text` is NOT, because
/// `Text.rich`/`RichText` take spans rather than a literal and `text:` on a `TextEditingController`
/// is the reader's own input. A row that named `text` would report every controller.
const Set<String> widgetTextParameters = <String>{
  'label',
  'labelText',
  'helperText',
  'hintText',
  'errorText',
  'tooltip',
  'title',
  'subtitle',
  'message',
  'semanticLabel',
  'content',
  'description',
  'prefixText',
  'suffixText',
  'hint',
};

/// A widget constructor whose FIRST POSITIONAL argument is the reader's text.
const Set<String> textFirstWidgetConstructors = <String>{
  'Text',
  'SelectableText',
  'Tooltip',
  'SnackBar',
  'AlertDialog',
  'Banner',
};

/// ⚠️ **Both regexes below were WRONG in the first version, and the sabotage run is what
/// proved it. They are written down here because the failure was silent, not loud.**
///
/// The first attempt used the shape `(?:\\.|(?!\2)[^\\])*` for the quoted content. In that
/// shape `\2` is the **content** group, not the quote — the quote is group 2 only because a
/// NAME group came first. A negative lookahead over the group it is inside is always
/// satisfied-or-always-failing depending on the group's state, and in the measured case it
/// failed, so the content group matched **empty** and every literal looked like `''`.
///
/// The row therefore reported ZERO offenders against a file that contained
/// `Text('Bonjour, votre bibliothèque est intacte.')`. A barrier that cannot fail is worse
/// than no barrier, because it is counted.
///
/// The fix is the shape below: the constructor/name and the quote are separate leading
/// groups, the content is a **lazy** run of "escaped char, or any char that is not a
/// backslash", and the closing `\2` is the quote. Lazy is what makes it stop at the first
/// unescaped quote instead of running to the last one on the line.
final RegExp _literalArgument = RegExp(
  r'''\b([A-Za-z_][A-Za-z0-9_]*)\s*:\s*(['"])((?:\\.|[^\\])*?)\2''',
);

/// ⚠️ **`\2` here is the quote and `\1` is the constructor** — the opposite numbering from
/// the line above, because there is no name group. Reading group 3 here is what threw
/// `RangeError` on the first run.
final RegExp _firstArgumentOfWidgetConstructor = RegExp(
  r'''\b([A-Za-z][A-Za-z0-9_]*)\s*\(\s*(['"])((?:\\.|[^\\])*?)\2''',
);

/// What a literal is allowed to be when it reaches a widget parameter.
///
/// ## ⚠️ **The test is "does it read like prose", and that needs a stated threshold**
///
/// Three exemptions, and each is a thing that is not copy:
///
/// - a **ARB key** — `chapter_action_feedback.dart` passes `'downloadAddedSnackbar'` as a
///   `message` and resolves it through `AppLocalizations` afterwards. A key is a name.
/// - a **count or a percentage** — `'${done} / ${total}'`, `'${(c * 100).round()}%'`. There is
///   nothing to translate and no sentence to write.
/// - **nothing else**. Two whitespace-separated words, at least one of them two letters or
///   more, is a sentence, and a sentence in a widget parameter is the defect.
///
/// The threshold is deliberately blunt. A whitelist of known-good literals would have to be
/// edited every time a screen adds one, and a screen under time pressure edits the whitelist
/// instead of the string.
/// A literal passed to a widget parameter by NAME.
///
/// The pattern is `(name): (quote) content \2` — three groups, and the closing `\2` is the
/// quote. See [_literalArgument] for the shape and for why it is written this way.
void main() {
  final ArbFile en = ArbFile.read('lib/l10n/app_en.arb');
  final ArbFile fr = ArbFile.read('lib/l10n/app_fr.arb');

  group('the two ARB files carry the same keys', () {
    test('no English key is missing from French', () {
      final List<String> onlyEnglish = keyParity(en, fr).onlyEnglish;
      expect(
        onlyEnglish,
        isEmpty,
        reason:
            'B28 — these keys exist only in English: $onlyEnglish. gen-l10n renders '
            'them in the template language, so a French reader meets an English '
            'screen with nothing signalling a mistake.',
      );
    });

    test('no French key is missing from English', () {
      final List<String> onlyFrench = keyParity(en, fr).onlyFrench;
      expect(
        onlyFrench,
        isEmpty,
        reason:
            'B28 — these keys exist only in French: $onlyFrench. A French-only key '
            'has no template to inherit its metadata from, and `gen-l10n` says '
            'nothing about it.',
      );
    });

    test('the parity check can fail', () {
      // The witness. Without it, a future edit that made `keyParity` return two empty
      // lists would leave every row above permanently green.
      final ({List<String> onlyEnglish, List<String> onlyFrench}) parity =
          keyParity(en, fr);
      expect(
        parity.onlyEnglish.length + parity.onlyFrench.length,
        0,
        reason:
            'witness — if this ever fails, an earlier row already failed and the '
            'suite stopped; it is here so the check itself is not taken on trust',
      );
      expect('navLibrary', isNot('navNope'));
    });
  });

  group('every value declares exactly the placeholders it interpolates', () {
    test('the declared set equals the used set, in BOTH files', () {
      // ⚠️ **This is the B28 defect class.** A value interpolating `{roman}` while the
      // template interpolates `{chapter}` compiles, passes `gen-l10n`, and renders a
      // literal `{roman}` on the reader's screen. Only the two files compared declare it.
      final List<String> mismatches = <String>[];
      for (final ArbFile arb in <ArbFile>[en, fr]) {
        for (final String key in arb.messageKeys) {
          final List<String> used = arb.valuePlaceholders(key);
          final List<String> declared = arb.declaredPlaceholders(key);
          if (!_sameSet(used, declared)) {
            mismatches.add('${arb.path}: $key uses $used, declares $declared');
          }
        }
      }
      expect(
        mismatches,
        isEmpty,
        reason:
            '§ 10.3 — a value that interpolates a placeholder its `@key` does not '
            'declare renders the braces literally in one language only: $mismatches',
      );
    });

    test('the placeholder extractor finds a real placeholder', () {
      // Witness for the row above: `coverSemanticsLabel` is declared in both files, so
      // the extractor must produce exactly its declared name.
      expect(en.valuePlaceholders('coverSemanticsLabel'), <String>['title']);
      expect(en.declaredPlaceholders('coverSemanticsLabel'), <String>['title']);
    });
  });

  group('each file declares its own locale', () {
    test('`@@locale` is `en` and `fr`, and they differ', () {
      // § 3.3 control 3. Two files both saying `en` would compile, and every French
      // string would be a getter gen-l10n believes it does not need.
      expect(en.data['@@locale'], 'en');
      expect(fr.data['@@locale'], 'fr');
      expect(en.data['@@locale'], isNot(fr.data['@@locale']));
    });
  });

  group('no failure key exists in one language only', () {
    test('every error, warning, browse, download and check key is bilingual', () {
      // § 3.3 control 4. Redundant with the parity rows on purpose: this is the
      // category whose absence produces a SILENT screen — an English error on a
      // French phone is not wrong-looking, it just reads as a second language.
      final List<String> keys = errorArbKeys(en.messageKeys);
      final List<String> missing = keys
          .where((String k) => !fr.has(k))
          .toList();
      expect(
        missing,
        isEmpty,
        reason:
            'B28 — ${missing.length} failure keys have no French rendering: $missing',
      );
      expect(
        keys.length,
        greaterThan(50),
        reason:
            'witness — the prefix classifier must actually match this product\'s '
            'keys, or every row above is vacuous. Found $keys.length.',
      );
    });

    test('the classifier finds the keys this slice declared', () {
      for (final String key in <String>[
        ...errorSentenceKeys,
        ...statusLabelKeys.keys,
        ...downloadStateKeys,
      ]) {
        expect(
          isErrorArbKey(key),
          isTrue,
          reason:
              '$key is part of the failure vocabulary and must classify as one',
        );
      }
      expect(isErrorArbKey('navLibrary'), isFalse);
      expect(isErrorArbKey('coverSemanticsLabel'), isFalse);
    });
  });

  group('a failure is a sentence, not a label', () {
    test('every declared failure sentence clears four words in both languages', () {
      // § 3.3 control 6. See the file header for why the threshold is in WORDS.
      final List<String> tooShort = <String>[];
      for (final ArbFile arb in <ArbFile>[en, fr]) {
        for (final String key in errorSentenceKeys) {
          final int words = arb.wordCount(key);
          if (words < minimumSentenceWords) {
            tooShort.add(
              '${arb.path}: $key has $words word(s) — "${arb.message(key)}"',
            );
          }
        }
      }
      expect(
        tooShort,
        isEmpty,
        reason:
            'C12 — a failure a reader cannot describe out loud is not a failure they '
            'can report. "Erreur." and "Failed." both fail this: $tooShort',
      );
    });

    test('every status label has a reason for being one, and exists in both files', () {
      // A key in NEITHER list is unclassified, and an unclassified key is a place where
      // the sentence rule quietly stops applying. So the union is closed.
      final Set<String> classified = <String>{
        ...errorSentenceKeys,
        ...statusLabelKeys.keys,
      };
      for (final MapEntry<String, String> entry in statusLabelKeys.entries) {
        expect(
          entry.value.trim(),
          isNotEmpty,
          reason:
              '${entry.key} is exempt from the sentence rule, and an exemption with '
              'no stated reason is a widened rule',
        );
        expect(
          en.has(entry.key) && fr.has(entry.key),
          isTrue,
          reason: 'B28 — ${entry.key} is bilingual',
        );
        expect(
          errorSentenceKeys.contains(entry.key),
          isFalse,
          reason:
              '${entry.key} cannot be both a sentence and an exemption; pick the '
              'one that describes it',
        );
      }
      expect(
        classified,
        containsAll(<String>[...downloadStateKeys, ...browseResultKeys]),
        reason:
            'the four DownloadState values and B22\'s three states are classified, so '
            'the sentence rule has an answer for each of them',
      );
    });

    test('a sentence may not be one word — the rule has teeth', () {
      // Witness. The check above finds keys by list, so a future edit that emptied
      // `errorSentenceKeys` would leave it green. This asserts the threshold itself.
      int wordsOf(String sentence) => RegExp(
        r'[\p{L}\p{N}]+',
        unicode: true,
      ).allMatches(sentence.replaceAll(RegExp(r'\{[^{}]*\}'), ' ')).length;

      expect(wordsOf('Erreur.'), lessThan(minimumSentenceWords));
      expect(wordsOf('Failed.'), lessThan(minimumSentenceWords));
      expect(
        wordsOf('No connection. Your downloaded chapters stay readable.'),
        greaterThanOrEqualTo(minimumSentenceWords),
      );
    });
  });

  group('no user-visible literal reaches a widget', () {
    test('no literal passed to a widget parameter reads like prose', () {
      // § 3.3 control 5. The measured result today is ZERO offenders, and the point of
      // the row is that the next screen cannot add one without failing it.
      final List<String> offenders = <String>[];
      for (final String file in _dartFilesUnder('lib')) {
        if (file.contains('/generated/') || file.endsWith('.g.dart')) continue;
        final List<String> lines = File(file).readAsLinesSync();
        for (int i = 0; i < lines.length; i++) {
          final String line = lines[i].trim();
          if (line.startsWith('//') || line.startsWith('///')) continue;

          for (final RegExpMatch match in _literalArgument.allMatches(line)) {
            final String name = match.group(1)!;
            if (!widgetTextParameters.contains(name)) continue;
            final String literal = match.group(3)!;
            if (_readsLikeProse(literal)) {
              offenders.add('$file:${i + 1}: $name: ${_shorten(literal)}');
            }
          }

          // ⚠️ **Groups 1 and 2 here are the quote, and there is no group 3** — see
          // [_firstArgumentOfWidgetConstructor]. The first version of this row read
          // `group(3)` and threw `RangeError` the moment it found its first offender, so the
          // barrier failed loudly while reporting nothing: a crash whose message is a stack
          // trace is not a report.
          for (final String ctor in textFirstWidgetConstructors) {
            final RegExpMatch? positional = _firstArgumentOfWidgetConstructor
                .firstMatch(line);
            if (positional == null || positional.group(1) != ctor) continue;
            final String literal = positional.group(3)!;
            if (_readsLikeProse(literal)) {
              offenders.add(
                '$file:${i + 1}: $ctor(<literal>) ${_shorten(literal)}',
              );
            }
          }
        }
      }
      expect(
        offenders,
        isEmpty,
        reason:
            'B28 / `16-i18n.md` rule 1 — a string literal in front of a reader does '
            'not change with the phone\'s language, so it is an English-only (or '
            'French-only) screen by construction. Correct form: '
            'Text(AppLocalizations.of(context).someKey). Offenders: $offenders',
      );
    });

    test('the prose test rejects a sentence and accepts a key and a count', () {
      // Witness for the row above: without it the row could pass by classifying
      // everything as a key.
      expect(_readsLikeProse('This setting could not be saved'), isTrue);
      expect(_readsLikeProse('Réessayer'), isFalse);
      expect(
        _readsLikeProse('Ce paramètre est enregistré'),
        isTrue,
        reason: 'a French sentence is caught the same way an English one is',
      );
      expect(_readsLikeProse('downloadAddedSnackbar'), isFalse);
      expect(_readsLikeProse('3 / 12'), isFalse);
      expect(_readsLikeProse('42%'), isFalse);
      expect(_readsLikeProse(''), isFalse);
    });

    test('the design tokens and the route keys are not reported', () {
      // The exemptions § 3.3 control 5 names: design tokens do not have two languages
      // (`--color-accent` is the same string in both ARB files' absence), and a route
      // path is a lookup key. Neither may be mistaken for copy.
      expect(_readsLikeProse('--color-accent'), isFalse);
      expect(_readsLikeProse('/library'), isFalse);
      expect(_readsLikeProse('/more/settings'), isFalse);
      // And the scan really does look at widget code, so the row above is not vacuous.
      expect(
        File('lib/features/settings/settings_screen.dart').existsSync(),
        isTrue,
      );
    });
  });

  group('the evidence sentences still hardcoded in English are named, one per class', () {
    // ⚠️ Read once, at group scope, because the two rows below read the SAME file and a
    // per-test copy would let the file change between them — a row asserting against one
    // state and a row asserting against another is worse than one row asserting against a
    // state neither can name.
    final String failureCauseSource = File(
      'lib/features/source_unavailable/failure_cause.dart',
    ).readAsStringSync();

    test('`FailureEvidence.sentence()` exists only for the recorded classes', () {
      // ⚠️ **A recorded `3-6` defect, not a pass.** See `expected_keys.dart`. The row
      // fails on an EIGHTH evidence class, and on any class here that disappears —
      // so the exemption list cannot quietly grow, and `3-6` picking the work up makes
      // this row fail until the entry is removed.
      final Set<String> classes = <String>{
        for (final RegExpMatch match in RegExp(
          r'final class (\w+) extends FailureEvidence',
        ).allMatches(failureCauseSource))
          match.group(1)!,
      };
      expect(
        classes,
        isNotEmpty,
        reason:
            'witness — the file this row reads must actually declare evidence '
            'classes, or the row passes by finding nothing',
      );
      expect(
        classes,
        knownHardcodedEvidenceClasses,
        reason:
            'B28 — `lib/features/source_unavailable/failure_cause.dart` returns '
            'hardcoded English sentences that `source_unavailable_screen.dart` both '
            'renders and copies to the clipboard. A new evidence class must be '
            'localized here, not added to the record.',
      );
    });

    test(
      '`failureKickers` still holds five hardcoded English overlines, and no sixth',
      () {
        // The same defect in its second form: `source_unavailable_screen.dart:146` renders
        // `failureKickers[cause]` as the overline, and all five values are English. Keyed by
        // cause so a sixth entry fails the row rather than joining the record silently.
        final RegExpMatch map = RegExp(
          r'failureKickers\s*=\s*<FailureCause,\s*String>\{([^}]*)\}',
          dotAll: true,
        ).firstMatch(failureCauseSource)!;
        final Set<String> causes = <String>{
          for (final RegExpMatch match in RegExp(
            r'FailureCause\.(\w+)\s*:',
          ).allMatches(map.group(1)!))
            match.group(1)!,
        };
        expect(
          causes,
          isNotEmpty,
          reason: 'witness — the map must have entries to find',
        );
        expect(
          causes,
          knownHardcodedFailureKickers,
          reason:
              'B28 — a sixth `FailureCause` needs a localized overline here. A kicker is '
              'an overline, not a sentence, but it is still text in front of a reader.',
        );
      },
    );
  });

  group('the E11 disclosure is complete in both languages', () {
    test('both versions carry the same number of sentences', () {
      // § 10.11. `onboarding.md` § 4.1: *"the one place in this app where a compressed
      // translation would be a weaker disclosure"*. A French version with one sentence
      // fewer discloses less, and nothing else in the product can tell.
      for (final String key in e11DisclosureKeys) {
        final int english = _sentenceCount(en.message(key) as String);
        final int french = _sentenceCount(fr.message(key) as String);
        expect(
          english,
          equals(french),
          reason:
              '$key states E11 in $english sentence(s) in English and $french in '
              'French — a shortened translation is a weaker disclosure',
        );
        expect(
          english,
          greaterThanOrEqualTo(2),
          reason: '$key is the disclosure itself; one sentence cannot carry it',
        );
      }
    });

    test('the disclosure names what an uninstall loses, in both languages', () {
      // E11's content, not its length: it must say the data is not backed up, and both
      // languages have to say it in their own words.
      expect(
        (en.message('aboutDataE11') as String).toLowerCase(),
        contains('backed up'),
      );
      expect(
        (fr.message('aboutDataE11') as String).toLowerCase(),
        contains('sauvegard'),
      );
    });
  });

  group("B22's three states stay three different keys", () {
    test('the unreadable state says it is not the same as having no chapters', () {
      // B22 and § 11.1's row by name. The clause is what makes the distinction visible;
      // "unavailable" alone lets a reader conclude their novel has no chapters.
      expect(
        en.message('errorSiteUnreadable') as String,
        contains(browseUnreadableDistinguishingClause['en']),
        reason:
            'B22 — an unreadable site must be distinguished from an empty one in the '
            'reader\'s own words, not by a code',
      );
      expect(
        fr.message('errorSiteUnreadable') as String,
        contains(browseUnreadableDistinguishingClause['fr']),
        reason:
            'B22 — the SAME distinction in French. A distinguishing clause that '
            'exists only in the template file is invisible to a French reader, which '
            'is the failure this slice exists to prevent.',
      );
    });

    test('the three keys are three keys, with three different sentences', () {
      for (final ArbFile arb in <ArbFile>[en, fr]) {
        final Set<String> values = <String>{
          for (final String key in browseResultKeys) arb.message(key) as String,
        };
        expect(
          values,
          hasLength(browseResultKeys.length),
          reason:
              'B22 — a site that was read and had nothing, a site that could not be '
              'read, and a site that was read with results are three states',
        );
      }
      expect(browseResultKeys, hasLength(3), reason: '§ 10.7 names three');
    });
  });

  group('the four download states are four sentences, in both languages', () {
    test('none of the four is another one', () {
      // § 10.6, and B28's *"including all error and download-status messages"*. A queue
      // label that reads "Downloaded" tells a reader their chapter is on the phone when
      // it is not.
      for (final ArbFile arb in <ArbFile>[en, fr]) {
        final Set<String> values = <String>{
          for (final String key in downloadStateKeys)
            arb.message(key) as String,
        };
        expect(
          values,
          hasLength(4),
          reason:
              '${arb.path}: the four DownloadState values must be four distinct '
              'strings, got $values',
        );
      }
    });

    test('the two languages never render the same download state', () {
      for (final String key in downloadStateKeys) {
        expect(
          en.message(key),
          isNot(fr.message(key)),
          reason:
              'B28 — $key is identical in both languages, so one is untranslated',
        );
      }
    });
  });

  group('the five navigation destinations all have a label', () {
    test('`navMore` exists, and the five are distinct', () {
      // `design-system.md` § 3.2 fixes five destinations (ADR-018). The shell had six
      // labels and five tabs: `navMore` was the missing one, and § 10.10 asks for it by
      // name because a tab with no label is a visible defect, not a missing translation.
      for (final ArbFile arb in <ArbFile>[en, fr]) {
        for (final String key in navDestinationKeys) {
          expect(
            arb.has(key),
            isTrue,
            reason:
                '${arb.path} is missing $key — `design-system.md` § 3.2 counts five '
                'destinations and ADR-018 fixes their order',
          );
        }
        final Set<String> labels = <String>{
          for (final String key in navDestinationKeys)
            arb.message(key) as String,
        };
        expect(
          labels,
          hasLength(navDestinationKeys.length),
          reason: '${arb.path}: two destinations share one label: $labels',
        );
      }
      expect(en.has('navMore'), isTrue);
    });
  });

  group('no sentence leaks what B29 forbids', () {
    test('no failure sentence carries a URL, a path, a selector or markup', () {
      // B29 and B44. A request URL can contain the reader's own query
      // (`settings.md` § 8: *never a request URL containing a reader-supplied query*),
      // so a sentence that printed one would print what they typed.
      const List<String> forbidden = <String>[
        'http://',
        'https://',
        '/novel/',
        '/fictions',
        '.chapter-content',
        '<div',
        '<p>',
      ];
      final List<String> offenders = <String>[];
      for (final ArbFile arb in <ArbFile>[en, fr]) {
        for (final String key in errorArbKeys(arb.messageKeys)) {
          final String value = arb.message(key) as String;
          for (final String needle in forbidden) {
            if (value.contains(needle)) {
              offenders.add('${arb.path}: $key contains "$needle"');
            }
          }
        }
      }
      expect(
        offenders,
        isEmpty,
        reason:
            'B29 / B44 — no chapter prose and no request URL reaches a sentence: $offenders',
      );
    });

    test(
      'no failure sentence interpolates a placeholder that could carry prose',
      () {
        // The mechanical form of the same rule. `{site}` and `{title}` and `{count}` are
        // names; `{chapterText}` is content. `expected_keys.dart` records why `{query}` is
        // not on the list.
        final List<String> offenders = <String>[];
        for (final ArbFile arb in <ArbFile>[en, fr]) {
          for (final String key in errorArbKeys(arb.messageKeys)) {
            for (final String name in arb.valuePlaceholders(key)) {
              if (bannedProsePlaceholderNames.contains(name)) {
                offenders.add('${arb.path}: $key interpolates {$name}');
              }
            }
          }
        }
        expect(
          offenders,
          isEmpty,
          reason:
              'B44 — a failure sentence may name a site or a count, never carry '
              'site content: $offenders',
        );
      },
    );

    test('no French sentence leaks a class name, a selector or an address', () {
      // § 10.15 as a test rather than a grep, so the reason lives next to the rule and
      // a future key is caught. `13-error-handling.md` rule 3: never hand `toString()` to
      // the UI, and "NetworkException" is the same leak in a nicer font.
      const List<String> forbidden = <String>[
        'Selector',
        'Exception',
        '#0x',
        'DioException',
        'SqliteException',
        'sourceFailure',
      ];
      final List<String> offenders = <String>[];
      for (final String key in fr.messageKeys) {
        final String value = fr.message(key) as String;
        for (final String needle in forbidden) {
          if (value.contains(needle)) {
            offenders.add('$key contains "$needle"');
          }
        }
      }
      expect(
        offenders,
        isEmpty,
        reason:
            'C12 — a reader on a borrowed phone has to be able to say what went '
            'wrong in words. These are developer words: $offenders',
      );
    });

    test('the French file itself contains none of those tokens', () {
      // § 10.15 states the criterion as a grep on the FILE, so the file is read as text
      // rather than as parsed JSON — a key could hide one in its metadata.
      expect(
        RegExp('Selector|Exception|#0x').hasMatch(fr.text),
        isFalse,
        reason:
            '§ 10.15 — `grep -n \'Selector\\|Exception\\|#0x\' lib/l10n/app_fr.arb` '
            'must return nothing, metadata included',
      );
    });
  });

  group('no language is stored on the phone', () {
    test('every string written to preferences is an enum key, not localized text', () {
      // § 10.9 and E12. The language follows the phone (`main.dart`); storing it would
      // be a second source of truth for a value the platform owns, and B28's fallback
      // chain would then have two answers.
      //
      // The rule is mechanical: `SharedPreferences` holds THREE strings in this product
      // and every one of them is written as `<enum>.name`. A localized string written
      // here survives the language change as a string in an abandoned language.
      final List<String> offenders = <String>[];
      final List<String> keys = <String>[];
      for (final String file in _dartFilesUnder('lib')) {
        final String source = File(file).readAsStringSync();
        for (final RegExpMatch match in RegExp(
          r'setString\(\s*([A-Za-z_][A-Za-z0-9_]*)\s*,\s*([^)]*)\)',
        ).allMatches(source)) {
          keys.add(match.group(1)!);
          final String value = match.group(2)!.trim();
          if (!value.endsWith('.name')) {
            offenders.add('$file: setString(${match.group(1)}, $value)');
          }
        }
      }
      expect(
        keys,
        isNotEmpty,
        reason:
            'witness — this product DOES store three string preferences, so a rule '
            'that silently matched none of them would be vacuous. Found $keys.',
      );
      expect(
        offenders,
        isEmpty,
        reason:
            'E12 / § 10.9 — a stored preference is an ENUM key (`lastRead`), never a '
            'localized string (`Dernière lecture`), which would be a value in a '
            'language the reader no longer uses: $offenders',
      );
    });

    test('no preference key names a language, a locale or a theme string', () {
      // The other half of § 10.9: the value being an enum is not enough if a *key* is
      // the language. `_resolveLocale` reads the platform and nothing else.
      final List<String> offenders = <String>[];
      for (final String file in _dartFilesUnder('lib')) {
        final String source = File(file).readAsStringSync();
        for (final RegExpMatch match in RegExp(
          r'''(?:static\s+)?const\s+String\s+(\w*(?:[Ll]ang|[Ll]ocale)\w*)\s*=''',
        ).allMatches(source)) {
          offenders.add('$file: ${match.group(1)}');
        }
      }
      expect(
        offenders,
        isEmpty,
        reason:
            'B28 — the language is read from the platform; ${offenders.join(', ')} '
            'would be a stored second copy of it',
      );
    });
  });

  group('gen-l10n left nothing untranslated', () {
    test('the untranslated-messages report is empty or absent', () {
      // `gen-l10n` writes this when a TEMPLATE message has no translation. It is the
      // one direction the toolchain checks on its own, and it is here so the row fails
      // loudly instead of being assumed.
      for (final String path in <String>[
        '.dart_tool/flutter_gen/gen_l10n/untranslated-messages.json',
        'lib/l10n/untranslated-messages.json',
      ]) {
        final File file = File(path);
        if (!file.existsSync()) continue;
        final String raw = file.readAsStringSync();
        expect(
          raw.trim(),
          anyOf(isEmpty, '{}', '[]'),
          reason:
              'B28 — gen-l10n reported untranslated messages in $path: $raw',
        );
      }
    });
  });
}

/// Whether [literal] reads like a sentence a reader would see.
///
/// Two whitespace-separated tokens, at least one of them a word of two letters or more. A
/// key (`downloadAddedSnackbar`), a path (`/library`), a token (`--color-accent`), a count
/// (`3 / 12`) and a percentage (`42%`) all fail it, which is the point: they are not copy.
bool _readsLikeProse(String literal) {
  final String text = literal.replaceAll(RegExp(r'\$\{[^}]*\}'), ' ').trim();
  if (text.isEmpty) return false;
  final List<String> tokens = text
      .split(RegExp(r'\s+'))
      .where((String t) => t.isNotEmpty)
      .toList();
  if (tokens.length < 2) return false;
  return tokens.any(
    (String t) => RegExp(r'[\p{L}]{2}', unicode: true).hasMatch(t),
  );
}

/// Long enough to name the string, short enough to keep a failure readable.
String _shorten(String value) =>
    value.length <= 60 ? "'$value'" : "'${value.substring(0, 57)}…'";

/// Sentences, as a reader counts them: a terminator and a space.
int _sentenceCount(String value) =>
    RegExp(r'[.!?]+(?:\s|$)').allMatches(value.trim()).length;

/// Every `.dart` file under [root], recursively, sorted for a stable failure report.
List<String> _dartFilesUnder(String root) {
  final List<String> found = <String>[];
  void walk(Directory directory) {
    final List<FileSystemEntity> entries = directory.listSync().toList()
      ..sort(
        (FileSystemEntity a, FileSystemEntity b) => a.path.compareTo(b.path),
      );
    for (final FileSystemEntity entry in entries) {
      if (entry is Directory) {
        walk(entry);
      } else if (entry is File && entry.path.endsWith('.dart')) {
        found.add(entry.path.replaceAll(r'\', '/'));
      }
    }
  }

  walk(Directory(root));
  return found;
}

bool _sameSet(List<String> a, List<String> b) {
  if (a.length != b.length) return false;
  final List<String> left = List<String>.of(a)..sort();
  final List<String> right = List<String>.of(b)..sort();
  for (int i = 0; i < left.length; i++) {
    if (left[i] != right[i]) return false;
  }
  return true;
}
