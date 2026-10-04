// Lumen Tale — the one place a screen asks a source for novels.
//
// ## ⚠️ This is the ONLY route from a screen to a source, and it is deliberately thin
//
// A screen that reached a `Source` itself would have to decide what a failure means, and that
// decision is B22 — which belongs to one mapping (`mapBrowseOutcome`) and nowhere else. So
// this reads and returns the outcome untouched, and adds exactly two things a raw source
// cannot supply: the source's **display name** (ADR-013 resolves it from the compiled
// registry, never from a database column) and the **request path**.
//
// ## ⚠️ No connectivity is decided HERE
//
// `hasConnection` is not a parameter of [readCatalogue] and no probe is consulted. The source
// attempt is the only source of truth about whether the site answered — a connectivity check
// that says "online" and a site that times out would both produce a list-shaped nothing.

import 'package:lumen_tale/core/error/source_failure.dart';
import 'package:lumen_tale/domain/sources/browse_outcome.dart';
import 'package:lumen_tale/domain/sources/models/novels_page.dart';
import 'package:lumen_tale/domain/sources/source.dart';
import 'package:lumen_tale/features/browse/search_outcome.dart';

/// Reads a catalogue from one registered source.
final class BrowseRepository {
  const BrowseRepository({required this.sourceById});

  /// Resolves a source id to a source, or `null` for an id no longer registered.
  final Source? Function(String sourceId) sourceById;

  /// The source's own display name, for a screen's sentences.
  ///
  /// ⚠️ **Whether this source declares a search, and `false` for an unregistered id.**
  ///
  /// The conservative direction: a field that does nothing is worse than no field, and a deep
  /// link to a site this build does not ship must not draw one.
  bool supportsSearchOf(String sourceId) =>
      sourceById(sourceId)?.supportsSearch ?? false;

  /// ⚠️ **`unknown` and never the id.** Printing a raw MD5 where a site name belongs tells a
  /// reader nothing they can act on, and puts an internal identifier on screen.
  String sourceNameOf(String sourceId) =>
      sourceById(sourceId)?.name ?? 'unknown';

  /// Reads page [request.page] of one tag, in the site's own order.
  ///
  /// ⚠️ **The page number goes to the site UNTRANSLATED.** Royal Road's `?page=N` is 1-based
  /// and FanMTL's is 0-based; the base is the site's fact, and a source that translated it
  /// here would make every later page arithmetic a guess.
  Future<BrowseOutcome<NovelsPage>> readCatalogue(
    CatalogueRequest request,
  ) async {
    final Source? source = sourceById(request.sourceId);
    if (source == null) {
      // ⚠️ **A registered id is the only way in**, and an unregistered one is a failure of
      // THIS app's registry rather than of the site. It is still typed, so the screen has one
      // vocabulary for "the catalogue is not available".
      // ⚠️ **Status `0`, and that is honest rather than convenient.** No request was made, so
      // there is no HTTP status to report, and inventing one (`404`, say) would put a number
      // in front of an owner who would go looking for it in a log that does not exist.
      return const BrowseFailed<NovelsPage>(
        SourceUnavailable(status: 0),
        retriable: false,
      );
    }
    // ⚠️ **A search goes to `searchNovels` and a catalogue to `getPopularNovels`.** Routing a
    // search through the catalogue call would return whatever the site ranks first and call it
    // results — which is a confidently wrong list rather than an error.
    if (request case SearchCatalogueRequest(:final String words)) {
      return source.searchNovels(request.page, words, kNoSearchFilters);
    }
    return source.getPopularNovels(request.page);
  }
}

/// What the catalogue screen is reading. **A sealed hierarchy, not an optional field.**
///
/// ⚠️ **"No tag" and "a search" are different requests**, and an optional `String? tag` cannot
/// tell a search from a tag that happens to be null. So the two are two types, and a request is
/// one or the other with no third possibility.
sealed class CatalogueRequest {
  const CatalogueRequest({required this.sourceId, this.page = 1});

  final String sourceId;

  /// The site's own page number, in the site's own base: Royal Road's `?page=N` is 1-based and
  /// a 0-based site's is not translated here.
  final int page;

  @override
  bool operator ==(Object other) =>
      other.runtimeType == runtimeType &&
      other is CatalogueRequest &&
      other.sourceId == sourceId &&
      other.page == page;

  @override
  int get hashCode => Object.hash(runtimeType, sourceId, page);

  @override
  String toString() => 'CatalogueRequest($sourceId p$page)';
}

/// The site's own default catalogue — Royal Road's `/fictions/active-popular`.
final class TagCatalogueRequest extends CatalogueRequest {
  const TagCatalogueRequest({
    required super.sourceId,
    required this.tag,
    super.page,
  });

  final String tag;

  @override
  String toString() => 'TagCatalogueRequest($sourceId/$tag p$page)';
}

/// A search, and the words are the READER'S byte for byte (B41).
final class SearchCatalogueRequest extends CatalogueRequest {
  const SearchCatalogueRequest({
    required super.sourceId,
    required this.words,
    super.page,
  });

  final String words;

  @override
  String toString() => 'SearchCatalogueRequest($sourceId q"$words" p$page)';
}
