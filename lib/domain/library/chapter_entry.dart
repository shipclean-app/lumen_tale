// Lumen Tale — one chapter as the LIST displays it. The FOURTH type, and it is not redundant.
//
// `3-2` § 2.2. Four types for four questions, and merging them is how `features/` ends up
// importing drift:
//
// | type | the question it answers |
// |---|---|
// | `Chapter` (the source) | what the **site** publishes |
// | `ChapterRow` (drift) | what the **database** holds |
// | `ChapterMarker` (`2-3`) | what is **on disk**, as two closures |
// | `ChapterEntry` | what the **chapter list** displays |
//
// ## ⚠️ Hand-written, and `LibraryEntry` is why
//
// `3-2`'s plan writes this as `@freezed`, and freezed is a dev dependency. But `2-5`'s
// `LibraryEntry` — the type this one sits beside, in the same directory, answering the same
// shape of question — is hand-written with `operator ==` and `hashCode`. One pattern per
// concern (`AGENTS.md` priority 4) beats the plan's spelling, and a second value-type dialect
// in one folder is exactly the "a new file beats a second way of doing the same thing" line
// taken the other way.

import 'package:lumen_tale/core/error/source_failure.dart';

/// One chapter, as the chapter list shows it.
final class ChapterEntry {
  const ChapterEntry({
    required this.id,
    required this.name,
    required this.ordinal,
    required this.isRead,
    required this.isDownloaded,
    this.number,
    this.downloadProgress,
    this.downloadFailure,
  });

  /// B3 — derived from the novel's id plus the chapter's own url. Never written by hand.
  final String id;

  /// B10 — **the site's own title, verbatim.** Never normalised, never corrected, never rendered
  /// "cleaner". An irregular form — *Ch. 12.5*, *Vol 3*, *Extra*, *Omake*, or nothing at all —
  /// is shown as it is and **is openable**. A site that publishes a chapter with no title still
  /// publishes a chapter.
  final String name;

  /// `03-source-system.md` rule 9 — the number **as the site publishes it**.
  ///
  /// ⚠️ **`null` means UNREADABLE, and that is different from zero.** Zero is a real chapter —
  /// an extra, an omake, an author's note — and collapsing the two is a B10 violation. The tile
  /// renders an em dash for `null` and the site's own text stays whole inside [name].
  final double? number;

  /// B9 — **the site's order, never re-derived from [number].**
  ///
  /// ⚠️ Two reasons, and both have bitten: `number` is `null` when the site published something
  /// unreadable, so it cannot sort; and it restarts at zero in every volume, so sorting by it
  /// interleaves volumes. This is the site's order and nothing else may re-sort it.
  final int ordinal;

  /// B13 — a chapter is unopened until the reader opens it. Opening it clears the mark.
  final bool isRead;

  /// ⚠️ **B6's MARK, not the file.** `true` only when the `.md` was wholly present at the moment
  /// the mark was written — ADR-022 writes the mark **after** the atomic rename, so an
  /// interrupted download leaves `false` and the tile reads *Not downloaded* and **never** a
  /// partial text (E6).
  final bool isDownloaded;

  /// Live, never persisted. `null` → no progress bar, and **not** a zero.
  final double? downloadProgress;

  /// B24 — a typed code, never a free string. `null` → no `failed` state on the tile at all,
  /// because a failure a reader cannot name is a failure they cannot act on.
  final SourceFailure? downloadFailure;

  /// The number as it is shown: an em dash for an unreadable one.
  ///
  /// ⚠️ **`-1` never reaches the screen.** The column's sentinel is a storage fact, and a tile
  /// reading `-1` is a tile showing an integer the site never published. 0 stays `0` — it is a
  /// real chapter.
  String get numberLabel {
    final double? value = number;
    return value == null
        ? '—'
        : value == value.roundToDouble()
        ? '${value.round()}'
        : '$value';
  }

  /// The same chapter at a different position in the site's list.
  ChapterEntry copyWithOrdinal(int ordinal) => ChapterEntry(
    id: id,
    name: name,
    number: number,
    ordinal: ordinal,
    isRead: isRead,
    isDownloaded: isDownloaded,
    downloadProgress: downloadProgress,
    downloadFailure: downloadFailure,
  );

  ChapterEntry copyWith({
    bool? isRead,
    bool? isDownloaded,
    double? downloadProgress,
    SourceFailure? downloadFailure,
  }) {
    return ChapterEntry(
      id: id,
      name: name,
      number: number,
      ordinal: ordinal,
      isRead: isRead ?? this.isRead,
      isDownloaded: isDownloaded ?? this.isDownloaded,
      downloadProgress: downloadProgress ?? this.downloadProgress,
      downloadFailure: downloadFailure ?? this.downloadFailure,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is ChapterEntry &&
      other.id == id &&
      other.name == name &&
      other.number == number &&
      other.ordinal == ordinal &&
      other.isRead == isRead &&
      other.isDownloaded == isDownloaded &&
      other.downloadProgress == downloadProgress &&
      other.downloadFailure == downloadFailure;

  @override
  int get hashCode => Object.hash(
    id,
    name,
    number,
    ordinal,
    isRead,
    isDownloaded,
    downloadProgress,
    downloadFailure,
  );

  @override
  String toString() =>
      'ChapterEntry($ordinal, $name, read: $isRead, downloaded: $isDownloaded)';
}

/// What `2-1` returns for one novel's chapter list.
final class ChapterListFetchResult {
  ChapterListFetchResult({required List<ChapterEntry> entries})
    : entries = List<ChapterEntry>.unmodifiable(entries);

  final List<ChapterEntry> entries;

  /// E3 — the number of **chapters**, never the number of the site's pages.
  ///
  /// ⚠️ **A chapter spread over three pages is ONE entry.** The page-joining happened upstream,
  /// in `2-2`, before this row existed; counting pages here would report a novel with 480
  /// chapters as having 1 100.
  int get chapterCount => entries.length;
}
