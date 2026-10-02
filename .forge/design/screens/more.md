---
type: screen
slug: more
title: More
module: more
status: approved
generated_at: 2026-10-02
derived_from:
  - .forge/prd.md
  - .forge/design/design-system.md
rule_ids:
  - B1
  - B29
  - B30
  - B34
  - B43
  - B50
edge_case_ids:
  - E9
  - E19
flow: settings-flow
---

# Screen — More

> The overflow destination. Rank **5** of 5 in the navigation, and the lowest **by design**.

---

## 1. Role of the screen

| | |
|---|---|
| **App archetype** | `mobile_consumer` |
| **Module** | more — rank **5** |
| **Route** | `/more` |
| **Type** | full-screen page |
| **Users** | the reader, when they want to change something rather than read |
| **User stories served** | US-13, US-17, plus the settings entry point for US-15/US-14 |
| **Business rules** | B1 B29 B30 B34 B43 B50 |
| **Edge cases** | E9 E19 |

**In one sentence**: this screen lets the reader reach everything that is configuration rather than reading, and be gone again quickly.

**Why it is at rank 5**: ADR-018 argues it. Frequency **2**, centrality **1** — the lowest on both counts — because every entry behind it is a setting or a transfer and none of it is part of the reading loop. It is last not as a dumping ground but because nothing here is ever the reason the app was opened.

---

## 2. Visual direction for this screen

| | |
|---|---|
| **Mood** | quiet, warm, unhurried |
| **Density** | **normal** — a list of 5 destinations needs air to be scannable, not the density of a data list |
| **Contrast level** | **medium** — `--color-text-primary` on `--color-surface`, 14.48:1 worst day / 12.00:1 night |
| **Surface** | `--color-surface` on `--color-background` |
| **Accent used** | `--color-accent` **only** on the active row's leading edge — the same 3dp marker `ChapterListTile` uses for the current chapter, so "where am I" looks the same everywhere in the app |
| **Photographic treatment** | **none** |
| **Reference** | the second-level of Mihon's `MoreScreen` (`ui/more/MoreTab.kt:42`) — a plain scrollable list — with its logo header and its two global switches removed, for reasons below |

### 2.1 Anti-generic — mandatory

- [x] **No pure `#FFFFFF` background** — `--color-background` `#F5F2ED` / `#121315`.
- [x] **No shadowed card per row.** Rows are flat, separated by `--color-border`. The one shadow in the app is `--shadow-sheet`, and it is not used here.
- [x] **Not uniform** — section labels are `--text-overline` at 600 with `letter-spacing 0.08em`, row titles `--text-h4`, row subtitles `--text-body-sm`. Three scales, three weights.
- [x] **No generic grey** — the paper-anchored neutral ramp.
- [x] **Not symmetrically centred** — rows are full-bleed with `--space-md` internal padding, left-aligned.
- [x] **No illustration.** No logo header, no icon per row. Mihon has both (`MoreScreen.kt:32`, `LogoHeader.kt`); a logo at the top of an overflow list is decoration that costs a screenful.
- [x] **Not one family at one weight** — sans throughout, but three type scales.

**Assumed, non-neutral choice**: **this list shows only what the reader can act on, and names the consequence of every entry.** Each row carries a one-line subtitle that says what the destination *is*, not what it is called — *Downloads — what is on the phone and what is not*, *Sources — the sites this app can read*. Mihon's `MoreScreen` rows are label-only, which forces a tap to find out. It also means the screen can be **absent features honestly**: there is no *Backup*, no *Export*, no *Sync*, no *Account*, and the absence is explained by `coverage.md` § B29/B30 rather than looking like something was forgotten.

---

## 3. Anatomy

```
AppScaffold (titleBar = "More", bottomNav visible, this is rank 5)
└── ScrollView
    ├── SectionLabel                       --text-overline, "Library"
    │   └── MoreRow  Downloads             subtitle + live queue state
    │   └── MoreRow  Stats
    │   └── MoreRow  History retention     → settings
    ├── SectionLabel                       --text-overline, "Sources"
    │   └── MoreRow  Sources               → sources
    └── SectionLabel                       --text-overline, "Application"
        └── MoreRow  Settings              → settings
        └── MoreRow  About                 → settings-about
```

| # | Component | Role | Source |
|---|---|---|---|
| 1 | `MoreRow` | One destination: title, one-line consequence, optional live value | `design-system.md` § 2.10 (below) |
| 2 | `AppScaffold` | Holds the title bar and the bottom nav | `design-system.md` § 2.8 |

### 2.10 `MoreRow` — declared here because it exists only for this screen

**Role**: one destination in a navigation list, with what it currently is.

| Slot | Required | Content |
|---|---|---|
| `title` | yes | Destination name, `--text-h4` |
| `subtitle` | yes | One line saying what the destination **does**, `--text-body-sm`, `--color-text-secondary`, max 1 line |
| `value` | no | Live state, right-aligned — e.g. *3 queued*, *2 sources*, *1 year*. `--text-body-sm`, `--color-text-secondary` |
| `trailing` | no | Chevron, `--color-text-disabled` |

**No icon.** Five unlabelled pictograms in a column is a memory test, not a navigation aid.

---

## 4. States — all nine, no exceptions

| State | Trigger | Rendering | Reader feedback |
|---|---|---|---|
| **Loading** | Nothing to load — the row list is static | **No loading state at all.** Deliberately: a spinner on a list of five strings is a spinner that exists to be looked at | — |
| **Filled** | The normal case | Five rows in three labelled sections | — |
| **Empty — never visited** | n/a | **Not applicable.** The list is never empty — there is always somewhere to go | — |
| **Empty — no data** | n/a | **Not applicable**, for the same reason. `Sources` still lists its sources; `Downloads` shows an empty queue *inside* `downloads` | — |
| **Load error** | n/a | **Not applicable.** This screen reads no remote state. The two `value` slots that could fail — queue state and source count — are local reads, and if one is unreadable the row shows **no `value`**, not an error. A settings list that can fail is a settings list that can be wrong | — |
| **Submit error** | n/a | **No submission here** | — |
| **Succès** | n/a | **No success state** | — |
| **Hors-ligne / permissions** | No connection | **Identical to Filled.** Nothing on this screen needs a network, and B7 already guarantees stored chapters read offline — so an offline banner here would be announcing a capability the reader does not need reminding of | — |
| **Lecture seule** | n/a | **Not applicable** | — |

> Six of the nine have no rendering, and each says why. For a navigation list that is the correct outcome rather than a shortfall: the states that belong here are **where the `value` slot shows something**, and those are described in § 5. A screen that manufactures empty and error states it cannot reach is a screen that lies about its own robustness.

---

## 5. Interactions

| Element | Event | Behaviour | Visual feedback | Resulting state | Rule |
|---|---|---|---|---|---|
| `MoreRow` | tap | Push the destination route | Standard `--duration-normal` slide | Destination's own screen | — |
| `MoreRow` → Downloads | tap | Push `/more/downloads`; `value` shows the live queue state | — | `downloads` | **B5** |
| `MoreRow` → Sources | tap | Push `/sources`; `value` shows *N sources* | — | `sources` | **B1** |
| `MoreRow` → Stats | tap | Push `/stats` | — | `stats` | — |
| `MoreRow` → History retention | tap | Push `/settings`, scrolled to the History section | — | `settings` | **B47** |
| `MoreRow` → Settings | tap | Push `/settings` | — | `settings` | **B26 B27 B28** |
| `MoreRow` → About | tap | Push `/settings-about` | — | `settings-about` | **B43** |
| Bottom-nav More (re-tap) | tap | **No-op that scrolls to top** — Mihon pushes Settings on re-tap (`MoreTab.kt:56-58`) | — | Filled | — |
| Section label | — | Not interactive. A label that expands is a label that hides destinations | — | — | — |

- **Focus / keyboard**: each row is one focus stop, in order. Focus visible at 2dp `--color-border-focus`.
- **Gestures**: none beyond scroll. **No swipe-to-delete** — nothing here is deletable.
- **Animations**: `--duration-normal` 200ms `--ease-standard` for the push only.
- **Retour arrière**: system back returns to the previous tab, which is the tab the reader was on before opening More — the bottom nav keeps each destination's own back stack.

> **On re-tap.** Mihon pushes Settings when the More tab is re-tapped. That is a shortcut into the *least* likely destination from the *least* likely tab, and it makes the re-tap gesture unpredictable. Ours does nothing. The one place a re-tap shortcut is worth having — History resuming the last chapter — is adopted verbatim, because there it is the fastest possible path back into reading.

---

## 6. Responsive

| Breakpoint | Behaviour | What collapses or disappears |
|---|---|---|
| **Mobile** `< 600dp` | Single column, full-bleed rows, `--space-lg` margins | Nothing. Design target |
| **Tablet** `600–1023dp` | Identical single column, centred. **Not a tablet layout** (ADR-019) | Nothing collapses — it stops widening |
| **Desktop** `1024–1439dp` | Same. Flutter desktop out of scope | — |

- **Cible tactile**: 56dp rows, above the 48dp minimum. `trailing` chevrons are 48dp even though the glyph is small.
- **Débordement**: row titles max 1 line (`--text-h4`), subtitles max 1 line (`--text-body-sm`), `value` truncates rather than wrapping. A two-line row in a settings list breaks the scan rhythm the whole screen depends on.

---

## 7. Accessibility

- [x] **Contrast 14.48:1** (day) / **12.00:1** (night) for row titles — measured.
- [x] **Contrast 6.22:1** / **6.01:1** for subtitles and `value` — measured.
- [x] **Focus ring `--color-border-focus`** at **6.07:1** / **8.86:1**, non-text, 2dp with 2dp offset.
- [x] **Every row has an accessibility label** combining title, subtitle and live `value` — *Downloads, what is on the phone and what is not, 3 queued*. The three parts are one focus stop and must announce as one thing.
- [x] **Language and reading direction** correct (B28); the row list does not assume LTR for the chevron.
- [x] **No colour carries meaning alone** — there is no colour-only state on this screen at all, which is the `design-system.md` § 0 anti-reference satisfied trivially.

---

## 8. Données

| Champ | Type | Origine | Requis | Erreur possible |
|---|---|---|---|---|
| `entries` | `List<MoreEntry>` | static, code | yes | None — a compile-time list |
| `downloads.pendingCount` | `int` | local queue | no | Unreadable → `value` omitted, row still tappable |
| `sources.enabledCount` | `int` | local | no | Unreadable → `value` omitted |
| `history.retention` | `Duration` | `shared_preferences` | yes | None — defaults to one year (**B47**) |

- **Chargement**: nothing loads. The list is static; only two `value` slots are dynamic and both are local reads.
- **Cache / hors-ligne**: **the whole screen works with no network**, because it reads nothing remote.
- **Données sensibles**: nothing on this screen is sensitive. It is the one place the app states **B29** (nothing leaves the device) and **B30** (nothing can be shared out) by *omission* — there is no Analytics, no Crash Reporting, no Export and no Account entry, and `coverage.md` records each absence with its reason.

---

## 9. Traçabilité

| ID | Origine | Manifestation on this screen |
|---|---|---|
| B1 | PRD | The Sources row's `value` shows how many sources exist; the destination lists them |
| B29 | PRD | **No telemetry, analytics or crash-reporting entry exists.** The absence is the implementation |
| B30 | PRD | **No backup, export, share or sync entry exists** — see `coverage.md`, which records this as an exclusion with a reason rather than an omission |
| B34 | PRD | The About destination states phones-only and APK delivery |
| B43 | PRD | The About row leads to a screen showing the installed version |
| B50 | PRD | **No search entry exists anywhere on this screen.** Search is a per-source capability on the Browse screens, never a global one |
| E9 | PRD | Locale change while on this screen — section labels and row subtitles re-localise; `value` strings do too (**B28**) |
| E19 | PRD | A source disabled elsewhere → the Sources `value` count updates on return |

---

## 10. Gate checklist

- [x] All nine states described. Six have no rendering and each says **why** — for a static navigation list, manufacturing empty and error states it cannot reach would be a screen that lies about its own robustness
- [x] Every interactive element has a behaviour, a feedback and a resulting state
- [x] Responsive defined at every breakpoint; the two larger ones say "identical, stops widening" (ADR-019)
- [x] Anti-generic section checked **and justified** — the assumed choice is *consequence-first rows with no icons, so absent features can be honest*
- [x] No design value left "to be defined"
- [x] Every B/E/C ID on this screen appears in § 9
- [x] `forge-guard placeholders` reports nothing here
- [x] Consistent with `design-system.md`: no shadow, no card, `MoreRow` declared here because it exists only for this screen
- [x] **Tokens cited exist**, values below

---

## 11. Tokens this screen cites

| Token | Day | Night | Measured (day / night) | Where it appears here |
|---|---|---|---|---|
| `--color-background` | `#F5F2ED` | `#121315` | — | The page field |
| `--color-surface` | `#FBF9F6` | `#1A1C1F` | — | Row background |
| `--color-text-primary` | `#1A1714` | `#E8E4DD` | **14.48:1** / **12.00:1** | Row titles |
| `--color-text-secondary` | `#5A524A` | `#A8A29A` | **6.22:1** / **6.01:1** | Subtitles, `value`, section labels |
| `--color-text-disabled` | `#6E665C` | `#948E87` | **4.58:1** / **4.69:1** | Chevron |
| `--color-accent` | `#8A4B12` | `#E3A857` | **5.50:1** / **7.25:1** | The active row's 3dp leading edge |
| `--color-border` | `#D9D3C9` | `#2E3237` | exempt | Rule between rows |
| `--color-border-focus` | `#8A4B12` | `#E3A857` | **6.07:1** / **8.86:1** | Focus ring |

Non-colour tokens: `--text-h4` `#18/24` · `--text-body-sm` `#14/20` · `--text-overline` `#11/16` · `--space-lg` `16dp` · `--space-md` `12dp` · `--duration-normal` `200ms` · `--ease-standard` `cubic-bezier(0.2, 0, 0, 1)`.