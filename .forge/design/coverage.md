---
type: design-coverage
status: approved
generated_at: 2026-10-02
derived_from:
  - .forge/prd.md
  - .forge/design/design-system.md
---

# Design coverage — every rule has somewhere to be seen

> Phase 3.5 requires that every business rule has a visual manifestation and every edge case has a screen state. This file is the audit of that claim. It is written **before** the screen files so that a rule with nowhere to live is found here rather than noticed at review.

## Why this file exists

A rule with no surface is not a documentation gap; it is a rule the reader cannot observe, which makes it indistinguishable from a rule that is not implemented. The failure this catches is the one the PRD itself is most worried about: **something the app does that the reader can never see**. The mirror image is also real — a rule forced onto a screen it does not belong to produces a control that exists only to be looked at, which is what `design-system.md` § 0's anti-references forbid.

So there are three honest answers for a rule, and only three:

1. **A screen, sheet, dialog or state shows it.**
2. **It is not observable, and the reason it is not observable is written down.**
3. **It is withdrawn** (B42).

## Business rules — 49 rows in the PRD, all accounted for

> The three counts below sum to **50** because `withdrawn` is counted separately from the 49 rows: B42 is a withdrawal that keeps its ID and appears in no § 4 table, so 36 + 13 + 1 = 50 counts it twice by construction. The reassurance is the `Unaccounted: 0` line, and it holds — **B50, added by the ADR-015 amendment, is listed.**

| Answer | Count | Rules |
|---|---|---|
| Needs a visible surface | **36** | B1 B2 B5 B9 B10 B11 B12 B13 B14 B15 B16 B17 B18 B19 B20 B22 B24 B25 B26 B27 B28 B31 B32 B33 B36 B39 B40 B41 B43 B44 B45 B46 B47 B48 B49 B50 |
| Not observable, with a stated reason | **13** | B3 B4 B6 B7 B8 B21 B23 B29 B30 B34 B35 B37 B38 |
| Withdrawn | **1** | B42 |
| **Unaccounted** | **0** | — |

### The 13 non-visual rules, each with its reason

These are not omissions. Several of them are *stronger* precisely because they have no screen.

| Rule | Why there is nothing to look at |
|---|---|
| **B3** | Identity stability is a DAO guarantee. It surfaces only as rows still being correct after a restart — which no screen can show on its own. |
| **B4** | **No account.** Surfaces as the *absence* of any sign-in screen. A "profile" tab would contradict it. |
| **B6** | Atomic chapter writes are a filesystem guarantee. Visible only as a chapter being wholly present or wholly absent — never half. |
| **B7** | Offline readability is the property **SC-2 exists to prove**. It has no screen of its own; it is what the reader screen does when there is no signal. |
| **B8** | A chapter spread over several site pages is one chapter. A source concern; visible as **one** reader entry and never a page spinner. |
| **B21** | The queue surviving a restart surfaces as the downloads screen **resuming** its state — it is a behaviour of a visible screen, not a separate one. |
| **B23** | One failing site never blocking another is visible as the *other tabs still working*. Deliberately awkward to demonstrate in any single screen, which is why it is verified by drill rather than by a view. |
| **B29** | No user data leaves the device. A network posture; **no screen can display an absence of traffic.** |
| **B30** | Chapters cannot be shared out of the app. Surfaces as the **absence** of a share action — the only correct UI for this rule is the share sheet never appearing. |
| **B34** | Android phones only, delivered as an APK. A build fact; visible only on the About screen. |
| **B35** | Checking for new chapters is off by default. A Settings toggle whose default is off. |
| **B37** | A check runs as a foreground job with a visible notification. An **OS** surface, not an in-app screen — the app's own screen is not the thing being promised. |
| **B38** | Checking never downloads. A separation guarantee; visible as the **absence** of any download trigger in Updates. |

> Six of these thirteen (B4, B29, B30, B34, B38, and B8's "never a page spinner") have their correct design as a **missing control**. That is the hardest kind of requirement to review, because a reviewer looking for proof finds nothing. It is recorded here so that "I could not find it" is never read as "it was forgotten".

### B42 — withdrawn

Withdrawn in `prd.md` § 9 and deliberately given no surface. Its ID is retained so the rule series is not renumbered.

## User stories — 17, all reaching at least one screen

| Story | Primary surface | Notes |
|---|---|---|
| US-01 Browse a site's catalogue | `browse-sources`, `browse-genre`, `browse-catalogue` | Genre browsing is the real discovery path (ADR-015) |
| US-02 Search within a site | `browse-catalogue` — **conditional** | Only where the source declares `supportsSearch`. FanMTL does not (B50) |
| US-03 Novel details and full chapter list | `novel-details` | |
| US-04 Read a chapter | `reader` | |
| US-05 Read a downloaded chapter offline | `reader` in its offline state | SC-2's surface |
| US-06 Download a single chapter | `chapter-tile`, `download-confirm-dialog` | |
| US-07 Download a whole novel as a queue | `novel-details`, `downloads` | |
| US-08 Watch and control a running download | `downloads`, plus the persistent status bar | |
| US-09 Keep a novel in the library | `novel-details`, `library` | |
| US-10 See which novels have new chapters | `updates` | |
| US-11 Resume exactly where I stopped | `library` shelf, `reader` | |
| US-12 Review what I read recently | `history` | |
| US-13 French and English | **Every screen** | B28 |
| US-14 Read at night in dark mode | **Every screen**; `reader`, `settings-reader` | ADR-016 |
| US-15 Read at my own text size | `reader`, `settings-reader` | ADR-017 |
| US-16 Be told when a site stops working | `source-unavailable` | B22, SC-6 |
| US-17 Get a new version as a file | `settings-about` | B31; the rest is CI |

## Success criteria — 6, and where each is *proven*

| SC | Not proven by looking at a screen | Proven by |
|---|---|---|
| **SC-1** sources work end to end | ✗ | Fetching each source, browsing it by genre, reading a chapter |
| **SC-2** offline reading | ✗ | **Physically switching the connection off** and reading 50 chapters. A screenshot proves nothing |
| **SC-3** records are correct | ✗ | Comparing library, history and counts against the sites |
| **SC-4** both languages complete | ✗ | Reading every screen in the other language, errors included |
| **SC-5** runs on the owner's phone | ✗ | Installing a CI-built APK on a real device — blocked by **Q-003** |
| **SC-6** broken site reported, not empty | ✓ | `source-unavailable` against a fixture of a site whose layout changed. **This is the one criterion a screen can demonstrate**, and it is the most likely way the app fails in real use |

> Five of six success criteria cannot be verified by looking at the UI. That is not a gap in the design; it is what "success" means here. **SC-6 is the exception and it is the one that gets a screen, because B22 makes the difference between a broken source and an empty one the thing the reader most needs told.**

## Open at the time of writing

- **Three `roadmap.md` § 7.1 targets are still "not yet measurable"** (list responsiveness, download-progress cadence, cancellation latency). Each owes a number or a deletion in Phase 4. They are not screen requirements and are not counted here.
- **Q-003** (no device) means SC-5 has no screen evidence and cannot get any until CI closes it.