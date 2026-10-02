---
type: screen
slug: browse-sources
title: Browse — Sources
module: browse
status: approved
generated_at: 2026-10-02
derived_from:
  - .forge/prd.md
  - .forge/design/design-system.md
rule_ids:
  - B1
  - B2
  - B22
  - B23
  - B24
  - B28
  - B32
  - B39
  - B50
  - C4
  - C11
  - C12
  - C14
edge_case_ids:
  - E4
  - E5
  - E9
  - E21
flow: discover-loop
---

# Screen — Browse · Sources

> The source of truth for generating this screen. One screen, not a family: `browse-genre` and `browse-catalogue` are specified separately because they are different routes with different capability questions.

---

## 1. Role of the screen

| | |
|---|---|
| **App archetype** | `mobile_consumer` |
| **Module** | browse — **rank 4** of 5 in the navigation |
| **Route** | `/browse` |
| **Type** | page, tab root (no back button) |
| **Users** | the reader, several times a week, in the one place a novel can be added to the library |
| **User stories served** | US-01, US-16 |
| **Business rules** | B1 B2 B22 B23 B24 B28 B32 B39 B50 C4 C11 C12 C14 |
| **Edge cases** | E4 E5 E9 E21 |

**In one sentence**: this screen lets the reader choose which of the app's compiled sites they browse — turning one off when they have finished with it, and being told plainly when a site can no longer be read.

**Why it is at rank 4 of the navigation**: Browse is the only way to add a novel, so it is the module with no alternative entry. It is still **fourth**, not first, because it is not what the app is opened for — resuming is (ADR-018). This screen is the *top* of the discover loop and a **tab root**: it has no back button and no title-bar action, because there is nothing behind it inside the tab and nothing to add above the list.

---

## 2. Visual direction for this screen

| | |
|---|---|
| **Mood** | quiet, warm, unhurried |
| **Density** **normal, leaning compact** | the library is a scan surface at 72dp; this is a list of **two to three** rows, and a list of three things that is 72dp tall with nothing else on it reads as an empty app. Rows are 64dp — the `NovelRow` `result` measure, reused deliberately because the thing being listed is the same kind of thing. |
| **Contrast level** **high** | `--color-text-primary` `#1A1714` on `--color-surface` `#FBF9F6` measures 14.48:1 by day. A status word that a reader has to act on — *off*, *could not read* — must not be the faintest thing on the row. |
| **Surface** | `--color-surface` `#FBF9F6` day / `#1A1C1F` night, on `--color-background` `#F5F2ED` / `#121315`. Flat rows, one `--color-border` `#D9D3C9` rule between them, **no card, no shadow**. |
| **Accent used** | `--color-accent` `#8A4B12` day / `#E3A857` night — **only** on the switch track when a source is on, and on the focus ring. The accent marks *state the reader set*, nothing else. It is never on a row that is merely present. |
| **Photographic treatment** | **none.** No site logo, no favicon, no banner. A favicon at 16dp is unreadable, a logo at 48dp is an advert for someone else's site inside a reading app, and a broken logo is a fourth way for this screen to fail. The site is identified by its **name and language**, which is what the reader reads anyway. |
| **Reference** | Mihon's source list, with the marketplace removed: a toggle and a name per row, no version numbers, no update badges, no store. |

### 2.1 Anti-generic — mandatory

This screen must not resemble any of these defects:

- [x] **No pure white `#FFFFFF` background** — `--color-background` is `#F5F2ED` / `#121315`, and the rows sit on `--color-surface` `#FBF9F6` / `#1A1C1F`, which is a *step* off the page and not a white card on a grey page.
- [x] **No shadowed card per row.** Rows are flat with a `--color-border` rule. `--shadow-none` is the default for every row in the app; the only two shadows in the app are the sheet and the dialog, and this screen uses one of them once (the confirm-free undo snackbar uses the sheet shadow).
- [x] **Not uniform.** Three scales on one row: name at `--text-h4` `#18/24`, meta at `--text-body-sm` `#14/20`, verdict at `--text-caption` `#12/16`. The hierarchy is a ratio of scales and a change of colour, not a constant indent.
- [x] **No generic grey `#6B7280`** — the neutrals are the paper-anchored ramp of `design-system.md` § 1.1; the row separator is `#D9D3C9` / `#2E3237`.
- [x] **No symmetric centring as the layout.** The status line is left-aligned at the `--space-lg` margin; the rows are full-bleed with internal `--space-md` padding; the switch is the only right-aligned element, which puts the eye on the control last.
- [x] **No generic spot illustration** — none. The all-off notice is a sentence and a colour, not an icon in a circle and not an empty-state graphic.
- [x] **Not one typeface at one weight** — the source name is 600 at `--text-h4`, its meta is 400 at `--text-body-sm`, and the capability line is 600 uppercase at `--text-overline` `#11/16` with `letter-spacing 0.08em`. Three treatments on one row is the scale doing the work.

**Assumed, non-neutral choice**: **this screen has no install, no update, and no store — and it says so, on the screen, in one line.** ADR-013 makes the sources a compile-time registry, so a reader arriving here expecting an extension store (which is what Mihon looks like, and what Tachiyomi looked like) finds a list of two names and a switch each. Inventing an "update available" badge or a "from repository" affordance would be a promise about a mechanism that does not exist and cannot be built in v1. The single `--text-caption` line under the status line — *These sites are part of the app. There is nothing to install, and nothing to update.* — is the honest version, and it is the sentence that saves the reader from looking for a button that is not there. It is also the reason this screen is 64dp rows and not a grid of source cards: **the content is a capability declaration, so it is set as a list where a declaration can be read.**

---

## 3. Anatomy

```
AppScaffold (titleBar + content + bottomNav; persistentStatus when a download runs)
├── TitleBar                    "Sources" --text-h1, no back (tab root), no action
├── StatusLine                  --text-overline, --color-text-secondary
│   └── AllOffNotice            only when 0 sources are on  --color-warning + wording, no button
├── SourceList                  full-bleed rows, --color-border rule between
│   └── SourceRow               (slice-local; built from StatusChip + Material 3 Switch)
│       ├── SourceName          --text-h4, --color-text-primary
│       ├── SourceMeta          --text-body-sm, --color-text-secondary
│       │                       "Chinese · 3 novels in your library"
│       ├── SourceCapability    --text-overline, "SEARCH" or "GENRE BROWSING ONLY"
│       ├── LastChecked         --text-caption, B49 wording or "never checked"
│       ├── StatusChip          local (off) · failed (could not read) · never-checked
│       └── Switch              48dp target, --color-accent track when on
└── SnackBarHost                --color-surface-raised, --shadow-sheet
```

| # | Component | Role | Source |
|---|---|---|---|
| 1 | `SourceRow` | One site: name, language, library reach, declared capabilities, last-known verdict, on/off | slice-local, assembled from the primitives below |
| 2 | `StatusChip` | The state label — off, could not read, never checked | `design-system.md` § 2.5 |
| 3 | `Switch` | The enable/disable control, 48dp | Material 3 `Switch` (`09-widgets-ui.md` §Conventions); **no design-system section — see § 11** |
| 4 | `EmptyState` | All-off is *not* an EmptyState — see § 4 | `design-system.md` § 2.7 |
| 5 | `AppScaffold` | Holds the title bar, the list and the bottom nav | `design-system.md` § 2.8 |

**`StatusChip` parity on this screen.** `StatusChip` declares six variants and this screen renders exactly three of them: `failed` for a site that could not be read, `never-checked` for a site no check has ever reached, `local` (the neutral variant) for a site the reader has turned off. The other three do not apply and are not rendered in a disabled or placeholder form: `new` is a novel-row concept and a site is never new — it is either in the build or it is not; `downloaded` and `downloading` are states of *a novel's chapters*, which is what the row's meta line reports as a count, not a state the site itself is in. One component, one rendering.

---

## 4. States — all nine, no exceptions

| State | Trigger | Rendering | Reader feedback |
|---|---|---|---|
| **Loading** | **A whole-screen loader is never a state here, and that is a decision.** Per ADR-013 the registry is compiled in and the last-known verdict is local, so no request is made on open. The only in-flight work is a **user-triggered check**, and loading exists **per row** | The row's check action becomes a 16dp spinner in place of the chip (`PrimaryButton` `loading`, `design-system.md` § 2.3) — **and the previous verdict stays on screen beside it**. A spinner that replaced the verdict would hide the very fact the reader came to read | Check spinner replaces the row's action; the verdict line is untouched |
| **Filled** | The normal case: the registry, one row per source | Rows as in § 3. Name, meta, capability, verdict, switch. Every row shows a **last-checked line** — a date, or *never checked* (B49). Nothing is ever presented as fresh when it is not | — |
| **Empty — never visited** | **Cannot occur, and this is worth saying rather than leaving blank.** B1 guarantees at least two sites in v1 and the registry is compiled in, so the list is never empty | Onboarding (`/onboarding`) is the app's only first-run surface (`flows.md` § 5), and this screen has no first-run variant: a welcome panel inside a list of three rows would be a second one | — |
| **Empty — no data** | **Every source is turned off.** The list itself is still full — the rows are what the reader needs in order to turn one back on | The `StatusLine` is replaced by `AllOffNotice` in `--color-warning` `#8A5A12` / `#E0AC47`: an icon **and** the words *No site is on. Browse has nothing to show until you turn one on.* **No button.** The first row that is off carries its name in `--color-text-primary` rather than secondary, so the eye lands on the switch that fixes it. A button here would have to be a bulk "turn them all on" the reader did not ask for; the row is the action | The notice is persistent, not a snackbar — a condition, not an event |
| **Load error** | Local settings cannot be read — a real failure with a real consequence: the on/off state is unknown | `ErrorState` at the top: `--color-error` icon, *Lumen Tale could not read which sites you have turned on*, `secondary` **Try again**. **Every row renders as ON**, and the switches are `disabled` (`--color-text-disabled` on `--color-surface-sunken`, still 48dp tall so nothing jumps). **Fail open, not closed**: a storage hiccup must not silently hide the app's entire discovery surface. An empty list here would look identical to "the reader turned everything off", which is a lie | The rows still show names and capabilities, so the screen is never blank |
| **Submit error** | The toggle is tapped and the write fails | The switch **springs back to its previous value** over `--duration-fast` 120ms, and a snackbar reads *Could not save that change. Nothing was changed.* No row is left half-toggled, because a switch showing a state the app does not hold is the same class of lie B22 exists to prevent | Reversal is animated so the failure is legible; the snackbar is `secondary`, not `primary` |
| **Success** | The switch is moved | The switch animates over `--duration-fast` 120ms `--ease-standard`. **A snackbar appears only when the site had novels in the library**, and then it names what did *not* change — *FanMTL is off. Your 3 novels and their downloaded chapters are untouched.* — with **Undo**. **When the site had nothing in the library there is no snackbar at all**: turning a site you have never used off is silent, and a toast per toggle would turn three taps into three interruptions | Undo rather than a confirm dialog: the action is reversible, and a modal for a reversible toggle teaches the reader to dismiss modals |
| **Offline / permissions** | No connection | **Identical to Filled.** Every value on this screen is local: the registry is compiled in, the toggles are local, the verdicts are the last ones *known* and each is stamped with when it was read. The screen makes **zero network calls on open**. **No permission prompt exists here** — nothing is requested: no account (B4), no file import, no notification, because a user-triggered check is foreground work and B37's notification belongs to the scheduled update check, which is a different flow | None. An "offline" banner on a screen that never needed a connection would be a lie in the other direction |
| **Read-only** | Always, for the entities on this screen | **The sites themselves are read-only.** Name, language and base host come from the compiled registry and there is no edit affordance anywhere: no add-source, no remove-source, no rename, no reorder, no "check for updates". The only thing this screen can change is whether a source participates in browsing. This is the one screen in the app where the **absence of an edit control is the implementation of ADR-013**, and a reviewer who cannot find an edit button has found the design working | — |

> Four of the nine have no rendering of their own, and each says why: loading does not exist because nothing is fetched, first-visit cannot occur because the registry is compiled in, and the read-only condition is a property rather than an event. A blank cell would read as an unimplemented state; a row that explains why there is nothing to implement is a decision.

---

## 5. Interactions

| Element | Event | Behaviour | Visual feedback | Resulting state | Rule |
|---|---|---|---|---|---|
| Source row | tap | Open `/browse/:sourceId` — the genre index for that site | Row `pressed`: `--color-surface-sunken` over `--duration-fast` 120ms | Filled, next screen | **B1** |
| Switch — turning **on** | tap | Persist `enabled = true` | Track fills `--color-accent` over `--duration-fast` 120ms `--ease-standard` | Filled | — |
| Switch — turning **off** | tap | Persist `enabled = false`. **Nothing is deleted.** The site stops appearing in Browse; the library keeps its novels, their downloads, and their update checks | Snackbar only if the site had library novels, with **Undo** | Filled | **B32**, **B39**, **C4** |
| Switch — write fails | tap | No state change | Switch springs back; snackbar *Could not save that change.* | Submit error | **B24** |
| Row's check action | tap | Fetch the site's own index page **once**, because the reader asked (B5). Verdict and timestamp update | 16dp spinner in place of the chip; chip returns with the new verdict | Loading → Filled | **B5**, **C7** |
| Check — connection absent | tap | No verdict change | Chip stays; snackbar *No connection. Nothing is wrong with the site.* — **distinct wording from a broken site** | Filled | **B22**, **E5** |
| Check — site unreadable | tap | Chip becomes `failed`; the verdict line names the cause | `--color-error` icon **+ words**, never colour alone | Filled, failed row | **B22**, **E4** |
| `AllOffNotice` | — (informational) | No button, by design | — | Empty — no data | — |
| Undo in the snackbar | tap | Restore `enabled = true` | Switch fills again | Filled | **B32** |
| List | scroll | Whole list, ≤ 3 rows — **there is no pagination and cannot be**: the registry is compile-time | — | — | **B1** |
| Long-press | gesture | **Nothing.** No multi-select here; the row's only long-press candidate is a destructive one that does not exist | — | — | — |
| Title bar | tap | **No action.** No search field, no sort, no filter, because none of the three has anything to act on | — | — | — |

- **Focus / keyboard**: D-pad moves focus between the switch of each row and the check action of each row; `Enter` toggles; `Esc` dismisses the snackbar. Focus is a 2dp `--color-border-focus` `#8A4B12` / `#E3A857` ring at a 2dp offset, never removed. The switch's accessible label is *FanMTL, on* / *FanMTL, off* — **the state is in the label**, because a switch that announces only "FanMTL" tells a screen-reader user nothing about the thing they just changed.
- **Gestures**: scroll only. **No pull-to-refresh** — it would issue a network request the reader did not ask for (B5) and B36's whole point is that opening the app is not a trigger. Refreshing is the per-row check, and it is explicit.
- **Animations**: switch and row press `--duration-fast` 120ms `--ease-standard`; snackbar slide `--duration-normal` 200ms; dialog fade `--duration-normal` 200ms. All become `0ms` under the OS reduce-motion setting.
- **Back**: **there is no back.** This is a tab root (ADR-008's `StatefulShellRoute`), so the system back gesture leaves the Browse tab and returns to wherever the reader came from, without unwinding a stack that does not exist.

---

## 6. Responsive

| Breakpoint | Behaviour | What collapses or disappears |
|---|---|---|
| **Mobile** `< 600dp` | Single column, `--space-lg` 16dp margins, rows full-bleed with `--space-md` 12dp internal padding, switch right-aligned at the row's trailing edge | Nothing. This is the design target and the only width v1 ships (C3) |
| **Tablet** `600–1023dp` | Identical single column, **centred and capped at the mobile measure**. **Explicitly not a tablet layout** — ADR-019 excluded it, and `design-system.md` § 1.7's `--bp-mobile` row says `< 600dp` is *the only layout v1 ships* | Nothing collapses. The layout stops growing and centres |
| **Desktop** `1024–1439dp` | Same. Flutter desktop is out of scope (C3) | — |

> **This tension was recorded, then resolved upstream.** An earlier draft of this note asked `design-system.md` to strike a `Paged grid` row reading *"Browse results on ≥600dp; 3 columns at `--bp-desktop`"* — unreachable under **ADR-019**, and also a bad rule on its own terms. The row is **gone**: § 4.2 now reads `Result grid — 2 columns, 96dp cells`, with the reason written beside it — *the column count does not change with width*, because a grid that gains columns makes the reader hunt for a novel they just saw three columns left. This screen was already following § 1.7 and ADR-019, so **nothing here changed**. The note is kept because it is the record of the correction. `browse-catalogue.md` § 6 carries the same note for the same reason.

- **Touch target**: 48dp minimum everywhere. The switch is 52×32dp visually and carries a 48dp hit area; the row's check action is 48dp even when it is a 16dp spinner; the snackbar's **Undo** is 48dp.
- **Overflow**: guaranteed never to overflow. The row's text column is the only flexible element and wraps to a third line rather than clipping. A source name longer than one line truncates with an ellipsis at `--text-h4` and **the full name is the row's accessible label and the title bar of the next screen**, so truncation never costs the reader the name. At the largest OS text scale the row grows vertically — the fixed 64dp is a target height, not a clip box.

---

## 7. Accessibility

- [x] **Contrast 14.48:1** (day) / **12.00:1** (night) for the source name — measured, not asserted.
- [x] **Contrast 6.22:1** / **6.01:1** for `--color-text-secondary` on `--color-surface`, used for the meta line.
- [x] **Contrast 4.80:1** / **7.36:1** for the all-off notice's `--color-warning`, and **6.64:1** / **6.22:1** for `--color-error` on a failed verdict — both measured, both at or above 4.5:1 for text.
- [x] **Focus visible** — 2dp `--color-border-focus` `#8A4B12` / `#E3A857`, measured at **6.07:1** / **8.86:1** as a non-text component (WCAG 1.4.11), at a 2dp offset, never removed.
- [x] **Keyboard navigation complete** across every switch and every check action; `Enter` activates, `Esc` dismisses the snackbar. The row itself is focusable and opens the site, so a keyboard user reaches the same destination as a touch user.
- [x] **No state is carried by colour alone.** Off is `--color-text-secondary` wording plus a neutral chip plus an unfilled track; a site that could not read is an icon **and** a sentence **and** `--color-error`. Both survive greyscale, a colour-blind reader, and a screen reader.
- [x] **Semantic alternative for every control**: the switch announces *FanMTL, on*; the check action announces *Check whether FanMTL can be read* — an action, not a noun, because that is what it does. The verdict line is part of the row's label, so it is read before the reader acts, not after.
- [x] **Language and reading direction correct**: the app's locale follows the phone (B28), and each source's own language is shown as an ISO code *word* rendered in the app's locale — `Chinese`, not `zh`. The row does not assume LTR, and the source's language is never used to right-align anything.
- [x] **Reduce-motion honoured**: switch and row press become instant; the snackbar still appears, because a notification is not decoration.

---

## 8. Data

| Field | Type | Origin | Required | Possible error |
|---|---|---|---|---|
| `source.id` | `String` | compiled registry (ADR-013) | yes | Never absent — a missing class is a build failure, not a runtime state |
| `source.name` | `String` | compiled registry | yes | Long names truncate; full name stays in the label |
| `source.lang` | `String` | compiled registry, ISO 639-1 | yes | Unknown code renders the code itself, never a blank |
| `source.supportsLatest` | `bool` | compiled registry | yes | — |
| `source.supportsSearch` | `bool` | compiled registry — **a promise, not a guess** (ADR-015) | yes | `false` for every v1 source until each site is measured; the row says so |
| `enabled` | `bool` | local storage, per source | yes | Unreadable → **fail open** (see Load error); unwritable → the switch reverts |
| `libraryNovelCount` | `int` | local | no | `null` renders as nothing rather than `0`, because `0` is a claim |
| `lastVerdict` | `enum(ok, unreadable, unreachable)` | local, written by a check or by a library update that reached the site | no | Absent → `never-checked` chip, never a green tick |
| `lastCheckedAt` | `DateTime` | local | no | Absent → *never checked* (B49) |
| `lastFailureCause` | `enum(no_connection, layout_changed, not_answering)` | local | no | Absent → the verdict falls back to the generic sentence |

- **Loading**: nothing is paged and nothing is fetched. The whole list is the registry, so there is no infinite scroll, no page spinner, and no *load more*.
- **Cache / offline**: **the entire screen works from the device with the radio off** — zero network calls on open. This is C14's form applied to a screen C14 does not list, and it is deliberate: making the source list depend on the network would mean the reader cannot even see which sites they have turned off on a train.
- **Sensitive data**: **no query, no cookie, no session and no page HTML is ever persisted or logged from this screen.** The app has no analytics, no crash reporting and no telemetry (B29), so a check writes a verdict and a timestamp and nothing else. The verdict is a source's *health*, not the reader's behaviour, and it is never sent anywhere.

---

## 9. Traceability

| ID | Origin | Manifestation on this screen |
|---|---|---|
| **B1** | PRD | The list is exactly what v1 ships — two rows. A site whose permission is unconfirmed is **absent**, not disabled and not listed as "coming" (E21) |
| **B2** | PRD | Each row names one site, and a novel opened from this screen belongs to that site and no other. This screen is where the one-site rule becomes visible |
| **B22** | PRD | A site that could not read is a `failed` chip, an icon, a sentence and a per-row **Check again**. It is never greyed, never hidden, and never presented as "no novels" |
| **B23** | PRD | One failed site leaves every other row fully usable and enabled. There is no global banner and no blocking state |
| **B24** | PRD | Every failure on this screen carries a way to try again: `Try again` on the settings-read error, `Check again` per row, and a reversible switch on the write error |
| **B28** | PRD | Every string is localisable, including the failure sentences — which is also what makes them reportable (C12). No in-app language switch exists (B28 forbids one) |
| **B32** | PRD | Turning a site off says, in the snackbar, that the library and the downloads are untouched. Deleting downloaded chapters is a separate explicit choice that lives on `downloads` and is **off by default** |
| **B39** | PRD | The disable wording states that **update checks for novels already in the library keep running**. A toggle that silently skipped those novels would violate B39 behind the reader's back |
| **B50** | PRD | The row's `SourceCapability` line states what the site can do: `SEARCH` or `GENRE BROWSING ONLY`. It is a **declaration, not a control** — and with every v1 source measured as having no usable search, every v1 row currently reads `GENRE BROWSING ONLY` |
| **C4** | PRD | Turning a site off removes nothing from disk. The screen says so at the moment of the action |
| **C11** | PRD | Rows are 64dp with 48dp targets, all controls reachable one-handed, and the list is one screen tall |
| **C12** | PRD | Failure wording is a sentence a reader can say out loud — *"FanMTL could not be read"*, *"there was no connection when it was last checked"* — with the date attached. There is no report button, because the app cannot receive a report (C2); the words are the channel |
| **C14** | PRD | Opening this screen makes **no network call at all**, which is stronger than C14 requires |
| **E4** | PRD | A site whose layout changed shows `failed` with its own wording — *Lumen Tale can no longer read this site* — not an empty list, and not a retry that pretends retrying might help |
| **E5** | PRD | With no connection, the screen renders identically to Filled and each verdict carries the date it was read. A check with no connection produces the wording *nothing is wrong with the site*, never a failed chip |
| **E9** | PRD | The disable notice confirms the stored chapters stay readable. A site can disappear entirely from the app and its downloads remain on the phone |
| **E21** | PRD | An unconfirmed site is **not shown at all** — not as a disabled row, not as "coming soon". The app does not advertise what it may not ship |

---

## 10. Gate checklist

- [x] All nine states described, with a concrete rendering. The four with nothing to render say **why** they have none.
- [x] Every interactive element has a behaviour, a feedback, a resulting state and a rule ID.
- [x] Responsive defined at **every** breakpoint in the design system — and the two larger ones say "identical, stop widening", which is ADR-019, not an omission. The `design-system.md` § 4.2 `Paged grid` tension is recorded rather than silently resolved.
- [x] Anti-generic section checked **and justified**; the assumed choice is stated (no install, no update, no store, and the screen says so).
- [x] No design value left "to be defined". Every colour, size, duration and easing cited exists in `design-system.md` with a value.
- [x] Every B/E/C ID on this screen appears in § 9.
- [x] `forge-guard placeholders` reports nothing here.
- [x] Consistent with `design-system.md`: this screen renders three of `StatusChip`'s six declared variants and names the other three with a reason, so the component has one rendering.
- [x] **Every token cited by this screen exists in the design system, with the value it is given here.** The full citation table is § 12; `design-check tokens-used` re-derives each value and fails the screen if one drifts.

---

## 11. Controls this screen does not have, and the design-system gap it found

**Absent, not disabled** — a disabled control is a promise about a version that does not exist:

| Absent | Why |
|---|---|
| Install / add source | ADR-013 — a compile-time registry. There is no repository |
| Update source / version bump | ADR-013. `versionId` is a compile-time constant bumped by the owner in a new build (C5, US-17) |
| Source detail screen | There is nothing to configure. A detail screen would be a screen with two read-only labels |
| Search, sort, filter | Nothing to search: ≤ 3 rows of a compile-time list |
| Multi-select | The only destructive action does not exist here, and B32 means there is nothing to bulk-apply |
| "Report this source" | C2/B29 — the app cannot receive a report. The sentence is the channel (C12) |
| Source logos / favicons | A 16dp favicon is unreadable, a 48dp logo is an advert, a broken logo is a fourth failure mode |
| Notification permission | No background work happens from this screen; B37's notification belongs to the scheduled check |

**Design-system gap found by this screen.** There is no `### 2.x Switch` section in `design-system.md`, and `component-parity` therefore has no contract to enforce on the one control this screen turns over. The colours used here are inherited, not invented: track `--color-accent` `#8A4B12` / `#E3A857` when on, `--color-surface-sunken` `#EBE7E0` / `#0C0D0F` when off, thumb `--color-surface-raised` `#FEFCF9` / `#232629`, focus ring 2dp `--color-border-focus`. That is the same selected/unselected pair `StatusChip` already declares, which is why it is defensible — but it should be written down once, in the design system, rather than left to this screen. **Recommendation to the design-system owner: add a `Switch` section carrying these four tokens, its three states (on / off / disabled) and its 48dp target.** This screen does not edit the design system itself.

---

## 12. Tokens this screen cites

Every value below is the one the design system declares, so `design-check tokens-used` can re-derive it. Non-colour tokens are listed for completeness; only the colour rows are contrast-measured.

| Token | Day | Night | Measured (day / night) | Where it appears here |
|---|---|---|---|---|
| `--color-background` | `#F5F2ED` | `#121315` | — | The page field behind the rows |
| `--color-surface` | `#FBF9F6` | `#1A1C1F` | — | Every `SourceRow` |
| `--color-surface-sunken` | `#EBE7E0` | `#0C0D0F` | — | Row `pressed`; a disabled switch's track |
| `--color-surface-raised` | `#FEFCF9` | `#232629` | — | The snackbar; the switch thumb |
| `--color-text-primary` | `#1A1714` | `#E8E4DD` | **14.48:1** / **12.00:1** | Source name; the first off row's name in the all-off notice |
| `--color-text-secondary` | `#5A524A` | `#A8A29A` | **6.22:1** / **6.01:1** | Meta line, `SourceCapability`, the *off* status wording |
| `--color-text-disabled` | `#6E665C` | `#948E87` | **4.58:1** / **4.69:1** | A disabled switch's label while settings are unreadable |
| `--color-text-inverse` | `#FDFAF6` | `#17181A` | **5.54:1** / **7.27:1** | The snackbar's **Undo** label |
| `--color-accent` | `#8A4B12` | `#E3A857` | **5.50:1** / **7.25:1** | Switch track when on; the focus ring's companion colour |
| `--color-warning` | `#8A5A12` | `#E0AC47` | **4.80:1** / **7.36:1** | `AllOffNotice` wording and icon |
| `--color-error` | `#8A3228` | `#EE8B76` | **6.64:1** / **6.22:1** | The `failed` chip and the settings-read `ErrorState` |
| `--color-info` | `#426986` | `#7FB3DA` | **4.74:1** / **6.78:1** | The `never-checked` chip — wording plus a neutral notice |
| `--color-border` | `#D9D3C9` | `#2E3237` | exempt | The rule between rows |
| `--color-border-focus` | `#8A4B12` | `#E3A857` | **6.07:1** / **8.86:1** | 2dp focus ring on switches and check actions |

Non-colour tokens cited: `--text-h1` `#31/38`; `--text-h4` `#18/24`; `--text-body-sm` `#14/20`; `--text-caption` `#12/16`; `--text-overline` `#11/16`; `--space-md` `12dp`; `--space-lg` `16dp`; `--radius-sm` `4dp`; `--radius-md` `8dp`; `--radius-full` `999dp`; `--border-width` `1dp`; `--duration-fast` `120ms`; `--duration-normal` `200ms`; `--ease-standard` `cubic-bezier(0.2, 0, 0, 1)`; `--shadow-sheet` `0 8 24 rgba(0,0,0,0.18)`.