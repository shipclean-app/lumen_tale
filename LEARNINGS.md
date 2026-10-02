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

- 2026-10-02 — Don't trust a CLI's help text over its parser: check how the flag is actually parsed. Forge's `state.js --help` documents `--reference <p>` (space) while the parser only matches `--reference=<p>` (equals); the space form silently registers nothing, so the reference project is recorded as read-only-but-absent.
  → domain: `18-external-contracts.md` | Seen: `state.js init --reference /tmp/opencode/mihon` returning `reference_projects: []` with exit status 0, 2026-10-02

- 2026-10-02 — Don't route a finding to a domain that doesn't exist in this project. Forge's `state.js finding` validates `--domain` against the project-rules-architect *template library* names (`security.md`, `i18n.md`, …), not this repo's numbered rule files, so no `finding` can ever name `17-security.md`. Log the machine event with `state.js log` and put the routable correction here instead.
  → domain: `18-external-contracts.md` | Seen: `state.js finding --domain=17-security.md` → `unknown_domain`, 2026-10-02

- 2026-10-02 — Don't port a rule set's content along with its patterns: strip symbols that belong to the source project and re-derive the rule for this one. ShadCN (`flutter_shadcn_ui`, `ShadButton`, `ShadCard`, `ShadSheet`) appeared in four rule files while being absent from the declared stack, so any session following them would search for widgets that were never installed.
  → domain: `02-architecture.md` | Seen: git history `chore: enrich project rules from keyed_rent conventions`, 2026-10-02

## Promotion

Promotion is the path that moves a correction from the journal into a rule. It happens once the rule set exists.

- **Correction → rule.** When the rule set changes, every entry in `## Corrections` is re-read: if it is still true, it is turned into a rule in the file that owns the named domain, and the entry says so in one line. If it is no longer true, it is struck from `## Corrections` with a note on why.
- **What promotion does not recover.** An entry that only holds because today's workaround is convenient stays in `## Corrections` and never becomes a rule, because a rule that encodes an accident breaks without warning.
- **Nothing travels the other way.** A rule that turns out to be wrong in practice does not get quietly fixed in the rule file: it comes down into `## Corrections`, and it is picked up from there. A correction that never goes up never becomes a rule.

## Constats non promus / Unpromoted findings

A finding with no promotion domain is not a correction — it is an observation with nowhere to be applied. Those live in `DECISIONS.md` as **open questions** (Q-002 … Q-004), each with the trigger that will close it.

Two tool-level observations are recorded in `.forge/audit/run-log.jsonl` instead, because they belong to Forge's machinery rather than to this project's rules, and no rule file here governs a third-party CLI:

- `guard_failure` — `state.js anchor` does not refuse a declared reference project.
- `unknown_domain` — `state.js finding --domain` validates against the project-rules-architect template library, not this repo's numbered rule files.