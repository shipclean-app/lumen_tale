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

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lumen_tale/core/database/app_database_provider.dart';
import 'package:lumen_tale/data/library/drift_library_repository.dart';
import 'package:lumen_tale/domain/library/library_entry.dart';
import 'package:lumen_tale/domain/library/library_repository.dart';

/// Overridden at the bootstrap, like every repository over the database.
final libraryRepositoryProvider = Provider<LibraryRepository>(
  (Ref ref) => DriftLibraryRepository(ref.watch(appDatabaseProvider)),
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
