// Lumen Tale — the `/history` screen, and its nine states.
//
// `history.md` § 4. Three of the nine have a second rendering, and each split says
// why in the design; the two that matter most here:
//
//   **empty-no-data splits in two.** Being cleared *by the reader* and being *aged
//   out* are different events with different emotional weight. One merged state would
//   have to pick a sentence, and whichever sentence lost would be a lie about what
//   happened to the reader's log.
//
//   **the load error names three survivals by name.** The fear on this screen is data
//   loss, and this app has no backup (ADR-010), so naming what survives is the only
//   thing that stops a reader assuming the worst.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:lumen_tale/app/router/app_router.dart';
import 'package:lumen_tale/core/ui/app_scaffold.dart';
import 'package:lumen_tale/core/ui/settings_choice_sheet.dart';
import 'package:lumen_tale/domain/history/history_grouping.dart';
import 'package:lumen_tale/domain/history/history_retention.dart';
import 'package:lumen_tale/features/history/history_providers.dart';
import 'package:lumen_tale/features/history/history_time_labels.dart';
import 'package:lumen_tale/features/history/widgets/history_chrome.dart';
import 'package:lumen_tale/features/history/widgets/history_entry_row.dart';
import 'package:lumen_tale/l10n/generated/app_localizations.dart';

/// What the reader reads for a window.
///
/// ⚠️ A `switch` over the enum and **not** `window.name`. This is the one place the
/// enum and a sentence meet, and `threeMonths` is a Dart identifier, not a phrase in
/// either language.
String windowLabelOf(AppLocalizations l10n, HistoryRetention window) {
  return switch (window) {
    HistoryRetention.oneWeek => l10n.historyWindowOneWeek,
    HistoryRetention.oneMonth => l10n.historyWindowOneMonth,
    HistoryRetention.threeMonths => l10n.historyWindowThreeMonths,
    HistoryRetention.oneYear => l10n.historyWindowOneYear,
    HistoryRetention.twoYears => l10n.historyWindowTwoYears,
  };
}

/// The five rows, **from the enum** — `design-system.md` § 2.12: a screen may not
/// restate the list.
List<SettingsChoiceOption<HistoryRetention>> retentionOptions(
  AppLocalizations l10n,
) {
  return <SettingsChoiceOption<HistoryRetention>>[
    for (final HistoryRetention window in HistoryRetention.values)
      SettingsChoiceOption<HistoryRetention>(
        value: window,
        label: windowLabelOf(l10n, window),
      ),
  ];
}

/// The sheet's warning sentence, and **the `historySheetWarningNone` branch is
/// load-bearing**.
String sheetWarning(
  AppLocalizations l10n,
  HistoryRetention window,
  int wouldDrop,
) {
  if (wouldDrop == 0) {
    // "Entries older than one year will be dropped" when nothing would be is a
    // sentence that makes the reader hesitate for no reason, and it is worse than
    // useless: it trains readers to distrust every sentence this sheet produces.
    return l10n.historySheetWarningNone;
  }
  return l10n.historySheetWarning(windowLabelOf(l10n, window));
}

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  /// Read once per open, and **disclosed**: the relative times are written against
  /// this instant, so "2 hours ago" is true when the screen opened and stale by the
  /// time the reader reads it. Reading `DateTime.now()` per row would make the same
  /// list disagree with itself as it scrolls.
  final DateTime _openedAt = DateTime.now();

  /// Whether the library holds anything, and whether that is **known yet**.
  ///
  /// ⚠️ **`null` means "not checked", and it is a third value on purpose.** The empty
  /// state asks *"has this reader ever opened anything?"*, and the answer is a fact
  /// about the **library**, not about the journal: a chapter can only be opened from a
  /// novel that is in the library, so an empty library means an unopened reader — while
  /// an empty journal with novels in it means they were cleared.
  ///
  /// Collapsing `null` into `false` would render *"Nothing read yet"* during the
  /// millisecond before the count lands, and then change the words under the reader.
  /// A state that says one thing and then says another is worse than one that says
  /// nothing for a moment.
  int? _libraryNovelCount;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_bootstrap);
  }

  Future<void> _bootstrap() async {
    await ref.read(historyRetentionProvider.notifier).load();
    final int novels = await ref.read(libraryEntryCountProvider.future);
    if (!mounted) {
      return;
    }
    setState(() => _libraryNovelCount = novels);
  }

  Future<void> _openSheet() async {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final HistoryRetention committed = ref.read(historyRetentionProvider);

    // ⚠️ **The count is taken when the sheet OPENS, and passed in.**
    //
    // `SettingsChoiceSheet` rewrites its warning sentence as the selection moves, so
    // the sentence has to be computable for any window — but the *number* is a
    // property of the reader's current rows, not of the sheet. Re-deriving it per row
    // would mean a database query per keystroke, and would make the count and the
    // warning disagree by one the moment a purge landed.
    await showSettingsChoiceSheet<HistoryRetention>(
      context,
      title: l10n.historySheetTitle,
      options: retentionOptions(l10n),
      selected: committed,
      labelOf: (HistoryRetention window) => windowLabelOf(l10n, window),
      warningFor: (HistoryRetention window) =>
          l10n.historySheetWarning(windowLabelOf(l10n, window)),
      onSelected: (HistoryRetention window) async {
        await ref.read(historyRetentionProvider.notifier).select(window);
        ref.invalidate(historyEntriesProvider);
        if (!mounted) {
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              l10n.historySnackWindowChanged(windowLabelOf(l10n, window)),
            ),
          ),
        );
      },
    );
  }

  Future<void> _confirmClear() async {
    final AppLocalizations l10n = AppLocalizations.of(context);
    // ⚠️ **`countAll()`, not the aged-out count.** `clearAll` removes every row,
    // including the ones inside the window; a count that honoured the window would
    // tell a reader with ten recent chapters that nothing is about to be deleted, and
    // then delete all ten. The count must be the set [HistoryRepository.clearAll]
    // touches, or the dialog is a lie with a number in it.
    final int count = await ref.read(historyRepositoryProvider).countAll();

    if (!mounted) {
      return;
    }
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: Text(l10n.historyClearDialogTitle),
        content: Text(l10n.historyClearDialogBody(count)),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.historyClearDialogConfirm),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) {
      return;
    }

    await ref.read(historyRepositoryProvider).clearAll();
    // ⚠️ **Invalidate the journal and NOTHING ELSE** — in particular not the reading
    // positions. Invalidating those would suggest they had been refreshed when they
    // have not moved, and a refresh that recomputes an offset from a new text size is
    // precisely how a position is lost. B46.
    ref.invalidate(historyEntriesProvider);
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l10n.historySnackCleared)));
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AsyncValue<List<HistoryDayGroup>> groups = ref.watch(
      historyEntriesProvider,
    );

    return AppScaffold(
      titleBar: AppBar(title: Text(l10n.historyTitle)),
      content: switch (groups) {
        AsyncData<List<HistoryDayGroup>>(
          value: final List<HistoryDayGroup> list,
        ) =>
          _filled(context, l10n, list),
        AsyncError<List<HistoryDayGroup>>(error: final Object _) => _loadError(
          context,
          l10n,
        ),
        _ => _loading(l10n),
      },
    );
  }

  // ── the eight skeleton rows, no cover ──────────────────────────────────
  Widget _loading(AppLocalizations l10n) {
    return ListView(
      padding: EdgeInsets.zero,
      children: const <Widget>[
        // ⚠️ **Two lines, not a cover and not a row.** The notice block is a title line
        // and a body line, and `history.md` § 4 says so: a skeleton shaped like a
        // different element is a promise the filled screen will not keep.
        Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            children: <Widget>[
              _SkeletonBar(widthFactor: 0.9),
              SizedBox(height: 8),
              _SkeletonBar(widthFactor: 0.6),
            ],
          ),
        ),
        // ⚠️ **Eight**, and every one of them **without a cover** — the `history`
        // variant of `NovelRow` declares no cover slot, and a skeleton that drew one
        // would promise an image the filled rows do not have.
        HistoryEntrySkeleton(),
        HistoryEntrySkeleton(),
        HistoryEntrySkeleton(),
        HistoryEntrySkeleton(),
        HistoryEntrySkeleton(),
        HistoryEntrySkeleton(),
        HistoryEntrySkeleton(),
        HistoryEntrySkeleton(),
      ],
    );
  }

  Widget _loadError(BuildContext context, AppLocalizations l10n) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              l10n.historyLoadErrorTitle,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            // ⚠️ **Three survivals, by name.** The fear is data loss and there is no
            // backup (ADR-010), so "something went wrong" is the least useful thing
            // this screen could say.
            Text(
              l10n.historyLoadErrorBody,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => ref.invalidate(historyEntriesProvider),
              child: Text(l10n.commonRetry),
            ),
          ],
        ),
      ),
    );
  }

  Widget _filled(
    BuildContext context,
    AppLocalizations l10n,
    List<HistoryDayGroup> groups,
  ) {
    final HistoryRetention window = ref.watch(historyRetentionProvider);
    final String windowName = windowLabelOf(l10n, window);

    if (groups.isEmpty) {
      return _empty(context, l10n, windowName);
    }

    final MaterialLocalizations platform = MaterialLocalizations.of(context);

    // ⚠️ **A flat list, built from the groups, not a nested list.** A `ListView` per
    // group would give every group its own scroll physics and its own lazy boundary,
    // and the headers would then be the reason the list is expensive to build. One
    // builder over a pre-flattened sequence keeps one lazy boundary for the screen.
    final List<Object> rows = <Object>[
      BoundNotice(
        windowLabel: windowName,
        onChangeWindow: _openSheet,
        onClear: _confirmClear,
      ),
      for (final HistoryDayGroup group in groups) ...<Object>[
        DayGroupHeader(label: dayGroupLabel(l10n, platform, group, _openedAt)),
        for (final entry in group.entries)
          HistoryEntryRow(
            entry: entry,
            chapterLabel: entry.chapterTitle.trim().isEmpty
                ? l10n.historyUntitledChapter
                : entry.chapterTitle,
            relativeLabel: relativeTimeLabel(l10n, entry.openedAt, _openedAt),
            onOpenReader: () => openReader(
              context,
              novelId: entry.novelId,
              chapterId: entry.chapterId,
            ),
            // `push`, not `go`: the novel page is a sibling **inside** the shell, and
            // `go` would replace the branch's page list, so back would land nowhere
            // useful.
            onOpenNovel: () {
              openNovelDetails(context, novelId: entry.novelId);
            },
          ),
      ],
      BoundTerminalLine(windowLabel: windowName),
    ];

    return ListView.builder(
      padding: EdgeInsets.zero,
      itemCount: rows.length,
      itemBuilder: (BuildContext context, int index) => rows[index] as Widget,
    );
  }

  Widget _empty(
    BuildContext context,
    AppLocalizations l10n,
    String windowName,
  ) {
    final int agedOut = ref.watch(historyAgedOutCountProvider).value ?? 0;
    final int? libraryNovels = _libraryNovelCount;

    // ⚠️ **Three states, and each is a claim the local data can actually support.**
    //
    //   **aged out** — entries exist and they are older than the window, so the
    //   window took them and nobody did it on purpose.
    //
    //   **never visited** — the *library* is empty. A chapter can only be opened from
    //   a novel that is in the library, so an empty library is a sound basis for "you
    //   have not read anything yet" — and it is the same fact `history.md` § 4 uses to
    //   choose which action to offer.
    //
    //   **cleared** — everything else: an empty journal with novels in it. The reader
    //   emptied it themselves.
    //
    // The three are checked in that order because `agedOut` is the only one that is a
    // statement about the journal itself, and the others are inferences from the
    // library.
    final bool wasAgedOut = agedOut > 0;
    final bool neverVisited = !wasAgedOut && (libraryNovels ?? 1) == 0;

    final String title = wasAgedOut
        ? l10n.historyAgedOutTitle
        : (neverVisited ? l10n.historyEmptyTitle : l10n.historyClearedTitle);
    final String body = wasAgedOut
        ? l10n.historyAgedOutBody
        : (neverVisited ? l10n.historyEmptyBody : l10n.historyClearedBody);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(body, textAlign: TextAlign.center),
            if (neverVisited) ...<Widget>[
              const SizedBox(height: 16),
              FilledButton(
                // `go`, and unlike `openReader` that is correct: `/browse` is a
                // sibling branch, so this is a branch switch, not a stack push.
                onPressed: () => openBrowse(context),
                child: Text(l10n.historyEmptyActionBrowse),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// One grey line of the notice block's skeleton.
class _SkeletonBar extends StatelessWidget {
  const _SkeletonBar({required this.widthFactor});

  final double widthFactor;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.surfaceContainerHighest;
    return FractionallySizedBox(
      widthFactor: widthFactor,
      alignment: AlignmentDirectional.centerStart,
      child: Container(height: 10, color: color),
    );
  }
}
