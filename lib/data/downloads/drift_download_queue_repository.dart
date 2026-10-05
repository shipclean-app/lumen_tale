// Lumen Tale — drift's side of the download queue.
//
// `5-1` § 2.2 / § 3.2 / § 3.4. `data/` → `core` + `domain` (`02-architecture.md`); this
// file imports **no** `features/`, which is why the runner programs against
// `ChapterWriter` rather than `ChapterStore`.
//
// ## ⚠️ THIS CLASS CANNOT WRITE `chapters`
//
// Not "does not" — *cannot*. There is no `update(_db.chapters)` anywhere below, and the
// join is a `SELECT`. B6/ADR-022: the mark is written by `2-3` after the atomic rename,
// so a `state = 'done'` written here before the file existed would mark a chapter
// downloaded that no fetch has written. `test/domain/downloads/queue_marking_isolation_test.dart`
// greps `lib/` for a third write site.
//
// ## ⚠️ `queue_position` IS THE ONLY ORDER THE QUEUE READS
//
// § 7: `ORDER BY ordinal` when enqueueing, `ORDER BY queue_position` when draining.
// `ordinal` is the site's list position and is what B9 and B18 agree on for *a choice*;
// `queue_position` is what a hand-picked order is stored as, and re-sorting it by
// `ordinal` would discard the only thing the reader expressed. `idx_queue_state` covers
// the `state` filter.

import 'package:drift/drift.dart';
import 'package:lumen_tale/core/database/app_database.dart';
import 'package:lumen_tale/core/error/app_exception.dart';
import 'package:lumen_tale/data/mappers/queue_mapper.dart';
import 'package:lumen_tale/domain/downloads/download_queue_repository.dart';
import 'package:lumen_tale/domain/downloads/queue_entry.dart';
import 'package:lumen_tale/domain/downloads/queue_failure_code.dart';

/// ⚠️ **THE PREFIX, NOT THE WHOLE ID.** `3-3`'s single-chapter enqueue writes
/// `q-<chapterId>`. Sharing that spelling would put both features on the same primary
/// key, so this one carries a per-enqueue discriminator as well — which is also what
/// § 7's *"two queues of the same chapter must be able to coexist"* requires.
const String kQueueItemIdPrefix = 'q';

final class DriftDownloadQueueRepository implements DownloadQueueRepository {
  DriftDownloadQueueRepository(this._db) : _mapper = QueueMapper(_db);

  final AppDatabase _db;
  final QueueMapper _mapper;

  /// ⚠️ **A PROCESS-LOCAL COUNTER, and it is the second half of the id.**
  ///
  /// `DateTime.now().microsecondsSinceEpoch` alone would be the obvious choice, and it
  /// is not enough on its own: two enqueues inside the same microsecond would produce
  /// the same primary key, and `insertOrIgnore` would silently **drop** the second one.
  /// The counter makes uniqueness within a process exact, and the timestamp keeps it
  /// across restarts. § 7 forbids the chapter id as the key because `3-3` offers an
  /// explicit *re-download* and the second attempt would overwrite the first.
  int _sequence = 0;

  // ── reads ────────────────────────────────────────────────────────────────────

  @override
  Stream<List<QueueEntry>> watchQueue() {
    final SimpleSelectStatement<$QueueItemsTable, QueueRow> query =
        _db.select(_db.queueItems)
          ..orderBy(<OrderingTerm Function($QueueItemsTable)>[
            ($QueueItemsTable t) => OrderingTerm.asc(t.queuePosition),
          ]);

    return query
        .join(_joins())
        .watch()
        .map(
          (List<TypedResult> rows) =>
              List<QueueEntry>.unmodifiable(rows.map(_mapper.fromJoined)),
        );
  }

  @override
  Future<List<QueueEntry>> pending() async {
    // ⚠️ **`state = 'queued'` BY ITS NAME, and no `LIMIT`.** § 3.3's table and § 9:
    // the limit belongs at the call site so a test can read ten items at once, and a
    // limit inside the query would make "the queue is in `queue_position` order" the one
    // property no test could check.
    final SimpleSelectStatement<$QueueItemsTable, QueueRow> query =
        _db.select(_db.queueItems)
          ..where(($QueueItemsTable t) => t.state.equals(kDownloadStateQueued))
          ..orderBy(<OrderingTerm Function($QueueItemsTable)>[
            ($QueueItemsTable t) => OrderingTerm.asc(t.queuePosition),
          ]);

    final List<TypedResult> rows = await query.join(_joins()).get();
    return List<QueueEntry>.unmodifiable(rows.map(_mapper.fromJoined));
  }

  // ── the write side ───────────────────────────────────────────────────────────

  @override
  Future<List<QueueEntry>> enqueue(
    List<String> chapterIds, {
    int? firstPosition,
  }) async {
    if (chapterIds.isEmpty) {
      return const <QueueEntry>[];
    }

    // ⚠️ **BRANCH 3: THE GLOBAL MAXIMUM, NEVER THE NOVEL'S.**
    //
    // `queue_items` has no `novel_id` column and `architecture.md` § 4.5 does not
    // provide one — the queue is ONE queue. A novel-scoped maximum would restart the
    // numbering for every novel and interleave two novels' chapters.
    final int first = firstPosition ?? await _nextPosition();

    final DateTime now = DateTime.now().toUtc();
    final List<String> inserted = <String>[];
    for (int i = 0; i < chapterIds.length; i++) {
      final String chapterId = chapterIds[i];

      // ⚠️ **BRANCH 4: `alreadyQueued` AND THEN `continue`.** A reader who taps
      // *Download* twice must not see a chapter twice, and a row that is `queued`,
      // `downloading` or `failed` is one the queue is already dealing with.
      //
      // ⚠️ **A `done` ROW DOES NOT BLOCK** — and § 3.2 says why: a `done` row means the
      // chapter is stored, so `resolveBulkChoice` already excluded it and the row is
      // unreachable from here. Blocking on it would make an explicit *re-download*
      // (`3-3`) impossible.
      if (await _alreadyQueued(chapterId)) {
        continue;
      }

      inserted.add(
        await _insert(chapterId: chapterId, position: first + i, addedAt: now),
      );
    }

    if (inserted.isEmpty) {
      return const <QueueEntry>[];
    }
    return _entriesByIds(inserted);
  }

  /// ⚠️ **`COALESCE(MAX(queue_position), 0) + 1`, IN SQL.**
  ///
  /// The first position of an empty queue is **1**, not 0: `0` would be indistinguishable
  /// from "never positioned", and `pending()` orders ascending, so a novel enqueued first
  /// must not be able to sort before a novel enqueued later.
  Future<int> _nextPosition() async {
    final QueryRow row = await _db
        .customSelect(
          'SELECT COALESCE(MAX(queue_position), 0) + 1 AS next FROM queue_items',
          readsFrom: <ResultSetImplementation<Object, Object?>>{_db.queueItems},
        )
        .getSingle();
    return row.read<int>('next');
  }

  Future<bool> _alreadyQueued(String chapterId) async {
    // ⚠️ **`q.state != 'done'` IS PART OF THE PREDICATE**, not an afterthought: a
    // finished row is history, and blocking on it would make `3-3`'s explicit
    // *re-download* impossible. The comparison lives in SQL because `state` carries a
    // name-based converter — `!= ?` binds a plain string and can never be mistaken for
    // an ordinal.
    final QueryRow row = await _db
        .customSelect(
          'SELECT COUNT(q.id) AS total FROM queue_items q '
          'WHERE q.chapter_id = ? AND q.state != ?',
          variables: <Variable<Object>>[
            Variable<String>(chapterId),
            const Variable<String>(kDownloadStateDone),
          ],
          readsFrom: <ResultSetImplementation<Object, Object?>>{_db.queueItems},
        )
        .getSingle();
    return row.read<int>('total') > 0;
  }

  Future<String> _insert({
    required String chapterId,
    required int position,
    required DateTime addedAt,
  }) async {
    final String id = _nextItemId(chapterId, addedAt);
    // ⚠️ **`state` WRITTEN AS THE ENUM, WHICH THE CONVERTER TURNS INTO ITS NAME.**
    // § 7: `DownloadStateConverter` is name-based and a persisted ordinal would shift
    // every future state. `InsertMode.insertOrIgnore` so a primary-key collision can
    // never overwrite an existing row — the safe direction.
    //
    // ⚠️ **NO `downloaded_at` IN THIS STATEMENT, AND NO `state = 'downloading'`.** The
    // queue enqueues; it does not download.
    await _db
        .into(_db.queueItems)
        .insert(
          QueueItemsCompanion.insert(
            id: id,
            chapterId: chapterId,
            state: const Value<DownloadState>(DownloadState.queued),
            queuePosition: position,
            addedAt: addedAt,
            // ⚠️ **`error_code: ''` AND NOT NULL.** `architecture.md` § 4.5 declares the
            // empty string as the default, and a null here would make
            // "did this fail, and why" a two-branch question at every read site.
            errorCode: const Value<String>(''),
          ),
          mode: InsertMode.insertOrIgnore,
        );
    return id;
  }

  String _nextItemId(String chapterId, DateTime addedAt) {
    _sequence += 1;
    return '$kQueueItemIdPrefix-$chapterId-${addedAt.microsecondsSinceEpoch}-$_sequence';
  }

  Future<List<QueueEntry>> _entriesByIds(List<String> ids) async {
    final SimpleSelectStatement<$QueueItemsTable, QueueRow> query =
        _db.select(_db.queueItems)
          ..where(($QueueItemsTable t) => t.id.isIn(ids))
          ..orderBy(<OrderingTerm Function($QueueItemsTable)>[
            ($QueueItemsTable t) => OrderingTerm.asc(t.queuePosition),
          ]);
    final List<TypedResult> rows = await query.join(_joins()).get();
    return List<QueueEntry>.unmodifiable(rows.map(_mapper.fromJoined));
  }

  // ── the loop's three transitions ─────────────────────────────────────────────

  @override
  Future<QueueEntry> markDownloading(String queueItemId) async {
    final QueueRow? item = await _rowById(queueItemId);
    if (item == null) {
      // ⚠️ **TYPED, NOT A `StateError`.** `13-error-handling.md` rule 1 forbids a
      // repository throwing a bare `Error`, and C12 asks for a failure a borrowed-device
      // reader can describe in words — "the queue lost track of the item it had just
      // read" is such a sentence.
      throw DatabaseException(
        'markDownloading found no queue item $queueItemId',
        operation: 'mark a queue item downloading',
      );
    }

    // ⚠️ **ALREADY `downloading` COMES BACK UNCHANGED, `attempts` INCLUDED.**
    //
    // `attempts` is B20's only record of what has been tried, so an increment on a
    // re-entry would erase the difference between "one attempt" and "two", and E15's
    // resume would have nothing left to resume from. A loop that re-reads the head after
    // an exception is exactly the case this covers.
    if (item.state == DownloadState.downloading) {
      return _entryFor(item.chapterId, queueItemId);
    }

    await (_db.update(
      _db.queueItems,
    )..where(($QueueItemsTable t) => t.id.equals(queueItemId))).write(
      QueueItemsCompanion(
        state: const Value<DownloadState>(DownloadState.downloading),
        attempts: Value<int>(item.attempts + 1),
        startedAt: Value<DateTime>(DateTime.now().toUtc()),
        // ⚠️ **THE ERROR CODE IS CLEARED ON THE WAY IN.** An item that failed once and
        // is being retried must not still be carrying the previous reason while it
        // runs: the reason belongs to an attempt, and the next one has not failed yet.
        errorCode: const Value<String>(''),
      ),
    );

    return _entryFor(item.chapterId, queueItemId);
  }

  @override
  Future<void> markDone(String queueItemId) async {
    // ⚠️ **THE GUARD IS `downloading`, NOT `!= done`.** `markDone` is called after
    // `2-3`'s `store()` returned; a row that is still `queued` at that point means the
    // loop and the row disagree, and writing `done` anyway would put a lie in the table.
    await (_db.update(_db.queueItems)..where(
          ($QueueItemsTable t) =>
              t.id.equals(queueItemId) &
              t.state.equals(kDownloadStateDownloading),
        ))
        .write(
          QueueItemsCompanion(
            state: const Value<DownloadState>(DownloadState.done),
            finishedAt: Value<DateTime>(DateTime.now().toUtc()),
            // ⚠️ **`''`, NOT THE PREVIOUS CODE.** A done item has no failure to report,
            // and a stale `source_layout_changed` beside `done` is a sentence the screen
            // would have to decide not to say.
            errorCode: const Value<String>(''),
          ),
        );
  }

  @override
  Future<void> markFailed(String queueItemId, QueueFailureCode code) async {
    // ⚠️ **`code.stored` AND NOT `code.name` AS A STRING FROM THE CALL SITE.** Both are
    // the enum's own `name` today; going through [QueueFailureCode.stored] is what makes
    // the column's value a property of the enum rather than a spelling a caller typed.
    //
    // ⚠️ **NOTHING ABOUT `chapters` HERE.** `state = failed` does not clear
    // `downloadedAt`, and there is nothing to clear: a stored chapter never enters the
    // queue (rule 3, *do not refetch*) and a chapter that was never stored has no mark.
    await (_db.update(_db.queueItems)..where(
          ($QueueItemsTable t) =>
              t.id.equals(queueItemId) &
              t.state.equals(kDownloadStateDownloading),
        ))
        .write(
          QueueItemsCompanion(
            state: const Value<DownloadState>(DownloadState.failed),
            finishedAt: Value<DateTime>(DateTime.now().toUtc()),
            errorCode: Value<String>(code.stored),
          ),
        );
  }

  @override
  Future<int> clearUnfinished() {
    // ⚠️ **`!= 'done'` AND NEVER `chapters`.** B32: removing a novel keeps its
    // downloaded chapters, and a queue row is state rather than content — the delete
    // cascade on `chapter_id` is what removes a novel's rows, and it touches no file.
    return (_db.delete(_db.queueItems)..where(
          ($QueueItemsTable t) => t.state.equals(kDownloadStateDone).not(),
        ))
        .go();
  }

  @override
  Future<int> resetInterruptedToQueued() {
    // ⚠️ **ONE `UPDATE`, AND `attempts` IS ABSENT FROM THE COMPANION ON PURPOSE.**
    //
    // § 3.1 lists exactly three writes: `state`, `started_at`, and nothing else. B20 counts
    // attempts, so an item that was on its second try before the kill is still on its
    // second try after it — and a reset that zeroed the counter would make a resume
    // indistinguishable from a first fetch, which is the one distinction E15 needs.
    //
    // `error_code` is absent for the same reason from the other side: an interruption is not
    // a failure, and clearing a reason that was never set would be a second way of saying
    // the same thing.
    return (_db.update(_db.queueItems)..where(
          ($QueueItemsTable t) => t.state.equals(kDownloadStateDownloading),
        ))
        .write(
          const QueueItemsCompanion(
            state: Value<DownloadState>(DownloadState.queued),
            startedAt: Value<DateTime?>(null),
          ),
        );
  }

  @override
  Future<bool> retry(String queueItemId) async {
    // ⚠️ **`state = 'failed'` IS THE PREDICATE, NOT A POST-HOC CHECK.** `downloads.md`
    // § 4's *Read-only* state and § 11.2's row agree: a `downloading` row has nothing to
    // replay, and a `done` row is a **stored chapter** — re-queueing it would download a
    // file that is already whole, which is `3-3`'s explicit *re-download* and B33's
    // deletion, not this. Writing `false` and changing nothing is the honest answer for
    // both.
    final QueueRow? row = await _rowById(queueItemId);
    if (row == null || row.state != DownloadState.failed) {
      return false;
    }

    // ⚠️ **`_nextPosition()`, SO A RETRIED CHAPTER GOES TO THE BACK OF THE QUEUE.**
    // § 3.5: *"it re-enters the queue and runs in reading order among the others"* — a
    // retry in its old slot would put chapter 3 ahead of chapters 4 and 5 again, which
    // B18's order does not allow and which would make a failure block everything behind it.
    await (_db.update(_db.queueItems)..where(
          ($QueueItemsTable t) =>
              t.id.equals(queueItemId) & t.state.equals(kDownloadStateFailed),
        ))
        .write(
          QueueItemsCompanion(
            state: const Value<DownloadState>(DownloadState.queued),
            queuePosition: Value<int>(await _nextPosition()),
            // ⚠️ **`attempts` IS **NOT** WRITTEN.** B20: the count must survive a retry, and
            // `markDownloading` is the only thing that increments it — so the second
            // attempt reads `2` and the reader's screen can say "tried twice".
            errorCode: const Value<String>(''),
            finishedAt: const Value<DateTime?>(null),
          ),
        );
    return true;
  }

  // ── helpers ──────────────────────────────────────────────────────────────────

  List<Join<HasResultSet, dynamic>> _joins() => <Join<HasResultSet, dynamic>>[
    // ⚠️ **INNER JOINS, DELIBERATELY.** A queue row whose chapter or novel row is gone
    // would produce a `QueueEntry` with an empty title and no source, and the loop
    // would then resolve no source for it. `queue_items.chapter_id` is `CASCADE`, so a
    // missing chapter row is already the queue row's own absence; if one is ever seen,
    // the row is simply not part of the queue the UI reads.
    innerJoin(
      _db.chapters,
      _db.chapters.id.equalsExp(_db.queueItems.chapterId),
    ),
    innerJoin(_db.novels, _db.novels.id.equalsExp(_db.chapters.novelId)),
  ];

  Future<QueueRow?> _rowById(String id) => (_db.select(
    _db.queueItems,
  )..where(($QueueItemsTable t) => t.id.equals(id))).getSingleOrNull();

  Future<QueueEntry> _entryFor(String chapterId, String queueItemId) async {
    final SimpleSelectStatement<$QueueItemsTable, QueueRow> query = _db.select(
      _db.queueItems,
    )..where(($QueueItemsTable t) => t.id.equals(queueItemId));
    final TypedResult row = await query.join(_joins()).getSingle();
    assert(
      row.readTable(_db.queueItems).chapterId == chapterId,
      'the join returned a different chapter than the row names',
    );
    return _mapper.fromJoined(row);
  }
}

/// ⚠️ **THE THREE STATE NAMES, WRITTEN ONCE, AS LITERALS IN SQL.**
///
/// They are SQL parameters, not a column expression, and the `DownloadStateConverter`
/// applies to column reads rather than to a hand-written predicate — so a query that
/// filtered on `DownloadState.queued` directly would bind the enum where the driver
/// expects a `String` and throw at runtime.
const String kDownloadStateQueued = 'queued';
const String kDownloadStateDownloading = 'downloading';
const String kDownloadStateDone = 'done';

/// ⚠️ **`retry` FILTERS ON IT**, and it is written here for the same reason the other three
/// are: the `DownloadStateConverter` applies to column *reads*, so a hand-written predicate
/// has to bind a name and not an enum.
const String kDownloadStateFailed = 'failed';
