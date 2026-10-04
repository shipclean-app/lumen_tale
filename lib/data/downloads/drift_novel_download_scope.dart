// Lumen Tale — the one read a bulk choice needs, from drift.
//
// `5-1` § 3.2's first line. Its own interface because `DownloadQueueRepository` is the
// queue's **write** side, and widening that interface to carry a novel's chapter list
// would put a read behind every caller that only ever enqueues.
//
// ## ⚠️ `ORDER BY ordinal ASC`, NO `LIMIT`, NO WINDOW — B9
//
// The plan's B9 row: *"a novel of 10 000 chapters produces 10 000 queue rows, not 50."*
// `resolveBulkChoice` has no global cap of its own — only `NextChapter` and
// `NextChapters(n)` do, and those are the caps B18 asks for — so truncating here would
// silently drop the tail of a 10 000-chapter novel, which is exactly what B9 forbids.
//
// ## ⚠️ **NEVER SORTED BY `number`** B9/B18
//
// `number` is `-1` when the site published something unreadable and it restarts at zero
// in every volume, so a query ordered by it interleaves the volumes and the queue stops
// reading in order. § 10's criterion is checked on a novel where one chapter has
// `number = -1`: that chapter must appear **in its ordinal place**, not at the head.
//
// ## ⚠️ `downloaded_at` IS READ, NEVER WRITTEN HERE
//
// The mark is `2-3`'s to write, after the atomic rename (ADR-022). This class reads it
// to decide "not stored" and writes nothing at all — the same prohibition the queue
// repository holds, from the other side of the join.

import 'package:drift/drift.dart';
import 'package:lumen_tale/core/database/app_database.dart';
import 'package:lumen_tale/domain/downloads/bulk_choice_resolver.dart';
import 'package:lumen_tale/domain/downloads/novel_download_scope.dart';

/// B9 — the chapter list is the site's whole order and must stay complete however long
/// it is, so this read is a filtered, ordered, **unbounded** select.
const int kDownloadScopeReadLimit = -1;

final class DriftNovelDownloadScope implements NovelDownloadScope {
  const DriftNovelDownloadScope(this._db);

  final AppDatabase _db;

  @override
  Future<List<DownloadableChapter>> chaptersOf(String novelId) async {
    final SimpleSelectStatement<$ChaptersTable, ChapterRow> query =
        _db.select(_db.chapters)
          ..where(($ChaptersTable t) => t.novelId.equals(novelId))
          // ⚠️ **`ordinal`, NEVER `number`.** See the file header.
          ..orderBy(<OrderingTerm Function($ChaptersTable)>[
            ($ChaptersTable t) => OrderingTerm.asc(t.ordinal),
          ]);

    final List<ChapterRow> rows = await query.get();
    return List<DownloadableChapter>.unmodifiable(<DownloadableChapter>[
      for (final ChapterRow row in rows)
        DownloadableChapter(
          id: row.id,
          ordinal: row.ordinal,
          isRead: row.isRead,
          // ⚠️ **THE MARK, NOT A PROBE.** ADR-022 made the column the discriminator so a
          // deliberately deleted copy and a lost file can be told apart; a per-row
          // `existsSync` would reintroduce the exact defect that decision removed.
          downloadedAt: row.downloadedAt,
        ),
    ]);
  }
}
