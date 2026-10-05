// forge:slice 3-7
// Lumen Tale — `/more/settings`: seven rows, and the four ways a settings screen lies.
//
//   **a value that says its own name** — every row prints the *value*, never the
//   control's state (§ 4: *"Values and consequences in words, never as a bare control
//   state"*);
//   **a count that is the set the delete touches** — and **never `0`** when the count
//   could not be obtained (B48);
//   **a read-only row inert by absence** — no chevron, no ripple, no greying;
//   **a destructive dialog that states how much** — in the TITLE, because a title is
//   what a reader reads first.

import 'package:drift/drift.dart' show InsertMode;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumen_tale/app/theme/app_theme.dart';
import 'package:lumen_tale/app/theme/app_version.dart';
// ⚠️ **`2-8` moved `pointSizeOf` here.** It used to live in `appearance_label.dart`, and the
// reader's `sizeButton` needed the same figure — which that file cannot hand across a
// feature boundary. The mapping now has one home both sides import, and this import is the
// only change to this file.
import 'package:lumen_tale/app/theme/reader_display_copy.dart';
import 'package:lumen_tale/app/theme/reader_scale.dart';
import 'package:lumen_tale/app/theme/theme_override.dart';
import 'package:lumen_tale/core/database/app_database.dart';
import 'package:lumen_tale/core/database/app_database_provider.dart';
import 'package:lumen_tale/core/storage/shared_preferences_provider.dart';
import 'package:lumen_tale/core/ui/settings_choice_sheet.dart';
import 'package:lumen_tale/domain/history/history_retention.dart';
import 'package:lumen_tale/features/settings/appearance_label.dart';
import 'package:lumen_tale/features/settings/language_label.dart';
import 'package:lumen_tale/features/settings/settings_providers.dart';
import 'package:lumen_tale/features/settings/settings_screen.dart';
import 'package:lumen_tale/l10n/generated/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

late AppDatabase db;
late SharedPreferences _prefs;

Future<void> pumpSettings(
  WidgetTester tester, {
  double height = 1400,
  ThemeOverride theme = ThemeOverride.system,
  ReaderTextScale scale = ReaderTextScale.md,
  BuildVersion version = const BuildVersion(
    buildName: '0.9.0',
    buildNumber: '41',
  ),
  Locale locale = const Locale('en'),
}) async {
  tester.view
    ..physicalSize = Size(360, height)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  setHistorySummaryLocale(locale);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(_prefs),
        appDatabaseProvider.overrideWithValue(db),
      ],
      child: Consumer(
        builder: (BuildContext context, WidgetRef ref, Widget? _) => MaterialApp(
          theme: AppTheme.day(),
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SettingsBody(
              version: version,
              themeOverride: theme,
              textScale: scale,
              ref: ref,
              // ⚠️ **The destinations are inert here.** A row that pushes a real route
              // would need the app's router in this test, and the rows below are about
              // what the page *says* — not about where it goes.
              onNavigate: const SettingsNavigation(
                openReaderSettings: _ignore,
                openHistory: _ignore,
                openOnboarding: _ignore,
                openAbout: _ignore,
                openRetentionSheet: _ignoreSheet,
                confirmClearHistory: _ignoreSheet,
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void _ignore(BuildContext context) {}

/// The page with the **real** `settingsNavigationProvider`, so the sheet and the dialog
/// are the ones `3-7` ships rather than no-ops.
Future<void> _pumpWithRealNavigation(WidgetTester tester) async {
  tester.view
    ..physicalSize = const Size(360, 1400)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  setHistorySummaryLocale(const Locale('en'));

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(_prefs),
        appDatabaseProvider.overrideWithValue(db),
      ],
      child: Consumer(
        builder: (BuildContext context, WidgetRef ref, Widget? _) =>
            MaterialApp(
              theme: AppTheme.day(),
              locale: const Locale('en'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: SettingsBody(
                  version: const BuildVersion(
                    buildName: '0.9.0',
                    buildNumber: '41',
                  ),
                  themeOverride: ThemeOverride.system,
                  textScale: ReaderTextScale.md,
                  ref: ref,
                  onNavigate: ref.read(settingsNavigationProvider),
                ),
              ),
            ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _ignoreSheet(BuildContext context, WidgetRef ref) async {}

Future<void> addNovelAndChapter() async {
  await db
      .into(db.novels)
      .insert(
        NovelsCompanion.insert(
          id: 'n1',
          sourceId: 's1',
          url: '/fiction/n1',
          title: 'A Novel',
        ),
        mode: InsertMode.insertOrIgnore,
      );
  await db
      .into(db.chapters)
      .insert(
        ChaptersCompanion.insert(
          id: 'c1',
          novelId: 'n1',
          name: 'Chapter one',
          url: '/fiction/n1/chapter/c1',
          ordinal: 1,
        ),
        mode: InsertMode.insertOrIgnore,
      );
}

Future<void> openAt(DateTime at) async {
  await db
      .into(db.historyEntries)
      .insert(
        HistoryEntriesCompanion.insert(
          id: 'h${at.millisecondsSinceEpoch}',
          novelId: 'n1',
          chapterId: 'c1',
          openedAt: at,
        ),
      );
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    _prefs = await SharedPreferences.getInstance();
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() => db.close());

  group('the rows, and the values they print', () {
    testWidgets('every live row is present, and there is no Check now', (
      WidgetTester tester,
    ) async {
      // ⚠️ **`Check now` is absent by decision** (file header): it is B36's update
      // check and no `8-*` slice has built one. A button that opens no check is a fake
      // control, so the row and its copy go together.
      await pumpSettings(tester);
      for (final String label in <String>[
        'Reader appearance',
        'Reading history',
        'Keep history for',
        'Clear reading history',
        'Language',
        'How this app works',
        'About Lumen Tale',
      ]) {
        expect(find.text(label), findsOneWidget, reason: label);
      }
      expect(find.text('Check now'), findsNothing);
    });

    testWidgets(
      'there is no LIBRARY group label, because the label would label nothing',
      (WidgetTester tester) async {
        // § 3: "an empty section label is worse than no section label".
        await pumpSettings(tester);
        expect(find.text('LIBRARY'), findsNothing);
        expect(find.text('READING'), findsOneWidget);
        expect(find.text('HISTORY'), findsOneWidget);
        expect(find.text('APP'), findsOneWidget);
      },
    );

    testWidgets(
      'the appearance row names the theme, the size and the point size',
      (WidgetTester tester) async {
        await pumpSettings(tester, theme: ThemeOverride.day);
        expect(find.text('Day · Medium (18 pt)'), findsOneWidget);
      },
    );

    testWidgets('the retention row prints the window NAME, not its enum name', (
      WidgetTester tester,
    ) async {
      // § 2.12's whole point: the row **names its own values**. `oneYear` in a
      // sentence is a string the app learned from its own code.
      await pumpSettings(tester);
      expect(find.text('one year'), findsOneWidget);
      expect(find.text('oneYear'), findsNothing);
    });

    testWidgets('the About row prints the version, or a dash when unreadable', (
      WidgetTester tester,
    ) async {
      await pumpSettings(tester);
      expect(find.text('Version 0.9.0 · build 41'), findsOneWidget);

      await pumpSettings(
        tester,
        version: const BuildVersion(buildName: '', buildNumber: ''),
      );
      // ⚠️ **A dash, not `Version —`.** An em dash looks like a version and C9 requires
      // the installed version to be determinable.
      expect(find.text('Version —'), findsNothing);
    });
  });

  group('the history count — three states, three words', () {
    testWidgets('a non-zero count prints the count and the oldest', (
      WidgetTester tester,
    ) async {
      await addNovelAndChapter();
      await openAt(DateTime.now().subtract(const Duration(hours: 3)));

      await pumpSettings(tester);
      expect(find.textContaining('1 entries'), findsOneWidget);
      // ⚠️ **The count is asserted, and the "oldest … ago" clause is not.**
      //
      // `relativeTimeLabel` deliberately renders **nothing** once the entry belongs to
      // an earlier local day (`6-5`'s three-buckets rule), so a fixture opened "3 hours
      // ago" has a *time-dependent* expected string: at 02:00 it is empty, at 14:00 it
      // is "3 hours ago". A row that pinned the phrase would pass at 14:00 and fail at
      // 02:00 on the same commit — so the phrase is pinned where `now` is an argument
      // instead, in `history_time_labels_test.dart`.
      expect(find.textContaining('oldest'), findsOneWidget);
    });

    testWidgets('an empty journal prints "0 entries" and NOT the sentence', (
      WidgetTester tester,
    ) async {
      // ⚠️ **"{count} entries · oldest {relative}"` with a zero has no oldest to name**,
      // so the zero is its own key. French takes the singular on zero ('0 entrée'),
      // which is a plural-rule difference and not a typo.
      await pumpSettings(tester);
      expect(find.text('0 entries'), findsOneWidget);
      expect(find.textContaining('oldest'), findsNothing);
    });

    testWidgets('a count that could not be obtained says so and NEVER says 0', (
      WidgetTester tester,
    ) async {
      // ⚠️ **The row this screen's Load-error state exists for.** § 4 (Load error,
      // declined) scopes the failure to this one row: a failed `COUNT` must not blank
      // eight correct rows, and it must never be rendered as a number (B48).
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(_prefs),
            appDatabaseProvider.overrideWithValue(db),
            historySummaryProvider.overrideWith(
              (Ref ref) async => throw StateError('the table is not there'),
            ),
          ],
          child: Consumer(
            builder: (BuildContext context, WidgetRef ref, Widget? _) =>
                MaterialApp(
                  theme: AppTheme.day(),
                  locale: const Locale('en'),
                  localizationsDelegates:
                      AppLocalizations.localizationsDelegates,
                  supportedLocales: AppLocalizations.supportedLocales,
                  home: Scaffold(
                    body: SettingsBody(
                      version: const BuildVersion(
                        buildName: '0.9.0',
                        buildNumber: '41',
                      ),
                      themeOverride: ThemeOverride.system,
                      textScale: ReaderTextScale.md,
                      ref: ref,
                      onNavigate: const SettingsNavigation(
                        openReaderSettings: _ignore,
                        openHistory: _ignore,
                        openOnboarding: _ignore,
                        openAbout: _ignore,
                        openRetentionSheet: _ignoreSheet,
                        confirmClearHistory: _ignoreSheet,
                      ),
                    ),
                  ),
                ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Count unavailable'), findsOneWidget);
      expect(find.text('0 entries'), findsNothing);
      // ⚠️ **And the other seven rows are untouched.** Blanking them to report one
      // failed `COUNT` would discard `one year`, `English` and `Day · Medium (18 pt)` —
      // the three values the reader opened the screen to check.
      expect(find.text('Keep history for'), findsOneWidget);
      expect(find.text('one year'), findsOneWidget);
      expect(find.text('Language'), findsOneWidget);
    });
  });

  group('the danger row', () {
    testWidgets('it is DISABLED on an empty journal, and says nothing', (
      WidgetTester tester,
    ) async {
      // § 4 (Empty — no data): "a dialog asking the reader to confirm destroying zero
      // entries is theatre".
      await pumpSettings(tester);
      final InkWell row = tester.widget<InkWell>(
        find
            .ancestor(
              of: find.text('Clear reading history'),
              matching: find.byType(InkWell),
            )
            .first,
      );
      expect(
        row.onTap,
        isNull,
        reason: 'no ripple, and no tap that then declines',
      );
    });

    testWidgets('it is DISABLED when the count could not be obtained', (
      WidgetTester tester,
    ) async {
      await addNovelAndChapter();
      await openAt(DateTime.now());
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(_prefs),
            appDatabaseProvider.overrideWithValue(db),
            historySummaryProvider.overrideWith(
              (Ref ref) async => throw StateError('the table is not there'),
            ),
          ],
          child: Consumer(
            builder: (BuildContext context, WidgetRef ref, Widget? _) =>
                MaterialApp(
                  theme: AppTheme.day(),
                  locale: const Locale('en'),
                  localizationsDelegates:
                      AppLocalizations.localizationsDelegates,
                  supportedLocales: AppLocalizations.supportedLocales,
                  home: Scaffold(
                    body: SettingsBody(
                      version: const BuildVersion(
                        buildName: '0.9.0',
                        buildNumber: '41',
                      ),
                      themeOverride: ThemeOverride.system,
                      textScale: ReaderTextScale.md,
                      ref: ref,
                      onNavigate: const SettingsNavigation(
                        openReaderSettings: _ignore,
                        openHistory: _ignore,
                        openOnboarding: _ignore,
                        openAbout: _ignore,
                        openRetentionSheet: _ignoreSheet,
                        confirmClearHistory: _ignoreSheet,
                      ),
                    ),
                  ),
                ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // ⚠️ **A dialog cannot state a count it does not have**, and stating how much is
      // the one thing the dialog exists to do — so the row is disabled, not opened with
      // a blank count.
      final InkWell row = tester.widget<InkWell>(
        find
            .ancestor(
              of: find.text('Clear reading history'),
              matching: find.byType(InkWell),
            )
            .first,
      );
      expect(row.onTap, isNull);
    });

    testWidgets('it is ENABLED when a count exists and is non-zero', (
      WidgetTester tester,
    ) async {
      await addNovelAndChapter();
      await openAt(DateTime.now());
      await pumpSettings(tester);

      final InkWell row = tester.widget<InkWell>(
        find
            .ancestor(
              of: find.text('Clear reading history'),
              matching: find.byType(InkWell),
            )
            .first,
      );
      expect(row.onTap, isNotNull);
    });
  });

  group('the read-only Language row', () {
    testWidgets('it carries NO chevron and NO ripple', (
      WidgetTester tester,
    ) async {
      // § 4 (Read-only): inert **by absence, not by greying**. B28 forbids the picker,
      // so a chevron would promise a destination that does not exist.
      await pumpSettings(tester);

      final InkWell languageRow = tester.widget<InkWell>(
        find
            .ancestor(of: find.text('Language'), matching: find.byType(InkWell))
            .first,
      );
      expect(
        languageRow.onTap,
        isNull,
        reason: 'no ripple and no tap — inert by absence, not by greying',
      );

      // ⚠️ **A COUNT, and it is 5.** The five tappable rows are *Reader
      // appearance*, *Reading history*, *Keep history for*, *How this app works* and
      // *About Lumen Tale*; the sixth row is read-only and the seventh is the danger row,
      // which has its own affordance.
      //
      // Asserting a per-row `findsNothing` **did not catch it.** `find.descendant(of:
      // an InkWell, …)` returned nothing even with a chevron forced onto the read-only
      // row, and a positive `findsWidgets` over the whole page cannot see an EXTRA one.
      // Counting can. The row above this one pins the row list, so the number here is
      // not a second statement of it — it is the assertion that *only* those five
      // carry a chevron.
      expect(find.byIcon(Icons.chevron_right), findsNWidgets(5));
    });

    testWidgets('it names the phone language IN THAT LANGUAGE', (
      WidgetTester tester,
    ) async {
      // An English UI with a French phone must read "Français": the row reports what
      // the PHONE is set to, and a value that changed with the ARB would be the app
      // naming the phone's language in the app's language.
      await pumpSettings(tester);
      expect(find.text('English'), findsOneWidget);

      await pumpSettings(tester, locale: const Locale('fr'));
      expect(find.text('Français'), findsOneWidget);
    });

    testWidgets('and it carries the hint saying where the real control is', (
      WidgetTester tester,
    ) async {
      await pumpSettings(tester);
      expect(
        find.textContaining('Follows your phone'),
        findsOneWidget,
        reason:
            'a read-only row with no explanation reads as a disabled control',
      );
    });
  });

  group('E11, in full, with the footer that admits why it is said here', () {
    testWidgets(
      'the disclosure, the footer and the ghost link are all present',
      (WidgetTester tester) async {
        await pumpSettings(tester, height: 2000);
        expect(
          find.textContaining('Nothing here is backed up'),
          findsOneWidget,
        );
        expect(
          find.textContaining('cannot warn you at the moment you uninstall'),
          findsOneWidget,
        );
        expect(find.text('What survives an update'), findsOneWidget);
      },
    );

    testWidgets('there is no "sign in", "backup" or "clear cache" anywhere', (
      WidgetTester tester,
    ) async {
      // § 11: all three are absent **by decision**, and a screen that looks like it is
      // missing something is a screen that will get them added back.
      await pumpSettings(tester, height: 2000);
      for (final String banned in <String>[
        'Sign in',
        'Backup',
        'Restore',
        'Export',
        'Free up space',
        'Clear cache',
        'Reset all settings',
      ]) {
        expect(find.textContaining(banned), findsNothing, reason: banned);
      }
    });
  });

  group('the helpers, as pure functions', () {
    test('the appearance label never prints a Dart name', () async {
      final AppLocalizations l10n = await AppLocalizations.delegate.load(
        const Locale('en'),
      );
      for (final ThemeOverride theme in ThemeOverride.values) {
        for (final ReaderTextScale scale in ReaderTextScale.values) {
          final String label = appearanceLabel(l10n, theme, scale);
          expect(label, isNot(contains(theme.name)));
          expect(label, isNot(contains(scale.name)));
        }
      }
    });

    test('the point size rises with the step, and starts at 16', () async {
      // E14 and "never below 16px": the smallest step IS the floor, so both hold
      // because the ladder's first rung is 16 and not because a check clamps it.
      final List<int> sizes = ReaderTextScale.values
          .map(pointSizeOf)
          .toList(growable: false);
      expect(sizes.first, greaterThanOrEqualTo(16));
      expect(sizes, orderedEquals(<int>[...sizes]..sort()));
      expect(
        sizes.toSet(),
        hasLength(sizes.length),
        reason: 'no two steps share a size',
      );
    });

    test('the language label falls back rather than rendering nothing', () async {
      final AppLocalizations l10n = await AppLocalizations.delegate.load(
        const Locale('en'),
      );
      expect(languageLabel(l10n, const Locale('en')), 'English');
      expect(languageLabel(l10n, const Locale('fr')), 'Français');
      // Unreachable in the app — `main.dart` resolves an unknown locale to French — but
      // answered rather than blank.
      expect(languageLabel(l10n, const Locale('de')), isNotEmpty);
    });

    test(
      'the history value never renders a failed count as a number',
      () async {
        final AppLocalizations l10n = await AppLocalizations.delegate.load(
          const Locale('en'),
        );
        expect(
          historyValueLabel(
            l10n,
            AsyncValue<HistorySummary>.error(
              StateError('x'),
              StackTrace.current,
            ),
          ),
          'Count unavailable',
        );
        expect(
          historyValueLabel(
            l10n,
            const AsyncValue<HistorySummary>.data(
              HistorySummary(entryCount: 0, oldestLabel: ''),
            ),
          ),
          '0 entries',
        );
      },
    );
  });

  group('the clear dialog, driven for real', () {
    testWidgets('its TITLE states the count, because a title is read first', (
      WidgetTester tester,
    ) async {
      // ⚠️ **The rest of this file stubs `SettingsNavigation`.** Stubbing it is right
      // for rows about wording and wrong for the dialog, whose one job is the number —
      // so this row uses the real provider, and a count of `0` or a missing count would
      // slip past every other assertion in the file.
      await addNovelAndChapter();
      for (int i = 0; i < 3; i++) {
        await openAt(DateTime.now().subtract(Duration(hours: i)));
      }
      await _pumpWithRealNavigation(tester);

      await tester.tap(find.text('Clear reading history'));
      await tester.pumpAndSettle();

      expect(find.text('Clear 3 entries?'), findsOneWidget);
      expect(
        find.text(
          'Reading positions are not part of this list and will not be touched.',
        ),
        findsOneWidget,
        reason: 'B46, and it is the body — the count is the title',
      );
    });

    testWidgets('Cancel is the first action, so the default is the safe one', (
      WidgetTester tester,
    ) async {
      await addNovelAndChapter();
      await openAt(DateTime.now());
      await _pumpWithRealNavigation(tester);

      await tester.tap(find.text('Clear reading history'));
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
        reason: 'the first action is what Enter reaches',
      );
      expect(actions.last, 'Clear');
    });

    testWidgets('cancelling leaves the journal alone', (
      WidgetTester tester,
    ) async {
      await addNovelAndChapter();
      await openAt(DateTime.now());
      await _pumpWithRealNavigation(tester);

      await tester.tap(find.text('Clear reading history'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(await db.select(db.historyEntries).get(), hasLength(1));
    });
  });

  group('B46 through this screen', () {
    testWidgets('the value line count is the set clearAll touches', (
      WidgetTester tester,
    ) async {
      // ⚠️ The row says "N entries" and the danger row deletes the whole journal. A
      // count inside the retention window would report 0 for a reader with a full
      // history, and the dialog would ask consent to deleting 1,200 entries while
      // saying "nothing will be removed".
      await addNovelAndChapter();
      for (int hours = 1; hours <= 3; hours++) {
        await openAt(DateTime.now().subtract(Duration(hours: hours)));
      }
      await _prefs.setString('app.historyRetention', 'oneWeek');

      await pumpSettings(tester);
      expect(find.textContaining('3 entries'), findsOneWidget);
      expect(
        await db.select(db.historyEntries).get(),
        hasLength(3),
        reason: 'the fixture really does hold three rows',
      );
    });

    testWidgets('the retention row and the History screen read the SAME enum', (
      WidgetTester tester,
    ) async {
      // § 2.12: two lists of the same values in two places is two truths about how long
      // history lasts. This screen's sheet rows come from `retentionOptions`, which is
      // the History screen's list.
      final AppLocalizations l10n = await AppLocalizations.delegate.load(
        const Locale('en'),
      );
      final List<SettingsChoiceOption<HistoryRetention>> rows =
          retentionOptions(l10n);
      expect(rows, hasLength(HistoryRetention.values.length));
      expect(
        rows.map((SettingsChoiceOption<HistoryRetention> r) => r.value),
        HistoryRetention.values,
      );
      // ⚠️ **And no sixth.** `design-system.md` § 2.12: an unbounded value next to
      // bounded ones teaches the reader the bounds are negotiable.
      expect(find.text('Keep everything'), findsNothing);
    });
  });
}
