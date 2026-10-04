// Lumen Tale — two dialogs the library needs and Browse will need again.
//
// `09-widgets-ui.md` § Overlays: **overlay components live in `core/ui/`, never as a local copy
// inside a feature.** `3-1`'s catalogue and `3-2`'s novel details both raise the similar-title
// question, and a second copy of a dialog that decides whether a duplicate gets written is two
// places for B40's default to be wrong in.
//
// ## The similar-title dialog returns a VERDICT, and has no default action
//
// ⚠️ **Nothing happens if the reader closes it.** That is not politeness — it is C8: on a
// device with no cloud backup the easiest gesture must not be the one that writes a second
// copy of a novel the reader already has. So `dismissed` is a first-class verdict and it
// reaches the same branch as `declined`.
//
// ## ⚠️ "Add anyway" says NOTHING WILL BE MERGED, on the dialog
//
// The button reads like a merge. One line under it says the second novel stays a second
// novel, and that line is on the dialog because after the dialog there is nowhere to say it.

import 'package:flutter/material.dart';

import 'package:lumen_tale/domain/library/library_repository.dart';
import 'package:lumen_tale/domain/library/similar_title.dart';
import 'package:lumen_tale/domain/sources/models/novel.dart';
import 'package:lumen_tale/l10n/generated/app_localizations.dart';

/// Shows the similar-title question and returns what the reader chose.
///
/// ⚠️ **Returns [SimilarTitleVerdict.dismissed] when the dialog is closed by the barrier, the
/// back gesture or the system button** — and `dismissed` declines. A dialog that answered
/// "add anyway" on dismissal would make the most casual gesture on the screen the one that
/// writes a duplicate.
Future<SimilarTitleVerdict> showSimilarTitleDialog(
  BuildContext context, {
  required List<SimilarTitle> similar,
}) {
  return showDialog<SimilarTitleVerdict>(
    context: context,
    builder: (BuildContext context) => SimilarTitleDialog(similar: similar),
  ).then(
    (SimilarTitleVerdict? answer) => answer ?? SimilarTitleVerdict.dismissed,
  );
}

/// B40's dialog.
class SimilarTitleDialog extends StatelessWidget {
  const SimilarTitleDialog({required this.similar, super.key});

  final List<SimilarTitle> similar;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppLocalizations copy = AppLocalizations.of(context);
    final SimilarTitle first = similar.first;

    return AlertDialog(
      title: Text(copy.librarySimilarTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // ⚠️ **Both titles AND both sites, per entry.** "Is this the same novel?" is
          // unanswerable without knowing which site published which — which is why the body
          // repeats for every candidate rather than only for the first.
          for (final SimilarTitle entry in similar)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              // ⚠️ **Positional, and in the order the generator emitted.** gen-l10n sorts
              // named placeholders alphabetically rather than in ARB order, so a named argument
              // here does not exist — and the row below names the same four values in the same
              // order, which is what keeps the two calls from drifting.
              child: Text(
                copy.librarySimilarBody(
                  entry.existingTitle,
                  entry.incomingTitle,
                  entry.incomingSourceName,
                  entry.existingSourceName,
                ),
              ),
            ),
          // ⚠️ **On the dialog, not after it.** "Add anyway" reads like a merge, and after the
          // dialog there is nowhere left to say the second novel stays a second novel.
          Text(
            copy.librarySimilarExplain,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          if (similar.length > 1)
            Text(
              '${similar.length}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          if (first.isSameSource)
            Text(
              copy.librarySimilarBody(
                first.existingTitle,
                first.incomingTitle,
                first.incomingSourceName,
                first.existingSourceName,
              ),
              style: theme.textTheme.bodySmall,
            ),
        ],
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () =>
              Navigator.of(context).pop(SimilarTitleVerdict.dismissed),
          child: Text(copy.libraryActionCancel),
        ),
        TextButton(
          onPressed: () =>
              Navigator.of(context).pop(SimilarTitleVerdict.openExisting),
          child: Text(copy.librarySimilarOpenExisting),
        ),
        FilledButton(
          onPressed: () =>
              Navigator.of(context).pop(SimilarTitleVerdict.addAnyway),
          child: Text(copy.librarySimilarAddAnyway),
        ),
      ],
    );
  }
}

/// A yes/no confirmation with an optional third action.
///
/// ⚠️ **The destructive label is a PARAMETER, not a style.** `13-error-handling.md` asks for a
/// typed reason and a copy that matches it, and a red button that says "OK" makes the reader
/// read the title twice — which is the wrong place to make them work.
class ConfirmDialog extends StatelessWidget {
  const ConfirmDialog({
    required this.title,
    required this.body,
    required this.confirmLabel,
    required this.isDestructive,
    super.key,
  });

  final String title;
  final String body;
  final String confirmLabel;

  /// Paints the confirm button in the error colour. **Never** implied by the presence of the
  /// dialog.
  final bool isDestructive;

  /// Shows it and answers `true` only on an explicit confirm.
  ///
  /// ⚠️ **`null` becomes `false`,** and that is the same rule as the similar-title dialog:
  /// closing a confirmation is not agreeing to it.
  static Future<bool> ask(
    BuildContext context, {
    required String title,
    required String body,
    required String confirmLabel,
    required bool isDestructive,
  }) async {
    final bool? answer = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => ConfirmDialog(
        title: title,
        body: body,
        confirmLabel: confirmLabel,
        isDestructive: isDestructive,
      ),
    );
    return answer ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations copy = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(title),
      content: Text(body),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(copy.libraryActionCancel),
        ),
        FilledButton(
          style: isDestructive
              ? FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error,
                  foregroundColor: Theme.of(context).colorScheme.onError,
                )
              : null,
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(confirmLabel),
        ),
      ],
    );
  }
}

/// B12/B40 — add this novel, asking about a similar title **before** anything is stored.
///
/// ⚠️ **THE REPOSITORY IS A PARAMETER, and that is the whole point of this function living
/// here.** It used to be declared in `features/library/library_screen.dart` and read
/// `libraryRepositoryProvider` through a `WidgetRef` — which meant a *dialog* owned the
/// repository, and `features/novel_details` had to import a feature to reach it.
///
/// Taking the repository makes this a pure UI-layer action over a `domain` interface, so
/// any screen that can show a dialog can use it, and none of them imports another feature.
///
/// ⚠️ **A FUNCTION, NOT A WIDGET, and that is `2-5`'s rule kept.** The caller must supply
/// the dialog and then act on the verdict; a widget that both asks and writes would put
/// B40's default one layer away from the branch that honours it.
Future<AddOutcome> addWithSimilarTitleCheck(
  BuildContext context,
  LibraryRepository library,
  Novel novel,
) {
  return library.addFromCatalogue(
    novel: novel,
    onSimilarTitle: (List<SimilarTitle> similar) =>
        showSimilarTitleDialog(context, similar: similar),
  );
}
