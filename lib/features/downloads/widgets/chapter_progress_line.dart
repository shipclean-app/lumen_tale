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
  const ChapterProgressLine({super.key, required this.progress, this.barColor});

  /// `0.0`–`1.0`, or `null` for "started, amount unknown".
  final double? progress;

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
    return Semantics(
      liveRegion: true,
      label: '${(clamped * 100).round()}%',
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
