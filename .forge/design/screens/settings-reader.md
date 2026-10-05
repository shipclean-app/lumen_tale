---
type: screen
slug: settings-reader
title: Reader settings
module: more
status: approved
generated_at: 2026-10-02
derived_from:
  - .forge/prd.md
  - .forge/design/design-system.md
rule_ids:
  - B25
  - B26
  - B27
  - B28
  - B44
  - B46
edge_case_ids:
  - E12
  - E13
  - E14
  - E22
flow: settings-flow
---

# Screen — Reader settings

> The source of truth for generating this screen. It is the **deep configuration of the reader**: the two values the reader's own tap-revealed controls already change in one tap, changed deliberately here with the result visible. One screen, not a sheet — the preview needs room, and a sheet over a settings page gives it none.

---

## 1. Role of the screen

| | |
|---|---|
| **App archetype** | `mobile_consumer` |
| **Module** | `more` — **rank 5 of 5**; this is a sub-sub-page of More, two levels below the bottom nav |
| **Route** | `/more/settings/reader` |
| **Type** | full page with a title bar, pushed inside the More shell |
| **Users** | the reader, in bed or in transit — the conditions under which they will actually change the size |
| **User stories served** | US-14, US-15 |
| **Business rules** | B25 B26 B27 B28 B44 B46 |
| **Edge cases** | E12 E13 E14 E22 |

**In one sentence**: this screen lets the reader choose how large the prose is and whether the app is dark, **with a real specimen of the result on the page while they choose**, so that the choice is made against the thing it changes rather than against a label.

**Why it sits two levels below the nav**: the reader who wants this has, almost always, wanted it *in the last chapter*. That path is one tap in `ReaderControls`. This page exists for the second kind of reader — the one who knows their text wants to be 23px and does not want to find that out at 2am inside a chapter. It is deliberately not promoted into the bottom nav: a text-size control is not a destination, and `design-system.md` § 3.2 holds the nav to five entries for exactly the reason that it would be a seventh place to go looking for something you already read.

---

## 2. Visual direction for this screen

| | |
|---|---|
| **Mood** | quiet, typographic, unhurried |
| **Density** | **airy, and not by choice** — justified: the majority of this screen is a type specimen, and a specimen surrounded by chrome measures the wrong thing. The controls themselves are compact; the specimen is given the rest of the page. |
| **Contrast level** | **high, in the specimen** — `--color-text-primary` `#1A1714` / `#E8E4DD` on `--color-surface-sunken` `#EBE7E0` / `#0C0D0F` measures **14.48:1** / **12.00:1**, the highest pair in the app. The chrome above it is ordinary body contrast |
| **Surface** | The chrome sits on `--color-background` `#F5F2ED` / `#121315`. The **specimen is `--color-surface-sunken`** — recessed, and the *same* field the reader uses. It is not a card and it is not `--color-surface`: a preview drawn on a different surface from the reader is a preview of nothing |
| **Accent used** | `--color-accent` `#8A4B12` / `#E3A857` — **only** on: the selected step of the size ladder, the selected segment of the theme control, and the focus ring. It appears nowhere in the specimen. An accent running through the specimen is a stripe the eye crosses on every line the reader is trying to judge |
| **Photographic treatment** | **none.** The specimen is **prose the app already holds**, in the reader's own serif. There is no screenshot, no rendered mock-up, no illustration of a phone. |
| **Reference** | a letterpress specimen sheet — a page where the type *is* the content and the furniture is set in the sans and stays out of the way. |

### 2.1 Anti-generic — mandatory

This screen must not resemble any of these defects:

- [x] **No pure white `#FFFFFF` background** — `--color-background` `#F5F2ED` / `#121315`, and the specimen on `--color-surface-sunken` `#EBE7E0` / `#0C0D0F`, neither of which is white.
- [x] **No shadowed card.** The specimen is a **recessed well**, not a raised card: no fill of its own, no shadow, no border, no radius on the column itself. This is the reader's own idiom — `reader.md` § 2.1 makes the same argument for the same surface — and a floating "preview card" is the standard way this screen gets built badly, because a card looks like a thing you can pick up rather than a thing you read.
- [x] **Not uniform.** Three scales are in play at once: `--text-overline` 11/16 for the two group labels, `--text-body` 16/24 for the step labels, and the reader scale at the selected step — 16/27 through 26/44. The specimen's size is the hierarchy; nothing else competes with it.
- [x] **No generic grey `#6B7280`** — secondary text is `--color-text-secondary`, the paper-anchored ramp.
- [x] **No symmetric centring as the layout.** The specimen is **left-aligned inside a centred measure**, capped at 65–75 characters and no wider, exactly as in the reader. Centring the prose would be the generic choice and would break ragged-right scanning — which is half of what the reader is here to judge.
- [x] **No generic spot illustration.** This is the screen where a fake reader screenshot would be most tempting and most wrong. There is none: the specimen is real stored text through the real widget, or an app-authored stand-in.
- [x] **Not one typeface.** The specimen is the **serif preference chain** (`Noto Serif` → `Roboto Slab` → platform serif, with the platform sans as a guaranteed fallback — ADR-017); the chrome above it is the platform sans. Two families, deliberately, and the boundary between them is the boundary between *the thing being configured* and *the thing configuring it*.

**Assumed, non-neutral choice**: **the specimen is real prose from the reader's own storage, not sample text, and when there is nothing stored it shows a two-line app-authored stand-in instead of pretending.** This is the decision that separates this screen from every settings screen with a "preview" box. A preview built from lorem ipsum, or from a novel the app has never downloaded, shows the reader a typeface — which they can already see anywhere — instead of showing them **the reader they will have**. The specimen is rendered by the same widget the reader uses, seeded with the first stored paragraph the app has on disk, which means it is genuinely calibrated: the same measure cap, the same 1.72 line-height, the same Markdown conversion. If the app holds no chapter yet — a first-day reader, opening Settings before browsing anything — the stand-in is two lines of **the app's own** prose describing the gestures, typeset at the selected step. Not a novel quote, not "Chapter 1", not lorem ipsum: text the app owns, so it can never misrepresent a site's content, and it is never written to disk as a chapter, so B6 is not engaged by it.

**The second assumed choice, stated because it looks like duplication**: **this screen and the reader's own controls are two doors to one value, and the screen says so.** `reader.md` § 2 records that `ReaderControls` already carries a `sizeButton` and a `themeButton`. That is not a competing mechanism, and it is not left implicit: `readingScale` and `themeOverride` are each **one stored value**, written by whichever door the reader came through, read by both. The division is of *purpose*, not of storage. The reader's controls are for the reader who is mid-chapter at 2am and wants it different **now**; this screen is for the reader who wants to decide **before**, and who needs to see the result across a whole paragraph to make the call. If they were two values, one of the two would be wrong, and the reader would find out in the reader.

---

## 3. Anatomy

```
AppScaffold (titleBar "Reader settings", bottomNav kept)
└── ReaderSettingsBody
    ├── GroupLabel "TEXT SIZE"           --text-overline 600, 0.08em
    │   └── SizeLadder                   5 equal steps, one row
    │       ├── SizeStep "Small"         16pt
    │       ├── SizeStep "Medium"        18pt   ← default, --color-accent
    │       ├── SizeStep "Large"         20pt
    │       ├── SizeStep "Larger"        23pt
    │       └── SizeStep "Largest"       26pt
    ├── Specimen                         --color-surface-sunken, measure 65–75 chars,
    │   │                                 left-aligned, --reader-{step}, line-height 1.72
    │   └── SpecimenText                 real stored Markdown, or the app's stand-in
    │       └── SpecimenFootnote         --text-caption, --color-text-secondary
    ├── GroupLabel "THEME"
    │   └── ThemeSegments                3 segments, one row
    │       ├── "Follow the phone"
    │       ├── "Day"
    │       └── "Night"
    ├── GroupLabel "NOT IN THIS VERSION"
    │   └── DeferredList                 prose, --text-body-sm, --color-text-secondary,
    │       └── DeferredItem × 7           no icons, no checkboxes, no disabled controls
    └── --space-2xl
        └── (end of page — nothing below)
```

| # | Component | Role | Source |
|---|---|---|---|
| 1 | `AppScaffold` | Title bar + retained bottom nav | `design-system.md` § 2.8 |
| 2 | `SizeLadder` | One of the five `--reader-*` steps, selectable, with its pixel figure | slice-local — see § 10. **Named here by `design-system.md` § 2.12 as amended, which withdrew the text size from `SettingsChoiceSheet`**; the argument is § 11 |
| 3 | `Specimen` | The recessed, measure-capped prose column | `design-system.md` § 2.3 ("the reader's prose column is not a card") |
| 4 | `ThemeSegments` | Three single-select segments over `enum(system\|day\|night)` | slice-local wrapper over the platform segmented control (ADR-001). **Named here by `design-system.md` § 2.12 as amended, which withdrew the theme from `SettingsChoiceSheet`**; the argument is § 11 |
| 5 | `GroupLabel` | `--text-overline` section label | `design-system.md` § 1.2 |
| 6 | `DeferredList` | The list of things that are **absent**, written as prose | slice-local; deliberately not a component — it is text, and text has no states |

> **Not used**: `ReaderControls` is **not** rendered here, though this screen writes the values it owns. The chrome cluster only exists over a reading surface — rendering it on a settings page would give the reader two identical-looking things and blur the one distinction that separates them. `StatusChip` is not used either: a selected size is a control's own state, not a chip the app keeps about something.

---

## 4. States — all nine, no exceptions

| State | Trigger | Rendering | Reader feedback |
|---|---|---|---|
| **Loading** | The screen is open and the specimen is being seeded. `readingScale` and `themeOverride` are synchronous local reads and render immediately; the **specimen's seed paragraph is a disk read** | The specimen renders the **app-authored two-line stand-in at the selected step** for the moment it takes to read one file, then swaps to the stored paragraph **without any animation and without a layout jump** — `Specimen` carries `min-height` of three lines at the current step, so the stand-in and the real paragraph occupy the same box. **No spinner, ever**: a spinner inside a type specimen would tell the reader the *type* is loading, and the type is not | Nothing announces the swap. A specimen that flickers between two texts is worse than one that was simply already there |
| **Filled** | Normal case | The five steps, the specimen in the reader's serif at the selected step on `--color-surface-sunken`, the three theme segments, and the deferred list | Immediate. Selecting a step re-measures the specimen on the same frame — no fade, no transition, because a reader judging type needs to see it *be* the new size, not become it |
| **Empty — never visited** | The reader has never opened this screen, and has never opened a chapter either — first-day reader who went straight to Settings | **This is the empty case, and it has a rendering**: the specimen shows the **app-authored stand-in**, and beneath it a `--text-caption` `--color-text-secondary` line: *"You have not downloaded anything yet — this is what the reader will look like."* Nothing else changes. The five steps and three segments are fully live, because a reader may want to set their size before they have a chapter | The stand-in is honest about being a stand-in, in one short clause, and it does not block anything. It is not an `EmptyState`, because an empty state with a title and a CTA would imply there is nothing to do — and there is |
| **Empty — no data** | The library is empty *and* no stored Markdown exists anywhere on the device — indistinguishable in outcome from the row above, and deliberately rendered identically | Same as above. There is **no separate state**, and the reason is B6: a chapter is either wholly present or absent, so "the library is empty" and "this device has no chapter text" are the same fact, not two | One rendering for one fact. Two renderings of the same fact is how a reader concludes one of them is a different problem |
| **Load error** | A stored paragraph exists but cannot be read — the file is gone, unreadable, or not valid Markdown. The **setting** is fine; the seed is not | The specimen **keeps rendering at the selected step**, using the app stand-in, and one line below it carries `--color-warning` with words: *"A chapter saved on this phone could not be read. Showing a sample instead."* **Not `--color-error`**, and this distinction is deliberate: nothing failed that the reader asked for. The size and the theme are still exactly as configured, and the screen is still fully usable | Warning, not error, because the error would read as *the setting did not save*. It did. The sample is labelled as a sample |
| **Submit error** | The chosen step or segment cannot be persisted (storage full, preferences file unwritable) | The control **snaps back to the stored value over `--duration-fast` 120ms** and a snackbar on `--color-surface-raised` with `--shadow-sheet` names what failed and offers **Try again**. **The specimen re-renders at the stored step, not the tapped one.** The invariant: *the screen never shows a size or a theme it does not hold* | Same invariant as Settings, applied to type. A specimen showing 26pt when the app holds 16pt is a reader that will be 16pt when the chapter opens — and the reader will have chosen 26 |
| **Success** | n/a | **There is no success state, and there should not be.** Changing the size or the theme *is* its own success feedback: the specimen has already re-measured. A snackbar per step tap would fire five times in five taps, and a check-mark animation on a type specimen is decoration competing with the only thing the reader is looking at | The state **is** the feedback. Nothing to add to it |
| **Offline / permissions** | No connection, or any permission state | **Identical to Filled, with zero variation.** This screen makes **no network call at all** and requests **no permission**. Storage needs no runtime grant for the app's own directory, and `POST_NOTIFICATIONS` is requested at the moment the reader turns the update schedule on in Settings — which this screen does not own and does not mention | A permission prompt here would be a lie about what the reader needs in order to change their font size: nothing |
| **Read-only** | The specimen, and only the specimen | **The specimen is a type specimen, not a reader.** It has no tap zones, no progress slider, no chapter navigation, no scroll position, no stored position, and its text is **never written to disk as a chapter**. It is inert by construction, and it must stay inert: a specimen that responds to taps is indistinguishable from the reader at a glance, and the reader would tap it expecting a chapter | Nothing else on this screen is read-only — there is no condition under which a size or a theme becomes unselectable. The specimen is the whole read-only surface, and it is read-only because it is evidence, not because it is disabled |

### 4.1 User-visible copy — both languages (B28)

| Key | English | Français |
|---|---|---|
| `group.size` | `TEXT SIZE` | `TAILLE DU TEXTE` |
| `size.sm` | `Small` · `16pt` | `Petit` · `16 pt` |
| `size.md` | `Medium` · `18pt` | `Moyen` · `18 pt` |
| `size.lg` | `Large` · `20pt` | `Grand` · `20 pt` |
| `size.xl` | `Larger` · `23pt` | `Plus grand` · `23 pt` |
| `size.xxl` | `Largest` · `26pt` | `Le plus grand` · `26 pt` |
| `group.theme` | `THEME` | `THÈME` |
| `theme.system` | `Follow the phone` | `Suivre le téléphone` |
| `theme.day` | `Day` | `Jour` |
| `theme.night` | `Night` | `Nuit` |
| `specimen.credit` | `From "{novel}" · {chapter}` | `Extrait de « {roman} » · {chapitre}` |
| `specimen.empty.title` | *(no title — the stand-in stands alone)* | — |
| `specimen.empty.note` | `You have not downloaded anything yet — this is what the reader will look like.` | `Vous n'avez encore rien téléchargé : c'est ainsi que le lecteur se comportera.` |
| `specimen.seedFailed` | `A chapter saved on this phone could not be read. Showing a sample instead.` | `Un chapitre enregistré sur ce téléphone n'a pas pu être lu. Un exemple est affiché à la place.` |
| `group.deferred` | `NOT IN THIS VERSION` | `PAS DANS CETTE VERSION` |
| `deferred.modes` | `No reading modes — reading is one continuous scroll.` | `Pas de mode de lecture : la lecture est un défilement continu unique.` |
| `deferred.swipe` | `No swipe or tap page-turn.` | `Pas de changement de page par balayage ou toucher.` |
| `deferred.orientation` | `No orientation or rotation lock.` | `Pas de verrouillage d'orientation.` |
| `deferred.filters` | `No colour filters — sepia, greyscale, inverted.` | `Pas de filtres de couleur : sépia, niveaux de gris, inversé.` |
| `deferred.justification` | `No text justification. Justified prose at this measure creates rivers, and rivers are worse than a ragged edge.` | `Pas de justification du texte. Un texte justifié à cette longueur de ligne crée des rivières, bien pires qu'une bordure irrégulière.` |
| `deferred.paragraphSpacing` | `No paragraph spacing control — the 1.72 line-height already sets the rhythm.` | `Pas de réglage de l'espacement des paragraphes : l'interligne de 1,72 fixe déjà le rythme.` |
| `deferred.lineHeight` | `No line-height control. It is held at 1.72 at every size on purpose, so the rhythm does not change when the size does.` | `Pas de réglage d'interligne. Il est maintenu à 1,72 à toutes les tailles, volontairement, pour que le rythme ne change pas avec la taille.` |
| `deferred.fonts` | `No font picker — the reader uses a serif, decided once. A reading face you can choose is a v2 candidate, not a v1 control.` | `Pas de choix de police : le lecteur utilise un serif, décidé une fois. Une face de lecture au choix est une candidate pour la v2, pas un contrôle de la v1.` |
| `error.write` | `This could not be saved. Nothing was changed.` | `Cela n'a pas pu être enregistré. Rien n'a été modifié.` |
| `button.retry` | `Try again` | `Réessayer` |

> Two of the nine have no distinct rendering, and each says why: **Empty — no data** is the same fact as **Empty — never visited** (B6), and **Success** has no state because the specimen is itself the feedback. The page-level **Loading** exists only for the specimen's disk read and is rendered *inside* the specimen rather than as a skeleton over the page.

---

## 5. Interactions

| Element | Event | Behaviour | Visual feedback | Resulting state | Rule |
|---|---|---|---|---|---|
| Title-bar back / system back | tap / back | Pop to `/more/settings` | `--duration-normal` 200ms `--ease-standard` | Settings | — |
| `SizeStep` — one of the five | tap | Write `readingScale = {sm,md,lg,xl,xxl}` and **re-render the specimen at that step on the same frame** | Step fills `--color-accent`, label to `--color-text-inverse`; the specimen's type and its `min-height` both change immediately, **no animation** | Filled, new size | **B27** |
| — the same step while already selected | tap | **Nothing.** No write, no animation, no toast | The pressed state and nothing more | Filled | — |
| `ThemeSegments` — one of three | tap | Write `themeOverride = {system,day,night}` and re-theme **this screen and the specimen** | Segment fills `--color-accent`; the whole page re-themes **instantly**, with no cross-fade — the same rule the reader's `themeButton` follows | Filled, new theme | **B26** |
| — segment `Follow the phone` | tap | Write `system`; the page then follows the OS and re-themes on every OS change with no further action | As above; the segment's label gains *nothing* visual — the follow-system case has no on-screen state, and inventing one would be lying about a value the OS owns | Filled | **B26**, E13 |
| `Specimen` | scroll | **Scrolls with the page like any other content, and nothing else.** No tap zones, no chapter navigation, no position | — | Filled | B25 |
| `Specimen` — at `--reader-xxl` on a 360dp phone | layout | The measure **stays capped at 65–75 characters**. On a narrow screen the column *narrows*; it never widens past the measure and never produces a horizontal scrollbar | — | Filled | E14 |
| OS font-size change while this screen is open | system | The specimen re-renders immediately at `phoneScale × step`, the measure cap re-applies, and **nothing is lost** — there is no position on this screen to lose | Specimen re-measures with no animation | Filled | **E14** |
| OS light/dark change while this screen is open | system | The page re-themes immediately if the override is `system` | Instant, no cross-fade | Filled | **E13** |
| OS language change while this screen is open | system | Every label, step name, segment and the stand-in re-localise. The specimen's own text does **not**, and must not: it is content the app did not write (B44, and the reader's own § E19) | Instant | Filled | **B28**, E12 |
| `DeferredList` | — | **Not interactive.** It is prose, and it has no tap target, no ripple and no disabled control | — | Filled | ADR-009 |

- **Focus / keyboard**: focus order is the five steps, then the three segments, in reading order. Each step and each segment is **one focusable node** announcing its name, its pixel figure and whether it is selected — *"Large, 20 pixels, not selected"*. `Enter` / `Space` selects. The specimen is **not focusable and not exposed as a text node**: it is a type specimen, and a screen reader announcing a paragraph of app stand-in as document content would be a false reading of the screen. `Esc` returns to Settings. Focus is visible at 2dp `--color-border-focus` with a 2dp offset and is never removed.
- **Gestures**: vertical scroll only. **No swipe left/right on a step** — the ladder is one row, not a carousel, because a horizontal stepper hides two of its five options and this app has five.
- **Animations**: **none on the specimen**, which is the point: `--duration-normal` 200ms on push/pop, `--duration-fast` 120ms on segment and step selection feedback, `--duration-fast` 120ms `--ease-accelerate` on a failed-write snap-back. Every duration becomes `0ms` under reduce-motion.
- **Back**: pops to `/more/settings`, which re-reads `readingScale` and `themeOverride` and shows them in its `Reader appearance` value line — so the reader can confirm on the previous screen that their choice took. **The change does not retro-apply to a chapter they already have open**, because this screen is not reachable from the reader; it becomes visible the next time a chapter opens.

---

## 6. Responsive

| Breakpoint | Behaviour | What collapses or disappears |
|---|---|---|
| **Mobile** `< 600dp` | Single column, `--space-lg` 16dp margins. The five steps stay in **one row of five equal columns** — at `--space-2xs` 2dp gaps they each hold 62dp on a 360dp screen, above the 48dp touch minimum, and the step label wraps to two lines rather than truncating. The specimen is capped at the same 65–75 character measure as the reader | Nothing. This is the design target |
| **Tablet** `600–1023dp` | Identical single column, centred, **capped** — the specimen keeps its measure and does not widen to fill 800dp, and the step row keeps five equal columns at the phone's column widths rather than stretching | Nothing collapses — the layout simply stops widening |
| **Desktop** `1024–1439dp` | Same single column, centred, same cap. Flutter desktop is out of scope | — |

- **Touch target**: **48dp minimum on every step and every segment**, enforced by the step row's own height rather than by the control's. The five steps in a 62dp column are the tightest arrangement on any screen in this app, and the reason they stay in one row is that a stacked ladder would put `Largest` below the fold at 200% text scale.
- **Overflow**: **guaranteed never to overflow.** The specimen's width is capped rather than fixed and it re-wraps at every step, so no step can produce a horizontal scrollbar (E14). Step labels wrap to two lines; the pixel figure on the third line wraps but never truncates, because the pixel figure is the one thing the reader can check against the phone's own font slider. At `--reader-xxl` **and** 200% OS text scale the specimen gets taller and the page scrolls — which is the correct outcome, since E14's requirement is no clipping and no overlap, not a fixed page height.

---

## 7. Accessibility

- [x] **Contrast 14.48:1** (day) / **12.00:1** (night) for the specimen — `--color-text-primary` on `--color-surface-sunken`, the highest pair in the app, measured, not asserted.
- [x] **Contrast 6.22:1** / **6.01:1** for the `DeferredList` and the specimen footnote — `--color-text-secondary`. Note this list is `--color-text-secondary` and not `--color-text-primary`: it is documentation, not content, and making it compete with the specimen would be the wrong hierarchy.
- [x] **Contrast 5.50:1** / **7.25:1** for the selected step's label — `--color-text-inverse` on `--color-accent`.
- [x] **Contrast 6.07:1** / **8.86:1** for the focus ring — `--color-border-focus`, measured as non-text per WCAG 1.4.11.
- [x] **The specimen is decorative by intent and says so to assistive technology.** It is marked as a sample and excluded from the reading order, so a screen-reader user is not handed the app's stand-in prose as document content — while the *controls* remain fully labelled with their values. This is the one screen in the app where the largest text on the page is deliberately not read aloud, and the reason is that it is a picture of text, not text.
- [x] **Selection is never carried by colour alone**: the selected step carries the fill, the label in `--color-text-inverse`, and its own state in the accessibility announcement. The selected theme segment likewise.
- [x] **Keyboard navigation complete** at every breakpoint; every step and segment reachable and operable; focus visible at 2dp with a 2dp offset, never removed.
- [x] **The smallest step is 16px** — `--reader-sm` `#16/27` — which clears the `design-quality.md` floor of 16px on mobile, so **the no-sub-16px floor and E14 cannot both be violated**; the largest is 26px with the measure cap holding.
- [x] **Reading order and language correct**: chrome follows the app locale with French as the fallback for an unrecognised language (B28); the specimen's text follows **its own** language, because content is displayed as published and never translated (B44). The `DeferredList` is fully localised in both languages, including the seven items it names.
- [x] **Reduce-motion honoured**: there are no specimen animations to disable, and every remaining duration becomes `0ms`.

---

## 8. Data

| Field | Type | Origin | Required | Possible error |
|---|---|---|---|---|
| `readingScale` | `enum(sm\|md\|lg\|xl\|xxl)` | `shared_preferences`, global | yes | Read failure → **no screen-level Load error is raised here, and none is raised on Settings root either** (`settings.md` § 4 declines that state for the same reason): the store is resolved once at bootstrap and an unknown value falls back to `md`, **because a default the reader never chose is recoverable and a blank screen is not**. Write failure → snap-back + snackbar |
| `themeOverride` | `enum(system\|day\|night)` | `shared_preferences`, global | yes | Same |
| `phoneTextScale` | `double` | platform | yes | Absent → `1.0`; the specimen is the reader at the chosen step, not multiplied twice |
| `specimenSeed` | `String` | local, the first stored Markdown paragraph on the device | no | Absent → the app stand-in, with the `--text-caption` note. Unreadable → the stand-in + `--color-warning` line |
| `specimenSource` | `String?` | local, the novel and chapter the seed came from | no | Null when the stand-in is shown. **Rendered as a small `--text-caption` credit under the specimen when present** — `From “{novel} · {chapter}”` — so the reader knows they are looking at their own book and not at marketing copy |
| `mediaQueryWidth` | `int` | platform | yes | — drives the measure cap only |
| `locale` | `Locale` | platform, read-only | yes | Unrecognised → **French** (B28) |

- **Loading**: nothing is paged and nothing is fetched. The single disk read is the specimen seed, and it is rendered inside the specimen rather than as a page state, because a page skeleton would replace the one thing the reader came to look at.
- **Cache / offline**: **the whole screen works with no connection**, because it reads nothing from the network. The specimen is local Markdown, so a reader on a plane can decide their text size on a plane — which is the condition this screen is mostly used in.
- **Sensitive data**: **the specimen's text is never logged, never copied elsewhere, and never leaves the app** (B29, B30, C4). It is rendered from a file the reader downloaded by asking; displaying it back to them on a settings page is the same display the reader already performs, and it produces no second copy. The app stand-in is app-owned text and carries no site content at all, so a first-day reader's specimen cannot misrepresent anyone's chapter.

---

## 9. Traceability

| ID | Origin | Manifestation on this screen |
|---|---|---|
| B25 | PRD | **Continuous scroll and nothing else.** There is no reading-mode control here — not disabled, absent. The specimen scrolls with the page and has no tap zones, so there is nothing on this screen that could be mistaken for a page-turn affordance |
| B26 | PRD | Three segments — `Follow the phone · Day · Night` — writing the same `themeOverride` the reader's `themeButton` writes. Selecting one re-themes this page **and** the specimen instantly, with no cross-fade |
| B27 | PRD | Five steps, `--reader-sm` through `--reader-xxl`, each labelled with its pixel figure, each applying to the specimen **on the same frame**. The value survives closing the app because it is one stored preference, and it is the same preference the reader's size control writes |
| B28 | PRD | Every label, step name, segment and the `DeferredList` exists in French and English. There is **no language control here** — B28 puts language in Settings root, and it is read-only |
| B44 | PRD | The specimen renders Markdown through the reader's own pipeline: no markup, styling or script from a fetched document survives, and the seed is displayed as text and nothing else |
| B46 | PRD | This screen writes `readingScale` and `themeOverride` and **nothing else**. It has no control that could clear, bound or touch history, and the control that could — *Clear reading history* — is on Settings root and nowhere near here |
| E12 | PRD | An OS language change re-localises the whole chrome live; the specimen's text stays as published, because content is never translated (B44) |
| E13 | PRD | With `themeOverride = system`, an OS light/dark change re-themes this page immediately. With an explicit override, it does not — which is the point of the override |
| E14 | PRD | An OS font-size change re-measures the specimen immediately with nothing lost; at the largest step and at 200% scale the measure cap holds, the column re-wraps, and **no text is clipped, overlapped or horizontally scrolled** |
| E22 | PRD | The specimen is seeded with a **whole stored paragraph**, so a legitimately short chapter — an "Extra", an author's afterword — is a valid seed and is never treated as a broken one |

---

## 10. Gate checklist

- [x] All nine states described, with a concrete rendering. The two with nothing distinct to render say **why**.
- [x] Every interactive element has a behaviour, a feedback, a resulting state and a rule ID.
- [x] Responsive defined at **every** breakpoint in the design system — and the two larger ones say "identical, stop widening", which is ADR-019.
- [x] Anti-generic section checked **and justified**; the assumed choice is stated: **a real specimen, and a labelled stand-in rather than lorem ipsum.**
- [x] No design value left "to be defined". Every colour, size, duration and easing cited exists in `design-system.md` with a value.
- [x] Every B/E/C ID on this screen appears in § 9.
- [x] `forge-guard placeholders` reports nothing here.
- [x] Consistent with `design-system.md`: the specimen obeys the reader scale, the 1.72 line-height held at every step, and the measure cap that `design-system.md` § 1.2 states as deliberate. **§ 2.12 was amended, not obeyed by silence**: it no longer lists the text size or the theme as `SettingsChoiceSheet` instances, and § 11 carries the argument for the ladder and the segments.
- [x] **Every token cited by this screen exists in the design system, with the value it is given here.** The full citation table is § 12.
- [x] **No token outside the design system was needed, and no ramp token is cited with a value.** The accent's pressed steps are declared in the design system without values, so they are named here by role and not written as hex.

---

## 11. Deliberately absent (ADR-009, ADR-017) — and why that is not a gap

The following are **absent from this screen: not disabled, not greyed out, not marked "coming soon".** A disabled control is a promise about v2, and this design does not make promises it has not kept.

| Absent | Why it is absent rather than disabled |
|---|---|
| **Reading modes** — scroll / paged / horizontal / side-by-side | ADR-009. v1 is continuous scroll only, so there is exactly one mode and a mode selector would select from a set of one. ADR-009 names this exact screen as where the mode setting lives in v2 |
| **Swipe and tap page-turn** | B25 forbids it in v1. It is not a setting; it does not exist |
| **Orientation and rotation lock** | ADR-009. A phone reader that locks orientation also has to justify not locking it, and neither is asked for |
| **Colour filters** — sepia, greyscale, inverted, background tint | ADR-009 and B25. A filter is a per-page transform, and v1 has no pages |
| **Text justification** — left / justified | Not deferred so much as **refused for v1 on the merits**: the reader's own anti-refuse list in `design-system.md` § 0 does not include justification because justified prose at a 65–75 character measure in a serif creates rivers, and rivers are worse than a ragged edge. A control that offers a worse reading experience is not a setting, it is a liability |
| **Paragraph spacing** | ADR-009. It interacts with the 1.72 line-height that ADR-017 holds constant on purpose: adding a second vertical rhythm control would give the reader two competing ways to change the same rhythm |
| **Line-height control** | ADR-017 holds line-height at **1.72 at every step** as a decision, argued in the ADR: scaling line-height with size would break the reading rhythm between size steps, and a rhythm that changes when the reader changes the size is a rhythm they cannot get used to. This is not deferred — it is a contestable choice with the reasoning attached, and shipping a slider over it would be shipping an argument the design has already had |
| **Custom font, font family, Dyslexic face** | ADR-017. v1 uses a **serif preference chain with no bundled font** — `Noto Serif` → `Roboto Slab` → platform serif — precisely so that no font picker exists and no licence is carried. Bundling is an **explicit v2 candidate** recorded in the ADR, and the Dyslexic face is named there as a genuine accessibility option that v1 declines on scope grounds |

The list above is rendered on the screen itself, as seven lines of `--text-body-sm` `--color-text-secondary` prose under the group label `NOT IN THIS VERSION`. That is the one place in this app where absence is drawn: a reader who has read a competitor's settings and does not see a justification mode here is entitled to know it was decided rather than forgotten. Each line names **why**, not just what — a list of seven absent controls with no reasons reads as an unfinished screen, and one with reasons reads as a decision.

**Two reconciliations with `design-system.md`, and both name a shape that lost.**

**One with § 2.9 (`Switch`).** That section names four settings whose effect is not obvious and requires each to carry a `consequence` line: *checking for new chapters*, *remove after reading*, *history retention* and *theme*. The first, second and third are switches or choice rows on Settings root, which is where they appear. **Theme is not a switch here — it is a three-segment control**, and it needs no `consequence` line because the control names all three of its values at once: the reader can see that `Follow the phone`, `Day` and `Night` exist before choosing, rather than reading a sentence explaining what a two-state control would do. A switch with a consequence line is the design system's answer for an effect that is *hidden*; a segmented control is the answer for an effect that is *enumerable*, and this one is enumerable. Both routes reach the same stored `themeOverride`, and the reader's `themeButton` cycles the same three values in the same order.

**One with § 2.12 (`SettingsChoiceSheet`), and the sheet lost.** § 2.12 used to list this screen's two controls as instances of `SettingsChoiceSheet` — theme (3 values), text size (5 values). It no longer does: **§ 2.12 was amended to name history retention as its one v1 instance, and this screen's ladder and segments are what it now points at.** The reasoning, because a screen file that adopts a design-system decision without arguing it is not reconciling, it is obeying:

- **The text size is not chosen once.** A reader who opens a sheet of five sizes is answering *which one is set*; a reader who walks a ladder is answering *how does my book look at each of these*. The second is the question they actually have, and it is the question the specimen on this page exists to answer. A sheet would answer it only by sending the reader out to look — which is the entire reason this is a screen rather than a sheet (`settings-reader.md` § 1: *the preview needs room*).
- **The visit frequency decides it.** Text size is adjusted a dozen times in a session and repeatedly for years; retention is set once and then lives. A shape that costs four taps per change is the wrong shape for the value a reader reaches for most often — open, scroll, tap, dismiss, against one tap on a step already in view.
- **Three values is not a reason for a sheet.** The theme's effect is *enumerable*, so all three names sit on the control at once; that is the same argument the paragraph above makes against a `consequence` line, applied to a sheet instead of a switch.

**What this costs, stated rather than hidden**: `SettingsChoiceSheet` now has **one** instance in the whole app, and two settings that look like siblings on other platforms get three different shapes here. That is the price of matching each control to how its value is actually used, and it is cheaper than the alternative — one uniform picker that is wrong for the value the reader touches most. § 2.12 keeps the component declared for exactly this reason: **the next screen that needs a single-value picker should reuse it, not invent a fourth shape.**

---

## 12. Tokens this screen cites

Every value below is the one the design system declares, so `design-check tokens-used` can re-derive it. Only the colour rows are contrast-measured, and each figure is the design system's own worst-case figure for that token across the surfaces it is legal on.

| Token | Day | Night | Measured (day / night) | Where it appears here |
|---|---|---|---|---|
| `--color-background` | `#F5F2ED` | `#121315` | — | The page field behind the chrome and the specimen |
| `--color-surface-sunken` | `#EBE7E0` | `#0C0D0F` | — | **The specimen itself** — the same recessed field the reader uses |
| `--color-text-primary` | `#1A1714` | `#E8E4DD` | **14.48:1** / **12.00:1** | Specimen text, step and segment labels |
| `--color-text-secondary` | `#5A524A` | `#A8A29A` | **6.22:1** / **6.01:1** | The `DeferredList`, the empty-library note, the specimen credit |
| `--color-text-inverse` | `#FDFAF6` | `#17181A` | **5.54:1** / **7.27:1** | The selected step and the selected segment label, on the `--color-accent` fill |
| `--color-accent` | `#8A4B12` | `#E3A857` | **5.50:1** / **7.25:1** | Selected step fill, selected segment fill, focus ring |
| `--color-warning` | `#8A5A12` | `#E0AC47` | **4.80:1** / **7.36:1** | The unreadable-seed line — warning, not error, because the setting saved |
| `--color-border` | `#D9D3C9` | `#2E3237` | exempt | 1dp rule between the two control groups. Exempt per `design-system.md` § 0.0: decorative separator, not a component boundary |
| `--color-border-focus` | `#8A4B12` | `#E3A857` | **6.07:1** / **8.86:1** | 2dp focus ring at 2dp offset on all eight controls |
| `--color-surface-raised` | `#FEFCF9` | `#232629` | — | The snackbar host on a failed write |

Non-colour tokens cited: `--reader-sm` `#16/27`; `--reader-md` `#18/31` (default); `--reader-lg` `#20/34`; `--reader-xl` `#23/39`; `--reader-xxl` `#26/44`; `--text-body` `#16/24` (step labels); `--text-body-sm` `#14/20` (`DeferredList`, captions); `--text-caption` `#12/16` (specimen credit, empty-library note, seed-failure line); `--text-overline` `#11/16` at 600 with `letter-spacing 0.08em` (the three group labels); `--space-2xs` `2dp` (gaps inside the step row and inside the segment row); `--space-md` `12dp` (step column padding); `--space-lg` `16dp` (group label offset); `--space-xl` `24dp` (between the size group and the specimen, and between the theme group and the deferred list); `--space-2xl` `32dp` (the gap that closes a group — larger than any gap inside one, per `design-system.md` § 1.3); `--space-3xl` `48dp` (page top margin); `--border-width` `1dp` (between-group rules); `--border-width-strong` `2dp` (focus ring); `--shadow-none` on the specimen, the steps and the segments; `--shadow-sheet` `0 8 24 rgba(0,0,0,0.18)` (snackbar); `--radius-md` `8dp` (unselected step and unselected segment outline); `--radius-full` `999dp` (the specimen's inset radius — **not applied to the prose column itself**, which is `--radius-none`); `--duration-fast` `120ms` (step and segment feedback, failed-write snap-back); `--duration-normal` `200ms` (push/pop); `--ease-standard` `cubic-bezier(0.2, 0, 0, 1)`; `--ease-accelerate` `cubic-bezier(0.3, 0, 1, 1)` (the snap-back); `--bp-mobile` `< 600dp`, `--bp-tablet` `600–1023dp`, `--bp-desktop` `1024–1439dp`; touch target `48dp`.