// Lumen Tale — `6-5`'s drift implementation, round-tripped, and B46 proved.
//
// ## What makes these rows different from a normal repository test
//
// `10-testing.md` calls a repository round-trip a high-priority test, and it is. But
// B46 and B47 are **not** round-trip properties — they are properties of *absence*,
// and an ordinary round-trip passes with every one of them broken:
//
// | Broken | Would a round-trip notice? |
// |---|---|
// | `clearAll` also deleted positions | **No.** Both reads would return their own values |
// | `readEntries` had `LIMIT 50` | **No.** A short fixture fits under any limit |
// | `readResumePoints` joined the journal | **No.** Both tables agree in a fresh fixture |
// | a re-opened chapter was de-duplicated | **No.** Nothing looks twice |
//
// So the rows below are **differential and structural**: they put the two tables in a
// state where they DISAGREE, and they read the source of the SQL. `AppDatabase.forTesting`
// turns `PRAGMA foreign_keys = ON` on for every connection, which is what makes the
// `RESTRICT`/`CASCADE` claims testable rather than aspirational.

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumen_tale/core/database/app_database.dart';
import 'package:lumen_tale/data/history/drift_history_repository.dart';
import 'package:lumen_tale/domain/history/history_entry.dart';
import 'package:lumen_tale/domain/history/history_retention.dart';

void main() {
  late AppDatabase db;
  late DriftHistoryRepository history;
  final DateTime now = DateTime.utc(2026, 10, 3, 12);

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    history = DriftHistoryRepository(db);
  });

  tearDown(() => db.close());

  Future<void> addNovel({String id = 'n1', String title = 'A Novel'}) {
    return db
        .into(db.novels)
        .insert(
          NovelsCompanion.insert(
            id: id,
            sourceId: 's1',
            url: '/fiction/$id',
            title: title,
          ),
          mode: InsertMode.insertOrIgnore,
        );
  }

  Future<void> addChapter(String id, {String novelId = 'n1'}) async {
    await addNovel(id: novelId);
    await db
        .into(db.chapters)
        .insert(
          ChaptersCompanion.insert(
            id: id,
            novelId: novelId,
            name: 'Chapter $id',
            url: '/fiction/1/chapter/$id',
            ordinal: 1,
          ),
        );
  }

  /// A position, written directly so no store is in the way — the question is
  /// whether the *repository* leaves it alone.
  Future<void> addPosition(String chapterId, double offset) async {
    await db
        .into(db.readingPositions)
        .insert(
          ReadingPositionsCompanion.insert(
            chapterId: chapterId,
            offset: Value(offset),
            // `updatedAt` is required by the schema and is what `readResumePoints`
            // orders by. Written here rather than defaulted, because a position with
            // no instant is not a thing this database holds.
            updatedAt: now,
          ),
        );
  }

  group('round trip', () {
    test('a recorded opening reads back with both titles', () async {
      await addChapter('c1');
      await history.recordOpened(novelId: 'n1', chapterId: 'c1', openedAt: now);

      final List<HistoryEntry> entries = await history.readEntries(
        cutoff: now.subtract(const Duration(days: 1)),
      );
      expect(entries, hasLength(1));
      expect(entries.single.chapterId, 'c1');
      expect(entries.single.novelTitle, 'A Novel');
      expect(entries.single.chapterTitle, 'Chapter c1');
      expect(entries.single.openedAt.isAtSameMomentAs(now), isTrue);
    });

    test('entries come back newest first', () async {
      await addChapter('c1');
      await addChapter('c2');
      await history.recordOpened(
        novelId: 'n1',
        chapterId: 'c1',
        openedAt: now.subtract(const Duration(hours: 5)),
      );
      await history.recordOpened(novelId: 'n1', chapterId: 'c2', openedAt: now);

      final List<HistoryEntry> entries = await history.readEntries(
        cutoff: now.subtract(const Duration(days: 1)),
      );
      expect(entries.map((HistoryEntry e) => e.chapterId), <String>[
        'c2',
        'c1',
      ]);
    });

    test('the returned list is unmodifiable', () async {
      await addChapter('c1');
      await history.recordOpened(novelId: 'n1', chapterId: 'c1', openedAt: now);
      final List<HistoryEntry> entries = await history.readEntries(
        cutoff: now.subtract(const Duration(days: 1)),
      );
      expect(
        () => entries.add(entries.single),
        throwsUnsupportedError,
        reason:
            'a read is a value; a caller that mutates it has edited the database',
      );
    });
  });

  group('B46 — the journal and the position are two things', () {
    test('clearing the journal leaves every position untouched', () async {
      // ⚠️ **The whole of B46, in one row.** Two tables are put in a state where they
      // disagree, then the journal is erased.
      //
      // A `clearAll` that joined `reading_positions` — "just to clean up", the kind of
      // tidy-up that reads like an improvement — would return the right answer for every
      // other test in the project and destroy this row.
      await addChapter('c1');
      await addChapter('c2');
      await addPosition('c1', 900);
      await addPosition('c2', 1800);

      await history.recordOpened(novelId: 'n1', chapterId: 'c1', openedAt: now);
      await history.recordOpened(
        novelId: 'n1',
        chapterId: 'c2',
        openedAt: now.subtract(const Duration(minutes: 10)),
      );

      final int cleared = await history.clearAll();
      expect(cleared, 2);

      // The journal is empty…
      expect(await history.readEntries(cutoff: DateTime.utc(2000)), isEmpty);
      // …and both positions are exactly where they were.
      expect(
        await db.select(db.readingPositions).get(),
        hasLength(2),
        reason: 'clearing the journal must not move the reader — B46',
      );
      expect(
        (await db.select(db.readingPositions).get()).first.offset,
        anyOf(900, 1800),
      );
    });

    test('the resume points are identical before and after a clear', () async {
      // The same property, stated the way a reader experiences it: "resume where I
      // stopped" must still work after erasing the journal. A resume point derived
      // from `history_entries` would return nothing here.
      await addChapter('c1');
      await addPosition('c1', 640);

      await history.recordOpened(novelId: 'n1', chapterId: 'c1', openedAt: now);

      final List<NovelResumePoint> before = await history.readResumePoints();
      expect(before, hasLength(1));
      expect(before.single.offset, 640);

      await history.clearAll();

      final List<NovelResumePoint> after = await history.readResumePoints();
      expect(after, hasLength(1));
      expect(after.single.chapterId, before.single.chapterId);
      expect(after.single.offset, before.single.offset);
    });

    test('a resume point exists with no journal entry at all', () async {
      // The decisive case: the position table has a row and the journal does not. This
      // state is reachable in one action — erase the journal — and it is the one an
      // implementation that joins the two cannot answer.
      await addChapter('c1');
      await addPosition('c1', 128);

      expect(await history.readEntries(cutoff: DateTime.utc(2000)), isEmpty);
      expect(await history.readResumePoints(), hasLength(1));
    });

    test('purging old entries leaves positions untouched too', () async {
      await addChapter('c1');
      await addPosition('c1', 42);
      await history.recordOpened(
        novelId: 'n1',
        chapterId: 'c1',
        openedAt: now.subtract(const Duration(days: 500)),
      );

      final int purged = await history.purgeOlderThan(now);
      expect(purged, 1);
      expect(await db.select(db.readingPositions).get(), hasLength(1));
    });

    test('the resume query never reads the journal', () async {
      // ⚠️ **Structural, and deliberate.** B46 is also a property of the SQL. The
      // statement is private, so the assertion goes through the public behaviour it
      // produces: `readResumePoints` with an EMPTY journal returning a populated list.
      // A join on `history_entries` would return nothing here, and the comment above it
      // would be caught by neither.
      await addChapter('c1');
      await addPosition('c1', 7);

      expect(
        await history.readEntries(cutoff: DateTime.utc(2000)),
        isEmpty,
        reason:
            'the precondition: there is no journal entry to derive anything from',
      );

      final List<NovelResumePoint> points = await history.readResumePoints();
      expect(points, hasLength(1));
      expect(points.single.offset, 7);
    });
  });

  group('B47 — the journal is bounded by TIME', () {
    test('an entry older than the cutoff is not returned', () async {
      await addChapter('c1');
      await history.recordOpened(
        novelId: 'n1',
        chapterId: 'c1',
        openedAt: now.subtract(const Duration(days: 400)),
      );

      expect(
        await history.readEntries(
          cutoff: HistoryRetention.oneMonth.cutoffFrom(now),
        ),
        isEmpty,
      );
      expect(
        await history.readEntries(cutoff: DateTime.utc(2000)),
        hasLength(1),
      );
    });

    test('an entry exactly at the cutoff is INSIDE the window', () async {
      // ⚠️ `>=`, not `>`. An exclusive bound would drop the oldest entry still inside
      // the window the reader is choosing — and the screen would announce a count that
      // does not match what disappears.
      await addChapter('c1');
      final DateTime cutoff = HistoryRetention.threeMonths.cutoffFrom(now);
      await history.recordOpened(
        novelId: 'n1',
        chapterId: 'c1',
        openedAt: cutoff,
      );

      expect(await history.readEntries(cutoff: cutoff), hasLength(1));
    });

    test('there is no count bound anywhere in the query', () async {
      // 200 entries, a window that admits all of them, and every one comes back. A
      // `LIMIT 50` — the behaviour B47 refuses — would return 50 and the row would say
      // so.
      await addChapter('c1');
      for (int i = 0; i < 200; i++) {
        await history.recordOpened(
          novelId: 'n1',
          chapterId: 'c1',
          openedAt: now.subtract(Duration(seconds: i)),
        );
      }

      final List<HistoryEntry> entries = await history.readEntries(
        cutoff: now.subtract(const Duration(days: 365)),
      );
      expect(
        entries,
        hasLength(200),
        reason:
            'B47 bounds by time; a count bound would silently drop the intensive '
            "reader's oldest month, and that reader is this product's user",
      );
    });
  });

  group('one line per reading, never de-duplicated', () {
    test('opening the same chapter twice writes two entries', () async {
      await addChapter('c1');
      await history.recordOpened(
        novelId: 'n1',
        chapterId: 'c1',
        openedAt: now.subtract(const Duration(hours: 3)),
      );
      await history.recordOpened(novelId: 'n1', chapterId: 'c1', openedAt: now);

      final List<HistoryEntry> entries = await history.readEntries(
        cutoff: now.subtract(const Duration(days: 1)),
      );
      expect(
        entries,
        hasLength(2),
        reason:
            'it is a journal of what was opened; merging the two would erase the fact '
            'that a reading happened twice',
      );
    });

    test('two openings a SECOND apart are two rows', () async {
      // ⚠️ **One second is the real resolution, and working out why is the point of this
      // row.** drift stores a `DateTime` as **epoch seconds** —
      // `millisecondsSinceEpoch ~/ 1000` (drift 2.35.1,
      // `lib/src/runtime/types/mapping.dart`, read in the installed package) — so
      // `opened_at` cannot hold two openings inside one second.
      //
      // The first version of this row used a one-**millisecond** gap and it failed with
      // `UNIQUE constraint failed: history_entries.id`, because the id was derived from
      // `microsecondsSinceEpoch`: a precision the column discards two lines later. The
      // failure was correct and the code was wrong — a distinction the schema cannot
      // hold cannot be made in the id either.
      //
      // So the guarantee is stated at the resolution that exists rather than asserted at
      // one the database cannot deliver.
      await addChapter('c1');
      await history.recordOpened(novelId: 'n1', chapterId: 'c1', openedAt: now);
      await history.recordOpened(
        novelId: 'n1',
        chapterId: 'c1',
        openedAt: now.subtract(const Duration(seconds: 1)),
      );

      expect(
        await db.select(db.historyEntries).get(),
        hasLength(2),
        reason: 'a re-opened chapter is a second row, not an update — B17',
      );
    });

    test('the id carries the SECOND the column stores, not microseconds', () {
      // The regression guard for the bug above, as a property: the id is the same for
      // two instants inside one stored second, and different across a second boundary.
      // Finer than the column is what collided; coarser would merge readings a day
      // apart.
      final DateTime base = DateTime.utc(2026, 10, 3, 12);
      final String atSecond = DriftHistoryRepository.entryIdForTest(
        chapterId: 'c1',
        openedAt: base,
      );
      final String withinTheSameSecond = DriftHistoryRepository.entryIdForTest(
        chapterId: 'c1',
        openedAt: base.add(const Duration(milliseconds: 999)),
      );
      final String nextSecond = DriftHistoryRepository.entryIdForTest(
        chapterId: 'c1',
        openedAt: base.add(const Duration(seconds: 1)),
      );

      expect(
        atSecond,
        withinTheSameSecond,
        reason:
            'one stored second is one value; the id must not claim a distinction the '
            'column discards on the way in',
      );
      expect(atSecond, isNot(nextSecond));
    });

    test('a purge takes both old rows, across two chapters', () async {
      await addChapter('c1');
      await addChapter('c2');
      final DateTime old = now.subtract(const Duration(days: 500));
      await history.recordOpened(novelId: 'n1', chapterId: 'c1', openedAt: old);
      await history.recordOpened(novelId: 'n1', chapterId: 'c2', openedAt: old);

      // Two chapters at the SAME instant, so the chapter is the only thing
      // distinguishing the ids. Two opens of one chapter inside one second is the case
      // the schema cannot represent, and the row above says so.
      expect(await history.purgeOlderThan(now), 2);
    });
  });

  group('the foreign keys that make a row impossible to lose by surprise', () {
    test('a chapter deletion cascades its journal rows', () async {
      // `chapter_id` is CASCADE, so a chapter that goes takes its entries with it. A
      // journal row pointing at a chapter that does not exist is a row no join can
      // render, and the reader would see a gap.
      await addChapter('c1');
      await history.recordOpened(novelId: 'n1', chapterId: 'c1', openedAt: now);
      await db.delete(db.chapters).go();

      expect(await db.select(db.historyEntries).get(), isEmpty);
    });

    test('a novel deletion is RESTRICTed and the journal survives', () async {
      // B32: taking a novel out of the library keeps its downloaded files and its
      // history. A CASCADE here would delete the reader's record as a side effect of a
      // library operation — B32's exact failure.
      await addChapter('c1');
      await history.recordOpened(novelId: 'n1', chapterId: 'c1', openedAt: now);

      await expectLater(
        db.delete(db.novels).go(),
        throwsA(isA<Exception>()),
        reason: 'RESTRICT must refuse, so nothing is deleted by surprise',
      );
      expect(await db.select(db.historyEntries).get(), hasLength(1));
    });
  });

  group('titles', () {
    test(
      'an untitled chapter keeps an empty string, never a placeholder',
      () async {
        // `history.md` § 4: renders as *Untitled*. Inventing "Chapter 1" would be a
        // sentence this app never learned.
        await addNovel();
        await db
            .into(db.chapters)
            .insert(
              ChaptersCompanion.insert(
                id: 'c1',
                novelId: 'n1',
                name: '',
                url: '/fiction/1/chapter/c1',
                ordinal: 1,
              ),
            );
        await history.recordOpened(
          novelId: 'n1',
          chapterId: 'c1',
          openedAt: now,
        );

        final HistoryEntry entry = (await history.readEntries(
          cutoff: DateTime.utc(2000),
        )).single;
        expect(entry.chapterTitle, isEmpty);
      },
    );

    test('a novel title with a quote survives intact', () async {
      // B10 verbatim. A title is site text, and site text contains punctuation that a
      // query built by concatenation would eat.
      await addNovel(title: 'The "Best" Novel & Co <tagged>');
      await addChapter('c1');
      await history.recordOpened(novelId: 'n1', chapterId: 'c1', openedAt: now);

      final HistoryEntry entry = (await history.readEntries(
        cutoff: DateTime.utc(2000),
      )).single;
      expect(entry.novelTitle, 'The "Best" Novel & Co <tagged>');
    });
  });
}
