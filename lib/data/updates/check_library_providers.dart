// Lumen Tale — `6-4`'s three providers, and why they are in `data/` and not in a feature.
//
// ## ⚠️ THEY ARE SHARED, AND A SHARED PROVIDER IN A FEATURE IS F-018 AGAIN
//
// `6-4` § 4.2 puts `libraryCheckProvider` in `features/updates/providers/`. Three
// screens read it — `updates.md` § 4 (*Loading — a check is running*), `library.md` § 5
// (*Check for new chapters*) and `settings.md` § 4.1 (`row.checkNow.*`) — and
// `02-architecture.md` forbids `features/*` importing another `features/*`. So
// declaring it in the updates feature would force `library` and `settings` to import
// `features/updates/`, which is the exact defect `app_database_provider.dart`
// documents: ten undeclared crossings, four of them a **database** provider reached
// through a history screen, and `tool/check_boundaries.py` had to be written to notice.
// These three therefore live beside the other shared providers, in `data/`.
//
// ## ⚠️ `libraryCheckProvider` IS `keepAlive`, AND § 4.2 GIVES THE REASON
//
// `updates.md` § 5 *Back*: a check in progress **is not** cancelled by leaving the
// screen — it is a foreground job with its own notification and its own cancel (B37) —
// and `library.md` shows the same progress from another tab. An `autoDispose` provider
// would destroy the run the moment the tab changed, and the check button would come back
// in its `loading` state with no work behind it. `05-state-management.md` rule 10
// requires a stated reason for `keepAlive`; this is it.
//
// ## ⚠️ TWO BOOTSTRAP OVERRIDES, AND BOTH THROW UNTIL THEY ARE OVERRIDDEN
//
// `data/` may not import `features/`, and the one declared `SourceManager` provider
// lives in `features/browse/catalogue_screen.dart` (F-018's successor: the database
// provider was moved out of `history`, and the registry provider was not). So
// `data/updates` cannot reach it. The limiter is worse: `buildSourceManager` creates the
// one shared `HostRateLimiter` as a **local variable**, so nothing outside
// `source_registry.dart` can name it. Both are therefore bootstrap overrides, in the
// same shape as `appDatabaseProvider` — and the reason they are declared here rather
// than constructed is precisely that a second registry or a second limiter would mean a
// second set of HTTP clients (ADR-013) and a throttle that no longer throttles the
// aggregate.

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lumen_tale/core/database/app_database_provider.dart';
import 'package:lumen_tale/core/error/app_exception.dart';
import 'package:lumen_tale/core/network/host_rate_limiter.dart';
import 'package:lumen_tale/data/library/library_providers.dart';
import 'package:lumen_tale/data/sources/source_manager.dart';
import 'package:lumen_tale/data/updates/drift_check_library.dart';
import 'package:lumen_tale/data/updates/drift_library_check_store.dart';
import 'package:lumen_tale/domain/updates/check_library.dart';
import 'package:lumen_tale/domain/updates/library_check.dart';
import 'package:lumen_tale/domain/updates/library_check_store.dart';

/// The registry, as this layer sees it.
///
/// ⚠️ **Overridden at the composition root**, exactly like `sourceManagerProvider` and
/// `appDatabaseProvider`. `data/` may not import `features/browse/` to reach the other
/// one, and building a registry here would be a second source server (ADR-013).
final libraryCheckSourceManagerProvider = Provider<SourceManager>(
  (Ref ref) => throw UnimplementedError(
    'libraryCheckSourceManagerProvider is overridden at the composition root, '
    'because data/ may not import the features/browse provider and a second '
    'registry would be a second source server (ADR-013)',
  ),
);

/// The **shared** per-host limiter.
///
/// ⚠️ **Overridden, never constructed here.** A second `HostRateLimiter` would be a
/// second set of per-host windows: `SourceHttpClient` would keep throttling against the
/// registry's instance while this one kept an empty table, and the `Retry-After` a
/// check records would be honoured by nobody.
final libraryCheckRateLimiterProvider = Provider<HostRateLimiter>(
  (Ref ref) => throw UnimplementedError(
    'libraryCheckRateLimiterProvider is overridden at the composition root with '
    'the SAME HostRateLimiter buildSourceManager gave each HttpClient, because '
    'two limiters mean the Retry-After this pass records is honoured by nobody',
  ),
);

/// The local half of the check.
final libraryCheckStoreProvider = Provider<LibraryCheckStore>(
  (Ref ref) => DriftLibraryCheckStore(ref.watch(appDatabaseProvider)),
);

/// The use case.
final checkLibraryProvider = Provider<CheckLibrary>(
  (Ref ref) => DriftCheckLibrary(
    store: ref.watch(libraryCheckStoreProvider),
    sources: ref.watch(libraryCheckSourceManagerProvider),
    rateLimiter: ref.watch(libraryCheckRateLimiterProvider),
    clock: DateTime.now,
  ),
);

/// The live progress of a pass. **`keepAlive`**, for the reason in the file header.
///
/// ⚠️ **A SEPARATE PROVIDER FROM [libraryCheckProvider], and not a field on it.**
/// Three screens read progress while the run machine reads the result; coupling them
/// would mean a screen watching the async state also rebuilt on every novel, which is
/// `15-performance.md`'s "a rebuild per chapter of a ten-thousand-chapter novel". One
/// notifier per concern — `05-state-management.md` § Notifier patterns.
///
/// The progress is `null` while no pass has started, which is a distinct claim from
/// `total == 0` (an empty library). B12 makes "nothing is kept" a real first-run state,
/// and a screen that drew a counter for it would be counting nothing.
final libraryCheckProgressProvider =
    NotifierProvider<LibraryCheckProgressNotifier, LibraryCheckProgress?>(
      LibraryCheckProgressNotifier.new,
    );

/// § 4.2 names a third notifier, `CheckResultNotifier`, holding the finished result.
/// **It is [libraryCheckProvider] itself, and the reason is mechanical.** Two providers
/// holding a `LibraryCheckResult` would be two sources of truth free to disagree —
/// which is B48's exact defect one layer up: a stale second copy of a number is worse
/// than no copy. `libraryCheckProvider`'s state *is* `LibraryCheckResult?`, `keepAlive`,
/// and readable by all three screens.
class LibraryCheckProgressNotifier extends Notifier<LibraryCheckProgress?> {
  @override
  LibraryCheckProgress? build() => null;

  /// Called by [LibraryCheckNotifier] for every emission. One write per novel, and the
  /// value is the snapshot the interactor produced — this notifier never derives or
  /// counts anything.
  void record(LibraryCheckProgress progress) => state = progress;

  /// Clears the line when a pass ends. `null` and `total == 0` stay distinct.
  void clear() => state = null;
}

/// **B36's single entry point.** Idle, running, done — and nothing that can start a pass
/// on its own.
final libraryCheckProvider =
    AsyncNotifierProvider<LibraryCheckNotifier, LibraryCheckResult?>(
      LibraryCheckNotifier.new,
    );

class LibraryCheckNotifier extends AsyncNotifier<LibraryCheckResult?> {
  /// ⚠️ **The idle state is `AsyncData(null)`, not `AsyncLoading`.** There is no work in
  /// flight, and a screen that reads this provider must be able to tell "no pass has run"
  /// from "a pass is starting" — B36's rule is that opening the app triggers nothing, and
  /// a loading state on first read would claim a pass had begun.
  @override
  FutureOr<LibraryCheckResult?> build() => null;

  bool _cancelRequested = false;

  /// B37 — whether the last pass ended because the reader asked it to.
  ///
  /// ⚠️ **Kept beside the result, NOT thrown from `run()`.** § 3.1 returns
  /// `interrupted: true` and § 10's B37 row asserts that shape, so a cancelled pass is a
  /// result. This exists because `13-error-handling.md` rule 7 requires a caller to
  /// distinguish *cancelled* from *failed* — `6-10` needs exactly that to suppress an
  /// error notification for the reader's own gesture.
  CheckCancelledException? get cancellation =>
      _cancelRequested ? const CheckCancelledException() : null;

  /// Runs one pass over the whole library (B36, B39).
  ///
  /// ⚠️ **The ONLY call to `CheckLibrary.run()` in `lib/`.** `run()` takes no trigger, no
  /// schedule and no lifecycle reason, so no caller can start a pass it cannot justify —
  /// and a test greps `lib/` to prove there is no other caller.
  ///
  /// A store that cannot be read surfaces as `AsyncError`: § 3.1's table says a
  /// `DatabaseException` is the screen's error state and not a per-novel failure.
  Future<LibraryCheckResult?> start() async {
    if (state.isLoading) {
      // B39 — a second pass over the same novels would double every write for the same
      // answer, and a progress line that counts to 46 is a lie about a 23-novel library.
      return null;
    }
    _cancelRequested = false;

    state = const AsyncLoading<LibraryCheckResult?>();
    try {
      final LibraryCheckResult result = await ref
          .read(checkLibraryProvider)
          .run(
            onProgress: ref.read(libraryCheckProgressProvider.notifier).record,
            cancellation: _isCancelled,
          );

      // ⚠️ **THE LINE IS CLEARED *AFTER* THE RESULT, NEVER BEFORE.** `updates.md` § 4 says
      // the terminal line replaces the counter, so a screen that watches only progress
      // must not keep drawing "Checking 23 of 23" under a finished pass.
      ref.read(libraryCheckProgressProvider.notifier).clear();
      state = AsyncData<LibraryCheckResult?>(result);

      // § 5 — the grouped refresh. The unopened count does **not** change (B48: it is
      // local, and the pass never writes `is_read`), so nothing about it needs
      // invalidating; what does change is `last_checked_at` and the failure markers, and
      // those reach the reader through the library stream.
      invalidateLibraryProviders(ref);

      return result;
    } on CancelledException {
      // ⚠️ **RULE 7: NO ERROR IS SURFACED.** The reader's own gesture is recorded in
      // [cancellation] and the state returns to "no result", which is what
      // `AppErrorString.checkCancelled` renders — a snackbar and no error surface.
      ref.read(libraryCheckProgressProvider.notifier).clear();
      _cancelRequested = true;
      state = const AsyncData<LibraryCheckResult?>(null);
      return null;
    }
  }

  /// B37 — ask the running pass to stop between two novels.
  ///
  /// Synchronous and never awaited: it flips a flag the interactor polls, it does not
  /// touch the network, and a cancel that had to wait for a request to finish would be a
  /// cancel the reader could not make.
  void cancel() => _cancelRequested = true;

  Future<bool> _isCancelled() async => _cancelRequested;
}
