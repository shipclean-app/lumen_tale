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

import 'package:lumen_tale/data/history/history_providers.dart';
import 'package:lumen_tale/data/library/local_counts.dart';
import 'package:lumen_tale/domain/history/history_entry.dart';
import 'package:lumen_tale/domain/history/history_grouping.dart';
import 'package:lumen_tale/domain/history/history_retention.dart';

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
