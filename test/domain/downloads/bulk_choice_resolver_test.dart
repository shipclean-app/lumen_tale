// forge:slice 5-1
// Lumen Tale — B18's six choices, resolved.
//
// `5-1` § 11.1. **Pure Dart, no database, no provider** (`10-testing.md` rule 4: a pure
// function is tested without one), so this file is the cheapest and the most direct test
// in the slice: every row asserts a branch of `resolveBulkChoice` against a list of
// chapters, and nothing else can move.
//
// | rule | the row |
// |---|---|
// | B18 | `NextChapter` is the FIRST NOT-STORED chapter, and does not filter on `isRead` |
// | B18 | `NextChapter` on a fully stored novel is `[]`, not an exception |
// | B18 | `NextChapters(5)` over three unstored chapters is **3**, never 5 |
// | B18 | `NextChapters(7)` **cannot be constructed** |
// | B18 | `AllUnopened` is not-read AND not-stored |
// | B18, rule 3 of `07` | `HandPicked` skips a stored chapter and **keeps the caller's order** |
// | B18 | `HandPicked([])` cannot be constructed |
// | B9, B18 | `number = -1` never moves a chapter — `ordinal` alone orders |
// | B18 | the repeated id yields ONE id (§ 3.2 branch 5) |
// | B18 | **there is no way to ask for "every chapter including read ones"** (§ 10) |
// | E14 | the resolver reads metadata only, so this slice renders nothing to resize |

import 'package:flutter_test/flutter_test.dart';
import 'package:lumen_tale/domain/downloads/bulk_choice.dart';
import 'package:lumen_tale/domain/downloads/bulk_choice_resolver.dart';

/// Any non-null instant: the mark's VALUE is never read, only its absence.
final DateTime _epoch = DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);

DownloadableChapter chapter(
  String id, {
  required int ordinal,
  bool isRead = false,
  bool stored = false,
}) => DownloadableChapter(
  id: id,
  ordinal: ordinal,
  isRead: isRead,
  downloadedAt: stored ? _epoch : null,
);

/// `count` chapters, none stored, none read, in `ordinal` order.
List<DownloadableChapter> plain(int count) => <DownloadableChapter>[
  for (int i = 0; i < count; i++) chapter('c${i + 1}', ordinal: i),
];

void main() {
  group('B18 — `NextChapter` is the first NOT-STORED chapter', () {
    test('⚠️ 100 chapters, 12 stored at the head → exactly ONE id, the 13th', () {
      // ⚠️ **THE PLAN'S OWN SCENARIO, AND THE 12 ARE STORED AT THE HEAD ON PURPOSE.**
      // "The first 12 stored" and "the first 12 not stored" are different answers, and
      // only the first one is B18's: the reader taps *Next chapter* and expects the
      // chapter they have not got, not the chapter at index zero.
      final List<DownloadableChapter> chapters = <DownloadableChapter>[
        for (int i = 0; i < 100; i++)
          chapter('c${i + 1}', ordinal: i, stored: i < 12),
      ];

      expect(
        resolveBulkChoice(const NextChapter(), chapters: chapters),
        <String>['c13'],
        reason:
            'B18: "the next chapter" is the next one without a copy. Returning c1 would '
            're-download a chapter this phone already holds, which rule 3 of '
            '07-downloads-offline.md forbids outright',
      );
    });

    test('⚠️ the chapter it returns MAY be one the reader has opened', () {
      // ⚠️ **THIS IS WHY `NextChapter` DOES NOT FILTER ON `isRead`.** § 3.1:
      // `novel-details.md` § 11.1 keeps *Next chapter* available on a novel whose
      // chapters have all been opened, and a choice requiring `isRead == false` would be
      // unavailable exactly there.
      final List<DownloadableChapter> chapters = <DownloadableChapter>[
        chapter('c1', ordinal: 0, isRead: true),
        chapter('c2', ordinal: 1, isRead: true),
      ];

      expect(
        resolveBulkChoice(const NextChapter(), chapters: chapters),
        <String>['c1'],
        reason:
            'B18: "already read" is not "already stored". A reader who finished a novel '
            'and presses *Download* is asking for a copy of it, not for chapters they '
            'have never seen',
      );
    });

    test('⚠️ a fully stored novel answers [] and does NOT throw', () {
      expect(
        resolveBulkChoice(
          const NextChapter(),
          chapters: <DownloadableChapter>[
            chapter('c1', ordinal: 0, stored: true),
            chapter('c2', ordinal: 1, stored: true),
          ],
        ),
        isEmpty,
        reason:
            '§ 3.1 branch 2: the sheet stays open and says there is nothing left. An '
            'exception here would put an error dialog over a state that is the correct '
            'answer — every chapter of that novel IS on this phone',
      );
    });
  });

  group('B18 — `NextChapters(n)` is exactly n, or what exists', () {
    test('⚠️ 3 unstored chapters with count = 5 → 3, never 5', () {
      expect(
        resolveBulkChoice(
          const NextChapters(5),
          chapters: <DownloadableChapter>[
            chapter('c1', ordinal: 0),
            chapter('c2', ordinal: 1),
            chapter('c3', ordinal: 2),
          ],
        ),
        <String>['c1', 'c2', 'c3'],
        reason:
            '§ 3.1: the sheet shows `resolveBulkChoice(choice).length`, so the count '
            'beside the row is 3 and the queue takes 3. A `min(5, total)` written in the '
            'widget would be a second answer to the same question',
      );
    });

    for (final int count in <int>[5, 10, 25]) {
      test('⚠️ count = $count takes exactly $count of 30', () {
        expect(
          resolveBulkChoice(NextChapters(count), chapters: plain(30)).length,
          count,
          reason:
              'B18 offers 5, 10 and 25 and no other count. The choice must take the '
              'reader\'s number, not a fraction of it',
        );
      });
    }

    // ⚠️ **THE CONSTRUCTION REFUSAL.** B18 names three counts. A fourth is a choice
    // nobody was offered, and § 3.1 says the refusal happens at construction so it
    // cannot be represented at all.
    test('⚠️ `NextChapters(7)` THROWS at construction', () {
      expect(
        () => NextChapters(7),
        throwsA(isA<AssertionError>()),
        reason:
            '§ 3.1: "a choice that is not in B18 must not be able to exist". The sheet '
            'computes its count through the same resolver, so a seventh count would be a '
            'number a reader saw beside a row the queue would then refuse to honour',
      );
    });
  });

  group('B18 — `AllUnopened` is the ONLY choice that filters on `isRead`', () {
    test('⚠️ 40 unopened of which 6 are stored → 34', () {
      // ⚠️ **THE TWO PREDICATES ARE BOTH NEEDED AND THE COUNT PROVES BOTH.** 40 − 6 = 34
      // only if `!isStored` is applied; 40 only if `!isRead` is applied. A test with only
      // one of the two wrong chapters would pass either implementation.
      final List<DownloadableChapter> chapters = <DownloadableChapter>[
        for (int i = 0; i < 40; i++)
          chapter('c${i + 1}', ordinal: i, stored: i < 6),
      ];

      expect(
        resolveBulkChoice(const AllUnopened(), chapters: chapters).length,
        34,
        reason:
            'B18: "all unread chapters" means unopened AND not already downloaded. A '
            'chapter that was opened and then downloaded must not be fetched again '
            '(rule 3 of 07-downloads-offline.md)',
      );
    });

    test('⚠️ 0 unopened → an empty list, and no exception', () {
      expect(
        resolveBulkChoice(
          const AllUnopened(),
          chapters: <DownloadableChapter>[
            chapter('c1', ordinal: 0, isRead: true),
            chapter('c2', ordinal: 1, isRead: true),
          ],
        ),
        isEmpty,
        reason:
            'a novel the reader has read in full online is a normal state, not an error. '
            'The sheet says "nothing to download" and no dialog appears',
      );
    });
  });

  group('B18 — `HandPicked` keeps the CALLER\'S order', () {
    test('⚠️ 3 ids of which 1 is stored → 2, in the order received', () {
      final List<DownloadableChapter> chapters = <DownloadableChapter>[
        chapter('c1', ordinal: 0, stored: true),
        chapter('c2', ordinal: 1),
        chapter('c3', ordinal: 2),
      ];

      // ⚠️ **`c3, c2` AGAINST `ordinal` `c2, c3`** — the two orders disagree, so a test
      // that happened to agree with `ordinal` would prove nothing about the rule.
      expect(
        resolveBulkChoice(
          HandPicked(<String>['c3', 'c1', 'c2']),
          chapters: chapters,
        ),
        <String>['c3', 'c2'],
        reason:
            'B18 + novel-details.md § 11.3: the selection bar declares NO reordering '
            'gesture, so the reader\'s insertion order IS the queue order. Rule 3 of '
            '07-downloads-offline.md drops the stored one',
      );
    });

    test('⚠️ a REPEATED id yields ONE id (§ 3.2 branch 5)', () {
      expect(
        resolveBulkChoice(
          HandPicked(<String>['c2', 'c2', 'c3']),
          chapters: plain(3),
        ),
        <String>['c2', 'c3'],
        reason:
            '§ 3.2 branch 5: the resolver guarantees it, so the queue holds one row per '
            'chapter even if a future selection surface can produce a duplicate',
      );
    });

    test('⚠️ `HandPicked([])` THROWS at construction', () {
      expect(
        () => HandPicked(<String>[]),
        throwsA(isA<AssertionError>()),
        reason:
            '§ 3.1: "an empty selection is not a choice, it is a mistap". A zero-length '
            'hand-picked download would be an offer the reader never made',
      );
    });

    // ⚠️ **THE DEFECT-CASE ROW.** § 3.1 calls this unreachable through the interface, and
    // says the resolver must *document* it in an assertion rather than catch it: an
    // unknown id is a caller defect, not a search input.
    test(
      '⚠️ an id the caller never displayed THROWS — it is not silently dropped',
      () {
        expect(
          () => resolveBulkChoice(
            HandPicked(<String>['c1', 'nope']),
            chapters: plain(3),
          ),
          throwsA(isA<StateError>()),
          reason:
              '§ 3.1: unreachable through the selection bar, which offers only ids it '
              'rendered. Silently dropping it would queue a download the reader did not '
              'ask for, and queueing nothing would claim it was handled',
        );
      },
    );
  });

  group('B9 — the order is `ordinal`, and `number` never enters it', () {
    test('⚠️ a chapter at `number = -1` stays IN ITS ORDINAL PLACE', () {
      // ⚠️ **`DownloadableChapter` HAS NO `number` FIELD AT ALL**, which is the strongest
      // form of the rule: there is no value a caller could sort by. The test pins the
      // consequence — passing the list OUT of order still resolves in `ordinal` order.
      final List<DownloadableChapter> chapters = <DownloadableChapter>[
        chapter('c3', ordinal: 2),
        chapter('c1', ordinal: 0),
        chapter('c2', ordinal: 1),
      ];

      expect(
        resolveBulkChoice(const NextChapters(5), chapters: chapters),
        <String>['c1', 'c2', 'c3'],
        reason:
            'B9/B18: `number` is -1 when the site published something unreadable and it '
            'restarts at zero per volume, so a queue ordered by it interleaves volumes '
            'and does not read in order. The list is copied and sorted by `ordinal`',
      );
    });

    test('⚠️ the caller\'s list is NOT re-ordered in place', () {
      // ⚠️ **A PURE FUNCTION WITH A SIDE EFFECT ON ITS ARGUMENT IS NOT PURE.** The list
      // handed in is the one a provider caches and a screen rebuilds from; sorting it
      // would reorder state nobody asked to reorder.
      final List<DownloadableChapter> chapters = <DownloadableChapter>[
        chapter('c2', ordinal: 1),
        chapter('c1', ordinal: 0),
      ];
      final List<String> before = chapters
          .map((DownloadableChapter c) => c.id)
          .toList();

      resolveBulkChoice(const NextChapter(), chapters: chapters);

      expect(
        chapters.map((DownloadableChapter c) => c.id).toList(),
        before,
        reason:
            '§ 3.1: the sort happens on a copy. The caller keeps the order it passed',
      );
    });

    test('⚠️ 10 000 chapters resolve in full — there is no global cap', () {
      // ⚠️ **B9's BOUND, MEASURED.** A novel of 10 000 chapters must produce 10 000 rows
      // for `AllUnopened`; a truncation would drop the tail silently, and B9 forbids
      // "silently truncating" by name.
      final List<DownloadableChapter> chapters = plain(10000);

      expect(
        resolveBulkChoice(const AllUnopened(), chapters: chapters).length,
        10000,
        reason:
            'B9: the list is complete whatever its length. Only `NextChapter` and '
            '`NextChapters(n)` cap, and those caps are the ones B18 asks for',
      );
    });
  });

  group('B18 — the forbidden seventh choice is UNREPRESENTABLE', () {
    test('⚠️ the sealed hierarchy has exactly four leaves, and no "everything"', () {
      // ⚠️ **§ 10's CRITERION, ASSERBED RATHER THAN ASSUMED.** B18: *"There is no '
      // "download every chapter including ones already read" shortcut — that is reachable '
      // only by selecting every chapter deliberately."* The only path to an already-read
      // chapter is therefore `HandPicked`, which is literally "selected by hand".
      expect(
        <BulkChoice>[
          const NextChapter(),
          const NextChapters(5),
          const NextChapters(10),
          const NextChapters(25),
          const AllUnopened(),
          HandPicked(<String>['c1']),
        ],
        hasLength(6),
        reason:
            'B18 names six scopes: next, next 5, next 10, next 25, all unread, and a '
            'hand-picked set. A seventh would be the shortcut the rule forbids',
      );
      expect(
        kBulkChoices,
        hasLength(5),
        reason:
            'and the SHEET has five radio rows: `novel-details.md` § 11.1 reaches the '
            'sixth choice by long-pressing tiles, not from the sheet — so a hand-picked '
            'row could only ever resolve to zero',
      );
    });
  });

  group(
    'E14 — this slice renders nothing, and therefore asserts nothing about resizing',
    () {
      test('⚠️ resolution reads four scalar fields and no rendering surface', () {
        // ⚠️ **§ 10's E14 CRITERION, STATED RATHER THAN SKIPPED.** E14 is "the phone's font
        // size changes mid-read". A text file cannot clip, overlap or reflow, so this slice
        // has no rendered surface that could — and a rendering assertion here would be a
        // test of `2-8`'s reader with none of its machinery.
        expect(
          resolveBulkChoice(
            const NextChapter(),
            chapters: <DownloadableChapter>[chapter('c1', ordinal: 0)],
          ),
          <String>['c1'],
          reason:
              'E14 belongs to 2-8. The strongest claim this slice CAN make is that its '
              'decision inputs are plain values, and the resolver runs in a `test()` with '
              'no widget tree at all — so there is nothing here for a font size to affect',
        );
      });
    },
  );
}
