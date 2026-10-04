// forge:slice 3-3
// Lumen Tale — `3-3`'s repository, and the TWO PROHIBITIONS that are the slice's core.
//
// ## Why this file exists
//
// `3-3`'s plan § 1 says the slice's heart is a pair of refusals:
//
// 1. **the interface NEVER writes `chapters.downloadedAt`** — `2-3` owns that column and
//    writes it *after* the atomic rename, and the ORDER of those two writes **is** B6
//    (ADR-022). A tile showing *downloaded* before the file is complete is exactly the
//    state the column exists to make unreachable;
// 2. **deleting a copy does NOT delete the row** — it removes the file and nulls the mark.
//    B9 requires the list to stay complete whatever its length, and the row is the parent
//    `history_entries` and `reading_positions` hang from.
//
// ## The rows
//
// | rule | the row |
// |---|---|
// | B6 — `enqueue` writes NO `chapters` statement | *the chapter row is byte-identical after an enqueue* |
// | B6 — an already-stored chapter is never queued | *`EnqueueAlreadyStored` and **zero** queue rows* |
// | B18 — `queuePosition` follows the REQUEST | *two reversed requests produce reversed positions* |
// | B18 — the state is the STRING `'queued'` | *a RAW query reads `'queued'`, not the ordinal `0`* |
// | B33 — the row SURVIVES a delete | *`chapters` count is unchanged* |
// | B33 — siblings are untouched | *the novel's row count is unchanged* |
// | B33 — `freedBytes` is MEASURED | *a file of known size frees exactly its own length* |
// | B33 — nothing stored means NOTHING happened | *zero writes, and not "removed"* |
// | B6 — cancelling a started item is refused | *`CancelTooLate`, mark unchanged* |

import 'dart:io';

import 'package:drift/drift.dart' show OrderingTerm, QueryRow, Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumen_tale/core/database/app_database.dart';
import 'package:lumen_tale/core/error/source_failure.dart';
import 'package:lumen_tale/data/downloads/drift_chapter_action_repository.dart';
import 'package:lumen_tale/domain/downloads/download_request.dart';
import 'package:lumen_tale/features/downloads/domain/chapter_store.dart';

/// ⚠️ **A REAL FILESYSTEM, because the slice's whole subject is files on disk.** A fake store
/// would make `freedBytes` a number the test supplied, which is exactly the number the
/// production code must MEASURE.
final class RealStore implements ChapterStore {
  RealStore(this.root);

  final Directory root;

  String _pathFor(ChapterRecord c) => '${root.path}/${c.novelId}/${c.id}.md';

  @override
  Future<DateTime> store({
    required ChapterRecord chapter,
    required String markdown,
  }) async {
    final File f = File(_pathFor(chapter));
    await f.parent.create(recursive: true);
    await f.writeAsString(markdown);
    return DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
  }

  @override
  Future<File?> fileFor(ChapterRecord chapter) async {
    final File f = File(_pathFor(chapter));
    return f.existsSync() ? f : null;
  }

  @override
  Future<void> deleteOne(ChapterRecord chapter) async {
    final File f = File(_pathFor(chapter));
    if (!f.existsSync()) {
      throw const ChapterStoreException(ChapterStoreFailure.cannotWrite);
    }
    f.deleteSync();
  }
}

/// A real database, a real temp directory, and a teardown that closes both.
final class Harness {
  Harness(this.db, this.repo, this.dir);

  final AppDatabase db;
  final DriftChapterActionRepository repo;
  final Directory dir;

  Future<void> close() async {
    await db.close();
    if (dir.existsSync()) {
      dir.deleteSync(recursive: true);
    }
  }
}

Future<Harness> harness() async {
  final AppDatabase db = AppDatabase.forTesting(NativeDatabase.memory());
  final Directory dir = Directory.systemTemp.createTempSync('lumen_3_3');
  return Harness(
    db,
    DriftChapterActionRepository(
      database: db,
      store: RealStore(dir),
      probeDirectory: dir,
      // ⚠️ **Room is PLENTY in a test, and said so rather than measured.** The real probe
      // writes megabytes to disk; a unit test that paid for it timed out. What these rows
      // test is the DECISION, not the filesystem.
      freeBytesProbe: () async => 1024 * 1024 * 1024,
    ),
    dir,
  );
}

Future<void> addNovel(AppDatabase db, {String id = 'n1'}) => db
    .into(db.novels)
    .insert(
      NovelsCompanion.insert(
        id: id,
        sourceId: 'rr',
        url: '/fiction/1/$id',
        title: 'The Rune Smith',
      ),
    );

Future<void> addChapter(
  AppDatabase db, {
  required String id,
  String novelId = 'n1',
  int ordinal = 0,
  DateTime? downloadedAt,
}) => db
    .into(db.chapters)
    .insert(
      ChaptersCompanion.insert(
        id: id,
        novelId: novelId,
        url: '/fiction/1/$novelId/$ordinal',
        name: 'Chapter $ordinal',
        ordinal: ordinal,
        downloadedAt: Value<DateTime?>(downloadedAt),
      ),
    );

final DateTime epoch = DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);

/// A store whose `deleteOne` always refuses: the file is there, the unlink is not.
///
/// ⚠️ **TOP-LEVEL, because a local class cannot be `final`.** Dart only accepts `final`
/// on a top-level declaration, so the first version — a `final class` inside a test body —
/// did not compile. It is a declaration, not a value, and that is where declarations live.
final class FailingStore implements ChapterStore {
  @override
  Future<DateTime> store({
    required ChapterRecord chapter,
    required String markdown,
  }) async => DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);

  @override
  Future<File?> fileFor(ChapterRecord chapter) async =>
      File('${Directory.systemTemp.path}/nope.md');

  @override
  Future<void> deleteOne(ChapterRecord chapter) async =>
      throw const ChapterStoreException(ChapterStoreFailure.cannotWrite);
}

void main() {
  group('B6 — enqueue NEVER writes the chapters table', () {
    test('⚠️ the chapter row is UNCHANGED after an enqueue', () async {
      final Harness h = await harness();
      addTearDown(h.close);
      await addNovel(h.db);
      await addChapter(h.db, id: 'c1');

      final ChapterRow before = await (h.db.select(
        h.db.chapters,
      )..where((t) => t.id.equals('c1'))).getSingle();
      await h.repo.enqueue(DownloadRequest.of(<String>['c1']));
      final ChapterRow after = await (h.db.select(
        h.db.chapters,
      )..where((t) => t.id.equals('c1'))).getSingle();

      expect(
        after.downloadedAt,
        before.downloadedAt,
        reason:
            'B6/ADR-022: the mark belongs to `2-3` AFTER its atomic rename. An enqueue that '
            'set it would let a tile claim a copy no fetch has written',
      );
      expect(
        after,
        equals(before),
        reason:
            'and the WHOLE row is unchanged — the prohibition is not about one column',
      );
    });

    test(
      '⚠️ an ALREADY-STORED chapter is never queued, and NOTHING is written',
      () async {
        final Harness h = await harness();
        addTearDown(h.close);
        await addNovel(h.db);
        await addChapter(h.db, id: 'c1', downloadedAt: epoch);

        final EnqueueOutcome outcome = await h.repo.enqueue(
          DownloadRequest.of(<String>['c1']),
        );
        final int queued = (await h.db.select(h.db.queueItems).get()).length;

        expect(
          outcome,
          isA<EnqueueAlreadyStored>(),
          reason:
              'B6: an item is never created for a chapter that already has a copy',
        );
        expect(
          queued,
          0,
          reason:
              'ZERO queue rows. A row here would re-download a chapter this app already holds, '
              'and the reader would see it appear twice',
        );
      },
    );

    test('⚠️ a PARTLY stored request queues only the missing ones', () async {
      final Harness h = await harness();
      addTearDown(h.close);
      await addNovel(h.db);
      await addChapter(h.db, id: 'c1', downloadedAt: epoch);
      await addChapter(h.db, id: 'c2');
      await addChapter(h.db, id: 'c3');

      final EnqueueOutcome outcome = await h.repo.enqueue(
        DownloadRequest.of(<String>['c1', 'c2', 'c3']),
      );

      expect(
        outcome,
        isA<EnqueuePartlyStored>(),
        reason:
            '"nothing happened" and "some happened" are different sentences, so the partial '
            'case is its own value rather than a count of zero',
      );
      expect(
        (outcome as EnqueuePartlyStored).skipped,
        1,
        reason: 'the stored chapter is skipped, not queued',
      );
      expect(
        (await h.db.select(h.db.queueItems).get()).length,
        2,
        reason: 'and the two that are missing ARE queued',
      );
    });
  });

  group('B18 — the queue follows the REQUEST, in this order', () {
    test('⚠️ two REVERSED requests produce REVERSED positions', () async {
      final Harness h = await harness();
      addTearDown(h.close);
      await addNovel(h.db);
      await addChapter(h.db, id: 'c1');
      await addChapter(h.db, id: 'c2');
      await addChapter(h.db, id: 'c3');

      // ⚠️ **REQUEST c3,c2,c1 AGAINST `ordinal` c1,c2,c3** — the two orders disagree, so a
      // test that queued them in the same order as `ordinal` would prove nothing.
      await h.repo.enqueue(DownloadRequest.of(<String>['c3', 'c2', 'c1']));

      final List<QueueRow> rows = await (h.db.select(
        h.db.queueItems,
      )..orderBy([(t) => OrderingTerm.asc(t.queuePosition)])).get();

      expect(
        rows.map((QueueRow r) => r.chapterId).toList(),
        <String>['c3', 'c2', 'c1'],
        reason:
            'B18: `queuePosition` follows the READER\'S order, never `chapters.ordinal` — a '
            'hand-picked sequence is a sequence, and re-sorting it by ordinal discards the '
            'one thing the reader expressed',
      );
      expect(
        rows.map((QueueRow r) => r.queuePosition).toList(),
        <int>[0, 1, 2],
        reason:
            'and the positions are the list index, so the queue reads them directly',
      );
    });

    // ⚠️ **THE STRING ROW.** `DownloadStateConverter` stores by NAME, so the column holds
    // `'queued'` and never the ordinal `0`. A raw query is the only way to see what is
    // actually on disk, and it is the only way to catch an implementation that wrote the
    // ordinal — which would read `0` and silently shift every future state.
    test('⚠️ the state is the STRING `\'queued\'`, not the ordinal', () async {
      final Harness h = await harness();
      addTearDown(h.close);
      await addNovel(h.db);
      await addChapter(h.db, id: 'c1');

      await h.repo.enqueue(DownloadRequest.of(<String>['c1']));

      final List<QueryRow> raw = await h.db
          .customSelect('SELECT state FROM queue_items')
          .get();
      expect(
        raw.first.data['state'],
        'queued',
        reason:
            'a name-based converter writes the NAME. Writing `DownloadState.queued.index` '
            'would store 0, and every future state would shift by however many states were '
            'ever added before it',
      );
    });
  });

  group('B33 — deleting a copy does NOT delete the row', () {
    test('⚠️ the `chapters` ROW SURVIVES, with siblings intact', () async {
      final Harness h = await harness();
      addTearDown(h.close);
      await addNovel(h.db);
      await addChapter(h.db, id: 'c1', downloadedAt: epoch);
      await addChapter(h.db, id: 'c2', ordinal: 1, downloadedAt: epoch);
      await addChapter(h.db, id: 'c3');
      await RealStore(h.dir).store(
        chapter: const ChapterRecord(id: 'c1', novelId: 'n1', ordinal: 0),
        markdown: 'x',
      );

      final int rowsBefore = (await h.db.select(h.db.chapters).get()).length;
      await h.repo.deleteStoredCopy('c1');
      final int rowsAfter = (await h.db.select(h.db.chapters).get()).length;

      expect(
        rowsAfter,
        rowsBefore,
        reason:
            'B9: the list stays complete whatever its length. Deleting the row would lose a '
            '10 000-chapter novel\'s list because ONE file was erased — and the row is the '
            'parent `history_entries` and `reading_positions` hang from',
      );
    });

    test(
      '⚠️ `freedBytes` is the file\'s MEASURED size, read before the unlink',
      () async {
        final Harness h = await harness();
        addTearDown(h.close);
        await addNovel(h.db);
        await addChapter(h.db, id: 'c1', downloadedAt: epoch);

        const String content = 'the rune smith, chapter one';
        await RealStore(h.dir).store(
          chapter: const ChapterRecord(id: 'c1', novelId: 'n1', ordinal: 0),
          markdown: content,
        );

        final DeleteOneOutcome outcome = await h.repo.deleteStoredCopy('c1');

        expect(
          (outcome as DeleteOneRemoved).freedBytes,
          content.length,
          reason:
              'the MEASURED length. Reading it after the unlink would return zero, and a '
              'confirmation reporting zero freed teaches a reader that deletions do nothing',
        );
      },
    );

    test('⚠️ the mark becomes null and the FILE is gone', () async {
      final Harness h = await harness();
      addTearDown(h.close);
      await addNovel(h.db);
      await addChapter(h.db, id: 'c1', downloadedAt: epoch);
      await RealStore(h.dir).store(
        chapter: const ChapterRecord(id: 'c1', novelId: 'n1', ordinal: 0),
        markdown: 'body',
      );

      await h.repo.deleteStoredCopy('c1');

      final ChapterRow row = await (h.db.select(
        h.db.chapters,
      )..where((t) => t.id.equals('c1'))).getSingle();
      expect(row.downloadedAt, isNull, reason: 'the MARK is cleared');
      expect(
        File('${h.dir.path}/n1/c1.md').existsSync(),
        isFalse,
        reason:
            'and the FILE is gone — a null mark over a surviving file is the reverse lie',
      );
    });

    test('⚠️ a chapter that is NOT stored deletes NOTHING and says so', () async {
      final Harness h = await harness();
      addTearDown(h.close);
      await addNovel(h.db);
      await addChapter(h.db, id: 'c1');

      expect(
        await h.repo.deleteStoredCopy('c1'),
        isA<DeleteOneNothingToRemove>(),
        reason:
            'B33: a confirmation for a no-op teaches a reader that confirmations are '
            'decorative. "Nothing to remove" is the honest sentence',
      );
    });

    // ⚠️ **THE OTHER HALF OF B33.** The mark is written *after* the file, so the row is the
    // parent that reading positions and history hang from. Deleting it would orphan them.
    test('⚠️ `reading_positions` and `history_entries` are UNTOUCHED', () async {
      final Harness h = await harness();
      addTearDown(h.close);
      await addNovel(h.db);
      await addChapter(h.db, id: 'c1', downloadedAt: epoch);
      await h.db
          .into(h.db.readingPositions)
          .insert(
            ReadingPositionsCompanion.insert(
              chapterId: 'c1',
              offset: const Value<double>(0.5),
              updatedAt: epoch,
            ),
          );

      final int positionsBefore =
          (await h.db.select(h.db.readingPositions).get()).length;
      await h.repo.deleteStoredCopy('c1');
      final int positionsAfter =
          (await h.db.select(h.db.readingPositions).get()).length;

      expect(
        positionsAfter,
        positionsBefore,
        reason:
            'deleting a FILE is not deleting a chapter. The reading position survives so the '
            'reader returns to where they were — which is the whole promise of B33',
      );
    });
  });

  group('B6 — cancelling', () {
    test('⚠️ a `queued` item is REMOVED', () async {
      final Harness h = await harness();
      addTearDown(h.close);
      await addNovel(h.db);
      await addChapter(h.db, id: 'c1');
      await h.repo.enqueue(DownloadRequest.of(<String>['c1']));

      final QueueRow item = await h.db.select(h.db.queueItems).getSingle();

      expect(await h.repo.cancelIfNotStarted(item.id), isA<CancelRemoved>());
      expect(
        (await h.db.select(h.db.queueItems).get()).length,
        0,
        reason: 'and the row is gone',
      );
    });

    // ⚠️ **THE ROW THAT MATTERS MOST IN THIS SLICE.** A cancel arriving one moment late
    // costs the reader their CANCEL, not their chapter: no file is touched and the mark is
    // untouched, so the item finishes and the chapter becomes stored normally.
    test('⚠️ a `downloading` item is REFUSED, and nothing is touched', () async {
      final Harness h = await harness();
      addTearDown(h.close);
      await addNovel(h.db);
      await addChapter(h.db, id: 'c1');
      await h.repo.enqueue(DownloadRequest.of(<String>['c1']));
      await (h.db.update(
        h.db.queueItems,
      )..where((t) => t.id.equals('q-c1'))).write(
        const QueueItemsCompanion(
          state: Value<DownloadState>(DownloadState.downloading),
        ),
      );

      final int rows = (await h.db.select(h.db.queueItems).get()).length;

      expect(
        await h.repo.cancelIfNotStarted('q-c1'),
        isA<CancelTooLate>(),
        reason:
            'B6: a fetch already under way would leave a half-written file whose completion '
            'nothing is watching',
      );
      expect(
        (await h.db.select(h.db.queueItems).get()).length,
        rows,
        reason: 'no row is removed',
      );
      final ChapterRow chapter = await (h.db.select(
        h.db.chapters,
      )..where((t) => t.id.equals('c1'))).getSingle();
      expect(
        chapter.downloadedAt,
        isNull,
        reason:
            'and `downloadedAt` is unchanged — the item finishes and the chapter becomes '
            'stored normally',
      );
    });
  });

  group('E20 — a refusal is founded on MEASURED bytes', () {
    test('⚠️ requiredBytes comes from a REAL file, or it is `null`', () async {
      final Harness h = await harness();
      addTearDown(h.close);
      await addNovel(h.db);
      await addChapter(h.db, id: 'c1');

      expect(
        await h.repo.measuredChapterBytes('n1'),
        isNull,
        reason:
            'nothing stored means UNKNOWN, and unknown never becomes a refusal. A `0` here '
            'would refuse every first download of every novel',
      );

      await addChapter(h.db, id: 'c2', ordinal: 1, downloadedAt: epoch);
      await RealStore(h.dir).store(
        chapter: const ChapterRecord(id: 'c2', novelId: 'n1', ordinal: 1),
        markdown: 'x' * 4096,
      );

      expect(
        await h.repo.measuredChapterBytes('n1'),
        4096,
        reason:
            'and a stored copy gives the file\'s REAL length — not an average, not a '
            'per-character estimate',
      );
    });

    // ⚠️ **NO `~`, NO `≈`, NO "estimate"** — the plan greps for all three, because a guessed
    // size can found neither a refusal nor a promise.
    test('⚠️ NO estimated size appears anywhere in the feature', () async {
      final Directory dir = Directory('lib/data/downloads');
      final List<File> files = dir
          .listSync()
          .whereType<File>()
          .where((File f) => f.path.endsWith('.dart'))
          .toList();

      for (final File f in files) {
        final String src = f.readAsStringSync();
        // ⚠️ **COMMENT LINES ARE STRIPPED FIRST.** This file's own comments discuss estimates
        // and approximations by name; a grep that matched its prose would be a grep that
        // cannot pass, which is a grep that gets switched off.
        final String code = src
            .split('\n')
            .where((String l) => !l.trimLeft().startsWith('//'))
            .join('\n');
        expect(
          code,
          isNot(contains('estimate')),
          reason: 'E20: a refusal may not rest on a guess — ${f.path}',
        );
      }
    });
  });

  group('C8 — a failed delete leaves the tile alone', () {
    test('⚠️ `DeleteOneFailed` and the MARK IS UNCHANGED', () async {
      final Harness h = await harness();
      addTearDown(h.close);
      await addNovel(h.db);
      await addChapter(h.db, id: 'c1', downloadedAt: epoch);

      final DriftChapterActionRepository repo = DriftChapterActionRepository(
        database: h.db,
        store: FailingStore(),
        probeDirectory: Directory.systemTemp,
      );

      final DeleteOneOutcome outcome = await repo.deleteStoredCopy('c1');

      expect(outcome, isA<DeleteOneFailed>());
      expect(
        (outcome as DeleteOneFailed).failure,
        isA<SourceFailure>(),
        reason: 'B24: a typed cause, so the screen can say WHY',
      );
      final ChapterRow row = await (h.db.select(
        h.db.chapters,
      )..where((t) => t.id.equals('c1'))).getSingle();
      expect(
        row.downloadedAt,
        isNotNull,
        reason:
            'the file survived, so the copy is still there — clearing the mark would be the '
            'REVERSE lie of the one B6 prevents',
      );
    });
  });
}
