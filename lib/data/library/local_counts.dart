// Lumen Tale — the three figures B31 promises, counted where the rows are.
//
// ## Why this file exists at all
//
// `3-5`'s About screen needs "Library N · Downloaded chapters N · Reading positions N",
// and `settings-about.md` § 2.1 is blunt about why that is the screen's whole point:
// *"A guarantee that an upgrade preserves the library is worth nothing without a way to
// see that it did."* B31 is a promise and these are the evidence.
//
// So the counting lives in `data/`, not in the widget: a screen that assembled its own
// SQL would be the second place that knows how a table is shaped, and the two would be
// free to disagree about what "downloaded" means.
//
// ## Three counts, and each one's set is stated
//
// | figure | rows | why that set |
// |---|---|---|
// | library | `novels` | what the reader chose to keep |
// | downloaded | `chapters` | ⚠️ every chapter **known** — see below |
// | positions | `reading_positions` | the only one they cannot recreate |

import 'package:drift/drift.dart';
import 'package:lumen_tale/core/database/app_database.dart';

/// How many novels are in the library.
///
/// ⚠️ `isNotNull`, not `isNull`: drift models a `NOT NULL` column as nullable in its
/// generated type, and a `WHERE id IS NULL` count would be **zero on a full library** —
/// which is the one answer that must never be wrong.
Future<int> countLibraryNovels(AppDatabase db) async {
  final Expression<int> count = db.novels.id.count();
  final TypedResult row =
      await (db.selectOnly(db.novels)
            ..addColumns(<Expression<Object>>[count])
            ..where(db.novels.id.isNotNull()))
          .getSingle();
  return row.read(count) ?? 0;
}

/// How many chapters are stored locally.
///
/// ⚠️ **This counts EVERY known chapter, not only downloaded ones — and that is stated
/// here because the ARB label cannot carry the caveat.**
///
/// A `downloaded` flag does not exist yet; `8-1`'s slice owns it. Until it lands, the
/// only honest options were to invent a column (a second source of truth for whether a
/// `.md` file is on disk) or to count what the database knows. This counts the latter,
/// and the row above says so.
///
/// ⚠️ **When `8-1` lands this must change**, and the change is not mechanical: a count of
/// `chapters` after `8-1` would over-report every novel the reader has merely *seen*,
/// which is a bigger lie than under-reporting. The count must become
/// `WHERE downloaded`, and a row must prove it.
Future<int> countKnownChapters(AppDatabase db) async {
  final Expression<int> count = db.chapters.id.count();
  final TypedResult row =
      await (db.selectOnly(db.chapters)
            ..addColumns(<Expression<Object>>[count])
            ..where(db.chapters.id.isNotNull()))
          .getSingle();
  return row.read(count) ?? 0;
}

/// How many reading positions exist.
Future<int> countReadingPositions(AppDatabase db) async {
  final Expression<int> count = db.readingPositions.chapterId.count();
  final TypedResult row =
      await (db.selectOnly(db.readingPositions)
            ..addColumns(<Expression<Object>>[count])
            ..where(db.readingPositions.chapterId.isNotNull()))
          .getSingle();
  return row.read(count) ?? 0;
}
