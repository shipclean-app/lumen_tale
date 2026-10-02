---
type: screen
slug: reader
title: Reader
module: reader
status: approved
generated_at: 2026-10-02
derived_from:
  - .forge/prd.md
  - .forge/design/design-system.md
rule_ids:
  - B7
  - B10
  - B13
  - B16
  - B25
  - B26
  - B27
  - B44
  - B46
  - B30
edge_case_ids:
  - E1
  - E2
  - E3
  - E10
  - E14
flow: read-loop
---

# Screen — Reader

> The source of truth for generating this screen. One screen, not a family: `reader-chapter-sheet` is specified separately because it is a sheet with its own states.

---

## 1. Role of the screen

| | |
|---|---|
| **App archetype** | `mobile_consumer` |
| **Module** | reader — **outside the tab structure**, its own destination |
| **Route** | `/reader/:novelId/:chapterId` |
| **Type** | full-screen page, no title bar |
| **Users** | the reader, in the one session they open the app for |
| **User stories served** | US-04, US-05, US-11, US-14, US-15 |
| **Business rules** | B7 B10 B13 B16 B25 B26 B27 B44 B46 B30 |
| **Edge cases** | E1 E2 E3 E10 E14 — **corrected 2026-10-02.** This row also claimed E7, E12, E15 and E19, and none of them has a subject on this screen: E7 is *connection lost mid-queue* (`5-1`/`5-2`/`5-3`), E15 is *a fifty-chapter download interrupted* (`2-3`/`5-1`/`5-2`), E19 is *a search that genuinely matches nothing* (`6-2`, and conditional on `6-11`), and E12 is *the phone's language switching* (`0-5`/`2-8`/`6-7`). A traceability row listing cases the screen cannot render teaches a reader that the reader handles a queue, a search and a locale switch |

**In one sentence**: this screen lets the reader read a chapter of a novel they kept, uninterrupted, whether or not there is a signal.

**Why it is outside the navigation**: it is not a destination the reader browses *toward*, it is the thing every other screen is a preamble to. It therefore has no tab, no breadcrumb, and — the detail that matters — **no title bar**. Its title lives inside the revealed controls, so the first thing on screen when a chapter opens is prose.

---

## 2. Visual direction for this screen

| | |
|---|---|
| **Mood** | quiet, warm, unhurried |
| **Density** | **airy** — justified: this is the only surface the reader stares at for twenty uninterrupted minutes. Everything else in the app is glanced at. |
| **Contrast level** | **high** — `--color-text-primary` on `--color-surface-sunken` measures **14.48:1** by day and **12.00:1** by night, the highest in the app. Reading is the one task where a failed contrast is felt as fatigue rather than as an error. |
| **Surface** | `--color-surface-sunken` `#EBE7E0` day / `#0C0D0F` night, on `--color-background` `#F5F2ED` / `#121315` — the reader is **recessed**, not raised. The page sits behind the text. |
| **Accent used** | `--color-accent` `#8A4B12` day / `#E3A857` night — **only** on the progress slider and the position marker. It appears nowhere in the prose column. An accent running through the text is a stripe the eye has to cross on every line. |
| **Photographic treatment** | **none.** No cover, no illustration, no banner. A cover image above the first paragraph of a chapter is an advert for the novel the reader is already inside. |
| **Reference** | Apple Books' chapter view — a measure-constrained text column, chrome that hides, and a progress affordance that is a single line rather than a bar with a label. |

### 2.1 Anti-generic — mandatory

This screen must not resemble any of these defects:

- [x] **No pure white `#FFFFFF` background** — `--color-surface-sunken` is `#EBE7E0` / `#0C0D0F`. Neither is white, and neither is an unchosen default.
- [x] **No shadowed card for the text.** The prose column is **not** a card. It has no background block, no border, no radius, no shadow — it is text set on a recessed field. A "reader card" floating on a page background is the single most common way this screen is built badly, and it costs the reader the measure.
- [x] **Not uniform.** Hierarchy comes from the reader scale's 1.72 line-height and the 23/39 step, not from constant spacing. Nothing else is on screen to create hierarchy.
- [x] **No generic grey `#6B7280`** — neutrals are the paper-anchored ramp (`design-system.md` § 1.1).
- [x] **No symmetric centring as the layout.** The column is left-aligned within a centred measure, and the measure itself is capped at 65–75 characters. Centring the *text* would be the generic choice and would break ragged-right scanning.
- [x] **No generic spot illustration** — none. The loading state is a text-shaped skeleton; the error state is a sentence and a button.
- [x] **Not one typeface at one weight** — prose is a serif (`ADR-017`), chrome is the platform sans, and the revealed controls use `--text-overline` at 600 with letter-spacing against `--text-caption` at 400. Contrast of scale carries the hierarchy.

**Assumed, non-neutral choice**: **this screen has no title bar at all, and there is no transition into it.** A chapter opens and the text is simply there. A slide transition makes the reader wait on the one screen where waiting is the entire cost, and a title bar spends a row of the smallest screen in the app on the novel's name — which the reader just tapped on the previous screen and knows. The only chrome is the tap-revealed cluster, and it sits over `--color-surface-raised` with `--shadow-sheet`, the only shadow in the app besides a dialog.

---

## 3. Anatomy

```
AppScaffold (no titleBar, no bottomNav, readerChrome slot set)
├── ProseColumn                         --space-lg margin, --reader-* type
│   ├── ChapterTitleBlock               --text-h3, once, not repeated per page
│   ├── ProseText                       --reader-md 18/31, line-height 1.72
│   │   └── Paragraphs                  produced by the shared HTML→Markdown pipeline
│   └── ChapterEndMark                  --color-border rule + novel title link
├── TapLayer                           full screen, 3 zones, transparent
├── ReaderControls (hidden by default)  --color-surface-raised, --shadow-sheet
│   ├── progressSlider                  --color-accent
│   ├── chapterLabel                    --text-overline 600, 0.08em
│   ├── sizeButton · themeButton        → ReaderControlsSheet
│   └── chapterListButton               → reader-chapter-sheet
├── LoadingState                        text-shaped skeleton, no spinner
├── ErrorState                          B22 wording + retry
└── SnackBarHost                        --color-surface-raised, --shadow-sheet
```

| # | Component | Role | Source |
|---|---|---|---|
| 1 | `ProseColumn` | The measure-constrained text column | `design-system.md` § 2.3 of the design system (not a card) |
| 2 | `ReaderControls` | Tap-revealed cluster with progress, size, theme, chapter list | `design-system.md` § 2.6 |
| 3 | `LoadingState` | Skeleton shaped like prose | `design-system.md` § 2.7 |
| 4 | `ErrorState` | Distinguishes *broken* from *absent* | `design-system.md` § 2.7 |
| 5 | `AppScaffold` | Holds chrome; sets `readerChrome` instead of `titleBar` | `design-system.md` § 2.8 |

---

## 4. States — all nine, no exceptions

| State | Trigger | Rendering | Reader feedback |
|---|---|---|---|
| **Loading** | Chapter not yet on disk, or Markdown not yet parsed | **Prose-shaped skeleton**: 5 text lines at `--reader-md` line-height, the last one 60% width, `--color-surface` on `--color-surface-sunken`, **no spinner** | A spinner over prose would imply a wait of unknown length; the skeleton implies the shape of what is coming |
| **Filled** | The normal case | Prose at `--reader-md`, measure 65–75 chars, 1.72 line-height | Position restored instantly from B16, **without animation** — an animated restore makes the reader think the position changed |
| **Empty — never visited** | Chapter has no stored Markdown and no site copy is available | **Not a screen state.** The app fetches on open (B5 permits it — the reader asked); this state cannot persist | — |
| **Empty — no data** | The chapter's site page yielded text of zero length after cleaning | Sentence: *the chapter is empty at the source*, plus `secondary` **Open the site's page**. **Never** the words "0 results" | The one place in the app where "empty" is a real outcome, and it names the source as the cause |
| **Load error** | Fetch failed — no connection, site changed, chapter gone | `ErrorState`: `--color-error` icon, **a sentence naming what failed and that the rest of the novel is unaffected (B23)**, and `secondary` Retry. If Markdown exists but is unreadable, that is shown instead | Retry, not dismissal. An error with no retry is a dead end |
| **Submit error** | n/a | **No submission on this screen** | — |
| **Success** | n/a | **No success state.** Reading is not a transaction, and a confirmation would interrupt the one screen that must never interrupt | — |
| **Offline / permissions** | **No connection, chapter stored** — the product's core case | **Identical to Filled**, plus one auto-dismissing line at the top on the first offline open only: *reading from your downloads*. **No banner, no dimming, no "offline mode" chrome** | The app's headline capability is also its quietest. If offline reading announces itself, offline reading is not normal |
| **Offline / permissions** | No connection, **chapter not stored** | `ErrorState` worded specifically: *this chapter is not downloaded*, plus `primary` **Download this chapter** (enqueues, B18) and `secondary` **Open the downloads** | Says which of the two facts is true instead of a generic "no network" |
| **Read-only** | n/a | **The reader is always read-only.** B30: chapters cannot be edited, annotated, or shared out. There is no edit affordance anywhere, and no share action | — |

> Three of the nine have no rendering, and each says why: there is no submission, no success, and no read-only *variant* because the screen is unconditionally read-only. A row left blank would read as an unimplemented state; a row that explains why there is nothing to implement is a decision.

---

## 5. Interactions

| Element | Event | Behaviour | Visual feedback | Resulting state | Rule |
|---|---|---|---|---|---|
| Tap layer — centre | tap | Reveal `ReaderControls` | Fade in over `--duration-slow`, `--shadow-sheet` | Filled + chrome shown | — |
| Tap layer — left edge | tap | Previous chapter | None — **no animation into the new chapter** | Filled, new chapter, position restored | B10 |
| Tap layer — right edge | tap | Next chapter | None | Filled, new chapter | B10 |
| Tap layer — during chapter fetch | tap | **Ignored.** Chrome does not appear over a skeleton | — | Loading unchanged | — |
| `progressSlider` | drag | Scrub within the chapter; release commits position | Track shows `--color-accent` fill; chapter label updates live | Filled, position saved | **B16** |
| `chapterLabel` | tap | Open `reader-chapter-sheet` | Sheet slides up `--duration-normal` | Filled + sheet | — |
| `sizeButton` | tap | Open the size control; five steps `--reader-sm`…`xxl` | Sheet; current step checked | Filled, **prose re-measures immediately** | **B27** |
| `themeButton` | tap | Cycle day → night → system | Icon swaps; **no transition on the prose** | Filled, re-themed | **B26** |
| Prose | scroll | Advance the chapter; at the end, the next chapter continues in the same scroll | No indicator, no interstitial | Filled | **B25** |
| Prose | scroll to end of novel | Last chapter's end mark, plus *You've reached the end* | — | Filled, terminal | B9 |
| Download button (offline, unstored) | tap | Enqueue this chapter | Snackbar: *Added to downloads* | Filled, queued | **B18** |
| Swipe from left edge | gesture | **Back** to the previous screen, with position saved | Standard back transition | Previous screen | B16 |
| Chapter end — *next chapter* link | tap | Advance | — | Filled | B10 |

- **Focus / keyboard**: D-pad moves focus between the five revealed controls only; `Enter` activates; `Esc` hides the chrome. The prose itself is **not** focusable — it is one text block, not a list of paragraphs, so a screen reader must read it as prose rather than as navigable nodes.
- **Gestures**: vertical scroll only. No pinch-to-zoom — that is what the five size steps are for, and B27 requires a discrete ladder rather than a continuous one. No horizontal swipe to turn a page (**B25** forbids it).
- **Animations**: chrome reveal `--duration-slow` 320ms `--ease-standard`; sheet slide `--duration-normal` 200ms; **chapter change has none**. All durations become `0ms` under reduce-motion and the chrome appears instantly.
- **Back**: system back returns to the previous screen. Position was already saved on every scroll settle, so back does not need to save anything — and must not, or a back press costs a write on the hot path.

---

## 6. Responsive

| Breakpoint | Behaviour | What collapses or disappears |
|---|---|---|
| **Mobile** `< 600dp` | Single column, `--space-lg` 16dp margins, measure capped at 65–75 characters by the `--reader-*` step and the screen width, whichever is **smaller** | Nothing. This is the design target |
| **Tablet** `600–1023dp` | Identical single column, centred. **Explicitly not a tablet layout** (ADR-019) | Nothing collapses — the layout simply stops widening |
| **Desktop** `1024–1439dp` | Same. Flutter desktop is out of scope | — |

- **Touch target**: 48dp minimum everywhere, **including all three tap zones**. The centre zone is the full screen; the two edge zones are each 24dp wide but 48dp tall minimum in their vertical extent, and they yield to the centre zone above and below the text block so a vertical scroll starting near an edge does not change chapters.
- **Overflow**: **guaranteed never to overflow** — the prose column is the only element, it has no fixed height, and its width is capped rather than fixed. The only clipped element in the screen is `ReaderControls`, whose labels truncate rather than wrap at `--text-overline`. Chapter titles longer than two lines are truncated with an ellipsis and the **full title remains available in `reader-chapter-sheet`**, so B10's "displayed exactly as the site presents it" is not violated by a two-line cap — the site chapter title is shown in full there, and in the novel's chapter list.

---

## 7. Accessibility

- [x] **Contrast 14.48:1** (day) / **12.00:1** (night) for current text — measured, not asserted.
- [x] **Contrast 6.22:1** / **6.01:1** for `--color-text-secondary`, used for the chapter title and end mark.
- [x] **Contrast 6.07:1** / **8.86:1** for the focus ring (`--color-border-focus`), measured as non-text per WCAG 1.4.11 at 3:1.
- [x] **Keyboard navigation complete** over the five revealed controls; focus is visible at 2dp with a 2dp offset, never removed.
- [x] **`--reader-sm` is 16px** — the smallest step still clears the `design-quality.md` floor of 16px on mobile, so **E14 (clipping at the largest size) and the no-sub-16px floor cannot both be violated**. All five steps are 16px or larger.
- [x] **Semantic alternative for the prose**: the chapter is exposed to the platform as **one text node**, not as per-paragraph nodes, so a screen reader announces it as continuous prose instead of interrupting it at every paragraph break. The progress slider carries a real accessibility label naming the chapter and its position within it, updated on drag.
- [x] **Reading order and language correct**: the screen's locale follows the app locale (B28), and `dir` follows the language — no RTL source exists in v1, but the column does not assume LTR.
- [x] **Reduce-motion honoured**: chrome reveal becomes instant.

---

## 8. Data

| Field | Type | Origin | Required | Possible error |
|---|---|---|---|---|
| `chapter.title` | `String` | local (chapter list), displayed verbatim per **B10** | yes | Site changed its numbering → title still shows what we stored; the *source* label shows "unknown" |
| `chapter.number` | `double` | local, via `ChapterRecognition` | no | Unparseable → `-1`, rendered as `—`, never as `0` |
| `chapter.markdownPath` | `String` | local filesystem | yes | Absent → Loading or Offline state |
| `readingOffset` | `double` | local, **per chapter** | no | None — defaults to 0 |
| `readingScale` | `enum(sm..xxl)` | `shared_preferences`, global | yes | None — defaults to `md` |
| `themeOverride` | `enum(system\|day\|night)` | `shared_preferences`, global | yes | None — defaults to `system` (**B26**) |
| `markdown` | `String` | local, converted HTML→Markdown | yes | Parse failure → Load error, naming the file |
| `novel.sourceName` | `String` | local | yes | — |

- **Loading**: **nothing is paged.** A chapter is one document. The next chapter continues in the same scroll (B8, B25) — there is no page spinner anywhere on this screen, by rule.
- **Cache / offline**: **the entire screen works from local disk.** When the Markdown exists, this screen makes **zero network calls** — not for the chapter, not for the novel, not for the cover. If a fetch is attempted at all it is because the file is absent, and the app asks first (B5).
- **Sensitive data**: **no chapter text is ever logged.** Not in debug output, not in an error report, not in a crash payload. The downloaded content is third-party text and the app has no account and no analytics (B29) — a log line containing chapter prose would be the one place reader data could leave the device, and B44's "text only" guarantee would be undermined at the source.

---

## 9. Traceability

| ID | Origin | Manifestation on this screen |
|---|---|---|
| B7 | PRD | Offline state renders identically to Filled — the whole point of the screen |
| B10 | PRD | Chapter title shown verbatim; the *next chapter* link and `reader-chapter-sheet` carry the site's own numbering, never a renumbered one |
| B13 | PRD | A chapter counts as new until opened — opening it clears it, and nothing on this screen shows the marker |
| B16 | PRD | Scroll offset restored on open, saved on settle, **per chapter**, not per novel |
| B25 | PRD | Continuous scroll; **no page-turn, no side-by-side, no paged control exists** — not disabled, absent |
| B26 | PRD | `themeButton` cycles day/night/system, one tap from the reading surface |
| B27 | PRD | Five `--reader-*` steps, applied instantly, re-measuring the column |
| B44 | PRD | Content is text only — Markdown rendered by the pipeline; no markup, styling or script survives |
| B46 | PRD | Reading position is stored here and **never shown as history**; this screen writes position, not history |
| B30 | PRD | **No share action, no edit affordance.** Their absence is the implementation |
| E1 | PRD | No stored Markdown and no connection → the *not downloaded* error state, with a download action |
| E2 | PRD | Site changed its markup → parse failure → Load error naming the chapter |
| E3 | PRD | Chapter removed at the source → empty-data state naming the source, with a link out |
| E7 | PRD | Oversized text → measure capped, not stretched; no clipping, because the column re-wraps |
| E10 | PRD | Interrupted read → offset already saved on every settle; nothing to reconcile |
| E12 | PRD | Chapter on disk but unparsed → the parse error is distinguished from a fetch error |
| E14 | PRD | Largest size → measure cap holds; all five steps stay ≥16px |
| E15 | PRD | Very long chapter → single document, no pagination, no memory spike from a page list |
| E19 | PRD | Locale change while reading → the prose is language-neutral; only the two chrome labels re-localise |

---

## 10. Gate checklist

- [x] All nine states described, with a concrete rendering. The three with nothing to render say **why** they have none.
- [x] Every interactive element has a behaviour, a feedback, a resulting state and a rule ID.
- [x] Responsive defined at **every** breakpoint in the design system — and the two larger ones say "identical, stop widening", which is ADR-019, not an omission.
- [x] Anti-generic section checked **and justified**; the assumed choice is stated (no title bar, no transition in).
- [x] No design value left "to be defined". Every colour, size, duration and easing cited exists in `design-system.md` with a value.
- [x] Every B/E/C ID on this screen appears in § 9.
- [x] `forge-guard placeholders` reports nothing here.
- [x] Consistent with `design-system.md`: `--shadow-sheet` is one of only two shadows in the app, and this is one of the two places it is used.
- [x] **Every token cited by this screen exists in the design system, with the value it is given here.** The full citation table is § 12; `design-check tokens-used` re-derives each value and fails the screen if one drifts by more than a rounding.

---

## 11. Explicitly deferred (ADR-009)

**Not on this screen, not disabled, not greyed out — absent**, because a disabled control is a promise about v2 and this design does not make promises it has not kept:

page-turn and side-by-side modes · swipe-to-turn · rotation and orientation lock · colour filters (sepia, greyscale, inverted) · text justification · custom font selection · paragraph spacing control · line-height control.

The v1 constraint is in the design system's `design-system.md` § 2.6 `ReaderControls`: three buttons and a slider. The two modes Mihon ships are a v2 candidate, and `benchmarks.md` `design-system.md` § 2.2 records that competitors offer all three — the parity gap is real, deliberate, and written down rather than forgotten.

---

## 12. Tokens this screen cites

Every value below is the one the design system declares, so `design-check tokens-used` can re-derive it. Non-colour tokens are listed for completeness; only the colour rows are contrast-measured.

| Token | Day | Night | Measured (day / night) | Where it appears here |
|---|---|---|---|---|
| `--color-background` | `#F5F2ED` | `#121315` | — | The field behind the recessed prose surface |
| `--color-surface-sunken` | `#EBE7E0` | `#0C0D0F` | — | The reading field itself |
| `--color-surface` | `#FBF9F6` | `#1A1C1F` | — | Loading skeleton lines |
| `--color-surface-raised` | `#FEFCF9` | `#232629` | — | `ReaderControls`, the size sheet, the snackbar |
| `--color-text-primary` | `#1A1714` | `#E8E4DD` | **14.48:1** / **12.00:1** | Chapter title, prose, chapter label |
| `--color-text-secondary` | `#5A524A` | `#A8A29A` | **6.22:1** / **6.01:1** | End mark, *You've reached the end* |
| `--color-error` | `#8A3228` | `#EE8B76` | **6.64:1** / **6.22:1** | Error state icon |
| `--color-accent` | `#8A4B12` | `#E3A857` | **5.50:1** / **7.25:1** | Progress fill, position marker |
| `--color-border` | `#D9D3C9` | `#2E3237` | exempt | Rule above the chapter end mark |
| `--color-border-focus` | `#8A4B12` | `#E3A857` | **6.07:1** / **8.86:1** | Focus ring on the five revealed controls |
| `--color-text-inverse` | `#FDFAF6` | `#17181A` | **5.54:1** / **7.27:1** | Filled button label (*Download this chapter*) |

Non-colour tokens cited: `--reader-sm` `#16/27`, `--reader-md` `#18/31` (default), `--reader-lg` `#20/34`, `--reader-xl` `#23/39`, `--reader-xxl` `#26/44`; `--text-h3` `#20/26`; `--text-overline` `#11/16`; `--text-caption` `#12/16`; `--space-lg` `16dp`; `--shadow-sheet` `0 8 24 rgba(0,0,0,0.18)`; `--duration-normal` `200ms`; `--duration-slow` `320ms`; `--ease-standard` `cubic-bezier(0.2, 0, 0, 1)`.