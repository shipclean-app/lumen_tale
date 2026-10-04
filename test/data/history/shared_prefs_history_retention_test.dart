// forge:slice 6-5
// Lumen Tale — `6-5`'s retention store, and the count that must run BEFORE a purge.
//
// ## The two properties worth stating before the rows
//
//   **A read writes nothing.** The default is the ABSENCE of a key, so "has the reader
//   chosen a window?" stays answerable — the same rule as `theme-type`'s two keys, and
//   the reason a row asserts the prefs map is still empty after a read.
//
//   **The count is strictly-before, and the purge is strictly-before.** If they
//   disagreed by one, a reader would read a notice saying "three entries will be
//   dropped" and watch two disappear. The count is the part that is supposed to be the
//   honest one, so the agreement is asserted directly rather than left to two predicates
//   that look alike.

import 'package:drift/drift.dart' show InsertMode;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumen_tale/core/database/app_database.dart';
import 'package:lumen_tale/data/history/drift_history_repository.dart';
import 'package:lumen_tale/data/history/shared_prefs_history_retention.dart';
import 'package:lumen_tale/domain/history/history_retention.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late DriftHistoryRepository history;
  late SharedPreferences prefs;
  late SharedPrefsHistoryRetentionStore store;
  final DateTime now = DateTime.utc(2026, 10, 3, 12);

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    db = AppDatabase.forTesting(NativeDatabase.memory());
    history = DriftHistoryRepository(db);
    prefs = await SharedPreferences.getInstance();
    store = SharedPrefsHistoryRetentionStore(
      prefs,
      (DateTime cutoff, {required bool exclusive}) =>
          countHistoryEntriesOlderThan(db, cutoff, exclusive: exclusive),
    );
  });

  tearDown(() => db.close());

  Future<void> addNovelAndChapter(String chapterId) async {
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
            id: chapterId,
            novelId: 'n1',
            name: 'Chapter $chapterId',
            url: '/fiction/n1/chapter/$chapterId',
            ordinal: 1,
          ),
        );
  }

  Future<void> openAt(DateTime at) async {
    await history.recordOpened(novelId: 'n1', chapterId: 'c1', openedAt: at);
  }

  group('the default is the absence of a key', () {
    test('an empty store reads oneYear and creates nothing', () async {
      expect(await store.read(), HistoryRetention.defaultWindow);
      expect(prefs.getKeys(), isEmpty, reason: 'a READ must not create a key');
    });

    test(
      'every window round-trips through its NAME, not its ordinal',
      () async {
        for (final HistoryRetention window in HistoryRetention.values) {
          await store.write(window);
          expect(await store.read(), window);
        }
      },
    );

    test(
      'a written key is the enum name, so an insertion cannot change it',
      () async {
        await store.write(HistoryRetention.threeMonths);
        expect(
          prefs.getString(SharedPrefsHistoryRetentionStore.retentionKey),
          'threeMonths',
        );
      },
    );
  });

  group('a refused write is loud — B24, C8', () {
    // `SharedPreferences` answers `false` to `setString` when the platform declines, and
    // it does **not** throw. Ignoring that leaves the screen showing a window the app
    // never stored, which is the exact state C8 forbids.
    test('a platform refusal throws rather than pretending', () async {
      final RefusingPreferences refusing = RefusingPreferences(prefs);
      final SharedPrefsHistoryRetentionStore loud =
          SharedPrefsHistoryRetentionStore(
            refusing,
            (DateTime cutoff, {required bool exclusive}) async => 0,
          );

      await expectLater(
        loud.write(HistoryRetention.oneWeek),
        throwsA(isA<SettingsPersistenceException>()),
        reason:
            'a window the app cannot remember must not be displayed as chosen',
      );
    });

    test(
      'the exception carries the key and never the value a reader typed',
      () {
        const SettingsPersistenceException failure =
            SettingsPersistenceException('app.historyRetention', 'threeMonths');
        expect(failure.key, 'app.historyRetention');
        expect(failure.toString(), isNot(contains('threeMonths')));
      },
    );
  });

  group('countOlderThan counts what is ABOUT to leave', () {
    test('an empty journal counts zero', () async {
      expect(
        await store.countOlderThan(
          HistoryRetention.threeMonths.cutoffFrom(now),
        ),
        0,
      );
    });

    test('only the entries older than the cutoff are counted', () async {
      await addNovelAndChapter('c1');
      final DateTime cutoff = HistoryRetention.threeMonths.cutoffFrom(now);
      await openAt(now);
      await openAt(cutoff.subtract(const Duration(days: 1)));
      await openAt(cutoff.subtract(const Duration(days: 10)));

      expect(await store.countOlderThan(cutoff), 2);
    });

    test('an entry EXACTLY at the cutoff is not counted', () async {
      // ⚠️ **The row the whole agreement rests on.** `purgeOlderThan` deletes
      // `opened_at < cutoff`, so a count of `<= cutoff` would announce one entry more
      // than will disappear. A reader who reads "one entry will be dropped" and watches
      // nothing vanish has been told a falsehood by a count.
      await addNovelAndChapter('c1');
      final DateTime cutoff = HistoryRetention.threeMonths.cutoffFrom(now);
      await openAt(cutoff);

      expect(await store.countOlderThan(cutoff), 0);
      expect(await history.purgeOlderThan(cutoff), 0);

      await openAt(cutoff.subtract(const Duration(seconds: 1)));
      expect(await store.countOlderThan(cutoff), 1);
      expect(await history.purgeOlderThan(cutoff), 1);
    });

    test('the announcement count equals the purge count, row for row', () async {
      // The direct statement of the property, with the count taken **before** the purge
      // — which is the only order in which the question is answerable. After a purge the
      // count is always zero, and that is true about the past and useless about the
      // decision the reader is making in front of the notice.
      await addNovelAndChapter('c1');
      final DateTime cutoff = HistoryRetention.oneMonth.cutoffFrom(now);
      for (int days = 40; days > 0; days -= 4) {
        await openAt(cutoff.subtract(Duration(days: days)));
      }
      await openAt(now);

      final int announced = await store.countOlderThan(cutoff);
      final int purged = await history.purgeOlderThan(cutoff);

      expect(
        announced,
        greaterThan(0),
        reason: 'the fixture must have old rows',
      );
      expect(purged, announced);
    });

    test(
      'the exclusive flag changes the count by exactly the boundary row',
      () async {
        await addNovelAndChapter('c1');
        final DateTime cutoff = HistoryRetention.oneYear.cutoffFrom(now);
        await openAt(cutoff);
        await openAt(cutoff.subtract(const Duration(seconds: 1)));

        expect(
          await countHistoryEntriesOlderThan(db, cutoff, exclusive: true),
          1,
        );
        expect(
          await countHistoryEntriesOlderThan(db, cutoff, exclusive: false),
          2,
          reason:
              'the inclusive form exists so a caller can ask about the boundary; the '
              'announcement path uses the exclusive one because the purge does',
        );
      },
    );
  });
}

/// `SharedPreferences` with `setString` answering `false` — a platform refusal, which
/// is a **real** outcome and does **not** throw.
///
/// The in-memory `SharedPreferences` has no seam for this, so the store takes the
/// platform interface rather than the concrete class; that is also why
/// `SharedPrefsThemePreferences` can be exercised the same way.
class RefusingPreferences implements SharedPreferences {
  RefusingPreferences(this._inner);

  final SharedPreferences _inner;

  @override
  Future<bool> setString(String key, String value) async => false;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      _inner.noSuchMethod(invocation);

  @override
  String? getString(String key) => _inner.getString(key);

  @override
  Set<String> getKeys() => _inner.getKeys();
}
