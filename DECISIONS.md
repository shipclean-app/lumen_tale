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

### Q-002 — Must the download queue survive app death? — **CLOSED 2026-10-02: it resumes, it does not continue**

- **Status**: Closed
- **Answer**: **The queue resumes; it does not continue.** **B21** settles it — *"A download queue survives the app being closed and reopened: it continues from where it stopped rather than restarting the novel."* "Continues from where it stopped" is **resumption**, not background execution, and the distinction is the whole answer. **E7** says the same thing from the other side: the queue is in-process and has **no background executor**. So it stays a Riverpod-driven in-process service with a persisted `queue_items` table, and it gains **no** platform background execution.
- **Closed against**: **E7**, **B21**, ADR-021's reasoning, and `15-performance.md` §Background work, which all already stated the in-process answer. **This question was answered everywhere except on the register** — it was the only open question with no citation in `.forge/` at all, so a session reading `DECISIONS.md` would have found it live while three other documents treated it as settled. That is the failure mode an open-questions list creates when the answer is reached without closing the item.
- **What the answer determined, and what it did not**: the queue stays a `queue_items` table plus an in-process service — **unchanged**. It does **not** touch `06-database.md`'s table design beyond what B21 already required. **And it is not the same question as ADR-021's**: the *check* (B37) does get a foreground job via `workmanager`, because the reader is watching and can cancel it. The *download* queue gets no executor, because nothing on screen is waiting for it. **Two subsystems, two lifecycles, and conflating them is what kept this question open for a session.**
- **Reopens if** a future version promises the queue keeps downloading after the app is closed — which would be a real feature with a real cost, and would need its own ADR.

### Q-008 — Is there a real Android phone, and a way to put an APK on it?

- **Status**: Open — **premise now answered YES on 2026-10-03; exit criteria still unmet.**
- **~~Confirmed unresolvable from this environment, 2026-10-03, by the owner~~ — RETRACTED 2026-10-03, by measurement.** The entry read *"you are on GitHub Codespaces so verification on a mobile device isn't possible."* That was true of the Codespace and false of the machine. A **nubia Z2577, Android 16 / API 36, arm64-v8a** is connected over USB, `adb install` succeeds, the app launches without crashing, and `flutter test integration_test/ -d <id>` deploys and runs. **The premise is answered; the question stays open** because its exit criteria are about product behaviour, not tooling.
- **What was actually missing, and was not the device**: the *mechanism to run a test on it*. `flutter test -d <id>` **silently ignores the device flag** for files under `test/` — a fabricated device id still printed `All tests passed!` after running the suite on the host. Only a file under `integration_test/` is genuinely deployed, and there it **refuses to run** against an unknown device. Anyone re-testing this must use `integration_test/`; see `test-plan.md` § 4.2.
- **What it does not change**: the plans, the gates and the build. The build is now verified here directly, so ADR-011's CI dependency is a second verification point rather than the only one.
- **Why the split matters**: `DECISIONS.md`'s Q-003 asked *can a native build be validated here* and closed on *an Android SDK is installed and `flutter build apk` succeeds*. `roadmap.md` asked *is there a real phone and a way to install on it* and has **no exit criteria at all**. Those are different questions with different answers: **ADR-011 already made the SDK a CI dependency**, so Q-003's original question is arguably satisfied by CI while the device question is untouched. One ID for both meant a session could close it on the easy half and believe v1 was verifiable.
- **Closes when**: an APK has been installed on a real phone, **a chapter has been read on it with the connection off**, and the **upgrade-safety drill** has run (`architecture.md` § 3.1b). Not on the SDK alone, and — measured 2026-10-03 — not on the APK alone either.
- **Blocks**: SC-5, and the MVP and V1 gates. **Nothing else** — the whole build sequence proceeds without it.
- **Not blocked by the device any more**: only by **0 of 32 slices being implemented**. No product behaviour exists to observe.

### Q-003 — Can the native SQLite build be validated on this machine?

- **Status**: **CLOSED 2026-10-03 — YES, by measurement.**
- **What was not known**: the stack uses `sqlite3` 3.x, which compiles the native library through Dart's build hooks (`native_toolchain_c`). `dart run drift_dev` works, so the hooks execute on the host — but no Android or iOS build had been run, because the environment was believed to have no Android SDK and no Xcode.
- **Answer, on the closing condition as written** (*an Android SDK is installed and `flutter build apk` succeeds*): **both now true.** An SDK is installed (platforms 34/35/36, build-tools 36.1.0, all licences accepted) and `flutter build apk --debug` succeeded in 707s.
- **Answer, on the question actually asked** (*is the database layer proven to build on a real target, or only to type-check?*): **proven, and then some.** `lib/arm64-v8a/libsqlite3.so` (1 732 360 bytes) is packaged in the APK, and `integration_test/device_proof_test.dart` then opened a real database **on the phone** through the app's own `_openLazy()`, asserting that the DDL executes against the device's SQLite build and that **`PRAGMA foreign_keys` is 1** on that connection. 6/6 passed on-device; `analyze` reports zero issues.
- **Why the extra step mattered**: *packaged* is not *loaded*. A `.so` that ships and fails to `dlopen` still produces a green build. The on-device suite is what distinguishes the two, and it is also the first evidence that **B32's only enforcement** — the `RESTRICT` on `history_entries.novelId`, which is off by default per connection and re-enabled solely by `_setup()` — holds against Android's SQLite rather than only the host's.
- **Two environment facts this exposed, recorded because they will recur**: the Android SDK's bundled JDK is **Java 25**, which **Gradle 8.14 cannot run on**; a JDK 21 was installed at `~/tools/jdk/jdk-21.0.12.1+1` and selected with `flutter config --jdk-dir`, rather than bumping the Gradle wrapper, which would have been a stack change. And the connected nubia ships `persist.log.tag='S'`, which filters logcat to Silence and makes `flutter run` hang after `✓ Built …apk` with no VM Service URL; set it to `I`.

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

### ADR-021: B37 ships in v1 — a manual check runs as a foreground job with a cancellable notification

- **Date**: 2026-10-02
- **Status**: Active
- **Context**: A red-team pass found **B37 simultaneously required and denied**. `prd.md:403` says *"A scheduled **or manual** check runs as a foreground job with a visible notification the user can cancel."* `settings.md` designs exactly that on the **manual** path — the foreground notification, the OS-permission deep link, the six interval strings. `architecture.md` said *"No v1 slice implements it"*, and the roadmap deferred it behind an undecided gate. ADR-020 made it worse by *rejecting* "a manual new-chapter notification" — but that is a **different notification** from B37's **job-progress** one, and conflating them let a live rule slip through as if it had been discharged.
- **Decision**: **B37 ships in v1, on the manual path.** A manual *Check now* runs as a foreground job with a visible, cancellable notification, exactly as `settings.md` specifies. This needs no background executor and does not contradict E7, which is about the **download** queue — a different subsystem with a different lifecycle.
- **Alternatives considered**: (a) Keep denying it — rejected: a design cannot decline an approved business rule; the only two mechanisms are shipping it or **withdrawing** it through the PRD's own apparatus. (b) Withdraw B37 — rejected: the notification is honest and useful (C12: the reader can see a check is running), it is already designed, and `workmanager` is already a committed dependency. Withdrawing would be the larger change.
- **Consequences**: Slice `6-10` carries B37. The roadmap's § 3.5 deferral is **withdrawn as a deferral** — it was never permitted, because `roadmap.md` § 0 Rule 3 says scoping "does not weaken, reinterpret or drop" any PRD rule, and the PRD's mechanism for dropping one is a **withdrawal that keeps its ID**. B35's *interval picker* was still being carried as conditional here; it is now **withdrawn entirely** — see ADR-023, which was written after this entry and does not contradict it.

### ADR-022: The download mark is a column (`chapters.downloadedAt`), not a filesystem probe

- **Date**: 2026-10-02
- **Status**: Active
- **Context**: **B6** says a chapter "is **marked as downloaded** only once it is completely present". **B33** says a single chapter's copy can be deleted on its own. But the committed schema had **no mark at all** — `chapters` held `id, novelId, name, number, url, isRead, readAt, ordinal`. So the mark was a per-row filesystem probe, and `reader-chapter-sheet.md` documented the consequence itself: *"Absent while marked downloaded → treated as absent; B6 says it cannot be, so this is a drift alarm."* Three problems followed. **B33 created the forbidden state** — a deleted copy is indistinguishable from a never-downloaded one. **B9 was at risk** — US-05 requires 10 000 chapters visibly marked, and probing 10 000 files is not a list operation. And the architecture conceded the divergence was real: *"A mismatch is **detectable**"* — while C8 requires the app be **incapable** of a false state of completeness.
- **Decision**: **`chapters.downloadedAt` is a nullable datetime. Null means not downloaded.** It is written **after** the atomic rename, never before. That ordering is the whole of B6's intent: a crash between the two leaves a file with no mark, which is the safe direction — the chapter offers itself for download rather than opening as complete. The reverse, a mark with no file, is unreachable.
- **Alternatives considered**: (a) A `isDownloaded` boolean — rejected: it cannot say *when*, so "downloaded then deleted" and "never downloaded" still share a value. (b) Keep the probe — rejected for the three reasons above. (c) Delete the row on delete — rejected: **B9** requires the chapter list complete whatever its length, and a 10 000-chapter novel would lose its chapter list because one file was removed.
- **Consequences**: `downloaded_at` exists in `schema.json` and is drift-guarded. **Schema version stays 1** — nothing has shipped, so this is a fix before release rather than a migration. Three tests cover it, including that deleting one chapter clears only that chapter's mark, and that `downloadedAt` and `isRead` are independent (B48 and B6 must not interact: downloaded is not read).

### ADR-020: No new-chapter notification in v1 — **superseded 2026-10-02**, see below

- **Date**: 2026-10-02
- **Status**: Active
- **Context**: `archetypes.md` § 2 names `notifications` among the five attendance modules of `mobile_consumer`, and states the standard plainly: *"Notifications et partage comme moteur de ré-engagement."* A standards review of `architecture.md` found the word appearing **zero times** across the architecture and `benchmarks.md` — no parity row, no ADR, no divergence line — while the design system leaned on it as an acquisition: it justified Updates at rank 2 with *"a serial novel generates the app's **only pull-loop**, and the pull is what brings the reader back"*, and said the Library is *"the screen the app must open **from** after a download or a new-chapter notification lands"*. **So the navigation's ordering argument rested on a mechanism the plan did not build.** That is a worse state than an honest omission, and it was the one finding that blocked the gate.
- **Decision**: **v1 ships no new-chapter notification, and this follows from B35 rather than from a preference.** B35 makes checking off by default and forbids the app checking on its own unless the reader opts in *and* picks an interval. With no check running, there is nothing to notify about — so the chain is **B35 (opt-in checks) → no automatic check → nothing to detect → nothing to announce → the pull-loop must be the reader opening the app**. A new-chapter notification becomes reachable the moment the reader opts into a schedule, at which point B37's foreground notification carries it; slice `6-4` owns that path and the roadmap already gates it on the §3.5 reduction being refused.

> **SUPERSEDED 2026-10-02 — the conclusion stands, the reasoning is now different, and it matters.** ADR-021 restored **B37** (a manual check as a visible, cancellable foreground job) to v1, and the Phase 4 red-team then withdrew **B35** itself to `prd.md` § 9. So the chain above no longer has a live link at either end. The two sentences that survive are: **"v1 ships no new-chapter notification"** and **"that is a parity gap, not a cosmetic one."**
>
> **What replaces the chain.** The notification is absent because **there is no automatic check in v1 to announce the result of** — and that is now a **scope** statement, not a rule-derived one. That is a weaker position and it is stated as weaker rather than dressed up: the old text claimed the design had no choice, and the choice existed. It was not exercised.
>
> **Why the choice was not exercised anyway.** A new-chapter notification is only worth firing when something fired without the reader; the only thing that can do that is the schedule, and the schedule is gone. A notification triggered by the reader's own tap (option *b* below) tells them what they just did. So the absence is **correct for v1 and would become wrong the moment the schedule returns** — which is the condition recorded in `prd.md` § 9 for restoring B35.
>
> **What did not change:** the cost line in `benchmarks.md` § 4b, and the correction to the design system's rank-2 justification for Updates. Those were the substance of this ADR and both are unaffected.
- **Alternatives considered**: (a) Ship notifications — rejected: honouring them would mean defaulting automatic checks on, which **contradicts B35 directly**. A design decision cannot override an approved business rule silently. (b) Ship a *manual* "a new chapter appeared" notification — rejected: it would fire only when the reader has just opened the app and checked, i.e. tell them what they just did. (c) Declare the absence without a reason — rejected: that is the failure being fixed. An absence with no chain is indistinguishable from an omission.
- **Consequences**: `benchmarks.md` § 3 gains a parity row (`no` in v1, `yes` in v2) and § 4 gains the cost line. **The design system's rank-2 justification for Updates is corrected** — it is a pull-loop *destination*, not a notification-driven one, and the wording now says so.

> **Appended 2026-10-02, because this sentence was false for the whole of a phase.** It claimed a correction that had **not** been made: `design-system.md` § 3.2 still read *\"a serial novel generates the app's only pull-loop, and **the pull is what brings the reader back**\"* — the notification-driven wording this ADR says it had replaced. **The Library rationale was corrected in the same pass; the Updates one was missed, and this ADR's own Context quotes the uncorrected sentence as the evidence for its finding.** The wording now says *\"the pull-loop is a destination the reader returns to, not a notification that brings them back\"*, and notes the second revision — ADR-023 removed the schedule the original sentence relied on. **An ADR that asserts a document was corrected is a claim about a different file, and it was checkable in one grep.** The real cost, stated plainly: **a serialised novel's reader must open the app to learn a chapter is out.** `benchmarks.md` § 2.2 records that competitors make progress notifications their primary re-engagement, so this is a real parity gap and not a cosmetic one.

### ADR-023: B35 (the opt-in update schedule) is withdrawn from v1 — a scope decision, recorded as one

- **Date**: 2026-10-02
- **Status**: Active
- **Context**: ADR-021 restored B37 and withdrew the roadmap's deferral of it. **It left B35 exactly where the deferral had left it — a live approved rule with no slice.** B35 is the *schedule*: off by default, plus a six-value interval picker. `roadmap.md` § 3.5 had deferred "B35's interval picker **and** B37's foreground notification" as a pair, and ADR-021 only unwound half of that sentence. Meanwhile `settings.md` and `updates.md` had both designed a real `CheckIntervalGroup` — anatomy, six strings, an interaction row, a data field, and a `V1 absent` alternative — for a control nothing would build. **A designed control with no slice is the same defect as a designed screen with no slice**, and it is the one this session has been removing everywhere else.
- **Decision**: **B35 is withdrawn to `prd.md` § 9 with its ID retained**, via `state.js amend` rather than left as a deferral. This is a **scope** decision and is labelled as one; it is not derived from any other rule. Three reasons, in weight order: **no success criterion requires it** — SC-3 is *"Library, history, and unread badges are correct"* and says nothing about checking, while `roadmap.md` § 4.1 defines v1 as exactly SC-1..SC-6; **it is the least verifiable subsystem in the project** — Android 13+ exact-alarm permission, background-start restrictions and Doze, none of which can be exercised under **Q-008**; and **its only purpose is to trigger a notification**, which ADR-020 removes.
- **Alternatives considered**: (a) Ship it — rejected, and not because it is hard: because it would ship **unproven**. The owner's instruction for this phase was that an unverified capability costs more than an absent one. (b) Leave it deferred — rejected: this is the defect. `roadmap.md` § 0 Rule 3 forbids deferring an un-withdrawn rule, and the PRD's mechanism for dropping one is a withdrawal that keeps its ID. (c) Keep the designed control and mark it `V1 absent` — **partly adopted**: both screens mark it absent rather than deleting it, so the design work is not lost.
- **Consequences**: **B36 and B37 both survive** — the reader taps *Check for updates* and sees a cancellable foreground job. Checking is not removed; the *schedule* is. Slice `6-10` carries B37 (ADR-021) and `6-4` carries B36. The **restoration trigger is in `prd.md` § 9**: Q-008 closes, the Android 13+ permissions are measured on a real phone rather than assumed, and a slice exists. Reversal cost is one slice plus re-adding one control and six strings to two screens. **This is the one scope reduction made without asking the owner**, and it is flagged as such in the Phase 4 bilan because the standing instruction is to copy Mihon, and Mihon has this feature.

### ADR-027: `2-6` owns `reading_positions`; `2-4` delegates the write and passes the extent it already holds

- **Date**: 2026-10-02
- **Status**: Active
- **Context**: A plan author found that **`2-4` and `2-6` both declared the `reading_positions` table** — `2-4` reproduced the whole drift class in its § 2.1 and wrote `reading_positions.offset` in its § 5, while `2-6` owned the column, the repository and the restore. Two plans for one file is the same defect as the designed-control-with-no-slice this session has been removing everywhere else, and it was invisible because both plans passed every gate. The same finding arrived with a second problem attached: `2-4`'s § 3.6 argued that preserving a position across a text-size change was *"the price of ADR-009, and it is conscious"* — a trade the project had refused **in writing** — which is now false, because `reading_positions.contentHeight` preserves it.
- **Decision**: **Three owners, one per layer, and a one-line contract between the two slices.** The **schema** belongs to the `local-store` foundation, which already wrote and tested it. The **repository, the restore and the re-anchor rule** belong to `2-6`. **`2-4` owns neither** — it holds `ScrollController.maxScrollExtent` after layout, so it calls `positionStore.write(chapterId, offset, contentHeight: extent)` and moves on. `2-4` § 2.1 now shows the table **for reading only**, with the pointer stated in the file.
- **The apparent conflict with ADR-009 was not one, and the reason is worth keeping.** ADR-009 chose a **pixel offset** over a fraction so a future paged mode could resume without converting every stored position. `contentHeight` stores a **height**, not a fraction — the pixel remains the stored value, and the quotient is **recomputed at read time and never persisted**. So ADR-009 is untouched, `2-4`'s original reasoning is *sound*, and only its conclusion was stale. A plan arguing against a change that turns out not to conflict with the rule it cites is still wrong — it asserts a price the project is not paying.
- **Consequences**: `2-4`'s § 3.6 is rewritten to say what ADR-009 protects and what `contentHeight` adds, rather than to refuse a preservation it now performs. `2-6` carries both restore branches: ratio when the height is known, **clamp and disclose** when it is `null`. The general form: *when two documents disagree, check whether they actually conflict before rewriting either* — one of the two claims here was simply describing a world that had moved.

### ADR-028: `core/error/` holds the exception hierarchy; `core/utils/` keeps the logger

- **Date**: 2026-10-02
- **Status**: Active
- **Context**: `13-error-handling.md` put the `AppException` hierarchy in **`core/utils/errors/`**. `architecture.md` § 1.2 and § 5.2 put it in **`core/error/`**. Two approved documents, one class, two paths — and **six live import paths across three plans** followed the wrong one. `core/` is declared a **leaf layer with no internal dependencies**, which is the deciding fact: `domain/` and `data/` must *catch* these exceptions, and a type under `core/utils/` is an internal of `core` that would have to leak upward to be caught at all.
- **Decision**: **`lib/core/error/`** for the hierarchy. The logger, which `13-error-handling.md` rule 6 also names and which `02-architecture.md` had listed **on the same table row**, **stays at `core/utils/logger.dart`** — a logger is a general utility, not an exception.
- **The part worth recording is the near-miss.** I first moved the logger too, on the reasoning that the two had been moved together before. They had not: they merely *shared a row*. **Two things on one table row share a fate whether or not they deserve to**, and the row was the only thing suggesting they belonged together. `02-architecture.md` now carries them as two rows with two reasons.
- **Consequences**: `core/utils/` is honestly described in § 1.2 as a general-utility home — markdown converter, chapter recognition, i18n helpers, the logger — and **explicitly not** the exception hierarchy. All six live import paths corrected. The general form, now hit three times in this project across three different documents: *fixing a path does not fix the paths that pointed at it*, which is why `http-client`'s acceptance criterion now greps for the old string and states where.

### ADR-026: `crypto` is added, because `Source.id` is an MD5 and nothing could compute one

- **Date**: 2026-10-02
- **Status**: Active
- **Context**: **`03-source-system.md` rule 1 and `B3` both require `Source.id` to be an MD5** of `'${name.toLowerCase()}/$lang/$versionId'`. `dart:convert` has no MD5. `pubspec.yaml` declared no hashing package. So the id rule — the thing that makes a source's data stable across renames and across installs, and the property `novels.id` embeds — was **unbuildable as written**, and `architecture.md` § 1.1 said *"Nothing else may be added"* without noticing that what it had added could not satisfy the contract three sections below it. Found by a plan author implementing `2-1`, who pinned the three exact MD5 values in the test plan so the composition is fixed regardless of route.
- **Decision**: **`crypto` 3.0.7 is added**, via `flutter pub add` and never by hand. It is a **dart.dev** package, **pure Dart**, no native code, no FFI, no platform channel — nothing `17-security.md` rule 13 bans. MD5 here is an **identifier**, not a security primitive: the input is three short public strings, the requirement is stability, and a collision would require two sources sharing a name, a language and a version. `crypto` also ships SHA-256, which is available if B3 is ever restated as a security claim.
- **Alternatives considered**: (a) Hand-roll MD5 — rejected: it is ~200 lines of bit-twiddling to produce a value whose only requirement is *stable*, and a hand-rolled hash is a thing to test against known vectors forever. (b) Use a plain SHA-256 of the same string — rejected: **B3 and rule 1 say MD5**, and silently changing the id derivation would invalidate every stored id while looking like a routine dependency bump. (c) Drop MD5 from the rule — rejected: the *stability* is the point, and the derivation is written down so a rename does not orphan a library.
- **Consequences**: § 1.1's "nothing else may be added" now carries **two** documented exceptions rather than pretending there are none, which is the point — a prohibition that has already been broken twice silently is worse than one that names its exceptions. `2-1` and `6-1` pin the three known vectors in their test plans, so a change to the composition fails a test rather than orphaning a library.

### ADR-025: B37's cancellation is in-app plus the platform's stop control — no notification action button

- **Date**: 2026-10-02
- **Status**: Active
- **Context**: B37 said a check runs as a foreground job with *"a visible notification **the user can cancel**"*. A plan author read that as a cancel button on the notification and could not find one, so it was measured rather than argued about. **`workmanager` 0.10.10 is federated** — the notification is built in `workmanager_android` 0.10.9, `ForegroundServiceUtils.createForegroundInfo`, which does exactly this: `setContentTitle`, `setContentText`, `setSmallIcon`, `setOngoing(true)`, `build()`. **There is no `addAction`.** `ForegroundServiceConfig` exposes `notificationTitle`, `notificationText`, `notificationChannelId`, `notificationChannelName`, `notificationId` and the foreground service type — **no action field**. `setOngoing(true)` also means the notification cannot be swiped away, so the reader has no path to stop the job from the shade.
- **Decision**: **Cancellation lives in the app, plus the platform's own foreground-service stop control where the OS offers one.** B37 was amended via `state.js amend` to say so, keeping the promise the reader relies on — *I started this and I can stop it* — and dropping the word that implied a mechanism the plugin does not have. **The intent is unchanged; the sentence is now true.**
- **Alternatives considered**: (a) Add `flutter_local_notifications` and build our own progress notification with an action — rejected for v1: it means a **second notification stack** alongside the one `workmanager` posts, two channels, two icon rules and two places to get a foreground-service permission wrong, bought for a convenience on a job the reader *just started while looking at it*. (b) Keep B37 as written and mark it unimplemented — rejected: that is the defect ADR-021 was written to close. (c) Drop the foreground job entirely and run the check in-process — rejected: then there is no notification at all, which is most of what B37 asks for.
- **Consequences**: `6-10`'s plan records the nine terminal branches it can actually reach, and the notification's copy names what it is rather than offering a button that is not there. **This reopens the moment a check can start from outside the app** — which is exactly what B35's withdrawn schedule would have done, and what a notification *action* exists to serve. `prd.md` § 9's restoration trigger for B35 therefore inherits this one: if the schedule returns, the cancel affordance is rebuilt rather than inherited, and ADR-025 is superseded.
- **The general form:** *a rule that names a mechanism is a claim about a third party's API, and it decays.* B37 was written when `workmanager` was a black box. The fix was not to weaken the rule's promise but to **measure the API and then say what is true** — the same move as ADR-022, where a rule's letter was satisfiable while its intent was not.

### ADR-024: `novels.author` and `novels.description` are stored — displayed, never searched

- **Date**: 2026-10-02
- **Status**: Active
- **Context**: A coverage audit found a three-way disagreement nobody had noticed. `06-database.md`'s *suggested* `NovelsTable` listed `author`, `artist`, `description`, `genres`. The committed schema had **none** of them. And **five bindings across four screen files** read `novel.author`, while `novel-details.md` said in terms that it is *"site, **stored**"*. Meanwhile **B42** had been withdrawn for assuming author and genre were stored *as searchable fields*, and **B45** replaced it with title-only search. So the rule file said "store them", the schema said "no", the screens said "stored", and the PRD said "don't make them searchable" — and all four were individually defensible.
- **Decision**: **Add `author` and `description` to `novels`, both nullable, both display-only, both unindexed.** `artist`, `genres` and `memo` stay out. The distinction that resolves it is between **storing a value for display** and **making it queryable**, and the earlier conflation of the two is what produced B42's withdrawal.
- **Alternatives considered**: (a) Strike the bindings from the four screens — rejected: it deletes real, specified UI (a subtitle line, an author line, a details blurb) to satisfy a rule that never forbade it. (b) Keep them out of the schema — rejected: that is the state that was found, and `novel-details.md` was asserting a storage that did not exist. (c) Add them **and** index them — rejected: an index on `author` would make B45's title-only promise false in the database rather than merely unwritten.
- **Consequences**: 41 columns, up from 39; `schemaVersion` stays **1** because nothing has shipped. **B45 is now enforced structurally** rather than by assertion: `idx_novels_title` exists, and there is deliberately no index on `author` or `description` — a test asserts their absence, so "not searchable" is a property of the database and not a sentence in a rule file. **B44** is honoured at the boundary: markup is never stored, so there is no HTML here to sanitise at render time. Nullable rather than empty-string because `library.md` specifies that an absent author collapses the subtitle line rather than showing an em dash — absent and blank are different states and this is where they differ.

### ADR-019: Android phones only — no tablet layout, no desktop, no two-pane

- **Date**: 2026-10-02
- **Status**: Active
- **Context**: Mihon is a two-pane app: `HomeScreen` picks `NavigationSuiteType.NavigationBar` on phones and `NavigationRail` on tablets via `isTabletUi()`, `SettingsScreen` opens a `TwoPanelBox`, and `SettingsMainScreen` pins the settings list in the start pane. `design-system.md` then cited **ADR-010** for "no tablet layout" in three places. ADR-010 is not that decision — it is *v1 is personal use: no sharing, no export, no backup*, a legal-posture choice. **An ADR cited for something it did not decide is worse than no citation**, because it makes a reader believe the platform scope was considered when it was never written down.
- **Decision**: **v1 targets Android phones.** Past `--bp-mobile` the layout stops growing and centres. **No rail, no two-pane settings, no wider result grid, no desktop target.** Flutter desktop is out of scope.
- **Alternatives considered**: (a) Keep Mihon's tablet behaviour — rejected: it doubles the layout surface for a device the owner does not have, and `archetypes.md` § 2 rates a phone-first reading loop as the archetype. (b) Ship "cap and centre" past 600dp and call it a tablet app — rejected: it is the same layout with a wider margin, so calling it a tablet layout would claim something not built. (c) Defer tablets to v2 — **chosen**, and recorded as such so v2 inherits a decision rather than starting one.
- **Consequences**: `design-system.md` § 1.7's "cap and centre" policy is the whole tablet story, and it is what every screen's § 6 repeats. `benchmarks.md` § 3's parity row for tablet layout reads `no / possible`, and § 4 now carries its cost. The rail and two-pane code in Mihon's inventory are excluded with this ADR as the stated reason, which `_mihon-verdicts.md` § 9 already argued on frequency grounds — this gives that argument a name.

### ADR-012 superseded — v1 success criteria

**ADR-012 listed five criteria. The PRD now has six, and SC-1 has changed shape.** ADR-012 remains `Active` in the table above, which is how a zeroed-context session would read it and be told v1 succeeds when "FanMTL and Royal Road are browsable, **searchable**". Two amendments were missed when they landed, which is the root cause and is recorded below.

- **SC-1** was amended by **ADR-015** (v1 claims *browse by genre*, and *search where — and only where — the site genuinely implements it*, B50). On measurement **FanMTL has no usable search at all**, so a v1 that read ADR-012's wording would be unachievable by construction.
- **SC-6** ("a broken site is reported, never presented as empty") has no counterpart in ADR-012, and `prd.md:591` says it exists "**for no other purpose**". A five-item list cannot describe a six-criterion v1.

**The root cause, and the mechanism that would have caught it.** `DECISIONS.md` is append-only and states that changing an entry requires "an entry that supersedes it". ADR-015 amended the PRD via `state.js amend` and **stopped**. It did not touch ADR-012, which is the document that *established* the criteria. Same for ADR-019 and ADR-013. **Every ADR that changes a prior ADR must supersede it here, or the corpus carries two truths.**

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

### ADR-013: All three v1 sources are adapters over one platform contract

> **Amended 2026-10-02:** the title's "all three v1" is inaccurate against **B1**, which is *exactly two* sites (FanMTL, Royal Road) with Novel Fire conditional on Q-004 and never counted against v1's success. The **contract** covers three sources; **v1** ships two. `roadmap.md` places Novel Fire after V1, not inside it.; FanMTL is built first

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
---

## Plans' open questions — registered 2026-10-03, because nothing else would revisit them

**Twenty-nine questions live inside seven plans.** Each is *well* done: costed, with a
cheapest-reversible option named, in the exact form `AGENTS.md` § "When blocked" asks
for. **The defect is that none of them was ever registered here**, so none had a
closing trigger and none would have been looked at again. A question inside a plan is
a note to the next reader of *that plan*; this project has 38 plans and a reader does
not come back to one.

`AGENTS.md` is explicit: *"A design is undecided and it changes the architecture →
write it as an open question in `DECISIONS.md` **with its closing trigger**."* These
were undecided, several of them architectural, and the register was skipped.

**Each row's trigger is written so it can be *checked*, not merely read.** Where the
trigger depends on something no plan can produce — a device, a measurement — it says so
rather than inventing a condition.

| # | Question | Lives in | Closes when |
|---|---|---|---|
| Q-009 | Who builds the 10 000-chapter list — a fixture that large, or a generated one? | `0-1` § 7 | `2-2`'s cleaner has a chapter-list fixture **of that size**, and its test runs against it. Until then the question is unanswerable, not merely open |
| Q-010 | Is FanMTL's chapter list paginated (`chapter-list-page1`)? | `0-1` § 7 | The fixture set contains either a second chapter-list page **or** a captured proof that there is none. One fetch of the real site settles it |
| Q-011 | Is FanMTL's per-chapter pagination real (E3 / B8)? | `0-1` § 7 | Same: a captured multi-page chapter, or a captured proof of a single page. `2-2` cannot join fragments it has never seen |
| Q-012 | Who writes the empty-signal verdict into the UI, and in what form? | `0-2` § 7 | `0-2` has run against the frozen fixtures and recorded a yes/no in `18-external-contracts.md`. **That record is the trigger and the answer at once** |
| Q-013 | Is Royal Road's chapter list complete on one page? | `0-3` § 7 | Royal Road fixtures are frozen and compared against the site's own `data-chapters` count — which **is** measured, so this closes the moment `0-3` runs |
| Q-014 | Does Royal Road have working search? | `0-3` § 7 | **`6-11` runs.** It exists precisely to measure this, and `6-2`'s condition is undecidable without it. The cheapest reversible option is already taken: ship `6-2` last |
| Q-015 | Who classifies Royal Road's chapter pages? | `0-4` § 7 | `0-4` has read a real Royal Road chapter page. **The edge `6-1 → 0-4` now exists**, so this cannot be skipped by accident again |
| Q-016 | Does a chapter page's nav block really hold thousands of links? | `0-4` § 7 | Same capture. Affects `2-2`'s cost, not its correctness |
| Q-017 | Who owns `/library/novel/:novelId/chapter/:chapterId`? | `0-5` § 7 | **Resolved 2026-10-03**: no screen pushes it, `design-system.md` § 3.5 removed it, and it is not declared. Row retained so the decision is not re-litigated |
| Q-018 | Which icons for the five tabs? | `0-5` § 7 | `design-system.md` § 3.2 declares them, or `0-5` picks Material 3 defaults and § 3.2 is corrected. **Not an architecture question** — a two-line edit either way |
| Q-019 | `navMore` does not exist in either ARB file | `0-5` § 7 | `localisation` runs. ADR-018 requires a fifth tab and it has no label in either language |
| Q-020 | ~~`more.md` § 3 still lists `Stats` and `Sources`~~ | `0-5` § 7 | **Resolved 2026-10-03** — `more.md`'s anatomy, empty state and rule attributions were cascaded. Struck so the next reader does not re-investigate |
| Q-021 | Four screens have no named slice | `0-5` § 7 | **Resolved 2026-10-03**: `3-6` and `3-7` were added, `/library` → `2-5`, `/updates` → `6-3`, `/more` → `0-5` |
| Q-022 | What is the first-launch trigger, and where does it live? | `0-5` § 7 | `3-4` lands. `shared_preferences` has no row for it and `onboarding` has no route guard yet |
| Q-023 | `test/widget_test.dart` looks for `find.byType(MaterialApp)` | `0-5` § 7 | **Resolved when `0-5` lands** — `MaterialApp.router` is still a `MaterialApp`, and if it is not, the test is corrected **with the reason recorded**, never silenced |
| Q-024 | `/more/settings/about` has two owners | `3-7` § 7.2 | `state.json`'s note for `3-7` and `3-5`'s agree on one body owner. **`3-5` implements the screen; `3-7` pushes the route** — recorded, but the two `state.json` notes should be collapsed into one |
| Q-025 | No slice owns the `search-unsupported` string, nor `ErrorState`'s | `localisation` § 7 | `6-7` runs and the ARB inventory covers both. **Blocked on nothing** — it is simply unassigned work |
| Q-026 | `source-unavailable.md` § 4.1 uses French placeholder names | `localisation` § 7 | `6-7` runs. Measured on the installed SDK: **renaming a placeholder in a translation *adds* a required parameter** rather than renaming one, so `{statut}` becomes a third argument |
| Q-027 | The five tab labels live in two places | `localisation` § 7 | `design-system.md` § 3.2 and the ARB agree, or § 3.2 points at the ARB and stops restating the labels |
| Q-028 | **Where does the `Novel` that B12's tap needs come from — and option (b) is WRONG** | `3-2` § 7, found 2026-10-04; **corrected the same day** | `3-2`'s action row exists. `/library/novel/:novelId` carries an **id and nothing else**, while `addWithSimilarTitleCheck` — which `2-5` already exposes as a **function**, so B40's default stays one layer from the branch honouring it — takes a **`Novel`**. ⚠️ **The first version of this row proposed reading the `Novel` back from the library by id, and that cannot work: B12's button appears precisely when `inLibrary == false`, and a novel that is not in the library has no stored row to read.** The option was cheap, reversible and wrong, which is the worst combination available. The real position: the details screen is reached from **two** places with **different** holdings — the library, where the novel *is* stored and `readById` would work, and the catalogue, where it is **not** stored and the `Novel` is in the caller's hand. §3.1 also admits a novel reached with **neither**: a restored stack or a deep link. So there are three holdings, not one. **(a)** the route carries the novel's fields — works for all three, but puts a title in a URL, where a stale link can change what the screen says the book is, and `architecture.md` §3.1a keeps `app/` out of feature models; **(b')** `openNovelDetails(context, novel)` passes the object through navigation for the two cases that HAVE one, and the screen renders slot 1 as *absent* for a novel it cannot describe — honest, but it means B12's button is missing on exactly the deep-link path §3.1 calls out; **(c)** a `NovelDetailsController` that resolves from the library when present and otherwise carries the pushed one — the most machinery, and the only option where the two paths cannot disagree. **Cheapest reversible meanwhile: (b')**, unbuilt, and it is the honest gap rather than a hidden one. Four ARB keys — `chapterListMarkAllRead`, `chapterListDownloadAll`, `chapterTileNotDownloaded`, `chapterListLoadExplainer` — are already translated and have **no caller in `lib/`**, because the row they belong to does not exist yet |

**The general form, and it is the same one as four times already:** *a decision
recorded in the place where it was made is not a decision anybody will revisit.*
Nine of these closed the moment they were written down, which is the point — six of
them were open only because nobody had looked. The other twenty are genuinely open
and now have a condition attached, which is what `AGENTS.md` asked for in the first
place.

**What is deliberately not here.** `0-4`'s two questions are measurements of Royal
Road, and `6-11` is the slice that exists to measure the search half; both are
recorded above against the slice that closes them rather than as open questions of
their own, because a question whose answer a scheduled slice will produce is a task,
not a question.
