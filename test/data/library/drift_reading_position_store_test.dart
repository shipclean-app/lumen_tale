// forge:slice 2-6
// Lumen Tale — `2-6`'s drift implementation, round-tripped.
//
// `10-testing.md`: a repository round-trip is a high-priority test, because the whole
// of B16 is "the position survives" and a repository that drops a column makes a
// passing unit test meaningless.
//
// Every row here is about a value the store is responsible for. The pure arithmetic
// lives in `test/domain/library/position_restore_test.dart`.

import 'package:drift/drift.dart' show InsertMode;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumen_tale/core/database/app_database.dart';
import 'package:lumen_tale/data/library/drift_reading_position_store.dart';
import 'package:lumen_tale/domain/library/position_restore.dart';
import 'package:lumen_tale/domain/library/reading_position.dart';

void main() {
  late AppDatabase db;
  late DriftReadingPositionStore store;
  late DateTime now;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    now = DateTime.utc(2026, 10, 3, 12);
    store = DriftReadingPositionStore.withClock(db, () => now);
  });

  tearDown(() => db.close());

  /// `insertOrIgnore`, not `insert`: every chapter in these tests belongs to the same
  /// novel, and a helper that re-inserts the novel per chapter fails on the second
  /// call. The first version did exactly that, and four tests failed on a UNIQUE
  /// constraint that says nothing whatever about reading positions — the worst kind of
  /// failure, because it looks like the subject is broken.
  Future<void> addNovel({String id = 'n1', String title = 'A Novel'}) => db
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

  Future<void> addChapter(String id, {String novelId = 'n1'}) async {
    await addNovel();
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

  group('Round trip', () {
    test('a written position reads back identical', () async {
      await addChapter('c1');
      await store.write('c1', 512.5, contentHeight: 4096);

      final ReadingPosition? read = await store.read('c1');
      expect(read, isNotNull);
      expect(read!.chapterId, 'c1');
      expect(read.offset, 512.5);
      expect(read.contentHeight, 4096);
      expect(
        read.updatedAt.toUtc(),
        now,
        reason: 'drift returns local-zone DateTimes',
      );
    });

    test(
      'reading a chapter with no row returns null, not a zero offset',
      () async {
        await addChapter('c1');
        expect(await store.read('c1'), isNull);
      },
    );

    test('writing twice updates in place — one row per chapter', () async {
      await addChapter('c1');
      await store.write('c1', 100, contentHeight: 1000);
      await store.write('c1', 900, contentHeight: 1000);

      final rows = await db.select(db.readingPositions).get();
      expect(rows, hasLength(1), reason: 'the table is keyed by chapterId');
      expect((await store.read('c1'))!.offset, 900);
    });

    test('clear removes the row and read goes back to null', () async {
      await addChapter('c1');
      await store.write('c1', 100, contentHeight: 1000);
      await store.clear('c1');
      expect(await store.read('c1'), isNull);
    });

    test('clearing a chapter that has no position is not an error', () async {
      await addChapter('c1');
      await store.clear('c1');
      expect(await store.read('c1'), isNull);
    });
  });

  group('contentHeight: 0 is not a measurement', () {
    test('an extent of 0 is stored as null', () async {
      await addChapter('c1');
      await store.write('c1', 0, contentHeight: 0);

      final ReadingPosition? read = await store.read('c1');
      expect(
        read!.contentHeight,
        isNull,
        reason: '§ 3.1: never write a 0 height',
      );
      expect(read.offset, 0, reason: 'the offset of 0 is legitimate though');
    });

    test('a negative extent is stored as null', () async {
      await addChapter('c1');
      await store.write('c1', 120, contentHeight: -5);
      expect((await store.read('c1'))!.contentHeight, isNull);
    });

    test('a fractional extent is rounded, not truncated', () async {
      await addChapter('c1');
      await store.write('c1', 120, contentHeight: 1000.6);
      expect((await store.read('c1'))!.contentHeight, 1001);
    });

    test(
      'a null-extent row restores by PIXEL, never by an invented ratio',
      () async {
        // The whole point of the column: without it there is nothing to re-anchor by.
        await addChapter('c1');
        await store.write('c1', 300, contentHeight: 0);

        final ReadingPosition? read = await store.read('c1');
        final ResumeAt resume =
            restorePosition(stored: read, currentScrollExtent: 1200)
                as ResumeAt;

        expect(resume.anchoredByRatio, isFalse);
        expect(resume.offset, 300);
      },
    );

    test('an extent row restores by RATIO after the text grows', () async {
      await addChapter('c1');
      await store.write('c1', 500, contentHeight: 1000);

      final ResumeAt resume =
          restorePosition(
                stored: await store.read('c1'),
                currentScrollExtent: 4000,
              )
              as ResumeAt;

      expect(resume.anchoredByRatio, isTrue);
      expect(resume.offset, closeTo(2000, 1e-9));
    });
  });

  group('The offset column cannot hold nonsense', () {
    test('a negative offset is clamped to 0', () async {
      await addChapter('c1');
      await store.write('c1', -300, contentHeight: 1000);
      expect((await store.read('c1'))!.offset, 0);
    });
  });

  group('mostRecentAmong — B17, and not the history table', () {
    test('returns the newest row by updatedAt', () async {
      for (final String c in <String>['c1', 'c2', 'c3']) {
        await addChapter(c);
      }
      await store.write('c1', 10, contentHeight: 100);
      now = DateTime.utc(2026, 10, 3, 13);
      await store.write('c2', 20, contentHeight: 100);
      now = DateTime.utc(2026, 10, 3, 14);
      await store.write('c3', 30, contentHeight: 100);

      final ReadingPosition? most = await store.mostRecentAmong(<String>[
        'c1',
        'c2',
        'c3',
      ]);
      expect(most!.chapterId, 'c3');
    });

    test('an empty list is null, not a query', () async {
      expect(await store.mostRecentAmong(const <String>[]), isNull);
    });

    test('a list of chapters with no positions is null', () async {
      await addChapter('c1');
      expect(await store.mostRecentAmong(<String>['c1']), isNull);
    });

    test('it only considers the chapters it was given', () async {
      await addChapter('c1');
      await addChapter('c2');
      now = DateTime.utc(2026, 10, 3, 13);
      await store.write('c2', 20, contentHeight: 100);

      final ReadingPosition? most = await store.mostRecentAmong(<String>['c1']);
      expect(most, isNull);
      expect(
        (await store.mostRecentAmong(<String>['c1', 'c2']))!.chapterId,
        'c2',
      );
    });

    test('a tie on updatedAt is broken deterministically by chapterId', () async {
      // A fast scroll settle can produce two writes inside one millisecond. Without a
      // tiebreak the "most recent" answer is whatever SQLite returned, which makes a
      // resume non-reproducible and a test impossible to write.
      for (final String c in <String>['c1', 'c2']) {
        await addChapter(c);
        await store.write(c, 10, contentHeight: 100);
      }

      final ReadingPosition? a = await store.mostRecentAmong(<String>[
        'c1',
        'c2',
      ]);
      final ReadingPosition? b = await store.mostRecentAmong(<String>[
        'c2',
        'c1',
      ]);
      expect(a!.chapterId, b!.chapterId);
    });
  });

  group('B46 — a position is never trimmed', () {
    test('there is no retention rule anywhere in the store', () async {
      // Retention would be a DELETE with a date or a count in it. Asserted by
      // inspection of the store's surface: exactly one delete, and it takes a
      // chapterId.
      await addChapter('c1');
      await addChapter('c2');

      now = DateTime.utc(2000);
      await store.write('c1', 10, contentHeight: 100);
      now = DateTime.utc(2026, 10, 3, 14);
      await store.write('c2', 20, contentHeight: 100);

      expect(
        await store.read('c1'),
        isNotNull,
        reason: '26 years old, still here',
      );
      expect(await store.read('c2'), isNotNull);
    });

    test('deleting a novel cascades to its positions, by the schema', () async {
      // Not a retention rule — the reader removing a chapter. `ReadingPositions`
      // declares `onDelete: KeyAction.cascade`, and `core/database` turns the pragma
      // on, so this actually holds rather than merely being declared.
      await addChapter('c1');
      await store.write('c1', 10, contentHeight: 100);
      expect(await store.read('c1'), isNotNull);

      await (db.delete(db.novels)..where((Novels t) => t.id.equals('n1'))).go();

      expect(await store.read('c1'), isNull);
    });
  });

  group('updatedAt is the store\'s clock, not the caller\'s', () {
    test(
      'two writes with the same injected clock are equal, and advancing it moves on',
      () async {
        await addChapter('c1');
        await store.write('c1', 10, contentHeight: 100);
        final DateTime first = (await store.read('c1'))!.updatedAt;

        now = now.add(const Duration(minutes: 5));
        await store.write('c1', 20, contentHeight: 100);
        final DateTime second = (await store.read('c1'))!.updatedAt;

        expect(second.isAfter(first), isTrue);
        expect(second.difference(first), const Duration(minutes: 5));
      },
    );
  });
}
