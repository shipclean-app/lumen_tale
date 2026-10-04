import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart' show GoRouterState;
import 'package:lumen_tale/app/router/app_router.dart';
import 'package:lumen_tale/app/router/app_routes.dart';
import 'package:lumen_tale/app/router/screen_registry.dart';
import 'package:lumen_tale/app/theme/app_theme.dart';
import 'package:lumen_tale/app/theme/app_theme_preferences.dart';
import 'package:lumen_tale/app/theme/app_version.dart';
import 'package:lumen_tale/app/theme/theme_providers.dart';
import 'package:lumen_tale/core/database/app_database.dart';
import 'package:lumen_tale/core/storage/shared_preferences_provider.dart';
import 'package:lumen_tale/data/sources/source_manager.dart';
import 'package:lumen_tale/features/about/about_screen.dart';
import 'package:lumen_tale/features/browse/catalogue_screen.dart';
import 'package:lumen_tale/features/history/history_providers.dart';
import 'package:lumen_tale/features/history/history_screen.dart';
import 'package:lumen_tale/features/library/library_screen.dart';
import 'package:lumen_tale/features/novel_details/novel_details_screen.dart';
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

  runApp(
    ProviderScope(
      overrides: [
        appThemePreferencesProvider.overrideWithValue(
          SharedPrefsThemePreferences(prefs),
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
final SourceManager sources = buildSourceManager(appVersion: _appVersion());

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
class LumenTaleApp extends StatelessWidget {
  const LumenTaleApp({super.key});

  @override
  Widget build(BuildContext context) {
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
      // `themeMode` is deliberately absent, so it is `ThemeMode.system` and the
      // phone's setting is honoured (E13). `themeOverride` — B26's explicit
      // permission for an in-app override — is applied by `2-8`, which reads the
      // provider this bootstrap overrides.
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
