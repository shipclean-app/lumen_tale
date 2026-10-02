---
type: screen
slug: source-unavailable
title: Source unavailable
module: browse
status: approved
generated_at: 2026-10-02
derived_from:
  - .forge/prd.md
  - .forge/design/design-system.md
rule_ids:
  - B2
  - B5
  - B7
  - B22
  - B23
  - B24
  - B28
  - B30
  - B50
edge_case_ids:
  - E2
  - E3
  - E4
  - E5
  - E8
  - E9
  - E18
  - E19
flow: error-flow
---

# Screen — Source unavailable

> The source of truth for generating this screen. It is **SC-6's only screen**: the PRD's own account is that a broken site reported as empty is the single most likely way this app fails in real use, and it is the one success criterion that can be demonstrated by looking at a screen. Every decision below serves one requirement: **this must never be mistakable for an empty result.**

---

## 1. Role of the screen

| | |
|---|---|
| **App archetype** | `mobile_consumer` |
| **Module** | `more` as recorded in the screen registry. **The route lives under `/browse/`** because the failure is about a source the reader was in the middle of browsing — and the two disagree. Recorded rather than silently resolved: the route placement is what the reader's back stack and the deep link need, and the module grouping is a registry question. Resolution belongs to Phase 4; neither value is changed here |
| **Route** | `/browse/:sourceId/unavailable` |
| **Type** | full page with a title bar carrying the **source's name**, pushed inside the Browse shell |
| **Users** | the reader, mid-task, who has just been refused something they asked for — and, after the fact, a friend describing the failure to the owner (C12) |
| **User stories served** | US-16, and US-01, US-02, US-03 wherever their fetch failed |
| **Business rules** | B2 B5 B7 B22 B23 B24 B28 B30 B50 |
| **Edge cases** | E2 E3 E4 E5 E8 E9 E18 E19 |
| **Flow** | `error-flow` |

**In one sentence**: this screen tells the reader **which of four different things went wrong**, shows the evidence that the app used to decide that, states plainly what still works, and offers the one action that is appropriate to the cause.

**Why it is a screen at all, rather than a dialog or a toast**: because the reader's next decision differs per cause. *No connection* → come back later. *The site changed* → tell the owner. *The site is refusing* → wait. *Removed at the source* → open what you already have. A single "Something went wrong — try again" collapses four actions into one wrong one, and the PRD's B22 exists because collapsing them is what the competitors do. C12 adds the second reason: the message must be **readable aloud and reported back in words**, which needs room and a sentence, not a banner that disappears.

---

## 2. Visual direction for this screen

| | |
|---|---|
| **Mood** | plain, specific, unhurried — never alarmed |
| **Density** | **normal** — justified: two blocks and at most three actions. The page is short because a failure page that scrolls is a failure page the reader has to work at, and the reader has just been refused something |
| **Contrast level** | **high** — the sentence naming the cause is `--color-text-primary` `#1A1714` / `#E8E4DD` at **14.48:1** / **12.00:1** on `--color-surface-sunken` `#EBE7E0` / `#0C0D0F`. The evidence line beneath it is `--color-text-secondary` at **6.22:1** / **6.01:1** — never caption contrast, because this line is the diagnosis |
| **Surface** | `--color-background` `#F5F2ED` / `#121315`; **both blocks are `--color-surface-sunken`** — recessed wells the reader looks *into*, the same idiom as the reader's prose field and as the E11 disclosure. There is no `--color-surface-raised` on this screen except the snackbar |
| **Accent used** | `--color-accent` `#8A4B12` / `#E3A857` — **only** on the focus ring and on one `ghost` action. **It appears nowhere inside the cause block.** A second opinion-coloured element beside a `--color-error` sentence reads as two things being wrong, and exactly one thing is wrong |
| **Photographic treatment** | **none.** No cover, no novel artwork, no illustration. The novel's cover on a page saying the novel is gone is a small cruelty, and the design system forbids spot illustration in any case |
| **Reference** | a diagnostic report rather than a marketing error page: a label, a finding, the evidence for the finding, and the action that the finding implies |

### 2.1 Anti-generic — mandatory

This screen must not resemble any of these defects:

- [x] **No pure white `#FFFFFF` background** — `--color-background` `#F5F2ED` / `#121315`.
- [x] **No shadowed card.** Both blocks are `--shadow-none` and sunken. A centred dialog with a red border and a big exclamation mark is the generic failure page, and it is ruled out by the design system's anti-references twice over: no icon in a circle, and no elevated card as a container.
- [x] **Not uniform.** `--text-overline` 11/16 at 600 with 0.08em letter-spacing for the cause kicker — **the only place in the app where a label is set that way**, because it must read as a label on a diagnosis rather than as a section header — against `--text-h3` 20/26 for the finding, `--text-body` 16/24 for the sentence, `--text-caption` 12/16 for the evidence, `--text-h4` 18/24 for the second block's lines.
- [x] **No generic grey `#6B7280`** — the secondary lines are the paper-anchored ramp.
- [x] **No symmetric centring.** Everything is left-aligned in a single column. **A centred failure page is the generic layout**, and centring also destroys the left-edge reading anchor that makes a block of evidence scannable.
- [x] **No generic spot illustration** — no broken-link cartoon, no cloud-with-a-slash in a coloured disc, no sad robot. The only glyph is a **24dp Material 3 icon at the top of the block, uncircled**, and it changes with the cause.
- [x] **Not one typeface at one weight** — sans chrome at four sizes and two weights, which is all this screen needs.

**Assumed, non-neutral choice**: **the screen is built to be mechanically impossible to mistake for an empty result list, and it says so in its own rendering rather than in a caption.** A generic app handles this with the words "Something went wrong" and hopes. This screen instead does seven specific things, each of which a reader who has also seen a genuine *no results* state will register as a difference:

1. **There is no list region.** The page is two blocks. A result list has rows; this has paragraphs. There is nothing here that could be read as "the list, and it happens to be short".
2. **The kicker is a `--text-overline` diagnosis label**, in the app's own vocabulary — `NO CONNECTION`, `THIS SITE'S PAGES HAVE CHANGED`, `THE SITE IS NOT SERVING REQUESTS`, `REMOVED AT THE SOURCE` — never `ERROR`.
3. **The kicker's colour is the cause's colour, and the cause's colour is not always red.** A missing connection is `--color-info`, a refusing site is `--color-warning`, only a changed layout is `--color-error`. A failure page that is always red teaches the reader that red means "the app is unhappy", not "this specific thing is broken".
4. **There is an evidence line** — `--text-caption`, `--color-text-secondary`, naming the HTTP status or the parse outcome that produced the diagnosis. **A genuine no-results state has no evidence line, because there is no failure to have evidence of.** This is the single strongest discriminator on the screen and it is the one a reader repeats to the owner.
5. **A pre-written sentence the reader can dictate.** Under the evidence line: *"Say: {source} cannot be read. The app loaded the page and found none of the elements it looks for."* That is C12's requirement made into an interface — the app writes the bug report the reader reads aloud.
6. **A second block exists and it is about something else.** `WHAT STILL WORKS`, with three counted lines in `--color-success`. An empty state has nothing to reassure about.
7. **A hard string ban.** The strings **`0 results`, `No results`, `Nothing found`, `Empty`** appear nowhere on this screen **or in the view that routes to it**. B22's discriminator is the site's own empty-result signal, and a screen that can emit both vocabularies has destroyed the distinction it exists to protect.

**And one decision that is visible mainly in what it refuses:** **a cause whose correct action is "nothing" gets no retry button.** For `REMOVED AT THE SOURCE` — where the site answered and confirmed the title is gone — there is no `Try again`. Not a disabled one, not a greyed one: **absent**, because B24 asks for "a way to try again" and for a confirmed removal there is nothing to try, and a button that re-requests a page the app has just been told does not exist is a promise the app cannot keep. The reason is printed where the button would have been: *"There is nothing to retry here."* B24 is an obligation to offer a way forward, not an obligation to offer a way back.

---

## 3. Anatomy

```
AppScaffold (titleBar = the source's own name, e.g. "FanMTL" — never "Error")
└── SourceUnavailableBody               single column, --space-3xl top margin
    ├── CauseBlock                      --color-surface-sunken, --shadow-none
    │   ├── causeIcon                   24dp, uncircled, colour = the cause's colour
    │   │                               wifi_off / sync_problem / hourglass_empty / block
    │   ├── CauseKicker                 --text-overline 600, 0.08em, uppercase
    │   │                               "NO CONNECTION" | "THIS SITE'S PAGES HAVE CHANGED"
    │   │                               | "THE SITE IS NOT SERVING REQUESTS"
    │   │                               | "REMOVED AT THE SOURCE"
    │   ├── CauseTitle                  --text-h3   "{source}'s pages can no longer be read."
    │   ├── CauseSentence               --text-body one sentence, names the cause and its owner
    │   ├── EvidenceLine                --text-caption, --color-text-secondary
    │   │                               "The page loaded (HTTP 200) and none of the expected
    │   │                                elements were found."
    │   ├── DictationLine               --text-caption, --color-text-secondary, only for
    │   │                               layout-changed: "Say: …"
    │   ├── CauseActions                ← per cause, see § 2.1 and § 5
    │   └── NoRetryLine                 --text-caption, only where a retry is absent
    │
    ├── --space-2xl
    │
    ├── StillWorksBlock                 --color-surface-sunken, --shadow-none
    │   ├── BlockLabel                   "WHAT STILL WORKS"  --text-overline
    │   ├── StillWorksLine × 3          --text-h4, --color-success check_circle 20dp
    │   │     "Your 14 kept novels and 512 downloaded chapters open with no connection."
    │   │     "Royal Road is unaffected — keep reading from it."
    │   │     "Your 638 reading positions are untouched."
    │   └── [secondary] Open the library · [ghost] Open Royal Road
    │
    └── (end of page — nothing below, no footer, no share)
```

| # | Component | Role | Source |
|---|---|---|---|
| 1 | `AppScaffold` | Title bar carrying the source's name; the Browse shell's bottom nav stays so the reader can leave sideways | design-system § 2.8 |
| 2 | `CauseBlock` | The diagnosis: icon, kicker, title, sentence, evidence, actions | slice-local composition over `ErrorState`'s contract — see § 10 |
| 3 | `StillWorksBlock` | B23, made a structural element rather than a clause | slice-local composition |
| 4 | `ErrorState` | **Used as the container's contract**: `--color-error` icon, a sentence naming what failed and what still works, a `secondary` retry. This screen is its only full-page instance | design-system § 2.7 |
| 5 | `SecondaryButton` / `TextButton` | Try again, Go back, Open the library, Copy this message | design-system § 2.3 |
| 6 | `SnackBarHost` | Retry outcome, and the change-of-cause notice | design-system § 1.4 |

> **Not used**: `NovelRow` and `StatusChip` are the components that carry a source's broken state elsewhere in the app — `NovelRow`'s `error` state carries `--color-error` plus an icon plus wording, never colour alone, and this page is where that row's tap lands. `EmptyState` is **never** rendered on this screen, in any state, including the ones where the honest answer is "there is nothing there" — because `EmptyState`'s three named instances are `library-empty`, `search-unsupported` and `no-chapters`, and none of them is a broken source. Rendering one here would be the exact confusion B22 forbids.

---

## 4. States — all nine, no exceptions

| State | Trigger | Rendering | Reader feedback |
|---|---|---|---|
| **Loading** | The route was entered by **cold start or deep link** — `/browse/:sourceId/unavailable` with no live failure in memory — and the stored cause record is being read from disk | `LoadingState` **at the shape of the content it replaces**: a 24dp `--color-surface` icon block, two text lines at `--text-h3` and `--text-body` widths, and a `--space-md`-wide button-shaped block — on `--color-surface-sunken`, `--duration-normal` shimmer, **no centred spinner**. **The cause kicker stays empty until the record is read.** Naming a cause before it is known would be worse than naming none, because the reader's action depends on which cause it is | None. The skeleton is the shape of the answer, so the page does not visibly reflow when the answer arrives |
| **Filled** | A cause is known and is reported. This is the only state a reader normally sees | `CauseBlock` + `StillWorksBlock`, with the actions that cause implies | See § 5. The cause sentence names **the cause and who it belongs to** in the same two lines — never a bare "an error occurred" |
| **Empty — never visited** | **Not reachable.** A source that has never been read cannot have failed. This route is only ever pushed *because* a fetch failed | **n/a, and the reason is structural**: the screen is entered from a failure, not discovered. If the route is reached with no stored cause — a hand-typed deep link, a restored back stack from before the record was written — the app **redirects to `/browse`**, the source list. It does **not** render an empty version of itself and it does **not** show a blank page | The redirect is silent and immediate. A failure screen with nothing to report is a worse thing than the list the reader came from, and B24 forbids failing to a blank screen |
| **Empty — no data** | **The one place this matters: the site's own explicit empty-result signal.** The site answered, the parser succeeded, and the response carries the site's own "nothing here" marker. **In that case the app never routes to this screen at all** — it renders the source's `EmptyState`, on the browse surface, in the site's own vocabulary | **A routing invariant, not a rendering**: *genuine nothing* and *could not read* are decided by the site's own signal, and only the second one reaches this route. B22 states the discriminator precisely and this is where it is enforced. So this row's rendering is: **this screen does not exist for this case, and its absence is the guarantee** | A reader comparing the two states on the same site sees: `EmptyState` — no icon, no kicker, no evidence line, `--color-text-primary` on `--color-surface`, one `secondary` action — and this screen, which shares **not one string** with it. That is what makes SC-6 demonstrable rather than asserted |
| **Load error** | The failure *was* recorded but the record cannot be read — the process was killed between the failure and this screen, or the record is corrupt. A real Android path, not a hypothetical | A **generic** `ErrorState`, and the word generic is the decision: `CauseBlock` with the kicker **`THIS SITE COULD NOT BE READ`**, `Icons.sync_problem` in `--color-error`, the title *"This site could not be read, and the details of why were lost."*, the sentence *"The app will not guess which of the four causes it was."*, and a `secondary` **Try again**. The `StillWorksBlock` renders in full, because it is true regardless | The screen refuses to invent a diagnosis. A guessed cause would send the reader to wait when the site has changed, or to report a bug when the phone is in a tunnel — and C12 means that misreport becomes the owner's next hour |
| **Submit error** | A retry fails again, or **fails differently** | Three renderings, all inside the block. **(a) Same cause:** the block is unchanged and one `--text-caption` line is added beneath the actions: *"It failed again at 14:32. Same cause: this site's pages have changed."* Stating *unchanged* is the information — it tells the reader their situation is stable and not deteriorating. **(b) New cause:** the cause block **replaces its content**, the icon and colour change, and one `--color-info` line reads *"This is a different problem from last time."* **(c) The retry itself could not be sent** — no connection: the block becomes the `no-connection` cause, which is a cause, not a submission failure | Every line carries a **timestamp**, because the reader's real question after two failures is *is this getting worse*. And in case (b) the change is announced rather than swapped silently: a cause that changes under the reader's feet without a word is the one way this screen could mislead |
| **Success** | A retry succeeds | The `CauseBlock` is **replaced** by a resolution: `Icons.check_circle` in `--color-success`, `--text-h3` *"FanMTL is working again."*, and a `primary` **Open FanMTL**. **No celebration** — anti-references forbid gamification, and "an update exists" / "the site is back" is not good news to mark. The `StillWorksBlock` **disappears**, because it is no longer news; and beneath the resolution, one `--text-caption` line records **when this source was last checked**, in the same words `Updates` uses per novel (B49) | The last-checked line matters after a success as much as after a failure: it is what stops the app, or the reader, from concluding there is nothing new. The count is local and was always right (B48); only the verification changes |
| **Offline / permissions** | **This is the screen's most common state.** The `no-connection` cause *is* the offline case, and it is not dressed as anything else | The `no-connection` block, and the `StillWorksBlock` **already showing the offline truth**: the library opens right now, with the numbers it has. **No offline banner, no dimming, no "you are offline" chrome anywhere** — consistent with `reader.md` § 4, where offline reading is also unannounced. **No permission is requested here.** Per ADR-014 the app carries no WebView challenge bypass, so a site serving an interactive anti-bot challenge is reported as the `site-unavailable` cause with the evidence line *"the site returned an anti-bot challenge"* — because that is the truthful class, and it is one a reader can repeat to the owner | The offline case is not a special case here; it is one of the four, with its own kicker and its own icon, and **no other screen in the app needs to say "you are offline"** |
| **Read-only** | The cause record, and nothing else on this page | **A cause, once concluded, is never edited.** A later attempt **appends an observation** — a timestamp, an outcome, a possible new cause — and the block renders the latest one. The reader cannot dismiss a cause, cannot mark it "seen", and cannot annotate it: the record exists so that the owner, alone (C5), can read a device and see what happened, and a record the reader can quietly tidy is not a record. **Beyond that, no control on this screen mutates anything**: every action either navigates or re-requests exactly one page | Read-only by design, and it is what makes C5 work — one person's repair depends on the failure history being whatever the device actually saw |

### 4.1 User-visible copy — both languages (B28)

Every cause has its own wording. The four kickers are the **load-bearing part**: they are the only place in the app where a diagnosis is named in four words rather than implied, and a reader who has seen two of the four will recognise the other two by the pattern.

| Key | English | Français |
|---|---|---|
| `cause.noConnection.kicker` | `NO CONNECTION` | `AUCUNE CONNEXION` |
| `cause.noConnection.title` | `{source} could not be reached from this phone.` | `{source} n'a pas pu être joint depuis ce téléphone.` |
| `cause.noConnection.body` | `The phone has no usable connection. The app cannot tell whether {source} is working, so it does not guess.` | `Le téléphone n'a pas de connexion exploitable. L'application ne peut pas savoir si {source} fonctionne : elle ne devine pas.` |
| `cause.noConnection.evidence` | `Transport error — no connection was made to {host}.` | `Erreur de transport — aucune connexion à {hôte}.` |
| `cause.noConnection.retry` | `Try again later.` | `Réessayer plus tard.` |
| `cause.layoutChanged.kicker` | `THIS SITE'S PAGES HAVE CHANGED` | `LES PAGES DE CE SITE ONT CHANGÉ` |
| `cause.layoutChanged.title` | `{source}'s pages can no longer be read.` | `Les pages de {source} ne peuvent plus être lues.` |
| `cause.layoutChanged.body` | `The site answered, but the structure this app reads has changed. This is a fault in the app's copy of {source} — not in {source}, and not in anything you did. Until a new version of Lumen Tale fixes it, this site cannot be read.` | `Le site a répondu, mais la structure que l'application lit a changé. C'est une faute dans la copie que l'application a de {source} — pas dans {source}, et rien n'est dû à votre utilisation. Tant qu'une nouvelle version de Lumen Tale ne l'aura pas corrigé, ce site reste illisible.` |
| `cause.layoutChanged.evidence` | `The page loaded (HTTP {status}) and none of the expected elements were found.` | `La page a été chargée (HTTP {statut}) et aucun des éléments attendus n'a été trouvé.` |
| `cause.layoutChanged.dictation` | `Say: {source} cannot be read. The app loaded the page and found none of the elements it looks for.` | `Dites : {source} est illisible. L'application a chargé la page et n'a trouvé aucun des éléments qu'elle cherche.` |
| `cause.layoutChanged.retryNote` | `Sometimes this fixes itself while the site finishes a change. Usually it does not.` | `Parfois cela se résout tout seul pendant que le site termine une modification. Rarement.` |
| `cause.siteUnavailable.kicker` | `THE SITE IS NOT SERVING REQUESTS` | `LE SITE NE RÉPOND PAS` |
| `cause.siteUnavailable.title` | `{source} is busy, or is refusing requests from this app.` | `{source} est occupé, ou refuse les requêtes de cette application.` |
| `cause.siteUnavailable.body` | `This is on {source}'s side and is usually temporary. Trying again immediately is more likely to be refused than accepted — wait a while.` | `Cela vient de {source} et dure d'ordinaire peu de temps. Réessayer tout de suite a plus de chances d'être refusé qu'accepté : attendez un moment.` |
| `cause.siteUnavailable.evidence.status` | `{source} answered HTTP {status}.` | `{source} a répondu HTTP {statut}.` |
| `cause.siteUnavailable.evidence.challenge` | `{source} returned an anti-bot challenge. This app does not attempt to get past one.` | `{source} a renvoyé un défi anti-robot. Cette application n'essaie pas de le franchir.` |
| `cause.siteUnavailable.countdown` | `Available again in {mm:ss}` | `De nouveau disponible dans {mm:ss}` |
| `cause.contentRemoved.kicker` | `REMOVED AT THE SOURCE` | `RETIRÉ DE LA SOURCE` |
| `cause.contentRemoved.title` | `{novel} is no longer at {source}.` | `{roman} n'existe plus sur {source}.` |
| `cause.contentRemoved.body` | `{source} answered and confirmed this title is gone. Everything already downloaded from it is still on this phone, and still opens.` | `{source} a répondu et confirme que ce titre a disparu. Tout ce qui en a déjà été téléchargé reste sur ce téléphone, et s'ouvre toujours.` |
| `cause.contentRemoved.evidence` | `{source} answered HTTP {status} and the page carries the site's own "not found" signal.` | `{source} a répondu HTTP {statut} et la page porte le signal « introuvable » du site.` |
| `cause.contentRemoved.noRetry` | `There is nothing to retry here.` | `Il n'y a rien à réessayer ici.` |
| `cause.contentRemoved.openNovel` | `Open the novel` | `Ouvrir le roman` |
| `cause.contentRemoved.browseOthers` | `Browse other sites` | `Parcourir les autres sites` |
| `cause.generic.kicker` | `THIS SITE COULD NOT BE READ` | `CE SITE N'A PAS PU ÊTRE LU` |
| `cause.generic.title` | `This site could not be read, and the details of why were lost.` | `Ce site n'a pas pu être lu, et les détails de la raison ont été perdus.` |
| `cause.generic.body` | `The app will not guess which of the four causes it was. Try again, and the reason will be recorded this time.` | `L'application ne devinera pas laquelle des quatre causes il s'agissait. Réessayez : la raison sera enregistrée cette fois.` |
| `stillWorks.label` | `WHAT STILL WORKS` | `CE QUI MARCHE TOUJOURS` |
| `stillWorks.offline` | `Your {library} kept novels and {downloaded} downloaded chapters open with no connection.` | `Vos {library} romans conservés et vos {downloaded} chapitres téléchargés s'ouvrent sans connexion.` |
| `stillWorks.otherSource` | `{source} is unaffected — keep reading from it.` | `{source} n'est pas concerné : continuez à y lire.` |
| `stillWorks.positions` | `Your {positions} reading positions are untouched.` | `Vos {positions} positions de lecture ne sont pas touchées.` |
| `stillWorks.openLibrary` | `Open the library` | `Ouvrir la bibliothèque` |
| `stillWorks.openOtherSource` | `Open {source}` | `Ouvrir {source}` |
| `retry.again` | `Try again` | `Réessayer` |
| `retry.againSame` | `It failed again at {time}. Same cause: {cause}.` | `Cela a encore échoué à {heure}. Même cause : {cause}.` |
| `retry.changedCause` | `This is a different problem from last time.` | `C'est un problème différent de la dernière fois.` |
| `copy.message` | `Copy this message` | `Copier ce message` |
| `copy.done` | `Message copied.` | `Message copié.` |
| `button.back` | `Go back` | `Revenir` |
| `resolved.title` | `{source} is working again.` | `{source} fonctionne de nouveau.` |
| `resolved.open` | `Open {source}` | `Ouvrir {source}` |
| `resolved.lastChecked` | `Last checked {relative}.` | `Dernière vérification {relative}.` |
| `resolved.neverChecked` | `Never checked.` | `Jamais vérifiée.` |

> **Two strings that must never appear on this screen, in either language**: `0 results` / `0 résultat`, and `No results` / `Aucun résultat`. They belong to the site's own empty-result signal, which renders on the browse surface in `EmptyState` and never routes here. SC-6 is only demonstrable if the two states share no vocabulary at all, and this is where that is enforced — a reviewer testing SC-6 will be reading these two strings before the other twenty.

> Three of the nine are unusually shaped, and each says why: **Loading** exists only for a cold-start read of the cause record; **Empty — never visited** is unreachable and redirects; **Empty — no data** is a *routing invariant*, because this screen does not exist for the genuine-empty case and that is the strongest form of the guarantee.

---

## 5. Interactions

| Element | Event | Behaviour | Visual feedback | Resulting state | Rule |
|---|---|---|---|---|---|
| Title-bar back / system back | tap / back | Pop to `/browse` | `--duration-normal` 200ms `--ease-standard` | Browse | — |
| **Cause: no connection** — `Try again` | tap | Re-request **the one page** the app was reading when it failed | Button enters `loading`: 16dp spinner, label hidden, width locked | Submit error, or Success | **B24**, E5 |
| **Cause: layout changed** — `Try again` | tap | The same single re-request. Offered because a site mid-deployment **can** be a temporary state, and the sentence says so: *"Sometimes this fixes itself while the site finishes a change. Usually it does not."* | As above | Submit error, or Success | **B24**, E4 |
| — `Copy this message` | tap | Put the kicker, the finding and the **evidence line** on the clipboard — the app's own words, no site content | Snackbar: *"Message copied."* | Filled | **C12** |
| **Cause: site not serving** — `Try again` | tap | The button first enters a **visible 60-second countdown**, disabled, captioned *"Available again in 0:47"*, and only then re-requests. The countdown is **reader-initiated** — the reader pressed the button; the app still never retries on its own | Countdown caption updates once a second; no spinner until the request is sent | Submit error, or Success | **B24**, **C7** |
| **Cause: removed at source** — **no retry exists** | — | **The button is absent.** In its place, `--text-caption`: *"There is nothing to retry here."* | — | Filled | **B22**, E9 |
| — `Open the novel` | tap | Push `/library/novel/:novelId` — **present only when the novel is in the library.** If it is not, this action is absent and `Browse other sites` appears instead | Push | Filled | **B7**, **B23** |
| — `Go back` | tap | Pop to `/browse` | Push/pop `--duration-normal` | Browse | — |
| `StillWorksBlock` — `Open the library` | tap | Push `/library`, which opens with **zero network calls** (C14) | Push | Filled | **B7**, **C14** |
| `StillWorksBlock` — `Open {other source}` | tap | Push `/browse/:otherSourceId` — **present only when another source is enabled and this is not it.** Its absence is the honest rendering of "there is no other site", which after B1 is a real state when only FanMTL is registered | Push | Filled | **B23**, B1 |
| — anywhere on the page | scroll | Vertical scroll only | — | Filled | — |
| — during a retry | tap | **The cause block does not become a spinner and the `StillWorksBlock` does not change.** The counts stay visible while the request is in flight, because they are local facts and a request cannot alter them (B48) | — | Submit error, or Success | **B48** |
| Automatic retry | — | **Does not exist.** No timed retry, no retry on app open, no retry on reconnect, no background check. Ever | — | — | **B35**, **B24** |
| Any `Share` / `Export` / `Send` action | — | **Does not exist**, and the absence is not a courtesy to the reader in a bad moment | — | — | **B30** |

- **Focus / keyboard**: focus order is the cause block's actions, then the `StillWorksBlock`'s actions. The kicker, title, sentence and evidence line are **text, not focusable** — a screen reader reads them as one announcement in reading order, which is exactly what C12 needs, since it is that announcement a reader repeats to the owner. `Esc` returns. Focus is visible at 2dp `--color-border-focus` with a 2dp offset and is never removed.
- **Gestures**: vertical scroll only. **No pull-to-refresh** — deliberately, and for the same reason as everywhere else in this app: the gesture that means *this list is stale* must not exist on a page whose whole claim is that it is not a list. Refresh is the explicit named button, because on this screen retrying is a **decision with a cause attached**, not a reflex.
- **Animations**: push/pop `--duration-normal` 200ms `--ease-standard`; a cause change cross-fades over `--duration-normal` so the replacement is visible as a replacement; `--shadow-sheet` on the snackbar. **No animation on the retry itself** — a spinner is the feedback. Every duration becomes `0ms` under reduce-motion, and the cross-fade becomes an instant swap.
- **Back**: pops to `/browse`. **The cause record is written before the route is pushed**, never on the way out — so leaving by any route, including the system back gesture, cannot lose the diagnosis that C5 and C6 depend on.

---

## 6. Responsive

| Breakpoint | Behaviour | What collapses or disappears |
|---|---|---|
| **Mobile** `< 600dp` | Single column, `--space-lg` 16dp margins, both blocks `--color-surface-sunken`. The `StillWorksBlock` actions are full-width and stack when they do not fit below 400dp | Nothing. This is the design target |
| **Tablet** `600–1023dp` | Identical single column, centred, **capped** — the sentence and evidence lines stop widening so the measure stays readable, and the blocks do not stretch | Nothing collapses — the layout simply stops widening |
| **Desktop** `1024–1439dp` | Same single column, centred, same cap. Flutter desktop is out of scope | — |

- **Touch target**: **48dp minimum** on every action. The `StillWorksBlock`'s three lines are **not interactive** and are set at text height with `--space-sm` 8dp between them — they are sentences, and a 48dp hit area on a sentence with no behaviour is a tap that does nothing.
- **Overflow**: **guaranteed never to overflow.** Every sentence and evidence line wraps; **none truncates**, because a truncated diagnosis is worse than a tall page. The source's name is the longest single token and it wraps inside the sentence rather than being abbreviated. The 24dp icon and the kicker sit on their own line at every width — they are never pushed beside the title, because an icon squeezed to 16dp is no longer the recognisable glyph the cause depends on.

---

## 7. Accessibility

- [x] **Contrast 14.48:1** (day) / **12.00:1** (night) for the cause sentence and the `StillWorksBlock` lines — `--color-text-primary` on `--color-surface-sunken`, measured, not asserted.
- [x] **Contrast 6.22:1** / **6.01:1** for the evidence line, the dictation line and the no-retry line — `--color-text-secondary`. Never caption contrast for the evidence, because it is the diagnosis.
- [x] **Contrast 6.64:1** / **6.22:1** (`--color-error`), **4.74:1** / **6.78:1** (`--color-info`), **4.80:1** / **7.36:1** (`--color-warning`), **4.68:1** / **6.89:1** (`--color-success`) for the kicker and the icons — and **no meaning is ever carried by one of them alone**: each cause ships a distinct **icon shape**, a distinct **kicker in words**, a distinct **colour**, and a distinct **action**. Four independent channels, because this is the screen where a reader who cannot distinguish the colours must still be able to tell a missing connection from a changed layout.
- [x] **Contrast 5.54:1** / **7.27:1** for the `primary` action label — `--color-text-inverse` on `--color-accent`.
- [x] **Contrast 6.07:1** / **8.86:1** for the focus ring — `--color-border-focus`, measured as non-text per WCAG 1.4.11.
- [x] **Keyboard navigation complete** at every breakpoint; every action reachable and operable; focus visible at 2dp with a 2dp offset, never removed.
- [x] **The whole block announces as one node per element, in reading order**, and the cause is announced first: *"No connection. FanMTL could not be reached from this phone. The app cannot tell whether it is working, so it does not guess. Try again."* The evidence line is inside that announcement, because a screen-reader user is the reader most likely to be reporting this to the owner (C12).
- [x] **The `StillWorksBlock` is a labelled group of three**, and the counts are spoken with their units: *"Your 14 kept novels and 512 downloaded chapters open with no connection."*
- [x] **Reading order and language correct**: every sentence, kicker, evidence line and action exists in French and English (B28), with French as the fallback. The **evidence line's HTTP status is not translated** — `HTTP 429` is a protocol fact, not prose, and translating it would make it harder to recognise. `dir` follows the language; no RTL source exists in v1.
- [x] **Reduce-motion honoured**: the cause cross-fade becomes an instant swap; the countdown still counts, because it is information and not decoration.

---

## 8. Data

| Field | Type | Origin | Required | Possible error |
|---|---|---|---|---|
| `sourceId` | `String` | route param | yes | Unknown → the router cannot resolve the route and falls back to `/browse`; **never** an empty page |
| `sourceName` | `String` | local, the static registry (ADR-013) | yes | Absent → the route cannot render and redirects to `/browse` |
| `causeClass` | `enum(no_connection\|layout_changed\|site_unavailable\|content_removed)` | **local, persisted** with the failed request | yes | Record unreadable → the Load-error state, which refuses to guess |
| `causeEvidence` | `String` | local, persisted — `HTTP 429`, `HTTP 200 · 0 expected elements found`, `no connection to {host}`, `HTTP 404 · site "not found" signal` | yes | Absent → the evidence line is omitted and the sentence says the detail was lost; **never** invented |
| `whatWasBeingRead` | `String` | local, persisted — the catalogue page, the chapter list, this novel's details, this chapter | yes | Absent → the sentence drops the object and stays grammatical |
| `causeFirstSeenAt` | `DateTime` | local | no | Absent → the "since" line is omitted |
| `causeObservations` | `List<{at, outcome, causeClass?}>` | local, appended, never edited | yes | — |
| `libraryCount` | `int` | local | no | Query fails → the line is **omitted entirely**, never shown as `0` (B48's lesson applied again: no invented local number) |
| `downloadedChapterCount` | `int` | local | no | As above |
| `readingPositionCount` | `int` | local | no | As above |
| `otherEnabledSourceName` | `String?` | `SourceManager` | no | Null → that line **and its action** are absent. After B1 this is a real state when only one source is registered |
| `lastCheckedAt` | `Date?` | local | no | Null → *"never checked"*, in B49's words (B15) |
| `retryAvailableAt` | `DateTime?` | local, in-memory | no | Null → no countdown; only the `site_unavailable` cause sets it |

- **Loading**: nothing is paged. One record read from disk (the cause), three local counts, one registry lookup. All of it is fast; the Loading state exists because a cold-start route entry does not have a live failure in memory.
- **Cache / offline**: **this screen is complete with no connection**, because every field on it is local. The retry is the only action that needs a network, and it fails into a cause rather than into a blank page. `C14` does not apply to this screen — it is the one surface that legitimately requires a connection, and it says so.
- **Sensitive data**: **nothing here is ever logged, and nothing here is ever sent.** The `causeEvidence` string contains an HTTP status and a hostname and **no chapter content, no novel title beyond the one the reader was already looking at, and nothing from the page itself** — a diagnostic string written by the app, not scraped from a site. `Copy this message` puts that same app-written diagnostic on the clipboard: it is the **second and last** clipboard use in the product (the first is `Copy version number` on the About screen), and both are diagnostics the reader may need to read aloud. **No chapter text, no novel file and no reading position is ever placed on the clipboard by any screen** — B30 is not close to being tested.

---

## 9. Traceability

| ID | Origin | Manifestation on this screen |
|---|---|---|
| B22 | PRD | **The screen exists because of this rule, and its whole rendering is the discriminator.** No list region · a diagnosis kicker that is never the word `ERROR` · an evidence line that a genuine no-results state cannot have · and the string ban on `0 results`, `No results`, `Nothing found`, `Empty` across this screen and the view that routes to it. The routing invariant is stated in § 4: the site's own empty-result signal goes to `EmptyState`; only "could not read" reaches this route |
| B23 | PRD | **`StillWorksBlock` is a structural block, not a clause in the error sentence** — three counted lines with their own actions. One failing site never blocks another, and never makes stored chapters unreadable, and the reader is told which of those is true by numbers rather than by reassurance |
| B24 | PRD | Every action that can fail shows an error with a way to try again — **except where there is nothing to try**, and that case says so in words rather than showing a button that lies. Every failure on this screen is a sentence the reader can act on, never a colour and never a blank page |
| B28 | PRD | Every kicker, title, sentence, evidence label, dictation line and action exists in French and English. **HTTP status codes are not translated** — they are protocol facts, and translating them would make them harder to recognise |
| B30 | PRD | **No share, no export, no send — not as a consolation, and not at all.** The `§ 8` entry records that this product has exactly two clipboard uses and neither carries site or chapter content |
| B2 | PRD | The screen names **one** source and, where another is registered and enabled, names it as the unaffected one. Nothing here merges, pools or generalises across sources |
| B5 | PRD | Retry re-requests **the one page** that failed, and the screen says so. Nothing on this page prefetches, enqueues a download, or speculates |
| B7 | PRD | For the `content_removed` cause the primary action is **Open the novel** — the stored chapters are the point, and they still read (B7, E9) |
| B50 | PRD | If a source declares search and then returns nothing usable, that is a **broken source** and lands here — never on a search screen showing "no results". This is the case B50 names explicitly, and it is why the evidence line can say *"the site answered, and returned no results for a search it advertises"* |
| E2 | PRD | A chapter list whose entries cannot be parsed as entries → `layout_changed`, with the evidence line naming the parse outcome, and **no chapter list is rendered at all** |
| E3 | PRD | A chapter whose continuation pages cannot be joined → `layout_changed` on that chapter. **No partial chapter is shown and no half-joined text is stored** (B6) |
| E4 | PRD | The site's layout changed → the `layout_changed` cause. The app states it could not read the site, shows the evidence, and offers the two actions a reader can actually take: retry, and copy the message |
| E5 | PRD | No connection while browsing or searching → the `no_connection` cause, with its own kicker and icon, **not** a generic offline banner |
| E8 | PRD | A page that loads with none of the expected items → `layout_changed`, **never** "no results". The evidence line is where this is visible: *HTTP 200, 0 expected elements found* |
| E9 | PRD | A novel removed at its site → the `content_removed` cause, `Open the novel` as the primary action, **no retry button**, and the guarantee that the stored chapters are untouched. Offline, the app makes no claim about the site at all — it shows only what is stored |
| E18 | PRD | A chapter page with no real text → `layout_changed` on that chapter, with the evidence line naming the threshold, and **the chapter is not stored as complete** (B6). The retry here re-fetches; it does not patch |
| E19 | PRD | A search that genuinely matches nothing → **not this screen.** It is `EmptyState` on the search surface, in different words, with no icon, no kicker and no evidence line. The two states are separated by the site's own signal and by a string ban |
| C6 | PRD | With no server and no telemetry, the app's failures must be recognisable **on the device** and reported there. The evidence line and the dictation sentence are that requirement as an interface |
| C7 | PRD | Sites change without warning and go down overnight. The `--color-error` state exists for the first and the `--color-warning` state for the second, and **the app never silently returns nothing** — which is the failure mode C7 calls the main thing to avoid |
| C12 | PRD | Every sentence here can be read aloud and reported back. The `Copy this message` action and the pre-written *Say: …* line exist because of this constraint, and the Load-error state refuses to guess a cause precisely so that a misreport is not created |

---

## 10. Gate checklist

- [x] All nine states described, with a concrete rendering. The four with nothing distinct to render say **why** they have none — and one of those, *Empty — no data*, is a routing invariant rather than a blank cell.
- [x] Every interactive element has a behaviour, a feedback, a resulting state and a rule ID.
- [x] Responsive defined at **every** breakpoint in the design system — and the two larger ones say "identical, stop widening", which is ADR-010.
- [x] Anti-generic section checked **and justified**; the assumed choice is stated: **seven mechanical differences from an empty list, and a retry button that is deliberately absent where retry cannot help.**
- [x] No design value left "to be defined". Every colour, size, duration and easing cited exists in `design-system.md` with a value.
- [x] Every B/E/C ID on this screen appears in § 9.
- [x] `forge-guard placeholders` reports nothing here.
- [x] Consistent with `design-system.md`: `ErrorState`'s contract — an icon, a sentence naming **what failed and what still works**, a `secondary` retry — is honoured, extended with the evidence line rather than replaced.
- [x] **Every token cited by this screen exists in the design system, with the value it is given here.** The full citation table is § 12.
- [x] **SC-6 demonstrable by looking**: a reviewer can put a captured fixture of a changed-layout site on one side and this screen on the other, and see a page with a diagnosis, an evidence line and an action — against a page that would have said `0 results` and had nothing else on it.

---

## 11. Deliberately absent — and why that is not a gap

| Absent | Rule | Why |
|---|---|---|
| **Share**, **export**, **send to…**, "copy the chapter text" | **B30**, ADR-010 | A failure is exactly when a reader reaches for a share sheet, and the answer is that there is none, ever — not that there is none *right now*. A consolation share would also be the one action that could move third-party content off the device, which C1 and C4 exist to prevent |
| A "report this to the developer" form, a feedback box, a bug-report dialog, an email link | **B29**, C2 | There is nowhere for it to go. The product has no server, no account and no support function, and a form that collects a description and sends it nowhere is worse than no form — it teaches the reader that reporting works. `Copy this message` and the *Say: …* line are the real affordances, and both keep the data on the device |
| An automatic retry, a retry timer, a retry on reconnect, a "check again" on app open | **B35**, C7 | The app does not act on its own account. A source that is down would then be re-requested every time the reader opened the app, from a site that may already be refusing it (C7) |
| A "skip this source" or "disable this source" button | B1, B23 | The reader can disable a source in Settings → Sources, where the setting lives, and doing it here would put a preference inside an error. More importantly, disabling one source must not look like it affects the others — B23's guarantee is better served by the settings screen than by a button next to a failure |
| An illustrated empty state, an icon in a coloured circle, a mascot | design-system § 0 anti-references | Ruled out by the design system, and doubly so here: the failure is real and a decoration would soften the only thing this screen is for |
| A progress bar or a spinner over the whole page | — | The retry is one page, not a batch. A full-page spinner would imply a long operation and, worse, would replace the `StillWorksBlock` — the numbers the reader most needs while waiting |
| "It will be fixed soon", an ETA, a "the developer has been notified" | C5, C6 | There is no notification. Nobody was told. The only honest claim is the one in the body sentence: the fix, if it comes, arrives as a new version the reader installs by hand |
| A "learn more" link | — | There is nothing to learn more *about*: no documentation site, no changelog, no account. A link out of a failure page to nowhere is the same false affordance as an empty list |

---

## 12. Tokens this screen cites

Every value below is the one the design system declares, so `design-check tokens-used` can re-derive it. Only the colour rows are contrast-measured, and each figure is the design system's own worst-case figure for that token across the surfaces it is legal on.

| Token | Day | Night | Measured (day / night) | Where it appears here |
|---|---|---|---|---|
| `--color-background` | `#F5F2ED` | `#121315` | — | The page field behind both blocks |
| `--color-surface-sunken` | `#EBE7E0` | `#0C0D0F` | — | `CauseBlock`, `StillWorksBlock`, the loading skeleton |
| `--color-surface` | `#FBF9F6` | `#1A1C1F` | — | The skeleton bars inside the cause block |
| `--color-text-primary` | `#1A1714` | `#E8E4DD` | **14.48:1** / **12.00:1** | The cause title and sentence, the three "what still works" lines |
| `--color-text-secondary` | `#5A524A` | `#A8A29A` | **6.22:1** / **6.01:1** | The evidence line, the dictation line, the no-retry line, the since/last-checked line |
| `--color-error` | `#8A3228` | `#EE8B76` | **6.64:1** / **6.22:1** | The `layout_changed` kicker and `Icons.sync_problem`; the Load-error block |
| `--color-warning` | `#8A5A12` | `#E0AC47` | **4.80:1** / **7.36:1** | The `site_unavailable` kicker and `Icons.hourglass_empty` |
| `--color-info` | `#426986` | `#7FB3DA` | **4.74:1** / **6.78:1** | The `no_connection` kicker and `Icons.wifi_off`; the "different problem from last time" line |
| `--color-success` | `#40713A` | `#7FBE72` | **4.68:1** / **6.89:1** | The three `Icons.check_circle` marks in `StillWorksBlock`; the resolution block |
| `--color-accent` | `#8A4B12` | `#E3A857` | **5.50:1** / **7.25:1** | Focus ring, and the `ghost` action label. **Never inside the cause block** |
| `--color-text-inverse` | `#FDFAF6` | `#17181A` | **5.54:1** / **7.27:1** | The resolution block's `primary` **Open FanMTL** label |
| `--color-surface-raised` | `#FEFCF9` | `#232629` | — | The snackbar host only |

Non-colour tokens cited: `--text-overline` `#11/16` at 600 with `letter-spacing 0.08em`, set uppercase — **the only uppercase label in the app**, used here for the cause kicker and for the two block labels; `--text-h3` `#20/26` at 600 (the cause title, the resolution headline); `--text-h4` `#18/24` at 600 (the three `StillWorksBlock` lines); `--text-body` `#16/24` at 400 (the cause sentence); `--text-caption` `#12/16` at 400 (the evidence line, the dictation line, the no-retry line, the countdown caption, the since/last-checked line); `--space-sm` `8dp` (between the three `StillWorksBlock` lines); `--space-md` `12dp` (block internal padding); `--space-lg` `16dp` (page margin); `--space-xl` `24dp` (icon to kicker, sentence to actions); `--space-2xl` `32dp` (between the two blocks); `--space-3xl` `48dp` (page top margin); `--border-width` `1dp` (the `--color-border` rule is **not** used on this screen — separation between the two blocks is space, per § 1.4); `--shadow-none` on both blocks; `--shadow-sheet` `0 8 24 rgba(0,0,0,0.18)` (snackbar); `--radius-lg` `16dp` (both blocks); `--duration-normal` `200ms` (push/pop, the cause cross-fade, the loading shimmer); `--ease-standard` `cubic-bezier(0.2, 0, 0, 1)`; `--bp-mobile` `< 600dp`, `--bp-tablet` `600–1023dp`, `--bp-desktop` `1024–1439dp`; touch target `48dp`.

**Two places where this screen uses a semantic colour beyond the usage the design system records, and why.** `--color-warning`'s declared usage is *Partial or interrupted download*; here it marks **the site refusing or rate-limiting** (`Icons.hourglass_empty`) and **the novel removed at the source** (`Icons.block`). The token's semantics are "something the app wanted did not complete, and it is not the app's own bug" — both causes are exactly that, and neither is a partial download. `--color-error` is **withheld** from them deliberately: a refusing site and a removed novel are things happening on the reader's side of the world, and colouring them the same brick red as a changed layout would tell the reader the app is at fault when in one case it is the site and in the other it is the site's author. The token's meaning is extended, not overridden, and it is recorded here rather than left for the next reader of the design system to discover as a drift. `--color-info`, by contrast, needs no extension: the design system already assigns it "neutral notices, and the *never checked* state — an absence of information, so it must not borrow the colour that means *something went wrong*", and **no connection is the same kind of fact** — an absence, not a failure — which is why it is the one cause that is not red and not amber.