---
type: screen
slug: onboarding
title: Onboarding
module: onboarding
status: draft
generated_at: 2026-10-02
derived_from:
  - .forge/prd.md
  - .forge/design/design-system.md
rule_ids: [B4, B7, B13, B26, B28, B29, B30, B35]
edge_case_ids: [E11, E12, E14]
flow: first-run
---

# Screen — Onboarding

> The source of truth for generating this screen. It is **two steps long and has no swipe gesture**, and both of those are decisions argued below. The PRD requires one thing here beyond the promise: the E11 disclosure, which cannot be deferred and cannot be abbreviated.

---

## 1. Role of the screen

| | |
|---|---|
| **App archetype** | `mobile_consumer` |
| **Module** | `onboarding` — **outside the tab structure**, a first-run flow reachable only by being needed once, and afterwards only deliberately from Settings |
| **Route** | `/onboarding` |
| **Type** | full page, **outside the shell** — no bottom nav, no title bar |
| **Users** | a reader on the day they install, and a borrowed-device reader who was lent the file |
| **User stories served** | US-05 (by anticipation), US-13 |
| **Business rules** | B4 B7 B13 B26 B28 B29 B30 B35 |
| **Edge cases** | E11 E12 E14 |

**In one sentence**: this screen teaches the reader the one thing they cannot guess about this app — **that it reads with no signal** — and tells them the one thing they must know before they start — **that nothing they download can be rescued**, in two steps they can skip in one tap.

**Why it is outside the nav**: `design-system.md` § 3.2 places Onboarding in overflow's rationale table with no label at all — it is a first-run flow, reachable from Settings, never a destination. A reader never *wants* to go to an onboarding screen; they either need it once or they deliberately re-read it.

---

## 2. Visual direction for this screen

| | |
|---|---|
| **Mood** | quiet, plain, unhurried — two sentences and a button |
| **Density** | **airy** — justified: this is the least dense surface in the app, and deliberately so. A reader who has just installed an app they were lent is deciding whether to trust it, and the signal for that decision is *scarcity*. Every control on this screen is a control they must accept the absence of |
| **Contrast level** | **high** — the promise sentence is `--color-text-primary` `#1A1714` / `#E8E4DD` at **14.48:1** / **12.00:1**, and it is set at `--text-h1` 31/38 at 700, **the only screen in the app that uses `--text-h1`**. A first-run screen that renders its promise in body text has already decided it is not the point of the app |
| **Surface** | `--color-background` `#F5F2ED` / `#121315`, with **one** `--color-surface-sunken` block — the E11 disclosure on step 2, recessed, for the same reason the reader's prose and the failure screen's blocks are recessed: it is a thing to look into, not a card to look at |
| **Accent used** | `--color-accent` `#8A4B12` / `#E3A857` — **only** on the active step dot, the `primary` button's fill, and the focus ring. It is on the button the reader presses and nowhere else |
| **Photographic treatment** | **none.** No illustration, no icon, no welcome graphic, no app screenshot, no progress-of-features carousel |
| **Reference** | a single well-set page — a promise and a consequence, then the door |

### 2.1 Anti-generic — mandatory

This screen must not resemble any of these defects:

- [x] **No pure white `#FFFFFF` background** — `--color-background` `#F5F2ED` / `#121315`.
- [x] **No shadowed card.** The disclosure is `--color-surface-sunken` with `--shadow-none`; there is no elevated card on either step.
- [x] **Not uniform.** `--text-overline` 11/16 at 600 with 0.08em for the kicker, `--text-h1` 31/38 at 700 for the promise, `--text-h2` 25/32 at 700 for the consequence headline, `--text-body` 16/24 for the sentence, `--text-body-sm` 14/20 for the disclosure, `--text-caption` 12/16 for the last clause. Four steps of the UI scale plus a label scale.
- [x] **No generic grey `#6B7280`** — the disclosure body is `--color-text-secondary`, the paper-anchored ramp.
- [x] **No symmetric centring.** Left-aligned in a single column with `--space-lg` 16dp margins, the promise at `--text-h1`, and **the controls in the bottom third** rather than centred in the middle of the screen. C11: this is read one-handed, often one-thumbed, in transit; a centred column of text with a button floating in the middle is the layout that makes a thumb reach across the screen for the wrong thing.
- [x] **No generic spot illustration** — and this is the screen where one is most expected. **There is no illustration, no icon and no screenshot**, because an illustration of "works offline" is decoration standing where an argument should be, and the design system's anti-references forbid it by name.
- [x] **Not one typeface at one weight** — sans chrome, three weights (700 headline, 400 body, 600 overline). The reader's serif is deliberately **absent**: no prose is being read here, and setting a serif specimen on a first-run screen would be showing off the reader before the reader exists.

**Assumed, non-neutral choice**: **two steps, and the second one is a consequence, not a feature.** `archetypes.md` § 2 names the trap for this archetype in four words — *onboarding too long* — and the generic answer is five cards: welcome, discover, download, organise, done, each one a feature restated. This screen refuses the feature tour entirely, for a reason that is specific rather than tasteful: **there is almost nothing to tour.** There is no account to create (B4), no source to install or authorise (ADR-013 — a static registry), no permission to grant (§ 4, *Offline / permissions*), no tour to take, no accounts screen to walk through, no settings wizard to complete. A feature tour in a product with no features to tour is five screens of teaching the reader that they are early, which is the opposite of what the screen is for.

So the screen teaches **one** thing, and the one thing is chosen by a test: *what would a reader get wrong and never notice?* A reader who has used this app for a week may still not know that a downloaded novel opens with no signal — because nothing about it announces itself, because offline reading is deliberately unannounced anywhere in this app (see `reader.md` § 4), and because a reader who never tests it never finds out. **That is the one thing worth two sentences.** The second step is not optional content either: E11 requires the disclosure on first run, and burying a disclosure in a settings page three levels down is how a disclosure stops being read.

**Four further decisions, each of which could have gone the other way:**

1. **No swipe.** The two steps are advanced by buttons, not by a horizontal pager. A horizontal pager fights the Android back gesture — a reader swiping back from step 2 expects to leave the app and gets a step change — and a swipe target at the bottom third of the screen is a target that fights the button above it. The step dot pair says *there are exactly two*, which is the only thing a pager would have communicated.
2. **`Skip` is on step 1, not on step 2.** Step 2 *is* the disclosure, and skipping a disclosure while showing it is a contradiction. So `Skip` exists once, on step 1, and step 2 has only **Start reading** and the system back gesture. The reader is therefore never offered a way to dismiss the disclosure without reading it — which is not paternalism; it is the difference between disclosing and displaying.
3. **The primary action on step 1 is `Next`, not `Get started`.** A button that reads "Get started" on a screen with a second step behind it teaches the reader that the button is a lie.
4. **No settings on first run.** Every setting keeps its default, and every default is visible and changeable in Settings afterwards. A first-run configuration wizard is the standard mechanism by which apps collect answers to questions the reader had not thought about — including, in other products, an analytics opt-in. This one asks nothing.

---

## 3. Anatomy

```
OnboardingScaffold (no titleBar, no bottomNav, outside the shell)
└── OnboardingBody                     single column, --space-3xl top, controls in the bottom third
    ├── StepDots                        2 × --radius-full 8dp
    │                                   inactive --color-border-field, active --color-accent
    │
    │   ── STEP 1 ──────────────────────────────────────────────
    ├── Kicker                          "LUMEN TALE"        --text-overline 600, 0.08em
    ├── PromiseHeadline                 --text-h1 31/38 700
    │                                   "It reads with no signal."
    ├── PromiseBody                     --text-body 16/24, measure capped, 2 sentences
    │                                   "Keep a novel here once and it opens with the
    │                                    connection switched off — on a train, on a plane,
    │                                    with no data used. Nothing is uploaded: there is no
    │                                    account, no server, and nothing is sent anywhere."
    │
    │   ── STEP 2 ──────────────────────────────────────────────
    ├── Kicker                          "BEFORE YOU START"  --text-overline 600, 0.08em
    ├── ConsequenceHeadline              --text-h2 25/32 700
    │                                   "There is no backup."
    ├── DisclosureBlock                 --color-surface-sunken, --shadow-none
    │   ├── disclosureBody               --text-body-sm 14/20
    │   │      "Nothing here is backed up. If you uninstall Lumen Tale or lose this
    │   │       phone, your library, your downloads and your reading positions are
    │   │       gone, and no copy exists anywhere."
    │   └── disclosureFootnote           --text-caption 12/16
    │          "The app cannot warn you at the moment you uninstall — the phone does
    │           that, outside the app. So it is said here, before, not after."
    │
    └── ControlBlock                    anchored in the bottom third
        ├── [text] Skip                 step 1 only — --color-accent label, 48dp
        └── [primary] Next  /  Start reading     --color-accent fill, --color-text-inverse
                                          --radius-md 8dp, md 44dp, full width
```

| # | Component | Role | Source |
|---|---|---|---|
| 1 | `OnboardingScaffold` | Page with **no** title bar and **no** bottom nav | design-system § 2.8, used with three slots empty |
| 2 | `StepDots` | Position only — two dots, one active | slice-local; `--radius-full`, 8dp |
| 3 | `DisclosureBlock` | The E11 statement, recessed, with no icon | design-system § 2.7 idiom, `--color-surface-sunken`, **no icon** |
| 4 | `PrimaryButton` / `TextButton` | `Next`, `Start reading`, `Skip` | design-system § 2.3 |
| 5 | `GroupLabel` — used as `Kicker` | `--text-overline` uppercase step kicker | design-system § 1.2 |

> **No icon is rendered on either step.** `EmptyState`, `ErrorState` and `LoadingState` are all absent — there is no empty, no error and no loading on this screen, and § 4 says why for each.

---

## 4. States — all nine, no exceptions

| State | Trigger | Rendering | Reader feedback |
|---|---|---|---|
| **Loading** | n/a, and the reason is load-bearing | **There is no loading state and no skeleton.** Every string on both steps is a compile-time resource in the app's ARB, so there is nothing to fetch. **The real cold-start decision happens in the router, before this screen is built:** if the "onboarding seen" flag cannot be read, the app **shows onboarding**. Showing two sentences to a reader who has already seen them is recoverable; never showing them to one who has not is not | None, and the absence is correct. A spinner on a page of static words is a spinner the reader would have to wait through for nothing |
| **Filled** | Step 1, the normal first-run state | The promise at `--text-h1`, two sentences, `Skip` and `Next` | None |
| **Empty — never visited** | **This screen *is* the never-visited state.** It is unreachable after the first run unless the reader asks for it from Settings | When it is **re-entered from Settings it opens on step 2, not step 1.** The promise has been read and either worked or not; the disclosure is the part a re-reader may have skipped, and it is the part with consequences. The title bar shows `How this app works` rather than nothing, and the kicker on step 1 is bypassed rather than shown and dismissed | The re-entry path is **better than the first-run path**, deliberately. A "replay the tutorial" button that replays the tutorial in the same order teaches the reader that the screen is a loop |
| **Empty — no data** | n/a | **Not applicable, and the reason is precise.** This screen reads no data — no library, no sources, no settings, no network — so it cannot be in a no-data state. The nearest empty it could meet is the app's own empty library, and it deliberately **does not render it**: the handoff target is `/library`, whose `EmptyState` instance `library-empty` is the design system's named rendering for exactly that, and duplicating it here would be a second rendering of one fact | The reader reaches the empty library on the **Library tab**, where it belongs, with its own call to action. Onboarding's job ends when it opens the door |
| **Load error** | The "onboarding seen" flag **cannot be read** at cold start — a genuine failure, and the one this screen must handle | There is nothing to render an error into. The app **shows onboarding**, because the failure of a *flag* must not skip a *disclosure*. The disclosure is the safety-relevant content and the cost of showing it twice is two sentences | Nothing on screen, by necessity. Recorded here rather than left blank because it is a decision about which way a failure goes |
| **Submit error** | The **only submission this screen has** is writing the "seen" flag, and it fails | Nothing to show, because the reader is already leaving. The button returns from its `loading` state to its default over `--duration-fast` 120ms, **the transition to `/library` happens anyway**, and the flag failing to persist means onboarding is shown **once more** next launch. A failing flag must never trap the reader in onboarding: the screen is skippable, and a flag that can re-show a skipped screen is a bug, not a safety | The reader is never told their skip did not save. Telling them would mean an error about a preference they do not have and cannot act on — and the retry would be "skip again", which is what they just did |
| **Success** | The reader reaches step 2 and presses **Start reading** | The handoff: a standard `--duration-normal` 200ms push to `/library`, whose `library-empty` state offers **Browse sources**. No toast, no "Welcome!", no confetti, no "You're all set" — anti-references forbid the celebration, and this app has no achievement to congratulate | The screen's success **is** the arrival somewhere else. Anything added on the way out would delay the first thing the reader actually came to do |
| **Offline / permissions** | No connection, or any OS permission state | **Identical to Filled, with zero variation and zero network calls.** And **no permission is requested, ever, here** — which is the decision this row defends. The app needs no storage permission for its own directory; `POST_NOTIFICATIONS` is requested at the moment the reader turns the update schedule on, in Settings; and because **B35 makes that schedule off by default**, at first run there is nothing the reader has yet decided they want. **A first-run permissions screen would therefore be requesting something the reader has not asked for** — and on Android 13+ a request shown before its context is a request the reader is primed to refuse, which is how an app ends up without the one permission it will later need | The strongest argument for this screen's length is a permission argument: **B35's off-by-default schedule is what proves that permissions do not belong on first run.** There is no permission to ask for, so a screen asking is a lie |
| **Read-only** | Step 1, entirely | **Step 1 has no controls that configure anything.** There is no toggle, no picker, no choice, no consent box — the two sentences are read and either believed or not, and the reader moves on. Nothing on either step writes a preference | Read-only because a first-run screen that collects answers is how a product acquires consent nobody requested. This screen collects **no** answer, which is also why it needs no settings screen for them to land in |

### 4.1 User-visible copy — both languages (B28)

The disclosure is **translated in full and not shortened**, which is the one place in this app where a compressed translation would be a weaker disclosure. Everything else is short by design and translates without loss.

| Key | English | Français |
|---|---|---|
| `step1.kicker` | `LUMEN TALE` | `LUMEN TALE` |
| `step1.headline` | `It reads with no signal.` | `Il lit sans réseau.` |
| `step1.body` | `Keep a novel here once and it opens with the connection switched off — on a train, on a plane, with no data used. Nothing is uploaded: there is no account, no server, and nothing is sent anywhere.` | `Gardez un roman ici une fois et il s'ouvre, connexion coupée — dans un train, dans un avion, sans DATA consommée. Rien n'est envoyé : il n'y a pas de compte, pas de serveur, et rien ne part.` |
| `step2.kicker` | `BEFORE YOU START` | `AVANT DE COMMENCER` |
| `step2.headline` | `There is no backup.` | `Il n'y a aucune sauvegarde.` |
| `step2.disclosure` | `Nothing here is backed up. If you uninstall Lumen Tale or lose this phone, your library, your downloads and your reading positions are gone, and no copy exists anywhere.` | `Rien ici n'est sauvegardé. Si vous désinstallez Lumen Tale ou perdez ce téléphone, votre bibliothèque, vos téléchargements et vos positions de lecture sont perdus, et aucune copie n'existe ailleurs.` |
| `step2.footnote` | `The app cannot warn you at the moment you uninstall — the phone does that, outside the app. So it is said here, before, rather than after.` | `L'application ne peut pas vous avertir au moment où vous désinstallez : c'est le téléphone qui le fait, en dehors de l'application. C'est donc dit ici, avant, plutôt qu'après.` |
| `button.next` | `Next` | `Suivant` |
| `button.start` | `Start reading` | `Commencer à lire` |
| `button.skip` | `Skip` | `Passer` |
| `button.replayLabel` | `How this app works` | `Comment fonctionne cette application` |
| `button.replayValue` | `Show the two introduction screens again` | `Revoir les deux écrans d'introduction` |

> The `step1.body` sentence is the product's one-line promise from the PRD, carried verbatim in meaning and reworded for a first run: *read a web novel once, and it stays readable without a signal*. It is the only marketing sentence in the app, and it is a promise about behaviour rather than a claim about the app's qualities.

> **Four of the nine have no rendering, and each says why**: nothing loads, there is no data to be empty, there is no submission that can fail visibly to the reader, and the screen's read-only half is read-only by choice. What remains — the promise, the disclosure, two buttons, and where they lead — is the whole of what a new reader cannot guess.

---

## 5. Interactions

| Element | Event | Behaviour | Visual feedback | Resulting state | Rule |
|---|---|---|---|---|---|
| `Next` | tap | Advance to step 2 **in place** — the same widget swaps its content; it is not a route push and there is no back stack entry | Content change `--duration-normal` 200ms `--ease-standard`; the active dot moves | Filled, step 2 | — |
| `Skip` | tap | Write the seen flag, then transition to `/library` **immediately, without visiting step 2** | — | Library | — |
| `Start reading` | tap | Write the seen flag, then push `/library` | Standard push `--duration-normal` | Library | — |
| System back gesture / back button on **step 1** | back | **The same as `Skip`.** Exiting onboarding is never a trap and never a prompt — no "are you sure you want to skip", which is a dialog that exists only to make someone feel they have chosen | — | Library | — |
| System back gesture / back button on **step 2** | back | **Returns to step 1, and does not exit.** The disclosure is not dismissible by accident, and the reader can go back and re-read the promise | Content change | Filled, step 1 | **E11** |
| — on **step 2** | — | **There is no `Skip` and no dismiss affordance.** Only the back gesture, which goes backwards | — | — | **E11** |
| Swipe horizontally | gesture | **Ignored.** No pager, no carousel, no horizontal drag | — | Unchanged | — |
| Swipe up / scroll | gesture | Vertical scroll only, and on both steps the content fits without scrolling at the default text size. It scrolls at 200% OS text scale and **nothing is clipped** | — | Unchanged | **E14** |
| OS font-size change | system | Both steps re-flow immediately; the `--text-h1` promise shrinks with the OS setting rather than ignoring it | Instant | Unchanged | **E14** |
| OS light/dark change | system | Both steps re-theme immediately — the default override is `system` (B26), so a reader who has set their phone to dark never sees this screen light | Instant | Unchanged | **B26** |
| OS language change | system | Both steps re-localise immediately, **including the disclosure**, which is the one piece of text on this screen that must never be read in a language the reader does not read | Instant | Unchanged | **B28**, E12 |

- **Focus / keyboard**: reading order — the dot pair (not focusable; it carries no action), the headline, the body, then the controls. **Every text block on this screen is announced**, including the disclosure footnote, because this is one of the two places the app speaks at the reader without being asked. `Enter` on the focused button activates it; `Esc` behaves as the back gesture. Focus is visible at 2dp `--color-border-focus` with a 2dp offset and is never removed.
- **Gestures**: **no horizontal swipe at all**, and the reason is in the ADR-adjacent text of § 2.1: a pager competes with the system back gesture, and on step 2 a horizontal swipe would be a second route out of a disclosure that is supposed to have one. Vertical scroll only.
- **Animations**: `--duration-normal` 200ms `--ease-standard` for the step change and the handoff push. **No entrance animation on either step** — the first thing on screen after installing an app is the sentence, not the sentence arriving. `--radius-full` dots do not pulse or breathe. Every duration becomes `0ms` under reduce-motion.
- **Back**: described above, and it is the one place on any screen in this app where back does not mean "leave" — on step 2 it means "read the promise again".

---

## 6. Responsive

| Breakpoint | Behaviour | What collapses or disappears |
|---|---|---|
| **Mobile** `< 600dp` | Single column, `--space-lg` 16dp margins, `--space-3xl` 48dp top margin. The promise paragraph is capped at the same 65–75 character measure the reader uses, because a promise set across a phone's full width is one line per clause. **`primary` is full width**; `Skip` sits directly above it, left-aligned, 48dp tall, so both controls are in the bottom third within thumb reach | Nothing. This is the design target |
| **Tablet** `600–1023dp` | Identical single column, centred, **capped** — the paragraph measure does not widen and the `primary` button does not stretch to 800dp. **Explicitly not a tablet layout** (ADR-010) | Nothing collapses — the layout simply stops widening |
| **Desktop** `1024–1439dp` | Same single column, centred, same cap. Flutter desktop is out of scope | — |

- **Touch target**: **48dp minimum on both controls**, and both are in the bottom third of the screen. `Skip` is 48dp tall despite being a `text` button, because it is the way out for a reader who does not want to be walked through anything.
- **Overflow**: **guaranteed never to overflow.** The headline wraps to two lines at `--text-h1` before it truncates — and it does not truncate, because the promise is the screen. The body paragraph wraps; the disclosure wraps; the footnote wraps. At 200% OS text scale the page grows and scrolls, and **the control block stays at the bottom of the content rather than floating over it**, so a long disclosure is never covered by a button.

---

## 7. Accessibility

- [x] **Contrast 14.48:1** (day) / **12.00:1** (night) for the promise headline and the body — `--color-text-primary` on `--color-background`, measured, not asserted.
- [x] **Contrast 6.22:1** / **6.01:1** for the disclosure body and the footnote — `--color-text-secondary` on `--color-surface-sunken`. This is **body text and the most consequential text on the screen**, so it is `--text-body-sm` 14/20 in a weight of 400 and never caption grey; the `--text-caption` is only the *reason the disclosure is here now* rather than later
- [x] **Contrast 5.54:1** / **7.27:1** for the `primary` label — `--color-text-inverse` on `--color-accent`.
- [x] **Contrast 6.07:1** / **8.86:1** for the focus ring — `--color-border-focus`, measured as non-text per WCAG 1.4.11.
- [x] **Contrast 3.18:1** / **3.24:1** for the inactive step dot** — `--color-border-field`, and the choice is argued: the design system exempts `--color-border` because it is a decorative rule, but a dot is a **UI component indicating position**, not a separator, so claiming the exemption here would be a false claim of the kind the design system explicitly warns about. `--color-border-field` is the token the design system declares for a component boundary, and it clears 3:1.
- [x] **No state is carried by colour alone**: step position is a filled dot **and** the step's own kicker text (`LUMEN TALE` / `BEFORE YOU START`), and only two steps exist, so position is unambiguous even with no colour at all.
- [x] **Keyboard navigation complete** at every breakpoint; both controls reachable and operable; focus visible at 2dp with a 2dp offset, never removed.
- [x] **Every text block is announced**, and the disclosure is announced as a distinct region — **not** as trailing text. A screen-reader user must not be able to reach step 2 and hear the consequence headline without the disclosure following it.
- [x] **Text size is never below the floor**: the smallest type on either step is `--text-caption` `#12/16`, and every text block is **below 16px-capable wrapping, not below it** — the caption is a footnote to a 14px body, and the body sits under a 31px headline. `--text-body` at `#16/24` carries the promise; nothing on this screen asks the reader to read at a size this design would refuse in the library.
- [x] **Reading order and language correct**: both steps exist in French and English, the French falling back for an unrecognised locale (B28). **The disclosure is translated, not paraphrased** — it is the one string in the app where a shorter translation would be a weaker disclosure. `dir` follows the language; no RTL source exists in v1.
- [x] **Reduce-motion honoured**: the step change and the handoff become instant; there is no entrance animation to disable.

---

## 8. Data

| Field | Type | Origin | Required | Possible error |
|---|---|---|---|---|
| `onboardingSeen` | `bool` | local, `shared_preferences` | yes | **Read failure → onboarding is shown.** That is the deliberate direction: the flag failing must not skip the disclosure. Write failure → the screen transitions anyway and is shown once more next launch |
| `strings` | `localised` | ARB resources, resolved for the active locale | yes | Absent → the router cannot build either step; this is a build-time defect, caught by the localisation gate, not a runtime state |
| `locale` | `Locale` | platform, read-only | yes | Unrecognised → **French** (B28) |
| `mediaQueryTextScale` | `double` | platform | yes | Absent → `1.0` |
| `phoneBrightnessSetting` | — | **not read** | — | The app never reads the phone's brightness. The "reads at night" comfort of this app is delivered by B26's dark theme, not by an app that tries to change the screen brightness behind the reader's back |

- **Loading**: **nothing is loaded.** Two ARB strings, one boolean, one locale. The screen has no network path and no paging and no local query beyond the flag.
- **Cache / offline**: **the entire screen works with no connection**, which is thematically not a coincidence — the first thing this app says about itself is that it works with the connection off, so an onboarding screen that needed a connection would be an embarrassment as well as a defect.
- **Sensitive data**: **nothing is stored by this screen except one boolean**, and no value is read, logged, or transmitted. No library, no source, no identifier, no permission state, no device information. The screen that teaches "nothing leaves this device" is itself the screen with the least data in the entire product — one flag — which is the only way its claim can be believed when the reader arrives at the About screen and reads the rest.

---

## 9. Traceability

| ID | Origin | Manifestation on this screen |
|---|---|---|
| B4 | PRD | **Step 1's body names it in half a sentence** — *"no account, no server"* — because a reader who expects a sign-in wall on an app they were lent is looking for one, and finding none is worth saying out loud. There is no sign-in screen to reach, nothing to sign in to, and no identity stored |
| B7 | PRD | **The promise.** *"Keep a novel here once and it opens with the connection switched off — on a train, on a plane, with no data used."* Named as the headline because it is the one thing a reader cannot guess: the app never announces that it works offline, on purpose |
| B13 | PRD | The promise is stated **only about chapters the reader already has**, never about the whole site. Nothing here implies the app can fetch anything without being asked (B5), which is the same boundary B13 draws around new chapters |
| B26 | PRD | The screen renders in the phone's light/dark setting by default, so a reader who has set their phone to dark is never shown a bright first-run screen — and the promise about reading comfortably at night is a consequence of this, not a separate feature |
| B28 | PRD | Both steps exist in French and English, French as the fallback. **The E11 disclosure is translated in full and not shortened**, because a compressed disclosure is a weaker disclosure, and this screen is one of only two places it appears |
| B29 | PRD | *"Nothing is uploaded: there is no account, no server, and nothing is sent anywhere."* — one clause of one sentence, and the first time the reader is told. The full argument and the test that falsifies it are on the About screen |
| B30 | PRD | **Nothing can be shared, exported or backed up out of this app**, and step 2 says so in the reader's own terms before they have anything to lose. The absence is disclosed on day one rather than discovered on the day they need it |
| B35 | PRD | **The proof that no permission belongs on first run.** The update schedule is off by default, so the notification permission that a schedule would need has no context at first run. A first-run permission screen would be asking for something the reader has not yet decided they want — which is why this screen asks for nothing |
| E11 | PRD | **Step 2, in full, with no way to skip it.** The disclosure names the library, the downloads and the reading positions; states that no copy exists anywhere; and states **why it is being said now** — *"the app cannot warn you at the moment you uninstall; the phone does that, outside the app"*. System back on step 2 returns to step 1 rather than leaving, so the disclosure is never dismissed by a stray gesture |
| E12 | PRD | An OS language change re-localises both steps immediately, **disclosure included** |
| E14 | PRD | An OS font-size change re-flows both steps immediately; the headline shrinks with it, nothing truncates, and the page scrolls rather than clipping at 200% |
| C4 | PRD | **No content is requested at first run.** Nothing is fetched, no source is contacted, no source is even named — the first network call this app ever makes is the one the reader asks for by browsing |
| C11 | PRD | Both controls are in the bottom third at 48dp minimum, for a reader who is one-handed and often in transit |
| C13 | PRD | A borrowed-device reader is lent a file and nothing else. There is no per-user data, no shared library and no migration, so first run on the second device is the same first run |

---

## 10. Gate checklist

- [x] All nine states described, with a concrete rendering. The four with nothing to render say **why** they have none — and each of those reasons is a decision (nothing loads, nothing to be empty, nothing to submit, nothing to configure).
- [x] Every interactive element has a behaviour, a feedback, a resulting state and a rule ID.
- [x] Responsive defined at **every** breakpoint in the design system — and the two larger ones say "identical, stop widening", which is ADR-010.
- [x] Anti-generic section checked **and justified**; the assumed choice is stated: **two steps, the second a consequence rather than a feature, no swipe, and no settings.**
- [x] No design value left "to be defined". Every colour, size, duration and easing cited exists in `design-system.md` with a value.
- [x] Every B/E/C ID on this screen appears in § 9.
- [x] `forge-guard placeholders` reports nothing here.
- [x] Consistent with `design-system.md`: the only screen using `--text-h1`, and it uses it for the promise — the one sentence this product exists to make.
- [x] **Every token cited by this screen exists in the design system, with the value it is given here.** The full citation table is § 12.
- [x] **Skippable, and re-reachable**: `Skip` and the back gesture both leave on step 1; Settings → *How this app works* reopens it, at step 2.

---

## 11. Deliberately absent — and why that is not a gap

| Absent | Rule / ADR | Why |
|---|---|---|
| Sign-in, account creation, "continue with…" | **B4** | There is no account. A first-run screen whose job is to create an identity is the wrong screen for a product whose entire claim is that it stores no identity |
| A permissions screen, and any permission request | C11, B35 | **There is nothing to ask for.** Storage needs no runtime grant for the app's own directory, and the one permission that would ever be needed — notifications for the update check — belongs to a feature that is **off by default (B35)**, so it has no context at first run. A permissions screen here would be a lie about what the app needs in order to read a novel |
| A source-install or source-authorisation flow | **ADR-013** | Sources are a **static registry**. There is no marketplace, no extension installer, no repository, no permission to grant a website. A screen asking the reader to trust a catalogue would be describing a product that does not exist |
| A feature tour: discover, download, organise, statistics, sync | PRD § 9 | **There is almost nothing to tour.** No account, no source install, no permission, no sync, no social, no purchase. Five cards restating five features would teach the reader that they are early, which is the opposite of the one thing worth teaching |
| A "what's new" or changelog carousel | B34, C9 | No store, no remote channel, and nothing fetched — a first-run screen that needed a connection to show its own changelog would contradict step 1 |
| A "rate the app" or "share the app" row | B30 | B30 governs what leaves the app, and B29 governs what is transmitted. There is no store to rate in and nothing to share |
| Analytics consent, a crash-reporting opt-in, a "personalise your experience" toggle | **B29** | Consent implies something to consent to. Nothing is collected, so there is nothing to ask about, and a first-run toggle that starts **on** is the mechanism by which products acquire permission they were never given |
| A "choose your reading goal", "how many novels a day", "pick your favourite genres" step | anti-references | Gamification, reading streaks and progress framing are all refused by the design system's anti-references. v1 keeps nothing that would need a goal |
| Font size, theme and appearance pickers at first run | ADR-009, B26, B27 | Both values have defaults that work — `system` and `md` — and B26/B27 mean the app already follows the phone for both. Asking at first run is asking the reader a question they have already answered in their settings |
| An app icon, a logo mark, a "made by" line | B4 | No operating entity to name. And a logo on a first-run screen is decoration standing in for the argument |
| Any horizontal swipe, pager, or carousel | — | Argued in § 2.1: it competes with the system back gesture, and on step 2 it would be a second exit from a disclosure meant to have one |

---

## 12. Tokens this screen cites

Every value below is the one the design system declares, so `design-check tokens-used` can re-derive it. Only the colour rows are contrast-measured, and each figure is the design system's own worst-case figure for that token across the surfaces it is legal on.

| Token | Day | Night | Measured (day / night) | Where it appears here |
|---|---|---|---|---|
| `--color-background` | `#F5F2ED` | `#121315` | — | The page field behind both steps |
| `--color-surface-sunken` | `#EBE7E0` | `#0C0D0F` | — | The E11 disclosure block on step 2 |
| `--color-text-primary` | `#1A1714` | `#E8E4DD` | **14.48:1** / **12.00:1** | The promise headline, the consequence headline, the body paragraph |
| `--color-text-secondary` | `#5A524A` | `#A8A29A` | **6.22:1** / **6.01:1** | The disclosure body and its footnote |
| `--color-text-inverse` | `#FDFAF6` | `#17181A` | **5.54:1** / **7.27:1** | The `primary` **Next** / **Start reading** label, on the accent fill |
| `--color-accent` | `#8A4B12` | `#E3A857` | **5.50:1** / **7.25:1** | The `primary` fill, the active step dot, the `Skip` label, the focus ring |
| `--color-border-field` | `#8F8778` | `#6B6560` | **3.18:1** / **3.24:1** | The **inactive step dot**. Not `--color-border`, whose `exempt` declaration is reserved for decorative rules between rows — a dot is a component boundary, and claiming the exemption here would be a false claim |
| `--color-border-focus` | `#8A4B12` | `#E3A857` | **6.07:1** / **8.86:1** | 2dp focus ring at 2dp offset on both controls |
| `--color-error` | `#8A3228` | `#EE8B76` | **6.64:1** / **6.22:1** | **Not rendered** — recorded because its *absence* is a decision: the disclosure is a standing consequence, not an incident, and colouring it red would make a permanent fact look like a current failure |

Non-colour tokens cited: `--text-h1` `#31/38` at 700 (the promise — **the only use of `--text-h1` in the app**); `--text-h2` `#25/32` at 700 (the consequence headline); `--text-body` `#16/24` at 400 (the promise paragraph); `--text-body-sm` `#14/20` at 400 (the disclosure body — the most consequential text on the screen, and deliberately not caption size); `--text-caption` `#12/16` at 400 (the disclosure footnote, "why it is said now"); `--text-overline` `#11/16` at 600 with `letter-spacing 0.08em`, uppercase (the two step kickers); `--space-lg` `16dp` (page margin, between the control block and the content); `--space-xl` `24dp` (between the headline and its paragraph); `--space-2xl` `32dp` (inside the disclosure block); `--space-3xl` `48dp` (page top margin, and the gap above the control block); `--radius-md` `8dp` (the `primary` button); `--radius-full` `999dp` (the two step dots, 8dp diameter, 8dp apart); `--shadow-none` on both steps and on the disclosure block; `--duration-normal` `200ms` (the step change, the handoff push); `--ease-standard` `cubic-bezier(0.2, 0, 0, 1)`; `--duration-fast` `120ms` (a button returning from `loading` after a failed flag write); `--bp-mobile` `< 600dp`, `--bp-tablet` `600–1023dp`, `--bp-desktop` `1024–1439dp`; touch target `48dp`.