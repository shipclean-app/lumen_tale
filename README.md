# Lumen Tale

A Flutter application for reading **web novels** offline, inspired by [Mihon](https://github.com/mihonapp/mihon).

> **Status: early.** The toolchain, dependencies, localization, and the agent rule set are in place. **No feature code exists yet** — there are no screens, no database, and no sources. `lib/` is a localization-and-theme bootstrap.

## What it does

Aggregate your favourite web novels in one place, browse catalogue sources, fetch chapter content from websites, read it, and keep it for offline reading.

Unlike Mihon (a manga reader whose sources return *image pages*), Lumen Tale is a *web novel* reader: sources return *chapter HTML content* that is cleaned, converted to Markdown, persisted on disk, and rendered by the reader.

The pipeline is the product:

```
Source website (HTML)
  → Source.fetchChapterContent(chapter)     raw HTML
  → clean: strip nav, ads, scripts, boilerplate (per-source selectors)
  → HTML → Markdown (first-party converter, built on package:html)
  → persist: chapter .md file + metadata on disk
  → render: Markdown reader (flutter_markdown_plus)
```

## Tech stack

| Concern | Choice |
|---|---|
| Language | Dart 3.13.5 / Flutter **3.47.6** (stable) |
| State + DI | Riverpod (`flutter_riverpod`, `riverpod_annotation`, `riverpod_generator`) |
| Navigation | `go_router` |
| Database | `drift` (SQLite) + `sqlite3` 3.x |
| Networking | `dio` |
| HTML parsing | `html` |
| HTML → Markdown | **first-party converter** on `package:html` (see below) |
| Immutable models | `freezed_annotation` + `json_annotation` (+ `freezed`, `json_serializable` as dev deps) |
| Reader | `flutter_markdown_plus` |
| Covers | `cached_network_image` |
| Background jobs | `workmanager` |
| Source preferences | `shared_preferences` |
| File storage | `path_provider`, `path` |
| Localization | FR + EN via ARB (`gen-l10n`) |

### Why the Markdown converter is ours

The obvious library, `html2md`, is **unusable**: every published version declares `sdk: >=2.12.0 <3.0.0`, so it is Dart 2 only and cannot resolve on Dart 3. Every Dart-3-capable alternative on pub.dev is a native/FFI binding (`h2m` via `flutter_rust_bridge`, `html_to_markdown_rust`, `html_to_markdown_ffi`), which would add a native build toolchain — NDK for Android, possibly `rustup`/`cargo` on every machine and in CI — to a mobile reader purely to convert chapter bodies.

So the converter is written directly against `package:html`, which was already a dependency for the selectors and the cleaning pass. Rationale and alternatives: `DECISIONS.md` ADR-003.

## Getting started

### Prerequisites

Flutter **3.47.6** or another release satisfying `sdk: ^3.11.5` (Dart `>=3.11.5 <4.0.0`). Install Flutter, then put it on your `PATH`:

```sh
export PATH="$HOME/flutter/bin:$PATH"
flutter --version
```

### Setup

```sh
flutter pub get
```

Dependencies are managed **only** through `flutter pub add` / `flutter pub remove` — never by editing `pubspec.yaml` by hand.

### Commands

| Command | Purpose |
|---|---|
| `flutter pub get` | Resolve dependencies |
| `flutter analyze` | Static analysis (must be clean) |
| `flutter test` | Run tests |
| `flutter gen-l10n` | Regenerate FR/EN localizations from ARB |
| `dart format .` | Format code |
| `dart run build_runner build --delete-conflicting-outputs` | Regenerate codegen (riverpod/freezed/json_serializable/drift) |
| `dart run drift_dev schema dump lib/core/database` | Export a drift schema snapshot after a schema change |
| `flutter build apk` | Android build (requires an Android SDK) |

## Architecture

Hybrid: **layered core** + **feature-first UI**. The layout below is the **target**; most of these directories do not exist yet.

```
lib/
├── main.dart
├── l10n/          # ARB sources + generated AppLocalizations
├── app/           # bootstrap, go_router, theme
├── core/          # network (dio), database (drift), storage, ui, utils
├── domain/        # PURE DART — Source contract, models, repository interfaces, interactors
├── data/          # drift repositories, mappers, SourceManager
├── sources/       # implementations/ — one class per website + source_registry.dart
└── features/      # library, browse, novel_details, reader, updates, history, downloads, settings
```

Dependency rules: `core` depends only on external packages · `domain` is pure Dart and depends on `core` · `data` implements `domain` · `sources/implementations` depend only on `domain/sources` + `core/network` · `features/*` never import each other · `app` wires everything.

## The Source Contract

Transposed from Mihon's `source-api`. **No dynamic extension system** in v1: sources are plain Dart classes, registered statically.

- `abstract class Source` — stable `id` (MD5 of `name/lang/versionId`), `name`, `lang`, `supportsLatest`, `filterList`; `getPopularNovels`, `getLatestNovels`, `searchNovels`, `getNovelUpdate`, `getNovelDetails`, `getChapterList`.
- `abstract class HttpSource` — `baseUrl`, dio-based HTTP helpers.
- `abstract class ParsedHttpSource` — declarative CSS selectors + `Element → Novel/Chapter` mappers, and `fetchChapterContent(chapter)` returning **raw chapter HTML** (our replacement for Mihon's `getPageList`).
- Registered statically in `lib/sources/implementations/source_registry.dart` and resolved by `SourceManager` (like Mihon's `AndroidSourceManager`).

## Localization

French and English ship together, French first. `l10n.yaml` points `gen-l10n` at `lib/l10n/app_en.arb` (template) and `lib/l10n/app_fr.arb`, writing to `lib/l10n/generated/`. An unsupported system locale resolves to French.

Add a string to **both** ARB files in the same change, then run `flutter gen-l10n`.

## Contributing

Project conventions live in `.opencode/rules/` (01–18): project vision, architecture, the source system, the HTML→Markdown pipeline, state management, database, downloads, coding standards, UI, testing, git workflow, agent workflow, error handling, design tokens, performance, i18n, security, and external-site contracts.

`AGENTS.md` is the entry point: it carries the verified toolchain, the priority ranking, the definition of done, and the index of every rule file with the trigger for reading it.

## License

To be determined.