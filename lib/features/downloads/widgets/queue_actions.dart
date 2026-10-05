// Lumen Tale — Pause and Cancel, and the two rules that decide whether each is there.
//
// `5-2` § 4.2, from `downloads.md` § 5.
//
// ## ⚠️ **A CONTROL IS **ABSENT**, NOT DISABLED — AND THE HEADER SAYS WHY**
//
// `downloads.md` § 11: *"Absent, not disabled — a disabled control is a promise about a
// version that does not exist."* A greyed *Pause* on a queue that is not running is a
// promise that the queue will run again, and there are two states where it may not: paused
// and stopped. So this widget renders *Resume* and not a disabled *Pause*.
//
// ## ⚠️ **NO GESTURE, AND THAT IS C11**
//
// `downloads.md` § 5's *Gestures*: vertical scroll and system back only. A swipe that paused
// or cancelled a fifty-chapter download is a gesture the reader never asked for, and with no
// backup (C8) an accidental cancel is an afternoon of re-downloading.

import 'package:flutter/material.dart';
import 'package:lumen_tale/app/theme/lumen_spacing.dart';
import 'package:lumen_tale/l10n/generated/app_localizations.dart';

/// The queue's two row-level controls.
class QueueActions extends StatelessWidget {
  const QueueActions({
    super.key,
    required this.canPause,
    required this.onPause,
    required this.onCancel,
  });

  /// ⚠️ **`false` MEANS *DO NOT RENDER THE BUTTON*, NOT `onPressed: null`.** See the header.
  final bool canPause;

  final VoidCallback onPause;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final LumenSpacing spacing = LumenSpacing.of(context);

    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: <Widget>[
        if (canPause)
          TextButton(
            onPressed: onPause,
            child: Text(l10n.downloadsPauseAction),
          ),
        // ⚠️ **CANCEL IS ALWAYS RENDERED WHILE THERE IS SOMETHING TO CANCEL**, including
        // while paused and while stopped: B19 gives the reader the right to abandon the
        // queue, and a control that appears only in the running state would take it away
        // exactly when the reader is deciding.
        Padding(
          padding: EdgeInsets.only(left: spacing.sm),
          child: TextButton(
            onPressed: onCancel,
            child: Text(l10n.downloadsCancelAction),
          ),
        ),
      ],
    );
  }
}
