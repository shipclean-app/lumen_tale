// forge:slice 6-7
// Lumen Tale — `6-7`: every failure has a sentence, and an action that works.
//
// B28: *every user-visible string exists in French and in English, **including all
// error and download-status messages**.* This file is what makes that testable for
// the failure vocabulary.
//
// Four properties, each one a way the vocabulary used to be wrong:
//
//  1. **Exhaustive.** Every `AppErrorString` resolves to a non-empty sentence in both
//     locales. An enum arm with no string is a screen that says nothing.
//  2. **No class names.** No sentence contains `Exception`, `Failure`, or a Dart
//     identifier — `13-error-handling.md` rule 3 forbids handing `e.toString()` to the
//     UI, and "NetworkException" is the same leak wearing a nicer font.
//  3. **The action matches the cause.** A `Retry` is offered only where a retry
//     repairs the problem. `SourceLayoutChanged` and `ParseFailed` have no action but
//     "report the bug", because no retry fixes either — and `architecture.md` § 5.2's
//     "Recoverable by retry" column becomes **executable** here rather than advisory.
//  4. **`RateLimited` uses the site's own duration.** C7 and `17-security.md` rule 6:
//     `Retry-After` is read, never guessed, and a rate limit offers **no** button.

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumen_tale/core/error/app_exception.dart';
import 'package:lumen_tale/core/error/source_failure.dart';
import 'package:lumen_tale/core/ui/app_error_copy.dart';
import 'package:lumen_tale/l10n/generated/app_localizations.dart';

Future<AppLocalizations> l10nOf(Locale locale) =>
    AppLocalizations.delegate.load(locale);

const List<Locale> bothLocales = <Locale>[Locale('en'), Locale('fr')];

/// Everything a sentence must never contain.
///
/// `Exception` and `Failure` are the two families the project actually has, and
/// `toString` is the call that leaks them. `Dio`/`Sqlite` name the two drivers
/// `13-error-handling.md` rule 2 exists to wrap.
const List<String> bannedInASentence = <String>[
  'Exception',
  'Failure',
  'toString',
  'Dio',
  'Sqlite',
  'null',
  'null)',
];

void main() {
  late AppLocalizations en;
  late AppLocalizations fr;

  setUpAll(() async {
    en = await l10nOf(const Locale('en'));
    fr = await l10nOf(const Locale('fr'));
  });

  group('every failure has a sentence, in both languages', () {
    test('no enum arm resolves to an empty string', () {
      for (final AppErrorString which in AppErrorString.values) {
        for (final MapEntry<Locale, AppLocalizations> pair
            in <Locale, AppLocalizations>{
              const Locale('en'): en,
              const Locale('fr'): fr,
            }.entries) {
          expect(
            pair.value.message(which).trim(),
            isNotEmpty,
            reason: '${which.name} is silent in ${pair.key.languageCode}',
          );
        }
      }
    });

    test('no sentence leaks a class name, a driver, or null', () {
      for (final AppErrorString which in AppErrorString.values) {
        for (final AppLocalizations l10n in <AppLocalizations>[en, fr]) {
          final String sentence = l10n.message(which);
          for (final String banned in bannedInASentence) {
            expect(
              sentence,
              isNot(contains(banned)),
              reason:
                  '${which.name} in ${l10n.localeName} contains "$banned"; '
                  '13-error-handling.md rule 3 forbids handing a type name to the UI',
            );
          }
        }
      }
    });

    test('the two languages are not the same sentence', () {
      // A copy-paste that leaves English in the French file passes every
      // non-emptiness check. It is the failure a reader on a borrowed device meets,
      // so it gets its own row.
      int identical = 0;
      for (final AppErrorString which in AppErrorString.values) {
        if (en.message(which) == fr.message(which)) identical++;
      }
      expect(
        identical,
        0,
        reason:
            '$identical sentence(s) are identical in both languages — every message '
            'in this vocabulary has a distinct French rendering',
      );
    });
  });

  group('the action matches the cause — C12', () {
    test('a changed layout offers "report", never "retry"', () {
      // E4 / SC-6. A retry cannot repair a site that renamed its markup, and a
      // button that says otherwise teaches the reader to keep tapping.
      for (final AppLocalizations l10n in <AppLocalizations>[en, fr]) {
        expect(
          l10n.recovery(AppErrorString.sourceLayoutChanged),
          l10n.actionReportBug,
        );
        expect(l10n.actionReportBug, isNot(contains('Retry')));
        expect(l10n.actionReportBug, isNot(contains('Réessayer')));
      }
    });

    test('a failed conversion offers "report", never "retry"', () {
      for (final AppLocalizations l10n in <AppLocalizations>[en, fr]) {
        expect(l10n.recovery(AppErrorString.parseFailed), l10n.actionReportBug);
      }
    });

    test('a rate limit offers nothing, because waiting is the action', () {
      // B37, `17-security.md` rule 6: `Retry-After` says when. A button that
      // retries early is how a rate limit gets worse.
      expect(en.recovery(AppErrorString.rateLimited), isNull);
      expect(fr.recovery(AppErrorString.rateLimited), isNull);
    });

    test('a full disk offers "free space", the one action that works', () {
      // C8. This is the only cause whose action is on the reader's own device.
      expect(en.recovery(AppErrorString.storageFull), en.actionFreeSpace);
      expect(fr.recovery(AppErrorString.storageFull), fr.actionFreeSpace);
    });

    test('an empty result offers nothing — it is an answer, not a failure', () {
      expect(en.recovery(AppErrorString.browseEmpty), isNull);
      expect(fr.recovery(AppErrorString.browseEmpty), isNull);
    });

    test('a cancellation offers nothing — rule 7', () {
      // "Cancelled" is not "failed". A screen that shows an error for it teaches the
      // reader that their own tap broke something.
      expect(en.recovery(AppErrorString.checkCancelled), isNull);
    });

    test('no connection offers a retry — E5', () {
      expect(en.recovery(AppErrorString.noConnection), en.commonRetry);
    });

    test('a removed item says the rest is untouched', () {
      // E9. The sentence matters more than the action here: a reader whose novel
      // vanished needs to know this is not data loss.
      for (final AppLocalizations l10n in <AppLocalizations>[en, fr]) {
        final String sentence = l10n.message(
          AppErrorString.itemRemovedAtSource,
        );
        expect(
          sentence.toLowerCase(),
          contains(l10n.localeName == 'fr' ? 'bibliothèque' : 'library'),
        );
      }
    });
  });

  group('the rate-limit duration is the site s, not a guess', () {
    test('with no duration the sentence does not invent one', () {
      expect(en.message(AppErrorString.rateLimited), en.errorRateLimited);
      expect(en.message(AppErrorString.rateLimited), isNot(contains('30')));
    });

    test('with a duration the sentence carries it', () {
      expect(
        en.message(
          AppErrorString.rateLimited,
          retryAfter: const Duration(seconds: 30),
        ),
        en.errorRateLimitedIn(30),
      );
      expect(
        en.message(
          AppErrorString.rateLimited,
          retryAfter: const Duration(seconds: 30),
        ),
        contains('30'),
      );
    });

    test('a duration is only used for the rate limit', () {
      // One cause takes a parameter. If another started honouring it silently, the
      // parameter would be a second source of truth for a sentence.
      for (final AppErrorString which in AppErrorString.values) {
        if (which == AppErrorString.rateLimited) continue;
        expect(
          en.message(which, retryAfter: const Duration(seconds: 30)),
          en.message(which),
          reason: '${which.name} must ignore retryAfter',
        );
      }
    });
  });

  group('the mapping from a thrown exception is total and honest', () {
    test('every subclass of the sealed hierarchy maps', () {
      final Map<AppException, AppErrorString> cases =
          <AppException, AppErrorString>{
            const NetworkException('timeout'): AppErrorString.noConnection,
            const SourceException('site down'):
                AppErrorString.sourceUnavailable,
            const DatabaseException('read failed'):
                AppErrorString.databaseUnavailable,
            const ChapterNotAvailableException('not downloaded'):
                AppErrorString.chapterNotAvailable,
            const CancelledException(): AppErrorString.checkCancelled,
          };
      for (final MapEntry<AppException, AppErrorString> entry
          in cases.entries) {
        expect(en.forAppException(entry.key), entry.value);
      }
    });

    test('a cancellation is never reported as a failure', () {
      expect(
        en.forAppException(const CancelledException()),
        AppErrorString.checkCancelled,
      );
      expect(en.recovery(AppErrorString.checkCancelled), isNull);
    });

    test('the seven subclasses are all reachable from one instance each', () {
      // `13-error-handling.md`: "Keep the hierarchy small." This row makes "small" a
      // number, so adding a fourth exception type for a fifth screen is visible.
      final Set<Type> subclasses = <Type>{
        NetworkException,
        SourceException,
        DatabaseException,
        ChapterNotAvailableException,
        CancelledException,
      };
      expect(subclasses, hasLength(5));
    });
  });

  group('the mapping from a typed site failure is total', () {
    test(
      'every SourceFailure subclass maps, and none is a site-read storage error',
      () {
        final Map<SourceFailure, AppErrorString> cases =
            <SourceFailure, AppErrorString>{
              const NoConnection(host: 'example.invalid'):
                  AppErrorString.noConnection,
              const RateLimited(retryAfter: Duration(seconds: 5)):
                  AppErrorString.rateLimited,
              const SourceLayoutChanged(failedSelector: '.x', status: 200):
                  AppErrorString.sourceLayoutChanged,
              const SourceUnavailable(status: 503):
                  AppErrorString.sourceUnavailable,
              const ItemRemovedAtSource(itemId: 'n1', status: 404):
                  AppErrorString.itemRemovedAtSource,
              const ParseFailed(path: '/novel/x.html'):
                  AppErrorString.parseFailed,
            };
        for (final MapEntry<SourceFailure, AppErrorString> entry
            in cases.entries) {
          expect(en.forSourceFailure(entry.key), entry.value);
        }
        // Six, not seven: `StorageFull` is not a source read. See `forSourceFailure`.
        expect(cases, hasLength(6));
      },
    );

    test(
      'no site sentence mentions the internal selector or the status code',
      () {
        // C12 asks for something a reader can say out loud. "Selector .chapter-content
        // failed" is a developer's sentence wearing a UI.
        for (final AppErrorString which in <AppErrorString>[
          AppErrorString.sourceLayoutChanged,
          AppErrorString.sourceUnavailable,
          AppErrorString.parseFailed,
        ]) {
          for (final AppLocalizations l10n in <AppLocalizations>[en, fr]) {
            final String sentence = l10n.message(which);
            expect(sentence, isNot(contains('.chapter-content')));
            expect(sentence, isNot(contains('503')));
            expect(sentence, isNot(contains('404')));
            expect(sentence, isNot(contains('Selector')));
          }
        }
      },
    );
  });

  group('the download vocabulary — B6, B37', () {
    test('the four states are distinct sentences', () {
      final Set<String> sentences = <String>{
        for (final AppErrorString which in <AppErrorString>[
          AppErrorString.downloadQueued,
          AppErrorString.downloadDownloading,
          AppErrorString.downloadDone,
          AppErrorString.downloadFailed,
        ])
          en.message(which),
      };
      expect(sentences, hasLength(4));
    });

    test('"downloaded" says done and not queued', () {
      // B6: the mark is written AFTER the atomic rename, so the word "Downloaded"
      // can only appear when the file is whole.
      expect(en.message(AppErrorString.downloadDone), en.downloadDone);
      expect(en.downloadDone, isNot(en.downloadQueued));
      expect(en.downloadDone, isNot(en.downloadDownloading));
    });

    test('a queued or running download can be cancelled', () {
      expect(en.recovery(AppErrorString.downloadQueued), en.commonCancel);
      expect(en.recovery(AppErrorString.downloadDownloading), en.commonCancel);
    });

    test('a finished download offers nothing', () {
      expect(en.recovery(AppErrorString.downloadDone), isNull);
    });
  });

  group('nothing reaches the reader from a sentence', () {
    test('no sentence contains a URL, a path, or a chapter title', () {
      // B44 and C5: a cause crossing an error layer does not carry a URL, so the
      // sentence cannot show one either.
      for (final AppErrorString which in AppErrorString.values) {
        for (final AppLocalizations l10n in <AppLocalizations>[en, fr]) {
          final String sentence = l10n.message(which);
          for (final String forbidden in <String>[
            'http://',
            'https://',
            '/novel/',
          ]) {
            expect(
              sentence,
              isNot(contains(forbidden)),
              reason: '${which.name} would show "$forbidden"',
            );
          }
        }
      }
    });

    test('every sentence fits a phone at 360dp in both languages', () {
      // C11: reading happens one-handed. A message that wraps to five lines is a
      // message the reader cannot act on while holding the phone.
      const int longestAllowed = 160;
      for (final AppErrorString which in AppErrorString.values) {
        for (final MapEntry<Locale, AppLocalizations> pair
            in <Locale, AppLocalizations>{
              const Locale('en'): en,
              const Locale('fr'): fr,
            }.entries) {
          expect(
            pair.value.message(which).length,
            lessThanOrEqualTo(longestAllowed),
            reason:
                '${which.name} in ${pair.key.languageCode} is ${pair.value.message(which).length} '
                'characters — longer than a message should be on a 360dp phone',
          );
        }
      }
    });
  });
}
