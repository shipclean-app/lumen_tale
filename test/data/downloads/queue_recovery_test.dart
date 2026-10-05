// forge:slice 5-2, 5-3
// Lumen Tale — the two repository operations `5-2` and `5-3` added: the session reset and
// *Retry*.
//
// `5-2` § 11.1's `resetInterruptedToQueued` block and `5-3` § 11.1's `retry` block, against a
// real in-memory drift database.
//
// ## ⚠️ **`test()`, NEVER `testWidgets()`** — the rows below are not widgets, but the file's
// neighbour writes real files and this one opens a real connection; a `testWidgets` zone
// would make the drift futures behave differently from production for no benefit.
//
// | rule | the row |
// |---|---|
// | E15 | 2 `downloading` rows → `queued`, `started_at` back to `null` |
// | B20 | `attempts` survives the reset |
// | B6, ADR-022 | no `downloaded_at` is touched by the reset |
// | B19 | `clearUnfinished`: 3 `done` + 2 `queued` → 2 removed, 3 kept |
// | B32, C4 | `clearUnfinished` touches no `chapters` row and clears no mark |
// | B19 | `clearUnfinished` is idempotent — a second call removes 0 |
// | B24 | `retry`: a `failed` row → `queued`, **last** position, `attempts` kept, code cleared |
// | B24 | `retry` refuses a `downloading` row and a `done` row |

import 'package:drift/drift.dart' show OrderingTerm, Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumen_tale/core/database/app_database.dart';
import 'package:lumen_tale/data/downloads/drift_download_queue_repository.dart';
import 'package:lumen_tale/domain/downloads/queue_entry.dart';

final class Fixture {
  Fixture(this.db, this.repo);

  final AppDatabase db;
  final DriftDownloadQueueRepository repo;

  Future<void> close() => db.close();
}

Future<Fixture> fixture({int chapters = 3}) async {
  final AppDatabase db = AppDatabase.forTesting(NativeDatabase.memory());
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
            ordinal: i,
          ),
        );
  }
  return Fixture(db, DriftDownloadQueueRepository(db));
}

/// Puts a row into a state the queue could not reach on its own, which is how a **process
/// death** is modelled: `5-1` marks `downloading` and a kill happens before `markDone`.
///
/// ⚠️ **THE TEST WRITES THIS STATE DIRECTLY, AND THAT IS THE POINT.** Simulating the kill by
/// running the loop and interrupting it would couple this row to the loop's timing; the claim
/// here is about what the reset does to a row that says `downloading`, and a row that says it
/// is a row that says it however it got there.
Future<void> forceState(
  Fixture f,
  String queueItemId,
  DownloadState state, {
  int attempts = 0,
  String errorCode = '',
}) async {
  await (f.db.update(
    f.db.queueItems,
  )..where(($QueueItemsTable t) => t.id.equals(queueItemId))).write(
    QueueItemsCompanion(
      state: Value<DownloadState>(state),
      attempts: Value<int>(attempts),
      errorCode: Value<String>(errorCode),
      startedAt: Value<DateTime?>(
        // ⚠️ **A NON-NULL STAMP FOR EVERY NON-`queued` STATE, INCLUDING `failed`.** The reset's
        // contract is "`started_at = NULL`", so the fixture must actually carry a stamp for
        // the row to lose one — a fixture that never set it would let a reset that wrote
        // nothing at all pass this test.
        state == DownloadState.queued ? null : DateTime.utc(2026, 3, 14),
      ),
    ),
  );
}

Future<Map<String, DateTime?>> marksOf(Fixture f) async {
  final List<ChapterRow> rows = await f.db.select(f.db.chapters).get();
  return <String, DateTime?>{
    for (final ChapterRow row in rows) row.id: row.downloadedAt,
  };
}

Future<List<QueueRow>> rowsInOrder(Fixture f) =>
    (f.db.select(f.db.queueItems)
          ..orderBy(<OrderingTerm Function($QueueItemsTable)>[
            ($QueueItemsTable t) => OrderingTerm.asc(t.queuePosition),
          ]))
        .get();

void main() {
  group('E15 / B20 — `resetInterruptedToQueued` brings a killed queue back', () {
    test('⚠️ two `downloading` rows → `queued`, and `started_at` is null again', () async {
      final Fixture f = await fixture(chapters: 5);
      addTearDown(f.close);
      await f.repo.enqueue(<String>['c0', 'c1', 'c2', 'c3', 'c4']);
      // ⚠️ **ONE `enqueue` CALL, AND THE ROWS ARE FORCED AFTERWARDS.** The second call the
      // first version of this row made returned **nothing** — `5-1` § 3.2's branch 4 skips a
      // chapter that already has a non-`done` row — so `inserted` was empty and the row
      // threw on `[0]`. A five-chapter queue with two chapters in flight is exactly E15.
      final List<QueueEntry> inserted = await f.repo.pending();
      await forceState(
        f,
        inserted[1].id,
        DownloadState.downloading,
        attempts: 1,
      );
      await forceState(
        f,
        inserted[2].id,
        DownloadState.downloading,
        attempts: 2,
      );

      final int reset = await f.repo.resetInterruptedToQueued();

      expect(
        reset,
        2,
        reason:
            '§ 3.1 step 1: "n = repo.resetInterruptedToQueued()" and the count is what the '
            'screen would report if it ever needed to',
      );
      final List<QueueRow> rows = await rowsInOrder(f);
      expect(
        rows.where((QueueRow r) => r.state == DownloadState.downloading).length,
        0,
        reason:
            '⚠️ **NOTHING IS LEFT `downloading` AFTER THE RESET.** `downloads.md` § 8: '
            '"interrupted … is always reset to paused on open, never to running" — and a row '
            'still reading `downloading` would make `deriveQueueRunState` report '
            '`interrupted` on the reader\'s first frame',
      );
      for (final QueueRow row in rows.where(
        (QueueRow r) => r.startedAt != null,
      )) {
        expect(
          row.startedAt,
          isNull,
          reason:
              'E15: `started_at = NULL` — the attempt did not begin again, it is pending',
        );
      }
    });

    test(
      '⚠️ `attempts` is KEPT — B20 counts attempts, it does not reset them',
      () async {
        final Fixture f = await fixture(chapters: 2);
        addTearDown(f.close);
        final List<QueueEntry> inserted = await f.repo.enqueue(<String>[
          'c0',
          'c1',
        ]);
        await forceState(
          f,
          inserted[1].id,
          DownloadState.downloading,
          attempts: 1,
        );

        await f.repo.resetInterruptedToQueued();

        final List<QueueRow> rows = await rowsInOrder(f);
        final QueueRow resumed = rows.firstWhere(
          (QueueRow r) => r.id == inserted[1].id,
        );
        expect(
          resumed.state,
          DownloadState.queued,
          reason: 'the row is pending again',
        );
        expect(
          resumed.attempts,
          1,
          reason:
              'B20: "the chapter is fetched again from the start", and `attempts` is what '
              'distinguishes that from a first fetch. Zeroing it here would make the resume and '
              'a fresh download indistinguishable — and `5-3` DISPLAYS the count (E18: "the '
              'attempt count is shown, because a threshold being applied is a thing the reader '
              'deserves to know about")',
        );
      },
    );

    test('⚠️ `error_code` is KEPT — an interruption is not a failure', () async {
      final Fixture f = await fixture(chapters: 2);
      addTearDown(f.close);
      final List<QueueEntry> inserted = await f.repo.enqueue(<String>[
        'c0',
        'c1',
      ]);
      await forceState(
        f,
        inserted[0].id,
        DownloadState.downloading,
        attempts: 1,
        errorCode: 'no_connection',
      );

      await f.repo.resetInterruptedToQueued();

      final QueueRow row = (await rowsInOrder(
        f,
      )).firstWhere((QueueRow r) => r.id == inserted[0].id);
      expect(
        row.errorCode,
        'no_connection',
        reason:
            '§ 3.1: "`error_code` is conserved: this is not a failure, it is an interruption". '
            'Clearing it would also be harmless, but keeping it is what lets the screen still '
            'say *Stopped — no connection* after a reopen, which is E7',
      );
    });

    test(
      '⚠️ NO `downloaded_at` is touched, and NONE of the rows is marked (B6, ADR-022)',
      () async {
        final Fixture f = await fixture();
        addTearDown(f.close);
        final List<QueueEntry> inserted = await f.repo.enqueue(<String>[
          'c0',
          'c1',
          'c2',
        ]);
        await forceState(
          f,
          inserted[0].id,
          DownloadState.downloading,
          attempts: 1,
        );
        final Map<String, DateTime?> before = await marksOf(f);

        await f.repo.resetInterruptedToQueued();

        expect(
          await marksOf(f),
          before,
          reason:
              'ADR-022: the mark is `2-3`’s to write, after its atomic rename, and the reset '
              'writes nothing to `chapters` at all. A chapter that was interrupted was never '
              'marked — which is the safe direction B6 requires',
        );
        expect(
          (await marksOf(f)).values.every((DateTime? mark) => mark == null),
          isTrue,
          reason:
              '⚠️ **AND NO ROW BECAME A MARKED CHAPTER.** B6: an item `queued`, `downloading` '
              'or `failed` always has `downloadedAt == null`; the reset moves one between the '
              'first two and never creates the third condition',
        );
      },
    );

    test('⚠️ a queue with nothing in flight resets 0 rows', () async {
      final Fixture f = await fixture(chapters: 2);
      addTearDown(f.close);
      await f.repo.enqueue(<String>['c0', 'c1']);

      expect(
        await f.repo.resetInterruptedToQueued(),
        0,
        reason:
            'E15: the common opening is "killed **between** two chapters", which leaves no '
            '`downloading` row — and `5-2` § 3.1’s table says 0 rows touched, `paused`, '
            '`12 of 50 downloaded`',
      );
    });
  });

  group('B19 / B32 / C4 — `clearUnfinished` IS the cancellation', () {
    test('⚠️ 3 `done` + 2 `queued` → 2 removed, 3 kept', () async {
      final Fixture f = await fixture(chapters: 5);
      addTearDown(f.close);
      final List<QueueEntry> inserted = await f.repo.enqueue(<String>[
        'c0',
        'c1',
        'c2',
        'c3',
        'c4',
      ]);
      for (final QueueEntry row in inserted.take(3)) {
        await forceState(f, row.id, DownloadState.done);
      }

      final int removed = await f.repo.clearUnfinished();

      expect(
        removed,
        2,
        reason:
            '§ 3.4: "Supprime les lignes non `done` — l\'annulation EST une suppression", and '
            'the count is what the snackbar turns into "Download cancelled — 12 chapters '
            'kept"',
      );
      final List<QueueRow> left = await rowsInOrder(f);
      expect(
        left.length,
        3,
        reason:
            'the twelve stored chapters keep their rows: they ARE the completed queue',
      );
      expect(
        left.every((QueueRow r) => r.state == DownloadState.done),
        isTrue,
        reason: 'and all three are `done` — B19 keeps every completed chapter',
      );
    });

    test('⚠️ NO `chapters` row is touched and NO mark is cleared (B32, C4)', () async {
      final Fixture f = await fixture(chapters: 4);
      addTearDown(f.close);
      final List<QueueEntry> inserted = await f.repo.enqueue(<String>[
        'c0',
        'c1',
        'c2',
        'c3',
      ]);
      await forceState(f, inserted[0].id, DownloadState.done);
      await (f.db.update(
        f.db.chapters,
      )..where(($ChaptersTable t) => t.id.equals('c0'))).write(
        ChaptersCompanion(downloadedAt: Value<DateTime?>(DateTime.utc(2026))),
      );
      final Map<String, DateTime?> before = await marksOf(f);

      await f.repo.clearUnfinished();

      expect(
        (await f.db.select(f.db.chapters).get()).length,
        4,
        reason:
            'B32: "removing a novel from the library keeps its downloaded chapters". A '
            'cancellation deletes QUEUE ROWS, which are state — never chapters, which are '
            'content',
      );
      expect(
        await marksOf(f),
        before,
        reason:
            'C4: a stored chapter leaves the phone only when the reader explicitly deletes '
            'that one (B33). `clearUnfinished` has no path to the column at all, and this row '
            'is the measurement of that',
      );
      expect(
        before['c0'],
        isNotNull,
        reason:
            'witness — a mark existed before the cancellation, so the comparison above is not '
            'comparing two sets of nulls (C8: a scan that passes vacuously is a scan nobody '
            'runs)',
      );
    });

    test('⚠️ it is IDEMPOTENT — a second call removes 0', () async {
      final Fixture f = await fixture();
      addTearDown(f.close);
      await f.repo.enqueue(<String>['c0', 'c1', 'c2']);

      expect(await f.repo.clearUnfinished(), 3, reason: 'first call');
      expect(
        await f.repo.clearUnfinished(),
        0,
        reason:
            'B19: cancelling an already-cancelled queue must remove nothing and change '
            'nothing. § 3.4 row 2: "File déjà annulée → 0 ligne supprimée"',
      );
      expect(
        (await rowsInOrder(f)).length,
        0,
        reason:
            'and the queue really is empty — the second call did not re-delete anything',
      );
    });
  });

  group('B24 / B20 — `retry` is ONE chapter, at the BACK of the queue', () {
    test(
      '⚠️ a `failed` row → `queued`, LAST position, `attempts` kept, code cleared',
      () async {
        final Fixture f = await fixture(chapters: 4);
        addTearDown(f.close);
        final List<QueueEntry> inserted = await f.repo.enqueue(<String>[
          'c0',
          'c1',
          'c2',
          'c3',
        ]);
        await forceState(
          f,
          inserted[0].id,
          DownloadState.failed,
          attempts: 2,
          errorCode: 'no_real_text',
        );
        final int maxPositionBefore = (await rowsInOrder(f)).last.queuePosition;

        final bool requeued = await f.repo.retry(inserted[0].id);

        expect(
          requeued,
          isTrue,
          reason: 'the row was `failed`, so there is something to replay',
        );
        final QueueRow row = (await rowsInOrder(
          f,
        )).firstWhere((QueueRow r) => r.id == inserted[0].id);
        expect(
          row.state,
          DownloadState.queued,
          reason: '§ 3.5: `state = queued`',
        );
        expect(
          row.attempts,
          2,
          reason:
              '⚠️ **AND `attempts` IS UNCHANGED BY THE REQUEUE.** § 3.5: "`attempts` conserved, '
              'then incremented at the start". B20 is why: a chapter that has already failed '
              'twice must read as having failed twice on the row the reader is shown, and only '
              'the NEXT `markDownloading` may take it to 3',
        );
        expect(
          row.queuePosition,
          maxPositionBefore + 1,
          reason:
              '§ 3.5: "`queue_position = MAX + 1` — the last, i.e. the back of the reading '
              'order", which is what `downloads.md` § 5 means by "it re-enters the queue and '
              'runs in reading order among the others". A retry in its old slot would put '
              'chapter 1 ahead of chapters 2 and 3 again',
        );
        expect(
          row.errorCode,
          '',
          reason:
              'the reason belonged to the PREVIOUS attempt and the next one has not failed yet. '
              'A stale code would make `deriveQueueRunState` report a stopped queue for a row '
              'that is pending',
        );
        expect(
          row.finishedAt,
          isNull,
          reason:
              'and the chapter is no longer finished — `finished_at` is the "done" stamp',
        );
      },
    );

    test(
      '⚠️ `retry` REFUSES a `downloading` row — Read-only has nothing to replay',
      () async {
        final Fixture f = await fixture(chapters: 2);
        addTearDown(f.close);
        final List<QueueEntry> inserted = await f.repo.enqueue(<String>[
          'c0',
          'c1',
        ]);
        await forceState(
          f,
          inserted[0].id,
          DownloadState.downloading,
          attempts: 1,
        );
        final List<QueueRow> before = await rowsInOrder(f);

        expect(
          await f.repo.retry(inserted[0].id),
          isFalse,
          reason:
              '`downloads.md` § 4 *Read-only*: "the running row’s controls are **absent, not '
              'disabled** … there is no meaningful state to cancel the write". Re-queueing it '
              'would put the queue in front of the chapter it is already writing',
        );
        expect(
          (await rowsInOrder(
            f,
          )).singleWhere((QueueRow r) => r.id == inserted[0].id).state,
          DownloadState.downloading,
          reason:
              '⚠️ **AND IT WROTE NOTHING.** A `retry` that returned `false` after re-queuing '
              'the row would be worse than no `retry` at all',
        );
        expect(
          (await rowsInOrder(f)).length,
          before.length,
          reason: 'no row was created and none removed',
        );
      },
    );

    test('⚠️ `retry` REFUSES a `done` row — that is B33, not a retry', () async {
      final Fixture f = await fixture(chapters: 2);
      addTearDown(f.close);
      final List<QueueEntry> inserted = await f.repo.enqueue(<String>[
        'c0',
        'c1',
      ]);
      await forceState(f, inserted[0].id, DownloadState.done);

      expect(
        await f.repo.retry(inserted[0].id),
        isFalse,
        reason:
            'B33: a `done` row is a **stored chapter**. Deleting it and re-downloading it is '
            'the reader\'s explicit, confirmed choice (`3-3`), and re-queueing it here would '
            're-fetch a file that is already whole with no confirmation at all',
      );
      expect(
        (await rowsInOrder(
          f,
        )).singleWhere((QueueRow r) => r.id == inserted[0].id).state,
        DownloadState.done,
        reason: 'the row is untouched',
      );
    });

    test('⚠️ `retry` on an unknown id returns `false` and throws nothing', () async {
      final Fixture f = await fixture();
      addTearDown(f.close);

      expect(
        await f.repo.retry('no-such-item'),
        isFalse,
        reason:
            'B24: a caller that lost a row must get an answer, not a `DatabaseException`. '
            '`markDownloading` throws here because the loop and the row disagreeing is a real '
            'defect; a Retry tap on a row that has just been cancelled is not',
      );
    });
  });
}
