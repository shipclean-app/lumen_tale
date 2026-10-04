// forge:slice 3-2
// Lumen Tale — `readNovel`: the stored row as the `Novel` `3-2`'s action row adds.
//
// ## Why this file exists
//
// `addFromCatalogue` takes a source-domain `Novel`, and a details screen reached from
// History — where the novel *is* stored — had no way to produce one. `readNovel` closes
// that. Two of its decisions are judgement calls, and judgement calls that are only
// written down are not made:
//
// | decision | the row |
// |---|---|
// | `genres` is EMPTY, never reconstructed | *a stored novel carries no genres, and inventing one costs a network call* |
// | the stored `status` is empty in practice | *`''` becomes `unknown` and never throws* |
// | an absent novel is `null`, not an exception | *a stale identifier is a state of the world* |
// | the round trip keeps everything `addFromCatalogue` reads | *title, url and id survive* |

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumen_tale/core/database/app_database.dart';
import 'package:lumen_tale/data/library/drift_library_repository.dart';
import 'package:lumen_tale/domain/library/similar_title.dart';
import 'package:lumen_tale/domain/sources/models/novel.dart';

Future<(AppDatabase, DriftLibraryRepository, Future<void> Function())>
harness() async {
  final AppDatabase db = AppDatabase.forTesting(NativeDatabase.memory());
  return (db, DriftLibraryRepository(db), db.close);
}

/// The novel `addFromCatalogue` would have been given from the catalogue.
Novel fromCatalogue({
  String id = 'n1',
  String title = 'The Rune Smith',
  NovelStatus status = NovelStatus.ongoing,
}) => Novel(
  id: id,
  sourceId: 'rr',
  url: '/fiction/1/$id',
  title: title,
  author: 'A. Writer',
  description: 'A novel about runes.',
  status: status,
  coverUrl: '/cover/$id.png',
  genres: const <String>['fantasy', 'progression'],
);

void main() {
  group('readNovel — what comes back', () {
    testWidgets('⚠️ a stored novel round-trips the fields the ADD path reads', (
      WidgetTester tester,
    ) async {
      final (
        AppDatabase db,
        DriftLibraryRepository repo,
        Future<void> Function() close,
      ) = await harness();
      addTearDown(close);

      await repo.addFromCatalogue(
        novel: fromCatalogue(),
        onSimilarTitle: (_) async => SimilarTitleVerdict.addAnyway,
      );

      final Novel? read = await repo.readNovel('n1');

      expect(read, isNotNull);
      // ⚠️ **THE FOUR `addFromCatalogue` ACTUALLY GUARDS ON.** It rejects an empty title and
      // an empty url, and keys everything else on the id — so a read that lost any of the
      // three would return a novel the add path then refuses, which is a defect that would
      // only show up as "adding does nothing".
      expect(read!.id, 'n1', reason: 'B3 — the id is the key for everything');
      expect(
        read.title,
        'The Rune Smith',
        reason: 'an empty title is REJECTED by the add',
      );
      expect(
        read.url,
        '/fiction/1/n1',
        reason: 'an empty url is REJECTED by the add',
      );
      expect(
        read.author,
        'A. Writer',
        reason:
            'and the author survives, because a card with no author is a worse card',
      );
    });

    testWidgets('⚠️ GENRES ARE EMPTY — the table has no column, and inventing one costs a '
        'network call', (WidgetTester tester) async {
      final (
        AppDatabase db,
        DriftLibraryRepository repo,
        Future<void> Function() close,
      ) = await harness();
      addTearDown(close);

      await repo.addFromCatalogue(
        novel: fromCatalogue(),
        onSimilarTitle: (_) async => SimilarTitleVerdict.addAnyway,
      );

      final Novel? read = await repo.readNovel('n1');

      // ⚠️ **The source had two genres and the stored novel has none.** That is the honest
      // answer, and the reason is the one that matters: `genres` is a DISCOVERY hint, the
      // `novels` table has no column for it, and nothing in the library ever filters by
      // genre. Recovering it would mean re-fetching the site — which is B5's exact
      // prohibition on a read path.
      expect(
        read!.genres,
        isEmpty,
        reason:
            'this app does not know the genres of a novel it has already stored, and must '
            'not spend a network call to find out on a screen the reader already opened',
      );
    });

    // ⚠️ **THIS ROW IS THE ONE A `values.byName` PARSER WOULD FAIL.** `addFromCatalogue`
    // never writes `status`, so the column holds its default `''`, and
    // `NovelStatus.values.byName('')` throws. `13-error-handling.md` says a typed value is
    // returned rather than thrown, and `NovelStatus.unknown` is documented as "the site
    // published no status" — which is precisely the case for every stored row.
    testWidgets(
      '⚠️ the stored status is `\'\'` and it becomes UNKNOWN, never a throw',
      (WidgetTester tester) async {
        final (
          AppDatabase db,
          DriftLibraryRepository repo,
          Future<void> Function() close,
        ) = await harness();
        addTearDown(close);

        await repo.addFromCatalogue(
          novel: fromCatalogue(status: NovelStatus.cancelled),
          onSimilarTitle: (_) async => SimilarTitleVerdict.addAnyway,
        );

        final Novel? read = await repo.readNovel('n1');

        expect(
          read!.status,
          NovelStatus.unknown,
          reason:
              'the source said CANCELLED and the row says "" — because `addFromCatalogue` '
              'never writes status at all. Reading it back must not throw on the empty '
              'string, and must not claim the site said "unknown" either: it said nothing, '
              'which is what `unknown` documents',
        );
      },
    );

    testWidgets('⚠️ an ABSENT novel is null, not an exception', (
      WidgetTester tester,
    ) async {
      final (
        AppDatabase db,
        DriftLibraryRepository repo,
        Future<void> Function() close,
      ) = await harness();
      addTearDown(close);

      expect(
        await repo.readNovel('never-stored'),
        isNull,
        reason:
            'a stale deep link and a restored stack are STATES OF THE WORLD. Throwing here '
            'would make a reachable route crash, and `getSingle()` is exactly the call '
            'that would have done it',
      );
    });
  });

  group('readNovel — and the state B12 depends on', () {
    testWidgets('⚠️ reading a novel REMOVED from the library still returns it', (
      WidgetTester tester,
    ) async {
      final (
        AppDatabase db,
        DriftLibraryRepository repo,
        Future<void> Function() close,
      ) = await harness();
      addTearDown(close);

      await repo.addFromCatalogue(
        novel: fromCatalogue(),
        onSimilarTitle: (_) async => SimilarTitleVerdict.addAnyway,
      );
      await repo.removeFromLibrary('n1');

      // ⚠️ **This is why `readNovel` is not `isInLibrary`.** B32 removes the ENTRY, not the
      // novel: the row survives so the reader can put it back, and so its downloaded
      // chapters and reading positions keep a parent to hang from. A reader who removed a
      // novel and reopened its page must still see what it was.
      expect(
        await repo.readNovel('n1'),
        isNotNull,
        reason:
            'removal deletes the MEMBERSHIP, not the novel — the row is what '
            '`restoreToLibrary` needs, and what a removed novel\'s page still describes',
      );
    });
  });
}
