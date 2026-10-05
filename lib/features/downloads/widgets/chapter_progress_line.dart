// Lumen Tale — the 2dp determinate bar under a downloading chapter's title.
//
// ## ⚠️ A DETERMINATE BAR IS A PROMISE, AND THE PROMISE IS THAT IT MOVES
//
// An indeterminate spinner on a download says *something is happening*. A determinate bar
// says *this much has happened*, and a reader who watches it and then sees it at 90% for a
// minute has been told a specific falsehood. So `progress` is `null`-able and **`null`
// renders the bar hidden, not animated** — an unknown amount is not a small amount.
//
// ## ⚠️ NO PERCENTAGE IS DRAWN
//
// § 4.3.1: *"Pourcentage dans l'étiquette de sémantique, pas dessiné."* Text drawn at 6dp
// over a title is unreadable on a low-contrast background and untranslatable in any layout
// that does not have that exact free space. The number belongs in the semantics label, where
// a screen reader and a text scale both get it for free.

import 'package:flutter/material.dart';

/// The determinate bar, or nothing at all when the amount is unknown.
///
/// ⚠️ **`Semantics(liveRegion: true)` ONLY WHILE IT IS SHOWN.** A progress bar that announces
/// itself continuously is the single most intrusive thing a screen reader can be made to
/// repeat; announcing it while it is visible and silent when it is not is the difference
/// between a useful control and a nuisance.
class ChapterProgressLine extends StatelessWidget {
  const ChapterProgressLine({
    super.key,
    required this.progress,
    this.barColor,
    this.spokenValue,
  });

  /// `0.0`–`1.0`, or `null` for "started, amount unknown".
  final double? progress;

  /// ⚠️ **`5-3` § 4.3: THE FULL SPOKEN VALUE, WHEN THE CALLER HAS ONE.**
  ///
  /// `downloads.md` § 7 asks for *Chapter 13 of 50, 41 per cent* — the position and the total
  /// are facts the bar does not carry, and `5-3`'s criterion is that `Semantics` announces
  /// them. **`null` keeps the bare percentage**, so the novel-details tile that already passes
  /// only a fraction is unchanged; a caller with a chapter's position passes the localized
  /// phrase and the percentage is derived from the value rather than rendered twice.
  final String? spokenValue;

  /// Overridable so a caller inside `NovelDetailsScreen`'s `TintedSurface` can reach
  /// contrast; the default is the accent token rather than a literal colour.
  final Color? barColor;

  @override
  Widget build(BuildContext context) {
    final double? value = progress;
    if (value == null) {
      return const SizedBox.shrink();
    }
    // ⚠️ **CLAMPED, NOT ASSERTED.** A provider that computes a ratio of two counters can
    // produce 1.0000001 during a rebuild, and `LinearProgressIndicator` throws on a value
    // outside `[0, 1]` — so a rounding artefact would take the tile down. Clamping is the
    // honest response: the bar is already at its end.
    final double clamped = value.clamp(0.0, 1.0);
    // ⚠️ **`spokenValue ?? THE BARE PERCENTAGE`, AND NEVER A SECOND RENDERING OF IT.**
    // `14-design-tokens.md` § Accessibility: one spoken value per component, and a screen
    // reader that says "Chapter 13 of 50, 41 per cent" must not then also read a "41%" from
    // somewhere else in the tree.
    return Semantics(
      liveRegion: true,
      label: spokenValue ?? '${(clamped * 100).round()}%',
      child: ExcludeSemantics(
        child: LinearProgressIndicator(
          value: clamped,
          minHeight: 2,
          backgroundColor: Theme.of(
            context,
          ).colorScheme.surfaceContainerHighest,
          valueColor: AlwaysStoppedAnimation<Color>(
            barColor ?? Theme.of(context).colorScheme.primary,
          ),
        ),
      ),
    );
  }
}
