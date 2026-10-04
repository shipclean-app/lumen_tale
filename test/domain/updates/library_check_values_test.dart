// forge:slice 6-4
// Lumen Tale — `6-4`: the values one pass is made of, and the claims that live in the
// **types** rather than in the code around them.
//
// ## The three claims under test, and why no test of the loop can make them
//
// | rule | the claim | where it is written |
// |---|---|---|
// | **B22** | *checked and found nothing* and *could not check* are two arms of a sealed hierarchy, not two values of one `int` | [NovelCheckOutcome] |
// | **B39** | the pass's evidence is the **length of a list**, not a total | [LibraryCheckResult.perNovel] |
// | **B48** | "what this pass found" is a **different number** from the library's unopened total | [LibraryCheckResult.discoveredChapters] |
//
// ⚠️ **Nothing here runs a pass.** The loop is `data/`'s; this file asserts the shape a
// reader of `lib/domain/updates/library_check.dart` must be able to rely on, and every
// claim is one that the loop could not enforce by itself.

import 'package:flutter_test/flutter_test.dart';
import 'package:lumen_tale/core/error/app_exception.dart';
import 'package:lumen_tale/domain/updates/library_check.dart';

/// A fixed instant, so no value in this file depends on the clock.
final DateTime epoch = DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);

NovelChecked checked(int found, {int site = 0}) => NovelChecked(
  newChaptersFound: found,
  siteChapterCount: site,
  checkedAt: epoch,
);

NovelCheckFailed failed(CheckFailureKind kind, {String? selector}) =>
    NovelCheckFailed(kind: kind, sourceId: 'src-a', failedSelector: selector);

LibraryCheckResult resultOf(
  List<NovelCheckOutcome> perNovel, {
  bool interrupted = false,
}) => LibraryCheckResult(
  startedAt: epoch,
  finishedAt: epoch,
  total: perNovel.length,
  perNovel: perNovel,
  interrupted: interrupted,
);

void main() {
  group('B22 — "found nothing" and "could not check" are two types', () {
    test(
      'the failure vocabulary is the six causes § 2.2 declares, and no more',
      () {
        // `architecture.md` § 5.2 filtered to what a *check* can produce. A seventh arm is
        // a cause nobody thought about; a missing one is a verdict a future `switch` author
        // chooses for themselves.
        expect(
          CheckFailureKind.values.map((CheckFailureKind k) => k.name).toList(),
          <String>[
            'noConnection',
            'rateLimited',
            'sourceLayoutChanged',
            'sourceUnavailable',
            'itemRemovedAtSource',
            'parseFailed',
          ],
          reason: '§ 2.2 lists exactly these six, and `storageFull` is 5-3\'s',
        );
      },
    );

    test('a check that found nothing is a CHECKED, not a failure', () {
      // ⚠️ **The load-bearing zero.** B22's whole failure is a reader being told "0 new
      // chapters" about a site that could not be reached. With two types the two claims
      // cannot be written the same way; with an `int` they are.
      final NovelCheckOutcome outcome = checked(0);

      expect(
        outcome,
        isA<NovelChecked>(),
        reason: 'a site that listed nothing is a RESULT, not an absence',
      );
      expect(
        outcome,
        isNot(isA<NovelCheckFailed>()),
        reason: 'nothing here says "could not check"',
      );
      expect(
        (outcome as NovelChecked).newChaptersFound,
        0,
        reason: 'and the count is legitimately zero, not missing',
      );
    });

    test(
      'a failure cannot be built out of the checked arm, and vice versa',
      () {
        expect(
          failed(CheckFailureKind.noConnection),
          isNot(isA<NovelChecked>()),
          reason: 'sealed hierarchy: neither arm can be spelled as the other',
        );
        expect(
          checked(3),
          isNot(isA<NovelCheckFailed>()),
          reason: 'and a site that answered is never reported as unreadable',
        );
      },
    );

    test('the failing SELECTOR rides on the failure and only that arm has one', () {
      // C5: the selector is the artefact that makes a site repairable as a file, so it
      // must be *carried* — and it must not become state a reader can be shown (C12).
      expect(
        failed(
          CheckFailureKind.sourceLayoutChanged,
          selector: 'table#chapters',
        ).failedSelector,
        'table#chapters',
        reason:
            'E4 is the one cause whose evidence is the selector that came back empty',
      );
      expect(
        failed(CheckFailureKind.noConnection).failedSelector,
        isNull,
        reason: 'a dropped connection broke no selector',
      );
    });

    test('a failure names its SITE, so one broken site cannot mark another', () {
      // B23 / § 3.2 branch 6. `sourceId` is what makes the error code land on the right
      // `sources` row; without it a failure is unattributable and B49 cannot be repaired.
      expect(
        const NovelCheckFailed(
          kind: CheckFailureKind.sourceUnavailable,
          sourceId: 'src-b',
        ).sourceId,
        'src-b',
        reason: 'B2 — one novel, one site, and the code is written there',
      );
    });
  });

  group('B39 — the evidence is the LENGTH of the per-novel list', () {
    test('checked plus failed accounts for every entry, on a finished pass', () {
      // The arithmetic § 10 states. A dropped novel is the defect this catches: it would
      // make `perNovel` shorter than `total` while both counts stayed consistent with it.
      final LibraryCheckResult result = resultOf(<NovelCheckOutcome>[
        checked(2),
        failed(CheckFailureKind.parseFailed),
        checked(0),
        failed(CheckFailureKind.rateLimited),
      ]);

      expect(
        result.checkedCount + result.failedCount,
        result.perNovel.length,
        reason: 'B39: no entry is unaccounted for, so no novel was skipped',
      );
      expect(result.checkedCount, 2);
      expect(result.failedCount, 2);
    });

    test('a failure counts as a VISITED novel, not as an absent one', () {
      // The other half of B39: "no novel is skipped **for any reason**", and the reason a
      // naive loop skips is that the read failed. So the failed entry is inside the list.
      final LibraryCheckResult result = resultOf(<NovelCheckOutcome>[
        checked(1),
        failed(CheckFailureKind.sourceLayoutChanged),
      ]);

      expect(
        result.perNovel.length,
        2,
        reason:
            'the broken novel is an entry, which is what makes the skip visible',
      );
    });

    test(
      'an interrupted pass keeps its total, and the gap between them is the truth',
      () {
        // C8: "it looked at 7 of 23" has to be sayable. That is why `total` is carried on
        // the RESULT rather than only on the progress line: the line is transient.
        final LibraryCheckResult result = LibraryCheckResult(
          startedAt: epoch,
          finishedAt: epoch,
          total: 23,
          perNovel: List<NovelCheckOutcome>.unmodifiable(
            List<NovelCheckOutcome>.filled(7, checked(0)),
          ),
          interrupted: true,
        );

        expect(
          result.total,
          23,
          reason:
              'B39 promised 23; an interruption does not renegotiate the promise',
        );
        expect(
          result.perNovel.length,
          7,
          reason: 'and the number actually visited is reported as itself',
        );
        expect(result.interrupted, isTrue);
      },
    );

    test('"nothing new" is counted over the CHECKED arm only', () {
      // A failure has no count, so folding failures into the sum would require inventing
      // a zero for each — which is B22's defect one level up.
      final LibraryCheckResult result = resultOf(<NovelCheckOutcome>[
        checked(3),
        failed(CheckFailureKind.itemRemovedAtSource),
        checked(1),
      ]);

      expect(
        result.discoveredChapters,
        4,
        reason: '6-10 announces what the pass FOUND; a failure found nothing',
      );
    });

    test('"discovered" is rows ADDED, never the site\'s chapter count', () {
      // ⚠️ B48. Re-checking a novel whose chapters are all known finds **zero** new rows
      // while the site still publishes 700 chapters. A pass that reported the site's
      // count here would announce the whole library as new on every tap.
      final LibraryCheckResult result = resultOf(<NovelCheckOutcome>[
        checked(0, site: 716),
      ]);

      expect(
        result.discoveredChapters,
        0,
        reason: 'B48: the site\'s 716 rows are a local fact, not a discovery',
      );
      expect(
        (result.perNovel.single as NovelChecked).siteChapterCount,
        716,
        reason:
            'the site\'s own count is still carried, for the screen\'s comparison',
      );
    });
  });

  group('B39 — progress counts novels, and the total never moves', () {
    test('the first emission already knows the total, so no frame waits for it', () {
      // § 2.2: `total` holds from the first emission. A screen that rendered "Checking 0
      // of" and then jumped to 23 would be showing a count that changed under the reader.
      const LibraryCheckProgress first = LibraryCheckProgress(
        total: 23,
        done: 0,
        inFlightNovelId: null,
      );

      expect(
        first.total,
        23,
        reason:
            '§ 2.2 — the total is a local query, known before the first request',
      );
      expect(first.done, 0);
      expect(
        first.inFlightNovelId,
        isNull,
        reason: 'nothing is in flight before the first novel',
      );
      expect(
        first.isComplete,
        isFalse,
        reason:
            'B12 makes an empty library a real state, so "done" needs the total',
      );
    });

    test(
      'the counter rises by exactly one per novel, and the last one completes',
      () {
        // The plan's own arithmetic, asserted as a list. § 3.4: "Checking 7 of 23", never
        // "50+" — and `remaining` is what makes a skipped novel a hole.
        final List<LibraryCheckProgress> emissions = <LibraryCheckProgress>[
          for (int done = 0; done <= 23; done++)
            LibraryCheckProgress(total: 23, done: done, inFlightNovelId: null),
        ];

        expect(
          emissions.map((LibraryCheckProgress p) => p.done).toList(),
          List<int>.generate(24, (int i) => i),
          reason: 'B39: one per novel, no jump and no repeat',
        );
        expect(
          emissions.map((LibraryCheckProgress p) => p.total).toSet(),
          <int>{23},
          reason:
              'and a total that moved mid-pass would be a count the reader cannot trust',
        );
        expect(emissions.last.isComplete, isTrue);
        expect(emissions.first.remaining, 23);
        expect(emissions[7].remaining, 16);
      },
    );

    test('an empty library is COMPLETE and not an error', () {
      // B12: "nothing is kept" is a first-run state, so a pass over zero novels reports
      // zero and never invents a failure to justify the absence.
      const LibraryCheckProgress empty = LibraryCheckProgress(
        total: 0,
        done: 0,
        inFlightNovelId: null,
      );

      expect(empty.isComplete, isTrue);
      expect(empty.remaining, 0);
    });
  });

  group('13-error-handling.md rule 7 — a cancellation is its own type', () {
    test(
      'the check\'s cancellation IS `CancelledException`, not a seventh class',
      () {
        // `AppException` is `sealed`, so a second cancellation type could not exist in
        // another library anyway. The alias is what lets a caller write
        // `on CancelledException` once and catch both a cancel and this.
        const CheckCancelledException cancelled = CheckCancelledException();

        expect(cancelled, isA<CancelledException>());
        expect(cancelled, isA<AppException>());
      },
    );

    test('a cancellation is a VALUE here, never something `run()` throws', () {
      // § 3.1 returns `interrupted: true`. Throwing would make the reader's own gesture
      // travel the same path as a dead site, and B24 would put an error on screen for a
      // tap the reader made.
      final LibraryCheckResult stopped = LibraryCheckResult(
        startedAt: epoch,
        finishedAt: epoch,
        total: 5,
        perNovel: const <NovelCheckOutcome>[],
        interrupted: true,
      );

      expect(stopped.perNovel, isEmpty);
      expect(
        stopped.interrupted,
        isTrue,
        reason:
            'B37 — a stopped pass is reported as stopped, never as a success',
      );
    });
  });

  group('B38 — the merged chapter carries metadata only', () {
    test('a new chapter has no body, and -1 stays -1', () {
      // B38 is mechanical here: a value that could carry HTML is a value a check could
      // start filling in. B10: the `-1` sentinel means "the site published no number",
      // and `0` is a real chapter (an extra, an omake, a note).
      const NewChapter chapter = NewChapter(
        id: 'c1',
        url: '/fiction/1/chapter/2',
        name: 'Chapter 2',
        number: ChapterRecognitionSample.unparseable,
        ordinal: 7,
      );

      expect(
        chapter.number,
        -1.0,
        reason: 'B10: an unreadable number is stored as -1, never coerced to 0',
      );
      expect(
        chapter.ordinal,
        7,
        reason:
            'B9: the site\'s own position, never re-derived from the number',
      );
      expect(
        chapter.url,
        startsWith('/'),
        reason: '03-source-system.md rule 3 — relative, never a full URL',
      );
    });
  });
}

/// The sentinel this file asserts, named so the literal is written once.
abstract final class ChapterRecognitionSample {
  /// B10's *the site published no readable number*.
  static const double unparseable = -1;
}
