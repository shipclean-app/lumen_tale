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