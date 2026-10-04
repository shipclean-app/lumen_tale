// Lumen Tale — `SourceManager` seen as the queue's port.
//
// ## ⚠️ **COMPOSITION, NOT INHERITANCE**
//
// `SourceManager` is a `final class` in `data/sources/`, and § 8's dependency table
// gives `data` exactly that. Composition is also what lets the queue depend on a
// `domain/` interface (`ChapterContentSource`) while the registry stays the single
// place that knows a `sourceId` resolves to a source — a subclass would make the queue
// depend on the registry *and* its port.
//
// ## ⚠️ **ONE RESOLUTION PER ATTEMPT, AND IT IS A LOCAL**
//
// `baseUrlOf` and `fetchChapterContent` are two methods, and a lookup function is a
// function: resolving twice could resolve two different sources if the registry changed
// in between. `fetchChapterContent` resolves once into a local and the caller has
// already asked `baseUrlOf` — the pairing the port documents is honoured by
// `baseUrlOf` being a pure projection of the same lookup the fetch uses.
//
// ## ⚠️ **A `Source` THAT CANNOT FETCH CHAPTERS IS `null`, AND THAT IS
// `source_unavailable`**
//
// `Source` has no `fetchChapterContent`; only `ParsedHttpSource` does, and only it can
// return chapter HTML (rule 11 — the substitution for Mihon's `getPageList`). So the
// single `null` case a caller must handle is *"this novel's source is not a
// chapter-content source, or is not in this build at all"* — which is exactly B3's
// *"this novel can no longer be refreshed"*, and exactly one typed code.

import 'package:lumen_tale/core/error/source_failure.dart';
import 'package:lumen_tale/data/sources/source_manager.dart';
import 'package:lumen_tale/domain/downloads/chapter_content_source.dart';
import 'package:lumen_tale/domain/sources/browse_outcome.dart';
import 'package:lumen_tale/domain/sources/models/chapter.dart';
import 'package:lumen_tale/domain/sources/source.dart';

/// The registry, adapted to the two methods the queue needs.
final class SourceRegistryChapterContent implements ChapterContentSource {
  const SourceRegistryChapterContent(this._byId);

  /// Resolves a stored `sourceId` to a source, or `null`. `SourceManager.byId`'s shape.
  final Source? Function(String sourceId) _byId;

  @override
  String? baseUrlOf(String sourceId) {
    final Source? source = _byId(sourceId);
    return source is HttpSource ? source.baseUrl : null;
  }

  @override
  Future<BrowseOutcome<String>> fetchChapterContent({
    required String sourceId,
    required Chapter chapter,
  }) async {
    final Source? source = _byId(sourceId);
    // ⚠️ **NOT REACHABLE THROUGH THE RUNNER, AND IT IS A TYPED FAILURE ANYWAY.** The
    // loop asks `baseUrlOf` first and marks the item failed when it is `null`, so this
    // branch defends a direct caller rather than a path production can take. Returning a
    // `BrowseFailed` — rather than throwing — is the choice B22 makes everywhere else:
    // a caller has one vocabulary, and "the site could not be read" is the sentence that
    // is true here.
    if (source is! ParsedHttpSource) {
      return const BrowseFailed<String>(
        SourceUnavailable(status: 0),
        retriable: false,
      );
    }
    return source.fetchChapterContent(chapter);
  }
}
