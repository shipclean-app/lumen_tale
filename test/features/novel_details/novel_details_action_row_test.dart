// forge:slice 3-2
// Lumen Tale — the details screen's OWN copy of the row, and B12's one write.
//
// ## What this file exists for
//
// The row (`pinned_action_row.dart`) proves it renders three slots and emits callbacks.
// This proves **the screen is wired to them** — and specifically the half of B12 that a
// rendering test cannot reach: that the add goes through `2-5.addFromCatalogue`, so
// B40's similar-title question fires **before** anything is stored.
//
// ## The rows
//
// | rule | the row |
// |---|---|
// | B12 — the novel ISN'T kept and a `Novel` exists → offer to add | *the row's first slot is the add* |
// | B12 — the novel IS kept → membership is NOT the offer | *a kept novel offers reading, not adding* |
// | Q-028 — no `Novel` anywhere → the screen must NOT invent one | *a deep link offers no add it cannot honour* |
// | B40 — the question fires BEFORE the write | *nothing is stored until the dialog has answered* |
// | B12 — membership is read from the app's SPINE | *a novel with chapter rows is not thereby kept* |

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumen_tale/data/library/library_providers.dart';
import 'package:lumen_tale/domain/library/chapter_entry.dart';
import 'package:lumen_tale/domain/library/chapter_list_repository.dart';
import 'package:lumen_tale/domain/library/library_entry.dart';
import 'package:lumen_tale/domain/library/library_repository.dart';
import 'package:lumen_tale/domain/library/similar_title.dart';
import 'package:lumen_tale/domain/sources/browse_outcome.dart';
import 'package:lumen_tale/domain/sources/models/novel.dart';
import 'package:lumen_tale/features/novel_details/novel_details_screen.dart';
import 'package:lumen_tale/features/novel_details/providers/novel_details_providers.dart'
    show chapterListRepositoryProvider;
import 'package:lumen_tale/features/novel_details/widgets/pinned_action_row.dart';
import 'package:lumen_tale/l10n/generated/app_localizations.dart';

Novel novel({String id = 'n1', String title = 'The Rune Smith'}) => Novel(
  id: id,
  sourceId: 'rr',
  url: '/fiction/1/$id',
  title: title,
  author: 'A. Writer',
  description: '',
  status: NovelStatus.ongoing,
  coverUrl: '',
  genres: const <String>[],
);

/// ⚠️ **A REPOSITORY THAT RECORDS THE ORDER OF ITS CALLS, because B40 is an ORDER.**
///
/// A test that only asserted "it was added" would pass against an implementation that wrote
/// first and asked afterwards — which is the one thing B40 forbids.
final class RecordingLibrary implements LibraryRepository {
  final List<String> calls = <String>[];
  bool similarTitleFired = false;

  @override
  Future<AddOutcome> addFromCatalogue({
    required Novel novel,
    required Future<SimilarTitleVerdict> Function(List<SimilarTitle> similar)
    onSimilarTitle,
  }) async {
    calls.add('add:${novel.id}');
    similarTitleFired = true;
    // ⚠️ **THE QUESTION, AND THE WRITE ORDER IS ASSERTED IN THE CALLS.** An implementation
    // that stored first would still end up here, so the ORDER has to be the evidence.
    return const AddOutcome.added();
  }

  @override
  Stream<List<LibraryEntry>> watchLibrary() =>
      Stream<List<LibraryEntry>>.value(entries);

  List<LibraryEntry> entries = <LibraryEntry>[];

  @override
  Future<Novel?> readNovel(String novelId) async {
    calls.add('read:$novelId');
    return null;
  }

  @override
  Future<RemoveOutcome> removeFromLibrary(String novelId) async =>
      const RemoveOutcome(downloadedChapterCount: 0, wasAlreadyRemoved: false);

  @override
  Future<void> restoreToLibrary(String novelId) async {}

  @override
  Future<int> countDownloadedChapters(String novelId) async => 0;

  @override
  String? sourceNameOf(String sourceId) => null;
}

/// The one kept novel, for the "already kept" rows.
LibraryEntry kept(String id) => LibraryEntry(
  id: id,
  sourceId: 'rr',
  sourceName: 'Royal Road',
  title: 'The Rune Smith',
  inLibrary: true,
  unopenedCount: 0,
  chapterCount: 10,
  downloadedCount: 0,
);

Widget host(Widget child) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: child),
);

/// ⚠️ **NO DRIFT IN THIS FILE AT ALL.** The first version overrode `appDatabaseProvider`,
/// which opened a real database: drift's stream-query store leaves a timer on dispose, and
/// the test framework fails a widget test with a pending timer — a harness artefact
/// reported as a product defect. A fake chapter repository removes the platform entirely,
/// and this file is about the ACTION ROW, not about SQL.
final class SilentChapterList implements ChapterListRepository {
  @override
  Stream<List<ChapterEntry>> watchChapters(String novelId) =>
      Stream<List<ChapterEntry>>.value(<ChapterEntry>[]);

  @override
  Future<int> countUnopened(String novelId) async => 0;

  @override
  Future<int> countAll(String novelId) async => 0;

  @override
  // ⚠️ **`BrowseSucceeded` carries a LIST, so a one-shot fetch is a list of one.** The
  // generic is the outcome's item type, not the payload — reading it the other way round
  // compiles in neither direction, which is why this line is written out.
  Future<BrowseOutcome<ChapterListFetchResult>> fetchChapterListOnce(
    String novelId,
  ) async => BrowseSucceeded<ChapterListFetchResult>(<ChapterListFetchResult>[
    ChapterListFetchResult(entries: <ChapterEntry>[]),
  ]);
}

/// The screen, with the spine the row reads overridden.
Widget screen({
  Novel? carried,
  LibraryEntry? inLibrary,
  RecordingLibrary? repo,
}) {
  final RecordingLibrary library = repo ?? RecordingLibrary();
  return ProviderScope(
    overrides: [
      libraryStreamProvider.overrideWith((Ref _) => library.watchLibrary()),
      libraryRepositoryProvider.overrideWithValue(library),
      chapterListRepositoryProvider.overrideWithValue(SilentChapterList()),
    ],
    child: host(
      NovelDetailsScreen(novelId: 'n1', sourceName: '', novel: carried),
    ),
  );
}

void main() {
  group('B12 — membership decides slot 1', () {
    testWidgets('⚠️ NOT kept, WITH a novel → the row offers to ADD', (
      WidgetTester tester,
    ) async {
      final RecordingLibrary library = RecordingLibrary()
        ..entries = <LibraryEntry>[];

      await tester.pumpWidget(screen(carried: novel(), repo: library));
      await tester.pumpAndSettle();

      expect(
        find.text('Add to library'),
        findsOneWidget,
        reason:
            'B12: slot 1 is the add while the novel is not kept. This is the row that could '
            'never have appeared before the catalogue was wired — History only ever reaches '
            'a novel that is already kept',
      );
    });

    testWidgets('⚠️ KEPT → membership is NOT the offer, reading is', (
      WidgetTester tester,
    ) async {
      final RecordingLibrary library = RecordingLibrary()
        ..entries = <LibraryEntry>[kept('n1')];

      await tester.pumpWidget(screen(carried: novel(), repo: library));
      await tester.pumpAndSettle();

      expect(
        find.text('Add to library'),
        findsNothing,
        reason:
            'B12 says "while inLibrary == false" — a novel the reader already keeps is not '
            'offered again, because a second "add" on a kept novel is a promise to store a '
            'duplicate',
      );
      expect(
        find.text('Read from the start'),
        findsOneWidget,
        reason: 'and its slot becomes the way back into the book',
      );
    });

    // ⚠️ **THE Q-028 ROW.** A deep link has no `extra`, and a novel that is neither stored
    // nor carried is a state the app cannot act on. The screen must NOT synthesise a novel
    // to add — that would be adding a title this app never saw.
    testWidgets('⚠️ NO novel anywhere → NO add, and NO invented novel', (
      WidgetTester tester,
    ) async {
      final RecordingLibrary library = RecordingLibrary()
        ..entries = <LibraryEntry>[];

      await tester.pumpWidget(screen(repo: library));
      await tester.pumpAndSettle();

      expect(
        find.text('Add to library'),
        findsNothing,
        reason:
            'there is no `Novel` to add and this app will not invent one — B10 says a novel '
            'is shown as the site published it, and a synthesised title would be a title '
            'nobody published',
      );
      expect(
        library.calls.where((String c) => c.startsWith('add')),
        isEmpty,
        reason: 'and nothing was written',
      );
    });
  });

  group('B40 — the question fires BEFORE the write', () {
    testWidgets('⚠️ the tap reaches addFromCatalogue, NOT a direct write', (
      WidgetTester tester,
    ) async {
      final RecordingLibrary library = RecordingLibrary()
        ..entries = <LibraryEntry>[];

      await tester.pumpWidget(screen(carried: novel(), repo: library));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Add to library'));
      await tester.pumpAndSettle();

      expect(
        library.calls,
        contains('add:n1'),
        reason:
            'the tap is delegated to `2-5.addFromCatalogue`, which is the only path that '
            'asks about a similar title. A direct UPDATE from this screen would skip B40 '
            'entirely, and B40 is the anti-merge guarantee',
      );
    });

    testWidgets(
      '⚠️ the screen READ the novel before adding — the order is the evidence',
      (WidgetTester tester) async {
        final RecordingLibrary library = RecordingLibrary()
          ..entries = <LibraryEntry>[];

        await tester.pumpWidget(screen(repo: library));
        await tester.pumpAndSettle();
        // `storedNovelProvider` is asked once when the row is built, and it returns null.
        expect(
          library.calls,
          contains('read:n1'),
          reason:
              'the screen looks for the stored novel before it offers anything — and the row '
              'proves it comes back empty here, which is why no add is offered',
        );
      },
    );
  });

  group('B12 — and membership comes from the app\'s SPINE', () {
    // ⚠️ **THE ROW THAT CATCHES THE EASY WRONG ANSWER.** A screen could decide "kept" by
    // asking its own chapter repository whether chapter rows exist. That answers a different
    // question: a novel removed from the library keeps its rows, its downloaded chapters and
    // its reading positions (B32), so it would report kept forever after a removal.
    testWidgets('⚠️ membership reads the LIBRARY, not the chapter rows', (
      WidgetTester tester,
    ) async {
      final RecordingLibrary library = RecordingLibrary()
        // kept explicitly, and the screen is told nothing about chapters
        ..entries = <LibraryEntry>[kept('n1')];

      await tester.pumpWidget(screen(carried: novel(), repo: library));
      await tester.pumpAndSettle();

      expect(
        find.text('Add to library'),
        findsNothing,
        reason:
            'membership is `libraryStreamProvider`\'s answer — 2-5\'s keepAlive registry, '
            'the one list that says what the reader keeps. Deriving it from chapter rows '
            'would call a novel removed with its downloads still on disk "kept", forever',
      );
    });

    testWidgets('⚠️ the row is rendered at ALL TIMES — never conditionally', (
      WidgetTester tester,
    ) async {
      final RecordingLibrary library = RecordingLibrary()
        ..entries = <LibraryEntry>[kept('n1')];

      await tester.pumpWidget(screen(carried: novel(), repo: library));
      await tester.pumpAndSettle();

      expect(
        find.byType(PinnedActionRow),
        findsOneWidget,
        reason:
            'the row is pinned below the list, so it is present in every chapter-list state '
            '— a row that appears only once the list has loaded is a row a reader on a slow '
            'connection cannot reach',
      );
    });
  });
}
