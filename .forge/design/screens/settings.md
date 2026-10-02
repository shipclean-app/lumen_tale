---
type: screen
slug: settings
title: Settings
module: more
status: approved
generated_at: 2026-10-02
derived_from:
  - .forge/prd.md
  - .forge/design/design-system.md
rule_ids:
  - B4
  - B26
  - B27
  - B28
  - B30
  - B35
  - B36
  - B38
  - B47
  - B46
edge_case_ids:
  - E11
  - E12
  - E13
  - E14
flow: settings-flow
---

# Screen — Settings

> The source of truth for generating this screen. One screen, not a family: `settings-reader` and `settings-about` are specified separately because each has its own states, and the Sources sub-screen is a list, not a settings row.

---

## 1. Role of the screen

| | |
|---|---|
| **App archetype** | `mobile_consumer` |
| **Module** | `more` — **rank 5 of 5** in the bottom navigation, and Settings is the last destination behind it |
| **Route** | `/more/settings` |
| **Type** | full page with a title bar, pushed inside the More shell so the bottom nav stays |
| **Users** | the reader, occasionally — and on a borrowed device, by the owner, over the reader's shoulder |
| **User stories served** | US-13, US-17 |
| **Business rules** | B4 B26 B27 B28 B30 B35 B36 B38 B46 B47 |
| **Edge cases** | E11 E12 E13 E14 |

**In one sentence**: this screen lets the reader change the handful of things they own — how it looks, when it checks, how long it remembers — and states the two things they do not own, plainly: there is no account, and there is nothing here that can be rescued.

**Why it is last in the navigation**: frequency 2, centrality 1, and that is the point rather than an accident. `design-system.md` § 3.2 ranks More fifth *by design* — everything behind it is configuration, none of it is part of the reading loop, and a reader who opens Settings daily has a problem this product does not have. It is nevertheless the screen with the most sub-screens, which is exactly why it is worth designing carefully and not last in effort.

---

## 2. Visual direction for this screen

| | |
|---|---|
| **Mood** | quiet, plain, countable |
| **Density** | **normal** — justified: this is a scan surface. The reader arrives with one question ("is checking on? how long does it remember?"), finds it in under two seconds, and leaves. It must not be dense, because a dense settings screen implies more configuration than exists. |
| **Contrast level** | **high** — `--color-text-primary` `#1A1714` / `#E8E4DD` measures **14.48:1** / **12.00:1**; every label is primary, and value lines are `--color-text-secondary` `#5A524A` / `#A8A29A` at **6.22:1** / **6.01:1**. This is the one screen where a value line is the *content* rather than metadata, so it clears body-text contrast rather than caption contrast. |
| **Surface** | `--color-background` `#F5F2ED` day / `#121315` night. Rows are **full-bleed on the page**, not cards: separation inside a group is a `--color-border` `#D9D3C9` / `#2E3237` 1dp rule, and separation *between* groups is space. |
| **Accent used** | `--color-accent` `#8A4B12` / `#E3A857` — **only** on: the selected switch track, the selected radio, the selected sheet row, the focus ring, and one text action. It marks *the value the reader chose*. It is never a row background. |
| **Photographic treatment** | **none.** No cover, no illustration, no glyph in a circle anywhere on this screen. |
| **Reference** | the Android system Settings of a phone with nothing to sell you — grouped rows, `--text-overline` group labels, values stated in words on the right, and no icon column. |

### 2.1 Anti-generic — mandatory

This screen must not resemble any of these defects:

- [x] **No pure white `#FFFFFF` background** — `--color-background` is `#F5F2ED` / `#121315`, warm paper by day and cool ink by night (ADR-016).
- [x] **No shadowed card for everything.** Rows are full-bleed, `--shadow-none`, separated by a `--color-border` rule inside a group and by `--space-xl` between groups. A settings screen built from rounded, shadowed cards is the single most common way this screen goes wrong: it turns four paragraphs of text into eleven containers and implies each row is a document.
- [x] **Not uniform.** Hierarchy is carried by `--text-overline` 11/16 at 600 with `letter-spacing 0.08em` for group labels against `--text-h4` 18/24 at 600 for row labels against `--text-body-sm` 14/20 for value lines — a 1.25 UI scale plus one scale for labels, not a constant gap.
- [x] **No generic grey `#6B7280`** — the value lines are the paper-anchored ramp `--color-text-secondary`.
- [x] **No symmetric centring as the layout.** Labels are left, values are right-aligned on the same row, and the two never meet in the middle. A centred label/value column is a form, and this is not a form.
- [x] **No generic spot illustration** — none. The one non-row element, the E11 disclosure, is **a recessed block of words with no icon at all**, because an icon would make a permanent fact look like an incident.
- [x] **Not one typeface at one weight** — sans throughout in chrome, three weights in use (600 group labels, 600 row labels, 400 value lines), and the reader's serif appears nowhere on this screen: the reader scale is prose-only (`design-system.md` § 1.2).

**Assumed, non-neutral choice**: **this screen has no leading icons, and a chevron appears if and only if the row cannot show its whole answer — on nothing else.** That is the decision the screen exists to make, and it is argued rather than assumed. A leading icon column on a settings list is 24dp of gutter plus 8dp of space per row — 32dp of a 360dp screen, one ninth of the width — spent on glyphs that carry no information: none of `Sources`, `Language`, `Reading history` or `Check for new chapters` is identifiable by a picture, and the reader already knows what each one is from its label. Worse, it makes the screen a recognisable imitation of a platform settings list, which is the generic outcome this design system refuses by name. The chevron is therefore **information, not decoration**: it is the only mark on the screen that means *there is a decision here you cannot see in this row* — five rows navigate to a screen, and the retention row's five time windows do not fit in a value line. The count that follows this rule is an observation, not the rule: as written this screen spends it on six rows and withholds it from five, and adding a row will change that arithmetic without weakening the argument. The consequence is that the reader learns this screen's grammar in one glance: *a row with a value and no chevron is something I change right here; a row with a chevron has more to it than this row can show*.

**Three more decisions on this screen, stated because they are contestable:**

1. **No account section, no profile, no sync, no sign-out.** Not "coming later", not greyed out: **absent**. B4 is not a feature gap, it is the product's privacy posture, and a row that says "Sign in" would be a request to create an identity the app has no use for. A screen's absences are part of its design.
2. **No backup, no export, no share, anywhere.** B30 and ADR-010. The screen does not look like it is missing something because **nothing in this product has ever had those** — they were excluded by decision in PRD § 9, not deferred. What the screen *does* carry is the consequence of that decision, stated plainly in the E11 disclosure block, because the disclosure is what makes the absence honest rather than negligent.
3. **The theme is shown here and changed one tap deeper.** The `Reader appearance` row carries the current override in words (`Day · Medium (18pt)`) and navigates to `settings-reader`, which owns the three-value control. Settings root renders **no second theme control**. A root settings screen that repeats every leaf setting inline is how two screens end up disagreeing about the same stored value.

---

## 3. Anatomy

```
AppScaffold (titleBar "Settings", bottomNav kept — this is a sub-page of More)
└── SettingsBody                         ListView, --space-3xl top margin
    ├── GroupLabel "READING"             --text-overline 600, 0.08em, --color-text-secondary
    │   └── SettingsRow → settings-reader
    │         label    "Reader appearance"
    │         value    "Day · Medium (18pt)"
    │         trailing chevron_right
    ├── --space-xl break
    ├── GroupLabel "LIBRARY"
    │   ├── SettingsRow → /more/sources
    │   │     label  "Sources"   value "2 of 2 sites enabled"
    │   ├── SettingsSwitchRow  "Check for new chapters"
    │   │     consequence  "Off — nothing is checked unless you ask."   ← B35, § 2.9
    │   │     control  Switch (setting variant, off)
    │   ├── CheckIntervalGroup                ← absent entirely while the switch is off
    │   │     RadioListTile × 6               never / 12h / 24h / 48h / 72h / weekly
    │   └── SettingsActionRow  "Check now"
    │         value "Last checked 2 days ago"  ← B49 wording, same vocabulary as Updates
    ├── --space-xl break
    ├── GroupLabel "DOWNLOADS"
    │   └── SettingsSwitchRow  "Remove after reading"
    │         consequence  "When on, a chapter's stored copy is deleted once you
    │                        have finished it. There is no backup of it."  ← § 2.9
    │         control  Switch (setting variant, off — B32's "off by default")
    ├── --space-xl break
    ├── GroupLabel "HISTORY"
    │   ├── SettingsRow → /history
    │   │     label  "Reading history"
    │   │     value  "1,247 entries · oldest 4 months ago"
    │   ├── SettingsRow → sheet  "Keep history for"
    │   │     label  "Keep history for"   value "1 year"   ← B47 default
    │   ├── SettingsChoiceSheet  5 single-select rows, current one --color-accent
    │   └── SettingsRow (danger)  "Clear reading history"   → ConfirmDialog
    ├── --space-xl break
    ├── GroupLabel "APP"
    │   ├── SettingsRow (read-only, no chevron)  "Language"
    │   │     value   "English"
    │   │     hint    "Follows your phone."  --text-caption, --color-text-secondary
    │   ├── SettingsRow → /onboarding   "How this app works"
    │   └── SettingsRow → settings-about
    │         value "Version 0.9.0 · build 41"
    └── DisclosureBlock                    --color-surface-sunken, no icon
          "Nothing here is backed up. If you uninstall Lumen Tale
           or lose this phone, your library, your downloads and your
           reading positions are gone, and no copy exists anywhere."
          · On its own footer line, --text-caption:
          "Uninstalling cannot be detected while it happens. Read this
           once now rather than after."
          · ghost link "What survives an update →"  → settings-about
```

| # | Component | Role | Source |
|---|---|---|---|
| 1 | `AppScaffold` | Title bar + retained bottom nav + push route | design-system § 2.8 |
| 2 | `GroupLabel` | `--text-overline` section label | design-system § 1.2 (the "Section label" usage of `--text-overline`) |
| 3 | `SettingsRow` | Label + right-aligned value + optional chevron | **§ 4.2 "Settings" layout** (grouped rows with section labels, no icons); the row itself is slice-local — see § 10 |
| 4 | `SettingsSwitchRow` | Row hosting a `Switch`, carrying a mandatory `consequence` line | **`Switch` is design-system § 2.9**, `setting` variant; the row wrapper is slice-local |
| 5 | `SettingsChoiceSheet` | Bottom sheet, single-select, for the six intervals and the five retention windows | design-system § 4.2 "Sheet" layout |
| 6 | `DisclosureBlock` | The recessed block carrying E11 | design-system § 2.7 idiom, `--color-surface-sunken`, **no icon** |
| 7 | `SecondaryButton` / `TextButton` | Sheet actions, dialog cancel, the ghost link | design-system § 2.3 |
| 8 | `SnackBarHost` | Result of "Check now", and of a failed write | design-system § 1.4 `--shadow-sheet` |

> **Components that are not used, and why**: `StatusChip` is not on this screen. A chip is the design system's carrier of *counts the app keeps about itself* (B48, B49) and every figure here is a settings value or a stated fact, not a state chip — putting `StatusChip` next to a switch would read as a second control. `NovelRow` is not used either: these are not novels. `Switch`'s `inline` variant is not used either — every switch here has a row to live in, and the `inline` variant exists for a sheet or a dialog, where there is none.

> **The design system declares the "Settings" layout (§ 4.2: *grouped rows with section labels, no icons*) but no row primitive for it.** `SettingsRow`, `SettingsSwitchRow` and `SettingsChoiceSheet` are therefore slice-local, and the row wrapper needs to be lifted into § 2 before a second settings screen is written — otherwise the same rows will acquire two renderings. This is recorded rather than silently duplicated.

---

## 4. States — all nine, no exceptions

| State | Trigger | Rendering | Reader feedback |
|---|---|---|---|
| **Loading** | The reader has tapped **Clear reading history**. The confirm dialog must state how many entries it is about to delete, and that is a `COUNT` over the history table before the dialog can be answered honestly. | The dialog's confirm button enters `PrimaryButton`'s `loading` state: 16dp spinner centred, label hidden, **width locked** so the dialog does not resize. Its cancel button stays live. **The rest of the screen renders fully and immediately** — every label and every value on this page is a compile-time string or a synchronous local read, so there is no page-level skeleton and no spinner anywhere else | A spinner in a destructive dialog is the one place it earns its cost: it says *this is counting, not deleting*. Refusing to show the count would mean a dialog saying "clear your history?" without saying how much |
| **Filled** | Normal case | The eleven rows above. Values and consequences in words, never as a bare control state: the schedule says `Off — nothing is checked unless you ask`, the retention says `1 year`, the language says `English`, the reader appearance says `Day · Medium (18pt)` | None. A settings screen that confirms every press is a settings screen nobody trusts |
| **Empty — never visited** | First time the reader opens Settings, so nothing has been changed yet | **The same eleven rows.** Every value renders at its declared default: `Off`, `Day`, `Medium (18pt)`, `1 year`, `Off`. There is no skeleton and no "not configured yet" state, and the reason is the point: on a first visit the defaults *are* the configuration, and a row that hides itself until it has been touched teaches the reader that a blank row is normal — which is exactly the affordance that makes a broken source look empty | None. The screen's appearance is identical before and after configuration, so the reader can compare it to what they set |
| **Empty — no data** | The reader taps **Clear reading history** when the list is already empty | The `danger` row enters `PrimaryButton`'s `disabled` state: `--color-text-disabled` `#6E665C` / `#948E87` label (measured **4.58:1** / **4.69:1**) on `--color-surface-sunken`, **still 48dp tall** so the row does not jump. No dialog opens, because there is nothing to confirm | Nothing, and that is correct: a dialog asking the reader to confirm destroying zero entries is theatre |
| **Load error** | The stored settings cannot be read — a corrupt or unreadable preferences file. This is the one failure that can affect the whole screen | The row list is replaced by `ErrorState`: `--color-error` icon, **a sentence naming what failed** — *"This screen's settings could not be read from the phone."* — and a `secondary` **Try again**. **The failure is scoped in the sentence itself**: *"Your library, your downloads and your reading positions are untouched — they are stored separately."* That second clause is not reassurance; it is the reason the reader can act on the message instead of panicking | The error says *what failed* and *what did not*, per B24. It never falls back to showing defaults, because showing defaults would make a corrupted preferences file indistinguishable from a fresh install — and the reader would then re-apply settings over unknown values |
| **Submit error** | A write fails: `Clear reading history`, either switch, the theme override, the size step or the interval cannot be persisted (storage full, file unwritable) | The dialog **stays open**. For the dialog's destructive action: one `--color-error` message at `--text-body-sm` beneath the buttons — never the button alone changing colour. For the two switches, exactly the design system's `Switch`/`failed` state (§ 2.9): **the switch snaps back to the stored value over `--duration-fast` 120ms and the failure is shown *beside* the switch, as the row's `consequence` line replaced by the message — never by tinting the switch**, because a red switch reads as "this setting is now off" rather than "this setting could not be saved". For the radios and segments: snap-back, and the same beside-the-control message | The snap-back is the important part, and § 2.9 says why there is no `loading` state at all: the write is synchronous, so a spinner would ask the reader to believe a write is in progress when none is. A toggle that stays flipped while the write failed shows the reader a setting the app does not hold — the same false-state-of-completeness failure B6 and C8 forbid in the download pipeline, in a place where it would be read as a preference |
| **Success** | `Clear reading history` completed | Three things happen, in this order. (1) The dialog dismisses. (2) The snackbar reads **"Reading history cleared. Your reading positions were kept."** — the second clause is mandatory and is the entire success message, because B46 makes position the thing the reader must believe survived. (3) The `Reading history` row's value updates immediately to `0 entries`. **There is no confetti, no toast with a tick, no account of the deletion** — anti-references forbid the celebration | A generic "History cleared" leaves the reader fearing they lost their place, which is the app's core promise (B16). The confirmation names the half that was *kept* |
| **Offline / permissions** | No connection at all | **Identical to Filled.** This screen makes **zero network calls**, so there is nothing to degrade and nothing to disable. The one exception is deliberate and visible: **`Check now` stays live offline** and, when tapped with no connection, produces the Load-error rendering worded for the network — *"No connection. Nothing on this screen is affected."* Separately, and only if the reader has already turned the schedule on: if Android's **notification permission** is denied, the schedule row carries a `--color-warning` line with an icon and words — *"The check will run, but Android will not show its notification, so nothing will tell you when it finishes."* — plus a text action **Open notification settings**, which deep-links to the OS settings rather than re-prompting in a loop | Offline is not announced anywhere in this app, and this is not the place to start. The notification case is a genuine one and it is reported **in words with an icon**, because `--color-warning`'s meaning is "something is not doing what you asked and it is not broken" — the exact condition here — and because colour alone is forbidden from carrying it |
| **Read-only** | Nothing. **No permission, no role, no sign-in state and no app condition makes this screen read-only** | Every row here is a control the reader owns. What the row list does contain is read-only *content* beside controls — the `Language` row and the E11 disclosure — and the rule that separates them is typographic and mechanical: **read-only content carries no chevron, no ripple, no toggle, and no pressed state.** A row the reader cannot act on is visually inert by absence, not by greying | This is where B4 is visible. There is no account row to disable, no profile to view, no "sign out" to grey out. The screen has no state in which the reader's own configuration is held for them by anything |

### 4.1 User-visible copy — both languages (B28)

Every string on this screen, in both languages, as it will be keyed in the ARB. French is not a translation pass here: it is the **other** half of the copy, and where a French string is longer than its English — which happens, and which is why the row's value line truncates rather than the label — the truncation is a design consequence, not a bug.

| Key | English | Français |
|---|---|---|
| `group.reading` | `READING` | `LECTURE` |
| `group.library` | `LIBRARY` | `BIBLIOTHÈQUE` |
| `group.downloads` | `DOWNLOADS` | `TÉLÉCHARGEMENTS` |
| `group.history` | `HISTORY` | `HISTORIQUE` |
| `group.app` | `APP` | `APPLICATION` |
| `row.appearance.label` | `Reader appearance` | `Apparence du lecteur` |
| `row.appearance.value` | `{theme} · {size} ({pt} pt)` | `{thème} · {taille} ({pt} pt)` |
| `theme.day` | `Day` | `Jour` |
| `theme.night` | `Night` | `Nuit` |
| `theme.system` | `Follow the phone` | `Suivre le téléphone` |
| `size.sm` | `Small` | `Petit` |
| `size.md` | `Medium` | `Moyen` |
| `size.lg` | `Large` | `Grand` |
| `size.xl` | `Larger` | `Plus grand` |
| `size.xxl` | `Largest` | `Le plus grand` |
| `row.sources.label` | `Sources` | `Sources` |
| `row.sources.value` | `{enabled} of {total} sites enabled` | `{actifs} sites activés sur {total}` |
| `row.check.label` | `Check for new chapters` | `Rechercher les nouveaux chapitres` |
| `row.check.consequenceOff` | `Off — nothing is checked unless you ask.` | `Désactivé — rien n'est vérifié sauf à votre demande.` |
| `row.check.consequenceNever` | `Off — nothing is checked on its own, ever.` | `Désactivé — rien ne sera vérifié automatiquement.` |
| `row.check.consequenceInterval` | `Checks every {interval}. You can cancel a running check from its notification.` | `Vérifie toutes les {interval}. Vous pouvez annuler une vérification en cours depuis sa notification.` |
| `interval.never` | `Never` | `Jamais` |
| `interval.12h` | `Every 12 hours` | `Toutes les 12 heures` |
| `interval.24h` | `Every 24 hours` | `Toutes les 24 heures` |
| `interval.48h` | `Every 48 hours` | `Toutes les 48 heures` |
| `interval.72h` | `Every 72 hours` | `Toutes les 72 heures` |
| `interval.weekly` | `Weekly` | `Chaque semaine` |
| `interval.note.neverDownloads` | `Checking only reads chapter lists. It never downloads anything.` | `La vérification ne lit que les listes de chapitres. Elle ne télécharge jamais rien.` |
| `row.checkNow.label` | `Check now` | `Vérifier maintenant` |
| `row.checkNow.lastOk` | `Checked {relative} · nothing new.` | `Vérifiée {relative} · rien de nouveau.` |
| `row.checkNow.never` | `Never checked` | `Jamais vérifiée` |
| `row.checkNow.failed` | `Could not check {relative}. {cause}` | `Vérification impossible {relative}. {cause}` |
| `row.removeAfterReading.label` | `Remove after reading` | `Supprimer après lecture` |
| `row.removeAfterReading.consequence` | `When on, a chapter's stored copy is deleted once you have finished it. There is no backup of it.` | `Activé, la copie stockée d'un chapitre est supprimée dès que vous l'avez terminé. Il n'en existe aucune sauvegarde.` |
| `dialog.removeAfterReading.title` | `Delete chapters after reading?` | `Supprimer les chapitres après lecture ?` |
| `dialog.removeAfterReading.body` | `Finish reading a chapter and its stored copy is deleted. There is no backup of it — it cannot be brought back.` | `Terminez la lecture d'un chapitre et sa copie stockée est supprimée. Il n'en existe aucune sauvegarde : elle ne peut pas être récupérée.` |
| `dialog.removeAfterReading.confirm` | `Turn on` | `Activer` |
| `row.history.label` | `Reading history` | `Historique de lecture` |
| `row.history.value` | `{count} entries · oldest {relative}` | `{count} entrées · la plus ancienne {relative}` |
| `row.history.value.empty` | `0 entries` | `0 entrée` |
| `row.retention.label` | `Keep history for` | `Conserver l'historique pendant` |
| `retention.1w` | `1 week` | `1 semaine` |
| `retention.1m` | `1 month` | `1 mois` |
| `retention.3m` | `3 months` | `3 mois` |
| `retention.1y` | `1 year` | `1 an` |
| `retention.2y` | `2 years` | `2 ans` |
| `row.clearHistory.label` | `Clear reading history` | `Effacer l'historique de lecture` |
| `dialog.clearHistory.title` | `Clear {count} entries?` | `Effacer {count} entrées ?` |
| `dialog.clearHistory.body` | `Reading positions are not part of this list and will not be touched.` | `Les positions de lecture ne font pas partie de cette liste et ne seront pas touchées.` |
| `dialog.clearHistory.confirm` | `Clear` | `Effacer` |
| `snack.historyCleared` | `Reading history cleared. Your reading positions were kept.` | `Historique de lecture effacé. Vos positions de lecture ont été conservées.` |
| `row.language.label` | `Language` | `Langue` |
| `row.language.hint` | `Follows your phone. Change it in Android's language settings.` | `Suit votre téléphone. Changez-la dans les paramètres de langue d'Android.` |
| `row.onboarding.label` | `How this app works` | `Comment fonctionne cette application` |
| `row.onboarding.value` | `Show the two introduction screens again` | `Revoir les deux écrans d'introduction` |
| `row.about.label` | `About Lumen Tale` | `À propos de Lumen Tale` |
| `row.about.value` | `Version {buildName} · build {buildNumber}` | `Version {buildName} · build {buildNumber}` |
| `disclosure.e11` | `Nothing here is backed up. If you uninstall Lumen Tale or lose this phone, your library, your downloads and your reading positions are gone, and no copy exists anywhere.` | `Rien ici n'est sauvegardé. Si vous désinstallez Lumen Tale ou perdez ce téléphone, votre bibliothèque, vos téléchargements et vos positions de lecture sont perdus, et aucune copie n'existe ailleurs.` |
| `disclosure.e11.footer` | `The app cannot warn you at the moment you uninstall — the phone does that, outside the app. So it is said here, before, rather than after.` | `L'application ne peut pas vous avertir au moment où vous désinstallez : c'est le téléphone qui le fait, en dehors de l'application. C'est donc dit ici, avant, plutôt qu'après.` |
| `disclosure.aboutLink` | `What survives an update` | `Ce qui survit à une mise à jour` |
| `error.load` | `This screen's settings could not be read from the phone. Your library, your downloads and your reading positions are untouched — they are stored separately.` | `Les paramètres de cet écran n'ont pas pu être lus depuis le téléphone. Votre bibliothèque, vos téléchargements et vos positions de lecture ne sont pas touchés : ils sont stockés séparément.` |
| `error.write` | `This setting could not be saved. Nothing was changed.` | `Ce paramètre n'a pas pu être enregistré. Rien n'a été modifié.` |
| `error.countUnavailable` | `Count unavailable` | `Nombre indisponible` |
| `warning.notifications` | `The check will run, but Android will not show its notification, so nothing will tell you when it finishes.` | `La vérification s'exécutera, mais Android n'affichera pas sa notification : rien ne vous dira quand elle se termine.` |
| `warning.notifications.action` | `Open notification settings` | `Ouvrir les paramètres de notification` |
| `button.retry` | `Try again` | `Réessayer` |
| `button.cancel` | `Cancel` | `Annuler` |

> Three of the nine have an unusually thin rendering, and each says why: the page-level **Loading** does not exist because nothing on this page is fetched; **Empty — never visited** has no distinct appearance because the defaults *are* the state; **Read-only** has no variant because the screen is unconditionally writable. A blank cell would read as an unimplemented state; a row that explains why there is nothing to implement is a decision.

---

## 5. Interactions

| Element | Event | Behaviour | Visual feedback | Resulting state | Rule |
|---|---|---|---|---|---|
| Title-bar back | tap / system back | Pop to `/more` | `--duration-normal` 200ms `--ease-standard` | More | — |
| `SettingsRow → settings-reader` | tap | Push `/more/settings/reader` | Slide `--duration-normal` | Filled, sub-screen | B26 B27 |
| `SettingsRow → /more/sources` | tap | Push the Sources sub-screen — a list with an enable/disable switch per site | Slide | Filled | B1 B50 |
| `SettingsSwitchRow` — "Check for new chapters" | tap | Write `updateInterval = never`. **Off is the default and stays off until the reader taps it**; the `consequence` line names what OFF means (`Off — nothing is checked unless you ask`), which is what makes the off state legible rather than merely dark | Track fills `--color-accent`, thumb `--color-surface-raised`, `--duration-fast` 120ms; the `consequence` line changes to the chosen interval | Filled, check ON | **B35** |
| — the same row, when ON | tap | Write `updateInterval = never` — **choosing "Never" actively disables the schedule, it does not merely skip a run** | Track empties to `--color-surface-sunken`, thumb returns | Filled, check OFF, and the interval group **disappears with the row** | **B35** |
| `SettingsSwitchRow` — "Remove after reading" | tap | Opening a **`danger` confirm dialog first**, every time, never only the first: *"Finish reading a chapter and its stored copy is deleted. There is no backup of it — it cannot be brought back."* Confirming writes `removeAfterReading = true` | Switch snaps on only after the dialog confirms; the dialog is `--shadow-dialog` on `--color-surface-raised` | Filled, deletion ON | **B32**, **B33**, **C8** |
| — cancelling that dialog | tap | Nothing is written | Dialog dismisses, switch unchanged | Filled, deletion OFF | **B32** |
| `CheckIntervalGroup` — six radios | tap | Write the chosen interval. Intervals: `Never · Every 12 hours · Every 24 hours · Every 48 hours · Every 72 hours · Weekly` | Radio fills `--color-accent`, label goes `--color-text-primary` | Filled | **B35** |
| `SettingsActionRow` — "Check now" | tap | Run one library check **in the foreground**, whether or not a schedule exists | Row goes to `loading` (16dp spinner, label hidden, width locked) | Filled, then a snackbar | **B36** |
| — while the check runs | — | The app shows a cancellable foreground notification, per the platform contract; **cancelling one run does not touch the schedule** | OS notification surface | Filled | **B37** |
| — the check succeeds | — | Snackbar: *"Checked just now. Nothing new."* — **never** "No new chapters" as a fresh claim (B15) | — | Filled | **B15 B49** |
| — the check fails | — | The row's value line becomes the **failure wording**, not an empty state: *"Could not check just now."* plus the cause class in words. **No chapter count changes, because counts are local (B48)** | — | Filled | **B22 B24** |
| `SettingsRow → sheet` — "Keep history for" | tap | Sheet with five single-select rows: `1 week · 1 month · 3 months · 1 year · 2 years`. **There is no "forever"** — B47 bounds the list *by time*, and an unbounded option would be the rule it exists to prevent | Sheet slides up `--duration-normal`; current row checked with `--color-accent` | Filled | **B47** |
| `SettingsRow` — "Reading history" | tap | Push `/history` | Slide | Filled | B17 B47 |
| `SettingsRow` — "Clear reading history" (danger) | tap | Open `ConfirmDialog` on `--color-surface-raised` with `--shadow-dialog`: the **exact count**, and *"Your reading positions will not be touched."* | Dialog fade `--duration-normal` | Filled + dialog | **B46 B47 B24** |
| — the dialog's confirm | tap | `COUNT` → delete → dismiss → snackbar naming what was kept | See Success | Filled | **B46 B47** |
| `SettingsRow` — "Language" | tap | **Nothing. There is no destination and no chevron**, because B28 forbids an in-app language switch | None — no ripple, no pressed state | Filled | **B28** |
| `SettingsRow → /onboarding` | tap | Push `/onboarding`, **opening on step 2** (the disclosure), because the promise on step 1 has already been read | Slide | Filled | E11 |
| `SettingsRow → settings-about` | tap | Push `/more/settings/about` | Slide | Filled | **B43** |
| `DisclosureBlock` — ghost link | tap | Push `settings-about`, which carries the full E11 statement next to the version | Slide | Filled | E11 |

- **Focus / keyboard**: focus order is reading order — group label (not focusable) → row → row. Each row is **one focusable node**, so a `Switch` row announces as a single control with a state and its consequence, not as a label plus a switch plus a value. `Enter` / `Space` activates. `Back` returns. Focus is visible at 2dp `--color-border-focus` with a 2dp offset and is never removed. The sheet traps focus; `Esc` closes it and restores focus to the row that opened it.
- **Gestures**: **vertical scroll only.** No swipe-to-delete on any row: a destructive gesture on a row that also carries a value is two readings of one finger, and the only destructive action on this screen is one the reader must mean.
- **Animations**: push and sheet slide `--duration-normal` 200ms `--ease-standard`; switch thumb and radio `--duration-fast` 120ms `--ease-standard`; the snap-back after a failed write `--duration-fast` 120ms `--ease-accelerate`, because a value being taken *back* should arrive fast and stop. All durations become `0ms` under reduce-motion.
- **Back**: system back pops one level and **discards nothing**, because every row writes immediately and there is no uncommitted form on this screen. Leaving mid-dialog dismisses the dialog.

---

## 6. Responsive

| Breakpoint | Behaviour | What collapses or disappears |
|---|---|---|
| **Mobile** `< 600dp` | Single column, full-bleed rows with `--space-md` 12dp internal padding, group labels inset `--space-lg` 16dp, `--space-3xl` 48dp top margin. Values are right-aligned in the row's remaining width and **truncate with an ellipsis** | Nothing. This is the design target |
| **Tablet** `600–1023dp` | Identical single column, centred, **capped at the same measure as the phone** — the row list does not widen and the label does not drift away from the value. **Explicitly not a tablet layout** (ADR-010) | Nothing collapses — the layout simply stops widening |
| **Desktop** `1024–1439dp` | Same single column, centred, same cap. Flutter desktop is out of scope | — |

- **Touch target**: **48dp minimum on every row.** The `Switch` (`setting` variant) is a 48×32dp track, which is under 48 on its short axis — so the **row** is the target, at 48dp, and the switch sits inside it. The sheet rows are 56dp. `RadioListTile` is a Material primitive with its own platform hit-slop behaviour; the row's own height is the guarantee.
- **Overflow**: **guaranteed never to overflow.** Row labels wrap to two lines rather than truncate — truncating a settings label removes the reader's only way to know what the row is. Value lines truncate with an ellipsis at `--text-body-sm` and their full value is in the accessibility label. At 200% OS text scale, a row grows in height and the list scrolls; nothing is clipped. The `Language` hint line wraps to two lines rather than truncating, because it is the sentence that explains B28.

---

## 7. Accessibility

- [x] **Contrast 14.48:1** (day) / **12.00:1** (night) for row labels — `--color-text-primary` on `--color-background`, measured, not asserted.
- [x] **Contrast 6.22:1** / **6.01:1** for value lines and group labels — `--color-text-secondary`, at body-text contrast rather than caption contrast because on this screen the value line *is* the content.
- [x] **Contrast 4.58:1** / **4.69:1** for the disabled destructive row — `--color-text-disabled`, cleared even though WCAG 1.4.3 exempts inactive text.
- [x] **Contrast 4.80:1** / **7.36:1** for the denied-notification line — `--color-warning`, and it is never alone: icon **and** words carry the meaning.
- [x] **Contrast 6.07:1** / **8.86:1** for the focus ring — `--color-border-focus`, measured as non-text per WCAG 1.4.11.
- [x] **Contrast 3.18:1** / **3.24:1** for the selected sheet row's outline — `--color-border-field`, the token the design system declares for a component boundary.
- [x] **Keyboard navigation complete** on all four breakpoints; every row is reachable and operable; focus is visible at 2dp with a 2dp offset and never removed.
- [x] **No state is carried by colour alone.** The schedule's state is a switch **plus** the word `Never` or the interval name. The denied-notification case is an icon, words and a colour. The destructive row is the word `Clear`, not a red tint.
- [x] **Every row announces as one node** with its label, its current value and its role — for example *"Check for new chapters, off, value Never"* or *"Keep history for, 1 year, opens a list of options"*. A row that navigates and a row that changes a value are announced differently, because they are different things.
- [x] **The `Language` row is announced as read-only text**, not as an inert button: no chevron, no ripple, and the hint line is part of the same announcement so B28's reason is read aloud rather than merely drawn.
- [x] **Reading order and language correct**: the whole screen follows the phone's locale (B28), an unrecognised locale falls back to French, and every value in the sheet is localised — including `Every 72 hours`, which is the one string that is easy to leave untranslated. `dir` follows the language; no RTL source exists in v1 and the right-aligned value column is swapped under RTL.
- [x] **Reduce-motion honoured**: every duration becomes `0ms`, including the failed-write snap-back.

---

## 8. Data

| Field | Type | Origin | Required | Possible error |
|---|---|---|---|---|
| `themeOverride` | `enum(system\|day\|night)` | `shared_preferences`, global | yes | Write fails → control snaps back, snackbar; unreadable → screen-level Load error |
| `readingScale` | `enum(sm..xxl)` | `shared_preferences`, global | yes | Same |
| `updateInterval` | `enum(never\|12h\|24h\|48h\|72h\|weekly)` | `shared_preferences` | yes | Same. **Default `never`** — B35 |
| `removeAfterReading` | `bool` | `shared_preferences` | yes | Write fails → § 2.9's `failed` state: snap back, failure shown beside the switch. **Default `false`** — B32's "off by default" |
| `historyRetention` | `enum(1w\|1m\|3m\|1y\|2y)` | `shared_preferences` | yes | Same. **Default `1y`** — B47 |
| `historyEntryCount` | `int` | local, `COUNT(*)` over the history table | yes | Query fails → the row's value renders as `--text-caption` *"Count unavailable"*, **never as 0** (B48's lesson: a wrong local number is worse than no number) |
| `historyOldestEntryAt` | `Date?` | local | no | Null → the row says `0 entries`, which is the truth |
| `enabledSourceCount` / `registeredSourceCount` | `int`, `int` | `SourceManager` over the static registry (ADR-013) | yes | Registry read fails → value renders as `—`, not as `0 of 0` |
| `lastLibraryCheckAt` | `Date?` | local | no | Null → *"Never checked"* (B49) |
| `lastLibraryCheckOutcome` | `enum(ok\|failed)`, cause class | local | no | Failed → the row states the cause class in words, never "nothing new" (B15 B22) |
| `notificationsBlocked` | `bool` | OS | no | Unknown → the hint line is omitted rather than guessed |
| `buildName`, `buildNumber` | `String` | build-time constant from `pubspec.yaml` `version:` (ADR-011) | yes | Absent → the About row reads `Version —` and never an invented number (B43) |
| `locale` | `Locale` | platform, read-only | yes | Unrecognised → **French** (B28) |

- **Loading**: nothing on this screen is paged and nothing is fetched. The only asynchronous work is the `COUNT` behind the destructive dialog, and it is rendered in that dialog's `loading` state rather than as a page state.
- **Cache / offline**: **the screen is fully functional with no connection**, because it reads nothing from the network. `Check now` is the single exception and it fails honestly rather than disabling itself.
- **Sensitive data**: **nothing read here is ever logged.** No preference value, no history count, no registry size. The app has no account and no telemetry (B4, B29), and a log line containing "this reader keeps 14 novels and checks nightly" is a usage profile, which C2 forbids even when it never leaves the device in a file the reader can see. The only thing ever written outside the app is the OS notification the foreground check requires (B37), and that notification contains a count, not content.

---

## 9. Traceability

| ID | Origin | Manifestation on this screen |
|---|---|---|
| B4 | PRD | **No account, profile, sync or sign-out section exists.** Not disabled — absent. Traced as the Read-only state's reason: there is no identity that could hold the reader's configuration |
| B26 | PRD | The theme override appears as the first half of the `Reader appearance` value line, **in words** (`Day`), on the row that owns it. The three-value control itself lives one tap deeper on `settings-reader`. Root Settings renders **no second theme control** |
| B27 | PRD | The text size appears as the second half of the same value line, with its pixel figure (`Medium (18pt)`) so the reader can compare it against the phone's own font-size slider. The five-step ladder and the live preview live on `settings-reader` |
| B28 | PRD | The `Language` row is **read-only and carries no chevron**, because B28 forbids an in-app language switch. Its hint line states that the app follows the phone. Changing the phone's language re-localises this whole screen live, including this row's own value (E12) |
| B30 | PRD | **No backup, no export, no share row exists anywhere.** Their absence is the implementation, and the E11 disclosure is what the absence obliges the app to say instead |
| B32 | PRD | **A switch exists and is off by default** — *Remove after reading* in the `DOWNLOADS` group — and turning it on requires a `danger` confirmation that names the absence of a backup. The confirmation is required **every** time, not only the first, because B32's guarantee is that deletion is "a separate choice the user makes explicitly", and a second turn of the same switch after weeks is not a choice the reader is making explicitly any more |
| B33 | PRD | The per-chapter and per-novel deletes that the switch's `consequence` line refers to live where the reader is actually reading. Nothing on this screen can delete anything itself, and the switch's confirmation says so in the reader's own words rather than leaving the consequence to be discovered afterwards |
| B35 | PRD | The `Check for new chapters` switch is **off by default**, and its `consequence` line says what OFF means (`Off — nothing is checked unless you ask`) — the design system's § 2.9 requires exactly this line for this setting, and without it "off by default" is a state the reader cannot see. The six-interval group is **not rendered at all** while the switch is off, so the screen never implies that a schedule exists. Choosing `Never` from within the group actively disables the schedule |
| B36 | PRD | `Check now` is present and live **whether or not the schedule is on**. Nothing on this screen, and nothing about opening the app, triggers a check by itself |
| B38 | PRD | One `--text-caption` line under the interval group: *"Checking only reads chapter lists. It never downloads anything."* The absence of a download control inside the schedule group is the second half of the same guarantee |
| B46 | PRD | The destructive dialog names what is kept (*"Your reading positions will not be touched."*), the success snackbar repeats it, and the row that shows the count is not a position row. Clearing history can never cost a position, so no control here is worded as if it might |
| B47 | PRD | `Keep history for` = `1 year` by default, configurable through five time windows, and `Clear reading history` exists. **No "forever" option**, because B47 bounds the list by time and an unbounded choice would be the rule it exists to prevent |
| E11 | PRD | The `DisclosureBlock` at the foot of the page states plainly that nothing is backed up, that an uninstall destroys the library, and that **the app cannot warn the reader at the moment of removal** — which is the honest reason the disclosure is here, on first run, and in Settings |
| E12 | PRD | A phone-language change re-localises the entire screen and its value lines instantly, with no loss of any stored setting and no re-entry |
| E13 | PRD | Changing the phone's light/dark setting re-themes this screen immediately, and the `Reader appearance` value line follows the `system` override |
| E14 | PRD | The `Reader appearance` value line reports the resolved pixel figure, so the reader can see the reader's size respond to the phone's font-size setting without opening a chapter |
| C5 | PRD | Every maintenance action funnels through a new installable file; nothing on this screen asks the reader to do a technical procedure |
| C12 | PRD | Every failure message here is a sentence a borrowed-device reader can read aloud and describe to the owner — including the cause class on `Check now` and the write-failure wording |
| C14 | PRD | **Zero network calls** to render this screen; it is a listed screen under the no-network rule |

---

## 10. Gate checklist

- [x] All nine states described, with a concrete rendering. The four with nothing to render say **why** they have none.
- [x] Every interactive element has a behaviour, a feedback, a resulting state and a rule ID.
- [x] Responsive defined at **every** breakpoint in the design system — and the two larger ones say "identical, stop widening", which is ADR-010, not an omission.
- [x] Anti-generic section checked **and justified**; the assumed choice is stated: **no icon column, and a chevron on six of eleven rows and nothing else.**
- [x] No design value left "to be defined". Every colour, size, duration and easing cited exists in `design-system.md` with a value.
- [x] Every B/E/C ID on this screen appears in § 9.
- [x] `forge-guard placeholders` reports nothing here.
- [x] Consistent with `design-system.md`: the "Settings" layout in § 4.2 is *grouped rows with section labels, no icons*, and this screen is its first implementation. Both switches use § 2.9's `setting` variant with its mandatory `consequence` line, its `failed` state and its deliberately absent `loading` state.
- [x] **Every token cited by this screen exists in the design system, with the value it is given here.** The full citation table is § 12; `design-check tokens-used` re-derives each day value and fails the screen if one drifts.
- [x] **Numbers in this document are format exemplars, not fixtures.** `1,247 entries`, `2 of 2 sites enabled`, `Last checked 2 days ago` and `Version 0.9.0 · build 41` describe the *shape* of each value. Every one of them is rendered from real device data, and no screen in this app contains a hard-coded count — a plausible fixed number in a settings screen would be a lie the reader could not detect.

---

## 11. Deliberately absent — and why that is not a gap

| Absent | Rule | Why |
|---|---|---|
| Account, sign-in, sign-out, profile, sync | **B4** | There is no server and no identity to store. A row that said "Sign in" would be asking for a credential the product has no use for |
| Backup, restore, export, share a chapter, send a novel anywhere | **B30**, ADR-010 | Content belongs to its authors and its sites (C1, C4). Excluded by decision in PRD § 9, not deferred — so the screen does not look like it is missing something, because nothing here ever had them |
| An in-app language picker | **B28** | The app follows the phone, and an unrecognised language falls back to French. A picker would be a second source of truth for a value the platform already owns |
| A "reset all settings" button | — | It would be a destructive control whose only outcome the reader cannot undo (there is no backup), and it would clear the update interval **and** the retention window **and** the theme in one gesture. Three reversible settings are not worth one irreversible button |
| Storage used, cache size, "clear cache" | C4 | The app stores only what the reader asked for, and every stored chapter is a chapter they chose. A "free up space" control next to a no-backup product reads as an invitation to delete something irreplaceable — the per-chapter and per-novel deletes that *do* exist are explicit and separate (B32, B33) |
| Reading modes, colour filters, font family | ADR-009, ADR-017 | They belong to the reader, not to the root screen, and in v1 they do not exist. `settings-reader` states this in full rather than showing them greyed out |
| Per-novel check intervals, per-novel "check now" | B39 | B39 requires a check to visit **every** novel in the library and to skip none. A per-novel interval would be a way to skip one, so the control does not exist. Batching a subset of novels is the v2 candidate, and it belongs in the schedule, not in this screen |
| Notification permission request on screen entry | B37, Android 13+ | The permission is requested **at the moment the reader turns the schedule on**, which is when it is first needed. Asking on entry — for a feature that is off by default (B35) and that most readers of a personal library will never turn on — would be requesting something they have not yet decided they want |

---

## 12. Tokens this screen cites

Every value below is the one the design system declares, so `design-check tokens-used` can re-derive it. Non-colour tokens are listed for completeness; only the colour rows are contrast-measured, and each measured figure is the design system's own worst-case figure for the token across the surfaces it is legal on.

| Token | Day | Night | Measured (day / night) | Where it appears here |
|---|---|---|---|---|
| `--color-background` | `#F5F2ED` | `#121315` | — | The page field under every full-bleed row |
| `--color-surface-sunken` | `#EBE7E0` | `#0C0D0F` | — | The E11 disclosure block; the disabled destructive row's label background; **the `Switch`'s track in its off state** (§ 2.9) |
| `--color-text-primary` | `#1A1714` | `#E8E4DD` | **14.48:1** / **12.00:1** | Row labels, the disclosure block's text |
| `--color-text-secondary` | `#5A524A` | `#A8A29A` | **6.22:1** / **6.01:1** | Value lines, group labels, the B38 line, the Language hint |
| `--color-text-disabled` | `#6E665C` | `#948E87` | **4.58:1** / **4.69:1** | The `Clear reading history` row when history is already empty |
| `--color-accent` | `#8A4B12` | `#E3A857` | **5.50:1** / **7.25:1** | Selected switch track, selected radio, selected sheet row, focus ring, the ghost link |
| `--color-warning` | `#8A5A12` | `#E0AC47` | **4.80:1** / **7.36:1** | The denied-notification line |
| `--color-error` | `#8A3228` | `#EE8B76` | **6.64:1** / **6.22:1** | `ErrorState` icon, the failed-write message |
| `--color-border` | `#D9D3C9` | `#2E3237` | exempt | 1dp rule **between rows inside a group**, and **the `Switch`'s thumb in its `disabled` state** (§ 2.9). Exempt per § 0.0 of the design system for the rule: it is a decorative separator, not a component boundary |
| `--color-border-field` | `#8F8778` | `#6B6560` | **3.18:1** / **3.24:1** | The selected sheet row's outline |
| `--color-border-focus` | `#8A4B12` | `#E3A857` | **6.07:1** / **8.86:1** | 2dp focus ring at 2dp offset on every row |
| `--color-surface-raised` | `#FEFCF9` | `#232629` | — | The snackbar host; **the `Switch`'s thumb, on and off** (§ 2.9) |
| `--color-text-inverse` | `#FDFAF6` | `#17181A` | **5.54:1** / **7.27:1** | Labels on the `--color-accent` fills |

Non-colour tokens cited: `--text-h4` `#18/24` at 600 (row labels); `--text-body-sm` `#14/20` at 400 (value lines, the disclosure block); `--text-caption` `#12/16` at 400 (the B38 line, the Language hint, the E11 footer, a "Count unavailable" fallback); `--text-overline` `#11/16` at 600 with `letter-spacing 0.08em` (group labels); `--space-2xs` `2dp` (rule inset inside a group); `--space-md` `12dp` (row internal padding, group label offset); `--space-lg` `16dp` (group label inset); `--space-xl` `24dp` (the gap that closes a group — larger than any gap inside it, per § 1.3); `--space-3xl` `48dp` (page top margin); `--border-width` `1dp` (the between-rows rule); `--border-width-strong` `2dp` (focus ring, pressed row edge); `--shadow-none` on every row; `--shadow-sheet` `0 8 24 rgba(0,0,0,0.18)` (snackbar); `--shadow-dialog` `0 16 48 rgba(0,0,0,0.24)` (the clear-history confirm dialog); `--radius-md` `8dp` (dialog and sheet); `--radius-lg` `16dp` (the E11 disclosure block); `--duration-fast` `120ms` (switch, radio, failed-write snap-back); `--duration-normal` `200ms` (push, sheet, dialog, snackbar); `--ease-standard` `cubic-bezier(0.2, 0, 0, 1)`; `--ease-accelerate` `cubic-bezier(0.3, 0, 1, 1)` (the snap-back, because a value being taken *back* should arrive quickly); `--bp-mobile` `< 600dp`, `--bp-tablet` `600–1023dp`, `--bp-desktop` `1024–1439dp`; touch target `48dp`.