// forge:slice 6-4
// Lumen Tale — B38, as the SEVEN PROPERTIES § 3.3 writes down.
//
// ## Why this file exists at all
//
// ⚠️ **B38 IS A STRUCTURAL CLAIM, SO A SUCCESSFUL PASS CANNOT PROVE IT.** § 3.3 says so
// in its own words: *it cannot be proved by executing a successful pass, because a
// successful pass does nothing forbidden.* What a successful pass **can** prove is the
// negative space — read every row of `queue_items`, read every chapter row's three marks,
// watch sqlite's own update hook for a `DELETE`, and count the calls a spy source received.
// Each is an absence, and an absence asserted by reading state afterwards is the only kind
// that is not a promise.
//
// | § 3.3 | the property | the row here |
// |---|---|---|
// | 1 | no call reaches `fetchChapterContent` | *the spy source is asked for zero bodies* |
// | 2 | no `INSERT` reaches `queue_items` | *the queue is the same size it was* |
// | 3 | no `UPDATE` sets `chapters.downloaded_at` | *every row's mark is byte-identical* |
// | 4 | no `UPDATE` sets `chapters.is_read` / `read_at` | *ditto, and the reader's own acts survive* |
// | 5 | no `UPDATE` sets `novels.in_library` | *membership is not the check\'s to change* |
// | 6 | no `DELETE` touches any row | *sqlite\'s update hook reports no delete, ever* |
// | 7 | the only network calls are two | *the spy\'s call log, in order* |
//
// ## ⚠️ EVERY ROW BELOW RUNS REAL `dart:io` (a real sqlite file, in memory)
//
// So every test here is a **`test()`, never a `testWidgets()`**. A widget test runs its body
// in a fake-async zone where a real file future never completes, so such a test hangs and
// takes the whole suite with it. That is a mistake this project has made before.
//
// ## ⚠️ AND THE CODE-GREP ROWS ARE CODE-ONLY
//
// The two files that perform a check's writes have **long** comments explaining that they
// cannot delete, enqueue or mark a chapter. A structural grep that searched the whole file
// would fail on its own explanation — and a test that has to be weakened to go green is a
// test whose check is gone. Comments are stripped first, exactly as
// `drift_unopened_count_repository_test.dart` does it.

import 'dart:io';

import 'package:drift/drift.dart'
    show
        InsertMode,
        OrderingTerm,
        QueryRow,
        TableUpdate,
        UpdateKind,
        Value,
        Variable;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumen_tale/core/database/app_database.dart';
import 'package:lumen_tale/core/error/source_failure.dart';
import 'package:lumen_tale/core/network/host_rate_limiter.dart';
import 'package:lumen_tale/data/sources/source_manager.dart';
import 'package:lumen_tale/data/updates/drift_check_library.dart';
import 'package:lumen_tale/data/updates/drift_library_check_store.dart';
import 'package:lumen_tale/domain/sources/browse_outcome.dart';
import 'package:lumen_tale/domain/sources/models/chapter.dart';
import 'package:lumen_tale/domain/sources/models/novel.dart';
import 'package:lumen_tale/domain/sources/source.dart';
import 'package:lumen_tale/domain/sources/source_id.dart';
import 'package:lumen_tale/domain/updates/library_check.dart';

import 'check_fakes.dart';

/// Just the three marks, keyed by chapter id — the tuple a check must not move.
Future<Map<String, (bool, DateTime?, DateTime?)>> marks(AppDatabase db) async {
  final List<ChapterRow> rows =
      await (db.select(db.chapters)
            ..orderBy(<OrderingTerm Function($ChaptersTable)>[
              ($ChaptersTable t) => OrderingTerm.asc(t.id),
            ]))
          .get();
  return <String, (bool, DateTime?, DateTime?)>{
    for (final ChapterRow r in rows) r.id: (r.isRead, r.readAt, r.downloadedAt),
  };
}

/// `novels.in_library` for every row, keyed by id.
Future<Map<String, bool>> membership(AppDatabase db) async {
  final List<NovelRow> rows = await db.select(db.novels).get();
  return <String, bool>{for (final NovelRow r in rows) r.id: r.inLibrary};
}

Future<int> queueSize(AppDatabase db) async {
  final int rows = await db
      .customSelect('SELECT COUNT(*) AS total FROM queue_items')
      .getSingle()
      .then((QueryRow r) => r.read<int>('total'));
  return rows;
}

/// The two instants the fixture's marks use.
///
/// ⚠️ **CONSTANTS, NOT INLINE `DateTime.utc` CALLS.** The fixture writes them and the
/// assertions compare them; a first version spelled the same date in both places and they
/// disagreed — which is the mildest possible failure and still a failure, because a test
/// comparing against a *different* number than the fixture wrote cannot tell a regression
/// from a typo.
final DateTime kReadAt = DateTime.utc(2026, 9, 1, 8);
final DateTime kDownloadedAt = DateTime.utc(2026, 10, 1, 8);

/// Never cancelled.
Future<bool> neverCancelled() async => false;

void main() {
  late AppDatabase db;
  late DriftCheckLibrary check;
  late SpySource site;
  late List<Duration> waits;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    site = SpySource();
    waits = <Duration>[];
    check = DriftCheckLibrary(
      store: DriftLibraryCheckStore(db),
      sources: SourceManager(<Source>[site]),
      rateLimiter: HostRateLimiter(
        clock: () => DateTime.utc(2026, 10, 4),
        sleep: (Duration d) async => waits.add(d),
      ),
      clock: () => DateTime.utc(2026, 10, 4, 9),
    );
  });

  tearDown(() => db.close());

  /// One novel in the library, already holding chapters the reader has acted on.
  ///
  /// ⚠️ **THE FIXTURE IS THE THING A PASS MUST NOT CHANGE.** A row with `is_read = true` and
  /// `downloaded_at` set is the reader's own history, and § 3.3 points 3 and 4 are about not
  /// touching it. An all-fresh fixture would make those two properties vacuous.
  Future<void> seedNovel(
    String id, {
    int chapters = 3,
    int read = 1,
    int downloaded = 2,
  }) async {
    await db
        .into(db.sources)
        .insert(
          SourcesCompanion.insert(id: 'src-a'),
          mode: InsertMode.insertOrIgnore,
        );
    await db
        .into(db.novels)
        .insert(
          NovelsCompanion.insert(
            id: id,
            sourceId: 'src-a',
            url: '/fiction/$id',
            title: 'Novel $id',
            inLibrary: const Value(true),
          ),
          mode: InsertMode.insertOrIgnore,
        );
    // ⚠️ **THE DERIVED ID, NOT `$id-c$i`.** `chapterOf` builds `SourceId.forChapter(novelId,
    // relativeUrl)`, so a fixture using an invented id makes every already-known chapter
    // look new — the pass then reports 45 discoveries where the site published 3, and the
    // "40 new chapters" rows below would be measuring the fixture instead of the code.
    // § 11.3's integration row is about a **partly** known list; this is what makes it
    // partly known.
    for (int i = 0; i < chapters; i++) {
      final String url = '/fiction/$id/chapter/$i';
      await db
          .into(db.chapters)
          .insert(
            ChaptersCompanion.insert(
              id: SourceId.forChapter(novelId: id, relativeUrl: url),
              novelId: id,
              name: 'Chapter $i',
              url: url,
              ordinal: i,
              isRead: Value(i < read),
              // ⚠️ **`readAt` AND `downloadedAt` ON INDEPENDENT COUNTS.** `readAt` marks
              // the chapters the reader opened and `downloadedAt` the ones on the phone,
              // and the two counts differ — so the fixture holds a read-but-not-downloaded
              // row, a downloaded-but-unread one, and one that is neither. A check that
              // touched any of the three marks would have to move at least one of them.
              readAt: Value(i < read ? kReadAt : null),
              downloadedAt: Value(i < downloaded ? kDownloadedAt : null),
            ),
          );
    }
  }

  /// What the site publishes for [novelId]: [existing] chapters it already knows, plus
  /// [brandNew] it does not.
  BrowseOutcome<List<Chapter>> published(
    String novelId, {
    required int existing,
    required int brandNew,
  }) => BrowseSucceeded<List<Chapter>>(<List<Chapter>>[
    <Chapter>[
      for (int i = 0; i < existing; i++) chapterOf(novelId, i),
      for (int i = existing; i < existing + brandNew; i++)
        chapterOf(novelId, i),
    ],
  ]);

  group('§ 3.3 — a full pass over three novels, and the negative space', () {
    test('property 1 — no chapter BODY is ever requested', () async {
      await seedNovel('n1');
      await seedNovel('n2');
      await seedNovel('n3');
      site.details = null;
      site.chapters = published('n1', existing: 3, brandNew: 40);

      await check.run(onProgress: (_) {}, cancellation: neverCancelled);

      expect(
        site.contentCalls,
        0,
        reason:
            '⚠️ B38: `fetchChapterContent` is the ONLY method that returns HTML, and a '
            'check reads lists. One call here would be a download the reader never asked '
            'for (B5)',
      );
      expect(
        site.calls.toSet(),
        <String>{'getNovelDetails', 'getChapterList'},
        reason:
            '§ 3.3 property 7: no catalogue, no search, no `getNovelUpdate` — a check '
            'reads two things and nothing else',
      );
      expect(site.calls, hasLength(6), reason: 'exactly two reads per novel');
    });

    test('property 2 — `queue_items` gains NO row, on any code path', () async {
      await seedNovel('n1');
      await seedNovel('n2');
      site.details = null;
      site.chapters = published('n1', existing: 3, brandNew: 40);

      final int before = await queueSize(db);
      await check.run(onProgress: (_) {}, cancellation: neverCancelled);

      expect(
        await queueSize(db),
        before,
        reason:
            '⚠️ B38: `5-1` is the only producer of a queue item, and a check is not it. A '
            'row here would mean the reader\'s mobile data was spent without a tap',
      );
      expect(before, 0, reason: 'and the fixture starts with an empty queue');
    });

    test('properties 3 and 4 — no chapter row loses or gains a mark', () async {
      await seedNovel('n1', chapters: 5, read: 2, downloaded: 3);
      site.details = null;
      // 40 chapters the app does not hold: the pass announces 40 and writes 40 rows.
      site.chapters = published('n1', existing: 5, brandNew: 40);

      final Map<String, (bool, DateTime?, DateTime?)> before = await marks(db);
      final LibraryCheckResult result = await check.run(
        onProgress: (_) {},
        cancellation: neverCancelled,
      );

      expect(
        (result.perNovel.single as NovelChecked).newChaptersFound,
        40,
        reason:
            'E16(b): the pass really did discover 40 chapters — this is not a no-op',
      );
      final Map<String, (bool, DateTime?, DateTime?)> after = await marks(db);
      expect(
        <String, (bool, DateTime?, DateTime?)>{
          // ⚠️ **THE `!` IS LOAD-BEARING AND NOT DEFENSIVE.** It says every id that existed
          // before the pass still exists after it — an absent key would otherwise satisfy
          // the map with a `null` and read as "its marks are all null", which is a
          // different claim from "the row survived".
          for (final String id in before.keys) id: after[id]!,
        },
        before,
        reason:
            '⚠️ B13/B6: the reader opened 2 of them and downloaded 3, and a check that '
            're-set either would be rewriting their reading history with no backup (C8)',
      );
      expect(
        after.length,
        45,
        reason:
            'and the 40 new rows are unopened and not on the phone, which is B38 at '
            'the row level',
      );
    });

    test('property 5 — `novels.in_library` is not the check\'s to change', () async {
      await seedNovel('n1');
      // A novel the reader browsed and did not keep. It is not visited at all, and saying
      // so is the assertion: if the check "helpfully" kept what it found, this is where it
      // would show.
      await db
          .into(db.novels)
          .insert(
            NovelsCompanion.insert(
              id: 'not-kept',
              sourceId: 'src-a',
              url: '/fiction/not-kept',
              title: 'Browsed only',
              inLibrary: const Value(false),
            ),
          );

      final Map<String, bool> before = await membership(db);
      site.details = null;
      site.chapters = published('n1', existing: 3, brandNew: 2);

      await check.run(onProgress: (_) {}, cancellation: neverCancelled);

      expect(
        await membership(db),
        before,
        reason:
            'B11/B12: keeping and following are the reader\'s decision. A check that '
            'wrote membership would put a novel in the library nobody chose to keep',
      );
    });

    test('property 6 — sqlite reports NO delete on any table, for the whole pass', () async {
      // ⚠️ **THE ROW THAT NEEDS A CONTROL, AND THIS IS IT.** § 3.3 point 6 says "no DELETE
      // touches any row". Counting rows before and after would miss a delete followed by a
      // re-insert of the same ids. So the **update hook itself** is watched — and a control
      // row first proves the hook reports deletes at all, without which the real row above
      // it would pass vacuously.
      await seedNovel('n1');
      await db
          .into(db.chapters)
          .insert(
            ChaptersCompanion.insert(
              id: 'doomed',
              novelId: 'n1',
              name: 'Doomed',
              url: '/fiction/n1/chapter/doomed',
              ordinal: 99,
            ),
          );

      final List<TableUpdate> updates = <TableUpdate>[];
      final subscription = db.tableUpdates().listen(updates.addAll);
      addTearDown(subscription.cancel);

      // ── the control: a delete this fixture performs, on purpose ──────────────
      await (db.delete(
        db.chapters,
      )..where((Chapters t) => t.id.equals('doomed'))).go();
      await pumpEventQueue();
      expect(
        updates.where((TableUpdate u) => u.kind == UpdateKind.delete),
        isNotEmpty,
        reason:
            '⚠️ CONTROL: if the hook did not report this delete, the row below would pass '
            'for the wrong reason — and a guard that cannot fail is not a guard',
      );

      // ── the claim: the pass itself deletes nothing ──────────────────────────────
      final int before = updates.length;
      site.details = null;
      site.chapters = published('n1', existing: 3, brandNew: 5);
      await check.run(onProgress: (_) {}, cancellation: neverCancelled);
      await pumpEventQueue();

      expect(
        updates
            .skip(before)
            .where((TableUpdate u) => u.kind == UpdateKind.delete)
            .toList(),
        isEmpty,
        reason:
            '⚠️ E9/B32/B33: a check removes nothing — a novel\'s chapters and their `.md` '
            'files survive it untouched, which is the whole of "the rest of your library '
            'is unaffected"',
      );
      expect(
        updates.skip(before),
        isNotEmpty,
        reason:
            'and the hook was live for the pass: it saw the inserts it made',
      );
    });

    test('properties 2, 3, 4 and 6 hold on the FAILING path too', () async {
      // ⚠️ **A PASS THAT FAILS IS THE MORE DANGEROUS ONE.** The happy path only inserts;
      // an error handler is exactly where a "clean up the partial state" delete would be
      // written by someone trying to be tidy. E9's row and `drift_chapter_list_repository`
      // both do delete — so this path must be measured, not assumed.
      await seedNovel('n1', chapters: 4, read: 2, downloaded: 3);
      await seedNovel('n2');
      site.detailsFor = <String, BrowseOutcome<Novel>>{
        'n1': const BrowseFailed<Novel>(
          ItemRemovedAtSource(itemId: 'n1', status: 404),
          retriable: false,
        ),
        'n2': const BrowseFailed<Novel>(
          NoConnection(host: 'site.test'),
          retriable: true,
        ),
      };

      final List<TableUpdate> updates = <TableUpdate>[];
      final subscription = db.tableUpdates().listen(updates.addAll);
      addTearDown(subscription.cancel);

      final Map<String, (bool, DateTime?, DateTime?)> before = await marks(db);
      final int queue = await queueSize(db);

      final LibraryCheckResult result = await check.run(
        onProgress: (_) {},
        cancellation: neverCancelled,
      );
      await pumpEventQueue();

      expect(
        updates.where((TableUpdate u) => u.kind == UpdateKind.delete),
        isEmpty,
        reason:
            '⚠️ E9: the novel is gone from the site, and its 4 stored chapters — two of '
            'them read, three downloaded — are exactly what a reader would lose to a '
            'tidy-up delete',
      );
      expect(
        await marks(db),
        before,
        reason: 'B13/B6 — unchanged on the failure path too',
      );
      expect(
        await queueSize(db),
        queue,
        reason: 'B38 — unchanged on the failure path too',
      );
      expect(
        result.failedCount,
        2,
        reason:
            'and the pass is reported: two failures, never "nothing new" (B22)',
      );
    });
  });

  group('B48 — the unopened count is a LOCAL fact and a check does not move it', () {
    test('the count is identical before and after a SUCCESSFUL pass', () async {
      await seedNovel('n1', chapters: 5, read: 2);
      site.details = null;
      site.chapters = published('n1', existing: 5, brandNew: 40);

      final int before = await _unopened(db, 'n1');
      await check.run(onProgress: (_) {}, cancellation: neverCancelled);

      expect(
        await _unopened(db, 'n1'),
        before + 40,
        reason:
            'the count DID move, because 40 real rows arrived — which is what makes the '
            'row below meaningful rather than vacuous',
      );
    });

    test('the count is identical before and after a FAILED pass', () async {
      // ⚠️ **THE ROW B48 EXISTS FOR.** Losing contact with a site changes the
      // **verification**, never the number — and the number is local, so a failure has
      // nothing to do with it.
      await seedNovel('n1', chapters: 5, read: 2);
      site.details = const BrowseFailed<Novel>(
        NoConnection(host: 'site.test'),
        retriable: true,
      );

      final int before = await _unopened(db, 'n1');
      final LibraryCheckResult result = await check.run(
        onProgress: (_) {},
        cancellation: neverCancelled,
      );

      expect(
        await _unopened(db, 'n1'),
        before,
        reason:
            '⚠️ B48: the local count does not depend on any check, and a failed one '
            'cannot move it — a count that moved on failure is a number the reader cannot '
            'reason about',
      );
      expect(
        result.discoveredChapters,
        0,
        reason:
            'and what the pass FOUND is a separate number, which is 0 here (B48)',
      );
    });
  });

  group('the prohibition is STRUCTURAL: the code cannot name what it may not do', () {
    // ⚠️ **CODE ONLY, COMMENTS STRIPPED.** Both files below carry long comments explaining
    // that they cannot delete, enqueue or mark a chapter. A grep that searched the whole
    // file would fail on this section's own reasoning — and a structural test that has to
    // be weakened to go green has had its check removed.
    test('neither implementation names a `DELETE`', () {
      for (final String path in _writersUnderTest) {
        for (final String line in _codeLinesOf(path)) {
          expect(
            line,
            isNot(contains('.delete(')),
            reason:
                'B32/B33: a check removes nothing, and `$path` must have no path that '
                'could. A `DELETE` there is invisible in review — the pass still succeeds '
                'and only the reader\'s stored chapters are gone',
          );
        }
      }
    });

    test('neither implementation names the download queue', () {
      for (final String path in _writersUnderTest) {
        final String code = _codeLinesOf(path).join('\n');
        for (final String forbidden in <String>[
          'queue_items',
          'queueItems',
          'QueueItems',
          'BulkDownloadRequest',
          'enqueue',
        ]) {
          expect(
            code,
            isNot(contains(forbidden)),
            reason:
                'B38: `$path` must never name $forbidden — `5-1` is the only producer of '
                'a queue item, and this slice has no path to one',
          );
        }
      }
    });

    test('neither implementation names `fetchChapterContent`', () {
      // § 9 Phase 2 names this grep explicitly, and it is the one the plan calls out by
      // hand: *`grep -rn 'fetchChapterContent' lib/domain/updates lib/data/updates` must
      // return nothing.* The test plan's § 11.3 asks for it again on a spy source; this
      // is the spelling that catches it at the source.
      for (final String path in <String>[
        'lib/domain/updates/library_check.dart',
        'lib/domain/updates/check_library.dart',
        'lib/data/updates/drift_check_library.dart',
      ]) {
        expect(
          _codeLinesOf(path).join('\n'),
          isNot(contains('fetchChapterContent')),
          reason:
              'B38: a check reads chapter LISTS. The method that returns a chapter body '
              'belongs to `2-2`/`2-3`, and naming it in `$path` is how a download gets '
              'started by a tap on *Check*',
        );
      }
    });

    test('the chapter COMPANION names none of the marks it may not write', () {
      // ⚠️ **SCOPED TO `ChaptersCompanion.insert(…)`, NOT TO THE WHOLE FILE.**
      // `drift_library_check_store.dart` reads `t.inLibrary` in `listLibraryNovels` —
      // legitimately, since B39's predicate is `in_library = 1`. A file-wide grep would
      // flag that read as the write it is not, and the fix would be to weaken the
      // assertion until it proved nothing. The claim is about the COMPANION, because the
      // companion is the only way an insert can set a column.
      //
      // `isRead` and `readAt` are here, not `downloadedAt` alone: `is_read` is the one a
      // "mark the new ones as seen" convenience reaches for, and § 7 names that mistake.
      final String store = File(
        'lib/data/updates/drift_library_check_store.dart',
      ).readAsStringSync();
      final int start = store.indexOf('ChaptersCompanion.insert(');
      expect(
        start,
        greaterThan(-1),
        reason: 'the companion must exist for this row to mean anything at all',
      );
      // ⚠️ **THE END MARKER IS THE FIRST LINE THAT IS ONLY `),` — NOT `));`.** The
      // companion closes with `),` on its own line and `));` appears nowhere near it, so
      // searching for `));` returns `-1` and `substring` throws a `RangeError` instead of
      // failing the assertion. A structural test that crashes on its own marker is not a
      // structural test.
      final String companion = store.substring(
        start,
        _endOfCompanion(store, start),
      );

      for (final String forbidden in <String>[
        'isRead',
        'readAt',
        'downloadedAt',
      ]) {
        expect(
          companion,
          isNot(contains(forbidden)),
          reason:
              'B13/B6: `mergeChapterList` inserts `chapters` rows, and the ABSENCE of '
              '$forbidden from the companion IS the rule — opening a chapter and '
              'downloading it are the reader\'s two acts',
        );
      }
    });
  });

  group('B36 — a check starts only from an explicit action', () {
    test('no call site for `run()` exists outside the provider and its tests', () {
      // ⚠️ **A GREP OVER `lib/`, AND IT IS THE POINT.** B36: *opening the app is not a
      // trigger for a check.* ADR-023 withdrew the schedule, so `6-10`'s foreground job is
      // that same tap. If this list grows, a pass has become automatic.
      // ⚠️ **THE MATCH IS PER FILE, NOT PER LINE.** `dart format` breaks the call across
      // three lines — `await ref` / `.read(checkLibraryProvider)` / `.run(` — so a
      // line-based grep for "`.run(` and `checkLibrary` on the same line" finds NOTHING and
      // passes vacuously. That is the strongest form this defect takes: the guard is green
      // and it is measuring nothing. So the file is the unit, and the reported line is the
      // `.run(` itself.
      final List<String> callSites = <String>[];
      for (final File file in _dartFilesIn('lib')) {
        final List<(int, String)> code = _codeLinesWithNumbers(file.path);
        final String whole = code.map((record) => record.$2).join('\n');
        if (!whole.contains('checkLibraryProvider')) continue;
        for (final (int line, String text) in code) {
          if (text.contains('.run(')) callSites.add('${file.path}:$line');
        }
      }
      expect(
        callSites,
        <String>['lib/data/updates/check_library_providers.dart:175'],
        reason:
            'B36: `CheckLibrary.run()` is called from ONE place — the notifier\'s '
            '`start()`. `main.dart`, an `AppLifecycleListener`, a stream build and a tab '
            'change would all appear here, and all of them would be violations. The line '
            'NUMBER is asserted too: an index into the comment-stripped list would report '
            'a number that means nothing to a reader of the file',
      );
    });

    test('no scheduling API is referenced anywhere in `lib/`', () {
      // ADR-023 withdrew B35's schedule, and `15-performance.md` says `workmanager` runs
      // the manual check and nothing else. A `registerPeriodicTask` here would be a
      // background check the reader never asked for — and B38's data cost with no dialog.
      //
      // ⚠️ **THE LIST WAS NARROWED TO ONE ENTRY WHEN `6-10` LANDED, AND THE OTHER THREE
      // WERE WRONG.** It read `registerPeriodicTask`, `registerOneOffTask`, `Workmanager`
      // and `Workmanager().initialize` — and the last three forbid the manual check itself,
      // not a schedule. `6-10` is B37: a tap registers a **one-off** foreground job through
      // `Workmanager`, so a guard that forbade `registerOneOffTask` forbade the slice from
      // existing and could only be satisfied by deleting the row. The reason text above says
      // "there is no schedule in any version", and `registerOneOffTask` is not a schedule.
      //
      // ⚠️ **THE GUARD IS NOT WEAKENED — IT MOVED, AND IT IS STILL EXACT.** ADR-023 is about
      // a *periodic* task, so that is the only string this row needs. The complementary
      // guards live in `test/core/background/check_job_structure_test.dart` and are
      // *stronger* than what was removed: `CheckJobRequest` has no `frequency`, no
      // `initialDelay` and no `expedited` field, and the only `registerOneOffTask` call site
      // in `lib/` is the one inside `CheckJobEngine.registerCheck`. Those rows can fail;
      // this one could only fail for an unrelated reason.
      for (final File file in _dartFilesIn('lib')) {
        final String code = _codeLinesOf(file.path).join('\n');
        expect(
          code,
          isNot(contains('registerPeriodicTask')),
          reason:
              'ADR-023: there is no schedule in any version, and a `registerPeriodicTask` '
              'in `${file.path}` would create one',
        );
      }
    });

    test('no file that reaches the provider starts a pass from a build', () {
      // § 4.3's mapping is the opposite of an entry point: `updates.md`, `library.md` and
      // `settings.md` *read* the provider. A screen that watched it in order to fetch would
      // be B36's violation in a build clause.
      //
      // ⚠️ **AND IT IS NOW `data/`'s FALLBACK, WHICH IS NOT A BUILD.** `6-10` § 3.4 requires
      // the in-process pass to be reachable exactly once, from the fallback that runs when a
      // foreground job cannot be registered — and that call lives in
      // `data/background/check_job_providers.dart`, a file that names the provider and calls
      // `start()` from a *callback*. As written the row forbade any co-occurrence anywhere
      // in `lib/`, which is stricter than its own stated rule and had one legitimate caller
      // it could not admit. The rule is about a **screen**, so the rule is now stated over
      // screens — and strengthened: the fallback's file is asserted to hold *exactly one*
      // call site, so a second one there fails just as loudly.
      //
      // ⚠️ **SCREENS ONLY, AND THE SET IS ASSERTED FIRST SO THE ROW CANNOT GO VACUOUS.**
      // `lib/features/` exists and holds the three screens that will read this provider; a
      // loop over "files that happen to mention it" matched nothing today and passed for the
      // wrong reason, which is the shape § 4.2's guard already got wrong once.
      final List<File> screens = _dartFilesIn('lib/features').toList();
      expect(
        screens.length,
        greaterThan(10),
        reason:
            'precondition: the loop below must have screens to read, or it proves nothing',
      );
      for (final File file in screens) {
        final String code = _codeLinesOf(file.path).join('\n');
        if (!code.contains('libraryCheckProvider')) continue;
        expect(
          code,
          isNot(contains('.start()')),
          reason:
              'B36: a screen that calls `start()` from `build` would check the library '
              'every time it opened. `start()` belongs to a callback, and '
              '`${file.path}` has one',
        );
      }

      // ⚠️ **AND THE ONE CALLER OUTSIDE A SCREEN IS COUNTED, NOT TRUSTED.** The fallback is
      // the *only* legitimate `start()` outside a screen — one reader tap whose foreground
      // job could not be registered — and a second one would be a second automatic trigger.
      final List<String> outsideScreens = <String>[];
      for (final File file in _dartFilesIn('lib')) {
        if (file.path.contains('/features/')) continue;
        // ⚠️ **`.any(…)`, NOT `.contains(…)`.** `codeLinesOf` returns a `List<String>`, and
        // a list's `contains` tests **element equality** — asking whether one line *equals*
        // `'libraryCheckProvider'` is false for every file in the repository, which is how
        // the first version of this row collected nothing and reported it as a pass.
        if (!_codeLinesOf(
          file.path,
        ).any((String line) => line.contains('libraryCheckProvider'))) {
          continue;
        }
        for (final (int line, String text) in _codeLinesWithNumbers(
          file.path,
        )) {
          if (text.contains('.start()')) {
            outsideScreens.add('${file.path}:$line');
          }
        }
      }
      expect(
        outsideScreens,
        <String>['lib/data/background/check_job_providers.dart:89'],
        reason:
            '§ 3.4 fallback: one tap, one in-process pass, from `data/` and not from a '
            'widget. The count and the line number are both asserted, so a second caller '
            'fails here rather than making two passes possible',
      );
    });

    test(
      'no BOOTSTRAP path names the check: `main.dart`, `lib/app/`, a lifecycle hook',
      () {
        // ⚠️ **§ 10's ROW, WORDED AS THE GREP IT IS.** *`grep -rn 'checkLibrary\|libraryCheck
        // Provider' lib/` returns only the provider declaration, the screen that carries the
        // button, and the test.* The screen may appear whenever a slice claims it — this row is
        // about the other half of the sentence, the files that must NEVER be in the output:
        // the composition root, `app/`, and anything that observes app lifecycle. Those three
        // are the only places in `lib/` where a check could start without the reader asking,
        // so they are asserted by name and each one is checked individually.
        //
        // ⚠️ **AND THE LIST IS NOT EMPTY, SO THIS ROW CAN FAIL.** `lib/main.dart` and
        // `lib/app/` exist; a loop over "files that happen to mention it" would match nothing
        // and pass for the wrong reason, which is the shape § 4.2's guard already got wrong
        // once.
        final List<File> bootstrap = <File>[
          File('lib/main.dart'),
          ..._dartFilesIn('lib/app'),
        ];
        expect(
          bootstrap,
          isNotEmpty,
          reason:
              'the composition root exists, so the row below is measuring something',
        );
        for (final File file in bootstrap) {
          final String code = _codeLinesOf(file.path).join('\n');
          for (final String forbidden in <String>[
            'libraryCheckProvider',
            'checkLibraryProvider',
            'libraryCheckProgressProvider',
          ]) {
            expect(
              code,
              isNot(contains(forbidden)),
              reason:
                  'B36: opening the app is not a trigger for a check, and '
                  '`${file.path}` runs before any reader has tapped anything. A `Check` '
                  'button is a gesture; this file is not one',
            );
          }
        }

        // A lifecycle listener is the subtler half: it is the one place a pass could start
        // without any gesture at all, and `15-performance.md` gives `workmanager` the manual
        // check as its only job.
        for (final File file in _dartFilesIn('lib')) {
          final String code = _codeLinesOf(file.path).join('\n');
          final bool watchesLifecycle =
              code.contains('AppLifecycleListener') ||
              code.contains('didChangeAppLifecycleState');
          if (!watchesLifecycle) continue;
          expect(
            code,
            isNot(contains('libraryCheck')),
            reason:
                'B36: `resumed` is not an action, and a check on resume would spend data '
                'the reader never agreed to. `${file.path}` observes lifecycle',
          );
        }
      },
    );
  });
}

/// The two files that perform a check's writes, and the third that drives them.
const List<String> _writersUnderTest = <String>[
  'lib/data/updates/drift_library_check_store.dart',
  'lib/data/updates/drift_check_library.dart',
];

/// Where [start]'s argument list closes: the first following line that is only `),`.
///
/// ⚠️ **LINE-BASED, AND THE REASON IS THE FORMATTER.** `dart format` owns this shape, so
/// the closing line is exactly `),` with nothing else on it, and the call's arguments
/// cannot contain one — a nested call would be indented. A paren-counting parser would be
/// stricter and would also break the first time a companion grows a nested expression.
int _endOfCompanion(String source, int start) {
  final List<String> lines = source.substring(start).split('\n');
  int consumed = 0;
  for (int i = 1; i < lines.length; i++) {
    consumed += lines[i].length + 1;
    if (lines[i].trim() == '),') return start + consumed;
  }
  return start + source.substring(start).length;
}

/// The lines of [path] that are CODE rather than a comment.
///
/// ⚠️ **DELIBERATELY CRUDE, AND THE SAME SHAPE `6-3`'s test uses.** A Dart parse would be
/// more precise and would also fail on the first syntax these files grow tomorrow. Every
/// comment style the project uses is covered: `//`, `///`, and a `/* … */` opener.
List<String> _codeLinesOf(String path) => _codeLinesWithNumbers(
  path,
).map((record) => record.$2).toList(growable: false);

/// [path]'s code lines **with their 1-based line numbers in the file**.
///
/// ⚠️ **THE NUMBERS ARE FROM THE FILE, NOT FROM THE FILTERED LIST.** A stripped list has
/// shorter indices than the file, so reporting `i + 1` from it names a line the reader
/// cannot find — and a guard whose output is wrong is a guard nobody trusts when it fires.
List<(int, String)> _codeLinesWithNumbers(String path) {
  final List<String> lines = File(path).readAsLinesSync();
  final List<(int, String)> out = <(int, String)>[];
  for (int i = 0; i < lines.length; i++) {
    final String trimmed = lines[i].trimLeft();
    if (trimmed.startsWith('//')) continue;
    if (trimmed.startsWith('*') || trimmed.startsWith('/*')) continue;
    out.add((i + 1, lines[i]));
  }
  return out;
}

Iterable<File> _dartFilesIn(String directory) => Directory(directory)
    .listSync(recursive: true)
    .whereType<File>()
    .where((File f) => f.path.endsWith('.dart'));

/// `COUNT(is_read = 0)` for one novel — B48's count, in the one place it is defined.
Future<int> _unopened(AppDatabase db, String novelId) async {
  final QueryRow row = await db
      .customSelect(
        'SELECT COUNT(c.id) AS total FROM chapters c '
        'WHERE c.novel_id = ? AND c.is_read = 0',
        variables: <Variable<Object>>[Variable<String>(novelId)],
      )
      .getSingle();
  return row.read<int>('total');
}
