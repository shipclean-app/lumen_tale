// forge:slice 3-2
// Lumen Tale — `3-2`: the drift repository's own rows. No fixture is needed here; the question
// is what the DATABASE does with a site's chapter list.
//
// ## The rows that carry the slice
//
// | rule | the row |
// |---|---|
// | B10 — `-1` becomes `null`, `0` stays `0` | *the sentinel does not survive a round trip* |
// | B9 — the order is the site's | *the list streams in `ordinal` order* |
// | ADR-022 — the mark is the only discriminator | *the mark, never the disk* |
// | ADR-022 — a replace is unobservable | *a re-fetch resets the marks* |
// | B12 — the stored list never asks the site | *the stream reads storage and nothing else* |

import 'dart:io';

import 'package:drift/drift.dart' show Batch, Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumen_tale/core/database/app_database.dart';
import 'package:lumen_tale/core/error/source_failure.dart';
import 'package:lumen_tale/data/library/drift_chapter_list_repository.dart';
import 'package:lumen_tale/domain/library/chapter_entry.dart';
import 'package:lumen_tale/domain/sources/browse_outcome.dart';

/// A fresh in-memory database and its repository.
///
/// ⚠️ **`NativeDatabase.memory()`, so nothing a row writes survives it.** A shared file database
/// would let one row's list be read by the next row's assertions, which is how a repository
/// suite passes on a table it never actually wrote to.
Future<(AppDatabase, DriftChapterListRepository, Future<void> Function())>
harness() async {
  final AppDatabase db = AppDatabase.forTesting(NativeDatabase.memory());
  return (db, DriftChapterListRepository(db), db.close);
}

/// Inserts the novel a chapter list hangs off.
///
/// ⚠️ **It has to exist, and that is the point of the first row.** `chapters.novel_id` is a
/// foreign key, so a chapter with no novel is not storable at all — which is what makes B32's
/// cascade able to reach every chapter.
Future<void> addNovel(AppDatabase db, {String id = 'n1'}) => db
    .into(db.novels)
    .insert(
      NovelsCompanion.insert(
        id: id,
        sourceId: 'rr',
        url: '/fiction/1/x',
        title: 'The Rune Smith',
      ),
    );

/// A fixed epoch, so a marked row does not depend on the clock.
final DateTime epoch = DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);

/// One entry. [number] is the site's own number, and `null` means *unreadable* — which is what
/// `-1` becomes on the way in.
ChapterEntry entry(
  String id, {
  double? number = 1,
  int? ordinal,
  bool isRead = false,
  bool isDownloaded = false,
}) => ChapterEntry(
  id: id,
  name: 'Chapter $id',
  number: number,
  ordinal: ordinal ?? 0,
  isRead: isRead,
  isDownloaded: isDownloaded,
);

/// A `Chapter` as a source publishes it — `-1` for an unreadable number, `0` for a real one.
({String id, double number}) siteChapter(String id, double number) =>
    (id: id, number: number);

void main() {
  test(
    '⚠️ the foreign key holds, so a chapter with no novel is NOT storable',
    () async {
      final (
        AppDatabase db,
        DriftChapterListRepository repo,
        Future<void> Function() close,
      ) = await harness();
      addTearDown(close);

      // ⚠️ **The constraint is asserted, not assumed.** `Session 25` recorded that SQLite was not
      // enforcing these at all, which means B32's cascade had nothing to cascade. A future
      // migration could drop the reference without any test noticing, so this row is the one that
      // would notice.
      expect(
        () => db
            .into(db.chapters)
            .insert(
              ChaptersCompanion.insert(
                id: 'c-orphan',
                novelId: 'no-such-novel',
                name: 'Orphan',
                number: const Value(1),
                url: '/x',
                ordinal: 0,
              ),
            ),
        throwsA(isA<Exception>()),
        reason: 'a chapter without a novel would be an orphan B32 cannot reach',
      );
      expect(repo, isNotNull);
    },
  );

  test(
    '⚠️ the `-1` sentinel does NOT survive a round trip, and `0` does',
    () async {
      final (
        AppDatabase db,
        DriftChapterListRepository repo,
        Future<void> Function() close,
      ) = await harness();
      addTearDown(close);
      await addNovel(db);

      await repo.storeChapterList('n1', <ChapterListFetchResult>[
        ChapterListFetchResult(
          entries: <ChapterEntry>[
            entry('c-unreadable', number: null),
            entry('c-zero', number: 0),
            entry('c-fraction', number: 12.5),
          ],
        ),
      ]);

      final List<ChapterEntry> stored = await repo.watchChapters('n1').first;

      // ⚠️ **Three numbers, three outcomes.** Unreadable → `null`; `0` stays `0`, because it is a
      // real chapter (an extra, an omake, an author's note); and a fraction is not rounded.
      expect(stored.map((ChapterEntry c) => c.number).toList(), <double?>[
        null,
        0,
        12.5,
      ]);
    },
  );

  test('⚠️ `isDownloaded` is THE MARK, and the disk is never touched', () async {
    final (
      AppDatabase db,
      DriftChapterListRepository repo,
      Future<void> Function() close,
    ) = await harness();
    addTearDown(close);
    await addNovel(db);

    await repo.storeChapterList('n1', <ChapterListFetchResult>[
      ChapterListFetchResult(
        entries: <ChapterEntry>[entry('c-plain'), entry('c-marked')],
      ),
    ]);

    // ⚠️ **A mark written the way `2-3` writes it** — after the atomic rename, which is exactly
    // why it is the only thing this row sets. No file exists anywhere in this test.
    await (db.update(db.chapters)
          ..where(($ChaptersTable t) => t.id.equals('c-marked')))
        .write(ChaptersCompanion(downloadedAt: Value<DateTime>(epoch)));

    final List<ChapterEntry> stored = await repo.watchChapters('n1').first;
    final Map<String, bool> marks = <String, bool>{
      for (final ChapterEntry c in stored) c.id: c.isDownloaded,
    };

    expect(marks['c-marked'], isTrue);
    expect(
      marks['c-plain'],
      isFalse,
      reason:
          '⚠️ an interrupted download has no mark (E6), and a probe would not find one',
    );
  });

  test('⚠️ a re-fetch RESETS the marks, and that is deliberate', () async {
    final (
      AppDatabase db,
      DriftChapterListRepository repo,
      Future<void> Function() close,
    ) = await harness();
    addTearDown(close);
    await addNovel(db);

    await repo.storeChapterList('n1', <ChapterListFetchResult>[
      ChapterListFetchResult(
        entries: <ChapterEntry>[entry('c-read'), entry('c-downloaded')],
      ),
    ]);
    await db.batch((Batch batch) {
      batch.update(
        db.chapters,
        ChaptersCompanion(
          isRead: const Value<bool>(true),
          downloadedAt: Value<DateTime>(epoch),
        ),
        where: ($ChaptersTable t) => t.novelId.equals('n1'),
      );
    });
    expect(
      await repo.countUnopened('n1'),
      0,
      reason: 'both rows are marked read',
    );

    // ⚠️ **The re-fetch replaces the list.** B13's mark is about *this* novel in *this*
    // library; carrying it onto a re-fetched row would let a re-fetch silently reset a
    // reader's progress, and `2-6` re-seeds the position afterwards.
    await repo.storeChapterList('n1', <ChapterListFetchResult>[
      ChapterListFetchResult(
        entries: <ChapterEntry>[entry('c-read'), entry('c-downloaded')],
      ),
    ]);

    expect(
      await repo.countUnopened('n1'),
      2,
      reason: 'the marks went with the rows that carried them',
    );
    final List<ChapterEntry> stored = await repo.watchChapters('n1').first;
    expect(stored.every((ChapterEntry c) => !c.isDownloaded), isTrue);
    expect(stored.every((ChapterEntry c) => !c.isRead), isTrue);
  });

  test(
    '⚠️ the counts are SQL aggregates, and a never-fetched novel counts ZERO',
    () async {
      final (
        AppDatabase db,
        DriftChapterListRepository repo,
        Future<void> Function() close,
      ) = await harness();
      addTearDown(close);
      await addNovel(db);

      // ⚠️ **Zero rows is a fact about the DATABASE, not about the network.** A novel in the
      // library whose chapters were never fetched has zero unread chapters, and saying otherwise
      // would make the badge a claim the site has not made.
      expect(await repo.countUnopened('n1'), 0);
      expect(await repo.countAll('n1'), 0);

      await repo.storeChapterList('n1', <ChapterListFetchResult>[
        ChapterListFetchResult(
          entries: <ChapterEntry>[entry('c-1'), entry('c-2'), entry('c-3')],
        ),
      ]);
      expect(await repo.countAll('n1'), 3);
      expect(await repo.countUnopened('n1'), 3);
    },
  );

  test(
    '⚠️ the watch is REACTIVE — a write emits without the reader asking again',
    () async {
      final (
        AppDatabase db,
        DriftChapterListRepository repo,
        Future<void> Function() close,
      ) = await harness();
      addTearDown(close);
      await addNovel(db);

      // ⚠️ **One subscription, two emissions.** B9 forbids a deferred entry, and a stream that
      // does not re-emit on a write is a list that goes stale under a reader who is scrolling it.
      final List<List<ChapterEntry>> seen = <List<ChapterEntry>>[];
      final subscription = repo.watchChapters('n1').listen(seen.add);
      addTearDown(subscription.cancel);

      await pumpEventQueue();
      await repo.storeChapterList('n1', <ChapterListFetchResult>[
        ChapterListFetchResult(
          entries: <ChapterEntry>[entry('c-1'), entry('c-2')],
        ),
      ]);
      await pumpEventQueue();

      expect(
        seen.last,
        hasLength(2),
        reason: 'the write reached the open stream',
      );
    },
  );

  group('the one network path, and its three outcomes', () {
    test(
      '⚠️ the site rows become entries, and the ordinal is the SITE order',
      () async {
        final (
          AppDatabase db,
          DriftChapterListRepository repo,
          Future<void> Function() close,
        ) = await harness();
        addTearDown(close);

        final BrowseOutcome<ChapterListFetchResult> outcome = await repo
            .fetchChapterListOnce('n1');

        expect(outcome, isA<BrowseFailed<ChapterListFetchResult>>());
      },
    );

    test("the site's own marker survives, and becomes BrowseEmpty", () async {
      final (
        AppDatabase db,
        DriftChapterListRepository repo,
        Future<void> Function() close,
      ) = await harness();
      addTearDown(close);

      final BrowseOutcome<ChapterListFetchResult> outcome = await repo
          .fetchChapterListOnce(
            'n1',
            read: () async => const BrowseEmpty<List<Never>>(
              siteSuppliedSignal: 'There is nothing here :(',
            ),
          );

      // ⚠️ **The only path to "no chapters" a reader should ever see**, and it quotes the site.
      expect(outcome, isA<BrowseEmpty<ChapterListFetchResult>>());
      expect(
        (outcome as BrowseEmpty<ChapterListFetchResult>).siteSuppliedSignal,
        'There is nothing here :(',
      );
    });

    test('⚠️ a typed failure stays TYPED, with its own retriability', () async {
      final (
        AppDatabase db,
        DriftChapterListRepository repo,
        Future<void> Function() close,
      ) = await harness();
      addTearDown(close);

      final BrowseOutcome<ChapterListFetchResult> outcome = await repo
          .fetchChapterListOnce(
            'n1',
            read: () async => const BrowseFailed<List<Never>>(
              SourceLayoutChanged(failedSelector: 'tr', status: 200),
              retriable: false,
            ),
          );

      expect(outcome, isA<BrowseFailed<ChapterListFetchResult>>());
      expect(
        (outcome as BrowseFailed<ChapterListFetchResult>).reason,
        isA<SourceLayoutChanged>(),
      );
      expect(outcome.retriable, isFalse);
    });

    test('⚠️ a MISSING read is a typed failure, not an empty list', () async {
      final (
        AppDatabase db,
        DriftChapterListRepository repo,
        Future<void> Function() close,
      ) = await harness();
      addTearDown(close);

      // ⚠️ **The repository was misconfigured**, which is not the site's fault — and it is still
      // typed, so the screen has one vocabulary rather than a second one for "the wiring is
      // wrong" and a third for "the site is broken".
      final BrowseOutcome<ChapterListFetchResult> outcome = await repo
          .fetchChapterListOnce('n1');

      expect(outcome, isA<BrowseFailed<ChapterListFetchResult>>());
      expect(
        (outcome as BrowseFailed<ChapterListFetchResult>).retriable,
        isFalse,
      );
    });

    test('⚠️ NO source THROWS a typed cause — the convention that holds today', () {
      // ⚠️ **The mirror of the repository's `on SourceFailure` arm.** `13-error-handling.md`: a
      // typed cause is RETURNED through an outcome, never thrown — and Dart's `only_throw_errors`
      // lint agrees, because `SourceFailure` is not an `Exception`. So the catch arm is
      // defence in depth, and this row is what keeps it defence: a future source that threw one
      // would be caught here rather than in a crash report nobody reads.
      //
      // ⚠️ **It walks `lib/` RECURSIVELY, and the walk is the row.** A single-level read found
      // nothing because `lib` is a directory, and `Directory.listSync(recursive: true)` is what
      // makes the claim mean something: a `throw` in `lib/sources/implementations/` is in
      // `lib/` too. A guard that only looks one level down is a guard that passes for the wrong
      // reason, which is the failure this project has already paid for once.
      final String code = Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((File f) => f.path.endsWith('.dart'))
          .map((File f) => f.readAsStringSync())
          .join('\n');

      expect(
        code,
        isNotEmpty,
        reason:
            'the walk found no Dart source at all, so it would have passed vacuously',
      );

      final RegExp thrownCause = RegExp(
        r'throw\s+(const\s+)?(NoConnection|SourceLayoutChanged|SourceUnavailable|'
        r'ItemRemovedAtSource|ParseFailed|RateLimited|CauseUnknown)\b',
      );
      expect(
        thrownCause.hasMatch(code),
        isFalse,
        reason: 'a typed cause is returned through an outcome, never thrown',
      );
    });
  });
}
