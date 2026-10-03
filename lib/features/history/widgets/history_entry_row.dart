// Lumen Tale — one line of the journal.
//
// `history.md` § 4.1: `NovelRow` variant `history`, 56dp, **no cover**.
//
// ## There is no cover slot, and the reason is not that there was no time
//
// The variant declares no cover, so this row declares no `cover` field. A loading
// state that showed a cover placeholder would promise an image the filled rows do not
// have, and a cover in a log of what was *opened* is decoration that changes the
// height and hides the chapter line — which is the part B10 makes verbatim.
//
// ## Two tap targets, and the second one is deliberate
//
// The whole row opens the **reader at that chapter's stored position**, and the novel
// title region opens the novel's other chapters. One row, two destinations, because a
// reader who wants chapter 40 does not want to go via chapter 3, and a reader who
// wants to *continue* does not want the novel page first.
//
// ## No long-press menu, and that is a decision
//
// The only menu a log row could offer is *delete*, and delete here would mean "remove
// this line from a list" — which no reader wants, and which B46's subject matter makes
// dangerous to gesture toward. Clearing is a single explicit action on the notice.

import 'package:flutter/material.dart';

import 'package:lumen_tale/app/theme/lumen_colors.dart';
import 'package:lumen_tale/app/theme/lumen_spacing.dart';
import 'package:lumen_tale/domain/history/history_entry.dart';
import 'package:lumen_tale/l10n/generated/app_localizations.dart';

/// One journal line: novel, chapter, and how long ago.
class HistoryEntryRow extends StatelessWidget {
  const HistoryEntryRow({
    super.key,
    required this.entry,
    required this.chapterLabel,
    required this.relativeLabel,
    required this.onOpenReader,
    required this.onOpenNovel,
  });

  final HistoryEntry entry;

  /// The chapter title, already defaulted to *Untitled* by the caller.
  final String chapterLabel;

  /// Already localized, and **possibly the empty string** past midnight — the day
  /// header carries the date there. A row renders whatever it is given and never
  /// invents a fourth time bucket.
  final String relativeLabel;

  final VoidCallback onOpenReader;
  final VoidCallback onOpenNovel;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final LumenColors colors = LumenColors.of(context);
    final LumenSpacing spacing = LumenSpacing.of(context);

    return Semantics(
      container: true,
      button: true,
      // ⚠️ **One label for the whole row, not two.** Two focusable regions with the
      // novel's title as the first of them would have a screen reader announce the
      // novel, then the chapter, then the time, then the second target's name — four
      // utterances for one line. The label below is the line's whole content.
      label: <String>[
        if (entry.novelTitle.trim().isNotEmpty) entry.novelTitle,
        if (chapterLabel.isNotEmpty) chapterLabel,
        if (relativeLabel.isNotEmpty) relativeLabel,
      ].join(', '),
      child: InkWell(
        onTap: onOpenReader,
        child: Container(
          constraints: const BoxConstraints(minHeight: 56),
          padding: EdgeInsets.symmetric(
            horizontal: spacing.lg,
            vertical: spacing.md,
          ),
          color: colors.surface,
          child: Row(
            children: <Widget>[
              Expanded(
                child: ExcludeSemantics(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      GestureDetector(
                        // The second destination. `behavior: translucent` so the row's
                        // own `InkWell` still shows a splash underneath — otherwise
                        // the title would be a hole in the row's tap target and a
                        // reader aiming for the reader would get nothing.
                        behavior: HitTestBehavior.translucent,
                        onTap: onOpenNovel,
                        child: Text(
                          entry.novelTitle.trim().isEmpty
                              ? l10n.historyUntitledNovel
                              : entry.novelTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(color: colors.textPrimary),
                        ),
                      ),
                      SizedBox(height: spacing.xs2),
                      Text(
                        chapterLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        // ⚠️ `--color-text-secondary`, and that is the point: this is
                        // B10's verbatim site text and it must not be set in a body
                        // token, or an irregular title like *Omake* reads as a
                        // heading.
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (relativeLabel.isNotEmpty) ...<Widget>[
                SizedBox(width: spacing.sm),
                ExcludeSemantics(
                  child: Text(
                    relativeLabel,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// The `history` variant's skeleton: a two-thirds title line, a one-half line, and a
/// short trailing block. **No cover**, for the reason in this file's header.
class HistoryEntrySkeleton extends StatelessWidget {
  const HistoryEntrySkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final LumenColors colors = LumenColors.of(context);
    final LumenSpacing spacing = LumenSpacing.of(context);

    Widget line({double? width, double? widthFactor}) {
      // ⚠️ **`width` for the trailing block, `widthFactor` for the lines.**
      //
      // `FractionallySizedBox` needs a bounded parent width, and the trailing block
      // sits directly in a `Row` — where a fraction resolves against infinity and the
      // layout throws. The trailing block is a fixed short bar anyway ("a trailing
      // short block", `history.md` § 4), so a fixed width is the honest shape.
      final Widget box = Container(
        height: 10,
        decoration: BoxDecoration(
          color: colors.surfaceSunken,
          borderRadius: BorderRadius.circular(2),
        ),
      );
      if (width != null) {
        return SizedBox(width: width, child: box);
      }
      return FractionallySizedBox(
        widthFactor: widthFactor,
        alignment: AlignmentDirectional.centerStart,
        child: box,
      );
    }

    return ExcludeSemantics(
      child: Container(
        constraints: const BoxConstraints(minHeight: 56),
        padding: EdgeInsets.symmetric(
          horizontal: spacing.lg,
          vertical: spacing.md,
        ),
        color: colors.surface,
        child: Row(
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  // ⚠️ A two-thirds title line over a one-half line — the shape of the
                  // row it stands in for. A skeleton shaped like a different element
                  // is a promise the filled screen will not keep.
                  line(widthFactor: 2 / 3),
                  SizedBox(height: spacing.xs),
                  line(widthFactor: 1 / 2),
                ],
              ),
            ),
            SizedBox(width: spacing.sm),
            line(width: 40),
          ],
        ),
      ),
    );
  }
}
