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
- **Phase 5: 28 per-slice plans** from `templates/implementation-plan.md.tmpl`, via `forge-implementer`. Each slice's `path` already points at `.forge/plans/<key>.md` except `6-10`, which points at `.forge/plans/6-10.md` and has never existed.
- **`6-10` needs a rule-to-slice home.** ADR-021 gives it B37 and § 3.2 lists it under US-10, but it was added after the coverage matrix was written, so `coverage.md` has not counted it. Its `state.json` `path` is `.forge/architecture.md`, matching every other slice — the plan file itself is Phase 5's job.
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
