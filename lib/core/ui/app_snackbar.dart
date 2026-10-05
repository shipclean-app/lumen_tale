// Lumen Tale — the app's ONE snackbar, and the two words it adds to a plain one.
//
// ## ⚠️ **IT EXISTS BECAUSE TWO RULE FILES NAMED IT AND NOBODY WROTE IT**
//
// `09-widgets-ui.md` § Overlays: *"Lightweight feedback uses the app's snackbar wrapper in
// `core/ui/` — no scattered `ScaffoldMessenger` calls."* `13-error-handling.md` rule 5 says
// the same about the user-facing mapping. Until this file the only snackbars in `lib/` were
// hand-written `ScaffoldMessenger.of(context).showSnackBar(SnackBar(...))` calls, so the rule
// named a component that had never been written — and `downloads.md` § 3 asks for this
// screen's snackbar to carry `--color-surface-raised` and `--shadow-sheet`, which a bare
// `SnackBar` does not.
//
// `09-widgets-ui.md` rule 2: **when a primitive is missing, add it once to `core/ui/` and
// reuse it.** It is added here rather than copied into `features/downloads/`, and the four
// existing call sites are left alone deliberately — `AGENTS.md` priority 5 forbids a
// speculative refactor, and this slice owns no screen of theirs.
//
// ## ⚠️ **IT TAKES AN ALREADY-RESOLVED SENTENCE AND A CALLBACK, NEVER A REPOSITORY**
//
// `09-widgets-ui.md` § Overlays: *"Never put domain/repository logic inside `core/ui/`
// overlay components — they receive already-resolved values and callbacks."* So there is no
// provider read and no notifier call in this file: the screen decided the words, and this
// only presents them.

import 'package:flutter/material.dart';

/// ⚠️ **THE `--shadow-sheet` STEP, WRITTEN ONCE** so the downloads screen does not repeat it.
///
/// `downloads.md` § 12 assigns `--shadow-sheet` (`0 8 24 rgba(0,0,0,0.18)`) to the snackbar
/// and `--shadow-dialog` to the dialogue, and `app/theme/shadows.dart` is the token that
/// carries it. Material's `SnackBar` wants a single `double`; this is the figure it is given,
/// and it is a **named constant rather than a bare `3`** so a reader can find it.
const double kAppSnackBarElevation = 3;

/// Shows [message] in the app's snackbar, optionally with one action.
///
/// ⚠️ **`actionLabel` AND `onAction` ARE BOTH REQUIRED OR NEITHER IS USED.** A snackbar whose
/// button has no label is a rectangle the reader has to guess at, and
/// `14-design-tokens.md` § Accessibility says an icon-only control needs a semantics label —
/// so a half-supplied pair renders no button at all rather than an unlabelled one.
///
/// ⚠️ **AND WHEN THERE IS NO ACTION THERE IS NO DISMISS BUTTON.** A snackbar with a *Close*
/// beside a *Resume* is two competing dismissals, one of them primary; with neither, the
/// duration is the dismissal.
void showAppSnackBar(
  BuildContext context, {
  required String message,
  String? actionLabel,
  VoidCallback? onAction,
}) {
  final ThemeData theme = Theme.of(context);
  final bool hasAction = actionLabel != null && onAction != null;

  // ⚠️ **NOT `await`ed.** `showSnackBar` returns a `ScaffoldFeatureController`, which is a
  // `SynchronousFuture`-shaped handle rather than something to suspend on — and this
  // function has nothing to do afterwards.
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      duration: const Duration(seconds: 5),
      // ⚠️ **THE RAISED SURFACE, NOT A DIALOGUE.** `downloads.md` § 3's anatomy makes the
      // snackbar one of *the two things that float*, and § 12 assigns `--shadow-sheet` to it;
      // `LumenShadows.dialog` belongs to the `AlertDialog`.
      elevation: kAppSnackBarElevation,
      backgroundColor: theme.colorScheme.surfaceContainerHighest,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      action: hasAction
          ? SnackBarAction(label: actionLabel, onPressed: onAction)
          : null,
    ),
  );
}
