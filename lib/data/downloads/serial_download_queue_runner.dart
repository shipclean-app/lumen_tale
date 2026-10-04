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
// ## ⚠️ **THE LOOP MOVES ON AFTER EVERY FAILURE, AND `5-3` WILL CHANGE THAT**
//
// An unreadable chapter must not stop a 400-chapter novel; a lost connection must stop
// the queue. **The distinction is per cause, not per severity**, and `5-3` owns it.
// There is deliberately **no** `if (reason is NoConnection) break` here: that would be
// `5-3`'s work in the wrong file, untested by `5-3`'s tests. § 8 says the same thing
// about the half of `5-3` this slice must not write.
//
// ## ⚠️ `ORDER BY queue_position`, NOT BY `chapters.ordinal`
//
// A hand-picked order is stored as `queue_position` and must be honoured; re-sorting it
// by `ordinal` would discard the only thing the reader expressed. The *enqueue* sorts by
// `ordinal` (§ 3.2); the *drain* reads the position.

import 'package:lumen_tale/core/pipeline/converted_chapter.dart';
import 'package:lumen_tale/domain/downloads/chapter_content_source.dart';
import 'package:lumen_tale/domain/downloads/chapter_markdown_converter.dart';
import 'package:lumen_tale/domain/downloads/chapter_writer.dart';
import 'package:lumen_tale/domain/downloads/download_queue_repository.dart';
import 'package:lumen_tale/domain/downloads/download_queue_runner.dart';
import 'package:lumen_tale/domain/downloads/queue_entry.dart';
import 'package:lumen_tale/domain/downloads/queue_failure_code.dart';
import 'package:lumen_tale/domain/sources/browse_outcome.dart';
import 'package:lumen_tale/domain/sources/models/chapter.dart';

/// The serial drain loop. B18's first clause, as a loop.
final class SerialDownloadQueueRunner implements DownloadQueueRunner {
  SerialDownloadQueueRunner({
    required DownloadQueueRepository queue,
    required ChapterContentSource content,
    required ChapterMarkdownConverter converter,
    required ChapterWriter writer,
  }) : _queue = queue,
       _content = content,
       _converter = converter,
       _writer = writer;

  final DownloadQueueRepository _queue;
  final ChapterContentSource _content;
  final ChapterMarkdownConverter _converter;
  final ChapterWriter _writer;

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
      // ⚠️ **`pending()` HAS NO `LIMIT`, AND THE HEAD IS TAKEN HERE.** § 9: the limit
      // belongs at the call site so a test can read ten items at once. **Never
      // `.take(n)`, never a `Future.wait` over N items** — that is the parallelism B18
      // refuses.
      final List<QueueEntry> pending = await _queue.pending();
      if (pending.isEmpty) {
        return; // queue drained; `_finish` clears `_loop`
      }
      final QueueEntry head = pending.first;

      _active = head;
      // B20 — `attempts += 1`, and an item already `downloading` comes back unchanged.
      await _queue.markDownloading(head.id);
      await _attempt(head);
    }
  }

  /// One item, and **the four outcomes the fetch and the write can produce.**
  Future<void> _attempt(QueueEntry item) async {
    // ⚠️ **THE SOURCE IS RESOLVED BEFORE THE FETCH, AND `null` IS A FAILURE WITH A
    // REASON.** B3: a novel can name a source this build no longer contains, and "this
    // novel can no longer be refreshed" is a sentence the reader can be shown — a
    // `StateError` here would stop a fifty-chapter queue over one chapter.
    final String? baseUrl = _content.baseUrlOf(item.sourceId);
    if (baseUrl == null) {
      await _queue.markFailed(item.id, QueueFailureCode.sourceUnavailable);
      return;
    }

    final BrowseOutcome<String> outcome = await _content.fetchChapterContent(
      sourceId: item.sourceId,
      chapter: _sourceChapterOf(item),
    );

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
          await _queue.markFailed(item.id, QueueFailureCode.noRealText);
          return; // → next chapter, NOT a stop: E18 must not stop a 400-chapter novel
        }

        // ⚠️ **THE ORDER THAT IS B6: `store()`, THEN `markDone`.**
        //
        // `ChapterWriter` is `2-3`'s port and it writes the file before the mark; this
        // line writes `done` after it. If it throws, **nothing is marked**: the item
        // stays `downloading` with `attempts` incremented, `downloadedAt` is null, no
        // file exists, and the chapter offers itself for download again — the safe
        // direction, and E15's "resumable, not corrupt".
        await _writer.writeChapter(
          chapterId: item.chapterId,
          novelId: item.novelId,
          ordinal: item.ordinal,
          markdown: converted.markdown,
        );
        await _queue.markDone(item.id);

      case BrowseEmpty():
        // E8 / B22 — **NOT "zero results" and NOT an empty chapter.** The site said so
        // itself; the item is `failed` with a code the screen can read aloud.
        await _queue.markFailed(item.id, QueueFailureCode.sourceEmpty);

      case BrowseFailed(:final reason):
        // ⚠️ **EVERY CAUSE IS THE SAME HERE, AND THAT IS DELIBERATE.** `5-3` decides,
        // per cause, whether the queue stops or continues. This slice marks it and
        // moves to the next chapter — see the file header.
        await _queue.markFailed(item.id, QueueFailureCode.of(reason));
    }
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
