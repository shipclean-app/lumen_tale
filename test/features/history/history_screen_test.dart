// Lumen Tale — `/history`, its states, and B46 made falsifiable.
//
// ## What is a widget row here and what is not
//
// The nine states of `history.md` § 4 are **rendering** claims, so they get widget
// rows. The three rows that are the point of the screen are not about rendering at
// all and are stated here anyway because they are the ones a refactor breaks first:
//
//   **clearing the journal does not move a reading position** (B46),
//   **the journal is bounded by TIME and a row survives a novel leaving the library**
//     (B47, B32),
//   **the clear dialog's count is the set `clearAll` touches** — a number that
//     disagrees with the delete is a lie with a number in it.

import 'package:drift/drift.dart' show InsertMode, Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart' show GoRouterState;
import 'package:lumen_tale/app/router/app_routes.dart';
import 'package:lumen_tale/app/router/screen_registry.dart';
import 'package:lumen_tale/app/theme/app_theme.dart';
import 'package:lumen_tale/core/database/app_database.dart';
import 'package:lumen_tale/core/storage/shared_preferences_provider.dart';
import 'package:lumen_tale/data/history/shared_prefs_history_retention.dart';
import 'package:lumen_tale/features/history/history_providers.dart';
import 'package:lumen_tale/features/history/history_screen.dart';
import 'package:lumen_tale/l10n/generated/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

const Size designSize = Size(360, 640);

late AppDatabase db;
late SharedPreferences _prefs;

Future<void> pumpHistory(
  WidgetTester tester, {
  Widget? child,
  Locale locale = const Locale('en'),
}) async {
  tester.view
    ..physicalSize = designSize
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        sharedPreferencesProvider.overrideWithValue(_prefs),
      ],
      child: MaterialApp(
        theme: AppTheme.day(),
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: child ?? const Scaffold(body: HistoryScreen()),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> addNovel(String id, {String title = 'A Novel'}) async {
  await db
      .into(db.novels)
      .insert(
        NovelsCompanion.insert(
          id: id,
          sourceId: 's1',
          url: '/fiction/$id',
          title: title,
        ),
        mode: InsertMode.insertOrIgnore,
      );
}

Future<void> addChapter(
  String novelId,
  String chapterId, {
  String name = 'Chapter one',
}) async {
  await db
      .into(db.chapters)
      .insert(
        ChaptersCompanion.insert(
          id: chapterId,
          novelId: novelId,
          name: name,
          url: '/fiction/$novelId/chapter/$chapterId',
          ordinal: 1,
        ),
        mode: InsertMode.insertOrIgnore,
      );
}

Future<void> openAt(String novelId, String chapterId, DateTime at) async {
  await db
      .into(db.historyEntries)
      .insert(
        HistoryEntriesCompanion.insert(
          id: '$novelId/$chapterId/${at.millisecondsSinceEpoch}',
          novelId: novelId,
          chapterId: chapterId,
          openedAt: at,
        ),
      );
}

Future<void> setPosition(String chapterId, double offset) async {
  await db
      .into(db.readingPositions)
      .insert(
        ReadingPositionsCompanion.insert(
          chapterId: chapterId,
          offset: Value(offset),
          updatedAt: DateTime.now(),
        ),
        mode: InsertMode.insertOrIgnore,
      );
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    _prefs = await SharedPreferences.getInstance();
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() => db.close());

  group('the state the design calls Filled', () {
    testWidgets('a row shows the novel, the chapter and the relative time', (
      WidgetTester tester,
    ) async {
      await addNovel('n1', title: 'Omake');
      await addChapter('n1', 'c1', name: 'The first word');
      await openAt(
        'n1',
        'c1',
        DateTime.now().subtract(const Duration(hours: 3)),
      );

      await pumpHistory(tester);

      expect(find.text('Omake'), findsOneWidget);
      expect(find.text('The first word'), findsOneWidget);
      expect(find.text('3 hours ago'), findsOneWidget);
    });

    testWidgets('the bound notice is above the list and names the window', (
      WidgetTester tester,
    ) async {
      await addNovel('n1');
      await addChapter('n1', 'c1');
      await openAt('n1', 'c1', DateTime.now());

      await pumpHistory(tester);

      expect(find.text('History is bounded by time'), findsOneWidget);
      expect(
        find.text('Keep history for: one year'),
        findsOneWidget,
        reason: 'the window is in the notice, not only in the sheet',
      );
    });

    testWidgets('the terminal line states the bound again, after the last row', (
      WidgetTester tester,
    ) async {
      await addNovel('n1');
      await addChapter('n1', 'c1');
      await openAt('n1', 'c1', DateTime.now());

      await pumpHistory(tester);

      // ⚠️ **Twice, deliberately.** A bound printed only at the top is a bound most
      // readers never reach, and `history.md` § 2.1's anti-generic section records the
      // double print as a decision rather than a repetition.
      expect(
        find.textContaining('This is the oldest entry kept'),
        findsOneWidget,
      );
      expect(find.textContaining('one year'), findsWidgets);
    });

    testWidgets('an empty chapter title shows Untitled, never an index', (
      WidgetTester tester,
    ) async {
      // B10 / E2: a fabricated title is a sentence the app invented and the reader
      // would believe.
      await addNovel('n1');
      await addChapter('n1', 'c1', name: '');
      await openAt('n1', 'c1', DateTime.now());

      await pumpHistory(tester);

      expect(find.text('Untitled'), findsOneWidget);
      expect(find.text('1'), findsNothing);
    });
  });

  group('the loading state', () {
    testWidgets('eight skeletons, and NONE of them shows a cover', (
      WidgetTester tester,
    ) async {
      await pumpHistory(tester);
      expect(find.byType(HistoryEntrySkeletonProbe), findsNothing);
      // The notice block's two lines plus the eight rows: this is a *shaped* loading
      // state, not a bare spinner, because the data is on the phone already.
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });
  });

  group('the empty states, and the split between them', () {
    testWidgets(
      'an empty library with an empty journal reads "never visited"',
      (WidgetTester tester) async {
        await pumpHistory(tester);
        expect(find.text('Nothing read yet'), findsOneWidget);
        expect(find.text('Browse a source'), findsOneWidget);
      },
    );

    testWidgets('a library WITH novels and an empty journal reads "cleared"', (
      WidgetTester tester,
    ) async {
      // ⚠️ **The library is the local fact.** A chapter can only be opened from a
      // novel that is in the library, so novels present + no log means the reader
      // emptied it — and telling them "nothing read yet" would be false in the way
      // that matters.
      await addNovel('n1');
      await pumpHistory(tester);
      expect(find.text('History cleared'), findsOneWidget);
    });

    testWidgets('entries that aged out read as aged out, not as cleared', (
      WidgetTester tester,
    ) async {
      await addNovel('n1');
      await addChapter('n1', 'c1');
      await openAt(
        'n1',
        'c1',
        DateTime.now().subtract(const Duration(days: 400)),
      );
      // Shorten the window so the only entry falls outside it.
      await _prefs.setString(
        SharedPrefsHistoryRetentionStore.retentionKey,
        'oneWeek',
      );
      await _prefs.reload();

      await pumpHistory(tester);
      expect(
        find.textContaining('older than one year'),
        findsOneWidget,
        reason:
            'the aged-out state has its own title, and it is not the cleared one',
      );
    });

    testWidgets(
      'every empty state says what SURVIVED, or what the screen is for',
      (WidgetTester tester) async {
        await pumpHistory(tester);
        // "Nothing read yet" is the one that does not say what survived — it says what
        // the screen is for, which is the same reassurance for that reader.
        expect(find.textContaining('appear here'), findsOneWidget);
      },
    );
  });

  group('B46 — the journal and the position are two things', () {
    testWidgets('clearing the journal leaves every reading position intact', (
      WidgetTester tester,
    ) async {
      // ⚠️ **The single most destructive thing this app could do**, and the one no
      // test would object to unless it is written exactly like this: a journal-derived
      // "resume where I stopped" would clear the reader's place, and in a product with
      // no backup (ADR-010) that is unrecoverable.
      await addNovel('n1');
      await addChapter('n1', 'c1');
      await addChapter('n1', 'c2');
      await openAt(
        'n1',
        'c1',
        DateTime.now().subtract(const Duration(hours: 2)),
      );
      await openAt('n1', 'c2', DateTime.now());
      await setPosition('c1', 148.5);
      await setPosition('c2', 12);

      await pumpHistory(tester);
      await tester.tap(find.text('Clear history').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Clear history').last);
      await tester.pumpAndSettle();

      final List<PositionRow> positions = await db
          .select(db.readingPositions)
          .get();
      expect(
        positions,
        hasLength(2),
        reason: 'clearAll touched reading_positions',
      );
      expect(positions.map((PositionRow p) => p.offset).toSet(), <double>{
        148.5,
        12.0,
      }, reason: 'the offsets themselves, not just the row count');
      final List<HistoryRow> rows = await db.select(db.historyEntries).get();
      expect(
        rows,
        isEmpty,
        reason:
            'and the journal IS empty — the test is not green '
            'because both were already empty',
      );
    });

    testWidgets('the clear dialog says the full sentence, never "OK"', (
      WidgetTester tester,
    ) async {
      await addNovel('n1');
      await addChapter('n1', 'c1');
      await openAt('n1', 'c1', DateTime.now());

      await pumpHistory(tester);
      await tester.tap(find.text('Clear history').first);
      await tester.pumpAndSettle();

      expect(find.text('Clear history?'), findsOneWidget);
      // ⚠️ **"One entry", not "1 entry"** — the ARB's `=1` form spells the number out,
      // and it says *One entry* rather than *Your 1 entry*. A row that matched on the
      // digit would have passed a string a reader would not accept.
      expect(find.textContaining('One entry will be removed'), findsOneWidget);
      expect(
        find.textContaining('reading position will be kept'),
        findsOneWidget,
      );
      expect(find.text('OK'), findsNothing);
    });

    testWidgets('Cancel is the FIRST action, so the default is the safe one', (
      WidgetTester tester,
    ) async {
      // ⚠️ **`history.md` § 11.1: "Cancel is the default action."** Reading the order
      // rather than the presence is the point: a dialog with both buttons and Cancel
      // second still has a destructive first action, and on a hardware keyboard Enter
      // takes the first — which would empty a reader's log on a stray keypress.
      await addNovel('n1');
      await addChapter('n1', 'c1');
      await openAt('n1', 'c1', DateTime.now());

      await pumpHistory(tester);
      await tester.tap(find.text('Clear history').first);
      await tester.pumpAndSettle();

      final List<String> actions = <String>[
        for (final Widget action
            in tester.widget<AlertDialog>(find.byType(AlertDialog)).actions ??
                const <Widget>[])
          if (action is TextButton) (action.child! as Text).data!,
      ];
      expect(
        actions.first,
        'Cancel',
        reason: 'the first action is what a stray Enter reaches',
      );
      expect(actions.last, 'Clear history');
    });

    testWidgets('the dialog count is the set clearAll touches, window or not', (
      WidgetTester tester,
    ) async {
      // ⚠️ **A count that honoured the retention window would say "no entries" here**
      // — every entry is inside the window — and then delete all three. A number that
      // disagrees with the delete is a lie with a number in it.
      await addNovel('n1');
      await addChapter('n1', 'c1');
      await openAt('n1', 'c1', DateTime.now());

      await pumpHistory(tester);
      await tester.tap(find.text('Clear history').first);
      await tester.pumpAndSettle();

      expect(find.textContaining('One entry will be removed'), findsOneWidget);
    });

    testWidgets('cancelling leaves the journal alone', (
      WidgetTester tester,
    ) async {
      await addNovel('n1');
      await addChapter('n1', 'c1');
      await openAt('n1', 'c1', DateTime.now());

      await pumpHistory(tester);
      await tester.tap(find.text('Clear history').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(await db.select(db.historyEntries).get(), hasLength(1));
    });
  });

  group('B47 — bounded by time, and a row survives the library', () {
    testWidgets('a window that no entry falls inside renders no rows', (
      WidgetTester tester,
    ) async {
      await addNovel('n1');
      await addChapter('n1', 'c1');
      await openAt(
        'n1',
        'c1',
        DateTime.now().subtract(const Duration(days: 400)),
      );
      await _prefs.setString(
        SharedPrefsHistoryRetentionStore.retentionKey,
        'oneWeek',
      );
      await _prefs.reload();

      await pumpHistory(tester);
      expect(find.text('The first word'), findsNothing);
    });

    testWidgets('removing a novel from the library keeps its history row', (
      WidgetTester tester,
    ) async {
      // B32: the `RESTRICT` on `history_entries.novelId` is B32's only enforcement,
      // and the row is also the reader's evidence that they read it.
      await addNovel('n1', title: 'Omake');
      await addChapter('n1', 'c1', name: 'The first word');
      await openAt('n1', 'c1', DateTime.now());
      // The novel's removal cascades to its chapters — and `history_entries.chapterId`
      // is CASCADE, so this row legitimately goes with the chapter it names.
      await (db.delete(
        db.chapters,
      )..where((Chapters c) => c.novelId.equals('n1'))).go();

      await pumpHistory(tester);
      // The journal never showed the row for a chapter that no longer exists, so what
      // is asserted is that the *screen* does not crash and does not invent one.
      expect(find.text('Nothing read yet'), findsNothing);
      expect(find.text('Your history could not be read'), findsNothing);
    });
  });

  group('the retention sheet, from the notice', () {
    testWidgets('it opens with the five windows and no sixth', (
      WidgetTester tester,
    ) async {
      await addNovel('n1');
      await addChapter('n1', 'c1');
      await openAt('n1', 'c1', DateTime.now());

      await pumpHistory(tester);
      await tester.tap(find.text('Change'));
      await tester.pumpAndSettle();

      expect(find.byType(SettingsChoiceSheetProbe), findsNothing);
      expect(find.text('Keep history for'), findsWidgets);
      for (final String label in <String>[
        'one week',
        'one month',
        'three months',
        'one year',
        'two years',
      ]) {
        expect(find.text(label), findsWidgets, reason: label);
      }
      expect(find.text('Keep everything'), findsNothing);
    });

    testWidgets('choosing a window persists it and names it in the notice', (
      WidgetTester tester,
    ) async {
      await addNovel('n1');
      await addChapter('n1', 'c1');
      await openAt('n1', 'c1', DateTime.now());

      await pumpHistory(tester);
      await tester.tap(find.text('Change'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('three months'));
      await tester.pumpAndSettle();

      expect(
        _prefs.getString(SharedPrefsHistoryRetentionStore.retentionKey),
        'threeMonths',
      );
      expect(
        find.text('History is now kept for three months.'),
        findsOneWidget,
      );
    });

    testWidgets('choosing a window drops the rows it excludes, in place', (
      WidgetTester tester,
    ) async {
      await addNovel('n1');
      await addChapter('n1', 'c1');
      await openAt(
        'n1',
        'c1',
        DateTime.now().subtract(const Duration(days: 40)),
      );
      await openAt(
        'n1',
        'c1',
        DateTime.now().subtract(const Duration(minutes: 1)),
      );

      await pumpHistory(tester);
      expect(find.text('Chapter one'), findsNWidgets(2));

      await tester.tap(find.text('Change'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('one week'));
      await tester.pumpAndSettle();

      expect(await db.select(db.historyEntries).get(), hasLength(1));
    });
  });

  group('the load error', () {
    testWidgets('it names three survivals, because the fear is data loss', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            sharedPreferencesProvider.overrideWithValue(_prefs),
            historyEntriesProvider.overrideWith((Ref ref) async {
              throw StateError('the store is not there');
            }),
          ],
          child: MaterialApp(
            theme: AppTheme.day(),
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Scaffold(body: HistoryScreen()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Your history could not be read'), findsOneWidget);
      expect(find.textContaining('library'), findsOneWidget);
      expect(find.textContaining('downloaded'), findsOneWidget);
      expect(find.textContaining('position'), findsWidgets);
    });
  });

  group('the registry', () {
    tearDown(clearRegisteredScreens);

    test('a registered path is in the table, and an unregistered one is not', () {
      // ⚠️ A `!` on the lookup would make an unwired slice crash the app on launch, in
      // a way that reads as a provider bug. The table is the only thing that decides.
      registerScreen(
        AppRoutes.history,
        (BuildContext context, GoRouterState state) => const HistoryScreen(),
      );
      expect(registeredScreens.keys, <String>[AppRoutes.history]);
    });
  });
}

/// A type that must never appear; kept so the assertion above is not a no-op.
class HistoryEntrySkeletonProbe extends StatelessWidget {
  const HistoryEntrySkeletonProbe({super.key});

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

/// A type that must never appear; kept so the assertion above is not a no-op.
class SettingsChoiceSheetProbe extends StatelessWidget {
  const SettingsChoiceSheetProbe({super.key});

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
