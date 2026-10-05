// Lumen Tale — the library screen: search, sort/filter, the rows, and the removal dialog.
//
// `2-5` built the list; `6-6` **adds three things to it** and does not rebuild it:
// the title-only search (B45), the unopened badge (B14) with the stopped-download wording
// (E6/E7), and the sort/filter sheet.
//
// ## ⚠️ THE ROWS COME FROM [libraryRowsStreamProvider], NOT [libraryStreamProvider]
//
// The two disagree about `unopenedCount` and neither could be moved: `2-5`'s is *unread
// among downloaded*, `6-6` § 3.2's is `COUNT(is_read = 0)` over every chapter — which is
// `6-3`'s number and B14's sentence. `library_row.dart` says why. The screen reads the one
// that matches the badge the plan specifies, and `2-5`'s stream keeps its other two
// consumers (`novel_details`, `source_unavailable`).
//
// ## ⚠️ The row streams are `keepAlive`, and that is a stated rule
//
// `05-state-management.md` rule 10 names the library among the `keepAlive` cases: it is the
// first-rank destination (ADR-018), so it must survive a tab change and a round trip.
//
// ## ⚠️ Nothing here fetches
//
// The rows come from the local database. The only thing that reaches a site is "check for
// new chapters", which belongs to `6-4` and stays **disabled and labelled** here — a
// button that looks live and does nothing is worse than a labelled slot that says which
// slice owns it, and `2-5`'s test greps this file for `onPressed: null` so the claim is
// checked rather than believed.
//
// ## ⚠️ THE REMOVE BUTTON IS PER ROW, AND THAT IS A DEVIATION FROM `library.md` § 3
//
// The design puts Remove on the `SelectionActionBar` reached by a long-press, and says a
// row carries **no** action of its own. The bar is `5-1`'s — it is already written for the
// chapter list — and building a second selection machine for one button is the sort of
// duplication `09-widgets-ui.md` rule 2 forbids. So the button `2-5` shipped stays, and
// when the selection bar lands it replaces this slot rather than sitting beside it.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:lumen_tale/app/router/app_routes.dart';
import 'package:lumen_tale/core/ui/app_scaffold.dart';
import 'package:lumen_tale/core/ui/library_dialogs.dart';
import 'package:lumen_tale/data/library/library_providers.dart';
import 'package:lumen_tale/domain/library/library_repository.dart';
import 'package:lumen_tale/domain/library/library_row.dart';
import 'package:lumen_tale/domain/library/library_search.dart';
import 'package:lumen_tale/features/library/providers/library_query.dart';
import 'package:lumen_tale/features/library/providers/library_rows.dart';
import 'package:lumen_tale/features/library/providers/library_sort_filter.dart';
import 'package:lumen_tale/features/library/widgets/library_empty_states.dart';
import 'package:lumen_tale/features/library/widgets/library_novel_row.dart';
import 'package:lumen_tale/features/library/widgets/library_search_field.dart';
import 'package:lumen_tale/features/library/widgets/library_sort_filter_sheet.dart';
import 'package:lumen_tale/l10n/generated/app_localizations.dart';

/// `/library` — the reader's own novels, offline.
class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

/// ⚠️ **`StatefulWidget` FOR THE FIELD'S OWN CONTROLLER AND NOTHING ELSE.** The business
/// state — the query, the sort, the facets — is in three providers, because
/// `05-state-management.md` rule 9 allows local state only when it is ephemeral, and a
/// `TextEditingController` is. Putting the query here instead would make it die with the
/// widget, which is what the shell branch exists to prevent (`library.md` § 5: *This branch
/// keeps its scroll offset and its query*).
class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  final TextEditingController _query = TextEditingController();

  /// The search field's own visibility. **Ephemeral** — the query survives a tab change,
  /// the open/closed field is a gesture that belongs to this instance.
  bool _searching = false;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  /// ⚠️ **`keepFilter: false` IS *X* AND *Clear search*; `true` IS SUBMIT.** § 5: *Submit
  /// closes the field keeping the filter; `X` clears it.* Two gestures, two promises, and
  /// neither writes anything — the query is memory.
  void _closeSearch({required bool keepFilter}) {
    if (!keepFilter) {
      ref.read(libraryQueryProvider.notifier).clear();
      _query.clear();
    }
    setState(() => _searching = false);
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations copy = AppLocalizations.of(context);
    final AsyncValue<List<LibraryRow>> rows = ref.watch(libraryRowsProvider);
    final TitleSearch query = ref.watch(libraryQueryProvider);

    return AppScaffold(
      titleBar: AppBar(
        title: Text(copy.libraryTitle),
        actions: <Widget>[
          // ⚠️ **A TOOLTIP NAMING THE SCOPE, not a bare glyph.** § 5: a bare refresh glyph
          // says "reload my own data", and a search glyph next to a check glyph is a puzzle
          // for anyone who meets the app once. The tooltip is *Search by title* — B45 in the
          // place the reader's finger lands.
          IconButton(
            key: const Key('library.search-button'),
            icon: const Icon(Icons.search),
            tooltip: copy.librarySearchHint,
            onPressed: () => setState(() => _searching = true),
          ),
          IconButton(
            key: const Key('library.sort-button'),
            icon: const Icon(Icons.tune),
            tooltip: copy.librarySortTitle,
            onPressed: () => showLibrarySortFilterSheet(context),
          ),
          // ⚠️ **DISABLED, NOT ABSENT AND NOT LIVE**, and an **`IconButton` with a
          // tooltip** rather than `2-5`'s `TextButton`. Three labelled actions do not fit
          // a 360dp app bar — the first version overflowed by 132px the moment the label
          // was the honest *Check for new chapters*. § 5 asks the control to "carry the
          // label, not a bare refresh glyph", and a tooltip **is** that label: it is what a
          // long-press shows and what a screen reader announces, so the glyph is never the
          // only thing there. `6-4` wires the tap.
          IconButton(
            key: const Key('library.check-button'),
            icon: const Icon(Icons.refresh),
            tooltip: copy.checkNowAction,
            onPressed: null,
          ),
        ],
      ),
      content: Column(
        children: <Widget>[
          if (_searching)
            LibrarySearchField(
              controller: _query,
              // ⚠️ **THE COUNT IS THE LIST'S OWN LENGTH.** § 3.1 branch 11: the helper
              // text and the list must say the same thing, so this is passed rather than
              // counted again here.
              resultCount: rows.asData?.value.length ?? 0,
              onChanged: ref.read(libraryQueryProvider.notifier).setQuery,
              onCleared: () => _closeSearch(keepFilter: false),
              onSubmitted: () => _closeSearch(keepFilter: true),
            ),
          Expanded(
            child: switch (rows) {
              AsyncData<List<LibraryRow>>(value: final List<LibraryRow> list) =>
                _body(context, ref, copy, list, query),
              AsyncError<List<LibraryRow>>(error: final Object _) => _loadError(
                context,
                ref,
                copy,
              ),
              _ => _loading(),
            },
          ),
        ],
      ),
    );
  }

  Widget _body(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations copy,
    List<LibraryRow> rows,
    TitleSearch query,
  ) {
    final LibraryFacets facets = ref.watch(libraryFacetsProvider);

    if (rows.isEmpty) {
      return LibraryEmptyState(
        reason: _reasonFor(query, facets),
        query: query.raw,
        activeFacetCount: facets.activeCount,
        onBrowse: () => GoRouter.of(context).go(AppRoutes.browse),
        onClearQuery: () => ref.read(libraryQueryProvider.notifier).clear(),
        onClearFacets: () =>
            ref.read(libraryFacetsProvider.notifier).clearAll(),
      );
    }

    return ListView.separated(
      // ⚠️ **Keyed by id, not by index.** A removal above reindexes every row below it, and
      // an index key would make Flutter reuse the wrong tile's state — which on a removal
      // dialog means the next tap opens the wrong novel's dialog.
      key: const ValueKey<String>('library-list'),
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: rows.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (BuildContext context, int index) {
        final LibraryRow row = rows[index];
        return LibraryNovelRow(
          key: ValueKey<String>(row.novelId),
          row: row,
          onTap: () =>
              GoRouter.of(context).go(AppRoutes.novelDetailsFor(row.novelId)),
          onRemove: () => _confirmRemoval(context, ref, copy, row),
        );
      },
    );
  }

  /// § 4.3's decision table: which of the three empties this is.
  ///
  /// ⚠️ **A SEARCH IS REPORTED FIRST**, because it is the narrower of the two narrowings a
  /// reader applied; "you have never kept anything" is reported only when neither a query
  /// nor a facet is narrowing anything, because that is the only case where the library
  /// itself is the reason.
  static LibraryEmptyReason _reasonFor(
    TitleSearch query,
    LibraryFacets facets,
  ) {
    if (!query.isEmpty) return LibraryEmptyReason.noQueryMatch;
    if (facets.isActive) return LibraryEmptyReason.noFacetMatch;
    return LibraryEmptyReason.neverVisited;
  }

  /// B32's dialog, and its body is where C8's reassurance lives.
  Future<void> _confirmRemoval(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations copy,
    LibraryRow row,
  ) async {
    final LibraryRepository repository = ref.read(libraryRepositoryProvider);

    // ⚠️ **The count is asked for BEFORE the confirmation**, so the number in the dialog is
    // one the reader could check. Asking afterwards would mean writing first and explaining
    // later.
    final int downloaded = await repository.countDownloadedChapters(
      row.novelId,
    );
    if (!context.mounted) {
      return;
    }

    final bool confirmed = await ConfirmDialog.ask(
      context,
      title: copy.libraryRemoveTitle,
      body: copy.libraryRemoveBody(downloaded, row.title),
      confirmLabel: copy.libraryRemoveAction,
      isDestructive: true,
    );
    if (!confirmed || !context.mounted) {
      return;
    }

    // ⚠️ **`removeFromLibrary` returns the count it read before the write**, and the
    // message says what survived. B32 is a promise the reader can see rather than a rule
    // they must trust.
    await ref.read(removeFromLibraryProvider)(row.novelId);
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(copy.libraryRemoveKept)));
  }

  /// ⚠️ **A SKELETON IN THE SHAPE OF A ROW, and never a spinner.** A spinner over a list
  /// implies a wait of unknown length; a skeleton implies the shape of what is arriving.
  Widget _loading() {
    return ListView.builder(
      itemCount: 6,
      itemBuilder: (BuildContext context, int index) => const SizedBox(
        height: LibraryNovelRow.height,
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: <Widget>[
              SizedBox(
                width: LibraryNovelRow.coverSize,
                height: LibraryNovelRow.coverSize,
                child: ColoredBox(color: Color(0x14000000)),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    SizedBox(
                      height: 12,
                      child: ColoredBox(color: Color(0x14000000)),
                    ),
                    SizedBox(height: 8),
                    SizedBox(
                      height: 10,
                      child: ColoredBox(color: Color(0x0A000000)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// ⚠️ **B24 — the sentence names what FAILED AND WHAT STILL WORKS.** A library read
  /// failure is a storage failure, and "something went wrong" tells the reader nothing they
  /// can act on; *your downloaded chapters are still on this phone* is a promise they can
  /// check.
  Widget _loadError(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations copy,
  ) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              copy.libraryLoadErrorTitle,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              copy.libraryLoadErrorBody,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            // ⚠️ **Retry, not dismissal.** § 4: *this is a storage failure, so the sentence
            // promises the thing that survives it* — which only makes sense next to a
            // control that tries again.
            TextButton(
              onPressed: () => ref.invalidate(libraryRowsStreamProvider),
              child: Text(copy.commonRetry),
            ),
          ],
        ),
      ),
    );
  }
}
