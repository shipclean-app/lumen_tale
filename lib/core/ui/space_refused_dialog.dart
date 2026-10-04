// Lumen Tale — E20's refusal, the one dialogue that names two numbers.
//
// ## ⚠️ IT SHOWS BOTH MEASURED FIGURES, OR IT IS NOT THIS DIALOGUE
//
// `3-3` § 3.6: the refusal carries `requiredBytes` **and** `freeBytes`, both measured — one
// from a copy already on disk, one from a bounded probe of the volume chapters are written
// to. A refusal with no numbers is a shrug, and a shrug at a reader who has just been told
// "no" is worse than the failure it replaces.
//
// ## ⚠️ NO "DOWNLOAD ANYWAY", AND NO DELETION
//
// § 4.3.2 forbids both, and the reason is the same: the app does not know what else is on
// this phone, so offering to remove something on the reader's behalf is a guess about their
// library. The dialogue says what is true, gives the one action that is honest — going back
// to free space themselves — and stops.

import 'package:flutter/material.dart';
import 'package:lumen_tale/l10n/generated/app_localizations.dart';

/// The two figures, formatted on demand.
///
/// ⚠️ **`formatBytes` IS A CALLBACK, NOT A `String`.** The bytes must be formatted in the
/// reader's locale and in the dialog's own `BuildContext`; formatting them where the refusal
/// was constructed would freeze them against whatever locale happened to be current there.
final class SpaceRefusedDialogData {
  const SpaceRefusedDialogData({
    required this.requiredBytes,
    required this.freeBytes,
    required this.formatBytes,
  });

  final int requiredBytes;
  final int freeBytes;
  final String Function(int bytes) formatBytes;
}

/// Shows E20's dialogue. There is no return value: there is nothing to accept.
Future<void> showSpaceRefusedDialog({
  required BuildContext context,
  required SpaceRefusedDialogData data,
}) => showDialog<void>(
  context: context,
  // ⚠️ **NOT DISMISSABLE INTO SILENCE BY TAPPING OUTSIDE.** A refusal the reader can wave
  // away is indistinguishable from no refusal at all — but it still costs them the download
  // they asked for, so the only exits are the two buttons below.
  barrierDismissible: false,
  builder: (BuildContext dialogContext) {
    final AppLocalizations l10n = AppLocalizations.of(dialogContext);
    return AlertDialog(
      title: Text(l10n.chapterListSpaceRefusedTitle),
      content: Text(
        l10n.downloadSpaceRefusedBody(
          data.formatBytes(data.requiredBytes),
          data.formatBytes(data.freeBytes),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: Text(l10n.commonCancel),
        ),
        // ⚠️ **ONE CONFIRM, AND IT CONFIRMS NOTHING.** It closes the dialogue and lets the
        // reader act — there is no "download anyway" behind it.
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: Text(l10n.commonOk),
        ),
      ],
    );
  },
);
