// Lumen Tale — the library's five sorts and four facets, as state and as pure functions.
//
// `6-6` § 3.1 and `library.md` § 11.1. Pure logic, no Flutter import; the screen reads the
// providers and the widget renders them.
//
// ## ⚠️ THE FIVE SORTS ARE FIVE LOCAL FACTS, AND FOUR CONTROLS ARE NOT OFFERED
//
// ```text
// lastRead  reading_positions.updated_at DESC     recentlyAdded  novels.added_at DESC
// title     novels.title A→Z                      unopened       COUNT(is_read = 0) DESC
// site      novels.source_id, then title
// ```
//
// ⚠️ **NO SORT BY AUTHOR**, for exactly the reason there is no search by author: ADR-024
// makes it a decorated field, and a sort key is a search key wearing a different hat.
// ⚠️ **NO *Completed* FILTER** — B39's note records that the completed state was removed
// from the check because no rule, story or glossary entry defined it, and a filter over a
// state the product does not have is a control that lies.
//
// ## ⚠️ `site` IS THE ONE FACET THAT CARRIES A VALUE
//
// Downloaded / Not downloaded / Has unopened are flags a chip can toggle. "Site" cannot be —
// a chip labelled *Site* with no chosen site filters nothing, which is the sheet's *Empty*
// state pretending to be a choice. So it carries a `String?` and opens a picker over the
// sites actually present in the library, named from [LibraryRow.sourceName] rather than from
// an ARB key: a site's name is data (`ADR-013`), and inventing an ARB key per site would
// make the l10n bundle a second source registry.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lumen_tale/data/library/library_providers.dart';
import 'package:lumen_tale/domain/library/library_row.dart';

/// `library.md` § 11.1's five `RadioRow`s, in that order.
enum LibrarySort {
  /// By `MAX(reading_positions.updated_at)`, most recent first.
  lastRead,

  /// By `novels.added_at`, most recent first.
  recentlyAdded,

  /// By title, A→Z.
  title,

  /// By unopened count, most first.
  unopened,

  /// By site, then by title inside a site.
  site,
}

/// `library.md` § 11.1's four `FilterChip`s.
enum LibraryFacet {
  /// Only novels with at least one downloaded chapter.
  downloaded,

  /// Only novels with none.
  notDownloaded,

  /// Only novels with at least one unopened chapter.
  hasUnopened,

  /// Only novels from one site. **Carries a value** — see [LibraryFacets.siteName].
  site,
}

/// The active facets.
///
/// ⚠️ **`downloaded` and `notDownloaded` are stored independently and NOT made mutually
/// exclusive.** A toggle that clears the other would be a control that silently edits a
/// choice the reader made, and the reader can see the result either way. The *count* of
/// active facets is what the empty state reports, and it counts what is on.
final class LibraryFacets {
  const LibraryFacets({this.flags = const <LibraryFacet>{}, this.siteName});

  static const LibraryFacets none = LibraryFacets();

  final Set<LibraryFacet> flags;

  /// The chosen site, by **display name** — see this file's header on why the name and not
  /// an id: the row carries a name, and resolving an id back would need the registry in the
  /// filter layer for no gain the reader could see.
  final String? siteName;

  bool has(LibraryFacet facet) => flags.contains(facet);

  /// ⚠️ **What the empty state reports.** [LibraryFacet.site] counts as **one** facet
  /// whether it is on or off, so a reader who turned two flags on and chose a site sees
  /// *3 filters on* and not *4* — the number of things to undo, which is what the sentence
  /// is for.
  int get activeCount =>
      flags.length +
      (siteName == null ? 0 : 1) +
      // ⚠️ `site` may sit in [flags] only as a marker that the picker is open, so it is
      // counted once: `flags` excludes it, and this branch keeps the two paths from
      // disagreeing if a future caller adds it.
      (flags.contains(LibraryFacet.site) && siteName != null ? -1 : 0);

  bool get isActive => activeCount > 0;

  LibraryFacets toggle(LibraryFacet facet) {
    if (facet == LibraryFacet.site) {
      // ⚠️ **Tapping the Site chip again clears the choice.** Every chip on this sheet
      // toggles, and a chip that only opens a picker would be a control that cannot be
      // undone from where it was made.
      return siteName == null ? this : LibraryFacets.none;
    }
    final Set<LibraryFacet> next = Set<LibraryFacet>.of(flags);
    if (!next.remove(facet)) {
      next.add(facet);
    }
    return LibraryFacets(flags: next, siteName: siteName);
  }

  LibraryFacets choosingSite(String? name) =>
      LibraryFacets(flags: flags, siteName: name);

  @override
  bool operator ==(Object other) =>
      other is LibraryFacets &&
      other.siteName == siteName &&
      other.flags.length == flags.length &&
      other.flags.containsAll(flags);

  @override
  int get hashCode => Object.hash(Object.hashAllUnordered(flags), siteName);

  @override
  String toString() => 'LibraryFacets($flags, site: $siteName)';
}

/// § 5: the sort and the facets are **session** state.
///
/// ⚠️ **`autoDispose` here and NOT `shared_preferences`, and that is a recorded gap rather
/// than a decision.** `library.md` § 11.1 persists them so a reader who always sorts by
/// *Unopened chapters* finds it that way tomorrow. No acceptance criterion in `6-6` § 10
/// covers persistence, and writing them before the filter layer exists would be a
/// preference store whose write path no screen exercises. When it is wired, it is
/// `shared_preferences` and the shape below does not change — it is already a value with
/// equality, which is all a store needs.
final librarySortProvider = NotifierProvider<LibrarySortNotifier, LibrarySort>(
  LibrarySortNotifier.new,
);

class LibrarySortNotifier extends Notifier<LibrarySort> {
  @override
  LibrarySort build() => LibrarySort.lastRead;

  void choose(LibrarySort sort) => state = sort;
}

final libraryFacetsProvider =
    NotifierProvider<LibraryFacetsNotifier, LibraryFacets>(
      LibraryFacetsNotifier.new,
    );

class LibraryFacetsNotifier extends Notifier<LibraryFacets> {
  @override
  LibraryFacets build() => LibraryFacets.none;

  void toggle(LibraryFacet facet) => state = state.toggle(facet);

  void chooseSite(String? name) => state = state.choosingSite(name);

  /// § 11.1's `ActionsRow`. **Disabled when nothing is set** — the sheet is never empty,
  /// and *no facet selected* means no filtering.
  void clearAll() => state = LibraryFacets.none;
}

/// The sites the *library* holds, by display name — the `Site` facet's picker.
///
/// ⚠️ **DERIVED FROM THE ROWS AND NOT FROM THE REGISTRY.** A picker offering every
/// compiled source would let a reader switch on a filter that empties the list, and
/// *nothing here* with a chip lit is exactly the state `library.md` § 4 says this app is
/// most often wrong about. The registry is the authority for what a site *is*
/// (`library_rows_repository.dart` resolves the names); this only reports which of them
/// the reader actually keeps novels from.
final librarySiteNamesProvider = Provider<AsyncValue<List<String>>>((Ref ref) {
  return ref
      .watch(libraryRowsStreamProvider)
      .whenData(
        (List<LibraryRow> rows) => <String>{
          for (final LibraryRow row in rows) row.sourceName,
        }.toList(),
      );
});

/// ⚠️ **The filters run FIRST and the query second, and that is `(filters) AND (title)`.**
///
/// `library.md` § 5 states it, and the order matters for the count the helper text shows:
/// filtering after the title match would report a different list length than the filter
/// implies, and two numbers on one page disagreeing is B22 in another costume.
///
/// ⚠️ **Facet filtering is over a list already in hand.** It is pure and in memory, which
/// is what keeps it testable without a database: the search is the only query here, and it
/// is title-only (B45) because that is the only thing B45 permits to be a query.
List<LibraryRow> applyFacets(List<LibraryRow> rows, LibraryFacets facets) {
  if (!facets.isActive) {
    return rows;
  }
  return <LibraryRow>[
    for (final LibraryRow row in rows)
      if (_passesFacets(row, facets)) row,
  ];
}

bool _passesFacets(LibraryRow row, LibraryFacets facets) {
  if (facets.has(LibraryFacet.downloaded) && row.downloadedCount <= 0) {
    return false;
  }
  if (facets.has(LibraryFacet.notDownloaded) && row.downloadedCount > 0) {
    return false;
  }
  if (facets.has(LibraryFacet.hasUnopened) && row.unopenedCount <= 0) {
    return false;
  }
  // ⚠️ **By NAME and never by id.** The row carries the display name (`ADR-013`) and the
  // picker offers exactly those names, so comparing them cannot drift on a registry
  // rebuild. Two rows from two sites are never collapsed here either.
  if (facets.siteName != null && row.sourceName != facets.siteName) {
    return false;
  }
  return true;
}

/// The five orders of § 3.1, applied to a list already filtered.
///
/// ⚠️ **EVERY COMPARATOR ENDS WITH `novelId`.** Without a final tiebreak two novels with
/// equal counts swap between rebuilds and the list flickers — the same defect `6-3` named
/// in its `ORDER BY`, and the fix is not optional just because it is invisible most of the
/// time.
List<LibraryRow> applySort(List<LibraryRow> rows, LibrarySort sort) {
  final List<LibraryRow> sorted = List<LibraryRow>.of(rows);
  sorted.sort((LibraryRow a, LibraryRow b) => _compare(a, b, sort));
  return sorted;
}

int _compare(LibraryRow a, LibraryRow b, LibrarySort sort) {
  final int primary = switch (sort) {
    // ⚠️ **NULLS LAST, on every timestamp.** A novel never read and a novel never added is
    // not "the oldest": it is *unknown*, and putting it at the top of "Last read" would
    // claim the reader read it first.
    LibrarySort.lastRead => _byNullableDesc(a.lastReadAt, b.lastReadAt),
    LibrarySort.recentlyAdded => _byNullableDesc(a.addedAt, b.addedAt),
    LibrarySort.title => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
    LibrarySort.unopened => b.unopenedCount.compareTo(a.unopenedCount),
    // ⚠️ **Site THEN title.** One sort key per facet would group every novel of a site
    // together arbitrarily, which is not a site sort at all.
    LibrarySort.site => _chained(<int>[
      a.sourceName.compareTo(b.sourceName),
      _compare(a, b, LibrarySort.title),
    ]),
  };
  return primary != 0 ? primary : a.novelId.compareTo(b.novelId);
}

/// Descending on a nullable instant, **absent values last**.
int _byNullableDesc(DateTime? a, DateTime? b) {
  if (a == null && b == null) return 0;
  if (a == null) return 1;
  if (b == null) return -1;
  return b.compareTo(a);
}

/// The first non-zero comparison, so a sort can say "by X, then by Y" in one line.
int _chained(List<int> comparisons) {
  for (final int value in comparisons) {
    if (value != 0) {
      return value;
    }
  }
  return 0;
}
