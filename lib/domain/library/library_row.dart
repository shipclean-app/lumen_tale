// Lumen Tale — the render-ready library row, and how a queue reads on it.
//
// `6-6` § 2.2 / § 3.2 / § 3.3. Pure Dart: `domain` carries no Flutter import
// (`02-architecture.md`).
//
// ## ⚠️ This is a FOURTH type, and the three that came before are still here
//
// | type | the question it answers |
// |---|---|
// | `Novel` | what the **site** publishes |
// | `NovelRow` (drift) | what the **database** holds |
// | `LibraryEntry` (`2-5`) | what the library **stream** reports — whose `unopenedCount` is *unread among downloaded*, by `2-5`'s stated choice |
// | `LibraryRow` (this file) | what **this screen draws**, and `6-6` § 3.2's number |
//
// ⚠️ **The fourth row is not tidiness, it is a disagreement that had to be
// resolved rather than averaged.** `6-3` — which the plan names as the owner of
// the counting model — computes `unopened = SUM(CASE WHEN is_read = 0 …)` over
// **every** chapter row, and B14 says *the chapters in it that the user has not
// opened*. `2-5` chose *unread among downloaded*, for a defensible reason that
// B14's wording does not give it: a chapter that is not on the phone cannot be
// opened. Both are asserted by a passing test, so neither could be moved.
// Rendering `6-3`'s number as the badge is the plan's decision and it is the
// one that matches B14's sentence; `LibraryEntry` keeps its own meaning and its
// own consumers (`novel_details`, `source_unavailable`).
//
// ## ⚠️ `unopenedCount` IS A NUMBER AND NOT A FLAG
//
// B14 + `14-design-tokens.md`: a badge carries a **count**, and a badge at zero
// is a permanent alarm, so [UnopenedBadge] renders **nothing** for `0`.
// "A few" is not a number the reader can check, and a stale count that still
// looks fresh is exactly what B14 forbids.

import 'package:lumen_tale/domain/downloads/queue_failure_code.dart';

/// How a novel's download reads on the library row.
///
/// ⚠️ **A summary for DISPLAY, never a machine state.** `5-1`/`5-2` own the real
/// states (`queue_items.state`); this exists so E6 and E7 have a shape to render,
/// and every value here is derived by [resolveDownloadPresentation] from that
/// real state plus the two counts.
enum DownloadPresentation {
  /// Nothing is downloaded for this novel, and no queue is running.
  none,

  /// A queue is running. [LibraryRow.downloadedPair] still carries its
  /// denominator — a bare percentage is forbidden (E6).
  running,

  /// ⚠️ **E6 — stopped AFTER a transfer began.** The row must read
  /// *12 of 480 downloaded*. `running` is **interdicted** for a stopped novel:
  /// that is the whole difference between "12 of 480, at rest" and "working".
  stopped,

  /// ⚠️ **E7 — stopped because the connection was lost.**
  ///
  /// ⚠️ **The word is *stopped*, never *paused*.** "Paused" promises a resume the
  /// app will not perform: E7 says a queue stopped by a lost connection *does not
  /// resume on its own when the connection returns*, and a label that says
  /// otherwise is a promise about the network the app cannot keep.
  stoppedByConnectionLost,

  /// ⚠️ **E20 — stopped for want of space.** Distinct from [stoppedByConnectionLost]
  /// because the reader's next action differs: press *Resume*, or free storage.
  /// A generic *stopped* leaves the reader guessing between the two.
  stoppedOutOfStorage,

  /// Every chapter the site listed is on the phone. B6.
  complete,
}

/// Why a queue stopped, as far as the library row is concerned.
///
/// ⚠️ **Three values, and the third is the fallback that must stay visible.** An
/// unrecognised `queue_items.error_code` is `otherCause`, not "no cause" — a row
/// that rendered a running queue because a code it did not recognise meant it to
/// resume would claim work is happening while nothing is.
enum DownloadStopCause {
  /// The queue stopped for a reason the code column does not name.
  otherCause,

  /// E7 — `no_connection`. `QueueFailureCode.noConnection`.
  connectionLost,

  /// E20 — the write refused because the phone is full. Not a
  /// [QueueFailureCode] today; it is named here so the row has a shape for it.
  storageFull,
}

/// The queue state one novel's row reads, reduced to what § 3.3 branches on.
final class DownloadActivity {
  const DownloadActivity({required this.isRunning, this.stoppedBecause});

  /// No queue work for this novel at all.
  const DownloadActivity.idle() : isRunning = false, stoppedBecause = null;

  /// ⚠️ **[stoppedBecause] may only be non-null while [isRunning] is false.**
  ///
  /// `5-1`'s loop writes one state per item; a row that reports both at once is
  /// a row whose label cannot be chosen, which is the failure `running` for a
  /// stopped novel is. The constructor takes them separately so a caller has to
  /// say which, and [resolveDownloadPresentation] reads stopped **first**.
  final bool isRunning;
  final DownloadStopCause? stoppedBecause;

  @override
  bool operator ==(Object other) =>
      other is DownloadActivity &&
      other.isRunning == isRunning &&
      other.stoppedBecause == stoppedBecause;

  @override
  int get hashCode => Object.hash(isRunning, stoppedBecause);

  @override
  String toString() =>
      'DownloadActivity(running: $isRunning, stopped: $stoppedBecause)';
}

/// The six branches of § 3.3, in the order they are evaluated.
///
/// ⚠️ **THE STOPPED BRANCHES COME FIRST, and that ordering IS E6.** A novel whose
/// whole chapter list is on the phone *and* whose last item failed is not
/// `complete`, and a novel with a stopped queue is not `running`. Reading the
/// counts first would make both of those states render as success — C8's exact
/// prohibition on presenting an interrupted download as a finished one.
DownloadPresentation resolveDownloadPresentation({
  required int downloadedCount,
  required int chapterCount,
  DownloadActivity activity = const DownloadActivity.idle(),
}) {
  // ⚠️ `chapterCount > 0` and not `downloadedCount == chapterCount`: a novel the
  // site has published no chapter for is `0 / 0`, and calling that *complete*
  // would claim the app fetched something that does not exist.
  final DownloadPresentation? stopped = switch (activity.stoppedBecause) {
    DownloadStopCause.connectionLost =>
      DownloadPresentation.stoppedByConnectionLost,
    DownloadStopCause.storageFull => DownloadPresentation.stoppedOutOfStorage,
    DownloadStopCause.otherCause => DownloadPresentation.stopped,
    null => null,
  };
  if (stopped != null) {
    return stopped;
  }

  if (activity.isRunning) {
    return DownloadPresentation.running;
  }
  if (chapterCount > 0 && downloadedCount == chapterCount) {
    return DownloadPresentation.complete;
  }
  return DownloadPresentation.none;
}

/// Reads a `queue_items.error_code` as a cause.
///
/// ⚠️ **`null` for an unreadable code is the caller's to decide**, exactly as
/// `QueueFailureCode.parse` already insists. Here the caller — the repository
/// that builds the row — turns it into [DownloadStopCause.otherCause] rather
/// than into "no stop at all", because a queue that stopped with a code this
/// build cannot read has still stopped.
DownloadStopCause? stopCauseOf(String errorCode) {
  if (errorCode.isEmpty) {
    return null;
  }
  return switch (QueueFailureCode.parse(errorCode)) {
    QueueFailureCode.noConnection => DownloadStopCause.connectionLost,
    _ => DownloadStopCause.otherCause,
  };
}

/// One row of the library, ready to render.
final class LibraryRow {
  const LibraryRow({
    required this.novelId,
    required this.title,
    required this.sourceName,
    required this.unopenedCount,
    required this.chapterCount,
    required this.downloadedCount,
    required this.download,
    this.author,
    this.coverUrl,
    this.lastCheckedAt,
    this.lastCheckError,
    this.addedAt,
    this.lastReadAt,
  });

  /// B3 — the stable id, and what `/library/novel/:novelId` carries.
  final String novelId;

  /// ⚠️ **B10 — the site's own text, verbatim.** The only field the search
  /// queries (B45), and the only one a candidate is compared on without being
  /// rewritten.
  final String title;

  /// ADR-024 — displayed in the row's subtitle, **never** indexed, **never**
  /// searched, **never** sorted on.
  ///
  /// `null` collapses the subtitle and the row keeps its height. An empty string
  /// is not the same thing as an absence, and the library makes the difference
  /// visible rather than flattening both to a dash.
  final String? author;

  /// ⚠️ **Always shown at the end of the status line.** B40/E17/B2: two novels
  /// with the same title must be tellable apart, and the site is what tells
  /// them apart.
  final String sourceName;

  final String? coverUrl;

  /// ⚠️ **B14 — `COUNT(chapters.is_read = 0)`.** Local, exact, derived in one SQL
  /// aggregate, never a loop and never a column.
  final int unopenedCount;

  /// `COUNT(chapters.id)` — the site's own list, which is not the downloads.
  final int chapterCount;

  /// B6 — `COUNT(chapters.downloaded_at IS NOT NULL)`.
  ///
  /// ⚠️ **The mark, never a file probe.** ADR-022 makes the mark the fact; E6
  /// guarantees an interrupted transfer has none, and B33 clears it on a
  /// deliberate deletion — so an existence check could not tell "removed on
  /// purpose" from "lost".
  final int downloadedCount;

  /// B49 — `null` renders **Never checked**, in words, never "just now" and
  /// never omitted.
  final DateTime? lastCheckedAt;

  /// B22 — non-null puts a `failed` chip on the row carrying an **icon and the
  /// words** *Could not check*, while this row's [unopenedCount] stays exact:
  /// losing contact with a site changes the verification, never a local fact.
  final String? lastCheckError;

  /// How the download reads on this row. See [resolveDownloadPresentation].
  final DownloadPresentation download;

  final DateTime? addedAt;

  /// `MAX(reading_positions.updated_at)` — the *Last read* sort key.
  ///
  /// ⚠️ **Read from the position, never from `history_entries`.** They are two
  /// things: the position is per chapter and never trimmed (B46), the history is
  /// bounded and erasable (B47). Sorting a shelf by a log that can be deleted is
  /// sorting by something the reader does not control.
  final DateTime? lastReadAt;

  /// ⚠️ **E6/E7 — "12 / 480", ALWAYS with its denominator.** Never `12 %`, never
  /// `12` alone: without the denominator a reader reads a partial figure as a
  /// total, which is C8's forbidden presentation in numeric form.
  String get downloadedPair => '$downloadedCount / $chapterCount';

  /// ⚠️ **A novel the site has published no chapter for reads `0 / 0`**, and the
  /// row says exactly that. It is not an error state and not a badge.
  bool get hasNoChapters => chapterCount <= 0;

  /// B14 / a11y — **no badge at zero.** `0` in a pill is a permanent alarm; the
  /// absence of the pill is the message.
  bool get showsUnopenedBadge => unopenedCount > 0;

  /// B22 — a check failure, as a chip rather than as a missing row.
  bool get couldNotBeChecked => lastCheckError != null;

  @override
  bool operator ==(Object other) =>
      other is LibraryRow &&
      other.novelId == novelId &&
      other.title == title &&
      other.unopenedCount == unopenedCount &&
      other.chapterCount == chapterCount &&
      other.downloadedCount == downloadedCount &&
      other.download == download &&
      other.lastCheckedAt == lastCheckedAt &&
      other.lastCheckError == lastCheckError;

  @override
  int get hashCode => Object.hash(
    novelId,
    title,
    unopenedCount,
    chapterCount,
    downloadedCount,
    download,
    lastCheckedAt,
    lastCheckError,
  );

  @override
  String toString() =>
      'LibraryRow($title, $sourceName, unopened: $unopenedCount)';
}
