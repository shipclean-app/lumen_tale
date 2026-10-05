// forge:slice 5-1
// Lumen Tale — the queue in the provider graph: § 4.2's keepAlive and § 5's liveness.
//
// `05-state-management.md` rule 10 requires a **stated reason** for every `keepAlive`, and
// § 4.2 states two: the queue is one queue for three surfaces, and `autoDispose` would
// resurrect the restart E15 forbids. This file is what keeps the reason true rather than
// written down.
//
// ## ⚠️ **`ProviderContainer` WITH `overrideWithValue`, AND NO `addTearDown` FORGETTING**
//
// `10-testing.md` rule 11: notifiers and controllers are tested through a container with
// their dependencies overridden. The container holds a stream subscription and a running
// loop, so `container.dispose()` is not optional — a test that left one open would leave a
// `Timer` and a `Subscription` behind, and the next test's assertions would be answering
// someone else's queue.

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumen_tale/core/database/app_database.dart';
import 'package:lumen_tale/core/database/app_database_provider.dart';
import 'package:lumen_tale/core/pipeline/converted_chapter.dart';
import 'package:lumen_tale/data/downloads/drift_download_queue_repository.dart';
import 'package:lumen_tale/data/downloads/drift_novel_download_scope.dart';
import 'package:lumen_tale/data/sources/source_manager.dart';
import 'package:lumen_tale/domain/downloads/bulk_choice.dart';
import 'package:lumen_tale/domain/downloads/bulk_download_enqueue.dart';
import 'package:lumen_tale/domain/downloads/chapter_markdown_converter.dart';
import 'package:lumen_tale/domain/downloads/chapter_writer.dart';
import 'package:lumen_tale/domain/downloads/download_queue_runner.dart';
import 'package:lumen_tale/domain/downloads/queue_entry.dart';
import 'package:lumen_tale/domain/sources/browse_outcome.dart';
import 'package:lumen_tale/domain/sources/models/chapter.dart';
import 'package:lumen_tale/domain/sources/models/filter.dart';
import 'package:lumen_tale/domain/sources/models/novel.dart';
import 'package:lumen_tale/domain/sources/models/novels_page.dart';
import 'package:lumen_tale/domain/sources/models/update.dart';
import 'package:lumen_tale/domain/sources/source.dart';
import 'package:lumen_tale/features/downloads/providers/download_queue_provider.dart';

/// A converter that always produces a real chapter, so nothing here is about E18.
final class ProseConverter implements ChapterMarkdownConverter {
  @override
  ConvertedChapter convert({
    required String rawHtml,
    required String baseUrl,
  }) => const ConvertedChapter(
    markdown: 'stored',
    paragraphCount: 1,
    lineBreakCount: 0,
    plainTextLength: 200,
    imagesKept: 0,
  );
}

/// Counts fetches and writes, and does no I/O at all — this file's subject is the graph,
/// not the disk.
final class CountingWriter implements ChapterWriter {
  final List<String> written = <String>[];

  @override
  Future<void> writeChapter({
    required String chapterId,
    required String novelId,
    required int ordinal,
    required String markdown,
  }) async {
    written.add(chapterId);
  }
}

/// The smallest thing that satisfies the source contract, because the queue resolves its
/// chapter HTML through `SourceManager.byId` → `ParsedHttpSource.fetchChapterContent`.
///
/// ⚠️ **A REAL SOURCE, NOT AN OVERRIDDEN RUNNER.** Overriding `downloadQueueRunnerProvider`
/// would have made the test assert about a runner it supplied, and `SourceRegistryChapter
/// Content`'s half of the wiring — the `Source` → `HttpSource` → `ParsedHttpSource`
/// narrowing — would have gone untested. The `Source` methods below throw, because the
/// queue calls exactly one of them and a test that reached another would be reading a
/// cataloguing path this slice does not have.
final class FakeChapterSource implements ParsedHttpSource {
  final List<String> fetched = <String>[];

  @override
  String get id => 'rr';

  @override
  String get name => 'Fake';

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
    return const BrowseSucceeded<String>(<String>['<p>prose</p>']);
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

Future<AppDatabase> seeded({int chapters = 3}) async {
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
            number: Value<double>(i.toDouble()),
          ),
        );
  }
  return db;
}

/// ⚠️ **THE OVERRIDES ARE THE WHOLE POINT.** `appDatabaseProvider`, `chapterWriterProvider`
/// and `sourceManagerProvider` all throw until `main.dart` supplies them, so a container
/// without overrides cannot resolve the queue at all — and a test that "passed" by
/// swallowing that would be testing a container that never built anything.
/// Keeps the queue's stream **listened to** for the life of the test.
///
/// ⚠️ **A HELD SUBSCRIPTION, NOT `container.read(provider)`.** A plain `read` of a
/// `StreamProvider` subscribes and immediately closes again, so the drift stream is torn
/// down before its first value and `read(provider.future)` then waits for an emission that
/// never comes — which reads as a queue that is broken when the queue is fine. Holding the
/// subscription is what a screen does, and it is what a test must imitate.
ProviderSubscription<AsyncValue<List<QueueEntry>>> listenToQueue(
  ProviderContainer container,
) {
  final ProviderSubscription<AsyncValue<List<QueueEntry>>> subscription =
      container.listen(
        downloadQueueStreamProvider,
        (AsyncValue<List<QueueEntry>>? _, AsyncValue<List<QueueEntry>> _) {},
      );
  addTearDown(subscription.close);
  return subscription;
}

/// ⚠️ **A SINGLE SOURCE INSTANCE, REACHABLE FROM A TEST.** The container builds the
/// registry, so the source's fetch log is only reachable through a top-level holder. A
/// second instance would count zero fetches and the rows below would pass for the wrong
/// reason — "nothing was fetched" would be true of a different object.
final FakeChapterSource fakeChapterSource = FakeChapterSource();

ProviderContainer containerFor(AppDatabase db, CountingWriter writer) {
  final ProviderContainer container = ProviderContainer(
    overrides: [
      appDatabaseProvider.overrideWithValue(db),
      chapterWriterProvider.overrideWithValue(writer),
      // ⚠️ **THE REGISTRY IS OVERRIDDEN WITH A REAL `SourceManager`**, because `0-5`'s is
      // overridden only in `main.dart` and this container is not `main`. Building one over
      // a single fake source is also the only way `SourceRegistryChapterContent`'s
      // `HttpSource` / `ParsedHttpSource` narrowing gets exercised — the queue resolves a
      // stored `sourceId` through it on every attempt.
      sourceManagerProvider.overrideWithValue(
        SourceManager(<Source>[fakeChapterSource]),
      ),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  // ⚠️ **THE SHARED SOURCE'S LOG IS CLEARED PER TEST.** `fakeChapterSource` is one
  // top-level instance (see its declaration), so without this the second test would start
  // with three fetches already recorded and "nothing was fetched" would be true of a
  // different run.
  setUp(fakeChapterSource.fetched.clear);
  group('E7 / § 5 — `isRunning` is session state, and starts false', () {
    test('⚠️ a queue with rows is NOT running until something starts it', () async {
      final AppDatabase db = await seeded();
      addTearDown(db.close);
      final CountingWriter writer = CountingWriter();
      final ProviderContainer container = containerFor(db, writer);
      await DriftDownloadQueueRepository(db).enqueue(<String>['c0', 'c1']);

      // ⚠️ **THE ROWS EXIST AND NOTHING IS RUNNING.** This is E7's whole shape: a queue
      // left by a previous session must not resume itself, or "downloads continue only
      // while the app is open" becomes a promise the app does not keep.
      // ⚠️ **LISTEN FIRST, THEN READ.** The rows exist on disk but the queue's *state*
      // comes from the stream, so a read before the stream has emitted returns an empty
      // list. A test that read straight after seeding would conclude the queue was empty
      // — which is the exact question the row is asking.
      listenToQueue(container);
      await container.read(downloadQueueStreamProvider.future);
      final QueueState state = container.read(downloadQueueProvider);
      expect(
        state.entries,
        hasLength(2),
        reason:
            'the queue definition is on disk — that is what E15 resumes from',
      );
      expect(
        state.isRunning,
        isFalse,
        reason:
            '§ 5: "isRunning is session state, never the database … at the opening of a '
            'session, isRunning == false by default, so no automatic resume is possible '
            'even by forgetting it". E7: there is no background executor to have resumed it',
      );
      expect(
        fakeChapterSource.fetched,
        isEmpty,
        reason: 'and nothing was fetched',
      );
    });
  });

  group('B18 — `enqueueChoice` resolves, enqueues, and starts the loop ONCE', () {
    test('⚠️ a resolved choice produces rows, `done`, and exact counts', () async {
      final AppDatabase db = await seeded();
      addTearDown(db.close);
      final CountingWriter writer = CountingWriter();
      final ProviderContainer container = containerFor(db, writer);
      // ⚠️ **THE STREAM IS LISTENED TO AND ITS FIRST VALUE IS AWAITED.** A drift-backed
      // `StreamProvider` starts as `loading`, so a synchronous read returns an empty list
      // rather than the rows — a failure that looks like a missing seed rather than a
      // missing await.
      listenToQueue(container);
      await container.read(downloadQueueStreamProvider.future);

      final QueueEnqueueOutcome outcome = await container
          .read(downloadQueueProvider.notifier)
          .enqueueChoice(novelId: 'n1', choice: const AllUnopened());
      // ⚠️ **THE LOOP IS ASYNC AND UNCONTROLLED HERE, SO IT IS AWAITED THROUGH THE
      // RUNNER'S OWN PROMISE.** The notifier starts it; nothing awaits it, so the row
      // states below are read after `drain()` rather than raced against.
      await container.read(downloadQueueRunnerProvider).drain();

      expect(
        outcome,
        isA<QueueEnqueued>().having(
          (QueueEnqueued o) => o.rows.length,
          'rows',
          3,
        ),
        reason:
            'B18: `AllUnopened` on a novel of three unread chapters is three rows',
      );
      expect(writer.written, <String>[
        'c0',
        'c1',
        'c2',
      ], reason: 'B18: in reading order, one at a time, and every one written');
      expect(
        container.read(downloadQueueProvider).counts.downloaded,
        3,
        reason:
            'C8: the header figure is `count(state = \'done\')` — exact, derived, and never '
            'a stored total that could be one write behind',
      );
      expect(
        container.read(downloadQueueProvider).isRunning,
        isFalse,
        reason: 'and the loop has ended, so the state is honest again',
      );
    });

    test('⚠️ a choice with NOTHING to download does NOT start a loop', () async {
      final AppDatabase db = await seeded();
      addTearDown(db.close);
      // ⚠️ **ALL THREE CHAPTERS ARE ALREADY STORED.** The sheet's second empty branch:
      // there is genuinely nothing to download, which is not an error and not a dialog.
      await db
          .update(db.chapters)
          .write(const ChaptersCompanion(downloadedAt: Value<DateTime?>(null)));
      for (final ChapterRow row in await db.select(db.chapters).get()) {
        await (db.update(
          db.chapters,
        )..where(($ChaptersTable t) => t.id.equals(row.id))).write(
          ChaptersCompanion(downloadedAt: Value<DateTime?>(DateTime.utc(2026))),
        );
      }
      final CountingWriter writer = CountingWriter();
      final ProviderContainer container = containerFor(db, writer);
      // ⚠️ **THE STREAM IS LISTENED TO AND ITS FIRST VALUE IS AWAITED.** A drift-backed
      // `StreamProvider` starts as `loading`, so a synchronous read returns an empty list
      // rather than the rows — a failure that looks like a missing seed rather than a
      // missing await.
      listenToQueue(container);
      await container.read(downloadQueueStreamProvider.future);

      final QueueEnqueueOutcome outcome = await container
          .read(downloadQueueProvider.notifier)
          .enqueueChoice(novelId: 'n1', choice: const NextChapter());

      expect(
        outcome,
        isA<QueueNothingToDownload>().having(
          (QueueNothingToDownload o) => o.why,
          'why',
          QueueEmptyWhy.choiceYieldsNothing,
        ),
        reason:
            'B22: "nothing to download" and "this novel has no chapter list" are different '
            'sentences, and a count of zero covers both — which is why the outcome carries '
            'a reason',
      );
      expect(
        fakeChapterSource.fetched,
        isEmpty,
        reason: 'no fetch was attempted',
      );
      expect(
        container.read(downloadQueueRunnerProvider).isRunning,
        isFalse,
        reason:
            '⚠️ **A LOOP OVER AN EMPTY QUEUE WOULD BRIEFLY REPORT `isRunning == true`** for '
            'a reader who was just told there is nothing to download. The notifier starts '
            'the loop only when rows were written',
      );
    });
  });

  group('§ 4.2 — the runner is ONE instance for the session', () {
    test('⚠️ two reads of the provider give the SAME runner object', () async {
      final AppDatabase db = await seeded();
      addTearDown(db.close);
      final ProviderContainer container = containerFor(db, CountingWriter());

      final DownloadQueueRunner first = container.read(
        downloadQueueRunnerProvider,
      );
      final DownloadQueueRunner second = container.read(
        downloadQueueRunnerProvider,
      );

      expect(
        identical(first, second),
        isTrue,
        reason:
            '§ 4.2: "register the loop in the Riverpod graph with a SINGLE instance". Two '
            'loops over one queue is the parallelism B18 forbids, and `start()`\'s own '
            'idempotence guard is per-object — a second object has a second guard and '
            'therefore a second loop',
      );
    });

    test('⚠️ the repository provider is also one instance', () async {
      final AppDatabase db = await seeded();
      addTearDown(db.close);
      final ProviderContainer container = containerFor(db, CountingWriter());

      expect(
        identical(
          container.read(downloadQueueRepositoryProvider),
          container.read(downloadQueueRepositoryProvider),
        ),
        isTrue,
        reason:
            '`5-2` adds a pause gate and `5-3` adds progress; both hang off this provider, '
            'and a second repository instance would be a second `_sequence` counter — which '
            'is half of the generated row id',
      );
      expect(
        container.read(novelDownloadScopeProvider),
        isA<DriftNovelDownloadScope>(),
        reason:
            'and the scope is the drift one, so `enqueueChoice` reads `chapters`',
      );
    });
  });
}
