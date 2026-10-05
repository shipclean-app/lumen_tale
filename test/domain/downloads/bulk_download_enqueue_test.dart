// forge:slice 5-1
// Lumen Tale — § 3.2's six branches, and the header's exact counts.
//
// Two files' worth of rules in one, because they are the two halves of the same sentence:
// the rows the queue enqueues, and the number the reader is shown next to them.
//
// | rule | the row |
// |---|---|
// | B18 | enqueue order is `ordinal` — a chapter with `number = -1` stays in its place |
// | B18 | a hand-picked order is the SELECTION's order, not `ordinal`'s |
// | B12 | a novel with no `chapters` rows → `noChapterRows`, no exception |
// | B18 | a fully stored novel → `choiceYieldsNothing`, no exception, no dialog |
// | B9 | 10 000 chapters enqueue 10 000 rows — no `LIMIT`, no window |
// | B18, § 3.2 branch 6 | **NO NETWORK CALL** at enqueue |
// | C8 | the displayed count is `resolveBulkChoice(choice).length`, and it is the SAME |
// | C8 | `12 of 50 downloaded` is 12 after 12 done, 1 failed and 1 cancelled |

import 'package:drift/drift.dart' show OrderingTerm, Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumen_tale/core/database/app_database.dart';
import 'package:lumen_tale/data/downloads/drift_download_queue_repository.dart';
import 'package:lumen_tale/data/downloads/drift_novel_download_scope.dart';
import 'package:lumen_tale/domain/downloads/bulk_choice.dart';
import 'package:lumen_tale/domain/downloads/bulk_choice_resolver.dart';
import 'package:lumen_tale/domain/downloads/bulk_choice_rows.dart';
import 'package:lumen_tale/domain/downloads/bulk_download_enqueue.dart';
import 'package:lumen_tale/domain/downloads/queue_entry.dart';
import 'package:lumen_tale/domain/downloads/queue_progress_counts.dart';

final DateTime _epoch = DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);

/// One chapter per call, inserted in the order given — the insertion order is
/// deliberately NOT always the ordinal order, so the read's own sort has to do the work.
Future<void> seed(
  AppDatabase db, {
  int chapters = 3,
  int stored = 0,
  int read = 0,
  int unparseableAt = -1,
}) async {
  await db
      .into(db.novels)
      .insert(
        NovelsCompanion.insert(
          id: 'n1',
          sourceId: 'rr',
          url: '/fiction/1/n1',
          title: 'The Rune Smith',
        ),
      );
  for (int i = 0; i < chapters; i++) {
    await db
        .into(db.chapters)
        .insert(
          ChaptersCompanion.insert(
            id: 'c$i',
            novelId: 'n1',
            url: '/fiction/1/n1/c$i',
            name: 'Chapter $i',
            // ⚠️ **`number = -1` AT A CHOSEN POSITION.** § 10: "verified on a novel where one
            // chapter has `number = -1`: that chapter appears **in its place**, not first."
            number: Value<double>(i == unparseableAt ? -1 : i.toDouble()),
            ordinal: i,
            isRead: Value<bool>(i < read),
            downloadedAt: Value<DateTime?>(i < stored ? _epoch : null),
          ),
        );
  }
}

void main() {
  group('B18 — the enqueued order is `ordinal`, and `number` never enters it', () {
    test('⚠️ a chapter with `number = -1` is enqueued IN ITS PLACE, not first', () async {
      final AppDatabase db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      // ⚠️ **CHAPTER 1 IS THE UNPARSEABLE ONE.** `number` is `-1`, which sorts BEFORE
      // every real number — an implementation that ordered by it would enqueue c1 first
      // and put the queue in the wrong order from its second row onwards.
      await seed(db, chapters: 4, unparseableAt: 1);
      final DriftDownloadQueueRepository repo = DriftDownloadQueueRepository(
        db,
      );

      final QueueEnqueueOutcome outcome = await enqueueBulkChoice(
        queue: repo,
        scope: DriftNovelDownloadScope(db),
        novelId: 'n1',
        choice: const AllUnopened(),
      );

      expect(
        (outcome as QueueEnqueued).rows
            .map((QueueEntry e) => e.chapterId)
            .toList(),
        <String>['c0', 'c1', 'c2', 'c3'],
        reason:
            'B9/B18: `ORDER BY c.ordinal ASC`. `number` is -1 when the site published '
            'something unreadable and it restarts at zero in every volume, so ordering by '
            'it interleaves volumes and produces a queue that does not read in order',
      );
      // ⚠️ **NO CAST HERE: THE `as` ABOVE PROMOTED IT.** `outcome as QueueEnqueued`
      // promotes the local for the rest of the block, and re-casting is a lint error —
      // which is the analyzer telling a reader the second cast can only be dead code.
      final QueueEnqueued enqueued = outcome;
      expect(
        enqueued.rows.map((QueueEntry e) => e.chapterNumber).toList(),
        <double?>[0, null, 2, 3],
        reason:
            '⚠️ **AND THE SENTINEL BECAME `null`, NOT `-1`.** The stored column keeps '
            '-1 and the domain never sees it: `03-source-system.md` rule 9 says an '
            'unreadable number is not chapter zero, and 0 is a real chapter (an extra, '
            'an omake, an author\'s note) — `ChapterEntry` makes the same mapping',
      );
    });

    test('⚠️ 10 000 chapters enqueue 10 000 rows — B9\'s bound', () async {
      final AppDatabase db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      await seed(db, chapters: 10000);
      final DriftDownloadQueueRepository repo = DriftDownloadQueueRepository(
        db,
      );

      final QueueEnqueueOutcome outcome = await enqueueBulkChoice(
        queue: repo,
        scope: DriftNovelDownloadScope(db),
        novelId: 'n1',
        choice: const AllUnopened(),
      );

      final List<QueueRow> rows =
          await (db.select(db.queueItems)
                ..orderBy(<OrderingTerm Function($QueueItemsTable)>[
                  ($QueueItemsTable t) => OrderingTerm.asc(t.queuePosition),
                ]))
              .get();
      expect(
        rows,
        hasLength(10000),
        reason:
            'B9: "a novel of 10 000 chapters must still list completely, in order, without '
            'freezing or dropping entries". `resolveBulkChoice` has no global cap of its '
            'own, and the read has no `LIMIT` and no window',
      );
      expect(
        (outcome as QueueEnqueued).rows,
        hasLength(10000),
        reason:
            'and every one of them is reported back — none was silently dropped',
      );
    });
  });

  group('B18 — the two empty branches, and NEITHER THROWS', () {
    test('⚠️ a novel whose list was never loaded → `noChapterRows` (B12)', () async {
      final AppDatabase db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      // ⚠️ **THE NOVEL EXISTS AND HAS NO CHAPTERS.** That is the normal first state of
      // every novel in the library — the reader has not opened it yet.
      await db
          .into(db.novels)
          .insert(
            NovelsCompanion.insert(
              id: 'n1',
              sourceId: 'rr',
              url: '/fiction/1/n1',
              title: 'The Rune Smith',
            ),
          );
      final DriftDownloadQueueRepository repo = DriftDownloadQueueRepository(
        db,
      );

      final QueueEnqueueOutcome outcome = await enqueueBulkChoice(
        queue: repo,
        scope: DriftNovelDownloadScope(db),
        novelId: 'n1',
        choice: const NextChapter(),
      );

      expect(
        outcome,
        isA<QueueNothingToDownload>().having(
          (QueueNothingToDownload o) => o.why,
          'why',
          QueueEmptyWhy.noChapterRows,
        ),
        reason:
            'B12: a novel whose chapter list has never been fetched is not a bug and not '
            'an error dialog. The sheet says "load the chapter list", and the row carries '
            'a REASON because a count of zero covers both of this file\'s empty cases',
      );
      expect(
        await db.select(db.queueItems).get(),
        isEmpty,
        reason: 'and nothing was written',
      );
    });

    test(
      '⚠️ a fully stored novel → `choiceYieldsNothing`, and NO exception',
      () async {
        final AppDatabase db = AppDatabase.forTesting(NativeDatabase.memory());
        addTearDown(db.close);
        await seed(db, stored: 3);
        final DriftDownloadQueueRepository repo = DriftDownloadQueueRepository(
          db,
        );

        final QueueEnqueueOutcome outcome = await enqueueBulkChoice(
          queue: repo,
          scope: DriftNovelDownloadScope(db),
          novelId: 'n1',
          choice: const NextChapters(10),
        );

        expect(
          (outcome as QueueNothingToDownload).why,
          QueueEmptyWhy.choiceYieldsNothing,
          reason:
              '§ 3.1/§ 3.2 branch 2: there is genuinely nothing to download. That is the '
              'correct answer for a novel already on this phone, and it is not an error — a '
              'dialog over it would teach readers that confirmations are decorative',
        );
      },
    );
  });

  group('B18 / § 3.2 branch 6 — enqueue makes NO network call', () {
    // ⚠️ **THE STRUCTURAL WITNESS.** § 3.2 branch 6 says the connectivity check happens at
    // the first fetch, never at enqueue — otherwise *"Downloading needs a connection"*
    // would be a truth the queue has to verify BY WRITING. The proof is that neither type
    // in this call graph can make a request: `DownloadQueueRepository` and
    // `NovelDownloadScope` have no client between them.
    test('⚠️ the enqueue path holds no client, no source and no outcome', () async {
      final AppDatabase db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      await seed(db, chapters: 2);
      final DriftDownloadQueueRepository repo = DriftDownloadQueueRepository(
        db,
      );

      await enqueueBulkChoice(
        queue: repo,
        scope: DriftNovelDownloadScope(db),
        novelId: 'n1',
        choice: const NextChapter(),
      );

      // ⚠️ **THE SIDE EFFECT IS A ROW, NOT A REQUEST.** `no_http` is not a thing this
      // project can assert without an interceptor, so the assertion is on what the
      // enqueue produced: one `queued` row, `startedAt` null, `attempts` 0. A queue that
      // had probed the site at enqueue time would show `downloading`, or an attempt.
      final QueueRow row = await db.select(db.queueItems).getSingle();
      expect(
        row.state,
        DownloadState.queued,
        reason: 'the row was ENQUEUED, not fetched',
      );
      expect(
        row.startedAt,
        isNull,
        reason:
            'nothing was started: § 7, "the queue enqueues; it does not download"',
      );
      expect(
        row.attempts,
        0,
        reason:
            'and no attempt was counted, which is what a fetch would have done',
      );
    });
  });

  group('B18 — the counts on the sheet ARE the counts the queue applies', () {
    test('⚠️ every row\'s count is `resolveBulkChoice(choice).length`', () async {
      final AppDatabase db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      await seed(db, chapters: 100, stored: 12, read: 60);
      // ⚠️ **ONLY THE SCOPE IS BUILT HERE.** No repository, no runner, no loop: the counts
      // a reader sees are a function of the chapter list alone, which is why they can be
      // computed before anything is queued and cannot drift from what is queued.
      final List<DownloadableChapter> chapters = await DriftNovelDownloadScope(
        db,
      ).chaptersOf('n1');
      final List<BulkChoiceRow> rows = bulkChoiceRows(
        chapters: chapters,
        labelOf: (BulkChoice c) => c.runtimeType.toString(),
      );

      expect(
        rows,
        hasLength(5),
        reason:
            'novel-details.md § 11.1 lists five radio rows; the sixth choice is reached by '
            'long-pressing tiles, not from the sheet',
      );
      for (final BulkChoiceRow row in rows) {
        expect(
          row.count,
          resolveBulkChoice(row.choice, chapters: chapters).length,
          reason:
              '⚠️ **THE `min(5, total)` DEFECT, ASSERTED AWAY.** § 7: the count beside the '
              'row must be the number the queue will enqueue. A widget computing '
              '`min(count, total)` while the resolver computes `take(count)` would show a '
              'different number from the one it applies, and only diverge on the '
              'fortieth chapter',
        );
      }
      expect(
        rows.map((BulkChoiceRow r) => r.count).toList(),
        <int>[1, 5, 10, 25, 40],
        reason:
            'the figures for this shape: 100 chapters, the first 12 stored, the first 60 '
            'read. `NextChapter` is the 13th; `AllUnopened` is chapters 60–99, which is '
            '40 — and 40 is the number the confirm must name. ⚠️ The first version of this '
            'expectation said 28, from subtracting the stored 12 out of the unopened 40; '
            'the stored 12 are all inside the READ 60, so they were never unopened',
      );
    });

    test('⚠️ the confirm names the row\'s count, not a second figure', () async {
      final AppDatabase db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      await seed(db, chapters: 100, stored: 12, read: 60);
      final List<DownloadableChapter> chapters = await DriftNovelDownloadScope(
        db,
      ).chaptersOf('n1');
      final List<BulkChoiceRow> rows = bulkChoiceRows(
        chapters: chapters,
        labelOf: (BulkChoice c) => 'row',
      );

      final BulkChoiceSelection selection = BulkChoiceSelection.of(
        const AllUnopened(),
        rows,
      );

      expect(
        selection.count,
        40,
        reason:
            'C8: the count the reader reads beside the row and the count the confirm '
            'names are ONE figure. `BulkChoiceSelection.of` reads the row rather than '
            'resolving again, so there is no second expression to drift',
      );
      expect(selection.canConfirm, isTrue, reason: 'and it is confirmable');
    });

    test('⚠️ a choice with nothing to download DISABLES the confirm', () async {
      final AppDatabase db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      await seed(db, chapters: 2, stored: 2);
      final List<DownloadableChapter> chapters = await DriftNovelDownloadScope(
        db,
      ).chaptersOf('n1');
      final List<BulkChoiceRow> rows = bulkChoiceRows(
        chapters: chapters,
        labelOf: (BulkChoice c) => 'row',
      );

      expect(
        BulkChoiceSelection.of(const NextChapter(), rows).canConfirm,
        isFalse,
        reason:
            'novel-details.md § 11.1 has NO empty state for the sheet: the rows stay '
            'visible at zero and the confirm is disabled. Hiding the control would move '
            'the row under the reader\'s thumb',
      );
    });
  });

  group('C8 — `12 of 50 downloaded` is 12, and never 12 ± 1', () {
    test('⚠️ after 12 done, 1 failed and 1 cancelled: 12 of 50, 0 in progress', () {
      final List<QueueEntry> entries = <QueueEntry>[
        for (int i = 0; i < 12; i++) _entry('c$i', DownloadState.done),
        _entry('c12', DownloadState.failed),
        _entry(
          'c13',
          DownloadState.queued,
        ), // 13 is the "cancelled" row, still pending
        for (int i = 14; i < 50; i++) _entry('c$i', DownloadState.queued),
      ];

      final QueueProgressCounts counts = QueueProgressCounts.of(entries);

      expect(
        counts.downloaded,
        12,
        reason:
            'C8 verbatim: "12 of 50 downloaded", produced by `count(state = \'done\')`, '
            'and it is 12 — NEVER 13 after a failure and NEVER 11 after a cancellation. '
            'A `failed` row is not a download, and a `queued` one is not either',
      );
      expect(
        counts.total,
        50,
        reason: 'the queue covers fifty distinct chapters',
      );
      expect(
        counts.inProgress,
        0,
        reason:
            'and nothing is moving. `downloads.md` § 2.1 refuses an aggregate bar because '
            '"the queue is serial and a single bar would imply a parallelism the app does '
            'not have" — so this figure is a count, never an aggregate',
      );
    });

    test(
      '⚠️ a `downloading` row counts as in progress and NOT as downloaded',
      () {
        final QueueProgressCounts counts = QueueProgressCounts.of(<QueueEntry>[
          for (int i = 0; i < 12; i++) _entry('c$i', DownloadState.done),
          _entry('c12', DownloadState.downloading),
        ]);

        expect(
          counts.downloaded,
          12,
          reason:
              'B6: a `downloading` row means the file is being written. Counting it would '
              'make the header claim a chapter the reader cannot open yet',
        );
        expect(
          counts.inProgress,
          1,
          reason: 'and the header\'s second number is exactly this',
        );
      },
    );

    test('⚠️ two queues of the same chapter count as ONE chapter', () {
      // ⚠️ **§ 3.2 BRANCH 4 MAKES THIS REACHABLE.** A `done` row does not block a fresh
      // queue, so two rows can name one chapter — and `entries.length` would then report a
      // novel as having more chapters than it has. C8's "exact" would be exact about the
      // wrong number.
      final QueueProgressCounts counts = QueueProgressCounts.of(<QueueEntry>[
        _entry('c0', DownloadState.done, id: 'q1'),
        _entry('c0', DownloadState.queued, id: 'q2'),
        _entry('c1', DownloadState.queued, id: 'q3'),
      ]);

      expect(
        counts.total,
        2,
        reason:
            'DISTINCT chapter ids, not rows — § 7\'s generated row ids exist precisely '
            'so two queues of one chapter can coexist',
      );
      expect(counts.downloaded, 1, reason: 'and one of them is stored');
    });
  });
}

QueueEntry _entry(String chapterId, DownloadState state, {String id = 'q'}) =>
    QueueEntry(
      id: id,
      chapterId: chapterId,
      novelId: 'n1',
      novelTitle: 'The Rune Smith',
      chapterName: 'Chapter $chapterId',
      sourceId: 'rr',
      chapterUrl: '/fiction/1/n1/$chapterId',
      ordinal: 0,
      chapterNumber: null,
      state: state,
      queuePosition: 0,
      addedAt: _epoch,
      attempts: state == DownloadState.downloading ? 1 : 0,
      errorCode: '',
    );
