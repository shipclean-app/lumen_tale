// forge:slice 6-6
// Lumen Tale — `6-6`: the two queries this slice writes, against a real SQLite.
//
// ## Why these rows are run against a DATABASE and not against a Dart list
//
// Four of § 10's criteria are claims about **SQLite**, not about Dart:
//
// - `title LIKE ? ESCAPE '\'` must fold case and treat `%` and `_` literally;
// - `idx_novels_title` must exist and `author` / `description` must have **no** index;
// - `COUNT(c.id)` under a `LEFT JOIN` must be `0` for a novel with no chapters, where
//   `COUNT(*)` is `1`;
// - **no** `unread_count` column may exist in the live schema.
//
// A mocked repository could answer all four while the SQL was wrong, and the SQL is where
// the plan's own drafts were wrong twice (see `library_queries.dart`'s header).
//
// ## ⚠️ `test()`, NEVER `testWidgets()`
//
// Every test here touches `package:sqlite3` through a real `NativeDatabase`. A
// `testWidgets` body runs inside a fake-async zone where real file and database futures
// never complete, so the row would hang and take the whole suite with it. This is a
// project-wide rule, not a preference for this file.

import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart'
    show
        ApplyInterceptor,
        InsertMode,
        QueryExecutor,
        QueryInterceptor,
        QueryRow,
        Value,
        Variable,
        driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumen_tale/core/database/app_database.dart';
import 'package:lumen_tale/data/library/drift_library_rows_repository.dart';
import 'package:lumen_tale/data/library/library_queries.dart';
import 'package:lumen_tale/domain/library/library_row.dart';
import 'package:lumen_tale/domain/library/library_search.dart';

/// The instant the fixtures write for anything they must date.
///
/// ⚠️ **`final`, and every fixture that wants it passes it explicitly.** Dart's
/// `DateTime.utc` is not a `const` constructor in this SDK, and a default parameter value
/// must be a compile-time constant — so a default of `kAt` is a compile error, not a
/// style question.
final DateTime kAt = DateTime.utc(2026, 10, 1, 9);

/// Counts the `SELECT` statements SQLite is actually asked to run.
///
/// ⚠️ **DRIFT'S OWN `QueryInterceptor`, AND NOT A COUNTER INSIDE THE REPOSITORY.** A spy
/// the production code increments would be asserting that the production code increments
/// the spy; this one sits below the repository, so the number is the database's.
final class _SelectCounter extends QueryInterceptor {
  final List<String> statements = <String>[];

  @override
  Future<List<Map<String, Object?>>> runSelect(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) {
    statements.add(statement);
    return executor.runSelect(statement, args);
  }
}

void main() {
  // ⚠️ **ONE WARNING DISABLED, AND IT IS A HARNESS FACT.** The row-counting test opens a
  // SECOND `AppDatabase` beside the fixture one, because drift's `QueryInterceptor` has to
  // wrap the executor *at construction*. drift warns about that; here the two databases
  // hold separate in-memory executors and share nothing, which is the case the FAQ's
  // advice does not describe.
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late AppDatabase db;
  late DriftLibraryRowsRepository repo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = DriftLibraryRowsRepository(
      db,
      // ⚠️ **A resolver, so the row's `sourceName` is a site name and not `unknown`.** The
      // badge, the pair and the site are the three things B40/E17 make visible, and a row
      // that said `unknown` for both sites would make E17 untestable.
      sourceNameOf: (String id) => switch (id) {
        'royal' => 'Royal Road',
        'fanmtl' => 'FanMTL',
        _ => 'unknown',
      },
    );
  });

  tearDown(() => db.close());

  Future<void> addSource(String id, {String? lastErrorCode}) => db
      .into(db.sources)
      .insert(
        SourcesCompanion.insert(id: id, lastErrorCode: Value(lastErrorCode)),
        mode: InsertMode.insertOrIgnore,
      );

  /// ⚠️ **[title] AND [addedAt] TAKE NO DEFAULT**, because a default parameter
  /// value must be a compile-time constant and neither `'Novel $id'` nor [kAt] is one. A
  /// helper that took them was a compile error twice before it was written this way.
  Future<void> addNovel(
    String id, {
    String sourceId = 'royal',
    String? title,
    String? author,
    String? description,
    bool inLibrary = true,
    DateTime? addedAt,
    DateTime? lastCheckedAt,
  }) async {
    await addSource(sourceId);
    await db
        .into(db.novels)
        .insert(
          NovelsCompanion.insert(
            id: id,
            sourceId: sourceId,
            url: '/fiction/$id',
            title: title ?? 'Novel $id',
            author: Value(author),
            description: Value(description),
            inLibrary: Value(inLibrary),
            addedAt: Value(addedAt ?? kAt),
            lastCheckedAt: Value(lastCheckedAt),
          ),
          mode: InsertMode.insertOrIgnore,
        );
  }

  /// ⚠️ **`insertOrIgnore`, so the helper is idempotent.** `addQueueItem` calls it for a
  /// chapter a test may already have seeded, and a plain insert dies on the second call
  /// with a UNIQUE constraint that says nothing about downloads.
  Future<void> addChapter(
    String novelId,
    int ordinal, {
    bool isRead = false,
    bool downloaded = false,
  }) async {
    await db
        .into(db.chapters)
        .insert(
          ChaptersCompanion.insert(
            id: '$novelId-c$ordinal',
            novelId: novelId,
            name: 'Chapter $ordinal',
            url: '/fiction/$novelId/chapter/$ordinal',
            ordinal: ordinal,
            isRead: Value(isRead),
            readAt: Value(isRead ? kAt : null),
            downloadedAt: Value(downloaded ? kAt : null),
          ),
          mode: InsertMode.insertOrIgnore,
        );
  }

  /// ⚠️ **THE CHAPTER IS CREATED IF IT IS ABSENT**, because `queue_items.chapter_id`
  /// cascades from `chapters` and SQLite's foreign keys are ON — a queue row for a chapter
  /// that does not exist is refused, and the refusal reads as a product defect.
  Future<void> addQueueItem(
    String novelId,
    int ordinal, {
    required DownloadState state,
    String errorCode = '',
  }) async {
    await addChapter(novelId, ordinal);
    await db
        .into(db.queueItems)
        .insert(
          QueueItemsCompanion.insert(
            id: 'q-$novelId-$ordinal',
            chapterId: '$novelId-c$ordinal',
            state: Value(state),
            queuePosition: ordinal,
            addedAt: kAt,
            errorCode: Value(errorCode),
          ),
        );
  }

  /// The ids one query returns, as a set so the assertions do not depend on the order.
  Future<Set<String>> idsMatching(String raw) async {
    final List<QueryRow> rows = await db
        .customSelect(
          titleSearchSql,
          variables: <Variable<Object>>[
            const Variable<bool>(true),
            Variable<String>(TitleSearch.of(raw).bindValue),
          ],
        )
        .get();
    return <String>{
      for (final QueryRow row in rows) row.read<String>('novel_id'),
    };
  }

  group('B45 — the query reads TITLE and nothing else', () {
    test('a query inside the title finds it — not only a prefix', () async {
      // ⚠️ **B45 says "by title", not "by the start of the title".** `ember` has to find
      // *The Vow of **Embers***; a prefix-only implementation would return nothing and the
      // row would pass on any fixture whose title happened to start with the query.
      await addNovel('n1', title: 'The Vow of Embers');

      expect(await idsMatching('vow'), <String>{'n1'});
      expect(await idsMatching('ember'), <String>{'n1'});
    });

    test('case is folded, so VOW finds the vow', () async {
      await addNovel('n1', title: 'The Vow of Embers');

      expect(
        await idsMatching('VOW'),
        <String>{'n1'},
        reason:
            'COLLATE NOCASE folds ASCII, and the Dart half folds it before binding',
      );
    });

    test('⚠️ a query present ONLY in the AUTHOR returns NOTHING', () async {
      // ⚠️ **B45 MADE EXECUTABLE.** This is the row that fails if somebody "improves" the
      // search by joining `author`, and ADR-024 makes the absence of an index on that
      // column half of the promise rather than an accident.
      await addNovel('n1', title: 'Ashes', author: 'Ilan W.');

      expect(
        await idsMatching('ilan'),
        isEmpty,
        reason:
            'B45: the library is searched by novel title only, never by author',
      );
    });

    test('⚠️ a query present ONLY in the DESCRIPTION returns NOTHING', () async {
      await addNovel(
        'n1',
        title: 'Ashes',
        description: 'A wandering ilan with a lantern.',
      );

      expect(
        await idsMatching('lantern'),
        isEmpty,
        reason:
            'B45 and ADR-024: description is displayed, never a searchable field',
      );
    });

    test('a `%` in the query is LITERAL, and does not match 1000', () async {
      // ⚠️ **THE SILENT-FAILURE ROW.** Without `ESCAPE` plus the three `replaceAll`s the
      // needle reads as a wildcard and `100 %` returns *Chapter 1000* as well — nothing
      // fails, the list is simply false.
      await addNovel('n1', title: 'Chapter 100 %');
      await addNovel('n2', title: 'Chapter 1000');

      expect(
        await idsMatching('100 %'),
        <String>{'n1'},
        reason:
            'the reader asked for a title containing "100 %", not one starting with 100',
      );
    });

    test('a `_` in the query is LITERAL, and does not match axb', () async {
      await addNovel('n1', title: 'a_b');
      await addNovel('n2', title: 'axb');

      expect(
        await idsMatching('a_b'),
        <String>{'n1'},
        reason:
            'SQL LIKE folds "_" to any single character, and ESCAPE is what stops it',
      );
    });

    test('a literal backslash is an anticharre, and does not THROW', () async {
      await addNovel('n1', title: 'Chapter 100 %');

      expect(
        await idsMatching(r'100\%'),
        isEmpty,
        reason:
            'the escaped needle must still be valid SQL; a double escape would make the '
            'anticharre part of the pattern and raise instead of matching nothing',
      );
    });

    test('two novels with the same title are TWO ids', () async {
      // ⚠️ **B2 / E17.** `novels.id` is derived from the source id, so the two rows are
      // structurally distinct — and the query must not deduplicate them.
      await addNovel('royal-1', title: 'The Ascension');
      await addNovel('fanmtl-1', sourceId: 'fanmtl', title: 'The Ascension');

      expect(
        await idsMatching('ascension'),
        hasLength(2),
        reason:
            'never deduplicated by title: two sites publishing a title are two books',
      );
    });

    test('a novel that is not in the library is not a result', () async {
      await addNovel('n1', title: 'The Vow of Embers');
      await addNovel('n2', title: 'The Vow of Embers', inLibrary: false);

      expect(await idsMatching('vow'), <String>{'n1'});
    });

    test(
      'a one-character query matches everything it should — no minimum length',
      () async {
        // ⚠️ **§ 3.1 branch 10.** A "minimum three characters" rule nobody authorised hides
        // results, and the list counter is the honest way to say "this is a wide list".
        await addNovel('n1', title: 'The Vow of Embers');
        await addNovel('n2', title: 'Ashes');

        expect(await idsMatching('e'), <String>{'n1', 'n2'});
      },
    );
  });

  group('B45 — the INDEX is half the promise', () {
    test(
      'idx_novels_title exists and nothing indexes author or description',
      () async {
        final List<QueryRow> rows = await db
            .customSelect(
              "SELECT name, tbl_name FROM sqlite_master WHERE type = 'index'",
            )
            .get();
        final List<String> names = <String>[
          for (final QueryRow row in rows) row.read<String>('name'),
        ];

        expect(
          names,
          contains('idx_novels_title'),
          reason:
              'B45 searches the title, and the index is what makes it cheap',
        );
        expect(
          names.where(
            (String n) =>
                n.contains('author') ||
                n.contains('description') ||
                n.contains('genre'),
          ),
          isEmpty,
          reason:
              'an index on author or description would be the other half of a capability the '
              'app does not have (ADR-024, B45)',
        );
      },
    );
  });

  group('B14 — the badge is an aggregate, and it is exact', () {
    test('3 unopened, open one, and the badge falls to exactly 2', () async {
      await addNovel('n1');
      await addChapter('n1', 1);
      await addChapter('n1', 2);
      await addChapter('n1', 3);

      expect((await repo.watchRows().first).single.unopenedCount, 3);

      // ⚠️ **A `WHERE`, AND NOT A BARE `write()`.** `db.update(db.chapters).write(…)` with no
      // predicate writes EVERY chapter, so the first version of this row opened all three
      // at once and the badge fell to 0 — a failure that looked exactly like the bug it
      // was meant to catch.
      await (db.update(
        db.chapters,
      )..where((Chapters t) => t.id.equals('n1-c1'))).write(
        ChaptersCompanion(isRead: const Value(true), readAt: Value(kAt)),
      );
      expect(
        (await repo.watchRows().first).single.unopenedCount,
        2,
        reason:
            'B13: opening a chapter clears its marker, and B14: the badge follows by one',
      );
    });

    test(
      '⚠️ a novel with NO chapters counts 0, and `COUNT(*)` would have said 1',
      () async {
        await addNovel('n1');

        final LibraryRow row = (await repo.watchRows().first).single;
        expect(
          row.unopenedCount,
          0,
          reason:
              'COUNT(c.id) under a LEFT JOIN is 0; COUNT(*) is 1, which would put "1 '
              'unopened" on a novel with nothing in it',
        );
        expect(row.chapterCount, 0);
        expect(row.downloadedPair, '0 / 0');
      },
    );

    test('no `unread_count` column exists, in the LIVE schema or in the snapshot', () async {
      // ⚠️ **B14 / B48 — "a stored count is a second source of truth free to disagree with
      // the rows it counts".** The live schema is the one that matters; the snapshot is
      // compared with it so the two cannot drift apart behind a green test.
      final List<QueryRow> rows = await db
          .customSelect("SELECT name FROM pragma_table_info('novels')")
          .get();
      final List<String> columns = <String>[
        for (final QueryRow row in rows) row.read<String>('name'),
      ];

      expect(
        columns.where((String c) => c.toLowerCase().contains('unread')),
        isEmpty,
        reason: 'B14: the count is derived in SQL, never stored',
      );
      expect(
        columns.where((String c) => c.toLowerCase().contains('unopened')),
        isEmpty,
      );

      final Map<String, dynamic> snapshot =
          jsonDecode(File('lib/core/database/schema.json').readAsStringSync())
              as Map<String, dynamic>;
      final List<Map<String, dynamic>> entities =
          (snapshot['entities']! as List<dynamic>).cast<Map<String, dynamic>>();
      // ⚠️ **THE NESTING IS TYPED AT EVERY LEVEL.** `jsonDecode` returns `dynamic`,
      // and reading `['data']['columns']` off a `dynamic` is an `avoid_dynamic_calls` info
      // — which AGENTS.md's item 2 counts as a failure. `schema.json` is a map of maps of
      // lists of maps, so the casts are written out rather than left to inference.
      final Map<String, dynamic> novels = entities.firstWhere(
        (Map<String, dynamic> e) =>
            (e['data']! as Map<String, dynamic>)['name'] == 'novels',
      );
      final Map<String, dynamic> novelsData =
          novels['data']! as Map<String, dynamic>;
      final List<String> snapshotColumns = <String>[
        for (final Map<String, dynamic> column
            in (novelsData['columns']! as List<dynamic>)
                .cast<Map<String, dynamic>>())
          column['name']! as String,
      ];

      expect(
        snapshotColumns,
        orderedEquals(columns),
        reason:
            'the committed snapshot and the live schema must agree, or the test above is '
            'proving something about a schema nobody ships',
      );
    });

    test('the whole library is read by ONE select, not three per novel', () async {
      // ⚠️ **`06-database.md` rule 8, and B9's 10 000 chapters per novel.** The shape this
      // replaces ran a `SELECT COUNT(*)` per novel per counter — 600 queries for a 200
      // novel library, each one a separate scan. The count is taken through drift's
      // `QueryInterceptor`, so it is the number of statements SQLite was actually asked
      // to run, not a comment about them.
      final _SelectCounter counter = _SelectCounter();
      final AppDatabase counted = AppDatabase.forTesting(
        NativeDatabase.memory().interceptWith(counter),
      );
      addTearDown(counted.close);

      Future<void> seed(AppDatabase target) async {
        await target
            .into(target.sources)
            .insert(
              SourcesCompanion.insert(id: 'royal'),
              mode: InsertMode.insertOrIgnore,
            );
        for (final (String id, int chapters) in <(String, int)>[
          ('n1', 30),
          ('n2', 12),
          ('n3', 5),
        ]) {
          await target
              .into(target.novels)
              .insert(
                NovelsCompanion.insert(
                  id: id,
                  sourceId: 'royal',
                  url: '/fiction/$id',
                  title: 'Novel $id',
                  inLibrary: const Value(true),
                  addedAt: Value(kAt),
                ),
                mode: InsertMode.insertOrIgnore,
              );
          for (int i = 1; i <= chapters; i++) {
            await target
                .into(target.chapters)
                .insert(
                  ChaptersCompanion.insert(
                    id: '$id-c$i',
                    novelId: id,
                    name: 'Chapter $i',
                    url: '/fiction/$id/chapter/$i',
                    ordinal: i,
                  ),
                );
          }
        }
      }

      await seed(counted);
      counter.statements.clear();

      final List<LibraryRow> rows = await DriftLibraryRowsRepository(
        counted,
        sourceNameOf: (String _) => 'Royal Road',
      ).watchRows().first;

      expect(rows, hasLength(3), reason: 'three kept novels, three rows');
      expect(
        counter.statements.where((String sql) => sql.contains('FROM novels n')),
        hasLength(1),
        reason:
            'one aggregate for the whole library; a per-novel count would have produced '
            'one statement per novel and the cost would grow with the library',
      );
    });

    test('⚠️ a check FAILURE changes no unopenedCount (B22 + B48)', () async {
      await addNovel('n1');
      await addChapter('n1', 1);
      await addChapter('n1', 2);

      expect((await repo.watchRows().first).single.unopenedCount, 2);

      // ⚠️ **EXACTLY WHAT `6-4` WRITES**: `sources.last_error_code`, and no
      // `novels.last_checked_at`. A broken site is a *verification*, never a number.
      await db
          .update(db.sources)
          .write(
            const SourcesCompanion(
              lastErrorCode: Value('source_layout_changed'),
            ),
          );

      final LibraryRow row = (await repo.watchRows().first).single;
      expect(
        row.unopenedCount,
        2,
        reason: 'B48: the count is a local fact and depends on no check',
      );
      expect(row.lastCheckError, 'source_layout_changed');
      expect(
        row.lastCheckedAt,
        isNull,
        reason: 'B49: a failure is not a check, so "never checked" stays true',
      );
    });
  });

  group('B14 / B49 — the row carries the verification beside the count', () {
    test(
      'last_checked_at is read and null renders Never checked at the UI',
      () async {
        await addNovel('n1');
        await addNovel('n2', lastCheckedAt: kAt);

        final Map<String, LibraryRow> rows = <String, LibraryRow>{
          for (final LibraryRow row in await repo.watchRows().first)
            row.novelId: row,
        };
        expect(rows['n1']!.lastCheckedAt, isNull);
        expect(rows['n2']!.lastCheckedAt!.toUtc(), kAt);
      },
    );
  });

  group(
    'E6 / E7 — the download presentation comes from the queue, not from the files',
    () {
      test('a stopped queue at 12 of 480 is `stopped`, never `running`', () async {
        await addNovel('n1');
        // ⚠️ **ALL 480 CHAPTER ROWS ARE CREATED**, not just the 12 downloaded ones. The
        // denominator is `COUNT(chapters.id)` — the site's own list — so a fixture with
        // 13 rows would render "12 / 13" and the row about "12 of 480" would be testing
        // something else.
        for (int i = 1; i <= 480; i++) {
          await addChapter('n1', i, downloaded: i <= 12);
        }
        await addQueueItem('n1', 13, state: DownloadState.failed);

        final LibraryRow row = (await repo.watchRows().first).single;
        expect(row.download, DownloadPresentation.stopped);
        expect(row.downloadedPair, '12 / 480');
        expect(
          row.downloadedCount,
          12,
          reason:
              'B6/ADR-022: the count is COUNT(downloaded_at IS NOT NULL), not a file probe',
        );
      });

      test(
        'a queue that lost its connection says `stoppedByConnectionLost`',
        () async {
          await addNovel('n1');
          await addChapter('n1', 1, downloaded: true);
          await addQueueItem(
            'n1',
            2,
            state: DownloadState.failed,
            errorCode: 'no_connection',
          );

          final LibraryRow row = (await repo.watchRows().first).single;
          expect(row.download, DownloadPresentation.stoppedByConnectionLost);
          expect(
            row.downloadedCount,
            1,
            reason:
                'E7: the chapters already finished stay counted and stay readable',
          );
        },
      );

      test(
        'a running queue is `running` even beside an earlier failure',
        () async {
          await addNovel('n1');
          await addChapter('n1', 1, downloaded: true);
          await addChapter('n1', 2);
          await addQueueItem('n1', 1, state: DownloadState.failed);
          await addQueueItem('n1', 2, state: DownloadState.downloading);

          expect(
            (await repo.watchRows().first).single.download,
            DownloadPresentation.running,
          );
        },
      );

      test(
        'everything on the phone is `complete`, and no queue means `none`',
        () async {
          await addNovel('n1');
          await addChapter('n1', 1, downloaded: true);
          expect(
            (await repo.watchRows().first).single.download,
            DownloadPresentation.complete,
          );

          await addNovel('n2');
          await addChapter('n2', 1);
          expect(
            (await repo.watchRows().first).last.download,
            DownloadPresentation.none,
          );
        },
      );
    },
  );

  group('the sort key the sheet offers — *Last read* — is the READING POSITION', () {
    test(
      'last_read_at comes from reading_positions, never from the journal',
      () async {
        await addNovel('n1');
        await addChapter('n1', 1);
        await db
            .into(db.readingPositions)
            .insert(
              ReadingPositionsCompanion.insert(
                chapterId: 'n1-c1',
                updatedAt: kAt,
              ),
            );

        final LibraryRow row = (await repo.watchRows().first).single;
        // ⚠️ **`.toUtc()` ON BOTH SIDES.** drift stores a `DateTime` as a unix second
        // count and reads it back in the *local* zone, so `DateTime.utc(2026-10-01 09:00)`
        // comes back as the same instant in whatever zone the machine is set to — equal as
        // an instant, unequal as a `DateTime`.
        expect(row.lastReadAt!.toUtc(), kAt);
      },
    );

    test(
      'a novel never read reports null, so it sorts LAST and not first',
      () async {
        await addNovel('n1');

        expect((await repo.watchRows().first).single.lastReadAt, isNull);
      },
    );
  });

  group('the repository refuses to answer a search it should not be asked', () {
    test(
      'an empty query throws rather than returning the whole library again',
      () async {
        // ⚠️ **§ 3.1 branch 1 IS THE CALLER'S BRANCH.** A `LIKE '%%'` here would make "no
        // query" have two answers, and the one that is wrong is the one nothing tests.
        expect(
          () => repo.watchMatchingNovelIds(TitleSearch.of('')).first,
          throwsStateError,
        );
        expect(
          () => repo.watchMatchingNovelIds(TitleSearch.of('   ')).first,
          throwsStateError,
        );
      },
    );
  });
}
