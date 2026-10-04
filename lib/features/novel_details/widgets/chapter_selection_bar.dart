// Lumen Tale — B18's sixth choice: `n selected · Download · Cancel`.
//
// `5-1` § 4.2 / § 4.3, from `novel-details.md` § 11.3.
//
// ## ⚠️ **TWO ABSENCES, AND BOTH ARE THE RULE**
//
//  1. **NO "SELECT ALL".** B18 reserves *"every chapter including ones already read"* for
//     a **deliberate** selection, and a select-all button is the exact opposite of
//     deliberate. § 11.3 refuses it by name.
//  2. **NO "ADD TO LIBRARY".** A selection is a download instrument; membership is one
//     act on one screen (B11). § 11.3 refuses it by name.
//
// So this bar has **three** things in it and no fourth, and `3-2`'s `PinnedActionRow`
// has the same reason for having three.
//
// ## ⚠️ **NO REORDERING, AND THAT IS WHY THE ORDER IS AN INSERTION ORDER**
//
// § 11.3 declares no reordering gesture here, so the order the reader tapped is the
// order the queue runs — which is why `HandPickedSelection` holds a `List<String>` and
// why `resolveBulkChoice`'s `HandPicked` branch preserves the caller's order rather than
// sorting by `ordinal`.
//
// ## ⚠️ **THE SELECTED TILE USES `NovelRow`'s `selected` GRAMMAR**
//
// § 11.3: *"`ChapterListTile` declares no `selected` state … this screen renders selection
// with the app's single selection grammar, `NovelRow`'s declared `selected`
// presentation: a 2dp `--color-border-strong` leading edge plus a `--color-accent` 10%
// fill."* [SelectedChapterTile] below implements exactly that and **adds no state to
// `ChapterListTile`** — a local variant would give the app two grammaries for one meaning,
// which `design-check component-parity` is right to flag.

import 'package:flutter/material.dart';
import 'package:lumen_tale/app/theme/lumen_colors.dart';
import 'package:lumen_tale/app/theme/lumen_radius.dart';
import 'package:lumen_tale/app/theme/lumen_spacing.dart';
import 'package:lumen_tale/l10n/generated/app_localizations.dart';

/// C11 — a control reachable one-handed, in transit. 48dp, never conditional.
const double kSelectionBarControlHeight = 48;

/// `n selected · Download · Cancel`.
class ChapterSelectionBar extends StatelessWidget {
  const ChapterSelectionBar({
    required this.selectedCount,
    required this.onDownload,
    required this.onClear,
    super.key,
    this.downloadLabel,
    this.selectedLabel,
  });

  /// How many chapters are selected. **A count, not a boolean** — the reader needs to
  /// know what the tap is about to act on.
  final int selectedCount;

  /// ⚠️ **EMITS THE SELECTION IN ORDER.** The callback takes no argument: the bar holds
  /// no ids, and the screen's `HandPickedSelection` is the single ordered copy. A bar
  /// that passed a `Set` would have thrown the order away at the last moment.
  final VoidCallback onDownload;

  /// Clears the selection. **Not** *Cancel the download* — B19's cancellation is `5-2`'s,
  /// and a selection that quietly cancelled a fifty-chapter queue would be a
  /// destructive action behind a word readers use for "dismiss".
  final VoidCallback onClear;

  /// ⚠️ **BOTH OPTIONAL AND BOTH DEFAULTS TO THE APP'S OWN WORD.** The caller may
  /// localize a screen-specific phrasing; what it may not do is invent a **third
  /// control**, and these two parameters are words, not actions.
  final String? downloadLabel;
  final String? selectedLabel;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations copy = AppLocalizations.of(context);
    final LumenSpacing spacing = LumenSpacing.of(context);
    final LumenColors colors = LumenColors.of(context);

    return DecoratedBox(
      // ⚠️ **`--color-border`, NOT A SHADOW.** `downloads.md` § 2.1: flat rows and a border
      // rule; the app keeps exactly two shadows (`--shadow-sheet`, `--shadow-dialog`) and
      // a bar is neither.
      decoration: BoxDecoration(
        color: colors.surfaceRaised,
        border: Border(top: BorderSide(color: colors.border)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: spacing.lg,
            vertical: spacing.sm,
          ),
          child: Row(
            children: <Widget>[
              // ⚠️ **THE COUNT IS IN THE BAR AND NOT ONLY IN THE SEMANTICS.** "3 selected"
              // is what makes the tap a decision rather than a leap; a label of "Download"
              // alone gives a screen-reader user no way to know what is about to happen.
              Expanded(
                child: Text(
                  selectedLabel ?? '$selectedCount',
                  key: const Key('chapterSelectionBar.count'),
                  style: Theme.of(
                    context,
                  ).textTheme.labelLarge?.copyWith(color: colors.textPrimary),
                ),
              ),
              SizedBox(width: spacing.sm),
              SizedBox(
                height: kSelectionBarControlHeight,
                child: FilledButton(
                  // ⚠️ **DISABLED AT ZERO, NEVER ABSENT.** Same rule as
                  // `pinned_action_row.dart`'s *Mark all as read*: a control that
                  // disappears moves its neighbours under a thumb that was already moving.
                  onPressed: selectedCount == 0 ? null : onDownload,
                  child: Text(downloadLabel ?? copy.chapterListDownloadAction),
                ),
              ),
              SizedBox(width: spacing.sm),
              SizedBox(
                height: kSelectionBarControlHeight,
                child: TextButton(
                  onPressed: onClear,
                  child: Text(copy.commonCancel),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A chapter tile in its SELECTED state, using `NovelRow`'s declared grammar.
///
/// ⚠️ **THIS IS NOT A `ChapterListTile` STATE, AND IT IS NOT A NEW ONE.** § 11.3 borrows
/// the grammar deliberately: a 2dp `--color-border-strong` leading edge plus a
/// `--color-accent` 10% fill. Adding `selected` to `ChapterListTile`'s contract is a
/// decision for the design system's owner (recorded as a known gap in § 11.3), not
/// something a screen may do for itself.
class SelectedChapterTile extends StatelessWidget {
  const SelectedChapterTile({required this.child, super.key});

  /// The tile exactly as it would render unselected. The wrapper supplies selection and
  /// nothing else, so a tile's own states (`read`, `failed`, …) keep compositing with
  /// selection rather than being replaced by it.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final LumenColors colors = LumenColors.of(context);
    final LumenSpacing spacing = LumenSpacing.of(context);
    final LumenRadius radius = LumenRadius.of(context);

    return DecoratedBox(
      // ⚠️ **BORDER-ONLY LEFT EDGE, 2dp.** `radius.lg` is the sheet's corner radius and is
      // not used here: `NovelRow`'s selected grammar is an edge, not a rounded card, and
      // rounding it would make a selected chapter look like a different component.
      decoration: BoxDecoration(
        color: colors.accent.withValues(alpha: 0.1),
        border: Border(
          left: BorderSide(color: colors.borderStrong, width: 2),
        ),
        borderRadius: BorderRadius.circular(radius.sm),
      ),
      child: Padding(
        padding: EdgeInsets.only(left: spacing.md),
        child: child,
      ),
    );
  }
}