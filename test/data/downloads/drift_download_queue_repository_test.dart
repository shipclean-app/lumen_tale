// forge:slice 5-1
// Lumen Tale — drift's side of the queue, and the orderings B18 depends on.
//
// `5-1` § 11.1. In-memory drift (`10-testing.md` rule 4: prefer in-memory fakes for
// drift), and **`test()`, never `testWidgets()`** — this file does no widget work, and
// a real async database under fake-async is a hang rather than a failure.
//
// | rule | the row |
// |---|---|
// | B18 | three enqueues give `queue_position` 1, 2, 3 — **globally, across two novels** |
// | B18 | the same chapter twice → ONE row (§ 3.2 branch 4) |
// | B18, B12 | a novel with no `chapters` rows is the scope reader's empty list, not an error here |
// | B18 | `pending()` is ordered by `queue_position`, NOT by `chapters.ordinal` |
// | B18, B19 | `pending()` returns ONLY `queued` rows |
// | B20 | `markDownloading` moves 0 → 1 and writes `startedAt` |
// | B20 | `markDownloading` on a `downloading` row leaves `attempts` ALONE |
// | B24, C8 | `markDone`/`markFailed` write `finishedAt`; `error_code` is `''` for done |
// | ADR-022 § 4.5 | the raw column holds the NAME `'queued'`, never the ordinal |
// | B18 | **there is no concurrency column to mis-set** |

import 'package:drift/drift.dart' show OrderingTerm, QueryRow, Value, Variable;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumen_tale/core/database/app_database.dart';
import 'package:lumen_tale/data/downloads/drift_download_queue_repository.dart';
import 'package:lumen_tale/domain/downloads/queue_entry.dart';
import 'package:lumen_tale/domain/downloads/queue_failure_code.dart';

final DateTime _epoch = DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);

/// A database, a repository and a teardown that closes the database.
final class Harness {
  Harness(this.db, this.repo);

  final AppDatabase db;
  final DriftDownloadQueueRepository repo;

  Future<void> close() => db.close();
}

Future<Harness> harness() async {
  final AppDatabase db = AppDatabase.forTesting(NativeDatabase.memory());
  return Harness(db, DriftDownloadQueueRepository(db));
}

Future<void> addNovel(
  AppDatabase db, {
  String id = 'n1',
  String title = 'The Rune Smith',
}) => db
    .into(db.novels)
    .insert(
      NovelsCompanion.insert(
        id: id,
        sourceId: 'rr',
        url: '/fiction/1/$id',
        title: title,
      ),
    );

Future<void> addChapter(
  AppDatabase db, {
  required String id,
  String novelId = 'n1',
  int ordinal = 0,
  double? number,
  bool isRead = false,
  DateTime? downloadedAt,
}) => db
    .into(db.chapters)
    .insert(
      ChaptersCompanion.insert(
        id: id,
        novelId: novelId,
        url: '/fiction/1/$novelId/$ordinal',
        name: 'Chapter $ordinal',
        number: Value<double>(number ?? -1),
        ordinal: ordinal,
        isRead: Value<bool>(isRead),
        downloadedAt: Value<DateTime?>(downloadedAt),
      ),
    );

void main() {
  group('B18 — `queue_position` is GLOBAL and follows the request', () {
    test('⚠️ three enqueues give positions 1, 2, 3 — ACROSS TWO NOVELS', () async {
      final Harness h = await harness();
      addTearDown(h.close);
      await addNovel(h.db);
      await addNovel(h.db, id: 'n2', title: 'Second');
      await addChapter(h.db, id: 'c1');
      await addChapter(h.db, id: 'c2', ordinal: 1);
      await addChapter(h.db, id: 'c3', novelId: 'n2');

      await h.repo.enqueue(<String>['c1']);
      await h.repo.enqueue(<String>['c2']);
      // ⚠️ **THE THIRD CHAPTER IS IN A DIFFERENT NOVEL.** `queue_items` has no `novel_id`
      // column and `architecture.md` § 4.5 does not provide one, so the queue is ONE
      // queue: a novel-scoped maximum would restart the numbering and interleave two
      // novels' chapters.
      await h.repo.enqueue(<String>['c3']);

      final List<QueueRow> rows =
          await (h.db.select(h.db.queueItems)
                ..orderBy(<OrderingTerm Function($QueueItemsTable)>[
                  ($QueueItemsTable t) => OrderingTerm.asc(t.queuePosition),
                ]))
              .get();

      expect(
        rows.map((QueueRow r) => r.queuePosition).toList(),
        <int>[1, 2, 3],
        reason:
            '§ 3.2 branch 3: the position is `COALESCE(MAX(queue_position), 0) + 1` over '
            'the WHOLE table. Per-novel positions would produce two chapters numbered 1',
      );
      expect(rows.map((QueueRow r) => r.chapterId).toList(), <String>[
        'c1',
        'c2',
        'c3',
      ], reason: 'and the order is the order they were enqueued in');
    });

    test('⚠️ the SAME chapter twice is enqueued ONCE (§ 3.2 branch 4)', () async {
      final Harness h = await harness();
      addTearDown(h.close);
      await addNovel(h.db);
      await addChapter(h.db, id: 'c1');

      final List<QueueEntry> first = await h.repo.enqueue(<String>['c1']);
      final List<QueueEntry> second = await h.repo.enqueue(<String>['c1']);

      expect(first, hasLength(1), reason: 'the first enqueue wrote a row');
      expect(
        second,
        isEmpty,
        reason:
            '§ 3.2 branch 4: a chapter already in the queue is SKIPPED, never '
            'duplicated. A reader who taps *Download* twice must not see the chapter '
            'twice',
      );
      expect(
        (await h.db.select(h.db.queueItems).get()).length,
        1,
        reason: 'and there is exactly one row in the table',
      );
    });

    test('⚠️ a `done` row does NOT block a fresh queue (§ 3.2)', () async {
      // ⚠️ **THE ROW § 3.2 EXPLAINS.** A `done` row means the chapter is stored, so
      // `resolveBulkChoice` already excluded it and this path is unreachable from the
      // sheet. Blocking on it would make `3-3`'s explicit *re-download* impossible —
      // which is B33's "delete a copy" twin for the queue side.
      final Harness h = await harness();
      addTearDown(h.close);
      await addNovel(h.db);
      await addChapter(h.db, id: 'c1');
      final List<QueueEntry> first = await h.repo.enqueue(<String>['c1']);
      await h.repo.markDownloading(first.single.id);
      await h.repo.markDone(first.single.id);

      final List<QueueEntry> second = await h.repo.enqueue(<String>['c1']);

      expect(
        second,
        hasLength(1),
        reason:
            '§ 3.2: `alreadyQueued` ignores `done` rows. An explicit re-download is a '
            'legitimate second queue for the same chapter',
      );
      expect(
        second.single.id,
        isNot(first.single.id),
        reason:
            '§ 7: the row id is GENERATED, never the chapter id — two queues of the same '
            'chapter must coexist, and with `chapterId` as the primary key the second '
            'would overwrite the first',
      );
    });
  });

  group('B18 — the state is a NAME, never an ordinal', () {
    // ⚠️ **THE STRING ROW.** `DownloadStateConverter` is name-based, so the column holds
    // `'queued'`. A raw query is the only way to see what is on disk, and it is the only
    // way to catch an implementation that wrote `DownloadState.queued.index` — which
    // would store 0 and silently shift every future state.
    test(
      '⚠️ a RAW read of the column says `queued`, `downloading`, `done`, `failed`',
      () async {
        final Harness h = await harness();
        addTearDown(h.close);
        await addNovel(h.db);
        await addChapter(h.db, id: 'c1');

        final QueueEntry row = (await h.repo.enqueue(<String>['c1'])).single;
        final List<String> seen = <String>[];
        Future<void> state() async {
          final List<QueryRow> raw = await h.db
              .customSelect(
                'SELECT state FROM queue_items WHERE id = ?',
                variables: <Variable<Object>>[Variable<String>(row.id)],
              )
              .get();
          seen.add(raw.single.data['state']! as String);
        }

        await state();
        await h.repo.markDownloading(row.id);
        await state();
        await h.repo.markDone(row.id);
        await state();
        final QueueEntry failed = (await h.repo.enqueue(<String>['c1'])).single;
        await h.repo.markDownloading(failed.id);
        await h.repo.markFailed(failed.id, QueueFailureCode.sourceEmpty);
        final List<QueryRow> last = await h.db
            .customSelect(
              'SELECT state FROM queue_items WHERE id = ?',
              variables: <Variable<Object>>[Variable<String>(failed.id)],
            )
            .get();
        seen.add(last.single.data['state']! as String);

        expect(
          seen,
          <String>['queued', 'downloading', 'done', 'failed'],
          reason:
              'ADR-022 § 4.5: `DownloadStateConverter` stores by NAME. Persisting an '
              'ordinal would remap every row the next time a state was inserted into the '
              'enum — silently, and in the middle of a reader\'s library',
        );
      },
    );
  });

  group('B18 / B19 — `pending()` is `queue_position` order, `queued` only', () {
    test('⚠️ the order is `queue_position`, NOT `chapters.ordinal`', () async {
      final Harness h = await harness();
      addTearDown(h.close);
      await addNovel(h.db);
      await addChapter(h.db, id: 'c1');
      await addChapter(h.db, id: 'c2', ordinal: 1);
      await addChapter(h.db, id: 'c3', ordinal: 2);

      // ⚠️ **REQUEST `c3, c1, c2` AGAINST `ordinal` `c1, c2, c3`.** The two orders
      // disagree, so a test that enqueued in ordinal order would prove nothing about the
      // column the queue actually reads.
      await h.repo.enqueue(<String>['c3', 'c1', 'c2']);

      final List<QueueEntry> pending = await h.repo.pending();

      expect(
        pending.map((QueueEntry e) => e.chapterId).toList(),
        <String>['c3', 'c1', 'c2'],
        reason:
            'B18: a hand-picked order is honoured. `queue_position` is what the queue '
            'READS; `chapters.ordinal` is what a BULK CHOICE sorts by, and re-sorting '
            'here would discard the only thing the reader expressed',
      );
      expect(
        pending,
        hasLength(3),
        reason:
            '§ 9: `pending()` has NO `LIMIT` — the `LIMIT 1` belongs at the call site so '
            'a test can read ten at once, and a limit in the query would make the '
            'ordering the one property nothing could check',
      );
    });

    test('⚠️ only `queued` rows come back', () async {
      final Harness h = await harness();
      addTearDown(h.close);
      await addNovel(h.db);
      await addChapter(h.db, id: 'c1');
      await addChapter(h.db, id: 'c2', ordinal: 1);
      await addChapter(h.db, id: 'c3', ordinal: 2);

      final List<QueueEntry> rows = await h.repo.enqueue(<String>[
        'c1',
        'c2',
        'c3',
      ]);
      // ⚠️ **`markFailed` IS GUARDED ON `state = downloading`,** so the middle row has to
      // enter the loop's state machine before it can leave it. That guard is deliberate
      // (§ 3.3: `markDone` is called after `store()` returned; a row still `queued` at
      // that point means the loop and the row disagree) — and this test pays it, which is
      // how a reader of the test discovers the transition is not free.
      await h.repo.markDownloading(rows[0].id);
      await h.repo.markDownloading(rows[1].id);
      await h.repo.markFailed(rows[1].id, QueueFailureCode.sourceEmpty);

      final List<QueueEntry> pending = await h.repo.pending();

      expect(
        pending.map((QueueEntry e) => e.chapterId).toList(),
        <String>['c3'],
        reason:
            'B19: a paused queue is `queued` WITH THE QUEUE STOPPED, not a fourth '
            'state. An in-flight row is resumed by putting it back to `queued` '
            '(5-2), and returning it here would re-enter the item the loop is already '
            'in the middle of',
      );
    });
  });

  group('B20 — `markDownloading` counts attempts, and does not double-count', () {
    test('⚠️ `attempts` goes 0 → 1 and `startedAt` becomes non-null', () async {
      final Harness h = await harness();
      addTearDown(h.close);
      await addNovel(h.db);
      await addChapter(h.db, id: 'c1');
      final QueueEntry queued = (await h.repo.enqueue(<String>['c1'])).single;

      final QueueEntry started = await h.repo.markDownloading(queued.id);

      expect(
        started.state,
        DownloadState.downloading,
        reason: 'the state moved',
      );
      expect(
        started.attempts,
        1,
        reason:
            'B20: an interrupted download resumes rather than restarting, so the '
            'attempt count is what tells a resume from a fresh fetch',
      );
      expect(
        started.startedAt,
        isNotNull,
        reason:
            'and `startedAt` is when it began — a timestamp a reader can be shown',
      );
    });

    // ⚠️ **B20'S OTHER HALF, AND E15 DEPENDS ON IT.** A loop that re-reads the head after
    // an exception must not make the attempt count say "twice", or the one record of
    // what has been tried stops distinguishing a resume from a retry.
    test('⚠️ a SECOND `markDownloading` leaves `attempts` unchanged', () async {
      final Harness h = await harness();
      addTearDown(h.close);
      await addNovel(h.db);
      await addChapter(h.db, id: 'c1');
      final QueueEntry queued = (await h.repo.enqueue(<String>['c1'])).single;

      await h.repo.markDownloading(queued.id);
      final QueueEntry again = await h.repo.markDownloading(queued.id);

      expect(
        again.attempts,
        1,
        reason:
            '§ 3.3: an item already `downloading` is returned as it is. Incrementing '
            'here would turn a resume into a second attempt and lose the distinction '
            'E15 needs to restart a chapter FROM THE BEGINNING',
      );
    });
  });

  group('B24 / C8 — `markDone` and `markFailed` write what the screen reads', () {
    test('⚠️ `done` writes `finishedAt` and CLEARS `errorCode`', () async {
      final Harness h = await harness();
      addTearDown(h.close);
      await addNovel(h.db);
      await addChapter(h.db, id: 'c1');
      final QueueEntry queued = (await h.repo.enqueue(<String>['c1'])).single;
      await h.repo.markDownloading(queued.id);
      await h.repo.markFailed(queued.id, QueueFailureCode.sourceLayoutChanged);
      // ⚠️ **THE RETRY GOES THROUGH `clearUnfinished`.** A `failed` row is NOT `done`, so
      // it still blocks a second queue for the same chapter (§ 3.2 branch 4) — which is
      // what "a chapter the reader chose twice is downloaded once" means. `5-2` is where
      // *retry* becomes a reader action; here the row is removed so the second attempt is
      // a genuinely new one.
      await h.repo.clearUnfinished();
      final QueueEntry retry = (await h.repo.enqueue(<String>['c1'])).single;
      await h.repo.markDownloading(retry.id);
      await h.repo.markDone(retry.id);

      final QueueRow row = await (h.db.select(
        h.db.queueItems,
      )..where(($QueueItemsTable t) => t.id.equals(retry.id))).getSingle();

      expect(row.state, DownloadState.done, reason: 'the state moved');
      expect(
        row.finishedAt,
        isNotNull,
        reason: 'a finished attempt has an end, and the row carries it',
      );
      expect(
        row.errorCode,
        '',
        reason:
            '§ 3.2 branch 4 writes `\'\'` and never NULL. A stale `source_layout_changed` '
            'beside `done` is a sentence the screen would have to decide not to say',
      );
    });

    test(
      '⚠️ `failed` writes the CODE, and `state=failed` does not touch `downloadedAt`',
      () async {
        final Harness h = await harness();
        addTearDown(h.close);
        await addNovel(h.db);
        await addChapter(h.db, id: 'c1');
        final QueueEntry queued = (await h.repo.enqueue(<String>['c1'])).single;
        await h.repo.markDownloading(queued.id);
        await h.repo.markFailed(queued.id, QueueFailureCode.noRealText);

        final QueueRow row = await (h.db.select(
          h.db.queueItems,
        )..where(($QueueItemsTable t) => t.id.equals(queued.id))).getSingle();
        expect(
          row.errorCode,
          QueueFailureCode.noRealText.stored,
          reason:
              'C12: `error_code` is a code from the taxonomy, never free text, so a reader '
              'on a borrowed device can say what happened out loud',
        );
        expect(row.finishedAt, isNotNull, reason: 'the attempt ended');
        final ChapterRow chapter = await (h.db.select(
          h.db.chapters,
        )..where(($ChaptersTable t) => t.id.equals('c1'))).getSingle();
        expect(
          chapter.downloadedAt,
          isNull,
          reason:
              'B19/ADR-022: a failed item is NEVER marked downloaded. There is nothing to '
              'clear — a stored chapter never enters the queue — and the absence of a mark '
              'is what makes the chapter offer itself for download again',
        );
      },
    );

    test('⚠️ `markFailed` REJECTS a code that is not in the taxonomy', () async {
      final Harness h = await harness();
      addTearDown(h.close);
      await addNovel(h.db);
      await addChapter(h.db, id: 'c1');
      final QueueEntry queued = (await h.repo.enqueue(<String>['c1'])).single;
      await h.repo.markDownloading(queued.id);

      // ⚠️ **A FREE STRING IS THE DEFECT, AND IT REACHES THE COLUMN BY SQL.**
      // `error_code` is a `TextColumn`, so nothing at the schema level stops a caller
      // writing `"error 3"` — and C12 is precisely about a reader being unable to
      // describe that. `QueueFailureCode` is the type-level half; `parse` returning
      // `null` is the runtime half.
      await h.db
          .customSelect(
            'UPDATE queue_items SET error_code = ? WHERE id = ?',
            variables: <Variable<Object>>[
              const Variable<String>('error 3'),
              Variable<String>(queued.id),
            ],
          )
          .get();
      final List<QueryRow> raw = await h.db
          .customSelect(
            'SELECT error_code FROM queue_items WHERE id = ?',
            variables: <Variable<Object>>[Variable<String>(queued.id)],
          )
          .get();
      expect(
        raw.single.data['error_code'],
        'error 3',
        reason:
            'witness — the column accepted a free string, which is why `parse` must '
            'be able to refuse it rather than defaulting',
      );

      final QueueRow row = await (h.db.select(
        h.db.queueItems,
      )..where(($QueueItemsTable t) => t.id.equals(queued.id))).getSingle();
      expect(
        QueueFailureCode.parse(row.errorCode ?? ''),
        isNull,
        reason:
            'and `QueueFailureCode.parse` answers `null` rather than guessing '
            '[causeUnknown] — a column written by an older build is UNREADABLE, and '
            'reporting a cause nobody observed is the claim C12 forbids',
      );
    });
  });

  group('B18 — there is no concurrency column to mis-set', () {
    // ⚠️ **THE ROW FROM § 7 AND § 11.1.** B18 makes "one at a time" a constant, and
    // `architecture.md` § 4.5 deleted the column precisely so an implementation could not
    // change it: *"a constant expressed as a column is something an implementation could
    // change"*. This asserts the absence so the column cannot be added "just to measure
    // later".
    test('⚠️ `queue_items` has NO column that expresses concurrency', () async {
      final Harness h = await harness();
      addTearDown(h.close);
      final List<QueryRow> columns = await queueItemColumns(h);
      final List<String> names = columns
          .map((QueryRow r) => r.data['name']! as String)
          .toList();

      expect(
        names,
        containsAll(<String>[
          'id',
          'chapter_id',
          'state',
          'queue_position',
          'added_at',
          'started_at',
          'finished_at',
          'attempts',
          'error_code',
        ]),
        reason:
            'architecture.md § 4.5 lists exactly these nine. A test that asserted the '
            'present columns could not tell a tenth from a change to a comment',
      );
      expect(
        names.where(
          (String n) =>
              n.contains('concurren') ||
              n.contains('parallel') ||
              n.contains('max') ||
              n.contains('batch'),
        ),
        isEmpty,
        reason:
            '§ 7: do NOT add a concurrency column, "just to measure later". B18 makes it '
            'a constant, and the queue reads ONE item per iteration — a column would be '
            'a value an implementation could set to something B18 forbids',
      );
    });
  });

  group('B32 — `clearUnfinished` drops queue state and NOTHING else', () {
    test('⚠️ `done` rows SURVIVE and no chapter row is touched', () async {
      final Harness h = await harness();
      addTearDown(h.close);
      await addNovel(h.db);
      await addChapter(h.db, id: 'c1', downloadedAt: _epoch);
      await addChapter(h.db, id: 'c2', ordinal: 1);
      final List<QueueEntry> rows = await h.repo.enqueue(<String>['c1', 'c2']);
      await h.repo.markDownloading(rows[0].id);
      await h.repo.markDone(rows[0].id);

      final int cleared = await h.repo.clearUnfinished();

      expect(cleared, 1, reason: 'the `queued` row went');
      final List<QueueRow> left = await h.db.select(h.db.queueItems).get();
      expect(
        left.map((QueueRow r) => r.chapterId).toList(),
        <String>['c1'],
        reason:
            'and the `done` row stays: cancelling a queue is not undoing a download',
      );
      final ChapterRow chapter = await (h.db.select(
        h.db.chapters,
      )..where(($ChaptersTable t) => t.id.equals('c1'))).getSingle();
      expect(
        chapter.downloadedAt,
        isNotNull,
        reason:
            'B32: removing a novel from the library keeps its downloaded chapters, and '
            'a queue row is STATE — clearing it must never touch content',
      );
    });
  });
}

/// The `queue_items` column names, read from SQLite's own catalogue.
///
/// ⚠️ **`PRAGMA table_info`, NOT drift's generated `$columns`.** Drift exposes the
/// columns as Dart getters, so a new column would appear in the generated file and a
/// test written against the getters would be updated by the same `build_runner` run that
/// added it. Reading the schema is the only version that can fail when the schema
/// changes.
Future<List<QueryRow>> queueItemColumns(Harness h) =>
    h.db.customSelect("PRAGMA table_info('queue_items')").get();
