---
type: design-system
status: approved
generated_at: 2026-10-02
derived_from:
  - .forge/prd.md
  - .forge/benchmarks.md
---

# Design System — Lumen Tale

> The visual foundation for every screen in `.forge/design/screens/`. Changing a token here changes the whole product.
>
> **Every value in this document is measured, not asserted.** Contrast ratios were computed with the WCAG 2.1 relative-luminance formula and are recorded next to the token. `design-check contrast` re-measures them at the gate.

---

## 0.0 Colour class declaration

> Written **before** section 1, and it is an engagement: a colour token absent from these lists is a deliberate choice, not an oversight, and the checker will say so.

<!-- forge:token-classes
text     --color-text-primary --color-text-secondary --color-text-disabled --color-accent --color-success --color-warning --color-error --color-info
on       --color-text-inverse = --color-accent --color-success --color-warning --color-error --color-info
surface  --color-background --color-surface --color-surface-raised --color-surface-sunken
nontext  --color-border-field --color-border-focus --color-border-strong
exempt   --color-border = purely decorative rule between list rows; carries no information and is not a component boundary, so WCAG 1.4.11 does not apply to it
-->

**The five directives.**

| Directive | Effect | Threshold |
|---|---|---|
| `text` | carries text | **4.5:1** against every `surface`, and against every background in its `on:` list |
| `surface` | a background text is placed on | none of its own; the text placed on it is measured |
| `nontext` | UI component: field border, focus ring | **3:1** against `--color-background` (WCAG 1.4.11) |
| `on` | backgrounds this text is **actually** placed on | — |
| `exempt` | neither text nor component | none — **the reason is mandatory** |

> **Why `on:` is not a convenience.** `--color-text-inverse` is never placed on a page surface; it is placed on the accent and semantic fills. Without `on:` it would be measured against the paper, where it is never drawn, and would fail by palette — which is almost every palette. The declaration above is what stops that false failure.
>
> The first draft of this declaration also listed `--color-surface-raised` under `on:`, on the theory that inverse text might sit on a raised surface. It does not — and it is worse than redundant: the checker then measured `#17181A` against `#232629` and reported **1.17:1**, an "offender" that described a combination the app never draws. An `on:` list is a claim about where text is *actually* posed, so an entry that is not true is not neutral, it is a false failure that looks like a real one.

> **Do not move a button background into `nontext` to make its label measurable.** Declare the label in `text` with an `on:` pointing at that background. Measuring every text token against every component keeps the worst pair and produces a warning nobody can close.

---

## 0. Visual direction

| Anchor | Content |
|---|---|
| **References** | **Mihon** for structure and restraint — content first, flat lists, no decoration that is not information. **Apple Books** for reading typography and a quiet progress indicator. **Kindle** for the offline posture: the shelf is the app, and the app is usable with the radio off. |
| **Ambiance** | *quiet, warm, unhurried* |
| **Anti-references** | No gamification of any kind — no streaks, no badges for reading, no confetti, no "you have unread!" as a reward. No achievement loops. No illustrations or empty-state art: an empty state is a sentence and one action. No shadowed card per row. No default blue. No icon-in-a-circle as decoration. No pure `#FFFFFF` page background. |

**App archetype**: `mobile_consumer` — see `references/archetypes.md`.
**Platform**: Android (Flutter). Phone only in v1.
**Core loop**: *find a novel, download it, read it offline, resume where I stopped, notice when a tracked novel has a new chapter.*

**Density**: **normal**, leaning airy in the reader and compact in the library.
Justification: the two dominant surfaces have opposite jobs. The reader must be the most generous surface in the app — it is the one the user stares at for twenty minutes at a time, so it gets a 16px minimum body, a 1.7 line-height and a 65–75 character measure. The library is a *scan* surface: it is glanced at to answer "what do I have and what is new", so rows stay 72dp with title and status on two lines. Applying one density to both would either crowd the prose or waste the library.

### Design skill — required, and absent here

`references/design-quality.md` § 2 requires a design skill per context; for a mobile app that is `imagegen-frontend-mobile`.

**It is not installed in this environment**, and no image-generation skill is available either. Per § 2's fallback, the **§ 3 interdicts are applied in full** (each is checked in § 4.1 of every screen file, and the checklist at the foot of this document), and the **§ 4 requirements are met**. **This absence is recorded here and repeated in the phase audit** rather than being papered over. The practical consequence: there are no rendered mockups, so the direction is carried by this document's tokens and anchors alone, and visual review happens in code, at the gate.

### The contestable choices

Three decisions here would be argued with. They are argued *for*, not merely made.

**1. The two themes are deliberately not inversions of each other.** Day is warm paper (hue ≈ 37°, chroma 0.03). Night is **cool ink** (hue 220°, chroma 0.14) carrying warm-white text (`#E8E4DD`). The obvious "cosy" choice is a warm night theme, and the competitors do exactly that. It is the wrong choice for this product: warm text on a warm dark field raises halation at low brightness, which is precisely the condition under which a reader turns the brightness down. A cool field with warm text keeps the page looking unlit and the prose looking lit. The amber accent then reads as *lamplight* on that cool field, and never as an error colour — which is why `error` is a desaturated brick (`#8A3228` day / `#EE8B76` night) and not another red-orange that would compete with the accent.

**2. The reader's prose is set in a serif; the chrome is not.** Mihon renders images and has no typographic opinion, so this is a place where copying the reference copies nothing. The dominant activity here is long-form prose, and prose at 20px/1.7 in a sans is measurably less comfortable over a long session than the same in a serif. FanMTL's own reader chrome offers **Lora** and a **Dyslexic** option as font choices — evidence that this particular reader expects to be offered a reading face. We do not bundle one: the prose uses a serif *preference chain* (`Noto Serif` → `Roboto Slab` → platform serif) with a sans fallback, so there is no licence to carry and no APK weight. Bundling a variable reading face is a **v2** candidate, and only if the preference chain proves unsatisfying.

**3. The accent is amber, not blue.** Blue is the default accent of essentially every Android app and carries no meaning here. Amber is derived from the reading-lamp concept and, more practically, it is the one accent hue that survives both themes without changing role: it is a dark burnt orange on paper and a light gold on ink, and it never collides with `error`.

### What this design refuses that the benchmarks say competitors ship

`benchmarks.md` § 2.2 records that Dreame and Webnovel both offer flipping, sliding *and* scrolling reading modes, and that Dreame's dark mode is "not immediately obvious — you have to dig into the settings menu". **We ship neither the mode carousel nor a hidden dark-mode switch.** ADR-009 defers the modes to v2; the theme switch is in the reader's own controls and in the top bar, one tap from every screen that matters. The parity gap is real and deliberate; § 4 of `benchmarks.md` records its cost.

---

## 1. Design tokens

### 1.1 Colours

One token, one role, **two theme values**, in one row. This is the shape Flutter wants — a `ThemeExtension` carrying the same property names with different values per `ThemeData` — so the token is written once and themed twice, not duplicated under a `_light` suffix.

It also keeps the file honest for the checkers. Written as two separate tables, each token name appears **twice**, and `design-check` resolves a token to its *last* occurrence: `contrast` then measures only the night theme and silently ignores the day one, and `tokens-used` flags the day table as 18 screens citing values that disagree with the design system — the design system disagreeing with itself. One row per token removes the duplicate, and both themes stay visible in one place.

| Token | Day | Night | Measured (day / night) | Usage |
|---|---|---|---|---|
| `--color-background` | `#F5F2ED` | `#121315` | — | Page field. Day is warm paper, **not** `#FFFFFF`; night is **cool** ink — see the contestable choices in § 0. |
| `--color-surface` | `#FBF9F6` | `#1A1C1F` | — | List rows, cards, sheets |
| `--color-surface-raised` | `#FEFCF9` | `#232629` | — | Menus, dialogs, the reader's control bar |
| `--color-surface-sunken` | `#EBE7E0` | `#0C0D0F` | — | Recessed wells: the reader behind the text, empty states |
| `--color-text-primary` | `#1A1714` | `#E8E4DD` | **14.48:1** / **12.00:1** | Body and titles |
| `--color-text-secondary` | `#5A524A` | `#A8A29A` | **6.22:1** / **6.01:1** | Metadata, chapter numbers, captions |
| `--color-text-disabled` | `#6E665C` | `#948E87` | **4.58:1** / **4.69:1** | Disabled controls. WCAG 1.4.3 exempts inactive text; we still clear 4.5:1 because it costs nothing. |
| `--color-text-inverse` | `#FDFAF6` | `#17181A` | **5.54:1** / **7.27:1** | Text on a fill. See § 0.0. |
| `--color-accent` | `#8A4B12` | `#E3A857` | **5.50:1** / **7.25:1** | Primary action, focus ring, active tab, links |
| `--color-success` | `#40713A` | `#7FBE72` | **4.68:1** / **6.89:1** | Download complete, source healthy |
| `--color-warning` | `#8A5A12` | `#E0AC47` | **4.80:1** / **7.36:1** | **Not a failure, but needs attention.** Partial or interrupted download · a site refusing or rate-limiting · a permission denied. Never *never checked* — that is `--color-info`, because an absence of information must not borrow the colour that means something went wrong |
| `--color-error` | `#8A3228` | `#EE8B76` | **6.64:1** / **6.22:1** | Failed download, broken source (B22) |
| `--color-info` | `#426986` | `#7FB3DA` | **4.74:1** / **6.78:1** | Neutral notices, and the **"never checked"** state (B49) — *never checked* is an absence of information, so it must not borrow the colour that means *something went wrong* |
| `--color-border` | `#D9D3C9` | `#2E3237` | exempt | Rule between list rows. `exempt` per § 0.0. |
| `--color-border-field` | `#8F8778` | `#6B6560` | **3.18:1** / **3.24:1** | Text-field outline — a component boundary |
| `--color-border-focus` | `#8A4B12` | `#E3A857` | **6.07:1** / **8.86:1** | Focus ring |
| `--color-border-strong` | `#6B645E` | `#8A8885` | **5.21:1** / **5.26:1** | Selected row, pressed state |


**Semantic colours are per-theme by necessity, not by preference.** A single value cannot serve both: an error red at `#8A3228` measures **7.32:1** on paper and **2.27:1** on night. Every semantic colour is therefore specified twice. This is the one place where "one token, two values" is not a convenience — it is the difference between a legible error message and an invisible one.

**One inverse token, not five.** An earlier draft of this table carried five per-semantic `on-*` values (`#1A0F0C`, `#0F1A0E`, `#0E161C` and so on), each chosen to squeeze more contrast out of its own fill. Measured against the declared `--color-text-inverse` they were both redundant and wrong: the document declared one token, so `#17181A` *is* the colour actually drawn on `#EE8B76`, and the claimed 7.69:1 was a figure for a colour the app does not use. One token per theme clears **5.54:1** (day) and **7.27:1** (night) on every fill in the palette, which is the only requirement — and five near-identical tokens for a 0.4:1 difference is the kind of accumulation this design system is supposed to refuse.

> **How to read the `Measured` column.** Each figure is the **worst** ratio the token achieves across the surfaces (or `on:` fills) it is legal to appear on, in that theme — not a ratio against one convenient neighbour.
>
> **What the checkers verify, and what they do not.** `design-check contrast` reads the **Day** column — the first value on the row — so every day figure in this table is re-derived by the tool, and a claim that drifts from the measurement by more than 0.15 fails the gate. **The Night column is not machine-checked** by that command. It was verified with the same WCAG 2.1 relative-luminance formula and every night figure is recorded here: text tokens 4.69:1 – 12.00:1 against the four night surfaces, `--color-text-inverse` at 7.27:1 worst of its `on:`, non-text 3.24:1 – 8.86:1 against the night background. Those numbers are claims this document makes on its own authority, which is a weaker guarantee than the day column's and is stated as such rather than left implied.
>
> The single-row format exists for a reason worth recording: written as two separate tables, each token name appears twice and both checkers misbehave — `contrast` resolves to the last occurrence and measures one theme while ignoring the other, and `tokens-used` flags the design system's own day table as 18 screens whose values disagree with the design system, i.e. the file contradicting itself. One row per token removes the ambiguity and both commands pass.

| Ramp | 50 | 100 | 200 | 300 | 400 | 500 | 600 | 700 | 800 | 900 | 950 |
|---|---|---|---|---|---|---|---|---|---|---|---|
| `--color-accent-*` (day) | `#F98720` | `#EE821F` | `#DA761C` | `#C16919` | `#A15715` | `#8A4B12` | `#69390E` | `#512C0B` | `#3F2208` | `#2F1A06` | `#221204` |
| `--color-accent-*` (night) | `#F9B85F` | `#EEB05B` | `#DAA154` | `#C18E4A` | `#A1773E` | `#8A6635` | `#694D28` | `#513C1F` | `#3F2F18` | `#2F2312` | `#22190D` |
| `--color-ink-*` (neutral) | `#F8F5F0` | `#F1EEE9` | `#E1DEDA` | `#C9C7C3` | `#A8A6A3` | `#8A8885` | `#666563` | `#4C4C4A` | `#393938` | `#2A2A29` | `#1E1E1D` |

Both ramps are **tonal**: hue and chroma are held constant and only lightness moves, so step 500 of each is the anchor and the neighbours are the same colour lighter or darker. They are generated from the anchors, not picked by eye.

The neutral ramp is anchored on the **paper hue** (chroma 0.03), not on the mid neutral (chroma 0.18). Anchoring on the mid neutral instead holds that higher chroma across the ramp and turns the light end visibly peach — measured: `#F9E3CC` against the intended `#F5F2ED`. That mistake is why the neutral's top stops sit where they do.

**Stops that are never used.** The 50–300 accent stops are defined so hover, pressed and tinted states have somewhere real to go, and no screen cites 800–950: nothing in the product is a deep accent field. They are declared because a token family with no dark end cannot render a pressed state honestly.

### 1.2 Typography

Two scales. Mixing them would be the generic outcome — one ramp doing both jobs.

**UI scale** — base **16px**, ratio **1.25** (major third): 16 → 20 → 25 → 31.25 → 39.06. **The top step is deliberately capped**: 39px is the modular next step and is *not* used, because a 39px page title on a 360dp phone costs a whole row for four words.

| Token | Size / line | Weight | Ratio to previous | Usage |
|---|---|---|---|---|
| `--text-h1` | 31 / 38 | 700 | 1.25 | Screen title |
| `--text-h2` | 25 / 32 | 700 | 1.25 | Section title |
| `--text-h3` | 20 / 26 | 600 | 1.20 | Card title, novel title in the library |
| `--text-h4` | 18 / 24 | 600 | 1.13 | List-row title |
| `--text-body` | 16 / 24 | 400 | — | Body. **Never below 16px on mobile** (`design-quality.md` § 3). |
| `--text-body-sm` | 14 / 20 | 400 | 1.14 | Secondary body, dialog text |
| `--text-caption` | 12 / 16 | 400 | 1.17 | Chapter number, timestamp |
| `--text-overline` | 11 / 16 | 600, `letter-spacing 0.08em` | 1.09 | Section label, filter chip, tab label |

**Reader scale** — prose only, never used in chrome. Sizes are the ladder B27 exposes to the reader; the default is `md`.

| Token | Size / line | Measure | Usage |
|---|---|---|---|
| `--reader-sm` | 16 / 27 | 65–75 chars | Smallest reading size |
| `--reader-md` | **18 / 31** | 65–75 chars | **Default** |
| `--reader-lg` | 20 / 34 | 65–75 chars | |
| `--reader-xl` | 23 / 39 | 65–75 chars | |
| `--reader-xxl` | 26 / 44 | 65–75 chars | Largest reading size |

Line-height is **1.72** at every step, held constant on purpose: scaling line-height with size would break the reading rhythm between steps, and a rhythm that changes when the reader changes the size is a rhythm they cannot get used to. The **measure is capped** independently of screen width: on a 360dp phone at `xxl` the column would run to ~95 characters, which is unreadable, so the reader column is `max-width` constrained and centred rather than stretched.

**Families.** UI: the platform sans (Roboto on Android) — no bundling. Prose: serif preference chain `Noto Serif` → `Roboto Slab` → platform serif, with the platform sans as the guaranteed fallback so a missing family degrades to plain readable text rather than to tofu.

### 1.3 Spacing

Base **4dp**. Not uniform across a screen — § 3 of `design-quality.md` forbids uniform page spacing, and the rule is enforced in the screen files: a group is closed by a *larger* gap to the next group than the gaps inside it.

| Token | Value | Usage |
|---|---|---|
| `--space-2xs` | 2dp | Badge inset |
| `--space-xs` | 4dp | Inside a chip |
| `--space-sm` | 8dp | Gap inside a group |
| `--space-md` | 12dp | Standard gap, list row padding |
| `--space-lg` | 16dp | Between groups |
| `--space-xl` | 24dp | Section break |
| `--space-2xl` | 32dp | Major section break |
| `--space-3xl` | 48dp | Page top margin, empty-state block |

### 1.4 Shadows

**Two shadows exist, for two genuinely floating things.** `design-quality.md` § 3 forbids the shadow as default separator: on a flat surface, separation is `--color-border`, a background step, or space.

| Token | Value | Usage |
|---|---|---|
| `--shadow-none` | none | Default. Every row, card and surface in the app. |
| `--shadow-sheet` | `0 8 24 rgba(0,0,0,0.18)` | Bottom sheet, and the reader's revealed control bar — they float over content |
| `--shadow-dialog` | `0 16 48 rgba(0,0,0,0.24)` | Modal dialog only |

In night theme the shadows are unchanged: on a `#121315` field a dark shadow is nearly invisible, so elevation there is carried by the `--color-surface-raised` step instead. That is a deliberate exception to "one rule everywhere" and it is why night has a raised surface at all.

### 1.5 Borders

| Token | Value | Usage |
|---|---|---|
| `--radius-none` | 0dp | Reader prose column, full-bleed rows |
| `--radius-sm` | 4dp | Chips, small badges |
| `--radius-md` | 8dp | Text fields, buttons |
| `--radius-lg` | 16dp | Sheets, cards, dialogs |
| `--radius-full` | 999dp | Pills, the unread count dot |
| `--border-width` | 1dp | All rules and field outlines |
| `--border-width-strong` | 2dp | Selected row, focused field |

### 1.6 Motion

Named, not "a nice transition".

| Token | Value | Usage |
|---|---|---|
| `--duration-fast` | 120ms | Press feedback, chip select |
| `--duration-normal` | 200ms | Screen push, sheet slide-in |
| `--duration-slow` | 320ms | Reader chrome reveal, scroll restore |
| `--ease-standard` | `cubic-bezier(0.2, 0, 0, 1)` | General |
| `--ease-decelerate` | `cubic-bezier(0, 0, 0, 1)` | Entering |
| `--ease-accelerate` | `cubic-bezier(0.3, 0, 1, 1)` | Leaving |

**Reduce-motion.** Every duration becomes `0ms` under the OS reduce-motion setting, and the reader's chrome reveal becomes an instant show. A reading app that animates a restore the reader did not ask for is worse than one that does not animate it at all.

### 1.7 Breakpoints

| Token | Range | v1 layout policy |
|---|---|---|
| `--bp-mobile` | `< 600dp` | **The only layout v1 ships.** Single column, `--bp-mobile` is the design target. |
| `--bp-tablet` | `600–1023dp` | Single column, **capped and centred** — `--reader-md` measure, nothing wider. Explicitly not a tablet layout (**ADR-019**). |
| `--bp-desktop` | `1024–1439dp` | Same single column, centred. Flutter desktop is out of scope. |
| `--bp-wide` | `≥ 1440dp` | Same single column, centred. |

**This is not a tablet layout and must not be built as one.** The owner excluded it (**ADR-019**, a platform decision — *not* **ADR-010**, which is a legal-posture decision about sharing, export and backup). The policy above is what "adapts" instead: past 600dp the layout stops growing and centres. `13-error-handling` and `09-widgets-ui` both forbid widening the reader column past the measure, because the failure mode is a 1400dp line of prose.

**Touch target**: **48dp minimum** on every tappable element, including the reader's tap zones and list-row chevrons.

### 1.8 Mapping to Flutter

This is a Flutter app, so `--color-*` names are a **specification vocabulary, not CSS**. The code shape is:

| Design token | Flutter |
|---|---|
| The colour tables in § 1.1 | One `LumenColors extends ThemeExtension<LumenColors>` with the same property names, registered on both `ThemeData`s |
| `--reader-*`, `--text-*` | `TextTheme` (Material 3 slots: `bodyLarge`, `titleMedium`, `labelSmall`, …) plus one `readerProse` style |
| `--space-*` | 4dp base; a `LumenSpacing` extension or literal constants |
| `--radius-*` | `BorderRadius` |
| `--shadow-*` | `BoxShadow` in `cardTheme`/`bottomSheetTheme` |
| `--duration-*`, `--ease-*` | `Duration` + `Curve` |
| `--bp-*` | `MediaQuery` breakpoints; the ≥600dp rule is "cap and centre" |

Material 3 primitives throughout (`09-widgets-ui.md` §Conventions). ShadCN was dropped as contamination from another project — **ADR-001**.

---

## 2. Primitive components

Every component below declares its variants, sizes, **all** states and its slots. Screens must not invent a component; if one is missing it is added here first, so the same component cannot have two renderings (checked at the gate by `design-check component-parity`).

### 2.1 `NovelRow`

**Role**: one novel in the library, in search results, or in a source's catalogue.

**Variants**

| Variant | Appearance | Usage |
|---|---|---|
| `library` | 72dp, 48dp cover, title + author + 2-line status | Library list |
| `result` | 64dp, 40dp cover, title + author, no status | Browse results |
| `compact` | 56dp, 32dp cover, title only | "Continue reading" shelf |
| `history` | 56dp, no cover, title + chapter + relative time | History list |

**Sizes**: sm / md / lg map to the four variants above; there is no independent size axis.

**États** — every state this component must render:

| État | Trigger | Appearance |
|---|---|---|
| `default` | — | `--color-surface`, no rule |
| `pressed` | finger down | `--color-surface-sunken` |
| `selected` | multi-select active | `--color-border-strong` 2dp on the leading edge, `--color-accent` 10% fill |
| `focused` | keyboard / D-pad | `--color-border-focus` 2dp ring |
| `loading` | cover still fetching | `--color-surface-sunken` placeholder block, **no spinner** — a spinner per row in a 40-row list is noise |
| `offline` | cover absent and unreachable | `--color-surface-sunken` with the initials of the title, `--color-text-disabled` |
| `error` | source broke (B22) | Row still renders; the status line carries `--color-error` **and** an icon **and** wording — never colour alone |

**Slots** — what this row can carry:

| Slot | Required | Content |
|---|---|---|
| `cover` | no | Cover image, or a `--color-surface-sunken` block with title initials |
| `title` | yes | Novel title, `--text-h4`, max 2 lines |
| `subtitle` | no | Author, `--text-body-sm`, `--color-text-secondary`, 1 line |
| `status` | no | Unread count / download state / last-read — see B48, B49 |
| `unreadBadge` | no | `--radius-full` pill, `--color-accent` fill, `--color-text-inverse` label |
| `trailing` | no | Chevron, or the download progress bar |
| `progress` | no | 2dp determinate line under the title while a download runs — **not** a slot on `ChapterListTile` alone; B18 needs the same signal in both places |

**Deliberately absent**: no shadow, no rounded card wrapper. A library row is a row. The cover is the only thing with a radius.

### 2.2 `ChapterListTile`

**Role**: one chapter in a novel's chapter list, and one chapter in the reader's chapter sheet.

**Variants**: `list` (56dp, in novel details) · `sheet` (64dp, drag handle, in the reader) · `current` (the `list` variant with a 3dp `--color-accent` leading edge marking the reading position).

**États**: default · `pressed` · `read` (title `--color-text-secondary`, and **not** struck through — a strike on 300 chapters is a wall of lines) · `current` · `downloading` (`--shadow-none` row with a 2dp determinate progress line under the title, `--color-accent`) · `failed` (`--color-error` icon + wording + retry) · `offline-and-absent` (row present, tap opens the fetch, labelled as not downloaded).

**Slots**: `number` (`--text-caption`, tabular) · `title` · `stateIcon` · `progress` · `trailing`.

### 2.3 `PrimaryButton` / `SecondaryButton` / `TextButton`

**Variants**

| Variant | Appearance | Usage |
|---|---|---|
| `primary` | `--color-accent` fill, `--color-text-inverse` label | The one action a screen is for |
| `secondary` | transparent, `--color-border-field` 1dp outline | A second action |
| `danger` | `--color-error` fill, `--color-text-inverse` label | Destructive, with a confirm dialog |
| `ghost` | no fill, no outline, `--color-accent` label | Tertiary, in-app bar |

**Sizes**: sm 32dp / **md 44dp (default)** / lg 52dp. Width is intrinsic below 360dp and full-width for a form's primary action.

**États** — every state this component must render:

| State | Appearance |
|---|---|
| `default` | as per variant |
| `pressed` | `--color-accent-600` day / `--color-accent-300` night |
| `focused` | 2dp `--color-border-focus` ring, 2dp offset |
| `disabled` | `--color-text-disabled` label on `--color-surface-sunken`; **still 48dp tall** so the row does not jump |
| `loading` | 16dp spinner centred, label hidden, width locked to prevent reflow |

**Slots**: `iconLeft` (optional) · `label` (required) · `trailing` (optional).

### 2.4 `TextField`

**États**: default (`--color-border-field` 1dp) · `focused` (2dp `--color-border-focus`) · `error` (`--color-error` 1dp **plus** a message below at `--text-body-sm` — never the border alone) · `disabled` · `read`-only (`--color-surface-sunken` fill, no border) · `filled`.

**Slots**: `label` · `placeholder` (never empty micro-copy — a real example, e.g. "Titre du roman") · `prefixIcon` · `suffix` · `helperText` · `errorText`.

**Height 56dp.** Minimum 48dp touch target with 8dp of internal padding.

### 2.5 `StatusChip`

**Role**: the small state label on a novel row and a chapter tile. This is the component that carries B48 and B49 — the counts the app keeps about itself.

**Variants**: `new` (accent) · `downloaded` (success) · `downloading` (accent + determinate bar) · `failed` (error) · `never-checked` (info, wording only) · `local` (neutral).

**États** — every state this component must render: `default` · `pressed` (chips in filters) · `selected` (`--color-accent` fill, `--color-text-inverse`) · `unselected` (outline, `--color-text-secondary`).

**Slots**: `icon` (always paired with colour — `design-quality.md` § 3 forbids colour carrying meaning alone) · `label` · `count`.

### 2.6 `ReaderControls`

**Role**: the chrome that appears when the reader is tapped. Not a toolbar — it is a control cluster that hides entirely.

**Slots**: `progressSlider` (chapter + within-chapter, draggable, `--color-accent`) · `chapterTitle` · `sizeButton` · `themeButton` (day/night/system — one tap, per § 0 anti-references) · `chapterListButton` · `backButton`.

**États** — every state this component must render: `hidden` (default — the reading surface) · `revealed` (fades in over `--duration-slow`) · `dragging`.

**v1 constraint (ADR-009)**: continuous scroll only. There is no mode-switch button, because there is only one mode. A disabled control would be a promise about v2, and this design does not make promises it has not kept.

### 2.7 `EmptyState`, `ErrorState`, `LoadingState`

**`EmptyState`**: a sentence and one action. **No illustration, no icon in a circle** (anti-references). Title `--text-h3`, body `--text-body-sm` in `--color-text-secondary`, one `primary` button. Three named instances, each with real copy: `library-empty`, `search-unsupported` (per B50 — explains that this site has no search and offers genres instead), `no-chapters`.

**`ErrorState`**: `--color-error` icon, a sentence naming **what failed and what still works**, and a `secondary` retry. It must never read as "no results" — that distinction is B22 and it is the whole point of the component. A broken source and an empty category look nothing alike.

**`LoadingState`**: a skeleton at the shape of the content it replaces (a cover block plus two text lines), never a centred spinner for a list. `--duration-normal` shimmer, disabled entirely under reduce-motion.

### 2.8 `AppScaffold`

**Slots**: `titleBar` · `content` · `floatingAction` · `bottomNav` (main destinations only) · `persistentStatus` (download progress — see § 3.2) · `readerChrome` (reserved; the reader sets it instead of `titleBar`).

**États** — every state this component must render:

| État | Declencheur | Apparence |
|---|---|---|
| `default` | a normal screen | `titleBar` + `content` + `bottomNav` |
| `immersive` | the reader | `readerChrome` instead of `titleBar` and `bottomNav`; the reader sets both |
| `busy` | a download is running | `persistentStatus` appears above `bottomNav`, `--color-accent` determinate line |

**Rule**: a screen sets `titleBar` **or** `readerChrome`, never both.

### 2.9 `Switch`

**Role**: a binary setting that takes effect immediately and needs no Save. Used only for settings that persist on change — **never** for anything inside a form that has a submit action.

**Variantes**

| Variant | Appearance | Usage |
|---|---|---|
| `setting` | Material 3 switch, track `--color-surface-sunken` off / `--color-accent` on, thumb `--color-surface-raised` | A settings row. Its row also carries a title and a one-line consequence |
| `inline` | same control, smaller, with its label immediately beside it | Inside a sheet or a dialog, where there is no row to host it |

**Tailles**: md 48×32dp track (the only size). A settings switch that grows is a settings switch that no longer fits a row.

**États** — every state this component must render:

| État | Declencheur | Apparence |
|---|---|---|
| `default` | — | Track off `--color-surface-sunken`, thumb `--color-surface-raised`; on `--color-accent` |
| `pressed` | finger down | Track darkens one step; thumb grows 2dp |
| `focused` | keyboard / D-pad | 2dp `--color-border-focus` ring, 2dp offset |
| `disabled` | the setting is unavailable here | `--color-text-disabled` label; thumb `--color-border` |
| `loading` | **deliberately absent** | A switch has no in-between state — see below |
| `failed` | the write to storage failed | The row turns `--color-error` and shows the failure **beside** the switch, never by tinting the switch itself |

**Slots**

| Slot | Required | Content |
|---|---|---|
| `label` | yes | What the switch controls |
| `consequence` | no | One line saying what ON actually does — mandatory for the four settings where the effect is not obvious |

**Why there is no `loading` state**, which is the component's whole design decision: a switch that shows a spinner is asking the reader to believe a write is in progress. Ours writes to `shared_preferences` synchronously and **fails loudly instead of pretending** — if the write throws, the switch snaps back and the row says so. A setting that cannot be saved is a bug the reader should see immediately, not a state to design around.

### 2.10 `SettingsRow`

**Role**: one line in a settings list. Declared here because **three separate screens had each defined their own** — which is precisely the failure this design system exists to prevent: the same row with two renderings, and no check that would catch it.

**Variantes**

| Variant | Appearance | Usage |
|---|---|---|
| `action` | Label left, value right-aligned, **no chevron** | A setting changed in place. The absence of a chevron is the information |
| `navigate` | Label left, value right, chevron `--color-text-disabled` at the far right | The row cannot show the whole answer; it goes somewhere |

**Tailles**: one size, 56dp row. A settings row with two heights is a settings list that cannot be scanned.

**États** — every state this component must render:

| État | Declencheur | Apparence |
|---|---|---|
| `default` | — | Label `--text-h4`, value `--text-body-sm`, `--color-text-secondary` |
| `pressed` | finger down | Row fills `--color-surface-sunken` |
| `focused` | keyboard / D-pad | 2dp `--color-border-focus` ring |
| `disabled` | the setting is unavailable here | Label `--color-text-disabled`, value hidden, **chevron still shown** — a row that hides its chevron when disabled implies there is nothing there |

**Slots**

| Slot | Required | Content |
|---|---|---|
| `label` | yes | What the setting is |
| `value` | no | Current state, right-aligned, max 1 line |
| `consequence` | no | One line under the row. **Mandatory on every switch row** — see `Switch` § 2.9 |
| `chevron` | no | Present iff variant is `navigate` |

### 2.11 `SettingsSwitchRow`

`SettingsRow` (variant `action`) hosting a `Switch`, with `consequence` **required**. It exists as its own entry because the mandatory `consequence` is the whole point: a switch whose effect is not obvious is a switch the reader has to guess about, and **an "off by default" is meaningless if the reader cannot see what turning it on would do**.

### 2.12 `SettingsChoiceSheet`

**Role**: the single-value picker for a `navigate` row — theme (3 values), text size (5 values), history retention (5 values). **Not language**: B28 forbids an in-app language switch, because the platform already owns that value and a second source of truth for it is a bug waiting to happen. One component for all of them, so every choice in the app is made the same way.

**États** — every state this component must render:

| État | Declencheur | Apparence |
|---|---|---|
| `default` | open | Rows of label + checkmark; the current value checked |
| `pressed` | finger down on a row | `--color-surface-sunken` |
| `focused` | keyboard | 2dp `--color-border-focus` ring; arrow keys move, `Enter` selects |
| `disabled` | a value is unavailable | Label `--color-text-disabled`, not selectable |

**Slots**: `title` · `value` · `rows` (label + optional description) · `selectedValue`.

**No "forever" option on any bounded list.** B47 requires the history to be bounded by time, and a settings list that offers an unbounded value next to bounded ones teaches the reader the bounds are negotiable.

**Why every setting switch carries a `consequence` line.** The general rule: a switch whose effect is **destructive, invisible, or surprising when wrong** must say in words what the position means. Two worked examples earned it. *Checking for new chapters* was the original (**B35**, now withdrawn — ADR-023). *Remove after reading* earned it and was then **cut**, because **B32**/**B33** make deletion per-chapter and explicit, so the switch was asserting an effect the rules did not permit. **Both are gone, and `SettingsSwitchRow` therefore has ZERO instances in v1.** It stays declared — components are specified ahead of use, and deleting a primitive because today's screens do not need it is how a design system loses its vocabulary — but the honest status is *declared, unused*, not *in use*. **It returns whole** with the first v2 setting that needs it; the B35 restoration in `prd.md` § 9 is one candidate. *History retention* (**B47**, one year), and *theme* (**B26**). A switch with a label but no consequence is a switch the reader has to guess about, and B35's "off by default" is meaningless if the reader cannot see what turning it on would do. The reader has no title bar at all — its title lives in the revealed controls, so the first thing on screen when a chapter opens is prose.

---

## 3. Navigation patterns

### 3.1 Structure

Bottom navigation, 5 destinations. Single column throughout. No drawer: a drawer would hide the destinations that carry the loop.

### 3.2 Main navigation

> The order of navigation entries **is a statement of priority**. It follows the frequency of the work loop, not the org chart of the domain. `references/module-prioritization.md` — this section is not optional.

- **Type**: bottom nav
- **Responsive behaviour**: ≥600dp the bar stays at the bottom and stays 5 items. It does not become a rail. **ADR-019**, not **ADR-010**: tablet exclusion is a platform decision, and ADR-010 is about sharing, export and backup. **Corrected 2026-10-02** — a 42-citation sweep rewrote `not ADR-010` into `not ADR-019`, producing a sentence that named the same ADR on both sides of a contrast. A blanket string replacement cannot see the word *not*.
- **Plateau**: 5 items. The rest is overflow.

| Rank | Module | Label (EN / FR) | Freq. | Centrality | Why here and not elsewhere |
|---|---|---|---|---|---|
| 1 | Library | Library / Bibliothèque | 5 | 5 | **Opens the loop.** A returning reader's most frequent action is resuming, not discovering. Frequency 5, not by default: it is the screen that answers "what do I have, and where was I". |
| 2 | Updates | Updates / Mises à jour | 4 | 4 | "Did my serialised novels move?" — the new-before-past rule. Second because a serial novel generates the app's only pull-loop, **and the pull-loop is a destination the reader returns to, not a notification that brings them back**. ADR-020 originally justified this rank by *"the pull is what brings the reader back"*, which argued for a mechanism the plan does not build; ADR-023 then removed the schedule behind it. |
| 3 | History | History / Historique | 4 | 2 | "What did I read?" — also a resume surface, but *past* tense, so below Updates. Centrality 2: history is a record, not a destination the reader builds. |
| 4 | Browse | Browse / Parcourir | 3 | 3 | The only way to add a novel. Centrality 3, frequency 3 — genuinely several-times-a-week, but not daily, and not the reason the app is opened. |
| 5 | More | More / Plus | 2 | 1 | Lifecycle and configuration. Lowest frequency **by design**: everything here is a setting or a transfer, and none of it is part of the reading loop. |

**Why Library is first, argued rather than assumed.** The rule exists precisely because "the home screen first" is a default that survives unexamined. Three reasons, in order of weight:

1. It has the highest frequency — a reader opens the app to resume, and resume means their own shelf.
2. It is the only screen that can **open the loop** rather than summarise it. `archetypes.md` § 2 names the trap precisely: *"écran d'accueil qui est un sommaire"*. So the Library is **not** a list of covers with chapter counts. It leads with a **continue-reading shelf** — the last read novel, at its position — and the list is below it. A library that is only a list has put a summary where a home should be.
3. It is the screen the app must open *from* after a download completes — so it is where the loop re-enters. **Not** after a new-chapter notification: v1 has none, because there is no automatic check to announce the result of — no schedule (B35 withdrawn, ADR-023) and no new-chapter notification (ADR-020, superseded).

**Overflow (« More »)** — everything here is configuration or a transfer, never part of the reading loop:

| Module | Label (EN / FR) | Why in overflow |
|---|---|---|
| Downloads | Downloads / Téléchargements | A *state* of library novels, not a place to browse. Progress is surfaced in three better places: the library row, the novel detail screen, and a persistent status bar. Its own screen exists for the queue and the failed-items list. |
| Sources | Sources / Sources | Configuration of what exists. Per ADR-013 there is a static registry — no install flow — so this is a list and a toggle, opened rarely. |
| Stats | Stats / Statistiques | Mihon has it; we keep it because it is cheap once history exists. Read-only, curiosity, never a target. **No gamification framing** (anti-references). |
| Settings | Settings / Paramètres | Configuration. |
| Onboarding | — | A first-run flow, reachable from Settings, never in the nav. |

**Status of the nav in `state.json`**: recorded via `state.js set-nav`, not written by hand.

### 3.3 Breadcrumbs

- **Visibility**: never. This is a phone app with a back stack, not a web hierarchy. A breadcrumb that duplicates the back button costs a row and teaches nothing.
- **Sub-screens keep their parent's context in the title bar**, so "which novel am I in?" never needs a trail.

### 3.4 Transitions

- **Type**: horizontal slide for lateral navigation (push/pop); vertical slide for sheets; fade for dialogs.
- **Duration**: `--duration-normal` (200ms), `--ease-standard`.
- **Reader**: **no transition in.** Opening a chapter does not slide — the text is simply there. A slide would make the reader wait, on the one screen where waiting is the whole cost. The scroll position is restored at `--duration-slow` only if the reader has scrolled away and returns; otherwise it is restored without animating, because an animated restore makes the reader think the position changed.

### 3.5 Routing

`go_router` shell routes (ADR-008), one `StatefulShellRoute` per bottom-nav destination so each tab keeps its own scroll position and back stack.

**Fifteen routes, and this table is reconciled against the eighteen screen files** — every route a screen pushes appears here, and every route here is pushed by a screen. That reconciliation is not free: it was checked on 2026-10-02 and it found four discrepancies, all of which had been sitting here as "verified":

| Discrepancy | Resolution |
|---|---|
| `/library/novel/:novelId/chapter/:chapterId` appeared here and in **no** screen file | **Removed.** Every screen that opens a chapter pushes `/reader/:novelId/:chapterId` — 3 call sites, 0 for the other form. Two URLs for one destination is a route table with two truths |
| `/browse/:sourceId/unavailable` pushed by `source-unavailable.md`, absent here | **Added** |
| `/more/settings/reader` and `/more/settings/about` pushed by `settings-reader.md` and `settings-about.md`, absent here | **Added** — they are sub-routes of `/more/settings`, reached from `settings.md`'s rows |
| `/more/sources` and `/more/stats` were here with no slice behind them | **Removed** 2026-10-02 with slices `6-9` and `6-8`; the screens are designed and return in v2 |

/library                        /library/novel/:novelId
/updates          /history
/browse           /browse/:sourceId    /browse/:sourceId/genre/:genre
                  /browse/:sourceId/unavailable
/more             /more/downloads      /more/settings
                  /more/settings/reader    /more/settings/about
/reader/:novelId/:chapterId     (outside the shell — no tab bar)
/onboarding                      (outside the shell)
```

---

## 4. Grid and layout

### 4.1 Base grid

Single column, `--space-lg` (16dp) horizontal margin, `--space-3xl` (48dp) top margin. List rows are full-bleed with internal `--space-md` padding. **No 12-column grid**: there is no layout on screen that needs one, and drawing it would be scaffolding for a case that does not exist.

### 4.2 Layouts

| Layout | Structure | Usage |
|---|---|---|
| List page | title bar, full-bleed rows, bottom nav | Library, Updates, History |
| Detail page | collapsing cover header, metadata block, action row, chapter list | Novel details |
| Reader | prose column, no title bar, chrome on tap | Reader |
| Result grid | 2 columns, 96dp cells, `--space-md` gap | Browse and search results. **The column count does not change with width** — see below |

> **Why the result grid does not gain columns.** An earlier draft of this table said *2 columns below 600dp, 3 at `--bp-desktop`*, which is a tablet layout, and **ADR-019** excludes those. A grid that changes its column count with width is also the grid that makes the reader hunt: the same novel sits in a different place on a tablet. Two columns everywhere keeps a result list learnable, and on a wide screen it centres rather than spreading.
| Settings | grouped rows with section labels, no icons | Settings and its sub-screens |
| Sheet | handle, title, content, actions | Chapter list, filters, sort, reader options |

---

## Gate checklist

Cf. `references/design-quality.md`.

**Direction**
- [x] The three anchors are written, before any screen: references, ambiance, anti-references (§ 0).
- [x] Archetype identified as `mobile_consumer` and justified (§ 0).
- [x] Density chosen consciously and justified per surface (§ 0).
- [x] **A design skill was required and is absent** — `imagegen-frontend-mobile` is not installed. § 3 interdicts applied in full, § 4 requirements met, and the absence is declared here and in the phase audit (§ 0).
- [x] Three contestable choices argued for, not merely made (§ 0).

**Tokens**
- [x] Every token has a concrete value; no "to be defined" anywhere.
- [x] **No unresolved template placeholder anywhere in this file** — `forge-guard placeholders` reports none.
      > **Reworded 2026-10-02, and the guard is the reason.** This line used to *quote* the literal placeholder token in order to assert that none remained, and `no_unresolved_placeholders` duly reported **this very line**. A checklist that asserts the absence of a string while containing it is not a subtle failure — it is a claim the tool cannot distinguish from an instance, and it had been sitting green because nobody ran the check against the file that made the claim. **Every 'no TODO' / 'no placeholder' checklist line ever written has this shape**, and the honest phrasing is to describe the condition without reproducing the token.
- [x] Palette covers default, pressed, focused, disabled, error, success, warning, info.
- [x] Not a default palette: no `#3B82F6`, `#6B7280`, `#EF4444`, `#10B981`. Accent is `#8A4B12` / `#E3A857`.
- [x] Background is `#F5F2ED` / `#121315` — **not** `#FFFFFF`.
- [x] Type scale has real, stated ratios: 1.25 major third, top step capped and the cap explained.
- [x] Every colour token is declared in § 0.0, with the exempt one's reason given.
- [x] All contrast measured and recorded per theme, not asserted. Semantic colours are per-theme because a single value cannot serve both (`error` is 7.32:1 on paper and 2.27:1 on night).

**Components**
- [x] Primitives cover the product's surface: rows, chapter tiles, buttons, fields, chips, reader controls, empty/error/loading, scaffold.
- [x] Every component declares all states, including the ones that are easy to forget (`pressed`, `offline`, `failed`).
- [x] Shadow is not the default separator: two shadows, for two floating things only.

**Navigation**
- [x] Navigation defined for phone, and the ≥600dp policy stated as *cap and centre*, not a tablet layout.
- [x] Order justified by frequency, with a score and a reason per item.
- [x] Five main items; the rest in overflow with a reason each.
- [x] Library is first **for a stated reason**, and is required to open the loop rather than summarise it.
- [x] Order recorded via `state.js set-nav`.

**Layout**
- [x] Grid and layouts cover every case in the PRD. No 12-column grid, and the absence is justified.
- [x] Motion named with durations and easings, plus a reduce-motion policy.
- [x] Flutter mapping given (§ 1.8) so the spec is not mistaken for CSS.

**Status**: `draft` — awaiting validation.