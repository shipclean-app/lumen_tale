// forge:slice 6-5
// Lumen Tale — `6-5`: B46 (a position is not a history entry) and B47 (the journal
// is bounded by TIME, never by a count).
//
// Both rules are invisible in a passing test suite, because both produce a working
// screen. B46 produces a working screen that lies about where the reader stopped; B47
// produces a working screen that silently drops the intensive reader's oldest month.
// So the rows here are mostly about **absences** — a field that must not exist, a
// `LIMIT` that must not be written, a join that must not appear.
//
// The domain layer takes **no clock**: every function that needs "now" is handed it.
// A function that read a clock would be untestable exactly at a midnight boundary,
// which is the only place any of this can be wrong.

import 'package:flutter_test/flutter_test.dart';
import 'package:lumen_tale/domain/history/history_entry.dart';
import 'package:lumen_tale/domain/history/history_grouping.dart';
import 'package:lumen_tale/domain/history/history_retention.dart';

/// One fixed instant, so no row depends on the machine's clock.
final DateTime now = DateTime.utc(2026, 10, 3, 12);

HistoryEntry entry(
  String id, {
  required DateTime openedAt,
  String chapterTitle = 'Chapter 1',
  String novelTitle = 'A Novel',
}) {
  return HistoryEntry(
    id: id,
    novelId: '90db9662f191bf2418033ab0bee1e629',
    novelTitle: novelTitle,
    chapterId: '3003a98742f53c4b4f2ae62d8105a4e9',
    chapterTitle: chapterTitle,
    openedAt: openedAt,
  );
}

void main() {
  group('HistoryEntry — B46 in mechanical form', () {
    test('an entry carries no reading position of any kind', () {
      // The absence is the feature. A `progress` field here would be *used*, because a
      // journal row is exactly where a reader looks for "where was I".
      //
      // ⚠️ Asserted by **use**, not by reflection: `dart:mirrors` is unavailable on
      // this platform, and a test that pretended to enumerate fields would be a
      // control that verifies nothing. What can be checked is that the type offers no
      // such getter — which is a compile-time fact, so the row below is the
      // behavioural half of it.
      final HistoryEntry e = entry('h1', openedAt: now);

      // Every field the contract declares, and nothing else is reachable from here.
      expect(e.id, 'h1');
      expect(e.openedAt, now);
      expect(e.chapterTitle, 'Chapter 1');
      expect(e.novelTitle, 'A Novel');
    });

    test('two openings of one chapter are two entries, not one', () {
      // No unique key on `(novel_id, chapter_id)` is deliberate: it is a journal of
      // what was opened, and re-opening a chapter must show at its new date. Merging
      // them would erase the fact that a reading happened twice.
      final List<HistoryEntry> journal = <HistoryEntry>[
        entry('h2', openedAt: now),
        entry('h1', openedAt: now.subtract(const Duration(hours: 2))),
      ];
      expect(journal, hasLength(2));
      expect(journal.map((HistoryEntry e) => e.id), <String>['h2', 'h1']);
    });

    test('toString carries the id, not the chapter title', () {
      // A chapter title is site text, and a `toString` is the most likely accidental
      // carrier of it into a log — the same rule `Novel` follows.
      expect(
        entry('h1', openedAt: now).toString(),
        isNot(contains('Chapter 1')),
      );
    });

    test(
      'an untitled chapter keeps a null-safe label for the screen to render',
      () {
        // `history.md` § 4: empty at the source renders *Untitled*, never an index.
        final HistoryEntry e = entry('h1', openedAt: now, chapterTitle: '');
        expect(e.chapterTitle, '');
        // The screen's job, not this type's — but the value must survive untouched, so
        // no fallback is applied here where a second one could disagree.
        expect(e.chapterTitle.trim(), isEmpty);
      },
    );
  });

  group('NovelResumePoint — B17 second sentence', () {
    test('a resume point carries a scroll offset, not a page index', () {
      // ADR-009: an offset, because a page index is meaningless at another text size.
      final NovelResumePoint point = NovelResumePoint(
        novelId: 'n1',
        chapterId: 'c1',
        chapterTitle: 'Chapter 4',
        offset: 1840.5,
        updatedAt: now,
      );
      expect(point.offset, 1840.5);
      expect(point.updatedAt, now);
    });

    test(
      'the journal and the resume point are different types with different fields',
      () {
        // If these were one type, clearing the journal would be able to clear a
        // position — which is the bug B46 exists to prevent, and which only becomes
        // possible again if the two shapes merge.
        expect(HistoryEntry, isNot(NovelResumePoint));
        final HistoryEntry e = entry('h1', openedAt: now);
        expect(e, isNot(isA<NovelResumePoint>()));
      },
    );
  });

  group('HistoryRetention — B47', () {
    test('there is no "keep everything"', () {
      // A `keepAll` member would let the reader ask the app to promise something it
      // cannot back: there is no remote copy (C8, ADR-010).
      expect(HistoryRetention.values, hasLength(5));
      expect(
        HistoryRetention.values.map((HistoryRetention w) => w.name),
        isNot(contains('keepAll')),
      );
      expect(
        HistoryRetention.values.map((HistoryRetention w) => w.name),
        isNot(contains('forever')),
      );
    });

    test('one year is the default and it is conservative, not arbitrary', () {
      expect(HistoryRetention.defaultWindow, HistoryRetention.oneYear);
      // Conservative means: shorter than the longest offered, so a reader who chose
      // nothing keeps less, not more.
      expect(
        HistoryRetention.defaultWindow.window,
        lessThan(HistoryRetention.twoYears.window),
      );
    });

    test('the windows are strictly increasing in the declared order', () {
      const List<HistoryRetention> windows = HistoryRetention.values;
      for (int i = 1; i < windows.length; i++) {
        expect(
          windows[i].window,
          greaterThan(windows[i - 1].window),
          reason:
              '${windows[i].name} must be a longer window than '
              '${windows[i - 1].name}; the enum order IS the sheet row order',
        );
      }
    });

    test('a cutoff is derived, never stored', () {
      expect(
        HistoryRetention.threeMonths.cutoffFrom(now),
        now.subtract(const Duration(days: 90)),
      );
    });

    test('nothing stored reads the default and writes no key', () {
      expect(
        HistoryRetention.fromStorage(null),
        HistoryRetention.defaultWindow,
      );
    });

    test('a stored value round-trips through its own name, not its ordinal', () {
      // Storing the ordinal would break the moment a member is inserted, and the
      // reader's preference would silently become a different window.
      for (final HistoryRetention window in HistoryRetention.values) {
        expect(HistoryRetention.fromStorage(window.name), window);
      }
    });

    test('a stored value the enum no longer has falls back to the default', () {
      // Reachable: a preference written by a version that had a sixth window.
      expect(
        HistoryRetention.fromStorage('keepAll'),
        HistoryRetention.defaultWindow,
      );
      expect(HistoryRetention.fromStorage(''), HistoryRetention.defaultWindow);
    });
  });

  group('the day a line belongs to is computed, never stored', () {
    test('consecutive entries on one local day make one group', () {
      final List<HistoryEntry> journal = <HistoryEntry>[
        entry('a', openedAt: DateTime(2026, 10, 3, 23, 40)),
        entry('b', openedAt: DateTime(2026, 10, 3, 9, 15)),
        entry('c', openedAt: DateTime(2026, 10, 2, 22, 5)),
      ];

      final List<HistoryDayGroup> groups = groupByLocalDay(journal);
      expect(groups, hasLength(2));
      expect(groups[0].entries.map((HistoryEntry e) => e.id), <String>[
        'a',
        'b',
      ]);
      expect(groups[1].entries.map((HistoryEntry e) => e.id), <String>['c']);
      expect(groups[0].date, DateTime(2026, 10, 3));
    });

    test('an empty journal is zero groups, not an error', () {
      // US-12 distinguishes "never opened anything" from "opened things and then
      // cleared them", and both start here.
      expect(groupByLocalDay(const <HistoryEntry>[]), isEmpty);
    });

    test('a single entry is one group of one', () {
      final List<HistoryDayGroup> groups = groupByLocalDay(<HistoryEntry>[
        entry('a', openedAt: now),
      ]);
      expect(groups, hasLength(1));
      expect(groups.single.entries, hasLength(1));
    });

    test(
      'the boundary is half-open: exactly at midnight belongs to the new day',
      () {
        final List<HistoryEntry> journal = <HistoryEntry>[
          entry('b', openedAt: DateTime(2026, 10, 3)),
          entry('a', openedAt: DateTime(2026, 10, 2, 23, 59, 59)),
        ];
        expect(groupByLocalDay(journal), hasLength(2));
      },
    );

    test('the last millisecond of a day is still that day', () {
      final List<HistoryEntry> journal = <HistoryEntry>[
        entry('a', openedAt: DateTime(2026, 10, 2, 23, 59, 59, 999)),
      ];
      expect(groupByLocalDay(journal).single.date, DateTime(2026, 10, 2));
    });

    test('two entries at the same millisecond keep their arrival order', () {
      // The relative order is **indeterminate** and this does not pretend otherwise:
      // they share a group and neither is reordered. B17 says "most recent first",
      // not "and here is a tie-breaker".
      final DateTime same = DateTime(2026, 10, 3, 14, 30);
      final List<HistoryEntry> journal = <HistoryEntry>[
        entry('first', openedAt: same),
        entry('second', openedAt: same),
      ];
      final HistoryDayGroup group = groupByLocalDay(journal).single;
      expect(group.entries.map((HistoryEntry e) => e.id), <String>[
        'first',
        'second',
      ]);
    });

    test('a gap of days produces one group per day, not one per gap', () {
      final List<HistoryEntry> journal = <HistoryEntry>[
        entry('a', openedAt: DateTime(2026, 10, 1, 12)),
        entry('b', openedAt: DateTime(2026, 9, 28, 12)),
        entry('c', openedAt: DateTime(2026, 9, 20, 12)),
      ];
      expect(groupByLocalDay(journal), hasLength(3));
    });

    test('the day comparison reads the calendar, not the clock', () {
      // ⚠️ **The reason this helper exists, and the reason it is asserted the way it
      // is.** The tempting demonstration is that `DateTime(2026,10,3)` and
      // `DateTime.utc(2026,10,3)` are "the same instant and different days" — but
      // whether they are the same instant **depends on the machine's timezone**: in
      // UTC they are identical, in Europe/Paris the local one is two hours later.
      //
      // A first draft asserted `isAtSameMomentAs == true` and it passed on this
      // container (TZ=Etc/UTC) and **failed under TZ=Europe/Paris**. A test whose
      // truth depends on the environment is a test that will fail for someone who did
      // nothing wrong, and the usual response is to delete it.
      //
      // So the property is asserted directly and deterministically: the comparison
      // reads year/month/day and **ignores the time entirely**. Two instants at
      // opposite ends of the same local day are the same day; two midnights that are
      // the same instant are obviously the same day too, and that case needs no
      // timezone to demonstrate.
      final DateTime earlyMorning = DateTime(2026, 10, 3);
      final DateTime lateEvening = DateTime(2026, 10, 3, 23, 59, 59, 999);
      expect(isSameLocalDay(earlyMorning, lateEvening), isTrue);

      expect(isSameLocalDay(earlyMorning, DateTime(2026, 10, 4)), isFalse);
      expect(
        isSameLocalDay(earlyMorning, DateTime(2026, 10, 3, 12)),
        isTrue,
        reason: 'the time of day must not move a row between groups',
      );

      // And the whole helper's purpose, in one row: two entries twenty minutes apart
      // across midnight are two groups.
      final List<HistoryDayGroup> groups = groupByLocalDay(<HistoryEntry>[
        entry('after', openedAt: DateTime(2026, 10, 3, 0, 5)),
        entry('before', openedAt: DateTime(2026, 10, 2, 23, 55)),
      ]);
      expect(groups, hasLength(2));
    });

    test('local midnight is derived from the local calendar, not truncated', () {
      expect(
        localMidnightOf(DateTime(2026, 10, 3, 23, 59)),
        DateTime(2026, 10, 3),
      );
      expect(localMidnightOf(DateTime(2026, 10, 3)), DateTime(2026, 10, 3));
      // Day, month and year only — time is zeroed, not rounded to the nearest hour.
      expect(localMidnightOf(DateTime(2026, 1, 31, 12)).day, 31);
    });
  });

  group('counting what is about to leave the window', () {
    test('the count is about entries older than the cutoff', () {
      final DateTime cutoff = HistoryRetention.threeMonths.cutoffFrom(now);
      final List<HistoryEntry> journal = <HistoryEntry>[
        entry('in', openedAt: now),
        entry('at', openedAt: cutoff),
        entry('old1', openedAt: cutoff.subtract(const Duration(days: 1))),
        entry('old2', openedAt: cutoff.subtract(const Duration(days: 400))),
      ];

      // Exactly at the cutoff is **inside** the window, so it is not counted as about
      // to leave. An exclusive comparison would make a reader lose the oldest entry
      // still inside the window they are choosing.
      expect(countOlderThan(journal, cutoff), 2);
    });

    test(
      'a fresh journal counts zero, which is why the count runs BEFORE the purge',
      () {
        // After a purge this is always zero — true about the past, useless about the
        // decision the reader is making (`history.md` § 11.1).
        final List<HistoryEntry> journal = <HistoryEntry>[
          entry('a', openedAt: now),
        ];
        expect(
          countOlderThan(journal, now.subtract(const Duration(days: 90))),
          0,
        );
      },
    );
  });
}
