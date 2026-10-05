// Lumen Tale — the paused / stopped / running row, and the four ways it must never lie.
//
// `5-2` § 4.2/§ 4.3 and `5-3` § 4.3, from `downloads.md` § 4.
//
// ## ⚠️ **ICON **AND** WORD **AND** — NEVER COLOUR ALONE**
//
// `14-design-tokens.md` § Accessibility: *"No color-only state indicators … pair color with
// an icon or label."* `downloads.md` § 7 repeats it as a hard requirement, and C11 is a
// one-handed, night, glanced-at context. So `--color-warning` on *Paused* is a **third**
// channel after an icon and a word, never the first.
//
// ## ⚠️ **THE STOPPED STATE SAYS WHY, AND THEN SAYS IT WILL NOT RESTART BY ITSELF**
//
// E7, and `downloads.md` § 4 *Offline*: the reason in words on one line, and *It will not
// continue on its own when the signal comes back* on the next. The second sentence is the one
// that closes the trap: a reader whose queue stopped without it will assume the app will
// pick it up when the bar improves, and be wrong for ever.
//
// ## ⚠️ **`interrupted` IS NEVER RENDERED, AND THE `switch` SAYS SO EXPLICITLY**
//
// `downloads.md` § 8: *"interrupted is the state after the process died and is always reset
// to paused on open, never to running."* By the time a widget sees it the reset has already
// happened. The arm below renders it as [QueueRunState.paused] **and says why in a comment**,
// because the alternative — silently falling through — would make a domain value reach a
// screen the moment somebody removed a branch.
//
// ## ⚠️ **THE RESUME CONTROL IS PRIMARY (`FilledButton`) AND THE PAUSE IS NOT**
//
// `downloads.md` § 2's *Accent used*: `--color-accent` appears **only** on the determinate
// progress line and on the `primary` **Resume** button — "not on section labels, not on
// completed rows, not on the counts". A paused queue's one useful act is the accent button.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lumen_tale/app/theme/lumen_colors.dart';
import 'package:lumen_tale/app/theme/lumen_spacing.dart';
import 'package:lumen_tale/domain/downloads/queue_run_state.dart';
import 'package:lumen_tale/features/downloads/widgets/storage_full_notice.dart';
import 'package:lumen_tale/l10n/generated/app_localizations.dart';

/// The queue's status row: what it is doing, or why it stopped.
class QueueRunStateRow extends StatelessWidget {
  const QueueRunStateRow({
    super.key,
    required this.run,
    required this.onResume,
    this.sourceName,
    this.notBefore,
    this.storageBytesNeeded,
  });

  final QueueRun run;

  /// B22 — the broken site's **display name**, when this queue belongs to one this build can
  /// resolve. `null` for every other stop reason, and for a site id no longer in the registry
  /// — and the sentence then falls back to *"this app can no longer read this site"*, which
  /// is still true and is sayable.
  ///
  /// ⚠️ **A NAME, NEVER A `sourceId`.** `QueueEntry.sourceId` is a 32-character MD5, and
  /// "Lumen Tale could not read 3f2a…" is not a sentence C12 can use. The screen resolves it
  /// through `SourceManager` and passes the name, because resolution belongs to the screen
  /// and this widget must not reach for a registry.
  final String? sourceName;

  /// E7 — wakes the stopped queue. **Never called from this widget's build.**
  final VoidCallback onResume;

  /// `17-security.md` rule 6 — the `Retry-After` time the **site** named, rendered as a
  /// clock time. `null` for every other reason, and the rate-limited sentence then omits the
  /// clause rather than inventing an hour.
  final DateTime? notBefore;

  /// E20 — what the chapter the app was writing needed, or `null`. **Never a free-space
  /// figure**; see `storage_full_notice.dart`'s header for the rule.
  final int? storageBytesNeeded;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final QueueRunState state = run.state;

    // ⚠️ **`interrupted` AND `idle` BOTH RENDER NOTHING**, and this is not a shrug — the
    // screen does not call this widget for `idle` at all (`downloads.md` § 4: the queue
    // section is not rendered), and § 3.1's reset has already turned `interrupted` into
    // `paused`. Returning `SizedBox.shrink()` rather than an `if` in the caller means a
    // future state cannot accidentally draw a row.
    if (state == QueueRunState.idle) {
      return const SizedBox.shrink();
    }

    final bool stopped = state == QueueRunState.stopped;
    final Color tone = stopped
        ? LumenColors.of(context).error
        : LumenColors.of(context).warning;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(
                stopped ? Icons.error_outline : Icons.pause_circle_outline,
                size: 18,
                color: tone,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  stopped
                      ? l10n.downloadsStoppedLabel
                      : l10n.downloadsPausedLabel,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(color: tone),
                ),
              ),
              // ⚠️ **THE ORDER IS *Paused* THEN *Resume*, AND IT IS NOT SWAPPED BY THE
              // REASON.** A stopped queue's row shows both its reason and its *Resume*; the
              // reason is the second line, never a replacement for the button.
              FilledButton(
                onPressed: onResume,
                child: Text(l10n.downloadsResumeAction),
              ),
            ],
          ),
          if (stopped) ...<Widget>[
            SizedBox(height: LumenSpacing.of(context).xs),
            Text(
              _reasonOf(context),
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: tone),
            ),
            // ⚠️ **AND THE SENTENCE THAT CLOSES THE TRAP**, on its own line. `downloads.md`
            // § 4 puts it directly beneath the reason, and § 2.1 says it is repeated
            // *inside* the stopped state — the standing notice above the title is not a
            // substitute for it here.
            //
            // ⚠️ **BUT NOT FOR A FULL DISK.** *"when the signal comes back"* is **false** when
            // the disk is full and the signal is perfect, and a notice that is wrong in the
            // one state where the reader has a concrete action to take is worse than none.
            // The same goes for a cancellation, where there is no queue left to continue.
            if (saysItWillNotContinue)
              Text(
                l10n.downloadsWillNotContinueOnItsOwn,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: LumenColors.of(context).textSecondary,
                ),
              ),
            if (run.stopReason == QueueStopReason.outOfStorage)
              StorageFullNotice(
                bytesNeeded: storageBytesNeeded,
                onResume: onResume,
              ),
          ],
        ],
      ),
    );
  }

  /// ⚠️ **A `switch` ON THE REASON, NOT A `bool` FIELD.** "Does the notice apply?" has three
  /// answers that are not yes/no, and collapsing them into one flag is how *It will not
  /// continue when the signal comes back* ends up printed under a full disk.
  bool get saysItWillNotContinue => switch (run.stopReason) {
    QueueStopReason.noConnection => true,
    QueueStopReason.rateLimited => true,
    QueueStopReason.sourceUnreadable => true,
    QueueStopReason.unknown => true,
    // ⚠️ **THE SIGNAL IS FINE. THE DISK IS NOT.** And a cancelled queue has nothing left to
    // continue at all.
    QueueStopReason.outOfStorage => false,
    QueueStopReason.cancelled => false,
  };

  /// ⚠️ **THE REASON IS A `switch` WITH NO `default`, AND EVERY ARM IS A SENTENCE.**
  ///
  /// B22/C12: a reader who can only say "the downloads stopped" cannot report a problem.
  /// Each value names a cause the reader can repeat out loud, and `unknown` gets the generic
  /// one rather than a guess.
  String _reasonOf(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    switch (run.stopReason) {
      case QueueStopReason.noConnection:
        return l10n.downloadsStoppedNoConnection;
      case QueueStopReason.rateLimited:
        final DateTime? when = notBefore;
        // ⚠️ **THE GENERIC RATE-LIMITED SENTENCE WHEN THERE IS NO TIME TO NAME.** `5-3`
        // § 3.2 says the row must name the `Retry-After` time; `null` means this build could
        // not read one, and inventing an hour would be exactly the guess `17-security.md`
        // rule 6 forbids.
        return when == null
            ? l10n.queueCauseRateLimited
            : l10n.downloadsStoppedRateLimited(
                DateFormat.jm(l10n.localeName).format(when.toLocal()),
              );
      case QueueStopReason.sourceUnreadable:
        // ⚠️ **THE SITE'S NAME WHEN IT RESOLVES, AND THE SENTENCE WITHOUT IT WHEN IT DOES
        // NOT.** B22 wants ONE line naming the site rather than forty-eight; a line that says
        // "could not read 3f2a91…" has named a hash, and a hash cannot be reported to anyone.
        final String? name = sourceName;
        return (name == null || name.trim().isEmpty)
            ? l10n.queueCauseSourceLayoutChanged
            : l10n.downloadsStoppedSourceUnreadable(name);
      case QueueStopReason.outOfStorage:
        // ⚠️ **NO FIGURE, AND NOT BECAUSE IT IS UNAVAILABLE.** `downloads.md` § 9: free space
        // is not displayed; the app has no honest way to read it. The sentence is the fact
        // plus the action, which is the whole of what can be said truthfully.
        return l10n.downloadsStoppedOutOfStorage;
      case QueueStopReason.cancelled:
        return l10n.downloadsCancelledKept(run.doneCount);
      case QueueStopReason.unknown:
        return l10n.queueCauseUnknown;
    }
  }
}
