import 'package:drift/drift.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart' show GoRouterState;
import 'package:lumen_tale/app/router/app_router.dart';
import 'package:lumen_tale/app/router/app_routes.dart';
import 'package:lumen_tale/app/router/first_run_gate.dart';
import 'package:lumen_tale/app/router/screen_registry.dart';
import 'package:lumen_tale/app/theme/app_theme.dart';
import 'package:lumen_tale/app/theme/app_theme_preferences.dart';
import 'package:lumen_tale/app/theme/app_version.dart';
import 'package:lumen_tale/app/theme/theme_providers.dart';
import 'package:lumen_tale/core/background/check_job_engine.dart'
    show checkJobAppVersionKey;
import 'package:lumen_tale/core/background/check_job_interlock.dart';
import 'package:lumen_tale/core/database/app_database.dart';
import 'package:lumen_tale/core/database/app_database_provider.dart';
import 'package:lumen_tale/core/network/host_rate_limiter.dart';
import 'package:lumen_tale/core/storage/onboarding_seen.dart';
import 'package:lumen_tale/core/storage/shared_preferences_provider.dart';
import 'package:lumen_tale/data/background/check_job_entry_point.dart';
import 'package:lumen_tale/data/background/check_job_providers.dart';
import 'package:lumen_tale/data/library/drift_library_repository.dart';
import 'package:lumen_tale/data/library/drift_reading_position_store.dart';
import 'package:lumen_tale/data/library/library_providers.dart';
import 'package:lumen_tale/data/reader/chapter_row.dart';
import 'package:lumen_tale/data/reader/local_chapter_reader_repository.dart';
import 'package:lumen_tale/data/sources/source_manager.dart';
import 'package:lumen_tale/data/updates/check_library_providers.dart';
import 'package:lumen_tale/domain/reader/chapter_reader_repository.dart';
import 'package:lumen_tale/domain/sources/models/novel.dart';
import 'package:lumen_tale/features/about/about_screen.dart';
import 'package:lumen_tale/features/browse/catalogue_screen.dart';
import 'package:lumen_tale/features/downloads/providers.dart';
import 'package:lumen_tale/features/downloads/providers/download_queue_provider.dart'
    show chapterWriterProvider;
// ⚠️ `sourceManagerProvider` IS DECLARED IN TWO FEATURES — the browse repository's and the
// queue's. `hide` rather than a prefix: main.dart uses the browse one, and a prefix here
// would import a second name for the same concept.
import 'package:lumen_tale/features/downloads/screens/downloads_screen.dart';
import 'package:lumen_tale/features/downloads/stored_chapter_writer.dart';
import 'package:lumen_tale/features/history/history_screen.dart';
import 'package:lumen_tale/features/library/library_screen.dart';
import 'package:lumen_tale/features/novel_details/novel_details_screen.dart';
import 'package:lumen_tale/features/onboarding/domain/onboarding_state.dart';
import 'package:lumen_tale/features/onboarding/screens/onboarding_screen.dart';
import 'package:lumen_tale/features/reader/reader_providers.dart';
import 'package:lumen_tale/features/reader/reader_screen.dart';
import 'package:lumen_tale/features/settings/settings_screen.dart';
import 'package:lumen_tale/features/source_unavailable/failure_cause.dart';
import 'package:lumen_tale/features/source_unavailable/source_unavailable_screen.dart';
import 'package:lumen_tale/l10n/generated/app_localizations.dart';
import 'package:lumen_tale/sources/implementations/source_registry.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Bootstrap for Lumen Tale.
///
/// Wiring only: localisation, theme, router. Feature code lives under `features/`
/// and is reachable only through `app/router/app_router.dart`.
///
/// ## `main` is `async` and it AWAITS — load-bearing, not stylistic
///
/// `theme_providers.dart` declares
/// `appThemePreferencesProvider = Provider((ref) => throw
/// UnimplementedError('overridden at the bootstrap by 0-5'))`, and **this file is
/// the only place that override exists**. A synchronous `runApp` leaves the throw
/// live, and the first read of the theme is the first frame — so the app dies on
/// launch, in a way that looks like a provider bug rather than a missing override.
///
/// Two consequences, and both are the point:
///
/// - `SharedPreferences` is resolved **once**, before any route exists, so every
///   later read is synchronous. A settings-store load error is therefore
///   **unreachable** as a screen state — the failure is a *bootstrap* failure,
///   which is why `settings.md` § 4 struck that state.
/// - `MissingPluginException` is **not** caught. An app that cannot persist a
///   setting must not pretend it can; swallowing this would give the reader a
///   switch that silently does nothing.
/// Registers every screen the router can build, by **path**.
///
/// ⚠️ **Extracted from `main()` so it is testable**, and the extraction is the reason the
/// composition root is worth having as a function rather than as code inside `runApp`'s
/// neighbourhood: a registration that can only happen by running the app cannot be asserted,
/// and an unassertable registration is how `/reader` ends up a route that opens nothing.
///
/// `app/` still imports no `features/` **package** — these are function bodies reached
/// through the registry, and `test/app/shell/app_shell_test.dart` greps the import lines.
void registerScreens() {
  registerScreen(
    AppRoutes.novelDetails,
    // ⚠️ **`sourceName` is EMPTY, and that is the screen's own documented contract** —
    // `ChapterListHeader.sourceName` says an empty string means "do not name a site",
    // and the header then prints the bare count.
    //
    // ⚠️ **The URL carries a novel id and nothing else, so a name read from the path
    // would be an invention.** A deep link knows which novel, not which site published
    // it; printing `/library/novel/n1` as though it were a site name would put an
    // identifier where a reader expects a publication. A future slice that knows the
    // source can pass it here — as a value, never as something parsed out of the path.
    (BuildContext context, GoRouterState state) => NovelDetailsScreen(
      novelId: state.pathParameters['novelId']!,
      // ⚠️ **THE CATALOGUE'S NOVEL, WHEN IT BROUGHT ONE** — see `openNovelDetails`. A deep
      // link has no `extra`, and that is not a failure: the screen reads the stored row
      // instead, and a novel that is neither stored nor carried is a state it can describe.
      novel: state.extra is Novel ? state.extra! as Novel : null,
      sourceName: '',
      currentChapterId: state.uri.queryParameters['chapter'],
    ),
  );
  registerScreen(
    AppRoutes.sourceUnavailable,
    // ⚠️ **`pathParameters['failure']` is a CAUSE NAME, not a failure object.** A failure is
    // not serialisable and must not be reconstructed from a URL — so the route names the
    // cause and the screen rebuilds the typed failure from it. That keeps B24's rule (a
    // typed reason, never a string) intact through a navigation boundary, and it means a
    // stale deep link cannot invent a cause this build does not have.
    (BuildContext context, GoRouterState state) => SourceUnavailableScreen(
      sourceId: state.pathParameters['sourceId']!,
      sourceName: state.pathParameters['sourceId']!,
      failure: failureFromCauseName(
        state.uri.queryParameters['cause'] ?? 'unreadable-record',
      ),
    ),
  );
  registerScreen(
    AppRoutes.sourceGenre,
    // ⚠️ **ONE route, TWO modes — `?q=` is the discriminator, and it is `null` for a
    // catalogue and non-null for a search.** `browse-catalogue.md` § 1.1 asks for one screen
    // rather than two, because the two differ in a query field and a set of rows and nothing
    // else; two screens would be two copies of the list to keep in step.
    //
    // ⚠️ **An empty `?q=` is STILL a search.** `q=` in the URL and `q` absent are different
    // requests, and collapsing them would mean this app deciding that an empty field means "show
    // me the catalogue" — which is the site's decision to make, not ours.
    //
    // ⚠️ `supportsSearch` is NOT passed: it is the source's own answer, it lives in the
    // registry, and the screen reads it from the same repository it reads the catalogue from. A
    // builder that looked it up would be a second place where "does this site have search" is
    // decided.
    (BuildContext context, GoRouterState state) => CatalogueScreen(
      sourceId: state.pathParameters['sourceId']!,
      tag: state.pathParameters['genre']!,
      words: state.uri.queryParameters['q'],
      // ⚠️ **`?page=` IS READ HERE AND NOWHERE ELSE.** One parse, one place: a screen that
      // resolved its own page could disagree with the router about which page is showing.
      page: AppRoutes.pageFrom(state.uri),
    ),
  );
  registerScreen(
    AppRoutes.library,
    (BuildContext context, GoRouterState state) => const LibraryScreen(),
  );
  registerScreen(
    AppRoutes.history,
    (BuildContext context, GoRouterState state) => const HistoryScreen(),
  );
  registerScreen(
    AppRoutes.settingsAbout,
    (BuildContext context, GoRouterState state) => const AboutScreen(),
  );
  registerScreen(
    AppRoutes.settings,
    (BuildContext context, GoRouterState state) => const SettingsScreen(),
  );
  // ⚠️ **`5-2`'s SCREEN, AND IT IS THE ROUTE `downloads.md` § 3 IS WRITTEN FOR.**
  //
  // `/more/downloads` is where the reader pauses, resumes and cancels a queue, and where
  // E7's standing notice lives. It renders a `PlaceholderScreen` until this line exists —
  // and the registration alone would not have been enough, because `app_router.dart`'s
  // `_subRoutesFor` also had to resolve it by the FULL constant. `test/app/router/
  // route_resolution_test.dart` asserts both halves, which is the whole reason it exists.
  registerScreen(
    AppRoutes.downloads,
    (BuildContext context, GoRouterState state) => const DownloadsScreen(),
  );
  // ⚠️ **The reader registers as a STANDALONE route, not a screen.**
  //
  // `/reader/:novelId/:chapterId` is outside the shell — no tab bar, no transition — so it
  // is resolved through `standaloneRouteBuilderFor` and reaches `app/` by no other name
  // than its path. The same rule as every other registration above, applied to the one
  // route that is not a shell destination.
  registerStandaloneRoute(
    AppRoutes.reader,
    (BuildContext context, GoRouterState state) =>
        ReaderScreen(chapterId: state.pathParameters['chapterId']!),
  );
  // ⚠️ **`3-4`'s screen, AND THE SECOND STANDALONE REGISTRATION.**
  //
  // `/onboarding` is outside the shell — `design-system.md` § 3.5 puts a first-run flow in
  // overflow's rationale table with **no label at all**, so there is no tab bar to be inside
  // of. Registering it here is what stops the route from rendering a `PlaceholderScreen` on
  // the one screen E11 makes mandatory; before this line a first run landed on a page naming
  // `/onboarding`, which is the exact failure `test/app/router/route_resolution_test.dart`
  // was written for and could not see.
  registerStandaloneRoute(
    AppRoutes.onboarding,
    // ⚠️ **THE ENTRY STEP IS READ FROM THE QUERY, AND THE CONSTANTS COME FROM
    // `AppRoutes`.** The cold-start redirect pushes the bare path (step 1, § 3.1) and
    // `openOnboarding` pushes `?step=disclosure`, so the *route* decides which step opens —
    // there is no second table of "who entered from where" that could disagree with the URL
    // a restored stack comes back with.
    //
    // Anything that is not the disclosure value opens on step 1. A malformed parameter is a
    // cold start, not a re-read: showing the promise again to a reader who has already read
    // it is the recoverable direction, and it is the same reasoning as `readFailsOpen`.
    (BuildContext context, GoRouterState state) => OnboardingScreen(
      initialStep:
          state.uri.queryParameters[AppRoutes.onboardingStepQuery] ==
              AppRoutes.disclosureStepValue
          ? OnboardingStep.disclosure
          : OnboardingStep.promise,
    ),
  );
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final SharedPreferences prefs = await SharedPreferences.getInstance();

  // ⚠️ **Registration, and only registration.**
  //
  // `architecture.md` § 3.1a forbids `app/` importing a feature, while saying a screen
  // *is* a route. The registry is the way out, and **this file is the composition root** —
  // the one place whose job is to know about every layer at once. It already overrides
  // three providers drawn from three layers; the screens join that list.
  //
  // A destination with no entry renders a placeholder rather than throwing, so a slice that
  // lands without registering is visible in one second of running the app — except for the
  // reader, which is reached by `push` from four places, and which `registerScreens` is
  // extracted so a row can assert it.
  //
  // ⚠️ **CALLED ONCE. It was called twice here**, and the second call carried a comment
  // describing it as deliberate. `registerScreen` assigns into a map, so the second call
  // overwrote the first with identical builders and changed nothing — which is exactly
  // why it survived: a duplicate that happens to be idempotent is invisible at runtime
  // and meaningless in review, and it still reads as two registrations to anyone who
  // later makes `registerScreen` do something order-dependent.
  registerScreens();

  // ⚠️ **THE COLD-START GATE, INSTALLED ONCE, BEFORE `runApp`.** E11 needs the "nothing here
  // is backed up" disclosure made *before* an uninstall, and the only moment the app can put
  // a screen in front of the reader on its own is first run — so the decision lives in the
  // router's `redirect` (`first_run_gate.dart`) rather than here, and what this line supplies
  // is the flag reader the redirect cannot obtain for itself.
  //
  // `appRouter` is a top-level `final` and cannot read a Riverpod container (its header gives
  // the reason), and `prefs` is resolved above, so the store is constructed here and handed
  // over. **`main()` is the composition root**, which is why this is the right place and why
  // `test/app/shell/app_shell_test.dart` counts the call: a missing installation is invisible
  // at runtime — the app simply never shows onboarding.
  await installStartupGate(
    OnboardingStartupGate(
      SharedPreferencesOnboardingSeenStore(prefs).readFailsOpen,
    ),
  );

  // ⚠️ **B37's ENGINE IS INITIALISED HERE, BEFORE `runApp`, AND IT IS NOT OPTIONAL.**
  //
  // `6-10` § 3.5 gives the order and the reason: `executeTask` registers its handlers on
  // the isolate's messenger and the platform calls the dispatcher afterwards, so a task that
  // ran before the handlers existed would find an engine with nothing to receive it. The
  // same section installs the progress listener, which is the app-side half of the bridge a
  // background isolate's integers travel over.
  //
  // ⚠️ **`MissingPluginException` IS NOT CAUGHT HERE, for the reason the header of this
  // file gives for the theme.** An app that cannot schedule its one foreground job must not
  // pretend it can; swallowing this would give the reader a *Check* button that silently
  // does nothing.
  await initializeBackgroundCheckEngine();

  // ⚠️ **A FLAG LEFT BY A KILLED ISOLATE IS RELEASED HERE, AND NOTHING IS REGISTERED.**
  //
  // `6-10` § 3.3 branches 7 and 8: a background isolate the system takes away runs no
  // `finally` and fires no `onTaskStopped`, so the one-flight flag is the only evidence that
  // anything was in flight. Releasing it makes the next tap work.
  //
  // ⚠️ **NO RESUME AND NO RE-REGISTRATION, AND BOTH ARE RULES.** Resuming would complete an
  // interrupted pass from a partial state, which B20 forbids; registering anything would make
  // *opening the app* a trigger, which is B36 — and ADR-023 withdrew the schedule, so there
  // is nothing to re-arm.
  await releaseStaleCheckJobFlag(SharedPreferencesCheckJobInterlock(prefs));

  runApp(
    ProviderScope(
      overrides: [
        appThemePreferencesProvider.overrideWithValue(
          SharedPrefsThemePreferences(prefs),
        ),
        // ⚠️ **THE SOURCE-NAME RESOLVER, AND `6-6` IS WHY IT IS HERE.**
        //
        // `DriftLibraryRepository`'s constructor defaults `sourceNameOf` to a function that
        // returns the literal `'unknown'`, and the library rows print it — so every row in
        // production read *unknown* where a site name belongs. The seam was there; nothing
        // supplied it.
        //
        // ⚠️ **ONE REGISTRY, PER ADR-013.** The resolver reads the SAME [sources] every other
        // caller reads. A second index built here would be a second compiled registry, and a
        // source compiled into one and not the other would print `unknown` in the library and
        // its real name in the browser — the app contradicting itself about the same site.
        // ⚠️ **THE READER'S REAL REPOSITORY — AND ITS ABSENCE MADE EVERY CHAPTER THROW.**
        //
        // `chapterReaderRepositoryProvider` is declared
        // `throw UnimplementedError('overridden in the composition root')`, and **the
        // composition root never overrode it.** Every reader test supplies a fake, so 1936
        // green tests proved nothing about this: the app's core screen would have thrown
        // `UnimplementedError` the first time a reader opened a chapter.
        //
        // ⚠️ **THIS IS THE FIFTH DEAD-CONTROL DEFECT IN ONE SHAPE.** A seam every test
        // overrides, and production does not, is a seam that is *tested* and *absent* — and
        // it is invisible to every gate, because analyze is clean, the suite is green and the
        // code says exactly what it means. The row that catches it is
        // `test/app/bootstrap_seams_test.dart`: *every provider whose body throws is
        // overridden here*.
        // ⚠️ **THE QUEUE RUNNER'S WRITER, AND IT THREW FOR THE SAME REASON.**
        //
        // `chapterWriterProvider` is declared `throw UnimplementedError('overridden at the
        // bootstrap')`, is read by `downloadQueueRunnerProvider`, and **was never
        // overridden**. So the second showstopper was live: `5-1`'s runner resolved a writer
        // that threw, and every download failed at the first chapter. Its own 137 cases pass
        // because each supplies its own writer.
        //
        // ⚠️ **THE WRITER IS AN ADAPTER AROUND THE SAME STORE THE READER USES.** Two writers
        // would mean two sets of `downloadedAt` writes and two orders for B6's two writes to
        // be wrong in.
        chapterWriterProvider.overrideWith(
          (Ref ref) => StoredChapterWriter(ref.watch(chapterStoreProvider)),
        ),
        chapterReaderRepositoryProvider.overrideWith(
          (Ref ref) => LocalChapterReaderRepository(
            rowLookup: driftChapterRowLookup(ref.watch(appDatabaseProvider)),
            // ⚠️ **THE SAME STORE THE QUEUE WRITES THROUGH.** A reader that resolved a
            // position from a different store than the one `5-1` saves to would restore an
            // offset against a chapter it has not read.
            store: ref.watch(chapterStoreProvider),
            positions: DriftReadingPositionStore(
              ref.watch(appDatabaseProvider),
            ),
            // B6-adjacent: **the mark is a column write, not a file write**, so it cannot
            // precede the store's rename. `2-3` owns `downloadedAt`; `isRead` is the
            // reader's own column and has no such ordering.
            onMarkOpened: (String chapterId) async {
              final AppDatabase db = ref.read(appDatabaseProvider);
              await (db.update(db.chapters)
                    ..where(($ChaptersTable t) => t.id.equals(chapterId)))
                  .write(const ChaptersCompanion(isRead: Value<bool>(true)));
            },
            // ⚠️ **NEIGHBOURS BY `ordinal` WITHIN THE NOVEL, AND `null` AT EITHER END.**
            // The reader's previous/next is the site's order, so a neighbour that skipped a
            // chapter would put a reader on the wrong text with no way to tell.
            onNeighbour: (String chapterId, NeighbourDirection direction) async {
              final AppDatabase db = ref.read(appDatabaseProvider);
              final ChapterRow? here =
                  await (db.select(db.chapters)
                        ..where(($ChaptersTable t) => t.id.equals(chapterId)))
                      .getSingleOrNull();
              if (here == null) return null;
              final int step = direction == NeighbourDirection.previous
                  ? -1
                  : 1;
              final List<ChapterRow> found =
                  await (db.select(db.chapters)
                        ..where(
                          ($ChaptersTable t) =>
                              t.novelId.equals(here.novelId) &
                              (step < 0
                                  ? t.ordinal.isSmallerThanValue(here.ordinal)
                                  : t.ordinal.isBiggerThanValue(here.ordinal)),
                        )
                        // ⚠️ **THE ORDER FOLLOWS THE DIRECTION, and it is the whole
                        // query.** `previous` must be the *nearest* chapter below,
                        // which is the largest ordinal under it — so `desc`. Getting
                        // this backwards puts a reader on the first chapter of the
                        // novel instead of the one before.
                        ..orderBy(<OrderClauseGenerator<$ChaptersTable>>[
                          if (step < 0)
                            ($ChaptersTable t) => OrderingTerm.desc(t.ordinal)
                          else
                            ($ChaptersTable t) => OrderingTerm.asc(t.ordinal),
                        ])
                        ..limit(1))
                      .get();
              if (found.isEmpty) return null;
              return ChapterNeighbour(
                chapterId: found.first.id,
                ordinal: found.first.ordinal,
              );
            },
          ),
        ),
        libraryRepositoryProvider.overrideWith(
          (Ref ref) => DriftLibraryRepository(
            ref.watch(appDatabaseProvider),
            sourceNameOf: (String sourceId) => sources.byId(sourceId)?.name,
          ),
        ),
        // ⚠️ **The instance `getInstance()` returned, shared.**
        //
        // Two calls return two objects over one file. The retention store and the
        // theme both read it, and the disagreement would surface as a setting that
        // reverts — with no error and no trace. `sharedPreferencesProvider` makes
        // that a fact rather than a convention.
        sharedPreferencesProvider.overrideWithValue(prefs),
        // ⚠️ **The database.**
        //
        // `appDatabaseProvider` throws until this line, for the reason the comment at
        // the top of this file gives for the theme: a synchronous `runApp` leaves the
        // throw live, and the first read is the first frame.
        //
        // `overrideWith` rather than `overrideWithValue` so the connection is **closed
        // once**: `AppDatabase()` is a `LazyDatabase`, so nothing opens until the first
        // query, and `ref.onDispose` is where a process-scoped singleton shuts its
        // handle rather than waiting for the OS.
        appDatabaseProvider.overrideWith((Ref ref) {
          final AppDatabase db = AppDatabase();
          ref.onDispose(db.close);
          return db;
        }),
        // ⚠️ **The sources, and their clients, built ONCE at the bootstrap.**
        //
        // `buildBrowseRepository` builds one `HttpClient` per registered source — never one
        // shared client, because `Dio`'s `baseUrl` is per instance and a shared one would send
        // one site's paths to another host. `05-state-management.md` rule 8: the repository is a
        // provider because it is the thing every browse screen programs against.
        //
        // The version goes into the User-Agent, and `readBuildVersion()` is a function rather
        // than a `final` precisely so this call site is where the read happens.
        sourceManagerProvider.overrideWithValue(sources),
        browseRepositoryProvider.overrideWithValue(
          buildBrowseRepository(sources),
        ),
        // ⚠️ **THE LAST TWO OVERRIDES EXIST BECAUSE `6-4`'s INTERACTOR THROWS WITHOUT THEM,
        // AND UNTIL `6-10` NOTHING DID.**
        //
        // `libraryCheckSourceManagerProvider` and `libraryCheckRateLimiterProvider` are
        // declared `throw UnimplementedError` in `data/updates/check_library_providers.dart`,
        // for a stated reason: `data/` may not import the `features/browse` provider that
        // holds the one registry, and the limiter was a *local* inside `buildSourceManager`
        // so nothing outside could name it. Both are bootstrap overrides — the same shape as
        // `appDatabaseProvider` — and `6-4` shipped without them. The consequence was not a
        // missing feature: **the Check button threw `UnimplementedError` the moment it was
        // tapped**, because `checkLibraryProvider` reads both to build `DriftCheckLibrary`.
        //
        // ⚠️ **THE SAME INSTANCES, NOT FRESH ONES.** `sources` is the registry every `Dio`
        // client already points at, and `sharedRateLimiter` is the object
        // `buildSourceManager` was handed, so a `429`'s `Retry-After` recorded by a check is
        // honoured by the very clients that will make the next request (C7). A second
        // registry would be a second set of HTTP clients (ADR-013) and a second set of
        // per-host windows — the exact hole `buildSourceManager`'s new `limiter` parameter
        // was added to close.
        libraryCheckSourceManagerProvider.overrideWithValue(sources),
        libraryCheckRateLimiterProvider.overrideWithValue(sharedRateLimiter),
        // ⚠️ **THE BUILD VERSION CROSSES INTO THE BACKGROUND ISOLATE AS TASK INPUT.**
        // `_appVersion()` is private to this file, and `data/background/` may not import
        // `app/theme/app_version.dart` — so the composition root hands it over. It is the
        // only value in `inputData`, and `inputData` is never drawn: the notification and
        // the progress map are integers and localized strings only (C2).
        checkJobInputDataProvider.overrideWithValue(<String, Object?>{
          checkJobAppVersionKey: _appVersion(),
        }),
      ],
      child: const LumenTaleApp(),
    ),
  );
}

/// The registry, built ONCE.
///
/// ⚠️ **A local, and then overridden as a value twice.** The manager is the thing both the
/// browse repository and the router's `supportsSearch` read, and a second build here would
/// give two sets of `Dio` instances and two rate limiter states — so the limiter would throttle
/// half of what it thinks it is throttling.
final SourceManager sources = buildSourceManager(
  appVersion: _appVersion(),
  limiter: sharedRateLimiter,
);

/// The **shared** per-host limiter, and a top-level `final` for the same reason
/// [sources] is one.
///
/// ⚠️ **DECLARED HERE BECAUSE TWO CALLERS MUST NAME THE SAME OBJECT.** `main.dart` hands it
/// to `buildSourceManager` *and* overrides `libraryCheckRateLimiterProvider` with it, and the
/// background isolate (`6-10`) does the same inside its own process. Building it inline at
/// either use site produced the defect this declaration exists to prevent: a limiter whose
/// table stays empty while the requests it was meant to space go straight through, so the
/// `Retry-After` a check records is honoured by nobody (C7).
final HostRateLimiter sharedRateLimiter = HostRateLimiter();

/// The version string that goes into the User-Agent.
///
/// ⚠️ **`buildName` and NOT `buildNumber`, deliberately.** The number changes on every CI run
/// and would make each build look like a different client to a site; the name changes when a
/// release does, which is what a server-side rate limit wants to see. An empty name is passed
/// through — `userAgent` renders `unknown` — rather than a placeholder that would look like a
/// real version to a site's logs.
String _appVersion() {
  final BuildVersion version = readBuildVersion();
  return version.buildName.isEmpty ? version.buildNumber : version.buildName;
}

/// Root widget.
///
/// ## ⚠️ It is a `ConsumerWidget` because B26 is applied HERE and only here
///
/// `2-8` § 3.2: *"one single call in the application, in the root widget"*. The reason is not
/// tidiness: a `Brightness` decided locally on the reader would be a **second** answer to
/// "which night is it?", and the two would diverge the first time the reader used the
/// `themeButton` from the chrome and then opened Settings, which is exactly the sequence
/// `settings-reader.md` § 2.1 calls two doors to one value.
///
/// `ThemeOverride.resolve` is the **only** translation from an override to a `ThemeMode` in
/// the project — the enum says so at its own declaration, and this line is where that claim
/// is kept.
class LumenTaleApp extends ConsumerWidget {
  const LumenTaleApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      // `go_router` holds the one instance. **Not a provider**: navigation state
      // is the router's, and `05-state-management.md` forbids a provider
      // modifying another one's state. It is also a top-level `final`
      // (`app_router.dart`), so E12's language switch cannot rebuild it.
      routerConfig: appRouter,
      onGenerateTitle: (BuildContext context) =>
          AppLocalizations.of(context).appTitle,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      // ⚠️ `localeListResolutionCallback`, **never** `localeResolutionCallback`:
      // the latter sees only the first preferred locale, so `fr_CA` would never
      // reach `fr` by language code and B28's French fallback would only apply to
      // the crudest cases.
      localeListResolutionCallback: _resolveLocale,
      theme: AppTheme.day(),
      darkTheme: AppTheme.night(),
      // ⚠️ **ADR-016: two palettes, designed separately.** `day` and `night` are not one
      // value computed from the other — a single error red measures 7.32:1 on paper and
      // 2.27:1 on ink — so this is a choice between two finished designs, not a brightness.
      //
      // ⚠️ **`MediaQuery.platformBrightnessOf` ABOVE the `MaterialApp`, and that is the
      // phone's answer rather than the app's.** Read inside, it would follow the theme this
      // very line sets, which is a loop: `system` would resolve through the value it is
      // deciding. Above, the `MediaQuery` comes from the view, so it moves when the OS moves.
      themeMode: ref
          .watch(themeOverrideProvider)
          .resolve(MediaQuery.platformBrightnessOf(context)),
    );
  }
}

/// **B28's fallback chain.** French is this project's primary locale, so an
/// unrecognised system locale resolves to French rather than silently falling back
/// to the ARB template (`en`).
///
/// Unchanged from the pre-`0-5` bootstrap, and it stays here on purpose:
/// `16-i18n.md` rule 5 names this function and this file, and
/// `architecture.md` § 3.1a says the router keeps the existing
/// `localeListResolutionCallback`. Moving it into `app/` would violate a named rule
/// for no gain.
Locale _resolveLocale(
  Iterable<Locale>? preferredLocales,
  Iterable<Locale> supportedLocales,
) {
  for (final Locale preferred in preferredLocales ?? const <Locale>[]) {
    for (final Locale supported in supportedLocales) {
      // ⚠️ **By language code, never by string equality.** `"fr_CA"` does not equal
      // `Locale('fr')`, and comparing the whole string is exactly the mistake that
      // would send Canadian French to the English ARB template.
      if (preferred.languageCode == supported.languageCode) {
        return supported;
      }
    }
  }
  return const Locale('fr');
}

/// Exposed for `test/app/router/app_router_test.dart`.
///
/// The function is **byte for byte** the one above, unchanged since the
/// localisation bootstrap, and it is exported rather than duplicated: a test that
/// re-implements it would assert a copy, and a copy is free to drift.
@visibleForTesting
Locale resolveLocaleForTesting(
  Iterable<Locale>? preferredLocales,
  Iterable<Locale> supportedLocales,
) => _resolveLocale(preferredLocales, supportedLocales);
