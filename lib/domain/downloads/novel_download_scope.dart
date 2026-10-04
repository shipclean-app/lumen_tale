// Lumen Tale — the one read a bulk choice needs: this novel's chapters, in its own order.
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

import 'package:lumen_tale/domain/downloads/bulk_choice_resolver.dart';

/// A novel's chapters, as a bulk choice needs to see them.
abstract interface class NovelDownloadScope {
  /// Every chapter of [novelId], **`ordinal` ascending**, with no limit and no window.
  ///
  /// ⚠️ **NEVER SORTED BY `number`.** `number` is `-1` when the site published something
  /// unreadable and it restarts at zero per volume, so a query ordered by it interleaves
  /// the volumes and the queue stops reading in order (B9, B18).
  Future<List<DownloadableChapter>> chaptersOf(String novelId);
}
