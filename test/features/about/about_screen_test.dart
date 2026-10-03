// Lumen Tale — `/more/settings/about`: B43's version, and B31's three figures.
//
// ## What this file is for
//
// § 2.1: *"A guarantee that an upgrade preserves the library is worth nothing without a
// way to see that it did."* So the counts are the screen, and the rows below are about
// the three ways a count can lie:
//
//   **a dash is not a zero** (we could not look / you have none),
//   **loading is not an error** (a skeleton that never resolves is a lie in the other
//   direction),
//   **the guarantee sentence survives a missing version** (B31 is about the data, and a
//   missing build string must not blank the page that states what happens to it).

import 'package:drift/drift.dart' show InsertMode, Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumen_tale/app/theme/app_theme.dart';
import 'package:lumen_tale/app/theme/app_version.dart';
import 'package:lumen_tale/core/database/app_database.dart';
import 'package:lumen_tale/core/storage/shared_preferences_provider.dart';
import 'package:lumen_tale/features/about/about_providers.dart';
import 'package:lumen_tale/features/about/about_screen.dart';
import 'package:lumen_tale/features/history/history_providers.dart';
import 'package:lumen_tale/l10n/generated/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

late AppDatabase db;
late SharedPreferences _prefs;

/// ⚠️ **Only the WIDTH is the design constraint** (`design-system.md` § 1.7 makes
/// `< 600dp` the only layout v1 ships) — [height] is whatever a row needs. The privacy
/// and delivery blocks are below the fold on a 640dp phone, and those rows are about
/// *what the page says*, not about scrolling; a row that dragged the list to reach its
/// own assertion would be testing the gesture.
Future<void> pumpAbout(
  WidgetTester tester, {
  BuildVersion version = const BuildVersion(
    buildName: '0.9.0',
    buildNumber: '41',
  ),
  AboutCounts? counts,
  double height = 640,
}) async {
  tester.view
    ..physicalSize = Size(360, height)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(_prefs)],
      child: MaterialApp(
        theme: AppTheme.day(),
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: AboutBody(
            version: version,
            counts:
                counts ??
                const AboutCounts(
                  library: AsyncValue<int>.data(14),
                  downloaded: AsyncValue<int>.data(512),
                  positions: AsyncValue<int>.data(638),
                ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> addNovel(String id) => db
    .into(db.novels)
    .insert(
      NovelsCompanion.insert(
        id: id,
        sourceId: 's1',
        url: '/fiction/$id',
        title: 'A Novel',
      ),
      mode: InsertMode.insertOrIgnore,
    );

Future<void> addChapter(String novelId, String chapterId) => db
    .into(db.chapters)
    .insert(
      ChaptersCompanion.insert(
        id: chapterId,
        novelId: novelId,
        name: 'Chapter',
        url: '/fiction/$novelId/chapter/$chapterId',
        ordinal: 1,
      ),
      mode: InsertMode.insertOrIgnore,
    );

Future<void> addPosition(String chapterId, double offset) => db
    .into(db.readingPositions)
    .insert(
      ReadingPositionsCompanion.insert(
        chapterId: chapterId,
        offset: Value(offset),
        updatedAt: DateTime(2026, 10, 3),
      ),
      mode: InsertMode.insertOrIgnore,
    );

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    _prefs = await SharedPreferences.getInstance();
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() => db.close());

  group('B43 — the version can be determined', () {
    testWidgets('a readable version renders the version line', (
      WidgetTester tester,
    ) async {
      await pumpAbout(tester);
      expect(find.text('Version 0.9.0 · build 41'), findsOneWidget);
    });

    testWidgets('an unreadable version is a SENTENCE, never an em dash', (
      WidgetTester tester,
    ) async {
      // ⚠️ **The row `Version —` is forbidden for.** An em dash looks like a version,
      // and a reader who believes she is on 0.9.0 sends a bug report against a build
      // that may be any of them.
      await pumpAbout(
        tester,
        version: const BuildVersion(buildName: '', buildNumber: ''),
      );
      expect(
        find.text('The installed version number could not be read.'),
        findsOneWidget,
      );
      // ⚠️ **Scoped to the version line**, not to the whole page: the privacy block is
      // full of legitimate em dashes, and a blanket `contains('—')` would fail on the
      // sentences that are doing their job. What is forbidden is a *version* that is
      // an em dash.
      expect(find.textContaining('Version —'), findsNothing);
      expect(
        find.byWidgetPredicate(
          (Widget w) =>
              w is Text &&
              (w.data ?? '').startsWith('Version') &&
              (w.data ?? '').length > 'Version'.length,
        ),
        findsNothing,
      );
    });

    testWidgets('half a version counts as unreadable', (
      WidgetTester tester,
    ) async {
      // A name with no build number identifies a release line, not a build. C9 asks
      // *which version*, and half an answer is a question mark dressed as a fact.
      await pumpAbout(
        tester,
        version: const BuildVersion(buildName: '0.9.0', buildNumber: ''),
      );
      expect(find.text('Version 0.9.0 · build '), findsNothing);
      expect(
        find.text('The installed version number could not be read.'),
        findsOneWidget,
      );
    });

    testWidgets('the missing version does NOT blank the rest of the page', (
      WidgetTester tester,
    ) async {
      // ⚠️ **A missing string must not blank the page that states what happens to the
      // reader's data.** E11 and B31's guarantee are the two most important sentences
      // on the screen and neither depends on a build number.
      await pumpAbout(
        tester,
        version: const BuildVersion(buildName: '', buildNumber: ''),
        height: 2400,
      );
      expect(
        find.textContaining('Nothing here is backed up anywhere'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Installing a new version keeps your library'),
        findsOneWidget,
      );
      expect(find.text('Library'), findsOneWidget);
      expect(find.text('14'), findsOneWidget);
      // ⚠️ **And the blocks AFTER the identity one.** An earlier version of this row
      // stopped at the data block and passed a screen that had lost its privacy
      // statement — the failure the row exists to prevent, asserted half as widely as
      // it claimed.
      expect(find.text('WHAT LEAVES THIS DEVICE'), findsOneWidget);
      expect(find.textContaining('There is no app store'), findsOneWidget);
    });
  });

  group('B31 — three counts, a guarantee, and E11', () {
    testWidgets('all three figures render, with their labels', (
      WidgetTester tester,
    ) async {
      await pumpAbout(tester);
      expect(find.text('Library'), findsOneWidget);
      expect(find.text('Downloaded chapters'), findsOneWidget);
      expect(find.text('Reading positions'), findsOneWidget);
      expect(find.text('14'), findsOneWidget);
      expect(find.text('512'), findsOneWidget);
      expect(find.text('638'), findsOneWidget);
    });

    testWidgets('three zeroes render as three zeroes, with no EmptyState', (
      WidgetTester tester,
    ) async {
      // `settings-about.md` § 4 (Empty — no data): the counts read `0 · 0 · 0` in
      // `--text-body`, "no `EmptyState`, no illustration, no 'get started' call to
      // action" — an About screen with a celebratory empty state about having
      // downloaded nothing is gamification.
      await pumpAbout(
        tester,
        counts: const AboutCounts(
          library: AsyncValue<int>.data(0),
          downloaded: AsyncValue<int>.data(0),
          positions: AsyncValue<int>.data(0),
        ),
      );
      expect(find.text('0'), findsNWidgets(3));
      expect(find.textContaining('get started'), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('a count that could not be computed is a DASH, not a zero', (
      WidgetTester tester,
    ) async {
      // ⚠️ **The distinction the whole block exists for.** A zero says "you have none";
      // a dash says "we could not look". A reader who took the first for the second
      // would re-download a library she still has.
      await pumpAbout(
        tester,
        counts: AboutCounts(
          library: const AsyncValue<int>.data(14),
          downloaded: AsyncValue<int>.error(
            StateError('disk'),
            StackTrace.current,
          ),
          positions: const AsyncValue<int>.data(638),
        ),
      );
      expect(find.text('—'), findsOneWidget);
      expect(find.text('14'), findsOneWidget);
      expect(find.text('638'), findsOneWidget);
    });

    testWidgets('one failing count does not blank the other two', (
      WidgetTester tester,
    ) async {
      await pumpAbout(
        tester,
        counts: AboutCounts(
          library: AsyncValue<int>.error(
            StateError('nope'),
            StackTrace.current,
          ),
          downloaded: AsyncValue<int>.error(
            StateError('nope'),
            StackTrace.current,
          ),
          positions: const AsyncValue<int>.data(638),
        ),
      );
      expect(find.text('638'), findsOneWidget);
      expect(find.text('Reading positions'), findsOneWidget);
    });

    testWidgets('loading renders a bar, and never a dash and never a spinner', (
      WidgetTester tester,
    ) async {
      // `settings-about.md` § 4 (Loading): *"a bar the width of the figure it will
      // become, with `--duration-normal` shimmer, **no centred spinner**"*. A dash that
      // flickers to a number reads as an error that was not one.
      await pumpAbout(
        tester,
        counts: const AboutCounts(
          library: AsyncLoading<int>(),
          downloaded: AsyncLoading<int>(),
          positions: AsyncLoading<int>(),
        ),
      );
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('—'), findsNothing);
      expect(find.text('14'), findsNothing);
    });

    testWidgets('the counts are NOT interactive', (WidgetTester tester) async {
      // § 5: *"The three data counts | — | **Nothing.** No chevron, no ripple, no
      // pressed state"*. Evidence that responds to a tap is not evidence: the reader
      // takes these before an update and compares after.
      await pumpAbout(tester);
      expect(find.widgetWithText(InkWell, 'Library'), findsNothing);
      expect(find.widgetWithText(InkWell, 'Downloaded chapters'), findsNothing);
      expect(find.widgetWithText(InkWell, 'Reading positions'), findsNothing);
      expect(find.byIcon(Icons.chevron_right), findsNothing);
    });

    testWidgets('the guarantee sentence is on the page, next to the counts', (
      WidgetTester tester,
    ) async {
      // § 4bis: this sentence is what survived the removal of `UpdateBlock`. It is
      // read out loud *before* the reader installs anything.
      await pumpAbout(tester);
      expect(
        find.textContaining('Installing a new version keeps your library'),
        findsOneWidget,
      );
    });

    testWidgets('there is no version-check control, and nothing reaches a server', (
      WidgetTester tester,
    ) async {
      // § 4bis removed it from v1, and B29 is satisfied while the app sends nothing.
      // A control here would be the one place on this screen that could reach out.
      await pumpAbout(tester);
      expect(find.textContaining('Check for a new version'), findsNothing);
      expect(find.textContaining('Install the update'), findsNothing);
      expect(find.textContaining('Download the file'), findsNothing);
    });
  });

  group('the privacy block', () {
    testWidgets('two things are sent and seven never are', (
      WidgetTester tester,
    ) async {
      await pumpAbout(tester, height: 2200);
      expect(
        find.text("A chapter's page — but only after you asked for it."),
        findsOneWidget,
      );
      expect(
        find.textContaining(
          'One request to check whether a newer version exists',
        ),
        findsOneWidget,
      );
      for (final String line in <String>[
        'Your library',
        'Your reading positions',
        'Your history',
        'Your error logs',
        'Crash reports',
        'Analytics',
        'A device identifier',
      ]) {
        expect(find.text(line), findsOneWidget, reason: line);
      }
    });

    testWidgets('the claim is falsifiable — airplane mode is the test', (
      WidgetTester tester,
    ) async {
      // A privacy promise the reader cannot test is marketing. Thirty seconds is the
      // price of the claim being more than a sentence.
      await pumpAbout(tester, height: 2200);
      expect(
        find.textContaining('switch the phone to airplane mode'),
        findsOneWidget,
      );
    });

    testWidgets(
      'both lists sit under a heading a screen reader will announce',
      (WidgetTester tester) async {
        await pumpAbout(tester, height: 2200);
        final Iterable<Semantics> headings = find
            .byWidgetPredicate(
              (Widget w) => w is Semantics && w.properties.header == true,
            )
            .evaluate()
            .map((Element e) => e.widget as Semantics);
        expect(
          headings.map((Semantics s) => s.properties.label),
          containsAll(<String>[
            'YOUR DATA ON THIS DEVICE',
            'WHAT LEAVES THIS DEVICE',
          ]),
        );
      },
    );

    testWidgets('the delivery sentence is the last block, with no links out', (
      WidgetTester tester,
    ) async {
      await pumpAbout(tester, height: 2400);
      expect(find.textContaining('There is no app store'), findsOneWidget);
      expect(find.byType(SingleChildScrollView), findsNothing);
    });
  });

  group('the counts read real rows', () {
    testWidgets('one provider failing does not blank the other two figures', (
      WidgetTester tester,
    ) async {
      // ⚠️ **The failure shape is the reason there are three queries.** The rows above
      // inject an `AboutCounts` directly and so never exercised the providers; this one
      // drives the real screen with only the positions query failing, which is what
      // "one local query per figure" is actually buying.
      await addNovel('n1');
      await addChapter('n1', 'c1');

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(_prefs),
            appDatabaseProvider.overrideWithValue(db),
            aboutPositionsCountProvider.overrideWith(
              (Ref ref) => throw StateError('the positions table is not there'),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.day(),
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Scaffold(body: AboutScreen()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // The two that answered still answer …
      expect(find.text('Reading positions'), findsOneWidget);
      expect(find.text('Library'), findsOneWidget);
      expect(find.text('Downloaded chapters'), findsOneWidget);
      expect(find.text('1'), findsNWidgets(2));
      // … and the one that failed says so rather than claiming zero.
      expect(find.text('—'), findsOneWidget);
    });

    testWidgets('the figures come from the database, not from a constant', (
      WidgetTester tester,
    ) async {
      await addNovel('n1');
      await addChapter('n1', 'c1');
      await addPosition('c1', 12);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(_prefs),
            appDatabaseProvider.overrideWithValue(db),
          ],
          child: MaterialApp(
            theme: AppTheme.day(),
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Scaffold(body: AboutScreen()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('1'), findsNWidgets(3));
      expect(find.text('14'), findsNothing);
    });
  });
}
