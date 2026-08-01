# Lumen Tale

A Flutter application for reading **Web Novels** offline, inspired by [Mihon](https://github.com/mihonapp/mihon).

## Product Overview

- **What it does**: aggregate your favorite web novels in one place, browse catalogue sources, fetch chapter content from websites (HTML), convert it to **Markdown**, store it locally, and read it — including offline.
- **Key difference from Mihon**: Mihon is a manga reader whose sources return *image pages* (`getPageList` → images). Lumen Tale is a *web novel* reader: sources return *chapter HTML content* that is cleaned, converted to Markdown (`.md`), persisted on disk, and rendered by the reader.
- **V1 constraint**: there is **no dynamic extension system**. Sources are plain Dart classes implementing an abstract `Source`; a static registry lists them.

## Tech Stack

| Concern | Choice |
|---|---|
| Language | Dart / Flutter stable (Dart SDK ^3.11.5) |
| State + DI | Riverpod (`flutter_riverpod`, `riverpod_annotation`, `riverpod_generator`) |
| Navigation | `go_router` |
| Database | `drift` (SQLite) + `sqlite3_flutter_libs` |
| Networking | `dio` |
| HTML parsing | `html` |
| HTML → Markdown | `html2md` + custom cleaning layer |
| Immutable models | `freezed` + `json_serializable` |
| Reader | `flutter_markdown` |
| Covers | `cached_network_image` |
| Background jobs | `workmanager` |
| Source preferences | `shared_preferences` |
| File storage | `path_provider`, `path` |

## Architecture

Hybrid: **layered core** + **feature-first UI**.

```
lib/
├── main.dart
├── app/              # bootstrap, go_router, theme
├── core/             # network (dio), database (drift), storage, utils — depends on nothing internal
├── domain/           # PURE DART: Source contract, models, repository interfaces, interactors
├── data/             # drift repositories, mappers, SourceManager
├── sources/
│   └── implementations/  # one class per website + source_registry.dart
└── features/         # UI per feature: library, browse, novel_details, reader, updates, history, downloads, settings
```

Dependency rules:
- `core` depends only on external packages.
- `domain` is pure Dart (no Flutter UI imports) and depends on `core`.
- `data` implements `domain` and depends on `core`.
- `sources/implementations` depend only on `domain/sources` + `core/network`.
- `features/*` never import each other; they communicate through `app` (router, shared providers).
- `app` wires everything together.

## The Source Contract

The heart of the app, transposed from Mihon's `source-api`:

- `abstract class Source` — stable `id` (MD5 of `name/lang/versionId`), `name`, `lang`, `supportsLatest`, `filterList`; methods `getPopularNovels(page)`, `getLatestNovels(page)`, `searchNovels(page, query, filters)`, `getNovelUpdate(...)`, `getNovelDetails(...)`, `getChapterList(...)`.
- `abstract class HttpSource` — `baseUrl`, dio-based HTTP helpers.
- `abstract class ParsedHttpSource` — declarative CSS selectors + `Element → Novel/Chapter` mappers, and `fetchChapterContent(chapter)` returning raw chapter HTML (our replacement for Mihon's `getPageList`).
- Pipeline: `fetchChapterContent → clean (strip ads/nav) → html2md → .md on disk → reader renders`.
- Sources are registered statically in `lib/sources/implementations/source_registry.dart` and resolved by `SourceManager` (like Mihon's `AndroidSourceManager`).

## Commands

| Command | Purpose |
|---|---|
| `flutter pub get` | Resolve dependencies |
| `flutter analyze` | Static analysis (must be clean) |
| `flutter test` | Run tests |
| `dart format .` | Format code |
| `dart run build_runner build --delete-conflicting-outputs` | Regenerate codegen (riverpod/freezed/drift) |

## Rules

Project-specific conventions live in `.opencode/rules/` (loaded as instructions via `opencode.json`). Always read the relevant file(s) before working on a task:

- `01-project-vision.md` — product scope and MVP
- `02-architecture.md` — layers and dependency rules
- `03-source-system.md` — Source contract and how to add a source
- `04-html-to-markdown.md` — the HTML→Markdown pipeline
- `05-state-management.md` — Riverpod conventions
- `06-database.md` — drift schema and migrations
- `07-downloads-offline.md` — downloads and offline storage
- `08-coding-standards.md` — Dart/Flutter style
- `09-widgets-ui.md` — UI conventions
- `10-testing.md` — testing conventions
- `11-git-workflow.md` — git and PR conventions
- `12-ai-agent-workflow.md` — how agents must operate in this repo
