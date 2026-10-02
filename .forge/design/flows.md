---
type: design-flows
status: approved
generated_at: 2026-10-02
derived_from:
  - .forge/prd.md
  - .forge/design/design-system.md
  - .forge/design/coverage.md
---

# Navigation flows

> Screens are specified one file each under `.forge/design/screens/`. This file specifies the **paths between them** — what a reader can do, what happens when it goes wrong, and what a first run looks like.
>
> The Forge `ux-designer` agent § 6 requires four kinds of flow: happy path, alternatives, errors, onboarding. All four are here, and the error flows are the substantial ones — because for this product the failure path *is* a requirement (B22, SC-6), not an appendix.

## 0. The one-sentence loop

> **Find a novel on a source → download it → read it with no signal → resume where I stopped → notice when a tracked novel has a new chapter.**

Every flow below is a path through that sentence. Anything that does not serve it belongs in overflow (ADR-018).

---

## 1. Happy path — first ever read (cold start)

```
/onboarding  →  /library  →  /browse  →  /browse/:sourceId  →  /browse/:sourceId/genre/:genre
   (skippable)   (empty)     (sources)      (genres)                (catalogue)
                                                                 │
                          /library/novel/:novelId  ←── tap row ────┘
                                    │
              add to library ──────┤   B12: only ever via an explicit action on a novel actually seen
                                    │
              download whole novel ─┤   B18: enqueued one chapter at a time, in reading order
                                    ↓
                          /more/downloads  (optional — the reader need not visit it)
                                    │
                          /library  →  continue-reading shelf, position at the top
                                    │
                          /reader/:novelId/:chapterId
                                    │
                      scroll ───────┤  B25: continuous, no page turn
                                    │
                    tap (centre) ───┤  reveal ReaderControls
                                    │
                  download next ────┘  silent: this is the normal path (B5 permits it — the reader asked)
```

**What is deliberately absent from this path**, and why:

| Absent | Reason |
|---|---|
| A permission prompt | Nothing to request: no account (B4), no files to import, no notification permission is needed for a foreground job (B37) |
| A source install step | ADR-013 — sources are a **static registry**, not extensions. There is nothing to install |
| A "choose your favourite genres" wizard | `archetypes.md` § 2: onboarding too long is the named trap. The reader learns the one unguessable fact and gets out |
| A sign-in | B4. The correct UI is the sign-in screen that does not exist |

---

## 2. The core loop, once the app is warm

The loop a returning reader actually runs, which is **not** the cold-start path:

```
/library  ── tap the continue-reading shelf ──→  /reader/:novelId/:chapterId
   ↑                                                    │
   │                                          scroll, position saved on settle (B16)
   │                                                    │
   └────────────────────────────────────────────────────┘
```

Opening the Library is the cheapest possible path back into reading: **one tap from app launch to prose**, because the shelf's top item already holds the stored position. This is the whole reason ADR-018 puts Library first and requires it to lead with the shelf rather than a list of covers.

---

## 3. Alternative flows

### 3.1 Resuming a novel not at the top

`/library` → multi-select (long-press a row) → the selected novels show a **selection action bar** → *Download* or *Remove*. Removal is confirmed and **says that downloads are kept** (B32).

### 3.2 Finding a novel by title in what is already owned

`/library` → the library search field → results as `NovelRow` variant `compact`.

**B45, strictly: title only.** The field's placeholder and its hint both say so. It never searches author, genre, description or status. A library search that quietly matches on description would make the reader trust it for something it does not do.

### 3.3 A serialised novel has new chapters

Two entry points, and they are deliberately different:

| From | Path | Why |
|---|---|---|
| Manual | `/updates` → *Check now* (B36) | The reader asked, so the app fetches (B5) |
| Automatic | **does not happen in v1 — and not because a rule forbids it** | **B35 was withdrawn** (ADR-023), so there is no schedule to be careful about; there is simply none. `benchmarks.md` § 2.1 records Mihon defaults `autoUpdateInterval` to 0, so Mihon *could* check on its own and we choose not to. The distinction is kept visible because the earlier text claimed a rule forced this, and no rule does |

On return, `/updates` shows what changed. **B38: checking never downloads.** The two actions are visually separate on the same screen, and the copy must not blur them — "check" fetches chapter *lists*; "download" fetches chapter *bodies*.

### 3.4 Reading while offline, deliberately

`/library` → shelf → a stored chapter opens with **no network call at all** (`reader.md` § 8). Unstored chapters offer a download action rather than a failure (E1).

### 3.5 A source that supports search

`/browse/:sourceId` renders a search field **only if** the source declares `supportsSearch` (ADR-015, B50). Query goes to the site unchanged (B41) → results on `/browse/:sourceId/genre/:genre`, or a distinct results state.

**FanMTL never takes this path.** Its search is unreachable (measured), so `supportsSearch = false`, so the field is **never rendered** and genre browsing is offered instead. A dead search box would be indistinguishable from a bug.

---

## 4. Error flows — the substantial part

B22: *"When a site cannot be read the app states that it could not read it, and never presents it as empty."* SC-6 makes this the single criterion a screen must demonstrate.

### 4.1 The distinction that must never blur

| | Broken | Empty |
|---|---|---|
| **Means** | The app could not read the site | The site was read, and there is genuinely nothing there |
| **Component** | `source-unavailable` | An empty list with a sentence |
| **Accent** | `--color-error` **plus an icon plus wording** | `--color-text-secondary`, no error colour |
| **Action offered** | Retry, and — for a layout change — report the bug | Change genre, or change the query |
| **Data shown** | None | None |
| **Never** | "0 results", "Nothing found", an empty list | An error, a retry |

Colour alone never carries the distinction (`design-system.md` anti-references) — icon and wording carry it too, so it survives a screen reader and a colour-blind reader.

### 4.2 Failure kinds, and what the reader does

`source-unavailable` must distinguish these, because the correct action differs:

| Cause | What the reader is told | What they can do |
|---|---|---|
| **No connection** | Nothing is wrong with the site | Read what is downloaded; retry when there is signal |
| **The site changed its layout** | The app can no longer read this site; nothing is lost | Nothing to retry — this is a bug worth reporting |
| **Site down or rate-limiting** | The site is not answering right now | Back off and retry later; stored chapters unaffected |
| **Novel or chapter removed at the source** | This specific item is gone | Go back; the rest of the novel is unaffected (B23) |

Collapsing these into one "error" is the specific failure SC-6 exists to catch, because three of the four have **no retry worth offering** and one of them has nothing wrong at all.

### 4.3 Failure in the middle of the work

| Where | What happens | Rule |
|---|---|---|
| One chapter fails to fetch | The chapter shows `failed` with retry; the reader keeps reading | B23 — a failure never blocks the rest |
| Download interrupted | Resumes from where it stopped; nothing re-downloaded | B20 |
| App closed mid-queue | Queue survives and resumes | B21 |
| Chapter empty at the source | Sentence naming the source, with a link out — **never** "0 results" | B22 |
| Chapter stored but unparseable | Distinguished from a fetch failure; names the file | E12 |
| Text size at the largest step | Measure caps rather than stretching; nothing clips | E14 |
| Every download fails on one source | The downloads screen reports it **as a source failure**, not as N failed chapters | B22 |

### 4.4 The honest limitation in the download flow

**E7: the download queue is in-process — there is no background executor in v1.** So a download makes progress **only while the app is alive**, and `more/downloads` must say so rather than implying work continues in the background. This is the single most likely over-promise in the product and `benchmarks.md` § 3 now records background download as **absent** for v1 to match.

---

## 5. Onboarding

`/onboarding` — short, skippable, re-reachable from settings, and in both languages (B28).

It teaches exactly one thing, because it is the one thing a new reader cannot guess and everything else they can:

> **You can download a novel and read it with no signal.**

Three panels maximum. **No permissions** (nothing to request). **No source install** (ADR-013). **No account** (B4). **No feature tour** — `archetypes.md` § 2 names "onboarding too long" as the trap for this archetype, and a tour of features is how it is sprung.

Its "assumed, non-neutral choice" (`onboarding.md` § 2.1): it ends on the empty Library rather than on a welcome-back screen, so the first thing the reader meets after dismissing it is the place the loop starts.

---

## 6. Flows the design deliberately does NOT have

These are absences with reasons. Per ADR-010 these are **excluded, not deferred** — they belong to no version.

| Absent flow | Why |
|---|---|
| Sign in / register / account | B4. No identity, so no authentication screen |
| Backup, export, share a chapter | B30 + ADR-010. The correct UI is the share sheet that never appears |
| Install or update a source extension | ADR-013 — a static registry. There is no repository, so there is no install flow |
| Migrate from another app | Out of scope (ADR-010) |
| Cloud sync between devices | ADR-010. Deliberately excluded |
| In-app purchase / subscription | ADR-010. Personal use |
| Tablet two-pane reader | ADR-019 |
| Page-turn mode in the reader | ADR-009 — v2. **Absent, not disabled** |
| Permission prompts | Nothing to request |

---

## 7. Coverage of this file against the flows the phase requires

| Required flow (the Forge `ux-designer` agent § 6) | Where |
|---|---|
| Main / happy path | § 1 cold start, § 2 the warm loop |
| Alternatives | § 3 — five legitimate variants |
| Errors | § 4 — four kinds of failure, seven interruption points, and the one honest limitation |
| Onboarding | § 5, plus § 6 for the flows deliberately absent |