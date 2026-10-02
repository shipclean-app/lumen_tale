---
type: screen
slug: novel-details
title: Novel details
module: library
status: approved
generated_at: 2026-10-02
derived_from:
  - .forge/prd.md
  - .forge/design/design-system.md
rule_ids:
  - B9
  - B10
  - B11
  - B12
  - B13
  - B14
  - B15
  - B18
  - B19
  - B22
  - B24
  - B26
  - B28
  - B32
  - B33
  - B40
  - B48
  - B49
edge_case_ids:
  - E1
  - E2
  - E3
  - E4
  - E5
  - E6
  - E8
  - E9
  - E10
  - E12
  - E16
  - E20
flow: library-loop
---

# Screen — Novel details

> The source of truth for generating this screen. It is the densest surface in the app: a collapsing cover header, a metadata block, a three-slot action row, and the **complete** chapter list. Its one dialog (bulk download) and its similar-title warning are specified here, in § 11, because they are surfaces of this screen and not destinations.

---

## 1. Role of the screen

| | |
|---|---|
| **App archetype** | `mobile_consumer` |
| **Module** | library — **rank 1 of 5** in the bottom navigation; this is the library's detail page, not a tab of its own |
| **Route** | `/library/novel/:novelId` |
| **Type** | detail page (`design-system.md` § 4.2: collapsing cover header, metadata block, action row, chapter list) |
| **Users** | the reader deciding whether to keep and download a novel; the reader returning to reach one specific chapter of a novel they already keep |
| **User stories served** | US-03, US-09, US-07, US-06, US-11, US-10, US-16 |
| **Business rules** | B9 B10 B11 B12 B13 B14 B15 B18 B19 B22 B24 B26 B28 B32 B33 B40 B48 B49 |
| **Edge cases** | E1 E2 E3 E4 E5 E6 E8 E9 E10 E12 E16 E20 |

**In one sentence**: this screen lets the reader keep a novel, start downloading it, and reach any chapter of it by name and number, with every chapter the site lists shown in the site's order and the site's own words.

**Why it belongs to the library module**: keeping and following are the same act (B11), so this screen *is* the library's detail, and it sits inside the library's shell branch — the reader tabs back to the shelf with the scroll position and the title query intact.

---

## 2. Visual direction for this screen

| | |
|---|---|
| **Mood** | quiet, warm, unhurried — but long: this is the only scrolling surface in the app with more than one screenful of content, so it must stay readable at the four-hundredth tile |
| **Density** | **normal**, leaning compact at the header. Justified: the header has three facts and a description, so it earns its 168dp; the chapter list is `ChapterListTile` at 56dp and stays there, because a chapter list that grows to 72dp turns 4 812 chapters into 386 000dp of scrolling (E1) |
| **Contrast level** | **high** — `--color-text-primary` `#1A1714` / `#E8E4DD` measures **14.48:1** / **12.00:1** on the row field. A read chapter drops to `--color-text-secondary` `#5A524A` / `#A8A29A` at **6.22:1** / **6.01:1** and no further; the read/unread distinction must survive at 6:1, because half of a long list is read |
| **Surface** | rows on `--color-surface` `#FBF9F6` / `#1A1C1F` full-bleed over `--color-background` `#F5F2ED` / `#121315`; the collapsed header bar and the app-bar actions sit on `--color-surface-raised` `#FEFCF9` / `#232629`, raised by a background step and **not** by a shadow; the cover banner and the skeletons use `--color-surface-sunken` `#EBE7E0` / `#0C0D0F` |
| **Accent used** | `--color-accent` `#8A4B12` / `#E3A857` — on exactly four things: the primary action, the 3dp leading edge of the `current` tile, the determinate download bar, and the focus ring. It appears **nowhere in the chapter list except those**, because an accent per unread row would draw a stripe down a 4 000-row list and make the reading position invisible |
| **Photographic treatment** | **banner, never a backdrop** — the cover is a 140dp full-bleed image **above** the title, `--radius-none`, no scrim, no gradient, and **no text over it**. A cover used as a background for the title needs a scrim token this design system does not declare, and inventing one is how a header starts washing out the artwork it is showing |
| **Reference** | a good print table of contents: the work's identity at the head, a short apparatus, then the contents in full, in order, without an index |

### 2.1 Anti-generic — mandatory

This screen must not resemble any of these defects:

- [x] **No pure white `#FFFFFF` background** — `--color-background` is `#F5F2ED` day / `#121315` night.
- [x] **No shadowed card for the content.** The chapter list is not a card, the metadata block is not a card, and the header is not a floating card over a page: it is a full-bleed banner that collapses into a 56dp bar. The only shadow on this screen is `--shadow-dialog` under a confirm dialog — the same one shadow budget as the whole app.
- [x] **Not uniform.** `--text-h2` 25/32 700 for the novel title, `--text-h4` 18/24 for a chapter title, `--text-body` 16/24 for the description, `--text-body-sm` 14/20 for the author, `--text-caption` 12/16 tabular for the number and the timestamp, `--text-overline` 11/16 600 with 0.08em for the two section labels. Five scales on one screen, and the chapter tiles hold a single scale for 4 000 repetitions so the list reads as a rhythm rather than as typography.
- [x] **No generic grey `#6B7280`** — the paper-anchored neutral ramp, as everywhere.
- [x] **No symmetric centring as the layout.** The banner is full-bleed, the metadata block is left-aligned under `--space-lg` margins, and the chapter tiles are full-bleed rows with internal `--space-md` padding. Nothing on this screen is centred except the 140dp cover's own crop.
- [x] **No generic spot illustration** — the empty-data state is a sentence and a `secondary` that leaves the app; the error state is a sentence naming the site and a retry.
- [x] **Not one typeface at one weight** — the same reasoning as the library: one family is correct for a contents list, and the hierarchy is carried by scale and tracking instead. ADR-017's serif belongs to prose, and a chapter list is not prose.

**Assumed, non-neutral choice**: **the chapter list has no sort control, no filter row, no search box and no pagination — and the one affordance that replaces them is a jump to the reading position.** B9 and B10 permit exactly one order, the site's, and no other order may be offered: a sort menu here would be a control whose only legal result is the order already displayed, which teaches the reader that this screen's controls do not do anything. Its corollary is the action row: **exactly three slots, permanently**, which can never grow a fourth button — no share, because B30 makes sharing out of the app impossible; no favourite star, because B11 says keeping *is* following and a second mark would be a second list wearing a different icon; no "mark as completed", because no rule defines a completed state and B39's note records that the check's completed flag was deleted for exactly that reason. What the screen offers instead is pinned: the action row stays under the collapsed header while the reader scrolls nine thousand chapters down, so B18's download is one thumb-reach away at any depth.

---

## 3. Anatomy

```
AppScaffold (titleBar, bottomNav, persistentStatus)
├── SliverAppBar — expanded 168dp, collapsed 56dp, pinned
│   ├── BackButton · OverflowButton      Check this novel now (B36) · Remove from library (B32)
│   ├── CoverBanner  140dp, --radius-none, --surface-sunken placeholder; NO text over it
│   └── CollapsedTitleBar                novel title verbatim, --text-h4, on --color-surface-raised
├── MetadataBlock                         --space-lg margins, --space-lg between groups
│   ├── NovelTitle                        --text-h2 25/32 700, the site's own title, one line + ellipsis
│   ├── AuthorLine                        --text-body-sm, --color-text-secondary, omitted when the site gives none
│   ├── SourceLine                        --color-info + icon, "Royal Road"  — never a bare name
│   ├── DescriptionParagraph              --text-body 16/24, site text, collapsed at 4 lines + "More"
│   └── StatusLine                        StatusChip local "12 not opened" + StatusChip never-checked / last checked
├── ActionRow                             pinned, 3 slots, 44dp buttons in a 56dp bar, --space-md gaps
│   ├── Slot1  Add to library | Continue | Read from the start
│   ├── Slot2  Download  → BulkDownloadSheet (B18)  ·  determinate progress  ·  StatusChip downloaded
│   └── Slot3  Mark as read   (disabled at 48dp with wording when nothing is unopened)
├── ChapterList                           full-bleed tiles, --space-md padding, --color-border rules
│   ├── ChapterListHeader                 overline "CHAPTERS" + "4 812 chapters · as Royal Road lists them"
│   │                                     + [Jump to current chapter] when a position exists
│   ├── ChapterListTile variant list      56dp — default · read · current (3dp accent edge) ·
│   │                                     downloading (2dp determinate line) · failed (icon + words + retry) ·
│   │                                     offline-and-absent (labelled "not downloaded")
│   ├── SelectionBar (multi-select)       long-press a tile → hand-picked download set (B18)
│   └── ChapterListTailMarker             terminal line, only when the 10 000 bound is reached (B9)
└── ConfirmDialog · Dialog · SnackBarHost · ErrorState · EmptyState(no-chapters) · LoadingState
```

| # | Component | Role | Source |
|---|---|---|---|
| 1 | `ChapterListTile` variant `list` | One chapter, 56dp, six states | design-system § 2.2 |
| 2 | `ChapterListTile` variant `current` | The tile carrying the reading position's 3dp accent edge | design-system § 2.2 |
| 3 | `StatusChip` | Carries B48's count and B49's verification state | design-system § 2.5 |
| 4 | `PrimaryButton` / `SecondaryButton` / `TextButton` | The three action slots, and every dialog | design-system § 2.3 |
| 5 | `NovelRow` variant `compact` | **not used here** — a novel is not listed on its own detail page; recorded because a generic implementation reaches for a related-novels strip and there is none | design-system § 2.1 |
| 6 | `EmptyState` instance `no-chapters` | The genuine-empty case | design-system § 2.7 |
| 7 | `ErrorState` | Distinguishes *could not read the site* from *nothing there* | design-system § 2.7 |
| 8 | `LoadingState` | Tile-shaped skeleton | design-system § 2.7 |
| 9 | `AppScaffold` | Title bar, bottom nav, `persistentStatus` | design-system § 2.8 |
| 10 | `CollapsingCoverHeader` | **slice-local**: banner + collapsing bar + the pinned `ActionRow`. Declared here rather than in the design system because it composes three existing pieces; if a second screen ever collapses a header, it is promoted there |

---

## 4. States — all nine, no exceptions

| State | Trigger | Rendering | Reader feedback |
|---|---|---|---|
| **Loading** | **First** open of a novel that was never stored. The metadata arrives with the route, so the banner and the title render **immediately** and only the list is pending; the reader sees the novel's identity while the list builds | `LoadingState` shaped like the content: the 140dp banner is a `--color-surface-sunken` block, the description is three `--color-surface` lines of decreasing width, and the list is **twelve** `ChapterListTile` skeletons — 56dp each, with a 32dp number block, a two-thirds title line and a trailing state-icon block. Shimmer `--duration-normal`, off under reduce-motion | None. The identity is already on screen, so nothing announces a wait |
| **Filled** | The normal case — a kept novel with a stored chapter list | The whole anatomy above: banner, metadata, pinned action row, complete chapter list in site order | — |
| **Filled — stored list, no network** | Every subsequent open | **The list is local and renders from the first frame**: no skeleton, no spinner, no fetch. The screen makes **zero** network calls on every open after the first (C14) | Nothing. This is the second most common open in the app and it must feel like the first |
| **Empty — never visited** | A novel reached **without** the reader asking for its contents — a restored back stack, a deep link, a notification tap — and nothing about it is stored: not in the library, no chapter list, no description. B5 forbids fetching speculatively, and opening a novel from a catalogue is a request for its chapters (US-03) while a restored back stack is not | The banner and title render from what the route carried; the description and chapter regions are replaced by `EmptyState`: title *Not in your library yet*, body *Lumen Tale has not read this novel's chapters yet.*, and **two** actions — `primary` **Add to library** and `secondary` **Load the chapter list**. The second is the B5 ask, in words, before a single request goes out | Asking before fetching is the difference between a fast screen and a polite one; B5's cost is storage, and this is where it is respected |
| **Empty — no data** | The site answered **and carried its own explicit empty-result signal** (B22's discriminator). This is the one place "empty" is a genuine answer and not a symptom | `EmptyState` instance `no-chapters`: title *Royal Road lists no chapters for this novel*, body *The site itself reports an empty chapter list. This is not a failure to read it.*, and a `secondary` **Open the page at Royal Road**. **Never** the bare number "0 chapters", and never an empty scrollable list | The sentence names the site and says the emptiness is the site's own claim — because the alternative reading, "the app failed", is the mistake B22 exists to prevent |
| **Load error** | Three distinct causes, three distinct sentences — they must never look alike | **(a) The site could not be read** (E4, E8, B22): `ErrorState` with `--color-error` icon, *Royal Road could not be read. Its pages have probably changed.* and a `secondary` **Try again**, plus one line naming what still works: *Your 148 downloaded chapters are still readable.* (B23) **(b) The list was never fetched and there is no connection**: `EmptyState` *The chapter list has not been loaded yet*, with **Load the chapter list** disabled at 48dp and the sentence *Loading needs a connection* — not an error, because nothing failed **(c) The stored list could not be read**: a distinct `ErrorState`, *Your saved chapter list for this novel could not be read. Downloaded chapters are unaffected.* | (a) says the *site* failed and offers retry; (b) says nothing failed and names the missing precondition; (c) says the *device's copy* failed. Three causes, three sentences, because B22 is the difference between "could not read" and "genuinely nothing" and it is worthless if the app renders both as an empty list |
| **Submit error** | The submissions here are **Slot 2's bulk download**, **Slot 3's mark as read**, and **Add to library**. Download refused for storage (E20): a dialog — *The download did not start. The phone has not enough free space.* — with `secondary` **Delete a chapter** and `primary` **Try again**; nothing is enqueued and no tile shows progress. Mark-as-read refused: **every chip and every tile stays exactly as it was**, and a SnackBar says *Nothing was changed*, because an optimistic re-render that a failed write cannot undo would be the app lying about its own state | Both errors name the cause and the untouched state. A bulk action that half-applies is not representable in this UI, and that is the point |
| **Success** | Slot 2 completed; Slot 3 completed; a novel was added | Slot 2: the button becomes `StatusChip` `downloading` with a determinate bar, then `downloaded` — the state lives in the control, not in a toast the reader has already missed. Slot 3: the affected tiles flip to `read` and the header count falls to `0 not opened`, plus SnackBar *Marked 12 chapters as read*. Add: Slot 1 becomes **Continue** (or **Read from the start**) and a SnackBar *Added to your library* | Every success is legible in the widget that caused it. The count falling in the header is the confirmation; the toast is redundant on purpose |
| **Offline / permissions** — *downloaded* | No connection, novel downloaded | **Identical to Filled**, plus one auto-dismissing line on the first offline open of a session: *reading and downloading are both off this screen*. No banner, no dimming | Nothing. Announcing offline state on a screen that works offline would make offline reading feel like a degraded mode, which is the opposite of what it is |
| **Offline / permissions** — *not downloaded* | No connection, novel has no stored chapters | Every not-stored tile renders `ChapterListTile`'s **offline-and-absent** state: the row is present, its trailing slot reads *Not downloaded*, and tapping it opens the reader's not-downloaded error — which offers **Download this chapter** — rather than an empty screen or a silent skip (US-05's acceptance criterion) | The reader can tell "not yet downloaded" from "empty" from "failed" in all three cases, with words in every one |
| **Offline / permissions** — *actions that need a network* | No connection, reader taps a network action | **Check this novel now** and **Load the chapter list** and **Download** stay visible; each opens its surface with the action button `disabled` at 48dp and the sentence *Checking needs a connection* / *Downloading needs a connection*. **`Mark as read` and `Add to library` stay enabled**: both are local writes, and disabling them would be telling the reader the app cannot do something it can do | The reader learns precisely which two of the four actions are network-bound, every time, from the control itself |
| **Read-only** | Unconditional | **The novel's own data is read-only, and so is every chapter body.** There is no edit affordance anywhere on this screen: the title, the author and the description are the site's, displayed verbatim, and the only place they can change is the site. There is no share and no export (B30). The stored Markdown is a file the app can read and delete but never rewrite, and the site's chapter numbering is never overwritten by ours (B10). B33's per-chapter delete lives in Downloads, where it can be unambiguous about what it frees | The absence *is* the implementation. The one thing the reader can change here is what they keep and what they fetch — never the content |

> Three of the nine have no single rendering and each says why: offline splits into three because "offline" is one fact with three consequences, load-error splits into three because a failed site, an unfetched list and an unread stored list are three different problems that must not share a sentence, and read-only has no *variant* because the whole screen is unconditionally read-only with respect to content.

---

## 5. Interactions

| Element | Event | Behaviour | Visual feedback | Resulting state | Rule |
|---|---|---|---|---|---|
| Back button / system back | tap / gesture | Pop to the library branch, whose scroll offset and title query are intact | `--duration-normal` 200ms reverse slide | Library, Filled | — |
| Cover banner | tap | **Open the novel's page at the site in the browser.** A novel not yet added is the only place the reader can see the site's own page, and following a URL the app found in a page is explicitly permitted (B44) | Standard browser hand-off | — | **B44** |
| Overflow · **Check this novel now** | tap | Check this one novel's chapter list. **Not** confirmed, for B38's reason: a check downloads nothing. This is a manual action and is available whatever the schedule is | `loading` button state; `persistentStatus` *Checking 1 of 1 novel · nothing is downloaded* | Filled, timestamp updated | **B36**, **B38** |
| Overflow · **Remove from library** | tap | Dialog whose body is B32: *Removed from your library. Its 148 downloaded chapters stay on this phone.* + `TextButton` **Delete the downloads instead** → `/more/downloads`. Cancel is default; Remove is `danger` | Row disappears; SnackBar *Removed from your library* with **Undo**, which restores the library entry and nothing else | Filled, no longer kept | **B32**, **B33** |
| **Slot 1** — `Add to library` | tap | Adds. If a library entry has the same or a similar title, the **similar-title warning** fires first (§ 11.2) — the existing novel is named with its site, and the choices are **Open the existing novel** / **Add anyway**. There is no merge option and no rename | Slot 1 becomes **Continue** | Filled, kept | **B12**, **B40** |
| **Slot 1** — `Continue` | tap | Open the reader at the stored position of this novel's most recent chapter. Label carries the chapter's own title | No transition into the reader | Reader at position | **B16**, **B17** |
| **Slot 1** — `Read from the start` | tap | Open the reader at chapter one | No transition into the reader | Reader | **B9** |
| **Slot 2** — `Download` | tap | `BulkDownloadSheet`: B18's own list — next chapter · next 5 / 10 / 25 · **all unopened chapters** · a set you pick by hand — each with a running chapter count, then one confirm naming the count, the data cost, and that the queue can be paused or cancelled | Sheet + confirm; then the button becomes the progress state | Downloading | **B18** |
| **Slot 2** — running | — | Determinate bar inside the control; `persistentStatus` carries *212 of 480 · pause · cancel* for the rest of the screen | Accent fill advances | Downloading | **B18**, **B19** |
| **Slot 3** — `Mark as read` | tap | Confirm: *Mark all 12 chapters you have not opened as read?* Then writes the same field opening a chapter writes, so every count in the app falls identically | Tiles flip to `read`; header count falls to 0 | Filled, zero unopened | **B13**, **B14** |
| **Slot 3** — disabled | tap | Present only when nothing is unopened; it is `disabled` with the wording *Nothing unopened*, at full 48dp so the action row never reflows | — | Unchanged | **B13** |
| `ChapterListHeader` — **Jump to current chapter** | tap | Scroll the list to the `current` tile, at `--duration-normal`; with reduce-motion it jumps | Tile lands under the pinned header | Filled | **B16** |
| `ChapterListTile` — stored chapter | tap | Open the reader at that chapter's stored position | No transition into the reader | Reader | **B16** |
| `ChapterListTile` — not stored, online | tap | Open the reader, which fetches it (B5: the reader asked) and shows its loading skeleton | — | Reader, Loading | **B5** |
| `ChapterListTile` — not stored, offline | tap | Open the reader's **not-downloaded** error state, offering **Download this chapter** | — | Reader, offline-and-absent | **B15** |
| `ChapterListTile` — downloading | tap | **Ignored.** A tile in flight is not a target | — | Unchanged | **B19** |
| `ChapterListTile` — failed | tap | Open the reader's error state with its retry, which re-enqueues **that chapter** only | — | Reader, Load error | **B22**, **B24** |
| `ChapterListTile` | long-press | Enter chapter selection mode for a hand-picked download set (B18's sixth choice). The action bar reads *n selected · Download · Cancel*, and **Add to library is not in it** — a selection is a download instrument, not a membership instrument | Tiles take the selected state (2dp `--color-border-strong`, accent 10% fill) | Selection | **B18** |
| Chapter list | scroll | The banner collapses to the 56dp bar over `--duration-normal`; the action row stays **pinned** beneath it | — | Filled | — |
| Chapter list | pull-to-refresh | **Absent**, as on the library: the explicit labelled action is the only trigger, and opening a novel is visibly not one | — | — | **B36** |
| Chapter list | filter / sort / search | **Absent, permanently.** B9 and B10 allow one order — the site's — so no control here may produce another | — | — | **B9**, **B10** |
| Chapter list | end of list | Nothing. There is no next page, no "show more", and no lazy fetch: the list is complete or the app says it is not (§ 4, B9's bound) | — | Filled | **B9** |

- **Focus / keyboard**: D-pad moves through the app-bar buttons, the three action slots, then tile to tile; the focus ring is 2dp `--color-border-focus` with a 2dp offset. `Enter` opens the focused chapter. In selection mode the menu key toggles the focused tile and `Esc` exits. Focus entering the list programmatically (Jump to current chapter) lands on the `current` tile, announced as the reading position.
- **Gestures**: tap, long-press, vertical scroll, back swipe. No swipe on a tile — no swipe-to-download and no swipe-to-delete, because on a device with no backup (C8, ADR-010) the destructive gesture must never be the easy one (B32).
- **Animations**: header collapse `--duration-normal` 200ms `--ease-standard`; sheet and dialog as in the library; **push into the reader has no animation** (design-system § 3.4); the determinate bar advances per chapter, not on a timer, so it never animates while nothing is happening. All durations become `0ms` under reduce-motion.
- **Back**: system back pops; **no position is written on back**. Position is already saved on every scroll settle in the reader, so a back press here must not cost a write on the hot path.

---

## 6. Responsive

| Breakpoint | Behaviour | What collapses or disappears |
|---|---|---|
| **Mobile** `< 600dp` | The design target. Single column, `--space-lg` 16dp margins on the metadata block, chapter tiles full-bleed with `--space-md` internal padding, `--space-3xl` 48dp top margin | Nothing — this is what ships |
| **Tablet** `600–1023dp` | **Identical single column, centred, capped.** The content column stops at the `--reader-md` measure width and centres, and **deliberately does not** become a two-pane master/detail with the chapter list in a side rail — ADR-010 and C3 put tablet out of scope, and a two-pane version of this screen would be the single most expensive layout in the app to get right on a device nobody will test it on | Nothing collapses — the layout simply stops growing |
| **Desktop** `1024–1439dp` | Same single column, centred. Flutter desktop is out of scope (C3) | — |

`--bp-wide` `≥ 1440dp` follows the same capped-and-centred rule by declaration (`design-system.md` § 1.7); the chapter list never widens past the measure, because a chapter title stretched across 1 400dp is the same failure the reader's prose column is capped against.

- **Touch target**: 48dp minimum everywhere. Tiles are 56dp; the three action slots are 44dp tall inside a 56dp bar, and the disabled state keeps the 48dp so the row never jumps; the jump-to-current-chapter control is a 48dp `TextButton` in the list header; the overflow button is a 48dp square.
- **Overflow**: **guaranteed never to overflow.** The title truncates to one line at `--text-h2` with an ellipsis; the description collapses at four lines behind **More**; a chapter tile's title truncates to **two** lines at `--text-h4`, and because B10 requires the site's title verbatim, the full string is reachable two ways — the tile expands in place on tap-and-hold of the title area... no: the full title is always available in the reader's `reader-chapter-sheet`, and **a tile whose title is truncated says so with a trailing ellipsis, never a shortened title**. An irregular title such as *Omake* or an untitled chapter is never dropped, never merged and never renumbered (B10, E2, E10).

---

## 7. Accessibility

- [x] **Contrast 14.48:1** (day) / **12.00:1** (night) for the novel title and for unopened chapter titles — measured.
- [x] **Contrast 6.22:1** / **6.01:1** for a **read** chapter's title and for the author line. This is the pair that decides whether a long contents list is usable, because half its rows are read and the read state is carried by that token alone.
- [x] **Contrast 6.07:1** / **8.86:1** for the focus ring, non-text per WCAG 1.4.11 at 3:1.
- [x] **No state by colour alone** — the six `ChapterListTile` states each carry a second channel: read is a **tonal** change plus the tile's `trailing` state icon; downloading is a determinate **line** plus its percentage in the semantics label; failed is an icon **and** the words *failed · retry*; offline-and-absent is the words *Not downloaded*; the reading position is a **3dp leading edge** plus the word *Reading position* in the semantics label. No state here is a hue.
- [x] **Keyboard navigation complete** over the app bar, the three action slots and every tile; focus visible at 2dp with a 2dp offset, never removed; the pinned action row never traps focus above the list.
- [x] **Semantics per tile**, one node: *"Chapter 214, The Weight of Quiet Water, not opened, downloaded"* — the state words are in the label, because "the tile is grey" is not a state a screen reader can report.
- [x] **Semantics for the pinned bar**: the three slots are labelled by their **current** function, not their origin — a slot that says *Continue* announces *"Continue, Chapter 214, at 41% of this chapter"*, so the reader learns what the button will do before pressing it.
- [x] **Text alternative for the cover**: decorative, `excludeSemantics`, because the title beside it is the information; the 140dp banner is a picture of a book cover and announcing it as *"cover image"* would be noise on every one of the reader's visits.
- [x] **Live region** on `persistentStatus` while a queue runs, so *212 of 480* is spoken as it changes; the completion message is announced too, because the reader is often in the chapter list rather than looking at the bar.
- [x] **Language and reading direction** correct: all chrome strings follow the app locale (B28) with French fallback, and **chapter titles are never translated** — they are the site's, in the site's language, displayed as published (§ 7.4 of the PRD).
- [x] **Reduce-motion honoured**: the header collapse becomes instant, the jump becomes a jump, the skeleton stops shimmering.

---

## 8. Data

| Field | Type | Origin | Required | Possible error |
|---|---|---|---|---|
| `novel.id` | `String` | route + local store, stable across restarts (B3) | yes | — |
| `novel.title` | `String` | site, stored verbatim | yes | Empty at the source → the novel is never added |
| `novel.author` | `String?` | site, stored | no | Absent → the author line is omitted and the block closes up |
| `novel.description` | `String?` | site, stored as text (B44: markup is never executed or kept) | no | Absent → the paragraph is omitted; **never** a placeholder of dashes |
| `novel.sourceName` / `novel.sourceUrl` | `String` / `Uri` | stored; the URL is the app's own recorded address for this novel | yes | A URL the app found in a page is followed as a link, never obeyed as a command (B44) |
| `novel.chapterCount` | `int` | local, over stored chapter metadata | yes | — |
| `novel.unopenedCount` | `int` | local, exact (B14, B48) | yes | — |
| `novel.lastCheckedAt` | `DateTime?` | local | no | `null` → **Never checked** (B49) |
| `novel.lastCheckError` | `String?` | local | no | → *could not check* / *no longer at Royal Road* (B22, E9) |
| `chapter.id` | `String` | local | yes | — |
| `chapter.title` | `String` | site, stored and displayed **verbatim** (B10) | yes | Empty at the source → the tile shows the number and the word *Untitled*, never a placeholder index |
| `chapter.number` | `double?` | local, via the source's recognition | no | Unparseable → `null`, rendered as `—`, **never as `0`** (B10, E2) |
| `chapter.isOpened` | `bool` | local | yes | The single field B13 and B14 turn on |
| `chapter.isDownloaded` | `bool` | local, true only when the file is wholly present (B6) | yes | Interrupted → `false`, so the tile reads *Not downloaded* and never a partial text (E6) |
| `chapter.downloadProgress` | `double?` | live queue state | no | `null` → no bar |
| `chapter.failure` | `String?` | local | no | → `failed` state with retry |
| `readingPosition` | `(chapterId, offset)` | local, **never trimmed** (B46) | no | Absent → no `current` tile, and **Jump to current chapter** is not rendered at all |
| `similarTitles` | `List<Novel>` | local, computed on add | no | Empty → no warning; never fuzzy-matched into a false positive without saying which titles matched |

- **Loading**: **the chapter list loads in one block, never in pages.** No lazy fetch, no "show more", no page spinner anywhere — B9 forbids dropping or deferring an entry, and a paged list is a deferred entry. The list is virtualised: 10 000 tiles build as the reader scrolls, and every tile's read/downloaded flags come from the local store rather than from a per-tile query. Past the 10 000 bound of B9 the tail marker states how many chapters the site lists beyond what is displayed — **a number and a sentence, not a button**, because a button would promise an order B10 does not permit.
- **Cache / offline**: **the first open fetches the chapter list once; every open after that makes zero network calls** (C14). The metadata block, the counts, the timestamps and every tile state are local, which is why the offline state is byte-identical to Filled.
- **Sensitive data**: chapter bodies are **not loaded on this screen at all** — no Markdown is read here, so none can be logged. Error logs carry the novel id, the source name and a chapter id; **never a chapter title, never chapter text** (B29). There is no share or export action anywhere (B30).

---

## 9. Traceability

| ID | Origin | Manifestation on this screen |
|---|---|---|
| B9 | PRD | The list is complete, in site order, with no page spinner, no "show more" and no lazy fetch; above the 10 000 bound a terminal line states how many chapters are not displayed |
| B10 | PRD | Every chapter title is the site's, verbatim, never renumbered or reordered. Our parsed number sits in the `number` slot at `--text-caption`; when it cannot be parsed the slot shows `—` and **the site's own numbering remains in full in the title**, which is where an unparseable numbering is shown. Irregular titles — *Ch. 12.5*, *Vol 3*, *Extra*, *Omake*, untitled — all render and all open |
| B11 | PRD | **Add to library** and following are the same act; there is no star, no watch button and no second list |
| B12 | PRD | The novel enters only through this screen's `primary` action, and only for a novel opened from a site — which is also why the empty-never-visited state asks before it fetches |
| B13 | PRD | A tile is unread until opened; `Mark as read` writes the same field opening a chapter writes |
| B14 | PRD | The header count is an exact local integer; it changes when a chapter is opened, never when a check runs |
| B15 | PRD | Offline, **Check this novel now** says it needs a connection and the last-checked timestamp stays exactly as it was, stale and visible |
| B18 | PRD | The download surface is B18's own six choices with running counts, plus a hand-picked set reached by long-press |
| B19 | PRD | Pause and cancel live in `persistentStatus`; a cancelled chapter's tile returns to *Not downloaded* and never keeps a progress bar |
| B22 | PRD | *Could not read the site*, *the site says there is nothing*, and *your stored list is unreadable* are three sentences. This screen never shows an empty list where it could not read one (SC-6's surface) |
| B24 | PRD | Every failure offers a retry and names what still works |
| B26 | PRD | The header, the list and the pinned bar re-theme on the phone's light/dark setting, with the in-app override one tap away in the reader |
| B28 | PRD | All chrome is ARB with French fallback; chapter titles are the one thing deliberately **not** localised |
| B32 | PRD | The removal dialog states the downloads stay and links to the one place they can be deleted |
| B33 | PRD | Per-chapter deletion is not offered here; it lives in Downloads, where "this frees its space and leaves the others untouched" can be said about one row |
| B40 | PRD | The similar-title warning names both sites and offers **Open the existing** / **Add anyway** — and no merge, no rename |
| B48 | PRD | The count renders as a local fact with no reference to any check, in the `local` chip next to the verification chip |
| B49 | PRD | **Never checked** is its own chip in the information token, wording only. The screen never implies there is nothing new for a novel it has not looked at |
| E1 | PRD | A 120-chapter novel and a several-thousand-chapter novel both render completely and in order, virtualised, with identical rendering cost per tile |
| E2 | PRD | Irregular and untitled titles render verbatim and stay openable; an unparseable number shows `—`, never `0` |
| E3 | PRD | A chapter spread over several site pages is **one** tile, never three — the page split is a source concern that never reaches the list |
| E4 | PRD | A changed layout produces the site-could-not-be-read state with a retry and a line about the downloaded chapters still being readable |
| E5 | PRD | Offline, the screen is either identical to Filled or the unfetched-list state — and the actions that need a network say so in their own sentence |
| E6 | PRD | An interrupted download leaves its tile reading *Not downloaded*; nothing partial is ever shown as readable |
| E8 | PRD | A page that loads with none of the expected chapter elements is a **failure**, not an empty novel |
| E9 | PRD | Online, a vanished novel reads *no longer at Royal Road* and keeps its stored chapters reachable; offline, the screen makes no claim about the site at all |
| E10 | PRD | Two entries with the same site title are **both** listed, in the site's order, and neither is merged or hidden |
| E12 | PRD | A language change re-localises the whole screen with no loss of the novel, the list or the selection |
| E16 | PRD | A chapter the site published after the last check is invisible until a check finds it, and the header's count and timestamp never imply otherwise |
| E20 | PRD | A queue that exhausts storage stops, says why, keeps what it finished, and records no partial chapter as complete |

---

## 10. Gate checklist

- [x] All nine states described with a concrete rendering; the three that split or explain say **why** (offline splits three ways, load-error names three different failures, read-only has no variant because the screen is unconditionally read-only with respect to content).
- [x] Every interactive element has a behaviour, a feedback, a resulting state and a rule ID.
- [x] Responsive defined at **every** breakpoint of the design system; the two larger ones say "identical, stop widening" — ADR-010, and the rejected two-pane layout is named so nobody re-proposes it as an improvement.
- [x] Anti-generic section checked **and justified**; the assumed choices are stated (no sort/filter/search on the chapter list, and an action row that can never grow a fourth button).
- [x] No design value left "to be defined". Every colour, size, duration and easing cited exists in `design-system.md` with its value.
- [x] Every B/E/C ID on this screen appears in § 9.
- [x] `forge-guard placeholders` reports nothing here.
- [x] Consistent with `design-system.md`: `ChapterListTile` is rendered in exactly the states its contract declares, and its `number`, `title`, `stateIcon`, `progress` and `trailing` slots are all populated — the cover slot of `NovelRow` is deliberately **not** rendered, and that is recorded in § 3 rather than left to the implementer. The one place this screen renders something the component does not declare — a **selected** tile for B18's hand-picked set — borrows `NovelRow`'s published `selected` grammar and is recorded as a design-system gap in § 11.3 rather than invented.
- [x] Material 3 primitives only (`CustomScrollView` + `SliverAppBar`, `SliverPersistentHeader` pinned, `ListView.builder`, `FilledButton`, `OutlinedButton`, `TextButton`, `ModalBottomSheet`, `AlertDialog`, `SnackBar`, `FilterChip`) — ADR-001.
- [x] **Every token cited by this screen exists in the design system, with the value it is given here.** The full citation table is § 12.
- [x] **v1 reading is scroll-only** (ADR-009): this screen contains no page-turn, slide or swipe-to-turn affordance, not even disabled. It contains no reading at all — only navigation into the reader, which is continuous-scroll only.

---

## 11. Sub-surfaces of this screen

### 11.1 `BulkDownloadSheet`

B18's six choices as radio rows, each with a running chapter count beside it: *Next chapter* · *Next 5* · *Next 10* · *Next 25* · *All unopened chapters (212)* · *Chapters you choose*. Then one confirm: *Download 212 chapters. This uses mobile data and storage. You can pause or cancel from the status bar at any time.* **No size estimate is printed** — the app holds no byte figure before it has fetched anything, and a fabricated "≈ 8 MB" is a number the reader will hold against the app on the first night of a real queue.

The sixth choice is reached by long-pressing tiles, not from this sheet, so that "a set the user selected by hand" is literally hand-selected. There is deliberately **no** *every chapter including ones already read* shortcut: B18 makes that reachable only by selecting every chapter deliberately.

**States**: *Loading* — none, and the reason is that every option is computed from stored chapter metadata already in memory; *Filled* — as above; *Empty* — **not a state**, because a novel with zero unopened chapters still has *Next chapter* available and the sheet says so rather than presenting an empty list of options; *Load error* — none, nothing is fetched; *Submit error* — the confirm's refusal path is § 4's storage dialog, and the sheet stays open with its chosen option intact; *Success* — the sheet closes and the control carries the progress, so there is no success state *in* the sheet; *Offline* — **identical**, with every option disabled at 48dp and one sentence, *Downloading needs a connection*; *Read-only* — none.

### 11.2 The similar-title warning (B40)

A `AlertDialog` shown **before** the entry is added, when the library already holds a novel whose title matches:

> **A novel with this title is already in your library**
> *The Ascension of the Ninth Son* — Royal Road, kept since March.
> *The Ascension of the Ninth Son* — FanMTL.
> `secondary` **Open the Royal Road one** · `TextButton` **Add anyway**

Three properties make it a warning and not a merge prompt: it **names both sites**, it offers exactly two ways forward, and **there is no merge, no rename and no alias**. A dialog that offered "merge" would be offering a feature B40 and B2 forbid, and one that silently added the second entry would defeat the point of warning at all. The comparison is on the **title as each site presents it**, so two novels that merely share a genre are never caught by it.

**States**: *Filled* — as above; every other state is **n/a and says so** — the dialog is a two-button confirmation over local data: it loads nothing (the comparison happened before it opened), it cannot fail, it cannot be submitted remotely, and it is not offline-sensitive. Its offline, error and success states do not exist because nothing about it can fail.

### 11.3 Chapter selection, and a gap in the design system recorded rather than papered over

B18's sixth bulk choice is *a set the user selected by hand*, so this screen has a chapter selection mode: long-press a tile, toggle tiles, and the action bar reads *n selected · Download · Cancel*.

**`ChapterListTile` declares no `selected` state.** Its contract (design-system § 2.2) lists default · pressed · read · current · downloading · failed · offline-and-absent, and a selected chapter is none of those — a tile can be *read and selected*, or *unread and selected*, so selection is orthogonal to every state the component declares. Rather than invent a state, this screen renders selection with **the app's single selection grammar, `NovelRow`'s declared `selected` presentation**: a 2dp `--color-border-strong` leading edge plus a `--color-accent` 10% fill, identical to a selected library row. One grammar for one meaning across the app is worth more than a locally invented variant, and `design-check component-parity` will keep every screen honest about it.

**The design system should gain the state**, and that is a decision for its owner rather than for this screen: adding `selected` to `ChapterListTile`'s state table, with the note that it composes with `read` rather than replacing it, would make this screen's borrowing unnecessary. Recorded here so that it is a known gap rather than an accident, and so that `component-parity` flags every other screen that has to make the same borrowing.

Two further constraints on this mode, both from B18: **Add to library is not in its action bar** — a selection is a download instrument, and membership is one act on one screen (B11); and there is **no "select all 4 812"** affordance, because B18 reserves *every chapter including read ones* for deliberate selection, and a select-all button is the opposite of deliberate.

---

## 12. Tokens this screen cites

Every value below is the one `design-system.md` declares, so `design-check tokens-used` can re-derive it. Only the colour rows are contrast-measured.

| Token | Day | Night | Measured (day / night) | Where it appears here |
|---|---|---|---|---|
| `--color-background` | `#F5F2ED` | `#121315` | — | Page field behind the full-bleed tiles |
| `--color-surface` | `#FBF9F6` | `#1A1C1F` | — | Chapter tiles, skeleton text lines |
| `--color-surface-raised` | `#FEFCF9` | `#232629` | — | Collapsed header bar, the download sheet, dialogs, the snackbar |
| `--color-surface-sunken` | `#EBE7E0` | `#0C0D0F` | — | Cover banner placeholder, description skeleton, disabled action fill |
| `--color-text-primary` | `#1A1714` | `#E8E4DD` | **14.48:1** / **12.00:1** | Novel title, unopened chapter titles, the collapsed bar's title |
| `--color-text-secondary` | `#5A524A` | `#A8A29A` | **6.22:1** / **6.01:1** | **Read** chapter titles, author line, description, chapter numbers |
| `--color-text-disabled` | `#6E665C` | `#948E87` | **4.58:1** / **4.69:1** | Disabled *Mark as read*, disabled download options offline, and the `—` placeholder in an unparseable chapter-number slot |
| `--color-text-inverse` | `#FDFAF6` | `#17181A` | **5.54:1** / **7.27:1** | Label on the primary action and on the danger Remove button |
| `--color-accent` | `#8A4B12` | `#E3A857` | **5.50:1** / **7.25:1** | The 3dp leading edge of the `current` tile, the determinate progress line, the focus ring, selected-tile 10% fill |
| `--color-success` | `#40713A` | `#7FBE72` | **4.68:1** / **6.89:1** | `downloaded` chip on Slot 2 |
| `--color-warning` | `#8A5A12` | `#E0AC47` | **4.80:1** / **7.36:1** | Slot 2 and `persistentStatus` when a queue stops part-way (connection lost, storage exhausted) |
| `--color-error` | `#8A3228` | `#EE8B76` | **6.64:1** / **6.22:1** | `failed` tile icon and words, the site-could-not-be-read `ErrorState`, the storage dialog |
| `--color-info` | `#426986` | `#7FB3DA` | **4.74:1** / **6.78:1** | **Never checked** chip, the source line |
| `--color-border` | `#D9D3C9` | `#2E3237` | exempt | Rules between chapter tiles, the pinned action row's separator |
| `--color-border-field` | `#8F8778` | `#6B6560` | **3.18:1** / **3.24:1** | `secondary` button outlines, unselected download-sheet radio rows |
| `--color-border-focus` | `#8A4B12` | `#E3A857` | **6.07:1** / **8.86:1** | 2dp focus ring on every focusable element |
| `--color-border-strong` | `#6B645E` | `#8A8885` | **5.21:1** / **5.26:1** | 2dp leading edge of a chapter tile selected for a hand-picked download — **borrowed from `NovelRow`'s declared `selected` grammar; see § 11.3** |

Non-colour tokens cited: `--text-h2` `#25 / 32`; `--text-h3` `#20 / 26`; `--text-h4` `#18 / 24`; `--text-body` `#16 / 24`; `--text-body-sm` `#14 / 20`; `--text-caption` `#12 / 16`; `--text-overline` `#11 / 16` (600, 0.08em); `--space-xs` `4dp`; `--space-sm` `8dp`; `--space-md` `12dp`; `--space-lg` `16dp`; `--space-xl` `24dp`; `--space-3xl` `48dp`; `--radius-sm` `4dp`; `--radius-md` `8dp`; `--radius-lg` `16dp`; `--radius-full` `999dp`; `--border-width` `1dp`; `--border-width-strong` `2dp`; `--shadow-dialog` `0 16 48 rgba(0,0,0,0.24)`; `--duration-fast` `120ms`; `--duration-normal` `200ms`; `--ease-standard` `cubic-bezier(0.2, 0, 0, 1)`.