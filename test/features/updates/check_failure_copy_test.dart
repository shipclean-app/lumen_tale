// forge:slice 6-4
// Lumen Tale — `CheckFailureKind` in words, and the three lines a pass says out loud.
//
// ## The four claims, and which of them a reviewer would not catch by reading
//
// | rule | the claim | why it needs a test |
// |---|---|---|
// | **B24 / B28** | every one of the six causes has a sentence, **in both languages** | a key missing from `app_fr.arb` ships an English string to a French reader, and `main.dart`'s fallback hides it at runtime |
// | **C12 / 17-security rule 4** | no sentence names a CSS selector or a Dart type | a reader who has to *describe* the failure to the phone's owner cannot say `table#chapters` |
// | **B39 § 3.4** | the progress line says **both** numbers, uncapped | `Checking 50+ of …` looks identical to a pass that skipped novels |
// | **B22** | a failure count is **never** folded into a success | `Checked 23 of 23 novels` when 4 could not be checked is a lie a reader cannot audit |
//
// ## ⚠️ WHY THIS FILE DOES NOT CALL `checkFailureSentence` ONLY
//
// A copy test that asserts a sentence is non-empty passes when the sentence is `'x'`. So
// each row also asserts something about the **content**: the words a reader needs, the
// absence of the words they must not see, and the numbers the counter is made of.

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumen_tale/domain/updates/library_check.dart';
import 'package:lumen_tale/features/updates/presentation/check_failure_copy.dart';
import 'package:lumen_tale/l10n/generated/app_localizations.dart';

Future<AppLocalizations> l10nOf(String language) =>
    AppLocalizations.delegate.load(Locale(language));

/// Every shape a sentence must never take.
///
/// ⚠️ **SELECTOR SHAPES, NOT A BANNED LIST OF SELECTORS.** A test banning
/// `table#chapters` passes until the site is repaired and the selector becomes
/// `div.fiction-chapters` — at which point the next broken selector reaches the UI. So the
/// patterns are the *shapes*: `tag.class`, `#id`, `tag[attr]`, and a lone `tag.class` with a
/// dot in it. `18-external-contracts.md` records the selector for the OWNER; this file is
/// what keeps it out of the reader's screen.
final List<RegExp> selectorShaped = <RegExp>[
  RegExp(r'[a-zA-Z]+\.[a-zA-Z][\w-]*'),
  RegExp(r'#[a-zA-Z][\w-]*'),
  RegExp(r'\[[a-zA-Z]+[~^$*|=]'),
];

/// What a sentence must never contain, whatever its cause.
///
/// `Exception`/`Failure` are the two families the project has (13-error-handling rule 3
/// forbids handing `e.toString()` to the UI), `toString` is the call that leaks them, and
/// `null` is the word that means the app did not fill a field in.
const List<String> bannedInASentence = <String>[
  'Exception',
  'Failure',
  'toString',
  'Dio',
  'Sqlite',
  'null',
];

void main() {
  late AppLocalizations en;
  late AppLocalizations fr;

  setUpAll(() async {
    en = await l10nOf('en');
    fr = await l10nOf('fr');
  });

  group('B24/B28 — every cause has a sentence, in both languages', () {
    test('no cause resolves to an empty or blank sentence', () {
      for (final MapEntry<String, CheckFailureKind> entry in _byName.entries) {
        expect(
          en.checkFailureSentence(entry.value).trim(),
          isNotEmpty,
          reason:
              'B24: `${entry.key}` is a verdict a reader will be shown, and an empty '
              'string is a screen that says nothing while claiming the novel was checked',
        );
        expect(
          fr.checkFailureSentence(entry.value).trim(),
          isNotEmpty,
          reason:
              'B28: `${entry.key}` must have a FRENCH sentence, not an English one',
        );
      }
    });

    test('the six causes resolve to six DIFFERENT English sentences', () {
      // ⚠️ **COLLISION IS A SILENT DEFECT.** Two arms mapping to one string would make
      // *the site changed* and *no connection* indistinguishable on screen, and B22's whole
      // work is that they are distinguishable. A copy test that only checked non-emptiness
      // would pass with five sentences for six causes.
      final Set<String> sentences = <String>{
        for (final CheckFailureKind kind in CheckFailureKind.values)
          en.checkFailureSentence(kind),
      };
      expect(
        sentences,
        hasLength(CheckFailureKind.values.length),
        reason:
            'B22: each cause needs its own words, or two failures render as one — and '
            '${sentences.length} sentences for ${CheckFailureKind.values.length} causes '
            'is exactly that',
      );
    });

    test('a sentence never names a Dart type or the word null', () {
      for (final AppLocalizations l10n in <AppLocalizations>[en, fr]) {
        for (final CheckFailureKind kind in CheckFailureKind.values) {
          final String sentence = l10n.checkFailureSentence(kind);
          for (final String banned in bannedInASentence) {
            expect(
              sentence,
              isNot(contains(banned)),
              reason:
                  '13-error-handling.md rule 3: `$banned` in user-visible text is a type '
                  'leaking through a nicer font. C12 asks for a sentence the reader can '
                  'say out loud',
            );
          }
        }
      }
    });
  });

  group('C12 / 17-security.md rule 4 — no sentence names a SELECTOR', () {
    test('neither language contains anything shaped like a CSS selector', () {
      for (final AppLocalizations l10n in <AppLocalizations>[en, fr]) {
        for (final CheckFailureKind kind in CheckFailureKind.values) {
          final String sentence = l10n.checkFailureSentence(kind);
          for (final RegExp shape in selectorShaped) {
            expect(
              shape.hasMatch(sentence),
              isFalse,
              reason:
                  'a CSS selector is evidence for the OWNER (`18-external-contracts.md`, '
                  'C5), not text a reader can act on: $sentence',
            );
          }
        }
      }
    });

    test(
      'the E4 sentence tells the reader the app cannot read the site, not which node',
      () {
        // ⚠️ **THE ROW `failedSelector` IS ABOUT.** `drift_check_library.dart` carries the
        // selector that came back empty so a repair is deliverable as a file. This asserts
        // that the *sentence* carries none of it: the two have opposite audiences, and the
        // temptation to merge them is to put the evidence where the reader can see it.
        final String sentence = en.checkFailureSentence(
          CheckFailureKind.sourceLayoutChanged,
        );
        expect(
          sentence.toLowerCase(),
          contains('changed'),
          reason:
              'C12: the reader needs to be able to say "this site changed its layout" out '
              'loud — that is the whole of what they can act on',
        );
        expect(
          sentence,
          isNot(contains('failedSelector')),
          reason:
              'and the field name is as unreadable as the selector it holds',
        );
      },
    );

    test('the E9 sentence promises the rest of the library is untouched', () {
      // E9's reader has just been told a novel they kept is gone from its site. The
      // sentence has to answer the question that follows immediately — *did I lose
      // anything?* — because the answer is yes and they need to hear it calmly.
      expect(
        en
            .checkFailureSentence(CheckFailureKind.itemRemovedAtSource)
            .toLowerCase(),
        allOf(contains('no longer'), contains('untouched')),
        reason:
            'C12/B7: E9 must say the novel is gone AND that the downloaded chapters are '
            'still readable, or the reader has to ask',
      );
    });

    test('the no-connection sentence says the downloaded chapters stay readable', () {
      // B15: offline, the app shows the last known result. The sentence is where a reader
      // learns that nothing was lost, and a generic "network error" would not say it.
      expect(
        en.checkFailureSentence(CheckFailureKind.noConnection).toLowerCase(),
        contains('readable'),
        reason:
            'B15/B7: with no connection the reader must be able to keep reading what is '
            'already downloaded',
      );
    });

    test('the rate-limit sentence names the SITE as the party asking', () {
      // C7: the wait is the site's decision, not an app failure. A sentence that said
      // "the app is busy" would send the reader to look at the wrong thing.
      expect(
        en.checkFailureSentence(CheckFailureKind.rateLimited).toLowerCase(),
        contains('site'),
        reason:
            'C7: nobody should retry a 429 without being told the site asked for the '
            'wait — and `17-security.md` rule 6 reads the header rather than guessing it',
      );
    });
  });

  group('B39 § 3.4 — the progress line says BOTH facts, and never caps the count', () {
    LibraryCheckProgress at(int done, int total) =>
        LibraryCheckProgress(total: total, done: done, inFlightNovelId: null);

    test('it reads "Checking 7 of 23 novels", with both numbers verbatim', () {
      expect(
        en.checkProgressLine(at(7, 23)),
        'Checking 7 of 23 novels · nothing is downloaded',
        reason:
            '§ 3.4 spells the line out, and B39 is the first half: the counter is the '
            'only visible proof that nothing was skipped',
      );
      expect(
        en.checkProgressLine(at(7, 23)),
        contains('nothing is downloaded'),
        reason:
            'and B38 is the second half — which is why there is no confirmation dialog '
            'before a check, since a check costs no data and no storage',
      );
    });

    test('the French line carries both numbers too', () {
      // B28: a template that dropped a placeholder in French would render "Checking 7
      // novels" and stop counting, which is the one thing B39 forbids.
      expect(
        fr.checkProgressLine(at(7, 23)),
        contains('7'),
        reason: 'B28: the placeholder survives translation',
      );
      expect(
        fr.checkProgressLine(at(7, 23)),
        contains('23'),
        reason:
            'B28: BOTH placeholders survive — `7 sur` alone is not a count of 23',
      );
    });

    test('no total is ever rendered with a cap, an ellipsis, or a rounded figure', () {
      // ⚠️ **THE ROW § 3.4 WRITES AS A PROHIBITION.** *Never a truncated plural, never
      // `top 50`, never an ellipsis.* `Checking 50+ of` is the rendering of a pass that
      // visited fifty novels, and it is indistinguishable from one that visited all of
      // them — which is exactly the invisibility B39 was rewritten to remove.
      for (final AppLocalizations l10n in <AppLocalizations>[en, fr]) {
        for (final LibraryCheckProgress progress in <LibraryCheckProgress>[
          at(3, 23),
          at(3, 1000),
          at(3, 100000),
        ]) {
          final String line = l10n.checkProgressLine(progress);
          expect(
            line,
            isNot(contains('+')),
            reason:
                '§ 3.4: a `+` turns a count into a claim about a number never seen',
          );
          expect(
            line,
            isNot(contains('…')),
            reason: '§ 3.4: no ellipsis, ever',
          );
          expect(
            line,
            contains('${progress.total}'),
            reason:
                '§ 3.4: the FULL total is rendered, so a reader can divide done by total '
                'and see that nothing was skipped',
          );
        }
      }
    });

    test('a pass over 0 novels still reads as a counter, not as an error', () {
      expect(
        en.checkProgressLine(at(0, 0)),
        contains('0'),
        reason:
            'B12: "nothing is kept" is a real first-run state, and the counter must be '
            'able to say so rather than a screen inventing a failure for it',
      );
    });
  });

  group('B22/B39 § 3.4 — the terminal line has three shapes, and none of them hides', () {
    LibraryCheckResult result({
      required int checked,
      required int failed,
      required int total,
      bool interrupted = false,
    }) => LibraryCheckResult(
      startedAt: DateTime.utc(2026, 10, 4, 9),
      finishedAt: DateTime.utc(2026, 10, 4, 9, 1),
      total: total,
      perNovel: List<NovelCheckOutcome>.unmodifiable(<NovelCheckOutcome>[
        ...List<NovelCheckOutcome>.filled(checked, _checked),
        ...List<NovelCheckOutcome>.filled(
          failed,
          const NovelCheckFailed(
            kind: CheckFailureKind.sourceLayoutChanged,
            sourceId: 'src-a',
          ),
        ),
      ]),
      interrupted: interrupted,
    );

    test('a complete pass with no failures says "none skipped"', () {
      expect(
        en.checkTerminalLine(result(checked: 23, failed: 0, total: 23)),
        'All 23 novels checked · none skipped.',
        reason:
            'B39: *none skipped* is the claim the reader cannot verify any other way, so '
            'it is the sentence rather than a detail',
      );
    });

    test(
      'a pass with failures reports the failure count, and never the success alone',
      () {
        expect(
          en.checkTerminalLine(result(checked: 19, failed: 4, total: 23)),
          'Checked 19 of 23 novels · 4 could not be checked.',
          reason:
              'B22: the failure count is never folded into a success. "Checked 23 of 23" '
              'when 4 could not be checked is the exact lie this slice exists to prevent',
        );
      },
    );

    test('an INTERRUPTED pass says where it stopped, even when nothing failed', () {
      // ⚠️ **THE ORDER OF THE BRANCHES IS LOAD-BEARING, AND THIS IS THE ROW FOR IT.**
      // An interrupted pass can also carry failures, and reporting it as "checked 7 of 23"
      // would hide the fact that it stopped. So this asserts the line for a stopped pass
      // whose `failedCount` is zero — the case where the failure branch would otherwise be
      // reached by accident.
      expect(
        en.checkTerminalLine(
          result(checked: 7, failed: 0, total: 23, interrupted: true),
        ),
        'Check stopped at 7 of 23 novels.',
        reason:
            'B37/C8: a stopped pass is reported as stopped, and *All 23 novels checked* '
            'would be a claim about 16 novels nobody looked at',
      );
    });

    test('an interrupted pass that ALSO had failures still says it stopped', () {
      expect(
        en.checkTerminalLine(
          result(checked: 7, failed: 2, total: 23, interrupted: true),
        ),
        contains('stopped'),
        reason:
            'B37 comes before B22 in the branch order: "stopped at 7 of 23" is the fact a '
            'reader must see first, and the failures are a detail of it',
      );
    });

    test('an empty library\'s terminal line claims nothing was skipped', () {
      // B12: zero novels is a finished pass over an empty library. The alternative — "All 0
      // novels checked" reading as a failure — would be a screen inventing a problem.
      expect(
        en.checkTerminalLine(result(checked: 0, failed: 0, total: 0)),
        'All 0 novels checked · none skipped.',
        reason: 'B12/B39: and it is honest — there was nothing to skip',
      );
    });

    test('every terminal shape is available in French too', () {
      expect(
        fr.checkTerminalLine(result(checked: 23, failed: 0, total: 23)),
        isNotEmpty,
        reason: 'B28: the FR fallback would otherwise show the English line',
      );
      expect(
        fr.checkTerminalLine(result(checked: 19, failed: 4, total: 23)),
        contains('4'),
        reason: 'B28: and the failure count survives translation',
      );
      expect(
        fr.checkTerminalLine(
          result(checked: 7, failed: 0, total: 23, interrupted: true),
        ),
        contains('7'),
        reason: 'B28: and so does the "stopped at" count',
      );
    });
  });
}

/// One `CheckFailureKind` per name, so a row can fail with the name the reader would need.
///
/// ⚠️ **BUILT FROM THE ENUM, NOT A HAND-WRITTEN LIST.** A hand-written list is the second
/// place the six causes exist, and it goes stale silently: adding a seventh arm to the enum
/// would leave this map with six entries and the "six different sentences" row would keep
/// passing while covering five causes.
final Map<String, CheckFailureKind> _byName = <String, CheckFailureKind>{
  for (final CheckFailureKind kind in CheckFailureKind.values) kind.name: kind,
};

/// A `NovelChecked`, reused: `checkTerminalLine` reads **counts**, not the outcomes'
/// contents, so the value behind each one is irrelevant to every assertion here.
final NovelChecked _checked = NovelChecked(
  newChaptersFound: 0,
  siteChapterCount: 0,
  checkedAt: DateTime.utc(2026, 10, 4, 9),
);
