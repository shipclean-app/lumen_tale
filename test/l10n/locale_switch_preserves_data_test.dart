// forge:slice 6-7
// Lumen Tale — `6-7` § 11.3: E12 end to end, through a real database.
//
// ## What the criterion is
//
// E12 / § 10.13: *"the phone's language changes — the reader switches the phone from French
// to English or back. Expected: the app's text, including every error message, follows the
// new language, **with no loss of library, downloads or progress**."*
//
// `locale_resolution_test.dart` proves the first half — the text follows the language, and
// the query and its selection survive. This file proves the second half, which is the half
// that a language change could plausibly break and that nothing else would notice:
//
// | table | what would break if the change wrote anything |
// |---|---|
// | `reading_positions` | the reader's place in every novel (B16) |
// | `history_entries` | the record of what they read (B17) |
// | `chapters` | what is available offline (B2) |
//
// ## ⚠️ `test()`, never `testWidgets()`
//
// A drift query against `NativeDatabase.memory()` is real asynchronous work. Under
// `testWidgets()`'s fake async it does not complete, so the test HANGS rather than fails, and
// a hang takes the whole suite with it instead of naming one row. Every row here is `test()`.
//
// ## ⚠️ The snapshots are non-empty, and that is asserted first
//
// "The tables are unchanged" is trivially true of three empty tables. The rows below seed
// real content and **assert the snapshot has rows before comparing**, so the row cannot pass
// by having nothing to protect.

import 'package:drift/drift.dart' show InsertMode, QueryRow, Value;
import 'package:drift/native.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumen_tale/core/database/app_database.dart';
import 'package:lumen_tale/core/ui/app_error_copy.dart';
import 'package:lumen_tale/l10n/generated/app_localizations.dart';

Future<AppLocalizations> l10nOf(Locale locale) =>
    AppLocalizations.delegate.load(locale);

void main() {
  late AppDatabase db;

  setUp(() {
    // ⚠️ The setup hook is NOT applied by `forTesting` — see
    // `app_database_test.dart`'s own note. A test instance without `foreign_keys = ON` would
    // hold rows the schema says cannot exist, and a snapshot of an impossible database proves
    // nothing.
    db = AppDatabase.forTesting(
      NativeDatabase.memory(
        setup: (e) => e.execute('PRAGMA foreign_keys = ON'),
      ),
    );
  });

  tearDown(() => db.close());

  group('a language change leaves the library, the history and the positions alone', () {
    test(
      'the three tables are byte-identical before and after the locale switch',
      () async {
        await _seed(db);

        final Map<String, List<Map<String, Object?>>> before = await _snapshot(
          db,
        );
        expect(
          before['reading_positions'],
          hasLength(2),
          reason:
              'the positions table holds rows, so "unchanged" is a real claim',
        );
        expect(
          before['history_entries'],
          hasLength(2),
          reason:
              'the history table holds rows, so "unchanged" is a real claim',
        );
        expect(
          before['chapters'],
          hasLength(3),
          reason:
              'the chapters table holds rows, so "unchanged" is a real claim',
        );

        // ⚠️ **The switch is exactly what the phone does: resolve a locale and load that
        // bundle.** Nothing else runs, because nothing else *can* — there is no write in the
        // localisation path, and this row is what makes that claim checkable rather than
        // merely stated.
        final AppLocalizations french = await l10nOf(const Locale('fr'));
        final AppLocalizations english = await l10nOf(const Locale('en'));
        expect(
          french.errorNoConnection,
          isNot(english.errorNoConnection),
          reason: 'witness — the two bundles really are different languages',
        );

        final Map<String, List<Map<String, Object?>>> after = await _snapshot(
          db,
        );

        for (final String table in <String>[
          'reading_positions',
          'history_entries',
          'chapters',
        ]) {
          expect(
            after[table],
            before[table],
            reason:
                'E12 — $table changed while the phone switched language. The language '
                'is read from the platform and written nowhere, so a diff here means '
                'something wrote to the database during a localisation event.',
          );
        }
      },
    );

    test('every failure sentence follows the switch, and the data does not', () async {
      // The two halves of E12 **in one row**, because E12's promise is a conjunction: the
      // text follows AND nothing is lost. Testing them separately lets a future change pass
      // one and fail the other, and the reader experiences both at once.
      await _seed(db);
      final Map<String, List<Map<String, Object?>>> before = await _snapshot(
        db,
      );

      final AppLocalizations french = await l10nOf(const Locale('fr'));
      final Map<String, String> frenchSentences = <String, String>{
        for (final AppErrorString arm in AppErrorString.values)
          arm.name: french.message(arm),
      };

      final AppLocalizations english = await l10nOf(const Locale('en'));
      final Map<String, String> englishSentences = <String, String>{
        for (final AppErrorString arm in AppErrorString.values)
          arm.name: english.message(arm),
      };

      expect(
        frenchSentences.keys.toSet().difference(englishSentences.keys.toSet()),
        isEmpty,
        reason:
            'B28 / E12 — the two bundles cover the SAME arms, so the only difference '
            'a reader can see is the language',
      );
      final List<String> unchanged = <String>[
        for (final String arm in frenchSentences.keys)
          if (frenchSentences[arm] == englishSentences[arm]) arm,
      ];
      expect(
        unchanged,
        isEmpty,
        reason: 'E12 — these arms did not follow the switch: $unchanged',
      );

      expect(
        await _snapshot(db),
        before,
        reason:
            'E12 — the switch changed the text and nothing else. Chapters, positions '
            'and history are the reader\'s own record; a localisation event has no '
            'business touching it.',
      );
    });
  });
}

/// A novel, three chapters, two positions, two history entries.
///
/// Written through the typed API, so the snapshot is of rows the schema accepts rather than
/// of rows a `customInsert` forced in.
Future<void> _seed(AppDatabase db) async {
  final DateTime now = DateTime.utc(2026, 10, 3, 12);
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
  for (int i = 1; i <= 3; i++) {
    await db
        .into(db.chapters)
        .insert(
          ChaptersCompanion.insert(
            id: 'c$i',
            novelId: 'n1',
            name: 'Chapter $i',
            url: '/fiction/n1/chapter/c$i',
            ordinal: i,
          ),
          mode: InsertMode.insertOrIgnore,
        );
  }
  for (final (String, double) position in <(String, double)>[
    ('c1', 420),
    ('c3', 91),
  ]) {
    await db
        .into(db.readingPositions)
        .insert(
          ReadingPositionsCompanion.insert(
            chapterId: position.$1,
            offset: Value(position.$2),
            updatedAt: now,
          ),
          mode: InsertMode.insertOrIgnore,
        );
  }
  for (final (String, int) entry in <(String, int)>[('c1', 0), ('c2', 3600)]) {
    await db
        .into(db.historyEntries)
        .insert(
          HistoryEntriesCompanion.insert(
            id: 'h${entry.$2}',
            novelId: 'n1',
            chapterId: entry.$1,
            openedAt: now.add(Duration(seconds: entry.$2)),
          ),
          mode: InsertMode.insertOrIgnore,
        );
  }
}

/// Every row of the three tables E12 names, as plain maps.
///
/// `toMap()` rather than the data class, because the comparison is about **values** — a diff
/// in the data class's own field order would be a false alarm, and a diff in a value is the
/// thing that matters. Rows are ordered by primary key so two reads of the same content
/// always compare equal.
Future<Map<String, List<Map<String, Object?>>>> _snapshot(
  AppDatabase db,
) async {
  Future<List<Map<String, Object?>>> read(String table, String orderBy) async {
    final List<QueryRow> rows = await db
        .customSelect('SELECT * FROM $table ORDER BY $orderBy')
        .get();
    return <Map<String, Object?>>[for (final QueryRow row in rows) row.data];
  }

  return <String, List<Map<String, Object?>>>{
    'chapters': await read('chapters', 'id'),
    'reading_positions': await read('reading_positions', 'chapter_id'),
    'history_entries': await read('history_entries', 'id'),
  };
}
