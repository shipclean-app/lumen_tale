// Lumen Tale — `2-4`'s decision, in one place. Seven branches, all local, no fetch.
//
// ## The order of the branches is the design
//
// `2-4` § 3.1, in the order they run:
//
// ```text
// row absent?          → ChapterRowGone          (not a failure)
// mark null?           → offline+absent | not stored
// file absent?         → ChapterFileMissing      (unreachable by the app)
// file zero bytes?     → ChapterFileEmpty        (interrupted write)
// file unreadable?     → ChapterFileCorrupt
// otherwise            → ChapterText             (zero network calls)
// ```
//
// Each branch is reached only because every earlier one has been ruled out, so a later check
// can never be skipped and an earlier one can never be redundant. That is why
// `downloadedAt` is read **before** the filesystem is touched: the mark is the fact, and the
// disk is consulted only about a chapter that is already known to be stored.
//
// ## `utf8.decode` is STRICT, and never `allowMalformed: true`
//
// A replacement `U+FFFD` in the middle of the prose is a character the reader cannot tell
// from a real one, and it would make a truncated file **look readable** — B6 broken through
// the back door, by a flag that looks like robustness. A `FormatException` is caught and
// becomes `ChapterFileCorrupt(truncatedUtf8)`, which is a sentence the reader can act on.

import 'dart:convert';
import 'dart:io';

import 'package:lumen_tale/data/reader/chapter_row.dart';
import 'package:lumen_tale/domain/library/reading_position_store.dart';
import 'package:lumen_tale/domain/reader/chapter_document.dart';
import 'package:lumen_tale/domain/reader/chapter_reader_repository.dart';
import 'package:lumen_tale/features/downloads/domain/chapter_store.dart';

/// The local read, over a row lookup and a filesystem.
final class LocalChapterReaderRepository implements ChapterReaderRepository {
  const LocalChapterReaderRepository({
    required ChapterRowLookup rowLookup,
    required ChapterStore store,
    required this.positions,
    required Future<void> Function(String chapterId) onMarkOpened,
    required Future<ChapterNeighbour?> Function(
      String chapterId,
      NeighbourDirection direction,
    )
    onNeighbour,
    int maxChapterBytes = kMaxChapterBytes,
  }) : _rows = rowLookup,
       _store = store,
       _onMarkOpened = onMarkOpened,
       _onNeighbour = onNeighbour,
       _maxBytes = maxChapterBytes;

  final ChapterRowLookup _rows;
  final ChapterStore _store;
  final int _maxBytes;

  /// B13 — the write. ⚠️ **A closure, for the same reason `ChapterMarker` is two:** the
  /// repository's own test must be able to assert that `markOpened` does nothing for an
  /// already-read chapter, and a test that needs an executor to observe an *absence* has
  /// already lost the thing it was built to prove.
  final Future<void> Function(String chapterId) _onMarkOpened;

  /// `2-7`'s neighbour lookup, by ordinal.
  final Future<ChapterNeighbour?> Function(
    String chapterId,
    NeighbourDirection direction,
  )
  _onNeighbour;

  /// ⚠️ **A field, exposed through the interface rather than two more methods.** B16 and
  /// B17's operations are already declared on `ReadingPositionStore`, and `2-6`'s
  /// `restorePosition` reads the same rows — a second declaration here would give one
  /// concept two interfaces, and what decides which one a caller used is which file it
  /// imported.
  ///
  /// ⚠️ **Reached through the interface, not re-declared as two more methods.** B16/B17's
  /// operations already exist on `ReadingPositionStore`, and `2-6`'s `restorePosition`
  /// reads the same rows — a second declaration here would give one concept two interfaces,
  /// and what decides which one a caller used is which file it happened to import.
  @override
  final ReadingPositionStore positions;

  @override
  Future<ChapterDocument> readChapter({
    required String chapterId,
    required bool hasConnection,
  }) async {
    // ── fact 1 — does the row exist? ────────────────────────────────────────
    final ReaderChapterRow? row = await _rows(chapterId);
    if (row == null) {
      // ⚠️ **A stale identifier, not a failure.** A deep link the user followed, or a
      // navigation stack restored after the chapter was deleted.
      return const ChapterRowGone();
    }

    // ── fact 2 — is the mark set? This is the ONLY discriminator ────────────
    //
    // ⚠️ **Not "does the file exist".** ADR-022: the mark is the fact, the file is the
    // data. Probing the disk to decide whether a chapter is downloaded is exactly the
    // defect ADR-022 removes — and B33 makes it unfixable, because after a deliberate
    // delete a probe cannot tell "removed on purpose" from "lost".
    final DateTime? markedAt = row.downloadedAt;
    if (markedAt == null) {
      // ⚠️ **Two facts, two sentences.** Each alone leaves the reader unsure whether the
      // button will work.
      return hasConnection
          ? ChapterNotStored(chapterId: chapterId)
          : ChapterOfflineAndAbsent(chapterId: chapterId);
    }

    // ── fact 3 — is the file there, and is it readable? ──────────────────────
    // ⚠️ **`row.novelId` and `row.ordinal`, never the caller's.** See the interface: a
    // caller-supplied ordinal would name a different chapter's file, and the only symptom
    // would be plausible prose from the wrong chapter.
    final File? file = await _store.fileFor(
      ChapterRecord(id: chapterId, novelId: row.novelId, ordinal: row.ordinal),
    );
    if (file == null) {
      // ⚠️ **Unreachable by this application, reachable from outside it.** ADR-022 makes
      // "file without mark" the only direction a crash leaves, so nothing here can produce
      // it — a system clean-up, a restore from elsewhere, or a moved support directory
      // can. So it has a render, and the words say the *download succeeded*.
      return ChapterFileMissing(chapterId: chapterId, markedAt: markedAt);
    }

    final int size = _lengthOf(file);
    if (size == 0) {
      // ⚠️ **Zero bytes is its own case, not corruption.** It is the signature of an
      // interrupted write, so the sentence is about the recording being cut short.
      return ChapterFileEmpty(chapterId: chapterId);
    }

    if (size > _maxBytes) {
      // ⚠️ **Refused before reading, not after.** Reading a file that claims to be 2 GB
      // to then decide it is too big is the failure mode; the size is in the directory
      // entry and costs nothing.
      return ChapterFileCorrupt(
        chapterId: chapterId,
        reason: ReaderFileFailure.notMarkdown,
        byteLength: size,
      );
    }

    final List<int> bytes;
    try {
      bytes = file.readAsBytesSync();
    } on FileSystemException {
      // ⚠️ **Not "corrupt"** — corruption is a conclusion about the *content*, and this
      // is a refusal to read it. The typed reason is what tells the two apart in the
      // reader's sentence.
      return ChapterFileCorrupt(
        chapterId: chapterId,
        reason: ReaderFileFailure.unreadableIo,
        byteLength: size,
      );
    }

    final String text;
    try {
      // ⚠️ **STRICT.** See the file header — `allowMalformed: true` would make a
      // truncated file readable and B6 would be broken by a flag that looks careful.
      text = utf8.decode(bytes);
    } on FormatException {
      return ChapterFileCorrupt(
        chapterId: chapterId,
        reason: ReaderFileFailure.truncatedUtf8,
        byteLength: size,
      );
    }

    // ⚠️ **`trim().isEmpty` is `ChapterFileEmpty`, not a valid chapter.** E22 protects a
    // *short legitimate* chapter, and this is not short: `2-2` refuses to produce one
    // below its threshold (E18), so whitespace-only means an interrupted write.
    if (text.trim().isEmpty) {
      return ChapterFileEmpty(chapterId: chapterId);
    }

    if (!looksLikeMarkdown(text)) {
      // ⚠️ **A guard, not a parser** — and the difference is deliberate. A full Markdown
      // parse on every read is `2-2`'s work repeated at the wrong time; `2-2` already
      // did it once, at write time. What remains to catch is the catastrophic case: a
      // whole HTML page that got renamed into place.
      return ChapterFileCorrupt(
        chapterId: chapterId,
        reason: ReaderFileFailure.notMarkdown,
        byteLength: size,
      );
    }

    return ChapterText(
      chapterId: chapterId,
      chapterName: row.name,
      // ⚠️ **`-1` becomes `null`, not `0`.** B10: 0 is a real chapter number.
      number: row.number == -1 ? null : row.number,
      ordinal: row.ordinal,
      markdown: text,
      byteLength: size,
    );
  }

  /// The file's size, or `0` when it cannot be asked.
  ///
  /// ⚠️ **`0` on an I/O error is deliberate and it is honest about the limit.** A stat that
  /// fails leaves the reader in [ChapterFileEmpty] — "the recording was interrupted" — which
  /// is the least wrong of the available sentences, because the file genuinely cannot be
  /// read. Returning a fake non-zero size instead would push a real I/O failure into
  /// [ReaderFileFailure.notMarkdown], which tells the reader their copy is the problem.
  int _lengthOf(File file) {
    try {
      return file.lengthSync();
    } on FileSystemException {
      return 0;
    }
  }

  @override
  Future<void> markOpened(String chapterId) => _onMarkOpened(chapterId);

  @override
  Future<ChapterNeighbour?> neighbour({
    required String chapterId,
    required NeighbourDirection direction,
  }) => _onNeighbour(chapterId, direction);
}

/// ⚠️ **The largest chapter this reader will open, in bytes.** 2 MiB.
///
/// Royal Road's longest capture in the fixtures is well under 100 KB; the biggest chapter
/// seen on any of the registered sources is a few hundred KB. 2 MiB leaves an order of
/// magnitude of headroom while keeping the failure bounded — a decoder that is handed a file
/// the size of a video will exhaust the heap, and "refuse before reading" is cheaper than
/// "stop halfway through".
const int kMaxChapterBytes = 2 * 1024 * 1024;

/// Whether [text] is Markdown rather than HTML that got renamed into place.
///
/// ⚠️ **Coarse on purpose, and it has a known false positive.** A chapter *about* HTML that
/// contains a literal `<div` in a code block would be refused. That is the cheaper error:
/// the reader is told to download again, the download produces the same file, and the
/// chapter stays unreadable — bad, and visible. The opposite direction would show a whole
/// page of site chrome as the author's prose, and the reader would have no way to tell.
///
/// The check is "does it look like HTML", **not** "does it parse as Markdown": the second is
/// a parser, and a parser on every read is the work `2-2` already did once at write time.
bool looksLikeMarkdown(String text) {
  final String head = text.length <= kHtmlProbeLength
      ? text
      : text.substring(0, kHtmlProbeLength);

  for (final String marker in kHtmlMarkers) {
    if (head.contains(marker)) {
      return false;
    }
  }
  return true;
}

/// ⚠️ **Only the first slice is inspected.** An HTML page is HTML in its first few hundred
/// characters — `<!DOCTYPE`, `<html`, `<head>` — whereas a chapter that merely *mentions* a
/// tag tends to mention it in a code block further down. Reading the whole file for markers
/// would turn every chapter about programming into "corrupt".
const int kHtmlProbeLength = 512;

/// The tags that mean "this is a web page", lowercase, as they appear in practice.
const List<String> kHtmlMarkers = <String>[
  '<!doctype',
  '<html',
  '<head',
  '<body',
  '<div',
  '<span',
  '<script',
  '<style',
];
