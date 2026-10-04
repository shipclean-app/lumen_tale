// forge:slice 5-1
// Lumen Tale — § 3.4's grep, run as a test.
//
// ## ⚠️ WHY THIS FILE IS A TEST AND NOT A COMMENT
//
// § 3.4 says the claim is *mechanically verifiable*:
//
// > `grep -rn 'downloadedAt\|downloaded_at' lib/` must return exactly two write sites:
// > `2-3` and the test. **A third site is a defect**, and `5-2`'s plan makes it look.
//
// B19's first half — *"Paused, cancelled and unfinished chapters are never marked as
// downloaded"* — is then unreachable rather than merely intended, because there is no
// code path that can produce the state it forbids. A comment in the repository saying
// "this never writes the mark" is a promise; this is a scan.
//
// ## ⚠️ **IT SCANS `lib/`, NOT JUST THIS SLICE**
//
// The defect § 3.4 names is *anywhere*, and a scan limited to `domain/downloads` and
// `data/downloads` would pass while a third writer sat in `features/`. The allowlist
// below is the whole of the exemption.
//
// ## ⚠️ **THE ALLOWLIST HAS FOUR ENTRIES AND § 3.4 PREDICTED TWO**
//
// § 3.4 was written before `3-3` landed, and it says the only other site is the test. Two
// more exist now, and both are required by a rule rather than by convenience:
//
//  * `lib/features/downloads/providers.dart` — `3-3`'s `chapterMarkerProvider`. Its own
//    header says it: *"the one writer of `chapters.downloadedAt` … `5-1`'s queue and
//    `3-3`'s tile must write `downloadedAt` through **the same** marker."* Two markers
//    would mean two writers, and B6's order would then depend on which ran last.
//  * `lib/data/downloads/drift_chapter_action_repository.dart` — B33: *"Only deleting a
//    chapter's copy removes its file and clears its `downloadedAt`."* Clearing a mark is a
//    write of that column, and pretending otherwise would make B33 untestable.
//
// Neither may **set** a mark on a chapter that has no file; only `2-3`'s store does that,
// and only after the rename. That asymmetry is asserted in the rows below.
//
// ## ⚠️ **COMMENTS ARE STRIPPED BEFORE THE MATCH**
//
// This file's own prose says `downloadedAt` forty times, and so does
// `file_chapter_store.dart`'s header. A grep that matched comments would be a grep that
// cannot pass, which is a grep that gets switched off — the same trap
// `drift_chapter_action_repository_test.dart`'s *no estimated size* row documents.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The only files in `lib/` allowed to write `downloadedAt` / `downloaded_at`.
///
/// ⚠️ **FOUR PATHS, EACH WITH A RULE BEHIND IT** — see the file header. `2-3` SETS the
/// mark after its rename; `3-3`'s marker is the statement that does the setting; `3-3`'s
/// repository CLEARS it for B33; `core/database` declares the column.
const Set<String> kAllowedMarkWriters = <String>{
  'lib/features/downloads/data/file_chapter_store.dart',
  'lib/features/downloads/providers.dart',
  'lib/data/downloads/drift_chapter_action_repository.dart',
  'lib/core/database/app_database.dart',
};

/// ⚠️ **`Value<` AFTER THE NAME IS THE WHOLE DISCRIMINATOR.**
///
/// A **read** is `DownloadableChapter(downloadedAt: row.downloadedAt)` and
/// `if (row.downloadedAt == null)`. A **write** is a drift companion —
/// `ChaptersCompanion(downloadedAt: Value<DateTime?>(…))` — or SQL assigning the column,
/// or a `copyWith(downloadedAt:)`. The first version of this predicate matched the bare
/// name and reported six offenders, **five of which were reads**, which is how a scan
/// becomes a scan nobody runs.
final RegExp _driftCompanionWrite = RegExp(r'downloadedAt\s*:\s*Value<');
final RegExp _sqlAssignment = RegExp(r'downloaded_at\s*=');
final RegExp _copyWithWrite = RegExp(r'copyWith\(\s*downloadedAt\s*:');

/// Whether [line] writes the mark, as opposed to reading or declaring it.
bool _writesTheMark(String line) =>
    _driftCompanionWrite.hasMatch(line) ||
    _sqlAssignment.hasMatch(line) ||
    _copyWithWrite.hasMatch(line);

void main() {
  group('B19 / § 3.4 — `downloadedAt` is written in exactly one place', () {
    test('⚠️ no `lib/` file outside the allowlist WRITES the mark', () {
      final List<Directory> roots = <Directory>[Directory('lib')];
      expect(
        roots.where((Directory d) => d.existsSync()),
        isNotEmpty,
        reason: 'witness — `lib/` exists, so the scan below is not vacuous',
      );

      final List<String> offenders = <String>[];
      for (final File file in <File>[
        for (final Directory root in roots)
          ...root
              .listSync(recursive: true)
              .whereType<File>()
              .where((File f) => f.path.endsWith('.dart')),
      ]) {
        if (kAllowedMarkWriters.contains(file.path)) {
          continue;
        }
        final List<String> lines = file.readAsStringSync().split('\n');
        for (int i = 0; i < lines.length; i++) {
          final String trimmed = lines[i].trimLeft();
          // ⚠️ **COMMENTS AND GENERATED OUTPUT ARE STRIPPED FIRST.** Generated drift
          // `.g.dart` files repeat the column's declaration; a scan that counted them
          // would be reporting the generator, not a write.
          if (trimmed.startsWith('//') ||
              trimmed.startsWith('*') ||
              trimmed.startsWith('/*') ||
              file.path.endsWith('.g.dart') ||
              file.path.endsWith('.freezed.dart')) {
            continue;
          }
          if (_writesTheMark(trimmed)) {
            offenders.add('${file.path}:${i + 1}  ${trimmed.trim()}');
          }
        }
      }

      expect(
        offenders,
        isEmpty,
        reason:
            'B19/ADR-022: `downloadedAt` is written by `2-3` AFTER its atomic rename, and '
            'the ORDER of those two writes IS B6. A third write site is a chapter that '
            'can be marked downloaded while no fetch has written a file. Offenders: '
            '$offenders',
      );
    });

    test('⚠️ the scan can actually FAIL — a witness, not an assumption', () {
      // ⚠️ **THE ROW THAT KEEPS THE ROW ABOVE HONEST.** A grep that finds nothing because
      // its pattern never matches is a green light wired to nothing. § 3.4's grep has
      // already been written by hand and found nothing; this asserts the *predicate* still
      // recognises a write.
      expect(
        _writesTheMark(
          'ChaptersCompanion(downloadedAt: Value<DateTime?>(now))',
        ),
        isTrue,
        reason: 'witness — a drift companion write is recognised',
      );
      expect(
        _writesTheMark('UPDATE chapters SET downloaded_at = ? WHERE id = ?'),
        isTrue,
        reason: 'witness — a SQL assignment is recognised',
      );
      expect(
        _writesTheMark(
          'DownloadableChapter(downloadedAt: row.downloadedAt, ordinal: 0)',
        ),
        isFalse,
        reason:
            '⚠️ **A READ, AND THE FIRST VERSION FLAGGED IT.** Passing a row\'s mark into a '
            'value object is a READ; without `Value<` after the name this scan reported '
            'five offenders that were all reads, which is how a scan becomes one nobody '
            'runs',
      );
      expect(
        _writesTheMark('if (chapter.downloadedAt != null) return;'),
        isFalse,
        reason:
            'and a nullability check is not a write. Reading the mark is what '
            '`resolveBulkChoice` does on every enqueue — a scan that flagged reads would '
            'flag the whole slice',
      );
      expect(
        _writesTheMark(
          'SELECT q.id FROM queue_items q WHERE q.downloaded_at IS NULL',
        ),
        isFalse,
        reason: 'witness — a SQL predicate is not a write either',
      );
    });

    test('⚠️ `2-3` SETS the mark, and only AFTER its rename (B6)', () {
      // ⚠️ **THE POSITIVE HALF.** A scan that allowlisted nothing and found nothing would
      // pass every assertion above while the app marked chapters nowhere — which is a
      // different lie, and B6's other direction.
      const String store =
          'lib/features/downloads/data/file_chapter_store.dart';
      expect(
        kAllowedMarkWriters,
        contains(store),
        reason:
            '§ 3.4 names `2-3` as the writer. It writes the file, renames it, and only '
            'then calls `_marker.markDownloaded` — and THAT ORDER is B6',
      );
      final String source = File(store).readAsStringSync();
      final int renameAt = source.indexOf('await temp.rename(');
      final int markAt = source.indexOf('await _marker.markDownloaded(');
      expect(
        renameAt,
        greaterThan(-1),
        reason: 'witness — the atomic rename is in this file',
      );
      expect(
        markAt,
        greaterThan(renameAt),
        reason:
            'ADR-022: the RENAME COMES FIRST. A crash between the two leaves a file with '
            'no mark — the safe direction, because the chapter then offers itself for '
            'download. The reverse leaves a mark with no file, and that is the state the '
            'column exists to make unreachable',
      );
    });

    // ⚠️ **THE ASYMMETRY, WHICH IS B33 AGAINST B6.** Three of the four allowed paths can
    // only CLEAR the mark (B33) and one can SET it. If the clearers could set it, a
    // delete would leave a mark for a file that is gone — the reverse lie.
    test('⚠️ the only path that may SET a mark is `2-3`\'s store', () {
      const String clearer =
          'lib/data/downloads/drift_chapter_action_repository.dart';
      expect(
        kAllowedMarkWriters,
        contains(clearer),
        reason:
            'B33: "only deleting a chapter\'s copy removes its file and clears its '
            '`downloadedAt`". Clearing a mark is a write of that column, so excluding '
            'this path would make B33 untestable',
      );
      final List<String> lines = File(clearer).readAsStringSync().split('\n');
      final List<String> companionWrites = <String>[
        for (final String line in lines)
          if (_driftCompanionWrite.hasMatch(line.trimLeft()) &&
              !line.trimLeft().startsWith('//'))
            line.trim(),
      ];

      expect(
        companionWrites,
        hasLength(1),
        reason:
            'exactly ONE companion write of the mark in `3-3`\'s repository, and it is '
            'the CLEAR. A second one would be a path that marks a chapter downloaded '
            'outside `2-3`, which is precisely the third write site § 3.4 forbids. '
            'Found: $companionWrites',
      );
      expect(
        companionWrites.single,
        contains('Value<DateTime?>(null)'),
        reason:
            '⚠️ **AND IT IS `null`.** `deleteStoredCopy` removes the file and then clears '
            'the mark, keeping the `chapters` row (B9/B33). A non-null value here would '
            'be B33\'s delete claiming a copy that is not on the disk',
      );
    });
  });
}
