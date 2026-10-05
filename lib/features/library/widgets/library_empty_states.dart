// Lumen Tale — the library's THREE empty states, and why they are three.
//
// `6-6` § 4.3 / `library.md` § 4. `features/library/widgets/`.
//
// ## ⚠️ *"Nothing here" WITHOUT A CAUSE IS THE STATE THIS APP IS MOST OFTEN WRONG ABOUT*
//
// There are three ways this list can be empty, they need three different sentences, and
// three different buttons:
//
// | state | sentence | button |
// |---|---|---|
// | never visited | *Your library is empty* | **Browse a source** → `/browse` |
// | a query matched nothing | *No kept novel matches "vow"* | **Clear search** |
// | filters excluded everything | *No kept novel is downloaded* | **Clear filters** (+ how many were on) |
//
// Rendering them with one `EmptyState` would make a reader who has 200 novels and typed
// *vow* believe they had none.
//
// ## ⚠️ THE WORDS *"0 results"* ARE **FORBIDDEN** HERE, AND THIS FILE IS WHY
//
// B22/E19's *no results* register belongs to a **site** query that failed. The library is
// local: it has no site to have lost, and a message phrased as a query failure would tell
// the reader their answer came from somewhere it did not.

import 'package:flutter/material.dart';

import 'package:lumen_tale/app/theme/lumen_spacing.dart';
import 'package:lumen_tale/l10n/generated/app_localizations.dart';

/// Which of the three empty states this is. An enum, because "empty" alone cannot choose.
enum LibraryEmptyReason {
  /// Nothing has ever been kept. B12 makes this the honest first-run state: the app
  /// cannot arrive at a non-empty library by itself.
  neverVisited,

  /// The library has novels and the **title query** matched none of them.
  noQueryMatch,

  /// The library has novels and the **facets** excluded all of them.
  noFacetMatch,
}

/// The sentence and the one button.
class LibraryEmptyState extends StatelessWidget {
  const LibraryEmptyState({
    required this.reason,
    required this.query,
    required this.activeFacetCount,
    required this.onBrowse,
    required this.onClearQuery,
    required this.onClearFacets,
    super.key,
  });

  final LibraryEmptyReason reason;

  /// ⚠️ **The RAW text the reader typed**, quoted back in the sentence — not the escaped
  /// needle and not the lowercased key. *No kept novel matches "vow"* is them quoting the
  /// reader; *No kept novel matches "%vow%"* is them reading SQL.
  final String query;

  final int activeFacetCount;

  final VoidCallback onBrowse;
  final VoidCallback onClearQuery;
  final VoidCallback onClearFacets;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppLocalizations copy = AppLocalizations.of(context);
    final LumenSpacing spacing = LumenSpacing.of(context);

    final String title = switch (reason) {
      LibraryEmptyReason.neverVisited => copy.libraryEmptyTitle,
      LibraryEmptyReason.noQueryMatch => copy.librarySearchNoMatchTitle(query),
      LibraryEmptyReason.noFacetMatch => copy.libraryNoDataTitle,
    };
    final String body = switch (reason) {
      LibraryEmptyReason.neverVisited => copy.libraryEmptyBody,
      // ⚠️ **A query that matched nothing needs NO second paragraph.** The sentence already
      // named the query, and adding "try another search" would be advice on a screen whose
      // one job is to say what happened.
      LibraryEmptyReason.noQueryMatch || LibraryEmptyReason.noFacetMatch => '',
    };

    final (String label, VoidCallback action) = switch (reason) {
      LibraryEmptyReason.neverVisited => (
        copy.libraryEmptyBrowseAction,
        onBrowse,
      ),
      LibraryEmptyReason.noQueryMatch => (
        copy.librarySearchClearAction,
        onClearQuery,
      ),
      // ⚠️ **THE BUTTON REPORTS HOW MANY FACETS WERE ON**, per `library.md` § 4: *Clear
      // filters, which also reports how many facets were active*. A reader who cannot tell
      // how much they narrowed has to clear twice to find out.
      LibraryEmptyReason.noFacetMatch => (
        '$activeFacetCount · ${copy.libraryNoDataClearFilters}',
        onClearFacets,
      ),
    };

    return Center(
      child: Padding(
        padding: EdgeInsets.all(spacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            // ⚠️ **NO ILLUSTRATION AND NO ICON IN A CIRCLE.** `library.md` § 2.1 names that
            // as one of this screen's anti-generic defects: the empty state is a sentence
            // and one button.
            Text(
              title,
              textAlign: TextAlign.center,
              key: const Key('library.empty-title'),
              style: theme.textTheme.titleMedium,
            ),
            if (body.isNotEmpty) ...<Widget>[
              SizedBox(height: spacing.sm),
              Text(
                body,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium,
              ),
            ],
            SizedBox(height: spacing.lg),
            // ⚠️ **THE PRIMARY BUTTON LEAVES FOR BROWSE** rather than offering *Add a novel*
            // with no source picker behind it — the library cannot fill itself, so the
            // action that fills it has to go where novels come from (B12).
            FilledButton(
              key: const Key('library.empty-action'),
              onPressed: action,
              child: Text(label),
            ),
          ],
        ),
      ),
    );
  }
}
