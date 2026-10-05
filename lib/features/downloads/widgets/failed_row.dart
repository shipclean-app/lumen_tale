// Lumen Tale — one chapter that could not be downloaded, and the list of them.
//
// `5-3` § 4.2/§ 4.3, from `downloads.md` § 3, § 5 and § 9.
//
// ## ⚠️ **A BROKEN SITE IS **ONE** ROW, NOT ONE ROW PER CHAPTER**
//
// B22, and it is the single most load-bearing sentence on this screen: *"Every download from
// one source failing is reported as one source failure, not as forty-eight failed chapters."*
// `downloads.md` § 5's reason — a 400-chapter novel whose site changed would otherwise
// produce forty-eight identical rows that say the same thing forty-eight times, and a reader
// scrolling them learns nothing and can act on none.
//
// So the collapse is **by cause, not by count**: a `source_layout_changed` or
// `source_unavailable` row becomes a single line naming the site. The three rows that are
// genuinely per-chapter — `source_empty`, `no_real_text`, `parse_failed` — stay one each.
//
// ## ⚠️ **`Retry` IS **ABSENT** FOR `downloading` AND `done`, AND THE SECTION ONLY RENDERS
// `failed` ROWS**
//
// `downloads.md` § 4 *Read-only* and § 5: while a chapter is being written there is nothing
// to replay, and a `done` row is a **stored** chapter whose removal is B33 — an explicit
// per-chapter delete with a confirmation, not a Retry that re-downloads a whole file.

import 'package:flutter/material.dart';
import 'package:lumen_tale/app/theme/lumen_colors.dart';
import 'package:lumen_tale/app/theme/lumen_spacing.dart';
import 'package:lumen_tale/core/database/app_database.dart';
import 'package:lumen_tale/domain/downloads/queue_entry.dart';
import 'package:lumen_tale/domain/downloads/queue_failure_code.dart';
import 'package:lumen_tale/features/downloads/queue_failure_copy.dart';
import 'package:lumen_tale/l10n/generated/app_localizations.dart';

/// The whole failed list, or **nothing at all** when it is empty.
///
/// ⚠️ **AN EMPTY SECTION IS NOT RENDERED** (`downloads.md` § 3 and § 4), and the check is
/// here rather than in the screen so a screen cannot forget it: `SliverList` with a label
/// over zero rows is a heading that lies about its own contents.
class FailedSection extends StatelessWidget {
  const FailedSection({
    super.key,
    required this.entries,
    required this.onRetry,
    required this.onOpenNovel,
    this.sourceNameOf,
  });

  /// Only `failed` rows should be passed in; the row widget re-checks anyway.
  final List<QueueEntry> entries;

  /// B24 — re-fetch **this chapter alone**. `downloads.md` § 5.
  final void Function(QueueEntry entry) onRetry;

  /// E9's action for a chapter the site says is gone.
  final void Function(QueueEntry entry) onOpenNovel;

  /// `QueueEntry.sourceId` → the site's display name. **`null` means the collapse names no
  /// site**, and the sentence falls back to the one that does not need one.
  final String? Function(String sourceId)? sourceNameOf;

  @override
  Widget build(BuildContext context) {
    final List<QueueEntry> failed = entries
        .where((QueueEntry e) => e.state == DownloadState.failed)
        .toList();
    if (failed.isEmpty) {
      return const SizedBox.shrink();
    }

    // ⚠️ **THE COLLAPSE IS A `Map` KEYED BY THE CAUSE, SO IT IS A TOTAL FUNCTION.**
    // Forty-eight `source_layout_changed` rows become one entry; everything else stays. The
    // alternative — a counter and a threshold — is the `attempts > 3` shape `5-3` § 7 forbids
    // by name, applied to presentation instead of policy.
    final Map<QueueFailureCode, List<QueueEntry>> byCode =
        <QueueFailureCode, List<QueueEntry>>{};
    for (final QueueEntry entry in failed) {
      byCode
          .putIfAbsent(
            QueueFailureCode.parse(entry.errorCode) ??
                QueueFailureCode.causeUnknown,
            () => <QueueEntry>[],
          )
          .add(entry);
    }

    final AppLocalizations l10n = AppLocalizations.of(context);
    final LumenSpacing spacing = LumenSpacing.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: EdgeInsets.fromLTRB(16, spacing.lg, 16, spacing.xs),
          child: Text(
            l10n.downloadsFailedSectionLabel,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: LumenColors.of(context).textSecondary,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.1,
            ),
          ),
        ),
        for (final QueueFailureCode code in byCode.keys) ...<Widget>[
          if (isCollapsedByCause(code))
            CollapsedSourceFailureRow(
              // ⚠️ **THE FIRST ROW STANDS FOR THE WHOLE GROUP**, and it is the *earliest* one
              // in `queue_position` order — the chapter the reader asked for first, which is
              // the one they will recognise.
              entry: byCode[code]!.first,
              chapterCount: byCode[code]!.length,
              sourceName: sourceNameOf?.call(byCode[code]!.first.sourceId),
            )
          else
            for (final QueueEntry entry in byCode[code]!)
              FailedRow(
                entry: entry,
                onRetry: () => onRetry(entry),
                onOpenNovel: () => onOpenNovel(entry),
              ),
        ],
      ],
    );
  }

  /// ⚠️ **THE TWO CODES THAT MEAN "THE SITE", AND NO THIRD.**
  ///
  /// `source_unavailable` is included because B3's case — a novel naming a source this build
  /// no longer contains — fails identically on every chapter of that novel, which is
  /// `downloads.md` § 5's situation wearing a different code. The three per-chapter causes
  /// are deliberately **not** here: each of them is a claim about one chapter, and merging
  /// them would hide the chapters a retry can actually fix.
  static bool isCollapsedByCause(QueueFailureCode code) =>
      code == QueueFailureCode.sourceLayoutChanged ||
      code == QueueFailureCode.sourceUnavailable;
}

/// One failed chapter: icon, name, reason, attempts, Retry.
class FailedRow extends StatelessWidget {
  const FailedRow({
    super.key,
    required this.entry,
    required this.onRetry,
    required this.onOpenNovel,
  });

  final QueueEntry entry;
  final VoidCallback onRetry;
  final VoidCallback onOpenNovel;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final LumenColors colors = LumenColors.of(context);
    final LumenSpacing spacing = LumenSpacing.of(context);
    final QueueFailureCopy copy = queueFailureCopyForStoredCode(
      entry.errorCode,
      l10n,
    );

    // ⚠️ **`downloading` AND `done` CARRY **NO ACTION AT ALL**, AND THE CHECK IS **HERE** RATHER
    // THAN IN `FailedSection`.
    //
    // `FailedSection` filters to `failed` rows, so a guard there would be invisible to a caller
    // that builds a `FailedRow` directly — and `downloads.md` § 4 *Read-only* is a statement
    // about **the row**, not about one list's filtering: a chapter mid-write has nothing to
    // replay, and a `done` row is a **stored** chapter whose removal is B33's confirmed,
    // per-chapter choice. Neither gets a Retry, and neither gets a *disabled* one (§ 11: "a
    // disabled control is a promise about a version that does not exist").
    final bool replayable = entry.state == DownloadState.failed;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, spacing.sm, 16, spacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              // ⚠️ **AN ICON **PLUS** THE WORDS, NEVER RED TEXT ALONE** — the same rule
              // `StatusChip` and `FailedChapterRetry` already carry, for the same reason.
              Icon(Icons.error_outline, size: 16, color: colors.error),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  // ⚠️ **THE CHAPTER'S OWN NAME**, never the novel's. `downloads.md` § 4:
                  // 'Every failed row names the chapter, not just the novel' — a reader with
                  // three queued novels needs to know which chapter of which.
                  l10n.downloadsFailedRowTitle(entry.chapterName),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ],
          ),
          Text(
            copy.sentence,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: colors.error),
          ),
          // ⚠️ **THE ATTEMPT COUNT, AND IT IS SHOWN EVEN WHEN IT IS ONE.**
          // `downloads.md` § 9 (E18): *"the attempt count is shown, because a threshold being
          // applied is a thing the reader deserves to know about"*, and C12 — "it failed
          // twice" and "it failed once" are not described the same way. Printing it only from
          // two would make the second failure the first thing the reader ever saw of it.
          Text(
            l10n.downloadsAttemptCount(entry.attempts),
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(color: colors.textSecondary),
          ),
          if (replayable)
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: TextButton(
                // ⚠️ **WIRED TO A REAL CALL, ALWAYS.** A `TextButton(onPressed: () {})`
                // labelled *Retry* has shipped three times in this project; the criterion here
                // is the gesture reaching `retry(queueItemId)`.
                //
                // ⚠️ **A STOPPED QUEUE'S FAILURE RE-ENTERS THE QUEUE, NOT THE CHAPTER ALONE:**
                // the chapter failed *because* the connection or the disk failed, so
                // re-fetching it on its own would fail identically. `resumeQueue` therefore
                // routes to [onRetry] as well — and the screen wires that one callback to
                // `downloadQueueControlProvider.notifier.resume()`, which is the control the
                // label names.
                onPressed: () => switch (copy.action) {
                  QueueFailureAction.retryChapter => onRetry(),
                  QueueFailureAction.openNovel => onOpenNovel(),
                  QueueFailureAction.resumeQueue => onRetry(),
                },
                child: Text(copy.actionLabel),
              ),
            ),
        ],
      ),
    );
  }
}

/// B22's one row for a broken site.
class CollapsedSourceFailureRow extends StatelessWidget {
  const CollapsedSourceFailureRow({
    super.key,
    required this.entry,
    required this.chapterCount,
    this.sourceName,
  });

  /// The first of the group — the chapter the reader asked for first.
  final QueueEntry entry;

  /// ⚠️ **HOW MANY CHAPTERS THIS ONE ROW STANDS FOR.** Printed, because hiding it would make
  /// a collapsed row look like a single failure — and a reader who knows forty-eight chapters
  /// failed needs to be told the app knows it too.
  final int chapterCount;

  final String? sourceName;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final LumenColors colors = LumenColors.of(context);
    final String? name = sourceName;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // ⚠️ **`--color-info`, NOT `--color-error`.** `downloads.md` § 12's token table
          // assigns `--color-info` to "the single-source-failure row's icon — a notice about
          // the site, not an error in the queue". The distinction is the point of the row.
          Icon(Icons.cloud_off_outlined, size: 16, color: colors.info),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  (name == null || name.trim().isEmpty)
                      ? l10n.queueCauseSourceLayoutChanged
                      : l10n.downloadsStoppedSourceUnreadable(name),
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: colors.error),
                ),
                Text(
                  // ⚠️ **THE CHAPTER COUNT, AND THE CHAPTER NAMES ARE **NOT** LISTED.** B44 and
                  // `17-security.md` rule 9: forty-eight site titles is not evidence anything
                  // needs, and the novel's title here is `QueueEntry.novelTitle`, which the
                  // row's one sentence already implies.
                  l10n.downloadsAttemptCount(chapterCount),
                  style: Theme.of(
                    context,
                  ).textTheme.labelSmall?.copyWith(color: colors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
