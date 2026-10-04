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

### Phase 7 — `localisation` implemented, and one row deliberately not written

**Built:** `lib/l10n/arb_key_derivation.dart` — the screen/dotted → flat camelCase rule
as code, because a rule that lives only in prose cannot be tested. **27 rows** across the
three files § 11 declares, so `localisation` is the third foundation with its tests on
disk and **7 of 14** declared locations exist overall. Host suite **110/110**.

**Four things worth writing down:**

1. **The derivation's first version produced `sourceUnavailablecausenoConnectionkicker`.**
   camelCasing each segment and joining them does not mark the boundary BETWEEN two
   segments, so the whole thing came out as one word. The fix upper-cases the head of
   every segment after the first. A test row caught it; nothing else would have.
2. **The plan's row « a key present on two screens is one key » is ambiguous as written.**
   It says `settings.md` and `settings-reader.md` both write `error.write` → one
   `settingsErrorWrite`, but read literally the two slugs differ, so the rows contradict.
   **The resolution is that `settings-reader` is a FILE name, not a slug** — both screens
   live under `settings`. Implemented that way, and added the converse row (a genuinely
   different slug yields a genuinely different key) so the row above cannot be satisfied
   by a function ignoring the slug.
3. **The `@key` metadata row had to be narrowed to be true.** 14 of 16 ARB keys have no
   metadata block, and that is correct: gen-l10n only needs `@key` to *infer* placeholders
   and plurals, and a plain literal has none. The row now asserts that every key
   **carrying a placeholder** declares itself — and additionally asserts the two that do
   need it have it, so the check cannot pass by finding nothing.
4. **The 41-key error family row is absent, on purpose.** `localisation` § 11 asks that
   « the error message family resolves in both languages » across **41** `source-unavailable`
   keys. **Those strings do not exist** — no slice has authored them. A loop over the
   three keys that do exist would be a green row covering 3 of 41. The row is left
   unwritten, `localized_strings_test.dart` says so in its own header, and the register
   records the absence. **A specification row is not a green tick.**

**Also added, so `fr` cannot silently resolve to English:** a row asserting every shared
key returns *different* text in the two locales. Each locale's own assertions pass
happily if one of them falls through to the other; only the comparison catches it (E12).

**Proven RED before trusted:** deleting `navBrowse` from `app_fr.arb` → the
completeness row **fails** naming the key, restored → green.

### Verified

format clean · `analyze --fatal-infos` **zero** · host **110/110** · `check_plans`
**38 clean, 0 failures**. Register § 3 recomputed to **116 written** (110 host + 6
on-device), **3 of 55** declared locations, **7 of 14** foundation locations.

### Still open, and not hidden

- **The on-device suite was NOT re-run** — the Z2577 is disconnected. The 6/6 from
  earlier today stands; today's run is reported as *not executed*, not as passing.
- **Wave 0 is not complete.** `theme-type` (39 rows, 6 files) and `0-1` (21 rows) remain,
  and `apk-pipeline` is largely discharged by the CI workflow but declares one test file.
- **`theme-type`'s design premise now exists** — § 0.1 and § 0.3 were added to
  `design-system.md`, so F-011's citations resolve. `broken: 3 → 0`.

### NEXT SESSION SHOULD

- **`theme-type` next**, then `0-1`. That clears Wave 0 and opens `2-1`, which is the
  gate on the whole source pipeline.
- **Author the 41 `source-unavailable` strings** when the slice that owns them lands, then
  add the row that is currently absent.
- **Re-run the on-device suite** when the phone is back.

### NEXT SESSION SHOULD NOT

- **Do not camelCase segments and join them.** The boundary between two segments needs an
  upper-cased head, or the key is one unpronounceable word.
- **Do not write a coverage row over 3 of the 41 keys it names.** The number in the plan
  is the specification; a green tick over a subset is a lie about it.

### Phase 7 — `theme-type` implemented, and the test found a real theme bug

**Built** (8 files under `lib/app/theme/`): `lumen_colors.dart`, `lumen_spacing.dart`,
`lumen_radius.dart`, `shadows.dart`, `motion.dart`, `reader_scale.dart`,
`theme_override.dart`, `app_theme_preferences.dart`, `app_theme.dart`. **55 rows** in
`lumen_colors_test.dart`, `reader_scale_test.dart`, `theme_override_test.dart` and
`theme_providers_test.dart`. Host suite **165/165**. **Five of six Wave-0 nodes now have
tests on disk** (8 of 14 foundation locations).

**⚠️ A REAL BUG, found by the E13 row, not by reading the code:**

`ColorScheme.fromSeed` derives `brightness` from the **seed's** luminance, and the seed is
the day amber in *both* themes. So `AppTheme.night()` was returning a scheme reporting
`Brightness.light` while every one of its sixteen tokens said night. The colours were
right, nothing threw, and **every consumer of `Theme.of(context).brightness` was wrong.**

This is the second instance in two sessions of a *default that silently disagrees with the
thing it configures* — the first was dio replacing base headers and eating the
User-Agent. Both were found by a test that asked a behavioural question, and neither was
visible from `analyze`, from a build, or from reading the file. Fixed by passing
`brightness:` explicitly, and the row now asserts the scheme directly so it stays fixed.

**The E13 row took four attempts, and every failure is recorded in the file:**

1. asserting `colorScheme.primary` — wrong, that is a seed role, not the accent.
2. driving it through `themeMode` + `platformBrightnessTestValue` — `MaterialApp` resolves
   `themeMode` against its own platform brightness, which the test binding reports as
   `light` and does not move on a `pumpWidget`.
3. swapping `theme` while **reusing the same `MaterialApp` element** — Flutter reuses the
   element and `MaterialApp` had already resolved brightness from the first theme.
4. finally: read the **accent token** (what this foundation owns) and give each theme its
   own subtree **key** so the swap is real.

**Three plan defects found and corrected in place, not worked around:**

- **`ReaderTextScale` cannot declare `index`** — every Dart enum already has one, so the
  plan's `int get index` does not compile. Renamed `stepIndex`.
- **§ 1.2 contradicts itself on line height.** The prose says **1.72** and the table
  tabulates five pairs that are **1.6875, 1.7222, 1.7000, 1.6957, 1.6923**. The table is
  what renders, so the table wins; the test asserts the **spread** (< 0.04) rather than a
  figure the design system itself refutes. A first draft asserted 1.72 and failed on three
  of five steps — "fixing" it would have meant editing the table to match the prose, which
  is rewriting the design system to fit a test.
- **A fourth plan file split.** § 4.1 lists `lumen_radius.dart`, `shadows.dart` and
  `motion.dart` as separate files; they are written as three.

**Two of my own test bugs, both the "passes for the wrong reason" kind:**

- The night-error assertion measured `day.error` on `night.background` and **never read
  `night.error`**, so making `LumenColors.night()` reuse the day error kept every row
  green. Both columns are now measured as columns — verified by sabotaging night and
  watching **two** rows fail.
- A first E13 draft asserted in-tree brightness against the binding's platform
  brightness. Fixed only after the probe showed `night().colorScheme.brightness` was
  genuinely wrong — the harness problem and the product bug were tangled together, and
  the probe is what separated them.

### Verified

format clean · `analyze --fatal-infos` **zero** · host **165/165** · `check_plans`
**38 clean**. Register § 3 recomputed: **171 written** (165 host + 6 on-device),
**4 of 55** locations.

### NEXT SESSION SHOULD

- **Finish `theme-type`'s remaining 5 test files** (`app_theme_preferences_test.dart`,
  `reader_scale_widget_test.dart`, `theme_override_test.dart` partially covered) — 55 of
  39 declared rows are written, so the surplus is in `lumen_colors_test.dart`; reconcile
  the count against the plan rather than leaving it over.
- **`0-1`** (21 rows), then **`apk-pipeline`**. That clears Wave 0 and opens `2-1`.
- **Re-run the on-device suite** when the Z2577 reconnects.

### NEXT SESSION SHOULD NOT

- **Do not trust a colour scheme's brightness.** Derive it from the seed and it becomes
  the seed's brightness — which is the *day* accent's, in both themes.
- **Do not assert a proportion `design-system.md` states in prose when its table says
  otherwise.** Measure the table, assert the spread, and say which one won.

### Phase 7 — `0-1` written, and the sites that were supposed to be captured are gone

Wrote `test/fixtures/fixture_manifest.dart` (§ 2.3's model, verbatim) and
`test/fixtures/fanmtl_manifest_test.dart`. Host suite **190 + 9 skipped**.

**⚠️ Wave 0 is blocked by the sites themselves, measured 2026-10-03** with the honest
`LumenTale/0.1.0 (personal reader)` UA:

| Site | Result |
|---|---|
| FanMTL `/`, `/robots.txt`, catalogue path, `/browsetags/`, `/browsetags/all.html` | **403**, Cloudflare interstitial |
| Royal Road `/` → `/home` | **200**, 118 173 bytes, real markup |
| Royal Road `/fiction/1`, `/fictions/ratings`, `/fiction/best-rated`, `/fiction/updates`, `/fiction/ratings` | **404**, zero novel rows |

**ADR-014 recorded both sites at 200 on 2026-10-02.** The sites moved; the client did
not. `0-1` exists to capture fixtures *before* any feature code, so this blocks Wave 0 at
its first slice. Logged as **F-012** and **F-013**, and measured into
`18-external-contracts.md` § Re-measurement 2026-10-03.

**No bypass, and no fabricated fixture.** ADR-014 already rejected Mihon's WebView
technique on measurement, and C2's no-telemetry constraint plus rule 7 put a
challenge-solving WebView out of scope independently — a Cloudflare interstitial is the
site declining, and the correct response is to record it. Fabricating HTML and calling it
a capture is precisely what `kind: manufactured` exists to distinguish; a green `0-1`
built on manufactured fixtures would hand `2-1` a selector contract validated against
nothing, which is the failure Wave 0 was created to prevent. **So the nine capture rows
SKIP, loudly, naming F-012** — and the manifest API rows run against an in-memory
manifest so they still prove something.

**The closed-list rule was a comment until a test caught it.** § 2.2 declares `kind` a
closed list of eight because "a free string becomes a taxonomy nobody maintains". My
first `fromJson` accepted any string: the constant existed, was complete, and was never
checked. **A declared invariant that nothing enforces is documentation.** `fromJson` now
refuses a `kind` outside the list.

**Two of my own mistakes, both caught immediately:**
- Asserted `entry.capturedBy`, which does not exist — § 2.2 puts `capturedBy` on the
  **manifest**, not on each entry. Now read once off the manifest.
- The manifest's eleven mandatory fields are asserted **field by field**: removing any one
  must fail. A test that only checks the list has the right length would not notice a
  field that stopped being required.

**Also found: `state.js finding` reuses finding IDs.** It numbers `F-<length + 1>` with
no tombstone, so a finding raised after one was *resolved* can collide with the resolved
ID. The FanMTL finding was issued as `F-011` — already used in this log for theme-type's
broken `design-system.md` citation, fixed in `a3665d8`. Renamed by hand to `F-012`, then
`F-013`, and both `script_failure` events are in the run log. **There is no verb to fix
it**, which is the same gap as F-001.

### Verified

format clean · `analyze --fatal-infos` **zero** · host **190 passed, 9 skipped** ·
`check_plans` **38 clean**. Register § 3 recomputed: **196 written** (190 host + 6
on-device), **6 of 55** locations, and the skipped count is now a **row in the register**
rather than an absence nobody can see.

### NEXT SESSION SHOULD

- **Decide how fixtures get captured** — F-012/F-013. Capturing from the owner's phone,
  which already carries whatever cookie the challenge needs, is the cheapest honest
  option and needs no rule change. Royal Road's catalogue URLs need finding regardless.
- **Re-measure ADR-014's table.** Both rows are now wrong, and `2-1`'s selectors are
  being written against them.
- **`apk-pipeline`** is the last Wave-0 node; its test file is declared and unwritten.
- **Promote F-001…F-013** (12 open). And note `state.js finding` needs a tombstone.

### NEXT SESSION SHOULD NOT

- **Do not fabricate a fixture to make `0-1` green.** The skip is the honest state, and
  `kind: manufactured` exists so the two can never be confused.
- **Do not declare an invariant in a constant and assume it is enforced.** `FixtureEntry.kinds`
  was complete, correct, and checked by nothing.
- **Do not treat a 403 or 404 as a bug in the client** before re-reading the ADR that
  measured the site. Both sites answered 200 the day before.

### Phase 7 — `apk-pipeline`, and Wave 0 is complete

**Built:** `lib/app/build_info.dart` (`AppBuildInfo`, `BuildInfoReader`,
`isDistinguishable`) plus 13 rows in `test/app/build_info_test.dart`. **All six Wave-0
nodes now have at least one test file on disk** (13 of 14 declared locations).

**⚠️ The plan's own guard was the wrong one, and the absence test caught it.**
§ 2.3 writes `displayLine => isUnknown ? '—' : '$buildName ($buildNumber)'`, and
`isUnknown` is true only when **both** values are absent. So `buildNumber: null` with a
readable `buildName` rendered **`1.0.0 (null)`** — a fabricated literal, in the exact
place B43 forbids one. The plan spells out only the `buildNumber`-absent case and leaves
the mirror case to be inferred, so I implemented the plan and the row for the *other*
half caught it. The guard is now `buildName == null || buildNumber == null`.

**Proven RED:** restoring the `isUnknown` guard makes **two** rows fail with the literal
`1.0.0 (null)` and `null (42)`.

**The forbidden-value row is a SCAN, not four assertions.** Nine combinations of
present/absent name and number are generated and each is checked for `0.0.0`,
`unknown`, `null`, `undefined`, `NaN` and emptiness. Four equality assertions would
only have covered the four states someone thought of.

**No `BuildInfoReader` implementation exists, deliberately.** B43 needs the version at
runtime and the OS is the only correct source, which means `package_info_plus` — **not**
in `pubspec.yaml`. `apk-pipeline` § 7 records that as an open dependency question under
`17-security.md` rule 13, so `3-5` owns the implementation. Reading `pubspec.yaml` at
runtime was rejected and the reason is in the source: it reads the *source* of the
compilation, and the two diverge from the first `--build-name` override — that is, from
the first CI build.

### Verified

format clean · `analyze --fatal-infos` **zero** · host **203 passed + 9 skipped** ·
`check_plans` **38 clean**. Register § 3: **209 written** (203 host + 6 on-device),
**7 of 55** locations, **13 of 14** foundation locations.

### The one place I stopped short of finishing, and why

**Wave 0 is done in the sense that every node has code and tests; Wave 0 is NOT
verified, because `0-1`'s nine capture rows skip.** The sites answer 403 and 404
(F-012, F-013). `roadmap.md` put fixture capture in Wave 0 *before any feature code* so
the HTML surprises would land early — and the surprise has landed, just not the way the
plan expected: **the sites moved between the ADR that measured them and the slice that
depends on them.**

I did not fabricate a fixture, and I did not start Wave 1, because Wave 1's `0-2`
through `0-4` are *fixture-driven* and `2-1` builds the Source contract against selectors
that `18-external-contracts.md` documents for URLs now measured dead. Building the
contract against unverified selectors would freeze the wrong thing.

### NEXT SESSION SHOULD

- **Decide F-012/F-013** — how fixtures get captured. The owner's phone carries whatever
  cookie the challenge needs, and that is ADR-014's own method. Royal Road's current
  catalogue URLs need finding either way.
- **Re-measure ADR-014's table.** Both rows are false as of 2026-10-03.
- **Then Wave 1**, in dependency order: `failure-discriminator` (which `http-client` now
  hands the `FetchResult` it was told to import), then the `0-*` fixture slices.
- **Promote F-001…F-013** (12 open), and give `state.js finding` a tombstone so an ID is
  never reused after a resolve.

### NEXT SESSION SHOULD NOT

- **Do not guard a two-value invariant with a both-absent check.** `isUnknown` was the
  plan's own suggestion and it let `1.0.0 (null)` through.
- **Do not implement `BuildInfoReader` from `pubspec.yaml`.** That is a new dependency
  question (`17-security.md` rule 13) *and* the wrong source.
- **Do not start Wave 1 against selectors for URLs measured dead today.**

### Phase 7 — `0-1` DISCHARGED on Royal Road, and the capture corrected three beliefs

I had stopped and called the fixture decision the owner's. It was mine. FanMTL is
Cloudflare-blocked, but **the second v1 site was reachable** — I had measured its `/` as
200 and then not followed the lead. Following it found that **its URLs had moved**, which
is why ADR-014's paths 404'd.

**Captured:** 9 fixtures, 2 045 855 bytes, into `test/fixtures/sources/royalroad/` with
a full manifest. `0-1` is **no longer skipped** — 19 rows green against real captures.

**Live URLs, all fetched, all superseding § FanMTL-era claims above:**

| What | URL |
|---|---|
| Entry | `/` **302** → `/home` |
| Catalogue | `/fictions/active-popular`, page N via **`?page=N`** (a query) |
| Detail | `/fiction/<id>/<slug>` |
| Chapter | `/fiction/<id>/<slug>/chapter/<n>/<chapter-slug>` — **five segments** |

**Three beliefs the capture corrected — none guessed, all measured:**

1. **The three-segment chapter URL 404s.** `/fiction/33844/the-runesmith/chapter/526587`
   returns `Not Found | Royal Road`. The fifth segment is the chapter's own slug. **A
   chapter URL that 404s is indistinguishable from a chapter that does not exist** — that
   is B22's third state, so the segment is part of the contract.
2. **The body container is `chapter-inner chapter-content`.** An exact
   `class="chapter-content"` match finds **nothing**: zero paragraphs on a page with 106.
   **A zero-parse looks exactly like an empty chapter**, which is B22's failure mode, so
   this one would have shipped as a source that "works".
3. **B22's third state has NO marker on this site.** A zero-row catalogue (HTTP 200,
   239 765 bytes) carries no "nothing here" / "no results" / "no fictions".
   `18-external-contracts.md` recorded that it *does* volunteer one. **It does not.**
   `2-1` must distinguish by **page shape** — a marker-based implementation would call
   every unparseable catalogue "no results".

**And one plan instruction that could not be followed.** § 3.2 says build the
manufactured fixture from the **detail** page. That page has **zero** occurrences of
`chapter-content` in 1 000 263 bytes — the prose lives on the chapter page. Renaming
there would have substituted nothing and produced a fixture named "broken" that was not
broken. Built from a chapter page instead, with a row asserting the detail page really
has no container so the choice cannot rot silently.

**Three bugs of mine, all caught by the rows meant to catch them:**

- **The round-trip was the wrong instrument.** `broken.replaceAll('chapter-content',
  'chapter-content')` is a no-op; run backwards it yields `chapter-content-v2-v2`. A
  negative lookahead still failed, because after matching the bare name the scan resumes
  past it and the trailing `-v2` survives. **Fixing a round-trip means reasoning about
  regex resumption.** Replaced with what § 3.2 actually asks: the two files differ in
  exactly ONE line, and that line is the rename.
- **`listSync()` without `recursive: true`** reported the manufactured fixture as "on disk
  but undeclared" — the exact failure B9 warns about, caused by the check itself.
- **`manifest.json` excluded from one direction only**, so it looked undeclared. It is
  the thing doing the declaring.

**Proven RED:** adding a second illegitimate edit (commenting out the ad `<script>`) makes
the row fail **and name both differing lines** — 55 and 431 — which is the diagnostic
§ 3.2 wants.

**`robots.txt` honoured, not just captured.** A row parses the `User-agent: *` block and
asserts that **no captured path is disallowed by it**, and that we are not among the
fourteen agents banned wholesale. C1 is a permission question, so "we read robots.txt" is
not evidence — "no captured URL falls under a rule" is.

### Verified

format clean · `analyze --fatal-infos` **zero** · host **222 passed + 9 skipped** ·
`check_plans` **38 clean**. Register § 3: **228 written**, **7 of 55** locations, and the
skipped nine are now attributed to FanMTL specifically rather than to "no capture yet".

### NEXT SESSION SHOULD

- **Write `2-1` (the Source contract) against the corrected facts** — five-segment chapter
  URLs, `chapter-inner chapter-content`, and page-shape discrimination. All three came
  from a real capture; two contradict documents written earlier today.
- **FanMTL remains unmeasured for our purposes** (F-012). Royal Road carries v1 on its
  own; FanMTL's scraper waits on a capture that Cloudflare currently prevents.
- **Promote F-001…F-014** (13 open) and give `state.js finding` a tombstone.
- **`theme-type`'s sixth test file**, `reader_scale_widget_test.dart`'s plan-name sibling,
  and `apk-pipeline`'s remaining integration rows.

### NEXT SESSION SHOULD NOT

- **Do not use a round-trip to prove a single substitution.** Two attempts failed and the
  third instrument — diff the lines — is the one the spec describes.
- **Do not write a selector from the documentation.** Three of the documented shapes are
  wrong on the live site, and two of them fail *silently* as "no results".
- **Do not treat a zero-parse as an empty chapter.** That conflation is B22's third state
  and it is the most expensive bug available here.

### Phase 7 — the FanMTL gap is now one command, not a project

The owner solved the Cloudflare challenge in their browser. I re-measured first:
**every** FanMTL path still answers 403 from this machine — `/robots.txt`,
`/favicon.ico`, with no UA and with a browser UA. It is a blanket challenge keyed to
their session, and **I did not replay their `cf_clearance` cookie**, because that is the
bypass ADR-014 rejected on measurement and C1 forbids: it would mean shipping a session
token to defeat a site's bot protection. The honest path is that they save the page they
legitimately read.

**So I removed the remaining work rather than asking for it.** `tool/build_manifest.py`
turns files dropped into a fixture folder into a manifest. It **computes** `bytes` and
`sha256` from the files — § 3.2 makes `bytes` the one field an automatic guard asserts,
and a hand-typed hash is a promise about a file rather than a fact about one — and it
**refuses**:

| Refusal | Rule |
|---|---|
| `bytes`/`sha256` supplied | measured, never typed |
| absolute `url` | `03-source-system.md` rules 2-3 |
| `kind` outside the closed list | § 2.2 — a free string becomes a taxonomy nobody maintains |
| malformed `capturedAt` | provenance; omit it and it is stamped instead |
| empty `notes` | § 2.2 — records what was OBSERVED, not a workaround |
| session cookie / `cf_clearance` | C2, B4 — enforced at build time, not left to review |
| browser-save wrapper | the bytes would be Chrome's preamble, not the server's |
| `.mht`/`.mhtml` | a MIME envelope; unwrapping by hand is an unrecorded edit |
| declared file absent | a missing capture must not become a silent skip |

**All nine proven to fire** by `test/fixtures/manifest_builder_test.dart` (15 rows), which
stages a throwaway site per row. **Three were found NOT to fire and fixed:**

1. **`capturedAt` was checked only per entry**, so a malformed value at the **top level**
   of `manifest.in.json` was accepted while the same value on an entry was refused.
   Guarding with `is not None` made it worse — omitting the key skipped the check
   entirely.
2. **The wrapper check required `<!doctype html>` immediately followed by the comment.**
   Chrome emits the comment **first**, so a real browser save was accepted — the exact
   artefact the check exists to catch. A check that fires on one byte sequence is not a
   check.
3. Verified by sabotage: breaking the marker makes all three wrapper rows fail **and
   leaves the genuine-page row green**, which is what distinguishes a real check from one
   that refuses everything.

**`test/fixtures/sources/fanmtl/manifest.in.json` is staged and waiting** — seven entries
with the real URLs `18-external-contracts.md` documents, each `notes` field marked
`REPLACE:` with **what the human must observe** rather than what the machine can derive:
the selector including every class on the element, the count counted by hand, and whether
the site publishes its own completeness figure. The builder currently refuses with all
seven "declared but absent", which is the correct state.

**`.forge/design/capture-procedure.md`** documents the procedure and *why* it is not a
`curl`, including the three Royal Road findings that contradict documents written earlier
the same day — because the second capture is where the first one's lessons belong.

### Verified

format clean · `analyze --fatal-infos` **zero** · host **243 passed + 9 skipped** ·
`check_plans` **38 clean**. Register § 3: **249 written**, **243 host + 6 on-device**.

### NEXT SESSION SHOULD

- **`2-1`, the Source contract**, against the captured facts: five-segment chapter URLs,
  `chapter-inner chapter-content`, page-shape discrimination. All three came from real
  bytes and two contradict the prose.
- **FanMTL**: drop seven files in and run `python3 tool/build_manifest.py fanmtl`. One
  command, and the refusals protect the repository from a bad capture.
- **Promote F-001…F-014** (13 open) and give `state.js finding` a tombstone so an ID is
  never reused after a resolve.
- **`theme-type`'s sixth test file**, and `apk-pipeline`'s integration rows.

### NEXT SESSION SHOULD NOT

- **Do not replay a clearance cookie**, however available it is. It is the bypass ADR-014
  rejected, and the builder refuses a fixture containing one on purpose.
- **Do not save a page as "Complete" or "Single File".** The first lands an assets folder
  in git, the second makes `bytes` measure Chrome's inlining rather than the server's
  response, and the builder refuses both.
- **Do not trust a refusal that has never rejected anything.** Three of the nine above
  did not fire when first written, and a validator is only known once it has failed.

### `failure-discriminator` — B22 expressed in the type system

Wave 1's load-bearing foundation. Four pure-Dart files, no `package:flutter`, no
provider, no selector, no clock:

| File | What |
|---|---|
| `lib/core/error/source_failure.dart` | `SourceFailure` sealed + six causes |
| `lib/domain/sources/browse_outcome.dart` | `BrowseSucceeded` / `BrowseFailed` / `BrowseEmpty` |
| `lib/domain/sources/read_attempt.dart` | `ContentProbe`, `ReadStage`, `ZeroItemsPolicy`, `ReadAttempt` |
| `lib/domain/sources/outcome_discriminator.dart` | `classify` — nine branches, all of which return |

`classify` imports `fetch_result.dart` and does not touch it, which is the only way the
dependency runs the right way round: `http-client` is wave 0 and owns the type,
`failure-discriminator` is wave 2 and consumes it.

**Three defects found by writing the tests, all of them real:**

1. **The six causes had no value equality.** The first `expect(cause, const
   NoConnection(host: 'x'))` compared two identical failures and got
   `Expected: <Instance of 'NoConnection'> / Actual: <Instance of 'NoConnection'>` —
   the failure *text* of a missing `operator ==`. A value carrier whose equality is
   identity cannot go in a `Set`, cannot be compared by a screen and cannot be
   asserted on, so "an outcome is a value" would have been a comment rather than a
   property. Fixed by hand, and the header says why it is hand-written: `core/` is
   the leaf layer and imports nothing from `lib/`, so a codegen `part` file there puts
   a build dependency at the bottom of the graph — and each of these is five
   primitive fields, where `freezed` would emit more code than it replaces plus a
   `copyWith` nobody wants.
2. **`BrowseEmpty` was reachable in 12 combinations, not 1.** My own test asserted
   `reached == 1` from the plan's wording ("appears in *one* of the count/signal
   combinations") and measured 12. The **12 is correct** — 2 counts × 6 stages, all
   with a signal — and the assertion was the thing that was wrong. The test now
   asserts the half that matters and that the plan actually means: **no signal-less
   combination ever reaches `BrowseEmpty`** (0 of 36), and not every combination does.
   A test asserting a wrong constant is worse than no test, because it is green until
   the arithmetic changes.
3. **`retriable` could not be looped over six causes.** `ItemRemovedAtSource` is
   produced **only** by `6-4`, which is the only layer holding the site's answer, so
   driving it through `classify` yields a `BrowseSucceeded`. Split into two tests: the
   five producible causes must return the cause that went in *and* agree on
   `retriable`, and all six are pinned against the § 3.4 table by value — which is
   stronger than self-consistency, since a cause that flipped its answer now fails
   rather than agreeing with itself.

**Two proven RED by sabotage**, because a green suite proves nothing about whether it
can go red:

- moving the signal check **after** the count check — the exact § 3.2 mistake — fails
  1 test (`a present signal with results wins over the count`);
- returning `BrowseSucceeded([])` instead of `SourceLayoutChanged` on an absent
  container — **the SC-6 defect itself** — fails 9.

**§ 3.5's coherence test runs against Royal Road, not FanMTL.** The plan names
`fanmtl-broken-layout.html`; FanMTL is unreachable from here (F-012) so `0-1`
manufactured the pair from Royal Road, which it could reach. What § 3.5 asks for is a
property of the *classifier*, and the three outcomes — absent probe, empty container,
forged signal — are produced from that one file with no network. The test also pins
the pair: the intact capture really did have `.chapter-inner.chapter-content`, and the
manufactured one really does not, on a page that is otherwise well formed and 92 KB of
prose.

### Verified

format clean · `analyze --fatal-infos` **zero** · host **287 passed + 9 skipped** ·
`check_plans` **38 clean** · every declared foundation test location now exists.

### NEXT SESSION SHOULD

- **`2-1`, the Source contract**, against captured facts: five-segment chapter URLs,
  `chapter-inner chapter-content`, **and no site empty-result marker at all** — which
  means `BrowseEmpty` is unreachable on Royal Road and page shape is the only
  discriminator. `0-2` is what measures that, and it is blocked on FanMTL, so `2-1`
  must be written for the two-state reality the capture shows.
- **`0-2`, `0-3`, `2-6`, `6-3`, `0-5`** — the rest of Wave 1.

### `0-2` — measuring FanMTL/Royal Road empty-result signal

`lib/domain/sources/empty_signal.dart` probes fixture bodies for an explicit "nothing
here" string. Only text nodes are collected, with `<script>`, `<style>`, `<noscript>`,
`<title>`, `<template>`, `<svg>`, `<head>` skipped. A string only in a script or
comment is `hiddenOnly`, not `carries`; the verdict is `ambiguous` in that case.

A small but necessary correction: a literal can be visible to a reader but not a
substring of the raw serialised HTML (e.g. two `<h1>` tags splitting a phrase), so
`isPresent` checks `rawHits OR visibleHits`, and the verifier uses that. The
synthetic tests in `test/domain/sources/empty_signal_test.dart` each build their own
probe (closed literal set), and the group asserting "bodyless" HTML accommodates HTML5
tree-building that synthesises a body.

For Royal Road, `failure-not-found.html` carries the two strings in visible text and
no catalogue/novel/chapter page does; `signalOnFailurePageOnly`, `statesAvailable=3`
but `appliesTo = [search, novelDetails, chapterContent]`, `doesNotApplyTo =
[genreBrowse, catalogueBrowse]`. This resolves `roadmap.md` § 7.2 item 2 for the site
we could reach.

The file `test/fixtures/sources/royalroad/empty-signal.json` is **re-derived**, not
invented: `test/domain/sources/empty_signal_test.dart` loads it and compares it to the
verdict recomputed from the fixtures on every run. It fails if `foundInFixtures`,
`absentFromFixtures`, `statesAvailable` or `verdict` drift. Tested by sabotage: drift
verdict → guard fails; drift foundInFixtures → guard fails.

`0-2` is now `built`.


### `0-3` — Royal Road pagination, and three corrections that were wrong in the prose

`test/fixtures/royalroad_pagination_probe.dart` reads the frozen fixtures. The capture
itself was done under `0-1`, which could reach Royal Road; `0-3` never got a FanMTL to
measure. The plan's `Emplacement` was `royalroad_fixtures_test.dart`, written here as
`royalroad_pagination_test.dart` because everything in it is about pagination and chapter
completeness.

**Three claims in the plan and in `18-external-contracts.md` are contradicted by the
bytes**, and each is asserted rather than noted:

| Written | Actually | Consequence of trusting the prose |
|---|---|---|
| catalogue rows are `tr.fiction-list-item` | `div.fiction-list-item.row`, 20/page, and the page has **no `<table>` at all** | a probe reports 0 rows, calls the page empty, hands `0-2` an "absent" verdict for a full catalogue |
| numbered anchors expose an offset | there is **no offset**; `?page=N`, 1-based | `?page=` never found → pagination reads absent → the source reads page 1 forever |
| the current page is `li.active` | `li.page-active` | every page reads as page 1 |

**⚠️ `0-3` § 3.2.1's confirmation rule is WRONG for this site, and the deviation is
recorded in the rules file rather than hidden.** The rule is
`secondPageItemCount > firstPageItemCount`. Royal Road serves **20 items on every listing
page**, so the rule is false on a site whose pagination demonstrably works — page 1
holds 20 novels, page 2 holds 20 *different* novels, verified by hashing sorted
`/fiction/<id>` hrefs. Applying the rule literally would record working pagination as
unconfirmed, and `2-1` would treat `?page=N` as decoration: a failure that looks like
"the source returned everything" while dropping 99 % of the catalogue. Confirmation is
therefore a **set comparison**, and both counts are still recorded so a reader can check
the reasoning. A test asserts `isConfirmed == false` for the count rule **and** that the
manifest's basis names the distinct-href check.

**The most useful finding is a negative one: the chapter table is NOT paginated.** All
716 chapters are on the fiction page, `data-chapters="716"` matches 716 `tr.chapter-row`,
and 716 distinct chapter hrefs agree. Completeness is **arithmetic**, not suspicion. The
fiction page's pager is `?reviews=N` — the **reviews tab** — and recording that
distinction is what stops `2-1` hunting for chapter pages that do not exist.

**Two defects fixed while measuring:**
- `li.page-active` was being read as `active`, so every page measured as page 1.
- `javascript:;` anchors exist on the page outside `ul.pagination`. Counting all anchors
  reports them as pages. Anchors are now scoped to the pagination container, where there
  are none — and a test asserts the page *does* contain them, so the scoping is real.

**The manifest's `pagination[]` was being loaded by nothing.** `FixtureManifest.load`
ignored unknown top-level keys, so the section could sit in the JSON looking measured
while no test could fail if it were wrong. It is now parsed into `PaginationRecord`, and
the loader **refuses** a record that claims `isConfirmed: true` with no parameter or no
`confirmationBasis` — the same rule as a hand-typed `bytes`. Verified by sabotage:
forcing the loader to ignore `pagination[]` fails 4 tests; marking the catalogue
unconfirmed fails 1.

`18-external-contracts.md` § Royal Road: the "to be discovered during implementation"
line is replaced with the measured values, and the **`There is nothing here :(` empty-signal
claim is RETRACTED** — its selector matches nothing on the live site and a zero-row
catalogue carries no marker at all.

### Verified

format clean · `analyze --fatal-infos` **zero** · host **329 passed + 9 skipped** ·
`check_plans` **38 clean**. Sabotage: the plan's selector → 2 failures; `page-active` →
`active` → 2 failures; loader ignoring `pagination[]` → 4 failures.

### NEXT SESSION SHOULD

- **`2-1`, the Source contract**, now with four measured facts it cannot get wrong:
  `.fiction-list-item` (not `tr.…`), `?page=N` 1-based set-confirmed, chapter list
  **unpaginated** with `data-chapters` as the witness, and **no** browse-side empty
  signal (`empty-signal.json`).
- **`2-6`**, **`6-3`**, **`0-5`** — the rest of Wave 1.

### `2-6` — reading position, and a database trap that made FK enforcement optional

`lib/domain/library/reading_position.dart`, `position_restore.dart`,
`reading_position_store.dart` (interface), and
`lib/data/library/drift_reading_position_store.dart` (drift). 41 rows.

**⚠️ A real defect in `AppDatabase.forTesting`, found by writing a cascade test.**

The cascade test failed — deleting a novel did **not** remove its reading positions.
The cause is not `2-6`: `AppDatabase.forTesting(super.executor)` passed the executor
straight through, and `PRAGMA foreign_keys` is applied by `setup: _setup` on the
**production** path only. A test database therefore had **no FK enforcement at all** —
every `references(...)` decorative, `RESTRICT` not restricting, `CASCADE` not cascading.

`app_database_test.dart` had been papering over this by passing the pragma itself and
carrying a comment explaining why. **Every other test file inherited the trap.** A
cascade or RESTRICT test written against `forTesting(NativeDatabase.memory())` observes
a schema with no constraints — and the constraint simply does not fire, which reads as a
broken `onDelete` rather than a broken harness. That is the exact failure mode already
recorded for this file in the database comments, reproduced in the test layer.

Fixed at the source: `forTesting` now wraps the executor in `_SetupExecutor`, which runs
the pragma in `ensureOpen` — the only point where a connection is guaranteed open, and
the only point where a **per-connection** pragma can be applied. Safe is the default;
asking for a pragma-free database is now a deliberate act. The wrapper implements
internal drift API (not exported), so it is documented as such.

**⚠️ The plan's § 3.2 clamp branch in the ratio case is UNREACHABLE by a shrink.**

`raw <= storedHeight` ⇒ fraction ≤ 1 ⇒ fraction × extent ≤ extent. My test asserted a
clamp on `900/1000 × 300` and measured **270**. The arithmetic was right; the assertion
was wrong, and the plan's reasoning is wrong. A shrink is safe by construction. Only an
**inconsistent row** (offset larger than the height it was measured against) clamps
there — which *is* reachable, because `maxScrollExtent` can change between the frame
that measured it and the frame that writes the position. Both rows are now asserted, and
the distinction is written down: **a shrink never clamps; only an inconsistent row
does.** Conflating the two would have made the clamp untestable and therefore unverified.

**Three more things found by writing the tests:**
- `ReadingPosition` needs value equality or nothing can be asserted on it — the same
  defect as the six causes in `failure-discriminator`.
- `updatedAt` is written by the **store**, not passed in. The caller has a position in a
  chapter, not a clock; a repository that accepted a timestamp would let a feature
  invent one, and `updatedAt` is B17's ordering key.
- `mostRecentAmong` needed a **deterministic tiebreak** on `chapterId`. Two writes in
  the same millisecond are possible on a fast scroll settle, and without the tiebreak
  the "most recent" answer is whatever SQLite returned — non-reproducible and untestable.

Also fixed: a test helper re-inserted the novel per chapter, so four tests died on a
UNIQUE constraint that says nothing about reading positions.

**Proven RED by sabotage:** removing the FK pragma → the cascade test fails; disabling the
ratio branch → **6** rows fail (same-extent, shrunk, grown, shrink-no-clamp,
inconsistent-clamp, monotonicity); making `wasClamped` always false → the clamp row fails.

### Verified

format clean · `analyze --fatal-infos` **zero** · host **370 passed + 9 skipped** ·
`check_plans` **38 clean**.

### NEXT SESSION SHOULD

- **`6-3`**, the local counting model — B48's *derived* unread count over
  `idx_chapters_novel_read`, with no `unreadCount` column anywhere.
- **`0-5`** — the route table, the last Wave 1 node.
- **`2-1`**, now with five measured facts: `.fiction-list-item`, `?page=N` 1-based and
  set-confirmed, chapter list **unpaginated** with `data-chapters` as the witness, no
  browse-side empty signal, and `chapter-inner chapter-content`.

### `6-3` — the local counting model, and a defect in the plan's own SQL

`lib/domain/library/library_update_fact.dart` (`LibraryUpdateFact`, the sealed
`Verification`, `UnopenedCountRepository`) and
`lib/data/library/drift_unopened_count_repository.dart`. 46 rows.

**⚠️ The plan's `ORDER BY … COALESCE(n.added_at, 0)` does the opposite of what the
plan says it does.** The plan's own comment: *a library novel with no added_at … must
not sort first everywhere.* But `COALESCE(NULL, 0)` maps null to the **epoch**, and the
epoch sorts **first**. So the plan's SQL sorts untimestamped novels to the top while
claiming to prevent exactly that. The query uses `(n.added_at IS NULL), n.added_at ASC`,
which puts nulls last — what the prose asked for and what "ties keep library order"
(`updates.md` § 4) means. A test asserts a novel with a null `addedAt` sorts **after** a
dated one with the same count, so the two readings cannot be confused again.

**⚠️ `COALESCE(SUM(…), 0)` is redundant with `ELSE 0` inside the `CASE`, and no test can
tell them apart — so the file says so instead of claiming otherwise.** I sabotaged each
independently and **every row stayed green**: with `ELSE 0`, a null-joined row
contributes 0 and `SUM` returns 0; without it, `NULL = 0` is NULL and `COALESCE` saves
the day. Both are kept as two cheap guards on one property, and the **property** is what
a test asserts: `unopened` is `0`, never `null`, because a nullable count makes "how
many?" a screen's decision. The first version of that comment asserted `COALESCE` was
required and a comment making a false claim is worse than no comment.

**⚠️ `readsFrom` is not optional decoration.** drift's `customSelect` without it returns
a value that does not re-emit — the badge would emit once and silently stop updating.
Sabotaged: removing it fails the stream row.

**LEFT JOIN vs INNER JOIN, proven.** Sabotaged to `INNER JOIN`: **2 failures** — a library
novel with no chapter list disappears, which is B48 missed (*"I have not asked" is not
"there are none"*).

**`customSelect` rather than drift's query builder.** The plan's query is
`SUM(CASE …)` in a group by over a `LEFT JOIN`, which drift's expression builder has no
clean spelling for. The first attempt produced twenty minutes of cast soup nobody could
read. The SQL *is* the specification, and the part the builder cannot express is exactly
the part that matters.

**`Verification` is sealed, and `CouldNotCheck` carries a typed failure.** `null`,
"epoch 0" and "this instant" are three claims, and a nullable `DateTime` would let `null`
render as "just now" in one place and "Never checked" in another.

**B48's negative space is tested.** Three rows assert no table has an unread-count column,
`schema.json` has none, and the count moves exactly when the underlying rows move —
because it was never a number.

**Two test defects worth naming, both of which had a correct *product* underneath:**
- The B38 structural assertions searched whole files and failed **on their own doc
  comments**, which mention "download" extensively to explain that the repository cannot.
  A structural assertion that trips over its own explanation gets weakened, and weakening
  it removes the check. Now the search strips comments first.
- `markAllOpened preserves first readAt` asserted a timestamp the test itself had passed
  to `markOpened` — which does nothing to an already-read row. Correct behaviour, wrong
  expectation. The fixture's read time is now one named constant, because it was written
  twice with different values (`2026-09-01` in the helper, `2026-09-02` in the
  assertion) and a test comparing against a different number than the fixture wrote
  cannot tell a regression from a typo.

### Verified

format clean · `analyze --fatal-infos` **zero** · host **397 passed + 9 skipped** ·
`check_plans` **38 clean**. Sabotage: INNER JOIN → 2 failures; `readsFrom` removed → 1;
`markOpened` restamping `readAt` → 1; `COALESCE` removed → 0 (recorded as redundant).

### NEXT SESSION SHOULD

- **`0-5`**, the route table — the last Wave 1 node.
- **`2-1`**, the Source contract, against five measured facts and no browse-side empty
  signal.
- **Findings to promote**: the plan's `COALESCE(added_at, 0)` sorts nulls first; `customSelect`
  needs `readsFrom` or a stream emits once; `AppDatabase.forTesting` was a FK trap.

---

## 2026-10-03 — Session 9: the tree did not compile, and the tracking file was wrong in both directions

### STARTED FROM

Phase 7 `in_progress`, `state.js start` reporting **32 slices, all `planned`, zero
suspended** — and `flutter analyze` reporting **18 errors**. The previous commit
(`b49c11e`) had added `lib/domain/sources/source.dart`, which imports five model files
that were never written. The last green commit was the one before it.

### DECIDED

- **Repair before anything else.** Not a commit on top of a broken tree: the Definition
  of Done lists `flutter analyze` as item 2 and item 2 is a gate, so a commit that skips
  it is not a commit with a gap, it is a commit that skipped the gate. Everything else in
  this session waited.
- **The five models are `domain`, so `ChapterRecognition` and `NovelStatus` went in the
  files that own the fields they fill** — `models/chapter.dart` and `models/novel.dart` —
  rather than in a sixth file nothing else imports. `SourceId` is a separate file because
  `source.dart`'s own doc comment already names `SourceId.of`, and three layers derive
  through it.
- **`FilterList` extends `ListBase`, it does not delegate through `noSuchMethod`.** Both
  satisfy "implements `List` by delegation". Delegating through `noSuchMethod` reaches
  `NoSuchMethodError` — *"Class 'List<Filter<Object?>>' has no instance method 'add'"* —
  because the unmodifiable inner list has no `add`. That reads like a typo in the caller;
  the caller wrote a method that **exists and is refused on purpose** (rule 5: the platform
  does not change what a source declared). `ListBase` routes every remaining mutator
  through `[]=` or `length=`, so two overrides refuse all of them, and the refusal names
  the rule.
- **`Novel.toString` carries the id and not the title.** `2-1`'s own acceptance criterion
  for the dropped-row path is that the site's title never reaches a log, and a `toString`
  is the most likely accidental carrier. Printing it would make the criterion true of the
  logger and false of the model.
- **`state.json` now says what is true.** Six foundations and six slices were reported
  `planned` while their code and tests were committed and green. Four are complete and
  tested, two are provably partial (`0-1` blocked on F-012, `2-1` has its data layer and
  no source), and the state now says exactly that.

### REJECTED

- **Renumbering `.forge/plans/2-1.md` § 3.1 to match its own constant.** The plan
  *displays* `md5('f321cc5e…31//novel/ke383028.html')` — two slashes — beside the frozen
  constant `90db9662…`, which is the digest of the **one**-slash string. Both were computed:
  ```
  md5(sid + "//novel/ke383028.html")  = 071603bb…   ← not the plan's value
  md5(sid + "/novel/ke383028.html")   = 90db9662…   ← the plan's value
  ```
  The constant is the authority — it was computed, the string was written by hand. So
  `SourceId` strips leading slashes and both shapes are pinned by a test. Rejecting the
  renumbering is deliberate: editing the plan to match the code would have removed the
  record of the contradiction.
- **Adding `navMore` to the ARB files is not this slice's to decide.** `0-5` § 7 question 3
  says the foundation `localisation` owns the keys and `0-5` consumes them. `localisation`
  **is** built and `navMore` is not in either file. Leaving it missing means a fifth tab
  with no label in two languages, which is B28 violated directly; so it gets written, in
  both files, in the same commit — `16-i18n.md` rule 2's requirement — and the owner of
  the key is recorded rather than assumed.
- **Implementing `FanMtlSource` now.** Its three catalogue selectors are unfilled, F-012
  measured the site at 403 behind a Cloudflare challenge for an honest UA one day after
  ADR-014 measured 200, and `2-1` § 7 question 3 says a guessed selector has **no
  recovery**: it matches nothing, every page reads as `SourceLayoutChanged`, and SC-6's
  fixture becomes indistinguishable from a working site. No bypass, no impersonation.
  Royal Road has 2 MB of measured fixtures; FanMTL has none.

### BLOCKED

- **F-012 (FanMTL 403) stays open.** The documentation half is done —
  `18-external-contracts.md` records the 403 on five paths with an honest UA. The capture
  half needs the owner's phone. No bypass will be built: ADR-014 already rejected the
  WebView technique, and C2 plus `17-security.md` rule 7 put a challenge-solving WebView
  out of scope independently. A Cloudflare interstitial is the site declining; the correct
  response is to record it, not to defeat it.
- **F-013 is promoted.** Its correction was *find the current catalogue and chapter URLs
  and update the file*: Royal Road's are `/fictions/…` for listings and
  `/fiction/<id>/<slug>/chapter/<chapterId>/<slug>` for a chapter, both captured, both
  measured, both written back.
- **On-device suite**: `YBZ2577ALDAC000899` is absent from `adb devices`.

### FILES TOUCHED

**Product** — `lib/domain/sources/{source_id,source}.dart`,
`lib/domain/sources/models/{novel,chapter,novels_page,update,filter}.dart`,
`test/domain/sources/{source_id_test,chapter_test,models_test}.dart`.

**Forge state** — `.forge/audit/issues.md` (created; 5 incidents), `.forge/state.json`
(13 findings promoted, duplicate key removed, `test_plan` premise declared, 12 node
statuses corrected), `.forge/plans/{2-2,6-6}.md` (two broken pointers).

**The skill itself, in `~/.agents/skills/forge/`** — five defects fixed, each with a
witness on both sides:

| Defect | Fix | Failing witness | Clean witness |
|---|---|---|---|
| `finding` minted `F-014` twice | next id = max + 1, plus a `while` that skips any id in use; `--resolve` stamps `retired_at` | 13 entries, gap + resolved entry → `length+1` = `F-014`, an id in use | same command → `F-015` |
| four slices reported **0** tests, they had **138** | one `L.countSliceTests`, both branches, both scripts | `attendu F-010 (max+1), obtenu F-003` | 228 selftests pass; a slice no test cites still returns 0 |
| `register` accepted two keys for one path | refused, existing key named | refusal leaves `state.json` byte-identical | re-registering the canonical key passes |
| `version_pins_agree` read `.dart_tool/` | generated dirs skipped; a JSON name must be declared | real conflict + noise → `fail` on the conflict only | clean tree → `pass`; **no manifest** → still `fail` |
| `section_references` could not pass | index walks `.opencode/rules/` and `.forge/**`; external targets reclassified | — | 113 files, 3 843 references resolved, **2 true broken pointers found and fixed** |

`selftest.js`: **228 passed, 8 skipped, 0 failed**. The 8 skips are the `pglite` engine,
absent from this machine; `skip` is not `pass` and the output says so.

### STATUS

`dart format` clean · `flutter analyze --fatal-infos` **zero** · host **457 passed +
9 skipped** · `forge-guard all` **pass** · `consistency-check all` **pass** ·
`coverage-check` on the touched slices · one unpromoted finding left, **F-012**, which is
the only honest one.

### NEXT SESSION SHOULD

- **`0-5`** — the route table, `AppScaffold`, `AppShell`, `MaterialApp.router`. The
  `appRouter` must be a top-level `final`, or E12's language switch loses the navigation
  stack; and `main` must be `async` and **await** `SharedPreferences`, or
  `appThemePreferencesProvider` throws on the first frame.
- **Then Wave 2**: `0-4`, `3-5`, `6-5`, `6-7`, `3-7`, `6-11`.
- **`2-1`'s source implementations, against Royal Road** — the one site with measured
  fixtures. FanMTL stays unimplemented while F-012 is open.

### NEXT SESSION SHOULD NOT

- **Do not rename a test file to contain its slice key** just to satisfy
  `state.js start`. That was the defect: the tracking file, not the tests, was wrong.
- **Do not re-add `--delete-conflicting-outputs` to `build_runner`**, and do not run
  `dart run drift_dev schema dump` with one argument — it prints usage and exits 0, which
  looks like success.
- **Do not treat `check_plans.py` passing as "the plans are implemented"**. It checks
  headings and ids; the code is the only proof, and the last commit before this one was
  proof of the opposite.

---

## 2026-10-03 — Session 10: `0-5`, and the route the plan had wrong

### STARTED FROM

Session 9's repair committed at `e0015ed`: 502 tests green, tree compiling, Forge state
telling the truth. `0-5` is the last Wave 1 node — *routing*, not a screen. Eighteen
screens had no route to mount on.

### DECIDED

- **`AppShell` is a `Column`, not a `Scaffold`, and `AppScaffold` is the only `Scaffold`
  in the app.** Two would give every screen two `SafeArea`s and put the shell's bar under
  the screen's own. Three symptoms, one cause.
- **`FilterList`… no. `openReader` and `openOnboarding` use `push`, and `go` is not
  available to a caller.** The plan § 2.3 wrote `/reader/…` as a root-level route with
  `parentNavigatorKey: branchKeys.first`, and **go_router rejects that**: a
  `parentNavigatorKey` must name a shell's key or the root's, and a root-level route's
  parent is the root. The plan's own § 11.2 tab asserted `appRouter` starts on `/library`,
  so it passed every gate while never being instantiated — nothing ran it.
- **The real consequence is worse than the crash.** `go()` **replaces** the root page
  list; `push()` **appends** to it (`RouteMatchList.push` →
  `_createNewMatchUntilIncompatible`, go_router 18.0.2 `lib/src/match.dart`, read in the
  installed source). So a root-level reader navigated with `go` unmounts the shell: the
  reader loses the tab they came from, that tab's stack, its scroll position, and `pop`
  then has nothing to pop — a reader who opens a chapter from *Updates* and presses back
  **leaves the app**. The capability is therefore exposed as `openReader`, which contains
  the correct call and nothing else, and a grep row forbids `.go(AppRoutes.readerFor`.
- **`/library/novel/:novelId/chapter/:chapterId` is NOT declared.** `0-5` § 7 question 1
  asked who owned it. `design-system.md` § 3.5's table already answered: **removed**
  2026-10-02, because every screen that opens a chapter pushes `/reader/…` (3 call sites,
  0 for the other form). The plan's § 2.2 was written from a pre-removal reading.
- **`navMore` is written, in both ARB files, in this commit.** `0-5` § 7 question 3 said
  the label test "fails, and that is the correct outcome while the `localisation`
  foundation has not written the key". The foundation **is** built and did not write it —
  so that row was not a demonstration, it was a defect that would have shipped. B28 is
  not satisfied by four of five labels.
- **The icons are this slice's choice and are named as such.** § 3.2 gives labels, not
  icons. The bundled Material set, one outlined/filled pair each. The testable property is
  not "which glyph" but *every destination has a pair and the two differ* — otherwise a
  selected tab is indistinguishable from an unselected one.

### REJECTED

- **Nesting the reader under the Library branch with a root `parentNavigatorKey`**, which
  is go_router's canonical "full-screen route" example. It renders above the shell and
  `pop` works — but the URL becomes `/library/reader/…`, which is a third spelling of a
  destination § 3.5 already reconciled, **and** opening a chapter from *History* would
  switch the reader to the Library tab. Changing three screen files and a reconciled
  design table to buy a property `push` gives for free is the worse trade.
- **Adding `@visibleForTesting` hooks to production code** for the router's shape. The
  structural claims ("this is a top-level `final`", "main awaits its preferences") have
  no runtime witness, so they are **grep rows** with a witness string each, matching the
  idiom `no_telemetry_test.dart` already established. Adding a hook to production code so
  a test can assert a fact about production code is the defect the grep exists to avoid.
- **Weakening `avoid_redundant_argument_values` for the `immersive` row.** `showBottomNav`
  defaults to `true`, and that default *is* the trap: a reader screen that forgets to set
  the state gets `true` without asking. The row now omits the flag and proves the default
  loses to the state anyway.

### BLOCKED

- **F-012 (FanMTL 403) unchanged and still the only open finding.** No bypass, no
  impersonation, no second Chrome instance. `2-1`'s catalogue selectors stay unfilled:
  § 7 question 3 says a guessed selector has **no recovery** — it matches nothing, every
  page reads as `SourceLayoutChanged`, and SC-6's manufactured fixture becomes
  indistinguishable from a working site.
- **On-device suite**: `YBZ2577ALDAC000899` still absent from `adb devices`.

### FILES TOUCHED

`lib/app/router/{app_routes,app_nav_destinations,app_router,placeholder_screen}.dart`,
`lib/app/shell/app_shell.dart`, `lib/core/ui/app_scaffold.dart`, `lib/main.dart`,
`lib/l10n/app_{en,fr}.arb` + generated,
`test/app/router/app_router_test.dart`, `test/app/shell/app_shell_test.dart`,
`.forge/design/design-system.md` (amended, §§ 3.5.1–3.5.2).

### STATUS

`dart format` clean · `flutter analyze --fatal-infos` **zero** · host **502 passed +
9 skipped** · `forge-guard all` **pass** · `consistency-check all` **pass** ·
`coverage-check 0-5` **pass** · `design-check` contrast / tokens / component-parity
**pass**.

**Sabotage, each on both sides** — because a check that has never failed is a check that
has never been tested:

| Sabotage | Result |
|---|---|
| `immersive` honours `showBottomNav` again | the immersive row **fails** — a `nav` key is found |
| `openReader` uses `go` instead of `push` | *the reader is above the shell, so back returns there* **fails** |
| FR `navMore` renamed `Plus` → `Encore` | *the labels are § 3.2 word for word* **fails**: `Expected: 'Plus' Actual: 'Encore'` |
| `navMore` deleted from both ARBs | `arb_completeness_test` cannot even compile the app's label row — the key is a build-time dependency, which is stronger than a red row |

Two test defects found and fixed in this session's own tests, both of the "a check that
never looked at the requirement" family:

- The provider-override grep was written as an **absence** check, copied from its
  neighbours, so it forbade the exact line the requirement needs and passed while
  asserting nothing. It is a **presence** check now, and it counts.
- `await openReader(...)` **hung the row for four minutes** and looked like a router
  deadlock. `GoRouter.push` returns a future that completes when the route is **popped**.
  Three rows now use `unawaited`, and say why.

### NEXT SESSION SHOULD

- **Wave 2**: `0-4`, `3-5`, `6-5`, `6-7`, `3-7`, `6-11` — the foundations are built and
  these are the slices that consume them.
- **`2-1`'s source implementations, against Royal Road.** `div.fiction-list-item.row`,
  `?page=N` 1-based, an unpaginated chapter table with `data-chapters=716` as the witness,
  and `chapter-inner chapter-content` for the body. FanMTL stays unimplemented while
  F-012 is open.
- **Every screen slice fills exactly one `PlaceholderScreen`.** The route table is the
  contract; each one names the route it stands in for, so the reader of a failed route
  knows which slice is missing.

### NEXT SESSION SHOULD NOT

- **Do not add a testing hook to production code to make a structural claim testable.**
  Write the grep, and give the pattern a witness.
- **Do not `go()` the reader.** The grep row forbids it and says what breaks.
- **Do not pass `-d <device-id>` to `flutter test` for a file under `test/`.** The flag is
  silently ignored and a fabricated id still passes. Only `integration_test/` deploys, and
  it refuses an unknown device.

---

## 2026-10-03 — Session 11: the failure vocabulary, and a mistake I made mid-sabotage

### STARTED FROM

Wave 1 closed at `7d6808f` (502 tests). Wave 2 is six slices: `0-4`, `3-5`, `3-7`, `6-5`,
`6-7`, `6-11`. **`0-4` is blocked** — it ranks the furniture of a *FanMTL* chapter page,
and FanMTL is 403 behind a Cloudflare challenge for an honest UA (F-012), so there is no
page to rank and § 7 question 3 says a guessed answer has no recovery. `6-7` is the one
Wave-2 slice with **no blocked dependency**, and it is the one every screen slice needs:
B28 demands a string in two languages for every error and download status, and there
were sixteen keys, all navigation.

### DECIDED

- **`forSourceFailure` has SIX arms, not seven.** `architecture.md` § 5.2's table has
  seven rows and `StorageFull` is the seventh — but a full disk is **not a source read**,
  so it cannot be a `SourceFailure`, and `failure-discriminator` did not create one. A
  storage failure reaches the mapper through a **write**. Inventing a
  `StorageFull extends SourceFailure` would put "the phone is full" inside a taxonomy
  whose whole subject is *a site that could not be read*, and every reader of § 5.2 would
  then believe the table and the hierarchy agree. **They do not, and that difference is
  the useful part.** The test asserts `hasLength(6)` and says why in its reason string.
- **Three `AppException` subclasses were added**, all three named by
  `13-error-handling.md` § The hierarchy: `SourceException`, `DatabaseException`,
  `ChapterNotAvailableException`. The rule file already lists them; only
  `NetworkException` and `CancelledException` existed. Each carries the fact § 5.2 says a
  screen needs — `status` for `SourceException`, `operation` for `DatabaseException`,
  `chapterId` for `ChapterNotAvailableException` — because a bare "storage error" is not
  something a reader can describe, and C12 asks for one they can.
- **`SourceFailure` and `AppException` are mapped side by side, never chained.** Reads
  **return** `BrowseFailed(reason)`; writes **throw**. Different directions, so merging
  them would be one fact with two representations — the shape this project has been
  bitten by twice.
- **`recovery()` returns `null` in six places, and that is the point.** A `Retry` on
  `SourceLayoutChanged` is a lie: no retry repairs a site that renamed its markup. A
  `Retry` on `ParseFailed` is a lie for the same reason. `RateLimited` offers **nothing**
  because the site's `Retry-After` already says when, and B37 plus
  `17-security.md` rule 6 are explicit that a retry earlier than the header makes the
  rate limit worse. `architecture.md` § 5.2's "Recoverable by retry" column stops being
  advisory and becomes executable.
- **`RateLimited` is the only arm that reads `retryAfter`,** and a row asserts every
  other arm **ignores** it — otherwise the parameter becomes a second source of truth
  for a sentence.

### REJECTED

- **Adding a `RateLimitedException`.** The plan's § 2.2 mapping references one. The rule
  file does not declare it, and rate limiting is a *site* fact, which is exactly what
  `SourceFailure` carries. A fifth exception type would put "the site said 429" in the
  write-side hierarchy.
- **Making `forDatabaseException` distinguish "out of room".** It was written, then cut:
  it takes the exception and returns a constant, so the name promises a decision the
  body does not make. The honest version is a parameter the caller supplies, and no
  caller exists yet — a function shaped for a caller that has not been written is
  scaffolding, and the rule against speculative code is in the priority order at 5.

### BLOCKED

- **`0-4` stays blocked on F-012.** No bypass, no impersonation.
- **F-012 remains the only open finding.** Unchanged and unpromoted.

### FILES TOUCHED

`lib/l10n/app_{en,fr}.arb` + generated (41 keys each, from 17),
`lib/core/error/app_exception.dart` (+3 subclasses),
`lib/core/ui/app_error_copy.dart` (new — the one mapping point),
`test/core/ui/app_error_copy_test.dart` (25 rows).

### STATUS

`dart format` clean · `analyze --fatal-infos` **zero** · host **527 passed + 9 skipped**
· `forge-guard all` **pass** · `consistency-check all` **pass** ·
`coverage-check 6-7` **pass** · EN and FR carry **41 keys each, identical sets**.

**Sabotage, all three observed:**

| Sabotage | Result |
|---|---|
| `sourceLayoutChanged` mapped to `commonRetry` | *a changed layout offers "report", never "retry"* **fails** |
| one FR sentence replaced by its EN twin | *the two languages are not the same sentence* **fails**: `1 sentence(s) are identical in both languages` |
| one EN sentence prefixed `NetworkException:` | *no sentence leaks a class name* **fails**: `contains "Exception"` |

**A mistake of mine, recorded because the next session needs to know it happened.** While
restoring after the third sabotage I ran `git checkout lib/l10n/app_en.arb` and
`lib/l10n/app_fr.arb` to undo a one-line edit — and **that reverted the whole slice's
ARB work**, because those files were uncommitted. The French file was rebuilt from the
message content and verified key-for-key against the English one (41/41, no difference);
the English file was restored from a copy. No product code was lost and no test was
weakened, and `flutter analyze` was red for a while, which is how it was caught. **The
lesson is procedural and it is the reason this entry exists**: a sabotage must be undone
from a *copy taken for the purpose*, never from `git checkout` on a file the current
commit does not contain. There is a copy at `/tmp/opencode/en.bak` next time too, and
the copy is the rollback, not the index.

### NEXT SESSION SHOULD

- **`6-5`** (History) — check first whether `history_entries` exists; if not, this is a
  migration and `schemaVersion` stops being 1. Read the plan's § 2 before writing code.
- **`3-5`** (About) — needs three counts, two of which exist (`reading_positions` from
  `2-6`) and one of which does not.
- **`3-7`** (Settings) — depends on `6-5` and `6-7`.
- **`6-11`** — measure Royal Road's and Novel Fire's search with the honest UA. If the
  network refuses, that is a finding, not a retry loop.
- **`2-1`'s sources, against Royal Road.** `0-4` is not the only FanMTL hostage: the
  catalogue selectors are too, for the same reason.

### NEXT SESSION SHOULD NOT

- **Do not undo a sabotage with `git checkout`.** Copy the file first.
- **Do not add an exception subclass to fit a mapping.** `13-error-handling.md`: keep the
  hierarchy small, and add a subclass only when a caller needs to catch it specifically.

---

## 2026-10-03 — Session 12: Royal Road has a working search, and I wrote the verdict before measuring it

### STARTED FROM

`6-7` committed at `6001242` (527 tests). Wave 2 had one unblocked node left that needed no
code I did not already have: **`6-11`** — *does Royal Road implement a search a reader
would call useful?* An `Open items` row said **"unknown — not yet checked"** since
2026-10-02, and ADR-015 makes `supportsSearch` a promise, so an unchecked promise is a
guess wearing a flag.

### DECIDED

- **The method is ADR-015 word for word, and the negative query is not optional.** Two
  queries that MUST match (`litrpg`, `system+fantasy`) and one that cannot
  (`zzzqqqxxnotanovelname`), honest UA, GET, no session, redirects followed. Without the
  control, "20 rows for `litrpg`" and "the page always shows 20 rows" are the **same
  observation**, and a source that shows a random catalogue forever satisfies the first
  one.
- **A count is not the verdict; the titles are.** ADR-015 says *results a reader would
  call useful*. All ten sampled titles carry the queried words — *Cards of Transcendence
  - A Deck Building **LitRPG** Adventure*, *I Died to a Pole and Woke Up a Dragonborn
  [**LitRPG System Fantasy**]* — so the test asserts ≥5 titles contain a queried word,
  re-derived from the capture. A test asserting `rows == 20` would have passed against a
  page that ignores the query entirely.
- **`supportsSearch = true` for Royal Road**, and `03-source-system.md` rule 5a no longer
  applies to this site — so `3-1` may render a search entry for it.
- **Novel Fire is recorded as UNMEASURED, not `false`.** Every path — `/`, `/search`,
  `/search?keywords=litrpg` — answers **403** with a `Just a moment...` interstitial
  carrying `challenges.cloudflare.com`, on the honest UA. Rule 5a's list is *404,
  meta-refresh, timeout, empty page*; a challenge is none of those, it is the site
  declining to be read at all. Writing `false` from a 403 would be the guess ADR-015
  exists to forbid, and it would permanently hide a search box for a site nobody managed
  to look at. The `Open items` table now carries a warning that **two flags with two
  different reasons look alike**: FanMTL is `false` because its endpoint is *absent* (a
  property of the site, still true next month), Novel Fire is unknown because its
  endpoint is *unreadable today* (a property of this network, which the owner's own
  phone may answer).
- **The verdict is a frozen capture plus a re-derivation, not a comment.** Three pages
  (596 KB) under `test/fixtures/sources/royalroad/search/`, `verdict.json` beside them,
  and `test/fixtures/royalroad_search_test.dart` recomputing row counts, byte counts,
  title relevance and marker occurrence **from the pages**. `FixtureEntry.kinds` gained
  a closed-list entry `search`, and the row asserting its length moved from 8 to 9 — the
  point of closing a list is that adding a kind is a visible decision.

### REJECTED

- **`Row count == 20` as the test.** It is satisfied by a page that ignores the query. The
  titles are the evidence.
- **Declaring `supportsSearch = false` for Novel Fire from its 403.** Rejected above, and
  it is the single most consequential thing this session nearly got wrong: the flag would
  have been permanently false on the strength of a wall, and nothing would ever revisit it.
- **A separate `kind` per measurement** (`search-verdict`, `search-control`). One kind,
  three entries; the **pair** is the unit and the notes say so.

### THE MISTAKE, in full

**My first reading of `6-11`'s verdict was wrong, and wrong in the direction that made
the site look worse.** I wrote that Royal Road's search carried **no** empty marker — and
in the same file I listed `"No results"` among the markers I had checked, then asserted
that no checked marker was present.

The literal is there: `div.search-item.clearfix > h4.font-red-sunglo`, **"No results
matching these criteria were found"**, in visible text, **once** on the zero-row page and
**zero** times on either 20-row page.

So the correct verdict is the opposite of the first one, and it is better news:
`ReadStage.searchResults` becomes `zeroIsGenuine` for Royal Road, **`BrowseEmpty` becomes
reachable**, and B22 is satisfiable there because the site supplies the signal itself.

Why it happened, and this is the part worth keeping: I wrote the assertion from the
conclusion. `0-2` had measured the **browse** side and found no marker, and I carried that
result across to the **search** side without measuring — then wrote a test in the shape of
"the marker is absent" that passed the *listing* step and failed the *presence* step. The
list of candidate markers was the honest part; the conclusion was borrowed.

The failure was **loud**, and that is the whole reason it cost twenty minutes and not a
release: the test ran against the capture it was written from and failed on the first try.
A borrowed conclusion written as a *comment* would have shipped.

### The rule that comes out of it

**A measurement of one page is a measurement of that page.** `0-2`'s browse-side retraction
and `6-11`'s search-side finding are the same site, the same day, and **opposite**, and both
are now written in `18-external-contracts.md` as two sections with an explicit warning that
neither licenses the other. `kZeroItemsPolicyByStage` is declared per call by the source
that made the request for exactly this reason: one stage becoming genuine must not become a
policy on all seven.

### FILES TOUCHED

`test/fixtures/sources/royalroad/search/` (3 pages + `verdict.json`),
`test/fixtures/royalroad_search_test.dart` (new, 24 rows),
`test/fixtures/fixture_manifest.dart` (`search` kind),
`test/fixtures/fixture_manifest_test.dart`'s sibling `royalroad_manifest_test.dart`
(`verdict.json` excluded by exact name), `test/fixtures/fanmtl_manifest_test.dart`
(8 → 9), `.opencode/rules/18-external-contracts.md` (Open-items table + two new sections),
`tool/append_search_fixtures.py`.

### STATUS

`dart format` clean · `analyze --fatal-infos` **zero** · host **551 passed + 9 skipped**
· `forge-guard all` **pass** · `consistency-check all` **pass** ·
`coverage-check 6-11` **pass**.

**Sabotage**: the marker text replaced by something else in the control fixture → **two**
rows fail, the byte-count row first (the capture no longer matches what was recorded) and
then the marker discriminator. Replaced by the copy: 24 pass.

### NEXT SESSION SHOULD

- **`6-5`** (History) — `history_entries` **exists**, so no migration and `schemaVersion`
  stays 1. Read the plan's § 2 before writing code, because B47 (the list is bounded in
  time) and B46 (reading position never is) share a screen and must not share a query.
- **`3-5`** (About) — needs three counts. `reading_positions` exists from `2-6`; the other
  two are novel and downloaded-chapter counts.
- **`3-7`** (Settings) — depends on `6-5` and `6-7`.
- **`2-1`'s source, against Royal Road** — and now with `supportsSearch` measured, so the
  search path is buildable where before it was blocked on an open question.

### NEXT SESSION SHOULD NOT

- **Do not carry a measurement of one page across to another.** Two pages of the same site
  on the same day have produced opposite answers in this project. Measure the page.
- **Do not set `supportsSearch = false` from a 403 or a challenge.** Measure "unreadable",
  and record that.
- **Do not write an assertion from a conclusion you borrowed.** Write the measurement first,
  then the row that fails when it is wrong.

---

## 2026-10-03 — Session 13: `6-5` History, and the second the database actually stores

### STARTED FROM

`6-11` committed at `987d592` (551 tests). `6-5` is the first of Wave 2's slices with a
**table already in place** — `history_entries` and `reading_positions` both exist from
`local-store`, so no migration and `schemaVersion` stays 1. The plan says so; the plan was
worth reading before writing, because B47 and B46 land on the **same screen** and must not
land on the same query.

### DECIDED

- **`clearAll()` is one statement, `DELETE FROM history_entries`, with no join.** Not "a
  join we decided against" — **no join**. A join is readable, reversible, testable, and
  would still destroy the reader's place in a product with no remote copy of anything
  (C8, ADR-010). B46's requirement is an absence, so the absence is what the code shows.
- **`readResumePoints()` joins `reading_positions ⋈ chapters ⋈ novels` and reads NO row
  of `history_entries`.** B17's second sentence says the last chapter read for a novel
  comes from the position record. Deriving it from the journal is the one implementation
  that looks entirely reasonable and is wrong: erasing the journal would erase where the
  reader stopped, which is the most destructive thing this app could do and the one no
  other test in the project would object to.
- **The domain layer takes no clock.** Every function that needs "now" is handed it. A
  function reading a clock would be untestable exactly at a midnight boundary, which is
  the only place any of this can be wrong.
- **The day header is computed, never stored, and compared field by field.**
  `isSameLocalDay` reads year/month/day and **ignores the time**, because an
  instant-based comparison puts a 23:55 row and a 00:05 row in the same group — the
  row a reader reads as *yesterday* lands under *today*.
- **`readsFrom` for the journal deliberately omits `readingPositions`.** A journal row
  carries no position, so a position write cannot alter one. Listing it would make a
  scroll re-query the journal and re-render the list under the reader's thumb.
- **`HistoryRetention` is an enum, not a `Duration`**, because a raw `Duration` accepts
  `Duration(days: 45)` — a window nothing in the product offers, and therefore a value no
  screen can render. **There is no "keep everything"**: it would be a way to promise
  something the app cannot back.

### THE FINDING, and the code it changed

**drift stores a `DateTime` as epoch seconds** — `millisecondsSinceEpoch ~/ 1000`,
read in the installed drift 2.35.1 at
`lib/src/runtime/types/mapping.dart`. I derived `history_entries.id` from
`openedAt.microsecondsSinceEpoch`, and the test *two openings in the same millisecond
are still two rows* failed with `UNIQUE constraint failed: history_entries.id`.

The failure was **right and the code was wrong**: a distinction the column discards two
lines later cannot be made in the id either. So:

- `_entryId` now hashes `chapterId` and `millisecondsSinceEpoch ~/ 1000` — **the same
  expression drift applies on the way in**, with a comment saying so.
- The guarantee is stated at the resolution that exists: two openings **a second or more
  apart** are two rows. Two opens of the same chapter inside one second are
  indistinguishable **in this schema**, and that is written down rather than asserted
  away. It is not a gesture a reader makes — the minimum is a tap, a load and a scroll.
- A row pins the property directly: the id is the same for two instants inside one stored
  second and different across a boundary. Finer than the column is what collided;
  coarser would merge readings a day apart.

### REJECTED

- **Making the id finer** — a monotonic counter, or `DateTime.now().microsecond` at the
  repository. Both make the id depend on something the schema does not hold, so the row
  and the id disagree on disk. Same defect, invisible.
- **A `rowid`-based id.** `history_entries.id` is a `TextColumn` primary key, and
  changing that is a schema migration for a problem that a one-line derivation solves.
- **Reflexivity for "no clock".** `dart:mirrors` is unavailable on this platform, so the
  B46 rows assert **behaviour** (positions survive a clear; a resume point exists with an
  empty journal) rather than enumerating fields. The behaviour is the stronger claim: a
  field nobody renders is harmless, and a clear that moves the reader is not.

### BLOCKED

- **The `/history` screen itself is not built.** This slice delivered the domain contract,
  the retention model, the grouping and the drift repository — 43 rows. The UI, the
  confirm sheet and `SettingsChoiceSheet` wiring are not here, and `3-7` (Settings) needs
  the retention store, which is **also not here**. `6-5` stays `in_progress` rather than
  being called done.

### FILES TOUCHED

`lib/domain/history/{history_entry,history_retention,history_repository,history_grouping}.dart`,
`lib/data/history/drift_history_repository.dart`,
`test/domain/history/history_test.dart` (24),
`test/data/history/drift_history_repository_test.dart` (19).

### STATUS

`dart format` clean · `analyze --fatal-infos` **zero** · host **594 passed + 9 skipped**
· `forge-guard all` **pass** · `consistency-check all` **pass** · `coverage-check 6-5`
**pass**.

**Sabotage, all three, on both sides.** Each of these would pass every other test in the
project:

| Sabotage | Rows that caught it |
|---|---|
| `clearAll` also deletes positions | **2 fail** — *positions untouched*, *resume points identical after a clear* |
| `readResumePoints` joins `history_entries` | **3 fail** — including *a resume point exists with no journal entry at all* |
| `LIMIT 50` added to the journal read | **1 fail** — *there is no count bound anywhere in the query* (200 entries, all returned) |

### NEXT SESSION SHOULD

- **Finish `6-5`**: the `HistoryRetentionStore` over `shared_preferences` (the plan's § 2.2
  names `countOlderThan` as a *pre-purge* count — after a purge it is always zero, true
  about the past and useless about the decision), then the `/history` screen and the
  retention sheet. `3-7` cannot start until the store exists.
- **`3-5`** (About) — needs three counts; `reading_positions` exists from `2-6`.
- **`2-1`'s source, against Royal Road**, now that `supportsSearch` is measured and its
  search side has an empty marker.

### NEXT SESSION SHOULD NOT

- **Do not derive an id from a resolution finer than the column that stores it.** drift's
  `DateTime` is epoch **seconds**, and the symptom is a UNIQUE-constraint failure on a
  routine action rather than a wrong-looking row.
- **Do not assert at a resolution the database does not deliver.** State the guarantee at
  the one that exists and write down the limit.

---

## 2026-10-03 — Session 14 (same session, continued): the retention store, and a count that has to run before a purge

### STARTED FROM

`6-5` committed at `3b763e3` with the domain and the drift repository in place and the
slice honestly `in_progress`. What was missing was `HistoryRetentionStore` — and **`3-7`
cannot start without it**, because Settings' *Keep history for* row reads the same value.

### DECIDED

- **The count is strictly-before, and the purge is strictly-before, and a row asserts
  they agree.** If the count were `<=` and the purge `<`, a reader would read a notice
  saying *"three entries will be dropped"* and watch two vanish — told a falsehood by the
  one number on the screen that is supposed to be honest. The row takes the count,
  purges, and asserts `purged == announced`.
- **The predicate is built by drift's builder, not written as SQL text.** The first
  version interpolated `'${exclusive ? '<' : '<='}'` into a `customSelect` and carried a
  comment saying it mirrored `purgeOlderThan`. That is **two statements of one rule, one
  of them a string**, and no test can compare them without parsing SQL. Now the expression
  *is* the statement: `purgeOlderThan` uses `isSmallerThanValue` and so does this.
- **The store takes a `HistoryOlderThanCounter` function, not a repository.** A bare
  function parameter is a shape everything satisfies and nothing documents; a named
  `typedef` carries the rule *strictly before the cutoff* in its own name. And
  `HistoryRepository` does **not** gain a count method — it would put a *"how many"* onto
  an interface whose other methods are "give me" or "delete", and every implementation
  would then have to answer a question the **screen** is asking.
- **`SettingsPersistenceException` is NOT an `AppException`.** The AppException hierarchy
  is for failures the UI maps to a message *by cause* (B22), and this cause is "the OS
  declined to write a byte" — a different kind of thing. Merging them would make
  `13-error-handling.md` rule 5's mapping carry a case it has no sentence for.
- **`row.read(count) ?? 0`.** `COUNT(*)` is never NULL, but drift types the read as `int?`
  because it cannot know which expressions are non-nullable. A nullable count makes
  *"how many will be dropped?"* a **screen's decision** — the screen would have to decide
  whether `null` means zero, unknown, or "show nothing", and those give three different
  notices. B48's argument, verbatim, and it is the same one.

### BLOCKED — still, and it is the same blocker

- **The `/history` screen is not built.** `history.md` § 4 specifies nine states, three
  with a second rendering: loading (eight `NovelRow` skeletons, **no cover** — this variant
  has none), empty-never-visited (whose action depends on a **local fact** — *Browse a
  source* when the library is empty, *Open your library* when it is not), empty-no-data
  **split in two** because "cleared by the reader" and "aged out" are different events
  with different emotional weight, and a load error that must name **three survivals by
  name** because the fear is data loss and there is no backup (ADR-010).
- **Its copy does not exist yet**, so this is not just a widget job: ~20 keys × 2
  languages. **`6-5` stays `in_progress`.**

### FILES TOUCHED

`lib/data/history/shared_prefs_history_retention.dart` (new),
`test/data/history/shared_prefs_history_retention_test.dart` (10).

### STATUS

`dart format` clean · `analyze --fatal-infos` **zero** · host **604 passed + 9 skipped**
· `forge-guard all` **pass** · `consistency-check all` **pass**.

**Sabotage, all three, on both sides:**

| Sabotage | Rows that caught it |
|---|---|
| count uses `<=` while the purge uses `<` | *an entry EXACTLY at the cutoff is not counted* **fails** |
| the write ignores a platform refusal | *a platform refusal throws rather than pretending* **fails** |
| a read creates the key | **2 rows fail** — *creates nothing*, *round-trips through its name* |

### NEXT SESSION SHOULD

- **The `/history` screen**, copy first: the nine states in `history.md` § 4, then
  `SettingsChoiceSheet` (§ 2.12, shared, owned here because its rows *are* the
  `HistoryRetention` values), `BoundNotice`, `DayGroupHeader`, and the confirm dialog
  whose body is B46 in one sentence. `3-7` imports that sheet with the **same enum** —
  the dependency edge is `3-7 → 6-5`, and a local `RetentionSheet` with its own five
  values would produce two rebirths of the same component.
- **`3-5`** (About), then **`3-7`** (Settings).
- **`2-1`'s source, against Royal Road.**

### NEXT SESSION SHOULD NOT

- **Do not write the announcement count and the purge as two statements.** They must be
  the same predicate; a test that compares them is what keeps them so.
- **Do not add a count method to `HistoryRepository`.** The question belongs to the screen.

---

## 2026-10-03 — Session 15 (same session, continued): the `/history` copy, and `SettingsChoiceSheet`

### STARTED FROM

`6-5` at `16545f7` with the retention store committed and the screen still missing.
The screen is not just a widget: `history.md` § 4 specifies **nine states, three with
a second rendering**, so the copy had to exist before any of it could be written.

### DECIDED

- **The ARB files are written by `tool/append_history_strings.py`, not by hand.** B28
  demands French *and* English for every user-visible string, and two hand edits can
  leave the files a key apart. One table, two files, cannot.
- **`SettingsChoiceSheet` is generic over `T`, and owns no list of windows.**
  `design-system.md` § 2.12 says *"a screen may not restate the list"*. A sheet
  written against `HistoryRetention` would be a **second statement of which five
  windows exist**, beside the enum — and a sixth window would then need three edits.
  The widget takes options + a `labelOf` + a `warningFor`; `6-5` supplies all three
  from the enum.
- **It is owned by `6-5`, not `3-7`.** Its rows ARE `HistoryRetention`'s values and its
  warning sentence comes from `countOlderThan`, both declared here. `3-7` imports it —
  the only direction the edge can take, since `3-7` already reads the enum and the
  store from `6-5`.
- **`on Object`, not `on Exception`.** `SettingsPersistenceException` is deliberately
  not an `AppException`, so a narrower clause lets the one failure this state exists
  for escape as an unhandled async error — on a modal sheet that is a **silent no-op**:
  the sheet sits there looking unchanged and the tap appears to have done nothing.
- **`onSelected` IS the write, not a notification.** § 11.1's *Submit error* keeps the
  sheet open on the **previous** window. A sheet that popped before the write and told
  the caller afterwards has already closed by the time the failure arrives.
- **There is no "pending" selection.** A tap commits; a commit lands or throws. A
  preview plus an *Apply* button would have a state where the reader has chosen
  something the app has not stored — C8's state, reached one step earlier.
- **`catch Object`, snap back, disclose.** B24 and C8: a refused write must not leave
  the reader looking at a window the app cannot honour.
- **The press feedback is gated, the tap is not.** A disabled row must not acknowledge
  a finger, and it must also not be *reachable* — so the tap is wired unconditionally
  and the refusal lives in one place, `_choose`, which is the state machine's rule
  rather than the row's presentation. Gating `onTap` made the row a **second** place
  deciding "may this be chosen", free to disagree with the first.
- **Arrow keys walk past a disabled row, in the direction of travel.** Falling back to
  "the first enabled row" jumps *backwards*, so ↓ onto a disabled row moves focus up
  the list — and on the row where it matters it lands where it started, so the key
  appears to do nothing.

### REJECTED

- **`Material.elevation` for the sheet shadow.** § 1.4 keeps exactly two shadows with
  fixed values; an elevation would pick its own and there would be a third nobody
  approved. The shadow is `LumenShadows.of(context).sheet` on a `DecoratedBox`.
- **A row-per-window list inside the widget.** See DECIDED.

### FILES TOUCHED

`lib/l10n/app_en.arb`, `lib/l10n/app_fr.arb` (+34 keys each),
`tool/append_history_strings.py` (new),
`lib/core/ui/settings_choice_sheet.dart` (new),
`test/l10n/history_strings_test.dart` (new, 22),
`test/core/ui/settings_choice_sheet_test.dart` (new, 23).

### STATUS

`dart format` clean · `analyze --fatal-infos` **zero** · host **649 passed + 9 skipped**
· `forge-guard all` **pass** · `consistency-check all` **pass**.

**Sabotage, six, all caught:**

| Sabotage | Rows that caught it |
|---|---|
| the checkmark moves **before** the write (C8) | *does NOT move while the write is in flight* |
| `on Exception` instead of `on Object` | **6 rows fail** — the whole *submit error* group |
| arrow keys track the committed row, not the focused one | *move focus and wrap at both ends* |
| a disabled row is still selectable | *a disabled row cannot be selected* |
| arrow keys fall back to the first enabled row | *walk PAST a disabled row* |
| a failed write keeps the new value and hides the error | **4 rows fail** |

### NEXT SESSION SHOULD

- **`HistoryScreen` itself** — the nine states of `history.md` § 4, plus the
  `BoundNotice`, `DayGroupHeader` and the `NovelRow` `history` variant (no cover),
  plus the router entry replacing `PlaceholderScreen` on the history branch. Its
  providers go in `features/history/`.
- **`3-5`** (About) and **`3-7`** (Settings, which imports the sheet).
- **`2-1`'s source**, against Royal Road.

### NEXT SESSION SHOULD NOT

- **Do not add a window name to `SettingsChoiceSheet`.** It holds no list, and a row
  asserts the enum and the table have the same five members.
- **Do not gate `onTap` on the row.** One place refuses a choice, and it is the state
  machine.

---

## 2026-10-03 — Session 16 (same session, continued): the `/history` screen, and a registry so `app/` need not import a feature

### STARTED FROM

`6-5` at `8948808` with the copy and the sheet committed. The screen itself needed nine
states, three widgets, and — the part that turned out to be the interesting one — a way
for the router to mount a feature screen **without `app/` importing a feature**.

### DECIDED

- **`app/router/screen_registry.dart`, and the router looks screens up instead of
  importing them.** `architecture.md` § 3.1a says *"`app/` imports no `features/` code
  beyond the shell"*, and the same section says *"a screen is a route and a route is a
  row in this table"* — a screen slice has to be able to fill its own row. Those two
  statements cannot both be satisfied by an import, and the grep row
  (`app/ must not import a feature`) fired on the first attempt. The registry is the
  way out: `app/` owns the lookup, `main.dart` registers, neither imports the other.
  **An unregistered destination renders a `PlaceholderScreen`, never throws** — a `!`
  on the lookup would crash the app on launch in a way that reads as a provider bug.
- **`appHistoryRetentionProvider` is COMPOSED, not a bootstrap override.** Overriding
  it would mean `main.dart` had to build the store's counting function, which needs the
  `AppDatabase` — and the db is created *by* the override that would supply it. A
  bootstrap that has to order two overrides against each other is a bootstrap with a
  cycle in it. `sharedPreferencesProvider` is a new `core/storage` provider so the
  theme and the retention store share **one** instance over one file.
- **`appDatabaseProvider` uses `overrideWith` + `ref.onDispose`, not
  `overrideWithValue`.** A process-scoped singleton should shut its handle; a database
  holding the library, the positions and the journal (B7) is exactly that.
- **`HistoryRepository` GAINED `countAll()` — reversing this session's earlier
  decision.** The reason it did not belong is now visible: the clear dialog says *"your
  N entries will be removed"*, and `clearAll` removes every row. A count that honoured
  the retention window would tell a reader with ten recent chapters that **nothing** is
  about to be deleted, and then delete all ten. `purgeOlderThan` and `clearAll` already
  return counts, so a count is not a foreign shape on this interface — it is the same
  question asked *before* acting instead of after. The earlier objection ("a 'how many'
  onto an interface whose methods are give me or delete") was wrong: two of the four
  methods were already "how many did you delete".
- **The empty state's three-way split, and the discriminator for each.**
  - **aged out** ⟸ `agedOutCount > 0` — a statement about the journal itself.
  - **never visited** ⟸ **the library is empty**. A chapter can only be opened from a
    novel that is in the library, so an empty library is a sound basis for "you have not
    read anything yet" — and it is the same local fact `history.md` § 4 already uses to
    pick the empty action.
  - **cleared** ⟸ everything else: an empty journal with novels in it.
  Checked in that order, because the last two are inferences from the library rather
  than statements about the journal.
- **`drift_library_entry_count.dart` is a temporary, and says so.** `6-3` owns the
  library and has not landed; rather than leave two of the four empty-state strings
  unreachable — dead ARB keys are a defect, and an unimplemented branch of § 4 is worse
  — this counts the one column the question needs. Its header says it will be deleted
  when `6-3` lands.
- **Relative time has THREE buckets and no fourth.** *just now* · *N minutes* · *N
  hours* · then **nothing**. Past local midnight the day header already carries the
  date. The cut is `isSameLocalDay`, **not `inHours < 24`** — a `Duration` cut would
  put *"23 hours ago"* under a header reading *Yesterday*, which is yesterday's row
  quoting a number from today. A negative duration (phone clock behind the last write)
  clamps to *just now*: *"opened in -4 minutes"* is a sentence no reader can act on.
- **The row's press feedback is gated, its tap is not.** A disabled row must not
  acknowledge a finger **and** must not be reachable, so the tap is wired
  unconditionally and the refusal lives in `_choose` — one place, not two that can
  disagree.
- **Cancel is the dialog's FIRST action, and a row reads the ORDER.** Both buttons
  present is not the requirement; on a hardware keyboard `Enter` takes the first, and a
  destructive first action empties a reader's log on a stray keypress.
- **The list is one flat `ListView.builder` over a pre-flattened sequence**, not a
  `ListView` per day group: nested lists would give every group its own scroll physics
  and its own lazy boundary.

### REJECTED

- **`SettingsChoiceSheet.show` as a static on the class.** `SettingsChoiceSheet<T>.show(…)`
  parses as a **named constructor** in Dart — `Type.name(…)` is always a constructor —
  so the analyzer said *"doesn't have a constructor named show"* while the call site said
  exactly what it meant. It is a top-level `showSettingsChoiceSheet<T>` now.
- **A clock time on the row** (`DateFormat.Hm()`), in favour of a relative time: it says
  "23:47" for an entry opened *yesterday* at 23:47 and never updates, so a row that said
  "just now" at breakfast is lying by lunchtime.
- **`Material.elevation` for the sheet shadow.** § 1.4 keeps exactly two shadows with
  fixed values.

### FILES TOUCHED

`lib/app/router/screen_registry.dart` (new), `lib/app/router/app_router.dart`,
`lib/core/storage/shared_preferences_provider.dart` (new),
`lib/core/ui/settings_choice_sheet.dart`, `lib/data/library/drift_library_entry_count.dart`
(new), `lib/data/history/drift_history_repository.dart`,
`lib/domain/history/history_repository.dart`, `lib/features/history/**` (new, 5),
`lib/main.dart`, both ARB files (+6 keys each),
`test/features/history/**` (new, 47).

### STATUS

`dart format` clean · `analyze --fatal-infos` **zero** · host **683 passed + 9 skipped**
· `forge-guard all` **pass** · `consistency-check all` **pass**.

**Sabotage, seven:**

| Sabotage | Rows that caught it |
|---|---|
| `clearAll` also deletes `reading_positions` | B46 row (and a compile-time block on the journal's neighbour) |
| `countAll` honours the retention window | **2 rows fail** — the count and the full sentence |
| `clearAll` becomes `purgeOlderThan(now)` | *leaves every reading position intact* |
| empty state collapses never-visited into cleared | **2 rows fail** |
| the destructive button is the first action | *Cancel is the FIRST action* |
| `skipWidgets` skeleton `FractionallySizedBox` with infinite width | 18 rows — a layout throw, not a silent pass |
| the sheet's catch clause narrowed to `Exception` | 6 rows (earlier commit) |

Two sabotages **did not** fail on the first attempt and produced test gaps, not false
alarms, and both were fixed by writing the row rather than by weakening the claim:
`countAll` with a window (the first attempt filtered on `now` rather than the cutoff, so
the fixture still counted), and Cancel's order (no row existed).

### NEXT SESSION SHOULD

- **`3-5` (About)** and **`3-7` (Settings)** — `3-7` imports the sheet and the enum,
  and now has everything it needs.
- **`2-1`'s source**, against Royal Road: `div.fiction-list-item.row`, `?page=N` 1-based,
  the unpaginated chapter table, `chapter-inner chapter-content`.
- **`3-7`'s `SharedPrefsThemePreferences`** has a sibling now — check whether
  `appThemePreferencesProvider` should be composed from `sharedPreferencesProvider` the
  same way `appHistoryRetentionProvider` is, so the prefs interface has one place.

### NEXT SESSION SHOULD NOT

- **Do not import a feature from `app/`.** Use `screen_registry.dart`; the grep row
  fires on the first attempt otherwise.
- **Do not put a window on `countAll`.** The dialog's number must be the set
  `clearAll` touches, and a row asserts it.
- **Do not add a fourth time bucket to the row.** The header carries the date; the
  absence past local midnight is the design, not a gap.

---

## 2026-10-03 — Session 17 (same session, continued): `3-5` About, B31's three figures, and B43's version

### STARTED FROM

`6-5` complete at `4e05c9f`. `3-5` was the next unblocked leaf: three counts, a version
line, and `settings-about.md`'s nine states.

### DECIDED

- **The registry is keyed by PATH, not by destination.** The first version keyed by
  `AppNavDestination`, which covers the five branch roots and nothing else — and
  `/more/settings/about` is a **sub-route** with no destination, so `3-5` could not
  register it. A branch root is now just the route whose path happens to be a branch, so
  one table serves both call sites.
- **The version comes from Flutter's build-time Dart defines, and the app adds no
  dependency to read it.** `FLUTTER_BUILD_NAME` / `FLUTTER_BUILD_NUMBER` are what
  `flutter build` passes for exactly this; `package_info_plus` would only re-derive them.
- **`BuildVersion` is a nullable pair, not a formatted string.** Formatting first turns
  "missing" into `"0.9.0 · build "`, a version that looks complete and is not —
  `settings-about.md` § 4 forbids `Version —` by name, because an em dash *looks like*
  a version and C9 requires the installed version to be determinable.
- **Half a version counts as unreadable.** A name with no build number identifies a
  release line, not a build. C9 asks *which version*.
- **A missing version blanks NOTHING.** E11 and B31's guarantee are the two most
  important sentences on the screen and neither depends on a build number, so the error
  is scoped *in the rendering* rather than as a second screen.
- **Three separate count queries, and the failure shape is the reason** — not the
  performance. One `SELECT` with three sub-selects would be cheaper and would make the
  three figures one answer: one slow query would put all three in `loading`, and one
  failure would blank all three. A reader who cannot see their position count must
  still see their library count.
- **A count that could not be computed is a DASH; a count of zero is a zero.** That
  distinction is the entire reason the block exists: a reader who took "you have none"
  for "we could not look" would re-download a library she still has.
- **`countKnownChapters` counts EVERY known chapter, not only downloaded ones, and says
  so in its header.** A `downloaded` flag does not exist yet — `8-1` owns it — and the
  ARB label cannot carry a caveat. The header states the set and states that `8-1` must
  change it, because a count of `chapters` afterwards would over-report every novel the
  reader has merely *seen*.
- **`data/library/local_counts.dart`, not `drift_library_entry_count.dart`.** The About
  screen needed the same "how many novels" the History screen needed, so there is now one
  function in `data/` — where the table's shape is known — and both call it. Two
  queries that could disagree about the same figure was the defect the file name
  `local_counts` removes.
- **The overline carries `header: true` AND an explicit `label`.** The flag alone leaves
  `properties.label` `null`, so anything reading the tree sees a heading with no name.
  Same shape `DayGroupHeader` uses, for the same reason.
- **`arb_completeness_test` gained ONE named exemption, with a reason.** `'nothing here'`
  is a heuristic for "claims a list is empty", and E11's sentence opens with the same
  three words while claiming that nothing here is *backed up*. Narrowing the phrase would
  weaken the rule for every future key; rewording would diverge `settings-about.md` § 4.1
  from the ARB on the one sentence the screen exists to state.
- **`UpdateBlock` is gone, and so are eighteen ARB keys the design still lists.** § 4bis
  removed the version check from v1: no success criterion requires it, `apk-pipeline`
  already delivers builds, and it is the one control on this screen that could reach a
  server by itself — which makes every future addition a place to be careless about B29.
  What survives is the version line and B31's guarantee sentence, and both are here. Dead
  copy is a defect.

### FILES TOUCHED

`lib/app/theme/app_version.dart` (new), `lib/features/about/**` (new, 3),
`lib/data/library/local_counts.dart` (new, replacing `drift_library_entry_count.dart`),
`lib/app/router/screen_registry.dart`, `lib/app/router/app_router.dart`,
`lib/features/history/history_providers.dart`, `lib/main.dart`, both ARB files
(+23 keys each), `tool/append_about_strings.py` (new),
`test/features/about/about_screen_test.dart` (new, 18),
`test/l10n/arb_completeness_test.dart`.

### STATUS

`dart format` clean · `analyze --fatal-infos` **zero** · host **701 passed + 9 skipped**
· `forge-guard all` **pass** · `consistency-check all` **pass**.

**Sabotage, six, all caught:**

| Sabotage | Rows that caught it |
|---|---|
| a missing version renders as `0.9.0 · build ` | **2 rows** |
| the privacy block and delivery sentence are removed | **3 rows** |
| half a version counts as readable | *half a version counts as unreadable* |
| a failed count renders as `0` | *a DASH, not a zero* |
| the positions count IS the library count | *one provider failing does not blank the other two* |
| the counts become tappable | *the counts are NOT interactive* |

Three sabotages did **not** fail on the first attempt and produced test gaps rather than
false alarms: a blanked "rest of the page" row that stopped at the data block and passed
a screen which had lost its privacy statement; a row whose injected `AboutCounts` never
exercised the providers; and an `isReadable` that treated half a version as whole.

### NEXT SESSION SHOULD

- **`3-7` Settings** — the last unblocked Wave-2 leaf. It imports `SettingsChoiceSheet`
  and `HistoryRetention`, and everything it needs now exists.
- **`2-1`'s source**, against Royal Road: `div.fiction-list-item.row`, `?page=N` 1-based,
  the unpaginated chapter table, `chapter-inner chapter-content`.
- **Consider composing `appThemePreferencesProvider` from `sharedPreferencesProvider`**,
  the way `appHistoryRetentionProvider` now is, so the preferences interface has one
  place instead of two.

### NEXT SESSION SHOULD NOT

- **Do not add a `downloaded` column** to make `aboutDownloadedCountProvider` honest.
  `8-1` owns it, and the function's header says the change is not mechanical.
- **Do not reach for `package_info_plus`.** The build-time defines are what ADR-011
  already uses.
- **Do not key the screen registry by anything but an `AppRoutes` path.** A relative
  `'about'` registers under a key nothing looks up, and the screen reports itself
  registered while rendering a placeholder.

---

## 2026-10-04 — Session 18: `3-7` Settings, and the two strings § 4.1 wants that must not exist

### STARTED FROM

`3-5` complete at `2685e7e`. `3-7` was the last unblocked Wave-2 leaf: seven rows, three
group labels, one disclosure block.

### DECIDED

- **`Check now` is NOT built, and the `LIBRARY` group goes with it.** `settings.md` § 4
  (Filled) names eight rows; this screen has seven. `Check now` is **B36's update check**
  (ADR-021), no `8-*` slice has built an update subsystem, no source reports a "last
  checked" instant, and there is nothing to count. A button that opens no check is the
  fake-control defect § 11 spends a table refusing — so the row goes, and **with it the
  group**, because § 3 is explicit that "an empty section label is worse than no section
  label". Finding **F-012**.
- **`retention.1w` … `retention.2y` are NOT declared.** § 4.1 lists them, unstruck, so
  § 4.1 wants them — and they are a **second spelling of the same five windows** `6-5`
  already owns as `historyWindowOneWeek` … `historyWindowTwoYears`, one of which spells
  "1 week" where `6-5` spells "one week". § 2.12 exists to stop exactly this: *"two
  lists of the same values in two places is two truths about how long history lasts, and
  nothing in a dependency graph or a design token would notice."* One set of strings has
  to lose and `settings.md`'s twin is the one that loses, because `§ 2.12` names **`6-5`**
  as the owner. Finding **F-013**.
- **`settingsLanguageEnglish` and `settingsLanguageFrench` are IDENTICAL in both files,
  and that is deliberate.** The row reports what the **phone** is set to, so an English
  UI with a French phone must read *Français*. A value that changed with the ARB would
  be the app naming the phone's language in the app's language, which is a different
  claim — and which a translator would helpfully localize into something wrong.
- **`Locale.languageName` does not exist, and `MaterialLocalizations` has no such
  getter** — checked in the installed SDK, not from memory. So the language name is a
  `switch` over the language code with an ARB pair behind it, and a `Map<Locale, …>`
  (the tempting version) is a **second source of truth** that would be free to disagree
  with the ARB.
- **The history count is `COUNT(*)` over the WHOLE table, not the window.** The row says
  *"{count} entries"* and the danger row below it deletes the whole journal, so the count
  has to be the set `clearAll` touches. A count inside the window would report 0 for a
  reader with a full history and the dialog would ask consent to deleting 1,200 entries
  while saying *nothing will be removed*.
- **The danger row is disabled when the count is zero AND when it could not be obtained.**
  § 4 (Empty — no data) applies the same rendering to both, and says why: a dialog
  asking the reader to confirm destroying zero entries is theatre, and a dialog that
  cannot state how much is about to be destroyed cannot state the one thing it exists to
  state. `onTap: null` when disabled — not a handler that declines.
- **The count is in the dialog's TITLE.** A title is what a reader reads before anything
  else, and stating how much is that dialog's one job.
- **`Cancel` is the first action**, for the same reason as `6-5`: on a hardware keyboard
  `Enter` takes the first.
- **The `Language` row is read-only by ABSENCE**, § 4 (Read-only): no chevron, no ripple,
  no greying. A greyed row reads as a control the app has not finished, which is exactly
  the affordance that makes a broken source look empty.
- **`HistorySummary.oldestLabel` is a localized STRING, not a `DateTime`.** The row's
  sentence needs a phrase, and the alternative hands the phrase to the row — so the first
  second screen wanting it produces two. The cost is `_summaryLocale`, module-level
  mutable state, and the file says so: a provider cannot read a `BuildContext`, and the
  honest alternative is a `Provider.family` that rebuilds a whole summary because one
  *word* changed.
- **`appearanceLabel` and `pointSizeOf` are their own file.** The row joins three facts
  and the third — the point size a step *is* — belongs to `settings-reader.md`'s ladder,
  not to this screen. A screen repeating the table would be a second place that knows
  what "Medium" means.

### The time-dependence that bit twice, and the seam that fixed it

A widget row asserting `3 hours ago` **passes at 14:00 and fails at 02:00 on the same
commit**, because `6-5`'s `relativeTimeLabel` deliberately renders **nothing** once the
entry belongs to an earlier local day — the day header carries the date. It failed twice:
once in `6-5`'s own screen test, then again in `3-7`'s.

The fix is not a weaker assertion. `HistoryScreen` gained an `openedAt` constructor
parameter — `null` in the app, a pinned instant in every test — so both ends of the
sentence are fixed and the row can assert the phrase at any hour. The phrases were always
pinnable; they are pinned where `now` is an *argument*, in
`history_time_labels_test.dart`. **A row that pins a time-dependent string is not a
weaker row, it is a row that fails on a schedule.**

### FILES TOUCHED

`lib/features/settings/**` (new, 5), `lib/app/theme/app_version.dart` (unchanged),
`lib/domain/history/history_repository.dart` (`oldestEntryAt`),
`lib/data/history/drift_history_repository.dart`, both ARB files (+26 keys each),
`tool/append_settings_strings.py` (new), `lib/main.dart` (registers the route),
`test/features/settings/settings_screen_test.dart` (new, 25).

### STATUS

`dart format` clean · `analyze --fatal-infos` **zero** · host **726 passed + 9 skipped**
· `forge-guard all` **pass** · `consistency-check all` **pass`.

**Sabotage, six, all caught:**

| Sabotage | Rows that caught it |
|---|---|
| a failed count renders as a dash instead of `Count unavailable` | **2 rows** |
| the danger row is enabled with no count | **2 rows** |
| the read-only row gains a chevron | *it carries NO chevron and NO ripple* |
| the language value follows the ARB instead of the phone | **2 rows** |
| the dialog title's count is hard-coded | *its TITLE states the count* |
| `Cancel` moves behind the destructive action | *Cancel is the first action* |

Two sabotages exposed real test gaps, both fixed by writing the row rather than by
weakening the claim: the chevron was guarded by a per-row `findsNothing` and a positive
`findsWidgets`, and **neither could see an extra chevron** — `find.descendant(of: an
InkWell, …)` returned nothing even with the chevron present. It is a **count** now, and
the count names the five rows it expects. And the dialog's copy was asserted through a
**stubbed** `SettingsNavigation`, which is right for wording rows and wrong for the
number; three rows now drive the real provider.

### NEXT SESSION SHOULD

- **`2-1`'s source**, against Royal Road: `div.fiction-list-item.row`, `?page=N` 1-based,
  the unpaginated chapter table, `chapter-inner chapter-content`. This is the last
  unblocked Wave-2 item and it is the product's whole premise.
- **`3-6` (Settings → Reader)**, the appearance screen `3-7`'s first row points at. It is
  currently a placeholder, and the row prints values it owns correctly.
- **`8-*` for the update check**, which is what unblocks `Check now` and the `LIBRARY`
  group (F-012).

### NEXT SESSION SHOULD NOT

- **Do not re-declare `retention.1w`.** `6-5` owns the five names; § 2.12 names it as the
  owner and a twin is the defect the section exists to prevent (F-013).
- **Do not localize `settingsLanguageEnglish` / `settingsLanguageFrench`.** They are
  identical in both files on purpose: the row reports the *phone's* language.
- **Do not pin a time-dependent string in a widget row.** Pin `openedAt`.

---

## 2026-10-04 — Session 19: `2-1` — Royal Road, and the order the site actually publishes

### STARTED FROM

`3-7` at `7885f75`, with `50ee274` having recorded the catalogue row's anatomy from the
frozen fixtures. `2-1` is the product's premise and the last unblocked Wave-2 item.

### DECIDED

- **`lib/domain/sources/http_fetching.dart` is a MIXIN, and `2-1` writes no
  `HttpSource`.** `source.dart` already declares `HttpSource` as an abstract **class**,
  so `class RoyalRoadSource extends HttpSource` would work today and break the moment a
  source needed a second base. `Source` and `HttpSource` are both abstract classes and
  Dart has no multiple inheritance.
- **`ReadPipeline` makes the four steps of a read one call.** fetch → probe → attempt →
  classify. A source that branched on `rows.isEmpty` before classifying would have
  re-implemented B22 in a place with no tests, so the class removes the opportunity.
- **`requestPath` carries no query string.** A failure line is something an owner reads,
  and a reader's search term inside one is a small leak (C5).
- **The catalogue probe is the CONTAINER, not the rows.** This site publishes **no**
  empty marker on the browse side, so page shape is the only discriminator available:
  "container present" means intact, "container absent" means the layout moved.
- **An empty-but-intact catalogue is reported as `SourceLayoutChanged`, and that is
  recorded rather than worked around.** With no site-supplied signal,
  `ZeroItemsPolicy.zeroIsBroken` means an empty catalogue *cannot* be reported as "no
  results". B22 says the discriminator is the site's own signal; this site publishes
  none, so the honest answer is "we could not read it", and inventing a marker would make
  every empty catalogue indistinguishable from a successful one.
- **The B9 witness is CHECKED, not read.** `table#chapters[data-chapters="716"]` carries
  exactly 716 rows on the capture. A mismatch is reported as `SourceLayoutChanged` —
  **never padded and never trimmed**, because padding would invent chapters and a short
  list returned as the whole one is B9 broken with no error anywhere.
- **`NovelUpdate.chapters` is the WHOLE list the site publishes**, not only the
  additions: the field is the novel's chapters and the screen diffs them. Passing only
  the additions would make every chapter look new on every check, which trains a reader
  to ignore the update screen.
- **`fetchChapterContent` returns the container's `innerHtml` and stops** — no cleaning,
  no thresholds, no joining beyond the site's own order (`03-source-system.md` rule 11).
  A present-but-empty container is **not** a failure: the container IS the element being
  looked for, and inventing a failure for it would be the app overruling the site.
- **FanMTL and Novel Fire are NOT in the registry.** FanMTL answers 403 with a Cloudflare
  challenge (ADR-014 rejected impersonation; no bypass will be built), and Novel Fire is
  **UNMEASURED**, not `false`. Registering either would put a tab on the reader's screen
  that reports every read as broken, or claim a measurement nobody took.

### THE FINDING THAT WAS NOT EXPECTED

**Royal Road's chapter table is ordered by PUBLICATION, not by number.** The Runesmith
capture's first three numbers are `526587`, `568159`, `520102` — measured, and **not
ascending**. This surfaced because a row asserting ascending numbers **failed**, which is
the only reason it is worth recording.

A source that sorted by number, or renumbered rows `1, 2, 3…`, would produce an order the
site never published — and **every chapter would still be present**, so nothing would look
wrong. The capture's first row is also a glossary (`data-content="0"`), so renumbering
would silently claim the glossary is chapter 1.

The row now asserts the three numbers exactly **and** that they are not ascending, so a
change in the site's order fails a test that says so. Promoted to
`18-external-contracts.md` with the cross-site rule: *a chapter list is the site's order,
and the site may order it by something other than the number in the URL.*

### FILES TOUCHED

`lib/domain/sources/http_fetching.dart` (new), `lib/domain/sources/read_pipeline.dart`
(new), `lib/sources/implementations/royal_road_source.dart` (new),
`lib/sources/implementations/source_registry.dart` (new),
`lib/data/sources/source_manager.dart` (new),
`test/sources/royal_road_source_test.dart` (new, 26),
`.opencode/rules/18-external-contracts.md` (+2 sections).

### STATUS

`dart format` clean · `analyze --fatal-infos` **zero** · host **752 passed + 9 skipped**
· `forge-guard all` **pass** · `consistency-check all` **pass**.

**Sabotage, seven, all caught:**

| Sabotage | Rows that caught it |
|---|---|
| the author selector uses `/author/` — the shape every other site uses | *the author is under `/profile/`* |
| the catalogue row invents an author from the title | *the row carries NO author, and none is invented* |
| the rating is read from the `fa-star` span's **text**, which is empty | *the rating comes from the title attribute* |
| the chapter-body selector is an exact `class="chapter-content"` match | **2 rows** |
| the published chapter count is not read at all | *a truncated table is reported* |
| a short chapter table is returned as the whole one | *a truncated table is reported* |
| chapters are renumbered `1..n` | *the order is the TABLE order, and it is NOT ascending* |

### STILL NOT DONE IN `2-1`

- **No live verification.** Every row runs against the frozen captures; the selectors were
  never re-fetched. The network answers 200 today, and confirming the selectors still
  match is a `18-external-contracts.md` re-measurement, not something the tests can do.
- **The registry is not wired to a provider**, so the Browse tab still has no source
  behind it. That is `3-1`, and `SourceManager` exists for it.
- **No genre browsing**, because this source declares an empty `filterList` — Royal Road
  filters by tag through its own tag pages rather than through a filter list this contract
  carries.

### NEXT SESSION SHOULD

- **`2-2`** (library writes) — the first slice that stores anything, so `Novel.id`'s
  derivation becomes load-bearing rather than theoretical.
- **`3-1`** (Browse), which consumes `SourceManager` and makes the app read a novel.
- **Re-measure Royal Road's selectors live**, and record the result the way the two
  sections above are recorded.

### NEXT SESSION SHOULD NOT

- **Do not sort or renumber a chapter list.** The site orders by publication, and every
  chapter being present does not make the order right.
- **Do not register FanMTL or Novel Fire.** F-012 stands; Novel Fire is UNMEASURED.
- **Do not add a `downloaded` flag or an `author` fallback.** Both would be a second
  source of truth against a measurement that already exists.

---

## 2026-10-04 — Session 20: `2-2` — HTML to Markdown, and the paragraph the site asked for

### STARTED FROM

`2-1` at `e886ce8`. `2-2` is the product's central transformation and everything
downstream needs it.

### DECIDED

- **No `html2md`, no FFI bridge — the walk is written here** (ADR-003). Every published
  `html2md` declares `sdk: >=2.12.0 <3.0.0`, so Dart 2 alone, and a Rust toolchain for this
  step is a bad trade in a mobile reader. There is therefore **no base converter to wrap**,
  which is why `04-html-to-markdown.md` specifies an algorithm and not an adapter.
- **`<br><br>` is a paragraph, and the break is DEFERRED.** FanMTL emits zero `<p>`, so a
  converter asking "is this a `<p>`" sees none and emits the whole chapter as one
  paragraph — which *looks* right and fails structurally. `_pendingBreak` is 0/1/2 and is a
  **promise**, paid by `_emitText`, because § 3.2's table says a `<br>` followed by a `<br>`
  emits *nothing*: emitting the hard break eagerly and then upgrading it to a paragraph
  produced `Two  \n\nThree` — two visual separations where the site asked for one.
- **`paragraphCount` counts paragraphs as a reader SEES them, not tags in the source.**
  `<p>One</p>Two` is two paragraphs and one `<p>`; the site closed a block, so the text
  after it opens another. Without `_blockClosed` the output showed three paragraphs while
  the count said two — and the count is what E22's threshold reads.
- **The first run of text opens a paragraph.** A chapter that begins straight into prose
  with neither `<p>` nor `<br>` still has paragraphs. Every block marker — heading, inline
  emphasis, list item, `hr` — sets `_documentStarted`, because that marker's own text
  belongs to the *marker*, not to a first paragraph. Skipping that produced `###\n\nTitle`
  and `*\n\na`.
- **The walk is iterative over a stack that holds CLOSERS as well as nodes.** A recursive
  `_children` per container recurses once per *nesting level*; a step that closes a
  container costs one list slot instead of one call frame. E1 asks that a 10 000-entry
  list stay readable, and a row asserts it.
- **Removals are a UNION, never a replacement.** `kDefaultRemovals` first, then the
  source's own — so a source cannot re-introduce a `<script>` by omitting it, because
  omitting is not an operation `ConversionRequest` offers.
- **`parent is! dom.Element` in `_unwrap`, and it is load-bearing.** `querySelectorAll` is
  a live view, so an earlier rule may have removed an *ancestor*; inserting into the
  Document would re-parent a node **outside** the article and silently move prose out of
  the chapter. `package:html` has no `parentElement`, so this narrowing does the job.
- **A hard break is EXACTLY two trailing spaces.** Calling a space-writer first produced
  four, which a renderer reads as a hard break plus two spaces of content.
- **Images are dropped by default, and the default IS the rule** (rule 3). A non-zero
  `imagesKept` means a source asked; an unresolvable `src` is dropped and **not counted**,
  because an `![](…)` the reader also sees broken is worse than no image.
- **An irregular table becomes paragraphs separated by an EM DASH, not a pipe.** Rule 8:
  the shape is lost, the text never is. A pipe inside prose reads as a table row to every
  renderer, and this fallback is prose. Over 200 rows the fallback is unconditional.
- **Escaping is "only where it changes the sense".** A character is escaped only when
  adjacent to a non-space, because a chapter *about* Markdown must stay readable — a
  blanket escape turns "he said * * *" into punctuation the reader reads past.

### THE ROW THAT SAYS THE UNCOMFORTABLE THING OUT LOUD

`0-1`'s manufactured broken-layout fixture is a **catalogue** page: 109 `<p>` elements and
34 000 characters. Handed to the converter whole, it converts to a long, confident,
entirely wrong chapter — and the row asserts exactly that (`belowThreshold is false`).

So **the threshold cannot be what protects the product here**, and no converter can: given
a page full of prose it will faithfully convert the prose. What protects the reader is
`2-1`'s selector returning nothing, which the sibling row asserts. A converter that
"detected" the broken page would be guessing, and a guess that turns a long catalogue page
into a short chapter is the mirror image of SC-6.

### FILES TOUCHED

`lib/core/pipeline/html_to_markdown.dart` (new),
`lib/core/pipeline/removal_rule.dart` (new),
`lib/core/pipeline/converted_chapter.dart` (new),
`test/core/pipeline/html_to_markdown_test.dart` (new, 38),
`test/core/pipeline/real_fixture_conversion_test.dart` (new, 9).

### STATUS

`dart format` clean · `analyze --fatal-infos` **zero** · host **799 passed + 9 skipped**
· `forge-guard all` **pass** · `consistency-check all` **pass`.

**Sabotage, seven, all caught:**

| Sabotage | Rows that caught it |
|---|---|
| a paragraph only counts when the node is a `<p>` — the FanMTL defect | **2 rows** |
| the hard break is emitted eagerly instead of deferred | **2 rows** |
| the bullet marker ignores `frame.ordered` | *an unordered list, nested* |
| a source's removals **replace** the defaults | *script and style go with their subtree* |
| `javascript:` is rendered | *`javascript:` is NEVER rendered* |
| escaping becomes a blanket escape | *a lone asterisk between spaces stays readable* |
| an irregular table drops cells instead of keeping the text | **2 rows** |

### NEXT SESSION SHOULD

- **`2-3`** — the atomic disk write and `downloadedAt`. `2-2` returns a `String`; `2-3` is
  what puts it on disk, and its two-write order **is** B6 rather than an implementation
  detail (ADR-022).
- **`2-4`** — the reader, which is the product's proof.

### NEXT SESSION SHOULD NOT

- **Do not count tags instead of paragraphs.** `<p>One</p>Two` is two paragraphs.
- **Do not emit a hard break eagerly.** The `<br><br>` upgrade produces a double break.
- **Do not try to detect a broken layout in the converter.** The selector does that, and a
  guess turns a catalogue page into a short chapter.

---

## 2026-10-04 — Session 21: `2-3` — the atomic chapter write, and the order that IS B6

### STARTED FROM

`2-2` at `8daccfa`. `2-3` is what makes `2-4`'s offline reading possible: there is
nothing to read without a file.

### DECIDED

- **`ChapterStore` lives in `features/downloads/domain/`, and `ChapterMarker` is TWO
  CLOSURES rather than a database.** ADR-022's rule is about the *order* of two writes,
  so the test has to observe that order — and a test that needs an executor to check a
  call sequence has already lost the thing it was built to prove. The row does not assert
  "the file exists and the mark was set"; it asserts that **the file was already complete
  at the moment the marker was called.**
- **The file is written first and the mark second, and that direction is what makes B6
  expressible.** A crash between the two leaves a file **without** a mark, so the chapter
  offers itself for download again. The reverse leaves a mark without a file and the
  reader opens a chapter that is not there — and that state is **unreachable**, which is
  what lets B6 be stated at all.
- **The temporary file is in the SAME directory.** `rename()` is atomic only within one
  filesystem; a temporary elsewhere turns the rename into a copy, and a copy is not atomic,
  so a kill mid-copy leaves a half-written chapter the mark says is complete.
- **The filename is built from `ordinal` and never from `number`.** `number` is `-1` when
  unparseable and restarts per volume, so a filename from it collides across volumes: two
  chapters, one file, one silently replaced. § 3.3 records that this reordering "was
  already deleted once".
- **`mkdir` is recursive.** A `novelId` is an MD5 today and could nest after a change; a
  single-level `mkdir` fails on the first id containing a separator, and a row asserts it.
- **`ChapterStoreException` is NOT an `AppException`.** That hierarchy is for failures the
  UI maps to a message *by cause* (B22), and "the filesystem said no" is a cause the reader
  has no sentence for — `errorStorageFull` is `5-3`'s to classify, and it classifies this.
- **`ChapterStoreFailure` has three cases, and `temporaryFileMissing` is the interesting
  one.** "A write that reports success and produces no file" is B6's *misleading success*,
  and it gets its own case so the caller cannot go on to mark the chapter downloaded.
- **`deleteOne` never deletes the `chapters` row**, and the interface makes that
  impossible rather than the code merely doing it: `ChapterMarker` exposes `markDownloaded`
  and `clearDownloaded` and nothing else. B9 requires the list to stay complete whatever its
  length — a deleted row would lose a 10 000-chapter novel's list because one file went.

### THREE SABOTAGES THAT DID NOT FAIL, and what each one actually is

Recording these because "the tests caught it" is the claim, and in three cases the truth is
more useful than the claim:

- **No misleading-success check.** Removing `temp.existsSync()` changes nothing, because
  `writeAsString` either throws or creates the file. The branch guards a **platform that
  reports success without producing a file**, and this host is not that platform. There is
  no row that can cover it without a fake filesystem, and the honest statement is that it
  is a defence against an untestable platform behaviour — not a tested branch.
- **The temporary in another directory.** The rename still succeeds, because in this
  container both the support directory and the OS temp directory are under `/tmp` — one
  filesystem. **The atomicity property is a property of the filesystem, not of this code**,
  and no test here can distinguish the two. The row that *is* checkable is the one that
  asserts the same-directory path, and it exists.
- **The `deleteOne` sabotage only edited a comment.** That is my mistake in writing the
  sabotage, not a gap in the tests — and it is worth naming, because it means the fourth
  sabotage proved nothing at all.

### FILES TOUCHED

`lib/features/downloads/domain/chapter_store.dart` (new),
`lib/features/downloads/data/file_chapter_store.dart` (new),
`test/features/downloads/file_chapter_store_test.dart` (new, 16).

### STATUS

`dart format` clean · `analyze --fatal-infos` **zero** · host **815 passed + 9 skipped**
· `forge-guard all` **pass** · `consistency-check all` **pass`.

**Sabotage, four attempted — one caught, three recorded above:**

| Sabotage | Result |
|---|---|
| the mark is written **before** the file (ADR-022 reversed) | **2 rows fail** |
| the misleading-success check is removed | not observable on this host |
| the temporary lives in another directory | not observable — one filesystem here |
| `deleteOne` deletes the `chapters` row | the sabotage only edited a comment |

### NEXT SESSION SHOULD

- **`2-4`** — the reader. Three local facts decide the state (mark, file, connectivity), and
  the offline proof is the product's claim.
- **Wire `ChapterMarker` to drift** when the first reader or queue needs it; the interface
  exists so that wiring is one closure each way.

### NEXT SESSION SHOULD NOT

- **Do not swap the two writes.** The order is the rule, not a preference.
- **Do not put the temporary in another directory.** It is the difference between a rename
  and a copy, and a test here cannot see it.
- **Do not delete a `chapters` row.** B9 needs the list, whatever its length.
