// Lumen Tale — `/more/downloads`: the queue's controls, its failed chapters, and the notice
// that is always there.
//
// `5-2` § 4.3 + `5-3` § 4.3, from `downloads.md` § 3 and § 4.
//
// ## ⚠️ **NINE STATES, AND THIS SCREEN OWNS SEVEN OF THEM**
//
// `downloads.md` § 4 enumerates nine. This file renders the seven that belong to it: Filled
// (running / paused / stopped), Empty-never-visited, Load error, Submit error (a), Offline
// and Read-only. The *loading* state is explicitly **not** a whole-screen loader — § 4 says so
// and explains why (the queue is local records, so the rows are immediate) — and the
// Read-only state's rendering is the **absence** of per-chapter controls, which is enforced by
// `QueueActions` and `RunningChapterRow` rather than by a branch here.
//
// ## ⚠️ **ONE `QueueSection` PER NOVEL, AND NEVER ONE MERGED LIST**
//
// `5-3` § 3.6 (E17): `queue_items` has no `novel_id`, so the flat row list is split by
// `novelId` and **each group keeps its own counts**. Two novels with the same title from
// different sites are two queues with two counters — never a total aggregated over a title.
// § 3.6's own text says "one QueueSection at a time"; this renders one per group instead, and
// the deviation is deliberate: hiding a *paused* queue for novel B behind a novel A that
// happens to sort first is the worse of the two errors, and E17's criterion is about the
// counters, which per-group rendering satisfies exactly.
//
// ## ⚠️ **THE SCREEN COMPUTES NOTHING** — it derives one `QueueRun` per group and hands it down.
//
// `05-state-management.md` rule 6: widgets read providers and call notifiers. Two widgets each
// deciding "is the queue paused" is how two of them end up disagreeing about the one thing C8
// forbids drifting.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lumen_tale/app/router/app_router.dart';
import 'package:lumen_tale/app/theme/lumen_spacing.dart';
import 'package:lumen_tale/core/ui/app_scaffold.dart';
import 'package:lumen_tale/core/ui/app_snackbar.dart';
import 'package:lumen_tale/core/ui/cancel_queue_dialog.dart';
import 'package:lumen_tale/domain/downloads/chapter_progress.dart';
import 'package:lumen_tale/domain/downloads/queue_entry.dart';
import 'package:lumen_tale/domain/downloads/queue_groups.dart';
import 'package:lumen_tale/domain/downloads/queue_progress_counts.dart';
import 'package:lumen_tale/domain/downloads/queue_run_state.dart';
import 'package:lumen_tale/domain/downloads/queue_run_state_deriver.dart';
import 'package:lumen_tale/features/downloads/providers/download_progress_provider.dart';
import 'package:lumen_tale/features/downloads/providers/download_queue_control_provider.dart';
import 'package:lumen_tale/features/downloads/providers/download_queue_provider.dart';
import 'package:lumen_tale/features/downloads/widgets/chapter_progress_line.dart';
import 'package:lumen_tale/features/downloads/widgets/failed_row.dart';
import 'package:lumen_tale/features/downloads/widgets/in_process_notice.dart';
import 'package:lumen_tale/features/downloads/widgets/queue_actions.dart';
import 'package:lumen_tale/features/downloads/widgets/queue_count_label.dart';
import 'package:lumen_tale/features/downloads/widgets/queue_run_state_row.dart';
import 'package:lumen_tale/l10n/generated/app_localizations.dart';

/// `/more/downloads`. Registered in `main.dart`'s `registerScreens`, resolved by
/// `app_router.dart`'s `screenBuilderFor(AppRoutes.downloads)`.
class DownloadsScreen extends ConsumerWidget {
  const DownloadsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final QueueControlState control = ref.watch(downloadQueueControlProvider);

    // ⚠️ **THE **STREAM** PROVIDER IS WATCHED FOR THE ASYNC STATE, NOT THE NOTIFIER.**
    // `downloadQueueProvider` is a `NotifierProvider` and its state is already a
    // `QueueState` with the rows read out of the stream — it has no `loading` and no `error`
    // arm to switch on, so § 4's *Load error* would be unreachable through it. The stream is
    // the `AsyncValue`, and it is also the thing to invalidate on *Try again*.
    //
    // ⚠️ **`value`, NOT `valueOrNull` AND NOT `requireValue`.** `AsyncValue.value` is the
    // nullable getter and `requireValue` throws while a drift stream is still loading — a
    // downloads screen that crashed on its first frame would be a bug in the queue's lifetime
    // rather than in the reader's data (`5-1`'s notifier header says the same).
    final AsyncValue<List<QueueEntry>> rows = ref.watch(
      downloadQueueStreamProvider,
    );
    final List<NovelQueueGroup> groups = groupQueueByNovel(
      rows.value ?? const <QueueEntry>[],
    );

    return AppScaffold(
      titleBar: AppBar(title: Text(l10n.downloadsTitle)),
      content: switch (rows) {
        AsyncError<List<QueueEntry>>(error: final Object _) => _LoadError(
          onRetry: () => ref.invalidate(downloadQueueStreamProvider),
        ),
        _ when groups.isEmpty => ListView(
          padding: EdgeInsets.zero,
          children: const <Widget>[
            // ⚠️ **THE NOTICE IS FIRST, IN EVERY STATE, INCLUDING THE EMPTY ONE.**
            // `downloads.md` § 2.1: "it is the first line under the title, it is always
            // there". § 3's anatomy places it above every section, and § 2.1 has it repeated
            // inside the stopped state — which `QueueRunStateRow` prints.
            InProcessNotice(),
            _EmptyDownloads(),
          ],
        ),
        _ => ListView(
          padding: EdgeInsets.zero,
          children: <Widget>[
            const InProcessNotice(),
            for (final NovelQueueGroup group in groups)
              QueueSection(group: group, control: control),
          ],
        ),
      },
    );
  }
}

/// One novel's queue: header counts, the running chapter, the status row, the controls and
/// the failed chapters.
class QueueSection extends ConsumerWidget {
  const QueueSection({super.key, required this.group, required this.control});

  final NovelQueueGroup group;
  final QueueControlState control;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final LumenSpacing spacing = LumenSpacing.of(context);

    // ⚠️ **ONE DERIVATION PER GROUP, AND THE ROWS ARE **THE GROUP'S** — NOT THE FLAT LIST.**
    // `deriveQueueRunState` is the only place the run state is decided
    // (`queue_run_state_deriver.dart`'s header), and giving it the group's rows is what makes
    // E17's "two counters" true rather than aspirational.
    final QueueRun run = deriveQueueRunState(
      entries: group.entries,
      // ⚠️ **SESSION STATE ONLY, AND THAT IS CORRECT.** `QueueState.isRunning` is refreshed
      // when the row stream emits — which is *after* a chapter finishes — and `control` is the
      // session mirror the notifier writes the instant *Resume* starts the loop. Nothing else
      // is allowed in here: `5-1` explicitly says `isRunning` is a field and not
      // `queue_items.state != done`.
      isRunning: control.isRunning,
      sessionStopReason: control.stoppedFor,
    );

    // ⚠️ **`idle` RENDERS **NOTHING AT ALL**.** `downloads.md` § 4: the queue section is not
    // rendered — not a "Paused" row, not a disabled *Resume*. § 11 lists "a disabled *Pause*"
    // under *"Claims this screen refuses to make"*.
    if (run.state == QueueRunState.idle) {
      return const SizedBox.shrink();
    }

    final QueueEntry? active = run.activeItem;
    final String? sourceName = _sourceNameOf(ref, group.sourceId);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: EdgeInsets.fromLTRB(16, spacing.sm, 16, 0),
          child: Text(
            group.novelTitle,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(16, spacing.xs2, 16, spacing.sm),
          child: QueueCountLabel(
            counts: group.counts,
            // ⚠️ **`labelOf` IS A CALLBACK BECAUSE THE SENTENCE IS LOCALIZED**, and
            // `queue_count_label.dart`'s header says why this widget holds no string of its
            // own: the wording belongs to the screen, not to a shared widget.
            labelOf: (QueueProgressCounts counts) =>
                l10n.downloadsHeaderCounts(counts.downloaded, counts.total),
          ),
        ),
        if (active != null)
          RunningChapterRow(
            entry: active,
            position: group.counts.downloaded + 1,
            total: group.counts.total,
          ),
        QueueRunStateRow(
          run: run,
          sourceName: sourceName,
          notBefore: control.resumeNotBefore,
          storageBytesNeeded: control.storageBytesNeeded,
          onResume: () =>
              ref.read(downloadQueueControlProvider.notifier).resume(),
        ),
        QueueActions(
          // ⚠️ **`canPause` IS `run.canPause`, WHICH IS `state == running`.** § 3.2 row 4: a
          // Pause on a queue that is not running produces no write at all — and § 4's
          // *Read-only* state wants the control **absent**, not dimmed.
          canPause: run.canPause,
          onPause: () =>
              ref.read(downloadQueueControlProvider.notifier).pause(),
          onCancel: () => _confirmAndCancel(context, ref, run),
        ),
        FailedSection(
          entries: group.entries,
          onRetry: (QueueEntry entry) =>
              ref.read(downloadQueueControlProvider.notifier).retry(entry.id),
          onOpenNovel: (QueueEntry entry) =>
              openNovelDetails(context, novelId: entry.novelId),
          sourceNameOf: (_) => sourceName,
        ),
      ],
    );
  }

  /// ⚠️ **THE SITE'S NAME, OR `null`.** `QueueEntry.sourceId` is an MD5 and a hash cannot be
  /// read aloud to whoever owns the phone (C12), so B22's collapsed row needs the registry. A
  /// source this build no longer holds resolves to `null` and the sentence falls back to the
  /// one that does not need a name.
  static String? _sourceNameOf(WidgetRef ref, String sourceId) =>
      ref.watch(sourceManagerProvider).byId(sourceId)?.name;

  /// ⚠️ **CONFIRM FIRST, THEN CANCEL — AND THE DIALOGUE IS B19'S SHARED ONE.**
  ///
  /// The dialogue comes before the notifier on purpose: `cancel()` sets the loop's stop flag
  /// before its first write, and a confirmation the reader has not given must not have that
  /// effect. § 3.5's failure path is handled here too, because the *screen* is what shows the
  /// sentence a cancelled-looking queue must never be shown without.
  Future<void> _confirmAndCancel(
    BuildContext context,
    WidgetRef ref,
    QueueRun run,
  ) async {
    final QueueEntry? active = run.activeItem;
    final bool confirmed = await confirmCancelQueue(
      context: context,
      data: CancelQueueDialogData(
        keptCount: run.doneCount,
        activeChapterTitle: active?.chapterName,
      ),
    );
    if (!confirmed || !context.mounted) {
      return;
    }

    final QueueQueueControl queueControl = ref.read(
      downloadQueueControlProvider.notifier,
    );
    final int? removed = await queueControl.cancel();
    if (!context.mounted) {
      return;
    }
    final AppLocalizations l10n = AppLocalizations.of(context);
    if (removed == null) {
      // ⚠️ **`removed == null` IS THE FAILED WRITE, AND IT INVERTS THE DISPLAY.** `5-2`
      // § 3.5: the queue keeps running and a snackbar says exactly that — the one submission
      // in the app whose failure must not leave the screen showing a state the app does not
      // hold (B19, B24).
      showAppSnackBar(context, message: l10n.downloadsCancelFailedSnackbar);
      return;
    }
    // ⚠️ **THE SNACKBAR REPORTS **WHAT SURVIVED**, NOT THAT SOMETHING WAS CANCELLED.** B19: the
    // reader needs to know whether chapter 12 is still on the phone, and a bare "cancelled"
    // does not answer that.
    showAppSnackBar(
      context,
      message: l10n.downloadsCancelledKept(run.doneCount),
    );
  }
}

/// The chapter being fetched: its name, its bar, and **no controls at all**.
///
/// ## ⚠️ **NO PAUSE, NO CANCEL, NO RETRY — `downloads.md` § 4 *Read-only***
///
/// *"The running row's controls are **absent, not disabled**. A chapter is stored atomically
/// — wholly present or wholly absent (B20, C8) — so there is no meaningful state to cancel
/// the write."* Cancelling the **queue** is meaningful and stays available one level up in
/// [QueueActions]; cancelling *this file* is not a state the storage format can represent.
/// § 11.2's row asserts the absence, so this widget must not grow a button.
class RunningChapterRow extends ConsumerWidget {
  const RunningChapterRow({
    super.key,
    required this.entry,
    required this.position,
    required this.total,
  });

  final QueueEntry entry;
  final int position;
  final int total;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ChapterProgress? progress = ref.watch(downloadProgressProvider).value;
    final AppLocalizations l10n = AppLocalizations.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            entry.chapterName,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          ChapterProgressLine(
            // ⚠️ **`fraction` IS `null` WHEN THE TOTAL IS UNKNOWN, AND `ChapterProgressLine`
            // RENDERS NOTHING** — `downloads.md` § 8 and C8: an absent `Content-Length` means
            // the figure is **omitted**, and a bar at zero that never moves is a bar that
            // lies.
            progress: progress?.fraction,
            // ⚠️ **AND THE SPOKEN VALUE CARRIES THE PERCENTAGE, WITH OR WITHOUT ONE.**
            // `downloads.md` § 7 asks for *Chapter 13 of 50, 41 per cent*; § 8 forbids
            // standing a `0` in for an unknown one, so the percentage clause **disappears**
            // rather than becoming zero.
            spokenValue: progress == null
                ? null
                : (progress.fraction == null
                      ? l10n.downloadsSemanticsProgressUndetermined(
                          position,
                          total,
                        )
                      : l10n.downloadsSemanticsChapterProgress(
                          position,
                          total,
                          (progress.fraction! * 100).round(),
                        )),
          ),
        ],
      ),
    );
  }
}

/// `downloads.md` § 4 *Empty — never visited*, and § 11's "the two empty states are a sentence
/// and one button".
class _EmptyDownloads extends StatelessWidget {
  const _EmptyDownloads();

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    // ⚠️ **THE NOTICE IS **NOT** IN THIS FRAGMENT, AND IT IS A FRAGMENT ON PURPOSE.**
    // `downloads.md` § 2.1 says the notice is in EVERY state and § 4's empty state is one of
    // them, so the screen above places `InProcessNotice` first in both branches. The obvious
    // refactor is to make the empty state a full page — and that refactor would silently drop
    // E7's standing line from the screen a first-time reader sees.
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: <Widget>[
          Text(
            l10n.downloadsEmptyTitle,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          // ⚠️ **THE BODY STATES THE BENEFIT, NOT THE MECHANISM.** § 4: *"Downloaded chapters
          // read with no signal at all"* — that is the one thing a download queue is for, and
          // it is what a reader deciding whether to bother needs.
          Text(
            l10n.downloadsEmptyBody,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          FilledButton(
            // ⚠️ **WIRED, AND IT IS `openBrowse`.** § 4: the primary action "starts the
            // discover loop rather than explaining the queue". A button that only closed the
            // screen would be the third dead control this project has shipped.
            onPressed: () => openBrowse(context),
            child: Text(l10n.downloadsEmptyActionBrowse),
          ),
        ],
      ),
    );
  }
}

/// `downloads.md` § 4 *Load error*, and B23: the copy exists to stop the reader from doing
/// something irreversible while the app is confused.
class _LoadError extends StatelessWidget {
  const _LoadError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              l10n.downloadsLoadErrorTitle,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            // ⚠️ **THE REASSURANCE IS THE POINT.** With no backup (ADR-010) the reader's first
            // assumption on this screen is data loss, and "something went wrong" is the least
            // useful sentence available. B23 says what survives, by name.
            Text(
              l10n.downloadsLoadErrorBody,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: onRetry,
              child: Text(l10n.downloadsLoadErrorRetry),
            ),
          ],
        ),
      ),
    );
  }
}
