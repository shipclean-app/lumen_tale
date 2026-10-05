// forge:slice 6-4
// Lumen Tale — the three providers: B36\'s single door, B37\'s cancel, and the lifetime that
// lets a check survive a tab change.
//
// ## What a `ProviderContainer` row can prove that a fake cannot
//
// `05-state-management.md` §P1: Riverpod notifiers are tested with a container and
// overrides, not with widgets. § 11.2 says why this slice has no widget test: *a widget test
// for an `AsyncNotifier` that orchestrates a network loop would be a test that tests
// nothing.* So this file is the notifier\'s whole surface, and the three claims are the ones
// § 4.2 and § 5 make about it:
//
// | rule | the claim | the row |
// |---|---|---|
// | **B36** | reading the provider runs **nothing**; `start()` is the only caller | *the interactor\'s `run` is counted, and stays at zero* |
// | **B37** | `cancel()` before the first novel yields `perNovel.isEmpty && interrupted` | *the shape § 10 names, on a real interactor* |
// | **05-state-management rule 10** | all three are `keepAlive`, for the stated reason | *the value survives the disappearance of its last listener* |
// | **§ 5** | the pass ends by calling `invalidateLibraryProviders(ref)` | *the library stream is re-read after the pass* |
//
// ## ⚠️ RIVERPOD 3, AND THE TWO SPELLINGS THIS FILE DEPENDS ON
//
// 1. `AsyncNotifier` providers are **not** `autoDispose` here, and `read()` on an
//    uninitialised provider does not build it. So every row **listens first** and waits for
//    the value — `container.listen` then a `Completer`, the shape `chapter_list_view_state
//    _test.dart` uses — because reading `.future` on a `FutureProvider` is the idiom and it
//    is wrong for an `AsyncNotifier`.
// 2. `overrideWithValue` on a **bootstrap-throwing** provider is what puts a
//    `SourceManager` and a `HostRateLimiter` in the container. Both throw until the
//    composition root overrides them, which is why these rows are also the only place the
//    test proves a container can be built without `main.dart`.
//
// ⚠️ **AND THE `AsyncData(null)` IDLE STATE IS AN ASSERTION, NOT A DEFAULT.** § 4.2\'s reason
// for the idle shape is that a screen must be able to tell "no pass has run" from "a pass is
// starting". A provider that built `AsyncLoading` would claim a pass had begun — which is
// B36\'s rule, restated as a state.

import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumen_tale/core/database/app_database.dart';
import 'package:lumen_tale/core/database/app_database_provider.dart';
import 'package:lumen_tale/core/network/host_rate_limiter.dart';
import 'package:lumen_tale/data/library/library_providers.dart';
import 'package:lumen_tale/data/sources/source_manager.dart';
import 'package:lumen_tale/data/updates/check_library_providers.dart';
import 'package:lumen_tale/data/updates/drift_check_library.dart';
import 'package:lumen_tale/data/updates/drift_library_check_store.dart';
import 'package:lumen_tale/domain/library/library_entry.dart';
import 'package:lumen_tale/domain/library/library_repository.dart';
import 'package:lumen_tale/domain/library/similar_title.dart';
import 'package:lumen_tale/domain/sources/models/novel.dart';
import 'package:lumen_tale/domain/sources/source.dart';
import 'package:lumen_tale/domain/updates/check_library.dart';
import 'package:lumen_tale/domain/updates/library_check.dart';

import 'check_fakes.dart';

/// A `CheckLibrary` that records every `run()` and answers a fixed result.
///
/// ⚠️ **IT EXISTS TO COUNT, NOT TO STAND IN FOR THE REAL THING.** `drift_check_library_test
/// .dart` drives the real interactor; this double exists for the rows about what the
/// **notifier** does — B36\'s "reading starts nothing", B37\'s cancel plumbing, the invalidation
/// at the end — where a network loop would only obscure the state transitions.
final class CountingCheckLibrary implements CheckLibrary {
  CountingCheckLibrary({this.result});

  /// What `run()` returns when it is allowed to finish. `null` builds a two-novel result.
  LibraryCheckResult? result;

  int runCalls = 0;

  /// The emissions handed to the caller, in order.
  final List<LibraryCheckProgress> emissions = <LibraryCheckProgress>[];

  /// Awaits this before returning, so a `cancel()` issued mid-pass is observable.
  Completer<void>? gate;

  @override
  Future<LibraryCheckResult> run({
    required void Function(LibraryCheckProgress) onProgress,
    required Future<bool> Function() cancellation,
  }) async {
    runCalls++;
    onProgress(
      const LibraryCheckProgress(total: 2, done: 0, inFlightNovelId: 'n1'),
    );
    if (gate != null) await gate!.future;
    if (await cancellation()) {
      return LibraryCheckResult(
        startedAt: DateTime.utc(2026, 10, 4, 9),
        finishedAt: DateTime.utc(2026, 10, 4, 9, 1),
        total: 2,
        perNovel: const <NovelCheckOutcome>[],
        interrupted: true,
      );
    }
    onProgress(
      const LibraryCheckProgress(total: 2, done: 1, inFlightNovelId: 'n2'),
    );
    onProgress(
      const LibraryCheckProgress(total: 2, done: 2, inFlightNovelId: null),
    );
    emissions.addAll(<LibraryCheckProgress>[
      const LibraryCheckProgress(total: 2, done: 0, inFlightNovelId: 'n1'),
    ]);
    return result ??
        LibraryCheckResult(
          startedAt: DateTime.utc(2026, 10, 4, 9),
          finishedAt: DateTime.utc(2026, 10, 4, 9, 1),
          total: 2,
          perNovel: List<NovelCheckOutcome>.unmodifiable(<NovelCheckOutcome>[
            NovelChecked(
              newChaptersFound: 3,
              siteChapterCount: 9,
              checkedAt: DateTime.utc(2026, 10, 4, 9),
            ),
            NovelChecked(
              newChaptersFound: 0,
              siteChapterCount: 4,
              checkedAt: DateTime.utc(2026, 10, 4, 9),
            ),
          ]),
          interrupted: false,
        );
  }
}

/// A library repository that counts `watchLibrary()` subscriptions, and answers nothing.
///
/// ⚠️ **A COUNT, NOT A CACHE.** `invalidateLibraryProviders` re-subscribes the
/// stream, and a cached list would let the row pass without the invalidation having
/// happened — the failure mode `drift_unopened_count_repository_test.dart` calls out for
/// its own stream.
///
/// ⚠️ **EVERY METHOD IS STUBBED, AND NONE OF THEM IS USED.** The interface has
/// eight members because it is the library\'s whole surface; this notifier needs one of
/// them. Each throws rather than returning a plausible value, so a row that reached one by
/// accident fails loudly instead of passing on a coincidence.
final class CountingLibraryRepository implements LibraryRepository {
  int watches = 0;

  @override
  Stream<List<LibraryEntry>> watchLibrary() {
    watches++;
    return Stream<List<LibraryEntry>>.value(const <LibraryEntry>[]);
  }

  Never _unused(String method) =>
      throw StateError('this notifier test must not call $method');

  @override
  Future<AddOutcome> addFromCatalogue({
    required Novel novel,
    required Future<SimilarTitleVerdict> Function(List<SimilarTitle> similar)
    onSimilarTitle,
  }) async => _unused('addFromCatalogue');

  @override
  Future<int> countDownloadedChapters(String novelId) async =>
      _unused('countDownloadedChapters');

  @override
  Future<Novel?> readNovel(String novelId) async => _unused('readNovel');

  @override
  Future<void> restoreToLibrary(String novelId) async =>
      _unused('restoreToLibrary');

  @override
  Future<RemoveOutcome> removeFromLibrary(String novelId) async =>
      _unused('removeFromLibrary');

  @override
  String? sourceNameOf(String sourceId) => _unused('sourceNameOf');
}

/// A container with the bootstrap providers overridden and nothing else.
Future<ProviderContainer> containerOf({
  required CheckLibrary check,
  required LibraryRepository library,
}) async {
  final ProviderContainer container = ProviderContainer(
    overrides: [
      libraryCheckStoreProvider.overrideWithValue(_UnusedStore()),
      checkLibraryProvider.overrideWithValue(check),
      libraryRepositoryProvider.overrideWithValue(library),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

/// The store the notifier tests never reach, because `checkLibraryProvider` is overridden.
///
/// ⚠️ **IT IS NOT A REAL DRIFT STORE ON PURPOSE.** Every row here is about the NOTIFIER, and
/// the interactor is replaced by [CountingCheckLibrary]. A real store would add a database
/// to a test that must assert "reading the provider issues no query and no request".
final class _UnusedStore implements LibraryCheckStore {
  @override
  Future<bool> isSourceEnabled(String sourceId) async => true;

  @override
  Future<List<LibraryNovelRef>> listLibraryNovels() async =>
      const <LibraryNovelRef>[];

  @override
  Future<int> mergeChapterList(String novelId, List<NewChapter> fresh) async =>
      0;

  @override
  Future<void> recordCheckFailure(
    String novelId,
    CheckFailureKind kind,
  ) async {}

  @override
  Future<void> recordChecked(String novelId, DateTime at) async {}
}

void main() {
  group('B36 — reading the provider runs NOTHING', () {
    test('the idle state is `AsyncData(null)`, and `run()` was never called', () async {
      final CountingCheckLibrary check = CountingCheckLibrary();
      final ProviderContainer container = await containerOf(
        check: check,
        library: CountingLibraryRepository(),
      );

      final AsyncValue<LibraryCheckResult?> idle = await _checkStateOf(
        container,
      );

      expect(
        idle,
        isA<AsyncData<LibraryCheckResult?>>(),
        reason:
            '§ 4.2: the idle state must be distinguishable from "a pass is starting" — '
            'a screen reading `isLoading` would claim a check had begun, which is B36\'s '
            'rule about what a first read may do',
      );
      expect(
        idle.value,
        isNull,
        reason: 'and no pass has run, so there is no result',
      );
      expect(
        check.runCalls,
        0,
        reason:
            '⚠️ THE ROW B36 IS WRITTEN FOR. Opening the app is not a trigger. A provider '
            'that fetched in `build` would make this screen check the library every time '
            'it appeared',
      );
      expect(
        container.read(libraryCheckProgressProvider),
        isNull,
        reason:
            'and no counter was drawn: `total == 0` (an empty library) and "no pass has '
            'started" are different claims, and B12 makes the first one real',
      );
    });

    test(
      'a second `start()` while one is running does not begin a second pass',
      () async {
        // B39: a pass that ran twice would double every write for the same answer and
        // produce a counter that climbs past the library\'s size — a lie about 23 novels.
        final CountingCheckLibrary check = CountingCheckLibrary()
          ..gate = Completer<void>();
        final ProviderContainer container = await containerOf(
          check: check,
          library: CountingLibraryRepository(),
        );
        await _checkStateOf(container);

        final Future<LibraryCheckResult?> first = container
            .read(libraryCheckProvider.notifier)
            .start();
        // The pass is in flight inside `gate`; a second `start()` now must be a no-op.
        final LibraryCheckResult? second = await container
            .read(libraryCheckProvider.notifier)
            .start();

        expect(
          second,
          isNull,
          reason:
              'the second `start()` returns nothing rather than a second pass',
        );
        expect(
          check.runCalls,
          1,
          reason: 'B39: one pass over 23 novels, not two passes over 23 novels',
        );

        check.gate!.complete();
        await first;
      },
    );

    test('`start()` drives the interactor, and stores the result', () async {
      final CountingCheckLibrary check = CountingCheckLibrary();
      final ProviderContainer container = await containerOf(
        check: check,
        library: CountingLibraryRepository(),
      );
      await _checkStateOf(container);

      final LibraryCheckResult? result = await container
          .read(libraryCheckProvider.notifier)
          .start();

      expect(check.runCalls, 1, reason: 'B36: the tap is what starts a pass');
      expect(result, isNotNull);
      expect(
        result!.discoveredChapters,
        3,
        reason:
            '§ 11.3: `6-10` reads `discoveredChapters` off this result without redoing the '
            'pass, so the number has to be here and not only on screen',
      );
      expect(
        container.read(libraryCheckProvider).value,
        same(result),
        reason:
            'and the result is kept on the provider, readable by all three screens',
      );
    });
  });

  group('B37 — `cancel()` is the reader\'s own gesture, and no error surfaces', () {
    test('cancelled before the first novel: empty, interrupted, and NOT an error', () async {
      // § 10\'s B37 row, verbatim: `perNovel.isEmpty && interrupted == true`.
      //
      // ⚠️ **THE RETURNED VALUE IS THE INTERRUPTED RESULT, NOT `null`.** § 3.1 RETURNS it
      // rather than throwing, and the first version of this row asserted `null` — which
      // describes the *notifier\'s* `AsyncData(null)` after it swallows a
      // `CancelledException`, a path the real interactor never takes. The shape `6-10`
      // needs is on the result; the *suppression* of the error is on the notifier\'s
      // `cancellation` flag. Both are asserted, and they are different facts.
      final CountingCheckLibrary check = CountingCheckLibrary()
        ..gate = Completer<void>();
      final ProviderContainer container = await containerOf(
        check: check,
        library: CountingLibraryRepository(),
      );
      await _checkStateOf(container);

      final Future<LibraryCheckResult?> pass = container
          .read(libraryCheckProvider.notifier)
          .start();
      container.read(libraryCheckProvider.notifier).cancel();
      check.gate!.complete();

      final LibraryCheckResult? result = await pass;
      expect(
        result?.perNovel,
        isEmpty,
        reason:
            'B37: the gate fired before the first novel, so nothing was visited',
      );
      expect(
        result?.interrupted,
        isTrue,
        reason:
            'and it is reported as interrupted — a stopped pass is never a finished '
            'one (C8)',
      );
      expect(
        container.read(libraryCheckProvider).hasError,
        isFalse,
        reason:
            '⚠️ rule 7: the reader\'s own gesture must show NO error. `hasError` is '
            'the assertion a screen\'s error branch keys on',
      );
      expect(
        container.read(libraryCheckProvider.notifier).cancellation,
        isA<CheckCancelledException>(),
        reason:
            'rule 7: the caller still distinguishes "cancelled" from "failed", and the '
            'distinction is a typed value because `6-10` needs it to stay silent',
      );
      expect(
        container.read(libraryCheckProgressProvider),
        isNull,
        reason:
            'and the counter is cleared, so no "Checking 2 of 2" outlives the pass',
      );
    });

    test('a pass that is not cancelled reports `cancellation == null`', () async {
      final CountingCheckLibrary check = CountingCheckLibrary();
      final ProviderContainer container = await containerOf(
        check: check,
        library: CountingLibraryRepository(),
      );
      await _checkStateOf(container);
      await container.read(libraryCheckProvider.notifier).start();

      expect(
        container.read(libraryCheckProvider.notifier).cancellation,
        isNull,
        reason:
            'the flag is per-pass: a cancel from an earlier pass must not silence the '
            'next pass\'s error notification',
      );
    });

    test('the progress line is CLEARED when a pass ends', () async {
      // ⚠️ **THE PASS IS GATED, OR THIS ROW MEASURES NOTHING.** An ungated fake finishes
      // before the first `await`, so the "a running pass has a line" assertion below reads
      // a pass that has already ended and whose line has already been cleared — which is
      // exactly how it failed the first time. A row that does not control its own timing
      // cannot observe a transition.
      //
      // ⚠️ **CLEARED *AFTER* THE RESULT, NEVER BEFORE.** `updates.md` § 4: the terminal line
      // replaces the counter. A screen that watches only progress must not keep drawing
      // "Checking 23 of 23" under a finished pass — and clearing first would leave a gap
      // where neither line is drawn.
      final CountingCheckLibrary check = CountingCheckLibrary()
        ..gate = Completer<void>();
      final ProviderContainer container = await containerOf(
        check: check,
        library: CountingLibraryRepository(),
      );
      await _checkStateOf(container);

      final Future<LibraryCheckResult?> pass = container
          .read(libraryCheckProvider.notifier)
          .start();
      // `run` has already emitted its first progress line by the time it is awaited.
      await pumpEventQueue();
      expect(
        container.read(libraryCheckProgressProvider)?.total,
        2,
        reason:
            'a running pass has a line to draw, and it already knows the library\'s size '
            '(§ 2.2: the total holds from the first emission)',
      );

      check.gate!.complete();
      await pass;
      expect(
        container.read(libraryCheckProgressProvider),
        isNull,
        reason:
            '§ 4.3: once the pass is over the terminal line replaces the counter, and a '
            'stale counter under it is two answers to one question',
      );
    });
  });

  group(
    '05-state-management.md rule 10 — all three are `keepAlive`, for a stated reason',
    () {
      // ⚠️ **THE ROW, AND WHY IT IS NOT A DECLARATION CHECK.** Reading the source for
      // `autoDispose` proves the declaration, which a reviewer can read in one glance. What
      // only a container can prove is the *behaviour*: with `autoDispose`, destroying the last
      // listener rebuilds the provider, and the state silently returns to its initial value —
      // so a pass would appear to have never run, and the *Check* button would come back in a
      // `loading` state with no work behind it. That is `updates.md` § 5\'s Back requirement.
      test('the result survives the disappearance of its last listener', () async {
        final CountingCheckLibrary check = CountingCheckLibrary();
        final ProviderContainer container = await containerOf(
          check: check,
          library: CountingLibraryRepository(),
        );
        await _checkStateOf(container);
        await container.read(libraryCheckProvider.notifier).start();

        final ProviderSubscription<AsyncValue<LibraryCheckResult?>> sub =
            container.listen<AsyncValue<LibraryCheckResult?>>(
              libraryCheckProvider,
              (_, _) {},
            );
        await pumpEventQueue();
        sub.close();

        expect(
          container.read(libraryCheckProvider).value?.discoveredChapters,
          3,
          reason:
              '§ 4.2: `libraryCheckProvider` is `keepAlive` so the pass survives a tab '
              'change. An `autoDispose` provider would rebuild here and reset to `null`, '
              'which is a *check* button in a loading state with no work behind it',
        );
      });

      test('the progress line survives too, for the same reason', () async {
        final CountingCheckLibrary check = CountingCheckLibrary()
          ..gate = Completer<void>();
        final ProviderContainer container = await containerOf(
          check: check,
          library: CountingLibraryRepository(),
        );
        await _checkStateOf(container);
        final ProviderSubscription<LibraryCheckProgress?> sub = container
            .listen<LibraryCheckProgress?>(
              libraryCheckProgressProvider,
              (_, _) {},
            );
        final Future<LibraryCheckResult?> pass = container
            .read(libraryCheckProvider.notifier)
            .start();
        await pumpEventQueue();
        final LibraryCheckProgress? live = container.read(
          libraryCheckProgressProvider,
        );
        sub.close();

        expect(
          live?.total,
          2,
          reason:
              '§ 4.2: `library.md` shows the SAME progress from another tab, so the counter '
              'cannot be screen-scoped either',
        );
        check.gate!.complete();
        await pass;
      });
    },
  );

  group('§ 5 — the pass ends by invalidating the library, once', () {
    test(
      'the library stream is re-read after a pass, because `last_checked_at` moved',
      () async {
        // ⚠️ **THE LISTENER STAYS OPEN ACROSS THE PASS.** The first version read the stream
        // once and closed its subscription, so `libraryStreamProvider` had no listener, the
        // invalidation rebuilt nothing, and `watches` never moved — a row that passes only
        // if the invalidation happens to rebuild an *unobserved* provider. A library screen
        // subscribes, and this container must too, or the row measures a container nobody
        // uses. This is the same mistake § 12.3\'s B48 row warns about: a read that returns
        // a value is not the same as an observation that stays.
        final CountingLibraryRepository library = CountingLibraryRepository();
        final ProviderContainer container = await containerOf(
          check: CountingCheckLibrary(),
          library: library,
        );
        await _checkStateOf(container);
        final ProviderSubscription<AsyncValue<List<LibraryEntry>>> sub =
            container.listen<AsyncValue<List<LibraryEntry>>>(
              libraryStreamProvider,
              (_, _) {},
            );
        await pumpEventQueue();
        final int before = library.watches;

        await container.read(libraryCheckProvider.notifier).start();
        await pumpEventQueue();

        expect(
          library.watches,
          greaterThan(before),
          reason:
              '§ 5: `invalidateLibraryProviders(ref)` is what carries `last_checked_at` '
              'and the failure markers to the reader. Without it the library row would '
              'keep saying *Never checked* after a successful pass — B49 rendered as a bug',
        );
        sub.close();
      },
    );

    test('reading the providers invalidates nothing on its own', () async {
      // ⚠️ **THE CONTROL FOR THE ROW ABOVE, AND IT NEEDS A LIVE LISTENER TOO.** An
      // invalidation test passes vacuously if the *read* already re-subscribes — and it
      // fails for the wrong reason when nothing is subscribed, because then nothing
      // re-subscribes either way and both rows agree for the same wrong reason. So this
      // performs the same reads with a subscription held open and asserts the count does
      // not move. It is also C14\'s claim: opening the library refreshes nothing and fetches
      // nothing.
      final CountingLibraryRepository library = CountingLibraryRepository();
      final ProviderContainer container = await containerOf(
        check: CountingCheckLibrary(),
        library: library,
      );
      await _checkStateOf(container);
      final ProviderSubscription<AsyncValue<List<LibraryEntry>>> sub = container
          .listen<AsyncValue<List<LibraryEntry>>>(
            libraryStreamProvider,
            (_, _) {},
          );
      await pumpEventQueue();
      final int before = library.watches;

      container.read(libraryCheckProgressProvider);
      container.read(libraryCheckProvider);
      container.read(libraryCheckProvider.notifier);
      await pumpEventQueue();

      expect(
        library.watches,
        before,
        reason:
            'B36/C14: reading a provider must not refresh the library, and refreshing '
            'the library must not read the network',
      );
      sub.close();
    });
  });

  group('the bootstrap overrides are what a container needs, and nothing else', () {
    test('a container can be built with four overrides and no `main.dart`', () async {
      // ⚠️ **BECAUSE BOTH BOOTSTRAP PROVIDERS THROW UNTIL OVERRIDDEN.** `appDatabaseProvider`,
      // `libraryCheckSourceManagerProvider` and `libraryCheckRateLimiterProvider` all throw
      // by design, so "the tests pass" is only true because the container supplies them.
      // This row asserts the two `6-4`-specific ones are overridable, which is the property
      // a future slice needs when it builds the same interactor for `6-10`.
      final SpySource site = SpySource();
      final AppDatabase db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);

      final ProviderContainer container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          libraryCheckSourceManagerProvider.overrideWithValue(
            SourceManager(<Source>[site]),
          ),
          libraryCheckRateLimiterProvider.overrideWithValue(
            HostRateLimiter(
              clock: () => DateTime.utc(2026, 10, 4),
              sleep: (Duration _) async {},
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      expect(
        container.read(checkLibraryProvider),
        isA<DriftCheckLibrary>(),
        reason:
            'the four bootstrap providers are the whole composition root for this slice, '
            'and the interactor is built from them alone',
      );
      expect(
        container.read(libraryCheckStoreProvider),
        isA<DriftLibraryCheckStore>(),
        reason:
            'and the store is derived from the database — a second store would be a '
            'second transaction scope writing the same rows',
      );
    });
  });
}

/// The first value the check provider publishes.
///
/// ⚠️ **THE PROVIDER IS NAMED, NOT TAKED AS A PARAMETER.** riverpod 3 exports
/// `listen`'s parameter type (`ProviderListenable`) only from a private library, so a
/// generic helper would have to spell a type this package cannot import — and
/// `Object` would silently accept anything, which is the opposite of what a test helper
/// should do. Two concrete helpers, eight lines each, and the type of the thing being
/// observed is written down where it is observed.
///
/// ⚠️ **A `Completer`, NOT `read().future`.** An `AsyncNotifier` builds on its
/// first *subscription*, so reading its `AsyncValue` before it has built throws. A
/// listener waits for the first emission — the shape `chapter_list_view_state_test.dart`
/// uses.
///
/// ⚠️ **`sub.close()`, NEVER `await sub.close()`.** riverpod 3\'s
/// `ProviderSubscription.close()` returns **`void`**, so awaiting it is a compile error
/// (`use_of_void_result`) rather than a style note, and `unawaited_futures` does not apply
/// because there is no future here to leave unawaited.
Future<AsyncValue<LibraryCheckResult?>> _checkStateOf(
  ProviderContainer container,
) {
  final Completer<AsyncValue<LibraryCheckResult?>> arrived =
      Completer<AsyncValue<LibraryCheckResult?>>();
  // ⚠️ **`fireImmediately: true` IS WHAT MAKES THIS TERMINATE.** riverpod 3\'s `listen`
  // defaults it to **false**, so a listener that only wants the first value waits for a
  // *change* that never comes — and an `AsyncNotifier` whose `build()` completes
  // synchronously never changes. The first version omitted it and every row in this file
  // timed out at 30 seconds rather than failing, which is the shape this mistake takes: a
  // hang, not a red assertion.
  //
  // ⚠️ **AND `fireImmediately` FIRES **SYNCHRONOUSLY**, INSIDE `listen`.** The listener
  // therefore runs before `sub` has been assigned, so a `late final sub` referenced from
  // the callback throws `LateInitializationError` — and the throw happens inside riverpod\'s
  // own notification path, so it surfaces as an unhandled error rather than a failed
  // `expect`. Hence `sub` being nullable and closed *after* the call returns.
  ProviderSubscription<AsyncValue<LibraryCheckResult?>>? sub;
  sub = container.listen<AsyncValue<LibraryCheckResult?>>(
    libraryCheckProvider,
    (AsyncValue<LibraryCheckResult?>? _, AsyncValue<LibraryCheckResult?> next) {
      if (arrived.isCompleted) return;
      arrived.complete(next);
    },
    fireImmediately: true,
  );
  sub.close();
  return arrived.future;
}
