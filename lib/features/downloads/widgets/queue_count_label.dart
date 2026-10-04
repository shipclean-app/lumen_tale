// Lumen Tale — `12 of 50 downloaded · 1 in progress`, from two exact numbers.
//
// `5-1` § 4.1 / § 4.3, from `downloads.md` § 3 and § 2.1. It is the **same widget** for
// the three surfaces that show a queue's progress — the library row, the novel's `Slot 2`
// and `AppScaffold`'s `persistentStatus` — because `design-system.md` § 3.2 requires the
// progress to be displayed **once**, not three times with three figures.
//
// ## ⚠️ **BOTH NUMBERS ARE EXACT, AND THEY COME FROM THE ROWS**
//
// C8: *"`12 of 50 downloaded` is `count(state='done')` and is 12 — never 13 after a
// failure and never 11 after a cancellation."* [QueueProgressCounts] derives both, so this
// widget has no arithmetic of its own to get wrong: it renders what it is given.
//
// ## ⚠️ **NO ESTIMATED BYTES, EVER**
//
// `downloads.md` § 2.1: *"progress is never a single aggregate bar over the novel"* — the
// bar belongs to the chapter being fetched. This widget therefore renders **no bar and no
// size figure**; the byte count is `5-3`'s, measured per chapter.
//
// ## ⚠️ **THE WORDS ARE THE CALLER'S**
//
// [labelOf] takes the counts and returns one localized sentence, the same shape
// `SettingsChoiceSheet.warningFor` uses. `domain/` and `features/` both keep their
// localization out of this file, and adding an ARB key here would have put a string in
// the widget instead of with the screen that owns the wording — `6-7` is the localisation
// slice and it owns the ARB.

import 'package:flutter/material.dart';
import 'package:lumen_tale/app/theme/lumen_colors.dart';
import 'package:lumen_tale/domain/downloads/queue_progress_counts.dart';

/// The queue's one-line header. Dense, one line, and every figure on it exact.
class QueueCountLabel extends StatelessWidget {
  const QueueCountLabel({
    required this.counts,
    required this.labelOf,
    super.key,
  });

  /// Both numbers, derived from the rows by [QueueProgressCounts.of].
  final QueueProgressCounts counts;

  /// The sentence, localized by the caller. Takes the counts rather than two integers so
  /// a caller cannot mix one row's `downloaded` with another row's `total` — which is the
  /// shape C8's "never 13 after a failure" defect has.
  final String Function(QueueProgressCounts counts) labelOf;

  @override
  Widget build(BuildContext context) {
    final LumenColors colors = LumenColors.of(context);
    // ⚠️ **ONE LINE, AND IT ELIDES FROM THE RIGHT.** § 11.5's manual check: at 360dp the
    // count may be truncated — **never the novel's title**, which is the identity.
    return Text(
      labelOf(counts),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: Theme.of(
        context,
      ).textTheme.labelMedium?.copyWith(color: colors.textSecondary),
    );
  }
}

/// The empty case, and it is a **sentence**, not a blank line.
///
/// `downloads.md` § 2.1's empty state is "a sentence and one button"; B22's own rule is
/// that an empty state is a state a screen knows about. So this exists rather than
/// `QueueCountLabel` rendering `0 of 0`.
class QueueCountLabelEmpty extends StatelessWidget {
  const QueueCountLabelEmpty({required this.label, super.key});

  /// The caller's localized sentence.
  final String label;

  @override
  Widget build(BuildContext context) {
    final LumenColors colors = LumenColors.of(context);
    return Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: Theme.of(
        context,
      ).textTheme.labelMedium?.copyWith(color: colors.textSecondary),
    );
  }
}
