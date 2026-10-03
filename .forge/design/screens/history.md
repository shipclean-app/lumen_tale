---
type: screen
slug: history
title: History
module: history
status: approved
generated_at: 2026-10-02
derived_from:
  - .forge/prd.md
  - .forge/design/design-system.md
rule_ids:
  - B13
  - B16
  - B17
  - B22
  - B24
  - B26
  - B28
  - B30
  - B32
  - B33
  - B45
  - B46
  - B47
edge_case_ids:
  - E5
  - E9
  - E12
flow: library-loop
---

# Screen — History

> The source of truth for generating this screen. It is the app's most **read-only** surface and its clearest statement of B46: what you opened is not where you stopped. The retention sheet is specified in § 11.

> **One fact, one authority — and this file is the fifth place that has had to learn it.**
> The retention window was written here **four different ways in one file**: four options, three options, five options, and four-plus-forever, across six copies (§ 3, § 5 twice, § 7, § 8, § 11.1), while `settings.md` § 8, `design-system.md` § 2.12, `6-5` § 2.2 and `3-7` § 3.3 all said five. **The form, for any fact that lives in more than one document:**
>
> 1. **Name one authority** — the most specific document that states the fact *for the thing itself*. Here: `settings.md` § 8 (`enum(1w|1m|3m|1y|2y)`) and `6-5` § 2.2 (`HistoryRetention`) own the value list; **this file owns the wording only** and must not restate the list.
> 2. **Every copy says whose copy it is**, with the authority's name and section. A copy that does not name its source is a copy that will be edited independently the next time.
> 3. **Never assert a count or a list twice in two wordings.** Write *the same five*, link, and stop — the count lives in exactly one place.
> 4. **A new copy is written in the same edit that makes it true.** A copy added later, in a later session, is a copy nobody has checked.
> 5. **An approved screen is not a safe place for a stale copy.** This file is `status: approved` and every gate reads all of it, so a wrong value here is a wrong value in the product. What was corrected was not a typo: it was **a control that does not exist in the design** (`Keep everything`, which B47 exists to forbid) and **a `three years` window that appears in no other document in the project**.

---

## 1. Role of the screen

| | |
|---|---|
| **App archetype** | `mobile_consumer` |
| **Module** | history — **rank 3 of 5** in the bottom navigation |
| **Route** | `/history` |
| **Type** | list page, bottom-nav destination (its own `StatefulShellRoute` branch) |
| **Users** | the reader looking for something they started and did not finish; the reader who wants to know what they have been reading this month |
| **User stories served** | US-12, US-11, US-09 |
| **Business rules** | B13 B16 B17 B22 B24 B26 B28 B30 B32 B33 B45 B46 B47 |
| **Edge cases** | E5 E9 E12 |

**In one sentence**: this screen shows the reader which chapters they opened and when, newest first, bounded by a stated window and clearable — without ever showing a reading position, because the two are different things and there is no backup of either.

**Why it is rank 3**: also a resume surface, but past tense, and centrality 2 — a record of what was read, not a destination the reader builds. It sits below Updates because *what moved* outranks *what I already did*.

---

## 2. Visual direction for this screen

| | |
|---|---|
| **Mood** | quiet, warm, unhurried — and **past tense**. Nothing on this screen is a prompt, an alert or a nudge |
| **Density** | **dense** — `NovelRow`'s `history` variant at 56dp with **no cover**, justified: a cover here would be a picture of a book next to the book's name, and the reader is looking for *which chapter*, not which novel |
| **Contrast level** | **high** — `--color-text-primary` `#1A1714` / `#E8E4DD` at **14.48:1** / **12.00:1** for the novel title; the chapter title beneath it is `--color-body-sm` weight in `--color-text-secondary` `#5A524A` / `#A8A29A` at **6.22:1** / **6.01:1**, which is where B10's verbatim chapter string lives and it must not be faint |
| **Surface** | rows on `--color-surface` `#FBF9F6` / `#1A1C1F` full-bleed over `--color-background` `#F5F2ED` / `#121315`; the bound notice sits on `--color-surface-raised` `#FEFCF9` / `#232629`; skeletons on `--color-surface-sunken` `#EBE7E0` / `#0C0D0F`. The only shadow on this screen is `--shadow-dialog` under the clear-history confirmation |
| **Accent used** | **nowhere except the focus ring.** `--color-accent` `#8A4B12` / `#E3A857` is this product's colour for *you have not opened this yet*, and every row on this screen is by definition something the reader **has** opened — B13's marker is cleared on all of them. A screen that borrowed the accent for emphasis would be spending the app's one semantic colour on decoration | 
| **Photographic treatment** | **none.** `NovelRow`'s `history` variant has no cover slot, so there is nothing to style, and nothing here needs to be |
| **Reference** | the index of a reading journal: dated, in order, never re-sorted by book or by author, and with the period it covers printed at the top rather than assumed to be all of it |

### 2.1 Anti-generic — mandatory

This screen must not resemble any of these defects:

- [x] **No pure white `#FFFFFF` background** — `--color-background` is `#F5F2ED` day / `#121315` night.
- [x] **No shadowed card per row.** Flat strips separated by `--color-border`; no cover thumbnails, no rounded card wrappers, and the single raised surface is the notice block.
- [x] **Not uniform.** `--text-h1` 31/38 for the screen title, `--text-overline` 11/16 600 with 0.08em for the day-group labels — **Today · Yesterday · Thursday 12 March** — and the two row scales beneath them. The day grouping is the hierarchy, and it is a typographic and spacing device rather than a set of dividers.
- [x] **No generic grey `#6B7280`** — the paper-anchored neutral ramp.
- [x] **No symmetric centring as the layout.** Full-bleed rows with `--space-md` internal padding, a `--space-lg`-margined notice, left-aligned text throughout.
- [x] **No generic spot illustration** — both empty states are a sentence and one action, and the cleared state is a sentence that says what was **kept**, not an illustration of an empty box.
- [x] **Not one typeface at one weight** — the platform sans at three scales, with the day headers carrying tracking and weight (600 at 0.08em) against the rows' 400. Nothing here is prose, so no serif (ADR-017).

**Assumed, non-neutral choice**: **no row on this screen carries a progress bar, a percentage, or the words "unread" or "finished".** B46 makes reading position and reading history different things, and a percentage here would be the exact place where a reader reads one as the other — a history entry reading *Chapter 214 · 41%* says something about *where you stopped*, which is a fact this screen does not hold and must not imply. The position lives in the position record; this list only says what was opened and when. The second non-neutral choice, from the same rule: **the screen has no search, no filter and no sort control.** A log is read in the one order it was written — newest first — and the app already searches titles in exactly one place, by rule (B45). Adding a second title search over a log would be the same capability in the worse location. The third: **the bound is printed at the top and again at the bottom.** *Kept for one year* in the notice, and *This is the oldest entry kept* at the end of the list — because a list that simply stops looks like a list that has run out, and the difference between "you reached the end" and "we dropped the rest" is the difference between a record and a lie (B47).

---

## 3. Anatomy

```
AppScaffold (titleBar, bottomNav)
├── TitleBar
│   └── Title "History"                          --text-h1 31/38 700
├── BoundNotice                --color-surface-raised, --radius-lg, --space-md padding
│   ├── NoticeText             "This is what you opened, not where you stopped.
│   │                           Clearing it never moves a remembered position."   (B46)
│   ├── RetentionLink          "Keep for one year"  → SettingsChoiceSheet (§ 11)    (B47)
│   └── ClearLink              "Clear history"      → ConfirmDialog
├── HistoryList                full-bleed rows, --space-md padding, --color-border rules
│   ├── DayGroupHeader ×N      --text-overline, "TODAY" · "YESTERDAY" · "THURSDAY 12 MARCH"
│   ├── NovelRow variant history   56dp, no cover, title + chapter + relative time
│   │   ├── RowPrimary  novel title  --text-h4        → /reader/:novelId/:chapterId
│   │   ├── RowSecondary chapter title verbatim, one line, --text-body-sm       (B10)
│   │   └── RowTertiary relative time, --text-caption, trailing
│   └── TerminalLine           "This is the oldest entry kept. Entries older than one year are dropped."   (B47)
└── SettingsChoiceSheet · ConfirmDialog · SnackBarHost · EmptyState · ErrorState · LoadingState
```

| # | Component | Role | Source |
|---|---|---|---|
| 1 | `NovelRow` variant `history` | One opened chapter: novel, chapter, when | `design-system.md` § 2.1 |
| 2 | `EmptyState` / `ErrorState` / `LoadingState` | Never-read, cleared, aged-out, unreadable store, first paint | `design-system.md` § 2.7 |
| 3 | `TextButton` / `PrimaryButton` | The two inline notice actions and the empty state's one action | `design-system.md` § 2.3 |
| 4 | `AppScaffold` | Title bar and bottom nav; **no** `persistentStatus`, because a running download is reported on the screen that started it | `design-system.md` § 2.8 |
| 5 | `BoundNotice` | **slice-local**: the raised block carrying B46's sentence in prose and B47's two controls side by side. A composition of `Text` and two `TextButton`s on `--color-surface-raised`; promoted to the design system only if a second screen needs the same pair |
| 6 | `DayGroupHeader` | **slice-local**: one `--text-overline` label per day, marked as a semantic header for screen readers |

---

## 4. States — all nine, no exceptions

| State | Trigger | Rendering | Reader feedback |
|---|---|---|---|
| **Loading** | First paint, before the local store returns (process death, cold start) | `LoadingState` shaped like the list: the notice block as two `--color-surface` lines, one overline-width label, and **eight** `NovelRow` skeletons at 56dp — a two-thirds title line, a one-half line, a trailing short block. No cover, because this variant has none | None. The data is on the phone and takes milliseconds |
| **Filled** | The normal case | Day-grouped, newest first, no covers, no progress anywhere on the list | — |
| **Filled — after a chapter was opened elsewhere** | The reader is reading right now, in another tab | The list does **not** change and does not gain a live region: history is a record of what was opened, not a live feed of what is being read. The entry appears when the reader next opens this screen, in the day group it belongs to | None, deliberately. A list that reorders itself while the reader looks at it is a different product |
| **Empty — never visited** | No chapter has ever been opened. Not an error, not a failure to load — a first-run state | `EmptyState`: title *Nothing read yet*, body *The chapters you open appear here, newest first.*, and one `primary` action that depends on a local fact: **Browse a source** when the library is empty, **Open your library** when it is not | The action points where the reader's next step actually is, decided by what is already on the phone rather than by a fixed string |
| **Empty — no data** | Two causes, two sentences, and the difference matters because one of them is the reader's own act | **(a) Cleared by the reader**: title *History cleared*, body **Your library, your downloads and every remembered position were kept** — B46 said out loud, on the screen where the fear lives. One `secondary` **Keep for one year** opens the retention sheet. **(b) Every entry aged out**: title *Everything older than one year was dropped*, body *Your reading positions were kept.*, plus the retention control so the window can be widened | Both say what survived. An empty list after a destructive action that says nothing is the moment a reader goes looking for what else just disappeared |
| **Load error** | The local history store cannot be read — corrupted, failed migration | `ErrorState` with `--color-error` icon, a sentence naming **what failed and what still works**: *Your history could not be read. Your library, your downloaded chapters and every remembered reading position are unaffected*, and a `secondary` **Try again** | The sentence is unusually specific because the fear here is data loss, and this app has no backup (ADR-010). Promising three survivals by name is what stops the reader from assuming the worst |
| **Submit error** | Two submissions: clearing, and changing the retention window. **Clear failed**: **the list is unchanged** — every row still there — and a SnackBar says *History was not cleared*, because an optimistic empty list is a record of something that never happened. **Retention write failed**: the sheet stays open on the previous window with a field-level error under the control | Neither failure is visible in the list. Both name the value that is still in force |
| **Success** | Cleared, or the window changed | **Cleared**: the empty-no-data (a) state, plus SnackBar *History cleared. Your reading positions were kept.* **Window changed**: the notice line re-renders in place — *Kept for three months* — and the terminal line's wording follows it, with SnackBar *History is now kept for three months* | The bound is updated in both places it is printed, because a screen that says "one year" in the notice and "three months" at the end would be two lies |
| **Offline / permissions** | No usable connection | **Byte-identical to Filled.** Nothing on this screen has ever needed a network (C14), so there is no offline sentence to add and no disabled control: adding one would imply the screen depends on a signal it does not use | None. This is the clearest offline state in the app, precisely because it is uneventful |
| **Offline / permissions** — *the chapter's download was deleted* | The reader deleted this chapter's downloaded copy (B33), then opened it from here | The row opens the reader's **not-downloaded** state, which offers **Download this chapter**. The row itself is unchanged and offers no warning: whether a chapter's file is still on the phone is not a property of the *history* entry, and B33's deletion lives in Downloads where it was made | The honest outcome is the reader's own state, not an error invented by this screen |
| **Read-only** | Unconditional — **this is the most read-only screen in the app**, and the reasons are worth stating separately | **(1) A row cannot be edited, renamed, annotated or individually deleted.** There is no per-row delete, because a delete button on a history row reads as *"delete this chapter"* — which it is not: it would remove one log line while the chapter, its download and its position all stayed. The only destructive action here is **Clear history**, which says exactly what it clears. **(2) Opening a row only navigates.** It writes the position record because the reader read something, not because this screen was used. **(3) Nothing can be shared or exported** from here (B30). **(4) The stored entry is a fact, not a document** — nothing on this screen can rewrite one | A log you can edit is not a log. The whole value of this screen is that it is the one place the reader can check what the app believes and find it unalterable |

> Three of the nine have a second rendering or an explanatory absence and each says why: empty-no-data splits because being cleared by the reader and being aged out are different events with different emotional weight, offline has a second rendering because a deleted download is a state the reader created deliberately elsewhere, and read-only is expanded into four named properties because "this screen is read-only" is too coarse to be implementable — which exact operations are refused is the specification.

---

## 5. Interactions

| Element | Event | Behaviour | Visual feedback | Resulting state | Rule |
|---|---|---|---|---|---|
| Row — primary target | tap | **Open the reader at that chapter's stored position**, exactly as returning to it would (US-11's resume behaviour) | No transition into the reader | Reader at position | **B16**, **B17** |
| Row — novel title region | tap | Push `/library/novel/:novelId` — the row's second destination, so a reader who wants the novel's other chapters does not have to go via the reader | Standard push, `--duration-normal` | Filled on the detail screen | — |
| Row | long-press | **Nothing.** No per-row menu exists on this screen, and that is a decision rather than an omission: the only menu a log row could offer is *delete*, and delete here would have to mean "remove this line from a list", which no reader wants and B46's subject matter makes dangerous to gesture toward | — | Unchanged | **B46** |
| Retention link | tap | Open `SettingsChoiceSheet` (§ 11) — the **same five windows `settings.md` offers**: `1 week · 1 month · 3 months · 1 year (default) · 2 years`, and **no `Keep everything`** | Sheet slides up `--duration-normal`, `--shadow-sheet` | Filled + sheet | **B47** |
| Retention sheet | tap an option | Change the window immediately, re-render the notice and the terminal line in place, close the sheet. **Entries are dropped by age, oldest first** — changing the window shorter than the current age drops entries, and the sheet says so before the reader picks: *Entries older than three months will be dropped now* | Notice and terminal line update; SnackBar names the new window | Filled | **B47** |
| Clear history | tap | `ConfirmDialog`: **Your 96 entries will be removed. Your library, your downloads and every remembered reading position will be kept.** Cancel is the default; Clear is `danger` and says *Clear history* in full rather than *OK* | Dialog; then the empty-no-data (a) state and a SnackBar repeating the promise | Empty | **B46**, **B47** |
| Day group header | — | A label, not a control. It is a semantic **header** for screen readers so the list can be traversed by date | — | — | — |
| Terminal line | — | The stated bound at the end of the list: *This is the oldest entry kept. Entries older than one year are dropped.* The second sentence **names the selected window**, so it is rewritten in place whenever the window changes. **There is no unbounded case**: no `Keep everything` exists, so the second sentence is never absent and a list whose bound cannot be named cannot arise — a screen that claimed a bound it was not applying, or silently dropped one, would be the exact failure B47 was written to avoid | — | — | **B47** |
| List | scroll | Day groups scroll with the list; nothing is pinned, because nothing here is being tracked while the reader reads | — | Filled | — |
| List | pull-to-refresh | **Absent.** Every datum on this screen is already local and none of it changes without the reader acting, so a refresh gesture would be a spinner promising a fetch that does not exist | — | — | **C14** |
| List | search / filter / sort | **Absent, permanently** — see § 2.1. The app searches titles in one place by rule (B45), and a log is read in the order it was written | — | — | **B45** |
| Tab switch | tap another destination | The branch keeps its list and scroll offset (go_router shell routes) | — | Filled | — |

- **Focus / keyboard**: D-pad moves through the title, the two notice actions, then row to row, announcing each day group as a header as it enters. The focus ring is 2dp `--color-border-focus` with a 2dp offset, never removed. `Enter` opens the chapter; the row's second destination is exposed as a **secondary semantic action** ("Open the novel") rather than as a separate focus stop, so a keyboard user is not made to tab twice through the same row for two different outcomes. `Esc` closes the sheet or the dialog.
- **Gestures**: tap and scroll only. No swipe, no long-press, no pull-to-refresh — each is argued above rather than omitted.
- **Animations**: sheet slide `--duration-normal` 200ms `--ease-standard`; dialog fade `--duration-normal`; press feedback `--duration-fast` 120ms. The list itself has **no** insertion animation when the reader opens a chapter in another tab and returns: an entry that animates into place is an entry the reader did not ask for. All durations become `0ms` under reduce-motion.
- **Back**: system back pops, or dismisses the sheet or the dialog. Back never clears anything and never reorders the list.

---

## 6. Responsive

| Breakpoint | Behaviour | What collapses or disappears |
|---|---|---|
| **Mobile** `< 600dp` | The design target. Single column, `--space-lg` 16dp margins on the notice block, rows full-bleed with `--space-md` internal padding, `--space-3xl` 48dp top margin, day headers in `--space-lg` above their first row | Nothing — this is what ships |
| **Tablet** `600–1023dp` | **Identical single column, centred, capped.** The column stops at the `--reader-md` measure width and centres. **This is deliberately not a tablet layout** (ADR-019, C3): there is no two-column date-split and no grouped-by-novel variant, even though a calendar-heatmap or a "by novel" grouping is the obvious thing to add here and would break the one order a log should have | Nothing collapses — the layout simply stops growing |
| **Desktop** `1024–1439dp` | Same single column, centred. Flutter desktop is out of scope (C3) | — |

`--bp-wide` `≥ 1440dp` follows the same capped-and-centred rule by declaration (`design-system.md` § 1.7).

- **Touch target**: 48dp minimum. Rows are 56dp; the notice's two inline actions are 48dp tall with 48dp of horizontal separation, so neither can be hit by accident while reaching for the other; the dialog buttons are 44dp in a 48dp bar.
- **Overflow**: **guaranteed never to overflow.** The novel title truncates to one line at `--text-h4`; the chapter title truncates to one line at `--text-body-sm` **with an ellipsis and never a shortened string** — B10 requires the site's chapter title as published, so the full text is always available in the reader's own chapter sheet. Relative time truncates last and is short by construction (*3 days ago*). At 320dp the notice wraps to at most four lines and its two actions stay on one row, or wrap to two — they never truncate, because a truncated "Clear hist…" is not a label.

---

## 7. Accessibility

- [x] **Contrast 14.48:1** (day) / **12.00:1** (night) for novel titles — `--color-text-primary` `#1A1714` / `#E8E4DD`, measured.
- [x] **Contrast 6.22:1** / **6.01:1** for chapter titles and relative times — `--color-text-secondary` `#5A524A` / `#A8A29A`. The chapter string is B10's verbatim site text, and setting it in a body token is what keeps an irregular title like *Omake* or an untitled chapter legible.
- [x] **Contrast 6.07:1** / **8.86:1** for the focus ring, non-text per WCAG 1.4.11 at 3:1.
- [x] **No state by colour alone**: day-group headers are labels, not colours; the "keep everything" case is distinguished by the **absence of a sentence** rather than by a tint; the cleared state is distinguished by its wording, not by a red field.
- [x] **Keyboard navigation complete** over the title, both notice actions and every row; focus visible at 2dp, never removed; day-group headers are reachable and announced as headers, so the list can be traversed by date rather than row by row.
- [x] **Semantics per row**, one node, and **it says "opened"**: *"The Ascension of the Ninth Son, Chapter 214, The Weight of Quiet Water, opened 3 days ago"*. It does **not** announce a percentage, a progress value or the word *unread* — B46 enforced in the accessibility layer, which is where it would otherwise leak, since a screen reader user cannot see the absence of a progress bar and would reasonably assume one exists.
- [x] **Both destinations reachable**: the row's primary action opens the chapter, and "Open the novel" is a named secondary semantic action on the same node.
- [x] **Announcements for the two destructive paths**: clearing announces *History cleared. Your reading positions were kept*, so the reassurance is not a visual line the reader may have already scrolled past.
- [x] **Text alternative for images**: there are none — `NovelRow`'s `history` variant has no cover slot, so nothing here needs a label.
- [x] **Language and reading direction** correct: every string follows the app locale (B28) with French fallback; day headers are localised by the platform's date formatter rather than concatenated, and relative times are localised too. **Chapter titles are never translated** — they are the site's, as published (`prd.md` § 7.4).
- [x] **Reduce-motion honoured**: sheet and dialog appear instantly, press feedback becomes a state change with no tween, and the list has no insertion animation to disable.

---

## 8. Data

| Field | Type | Origin | Required | Possible error |
|---|---|---|---|---|
| `entry.novelId` | `String` | local, stable (B3) | yes | A novel removed from the library keeps its entries — B32 removes the library entry, not the log |
| `entry.chapterId` | `String` | local | yes | Unresolvable only if the chapter's stored copy was deleted (B33), which opens the reader's not-downloaded state rather than failing here |
| `entry.chapterTitle` | `String` | site, stored and shown **verbatim** (B10) | yes | Empty at the source → the row shows the novel title and *Untitled*, never an index |
| `entry.novelTitle` | `String` | site, stored verbatim | yes | — |
| `entry.openedAt` | `DateTime` | local, written when the chapter opens | yes | The single field this screen is ordered by (B17), grouped by, and aged against (B47) |
| `retentionWindow` | `enum(3 months, 1 year, 3 years, keep everything)` | `shared_preferences`, **default `1 year`** | yes | A write failure keeps the previous window and shows a field-level error |
| `agedOutCount` | `int` | local, computed at read time | no | Reported in the aged-out empty state, never silently applied while the reader is looking at rows |
| `readingPosition` | `(chapterId, offset)` per chapter | local, **read-only from this screen**, **never trimmed by any retention rule** (B46) | no | Referenced only so the row can resume at it; never written here, never aged, never cleared |

- **Loading**: **the list loads in one block from the local store.** No paging, no infinite scroll — B47 bounds it by time rather than by count, so a heavy reader's list can legitimately be long, and the answer to a long list is a virtualised one with day headers, not a page spinner. Rows are built lazily on scroll; the counts in the group headers come from the stored timestamps, not from a per-row query.
- **Cache / offline**: **zero network calls, ever** (C14). This screen never fetched anything in the first place, which is why its offline state needs no sentence.
- **Sensitive data**: no analytics and nothing transmitted (B29); no share and no export (B30). Logs carry entry ids and counts — **never a chapter title, never chapter text**, and never an `openedAt` timestamp, because a timestamp is the closest thing this app holds to a reading habit.

---

## 9. Traceability

| ID | Origin | Manifestation on this screen |
|---|---|---|
| B13 | PRD | Every row is by definition **opened**, so no row carries the unopened marker and the accent colour appears nowhere on this screen except the focus ring |
| B16 | PRD | Tapping a row opens the reader at **that chapter's** stored position, per chapter — not the novel's most recent chapter, and not the top of the chapter |
| B17 | PRD | Reverse chronological, grouped by day, and **"where was I" comes from the position record, never from this list** — which is why this list can be aged out and cleared while a position cannot |
| B22 | PRD | A stored entry whose site has changed or vanished still lists: the log is local, so a broken site cannot alter it (E9). The only failure this screen reports is its own store |
| B24 | PRD | An unreadable store produces a sentence and a retry, never a blank page; a failed clear leaves the list intact and says so |
| B26 | PRD | The screen re-themes on the phone's setting, with the same surfaces and the same measured contrasts |
| B28 | PRD | Every string is ARB with French fallback, including day headers, relative times, both notice actions and the clear confirmation |
| B30 | PRD | No share, no export, no per-chapter action that could lead out of the app |
| B32 | PRD | Removing a novel from the library **keeps its history entries** — the log outlives the library entry, and only the deliberate Clear removes it |
| B33 | PRD | A row whose chapter download was deleted still lists and opens into the reader's not-downloaded state; the history is not edited by a deletion that happened elsewhere |
| B45 | PRD | **No search box here.** Titles are searched in one place, by rule, and a second title search over a log would be the same capability in the worse place |
| B46 | PRD | The distinction is stated in the notice's own sentence, repeated in the clear confirmation, repeated in the cleared state, repeated in the store-failure sentence — **and enforced structurally: no row shows a position, a percentage or a progress bar** |
| B47 | PRD | The window is **one year by default**, **configurable**, **clearable**, and **printed at the top and at the end of the list**, with a terminal line stating that older entries are dropped oldest-first |
| E5 | PRD | Offline, the screen is uneventful: nothing here ever needed a network, so no connection message is shown at all |
| E9 | PRD | A novel the site has dropped or renamed still has its history rows; the log is local and is not edited by anything a site does |
| E12 | PRD | A language change re-localises the screen — day headers and relative times included — with no loss of the list and no change to any timestamp |

---

## 10. Gate checklist

- [x] All nine states described with a concrete rendering; the ones that split or that are explained say **why** (empty-no-data splits by cause, offline has a second rendering for a deleted download, read-only is expanded into four named properties because a blanket "read-only" is not implementable).
- [x] Every interactive element has a behaviour, a feedback, a resulting state and a rule ID.
- [x] Responsive defined at **every** breakpoint of the design system; the two larger ones say "identical, stop widening" — ADR-019, and the rejected "grouped by novel" variant is named so it is not re-proposed.
- [x] Anti-generic section checked **and justified**; the assumed choices are stated (no progress anywhere, no search/filter/sort, and the bound printed twice).
- [x] No design value left "to be defined". Every colour, size, duration and easing cited exists in `design-system.md` with its value.
- [x] Every B/E/C ID on this screen appears in § 9.
- [x] `forge-guard placeholders` reports nothing here.
- [x] Consistent with `design-system.md`: `NovelRow`'s `history` variant is rendered with **no** `cover` slot, which that variant declares, and the accent token is cited only where it appears.
- [x] Material 3 primitives only (`CustomScrollView`, `ListView.builder`, `TextButton`, `OutlinedButton`, `AlertDialog`, `ModalBottomSheet`, `SnackBar`) — ADR-001.
- [x] **Every token cited by this screen exists in the design system, with the value it is given here.** The full citation table is § 12.
- [x] **v1 reading is scroll-only** (ADR-009): this screen contains no page-turn, slide or swipe-to-turn affordance, not even disabled. It links into the reader and specifies nothing about how the reader reads.
- [x] **Nothing on this screen can destroy an unrecoverable thing.** The only destructive action is one confirmation away, it names its own scope, and it promises what survives — which is the whole of B32's and B46's posture applied to a log.

---

## 11. Sub-surfaces of this screen

### 11.1 `RetentionSheet` and the clear confirmation

**`RetentionSheet`** — a `ModalBottomSheet` on `--color-surface-raised`, `--shadow-sheet`, `--radius-lg`, with four radio rows and a sentence above them that changes with the selection: *Entries older than three months will be dropped, oldest first. Your reading positions are never affected.*

| Option | Effect |
|---|---|
| Three months | Drops entries older than three months, oldest first |
| **One year** | **The default.** Conservative enough to bound a pathological table and never felt in normal use |
| Two years | Drops entries older than two years |

**Five options, and the reason there are no more: there is no \*\*Keep everything\*\*.** An earlier draft of this screen offered it as a sixth, and that was the rule **B47** exists to prevent — *\"the history list is bounded by time, not by count\"* becomes false the moment the reader can remove the bound. `design-system.md` § 2.12 forbids it independently (*\"No 'forever' option on any bounded list\"*), because an unbounded value next to bounded ones teaches the reader the bounds are negotiable. **The five windows are the same five `settings.md` offers** — `1 week · 1 month · 3 months · 1 year · 2 years`, one year the default — because two lists of the same values in two places is two truths about how long history lasts.

**The clear confirmation** is an `AlertDialog` on `--color-surface-raised` with `--shadow-dialog`, and its body is B46 in one sentence: **Your 96 entries will be removed. Your library, your downloads and every remembered reading position will be kept.** Cancel is the default action; the destructive button reads **Clear history** in full, never *OK*, never *Delete*. The promise is repeated after the fact in the cleared state and in the SnackBar, because a reader who has just emptied a list is exactly the reader who will wonder what else went with it.

**States**: *Loading* — none; the options are local values and the entry count is a local count. *Filled* — as above. *Empty* — **not a state**: there is always at least one option, and selecting one always resolves to a definite window. *Load error* — none; nothing is fetched. *Submit error* — a preference write that fails keeps the sheet open on the **previous** window with a field-level error, and never applies a window the app cannot remember. *Success* — the sheet closes, the notice and the terminal line both re-render in place, and a SnackBar names the new window. *Offline* — **identical**: a retention window is a local preference. *Read-only* — none.

---

## 12. Tokens this screen cites

Every value below is the one `design-system.md` declares, so `design-check tokens-used` can re-derive it. Only the colour rows are contrast-measured.

| Token | Day | Night | Measured (day / night) | Where it appears here |
|---|---|---|---|---|
| `--color-background` | `#F5F2ED` | `#121315` | — | Page field behind the full-bleed rows |
| `--color-surface` | `#FBF9F6` | `#1A1C1F` | — | Row strips, skeleton lines |
| `--color-surface-raised` | `#FEFCF9` | `#232629` | — | Bound notice, `RetentionSheet`, the clear dialog, the snackbar |
| `--color-surface-sunken` | `#EBE7E0` | `#0C0D0F` | — | Skeleton row lines, and a row in its `pressed` state (`design-system.md` § 2.1) |
| `--color-text-primary` | `#1A1714` | `#E8E4DD` | **14.48:1** / **12.00:1** | Screen title, novel titles in rows, the notice's first sentence |
| `--color-text-secondary` | `#5A524A` | `#A8A29A` | **6.22:1** / **6.01:1** | **Chapter titles (B10, verbatim)**, relative times, the notice's second sentence, the terminal line |
| `--color-text-inverse` | `#FDFAF6` | `#17181A` | **5.54:1** / **7.27:1** | Label on the empty state's primary button and on the dialog's destructive button |
| `--color-accent` | `#8A4B12` | `#E3A857` | **5.50:1** / **7.25:1** | **The focus ring only** — the accent carries "you have not opened this", and every row here has been opened (B13) |
| `--color-error` | `#8A3228` | `#EE8B76` | **6.64:1** / **6.22:1** | The store-failure `ErrorState` icon — the only error this screen can have |
| `--color-border` | `#D9D3C9` | `#2E3237` | exempt | Rules between rows and above day-group gaps |
| `--color-border-field` | `#8F8778` | `#6B6560` | **3.18:1** / **3.24:1** | The unselected radio control in `RetentionSheet` |
| `--color-border-focus` | `#8A4B12` | `#E3A857` | **6.07:1** / **8.86:1** | 2dp focus ring on every focusable element |

Two tokens the other three screens cite are **deliberately not cited here**: `--color-text-disabled`, because this screen has no disabled control — every action on it is either available or absent; and `--color-border-strong`, because that token marks a **selected** row, and this screen has no selection at all. § 2.1 explains why: a per-row select is the control this screen refuses.

Non-colour tokens cited: `--text-h1` `#31 / 38`; `--text-h3` `#20 / 26`; `--text-h4` `#18 / 24`; `--text-body-sm` `#14 / 20`; `--text-caption` `#12 / 16`; `--text-overline` `#11 / 16` (600, 0.08em); `--space-xs` `4dp`; `--space-sm` `8dp`; `--space-md` `12dp`; `--space-lg` `16dp`; `--space-xl` `24dp`; `--space-3xl` `48dp`; `--radius-sm` `4dp`; `--radius-md` `8dp`; `--radius-lg` `16dp`; `--radius-full` `999dp`; `--border-width` `1dp`; `--border-width-strong` `2dp`; `--shadow-sheet` `0 8 24 rgba(0,0,0,0.18)`; `--shadow-dialog` `0 16 48 rgba(0,0,0,0.24)`; `--duration-fast` `120ms`; `--duration-normal` `200ms`; `--ease-standard` `cubic-bezier(0.2, 0, 0, 1)`.