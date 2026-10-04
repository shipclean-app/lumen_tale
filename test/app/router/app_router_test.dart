// Lumen Tale — `0-5` § 11.1, the route table as data.
//
// Four kinds of claim are checked here, and they are not interchangeable:
//
//  1. **The order of the five destinations** is ADR-018's, asserted in BOTH
//     directions. A one-directional assertion passes for an enum whose declaration
//     order and `rank` disagree, which is the exact shape of the defect.
//  2. **The paths** are the fifteen `design-system.md` § 3.5 lists, the three that
//     were removed are absent, and no builder leaks a `:param` into a location.
//  3. **The labels**, in both languages — B28.
//  4. **Shape of the source**, by grep: the router is a top-level `final`, the
//     bootstrap awaits its preferences, and nothing redirects to onboarding. These
//     have no runtime witness, because the code they forbid is absent. Those rows
//     live in `test/app/shell/app_shell_test.dart`, beside the widgets the wiring
//     mounts.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart' show GoRouterState;
import 'package:lumen_tale/app/router/app_nav_destinations.dart';
import 'package:lumen_tale/app/router/app_router.dart';
import 'package:lumen_tale/app/router/app_routes.dart';
import 'package:lumen_tale/app/router/screen_registry.dart';
import 'package:lumen_tale/l10n/generated/app_localizations.dart';
import 'package:lumen_tale/main.dart';

/// ADR-018's order, written out independently of the enum so the assertion has
/// something to fail against.
const List<AppNavDestination> adr018Order = <AppNavDestination>[
  AppNavDestination.library,
  AppNavDestination.updates,
  AppNavDestination.history,
  AppNavDestination.browse,
  AppNavDestination.more,
];

/// The fifteen paths of § 3.5, as one list, so every row about "the table" reads
/// the same object. Written out longhand on purpose: deriving it from `AppRoutes`
/// would make the assertion compare the table with itself.
const List<String> theFifteenRoutes = <String>[
  AppRoutes.library,
  AppRoutes.updates,
  AppRoutes.history,
  AppRoutes.browse,
  AppRoutes.more,
  AppRoutes.novelDetails,
  AppRoutes.sourceBrowse,
  AppRoutes.sourceGenre,
  AppRoutes.sourceUnavailable,
  AppRoutes.downloads,
  AppRoutes.settings,
  AppRoutes.settingsReader,
  AppRoutes.settingsAbout,
  AppRoutes.reader,
  AppRoutes.onboarding,
];

void main() {
  group('the order of the bottom nav', () {
    test('the five destinations are in ADR-018 order', () {
      expect(appNavDestinations, adr018Order);
    });

    test('declaration order and rank agree, in both directions', () {
      expect(AppNavDestination.values, hasLength(adr018Order.length));
      for (int i = 0; i < AppNavDestination.values.length; i++) {
        expect(
          AppNavDestination.values[i].rank,
          i + 1,
          reason:
              '${AppNavDestination.values[i].name} sits at index $i but claims '
              'rank ${AppNavDestination.values[i].rank}',
        );
      }
    });

    test('Library is first because it opens the loop, not by default', () {
      // § 3.2's reasons, in weight order. The first is frequency; the second — "the
      // only screen that can open the loop" — is the one a default cannot reproduce,
      // because a default never asks.
      const AppNavDestination library = AppNavDestination.library;
      expect(library.rank, 1);
      expect(library.frequency, 5);
      expect(library.centrality, 5);
      expect(
        library.frequency,
        greaterThanOrEqualTo(AppNavDestination.more.frequency),
      );
      expect(AppNavDestination.more.rank, 5);
    });

    test('every destination has an icon pair and the two differ', () {
      for (final AppNavDestination destination in AppNavDestination.values) {
        expect(
          destination.icon,
          isNot(destination.selectedIcon),
          reason:
              '${destination.name} would be indistinguishable when selected if its '
              'two icons were the same glyph',
        );
      }
    });

    test('there is one branch navigator key per destination', () {
      // The keys are indexed by `rank - 1`. A mismatch would put the History
      // branch's Navigator on the Library key: both branches would then share one
      // Navigator and both stacks would be one stack, silently.
      expect(branchKeys, hasLength(AppNavDestination.values.length));
      expect(
        branchKeys.toSet(),
        hasLength(AppNavDestination.values.length),
        reason: 'two branches sharing one GlobalKey is one stack, not two',
      );
    });
  });

  group('the paths', () {
    test('there are exactly fifteen, which is what § 3.5 lists', () {
      expect(theFifteenRoutes, hasLength(15));
      expect(theFifteenRoutes.toSet(), hasLength(15));
    });

    test(
      'every path is absolute, has no trailing slash and no empty segment',
      () {
        for (final String path in theFifteenRoutes) {
          expect(path, startsWith('/'), reason: path);
          expect(path, isNot(endsWith('/')), reason: path);
          expect(path, isNot(contains('//')), reason: path);
        }
      },
    );

    test('the removed routes are absent', () {
      // `/library/novel/:novelId/chapter/:chapterId` was removed from § 3.5: every
      // screen that opens a chapter pushes `/reader/…`, so two URLs for one
      // destination is a route table with two truths. `/more/sources` and
      // `/more/stats` went with slices 6-9 and 6-8 and no v1 rule needs them.
      //
      // Declaring them would produce destinations a reader can reach and that do
      // nothing — and `flutter analyze` would not say a word, because an unreachable
      // screen is not a compile error.
      for (final String removed in <String>[
        '/more/sources',
        '/more/stats',
        '/library/novel/:novelId/chapter/:chapterId',
      ]) {
        expect(
          theFifteenRoutes,
          isNot(contains(removed)),
          reason: '$removed was removed from v1 and must not come back',
        );
      }
    });

    test('the builders produce the locations their patterns describe', () {
      expect(AppRoutes.readerFor('n1', 'c1'), '/reader/n1/c1');
      expect(AppRoutes.novelDetailsFor('n1'), '/library/novel/n1');
      expect(AppRoutes.sourceBrowseFor('fanmtl'), '/browse/fanmtl');
      expect(
        AppRoutes.sourceGenreFor('fanmtl', 'contemporary-romance'),
        '/browse/fanmtl/genre/contemporary-romance',
      );
      expect(
        AppRoutes.sourceUnavailableFor('fanmtl'),
        '/browse/fanmtl/unavailable',
      );
    });

    test('no builder leaks a `:param` into its result', () {
      // `go()` takes a **location**; `GoRoute.path` takes a **pattern**; the two
      // differ by exactly the `:param`. A builder that interpolated from the pattern
      // yields `/reader/:novelId/a/b`, which MATCHES the route, resolves to the
      // literal string ":novelId", and opens a novel that does not exist — with
      // nothing thrown.
      final List<String> locations = <String>[
        AppRoutes.readerFor('n1', 'c1'),
        AppRoutes.novelDetailsFor('n1'),
        AppRoutes.sourceBrowseFor('s1'),
        AppRoutes.sourceGenreFor('s1', 'g1'),
        AppRoutes.sourceUnavailableFor('s1'),
        AppRoutes.settingsReaderPath(),
        AppRoutes.settingsAboutPath(),
        AppRoutes.downloadsPath(),
      ];
      for (final String location in locations) {
        expect(location, isNot(contains(':')), reason: location);
      }
    });

    test('every builder output has its pattern segment count', () {
      // The row that would have caught the leak above, and the one that keeps
      // catching it: a location whose arity differs from its pattern cannot match it.
      void expectShape(String pattern, String location) {
        expect(
          pattern.split('/').length,
          location.split('/').length,
          reason: '$location does not have the segment count of $pattern',
        );
      }

      expectShape(AppRoutes.reader, AppRoutes.readerFor('n1', 'c1'));
      expectShape(AppRoutes.novelDetails, AppRoutes.novelDetailsFor('n1'));
      expectShape(AppRoutes.sourceBrowse, AppRoutes.sourceBrowseFor('s1'));
      expectShape(AppRoutes.sourceGenre, AppRoutes.sourceGenreFor('s1', 'g1'));
      expectShape(
        AppRoutes.sourceUnavailable,
        AppRoutes.sourceUnavailableFor('s1'),
      );
      expectShape(AppRoutes.settingsReader, AppRoutes.settingsReaderPath());
      expectShape(AppRoutes.settingsAbout, AppRoutes.settingsAboutPath());
      expectShape(AppRoutes.downloads, AppRoutes.downloadsPath());
    });

    test('there is no sharing, export, account or sync route — B4, B30', () {
      // B4: no account, no sign-in, no identity on the device.
      // B30: nothing a novel or a chapter can be sent, exported or copied out of.
      //
      // Both are implemented by the **absence** of a surface: there is no such route
      // to disable, so there is nothing to revoke. Naming the forbidden words is what
      // makes the absence checkable instead of a claim.
      for (final String forbidden in <String>[
        'login',
        'signin',
        'signup',
        'account',
        'profile',
        'sync',
        'share',
        'export',
        'backup',
      ]) {
        for (final String path in theFifteenRoutes) {
          expect(
            path.toLowerCase(),
            isNot(contains(forbidden)),
            reason: '$path is a $forbidden route, which B4 and B30 forbid',
          );
        }
      }
    });
  });

  group('the tab labels, in both languages — B28', () {
    test('all five labels resolve in both locales, and none is empty', () async {
      // ⚠️ This row **failed** until this slice wrote `navMore`. `0-5` § 7 question 3
      // recorded that four of the five tab labels existed in the ARB files and the
      // fifth did not, and the plan called the failure "the correct outcome while
      // the `localisation` foundation has not written the key". The foundation **is**
      // built, and it did not write it — so the row was not a demonstration, it was
      // a defect that would have shipped. B28 is not satisfied by four of five.
      for (final AppLocalizations l10n in <AppLocalizations>[
        await AppLocalizations.delegate.load(const Locale('en')),
        await AppLocalizations.delegate.load(const Locale('fr')),
      ]) {
        for (final AppNavDestination destination in appNavDestinations) {
          expect(
            destination.label(l10n).trim(),
            isNotEmpty,
            reason: '${destination.name} has no label in ${l10n.localeName}',
          );
        }
      }
    });

    test('the labels are § 3.2 word for word, in both languages', () async {
      final AppLocalizations en = await AppLocalizations.delegate.load(
        const Locale('en'),
      );
      final AppLocalizations fr = await AppLocalizations.delegate.load(
        const Locale('fr'),
      );
      expect(AppNavDestination.library.label(en), 'Library');
      expect(AppNavDestination.library.label(fr), 'Bibliothèque');
      expect(AppNavDestination.updates.label(en), 'Updates');
      expect(AppNavDestination.updates.label(fr), 'Mises à jour');
      expect(AppNavDestination.history.label(en), 'History');
      expect(AppNavDestination.history.label(fr), 'Historique');
      expect(AppNavDestination.browse.label(en), 'Browse');
      expect(AppNavDestination.browse.label(fr), 'Parcourir');
      // § 3.2: "More / Plus". Not "Settings", not "Menu" — the overflow row holds
      // configuration and transfers, and a label promising settings lies about three
      // of its rows.
      expect(AppNavDestination.more.label(en), 'More');
      expect(AppNavDestination.more.label(fr), 'Plus');
    });
  });

  group('B28 — the French fallback chain', () {
    const List<Locale> supported = AppLocalizations.supportedLocales;

    test('French resolves to French, English to English', () {
      expect(
        resolveLocaleForTesting(<Locale>[const Locale('fr')], supported),
        const Locale('fr'),
      );
      expect(
        resolveLocaleForTesting(<Locale>[const Locale('en')], supported),
        const Locale('en'),
      );
    });

    test('fr_CA resolves to French by language code, not by string equality', () {
      // E12. `Locale('fr', 'CA')` is not equal to `Locale('fr')`, and comparing the
      // whole string is exactly the mistake that sends Canadian French to the English
      // ARB template.
      expect(
        resolveLocaleForTesting(<Locale>[const Locale('fr', 'CA')], supported),
        const Locale('fr'),
      );
    });

    test('an unrecognised language falls back to FRENCH, not to English', () {
      // The whole reason the callback exists. Without it `MaterialApp` falls back to
      // the first of `supportedLocales`, which is the ARB template's `en`.
      for (final Locale unsupported in <Locale>[
        const Locale('de'),
        const Locale('ja', 'JP'),
        const Locale('zh'),
        const Locale('pt', 'BR'),
        const Locale('ru'),
      ]) {
        expect(
          resolveLocaleForTesting(<Locale>[unsupported], supported),
          const Locale('fr'),
          reason: '${unsupported.languageCode} must resolve to French',
        );
      }
    });

    test('no preferred locale at all falls back to French', () {
      expect(resolveLocaleForTesting(null, supported), const Locale('fr'));
      expect(
        resolveLocaleForTesting(const <Locale>[], supported),
        const Locale('fr'),
      );
    });

    test('the first recognisable entry in the list wins', () {
      // A phone set to `de` then `fr` speaks French. Scanning only the first entry is
      // what `localeResolutionCallback` does, and it is why the LIST callback is the
      // one this app passes.
      expect(
        resolveLocaleForTesting(<Locale>[
          const Locale('de'),
          const Locale('en'),
        ], supported),
        const Locale('en'),
      );
      expect(
        resolveLocaleForTesting(<Locale>[
          const Locale('de'),
          const Locale('fr'),
        ], supported),
        const Locale('fr'),
      );
    });
  });

  group('the standalone registry — routes outside the shell', () {
    test('⚠️ /reader IS registered, and a placeholder there is a dead end', () {
      // ⚠️ **The reader is reached by `push` from four places** — the library row, the
      // novel's details, the reader's own chapter sheet and history. An unregistered reader
      // is therefore not a visible placeholder but a route that opens nothing, and nothing
      // in a smoke test would say so: every other screen in the app is reached by `go` from
      // a tab, and `go` to a missing route rebuilds the shell.
      clearRegisteredScreens();
      registerScreens();

      expect(registeredStandaloneRoutes, contains(AppRoutes.reader));
      expect(registeredScreens, contains(AppRoutes.history));
    });

    test('⚠️ the reader path carries BOTH ids and no ordinal', () {
      // ⚠️ **`ordinal` is deliberately absent.** `2-3` names a stored file after the row's
      // ordinal, and the repository reads that from the row — so a URL carrying an ordinal
      // would be a second copy of a fact with a second chance to be wrong, and a wrong one
      // opens a *different chapter's* prose with no error anywhere.
      expect(AppRoutes.reader, '/reader/:novelId/:chapterId');
      expect(AppRoutes.reader, isNot(contains('ordinal')));
      expect(AppRoutes.reader, isNot(contains('?o')));
      expect(AppRoutes.readerFor('n1', 'c1'), '/reader/n1/c1');
    });

    test('registration replaces rather than duplicating', () {
      // ⚠️ Two answers to one route, and the second is the one nobody reviewed.
      registerStandaloneRoute(
        '/x',
        (BuildContext _, GoRouterState _) => const SizedBox.shrink(),
      );
      registerStandaloneRoute(
        '/x',
        (BuildContext _, GoRouterState _) => const SizedBox.shrink(),
      );
      expect(
        registeredStandaloneRoutes.keys.where((String k) => k == '/x'),
        hasLength(1),
      );
      clearRegisteredScreens();
    });
  });
}
