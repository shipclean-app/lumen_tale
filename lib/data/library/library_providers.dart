// Lumen Tale — the library's three providers, and why they are not in `features/library/`.
//
// ## ⚠️ They were, and four features imported a feature to reach them
//
// `libraryRepositoryProvider`, `libraryStreamProvider` and `removeFromLibraryProvider`
// were declared in `features/library/library_screen.dart`. Four features then imported
// that SCREEN to reach them: `browse`, `source_unavailable`, `novel_details` (twice).
//
// Every one of those imports was a violation of `02-architecture.md`, and each one pulled
// a whole screen's dependency list into a screen that wanted three symbols. The `show`
// clause kept the *namespace* clean; it did nothing about the *dependency*, which is what
// the rule is about.
//
// ## ⚠️ `libraryStreamProvider` is `keepAlive`, and that is the reason it is shared
//
// It is `05-state-management.md` rule 10: the library is the app's spine, every screen
// reads it, and the alternative is a screen that rebuilds when nothing changed. It is the
// one provider here whose lifetime is the process's.
//
// ## ⚠️ `invalidateLibraryProviders` LIVES HERE TOO, and that is not tidiness
//
// It was added by `6-4`. A grouped invalidation helper is only worth having if it
// sits beside the thing it defines: the helper's whole value is that a caller
// cannot refresh three things and forget the third, and a copy living in whichever
// feature needed it this time would be a second place deciding what "the library"
// means.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lumen_tale/core/database/app_database_provider.dart';
import 'package:lumen_tale/data/library/drift_library_repository.dart';
import 'package:lumen_tale/data/library/drift_library_rows_repository.dart';
import 'package:lumen_tale/data/library/drift_similar_title_finder.dart';
import 'package:lumen_tale/domain/library/library_entry.dart';
import 'package:lumen_tale/domain/library/library_repository.dart';
import 'package:lumen_tale/domain/library/library_row.dart';
import 'package:lumen_tale/domain/library/library_rows_repository.dart';
import 'package:lumen_tale/domain/library/similar_title.dart';

/// Overridden at the bootstrap, like every repository over the database.
final libraryRepositoryProvider = Provider<LibraryRepository>(
  (Ref ref) => DriftLibraryRepository(ref.watch(appDatabaseProvider)),
);

/// `6-6`'s rows: the library with the counts and facts the **row** renders.
///
/// ⚠️ **A SEPARATE STREAM FROM [libraryStreamProvider], and the reason is a number.**
/// `LibraryEntry.unopenedCount` is `2-5`'s *unread among downloaded*;
/// `LibraryRow.unopenedCount` is `6-6` § 3.2's `COUNT(is_read = 0)` over every chapter,
/// which is the number `6-3` — the plan's owner for the counting model — computes. Both
/// are asserted by a passing test, so neither could be moved, and a screen that read one
/// while claiming the other would be the app contradicting itself inside one row. See
/// `library_row.dart`'s header.
///
/// ⚠️ **THE SOURCE-NAME RESOLVER IS [LibraryRepository.sourceNameOf], and not a second
/// registry.** ADR-013 says there is exactly one compiled registry and no stored source
/// name; wiring a second `SourceManager` here to resolve the same ids would be a second
/// answer to "what is this site called", and `main.dart` overrides one provider rather
/// than two.
final libraryRowsRepositoryProvider = Provider<LibraryRowsRepository>(
  (Ref ref) => DriftLibraryRowsRepository(
    ref.watch(appDatabaseProvider),
    sourceNameOf: ref.watch(libraryRepositoryProvider).sourceNameOf,
  ),
);

/// The library rows, reactively.
///
/// ⚠️ **`keepAlive`, for [libraryStreamProvider]'s reason and not a new one.** It reads
/// the same table, and a provider that disposed while the tab was away would re-run one
/// aggregate per return for the screen the reader came back to.
final libraryRowsStreamProvider = StreamProvider<List<LibraryRow>>(
  (Ref ref) => ref.watch(libraryRowsRepositoryProvider).watchRows(),
);

/// B40's finder, over the same local table.
final similarTitleFinderProvider = Provider<SimilarTitleFinder>(
  (Ref ref) => DriftSimilarTitleFinder(
    ref.watch(appDatabaseProvider),
    sourceNameOf: ref.watch(libraryRepositoryProvider).sourceNameOf,
  ),
);

/// The library, as a stream — **`keepAlive`**, for the reason in the file header.
final libraryStreamProvider = StreamProvider<List<LibraryEntry>>(
  (Ref ref) => ref.watch(libraryRepositoryProvider).watchLibrary(),
);

/// Removes a novel, and reports the count that was downloaded when the reader was asked.
///
/// ⚠️ **`autoDispose`,** because it holds one operation in progress and nothing else — the
/// data lives in the stream, not here.
final removeFromLibraryProvider =
    Provider.autoDispose<Future<RemoveOutcome> Function(String novelId)>(
      (Ref ref) => ref.watch(libraryRepositoryProvider).removeFromLibrary,
    );

/// `05-state-management.md` §Invalidation — **one call** for the callers that must
/// refresh the library, its counts and its timestamps together.
///
/// ⚠️ **It invalidates ONE provider, and that is not an omission.** A check writes
/// `novels.last_checked_at` and `sources.last_error_code`; both reach the reader
/// through [libraryStreamProvider], which is the single read that renders a
/// library row. The unopened count is **not** here and does not need to be:
///
/// - **B48** — it is derived in SQL over chapter rows, and this pass never writes
///   `is_read`, so it cannot have moved;
/// - drift's streams re-emit on their own when the tables change, which is what
///   `readsFrom` is declared for.
///
/// So an invalidation for the count would be a refresh that provably produces the
/// same numbers — the sort of redundant write-down that makes a later reader
/// believe the two are independent facts.
void invalidateLibraryProviders(Ref ref) {
  ref.invalidate(libraryStreamProvider);
  // ⚠️ **The rows stream is invalidated too, and `6-6` says why that is not redundant.**
  // drift re-emits a custom select on its own when a table it reads changes, so the badge
  // would refresh regardless — but `libraryRowsStreamProvider` also feeds the *search id
  // set*, whose `readsFrom` is `novels` alone, and a novel removed while a query is open
  // must leave the results. Invalidating the derived stream rather than each reader is
  // the same "a caller cannot refresh three things and forget the third" argument this
  // helper exists for.
  ref.invalidate(libraryRowsStreamProvider);
}
