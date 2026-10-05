// Lumen Tale — the bound notice, and the two day-group pieces. Slice-local widgets.
//
// `history.md` § 4.1 puts `BoundNotice` and `DayGroupHeader` in
// `lib/features/history/widgets/` with **no** core dependency, and that is where they
// are: `BoundNotice` says B47 in this screen's words and `DayGroupHeader` renders a
// date this screen computed. Neither is a general component yet — promoting either to
// `core/ui/` would be a claim that a second screen wants it, and no second screen
// does.
//
// ## The notice is the only place on this screen that states the bound, and the
// terminal line states it again
//
// Twice on purpose: the top, for a reader who has not reached the bottom, and the
// bottom, for a reader who scrolled the whole list without being told. A bound that
// only appears at the top is a bound most readers never read.

import 'package:flutter/material.dart';

import 'package:lumen_tale/app/theme/lumen_colors.dart';
import 'package:lumen_tale/app/theme/lumen_radius.dart';
import 'package:lumen_tale/app/theme/lumen_spacing.dart';
import 'package:lumen_tale/l10n/generated/app_localizations.dart';

/// B47 and B46, in a block above the list.
///
/// ⚠️ **Two sentences, and the second one is the point.** "History is bounded by
/// time" is a fact the reader cannot check; "clearing it never moves a remembered
/// reading position" is the fact they are actually afraid of. A notice that carried
/// only the first would be true and useless.
class BoundNotice extends StatelessWidget {
  const BoundNotice({
    super.key,
    required this.windowLabel,
    required this.onChangeWindow,
    required this.onClear,
  });

  /// The current window, already localized. Never the enum's `name` — `threeMonths`
  /// in a French sentence is a string the app learned from its own code.
  final String windowLabel;

  final VoidCallback onChangeWindow;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final LumenColors colors = LumenColors.of(context);
    final LumenSpacing spacing = LumenSpacing.of(context);

    return Container(
      decoration: BoxDecoration(
        color: colors.surfaceRaised,
        borderRadius: BorderRadius.circular(LumenRadius.of(context).lg),
      ),
      padding: EdgeInsets.all(spacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            l10n.historyNoticeTitle,
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(color: colors.textPrimary),
          ),
          SizedBox(height: spacing.xs),
          Text(
            l10n.historyNoticeBody,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: colors.textSecondary),
          ),
          SizedBox(height: spacing.md),
          // ⚠️ The window's name is **in the notice**, not only in the sheet. A reader
          // who opens the notice must be able to learn what bound they are under
          // without opening a picker to find out.
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  '${l10n.historyRetentionLabel}: $windowLabel',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: colors.textPrimary),
                ),
              ),
              TextButton(
                onPressed: onChangeWindow,
                child: Text(l10n.historyRetentionChange),
              ),
            ],
          ),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton(
              onPressed: onClear,
              style: TextButton.styleFrom(foregroundColor: colors.error),
              child: Text(l10n.historyClearAction),
            ),
          ),
        ],
      ),
    );
  }
}

/// A day boundary. `--text-overline`, and **a semantic header**.
class DayGroupHeader extends StatelessWidget {
  const DayGroupHeader({super.key, required this.label});

  /// Already localized, from [dayGroupLabel].
  final String label;

  @override
  Widget build(BuildContext context) {
    final LumenColors colors = LumenColors.of(context);
    final LumenSpacing spacing = LumenSpacing.of(context);

    // ⚠️ `semanticsLabel` AND `Semantics(header: true)`. The default text style is
    // small and grey, which a screen reader will not announce as a boundary — so
    // without the header flag a blind reader hears fourteen rows with no way to know
    // they crossed into another day. `design-system.md` § 2 and `09-widgets-ui.md`
    // rule 3: a boundary in the pixels is a boundary in the accessibility tree.
    return Semantics(
      header: true,
      label: label,
      child: ExcludeSemantics(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            spacing.lg,
            spacing.lg,
            spacing.lg,
            spacing.sm,
          ),
          child: Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(color: colors.textSecondary),
          ),
        ),
      ),
    );
  }
}

/// The line under the last row: B47's bound, where a reader who scrolled everything
/// finally learns about it.
///
/// ⚠️ **Never absent.** There is no unbounded case, so this line has no empty state: a
/// screen that claimed a bound it was not applying is the exact failure B47 exists to
/// prevent, and "no line here because nothing is bounded" is the same lie in a
/// quieter voice.
class BoundTerminalLine extends StatelessWidget {
  const BoundTerminalLine({super.key, required this.windowLabel});

  final String windowLabel;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final LumenSpacing spacing = LumenSpacing.of(context);
    final LumenColors colors = LumenColors.of(context);

    return Padding(
      padding: EdgeInsets.fromLTRB(
        spacing.lg,
        spacing.lg,
        spacing.lg,
        spacing.xl3,
      ),
      child: Text(
        l10n.historyTerminalLine(windowLabel),
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(color: colors.textSecondary),
      ),
    );
  }
}
