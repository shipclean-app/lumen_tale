// Lumen Tale — E20's line: the phone is out of storage, and one measured figure.
//
// `5-3` § 4.2, from `downloads.md` § 4 *Offline* and § 9.
//
// ## ⚠️ **NO FREE-SPACE FIGURE, EVER, AND § 9 SAYS WHY IN ONE SENTENCE**
//
// *"Free space is not displayed — the app has no honest way to read it without a platform
// channel it has not earned."* A free-space number on a phone goes stale in the seconds
// between rendering it and the reader looking up; C12 requires a failure state to be
// **true**, and a stale number is worse than no number because it looks like data.
//
// So the one figure on this line is **what this chapter needs** — measured by the app, in the
// file it was about to write — and never what the phone has left.
//
// ## ⚠️ **THE ACTION IS "FREE SPACE, THEN RESUME", NOT "TRY AGAIN"**
//
// A Retry would fail identically: the disk is still full. `13-error-handling.md`'s rule 5
// asks for a message the reader can *act on*, and "try again" is an instruction that cannot
// work. The button here is **Resume** — the queue's own control — because the queue stopped,
// not the chapter.

import 'package:flutter/material.dart';
import 'package:lumen_tale/app/theme/lumen_colors.dart';
import 'package:lumen_tale/app/theme/lumen_spacing.dart';
import 'package:lumen_tale/core/ui/byte_format.dart';
import 'package:lumen_tale/l10n/generated/app_localizations.dart';

/// E20's two sentences and the queue's own *Resume*.
class StorageFullNotice extends StatelessWidget {
  const StorageFullNotice({
    super.key,
    required this.bytesNeeded,
    required this.onResume,
  });

  /// ⚠️ **`null` RENDERS **NO FIGURE AT ALL**, NOT `0`.** The runner records `null` when the
  /// store threw something it could not classify as out-of-space, and `downloads.md` § 8's
  /// rule — *"Absent → the byte figure is omitted rather than showing `0`, which is a
  /// claim"* — applies to bytes exactly as it does to a download's total.
  final int? bytesNeeded;

  final VoidCallback onResume;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final LumenColors colors = LumenColors.of(context);
    final int? needed = bytesNeeded;

    // ⚠️ **THE FIGURE **ONLY**, AND THE SENTENCE BELONGS TO `QueueRunStateRow`.**
    //
    // E20's sentence — *"The phone is out of storage. Free up some space, then resume."* — is
    // the row's `stopReason` rendering, and printing it here as well would put the **same
    // words twice** on one screen. `downloads.md` § 4 wants the sentence AND the figure; the
    // sentence is one line wherever it is printed, and this widget is the figure's home.
    return Padding(
      padding: EdgeInsets.only(left: 24, bottom: LumenSpacing.of(context).xs),
      child: Text(
        // ⚠️ **`needed == null` PRINTS **NOTHING**, NOT `0`.** `downloads.md` § 8's rule for an
        // absent figure is *omitted*, and a bare `0` is a claim.
        needed == null
            ? ''
            : l10n.downloadsStorageNeeded(formatBytes(context, needed)),
        style: Theme.of(
          context,
        ).textTheme.labelSmall?.copyWith(color: colors.textSecondary),
      ),
    );
  }
}
