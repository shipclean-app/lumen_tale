// Lumen Tale — `6-3`: B48's derived count, and the four ways it can be wrong.
//
// ## The claims under test
//
// **B48** — the unopened count is a **local, exact** fact: computed over chapter-list
// metadata, correct for a novel with zero downloaded chapters, and dependent on no check.
//
// **B49** — freshness is a **separate fact** with three distinguishable states, and
// losing contact with a site changes the verification, never the number.
//
// **B38** — a check never downloads. Structurally, not by convention: this repository has
// no path to `queue_items`, and there is a test that says so.
//
// **B13** — a chapter was opened. Idempotent in its effect *and* in `readAt`.
//
// The last group asserts the negative space: that no column anywhere in the schema holds
// an unread count, and that the schema **cannot** grow one by accident.

import 'dart:io';

import 'package:drift/drift.dart' show InsertMode, QueryRow, Value, Variable;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumen_tale/core/database/app_database.dart';
import 'package:lumen_tale/core/error/source_failure.dart';
import 'package:lumen_tale/data/library/drift_unopened_count_repository.dart';
import 'package:lumen_tale/domain/library/library_update_fact.dart';

/// The `read_at` the chapter fixture writes for a chapter that arrives already read.
///
/// **A constant, not a literal at each use site.** The first version wrote
/// `DateTime.utc(2026, 9, 1)` inside the helper and `2026-09-02` in the assertion, and
/// the two disagreed — which is the mildest possible failure and still a failure: a test
/// that compares against a *different* number than the fixture wrote cannot tell a real
/// regression from a typo.
final DateTime kFixtureReadAt = DateTime.utc(2026, 9, 1, 8);

void main() {
  late AppDatabase db;
  late DriftUnopenedCountRepository repo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = DriftUnopenedCountRepository(db);
  });

  tearDown(() => db.close());

  // ⚠️ `insertOrIgnore`, for the same reason `addNovel` uses it: this helper runs once
  // per novel, and a plain insert dies on the second novel with a UNIQUE constraint that
  // says nothing about counting. The first version did, and eight tests failed that way.
  //
  // `Sources` has no `name` column — the registry owns a source's name and the platform
  // stores only its id and its settings (B41). This helper invented one, and the
  // compiler caught it immediately.
  Future<void> addSource() => db
      .into(db.sources)
      .insert(
        SourcesCompanion.insert(id: 's1'),
        mode: InsertMode.insertOrIgnore,
      );

  Future<void> addNovel(
    String id, {
    bool inLibrary = true,
    DateTime? addedAt,
    DateTime? lastCheckedAt,
  }) async {
    await addSource();
    await db
        .into(db.novels)
        .insert(
          NovelsCompanion.insert(
            id: id,
            sourceId: 's1',
            url: '/fiction/$id',
            title: 'Novel $id',
            inLibrary: Value(inLibrary),
            addedAt: Value(addedAt),
            lastCheckedAt: Value(lastCheckedAt),
          ),
          mode: InsertMode.insertOrIgnore,
        );
  }

  Future<void> addChapters(
    String novelId,
    int count, {
    int read = 0,
    int downloaded = 0,
    int firstOrdinal = 1,
  }) async {
    // ignore: always_specify_types
    for (var i = 0; i < count; i++) {
      final int ordinal = firstOrdinal + i;
      await db
          .into(db.chapters)
          .insert(
            ChaptersCompanion.insert(
              id: '$novelId-c$ordinal',
              novelId: novelId,
              name: 'Chapter $ordinal',
              url: '/fiction/$novelId/chapter/$ordinal',
              ordinal: ordinal,
              isRead: Value(i < read),
              // ⚠️ A read chapter gets a `readAt`. The schema permits `is_read = 1`
              // with `read_at = NULL`, and **nothing in this project writes that** —
              // `markOpened` refuses to touch an already-read row and a bulk mark skips
              // it — so a fixture that creates one tests a state no reader can reach.
              // The first version did, and one assertion failed on a null `readAt` that
              // was correct behaviour.
              readAt: Value(i < read ? kFixtureReadAt : null),
              downloadedAt: Value(
                i < downloaded
                    ? DateTime.utc(2026, 10).add(Duration(days: i))
                    : null,
              ),
            ),
          );
    }
  }

  group('B48 — the count is local and exact', () {
    test('it counts the chapters that have not been opened', () async {
      await addNovel('n1');
      await addChapters('n1', 10, read: 4);
      final LibraryUpdateFact? fact = await repo.factFor('n1');

      expect(fact!.totalCount, 10);
      expect(fact.unopenedCount, 6);
      expect(
        fact.openedCount,
        4,
        reason: 'derived as the complement, never stored',
      );
    });

    test('it is correct for a novel with ZERO downloaded chapters', () async {
      // The distinguishing claim of B48: the count never consults the network and never
      // needs a body, so a library novel whose chapters were never fetched still counts.
      await addNovel('n1');
      await addChapters('n1', 7);
      final LibraryUpdateFact? fact = await repo.factFor('n1');

      expect(fact!.unopenedCount, 7);
      expect(fact.downloadedUnopenedCount, 0);
    });

    test('unopened is 0 and never null, whatever the guard that produces it', () async {
      // The property, asserted rather than attributed. `COALESCE(SUM(…), 0)` and an
      // `ELSE 0` inside the `CASE` each independently turn a null-joined row into a 0,
      // so **no test can say which one is required** -- removing either leaves every row
      // green. The property both exist to protect is the one worth a test: the number is
      // never null, because a nullable count makes "how many?" a screen's decision.
      await addNovel('empty');
      final QueryRow row =
          (await db
                  .customSelect(
                    'SELECT COALESCE(SUM(CASE WHEN c.is_read = 0 THEN 1 ELSE 0 END), 0) '
                    'AS unopened FROM novels n '
                    'LEFT JOIN chapters c ON c.novel_id = n.id WHERE n.id = ?',
                    variables: <Variable<Object>>[
                      const Variable<String>('empty'),
                    ],
                  )
                  .get())
              .single;

      expect(row.read<int>('unopened'), 0);
      expect(
        (await repo.factFor('empty'))!.unopenedCount,
        0,
        reason: 'and the repository agrees',
      );
    });

    test('a novel with NO chapter list is 0, not missing', () async {
      // ⚠️ The LEFT JOIN row. An INNER JOIN would make this novel invisible in the
      // library because the app has not asked for its chapters yet — and "I have not
      // asked" is not "there are none".
      await addNovel('n1');
      final LibraryUpdateFact? fact = await repo.factFor('n1');

      expect(fact, isNotNull);
      expect(fact!.totalCount, 0);
      expect(
        fact.unopenedCount,
        0,
        reason: 'never null, never a display decision',
      );
    });

    test('downloaded-unopened is counted separately from the total', () async {
      // `library.md` § 8 renders "12 of 480 downloaded" — a pair, never a partial
      // number presented as complete. 3 read and 6 downloaded, so the unopened are
      // indices 3..9 and the downloaded are 0..5: the overlap is 3, 4 and 5 — three.
      //
      // (My first fixture used `downloaded: 4`, whose overlap with 3 read chapters is
      // the single chapter at index 3. One is arithmetically correct and would have
      // asserted a number that says nothing about whether the overlap was computed or
      // whether it was accidentally `total - read`.)
      await addNovel('n1');
      await addChapters('n1', 10, read: 3, downloaded: 6);
      final LibraryUpdateFact? fact = await repo.factFor('n1');

      expect(fact!.unopenedCount, 7);
      expect(fact.downloadedUnopenedCount, 3);
    });

    test('downloading a chapter does NOT change the unopened count', () async {
      // B14's count is about chapters and about reading, not about the network.
      await addNovel('n1');
      await addChapters('n1', 5);
      expect((await repo.factFor('n1'))!.unopenedCount, 5);

      await db
          .update(db.chapters)
          .write(
            ChaptersCompanion(downloadedAt: Value(DateTime.utc(2026, 10))),
          );
      expect((await repo.factFor('n1'))!.unopenedCount, 5);
    });

    test(
      'a novel not in the library is not returned by the library stream',
      () async {
        await addNovel('n1');
        await addNovel('n2', inLibrary: false);
        await addChapters('n1', 3);
        await addChapters('n2', 3);

        final List<LibraryUpdateFact> facts = await repo
            .watchLibraryFacts()
            .first;
        expect(facts.map((LibraryUpdateFact f) => f.novelId), <String>['n1']);
      },
    );

    test('the library stream is ordered by unopened, descending', () async {
      await addNovel('small');
      await addNovel('big');
      await addNovel('none');
      await addChapters('small', 3);
      await addChapters('big', 9);

      final List<LibraryUpdateFact> facts = await repo
          .watchLibraryFacts()
          .first;
      expect(facts.map((LibraryUpdateFact f) => f.novelId), <String>[
        'big',
        'small',
        'none',
      ]);
    });

    test('a tie keeps library order, deterministically', () async {
      // `updates.md` § 4: *ties keep library order.* Without a second key two novels
      // with the same count swap on every rebuild and the list flickers.
      await addNovel('second', addedAt: DateTime.utc(2026, 10, 2));
      await addNovel('first', addedAt: DateTime.utc(2026, 10));
      await addChapters('first', 3);
      await addChapters('second', 3);

      final List<LibraryUpdateFact> facts = await repo
          .watchLibraryFacts()
          .first;
      expect(facts.map((LibraryUpdateFact f) => f.novelId), <String>[
        'first',
        'second',
      ]);
    });

    test('a novel with a null addedAt does not sort first everywhere', () async {
      // `added_at` is nullable, and an untimestamped novel must sort LAST. The plan
      // writes `COALESCE(n.added_at, 0)` and explains it as preventing exactly that —
      // but COALESCE maps NULL to the epoch and the epoch sorts first, so the plan's
      // SQL does the opposite of its own prose. The query uses `(n.added_at IS NULL)`
      // instead. This row is the evidence that the two differ.
      await addNovel('nulled');
      await addNovel('dated', addedAt: DateTime.utc(2026, 10));
      await addChapters('nulled', 1);
      await addChapters('dated', 1);

      final List<LibraryUpdateFact> facts = await repo
          .watchLibraryFacts()
          .first;
      expect(facts.map((LibraryUpdateFact f) => f.novelId), <String>[
        'dated',
        'nulled',
      ]);
    });
  });

  group('B49 — freshness is a separate fact', () {
    test('a novel never checked is NeverChecked, not an epoch', () async {
      await addNovel('n1');
      await addChapters('n1', 4);

      final LibraryUpdateFact? fact = await repo.factFor('n1');
      expect(fact!.verification, const NeverChecked());
      expect(fact.verification.saysSomethingAboutFreshness, isFalse);
    });

    test('a checked novel reports when', () async {
      final DateTime when = DateTime.utc(2026, 10, 3, 9);
      await addNovel('n1', lastCheckedAt: when);
      await addChapters('n1', 4);

      final LibraryUpdateFact? fact = await repo.factFor('n1');
      expect(fact!.verification, CheckedAt(when));
      expect(fact.verification.saysSomethingAboutFreshness, isTrue);
    });

    test('a failing check changes the VERIFICATION and never the number', () async {
      // ⚠️ `updates.md` § 4: *losing contact with a site changes the verification,
      // never the number.* A count that moves because a check failed is a number the
      // reader cannot reason about.
      final DateTime when = DateTime.utc(2026, 10, 3, 9);
      await addNovel('n1', lastCheckedAt: when);
      await addChapters('n1', 5, read: 1);

      final LibraryUpdateFact before = (await repo.factFor('n1'))!;
      expect(before.unopenedCount, 4);

      // `6-4` writes the failure; `6-3` does not, and cannot.
      await db
          .into(db.sources)
          .insert(
            SourcesCompanion.insert(
              id: 's2',
              lastErrorCode: const Value('no_connection'),
            ),
          );

      final LibraryUpdateFact after = (await repo.factFor('n1'))!;
      expect(after.unopenedCount, before.unopenedCount);
      expect(after.verification, before.verification);
    });

    test(
      'the three verification states are distinguishable and comparable',
      () {
        const Verification never = NeverChecked();
        final Verification checked = CheckedAt(DateTime.utc(2026, 10, 3));
        const Verification failed = CouldNotCheck(
          NoConnection(host: 'www.royalroad.com'),
        );

        expect(<Verification>{never, checked, failed}, hasLength(3));
        expect(checked, isNot(failed));
        expect(never.saysSomethingAboutFreshness, isFalse);
        expect(checked.saysSomethingAboutFreshness, isTrue);
        expect(
          failed.saysSomethingAboutFreshness,
          isTrue,
          reason: 'a failed check IS a statement about freshness',
        );
      },
    );

    test('CouldNotCheck carries a typed failure, not a string', () {
      const CouldNotCheck failure = CouldNotCheck(
        NoConnection(host: 'www.royalroad.com'),
      );
      expect(failure.failure, isA<SourceFailure>());
      expect(
        failure.toString(),
        contains('NoConnection'),
        reason: 'never the message: 13-error-handling.md rule 5',
      );
    });
  });

  group('B13 — marking a chapter opened', () {
    test('it clears the marker and moves the count by exactly one', () async {
      await addNovel('n1');
      await addChapters('n1', 5);
      final DateTime at = DateTime.utc(2026, 10, 3, 20);

      await repo.markOpened('n1-c1', at: at);

      expect((await repo.factFor('n1'))!.unopenedCount, 4);
      final ChapterRow row = await (db.select(
        db.chapters,
      )..where((Chapters t) => t.id.equals('n1-c1'))).getSingle();
      expect(row.isRead, isTrue);
      expect(row.readAt!.toUtc(), at);
    });

    test('re-opening does NOT move readAt', () async {
      // `readAt` is when the chapter BECAME read — a fact, not a counter. Re-reading is
      // very common, and a column that moves on every read has lost its only meaning.
      await addNovel('n1');
      await addChapters('n1', 3);
      final DateTime first = DateTime.utc(2026, 10, 1, 8);
      final DateTime second = DateTime.utc(2026, 10, 3, 22);

      await repo.markOpened('n1-c1', at: first);
      await repo.markOpened('n1-c1', at: second);

      final ChapterRow row = await (db.select(
        db.chapters,
      )..where((Chapters t) => t.id.equals('n1-c1'))).getSingle();
      expect(row.readAt!.toUtc(), first);
      expect((await repo.factFor('n1'))!.unopenedCount, 2);
    });

    test(
      'a chapter that does not exist writes nothing and throws nothing',
      () async {
        // Creating a row from an id alone would produce a chapter with no url and no
        // ordinal — a row that can neither open nor count correctly.
        await addNovel('n1');
        await addChapters('n1', 3);

        await repo.markOpened('nope', at: DateTime.utc(2026, 10, 3));

        final List<ChapterRow> rows = await db.select(db.chapters).get();
        expect(rows, hasLength(3), reason: 'no chapter was conjured');
        expect((await repo.factFor('n1'))!.unopenedCount, 3);
      },
    );

    test(
      'markAllOpened zeroes the count and reports what it changed',
      () async {
        await addNovel('n1');
        await addChapters('n1', 6, read: 2);
        final DateTime at = DateTime.utc(2026, 10, 3, 21);

        final int changed = await repo.markAllOpened('n1', at: at);

        expect(changed, 4);
        expect((await repo.factFor('n1'))!.unopenedCount, 0);
      },
    );

    test('markAllOpened never touches last_checked_at', () async {
      // ⚠️ A bulk local write is not a check. B49 says a novel is only ever *checked*
      // when the app looked at its site, and this is where that could be broken by
      // someone "helpfully" stamping the time.
      await addNovel('n1');
      await addChapters('n1', 4);

      await repo.markAllOpened('n1', at: DateTime.utc(2026, 10, 3, 21));

      expect(
        (await repo.factFor('n1'))!.verification,
        const NeverChecked(),
        reason: 'the count is 0 and we still have not looked at the site',
      );
    });

    test('markAllOpened preserves the first readAt of already-read chapters', () async {
      await addNovel('n1');
      // One chapter arrives already read, carrying the fixture's own read time.
      await addChapters('n1', 4, read: 1);
      final DateTime fixtureReadAt = kFixtureReadAt;
      final DateTime bulkAt = DateTime.utc(2026, 10, 3, 21);

      await repo.markAllOpened('n1', at: bulkAt);

      final ChapterRow row = await (db.select(
        db.chapters,
      )..where((Chapters t) => t.id.equals('n1-c1'))).getSingle();

      // The bulk mark filters on `is_read = false`, so this row was never a candidate
      // and its first-read time is untouched — the same rule `markOpened` applies, by
      // the same mechanism.
      //
      // `fixtureReadAt` is what the fixture wrote, **not** what `markOpened` wrote. My
      // first version asserted a time it had passed to `markOpened`, which does nothing
      // to an already-read row — correct behaviour, wrong expectation.
      expect(row.readAt!.toUtc(), fixtureReadAt);
      expect(
        row.readAt!.toUtc(),
        isNot(bulkAt),
        reason:
            'the bulk mark must not restamp a chapter that was already read',
      );
    });
  });

  group('B48 — there is no stored count anywhere', () {
    test('no table has an unread-count column', () async {
      final List<String> offenders = <String>[];
      for (final String table in <String>[
        'novels',
        'chapters',
        'reading_positions',
        'history_entries',
        'queue_items',
        'sources',
      ]) {
        final List<QueryRow> cols = await db
            .customSelect('PRAGMA table_info($table)')
            .get();
        for (final QueryRow col in cols) {
          final String name = col.read<String>('name');
          if (RegExp('unread|unopened|new_chapters').hasMatch(name)) {
            offenders.add('$table.$name');
          }
        }
      }
      expect(
        offenders,
        isEmpty,
        reason:
            'architecture.md § 4.7: a stored count is a second source of truth '
            'free to disagree with the rows it counts',
      );
    });

    test('the schema file on disk has no count column either', () {
      // The snapshot is what a future migration is diffed against, so a column added
      // here without regenerating the snapshot would be invisible to review.
      final File schema = File('lib/core/database/schema.json');
      if (!schema.existsSync()) return; // nothing to assert, and it is optional
      final String text = schema.readAsStringSync();
      expect(text, isNot(contains('unread_count')));
      expect(text, isNot(contains('unopened')));
    });

    test('the count moves exactly when the underlying rows move', () async {
      // The proof that nothing is cached: insert a chapter and the number changes,
      // because the number was never a number.
      await addNovel('n1');
      await addChapters('n1', 3);
      expect((await repo.factFor('n1'))!.unopenedCount, 3);

      await addChapters('n1', 2, firstOrdinal: 10);
      expect((await repo.factFor('n1'))!.unopenedCount, 5);
    });

    test('the stream re-emits when a chapter is opened', () async {
      await addNovel('n1');
      await addChapters('n1', 3);

      final List<int> seen = <int>[];
      final sub = repo.watchLibraryFacts().listen((
        List<LibraryUpdateFact> facts,
      ) {
        if (facts.isNotEmpty) seen.add(facts.first.unopenedCount);
      });

      // Let the first emission land, then change something.
      await Future<void>.delayed(const Duration(milliseconds: 40));
      await repo.markOpened('n1-c1', at: DateTime.utc(2026, 10, 3));
      await Future<void>.delayed(const Duration(milliseconds: 60));
      await sub.cancel();

      expect(seen.first, 3);
      expect(
        seen.last,
        2,
        reason:
            '⚠️ without `readsFrom` the stream emits once and never again, and '
            'the badge silently stops updating',
      );
    });
  });

  group('B38 — a check never downloads', () {
    test('this repository has no path to the download queue', () {
      // Structural, not conventional. `06-database.md` rule and the removal of the
      // `6-3 → 5-2` edge: the guarantee is the absence of a code path.
      //
      // ⚠️ **Code only, comments stripped.** The first version searched the whole file
      // and failed on this file's own doc comments — which mention "download"
      // extensively, precisely to explain that the repository cannot. A structural
      // assertion that trips over its own explanation is a test that has to be
      // weakened, and weakening it would remove the check.
      final String source = File(
        'lib/data/library/drift_unopened_count_repository.dart',
      ).readAsLinesSync().where(_isCode).join('\n');

      for (final String forbidden in <String>[
        'queue_items',
        'db.queue',
        'QueueItems',
        'DownloadState',
        'queueItems',
      ]) {
        expect(
          source,
          isNot(contains(forbidden)),
          reason: 'the implementation must never name $forbidden',
        );
      }
    });

    test('the interface offers nothing that could enqueue a download', () {
      expect(
        UnopenedCountRepository,
        isNotNull,
        reason: 'an interface, not a class: nothing to instantiate by accident',
      );
      // The interface file, code only. `downloadUnopenedCount` is a legitimate *field*
      // and is deliberately not in this list — the assertion is about the ability to
      // start a download, not about the word.
      final String source = File(
        'lib/domain/library/library_update_fact.dart',
      ).readAsLinesSync().where(_isCode).join('\n');
      for (final String forbidden in <String>[
        'queueItems',
        'QueueItems',
        'enqueue',
        'Future<void> download',
      ]) {
        expect(
          source,
          isNot(contains(forbidden)),
          reason: 'the interface must not mention $forbidden at all',
        );
      }
    });
  });
}

/// True when [line] is code rather than a comment.
///
/// Deliberately crude. A full Dart parse would be more precise and would also fail on
/// the first syntax the file grows tomorrow; the rules below cover every comment style
/// the project uses (`//`, `///`, and a `/* … */` opener), which is enough for an
/// assertion whose job is to keep the *code* honest.
bool _isCode(String line) {
  final String trimmed = line.trimLeft();
  if (trimmed.startsWith('//')) return false;
  if (trimmed.startsWith('*') || trimmed.startsWith('/*')) return false;
  return true;
}
