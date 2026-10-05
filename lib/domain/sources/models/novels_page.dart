// Lumen Tale — one page of a catalogue read.
//
// `03-source-system.md` § Models: novels + hasNextPage.
//
// ⚠️ **Page numbers are 1-based** at this boundary, because `Source`'s methods
// take a 1-based [page] and the sites disagree about it underneath. The
// conversion happens in the source, once, at the wire — `2-1` § 3.2 — and never
// in this type. A type that carried a zero-based field would make the conversion
// available in two places.
//
// Pure Dart.

import 'package:lumen_tale/domain/sources/models/novel.dart';

/// A page of catalogue results, plus the **site's** own answer to "is there
/// another one?".
///
/// ⚠️ **[hasNextPage] is never inferred from a short page by the app.** It is
/// what the site's own pager said. A source that has no pager — a list of
/// chapters, a genre index with exactly one tag — reports what it knows, and
/// `browse-catalogue.md` § 8 ends the pagination on that value. Inventing a
/// `false` because a page looked short is the app claiming to have reached an end
/// it never reached.
final class NovelsPage {
  NovelsPage({required List<Novel> novels, required this.hasNextPage})
    : novels = List<Novel>.unmodifiable(novels);

  /// Unmodifiable at construction: an outcome is a value, and a caller that
  /// mutates the list it was handed has turned a read into an edit.
  final List<Novel> novels;

  /// Whether the site itself indicated more pages.
  final bool hasNextPage;

  @override
  String toString() =>
      'NovelsPage(${novels.length}, hasNextPage: $hasNextPage)';
}
