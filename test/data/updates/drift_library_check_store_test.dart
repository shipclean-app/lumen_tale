// forge:slice 6-4
// Lumen Tale — `6-4`'s three drift writes, on a real in-memory database.
//
// ## Why this file needs a real database and not the recording store
//
// `RecordingCheckStore` (in `check_fakes.dart`) answers *which* method the loop called.
// It cannot answer **what the SQL did**, and B49's two halves live entirely in the SQL: one
// statement writes `novels.last_checked_at` and clears `sources.last_error_code` **for that
// novel's source only**, and the other writes the typed code **without touching the
// timestamp**. A fake would let both halves be asserted while the statement was wrong.
//
// The three claims, and the SQL mistake each would hide:
//
// | rule | the statement | what a fake could not see |
// |---|---|---|
// | **B49** | `recordChecked` stamps the novel AND clears **its own** source's code | a global `UPDATE sources` — which would silently repair a broken site because another site succeeded (B23 inverted) |
// | **B24 / B22** | `recordCheckFailure` writes `kind.name` and **nothing else** | an `insertOnConflictUpdate` that also flips `enabled` back on (B41) |
// | **B48 / B3** | `mergeChapterList` is `INSERT OR IGNORE`, returning rows **added** | a delete-then-insert — which resets `is_read` and `downloaded_at` on every chapter the reader had already opened |

import 'package:drift/drift.dart'
    show InsertMode, OrderingTerm, QueryRow, TableInfo, Value, Variable;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumen_tale/core/database/app_database.dart';
import 'package:lumen_tale/data/updates/drift_library_check_store.dart';
import 'package:lumen_tale/domain/library/library_repository.dart';
import 'package:lumen_tale/domain/updates/library_check.dart';

/// A fresh in-memory database and its store — **and no rows at all**.
///
/// ⚠️ **NO `sources` ROW IS SEEDED.** `sources` is populated the first time something has
/// something to say about a source, so a fresh install has none — and `isSourceEnabled` is
/// required to read an absent row as *enabled* precisely so that a first check can succeed.
/// A harness that pre-inserted one would make every row here pass against a state the app
/// never starts in.
///
/// ⚠️ **`NativeDatabase.memory()`, so nothing a row writes survives it** — and
/// `AppDatabase.forTesting` turns the foreign keys on, which matters because
/// `chapters.novel_id` references `novels.id`: without it a chapter could be inserted for a
/// novel that does not exist, and several rows below would pass against rows that cannot
/// exist in the app.
Future<(AppDatabase, DriftLibraryCheckStore)> harness() async {
  final AppDatabase db = AppDatabase.forTesting(NativeDatabase.memory());
  return (db, DriftLibraryCheckStore(db));
}

/// The instant every stamp uses.
///
/// ⚠️ **`toUtc()` ON THE WAY BACK, EVERYWHERE.** drift stores a `DateTime` as a unix
/// count and rebuilds it in **local** time, so `expect(row.lastCheckedAt, kAt)` compares a
/// UTC instant with a local one and fails on the `Z` — which says nothing about the write.
/// The comparison that means something is [DateTime.toUtc], and every row below spells it.
final DateTime kAt = DateTime.utc(2026, 10, 4, 9, 30);

/// One `sources` row, which [harness] deliberately does not seed.
///
/// ⚠️ **`insertOrIgnore`, because a row inserted twice dies on a UNIQUE constraint that says
/// nothing about what is being tested.
Future<void> addSource(
  AppDatabase db,
  String id, {
  bool enabled = true,
  String settings = '{}',
  String lastErrorCode = '',
}) => db
    .into(db.sources)
    .insert(
      SourcesCompanion.insert(
        id: id,
        enabled: Value(enabled),
        settings: Value(settings),
        lastErrorCode: Value(lastErrorCode),
      ),
      mode: InsertMode.insertOrIgnore,
    );

NovelsCompanion novelRow(
  String id, {
  String sourceId = 'src-a',
  bool inLibrary = true,
  DateTime? lastCheckedAt,
}) => NovelsCompanion.insert(
  id: id,
  sourceId: sourceId,
  url: '/fiction/$id',
  title: 'Novel $id',
  inLibrary: Value(inLibrary),
  lastCheckedAt: Value(lastCheckedAt),
);

/// A chapter id exactly as the interactor derives it, so B3's claim is tested against the
/// same derivation and not against a hand-written string.
String chapterId(String novelId, String url) =>
    '${novelId}_$url'.hashCode.toString();

/// ⚠️ **`ordinal` IS REQUIRED, WITH NO DEFAULT.** B9 is *about* that field, so leaving it
/// optional would let a fixture omit it and silently store a zero — and a test written that
/// way passes whether or not the value came from the site. Every call site spells it.
NewChapter chapter(
  String id, {
  String? name,
  double number = 1,
  required int ordinal,
}) => NewChapter(
  id: id,
  url: '/fiction/n/chapter/$id',
  name: name ?? 'Chapter $ordinal',
  number: number,
  ordinal: ordinal,
);

/// The three columns a check must never write, as a comparable snapshot of one row.
({bool isRead, DateTime? readAt, DateTime? downloadedAt}) marksOf(
  ChapterRow row,
) => (isRead: row.isRead, readAt: row.readAt, downloadedAt: row.downloadedAt);

void main() {
  group('B39 — the snapshot is every library novel, with NO other predicate', () {
    test('a novel outside the library is not visited', () async {
      final (AppDatabase db, DriftLibraryCheckStore store) = await harness();
      addTearDown(db.close);
      await db.into(db.novels).insert(novelRow('kept'));
      await db.into(db.novels).insert(novelRow('kept-too'));
      await db.into(db.novels).insert(novelRow('browsed', inLibrary: false));

      final List<LibraryNovelRef> listed = await store.listLibraryNovels();

      expect(
        listed.map((LibraryNovelRef r) => r.novelId).toSet(),
        <String>{'kept', 'kept-too'},
        reason:
            'B11/B12: membership is the reader\'s decision and the only filter here',
      );
    });

    test('a novel never checked and one checked an hour ago are BOTH listed', () async {
      // ⚠️ **THE ROW THAT FORBIDS THE OPTIMISATION.** "Skip what was checked recently" is
      // the filter every update implementation reaches for, and B39 — *no novel is skipped
      // **for any reason*** — forbids exactly it. It is invisible from the interface: the
      // total would simply be smaller, and the reader chose 3.
      final (AppDatabase db, DriftLibraryCheckStore store) = await harness();
      addTearDown(db.close);
      await db.into(db.novels).insert(novelRow('never'));
      await db
          .into(db.novels)
          .insert(
            novelRow('recent', lastCheckedAt: DateTime.utc(2026, 10, 4, 8)),
          );
      await db.into(db.novels).insert(novelRow('ancient'));

      final List<LibraryNovelRef> listed = await store.listLibraryNovels();

      expect(
        listed.map((LibraryNovelRef r) => r.novelId).toSet(),
        <String>{'never', 'recent', 'ancient'},
        reason:
            'B39: a timestamp is not a skip criterion, and neither is any other column',
      );
    });

    test('the list is a snapshot taken once, and its order is stable', () async {
      final (AppDatabase db, DriftLibraryCheckStore store) = await harness();
      addTearDown(db.close);
      for (final String id in <String>['c', 'a', 'b']) {
        await db.into(db.novels).insert(novelRow(id, lastCheckedAt: kAt));
      }

      final List<LibraryNovelRef> first = await store.listLibraryNovels();
      await db.into(db.novels).insert(novelRow('d', lastCheckedAt: kAt));
      final List<LibraryNovelRef> second = await store.listLibraryNovels();

      expect(
        first.map((LibraryNovelRef r) => r.novelId),
        <String>['a', 'b', 'c'],
        reason:
            'ties on `last_checked_at` must break on id, or two rows swap on every read',
      );
      expect(second.map((LibraryNovelRef r) => r.novelId), <String>[
        'a',
        'b',
        'c',
        'd',
      ], reason: 'and the ordering key is stable as the library grows');
    });

    test('the ref carries only what a check reads', () async {
      final (AppDatabase db, DriftLibraryCheckStore store) = await harness();
      addTearDown(db.close);
      await db.into(db.novels).insert(novelRow('n1'));

      final LibraryNovelRef ref = (await store.listLibraryNovels()).single;

      expect(
        ref.sourceId,
        'src-a',
        reason: 'B2: the one site this novel came from',
      );
      expect(
        ref.title,
        'Novel n1',
        reason: 'B10: the site\'s own text, as stored',
      );
      expect(
        ref.url,
        '/fiction/n1',
        reason:
            'rule 3: relative, and `HttpSource` is what joins it to a baseUrl',
      );
    });
  });

  group('B49 — recordChecked stamps the novel and clears ITS OWN source only', () {
    test(
      'the timestamp is written, and it is the one the interactor passed',
      () async {
        final (AppDatabase db, DriftLibraryCheckStore store) = await harness();
        addTearDown(db.close);
        await db.into(db.novels).insert(novelRow('n1'));

        await store.recordChecked('n1', kAt);

        final NovelRow row = await (db.select(
          db.novels,
        )..where((Novels t) => t.id.equals('n1'))).getSingle();
        expect(
          row.lastCheckedAt!.toUtc(),
          kAt,
          reason: 'B49: we looked, and here is when',
        );
      },
    );

    test('a success clears the code on ITS OWN source and leaves the others alone', () async {
      // ⚠️ **B23 INVERTED.** A global clear would let a broken site stop reporting *Could
      // not check* because a **different** site succeeded — a failure that hides itself,
      // which is worse than never recording it. § 3.2 branch 6 says the clear is scoped.
      final (AppDatabase db, DriftLibraryCheckStore store) = await harness();
      addTearDown(db.close);
      // ⚠️ **TWO SOURCES, EACH ALREADY FAILED, WITH DIFFERENT CAUSES.** The claim is that
      // stamping novel `a` clears `src-a` and leaves `src-b` alone, which is only
      // distinguishable if the two started in different states — and if one of them had no
      // row at all, "left alone" would be vacuous.
      await addSource(db, 'src-a', lastErrorCode: 'noConnection');
      await addSource(db, 'src-b', lastErrorCode: 'sourceLayoutChanged');
      await db.into(db.novels).insert(novelRow('a'));
      await db.into(db.novels).insert(novelRow('b', sourceId: 'src-b'));

      await store.recordChecked('a', kAt);

      expect(
        (await (db.select(
              db.sources,
            )..where((Sources t) => t.id.equals('src-a'))).getSingle())
            .lastErrorCode,
        '',
        reason: '§ 3.2 branch 6: this site answered, so its own marker goes',
      );
      expect(
        (await (db.select(
              db.sources,
            )..where((Sources t) => t.id.equals('src-b'))).getSingle())
            .lastErrorCode,
        'sourceLayoutChanged',
        reason:
            '⚠️ and the other site keeps its marker: one success says nothing about it, and '
            'B23 is a failure never blocking the others — not one hiding itself',
      );
    });

    test(
      'a novel with no `sources` row is stamped, and nothing is conjured',
      () async {
        final (AppDatabase db, DriftLibraryCheckStore store) = await harness();
        addTearDown(db.close);
        await db
            .into(db.novels)
            .insert(novelRow('orphan', sourceId: 'never-seen'));

        await store.recordChecked('orphan', kAt);

        final NovelRow row = await (db.select(
          db.novels,
        )..where((Novels t) => t.id.equals('orphan'))).getSingle();
        expect(row.lastCheckedAt!.toUtc(), kAt);
        expect(
          await db.select(db.sources).get(),
          isEmpty,
          reason:
              'there is nothing to clear a code on, and inventing a source row would be a '
              'row whose only content is a status nobody set',
        );
      },
    );
  });

  group('B24/B22 — recordCheckFailure writes the TYPED code and nothing else', () {
    test(
      'the code lands on `sources.last_error_code`, spelled as the enum',
      () async {
        final (AppDatabase db, DriftLibraryCheckStore store) = await harness();
        addTearDown(db.close);
        await db.into(db.novels).insert(novelRow('n1'));

        await store.recordCheckFailure('n1', CheckFailureKind.noConnection);

        expect(
          (await (db.select(
                db.sources,
              )..where((Sources t) => t.id.equals('src-a'))).getSingle())
              .lastErrorCode,
          'noConnection',
          reason:
              'B24: an enum name is a closed vocabulary; a free string would let a screen '
              'render a cause nobody declared',
        );
      },
    );

    test('B49 — it never writes `last_checked_at`, for any cause', () async {
      final (AppDatabase db, DriftLibraryCheckStore store) = await harness();
      addTearDown(db.close);
      await db.into(db.novels).insert(novelRow('n1'));

      for (final CheckFailureKind kind in CheckFailureKind.values) {
        await store.recordCheckFailure('n1', kind);
        final NovelRow row = await (db.select(
          db.novels,
        )..where((Novels t) => t.id.equals('n1'))).getSingle();
        expect(
          row.lastCheckedAt,
          isNull,
          reason:
              '⚠️ B49: $kind means "we could not look", and stamping it would make the '
              'row read "we looked and there was nothing"',
        );
      }
    });

    test('it preserves the source\'s OWN settings, including `enabled`', () async {
      // ⚠️ **B41, VIOLATED BY A REASONABLE IMPLEMENTATION.** Drift's
      // `insertOnConflictUpdate` rewrites the whole row from the companion, so an
      // `insertOnConflictUpdate` reporting a failure on a source the reader had switched
      // **off** would switch it back **on** — the platform overwriting a setting, as a side
      // effect of a failure report. A column-level upsert touches one column.
      final (AppDatabase db, DriftLibraryCheckStore store) = await harness();
      addTearDown(db.close);
      await db
          .into(db.sources)
          .insert(
            SourcesCompanion.insert(
              id: 'off',
              enabled: const Value(false),
              settings: const Value('{"pageSize":50}'),
              lastCheckedAt: Value(kAt),
            ),
            mode: InsertMode.insertOrIgnore,
          );
      await db.into(db.novels).insert(novelRow('n1', sourceId: 'off'));

      await store.recordCheckFailure('n1', CheckFailureKind.sourceUnavailable);

      final SourceRow row = await (db.select(
        db.sources,
      )..where((Sources t) => t.id.equals('off'))).getSingle();
      expect(
        row.lastErrorCode,
        'sourceUnavailable',
        reason: 'the code is the point of the call',
      );
      expect(
        row.enabled,
        isFalse,
        reason:
            'B41: reporting a failure must not re-enable a source the reader switched off',
      );
      expect(
        row.settings,
        '{"pageSize":50}',
        reason:
            'and its own settings are the source\'s, not the platform\'s to overwrite',
      );
      expect(
        row.lastCheckedAt!.toUtc(),
        kAt,
        reason: 'and its own timestamp is not this novel\'s',
      );
    });

    test('a source with NO row gets one, carrying only the code', () async {
      // A novel whose source has never failed has no `sources` row — the registry is code
      // (ADR-013). The first failure report is what creates it, and it must not invent the
      // rest of a row.
      final (AppDatabase db, DriftLibraryCheckStore store) = await harness();
      addTearDown(db.close);
      await db.into(db.novels).insert(novelRow('n1', sourceId: 'fresh'));

      await store.recordCheckFailure('n1', CheckFailureKind.parseFailed);

      final SourceRow row = await (db.select(
        db.sources,
      )..where((Sources t) => t.id.equals('fresh'))).getSingle();
      expect(row.lastErrorCode, 'parseFailed');
      expect(
        row.enabled,
        isTrue,
        reason: 'a schema default, not a decision this call made',
      );
      expect(row.settings, '{}', reason: 'and no settings were invented');
    });

    test('the `failedSelector` is NOT stored, on any column', () async {
      // `library_repository.dart` says so, and the reason is `architecture.md` § 5.2: a
      // column carrying a CSS class name is a column a screen could render.
      final (AppDatabase db, DriftLibraryCheckStore store) = await harness();
      addTearDown(db.close);
      await db.into(db.novels).insert(novelRow('n1'));

      await store.recordCheckFailure(
        'n1',
        CheckFailureKind.sourceLayoutChanged,
      );

      for (final TableInfo<Object?, Object?> table
          in <TableInfo<Object?, Object?>>[
            db.novels,
            db.sources,
            db.chapters,
          ]) {
        final List<QueryRow> cols = await db
            .customSelect('PRAGMA table_info(${table.actualTableName})')
            .get();
        for (final QueryRow col in cols) {
          expect(
            col.read<String>('name'),
            isNot(contains('selector')),
            reason:
                '17-security.md rule 4: a raw CSS selector must never reach a column a '
                'reader-facing query could return',
          );
        }
      }
    });
  });

  group('B48/B3 — mergeChapterList is INSERT OR IGNORE, and returns rows ADDED', () {
    test(
      'three new chapters are added and the return value is three',
      () async {
        final (AppDatabase db, DriftLibraryCheckStore store) = await harness();
        addTearDown(db.close);
        await db.into(db.novels).insert(novelRow('n1'));

        final int added = await store.mergeChapterList('n1', <NewChapter>[
          chapter('c1', ordinal: 0),
          chapter('c2', ordinal: 1),
          chapter('c3', ordinal: 2),
        ]);

        expect(added, 3);
        expect(
          await db.select(db.chapters).get(),
          hasLength(3),
          reason: 'three rows, one per chapter the site published',
        );
      },
    );

    test('re-merging the same list adds NOTHING and returns 0', () async {
      // B3: the id is derived, so a second check of the same novel cannot duplicate its
      // list — and B48's announcement ("found N new chapters") must be 0 the second time,
      // not the site's whole chapter count.
      final (AppDatabase db, DriftLibraryCheckStore store) = await harness();
      addTearDown(db.close);
      await db.into(db.novels).insert(novelRow('n1'));
      final List<NewChapter> fresh = <NewChapter>[
        chapter('c1', ordinal: 0),
        chapter('c2', ordinal: 1),
      ];
      await store.mergeChapterList('n1', fresh);

      final int added = await store.mergeChapterList('n1', fresh);

      expect(added, 0, reason: 'B48: "new" means rows ADDED by this call');
      expect(await db.select(db.chapters).get(), hasLength(2));
    });

    test(
      'a partly-known list adds only the rows it did not already hold',
      () async {
        final (AppDatabase db, DriftLibraryCheckStore store) = await harness();
        addTearDown(db.close);
        await db.into(db.novels).insert(novelRow('n1'));
        await store.mergeChapterList('n1', <NewChapter>[
          chapter('c1', ordinal: 0),
          chapter('c2', ordinal: 1),
        ]);

        final int added = await store.mergeChapterList('n1', <NewChapter>[
          chapter('c1', ordinal: 0),
          chapter('c2', ordinal: 1),
          chapter('c3', ordinal: 2),
        ]);

        expect(
          added,
          1,
          reason:
              'the count is the rows THIS call supplied minus the ones already present, '
              'which is why it is not `total - known` over the novel\'s whole list',
        );
        expect(await db.select(db.chapters).get(), hasLength(3));
      },
    );

    test('B13/B6 — an existing row keeps `is_read`, `read_at` and `downloaded_at`', () async {
      // ⚠️ **THE ASYMMETRY WITH `drift_chapter_list_repository.dart`, WHICH IS THE POINT.**
      // The loader replaces a list (delete-then-insert) because the first open establishes
      // it; a check must not run that code, or every pass would reset the reader's
      // progress. `IGNORE` never updates, so an existing row survives byte for byte.
      final (AppDatabase db, DriftLibraryCheckStore store) = await harness();
      addTearDown(db.close);
      await db.into(db.novels).insert(novelRow('n1'));
      await db
          .into(db.chapters)
          .insert(
            ChaptersCompanion.insert(
              id: 'c1',
              novelId: 'n1',
              name: 'Chapter 0',
              url: '/fiction/n/chapter/c1',
              ordinal: 0,
              isRead: const Value(true),
              readAt: Value(kAt),
              downloadedAt: Value(kAt),
            ),
          );
      final ChapterRow before = await (db.select(
        db.chapters,
      )..where((Chapters t) => t.id.equals('c1'))).getSingle();

      // The site has since RENAMED it and moved it. A replace would apply both.
      final int added = await store.mergeChapterList('n1', <NewChapter>[
        chapter('c1', name: 'Chapter 0 (site\'s new title)', ordinal: 0),
      ]);

      final ChapterRow after = await (db.select(
        db.chapters,
      )..where((Chapters t) => t.id.equals('c1'))).getSingle();
      expect(
        added,
        0,
        reason: 'the id is unchanged, so this is the same chapter',
      );
      expect(
        marksOf(after),
        marksOf(before),
        reason:
            '⚠️ B13/B6: opening a chapter and downloading it are the reader\'s two acts, '
            'and a check cannot undo either',
      );
      expect(
        after.name,
        'Chapter 0',
        reason:
            'and the stored title is not silently replaced by the site\'s new one',
      );
    });

    test('a discovered chapter arrives UNOPENED and NOT on the phone', () async {
      // E16(b): once found, it counts immediately like any other unopened chapter, and its
      // body is **not** fetched — which is B38 at the row level.
      final (AppDatabase db, DriftLibraryCheckStore store) = await harness();
      addTearDown(db.close);
      await db.into(db.novels).insert(novelRow('n1'));

      await store.mergeChapterList('n1', <NewChapter>[
        chapter('c1', ordinal: 0),
      ]);

      final ChapterRow row = await (db.select(
        db.chapters,
      )..where((Chapters t) => t.id.equals('c1'))).getSingle();
      expect(
        row.isRead,
        isFalse,
        reason: 'B13: a chapter counts as new until the user OPENS it',
      );
      expect(row.readAt, isNull);
      expect(
        row.downloadedAt,
        isNull,
        reason:
            'B6/ADR-022: the mark is written by 2-3 after the atomic rename, and B38 '
            'forbids a check from writing it',
      );
    });

    test('B9 — the ordinal is the site\'s position and is not re-derived', () async {
      final (AppDatabase db, DriftLibraryCheckStore store) = await harness();
      addTearDown(db.close);
      await db.into(db.novels).insert(novelRow('n1'));

      // Royal Road orders by publication date, so ordinal and number genuinely disagree.
      await store.mergeChapterList('n1', <NewChapter>[
        chapter('a', number: 526587, ordinal: 0),
        chapter('b', number: 568159, ordinal: 1),
        chapter('c', number: 520102, ordinal: 2),
      ]);

      final List<ChapterRow> rows =
          await (db.select(db.chapters)
                ..orderBy(<OrderingTerm Function($ChaptersTable)>[
                  ($ChaptersTable t) => OrderingTerm.asc(t.ordinal),
                ]))
              .get();
      expect(
        rows.map((ChapterRow r) => r.ordinal).toList(),
        <int>[0, 1, 2],
        reason:
            'B9: the ordinal is stored as given, never recomputed from the number',
      );
      expect(
        rows.map((ChapterRow r) => r.number).toList(),
        <double>[526587, 568159, 520102],
        reason:
            'and the numbers are the site\'s, unsorted — re-deriving the order from them '
            'would be the failure `18-external-contracts.md` records for Royal Road',
      );
    });

    test('B10 — an unparseable number is stored as -1 and never as 0', () async {
      final (AppDatabase db, DriftLibraryCheckStore store) = await harness();
      addTearDown(db.close);
      await db.into(db.novels).insert(novelRow('n1'));

      await store.mergeChapterList('n1', <NewChapter>[
        chapter('unnumbered', number: -1, ordinal: 0),
        chapter('zero', number: 0, ordinal: 1),
      ]);

      final List<ChapterRow> rows =
          await (db.select(db.chapters)
                ..orderBy(<OrderingTerm Function($ChaptersTable)>[
                  ($ChaptersTable t) => OrderingTerm.asc(t.ordinal),
                ]))
              .get();
      expect(
        rows.map((ChapterRow r) => r.number).toList(),
        <double>[-1, 0],
        reason:
            'B10: `-1` is "the site published no number" and `0` is a real chapter — an '
            'extra, an omake, a note — and they must not share a value',
      );
    });

    test('an empty list writes nothing and returns 0', () async {
      final (AppDatabase db, DriftLibraryCheckStore store) = await harness();
      addTearDown(db.close);
      await db.into(db.novels).insert(novelRow('n1'));

      expect(await store.mergeChapterList('n1', const <NewChapter>[]), 0);
      expect(await db.select(db.chapters).get(), isEmpty);
    });

    test('B48 — the unopened count moves only when a ROW moves', () async {
      // ⚠️ **THE COUNT IS COMPUTED, NEVER STORED.** `architecture.md` § 4.7: a stored
      // count is a second source of truth free to disagree with the rows it counts. So the
      // number moves because rows moved, and a pass that adds nothing leaves it alone even
      // though it read the site.
      final (AppDatabase db, DriftLibraryCheckStore store) = await harness();
      addTearDown(db.close);
      await db.into(db.novels).insert(novelRow('n1'));
      await store.mergeChapterList('n1', <NewChapter>[
        chapter('c1', ordinal: 0),
        chapter('c2', ordinal: 1),
      ]);
      expect(await _unopened(db, 'n1'), 2);

      await store.mergeChapterList('n1', <NewChapter>[
        chapter('c1', ordinal: 0),
        chapter('c2', ordinal: 1),
      ]);
      expect(
        await _unopened(db, 'n1'),
        2,
        reason:
            'a re-check that adds no row leaves the local count exactly where it was',
      );

      await store.mergeChapterList('n1', <NewChapter>[
        chapter('c3', ordinal: 2),
      ]);
      expect(
        await _unopened(db, 'n1'),
        3,
        reason: 'and a genuinely new chapter moves it by exactly one',
      );
    });
  });

  group('B41 — isSourceEnabled reads a COLUMN, and absent means enabled', () {
    test(
      'a source with no row is enabled, so a fresh install can check',
      () async {
        final (AppDatabase db, DriftLibraryCheckStore store) = await harness();
        addTearDown(db.close);

        expect(
          await store.isSourceEnabled('never-heard-of-it'),
          isTrue,
          reason:
              '§ 3.2 guard 0: reading "no row" as "off" would make every novel fail its '
              'very first check with nothing on screen to explain it',
        );
      },
    );

    test('a source the reader switched off reads as off', () async {
      final (AppDatabase db, DriftLibraryCheckStore store) = await harness();
      addTearDown(db.close);
      await addSource(db, 'src-a', enabled: false);

      expect(
        await store.isSourceEnabled('src-a'),
        isFalse,
        reason:
            'B41: the switch is a local setting and it governs what a check may read',
      );
    });
  });
}

/// `COUNT(is_read = 0)` for one novel — the query B48 says the count **is**.
Future<int> _unopened(AppDatabase db, String novelId) async {
  final QueryRow row = await db
      .customSelect(
        'SELECT COUNT(c.id) AS total FROM chapters c '
        'WHERE c.novel_id = ? AND c.is_read = 0',
        variables: <Variable<Object>>[Variable<String>(novelId)],
      )
      .getSingle();
  return row.read<int>('total');
}
