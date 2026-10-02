---
type: screen
slug: library
title: Library
module: library
status: approved
generated_at: 2026-10-02
derived_from:
  - .forge/prd.md
  - .forge/design/design-system.md
rule_ids:
  - B11
  - B12
  - B13
  - B14
  - B22
  - B24
  - B26
  - B28
  - B32
  - B33
  - B36
  - B39
  - B40
  - B45
  - B48
  - B49
edge_case_ids:
  - E5
  - E6
  - E7
  - E9
  - E12
  - E16
  - E17
  - E20
flow: library-loop
---

# Screen — Library

> The source of truth for generating this screen. Its filter sheet, its sort sheet and its confirm dialogs are **sheets of this screen**, specified in § 11 — they are not separate screen files, and § 11 says why.

---

## 1. Role of the screen

| | |
|---|---|
| **App archetype** | `mobile_consumer` |
| **Module** | library — **rank 1 of 5** in the bottom navigation |
| **Route** | `/library` |
| **Type** | list page, bottom-nav destination (its own `StatefulShellRoute` branch, so its scroll position survives tab switches) |
| **Users** | the reader coming back to resume; the borrowed-device reader, who has the same library and the same need |
| **User stories served** | US-09, US-11, US-03, US-10, US-16 |
| **Business rules** | B11 B12 B13 B14 B22 B24 B26 B28 B32 B33 B36 B39 B40 B45 B48 B49 |
| **Edge cases** | E5 E6 E7 E9 E12 E16 E17 E20 |

**In one sentence**: this screen lets the reader step straight back into the chapter they stopped in, and see everything they keep, without a connection and without asking any site anything.

**Why it is rank 1**: frequency 5 × centrality 5, and the only screen that can **open** the loop rather than summarise it — `ADR-018`. It is not a grid of covers with counts; it leads with one novel at the position where the reader stopped, and the shelf is below it.

---

## 2. Visual direction for this screen

| | |
|---|---|
| **Mood** | quiet, warm, unhurried — at scan speed rather than reading speed |
| **Density** | **dense** — rows are 72dp, justified: this is a surface that is *glanced at* to answer "what do I have and what is unopened", so title and status share two lines and nothing else competes. `design-system.md` § 0 sets the library against the reader on purpose |
| **Contrast level** | **high for the status line** — `--color-text-secondary` `#5A524A` / `#A8A29A` measures **6.22:1** / **6.01:1**, and that line carries the count, which is the most important string on the row. Nothing informational on this screen is ever drawn in `--color-text-disabled` except a genuinely disabled control |
| **Surface** | rows are `--color-surface` `#FBF9F6` / `#1A1C1F` strips, full-bleed with `--space-md` internal padding, on `--color-background` `#F5F2ED` / `#121315`. The continue-reading shelf is the one raised element: `--color-surface-raised` `#FEFCF9` / `#232629`, `--radius-lg` 16dp, **no shadow** |
| **Accent used** | `--color-accent` `#8A4B12` / `#E3A857` — only on three things: the unopened-count pill, the shelf's progress fill, and the focus ring. The accent is never a row background; a screen where every row is tinted is a screen where the badge stops meaning anything |
| **Photographic treatment** | **thumbnail** — the 48dp cover is the only image, `--radius-sm` 4dp, no border, no shadow. A missing cover is never a broken-image glyph: it is a `--color-surface-sunken` block with the title's initials in `--color-text-disabled`, which is `NovelRow`'s `offline` state |
| **Reference** | Kindle's library before Amazon added recommendations to it: one continue-reading card, the shelf below it, no grid |

### 2.1 Anti-generic — mandatory

This screen must not resemble any of these defects:

- [x] **No pure white `#FFFFFF` background** — `--color-background` is `#F5F2ED` by day, warm paper, and `#121315` by night, cool ink. Neither is white and neither is an unchosen default.
- [x] **No shadowed card per row.** Every row and the shelf are `--shadow-none`; the only shadow on this screen is `--shadow-sheet` under the filter sheet and `--shadow-dialog` under a confirm dialog — the two floating things in the whole app. `design-system.md` § 1.4 allows no third.
- [x] **Not uniform.** Three different scales in the first screenful: `--text-overline` 11/16 at 600 with 0.08em tracking for the *Continue reading* label, `--text-h4` 18/24 for a row title, `--text-body-sm` 14/20 for the author and `--text-caption` 12/16 for the timestamp. The shelf's own line-height carries the second break. Hierarchy is a ratio, not a constant gap.
- [x] **No generic grey `#6B7280`** — neutrals are the paper-anchored ramp of `design-system.md` § 1.1.
- [x] **No symmetric centring as the layout.** The shelf is a full-bleed card under `--space-lg` margins; the list below it is full-bleed rows with internal `--space-md` padding. Only the shelf's text block is left-aligned inside its card.
- [x] **No generic spot illustration** — the two empty states are a sentence and one button. `EmptyState`'s `library-empty` instance has real copy and no image, per `design-system.md` § 2.7 and the anti-references in § 0.
- [x] **Not one typeface at one weight** — one family (the platform sans), four scales and three weights, with tracking on the overlines. Nothing on this screen needs a second family: it is not prose, and pretending otherwise would cost APK weight for nothing (ADR-017's reasoning, inverted).

**Assumed, non-neutral choice**: **the top of this screen is a resume, not a summary.** It carries exactly one novel — the last one read — rendered at its stored position: the novel in `NovelRow`'s `compact` variant, the site's own chapter title beneath it verbatim (B10), and a 2dp determinate bar showing how far through that chapter the reader got. Tapping it opens the reader at that position, with no intervening screen. There is no header line reading "42 novels · 96 unopened", no cover grid, and no "Continue reading" carousel of six cards: a carousel is a summary with extra taps, and ADR-018's requirement is that the Library *open the loop*. The whole shelf is below this one card, which is why the card exists at all. The second non-neutral choice, stated here because it is the one a generic list gets wrong: **a row's author is displayed and is not searchable.** B45 forbids searching, filtering or sorting by author because the app does not hold it as a searchable field — so the search field's placeholder reads *Search by title*, the filter sheet carries an explicit line saying so, and the author line under a title is marked as decoration. A field shown next to a search box teaches that the box searches it.

---

## 3. Anatomy

```
AppScaffold (titleBar, bottomNav, persistentStatus)
├── TitleBar
│   ├── Title "Library"                     --text-h1 31/38 700
│   ├── SearchButton → SearchField          TextField 56dp, placeholder "Search by title"  (B45)
│   ├── SortFilterButton                    → SortFilterSheet  (§ 11)
│   └── CheckLibraryButton                  icon + label, tooltip "Check for new chapters" (B36)
├── ContinueReadingShelf                    --color-surface-raised, --radius-lg, --shadow-none
│   ├── Overline "CONTINUE READING"         --text-overline 11/16 600, 0.08em
│   ├── NovelRow variant compact            56dp, 32dp cover, title  (design-system § 2.1)
│   ├── ResumeLine                          chapter title verbatim (B10) + "41% of this chapter"
│   └── ProgressTrack                       2dp, --color-accent fill on --color-surface-sunken track
├── LibraryList                             full-bleed rows, --space-md padding, --color-border rules
│   ├── NovelRow variant library            72dp, 48dp cover, title + author + 2-line status
│   └── StatusChip                          new · downloaded · downloading · failed · never-checked · local (B48, B49)
├── SelectionActionBar                      contextual; Download · Mark as read · Remove (B11, B32, B33)
├── SortFilterSheet                         --color-surface-raised, --shadow-sheet, --radius-lg
├── ConfirmDialog                           --color-surface-raised, --shadow-dialog, --radius-lg
├── EmptyState / ErrorState / LoadingState  design-system § 2.7
└── SnackBarHost                            --color-surface-raised, --shadow-sheet
```

| # | Component | Role | Source |
|---|---|---|---|
| 1 | `NovelRow` variant `library` | One kept novel, 72dp, title + author + status | design-system § 2.1 |
| 2 | `NovelRow` variant `compact` | The one novel on the shelf | design-system § 2.1 |
| 3 | `StatusChip` | The only place B48 and B49 are rendered | design-system § 2.5 |
| 4 | `TextField` | The title-only search (B45) | design-system § 2.4 |
| 5 | `EmptyState` / `ErrorState` / `LoadingState` | Empty, broken-store, first-paint | design-system § 2.7 |
| 6 | `AppScaffold` | Title bar, bottom nav, `persistentStatus` | design-system § 2.8 |
| 7 | `ContinueReadingShelf` | **slice-local**: a raised card wrapping `NovelRow` `compact` + `ResumeLine` + `ProgressTrack`. Declared here, not in the design system, because it is a layout of three existing pieces and not a new primitive |
| 8 | `SelectionActionBar` | **slice-local**: the contextual bar `AppScaffold` shows in place of the title while a selection exists |

---

## 4. States — all nine, no exceptions

| State | Trigger | Rendering | Reader feedback |
|---|---|---|---|
| **Loading** | Cold start, or the process was killed and the local library has not returned yet — **under 100ms in practice, and this state is a skeleton, not a spinner** | `LoadingState` shaped like the content it replaces: one shelf skeleton (32dp cover block + one 18/24 line + an unlabelled 2dp track) and **eight** row skeletons (48dp cover block + two text lines), `--color-surface` on `--color-background`, shimmer `--duration-normal`, disabled entirely under reduce-motion | None beyond the shape. A centred spinner on a screen that is 100ms from ready is a flash of noise |
| **Filled** | The normal case | Shelf above, list below, rows at 72dp. The shelf shows only if a reading position exists **and** its novel is still kept | — |
| **Empty — never visited** | No novel has ever been kept. B12 makes this the honest first-run state: a novel enters only by an explicit action on a novel opened from a site, so the app cannot arrive at a non-empty library by itself | `EmptyState` instance `library-empty`: title `--text-h3` *Your library is empty*, body `--text-body-sm` in `--color-text-secondary` *Novels you keep appear here, and they stay readable without a connection*, and one `primary` button **Browse a source** → `/browse`. **No illustration, no icon in a circle** | The one button on the empty screen is the action that fills it, and it leaves for Browse rather than offering "Add a novel" with no source picker behind it |
| **Empty — no data** | The library has novels, but the active **title query** or **filter facet** matches none | A sentence naming what was searched and narrowed: *No kept novel matches "vow"*, or *No kept novel is downloaded*. One `TextButton` **Clear search** (or **Clear filters**, which also reports how many facets were active). **Never** the words "0 results": the library is local, so the register of a failed site query (B22, E19) would be a lie about where the answer came from | The reader is told *which* thing excluded everything, because "nothing here" with no cause is the state this app is most often wrong about |
| **Load error** | The local library store cannot be read — corrupted file, failed migration | `ErrorState`: `--color-error` icon, a sentence naming **what failed and what still works** (B24): *Your library could not be read. Chapters already downloaded are still on this phone and still readable*, and a `secondary` **Retry**. **A broken *site* is not this state** — that is `NovelRow`'s `error` state, rendered per row, and the two must never look alike | Retry, not dismissal. This is a storage failure, so the sentence promises the thing that survives it |
| **Submit error** | Two submissions exist on this screen: the manual check (B36) and the removal. **Check**: per-novel failures render as a `failed` chip in that row's status line (*could not check*), and one line under the check action reports *12 of 23 novels checked · 11 could not be checked* — the failure count is never folded into a success toast. **Removal**: the local write failed, so the row is **still there** and a dialog says *The novel was not removed* with **Retry**. Nothing is removed optimistically, because there is no backup (C8) | Both name the count that failed and the count that succeeded. A check that half-failed and reported success is B22's failure mode with extra steps |
| **Success** | Check completed, or a removal completed | Check: SnackBar *Checked 23 novels · 4 have chapters you have not opened*, and the checked rows' timestamps change in place. Removal: SnackBar *Removed from your library* with **Undo**. **The undo restores the library entry only** — the confirmation dialog said before the tap that the downloads stay, so nothing needs putting back | The check's success line reports what it found, not that it ran |
| **Offline / permissions** — *library intact* | No usable connection. **The product's core case** | **Identical to Filled.** One auto-dismissing line on the *first* offline open only: *your library is on this phone*. No banner, no dimming, no "offline mode" chrome: if offline state announced itself, offline reading would not be normal (C14, B48) | Nothing. The app must never look like it is waiting for a network it does not need |
| **Offline / permissions** — *cover missing* | The 48dp cover was never stored, and no connection to fetch it | `NovelRow`'s `offline` state: a `--color-surface-sunken` block carrying the title's initials in `--color-text-disabled`. The row's text and its chips are untouched — a missing picture is not a failure state, and E5 is about browsing, which this screen does not do | None |
| **Offline / permissions** — *actions that need a network* | No connection, reader taps **Check** or **Download** | Both buttons stay **visible and enabled** — greying them out teaches that the feature is gone. Tapping opens the sheet, whose action button is `disabled` at 48dp with the sentence *Checking needs a connection* / *Downloading needs a connection* below it. **Never a spinner, never a silent no-op, never a fake queue** | The reader is told which of the two facts is true: the feature exists, the network does not |
| **Read-only** | Two elements, both unconditional, both stated | **No screen-level read-only mode** — this is a mutating surface on purpose: you remove, you mark read, you download, you check. What is read-only: (1) **the stored reading position on the shelf tile** — it is displayed and cannot be moved, renamed or deleted here; you change it by reading, and B46 forbids any retention rule touching it; (2) **the shelf tile inside selection mode**, which is not selectable and not actionable, so a forty-row selection is never anchored on the one row the reader most wants to open | Both are visible in the rendering rather than asserted here: (1) no control sits on the position, (2) the tile is simply not in the selection's addressable set |

> Three of the nine have a partial or explanatory rendering rather than a single one, and each says why: offline splits three ways because "offline" is one fact and three consequences, submit-error splits because this screen has two submissions, and read-only names its two read-only elements instead of claiming the screen is read-only — it is not.

---

## 5. Interactions

| Element | Event | Behaviour | Visual feedback | Resulting state | Rule |
|---|---|---|---|---|---|
| Shelf tile | tap | **Open the reader directly at the stored position** — not the novel's detail screen. This is the one place in the app where a tap skips a screen, and it is the shortcut ADR-018 buys | None beyond the standard push; **no transition into the reader** (design-system § 3.4) | Reader at the stored offset | **B16**, ADR-018 |
| Shelf tile | long-press | **Ignored.** The tile is not selectable, so a multi-select can never be anchored on it | — | Unchanged | — |
| `NovelRow` (list) | tap | Push `/library/novel/:novelId` | `--duration-normal` 200ms slide, `--ease-standard` | Filled on the detail screen | — |
| `NovelRow` (list) | long-press | Enter selection mode with that row selected | Row takes `selected`: `--color-border-strong` 2dp on the leading edge, `--color-accent` 10% fill; title bar cross-fades to `SelectionActionBar` over `--duration-fast` 120ms | Selection active | — |
| Search button | tap | The title bar's title becomes a `TextField`, 56dp, placeholder **Search by title** | Field takes focus, `--color-border-focus` 2dp | Filled + query active | **B45** |
| Search field | type | Filters the library by **title only**. No author, genre or status matching, and no hint that one exists | Rows recompute per keystroke; result count in the field's helper text: *3 novels* | Filled or Empty-no-data | **B45** |
| Search field | submit / `X` | Submit closes the field keeping the filter; `X` clears it | — | Filled or Empty-no-data | **B45** |
| Sort/filter button | tap | Open `SortFilterSheet` (§ 11). Facets apply **live**; there is no Apply button, because a filter that needs confirming is a filter the reader distrusts | Sheet slides up `--duration-normal`, `--shadow-sheet` | Filled + facet | **B45** |
| **Check for new chapters** | tap | Start a manual check (B36). **No confirmation dialog** — the reason is the invariant, not laziness: a check downloads nothing (B38), so it costs data and nothing else. The button carries the label, not a bare refresh glyph, because a bare refresh glyph says "reload my own data" and this visits every site (B39) | Button takes its `loading` state (16dp spinner, label hidden, width locked); `persistentStatus` shows *Checking 7 of 23 novels · nothing is downloaded* | Checking → Filled | **B36**, **B38**, **B39** |
| Persistent status | during a check | Progress is **counted in novels, never capped** | *Checking 23 of 23 novels* | Check complete | **B39** |
| Selection · **Download** | tap | Bulk-download sheet: *Next chapter of each*, *Next 5 of each*, *Next 10*, *Next 25*, *All unopened chapters of each*, or a hand-picked set. Then a confirm that states the **chapter count**, that it uses mobile data, and that it can be paused or cancelled from the status bar. **No size figure is printed** — the app does not have one before it has fetched anything, and a fabricated "≈ 4 MB" is the kind of number a reader later holds against the app | Confirm → sheet closes → rows take `downloading` with determinate progress | Downloading | **B18**, **B19** |
| Selection · **Mark as read** | tap | Marks every currently unopened chapter of the selected novels as opened — **the same local field opening a chapter writes**, so every count in the app falls identically (B13, B14). Confirm states the count of chapters it will mark | Confirm → SnackBar *Marked 38 chapters as read* | Filled, counts zeroed | **B13**, **B14** |
| Selection · **Remove from library** | tap | `ConfirmDialog` whose body is B32 verbatim: *Removed from your library. Its 148 downloaded chapters stay on this phone.* and a `TextButton` **Delete the downloads instead** → `/more/downloads` | Cancel is the default; Remove is a `danger` button | Filled, row gone | **B32**, **B33** |
| Row `trailing` slot | — | Carries the download progress bar while a queue runs, the chevron otherwise. **There is no per-row overflow menu**, because `NovelRow` declares no slot for one and inventing a slot is how one component acquires two renderings | — | — | — |
| Row | swipe | **Absent.** No swipe-to-remove, no swipe-to-download. On a device with no backup and no export (C8, ADR-010), the most destructive gesture in the app must not be the easiest | — | — | **B32** |
| List | pull-to-refresh | **Absent.** A downward flick that quietly visits every site is a gesture whose cost the reader cannot see, and B36's point is that *opening the app* is not a trigger. The explicit, labelled button is the only trigger on this screen | — | — | **B36**, **B35** |
| List | scroll | The shelf scrolls away with the list. It **leads**; it does not pin. A pinned shelf spends the top third of the smallest screen on one row | — | Filled | ADR-018 |
| Selection action bar | Back / `Esc` | Exits selection mode first, restoring the title bar; a second back leaves the screen | `--duration-fast` | Filled | — |
| Tab switch | tap another destination | This branch keeps its scroll offset and its query (go_router shell routes, design-system § 3.5) | — | Filled | — |

- **Focus / keyboard**: D-pad moves between the four title-bar actions, the shelf tile, then row to row; the focus ring is 2dp `--color-border-focus` with a 2dp offset and is never removed. `Enter` opens. The menu key enters selection mode with the focused row selected. Every row's chevron hit area is padded to the 48dp minimum so the row is not the only target.
- **Gestures**: tap, long-press, scroll. No swipe, no pull-to-refresh, no pinch — each is argued in the table above rather than omitted.
- **Animations**: sheet slide and screen push `--duration-normal` 200ms `--ease-standard`; press feedback and chip select `--duration-fast` 120ms; **push into the reader has no animation**, per design-system § 3.4. Every duration becomes `0ms` under reduce-motion and the skeleton stops shimmering.
- **Back**: exits selection mode, then clears an active query, then leaves. Nothing is saved on back — the query lives in the shell branch and survives, so a back press costs no write on the hot path.

---

## 6. Responsive

| Breakpoint | Behaviour | What collapses or disappears |
|---|---|---|
| **Mobile** `< 600dp` | The design target. Single column, `--space-lg` 16dp horizontal margins, rows full-bleed with `--space-md` internal padding, `--space-3xl` 48dp top margin | Nothing — this is what ships |
| **Tablet** `600–1023dp` | **Identical single column, centred, capped.** The column stops at the `--reader-md` measure width and centres. **This is deliberately not a tablet layout** (ADR-010, C3): there is no two-pane library, no master/detail split, no wider cover grid. Past 600dp the layout stops widening, full stop | Nothing collapses — the layout simply stops growing |
| **Desktop** `1024–1439dp` | Same single column, centred. Flutter desktop is out of scope (C3) | — |

The same policy applies at `--bp-wide` `≥ 1440dp`, which `design-system.md` § 1.7 declares as the same capped column; the app does not ship there, and the rule is written so that if it ever did, it would still be one centred column.

- **Touch target**: 48dp minimum everywhere. Rows are 72dp; the chevron's hit area is padded to 48dp even though the glyph is 24dp; the search field is 56dp; selection-action buttons are 44dp tall inside a 48dp bar.
- **Overflow**: **guaranteed never to overflow** — every text slot truncates rather than wraps: the title at `--text-h4` to two lines with an ellipsis, the author to one line, the status line to one line per fact with the second line carrying the timestamp. A 40-character French chapter title on a 360dp phone truncates; the full string is always available on the novel's chapter list, which is where B10's verbatim requirement is honoured in full.

---

## 7. Accessibility

- [x] **Contrast 14.48:1** (day) / **12.00:1** (night) for row titles — `--color-text-primary` `#1A1714` / `#E8E4DD`, measured.
- [x] **Contrast 6.22:1** / **6.01:1** for the status line — `--color-text-secondary` `#5A524A` / `#A8A29A`. This line carries the unopened count, so it is measured as body text and never set in the disabled token.
- [x] **Contrast 6.07:1** / **8.86:1** for the focus ring (`--color-border-focus`), non-text per WCAG 1.4.11 at 3:1.
- [x] **No state by colour alone**: the unopened pill carries a **number** as well as a fill; `failed` carries an icon *and* the words *could not check*; `never-checked` is wording only, in the information token, precisely because "we have not looked" is a fact and not an alarm.
- [x] **Keyboard navigation complete** over the title-bar actions, the shelf tile and every row; focus visible at 2dp, never removed; selection mode is reachable with the menu key and leaves with `Esc`.
- [x] **Semantics per row**, one node per row: *"The Ascension of the Ninth Son, by Ilan W., 12 not opened, checked 3 days ago, downloaded, 148 of 480 chapters"* — the count and the timestamp are inside the label, because a screen-reader user cannot infer a pill from a list.
- [x] **Semantics on the shelf tile**: *"Continue reading, The Ascension of the Ninth Son, Chapter 214, 41% through this chapter"* — "continue reading" is in the label, since the visual hierarchy alone says it.
- [x] **Live region** on the check's progress line, so *Checking 7 of 23 novels* and its completion are announced rather than being visual-only.
- [x] **Covers are decorative**: `excludeSemantics`, no alt text, because the title beside them is the information. The initials block announces nothing, being a placeholder for an image that carries no data.
- [x] **Language and reading direction** correct: every string follows the app locale (B28), an unrecognised locale falls back to French, and no row assumes LTR — the status line is a `Wrap` of facts, not a single concatenated string, so an RTL locale reorders it without truncation.
- [x] **Reduce-motion honoured**: no shimmer, no slide, press feedback becomes a state change with no tween.

---

## 8. Data

| Field | Type | Origin | Required | Possible error |
|---|---|---|---|---|
| `novel.id` | `String` | local store | yes | None on screen — it is what the route carries |
| `novel.title` | `String` | local store, verbatim from the site | yes | Never empty; a novel with no title at the source is never added |
| `novel.author` | `String?` | local store | no | Absent when the site publishes none → the `subtitle` slot renders empty and the row keeps its 72dp |
| `novel.sourceName` | `String` | local store | yes | Always shown at the end of the status line — two novels with the same title must be tellable apart (B40, E17) |
| `novel.coverPath` | `String?` | local filesystem, cached | no | Absent → `offline` row state with initials |
| `novel.unopenedCount` | `int` | local, derived over stored chapter-list metadata | yes | Never stale, never an estimate (B14, B48) |
| `novel.lastCheckedAt` | `DateTime?` | local | no | `null` renders **Never checked** — never "just now", never omitted (B49) |
| `novel.lastCheckError` | `String?` | local | no | Present → `failed` chip worded *could not check* (B22) |
| `novel.downloadedCount` / `chapterCount` | `int`, `int` | local, derived | yes | Download interrupted → the pair reads *12 of 480 downloaded*, never a partial number presented as complete (B6, E6, E7) |
| `novel.downloadProgress` | `double?` | live queue state | no | `null` → no bar in `trailing` |
| `readingPosition` | `(chapterId, offset)` per chapter | local, **never trimmed** | no | Absent → the shelf is not rendered at all, not rendered empty |
| `query` | `String` | in-memory, per shell branch | no | — |
| `sortKey`, `facets` | enums | `shared_preferences`, persisted | yes | Write failure → the sheet keeps the previous values and shows a field-level error; the list never changes to something unremembered |

- **Loading**: **the library loads in one block.** No paging, no infinite scroll — a personal library is bounded by what one reader keeps, and every count is a single aggregate query rather than a per-row read. The list is virtualised; a four-hundred-novel library scrolls without building four hundred widgets.
- **Cache / offline**: **zero required network calls** (C14). Covers are fetched once and cached, and a cover that is missing degrades to initials — it is never a blocking load. The manual check is the only thing here that touches a site, and it is the reader's explicit tap.
- **Sensitive data**: nothing is transmitted, and there is no analytics (B29). Error logs carry the novel id and the source name; **never a chapter title, never chapter text**, because a log line is the one place third-party prose could leave the device. No share or export action exists anywhere on this screen (B30).

---

## 9. Traceability

| ID | Origin | Manifestation on this screen |
|---|---|---|
| B11 | PRD | No follow control and no second list. Removal here is removal from *the* library, and the selection bar's actions are the whole per-item action set |
| B12 | PRD | An empty library is a real first-run state with a **Browse a source** button, not an auto-populated shelf — nothing enters without the reader opening a novel from a site |
| B13 | PRD | The count *is* the number of chapters not opened; "Mark as read" writes the same field opening a chapter writes, so the two can never disagree |
| B14 | PRD | The pill is an exact integer computed locally, never a rounded or stale figure |
| B22 | PRD | A broken site is a **row** state (`failed` chip + icon + wording), visibly different from a novel with nothing unopened; and the local count stays on that row regardless |
| B24 | PRD | The store-failure state names what failed and what survives, with a retry; the check reports *12 of 23 checked · 11 could not be checked* |
| B26 | PRD | Every surface token is themed; the night library is the same layout on the night field, cool ink `#121315` |
| B28 | PRD | Every string here is ARB, French fallback; the section labels are real copy, not concatenated tokens |
| B32 | PRD | The removal dialog states that the downloads stay and points at the one place they can be deleted |
| B33 | PRD | Deleting one chapter's download is not offered here — it lives in Downloads, per B33's "on its own, leaving the others untouched" |
| B36 | PRD | The labelled **Check for new chapters** action exists whether or not a schedule is on, and pull-to-refresh is absent so that *opening the app* is visibly not a trigger |
| B39 | PRD | The progress line counts novels with no cap, and no control anywhere offers a partial check |
| B40 | PRD | Two identically-titled novels are two rows; each names its site at the end of its status line, and nothing merges or renames |
| B45 | PRD | Search is a single title field with the placeholder *Search by title*; the filter sheet has no author, genre or description facet and says so |
| B48 | PRD | The count renders with no reference to any check; the status line pairs it with the timestamp rather than with "since" |
| B49 | PRD | **Never checked** is a chip of its own, in the information token, wording only — the app never implies nothing is new for a novel it has not looked at |
| C11 | PRD | Every action is reachable one-handed: the check and the filter controls sit in the app bar and the selection bar, never in a corner menu |
| C14 | PRD | The screen renders with the radio off; offline is byte-identical to Filled |
| E5 | PRD | Offline here can only affect a cover, and that is the `offline` row state — a message about no connection would be wrong, because browsing is not on this screen |
| E6 | PRD | An interrupted download leaves the row reading *12 of 480 downloaded*; nothing partial is ever shown as complete (B6) |
| E7 | PRD | A queue stopped by losing the connection reads *stopped*, not *complete*, and its already-downloaded chapters stay counted |
| E9 | PRD | Offline, the row says nothing about its site at all; online, a vanished novel's check failure reads *no longer at Royal Road* and its stored chapters stay reachable |
| E12 | PRD | A language change re-localises the screen in place with no loss of the library, the query or the selection |
| E16 | PRD | The row keeps its local count and its last-checked timestamp and never implies that nothing is new until a check finds it |
| E17 | PRD | Two rows, two source names, no merge, no rename |
| E20 | PRD | A download that stopped for lack of space renders `failed` with wording that names storage, never as a paused queue |

---

## 10. Gate checklist

- [x] All nine states described with a concrete rendering; the three that split or explain say **why** (offline splits into three consequences, submit-error into two submissions, read-only names its two read-only elements).
- [x] Every interactive element has a behaviour, a feedback, a resulting state and a rule ID.
- [x] Responsive defined at **every** breakpoint of the design system, and the two larger ones say "identical, stop widening" — ADR-010, not an omission.
- [x] Anti-generic section checked **and justified**; the assumed choice is stated (a resume at the top, not a summary; an author that is displayed but not searchable).
- [x] No design value left "to be defined". Every colour, size, duration and easing cited exists in `design-system.md` with its value.
- [x] Every B/E/C ID on this screen appears in § 9.
- [x] `forge-guard placeholders` reports nothing here.
- [x] Consistent with `design-system.md`: this screen uses `--shadow-sheet` and `--shadow-dialog` and **nothing else**, which is the whole shadow budget outside the reader.
- [x] Material 3 primitives only (`ListView`, `SliverAppBar`, `SearchBar`/`TextField`, `ModalBottomSheet`, `AlertDialog`, `SnackBar`, `FilterChip`) — ADR-001, no ShadCN symbol anywhere in this file.
- [x] **Every token cited by this screen exists in the design system, with the value it is given here.** The full citation table is § 12; `design-check tokens-used` re-derives each value and fails the screen if one drifts.
- [x] **v1 reading is scroll-only** (ADR-009): this screen contains no page-turn, slide or swipe-to-turn affordance, not even disabled, because it contains no reading at all.

---

## 11. Sub-surfaces of this screen

Three of them are sheets of this screen and are specified here rather than as separate screen files. The decision is deliberate: `design-system.md` § 4.2 lists *filters* and *sort* under the **Sheet** layout of this screen, and a two-facet sheet given its own file would owe nine states for a control that renders from the first frame.

### 11.1 `SortFilterSheet`

```
BottomSheet  --color-surface-raised, --shadow-sheet, --radius-lg 16dp
├── DragHandle          4dp x 32dp, --color-border
├── SheetTitle           "Sort and filter"    --text-h2 25/32 700
├── ScopeLine            "Titles only — the app does not keep authors, genres or descriptions as searchable fields."  --text-body-sm, --color-text-secondary   (B45)
├── SortSection
│   ├── SectionLabel     "SORT"                --text-overline 11/16 600
│   └── RadioRow x5      Last read (default) · Recently added · Title A→Z · Unopened chapters · Site
├── Divider              --color-border
├── FilterSection
│   ├── SectionLabel     "FILTER"
│   └── FilterChip x4    Downloaded · Not downloaded · Has unopened chapters · Site
└── ActionsRow           "Clear all" (TextButton, disabled when nothing is set, wording *No filters applied*)
```

Every control here is a field the app actually stores. Three things it deliberately does **not** offer, each for a stated reason rather than by omission:

| Not offered | Why |
|---|---|
| Author, genre, description facets | **B45** — the app does not hold them as searchable fields, so a facet would imply a capability it does not have |
| **Completed** | B39's note records that the completed state was deleted from the check because no rule, story or glossary entry defined it. A filter over a state the product does not have is a control that lies |
| Sort by reading progress | Position is per chapter and never trimmed (B46); a shelf sorted by it would be a different claim about the same data |

**States**: *Loading* — **none, and the reason is that the facets are local enums**: the sheet renders from the first frame with no data to wait for, so a skeleton here would be theatre. *Filled* — as drawn, all facets apply live. *Empty* — **not a state**: no facet selected means no filtering, which is the default, so the sheet is never empty and `Clear all` is disabled with the wording *No filters applied*. *Load error* — none; nothing is fetched. *Submit error* — a preference write that fails leaves the sheet open with the **previous** values and a field-level error beneath the offending row; the list behind never changes to something the app cannot remember. *Success* — implicit and instant: the list behind the sheet is already correct, which is why there is no Apply button. *Offline* — **identical to Filled**; every facet is a local preference. *Read-only* — none; a filter is a view, and the view is always writable.

### 11.2 `BulkDownloadSheet` and `RemoveFromLibraryDialog`

The bulk choices are B18's own list — next chapter, next 5 / 10 / 25, all unopened, hand-picked — presented as radio rows with the running **chapter count** beside each, then one `ConfirmDialog` whose body states: *Download 38 chapters across 2 novels. This uses mobile data. You can pause or cancel from the status bar at any time.* **No size estimate is printed**, because the app has no byte figure before it fetches anything.

The remove dialog's body is B32 in the reader's own words: *Removed from your library. Its 148 downloaded chapters stay on this phone.* with a secondary text action **Delete the downloads instead**, and **Cancel as the default action** — the destructive button is never the one a double-tap lands on.

---

## 12. Tokens this screen cites

Every value below is the one `design-system.md` declares, so `design-check tokens-used` can re-derive it. Only the colour rows are contrast-measured.

| Token | Day | Night | Measured (day / night) | Where it appears here |
|---|---|---|---|---|
| `--color-background` | `#F5F2ED` | `#121315` | — | The page field behind the full-bleed rows |
| `--color-surface` | `#FBF9F6` | `#1A1C1F` | — | Row strips, skeleton text lines |
| `--color-surface-raised` | `#FEFCF9` | `#232629` | — | The continue-reading shelf, the filter sheet, the snackbar, dialogs |
| `--color-surface-sunken` | `#EBE7E0` | `#0C0D0F` | — | Cover placeholder block, progress track, disabled button fill |
| `--color-text-primary` | `#1A1714` | `#E8E4DD` | **14.48:1** / **12.00:1** | Row titles, shelf novel title, sheet title |
| `--color-text-secondary` | `#5A524A` | `#A8A29A` | **6.22:1** / **6.01:1** | Author line, status line, unopened count text, sheet scope line |
| `--color-text-disabled` | `#6E665C` | `#948E87` | **4.58:1** / **4.69:1** | Disabled *Clear all*, the initials block, disabled action labels |
| `--color-text-inverse` | `#FDFAF6` | `#17181A` | **5.54:1** / **7.27:1** | Label inside the accent unopened pill, label on the primary button |
| `--color-accent` | `#8A4B12` | `#E3A857` | **5.50:1** / **7.25:1** | Unopened pill fill, shelf progress fill, focus ring, selected-row 10% fill |
| `--color-success` | `#40713A` | `#7FBE72` | **4.68:1** / **6.89:1** | `downloaded` chip |
| `--color-warning` | `#8A5A12` | `#E0AC47` | **4.80:1** / **7.36:1** | Partial or stopped download chip |
| `--color-error` | `#8A3228` | `#EE8B76` | **6.64:1** / **6.22:1** | `failed` chip icon and text, store-failure `ErrorState` |
| `--color-info` | `#426986` | `#7FB3DA` | **4.74:1** / **6.78:1** | `never-checked` chip — information, wording only |
| `--color-border` | `#D9D3C9` | `#2E3237` | exempt | Rules between rows, the drag handle |
| `--color-border-field` | `#8F8778` | `#6B6560` | **3.18:1** / **3.24:1** | Unselected filter chips' outline, text field at rest |
| `--color-border-focus` | `#8A4B12` | `#E3A857` | **6.07:1** / **8.86:1** | 2dp focus ring on every focusable element |
| `--color-border-strong` | `#6B645E` | `#8A8885` | **5.21:1** / **5.26:1** | 2dp leading edge of a selected row |

Non-colour tokens cited: `--text-h1` `#31 / 38`; `--text-h2` `#25 / 32`; `--text-h4` `#18 / 24`; `--text-body` `#16 / 24`; `--text-body-sm` `#14 / 20`; `--text-caption` `#12 / 16`; `--text-overline` `#11 / 16` (600, 0.08em); `--space-xs` `4dp`; `--space-sm` `8dp`; `--space-md` `12dp`; `--space-lg` `16dp`; `--space-xl` `24dp`; `--space-3xl` `48dp`; `--radius-sm` `4dp`; `--radius-md` `8dp`; `--radius-lg` `16dp`; `--radius-full` `999dp`; `--border-width` `1dp`; `--border-width-strong` `2dp`; `--shadow-sheet` `0 8 24 rgba(0,0,0,0.18)`; `--shadow-dialog` `0 16 48 rgba(0,0,0,0.24)`; `--duration-fast` `120ms`; `--duration-normal` `200ms`; `--ease-standard` `cubic-bezier(0.2, 0, 0, 1)`.