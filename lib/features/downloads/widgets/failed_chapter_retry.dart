// Lumen Tale — the `+` **Retry** affordance on a failed chapter.
//
// ## ⚠️ IT RETRIES **THIS CHAPTER ALONE**, AND SAYING SO IS THE POINT
//
// § 4.3.1 forbids a "retry everything" control here, and the reason is not taste: a `failed`
// state is a **typed** `error_code`, so one chapter failed for *a* reason — a layout change
// on the site, a connection that dropped — and the others are not broken. A single retry that
// re-queues the whole novel turns one site's layout change into a hundred fetches that will
// fail the same way.
//
// ## ⚠️ THE WORDS COME FROM `AppErrorCopy`, WHICH IS EXHAUSTIVE OVER THE SEALED HIERARCHY
//
// `13-error-handling.md` rule 5: one place maps failures to localized messages, and this
// widget may not invent a sentence. `forSourceFailure` is a `switch` over a **sealed**
// hierarchy, so a new `SourceFailure` arm breaks this file's compilation until someone
// decides what it looks like — which is the property a `toString()` never had.

import 'package:flutter/material.dart';
import 'package:lumen_tale/core/error/source_failure.dart';
import 'package:lumen_tale/core/ui/app_error_copy.dart';
import 'package:lumen_tale/l10n/generated/app_localizations.dart';

/// A failed chapter's error line and its single-chapter retry.
///
/// ⚠️ **AN ICON **PLUS** A LABEL, NEVER RED TEXT ALONE.** `09-widgets-ui.md`: colour is not
/// information. A reader who cannot distinguish `--color-error` from the surrounding
/// secondary text still needs to know something went wrong and what to press.
class FailedChapterRetry extends StatelessWidget {
  const FailedChapterRetry({
    super.key,
    required this.failure,
    required this.onRetry,
  });

  /// The typed cause. B24 — a `SourceFailure`, never a `String`.
  final SourceFailure failure;

  /// Queues **this chapter** again. B22.
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AppErrorString shape = l10n.forSourceFailure(failure);

    // ⚠️ **A `null` RECOVERY IS NOT AN ERROR AND IS NOT PADDED WITH A BUTTON.** A layout
    // change or a failed conversion has nothing a retry repairs; `AppErrorCopy.recovery`
    // returns `null` precisely so this widget can show the sentence and no button. A retry
    // button there is the lie `AppErrorCopy`'s own doc forbids.
    final String? retry = l10n.recovery(shape);

    return Row(
      children: <Widget>[
        Icon(Icons.error_outline, size: 16, color: theme.colorScheme.error),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            l10n.message(shape),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
        ),
        if (retry != null) TextButton(onPressed: onRetry, child: Text(retry)),
      ],
    );
  }
}
