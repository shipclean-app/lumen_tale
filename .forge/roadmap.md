---
type: roadmap
status: draft
generated_at: 2026-10-02
derived_from: .forge/prd.md
version: 1
---

# Roadmap — Lumen Tale

> This document defines **WHAT will be delivered and in what order**.
> It derives from `.forge/prd.md` (approved, v2), `.forge/benchmarks.md` and `.forge/state.json`.
> Every business rule, edge case and constraint cited carries its PRD identifier (B*, E*, C*), so any row
> here can be traced back to an approved requirement and forward to a slice and a test.
>
> The roadmap is alive — it changes when real use contradicts it.

---

## 0. How to read this document, and three standing rules

**Rule 1 — No calendar.** The project owner has explicitly refused calendar dates: a date we cannot keep is
worse than none. Every version is therefore defined by an **ordering and an exit criterion**, never by a target
date. "Reached when" below means: when the exit criterion is met, the version exists. A version that meets its
criterion early is not held back, and one that fails it is not declared.

**Rule 2 — Size is relative.** Effort is S/M/L/XL and slice counts are planning estimates only. Slice
decomposition belongs to Phase 4; the numbers here exist so the *relative* weight of each version is visible
and arguable, not so it can be summed into a schedule.

**Rule 3 — Scoping does not override the PRD.** This document decides *when* and in *what order* the approved
requirements are addressed. It does not weaken, reinterpret or drop any of them. Where I believe a version as
constrained by the ADRs is too large to be delivered at the required quality, §2.4 and §3.5 say so loudly and
name the trade instead of quietly shrinking the version.

### 0.1 The two facts that drive every decision in this document

1. **The owner's stated "wow moment" is: *a downloaded novel opens with no signal*** (`.forge/prd.md` §3 US-05,
   (`prd.md` § 10 SC-2, `prd.md` § 11 glossary). That is a **sequencing signal, not a nice-to-have**. It is the reason the build order
   in §8 starts at storage and the reader and reaches browse last.
2. **The product's structural advantage is B31** — installing a new version over an existing one preserves the
   library, every downloaded chapter, all reading positions and the history. `.forge/benchmarks.md` §2.3 shows
   that reinstall data loss is *the single most-complained-about failure* across the commercial apps, and that
   they cannot fix it because their library lives on a server. This is the one place where we are structurally
   better than the competition, and it appears as an explicit, repeated, testable drill at both gates (§2.1,
   §3.1) rather than as a promise.

### 0.2 An honest word before the tables

`benchmarks.md` § 3 lists a wide parity grid. Reading it against `prd.md` § 1.4 of the PRD produces an uncomfortable
conclusion worth stating up front:

> **Of the seventeen user stories, exactly three carry differentiation: US-05 (offline read), US-16 (a broken
> site reported rather than shown as empty) and US-17 (which is where B31 lives). Everything else is parity work
> that Dreame, Webnovel or Mihon already do.**

Parity work is not worthless — parity is the *price of being usable* — but it must be recognised as such, so
that effort is not spent on it as though it were the wedge. The MVP is therefore built around the three
differentiators plus the minimum parity needed to reach them, and the parity stories that are not on that path
(search, updates, history, second language) are scheduled by their cost, not by their excitement.

---

## 1. Version vision

| Version | Theme / promise | Primary success criterion | Reached when |
|---|---|---|---|
| **MVP** | **"One novel, one source, read it with the radio off."** The claim is proven at minimum scale: one FanMTL novel, chapters fetched and stored, read with connectivity physically switched off, and preserved across an upgrade. | **SC-2 at scale 1** — a downloaded chapter opens and scrolls to the end with the network off — **plus SC-5** (one verified install from an automatically built APK) and **SC-6** (a broken site is reported, never shown empty). | The offline read path is demonstrated on a real device with the network off, and the upgrade drill has been run once. See §2.1 for the full exit list. |
| **V1** | **"The whole daily loop, for two sites."** Downloads scale from one chapter to a whole novel; the library, history, unread counts and the second site become real; both languages are complete. | **SC-1..SC-6 all met** — FanMTL *and* Royal Road browsed by genre and read end to end, and searched only where a site's own search measures as genuinely usable; 50 chapters downloaded and read offline; library/history/badges correct; FR and EN complete; installed and proven on the owner's phone; a broken site reported as broken. | All six success criteria are satisfied on the device, and the upgrade drill has been run a second time with a larger library. See §3.1. |
| **V2+** | **"Parity with the apps we replace."** The reading modes both competitors ship, true background download, scheduled checks, the third site. | No criterion yet — see §4.0. V2 has no measurable target because the PRD left no P3/P4 backlog; V2 is defined by its **opening conditions**, not by its content. | Not planned. Rebuilt from the first year of real use. |

**Dependency direction:** V1 depends on the MVP existing and being *correct*, not merely present. Every V1
slice assumes the atomic storage, the failure discriminator, the identity stability (B3) and the schema
versioning (B31) of the MVP. There is no V1 slice that can be built before the MVP gate, and none that could
plausibly be moved before it without re-doing it later.

---

## 2. MVP — Minimum Viable Product

> The smallest set that solves the main problem (a web novel that stays readable with no signal) and can be
> used by a real person — not a demo, not a prototype.

### 2.0 Why this roadmap does not start with browse

The obvious order for a reader app is **browse → read → download**. It is wrong here, for five reasons, and the
reasons are structural rather than stylistic:

1. **It optimises the visible, and the visible is not the product.** Discovery is the one capability every
   competitor is better at; we would be building our weakest suit first and calling it progress. The offline
   claim is the one thing they *structurally cannot* copy (`benchmarks.md` §2.3).
2. **Every early success signal would be a network signal.** Browse-first means each "it works" during weeks 1–4
   proves that *an online pipeline* works. The product claim is only exercised with the radio off. Build order
   should put the claim on the critical path while it is still cheap to change.
3. **It makes the most expensive failure the latest one.** If the stored representation of a chapter turns out
   to be wrong for offline reading — text size clamping, a scroll position that is meaningless once stored,
   a chapter too large to render — the fix is a change to the *format*, and a format change invalidates every
   reader screen built on top of it. That discovery belongs in the first third of the project, not the last.
4. **It hides the two failures most likely to occur in real use.** The PRD's top risk (HIGH/HIGH) is a site
   changing and the app silently returning nothing, and constraint C8's danger is a partial download presented
   as complete. Neither is visible to a browse-first demo. Both are *loud* in an offline-first build, because
   the build immediately depends on the stored copy being right.
5. **Effort is asymmetric between the two ends.** Browse (US-01, US-02) is the cheapest code per unit of value
   once a source contract exists, and it can be added later without rework. Storage, atomic writes and the
   offline read path are the most expensive things to add late.

**The counter-argument, stated so it is not dismissed.** Parsing surprises live in real HTML, and browse-first
meets them on day 1 while offline-first defers them. That is a real cost. §8 answers it with **Wave 0**: capture
and freeze real fixtures from FanMTL *before any feature code exists*, so the HTML surprises land immediately
even though no UI is built yet. What fixtures cannot do is reproduce a site that changes at three in the
morning — that cost is accepted, not eliminated, and it is why the MVP gate includes one live network run
before the radio goes off.

### 2.1 Scope — the scoring behind the cut

Value 1–5 (how essential to the main problem), complexity 1–5 (relative to the other stories in this project).
"Delivered" says whether the MVP ships the story **whole** or **in part** — a story delivered in part has
acceptance criteria that are *not* met at the MVP gate, and that is stated rather than glossed.

| US | Story | Value | Cx | Dependencies (US) | Main risk | Differentiating | Delivered | Where the rest lands |
|---|---|---|---|---|---|---|---|---|
| US-05 | Read a downloaded chapter with the connection off | 5 | 3 | US-04, US-06, US-09 | **HIGH** — the claim itself is unproven until the radio is off | **YES — the product** | **full** | — |
| US-06 | Download a single chapter | 5 | 3 | US-03 | MED — atomicity (B6); a partial chapter shown as complete is unrecoverable data loss (C8) | partial | **full** | — |
| US-04 | Read a chapter in the reader | 5 | 5 | US-03 | **HIGH** — the HTML→clean→text conversion is the largest unknown technical risk in the project | partial (no ads/furniture) | **full** | — |
| US-09 | Keep a novel in the library | 5 | 3 | US-03 | MED — B32: removal must never destroy downloads, and there is no backup (C8) | no — but it carries B32 | **part** (add / remove / list / open, B11, B12, B32, B33) | badge + B40 + B45 → **V1** |
| US-11 | Resume exactly where I stopped | 5 | 2 | US-04 | LOW — but B46/B47 are a live trap: any retention rule that touches positions is unrecoverable | partial (with B31 → the wedge) | **full** | — |
| US-16 | Be told when a site stops working | 5 | 2 | none | LOW build risk, **HIGH** design risk — B22's "genuine nothing" vs "could not read" discriminator is subtle and site-specific (see §7.2) | **YES (weakly)** — competitors show empty | **full** | — |
| US-17 | Get a new version as a file | 5 | 2 | US-16 | MED — the CI build has never been exercised; SC-5 is unproven (Q-003) | no (but it carries **B31, the wedge**) | **full** | — |
| US-03 | Novel details + full chapter list | 4 | 3 | US-01, US-16 | MED — 10 000 chapters must list completely and in order (B9, E1) | no | **full** | — |
| US-01 | Browse a site's catalogue | 3 | 3 | US-16 | MED — site layout churn (C7); entry point for any real use | no | **part** — one source, list with title and cover where offered; **no** description, **no** search, no paging polish | description/paging polish → **V1** with US-02 |
| US-14 | Read at night in dark mode | 4 | 2 | US-04 | LOW | no — table stakes, both competitors ship it (`benchmarks.md` § 3 and § 5) | **full** | — |
| US-15 | Read at my own text size | 4 | 2 | US-04 | MED — clipping/overlap at the largest size (E14) | no — table stakes | **full** | — |
| US-07 | Download a whole novel as a queue | 5 | **5** | US-06 | **HIGH** — a persistent state machine (B19, B21, E15) plus six bulk choices (B18) plus storage exhaustion (E20) | no — everyone has it | — | **V1** |
| US-08 | Watch and control a running download | 3 | 3 | US-07 | MED — cancellation must be prompt and final (B19) | no | — | **V1** |
| US-02 | Search within a site | 3 | 2 | US-01, US-16 | LOW mechanically (B41 is a pass-through) but **gated**: unavailable unless the site genuinely implements search | no | — | **conditional** — a per-source slice that ships only for a site measured as genuinely searchable (B50, ADR-015). FanMTL does not, so it is **not** in V1 for FanMTL; Royal Road is unchecked |
| US-10 | See which novels have new chapters | 3 | 4 | US-09 | **HIGH** — background execution, scheduling, and the B48/B49 local-vs-checked split; unverifiable without a device | no | — | **V1** (see §3.5 reduction) |
| US-12 | Review what I read recently | 3 | 2 | US-04, US-11 | LOW build risk, MED design risk — must not touch positions (B46/B47) | no | — | **V1** |
| US-13 | Whole app in French or English | 4 | 2 | — | LOW | no — parity | — | **V1** |

**The MVP cut: 11 stories delivered, 9 of them whole, 2 in part. Estimated 14–18 slices. Size: L.**

That is large for an MVP, and §2.4 says so rather than pretending otherwise.

**Two inclusion decisions that contradict the PRD's own priorities, stated openly:**

- **US-14 and US-15 are in the MVP despite being P2 in the PRD.** They are there because the MVP must test a
  third hypothesis, not just two: *will Anaïs actually read a long session in this reader instead of in her
  browser?* A reader that is white-blasted at 11pm on a phone fails that hypothesis regardless of how well
  the offline path works. They are also cheap (2 each) and they carry accessibility obligations (E14), which is not optional.
- **US-09 is in the MVP despite being P2.** US-05's own acceptance criteria say the novel "opens **from the
  library**" with the connection off, and C14 forbids any network call to open the library. Without a library
  there is no offline entry point, and the wow moment is unreachable. P2 in the PRD, MVP in this roadmap.

### 2.2 What is NOT in the MVP

| Element | Why excluded | Risk of exclusion | Target |
|---|---|---|---|
| US-07 — download a whole novel as a queue | A queue is a persistent state machine with six bulk choices (B18), pause/resume/cancel (B19) and restart-survival (B21). Building it against a storage format that has not yet been proven by a real offline read is how the format gets built wrong. | Medium — the owner re-downloads chapter by chapter until V1. Acceptable: single-chapter download is a complete escape hatch. | V1 |
| US-08 — watch/control a running download | Nothing to watch while downloading one chapter at a time by hand. | Low | V1 |
| US-02 — search within a site | B41 makes it a pass-through of the reader's words to the site, and it shares every piece of machinery already in the MVP. **But B50/ADR-015 removed its reason to be in V1 at all**: it was justified as "SC-1 requires it", and SC-1 no longer does. On FanMTL it is not implementable, and the owner is explicit that feeding a novel's own tags into a site's search bar "ain't satisfying at all". | Low — to reach a known novel the owner browses genres, which is how these sites work, and a novel's detail-page genres are the good way in. | **conditional**, not a version — it is per-source, decided by measurement. Royal Road must be measured before it can be promised. |
| US-10 — new-chapter detection | Depends on the library being real (US-09b) and is the least verifiable subsystem in the project. | Low for the MVP: nothing in the MVP claims to notice new chapters. | V1 |
| US-12 — reading history | A list over data that will exist; and B47's retention rules must never touch reading positions (B46), which is a trap worth meeting only once positions are proven. | Low — resume (US-11) already covers "pick up where I left off". | V1 |
| US-13 — English UI | The owner reads in both languages; the *owner* navigates in French. What ships in the MVP is the **mechanism** (every string in the localisation catalogue, French fallback), not the translations. | Low — translating is additive work on strings that already exist. | V1 |
| US-09(b) — unread badge, similar-title warning, title-only search | Each depends on the counting model that belongs to US-10 (B48/B49). Shipping a badge before the counting model exists produces a number that can go stale, which B14 forbids. | Medium — the MVP library shows no new-chapter indication at all, so "what is new" must be judged by eye. | V1 |
| US-01(b) — descriptions and paging polish | Cosmetic; it delays the offline claim without testing anything. | Low | V1 |

### 2.3 Risks specific to the MVP

| Risk | Probability | Impact | Mitigation |
|---|---|---|---|
| **Q-003 — no real-device verification.** The MVP exit criterion is physically impossible without a phone in the loop, and no document in `.forge/` records that one exists. | HIGH | **HIGH** — every exit criterion in §2.1 becomes unverifiable, and the §7.1 performance targets stay definitions | §7.1 places this at Wave 1 (build the APK) and at the MVP gate. If it has not resolved by the MVP gate, **the honest outcome is that the MVP gate cannot be held** — not that the MVP ships on emulator evidence. |
| **The HTML→clean→text conversion does not produce readable text on the first real site** | MEDIUM | **HIGH** — US-04 is the largest single slice and everything renders through it | Wave 0 captures real fixtures before any code. The E18/E22 threshold rules are specified in the PRD precisely because "short" and "broken" must not be confused. |
| **B22 has no site-provided discriminator to build on.** B22 requires distinguishing "genuinely nothing" from "could not read" **using the site's own explicit empty-result signal**. If FanMTL has none, B22 as written is not implementable for that source. | MEDIUM | **HIGH** — B22 underpins US-16, and SC-6 exists only to verify it | Raised as an open premise in §7.2 — **this is a PRD premise that must be checked against FanMTL's real pages in Wave 0**, and it may require amending B22 before US-16 is specified. Not resolved here: scoping does not rewrite approved rules. |
| A stored chapter turns out to be unrepresentable at the phone's largest text size | LOW | MEDIUM — a reader-side fix, but late | US-15 is in the MVP, not deferred, precisely so this surfaces at Wave 2 with the reader, not after V1. |
| The offline path is correct but the first live run is not reproducible — a site changed between fixture capture and the gate | MEDIUM | MEDIUM | The MVP gate includes one live network run before the radio goes off, so a changed page is reported by B22 rather than discovered as a mystery. |
| Scope discipline erodes once the browse UI is visible | MEDIUM | MEDIUM | §8 fixes browse last, and the MVP's browse is explicitly partial (§2.2). Anything added to the browse surface before the MVP gate moves to V1 by default. |

### 2.4 Is this MVP too big? — an explicit answer

**Yes, and it cannot be made small without changing what it proves.**

Eleven stories and roughly 14–18 slices is at the top of what an MVP may legitimately be. I want that on the
record rather than buried, because the failure mode this project is most exposed to is not an ugly MVP — it is
an MVP that grows, because every visible thing on a browse screen looks like one more small thing.

The reason the MVP cannot be shrunk further is structural: **the "wow moment" in this project is a guarantee
across storage, delivery and upgrade, not a feature.** If it were a feature, the MVP would be five stories
(fetch, convert, read, store, read offline). Because it is a guarantee, it drags in the library (offline entry,
C14), reading position (US-05's own acceptance criteria), failure reporting (a broken source must not look
like an empty one), delivery (SC-5), reader comfort (the hypothesis test), and identity stability plus schema
versioning (B3, B31 — positions must survive an upgrade). Each of those is individually small and jointly
irreducible.

**A leaner MVP exists, and I recommend against it.** Cutting US-14, US-15, US-01(b) and US-09(b) gives a
**7-story MVP** at roughly 9–11 slices, size M. What it costs: the MVP no longer tests "will she actually read
in it", the first offline demo happens on a phone that may be in light mode, and the owner judges comfort
later than she would have. What it buys: two to four weeks of apparent progress. **This is the owner's call at
the gate, not mine** — it is recorded here so the option is visible and priced rather than quietly taken.

**Recommendation:** keep the 11-story MVP, and hold the line on §2.2 — the browse surface stays partial and
stays last even though it is the most satisfying thing to build.

---

## 3. V1 — First complete version

V1 = the MVP, plus what makes the difference and what the success criteria demand. It is defined by **SC-1..SC-6
and nothing else**: anything not required by one of those six criteria, and not needed to make one true, is
V2.

### 3.1 Additions relative to the MVP

| US / item | Rules | Why in V1 | Criterion it satisfies |
|---|---|---|---|
| US-07 — download a whole novel as a queue | B18, B19, B20, B21, E7, E15, E20 | SC-2 requires **fifty** chapters downloaded and read offline. Hand-downloading fifty chapters does not demonstrate a queue that survives the app being closed (B21), and B21 is what makes the promise honest for a 400-chapter novel. | **SC-2** |
| US-08 — watch and control a running download | B19, E7, E20 | Without it, the queue runs unattended with no way to stop it — against B5 ("nothing is fetched unless the user asked"), against data-allowance concern (§8 risks) and against C11 (control on a phone, one-handed). | SC-2, and honesty under B19 |
| US-01(b) — complete catalogue browsed **by genre**, with description and paging | B24, E19, B2, B50 | SC-1 requires each source to be **browsed**; on measurement, genre browsing is the real discovery path and FanMTL has no usable search at all. This is the slice that makes SC-1 true. | **SC-1** |
| US-02 — search within a site | B41, B50, ADR-015 | **Held out of the committed V1 set.** It was pulled in only because SC-1 used to demand search; SC-1 no longer does. It is a *per-source* capability, so it cannot be a committed slice before Royal Road and Novel Fire are measured. | **none** — ships per source, when measured |
| **Royal Road as a second source** | B1, B2, B3, C1 | SC-1 names both sites. Two sources is also the only real test of the source contract: a second site is where a design that accidentally hard-codes FanMTL reveals itself. | **SC-1** |
| US-10 — new chapters | B13, B14, B15, B35, B36, B38, B39, B48, B49, E16 | SC-3 requires the unread badges to be **correct**. B48 makes the count a purely local fact; B49 makes the last-checked state visible. **B38 is the invariant to protect**: a check never starts a download, which is also what keeps the app polite to the sites (C7). | **SC-3** |
| US-12 — reading history | B17, B46, B47 | SC-3 names the history explicitly. | **SC-3** |
| US-13 — the whole app in French and English | B28, E12 | SC-4 requires both languages **complete, including error and download-status messages**. The mechanism already shipped in the MVP; only the English catalogue and the extraction of the error strings are new. | **SC-4** |
| US-09(b) — unread badge on library entries, similar-title warning, title-only search | B14, B40, B45 | B40 is the anti-merge guarantee (two identically-titled novels from two sites stay two novels, B2/E17); B45 promises only the field the app actually holds. Both are cheap once US-10's counting model exists. | **SC-3** |
| **The upgrade-safety drill, run a second time** | **B31**, C8 | §0.1: this is the wedge. Running it once in the MVP proves the mechanism; running it again in V1 proves it **with a real library, real downloads, real positions and a real history** — the actual claim the competition cannot make. | the differentiation claim |

**V1 must also carry, unchanged from the MVP, and re-verified at the V1 gate:** the three §7.1 performance
targets (§4.0), SC-6 (a broken site reported, verified against a captured fixture of a changed layout), and the
"no network call on the read path" property (C14).

### 3.2 What is pushed to V2+

| Element | Why not in V1 | Risk of the deferral |
|---|---|---|
| Paged / slide reading modes | ADR-009; B25 makes continuous scroll a v1 rule; the benchmarks grid places them at v2 | Medium — both competitors ship all three modes today, and a reader who wants page-turn will use them. Accepted knowingly (`benchmarks.md` §4). |
| Reading modes + orientation lock | ADR-009 | Low — v1 already scrolls correctly in both orientations per US-04 |
| Colour filters (sepia, inversion, per-chapter) | ADR-009 | Medium — night readers are our persona and sepia is the commonest request in this genre |
| **True background download execution** | **E7 states the queue runs in-process and has no background executor; the queue survives app closure by *resuming*, not by continuing.** | Medium-high — `benchmarks.md` §3 lists background download as a v1 capability, and Webnovel's published advantage is exactly this ("just works in the background"). See §7.2: this is a contradiction between two approved documents and needs the orchestrator to settle it. |
| Scheduled update checks with a foreground notification | B35's interval picker and B37 are the most device-dependent machinery in the project. Deferred **only if** the §3.5 reduction is accepted at the gate. | Low — B35 already requires checks to be **off by default**, so nothing is lost for the reader's battery in v1. |
| Novel Fire | C10, B1, E21 — conditional, **outside the version ladder entirely**. Not "v2". | None — see §7.1. |
| Additional languages beyond FR/EN | Not a PRD requirement at all; only `benchmarks.md` §3 mentions "more" | None |
| Tablet layout, desktop, web, store publication, `.txt`/EPUB/PDF reading, trackers, social features, in-app purchases | PRD §9; ADR-010; C-002, C-003, C-010 | None — these are **exclusions**, not deferrals. See §5.2. |

### 3.3 Risks specific to V1

| Risk | Probability | Impact | Mitigation |
|---|---|---|---|
| **V1 is XL and one person is maintaining two scrapers** | **HIGH** | HIGH — the PRD's own unknown: nobody has measured how often these sites change | §3.5. Delivery by merge-milestone rather than as a single event, each milestone independently usable. |
| The update subsystem (US-10) is the most expensive and least verifiable part of V1 | MEDIUM | HIGH — it needs a real device, a real OS scheduler and real battery behaviour | §3.5 proposes reducing US-10 to manual-only for V1. Recommend the reduction. |
| Royal Road proves to have a different page shape that invalidates the source contract | MEDIUM | MEDIUM-HIGH — the cost is a contract amendment, not a rewrite, **if** the contract was built as a contract (ADR-013) | Wave 0 captures Royal Road fixtures alongside FanMTL's, before the contract is frozen. |
| A 50-chapter queue fills the phone's storage | LOW | MEDIUM — E20 handles it, but it is only handled correctly if it is tested | E20 is an explicit test case in the V1 gate, not an assumption. |
| **B37's foreground notification is built and turns out to be unkillable/unclearable on the owner's device** | MEDIUM | MEDIUM | Only relevant if the §3.5 reduction is refused. Build it last in V1, after the manual path, so it can be dropped without cost. |

### 3.4 Inter-version dependencies

| V1 depends on | Nature | Critical? |
|---|---|---|
| Atomic chapter storage from the MVP (B6, B20) | technical | **yes** — a queue over non-atomic storage would queue corrupt chapters at scale |
| Schema versioning + migration from the MVP (B31) | technical | **yes** — B31 cannot be demonstrated on a store whose schema cannot be migrated |
| The failure discriminator from the MVP (B22) | technical | **yes** — a 50-chapter queue that meets one broken chapter needs B22 to not mark it as a "successful" chapter |
| Identity stability from the MVP (B3) | technical | **yes** — the queue resumes by identity; unstable IDs restart the novel (B21) |
| Reader-position storage from the MVP (B16, B46) | product | **yes** — US-12's history is defined *relative to* positions (B17) |
| The APK pipeline from the MVP (C9, ADR-011) | delivery | **yes** — V1 has nothing to be delivered by |
| **A real device (Q-003)** | external | **yes** — the queue's persistence (B21/E15), storage exhaustion (E20) and background behaviour cannot be verified in CI |
| FanMTL + Royal Road still working on the day of the gate | external | **yes** for SC-1 — and uncontrollable (C7) |
| Owner availability to make the Q-004 legal judgement | external | no — v1's success excludes Novel Fire (B1) |

### 3.5 Is V1 too big? — an explicit answer

**Yes. V1 is XL: 6 stories, one additional source, three sub-features, and roughly 12–16 slices on top of an
MVP that is already L. MVP + V1 is XL at roughly 26–34 slices, one implementer, one device, and one person who
is also the only person who can repair a scraper.**

I am keeping it XL rather than shrinking it, because the brief's constraint is exact: **V1 must be sufficient to
satisfy SC-1 through SC-6**, and SC-1 names two sources, SC-2 names fifty chapters, SC-3 names library, history
and badges, SC-4 names two complete languages. Any smaller V1 stops being "v1 done" and becomes something else.

**Two things make this survivable, and neither is an excuse:**

1. **V1 is a checkpoint on a stream of APKs, not a launch.** ADR-011 and C3 mean there is no store, no review
   process, no migration window and no support burden. Each milestone can ship to the owner's phone and be used
   that night. "V1 done" is when the six criteria are met, not when work stops.
2. **The criteria are attachable to milestones.** SC-2 lands with the queue (Wave 5); SC-1's Royal Road half
   lands with the second adapter; SC-4 lands with the translations. There is no moment where half the V1 is
   unusable.

**The recommended V1 reduction (owner's decision at the gate, not mine).** The one place V1 can lose real
weight without failing a criterion is inside US-10:

> Ship US-10 in V1 as **manual "update library" only** (B36), with the local count (B48) and the visible
> "last checked / never checked" state (B49). Defer B35's interval picker and B37's foreground notification to
> V2+. B35 already requires checks to be **off by default**, so the reader loses nothing they would otherwise
> have. SC-3 remains satisfiable. The rule against shipping a control that does nothing is absolute: an interval
> picker present but inert is a lie (B24), so the picker goes with the scheduler, not before it.

This removes the least verifiable, most device-dependent subsystem from V1 and costs one criterion-nothing.
**If the reduction is refused, my judgement is that V1 as specified is not achievable at the project's quality
bar by one person, and the right response is to renegotiate SC-3 — not to ship the update subsystem
half-verified.**

---

## 4. V2 and beyond

### 4.0 An honest statement about V2's contents

**`.forge/prd.md` contains no P3 or P4 user story.** Every story is P1 or P2, and every P2 story is required by
SC-3 or SC-4 and therefore belongs to V1. That means **zero PRD user stories are deferred to V2**, and a V2
backlog built from the PRD would be empty.

I will not invent stories to fill it — scoping does not redefine requirements. So V2 is specified here as a set
of **named deferrals with explicit origin** (an ADR, a PRD §9 exclusion, or a `benchmarks.md` parity cell) plus
**opening conditions** stating what must be observed before each is worth building. That is the most this
document can honestly say, and it is enough to stop the items being forgotten.

### 4.1 V2 backlog

| Item | Origin | Why it waits | Opening condition — what must be true to build it |
|---|---|---|---|
| **Paged / slide reading modes** | ADR-009, B25, `benchmarks.md` §3 | The reader is the largest subsystem and feeds the whole pipeline; a second scroll model on top of unproven storage is the wrong order | V1 shipped and the reader met the §7.1 frame budget on a real device |
| **Reading modes + orientation lock** | ADR-009, `benchmarks.md` §3 | Same subsystem, same reason | Same |
| **Colour filters (sepia, inversion)** | ADR-009, `benchmarks.md` §3 | Cheap to build, but it competes for attention with items that change what the product *is* | V1 shipped, and ideally one direct request from the owner |
| **True background download execution** (the queue continues after the app is closed) | E7, B21, `benchmarks.md` §3 | The approved PRD explicitly refuses it: the queue runs in-process and resumes. Making it continue is a different product promise with real battery and politeness costs (C7) | The contradiction in §7.2 is settled, **and** the battery cost of downloads — the PRD's own unmeasured unknown (§8) — has been measured on the owner's phone |
| **Scheduled update checks + cancellable foreground notification** | B35, B37 | Most device-dependent machinery in the project | The §3.5 reduction is accepted, **and** the owner has run the manual check enough times to know what interval they would actually pick |
| **Novel Fire** | B1, C10, E21 | Conditional, **not a version** | The owner confirms the terms (Q-004). Then it is added — whenever, or never. |

### 4.2 Ideas for V3+ (not requirements; recorded so they are not lost)

- **More languages beyond FR and EN** — depends on whether a borrowed-device reader ever asks (`benchmarks.md` §3 lists "more" only as parity).
- **Tablet / larger-screen layout** — the owner answered "phone only *for the moment*" (client point C-002), so this was never a requirement and reopening it needs a reason, not a schedule.
- **Local file reading (.txt / EPUB / PDF)** — PRD §9 declined it: the app reads web novels, it is not a document reader. Only worth revisiting if the owner ever wants the format.
- **Not adopting, on purpose:** Mihon's 4 library filter toggles, 10 sort modes and 4 display modes. More library controls on a phone the reader uses one-handed, reading, is friction, not feature. Recorded here so it is visibly a decision and not an oversight.

### 4.3 The three §7.1 targets that are "not yet measurable" — where each gets a number, or is deleted

`.forge/prd.md` §7.1 marks three targets as not yet measurable and owes each "a number or a deletion". A deferral
nobody discharges is a deferral that becomes a lie. Each is assigned a **trigger event** and a **deletion
deadline**:

| Target | When it must be resolved | What a number would look like | If the trigger is missed |
|---|---|---|---|
| **Long-list responsiveness** — browsing a catalogue and opening a chapter list of several thousand chapters stays usable (E1, B9) | **Wave 0**, against captured fixtures, and re-confirmed at the **MVP gate** on the device. This is the earliest of the three because the data exists as soon as a fixture does, and the threshold is cheapest to pick while designing the list rather than after. | A wall-clock threshold for opening a chapter list of N chapters on a named device, plus a statement of N. B9 already fixes the required behaviour (complete, in order, 10 000 chapters); §7.1 owes the *latency*. | **Deleted at the MVP gate.** A dropped target that has survived its first opportunity is not a target. Deleting it means US-03 is verified behaviourally (complete, in order, nothing dropped) and not performance-wise. |
| **Download-progress cadence** — progress is visible *while* the queue runs, not only at the end (US-08) | **Before the US-08 slice is specified** (Phase 5). The cadence is a property of the progress display, so specifying US-08 without it produces a display nobody can check. | A minimum update frequency for the progress indicator during a running queue. | **Deleted at the V1 gate.** The PRD's own requirement — progress is visible during the run — stands on its own and is still testable. |
| **Cancellation latency** — how quickly a cancelled queue actually stops (B19) | **Before the US-07/US-08 slices are specified**, same reasoning. | A bound on time between cancelling and the last fetch starting. | **Deleted at the V1 gate.** B19's testable form already exists and is stronger than a latency figure: *"no further chapter is fetched after it"* is a fact, not a measurement. |

**One line applies to all three:** the §7.1 frame-budget targets that *are* numbered (16 / 11 / 8ms against the
device's own refresh rate, measured with the SDK's own frame timings) are **targets, not measurements**, and
they stay that way until Q-003 closes. §7.1 is not discharged by writing numbers in it; it is discharged by a
device.

---

## 5. Assumed trade-offs

> The most important section of this document. Every exclusion is a conscious trade. Each row states what is
> **lost**, what is **gained**, and the **risk of the deferral**.

### 5.1 What is NOT in V1, and what that costs

| Trade-off | What is lost by deferring | What is gained | Risk of deferring |
|---|---|---|---|
| **No page-turn, slide or reading modes in v1** (ADR-009, B25) | Readers who prefer paginated text must scroll. Both competitors ship three modes today, and this is our persona's habit. | The reader subsystem — the largest single slice, and the one the whole pipeline feeds — is built once, in one mode, and proven against the §7.1 frame budget before a second model is layered on. A second scroll model on unproven storage is how the storage format gets built wrong. | **Medium.** Highest in the short term. Mitigated only by the storage decision being right: position is stored as a **scroll offset, not a page index** (ADR-009), which is what keeps v2 additive rather than a migration. If that decision is made wrong in v1, this deferral becomes expensive rather than merely inconvenient. |
| **No colour filters in v1** (ADR-009) | Sepia and inversion — the two requests a night reader makes most. | Focus. | **Medium.** The persona reads at night; dark mode does not fully answer that need. Cheap to add in v2 once the reader exists. |
| **Single-chapter download only in the MVP** (US-07 → V1) | The owner re-taps for each chapter in the MVP; 50 chapters is not a pleasant manual act. | The queue's persistent state machine (B18/B19/B21), the highest-risk piece of V1, is built once against storage already proven by a real offline read. | **Low.** Single-chapter download is a complete escape hatch, and the MVP is a checkpoint, not a shipped product. |
| **No in-background queue execution in v1** (E7) | The "just works in the background" advantage Webnovel is praised for. The queue must survive the app being closed by *resuming*, not by continuing. | No background scheduler, no battery cost, no OS-lifecycle surprises, and full compliance with E7 as approved. | **Medium-high, and partly unresolved** — `benchmarks.md` §3 claims background download for v1. See §7.2: the roadmap follows the PRD, and the contradiction is flagged rather than silently resolved. |
| **No search in the MVP** (US-02 → conditional) | The owner cannot type a title; they browse genres. | Nothing material — and note this deferral is now **permanent per source** rather than a scheduling choice, because FanMTL will never have it (B50). | **Low.** Pure convenience; no hypothesis depends on it. |
| **No new-chapter detection in the MVP** (US-10 → V1) | Nothing in the MVP notices a new chapter. | The most device-dependent, least verifiable subsystem stays out of the MVP, and no badge is ever shipped before the counting model that must make it exact (B14/B48). | **Low for the MVP.** The MVP makes no claim about updates, so nothing is misleading. |
| **No history in the MVP** (US-12 → V1) | "What did I read last week?" must be answered from resume instead. | B46/B47 are a dangerous pair — a retention rule that touches reading positions is unrecoverable data loss with no backup (C8). Meeting that trap once positions are proven is worth more than meeting it early. | **Low.** Resume (US-11) covers the real need. |
| **English UI deferred to V1** (US-13 → V1) | The app's chrome is French-only during the MVP, for a reader of English content. | The localisation **mechanism** ships in the MVP, so V1's SC-4 is additive translation work and not a retrofit. | **Low.** The one real risk — retrofitting i18n across a shipped app — is avoided entirely. |
| **B40 similar-title warning and B45 title-only search deferred to V1** | In the MVP, two similarly titled novels from two sites sit side by side without warning. | No merge is possible in the MVP in the first place, so the warning guards a mistake the MVP cannot make. | **Low**, rising to medium if the MVP accumulates many library entries — which is exactly what happens by the time V1 starts. |
| **Third source never a v1 dependency** (B1, C10) | If Novel Fire is the site the owner actually reads, v1 does not serve it. | FanMTL is the first source and does not wait; v1's success is judged without Novel Fire by explicit agreement (E21). | **None to the schedule.** See §7.1. |
| **Mihon's library ergonomics deliberately not adopted** (4 filter toggles, 10 sorts, 4 display modes) | A power-user library. | One-handed, at night, while reading — every extra library control is friction. | **None.** Recorded so the omission reads as a decision. |

### 5.2 Excluded, not deferred — never in any version

These are **not** trade-offs to be revisited. They were signed out by the owner (PRD §9) and, where the client
contract requires it, fixed by ADR-010 / ADR-011. Putting any of them in a version — including "V2, probably" —
would contradict an approved decision.

| Excluded | Basis |
|---|---|
| Accounts, sign-in, cloud sync, per-user profiles | ADR-010; B4, B29, C2, C13 |
| Export, backup, restore, sharing a chapter, sending a novel anywhere | ADR-010; B30, C4; PRD §9. **The consequence is disclosed, not engineered away**: uninstalling destroys the library (E11, disclosed on first run and in settings). |
| In-app purchases, coins, subscriptions, ads | ADR-010; PRD §9 |
| Tracker integrations (Anilist, MyAnimeList and similar) | PRD §9 — never a requirement; the reader does not track what they read |
| Social features: comments, author replies, daily rewards, recommendations | PRD §9 — the app has no server and no other users |
| App store publication, store account, public distribution | ADR-011, C3, C9; client decision C-001 |
| Desktop, web, tablet-optimised layout, iOS | C3; client decisions C-002, C-010 |
| Reading the reader's own .txt, EPUB or PDF files | PRD §9 — the app reads web novels; it is not a document reader |
| Cloudflare cookie harvesting via an off-screen WebView | ADR-014 (`benchmarks.md` §2.1) — Mihon does it, we deliberately do not |
| A dynamic extension / plugin system for user-installed sources | V1 is a static registry of plain source classes; the PRD's Source contract is in-app only |

---

## 6. Relative effort per version

Sizes are **relative to this project**, not absolute. S = 1–3 simple slices, M = 4–7 slices, L = 8–12 slices,
XL = 13+ slices or slices that are complex. Slice counts are planning estimates; decomposition belongs to Phase 4.

| Version | Slices (est.) | Size | Risk factors |
|---|---|---|---|
| **Foundations** (Phase 4 foundations, not a version) | 5–7 | **M** | Transverse and blocking: the APK pipeline (Q-003 depends on it), the local store and its schema versioning (B31 depends on it), the failure-vs-empty discriminator (US-16 and SC-6 depend on it), the localisation catalogue, theme and reader type scale |
| **Wave 0 — evidence** (fixtures, not code) | 1–2 | **S** | Small and cheap, but it gates the accuracy of everything else. Skipping it is the single cheapest way to waste the project. |
| **MVP** | 14–18 | **L** | The HTML→clean→text conversion is the largest technical unknown; the offline guarantee is unproven until a device exists; no real fanMTL HTML has been recorded as ever having been read |
| **V1** | 12–16 | **L** | Two scrapers to maintain with an unmeasured churn rate; the queue's persistence and the update subsystem are only verifiable on a device; SC-1/SC-2/SC-3 all land here |
| **MVP + V1 combined** | 26–34 | **XL** | One implementer, one device, one person who can repair a scraper. See §3.5 — this is the honest total, and it is why the V1 reduction is recommended |
| **V2** | not estimated | — | Not estimable, because the PRD left no P3/P4 backlog (§4.0). Any number here would be invented. |

**Consistency check:** MVP (L) and V1 (L) are the same size, which is unusual and worth naming — an MVP that is
the same weight as the version that follows it is a signal that the MVP is oversized. §2.4 admits it and prices
the 7-story alternative rather than hiding it.

---

## 7. External dependencies

| Dependency | Impacts | Status | Risk if unavailable |
|---|---|---|---|
| **Q-003 — a real Android phone, and a way to install an APK on it** | MVP, V1, and every §7.1 target | **Open — nothing in `.forge/` records that one exists** | **The roadmap has no exit criteria.** SC-2 needs connectivity physically off; SC-5 needs an install; B31 needs a second install; the frame-budget targets need `FrameTiming` from a real device. Without it the project can be built but not finished. §7.1 of this document. |
| **Q-004 — Novel Fire's terms of service** (the PRD carries this as C10 / E21 / B1 and as an open Unknown) | V1 (does not gate it), V2+ | **Unconfirmed, no deadline** | None to the schedule by explicit agreement (B1, C10, E21). §7.1 of this document. |
| **FanMTL's current page structure** | MVP (gates everything) | **Unverified** — no artefact in `.forge/` records that its HTML has ever been read. C1 verified its *terms*, not its markup. | **High.** Selectors designed from memory fail on first contact. Wave 0 exists for this. |
| **Royal Road's current page structure** | V1 (SC-1) | **Unverified** | Medium-High — a cost if the source contract is a real contract (ADR-013); a rewrite if it is not. Capture fixtures in Wave 0 while the capture tooling exists. |
| **An Android SDK in GitHub Actions, producing a repeatable APK on merge** (C-003, ADR-011) | MVP (SC-5), V1 | **Decided, never built** | High and early — the whole delivery model funnels through it, and it is the only way the owner ever receives a fix (C5). |
| **FanMTL and Royal Road remaining readable** on the day of any gate | MVP, V1 | Uncontrollable (C7) | Medium — a site broken on gate day does not fail the roadmap, it produces a **B22 failure to demonstrate honestly**, and the demo is rescheduled. SC-6 can still be verified with a captured broken fixture. |
| **The resolved Flutter/Dart toolchain and its packages** (settled in Phase 0 conventions) | All | Resolved, unproven by any slice | Low — but the first slice that uses each package is where an unproven dependency first fails. |

### 7.1 Where Q-003 and Q-004 land in the sequence

**Q-003 — no real-device verification — is the first thing that must unblock, and the last thing that can be
assumed.**

| Position in the sequence | What happens |
|---|---|
| **Wave 0** | The offline read path is designed against the assumption that it will be measurable. Nothing else changes. |
| **Wave 1** | The APK pipeline is the **first foundation built**, ahead of the store, the sources and every screen — because it is the only artifact that makes a device measurement possible, and because SC-5 needs it anyway. |
| **Wave 4 — the MVP gate** | **The gate cannot be held without a device.** This is the pivot point of the whole roadmap: the offline claim is proven here or it is not proven at all. |
| **V1 (Waves 5–7)** | The queue's restart survival (B21/E15), storage exhaustion (E20), connection loss mid-queue (E7) and every §7.1 performance target are device-only. None of them can be verified in CI. |

**If Q-003 resolves badly** — no phone in the loop, no way to install, no time to test — then:

- The MVP **does not ship** and does not get declared. An MVP verified only on an emulator has proven nothing
  that SC-2, SC-5 or SC-6 claim: emulator storage is not phone storage, emulator connectivity is not a radio,
  and an emulator frame timing is not a reader's frame budget.
- The correct response is to **stop and re-scope**, not to substitute a weaker claim. Specifically: the honest
  fallback is to move SC-5 to the very first milestone and make a device the project's first funded milestone,
  because every other criterion is downstream of it.
- The one thing that may proceed without a device is Wave 0 (fixture capture) and the foundations that do not
  need measurement. Everything else waits.

**Q-004 — Novel Fire's terms — is deliberately placed nowhere in the sequence.**

| Position | What happens |
|---|---|
| **Never on the critical path** | C10: "There is no deadline." FanMTL is the first source and does not wait. Novel Fire ships whenever, or never. |
| **After the V1 gate** | If the terms are confirmed, it is added as an additive slice over the same source contract (ADR-013) — selectors, not a rewrite. It is added **after** V1, never inside it, because adding a source mid-V1 would add a third scraper to a version already at XL. |
| **If the terms are unacceptable (E21)** | Nothing changes. Novel Fire is dropped permanently, is not advertised anywhere in the app, and **v1's success is judged without it** (B1). No roadmap item moves and no criterion fails. |
| **If the terms are fine but the site proves unscrapeable** | It becomes a V2+ candidate under §4.1's opening conditions, and it is **dropped from the roadmap** rather than carried as a permanently open item. |

### 7.2 Two contradictions between approved documents, flagged not resolved

Both are outside a scope-architect's authority to settle. They are recorded here because a roadmap that hides
them will inherit them.

1. **Background download.** `.forge/benchmarks.md` §3 lists "Background download — Lumen Tale v1: **yes**".
   `.forge/prd.md` **E7** states the opposite: the download queue "runs in-process and has no background
   executor", it stops on connection loss, and it does not resume by itself. B21 then requires it to *resume*
   when the app is opened again. **This roadmap follows the PRD**: V1 ships an in-process queue that survives
   closure by resuming, and true background execution sits in §4.1. `benchmarks.md` §3 should be corrected, or
   E7 should be amended — one of the two is wrong.
2. **B22's discriminator may not exist on FanMTL.** B22 requires distinguishing "genuinely nothing" from "could
   not read" using **the site's own explicit empty-result signal**. Nothing in `.forge/` records whether FanMTL
   has such a signal. If it does not, B22 as written is not implementable for that source, and both US-16 and
   SC-6 — the criterion that exists for no other purpose — are affected. Wave 0 is where this gets checked;
   if it fails, B22 needs an amendment before US-16 is specified.

---

## 8. Dependency-ordered build sequence

> **This is the order slices must be implemented in — which is not the order the reader experiences them.**
> The reader's order is browse → library → read → download. The build order is the reverse of the one that
> matters: **store → read → download → library → browse.** The browse surface is deliberately last, and
> §2.0 is why.

### Wave 0 — Evidence, before any feature code

| # | Item | Depends on | Blocks |
|---|---|---|---|
| 0.1 | Capture and freeze real FanMTL fixtures with their capture date: catalogue page, novel page, chapter-list page, a multi-page chapter, a genuinely short chapter (Extra / Omake / author's note), and a page containing a script tag and a third-party image | — | 0.4, Wave 2 |
| 0.2 | Record, from those fixtures, **whether FanMTL has an explicit empty-result signal** (§7.2 item 2) | 0.1 | US-16, SC-6 |
| 0.3 | Capture the equivalent Royal Road fixtures, while the capture tooling exists | 0.1 | the source contract (Wave 2), Wave 6 |
| 0.4 | Record which parts of a chapter page are content and which are furniture, from the real pages | 0.1 | the cleaning rules |

### Wave 1 — Foundations that unblock verification

| # | Item | Depends on | Blocks |
|---|---|---|---|
| 1.1 | **APK built automatically on merge, with a version number** (C9, B34, ADR-011) | — | SC-5, Q-003, everything measurable |
| 1.2 | Local persisted store, with schema versioning and a migration path | — | B31, B3, everything persisted |
| 1.3 | The failure-vs-empty discriminator (B22, B24, C6, C7) | 0.1, 0.2 | US-16, SC-6 |
| 1.4 | Localisation catalogue with French and a French fallback — **mechanism only, no English yet** (B28) | — | US-13, SC-4 |
| 1.5 | Theme and reader type scale following the system, with an in-app override persisted (B26, B27) | — | US-14, US-15 |

### Wave 2 — The offline read path: the product. Built headless, with no browse UI in existence

| # | Item | Depends on | Blocks |
|---|---|---|---|
| 2.1 | FanMTL as one adapter over the source contract: catalogue → novel → chapter list → chapter pages (B1, B2, B3, B8, B9, B10, E3) | 0.1, 1.2, 1.3 | 2.2 |
| 2.2 | Clean and convert a chapter page to stored text, with the "no real text" threshold rules (B5, B44, E18, E22) | 2.1 | 2.3 |
| 2.3 | Store a chapter atomically: present-and-complete, or not present (B6, B20, E6) | 2.2 | 2.4 |
| 2.4 | **Read a stored chapter from local storage only — the wow moment is proven here** (B7, C14) | 2.3 | the whole product claim |
| 2.5 | Library: add, remove, list, open — and removing keeps the downloads (B11, B12, B32, B33) | 1.2, 2.1 | 2.4's entry point |
| 2.6 | Reading position per chapter (B16, B46) | 1.2 | US-11 |
| 2.7 | Reader presentation: continuous scroll, chapter title, no horizontal scroll at 10 000 characters, no clipped final paragraph (B25, §7.1) | 2.4 | 2.8 |
| 2.8 | Theme and text size applied in the reader, with no clipping at the largest size (B26, B27, E13, E14) | 1.5, 2.7 | US-14, US-15 |

### Wave 3 — Reach a novel: the browse surface attaches last

| # | Item | Depends on | Blocks |
|---|---|---|---|
| 3.1 | Catalogue UI, one source, with loading and failure states (US-01a, B24) | 2.1, 1.3 | 3.2 |
| 3.2 | Novel details + chapter list UI, with large-list behaviour (US-03, E1, E2, E10) | 3.1, 2.1 | 3.3 |
| 3.3 | Download a single chapter from the chapter list, and delete a single chapter (US-06, B33) | 3.2, 2.3 | — |
| 3.4 | First-run and settings disclosure that the library is not recoverable (E11) — *this item forces a minimal first-run surface that Phase 3 must design* | 2.5 | SC honesty |
| 3.5 | About screen showing the installed version (B43, US-17) | 1.1 | — |

### Wave 4 — MVP gate

- One live network run (a site may have changed since Wave 0), **then** connectivity physically off, and 50-chapter-scale is *not* required here — one chapter is.
- **The upgrade-safety drill:** with a library entry, downloaded chapters, reading positions and a history in place, install the next APK over the previous one and assert every one of those is intact afterwards. This is B31, the wedge, and it is a drill rather than a claim.
- Long-list responsiveness gets its number, or is deleted (§4.3).

### Wave 5 — V1a: the SC-2 scale proof

| # | Item | Depends on | Blocks |
|---|---|---|---|
| 5.1 | Download queue with the six bulk choices: next / next 5, 10, 25 / all unread / hand-picked (B18) | 3.3 | 5.2 |
| 5.2 | Pause, resume, cancel; no further fetch after a cancel; queue survives app closure (B19, B20, B21, E7, E15) | 5.1 | SC-2 |
| 5.3 | Progress indicator; connection loss mid-queue stops and says why; storage exhaustion stops, keeps completed chapters (US-08, E7, E20) | 5.2 | SC-2 |

### Wave 6 — V1b: the app around it

| # | Item | Depends on | Blocks |
|---|---|---|---|
| 6.1 | Royal Road adapter (SC-1) — the real test of the source contract | 0.3, 2.1 | SC-1 |
| 6.2 | Search, **per source, only where measured usable** (US-02, B41, B50) | 3.1 | — (SC-1 satisfied by 6.1) |
| 6.3 | The local counting model: unopened count is local and exact (B48), last-checked / never-checked is visible (B49), a check never downloads (B38) | 5.2 | SC-3 |
| 6.4 | Manual "update library" (B36) — and **B35's interval picker + B37's foreground notification only if the §3.5 reduction is refused** | 6.3 | SC-3 |
| 6.5 | History view, time-bounded, never touching reading positions (US-12, B17, B46, B47) | 2.6 | SC-3 |
| 6.6 | Library unread badge, similar-title warning, title-only search (US-09b, B14, B40, B45) | 6.3 | SC-3 |
| 6.7 | English translations, **including every error and download-status message** (US-13, B28) | 1.4 | SC-4 |

### Wave 7 — V1 gate

- SC-1..SC-6 all verified, including the SC-6 broken-site check against a captured fixture of a changed layout.
- **The upgrade-safety drill, run a second time**, with a real library, real downloads, real positions and a real history.
- The two remaining §7.1 targets get numbers or are deleted (§4.3).

### 8.1 Where the implementation order deliberately diverges from the reader's order

| The reader experiences | Built at | Why the divergence |
|---|---|---|
| Browse a catalogue | **Wave 3** | Cheapest to add, easiest to rework, least differentiating — last |
| Open a novel, see its chapters | **Wave 3** (UI), **Wave 2** (data) | The data must exist before the offline path; the screen can wait |
| Read a chapter | **Wave 2** | The product |
| Download it | **Wave 3** (single), **Wave 5** (queue) | Atomic storage is proven in Wave 2 before any UI offers a download button |
| Read it with no signal | **Wave 2** | The claim, first |
| Find it again, in the library | **Wave 2** | Required for the claim to be reachable |
| Resume where I stopped | **Wave 2** | Required by US-05's own acceptance criteria |
| Find new chapters | **Wave 6** | Cannot exist before the counting model that makes it exact |
| Get a new version | **Wave 1** | First, so a fix can always reach the phone |

---

## 9. Where this roadmap is most likely to be wrong

Recorded here rather than only in the report, because a roadmap that does not name its own weak points is a
roadmap that cannot be corrected cheaply.

1. **The offline-first order only pays off if the stored format is right the first time.** Every argument in
   §2.0 assumes the clean→store→render pipeline holds up against real site HTML early. If the representation
   has to change after Wave 2 — a chapter too large to render at large text sizes, or a position that cannot be
   stored as an offset — then building the reader *before* browse was the wrong call, and the cheap-looking
   deferral of browse (US-01) becomes the cheapest-looking mistake in the project. Wave 0 fixtures are the
   mitigation, and they mitigate it only for the cases someone thought to capture.
2. **The MVP is still probably too big, and §2.4 is an admission rather than a defence.** Eleven stories at size
   L is at the top of the legitimate range. I have argued that the "wow moment" being a *guarantee* rather than
   a *feature* is what makes it irreducible — which is true — and it is also exactly the kind of argument that
   justifies any size. The lean 7-story MVP is priced and available; if the first two waves overrun, taking it
   is the correct response and not a defeat.
3. **V1 is XL and the most likely place to break is SC-3.** SC-3 ("library, history and unread badges are
   correct") drags in the update subsystem, which is the least verifiable, most device-dependent part of the
   project and the one Q-003 most directly gates. I have recommended a reduction (§3.5) rather than pretend the
   problem away. If that reduction is refused, my honest judgement is that V1 is **not** achievable at quality
   by one person, and the response is to renegotiate SC-3 — not to ship a badge fed by a subsystem that was
   never verified.
4. **Every exit criterion in this document depends on one unresolved input.** Q-003 is assumed to resolve early
   and quietly. If it resolves late, nothing in §2.1, §3.1 or §4.3 is checkable, and the honest state is that
   the project has been written and not finished.

---

## Gate checklist

- [x] The MVP resolves the main problem of the PRD (a web novel stays readable with no signal) and can be used by a real person — §2.1, with §2.2 stating plainly what it deliberately cannot do.
- [x] Every exclusion is justified by an explicit trade, not "no time" — §5.1 (lost / gained / risk), §5.2 (excluded, never deferred).
- [x] Risks are identified per version — §2.3, §3.3 — and not globally.
- [x] External dependencies are listed with their status — §7, including two flagged contradictions with approved documents (§7.2).
- [x] Relative effort is coherent between versions — §6, with the MVP-equals-V1 anomaly named rather than smoothed.
- [x] **No P1 feature is deferred to V2.** All ten P1 stories (US-01 through US-08, plus US-16 and US-17) sit in the MVP or in V1. V2 contains zero PRD user stories, because the PRD left no P3/P4 backlog — §4.0 says so instead of inventing one.
- [x] Inter-version dependencies are explicit — §3.4 and §8.
- [x] **No absolute dates.** Versions are defined by exit criteria and ordering (§0, Rule 1).
- [x] The document contains no implementation jargon — slices are named only as a size unit, and no framework, storage engine or package is prescribed; architecture belongs to Phase 4.
- [x] Every V1 item traces to a success criterion, and every MVP item traces to an approved rule or edge case.
- [x] The three §7.1 "not yet measurable" targets each have a trigger event and a deletion deadline — §4.3.
- [x] Q-003 and Q-004 each have a stated position in the sequence and a stated consequence — §7.1.
- [x] B31 appears as an explicit, repeatable drill at both gates — §2.1, §3.1, Wave 4, Wave 7.

**Status**: `draft` → awaiting validation.

**Gate questions for the owner** (three decisions this roadmap cannot make for itself):

1. **Is the 11-story MVP accepted, or do we take the 7-story lean MVP priced in §2.4?** This is the single largest scope decision in the document, and it is cheaper to make now than after Wave 2.
2. **Is the V1 reduction in §3.5 accepted** — new-chapter checks as manual-only in V1, with the interval picker and the foreground notification in V2+? If not, V1 is XL and I think that is not achievable by one person at quality, and SC-3 should be renegotiated instead.
3. **Who resolves Q-003, and when?** It is the precondition for the MVP gate and for every §7.1 target. Nothing on this roadmap is verifiable without it.
