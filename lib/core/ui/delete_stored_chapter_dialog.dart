// Lumen Tale — the delete-one confirmation of B33.
//
// ## ⚠️ WHY IT LIVES IN `core/ui/` AND NOT IN `features/downloads/`
//
// `09-widgets-ui.md` § Overlays: **three** surfaces need this dialog — the chapter tile
// (`3-2`), the Downloads screen (`5-2`) and the selection sheet — and a copy inside one
// feature is precisely how a component ends up with two renderings. It takes **resolved
// values and callbacks only**: no repository, no provider, no domain logic.
//
// ## ⚠️ WHY IT CONFIRMS A DESTRUCTION THAT CANNOT BE UNDONE
//
// `downloads.md` § 4 argues it in one line: removing a novel from the library is reversible
// *because nothing is destroyed* (B32). Deleting a download **is** the destruction — there is
// no backup and no export (B31, C8) — so an *Undo* would be promising to re-download content
// that may have changed or disappeared. Confirm, then delete. No undo.
//
// ## ⚠️ `siblingCount` IS A NUMBER, NOT A PHRASE, AND IT IS ALWAYS PRESENT
//
// The dialog's whole reassurance is "the others are not touched". Passing a pre-built
// sentence would let a caller write "and also your library", and the one thing this dialog
// must not do is decorate a number. `0` is legal and renders as a different plural form.

import 'package:flutter/material.dart';
import 'package:lumen_tale/core/ui/byte_format.dart';
import 'package:lumen_tale/l10n/generated/app_localizations.dart';

/// Shows the B33 confirmation and returns `true` only on an explicit confirm.
///
/// ⚠️ **`barrierDismissible: false` AND A REAL CANCEL.** A destructive confirmation that a
/// stray tap outside dismisses is a confirmation that fires on its own; one with no cancel
/// is a dead end. Both are set, deliberately, and the row that proves the second is in
/// `test/core/ui/delete_stored_chapter_dialog_test.dart`.
Future<bool> confirmDeleteStoredChapter({
  required BuildContext context,
  required int ordinal,
  required int siblingCount,
  required int freedBytes,
}) async {
  final AppLocalizations l10n = AppLocalizations.of(context);
  final bool? answer = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext dialogContext) => AlertDialog(
      title: Text(l10n.deleteStoredTitle(ordinal)),
      content: Text(
        l10n
            .deleteStoredBody(
              formatBytes(dialogContext, freedBytes),
              describeSiblingCount(dialogContext, siblingCount),
            )
            .trim(),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(l10n.deleteStoredConfirm),
        ),
      ],
    ),
  );
  // ⚠️ **A DISMISSED DIALOG IS `null`, AND `null` IS A CANCEL.** `barrierDismissible: false`
  // makes it unreachable today; returning `?? false` anyway means a future escape route
  // cannot silently become consent.
  return answer ?? false;
}
