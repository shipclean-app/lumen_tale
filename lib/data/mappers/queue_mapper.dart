// Lumen Tale — `queue_items` joined with `chapters` and `novels`, as the domain sees it.
//
// `02-architecture.md` §Directory authorities: *"DB entity ↔ domain model mapping"* lives
// in `data/mappers/`. This is the only place in the codebase that knows a `QueueRow` has
// nine columns, that `chapters.number` carries `-1` for *unparseable*, or that the
// chapter's title is three tables away from the queue row.
//
// ## ⚠️ WHY THE JOIN HAPPENS HERE AND NOT IN THE DOMAIN
//
// `QueueEntry` carries `novelTitle`, `chapterName`, `chapterUrl`, `ordinal` and
// `sourceId`, none of which are columns of `queue_items`. Joining them once, here, is
// what keeps `features/` free of a `TableRow` (§Repository pattern: a drift row never
// crosses `data/` → `features/`) and keeps the three surfaces that draw a queue line —
// the novel's page, the downloads header, the persistent status — reading one query
// rather than three that can disagree.

import 'package:drift/drift.dart' show TypedResult;
import 'package:lumen_tale/core/database/app_database.dart';
import 'package:lumen_tale/domain/downloads/queue_entry.dart';

/// Reads a joined queue row as a [QueueEntry].
///
/// ⚠️ **IT HOLDS THE DATABASE ONLY TO NAME THE THREE TABLES.** `TypedResult.readTable`
/// is keyed by the table instance, so the mapper needs the same instances the query was
/// built from; the mapping itself touches no I/O.
final class QueueMapper {
  const QueueMapper(AppDatabase database) : _db = database;

  final AppDatabase _db;

  QueueEntry fromJoined(TypedResult row) {
    final QueueRow item = row.readTable(_db.queueItems);
    final ChapterRow chapter = row.readTable(_db.chapters);
    final NovelRow novel = row.readTable(_db.novels);

    return QueueEntry(
      id: item.id,
      chapterId: item.chapterId,
      novelId: chapter.novelId,
      novelTitle: novel.title,
      chapterName: chapter.name,
      sourceId: novel.sourceId,
      chapterUrl: chapter.url,
      ordinal: chapter.ordinal,
      // ⚠️ **`-1` BECOMES `null`, AND `0` STAYS `0`.** The sentinel is a storage fact
      // (`03-source-system.md` rule 9) and must never reach a tile: an unparseable title
      // is neither chapter zero nor chapter minus one, and 0 is a real chapter — an
      // extra, an omake, an author's note. `ChapterEntry` makes the same mapping, and
      // making it in two places is cheaper than having two places disagree.
      chapterNumber: chapter.number == -1 ? null : chapter.number,
      state: item.state,
      queuePosition: item.queuePosition,
      addedAt: item.addedAt,
      startedAt: item.startedAt,
      finishedAt: item.finishedAt,
      attempts: item.attempts,
      // ⚠️ **`''`, NOT `null`.** The column is nullable for an older build's sake;
      // `architecture.md` § 4.5's empty string is what the domain sees, so
      // `errorCode.isEmpty` is one test and a null check is not needed at every call
      // site.
      errorCode: item.errorCode ?? '',
    );
  }
}
