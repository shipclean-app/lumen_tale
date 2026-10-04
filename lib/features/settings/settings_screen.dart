// Lumen Tale — `/more/settings`. Seven rows, three group labels, and E11.
//
// `settings.md`. A sub-page of More, so it is a **push** inside the shell's branch —
// `openNovelDetails` in `app_router.dart` says why `push` and not `go`.
//
// ## Seven rows, and § 4's list of eight is short by one on purpose
//
// `settings.md` § 4 (Filled) names eight. `Check now` is **not built**, and its absence
// is a recorded deviation rather than an oversight:
//
//   `Check now` is **B36's update check**, run because the reader asked (ADR-021). No
//   `8-*` slice has built an update subsystem, no source reports a "last checked"
//   instant, and there is nothing to count. A button that opens no check is a fake
//   control — the defect § 11 spends a table refusing elsewhere — so the row goes with
//   its copy (`row.checkNow.*`, `error.noConnection`, `warning.notifications.*` are
//   not in the ARB).
//
//   **And the `LIBRARY` group goes with it.** `settings.md` § 3 is explicit: *"an empty
//   section label is worse than no section label"*. `LIBRARY` held `Check now` and three
//   struck rows; with the button gone the label labels nothing.
//
// ## The `retention.*` strings are NOT re-declared
//
// `settings.md` § 4.1 lists `retention.1w` … `retention.2y` — a **second spelling of the
// same five windows** `6-5` already owns as `historyWindowOneWeek` …
// `historyWindowTwoYears`. `design-system.md` § 2.12 exists to prevent exactly that:
//
//     *"Two lists of the same values in two places is two truths about how long history
//     lasts, and nothing in a dependency graph or a design token would notice."*
//
// So this screen **imports the names** rather than restating them. Finding F-013.
//
// ## Load error is DECLINED, not unspecified
//
// § 4 strikes the screen-level Load error with a reason: the three stored settings are
// resolved once at the bootstrap, so a failure to read them never produced this route.
// What *can* fail is a local `COUNT(*)` over the history table, and that is scoped to
// the one row that owns it: `Count unavailable`, never `0` (B48).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:lumen_tale/app/theme/app_version.dart';
import 'package:lumen_tale/app/theme/lumen_spacing.dart';
import 'package:lumen_tale/app/theme/reader_scale.dart';
import 'package:lumen_tale/app/theme/theme_override.dart';
import 'package:lumen_tale/app/theme/theme_providers.dart';
import 'package:lumen_tale/core/ui/app_scaffold.dart';
import 'package:lumen_tale/domain/history/history_retention.dart';
// ⚠️ **Settings legitimately needs HISTORY's retention providers** — the "clear
// history" control is a settings row, and the policy it edits is history's domain.
// That dependency is real; the DATABASE provider beside it is not, and now comes
// from `core/`. See F-018 — moving `historyRepositoryProvider` and
// `historyRetentionProvider` to `data/history/` retires this last import.
import 'package:lumen_tale/features/history/history_providers.dart';
import 'package:lumen_tale/features/settings/appearance_label.dart';
import 'package:lumen_tale/features/settings/language_label.dart';
import 'package:lumen_tale/features/settings/settings_providers.dart';
import 'package:lumen_tale/features/settings/settings_rows.dart';
import 'package:lumen_tale/l10n/generated/app_localizations.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);

    // ⚠️ **Recorded on every build, before the summary is read.** A provider cannot read
    // a `BuildContext`, so the locale the "oldest … ago" sentence is written in has to
    // arrive from here. Doing it in `build` rather than in `initState` is deliberate:
    // the sentence is rebuilt on every locale change (E12), and a one-shot capture
    // would leave a French reader reading an English sentence after a language change.
    setHistorySummaryLocale(Localizations.localeOf(context));

    return AppScaffold(
      titleBar: AppBar(title: Text(l10n.settingsTitle)),
      content: SettingsBody(
        version: readBuildVersion(),
        // ⚠️ **The two display values are read HERE, by the `ConsumerWidget`, and handed
        // down as plain fields.** A `StatelessWidget` that reached for a provider itself
        // would need a wrapper widget, and this page has no state of its own to justify
        // one.
        themeOverride: ref.watch(themeOverrideProvider),
        textScale: ref.watch(readerTextScaleProvider),
        ref: ref,
        onNavigate: ref.read(settingsNavigationProvider),
      ),
    );
  }
}

/// The page, and every block in it.
class SettingsBody extends StatelessWidget {
  const SettingsBody({
    super.key,
    required this.version,
    required this.themeOverride,
    required this.textScale,
    required this.ref,
    required this.onNavigate,
  });

  final BuildVersion version;

  final ThemeOverride themeOverride;
  final ReaderTextScale textScale;

  /// ⚠️ **A `WidgetRef` in a `StatelessWidget`, and only for two calls.** The retention
  /// sheet and the clear dialog both read a provider and invalidate one, and a
  /// `StatelessWidget` cannot watch. Rather than promote this body to a
  /// `ConsumerStatefulWidget` — which would give it state it does not have, whose
  /// `setState` no row here would ever call — those two flows take the ref.
  final WidgetRef ref;

  /// The destinations, as functions. § 9: a feature never writes a route string.
  final SettingsNavigation onNavigate;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final LumenSpacing spacing = LumenSpacing.of(context);
    final HistoryRetention window = ref.watch(historyRetentionProvider);
    final AsyncValue<HistorySummary> summary = ref.watch(
      historySummaryProvider,
    );

    return ListView(
      padding: EdgeInsets.fromLTRB(
        spacing.lg,
        spacing.xl3,
        spacing.lg,
        spacing.xl3,
      ),
      children: <Widget>[
        // ── READING ───────────────────────────────────────────────────────
        GroupLabel(label: l10n.settingsGroupReading),
        SettingsRow(
          label: l10n.settingsRowAppearanceLabel,
          value: appearanceLabel(l10n, themeOverride, textScale),
          onTap: () => onNavigate.openReaderSettings(context),
        ),
        SizedBox(height: spacing.xl),

        // ⚠️ **No `LIBRARY` group.** See the file header: an empty section label is
        // worse than no section label, and the only live row it held was `Check now`.

        // ── HISTORY ───────────────────────────────────────────────────────
        GroupLabel(label: l10n.settingsGroupHistory),
        SettingsRow(
          label: l10n.settingsRowHistoryLabel,
          value: historyValueLabel(l10n, summary),
          onTap: () => onNavigate.openHistory(context),
        ),
        SettingsRow(
          label: l10n.settingsRowRetentionLabel,
          value: retentionLabelOf(l10n, window),
          onTap: () => onNavigate.openRetentionSheet(context, ref),
        ),
        DangerRow(
          label: l10n.settingsRowClearHistoryLabel,
          // ⚠️ **Disabled when the count is zero AND when the count could not be
          // obtained** — § 4 (Empty — no data) applies the same rendering to both, and
          // says why: a dialog asking the reader to confirm destroying zero entries is
          // theatre, and a dialog that cannot state how much is about to be destroyed
          // cannot state the one thing it exists to state.
          enabled: (summary.value?.entryCount ?? 0) > 0 && !summary.hasError,
          countUnavailable: summary.hasError || summary.value == null,
          onTap: () => onNavigate.confirmClearHistory(context, ref),
        ),
        SizedBox(height: spacing.xl),

        // ── APP ───────────────────────────────────────────────────────────
        GroupLabel(label: l10n.settingsGroupApp),
        // ⚠️ **`readOnly: true`, and that is typographic.** § 4 (Read-only): read-only
        // content carries no chevron, no ripple, no toggle and no pressed state — a row
        // the reader cannot act on is visually inert **by absence, not by greying**.
        SettingsRow(
          label: l10n.settingsRowLanguageLabel,
          value: languageLabel(l10n, Localizations.localeOf(context)),
          hint: l10n.settingsRowLanguageHint,
          readOnly: true,
        ),
        SettingsRow(
          label: l10n.settingsRowOnboardingLabel,
          value: l10n.settingsRowOnboardingValue,
          onTap: () => onNavigate.openOnboarding(context),
        ),
        SettingsRow(
          label: l10n.settingsRowAboutLabel,
          // ⚠️ **The same fallback `3-5` uses, for the same reason.** `Version —` looks
          // like a version (C9), so an unreadable build renders a dash and the About
          // page still carries the sentence that says what could not be read.
          value: version.isReadable
              ? l10n.settingsRowAboutValue(
                  version.buildName,
                  version.buildNumber,
                )
              : l10n.aboutDataCountUnavailable,
          onTap: () => onNavigate.openAbout(context),
        ),
        SizedBox(height: spacing.xl),

        DisclosureBlock(
          body: l10n.settingsDisclosureE11,
          footer: l10n.settingsDisclosureE11Footer,
          linkLabel: l10n.settingsDisclosureAboutLink,
          onLink: () => onNavigate.openAbout(context),
        ),
      ],
    );
  }
}

/// `{count} entries · oldest {relative}` — and **never a zero in that sentence**.
///
/// Three states, three renderings: loading and error are two different words, and zero
/// has its own key because *"{count} entries · oldest {relative}"* with a zero has no
/// oldest to name.
String historyValueLabel(
  AppLocalizations l10n,
  AsyncValue<HistorySummary> summary,
) {
  if (summary.isLoading) {
    return l10n.aboutDataCountUnavailable;
  }
  // ⚠️ **`hasError` before `value`.** A `FutureProvider` that has thrown has `value ==
  // null` **and** `hasError`, and reading `value` first would render the dash for a
  // query that gave up — the one answer B48 forbids, because a dash says "we could not
  // look" and this row *did* look and failed.
  if (summary.hasError) {
    return l10n.settingsErrorCountUnavailable;
  }
  final HistorySummary? value = summary.value;
  if (value == null) {
    return l10n.aboutDataCountUnavailable;
  }
  if (value.entryCount == 0) {
    return l10n.settingsRowHistoryValueEmpty;
  }
  return l10n.settingsRowHistoryValue(
    value.entryCount.toString(),
    value.oldestLabel,
  );
}

/// The name `6-5` gives a retention window, **not `settings.md`'s twin**.
String retentionLabelOf(AppLocalizations l10n, HistoryRetention window) {
  return switch (window) {
    HistoryRetention.oneWeek => l10n.historyWindowOneWeek,
    HistoryRetention.oneMonth => l10n.historyWindowOneMonth,
    HistoryRetention.threeMonths => l10n.historyWindowThreeMonths,
    HistoryRetention.oneYear => l10n.historyWindowOneYear,
    HistoryRetention.twoYears => l10n.historyWindowTwoYears,
  };
}
