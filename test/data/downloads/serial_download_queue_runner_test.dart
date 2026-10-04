// forge:slice 5-1
// Lumen Tale — the serial loop, and B18's "one at a time, in reading order".
//
// `5-1` § 11.1.
//
// ## ⚠️ **`test()`, NEVER `testWidgets()` — THIS FILE DOES REAL `dart:io`**
//
// The store below writes **real files** into a real temp directory, because the property
// under test is *"a chapter is on the disk before the row says `done`"* — a fake store
// would make that a number the test supplied, which is exactly the number production has
// to earn. Under `testWidgets`' fake async, a real file future never completes and the
// test **hangs**, taking the whole suite with it.
//
// | rule | the row |
// |---|---|
// | B18 | `start()` twice is ONE loop (§ 4.2's idempotence) |
// | B18, B6 | 3 chapters → 3 `done` rows, 3 `.md` files on disk, 3 marks |
// | B18 | `maxConcurrent == 1` over twelve chapters — the counter row |
// | B18 | the chapters are stored in QUEUE order |
// | B22, E8 | `BrowseEmpty` → `failed` + `source_empty`, and the loop CONTINUES |
// | B24 | `BrowseFailed` → `failed` + the taxonomy code, and the loop continues |
// | E18, B6 | no prose → `failed` + `no_real_text`, **no file**, **no mark** |
// | B6, E20 | `store()` throws → the item stays `downloading`, `attempts == 1`, no mark |
// | E15, B20 | an interrupted row is relaunchable **from the beginning** |
// | E7 | an empty queue ends the loop: `isRunning == false` |
// | B19 | the runner writes `downloadedAt` **ZERO** times |

import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart' show OrderingTerm, UpdateStatement, Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumen_tale/core/database/app_database.dart';
import 'package:lumen_tale/core/error/source_failure.dart';
import 'package:lumen_tale/core/pipeline/converted_chapter.dart';
import 'package:lumen_tale/data/downloads/drift_download_queue_repository.dart';
import 'package:lumen_tale/data/downloads/serial_download_queue_runner.dart';
import 'package:lumen_tale/domain/downloads/chapter_content_source.dart';
import 'package:lumen_tale/domain/downloads/chapter_markdown_converter.dart';
import 'package:lumen_tale/domain/downloads/chapter_writer.dart';
import 'package:lumen_tale/domain/downloads/queue_failure_code.dart';
import 'package:lumen_tale/domain/sources/browse_outcome.dart';
import 'package:lumen_tale/domain/sources/models/chapter.dart';

const String _baseUrl = 'https://www.royalroad.com';

/// A real filesystem, because the claim under test is about files on disk.
///
/// ⚠️ **IT PERFORMS `2-3`'s TWO WRITES IN ORDER, AND THAT IS THE POINT.** `FileChapterStore`
/// writes the file and *then* calls its `ChapterMarker`; this stub does the same, with
/// [onMarked] playing the marker. So the assertions below about `downloadedAt` are
/// assertions about ADR-022's order reached through the queue's port, and a queue that
/// wrote `done` before calling this would show up as a `done` row over a null mark.
final class TempStore implements ChapterWriter {
  TempStore(this.root, {this.onMarked});

  final Directory root;

  /// `2-3`'s second write. `null` models a writer that does not mark — which is how the
  /// B19 row proves the QUEUE never marks, independently of this stub.
  final Future<void> Function(String chapterId)? onMarked;

  /// ⚠️ **A REAL, COUNTABLE `writeChapter` CALL.** The list here is not the concurrency
  /// counter — it is the witness that a `store()` that throws really was reached.
  final List<String> written = <String>[];

  /// When set, the next `writeChapter` throws. § 3.3's storage row.
  bool failNext = false;

  @override
  Future<void> writeChapter({
    required String chapterId,
    required String novelId,
    required int ordinal,
    required String markdown,
  }) async {
    if (failNext) {
      failNext = false;
      throw const FileSystemException('disk full');
    }
    final File file = File('${root.path}/$novelId/$ordinal.md');
    await file.parent.create(recursive: true);
    await file.writeAsString(markdown);
    written.add('$novelId/$ordinal');
    // ⚠️ **AND ONLY NOW THE MARK** — the same order `FileChapterStore.store()` uses, and
    // the reason a crash between the two leaves a file with no mark.
    await onMarked?.call(chapterId);
  }

  File fileFor(String novelId, int ordinal) =>
      File('${root.path}/$novelId/$ordinal.md');
}

/// The same writer with **no marker** — used by the B19 row, which needs a chapter that
/// is on the disk and marked by nobody, so a non-null mark can only have come from the
/// queue.
final class UnmarkedStore extends TempStore {
  UnmarkedStore(super.root);

  @override
  Future<void> writeChapter({
    required String chapterId,
    required String novelId,
    required int ordinal,
    required String markdown,
  }) async {
    final File file = File('${root.path}/$novelId/$ordinal.md');
    await file.parent.create(recursive: true);
    await file.writeAsString(markdown);
    written.add('$novelId/$ordinal');
  }
}

/// A content source a test steers: one outcome per chapter, plus a concurrency counter.
///
/// ⚠️ **THE COUNTER IS THE POINT.** B18's first clause is *"one at a time"*, and the only
/// honest way to measure it is to count overlapping calls — an implementation using
/// `Future.wait` over N items would pass every other row in this file.
final class FakeContent implements ChapterContentSource {
  FakeContent(this.outcomes);

  /// By chapter id. A missing id yields `BrowseSucceeded` with real prose.
  final Map<String, BrowseOutcome<String>> outcomes;

  int inFlight = 0;
  int maxConcurrent = 0;
  final List<String> fetched = <String>[];

  /// Set to make every chapter's source unresolvable (B3).
  bool sourceMissing = false;

  /// When set, a fetch waits on this. It is how a test observes the loop **while a
  /// chapter is in flight** — the only moment `activeItem` means anything.
  Completer<void>? gate;

  /// Completes once a fetch is under way.
  final Completer<void> entered = Completer<void>();

  @override
  String? baseUrlOf(String sourceId) => sourceMissing ? null : _baseUrl;

  @override
  Future<BrowseOutcome<String>> fetchChapterContent({
    required String sourceId,
    required Chapter chapter,
  }) async {
    inFlight += 1;
    maxConcurrent = inFlight > maxConcurrent ? inFlight : maxConcurrent;
    if (!entered.isCompleted) {
      entered.complete();
    }
    // ⚠️ **A REAL `await` BETWEEN THE TWO HALVES.** A counter incremented and decremented
    // with no suspension point would read 1 even for a `Future.wait`, because nothing
    // would ever have overlapped.
    await Future<void>.delayed(Duration.zero);
    final Completer<void>? wait = gate;
    if (wait != null) {
      await wait.future;
    }
    fetched.add(chapter.id);
    inFlight -= 1;
    return outcomes[chapter.id] ?? const BrowseSucceeded<String>(<String>['']);
  }
}

/// Long enough to clear [kMinTextLengthForARealChapter] with room to spare.
const String prose =
    'The rune smith struck the anvil and the anvil answered in a language she had not '
    'heard before, which was the first honest thing the mountain had said to anyone in '
    'twenty years of being asked questions by strangers.';

/// A converter that answers whatever the test tells it to — including no prose at all.
///
/// ⚠️ **`belowPerCall` AND NOT A BOOLEAN**, because a test needs ONE chapter to fail while
/// its successor succeeds: a converter that failed everything would prove "refused" but
/// not "and the loop carried on", which is the half of § 3.3's E18 row that matters.
final class StubConverter implements ChapterMarkdownConverter {
  StubConverter({
    this.belowPerCall = const <bool>[],
    this.markdown = 'stored markdown',
  });

  /// One entry per call: `true` produces a chapter below E22's threshold.
  final List<bool> belowPerCall;

  int _calls = 0;

  final String markdown;

  @override
  ConvertedChapter convert({required String rawHtml, required String baseUrl}) {
    final bool below = _calls < belowPerCall.length && belowPerCall[_calls];
    _calls += 1;
    return below
        ? const ConvertedChapter(
            markdown: '',
            paragraphCount: 0,
            lineBreakCount: 0,
            plainTextLength: 3,
            imagesKept: 0,
          )
        : ConvertedChapter(
            markdown: markdown,
            paragraphCount: 1,
            lineBreakCount: 0,
            plainTextLength: markdown.length,
            imagesKept: 0,
          );
  }
}

final class Harness {
  Harness(this.db, this.repo, this.store, this.root);

  final AppDatabase db;
  final DriftDownloadQueueRepository repo;
  final TempStore store;
  final Directory root;

  Future<void> close() async {
    await db.close();
    if (root.existsSync()) {
      root.deleteSync(recursive: true);
    }
  }
}

Future<Harness> harness() async {
  final AppDatabase db = AppDatabase.forTesting(NativeDatabase.memory());
  final Directory root = Directory.systemTemp.createTempSync('lumen_5_1');
  // ⚠️ **`onMarked` IS `2-3`'s MARKER, WIRED TO THE REAL DATABASE.** The queue reaches the
  // mark only through the `ChapterWriter` port, so a faithful marker is what makes
  // "the file exists before the mark does" testable rather than asserted.
  Future<void> mark(String chapterId) async {
    final UpdateStatement<$ChaptersTable, ChapterRow> update = db.update(
      db.chapters,
    )..where(($ChaptersTable t) => t.id.equals(chapterId));
    await update.write(
      ChaptersCompanion(downloadedAt: Value<DateTime?>(DateTime.now().toUtc())),
    );
  }

  return Harness(
    db,
    DriftDownloadQueueRepository(db),
    TempStore(root, onMarked: mark),
    root,
  );
}

Future<void> seedNovel(
  AppDatabase db, {
  String novelId = 'n1',
  int chapters = 1,
}) async {
  await db
      .into(db.novels)
      .insert(
        NovelsCompanion.insert(
          id: novelId,
          sourceId: 'rr',
          url: '/fiction/1/$novelId',
          title: 'The Rune Smith',
        ),
      );
  for (int i = 0; i < chapters; i++) {
    await db
        .into(db.chapters)
        .insert(
          ChaptersCompanion.insert(
            id: 'c$i',
            novelId: novelId,
            url: '/fiction/1/$novelId/c$i',
            name: 'Chapter $i',
            ordinal: i,
          ),
        );
  }
}

SerialDownloadQueueRunner runnerFor(
  Harness h,
  FakeContent content, {
  StubConverter? converter,
  ChapterWriter? writer,
}) => SerialDownloadQueueRunner(
  queue: h.repo,
  content: content,
  converter: converter ?? StubConverter(),
  writer: writer ?? h.store,
);

Future<List<QueueRow>> rowsOf(Harness h) =>
    (h.db.select(h.db.queueItems)
          ..orderBy(<OrderingTerm Function($QueueItemsTable)>[
            ($QueueItemsTable t) => OrderingTerm.asc(t.queuePosition),
          ]))
        .get();

Future<Map<String, DateTime?>> marksOf(Harness h) async {
  final List<ChapterRow> chapters = await h.db.select(h.db.chapters).get();
  return <String, DateTime?>{
    for (final ChapterRow c in chapters) c.id: c.downloadedAt,
  };
}

void main() {
  group('B18 — `start()` is idempotent, and the queue drains', () {
    test('⚠️ two `start()` calls run ONE loop', () async {
      final Harness h = await harness();
      addTearDown(h.close);
      await seedNovel(h.db, chapters: 3);
      await h.repo.enqueue(<String>['c0', 'c1', 'c2']);
      final FakeContent content = FakeContent(
        <String, BrowseOutcome<String>>{},
      );
      final SerialDownloadQueueRunner runner = runnerFor(h, content);

      runner.start();
      runner.start(); // § 4.2: idempotent
      await runner.drain();

      expect(
        content.fetched,
        hasLength(3),
        reason:
            'B18: two loops over one queue is the parallelism the rule forbids, and a '
            'reader who taps *Download* twice would see chapters fetched twice. One loop '
            'means three fetches, not six',
      );
      expect(runner.isRunning, isFalse, reason: 'and the loop ended');
    });

    test('⚠️ an EMPTY queue ends the loop immediately (E7)', () async {
      final Harness h = await harness();
      addTearDown(h.close);
      final FakeContent content = FakeContent(
        <String, BrowseOutcome<String>>{},
      );
      final SerialDownloadQueueRunner runner = runnerFor(h, content);

      expect(runner.isRunning, isFalse, reason: 'false before anything starts');
      runner.start();
      await runner.drain();

      expect(content.fetched, isEmpty, reason: 'nothing to fetch');
      expect(
        runner.isRunning,
        isFalse,
        reason:
            '§ 3.3: an empty queue ends the loop, so `_loop` is null again. A queue that '
            'stayed "running" with nothing to do would show a progress bar for ever',
      );
    });

    test(
      '⚠️ `isRunning` is TRUE while the loop works, and `activeItem` names the chapter',
      () async {
        final Harness h = await harness();
        addTearDown(h.close);
        await seedNovel(h.db);
        await h.repo.enqueue(<String>['c0']);
        // ⚠️ **THE FETCH IS GATED, BECAUSE `start()` RETURNS BEFORE THE LOOP HAS READ
        // ITS HEAD.** `_drain` awaits `pending()` before it can name a chapter, so a
        // synchronous `start()` → `activeItem` pair reads `null` for the right reason and
        // looks like a bug. The gate makes the window observable instead of raced.
        final FakeContent content = FakeContent(
          <String, BrowseOutcome<String>>{},
        )..gate = Completer<void>();
        final SerialDownloadQueueRunner runner = runnerFor(h, content);

        runner.start();
        expect(runner.isRunning, isTrue, reason: 'the loop is moving');
        await content.entered.future;

        expect(
          runner.activeItem?.chapterName,
          'Chapter 0',
          reason:
              '§ 4.2: `activeItem` is what the downloads screen names on its running row. '
              'A progress bar with no chapter title is C8 with extra steps',
        );
        content.gate!.complete();
        await runner.drain();
        expect(
          runner.activeItem,
          isNull,
          reason: 'and it is cleared when the loop ends',
        );
      },
    );
  });

  group('B18 — `maxConcurrent == 1` over twelve chapters', () {
    // ⚠️ **THE COUNTER ROW, AND § 10'S CRITERION VERBATIM.** `architecture.md` § 4.5
    // deleted the concurrency column so this could not be changed; a `Future.wait` over N
    // items would pass every other assertion in this file and fail only here.
    test('⚠️ twelve chapters, one at a time, maximum observed in flight = 1', () async {
      final Harness h = await harness();
      addTearDown(h.close);
      await seedNovel(h.db, chapters: 12);
      await h.repo.enqueue(<String>[for (int i = 0; i < 12; i++) 'c$i']);
      final FakeContent content = FakeContent(
        <String, BrowseOutcome<String>>{},
      );
      final SerialDownloadQueueRunner runner = runnerFor(h, content);

      runner.start();
      await runner.drain();

      expect(
        content.maxConcurrent,
        1,
        reason:
            'B18: "enqueues its chapters ONE AT A TIME in reading order". The loop reads '
            '`pending().first` inside a `while`; a `Future.wait` over N items is '
            'parallelism, and `downloads.md` § 2.1 refuses an aggregate bar precisely '
            'because "the queue is serial and a single bar would imply a parallelism the '
            'app does not have"',
      );
      expect(
        content.fetched,
        hasLength(12),
        reason: 'and all twelve were fetched — serial, not concurrent',
      );
    });
  });

  group('B18 / B6 — the nominal path writes a file and THEN a mark', () {
    test('⚠️ 3 chapters → 3 `done` rows, 3 files, 3 non-null marks', () async {
      final Harness h = await harness();
      addTearDown(h.close);
      await seedNovel(h.db, chapters: 3);
      await h.repo.enqueue(<String>['c0', 'c1', 'c2']);
      final SerialDownloadQueueRunner runner = runnerFor(
        h,
        FakeContent(<String, BrowseOutcome<String>>{}),
      );

      runner.start();
      await runner.drain();

      final List<QueueRow> rows = await rowsOf(h);
      expect(rows.map((QueueRow r) => r.state).toList(), <DownloadState>[
        DownloadState.done,
        DownloadState.done,
        DownloadState.done,
      ], reason: 'B18: every chapter went through the queue');
      expect(
        h.store.written,
        <String>['n1/0', 'n1/1', 'n1/2'],
        reason:
            'B18: in QUEUE order — the third chapter is the third stored. And the file '
            'names carry the ORDINAL, never `number`',
      );
      for (int i = 0; i < 3; i++) {
        expect(
          h.store.fileFor('n1', i).existsSync(),
          isTrue,
          reason: 'B6: chapter $i is completely present on the phone',
        );
      }
      expect(
        (await marksOf(h)).values.every((DateTime? mark) => mark != null),
        isTrue,
        reason:
            'B6/ADR-022: `2-3` wrote each mark AFTER its rename, and the row says `done`',
      );
    });

    test('⚠️ a REVERSED hand-picked order is stored in that order', () async {
      final Harness h = await harness();
      addTearDown(h.close);
      await seedNovel(h.db, chapters: 3);
      await h.repo.enqueue(<String>['c2', 'c0', 'c1']);
      final FakeContent content = FakeContent(
        <String, BrowseOutcome<String>>{},
      );
      final SerialDownloadQueueRunner runner = runnerFor(h, content);

      runner.start();
      await runner.drain();

      expect(
        content.fetched,
        <String>['c2', 'c0', 'c1'],
        reason:
            'B18: `queue_position` is what the queue READS. Re-sorting by `chapters.'
            'ordinal` here would discard the reader\'s selection, and the files would be '
            'stored in an order the reader did not ask for',
      );
    });
  });

  group('B22 / E8 / B24 — the three failure outcomes, and the loop MOVES ON', () {
    test(
      '⚠️ `BrowseEmpty` → `failed` + `source_empty`, not `done`, and it continues',
      () async {
        final Harness h = await harness();
        addTearDown(h.close);
        await seedNovel(h.db, chapters: 3);
        await h.repo.enqueue(<String>['c0', 'c1', 'c2']);
        final FakeContent content = FakeContent(<String, BrowseOutcome<String>>{
          'c0': const BrowseEmpty<String>(
            siteSuppliedSignal: 'no chapters here',
          ),
        });
        final SerialDownloadQueueRunner runner = runnerFor(h, content);

        runner.start();
        await runner.drain();

        final List<QueueRow> rows = await rowsOf(h);
        expect(
          rows[0].state,
          DownloadState.failed,
          reason: 'the empty one failed',
        );
        expect(
          rows[0].errorCode,
          QueueFailureCode.sourceEmpty.stored,
          reason:
              'E8: "the site said nothing" is not "the app has nothing" and it is not '
              '"zero results". C12: the code has to be sayable out loud',
        );
        expect(
          rows.sublist(1).map((QueueRow r) => r.state).toList(),
          <DownloadState>[DownloadState.done, DownloadState.done],
          reason:
              '§ 3.3: the `continue` is 5-1\'s. One unreadable chapter must not stop a '
              '400-chapter novel; `5-3` decides, per cause, when a queue stops',
        );
        expect(
          h.store.fileFor('n1', 0).existsSync(),
          isFalse,
          reason: 'and nothing was written for it',
        );
      },
    );

    test('⚠️ `BrowseFailed` → the taxonomy code, and the loop continues', () async {
      final Harness h = await harness();
      addTearDown(h.close);
      await seedNovel(h.db, chapters: 2);
      await h.repo.enqueue(<String>['c0', 'c1']);
      final FakeContent content = FakeContent(<String, BrowseOutcome<String>>{
        'c0': const BrowseFailed<String>(
          SourceLayoutChanged(failedSelector: '.chapter-inner', status: 200),
          retriable: false,
        ),
      });
      final SerialDownloadQueueRunner runner = runnerFor(h, content);

      runner.start();
      await runner.drain();

      final List<QueueRow> rows = await rowsOf(h);
      expect(
        rows[0].state,
        DownloadState.failed,
        reason: 'E4: a layout change is a failure',
      );
      expect(
        rows[0].errorCode,
        'source_layout_changed',
        reason:
            'B24: a typed code from `architecture.md` § 5.2. "Failed" with no reason is '
            'the state B22 exists to prevent, and an owner reading the code aloud knows '
            'which selector to look at',
      );
      expect(
        rows[1].state,
        DownloadState.done,
        reason:
            'and the next chapter is unaffected — E9: one item is gone, the rest are not',
      );
    });

    test(
      '⚠️ a source this build does NOT have → `source_unavailable`, not a crash',
      () async {
        final Harness h = await harness();
        addTearDown(h.close);
        await seedNovel(h.db, chapters: 2);
        await h.repo.enqueue(<String>['c0', 'c1']);
        final FakeContent content = FakeContent(
          <String, BrowseOutcome<String>>{},
        )..sourceMissing = true;
        final SerialDownloadQueueRunner runner = runnerFor(h, content);

        runner.start();
        await runner.drain();

        final List<QueueRow> rows = await rowsOf(h);
        expect(
          rows.map((QueueRow r) => r.errorCode).toList(),
          <String>['source_unavailable', 'source_unavailable'],
          reason:
              'B3: a stored novel can name a source this build no longer contains. That is '
              'a sentence the reader can be shown ("this novel can no longer be refreshed"), '
              'not a crash that stops a fifty-chapter queue over one novel',
        );
        expect(content.fetched, isEmpty, reason: 'and nothing was fetched');
        expect(
          (await marksOf(h)).values.every((DateTime? mark) => mark == null),
          isTrue,
          reason: 'B19: nothing was marked downloaded',
        );
      },
    );
  });

  group('E18 / B6 — a chapter with no real prose is REFUSED, not stored', () {
    test('⚠️ below the threshold → `failed` + `no_real_text`, NO file, NO mark', () async {
      final Harness h = await harness();
      addTearDown(h.close);
      await seedNovel(h.db, chapters: 2);
      await h.repo.enqueue(<String>['c0', 'c1']);
      final SerialDownloadQueueRunner runner = runnerFor(
        h,
        FakeContent(<String, BrowseOutcome<String>>{}),
        // ⚠️ **`belowPerCall: [true]` — THE FIRST CHAPTER ONLY.** The second must succeed, or the
        // test would prove "refused" without proving "and the loop carried on", which is
        // the half of § 3.3's E18 row that a one-chapter novel cannot show.
        converter: StubConverter(belowPerCall: const <bool>[true]),
      );

      runner.start();
      await runner.drain();

      final List<QueueRow> rows = await rowsOf(h);
      expect(
        rows[0].errorCode,
        QueueFailureCode.noRealText.stored,
        reason:
            'E18/B22: "this chapter converted to nothing" and "this site could not be '
            'read" are different claims. The threshold itself is `5-3`\'s; refusing to '
            'store an empty chapter is not',
      );
      expect(
        h.store.fileFor('n1', 0).existsSync(),
        isFalse,
        reason:
            'B6: a `.md` marked downloaded that opens empty is the exact state the mark '
            'exists to make unreachable',
      );
      expect(
        (await marksOf(h))['c0'],
        isNull,
        reason: 'and no mark was written — `2-3` was never called',
      );
      expect(
        rows[1].state,
        DownloadState.done,
        reason:
            '§ 3.3: `continue`, not a stop. A chapter the site published as furniture '
            'must not end a novel\'s download',
      );
    });
  });

  group('B6 / E20 — a storage failure marks NOTHING and rises to `5-3`', () {
    test(
      '⚠️ `store()` throws → `downloading`, `attempts == 1`, no mark, no `done`',
      () async {
        final Harness h = await harness();
        addTearDown(h.close);
        await seedNovel(h.db, chapters: 2);
        await h.repo.enqueue(<String>['c0', 'c1']);
        final SerialDownloadQueueRunner runner = runnerFor(
          h,
          FakeContent(<String, BrowseOutcome<String>>{}),
        );
        h.store.failNext = true;

        runner.start();
        // ⚠️ **`expectLater`, NOT `await` IN A TRY.** § 3.3's storage row says the exception
        // RISES — swallowing it is E7's over-promise in miniature, and a test that caught
        // it would be testing a loop that lied.
        await expectLater(
          runner.drain(),
          throwsA(isA<FileSystemException>()),
          reason:
              'E20: the filesystem refused. `5-3` classifies it; `5-1` must not decide that '
              'a full disk is "try the next chapter"',
        );

        final List<QueueRow> rows = await rowsOf(h);
        expect(
          rows[0].state,
          DownloadState.downloading,
          reason:
              'B6: `state = done` written before `store()` would leave a row claiming a '
              'download for a chapter that is not on the disk, and C8\'s `12 of 50` would '
              'become a lie',
        );
        expect(
          rows[0].attempts,
          1,
          reason: 'B20: the attempt is counted, which is what E15 resumes from',
        );
        expect(
          (await marksOf(h))['c0'],
          isNull,
          reason:
              'and `downloadedAt` is null — the chapter offers itself for download again',
        );
        expect(
          rows[1].state,
          DownloadState.queued,
          reason:
              'the queue stopped at the failure rather than skipping past it',
        );
        expect(
          runner.isRunning,
          isFalse,
          reason: 'the loop has ended, with the reason delivered to the caller',
        );
      },
    );
  });

  group('E15 / B20 — a process kill leaves a RESUMABLE row', () {
    test(
      '⚠️ an interrupted chapter is retried FROM THE BEGINNING, not from a fragment',
      () async {
        final Harness h = await harness();
        addTearDown(h.close);
        await seedNovel(h.db);
        await h.repo.enqueue(<String>['c0']);
        final QueueRow row = (await rowsOf(h)).single;

        // ── the kill ────────────────────────────────────────────────────────────────
        // ⚠️ **THE LOOP IS THE ONE THAT MARKS IT `downloading`, NOT THE TEST.** A
        // hand-marked row would be invisible to `pending()` — B19 says only `queued` rows
        // are pending — so pre-marking here would make the "kill" a queue that had already
        // finished, and the resume would prove nothing.
        h.store.failNext = true;
        final SerialDownloadQueueRunner first = runnerFor(
          h,
          FakeContent(<String, BrowseOutcome<String>>{}),
        );
        first.start();
        await expectLater(first.drain(), throwsA(isA<FileSystemException>()));

        final QueueRow killed = (await rowsOf(h)).single;
        expect(
          killed.state,
          DownloadState.downloading,
          reason:
              '§ 3.5: a row left `downloading` is a RESUMABLE state, not a corrupt one — '
              'nothing was marked and `attempts` counts the attempt',
        );
        expect(
          (await marksOf(h))['c0'],
          isNull,
          reason: 'and no mark: the file write never completed',
        );
        expect(
          h.store.fileFor('n1', 0).existsSync(),
          isFalse,
          reason:
              'no partial file either — `2-3` writes to a `.part` and renames',
        );

        // ── the requeue, which is `5-2`'s verb and `5-1`'s loop ──────────────────
        // ⚠️ **THE STATEMENT IS ASSIGNED BEFORE IT IS AWAITED.** `await x..y()` parses as
        // `(await x)..y()` — `await` binds tighter than a cascade — and the result is a
        // parse error rather than a wrong answer, which is the good kind of trap.
        final UpdateStatement<$QueueItemsTable, QueueRow> requeue = h.db.update(
          h.db.queueItems,
        )..where(($QueueItemsTable t) => t.id.equals(row.id));
        await requeue.write(
          const QueueItemsCompanion(
            state: Value<DownloadState>(DownloadState.queued),
          ),
        );
        final FakeContent second = FakeContent(
          <String, BrowseOutcome<String>>{},
        );
        final SerialDownloadQueueRunner resumed = runnerFor(
          h,
          second,
          converter: StubConverter(
            markdown: 'the whole chapter, from its first line',
          ),
        );

        resumed.start();
        await resumed.drain();

        expect(second.fetched, <String>[
          'c0',
        ], reason: 'the loop picked it up again');
        expect(
          (await rowsOf(h)).single.attempts,
          2,
          reason:
              'B20: the second attempt is counted as a second one, and that count is what '
              'tells a resume from a fresh fetch',
        );
        expect(
          h.store.fileFor('n1', 0).readAsStringSync(),
          'the whole chapter, from its first line',
          reason:
              '⚠️ **FROM THE BEGINNING, NOT FROM A FRAGMENT.** B20 requires the interrupted '
              'chapter to restart, and a chapter assembled from a partial write would be a '
              'file that is neither the old one nor the new one',
        );
        expect(
          (await marksOf(h))['c0'],
          isNotNull,
          reason: 'and only now — after the whole file — is the mark written',
        );
      },
    );
  });

  group('B19 — the runner NEVER writes `chapters.downloadedAt`', () {
    // ⚠️ **THE § 3.4 GREP, RUN AS A TEST.** The claim is mechanical: `2-3`'s store is the
    // only writer of the mark. A comment saying so is not evidence; a scan is.
    test('⚠️ no statement this runner emits writes the `chapters` table', () async {
      final Harness h = await harness();
      addTearDown(h.close);
      await seedNovel(h.db);
      await h.repo.enqueue(<String>['c0']);

      // ⚠️ **`UnmarkedStore`, AND THAT IS THE WHOLE ARGUMENT.** Everywhere else in this
      // file the writer also marks — faithfully, in `2-3`'s order. Here it deliberately
      // does NOT, so a non-null `downloadedAt` afterwards could only have been written by
      // the queue, and § 3.4's claim ("the only write of the mark is `2-3`'s") becomes a
      // measurement rather than a comment.
      final UnmarkedStore unmarked = UnmarkedStore(h.root);
      final FakeContent content = FakeContent(
        <String, BrowseOutcome<String>>{},
      );
      final SerialDownloadQueueRunner runner = runnerFor(
        h,
        content,
        converter: StubConverter(),
        writer: unmarked,
      );
      runner.start();
      await runner.drain();
      final List<QueueRow> log = await rowsOf(h);

      expect(log.map((QueueRow r) => r.state).toList(), <DownloadState>[
        DownloadState.done,
      ], reason: 'the queue moved the row — that is all it is allowed to do');
      expect(
        unmarked.written,
        <String>['n1/0'],
        reason:
            '⚠️ **THE WITNESS.** The chapter IS on the disk and the row IS `done`, so the '
            'loop completed B6\'s work; the only thing missing is the mark, and the only '
            'code that could have written it is the queue',
      );
      expect(
        (await marksOf(h))['c0'],
        isNull,
        reason:
            'B19/§ 3.4: `downloadedAt` is null because nothing in `5-1` wrote it. ADR-022 '
            'makes this the one write that must not exist outside `2-3` — a mark written '
            'here would be a chapter "downloaded" that no fetch has written, and B6 exists '
            'to make that unreachable',
      );
    });
  });
}
