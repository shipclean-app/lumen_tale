// Lumen Tale — the source contract, as pure Dart.
//
// Transposed from Mihon's `source-api` with one substitution: a manga source returns
// **image pages**, a web-novel source returns **chapter HTML**.
// `fetchChapterContent` replaces `getPageList`. That is the whole difference between
// this app and the thing it is modelled on, and it is why the pipeline is
// `fetch → clean → Markdown → .md on disk` rather than `fetch → images → cache`.
//
// ## Every read returns `BrowseOutcome<T>`. None of them returns a list.
//
// `architecture.md` § 5.1 states this in prose and its code block shows
// `Future<NovelsPage>` for four of the methods — the block predates
// `failure-discriminator`. **The prose wins**, and B22 is SC-6: a catalogue method that
// can return a bare list is exactly what SC-6 exists to forbid, because a bare list
// cannot say whether the site had nothing or could not be read.
//
// Pure Dart. `domain` carries no Flutter import (`02-architecture.md`).

import 'package:lumen_tale/domain/sources/browse_outcome.dart';
import 'package:lumen_tale/domain/sources/models/chapter.dart';
import 'package:lumen_tale/domain/sources/models/filter.dart';
import 'package:lumen_tale/domain/sources/models/novel.dart';
import 'package:lumen_tale/domain/sources/models/novels_page.dart';
import 'package:lumen_tale/domain/sources/models/update.dart';

/// What every source must provide. **No dynamic extension system**: sources are plain
/// Dart classes in a static registry (`AGENTS.md`, v1 scope).
abstract class Source {
  /// **Stable, unique id.** MD5 of `'<name.toLowerCase()>/$lang/$versionId'`.
  ///
  /// ⚠️ **Never hand-written.** A hand-written id changes when someone retypes it, and a
  /// stored novel whose source id no longer resolves is a chapter the reader can no
  /// longer refresh. `SourceId.of` computes it, and a test asserts every registered
  /// source's id matches its own derivation.
  String get id;

  String get name;

  /// ISO 639-1 (`en`, `fr`, …). Part of the id, so renaming a language is a **breaking**
  /// change — which is correct: it orphans the reader's library.
  String get lang;

  /// Whether this source has a "latest updates" listing worth showing.
  bool get supportsLatest;

  /// Whether this site **genuinely implements search** — its own search returns results a
  /// reader would call useful.
  ///
  /// ⚠️ **Not a capability the source asserts for its own convenience.** ADR-015: `false`
  /// means the UI offers genre/tag browsing instead and **never** renders a search box.
  /// `18-external-contracts.md` records the per-site measurement, and `6-11` measures
  /// reachability rather than trusting a flag.
  bool get supportsSearch;

  /// Filters this source declares, for search **and** for genre browsing.
  ///
  /// An empty list means no filters. **The platform never interprets their states** (B41):
  /// the values belong to the site and the source owns them.
  FilterList get filterList;

  /// The catalogue, most popular first. [page] is **1-based**, which is what Royal Road's
  /// `?page=` is and what a 0-based default would silently get wrong.
  Future<BrowseOutcome<NovelsPage>> getPopularNovels(int page);

  /// The catalogue, most recently updated first.
  Future<BrowseOutcome<NovelsPage>> getLatestNovels(int page);

  /// Search, [page] 1-based, [query] as the reader typed it.
  ///
  /// ⚠️ [query] is **untrusted input** and reaches the site as a URL parameter. It is
  /// never concatenated into a path (`17-security.md` rule 1), it never reaches a log, and
  /// it never reaches an error surface.
  Future<BrowseOutcome<NovelsPage>> searchNovels(
    int page,
    String query,
    FilterList filters,
  );

  /// What changed since [chapters] was recorded.
  ///
  /// [fetchDetails] and [fetchChapters] let a caller ask for the cheap half. **B38**: this
  /// must never download a chapter body — it compares metadata.
  Future<BrowseOutcome<NovelUpdate>> getNovelUpdate(
    Novel novel,
    List<Chapter> chapters, {
    required bool fetchDetails,
    required bool fetchChapters,
  });

  Future<BrowseOutcome<Novel>> getNovelDetails(Novel novel);

  Future<BrowseOutcome<List<Chapter>>> getChapterList(Novel novel);
}

/// A source reached over HTTP.
abstract class HttpSource extends Source {
  /// **No trailing slash.** Every path a source builds is `'$baseUrl$path'`, and a
  /// trailing slash makes `//list/...` — which some hosts answer and some do not.
  String get baseUrl;

  /// Bump **when URLs break**, so a reader's stored novels keep resolving.
  ///
  /// ⚠️ Part of the source id (`SourceId.of`), so a bump orphans the library unless the
  /// id derivation is version-aware. That is deliberate and is `18-external-contracts.md`
  /// rule 1's whole point: a broken URL must be a **visible, recorded event**, not a
  /// silent 404.
  int get versionId;
}

/// An HTTP source whose pages are parsed from markup.
abstract class ParsedHttpSource extends HttpSource {
  /// **Raw HTML of a chapter.** This is the method that replaces Mihon's `getPageList`.
  ///
  /// `03-source-system.md` rule 11: **conversion to Markdown is not the source's job.** A
  /// source selects the article node, extracts nothing else, joins the pages in the site's
  /// own order when a chapter runs over several, and stops. Everything after that —
  /// cleaning, thresholds, atomic writes — belongs to `2-2` and `2-3`, and a source that
  /// does any of it is a source that cannot be tested against a fixture.
  Future<BrowseOutcome<String>> fetchChapterContent(Chapter chapter);
}
