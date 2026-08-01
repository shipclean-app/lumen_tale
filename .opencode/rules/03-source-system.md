# Source System

Transposed from Mihon's `source-api`. There is **no dynamic extension system** in v1: every source is a plain Dart class, registered statically.

## Contract

`domain/sources/source.dart`:

```dart
abstract class Source {
  /// Stable, unique id. MD5 of '${name.toLowerCase()}/$lang/$versionId'.
  String get id;

  String get name;
  String get lang;              // ISO 639-1 ('en', 'fr', ...)
  bool get supportsLatest;

  /// Filters declared by the source for search. Empty list = no filters.
  FilterList get filterList;

  Future<NovelsPage> getPopularNovels(int page);
  Future<NovelsPage> getLatestNovels(int page);
  Future<NovelsPage> searchNovels(int page, String query, List<Filter> filters);
  Future<NovelUpdate> getNovelUpdate(
    Novel novel, {
    required bool fetchDetails,
    required bool fetchChapters,
  });
  Future<Novel> getNovelDetails(Novel novel);
  Future<List<Chapter>> getChapterList(Novel novel);
}

abstract class HttpSource extends Source {
  String get baseUrl;               // no trailing slash
  int get versionId => 1;           // bump when URLs break
  // dio-based helpers for GET with shared headers, progress, retry.
}

abstract class ParsedHttpSource extends HttpSource {
  // Declarative CSS selectors (package:html) + Element mappers:
  //   popularNovelsSelector / novelFromElement
  //   searchSelector / novelFromElement
  //   latestSelector / novelFromElement
  //   details selectors + detailNovel
  //   chapterListSelector / chapterFromElement
  //   chapterContentSelector          -> article body

  /// Raw HTML of a chapter. This replaces Mihon's getPageList (images).
  Future<String> fetchChapterContent(Chapter chapter);
}
```

## Rules

1. **Id stability**: `id` is derived from `name/lang/versionId` (MD5). Never hand-write an id; compute it from those three fields so renames keep stable ids.
2. **baseUrl**: no trailing slash. Never hardcode a full URL beyond `baseUrl + relative path`.
3. **Relative URLs**: store relative URLs (path + query) in `Novel.url` / `Chapter.url` via a `setUrlWithoutDomain` helper — never store full URLs (hosts change).
4. **Be gentle**: respect the target site — shared rate limiting, delays, minimal requests, a sane User-Agent from `core/network`. Only scrape sites that permit it.
5. **Filters**: a source *declares* filters in `filterList` and *interprets* their states itself. The platform never interprets filter values.
6. **Configurable sources**: implement `ConfigurableSource` (shared_preferences namespaced `source_<id>`) for per-source options and expose a settings UI in `features/settings`.
7. **`memo`**: `Map<String, dynamic>` for source-internal metadata that must not be shown to users. Keep it small.
8. **Status mapping**: use the shared `NovelStatus` enum (Unknown, Ongoing, Completed, Licensed, PublishingFinished, Cancelled, OnHiatus) and map site-specific statuses into it.
9. **Chapter numbering**: parse numbers with `ChapterRecognition` (regex `[0-9]+(\.[0-9]+)?(\.?[a-z]+)?`; extra/omake/special → 0.99/0.98/0.97). Fall back to `-1` when not parseable.
10. **Errors**: throw typed exceptions (`SourceException` subclasses) from `core/utils`, never bare `Exception`.
11. **Adding a source**: create `sources/implementations/<name>_source.dart` + register it in `source_registry.dart`. Use `/scaffold-source` to bootstrap from a template. Ship parsing unit tests with fixture HTML.

## Models (`domain/sources/models`)

- `Novel` — url, title, author, artist?, status (enum), description?, genres (List<String>), coverUrl?, initialized, updateStrategy, memo.
- `Chapter` — url, name, number (double, `-1` if unknown), scanlator?, dateUpload (DateTime), memo.
- `NovelUpdate` — novel + chapters (result of `getNovelUpdate`).
- `NovelsPage` — novels + hasNextPage (drives pagination; page numbers are 1-based).
- `Page` — used only when a chapter is split across pages: index, url, html/markdown, imageUrl?. **The order of the list is authoritative** — ignore indexes coming from the source.
- `Filter` — sealed class: Header, Separator, Select, Text, CheckBox, TriState, Sort.
- `UpdateStrategy` — AlwaysUpdate | OnlyFetchOnce.
