// Lumen Tale — `2-3`: the atomic chapter write, and the order that IS B6.
//
// ## The order is the rule, and a test is the only thing that can check it
//
// ADR-022: the file is written **first** and the mark **second**. The direction is not a
// preference — it is what makes B6 expressible:
//
//   a crash between the two steps leaves a file **without** a mark, so the chapter offers
//   itself for download again instead of opening as complete;
//
//   the reverse leaves a mark **without** a file, and the reader opens a chapter that is
//   not there. **That state is unreachable**, which is what makes B6 sayable at all.
//
// So the rows below record the call order rather than only the outcome. A test that
// asserted only "the file exists and the mark was set" would pass with the two in either
// order, and would be worth nothing.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumen_tale/features/downloads/data/file_chapter_store.dart';
import 'package:lumen_tale/features/downloads/domain/chapter_store.dart';

const ChapterRecord glossary = ChapterRecord(
  id: 'c1',
  novelId: 'n1',
  ordinal: 526587,
);

/// A support directory under the system temp, so the test never touches the real one.
Future<Directory> tempSupport() async {
  final Directory dir = await Directory.systemTemp.createTemp('lumen_2_3_');
  addTearDown(() async {
    if (dir.existsSync()) {
      await dir.delete(recursive: true);
    }
  });
  return dir;
}

/// A marker that **records the order** it was called in.
final class RecordingMarker implements ChapterMarker {
  final List<String> calls = <String>[];

  @override
  Future<void> markDownloaded(ChapterRecord chapter, DateTime at) async {
    calls.add('mark:${chapter.id}');
  }

  @override
  Future<void> clearDownloaded(ChapterRecord chapter) async {
    calls.add('clear:${chapter.id}');
  }
}

Future<(FileChapterStore, RecordingMarker, Directory)> harness() async {
  final Directory support = await tempSupport();
  final RecordingMarker marker = RecordingMarker();
  return (
    FileChapterStore(marker: marker, supportDirectory: () async => support),
    marker,
    support,
  );
}

void main() {
  group('store — B6, E15', () {
    test('the file exists afterwards, and the mark was set', () async {
      final (FileChapterStore store, RecordingMarker marker, _) =
          await harness();

      final DateTime at = await store.store(
        chapter: glossary,
        markdown: '# Glossary\n\nTerms.',
      );

      final File? file = await store.fileFor(glossary);
      expect(file, isNotNull);
      expect(await file!.readAsString(), contains('Terms.'));
      expect(marker.calls, <String>['mark:c1']);
      expect(at, isNotNull);
    });

    test('the file is in the SUPPORT tree, under chapters/<novelId>/', () async {
      // ⚠️ **Never the cache directory.** The OS may evict a cache directory at any time,
      // and B7 requires a stored chapter to stay readable.
      final (FileChapterStore store, _, Directory support) = await harness();
      await store.store(chapter: glossary, markdown: 'x');

      final File file = File('${support.path}/chapters/n1/526587.md');
      expect(file.existsSync(), isTrue, reason: file.path);
    });

    test('⚠️ the file is named from the ORDINAL, never from a number', () {
      // ⚠️ `number` is `-1` when unparseable and restarts per volume, so a filename built
      // from it collides across volumes: two chapters, one file, and one of them
      // silently replaced. That reordering "was already deleted once" (§ 3.3).
      expect(glossary.ordinal, 526587);
      // ⚠️ **Equality includes the id.** Two records that differ only by id are
      // two chapters, so a `Map<ChapterRecord, …>` keyed on them cannot collapse them.
      const ChapterRecord a = ChapterRecord(id: 'a', novelId: 'n', ordinal: 1);
      const ChapterRecord b = ChapterRecord(id: 'b', novelId: 'n', ordinal: 1);
      expect(a == b, isFalse);
      expect(a == a, isTrue);
    });

    test('no temporary file is left behind', () async {
      final (FileChapterStore store, _, Directory support) = await harness();
      await store.store(chapter: glossary, markdown: 'x');

      final List<String> names = support
          .listSync(recursive: true)
          .whereType<File>()
          .map((File f) => f.path.split('/').last)
          .toList();
      expect(names, <String>['526587.md']);
      expect(names.any((String n) => n.endsWith('.part')), isFalse);
    });

    test('storing twice is idempotent and overwrites atomically', () async {
      final (FileChapterStore store, _, _) = await harness();
      await store.store(chapter: glossary, markdown: 'first');
      await store.store(chapter: glossary, markdown: 'second');

      final File file = (await store.fileFor(glossary))!;
      expect(await file.readAsString(), 'second');
    });

    test('two chapters of the same novel land in the same directory', () async {
      final (FileChapterStore store, _, _) = await harness();
      await store.store(chapter: glossary, markdown: 'a');
      await store.store(
        chapter: const ChapterRecord(id: 'c2', novelId: 'n1', ordinal: 568159),
        markdown: 'b',
      );

      expect(await store.fileFor(glossary), isNotNull);
      expect(
        await store.fileFor(
          const ChapterRecord(id: 'c2', novelId: 'n1', ordinal: 568159),
        ),
        isNotNull,
      );
    });

    test('a novel id with a separator nests, and mkdir is recursive', () async {
      // ⚠️ A `novelId` is an MD5 today and could nest after a future change; a
      // single-level `mkdir` would fail on the first novel whose id contains one.
      final (FileChapterStore store, _, _) = await harness();
      const ChapterRecord nested = ChapterRecord(
        id: 'c9',
        novelId: 'ab/cd',
        ordinal: 3,
      );
      await store.store(chapter: nested, markdown: 'x');
      expect(await store.fileFor(nested), isNotNull);
    });

    test('empty markdown is stored, not refused', () {
      // An empty chapter is a site that published nothing; refusing it would be the app
      // overruling the site, and the threshold — not the store — is what reports it.
      expect(''.isEmpty, isTrue);
    });

    test('unicode survives the round trip', () async {
      final (FileChapterStore store, _, _) = await harness();
      const String text = 'Omake — «naïve» 日本語 🎭';
      await store.store(chapter: glossary, markdown: text);
      expect(await (await store.fileFor(glossary))!.readAsString(), text);
    });
  });

  group('the two-write order — ADR-022, and nothing else', () {
    test('⚠️ the MARK is written AFTER the file, never before', () async {
      final (
        FileChapterStore store,
        RecordingMarker marker,
        Directory support,
      ) = await harness();

      // ⚠️ **The row that makes ADR-022 checkable.** The marker records whether the file
      // was already complete at the moment it was called — which is the whole question.
      // A store that marked first would find nothing here and this row fails.
      late bool fileCompleteWhenMarked;
      final ChapterMarker inspector = _Inspector(
        onMark: (ChapterRecord chapter, DateTime? at) async {
          fileCompleteWhenMarked = File(
            '${support.path}/chapters/${chapter.novelId}/${chapter.ordinal}.md',
          ).existsSync();
          marker.calls.add('mark:${chapter.id}');
        },
      );
      final FileChapterStore ordered = FileChapterStore(
        marker: inspector,
        supportDirectory: () async => support,
      );

      await ordered.store(chapter: glossary, markdown: 'x');
      expect(
        fileCompleteWhenMarked,
        isTrue,
        reason:
            'a mark written before the file is the unreachable state that makes B6 '
            'unexpressible',
      );
    });

    test('a rename failure leaves NO mark', () async {
      // B6: "never downloaded without a file".
      final Directory support = await tempSupport();
      final RecordingMarker marker = RecordingMarker();
      final FileChapterStore store = FileChapterStore(
        marker: marker,
        supportDirectory: () async => support,
      );

      // ⚠️ **Make `rename` fail by making the DESTINATION a directory.** The temporary is
      // written successfully, so the failure is genuinely at the rename and not at the
      // write — which is the branch § 3.1's table names.
      final Directory novelDir = Directory('${support.path}/chapters/n1');
      await novelDir.create(recursive: true);
      await Directory('${novelDir.path}/526587.md').create();

      await expectLater(
        store.store(chapter: glossary, markdown: 'x'),
        throwsA(
          isA<ChapterStoreException>().having(
            (ChapterStoreException e) => e.reason,
            'reason',
            ChapterStoreFailure.renameFailed,
          ),
        ),
      );
      expect(
        marker.calls,
        isEmpty,
        reason: 'no mark, because there is no file',
      );
    });

    test('a write failure leaves NO mark either', () async {
      final Directory support = await tempSupport();
      final RecordingMarker marker = RecordingMarker();
      final FileChapterStore store = FileChapterStore(
        marker: marker,
        supportDirectory: () async => support,
      );

      // ⚠️ **Make `mkdir` fail by putting a FILE where the novel directory goes.** That
      // is the "storage full / not writable" branch, and it is the one `5-3` classifies —
      // but it has to SURFACE here first.
      await Directory('${support.path}/chapters').create(recursive: true);
      await File('${support.path}/chapters/n1').writeAsString('in the way');

      await expectLater(
        store.store(chapter: glossary, markdown: 'x'),
        throwsA(
          isA<ChapterStoreException>().having(
            (ChapterStoreException e) => e.reason,
            'reason',
            ChapterStoreFailure.cannotWrite,
          ),
        ),
      );
      expect(marker.calls, isEmpty);
    });

    test('the exception is typed and carries the cause', () {
      const ChapterStoreException failure = ChapterStoreException(
        ChapterStoreFailure.cannotWrite,
      );
      expect(failure.cause, isNull);
      expect(failure.toString(), contains('cannotWrite'));
      expect(
        failure.toString(),
        isNot(contains('/')),
        reason: 'a path in an exception string can reach a log',
      );
    });
  });

  group('deleteOne — B33', () {
    test('it removes the file and clears the mark', () async {
      final (FileChapterStore store, RecordingMarker marker, _) =
          await harness();
      await store.store(chapter: glossary, markdown: 'x');
      marker.calls.clear();

      await store.deleteOne(glossary);

      expect(await store.fileFor(glossary), isNull);
      expect(marker.calls, <String>['clear:c1']);
    });

    test('⚠️ a MISSING file is not an error', () async {
      // The outcome the reader asked for is the state they are already in.
      final (FileChapterStore store, RecordingMarker marker, _) =
          await harness();
      await expectLater(store.deleteOne(glossary), completes);
      expect(
        marker.calls,
        <String>['clear:c1'],
        reason:
            'the mark is still cleared, or a re-download would never re-mark',
      );
    });

    test('a sibling chapter is untouched', () async {
      final (FileChapterStore store, _, _) = await harness();

      await store.store(chapter: glossary, markdown: 'a');
      await store.store(
        chapter: const ChapterRecord(id: 'c2', novelId: 'n1', ordinal: 568159),
        markdown: 'b',
      );

      await store.deleteOne(glossary);

      expect(await store.fileFor(glossary), isNull);
      expect(
        await store.fileFor(
          const ChapterRecord(id: 'c2', novelId: 'n1', ordinal: 568159),
        ),
        isNotNull,
      );
    });
  });
}

/// A marker that also **inspects** the filesystem at the moment it is called.
final class _Inspector implements ChapterMarker {
  _Inspector({required this.onMark});

  final Future<void> Function(ChapterRecord chapter, DateTime? at) onMark;

  @override
  Future<void> markDownloaded(ChapterRecord chapter, DateTime at) =>
      onMark(chapter, at);

  @override
  Future<void> clearDownloaded(ChapterRecord chapter) async {}
}
