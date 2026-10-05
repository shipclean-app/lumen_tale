# LEARNINGS.md — Lumen Tale corrections

What the project has learned from **its own** mistakes. An entry says what was done wrong and **what to do next time** — not the workaround, so that a change in the world cannot silently make the entry false.

This file is the project's **only corrections store**. No "learnings" section in `SESSION_LOG.md`, no corrections smuggled into a rule file: two stores produce a stale "(none yet)" in one of them, and that is the half an agent is most likely to read.

## Format

**One line per correction**, in this order: the date, then **the contrast**, then the destination.

```markdown
- YYYY-MM-DD — <the fault, as a contrast: "don't X, the correct behaviour is Y">
  → domain: <target rule file> | Seen: <where it was noticed>
```

The **contrast** is the form, and it is not decorative. "There was a problem with dates" teaches nothing and goes stale without warning. "Don't compare a date to `now` — compare against the injectable clock, otherwise the test passes on the wrong day" stays true when the implementation changes.

`domain:` is the rule file this correction will be **promoted into**. A correction with no destination cannot be promoted and stays a journal entry.

`Seen:` is where it was noticed. Without it, an entry repeats the mistake three times before anyone admits it is a pattern.

## Corrections

<!-- Newest last. -->

- 2026-10-02 — Don't assert that a dependency, config file, or code path is present when you have only read the rule that mentions it: read `pubspec.yaml`, `pubspec.lock`, and the filesystem first. The rule set claimed `intl` was enabled, `l10n.yaml` was present, and `flutter_localizations` was wired into `main.dart`; none of the three existed, and `lib/` held the untouched Flutter counter demo.
  → domain: `08-coding-standards.md` | Seen: auditing the rule set against the repository, 2026-10-02

- 2026-10-02 — Don't adopt a package from a rule or a plan without checking its `environment.sdk` constraint against this project's Dart version. `html2md` declares `>=2.12.0 <3.0.0` on every published version, so it cannot resolve on Dart 3 at all, and it had been a declared stack item from the start.
  → domain: `08-coding-standards.md` | Seen: first `flutter pub add` run, 2026-10-02

- 2026-10-02 — Don't trust a registry API's deprecation flag over the resolver's own output: run the install and read the warning. The pub.dev API reported `isDiscontinued: false` for `flutter_markdown`, while `flutter pub get` reported it as discontinued and named its replacement; the persistent "1 package is discontinued" line was that package, and only the resolver identified it.
  → domain: `08-coding-standards.md` | Seen: scanning 141 locked packages against the API and finding nothing, then reading `flutter analyze`, 2026-10-02

- 2026-10-02 — Don't carry an API or option forward from another project's toolchain version: check it against the installed SDK or `--help` output. `synthetic-package` in `l10n.yaml` is a no-op in Flutter 3.47 and warns on every run; `useMaterial3: true` and `themeMode: ThemeMode.system` are now defaults and `avoid_redundant_argument_values` flags them.
  → domain: `16-i18n.md` | Seen: `flutter gen-l10n` and `flutter analyze`, 2026-10-02

- 2026-10-02 — Don't rely on `process.cwd()` to keep you anchored to the right project when a reference repository is on disk: pass the anchor explicitly. Forge's `state.js anchor` is documented to refuse a declared reference project, but run from inside the cloned Mihon checkout it resolved Mihon as the anchor with `reference_projects: []` — the guard reads only the candidate's own `state.json`, so it cannot see a reference declared by another project.
  → domain: `17-security.md` | Seen: `state.js anchor` run from `/tmp/opencode/mihon` after registering it via `--reference=`, 2026-10-02

- 2026-10-03 — Don't report a `-d`/`--device` flag as proof a test ran on a device: prove it with an assertion that can only pass in one place. `flutter test -d <id>` silently ignores the flag for files under `test/` — a *fabricated* device id returned `All tests passed!` after running the whole suite on the host, and I wrote that down as an on-device result before checking. Only a file under `integration_test/` is actually deployed, and there an unknown device fails loudly. First assertion in any device suite belongs to `Platform.isAndroid`.
  → domain: `10-testing.md` | Seen: reporting `flutter test -d YBZ2577ALDAC000899` as on-device, then re-running it with `TOTALLY_FAKE_DEVICE_12345` and getting the same green, 2026-10-03

- 2026-10-03 — Don't record an environmental limit in a decision register as though it were a property of the world: date it, attribute it, and say what would falsify it. Q-008 read *"Confirmed unresolvable from this environment, by the owner: you are on GitHub Codespaces so verification on a mobile device isn't possible"* — true of the Codespace, false of the machine, and sitting in the one file a future session reads to decide what is still unknown. A phone was connected the whole time.
  → domain: `12-ai-agent-workflow.md` | Seen: the owner connecting a phone and asking why the logs said a device test was impossible, 2026-10-03

- 2026-10-03 — Don't hardcode a machine-specific absolute path into a project tool: resolve it from `__file__` or an env var. `check_plans.py` had `ROOT = Path('/workspaces/lumen_tale')` and `FORGE = Path('/home/codespace/.agents/skills/forge')`, so the tool that `test-plan.md` §6 relies on to keep its counts *derived* died with `FileNotFoundError` on `.forge/state.json` — leaving hand-editing the counts as the only way to update them, which §6 names as this project's recurring defect.
  → domain: `11-git-workflow.md` | Seen: `python3 .forge/plans/check_plans.py --test-plan` on a machine that is not the Codespace, 2026-10-03

- 2026-10-02 — Don't trust a CLI's help text over its parser: check how the flag is actually parsed. Forge's `state.js --help` documents `--reference <p>` (space) while the parser only matches `--reference=<p>` (equals); the space form silently registers nothing, so the reference project is recorded as read-only-but-absent.
  → domain: `18-external-contracts.md` | Seen: `state.js init --reference /tmp/opencode/mihon` returning `reference_projects: []` with exit status 0, 2026-10-02

- 2026-10-02 — Don't route a finding to a domain that doesn't exist in this project. Forge's `state.js finding` validates `--domain` against the project-rules-architect *template library* names (`security.md`, `i18n.md`, …), not this repo's numbered rule files, so no `finding` can ever name `17-security.md`. Log the machine event with `state.js log` and put the routable correction here instead.
  → domain: `18-external-contracts.md` | Seen: `state.js finding --domain=17-security.md` → `unknown_domain`, 2026-10-02

- 2026-10-02 — Don't port a rule set's content along with its patterns: strip symbols that belong to the source project and re-derive the rule for this one. ShadCN (`flutter_shadcn_ui`, `ShadButton`, `ShadCard`, `ShadSheet`) appeared in four rule files while being absent from the declared stack, so any session following them would search for widgets that were never installed.
  → domain: `02-architecture.md` | Seen: git history `chore: enrich project rules from keyed_rent conventions`, 2026-10-02

- 2026-10-02 — Don't fix a defect at the point you discover it: sweep for that **class** of defect before moving on. Three contradictions in the PRD were repaired where they were found, and a red-team pass then found seven more of the same class plus twenty-four further problems. The question that catches all of them is *"where else does this exact sentence appear?"* — and it is cheap; the sweep that would have found them was one grep wider than the one actually run.
  → domain: `12-ai-agent-workflow.md` | Seen: PRD red-team pass after signing, 2026-10-02

- 2026-10-02 — Don't sign a document that contains cross-section contradictions: a green structural check is not a coherent document. Placeholders, ID contiguity and cross-reference resolution all passed on a PRD that simultaneously said library removal deletes downloads and does not. Coherence is a separate property, and it needs a separate pass by a reader who did not write it.
  → domain: `12-ai-agent-workflow.md` | Seen: seven critical contradictions in an approved PRD, 2026-10-02

- 2026-10-02 — Don't trust an audit check whose comparison was never tested against a known-bad input. Two integrity scripts reported seventy-plus "missing" IDs that all existed, because they compared a bare number against a prefixed string. A verifier that cries wolf gets switched off, and a switched-off verifier protects nothing.
  → domain: `17-security.md` | Seen: PRD integrity audit flagging every B/E/C/US ID as missing, 2026-10-02

## Promotion

- 2026-10-02 — Don't treat a session log as a closing chore, because a self-documenting commit message is not the log: the log's job is the part a commit cannot carry — what was rejected, what is blocked, and what a next session must not re-litigate. Nine commits went unlogged across Phases 3 and 4, including the finding that `component-parity` was verifying nothing and the finding that SQLite was not enforcing the foreign keys that hold B32.
  → domain: `AGENTS.md` (Definition of Done) | Seen: the owner asked why SESSION_LOG.md was "so far behind that it is not funny", 2026-10-02

- 2026-10-02 — Don't trust a green gate that reports zero work: a check which reads nothing and passes is worse than no check, because a reviewer stops looking. `component-parity` reported `states: 0` for all eight components and said PASS, because the state tables' name column was unbackticked and the heading was the English `States` where the template specifies `États`.
  → domain: `09-widgets-ui.md` | Seen: the browse screens agent asked for a component that did not exist, and separately the component-parity output showed `states: 0`, 2026-10-02

- 2026-10-02 — Don't satisfy a rule's letter when its intent has no state to live in. **B6** said a chapter "is *marked as downloaded* only once it is completely present" and **B33** deletes one chapter's copy; the schema held no mark, so "marked" was a per-row filesystem probe and a deliberate deletion was indistinguishable from never having downloaded. A rule that nothing in the schema can express is a rule nothing verifies — check that each rule has a column, a derived value, or a named check, not only a sentence in the PRD.
  → domain: `10-testing.md` | Seen: the red-team pass on Phase 4, 2026-10-02

- 2026-10-03 — Don't run `git checkout -- <file>` to undo one bad edit in a file that has other uncommitted work. I used it to revert a stray edit and it reverted **everything** uncommitted in that file, including a subagent's four-paragraph rewrite that had been sitting there uncommitted. It survived only because a prior `git add -A` had swept it into a commit. **Undo an edit by re-applying the inverse, or stash first — not by discarding the file.** Twice in one session, and both times the recovery depended on luck about what a previous `git add -A` happened to have caught.
  → domain: `11-git-workflow.md` | Seen: reverting a stray `core/error` layout line in `.forge/architecture.md`, 2026-10-03

- 2026-10-03 — Don't open a file for writing and then read it back to build the value you are about to write. `open(p, 'w')` truncates **immediately**, so the read that follows returns `''`, and the file is destroyed by the statement meant to update it. It cost a 77 KB plan, recovered only because it was committed; **anything not yet committed is one careless statement from gone.** Read into a variable, transform, then write once — which is what `.forge/plans/`'s own `patch.py` does, and why that helper exists at all.
  → domain: `12-ai-agent-workflow.md` | Seen: adding a §10 criterion to `.forge/plans/0-5.md` during the Phase 5 review, 2026-10-03

- 2026-10-03 — Don't reconcile a table against the files it governs in one direction and call it reconciled. `design-system.md` § 3.5 was diffed against all eighteen screen files and declared clean, then a screen was found pushing three routes that had **never** been in the table — because the diff compared the table *to* what screens push, which finds a missing entry and cannot find an invented one. **A one-way reconciliation is a check that reports zero on the half it does not look at**, which is the fourth time this project has hit that shape in a fourth disguise.
  → domain: `12-ai-agent-workflow.md` | Seen: the `more.md` route pushes, 2026-10-03

- 2026-10-02 — Don't let a bulk-edit script report success it did not verify. A `str.replace` patch helper printed `ok` unconditionally; five of nine replacements had silently matched nothing because the text had been reflowed by `dart format` or by an earlier edit in the same run, and the run's own log said every one had landed.
  → domain: `12-ai-agent-workflow.md` | Seen: re-reading five files back after a fix batch and finding the claims false, 2026-10-02

- 2026-10-02 — Don't register a slice against a deliverable's path: `state.js register slice 6-10 .forge/architecture.md` wrote a document-shaped entry (`type: architecture`, all of the file's headings, a content hash) and every later `set-status` / `dep` then rejected it as `unknown_slice`. Point a slice at the plan file it will own, `.forge/plans/<key>.md`.
  → domain: `12-ai-agent-workflow.md` | Seen: registering the ADR-021 slice, 2026-10-02

- 2026-10-02 — Don't guess a deliverable key from its filename: `forge-guard fast-track` looks up `design_system` and `CANONICAL_LAYOUT` in `forge-lib.js` is the only authority on key spelling. `design-system.md` the file is `design_system` the key, and the hyphenated key passes every other gate while making fast-track permanently unavailable.
  → domain: `12-ai-agent-workflow.md` | Seen: fast-track refusing a project whose design system was approved, 2026-10-02

- 2026-10-02 — Don't declare a database constraint and assume it holds; execute it. SQLite disables foreign-key enforcement per connection by default and it is not part of the file format, so `CASCADE` and `RESTRICT` in a drift schema are inert unless every connection sets the pragma. `history_entries.novelId` was `RESTRICT` — the only enforcement of B32 — and deleting a novel succeeded.
  → domain: `06-database.md` | Seen: two schema tests failing against a schema that read correctly, 2026-10-02

- 2026-10-02 — Don't write a drift guard and call it a guard until you have seen it fail: a test that has only ever been green is a decoration. The snapshot-drift test was proven red by adding a column without re-dumping (`columns drifted on chapters`) and green again on restore.
  → domain: `10-testing.md` | Seen: applying the "reports zero and passes" correction to my own new test, 2026-10-02

- 2026-10-03 — Don't give one preference two write paths, even when the second one is only "a thin interface". `2-8` declared its own `SharedPreferences`, its own provider pair and a `Future<bool>` « ne lève jamais » controller for two values `theme-type` already owned end to end with a `select()` that throws. **Two layers, two failure semantics, one preference** — and the reader's behaviour then depended on which layer answered. One preference means one stack and one error contract, whatever the indirection is for.
  → domain: `05-state-management.md` | Seen: a plan re-declaring a foundation's whole provider layer with the opposite error contract, 2026-10-03

- 2026-10-03 — A plan's code must compile as written, and the pseudocode is the part nobody runs. `http-client` § 3.1's `build()` used `rateLimiter` twice and never declared it; `6-11` called a constructor with a `userAgent:` parameter its class did not have; `2-1` listed five files to create **with no directory**, so its own § 2 imports resolved to nothing. Three instances of one shape, and not one is visible to `flutter analyze` because the file does not exist.
  → domain: `08-coding-standards.md` | Seen: three plans in one pass, all copy-pasteable code blocks, 2026-10-03

- 2026-10-03 — A cross-document check must compare **the same thing twice**, and must be able to say when it cannot. `check_plans.py`'s duplicate-path rule compared `lib/core/x.dart` against `core/x.dart` and reported 36 false positives; its enum rule read a member list off an enum body containing a `static fromStorage` and reported the foundation's own enum as a second spelling of itself. **A check with false positives gets switched off, and a switched-off check is worse than the gap it was closing** — so narrowing the rule is part of writing it, not an admission.
  → domain: `10-testing.md` | Seen: two noisy rules in a check written the same afternoon, 2026-10-03

- 2026-10-03 — Assert the bounds of every edit you make by line index, and match on the invariant rather than on decorative formatting. Replacing `2-8` § 3.4 by exact string failed twice on a box-drawing rule of the wrong width; the third attempt asserted `startswith` on the invariant line and the assertions fired on my own wrong assumption instead of writing a mangled block into the file. **The assertion's value is proven by the time it fires on you.**
  → domain: `08-coding-standards.md` | Seen: a `sub()` helper failing on an 80-column rule, 2026-10-03

- 2026-10-03 — Don't `git stash` a directory another agent or process is writing to. One fix agent ran `git stash push -- .forge` to get a clean baseline while a second agent had uncommitted edits in five files in that tree. It survived only because the stash was popped intact and verified. **A baseline belongs in a `git worktree` at HEAD, never in the working tree you are measuring.**
  → domain: `12-ai-agent-workflow.md` | Seen: two agents editing `.forge/plans/` at once, 2026-10-03


Promotion is the path that moves a correction from the journal into a rule. It happens once the rule set exists.

- **Correction → rule.** When the rule set changes, every entry in `## Corrections` is re-read: if it is still true, it is turned into a rule in the file that owns the named domain, and the entry says so in one line. If it is no longer true, it is struck from `## Corrections` with a note on why.
- **What promotion does not recover.** An entry that only holds because today's workaround is convenient stays in `## Corrections` and never becomes a rule, because a rule that encodes an accident breaks without warning.
- **Nothing travels the other way.** A rule that turns out to be wrong in practice does not get quietly fixed in the rule file: it comes down into `## Corrections`, and it is picked up from there. A correction that never goes up never becomes a rule.

## Constats non promus / Unpromoted findings

A finding with no promotion domain is not a correction — it is an observation with nowhere to be applied. Those live in `DECISIONS.md` as **open questions**, each with the trigger that will close it. **Q-002 was the cautionary case**: it sat on that list for three sessions while **E7**, **B21**, ADR-021 and `15-performance.md` had all answered it. Nothing was wrong except that nobody closed the item, so a session reading `DECISIONS.md` found a live question that four other documents treated as settled. **An open question nothing cites is usually already answered** — check the register against the corpus, not just the trigger.

Two tool-level observations are recorded in `.forge/audit/run-log.jsonl` instead, because they belong to Forge's machinery rather than to this project's rules, and no rule file here governs a third-party CLI:

- `guard_failure` — `state.js anchor` does not refuse a declared reference project.
- `unknown_domain` — `state.js finding --domain` validates against the project-rules-architect template library, not this repo's numbered rule files.
- `domain` — a `const` constructor's initializer `assert` cannot call a method, so `assert(!list.toSet().length != list.length)` is a **compile error**, not a runtime check. Measured: `Error: Method invocation is not a constant expression`. An invariant that needs iteration has to be a static method, and it then fires only in a non-`const` invocation. Promotion target: `08-coding-standards.md` § Dart, alongside `prefer_asserts_in_initializer_lists`, whose name suggests the initializer is always the answer. (`0-4`, 2026-10-05.)

- `domain` — `Element.querySelector` returns the **first** match, so a doc comment reading "exactly one node, or this is invalid" is not enforced by the code it documents. `querySelectorAll(...).length != 1` is what turns the comment into a property, and the >1 branch is the one that matters: it is silent otherwise. (`0-4`, 2026-10-05.)

- `10-testing.md` — assert on a **parsed DOM count** when the raw bytes carry a malformed tag: `package:html` materialises a stray `</p>` as an empty `<p></p>`, so "does this page use `<p>` paragraphs?" has two different answers depending on whether you count elements or elements-with-text. `0-4`'s `ParagraphRule.decide` takes the second, and both numbers are asserted so a future capture that fixes the tag changes the test rather than the verdict. (`0-4`, 2026-10-05.)
