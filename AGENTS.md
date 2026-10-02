# AGENTS.md — Lumen Tale

## The project

A Flutter app for reading **web novels** offline, inspired by [Mihon](https://github.com/mihonapp/mihon). Users aggregate their favourite web novels, browse catalogue sources, fetch chapter content from websites, read it, and keep it for offline reading.

The difference from Mihon is the source contract: a manga source returns **image pages**, a web-novel source returns **chapter HTML**. That HTML is cleaned, converted to Markdown, persisted as `.md` on disk, and rendered by the reader. V1 has **no dynamic extension system** — sources are plain Dart classes in a static registry.

## Verified toolchain

**Never answer a Flutter or Dart API question from memory.** Flutter 3.47.6 shipped the day before this was written; the API surface is past the model's reliable knowledge. Read the installed SDK (`/home/codespace/flutter/packages/flutter/lib/src/…`), the package source in the pub cache, or the version-matched docs.

| Component | Resolved | Notes |
|---|---|---|
| Flutter | **3.47.6** (stable, rev `5fc346839b`) | Satisfies `sdk: ^3.11.5` (i.e. `>=3.11.5 <4.0.0`) |
| Dart | **3.13.5** | |
| DevTools | 2.60.0 | |

Version-matched documentation: <https://docs.flutter.dev/overview> (select the 3.47 release); Dart: <https://dart.dev>. Installed SDK source is authoritative over both.

**Runtime dependencies** (resolved — read `pubspec.lock` for the truth, never this table, if they disagree):

`flutter_riverpod` 3.4.3 · `riverpod_annotation` 4.0.7 · `go_router` 18.0.2 · `drift` 2.35.1 · `sqlite3` 3.7.0 · `dio` 5.11.1 · `html` 0.15.7 · `freezed_annotation` 3.1.0 · `json_annotation` 4.12.0 · `flutter_markdown_plus` 1.0.12 · `cached_network_image` 4.0.4 · `workmanager` 0.10.10 · `shared_preferences` 2.5.5 · `path_provider` 2.1.6 · `path` 1.9.1 · `intl` 0.20.3 · `flutter_localizations` (SDK)

**Dev dependencies**: `build_runner` 2.16.1 · `riverpod_generator` 4.0.9 · `freezed` 4.0.2 · `json_serializable` 6.14.1 · `drift_dev` 2.35.1 · `mocktail` 1.0.5 · `flutter_lints` 6.0.0

**Banned, with reasons** (each was in the stack at some point — do not re-add):

- `html2md` — every published version is `sdk: >=2.12.0 <3.0.0`. Dart 2 only. See ADR-003.
- `sqlite3_flutter_libs` — resolves to `0.6.0+eol`, "Not used anymore". Replaced by `sqlite3` 3.x. ADR-005.
- `flutter_markdown` — discontinued, replaced by `flutter_markdown_plus`. ADR-006.
- Any native/FFI package (`h2m`, `html_to_markdown_ffi`, …) for a problem `package:html` can solve. ADR-003, `17-security.md` rule 13.

## Current state

**`lib/` contains no feature code.** It is `main.dart` — a localization-and-theme bootstrap with no `home` — plus `lib/l10n/`. The layered layout below is the **target**, not a description of what exists. `test/widget_test.dart` covers the bootstrap (5 tests).

Nothing is half-built. There are no screens, no database, no sources, and no `app/`, `core/`, `domain/`, `data/`, `sources/`, or `features/` directories yet.

## Architecture

Hybrid: **layered core** + **feature-first UI**.

```
lib/
├── main.dart
├── l10n/          # ARB sources + generated AppLocalizations
├── app/           # bootstrap, go_router, theme      — owns theme assembly
├── core/          # network, database, storage, ui, utils — no internal deps
├── domain/        # PURE DART — Source contract, models, repository interfaces, interactors
├── data/          # drift repositories, mappers, SourceManager
├── sources/       # implementations/ — one class per website + source_registry.dart
└── features/      # library, browse, novel_details, reader, updates, history, downloads, settings
```

`core` → external packages only · `domain` → `core`, no Flutter UI · `data` → `core` + `domain` · `sources/implementations` → `domain/sources` + `core/network` only · `features/*` never import each other · `app` wires everything. Full table: `02-architecture.md`.

## The Source Contract

Transposed from Mihon's `source-api`, and the heart of the app:

- `Source` — stable `id` (MD5 of `name/lang/versionId`), `name`, `lang`, `supportsLatest`, `filterList`; `getPopularNovels`, `getLatestNovels`, `searchNovels`, `getNovelUpdate`, `getNovelDetails`, `getChapterList`.
- `HttpSource` — `baseUrl`, dio-based helpers, `versionId`.
- `ParsedHttpSource` — declarative CSS selectors + `Element → Novel/Chapter` mappers, and `fetchChapterContent(chapter)` returning **raw chapter HTML** (our replacement for Mihon's `getPageList`).
- Pipeline: `fetchChapterContent → clean → HTML→Markdown → .md on disk → reader renders`.
- Registered statically in `sources/implementations/source_registry.dart`, resolved by `SourceManager`.

Detail: `03-source-system.md`. Conversion: `04-html-to-markdown.md`.

## Commands

| Command | Purpose |
|---|---|
| `flutter pub get` | Resolve dependencies |
| `flutter pub add <pkg>` / `flutter pub add dev:<pkg>` / `flutter pub remove <pkg>` | **The only** way to change dependencies — never edit `pubspec.yaml` by hand |
| `dart format .` | Format |
| `flutter analyze` | Static analysis — must report zero issues |
| `flutter test` | Tests — must pass |
| `flutter gen-l10n` | Regenerate localizations after editing an ARB file |
| `dart run build_runner build` | Regenerate riverpod / freezed / json_serializable / drift code. **No flag** — `--delete-conflicting-outputs` was removed and is silently ignored, so passing it prints a warning and does nothing |
| `dart run drift_dev schema dump lib/core/database/app_database.dart lib/core/database/schema.json` | Export the drift schema snapshot after a table change. **Two** arguments — with one it prints usage and exits 0, so it looks like it ran |
| `dart run drift_dev identify-databases` | List the drift databases in the project and their schema version |
| `flutter build apk` | Android build — **unvalidated here**, no Android SDK (Q-003) |

Flutter lives at `/home/codespace/flutter/bin`. Generated files (`*.g.dart`, `*.freezed.dart`, `*.drift.dart`, `lib/l10n/generated/`) are committed and excluded from analysis.

## Definition of Done

A change is complete when **all** of these hold, in this order. This is the single definition — no rule file restates it.

1. `dart format .` — clean, no diff.
2. `flutter analyze` — **zero issues**, including zero `info`. Weakening a lint to go green is not a fix.
3. `flutter test` — all tests pass. Never edit a test to make a failing behaviour pass.
4. Generated code is committed: if you changed an annotated class or an ARB file, the regenerated output is in the same commit.
5. `SESSION_LOG.md` has an entry covering this work, or the commit extends an entry already written for this session.
6. Committed with a Conventional Commits message (`11-git-workflow.md`).

**Why item 5 is in the list and not in a reminder.** This session made **nine commits with no log entry**, and the log only got written when the owner asked why it was so far behind. The cause was not forgetting the rule — it was treating the log as a closing chore because each commit message felt self-documenting. A commit message carries *what changed*; the log carries *what was rejected, what is blocked, and what the next session must not re-litigate*, and nothing found that was lost cheaply. Findings that went unlogged here included `component-parity` verifying nothing, and SQLite not enforcing the foreign keys that hold B32.

So it is item 5 of the Definition rather than advice in a memory index, because **a definition is checked and a reminder is not**. An entry already open for the current session counts — the point is that the work is written down, not that a new heading appears per commit.

## When blocked

- A command fails twice for the same reason → **stop and report**. State the command, the error, and what you tried. Do not work around it silently.
- A request contradicts a closed decision in `DECISIONS.md` → **stop and ask**, naming the ADR. Do not build the alternative first.
- A stack change is needed (new dependency, different package, new toolchain) → check the banned list and `DECISIONS.md` first. If it needs a new native dependency, it needs an ADR (`17-security.md` rule 13).
- External site changed its layout → that is a finding for `18-external-contracts.md`, not a silent fix.
- A design is undecided and it changes the architecture → write it as an open question in `DECISIONS.md` with its closing trigger, and pick the cheapest reversible option meanwhile.

## Priority Order

Rules conflict. This ranking settles it — read it rather than choosing between two rule files yourself.

1. **Correctness and safety** — typed exceptions, no untrusted input reaching a path or a shell, no secrets at rest. A security or correctness rule beats a speed, style, or convenience rule.
2. **Layer and contract boundaries** — `02-architecture.md` and `03-source-system.md`. A convenience that crosses a layer is not a convenience.
3. **Testability** — the risky, change-prone code (source parsing, the HTML→Markdown converter, repository round-trips) is tested. Testability beats brevity.
4. **Project coherence** — one pattern per concern, matched to what already exists. A new file beats a second way of doing the same thing.
5. **Focused change** — no speculative refactors, no scaffolding for features that do not exist.
6. **Performance** — but never at the cost of 1–5, and never without a measured baseline.
7. **Style and idiom** — enforced by `flutter analyze`. Style never justifies deviating from 1–6.

Two conflicts this settles explicitly: `09-widgets-ui.md` §Conventions (prefer Material 3 primitives) beats any inherited ShadCN habit; and `08-coding-standards.md` §Dependencies (`flutter pub add` only) beats convenience when installing something.

## Rules index

Loaded automatically via `opencode.json` → `.opencode/rules/*.md`. **Read the ones your task touches** — the whole set loads every session, so skimming the index and reading two files is faster than reading eighteen.

| File | What goes in it | Read it when |
|---|---|---|
| `01-project-vision.md` | Product scope, the content pipeline, v1 non-goals | Deciding what to build, or whether something is in scope |
| `02-architecture.md` | Directory layout, dependency table, repository pattern, directory authorities | Adding a file, or unsure which layer may import what |
| `03-source-system.md` | The `Source` contract, source models, rules for writing a source | Writing or fixing a source; touching `domain/sources/` |
| `04-html-to-markdown.md` | The HTML→Markdown pipeline and the first-party converter | Touching conversion, cleaning, or chapter HTML |
| `05-state-management.md` | Riverpod conventions, provider lifetime, invalidation, notifier patterns | Writing or reviewing any provider or notifier |
| `06-database.md` | Drift schema, migrations, snapshots, drift-specific mappers | Changing a table, a DAO, or a mapper |
| `07-downloads-offline.md` | Download queue, storage layout, atomic writes, offline reading | Touching downloads, covers, or on-disk chapter files |
| `08-coding-standards.md` | Naming, immutability, async, API design, pubspec, codegen | Writing any Dart; changing dependencies |
| `09-widgets-ui.md` | Material 3 usage, feature layout, reader UX, overlays, navigation | Building or changing any screen or widget |
| `10-testing.md` | Test conventions, fixtures, priorities, coverage | Writing tests, or deciding what needs one |
| `11-git-workflow.md` | Branches, commits, PRs, what not to stage | Committing, branching, or opening a PR |
| `12-ai-agent-workflow.md` | How an agent operates: session start/end, verification, memory protocol | **Every session** — read this one always |
| `13-error-handling.md` | The `AppException` hierarchy, throw/catch/log/map policy | Throwing, catching, or surfacing any error |
| `14-design-tokens.md` | Theme tokens, typography, **accessibility (sole owner)** | Choosing a colour, spacing, type, or any a11y behaviour |
| `15-performance.md` | Rebuilds, lazy lists, reactivity, reader, background work | A screen feels slow, or you're adding background work |
| `16-i18n.md` | ARB workflow, key naming, the FR fallback | Adding or changing any user-visible string |
| `17-security.md` | Untrusted input, network posture, data at rest, dependencies, third-party content | Anything touching a path, a fetch, a secret, or a persisted blob |
| `18-external-contracts.md` | Per-site findings for scraped sources, with promotion targets | Implementing a source, or a source returns empty results |

## Memory index

These three files are **not** in the `instructions` glob — they are append-only journals that grow, so loading them every session would waste the context they exist to protect. Read and write them at the triggers below. `12-ai-agent-workflow.md` is the caller for the promotion path.

| File | What you write there | The trigger — write when… |
|---|---|---|
| `SESSION_LOG.md` | What happened this session: 8 named fields, one entry per session | **You are ending a session or a commit.** Write the entry before you stop, never during. Fill `REJECTED` — it is the only thing stopping the next session from re-proposing what you just declined. |
| `DECISIONS.md` | **Closed** decisions as ADRs (6 fields, `Status:` required) and open questions with their closing trigger | **You settle something a future session would otherwise re-litigate**, or an open question reaches its closing condition. Append-only: supersede, never rewrite. |
| `LEARNINGS.md` | One line per correction: the fault as a contrast, then its promotion target | **You get something wrong a second time**, or you discover a behaviour that contradicts a rule. A correction with no `domain:` cannot be promoted and stays a journal entry. |

`AGENTS.md` has no trigger of its own: it is loaded, and it is what points at the other three.