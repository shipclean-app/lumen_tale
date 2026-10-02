---
type: architecture
status: draft
generated_at: 2026-10-02
derived_from: .forge/prd.md
impl_waves: 6
impl_waves_rationale: >-
  Coarser than the computed topological minimum of 11, and deliberately so.
  The 11 waves are what the dependency graph *permits*; six are the roadmap's
  milestone waves, which is what it *intends*. They differ because the graph
  allows cheap slices that touch only foundations — 2-6 (reading position), 3-5
  (about), 6-5 (history), 6-7 (English) — to start in wave 1, while the roadmap
  holds them for later milestones. Declaring 11 would erase the milestone
  grouping, and declaring nothing would leave `dependency-check --write` free to
  overwrite the distinction without saying so. The difference that matters:
  browse UI (3-1) is topologically available at wave 4, but milestone Wave 2
  completes the whole offline chain ending at 2-4, so following the milestones
  puts the offline read proof BEFORE any browse UI exists.
---

# Architecture — Lumen Tale

> How the product is structured technically. It turns the PRD's needs into modules, slices, foundations, data models and contracts.
>
> **Granularity rule**: every entity, field and contract is documented — not summarised, not sampled. A field omitted here is a bug at implementation.

---

## 1. Overview

### 1.1 Technical stack

Versions are the **resolved** ones, verified against `pubspec.lock`. The table in `AGENTS.md` is the human-readable copy; this one is the contractual one.

| Domain | Choice | Version | Why |
|---|---|---|---|
| Language | Dart | 3.13.5 | Ships with Flutter; satisfies `sdk: ^3.11.5` |
| Framework | Flutter | 3.47.6 | Material 3 primitives; `AGENTS.md` forbids Cupertino and ShadCN (ADR-001) |
| Database | SQLite via `sqlite3` | 3.7.0 | ADR-005: `sqlite3_flutter_libs` resolves to `0.6.0+eol` and is unusable |
| ORM / query builder | drift | 2.35.1 | ADR-005. Chosen over Mihon's SQLDelight for generated type-safe Dart |
| State management | Riverpod (`flutter_riverpod` + `riverpod_annotation`) | 3.4.3 / 4.0.7 | ADR-008: `Future` + Riverpod, not Kotlin coroutines + Rx |
| Validation | hand-written guards, no library | — | **Deliberate.** `pubspec.yaml` declares no validator. The PRD's rules are conditions, not schemas; a validator would imply a server contract this app does not have (§ 5) |
| HTTP client | dio | 5.11.1 | Interceptors for the honest User-Agent, rate limiting and `Retry-After` (`17-security.md` rules 5–6) |
| HTML parsing | `package:html` | 0.15.7 | ADR-003: `html2md` is Dart-2 only on **every** published version |
| HTML→Markdown | **first-party converter** | — | ADR-003. `html2m`/`html_to_markdown_ffi` would add a native dep for a problem `package:html` solves |
| Markdown rendering | `flutter_markdown_plus` | 1.0.12 | ADR-006: `flutter_markdown` is discontinued |
| Local storage | `shared_preferences` | 2.5.5 | Settings only. **Never** chapter content — see § 4.4 |
| Filesystem | `path_provider` + `path` | 2.1.6 / 1.9.1 | Application **support** directory, not cache — § 4.4 |
| Networking (background) | `workmanager` | 0.10.10 | B37's foreground job. **No v1 slice implements it** — the earlier note pointed at `6-4`, which is the *manual* update and does not carry it. `6-4` owns B37 only if the `roadmap.md` § 3.5 reduction is refused. See `benchmarks.md` § 4b |
| Internationalisation | `flutter_localizations` + `gen_l10n` | SDK | FR primary, EN complete. Fallback chain is FR (B28) |
| Images | `cached_network_image` | 4.0.4 | Covers only. A missing cover degrades to initials — never blocks a read |
| Tests | `flutter_test` + `mocktail` | SDK / 1.0.5 | `mocktail`, not `mockito`: no codegen, no build-runner coupling in tests |
| Lint / Format | `flutter_lints` | 6.0.0 | DoD requires **zero** issues including zero `info` |

**Nothing else may be added.** `08-coding-standards.md` § Dependencies: `flutter pub add` is the only way to change dependencies, and `AGENTS.md` carries the banned list with a reason for each.

### 1.2 Target folder structure

```
lib/
├── main.dart                     bootstrap only — no `home:`, no feature code
├── l10n/                         ARB sources + generated AppLocalizations
├── app/                          theme assembly, router, shell         — no feature imports
├── core/                         external packages only                — no internal deps
│   ├── database/                 app_database.dart (the schema), DAOs
│   ├── network/                  dio client, honest UA, rate limiter, retry
│   ├── storage/                  chapter files, atomic write, paths
│   ├── error/                    AppException hierarchy
│   ├── ui/                       shared widgets: NovelRow, ChapterListTile, EmptyState…
│   └── utils/                    markdown converter, chapter recognition
├── domain/                       PURE DART — no Flutter import at all
│   ├── sources/                  Source contract, models, repository interfaces
│   ├── library/                  library, history, position models + interfaces
│   ├── downloads/                queue models + interfaces
│   └── interactors/              use cases: checkForUpdates, downloadNovel, resumeChapter
├── data/                         drift DAOs, mappers, repository implementations
│   └── sources/                  SourceManager, the static registry
├── sources/
│   └── implementations/          fanmtl_source.dart, royalroad_source.dart + registry
└── features/                     library, browse, reader, updates, history,
                                  downloads, sources, settings, onboarding
```

**Layer rules, enforced by review, not by tooling** (`02-architecture.md`):

| Layer | May import |
|---|---|
| `core` | external packages only. **No other `lib/` directory** |
| `domain` | `core`. **Zero `package:flutter` imports** — this is what makes the source contract testable without a widget binding |
| `data` | `core` + `domain` |
| `sources/implementations` | `domain/sources` + `core/network` **only** |
| `features/*` | `domain` + `core` + **never another `features/*`** |
| `app` | everything, and is the only place that wires them |

---

## 2. Foundations

Five transverse foundations. Everything else depends on at least one.

| Foundation | Responsibility | Depends on | Depended on by |
|---|---|---|---|
| `apk-pipeline` | CI builds a versioned APK on merge to `master` (B31, B34, C9, ADR-011) | — | `3-5` |
| `local-store` | drift schema, migrations, atomic chapter files (B6, B7, B31, B32) | — | `2-1`, `2-5`, `2-6` |
| `failure-discriminator` | Broken ≠ empty, and ≠ zero results (B22, B24, C6, C7) | `0-1`, `0-2` | `2-1`, `3-1` |
| `localisation` | ARB plumbing with a French fallback — **mechanism only** (B28) | — | `6-7` |
| `theme-type` | `LumenColors`, `TextTheme`, `--reader-*` scale, persisted override (B26, B27, ADR-016, ADR-017) | — | `2-8` |

### 2.1 `local-store` — **implemented**

The one foundation already built. Two parts, and the second is the one that bites:

**Part 1 — the relational store.** `lib/core/database/app_database.dart`, six tables, drift/SQLite. § 4 defines them field by field. Committed snapshot at `lib/core/database/schema.json`; `test/core/database/schema_snapshot_test.dart` fails when the snapshot and the live schema disagree. § 4.8 is the assertion list.

**Part 2 — the chapter files, which are not in the database.** A chapter body is a Markdown file on disk, keyed by path, written atomically. B6 requires a chapter to be *wholly present or wholly absent*, and that is a filesystem property, not a row property:

```
<application support>/chapters/<novelId>/<chapterIndex>.md
```

Atomic write is **temp file in the same directory, then rename**, because a rename within a directory is atomic on POSIX and Android's filesystem while a copy is not. `07-downloads-offline.md` owns the detail.

> **The finding that shaped this foundation.** Foreign-key enforcement is **off by default per connection** in SQLite and is not part of the file format. Declared `CASCADE` and `RESTRICT` constraints are therefore inert unless every connection runs `PRAGMA foreign_keys = ON`. Without it, `history_entries.novelId`'s `RESTRICT` — **B32's only enforcement** — did not fire, and deleting a novel silently destroyed the reader's history. The pragma is now set in a setup hook on the real connection, and a test asserts `PRAGMA foreign_keys == 1` so a future refactor fails rather than quietly disabling B32. **Any second connection must repeat it.**

### 2.2 `failure-discriminator`

The single most load-bearing foundation, and the one that cannot be built from a library. Its contract is a **three-state** result, never a two-state one:

```dart
sealed class BrowseOutcome<T> {
  const BrowseOutcome();
}

/// The site was read successfully. `items` may legitimately be empty.
final class BrowseSucceeded<T> extends BrowseOutcome<T> {
  final List<T> items;
}

/// The site could not be read. `reason` is typed, never a bare string (B24).
final class BrowseFailed<T> extends BrowseOutcome<T> {
  final SourceFailure reason;
  final bool retriable;
}

/// Read, but there is genuinely nothing — distinct from failure, and only
/// available where the site supplies its own empty-result signal.
final class BrowseEmpty<T> extends BrowseOutcome<T> {
  final String? siteSuppliedSignal;
}
```

**`BrowseEmpty` exists only where the site provides the signal.** FanMTL's failure page carries the explicit string *"No relevant content found"*, which is what makes the third state possible there. **On genre browsing that string is not applicable** — an empty genre page is judged by page shape (no novel rows), never by that string. A source with no site-supplied signal gets two states, and the UI must say which situation it cannot distinguish.

**Prohibited**, because each has been the obvious cheap answer: catching an exception and returning `BrowseSucceeded(items: [])`; returning `null` and letting the caller decide; a boolean `isEmpty`. All three collapse B22's distinction, and B22 is SC-6.

### 2.3 `apk-pipeline`

`.github/workflows/` builds a release APK on merge to `master`. ADR-011: **no store**. Version from `pubspec.yaml`, surfaced by B43 on `settings-about`.

This foundation exists before any feature because **Q-003** blocks every device verification, and SC-5 is unprovable without it. It is the cheapest slice in the plan and the one that unblocks the most.

---

## 3. Modules and slices

### 3.1 Inventory

34 items: 5 foundations + 29 slices. `wave` is the **computed topological** wave; `milestone` is the roadmap's grouping (see § 6.3).

| Slice | Key | Wave | Depends on | Responsibility |
|---|---|---|---|---|
| `0.1` | `0-1` | 0 | — | Freeze real FanMTL fixtures with capture dates |
| `0.2` | `0-2` | 1 | `0-1` | Record whether FanMTL has an explicit empty-result signal |
| `0.3` | `0-3` | 1 | `0-1` | Freeze Royal Road fixtures |
| `0.4` | `0-4` | 1 | `0-1` | Separate chapter content from furniture, from the real pages. Consumed by `2-2` |
| `1.1` | `apk-pipeline` | 0 | — | **Foundation.** Versioned APK on merge |
| `1.2` | `local-store` | 0 | — | **Foundation.** drift schema + atomic chapter files |
| `1.3` | `failure-discriminator` | 2 | `0-1`, `0-2` | **Foundation.** Broken ≠ empty (B22, B24) |
| `1.4` | `localisation` | 0 | — | **Foundation.** ARB plumbing, FR fallback |
| `1.5` | `theme-type` | 0 | — | **Foundation.** Colours, text, reader scale, override |
| `2.1` | `2-1` | 3 | `0-1`, `local-store`, `failure-discriminator` | FanMTL adapter: catalogue → novel → chapter list → chapter page |
| `2.2` | `2-2` | 4 | `2-1`, `0-4` | Clean and convert a chapter page to text. **Also waits on `0-4`** — see § 6.6 |
| `2.3` | `2-3` | 5 | `2-2` | Store a chapter atomically |
| `2.4` | `2-4` | 6 | `2-3` | **Read a stored chapter, local only — the wow moment** |
| `2.5` | `2-5` | 4 | `local-store`, `2-1` | Library add/remove/list/open; removing keeps downloads |
| `2.6` | `2-6` | 1 | `local-store` | Reading position, per chapter |
| `2.7` | `2-7` | 7 | `2-4` | Reader presentation: continuous scroll, large chapter, no clipping |
| `2.8` | `2-8` | 8 | `theme-type`, `2-7` | Theme and text size applied in the reader |
| `3.1` | `3-1` | 4 | `2-1`, `failure-discriminator` | Catalogue UI for one source |
| `3.2` | `3-2` | 5 | `3-1`, `2-1` | Novel details + chapter list UI |
| `3.3` | `3-3` | 6 | `3-2`, `2-3` | Download one chapter; delete one chapter |
| `3.4` | `3-4` | 5 | `2-5` | First-run disclosure that the library is not recoverable |
| `3.5` | `3-5` | 1 | `apk-pipeline` | About screen with the installed version |
| `5.1` | `5-1` | 7 | `3-3` | Download queue, six bulk choices |
| `5.2` | `5-2` | 8 | `5-1` | Pause/resume/cancel; queue survives closure |
| `5.3` | `5-3` | 9 | `5-2` | Progress, connection loss, storage exhaustion |
| `6.1` | `6-1` | 4 | `0-3`, `2-1` | Royal Road adapter |
| `6.2` | `6-2` | 5 | `3-1` | Search, per source, only where measured usable |
| `6.3` | `6-3` | 9 | `5-2` | Local counting model; last-checked / never-checked |
| `6.4` | `6-4` | 10 | `6-3` | Manual "update library" |
| `6.5` | `6-5` | 2 | `2-6` | History, time-bounded |
| `6.6` | `6-6` | 10 | `6-3` | Unread badge, similar-title warning, title-only search |
| `6.7` | `6-7` | 1 | `localisation` | English translations, including every error string |
| `6.8` | `6-8` | 3 | `6-5` | **Reading statistics** — plain counts, plainly labelled. The `stats` screen and `/more/stats` route exist in the design system, so a slot without a slice would be an empty module |
| `6.9` | `6-9` | 4 | `local-store`, `2-1` | **Source management** — the list and the enable switch. B1's `enabled` behaviour has a column (§ 4.6) and a route but no slice to make it reachable |

### 3.1b Verification gates — not slices, and not optional

Two **drills**, from the roadmap's milestone waves. They are verification, not implementation, so they carry no slice key — but they are the only proof two claims rest on, and an architecture that listed neither would let a reader assume they were covered by `3-5`.

| Gate | When | What it proves | Why it cannot be a slice |
|---|---|---|---|
| **MVP gate** | Roadmap Wave 4 | One live network run, then **connectivity physically off**, one chapter read. Plus **the upgrade-safety drill** below. Plus a number for list responsiveness, or its deletion (`roadmap.md` § 4.3) | Requires a physical device and a hand-off — **Q-003**. No test can stand in for it |
| **V1 gate** | Roadmap Wave 7 | **50 chapters downloaded and read with the connection off** (SC-2). Plus **the upgrade-safety drill run a second time, with a larger library** | Same |

**The upgrade-safety drill, stated as an acceptance criterion** because `benchmarks.md` § 2.3 makes it the product's one structural advantage and it is otherwise only asserted:

> With a library entry, downloaded chapters, reading positions and a history in place, **install the next APK over the previous one and assert every one of those is intact afterwards.** The downloaded chapter *files* are checked, not just the database rows — B31's guarantee is about what survives on the phone, and a migration that drops a table would pass a rows-only check.

No slice carries this. `apk-pipeline` builds the APK and `local-store` owns the schema; **the drill is what joins them**, and it only exists once Q-003 closes.

### 3.2 Coverage against the PRD

| User story | Slices | Rules |
|---|---|---|
| US-01 Browse a source | `3-1`, `6-1`, `6-2` | B1, B2, B22, B24 |
| US-02 Search (conditional) | `6-2` | B41, B50 |
| US-03 Novel details + chapter list | `3-2` | B9, B10 |
| US-04 Read a chapter | `2-7`, `2-4` | B25, B44 |
| US-05 Read offline | `2-4` | B7, C14 |
| US-06 Download one chapter | `3-3` | B33 |
| US-07 Download a novel as a queue | `5-1` | B18 |
| US-08 Watch/control a download | `5-2`, `5-3` | B19, B20, B21 |
| US-09 Keep in library | `2-5`, `6-6` | B11, B12, B32, B40, B45 |
| US-10 New chapters | `6-3`, `6-4` | B13, B14, B35, B36, B38, B39, B48, B49 |
| US-11 Resume where I stopped | `2-6`, `3-4` | B16, B46 |
| US-12 Review what I read | `6-5` | B17, B47 |
| US-13 French and English | `localisation`, `6-7` | B28 |
| US-14 Dark mode | `theme-type`, `2-8` | B26, ADR-016 |
| US-15 My text size | `theme-type`, `2-8` | B27, ADR-017 |
| US-16 Told when a site breaks | `failure-discriminator`, `3-1` | B22, B24, C6, C7 |
| US-17 A new version as a file | `apk-pipeline`, `3-5` | B31, B34, B43 |
| US-01 Browse a source *(enabling/disabling it)* | `6-9` | B1 |
| US-12 Review what I read *(as figures)* | `6-8` | B17, B46, B47 |

**All 17 stories have at least one slice.** `coverage.md` records the other direction: which of the 49 rules are non-visual, and why.

---

## 4. Data models

Six tables. Every field below exists because a rule requires it; the authority for a field's *behaviour* is the rule cited in `app_database.dart`'s own comment beside it.

> **Two names per field, and this is not redundancy.** The `Field` column is the **Dart getter** — what the code writes. The `Column` column is the **SQL name** — what `schema.json`, a raw query and a migration use. They differ by case (`sourceId` → `source_id`), and a reader comparing this section against the committed snapshot would otherwise conclude that five columns of `novels` were undocumented. Both are given for every field, and `schema_snapshot_test.dart` is what keeps the second column true.

> **Renumbering note.** § 4.3–4.6 were added and § 4.4–4.5 shifted to § 4.7–4.8. This document is still `draft`, so nothing is renumbered for real — but the rule in § 9 is real, and the *only* reason this was safe is that no external document cited § 4.4 or § 4.5 yet. `grep` confirmed zero citations outside this file before the change. That check is not optional next time; see § 9.

### 4.1 `novels`

| Field | Column | Type | Null | Default | Constraint | Description | Example |
|---|---|---|---|---|---|---|---|
| `id` | `id` | TEXT | no | — | **PK** | MD5 of `name/lang/versionId` + source id. B3: stable across restarts. Never hand-written | `a3f1…9c02` |
| `sourceId` | `source_id` | TEXT | no | — | — | **B2**: the one site this novel came from. Part of the identity, never derived from the title | `fanmtl` |
| `url` | `url` | TEXT | no | — | — | Relative path + query. `03-source-system.md` rule 3: never a full URL | `/novel/ke383028.html` |
| `title` | `title` | TEXT | no | — | — | Displayed **verbatim** as the site presents it | `Hurtful Reunion` |
| `status` | `status` | TEXT | no | `''` | — | Mapped into `NovelStatus`. `''` means the site did not say | `ongoing` |
| `coverUrl` | `cover_url` | TEXT | **yes** | — | — | Null means *this novel has no cover*, not *we failed* | `https://…/1.jpg` |
| `inLibrary` | `in_library` | INTEGER (bool) | no | `false` | — | **B11**: keeping and following are one act, so one flag | `1` |
| `lastCheckedAt` | `last_checked_at` | INTEGER (datetime) | **yes** | — | — | **B49**: null means *never checked*, and B48 forbids presenting a local count as if it came from a check | `1780000000000` |
| `addedAt` | `added_at` | INTEGER (datetime) | **yes** | — | — | Null while `inLibrary` is false | `1779500000000` |

### 4.2 `chapters`

| Field | Column | Type | Null | Default | Constraint | Description | Example |
|---|---|---|---|---|---|---|---|
| `id` | `id` | TEXT | no | — | **PK** | B3: derived from the novel's id + the chapter's url | `a3f1…:412` |
| `novelId` | `novel_id` | TEXT | no | — | **FK → `novels.id` `ON DELETE CASCADE`** | A chapter record cannot outlive its novel | `a3f1…9c02` |
| `name` | `name` | TEXT | no | — | — | **B10**: displayed exactly as the site presents it | `Chapter 412 – A Debt Repaid` |
| `number` | `number` | REAL | no | `-1` | — | **B10**: `-1` = unparseable and must render as an em dash. **`0` is a real chapter number** (extra, omake) and the two must stay distinguishable | `412` |
| `url` | `url` | TEXT | no | — | — | Relative, per rule 3 | `/novel/ke383028_412.html` |
| `isRead` | `is_read` | INTEGER (bool) | no | `false` | — | **B13**: new until opened. **The unread count is derived from this — there is no `unreadCount` column** | `0` |
| `readAt` | `read_at` | INTEGER (datetime) | **yes** | — | — | Null while unread | `1780000000000` |
| `ordinal` | `ordinal` | INTEGER | no | — | — | **B9**: reading order is the site's order, stored explicitly. Re-sorting by `number` would reorder volumes, side stories and numeric gaps | `411` |

### 4.3 `reading_positions`

One row per chapter the reader has opened.

| Field | Column | Type | Null | Default | Constraint | Description | Example |
|---|---|---|---|---|---|---|---|
| `chapterId` | `chapter_id` | TEXT | no | — | **PK**, FK → `chapters.id` `ON DELETE CASCADE` | B16: a position cannot outlive its chapter | `a3f1…:412` |
| `offset` | `offset` | REAL | no | `0` | — | **B16 / ADR-009**: a **scroll offset**, not a page index and not a page number | `1240.5` |
| `updatedAt` | `updated_at` | INTEGER (datetime) | no | — | — | Last write. B16's "reopening resumes from here" | `1780000000000` |

> `offset` is a **scroll offset** because ADR-009 defers paged modes to v2, and an offset is the only representation a future paged mode can resume from without converting it. A page index would need re-deriving the moment a text size or a line height changed.
>
> **This table is written on every scroll settle and is never read as a record of what was read** — that is `history_entries`, and B46 keeps the two apart.

### 4.4 `history_entries`

B17: recently opened chapters, most recent first.

| Field | Column | Type | Null | Default | Constraint | Description | Example |
|---|---|---|---|---|---|---|---|
| `id` | `id` | TEXT | no | — | **PK** | Generated. B47 bounds rows by **time**, so there is no sequence column | `h9c2…` |
| `novelId` | `novel_id` | TEXT | no | — | FK → `novels.id` **`ON DELETE RESTRICT`** | **B32**: the history survives the novel | `a3f1…9c02` |
| `chapterId` | `chapter_id` | TEXT | no | — | FK → `chapters.id` `ON DELETE CASCADE` | The chapter that was opened | `a3f1…:412` |
| `openedAt` | `opened_at` | INTEGER (datetime) | no | — | — | **B17**: the ordering column, descending | `1780000000000` |

> **The asymmetry is the whole point.** `novelId` is `RESTRICT` while `chapterId` is `CASCADE`. **B32 requires that removing a novel keeps its downloaded chapters, and the record of what was read survives that too.** A `CASCADE` on `novelId` would delete the reader's history as a side effect of a library operation — B32's exact failure expressed as a schema default, and it would have been invisible in review because `CASCADE` looks correct everywhere else in this schema.
>
> **No `position` column, and no `LIMIT` anywhere in access** — B47 bounds by time. There is deliberately no way to ask for "the last 50" by count, because a count bound is the behaviour B47 rejects.

### 4.5 `queue_items`

B18: the download queue.

| Field | Column | Type | Null | Default | Constraint | Description | Example |
|---|---|---|---|---|---|---|---|
| `id` | `id` | TEXT | no | — | **PK** | Generated per enqueue | `q1` |
| `chapterId` | `chapter_id` | TEXT | no | — | FK → `chapters.id` `ON DELETE CASCADE` | What is being fetched | `a3f1…:412` |
| `state` | `state` | TEXT | no | `'queued'` | via `DownloadStateConverter` | `queued \| downloading \| done \| failed`, stored **by name** | `failed` |
| `queuePosition` | `queue_position` | INTEGER | no | — | — | **B18**: insertion order. This, not `chapters.ordinal`, is what the queue reads, so a hand-picked order is honoured | `7` |
| `addedAt` | `added_at` | INTEGER (datetime) | no | — | — | When it was enqueued | `1780000000000` |
| `startedAt` | `started_at` | INTEGER (datetime) | **yes** | — | — | Null until it begins | `1780000010000` |
| `finishedAt` | `finished_at` | INTEGER (datetime) | **yes** | — | — | Null until it ends, either way | `1780000040000` |
| `attempts` | `attempts` | INTEGER | no | `0` | — | **B20**: what distinguishes a resume from a fresh fetch | `2` |
| `errorCode` | `error_code` | TEXT | **yes** | `''` | — | **B24**: a typed code from § 5.2, so a failure is never bare | `source_layout_changed` |

> **No concurrency column.** B18 makes concurrency a constant of one. A constant expressed as a column is something an implementation could change, so `app_database_test.dart` asserts the column's **absence** — the only way to notice one being added.
>
> **Stored by name, not by ordinal.** Reordering the `DownloadState` enum would otherwise silently re-map persisted history: a row written as `downloading` (index 1) would start reading as `done` (index 1) after the enum changed.
>
> `errorCode` defaults to `''` rather than `NULL` because `NULL` and "no error" are different claims, and only one of them is true for a row that has not failed.

### 4.6 `sources`

The app's **local** state of each compiled-in source. Not a copy of the registry — that is code (ADR-013).

| Field | Column | Type | Null | Default | Constraint | Description | Example |
|---|---|---|---|---|---|---|---|
| `id` | `id` | TEXT | no | — | **PK** | The registry's id, never hand-written (`03-source-system.md` rule 1) | `fanmtl` |
| `enabled` | `enabled` | INTEGER (bool) | no | `true` | — | B1: hiding a source hides its novels from browsing and **keeps every download** | `1` |
| `lastCheckedAt` | `last_checked_at` | INTEGER (datetime) | **yes** | — | — | **B49**: null means *never checked*, which is a different claim from *checked at epoch* | `1780000000000` |
| `lastErrorCode` | `last_error_code` | TEXT | **yes** | `''` | — | **B22**: lets `sources` render `unavailable` without attempting a fresh fetch | `source_layout_changed` |
| `settings` | `settings` | TEXT | no | `'{}'` | — | `ConfigurableSource` values as JSON. **Opaque to the platform** — B41's "never interprets a source's values" applies to a source's settings as much as to its filters | `{"mirror":"eu"}` |

### 4.7 What is deliberately **not** in the database

| Not stored | Where it lives | Why |
|---|---|---|
| Chapter **body** | `<support>/chapters/<novelId>/<n>.md` | B6's atomicity is a filesystem property. A 40 KB blob per row would make "present and complete" a property of a transaction instead of a rename |
| Cover **image** | disk cache via `cached_network_image` | Never a row. A missing cover degrades to title initials and must not block a read |
| Reading **settings** | `shared_preferences` | Not relational. `theme-type` owns them |
| Source **registry** | Dart code | ADR-013: a static registry, not rows. `sources` holds only the app's *local state* of each compiled-in source |
| Any **unread count** | derived: `count(chapters.is_read = 0)` | B48. A stored count is a second source of truth free to disagree with the rows it counts — B14 violated by construction |

**Storage location** (§ 4.7): application **support** directory, never cache. The OS may evict a cache directory, and B7 requires a stored chapter to stay readable.

### 4.8 Constraints, and how they were proved

`ddl-exec.js` drives **PostgreSQL** through pglite. This project targets SQLite, so that engine would test the wrong database. The substitute is stronger: the schema is **executed against real SQLite** and its constraints are asserted as behaviour.

| Constraint | How it is proved | Test |
|---|---|---|
| All six tables are created | SQLite accepted the DDL | `the DDL executes` |
| `chapters.novelId` cascades | Delete a novel, count chapters → 0 | `deleting a novel cascades to its chapters` |
| `historyEntries.novelId` restricts | Delete a novel → **throws** | `history survives the novel, and the FK refuses the delete` |
| Foreign keys are **enforced at all** | `PRAGMA foreign_keys == 1` | `foreign-key enforcement is ON, not merely declared` |
| Unread count is derived | 3 unread, open 1 → 2 | `opening a chapter clears exactly one unread` |
| Positions are independent per chapter | Two rows, two offsets | `two chapters of one novel hold independent offsets` |
| State stores a name, not an ordinal | Raw read → `'queued'` | `DownloadState round-trips as a name` |
| No concurrency column exists | Column set assertion | `the queue has no concurrency column to mis-set` |
| Never-checked ≠ epoch | `lastCheckedAt` is null | `a null lastCheckedAt is null, not epoch` |
| Unparseable ≠ 0 | Default `-1`, `0` still reachable | `the default is -1 and 0 stays reachable` |
| Snapshot matches the live schema | Compare SQLite's tables to `schema.json` | `the committed snapshot matches the schema that actually runs` |
| Snapshot still records B32's `RESTRICT` | Read the constraint out of the snapshot | `the snapshot still records B32's RESTRICT` |

**The drift guard was proven able to fail.** Adding a column and regenerating without re-dumping produces exactly `columns drifted on chapters`; restoring returns it to green. A guard never seen red is a decoration — and this project has already been bitten by a gate that reported zero and passed.

**One declared guard that cannot be declared here.** The template's `forge:ddl-refuse` mechanism proves a *constraint* refuses an operation by executing it. Two of the above are declared that way (`RESTRICT` refuses the delete). The rest are behaviour tests rather than DDL guards, because the DDL itself does not express them — the no-concurrency-column rule and the derived-count rule are absences, and an absence has no statement to refuse.

---

## 5. Contracts

> **The template's § 5 is "API contracts". This app has no API.** There is no server, no account, no endpoint and no request this project makes of anything it owns. The template's exhaustive error-code table has no counterpart here, and writing one would be inventing a surface that does not exist.
>
> What replaces it is the set of contracts this app actually has: what it requires of a source, what a source may fail with, and what it promises about the network. Those are specified below with the same exhaustiveness the template asks for.

### 5.1 The source contract

`domain/sources/source.dart` — transposed from Mihon's `source-api`, with `fetchChapterContent` replacing `getPageList`. `03-source-system.md` is the authority; the shape is:

```dart
abstract class Source {
  String get id;                       // MD5 — never hand-written
  String get name;
  String get lang;                     // ISO 639-1
  bool get supportsLatest;
  bool get supportsSearch;             // ADR-015: a promise, not a guess
  FilterList get filterList;           // declared by the source, interpreted by the source

  Future<NovelsPage> getPopularNovels(int page);
  Future<NovelsPage> getLatestNovels(int page);
  Future<NovelsPage> searchNovels(int page, String query, FilterList filters);
  Future<NovelUpdate> getNovelUpdate(Novel novel, List<Chapter> chapters, {
    required bool fetchDetails, required bool fetchChapters,
  });
  Future<Novel> getNovelDetails(Novel novel);
  Future<List<Chapter>> getChapterList(Novel novel);
}

abstract class HttpSource extends Source { String get baseUrl; int get versionId; }
abstract class ParsedHttpSource extends HttpSource {
  Future<String> fetchChapterContent(Chapter chapter);  // raw HTML
}
```

**Every one of these returns `BrowseOutcome<T>` (§ 2.2), not a bare list.** That is the contract-level expression of B22: the type system cannot express "empty" and "failed" the same way.

### 5.2 The failure taxonomy

`core/error` — one type per cause, each with its recovery. **B22 needs causes distinguished, not collapsed**, because three of the four have no retry worth offering and one has nothing wrong at all.

| Cause | Carries | Recoverable by retry | Reader's action |
|---|---|---|---|
| `NoConnection` | — | later, on its own | read what is downloaded |
| `RateLimited(retryAfter)` | duration | after `Retry-After` | wait |
| `SourceLayoutChanged` | selector that failed | **no** | nothing — report the bug |
| `SourceUnavailable` | status | later | back off |
| `ItemRemovedAtSource` | which item | **no** | go back; the rest is unaffected |
| `StorageFull` | bytes needed | **no** | free space, then resume |
| `ParseFailed` | file path | **no** | report the bug |

**Prohibited**: a bare `Exception`, a `String` reason, or an `errorCode` free-text field the platform interprets. B41's rule that the platform never interprets a source's values applies to failures too.

### 5.3 What the app promises about the network

| Promise | Rule | Mechanism |
|---|---|---|
| Honest identification | `17-security.md` rule 5 | `LumenTale/<version> (personal reader)` UA. **ADR-014: no browser impersonation.** Measured: Novel Fire returns 403 to a browser-like UA and 200 honest |
| Nothing fetched unasked | B5 | No speculative fetch on screen open, list scroll or app resume |
| Rate limiting and backoff | rules 5–6 | Shared limiter; `Retry-After` honoured |
| Nothing leaves the device | B29 | **No analytics, no crash reporting, no telemetry.** A crash log is a network call |
| No chapter prose in any log | B44 | Chapter text is never logged, at any level, including debug |
| Checking never downloads | B38 | Separate interactors; no code path from check to download |

### 5.4 Where the template's API table would have gone, and why it is empty

| Endpoint | Status |
|---|---|
| Authentication | **None.** B4. The correct implementation is the absence of a login surface |
| Account / profile | **None.** B4 |
| Cloud sync | **None.** ADR-010, excluded not deferred |
| Backup / restore / export | **None.** B30, ADR-010 |
| In-app purchase | **None.** ADR-010 |
| Telemetry | **None.** B29 |

Each is an **exclusion with a reason**, recorded in `coverage.md` § B29/B30 and `flows.md` § 6 — not an omission. An exclusion table is what makes the absence reviewable; a template's error-code table for endpoints that do not exist would not.

---

## 6. Dependency graph

### 6.1 Computed waves

Eleven waves, computed by `dependency-check.js`, not asserted:

```
W 0  0-1, apk-pipeline, local-store, localisation, theme-type
W 1  0-2, 0-3, 0-4, 2-6, 3-5, 6-7
W 2  6-5, failure-discriminator
W 3  6-8                          ← new; depends only on 6-5 (W 2)
W 3  2-1
W 4  2-2, 2-5, 3-1, 6-1, 6-9     ← 2-2 also waits on 0-4 (W 1)
W 5  2-3, 3-2, 3-4, 6-2
W 6  2-4, 3-3
W 7  2-7, 5-1
W 8  2-8, 5-2
W 9  5-3, 6-3
W10  6-4, 6-6
```

**Cycles: none. Dead dependencies: none.** Verified, not read.

### 6.2 The critical path

```
0-1 fixtures → 0-2 empty-signal → failure-discriminator → 2-1 FanMTL
  → 2-2 clean/convert → 2-3 atomic store → 2-4 READ OFFLINE ← the product's claim
```

The wow moment is on the critical path, not at the end of it. And **the offline proof precedes every browse UI slice in milestone order**, which is the roadmap's deliberate inversion and is explained in § 6.3.

### 6.3 Why `impl_waves: 6` and not 11

The graph permits more parallelism than the roadmap intends. `2-6` (reading position), `3-5` (about), `6-5` (history) and `6-7` (English) each depend only on a foundation, so the graph offers them in wave 1 — while the roadmap holds them for later milestones. Declaring 11 would erase the milestone grouping; declaring nothing would let `--write` overwrite the distinction silently.

The difference that matters, and the reason the milestones govern:

| Slice | Topological wave | Milestone |
|---|---|---|
| `2-4` **offline read proof** | 6 | **Wave 2** |
| `3-1` browse UI | **4** | **Wave 3** |

Browse UI is available *first* by topology. Following milestones puts the offline read proof **before any browse UI exists** — which is the whole argument for the roadmap's inverted order, and the reason an implementer should read § 6.3 rather than the wave numbers.

### 6.4 Parallelism

| Wave | Parallelisable |
|---|---|
| 0 | all five foundations, plus fixtures — 6 independent starts |
| 1 | `0-2`, `0-3`, `0-4`, `2-6`, `3-5`, `6-7` — 6 |
| 4 | `2-2`, `2-5`, `3-1`, `6-1` — 4 |

### 6.5 Cycles

**None detected.** Verified by `dependency-check.js check`, which refuses a dependency that would close a cycle.

### 6.6 What the risk posture found in this graph

`dependency-check` proves the graph is *well-formed*. It does not prove the graph is *right* — the missing edge in this section was well-formed too, and no cycle checker would ever see it.

**`0-4` had zero dependents, and should have had one.** Wave 0's slice `0-4` records *which parts of a chapter page are content and which are furniture*, and the roadmap names its consumer: "the cleaning rules". The cleaner is `2-2` — and `2-2` declared only `2-1`. So the converter could have been written before anyone read a real chapter page closely enough to know what to strip, which is precisely the research `0-4` exists to do.

The general form, and the reason this is recorded rather than quietly fixed: **a research slice whose declared purpose is "informs X" and whose dependency list is empty is the most dangerous kind of leaf.** It looks like a tidy terminal node, nothing else in the graph is affected by it, and no structural check can tell an intentional leaf from a forgotten edge. Fan-in of zero is a question to answer, not a result to accept.

Now declared: `2-2 → 0-4`. Fan-in of `0-4` is 1; wave counts are unchanged, because `0-4` lands in W1 and `2-2` in W4.

---

## 7. Architecture decisions

Full text in `DECISIONS.md`. The ones that shape the structure above:

| ID | Decision | Consequence for this document |
|---|---|---|
| ADR-003 | First-party HTML→Markdown on `package:html` | The converter is `core/utils`, not a dependency. § 1.1 records the reason |
| ADR-005 | drift + `sqlite3`, not SQLDelight or `sqlite3_flutter_libs` | § 4 is drift-flavoured throughout |
| ADR-008 | Layer-first domain, go_router, `Future` + Riverpod, String MD5 ids | § 1.2's layer table, § 5.1's id contract |
| ADR-013 | Static source registry, **no dynamic extension system** | § 4.4: the registry is code, not rows |
| ADR-014 | Mihon's Cloudflare bypass **not ported** | § 5.3: honest UA, with the measurement that justifies it |
| ADR-015 | `supportsSearch` is a declared, measured promise | § 5.1. FanMTL is `false`; the other two are **unmeasured** |
| ADR-016 | Day is warm paper, night is **cool ink** | `theme-type`'s two independently designed palettes, not one inverted |
| ADR-017 | Reader prose is serif via a preference chain; **nothing bundled** | `theme-type` ships no asset |
| ADR-009 | v1 continuous scroll; position stored as an **offset** | § 4.3's `offset`, and why it is not a page index |
| ADR-020 | **No new-chapter notification in v1** | § 5.4's exclusion table and `benchmarks.md` § 4b's first cost row. **Forced by B35**, not chosen: opt-in checks → no automatic check → nothing to detect → nothing to announce. The chain matters more than the absence — see ADR-020 for why a design decision cannot override an approved business rule silently |
| ADR-010 | Personal use: no account, sync, export, backup | § 5.4's exclusion table. It removes 24 screens from Mihon's inventory (`screens/_mihon-verdicts.md` § 2) and costs the reader **any safety net for their library** — mitigated only by B31, which `benchmarks.md` § 2.3 shows is the failure their competitors cannot fix |

---

## 8. Architectural risks

| Risk | Prob | Impact | Mitigation |
|---|---|---|---|
| **The HTML→Markdown converter is the largest unknown** and no real FanMTL HTML has ever been read in this repo | HIGH | HIGH | Wave 0 captures fixtures **before** any converter code. ADR-003 rejected every published converter, so there is no fallback to switch to |
| **No device to verify on** (Q-003) | HIGH | HIGH | `apk-pipeline` is a wave-0 foundation, so CI is unblocked early. Wave 4's drill is where SC-2 is won or lost |
| **SQLite FK enforcement off by default** | was HIGH | HIGH | **Fixed** — pragma on every connection + a test asserting it. Residual: any future second connection must repeat it |
| **No drift-based migration verification** at schema version 1 | MED | MED | `drift_dev schema generate` emits non-compiling code in 2.35.1. Hand-written drift guard instead, proven red once. Re-run the generator at v2 |
| A site changes its layout | HIGH | MED | B22 reports it rather than returning empty. `18-external-contracts.md` is the finding log; a new layout change is a new entry there, not a silent fix |
| Sequential downloads make a 900-chapter novel slow | HIGH | LOW | B18 makes it a constant. Accepted and documented, not optimised away — a concurrency column is what would let it drift |
| One implementer, one device, one person who can repair a scraper | HIGH | HIGH | Stated plainly in the roadmap. The MVP+V1 total is 32 slices and the roadmap prices a 7-story reduction if Waves 1–2 overrun |
| **Q-004** — Novel Fire's terms unread | MED | LOW | Gates one source only. Ships when confirmed, never otherwise |
| **No new-chapter notification in v1** — a serial's reader must open the app to learn a chapter is out | HIGH | **MED** | ADR-020: forced by B35's opt-in checking, not chosen. Both commercial apps use progress notifications as their primary re-engagement, so this is a real parity gap. `benchmarks.md` § 4b states the cost; `6-4` reaches it the moment the reader opts into a schedule |
| Royal Road / Novel Fire search unmeasured | MED | LOW | `6-2` is per-source and conditional. v1 claims genre browsing for all three and search for none — a passing v1, not a gap |
| Chapter bodies as files drift from the database | MED | MED | § 4.7 gives files their own key space and B6 their own atomicity. A mismatch is detectable: the row exists, the file does not |

---

## 9. Amendments

**This document will be cited by number.** A Phase 5 plan reading `architecture.md` § 4.2 is relying on a contract.

> **Extend, never renumber.** A section appended at the end breaks nothing. Inserted mid-document, it shifts every later number — and each reference then points at a section that *still exists*, hence at the **wrong** one. No check sees that drift, because it resolves.

| # | Amendment | Reason | Sections added | Renumbered |
|---|---|---|---|---|
| — | — | none yet | — | — |

An amendment is recorded with `state.js amend`, which **refuses** the renumbering and names the drift.

---

## Gate checklist

- [x] Every PRD user story has a slice — § 3.2, all 17
- [x] Every slice has a responsibility expressible in one line — § 3.1
- [x] Foundations identified and separated from feature slices — § 2, five of them, all wave-0-eligible
- [x] All data models defined field by field — § 4, six tables, 38 columns
- [x] The template's "every endpoint lists its error codes" is satisfied **by § 5's honest substitution**: there is no API, the failure taxonomy is enumerated with its recovery, and the excluded surfaces are listed with reasons rather than left blank
- [x] Dependency graph has no cycles — § 6.5, verified by `dependency-check`
- [x] Implementation order is consistent with the dependencies — § 6.1–6.3, and the milestone-vs-topology divergence is declared with its reason
- [x] Non-trivial architecture decisions are recorded as ADRs — § 7, ten, with `DECISIONS.md` as the authority
- [x] The DDL **executes** — against real SQLite rather than pglite, with 12 constraints asserted as behaviour, and the drift guard proven red once
- [x] `consistency-check references`: zero broken

**Status**: `draft` — awaiting validation.