// forge:slice 6-4
// Lumen Tale — one pass over a REAL database, and the four rows a screen reads afterwards.
//
// ## Why this file and not a bigger one in `drift_library_check_store_test.dart`
//
// The store's own rows assert **what the SQL did** to one column at a time. § 10 writes
// its B15/B49 and E9 rows as *pairs of facts about a novel's row* — the timestamp and the
// code, the timestamp and the chapter count — and neither pair exists until a real pass
// wrote both halves. A check with a fake store can assert that `recordChecked` was called;
// it cannot assert that the two facts a screen renders agree with each other afterwards.
//
// | § 10 | the row | the pair |
// |---|---|---|
// | **B15 / B49** | after a `noConnection`, `last_checked_at` is still `null` **and** `sources.last_error_code == 'noConnection'` | *we could not look* / *here is why* |
// | **E9** | after an `ItemRemovedAtSource`, `last_checked_at` **is** written and `COUNT(is_read = 0)` is unchanged | *we looked* / *and nothing was lost* |
// | **B22 / B23** | one site broken while another answers | the broken site's code survives the other's success |
// | **§ 3.2 branch 6** | fail, then succeed | the code is cleared and the timestamp is written |
//
// ## ⚠️ EVERY ROW BELOW RUNS REAL `dart:io`
//
// A real sqlite file, in memory. So every test here is a **`test()`, never a
// `testWidgets()`**: a widget test runs its body in a fake-async zone where a real file
// future never completes, so such a test hangs and takes the whole suite with it.
//
// ## ⚠️ AND `last_checked_at` IS COMPARED THROUGH `toUtc()`
//
// drift stores a `DateTime` as a unix count and rebuilds it in **local** time, so comparing
// a UTC instant against the row fails on the `Z` and says nothing about the write.

import 'package:drift/drift.dart' show InsertMode, QueryRow, Value, Variable;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumen_tale/core/database/app_database.dart';
import 'package:lumen_tale/core/error/source_failure.dart';
import 'package:lumen_tale/core/network/host_rate_limiter.dart';
import 'package:lumen_tale/data/sources/source_manager.dart';
import 'package:lumen_tale/data/updates/drift_check_library.dart';
import 'package:lumen_tale/data/updates/drift_library_check_store.dart';
import 'package:lumen_tale/domain/sources/browse_outcome.dart';
import 'package:lumen_tale/domain/sources/models/novel.dart';
import 'package:lumen_tale/domain/sources/source.dart';
import 'package:lumen_tale/domain/sources/source_id.dart';
import 'package:lumen_tale/domain/updates/library_check.dart';

import 'check_fakes.dart';

/// The instant the interactor's clock reports, so no row depends on the wall clock.
final DateTime kCheckedAt = DateTime.utc(2026, 10, 4, 9, 30);

/// Never cancelled.
Future<bool> neverCancelled() async => false;

void main() {
  late AppDatabase db;
  late List<SpySource> sites;

  /// A pass over the whole library, against [db] and every site in [sites].
  Future<LibraryCheckResult> pass() => DriftCheckLibrary(
    store: DriftLibraryCheckStore(db),
    sources: SourceManager(<Source>[for (final SpySource s in sites) s]),
    rateLimiter: HostRateLimiter(
      clock: () => kCheckedAt,
      sleep: (Duration _) async {},
    ),
    clock: () => kCheckedAt,
  ).run(onProgress: (_) {}, cancellation: neverCancelled);

  /// A novel in the library, with two chapter rows the reader already holds.
  ///
  /// ⚠️ **[sourceId] IS REQUIRED, NOT DEFAULTED.** A check resolves a novel through its
  /// source, so a fixture that forgot the name would seed a novel nothing can read — and
  /// every row here would then be measuring `itemRemovedAtSource` while reading as a test
  /// about something else.
  ///
  /// ⚠️ **`isRead` IS NEVER SET HERE.** A fixture that marks chapters read would make
  /// `COUNT(is_read = 0)` a number a check could appear to move by accident, and the E9
  /// row below is *only* meaningful against rows that carry the reader's own history. The
  /// count is 2 before the pass here, and the row asserts it is 2 after it.
  Future<void> seedNovel(String id, {required String sourceId}) async {
    await db
        .into(db.novels)
        .insert(
          NovelsCompanion.insert(
            id: id,
            sourceId: sourceId,
            url: '/fiction/$id',
            title: 'Novel $id',
            inLibrary: const Value(true),
          ),
          mode: InsertMode.insertOrIgnore,
        );
    for (int i = 0; i < 2; i++) {
      final String url = '/fiction/$id/chapter/$i';
      await db
          .into(db.chapters)
          .insert(
            ChaptersCompanion.insert(
              // ⚠️ **THE DERIVED ID, NOT `$id-c$i`.** B3's stability is what makes the rows
              // this pass must not touch *these* rows, and the derivation is the interactor's
              // own — a fixture that re-spelled it could drift from the code under test.
              id: SourceId.forChapter(novelId: id, relativeUrl: url),
              novelId: id,
              name: 'Chapter $i',
              url: url,
              ordinal: i,
            ),
            mode: InsertMode.insertOrIgnore,
          );
    }
  }

  /// A `sources` row, carrying the marker an earlier pass left on it.
  ///
  /// ⚠️ **THE REGISTRY IS CODE, NOT A ROW.** `novels.source_id` is not a foreign key to
  /// `sources`, and a row appears only once something has had something to say about the
  /// source — so a fixture that pre-seeded one would start from a state a fresh install
  /// never reaches, and the "absent means enabled" branch would never run.
  Future<void> seedSource(String id, {required String lastErrorCode}) => db
      .into(db.sources)
      .insert(
        SourcesCompanion.insert(id: id, lastErrorCode: Value(lastErrorCode)),
        mode: InsertMode.insertOrIgnore,
      );

  /// `COUNT(is_read = 0)` for one novel — B48's count, in the one place it is defined.
  Future<int> unopened(String novelId) async {
    final QueryRow row = await db
        .customSelect(
          'SELECT COUNT(c.id) AS total FROM chapters c '
          'WHERE c.novel_id = ? AND c.is_read = 0',
          variables: <Variable<Object>>[Variable<String>(novelId)],
        )
        .getSingle();
    return row.read<int>('total');
  }

  Future<DateTime?> lastCheckedAt(String novelId) async =>
      (await (db.select(
            db.novels,
          )..where(($NovelsTable t) => t.id.equals(novelId))).getSingle())
          .lastCheckedAt;

  /// `sources.last_error_code`, **as the nullable column it is**.
  ///
  /// ⚠️ **`String?`, NOT `?? ''`.** The column is `text().nullable()` with a `''` default, so
  /// `null` and `''` are two different shapes of "no code" — and B24's claim is that a
  /// failed novel carries a code a screen can render. Collapsing them here would let a row
  /// that wrote `NULL` pass as a clear.
  Future<String?> lastErrorCode(String sourceId) async =>
      (await (db.select(
            db.sources,
          )..where(($SourcesTable t) => t.id.equals(sourceId))).getSingle())
          .lastErrorCode;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    // ⚠️ **`SpySource()` AND NOT `SpySource(sourceId: 'src-a')`.** The spy's default id IS
    // `'src-a'`, so naming it again is a redundant argument — and `avoid_redundant_argument_values`
    // is right to say so. Every novel in these rows is seeded against `src-a` explicitly,
    // which is the fact that matters.
    sites = <SpySource>[SpySource()];
  });

  tearDown(() => db.close());

  group('B15/B49 — a failure that means "we could not look" writes BOTH halves', () {
    test('after a `noConnection`: no timestamp, and the code a screen can read', () async {
      // ⚠️ **THE PAIR IS THE ROW.** Either half alone would pass while the other was
      // wrong: a pass that stamped the novel would render "Never checked" as a check that
      // found nothing (B49's exact prohibition), and a pass that recorded no code would
      // leave the row claiming *Could not check* with nothing to say why — B15's local
      // answer is only honest because the cause is stored.
      await seedNovel('n1', sourceId: 'src-a');
      sites.single.details = const BrowseFailed<Novel>(
        NoConnection(host: 'site.test'),
        retriable: true,
      );

      final LibraryCheckResult result = await pass();

      expect(
        result.perNovel.single,
        isA<NovelCheckFailed>(),
        reason:
            'B22: the site could not be read, so this is a verdict and not a zero',
      );
      expect(
        await lastCheckedAt('n1'),
        isNull,
        reason:
            '⚠️ B49: `null` is the whole claim. A timestamp here would tell the reader the '
            'novel was checked and found nothing, which is the opposite of what happened',
      );
      expect(
        await lastErrorCode('src-a'),
        'noConnection',
        reason:
            'B24/B15: the typed code is what the library row renders *Could not check* '
            'without a fetch, and it is spelled as the enum on purpose',
      );
      expect(
        await unopened('n1'),
        2,
        reason: 'B48: the local count is untouched by a pass that read nothing',
      );
    });
  });

  group('E9 — the one failure that writes the timestamp, and takes nothing away', () {
    test('after an `ItemRemovedAtSource`: stamped, and the count is unchanged', () async {
      // ⚠️ **THE TWO HALVES PULL IN OPPOSITE DIRECTIONS, WHICH IS WHY BOTH ARE HERE.**
      // E9 is the only failure that may write `last_checked_at` — the site answered, and
      // the answer was that the novel is gone — and it is the case where a reader's next
      // fear is "did I just lose the chapters I downloaded". B7/B32 answer that, and the
      // answer is only credible if the count is asserted after the fact rather than
      // promised in a comment.
      await seedNovel('n1', sourceId: 'src-a');
      sites.single.details = const BrowseFailed<Novel>(
        ItemRemovedAtSource(itemId: 'n1', status: 404),
        retriable: false,
      );
      final int before = await unopened('n1');

      final LibraryCheckResult result = await pass();

      expect(
        (result.perNovel.single as NovelCheckFailed).kind,
        CheckFailureKind.itemRemovedAtSource,
        reason:
            'E9 has its own verdict, and it is the only failure that stamps',
      );
      expect(
        (await lastCheckedAt('n1'))?.toUtc(),
        kCheckedAt,
        reason:
            'B49: we looked, and we saw — so the honest stamp is a real one',
      );
      expect(
        await unopened('n1'),
        before,
        reason:
            '⚠️ B7/E9: the novel is gone from the SITE, not from the phone. A tidy-up '
            'delete here is invisible in the pass\'s result and destructive in the reader\'s '
            'library, with no backup (C8)',
      );
      expect(
        await db.select(db.chapters).get(),
        hasLength(2),
        reason:
            'and the rows themselves are still there — not renumbered, not re-flagged',
      );
    });
  });

  group('B23 — one broken site does not repair itself because another answered', () {
    test('the broken site\'s code SURVIVES the other site\'s success', () async {
      // ⚠️ **TWO NOVELS, TWO SOURCES, ONE PASS — AND THAT IS THE POINT.** A pass over one
      // site cannot show the defect: the clear is scoped to the novel's own source, so it
      // needs a second site that is genuinely broken to be caught. § 3.2 branch 6's warning
      // is that a *global* clear would let a broken site stop reporting *Could not check*
      // the moment any other site answered — a failure that hides itself, which B23 turned
      // around by accident.
      await seedNovel('a', sourceId: 'src-a');
      await seedNovel('b', sourceId: 'src-b');
      // ⚠️ **BOTH SOURCES START WITH A STALE MARKER.** A source that has never failed has no
      // row at all, so a clear would be invisible and this row vacuous. `src-b`'s
      // `noConnection` is what an earlier pass left there: the site recovered, this pass
      // answers, and its own marker must go. `src-a`'s is about to be overwritten by the
      // failure of this pass — the other half of the comparison.
      await seedSource('src-a', lastErrorCode: 'noConnection');
      await seedSource('src-b', lastErrorCode: 'noConnection');
      sites = <SpySource>[
        SpySource(), // id `src-a`, the broken one
        SpySource(sourceId: 'src-b'),
      ];

      sites[0].details = const BrowseFailed<Novel>(
        SourceLayoutChanged(failedSelector: 'table#chapters', status: 200),
        retriable: false,
      );
      // `src-b` answers, which is what writes `recordChecked` for novel `b`.

      final LibraryCheckResult result = await pass();

      expect(
        result.perNovel,
        hasLength(2),
        reason: 'B39: both novels were visited',
      );
      expect(result.failedCount, 1);
      expect(
        await lastErrorCode('src-a'),
        'sourceLayoutChanged',
        reason: 'B24: the broken site is recorded with its own cause',
      );
      expect(
        await lastCheckedAt('a'),
        isNull,
        reason: 'B49: a page that would not parse is not a check',
      );
      expect(
        await lastCheckedAt('b'),
        isNotNull,
        reason:
            'and the site that answered IS stamped — the clear is not the whole row',
      );
      expect(
        await lastErrorCode('src-b'),
        '',
        reason:
            'this one answered, so its own marker goes — and only its own: `src-a` kept '
            'the marker it earned',
      );
    });
  });

  group('§ 3.2 branch 6 — a site that fails and then answers', () {
    test(
      'the code is cleared AND the timestamp is written, on the second pass',
      () async {
        // B22's repair story: the reader is told *Could not check*, the site comes back, and
        // the next pass has to leave no trace of the failure — or the row keeps saying
        // "could not check" about a site that answered two minutes ago.
        await seedNovel('n1', sourceId: 'src-a');
        sites.single.details = const BrowseFailed<Novel>(
          ParseFailed(path: '/fiction/n1'),
          retriable: false,
        );

        await pass();

        expect(
          await lastCheckedAt('n1'),
          isNull,
          reason: 'B49: run 1 did not look',
        );
        expect(await lastErrorCode('src-a'), 'parseFailed');

        // The site recovers: no declared failure, so it publishes its own empty list.
        sites.single.details = null;

        await pass();

        expect(
          (await lastCheckedAt('n1'))?.toUtc(),
          kCheckedAt,
          reason: 'B49: run 2 did look, and the stamp is the moment it looked',
        );
        expect(
          await lastErrorCode('src-a'),
          '',
          reason:
              '⚠️ § 3.2 branch 6: a success clears THIS source\'s marker, and B23 is why the '
              'clear is scoped — a global one would repair every broken site at once',
        );
      },
    );
  });
}
