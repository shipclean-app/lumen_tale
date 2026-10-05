# Architecture

## Layout

Hybrid: **layered core** (network/database/domain/data/sources) + **feature-first UI**.

```
lib/
├── main.dart
├── l10n/                        # ARB sources (app_en.arb, app_fr.arb) — generated output in .dart_tool
├── app/
│   ├── app.dart                 # ProviderScope + root widget
│   ├── router/                  # go_router definition & route table
│   └── theme/                   # Material 3 theme assembly, tokens, ThemeExtensions
├── core/
│   ├── network/                 # dio client, interceptors, rate limiting, headers
│   ├── database/                # drift database, tables, DAOs
│   ├── storage/                 # filesystem layout for downloads/covers
│   ├── ui/                      # shared presentation only: snackbar/dialog wrappers, async-state body
│   └── utils/                   # logger, extensions, typed errors
├── domain/                      # PURE DART — no Flutter UI imports
│   ├── sources/                 # Source contract + models (Novel, Chapter, Filter, ...)
│   ├── models/                  # freezed domain models
│   ├── repositories/            # abstract repository interfaces
│   └── interactors/             # use cases
├── data/
│   ├── repositories/            # drift-backed implementations
│   ├── mappers/                 # DB entity <-> domain model
│   └── sources/
│       └── source_manager.dart  # resolves sources by id
├── sources/
│   └── implementations/         # one file per website + source_registry.dart
└── features/                    # UI per feature
    ├── library/                 # novel library grid, sorting, filters
    ├── browse/                  # catalogue per source, search, filters
    ├── novel_details/           # details + chapter list + download actions
    ├── reader/                  # markdown reader, scroll position, progress
    ├── updates/                 # new chapters feed
    ├── history/                 # reading history
    ├── downloads/               # download queue / manager UI
    └── settings/                # app + per-source settings
```

### Directory authorities

One concern, one directory, one rule file. Resolve a placement question here first; these are the answers that have already been decided:

| Concern | Directory | Rule file |
|---|---|---|
| Theme assembly, tokens, `ThemeExtension`s | `app/theme/` | `14-design-tokens.md` |
| Shared snackbar / dialog / async-state components | `core/ui/` | `09-widgets-ui.md` |
| Typed exception hierarchy | **`core/error/`** | `13-error-handling.md`. **Moved 2026-10-02 from `core/utils/errors/`**: `core/` is a leaf layer, so an exception that `domain/` must catch cannot live under `core/utils/`, which is internal to `core`. `architecture.md` § 1.2 is the authority for paths |
| Logger | `core/utils/logger.dart` | `13-error-handling.md` rule 6. **Stayed put, and the distinction is the point** (ADR-028): a logger is a general utility, so `core/utils/` is its home. It was nearly moved with the exceptions because `02-architecture.md` listed the two on one row — **two things sharing a table row share a fate, and they should not have shared a row.** |
| DB entity ↔ domain model mapping | `data/mappers/` | `02-architecture.md` §Repository pattern |

## Dependency rules (enforced)

| Layer | May depend on | Must NOT depend on |
|---|---|---|
| `core` | external packages only | any other internal layer |
| `domain` | `core` | Flutter UI, `data`, `features`, `sources/implementations` |
| `data` | `core`, `domain` | `features`, `app` |
| `sources/implementations` | `domain/sources`, `core/network` | `data`, `features`, `app` |
| `features/*` | `core`, `domain`, `data`, `app` (router/theme only) | other `features` |
| `app` | everything | — |

Additional rules:

- `domain` must stay free of Flutter imports (`flutter/material`, `flutter/widgets`, ...). Only `package:flutter/foundation` is allowed where strictly needed; prefer pure Dart.
- `features/*` communicate through `app` (router) and shared Riverpod providers, never via direct imports of each other.
- Public API: define `abstract` repository interfaces in `domain`; `data` holds implementations. Never leak DB/network types into features.
- `core/ui/` is the only place a Flutter widget may live under `core/`, and it receives resolved values — it never calls a repository or a notifier.

## Data flow

1. UI (feature) reads a Riverpod provider → interactor (use case) → repository interface.
2. Repository (data) serves data from drift (streams) or triggers a remote fetch.
3. Remote fetch goes through the `Source` contract in `domain/sources`, implemented by `sources/implementations`.
4. Source returns raw HTML → converted to Markdown → persisted via `core/storage` + the `data` repository.
5. DB changes stream back through drift → Riverpod → reactive UI.

## Repository pattern

**This section owns the mapper and repository-boundary rules.** `06-database.md` states only the drift-specific half (type converters, epoch millis, enum codes) and points back here.

- `domain/repositories` defines `abstract` interfaces; methods return **domain types** (or `Stream<T>`), never DB rows, DTOs, or raw `Map<String, dynamic>`.
- `data/repositories` implements them (drift-backed, dio-backed). Mapping between DB entities and domain models lives in `data/mappers/` as static classes (`fromRow`, `toDomain`, `toInsert`, ...).
- Features depend on the interfaces only — swapping an implementation must not touch UI code.
- Sources (`sources/implementations`) are consumed through the `Source` contract in `domain/sources`, never directly from a feature.

## UI vs logic

- Pages (`features/<f>/screens`) contain **only** UI composition + simple calls (`ref.watch`, `ref.read(...notifier).action`).
- Business logic (validation, orchestration, side effects, IO) lives in Riverpod notifiers + `domain/interactors`.
- If a page/widget approaches ~250 lines, extract sections into `widgets/` and logic into `providers/` / interactors — but never split artificially.