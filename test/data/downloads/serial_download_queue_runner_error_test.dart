// forge:slice 5-3
// Lumen Tale — the loop's **twelve** outcomes: which cause stops the queue and which does not.
//
// `5-3` § 11.1 and § 3.2's table, one row per line of that table.
//
// ## ⚠️ **`test()`, NEVER `testWidgets()` — THE WRITER BELOW WRITES **REAL** FILES**
//
// The `storage_full` rows have to put a real `.md.part` on a real disk and read it back,
// because E20's claim is about a *file* the reader never sees. Under `testWidgets`' fake
// async a real file future never completes and the test **hangs**, taking the suite with it.
//
// | rule | the row |
// |---|---|
// | E7, B19 | `no_connection` → `failed` + code, queue stopped, **0** further fetches |
// | rule 6 | `rate_limited` → stopped, and the gate carries the **site's** `Retry-After` |
// | B22, E4 | `source_layout_changed` → stopped, **one** row |
// | E20, B6 | `storage_full` from a write → item stays `downloading`, `attempts == 1`, no mark |
// | E8 | `source_empty` → `failed`, queue **running**, next chapter fetched |
// | E18 | `no_real_text` → `failed`, **no file**, queue `running` |
// | B24 | `parse_failed` → `failed`, queue `running` |
// | B24 | another `store()` failure → item stays `downloading`, queue stopped, reason unknown |
// | B24 | `retry` fails again → `failed`, **same wording**, `attempts` incremented |
// | B18, C8 | 12 chapters with 2 `no_real_text` → 10 stored, 2 `failed`, marks only for 10 |

import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart' show OrderingTerm, UpdateStatement, Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumen_tale/core/database/app_database.dart';
import 'package:lumen_tale/core/error/source_failure.dart';
import 'package:lumen_tale/core/error/storage_full_exception.dart';
import 'package:lumen_tale/core/pipeline/converted_chapter.dart';
import 'package:lumen_tale/data/downloads/drift_download_queue_repository.dart';
import 'package:lumen_tale/data/downloads/serial_download_queue_runner.dart';
import 'package:lumen_tale/domain/downloads/chapter_content_source.dart';
import 'package:lumen_tale/domain/downloads/chapter_markdown_converter.dart';
import 'package:lumen_tale/domain/downloads/chapter_writer.dart';
import 'package:lumen_tale/domain/downloads/queue_failure_code.dart';
import 'package:lumen_tale/domain/downloads/queue_run_state.dart';
import 'package:lumen_tale/domain/downloads/queue_stop_gate.dart';
import 'package:lumen_tale/domain/sources/browse_outcome.dart';
import 'package:lumen_tale/domain/sources/models/chapter.dart';

const String _baseUrl = 'https://www.royalroad.com';

/// A writer that can be told to fail, and a real file when it does not.
final class ScriptedWriter implements ChapterWriter {
  ScriptedWriter(this.root, {this.onMarked});

  final Directory root;
  final Future<void> Function(String chapterId)? onMarked;
  final List<String> written = <String>[];

  /// ⚠️ **SET TO FAIL THE **NEXT** WRITE ONLY.** A sticky failure would stop the row after the
  /// first attempt and the test would read as "the loop crashed" rather than "the cause
  /// decided".
  ///
  /// Typed as `Exception` rather than `Object` so `throw failure` is not a bare throw of an
  /// unknown type — `13-error-handling.md` rule 1, and `StorageFullException` and
  /// `FileSystemException` both are one.
  Exception? failNextWith;

  @override
  Future<void> writeChapter({
    required String chapterId,
    required String novelId,
    required int ordinal,
    required String markdown,
  }) async {
    final Exception? failure = failNextWith;
    if (failure != null) {
      failNextWith = null;
      // ⚠️ **THE `.part` IS WRITTEN **BEFORE** THE FAILURE.** `2-3` writes to
      // `.<ordinal>.md.part` and renames; a disk that fills has already accepted some bytes,
      // so the partial exists and E20's row can read it.
      final File partial = File('${root.path}/$novelId/.$ordinal.md.part');
      await partial.parent.create(recursive: true);
      await partial.writeAsString(markdown);
      throw failure;
    }
    final File file = File('${root.path}/$novelId/$ordinal.md');
    await file.parent.create(recursive: true);
    await file.writeAsString(markdown);
    written.add('$novelId/$ordinal');
    await onMarked?.call(chapterId);
  }

  File fileFor(String novelId, int ordinal) =>
      File('${root.path}/$novelId/$ordinal.md');

  File partialFor(String novelId, int ordinal) =>
      File('${root.path}/$novelId/.$ordinal.md.part');
}

/// A content source a test steers: one outcome per chapter.
final class ScriptedContent implements ChapterContentSource {
  ScriptedContent(this.outcomes);

  final Map<String, BrowseOutcome<String>> outcomes;
  final List<String> fetched = <String>[];

  /// ⚠️ **WHEN SET, EVERY FETCH **AT OR AFTER** [gateAt] WAITS ON [gate].**
  ///
  /// `5-3` § 11.1's "ten chapters done and then a full disk" needs the loop to be sitting
  /// *exactly* on chapter 11 while the test arranges the failure. Polling for `done >= 10`
  /// races — the loop is faster than the poll and reaches chapter 50 first, which is how the
  /// first version of that row read `11` where it wanted `10`. A `Completer` the fake awaits
  /// is the deterministic answer, and it is the same technique `5-1`'s `gate` field uses.
  Completer<void>? gate;
  int gateAt = 0;

  /// Holds the loop on the fetch whose index is [at] (0-based) until [hold] completes.
  void holdFrom(int at, Completer<void> hold) {
    gateAt = at;
    gate = hold;
  }

  /// ⚠️ **THE PROGRESS CALLBACK IS CAPTURED, BECAUSE THE PORT NOW OFFERS IT.** `5-3` § 2.3
  /// threads `onReceiveProgress` to the queue; a fake that ignores it is exactly the case
  /// `SourceRegistryChapterContent` is in, and storing it proves the runner really passes one.
  final List<void Function(int, int?)> progressHooks =
      <void Function(int, int?)>[];

  @override
  String? baseUrlOf(String sourceId) => _baseUrl;

  @override
  Future<BrowseOutcome<String>> fetchChapterContent({
    required String sourceId,
    required Chapter chapter,
    void Function(int received, int? total)? onProgress,
  }) async {
    final int index = fetched.length;
    fetched.add(chapter.id);
    progressHooks.add(onProgress ?? _ignoreProgress);
    final Completer<void>? wait = gate;
    if (wait != null && index >= gateAt) {
      await wait.future;
    }
    return outcomes[chapter.id] ??
        BrowseSucceeded<String>(<String>['<p>${'prose ' * 60}</p>']);
  }
}

/// A no-op progress callback, so a `null` from a port implementation that declines the
/// parameter is still a recordable entry rather than a `null` in a `List<Function>`.
void _ignoreProgress(int received, int? total) {}

/// A converter that answers whatever the test tells it to, one chapter at a time.
final class ScriptedConverter implements ChapterMarkdownConverter {
  ScriptedConverter({
    this.belowPerCall = const <bool>[],
    this.markdown = 'stored',
  });

  final List<bool> belowPerCall;
  final String markdown;
  int _calls = 0;

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

final class Bench {
  Bench(this.db, this.repo, this.writer, this.content, this.root, this.gate);

  final AppDatabase db;
  final DriftDownloadQueueRepository repo;
  final ScriptedWriter writer;
  final ScriptedContent content;
  final Directory root;
  final QueueStopGate gate;

  Future<void> close() async {
    await db.close();
    if (root.existsSync()) {
      root.deleteSync(recursive: true);
    }
  }
}

Future<Bench> bench({
  required Map<String, BrowseOutcome<String>> outcomes,
  int chapters = 3,
  List<bool> belowPerCall = const <bool>[],
  String markdown = 'stored',
}) async {
  final AppDatabase db = AppDatabase.forTesting(NativeDatabase.memory());
  final Directory root = Directory.systemTemp.createTempSync('lumen_5_3');
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
  return Bench(
    db,
    DriftDownloadQueueRepository(db),
    ScriptedWriter(
      root,
      onMarked: (String chapterId) async {
        final UpdateStatement<$ChaptersTable, ChapterRow> update = db.update(
          db.chapters,
        )..where(($ChaptersTable t) => t.id.equals(chapterId));
        await update.write(
          ChaptersCompanion(
            downloadedAt: Value<DateTime?>(DateTime.now().toUtc()),
          ),
        );
      },
    ),
    ScriptedContent(outcomes),
    root,
    QueueStopGate(),
  );
}

SerialDownloadQueueRunner runnerFor(
  Bench b, {
  ChapterWriter? writer,
  ChapterMarkdownConverter? converter,
}) => SerialDownloadQueueRunner(
  queue: b.repo,
  content: b.content,
  converter: converter ?? ScriptedConverter(),
  writer: writer ?? b.writer,
  gate: b.gate,
);

Future<List<QueueRow>> rowsInOrder(Bench b) =>
    (b.db.select(b.db.queueItems)
          ..orderBy(<OrderingTerm Function($QueueItemsTable)>[
            ($QueueItemsTable t) => OrderingTerm.asc(t.queuePosition),
          ]))
        .get();

Future<Map<String, DateTime?>> marksOf(Bench b) async {
  final List<ChapterRow> chapters = await b.db.select(b.db.chapters).get();
  return <String, DateTime?>{
    for (final ChapterRow c in chapters) c.id: c.downloadedAt,
  };
}

void main() {
  group('E7 / B19 — `no_connection` stops the queue and fetches nothing after', () {
    test('⚠️ the item fails, the queue stops, and chapter 2 is NEVER requested', () async {
      final Bench b = await bench(
        outcomes: <String, BrowseOutcome<String>>{
          // ⚠️ **`retriable: true` MATCHES `NoConnection.isRetriable`**, and `5-1` has a row
          // asserting the two never disagree — a `BrowseFailed` whose flag contradicts its
          // cause is a defect the whole vocabulary exists to prevent.
          'c0': const BrowseFailed<String>(
            NoConnection(host: 'www.royalroad.com'),
            retriable: true,
          ),
        },
      );
      addTearDown(b.close);
      await b.repo.enqueue(<String>['c0', 'c1', 'c2']);

      final SerialDownloadQueueRunner runner = runnerFor(b);
      runner.start();
      await runner.drain();

      final List<QueueRow> rows = await rowsInOrder(b);
      expect(
        rows[0].state,
        DownloadState.failed,
        reason: 'the chapter the connection dropped on is a failure',
      );
      expect(
        rows[0].errorCode,
        QueueFailureCode.noConnection.stored,
        reason:
            'B24: the typed code, so the screen can say *No connection* (C12)',
      );
      expect(
        b.gate.stoppedFor,
        QueueStopReason.noConnection,
        reason:
            '⚠️ **THE GATE, NOT A `failed` ROW, IS WHAT THE SCREEN READS.** The deriver reads '
            'the *last* failed row, and a queue that stopped on a `no_connection` two chapters '
            'after a `no_real_text` would otherwise report the wrong cause',
      );
      expect(
        b.content.fetched,
        <String>['c0'],
        reason:
            'B19: "no further chapter is fetched after it". The next request would fail '
            'identically and the reader would watch a queue produce nothing but failures',
      );
      expect(
        rows.sublist(1).map((QueueRow r) => r.state).toList(),
        <DownloadState>[DownloadState.queued, DownloadState.queued],
        reason:
            'B21: the survivors are still `queued`, so *Resume* starts from chapter 2',
      );
      expect(
        runner.isRunning,
        isFalse,
        reason:
            'and `isRunning` is honest again — a status bar for a queue that is not moving '
            'is a lie § 2.1 names',
      );
    });
  });

  group('`17-security.md` rule 6 — `rate_limited` WAITS for the site time it named', () {
    test('⚠️ the gate carries the `Retry-After` the site sent, not a guess', () async {
      final Bench b = await bench(
        outcomes: <String, BrowseOutcome<String>>{
          'c0': const BrowseFailed<String>(
            RateLimited(retryAfter: Duration(hours: 2)),
            retriable: true,
          ),
        },
        chapters: 2,
      );
      addTearDown(b.close);
      await b.repo.enqueue(<String>['c0', 'c1']);

      final SerialDownloadQueueRunner runner = runnerFor(b);
      runner.start();
      await runner.drain();

      expect(
        b.gate.stoppedFor,
        QueueStopReason.rateLimited,
        reason:
            'B24/C12: "the site asked us to slow down" is a sentence the reader can repeat to '
            'whoever owns the phone, and it is a different sentence from *no connection*',
      );
      expect(
        b.gate.resumeNotBefore,
        isNotNull,
        reason:
            '⚠️ **AND THE TIME COMES FROM `RateLimited.retryAfter`, NEVER FROM A CONSTANT.** '
            '`downloads.md` § 8 says the stopped row must name the hour the site asked for, '
            'and a duration invented here would be a wait the site never requested — which is '
            'the harm `17-security.md` rule 6 exists to prevent',
      );
      expect(
        b.gate.resumeNotBefore!.isAfter(DateTime.now().toUtc()),
        isTrue,
        reason: 'two hours from now, because that is what the fixture said',
      );
      expect(
        b.content.fetched,
        <String>['c0'],
        reason:
            'B19: a queue that keeps fetching a site which just asked it to stop is the '
            'thing the rule forbids',
      );
    });
  });

  group('B22 — a broken site is ONE row and a stopped queue', () {
    test('⚠️ `source_layout_changed` → one `failed` row, and nothing after it', () async {
      final Bench b = await bench(
        outcomes: <String, BrowseOutcome<String>>{
          'c0': const BrowseFailed<String>(
            SourceLayoutChanged(failedSelector: '.chapter-inner', status: 200),
            retriable: false,
          ),
        },
        chapters: 48,
      );
      addTearDown(b.close);
      await b.repo.enqueue(<String>[for (int i = 0; i < 48; i++) 'c$i']);

      final SerialDownloadQueueRunner runner = runnerFor(b);
      runner.start();
      await runner.drain();

      final List<QueueRow> rows = await rowsInOrder(b);
      expect(
        rows.where((QueueRow r) => r.state == DownloadState.failed).length,
        1,
        reason:
            '⚠️ **THE ROW THAT IS WORTH A HUNDRED.** B22: "every download from one source '
            'failing is reported as one source failure, not as forty-eight failed chapters". '
            'Forty-eight identical rows say the same thing forty-eight times and a reader can '
            'act on none of them',
      );
      expect(
        b.content.fetched,
        hasLength(1),
        reason:
            'B19: the queue stopped at the FIRST chapter, so forty-seven requests were never '
            'spent learning the same thing again',
      );
      expect(
        b.gate.stoppedFor,
        QueueStopReason.sourceUnreadable,
        reason:
            'and the queue reads as stopped-because-the-site, which is what B22 asks for',
      );
      expect(
        (await marksOf(b)).values.every((DateTime? m) => m == null),
        isTrue,
        reason:
            'B6: nothing was marked, so nothing presents itself as complete',
      );
    });
  });

  group('E20 — a full disk stops the queue WITHOUT judging the chapter', () {
    test('⚠️ the item stays `downloading`, `attempts == 1`, and no mark is written', () async {
      final Bench b = await bench(
        outcomes: <String, BrowseOutcome<String>>{},
        chapters: 2,
      );
      addTearDown(b.close);
      await b.repo.enqueue(<String>['c0', 'c1']);
      b.writer.failNextWith = const StorageFullException(4096);

      final SerialDownloadQueueRunner runner = runnerFor(b);
      runner.start();
      await runner.drain();

      final List<QueueRow> rows = await rowsInOrder(b);
      expect(
        rows[0].state,
        DownloadState.downloading,
        reason:
            '⚠️ **THE ROW OF § 3.2 THAT LOOKS LIKE A BUG.** A `failed` row says "this chapter '
            'is bad"; what is bad is the **phone**. Nobody judged the chapter, so nothing may '
            'be recorded about it',
      );
      expect(
        rows[0].attempts,
        1,
        reason:
            'B20: the attempt is counted, which is what a resume restarts from',
      );
      expect(
        (await marksOf(b))['c0'],
        isNull,
        reason:
            'E20/B6: "never records a partial chapter as complete". With no mark the chapter '
            'offers itself for download again instead of opening empty',
      );
      expect(
        b.gate.stoppedFor,
        QueueStopReason.outOfStorage,
        reason:
            'and the QUEUE is stopped with a reason it can say out loud — which is the whole '
            'difference between a row that stayed `downloading` and a row that is `failed`',
      );
      expect(
        b.gate.storageBytesNeeded,
        4096,
        reason:
            'E20/`architecture.md` § 5.2: `StorageFull` **carries** "bytes needed", and the '
            'screen shows it beside the chapter. It is NOT free space, which § 9 refuses to '
            'display at all',
      );
      expect(
        b.content.fetched,
        <String>['c0'],
        reason:
            'B19: continuing would empty the phone, so chapter 2 was never requested',
      );
      expect(
        b.writer.partialFor('n1', 0).existsSync(),
        isTrue,
        reason:
            'witness — a `.part` really is on the disk, so "no mark" above is C8 saying a '
            'partial is not a chapter rather than saying there was no partial to begin with',
      );
      expect(
        b.writer.fileFor('n1', 0).existsSync(),
        isFalse,
        reason:
            'and it was never renamed: `2-3` renames only on success (ADR-022)',
      );
    });

    test(
      '⚠️ ten chapters done and then a full disk → `10 of 50`, ten files, ten marks',
      () async {
        final Bench b = await bench(
          outcomes: <String, BrowseOutcome<String>>{},
          chapters: 50,
        );
        addTearDown(b.close);
        await b.repo.enqueue(<String>[for (int i = 0; i < 50; i++) 'c$i']);
        // ⚠️ **THE LOOP IS HELD **ON** THE ELEVENTH FETCH, NOT STOPPED AFTER THE TENTH.**
        // `shouldStopQueue('storage_full')` is what ends it in production; here the test has
        // to manufacture the moment, and a poll races a loop that reaches chapter 50 first —
        // which is how this row first read `11` where it wanted `10`.
        final Completer<void> eleventh = Completer<void>();
        b.content.holdFrom(10, eleventh);
        final SerialDownloadQueueRunner runner = runnerFor(b);
        runner.start();
        await _drainUntil(runner, b, 10);
        b.writer.failNextWith = const StorageFullException(4096);
        eleventh.complete();
        await runner.drain();

        final List<QueueRow> rows = await rowsInOrder(b);
        final int done = rows
            .where((QueueRow r) => r.state == DownloadState.done)
            .length;
        expect(
          done,
          10,
          reason:
              'C8/E20: `10 of 50 downloaded` — and **10**, not 11. A queue that counted the '
              'failed write as a download would tell the reader a chapter is on the phone when '
              'it is not',
        );
        expect(
          b.writer.written,
          hasLength(10),
          reason: 'and ten `.md` files really are on the disk',
        );
        final Map<String, DateTime?> marks = await marksOf(b);
        expect(
          marks.values.where((DateTime? m) => m != null).length,
          10,
          reason:
              'E20: "keeps every already-completed chapter" — the marks are not rolled back',
        );
        expect(
          marks['c10'],
          isNull,
          reason: 'and the interrupted one has none (B6)',
        );
        expect(
          b.gate.stoppedFor,
          QueueStopReason.outOfStorage,
          reason: 'stopped, and named',
        );
      },
    );

    test(
      '⚠️ a store failure the app CANNOT classify → stopped, reason `unknown`, no guess',
      () async {
        final Bench b = await bench(
          outcomes: <String, BrowseOutcome<String>>{},
          chapters: 2,
        );
        addTearDown(b.close);
        await b.repo.enqueue(<String>['c0', 'c1']);
        // ⚠️ **NOT A `StorageFullException`.** § 3.2 row 11: "the file written is not readable"
        // and "a store that threw something else" get a reason that does not guess.
        b.writer.failNextWith = const FileSystemException('disk full');

        final SerialDownloadQueueRunner runner = runnerFor(b);
        runner.start();
        // ⚠️ **`expectLater`, NOT A `try`.** The exception still RISES (the file header says so
        // and `5-1`'s row asserts it); the runner's job is to classify the stop, not to swallow.
        await expectLater(runner.drain(), throwsA(isA<FileSystemException>()));

        expect(
          b.gate.stoppedFor,
          QueueStopReason.unknown,
          reason:
              'B24/C12: "the phone is out of storage" would be a **plausible** sentence and not '
              'necessarily a true one — this failure could be a read-only volume or a missing '
              'directory. The screen must not guess, and the generic sentence is a claim it can '
              'actually support',
        );
        expect(
          (await rowsInOrder(b))[0].state,
          DownloadState.downloading,
          reason: 'and still no `failed` row: nobody judged the chapter',
        );
      },
    );
  });

  group('E8 / E18 / B24 — the causes that do NOT stop the queue', () {
    test(
      '⚠️ `source_empty` → `failed` + code, and the NEXT chapter IS fetched',
      () async {
        final Bench b = await bench(
          outcomes: <String, BrowseOutcome<String>>{
            'c0': const BrowseEmpty<String>(
              siteSuppliedSignal: 'no chapters here',
            ),
          },
        );
        addTearDown(b.close);
        await b.repo.enqueue(<String>['c0', 'c1', 'c2']);

        final SerialDownloadQueueRunner runner = runnerFor(b);
        runner.start();
        await runner.drain();

        final List<QueueRow> rows = await rowsInOrder(b);
        expect(
          rows[0].errorCode,
          QueueFailureCode.sourceEmpty.stored,
          reason:
              'E8: the site was read and said so itself — not "the app has nothing"',
        );
        expect(
          b.content.fetched,
          <String>['c0', 'c1', 'c2'],
          reason:
              '⚠️ **THE ROW THAT SEPARATES THE TWO POLICIES.** A page that answers with nothing '
              'is a page that answered; the next URL is a different request. Stopping here would '
              'end a 400-chapter novel over one blank page',
        );
        expect(
          b.gate.stoppedFor,
          isNull,
          reason:
              'and the queue did not stop, so the screen shows no reason at all',
        );
      },
    );

    test(
      '⚠️ `no_real_text` → `failed`, **no file**, and the queue carries on',
      () async {
        final Bench b = await bench(
          outcomes: <String, BrowseOutcome<String>>{},
          chapters: 2,
        );
        addTearDown(b.close);
        await b.repo.enqueue(<String>['c0', 'c1']);

        final SerialDownloadQueueRunner runner = runnerFor(
          b,
          converter: ScriptedConverter(belowPerCall: const <bool>[true]),
        );
        runner.start();
        await runner.drain();

        final List<QueueRow> rows = await rowsInOrder(b);
        expect(
          rows[0].errorCode,
          QueueFailureCode.noRealText.stored,
          reason:
              'E18: below the threshold is a **failure with a retry**, never a stored chapter',
        );
        expect(
          b.writer.fileFor('n1', 0).existsSync(),
          isFalse,
          reason:
              '⚠️ **B6: A `.md` MARKED DOWNLOADED THAT OPENS EMPTY IS THE STATE B6 EXISTS TO '
              'MAKE UNREACHABLE.** Storing it would be the failure this whole threshold was '
              'written to prevent',
        );
        expect(
          (await marksOf(b))['c0'],
          isNull,
          reason: 'and no mark, for the same reason',
        );
        expect(b.content.fetched, <String>[
          'c0',
          'c1',
        ], reason: 'E22: a short chapter must not end a novel');
      },
    );

    test('⚠️ `parse_failed` → `failed`, and the queue carries on', () async {
      final Bench b = await bench(
        outcomes: <String, BrowseOutcome<String>>{
          'c0': const BrowseFailed<String>(
            ParseFailed(path: 'fiction/1/n1/c0'),
            retriable: false,
          ),
        },
        chapters: 2,
      );
      addTearDown(b.close);
      await b.repo.enqueue(<String>['c0', 'c1']);

      final SerialDownloadQueueRunner runner = runnerFor(b);
      runner.start();
      await runner.drain();

      expect(
        (await rowsInOrder(b))[0].errorCode,
        QueueFailureCode.parseFailed.stored,
        reason: 'B22: one file did not survive parsing. That is one chapter',
      );
      expect(b.content.fetched, <String>[
        'c0',
        'c1',
      ], reason: 'and the rest of the queue is unaffected');
      expect(b.gate.stoppedFor, isNull, reason: 'the queue did not stop');
    });
  });

  group('B24 / B20 — a Retry that fails again says the SAME thing', () {
    test('⚠️ `retry` → `attempts == 2`, and the wording is unchanged', () async {
      final Bench b = await bench(
        outcomes: <String, BrowseOutcome<String>>{},
        chapters: 2,
      );
      addTearDown(b.close);
      await b.repo.enqueue(<String>['c0', 'c1']);
      // ⚠️ **`[true, false, true]` — THE THIRD CALL IS THE RETRY.** The converter is called
      // once per fetch, so a fixture with one `true` would let the second attempt SUCCEED and
      // the row would assert against a `done` row. The point of the row is the second
      // *failure*, so both attempts have to be refused.
      final SerialDownloadQueueRunner runner = runnerFor(
        b,
        converter: ScriptedConverter(
          belowPerCall: const <bool>[true, false, true],
        ),
      );
      runner.start();
      await runner.drain();

      final QueueRow failed = (await rowsInOrder(
        b,
      )).firstWhere((QueueRow r) => r.state == DownloadState.failed);
      expect(
        failed.state,
        DownloadState.failed,
        reason: 'E18 refused it the first time',
      );
      expect(failed.attempts, 1, reason: 'one attempt so far');
      expect(failed.errorCode, 'no_real_text', reason: 'and one reason');

      final bool requeued = await b.repo.retry(failed.id);
      expect(
        requeued,
        isTrue,
        reason: 'B24: the Retry control is offered, and it does something',
      );
      runner.start();
      await runner.drain();

      final QueueRow again = (await rowsInOrder(
        b,
      )).firstWhere((QueueRow r) => r.id == failed.id);
      expect(again.state, DownloadState.failed, reason: 'it failed again');
      expect(
        again.errorCode,
        failed.errorCode,
        reason:
            '⚠️ **THE *SAME* WORDING, AND THAT IS THE ROW.** B24/E18: a reader told two '
            'different things about the same chapter cannot describe either. A changed message '
            'would also mean the code changed, and the code is the evidence an owner reads',
      );
      expect(
        again.attempts,
        2,
        reason:
            'B20 + `downloads.md` § 9: the count is SHOWN because "it failed twice" and "it '
            'failed once" are not described the same way (C12)',
      );
    });
  });

  group('B18 / C8 — twelve chapters, two short ones, ten stored', () {
    test('⚠️ 10 `done`, 2 `no_real_text`, and marks for exactly the ten', () async {
      final Bench b = await bench(
        outcomes: <String, BrowseOutcome<String>>{},
        chapters: 12,
      );
      addTearDown(b.close);
      await b.repo.enqueue(<String>[for (int i = 0; i < 12; i++) 'c$i']);
      // ⚠️ **TWO `true`s, AT CALLS 3 AND 10, WHICH ARE CHAPTERS 3 AND 10.**
      // § 11.1's row says "12 chapters, 2 `no_real_text`"; one `true` refuses one chapter and
      // the row would then read 11 stored — a different scenario with a different meaning.
      final SerialDownloadQueueRunner runner = runnerFor(
        b,
        converter: ScriptedConverter(
          belowPerCall: const <bool>[
            false,
            false,
            true,
            false,
            false,
            false,
            false,
            false,
            false,
            true,
          ],
        ),
      );

      runner.start();
      await runner.drain();

      final List<QueueRow> rows = await rowsInOrder(b);
      expect(
        rows.where((QueueRow r) => r.state == DownloadState.done).length,
        10,
        reason: 'B18: the queue is serial and it did the other ten',
      );
      expect(
        rows
            .where(
              (QueueRow r) => r.errorCode == QueueFailureCode.noRealText.stored,
            )
            .length,
        2,
        reason: 'and the two short chapters are failures, not stored empties',
      );
      final Map<String, DateTime?> marks = await marksOf(b);
      expect(
        marks.values.where((DateTime? m) => m != null).length,
        10,
        reason:
            '⚠️ **THE C8 ROW: THE MARK IS NON-NULL FOR EXACTLY THE TEN STORED CHAPTERS.** A '
            'mark on either of the other two would make a chapter open as complete while the '
            'app holds nothing for it — the one lie this slice exists to prevent',
      );
      expect(
        b.content.fetched,
        hasLength(12),
        reason: 'E18/E22: two refusals did not end the queue',
      );
    });
  });
}

/// Runs the loop until [target] chapters are `done`, then stops it and returns.
///
/// ⚠️ **A POLL, NOT A HACK, AND THE `drain()` AT THE END IS WHAT MAKES IT DETERMINISTIC.**
/// The loop runs on real futures over real files; the test waits for the tenth `done` row and
/// then lets the loop finish, so the counts below are read from a settled database rather than
/// raced against.
Future<void> _drainUntil(
  SerialDownloadQueueRunner runner,
  Bench b,
  int target,
) async {
  for (int i = 0; i < 200; i++) {
    final List<QueueRow> rows = await rowsInOrder(b);
    if (rows.where((QueueRow r) => r.state == DownloadState.done).length >=
        target) {
      return;
    }
    await Future<void>.delayed(const Duration(milliseconds: 2));
  }
  fail('the queue never reached $target done chapters');
}
