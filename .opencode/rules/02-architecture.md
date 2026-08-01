# Architecture

## Layout

Hybrid: **layered core** (network/database/domain/data/sources) + **feature-first UI**.

```
lib/
├── main.dart
├── app/
│   ├── app.dart                 # ProviderScope + root widget
│   ├── router/                  # go_router definition & route table
│   └── theme/                   # ShadCN / Material 3 theme
├── core/
│   ├── network/                 # dio client, interceptors, rate limiting, headers
│   ├── database/                # drift database, tables, DAOs
│   ├── storage/                 # filesystem layout for downloads/covers
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

## Data flow

1. UI (feature) reads a Riverpod provider → interactor (use case) → repository interface.
2. Repository (data) serves data from drift (streams) or triggers a remote fetch.
3. Remote fetch goes through the `Source` contract in `domain/sources`, implemented by `sources/implementations`.
4. Source returns raw HTML → converted to Markdown → persisted via `core/storage` + the `data` repository.
5. DB changes stream back through drift → Riverpod → reactive UI.
