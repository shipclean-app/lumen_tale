// forge:slice 6-10
// Lumen Tale — the pass as it runs in the background isolate, against a real database.
//
// ## ⚠️ WHY THIS FILE RUNS REAL SQLITE
//
// `6-10` § 3.2's invariant is structural: *"AUCUN downloadQueueItem n'est inséré, AUCUN
// chapterContent n'est récupéré, AUCUN downloadedAt n'est écrit"*. A successful pass does
// nothing forbidden, so the claim cannot be proved by running one — it is proved by reading
// the state afterwards. That needs rows to move, so the fixture seeds a reader's own marks
// (read-but-not-downloaded, downloaded-but-unread, neither) and the rows below assert every
// mark is byte-identical afterwards. `6-4`'s `check_never_downloads_test.dart` proves the
// same seven properties for the **in-process** path; this file proves the background
// wrapper adds nothing, which is the part `6-10` owns.
//
// ## ⚠️ `test()`, NEVER `testWidgets()`
//
// Every row here opens a real drift connection and awaits it. A `testWidgets` body runs in a
// fake-async zone where a real file future never completes, so such a test hangs and takes
// the whole suite with it. This project has made that mistake before.
//
// | rule | the row |
// |---|---|
// | **B38** | `queue_items` gains 0 rows; no chapter mark moves; no novel leaves the library |
// | **B39** | one progress emission per novel, and a terminal success carrying all three counts |
// | **C8** | an interrupted pass is `CheckJobInterrupted(reason: null)`, never a success |
// | **B37** | `onStopped` reports each platform reason, and releases the flag |
// | **B37** | `systemIgnoredCancelledByApp` reports **nothing** and still releases |
// | **B32** | the connection enforces `RESTRICT`, and the production path sets the pragma |

import 'package:drift/drift.dart'
    show InsertMode, OrderingTerm, QueryRow, Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumen_tale/core/background/check_job_interlock.dart';
import 'package:lumen_tale/core/database/app_database.dart';
import 'package:lumen_tale/core/error/source_failure.dart';
import 'package:lumen_tale/core/network/host_rate_limiter.dart';
import 'package:lumen_tale/data/background/background_check_runner.dart';
import 'package:lumen_tale/data/sources/source_manager.dart';
import 'package:lumen_tale/data/updates/drift_check_library.dart';
import 'package:lumen_tale/data/updates/drift_library_check_store.dart';
import 'package:lumen_tale/domain/sources/browse_outcome.dart';
import 'package:lumen_tale/domain/sources/models/chapter.dart';
import 'package:lumen_tale/domain/sources/models/novel.dart';
import 'package:lumen_tale/domain/sources/source.dart';
import 'package:lumen_tale/domain/sources/source_id.dart';
import 'package:lumen_tale/domain/updates/check_job.dart';
import 'package:lumen_tale/domain/updates/check_stop_reason.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/background/check_job_fakes.dart';
import '../../core/background/code_grep.dart';
import '../../data/updates/check_fakes.dart';

/// The two instants the fixture's marks use.
///
/// ⚠️ **CONSTANTS, NOT INLINE `DateTime.utc` CALLS.** The fixture writes them and the
/// assertions compare them; a first version spelled the same date in both places and they
/// disagreed — a test comparing against a *different* number than the fixture wrote cannot
/// tell a regression from a typo.
final DateTime kReadAt = DateTime.utc(2026, 9, 1, 8);
final DateTime kDownloadedAt = DateTime.utc(2026, 10, 1, 8);

/// One novel in the library, holding chapters the reader has already acted on.
///
/// ⚠️ **THE FIXTURE IS THE THING A PASS MUST NOT CHANGE**, and the three marks are
/// deliberately mixed: a read-but-not-downloaded row, a downloaded-but-unread one and one
/// that is neither. A pass that touched any of the three marks would have to move at least
/// one of them.
Future<void> seedNovel(AppDatabase db, String id, {int chapters = 3}) async {
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
            isRead: const Value(false),
            readAt: Value(i == 0 ? kReadAt : null),
            downloadedAt: Value(i < 2 ? kDownloadedAt : null),
          ),
        );
  }
}

/// What the site publishes for [novelId].
BrowseOutcome<List<Chapter>> published(String novelId, {int total = 4}) =>
    BrowseSucceeded<List<Chapter>>(<List<Chapter>>[
      <Chapter>[for (int i = 0; i < total; i++) chapterOf(novelId, i)],
    ]);

void main() {
  late AppDatabase db;
  late SpySource site;
  late RecordingEngine engine;
  late SharedPreferencesCheckJobInterlock interlock;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    site = SpySource();
    engine = RecordingEngine();
    SharedPreferences.setMockInitialValues(<String, Object>{});
    interlock = SharedPreferencesCheckJobInterlock(
      await SharedPreferences.getInstance(),
    );
  });

  tearDown(() => db.close());

  /// A run over [novels], with the flag already held — which is the state the platform
  /// starts a registered job in.
  BackgroundCheckRun aRun() {
    return BackgroundCheckRun(
      check: DriftCheckLibrary(
        store: DriftLibraryCheckStore(db),
        sources: SourceManager(<Source>[site]),
        rateLimiter: HostRateLimiter(),
        clock: () => DateTime.utc(2026, 10, 4, 9),
      ),
      interlock: interlock,
      engine: engine,
    );
  }

  Future<void> seedLibrary(int novels) async {
    for (int i = 0; i < novels; i++) {
      await seedNovel(db, 'n$i');
    }
  }

  group('B38 — checking never downloads', () {
    test('a foreground pass adds no queue item and moves no chapter mark', () async {
      await seedLibrary(3);

      // ⚠️ **READ *BEFORE*, NOT A SAMPLE AFTER.** The claim is that nothing moved, and a
      // fixture that never set the marks would make rows 3 and 4 vacuous.
      final int queueBefore = await _queueSize(db);
      final Map<String, (bool, DateTime?, DateTime?)> before = await _marks(db);
      final Map<String, bool> membershipBefore = await _membership(db);

      final bool ran = await aRun().execute();

      expect(
        ran,
        isTrue,
        reason: '§ 3.2: `true` = success, WorkManager reschedules nothing',
      );
      expect(
        await _queueSize(db),
        queueBefore,
        reason:
            'B38: a check adds no `downloadQueueItem`. The whole content pipeline for this '
            'app exists, and none of it may be reachable from a pass',
      );
      expect(
        await _marks(db),
        before,
        reason:
            'B38 / B6 / B13: `is_read`, `read_at` and `downloaded_at` are the reader two '
            'acts. A pass that set any of them would be marking chapters the reader never '
            'opened and never downloaded',
      );
      expect(
        await _membership(db),
        membershipBefore,
        reason:
            'B38: `novels.in_library` is not the check\'s to change either — a pass '
            'removing a novel would be a destructive operation with no gesture behind it',
      );
    });

    test('the pass calls only the two contract methods a check needs', () {
      expect(
        site.calls,
        isEmpty,
        reason:
            '§ 3.2: "C\'est l\'invariant de B38, et il tient dans cette unique fonction '
            'parce que le seul appel qu\'elle fait est `CheckLibrary.run`." The runner '
            'itself must reach no site at all',
      );
    });
  });

  group('B39 — every novel is visited, and the counts are the pass\'s own', () {
    test('one progress emission per novel, then a terminal success', () async {
      await seedLibrary(3);
      for (final String id in <String>['n0', 'n1', 'n2']) {
        site.detailsFor[id] = const BrowseSucceeded<Novel>(<Novel>[]);
        site.chaptersFor[id] = published(id);
      }

      await interlock.acquire();
      await aRun().execute();

      expect(
        engine.reported,
        hasLength(4),
        reason:
            'B39: § 2.2 emits before the first network call — so the total is known from '
            'the first emission and the screen can say "0 of 3" instead of waiting to '
            'find out how long the library is — and once per novel thereafter. Three novels '
            'means four emissions',
      );
      expect(
        engine.reported.first,
        const CheckJobProgress(done: 0, total: 3),
        reason:
            'the FIRST emission already carries the total. An emission of `0 of 0` would be '
            'a count that jumps to the real number a frame later',
      );
      expect(
        engine.reported.map((CheckJobProgress p) => p.done).toList(),
        <int>[0, 0, 1, 2],
        reason:
            'B39: the counter rises by exactly one per novel, starting from the '
            'pre-network emission that already carries the total. It never reaches the total '
            'itself — `6-4` emits BEFORE each novel, so the last emission describes work '
            'still to do, and the "3 of 3" the reader sees is the terminal line',
      );
      expect(
        engine.reportedOutcomes,
        <CheckJobOutcome>[
          const CheckJobSucceeded(
            checkedNovelCount: 3,
            failedNovelCount: 0,
            discovered: 3,
          ),
        ],
        reason:
            '§ 3.3 branch 1: the terminal outcome is a success carrying what was FOUND — '
            'three novels checked, and the twelve chapter rows the pass added. B48: the '
            'count is rows added by this pass, not the library\'s unopened total',
      );
    });

    test('a broken site is a FAILURE beside the success, never inside it', () async {
      await seedLibrary(2);
      site.detailsFor['n0'] = const BrowseSucceeded<Novel>(<Novel>[]);
      site.chaptersFor['n0'] = published('n0');
      // ⚠️ **THE SITE ANSWERS AND SAYS NOTHING.** `BrowseEmpty` is not what a broken site
      // produces — a broken site produces a typed failure, and rendering it as "0 new
      // chapters" is B22's failure in its purest form.
      site.detailsFor['n1'] = const BrowseFailed<Novel>(
        SourceUnavailable(status: 503),
        retriable: true,
      );

      await interlock.acquire();
      await aRun().execute();

      expect(
        engine.reportedOutcomes.single,
        const CheckJobSucceeded(
          checkedNovelCount: 1,
          failedNovelCount: 1,
          discovered: 1,
        ),
        reason:
            'B22: the failure count is BESIDE the success count and never inside it. "Checked '
            '2 novels" when one site could not be read is the exact presentation B22 '
            'forbids, and `6-4` already proved the loop does this — this row proves the '
            'background wrapper forwards it unchanged',
      );
    });
  });

  group('C8 — an interrupted pass is never a successful one', () {
    test('a released flag stops the pass and reports it as an interruption', () async {
      await seedLibrary(3);
      for (final String id in <String>['n0', 'n1', 'n2']) {
        site.detailsFor[id] = const BrowseSucceeded<Novel>(<Novel>[]);
        site.chaptersFor[id] = published(id);
      }

      await interlock.acquire();
      final BackgroundCheckRun run = aRun();

      // ⚠️ **THE GESTURE IS TIMED BY THE SITE, NOT BY A `DELAY`.** Releasing the flag from a
      // timer makes the row depend on how fast the host is; releasing it from the site's
      // `beforeDetails` hook puts it at a known point in the loop — after novel 0's network
      // calls, before novel 1's — which is exactly what `cancel()` achieves: release, then
      // let the pass's own gate notice.
      site.beforeDetails = interlock.release;
      final bool ran = await run.execute();

      expect(
        ran,
        isTrue,
        reason:
            'B20: an interrupted pass is not retried by WorkManager. Returning `false` would '
            'make the platform re-run a check the reader stopped — a background trigger, which '
            'B36 forbids',
      );
      expect(
        engine.reportedOutcomes,
        <Matcher>[
          isA<CheckJobInterrupted>()
              .having((CheckJobInterrupted o) => o.reason, 'reason', isNull)
              .having(
                (CheckJobInterrupted o) => o.totalNovelCount,
                'totalNovelCount',
                3,
              )
              .having(
                (CheckJobInterrupted o) => o.reachedNovelCount,
                'reachedNovelCount',
                1,
              ),
        ],
        reason:
            'C8 / § 3.3 branch 2: `reason: null` because the reader did it and no platform '
            'reason ever arrived. `reachedNovelCount` < `totalNovelCount` is the point of '
            'the arm: the screen can say "Check stopped at 1 of 3 novels" instead of '
            'presenting a summary of one novel as the whole tour',
      );
      expect(
        engine.reportedOutcomes.whereType<CheckJobSucceeded>(),
        isEmpty,
        reason:
            'C8: "une passe interrompue n\'est JAMAIS rendue comme réussie". A `Succeeded` '
            'arm here would be the one rendering C8 exists to forbid',
      );
    });

    test(
      'the flag is released by the pass itself when it ends normally',
      () async {
        await seedLibrary(1);
        site.detailsFor['n0'] = const BrowseSucceeded<Novel>(<Novel>[]);
        site.chaptersFor['n0'] = published('n0');
        await interlock.acquire();

        await aRun().execute();

        expect(
          await interlock.isHeld(),
          isFalse,
          reason:
              '§ 3.2 and § 3.3 branch 1: a pass that finishes releases the flag, or the next '
              'tap is refused with no explanation',
        );
      },
    );
  });

  group('§ 3.3 branches 3 to 6 — the platform stopped the work', () {
    test('each stop reason is reported as an interruption, with both numbers', () async {
      const List<CheckStopReason> reported = <CheckStopReason>[
        CheckStopReason.timeout,
        CheckStopReason.preempt,
        CheckStopReason.cancelledByApp,
        CheckStopReason.backgroundRestriction,
        CheckStopReason.estimatedAppGpuLimit,
        CheckStopReason.deviceState,
        CheckStopReason.appStandby,
        CheckStopReason.deviceIdle,
        CheckStopReason.unknown,
      ];
      for (final CheckStopReason reason in reported) {
        final RecordingEngine local = RecordingEngine();
        final SharedPreferencesCheckJobInterlock localLock =
            SharedPreferencesCheckJobInterlock(
              await SharedPreferences.getInstance(),
            );
        await localLock.acquire();
        final BackgroundCheckRun run = BackgroundCheckRun(
          check: DriftCheckLibrary(
            store: DriftLibraryCheckStore(db),
            sources: SourceManager(<Source>[site]),
            rateLimiter: HostRateLimiter(),
            clock: () => DateTime.utc(2026, 10, 4, 9),
          ),
          interlock: localLock,
          engine: local,
        );

        await run.onStopped(reason);

        expect(
          local.reportedOutcomes.single,
          isA<CheckJobInterrupted>()
              .having((CheckJobInterrupted o) => o.reason, 'reason', reason)
              .having(
                (CheckJobInterrupted o) => o.reachedNovelCount,
                'reachedNovelCount',
                0,
              )
              .having(
                (CheckJobInterrupted o) => o.totalNovelCount,
                'totalNovelCount',
                0,
              ),
          reason:
              '§ 10: "une passe interrompue n\'est jamais rendue comme réussie", and C12: '
              'each of the ten reasons has its own sentence. A `switch` with a default '
              'that said "failed" would give a reader on a borrowed phone nothing to '
              'describe. Here the reason names itself, for ${reason.name}',
        );
        expect(
          await localLock.isHeld(),
          isFalse,
          reason:
              '§ 3.3: the flag is released by `onTaskStopped` as well as by the pass, '
              'because an isolate the system killed runs no `finally` and fires no other '
              'callback',
        );
      }
    });

    test(
      'systemIgnoredCancelledByApp reports NOTHING and still releases the flag',
      () async {
        await interlock.acquire();
        final BackgroundCheckRun run = aRun();

        await run.onStopped(CheckStopReason.systemIgnoredCancelledByApp);

        expect(
          engine.reportedOutcomes,
          isEmpty,
          reason:
              '§ 3.3 branch 6 and § 10: that reason means the worker RAN TO COMPLETION. The '
              'pass publishes its real result a moment later, and an interruption here '
              'would tell the reader their check was stopped when it finished — sending '
              'them to look for changes that are already saved. § 10 demands *Check '
              'finished after you cancelled it*',
        );
        expect(
          await interlock.isHeld(),
          isFalse,
          reason:
              'the flag is released regardless: the pass may never have started at all, and '
              'a flag left set would refuse the next tap with no explanation',
        );
      },
    );

    test('a stop after a counter keeps the counter in the report', () async {
      await seedLibrary(2);
      site.detailsFor['n0'] = const BrowseSucceeded<Novel>(<Novel>[]);
      site.chaptersFor['n0'] = published('n0');
      await interlock.acquire();
      final BackgroundCheckRun run = aRun();
      // ⚠️ **THE PLATFORM STOPS THE WORK *DURING* THE PASS, WHICH IS THE ONLY WAY IT
      // HAPPENS.** The first version released the flag and then called `onStopped`
      // afterwards — a sequence that cannot occur, since a stopped engine never finishes its
      // task body, and which reported `0 of 2` about a pass that had reached a novel. So
      // the second `getNovelDetails` is where the platform stops us: by then the counter
      // holds the emission for novel 1.
      int detailsCalls = 0;
      site.beforeDetails = () async {
        detailsCalls++;
        if (detailsCalls == 2) {
          await run.onStopped(CheckStopReason.deviceIdle);
          await interlock.release();
        }
      };
      await run.execute();

      expect(
        engine.reportedOutcomes.first,
        isA<CheckJobInterrupted>()
            .having(
              (CheckJobInterrupted o) => o.reachedNovelCount,
              'reachedNovelCount',
              1,
            )
            .having(
              (CheckJobInterrupted o) => o.totalNovelCount,
              'totalNovelCount',
              2,
            ),
        reason:
            'C8: "Check stopped at 7 of 23 novels" needs both numbers, and they come from '
            'the counter the pass last reported — which is why the stopped callback and the '
            'task body share one `BackgroundCheckRun`. Two objects would report `0 of 0` '
            'about a pass that had reached a novel',
      );
    });
  });

  group('B32 — the connection enforces the foreign keys', () {
    test(
      'PRAGMA foreign_keys is 1 on a database opened the way a test opens it',
      () async {
        final int pragma = await _foreignKeys(db);
        expect(
          pragma,
          1,
          reason:
              '`foreign_keys` is per connection and is not part of the file format. '
              '`AppDatabase.forTesting` applies `kEnableForeignKeys` in its constructor, so a '
              'test database is not the one place where the pragma is forgotten — the trap '
              '`app_database.dart` documents in full',
        );
      },
    );

    test('a novel with history cannot be deleted, so the RESTRICT is live', () async {
      await seedNovel(db, 'n0', chapters: 1);
      await db
          .into(db.historyEntries)
          .insert(
            HistoryEntriesCompanion.insert(
              id: 'h1',
              novelId: 'n0',
              chapterId: SourceId.forChapter(
                novelId: 'n0',
                relativeUrl: '/fiction/n0/chapter/0',
              ),
              openedAt: kReadAt,
            ),
          );

      await expectLater(
        (db.delete(
          db.novels,
        )..where(($NovelsTable t) => t.id.equals('n0'))).go(),
        throwsA(isA<Object>()),
        reason:
            'B32: the RESTRICT on `history_entries.novelId` is the only enforcement the '
            'schema has, and it exists only while the pragma is on. A test that observed '
            'the delete succeeding would have been measuring a schema with no constraints '
            'at all',
      );
    });

    test('the PRODUCTION connection applies the same pragma', () {
      final String source = codeOf('lib/core/database/app_database.dart');
      expect(
        source,
        contains('setup: _setup'),
        reason:
            '§ 3.2: "Cet isolate DOIT aussi l\'avoir. local-store § 2.1 : le pragma est '
            'par connexion". `AppDatabase()` — the constructor the background isolate '
            'builds — resolves its file through `_openLazy`, and that is the only place '
            'the production connection is configured',
      );
      expect(
        source,
        contains('const String kEnableForeignKeys = '),
        reason:
            'and the SQL lives beside the function that must not drop it, so a refactor '
            'that removed the pragma fails a test instead of silently disabling B32',
      );
    });
  });
}

/// `COUNT(*)` of `queue_items` — E7's table, which a check must never grow.
Future<int> _queueSize(AppDatabase db) async => db
    .customSelect('SELECT COUNT(*) AS total FROM queue_items')
    .getSingle()
    .then((QueryRow r) => r.read<int>('total'));

/// The three marks, keyed by chapter id — the tuple a check must not move.
Future<Map<String, (bool, DateTime?, DateTime?)>> _marks(AppDatabase db) async {
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

/// `novels.in_library` for every row.
Future<Map<String, bool>> _membership(AppDatabase db) async {
  final List<NovelRow> rows = await db.select(db.novels).get();
  return <String, bool>{for (final NovelRow r in rows) r.id: r.inLibrary};
}

/// `PRAGMA foreign_keys` as this connection reports it.
Future<int> _foreignKeys(AppDatabase db) async => db
    .customSelect('PRAGMA foreign_keys')
    .getSingle()
    .then((QueryRow r) => r.read<int>('foreign_keys'));
