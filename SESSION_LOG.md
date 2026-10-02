# SESSION_LOG.md — Lumen Tale session journal

**Append-only.** One entry per working session, read **in full at the start of every session** and appended **before** ending a session or a commit.

Each entry carries **8 named fields, in this order**. The order is part of the format: a session that begins at `STATUS` has to re-read the other seven to know where it stands.

`STARTED FROM` · `DECIDED` · `REJECTED` · `BLOCKED` · `FILES TOUCHED` · `STATUS` · `NEXT SESSION SHOULD` · `NEXT SESSION SHOULD NOT`

## What this file is not

It does not carry the status of a deliverable. It does not carry an architecture decision — that is `DECISIONS.md`. It does not carry a correction — that is `LEARNINGS.md`. It carries **what happened and in what order**, including the hesitation and the mistakes: the only information no other file can infer.

## Ownership of facts

| File | Holds |
|---|---|
| `pubspec.lock` | Resolved dependency versions — authority, never edited by hand |
| `AGENTS.md` | The entry file: priorities, commands, definition of done, rule index |
| `DECISIONS.md` | Closed architecture decisions (ADR) and open questions with closing triggers |
| `LEARNINGS.md` | Corrections, each with its promotion domain |
| `SESSION_LOG.md` (this file) | The narrative of the session |

## Journal

<!-- One entry per session, oldest first. Nothing else here. -->

---

## 2026-10-02 — Session 1: toolchain bootstrap and rule-set repair

### STARTED FROM

A four-commit repository with `AGENTS.md` and sixteen rule files, but no implementation: `lib/` held the untouched Flutter counter demo and `pubspec.yaml` listed exactly one dependency, `cupertino_icons`. No Flutter or Dart SDK was installed on the machine. `git log` recorded `chore: enrich project rules from keyed_rent conventions`, which named the origin of the rule content.

### DECIDED

Seven decisions, each recorded as an ADR with its alternatives: ShadCN dropped for Material 3 (ADR-001); the theme lives in `app/theme/` (ADR-002); the HTML→Markdown converter is written in-repo on `package:html` (ADR-003); toolchain is Flutter 3.47.6 / Dart 3.13.5 (ADR-004); `sqlite3` 3.x replaces the EOL `sqlite3_flutter_libs` (ADR-005); `flutter_markdown_plus` replaces the discontinued `flutter_markdown` (ADR-006); the definition of done is stated once in `AGENTS.md` rather than per file (ADR-007).

### REJECTED

- **ShadCN / `flutter_shadcn_ui`.** Present in four rule files, absent from the declared stack and from `pubspec.yaml`. Any session following those rules would have searched for `ShadButton` and found nothing. Material 3 is sufficient for a reader.
- **`h2m` as the HTML→Markdown converter.** Maintained and feature-rich, but it is a Rust FFI binding via `flutter_rust_bridge`; adopting it would add a native build toolchain (NDK for Android, possibly `rustup`/`cargo` on every machine and in CI) to a mobile reader, purely to convert chapter bodies.
- **Pinning Dart to keep `html2md`.** The package has never shipped a Dart 3 release; holding the whole toolchain back for it was the worse trade.
- **Flutter 3.41.9.** The tightest match to the caret range's lower bound, but two minor Dart releases behind current stable, at zero migration cost since no code exists.
- **Merging `11-git-workflow.md` and `12-ai-agent-workflow.md`.** Tempting, since the definition of done was duplicated between them. Rejected — git conventions and agent operating rules are genuinely different concerns and both files hold substantial unique content; cross-referencing preserves all of it where merging would have forced choices about what to drop.

### BLOCKED

- **The native SQLite build is unvalidated.** `sqlite3` 3.x provisions its native library through Dart build hooks. `dart run drift_dev` executes those hooks successfully here, but no Android or iOS build has run, because this environment has no Android SDK and no Xcode. Tracked as Q-003, closing when `flutter build apk` succeeds.
- **`flutter doctor` reports three failures** — Android toolchain, Chrome, Linux desktop toolchain. None block `analyze`, `test`, or `pub get`, and none of the three are v1 targets (`01-project-vision.md` §Non-goals). Left unfixed rather than installing an Android SDK that was not asked for.

### FILES TOUCHED

- **Toolchain**: installed Flutter 3.47.6 to `/home/codespace/flutter`, sha256-verified against Flutter's release manifest before extraction; PATH added to `~/.bashrc`.
- **Dependencies**: `flutter pub add` for 18 runtime and 6 dev packages; `flutter pub remove` for `sqlite3_flutter_libs` and `flutter_markdown`. `pubspec.lock` went from 28 to 142 packages. The `.drift.dart` analyzer exclusion was added because `drift_dev` was about to generate unexcluded output.
- **i18n**: created `l10n.yaml`, `lib/l10n/app_en.arb`, `lib/l10n/app_fr.arb`, and `lib/l10n/generated/`. Two flags were resolved by checking rather than guessing: `synthetic-package` is a no-op in 3.47, and `flutter: generate: true` is now required in `pubspec.yaml`.
- **Rules**: rewrote `AGENTS.md`, `02`, `04`, `05`, `06`, `08`, `09`, `12`, `14`, `15`, `16`; added `17-security.md` and `18-external-contracts.md`; edited `01`, `03`, `07`, `10`, `11`, `13`; created `DECISIONS.md`, `LEARNINGS.md`, `SESSION_LOG.md`, this file.
- **`README.md`** and **`opencode.json`** updated to match.

### STATUS

Toolchain installed and verified; dependencies resolved; `flutter analyze` clean, `flutter test` 5/5 green. The rule set is repaired: contamination removed, false claims corrected, duplicated rules deduplicated, and `security` plus `external-system-contracts` given owners. **No feature code exists** — `lib/` is `main.dart` (a localization-and-theme bootstrap with no `home`) plus generated localizations. The layered architecture in `02-architecture.md` is a target, not a description.

### NEXT SESSION SHOULD

Read `AGENTS.md`, then this journal, then the open questions in `DECISIONS.md`. The highest-value next step is Q-001: settle which sites may be scraped, because no source can be written until permission is recorded. After that, build the first vertical slice — the Source contract in `domain/sources/` and one source behind it — since `03-source-system.md` is the largest rule file and is entirely unexercised.

### NEXT SESSION SHOULD NOT

- Do not re-propose ShadCN. It was considered and rejected on the record (ADR-001); re-raising it needs new information, not a reminder.
- Do not re-propose `h2m`, or any FFI converter, without an ADR — the build-toolchain cost is the deciding factor and it is already written down (ADR-003, `17-security.md` rule 13).
- Do not re-derive the toolchain version. It is verified and recorded in `AGENTS.md` §Verified toolchain; read it rather than searching pub.dev again.
- Do not hand-edit `pubspec.yaml`. Three of this session's stack corrections came from packages that resolved fine but were deprecated or wrong-SDK; `flutter pub add` and the resolver's warnings are how those surfaced, and hand-editing bypasses both.

*(Session 1 tail — superseded below by session 2.)*

---

## 2026-10-02 — Session 2: Mihon reference research + Forge bootstrap

### STARTED FROM

Session 1's end state: toolchain installed, 18 rule files repaired, 7 ADRs recorded, Q-001 (which sites to scrape) still open. The user asked for Mihon to be cloned as a reference, then for Forge to plan the app, with the instruction that Mihon is copied as far as possible and that `.forge/design/screens` must eventually hold all of Mihon's screens.

### DECIDED

Four questions answered by the user and recorded as ADRs: **ADR-008** (Mihon is the declared reference — copy scope and structure, re-derive implementation, with the deliberate divergences from Mihon tabulated), **ADR-009** (reader is continuous-scroll in v1; paged mode and reading modes are v2, and scroll position is stored as an offset so v2 can resume it), **ADR-010** (v1 is personal-use only — no sharing, export, or backup), and **Q-001 closed** → the two v1 sites are Royal Road and Novel Fire.

Contract corrections from Mihon, applied to `03-source-system.md`: `Filter<T>` is generic with a typed `state`; `Filter.Group<V>` was missing from our model list; `getNovelUpdate` now receives the caller's existing chapters. `ParsedHttpSource` is kept but marked **optional and thin**, because Mihon deprecated its equivalent for hiding the implementation — the critique transfers across languages even though the code does not.

### REJECTED

- **Copying Mihon's domain layout.** Mihon is feature-first (`domain/chapter/{model,repository,interactor}`); we stay layer-first. Chosen by the user; ADR-008 records it so it is not "fixed" back later.
- **SQLDelight.** Mihon's data layer uses it; we keep drift. ADR-005 stands.
- **`--reference <path>` on Forge's `init`.** The documented space-separated form registers nothing and exits 0. Only `--reference=<path>` works.
- **Translating Forge's contract block headings into English.** `forge-guard contract` matches the French headings literally, so an English contract fails as "no content" on all four blocks.

### BLOCKED

- **`forge-guard version_pins_agree` is a false positive on a Dart project.** It reads `.dart_tool/package_graph.json`, treats the literal key `version` as a package named "version", and reports 140+ distinct pins as conflicts. Verified independently that all 24 direct dependency versions agree across `pubspec.yaml`, `pubspec.lock` and `AGENTS.md`. Logged as `guard_failure`; the gate is not blocked by it.
- **`state.js anchor` does not refuse a declared reference project.** Run from `/tmp/opencode/mihon` it resolved Mihon as the anchor with `reference_projects: []`. The guard reads only the candidate's own `state.json`, so cross-project protection depends entirely on passing the anchor explicitly.
- **`state.js finding` cannot target our rule files.** It validates `--domain` against the project-rules-architect *template library* names, so `--domain=17-security.md` is rejected as `unknown_domain`. Machine events go to `state.js log`; routable corrections go to `LEARNINGS.md`.
- **No Android SDK and no Xcode**, so no device build. Still Q-003.

### FILES TOUCHED

- `03-source-system.md`, `18-external-contracts.md`, `DECISIONS.md`, `LEARNINGS.md` — contract corrections, the two verified site records, ADR-008/009/010, Q-001 closed and Q-004 opened, and three new routable corrections.
- `.forge/` — created; `conventions.md` and `contract.md` written and registered; Mihon registered as a read-only reference project.
- `pubspec.yaml` / `pubspec.lock` — removed `cupertino_icons`, an unused Flutter-template leftover, which also enforces ADR-001's ban on Cupertino components. `flutter analyze` zero issues, `flutter test` 5/5 after the removal.

### STATUS

Phase 0 complete and guarded (one known false-positive failure, documented). `.forge/contract.md` passed `forge-guard contract` and went through one `client-liaison check` round that returned REVISE with 11 questions — all 11 addressed in the rewrite.

**Update, same day:** the contract was **signed** by the client and moved `draft → approved`. The client then confirmed all three sites (FanMTL first, then Royal Road and Novel Fire) stay in v1, and confirmed no store, no tablet, CI builds on merge. Those four answers are recorded as client points **C-001…C-004**, all answered, none overdue. **Phase 0 is completed and the current phase is now 1.**

Three new ADRs came out of that exchange: **ADR-011** (CI builds on merge to the default branch, no store — written against `master` because that is the branch that exists; the owner asked for `main`, tracked as **Q-006**), **ADR-012** (the five v1 success criteria), **ADR-013** (all three sites are adapters over one contract, FanMTL is the reference fixture). Q-001 and Q-005 are closed; **Q-004** (Novel Fire's terms are still unconfirmed) and **Q-006** remain open.

Two facts found by fetching FanMTL rather than guessing its markup, both of which would have shipped broken code: its chapters contain **zero `<p>` tags** (prose is bare text separated by `<br><br>`), and the article body is `div.chapter-content`, **not** `#chapter-article`, which also wraps the font/prev/next/night-mode chrome. Both are now promoted into `04-html-to-markdown.md`. And **FanMTL is behind Cloudflare** — every response carried `cf-ray` — contrary to the stated assumption; it did not challenge an honestly-identified client, and `17-security.md` rule 5 now says explicitly that if it ever does, we ask the owner rather than impersonate a browser. `cupertino_icons` was removed as an unused template leftover, which also cleared the last pin mismatch.

### NEXT SESSION SHOULD

Start Phase 1 — the PRD — reading `agents/product-analyst.md` first. The interview is pre-answered from `AGENTS.md`, the contract, and ADR-008/009/010/012/013: problem, users, solution, differentiator, constraints, and the five success criteria are all written down. Run `premise-challenger` at the end of the interview on the initial idea, then again on the finished PRD, as the phase requires. Before the gate: `forge-guard placeholders` and `consistency-check premises`.

Two things are known and must not be re-litigated in the PRD: the v1 site list is **three** sites with FanMTL first (Q-004 still gates Novel Fire), and **ADR-013 fixes FanMTL as the reference fixture** for the platform contract, so the PRD must not re-open "which one source" as if undecided.

### NEXT SESSION SHOULD NOT

- Do not re-derive the Mihon divergences. They are tabulated in ADR-008 with reasons; the temptation to "fix" layer-first toward Mihon's feature-first is the specific thing that decision exists to stop.
- Do not trust `forge-guard version_pins_agree` on this project. It is a JS-manifest check and cannot pass on a Dart dependency graph; verify pins from `pubspec.lock` instead.
- Do not run Forge commands from inside `/tmp/opencode/mihon`. The anchor guard will not stop you.
- Do not re-read Mihon's `source-api` expecting to copy it. `ParsedHttpSource` and most of `HttpSource` are deprecated upstream; our Dart equivalents are ours, and the reference is for scope and screens, not for Kotlin code.
---

## 2026-10-02 — Session 3: PRD approved, roadmap drafted, FanMTL search found unreachable

### STARTED FROM

Session 2's end state: Forge Phase 0 complete, contract signed, 14 ADRs recorded. The PRD was `draft` v3 after two red-team rounds and awaiting the owner's approval. `/tmp/opencode` had been wiped twice, taking the Mihon clone with it.

### DECIDED

- **PRD v3 approved** → Phase 1 closed, `.forge/state.json` `current_phase` advanced to 2.
- **`benchmarks.md` written** — it had been a skipped Phase 1 deliverable that `scope-architect` needs as an input. Mihon claims are source-verified against the clone; Dreame/Webnovel claims come from vendor listings and dated comparisons and are labelled as advertised rather than source-verified.
- **The roadmap's build order deliberately inverts the reader's order**: Wave 2 builds the offline read path headless, with no browse UI in existence at all. This follows the owner's stated wow moment — *"a downloaded novel opens with no signal"* — which makes the offline path a guarantee to be proven, not a feature built later.
- **Q-007 closed → ADR-015.** The owner's answer was a principle, not a one-off: genre browsing is how these sites work and a novel's own tags are the good way in, but a source gets **no search** unless its site genuinely implements one. `Source.supportsSearch` now sits in the contract beside Mihon's `supportsLatest`, and `03-source-system.md` rule 5a makes it a promise rather than a guess.
- **SC-1 amended.** As written it required every source to be "browsed, searched within" — which FanMTL measurably cannot be, so v1 would have been formally impossible to declare done.

### REJECTED

- **Rendering a search box on a source whose search does not work.** Rejected by the owner, and it is right: a visible-but-dead field is indistinguishable from a bug to the reader, which is exactly what B22 exists to prevent.
- **Implementing our own cross-source search index** so search always works. Rejected for v1: it turns a reader into a search engine, needs every chapter's metadata up front, and breaks the moment a site's markup changes.
- **Recording FanMTL's search as robots-blocked.** I had earlier written that its `robots.txt` disallows `/e/…`. The seven paths are `/d/`, `/e/class/`, `/e/config/`, `/e/data/`, `/e/enews/`, `/e/update/` — `/e/search/` is **not** among them. Right decision, wrong reason; corrected in `18-external-contracts.md`. Nearly shipped an inaccuracy in a file whose whole purpose is verified external facts.
- **Repointing the roadmap's four references to roadmap `§7.3`/`§7.4` at some other section.** Those section numbers were invented by the writing agent and do not exist. With no correct target, they were deleted rather than aimed at an arbitrary section.
- **Keeping `US-02` in V1 on its original justification.** Its only stated reason for being there was "SC-1 requires it, else SC-1 fails on a technicality". When SC-1 stopped requiring search, the justification died, so `US-02` left the committed V1 set and became a per-source slice decided by measurement.

### BLOCKED

- **Q-003** — no Android SDK or Xcode here, so no device build. Still closes via CI.
- **Q-004** — Novel Fire's terms of service still unread. Blocks that source only.
- **`forge-guard version_pins_agree`** — unchanged known false positive on a Dart dependency graph.
- **FanMTL text search** — measured unreachable, so permanently `supportsSearch = false` for that source. **Royal Road and Novel Fire search reachability is still unmeasured**, so v1 may claim genre browsing for all three sites and search for none.

### FILES TOUCHED

- `.forge/prd.md` — approved, then **amended extend-only** via `state.js amend`: B50 appended, `US-02`'s acceptance criterion made conditional, `SC-1` amended, validation checklist corrected from "B1–B49" to "B1–B50".
- `.forge/benchmarks.md` — new; registered. Competitive finding: the most-complained-about failure across the five commercial web-novel apps is data loss around reinstall, which is the one thing our device-local library makes structurally impossible (B31).
- `.forge/roadmap.md` — new; registered `draft`. MVP 11 stories (9 whole, 2 partial), V1 6 more, 6 capability deferrals. States plainly that an 11-story MVP at size L is probably still too big and prices a 7-story lean alternative.
- `.opencode/rules/03-source-system.md` — `supportsSearch` added to the contract; new rule 5a.
- `.opencode/rules/18-external-contracts.md` — precise robots paths, two new quirks, per-site search-verdict table with explicit "unknown, not yet checked" entries.
- `DECISIONS.md` — Q-007 closed, **ADR-015** added.

### STATUS

Phases 0, 1 and 2 delivered. `prd` and `contract` are `approved`; `benchmarks`, `roadmap` and `conventions` remain `draft`. Gate state at the last commit: `forge-guard` clean except the known Dart false positive, `consistency-check` clean with 146 section references resolved and 0 broken / 0 undeclared, PRD integrity clean, `flutter analyze` clean, `flutter test` 5/5.

Commits this session: `d52536e`, `6c8f4b3`, `cbde9ac`, `049fa2d`, `232f2b6`, `0c02871`, `b7c041f`, `8801c74`, `c984888`, `383c1c4`, `0517ad9`, `d50da98` — all on `feat/basics`. `master` untouched.

### NEXT SESSION SHOULD

Phase 3 — design and UI/UX. Read `agents/ui-designer.md` and `references/module-prioritization.md`. Mihon's five-tab backbone is Library / Updates / History / Browse (Sources · Extensions · MigrateSource) / More (→ Downloads · Stats · Settings · NewUpdate · Onboarding), with the Reader as its own Activity; the extensions entries do not survive in our v1 because there is no dynamic extension system (ADR-013), but their replacement — a static source registry and a source-management screen — is not a screen deletion and must be recorded as such per screen.

`.forge/design/screens` must end up holding **all** Mihon screens with an explicit copy / adapt / exclude verdict each. The instruction to the agent is to derive from Mihon rather than ask: *"dont ask me questions that could be answered by mihon and fit our lumen tale app"*.

### NEXT SESSION SHOULD NOT

- Do not re-open the search decision. ADR-015 settles it: per-source, gated on measurement, and `supportsSearch = false` for FanMTL is permanent rather than deferred.
- Do not claim search for Royal Road or Novel Fire. Both are **unmeasured**, and the file says so explicitly. Measuring them is cheap; asserting them is not.
- Do not treat the three §7.1 targets marked "not yet measurable" (list responsiveness, download-progress cadence, cancellation latency) as settled. Each owes a number or a deletion in Phase 4.
- Do not apply Forge's section-reference repair mechanically. `§X` appears mid-sentence often enough that a blind replace mangled six lines of the roadmap and had to be repaired by hand.
