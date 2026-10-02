---
type: screen
slug: browse-genre
title: Browse — Source genres
module: browse
status: approved
generated_at: 2026-10-02
derived_from:
  - .forge/prd.md
  - .forge/design/design-system.md
rule_ids:
  - B1
  - B2
  - B5
  - B22
  - B23
  - B24
  - B28
  - B41
  - B50
  - C11
  - C12
edge_case_ids:
  - E4
  - E5
  - E8
flow: discover-loop
---

# Screen — Browse · Source genres

> The source of truth for generating this screen. One screen, not a family: the novel list it navigates to is `browse-catalogue`, which is specified separately because it carries the B22 discriminator.

---

## 1. Role of the screen

| | |
|---|---|
| **App archetype** | `mobile_consumer` |
| **Module** | browse — **rank 4** of 5 in the navigation |
| **Route** | `/browse/:sourceId` |
| **Type** | page, pushed inside the Browse tab |
| **Users** | the reader, in the discover loop, on a phone with one hand |
| **User stories served** | US-01, US-02 *(conditional — B50)*, US-16 |
| **Business rules** | B1 B2 B5 B22 B23 B24 B28 B41 B50 C11 C12 |
| **Edge cases** | E4 E5 E8 |

**In one sentence**: this screen lets the reader see what one site can be browsed by — the genres and tags that site itself declares, plus whether that site has a search worth offering.

**Why it is at rank 4 of the navigation**: it is the second step of the discover loop and it inherits Browse's rank from `browse-sources`. It is **not** a tab: it is pushed, it has a back button, and it keeps its parent's context in the title bar (`design-system.md` § 3.3) — the title is the **site's name**, so "which site am I in?" never needs a breadcrumb.

**Route parameter `:sourceId`** carries one of two kinds of value, and both are declared here rather than left to the implementation:

| Value | Meaning | What is sent to the site |
|---|---|---|
| A **declared filter value** from the source's `filterList` | A genre or tag the site itself published | The source interprets its own filter value. **The app never interprets it** (B41) |
| The reserved token **`popular`** | The site's full catalogue | No filter. `getPopularNovels` |
| The reserved token **`latest`** | The site's newest chapters | No filter. `getLatestNovels`, and only offered when the source declares `supportsLatest` |

The two reserved tokens are **app-owned and are never sent as filter values**. They exist so `getPopularNovels` and `getLatestNovels` — both mandatory in the `Source` contract — have a reachable surface; a genre-only screen would leave half the contract dead.

---

## 2. Visual direction for this screen

| | |
|---|---|
| **Mood** | quiet, warm, unhurried |
| **Density** **airy** | the genre index is the one browse surface the reader *chooses* rather than scans. It is at most a screen of tiles plus two entry rows, and it is the moment where a reader decides whether this site is worth using — so the tiles get `--space-md` 12dp of air and the labels get room. Nothing else on the screen competes. |
| **Contrast level** **high** | `--color-text-primary` on `--color-background` measures 14.48:1 by day. Genre names are often non-English words the reader is reading for the first time; a faint label is a legibility failure, not a style choice. |
| **Surface** | tiles on `--color-surface` `#FBF9F6` / `#1A1C1F` over `--color-background` `#F5F2ED` / `#121315`. **No card wrapper, no shadow** — `--radius-sm` 4dp with a `--color-border-field` outline, which is what an outlined control looks like, because a genre **is** a control. |
| **Accent used** | `--color-accent` `#8A4B12` / `#E3A857` — **only** on the search entry row's label and on the focus ring. **Not** on the genre tiles: a field of amber tiles says "these are all selected", which is a state this screen has no notion of. |
| **Photographic treatment** | **none.** No covers, no banners, no site logo. A genre index is text; the covers arrive one screen later, on `browse-catalogue`. |
| **Reference** | Mihon's genre picker sheet and a settings grouped list, with the sheet promoted to a page — because on this screen the genres are the content, not a filter over something else. |

### 2.1 Anti-generic — mandatory

This screen must not resemble any of these defects:

- [x] **No pure white `#FFFFFF` background** — `--color-background` is `#F5F2ED` / `#121315`.
- [x] **No shadowed card for every genre.** A grid of raised cards is the single most common way this screen gets built and it turns a list of words into a wall of containers. Tiles are flat with a `--color-border-field` `#8F8778` outline, measured at **3.18:1** day / **3.24:1** night as a component boundary.
- [x] **Not uniform.** The screen has three scales — section labels at `--text-overline` `#11/16` in 600 with `0.08em` letter-spacing, the tile labels at `--text-body` `#16/24`, the capability sentence at `--text-body-sm` `#14/20` — and two gap sizes, `--space-sm` 8dp inside a group and `--space-xl` 24dp between groups, so a group closes by getting wider, not by getting a divider.
- [x] **No generic grey `#6B7280`** — neutrals come from the paper-anchored ramp.
- [x] **No symmetric centring as the layout.** The grid is left-aligned, and the last row is left **whatever shape it happens to be**. An odd number of genres leaves a half-empty final row; an even number fills exactly. Both are drawn as they fall. Centring the last row, or stretching a lone tile to fill the width, would be a layout inventing tidiness that the source's taxonomy does not have — and the count is a property of the site, not a choice this screen gets to make. **Note the arithmetic**: FanMTL declares **8 genres** plus an `all` pseudo-entry, so in a two-column grid it fills exactly, and this state has no ragged row to demonstrate with. The rule is stated for the general case because the second source's count is not yet measured — designing for FanMTL's even number would be designing for the wrong site.
- [x] **No generic spot illustration** — none. The `search-unsupported` block is a sentence and one button; the no-genres block is a sentence and one button.
- [x] **Not one typeface at one weight** — section labels 600 uppercase with letter-spacing against tile labels at 400 `--text-body`, and the capability sentence at `--text-body-sm`. Scale and weight carry the hierarchy.

**Assumed, non-neutral choice**: **this screen renders the site's taxonomy as the site declared it, in the site's own words, and refuses to improve it.** B41 says the app never interprets filter values; the design consequence is stronger than the rule's wording — the app does not translate a tag, does not normalise its case, does not split `contemporary-romance` into "contemporary" and "romance", does not sort them into a popularity order it computed, and does not merge `romance` with `contemporary-romance` even though a reader would find that helpful. The site's declared genres appear as one tile each, in the order the site listed them, and one of them is a hyphenated compound that wraps to two lines. Every one of those would be an improvement a generic designer makes, and every one of them would make the app the authority on a site it does not own. **The screen's own contribution is capability honesty, not taxonomy curation**: one line saying whether this site has a usable search, and — when it does not — `search-unsupported`, naming the site and the reason, instead of a search box that would return nothing.

---

## 3. Anatomy

```
AppScaffold (titleBar + content + bottomNav; persistentStatus when a download runs)
├── TitleBar                    the site's name, --text-h1; back to /browse
├── CapabilityBlock
│   ├── SearchEntry             only when supportsSearch == true  → browse-catalogue results mode
│   └── SearchUnsupported       EmptyState instance `search-unsupported`, only when false
├── EntryGroup                  --text-overline label "ALL NOVELS" · --text-overline label "NEWEST"
│   └── EntryRow                "All novels" → /browse/:sourceId/genre/popular
│   └── EntryRow                "Newest chapters" → .../latest,  only when supportsLatest
├── GenreGroup
│   ├── GroupLabel              --text-overline, the site's own words for the group
│   └── GenreGrid               2 columns, --space-md gap
│       └── GenreTile           --text-body on --color-surface, --radius-sm,
│                               --color-border-field 1dp outline, ≥48dp tall
└── SnackBarHost
```

| # | Component | Role | Source |
|---|---|---|---|
| 1 | `EmptyState` instance `search-unsupported` | States that this site has no usable search and offers genres instead | design-system § 2.7 |
| 2 | `EmptyState` | The variant for a site that declares neither search nor genres | design-system § 2.7 |
| 3 | `ErrorState` | Names what failed and what still works | design-system § 2.7 |
| 4 | `LoadingState` | Tile-shaped skeleton, never a centred spinner | design-system § 2.7 |
| 5 | `GenreTile` | One declared genre or tag, as a control | **slice-local** — deliberately *not* a `StatusChip` |
| 6 | `EntryRow` | The two reserved-scope entries | slice-local, `ListTile` |
| 7 | `AppScaffold` | Title bar, content, bottom nav | design-system § 2.8 |

**`GenreTile` is not a `StatusChip`, and the difference is load-bearing.** `StatusChip` is "the small state label" that carries counts and verdicts — a label *about* something. A `GenreTile` is a navigation target, so it is a control: it takes focus, it has a pressed state, and it navigates. Reusing the chip would put a state label into the tap order, and `component-parity`'s purpose is precisely to stop one component having two renderings.

---

## 4. States — all nine, no exceptions

| State | Trigger | Rendering | Reader feedback |
|---|---|---|---|
| **Loading** | The source's own index page is being fetched — this is a request the reader asked for by tapping a source, so B5 permits it | **`LoadingState`, tile-shaped**: a 2-column grid of `--radius-sm` blocks at `--text-body` line-height on `--color-surface`, the last one at 60% width, `--duration-normal` 200ms shimmer, **no spinner**. The two entry rows render **immediately and stay** — they need no network, and hiding them would delay the two things that are already available | The skeleton implies the shape of what is coming; a centred spinner over a 40-tile page would imply a wait of unknown length |
| **Filled** | The site declared at least one genre | `EntryGroup` then `GenreGroup`, exactly as in § 3. Worked example — FanMTL's `/browsetags/` measured 2026-10-02 exposes **nine** tags: `action`, `wuxia`, `xianxia`, `xuanhuan`, `shounen`, `romance`, `contemporary-romance`, `shoujo`, and one the project's own record does not name. **The eighth named above is rendered as one tile that wraps to two lines; the ninth is rendered as a tile and is not invented here** — `18-external-contracts.md` names eight of nine, and a design file does not fill in the gap with a guess | — |
| **Empty — never visited** | The reader opens this source for the first time | **Not a state, and this is a decision.** Nothing on this screen depends on how many times it has been opened — there is no per-source history, no "welcome back", no first-run affordance to show. `/onboarding` is the app's only first-run surface (`flows.md` § 5), and a welcome panel inside a list of genres would be a second one competing with the reason the reader arrived | — |
| **Empty — no data** | **The source declares no genres at all** — `filterList` is empty. A real state, not an error, and not a broken source | `EmptyState`, `--text-h3` title and `--text-body-sm` body naming the site and the fact: *FanMTL publishes no genre list the app can read.* One `primary` **Open FanMTL's catalogue in your browser**. Below it the `EntryGroup` still renders, because *All novels* is a catalogue the source does publish — **an empty genre index is not an empty screen.** And if the site also declares `supportsSearch == false`, the sentence changes and says so outright: *This site publishes neither genres nor a usable search. Its catalogue is still readable — open it below.* The correct UI for that is an honest sentence plus the two entries that do work, never a blank page | The wording distinguishes "declares nothing" from "could not read" by construction: no error colour, no icon, no retry |
| **Load error** | The index page could not be read — no connection, a non-success status, a parse failure, or expected elements absent (E8) | `ErrorState`: `--color-error` icon, **a sentence naming the site and saying what still works** — *Lumen Tale could not read FanMTL's genre list. Your library and every downloaded chapter are unaffected* (**B23**) — and `secondary` **Check again**. Beneath it a `--text-caption` line written for **C12**: *If you report this, say: "FanMTL's genre list could not be read."* **There is no cached fallback**: a stale genre index whose every tap fails anyway is two errors instead of one, and a genre index is one request away — unlike a count the app owns and cannot re-derive (which is the case B15 is about, and a different one) | The caption is not a share button or a report form. The app has no telemetry (C2), so a sentence the reader can say out loud **is** the reporting channel |
| **Submit error** | The search field is submitted and the site does not answer | **The field never turns red.** The query was well-formed and accepted; what failed is the site's answer. Marking the input as errored tells the reader they typed something wrong, which is the one thing that is not true — and it is exactly the conflation B22 exists to prevent, moved from the list into the field. The `ErrorState` renders in the destination screen's results area with the query intact and editable | The reader's words survive the failure, so retrying is one tap and nothing needs retyping |
| **Success** | The index page parsed | **No success state.** Fetching a taxonomy is not a transaction, and a "genres found" toast is a statement the reader can already see on screen — and a **count** toast would go stale the moment a site adds or removes a tag | — |
| **Offline / permissions** | No connection | Two branches, both stated. **No cached list**: the `ErrorState` reads *No connection. Nothing is wrong with FanMTL — the app just could not ask it* — and offers **Check again**. That wording is the whole B22 discipline in one sentence: no connection is not a broken site. **The library and every stored chapter stay fully usable** (B23), and the `secondary` action there is **Open your library**. **No permission prompt exists on this screen** — there is nothing to request: no account (B4), no files, no storage permission, and no notification, because this fetch is foreground work the reader triggered | Nothing is dimmed and nothing is disabled. An offline screen that greys out its own content teaches the reader that reading is conditional on a signal, which is the opposite of what this product is |
| **Read-only** | Always, for the taxonomy | **The genre index is read-only, by construction.** The app cannot add, remove, rename, reorder or merge a genre: the taxonomy is the site's, and the only thing this screen can change is which one is being looked at. Selecting a genre is a navigation, not an edit. Concretely — there is no "hide genre", no "pin genre", no "rename tag", no preference that reshapes this list. B41's rule and the absence of an edit affordance are the same fact seen from two sides | — |

> Three of the nine have no rendering of their own, and each says why: nothing here depends on visit history, no submission succeeds into a *state* (the destination screen shows the result, not a toast), and read-only is a property of the entities rather than an event.

---

## 5. Interactions

| Element | Event | Behaviour | Visual feedback | Resulting state | Rule |
|---|---|---|---|---|---|
| `SearchEntry` | tap | Navigate to `/browse/:sourceId/genre/popular?q=…` in **results mode**, where the field and the results live | Label flashes `--color-accent` pressed over `--duration-fast` 120ms | Filled → next screen | **B50** |
| `SearchEntry` — absent | — (conditional) | **Not rendered when `supportsSearch == false`.** Not disabled, not greyed, not behind a "coming soon". A search field that returns nothing is the failure B22 exists to prevent, presented as a feature | — | — | **B50**, **ADR-015** |
| `SearchUnsupported` | tap `primary` | Scroll to and focus the first `GenreTile` | Tile takes the focus ring | Filled | **B50** |
| `EntryRow` — *All novels* | tap | `/browse/:sourceId/genre/popular` | Row `pressed`: `--color-surface-sunken` | Filled → next screen | — |
| `EntryRow` — *Newest chapters* | tap | `/browse/:sourceId/genre/latest` | Same | Filled → next screen | — |
| `EntryRow` — *Newest chapters* absent | — (conditional) | **Not rendered when `supportsLatest == false`** | — | — | — |
| `GenreTile` | tap | `/browse/:sourceId/genre/<declared value>`, URL-encoded | Tile `pressed`: `--color-surface-sunken`, `--radius-sm` retained | Filled → next screen | **B41** |
| `GenreTile` | long-press | **Nothing.** No share, no copy, no "search for this tag". Copying a tag into a search box is the pattern ADR-015 rejected | — | — | **B41**, **B50** |
| Group label | tap | **Nothing.** Labels are labels, not filters | — | — | — |
| `Check again` | tap | Re-fetch the index once, because the reader asked | Button → 16dp spinner, label hidden, width locked | Loading → Filled or Load error | **B5**, **B24** |
| Grid | scroll | Whole grid. Tiles are laid out in one pass; there is no pagination of a genre list and no "show more" | — | — | — |
| Title bar | tap | **No action.** No sort, no filter sheet, no refresh — all three would have nothing to act on | — | — | — |

- **Focus / keyboard**: D-pad moves through the tiles in reading order (left-to-right, top-to-bottom, matching the visual order so the focus ring never jumps backwards); `Enter` opens; `Esc` navigates back. Focus is a 2dp `--color-border-focus` `#8A4B12` / `#E3A857` ring at a 2dp offset. The `SearchUnsupported` primary action moves focus into the grid rather than scrolling past it, so a keyboard user lands on the first tile rather than at the top of a scroll.
- **Gestures**: vertical scroll only. **No pull-to-refresh** — it would fetch without the reader asking (B5), and B36's point is that arriving is not a trigger. Refreshing is `Check again`.
- **Animations**: tile and row press `--duration-fast` 120ms `--ease-standard`; screen push `--duration-normal` 200ms `--ease-standard` (`design-system.md` § 3.4). The skeleton shimmer is `--duration-normal` 200ms and is **disabled entirely under reduce-motion** — a shimmering grid is the most attention-grabbing thing on an otherwise still screen.
- **Back**: system back returns to `/browse` with the scroll position of the source list restored, because each Browse tab keeps its own state (ADR-008's `StatefulShellRoute`). Nothing to save on the way out — this screen holds no position of its own.

---

## 6. Responsive

| Breakpoint | Behaviour | What collapses or disappears |
|---|---|---|
| **Mobile** `< 600dp` | Single column, `--space-lg` 16dp margins. `GenreGrid` is **2 columns** with a `--space-md` 12dp gap and a `--space-sm` 8dp row gap; tiles are at least 48dp tall and grow to fit a label of up to two lines | Nothing. This is the design target and the only width v1 ships (C3) |
| **Tablet** `600–1023dp` | Identical single column, **centred and capped at the mobile measure**. **Explicitly not a tablet layout** — ADR-010 excluded it, and § 1.7 says `< 600dp` is *the only layout v1 ships* | Nothing collapses. The grid stays two columns, because widening it is the tablet layout that was excluded |
| **Desktop** `1024–1439dp` | Same. Flutter desktop is out of scope (C3) | — |

- **Touch target**: 48dp minimum for every tile and every entry row. A tile carrying a one-line label is 48dp tall; a tile carrying `contemporary-romance` over two lines grows to about 60dp rather than truncating, because a genre the reader cannot read is a genre the site does not have.
- **Overflow**: guaranteed never to overflow. The grid's two columns are equal-width and their width is `min(available / 2, cap)`; a label that cannot fit two lines is truncated with an ellipsis and the **full label is the tile's accessible label**, so truncation never costs the reader the tag. No tile ever scrolls horizontally, and nothing is ever clipped mid-glyph.

---

## 7. Accessibility

- [x] **Contrast 14.48:1** (day) / **12.00:1** (night) for the tile label and the title bar — measured, not asserted.
- [x] **Contrast 6.22:1** / **6.01:1** for `--color-text-secondary` on the capability sentence.
- [x] **The tile outline is a non-text component**: `--color-border-field` `#8F8778` / `#6B6560`, measured at **3.18:1** day / **3.24:1** night against the page background, which is WCAG 1.4.11 — the threshold for a component boundary, not the 4.5:1 of text.
- [x] **Focus visible** — 2dp `--color-border-focus` at a 2dp offset, never removed, and it is the same colour as the `SearchEntry` label so the eye already knows what focus looks like on this screen.
- [x] **Keyboard navigation complete** in visual order; `Enter` opens a tile; `Esc` goes back. The tile group is announced as a group with the site's own group label, so a screen-reader user hears the taxonomy before the tiles.
- [x] **No state is carried by colour alone.** `supportsSearch` true and false are distinguished by the **presence or absence of a control plus a sentence**, never by tinting a tile.
- [x] **Semantic alternative for every tile**: each announces its label as the site wrote it, and the announcement is *FanMTL, genre: xianxia* — the site name first, because a screen-reader user arriving by swipe has no visual context for which site they are in.
- [x] **Language and reading direction correct**: the app's locale follows the phone (B28). A genre label is shown **in the site's own words and script, untranslated and uncased** — `wuxia` is not localised, not capitalised and not transliterated, because the site published those characters and the app has no authority over them. What the app supplies is the surrounding sentence, which is localised. The grid does not assume LTR: a label in a right-to-left script lays out right-to-left inside its own tile, and the grid's own column order follows the reading direction.
- [x] **Reduce-motion honoured**: the skeleton shimmer is off, tile presses are instant.

---

## 8. Data

| Field | Type | Origin | Required | Possible error |
|---|---|---|---|---|
| `source.id` | `String` | compiled registry | yes | Unknown id → the router does not match; there is no screen to show |
| `source.name` | `String` | compiled registry | yes | Long name truncates in the title bar; the full name is the title bar's accessible label |
| `source.supportsLatest` | `bool` | compiled registry | yes | `false` → *Newest chapters* is not rendered |
| `source.supportsSearch` | `bool` | compiled registry — **a promise, not a guess** | yes | `false` → `SearchUnsupported`; `true` but returning nothing → **a broken source (B22), not an empty result** |
| `filterList` | `FilterList` | the source, from its own index page | no | Empty → Empty — no data. Fetch failure → Load error. The two are never conflated |
| `filter.name` | `String` | the site, verbatim | yes | Unparseable → rendered as the source's own label, never dropped (B41) |
| `filter.value` | `Object` | the site | yes | Never parsed by the app. Passed to the source, which interprets it |
| `novelCount` | `int` | local | no | Absent renders as nothing, never as `0` — a `0` is a claim about the site |

- **Loading**: **nothing is paged.** A taxonomy is one page. If the site's index itself paginates, that is the source's problem to solve behind `filterList`, and the app does not invent a "show more" (B9's rule against truncation, applied to filters).
- **Cache / offline**: **no cached genre list.** Deliberate, and argued in § 4 — a genre index is re-fetchable in one request, so a stale copy only produces a second failure. The two entry rows are the offline-honest part of this screen: *All novels* is a route, not a cached result, so it is available with no signal and its destination screen will report the absence honestly.
- **Sensitive data**: **no filter value, no URL and no page HTML is persisted from this screen.** Only the enabled/checked verdict timestamps that `browse-sources` owns are stored, and nothing at all is logged. The app has no analytics, no crash reporting and no telemetry (B29).

---

## 9. Traceability

| ID | Origin | Manifestation on this screen |
|---|---|---|
| **B1** | PRD | The screen opens on a site that is in the build. A site whose permission is unconfirmed is never routable, so this screen cannot display one (E21) |
| **B2** | PRD | Every tile leads to novels of **this one site**. The site name is in the title bar, so "which site do these novels come from?" is answered by the chrome and not by inference |
| **B5** | PRD | The index page is fetched **because the reader tapped a source**, and on `Check again` because they asked again. There is no speculative pre-fetch of every site's genres at launch |
| **B22** | PRD | Load error and "declares nothing" are rendered differently and worded differently, and a source that declares search and returns nothing is a **broken source**, never "no results" |
| **B23** | PRD | The Load error states in its own sentence that the library and every downloaded chapter are unaffected. One site failing does not touch the rest of the app |
| **B24** | PRD | The Load error offers `Check again`; no failure on this screen ends in a dead end or a silent failure |
| **B28** | PRD | Every sentence the app supplies — capability, empty, error, report line — exists in French and English. The site's own genre labels are **not** localised, and that is the correct exception: they are the site's content, like a chapter title (B10) |
| **B41** | PRD | Genre labels are rendered verbatim, in the site's order, with its casing and its script. No translation, no splitting of `contemporary-romance`, no app-computed sort, no merge of `romance` into `contemporary-romance` |
| **B50** | PRD | The `SearchEntry` exists **only** when the source declares `supportsSearch`. Measured 2026-10-02, FanMTL's search is unreachable, so `supportsSearch == false` and this screen renders `search-unsupported` instead. Royal Road and Novel Fire are **not yet measured**, so their rows will read the same way until they are |
| **C11** | PRD | One-handed, one-thumb reach: tiles are 48dp, the grid is two columns so the whole taxonomy is one screen, and no interaction needs a second hand or a precise gesture |
| **C12** | PRD | The Load error carries a caption written to be read aloud — *"FanMTL's genre list could not be read"* — because a borrowed-device reader has no other way to get the failure back to the owner |
| **E4** | PRD | A site whose layout changed yields the Load error, naming the site and the fact that nothing is lost — never an empty grid |
| **E5** | PRD | No connection yields the Load error worded *No connection. Nothing is wrong with FanMTL*, and the library stays fully usable |
| **E8** | PRD | A page that loads but holds none of the expected genre elements is treated as a **suspected break** and reported as a failure with a retry, not as "this site has no genres" |

---

## 10. Gate checklist

- [x] All nine states described, with a concrete rendering. The three with nothing to render say **why** they have none.
- [x] Every interactive element has a behaviour, a feedback, a resulting state and a rule ID.
- [x] Responsive defined at **every** breakpoint in the design system — and the two larger ones say "identical, stop widening", which is ADR-010, not an omission.
- [x] Anti-generic section checked **and justified**; the assumed choice is stated (the site's taxonomy is rendered as declared, uninterpreted, and the app's contribution is capability honesty).
- [x] No design value left "to be defined". Every colour, size, duration and easing cited exists in `design-system.md` with a value.
- [x] Every B/E/C ID on this screen appears in § 9.
- [x] `forge-guard placeholders` reports nothing here.
- [x] Consistent with `design-system.md`: `GenreTile` is explicitly **not** a second rendering of `StatusChip`, and the reason is written down rather than left to the reader of the code.
- [x] **Every token cited by this screen exists in the design system, with the value it is given here.** The full citation table is § 12.

---

## 11. Claims this screen refuses to make

**Absent, not disabled** — a disabled control is a promise about a version that does not exist:

| Absent | Why |
|---|---|
| A search box when `supportsSearch == false` | ADR-015, B50. FanMTL's own search 404s with a meta-refresh for every query including one that should match. A field that can only return nothing is the B22 failure wearing a feature's clothes |
| "Search for this tag" on a genre tile | ADR-015's rejected alternative: pushing a site's own tag back into its search bar. Long-press does nothing at all |
| App-computed tag popularity, grouping or synonyms | B41. The taxonomy is the site's, including its awkward compounds |
| A "no genres found, search instead" fallback | It would be a search affordance built on a capability the source did not declare. If a site has neither, the correct answer is the site's own catalogue page in a browser |
| A cached genre list for offline use | Argued in § 4 — it converts one honest error into two. *All novels* is the offline-available path, and its destination reports the absence honestly |
| A genre filter sheet | The genre index **is** the whole screen. A sheet over a list of the same things is a wrapper around itself |
| Translation or transliteration of tags | B41, and the same rule B10 applies to chapter titles |

---

## 12. Tokens this screen cites

Every value below is the one the design system declares, so `design-check tokens-used` can re-derive it. Non-colour tokens are listed for completeness; only the colour rows are contrast-measured.

| Token | Day | Night | Measured (day / night) | Where it appears here |
|---|---|---|---|---|
| `--color-background` | `#F5F2ED` | `#121315` | — | The page field behind the grid |
| `--color-surface` | `#FBF9F6` | `#1A1C1F` | — | Every `GenreTile`, every `EntryRow`, the skeleton blocks |
| `--color-surface-sunken` | `#EBE7E0` | `#0C0D0F` | — | Tile and row `pressed` |
| `--color-text-primary` | `#1A1714` | `#E8E4DD` | **14.48:1** / **12.00:1** | Site name in the title bar, genre tile labels, the `EmptyState` title |
| `--color-text-secondary` | `#5A524A` | `#A8A29A` | **6.22:1** / **6.01:1** | The capability sentence, the `EmptyState` body |
| `--color-text-inverse` | `#FDFAF6` | `#17181A` | **5.54:1** / **7.27:1** | The `primary` button label in `search-unsupported` and in the no-genres `EmptyState` |
| `--color-accent` | `#8A4B12` | `#E3A857` | **5.50:1** / **7.25:1** | The `SearchEntry` label. **Never** on a genre tile |
| `--color-error` | `#8A3228` | `#EE8B76` | **6.64:1** / **6.22:1** | The Load error's `ErrorState` icon and its caption |
| `--color-border-field` | `#8F8778` | `#6B6560` | **3.18:1** / **3.24:1** | The 1dp outline around every `GenreTile` — a component boundary |
| `--color-border-focus` | `#8A4B12` | `#E3A857` | **6.07:1** / **8.86:1** | 2dp focus ring on tiles, entry rows and buttons |

Non-colour tokens cited: `--text-h1` `#31/38`; `--text-h3` `#20/26`; `--text-body` `#16/24`; `--text-body-sm` `#14/20`; `--text-caption` `#12/16`; `--text-overline` `#11/16`; `--space-sm` `8dp`; `--space-md` `12dp`; `--space-lg` `16dp`; `--space-xl` `24dp`; `--space-3xl` `48dp`; `--radius-sm` `4dp`; `--radius-md` `8dp`; `--border-width` `1dp`; `--border-width-strong` `2dp`; `--duration-fast` `120ms`; `--duration-normal` `200ms`; `--ease-standard` `cubic-bezier(0.2, 0, 0, 1)`; `--shadow-dialog` `0 16 48 rgba(0,0,0,0.24)`.