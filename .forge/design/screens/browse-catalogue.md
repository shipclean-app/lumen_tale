---
type: screen
slug: browse-catalogue
title: Browse — Catalogue and results
module: browse
status: approved
generated_at: 2026-10-02
derived_from:
  - .forge/prd.md
  - .forge/design/design-system.md
rule_ids:
  - B2
  - B5
  - B11
  - B12
  - B22
  - B23
  - B24
  - B28
  - B40
  - B41
  - B50
  - C11
  - C12
edge_case_ids:
  - E4
  - E5
  - E8
  - E9
  - E17
  - E19
flow: discover-loop
---

# Screen — Browse · Catalogue and results

> The source of truth for generating this screen. **This is the screen SC-6 is demonstrated on** — the one place where a broken source and a genuinely empty genre must look nothing alike, and where a reader decides whether to keep a novel.

---

## 1. Role of the screen

| | |
|---|---|
| **App archetype** | `mobile_consumer` |
| **Module** | browse — **rank 4** of 5 in the navigation |
| **Route** | `/browse/:sourceId/genre/:genre` |
| **Type** | page, pushed inside the Browse tab |
| **Users** | the reader, in the discover loop, choosing one novel out of thirty |
| **User stories served** | US-01, US-02 *(conditional — B50)*, US-09, US-16 |
| **Business rules** | B2 B5 B11 B12 B22 B23 B24 B28 B40 B41 B50 C11 C12 |
| **Edge cases** | E4 E5 E8 E9 E17 E19 |

**In one sentence**: this screen lets the reader scan what one site lists under one tag — or under their own words, where the site has a search — and keep the one they want.

**Why it is at rank 4 of the navigation**: third step of the discover loop, inside Browse, and pushed rather than a tab — so it keeps its parent's context in the title bar, which is the **site's name**, with the tag or the query as the sub-line. No breadcrumb (`design-system.md` § 3.3): a phone app with a back stack does not need one.

### 1.1 The two modes of one route

`:genre` carries either a **declared filter value** or one of the two reserved scope tokens (`popular`, `latest`) defined in `browse-genre.md` § 1. **Results mode** adds one query parameter, `q`:

| | **Catalogue mode** | **Results mode** |
|---|---|---|
| Reached by | tapping a genre, *All novels*, or *Newest chapters* | submitting the search field |
| Present only when | always | the source declares `supportsSearch == true` |
| Query field | **not rendered** | **rendered at the top of the content area**, above the list, sticky while the list scrolls |
| What is sent to the site | the source's own filter value, which the **source** interprets | **the reader's words, unchanged, and nothing else** — no genre scope is attached, because attaching one would be the app deciding what the query means (B41) |
| What the title bar shows | site name, sub-line = the tag | site name, sub-line = *Search* |

**Why one route and not two screens**: a query is not a genre, and pretending otherwise would put a fabricated scope in the URL and in the request. One route, two modes, and the mode is visible in the chrome — which is the honest representation of "these results are not genre-scoped".

---

## 2. Visual direction for this screen

| | |
|---|---|
| **Mood** | quiet, warm, unhurried |
| **Density** **dense** | this is the app's only comparison surface. The reader is choosing between titles, so the title must be the thing that survives; everything else — author, the state of the row — is one step back. `NovelRow` variant `result` at **64dp**, which is the compact half of the library's 72dp, is doing the work a grid would otherwise do. |
| **Contrast level** **high** | titles at `--color-text-primary` `#1A1714` measure 14.48:1 by day and 12.00:1 by night. A row's author at `--color-text-secondary` measures 6.22:1 and 6.01:1. Both are above the floor with room, because the failure mode here is not illegibility — it is picking the wrong novel. |
| **Surface** | rows on `--color-surface` `#FBF9F6` / `#1A1C1F` over `--color-background` `#F5F2ED` / `#121315`. **Flat rows, `--color-border` rule between, no card, no shadow** — the design system's deliberate absence, and on a 30-row list thirty shadows is thirty reasons to stop reading. |
| **Accent used** | `--color-accent` `#8A4B12` / `#E3A857` — **only** on two things: the **query field's** focus state, and the *In your library* marker on a row the reader has already kept. It marks **a decision the reader made**, never something merely present. It is not on the row, the chevron, or the tag. |
| **Photographic treatment** | **40dp cover, `--radius-sm` 4dp — the only element on this screen with a radius.** Covers are the reason this screen is a list and not a grid of words, and they are cached (`cached_network_image`) so a second visit costs no request. A missing cover is a `--color-surface-sunken` block with the title's initials; it is never a grey placeholder box. |
| **Reference** | Mihon's source results list — one row per novel, cover left, two lines of text, no decoration — with Mihon's absent statuses and present row actions removed. |

### 2.1 Anti-generic — mandatory

This screen must not resemble any of these defects:

- [x] **No pure white `#FFFFFF` background** — `--color-background` is `#F5F2ED` / `#121315`, and rows sit on the `--color-surface` step.
- [x] **No shadowed card per row.** Thirty shadowed cards is the failure this row exists to prevent: `--shadow-none` on every row, `--color-border` between them, and the only shadow on the screen is the one the snackbar borrows from the sheet family.
- [x] **Not uniform.** Two scales per row — title `--text-h4` `#18/24` at 600, author `--text-body-sm` `#14/20` — and the hierarchy is reinforced by a change of colour, not by an indent that stays the same on every row. The query field's 56dp height against a 64dp row is the only other rhythm on screen.
- [x] **No generic grey `#6B7280`** — the row separator is `#D9D3C9` / `#2E3237` and the author line is `#5A524A` / `#A8A29A`.
- [x] **No symmetric centring as the layout.** Rows are full-bleed with `--space-md` 12dp internal padding, the cover flush to the leading edge, and the chevron flush to the trailing edge. The list is one column and it is left-aligned; centring it would be the generic choice and would break the scanning rhythm.
- [x] **No generic spot illustration** — none, and this is the screen where it would be most tempting. An empty catalogue gets a sentence and one button; a broken site gets an icon, a sentence, a button and a report line. Neither gets a picture, and neither gets an icon in a circle.
- [x] **Not one typeface at one weight** — title 600, author 400, the tag sub-line at `--text-overline` `#11/16` in 600 with `0.08em`, the *In your library* marker at `--text-caption` in the accent. Three treatments carrying a two-word-per-row job.

**Assumed, non-neutral choice**: **the empty catalogue and the broken source are rendered as two different page shapes, not as one component with two wordings.** `ErrorState` and `EmptyState` are both "a sentence and one action", and swapping a word between them is the obvious cheap way to satisfy B22 — which is exactly why it is wrong: to a reader skimming, a centred quiet sentence and a top-anchored red-icon sentence with a filled button read as the same kind of thing, and B22 is a rule about what the reader must be able to *tell apart*. So the two states diverge mechanically as well as verbally: the empty catalogue is **centred, quiet, iconless, buttonless except one `primary`, and has nothing to scroll**; the broken source is **top-anchored under the title bar, left-aligned, carries a `--color-error` icon, offers a `secondary` **Check again**, and states in its own sentence that nothing has been lost.** A reader who has seen both once can tell them apart from across a room, with the colour removed entirely.

The second half of the choice is that **a row is never a hero**: adding a novel is a trailing icon on the row the reader is already looking at, not a button that appears over the list, and never a checkbox, a swipe, or a long-press. B12 says a novel enters the library only through an explicit action **on a novel the reader has actually seen** — and an affordance that fires on a swipe the reader performed while scrolling is the failure mode that rule is written against.

---

## 3. Anatomy

```
AppScaffold (titleBar + content + bottomNav; persistentStatus when a download runs)
├── TitleBar                    site name --text-h1; sub-line --text-overline = tag or "Search"
├── SearchFieldRow              RESULTS MODE ONLY, and only when supportsSearch == true
│   └── TextField               56dp, --color-border-field; the reader's words, unaltered
├── NovelList                   full-bleed rows, --color-border rule between
│   └── NovelRow (variant `result`)   64dp, 40dp cover, title + author, no status
│       ├── Cover               cached, --radius-sm; initials block when absent
│       ├── Title               --text-h4, 2 lines
│       ├── Author              --text-body-sm, --color-text-secondary, 1 line
│       ├── InLibrary           --color-accent marker, present only when B11 applies
│       ├── AddAction           trailing, ≥48dp — the only way in (B12)
│       └── Chevron             --color-text-secondary, 48dp target
├── PageFooter                  --text-caption; loading row of 3 skeletons while fetching
├── EmptyCatalogueState         centre-aligned, quiet, NO icon, NO error colour
├── SearchNoResultsState        results mode only — distinct copy from EmptyCatalogueState
├── ErrorState                  top-anchored, --color-error icon, "Check again", report line
└── SnackBarHost                --color-surface-raised, --shadow-sheet
```

| # | Component | Role | Source |
|---|---|---|---|
| 1 | `NovelRow` variant `result` | One novel in this site's catalogue or in these results | `design-system.md` § 2.1 |
| 2 | `TextField` | The query, in results mode only | `design-system.md` § 2.4 |
| 3 | `EmptyState` | The genuinely-empty catalogue | `design-system.md` § 2.7 |
| 4 | `ErrorState` | The site could not be read — the state that must not look like the one above | `design-system.md` § 2.7 |
| 5 | `LoadingState` | Row-shaped skeleton | `design-system.md` § 2.7 |
| 6 | `AppScaffold` | Title bar, content, bottom nav | `design-system.md` § 2.8 |

---

## 4. States — all nine, no exceptions

| State | Trigger | Rendering | Reader feedback |
|---|---|---|---|
| **Loading** | The catalogue or the result page is being fetched — the reader asked by navigating here, so B5 permits it | **`LoadingState`, row-shaped**: six `NovelRow` `result` skeletons, each a 40dp `--color-surface-sunken` cover block plus two `--color-surface` text lines of 100% and 60% width, `--duration-normal` 200ms shimmer, **no spinner**. **In results mode the field is present and usable while the list loads** — the query is the reader's input and blocking it behind the network would be backwards | The skeleton is the shape of the thing it replaces, so the reader knows how many lines are coming before they arrive |
| **Filled** | The page parsed and carries novel rows | The rows, in the order the site listed them. Title at `--text-h4` two lines, author at `--text-body-sm` one line. **No sort of any kind is applied by the app** — the order is the site's, which for FanMTL means its own sort segment (latest-update by default) rather than one the app guessed. The site name is in the title bar, so two identically titled novels from two sites are two rows in two different screens and neither is ever merged (B40, E17) | — |
| **Empty — never visited** | The reader opens a tag for the first time | **Not a state, and this is a decision.** Nothing on this screen changes based on visit history — there is no per-tag memory to show and no first-run affordance worth a row. `/onboarding` is the app's only first-run surface (`flows.md` § 5). Inventing a "you have not browsed this tag before" variant would be a novelty, and a novelty in a comparison surface is a distraction | — |
| **Empty — no data** | **The tag is genuinely empty.** The page parsed successfully and carries the site's own empty-result signal, or carries zero novel rows | **Judged by page shape — zero novel rows — not by any string.** FanMTL's failure page carries the literal text *"No relevant content found"*, and that string is **not** what this state is: it lives on the site's **search** failure page, so it discriminates for search calls only. An empty **tag** page is empty because there are no novels in it, and this state says exactly that: `EmptyState`, `--text-h3` *No novels in this tag*, `--text-body-sm` body naming the site and the tag — *FanMTL lists nothing under xianxia* — one `primary` **Browse another tag**, and a `--text-caption` line naming when the list was read. **No icon. No `--color-error`. No retry.** A retry would be an admission that something failed, and nothing failed | The caption carries the read time so the reader knows this is a fact about the site as of a moment, not a permanent truth |
| **Load error** | **The site could not be read.** Non-success status, a parse failure, or a successful response whose expected novel elements are simply absent (E8) — and, in results mode, **a source that declared `supportsSearch` and returned nothing usable** | `ErrorState`, **top-anchored, left-aligned**: `--color-error` icon, `--color-text-primary` title *Lumen Tale could not read FanMTL*, body naming **the tag and the site** and saying what still works — *This is not an empty list. Your library and every downloaded chapter are unaffected* (**B23**) — `secondary` **Check again**, and beneath it a `--text-caption` report line for **C12**: *If you report this, say: "FanMTL's xianxia list could not be read."* **Zero novel rows are rendered**, and the page does not scroll | The sentence *"This is not an empty list"* is written for the reader who has been told by a broken source in another app that it was empty. Saying it out loud is the whole point of B22 |
| **Submit error** | Two submissions exist here, and they fail differently | **(a) The search query** — the field **never turns red**. The query was well-formed and accepted; what failed is the site's answer. Marking the input as errored tells the reader they typed something wrong, which is the one thing that is not true, and it is B22's conflation moved from the list into the field. Instead the `ErrorState` replaces the list, the field keeps the query verbatim and editable, and retrying is one tap. **(b) Add to library** — the library write fails: the row's marker **returns to its un-kept state**, a snackbar reads *Could not add this novel. Nothing was changed*, and the row stays exactly where it was. No row ever shows "kept" for a novel the app did not keep | Both failures leave the screen in the state it was in before the tap, plus one sentence. Neither leaves a half-applied change |
| **Success** | Two successes, and only one of them speaks | **(a) Add to library (B12)** — the row's trailing marker fills `--color-accent` and the row reads *In your library*; a snackbar reads *Added to your library* with **Undo**, because B32 makes removal safe and therefore reversible. **(b) The query** — **no toast at all.** Results replace the list in place, the field keeps focus, and the reader is already looking at the answer. A toast that says "12 results" is a statement about something that is on the screen | Only one snackbar per row action, never one per row rendered |
| **Offline / permissions** | No connection | The catalogue is **live data and is not cached** — a cached catalogue row is a promise that tapping it will open something, and a novel that moved, was renamed or was removed at the site (E9) breaks that promise at the worst possible moment. So: `ErrorState` worded *No connection. Nothing is wrong with FanMTL*, `secondary` **Check again**, and a `ghost` **Open your library** — because the library and every stored chapter work with the radio off, and the screen that most often strands a reader is not allowed to strand them completely. **No permission prompt exists here** — no account (B4), no files, no storage permission | Nothing is dimmed, no row is disabled, and the screen does not pretend the list it is not showing is empty |
| **Read-only** | A novel already in the library | **A kept novel's row is read-only with respect to the library.** The `AddAction` is **absent** — replaced by the *In your library* marker, not disabled — and there is **no remove, no "unfollow", no delete** anywhere on this screen. Keeping and following are the same thing (B11), and ending it happens in the Library, where the confirmation says the downloads are kept (**B32**). What remains available on the row is reading: tapping a kept row opens its details, exactly as tapping an unkept row does. **Discovery is read-only; the library is not** | — |

> Two of the nine have no rendering of their own, and each says why: nothing here depends on visit history, and there is no separate success ceremony for a query. A blank cell would read as an unimplemented state; a row that explains why there is nothing to implement is a decision.

---

## 5. Interactions

| Element | Event | Behaviour | Visual feedback | Resulting state | Rule |
|---|---|---|---|---|---|
| `NovelRow` | tap | Open `/library/novel/:novelId` — **the novel in the row, never one with a similar title** | Row `pressed`: `--color-surface-sunken`, `--duration-fast` 120ms | Filled | **B3**, **B40** |
| `AddAction` on a row | tap | Add that one novel to the library, and **only that one**, on a novel the reader has on screen | Marker fills `--color-accent`; snackbar with **Undo** | Filled, row kept | **B12**, **B11** |
| `AddAction` — already kept | tap | **Absent, not disabled** — the row carries the marker instead | — | Filled | **B11** |
| Row | long-press | **Nothing.** No swipe-to-add, no long-press menu, no checkbox. A gesture that fires while the list is scrolling would keep novels the reader never looked at | — | — | **B12** |
| `TextField` | submit | Send **the reader's words, unchanged** — no splitting into title/author/description, no trimming into fields, no genre scope attached. Navigate to results mode | List replaced in place; field keeps focus; **no toast** | Filled | **B41**, **B50** |
| `TextField` | — (conditional) | **Not rendered when `supportsSearch == false`.** `browse-genre` carries the `search-unsupported` statement; this screen carries the consequences of the decision | — | — | **B50** |
| `Check again` | tap | Re-fetch this page once, because the reader asked | Button → 16dp spinner, label hidden, width locked | Loading → Filled or Load error | **B5**, **B24** |
| List | scroll to the page end | Fetch the next page of the same listing. **In catalogue mode the page number the reader sees starts at 1**; the site's own 0-based index never surfaces in the UI | Footer swaps the caption for three row skeletons; no full-screen loader, no spinner | Filled | **B5** |
| List | scroll in results mode | **Paginated identically, but "next page" of a search is re-sending the same words with the site's own offset.** The footer caption says *More results from FanMTL* rather than *Page 2*, because a search result set has no pages the reader reasoned about | Same | Filled | **B41** |
| `Undo` in the snackbar | tap | Remove the novel from the library again. **Its downloaded chapters are untouched** — nothing is deleted by either direction | Marker empties | Filled | **B32**, **C4** |
| Cover | tap | **Nothing.** Tapping the cover is the row tap | — | — | — |
| Title bar | tap | **No action.** No sort control — the sort is the site's, and exposing it would mean interpreting the site's sort segments. No filter sheet — the tag is already the filter | — | — | **B41** |
| System back | gesture | Return to `/browse/:sourceId`, with **the genre grid's scroll position intact** | Standard push transition `--duration-normal` 200ms | Previous screen | — |

- **Focus / keyboard**: D-pad moves row by row and, in results mode, reaches the field first and `Check again` last. `Enter` on a row opens it; `Enter` on the field submits. Focus is a 2dp `--color-border-focus` `#8A4B12` / `#E3A857` ring, and on a row it is drawn as the design system's `focused` state — `--color-border-focus` 2dp — **not** as the `selected` state's accent fill, because focus and selection are different things and a keyboard user must be able to tell them apart.
- **Gestures**: vertical scroll only, plus the system back gesture. **No pull-to-refresh** — B36's point is that arriving is not a trigger, and B5 forbids fetching the reader did not ask for. Refreshing is `Check again`. **No swipe actions on rows.**
- **Animations**: row press and marker fill `--duration-fast` 120ms `--ease-standard`; screen push `--duration-normal` 200ms; skeleton shimmer `--duration-normal` 200ms, **off under reduce-motion**; snackbar `--duration-normal` 200ms. No layout animation when the query is submitted — the list is replaced instantly so the answer arrives without the reader waiting to watch it arrive.
- **Back**: system back returns to the genre index. **This screen saves nothing on the way out** — the scroll position belongs to the previous screen's state, and a back press that writes is a write on the hot path.

---

## 6. Responsive

| Breakpoint | Behaviour | What collapses or disappears |
|---|---|---|
| **Mobile** `< 600dp` | Single column, `--space-lg` 16dp margins, rows full-bleed with `--space-md` 12dp internal padding. Covers 40dp, rows 64dp | Nothing. This is the design target and the only width v1 ships (C3) |
| **Tablet** `600–1023dp` | Identical single column, **centred and capped at the mobile measure**. **Explicitly not a tablet layout** — ADR-010 excluded it and `design-system.md` § 1.7 says `< 600dp` is *the only layout v1 ships* | Nothing collapses |
| **Desktop** `1024–1439dp` | Same. Flutter desktop is out of scope (C3) | — |

> **`design-system.md` § 4.2 records a `Paged grid` for "Browse results on ≥600dp; 3 columns at `--bp-desktop`".** That row and `design-system.md` § 1.7 / ADR-010 cannot both be built. This screen follows `design-system.md` § 1.7 and ADR-010, because a ≥600dp layout cannot be a v1 layout when v1 is a phone (C3) — which makes that row unreachable in v1 rather than wrong. It is recorded here for the design system's owner to strike, and **it is not built**. See also `browse-sources.md` § 6, where the same tension is recorded for the same reason.

- **Touch target**: 48dp minimum on every row, the chevron, the `AddAction`, the field, and the snackbar's **Undo**. The 40dp cover is inside the row's own target and is not separately tappable.
- **Overflow**: guaranteed never to overflow. The row's text column is the only flexible element and wraps to a third line rather than clipping; the title truncates at **two lines** with an ellipsis and the **full title is the row's accessible label and the novel's own title on the details screen**, so truncation never costs the reader the name it is choosing. No row scrolls horizontally. The field's text truncates from the end at the cursor, which is the field's own behaviour and not a layout failure.

---

## 7. Accessibility

- [x] **Contrast 14.48:1** (day) / **12.00:1** (night) for the novel title — measured, not asserted.
- [x] **Contrast 6.22:1** / **6.01:1** for `--color-text-secondary`, used for the author, the tag sub-line and the empty-state body.
- [x] **Contrast 6.64:1** / **6.22:1** for `--color-error` on the Load error's icon and title, and **6.07:1** / **8.86:1** for the `--color-border-focus` ring at 3:1 as a non-text component.
- [x] **Focus visible** at 2dp with a 2dp offset, never removed, and drawn differently from `selected` so the two are distinguishable.
- [x] **Keyboard navigation complete**: the field, then every row, then the footer action. `Enter` activates. The whole list is one focus order, not a grid of tab stops.
- [x] **No state is carried by colour alone.** *In your library* is a **word** as well as an accent colour; a broken site is an **icon plus a sentence**; the empty catalogue has **neither**, which is what makes its absence perceptible. A reader who cannot perceive `--color-error` at all still reads *"Lumen Tale could not read FanMTL"* on the first line of the screen.
- [x] **Semantic alternative for covers**: each cover is decorative relative to its row — the title is beside it in text — so it is announced as the novel's cover, not as a description invented from pixels. A cover that has not loaded announces nothing rather than announcing "image".
- [x] **The two failure-ish states are separable without sight.** The empty catalogue begins with *No novels in this tag*; the broken source begins with *Lumen Tale could not read*. Different words, different positions, different actions — announced in the same order they are read on screen.
- [x] **Language and reading direction correct**: the app's locale follows the phone (B28). The site name, the tag and the novel titles are shown in the **site's** words, because they are the site's content (B41, and the same rule B10 applies to chapters). What the app supplies around them — *No novels in this tag*, *In your library*, every error — is localised. `dir` follows the language; an Arabic or Chinese title lays out right-to-left or as the script demands **inside its own row** without the row itself moving.
- [x] **Reduce-motion honoured**: the shimmer is off, presses are instant, and the results replacement stays instant because it was already instant.

---

## 8. Data

| Field | Type | Origin | Required | Possible error |
|---|---|---|---|---|
| `source.id` | `String` | compiled registry | yes | Unknown → no route match |
| `source.supportsSearch` | `bool` | compiled registry — **a promise, not a guess** | yes | `true` and then nothing usable → **a broken source (B22)**, never "no results" |
| `genre` | `String` | the source's declared filter value, URL-encoded | in catalogue mode | Never parsed by the app. The **source** interprets it (B41) |
| `q` | `String` | **the reader's words, byte-for-byte** | in results mode | Never trimmed, split, normalised or re-cased before the request |
| `novels` | `List<Novel>` | the site's listing page | yes | Zero rows → Empty — no data. Non-success status, parse failure, or **expected rows absent from a 200** → Load error. The two are decided by response status and element presence, never by the absence of a match |
| `novel.id` | `String` | the site | yes | Unparseable → the row is **omitted and the omission is logged locally**, never rendered as a row with an empty title |
| `novel.title` | `String` | the site, verbatim | yes | Empty → the row is omitted rather than shown blank. Two identical titles stay two rows (**B40**, **E17**) |
| `novel.author` | `String` | the site, when it publishes one | no | Absent renders as nothing — **not** as a blank second line and **not** as a dash, which would read as an author named "—" |
| `novel.coverUrl` | `String?` | the site | no | Absent → initials block. Unreachable → `NovelRow` `offline`: initials, `--color-text-disabled` |
| `novel.inLibrary` | `bool` | local | yes | Never stale within a screen; the add writes before the marker moves |
| `page` | `int` | the site, offset in **its own** base — FanMTL's `/list/<tag>/<sort>-<page>.html` is **0-based** | yes | Converted at the request boundary. **The reader only ever sees page 1** |
| `hasMore` | `bool` | the site's own paging signal | yes | Absent signal with a full page → no footer. The app never invents an end to a list it did not reach |

- **Loading**: **paginated**, one page at a time, driven by scrolling to the end. The footer is three row-shaped skeletons — not a spinner, and not a full-screen loader, because the list the reader is reading must stay on screen while the next page arrives. No page number is shown, and no "load more" button.
- **Cache / offline**: **no catalogue caching, and no results caching.** Both are live data whose promise — that tapping the row opens that novel — decays. What *is* cached is the **cover image** (`cached_network_image`, persisted under `covers/`), which is why a second visit to the same tag costs no cover requests. The one offline-honest path out of this screen is **Open your library**, where everything already works.
- **Sensitive data**: **the query is never persisted, never logged, and never leaves the device except as the request the reader asked for.** A title a reader typed is a reading preference, and this app has no analytics, no crash reporting and no telemetry (B29) — so a query in a log line would be the one place a reader's behaviour could leave the phone. Failure reports name the **source and the tag**, never the query.

---

## 9. Traceability

| ID | Origin | Manifestation on this screen |
|---|---|---|
| **B2** | PRD | Every row belongs to the one site named in the title bar. The site is chrome, not an inference the reader has to make from a cover |
| **B5** | PRD | A page is fetched because the reader navigated here or pressed `Check again`. Nothing is fetched in the background, and opening the app is not a trigger (B36) |
| **B11** | PRD | *In your library* is the only library state on this screen, and there is no second concept — keeping and following are the same marker |
| **B12** | PRD | `AddAction` is a discrete tap on a named row. **No swipe, no long-press, no checkbox, and no add-all** — a novel enters the library only through an explicit action on a novel the reader has on screen |
| **B22** | PRD | The screen's whole reason to exist as a specification. Broken and empty diverge in wording, in position, in icon, in action and in the presence of a retry; and a source that declares search and returns nothing is broken, not empty |
| **B23** | PRD | The Load error says in its own sentence that the library and every downloaded chapter are unaffected. One source failing touches nothing else |
| **B24** | PRD | Every failure offers a way forward: `Check again` for the fetch, `Undo` or a reverted row for the library write. Nothing fails to a blank list |
| **B28** | PRD | Every sentence the app supplies is localisable, in French and English. The site's tag, titles and authors are **not** localised, because they are the site's content |
| **B40** | PRD | Two novels with the same or a similar title stay two rows and are never merged. The site in the title bar is what tells them apart |
| **B41** | PRD | The query is sent unchanged: no title/author/description decomposition, no re-casing, no trimming, no genre scope, no app-chosen sort. The footer says *More results from FanMTL* rather than *Page 2*, because a result set has no pages the reader reasoned about |
| **B50** | PRD | The field is rendered **only** when `supportsSearch == true`. Measured 2026-10-02, FanMTL's search is unreachable, so this screen renders no field at all for it and `browse-genre` carries the explanation |
| **C11** | PRD | 48dp targets throughout, rows at 64dp so a whole page is scannable with one thumb, and no gesture that requires a second hand or precision |
| **C12** | PRD | The Load error carries a caption written to be said out loud — *"FanMTL's xianxia list could not be read"* — because a borrowed-device reader has no other way to get the failure back to the owner |
| **E4** | PRD | A site whose layout changed yields the Load error naming the site and the tag. **Never** an empty list, and never a retry that pretends retrying might help |
| **E5** | PRD | No connection yields the Load error worded *No connection. Nothing is wrong with FanMTL*, plus a route to the library that does work offline |
| **E8** | PRD | A 200 response whose expected novel elements are absent is a **suspected break** and renders the Load error — it is not silently "no novels" |
| **E9** | PRD | A novel removed at the site: if it was already kept and stored, its chapter stays readable and its row shows what is local. If the reader taps a row for a novel that has gone, the destination reports it as a source failure, not as a novel with no chapters |
| **E17** | PRD | Two identically titled novels from two sites are two rows on two different screens, each opening its own site. The app never merges them, and the title bar's site name is the mechanism |
| **E19** | PRD | A well-formed search that matches nothing shows an explicit *no results* sentence that is **visibly distinct from a failure** — centred, quiet, iconless, offering a different query, against the top-anchored icon-and-retry of a break |

---

## 10. Gate checklist

- [x] All nine states described, with a concrete rendering. The two with nothing to render say **why** they have none.
- [x] Every interactive element has a behaviour, a feedback, a resulting state and a rule ID.
- [x] Responsive defined at **every** breakpoint in the design system — and the two larger ones say "identical, stop widening", which is ADR-010, not an omission. The `design-system.md` § 4.2 `Paged grid` tension is recorded, not silently resolved.
- [x] Anti-generic section checked **and justified**; the assumed choice is stated (broken and empty are two different page shapes, and adding a novel is a tap on a row rather than a gesture over a list).
- [x] No design value left "to be defined". Every colour, size, duration and easing cited exists in `design-system.md` with a value.
- [x] Every B/E/C ID on this screen appears in § 9.
- [x] `forge-guard placeholders` reports nothing here.
- [x] Consistent with `design-system.md`: `NovelRow` is rendered in its `result` variant only, its `error` state is never reached here (the whole screen fails together, so the failure is the screen's), and the empty-catalogue block is not a recoloured `ErrorState`.
- [x] **Every token cited by this screen exists in the design system, with the value it is given here.** The full citation table is § 12.

---

## 11. Claims this screen refuses to make

**Absent, not disabled**:

| Absent | Why |
|---|---|
| A search field when `supportsSearch == false` | B50, ADR-015. Measured 2026-10-02: FanMTL's search returns 404 with a meta-refresh for every query, including one that should match |
| The string *"No relevant content found"* as an empty-state label | It is FanMTL's **search failure** page text. Using it as an empty-catalogue label would both misattribute a site's string and collapse the exact distinction B22 exists to protect (quirk 7 in `18-external-contracts.md`) |
| Cached catalogue pages | A cached row is a promise that tapping it opens that novel. It decays, and it breaks worst on a novel the site has since moved or removed (E9) |
| Swipe-to-add, long-press menus, checkboxes, add-all | B12 — an explicit action on a novel the reader has actually seen. A gesture that fires mid-scroll keeps novels nobody looked at |
| Remove / unfollow on a row | B11, B32. It happens in the Library, where the confirmation states the downloads are kept |
| App-computed sort, relevance ranking, or "similar novels" | B41. The site's order is the site's. A relevance score would be the app ranking on fields it does not hold |
| A retry on an empty tag | Nothing failed. Offering one would say otherwise |
| Filters beyond the tag itself | The tag **is** the filter, and the app does not interpret filter values |
| Page numbers | The reader sees *More results from FanMTL*. The site's 0-based index never surfaces |
| Any sharing of a novel, a title or a query | B30, B29. The query is never persisted, never logged, and the failure report names the source and the tag, never what was typed |

---

## 12. Tokens this screen cites

Every value below is the one the design system declares, so `design-check tokens-used` can re-derive it. Non-colour tokens are listed for completeness; only the colour rows are contrast-measured.

| Token | Day | Night | Measured (day / night) | Where it appears here |
|---|---|---|---|---|
| `--color-background` | `#F5F2ED` | `#121315` | — | The page field behind the list; the surface the empty block sits on |
| `--color-surface` | `#FBF9F6` | `#1A1C1F` | — | Every `NovelRow`, the skeleton's text lines |
| `--color-surface-sunken` | `#EBE7E0` | `#0C0D0F` | — | Row `pressed`; the cover's initials block and the skeleton cover |
| `--color-text-primary` | `#1A1714` | `#E8E4DD` | **14.48:1** / **12.00:1** | Novel titles, the site name, the Load error's title |
| `--color-text-secondary` | `#5A524A` | `#A8A29A` | **6.22:1** / **6.01:1** | Author line, tag sub-line, chevron, the empty-state body and caption |
| `--color-text-inverse` | `#FDFAF6` | `#17181A` | **5.54:1** / **7.27:1** | The empty state's `primary` label (*Browse another tag*) |
| `--color-accent` | `#8A4B12` | `#E3A857` | **5.50:1** / **7.25:1** | The *In your library* marker; the field's focused border |
| `--color-error` | `#8A3228` | `#EE8B76` | **6.64:1** / **6.22:1** | The Load error's icon and title — **and nowhere on the empty catalogue** |
| `--color-border` | `#D9D3C9` | `#2E3237` | exempt | The rule between rows |
| `--color-border-field` | `#8F8778` | `#6B6560` | **3.18:1** / **3.24:1** | The `TextField` outline in its `default` state |
| `--color-border-focus` | `#8A4B12` | `#E3A857` | **6.07:1** / **8.86:1** | 2dp focus ring on the field, on rows, and on `Check again` |

Non-colour tokens cited: `--text-h1` `#31/38`; `--text-h3` `#20/26`; `--text-h4` `#18/24`; `--text-body-sm` `#14/20`; `--text-caption` `#12/16`; `--text-overline` `#11/16`; `--space-md` `12dp`; `--space-lg` `16dp`; `--space-3xl` `48dp`; `--radius-sm` `4dp`; `--radius-md` `8dp`; `--border-width` `1dp`; `--border-width-strong` `2dp`; `--duration-fast` `120ms`; `--duration-normal` `200ms`; `--ease-standard` `cubic-bezier(0.2, 0, 0, 1)`; `--shadow-sheet` `0 8 24 rgba(0,0,0,0.18)`.