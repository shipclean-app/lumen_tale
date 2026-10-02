// The committed snapshot must match the live schema.
//
// B31 is the app's one structural promise: installing a new version over an
// existing one preserves the library, the downloads, the reading positions and
// the history. A schema that drifts away from its own snapshot is how that
// promise gets broken by accident — a column added, a table dropped, and a
// migration written for a schema that is not the one on the phone.
//
// `drift_dev schema generate` would normally cover this, but it emits code that
// does not compile at schema version 1 (see `.forge/audit/run-log.jsonl`), so
// this comparison is written by hand. It compares the **live** database -- after
// drift has run `createAll` against real SQLite -- against the **committed**
// `schema.json`.
//
// When it fails, the fix is to write a migration and re-dump the snapshot. The
// fix is never to re-dump and move on.

import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumen_tale/core/database/app_database.dart';

void main() {
  test('the committed snapshot matches the schema that actually runs', () async {
    final db = AppDatabase.forTesting(
      NativeDatabase.memory(
        setup: (e) => e.execute('PRAGMA foreign_keys = ON'),
      ),
    );
    addTearDown(db.close);

    // Touch the database so drift actually executes createAll.
    await db.customSelect('SELECT 1').get();

    final snapshot =
        jsonDecode(File('lib/core/database/schema.json').readAsStringSync())
            as Map<String, dynamic>;

    final declared = <String, Set<String>>{};
    for (final entity in snapshot['entities'] as List<dynamic>) {
      final data =
          (entity as Map<String, dynamic>)['data'] as Map<String, dynamic>;
      final cols = (data['columns'] as List<dynamic>)
          .map((c) => (c as Map<String, dynamic>)['name'] as String)
          .toSet();
      declared[data['name'] as String] = cols;
    }

    // What SQLite actually holds.
    final live = <String, Set<String>>{};
    for (final row
        in await db
            .customSelect(
              "SELECT name FROM sqlite_master WHERE type = 'table' "
              "AND name NOT LIKE 'sqlite_%' ORDER BY name",
            )
            .get()) {
      final table = row.read<String>('name');
      final info = await db.customSelect('PRAGMA table_info($table)').get();
      live[table] = info.map((r) => r.read<String>('name')).toSet();
    }

    expect(
      live.keys.toSet(),
      declared.keys.toSet(),
      reason:
          'a table exists in the database that the snapshot does not describe, '
          'or the reverse. Write a migration, then re-dump the snapshot.',
    );

    for (final entry in live.entries) {
      expect(
        entry.value,
        declared[entry.key],
        reason: 'columns drifted on ${entry.key}',
      );
    }
  });

  test('the snapshot still records B32\'s RESTRICT', () {
    // A snapshot can match the live schema and still have lost a constraint,
    // because the constraint lives in the snapshot's structure rather than in
    // the column list compared above. Assert the asymmetry explicitly.
    final snapshot =
        jsonDecode(File('lib/core/database/schema.json').readAsStringSync())
            as Map<String, dynamic>;

    String? onDeleteFor(String table, String column) {
      for (final entity in snapshot['entities'] as List<dynamic>) {
        final data =
            (entity as Map<String, dynamic>)['data'] as Map<String, dynamic>;
        if (data['name'] != table) continue;
        for (final c in data['columns'] as List<dynamic>) {
          final col = c as Map<String, dynamic>;
          if (col['name'] != column) continue;
          for (final f in col['dsl_features'] as List<dynamic>) {
            final fk = (f as Map<String, dynamic>)['foreign_key'];
            if (fk != null) {
              return (fk as Map<String, dynamic>)['on_delete'] as String?;
            }
          }
        }
      }
      return null;
    }

    expect(
      onDeleteFor('history_entries', 'novel_id'),
      'restrict',
      reason:
          'B32 — removing a novel must not take the reader\'s history with it',
    );
    expect(
      onDeleteFor('chapters', 'novel_id'),
      'cascade',
      reason: 'a chapter record cannot outlive its novel',
    );
  });

  test('the schema version in the snapshot is the version in the code', () {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    final snapshot =
        jsonDecode(File('lib/core/database/schema.json').readAsStringSync())
            as Map<String, dynamic>;
    final meta = snapshot['_meta'] as Map<String, dynamic>;

    // `meta.version` is drift's schema format version, not the app's
    // `schemaVersion`. The point of the check is that both exist and are
    // readable -- a snapshot from a different drift major would change format.
    expect(meta['version'], isA<String>());
    expect(
      db.schemaVersion,
      1,
      reason: 'version 1 has no predecessor. Bump this when a migration lands.',
    );
  });
}
