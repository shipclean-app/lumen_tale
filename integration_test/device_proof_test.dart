// Lumen Tale — on-device proof for Q-003.
//
// `flutter test` **cannot** do this. It runs `flutter_test` files on the host
// Dart VM, and it ignores `-d` entirely: passing a real device id, a fabricated
// one, or none at all produced byte-identical `os=linux` results on
// 2026-10-03. That is why every host test in this project, including the ones
// asserting foreign-key enforcement, is host evidence only. Only a file in
// `integration_test/` is actually deployed to the phone.
//
// What this file is for, and what it is not:
//
//   Q-003 asked whether the native SQLite build is validated on a real target.
//   The APK carrying `lib/arm64-v8a/libsqlite3.so` proves it was *compiled and
//   packaged*. That is not the same as *loaded*, and a packaged library that
//   fails to load still yields a green build. This file opens a real database
//   through the app's own `_openLazy()` and therefore closes the gap.
//
// The assertion that matters most is `foreign_keys`. SQLite ships with it OFF
// per connection and it is not part of the file format, so a database created
// with the pragma on opens with it off unless every connection turns it on
// again. `app_database.dart`'s `_setup()` is the only thing that re-enables it,
// and the `RESTRICT` on `history_entries.novelId` is B32's only enforcement. On
// the host the pragma holds; this asserts it holds against the device's own
// SQLite build, which is a different binary and the one that actually ships.

import 'dart:io';

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:lumen_tale/core/database/app_database.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // The production constructor on purpose. `AppDatabase.forTesting` takes an
  // executor and would bypass both `getApplicationSupportDirectory()` and the
  // `_setup()` pragma hook — which is the entire subject of this file.
  late AppDatabase db;

  setUp(() => db = AppDatabase());
  tearDown(() => db.close());

  group('this suite is actually on the device', () {
    // Deliberately first, and deliberately not decoration. Without it, every
    // assertion below would also pass on a laptop, and this file would be a
    // host test wearing a device filename. See the header: `-d` does nothing.
    test('runs on Android, not on the host Dart VM', () {
      expect(
        Platform.isAndroid,
        isTrue,
        reason:
            'If this fails, the suite ran on the host and proves nothing '
            'about the device. Do not trust any other test in this file.',
      );

      // Printed, not asserted on. An OEM is free to replace this string: the
      // nubia Z2577 reports `MyOS16.0.8_Z2577_AE`, which does not contain
      // "Android". A first draft of this file asserted `contains('Android')`
      // and failed on a real device while passing on the host — the assertion
      // was wrong, not the device. `Platform.isAndroid` above is the guard that
      // holds; the version string is only here so a failing run says which
      // machine it was actually on.
      expect(Platform.operatingSystemVersion, isNotEmpty);
      // ignore: avoid_print
      print('PROBE device=${Platform.operatingSystemVersion}');
    });
  });

  group('Q-003 — the native library loads and the DDL executes', () {
    test('a real database file opens through the production path', () async {
      // Reaching a query at all means libsqlite3.so loaded, drift opened the
      // file, and onCreate ran createAll against the device's SQLite build.
      expect(db.schemaVersion, 1);

      final tables = await db
          .customSelect(
            "SELECT name FROM sqlite_master WHERE type = 'table' "
            "AND name NOT LIKE 'sqlite_%' ORDER BY name",
          )
          .get();
      final names = tables.map((r) => r.read<String>('name')).toSet();

      expect(
        names,
        containsAll(<String>{
          'novels',
          'chapters',
          'reading_positions',
          'history_entries',
          'queue_items',
          'sources',
        }),
        reason:
            'A table whose DDL the device SQLite rejects throws here, '
            'which is the point: this DDL has now been executed on Android.',
      );
    });

    test('the file lives in application support, not cache', () async {
      // B7 — the OS may evict the cache directory, and this database holds the
      // library, reading positions and history. Asserted on device because the
      // platform path is the thing that could differ from the host.
      final tables = await db
          .customSelect(
            "SELECT file FROM pragma_database_list WHERE name = 'main'",
          )
          .getSingle();
      final path = tables.read<String>('file');
      expect(path, isNot(contains('/cache/')));
      expect(path, endsWith('lumen.db'));
    });
  });

  group('B32 — the constraints are enforced on the device, not just declared', () {
    test('foreign_keys is ON on this connection', () async {
      final r = await db.customSelect('PRAGMA foreign_keys').getSingle();
      expect(
        r.read<int>('foreign_keys'),
        1,
        reason:
            'SQLite defaults this to 0 per connection. If it is 0 here, '
            '_setup() did not run and every constraint below is a no-op — '
            'B32 would read correctly and not hold.',
      );
    });

    test('deleting a novel cascades to its chapters', () async {
      await db
          .into(db.novels)
          .insert(
            NovelsCompanion.insert(
              id: 'dev-cascade-novel',
              sourceId: 'dev',
              url: '/dev/a',
              title: 'Device cascade',
            ),
          );
      await db
          .into(db.chapters)
          .insert(
            ChaptersCompanion.insert(
              id: 'dev-cascade-chapter',
              novelId: 'dev-cascade-novel',
              name: 'One',
              url: '/dev/a_1',
              ordinal: 0,
            ),
          );

      await (db.delete(
        db.novels,
      )..where((n) => n.id.equals('dev-cascade-novel'))).go();

      final left = await db.select(db.chapters).get();
      expect(left, isEmpty, reason: 'a chapter cannot outlive its novel');
    });

    test('B32 — history survives its novel, and the RESTRICT refuses', () async {
      await db
          .into(db.novels)
          .insert(
            NovelsCompanion.insert(
              id: 'dev-restrict-novel',
              sourceId: 'dev',
              url: '/dev/b',
              title: 'Device restrict',
              inLibrary: const Value(true),
            ),
          );
      await db
          .into(db.chapters)
          .insert(
            ChaptersCompanion.insert(
              id: 'dev-restrict-chapter',
              novelId: 'dev-restrict-novel',
              name: 'One',
              url: '/dev/b_1',
              ordinal: 0,
            ),
          );
      await db
          .into(db.historyEntries)
          .insert(
            HistoryEntriesCompanion.insert(
              id: 'dev-restrict-history',
              novelId: 'dev-restrict-novel',
              chapterId: 'dev-restrict-chapter',
              openedAt: DateTime.fromMillisecondsSinceEpoch(0),
            ),
          );

      // The behaviour, not the schema text. This is B32: removing a novel keeps
      // what the reader read, so the delete must be refused outright.
      await expectLater(
        (db.delete(
          db.novels,
        )..where((n) => n.id.equals('dev-restrict-novel'))).go(),
        throwsA(anything),
        reason:
            'RESTRICT must refuse. If this delete succeeds, history was '
            'destroyed as a side effect — B32 broken.',
      );

      // And the row is genuinely still there.
      final novel = await (db.select(
        db.novels,
      )..where((n) => n.id.equals('dev-restrict-novel'))).getSingle();
      expect(novel.id, 'dev-restrict-novel');

      final history = await (db.select(
        db.historyEntries,
      )..where((h) => h.id.equals('dev-restrict-history'))).getSingle();
      expect(history.id, 'dev-restrict-history');

      // Clean up in an order the constraints permit: child rows first.
      await (db.delete(
        db.historyEntries,
      )..where((h) => h.id.equals('dev-restrict-history'))).go();
      await (db.delete(
        db.chapters,
      )..where((c) => c.id.equals('dev-restrict-chapter'))).go();
      await (db.delete(
        db.novels,
      )..where((n) => n.id.equals('dev-restrict-novel'))).go();
    });
  });
}
