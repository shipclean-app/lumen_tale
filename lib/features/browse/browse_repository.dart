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

import 'package:flutter/foundation.dart';

import 'package:lumen_tale/core/error/source_failure.dart';
import 'package:lumen_tale/domain/sources/browse_outcome.dart';
import 'package:lumen_tale/domain/sources/models/novels_page.dart';
import 'package:lumen_tale/domain/sources/source.dart';

/// Reads a catalogue from one registered source.
final class BrowseRepository {
  const BrowseRepository({required this.sourceById});

  /// Resolves a source id to a source, or `null` for an id no longer registered.
  final Source? Function(String sourceId) sourceById;

  /// The source's own display name, for a screen's sentences.
  ///
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
    return source.getPopularNovels(request.page);
  }
}

/// One catalogue read, in the site's own terms.
///
/// ⚠️ **[tag] is carried for COPY and is not yet a path.** Royal Road's two catalogue paths are
/// `/fictions/active-popular` and `/fictions/latest-updates`, which are **not tags** — so a
/// request whose tag this implementation silently ignored would show a reader a different tag's
/// novels under the tag they tapped. `6-2` is the slice that turns a tag into a path; until it
/// lands, the tag is used only for the sentence an empty state says, and that limitation is
/// recorded in `18-external-contracts.md` rather than papered over.
@immutable
final class CatalogueRequest {
  const CatalogueRequest({
    required this.sourceId,
    required this.tag,
    this.page = 1,
  });

  final String sourceId;
  final String tag;

  /// The site's own page number, in the site's own base: Royal Road's `?page=N` is 1-based and
  /// a 0-based site's is not translated here.
  final int page;

  @override
  bool operator ==(Object other) =>
      other is CatalogueRequest &&
      other.sourceId == sourceId &&
      other.tag == tag &&
      other.page == page;

  @override
  int get hashCode => Object.hash(sourceId, tag, page);

  @override
  String toString() => 'CatalogueRequest($sourceId/$tag p$page)';
}
