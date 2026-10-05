// Lumen Tale — the loop that drains the queue, one chapter at a time.
//
// `5-1` § 3.3. `data/downloads/`, not `features/` (§ 4.2: *"it is an orchestration,
// not a presentation"*).
//
// ## ⚠️ **`while` + `pending().first`, AND NEVER `Future.wait`
//
// B18: *"Downloading a novel enqueues its chapters one at a time in reading order."*
// `architecture.md` § 4.5 deleted the concurrency column to make that unchangeable —
// "a constant expressed as a column is something an implementation could change" — and
// `app_database_test.dart` asserts the column's **absence**. § 10's criterion is a test
// that interposes a counter and asserts `maxConcurrent == 1` over twelve chapters; this
// loop is the only thing that could break it.
//
// ## ⚠️ **`markDownloading` → `store()` → `markDone`, IN THAT ORDER
//
// B6/ADR-022: `2-3` writes the file **then** the mark, and this loop writes `done` only
// after `store()` returned. In the other order a storage exception leaves a `done` row
// for a chapter that is not on the disk, and C8's `12 of 50 downloaded` becomes a lie.
// A `store()` that throws leaves the item `downloading` with `attempts` incremented,
// `downloadedAt` null and no file — E15's "resumable, not corrupt" — and the exception
// propagates to `5-3`.
//
// ## ⚠️ **THE LOOP MOVES ON AFTER EVERY FAILURE, AND `5-3` NOW DECIDES WHEN IT DOES NOT**
//
// An unreadable chapter must not stop a 400-chapter novel; a lost connection must stop the
// queue. **The distinction is per cause, not per severity**, and it lives in
// `domain/downloads/queue_stop_policy.dart` — a pure `switch` over a closed enum, so the
// decision is testable without a network, a database or a file. `5-1` deliberately had no
// `if (reason is NoConnection) break` here; `5-3` added one, and it is the only one.
//
// ## ⚠️ **A `store()` THAT THROWS LEAVES THE ITEM `downloading`, AND THAT IS THE POINT**
//
// `5-3` § 3.2 has TWO rows for it. `StorageFullException` stops the queue with the reason
// *the phone is out of storage*; anything else stops it with a reason that does not guess.
// Neither writes a `failed` row, because nobody judged the **chapter** to have failed — the
// phone is full, or the rename broke. A `failed` row would say "this chapter is bad", which
// is a claim about a different thing.
//
// ## ⚠️ **NO `features/` IMPORT TO CLASSIFY THAT EXCEPTION**
//
// `ChapterStoreException` lives in `features/downloads/domain/` and `data` may not import a
// feature. So the **writer** does the classification — `features/downloads/
// stored_chapter_writer.dart` raises `StorageFullException` (a `core/error/` type every
// layer may import) and lets everything else through as itself. That is the direction
// `stored_chapter_writer.dart`'s own header already argues for, and it keeps
// `data/downloads/` free of the `data → features` edge `3-3` still owes.
//
// ## ⚠️ `ORDER BY queue_position`, NOT BY `chapters.ordinal`
//
// A hand-picked order is stored as `queue_position` and must be honoured; re-sorting it
// by `ordinal` would discard the only thing the reader expressed. The *enqueue* sorts by
// `ordinal` (§ 3.2); the *drain* reads the position.

import 'dart:convert';

import 'package:lumen_tale/core/error/source_failure.dart';
import 'package:lumen_tale/core/error/storage_full_exception.dart';
import 'package:lumen_tale/core/pipeline/converted_chapter.dart';
import 'package:lumen_tale/core/utils/logger.dart';
import 'package:lumen_tale/domain/downloads/chapter_content_source.dart';
import 'package:lumen_tale/domain/downloads/chapter_markdown_converter.dart';
import 'package:lumen_tale/domain/downloads/chapter_writer.dart';
import 'package:lumen_tale/domain/downloads/download_queue_repository.dart';
import 'package:lumen_tale/domain/downloads/download_queue_runner.dart';
import 'package:lumen_tale/domain/downloads/queue_entry.dart';
import 'package:lumen_tale/domain/downloads/queue_failure_code.dart';
import 'package:lumen_tale/domain/downloads/queue_progress_reporter.dart';
import 'package:lumen_tale/domain/downloads/queue_run_state.dart';
import 'package:lumen_tale/domain/downloads/queue_stop_gate.dart';
import 'package:lumen_tale/domain/downloads/queue_stop_policy.dart';
import 'package:lumen_tale/domain/sources/browse_outcome.dart';
import 'package:lumen_tale/domain/sources/models/chapter.dart';

/// The serial drain loop. B18's first clause, as a loop.
final class SerialDownloadQueueRunner implements DownloadQueueRunner {
  SerialDownloadQueueRunner({
    required DownloadQueueRepository queue,
    required ChapterContentSource content,
    required ChapterMarkdownConverter converter,
    required ChapterWriter writer,
    QueueStopGate? gate,
    ChapterProgressReporter? progress,
  }) : _queue = queue,
       _content = content,
       _converter = converter,
       _writer = writer,
       _gate = gate,
       _progress = progress;

  final DownloadQueueRepository _queue;
  final ChapterContentSource _content;
  final ChapterMarkdownConverter _converter;
  final ChapterWriter _writer;

  /// ⚠️ **OPTIONAL, AND OPTIONAL FOR A NAMED REASON.**
  ///
  /// `5-1`'s tests construct this loop with four arguments and must keep compiling; a
  /// required fifth would have turned every one of them into a scaffold for a parameter it
  /// does not use. A `null` gate means *"the reader asked for nothing"*, which is the
  /// correct reading of a loop nobody is driving — and it is what keeps `5-1`'s own rows
  /// green without a single edit to them.
  final QueueStopGate? _gate;

  /// ⚠️ **`null` MEANS NO PROGRESS IS REPORTED**, and the loop then reads exactly as `5-1`'s
  /// did. `5-3` § 3.1's cadence lives in the tracker, never here.
  final ChapterProgressReporter? _progress;

  /// The loop in progress, or `null`. **`isRunning` is derived from this and from
  /// nothing in the database.**
  Future<void>? _loop;

  QueueEntry? _active;

  @override
  void start() {
    // ⚠️ **IDEMPOTENT, AND THE GUARD IS HERE RATHER THAN A FLAG.** Two loops over one
    // queue is the parallelism B18 forbids, and a reader who taps *Download* twice would
    // see a chapter fetched twice. Checking `_loop != null` also covers the empty-queue
    // case: a loop that found nothing sets it back to `null`, so a second tap after a
    // finished queue starts a new one rather than joining a dead future.
    if (_loop != null) {
      return;
    }
    // ⚠️ **THE FUTURE IS STORED, NOT FIRED AND FORGOTTEN.** `drain()` needs it, and the
    // error it carries has to reach `5-3` rather than vanish into an unhandled async
    // error the reader never sees explained.
    final Future<void> running = _drain();
    _loop = running;
    running.then<void>(
      (void _) => _finish(running),
      // ⚠️ **THE ERROR IS *SWALLOWED* HERE, DELIBERATELY, AND IT IS NOT THE ONLY
      // OBSERVER.** This listener exists solely to clear `_loop`, so a failed loop still
      // ends. The error itself is still on [running], which `drain()` awaits — so § 3.3's
      // "the exception rises to `5-3`" holds, and this `onError` does not become the one
      // place a storage failure disappears.
      onError: (Object error, StackTrace stack) => _finish(running),
    );
  }

  /// ⚠️ **`identical`, NOT `= null` UNCONDITIONED.** A second `start()` while the first
  /// loop is finishing must not have its own future cleared by the first loop's
  /// completion.
  void _finish(Future<void> running) {
    if (identical(_loop, running)) {
      _loop = null;
    }
    _active = null;
  }

  @override
  bool get isRunning => _loop != null;

  @override
  QueueEntry? get activeItem => _active;

  @override
  Future<void> drain() async {
    final Future<void>? running = _loop;
    if (running == null) {
      return;
    }
    // ⚠️ **`await`, NOT `.catchError`.** A storage exception must reach `5-3`, which
    // decides what a full disk means; swallowing it here is E7's over-promise in
    // miniature — a queue that stops without saying why.
    await running;
  }

  /// The loop itself: one chapter at a time, until the queue is empty.
  Future<void> _drain() async {
    while (true) {
      // ⚠️ **THE GATE IS READ HERE, BEFORE `pending()`, AND THIS IS THE ONLY PLACE B19's
      // *"no further chapter is fetched after it"* IS ENFORCEABLE.** A gate consulted after
      // the fetch would already have spent the request, and a pause consulted after
      // `markDownloading` would leave a row `downloading` with nothing running — which is
      // exactly the `interrupted` state E15 reserves for a **process death**, and a reader
      // who paused could no longer tell "I paused this" from "this crashed".
      if (_gate?.blocksNext ?? false) {
        _progress?.endChapterProgress();
        return; // `_finish` clears `_loop`, so `isRunning` is honest again
      }

      // ⚠️ **`pending()` HAS NO `LIMIT`, AND THE HEAD IS TAKEN HERE.** § 9: the limit
      // belongs at the call site so a test can read ten items at once. **Never
      // `.take(n)`, never a `Future.wait` over N items** — that is the parallelism B18
      // refuses.
      final List<QueueEntry> pending = await _queue.pending();
      if (pending.isEmpty) {
        _progress?.endChapterProgress();
        return; // queue drained; `_finish` clears `_loop`
      }
      final QueueEntry head = pending.first;

      _active = head;
      // B20 — `attempts += 1`, and an item already `downloading` comes back unchanged.
      await _queue.markDownloading(head.id);
      if (await _attempt(head)) {
        // ⚠️ **THE LOOP STOPS HERE, AND THE CAUSE IS NOT "SEVERITY".** `shouldStopQueue` is
        // a `switch` over the typed code (`5-3` § 3.2): a lost connection, a `429`, a site
        // this build can no longer read and a full disk each stop it; an unreadable
        // chapter, a short chapter and a parse failure each do not. Nothing else in this
        // file decides, and nothing anywhere decides by counting attempts — that shape would
        // stop a queue on a hard chapter and continue through a dead site, which is the
        // inverse of B22.
        _progress?.endChapterProgress();
        return;
      }
    }
  }

  /// One item. Returns `true` when the queue must stop afterwards.
  ///
  /// ⚠️ **THE RETURN VALUE IS THE STOP DECISION AND NOT THE OUTCOME.** `false` covers all
  /// three "the loop carries on" outcomes (stored, source empty, no real text) and the two
  /// "carries on because this cause does not stop a queue" ones; `true` covers the four
  /// stopping causes. An enum of outcomes would have needed a switch in the caller whose
  /// only question is "do I return or do I go round again", and a fifth arm added later
  /// would silently read as "carry on".
  Future<bool> _attempt(QueueEntry item) async {
    // ⚠️ **THE SOURCE IS RESOLVED BEFORE THE FETCH, AND `null` IS A FAILURE WITH A
    // REASON.** B3: a novel can name a source this build no longer contains, and "this
    // novel can no longer be refreshed" is a sentence the reader can be shown — a
    // `StateError` here would stop a fifty-chapter queue over one chapter.
    final String? baseUrl = _content.baseUrlOf(item.sourceId);
    if (baseUrl == null) {
      return _fail(item, QueueFailureCode.sourceUnavailable);
    }

    final BrowseOutcome<String> outcome = await _content.fetchChapterContent(
      sourceId: item.sourceId,
      chapter: _sourceChapterOf(item),
      // ⚠️ **`(r, t) => …`, AND IT IS **THE LOOP** THAT OWNS THE CADENCE DECISION.** The
      // transport reports every chunk it receives; `QueueProgressTracker` is what turns that
      // into at most one *changed* value per 500 ms plus a heartbeat. § 3.1's third state —
      // `total > 0 ? total : null` — is applied there, because a `null` here is a lie the
      // reporter cannot see.
      onProgress: (int received, int? total) =>
          _progress?.reportChapterProgress(
            queueItemId: item.id,
            chapterId: item.chapterId,
            chapterName: item.chapterName,
            receivedBytes: received,
            totalBytes: total,
          ),
    );

    // ⚠️ **THE CANCEL GATE IS READ BEFORE ANY WRITE, AND THAT IS § 3.4's REQUIREMENT.**
    // A cancelled chapter must leave nothing on the device: no `.md` and no
    // `downloadedAt`. Reading this after `store()` would produce a chapter the reader was
    // told was cancelled, stored and marked complete.
    if (_gate?.blocksWrite ?? false) {
      return true;
    }

    switch (outcome) {
      case BrowseSucceeded<String>(:final List<String> items):
        // ⚠️ **`items` IS A `List<String>`, NOT A `String`.** `BrowseSucceeded<T>.items`
        // is a list by construction (`browse_outcome.dart`), and `fetchChapterContent`
        // puts the article's inner HTML in it. **The first element is the chapter**; an
        // empty list is a page that arrived with nothing in it, which the threshold
        // below refuses as `no_real_text` rather than being stored as an empty chapter.
        final String raw = items.isEmpty ? '' : items.first;

        final ConvertedChapter converted = _converter.convert(
          rawHtml: raw,
          baseUrl: baseUrl,
        );

        // ⚠️ **E18 IS `5-3`'s, BUT THE REFUSAL IS ALREADY CORRECT HERE.** The
        // 100-character threshold is `5-3`'s decision; refusing to store a chapter with
        // no prose is not, and storing one would produce a `.md` marked downloaded that
        // opens empty — the exact state B6 makes unreachable for everything else.
        if (converted.belowThreshold) {
          // → next chapter, NOT a stop: E18 must not stop a 400-chapter novel, and
          // `shouldStopQueue('no_real_text')` is `false` for exactly that reason (E22).
          return _fail(item, QueueFailureCode.noRealText);
        }

        // ⚠️ **THE ORDER THAT IS B6: `store()`, THEN `markDone`.**
        //
        // `ChapterWriter` is `2-3`'s port and it writes the file before the mark; this
        // line writes `done` after it. If it throws, **nothing is marked**: the item
        // stays `downloading` with `attempts` incremented, `downloadedAt` is null, no
        // file exists, and the chapter offers itself for download again — the safe
        // direction, and E15's "resumable, not corrupt".
        try {
          await _writer.writeChapter(
            chapterId: item.chapterId,
            novelId: item.novelId,
            ordinal: item.ordinal,
            markdown: converted.markdown,
          );
        } on StorageFullException catch (full) {
          // ⚠️ **`5-3` § 3.2 ROW 10: THE ITEM STAYS `downloading` AND NO `failed` ROW IS
          // WRITTEN.** A `failed` row says "this chapter is bad"; what is bad is the phone.
          // § 3.4's fourth point follows from it: no `downloadedAt` is written, so the
          // chapter offers itself for download again instead of opening as complete (B6).
          //
          // The `.part` is left where it is on purpose — `2-3` overwrites it on the next
          // `store()` of the same chapter, and E15 already requires every read to ignore
          // it.
          _gate?.storageFull(full.bytesNeeded);
          full.logStoppedWriting(item.id);
          return true;
        } catch (error) {
          // ⚠️ **`5-3` § 3.2 ROW 11: A GENERIC REASON THAT DOES NOT GUESS.** A missing
          // directory, a failed rename and an I/O error all land here, and there is no
          // sentence for any of them that would be *right* rather than plausible. So the
          // queue stops and the screen says "stopped, and this app cannot say more".
          //
          // ⚠️ **IT IS LOGGED AND NOT SWALLOWED** — `13-error-handling.md` rule 4. `drain()`
          // still rethrows it to the caller; this catch exists to *classify* the stop, and
          // dropping the error here would be the one place a storage failure disappears.
          _gate?.stopped(QueueStopReason.unknown);
          logError(
            'download queue stopped: storage failure',
            error,
            name: 'lumen.queue',
          );
          rethrow;
        }
        await _queue.markDone(item.id);
        // ⚠️ **THE CONVERTED BYTES ARE THE ONLY FIGURE THE APP CAN STATE HONESTLY.** The
        // chapter is wholly in hand here; the heartbeat ends because the chapter is over.
        final int bytes = utf8.encode(converted.markdown).length;
        _progress?.reportChapterProgress(
          queueItemId: item.id,
          chapterId: item.chapterId,
          chapterName: item.chapterName,
          receivedBytes: bytes,
          // ⚠️ **`bytes` FOR BOTH, AND NOT `null`.** This is a real total — the app measured
          // it — so unlike a transport's `Content-Length` it may be drawn as a fraction.
          totalBytes: bytes,
        );
        _progress?.endChapterProgress();
        return false;

      case BrowseEmpty():
        // E8 / B22 — **NOT "zero results" and NOT an empty chapter.** The site said so
        // itself; the item is `failed` with a code the screen can read aloud.
        return _fail(item, QueueFailureCode.sourceEmpty);

      case BrowseFailed(:final reason):
        return _fail(item, QueueFailureCode.of(reason), reason: reason);
    }
  }

  /// Marks [item] failed and answers whether the **queue** must stop.
  ///
  /// ⚠️ **THE TWO DECISIONS ARE MADE HERE, TOGETHER, AND THEY ARE NOT THE SAME DECISION.**
  /// § 3.2's table has a `failed` row for most causes *and* a `Queue` column that is a
  /// separate judgement: the row is a claim about the chapter, the stop is a claim about
  /// whether the next request has any chance of a different answer. `5-1` could only make
  /// the first; the second is `5-3`'s and lives in one `switch` over a closed enum.
  ///
  /// ⚠️ **`source_unavailable` ALSO STOPS, AND THE REASON IS B22.** A novel naming a source
  /// this build no longer contains fails identically on all four hundred of its chapters.
  Future<bool> _fail(
    QueueEntry item,
    QueueFailureCode code, {
    SourceFailure? reason,
  }) async {
    await _queue.markFailed(item.id, code);
    if (!shouldStopQueue(code.stored)) {
      return false;
    }
    // ⚠️ **THE GATE IS TOLD SO THE SCREEN CAN NAME THE REASON BEFORE ANY ROW IS READ.**
    // It is not redundant: `deriveQueueRunState` reads the *last* failed row, and a queue
    // that stopped on a `rate_limited` two chapters after a `no_real_text` would otherwise
    // report the wrong cause — the one before the one that mattered.
    _gate?.stopped(
      code == QueueFailureCode.rateLimited
          ? QueueStopReason.rateLimited
          : switch (code) {
              QueueFailureCode.noConnection => QueueStopReason.noConnection,
              QueueFailureCode.sourceLayoutChanged ||
              QueueFailureCode.sourceUnavailable =>
                QueueStopReason.sourceUnreadable,
              QueueFailureCode.storageFull => QueueStopReason.outOfStorage,
              QueueFailureCode.cancelled => QueueStopReason.cancelled,
              _ => QueueStopReason.unknown,
            },
      // ⚠️ **`retryAfter` IS TAKEN FROM THE CAUSE AND NEVER COMPUTED.** `17-security.md`
      // rule 6: `429` carries `Retry-After` and the answer is to wait for it. A duration
      // invented here would be a wait the site never asked for.
      notBefore: reason is RateLimited
          ? DateTime.now().toUtc().add(reason.retryAfter)
          : null,
    );
    return true;
  }

  /// The source's own `Chapter`, built from the row.
  ///
  /// ⚠️ **THE `memo` MAP IS EMPTY AND THAT IS CORRECT** — rule 7: memo is small,
  /// source-internal and never shown; nothing this app stored needs to survive into a
  /// fetch request.
  Chapter _sourceChapterOf(QueueEntry item) => Chapter(
    id: item.chapterId,
    novelId: item.novelId,
    // ⚠️ **`url` RELATIVE, VERBATIM** — `03-source-system.md` rule 3. A stored absolute
    // URL would keep working after the site's paths moved and break silently when they
    // did not; a relative one is resolved against the source's `baseUrl` at fetch time,
    // which is the very `baseUrl` the converter above resolved against.
    url: item.chapterUrl,
    name: item.chapterName,
    // ⚠️ **`-1` BECOMES THE SENTINEL, AND 0 STAYS 0.** Same mapping as `ChapterEntry`
    // and the mapper: an unparseable title is neither chapter zero nor chapter minus
    // one, and `0` is a real chapter.
    number: item.chapterNumber ?? ChapterRecognition.unparseable,
  );
}
