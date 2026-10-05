// Lumen Tale — B19's confirmation, the one dialog that cancels a queue.
//
// ## ⚠️ WHY IT LIVES IN `core/ui/` AND NOT IN `features/downloads/`
//
// `09-widgets-ui.md` rule 2: *"When a primitive is missing, add it once to `core/ui/` and
// reuse it — never copy a widget into a feature."* `app/shell/app_shell.dart` renders the
// same trailing *Cancel* action for the **updates** queue, and `5-3`'s `FailedSection` will
// want the same shape. It takes **resolved values and a callback only** — no repository, no
// provider, no domain logic — which is the rule `09-widgets-ui.md` § Overlays states.
//
// ## ⚠️ IT NAMES THE CHAPTER IN FLIGHT **AND** THE NUMBER THAT SURVIVES
//
// `downloads.md` § 7: *"Destructive actions are confirmed and named: the dialog names the
// chapter, so the confirmation is a statement about a specific thing rather than a generic
// 'Are you sure?'."* C12 asks the same of every state on this screen — a borrowed-device
// reader has to be able to describe it out loud — and "Cancel?" is a word nobody can report
// to the owner.
//
// ## ⚠️ **`keptCount` IS A NUMBER AND NOT A PRE-BUILT SENTENCE**, for `delete_stored_chapter_dialog.dart`'s
// reason: passing a phrase would let a caller write "and also your library", and the one
// thing this dialog must not do is decorate a figure.

import 'package:flutter/material.dart';
import 'package:lumen_tale/l10n/generated/app_localizations.dart';

/// The two figures the confirmation is about.
final class CancelQueueDialogData {
  const CancelQueueDialogData({
    required this.keptCount,
    required this.activeChapterTitle,
  });

  /// How many chapters are already stored and will survive. B19: cancelling *"keeps every
  /// chapter already completed"* — and the number is what turns that from a promise into
  /// something the reader can check afterwards.
  final int keptCount;

  /// The chapter being fetched at the moment of the tap, or `null` when nothing is in
  /// flight. `null` renders the sentence **without** naming one rather than inventing a
  /// placeholder, because a dialogue that says "Chapter —" is worse than one that says
  /// "the chapter being downloaded".
  final String? activeChapterTitle;
}

/// Shows B19's confirmation and returns `true` only on an explicit confirm.
///
/// ⚠️ **`barrierDismissible: false`, FOR `delete_stored_chapter_dialog.dart`'s REASON**:
/// a destructive confirmation a stray tap dismisses is one that fires on its own. There is
/// a real *Cancel* button, so nothing here is a dead end.
Future<bool> confirmCancelQueue({
  required BuildContext context,
  required CancelQueueDialogData data,
}) async {
  final AppLocalizations l10n = AppLocalizations.of(context);
  final String? active = data.activeChapterTitle;
  final bool? answer = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext dialogContext) => AlertDialog(
      title: Text(l10n.queueCancelTitle),
      content: Text(
        // ⚠️ **THE ARGUMENT ORDER IS `kept` THEN `name`, AND THAT IS **NOT** THE ORDER THEY
        // APPEAR IN THE SENTENCE.** `gen-l10n` emits one parameter per declared placeholder in
        // the order of the `@key` metadata's `placeholders` map, and this repository's ARB
        // files declare them alphabetically (`16-i18n.md` rule 2, and
        // `tool/declare_arb_placeholders.py` sorts them). Passing them the other way round
        // produces *"'12' is being downloaded … The Chapter 13 chapters already downloaded are
        // kept"* — a real sentence with the reader's chapter in the wrong slot.
        (active == null || active.trim().isEmpty)
            ? l10n.queueCancelBody(data.keptCount)
            : l10n.queueCancelBodyWithChapter(data.keptCount, active),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text(l10n.commonCancel),
        ),
        // ⚠️ **A FILLED BUTTON, NOT A SECOND TEXTBUTTON.** `downloads.md` § 7 calls this the
        // screen's most important submission, and `14-design-tokens.md` says the primary
        // action is the one the reader's thumb is already on.
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(l10n.queueCancelConfirm),
        ),
      ],
    ),
  );
  // ⚠️ **`?? false`, NOT `?? true`.** `barrierDismissible: false` makes the `null` case
  // unreachable today; returning `false` anyway means a future escape route cannot silently
  // become consent to a deletion.
  return answer ?? false;
}
