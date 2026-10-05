// Lumen Tale — the library, as the screen reads it: search ∘ facets ∘ sort.
//
// `6-6` § 4.2. `features/library/providers/` — screen-scoped, so nothing else may read it
// (`05-state-management.md` rule 10).
//
// ## ⚠️ THE SEARCH RUNS IN SQL AND THE FILTERS RUN IN DART, AND THE SPLIT IS THE POINT
//
// ```text
// query  →  titleSearchSql   →  a set of NOVEL IDS          (B45 — one column, SQLite)
// facets →  applyFacets      →  a subset of LibraryRow      (local fields, testable)
// sort   →  applySort        →  an order
// ```
//
// The counts come from **one** aggregate ([libraryRowsStreamProvider]) and are never
// recomputed here, so the badge on screen is the number SQL counted rather than a second
// number derived beside it. Running the title query in SQLite is not an optimisation: B45
// is a claim about which column is *capable* of being searched, and `idx_novels_title`
// existing while `author` and `description` have no index is half of the promise. The
// other half — that a query present only in the author returns nothing — is only provable
// against a real `LIKE`.
//
// ## ⚠️ AN EMPTY QUERY DOES NOT REACH SQL AT ALL
//
// § 3.1 branch 1: an empty query renders the **whole** library. Asking SQLite for
// `LIKE '%%'` would return it too, through a second code path, and the branch would then
// exist in two places — and the one that is harder to see is the one a reader hits.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lumen_tale/data/library/library_providers.dart';
import 'package:lumen_tale/domain/library/library_row.dart';
import 'package:lumen_tale/domain/library/library_search.dart';
import 'package:lumen_tale/features/library/providers/library_query.dart';
import 'package:lumen_tale/features/library/providers/library_sort_filter.dart';

/// The ids a **non-empty** query matches. **`autoDispose.family`**, and the key is the
/// value itself.
///
/// ⚠️ **`TitleSearch` has `==`/`hashCode` for this and only this.** A family keyed by an
/// object with identity equality would re-open the database stream on every rebuild of the
/// query object — which, because `setQuery` runs per keystroke, means per keystroke.
final _matchingIdsProvider = StreamProvider.autoDispose
    .family<List<String>, TitleSearch>((Ref ref, TitleSearch query) {
      return ref
          .watch(libraryRowsRepositoryProvider)
          .watchMatchingNovelIds(query);
    });

/// The library as this screen draws it.
final libraryRowsProvider = Provider<AsyncValue<List<LibraryRow>>>((Ref ref) {
  final AsyncValue<List<LibraryRow>> all = ref.watch(libraryRowsStreamProvider);
  final TitleSearch query = ref.watch(libraryQueryProvider);
  final LibraryFacets facets = ref.watch(libraryFacetsProvider);
  final LibrarySort sort = ref.watch(librarySortProvider);

  // ⚠️ **THE EMPTY QUERY NEVER CREATES A FAMILY ENTRY.** `AutoDisposeFamily` would keep the
  // key alive for the frame it was created in, and a `LIKE '%%'` result would be a second
  // answer to "what does an empty query render" that nothing tests.
  final AsyncValue<List<String>> matches = query.isEmpty
      ? const AsyncData<List<String>>(<String>[])
      : ref.watch(_matchingIdsProvider(query));

  // ⚠️ **THE SEARCH'S FAILURE IS NOT SWALLOWED BY THE ROWS' SUCCESS.** Two nested `when`
  // calls would have to say which error wins; the answer is "either — both are the same
  // state to the reader", and saying it once is what these two lines do. A `||` pattern
  // would say it in one clause, but Dart will not bind the same variables across two
  // alternatives of an or-pattern, so the two branches are spelled out.
  if (all case AsyncError<List<LibraryRow>>(
    :final Object error,
    :final StackTrace stackTrace,
  )) {
    return AsyncError<List<LibraryRow>>(error, stackTrace);
  }
  if (matches case AsyncError<List<String>>(
    :final Object error,
    :final StackTrace stackTrace,
  )) {
    return AsyncError<List<LibraryRow>>(error, stackTrace);
  }

  return switch ((all, matches)) {
    (
      AsyncData<List<LibraryRow>>(value: final List<LibraryRow> rows),
      AsyncData<List<String>>(value: final List<String> ids),
    ) =>
      AsyncData<List<LibraryRow>>(_view(rows, query, ids, facets, sort)),
    // ⚠️ **Either side still loading.** The rows and the ids arrive from two streams, so
    // the list is not renderable until both are in — and a half-filtered list is worse
    // than a frame of skeleton.
    _ => const AsyncLoading<List<LibraryRow>>(),
  };
});

/// The four steps of § 3.1, and the reason they are in this order.
List<LibraryRow> _view(
  List<LibraryRow> all,
  TitleSearch query,
  List<String> ids,
  LibraryFacets facets,
  LibrarySort sort,
) {
  // ⚠️ **A SET for the membership test, not a `List.contains`.** The naive form is O(n²)
  // over the library, and a reader with 200 novels types eight characters.
  final Set<String> wanted = query.isEmpty ? const <String>{} : ids.toSet();

  final List<LibraryRow> titled = query.isEmpty
      ? all
      : <LibraryRow>[
          for (final LibraryRow row in all)
            if (wanted.contains(row.novelId)) row,
        ];

  // ⚠️ **FACETS AFTER THE TITLE MATCH.** § 3.1 branch 11 says the two combine as
  // `(facets) AND (title)`; both are conjunctive so the result is identical either way,
  // and running facets second means the list the filter sees is already the searched one —
  // which is what the helper text's count describes.
  return applySort(applyFacets(titled, facets), sort);
}
