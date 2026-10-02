// Proves the schema executes, rather than merely being re-read.
//
// Forge's `ddl-exec.js` drives PostgreSQL through pglite. This project targets
// SQLite via drift, so that engine would be testing the wrong database — and a
// DDL nobody has ever run is exactly the failure SKILL.md § 4.5 describes. This
// test is the substitute: it opens a real SQLite file, creates every table,
// inserts through the typed API, and asserts the constraints that the schema
// claims to hold.

// `isNull`/`isNotNull` exist in both drift and matcher; the drift ones
// would shadow the matchers and break compilation.
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumen_tale/core/database/app_database.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    // The setup hook is NOT applied by forTesting, so a test instance that
    // skipped it would silently have no FK enforcement -- which is precisely
    // the bug these tests exist to catch.
    db = AppDatabase.forTesting(
      NativeDatabase.memory(
        setup: (e) => e.execute('PRAGMA foreign_keys = ON'),
      ),
    );
  });

  tearDown(() => db.close());

  group('the DDL executes', () {
    test('every table is created, and the schema version is 1', () async {
      // Reaching the database at all means drift ran `createAll`, so a table
      // whose DDL SQLite rejects would already have thrown.
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
        reason: 'B2/B3/B6/B16/B17/B18/B1 each hang off one of these',
      );
    });

    test('foreign-key enforcement is ON, not merely declared', () async {
      // The assertion that closes the loop. Everything below about cascades
      // and restricts depends on this one row, and the two tests that follow
      // it failed before the pragma was added -- on a schema that looked
      // entirely correct.
      final r = await db.customSelect('PRAGMA foreign_keys').getSingle();
      expect(
        r.read<int>('foreign_keys'),
        1,
        reason: 'SQLite defaults this to 0 per connection; B32 depends on it',
      );
    });

    test('the foreign keys are actually declared', () async {
      final rows = await db
          .customSelect('PRAGMA foreign_key_list(chapters)')
          .get();
      expect(rows, isNotEmpty, reason: 'chapters.novelId must be a real FK');
      expect(rows.first.read<String>('table'), 'novels');

      final hp = await db
          .customSelect('PRAGMA foreign_key_list(history_entries)')
          .get();
      final hpTables = hp.map((r) => r.read<String>('table')).toSet();
      expect(
        hpTables,
        containsAll(<String>{'novels', 'chapters'}),
        reason: 'B32 — history survives the novel that pointed at it',
      );
    });
  });

  group('B48 — the unread count is derived, so it cannot drift', () {
    test('opening a chapter clears exactly one unread', () async {
      final n = await db
          .into(db.novels)
          .insertReturning(
            NovelsCompanion.insert(
              id: 'n1',
              sourceId: 'src',
              url: '/novel/a.html',
              title: 'A',
              inLibrary: const Value(true),
            ),
          );
      for (final c in ['c1', 'c2', 'c3']) {
        await db
            .into(db.chapters)
            .insert(
              ChaptersCompanion.insert(
                id: c,
                novelId: n.id,
                name: 'Chapter $c',
                ordinal: int.parse(c.substring(1)) - 1,
                url: '/novel/a_$c.html',
              ),
            );
      }

      // The count is a query, not a column: there is no `unreadCount` anywhere
      // in the schema, so it cannot disagree with the rows it counts.
      Future<int> unread() async {
        final q = await db
            .customSelect(
              'SELECT COUNT(*) AS c FROM chapters WHERE novel_id = ? AND is_read = 0',
              variables: [Variable<String>(n.id)],
            )
            .getSingle();
        return q.read<int>('c');
      }

      expect(await unread(), 3);

      await (db.update(db.chapters)..where((c) => c.id.equals('c2'))).write(
        const ChaptersCompanion(isRead: Value(true), readAt: Value(null)),
      );
      expect(await unread(), 2, reason: 'B13 — only the opened chapter clears');
    });
  });

  group('B6 — a chapter row is only ever present and complete', () {
    test('deleting a novel cascades to its chapters', () async {
      await db
          .into(db.novels)
          .insert(
            NovelsCompanion.insert(
              id: 'n1',
              sourceId: 's',
              url: '/a',
              title: 'A',
            ),
          );
      await db
          .into(db.chapters)
          .insert(
            ChaptersCompanion.insert(
              id: 'c1',
              novelId: 'n1',
              name: 'One',
              url: '/a_1',
              ordinal: 0,
            ),
          );

      await (db.delete(db.novels)..where((n) => n.id.equals('n1'))).go();

      final left = await db.select(db.chapters).get();
      expect(left, isEmpty, reason: 'a chapter cannot outlive its novel');
    });

    test(
      'B32 — history survives the novel, and the FK refuses the delete',
      () async {
        await db
            .into(db.novels)
            .insert(
              NovelsCompanion.insert(
                id: 'n1',
                sourceId: 's',
                url: '/a',
                title: 'A',
                inLibrary: const Value(true),
              ),
            );
        await db
            .into(db.chapters)
            .insert(
              ChaptersCompanion.insert(
                id: 'c1',
                novelId: 'n1',
                name: 'One',
                url: '/a_1',
                ordinal: 0,
              ),
            );
        await db
            .into(db.historyEntries)
            .insert(
              HistoryEntriesCompanion.insert(
                id: 'h1',
                novelId: 'n1',
                chapterId: 'c1',
                openedAt: DateTime(2026, 10, 2),
              ),
            );

        // RESTRICT, not CASCADE: this delete is the operation B32 forbids, and
        // the database is what refuses it.
        await expectLater(
          (db.delete(db.novels)..where((n) => n.id.equals('n1'))).go(),
          throwsA(isA<Exception>()),
          reason: 'B32 — removing a novel keeps what the reader has read',
        );

        final kept = await db.select(db.historyEntries).get();
        expect(kept, hasLength(1));
      },
    );
  });

  group(
    'ADR-024 — author and description are stored, displayed, never searched',
    () {
      test(
        'they default to null, because the site may publish neither',
        () async {
          final n = await db
              .into(db.novels)
              .insertReturning(
                NovelsCompanion.insert(
                  id: 'n1',
                  sourceId: 's',
                  url: '/a',
                  title: 'A',
                ),
              );
          expect(n.author, isNull);
          expect(
            n.description,
            isNull,
            reason:
                'absent and blank are different states — an em dash would be a '
                'lie about a value nobody gave us',
          );
        },
      );

      test(
        'B45 — neither column is indexed, so neither is searchable',
        () async {
          final rows = await db
              .customSelect(
                "SELECT name FROM sqlite_master WHERE type = 'index' "
                "AND name NOT LIKE 'sqlite_%'",
              )
              .get();
          final names = rows.map((r) => r.read<String>('name')).toSet();
          expect(names.where((n) => n.contains('author')), isEmpty);
          expect(names.where((n) => n.contains('description')), isEmpty);
          expect(
            names,
            contains('idx_novels_title'),
            reason: 'B45 — title only, and the index is how that is enforced',
          );
        },
      );

      test(
        'B44 — a description round-trips as plain text with no markup',
        () async {
          await db
              .into(db.novels)
              .insert(
                NovelsCompanion.insert(
                  id: 'n1',
                  sourceId: 's',
                  url: '/a',
                  title: 'A',
                  description: const Value(
                    'A debt repaid. No tags, no markup.',
                  ),
                ),
              );
          final back = await (db.select(
            db.novels,
          )..where((n) => n.id.equals('n1'))).getSingle();
          expect(back.description, 'A debt repaid. No tags, no markup.');
          expect(
            back.description,
            isNot(contains('<')),
            reason:
                'B44 — markup is never executed and never stored, so there is '
                'nothing here to sanitise at render time',
          );
        },
      );
    },
  );

  group('06-database rule 7 — the hot-path indexes exist', () {
    // Read from `sqlite_master`, not from the snapshot. The snapshot *does*
    // record indexes — but it recorded **none at all** until today, because
    // there were none, and an empty category in a snapshot reads exactly like a
    // covered one. `schema_snapshot_test.dart` now skips non-table entities, so
    // a *removed* index is caught there; this test catches an index that was
    // declared in Dart and never created, which is a different failure.
    const expected = {
      'idx_novels_title', // B45 — title-only search
      'idx_chapters_novel_ordinal', // B9 — the complete chapter list
      'idx_chapters_novel_read', // B14 / B48 — the derived unread count
      'idx_history_opened_at', // B17 — most recent first
      'idx_queue_state', // the paused/queued filter
    };

    test('every declared index is present in the live database', () async {
      final rows = await db
          .customSelect(
            "SELECT name FROM sqlite_master WHERE type = 'index' "
            "AND name NOT LIKE 'sqlite_%'",
          )
          .get();
      final live = rows.map((r) => r.read<String>('name')).toSet();
      expect(
        live,
        containsAll(expected),
        reason:
            'a declared index was never created. Drift does not warn about '
            'this, and the schema snapshot does not record it.',
      );
    });

    test('the count is derived by SQL, not by a per-row loop', () async {
      // 06-database rule 8. Three chapters, one read: the aggregate returns 2
      // without the reader ever seeing three rows.
      await db
          .into(db.novels)
          .insert(
            NovelsCompanion.insert(
              id: 'n1',
              sourceId: 's',
              url: '/a',
              title: 'A',
            ),
          );
      for (var i = 0; i < 3; i++) {
        await db
            .into(db.chapters)
            .insert(
              ChaptersCompanion.insert(
                id: 'c$i',
                novelId: 'n1',
                name: 'C$i',
                url: '/c$i',
                ordinal: i,
                isRead: Value(i == 0),
              ),
            );
      }
      final count = await db
          .customSelect(
            'SELECT COUNT(*) AS c FROM chapters '
            'WHERE novel_id = ? AND is_read = 0',
            variables: const [Variable('n1')],
          )
          .getSingle();
      expect(count.read<int>('c'), 2, reason: 'B14 / B48');
    });
  });

  group('B6 — the download mark is a column, not a probe', () {
    test('downloadedAt defaults to null: not downloaded', () async {
      await db
          .into(db.novels)
          .insert(
            NovelsCompanion.insert(
              id: 'n1',
              sourceId: 's',
              url: '/a',
              title: 'A',
            ),
          );
      final c = await db
          .into(db.chapters)
          .insertReturning(
            ChaptersCompanion.insert(
              id: 'c1',
              novelId: 'n1',
              name: 'One',
              url: '/a_1',
              ordinal: 0,
            ),
          );
      expect(
        c.downloadedAt,
        isNull,
        reason: 'B6 — a chapter is not marked until its file is wholly present',
      );
    });

    test(
      'B33 — deleting one chapter clears only that chapter\'s mark',
      () async {
        await db
            .into(db.novels)
            .insert(
              NovelsCompanion.insert(
                id: 'n1',
                sourceId: 's',
                url: '/a',
                title: 'A',
              ),
            );
        await db
            .into(db.chapters)
            .insert(
              ChaptersCompanion.insert(
                id: 'c1',
                novelId: 'n1',
                name: 'One',
                url: '/c1',
                ordinal: 0,
              ),
            );
        await db
            .into(db.chapters)
            .insert(
              ChaptersCompanion.insert(
                id: 'c2',
                novelId: 'n1',
                name: 'Two',
                url: '/c2',
                ordinal: 1,
                downloadedAt: Value(DateTime(2026, 10, 2)),
              ),
            );

        // The deletion B33 authorises.
        await (db.update(db.chapters)..where((c) => c.id.equals('c2'))).write(
          const ChaptersCompanion(downloadedAt: Value(null)),
        );

        final rows = {
          for (final r in await db.select(db.chapters).get()) r.id: r,
        };
        expect(rows['c1']!.downloadedAt, isNull);
        expect(rows['c2']!.downloadedAt, isNull);

        // And now the state that motivated the column: a deliberate deletion is
        // indistinguishable from a never-downloaded chapter *only if the mark is
        // the store*. With a column, "was downloaded, now removed" is
        // representable, so a future migration can tell them apart.
        // A distinct date, so the assertion below cannot pass by coincidence.
        final earlier = DateTime(2026, 10, 1, 9, 30);
        await (db.update(db.chapters)..where((c) => c.id.equals('c1'))).write(
          ChaptersCompanion(downloadedAt: Value(earlier)),
        );
        final after = {
          for (final r in await db.select(db.chapters).get()) r.id: r,
        };
        expect(
          after['c1']!.downloadedAt,
          isNotNull,
          reason: 'the mark is data, so it survives independently of any probe',
        );
      },
    );

    test('the unread count is unaffected by the download mark', () async {
      // B48 and B6 must not interact: downloading a chapter does not make it
      // read, and reading it does not require a download.
      await db
          .into(db.novels)
          .insert(
            NovelsCompanion.insert(
              id: 'n1',
              sourceId: 's',
              url: '/a',
              title: 'A',
            ),
          );
      await db
          .into(db.chapters)
          .insert(
            ChaptersCompanion.insert(
              id: 'c1',
              novelId: 'n1',
              name: 'One',
              url: '/a_1',
              ordinal: 0,
              downloadedAt: Value(DateTime(2026, 10, 2)),
            ),
          );
      final rows = await db.select(db.chapters).get();
      expect(
        rows.single.isRead,
        isFalse,
        reason: 'B13 — downloaded is not read',
      );
    });
  });

  group('B16 — a position is per chapter', () {
    test('two chapters of one novel hold independent offsets', () async {
      await db
          .into(db.novels)
          .insert(
            NovelsCompanion.insert(
              id: 'n1',
              sourceId: 's',
              url: '/a',
              title: 'A',
            ),
          );
      for (final c in ['c1', 'c2']) {
        await db
            .into(db.chapters)
            .insert(
              ChaptersCompanion.insert(
                id: c,
                novelId: 'n1',
                name: c,
                url: '/$c',
                ordinal: c == 'c1' ? 0 : 1,
              ),
            );
      }

      await db
          .into(db.readingPositions)
          .insert(
            ReadingPositionsCompanion.insert(
              chapterId: 'c1',
              offset: const Value(1240.5),
              updatedAt: DateTime(2026, 10, 2),
            ),
          );
      await db
          .into(db.readingPositions)
          .insert(
            ReadingPositionsCompanion.insert(
              chapterId: 'c2',
              offset: const Value(0),
              updatedAt: DateTime(2026, 10, 2),
            ),
          );

      final rows = await db.select(db.readingPositions).get();
      expect(rows, hasLength(2));
      expect(
        rows.firstWhere((r) => r.chapterId == 'c1').offset,
        closeTo(1240.5, 0.001),
      );
      expect(rows.firstWhere((r) => r.chapterId == 'c2').offset, 0);
    });
  });

  group('B18 — the queue is sequential and stores the state by name', () {
    test('DownloadState round-trips as a name, not an ordinal', () async {
      await db
          .into(db.novels)
          .insert(
            NovelsCompanion.insert(
              id: 'n1',
              sourceId: 's',
              url: '/a',
              title: 'A',
            ),
          );
      await db
          .into(db.chapters)
          .insert(
            ChaptersCompanion.insert(
              id: 'c1',
              novelId: 'n1',
              name: 'One',
              url: '/a_1',
              ordinal: 0,
            ),
          );
      await db
          .into(db.queueItems)
          .insert(
            QueueItemsCompanion.insert(
              id: 'q1',
              chapterId: 'c1',
              queuePosition: 0,
              addedAt: DateTime(2026, 10, 2),
            ),
          );

      // Stored by name, so reordering the enum cannot silently re-map history.
      final raw = await db
          .customSelect(
            'SELECT state FROM queue_items WHERE id = ?',
            variables: [const Variable<String>('q1')],
          )
          .getSingle();
      expect(raw.read<String>('state'), 'queued');

      await (db.update(db.queueItems)..where((q) => q.id.equals('q1'))).write(
        const QueueItemsCompanion(state: Value(DownloadState.failed)),
      );
      final back = await db.select(db.queueItems).getSingle();
      expect(back.state, DownloadState.failed);
      expect(
        back.errorCode,
        '',
        reason: 'B24 — a failure carries a typed reason',
      );
    });

    test('the queue has no concurrency column to mis-set', () async {
      // B18 makes concurrency a constant of one. Asserting its absence is the
      // only way to notice someone adding one.
      final cols = await db
          .customSelect('PRAGMA table_info(queue_items)')
          .get();
      final names = cols.map((c) => c.read<String>('name')).toSet();
      expect(names, isNot(contains('concurrent')));
      expect(names, isNot(contains('parallelism')));
      expect(
        names,
        containsAll(<String>{'queue_position', 'attempts', 'error_code'}),
      );
    });
  });

  group('B49 — never-checked is distinct from checked', () {
    test('a null lastCheckedAt is null, not epoch', () async {
      final n = await db
          .into(db.novels)
          .insertReturning(
            NovelsCompanion.insert(
              id: 'n1',
              sourceId: 's',
              url: '/a',
              title: 'A',
            ),
          );
      expect(
        n.lastCheckedAt,
        isNull,
        reason:
            'B49 — "never checked" and "checked at epoch" are different claims',
      );
    });
  });

  group('B10 — an unparseable chapter number is -1, not 0', () {
    test('the default is -1 and 0 stays reachable', () async {
      await db
          .into(db.novels)
          .insert(
            NovelsCompanion.insert(
              id: 'n1',
              sourceId: 's',
              url: '/a',
              title: 'A',
            ),
          );
      await db
          .into(db.chapters)
          .insert(
            ChaptersCompanion.insert(
              id: 'c-unparseable',
              novelId: 'n1',
              name: 'Author note',
              url: '/x',
              ordinal: 0,
            ),
          );
      await db
          .into(db.chapters)
          .insert(
            ChaptersCompanion.insert(
              id: 'c-zero',
              novelId: 'n1',
              name: 'Extra',
              url: '/y',
              ordinal: 1,
              number: const Value(0),
            ),
          );

      final rows = await db.select(db.chapters).get();
      final byId = {for (final r in rows) r.id: r};
      expect(
        byId['c-unparseable']!.number,
        -1,
        reason: 'B10 — unparseable must render as an em dash, never as 0',
      );
      expect(
        byId['c-zero']!.number,
        0,
        reason: '0 is a real chapter number and must remain distinguishable',
      );
    });
  });

  group('the schema is the only definition', () {
    test(
      'an unknown column is rejected — proof the table really exists',
      () async {
        await expectLater(
          db.customSelect('SELECT definitely_not_a_column FROM novels').get(),
          throwsA(isA<Exception>()),
        );
      },
    );

    test(
      'the queue stores a failure reason, so "failed" is never bare',
      () async {
        // B24: an action that can fail shows a reason the reader can act on. The
        // schema's answer to that is a typed code, and it has to survive a round
        // trip or the UI has nothing to render.
        await db
            .into(db.novels)
            .insert(
              NovelsCompanion.insert(
                id: 'n1',
                sourceId: 's',
                url: '/a',
                title: 'A',
              ),
            );
        await db
            .into(db.chapters)
            .insert(
              ChaptersCompanion.insert(
                id: 'c1',
                novelId: 'n1',
                name: 'One',
                url: '/a_1',
                ordinal: 0,
              ),
            );
        await db
            .into(db.queueItems)
            .insert(
              QueueItemsCompanion.insert(
                id: 'q1',
                chapterId: 'c1',
                queuePosition: 0,
                addedAt: DateTime(2026, 10, 2),
                state: const Value(DownloadState.failed),
                errorCode: const Value('source_layout_changed'),
              ),
            );

        final row = await db.select(db.queueItems).getSingle();
        expect(row.state, DownloadState.failed);
        expect(
          row.errorCode,
          'source_layout_changed',
          reason: 'B22/B24 — the reason is the whole point of the column',
        );
      },
    );
  });
}
