# Lumen Tale

A Flutter application for reading **Web Novels** offline, inspired by [Mihon](https://github.com/mihonapp/mihon).

## What it does

Aggregate your favorite web novels in one place, browse catalogue sources, fetch chapter content from websites (HTML), convert it to **Markdown**, store it locally, and read it — including offline.

Unlike Mihon (a manga reader whose sources return *image pages*), Lumen Tale is a **web novel** reader: sources return *chapter HTML content* that is cleaned, converted to Markdown (`.md`), persisted on disk, and rendered by the reader.

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
| Localization | FR + EN via ARB (`gen-l10n`) |

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

The heart of the app, transposed from Mihon's `source-api`. There is **no dynamic extension system** in v1: sources are plain Dart classes, registered statically.

- `abstract class Source` — stable `id` (MD5 of `name/lang/versionId`), `name`, `lang`, `supportsLatest`, `filterList`; methods `getPopularNovels(page)`, `getLatestNovels(page)`, `searchNovels(page, query, filters)`, `getNovelUpdate(...)`, `getNovelDetails(...)`, `getChapterList(...)`.
- `abstract class HttpSource` — `baseUrl`, dio-based HTTP helpers.
- `abstract class ParsedHttpSource` — declarative CSS selectors + `Element → Novel/Chapter` mappers, and `fetchChapterContent(chapter)` returning raw chapter HTML (our replacement for Mihon's `getPageList`).
- Pipeline: `fetchChapterContent → clean (strip ads/nav) → html2md → .md on disk → reader renders`.
- Sources are registered statically in `lib/sources/implementations/source_registry.dart` and resolved by `SourceManager` (like Mihon's `AndroidSourceManager`).

## Getting Started

### Prerequisites

- Flutter stable (Dart SDK ^3.11.5)

### Setup

```sh
flutter pub get
```

### Commands

| Command | Purpose |
|---|---|
| `flutter pub get` | Resolve dependencies |
| `flutter analyze` | Static analysis (must be clean) |
| `flutter test` | Run tests |
| `flutter gen-l10n` | Regenerate FR/EN localizations from ARB |
| `dart format .` | Format code |
| `dart run build_runner build --delete-conflicting-outputs` | Regenerate codegen (riverpod/freezed/drift) |

## Project conventions

Project-specific conventions live in `.opencode/rules/` (01–16): architecture, source system, HTML→Markdown pipeline, state management, database, downloads, coding standards, UI, testing, git workflow, error handling, design tokens, performance, i18n, and agent workflow.

## License

To be determined.
