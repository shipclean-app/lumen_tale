---
type: screen
slug: sources
title: Sources
module: more
status: approved
generated_at: 2026-10-02
derived_from:
  - .forge/prd.md
  - .forge/design/design-system.md
rule_ids:
  - B1
  - B5
  - B22
  - B23
  - B28
  - B32
  - B41
  - B50
edge_case_ids:
  - E4
  - E8
  - E9
  - E20
flow: settings-flow
---

# Screen — Sources

> Source management. This is Mihon's Extensions screen **after the extensions are taken away** — and what is left is exactly this.

---

## 1. Role of the screen

| | |
|---|---|
| **App archetype** | `mobile_consumer` |
| **Module** | more — rank 5 (overflow) |
| **Route** | `/sources` |
| **Type** | full-screen page |
| **Users** | the reader, when a site misbehaves or they want it out of the way |
| **User stories served** | US-01, US-16 |
| **Business rules** | B1 B5 B22 B23 B28 B32 B41 B50 |
| **Edge cases** | E4 E8 E9 E20 |

**In one sentence**: this screen lets the reader see which sites the app can read, turn one off without losing anything they downloaded, and read the per-site options a source declares.

**Where it comes from in Mihon**: `ExtensionDetailsScreen` (`ui/browse/extension/details/ExtensionDetailsScreen.kt:16`) lists the sources an extension provides, each individually enable/disable-able, and links each to `SourcePreferencesScreen` (`:40-44`). ADR-013 removes the extension, so the list becomes the screen rather than a detail page inside one.

---

## 2. Visual direction for this screen

| | |
|---|---|
| **Mood** | quiet, warm, unhurried |
| **Density** | **normal** — three sources is a short list, and a short list should not pretend to be dense |
| **Contrast level** | **high** — `--color-text-primary` on `--color-surface`, 14.48:1 / 12.00:1 |
| **Surface** | `--color-surface` on `--color-background` |
| **Accent used** | `--color-accent` on the switch track when on, and on the focus ring. Nowhere else |
| **Photographic treatment** | **none** — a source has a name and a language, not a cover |
| **Reference** | Mihon's `ExtensionDetailsScreen` source grid (`:41-42`), reduced to the two things that still exist |

### 2.1 Anti-generic — mandatory

- [x] **No pure `#FFFFFF`** — `--color-background` `#F5F2ED` / `#121315`.
- [x] **No shadowed card per row.** Flat rows, `--color-border` rules. No card wrapper: three rows in a list is not a gallery.
- [x] **Not uniform** — source name `--text-h3`, language `--text-body-sm`, per-source status `--text-caption`, section labels `--text-overline` 600.
- [x] **No generic grey** — paper-anchored neutral ramp.
- [x] **Not symmetrically centred** — full-bleed rows, left-aligned, switch hard right.
- [x] **No icon per source.** Mihon shows `SourceIcon`/`ExtensionIcon` (`ui/browse/source/components/BrowseIcons.kt:43,83`). We show the name and nothing else — a generated favicon per site is decoration that implies a visual identity the app has no way to maintain.
- [x] **Not one family at one weight** — sans, three scales, two weights.

**Assumed, non-neutral choice**: **a disabled source's row says what disabling keeps.** Each row carries a consequence line, and when a source is off that line becomes explicit: *Off — its novels stay in your library and its downloads stay on the phone*. **B32 is the reason this screen is more than a list of switches**: turning a source off is the action most likely to be feared as destructive, so the one place it is offered is also the place that promises it is not. Mihon has no equivalent line.

---

## 3. Anatomy

```
AppScaffold (titleBar = "Sources")
└── ScrollView
    ├── SourceRow  FanMTL
    │   ├── title       "FanMTL"
    │   ├── subtitle    "English · 8 genres"
    │   ├── status      "never checked" / "available" / "unavailable — see below"
    │   ├── consequence "Off — its novels stay in your library and its downloads stay on the phone"
    │   └── Switch      setting variant
    ├── SourceRow  Royal Road
    └── SourceRow  Novel Fire        (only when terms confirmed — Q-004)
        └── tap row → SourceOptionsSheet
            ├── Switch
            ├── per-source settings (ConfigurableSource)   ← 03-source-system.md rule 6
            └── "Check now"                                ← manual, B36
```

| # | Component | Role | Source |
|---|---|---|---|
| 1 | `SourceRow` | One source: name, language, status, consequence, enable switch | `design-system.md` § 2.10 |
| 2 | `Switch` (setting) | Enable / disable, saving on change with no Save button | `design-system.md` § 2.9 |
| 3 | `StatusChip` | Carries the status word — never colour alone | `design-system.md` § 2.5 |
| 4 | `ErrorState` | The per-source failure, when one has been detected | `design-system.md` § 2.7 |

### 2.10 `SourceRow`

**Rôle**: one site in the static registry, and the switch that takes it out of browsing.

| Slot | Required | Content |
|---|---|---|
| `title` | yes | Source name, `--text-h3`, from the registry |
| `subtitle` | yes | Language and genre count, `--text-body-sm`, `--color-text-secondary` |
| `status` | no | `StatusChip`: `never-checked` (info, B49) · `available` · `unavailable` (error) |
| `consequence` | yes | One line. Changes with the switch state — see § 2.1 |
| `switch` | yes | `Switch` variant `setting` |
| `options` | no | Chevron, when the source declares settings |

---

## 4. States — all nine, no exceptions

| State | Trigger | Rendering | Reader feedback |
|---|---|---|---|
| **Loading** | Reading the registry | Rows render with **no** `status` chip and the switch **disabled** until the read completes. No spinner — three rows do not need one | Nothing, deliberately: the rows are already there and legible |
| **Filled** | Registry read, all sources healthy | Three rows, switch on, `status` chip per row | — |
| **Empty — never visited** | n/a | **Not reachable.** The registry is compiled in; it is never empty. Mihon's extension list genuinely can be empty (`:51`), ours cannot | — |
| **Empty — no data** | n/a | **Not reachable**, and this is a deliberate difference worth naming: **a compiled-in registry has no empty state**, so there is no empty state to get wrong | — |
| **Load error** | Registry or per-source settings unreadable | **Fail open, and say so.** The row still renders with its name; the `status` chip reads `unavailable`, the switch is **left on** rather than forced off, and a line says *settings could not be read, so this source stays on*. Rationale below | The reader sees a real status, not a silently-empty list |
| **Submit error** | A `Switch` write fails | The switch **snaps back**, the row turns `--color-error`, and the failure appears **beside** the switch — never by tinting the switch. Per `design-system.md` § 2.9, a switch has no loading state on purpose | Immediate and visible |
| **Success** | n/a | **No success state.** Toggling a switch needs no confirmation — it is reversible and nothing is destroyed (**B32**) | — |
| **Hors-ligne / permissions** | No connection | **Identical to Filled.** No permission is ever requested (nothing to request), and a source's *existence* is a compile-time fact, not something a network can revoke | — |
| **Lecture seule** | n/a | **Not applicable** — this screen is always writable | — |

> Four of the nine have no rendering, each with its reason. Two of them are worth reading twice:
>
> **Empty — never visited** and **Empty — no data** are *unreachable*, not merely unstyled. A static registry cannot be empty. Mihon's extension list can be, and Mihon has to design for it; we get to record that we do not.
>
> **Load error fails open.** The contestable choice is here. If the settings read fails and we forced every switch off, the browse screen would be empty — and an empty browse screen is **indistinguishable from "you turned everything off"**, which is precisely the confusion B22 exists to prevent, reproduced by a different route. So the switches stay on and the row says the read failed. The risk is the mirror image: if the failure persists, the app shows sources as enabled that cannot browse. That risk is paid by the `unavailable` chip and by `browse-sources` reporting the failure there, which is where the reader actually goes next.

---

## 5. Interactions

| Element | Event | Behaviour | Visual feedback | Resulting state | Rule |
|---|---|---|---|---|---|
| `Switch` | tap | Enable / disable the source; writes to `shared_preferences` **synchronously** | Track fills `--color-accent` over `--duration-fast`; `consequence` line changes | Filled | **B32** |
| `Switch` | tap, write fails | Snap back; row turns `--color-error`; message beside the switch | Error row | Submit error | — |
| `SourceRow` | tap | Open `SourceOptionsSheet` for that source | Sheet slides up `--duration-normal` | Filled + sheet | — |
| `status` chip `unavailable` | tap | Open `source-unavailable` for that source | Sheet | — | **B22** |
| `status` chip `never-checked` | tap | Nothing — it is information, not an action | — | Filled | **B49** |
| Source settings row | tap | Open the per-source settings a `ConfigurableSource` declares | — | Settings sheet | `03-source-system.md` rule 6 |
| *Check now* | tap | A single **manual** check of this source — never scheduled, never automatic | Row shows `available` | Filled | **B35 B36** |
| System back | gesture | Return to `more` | Standard | `more` | — |

- **Focus / clavier**: row → switch → options, three stops per row. The switch is operable by `Space`/`Enter`. Focus visible at 2dp `--color-border-focus`.
- **Gestures**: none. **No swipe-to-disable** — a destructive-looking gesture on a switch that a reader may believe deletes their library is the wrong affordance for this control.
- **Animations**: `--duration-fast` 120ms on the track, `--duration-normal` 200ms on the sheet.
- **Retour arrière**: sheet closes, then the screen pops.

> **No incognito toggle, no "clear cookies".** Mihon's `ExtensionDetailsScreen` offers both per source (`:40-44`). Incognito needs an identity concept (**B4** forbids it), and cookies exist in Mihon because of its Cloudflare `cf_clearance` harvest — which **ADR-014 deliberately does not port**, so there is nothing to clear.

---

## 6. Responsive

| Breakpoint | Behaviour | What collapses or disappears |
|---|---|---|
| **Mobile** `< 600dp` | Single column, rows 72dp + a 24dp consequence line | Nothing. Design target |
| **Tablet** `600–1023dp` | Identical single column, centred (**ADR-010**) | Nothing |
| **Desktop** `1024–1439dp` | Same; desktop out of scope | — |

- **Cible tactile**: 48dp minimum on the switch, 48dp on the whole row's tap target, 48dp on each status chip.
- **Débordement**: source name max 1 line, subtitle max 1 line, `consequence` max **2** lines and truncates after that. A third line would push the switch's vertical centre off its row and break the scan.

---

## 7. Accessibility

- [x] **Contrast 14.48:1** (day) / **12.00:1** (night) for source names — measured.
- [x] **Contrast 6.22:1** / **6.01:1** for subtitles, status words and consequence lines — measured.
- [x] **Switch track measured as non-text**: `--color-accent` `#8A4B12` at **6.07:1** day / `#E3A857` at **8.86:1** night against `--color-background` (WCAG 1.4.11, 3:1). The off-state track is `--color-surface-sunken` and is paired with a **word** in the consequence line, never with position alone.
- [x] **Every switch announces state in words**: *FanMTL, English, 8 genres, off. Its novels stay in your library and its downloads stay on the phone.* The consequence line is part of the label, so the reassurance is spoken, not just drawn.
- [x] **Status is never colour alone** — every chip pairs `--color-error` / `--color-info` with an icon and a word.
- [x] **Language and direction** correct (B28).

---

## 8. Données

| Champ | Type | Origine | Requis | Erreur possible |
|---|---|---|---|---|
| `source.name` | `String` | static registry | yes | None |
| `source.lang` | `String` | static registry | yes | — |
| `source.supportsSearch` | `bool` | static registry | yes | — |
| `source.filterList` | `FilterList` | static registry | no | Empty list → the row's subtitle says *no genres* |
| `source.status` | `enum(available, unavailable, never-checked)` | local, from the last check | no | Never checked → `never-checked` (**B49**) |
| `source.enabled` | `bool` | `shared_preferences` | yes | Write failure → Submit error state |
| `source.settings` | `Map<String,dynamic>` | `shared_preferences`, namespaced `source_<id>` | no | Read failure → **Load error, fail open** |

- **Chargement**: nothing is paged. The registry is compiled in; only `status` and `settings` are read.
- **Cache / hors-ligne**: **the whole screen works with no network.** A source's existence, its filters and its enabled flag are all local facts. This is the point: the reader must be able to turn a misbehaving site off while offline.
- **Données sensibles**: none. No source credential is displayed on this screen — if a `ConfigurableSource` declares one, it is shown in **its own** settings sheet, masked, and never in the row. B29's guarantee that nothing leaves the device is not weakened by a local credential, but displaying one in a list would put it in screenshots.

---

## 9. Traçabilité

| ID | Origine | Manifestation on this screen |
|---|---|---|
| B1 | PRD | The list is exactly the compiled-in registry — two sites plus Novel Fire when its terms are confirmed |
| B5 | PRD | **No per-source fetch happens from this screen.** *Check now* is an explicit action the reader takes, never a side effect of opening it |
| B22 | PRD | A source that cannot be read shows `unavailable` with an icon and a word, and tapping it opens `source-unavailable` — never an empty-looking row |
| B23 | PRD | Disabling one source never touches the others, and the row says the stored chapters survive |
| B28 | PRD | Every string here is FR and EN |
| B32 | PRD | **The `consequence` line states it in words**: off keeps the library and the downloads |
| B41 | PRD | `filterList` is rendered as the source declares it; the platform interprets no value (**B50** governs whether search appears) |
| B50 | PRD | **`supportsSearch` is displayed as a fact**, so the reader can see why a source will not offer search — rather than being given a search field that returns nothing |
| E4 | PRD | A site changed its layout → `unavailable`, reported not hidden |
| E8 | PRD | A source declares no filters → the subtitle says *no genres*, and Browse shows a real empty state rather than an error |
| E9 | PRD | Locale change → all strings re-localise |
| E20 | PRD | A settings read failure → **fail open** with the reason stated |

---

## 10. Gate checklist

- [x] All nine states described; four have no rendering and each says **why**, including that a static registry makes two of them *unreachable* rather than merely unstyled
- [x] Every interactive element has a behaviour, a feedback and a resulting state
- [x] Responsive defined at every breakpoint; the two larger ones stop widening (ADR-010)
- [x] Anti-generic section checked **and justified**; the assumed choice is *consequence-first rows, so B32 can be promised in words*
- [x] No design value left "to be defined"
- [x] Every B/E/C ID appears in § 9
- [x] `forge-guard placeholders` reports nothing here
- [x] Consistent with `design-system.md`: `Switch` `design-system.md` § 2.9 and `StatusChip` `design-system.md` § 2.5 are both used as declared, including `Switch`'s deliberate **absence** of a loading state
- [x] **Tokens cited exist**, values below

---

## 11. Tokens this screen cites

| Token | Day | Night | Measured (day / night) | Where it appears here |
|---|---|---|---|---|
| `--color-background` | `#F5F2ED` | `#121315` | — | The page field |
| `--color-surface` | `#FBF9F6` | `#1A1C1F` | — | Row background |
| `--color-text-primary` | `#1A1714` | `#E8E4DD` | **14.48:1** / **12.00:1** | Source name |
| `--color-text-secondary` | `#5A524A` | `#A8A29A` | **6.22:1** / **6.01:1** | Language, status word, consequence line |
| `--color-accent` | `#8A4B12` | `#E3A857` | **5.50:1** / **7.25:1** | Switch track when on |
| `--color-info` | `#426986` | `#7FB3DA` | **4.74:1** / **6.78:1** | `never-checked` chip (**B49**) — info, never warning |
| `--color-error` | `#8A3228` | `#EE8B76` | **6.64:1** / **6.22:1** | `unavailable` chip, and a failed switch write |
| `--color-border` | `#D9D3C9` | `#2E3237` | exempt | Rule between rows |
| `--color-border-focus` | `#8A4B12` | `#E3A857` | **6.07:1** / **8.86:1** | Focus ring |

Non-colour tokens: `--text-h3` `#20/26` · `--text-body-sm` `#14/20` · `--text-caption` `#12/16` · `--text-overline` `#11/16` · `--space-md` `12dp` · `--space-lg` `16dp` · `--duration-fast` `120ms` · `--duration-normal` `200ms` · `--ease-standard` `cubic-bezier(0.2, 0, 0, 1)` · `--radius-full` `999dp`.