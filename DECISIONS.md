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

- **Status**: **Closed 2026-10-02** → became ADR-008 (sites) and the `18-external-contracts.md` records.
- **Resolution**: **FanMTL** (https://www.fanmtl.com) is the **first and primary** source — a fan-fiction / web-novel site whose robots.txt permits reading content and whose chapter text is server-rendered. **Royal Road** and **Novel Fire** were named earlier; after FanMTL became the first source their v1 status is **unconfirmed** — see Q-005. Novel Fire's terms remain unconfirmed regardless (Q-004).

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

### Q-004 — Does Novel Fire's terms permit a scraper?

- **Status**: **Open — Cloudflare concern resolved, terms still unconfirmed.**
- **Resolved by measurement (ADR-014):** the "probably blocked by Cloudflare" worry is **wrong**. An honest UA gets 200; only a browser-impersonating UA gets challenged. No bypass is needed and none will be built.
- **Still unknown**: Novel Fire's terms of service have not been read. It is also an aggregator whose chapter pages may be proxied from origin sites, so permission from Novel Fire may not cover the origin.
- **What the answer determines**: whether the Novel Fire source ships in v1. It is in scope (ADR-013) but its scraper stays unbuilt until this closes.
- **Closes when**: the owner reads and confirms the terms. At that moment, record it in `18-external-contracts.md` and confirm whether proxied origin content is in scope.

### Q-007 — Is tag browsing an acceptable substitute for text search on FanMTL?

- **Status**: **Closed 2026-10-02** → became **ADR-015**.
- **Resolution**: Genre/tag browsing is the primary discovery mechanism on these sites, and a novel's own tags are the good entry point — but a source gets **no search at all** unless its site genuinely implements one. FanMTL's search is unreachable, so **FanMTL offers genre browsing only**, and search is declared per source.

### ADR-015: Search is an opt-in per-source capability, gated on the site genuinely implementing it

- **Date**: 2026-10-02
- **Status**: Active
- **Context**: The owner answered Q-007 with a principle rather than a one-off: browsing by genre is how most web-novel sites work, and the tags on a novel's detail page are a good way in — **but passing those tags back into the site's own search bar returns unsatisfying results**. The rule they gave is therefore *"unless the website genuinely implements genre search, we won't add it to that source."* This is stricter than Mihon, which exposes search on every source that has a search endpoint, and much stricter than the commercial apps, which own their index and therefore always "have search".
- **Decision**: **`Source.supportsSearch` is a declared per-source capability**, exactly like Mihon's existing `supportsLatest`, and the app may only use it where the site's own search is genuinely usable. Where it is not, the source exposes **genre/tag browsing instead** and the app says so — it never renders a search box that would return nothing. A source that declares search and then returns nothing is a **broken source** (B22), not a source with no results.
- **Alternatives considered**: (a) Ship search on every source and let it return nothing — rejected: it is the failure B22 exists to prevent, presented as a feature. (b) Implement our own cross-source index so search always works — rejected for v1: it turns a reader into a search engine, needs every chapter's metadata up front, and breaks the moment a site's markup changes. (c) Hide search per source at the UI layer without declaring it in the contract (chosen): the capability is data, not presentation, so it belongs in the `Source` contract where `supportsLatest` already lives.
- **Consequences**: `03-source-system.md` gains `supportsSearch` alongside `supportsLatest`. `US-02` becomes conditional, which amended the approved PRD via `state.js amend` → **B50**. A novel's detail page exposes its genres as tap-to-browse, mirroring Mihon's `searchGenre()` behaviour rather than inventing a new interaction. Each remaining source needs its own reachability check before search can be promised for it — **Royal Road and Novel Fire are not yet checked**, so v1 can claim genre browsing for all three sites but search for none of them until they are.

### ADR-016: The two themes are deliberately not inversions of each other

- **Date**: 2026-10-02
- **Status**: Active
- **Context**: The PRD requires a dark theme (B14, B26) and `benchmarks.md` § 2.2 records that both competitors ship one — Dreame's with the complaint that it is hard to find. The obvious way to build a second theme is to invert the first: take the day palette, invert the lightness of each token, and ship. The warmth of the day palette then doubles down at night, because the tokens that carry chroma are the ones being inverted.
- **Decision**: **Day is warm paper; night is cool ink.** Day surfaces are hue ≈ 37°, chroma 0.03 (`#F5F2ED` … `#EBE7E0`). Night surfaces are hue 220°, chroma 0.14 (`#121315` … `#0C0D0F`), carrying **warm-white text** (`#E8E4DD`). The two themes are designed independently, not derived from each other.
- **Alternatives considered**: (a) Literal inversion — rejected on the halation argument below. (b) Warm night theme ("cosy") — the choice the competitors make and the intuitive one; rejected because it is wrong for the one condition that matters here. (c) Pure neutral greys in both, abandoning warmth — rejected: it discards the direction's whole identity and leaves the accent carrying all the character alone.
- **Consequences**: Night is a *designed* theme, not a derived one, so a token change in day does not propagate and each must be re-measured. The amber accent reads as lamplight on the cool field rather than as a warning. `error` had to become a **desaturated brick** (`#8A3228` day / `#EE8B76` night) precisely so it cannot compete with an amber accent in the same theme — that constraint did not exist before the accent was amber. Semantic colours are per-theme by necessity, not preference: one error red measures 7.32:1 on paper and 2.27:1 on night.
- **Why halation matters here specifically**: a reader who reads at night turns the screen brightness *down*. Low brightness is precisely the condition under which warm text on a warm dark field blooms. Putting the warmth in the *text* and the coolness in the *field* inverts that: the page recedes and the prose is what is lit. This is the reason the design is contestable, and it is a real reason rather than taste.

### ADR-017: Reader prose is serif, chrome is sans — via a preference chain, not a bundled font

- **Date**: 2026-10-02
- **Status**: Active
- **Context**: Mihon renders **images**, so it has no typographic opinion to copy — unlike every other part of its structure, this is a place where "copy the reference" copies nothing. The dominant activity in this app is long-form prose. Separately, `18-external-contracts.md` records that FanMTL's own reader chrome offers a **font picker with Lora and a Dyslexic option**, which is direct evidence of what this audience expects to be offered.
- **Decision**: The reader's prose uses a **serif preference chain** — `Noto Serif` → `Roboto Slab` → platform serif — with the platform sans as a guaranteed fallback. All application chrome uses the platform sans. **No font is bundled** in v1.
- **Alternatives considered**: (a) Bundle a variable reading face — rejected for v1: it adds an asset, a licence to carry, and an APK-size decision that is not worth it before the preference chain has been seen unsatisfying. **Kept as an explicit v2 candidate.** (b) Sans for prose too — rejected: it is the default outcome, and it is measurably less comfortable over a long session than the same measure in a serif. (c) Bundle the Dyslexic face because the site offers it — rejected as v1 scope creep; it is a genuine accessibility option and is **recorded as a v2 candidate**, not dismissed.
- **Consequences**: `design-system.md` § 1.2 declares the reader scale (`--reader-*`) separately from the UI scale, because one ramp doing both jobs is how a type scale stops being a scale. Line-height is held at **1.72 across every reading size** — scaling it with size would change the reading rhythm exactly when the reader has just changed something they will get used to. Bundling remains open and would reopen this ADR rather than quietly override it.

### ADR-018: Navigation order is Library · Updates · History · Browse · More, and Library must open the loop

- **Date**: 2026-10-02
- **Status**: Active
- **Context**: `references/module-prioritization.md` calls the order of navigation entries the most commonly missed rule in mobile design, and `archetypes.md` § 2 names the trap for `mobile_consumer` precisely: *"écran d'accueil qui est un sommaire"* — a home screen that is a menu. Mihon's own order is Library · Updates · History · Browse · More, so the reference and the frequency analysis happen to agree here, which is a reason to check the reasoning rather than a reason to skip it.
- **Decision**: Adopt that order, on these stated grounds. **Library is first because it has the highest frequency and is the only screen that can open the loop** — a returning reader's most frequent action is resuming, and the Library is where the app re-enters after a download or a notification. **It must lead with a continue-reading shelf at the stored position, with the list below it**; a Library that is only a list of covers with counts has put a summary where a home belongs. Updates is second (new-before-past; the app's only pull-loop). History is third (a resume surface, but past tense; centrality 2). Browse is fourth (the only way to add a novel, several times a week but never why the app is opened). More is fifth, **lowest by design**: everything behind it is configuration or a transfer.
- **Alternatives considered**: (a) Browse first, as the literal `mobile_consumer` "discover → consume → return" loop reads — rejected: the loop is *entered* through the reader's own shelf, not through a catalogue; putting Browse first optimises the step that happens least. (b) Downloads as a fifth tab, since offline is the stated wow moment — rejected: downloads are a **state of library novels**, not a place to browse, and their progress is surfaced in three better places (library row, novel detail, persistent status bar). The *offline guarantee* is proven by Wave 2, which is a build-order decision, not a navigation one. (c) Merge History into Library — rejected: they answer different questions ("what do I have" vs "what did I read"), and B46 already refuses to conflate reading position with history.
- **Consequences**: Recorded via `state.js set-nav` so the order is machine-checkable rather than asserted in prose. `design-system.md` § 3.2 carries the full per-item score and rationale. **Downloads sits in overflow with its reason written down**, because an overflow entry with no recorded reason is how a tab silently reappears.

### Q-006 — Is the default branch `master` or `main`?

- **Status**: **Closed 2026-10-02** — `master` **is** the main branch.
- **Resolution**: the owner's "main branch" meant the principal branch, which in this repository is `master`. ADR-011 as written is correct and needs no change. The CI `on:` trigger is `master`.

### Q-005 — Are Royal Road and Novel Fire still in v1 now that FanMTL is first?

- **Status**: **Closed 2026-10-02** — **all three sites are in v1.** FanMTL first, then Royal Road and Novel Fire.
- **Resolution**: FanMTL, Royal Road, and Novel Fire are all v1 sources. Novel Fire remains **individually blocked on Q-004** (its terms are unconfirmed) — being in scope is not permission to implement. Per ADR-013 the platform contract is built against FanMTL first and the other two are added as adapters over the same contract, so a source blocked on permissions does not block the slice.


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

### ADR-008: Mihon is the declared reference project — copy structure, re-derive code

- **Date**: 2026-10-02
- **Status**: Active
- **Context**: Lumen Tale's rules were written as a transposition of Mihon's `source-api`, but no reference was ever pinned, so every divergence was invisible and the rules silently drifted from both Mihon and from this project's own stack. Mihon was cloned for inspection (`/tmp/opencode/mihon`, `db45dda`). Comparing them surfaced divergences that "copy Mihon" would have inherited without anyone noticing.
- **Decision**: Mihon is the reference for **product scope, screen inventory, and feature structure**. It is **not** the reference for implementation. Mihon is Kotlin/Compose; this project is Flutter/Dart. Every Mihon pattern is evaluated for a Flutter equivalent first, and a divergence is recorded as an ADR rather than silently tolerated.
- **Alternatives considered**: (a) Port Mihon's architecture literally — rejected; there is no Kotlin-to-Dart translation that preserves the decisions, only the surface. (b) Ignore Mihon and design from the product need alone — rejected; it discards a validated feature decomposition and 60+ screens' worth of interaction design. (c) Reference-with-verification (chosen): Mihon's *what* and *why* are inherited; its *how* is re-derived against Flutter.
- **Divergences deliberately kept** (do not "fix" these back toward Mihon):

  | Concern | Mihon | Lumen Tale | Why |
  |---|---|---|---|
  | Domain layout | feature-first (`domain/chapter/{model,repository,interactor,service}`) | **layer-first** (`domain/{models,repositories,interactors}`) | Chosen by the owner. `02-architecture.md` is authoritative. |
  | Persistence | SQLDelight | **drift** | ADR-005. |
  | Navigation | Voyager (`cafe.adriel.voyager`) | **go_router** + centralized route constants | Voyager is Compose-only; `09-widgets-ui.md` rule 10 already mandates centralized paths. |
  | Async | `suspend` + RxJava | `Future` + Riverpod `AsyncValue` | Idiomatic Dart. |
  | `Source.id` | `Long` (MD5 first 8 bytes) | `String` (full MD5 hex) | Readable in logs and debuggable; no Mihon-compat requirement exists. |

- **Upstream deprecations that do transfer**: Mihon has deprecated `ParsedHttpSource` and most of `HttpSource`'s helpers — *"the helper functions are inherently limiting and hides the underlying implementation."* That critique applies to any language, so our `ParsedHttpSource` survives as an **optional, thin** convenience (`03-source-system.md` §Contract) rather than the contract itself.
- **Contract corrections made from this comparison**: `Filter<T>` is generic with a typed `state`; `Filter.Group<V>` was missing from our model list and is added; `getNovelUpdate` takes the caller's existing `chapters` so a source returns only what changed.
- **Consequences**: `18-external-contracts.md` holds site facts. Divergences get an ADR, not a quiet edit. `.forge/` is where scope and slices are planned — it holds *what to build and where we are*, never *what to follow*, which stays in `AGENTS.md` and `.opencode/rules/`.

### ADR-009: The reader is continuous-scroll in v1; paged mode and reading modes are v2

- **Date**: 2026-10-02
- **Status**: Active
- **Context**: The target is parity with the commercial web-novel mobile apps, which offer continuous **and** paged reading, plus reading modes (scroll, horizontal, vertical, dual-page), orientation control, and per-page colour filters. Mihon's reader mirrors that (`ReaderActivity`, `ReadingModeSelectDialog`, `OrientationSelectDialog`, `ChapterTransition`, `ColorFilterPage`, `ReadingModePage`). Shipping all of it in v1 would put the most complex subsystem of the app on the critical path before the pipeline it feeds is proven.
- **Decision**: v1 is **continuous scroll only**, restoring scroll position on reopen. Paged mode, reading modes, orientation selection, page transitions, and colour filters are explicitly v2, and the reader's state model must not preclude them.
- **Alternatives considered**: (a) Build the full reader up front — rejected: it is the largest single subsystem and its output feeds the pipeline, so building it first inverts the risk order. (b) Scroll-only forever — rejected; parity with the reference apps is a stated goal, so this would be a permanent gap rather than a deferral.
- **Consequences**: `09-widgets-ui.md` §Reader UX mandates continuous scroll for v1. A chapter's position is stored as a scroll offset, **not** a page index, so v2 paged mode can resume the same reading position — changing that later means migrating stored positions. Colour-filter and reading-mode settings are therefore v2 surfaces of `SettingsReaderScreen`.

### ADR-010: v1 scope is personal-use only

- **Date**: 2026-10-02
- **Status**: Active
- **Context**: The app reads third-party sites. Whether redistribution or export surfaces may be built affects the legal posture and the design of download, sharing, and backup features.
- **Decision**: v1 is **personal use only**. No sharing, no export to a portable format, no backup/restore of downloaded content, no public catalogue sharing.
- **Alternatives considered**: (a) Allow export in v1 — rejected: it converts a personal reader into a redistribution tool and pulls in provenance/licensing questions that are out of scope. (b) Say nothing and leave it open — rejected; an unstated default reads as permission.
- **Consequences**: Mihon's backup/restore screens and its `.cbz`/archive handling are excluded in v1. Downloaded Markdown is readable by the app and nothing else in v1. Revisiting export requires a new ADR.

### ADR-011: Builds are produced by GitHub Actions on merge to `main`, never distributed through a store

- **Date**: 2026-10-02
- **Status**: Active
- **Context**: The owner requires versioning so that merging into `main` produces the APK builds automatically. No Play Store (ADR-010's exclusion, now confirmed as the permanent answer to the §5 question). No tablet layout in the current scope.
- **Decision**: A GitHub Actions workflow builds the APKs on merge to the repository's **default branch — which is currently `master`**, not `main`. The owner asked for `main`; the branch does not exist, and a workflow whose `on:` names a nonexistent branch **never runs and reports success**, which is the same silent-green failure shape as an instruction glob that matches nothing. Written against `master` so it is true today; Q-006 tracks renaming the branch, and if it is renamed the trigger follows.
- **Decision (continued)**: There is **no store listing**, so there is no store version to keep in step and no review gate. `pubspec.yaml` `version: <major.minor.patch>+<build>` is the single source of truth; the workflow overrides `--build-name` and `--build-number` from the git tag and the Actions run number, so two builds of the same commit are never indistinguishable.
- **Alternatives considered**: (a) Play Store / App Store — rejected: needs a paid developer account, a review process, and a build proven on hardware we do not have; it would also couple every release to store policy. (b) Local builds only, no CI — rejected: the owner asked for builds to appear automatically on merge. (c) F-Droid style rolling channel — rejected as unnecessary indirection for a personal-use app.
- **Details still open, and deliberately so**: which exact APK variants to publish (split-per-abi vs universal), whether a debug artifact is uploaded alongside, and whether `main` is merged directly or via PR. These are cheap, reversible packaging choices — see §4 of the contract — and they are settled when the workflow is written, not now.
- **Consequences**: No Play Store code, no signing-for-store config, no store metadata work in any slice. `07-downloads-offline.md` is unaffected. The Android SDK becomes a **CI** dependency rather than a local one, which changes the shape of Q-003: the build is verifiable without a developer machine having an SDK.

### ADR-012: v1 success criteria

- **Date**: 2026-10-02
- **Status**: Active
- **Context**: No success criterion was ever stated. Phase 2 measures scope against it, so leaving it undefined lets the roadmap set its own target.
- **Decision**: v1 is done when **all** of the following hold:

  1. **FanMTL and Royal Road** are browsable, searchable, and their chapters readable end to end. **Novel Fire** as well, if its terms are confirmed before the §5 deadline — otherwise it does not count against v1 (Q-004).
  2. **Fifty chapters** can be downloaded and then read **with the network off**, verified by actually disabling connectivity — not by asserting the file exists.
  3. Library, history, and unread badges are correct.
  4. **French and English** are both complete — every user-visible string, including errors.
  5. **One verified install on the owner's own phone**, from a CI-produced APK.

- **Alternatives considered**: (a) "It builds and the tests pass" — rejected: says nothing about whether a person can read a novel. (b) A user-count target — rejected: this is personal-use, so there is no audience to grow into. (c) Feature-parity with Mihon — rejected: Mihon's scope is larger and explicitly excluded here.
- **Consequences**: Item 5 means Q-003 closes through CI, not through a local SDK install. Item 2 makes the offline promise falsifiable, which is the product's core claim. Criterion 1 names two sites rather than "the site", so success cannot be met by a single lucky integration.

### ADR-013: All three v1 sources are adapters over one platform contract; FanMTL is built first

- **Date**: 2026-10-02
- **Status**: Active
- **Context**: Q-005 closed with all three sites in v1 (FanMTL first, then Royal Road and Novel Fire). That creates a coupling risk: Novel Fire is individually blocked on unconfirmed terms (Q-004). If the platform contract is designed around whichever source happens to be first, the second and third sources become rewrites.
- **Decision**: The platform contract — `Source`, `HttpSource`, `Filter<T>`, `Novel`, `Chapter`, `NovelsPage`, and the HTML→Markdown pipeline — is written and tested against **FanMTL**, and FanMTL is the reference fixture. Royal Road and Novel Fire are **adapters over that same contract**: new selectors, new URL shapes, new per-source conversion overrides, no changes to the contract. A source blocked on permission therefore does not block the contract slice.
- **Alternatives considered**: (a) One source per slice with the contract split per site — rejected: it multiplies the contract by three and guarantees drift. (b) Wait for all three permissions before designing anything — rejected: it stalls the whole project on a question only the owner can answer. (c) FanMTL-specific contract — rejected: that is the divergence ADR-008 exists to prevent, applied to ourselves.
- **What each site forces that the others do not** — already verified, so Phase 4 does not have to discover them:

  | Concern | FanMTL | Royal Road | Novel Fire |
  |---|---|---|---|
  | Article selector | `div.chapter-content` | to be discovered | to be discovered |
  | Paragraph delimiter | `<br><br>`, **zero `<p>`** | to be discovered | to be discovered |
  | Catalogue / pagination | `/list/<tag>/<sort>-<page>.html`, **0-based page** | `/fictions/*` | to be discovered |
  | Chapter URL | `/novel/<id>_<n>.html` | `/fiction/<slug>/<chapter>` | to be discovered |
  | Cloudflare | present, not challenging | expected present | unknown |
  | Permission | permitted, verified | permitted, verified | **unconfirmed — Q-004** |

- **Consequences**: `04-html-to-markdown.md`'s per-source override mechanism is load-bearing from day one, not a convenience — it is how the second and third source get added without touching the contract. The `<br><br>` paragraph rule and the `.chapter-content` selector are already promoted from the FanMTL record for this reason. A source whose markup has no `<p>` at all is the hard case, and the first site happens to be that hard case, which is fortunate.

### ADR-014: Mihon's Cloudflare WebView bypass is NOT ported — and impersonating a browser measurably makes things worse

- **Date**: 2026-10-02
- **Status**: Active
- **Context**: The owner noted that some Mihon sources sit behind Cloudflare and that Mihon has a workaround, and suggested we would likely need it for Novel Fire. Mihon's mechanism is `core/common/.../network/interceptor/CloudflareInterceptor.kt`: detect the challenge by the official signal (`cf-mitigated: challenge` + `Server: cloudflare*`), then load the URL in a **real Android `WebView`** off-screen, wait up to 30 seconds for a fresh `cf_clearance` cookie, replay the request with it, and — importantly — **abort on interactive/Turnstile challenges** rather than defeating them. The Flutter port would need `webview_flutter`, a heavy platform plugin.
- **Measurement, 2026-10-02** — every site tested twice, once honest and once with a Chrome/Android browser string:

  | Site | Honest UA | Browser-like UA |
  |---|---|---|
  | FanMTL | 200, no challenge | 200, no challenge |
  | Royal Road (home, best-rated catalogue, real chapter) | 200, no `cf-mitigated`, no Turnstile | 200, no `cf-mitigated`, no Turnstile |
  | **Novel Fire** | **200, full page** | **403, `cf-mitigated: challenge`, Turnstile markup** |

- **Decision**: Do not port the WebView bypass. None of the three v1 sites challenges an honestly-identified client, and on Novel Fire **browser impersonation is the thing that triggers the block**. `17-security.md` rule 5 stays as written, and this measurement is promoted into it as the worked example.
- **Alternatives considered**: (a) Port Mihon's interceptor — rejected on measurement: it would add `webview_flutter` and a hidden-WebView code path that is **never exercised** by any current site, and on Novel Fire the User-Agent it would present to the challenge page is precisely the one that gets a 403. (b) Ask the sites for whitelisting — not pursued; it is a relationship cost for a personal-use app, and the honest client already works. (c) Honest identification only (chosen).
- **Consequences**: `webview_flutter` is **not** added. The path back is narrow and explicit: if a site starts serving `cf-mitigated: challenge` to our honest UA, that is a finding for `18-external-contracts.md`, the contract says we ask the owner rather than escalate, and the answer is either *drop the source* or *amend `17-security.md` rule 5 with a new ADR*. It is never an implementation detail. This decision is the concrete case behind the ADR-008 rule that a Mihon pattern is a starting point, not an authority — copying this one faithfully would have broken a source we can otherwise read fine.