// Lumen Tale — `2-4`'s decision, all nine branches, against a real filesystem.
//
// ## Why these rows use REAL files and not a fake store
//
// The decision is mostly about the filesystem: is the file there, is it zero bytes, does it
// decode, does it look like HTML. A fake `ChapterStore` would let every one of those be
// stubbed to whatever the row wanted to prove, which is how a decision function ends up
// "covered" and wrong. So the only fake here is the **row lookup** — the one thing whose
// values are genuinely arbitrary — and the store is `2-3`'s real `FileChapterStore`.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumen_tale/data/reader/chapter_row.dart';
import 'package:lumen_tale/data/reader/local_chapter_reader_repository.dart';
import 'package:lumen_tale/domain/library/reading_position.dart';
import 'package:lumen_tale/domain/library/reading_position_store.dart';
import 'package:lumen_tale/domain/reader/chapter_document.dart';
import 'package:lumen_tale/domain/reader/chapter_reader_repository.dart';
import 'package:lumen_tale/features/downloads/data/file_chapter_store.dart';
import 'package:lumen_tale/features/downloads/domain/chapter_store.dart';

const String novelId = 'n1';
const int ordinal = 526587;
const ChapterRecord record = ChapterRecord(
  id: 'c1',
  novelId: novelId,
  ordinal: ordinal,
);

/// How many times the filesystem was asked for the chapter's file.
final class CountingStore implements ChapterStore {
  CountingStore(this._inner);

  final ChapterStore _inner;
  int fileForCalls = 0;

  @override
  Future<DateTime> store({
    required ChapterRecord chapter,
    required String markdown,
  }) => _inner.store(chapter: chapter, markdown: markdown);

  @override
  Future<File?> fileFor(ChapterRecord chapter) {
    fileForCalls += 1;
    return _inner.fileFor(chapter);
  }

  @override
  Future<void> deleteOne(ChapterRecord chapter) => _inner.deleteOne(chapter);
}

/// A position store that records what it was told, and nothing else.
final class SilentPositionStore implements ReadingPositionStore {
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

/// One harness per row: a temp support tree, a real store, and a row lookup the test sets.
final class Harness {
  Harness._(this.support, this.store, this.rows, this.neighbours);

  static Future<Harness> create() async {
    final Directory support = await Directory.systemTemp.createTemp(
      'lumen_2_4_',
    );
    addTearDown(() {
      if (support.existsSync()) {
        support.deleteSync(recursive: true);
      }
    });
    final FileChapterStore real = FileChapterStore(
      marker: CallbackChapterMarker(
        onMark: (_, _) async {},
        onClear: (_) async {},
      ),
      supportDirectory: () async => support,
    );
    return Harness._(
      support,
      CountingStore(real),
      <ReaderChapterRow?>[],
      <String, ChapterNeighbour?>{},
    );
  }

  final Directory support;
  final CountingStore store;
  final List<ReaderChapterRow?> rows;
  final Map<String, ChapterNeighbour?> neighbours;

  /// Whether [store] was asked about the file.
  bool get touchedDisk => store.fileForCalls > 0;

  /// The path `2-3` writes to.
  File get chapterFile => File('${support.path}/chapters/$novelId/$ordinal.md');

  /// Write the chapter's stored copy without going through the store's mark.
  void writeStored(String bytes, {Encoding encoding = utf8}) {
    chapterFile.parent.createSync(recursive: true);
    chapterFile.writeAsBytesSync(encoding.encode(bytes));
  }

  void writeStoredBytes(List<int> bytes) {
    chapterFile.parent.createSync(recursive: true);
    chapterFile.writeAsBytesSync(bytes);
  }

  ReaderChapterRow? get row => rows.isEmpty ? null : rows.first;

  ChapterRowLookup get lookup =>
      (String id) async => row;

  LocalChapterReaderRepository build({
    bool markOpened = false,
    int maxChapterBytes = kMaxChapterBytes,
  }) {
    return LocalChapterReaderRepository(
      rowLookup: lookup,
      store: store,
      positions: SilentPositionStore(),
      onMarkOpened: (String _) async {
        if (markOpened) {
          // ignore: avoid_print
          print('marked');
        }
      },
      onNeighbour: (String id, NeighbourDirection direction) async =>
          neighbours[id],
      maxChapterBytes: maxChapterBytes,
    );
  }

  Future<ChapterDocument> read({bool hasConnection = true}) {
    return build().readChapter(chapterId: 'c1', hasConnection: hasConnection);
  }
}

/// A row whose mark is set — the normal case.
///
/// ⚠️ **[unmarked] exists as a separate factory rather than as `stored(downloadedAt: null)`.**
/// A `null` parameter whose default is `null` cannot say "explicitly no mark", so a caller
/// passing `null` would be passing the default and reading the `?? fallback` instead. Two
/// factories make the two states two names, which is what they are.
ReaderChapterRow stored({
  String name = 'Glossary',
  double number = 12,
  DateTime? downloadedAt,
  bool isRead = false,
}) => ReaderChapterRow(
  id: 'c1',
  novelId: novelId,
  name: name,
  number: number,
  ordinal: ordinal,
  isRead: isRead,
  downloadedAt: downloadedAt ?? DateTime.utc(2026, 10, 4),
);

/// ⚠️ **A row with NO mark**, which is a different fact and gets its own name.
ReaderChapterRow unmarked({
  String name = 'Glossary',
  double number = 12,
  bool isRead = false,
}) => ReaderChapterRow(
  id: 'c1',
  novelId: novelId,
  name: name,
  number: number,
  ordinal: ordinal,
  isRead: isRead,
  downloadedAt: null,
);

const String chapterBody =
    '# Glossary\n\nA term is a word the author has defined once and then uses everywhere.\n';

void main() {
  group('fact 1 — the row', () {
    test('an absent row is ChapterRowGone, and the disk is NEVER touched', () async {
      // ⚠️ **The disk is not consulted.** A stale identifier is answered from the database
      // alone; a version that probed for a file first would turn "this chapter is not in
      // your library" into "this chapter is not downloaded", which is a different sentence
      // and a wrong one.
      final Harness h = await Harness.create();
      h.rows.add(null);

      expect(await h.read(), isA<ChapterRowGone>());
      expect(h.touchedDisk, isFalse);
    });
  });

  group('fact 2 — the mark is the ONLY discriminator', () {
    test('mark null, with a connection: not stored, disk untouched', () async {
      final Harness h = await Harness.create();
      h.rows.add(unmarked());
      // ⚠️ A file IS present, and it must still be ignored: the mark is the fact, and a file
      // with no mark is the exact state ADR-022 says a crash leaves — so it is treated as
      // not downloaded rather than as a chapter that happens to be readable.
      h.writeStored(chapterBody);

      final ChapterDocument result = await h.read();
      expect(result, isA<ChapterNotStored>());
      expect(h.touchedDisk, isFalse);
    });

    test(
      'mark null, no connection: BOTH facts, and a different type',
      () async {
        final Harness h = await Harness.create();
        h.rows.add(unmarked());

        final ChapterDocument result = await h.read(hasConnection: false);
        expect(result, isA<ChapterOfflineAndAbsent>());
        expect(result, isNot(isA<ChapterNotStored>()));
      },
    );

    test(
      '⚠️ the two connectivity cases are DISTINCT TYPES, not one with a flag',
      () async {
        // ⚠️ A single `ChapterNotStored(offline: true)` would render identically unless every
        // call site remembered to check the flag — and the one place that forgot would tell an
        // offline reader that the button works.
        final Harness h = await Harness.create();
        h.rows.add(unmarked());

        final ChapterDocument online = await h.read();
        final ChapterDocument offline = await h.read(hasConnection: false);
        expect(online.runtimeType, isNot(offline.runtimeType));
      },
    );
  });

  group('fact 3 — the file', () {
    test('marked but absent: ChapterFileMissing carries markedAt', () async {
      // ⚠️ **Unreachable by the app and reachable from outside it** — a system clean-up, a
      // restore from elsewhere. `markedAt` is what lets the copy say "the download
      // succeeded", which is the fact that keeps the reader from thinking it failed.
      final DateTime at = DateTime.utc(2026, 10, 1, 9, 30);
      final Harness h = await Harness.create();
      h.rows.add(stored(downloadedAt: at));

      final ChapterDocument result = await h.read();
      expect(result, isA<ChapterFileMissing>());
      expect((result as ChapterFileMissing).markedAt, at);
    });

    test(
      'zero bytes is ChapterFileEmpty, and NOT ChapterFileCorrupt',
      () async {
        final Harness h = await Harness.create();
        h.rows.add(stored());
        h.writeStoredBytes(<int>[]);

        final ChapterDocument result = await h.read();
        expect(result, isA<ChapterFileEmpty>());
        expect(
          result,
          isNot(isA<ChapterFileCorrupt>()),
          reason:
              'zero bytes is an interrupted write; corrupt means bad content',
        );
      },
    );

    test('whitespace only is ChapterFileEmpty too', () async {
      // ⚠️ `2-2` refuses to produce a chapter below its threshold (E18), so a file of
      // whitespace cannot come from a successful conversion — it can only come from a write
      // that produced nothing.
      final Harness h = await Harness.create();
      h.rows.add(stored());
      h.writeStored('   \n\n\t  ');

      expect(await h.read(), isA<ChapterFileEmpty>());
    });

    test('⚠️ a SHORT but real chapter is NOT refused', () async {
      // ⚠️ **The row that stops E22's threshold being applied twice.** `2-2` guards the
      // write; this guard is a coarse HTML check, and a chapter of 90 real characters is
      // perfectly readable.
      final Harness h = await Harness.create();
      h.rows.add(stored());
      h.writeStored('A short chapter, but a whole one.');

      expect(await h.read(), isA<ChapterText>());
    });

    test('invalid utf-8 is truncatedUtf8, and NEVER decoded lossily', () async {
      // ⚠️ **A `U+FFFD` in the prose is a character the reader cannot tell from a real one,
      // and it would make a truncated file LOOK readable** — B6 broken through the back
      // door by a flag that reads as robustness.
      final Harness h = await Harness.create();
      h.rows.add(stored());
      // A lead byte for a three-byte sequence, then EOF.
      h.writeStoredBytes(<int>[0xE2, 0x82]);

      final ChapterDocument result = await h.read();
      expect(result, isA<ChapterFileCorrupt>());
      expect(
        (result as ChapterFileCorrupt).reason,
        ReaderFileFailure.truncatedUtf8,
      );
      expect(result.reason, isNot(ReaderFileFailure.notMarkdown));
    });

    test('an HTML page renamed into place is notMarkdown', () async {
      final Harness h = await Harness.create();
      h.rows.add(stored());
      h.writeStored(
        '<!DOCTYPE html><html><head><title>x</title></head></html>',
      );

      final ChapterDocument result = await h.read();
      expect(
        (result as ChapterFileCorrupt).reason,
        ReaderFileFailure.notMarkdown,
      );
      expect(result.byteLength, greaterThan(0));
    });

    test('a file past the ceiling is refused WITHOUT being read', () async {
      // ⚠️ Refusing on the directory entry's size, not after decoding: a decoder handed a
      // file the size of a video exhausts the heap, and the failure arrives half way through
      // the chapter.
      final Harness h = await Harness.create();
      h.rows.add(stored());
      h.writeStored('x' * 500);

      final ChapterDocument result = await h
          .build(maxChapterBytes: 100)
          .readChapter(chapterId: 'c1', hasConnection: true);
      expect(result, isA<ChapterFileCorrupt>());
      expect((result as ChapterFileCorrupt).byteLength, 500);
    });

    test('⚠️ a DIRECTORY at the chapter\'s path is "missing", not "unreadable"', () async {
      // ⚠️ **This row corrects a plausible guess.** `File.existsSync()` is **false for a
      // directory**, so a directory where the `.md` should be never reaches the read at
      // all — and "missing" is the right sentence for it, because there is no file to
      // read.
      //
      // The distinction is worth being exact about: `unreadableIo` is for a file that is
      // **there** and the filesystem refused to open it. A directory is not a refusal, it
      // is an absence, and calling it a refusal would tell a reader to retry against
      // something that will never become readable.
      final Harness h = await Harness.create();
      h.rows.add(stored());
      h.chapterFile.parent.createSync(recursive: true);
      Directory(h.chapterFile.path).createSync();

      final ChapterDocument result = await h.read();
      expect(result, isA<ChapterFileMissing>());
      expect(result, isNot(isA<ChapterFileCorrupt>()));
    });

    test(
      'a real chapter comes back as ChapterText, with the name verbatim',
      () async {
        final String longName = 'A ' * 40;
        final Harness h = await Harness.create();
        h.rows.add(stored(name: longName.trim()));
        h.writeStored(chapterBody);

        final ChapterDocument result = await h.read();
        expect(result, isA<ChapterText>());
        final ChapterText text = result as ChapterText;
        expect(text.chapterName, longName.trim());
        expect(text.markdown, contains('A term is a word'));
        expect(text.ordinal, ordinal);
        expect(text.byteLength, greaterThan(0));
      },
    );
  });

  group('B10 — the number', () {
    test('`-1` becomes null, and NEVER 0', () async {
      // ⚠️ **The row that keeps an omake from being "Chapter 0" forever.** Rule 9: an
      // unparseable number renders as an em dash, and 0 is a real chapter number.
      final Harness h = await Harness.create();
      h.rows.add(stored(number: -1));
      h.writeStored(chapterBody);

      final ChapterText text = (await h.read()) as ChapterText;
      expect(text.number, isNull);
    });

    test('`0` stays 0 — an extra, an omake, an author\'s note', () async {
      final Harness h = await Harness.create();
      h.rows.add(stored(number: 0));
      h.writeStored(chapterBody);

      expect(((await h.read()) as ChapterText).number, 0);
    });

    test('a fractional number survives', () async {
      final Harness h = await Harness.create();
      h.rows.add(stored(number: 12.5));
      h.writeStored(chapterBody);

      expect(((await h.read()) as ChapterText).number, 12.5);
    });
  });

  group('looksLikeMarkdown — a guard, and its known blind spot', () {
    test('HTML in the first 512 characters is refused', () {
      expect(looksLikeMarkdown('<html lang="en"></html>'), isFalse);
      expect(looksLikeMarkdown('Prose.\n\n<div class="x">y</div>'), isFalse);
    });

    test('plain prose and Markdown both pass', () {
      expect(looksLikeMarkdown(chapterBody), isTrue);
      expect(looksLikeMarkdown('Just a sentence.'), isTrue);
    });

    test('⚠️ `<div` beyond the probe length is NOT refused — the blind spot', () {
      // ⚠️ **Stated rather than hidden.** A chapter *about* HTML that shows a tag in a
      // code block further down passes, which is correct here; the mirror error — refusing a
      // real chapter — would need the marker inside the first 512 characters.
      //
      // The chosen failure is the cheap one: a refused chapter is visible and the reader is
      // told to download again. The expensive one — showing a whole page of site chrome as
      // the author's prose — would be silent.
      final String late = '${'prose ' * 200}<div class="example"></div>';
      expect(late.length, greaterThan(kHtmlProbeLength));
      expect(looksLikeMarkdown(late), isTrue);
    });

    test(
      'an empty string is not refused by the guard — emptiness is another branch',
      () {
        // ⚠️ The two checks are separate so each reports its own failure: a blank file is an
        // interrupted write and a `<html>` file is a bad one.
        expect(looksLikeMarkdown(''), isTrue);
      },
    );
  });

  group('the repository surface', () {
    test(
      'positions come from the injected store, not a second interface',
      () async {
        // ⚠️ B16/B17's operations are declared once, on `ReadingPositionStore`. Re-declaring
        // them on the reader's repository would give one concept two interfaces and the only
        // thing deciding which one a caller used is which file it imported.
        final Harness h = await Harness.create();
        final SilentPositionStore store = SilentPositionStore();
        final LocalChapterReaderRepository repository =
            LocalChapterReaderRepository(
              rowLookup: h.lookup,
              store: h.store,
              positions: store,
              onMarkOpened: (_) async {},
              onNeighbour: (_, _) async => null,
            );
        expect(repository.positions, same(store));
      },
    );

    test('markOpened and neighbour are the injected writes', () async {
      // ⚠️ A repository that took an `AppDatabase` for these two would make its own tests
      // need an executor to observe an *absence* — and a test that has lost the thing it was
      // built to prove cannot assert it.
      final List<String> calls = <String>[];
      final Harness h = await Harness.create();
      final LocalChapterReaderRepository repository =
          LocalChapterReaderRepository(
            rowLookup: h.lookup,
            store: h.store,
            positions: SilentPositionStore(),
            onMarkOpened: (String id) async => calls.add('mark:$id'),
            onNeighbour: (String id, NeighbourDirection d) async {
              calls.add('neighbour:$id:${d.name}');
              return null;
            },
          );
      await repository.markOpened('c1');
      await repository.neighbour(
        chapterId: 'c1',
        direction: NeighbourDirection.next,
      );
      expect(calls, <String>['mark:c1', 'neighbour:c1:next']);
    });
  });
}
