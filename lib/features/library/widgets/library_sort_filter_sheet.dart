// Lumen Tale — the library's sort and filter sheet.
//
// `library.md` § 11.1, a **sub-surface of this screen** and not a screen of its own:
// § 11 says the sheet is specified inside `library.md` because a two-facet sheet given its
// own file would owe nine states for a control that renders from the first frame.
//
// ## ⚠️ THE SCOPE LINE IS NOT DECORATION, IT IS B45 WRITTEN WHERE THE FACETS ARE
//
// `library.md` § 2.1: *the filter sheet carries an explicit line saying so.* A reader who
// opens the sheet and does not find an author facet is entitled to think it is elsewhere;
// the sentence *Titles only — the app does not keep authors, genres or descriptions as
// searchable fields* is what turns an absence into a decision.
//
// ## ⚠️ FOUR FACETS, THREE OF WHICH ARE FLAGS AND ONE OF WHICH CARRIES A VALUE
//
// `Downloaded` / `Not downloaded` / `Has unopened chapters` toggle. **Site** cannot: a chip
// labelled *Site* with no chosen site filters nothing, which is the sheet's *Empty* state
// pretending to be a choice — so it opens a picker over the sites **actually present in the
// library**, named from `LibraryRow.sourceName` (a site's name is data, `ADR-013`, and an
// ARB key per site would make the l10n bundle a second source registry).
//
// ## ⚠️ THREE CONTROLS THIS SHEET DOES NOT OFFER, EACH FOR A STATED REASON
//
// | not offered | why |
// |---|---|
// | author / genre / description facets | **B45** — the app does not hold them as searchable fields |
// | **Completed** | B39's note: the completed state was removed from the check because no rule defined it, and a filter over a state the product lacks is a control that lies |
// | sort by reading progress | position is per chapter and never trimmed (B46); a shelf sorted by it is a different claim about the same data |
//
// The absence is asserted by a test that reads the sheet's own source, because "the list of
// facets" is a list a reviewer cannot check by looking at a picture.
//
// ## ⚠️ NO *APPLY*, AND `Clear all` IS **DISABLED** WHEN NOTHING IS SET
//
// § 11.1: *facets apply live… the sheet is never empty.* A button that is enabled and does
// nothing is the interface-hole defect `2-5` documented, so this one is greyed and says so.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:lumen_tale/app/theme/lumen_colors.dart';
import 'package:lumen_tale/app/theme/lumen_radius.dart';
import 'package:lumen_tale/app/theme/lumen_spacing.dart';
import 'package:lumen_tale/app/theme/shadows.dart';
import 'package:lumen_tale/features/library/providers/library_sort_filter.dart';
import 'package:lumen_tale/l10n/generated/app_localizations.dart';

/// Opens the sheet. Facets apply as they are chosen; there is no result to return.
Future<void> showLibrarySortFilterSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    // ⚠️ `backgroundColor: Colors.transparent` because the sheet's own `DecoratedBox`
    // supplies `--color-surface-raised`; a `showModalBottomSheet` default would be a third
    // surface this design system does not have.
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.32),
    builder: (BuildContext context) => const LibrarySortFilterSheet(),
  );
}

class LibrarySortFilterSheet extends ConsumerWidget {
  const LibrarySortFilterSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations copy = AppLocalizations.of(context);
    final LumenColors colors = LumenColors.of(context);
    final LumenSpacing spacing = LumenSpacing.of(context);
    final LumenRadius radius = LumenRadius.of(context);
    final LibrarySort sort = ref.watch(librarySortProvider);
    final LibraryFacets facets = ref.watch(libraryFacetsProvider);

    return DecoratedBox(
      // ⚠️ **`--shadow-sheet` only.** § 1.4 keeps exactly two shadows in this app; the
      // sheet and the dialog are them.
      decoration: BoxDecoration(
        color: colors.surfaceRaised,
        borderRadius: BorderRadius.vertical(top: Radius.circular(radius.lg)),
        boxShadow: LumenShadows.of(context).sheet,
      ),
      child: SafeArea(
        top: false,
        // ⚠️ **A TRANSPARENT `Material` BETWEEN THE `DecoratedBox` AND THE ROWS.** The
        // surface is painted by a `DecoratedBox`, and `ListTile` paints its own background
        // and ink on the *nearest* `Material` ancestor — so without this the selected row's
        // tap ripple and pressed state are invisible, which is exactly the "live-looking
        // control that shows nothing" defect the rest of this sheet is careful about.
        // `SettingsChoiceSheet` solves it the same way.
        child: Material(
          type: MaterialType.transparency,
          child: SingleChildScrollView(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                spacing.lg,
                spacing.md,
                spacing.lg,
                spacing.lg,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  // § 11.1's `DragHandle`, 4dp × 32dp in `--color-border`.
                  Center(
                    child: Container(
                      width: 32,
                      height: 4,
                      margin: EdgeInsets.only(bottom: spacing.md),
                      decoration: BoxDecoration(
                        color: colors.border,
                        borderRadius: radius.fullAll,
                      ),
                    ),
                  ),
                  Text(copy.librarySortTitle, style: _titleOf(context)),
                  SizedBox(height: spacing.sm),
                  // ⚠️ **B45, IN SENTENCES, DIRECTLY ABOVE THE CONTROLS.** See the file header.
                  Text(
                    copy.libraryScopeLine,
                    key: const Key('library.scope-line'),
                    // ⚠️ **THE SHEET IS A *SHEET*, AND `library.md` § 11.1's *320dp* CHECK IS
                    // ABOUT THIS PARAGRAPH.** It wraps rather than ellipsising: a scope line
                    // that truncates has stopped arguing, which is the whole job of it.
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                  SizedBox(height: spacing.lg),
                  Text(copy.libraryFacetGroup, style: _overlineOf(context)),
                  SizedBox(height: spacing.sm),
                  // ⚠️ **A `RadioGroup` ANCESTOR AND NOT FIVE `groupValue`s.** Flutter 3.47
                  // deprecated `RadioListTile.groupValue`/`onChanged`, and the replacement is
                  // not cosmetic: `RadioGroup` also supplies the **arrow-key navigation and
                  // the `inMutuallyExclusiveGroup` semantics** § 2.12 asks of a radio row.
                  RadioGroup<LibrarySort>(
                    groupValue: sort,
                    onChanged: (LibrarySort? chosen) {
                      if (chosen != null) {
                        ref.read(librarySortProvider.notifier).choose(chosen);
                      }
                    },
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        for (final ({LibrarySort sort, String label}) option
                            in _sortOptions(copy))
                          // ⚠️ **A `RadioListTile` AND NOT A `Chip`:** these are **mutually
                          // exclusive** orders, and the group above is what tells a screen
                          // reader so. Five chips would read as five independent switches.
                          RadioListTile<LibrarySort>(
                            key: Key('library.sort.${option.sort.name}'),
                            value: option.sort,
                            title: Text(
                              option.label,
                              // ⚠️ **48dp MINIMUM ROW, and a `ListTile` is 48 by
                              // default.** C11: a one-handed, often-glanced control.
                              style: Theme.of(context).textTheme.bodyLarge,
                            ),
                            contentPadding: EdgeInsets.zero,
                          ),
                      ],
                    ),
                  ),
                  Divider(height: spacing.xl),
                  Text(copy.libraryFacetGroup, style: _overlineOf(context)),
                  SizedBox(height: spacing.sm),
                  _facetChip(
                    context,
                    ref,
                    copy,
                    facet: LibraryFacet.downloaded,
                    label: copy.libraryFacetDownloaded,
                  ),
                  _facetChip(
                    context,
                    ref,
                    copy,
                    facet: LibraryFacet.notDownloaded,
                    label: copy.libraryFacetNotDownloaded,
                  ),
                  _facetChip(
                    context,
                    ref,
                    copy,
                    facet: LibraryFacet.hasUnopened,
                    label: copy.libraryFacetHasUnopened,
                  ),
                  // ⚠️ **THE FOURTH FACET, AND IT IS A CHIP BECAUSE IT CARRIES A VALUE.**
                  // See the file header: a *Site* chip with no chosen site filters nothing.
                  _facetChip(
                    context,
                    ref,
                    copy,
                    facet: LibraryFacet.site,
                    label: copy.libraryFacetSite,
                  ),
                  SizedBox(height: spacing.lg),
                  Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: TextButton(
                      key: const Key('library.clear-filters'),
                      // ⚠️ **DISABLED, NOT HIDDEN, AND NOT A NO-OP.** § 11.1: *`Clear all` is
                      // disabled with the wording "No filters applied"*. A live-looking
                      // button that does nothing is the defect `2-5` documented for the
                      // un-wired check button.
                      onPressed: facets.isActive
                          ? () => ref
                                .read(libraryFacetsProvider.notifier)
                                .clearAll()
                          : null,
                      child: Text(
                        facets.isActive
                            ? copy.libraryFilterCount(facets.activeCount)
                            : copy.libraryNoDataTitle,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _facetChip(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations copy, {
    required LibraryFacet facet,
    required String label,
  }) {
    final LibraryFacets facets = ref.watch(libraryFacetsProvider);
    final bool on = facet == LibraryFacet.site
        ? facets.siteName != null
        : facets.has(facet);
    return Padding(
      padding: EdgeInsets.only(bottom: LumenSpacing.of(context).xs),
      child: FilterChip(
        key: Key('library.facet.${facet.name}'),
        label: Text(label),
        selected: on,
        // ⚠️ **TAPPING THE SITE CHIP OPENS A PICKER**, because the value is a site and not
        // a boolean. Tapping it again clears the choice — `LibraryFacets.toggle` says so,
        // so the two gestures are one behaviour rather than two rules.
        onSelected: facet == LibraryFacet.site
            ? (bool _) => _pickSite(context, ref, copy)
            : (bool _) =>
                  ref.read(libraryFacetsProvider.notifier).toggle(facet),
      ),
    );
  }

  /// The site picker — a dialog, because it is a question with one answer, not a view.
  Future<void> _pickSite(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations copy,
  ) async {
    // ⚠️ **ONLY THE SITES PRESENT IN THE LIBRARY.** Listing every compiled source would
    // offer a filter that empties the screen, and an empty screen with a chip lit is the
    // state `library.md` § 4 says this app is most often wrong about.
    final List<String> sites =
        ref.watch(librarySiteNamesProvider).asData?.value.toList() ??
        const <String>[];
    sites.sort();
    final String? chosen = await showDialog<String?>(
      context: context,
      builder: (BuildContext context) => SimpleDialog(
        title: Text(copy.libraryFacetSite),
        children: <Widget>[
          for (final String site in sites)
            SimpleDialogOption(
              key: Key('library.site.$site'),
              onPressed: () => Navigator.of(context).pop(site),
              child: Text(site),
            ),
          SimpleDialogOption(
            key: const Key('library.site.none'),
            onPressed: () => Navigator.of(context).pop(),
            child: Text(copy.librarySearchClearAction),
          ),
        ],
      ),
    );
    ref.read(libraryFacetsProvider.notifier).chooseSite(chosen);
  }

  /// § 11.1's five `RadioRow`s, in the order the design draws them.
  ///
  /// ⚠️ **THE LIST LIVES HERE AND NOT IN THE ENUM'S DOC, so a sixth key is a visible edit
  /// rather than an enum member nobody notices.** `09-widgets-ui.md` rule 2: the control
  /// renders from the first frame because the facets are local enums — there is no loading
  /// state here and a skeleton would be theatre.
  static List<({LibrarySort sort, String label})> _sortOptions(
    AppLocalizations copy,
  ) => <({LibrarySort sort, String label})>[
    (sort: LibrarySort.lastRead, label: copy.librarySortLastRead),
    (sort: LibrarySort.recentlyAdded, label: copy.librarySortRecentlyAdded),
    (sort: LibrarySort.title, label: copy.librarySortTitleAz),
    (sort: LibrarySort.unopened, label: copy.librarySortUnopened),
    (sort: LibrarySort.site, label: copy.librarySortSite),
  ];

  TextStyle? _titleOf(BuildContext context) =>
      Theme.of(context).textTheme.titleLarge;

  /// § 1.2's overline: 11/16 at 600 with 0.08em tracking. `TextTheme` has no overline role
  /// in Material 3, so this is the one place the design's scale is spelled out — and it is
  /// spelled out as a *copyWith* of an existing role rather than as a raw `fontSize`.
  TextStyle? _overlineOf(BuildContext context) => Theme.of(context)
      .textTheme
      .labelSmall
      ?.copyWith(fontWeight: FontWeight.w600, letterSpacing: 0.08);
}
