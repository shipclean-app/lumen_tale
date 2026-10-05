// Lumen Tale — B40's question, asked of the local library.
//
// `6-6` Phase 1. `data/` → `core` + `domain` (`02-architecture.md`).
//
// ## ⚠️ THE COMPARISON IS IN DART, AND `2-5` MEASURED WHY
//
// SQLite has no accent folding that matches `normalizeForSimilarity`, so a
// `lower()` / `replace()` chain in SQL would be a **second** normalisation — and two
// normalisations are two answers to "is this the same novel?". The plan writes *two*
// queries here (`exact`, `normalised`); this implementation runs **one** read and both
// comparisons in Dart, which is the same number of rows, one round trip, and one
// normalisation pair.
//
// ## ⚠️ ONE READ OF THE WHOLE KEPT LIST, AND NOT A READ PER CANDIDATE
//
// The candidates are the *only* thing this returns, and the list it scans is a personal
// library — bounded by what one reader chose to keep. Reading it once and comparing in
// memory is one query; reading a row per title in a catalogue would be the N+1
// `06-database.md` rule 8 forbids.
//
// ## ⚠️ NOTHING HERE WRITES, AND THAT IS THE WHOLE OF B40
//
// A `find` that wrote would be a merge wearing a method name, and the return type has
// nowhere to put a write result. `6-6` § 10's `mergeNovel|aliasOf|renameNovel` assertion
// reads `lib/domain/library/` for the *interface*; this file is the implementation it would
// break first.

import 'package:lumen_tale/core/database/app_database.dart';
import 'package:lumen_tale/data/library/drift_library_repository.dart'
    show SourceNameResolver;
import 'package:lumen_tale/domain/library/similar_title.dart';

final class DriftSimilarTitleFinder implements SimilarTitleFinder {
  DriftSimilarTitleFinder(this._db, {SourceNameResolver? sourceNameOf})
    : _sourceNameOf = sourceNameOf ?? _unknownSource;

  final AppDatabase _db;
  final SourceNameResolver _sourceNameOf;

  static String _unknownSource(String sourceId) => 'unknown';

  @override
  Future<List<SimilarTitleCandidate>> find({
    required String candidateTitle,
    String? candidateSourceId,
  }) async {
    // ⚠️ **An unprintable incoming title returns NOTHING, and not the whole library.**
    // `exactSimilarityKey('')` equals nothing and `normalizeForSimilarity('')` equals
    // nothing, so both keys match every row — a dialog listing the reader's entire
    // library against a novel B10 says cannot be displayed at all.
    if (exactSimilarityKey(candidateTitle).isEmpty) {
      return const <SimilarTitleCandidate>[];
    }

    final List<NovelRow> rows = await (_db.select(
      _db.novels,
    )..where(($NovelsTable table) => table.inLibrary.equals(true))).get();

    final List<SimilarTitleCandidate> candidates = <SimilarTitleCandidate>[];
    for (final NovelRow row in rows) {
      final SimilarityTier tier = tierFor(candidateTitle, row.title);
      if (tier == SimilarityTier.none) {
        continue;
      }
      candidates.add(
        SimilarTitleCandidate(
          tier: tier,
          novelId: row.id,
          title: row.title,
          author: row.author,
          sourceName:
              _sourceNameOf(row.sourceId) ?? _unknownSource(row.sourceId),
        ),
      );
    }

    // ⚠️ **`exact` before `normalised`, and BY SOURCE — never deduplicated.**
    // E17: two sites publish the same title, they are two books, and the dialog has to
    // name both so the reader can tell which is which. A `toSet()` here, or a `groupBy`
    // on the title, is the merge B40 forbids with one line of code in it.
    candidates.sort((SimilarTitleCandidate a, SimilarTitleCandidate b) {
      final int byTier = a.tier.index.compareTo(b.tier.index);
      if (byTier != 0) {
        return byTier;
      }
      final int byTitle = a.title.compareTo(b.title);
      return byTitle != 0 ? byTitle : a.novelId.compareTo(b.novelId);
    });

    return List<SimilarTitleCandidate>.unmodifiable(candidates);
  }
}
