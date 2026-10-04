// forge:slice 0-5
// Lumen Tale — `0-5`'s route table, and the half of registration nobody asserted.
//
// ## What this file is for
//
// `registerScreens()` registers a builder per path, and `app_router.dart` resolves each
// `GoRoute` through `screenBuilderFor(...)`. Those are two facts, and a test that only
// asserts the first leaves the second unproven.
//
// ## ⚠️ MEASURED: three VALIDATED slices were unreachable, and `3-2` with them
//
// `registerScreens()` registered builders for `AppRoutes.novelDetails`,
// `AppRoutes.sourceGenre` and `AppRoutes.sourceUnavailable` — and `_subRoutesFor` rendered
// `PlaceholderScreen(screenKey: …)` for all three. So `3-1`, `6-2` and `3-6` were
// implemented, registered, tested, marked **validated** in `.forge/state.json`, and a
// reader tapping through to them landed on a placeholder naming the route.
//
// Nothing was red. `app_router_test.dart` asserted `registeredScreens` *contains*
// `AppRoutes.history` — and it did. The table was correct; the route never read it.
//
// ## The rows
//
// | row | the defect it catches |
// |---|---|
// | every REGISTERED path is resolved through the registry | the one above, in general |
// | no registered path's route renders `PlaceholderScreen` | the same, from the other side |
// | `registerScreens()` is called once | the idempotent duplicate, invisible at runtime |
// | the reader is standalone and resolves through its own table | `/reader` in the shell |
// | resolving a registered path returns the registry's own builder | a substitute closure |

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumen_tale/app/router/app_nav_destinations.dart';
import 'package:lumen_tale/app/router/app_routes.dart';
import 'package:lumen_tale/app/router/screen_registry.dart';
import 'package:lumen_tale/main.dart' show registerScreens;

void main() {
  // ⚠️ **The registry is populated by calling the composition root's own function**,
  // because `registerScreens()` was extracted out of `main()` precisely so a row can run
  // it without launching the app. Rebuilding the table inside the test would mean testing
  // the rebuild.
  setUpAll(registerScreens);

  // ⚠️ **The names `app_router.dart` is expected to resolve, and their values come from
  // `AppRoutes` itself** — never from a literal re-spelled here. Half of these paths are
  // composed (`novelDetails` is `'$library/novel/:novelId'`), so a literal would be a
  // fourth copy of the route table, free to drift on the day it matters.
  const Map<String, String> resolvedByConstant = <String, String>{
    'novelDetails': AppRoutes.novelDetails,
    'sourceBrowse': AppRoutes.sourceBrowse,
    'sourceGenre': AppRoutes.sourceGenre,
    'sourceUnavailable': AppRoutes.sourceUnavailable,
    'settings': AppRoutes.settings,
    'settingsReader': AppRoutes.settingsReader,
    'settingsAbout': AppRoutes.settingsAbout,
  };

  // ⚠️ **Two ways a route resolves, and BOTH count.** A shell root resolves through
  // `screenBuilderFor(destination.path)` — a value, not a constant name — while a
  // sub-route names its constant. Collecting the shell paths from the enum rather than
  // re-listing them is what keeps a sixth tab from making this test lie.
  final Set<String> resolved = <String>{
    for (final AppNavDestination d in AppNavDestination.values) d.path,
    ...resolvedByConstant.values,
  };

  // ⚠️ **Every public path constant, name → value, values taken from `AppRoutes` itself.**
  //
  // The map exists because `screenBuilderFor`/`PlaceholderScreen` are called with a
  // CONSTANT NAME in the source (`AppRoutes.novelDetails`), and a name has to become a
  // value before it can be compared with the registry's keys. Spelling the path out as a
  // literal instead would produce a test that passes for the wrong reason — which is
  // exactly what the first version of this file did, and why the row below fails loudly on
  // a name it cannot resolve rather than skipping it.
  const Map<String, String> pathConstants = <String, String>{
    'library': AppRoutes.library,
    'updates': AppRoutes.updates,
    'history': AppRoutes.history,
    'browse': AppRoutes.browse,
    'more': AppRoutes.more,
    'novelDetails': AppRoutes.novelDetails,
    'sourceBrowse': AppRoutes.sourceBrowse,
    'sourceGenre': AppRoutes.sourceGenre,
    'sourceUnavailable': AppRoutes.sourceUnavailable,
    'downloads': AppRoutes.downloads,
    'settings': AppRoutes.settings,
    'settingsReader': AppRoutes.settingsReader,
    'settingsAbout': AppRoutes.settingsAbout,
    'reader': AppRoutes.reader,
    'onboarding': AppRoutes.onboarding,
  };

  group('the registry and the route table agree', () {
    // ⚠️ **The whole defect, stated once.** A path that has a builder AND is rendered by a
    // `PlaceholderScreen` is a screen that reports itself wired and is not.
    test('⚠️ NO registered path falls back to a PlaceholderScreen', () {
      final String router = _readRouter();
      final Set<String> registered = registeredScreens.keys.toSet();
      final List<String> offenders = <String>[];

      // ⚠️ **The `screenKey` argument is CAPTURED and then interpreted, rather than the
      // regex knowing about quotes.** A pattern that spells out both quote styles is a
      // pattern with an escaping bug waiting in it — and the first version of this row
      // had one, so the file did not even compile.
      //
      // ⚠️ **A CONSTANT is resolved to its value before it is compared.** Matching the file
      // for a literal path would pass on
      // `PlaceholderScreen(screenKey: AppRoutes.novelDetails)` — the very defect — and an
      // earlier version of this row did exactly that, which is why a sabotage went
      // straight through it. A test that cannot see the defect it names is worse than no
      // test, because it is believed.
      final RegExp placeholder = RegExp(
        r'PlaceholderScreen\(\s*screenKey:\s*([^,)]+)',
      );
      for (final Match m in placeholder.allMatches(router)) {
        String expression = m.group(1)!.trim();
        if (expression.startsWith('AppRoutes.')) {
          final String constant = expression.substring('AppRoutes.'.length);
          final String? value = pathConstants[constant];
          expect(
            value,
            isNotNull,
            reason:
                'the route table renders a placeholder for AppRoutes.$constant, which '
                'this row cannot resolve. An unresolvable name is NOT a pass — add it to '
                '`pathConstants`, or the row is blind to exactly the constant that moved.',
          );
          expression = value!;
        } else {
          // A literal screen key: `'settings'`. Strip the quotes rather than teach the
          // regex about them.
          expression = expression.replaceAll(RegExp(r'^["\x27]|["\x27]$'), '');
        }
        if (registered.contains(expression)) offenders.add(expression);
      }

      expect(
        offenders,
        isEmpty,
        reason:
            'a path with a registered builder whose route renders a placeholder is a '
            'screen no reader can reach — ${offenders.join(', ')}',
      );
    });

    // ⚠️ **Registered ⊆ resolved, and NOT equality.** `sourceBrowse` and `settingsReader`
    // are resolved but unregistered — their slices have not landed, and a placeholder that
    // NAMES the route is the intended outcome for those. The dangerous direction is the
    // other one, so that is the one asserted.
    test('⚠️ every REGISTERED path is resolved THROUGH the registry', () {
      final String router = _readRouter();

      for (final MapEntry<String, String> e in resolvedByConstant.entries) {
        expect(
          router,
          contains('screenBuilderFor(AppRoutes.${e.key})'),
          reason:
              '${e.value} has a registered builder and a route, but the route does not look '
              'it up by that constant — a relative or misspelled key registers under a name '
              'nothing reads, and the screen renders a placeholder while reporting itself '
              'registered',
        );
      }

      for (final String path in registeredScreens.keys) {
        expect(
          resolved,
          contains(path),
          reason:
              '$path has a registered builder, so a route must resolve it. If this fails '
              'and the row above passed, a new route was added without being listed in '
              '`resolvedByConstant` — add it there, and do NOT read the failure as a '
              'licence to leave the route out.',
        );
      }
    });

    // ⚠️ **And the converse, which is a weaker but still real obligation**: a path the
    // router resolves must be a constant of `AppRoutes`, not a literal. A literal in a
    // route table is the same defect one rename away.
    test('⚠️ the table resolves CONSTANTS, never string literals', () {
      final String router = _readRouter();
      final RegExp literal = RegExp('screenBuilderFor\\(\\s*[\'"]');
      expect(
        literal.hasMatch(router),
        isFalse,
        reason:
            'the registry is keyed by what `AppRoutes` spells out, so a literal key is a '
            'second spelling of a path that nothing keeps in step',
      );
    });

    // ⚠️ `registerScreen` assigns into a map, so a second `registerScreens()` overwrites
    // the first with an identical builder and changes nothing at runtime. That is exactly
    // why the duplicate survived review: it was idempotent. It was still two
    // registrations, and it reads as two.
    test('⚠️ registerScreens() is called ONCE', () {
      final String source = _read('lib/main.dart');
      // The declaration is `void registerScreens() {`; a CALL is `registerScreens();`.
      final RegExp call = RegExp(
        r'^\s*registerScreens\(\);\s*$',
        multiLine: true,
      );
      expect(
        call.allMatches(source).length,
        1,
        reason:
            'a second call is invisible while registerScreen is an assignment, and '
            'becomes a real bug the moment it is not',
      );
    });

    test('⚠️ /onboarding is STANDALONE and REGISTERED — `3-4`, E11', () {
      // ⚠️ **THE ROW THAT WOULD HAVE CAUGHT A FIRST-RUN READER ON A PLACEHOLDER.**
      //
      // `/onboarding` is the target of the cold-start **redirect**, and the redirect fires
      // *before* any screen is built — so an unregistered route here is not "a gap someone
      // will notice", it is a first-run reader landing on a page that says `/onboarding`.
      //
      // Nothing else in this file could see it: `standaloneRouteBuilderFor` synthesises a
      // builder for an absent path (see the rows above), so the placeholder row passes, and
      // the registration row above would too if it only consulted `registeredScreens` —
      // which is a *different* table for a *different* reason.
      expect(
        registeredStandaloneRoutes,
        contains(AppRoutes.onboarding),
        reason:
            'the cold-start redirect targets /onboarding; without a standalone '
            'registration it renders a PlaceholderScreen on the one screen E11 makes '
            'mandatory before an uninstall',
      );
      expect(
        registeredScreens,
        isNot(contains(AppRoutes.onboarding)),
        reason:
            'onboarding is outside the shell; registering it as a shell screen as well would '
            'give it two routes and only one of them is the real destination',
      );
    });

    test('⚠️ the reader is STANDALONE, and resolves through its own table', () {
      expect(
        registeredStandaloneRoutes,
        contains(AppRoutes.reader),
        reason:
            'the reader is reached by push from four places, so an unregistered reader is '
            'a blank screen rather than a visible placeholder',
      );
      expect(
        registeredScreens,
        isNot(contains(AppRoutes.reader)),
        reason:
            'registering the reader as a shell screen too would give it two routes, and '
            'only one of them is the real destination',
      );
    });
  });

  group('resolution actually resolves', () {
    test('⚠️ a REGISTERED path returns the REGISTRY\'s own builder', () {
      // ⚠️ **Identity, not a type check.** `screenBuilderFor` synthesises a placeholder
      // closure for an absent path, and two closures are never `identical` — so asserting
      // "resolving a registered path returns the builder the registry holds" tells the
      // real builder from the fallback without naming the fallback's type, which is a
      // detail of the fallback rather than of the route.
      for (final MapEntry<String, ScreenBuilder> e
          in registeredScreens.entries) {
        expect(
          identical(screenBuilderFor(e.key), e.value),
          isTrue,
          reason:
              '${e.key} is registered, so resolving it must return the very builder the '
              'registry holds rather than a synthesised placeholder',
        );
      }
    });

    test('⚠️ an UNREGISTERED path still yields a placeholder, not nothing', () {
      // ⚠️ **The fallback is load-bearing and must stay.** A route whose slice has not
      // landed renders a placeholder that NAMES the route, so the gap shows in one second
      // of running the app. Returning nothing instead would be strictly worse.
      expect(
        screenBuilderFor('/not/a/real/route'),
        isNotNull,
        reason: 'the fallback always returns something',
      );
      expect(
        screenBuilderFor('/not/a/real/route'),
        isNot(
          identical(
            screenBuilderFor('/not/a/real/route'),
            screenBuilderFor('/another/absent/route'),
          ),
        ),
        reason:
            'the fallback builds a closure naming the path it was asked for, so two '
            'absent paths do not resolve to the same screen',
      );
    });
  });
}

String _read(String relativePath) {
  final File file = File(relativePath);
  expect(
    file.existsSync(),
    isTrue,
    reason:
        '$relativePath was not found. These rows read the source on purpose: the defect '
        'they guard is a wiring mistake that no amount of walking the happy path shows, '
        'because the happy path is exactly what the placeholder replaced.',
  );
  return file.readAsStringSync();
}

String _readRouter() => _read('lib/app/router/app_router.dart');
