// Lumen Tale — `2-5`: the library over a REAL database, because B32 is about the schema.
//
// ## Why this uses drift and not a fake store
//
// The whole of B32 is a **schema** claim: `chapters.novelId` is `ON DELETE CASCADE` and
// `history_entries.novelId` is `ON DELETE RESTRICT`. A fake repository cannot show that a
// `DELETE` would erase chapter rows and would *fail* once a chapter has been opened — the two
// facts that make an UPDATE the only option. So every row here runs against
// `NativeDatabase.memory()` with the real migrations.

import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lumen_tale/core/database/app_database.dart';
import 'package:lumen_tale/data/library/drift_library_repository.dart';
import 'package:lumen_tale/domain/library/library_entry.dart';
import 'package:lumen_tale/domain/library/library_repository.dart';
import 'package:lumen_tale/domain/library/similar_title.dart';
import 'package:lumen_tale/domain/sources/models/novel.dart';

/// ⚠️ **One named instant, used by every seeded row.**
///
/// A literal repeated in ten places is ten chances for two rows to disagree about when a
/// download happened, and the rows that compare two of them would then be testing a
/// coincidence. A single name also keeps the interrupted-download cases (where the argument
/// is omitted) visibly different from the marked ones at every call site.
///
/// ⚠️ **The hour is not decoration.** `DateTime`'s `day` parameter defaults to `1`, so
/// `DateTime(2026, 10, 1)` passes a redundant argument — and a lint that fires on it would be
/// right about the literal and wrong about the intent. Naming an hour says "a download at nine
/// in the morning" rather than "a day whose number happens to match a default".
final DateTime markedAt = DateTime(2026, 10, 1, 9);

/// One database per row, so a row cannot pass because of another's writes.
Future<AppDatabase> openDatabase() async {
  return AppDatabase.forTesting(NativeDatabase.memory());
}

Novel novel({
  String id = 'n1',
  String title = 'The Rune Smith',
  String url = 'https://www.royalroad.com/fiction/1/x',
  String sourceId = 'royalroad',
  String? author = 'An Author',
}) {
  return Novel(
    id: id,
    sourceId: sourceId,
    title: title,
    url: url,
    author: author,
    coverUrl: null,
    description: 'A description the site published.',
    genres: const <String>[],
    status: NovelStatus.ongoing,
  );
}

DriftLibraryRepository repositoryOver(AppDatabase db) {
  return DriftLibraryRepository(
    db,
    sourceNameOf: (String id) => id == 'royalroad' ? 'Royal Road' : 'FanMTL',
  );
}

/// Puts a novel in the library, whatever the repository decides.
Future<void> seed(AppDatabase db, Novel n) {
  return repositoryOver(db)
      .addFromCatalogue(
        novel: n,
        onSimilarTitle: (_) async => SimilarTitleVerdict.addAnyway,
      )
      .then((_) {});
}

Never askAboutSimilar(List<SimilarTitle> _) =>
    throw StateError('this row must not reach the similar-title dialog');

void main() {
  group('B12 — the add, and its two guards', () {
    test('a novel is added, and carries its source and title verbatim', () async {
      final AppDatabase db = await openDatabase();
      addTearDown(db.close);

      final AddOutcome outcome = await repositoryOver(
        db,
      ).addFromCatalogue(novel: novel(), onSimilarTitle: askAboutSimilar);

      expect(outcome.isAdded, isTrue);
      final List<LibraryEntry> entries = await repositoryOver(
        db,
      ).watchLibrary().first;
      expect(entries, hasLength(1));
      expect(entries.single.title, 'The Rune Smith');
      expect(entries.single.sourceName, 'Royal Road');
      // ⚠️ **B49: `lastCheckedAt` stays null.** Browsing a catalogue is not a check of this
      // novel, and writing `now()` would claim a check that never happened.
      expect(entries.single.lastCheckedAt, isNull);
    });

    test('⚠️ an EMPTY title is rejected with ZERO writes', () async {
      final AppDatabase db = await openDatabase();
      addTearDown(db.close);

      final AddOutcome outcome = await repositoryOver(db).addFromCatalogue(
        novel: novel(title: '   '),
        onSimilarTitle: askAboutSimilar,
      );

      expect(outcome.rejection, AddRejection.emptyTitle);
      expect(await repositoryOver(db).watchLibrary().first, isEmpty);
    });

    test(
      '⚠️ an EMPTY url is rejected — there would be nothing to reopen',
      () async {
        final AppDatabase db = await openDatabase();
        addTearDown(db.close);

        final AddOutcome outcome = await repositoryOver(db).addFromCatalogue(
          novel: novel(url: ''),
          onSimilarTitle: askAboutSimilar,
        );

        expect(outcome.rejection, AddRejection.emptyTitle);
        expect(await repositoryOver(db).watchLibrary().first, isEmpty);
      },
    );

    test(
      '⚠️ B11: a second add is IDEMPOTENT — no error, and no second row',
      () async {
        // ⚠️ **Keeping and following are one act**, so a second tap is a no-op rather than a
        // failure — and it must not produce a second row either.
        final AppDatabase db = await openDatabase();
        addTearDown(db.close);
        final DriftLibraryRepository repository = repositoryOver(db);

        await repository.addFromCatalogue(
          novel: novel(),
          onSimilarTitle: askAboutSimilar,
        );
        final AddOutcome second = await repository.addFromCatalogue(
          novel: novel(),
          onSimilarTitle: askAboutSimilar,
        );

        expect(second.isAdded, isTrue);
        expect(second.wasAlreadyInLibrary, isTrue);
        expect(await repository.watchLibrary().first, hasLength(1));
      },
    );
  });

  group('B40 — the similar-title warning comes BEFORE any write', () {
    test('a matching title warns, and declining writes nothing', () async {
      final AppDatabase db = await openDatabase();
      addTearDown(db.close);
      final DriftLibraryRepository repository = repositoryOver(db);
      await seed(db, novel(id: 'a'));

      List<SimilarTitle> offered = const <SimilarTitle>[];
      final AddOutcome outcome = await repository.addFromCatalogue(
        novel: novel(id: 'b', title: 'the rune smith!'),
        onSimilarTitle: (List<SimilarTitle> similar) async {
          offered = similar;
          return SimilarTitleVerdict.declined;
        },
      );

      expect(offered, hasLength(1));
      expect(
        offered.single.existingTitle,
        'The Rune Smith',
        reason: 'the SITE title, never the normalised key',
      );
      expect(offered.single.existingSourceName, 'Royal Road');
      expect(outcome.rejection, AddRejection.declinedForSimilarTitle);
      expect(
        await repository.watchLibrary().first,
        hasLength(1),
        reason: 'the declined add wrote nothing',
      );
    });

    test(
      '⚠️ DISMISSING the dialog is declining — the default must be safe',
      () async {
        // ⚠️ **The easiest gesture on a device with no cloud backup (C8) must not be the one
        // that adds a second copy of a novel the reader already has.**
        final AppDatabase db = await openDatabase();
        addTearDown(db.close);
        final DriftLibraryRepository repository = repositoryOver(db);
        await seed(db, novel(id: 'a'));

        final AddOutcome outcome = await repository.addFromCatalogue(
          novel: novel(id: 'b'),
          onSimilarTitle: (_) async => SimilarTitleVerdict.dismissed,
        );

        expect(outcome.rejection, AddRejection.declinedForSimilarTitle);
        expect(await repository.watchLibrary().first, hasLength(1));
      },
    );

    test(
      '⚠️ "add anyway" produces a SECOND row — nothing is ever merged',
      () async {
        final AppDatabase db = await openDatabase();
        addTearDown(db.close);
        final DriftLibraryRepository repository = repositoryOver(db);
        await seed(db, novel(id: 'a'));

        final AddOutcome outcome = await repository.addFromCatalogue(
          novel: novel(id: 'b'),
          onSimilarTitle: (_) async => SimilarTitleVerdict.addAnyway,
        );

        expect(outcome.isAdded, isTrue);
        expect(outcome.addedDespiteSimilarTitle, isTrue);
        final List<LibraryEntry> entries = await repository
            .watchLibrary()
            .first;
        expect(entries, hasLength(2), reason: 'B40: nothing is merged');
        expect(entries.map((LibraryEntry e) => e.id).toSet(), <String>{
          'a',
          'b',
        });
      },
    );

    test('⚠️ a REMOVED novel does not collide with the next add', () async {
      // ⚠️ **The filter is `inLibrary = true`.** A removed novel occupies no space, and B32
      // says it can be put back without hindrance — so it must not occupy the collision slot
      // of somebody else's add.
      final AppDatabase db = await openDatabase();
      addTearDown(db.close);
      final DriftLibraryRepository repository = repositoryOver(db);
      await seed(db, novel(id: 'a'));
      await repository.removeFromLibrary('a');

      final AddOutcome outcome = await repository.addFromCatalogue(
        novel: novel(id: 'b'),
        onSimilarTitle: askAboutSimilar,
      );

      expect(
        outcome.isAdded,
        isTrue,
        reason: 'no dialog: the removed entry is not a candidate',
      );
    });

    test('⚠️ the comparison is EQUALITY, not a substring test', () async {
      // ⚠️ A substring test would call "The Rune Smith" and "The Rune Smith Returns" the same
      // novel and warn about a collision that does not exist — which trains a reader to
      // dismiss the warning, and a dismissed warning protects nobody.
      final AppDatabase db = await openDatabase();
      addTearDown(db.close);
      final DriftLibraryRepository repository = repositoryOver(db);
      await seed(db, novel(id: 'a'));

      bool asked = false;
      await repository.addFromCatalogue(
        novel: novel(id: 'b', title: 'The Rune Smith Returns'),
        onSimilarTitle: (_) async {
          asked = true;
          return SimilarTitleVerdict.addAnyway;
        },
      );

      expect(asked, isFalse);
    });
  });

  group('B32 — the removal is an UPDATE, and deletes nothing', () {
    test('⚠️ chapter rows SURVIVE the removal', () async {
      // ⚠️ **The row the whole slice turns on.** `DELETE FROM novels` would CASCADE these away,
      // and with them the metadata B14/B48 count.
      final AppDatabase db = await openDatabase();
      addTearDown(db.close);
      await seed(db, novel());
      await _seedChapter(db, 'c1', isRead: false);

      await repositoryOver(db).removeFromLibrary('n1');

      final List<ChapterRow> survivors = await db.select(db.chapters).get();
      expect(survivors, hasLength(1), reason: 'B32: the chapter list survives');
    });

    test('⚠️ history and reading positions SURVIVE the removal', () async {
      // ⚠️ **B32: "the record of what was read survives that too", and B46: a position is never
      // cut by any retention rule.** A `DELETE` would also *fail* here, because
      // `history_entries.novelId` is `ON DELETE RESTRICT`.
      final AppDatabase db = await openDatabase();
      addTearDown(db.close);
      await seed(db, novel());
      await _seedChapter(db, 'c1', isRead: true, downloadedAt: markedAt);
      await _seedHistory(db, 'h1');
      await _seedPosition(db, 'c1');

      await repositoryOver(db).removeFromLibrary('n1');

      expect(await db.select(db.historyEntries).get(), hasLength(1));
      expect(await db.select(db.readingPositions).get(), hasLength(1));
    });

    test('⚠️ the removal writes inLibrary = false and nulls addedAt', () async {
      // ⚠️ **`addedAt = null` while `inLibrary` is false**, per `architecture.md` § 4.1.
      final AppDatabase db = await openDatabase();
      addTearDown(db.close);
      await seed(db, novel());

      await repositoryOver(db).removeFromLibrary('n1');

      final NovelRow row = await db.select(db.novels).getSingle();
      expect(row.inLibrary, isFalse);
      expect(row.addedAt, isNull);
      expect(await repositoryOver(db).watchLibrary().first, isEmpty);
    });

    test(
      '⚠️ the downloaded count is returned, and read BEFORE the write',
      () async {
        final AppDatabase db = await openDatabase();
        addTearDown(db.close);
        await seed(db, novel());
        await _seedChapter(db, 'c1', isRead: false, downloadedAt: markedAt);
        await _seedChapter(
          db,
          'c2',
          isRead: false,
          downloadedAt: DateTime(2026, 10, 2),
        );
        await _seedChapter(db, 'c3', isRead: false);

        final RemoveOutcome outcome = await repositoryOver(
          db,
        ).removeFromLibrary('n1');

        // ⚠️ **Two, not three.** The interrupted download has no mark (E6, ADR-022), so it is not
        // downloaded — a file-existence probe would have counted it.
        expect(outcome.downloadedChapterCount, 2);
        expect(outcome.wasAlreadyRemoved, isFalse);
      },
    );

    test(
      '⚠️ NO `if (downloadedCount > 0)` branch exists — the trap is the branch',
      () async {
        // ⚠️ **The absence, asserted from the source.** An implementation in a hurry adds one,
        // and that branch is what makes a removal silently delete downloads. The number above
        // proves the count is *used*; this proves it is only used to report.
        final String code = _codeOf(
          'lib/data/library/drift_library_repository.dart',
        );
        expect(
          code,
          isNot(contains('delete(')),
          reason:
              'B32: nothing is deleted — a DELETE would CASCADE and RESTRICT-fail',
        );
        expect(code, isNot(contains('downloads')));
      },
    );

    test(
      'a REMOVED novel is already removed — idempotent, no second confirmation',
      () async {
        final AppDatabase db = await openDatabase();
        addTearDown(db.close);
        final DriftLibraryRepository repository = repositoryOver(db);
        await seed(db, novel());

        await repository.removeFromLibrary('n1');
        final RemoveOutcome second = await repository.removeFromLibrary('n1');

        expect(second.wasAlreadyRemoved, isTrue);
      },
    );

    test(
      'an ABSENT id throws LibraryEntryAbsent, not a storage failure',
      () async {
        // ⚠️ **A stale identifier in a restored navigation stack is a state of the world**, and
        // it must not be reported as the database failing.
        final AppDatabase db = await openDatabase();
        addTearDown(db.close);

        await expectLater(
          repositoryOver(db).removeFromLibrary('nope'),
          throwsA(isA<LibraryEntryAbsent>()),
        );
      },
    );

    test('⚠️ restore brings the entry back, with addedAt = NOW', () async {
      // ⚠️ **`addedAt` becomes NOW, not the previous value** — § 4.1 required it to be nulled on
      // removal, so the old instant is gone. The consequence is named rather than discovered:
      // after a remove-and-restore the novel sorts as *recently added*. No rule says
      // otherwise, and saying so here is worth more than finding out.
      final AppDatabase db = await openDatabase();
      addTearDown(db.close);
      final DriftLibraryRepository repository = repositoryOver(db);
      await seed(db, novel());
      await repository.removeFromLibrary('n1');
      await _seedChapter(db, 'c1', isRead: false, downloadedAt: markedAt);

      await repository.restoreToLibrary('n1');

      final List<LibraryEntry> entries = await repository.watchLibrary().first;
      expect(entries, hasLength(1));
      expect(entries.single.addedAt, isNotNull);
      // ⚠️ **And the chapter row is still there** — "undo" restores the entry and nothing
      // else, because the removal destroyed nothing.
      expect(await db.select(db.chapters).get(), hasLength(1));
    });
  });

  group('B14 / B48 — the counts are derived, and exact', () {
    test('unopened counts only DOWNLOADED unread chapters', () async {
      // ⚠️ **A chapter that is not on the phone cannot be opened**, so counting unread
      // chapters of an undownloaded novel would put a badge on a tile whose contents the
      // reader does not have.
      final AppDatabase db = await openDatabase();
      addTearDown(db.close);
      await seed(db, novel());
      await _seedChapter(db, 'c1', isRead: false, downloadedAt: markedAt);
      await _seedChapter(db, 'c2', isRead: false);
      await _seedChapter(db, 'c3', isRead: true, downloadedAt: markedAt);

      final LibraryEntry entry = (await repositoryOver(
        db,
      ).watchLibrary().first).single;

      expect(entry.unopenedCount, 1);
      expect(entry.downloadedCount, 2);
      expect(entry.chapterCount, 3);
    });

    test('the library is ordered by addedAt, newest first', () async {
      final AppDatabase db = await openDatabase();
      addTearDown(db.close);
      await seed(db, novel(id: 'a', title: 'First'));
      await seed(db, novel(id: 'b', title: 'Second'));

      // ⚠️ **`addedAt` is written EXPLICITLY, and the reason is a resolution finding.**
      //
      // drift stores a SQLite `DateTime` as **Unix seconds**, so two novels added in the same
      // second have byte-identical `addedAt` columns. Waiting for the next second in a test
      // would make the whole suite a second slower to assert something the column cannot
      // express — so the row sets the instants it needs.
      //
      // And that makes the tiebreaker the NORMAL case rather than an edge one, which is why
      // `id` is in the ORDER BY at all.
      await _setAddedAt(db, 'a', DateTime(2026, 10, 1, 9));
      await _setAddedAt(db, 'b', DateTime(2026, 10, 2, 9));

      final List<LibraryEntry> entries = await repositoryOver(
        db,
      ).watchLibrary().first;
      expect(entries.map((LibraryEntry e) => e.id), <String>['b', 'a']);
    });

    test('⚠️ an equal addedAt still gives a DETERMINISTIC order', () async {
      // ⚠️ **Two adds in the same millisecond have an EQUAL `addedAt`**, and a sort with a
      // tie returns whatever order the engine happens to produce — which can differ between
      // two reads of the same database. A library whose order shifts when nothing changed is
      // a library a reader cannot find anything in, so `id` is the tiebreaker.
      final AppDatabase db = await openDatabase();
      addTearDown(db.close);
      await seed(db, novel(id: 'a', title: 'First'));
      await seed(db, novel(id: 'b', title: 'Second'));

      final DriftLibraryRepository repository = repositoryOver(db);
      final List<String> first = (await repository.watchLibrary().first)
          .map((LibraryEntry e) => e.id)
          .toList();
      final List<String> second = (await repository.watchLibrary().first)
          .map((LibraryEntry e) => e.id)
          .toList();

      expect(first, second, reason: 'the same rows, read twice');
      expect(first, <String>[
        'a',
        'b',
      ], reason: 'the tiebreaker is the id, ascending');
    });
  });

  group('the repository cannot reach the network', () {
    test('⚠️ no network capability in the library', () async {
      final String code =
          _codeOf('lib/domain/library/library_repository.dart') +
          _codeOf('lib/domain/library/library_entry.dart') +
          _codeOf('lib/domain/library/similar_title.dart');

      expect(code, isNot(contains('core/network')));
      expect(code, isNot(contains('dio')));
      expect(code, isNot(contains('HttpClient')));
      expect(code, isNot(contains('SourceManager')));
    });
  });

  group('normalizeForSimilarity', () {
    test('case, punctuation, spacing and accents all collapse', () {
      // ⚠️ **"The Rune-Smith", "the rune smith" and "The Runesmith!" are one title to a reader
      // and three strings to the database.**
      expect(normalizeForSimilarity('The Rune Smith'), 'therunesmith');
      expect(normalizeForSimilarity('the rune smith'), 'therunesmith');
      expect(normalizeForSimilarity('The Rune-Smith'), 'therunesmith');
      expect(normalizeForSimilarity('  The   Rune   Smith  '), 'therunesmith');
      // ⚠️ **Accents are FOLDED, not dropped from the alphabet** — a reader comparing two
      // titles does not see an accent as a distinction.
      expect(
        normalizeForSimilarity('The Rêverie'),
        normalizeForSimilarity('The Reverie'),
      );
    });

    test('a different title is a different key', () {
      expect(
        normalizeForSimilarity('The Rune Smith'),
        isNot(normalizeForSimilarity('The Rune Smith Returns')),
      );
    });

    test('an empty and a punctuation-only title both normalise to empty', () {
      expect(normalizeForSimilarity(''), isEmpty);
      expect(normalizeForSimilarity('!!!'), isEmpty);
    });
  });
}

///
/// A chapter row with the given read and mark state.
Future<void> _seedChapter(
  AppDatabase db,
  String id, {
  required bool isRead,

  /// **Omitting it means "never downloaded"** — the interrupted-download case E6 describes,
  /// and the one the count rows below depend on.
  DateTime? downloadedAt,
}) {
  return db
      .into(db.chapters)
      .insert(
        ChaptersCompanion.insert(
          id: id,
          novelId: 'n1',
          name: 'Chapter $id',
          url: '/fiction/1/x/chapter/$id/x',
          ordinal: 1,
          isRead: Value(isRead),
          readAt: Value(isRead ? downloadedAt : null),
          downloadedAt: Value(downloadedAt),
        ),
      );
}

/// Sets a novel's `addedAt`, so an ordering row does not depend on the clock.
Future<void> _setAddedAt(AppDatabase db, String novelId, DateTime at) {
  return (db.update(db.novels)..where(($NovelsTable t) => t.id.equals(novelId)))
      .write(NovelsCompanion(addedAt: Value<DateTime?>(at)));
}

Future<void> _seedHistory(AppDatabase db, String id) {
  return db
      .into(db.historyEntries)
      .insert(
        HistoryEntriesCompanion.insert(
          id: id,
          chapterId: 'c1',
          novelId: 'n1',
          openedAt: markedAt,
        ),
      );
}

Future<void> _seedPosition(AppDatabase db, String chapterId) {
  return db
      .into(db.readingPositions)
      .insert(
        ReadingPositionsCompanion.insert(
          chapterId: chapterId,
          offset: const Value<double>(120),
          updatedAt: markedAt,
        ),
      );
}

/// A source file with its comments removed.
String _codeOf(String path) {
  return File(path)
      .readAsStringSync()
      .split('\n')
      .where((String line) => !line.trimLeft().startsWith('//'))
      .join('\n');
}
