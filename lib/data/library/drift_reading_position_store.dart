// Lumen Tale — the drift implementation of `ReadingPositionStore`.
//
// `data/` → `core` + `domain` (`02-architecture.md`). This file is where the row and
// the domain value meet, and it is deliberately the *only* place that knows both.
//
// ## Two rules this repository enforces, and why they are here rather than in the UI
//
// **1. An extent of 0 becomes `null`.** The interface takes `double contentHeight`
// because a widget measures a `double`; the column is `int` and nullable because a
// height is either a measurement or it is nothing. Storing `0` for "unmeasured" would
// make `contentHeight == 0` a degenerate ratio the restore refuses to divide by, and
// would make "the chapter is shorter than the window" indistinguishable from "we were
// not told".
//
// **2. `updatedAt` is written by the store, not passed in.** The caller has a position
// in a chapter, not a clock. A repository that accepted a timestamp would let a feature
// invent one, and `updatedAt` is B17's ordering key — a clock handed in from the
// outside is a second source of truth for "when did I last read this".
//
// **Neither position nor timestamp is ever trimmed.** B46 forbids retention-based
// deletion of a position, so the only path that removes a row is [clear], and it is
// called by nothing in v1.

import 'package:drift/drift.dart';
import 'package:lumen_tale/core/database/app_database.dart';
import 'package:lumen_tale/domain/library/reading_position.dart';
import 'package:lumen_tale/domain/library/reading_position_store.dart';

final class DriftReadingPositionStore implements ReadingPositionStore {
  DriftReadingPositionStore(this._db) : _now = _systemClock;

  /// The store's only clock, injectable so a test can assert ordering without waiting.
  DriftReadingPositionStore.withClock(this._db, DateTime Function() now)
    : _now = now;

  static DateTime _systemClock() => DateTime.now();

  final AppDatabase _db;
  final DateTime Function() _now;

  @override
  Future<ReadingPosition?> read(String chapterId) async {
    final PositionRow? row =
        await (_db.select(_db.readingPositions)
              ..where((ReadingPositions t) => t.chapterId.equals(chapterId)))
            .getSingleOrNull();
    return row == null ? null : _toDomain(row);
  }

  @override
  Future<void> write(
    String chapterId,
    double offset, {
    required double contentHeight,
  }) async {
    await _db
        .into(_db.readingPositions)
        .insertOnConflictUpdate(
          ReadingPositionsCompanion.insert(
            chapterId: chapterId,
            // A negative offset cannot come from a ScrollController, and storing one would
            // make `restorePosition`'s `raw <= 0` branch do two unrelated jobs. Clamping
            // here keeps the column's contract "a scroll offset" true for every row.
            offset: Value(offset < 0 ? 0 : offset),
            updatedAt: _now(),
            // ⚠️ Rule 1. `0` is not a measurement.
            contentHeight: Value(
              contentHeight > 0 ? contentHeight.round() : null,
            ),
          ),
        );
  }

  @override
  Future<void> clear(String chapterId) async {
    await (_db.delete(
      _db.readingPositions,
    )..where((ReadingPositions t) => t.chapterId.equals(chapterId))).go();
  }

  @override
  Future<ReadingPosition?> mostRecentAmong(List<String> chapterIds) async {
    if (chapterIds.isEmpty) return null;
    final PositionRow? row =
        await (_db.select(_db.readingPositions)
              ..where((ReadingPositions t) => t.chapterId.isIn(chapterIds))
              // B17 — most recently *written* position first. Deliberately NOT
              // `readAt`, and not history: the position is never trimmed and the
              // history is (B47).
              ..orderBy([
                (ReadingPositions t) => OrderingTerm.desc(t.updatedAt),
                // A deterministic tiebreak. Two rows written in the same millisecond
                // are possible on a fast scroll settle, and without this the order
                // between them is whatever SQLite felt like — which makes a
                // "most recent" answer untestable and a resume non-reproducible.
                (ReadingPositions t) => OrderingTerm.desc(t.chapterId),
              ])
              ..limit(1))
            .getSingleOrNull();
    return row == null ? null : _toDomain(row);
  }

  static ReadingPosition _toDomain(PositionRow row) => ReadingPosition(
    chapterId: row.chapterId,
    offset: row.offset,
    updatedAt: row.updatedAt,
    contentHeight: row.contentHeight,
  );
}
