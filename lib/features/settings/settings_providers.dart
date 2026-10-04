// Lumen Tale — the two things `settings.md` needs that the screen itself cannot hold.
//
// ## Two providers, and one of them is navigation
//
// `HistorySummary` — **two local queries over one table**: a `COUNT(*)` and a
// `MIN(opened_at)`. § 4 (Load error, declined) scopes a failed query to the one row that
// owns it, so both live in a single `FutureProvider` rather than being spread across the
// two rows that read them: one failure, one `error`, one value line that says
// `Count unavailable`.
//
// `SettingsNavigation` — **the destinations, as functions**. § 9's convention is that a
// feature never writes a route string, so the rows cannot take paths: a row that took
// `/history` would make `settings.md` the second place that knows the app's routes.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:lumen_tale/app/router/app_router.dart';
import 'package:lumen_tale/app/router/app_routes.dart';
import 'package:lumen_tale/core/ui/settings_choice_sheet.dart';
import 'package:lumen_tale/domain/history/history_repository.dart';
import 'package:lumen_tale/domain/history/history_retention.dart';
import 'package:lumen_tale/features/history/history_providers.dart';
import 'package:lumen_tale/features/history/history_time_labels.dart';
import 'package:lumen_tale/features/settings/settings_screen.dart';
import 'package:lumen_tale/l10n/generated/app_localizations.dart';

/// What the `Reading history` row's value line is made of.
final class HistorySummary {
  const HistorySummary({required this.entryCount, required this.oldestLabel});

  /// `COUNT(*)` over `history_entries` — **the whole table, not the window.**
  ///
  /// ⚠️ The row says *"{count} entries"* and the danger row below it deletes the whole
  /// journal, so the count has to be the set `clearAll` touches. A count inside the
  /// retention window would report 0 for a reader with a full history, and the dialog
  /// that asks consent to deleting 1,200 entries would say *"nothing will be removed"*.
  final int entryCount;

  /// Already localized, because *"{count} entries · oldest {relative}"* needs a phrase
  /// and the phrase is this screen's, not the row's.
  ///
  /// Empty when [entryCount] is zero — there is no oldest entry to name, and the row
  /// uses `settingsRowHistoryValueEmpty` in that case rather than an empty clause.
  final String oldestLabel;
}

/// The locale the summary's sentence is written in.
///
/// ⚠️ **Module-level mutable state, and it is a debt with a comment rather than a
/// secret.** A provider cannot read a `BuildContext`, and `AppLocalizations` cannot be
/// loaded without a locale. The screen sets this on every build; `SettingsBody`'s
/// `read` of the provider then has an l10n for the locale the screen is actually in,
/// which is what E12 requires after a language change.
///
/// The honest alternative is passing `AppLocalizations` through the read, which would
/// mean a `Provider.family` keyed on the locale and a provider that rebuilds its whole
/// summary when only a *phrase* changed. This is recorded rather than presented as
/// clean.
Locale _summaryLocale = const Locale('fr');

/// Records the locale before a read of [historySummaryProvider].
///
/// The initial value is **French**, which is B28's fallback chain — the same default
/// `main.dart` uses, so the two agree by construction rather than by coincidence.
void setHistorySummaryLocale(Locale locale) => _summaryLocale = locale;

final historySummaryProvider = FutureProvider<HistorySummary>((Ref ref) async {
  final HistoryRepository history = ref.watch(historyRepositoryProvider);
  final AppLocalizations l10n = await AppLocalizations.delegate.load(
    _summaryLocale,
  );
  final int count = await history.countAll();
  final DateTime? oldest = await history.oldestEntryAt();
  return HistorySummary(
    entryCount: count,
    oldestLabel: oldest == null
        ? ''
        : relativeTimeLabel(l10n, oldest, DateTime.now()),
  );
});

/// Every destination this screen can push, as functions.
final settingsNavigationProvider = Provider<SettingsNavigation>(
  (Ref ref) => SettingsNavigation(
    openReaderSettings: (BuildContext context) =>
        GoRouter.of(context).push(AppRoutes.settingsReader),
    openHistory: openHistoryTab,
    openOnboarding: openOnboarding,
    openAbout: (BuildContext context) =>
        GoRouter.of(context).push(AppRoutes.settingsAbout),
    openRetentionSheet: _openRetentionSheet,
    confirmClearHistory: _confirmClearHistory,
  ),
);

/// Opens `/history` — a **branch switch**.
///
/// ⚠️ `go`, and unlike `openReader` that is correct: `/history` is a sibling branch of the
/// `StatefulShellRoute`, so this is a branch switch and there is nothing to push on top
/// of a branch that has not been visited.
void openHistoryTab(BuildContext context) {
  GoRouter.of(context).go(AppRoutes.history);
}

/// The six destinations, named.
final class SettingsNavigation {
  const SettingsNavigation({
    required this.openReaderSettings,
    required this.openHistory,
    required this.openOnboarding,
    required this.openAbout,
    required this.openRetentionSheet,
    required this.confirmClearHistory,
  });

  final void Function(BuildContext context) openReaderSettings;
  final void Function(BuildContext context) openHistory;
  final void Function(BuildContext context) openOnboarding;
  final void Function(BuildContext context) openAbout;

  /// The two flows that need the container, and so take a [WidgetRef] as well.
  ///
  /// ⚠️ **Not a global container.** A `Provider` cannot reach one, and
  /// `ProviderScope.containerOf(context)` inside a provider body would read the
  /// container of whichever widget happened to be above — a lookup that changes when the
  /// page is embedded somewhere else.
  final Future<void> Function(BuildContext context, WidgetRef ref)
  openRetentionSheet;
  final Future<void> Function(BuildContext context, WidgetRef ref)
  confirmClearHistory;
}

/// Opens `6-5`'s `SettingsChoiceSheet` for the five retention windows.
///
/// ⚠️ **The sheet does not close on a successful write**, and that is the component's
/// contract (`6-5`'s *Success*): its own rows re-render in place and the SnackBar names
/// the new window. A screen that popped the sheet itself would be a second place
/// deciding when the reader is done.
Future<void> _openRetentionSheet(BuildContext context, WidgetRef ref) async {
  final AppLocalizations l10n = AppLocalizations.of(context);
  await showSettingsChoiceSheet<HistoryRetention>(
    context,
    title: l10n.historySheetTitle,
    // ⚠️ **The rows come from `retentionOptions`, which reads the SAME enum the History
    // screen's notice does.** § 2.12's point in one line: two lists of the same values
    // in two places is two truths about how long history lasts.
    options: retentionOptions(l10n),
    selected: ref.read(historyRetentionProvider),
    labelOf: (HistoryRetention window) => retentionLabelOf(l10n, window),
    warningFor: (HistoryRetention window) =>
        l10n.historySheetWarning(retentionLabelOf(l10n, window)),
    onSelected: (HistoryRetention window) async {
      await ref.read(historyRetentionProvider.notifier).select(window);
      ref.invalidate(historySummaryProvider);
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            l10n.historySnackWindowChanged(retentionLabelOf(l10n, window)),
          ),
        ),
      );
    },
  );
}

/// Opens the destructive confirmation, with the **count in the title**.
Future<void> _confirmClearHistory(BuildContext context, WidgetRef ref) async {
  final AppLocalizations l10n = AppLocalizations.of(context);
  final int count = await ref.read(historyRepositoryProvider).countAll();
  if (!context.mounted) {
    return;
  }
  final bool? confirmed = await showDialog<bool>(
    context: context,
    builder: (BuildContext dialogContext) => AlertDialog(
      // ⚠️ **The count is in the TITLE**, because a title is what a reader reads before
      // anything else, and stating how much is about to be destroyed is this dialog's
      // one job. § 4 (Loading) exists only for the `COUNT` this sentence waits on.
      title: Text(l10n.settingsDialogClearHistoryTitle(count.toString())),
      content: Text(l10n.settingsDialogClearHistoryBody),
      actions: <Widget>[
        // ⚠️ **Cancel first, and it is the default action.** `6-5` § 11.1's rule: on a
        // hardware keyboard `Enter` takes the first, and a destructive first action
        // empties a reader's log on a stray keypress.
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text(l10n.settingsButtonCancel),
        ),
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(l10n.settingsDialogClearHistoryConfirm),
        ),
      ],
    ),
  );
  if (confirmed != true) {
    return;
  }
  await ref.read(historyRepositoryProvider).clearAll();
  ref.invalidate(historySummaryProvider);
  if (!context.mounted) {
    return;
  }
  // ⚠️ **The second clause is the entire message.** B46 makes position the thing the
  // reader must believe survived; a generic "History cleared" leaves her fearing she lost
  // her place, which is the app's core promise (B16).
  ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(l10n.settingsSnackHistoryCleared)));
}

/// The five sheet rows, **from the enum** — `design-system.md` § 2.12.
List<SettingsChoiceOption<HistoryRetention>> retentionOptions(
  AppLocalizations l10n,
) {
  return <SettingsChoiceOption<HistoryRetention>>[
    for (final HistoryRetention window in HistoryRetention.values)
      SettingsChoiceOption<HistoryRetention>(
        value: window,
        label: retentionLabelOf(l10n, window),
      ),
  ];
}
