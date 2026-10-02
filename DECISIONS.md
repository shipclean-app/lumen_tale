# DECISIONS.md — Lumen Tale

## Règle / Rule

This project spans many sessions, each starting with a zeroed context. Without this file being respected, an AI without memory periodically re-proposes alternatives that were already set aside — losing what is being built and reopening settled debates.

**This file is a register of CLOSED decisions.** A decision recorded here is closed: it is neither to be re-proposed nor silently reversed, even if it looks suboptimal for the task at hand.

If a closed decision is **currently false**: say so explicitly, name the decision and where it is recorded, explain why it no longer holds, and **stop and ask** before proceeding differently. Do not simply build the alternative.

This file is **append-only**. Never delete or rewrite an entry: if a decision changes, **add an entry that supersedes it** and point back with `Status: Superseded by ADR-<NNN>`.

A decision belongs here when it would otherwise be **re-discussed every session**. If it would have to be repeated or re-argued in every slice that touches it, it belongs here.

## Format d'une entrée / Entry format

Six fields, in this order. All six are mandatory: an entry without `Status:` cannot be superseded, and therefore cannot be corrected.

```markdown
## ADR-<NNN>: <Title>

- **Date**: <YYYY-MM-DD>
- **Status**: Active | Superseded by ADR-<NNN>
- **Context**: <what triggered the decision>
- **Decision**: <what is decided>
- **Alternatives considered**: <what else, and why not that>
- **Consequences**: <what this commits the following work to>
```

**`Alternatives considered` is the field that gets skipped, and it is the one that makes a decision reusable.** A decision with no recorded alternative forces the next session to redo the entire evaluation to discover that the alternative exists.

Questions the project **cannot yet answer** stay questions, and each carries **the trigger that will close it** — a condition the agent will recognise on its own, at the moment it arrives. A question with no trigger never closes and becomes a dead line.

## Questions ouvertes / Open questions

### Q-001 — Which sites may Lumen Tale scrape, and who grants permission?

- **What is not known**: no site has been chosen, and `18-external-contracts.md` records `Permission: unknown` for every candidate. Whether the sites the user reads are scrapable at all is unverified.
- **What the answer determines**: whether a source implementation is even lawful/ethical to write, and what `18-external-contracts.md` records per site.
- **Closes when**: the first source is selected for implementation — at that moment, ask the project owner for permission before writing the scraper, not after.
- **Status**: Open

### Q-002 — Must the download queue survive app death?

- **What is not known**: `07-downloads-offline.md` specifies an in-process, cancellable queue with per-chapter progress. Nothing states whether a download must continue after the app is backgrounded or killed.
- **What the answer determines**: whether the queue stays a Riverpod-driven in-process service, or gains a persisted job table plus platform background execution — which would also change `15-performance.md` §Background work and the `DownloadsTable` design in `06-database.md`.
- **Closes when**: the downloads feature is specified in detail (acceptance criteria for "download 200 chapters and close the app").
- **Status**: Open

### Q-003 — Can the native SQLite build be validated on this machine?

- **What is not known**: the stack uses `sqlite3` 3.x, which compiles the native library through Dart's build hooks (`native_toolchain_c`). `dart run drift_dev` works, so the hooks execute here — but no Android or iOS build has been run, because this environment has no Android SDK and no Xcode.
- **What the answer determines**: whether the database layer is proven to build on a real target, or only that it type-checks.
- **Closes when**: an Android SDK is installed and `flutter build apk` succeeds.
- **Status**: Open

## Questions tranchées / Resolved questions

A closed question leaves this section and **becomes an ADR**, carrying the decision, the date, and the alternative that was set aside. Link it by number so the history stays legible: the question did not vanish, it was answered.

## Journal des décisions

### ADR-001: ShadCN is dropped in favour of Material 3

- **Date**: 2026-10-02
- **Status**: Active
- **Context**: The rule set was enriched from another Flutter project (`keyed_rent`) and carried `flutter_shadcn_ui` — in four rule files, naming `ShadButton`, `ShadCard`, `ShadSheet` — while the declared stack table in `AGENTS.md`/`README.md` never mentioned it and `pubspec.yaml` never contained it. A future session reading those rules would search for widgets that do not exist.
- **Decision**: Material 3 only, themed through `app/theme/`. No ShadCN dependency, no ShadCN symbols in any rule.
- **Alternatives considered**: (a) Adopt ShadCN and add it to the stack table — kept the inherited conventions but adopted a dependency nobody had justified for this product. (b) Defer the choice to the first screen — left the rules naming symbols that do not exist, which is the original defect. (c) Drop it (chosen): Material 3 is sufficient for a reader, and it is what the declared stack already said.
- **Consequences**: `09-widgets-ui.md` and `14-design-tokens.md` reference Material 3 primitives and `app/theme/`. Shared presentation components live in `core/ui/`. Any future ShadCN proposal is a new ADR, not a default.

### ADR-002: The theme lives in `app/theme/`, not `core/theme/`

- **Date**: 2026-10-02
- **Status**: Active
- **Context**: `02-architecture.md` and `09-widgets-ui.md` placed the theme in `app/theme/`; `14-design-tokens.md` said `core/theme/` twice. Two answers to one question — the defect the audit checklist calls the one most likely to survive every other check, because both are individually reasonable.
- **Decision**: `app/theme/` is canonical. `14-design-tokens.md` was corrected; `02-architecture.md` §Directory authorities now records the answer so the question cannot reopen.
- **Alternatives considered**: (a) `core/theme/` — would have meant rewriting the layout tree and contradicting `AGENTS.md`'s own layer description. (b) Tokens in `core/`, theme assembly in `app/` — a defensible split, rejected as premature: there is one consumer today and no second opinion about where the boundary falls.
- **Consequences**: `app/` owns theme assembly (`ThemeData`, `ColorScheme`, `ThemeExtension`s). `core/ui/` holds shared presentation components but never theme assembly.

### ADR-003: The HTML→Markdown converter is written in this repository

- **Date**: 2026-10-02
- **Status**: Active
- **Context**: The stack declared `html2md`. That package declares `sdk: >=2.12.0 <3.0.0` on **every** published version — it is Dart 2 only and cannot resolve on this project's Dart 3.13.5. A survey of pub.dev found that every Dart-3-capable HTML→Markdown package is a native/FFI binding (`h2m` via `flutter_rust_bridge`, `html_to_markdown_rust`, `html_to_markdown_ffi`), and every pure-Dart one is a Markdown *renderer* rather than a converter.
- **Decision**: Write the converter directly against `package:html`, which is already a dependency and already used for the selectors and cleaning pass. No `html2md`, no FFI.
- **Alternatives considered**: (a) `h2m` — maintained and feature-rich, but it adds `flutter_rust_bridge` and a native build step (NDK for Android, possibly `rustup`/`cargo` on every dev machine and in CI) to a mobile reader, purely to convert chapter bodies. (b) `html_to_markdown_ffi` and the `h2m` alternatives — same objection. (c) Pin an older Dart to keep `html2md` — rejected: it would have held the whole toolchain back for one package that has not shipped a Dart 3 release in its entire history.
- **Consequences**: The converter is first-party code and therefore first-party risk: it carries its own fixture suite (`test/fixtures/converter/`, P0 in `10-testing.md`) and its own determinism contract. Per-source conversion overrides are now cheap to add, which `03-source-system.md` needs. `17-security.md` rule 13 exists to stop a future session repeating the FFI evaluation without an ADR.

### ADR-004: Toolchain is Flutter 3.47.6 / Dart 3.13.5

- **Date**: 2026-10-02
- **Status**: Active
- **Context**: `pubspec.yaml` declared `sdk: ^3.11.5`, a caret range meaning `>=3.11.5 <4.0.0`. No Flutter or Dart SDK was installed on the machine. Current stable at the time was Flutter 3.47.6 (Dart 3.13.5); the newest release carrying exactly Dart 3.11.5 was Flutter 3.41.9, five months older.
- **Decision**: Install Flutter 3.47.6 (Dart 3.13.5), verified against Flutter's own release manifest and checksum-verified before extraction. It satisfies the declared range.
- **Alternatives considered**: (a) Flutter 3.41.9 — the tightest match to the caret range's lower bound, at the cost of two minor Dart releases and starting at the bottom of the range. (b) Flutter 3.47.5 — same minor, two weeks older; marginal benefit over the current stable. (c) 3.47.6 (chosen): zero code exists, so there is no migration cost, and `pubspec.lock` — not the SDK — is what makes builds reproducible.
- **Consequences**: `AGENTS.md` §Verified toolchain records the resolved versions and requires that Flutter/Dart API answers come from the installed SDK or version-matched docs, never from memory — a framework released the day before cannot be recalled reliably. Three stack declarations were corrected as a direct result (ADR-005, ADR-006, ADR-007).

### ADR-005: `sqlite3` 3.x replaces `sqlite3_flutter_libs`

- **Date**: 2026-10-02
- **Status**: Active
- **Context**: The stack declared `drift (SQLite) + sqlite3_flutter_libs`. `flutter pub add sqlite3_flutter_libs` resolved `0.6.0+eol`, whose own description reads "Not used anymore, update to version 3.x of package:sqlite3 instead". `sqlite3` 3.x builds the native library through Dart's build hooks (`native_toolchain_c`).
- **Decision**: Depend on `sqlite3` ^3.x and drop `sqlite3_flutter_libs`.
- **Alternatives considered**: (a) Keep `sqlite3_flutter_libs` at `0.5.x`, the last non-EOL line — deprecated and superseded by the package's own maintainer. (b) `drift_flutter` 0.3.1 — it still depends on the EOL package, so it does not solve the problem.
- **Consequences**: Native library provisioning is the toolchain's job, not the app's. `flutter build` on a real target remains unvalidated here (Q-003).

### ADR-006: `flutter_markdown_plus` replaces `flutter_markdown`

- **Date**: 2026-10-02
- **Status**: Active
- **Context**: `flutter pub add flutter_markdown` warned `0.7.7+1 (discontinued replaced by flutter_markdown_plus)`. This is what the persistent "1 package is discontinued" message referred to; it disappeared once the package was swapped. Note that the pub.dev API's `isDiscontinued` flag reported `false` for this package — the resolver is authoritative, not the API.
- **Decision**: Use `flutter_markdown_plus`.
- **Alternatives considered**: (a) Keep `flutter_markdown` — it still resolves and would have worked, but it is formally discontinued. (b) Write the renderer — out of scope for v1.
- **Consequences**: `09-widgets-ui.md` and `01-project-vision.md` name `flutter_markdown_plus` and say why, so the swap is not silently reverted.

### ADR-007: The definition of done is stated once, in `AGENTS.md`

- **Date**: 2026-10-02
- **Status**: Active
- **Context**: The format/analyze/test/commit sequence appeared in both `11-git-workflow.md` and `12-ai-agent-workflow.md`, inviting drift. The rule-file template asks every file to carry its own commands and definition of done, but this project's OpenCode target globs `.opencode/rules/*.md` with **no activation scoping** — so every file loads every session and the template's per-file block would have become 18 copies of the same three commands.
- **Decision**: `AGENTS.md` §Definition of Done is the single owner, alongside §Priority Order and §Commands. Rule files carry only domain-specific additions and cross-reference it.
- **Alternatives considered**: (a) Keep the per-file block from the template — 18 duplicated copies on a target that cannot scope them, which the audit checklist names as a "second, condensed restatement layer". (b) Merge `11` and `12` into one workflow file — rejected: git conventions and agent operating rules are genuinely different concerns and both files keep substantial unique content; cross-referencing preserves all of it.
- **Consequences**: `11` and `12` no longer restate the sequence. Conflicts between rule files are resolved by `AGENTS.md` §Priority Order, which is referenced rather than reasserted.