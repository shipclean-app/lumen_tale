---
type: screen
slug: stats
title: Reading statistics
module: more
status: draft
generated_at: 2026-10-02
derived_from:
  - .forge/prd.md
  - .forge/design/design-system.md
rule_ids: [B28, B30, B46, B47]
edge_case_ids: [E5, E12]
flow: settings-flow
---

# Screen — Reading statistics

> Kept from Mihon because it is cheap once history exists, and reframed because Mihon's competitors' framing is exactly what this app refuses.

---

## 1. Role of the screen

| | |
|---|---|
| **App archetype** | `mobile_consumer` |
| **Module** | more — rank 5 (overflow) |
| **Route** | `/stats` |
| **Type** | full-screen page |
| **Users** | the reader, curious about their own habits and nothing more |
| **User stories served** | US-12 |
| **Business rules** | B28 B30 B46 B47 |
| **Edge cases** | E5 E12 |
| **Mihon origin** | `StatsScreen` `ui/stats/StatsScreen.kt:18`, content `presentation/more/stats/StatsScreenContent.kt` |

**In one sentence**: this screen shows the reader what they have actually read, as a record — and refuses to turn it into a score.

**Why it is kept at all**: it costs almost nothing once history exists, and Mihon has it. **Why it is reframed** is § 2.1, and it is the single most contested thing in this file.

---

## 2. Visual direction for this screen

| | |
|---|---|
| **Mood** | quiet, warm, unhurried |
| **Density** | **normal** — figures with labels, not a dashboard |
| **Contrast level** | **high** — `--color-text-primary` on `--color-surface`, 14.48:1 / 12.00:1 |
| **Surface** | `--color-surface` on `--color-background` |
| **Accent used** | `--color-accent` on **one** thing: the bar fill in the per-source distribution. It is the only chart element, and the only one that needs colour at all |
| **Photographic treatment** | **none** |
| **Reference** | Mihon's `StatsScreenContent` (reading-time chart, entries per source, chapter-count distribution, average chapters) — kept as a *list of figures*, with the chart reduced to a bar |

### 2.1 Anti-generic — mandatory

- [x] **No pure `#FFFFFF`** — `--color-background` `#F5F2ED` / `#121315`.
- [x] **No shadowed card per figure.** Mihon tiles its stats (`StatsItem`). Tiles are containers for one number each, which is the definition of a card used as a box. Ours is a **definition list**: label left, value right, `--color-border` between rows.
- [x] **Not uniform** — a figure value is `--text-h2` 25/32 at 700; its label is `--text-body-sm` at 400; section labels are `--text-overline` at 600. A number at 31px beside a label at 14px is the hierarchy doing the work.
- [x] **No generic grey** — paper-anchored neutral ramp.
- [x] **Not symmetrically centred** — labels left, values right, on a shared baseline.
- [x] **No illustration, no trophy, no ring.** There is no achievement graphic anywhere on this screen.
- [x] **Not one family at one weight** — sans, three scales, two weights.

**Assumed, non-neutral choice**: **there is no score, no streak, no goal and no percentage-of-a-target anywhere on this screen — and that is the design.**

This is worth arguing rather than asserting, because it is where a reading app becomes a habit app. `benchmarks.md` § 2.2 records that the commercial competitors make progress, rewards and streaks their primary re-engagement mechanism. This screen's entire alternative claim is: **these are your reading habits, recorded, not a score being played against you.**

Concretely, what is refused and why:

| Refused | Why |
|---|---|
| **Reading streak** | It punishes a reader who took a week off, and it is the single mechanic most likely to make someone stop opening the app. Nothing in the PRD wants it |
| **"You read 3 days in a row!"** | Celebration is still a score. The refusal is not about tone |
| **Goal / target percentage** | Requires the reader to set a target they will miss. **B47's retention model is one year; a goal is one evening** |
| **Any badge or trophy** | Same reason as the anti-references in `design-system.md` § 0: no gamification of any kind |
| **Comparison to a previous period** ("up 12% from last month") | Implies the change is good or bad. It is neither — some weeks are for finishing a long novel |
| **Most-consecutive or best-ever framing** | "Personal best" is a high-water mark designed to be beaten |

What replaces all of it: plain counts, plainly labelled, with the **retention boundary stated on the screen** so the numbers cannot mislead. If history is trimmed at one year (**B47**), a figure without that caveat is a figure that implies "this is everything" when it is not — and **B46**'s separation of position from history applies here too: nothing on this screen is a reading position.

---

## 3. Anatomy

```
AppScaffold (titleBar = "Statistics")
└── ScrollView
    ├── RetentionNotice              "Between <date> and <date> · retention is one year"
    ├── SectionLabel                 "Reading"
    │   └── StatRow  Chapters read                    1,284
    │   └── StatRow  Novels started                      17
    │   └── StatRow  Novels finished                      6
    ├── SectionLabel                 "By source"
    │   └── SourceBar  FanMTL      ████████████░░░░  742
    │   └── SourceBar  Royal Road   ████░░░░░░░░░░░░  210
    └── SectionLabel                 "Recent"
        └── StatRow  Last chapter opened          2 days ago
```

| # | Component | Role | Source |
|---|---|---|---|
| 1 | `StatRow` | One figure: label left, value right | § 2.10 |
| 2 | `SourceBar` | A source's share of chapters read | § 2.10 |
| 3 | `AppScaffold` | Title bar and bottom nav | design-system § 2.8 |

### 2.10 `StatRow` and `SourceBar`

| Slot | Required | Content |
|---|---|---|
| `label` | yes | What is counted, `--text-body-sm`, `--color-text-secondary` |
| `value` | yes | The count, `--text-h2` 700, `--color-text-primary`, tabular figures |
| `note` | no | A qualifier, `--text-caption`, `--color-text-secondary` |

`SourceBar` adds `bar` — a 8dp `--color-surface-sunken` track with an `--color-accent` fill, plus the raw count as a number beside it. **The number is always present**: a bar alone would make the reader estimate, and a statistics screen that makes you estimate is a chart, not a statistic.

---

## 4. States — all nine, no exceptions

| State | Trigger | Rendering | Reader feedback |
|---|---|---|---|
| **Loading** | Aggregating history | Rows render with a `—` value; **no spinner**, because four rows of dashes are already legible | Nothing |
| **Filled** | History exists | Three sections, figures right-aligned | — |
| **Empty — never visited** | n/a | **Not applicable** — reaching this screen is already evidence of use | — |
| **Empty — no data** | History exists but holds no *completed opens* — the reader has only opened a screen | **A sentence and nothing else.** *Nothing has been recorded yet. Open a chapter and this fills in.* No zeroed figures, because a row of zeros is a failure looking like data. `design-system.md` § 2.7 `EmptyState`, with the named instance `no-history` | The CTA is the sentence itself; there is no button, because there is nothing to press |
| **Load error** | Aggregation throws | `ErrorState` with `--color-error` icon, a sentence naming **which** figures failed, and `secondary` Retry. If only one section fails, that section alone errors and the rest render | Retry, not dismissal |
| **Submit error** | n/a | **No submission here** | — |
| **Success** | n/a | **No success state.** Nothing was achieved | — |
| **Hors-ligne / permissions** | No connection | **Identical to Filled.** Every figure comes from local history — which is what makes this screen work with no signal at all | — |
| **Lecture seule** | n/a | **The entire screen is read-only, always.** No figure is editable, and there is no share or export action (**B30**) | — |

> Six of the nine have no rendering, each with a reason. The one that matters most is **Empty — no data**: rendering a table of zeroes would be the most misleading thing this screen could do, because zeroes look like a measurement and mean "nothing recorded". That is the same confusion B22 exists to prevent, in a different place.

---

## 5. Interactions

| Element | Event | Behaviour | Visual feedback | Resulting state | Rule |
|---|---|---|---|---|---|
| `StatRow` | — | Not interactive. **Nothing here is tappable** | — | Filled | — |
| `SourceBar` | tap | Push `browse-sources` filtered to that source | Standard slide | `browse-sources` | **B1** |
| Retry | tap | Re-run the aggregation | Rows return to dashes, then fill | Filled / Load error | — |
| Retention notice | tap | Push `/settings` at the History section | Standard slide | `settings` | **B47** |
| System back | gesture | Pop | — | `more` | — |

- **Focus / clavier**: `SourceBar` and the two links are focus stops. The `StatRow` figures are **not** focusable — a count is not a control, and making it one is how a settings screen becomes tiring to move through.
- **Gestures**: none beyond scroll. No pull-to-refresh: figures are local and cannot be stale.
- **Animations**: none. **A statistics screen that counts up its numbers is performing, not informing.**
- **Retour arrière**: pop to `more`.

---

## 6. Responsive

| Breakpoint | Behaviour | What collapses or disappears |
|---|---|---|
| **Mobile** `< 600dp` | Single column; label left, value right on one line | Nothing. Design target |
| **Tablet** `600–1023dp` | Identical, centred (**ADR-010**) | Nothing |
| **Desktop** `1024–1439dp` | Same; desktop out of scope | — |

- **Cible tactile**: `SourceBar` rows 48dp minimum even though the bar is 8dp. **A figure is never a touch target.**
- **Débordement**: labels max 1 line, values never truncate (tabular figures, right-aligned), source names max 1 line. The bar shrinks; the number does not.

---

## 7. Accessibility

- [x] **Contrast 14.48:1** (day) / **12.00:1** (night) for values — measured.
- [x] **Contrast 6.22:1** / **6.01:1** for labels and notes — measured.
- [x] **The `SourceBar` fill `--color-accent` measures 5.50:1** day / **7.25:1** night against `--color-surface` — above the 3:1 non-text threshold, and the **number beside it carries the same information**, so no information is colour-only.
- [x] **Each bar announces its number**, not its proportion: *FanMTL, 742 chapters*. A screen reader must not have to infer a length.
- [x] **Focus visible** at 2dp `--color-border-focus` on the three interactive elements.
- [x] **Language and direction** correct (B28), including the numbers' thousands separators per locale.

---

## 8. Données

| Champ | Type | Origine | Requis | Erreur possible |
|---|---|---|---|---|
| `chaptersRead` | `int` | local history, aggregate | no | Aggregation throws → Load error |
| `novelsStarted` | `int` | local history + library | no | — |
| `novelsFinished` | `int` | local history, last chapter opened | no | Definition stated in a `note`, not assumed |
| `bySource` | `List<{sourceId, count}>` | local history | no | — |
| `lastOpenedAt` | `DateTime` | local history | no | Never → `null`, renders *never* |
| `retentionWindow` | `DateRange` | `shared_preferences` (**B47**) | yes | Defaults to one year |
| `firstRecordedAt` | `DateTime` | local history | no | History trimmed → window start |

- **Chargement**: nothing is paged. Every figure is an aggregate over local history, computed in one pass and **cached in memory for the session**. Nothing is recomputed on scroll.
- **Cache / hors-ligne**: **fully local and fully available offline** — the only screen in the app that is complete with no network *and* needs no network. It is the one screen that can be true everywhere the reader goes.
- **Données sensibles**: none leave the device (**B29**), and there is no export (**B30**). Figures are derived from history and are themselves a local fact.

---

## 9. Traçabilité

| ID | Origine | Manifestation on this screen |
|---|---|---|
| B28 | PRD | Every label and figure name is FR and EN, including the retention notice |
| B30 | PRD | **No share action, no export, no figure is editable.** The screen is unconditionally read-only |
| B46 | PRD | **Nothing here is a reading position.** Every figure counts *opens*, and the section is labelled accordingly — the separation B46 requires, applied to a screen where it is easy to blur |
| B47 | PRD | **The retention boundary is stated on the screen** and tappable to the setting, so no figure can imply "this is everything" |
| E5 | PRD | History trimmed → the window start moves and the notice changes |
| E12 | PRD | A stale or corrupt aggregate → the section that failed errors alone |

---

## 10. Gate checklist

- [x] All nine states described; six have no rendering and each says why, and **Empty — no data** explicitly refuses to render zeroes
- [x] Every interactive element has a behaviour, a feedback and a resulting state — and the non-interactive rows are marked as such
- [x] Responsive defined at every breakpoint; the two larger ones stop widening (ADR-010)
- [x] Anti-generic section checked **and justified**; the assumed choice is *no score, no streak, no goal, no comparison*, argued in a table rather than asserted
- [x] No design value left "to be defined"
- [x] Every B/E/C ID appears in § 9
- [x] `forge-guard placeholders` reports nothing here
- [x] Consistent with `design-system.md`: `EmptyState` § 2.7 and `ErrorState` § 2.7 used as declared; **no shadow and no card**, per § 1.4
- [x] **Tokens cited exist**, values below

---

## 11. Tokens this screen cites

| Token | Day | Night | Measured (day / night) | Where it appears here |
|---|---|---|---|---|
| `--color-background` | `#F5F2ED` | `#121315` | — | The page field |
| `--color-surface` | `#FBF9F6` | `#1A1C1F` | — | Row background, bar track |
| `--color-text-primary` | `#1A1714` | `#E8E4DD` | **14.48:1** / **12.00:1** | Every figure |
| `--color-text-secondary` | `#5A524A` | `#A8A29A` | **6.22:1** / **6.01:1** | Labels, notes, the retention notice |
| `--color-accent` | `#8A4B12` | `#E3A857` | **5.50:1** / **7.25:1** | The one bar fill |
| `--color-error` | `#8A3228` | `#EE8B76` | **6.64:1** / **6.22:1** | Load error only |
| `--color-border` | `#D9D3C9` | `#2E3237` | exempt | Rule between rows |
| `--color-border-focus` | `#8A4B12` | `#E3A857` | **6.07:1** / **8.86:1** | Focus ring |

Non-colour tokens: `--text-h2` `#25/32` · `--text-body-sm` `#14/20` · `--text-caption` `#12/16` · `--text-overline` `#11/16` · `--space-lg` `16dp` · `--space-md` `12dp` · `--duration-normal` `200ms`.