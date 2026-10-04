// Lumen Tale — history's three SHARED providers, and why they are not in the feature.
//
// ## ⚠️ They were in `features/history/`, and `settings` imported the feature to reach two
// of them
//
// `settings`'s *Reading history* row and its *Clear history* action edit the retention
// **window** — which is history's domain, so the dependency is real rather than accidental.
// But it was expressed as `features/settings` importing `features/history`, which
// `02-architecture.md` forbids, and `tool/check_boundaries.py` reported it on every run as
// a DECLARED crossing rather than a fixed one.
//
// ## ⚠️ ALL THREE MOVE TOGETHER, AND THE NOTIFIER WITH THEM
//
// `historyRetentionProvider` is a `NotifierProvider` whose notifier reads
// `appHistoryRetentionProvider`, and that store counts through the database. Moving the
// provider and leaving the notifier behind splits a pair that only works together; moving
// the notifier and leaving the store does the same. Three declarations, one file.
//
// ## What STAYS in `features/history/`
//
// `historyEntriesProvider`, `libraryEntryCountProvider` and `historyAgedOutCountProvider`
// are **screen-shaped** — they exist to draw one screen, and no other feature draws it.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lumen_tale/core/database/app_database_provider.dart';
import 'package:lumen_tale/core/storage/shared_preferences_provider.dart';
import 'package:lumen_tale/data/history/drift_history_repository.dart';
import 'package:lumen_tale/data/history/shared_prefs_history_retention.dart';
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
