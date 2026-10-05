// Lumen Tale — the drift side of the reader's row lookup, and the row it returns.
//
// A separate file from the repository because the row is the **only** thing drift is asked
// for, and a test that wants to exercise the reader's decision can then supply a closure
// instead of an executor — which is the same reason `2-3`'s `ChapterMarker` is two closures.

import 'package:lumen_tale/core/database/app_database.dart';

/// What the reader needs to know about a chapter **row**, and nothing else.
///
/// ⚠️ **Not the drift row type.** A decision function that took an `AppDatabase` row could
/// only be tested with a database, and "which of the seven states is this" is a question
/// about the filesystem and about three columns — not about SQL.
final class ReaderChapterRow {
  const ReaderChapterRow({
    required this.id,
    required this.novelId,
    required this.name,
    required this.number,
    required this.ordinal,
    required this.isRead,
    required this.downloadedAt,
  });

  final String id;
  final String novelId;

  /// B10 — verbatim, and this is what the reader's title line shows.
  final String name;

  /// `-1` means unparseable. ⚠️ **Never collapsed to `0`**: an extra and an author's note
  /// carry the number zero, and `03-source-system.md` rule 9 requires an em dash for the
  /// unparseable case.
  final double number;

  /// B9 — the site's order. The filename, the neighbour lookup and `2-7`'s continuous
  /// scroll all key on this, never on `number`.
  final int ordinal;

  final bool isRead;

  /// B6's mark. `null` is the **only** discriminator for "not downloaded" — ADR-022 made
  /// the mark the fact and the filesystem the data, and probing the disk to answer this
  /// question is the defect it removed.
  final DateTime? downloadedAt;
}

/// Reads one chapter row, or `null` when there is none.
///
/// A closure rather than a database, so `2-4`'s seven branches are testable without an
/// executor — and so the repository's *other* dependency, the filesystem, can be varied on
/// its own.
typedef ChapterRowLookup = Future<ReaderChapterRow?> Function(String chapterId);

/// Reads a chapter row from drift.
///
/// ⚠️ **`select(...).getSingleOrNull()`, never `getSingle()`.** A stale deep link is an
/// ordinary event, and `getSingle()` turns it into an exception that the caller would have
/// to catch to express [ChapterRowGone] — which is the shape that lets a
/// `ChapterRowGone` become a crash.
ChapterRowLookup driftChapterRowLookup(AppDatabase database) {
  return (String chapterId) async {
    final ChapterRow? row =
        await (database.select(database.chapters)
              ..where(($ChaptersTable table) => table.id.equals(chapterId)))
            .getSingleOrNull();

    if (row == null) {
      return null;
    }
    return ReaderChapterRow(
      id: row.id,
      novelId: row.novelId,
      name: row.name,
      number: row.number,
      ordinal: row.ordinal,
      isRead: row.isRead,
      downloadedAt: row.downloadedAt,
    );
  };
}
