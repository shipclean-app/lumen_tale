---
type: screen
slug: reader-chapter-sheet
title: Reader chapter sheet
module: reader
status: approved
generated_at: 2026-10-02
derived_from:
  - .forge/prd.md
  - .forge/design/design-system.md
rule_ids:
  - B9
  - B10
  - B13
  - B14
  - B16
  - B17
  - B48
  - B49
edge_case_ids:
  - E5
  - E10
  - E20
flow: read-loop
---

# Screen — Reader chapter sheet

> **A deliberate addition. Mihon has no in-reader chapter list.** This file is the one place where we diverge from the reference on screen inventory, so the divergence is argued here rather than assumed.

---

## 1. Role of the screen

| | |
|---|---|
| **App archetype** | `mobile_consumer` |
| **Module** | reader — outside the tab structure |
| **Route** | presented as a sheet over `/reader/:novelId/:chapterId`; its state is not a route |
| **Type** | **sheet** |
| **Users** | the reader, mid-chapter |
| **User stories served** | US-04, US-11, US-12 |
| **Business rules** | B9 B10 B13 B14 B16 B17 B48 B49 |
| **Edge cases** | E5 E10 E20 |

**In one sentence**: this sheet lets the reader see the whole chapter list, see where they are, and jump — without leaving the chapter they are reading.

**Why it exists, given Mihon does not have it.** Verified as an absence, not an oversight: across all 616 lines of `ui/reader/ReaderActivity.kt`, all 17 files in `presentation/reader/**`, `ReaderAppBars.kt` and `ChapterNavigator.kt`, the only in-reader chapter navigation is `ChapterNavigator`'s previous/next buttons and page slider (`ui/reader/presentation/reader/components/ChapterNavigator.kt:66`), plus the `N`/`P` hardware keys (`ReaderActivity.kt:399-408`). To change chapter you must tap the title bar, land on `MangaScreen`, and pick from the list.

That works for a manga with 200 chapters read mostly in order, a few at a time. **It does not work for a web novel with 900 chapters**, which is the normal shape of the content this app exists for — and PRD **B9** requires the chapter list be shown complete whatever its length. Leaving the reader to go back to the novel screen for every jump means the reader's two most frequent actions (read forward, jump back) are separated by a screen transition and a scroll. This sheet removes that. **Mihon's gap is a consequence of its content model, not a better idea.**

---

## 2. Visual direction for this screen

| | |
|---|---|
| **Mood** | quiet, warm, unhurried |
| **Density** | **normal** — a chapter title plus a state marker, 64dp rows |
| **Contrast level** | **high** — `--color-text-primary` on `--color-surface-raised`, 14.48:1 / 12.00:1 |
| **Surface** | `--color-surface-raised` on `--color-background`, over the reader's `--color-surface-sunken`. One of only two surfaces in the app carrying `--shadow-sheet`, because a sheet genuinely floats over content |
| **Accent used** | `--color-accent` — **only** as the 3dp leading edge on the current chapter, matching the same marker on `ChapterListTile` and the `MoreRow` active marker, so "where am I" is one shape everywhere |
| **Photographic treatment** | **none** |
| **Reference** | Mihon's `MangaScreen` chapter list (`ui/manga/MangaScreen.kt:64`), re-specified for `ChapterListTile` (`design-system.md` § 2.2) and raised into a sheet |

### 2.1 Anti-generic — mandatory

- [x] **No pure `#FFFFFF`** — `--color-surface-raised` `#FEFCF9` / `#232629`.
- [x] **One shadow, used once.** `--shadow-sheet` `0 8 24 rgba(0,0,0,0.18)`, because a sheet over prose is the second genuinely floating thing in the app (the first is `ReaderControls`). No row inside it has a shadow.
- [x] **Not uniform** — chapter number `--text-caption`, title `--text-h4`, and the drag handle is a distinct 4dp `--color-border-strong` bar rather than another type size.
- [x] **No generic grey** — paper-anchored neutral ramp.
- [x] **Not symmetrically centred** — numbers left in a fixed 48dp column, titles left-aligned after it.
- [x] **No illustration, no search field inside the sheet** — see below.
- [x] **Not one family at one weight** — sans throughout, three scales.

**Assumed, non-neutral choice**: **no search field in this sheet, and the list is never virtualised into an unscrollable wall.**

Two decisions worth arguing:

1. **No search box.** The obvious feature is a filter field for a 900-row list. It is refused, because this sheet appears *over the prose the reader is reading*, and a search field that dismisses the text to filter a list is a worse trade than scrolling. **If the reader wants to find a chapter by name, `novel-details` has B45's title search and the full list.** Mihon does the same: its in-reader path is prev/next, not a filtered list.
2. **The list is a lazy list, but the *current* chapter is scrolled into view on open.** With 900 rows, lazy rendering is mandatory. But a sheet that opens at row 0 when the reader is on chapter 412 is useless, so opening always scrolls the current chapter to the vertical centre. The list itself stays a plain scroll — **no section headers, no "jump to current" floating button**, because the current chapter is always findable by the same gesture that opened the sheet.

---

## 3. Anatomy

```
Sheet  --color-surface-raised, --shadow-sheet, radius --radius-lg
├── DragHandle              4dp --color-border-strong bar
├── SheetHeader
│   ├── title               novel name, --text-h3
│   ├── subtitle            "412 of 900" · --text-body-sm
│   └── closeButton         48dp
└── LazyColumn
    └── ChapterListTile (list variant, 64dp)
        ├── number          --text-caption, tabular, verbatim from site (B10)
        ├── title           --text-h4
        ├── stateIcon       downloaded / downloading / failed / not downloaded
        ├── progress        2dp determinate line, --color-accent
        └── current         3dp --color-accent leading edge
```

| # | Component | Role | Source |
|---|---|---|---|
| 1 | `ChapterListTile` (variant `list`) | One chapter | design-system § 2.2 |
| 2 | `ReaderControls` | The sheet's opener — `chapterListButton` | design-system § 2.6 |
| 3 | `StatusChip` | Download state where a chip fits | design-system § 2.5 |
| 4 | `--shadow-sheet` | The sheet's only shadow | design-system § 1.4 |

---

## 4. States — all nine, no exceptions

| State | Trigger | Rendering | Reader feedback |
|---|---|---|---|
| **Loading** | Building the list from local chapter data | Rows render progressively as the lazy list lays out; the current chapter scrolls into view as soon as it is known. **No spinner over the whole sheet** | — |
| **Filled** | Chapter list present | Every chapter from the stored list, **complete and in reading order (B9)** | — |
| **Empty — never visited** | n/a | **Not applicable** — a novel can only be in the reader if its chapters were loaded | — |
| **Empty — no data** | Stored list holds zero chapters | `EmptyState` `no-chapters`: *This novel has no chapter list yet.* plus `secondary` **Reload from the source**. It is an **empty** state, not an error — the novel exists, its list does not | The reload action, because the cause is knowable and fixable |
| **Load error** | The chapter list could not be read, or the reload failed | `ErrorState`: `--color-error` icon, a sentence naming **what failed and that the current chapter is unaffected (B23)**, `secondary` Retry | Retry, not dismissal |
| **Submit error** | A jump to a chapter that is not stored and cannot be fetched | The row itself shows `failed` with retry; **the sheet stays open**. The reader's place in the list is not lost because one jump failed | The row's own error |
| **Succès** | A jump succeeds | **No success state.** The chapter changes behind the sheet and the sheet dismisses — that *is* the feedback | The sheet closing |
| **Hors-ligne / permissions** | No connection, chapter stored | **Every chapter is browsable offline (B7)**; unstored chapters render their `not downloaded` marker and tapping one offers a download rather than a failure | Per-row state, never a sheet-level banner |
| **Lecture seule** | n/a | **Always read-only.** No reorder, no rename, no delete, no drag (**B10** forbids renaming; **B30** forbids removing chapter data from the app) | — |

> Three have no rendering and each says why. **There is no success state on purpose**: the feedback for a jump is the chapter changing behind the sheet, and a confirmation toast on top of that would be announcing the obvious.

---

## 5. Interactions

| Element | Event | Behaviour | Visual feedback | Resulting state | Rule |
|---|---|---|---|---|---|
| `chapterListButton` (in `ReaderControls`) | tap | Open the sheet; current chapter scrolled to centre | Sheet slides up `--duration-normal`, `--shadow-sheet` | Filled + sheet | — |
| Drag handle | drag | Dismiss the sheet | Follows the finger, `--ease-standard` | Filled | — |
| Drag handle | fling down | Dismiss | `--duration-normal` | Filled | — |
| Sheet scrim | tap | Dismiss | — | Filled | — |
| `ChapterListTile` (stored) | tap | Jump to that chapter; **the sheet dismisses** and the position restores | Sheet slides down | Reader, new chapter | **B16** |
| `ChapterListTile` (not stored, online) | tap | Fetch, then jump | Row shows `downloading` with a determinate line | Reader, new chapter | **B5 B18** |
| `ChapterListTile` (not stored, offline) | tap | Offer a download; **the sheet does not dismiss** | Row's `not downloaded` marker becomes a download action | Filled + sheet | **B7** |
| `ChapterListTile` | long-press | **Nothing.** No context menu, no per-chapter actions | — | Filled | **B30** |
| `ChapterListTile` | swipe | **Nothing.** No swipe-to-download, no swipe-to-delete | — | Filled | **B33** is a *settings/queue* action, not a gesture |
| System back / Esc | gesture | Dismiss the sheet; the reader is unchanged | — | Filled | — |

- **Focus / clavier**: the list is one scroll stop; arrow keys move between tiles; `Enter` jumps. Focus visible at 2dp `--color-border-focus`.
- **Gestures**: drag-to-dismiss and scroll only.
- **Animations**: sheet in/out `--duration-normal` 200ms `--ease-standard`. **No animation on the jump itself** — same reasoning as the chapter change in `reader.md`: the reader chose it, and animating a restore makes them think the position moved.
- **Retour arrière**: dismisses the sheet, does not navigate. **A second back leaves the reader** — position was already saved on every scroll settle.

---

## 6. Responsive

| Breakpoint | Behaviour | What collapses or disappears |
|---|---|---|
| **Mobile** `< 600dp` | Full-height sheet, 64dp rows, 48dp number column | Nothing. Design target |
| **Tablet** `600–1023dp` | Sheet is capped at `--bp-mobile` width and centred; the reader behind it stays single-column (**ADR-010**) | Nothing collapses |
| **Desktop** `1024–1439dp` | Same; desktop out of scope | — |

- **Cible tactile**: 64dp rows, 48dp close button, 48dp on every tappable tile.
- **Débordement**: chapter numbers in a fixed 48dp tabular column so titles align; titles max 2 lines with an ellipsis. **B10 is not violated by a 2-line cap** — the full site title is on the tile's accessibility label and in `novel-details`, where no cap applies.

---

## 7. Accessibility

- [x] **Contrast 14.48:1** (day) / **12.00:1** (night) for chapter titles on `--color-surface-raised` — measured.
- [x] **Contrast 6.22:1** / **6.01:1** for chapter numbers.
- [x] **Current-chapter marker `--color-accent`** at **5.50:1** / **7.25:1** against `--color-surface-raised` — above the 3:1 non-text threshold, **and it is a leading edge, not a colour**: a reader who cannot perceive the amber still sees the bar.
- [x] **Each tile announces**: *Chapter 412, Chapter title as the site presents it, read, downloaded.* State is in words, never colour alone.
- [x] **The sheet has a proper dialog role and focus trap**; on open, focus moves to the current chapter's tile and is announced, so a screen-reader user is not dropped at row 1 of 900.
- [x] **Language and direction** correct (B28); the number column follows the layout direction.

---

## 8. Données

| Champ | Type | Origine | Requis | Erreur possible |
|---|---|---|---|---|
| `novel.name` | `String` | local library | yes | — |
| `chapters` | `List<Chapter>` | local chapter list, **complete and in reading order (B9)** | yes | Empty → Empty — no data state |
| `chapter.number` | `double` | local, via `ChapterRecognition` | no | Unparseable → `-1`, rendered `—`, never `0` |
| `chapter.isRead` | `bool` | local, cleared on open | yes | — |
| `chapter.isDownloaded` | `bool` | local filesystem | yes | Absent while marked downloaded → treated as absent; **B6** says it cannot be, so this is a drift alarm |
| `chapter.downloadState` | `enum(none, queued, downloading, failed)` | local queue | no | — |
| `currentChapterId` | `String` | local, from **B16** | yes | — |
| `lastCheckedAt` | `DateTime?` | local | no | Never → the sheet's subtitle says *never checked* (**B49**) |

- **Chargement**: a **lazy list**, mandatory at 900 rows. The chapter *bodies* are not loaded — only metadata — so opening this sheet costs no file reads beyond the list.
- **Cache / hors-ligne**: **fully available offline.** Every chapter's metadata is local; an unstored chapter offers a download instead of failing (**B7**).
- **Données sensibles**: **no chapter text is loaded or held by this sheet.** It reads metadata only, so opening it can never put prose in memory that a crash report could capture — the same constraint `reader.md` § 8 records for logging.

---

## 9. Traçabilité

| ID | Origine | Manifestation on this screen |
|---|---|---|
| B9 | PRD | The list is **complete and in reading order, however long** — no truncation, no "show more", and a lazy list that never implies an end it has not reached |
| B10 | PRD | Number and title shown **exactly as the site presents them**; unparseable renders `—`, never a renumbered `0`; the full title is on the accessibility label when the visible line truncates |
| B13 | PRD | An unread chapter carries its marker; opening it clears it and the tile updates on return |
| B14 | PRD | The sheet's subtitle carries the local new-chapter count as a **local** fact (**B48**) |
| B16 | PRD | Jumping restores that chapter's own offset — not the previous chapter's, and not the novel's |
| B17 | PRD | No history entries are written by opening this sheet; history records chapters **opened**, and a sheet that was opened is not a chapter that was read (**B46**) |
| B48 | PRD | The count shown is local and is never presented as the result of a check |
| B49 | PRD | The subtitle says when this novel was last checked, or **never checked** |
| E5 | PRD | Chapter metadata unreadable for some rows → those rows show their state as unknown rather than as read |
| E10 | PRD | A jump interrupted → the sheet stays open and the row shows `failed`; the reader's place is never lost |
| E20 | PRD | One chapter not fetchable → **only that row** errors; every other row stays usable (B23) |

---

## 10. Gate checklist

- [x] All nine states described; three have no rendering and each says why, and **the absence of a success state is justified** (the chapter changing *is* the feedback)
- [x] Every interactive element has a behaviour, a feedback and a resulting state — **including the ones deliberately inert**: long-press and swipe do nothing, and say why
- [x] Responsive defined at every breakpoint; the two larger ones stop widening (ADR-010)
- [x] Anti-generic section checked **and justified**; the assumed choice is *no search field, and the current chapter always scrolled into view*, both argued
- [x] No design value left "to be defined"
- [x] Every B/E/C ID appears in § 9
- [x] `forge-guard placeholders` reports nothing here
- [x] Consistent with `design-system.md`: `--shadow-sheet` is one of exactly two shadows and this is one of the two places it is used; `ChapterListTile` § 2.2 used as declared
- [x] **Tokens cited exist**, values below
- [x] **Divergence from Mihon is declared and argued** in § 1, not silently introduced

---

## 11. Tokens this screen cites

| Token | Day | Night | Measured (day / night) | Where it appears here |
|---|---|---|---|---|
| `--color-background` | `#F5F2ED` | `#121315` | — | Behind the sheet |
| `--color-surface-raised` | `#FEFCF9` | `#232629` | — | The sheet |
| `--color-text-primary` | `#1A1714` | `#E8E4DD` | **14.48:1** / **12.00:1** | Chapter titles, novel name |
| `--color-text-secondary` | `#5A524A` | `#A8A29A` | **6.22:1** / **6.01:1** | Chapter numbers, "412 of 900", never-checked |
| `--color-accent` | `#8A4B12` | `#E3A857` | **5.50:1** / **7.25:1** | Current-chapter leading edge, determinate progress |
| `--color-error` | `#8A3228` | `#EE8B76` | **6.64:1** / **6.22:1** | A `failed` row, Load error |
| `--color-warning` | `#8A5A12` | `#E0AC47` | **4.80:1** / **7.36:1** | A `queued` row — *partial or interrupted*, never *never checked* |
| `--color-success` | `#40713A` | `#7FBE72` | **4.68:1** / **6.89:1** | A `downloaded` row |
| `--color-border` | `#D9D3C9` | `#2E3237` | exempt | Rule between rows |
| `--color-border-strong` | `#6B645E` | `#8A8885` | **5.21:1** / **5.26:1** | The drag handle |
| `--color-border-focus` | `#8A4B12` | `#E3A857` | **6.07:1** / **8.86:1** | Focus ring |

Non-colour tokens: `--text-h3` `#20/26` · `--text-h4` `#18/24` · `--text-body-sm` `#14/20` · `--text-caption` `#12/16` · `--space-md` `12dp` · `--space-lg` `16dp` · `--radius-lg` `16dp` · `--shadow-sheet` `0 8 24 rgba(0,0,0,0.18)` · `--duration-normal` `200ms` · `--ease-standard` `cubic-bezier(0.2, 0, 0, 1)`.