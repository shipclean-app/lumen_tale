// Lumen Tale — the library's *view* reads, as interfaces.
//
// `6-6` § 4.2. `domain/library/` — pure Dart, no drift, no Flutter (`02-architecture.md`).
//
// ## ⚠️ WHY THIS EXISTS BESIDE `LibraryRepository` AND NOT INSIDE IT
//
// `LibraryRepository` is `2-5`'s contract, and it answers *what is kept*: one stream, one
// add, one remove, one count. This answers two questions `2-5` never had to ask —
// **what does the screen draw** (a row carrying B14's badge, B22's failure and B49's
// timestamp) and **which ids match a title query** (B45).
//
// Extending `LibraryRepository` instead would have put a second, differently-shaped
// question behind the same interface and made `source_unavailable` and `novel_details`
// depend on two more methods they have no use for.
//
// ## ⚠️ `watchMatchingNovelIds` IS A `Stream` AND NOT A `Future`, FOR ONE REASON
//
// A novel added while a query is already on screen must appear in the results without the
// reader retyping. A `Future` would freeze the id set at the moment the query was typed,
// and the row would sit in the library looking absent until the next keystroke.

import 'package:lumen_tale/domain/library/library_row.dart';
import 'package:lumen_tale/domain/library/library_search.dart';

/// B14, B40, B45, B22, B48, B49, B6, E6, E7 — the library, as the screen reads it.
abstract interface class LibraryRowsRepository {
  /// Every kept novel, with the counts and the facts the row renders.
  ///
  /// ⚠️ **One SQL aggregate for the whole library.** Not one query per novel, and not a
  /// Dart loop over chapters: `06-database.md` rule 8, and B9 says a single novel may
  /// carry 10 000 chapter rows.
  Stream<List<LibraryRow>> watchRows();

  /// The kept novels whose **title** contains the query, in stored order.
  ///
  /// ⚠️ **Ids, not rows.** The counts come from [watchRows] and must be counted **once**;
  /// a second aggregate for the same novel would be a second number free to disagree with
  /// the badge.
  ///
  /// ⚠️ **An empty query is the caller's branch, not this method's.** § 3.1 branch 1 says an
  /// empty query renders the *whole* library, and answering it here would mean a
  /// `LIKE '%%'` round trip for a result identical to [watchRows] — plus a second place
  /// that decides what "no query" means.
  Stream<List<String>> watchMatchingNovelIds(TitleSearch query);
}
