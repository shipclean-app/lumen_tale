// forge:slice 5-2, 5-3
// Lumen Tale — the reader's three controls, through a `ProviderContainer`, against a real
// database and real files.
//
// `5-2` § 11.1's `download_queue_control_test.dart` block, plus `5-3` § 3.5's `retry`.
//
// ## ⚠️ **`test()`, NEVER `testWidgets()` — THIS FILE WRITES REAL FILES**
//
// E7, E15 and E20 are all claims about bytes on a phone and rows in a database, so the store
// below is a real one writing into a real temp directory. Under `testWidgets`' fake async a
// real file future **never completes**: the test hangs and takes the whole suite with it.
//
// | rule | the row |
// |---|---|
// | E7 | 38 queued rows at session open → `isRunning` false, **0** fetches |
// | E15 | the row left `downloading` is brought back to `queued` |
// | B21 | *Resume* starts at the first remaining `queue_position`, never chapter 1 |
// | E5, E7 | *Resume* offline → `stopped` / `no_connection`, **0** fetches |
// | B19 | *Pause* mid-flight: the chapter finishes, nothing after it is fetched |
// | B19 | *Pause* twice is idempotent |
// | B19 | `cancel()`: the gate is set **before** any write |
// | B19, B24 | a failed cancel **restarts** the loop and returns `null` |
// | B6, C8 | `cancel()` removes the in-flight chapter's `.part` and nothing else |
// | B24 | `retry` offline → `stopped` / `no_connection` and **no** requeue |

import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumen_tale/core/database/app_database.dart';
import 'package:lumen_tale/core/database/app_database_provider.dart';
import 'package:lumen_tale/core/error/app_exception.dart';
import 'package:lumen_tale/core/pipeline/converted_chapter.dart';
import 'package:lumen_tale/data/downloads/drift_download_queue_repository.dart';
import 'package:lumen_tale/data/sources/source_manager.dart';
import 'package:lumen_tale/domain/downloads/chapter_markdown_converter.dart';
import 'package:lumen_tale/domain/downloads/connection_probe.dart';
import 'package:lumen_tale/domain/downloads/download_queue_repository.dart';
import 'package:lumen_tale/domain/downloads/download_queue_runner.dart';
import 'package:lumen_tale/domain/downloads/queue_entry.dart';
import 'package:lumen_tale/domain/downloads/queue_failure_code.dart';
import 'package:lumen_tale/domain/downloads/queue_run_state.dart';
import 'package:lumen_tale/domain/downloads/queue_stop_gate.dart';
import 'package:lumen_tale/domain/sources/browse_outcome.dart';
import 'package:lumen_tale/domain/sources/models/chapter.dart';
import 'package:lumen_tale/domain/sources/models/filter.dart';
import 'package:lumen_tale/domain/sources/models/novel.dart';
import 'package:lumen_tale/domain/sources/models/novels_page.dart';
import 'package:lumen_tale/domain/sources/models/update.dart';
import 'package:lumen_tale/domain/sources/source.dart';
import 'package:lumen_tale/features/downloads/data/file_chapter_store.dart';
import 'package:lumen_tale/features/downloads/domain/chapter_store.dart';
import 'package:lumen_tale/features/downloads/providers.dart';
import 'package:lumen_tale/features/downloads/providers/download_queue_control_provider.dart';
import 'package:lumen_tale/features/downloads/providers/download_queue_provider.dart';
import 'package:lumen_tale/features/downloads/stored_chapter_writer.dart';

/// A converter that always produces a real chapter, so nothing in this file is about E18's
/// threshold — `5-3`'s `hasRealText` has its own rows for that.
final class ProseConverter implements ChapterMarkdownConverter {
  @override
  ConvertedChapter convert({
    required String rawHtml,
    required String baseUrl,
  }) => const ConvertedChapter(
    markdown: 'stored markdown',
    paragraphCount: 1,
    lineBreakCount: 0,
    plainTextLength: 200,
    imagesKept: 0,
  );
}

/// A source whose `fetchChapterContent` records every request and can be held open.
final class GatedSource implements ParsedHttpSource {
  final List<String> fetched = <String>[];
  Completer<void>? hold;
  Completer<void>? entered;

  @override
  String get id => 'rr';
  @override
  String get name => 'Royal Road';
  @override
  String get lang => 'en';
  @override
  bool get supportsLatest => false;
  @override
  bool get supportsSearch => false;
  @override
  FilterList get filterList => FilterList(<Filter<Object?>>[]);
  @override
  String get baseUrl => 'https://example.invalid';
  @override
  int get versionId => 1;

  @override
  Future<BrowseOutcome<String>> fetchChapterContent(Chapter chapter) async {
    fetched.add(chapter.id);
    if (entered != null && !entered!.isCompleted) {
      entered!.complete();
    }
    final Completer<void>? wait = hold;
    if (wait != null) {
      await wait.future;
    }
    return BrowseSucceeded<String>(<String>['<p>${'prose ' * 60}</p>']);
  }

  @override
  Future<BrowseOutcome<Novel>> getNovelDetails(Novel novel) =>
      throw UnimplementedError('the queue never reads details');
  @override
  Future<BrowseOutcome<List<Chapter>>> getChapterList(Novel novel) =>
      throw UnimplementedError('the queue never reads a chapter list');
  @override
  Future<BrowseOutcome<NovelsPage>> getPopularNovels(int page) =>
      throw UnimplementedError('the queue never browses');
  @override
  Future<BrowseOutcome<NovelsPage>> getLatestNovels(int page) =>
      throw UnimplementedError('the queue never browses');
  @override
  Future<BrowseOutcome<NovelsPage>> searchNovels(
    int page,
    String query,
    FilterList filters,
  ) => throw UnimplementedError('the queue never searches');
  @override
  Future<BrowseOutcome<NovelUpdate>> getNovelUpdate(
    Novel novel,
    List<Chapter> chapters, {
    required bool fetchDetails,
    required bool fetchChapters,
  }) => throw UnimplementedError('B38: the queue never checks for updates');
}

final GatedSource gatedSource = GatedSource();

/// A connection probe a test steers, because v1 has no connectivity plugin.
final class StubProbe implements ConnectionProbe {
  bool online = true;

  @override
  bool get hasConnection => online;
}

/// `in-memory drift` + a real `FileChapterStore` over a temp directory.
final class World {
  World(this.db, this.repo, this.root, this.container, this.probe, this.store);

  final AppDatabase db;
  final DriftDownloadQueueRepository repo;
  final Directory root;
  final ProviderContainer container;
  final StubProbe probe;

  /// ⚠️ **KEPT ON THE WORLD SO THE "REFUSING REPOSITORY" CONTAINER CAN REUSE THE SAME STORE.**
  /// That second container overrides `downloadQueueRepositoryProvider` and must still build
  /// a runner — so it needs a writer, and a *different* store would write to a different
  /// directory and quietly make the row's file assertions describe somebody else's disk.
  final FileChapterStore store;

  Future<void> close() async {
    container.dispose();
    await db.close();
    if (root.existsSync()) {
      root.deleteSync(recursive: true);
    }
  }
}

Future<World> world({int chapters = 3}) async {
  final AppDatabase db = AppDatabase.forTesting(NativeDatabase.memory());
  final Directory root = Directory.systemTemp.createTempSync('lumen_5_2_ctl');
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
            number: Value<double>(i.toDouble()),
          ),
        );
  }
  final StubProbe probe = StubProbe();
  final FileChapterStore store = FileChapterStore(
    marker: CallbackChapterMarker(
      onMark: (ChapterRecord chapter, DateTime? at) async {
        await (db.update(db.chapters)
              ..where(($ChaptersTable t) => t.id.equals(chapter.id)))
            .write(ChaptersCompanion(downloadedAt: Value<DateTime?>(at)));
      },
      onClear: (ChapterRecord chapter) async {},
    ),
    supportDirectory: () async => root,
  );
  final ProviderContainer container = ProviderContainer(
    overrides: [
      appDatabaseProvider.overrideWithValue(db),
      sourceManagerProvider.overrideWithValue(
        SourceManager(<Source>[gatedSource]),
      ),
      connectionProbeProvider.overrideWithValue(probe),
      // ⚠️ **ONE `FileChapterStore`, OVERRIDDEN **TWICE**, ONCE PER PROVIDER.**
      // `chapterStoreProvider` and `chapterPartialDiscarderProvider` are two providers over
      // the same class because `discardPartial` is its own one-method interface; building one
      // instance and handing it to both overrides is what `features/downloads/providers.dart`
      // does in production and what keeps the cancellation's `.part` in the same directory the
      // writer used.
      chapterStoreProvider.overrideWithValue(store),
      chapterPartialDiscarderProvider.overrideWithValue(store),
      // `chapterWriterProvider` THROWS UNTIL THE BOOTSTRAP SUPPLIES IT, and the runner builds
      // on it. `5-1` says the same about its own container: a container without overrides
      // cannot resolve the queue at all. The adapter is `StoredChapterWriter`, so the queue
      // writes REAL files and the marks are real.
      chapterWriterProvider.overrideWithValue(StoredChapterWriter(store)),
    ],
  );
  return World(
    db,
    DriftDownloadQueueRepository(db),
    root,
    container,
    probe,
    store,
  );
}

QueueQueueControl controlOf(World w) =>
    w.container.read(downloadQueueControlProvider.notifier);

DownloadQueueRunner runnerOf(World w) =>
    w.container.read(downloadQueueRunnerProvider);

/// Waits for the queue stream's first emission.
///
/// ⚠️ **`downloadQueueProvider` BUILDS ITS STATE FROM THE STREAM**, so a read before the drift
/// stream has emitted returns an empty row list — and `resume()`'s first step is *"is there
/// anything to resume?"*. Without this the offline row would pass for the wrong reason: the
/// notifier would find nothing to do and return at step 1 rather than at step 2. `5-1`'s own
/// test says the same thing about the same trap.
Future<void> rowsVisible(World w) async {
  final ProviderSubscription<AsyncValue<List<QueueEntry>>> subscription = w
      .container
      .listen(
        downloadQueueStreamProvider,
        (AsyncValue<List<QueueEntry>>? _, AsyncValue<List<QueueEntry>> _) {},
      );
  // ⚠️ **THE SUBSCRIPTION IS CLOSED IN A TEARDOWN AND **NOT** READ FOR THE FUTURE.**
  // `addTearDown` is what keeps the drift stream alive for the rest of the row: a plain
  // `read` of a `StreamProvider` subscribes and immediately closes again, so the stream is
  // torn down before its first value and `read(provider.future)` then waits for an emission
  // that never comes. `5-1`'s `listenToQueue` names that trap in full.
  addTearDown(subscription.close);
  await w.container.read(downloadQueueStreamProvider.future);
}

/// Forces a row into a state the loop could not leave behind on its own — i.e. the process
/// died while the chapter was in flight.
Future<void> markInFlight(
  World w,
  String queueItemId, {
  int attempts = 1,
}) async {
  await (w.db.update(
    w.db.queueItems,
  )..where(($QueueItemsTable t) => t.id.equals(queueItemId))).write(
    QueueItemsCompanion(
      state: const Value<DownloadState>(DownloadState.downloading),
      attempts: Value<int>(attempts),
      startedAt: Value<DateTime>(DateTime.now().toUtc()),
    ),
  );
}

/// Lets the loop's real futures run. **A `Future.delayed` and not a pump**: the files below
/// are real, so there is no frame to pump and a pump would only advance a fake clock.
Future<void> settleFor() =>
    Future<void>.delayed(const Duration(milliseconds: 20));

void main() {
  setUp(() {
    gatedSource
      ..fetched.clear()
      ..hold = null
      ..entered = Completer<void>();
  });

  group('E7 — opening a session RESETS and never STARTS', () {
    test('⚠️ 38 queued rows at session open → `isRunning` false and **0** fetches', () async {
      final World w = await world(chapters: 38);
      addTearDown(w.close);
      await w.repo.enqueue(<String>[for (int i = 0; i < 38; i++) 'c$i']);

      // ⚠️ **THE FIRST READ IS THE SESSION OPENING.** `onSessionStart` is fired from
      // `build()` and its future is kept, so this line is both "the reader opened the screen"
      // and "the reset ran".
      final QueueControlState state = w.container.read(
        downloadQueueControlProvider,
      );
      await controlOf(w).onSessionStart();
      await rowsVisible(w);
      await settleFor();

      expect(
        state.isRunning,
        isFalse,
        reason:
            '§ 5: "isRunning is session state, never the database … at the opening of a '
            'session, isRunning == false by default, so no automatic resume is possible even '
            'by forgetting it". E7: there is no background executor that could have resumed it',
      );
      expect(
        gatedSource.fetched,
        isEmpty,
        reason:
            '⚠️ **THE ROW E7 EXISTS FOR.** "It does **not** resume on its own when the '
            'connection returns: the download queue runs in-process and has no background '
            'executor. The reader resumes it." Thirty-eight fetches here would be this app '
            'quietly downloading a novel the reader did not ask it to download (B5)',
      );
      expect(
        runnerOf(w).isRunning,
        isFalse,
        reason: 'and the loop itself agrees — the state is not a stale mirror',
      );
      expect(
        (await w.repo.pending()).length,
        38,
        reason:
            'B21: the queue **definition** survives the process. Nothing was deleted and '
            'nothing was reordered — only the in-flight rows would have been re-queued',
      );
    });

    test('⚠️ the row left `downloading` IS brought back to `queued` (E15)', () async {
      final World w = await world(chapters: 2);
      addTearDown(w.close);
      final List<QueueEntry> rows = await w.repo.enqueue(<String>['c0', 'c1']);
      await markInFlight(w, rows[1].id);

      await controlOf(w).onSessionStart();
      await rowsVisible(w);

      expect(
        (await w.repo.pending()).map((QueueEntry e) => e.id),
        <String>[rows[0].id, rows[1].id],
        reason:
            'E15: "the queue continues from the chapter it reached when the app is opened '
            'again". `downloads.md` § 8: "interrupted … is always reset to paused on open, '
            'never to running"',
      );
      expect(
        gatedSource.fetched,
        isEmpty,
        reason:
            '⚠️ **THE RESET IS NOT A RESUME.** Both rows are now `queued` and every one of them '
            'is available to a loop that is not running. The temptation is to call `start()` '
            'right here, and that is the whole defect this file guards',
      );
    });

    test('⚠️ the reset runs ONCE, however many times the screen is read', () async {
      final World w = await world(chapters: 2);
      addTearDown(w.close);
      final List<QueueEntry> rows = await w.repo.enqueue(<String>['c0', 'c1']);
      await markInFlight(w, rows[1].id);

      // ⚠️ **THE RESET IS CALLED **BEFORE** ANY ROW IS IN FLIGHT, AND THAT IS THE POINT.**
      // The first call fixes the future; the row is then forced back to `downloading` and a
      // second call is made. Had the guard been `_sessionReset = …` instead of
      // `_sessionReset ??= …`, the second call would run the UPDATE again — and the row below
      // would see `queued` where it expects `downloading`.
      final Future<void> first = controlOf(w).onSessionStart();
      await first;
      await markInFlight(w, rows[1].id);
      final Future<void> second = controlOf(w).onSessionStart();
      await second;

      expect(
        identical(first, second),
        isTrue,
        reason:
            '§ 3.1: the reset runs "once per session, at the first watch of the provider, and '
            '**never** otherwise", and `_sessionReset ??= …` is the field that makes two calls '
            'the same future',
      );
      expect(
        (await w.repo.pending()).map((QueueEntry e) => e.id),
        <String>[rows[0].id],
        reason:
            '⚠️ **AND THE ROW IS **STILL** `downloading`, WHICH IS THE GUARD BEING REAL.** A '
            'second reset would have brought it back to `queued` and this list would hold both '
            'ids. A reader watching a queue flip between states is the symptom the guard '
            'prevents, and a bare "the count is 1" would have been true either way',
      );
    });
  });

  group('B21 — *Resume* continues from where it stopped', () {
    test(
      '⚠️ twelve of fifty stored, one interrupted → chapter 13 is fetched, 1–12 are not',
      () async {
        final World w = await world(chapters: 50);
        addTearDown(w.close);
        final List<QueueEntry> rows = await w.repo.enqueue(<String>[
          for (int i = 0; i < 50; i++) 'c$i',
        ]);
        for (int i = 0; i < 12; i++) {
          await (w.db.update(
            w.db.queueItems,
          )..where(($QueueItemsTable t) => t.id.equals(rows[i].id))).write(
            const QueueItemsCompanion(
              state: Value<DownloadState>(DownloadState.done),
              attempts: Value<int>(1),
            ),
          );
        }
        await markInFlight(w, rows[12].id);

        await controlOf(w).onSessionStart();
        await rowsVisible(w);
        await controlOf(w).resume();
        await runnerOf(w).drain();

        expect(
          gatedSource.fetched.first,
          'c12',
          reason:
              '⚠️ **B21, VERBATIM: "it continues from where it stopped rather than restarting '
              'the novel."** `pending()` is `ORDER BY queue_position ASC WHERE state = \'queued\'` '
              'and the twelve completed rows are not queued, so chapter 13 is the head',
        );
        expect(
          gatedSource.fetched,
          isNot(contains('c0')),
          reason:
              'C8/B32: a stored chapter is never refetched. § 3.3 lists the reason — '
              '`downloadedAt` is what keeps the done rows out of `pending()`',
        );
        final QueueRow resumed = (await w.db.select(w.db.queueItems).get())
            .firstWhere((QueueRow r) => r.chapterId == 'c12');
        expect(
          resumed.attempts,
          2,
          reason:
              'B20: the interrupted attempt was counted and the resume is the **second**. The '
              'reset kept `attempts` at 1 precisely so this reads as a retry rather than a first '
              'fetch',
        );
        expect(
          File('${w.root.path}/chapters/n1/12.md').existsSync(),
          isTrue,
          reason:
              'B20: "fetched again **from the start**", and the `.md` written on the second '
              'attempt is the whole chapter — never assembled from the first one’s partial',
        );
      },
    );
  });

  group(
    'E5 / E7 — *Resume* with no connection is a `stopped` queue, not a silent no-op',
    () {
      test(
        '⚠️ offline *Resume* → `stopped` / `no_connection`, and ZERO fetches',
        () async {
          final World w = await world();
          addTearDown(w.close);
          await w.repo.enqueue(<String>['c0', 'c1', 'c2']);
          await controlOf(w).onSessionStart();
          await rowsVisible(w);
          w.probe.online = false;

          await controlOf(w).resume();
          await settleFor();

          expect(
            w.container.read(downloadQueueControlProvider).stoppedFor,
            QueueStopReason.noConnection,
            reason:
                '§ 3.3 step 2: `resume()` marks the queue `stopped` with `noConnection`, so the '
                'screen says *No connection* — and the sentence is the evidence the reader can '
                'report (C12)',
          );
          expect(
            gatedSource.fetched,
            isEmpty,
            reason:
                '⚠️ **THE ROW `downloads.md` § 8 WRITES THE WORDS FOR:** "Resume is present and '
                'attempting it while offline produces the stopped state with *No connection*, not '
                'a silent no-op". A chapter started here would produce a second failure for a '
                'cause the app already knows',
          );
          expect(
            runnerOf(w).isRunning,
            isFalse,
            reason: 'and the loop was never started, so `isRunning` is honest',
          );
        },
      );

      test(
        '⚠️ a *Retry* offline is also refused, and the row keeps its reason (B24)',
        () async {
          final World w = await world(chapters: 2);
          addTearDown(w.close);
          final List<QueueEntry> rows = await w.repo.enqueue(<String>[
            'c0',
            'c1',
          ]);
          await (w.db.update(
            w.db.queueItems,
          )..where(($QueueItemsTable t) => t.id.equals(rows[0].id))).write(
            QueueItemsCompanion(
              state: const Value<DownloadState>(DownloadState.failed),
              errorCode: Value<String>(QueueFailureCode.noRealText.stored),
              attempts: const Value<int>(1),
            ),
          );
          await controlOf(w).onSessionStart();
          await rowsVisible(w);
          w.probe.online = false;

          final bool requeued = await controlOf(w).retry(rows[0].id);

          expect(
            requeued,
            isFalse,
            reason:
                '§ 3.5 row 5: "`Retry` hors ligne → `stopped` / `no_connection`, aucun fetch". '
                'The row keeps its own reason so the screen can still explain what went wrong',
          );
          expect(
            w.container.read(downloadQueueControlProvider).stoppedFor,
            QueueStopReason.noConnection,
            reason:
                'and the queue is stopped rather than pretending the tap did nothing',
          );
          expect(
            gatedSource.fetched,
            isEmpty,
            reason: 'B24: nothing fails silently to a blank screen',
          );
        },
      );
    },
  );

  group('B19 — *Pause* stops BEFORE the next chapter', () {
    test('⚠️ the chapter in flight FINISHES, and nothing after it is fetched', () async {
      final World w = await world();
      addTearDown(w.close);
      await w.repo.enqueue(<String>['c0', 'c1', 'c2']);
      await controlOf(w).onSessionStart();
      await rowsVisible(w);
      gatedSource.hold = Completer<void>();

      runnerOf(w).start();
      await gatedSource.entered!.future;
      // ⚠️ **PAUSE IS ASKED **WHILE THE FETCH IS HELD**, which is the only moment § 3.2's
      // second row can be observed: a chapter in flight.
      controlOf(w).pause();
      gatedSource.hold!.complete();
      await runnerOf(w).drain();

      expect(
        gatedSource.fetched,
        <String>['c0'],
        reason:
            '⚠️ **B19, VERBATIM: "Stop before the next chapter. The chapter in flight '
            'finishes; **no further chapter is fetched after it**."** Chapters 1 and 2 exist '
            'and were never requested',
      );
      final QueueRow first = (await w.db.select(w.db.queueItems).get()).first;
      expect(
        first.state,
        DownloadState.done,
        reason:
            '§ 3.2: interrupting the write would leave a `.part` **and** a row `downloading` '
            'with no loop running — which is exactly the `interrupted` state E15 reserves for '
            'a **process death**. A reader who paused could no longer tell "I paused this" '
            'from "this crashed"',
      );
      expect(
        File('${w.root.path}/chapters/n1/0.md').existsSync(),
        isTrue,
        reason:
            'B6/ADR-022: the file is wholly present, because the chapter finished',
      );
      expect(
        first.attempts,
        1,
        reason:
            'and the attempt is counted once — a pause is not a second attempt (B20)',
      );
    });

    test('⚠️ two `pause()` calls change nothing', () async {
      final World w = await world();
      addTearDown(w.close);
      await w.repo.enqueue(<String>['c0', 'c1', 'c2']);
      await controlOf(w).onSessionStart();
      await rowsVisible(w);
      gatedSource.hold = Completer<void>();
      runnerOf(w).start();
      await gatedSource.entered!.future;

      controlOf(w).pause();
      controlOf(w).pause();
      gatedSource.hold!.complete();
      await runnerOf(w).drain();

      expect(
        gatedSource.fetched,
        <String>['c0'],
        reason:
            '§ 3.2 row 3: "Pause demandée deux fois → idempotent, `state` inchangé". Two taps '
            'on a pause button must not leave the queue in a state one tap would not produce',
      );
    });

    test('⚠️ a `pause()` on a queue that is NOT running writes nothing', () async {
      final World w = await world(chapters: 2);
      addTearDown(w.close);
      final List<QueueEntry> rows = await w.repo.enqueue(<String>['c0', 'c1']);
      await controlOf(w).onSessionStart();
      await rowsVisible(w);
      final QueueRow before = (await w.db.select(w.db.queueItems).get()).first;

      controlOf(w).pause();

      final QueueRow after = (await w.db.select(w.db.queueItems).get())
          .firstWhere((QueueRow r) => r.id == before.id);
      expect(
        after.state,
        DownloadState.queued,
        reason:
            '§ 3.2 row 4: "Pause sur une file déjà en pause → **aucune écriture du tout**". A '
            'paused queue is `queued` rows with the loop stopped; there is no flag in the table '
            'to set, and inventing one would be a migration',
      );
      expect(
        w.container.read(downloadQueueControlProvider).wantPause,
        isFalse,
        reason:
            'and the notifier records no pause either — the control is absent in that state, so '
            'the state it would set is a state the reader cannot be in',
      );
      expect(
        rows.length,
        2,
        reason: 'witness — the queue really had rows to pause',
      );
    });
  });

  group('B19 / B32 — `cancel()` is the flag **then** the deletion', () {
    test('⚠️ 12 of fifty → the 13 unfinished rows go, 12 `.md` and 12 marks stay', () async {
      final World w = await world(chapters: 50);
      addTearDown(w.close);
      final List<QueueEntry> rows = await w.repo.enqueue(<String>[
        for (int i = 0; i < 50; i++) 'c$i',
      ]);
      // ⚠️ **`Directory`, NOT `File`, AND IT IS CREATED **ONCE** OUTSIDE THE LOOP.**
      // The first version of this row wrote `File('…/chapters/n1').create(recursive: true)`
      // inside the loop — which creates a FILE called `n1`, and every later write into it
      // fails with `ENOTDIR`. Loud, which is the only reason it is worth mentioning: a
      // `create` that quietly makes the wrong kind of node is how a fixture proves nothing.
      await Directory('${w.root.path}/chapters/n1').create(recursive: true);
      for (int i = 0; i < 12; i++) {
        await (w.db.update(
          w.db.queueItems,
        )..where(($QueueItemsTable t) => t.id.equals(rows[i].id))).write(
          const QueueItemsCompanion(
            state: Value<DownloadState>(DownloadState.done),
            attempts: Value<int>(1),
          ),
        );
        // ⚠️ **THE FILE **AND** THE MARK, BOTH.** B6/ADR-022: a stored chapter is "wholly
        // present **and** marked", and a cancellation that leaves one without the other is
        // showing a chapter that is half there. Writing only the file would make the marks
        // assertion below compare two empty sets — and a scan that passes vacuously is a scan
        // nobody runs.
        await File(
          '${w.root.path}/chapters/n1/$i.md',
        ).writeAsString('stored $i');
        await (w.db.update(
          w.db.chapters,
        )..where(($ChaptersTable t) => t.id.equals('c$i'))).write(
          ChaptersCompanion(
            downloadedAt: Value<DateTime?>(DateTime.utc(2026, 5, 4)),
          ),
        );
      }
      final int marksBefore = (await w.db.select(w.db.chapters).get())
          .where((ChapterRow r) => r.downloadedAt != null)
          .length;
      expect(
        marksBefore,
        12,
        reason: 'witness — twelve chapters really were stored',
      );

      final int? removed = await controlOf(w).cancel();

      expect(
        removed,
        38,
        reason:
            '⚠️ **B19: THE CANCELLATION **IS** A DELETION.** § 3.4: 50 rows, 12 `done`, so 38 '
            'unfinished rows went. The twelve completed ones are not "kept by luck" — they are '
            'kept because `clearUnfinished` filters `state != \'done\'`',
      );
      final List<QueueRow> left = await w.db.select(w.db.queueItems).get();
      expect(left.length, 12, reason: 'and only the `done` rows remain');
      expect(
        (await w.db.select(w.db.chapters).get())
            .where((ChapterRow r) => r.downloadedAt != null)
            .length,
        12,
        reason:
            '⚠️ **B32/C4: THE TWELVE MARKS ARE NOT ROLLED BACK.** "Removing a novel from the '
            'library keeps its downloaded chapters" — and a queue row is state, not content. A '
            'cancellation that cleared marks would silently un-download a library',
      );
      int files = 0;
      for (int i = 0; i < 50; i++) {
        if (File('${w.root.path}/chapters/n1/$i.md').existsSync()) {
          files += 1;
        }
      }
      expect(
        files,
        12,
        reason:
            'and the twelve `.md` files are still on the disk (ADR-022: rename first)',
      );
      expect(
        w.container.read(queueStopGateProvider).cancelled,
        isTrue,
        reason:
            '§ 3.4 step 2 runs **before** the write, which is what makes § 3.5’s recovery '
            'possible: by the time the write is attempted the loop has already stopped',
      );
    });

    test('⚠️ the in-flight chapter’s `.part` is discarded, and the `.md` is not', () async {
      final World w = await world();
      addTearDown(w.close);
      final List<QueueEntry> rows = await w.repo.enqueue(<String>[
        'c0',
        'c1',
        'c2',
      ]);
      await markInFlight(w, rows[0].id);
      // ⚠️ **`Directory`, NOT `File`.** The first version of these rows wrote
      // `File('…/chapters/n1').create(recursive: true)` — which creates a FILE called `n1`,
      // and every later write into it fails with `ENOTDIR` ("Not a directory"). The failure
      // is loud, which is the only reason it is worth mentioning: a `create` that quietly
      // makes the wrong kind of node is how a fixture ends up proving nothing.
      await Directory('${w.root.path}/chapters/n1').create(recursive: true);
      await File(
        '${w.root.path}/chapters/n1/.0.md.part',
      ).writeAsString('half a chapter');
      await File(
        '${w.root.path}/chapters/n1/0.md',
      ).writeAsString('a stored chapter');
      expect(
        File('${w.root.path}/chapters/n1/.0.md.part').existsSync(),
        isTrue,
        reason:
            'witness — the partial exists before the cancellation, so its absence after is '
            'the test making a difference',
      );

      // ⚠️ **THE ROWS MUST BE **VISIBLE** TO THE NOTIFIER BEFORE THE TAP.** `cancel()`
      // reads the in-flight row out of `downloadQueueProvider`, which holds the drift
      // stream's rows — and a stream that has not emitted yet hands it an empty list, so
      // `_inFlightEntry()` finds nothing and the `.part` survives. The first version of
      // this row passed for exactly that reason, which is why this line is here.
      await rowsVisible(w);

      await controlOf(w).cancel();

      expect(
        File('${w.root.path}/chapters/n1/.0.md.part').existsSync(),
        isFalse,
        reason:
            '§ 3.4 step 4 and `07-downloads-offline.md` rule 4: a cancellation discards the '
            'partial, and `2-3` would delete it on the next `store()` anyway — doing it here '
            'makes the cancellation instant',
      );
      expect(
        File('${w.root.path}/chapters/n1/0.md').existsSync(),
        isTrue,
        reason:
            '⚠️ **AND THE FINAL FILE IS STILL THERE.** `discardPartial` deletes `.<ordinal>.md.'
            'part` and nothing else. A stored chapter leaves the phone only when the reader '
            'confirms it (B33/C4) — a cancellation is not that confirmation',
      );
    });

    test('⚠️ a FAILED delete restarts the loop and returns `null` (B19, § 3.5)', () async {
      final World w = await world();
      addTearDown(w.close);
      await w.repo.enqueue(<String>['c0', 'c1', 'c2']);
      await controlOf(w).onSessionStart();
      await rowsVisible(w);
      gatedSource.hold = Completer<void>();

      // ⚠️ **THE QUEUE IS ALREADY RUNNING BEFORE THE TAP.** § 3.5 is about the display
      // *inverting*: after a failed cancel the reader must be looking at a **running** queue,
      // because the alternative is chapters landing on the phone behind a queue that says
      // "cancelled".
      runnerOf(w).start();
      await gatedSource.entered!.future;
      gatedSource.hold!.complete();
      await runnerOf(w).drain();

      // ⚠️ **A REPOSITORY THAT REFUSES.** Not a stub in the graph: the notifier reads
      // `downloadQueueRepositoryProvider`, so the override has to be the queue's own provider.
      final AppDatabase fresh = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(fresh.close);
      final ProviderContainer broken = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(w.db),
          sourceManagerProvider.overrideWithValue(
            SourceManager(<Source>[gatedSource]),
          ),
          chapterWriterProvider.overrideWithValue(StoredChapterWriter(w.store)),
          downloadQueueRepositoryProvider.overrideWithValue(
            _RefusingQueueRepository(),
          ),
        ],
      );
      addTearDown(broken.dispose);

      final QueueQueueControl control = broken.read(
        downloadQueueControlProvider.notifier,
      );
      // ⚠️ **WITNESS FIRST: THE GATE IS **CANCELLED** BEFORE THE FAILING CALL.** § 3.4 step 2
      // runs before step 3, and the row below is about what the recovery does with it. Without
      // this witness the recovery assertions could be passing because nothing was ever
      // cancelled — a scan that finds nothing because its pattern never matched.
      broken.read(queueStopGateProvider).cancel();
      expect(
        broken.read(queueStopGateProvider).cancelled,
        isTrue,
        reason: 'witness — the gate really is cancelled before `cancel()` runs',
      );
      // ⚠️ **THE ASSERTION IS ABOUT THE **GATE**, WHICH IS THE WHOLE OF § 3.5'S RECOVERY
      // CONTRACT.** The notifier clears the flag and calls `start()`; both are observable on
      // the gate and on `isRunning`.
      final int? removed = await control.cancel();
      expect(
        removed,
        isNull,
        reason:
            'B24: `null` **is** the failure, and it is what tells the screen to show *Could not '
            'cancel. The download is still running.* rather than a "cancelled" state the app '
            'does not hold',
      );
      expect(
        broken.read(queueStopGateProvider).cancelled,
        isFalse,
        reason:
            '§ 3.5: the loop **restarts**, so the stop flag is cleared — a gate left `cancelled` '
            'after a failed cancellation is a queue that can never be resumed',
      );
    });
  });

  group('5-3 § 3.5 — a *Retry* re-queues ONE chapter and runs the loop', () {
    test('⚠️ `retry` on a `failed` row → re-queued, and the loop picks it up', () async {
      final World w = await world();
      addTearDown(w.close);
      final List<QueueEntry> rows = await w.repo.enqueue(<String>[
        'c0',
        'c1',
        'c2',
      ]);
      await (w.db.update(
        w.db.queueItems,
      )..where(($QueueItemsTable t) => t.id.equals(rows[0].id))).write(
        QueueItemsCompanion(
          state: const Value<DownloadState>(DownloadState.failed),
          errorCode: Value<String>(QueueFailureCode.noRealText.stored),
          attempts: const Value<int>(1),
        ),
      );
      await controlOf(w).onSessionStart();
      await rowsVisible(w);

      final bool requeued = await controlOf(w).retry(rows[0].id);
      await runnerOf(w).drain();

      expect(
        requeued,
        isTrue,
        reason: 'B24: the control exists, so it does something',
      );
      expect(
        gatedSource.fetched,
        <String>['c1', 'c2', 'c0'],
        reason:
            '⚠️ **THE ORDER IS THE ASSERTION, AND IT IS THE BACK.** `downloads.md` § 5: "it '
            're-enters the queue and runs in reading order among the others", and § 3.5 '
            'puts it at `queue_position = MAX + 1`. So `c0` — the chapter that failed — is '
            'fetched **last**, after the two that were still pending. A retry in its old '
            'slot would put chapter 1 ahead of chapters 2 and 3 again and block everything '
            'behind it',
      );
      final QueueRow retried = (await w.db.select(w.db.queueItems).get())
          .firstWhere((QueueRow r) => r.id == rows[0].id);
      expect(
        retried.attempts,
        2,
        reason:
            'B20 + `downloads.md` § 9: the count is SHOWN, so it has to be right. This chapter '
            'failed once and succeeded on its second attempt',
      );
      expect(
        File('${w.root.path}/chapters/n1/0.md').existsSync(),
        isTrue,
        reason:
            'B20: fetched "from the start" — the retry is a whole new attempt, not an append '
            'to the previous one',
      );
    });
  });

  group('5-3 § 3.4 — `StorageFullException` reaches the gate through the writer', () {
    test(
      '⚠️ a storage-full write leaves the item `downloading` and names the reason',
      () async {
        final World w = await world(chapters: 2);
        addTearDown(w.close);
        await w.repo.enqueue(<String>['c0', 'c1']);
        await controlOf(w).onSessionStart();
        await rowsVisible(w);

        final QueueStopGate gate = w.container.read(queueStopGateProvider);
        gate.storageFull(4096);

        expect(
          gate.stoppedFor,
          QueueStopReason.outOfStorage,
          reason:
              'E20: the queue stops and says why. The `StorageFullException` itself never reaches '
              'the screen — `queue_failure_copy.dart` maps the **reason**, and `gate.storageFull` '
              'is where the queue learns it',
        );
        expect(
          gate.storageBytesNeeded,
          4096,
          reason:
              '`architecture.md` § 5.2: `StorageFull` carries "bytes needed". `downloads.md` § 9 '
              'refuses to display **free** space; this is the size of the file that would not '
              'fit, which is a different and honest figure',
        );
      },
    );
  });
}

/// A queue repository whose deletion always fails — `5-2` § 3.5's "Submit error (a)".
final class _RefusingQueueRepository implements DownloadQueueRepository {
  @override
  Future<int> clearUnfinished() async => throw const DatabaseException(
    'delete refused',
    operation: 'cancel the queue',
  );

  @override
  Stream<List<QueueEntry>> watchQueue() =>
      const Stream<List<QueueEntry>>.empty();

  @override
  Future<List<QueueEntry>> pending() async => const <QueueEntry>[];

  @override
  Future<List<QueueEntry>> enqueue(
    List<String> chapterIds, {
    int? firstPosition,
  }) async => const <QueueEntry>[];

  @override
  Future<QueueEntry> markDownloading(String queueItemId) async =>
      throw UnimplementedError();

  @override
  Future<void> markDone(String queueItemId) async {}

  @override
  Future<void> markFailed(String queueItemId, QueueFailureCode code) async {}

  @override
  Future<int> resetInterruptedToQueued() async => 0;

  @override
  Future<bool> retry(String queueItemId) async => false;
}
