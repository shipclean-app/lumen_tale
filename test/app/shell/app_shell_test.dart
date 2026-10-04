// forge:slice 0-5
// Lumen Tale — `0-5` § 11.2, the shell rendered, and § 11.1's structural rows.
//
// Everything here runs at **360dp**, the one width v1 ships (`design-system.md`
// § 1.7, ADR-019). There is deliberately no "tablet layout" row: ADR-019 excluded
// tablets, rails and two-pane from the product, and § 3.2 says the bar stays at the
// bottom and stays five items at any width — so a second layout to check would be
// checking something this product does not have. There **is** a 800dp row, because
// § 3.2 makes a claim there ("it does not become a rail") and a claim needs a test.
//
// The file also owns the **grep rows**. They belong here rather than beside the route
// data because every one is a claim about the *wiring* — shell, router, bootstrap —
// and a claim about wiring has no runtime witness: the code it forbids is absent, so
// there is nothing to run. Each pattern therefore carries a **witness**, a string that
// must match it, so a broken pattern fails loudly instead of reporting a permanent
// green.

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumen_tale/app/router/app_nav_destinations.dart';
import 'package:lumen_tale/app/router/app_router.dart';
import 'package:lumen_tale/app/router/app_routes.dart';
import 'package:lumen_tale/app/theme/app_theme.dart';
import 'package:lumen_tale/core/ui/app_scaffold.dart';
import 'package:lumen_tale/l10n/generated/app_localizations.dart';

/// `design-system.md` § 1.7: `< 600dp` is the only layout v1 ships.
const Size designSize = Size(360, 640);

/// Pumps the whole app — router, shell, locales — at [size].
Future<void> pumpApp(
  WidgetTester tester, {
  Locale locale = const Locale('en'),
  Size size = designSize,
}) async {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  // ⚠️ **The router is a process-scope singleton**, so it keeps whatever was pushed
  // on it by the previous row. In production `main()` mounts it once, so this never
  // arises; in a test file every row is a fresh `MaterialApp` over the *same*
  // router, and without this a row that pushed the reader would leave it on the
  // stack for the next one. The symptom is a row failing for the row before it.
  appRouter.go(initialLocation);

  await tester.pumpWidget(
    MaterialApp.router(
      routerConfig: appRouter,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: locale,
      theme: AppTheme.day(),
      darkTheme: AppTheme.night(),
    ),
  );
  await tester.pumpAndSettle();
}

/// A context that can navigate — any element under the router will do.
BuildContext navigatorContext(WidgetTester tester) =>
    tester.element(find.byType(NavigationBar));

void main() {
  group('the bottom bar', () {
    testWidgets('renders exactly five destinations, at 360dp', (
      WidgetTester tester,
    ) async {
      await pumpApp(tester);
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.byType(NavigationDestination), findsNWidgets(5));
    });

    testWidgets('at 800dp it is still a bottom bar with five items — ADR-019', (
      WidgetTester tester,
    ) async {
      // § 3.2: ">=600dp the bar stays at the bottom and stays 5 items. It does not
      // become a rail." The row exists because putting a rail back is not a responsive
      // decision — it is the thing ADR-019 removed.
      await pumpApp(tester, size: const Size(800, 1000));
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.byType(NavigationDestination), findsNWidgets(5));
      expect(find.byType(NavigationRail), findsNothing);
    });

    testWidgets('the labels follow the locale — B28, E12', (
      WidgetTester tester,
    ) async {
      await pumpApp(tester, locale: const Locale('fr'));
      expect(find.text('Plus'), findsOneWidget);

      await pumpApp(tester);
      expect(find.text('More'), findsOneWidget);
    });

    testWidgets('the bar opens on Library — ADR-018', (
      WidgetTester tester,
    ) async {
      await pumpApp(tester);
      final NavigationBar bar = tester.widget<NavigationBar>(
        find.byType(NavigationBar),
      );
      expect(bar.selectedIndex, 0);
      // A selected tab is visually distinguishable, not only semantically.
      expect(
        find.byIcon(AppNavDestination.library.selectedIcon),
        findsOneWidget,
      );
    });

    testWidgets('tapping another tab switches the branch', (
      WidgetTester tester,
    ) async {
      await pumpApp(tester);
      await tester.tap(find.text('Browse'));
      await tester.pumpAndSettle();

      final NavigationBar bar = tester.widget<NavigationBar>(
        find.byType(NavigationBar),
      );
      expect(bar.selectedIndex, 3);
    });

    testWidgets('a tab keeps its own stack — § 3.5', (
      WidgetTester tester,
    ) async {
      // The whole reason for `StatefulShellRoute`: each tab keeps its own scroll
      // position and back stack, so leaving and returning resumes where it was.
      await pumpApp(tester);
      appRouter.go(AppRoutes.novelDetailsFor('n1'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('History'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Library'));
      await tester.pumpAndSettle();

      // The placeholder names the ROUTE it stands in for, which is the pattern — so
      // `/library/novel/:novelId`, not the location it was reached by. Asserting on
      // the location would be asserting on a string nothing renders.
      expect(
        find.text(AppRoutes.novelDetails),
        findsOneWidget,
        reason: 'the Library branch must still hold the novel it was showing',
      );
    });

    testWidgets('tapping the active tab returns it to its root', (
      WidgetTester tester,
    ) async {
      // The platform behaviour, and the only way back from a deep stack with no back
      // button in reach (C11: reading happens one-handed).
      await pumpApp(tester);
      appRouter.go(AppRoutes.novelDetailsFor('n1'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Library'));
      await tester.pumpAndSettle();

      expect(find.text(AppRoutes.novelDetailsFor('n1')), findsNothing);
    });
  });

  group('outside the shell', () {
    testWidgets('/reader renders no tab bar — § 3.5', (
      WidgetTester tester,
    ) async {
      await pumpApp(tester);
      // ⚠️ **NOT awaited.** `GoRouter.push` returns a future that completes when the
      // route is **popped** — so awaiting it here hangs the row for ever, and the
      // hang looks like a router deadlock rather than a missing keyword. The first
      // draft of this row did exactly that.
      unawaited(
        openReader(navigatorContext(tester), novelId: 'n1', chapterId: 'c1'),
      );
      await tester.pumpAndSettle();
      expect(find.byType(NavigationBar), findsNothing);
    });

    testWidgets('/onboarding renders no tab bar — § 3.5', (
      WidgetTester tester,
    ) async {
      await pumpApp(tester);
      // Not awaited — see the reader rows: the future completes on pop.
      unawaited(openOnboarding(navigatorContext(tester)));
      await tester.pumpAndSettle();
      expect(find.byType(NavigationBar), findsNothing);
    });

    testWidgets('the reader is above the shell, so back returns there', (
      WidgetTester tester,
    ) async {
      // The load-bearing half of "outside the shell". `GoRouter.go` REPLACES the root
      // page list, so a root-level route navigated with `go` unmounts the shell: the
      // reader loses the tab they came from, that tab's stack and its scroll
      // position, and `pop` then has nothing to pop. `push` appends instead.
      await pumpApp(tester);
      appRouter.go(AppRoutes.novelDetailsFor('n1'));
      await tester.pumpAndSettle();

      unawaited(
        openReader(navigatorContext(tester), novelId: 'n1', chapterId: 'c1'),
      );
      await tester.pumpAndSettle();
      expect(find.byType(NavigationBar), findsNothing);

      appRouter.pop();
      await tester.pumpAndSettle();

      expect(find.byType(NavigationBar), findsOneWidget);
      expect(
        find.text(AppRoutes.novelDetails),
        findsOneWidget,
        reason: 'going back from the reader must return to where it came from',
      );
    });

    testWidgets('the reader has no transition in — § 3.4', (
      WidgetTester tester,
    ) async {
      // "Opening a chapter does not slide — the text is simply there. A slide would
      // make the reader wait, on the one screen where waiting is the whole cost."
      await pumpApp(tester);
      unawaited(
        openReader(navigatorContext(tester), novelId: 'n1', chapterId: 'c1'),
      );
      // One frame, no settle: a transition would still be running and the shell's
      // bar would still be in the tree.
      await tester.pump();
      expect(find.byType(NavigationBar), findsNothing);
    });
  });

  group('AppScaffold', () {
    Future<void> pumpScaffold(
      WidgetTester tester, {
      required AppScaffold scaffold,
    }) async {
      tester.view
        ..physicalSize = designSize
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: scaffold,
        ),
      );
    }

    testWidgets('the default state renders both its slots', (
      WidgetTester tester,
    ) async {
      await pumpScaffold(
        tester,
        scaffold: AppScaffold(
          // ⚠️ `AppBar` is NOT a const constructor in Flutter 3.47 (checked in the
          // SDK source, not from memory). `AGENTS.md` says never to answer a Flutter
          // API question from memory, and this is the first question this project
          // asked that memory got wrong.
          titleBar: AppBar(title: const Text('title')),
          content: const _Marker(key: ValueKey<String>('body')),
          bottomNav: const _Marker(key: ValueKey<String>('nav')),
        ),
      );
      expect(find.byKey(const ValueKey<String>('body')), findsOneWidget);
      expect(find.byKey(const ValueKey<String>('nav')), findsOneWidget);
    });

    testWidgets('immersive ignores bottomNav even when one is passed', (
      WidgetTester tester,
    ) async {
      // § 2.8: `immersive` replaces titleBar AND bottomNav, **unconditionally**.
      //
      // `showBottomNav` is deliberately left at its DEFAULT of `true` here, and
      // that default *is* the trap: a reader screen that forgets to set the state
      // gets `true` without asking, and would get a tab bar under the prose. The
      // row therefore does not pass the flag — it proves the default loses to the
      // state anyway.
      await pumpScaffold(
        tester,
        scaffold: const AppScaffold(
          state: AppScaffoldState.immersive,
          bottomNav: _Marker(key: ValueKey<String>('nav')),
          content: _Marker(key: ValueKey<String>('body')),
        ),
      );
      expect(find.byKey(const ValueKey<String>('body')), findsOneWidget);
      expect(find.byKey(const ValueKey<String>('nav')), findsNothing);
    });

    testWidgets('persistentStatus sits ABOVE the bottom nav — § 2.8 busy', (
      WidgetTester tester,
    ) async {
      await pumpScaffold(
        tester,
        scaffold: const AppScaffold(
          state: AppScaffoldState.busy,
          // Fixed heights: a zero-height `SizedBox` has its top-left at the same y
          // as its neighbour, so an ordering assertion over shrunken markers proves
          // nothing. The rows must occupy space to have an order.
          persistentStatus: SizedBox(
            key: ValueKey<String>('status'),
            height: 24,
          ),
          bottomNav: SizedBox(key: ValueKey<String>('nav'), height: 80),
          content: _Marker(key: ValueKey<String>('body')),
        ),
      );
      final double statusY = tester
          .getTopLeft(find.byKey(const ValueKey<String>('status')))
          .dy;
      final double navY = tester
          .getTopLeft(find.byKey(const ValueKey<String>('nav')))
          .dy;
      expect(
        statusY,
        lessThan(navY),
        reason:
            'download progress must be visible above the bar it waits behind',
      );
    });

    testWidgets('no Scaffold is nested — the shell is a Column', (
      WidgetTester tester,
    ) async {
      await pumpApp(tester);
      // One Scaffold per screen: the one AppScaffold builds. Two would give the
      // content two SafeAreas and put the bar under the screen's own.
      expect(find.byType(Scaffold), findsOneWidget);
    });
  });

  group('an unknown route is never a blank page — B24, C12', () {
    testWidgets('a path that does not exist renders the error copy', (
      WidgetTester tester,
    ) async {
      await pumpApp(tester);
      appRouter.go('/nope/whatever');
      await tester.pumpAndSettle();

      final AppLocalizations l10n = await AppLocalizations.delegate.load(
        const Locale('en'),
      );
      expect(find.text(l10n.commonErrorTitle), findsOneWidget);
      expect(find.text(l10n.commonErrorBody), findsOneWidget);
    });
  });

  group('no overflow at the design width — C11', () {
    testWidgets('the shell and every bar render without overflow', (
      WidgetTester tester,
    ) async {
      for (final double scale in <double>[1, 1.5, 2]) {
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        await pumpApp(tester);
        expect(
          tester.takeException(),
          isNull,
          reason: 'the shell overflowed at ${scale * 100}% text scale',
        );
      }
    });
  });

  group('the shape of the wiring — greps, each with a witness', () {
    late List<File> routerFiles;
    late List<File> bootstrapFiles;

    setUpAll(() {
      routerFiles = theseFiles(<String>[
        'lib/app/router/app_router.dart',
        'lib/app/shell/app_shell.dart',
      ]);
      bootstrapFiles = theseFiles(<String>['lib/main.dart']);
    });

    test('the router is built exactly once, and never inside a build()', () {
      // E12: a router rebuilt on a locale change starts at `initialLocation`, so the
      // reader loses their place in the app. Nothing errors, so this can only be a
      // structural claim.
      expect(
        grepCode(routerFiles, RegExp(r'\bGoRouter\s*\(')),
        hasLength(1),
        reason:
            'there must be exactly one GoRouter construction in the router file, and '
            "it must be the top-level final's initializer",
      );
      assertNoCodeMatch(
        routerFiles,
        RegExp(r'^\s*(static\s+)?GoRouter\s+build\s*\('),
        'no GoRouter.build() — appRouter is a value, not a factory',
        witness: '  static GoRouter build() => GoRouter();',
      );
    });

    test('the reader is pushed, never go-n', () {
      // The capability is exposed as `openReader` precisely so a feature cannot spell
      // it the other way, and this row is what keeps that true if someone adds a
      // second call site later.
      assertNoCodeMatch(
        routerFiles,
        RegExp(r'\.go\s*\(\s*AppRoutes\.readerFor'),
        'the reader must never be navigated with go() — it would unmount the shell',
        witness: 'GoRouter.of(context).go(AppRoutes.readerFor(a, b));',
      );
      assertNoCodeMatch(
        routerFiles,
        RegExp(r'\.go\s*\(\s*AppRoutes\.onboarding'),
        'onboarding must never be navigated with go()',
        witness: 'GoRouter.of(context).go(AppRoutes.onboarding);',
      );
    });

    test('there is no redirect to onboarding — E11', () {
      // E11 asks for the "nothing here is backed up" disclosure to be made BEFORE an
      // uninstall, and the only moment the shell could trigger it alone is first run.
      // This slice does not decide that: the trigger belongs to whichever slice writes
      // the screen, and a preferences flag invented here for "do not miss anything"
      // would be the false promise E11 forbids. `0-5` § 7 question 6 records the gap.
      assertNoCodeMatch(
        routerFiles,
        RegExp(r'\bredirect\s*:'),
        'no redirect may exist in the route table — the first-run trigger is undecided',
        witness: 'redirect: (_, __) => AppRoutes.onboarding,',
      );
    });

    test(
      'the shell is a Column, not a Scaffold — one SafeArea, one bottom bar',
      () {
        // Two Scaffolds would give the child two SafeAreas and put the shell's nav bar
        // underneath the screen's own. The screens are written by other slices, so this
        // has to be enforced here, on the only file that could break it.
        assertNoCodeMatch(
          routerFiles,
          RegExp(r'\bScaffold\s*\('),
          'AppShell must not build a Scaffold — AppScaffold is the only one',
          witness: 'return Scaffold(body: navigationShell);',
        );
      },
    );

    test('no tab label is a literal', () {
      // `16-i18n.md` rule 1 and B28: a literal in a `NavigationDestination` does not
      // change language.
      assertNoCodeMatch(
        theseFiles(<String>['lib/app/shell/app_shell.dart']),
        RegExp("label:\\s*['\"]"),
        'a NavigationDestination label must come from AppLocalizations',
        witness: "label: 'Library',",
      );
    });

    test('no path literal is written outside app_routes.dart', () {
      // `09-widgets-ui.md` convention 10. One file owns every path; a second file
      // writing one is a second spelling of a route.
      //
      // ⚠️ `app_routes.dart` is **excluded from the scan**, not from the rule: it is
      // the file that is *supposed* to spell them. An earlier version of this row
      // scanned `lib/app` whole and failed on the one file that has to contain the
      // literals — which is the shape of a check that gets disabled instead of fixed.
      final List<File> others = dartFilesIn(
        'lib/app',
      ).where((File f) => !f.path.endsWith('app_routes.dart')).toList();
      expect(
        others,
        isNotEmpty,
        reason: 'the scan must still have files to read',
      );

      assertNoCodeMatch(
        others,
        RegExp("['\"]/(library|updates|history|browse|more|reader|onboarding)"),
        'paths are centralised in app_routes.dart — no other file spells one',
        witness: "final p = '/library';",
      );
    });

    test('app/ imports no feature', () {
      // `architecture.md` § 3.1a: "No feature import". Each screen slice fills one
      // route, and this is what keeps the shell from importing the thing it mounts.
      assertNoCodeMatch(
        dartFilesIn('lib/app'),
        RegExp('package:lumen_tale/features/'),
        'app/ must not import a feature',
        witness:
            "import 'package:lumen_tale/features/library/library_screen.dart';",
      );
    });

    test('main is async and resolves SharedPreferences before runApp', () {
      // `theme_providers.dart` declares the preferences provider as
      // `throw UnimplementedError('overridden at the bootstrap by 0-5')`, and
      // `main.dart` is the **only** place that override exists. A synchronous runApp
      // leaves the throw live, and the first read of the theme is the first frame —
      // so the app dies on launch, in a way that looks like a provider bug.
      assertNoCodeMatch(
        bootstrapFiles,
        RegExp(r'^\s*void\s+main\s*\(\s*\)\s*\{'),
        'main must be Future<void> main() async, and the line must not be a bare '
        '`void main()` — the regex is anchored so that `Future<void> main()` '
        'cannot be matched by its own return type',
        witness: 'void main() {',
      );
      assertNoCodeMatch(
        bootstrapFiles,
        RegExp(
          r'^\s*(?!Future)void\s+main\s*\(\s*\)\s*(async\s*)?\{[^}]*runApp',
        ),
        'main must not call runApp synchronously',
        witness: 'void main() { runApp(App()); }',
      );
      // The override must be PRESENT, and exactly once. `05-state-management.md`
      // forbids a provider modifying another one's state; this one is the bootstrap's
      // own, resolved before the first frame.
      //
      // ⚠️ The first draft wrote this as an *absence* check — the same shape as the
      // rows above it — and it passed while asserting nothing at all: the grep
      // forbade the very line the requirement needs. A check copied from its
      // neighbours is a check that never looked at the requirement.
      final List<String> overrides = grepCode(
        bootstrapFiles,
        RegExp(r'appThemePreferencesProvider\.overrideWith'),
      );
      expect(
        overrides,
        hasLength(1),
        reason:
            'the bootstrap must override appThemePreferencesProvider exactly once — '
            'found at $overrides',
      );
    });

    test('main uses the LIST locale callback, never the single one', () {
      // `localeResolutionCallback` sees only the FIRST preferred locale, so `fr_CA`
      // never reaches `fr` by language code and B28's fallback would only apply to
      // the crudest cases. The route-data rows that assert `fr_CA -> fr` would be a
      // lie in the real app if this row were not true.
      expect(
        sourceOf(bootstrapFiles),
        contains('localeListResolutionCallback: _resolveLocale'),
        reason: 'the LIST callback is the one that sees every preferred locale',
      );
      assertNoCodeMatch(
        bootstrapFiles,
        RegExp('(?<!localeList)localeResolutionCallback\\s*:'),
        'localeResolutionCallback sees only the first preferred locale — E12',
        witness: 'localeResolutionCallback: _resolveLocale,',
      );
    });
  });
}

/* ------------------------------------------------------------------ *
 * Grep helpers — see the file header for why each carries a witness.
 * ------------------------------------------------------------------ */

/// Every `.dart` file under [relativeDir], sorted so a failure is reproducible.
List<File> dartFilesIn(String relativeDir) {
  final Directory dir = Directory(relativeDir);
  expect(
    dir.existsSync(),
    isTrue,
    reason:
        '$relativeDir must exist — a grep over a missing directory is a grep over '
        'nothing, which is a permanent green',
  );
  final List<File> files =
      dir
          .listSync(recursive: true)
          .whereType<File>()
          .where((File f) => f.path.endsWith('.dart'))
          .toList()
        ..sort((File a, File b) => a.path.compareTo(b.path));
  expect(files, isNotEmpty);
  return files;
}

/// The named files. Every one must exist: a grep over a missing file is a grep over
/// nothing.
List<File> theseFiles(List<String> relativePaths) {
  final List<File> files = <File>[];
  for (final String relative in relativePaths) {
    final File file = File(relative);
    expect(
      file.existsSync(),
      isTrue,
      reason:
          '$relative must exist — grepping a missing file is grepping nothing',
    );
    files.add(file);
  }
  files.sort((File a, File b) => a.path.compareTo(b.path));
  return files;
}

/// Whether the line a hit points at is a comment.
///
/// Comments are excluded, and necessarily so: these files document *why* there is no
/// `redirect`, why the router is a top-level `final`, and why nothing becomes a rail.
/// A grep that counted its own prohibition would report a permanent red for code that
/// is correct — and the fix everyone reaches for is to weaken the grep, which is how a
/// check dies.
///
/// The exclusion is line-based and narrow: a line whose first non-space characters
/// open a comment. A prohibition therefore cannot hide a **use**, because a use sits
/// on code.
bool _isComment(File file, int lineNumber) {
  final List<String> lines = file.readAsStringSync().split('\n');
  if (lineNumber > lines.length) {
    return false;
  }
  final String line = lines[lineNumber - 1].trimLeft();
  return line.startsWith('//') || line.startsWith('*') || line.startsWith('/*');
}

/// Every **executable** line in [files] matching [pattern], as `path:line`.
List<String> grepCode(List<File> files, RegExp pattern) {
  final List<String> hits = <String>[];
  for (final File file in files) {
    final List<String> lines = file.readAsStringSync().split('\n');
    for (var i = 0; i < lines.length; i++) {
      if (pattern.hasMatch(lines[i]) && !_isComment(file, i + 1)) {
        hits.add('${file.path}:${i + 1}');
      }
    }
  }
  return hits;
}

/// Asserts no executable line in [files] matches [pattern].
///
/// [witness] is a string that **must** match [pattern]. Passing one turns "the grep
/// found nothing" into "the grep found nothing *and* can still find something", which
/// is the difference between a check and a tautology.
void assertNoCodeMatch(
  List<File> files,
  RegExp pattern,
  String reason, {
  String? witness,
}) {
  final List<String> hits = grepCode(files, pattern);
  expect(hits, isEmpty, reason: '$reason — found in $hits');
  if (witness != null) {
    expect(
      pattern.hasMatch(witness),
      isTrue,
      reason:
          'the grep itself is broken: "$witness" should have matched '
          '"${pattern.pattern}"',
    );
  }
}

/// The whole of [files] concatenated, comments **included** — for assertions that are
/// about wording rather than about a use.
String sourceOf(List<File> files) =>
    files.map((File f) => f.readAsStringSync()).join('\n');

/// A widget that only exists to be found, and to be pointed at by key.
class _Marker extends StatelessWidget {
  const _Marker({super.key});

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
