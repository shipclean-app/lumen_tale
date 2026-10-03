// Lumen Tale — "is the library empty?", as a count.
//
// ## Why this file exists and is so small
//
// `history.md` § 4's empty state **chooses its action from a local fact**: *Browse a
// source* when the library is empty, *Open your library* when it is not. A fixed
// string would point a new reader at a library they do not have, and point a reader
// with 200 novels at Browse.
//
// The full library repository belongs to `6-3`, which has not landed. Rather than
// leave two of the screen's four empty-state strings unreachable — dead ARB keys are
// a defect, and an unimplemented branch of `history.md` § 4 is worse — this counts the
// one column the question needs.
//
// **It will be deleted when `6-3` lands**, and `6-3`'s count will take its place.
// That is the only honest description: it is a question asked early of a
// not-yet-existing interface, not a second implementation of the library.

import 'package:drift/drift.dart';
import 'package:lumen_tale/core/database/app_database.dart';

/// How many novels are in the library.
///
/// ⚠️ A `Future<int> Function()` and not a repository interface: one method, one
/// caller, and an interface with one method is a shape every class can satisfy.
typedef LibraryEntryCounter = Future<int> Function();

Future<int> countLibraryNovels(AppDatabase db) async {
  // ⚠️ `isNotNull`, not `isNull`: drift models a `NOT NULL` column as nullable in its
  // generated type, and a `WHERE id IS NULL` count would be **zero on a full
  // library** — which is the one answer that must never be wrong.
  final Expression<int> id = db.novels.id.count();
  final TypedResult row =
      await (db.selectOnly(db.novels)
            ..addColumns(<Expression<Object>>[id])
            ..where(db.novels.id.isNotNull()))
          .getSingle();
  return row.read(id) ?? 0;
}
