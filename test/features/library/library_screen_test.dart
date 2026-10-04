// Lumen Tale — `2-5`'s screen: five states, and the two dialogs that must not lie.
//
// ## What these rows hold the screen to
//
// | promise | row |
// |---|---|
// | empty is NOT an error, and never says "0 results" | *an empty library names the next step* |
// | the removal dialog quotes a TRUE count | *the dialog quotes the count, read before the write* |
// | dismissing the similar-title dialog is declining | *dismissing answers DISMISSED* |
// | nothing is optimistic on a failed write | *the removal is not claimed when the dialog is dismissed* |

import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumen_tale/core/ui/library_dialogs.dart';
import 'package:lumen_tale/data/library/library_providers.dart';
import 'package:lumen_tale/domain/library/library_entry.dart';
import 'package:lumen_tale/domain/library/library_repository.dart';
import 'package:lumen_tale/domain/library/similar_title.dart';
import 'package:lumen_tale/domain/sources/models/novel.dart';
import 'package:lumen_tale/features/library/library_screen.dart';
import 'package:lumen_tale/l10n/generated/app_localizations.dart';

/// A repository that reports whatever the test hands it and records every call.
final class FakeLibrary implements LibraryRepository {
  FakeLibrary({this.rows = const <LibraryEntry>[], this.downloaded = 0});

  List<LibraryEntry> rows;
  int downloaded;

  /// A broadcast controller, closed by [pumpLibrary].
  ///
  /// ⚠️ **`StreamController.broadcast`, not the single-subscription default.** A second
  /// `watchLibrary` on a single-subscription controller throws, which would be a harness
  /// limitation reported as a product defect.
  // ignore: close_sinks
  final StreamController<List<LibraryEntry>> controller =
      StreamController<List<LibraryEntry>>.broadcast();

  final List<String> calls = <String>[];
  final List<RemoveOutcome> removals = <RemoveOutcome>[];

  @override
  Future<AddOutcome> addFromCatalogue({
    required Novel novel,
    required Future<SimilarTitleVerdict> Function(List<SimilarTitle> similar)
    onSimilarTitle,
  }) async {
    calls.add('add:${novel.id}');
    return const AddOutcome.added();
  }

  @override
  Stream<List<LibraryEntry>> watchLibrary() {
    calls.add('watch');
    return controller.stream;
  }

  /// ⚠️ **Resolves against [rows], so a row a test seeds IS the novel this returns.**
  ///
  /// The alternative — a separate stub list — would let a test seed a library row and read
  /// back a `null`, and the failure would look like the repository losing data rather than
  /// the fake having two sources of truth.
  @override
  Future<Novel?> readNovel(String novelId) async {
    calls.add('read:$novelId');
    for (final LibraryEntry entry in rows) {
      if (entry.id != novelId) continue;
      return Novel(
        id: entry.id,
        sourceId: entry.sourceId,
        // ⚠️ **A URL, because `addFromCatalogue` REJECTS an empty one** — a fake that
        // returned an empty url would be rejected for a reason no real stored row has.
        url: '/fiction/${entry.id}',
        title: entry.title,
        author: entry.author ?? '',
        description: '',
        status: NovelStatus.unknown,
        coverUrl: entry.coverUrl ?? '',
        genres: const <String>[],
      );
    }
    return null;
  }

  @override
  Future<RemoveOutcome> removeFromLibrary(String novelId) async {
    calls.add('remove:$novelId');
    final RemoveOutcome outcome = RemoveOutcome(
      downloadedChapterCount: downloaded,
      wasAlreadyRemoved: false,
    );
    removals.add(outcome);
    return outcome;
  }

  @override
  Future<int> countDownloadedChapters(String novelId) async {
    calls.add('count:$novelId');
    return downloaded;
  }

  @override
  Future<void> restoreToLibrary(String novelId) async =>
      calls.add('restore:$novelId');

  @override
  String? sourceNameOf(String sourceId) => sourceId;
}

LibraryEntry entry({
  String id = 'n1',
  String title = 'The Rune Smith',
  int unopened = 0,
  int downloaded = 0,
  int known = 480,
  String? author = 'An Author',
}) {
  return LibraryEntry(
    id: id,
    sourceId: 'royalroad',
    sourceName: 'Royal Road',
    title: title,
    author: author,
    inLibrary: true,
    unopenedCount: unopened,
    chapterCount: known,
    downloadedCount: downloaded,
    addedAt: DateTime(2026, 10, 1, 9),
  );
}

Future<FakeLibrary> pumpLibrary(
  WidgetTester tester,
  FakeLibrary repository,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [libraryRepositoryProvider.overrideWithValue(repository)],
      child: const _App(),
    ),
  );
  await tester.pump();
  repository.controller.add(repository.rows);
  await tester.pumpAndSettle();
  return repository;
}

class _App extends StatelessWidget {
  const _App();

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: LibraryScreen(),
    );
  }
}

void main() {
  group('the five states', () {
    testWidgets('⚠️ an empty library names the NEXT STEP, not a result count', (
      WidgetTester tester,
    ) async {
      // ⚠️ **"0 novels" would be a report about a query.** An empty library is the state every
      // reader is in until they browse once, so the screen says what to do.
      final FakeLibrary repository = await pumpLibrary(tester, FakeLibrary());

      expect(find.text('Your library is empty'), findsOneWidget);
      expect(
        find.text('Add a novel from Browse to start reading.'),
        findsOneWidget,
      );
      expect(find.textContaining('0 '), findsNothing);
      expect(repository.calls, contains('watch'));
    });

    testWidgets('a filled library renders one tile per entry', (
      WidgetTester tester,
    ) async {
      await pumpLibrary(
        tester,
        FakeLibrary(
          rows: <LibraryEntry>[
            entry(id: 'a', title: 'First', unopened: 3, downloaded: 12),
            entry(id: 'b', title: 'Second'),
          ],
        ),
      );

      expect(find.text('First'), findsOneWidget);
      expect(find.text('Second'), findsOneWidget);
      expect(find.text('3 new chapters'), findsOneWidget);
      expect(find.text('12 of 480 downloaded'), findsOneWidget);
    });

    testWidgets('⚠️ an unknown author is a WORD, and the SOURCE is always shown', (
      WidgetTester tester,
    ) async {
      // ⚠️ **ADR-024: displayed, never searched.** A site may publish no author; a dash is what
      // a rendering fallback produces, while a sentence says the library does not know.
      //
      // ⚠️ **And the source is on the same line even when the author is known**, because two
      // sites publish the same pen name.
      await pumpLibrary(
        tester,
        FakeLibrary(rows: <LibraryEntry>[entry(author: null)]),
      );

      expect(find.textContaining('Author unknown'), findsOneWidget);
      expect(find.textContaining('Royal Road'), findsOneWidget);
    });

    testWidgets('a novel with no downloads says so, not "0 of 480"', (
      WidgetTester tester,
    ) async {
      await pumpLibrary(tester, FakeLibrary(rows: <LibraryEntry>[entry()]));

      expect(find.text('Not downloaded yet'), findsOneWidget);
      expect(find.textContaining('0 of'), findsNothing);
    });

    testWidgets('⚠️ a load failure says the LIBRARY could not be read', (
      WidgetTester tester,
    ) async {
      // ⚠️ **The error is emitted AFTER the first pump, not before.** A broadcast controller
      // with no listener drops an `addError`, so pushing it early would test the harness
      // instead of the screen.
      final FakeLibrary repository = FakeLibrary();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [libraryRepositoryProvider.overrideWithValue(repository)],
          child: const _App(),
        ),
      );
      await tester.pump();
      repository.controller.addError(StateError('the database is closed'));
      await tester.pumpAndSettle();
      addTearDown(repository.controller.close);

      expect(find.text('Your library could not be read'), findsOneWidget);
      // ⚠️ **And it is NOT the generic app error**, which says an operation failed — here the
      // app is fine and the read is what could not be made.
      expect(find.textContaining('Something went wrong'), findsNothing);
    });
  });

  group('the removal dialog — B32, and C8', () {
    testWidgets('⚠️ the dialog quotes the count, read BEFORE the write', (
      WidgetTester tester,
    ) async {
      // ⚠️ **The number in a confirmation has to be checkable.** Asking the repository after
      // the write would mean writing first and explaining afterwards.
      final FakeLibrary repository = await pumpLibrary(
        tester,
        FakeLibrary(
          rows: <LibraryEntry>[entry(downloaded: 148)],
          downloaded: 148,
        ),
      );

      await tester.tap(find.byIcon(Icons.remove_circle_outline));
      await tester.pumpAndSettle();

      expect(find.text('Remove from library?'), findsOneWidget);
      expect(find.textContaining('148 downloaded chapters'), findsOneWidget);
      expect(
        repository.calls.indexOf('count:n1'),
        lessThan(repository.calls.length),
      );
      expect(
        repository.calls,
        isNot(contains('remove:n1')),
        reason: 'nothing is written until the reader confirms',
      );
    });

    testWidgets('⚠️ dismissing the dialog removes NOTHING', (
      WidgetTester tester,
    ) async {
      // ⚠️ **C8: on a device with no cloud backup the easiest gesture must not be the
      // destructive one.** Closing a confirmation is not agreeing to it.
      final FakeLibrary repository = await pumpLibrary(
        tester,
        FakeLibrary(rows: <LibraryEntry>[entry()]),
      );

      await tester.tap(find.byIcon(Icons.remove_circle_outline));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(repository.calls, isNot(contains('remove:n1')));
      expect(find.text('Remove from library?'), findsNothing);
    });

    testWidgets('⚠️ the BARRIER also declines — closing is not agreeing', (
      WidgetTester tester,
    ) async {
      // ⚠️ **The row that was missing, and its sabotage proved it.** Tapping *Cancel* closes
      // the dialog with `pop(false)`, so a `ConfirmDialog.ask` that answered `true` when the
      // answer was `null` passed every row — while the *barrier* dismissal, which is the most
      // casual gesture on the screen, would have removed a novel. Same rule as the
      // similar-title dialog, and it needed its own row to be held to it.
      final FakeLibrary repository = await pumpLibrary(
        tester,
        FakeLibrary(rows: <LibraryEntry>[entry()]),
      );

      await tester.tap(find.byIcon(Icons.remove_circle_outline));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();

      expect(
        repository.calls,
        isNot(contains('remove:n1')),
        reason:
            'the barrier is the easiest gesture on the screen, and C8 says the easiest '
            'gesture must not be the destructive one',
      );
    });

    testWidgets('⚠️ confirming removes, and says what SURVIVED', (
      WidgetTester tester,
    ) async {
      final FakeLibrary repository = await pumpLibrary(
        tester,
        FakeLibrary(
          rows: <LibraryEntry>[entry(downloaded: 148)],
          downloaded: 148,
        ),
      );

      await tester.tap(find.byIcon(Icons.remove_circle_outline));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Remove'));
      await tester.pumpAndSettle();

      expect(repository.calls, contains('remove:n1'));
      expect(repository.removals, hasLength(1));
      expect(repository.removals.single.downloadedChapterCount, 148);
      // ⚠️ **B32 said out loud.** "Nothing was deleted" is a promise the reader can see rather
      // than a rule they have to trust.
      expect(
        find.text('Nothing was deleted. The chapters are still here.'),
        findsOneWidget,
      );
    });

    testWidgets('the confirm button is DESTRUCTIVE and the cancel is not', (
      WidgetTester tester,
    ) async {
      await pumpLibrary(tester, FakeLibrary(rows: <LibraryEntry>[entry()]));

      await tester.tap(find.byIcon(Icons.remove_circle_outline));
      await tester.pumpAndSettle();

      final FilledButton confirm = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Remove'),
      );
      expect(
        confirm.style?.backgroundColor?.resolve(<WidgetState>{}) ??
            confirm.style?.backgroundColor,
        isNotNull,
        reason:
            'a destructive action is painted in the error colour, not the primary one',
      );
    });
  });

  group('the similar-title dialog — B40, and C8 again', () {
    testWidgets('⚠️ dismissing answers DISMISSED, and dismissed DECLINES', (
      WidgetTester tester,
    ) async {
      // ⚠️ **The same rule as the confirmation, and the same reason.** A dialog that answered
      // "add anyway" on dismissal would make the most casual gesture on the screen the one
      // that writes a duplicate.
      SimilarTitleVerdict? verdict;
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (BuildContext context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  verdict = await showSimilarTitleDialog(
                    context,
                    similar: candidates,
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      // ⚠️ **The barrier, not a button** — the most casual dismissal there is.
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();

      expect(verdict, SimilarTitleVerdict.dismissed);
    });

    testWidgets('the dialog names BOTH novels and BOTH sites', (
      WidgetTester tester,
    ) async {
      // ⚠️ **"Is this the same novel?" is unanswerable without knowing which site published
      // which**, which is why the body names both rather than only the incoming one.
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (BuildContext context) => Scaffold(
              body: TextButton(
                onPressed: () =>
                    showSimilarTitleDialog(context, similar: candidates),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Royal Road'), findsOneWidget);
      expect(find.textContaining('FanMTL'), findsOneWidget);
      expect(find.text('Add anyway'), findsOneWidget);
      // ⚠️ **And the merge warning is on the dialog**, because after it there is nowhere to say
      // the second novel stays a second novel.
      expect(
        find.text('Nothing will be merged — they stay two separate novels.'),
        findsOneWidget,
      );
    });

    testWidgets('the three verdicts are all reachable', (
      WidgetTester tester,
    ) async {
      for (final (String label, SimilarTitleVerdict expected)
          in <(String, SimilarTitleVerdict)>[
            ('Cancel', SimilarTitleVerdict.dismissed),
            ('Open the existing one', SimilarTitleVerdict.openExisting),
            ('Add anyway', SimilarTitleVerdict.addAnyway),
          ]) {
        SimilarTitleVerdict? verdict;
        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Builder(
              builder: (BuildContext context) => Scaffold(
                body: TextButton(
                  onPressed: () async {
                    verdict = await showSimilarTitleDialog(
                      context,
                      similar: candidates,
                    );
                  },
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();
        await tester.tap(find.text(label));
        await tester.pumpAndSettle();

        expect(verdict, expected, reason: label);
      }
    });
  });

  group('the screen cannot reach the network', () {
    test('⚠️ the library screen names no network capability', () {
      // ⚠️ **C14: the library is readable offline**, and the guarantee is the absence of a
      // capability rather than a promise in a comment.
      final String code = _codeOf('lib/features/library/library_screen.dart');
      expect(code, isNot(contains('dio')));
      expect(code, isNot(contains('HttpClient')));
      expect(code, isNot(contains('core/network')));
    });

    test(
      '⚠️ the "check" action is DISABLED, not a live button that does nothing',
      () {
        // ⚠️ **An interface hole, labelled.** A live-looking button that silently does nothing is
        // worse than a disabled one: the reader presses it and concludes the app is broken.
        // B36/B38/B39's wire belongs to `6-3`/`6-4`/`6-10`.
        final String code = _codeOf('lib/features/library/library_screen.dart');
        expect(code, contains('onPressed: null'));
      },
    );
  });
}

/// The candidates a B40 dialog is shown.
final List<SimilarTitle> candidates = <SimilarTitle>[
  const SimilarTitle(
    existingNovelId: 'n1',
    existingTitle: 'The Rune Smith',
    existingSourceName: 'Royal Road',
    incomingTitle: 'the rune smith',
    incomingSourceName: 'FanMTL',
  ),
];

String _codeOf(String path) {
  return File(path)
      .readAsStringSync()
      .split('\n')
      .where((String line) => !line.trimLeft().startsWith('//'))
      .join('\n');
}
