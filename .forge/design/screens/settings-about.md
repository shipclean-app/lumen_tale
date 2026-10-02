---
type: screen
slug: settings-about
title: About Lumen Tale
module: more
status: approved
generated_at: 2026-10-02
derived_from:
  - .forge/prd.md
  - .forge/design/design-system.md
rule_ids:
  - B4
  - B29
  - B30
  - B31
  - B34
  - B43
  - B47
edge_case_ids:
  - E11
flow: settings-flow
---

# Screen — About Lumen Tale

> The source of truth for generating this screen. It has **two readers**, and the design serves both: the owner, who installs a new file by hand and needs to know what changed (B43, C5), and a borrowed-device reader who needs to be able to describe the app in words to someone who can fix it (C12). It is also the only screen in the app where a claim about *absence* has to be made visible — which is what the two blocks in its lower half are for.

---

## 1. Role of the screen

| | |
|---|---|
| **App archetype** | `mobile_consumer` |
| **Module** | `more` — **rank 5 of 5**; three levels below the bottom nav |
| **Route** | `/more/settings/about` |
| **Type** | full page with a title bar, pushed inside the More shell |
| **Users** | the reader — and, second and more often, **the owner**, who is also the only person who can repair it |
| **User stories served** | US-17, and US-13 by inversion (B28) |
| **Business rules** | B4 B29 B30 B31 B34 B43 B47 |
| **Edge cases** | E11 |

**In one sentence**: this screen tells the reader which version of the app is on their phone, tells them what installing the next one will and will not do to their data, and states — in a form they can check themselves — that nothing they read has ever left the device.

**Why it is three levels below the nav**: frequency 1, centrality 1. It is a **reference surface, not a destination** — the reader comes when something is wrong or when they want to know what they are running. It is nonetheless the screen this product is most defensible on, because `benchmarks.md` `design-system.md` § 2.3 records that the single most-complained-about failure across the commercial competitors is data loss around a reinstall ("will not restore after a reinstall"), and B31 makes that failure structurally impossible. **A guarantee nobody can check is a claim. This screen exists to make it checkable**, and it does that by showing the three numbers that prove it, in `design-system.md` § 3.

---

## 2. Visual direction for this screen

| | |
|---|---|
| **Mood** | plain, declarative, evidentiary |
| **Density** | **airy** — justified: this is the one screen made of statements rather than controls, and each statement needs room to be read once and believed. Six blocks separated by `--space-2xl` 32dp, each a small island on `--color-background` |
| **Contrast level** | **high** — `--color-text-primary` `#1A1714` / `#E8E4DD` at **14.48:1** / **12.00:1** for every statement; `--color-text-secondary` `#5A524A` / `#A8A29A` at **6.22:1** / **6.01:1** for the qualifying clauses |
| **Surface** | `--color-background` `#F5F2ED` / `#121315`. **Three of the six blocks sit on `--color-surface-sunken`** — the update notice, the data counts, and the E11 statement — because they are recessed facts to look *into*, not cards to look *at*. There is no `--color-surface-raised` anywhere on this screen except the snackbar |
| **Accent used** | `--color-accent` `#8A4B12` / `#E3A857` — **only** on the one text action, the `primary` install button's label context, and the focus ring. The version number is **not** in the accent: making the version amber would make it the most prominent thing on the screen, and it is not the most important thing |
| **Photographic treatment** | **none.** No logo lockup, no banner, no icon wall of privacy badges |
| **Reference** | an About screen from an offline-first tool — a version string, a build number, and the things the program will not do with your files, written in the plain declarative and given the same weight as the features |

### 2.1 Anti-generic — mandatory

This screen must not resemble any of these defects:

- [x] **No pure white `#FFFFFF` background** — `--color-background` `#F5F2ED` / `#121315`.
- [x] **No shadowed card for everything.** Six blocks, `--shadow-none` on all of them, separated by space. The only shadow on the screen is `--shadow-sheet` on the snackbar. An About screen built from six elevated cards reads as a marketing page, which is the opposite of what a reader is being told here.
- [x] **Not uniform.** `--text-h2` 25/32 700 for the one title, `--text-h3` 20/26 600 for the version, `--text-body` 16/24 400 for the statements, `--text-caption` 12/16 for the qualifying clauses, `--text-overline` 11/16 at 600 with 0.08em letter-spacing for the six block labels. A 1.25 scale plus a label scale.
- [x] **No generic grey `#6B7280`** — the qualifying clauses are the paper-anchored `--color-text-secondary`.
- [x] **No symmetric centring as the layout.** The page is left-aligned. Only the version line's three counts are laid out as a row, and only because three numbers beside each other are three facts; they are left-aligned within that row.
- [x] **No generic spot illustration.** In particular, **no shield-of-privacy icon as a badge, and no row of trust logos.** The privacy block is a list of seven named things with a `--color-success` check beside each, because the alternative — one shield meaning "your data is safe" — is an assertion the reader has to trust, and this screen's whole purpose is to give them something better than trust.
- [x] **Not one typeface at one weight** — sans chrome at four sizes and two weights; nothing else is on the page, and the contrast of scale carries it.

**Assumed, non-neutral choice**: **B29 is stated as an experiment the reader can run in thirty seconds, not as a promise.** The privacy block's last line is an instruction, not a reassurance:

> **EN** — *Check it yourself: switch the phone to airplane mode, then open the app. Your library, your downloads and your reading positions are all there. Nothing is missing, because nothing was ever sent.*
> **FR** — *Vérifiez vous-même : passez le téléphone en mode avion, puis ouvrez l'application. Votre bibliothèque, vos téléchargements et vos positions de lecture sont tous là. Il ne manque rien, parce que rien n'a jamais été envoyé.*

**And the copy is falsifiable because it is the app's own promise.** B29 claims nothing leaves; B7 and C14 claim the app works with the radio off. Those are the same measurement, so a reader who runs the test does not take a statement on trust — they watch the app do the thing it said it would do, in the one condition where doing it would be impossible if anything had ever been sent. This is the only screen in the app where a privacy claim can be **tested rather than trusted**, and the test costs thirty seconds and no data.

This is the assumed, non-neutral part, and it is contestable. Every app claims not to track you; the claim costs the reader nothing to disbelieve and is impossible to falsify from the UI. Here the claim is made **falsifiable by the product's own behaviour**: the app's entire value is that it works with the radio off (B7, C14, SC-2), so the privacy guarantee and the product promise are *the same measurement*. If B29 were ever violated, this sentence would stop being true — the app would start needing the connection it claims not to need. The screen does not ask to be believed; it hands over a test that costs no data and takes half a minute.

**Three more decisions, stated because each could have gone the other way:**

1. **"A newer version is available" is a block on this page, not a dialog, not a snackbar and not a notification.** An update notice that interrupts is an update notice that gets dismissed unread; and C5 says the only technical user cannot write code, so the one moment the app most needs to reach her is the moment she is least willing to be interrupted. It also does not auto-check: the app never contacts anything on its own account, not for updates and not for telemetry (§ 11).
2. **The three data counts are here, not in a stats screen.** They are not curiosity and they are not gamified — they are the **evidence for B31**. A guarantee that an upgrade preserves the library is worth nothing without a way to see that it did, so the counts must sit on the same page as the version that would have destroyed them.
3. **There is no "What we collect" section, because there is no "we".** No company name, no team, no contact address, no terms link, no privacy policy link pointing at a website that does not exist. B4 means there is no operator identity to publish. An About screen with a company footer would be a lie about who runs the software.

---

## 3. Anatomy

```
AppScaffold (titleBar "About Lumen Tale", bottomNav kept)
└── AboutBody                            --space-3xl top margin, single column
    ├── AboutIdentity
    │   ├── aboutTitle                  "Lumen Tale"          --text-h2
    │   ├── versionLine                 "0.9.0 · build 41"    --text-h3
    │   ├── versionProvenance           --text-caption        "Android phone · built
    │   │                                                        automatically · no store"
    │   └── ghost TextButton            "Copy version number" → clipboard
    │
    ├── UpdateBlock                     ONLY while an update is known to exist
    │   │                               --color-surface-sunken
    │   ├── system_update_alt icon, --color-info
    │   ├── "Version 0.10.0 is available."           --text-h3
    │   ├── "You have 0.9.0 (build 41)."             --text-caption
    │   ├── guaranteeLine                --text-body  ← B31, the whole point
    │   │      "Installing it keeps your library, your downloads, your reading
    │   │       positions and your history. Nothing is replaced or re-downloaded."
    │   ├── apkProgressLine              ONLY while the file is downloading
    │   │      determinate, --color-accent, 2dp   ← inside this block, NOT the
    │   │                                              persistent status bar
    │   └── [primary] Install the update / [secondary] Download the file
    │       + [ghost] Not now
    │
    ├── DataBlock                       --color-surface-sunken
    │   ├── overline "YOUR DATA ON THIS DEVICE"
    │   ├── countRow × 3                 Library 14 · Downloaded chapters 512 ·
    │   │                                Reading positions 638     ← the B31 evidence
    │   ├── guaranteeLine
    │   └── disclosureLine               ← E11, in full, stated here rather than
    │                                        pointed at from Settings
    │
    ├── PrivacyBlock
    │   ├── overline "WHAT LEAVES THIS DEVICE"
    │   ├── sentList · 2 items           --color-info icon + --text-body
    │   │      1. "A chapter's page — but only after you asked for it."   (B5)
    │   │      2. "One request to check whether a newer version exists —
    │   │          only if you tap 'Check for a new version'."             (B34, C5)
    │   ├── neverList · 7 items          --color-success icon + --text-body
    │   │      your library · your reading positions · your history ·
    │   │      your error logs · crash reports · analytics · a device identifier
    │   └── verifyLine                   --text-body, the airplane-mode instruction
    │
    ├── DeliveryBlock
    │   └── one sentence at --text-body  B34 + C3 + C9
    │
    └── (end of page — no footer, no links out)
```

| # | Component | Role | Source |
|---|---|---|---|
| 1 | `AppScaffold` | Title bar + retained bottom nav | `design-system.md` § 2.8 |
| 2 | `UpdateBlock` | The B31 update notice, with the guarantee stated before the button | slice-local composition over `design-system.md` § 2.3 buttons |
| 3 | `DataBlock` | The three local counts that evidence B31, plus the E11 statement | slice-local composition |
| 4 | `PrivacyBlock` | What is sent, what is never sent, and the falsifiable check | slice-local composition |
| 5 | `PrimaryButton` / `SecondaryButton` / `TextButton` | Install, download, not now, copy | `design-system.md` § 2.3 |
| 6 | `SnackBarHost` | Confirmation of the clipboard copy; progress feedback | `design-system.md` § 1.4 |

> **Components deliberately not used**: `StatusChip` — a chip is the design system's carrier of counts the app keeps about *novels and chapters* (B48, B49), and these are storage counts about the installation; a chip would imply a status. `ErrorState` is used only in the Load-error row, and only for the one thing on this screen that can actually fail silently.

---

## 4. States — all nine, no exceptions

| State | Trigger | Rendering | Reader feedback |
|---|---|---|---|
| **Loading** | The screen opens. The version string and the delivery line are build-time constants and render **immediately**. The three counts are one local query per figure | The counts render as `LoadingState` skeletons **at the shape of the content they replace**: a `--color-surface-sunken` bar the width of the figure it will become, with `--duration-normal` shimmer, **no centred spinner**. Every other block renders fully and immediately, including the whole privacy block — a privacy statement must never be waiting on a query | Nothing announces it. The privacy block appearing before the counts is deliberate: the claims are static, and only the numbers are not |
| **Filled** | Normal case, no update known | `AboutIdentity` + `DataBlock` + `PrivacyBlock` + `DeliveryBlock`. The `Check for a new version` action is present under `AboutIdentity` with its last-result value line | None. The screen is entirely declarative |
| **Empty — never visited** | The reader has never tapped **Check for a new version** | **The `UpdateBlock` is absent** — not greyed, not empty, not showing "up to date", because the app does not know whether it is up to date and B15's discipline applies here exactly as it does to a novel's chapters: an unchecked answer must never be presented as a checked one. The action's value line reads **`Never checked`**, in the same words `Updates` uses for a novel's never-checked stamp (B49) | The absence is the honest state. An `UpdateBlock` saying "you are up to date" before any check has run would be a fabricated answer, and fabricated answers are the exact failure B22 exists to prevent |
| **Empty — no data** | Fresh install: the library is empty, nothing has been downloaded, no reading positions exist | **The three counts read `0 · 0 · 0`**, in `--text-body`, set exactly like the non-zero case. **No `EmptyState`, no illustration, no "get started" call to action** — this is an About screen, not a library, and a celebratory empty state about having downloaded nothing would be both absurd and, per the design system's anti-references, gamification | A real zero, shown as a zero. The reader who has just installed needs to see that the three numbers exist and that they are empty, because those are the three numbers B31 promises to preserve |
| **Load error** | The build-time version constant is missing or malformed — a real failure mode, since the version is injected at build time from `pubspec.yaml` (ADR-011) rather than read from the package | One `--color-error` line at `--text-body-sm` where the version would be: *"The installed version number could not be read."* **The rest of the screen renders completely and unchanged** — the three counts, the whole privacy block, the delivery sentence. The version is one string; a missing string must not blank the screen that states what the app does with the reader's data | The failure is scoped in the rendering rather than in a second sentence, because the surrounding content is still true. `Version —` is *not* used: an em dash looks like a version, and C9 requires the owner to be able to determine which version is installed |
| **Submit error** | **Check for a new version** fails — no connection, or the release-metadata file is unreachable | The action's value line becomes `--color-warning` **with an icon and words**: *"The version could not be checked. There may be no connection."* and the action's label switches to **Try again**. **It never becomes "You have the latest version."** | This is B22's discriminator applied to delivery, and it is the same rule verbatim: a file that could not be read is not a file that said "no". A failed check rendered as "up to date" is the single most damaging thing this screen could do, because it would tell the reader, falsely, that they are safe |
| **Success** | The check completed and returned a version | Two outcomes. **(a) Nothing newer:** the action's value line becomes a durable statement — *"Checked 14:32 · you have the latest version."* — with the timestamp, and **no auto-dismissal**: C12 requires a message that can be read later and reported back in words, and a claim that fades is a claim that was not made. **(b) Something newer:** the `UpdateBlock` appears above everything else with its guarantee line, and it does **not auto-dismiss either** | Both outcomes are states the reader can return to and re-read. There is no celebration in either — anti-references forbid it, and "an update exists" is not good news in a product whose install path is a file the reader must fetch by hand |
| **Offline / permissions** | No connection at all | **Identical to Filled**, with one deliberate difference: the `Check for a new version` action stays **live** and produces the Submit-error wording above when tapped. **No permission is ever requested by this screen.** Installing an APK hands off to the **OS install flow**, and the OS prompts; the app asks for nothing, has no install permission to request, and cannot grant itself one | This is the only place in the app where handing the reader to another app is correct, and it is a hand-off, not a permission screen. The OS's own prompt is the reader's, and the app must not restate or re-ask it |
| **Read-only** | The three data counts, and only the counts | **They are evidence, and evidence that responds to a tap is not evidence.** The counts carry no chevron, no ripple, no pressed state and no leading icon: they are read as text and they are not interactive. Every other element on this screen is either a control or a button | The counts are the only read-only surface here, and they are read-only **by design rather than by limitation**. They are the reference the reader takes before installing an update and compares after — and a control that could be pressed would make that comparison a lie |

### 4.1 User-visible copy — both languages (B28)

| Key | English | Français |
|---|---|---|
| `about.title` | `Lumen Tale` | `Lumen Tale` |
| `about.version` | `Version {buildName} · build {buildNumber}` | `Version {buildName} · build {buildNumber}` |
| `about.provenance` | `Android phone · built automatically · no store` | `Téléphone Android · compilé automatiquement · aucun magasin` |
| `about.copyVersion` | `Copy version number` | `Copier le numéro de version` |
| `snack.copied` | `Version number copied.` | `Numéro de version copié.` |
| `about.versionUnreadable` | `The installed version number could not be read.` | `Le numéro de version installé n'a pas pu être lu.` |
| `about.check.label` | `Check for a new version` | `Rechercher une nouvelle version` |
| `about.check.never` | `Never checked` | `Jamais vérifiée` |
| `about.check.uptodate` | `Checked {time} · you have the latest version.` | `Vérifiée à {heure} · vous avez la dernière version.` |
| `about.check.failed` | `The version could not be checked. There may be no connection.` | `La version n'a pas pu être vérifiée. Il n'y a peut-être pas de connexion.` |
| `about.check.retry` | `Try again` | `Réessayer` |
| `update.title` | `Version {version} is available.` | `La version {version} est disponible.` |
| `update.installed` | `You have {version}.` | `Vous avez la version {version}.` |
| `update.guarantee` | `Installing it keeps your library, your downloads, your reading positions and your history. Nothing is replaced or re-downloaded.` | `L'installation conserve votre bibliothèque, vos téléchargements, vos positions de lecture et votre historique. Rien n'est remplacé ni retéléchargé.` |
| `update.download` | `Download the file` | `Télécharger le fichier` |
| `update.downloading` | `Downloading · {percent}% of {size}` | `Téléchargement · {pourcent} % de {taille}` |
| `update.install` | `Install the update` | `Installer la mise à jour` |
| `update.dismiss` | `Not now` | `Pas maintenant` |
| `update.failed` | `The file could not be downloaded. Nothing on this phone was changed.` | `Le fichier n'a pas pu être téléchargé. Rien sur ce téléphone n'a été modifié.` |
| `data.label` | `YOUR DATA ON THIS DEVICE` | `VOS DONNÉES SUR CE TÉLÉPHONE` |
| `data.library` | `Library` | `Bibliothèque` |
| `data.downloaded` | `Downloaded chapters` | `Chapitres téléchargés` |
| `data.positions` | `Reading positions` | `Positions de lecture` |
| `data.countUnavailable` | `—` | `—` |
| `data.e11` | `Nothing here is backed up anywhere. If you uninstall Lumen Tale or lose this phone, all three numbers go to zero and no copy exists. Installing a new version over this one does not touch them — that is the only guarantee this app makes about your data.` | `Rien ici n'est sauvegardé nulle part. Si vous désinstallez Lumen Tale ou perdez ce téléphone, ces trois nombres tombent à zéro et aucune copie n'existe. Installer une nouvelle version par-dessus celle-ci n'y touche pas : c'est la seule garantie que cette application fait sur vos données.` |
| `privacy.label` | `WHAT LEAVES THIS DEVICE` | `CE QUI QUITTE CE TÉLÉPHONE` |
| `privacy.sent1` | `A chapter's page — but only after you asked for it.` | `La page d'un chapitre — mais seulement après que vous l'avez demandée.` |
| `privacy.sent2` | `One request to check whether a newer version exists — only if you tap "Check for a new version".` | `Une requête pour savoir si une nouvelle version existe — uniquement si vous touchez « Rechercher une nouvelle version ».` |
| `privacy.never1` | `Your library` | `Votre bibliothèque` |
| `privacy.never2` | `Your reading positions` | `Vos positions de lecture` |
| `privacy.never3` | `Your history` | `Votre historique` |
| `privacy.never4` | `Your error logs` | `Vos journaux d'erreurs` |
| `privacy.never5` | `Crash reports` | `Rapports de plantage` |
| `privacy.never6` | `Analytics` | `Suivi d'audience` |
| `privacy.never7` | `A device identifier` | `Un identifiant d'appareil` |
| `privacy.verify` | `Check it yourself: switch the phone to airplane mode, then open the app. Your library, your downloads and your reading positions are all there. Nothing is missing, because nothing was ever sent.` | `Vérifiez vous-même : passez le téléphone en mode avion, puis ouvrez l'application. Votre bibliothèque, vos téléchargements et vos positions de lecture sont tous là. Il ne manque rien, parce que rien n'a jamais été envoyé.` |
| `delivery.body` | `This app runs on Android phones only. A new build is produced every time a change is merged, and you install it from the file by hand. There is no app store and no store account.` | `Cette application fonctionne uniquement sur les téléphones Android. Une nouvelle version est produite à chaque modification fusionnée, et vous l'installez depuis le fichier, à la main. Il n'y a ni magasin d'applications ni compte de magasin.` |

> Three of the nine have a thin rendering and each says why: **Loading** exists only for three local figures and never blocks the static content; **Empty — never visited** is *absence of a block*, which is the honest rendering of "not checked"; **Read-only** has exactly one read-only element and it is deliberate.

---

## 5. Interactions

| Element | Event | Behaviour | Visual feedback | Resulting state | Rule |
|---|---|---|---|---|---|
| Title-bar back / system back | tap / back | Pop to `/more/settings` | `--duration-normal` 200ms `--ease-standard` | Settings | — |
| `Check for a new version` | tap | **One** HTTP GET of a static release-metadata file that CI publishes. It carries no device identifier, no library content, no version of the OS and nothing else — and the app performs it **only** because this button was tapped. It is never automatic | Action enters `loading`: 16dp spinner, label hidden, width locked | Filled, then Success or Submit error | **B29**, **C2**, **B34** |
| — the response is an equal or older version | — | Write the durable value line, with its timestamp | Value line updates | Filled, up to date | **B15**, B49 |
| — the response is a newer version | — | Render `UpdateBlock` with the guarantee line **above** the buttons | Block appears; no animation beyond a fade `--duration-normal` | Filled + update known | **B31** |
| `UpdateBlock` — Download the file | tap | Fetch the APK to a temporary file, then move it into place **atomically** — the same discipline as a chapter (B6). Progress shows on the block's own `apkProgressLine`: a 2dp determinate bar in `--color-accent`, and the caption reads `Downloading · 41% of 8.2 MB` | Determinate bar inside the block | Update known, file present | **B6**, **C8** |
| — the download fails | — | Bar disappears, one `--color-error` line **inside the block** names the failure, and **Download the file** returns to its default state. **No chapter is affected and none is enqueued** | — | Update known, no file | **B24**, B5 |
| — the file is present | — | The action set changes: `primary` **Install the update** becomes the emphasised action and **Download the file** is replaced by the file's size and name | Button emphasis moves | Update known, file present | **B31** |
| `Install the update` | tap | Hand the file to the OS install flow. **The OS then shows its own prompt; the app requests nothing and cannot skip it** | Standard system hand-off | App is replaced | **B34**, C3 |
| — after the install | — | The app opens with a **new version string on this same page** and the same three counts. That is the drill, and the screen is built so the drill is checkable | — | Filled, new version | **B31** |
| `Not now` | tap | Record locally that this version was dismissed. **The block returns when a *different* version is published** — so dismissing 0.10.0 does not hide 0.11.0, and a reader who dismissed three notices still sees the fourth | Block collapses | Filled | B15 |
| `Copy version number` | tap | Put `0.9.0 (build 41)` on the clipboard | Snackbar: *"Version number copied."* | Filled | **C9**, C12 |
| The three data counts | — | **Nothing.** No chevron, no ripple, no pressed state | — | — | **B31** |

- **Focus / keyboard**: reading order, top to bottom. The version line and the counts are **not focusable** — they are text, and making text focusable is how a screen-reader user ends up arrowing through four screens of nothing. Buttons take focus in their visual order. `Esc` returns to Settings. Focus is visible at 2dp `--color-border-focus` with a 2dp offset and is never removed.
- **Gestures**: vertical scroll only. **No pull-to-refresh anywhere on this screen**, and this is deliberate: pull-to-refresh is the gesture that says *this list is stale, pull for more*, and a page of static statements is not a list. Refreshing a privacy statement is a category error, and it is also the gesture a reader would use to retry the version check, which is why that retry is an explicit named button instead.
- **Animations**: push/pop `--duration-normal` 200ms `--ease-standard`; the `UpdateBlock` fades in over `--duration-normal`; the APK progress bar updates at most a few times a second with no easing, because a progress bar that eases is a progress bar that lies about its velocity; `--shadow-sheet` on the snackbar. Every duration becomes `0ms` under reduce-motion.
- **Back**: pops one level. **The APK download, if running, is not cancelled by leaving the screen** — it is a single file, it is atomic, and it finishes or fails on its own. If it completes while the reader is elsewhere, the `UpdateBlock` is waiting for them when they come back.

---

## 6. Responsive

| Breakpoint | Behaviour | What collapses or disappears |
|---|---|---|
| **Mobile** `< 600dp` | Single column, `--space-lg` 16dp margins. The three counts stay in **one row of three** and wrap to two rows only if a figure plus its label cannot fit, in which case each count becomes a two-line cell rather than truncating | Nothing. This is the design target |
| **Tablet** `600–1023dp` | Identical single column, centred, **capped** — the paragraph width of the `PrivacyBlock` stops widening and the count row stays three across | Nothing collapses — the layout simply stops widening |
| **Desktop** `1024–1439dp` | Same single column, centred, same cap. Flutter desktop is out of scope | — |

- **Touch target**: **48dp minimum** on all four buttons and the two text actions. The seven `neverList` rows and the two `sentList` rows are **not** interactive and are sized at their text height with `--space-sm` 8dp between them — they are sentences, and giving them a 48dp hit area with no behaviour would invite taps that do nothing.
- **Overflow**: **guaranteed never to overflow.** The `PrivacyBlock`'s paragraphs wrap; the guarantee line wraps; the count figures are `--text-body` and wrap to two lines rather than truncating, because a truncated count is a count the reader cannot compare before and after an update. The `UpdateBlock`'s buttons stack to full width below 400dp rather than overflowing their row.

---

## 7. Accessibility

- [x] **Contrast 14.48:1** (day) / **12.00:1** (night) for every statement — `--color-text-primary` on `--color-background`, measured, not asserted.
- [x] **Contrast 6.22:1** / **6.01:1** for the provenance line, the qualifying clauses and the block labels — `--color-text-secondary`.
- [x] **Contrast 5.54:1** / **7.27:1** for a button label — `--color-text-inverse` on `--color-accent`.
- [x] **Contrast 6.07:1** / **8.86:1** for the focus ring — `--color-border-focus`, measured as non-text per WCAG 1.4.11.
- [x] **Contrast 4.80:1** / **7.36:1** for the failed-check line — `--color-warning`, and never alone: an icon and words carry it. **This is the screen where that matters most**, because "the check failed" and "you are up to date" are the two sentences that must never be confused, and one of them is rendered in `--color-success`-adjacent language and the other in warning. Each is a distinct sentence with a distinct icon, a distinct colour, and a distinct next action.
- [x] **No state is carried by colour alone.** Every icon on this screen is paired with words, per `design-quality.md` § 3.
- [x] **Keyboard navigation complete** at every breakpoint; all four buttons and two text actions reachable; focus visible at 2dp with a 2dp offset, never removed.
- [x] **Semantic alternative for the counts**: each is announced as *"Library, 14 novels"*, *"Downloaded chapters, 512"*, *"Reading positions, 638"* — with the unit spoken, not just the digits. The three are announced as a **single group labelled "Your data on this device"**, so a screen-reader user hears them as one fact about this installation rather than three orphan numbers.
- [x] **The `neverList` items are a list, and a real one** — seven `<li>` elements inside a labelled group, so a screen-reader user can count them. This matters: the claim is "seven things never leave", and a claim the reader cannot count is weaker than the one the design intends.
- [x] **Reading order and language correct**: every sentence, label, button and the delivery paragraph exists in French and English (B28), the French falling back for an unrecognised locale. `dir` follows the language; no RTL source exists in v1.
- [x] **Reduce-motion honoured**: the `UpdateBlock` appears instantly; the progress bar updates without easing in either case.

---

## 8. Data

| Field | Type | Origin | Required | Possible error |
|---|---|---|---|---|
| `buildName` | `String` | build-time constant from `pubspec.yaml` `version:` (ADR-011) | yes | Missing or malformed → Load error, stated in words; **never** a dash or an invented number |
| `buildNumber` | `int` | same | yes | Same |
| `platform` | `String` | OS, read-only | yes | Absent → the provenance line omits its first clause rather than guessing Android |
| `libraryCount` | `int` | local, `COUNT(*)` over the library | yes | Query fails → skeleton bar, then the count is **omitted with `—`**, never `0` |
| `downloadedChapterCount` | `int` | local | yes | Same |
| `readingPositionCount` | `int` | local | yes | Same |
| `latestPublishedVersion` | `String?` | **remote**, the CI-published static release-metadata file | no | Only fetched when the reader taps. Unreachable → Submit error, **never** rendered as "up to date" |
| `updateFileName`, `updateFileSize`, `updateFileSha` | `String`, `int`, `String` | same file | no | Present only when a newer version exists; the size is spoken in the progress caption |
| `dismissedVersion` | `String?` | local | no | A *different* published version re-shows the block regardless |
| `apkDownloadState` | `enum(absent\|downloading\|present\|failed)` | local | yes | `failed` → the error line inside the block, with its own retry |
| `locale` | `Locale` | platform, read-only | yes | Unrecognised → **French** (B28) |

- **Loading**: nothing is paged. Three local `COUNT`s and, on demand, one remote metadata GET. The version and every static block render before any of them resolve.
- **Cache / offline**: **the whole screen renders and is complete with no connection**, because six of its seven fields are local or compile-time. The only remote field is the update check, and it is the one field on the screen that reports its own absence instead of guessing.
- **Sensitive data**: **the update request is the only outbound request this screen can make, and it carries nothing.** No library, no counts, no positions, no history, no device identifier, no OS version, no locale, nothing about who is asking — it is a `GET` of a static file whose entire content is a version string and a file name. The three counts displayed here are **never transmitted anywhere**, and the app has no analytics, no crash reporter and no telemetry to transmit them with (B29, C2). **The version string placed on the clipboard by `Copy version number` is not content** — it is the one string in this product the reader may legitimately need to read aloud to the owner, and B30 covers chapters and novels, not a version number. The app writes nothing to any log from this screen, including the counts.

---

## 9. Traceability

| ID | Origin | Manifestation on this screen |
|---|---|---|
| B4 | PRD | **No company name, no operator identity, no team, no contact address, no account, no sign-out.** The screen's "what leaves this device" list names *a device identifier* among the seven things that never leave — which is only possible because there is no identity to have one |
| B29 | PRD | The `PrivacyBlock`: two things sent, **and both are named as things the reader asked for first** — a chapter's page (B5), and one version check they tapped. Seven things never sent, as a countable list. Then the falsifiable instruction: *switch to airplane mode and open the app* |
| B30 | PRD | **No backup, no export, no share, no "send".** The only clipboard use in the entire app is `Copy version number`, and the DataBlock states the consequence of B30 plainly: nothing here is backed up anywhere |
| B31 | PRD | **The reason this screen exists.** The `UpdateBlock`'s guarantee line, stated *above* the install button, and — the part that makes it checkable — the three local counts, so the reader can take them before installing and compare them after. The install path is a plain OS hand-off with no uninstall step in it, which is what makes the guarantee structural rather than a promise |
| B34 | PRD | The provenance line (`Android phone · built automatically · no store`) and the one-sentence `DeliveryBlock`: built on every merge, installed by hand, **no store and no store account**. Visible only here, because B34 is a build fact |
| B43 | PRD | The version and build number, at `--text-h3`, the largest object on the page after the block labels, with `Copy version number` so the owner can put it somewhere they can read it |
| B47 | PRD | Not a control here — but `readingPositionCount` is one of the three preserved figures, which is the visible form of B46's and B47's guarantee: bounding the *history list* by time must never touch the *positions*, and the count that proves it is the one that must survive |
| E11 | PRD | The `DataBlock`'s `disclosureLine`, in full, where the version and the counts are: nothing is backed up anywhere, an uninstall or a lost phone takes all three numbers to zero, and **no copy exists**. Stated here rather than pointed at from Settings so that the disclosure and the guarantee about updates sit in the same field of view — the reader learns both limits of this product in one place |
| C3 | PRD | The delivery sentence names the platform constraint: an Android phone, installed from a file |
| C5 | PRD | The update check is **on-demand and named**, so the maintenance model is legible to someone who cannot write code: a new version exists, here is what it will do, here is the button |
| C6 | PRD | A failure on this screen is reported **on the device** — a missing version string is stated in words rather than silently rendering nothing |
| C9 | PRD | The build number is displayed, and copyable, so which build is installed is determinable without a developer |
| C12 | PRD | Every sentence here is one that can be read aloud and repeated: the version, the guarantee, the failed-check wording, the disclosure. **The failed-check line never auto-dismisses**, because a claim that fades cannot be reported back |

---

## 10. Gate checklist

- [x] All nine states described, with a concrete rendering. The four with nothing distinct to render say **why** they have none.
- [x] Every interactive element has a behaviour, a feedback, a resulting state and a rule ID.
- [x] Responsive defined at **every** breakpoint in the design system — and the two larger ones say "identical, stop widening", which is ADR-019.
- [x] Anti-generic section checked **and justified**; the assumed choice is stated: **B29 as a test the reader can run, not a promise.**
- [x] No design value left "to be defined". Every colour, size, duration and easing cited exists in `design-system.md` with a value.
- [x] Every B/E/C ID on this screen appears in § 9.
- [x] `forge-guard placeholders` reports nothing here.
- [x] Consistent with `design-system.md`: **no `--color-surface-raised` except the snackbar, and `--shadow-sheet` used only where the design system permits it.**
- [x] **Every token cited by this screen exists in the design system, with the value it is given here.** The full citation table is § 12.
- [x] **Figures on this screen are rendered from the device, never declared.** `14`, `512` and `638` are format exemplars in this document; there is no hard-coded count anywhere in the app, because a fixed number on a screen whose entire job is to be evidence would be the worst possible defect.

---

## 11. Deliberately absent — and why that is not a gap

| Absent | Rule | Why |
|---|---|---|
| Automatic update check on app open, on a timer, or on any background trigger | **B29**, B36, and the absence of any schedule (B35 withdrawn, ADR-023) | The app never contacts anything on the reader's behalf unless they asked. An update check is the least-bad candidate for an exception — it is one `GET` of a static file — and it is still an exception, so it is explicit, named and tapped. This is the same rule B35 already applies to chapter checks, applied to the app's own delivery |
| A store listing, a "rate the app" row, a "what's new" feed, a changelog fetched from a server | **B34**, C3, C9 | There is no store and no account. A changelog the reader cannot reach offline would also be a screen that fails without a connection, on the one screen that is supposed to explain the app |
| Company name, logo, contact address, "made by", terms link, privacy-policy link | **B4** | There is no operating entity to publish and no policy document hosted anywhere. A link to a policy that does not exist is the same failure as `source-unavailable` presenting an empty list: it asserts something the reader cannot check |
| A "check for updates" preference, an update channel, a beta channel, an auto-install toggle | B34 | There is exactly one channel: the APK the CI produced. An update *preference* would be a setting with one possible value |
| Telemetry consent, an analytics toggle, a crash-report toggle, a "diagnostics" switch | **B29** | Consent implies something to consent to. There is nothing to toggle, and a disabled switch for a feature that does not exist is a promise this design does not make |
| Per-source or per-novel information | B2 | A novel belongs to exactly one site (B2), and this screen is about the installation, not about what it reads. The one place the two meet is the privacy list, which names nothing |
| Total storage used, a cache-clearing button, a "manage downloads" link | C4 | This screen states *what is preserved*; it does not offer a way to destroy it. A delete control sitting under the sentence "nothing here is backed up" would be an invitation to do the one irreversible thing this product cannot undo — and per-chapter and per-novel deletes already exist, explicitly, where the reader is actually reading (B32, B33) |
| An export or a backup, even framed as "just in case" | **B30**, ADR-010 | Declined by decision, together with sharing. The DataBlock states the consequence instead of engineering around it, which is what E11 requires |

---

## 12. Tokens this screen cites

Every value below is the one the design system declares, so `design-check tokens-used` can re-derive it. Only the colour rows are contrast-measured, and each figure is the design system's own worst-case figure for that token across the surfaces it is legal on.

| Token | Day | Night | Measured (day / night) | Where it appears here |
|---|---|---|---|---|
| `--color-background` | `#F5F2ED` | `#121315` | — | The page field behind all six blocks |
| `--color-surface-sunken` | `#EBE7E0` | `#0C0D0F` | — | The `UpdateBlock`, the `DataBlock`, and the skeleton bars for the three counts |
| `--color-text-primary` | `#1A1714` | `#E8E4DD` | **14.48:1** / **12.00:1** | Every statement, the version line, the seven "never sent" rows, the verify instruction |
| `--color-text-secondary` | `#5A524A` | `#A8A29A` | **6.22:1** / **6.01:1** | The provenance line, the block labels, the E11 disclosure line, the progress caption |
| `--color-text-inverse` | `#FDFAF6` | `#17181A` | **5.54:1** / **7.27:1** | The `primary` Install button and the ghost action labels on the accent fill |
| `--color-accent` | `#8A4B12` | `#E3A857` | **5.50:1** / **7.25:1** | The 2dp determinate APK progress bar; focus ring |
| `--color-success` | `#40713A` | `#7FBE72` | **4.68:1** / **6.89:1** | The check beside each of the seven "never sent" items |
| `--color-info` | `#426986` | `#7FB3DA` | **4.74:1** / **6.78:1** | The `UpdateBlock` icon and the two "sent" items — the two things that do leave, marked as plainly as the seven that do not |
| `--color-warning` | `#8A5A12` | `#E0AC47` | **4.80:1** / **7.36:1** | The failed version check, with icon and words |
| `--color-error` | `#8A3228` | `#EE8B76` | **6.64:1** / **6.22:1** | The unreadable version string; the failed APK download line |
| `--color-border-focus` | `#8A4B12` | `#E3A857` | **6.07:1** / **8.86:1** | 2dp focus ring at 2dp offset on all four buttons and both text actions |
| `--color-surface-raised` | `#FEFCF9` | `#232629` | — | The snackbar host, and nothing else on this screen |

Non-colour tokens cited: `--text-h2` `#25/32` at 700 (the single page title inside the body); `--text-h3` `#20/26` at 600 (the version line, the update headline); `--text-body` `#16/24` at 400 (every statement, the counts, the seven never-sent rows, the verify instruction); `--text-body-sm` `#14/20` at 400 (the version Load-error line); `--text-caption` `#12/16` at 400 (the provenance line, the "You have 0.9.0" line, the progress caption, the E11 disclosure line); `--text-overline` `#11/16` at 600 with `letter-spacing 0.08em` (the block labels); `--space-sm` `8dp` (between the never-sent rows); `--space-md` `12dp` (inside a block); `--space-lg` `16dp` (page margin, between the icon and its sentence); `--space-xl` `24dp` (inside the UpdateBlock); `--space-2xl` `32dp` (between blocks — the largest gap on the page, and the one that closes each block, per `design-system.md` § 1.3); `--space-3xl` `48dp` (page top margin); `--border-width` `1dp`; `--shadow-none` on all six blocks; `--shadow-sheet` `0 8 24 rgba(0,0,0,0.18)` (snackbar only); `--radius-md` `8dp` (button corners); `--radius-lg` `16dp` (the three sunken blocks); `--radius-full` `999dp` (the `--color-success` check glyph's container at its natural size); `--duration-normal` `200ms` (push/pop, the UpdateBlock fade); `--ease-standard` `cubic-bezier(0.2, 0, 0, 1)`; `--bp-mobile` `< 600dp`, `--bp-tablet` `600–1023dp`, `--bp-desktop` `1024–1439dp`; touch target `48dp`.