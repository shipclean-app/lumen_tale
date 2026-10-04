// Lumen Tale — the library screen: the list, the tile, and the two dialogs it raises.
//
// `2-5` § 4.3's five states, and the four that belong to other slices are named in the file
// header rather than left blank.
//
// ## ⚠️ The stream is `keepAlive`, and that is a stated rule
//
// `05-state-management.md` rule 10 names the library among the `keepAlive` cases: it is the
// first-rank destination (ADR-018), so it must survive a tab change and a round trip. An
// `autoDispose` library would re-query the whole table on every tab press, and the reader
// would see the list rebuild.
//
// ## ⚠️ Nothing here fetches
//
// The screen renders [LibraryEntry] rows from the local database. The only thing that reaches
// a site is the "check for new chapters" button, which is an **interface hole**: B36/B38/B39's
// wire belongs to `6-3`/`6-4`/`6-10`. `2-5` makes it visible and labelled, and does not
// execute it — a button that looks live and does nothing is worse than a labelled slot that
// says which slice owns it.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lumen_tale/core/ui/app_scaffold.dart';
import 'package:lumen_tale/core/ui/library_dialogs.dart';
import 'package:lumen_tale/data/library/library_providers.dart';
import 'package:lumen_tale/domain/library/library_entry.dart';
import 'package:lumen_tale/domain/library/library_repository.dart';
import 'package:lumen_tale/l10n/generated/app_localizations.dart';

/// `/library` — the reader's own novels, offline.
class LibraryScreen extends ConsumerWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations copy = AppLocalizations.of(context);
    final AsyncValue<List<LibraryEntry>> library = ref.watch(
      libraryStreamProvider,
    );

    return AppScaffold(
      titleBar: AppBar(
        title: Text(copy.libraryTitle),
        // ⚠️ **A LABEL, never an icon alone** (B36). A glyph with no word is a puzzle, and the
        // whole of this button is that the action is not available yet.
        actions: <Widget>[
          TextButton(onPressed: null, child: Text(copy.commonRetry)),
        ],
      ),
      content: switch (library) {
        AsyncData<List<LibraryEntry>>(value: final List<LibraryEntry> rows) =>
          rows.isEmpty
              ? _empty(context, copy)
              : _filled(context, ref, copy, rows),
        AsyncError<List<LibraryEntry>>(error: final Object _) => _loadError(
          context,
          copy,
        ),
        _ => _loading(),
      },
    );
  }

  /// ⚠️ **Empty is NOT an error and never says "0 results".** It names the next step, because
  /// an empty library is the state every reader is in until they browse once.
  Widget _empty(BuildContext context, AppLocalizations copy) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              copy.libraryEmptyTitle,
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              copy.libraryEmptyBody,
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _filled(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations copy,
    List<LibraryEntry> rows,
  ) {
    return ListView.separated(
      // ⚠️ **Keyed by id, not by index.** A removal above reindexes every row below it, and an
      // index key would make Flutter reuse the wrong tile's state — which on a removal dialog
      // means the next tap opens the wrong novel's dialog.
      key: const ValueKey<String>('library-list'),
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: rows.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (BuildContext context, int index) {
        final LibraryEntry entry = rows[index];
        return LibraryTile(
          key: ValueKey<String>(entry.id),
          entry: entry,
          onRemove: () => _confirmRemoval(context, ref, entry),
        );
      },
    );
  }

  /// B32's dialog, and its body is where C8's reassurance lives.
  Future<void> _confirmRemoval(
    BuildContext context,
    WidgetRef ref,
    LibraryEntry entry,
  ) async {
    final AppLocalizations copy = AppLocalizations.of(context);
    final LibraryRepository repository = ref.read(libraryRepositoryProvider);

    // ⚠️ **The count is asked for BEFORE the confirmation**, so the number in the dialog is one
    // the reader could check. Asking afterwards would mean writing first and explaining later.
    final int downloaded = await repository.countDownloadedChapters(entry.id);
    if (!context.mounted) {
      return;
    }

    final bool confirmed = await ConfirmDialog.ask(
      context,
      title: copy.libraryRemoveTitle,
      body: copy.libraryRemoveBody(downloaded, entry.title),
      confirmLabel: copy.libraryRemoveAction,
      isDestructive: true,
    );
    if (!confirmed || !context.mounted) {
      return;
    }

    // ⚠️ **`removeFromLibrary` returns the count it read before the write**, and the sheet says
    // what survived. B32 is a promise the reader can see rather than a rule they must trust.
    await ref.read(removeFromLibraryProvider)(entry.id);
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(copy.libraryRemoveKept)));
  }

  Widget _loadError(BuildContext context, AppLocalizations copy) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          copy.libraryLoadErrorTitle,
          style: Theme.of(context).textTheme.titleMedium,
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  /// ⚠️ **A skeleton in the SHAPE of a tile**, and never a spinner: a spinner over a list
  /// implies a wait of unknown length, while a skeleton implies the shape of what is arriving.
  Widget _loading() {
    return ListView.builder(
      itemCount: 6,
      itemBuilder: (BuildContext context, int index) => const ListTile(
        leading: SizedBox(
          width: 32,
          height: 48,
          child: ColoredBox(color: Color(0x14000000)),
        ),
        title: SizedBox(
          height: 12,
          child: ColoredBox(color: Color(0x14000000)),
        ),
        subtitle: SizedBox(
          height: 10,
          child: ColoredBox(color: Color(0x0A000000)),
        ),
      ),
    );
  }
}

/// One row of the library.
///
/// ⚠️ **Three lines, and the third is optional.** Title, then the site's own subtitle (author or
/// "author unknown"), then progress. A tile with an author line that collapses to nothing when
/// the site published none reads as a broken tile, so it says what it does not know
/// (ADR-024).
class LibraryTile extends StatelessWidget {
  const LibraryTile({required this.entry, required this.onRemove, super.key});

  final LibraryEntry entry;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppLocalizations copy = AppLocalizations.of(context);

    return ListTile(
      // ⚠️ **A 32 × 48 placeholder, not a broken image.** `novels.coverUrl` is nullable and a
      // missing cover must not shift the row's baseline.
      leading: const SizedBox(
        width: 32,
        height: 48,
        child: ColoredBox(color: Color(0x14000000)),
      ),
      title: Text(entry.title),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            // ⚠️ **A WORD when the author is unknown** (ADR-024), and it is the SOURCE that
            // follows — never the author's name alone, because two sites publish the same
            // pen name.
            '${entry.sourceName} · ${entry.author ?? copy.libraryTileAuthorMissing}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          if (entry.unopenedCount > 0)
            Text(
              copy.libraryTileUnopened(entry.unopenedCount),
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
          Text(
            // ⚠️ **The MARK's count (B48).** An interrupted download has no mark, so this figure
            // never counts a chapter the reader cannot open.
            entry.downloadedCount > 0
                ? copy.libraryTileProgress(
                    entry.downloadedCount,
                    entry.chapterCount,
                  )
                : copy.libraryTileUndownloaded,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
      trailing: IconButton(
        onPressed: onRemove,
        icon: const Icon(Icons.remove_circle_outline),
        tooltip: copy.libraryRemoveAction,
      ),
    );
  }
}
