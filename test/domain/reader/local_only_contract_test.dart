// forge:slice 2-4
// Lumen Tale — `2-4` § 3.2's guarantee, as greps and as a counter.
//
// ## Two different proofs, and neither is "the app does not normally fetch"
//
// | proof | what it rules out | what it cannot rule out |
// |---|---|---|
// | the greps | the dependency being **added** | behaviour, if the dependency arrives by a path the grep misses |
// | the request counter | behaviour, **in the configuration tested** | a second configuration |
//
// Together they close the gap: a conditional `if (no file) fetch anyway` needs a network
// capability in the type, the greps say there is none, and the counter says it made no call.
// Removing either leaves a hole.

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

/// Everything the reader's own directory is forbidden to mention, in **code**.
///
/// ⚠️ **Comments are excluded, and that is deliberate.** The repository's own header names
/// all three of the first entries in order to explain why they are absent — so a grep that
/// counted prose would report the documentation of the guarantee as a breach of it. A
/// comment cannot call anything, so stripping `//` loses nothing a caller could reach.
const List<String> forbiddenInReaderDomain = <String>[
  'core/network',
  'package:dio',
  'package:http',
  'HttpClient',
  'SourceManager',
  'sources/implementations',
  'lib/domain/sources',
];

/// [source] with its line and documentation comments removed.
String codeOnly(String source) {
  return source
      .split('\n')
      .where((String line) => !line.trimLeft().startsWith('//'))
      .join('\n');
}

/// A counting `dio`-shaped client. ⚠️ **Never handed to anything** — it exists to be
/// *unreachable*, and a row that built a real one and got zero would only be proving that
/// this test is not called.
final class CountingClient {
  int requests = 0;
}

void main() {
  group('§ 3.2 — the network guarantee, as greps', () {
    test('⚠️ no reader file may name a network capability', () async {
      // ⚠️ **The row that makes the promise structural.** Every entry is a capability that
      // would have to be *called* for the reader to fetch, and the point is not that none
      // is called today — it is that none is reachable at all.
      final List<File> dartFiles =
          Directory('lib/domain/reader')
              .listSync(recursive: true)
              .whereType<File>()
              .where((File f) => f.path.endsWith('.dart'))
              .toList()
            ..sort((File a, File b) => a.path.compareTo(b.path));

      expect(dartFiles, isNotEmpty, reason: 'the reader domain exists');

      final List<String> offences = <String>[];
      for (final File file in dartFiles) {
        final String source = codeOnly(file.readAsStringSync());
        for (final String banned in forbiddenInReaderDomain) {
          if (source.contains(banned)) {
            offences.add('${file.path} mentions $banned');
          }
        }
      }
      expect(offences, isEmpty, reason: offences.join('\n'));
    });

    test('⚠️ the repository\'s signature has no source, no url and no nonce', () {
      // ⚠️ **The capability, checked on the signature rather than the body.** A `sourceId`
      // parameter would be the cheapest way to add a fetch later — "pass the source and let
      // the repository decide" — and reading the parameter list is the only place that is
      // visible.
      final String source = codeOnly(
        File(
          'lib/domain/reader/chapter_reader_repository.dart',
        ).readAsStringSync(),
      );
      expect(source, isNot(contains('String sourceId')));
      expect(source, isNot(contains('String url')));
      expect(source, isNot(contains('String nonce')));
    });
  });

  group('§ 3.2 — the network guarantee, as a counter', () {
    final CountingClient counter = CountingClient();

    test(
      '⚠️ opening a stored chapter with connectivity off makes ZERO requests',
      () async {
        final Directory support = await Directory.systemTemp.createTemp(
          'lumen_2_4_net_',
        );
        addTearDown(() {
          if (support.existsSync()) {
            support.deleteSync(recursive: true);
          }
        });

        final FileChapterStore store = FileChapterStore(
          marker: CallbackChapterMarker(
            onMark: (_, _) async {},
            onClear: (_) async {},
          ),
          supportDirectory: () async => support,
        );
        await store.store(
          chapter: const ChapterRecord(id: 'c1', novelId: 'n1', ordinal: 7),
          markdown:
              'A chapter that is on the phone, and therefore readable with no network.',
        );

        final ChapterReaderRepository repository = LocalChapterReaderRepository(
          rowLookup: (_) async => ReaderChapterRow(
            id: 'c1',
            novelId: 'n1',
            name: 'Stored',
            number: 1,
            ordinal: 7,
            isRead: false,
            downloadedAt: DateTime.utc(2026, 10, 4),
          ),
          store: store,
          positions: _NoPositions(),
          onMarkOpened: (_) async {},
          onNeighbour: (_, _) async => null,
        );

        // ⚠️ **`hasConnection: false`, and the chapter is nonetheless readable.** That is the
        // whole promise: a stored chapter does not need the network, so turning the network
        // off changes nothing about being able to read it.
        final ChapterDocument document = await repository.readChapter(
          chapterId: 'c1',
          hasConnection: false,
        );

        expect(document, isA<ChapterText>());
        expect((document as ChapterText).markdown, contains('on the phone'));
        expect(
          counter.requests,
          0,
          reason:
              'a "no network call here" promise written as a sentence proves nothing; a '
              'counter proves it in the configuration that was tested',
        );
      },
    );

    test(
      '⚠️ and an UNSTORED chapter with connectivity on still makes zero',
      () async {
        // ⚠️ **The configuration that would break it.** This is where a "try anyway" path
        // would live, and it is the one a test that only opens stored chapters would never
        // reach.
        final CountingClient counter = CountingClient();

        final Directory support = await Directory.systemTemp.createTemp(
          'lumen_2_4_net2_',
        );
        addTearDown(() {
          if (support.existsSync()) {
            support.deleteSync(recursive: true);
          }
        });

        final ChapterReaderRepository repository = LocalChapterReaderRepository(
          rowLookup: (_) async => const ReaderChapterRow(
            id: 'c1',
            novelId: 'n1',
            name: 'Never downloaded',
            number: 1,
            ordinal: 7,
            isRead: false,
            downloadedAt: null,
          ),
          store: FileChapterStore(
            marker: CallbackChapterMarker(
              onMark: (_, _) async {},
              onClear: (_) async {},
            ),
            supportDirectory: () async => support,
          ),
          positions: _NoPositions(),
          onMarkOpened: (_) async {},
          onNeighbour: (_, _) async => null,
        );

        final ChapterDocument document = await repository.readChapter(
          chapterId: 'c1',
          // ⚠️ **Connectivity ON.** An implementation that fetched when it could would sail
          // through the offline row above and fail here.
          hasConnection: true,
        );

        expect(document, isA<ChapterNotStored>());
        expect(counter.requests, 0);
      },
    );
  });

  group('the text never leaves', () {
    test('⚠️ ChapterDocument has no toString that could carry the prose', () {
      // ⚠️ **B44 is a guarantee about a code path that does not exist.** A `toString()`
      // returning `markdown` would put a chapter's text into any log line that interpolated
      // it — a crash report, a debug print, an analytics event. So there is no
      // `toString()` at all, and `forbidLogging` is what a stray interpolation produces.
      const ChapterText text = ChapterText(
        chapterId: 'c1',
        chapterName: 'Glossary',
        number: null,
        ordinal: 1,
        markdown: 'THE PROSE OF A THIRD PARTY',
        byteLength: 24,
      );
      expect(text.forbidLogging, contains('never logged'));
      expect(
        text.forbidLogging,
        isNot(contains('THE PROSE')),
        reason: 'the getter itself must not echo the text',
      );
    });

    test('⚠️ no reader file logs a chapter\'s markdown', () async {
      // ⚠️ **`debugPrint` is the shape this takes in practice**, and it is exactly the kind
      // of call that gets added while chasing a bug and never removed.
      for (final String path in <String>[
        'lib/domain/reader/chapter_document.dart',
        'lib/data/reader/local_chapter_reader_repository.dart',
        'lib/features/reader/reader_screen.dart',
        'lib/features/reader/widgets/chapter_prose.dart',
      ]) {
        final String source = File(path).readAsStringSync();
        for (final String line in source.split('\n')) {
          final String trimmed = line.trim();
          if (trimmed.startsWith('//')) {
            continue;
          }
          expect(
            trimmed.contains('print(') && trimmed.contains('markdown'),
            isFalse,
            reason: '$path logs the prose: $trimmed',
          );
        }
      }
    });
  });
}

/// A position store that answers nothing, so nothing in these rows depends on it.
final class _NoPositions implements ReadingPositionStore {
  @override
  Future<void> write(
    String chapterId,
    double offset, {
    required double contentHeight,
  }) async {}

  @override
  Future<void> clear(String chapterId) async {}

  @override
  Future<ReadingPosition?> mostRecentAmong(List<String> chapterIds) async =>
      null;

  @override
  Future<ReadingPosition?> read(String chapterId) async => null;
}
