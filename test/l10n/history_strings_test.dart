// Lumen Tale — `6-5`'s copy, and the two things a translation table can silently get wrong.
//
// B28 demands **every** user-visible string in French and English. `arb_completeness_test`
// already proves the two files carry the same keys and that each resolves; this file
// covers the two properties that are specific to this screen's vocabulary and that a
// parity check cannot see:
//
//  1. **The five window names are DATA, and the enum is the truth.** Each window has a
//     *duration* (`HistoryRetention.window`) and a *string* a reader reads. Two
//     representations of one window, free to disagree — and a test that compares the
//     string against the enum's member count catches a sixth window nobody translated.
//  2. **The placeholders are the ones the sentences actually read.** A key that takes
//     `{window}` must render a **localized** window name, never the enum's member name,
//     because `threeMonths` in a French sentence is a string the app learned from its
//     own code.

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumen_tale/domain/history/history_retention.dart';
import 'package:lumen_tale/l10n/generated/app_localizations.dart';

/// Every window, and the sentence a reader reads for it in each language.
const Map<HistoryRetention, Map<String, String>> windowNames =
    <HistoryRetention, Map<String, String>>{
      HistoryRetention.oneWeek: <String, String>{
        'en': 'one week',
        'fr': 'une semaine',
      },
      HistoryRetention.oneMonth: <String, String>{
        'en': 'one month',
        'fr': 'un mois',
      },
      HistoryRetention.threeMonths: <String, String>{
        'en': 'three months',
        'fr': 'trois mois',
      },
      HistoryRetention.oneYear: <String, String>{
        'en': 'one year',
        'fr': 'un an',
      },
      HistoryRetention.twoYears: <String, String>{
        'en': 'two years',
        'fr': 'deux ans',
      },
    };

Future<AppLocalizations> l10nOf(Locale locale) =>
    AppLocalizations.delegate.load(locale);

void main() {
  late AppLocalizations en;
  late AppLocalizations fr;

  setUpAll(() async {
    en = await l10nOf(const Locale('en'));
    fr = await l10nOf(const Locale('fr'));
  });

  group('the five windows', () {
    test('the enum has exactly five members and the table has five entries', () {
      // ⚠️ **The row that catches a sixth window.** B47 bounds the journal by time, and
      // `design-system.md` § 2.12 forbids a "forever" option on any bounded list — so a
      // new member has to be a *deliberate* widening, not something a screen invents
      // and then cannot translate.
      expect(HistoryRetention.values, hasLength(5));
      expect(windowNames, hasLength(5));
      for (final HistoryRetention window in HistoryRetention.values) {
        expect(
          windowNames.containsKey(window),
          isTrue,
          reason:
              '${window.name} has no entry in the table, so no sentence can name it',
        );
      }
    });

    test('every window has a non-empty name in both languages', () {
      for (final HistoryRetention window in HistoryRetention.values) {
        for (final AppLocalizations l10n in <AppLocalizations>[en, fr]) {
          expect(
            windowNames[window]![l10n.localeName]!.trim(),
            isNotEmpty,
            reason: '${window.name} in ${l10n.localeName}',
          );
        }
      }
    });

    test('no two windows share a name in either language', () {
      for (final String locale in <String>['en', 'fr']) {
        final Set<String> names = <String>{
          for (final HistoryRetention window in HistoryRetention.values)
            windowNames[window]![locale]!,
        };
        expect(
          names,
          hasLength(5),
          reason: 'two windows read identically in $locale',
        );
      }
    });

    test('the default window is one year, and its strings say so', () {
      // `HistoryRetention.defaultWindow` is the authority; these strings are what a
      // reader reads. Asserting the pair together is what stops the two representations
      // from drifting.
      expect(HistoryRetention.defaultWindow, HistoryRetention.oneYear);
      expect(windowNames[HistoryRetention.defaultWindow]!['en'], 'one year');
      expect(windowNames[HistoryRetention.defaultWindow]!['fr'], 'un an');
    });

    test('the names are in English for English and in French for French', () {
      // A copied-paste that leaves an English string in the French file passes every
      // non-emptiness check. It is the failure a reader on a borrowed device meets.
      for (final HistoryRetention window in HistoryRetention.values) {
        expect(
          windowNames[window]!['en'],
          isNot(windowNames[window]!['fr']),
          reason:
              '${window.name} reads identically in both languages — an English string '
              'left in the French table',
        );
      }
    });
  });

  group('the sentences that carry a window', () {
    test('the terminal line renders the window, not the enum name', () {
      // ⚠️ `{window}` must be a **localized** name. `threeMonths` in a French sentence
      // is a string the app learned from its own code, and a reader who sees it learns
      // nothing about how long their history lasts.
      for (final MapEntry<Locale, AppLocalizations> pair
          in <Locale, AppLocalizations>{
            const Locale('en'): en,
            const Locale('fr'): fr,
          }.entries) {
        for (final HistoryRetention window in HistoryRetention.values) {
          final String rendered = pair.value.historyTerminalLine(
            windowNames[window]![pair.key.languageCode]!,
          );
          expect(
            rendered,
            contains(windowNames[window]![pair.key.languageCode]!),
          );
          expect(
            rendered,
            isNot(contains(window.name)),
            reason:
                '${window.name} leaked its Dart name into ${pair.key.languageCode}',
          );
        }
      }
    });

    test('the sheet warning renders the window too', () {
      expect(
        fr.historySheetWarning(
          windowNames[HistoryRetention.threeMonths]!['fr']!,
        ),
        contains('trois mois'),
      );
      expect(
        en.historySheetWarning(
          windowNames[HistoryRetention.threeMonths]!['en']!,
        ),
        contains('three months'),
      );
    });

    test('the success snackbar names the new window', () {
      // "A screen saying 'one year' in the notice and 'three months' in the snackbar is
      // two lies" — so the snackbar carries it rather than saying "the window changed".
      expect(
        en.historySnackWindowChanged('three months'),
        contains('three months'),
      );
      expect(
        fr.historySnackWindowChanged('trois mois'),
        contains('trois mois'),
      );
    });

    test('an empty placeholder does not leave braces behind', () {
      // The cheap end of the placeholder contract: whatever the caller passes, the
      // sentence has no `{window}` in it. A raw `{` surviving into a sentence is a
      // template that was never filled, and it is visible.
      for (final AppLocalizations l10n in <AppLocalizations>[en, fr]) {
        for (final String rendered in <String>[
          l10n.historyTerminalLine('one year'),
          l10n.historySheetWarning('one year'),
          l10n.historySnackWindowChanged('one year'),
        ]) {
          expect(rendered, isNot(contains('{')), reason: rendered);
          expect(rendered, isNot(contains('}')), reason: rendered);
        }
      }
    });
  });

  group('the clear confirmation — B46 in one sentence', () {
    test('every plural form renders, and each carries the survival promise', () {
      for (final AppLocalizations l10n in <AppLocalizations>[en, fr]) {
        for (final int count in <int>[0, 1, 2, 96, 1000]) {
          final String rendered = l10n.historyClearDialogBody(count);
          expect(rendered, isNot(contains('{')));
          // The promise is the part that matters, and it must survive every count.
          if (l10n.localeName == 'fr') {
            expect(rendered, contains('conservés'), reason: 'count $count');
          } else {
            expect(rendered, contains('kept'), reason: 'count $count');
          }
        }
      }
    });

    test('the count appears, so the reader knows the scope before agreeing', () {
      // "Your 96 entries will be removed" — a dialog that says *entries will be removed*
      // without a number is asking for consent to an unbounded act.
      expect(en.historyClearDialogBody(96), contains('96'));
      expect(fr.historyClearDialogBody(96), contains('96'));
    });

    test('zero reads as zero rather than as a missing number', () {
      expect(en.historyClearDialogBody(0), isNot(contains('0 ')));
      expect(en.historyClearDialogBody(0), contains('No entries'));
    });

    test('the destructive button says what it does, in full', () {
      // Never 'OK', never 'Delete'. A button that asks a reader to trust a process
      // they have just been told nothing about is the failure B46 is adjacent to.
      expect(en.historyClearDialogConfirm, 'Clear history');
      expect(fr.historyClearDialogConfirm, 'Effacer l\'historique');
      expect(en.historyClearDialogConfirm.toLowerCase(), isNot('ok'));
      expect(en.historyClearDialogConfirm.toLowerCase(), isNot('delete'));
    });

    test('the cancel path is named, not implied', () {
      expect(en.commonCancel, 'Cancel');
      expect(fr.commonCancel, 'Annuler');
    });
  });

  group('the two empty states are different sentences', () {
    test('cleared-by-the-reader and aged-out do not share a title', () {
      // `history.md` § 4 splits this state because being cleared BY THE READER and
      // being AGED OUT are different events with different emotional weight. Merged,
      // one of them becomes a lie.
      expect(en.historyClearedTitle, isNot(en.historyAgedOutTitle));
      expect(fr.historyClearedTitle, isNot(fr.historyAgedOutTitle));
    });

    test('and never-visited is a third distinct title', () {
      expect(en.historyEmptyTitle, isNot(en.historyClearedTitle));
      expect(en.historyEmptyTitle, isNot(en.historyAgedOutTitle));
      expect(fr.historyEmptyTitle, isNot(fr.historyClearedTitle));
    });

    test('both empty-no-data states say what SURVIVED', () {
      // An empty list after a destructive action that says nothing is the moment a
      // reader goes looking for what else just disappeared.
      expect(en.historyClearedBody, contains('kept'));
      expect(en.historyAgedOutBody, contains('kept'));
      expect(fr.historyClearedBody, contains('conservés'));
      expect(fr.historyAgedOutBody, contains('conservées'));
    });

    test(
      'both empty actions exist and differ, because the library state differs',
      () {
        // The empty state's action depends on a LOCAL FACT: *Browse a source* when the
        // library is empty, *Open your library* when it is not. A fixed string would point
        // at a library the reader does not have.
        expect(
          en.historyEmptyActionBrowse,
          isNot(en.historyEmptyActionLibrary),
        );
        expect(
          fr.historyEmptyActionBrowse,
          isNot(fr.historyEmptyActionLibrary),
        );
      },
    );
  });

  group('B46, four times', () {
    test(
      'the survival promise is stated in the notice, the dialog, the cleared state and the error',
      () {
        // `history.md` § 9: B46 "repeated in the clear confirmation, repeated in the
        // cleared state, repeated in the store-failure sentence". Four places, because it
        // is the thing a reader on a device with no backup is actually afraid of.
        expect(en.historyNoticeBody, contains('never moves'));
        expect(en.historyClearedBody, contains('kept'));
        expect(en.historyClearDialogBody(3), contains('kept'));
        expect(en.historyLoadErrorBody, contains('unaffected'));
      },
    );

    test('the load error names three survivals, because the fear is data loss', () {
      // "Your library, your downloaded chapters and every remembered reading position
      // are unaffected" — three, by name. This app has no backup (ADR-010), so
      // promising the survivals is the only thing that stops the reader assuming the
      // worst.
      expect(en.historyLoadErrorBody, contains('library'));
      expect(en.historyLoadErrorBody, contains('downloaded'));
      expect(en.historyLoadErrorBody, contains('position'));
    });
  });

  group('no sentence leaks a class name, an enum name, or a path', () {
    test('nothing here says Dart', () {
      final List<String> sentences = <String>[
        for (final AppLocalizations l10n in <AppLocalizations>[
          en,
          fr,
        ]) ...<String>[
          l10n.historyTitle,
          l10n.historyEmptyTitle,
          l10n.historyEmptyBody,
          l10n.historyClearedTitle,
          l10n.historyClearedBody,
          l10n.historyAgedOutTitle,
          l10n.historyAgedOutBody,
          l10n.historyLoadErrorTitle,
          l10n.historyLoadErrorBody,
          l10n.historyNoticeTitle,
          l10n.historyNoticeBody,
          l10n.historyRetentionLabel,
          l10n.historyRetentionChange,
          l10n.historyClearAction,
          l10n.historyClearDialogTitle,
          l10n.historyClearDialogConfirm,
          l10n.historySheetTitle,
          l10n.historySheetWarningNone,
          l10n.historySnackCleared,
          l10n.historySnackNotCleared,
          l10n.historyUntitledChapter,
          l10n.historyUntitledNovel,
        ],
      ];
      for (final String sentence in sentences) {
        for (final String banned in <String>[
          'HistoryRetention',
          'oneYear',
          'threeMonths',
          'twoYears',
          'AsyncValue',
          'Exception',
          'context.',
        ]) {
          expect(
            sentence,
            isNot(contains(banned)),
            reason: '"$banned" reached a reader: $sentence',
          );
        }
      }
    });

    test('no sentence contains a path or a URL', () {
      // B44 / C5. The journal holds ids and counts; a title is site text and a path is
      // never a thing to show.
      for (final AppLocalizations l10n in <AppLocalizations>[en, fr]) {
        for (final String sentence in <String>[
          l10n.historyNoticeBody,
          l10n.historyLoadErrorBody,
          l10n.historyTerminalLine('one year'),
          l10n.historySnackCleared,
        ]) {
          expect(sentence, isNot(contains('/')));
          expect(sentence, isNot(contains('http')));
        }
      }
    });
  });
}
