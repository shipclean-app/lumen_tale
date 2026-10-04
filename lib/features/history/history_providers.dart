// Lumen Tale — the history slice's providers.
//
// `05-state-management.md`: the repository **is** a provider, and so is the retention
// store, because both are interfaces the UI reads and writes through.
//
// ## `historyRetentionProvider` is a `Notifier`, and its `select` is PURGE-THEN-WRITE
//
// `6-5` § 3.3 fixes the order and the reason: writing the preference and then purging
// would leave a screen announcing *three months* over a disk that still holds a year.
// C8's state, reached by doing the two halves in the wrong order.
//
// ## Invalidation is `historyEntriesProvider` and **nothing else**
//
// In particular **never** `readingPositionsProvider`: invalidating it would suggest the
// positions had been refreshed when they have not moved — and a refresh that recomputes
// an offset from a new text size is precisely the mechanism by which a position is
// lost. B46 says the journal and the position are two things.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:lumen_tale/core/database/app_database_provider.dart';
import 'package:lumen_tale/core/storage/shared_preferences_provider.dart';
import 'package:lumen_tale/data/history/drift_history_repository.dart';
import 'package:lumen_tale/data/history/shared_prefs_history_retention.dart';
import 'package:lumen_tale/data/library/local_counts.dart';
import 'package:lumen_tale/domain/history/history_entry.dart';
import 'package:lumen_tale/domain/history/history_grouping.dart';
import 'package:lumen_tale/domain/history/history_repository.dart';
import 'package:lumen_tale/domain/history/history_retention.dart';

final historyRepositoryProvider = Provider<HistoryRepository>(
  (Ref ref) => DriftHistoryRepository(ref.watch(appDatabaseProvider)),
);

/// The retention store, **composed rather than overridden**.
///
/// ⚠️ It is the only provider here that is not a bootstrap override, and that is on
/// purpose. Overriding it would mean the store's counting function had to be built in
/// `main.dart`, which means it would need the `AppDatabase` — and the db is
/// constructed *by* the override that creates the store. A bootstrap that has to
/// order two overrides against each other is a bootstrap with a cycle in it.
///
/// Composing from [appDatabaseProvider] and [sharedPreferencesProvider] makes the
/// order the container's problem, which is the one place that solves it.
///
/// **And it uses the same `SharedPreferences` instance the theme reads**, because
/// `main.dart` awaits `getInstance()` exactly once. Two instances over one file are two
/// caches that disagree — and the disagreement would show up as a retention window
/// that reverts, with no error anywhere.
final appHistoryRetentionProvider = Provider<HistoryRetentionStore>(
  (Ref ref) => SharedPrefsHistoryRetentionStore(
    ref.watch(sharedPreferencesProvider),
    (DateTime cutoff, {required bool exclusive}) =>
        countHistoryEntriesOlderThan(
          ref.watch(appDatabaseProvider),
          cutoff,
          exclusive: exclusive,
        ),
  ),
);

/// The committed window, B47 — `keepAlive`, because it outlives the screen that set it.
final historyRetentionProvider =
    NotifierProvider<HistoryRetentionNotifier, HistoryRetention>(
      HistoryRetentionNotifier.new,
    );

class HistoryRetentionNotifier extends Notifier<HistoryRetention> {
  @override
  HistoryRetention build() => HistoryRetention.defaultWindow;

  /// Loads the stored window. A **read creates nothing** — the default is the absence
  /// of a key, so "has the reader chosen a window?" stays answerable.
  Future<void> load() async {
    state = await ref.read(appHistoryRetentionProvider).read();
  }

  /// Shorten or lengthen the window, **purge first**.
  ///
  /// ⚠️ Order is load-bearing and the comment above the file says why. And the
  /// mutation happens **last**: a write that throws must leave `state` on the
  /// previous window so the sheet can snap back to it (B24, C8).
  Future<void> select(HistoryRetention window) async {
    if (window == state) {
      return;
    }
    final HistoryRetentionStore store = ref.read(appHistoryRetentionProvider);

    // ⚠️ `purge` BEFORE `write`, and both before `state`. A purge that throws leaves
    // the preference untouched and the rows untouched, which is a screen that is
    // simply late rather than one that lies.
    await _purgeFor(window);
    await store.write(window); // throws before any state mutation
    state = window;
  }

  Future<void> _purgeFor(HistoryRetention window) async {
    final DateTime cutoff = window.cutoffFrom(DateTime.now());
    await ref.read(historyRepositoryProvider).purgeOlderThan(cutoff);
  }
}

/// What the screen reads: the entries inside the window, grouped by local day.
final historyEntriesProvider = FutureProvider<List<HistoryDayGroup>>((
  Ref ref,
) async {
  // ⚠️ **The retention window is `watch`ed, not read once.** The list is the window,
  // so changing the window has to re-read it — a list that kept the old boundary
  // would show the reader rows the new window has already dropped.
  final HistoryRetention window = ref.watch(historyRetentionProvider);
  final List<HistoryEntry> entries = await ref
      .watch(historyRepositoryProvider)
      .readEntries(cutoff: window.cutoffFrom(DateTime.now()));
  return groupByLocalDay(entries);
});

/// How many novels are in the library, for the empty state's *local fact*.
///
/// `history.md` § 4 chooses the empty action from this, and it is also the basis for the
/// *"Nothing read yet"* claim: a chapter can only be opened from a novel that is in the
/// library, so an empty library means an unopened reader.
///
/// It reads [localCounts.countLibraryNovels] rather than a repository, because `6-3`
/// owns the library and has not written one — and the count lives in `data/` where the
/// table's shape is known, so `3-5`'s About screen uses the same function for the same
/// figure instead of a second query that could disagree.
final libraryEntryCountProvider = FutureProvider<int>(
  (Ref ref) => countLibraryNovels(ref.watch(appDatabaseProvider)),
);

/// How many entries are **about to** leave the window, for the sheet's warning.
///
/// A separate `FutureProvider`, not a field on [historyEntriesProvider], because it is
/// a different question with a different clock: the list is bounded by the window,
/// this counts what a *different* window would drop. Counting the list would answer
/// the question after the purge, where the answer is always zero.
final historyAgedOutCountProvider = FutureProvider<int>((Ref ref) async {
  final HistoryRetention window = ref.watch(historyRetentionProvider);
  return ref
      .watch(appHistoryRetentionProvider)
      .countOlderThan(window.cutoffFrom(DateTime.now()));
});
