// Lumen Tale — the two things the queue needs from a source, behind one port.
//
// `5-1` § 3.3. Pure Dart: the runner programs against this and never against `Source`,
// `HttpSource` or `SourceManager`.
//
// ## ⚠️ WHY ONE PORT AND NOT TWO INJECTIONS
//
// The loop needs the raw HTML **and** the source's `baseUrl`, because the converter
// resolves every `href` and `src` against it (`ConversionRequest.baseUrl`,
// `03-source-system.md` rule 3). Both facts belong to the same `Source` object, so a
// single port returning both is one dependency instead of two that could be given
// **different sources** — a converter resolving against a base URL that is not the one
// the chapter came from produces broken links that no test would catch.
//
// ## ⚠️ **`sourceId` IS A PARAMETER, NOT A FIELD ON THE CHAPTER
//
// A `Chapter` names its novel, not its source, and the source belongs to the **novel**
// (`novels.source_id`, B2). So the runner passes the `sourceId` it joined and the
// implementation resolves it once — which is also what makes the "base URL and fetch
// came from the same source" property above checkable rather than incidental.
//
// ## ⚠️ **`null` IS A REAL STATE, AND IT IS NOT A THROW
//
// B3: a stored novel can name a source this build no longer contains — the source was
// withdrawn, or `versionId` moved and the id derivation changed. That is a chapter the
// app can no longer refresh, and the runner's answer is a typed failure
// (`source_unavailable`), not a crash. `SourceManager.byId` already returns `null` for
// exactly this case rather than throwing, and this port keeps that shape.

import 'package:lumen_tale/domain/sources/browse_outcome.dart';
import 'package:lumen_tale/domain/sources/models/chapter.dart';

/// The chapter-content half of a source, as the queue consumes it.
abstract interface class ChapterContentSource {
  /// The source's `baseUrl` — **no trailing slash**, which every source's is — or `null`
  /// when this build does not contain a chapter-content source under [sourceId].
  ///
  /// ⚠️ **`null` MEANS "NO SUCH SOURCE" AND NOT "NO NETWORK".** Reachability is `5-3`'s
  /// question and is asked at the fetch; conflating the two here would let a reader
  /// offline be told their novel's source is gone.
  String? baseUrlOf(String sourceId);

  /// `ParsedHttpSource.fetchChapterContent`, verbatim, for [sourceId].
  ///
  /// ⚠️ **THE HTML IS RAW.** `03-source-system.md` rule 11: conversion is not the
  /// source's job, and cleaning happens after this returns.
  ///
  /// ⚠️ **CALLED ONLY AFTER [baseUrlOf] RETURNED NON-NULL.** The runner resolves once
  /// and passes the answer, so an implementation may rely on the pairing.
  Future<BrowseOutcome<String>> fetchChapterContent({
    required String sourceId,
    required Chapter chapter,
  });
}
