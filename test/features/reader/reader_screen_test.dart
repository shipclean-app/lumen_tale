// forge:slice 2-4
// Lumen Tale — `2-4`'s screen: nine states, one write at a settle, one mark at a display.
//
// ## What is asserted here and what is asserted elsewhere
//
// The seven non-prose states are **rendered here** and **decided** in
// `test/data/reader/local_chapter_reader_repository_test.dart`. This file injects a fake
// repository and checks that each `ChapterDocument` reaches a reader-visible sentence, and
// that a reader can act — because "the type is correct" and "the reader is told something
// they can use" are different claims.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lumen_tale/domain/library/reading_position.dart';
import 'package:lumen_tale/domain/library/reading_position_store.dart';
import 'package:lumen_tale/domain/reader/chapter_document.dart';
import 'package:lumen_tale/domain/reader/chapter_reader_repository.dart';
import 'package:lumen_tale/features/reader/mark_opened_once.dart';
import 'package:lumen_tale/features/reader/reader_providers.dart';
import 'package:lumen_tale/features/reader/reader_screen.dart';
import 'package:lumen_tale/l10n/generated/app_localizations.dart';

/// ⚠️ **Long enough that the column actually scrolls** — a chapter shorter than the viewport
/// ⚠️ **Paragraphs, not one long run.** A single 6 600-character paragraph wraps into
/// lines but can still fit its own box in some engines; separate paragraphs guarantee the
/// column overflows, and a settle row that passes because nothing scrolled proves nothing.
final String longProse = 'A paragraph of prose that scrolls.\n\n' * 200;

const ChapterText text = ChapterText(
  chapterId: 'c1',
  chapterName: 'Glossary',
  number: 12,
  ordinal: 526587,
  markdown: '# Glossary\n\nA term is a word the author has defined once.\n',
  byteLength: 61,
);

/// A handle on the prose area, so a row can tap the reading zone without depending on the
/// prose widget's own class name.
final Finder proseArea = find.byKey(
  const ValueKey<String>('reader-prose-area'),
);

/// A repository that returns whatever the test hands it and records what it received.
final class FakeRepository implements ChapterReaderRepository {
  FakeRepository(this.document);

  ChapterDocument document;

  /// `chapterId:novelId:ordinal:hasConnection`, one entry per read.
  ///
  /// ⚠️ **`hasConnection` is recorded rather than assumed**, so a row can prove the reader
  /// passed the platform's answer down instead of hard-coding `true`.
  final List<String> readCalls = <String>[];

  final List<String> marked = <String>[];

  @override
  Future<ChapterDocument> readChapter({
    required String chapterId,
    required bool hasConnection,
  }) async {
    readCalls.add('$chapterId:$hasConnection');
    return document;
  }

  @override
  Future<void> markOpened(String chapterId) async => marked.add(chapterId);

  @override
  Future<ChapterNeighbour?> neighbour({
    required String chapterId,
    required NeighbourDirection direction,
  }) async => null;

  @override
  final RecordingPositions positions = RecordingPositions();
}

/// A position store that **records what the reader wrote to it**, and is the only place
/// B16's operations can go from the screen.
final class RecordingPositions implements ReadingPositionStore {
  final List<(String, double, double)> writes = <(String, double, double)>[];

  @override
  Future<void> write(
    String chapterId,
    double offset, {
    required double contentHeight,
  }) async => writes.add((chapterId, offset, contentHeight));

  @override
  Future<void> clear(String chapterId) async {}

  @override
  Future<ReadingPosition?> mostRecentAmong(List<String> chapterIds) async =>
      null;

  @override
  Future<ReadingPosition?> read(String chapterId) async => null;
}

/// The reader inside a real app, so `AppLocalizations` resolves.
///
/// Returns the repository **and** a [ValueNotifier] for the platform text scale.
///
/// ⚠️ **Rebuilding by pumping a whole new tree does not test a rebuild.** A fresh
/// `ProviderScope` is a fresh container, and a fresh container is a fresh `ConsumerState` —
/// so a state flag resets and the row measures the wrong thing. The scale notifier rebuilds
/// without replacing the container.
Future<(FakeRepository, ValueNotifier<double>)> pumpReader(
  WidgetTester tester,
  ChapterDocument document, {
  bool hasConnection = true,
  ValueNotifier<bool>? connection,
}) async {
  final FakeRepository repository = FakeRepository(document);
  final ValueNotifier<double> scale = ValueNotifier<double>(1);
  final ValueNotifier<bool> online =
      connection ?? ValueNotifier<bool>(hasConnection);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        chapterReaderRepositoryProvider.overrideWithValue(repository),
        hasConnectionProvider.overrideWith((Ref ref) => online.value),
      ],
      child: ValueListenableBuilder<double>(
        valueListenable: scale,
        builder: (BuildContext _, double value, _) => const _App(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return (repository, scale);
}

class _App extends StatelessWidget {
  const _App();

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: ReaderScreen(chapterId: 'c1'),
    );
  }
}

void main() {
  group('OnceGate — B13\'s "once", where a row can actually drive it', () {
    test('⚠️ the action runs on the first call and not on any other', () {
      // ⚠️ **The row that was missing.** The guard was a `bool` on the screen's `State`, so
      // no test could re-enter it: two pumps do not rebuild, a text-scale change rebuilds
      // only `ChapterProse`, and a whole new tree resets the field. Removing the guard
      // therefore passed every screen row.
      final OnceGate gate = OnceGate();
      int calls = 0;

      expect(gate.run(() => calls += 1), isTrue);
      expect(gate.run(() => calls += 1), isFalse);
      expect(gate.run(() => calls += 1), isFalse);
      expect(calls, 1);
      expect(gate.isSpent, isTrue);
    });

    test(
      '⚠️ a THROWING action is still spent — the flag flips before, not after',
      () {
        // ⚠️ The write B13 guards can throw (a closed database, a full disk). Flipping after
        // the call would let every subsequent rebuild retry it, and a mark that half-succeeded
        // is worse than one that was attempted once and reported.
        final OnceGate gate = OnceGate();
        int calls = 0;

        expect(
          () => gate.run(() {
            calls += 1;
            throw StateError('the database is closed');
          }),
          throwsStateError,
        );
        expect(gate.run(() => calls += 1), isFalse);
        expect(calls, 1);
      },
    );

    test('a fresh gate is fresh', () {
      // ⚠️ The gate is per **mount**, not per app: returning to a chapter the reader has
      // already read re-opens it, and the repository's own `isRead` check is what makes that
      // idempotent.
      expect(OnceGate().isSpent, isFalse);
    });
  });

  group('the seven non-prose states, each with its own sentence', () {
    testWidgets('not stored: says it, and offers the download', (
      WidgetTester tester,
    ) async {
      await pumpReader(tester, const ChapterNotStored(chapterId: 'c1'));

      expect(find.text('This chapter is not downloaded'), findsOneWidget);
      expect(find.text('Download this chapter'), findsOneWidget);
      expect(find.text('Open downloads'), findsOneWidget);
    });

    testWidgets('⚠️ offline AND absent: BOTH facts, and the primary is disabled', (
      WidgetTester tester,
    ) async {
      // ⚠️ **The row that B24 asks for.** "Not downloaded" alone leaves the reader wondering
      // whether the button will work; "offline" alone leaves them wondering whether the
      // chapter is theirs. Each is insufficient on its own.
      await pumpReader(
        tester,
        const ChapterOfflineAndAbsent(chapterId: 'c1'),
        hasConnection: false,
      );

      expect(
        find.text('This chapter is not downloaded and there is no connection'),
        findsOneWidget,
      );
      final FilledButton primary = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Download this chapter'),
      );
      expect(
        primary.onPressed,
        isNull,
        reason: 'it cannot work without a connection',
      );
      // ⚠️ **And the reason is on screen.** A disabled button with no explanation reads as a
      // broken button.
      expect(find.text('Downloading needs a connection'), findsOneWidget);
    });

    testWidgets('⚠️ file missing: says the DOWNLOAD SUCCEEDED', (
      WidgetTester tester,
    ) async {
      // ⚠️ **The phrase is the row.** "This chapter is unavailable" would tell the reader the
      // download failed, which is false — and a reader who re-downloads on that sentence is
      // doing the right thing for the wrong reason.
      await pumpReader(
        tester,
        ChapterFileMissing(
          chapterId: 'c1',
          // ⚠️ **A local `DateTime`, not `DateTime.utc`.** `DateTime.utc` is not a compile-time
          // constant, so a `const` here would not build — and a chapter's missing-file state
          // has no business being pinned to UTC anyway.
          markedAt: DateTime(2026, 10, 1, 9),
        ),
      );

      expect(
        find.textContaining('its text is no longer on this phone'),
        findsOneWidget,
      );
      expect(find.textContaining('The download succeeded'), findsOneWidget);
      expect(find.text('Download again'), findsOneWidget);
    });

    testWidgets('file empty: "interrupted", not "corrupt"', (
      WidgetTester tester,
    ) async {
      await pumpReader(tester, const ChapterFileEmpty(chapterId: 'c1'));

      expect(
        find.text("This chapter's recording was interrupted"),
        findsOneWidget,
      );
      expect(find.textContaining('saved copy'), findsNothing);
      expect(find.text('Download again'), findsOneWidget);
    });

    testWidgets('⚠️ corrupt: the word comes from the TYPED reason', (
      WidgetTester tester,
    ) async {
      await pumpReader(
        tester,
        const ChapterFileCorrupt(
          chapterId: 'c1',
          reason: ReaderFileFailure.notMarkdown,
        ),
      );
      expect(
        find.text("This chapter's saved copy is not readable"),
        findsOneWidget,
      );
      expect(find.text('Download again'), findsOneWidget);
    });

    testWidgets('⚠️ an I/O refusal offers RETRY, not a re-download', (
      WidgetTester tester,
    ) async {
      // ⚠️ **The bytes may be fine and the filesystem merely refused.** Offering a
      // re-download would tell a reader their copy is at fault when it may not be.
      await pumpReader(
        tester,
        const ChapterFileCorrupt(
          chapterId: 'c1',
          reason: ReaderFileFailure.unreadableIo,
        ),
      );
      expect(find.text('Retry'), findsOneWidget);
      expect(find.text('Download again'), findsNothing);
    });

    testWidgets('⚠️ the I/O action RE-READS, and the bad-file action does not', (
      WidgetTester tester,
    ) async {
      // ⚠️ **The word and the action are one rule, so this row asserts the ACTION.** The
      // first version of this test read the label, and a sabotage that swapped only the
      // callback left a button reading **Retry** that performed a download — the label and
      // the behaviour were two expressions of one decision.
      //
      // `retry` invalidates the document provider, so it produces another read. `download`
      // is `2-4`'s intent with nothing behind it, so it produces none. Counting reads
      // separates them where a label cannot.
      final (FakeRepository repository, _) = await pumpReader(
        tester,
        const ChapterFileCorrupt(
          chapterId: 'c1',
          reason: ReaderFileFailure.unreadableIo,
        ),
      );
      final int before = repository.readCalls.length;

      await tester.tap(find.widgetWithText(FilledButton, 'Retry'));
      await tester.pumpAndSettle();

      expect(
        repository.readCalls.length,
        greaterThan(before),
        reason: 'an I/O refusal is retried, so the file is opened again',
      );
    });

    testWidgets('⚠️ and a bad file offers a download, which does NOT re-read', (
      WidgetTester tester,
    ) async {
      // ⚠️ The mirror, and it is the half that would hide: if both reasons re-read, the
      // action would be "retry" for a corrupt file too — and re-reading a file whose bytes
      // are bad produces the same corrupt file.
      final (FakeRepository repository, _) = await pumpReader(
        tester,
        const ChapterFileCorrupt(
          chapterId: 'c1',
          reason: ReaderFileFailure.notMarkdown,
        ),
      );
      final int before = repository.readCalls.length;

      await tester.tap(find.widgetWithText(FilledButton, 'Download again'));
      await tester.pumpAndSettle();

      expect(
        repository.readCalls.length,
        before,
        reason:
            're-downloading is 3-3\'s to execute; retrying the same bad file is not',
      );
    });

    testWidgets('row gone: NOT an error state, and it offers a way back', (
      WidgetTester tester,
    ) async {
      // ⚠️ An `ErrorState` would report *this app* as broken for a link the reader followed.
      await pumpReader(tester, const ChapterRowGone());

      expect(
        find.text('This chapter no longer exists in your library'),
        findsOneWidget,
      );
      expect(find.text('Back'), findsOneWidget);
      expect(find.textContaining('went wrong'), findsNothing);
    });
  });

  group('the normal state', () {
    testWidgets('the prose renders, and so does the number', (
      WidgetTester tester,
    ) async {
      await pumpReader(tester, text);

      // ⚠️ **`findsWidgets`, not `findsOneWidget`.** The fixture's Markdown opens with its
      // own `# Glossary`, so the title line and the prose both say it — and a row asserting
      // "exactly one" would be asserting something about the fixture rather than about the
      // reader.
      expect(find.text('Glossary'), findsWidgets);
      expect(find.text('Chapter 12'), findsOneWidget);
      expect(find.textContaining('A term is a word'), findsOneWidget);
    });

    testWidgets('⚠️ a `-1` number shows the word, never "Chapter 0"', (
      WidgetTester tester,
    ) async {
      // ⚠️ **B10.** An extra, an omake and an author's note carry the number zero, and rule 9
      // requires an em dash for the unparseable case — so an unparseable chapter must not
      // read as "Chapter 0".
      await pumpReader(
        tester,
        const ChapterText(
          chapterId: 'c1',
          chapterName: 'Omake',
          number: null,
          ordinal: 1,
          markdown: 'A short note.',
          byteLength: 14,
        ),
      );

      // ⚠️ **An em dash, per rule 9** — and emphatically not "Chapter 0".
      expect(find.text('Chapter —'), findsOneWidget);
      expect(find.text('Chapter 0'), findsNothing);
    });

    testWidgets('⚠️ there is NO app bar and no bottom bar over the prose', (
      WidgetTester tester,
    ) async {
      // ⚠️ § 3.5: prose, zero chrome, until a tap. A bar would push the first line of every
      // chapter down a bar's height.
      await pumpReader(tester, text);

      expect(find.byType(AppBar), findsNothing);
      expect(find.byType(NavigationBar), findsNothing);
      expect(find.byType(BottomNavigationBar), findsNothing);
    });

    testWidgets('a tap reveals the chrome, and a second tap hides it', (
      WidgetTester tester,
    ) async {
      await pumpReader(tester, text);

      await tester.tap(proseArea);
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.arrow_back), findsOneWidget);

      await tester.tap(proseArea);
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.arrow_back), findsNothing);
    });
  });

  group('B13 — marked once, on display', () {
    testWidgets('⚠️ exactly one mark, on the first frame that shows prose', (
      WidgetTester tester,
    ) async {
      // ⚠️ **The row that pins § 3.4's timing.** Marking in a tile's `onTap` would catch one
      // of the four ways a reader reaches a chapter; display is the only moment all four
      // share, and the only moment it is true that the reader has seen it.
      final (FakeRepository repository, _) = await pumpReader(tester, text);

      expect(repository.marked, <String>['c1']);
    });

    testWidgets('a rebuild does NOT re-mark', (WidgetTester tester) async {
      // ⚠️ **`read_at` advancing on every scroll settle would make B17's history ordering
      // meaningless** — "opened when" would become "last scrolled when".
      final ValueNotifier<bool> online = ValueNotifier<bool>(true);
      final (FakeRepository repository, _) = await pumpReader(
        tester,
        text,
        connection: online,
      );

      // ⚠️ **A REAL rebuild of `ReaderScreen.build`, with the `ConsumerState` intact.**
      //
      // Two pumps with nothing invalidated do not rebuild at all, and pumping a whole new
      // tree resets the state — so both of those passed with the once-guard removed. A text
      // scale change does **not** work either: only `ChapterProse` depends on `MediaQuery`,
      // so the parent never re-runs `build`. Connectivity *is* watched by the screen's own
      // state, so flipping it rebuilds the reader without replacing the state object.
      online.value = false;
      await tester.pumpAndSettle();
      online.value = true;
      await tester.pumpAndSettle();

      expect(
        repository.marked,
        <String>['c1'],
        reason:
            'read_at advancing on every rebuild would make B17\'s ordering a fiction',
      );
    });

    testWidgets('⚠️ a state with no prose marks NOTHING', (
      WidgetTester tester,
    ) async {
      // ⚠️ **"Opened" means the reader saw a chapter.** A prompt saying "this chapter is not
      // downloaded" is not a chapter, and marking it would put a chapter into the history
      // that was never read.
      final (FakeRepository repository, ValueNotifier<double> scale) =
          await pumpReader(tester, const ChapterNotStored(chapterId: 'c1'));

      expect(repository.marked, isEmpty);
    });
  });

  group('B16 — the position, written at a settle', () {
    testWidgets('⚠️ a finger still down writes NOTHING, and the release does', (
      WidgetTester tester,
    ) async {
      // ⚠️ **The row that rules out the 300 ms `Timer`.** A debounce fires *during* a
      // finger-driven scroll and writes an offset the reader has not reached. This row holds
      // the gesture open across 600 ms — three debounce periods — and asserts the store is
      // still empty.
      final (
        FakeRepository repository,
        ValueNotifier<double> scale,
      ) = await pumpReader(
        tester,
        ChapterText(
          chapterId: 'c1',
          chapterName: 'Long',
          number: 1,
          ordinal: 1,
          markdown: longProse,
          byteLength: 6000,
        ),
      );

      final TestGesture gesture = await tester.startGesture(
        tester.getCenter(proseArea),
      );
      await gesture.moveBy(const Offset(0, -400));
      await tester.pump(const Duration(milliseconds: 600));
      expect(
        repository.positions.writes,
        isEmpty,
        reason:
            'a finger still down is not a settle, and a Timer would write here',
      );

      await gesture.up();
      await tester.pumpAndSettle();
      expect(
        repository.positions.writes,
        isNotEmpty,
        reason:
            'the release IS a settle, and `jumpTo`/`animateTo` count as one too',
      );
    });

    testWidgets('⚠️ the write names THIS chapter, and carries the measured extent', (
      WidgetTester tester,
    ) async {
      // ⚠️ **B16 is per chapter.** A store that wrote a shared key would make reading
      // chapter 12 move chapter 13's position.
      final (
        FakeRepository repository,
        ValueNotifier<double> scale,
      ) = await pumpReader(
        tester,
        ChapterText(
          chapterId: 'c1',
          chapterName: 'Long',
          number: 1,
          ordinal: 1,
          markdown: longProse,
          byteLength: 6000,
        ),
      );

      await tester.fling(proseArea, const Offset(0, -600), 1200);
      await tester.pumpAndSettle();

      expect(repository.positions.writes.first.$1, 'c1');
      // ⚠️ **The extent is passed as measured and the store turns a `0` into `null`.** What
      // must not happen is the screen deciding what counts as a measurement — that rule has
      // one home.
      expect(repository.positions.writes.first.$3, greaterThan(0));
    });
  });

  group('E14 — the platform font size changes mid-read', () {
    testWidgets('⚠️ the prose rebuilds with no clipping and no exception', (
      WidgetTester tester,
    ) async {
      await pumpReader(tester, text);

      // ⚠️ **`MediaQuery.textScalerOf` read in `build` IS the mechanism.** There is no
      // listener and no state to update, so "resize immediately" is a property of the read
      // rather than of a callback someone has to remember to call.
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: ProviderScope(
            overrides: [
              chapterReaderRepositoryProvider.overrideWithValue(
                FakeRepository(text),
              ),
            ],
            child: const _App(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.textContaining('A term is a word'), findsOneWidget);
    });

    testWidgets('⚠️ the largest scale produces no overflow exception', (
      WidgetTester tester,
    ) async {
      // ⚠️ **"No text is clipped" is the absence of a constraint**, and a `RenderFlex`
      // overflow is reported as an exception in debug — so this is the row that actually
      // observes the absence. Asserting the widget tree for "no fixed height" would be a
      // proxy for a fact this observes directly.
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(3)),
          child: ProviderScope(
            overrides: [
              chapterReaderRepositoryProvider.overrideWithValue(
                FakeRepository(text),
              ),
            ],
            child: const _App(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });
}
