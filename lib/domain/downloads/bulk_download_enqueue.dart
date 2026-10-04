// Lumen Tale — § 3.2's six branches, in one pure-enough function over two ports.
//
// The reader's tap on one of B18's six choices becomes an ordered set of `queue_items`
// rows. Nothing here touches the network, the clock or a filesystem, and that is § 3.2's
// branch 6 stated as an interface:
//
// > **Impossible here:** this function makes NO network call. The connection is checked
// > at the first fetch, never at enqueue — otherwise *"Downloading needs a connection"*
// > (`novel-details.md` § 11.1) would be a truth the queue has to verify **by writing**.

import 'package:lumen_tale/core/utils/logger.dart';
import 'package:lumen_tale/domain/downloads/bulk_choice.dart';
import 'package:lumen_tale/domain/downloads/bulk_choice_resolver.dart';
import 'package:lumen_tale/domain/downloads/download_queue_repository.dart';
import 'package:lumen_tale/domain/downloads/novel_download_scope.dart';
import 'package:lumen_tale/domain/downloads/queue_entry.dart';

/// Turns [choice] into queue rows for [novelId].
///
/// The six branches, all of them:
///
/// 1. **the novel has no `chapters` rows** → logged and nothing, because a novel whose
///    list has never been loaded is not a bug (B12) and not a dialog;
/// 2. **the choice resolves to nothing** → nothing, and [QueueEmptyWhy.choiceYieldsNothing]
///    so the sheet can *say why* rather than showing an empty list of options;
/// 3. **the first position is the GLOBAL `MAX(queue_position) + 1`** — the queue is one
///    queue and `queue_items` has no `novel_id`;
/// 4. **insert in `picked`'s order**, skipping a chapter already in the queue;
/// 5. **a repeated id yields one row** (guaranteed by the resolver, and the repository
///    re-checks because it is the thing that owns the primary key);
/// 6. **no network** — see the file header.
Future<QueueEnqueueOutcome> enqueueBulkChoice({
  required DownloadQueueRepository queue,
  required NovelDownloadScope scope,
  required String novelId,
  required BulkChoice choice,
}) async {
  final List<DownloadableChapter> chapters = await scope.chaptersOf(novelId);

  // ── branch 1 ────────────────────────────────────────────────────────────────
  if (chapters.isEmpty) {
    // ⚠️ **LOGGED, NOT THROWN.** B12: a novel whose chapter list has never been fetched
    // is a novel the reader has not opened yet, and every novel starts that way. An
    // exception here would put an error dialog over "nothing to download", which is the
    // wrong sentence for a state that is the normal first state.
    //
    // ⚠️ **THE NOVEL'S ID AND NOTHING ELSE** — no title, no chapter name, no URL
    // (`13-error-handling.md` rule 6, C5). An id is evidence; a title is a reader's data.
    logInfo('queue: no chapter rows for novel $novelId');
    return const QueueNothingToDownload(why: QueueEmptyWhy.noChapterRows);
  }

  final List<String> picked = resolveBulkChoice(choice, chapters: chapters);

  // ── branch 2 ────────────────────────────────────────────────────────────────
  // ⚠️ **NOT AN ERROR AND NOT A DIALOG.** Every chapter stored, or nothing unopened:
  // there is genuinely nothing to download, and the sheet says exactly that.
  if (picked.isEmpty) {
    return const QueueNothingToDownload(why: QueueEmptyWhy.choiceYieldsNothing);
  }

  // ── branches 3, 4 and 5 ─────────────────────────────────────────────────────
  // ⚠️ **`firstPosition` IS NOT PASSED, AND THAT IS THE POINT.** The repository derives
  // it from the GLOBAL maximum. Passing a novel-scoped maximum here would be the one
  // line that makes two novels' queues interleave — and the queue has no novel column to
  // separate them again.
  final List<QueueEntry> rows = await queue.enqueue(picked);

  return QueueEnqueued(rows);
}

/// What an enqueue produced.
sealed class QueueEnqueueOutcome {
  const QueueEnqueueOutcome();
}

/// Rows are in `queue_items`. [rows] is **what was actually written**, which can be fewer
/// than the choice resolved to: a chapter already in the queue is skipped, not duplicated
/// (§ 3.2 branch 4), so this count is the honest one and not `choice.size`.
final class QueueEnqueued extends QueueEnqueueOutcome {
  QueueEnqueued(List<QueueEntry> rows)
    : rows = List<QueueEntry>.unmodifiable(rows);

  final List<QueueEntry> rows;

  @override
  String toString() => 'QueueEnqueued(${rows.length})';
}

/// Nothing was queued, and the sheet has a **reason** to show rather than a blank space.
final class QueueNothingToDownload extends QueueEnqueueOutcome {
  const QueueNothingToDownload({required this.why});

  final QueueEmptyWhy why;

  @override
  String toString() => 'QueueNothingToDownload(${why.name})';
}

/// Why a choice produced nothing.
enum QueueEmptyWhy {
  /// B12 — the novel has no stored chapter list. The reader is told to load it, not that
  /// something failed.
  noChapterRows,

  /// Every chapter the choice reaches is already stored, or already read.
  choiceYieldsNothing,
}
