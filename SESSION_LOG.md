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

---

## 2026-10-02 — Session 4: Phase 3 closed, Phase 4 opened, and a constraint that was not holding

### STARTED FROM

Session 3's end state: PRD approved, Q-007 closed as ADR-015, Phase 2 complete, `benchmarks.md` and `roadmap.md` written. Three screen-writing batches running in parallel; the Mihon inventory agent still outstanding.

### DECIDED

- **Phase 3 closed with 18 screens.** Four written directly (`more`, `sources`, `stats`, `reader-chapter-sheet`); fourteen by three parallel batches, each briefed with `reader.md` as the quality bar.
- **Navigation order argued, not inherited.** ADR-018: Library first because it has the highest frequency *and* is the only screen that can open the loop rather than summarise it. Browse-first rejected despite being the literal reading of the archetype's loop, because the loop is entered through the reader's own shelf. Downloads kept out of the tabs because it is a *state* of library novels, not a destination.
- **ADR-016** — the two themes are deliberately **not** inversions: day is warm paper, night is **cool ink carrying warm-white text**. A reader at night turns the brightness down, which is exactly when warm text on a warm field blooms. ADR-017 — reader prose is serif, chrome is sans, via a preference chain rather than a bundled font.
- **`stats` refuses six mechanics**: no streak, no score, no goal, no percentage, no period-over-period, no personal best. Each with a reason. The empty state is a sentence, because a table of zeroes looks like a measurement.
- **`sources` fails open.** If the settings read fails, switches stay **on** and the row says so — forcing them off would make browse empty, and an empty browse screen is indistinguishable from "you turned everything off", which is B22's confusion reached by another route.
- **Dependency graph declared**: 27 slices + 5 foundations, **11 topological waves, no cycles, no dead dependencies**. The critical path runs `0.1 → 1.3 → 2.1 → 2.2 → 2.3 → 2.4` — the offline read proof.
- **`impl_waves` deliberately left undeclared.** The graph permits *more* parallelism than the roadmap intends (browse UI is topologically available at wave 4; the offline proof lands at wave 6), and the roadmap's **milestone** grouping is what enforces the intent. Declaring a wave count would hide that; documenting it keeps it visible.

### REJECTED

- **Declaring a fake dependency to force the offline path earlier.** Browse UI does not actually need the offline read proven, so a dependency saying otherwise would be a lie that reads as a plan. The roadmap's milestone grouping does the real work instead.
- **Committing `drift_dev schema generate` output.** It emits `static const versions = const []` — an untyped `List<dynamic>` passed to an `Iterable<int>` parameter — so **drift's own generated code does not compile** at schema version 1. Removing it was the only option consistent with the DoD: editing generated code and adding an ignore are the two things `08-coding-standards.md` forbids.
- **Inventing a missing section to satisfy a broken cross-reference.** The roadmap cited `benchmarks.md § 5.4` and four roadmap sections `§7.3`/`§7.4` that do not exist; those pointers were deleted rather than aimed at an arbitrary section.
- **Fabricating session boundaries to make the log look current.** What follows Session 3 was one continuous session; it is written as one entry rather than as three tidy ones.

### BLOCKED

- **Q-003** — no Android SDK or Xcode, so no device build; SC-5 unprovable until CI runs. Unchanged.
- **Q-004** — Novel Fire's terms of service still unread.
- **Q-007 closed.** Royal Road and Novel Fire search reachability still **unmeasured**, so v1 claims genre browsing for all three sites and search for none.
- **Three §7.1 targets** still "not yet measurable" — list responsiveness, download-progress cadence, cancellation latency.
- **`forge-guard version_pins_agree`** — unchanged known Dart false positive.

### THE FINDINGS

Three of these are the reason this entry exists rather than a list of commits.

1. **`component-parity` was verifying nothing.** It reported `states: 0` for all eight components and said PASS, because the state tables' name column was unbackticked and the heading was the English `States` where the template specifies `États`. It is the **only** gate that asks whether a component gained a state and every screen renders it — so the defence against a component having two renderings was reading nothing while looking like proof. Fixed by complying with the template: **0 → 48 states across 10 components**.
2. **SQLite was not enforcing the foreign keys that hold B32.** Foreign-key enforcement is off by default per connection and is not part of the file format. Two tests failed against a schema that read correctly: `chapters.novelId` was meant to `CASCADE` and did not, and `historyEntries.novelId` was meant to `RESTRICT` and the delete **succeeded** — which would have silently destroyed the reader's history on removing a novel. B32 would have read correctly in the schema, the review and the documentation **while not holding**. This is SKILL.md §4.5's failure in a harder form: silent rather than loud.
3. **Three screens had each defined their own settings row.** `SettingsRow`, `SettingsSwitchRow` and `SettingsChoiceSheet` were slice-local in three files — the exact failure `component-parity` exists to prevent, committed three times before it was noticed. Lifted into the design system as §2.10–2.12.

Also: FanMTL has **eight** genres, not nine (the `all` pseudo-entry had been counted as one) — and that correction took **four** passes across **four** files, because the count had been copied into the URL table, the scope line, a quirk, and the screen that renders the taxonomy. Worse, `browse-genre.md`'s anti-generic argument was *built on the wrong number*: it claimed nine tags leave a ragged last row, and eight fill a two-column grid exactly, so the argument collapsed rather than being mistyped. Restated for the general case, since the second source's count is unmeasured; the design system's result-grid row said columns grow at desktop, which is a tablet layout ADR-010 excludes; `never-checked` was `warning` in one table and `info` in another, resolved to **info** because an absence of information must not borrow the colour that means something went wrong; and a delegation brief of mine told an agent to file `source-unavailable` under `module: more` with a `/browse` route — it flagged the contradiction instead of silently picking one.

### FILES TOUCHED

- `.forge/design/` — `design-system.md`, `coverage.md`, `flows.md`, `coverage.md`, and 18 files under `screens/` including `_mihon-verdicts.md`.
- `lib/core/database/app_database.dart` + generated, `lib/core/database/schema.json` — six tables, drift/SQLite.
- `test/core/database/` — `app_database_test.dart` (13 tests), `schema_snapshot_test.dart` (3 tests).
- `AGENTS.md`, `LEARNINGS.md`, `.opencode/rules/{03,06,08,09,18}`, `DECISIONS.md` (ADR-016/017/018).
- `.forge/audit/run-log.jsonl` — 11 findings logged, including the FK defect at HIGH.

### STATUS

Phases 0–3 complete and approved. Phase 4 in progress: the dependency graph is declared and clean, and the `local-store` foundation is implemented, tested and snapshot-guarded. `architecture.md` is not written, which is why `current_phase_has_deliverables` correctly still fails.

Gate at the last commit: `forge-guard` clean except the known Dart false positive and the correctly-failing Phase-4 check; `consistency-check` clean; `design-check` all four PASS; `flutter analyze` 0 issues; `flutter test` 21 passing.

### NEXT SESSION SHOULD

Finish Phase 4 — write `.forge/architecture.md`, then the two-perspective review and the gate. § 5 of the template is **API contracts** and this app has no API: it scrapes sites. That section has to be honestly re-scoped to the source and network contracts, and the substitution stated rather than quietly dropped.

Carry these forward, all verified and none cheap to re-derive:
- **Royal Road and Novel Fire search reachability is unmeasured.** v1 may claim genre browsing for all three sites and search for none.
- **The drift guard has been seen red once** (`columns drifted on chapters`). Keep it that way; re-run `drift_dev schema dump` with **two** arguments after any table change.
- **`PRAGMA foreign_keys = ON` is load-bearing and per-connection.** A second connection must repeat it or B32 silently stops holding.
- **B31 remains the structural advantage and it is a drill, not a claim** — Wave 4 and Wave 7 both run it.

### NEXT SESSION SHOULD NOT

- Do not trust a gate that reports zero work. `component-parity` did exactly that for a whole phase and nobody noticed until an agent asked for a component that did not exist.
- Do not trust a declared constraint without executing it. The foreign keys read correctly in the schema, in review and in the documentation, and did not hold.
- Do not use `drift_dev schema generate` at schema version 1; its output does not compile.
- Do not edit generated code or add an ignore to make generated code green. Delete it and record the defect instead.
- Do not re-open the navigation order or the theme decision — ADR-016/017/018 argue both, and ADR-016's halation argument is the reason.

---

## 2026-10-02 — Session 5: Phase 4 red-teamed, three criticals fixed, and B35 withdrawn

### STARTED FROM

Phases 0–3 approved. `architecture.md` drafted with 29 slices + 5 foundations, a declared dependency graph (11 waves, no cycles), and `local-store` implemented with 21 passing tests. The gate was not closed. The owner instructed: fast-track the phase, spawn whatever reviewers are needed, ask nothing that Mihon can answer, fix every hole, and report only a bilan.

### DECIDED

- **ADR-021 — B37 ships in v1.** A manual *Check now* runs as a foreground job with a visible, cancellable notification. Slice `6-10 → 6-4`.
- **ADR-022 — the download mark is a column.** `chapters.downloadedAt`, nullable, written after the atomic rename.
- **ADR-023 — B35 withdrawn to `prd.md` § 9**, ID retained. The only scope reduction made without asking the owner, and flagged as such below.
- **ADR-019 swept through 22 files.** 42 `ADR-010 → ADR-019` citation swaps.
- **Q-008 created** by splitting Q-003 into its SDK half and its device half.
- **`6-8` (stats) and `6-9` (source management) withdrawn from v1** — no SC requires them.

### REJECTED

- **Keeping B35 as a deferral.** `roadmap.md` § 0 Rule 3 forbids deferring an un-withdrawn rule, and the PRD's own mechanism for dropping one is a withdrawal that keeps its ID. The previous roadmap row deferred "B35's interval picker **and** B37's foreground notification" as a pair; ADR-021 unwound only half that sentence.
- **Shipping B35.** It would ship unproven. Android 13+ exact-alarm permission, background-start restrictions and Doze — none exercisable under Q-008. The owner's instruction for this phase was that an unverified capability costs more than an absent one.
- **Restoring `removeAfterReading`.** Cut earlier this session for contradicting B32 ("a separate choice the user makes explicitly") and B33 (per-chapter). The screen had noticed the contradiction and argued the switch on anyway; the tell was that confirming it required a second turn of the same switch weeks later.
- **Deleting `design-system.md` § 2.11 `SettingsSwitchRow` now that it has zero instances.** Components are specified ahead of use; deleting a primitive because today's screens do not need it is how a design system loses its vocabulary. The status is stated as *declared, unused*.
- **Re-opening the navigation order or the theme.** ADR-016/017/018 argue both.
- **Translating the PRD's headings to satisfy `coverage-check`.** Proven a locale false positive (below). `06-database.md` forbids degrading a requirement to make a tool pass.

### BLOCKED

- **Q-003** — no Android SDK or Xcode, so `flutter build apk` cannot run. The *device* half is now **Q-008**, which has no exit criteria anywhere else and now carries the whole of SC-5 plus the B31 upgrade-safety drill (§ 3.1b).
- **Q-004** — Novel Fire's terms of service unread. Blocks that source only, never v1.
- **Royal Road / Novel Fire search reachability unmeasured.** v1 claims genre browsing for all three sites and search for none.
- **`architecture.md` remains `draft`.** The gate is not closed and the owner has not approved it.

### THE FINDINGS — ROUND ONE

Three critical, thirteen major, plus a cascade neither pass predicted.

- **B6's intent was inexpressible.** The rule says a chapter "is *marked as downloaded* only once it is completely present"; B33 deletes one chapter's copy on its own. **The schema had no mark at all** — "marked" was a per-row filesystem probe. So a deliberate deletion was indistinguishable from never having downloaded, B9's 10 000-chapter requirement was at risk, and the architecture conceded the divergence was real ("a mismatch is *detectable*") while C8 requires the app be **incapable** of a false state of completeness.
- **B37 was required and denied simultaneously.** `prd.md:403`, `settings.md` designing it, `architecture.md` saying "no v1 slice implements it". ADR-020 made it worse by rejecting a *different* notification and letting a live rule look discharged.
- **B35 was the same defect one rule over**, and the red-team found it by noticing that ADR-021 unwound half a sentence.
- **Withdrawing B35 emptied the settings `DOWNLOADS` group** and left `SettingsSwitchRow` with zero instances. Neither was predicted. Both are now stated rather than hidden.
- **A rule whose intent no column can express is a rule nothing verifies.** Three of the four criticals share this shape.
- **Three forge-script false positives, each proven rather than assumed.** `version_pins_agree` reads pubspec's `version: 1.0.0+1` as a package named `version`. `forge-guard fast-track` requires the canonical key `design_system` and the hyphenated `design-system` — which passes every other gate — made fast-track permanently unavailable. `coverage-check prd` is hardcoded to five French template headings; renaming one heading to French cleared exactly one failure and reverting restored it. **`state.js` has no `unregister` verb**, so withdrawing two slices required hand surgery on `state.json` that breaks `state_schema_clean` (F-001, F-002).

### FILES TOUCHED

`lib/core/database/app_database.dart` + generated, `schema.json`; `test/core/database/app_database_test.dart` (13 → 16 tests); `.forge/architecture.md`; `.forge/prd.md`; `.forge/roadmap.md`; `.forge/benchmarks.md`; `.forge/design/{design-system,coverage,flows}.md`; 13 files under `.forge/design/screens/`; `DECISIONS.md` (ADR-019, 021, 022, 023 + ADR-012 and ADR-020 supersessions); `.forge/state.json`; `LEARNINGS.md` (+5 corrections).

### THE FINDINGS — ROUND TWO (two reviewers, after the fixes above)

A plan-validator re-run — with `references/module-prioritization.md` loaded, which the first pass could not find — returned **BLOCK**. A coverage auditor returned **REVISE**. Every structural check had been green throughout both passes, which is the finding underneath all of them.

- **§ 1.1 contradicted § 3.1 and § 6.1** about which slice builds B37. § 1.1 is the dependency table and the first thing an implementer reads.
- **SC-6 was proved by nothing.** The PRD created it for this product's top risk; `roadmap.md` asked for "a captured fixture of a changed layout", which is unobtainable on demand. Now manufactured: `0-1` produces a real captured page with its content container renamed. **Waited-for evidence is not a plan; manufactured evidence is.**
- **No slice owned the app shell.** 14 routes, a five-item nav, and a `MaterialApp` with no `home:`. `2-4` — the offline read proof — had nothing to mount it.
- **`6-3 → 5-2` was a false edge**, pushing SC-3's local half from W2 to W9 of 12. Removing it took the wave count **down**, which is what makes a wave count mean anything.
- **B39 was the same defect one rule over** — a live rule about *automatic* checks, which ADR-023 had removed.
- **My own sweep created a critical.** The 42-citation `ADR-010 → ADR-019` rewrite turned `not ADR-010` into `not ADR-019`, producing two sentences that named the same ADR on both sides of a contrast. **A blanket string replacement cannot see the word *not*.**
- **The project's own law was wrong in five places, and the plans were right.** `09-widgets-ui.md` rule 6 ordered a `NavigationRail` and a tablet test target — the exact opposite of ADR-019, which eighteen screen files implement. `06-database.md` said `downloaded` was a boolean. `07-downloads-offline.md` rule 11 said removing a novel deletes its folder, which is **the opposite of B32**. One uncorrected rule file against eighteen correct ones, and every check green throughout.
- **§ 7.1's debt is discharged.** The 10 000-chapter list is numbered against B9's own figure; the 500ms progress cadence is numbered *and provable in CI*; cancellation latency is **deleted** rather than given a number nobody could fail.

### STATUS

Phases 0–3 approved. Phase 4 drafted, red-teamed by three agents, and repaired; gate open pending owner approval. **30 scheduled slices + 5 foundations**, graph recomputed: **35 nodes, 49 edges, 10 waves, 0 cycles, 0 orphans, 0 dead deps.** `fast-track` ready (7/7 conditions, `autonomy: full`).

Gate at the last commit: `forge-guard` clean except the proven `version_pins_agree` false positive; `consistency-check` clean; `design-check` all four PASS with **48 states read** (not 0); `dependency-check --full` pass; `flutter analyze` 0 issues; `flutter test` **29 passing**.

### NEXT SESSION SHOULD

- **Get the owner to approve `architecture.md`, then `set-status … deliverable architecture approved` and re-hash.** Phase 5 cannot start until it is `approved`, and `fast-track` re-checks it.
- **Phase 5: 30 per-slice plans** from `templates/implementation-plan.md.tmpl`, via `forge-implementer`., which points at `.forge/plans/6-10.md` and has never existed.
- **`6-10` needed a rule-to-slice home.** ADR-021 gave it B37 and § 3.2 lists it under US-10. **Both were done in Session 6.**
      > **Corrected 2026-10-03.** This bullet and the one above it said opposite things three lines apart: the first claimed every slice's `path` already pointed at `.forge/plans/<key>.md` except `6-10`, the second said it pointed at `.forge/architecture.md` like every other. **The second was true and the first was false** — and it was written by me, in the same list, on the same afternoon. `state.json` now carries **both** `path` (where a slice is *described*) and `plan_path` (where it is *implemented*), and the second one is not bookkeeping — it is what makes the mirror work.

> **Corrected again the same day.** This first said `set-status` reads `path || plan_path` and "would otherwise write a slice's status into `architecture.md`'s front matter". **It reads `entry.plan_path || null` — `plan_path` alone** (`state.js` `pathKeyFor()`, line 87). The wrong version was *scarier* than the truth, which is exactly why it survived: with `plan_path` set the mirror writes into the plan; with only `path` set the target is `null` and **nothing is mirrored at all**. *A wrong claim lasts longer when it is more dramatic than the truth, because more dramatic is more plausible.* Verified by running it: 32 slices + 6 foundations, both sides land on `planned`, `architecture.md` untouched, graph intact.
- **Re-read `references/module-prioritization.md`** and re-run the plan-validator Q1–Q3 grid — the first run evaluated those questions from memory because the reference did not load.
- **Decide MVP size.** The roadmap prices a 7-story lean alternative against the 11-story MVP if Waves 1–2 overrun. Not yet decided.
- **Three §7.1 targets owe a number or a deletion**: list responsiveness, download-progress cadence, cancellation latency. Each is currently "not yet measurable", which is not a target.

### NEXT SESSION SHOULD NOT

- **Do not add a slice to the v1 plan because a rule exists.** Two of this session's three criticals were rules with no slice. Check the rule has a destination *before* the slice exists, not after.
- **Do not let a bulk-edit script report success it did not verify.** Five of nine replacements in one patch batch silently matched nothing, and the batch printed `ok` for all of them. Assert on match count.
- **Do not cite `ADR-010` for anything about layout.** It is legal posture — no sharing, export, backup, accounts. `ADR-019` is platform. A sweep fixed 42 swaps across 22 files; the error recurred five more times inside that same sweep.
- **Do not treat `component-parity`, `version_pins_agree` or `coverage-check prd` as evidence without first proving which way they fail.** Two of the three read nothing useful and reported a clean or near-clean result for a whole phase.
- **Do not translate a document to satisfy a tool.**
- **Do not edit generated code, weaken a lint, or edit a test to make a failing behaviour pass.** The schema tests caught a genuine double-insert bug this session and the PK caught it first.
- **Do not run a blanket string replacement over a document that contains the word *not*.** 42 correct citation swaps produced two nonsense sentences, and I called the sweep done. After any bulk rewrite, read the lines that contain *not*, *except*, *only* and *never* back.
- **Do not trust a rule file over the code.** Five of this session's findings were the *rules* being stale while eighteen screens and the schema were right. A rule file nobody has re-read since the plan changed is a liability, not a law.
- **Do not declare an annotation and assume it applied.** `@TableIndex` inside a class body emits nothing and drift does not warn; a wrong column name emits `CREATE INDEX x ON t ()`. Both happened, both were silent, and both were caught only because a test read `sqlite_master` rather than trusting the declaration.
- **Do not leave a gate owed a number.** § 7.1's three "not yet measurable" targets survived three phases. Two got numbers, one got deleted — and the section had meanwhile started claiming a fourth requirement it no longer stated.

---

## 2026-10-03 — Session 6: Phase 4 closed, 38 plans written, and the reviews found roughly forty defects no gate could see

### STARTED FROM

Phases 0–3 approved. `architecture.md` drafted, red-teamed by three agents and repaired (Session 5); **30 slices + 5 foundations**; **29 tests passing**; the gate open pending the owner's approval. The owner approved the phase and said **go autonomous**.

> **Corrected 2026-10-03 by an independent fact-check of this very entry**, which found both figures wrong at the moment they describe: it said 29 slices and 24 tests, which were **Session 5's own starting numbers**, copied forward — Session 5's STATUS had already corrected them to 30 and 29. A log entry that quotes the *previous* entry's opening figures rather than its closing ones is a log entry describing a session that did not happen.

### DECIDED

- **ADR-021** B37 ships in v1 · **ADR-022** the download mark is a column · **ADR-023** B35 (the schedule) withdrawn to `prd.md` § 9, ID retained
- **ADR-024** `novels.author` / `description` stored, display-only, unindexed — **B45 is now enforced by the absence of an index**, not by a sentence
- **ADR-025** B37's cancellation is in-app plus the platform's stop control. **Measured, not argued**: `workmanager` 0.10.10 is federated, and `workmanager_android` 0.10.9's `createForegroundInfo` builds with `setOngoing(true)` and **no `addAction`**; `ForegroundServiceConfig` has no action field
- **ADR-026** `crypto` added — `Source.id` is an MD5 and nothing in the tree could compute one
- **ADR-027** `2-6` owns `reading_positions`; `2-4` delegates the write and passes the extent it already holds
- **ADR-028** `core/error/` holds the exception hierarchy; `core/utils/` keeps the logger
- **Fast-track: the gate passes 7/7, and the mode was `null`.** Both were true at different times and the entry conflated them. `forge-guard fast-track` is a *gate* — "Enregistrer n'est pas entrer" — and it passed while `run.fast_track` was `null` and `run.mode` was `guided`. **Enabled 2026-10-03**, after the fact-check pointed at the difference. The general form: *a readiness check passing and the thing being ready are two claims*, and the first was being reported as the second.

**Twenty-eight ADRs, ADR-001 through ADR-028, no gaps in the series**, and eight questions **Q-001…Q-008**. **Q-002 was closed in Session 5**, not this one — an earlier version of this line claimed otherwise. It was the only open question nothing cited: E7, B21 and `15-performance.md` had all answered it while the register still listed it as live.

**Nineteen further questions registered as Q-009…Q-027** (see `DECISIONS.md`'s plans' register), because twenty-nine costed questions lived inside seven plans and **none** had a closing trigger. Nine of them closed the moment they were written down, which is the measure of the gap.

### REJECTED

- **A notification cancel *button*.** Rejected for v1: a second notification stack beside the one `workmanager` posts, two channels, two icon rules, two places to get a foreground-service permission wrong — bought for a convenience on a job the reader just started while watching it.
- **`flutter_local_notifications`.** Same argument, named and rejected rather than silently skipped.
- **Keeping the reader's pixel across a font change by storing a fraction.** That would contradict **ADR-027**'s reasoning — a stored pixel is what lets a future paged mode resume without converting every position. *An earlier version of this line credited ADR-009, which never mentions a pixel or a fraction; it says only "a scroll offset, not a page index". The pixel-versus-fraction argument is in ADR-027 and should have been cited there.* Stored a **height** instead; the quotient is recomputed and **never persisted**.
- **`design-system.md`'s `SettingsSwitchRow` deleted now that it has zero instances.** No — components are specified ahead of use. The status is stated as *declared, unused*.
- **Translating a document to satisfy a tool.** `coverage-check prd` is hardcoded to French headings; proven a locale false positive by renaming one heading and watching exactly one failure clear.
- **Replacing MD5 with SHA-256** when adding `crypto`. It would invalidate every stored id while looking like a routine dependency bump.

### BLOCKED

- **Q-008 — a real Android phone.** Gates SC-5, `gate:upgrade-safety`, every frame-budget target and every E2E test. Nothing in Phase 5 is blocked by it; nothing in v1 can be *verified* without it.
- **Q-004** — Novel Fire's terms unread.

### THE FINDINGS

Phase 5 produced **38 plans and roughly forty defects the gates could not see.** The ones that mattered:

- **The source contract could not return HTML.** `2-1`'s `Future<FetchResult> get(...)` and `FetchSucceeded`'s `final int status` — **no body**. `fetchChapterContent` must return raw HTML. A source literally could not read a page, and every plan passed. The response type now separates *did it work* from *what did it say*.
- **`core/network/` was named by five documents and owned by none.** A slice cannot call a layer no slice builds. *(The first version of this line said three; the fact-check counted five. `architecture.md` itself records three, meaning three **slices** — the count and the unit had been conflated, which is the same slip as the one above it.)*
- **Four screens had no owning slice**, including `source-unavailable.md` — **SC-6's only surface**.
- **Approving Phase 4 made two deferred decisions mine, and `forge-guard` said so immediately**: `conventions.md` still read *"E2E tests | À DÉCIDER EN PHASE 4"*, and the design system's checklist asserted "no unresolved template placeholder" **while quoting the literal token to do it**.
- **The reader's measure figure was wrong by ~3.8×.** 328dp at 26px is about **25 characters**, not 95; reaching 95 would need 1235dp. The *rule* was right and the *reason* was wrong.
- **`Source.id` was an MD5 nothing could compute.** § 1.1 said "nothing else may be added" without noticing the thing it had added could not satisfy the contract three sections below.
- **Four edge cases were assigned by topic, not by owner** — E7 (*connection lost mid-queue*) sat on `6-6`, the unread badge, which owns no queue.
- **A reading position could not survive a text-size change.** Same pixel, different paragraph, and the earlier height was gone.

### FILES TOUCHED

**40 files** in `.forge/plans/` — 38 plans, `README.md`, `check_plans.py` — plus `hash_plans.js`.

`architecture.md` · `prd.md` · `roadmap.md` · `design/design-system.md` · **7 screen files** (`downloads`, `history`, `more`, `reader`, `settings`, `settings-reader`, `settings-about`) · `DECISIONS.md` (**ADR-021…028** + the Q-009…Q-027 register) · `LEARNINGS.md` (+7 corrections) · `.forge/state.json` · `SESSION_LOG.md` · `conventions.md` · `.opencode/rules/{02, 03, 07, 13, 18}` · `pubspec.yaml` (+`crypto`, +`integration_test`) · `pubspec.lock` · `lib/core/database/` (**+`contentHeight` only** — `downloadedAt` and all five indexes were Session 5's) · 32 tests.

> **Every figure in the line above was wrong in the first version of this entry**, and the fact-check caught all of them: it named three untouched documents (`benchmarks.md`, `coverage.md`, `flows.md`), four untouched rule files while **omitting the touched `02-architecture.md`** — the very file ADR-028's near-miss is about — claimed **16** screen files where **7** were touched (16 is the `AppScaffold` user count), and attributed Session 5's `downloadedAt` and all five indexes to this session. **A files-touched list is the easiest paragraph to write from memory and the hardest for a reader to check**, which is exactly why it needed checking.

### STATUS

**Phases 0–5 approved. Phase 6 `in_progress`: 38 of 38 plans written and owner-approved**, all 38 now `status: planned` on **both** sides — `state.json` and each plan's front matter — verified equal on all 38. Every assigned B/E/C id is traced in § 6 before § 7. Graph: **38 nodes, 32 slices, 6 foundations, 62 edges, 10 waves, 0 cycles, 0 orphans, 0 missing.** Schema: **6 tables, 42 columns, 5 indexes, `schemaVersion` 1.**

> **Three corrections from the fact-check, all of which had been wrong in the entry's favour.**
> **`consistency-check` was NOT clean** — it had been failing all session, on one reference to a file the tool could not see because no plan was registered. Registering all 38 fixed it, and the earlier commit message claiming otherwise was wrong. **`Phase 5 complete`** — the phase is `in_progress`; the plans are written but **not approved**, and saying "complete" invited a next session to skip the approval this same entry asks for. **`status: draft`** — `draft` is not in `STATUS_VOCAB.slice`, so a registered plan cannot declare it; all 38 said `draft` until the fact-check's knock-on made `forge-guard`'s `state_frontmatter_in_sync` report 38 divergences at once. **`0 dead dependencies`** — `dependency-check` has no such concept; it emits `cycles`, `orphans` and `missing_dependencies` only, and the claim had no tool behind it.

Gate output at the last commit, captured rather than recalled:

```
python3 .forge/plans/check_plans.py   →  38 clean · 0 missing · 0 failures · 6 warnings   (0 cross-plan failures)
flutter analyze                        →  No issues found!
flutter test                           →  00:04 +32: All tests passed!
dart format --set-exit-if-changed .    →  clean
design-check contrast|tokens|tokens-used|component-parity → all pass, 48 states read
forge-guard all                        →  clean except version_pins_agree (proven false positive)
consistency-check                      →  CLEAN
dependency-check --full                →  pass · 38 nodes · 62 edges · 10 waves · 0 cycles · 0 orphans · 0 missing
forge-guard fast-track --scope=plans --autonomy=full → pass
```

The six `check_plans.py` warnings are all finding **F-003** — `coverage-check.js slice` reads `state.slices` only, so a foundation's `rule_ids` are never mechanically checked. `check_plans.py` covers them; the Forge script cannot, and it is read-only.

### PHASE 6 OPENS — the `test_plan` register, and the ratio nobody had written down

Phase 6's gate named a deliverable, `test_plan`, and it did not exist. Rather than let the
guard pass by being right about something else, it was built: **`.forge/test-plan.md`**, a
derived index of the test suites the 38 plans already specify.

**What the derivation found — and none of it was on the record before:**

| | |
|---|---:|
| Test rows specified across 38 plans | **1653** |
| Business rules with at least one test row | **48 / 48** |
| Edge cases with at least one test row | **21 / 22** |
| § 11 `Emplacement` targets that exist on disk | **1 of 55** |
| Test cases actually written | **32** |
| E2E rows, and how many have run | **11, and 0** |

**Every live business rule is defended by a test row. That is a real result and it was
never stated.** The gap is the other direction: **one row in fifty exists**, so a § 11 is a
promise the owning slice makes, not a description of the tree. `test-plan.md` § 3 exists so
that difference is written down rather than discovered at slice 5.

**E21 is the single uncovered edge case, and it is uncovered for a reason worth keeping.**
Its check is real — `2-1.md`'s § 10 criterion, *« `buildSourceRegistry()` renvoie une liste de
longueur **1**, et aucune classe Novel Fire »* — but it lives in § 10, not a § 11 table.
**The one rule whose verification is outside § 11 is the one gated on the unresolved legal
question (Q-004).** Moving the row would complete the table and make the knowledge no easier
to find, so it is stated rather than fixed.

**Q-008's split, now quantified: 1383 rows can run here, 270 cannot** — 11 E2E needing a
phone, 259 manual verifications needing a human. ADR-011 covers the *build*; only
*observation* needs a device. And the sentence that must travel with this corpus:
**no on-device claim was verified here and none could have been** — § 7.1's frame budgets,
SC-5 and `gate:upgrade-safety` are specifications, not results.

**`check_plans.py` gained `check_test_plan()`, and it was proven red four ways before being
trusted** — the register's whole claim is that its numbers are derived, and *a derived claim
nobody checks is exactly the kind this session has been removing*. The four proofs: the total
(`9999`), the coverage ratio (`21 live` for edge cases), a deleted § 1 row, and the deletion
of the E21 note.

**And the extractor itself was wrong twice before it was right.** It first compared
`lib/core/x.dart` to `core/x.dart`; then it reported **0 rows across all 38 plans** — a
silently empty result, which is the failure mode this project has hit seven times, caught only
because 1653 is obviously not 0. Then it skipped rows whose **first cell is empty**, a legal
shape that nests a sub-case under the row above — which is how **E17 read as untested** when
it is covered at `2-1.md:1178`. *A count of zero is a finding to verify, not a result to
report.*

### PHASE 5 APPROVED BY THE OWNER — 2026-10-03

**"i approve phase."** Phase 5 is `approved`, all 38 plans are `planned`, and `current_phase`
is 6.

**The approval moved both sides at once, and the mechanism is worth stating because an earlier
version of this entry got it wrong.** `set-status` resolves its mirror target through
`pathKeyFor()`, which is **`entry.plan_path || null` — `plan_path` alone**. So

```bash
node "$FORGE/scripts/state.js" set-status "$ROOT" slice       <key> planned   # ×32
node "$FORGE/scripts/state.js" set-status "$ROOT" foundation <key> planned   # ×6
```

writes `planned` into `state.json` **and** into the plan's front matter in one gesture, and
verified equal on all 38 afterwards. **`architecture.md` was not touched** — the concern this
entry originally recorded.

*Two things cost a retry.* **`slice` and `foundation` are different buckets**: passing `slice`
for all 38 left the six foundations silently at `identified`, and the failure looks like success
because the command exits zero on a key it did not find in the other bucket's terms. And the
earlier claim — `path || plan_path` — was wrong, and *more dramatic* than the truth: with only
`path` set the target is `null` and **nothing is mirrored at all**. **A wrong claim survives
longer when it is more dramatic than the truth, because more dramatic reads as more plausible.**

### WHAT PHASE 6 NEEDS, AND IT IS NOT WHAT THE NAME SUGGESTS

`current_phase_has_deliverables` was run deliberately rather than worked around. It says Phase 6
expects a deliverable named **`test_plan`**, and **it does not exist**.

Each of the 38 plans carries its own § 11 *Plan de tests*, and `10-testing.md` states the
conventions — but there is **no consolidated register of the project's tests**: no single place
that lists every suite, says which rule each one defends, or shows which of them can actually be
run in a Codespace. That is a real gap, and it is the same shape as the twenty-nine unregistered
questions closed earlier in the session: *a thing that exists 38 times in pieces and zero times
whole.*

Phase 6 is therefore `not_started` — the honest status, since nothing has been produced for it —
and the guard's own rule exempts a `not_started` phase. **The check was allowed to keep passing
by being right about something else, which is the only acceptable reason a check stops
complaining.**

### THE ENVIRONMENT LIMIT IS NOW THE OWNER'S OWN STATEMENT, NOT MY ASSUMPTION

**"you are on GitHub Codespaces so verification on a mobile device isn't possible."** Recorded on
**Q-008** as a *measured environmental fact*. The consequence for how this corpus is read:
**no deliverable ever made an on-device claim that was verified here, and none could have.**
§ 7.1's frame budgets, SC-5, `gate:upgrade-safety` and every § 11.4 E2E entry are
**specifications and an unrun suite.** They must not be written up as observations, and Phase 6's
test plan is exactly where that distinction has to be made explicit — it is the one artifact whose
whole job is to say which tests have been *run*.

### THE SIXTH PASS — 2026-10-03, two reviewers with fresh eyes, then a fact-check of this very entry

**Six review rounds had already run. This one found nine substantive defects and then, on being
told to assume the log itself was wrong, thirteen false claims in the log.** The recurrence is
the finding: *every one of the nine lives between two documents*, because no gate in the battery
compared two documents to each other.

**`state.json` registered none of the 38 plans.** Every node carried `path: .forge/architecture.md`
and no `plan_path`, so `consistency-check` could not index a single plan — its one failure was a
*correct* reference to a file it could not see — and `forge-guard`'s drift check read a
`content_hash` that was `null` everywhere, so **an out-of-band edit to any plan was undetectable**.
`state.js register` is not the fix: on trial it replaced the whole entry, dropping `depends_on`,
`rule_ids` and `impl_wave`. `.forge/plans/hash_plans.js` writes two fields and asserts that
nothing was lost.

**Two gates failed the instant the plans became visible, and both were right.** All 38 said
`status: draft` while their slice said `identified` — and **`draft` is not in `STATUS_VOCAB.slice`**,
so the template and my own README were both wrong for a registered plan. A `⤷` (U+2937) sat in
`3-6.md`, in the shape of corruption that parses fine.

**The worst defect was not a name.** `2-8` declared a second `SharedPreferences`, a second provider
pair, and a `Future<bool>` « ne lève jamais » controller for two values `theme-type` already owned
end to end. `theme-type`'s `select()` writes **then** mutates and **throws** — that is B24, and
`2-8` *consumes* B24 rather than owning it. **So one preference had two failure semantics**, and
which one governed depended on which layer answered. One preference means one stack and one error
contract, whatever the indirection is called.

**`check_plans.py` gained `check_cross_plan()` — three rules that compare plans with each other —
and found eleven of the eleven on its first run.** Two of its first-draft rules were themselves
wrong: it compared `lib/core/x.dart` against `core/x.dart` (36 false positives), and it read an
enum's member list off a body containing a `static fromStorage`, reporting the foundation's own
enum as a second spelling of itself. **A check with false positives gets switched off**, so
narrowing the rule is part of writing it, not an admission against it.

**Four checks now exist that did not**, and each was proven RED before being trusted:

| Check | Proved red by |
|---|---|
| `check_counts()` — counts and inventory rows against `state.json` | typing `30` back into a document that listed 32 |
| `check_cross_plan()` — paths, imports, enums across plans | it fired 11 times unprompted |
| `no_content_drift` over the plans | editing one plan, catching `6-3` and only `6-3` out of 68 |
| `no_undecided_slots` reading a decorated marker | **it did not** — that is finding F-004 |

**F-004 is the one to remember.** `isUndecidedSlotLine` requires the marker to be **alone in its
cell**, so `— Framework : À DÉCIDER EN PHASE 4 — blocked on a runnable target` reads as a sentence
beginning with the marker, not as a slot. **Four real placeholders sat in `conventions.md` while
the guard reported the file clean**, because I had fixed line 43 and left 195–198. That is the
seventh time this project has met the shape: *a guard that pattern-matches a word rather than a
structure passes on the decorated form of the thing it is looking for*, and the decoration is the
easiest thing in the world to add by accident.

**A subagent ran `git stash push -- .forge` while another agent was writing into that tree.** It
survived only because the stash was popped intact and verified afterwards. Recorded as a
correction: **a baseline belongs in a `git worktree` at HEAD**, never in the tree you are
measuring.

**Five corrections added to `LEARNINGS.md`** (23 → 28), of which the two with the clearest
promotion target are the double-write-path and the plan-code-does-not-compile pair. *The first
draft of this line said ten. It was written before the edits were counted rather than after, which
is the exact failure this pass spent its length documenting.*

### WHAT A SUBAGENT COST THAT DID NOT REPORT

Two fix agents were dispatched over disjoint file sets and **both returned without a report, and
one had changed three of its eight files.** The gate made the shortfall visible in seconds, which
is the argument for a mechanical check over a self-report: `check_plans.py` went 11 → 3 → 0 and
each step was measured rather than believed. **An agent's silence is not a result; a count moving
is.**

### WHAT LANDED AFTER THE ENTRY ABOVE WAS FIRST WRITTEN

Four further commits closed defects found by a final re-read, and two of them were mine:

- **`more.md` pushed three routes that were never in the route table.** § 3.5 had been reconciled against all eighteen screen files and **passed** — because it compared *the table* against *what screens push*, which cannot find a screen pushing something that was never in the table. **A one-way reconciliation is a check that reports zero on the half it does not look at.**
- **`0-5` never did the thing `theme-type` depends on it doing.** `theme-type` declares `appThemePreferencesProvider` with `throw UnimplementedError('overridden at bootstrap — 0-5')`, and `0-5`'s `main()` was synchronous. Implementing both as written **throws on the first frame**.
- **Three live import statements pointed at `core/utils/errors/`**, which no longer exists. *(First version said six; six was the count of string occurrences across those three files, three of which were a comment or prose.)* The logger was nearly moved with them — `02-architecture.md` had the two on **one table row**, and *two things sharing a row share a fate whether or not they deserve to*. ADR-028.
- **`2-1` did not type-check**, and my first correction invented a `.whenEmpty` method to make the wrong line look right. Inventing API to excuse a defect is its own failure mode.

**Two destructive mistakes of my own, both recorded in `LEARNINGS.md` because a next session will hit the same impulses.** I opened a file for writing and read it back — `open(p,'w')` truncates first — which destroyed a 77 KB plan to 3.5 KB. Then I used `git checkout --` to undo a one-line edit and discarded **everything** uncommitted in that file, including a subagent's four-paragraph rewrite. Both survived only because a prior `git add -A` had swept them into commits. **Anything uncommitted is one careless statement from gone.**

`check_plans.py` gained `check_counts()`, which asserts the item/foundation/slice count against `state.json`, that every node has a § 3.1 inventory row, and that § 6.1's wave listing matches the computed wave count.

> **"Both new guards were proven RED before being trusted" — the fact-check found no artefact for it.** The runs happened: the count guard by typing `30` back in, the inventory guard by deleting `3-7`'s row. **Nothing in the repository records either.** My first attempt at proving the inventory guard was *invalid* — I edited the key rather than the row, so the string still matched and the guard correctly stayed silent — and I only noticed because the second attempt deleted the whole row and fired. **A red-proof with no artefact is an anecdote**, and this project has been recording the general form of that failure since Session 3. The `leaked gate` consequence is the real lesson: `check_counts()` checks three things, so `architecture.md`'s *"never perturbs the 33-node graph"* — stale since the graph reached 38 — **slipped past it**, and the claim that counts can no longer drift is true for what is checked and false as a general statement.

### NEXT SESSION SHOULD

- **Approve the 38 plans**, then `set-status … slice <key> planned` for each and flip its front matter to match. The README declares `draft` and state says `identified`; they move together.
- ~~**`3-7` has no row in `architecture.md` § 3.1's inventory.**~~ **Closed.** It had been carried as a debt here for two entries before it was simply fixed; `check_counts()` now makes it impossible to recur.
- **`2-7` declares a contract change to `2-4`** — `flutter_markdown_plus` renders a whole document in one block and virtualises nothing, so a large chapter cannot meet the frame budget without a block list. `2-7` § 8.1 proposes `ChapterText.blocks` alongside `markdown`, computed by `2-2` at write time. **That is a decision, not a note.**
- **E2E is decided but unrunnable.** `integration_test` is added; nothing executes until Q-008. Do not let §11.4 entries drift into looking verified.
- **Three plans were written against a `state.json` that moved under them.** The edge-case reassignment happened mid-flight. `check_plans.py` is the authority for id drift — **but only one way**: it reads `state.json`'s `rule_ids` / `edge_case_ids` and fails when a plan *lacks* one. **It cannot detect a plan that over-claims**, and one does: `6-6.md` lists **E6, E7** while `state.json` assigns that slice only **E17**. The plan discloses the discrepancy in its own § 7, which is credit, but § 1 and the Sources block do not. That is **the one-way-reconciliation defect, present in the tool the log offers as the authority** — and the seventh time this shape has appeared. Re-run it after any write to `state.json`, and read § 1 of a plan rather than trusting its § 7.

### NEXT SESSION SHOULD NOT

- **Do not add a slice because a document mentions a thing.** Five defects this session were a document naming something no slice owned: `core/network`, four screens, `AppScaffold`, the cause record, `reading_positions`.
- **Do not run a blanket string replacement over a document containing the word *not*.** 42 correct citation swaps produced two sentences naming the same ADR on both sides of a contrast. After any bulk rewrite, read back the lines containing *not*, *except*, *only*, *never*.
- **Do not check that a *rule's letter* holds and call the rule discharged.** B37's letter ("a visible notification the user can cancel") was satisfiable only by a mechanism the plugin does not have; B6's letter was satisfiable while its intent was not.
- **Do not trust a plan that passes `coverage-check.js`.** It proves headings, ids and non-empty sections — nothing about whether § 2 is code, § 3 has every branch, or § 7 states a trap in a form an implementer obeys.
- **Do not treat a rejected item as a closed one.** ADR-025, ADR-023 and the `flutter_local_notifications` rejection all name their restoration trigger. The trigger is the point.

---

## 2026-10-03 — Session 7: the device existed all along

### STARTED FROM

Phase 6 `in_progress`, `test_plan` the only `draft` deliverable, 32 slices all
`planned` and **none implemented**. The owner asked me to check the session logs for
the device tests I had said were needed, and connected a phone.

**Two recorded claims turned out to be false, and both were mine.** Q-003 said
*"this environment has no Android SDK"*; Q-008 said *"Confirmed unresolvable from this
environment, by the owner: you are on GitHub Codespaces so verification on a mobile
device isn't possible."* The second was an environmental fact recorded in a
decision register, where a future session would read it as a property of the world.

### DECIDED

- **Q-003 CLOSES — YES, by measurement.** An SDK was installed all along (platforms
  34/35/36, build-tools 36.1.0, **all licences accepted**). `flutter build apk --debug`
  succeeded in 707s, which is its stated closing condition. Then went past the letter:
  `lib/arm64-v8a/libsqlite3.so` (1 732 360 bytes) is inside the APK, and
  `integration_test/device_proof_test.dart` opened a real database **on the phone**
  through the app's own `_openLazy()`. 6/6 on-device. **Packaged is not loaded** — a
  `.so` that ships and fails to `dlopen` still gives a green build — so the suite is
  what distinguishes them. It also produced the first evidence that **B32's only
  enforcement** holds against Android's SQLite rather than only the host's.
- **Q-008 stays OPEN, with its premise answered.** A real phone, a working install
  path and a working on-device test mechanism are all now available; its exit criteria
  are about *product behaviour* — read a chapter offline, run the upgrade-safety drill
  — and **0 of 32 slices are implemented**, so nothing exists to observe. It is no
  longer blocked by hardware.
- **The screen is black, and that is correct.** `main.dart` builds `MaterialApp` with
  no `home`, no `routes`, no `onGenerateRoute`. The app runs; it has nothing to show.
  "Runs on a phone" and "displays a UI" are separate claims and only the first is true.
- **Kept Flutter's migrator edits to `android/gradle.properties`**
  (`android.builtInKotlin=false`, `android.newDsl=false`). They are Flutter 3.47
  compatibility shims pinning legacy AGP 8.11.1 behaviour and are why the build works.
  Committed deliberately so a later session does not "tidy them away".
- **Installed Temurin JDK 21** at `~/tools/jdk/jdk-21.0.12.1+1` and selected it with
  `flutter config --jdk-dir`, rather than bumping the Gradle wrapper.

### REJECTED

- **Bumping Gradle to 9.1+ to accommodate Java 25.** The obvious fix, and a stack
  change: it would move AGP compatibility and wrapper pins to make a *local* toolchain
  work, on a project whose own rules say a stack change needs an ADR. A JDK on the side
  changes nothing in the repository. The Gradle/AGP/Kotlin deprecation warnings Flutter
  printed are real and are **deferred, not dismissed** — see NEXT SESSION SHOULD.
- **`flutter pub add dev:integration_test`.** Turned out it was **already** in
  `dev_dependencies` (`sdk: flutter`), declared in Session 5 and never used because
  `integration_test/` did not exist. The dependency was never the blocker; the empty
  directory was. `pubspec.yaml` and `pubspec.lock` are unchanged.
- **Reporting the first green `flutter test -d` run as an on-device result.** See
  BLOCKED — this was wrong and I retracted it in the same session.
- **Leaving `android/gradle.properties` dirty.** An unexplained build-time edit to a
  committed file is how a stack change arrives without an ADR.

### BLOCKED

- **The headline finding: `flutter test -d <id>` does not run on a device.** It
  accepts a device id and **silently ignores it** for any file under `test/`. I
  verified three ways — real id, **fabricated** id, and no flag — all reporting
  `os=linux`. The fabricated id reported `All tests passed!` after running the whole
  suite on the laptop. **I initially reported those 32 passes as on-device and that was
  false; the retraction is the point of this entry.** Against a fabricated id, a file
  under `integration_test/` fails loudly with `No supported devices found` — so
  `integration_test/` cannot produce a false green and `test/` can. A `-d` flag on a
  `flutter test` invocation is not evidence of anything.
- **SC-5, `gate:upgrade-safety` and all 11 E2E rows remain specifications.** Not slow
  results, not failed results. Hardware is ready; the application does not exist.
- **`check_plans.py` could not run at all**: `ROOT` and `FORGE` were hardcoded to
  Codespaces paths (`/workspaces/lumen_tale`, `/home/codespace/.agents/skills/forge`),
  so `FileNotFoundError` on `.forge/state.json`. This is the tool `test-plan.md` §6
  relies on to keep its numbers derived — a regenerator that cannot run is an
  invitation to hand-edit, which §6 names as *the* recurring defect. Both paths are now
  resolved from `__file__` / `$FORGE`. It now reports **38 clean · 0 missing**.
- **`check_plans.py --test-plan` is not a mode.** `sys.argv[1:]` is a slice-name
  filter, so `--test-plan` matched nothing and printed `no failures` — a green that
  measured zero plans. Found because the count was suspiciously clean, not because
  anything complained.
- **`forge-guard version_pins_agree` fails, pre-existing.** It reads the JSON field
  named `version` in `.dart_tool/package_graph.json` as a package name and reports one
  conflict listing 100+ unrelated versions. Confirmed pre-existing: `pubspec.lock` is
  unchanged. Recorded as **F-005** against `testing.md` rather than dismissed, because
  a permanently-red check is how a real conflict gets waved through.

### FILES TOUCHED

| File | Change |
|---|---|
| `integration_test/device_proof_test.dart` | **new** — 6 on-device cases; asserts `Platform.isAndroid` first |
| `android/gradle.properties` | Flutter migrator shims, committed deliberately |
| `.forge/plans/check_plans.py` | `ROOT`/`FORGE` resolved from `__file__` and `$FORGE` |
| `.forge/test-plan.md` | §3 counts 32 → 38 (32 host + 6 device); §4 amended with §4.1–4.3 |
| `DECISIONS.md` | Q-003 **closed**; Q-008 premise answered, entry retracted in place |
| `AGENTS.md` | `flutter build apk` no longer "unvalidated"; added the `flutter test -d` trap |

### STATUS

`flutter analyze` **zero issues** · `dart format` clean · host suite **32/32** ·
**on-device 6/6 on a nubia Z2577, Android 16 / API 36, arm64-v8a** · `forge-guard all`
**16/17**, the one failure pre-existing and logged as F-005 · Q-003 closed · Q-008 open
on implementation, not on hardware · Phase 6 still `in_progress`, `test_plan` still
`draft` — **unchanged by this session, deliberately: a device does not advance a phase.**

### NEXT SESSION SHOULD

- **Promote F-005** (`--resolve F-005 --promoted-to=testing.md`) once the guard is fixed.
- **Answer the deprecation warnings Flutter printed**: Gradle 8.14 → ≥ 9.1, AGP 8.11.1 →
  ≥ 9.0.1, Kotlin 2.2.20 → ≥ 2.3.20. Deferred with a reason (a stack change needs an
  ADR), not ignored. They will become hard failures.
- **Put the first real UI on the device.** It runs; it renders nothing. That is now the
  cheapest possible moment to find out whether the theme and typography survive ARM64.
- **Use `integration_test/` for every future device claim**, and keep a
  `Platform.isAndroid`-style assertion first in each file. The infra is now proven and
  was sitting unused for two sessions.

### NEXT SESSION SHOULD NOT

- **Do not trust `-d` on `flutter test`.** A fabricated device id produces
  `All tests passed!`. This is the eighth time this project has recorded a check
  reporting something it did not measure, and the first time it produced a **green
  result I was about to write down as a device measurement**. See `test-plan.md` § 4.2.
- **Do not read "the APK builds" as "the app works".** It launched to a black screen
  because `MaterialApp` has no `home`. A packaged `.so` is not a loaded `.so`.
- **Do not let the device close a question whose exit criteria are behavioural.**
  Q-008 asked whether a *chapter can be read offline*. No slice exists to read one.
- **Do not bump the Gradle wrapper to dodge a local JDK problem.** The JDK went
  sideways; the wrapper is a project-wide decision.
- **Do not assume a green script measured something.** `--test-plan` printed
  `no failures` over zero plans, and `version_pins_agree` is red for a reason that has
  nothing to do with dependencies.

---

## 2026-10-03 — Session 8: closing Phase 6, and the numbers I typed instead of deriving

### STARTED FROM

Phase 6 `in_progress` with `test_plan` the only `draft` deliverable, and Session 7's
device work committed. The owner asked for Phase 6 to be done autonomously. **Phase 6's
gate is six checklist items**, and measuring the register against them found **four of six
missing** — so "autonomously" meant writing most of the deliverable, not approving it.

### DECIDED

- **Constraints are an id type and the register never counted them.** `C1`–`C14` exist,
  13 of them are cited in plans' § 11, and § 2 reported only B and E. Adding the row
  found a **second** hole: **C13** (*no login, no profiles, no sync*) appears in § 11
  prose but in no test row. Truth is **12 of 14**, not 13.
- **The three uncovered ids are two absences and one oversight, and only one is
  excusable.** E21 and C10 are both the Novel Fire question (Q-004) — blocked on the
  owner. **C13 is blocked on nobody having written the test**, it is owed to
  `local-store` and `http-client`, and it is the most testable of the three. Recorded as
  owed rather than written, because a register specifies tests and does not implement them.
- **ADR-011 decided a GitHub Actions workflow on 2026-10-02 and no workflow file
  existed.** An approved decision with nothing built on it. There is now
  `.github/workflows/ci.yml` implementing five gates, triggered on `master` because that
  is the default branch — a workflow naming a nonexistent branch never runs and reports
  success.
- **CI asserts more than "the build exited 0".** It greps the finished APK for
  `lib/arm64-v8a/libsqlite3.so`, because a packaged library that fails to `dlopen` still
  produces a green build. Verified both directions against a real APK.
- **Gates 7 and 8 are deliberately not CI jobs.** One needs hardware nobody has, the
  other needs 0-of-32 slices. A workflow that blocks every merge is not a safety net.
- **The Chrome MCP gate item does not apply and saying so is the correct answer.**
  `C3` is explicit: no web, no desktop, no tablet. A 19-row Chrome checklist would be 19
  rows of *cannot run* — coverage that measures nothing. Answered with the Android
  equivalents (`integration_test` + `tester`, `adb exec-out screencap`) and 19 screens
  ordered by which becomes runnable first.
- **The one genuinely broken section pointer in the corpus is fixed.** `0-2.md` cited
  `architecture.md § 6.11`, which does not exist — it was a *line number* in § 3.1's
  table, and § 6 ends at 6.6. The plan already documented the mistake in a warning; the
  checker was reading the citation inside that warning. **broken: 3 → 0.**

### REJECTED

- **Hand-writing the pyramid counts.** I did exactly that on the first pass — 1170 /
  338 / 173 — and they were **wrong**; the real figures are 880 / 334 / 169. They came
  from nowhere, which is the defect this register spends § 6 warning about. Replaced with
  derived values, and `check_plans.py` now verifies § 7 and § 8 so the numbers cannot
  drift again. **The mistake was caught only because the checker was written afterwards
  to recompute them — a check written before the claim, not after.**
- **Rewording three documents to silence `section_references`.** The 3 remaining
  "unknown file" reports point at files that **exist** — two in `.opencode/rules/`, one
  a slice plan — and the checker indexes neither directory. Editing correct prose to
  satisfy a parser is changing the input to get green. Logged as **F-006** instead.
- **Adding `forge-guard` to CI.** `forge-guard.js` lives in the Forge skill directory,
  which is not vendored here, so the job would fail on a missing path rather than on a
  defect — a red X meaning nothing. Documented as gate 5, run locally.
- **Floating the Flutter version in CI.** Pinned to 3.47.6 so a toolchain change arrives
  as a visible diff rather than an unexplained red build.

### BLOCKED

- **Gate 7 (on-device) could not be re-run at the end of the pass.** The Z2577 dropped
  off USB mid-session and `adb kill-server && adb start-server` did not recover it. **Not
  reported as passing on that basis**: the 6/6 stands from the run earlier in the day,
  and after the owner reconnected the phone it was **re-run and reproduced 6/6**, with
  `persist.log.tag` still `I` across the reconnect. Recorded because a check that could
  not run must announce what it did not cover.
- **`version_pins_agree`** still fails — **F-005**, pre-existing, a checker bug.
- **`section_references`** still fails on 3 unknown targets — **F-006**, a checker scope
  gap. `broken` is 0.
- **6 findings are open and unpromoted** (F-001…F-006). Promotion means editing rule files,
  which belongs to `project-rules-architect`; Forge routes findings and does not write
  rules. Not this session's to close.

### FILES TOUCHED

| File | Change |
|---|---|
| `.github/workflows/ci.yml` | **new** — ADR-011's workflow: gates 1, 2, 3, 4, 6 + native-lib assertion |
| `.forge/test-plan.md` | §2 constraints row; §6 rewritten; **§7–§11 added** (pyramid, foundations, regression, screens, environments) |
| `.forge/plans/check_plans.py` | verifies §2's constraints row, §7's tiers, §8's per-foundation counts; C10/C13 guards; E21 guard de-brittled |
| `.forge/plans/0-2.md` | the broken `§ 6.11` pointer, without degrading the note that explains it |

### STATUS

`dart format` clean · `flutter analyze --fatal-infos` **zero issues** · host **32/32** ·
**on-device 6/6, re-verified after reconnect** · `check_plans.py` **38 clean, 0 failures** ·
`forge-guard` **16/17** (F-005) · `section_references` **broken 0**, 3 unknown (F-006) ·
`test_plan` still **`draft`** — Phase 6's gate is human and has not been passed.

### NEXT SESSION SHOULD

- **Pass or fail the Phase 6 gate.** `test_plan` is written and verified; it is waiting
  on an explicit approval, not on more work.
- **Write C13's test row** in `local-store` and `http-client`: no user/profile/session
  table in the schema, no auth or sync dependency in `pubspec.yaml`, no provider reaching
  the network for identity. It is owed and it is not blocked on anything.
- **Promote F-001…F-006** via `project-rules-architect`. Six findings with domains and no
  promotion have changed nothing, which is the condition the rule names.
- **Run CI once.** The workflow has never executed on GitHub. It passes locally gate by
  gate, which is not the same as having run there.

### NEXT SESSION SHOULD NOT

- **Do not type a number into `test-plan.md`.** I did, on the first pass, and all three
  were wrong. The register's premise is that its counts are derived; § 7 and § 8 now have
  a checker because of it.
- **Do not call a plan's § 11 passing proof that a foundation works.**
  `coverage-check.js` verifies structure — headings, ids, non-empty sections — and never
  behaviour. **2 of 14 declared foundation test locations exist.**
- **Do not edit a document to quiet a checker.** The three remaining `unknown file`
  reports point at files that exist; the checker simply does not index
  `.opencode/rules/` or `.forge/plans/`.
- **Do not add a CI job that needs hardware this project does not have**, and do not let
  the E2E rows into CI while 0 of 32 slices exist.

### Phase 6 gate — passed, and Phase 7 opened on two blockers

The owner approved `test_plan` and closed Phase 6. `test_plan` draft → **approved**,
phase 6 → **approved**, `current_phase` → **7_implementation**, `gates_pending` **0**,
`open_divergences` **0**, front matter mirror synced by `set-status` rather than by hand.

**Phase 7 opens on Wave 0** — `0-1`, `apk-pipeline`, `http-client`, `local-store`,
`localisation`, `theme-type`. Six nodes, no dependencies between them, and the wave count
is computed by `dependency-check` rather than asserted.

**Two blockers found in the first minute of Phase 7, both recorded rather than worked around:**

- **`0-1` is `stale`** — `check-stale` returns `{"stale": true, "reasons": ["plan_edited"]}`.
  Its plan changed after approval, so by Phase 7 step 1 it is blocked pending a re-approval
  gate. It is the only node of the six whose staleness could even be evaluated.
- **`check-stale` cannot check a foundation at all.** All six return
  `{"error": "unknown_slice"}` — it resolves only `state['slices']`, never
  `state['foundations']`. **This is F-003's root cause in a second script** (F-003 named
  `coverage-check.js` only), and it means the mandatory Phase 7 gate is **unrunnable for
  5 of the 6 Wave-0 nodes** — every foundation in the project. Recorded as **F-007**.

The second one matters more than it looks: SKILL.md Phase 7 step 1 makes `check-stale` the
gate before implementing a node, and a gate that errors for most of the graph is a gate
nobody can run. Either the lookup is fixed, or the five foundations get implemented with
no staleness check at all — and *that* is the failure this project has already written down
several times.

### NEXT SESSION SHOULD

- **Decide F-007 before implementing any foundation.** One-line fix in `check-stale`
  (fall back to `state['foundations']`), or amend SKILL.md Phase 7 step 1 to name a command
  that works. Implementing five nodes with the documented gate silently erroring is worse
  than not starting.
- **Re-gate `0-1`**, whose plan was edited after approval.
- **Promote F-001…F-007.** Seven findings with domains and no promotion have changed
  nothing, which is the exact condition the rule names.

### NEXT SESSION SHOULD NOT

- **Do not read `unknown_slice` as "nothing to check".** It means the checker did not look,
  which is the same shape as `flutter test -d` reporting green on a laptop.

### F-007 fixed — and fixing it exposed three worse defects underneath

The owner said *fix and go autonomous*. The fix was one line: `cmdCheckStale` resolved
only `state['slices']`, never `state['foundations']` — the same lookup `cmdDep` already
did correctly. Mirrored it. **`check-stale` now resolves all 38 nodes: 38 ok, 0 stale,
0 errors.** F-007 closed.

**The interesting part is what the fix uncovered.** All five foundations immediately
reported `plan_edited` — and then `0-1`, which had reported stale, reported `ok`. That
should not have happened with nothing changed on disk. It is F-008:

> **`check-stale` overwrites `plan_hash` with the current file hash and saves it.** It can
> report `plan_edited` **exactly once per plan**. Run 1 says stale, run 2 says clean.
> `state.json` grew 26 lines across two runs. A gate that can only fail once is not a gate.

Then F-009, which is the real one. I checked whether the drift was genuine before
touching anything, by hashing every historical version of `local-store.md` with Forge's
own `contentHash`:

```
b51fdad  sha256:b7187e2432d5   (phase 5 approved, all 38 plans)
4e46fe6  sha256:b7187e2432d5
7e2d162  sha256:b7187e2432d5
recorded in state.json: sha256:367fc29dc1be   ← matches NO committed version
```

**37 of 38 plans are byte-identical to the Phase-5 approval commit `b51fdad`.** The only
one that differs is `0-2`, which *I* edited this session to fix a broken pointer, and which
is committed with that change documented. So the plans are trustworthy and the bookkeeping
was fiction — and the scope is far wider than the five foundations:

| | |
|---|---:|
| nodes whose `content_hash` is not the hash of their `path` | **37 / 38** |
| nodes whose `plan_hash` is not the hash of their `plan_path` | **31 / 38** |

**The 7 nodes whose `plan_hash` looked correct were exactly the ones `check-stale` had just
rewritten** — F-008's self-heal presenting as a repair. `forge-guard`'s
`content_hashes_current` checks 69 artefacts and **none of the 38 nodes**, which is why 37
wrong hashes went unnoticed. Repaired by re-registering all 38 at their plan paths:
**38/38 internally consistent**, verified.

### What the repair cost, honestly

`section_references` went from **broken 0 → 2**. Correcting `path` made the resolver
re-attribute two references it had previously mis-filed, and both are real:

- `theme-type.md:1195` cites `design-system.md § 0.1`; there is no `0.1`. The halation
  argument lives under `### The contestable choices`.
- `theme-type.md:1224` cites `design-system.md § 0.3` for the rule that `ColorScheme.fromSeed`
  supplies the Material 3 roles. **`design-system.md` contains zero occurrences of
  `ColorScheme` and zero of `fromSeed`.** That is not a dangling pointer — it is a plan
  asserting a design-system rule that was never written.

**Not guessed at, and not renumbered.** Pointing `0.3` at a nearby section would produce a
reference that resolves and is wrong, which the rules call worse than one that resolves to
nothing. Logged as **F-011** against `14-design-tokens.md`, and **`theme-type` must not be
implemented from a plan whose stated design premise is absent.**

### NEXT SESSION SHOULD

- **Decide F-011 before implementing `theme-type`.** Add `0.1` and `0.3` to
  `design-system.md`, or correct the two citations to headings that exist.
- **Extend `forge-guard content_hashes_current` to slices and foundations.** Until it does,
  its `pass` says nothing about the graph, and 37 wrong hashes are exactly what it missed.
- **Fix F-008 in `state.js`** — `check-stale` must compare read-only and leave the hash to
  an explicit `register`, or record the drift in a separate field so it survives. Add a
  selftest that runs it twice on a mutated plan and asserts the second run still fails.
- **Promote F-001…F-011.** Eleven findings with domains and no promotion.

### NEXT SESSION SHOULD NOT

- **Do not trust a green from `check-stale` that you have already run once.** It is
  self-healing; the evidence is destroyed by the act of checking.
- **Do not treat `unknown_slice` as "nothing to check".** It meant "not looked at" — and
  fixing it immediately revealed that the hashes it would have read were wrong for 31 nodes.
- **Do not assume a repair is free.** Correcting 38 `path` values surfaced two real broken
  references that the broken state had been hiding.

### Phase 7 — `http-client` implemented (wave 0, critical path)

The owner said *fix and go autonomous, and don't leave any holes*. So: implemented the
foundation the whole source pipeline waits on, and finished the F-011 hole rather than
deferring it.

**Built, on the plan's § 2.2 contracts (10 files):** `lib/core/network/` —
`fetch_result.dart`, `http_response.dart`, `http_client.dart`, `http_policy.dart`,
`source_endpoint.dart`, `retry_after.dart`, `body_decoder.dart`,
`host_rate_limiter.dart`, `source_http_client.dart`; and `lib/core/error/app_exception.dart`.
**Tests: 51 rows** across the two files § 11 declares, so `http-client` is now the
second foundation with its tests on disk (3 of 14 locations, up from 2).

**Four things the plan did not know, found by reading the installed source:**

1. **`BaseOptions` has no `userAgent` field in dio 5.11.1** — the agent goes in `headers`.
2. **⚠️ A request-level `headers` map REPLACES the base headers, it does not merge**
   (`options.dart`: `headers: headers ?? effectiveHeaders`). Passing only
   `Accept-Encoding` per request would have **silently dropped the User-Agent** — a 403 on
   exactly the sites ADR-014 measured. The base headers are now merged forward explicitly
   and `the User-Agent reaches the base headers, not an option` fails if that changes.
3. **`HttpDate.parse` throws `HttpException`, not `FormatException`.** My first draft
   caught `FormatException`, so the catch never fired and an unreadable `Retry-After`
   propagated an `HttpException` out of the transport. § 3.4's branch 3 was unreachable.
   **The test found it, which is the whole argument for writing the row.**
4. **The plan's own `Retry-After` test row is wrong.** It asks for
   `07:28:00 GMT → ±1s`, but § 2.4 sets `maxRetryAfter = 10 minutes`; measured from 07:00
   the 28-minute delta clamps to 600 and the row fails **while the code is right**. Fixed
   the reference point to 07:26 and added a separate row proving the clamp — a date-format
   test that only passes because the value is out of range is not testing the format.

**Also two of my own mistakes, caught and corrected:** `_declarationsOfSealedFetchResult()`
returned a hardcoded `1` (a test that passes for the wrong reason — it now walks `lib/`),
and the meta-charset test built its bytes with `replaceAll('é','é')`, a no-op on a
UTF-8 literal that looked like it did something.

**Every new check proven RED before trusted**, by breaking the thing it watches:
- adding `print("telemetry")` to `core/network` → `logs nothing` **fails**
- swapping `on HttpException` back to `on ArgumentError` → `unparseable Retry-After`
  **fails**

**F-011 closed, not deferred.** `theme-type` cited `design-system.md § 0.3` for a rule
about `ColorScheme.fromSeed`, in a file containing **zero** occurrences of
`ColorScheme`. Rather than repoint the citation at a nearby section, § 0.1 and § 0.3 were
**added to `design-system.md` as numbered sections**, so the citations now resolve to the
rules they always meant to name.

### Verified

format clean · `analyze --fatal-infos` **zero** · host **83/83** (was 32) ·
`check_plans` **38 clean, 0 failures**. Register § 3 recomputed: **89** written,
**83 host + 6 on-device**, **2 of 55** declared locations exist.

### NEXT SESSION SHOULD

- **`localisation` (29 rows, 3 files) then `theme-type` (39 rows, 6 files)**, then `0-1`
  (21) and `apk-pipeline` (33, largely discharged by the CI workflow). That clears Wave 0.
- **Re-run the on-device suite when the Z2577 is connected.** It was disconnected at the
  end of this pass and the run is reported as **not re-verified**, not as passing.
- **`failure-discriminator`** is wave 2 and `http-client` now gives it the `FetchResult`
  it was told to import rather than declare.

### NEXT SESSION SHOULD NOT

- **Do not pass request-level `headers` to dio without merging the base ones.** It
  replaces them, and the User-Agent goes with them.
- **Do not assume a plan's test row is self-consistent.** Row 4 above is a plan whose
  expectation contradicts its own constant, and the code was right.
