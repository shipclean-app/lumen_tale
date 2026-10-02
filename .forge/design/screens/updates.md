---
type: screen
slug: updates
title: Updates
module: updates
status: approved
generated_at: 2026-10-02
derived_from:
  - .forge/prd.md
  - .forge/design/design-system.md
rule_ids:
  - B11
  - B13
  - B14
  - B15
  - B16
  - B17
  - B22
  - B24
  - B26
  - B28
  - B35
  - B36
  - B37
  - B38
  - B39
  - B48
  - B49
edge_case_ids:
  - E4
  - E5
  - E8
  - E9
  - E12
  - E16
  - E20
flow: update-loop
---

# Screen — Updates

> The source of truth for generating this screen. It is the app's **only pull-loop**, and the two halves of that loop — *checking* and *downloading* — are rendered as two separate surfaces because B38 says they never overlap. The per-novel action sheet is specified in § 11.

---

## 1. Role of the screen

| | |
|---|---|
| **App archetype** | `mobile_consumer` |
| **Module** | updates — **rank 2 of 5** in the bottom navigation |
| **Route** | `/updates` |
| **Type** | list page, bottom-nav destination (its own `StatefulShellRoute` branch) |
| **Users** | the reader returning to a serialised novel; the reader deciding, once a week, whether to turn automatic checking on |
| **User stories served** | US-10, US-11, US-09, US-16 |
| **Business rules** | B11 B13 B14 B15 B16 B17 B22 B24 B26 B28 B35 B36 B37 B38 B39 B48 B49 |
| **Edge cases** | E4 E5 E8 E9 E12 E16 E20 |

**In one sentence**: this screen tells the reader which of the novels they keep have chapters they have not opened, says honestly how recently the app last looked at each one, and keeps *checking* and *downloading* as two things they choose separately.

**Why it is rank 2**: new-before-past. It is the app's only pull-loop — the reason a reader comes back to a novel they are not reading yet — and the pull is what brings them to the app at all. It sits below Library because coming back to *your* shelf outranks finding out what moved.

---

## 2. Visual direction for this screen

| | |
|---|---|
| **Mood** | quiet, warm, unhurried — the tone of a mail client's unread view: factual, unexcited, never a nudge |
| **Density** | **dense** — the same 72dp `NovelRow` as the library, because this is the same scan at a different question. One extra line is spent on the verification timestamp, and it is worth a line: it is the difference between "there is something new" and "there is something new *and I know how fresh that is*" |
| **Contrast level** | **high** — `--color-text-primary` `#1A1714` / `#E8E4DD` at **14.48:1** / **12.00:1** for titles; `--color-text-secondary` `#5A524A` / `#A8A29A` at **6.22:1** / **6.01:1** for the count and the timestamp, which are the two numbers the reader came for |
| **Surface** | rows on `--color-surface` `#FBF9F6` / `#1A1C1F` full-bleed over `--color-background` `#F5F2ED` / `#121315`; the schedule notice and the bulk section sit on `--color-surface-raised` `#FEFCF9` / `#232629`; skeletons and progress tracks on `--color-surface-sunken` `#EBE7E0` / `#0C0D0F`. No shadows except the action sheet's `--shadow-sheet` and the bulk confirm's `--shadow-dialog` |
| **Accent used** | `--color-accent` `#8A4B12` / `#E3A857` — the unopened-count pill, the determinate progress bar, the focus ring, and **not** the check button. The check is a `TextButton` in the app bar, never a filled `primary`: a filled primary on this screen would tell the reader that checking is what they came to do, and they came to **read**. The most prominent control here is a chapter, not a cron job |
| **Photographic treatment** | **thumbnail** — the 48dp cover, `--radius-sm` 4dp, no border, no shadow; absent covers fall back to the initials block, which is `NovelRow`'s `offline` state |
| **Reference** | an email client's unread view: newest first, a count per thread, "mark all read" kept physically away from "sync" — because they are not the same act and one of them costs data |

### 2.1 Anti-generic — mandatory

This screen must not resemble any of these defects:

- [x] **No pure white `#FFFFFF` background** — `--color-background` is `#F5F2ED` day / `#121315` night.
- [x] **No shadowed card per row.** Rows are flat strips on the page field, separated by `--color-border`; the only raised surfaces are the notice block and the action sheet.
- [x] **Not uniform.** `--text-h1` 31/38 for the screen title, `--text-overline` 11/16 600 with 0.08em for the three section labels, `--text-h4` 18/24 for a novel title, `--text-body-sm` 14/20 for the author, `--text-caption` 12/16 tabular for both timestamps. Four scales and two weights, and the 72dp row rhythm carries the rest.
- [x] **No generic grey `#6B7280`** — the paper-anchored neutral ramp.
- [x] **No symmetric centring as the layout.** Full-bleed rows with `--space-md` internal padding, left-aligned metadata, a `--space-lg`-margined notice block.
- [x] **No generic spot illustration** — the two empty states are a sentence and one button, per the anti-references in `design-system.md` § 0: **no illustration, no "you have unread!" badge as a reward, no confetti, no streak.** An updates screen is exactly where a consumer app puts gamification, and the whole design refuses it here.
- [x] **Not one typeface at one weight** — the same reasoning as the library: scale and tracking carry the hierarchy, not a second family (ADR-017's serif belongs to prose).

**Assumed, non-neutral choice**: **the check and the downloads are not in the same button group, anywhere.** Checking lives in the app bar as a quiet `TextButton`; downloading lives per row (inside a long-press sheet, not the row itself) and library-wide in a **separate section below a `--color-border` rule, under its own overline**. B38 says a check never enqueues, defers or triggers a download, and the only honest way to make an invisible separation visible is to never put the two controls where one thumb could press both. Three consequences follow from the same decision: the running-check line in the status bar literally reads *nothing is downloaded*; **the check needs no confirmation dialog while every download does**, and the asymmetry is B38's cost model made visible rather than an inconsistency; and there is no affordance on this screen that does both, so the invariant cannot be broken by a mis-tap. The second non-neutral choice: **no "updated" spinner ever sits on a row.** The count on a row is a local fact and cannot be loading — a spinner next to it would tell the reader the number depends on the network, which is the one misunderstanding B48 exists to prevent.

---

## 3. Anatomy

```
AppScaffold (titleBar, bottomNav, persistentStatus)
├── TitleBar
│   ├── Title "Updates"                          --text-h1 31/38 700
│   ├── CheckButton  TextButton, accent label    "Check for new chapters"  (B36, not confirmed — B38)
│   └── ScheduleButton → /more/settings          opens the automatic-check setting (B35)
├── ScheduleNotice            --color-surface-raised, --radius-lg, --space-md padding
│   ├── NoticeText            "Automatic checks are off. Nothing is looked at unless you tap Check,
│   │                          and opening the app is not a check either."   (B35, B36)
│   └── NoticeLink            "Turn automatic checks on"  → the interval picker
├── UpdateList
│   ├── SectionHeader         overline "UNOPENED CHAPTERS" + "4 novels · 96 chapters you have not opened"   (local, B48)
│   ├── UpdateRow = NovelRow variant library, 72dp
│   │   ├── StatusChip new      "12 not opened"            — the local count (B14, B48)
│   │   ├── StatusChip local / never-checked
│   │   │                       "Last checked 3 days ago" · "Never checked"   (B49)
│   │   ├── StatusChip failed   "Could not check"          (B22)
│   │   └── trailing            determinate progress bar while a download runs
│   └── TerminalLine           "All 23 novels checked · none skipped."  (B39)
├── BulkSection               --color-border rule above, --space-2xl above the rule
│   ├── Overline "ACROSS YOUR LIBRARY — DOWNLOADING IS A SEPARATE CHOICE"   (B38)
│   ├── SecondaryButton        "Download all unopened (96)"  → confirm  (B18)
│   └── SecondaryButton        "Mark everything as read"     → confirm  (B13)
└── NovelActionSheet · ConfirmDialog · SnackBarHost · EmptyState · ErrorState · LoadingState
```

| # | Component | Role | Source |
|---|---|---|---|
| 1 | `NovelRow` variant `library` | One kept novel with an unopened-chapter count | design-system § 2.1 |
| 2 | `StatusChip` variants `new`, `never-checked`, `local`, `failed`, `downloading`, `downloaded` | The only place B48 and B49 are rendered | design-system § 2.5 |
| 3 | `TextButton` / `SecondaryButton` | The check, and the two bulk actions | design-system § 2.3 |
| 4 | `EmptyState` / `ErrorState` / `LoadingState` | Empty, unreadable store, first paint | design-system § 2.7 |
| 5 | `AppScaffold` | Title bar, bottom nav, and the `persistentStatus` slot that carries a running check | design-system § 2.8 |
| 6 | `ScheduleNotice` | **slice-local**: the raised block stating B35's default and B36's no-trigger-on-open. A composition of `Text` and a `TextButton` on `--color-surface-raised`; promoted to the design system only if a second screen needs it |
| 7 | `NovelActionSheet` | **slice-local**: the per-novel action sheet — see § 11 |

---

## 4. States — all nine, no exceptions

| State | Trigger | Rendering | Reader feedback |
|---|---|---|---|
| **Loading** — *first paint* | The local store has not returned yet (process death, cold start) | `LoadingState` shaped like the list: the notice block as two `--color-surface` lines, and **eight** `NovelRow` skeletons at 72dp — a 48dp cover block, a title line, a status line | None. This is a few milliseconds of work on data already on the phone |
| **Loading** — *a check is running* | A manual or scheduled check is in flight | **The list does not blank, dim or reload.** Every row keeps its exact count and its exact timestamp; the check button takes its `loading` state (16dp spinner, label hidden, width locked); `persistentStatus` reads **Checking 7 of 23 novels · nothing is downloaded** | A counter in novels, with no cap, and the two facts B38 and B39 are stated in the same line. **No row-level spinner** — see § 2.1 |
| **Filled** | The normal case: at least one kept novel has unopened chapters | The anatomy above. Novels are ordered by unopened count, descending; ties keep library order | — |
| **Empty — never visited** | The library is empty, so there is nothing to check. This is a real first-run state, not an error (B11, B12) | `EmptyState`: title *Nothing is followed yet*, body *Novels you keep appear here, with the chapters of each that you have not opened.*, and one `primary` **Browse a source** → `/browse`. **No illustration, no "no updates!" congratulation** | The one button leads to the only place a novel can enter the library |
| **Empty — no data** | Every kept novel has zero unopened chapters. **Two sub-cases, and they must not render alike** | **(a) Every novel has been checked**: title *No unopened chapters in the novels you keep*, body **Last check: today at 14:02**, and a `secondary` **Check for new chapters**. The timestamp is inside the empty state, because "nothing new" without a time is B49's exact failure. **(b) Nothing is unopened and at least one novel was never checked**: the same title, and the body reads **Never checked — the app has not looked at 3 of your novels**, never *up to date* | (b) is the sub-case that would otherwise lie: zero unopened chapters is a local truth, and pairing it with an unverified novel would present a local fact as a checked answer |
| **Load error** | Two different failures, two different sentences | **The local store could not be read**: `ErrorState` naming what failed and what still works — *Your update list could not be read. Your library and your downloaded chapters are unaffected* — with `secondary` **Try again**. **A check failed for some sites**: this is **per row**, as a `failed` chip worded *Could not check*, plus one line above the list: *4 novels could not be checked. Their unopened counts are still exact.* (B22, B48) | The line above the list is the heart of the screen: losing contact with a site changes the **verification**, never the **number**. A screen that greys those rows out would be saying the count is unknown, and it is not |
| **Submit error** | The submissions are the two bulk actions. **Download refused for storage** (E20): a dialog — *The download did not start. The phone has not enough free space.* — with `secondary` **Delete a chapter** and `primary` **Try again**, and nothing enqueued. **Mark everything as read write failed**: **every count on the screen stays exactly as it was** and a SnackBar says *Nothing was changed* | Neither ever leaves a half-applied state on screen. A bulk write that fails must not be visible until it succeeds, because the counts are the reader's only record of what they have read |
| **Success** | A check completed; a bulk download started; a bulk mark-as-read completed | Check: SnackBar **Checked 23 novels · 4 have chapters you have not opened**, and the checked rows' timestamps change in place. Bulk download: the section's button becomes a determinate progress state and the affected rows show their own bars. Bulk mark-as-read: every unopened count on screen falls to zero as the writes land, with SnackBar *Marked 96 chapters as read* | The check's success line reports **what it found**, not that it ran — the reader came for a number, not for an acknowledgement |
| **Offline / permissions** | No usable connection | **The list is byte-identical to Filled.** Every count is exact and local, so every count is shown (B48, C14). Two additions, both text: one line under the check button, **Checked chapters are from your last check · 3 novels were never checked**, and each novel's own verification chip is left **exactly as it was** — stale and visible | **No row is blanked, no count is hidden, and the screen never says "no new chapters" as a fresh answer** (B15). Tapping the check opens its surface with the action `disabled` at 48dp and the sentence *Checking needs a connection* |
| **Read-only** | Unconditional, and narrower here than on most screens | **Library membership is read-only on this screen.** There is no keep, no unkeep, no follow and no remove here: B11 makes keeping one act performed on the novel's own screen, and a second entry point for it would be a second concept. A check writes only two things — verification timestamps and what the site currently lists — and **never** the reader's reading position, never a downloaded file, and never their library | This screen reads the reader's library and their sites, and it changes the *app's knowledge*, not the reader's. Saying so is the point of the row: nothing here can be edited, only re-verified |

> Two of the nine have a second rendering and each says why: *Loading* has two because "the list is being built from local data" and "a network check is running" share a name and nothing else — the first shows skeletons, the second must show nothing change at all; and *Empty-no-data* has two because the difference between "checked and nothing new" and "never checked and nothing new" is the whole of B49.

---

## 5. Interactions

| Element | Event | Behaviour | Visual feedback | Resulting state | Rule |
|---|---|---|---|---|---|
| **Check for new chapters** | tap | Start a manual check of **every** novel in the library (B36, B39). **No confirmation** — a check downloads nothing (B38), so it costs no data and no storage, and a dialog implying otherwise would be the lie | Button `loading`; `persistentStatus` *Checking 1 of 23 novels · nothing is downloaded* | Checking → Filled | **B36**, **B38**, **B39** |
| `persistentStatus` — cancel | tap | Cancel **this run**. The schedule is untouched: cancelling one run does not disable the schedule (B37) | Status line replaced by *Check cancelled · your library is unchanged* | Filled | **B37** |
| `persistentStatus` | during a check | Counts novels, **never capped**, and says *nothing is downloaded* | Live counter | — | **B39**, **B38** |
| Terminal line | after a check | *All 23 novels checked · none skipped.* — B39 is the one rule a reader cannot otherwise verify: a check that quietly visited only the first fifty novels would look identical from outside, so the app states the count it reached | — | Filled | **B39** |
| Schedule link | tap | Open the automatic-check setting: **Never / every 12 / 24 / 48 / 72 hours / weekly**, with **Never** the default and an active choice that disables the schedule rather than skipping it | Standard push | — | **B35** |
| `UpdateRow` | tap | Push `/library/novel/:novelId` — the novel's own screen | `--duration-normal` 200ms, `--ease-standard` | Filled on the detail screen | — |
| `UpdateRow` | long-press | Open `NovelActionSheet` (§ 11): **Continue reading · Download new chapters · Mark as read · Open the novel** | Sheet slides up `--duration-normal`, `--shadow-sheet` | Filled + sheet | — |
| `NovelActionSheet` · Continue | tap | Open the reader at this novel's stored position (the position record, not this list — B17/B46) | No transition into the reader | Reader at position | **B16**, **B46** |
| `NovelActionSheet` · Download new chapters | tap | The same B18 sheet the novel's own screen uses, pre-scoped to **all unopened chapters**, then its confirm naming the count | Confirm → row takes `downloading` with determinate progress | Downloading | **B18**, **B38** |
| `NovelActionSheet` · Mark as read | tap | Confirm naming the count, then write the field opening a chapter writes | Row's count falls to 0 and the chip disappears | Filled | **B13**, **B14** |
| `NovelActionSheet` · Open the novel | tap | Push the novel's detail screen | Standard push | Filled | — |
| Bulk · **Download all unopened** | tap | Confirm: *Download 96 chapters across 4 novels. This uses mobile data and storage.* — the **all unopened** choice of B18, applied library-wide. **No "including chapters you already read" shortcut**, which B18 permits only by deliberate selection | Section button becomes the progress state; rows show their own bars | Downloading | **B18**, **B38** |
| Bulk · **Mark everything as read** | tap | Confirm: *Mark all 96 chapters in 4 novels as read?* | Every count on screen falls to zero as the writes land | Filled, all zero | **B13**, **B14** |
| Bulk row | — | **Both bulk actions are `secondary`, never `primary`, and they sit below a rule under their own overline.** A filled primary download button on this screen would put a data-costing action one thumb-reach from the row the reader came to press | — | — | **B38** |
| Row | swipe | **Absent** — no swipe-to-download, no swipe-to-mark-read. Marking 96 chapters read by accident is unrecoverable in the sense that matters: the reader's record of what they have opened is the only thing the count is computed from | — | — | **B13**, **B14** |
| List | pull-to-refresh | **Absent.** The check is a labelled button; a flick that visits 23 sites is a gesture whose cost cannot be seen, and B36's point is that opening the app is not a trigger | — | — | **B36** |
| List | tap on a `failed` chip | Nothing — it is text, not a control. The retry is the check button | — | — | **B22** |
| Tab switch | tap another destination | The branch keeps its list and its scroll offset (go_router shell routes) | — | Filled | — |

- **Focus / keyboard**: D-pad moves through the two title-bar controls, the notice link, then row to row; focus ring 2dp `--color-border-focus`, 2dp offset, never removed. `Enter` opens the novel, the menu key opens the novel's action sheet, `Esc` closes it. Inside the sheet, focus is trapped until it is dismissed — it is a modal, and leaving focus on a hidden row is the standard way a keyboard user ends up reading nothing.
- **Gestures**: tap, long-press, scroll. No swipe, no pull-to-refresh, no pinch.
- **Animations**: sheet slide and screen push `--duration-normal` 200ms `--ease-standard`; press feedback and chip select `--duration-fast` 120ms. **The list does not animate while a check runs** — a reordering animation would move the rows the reader is looking at, on the one screen where the numbers are the point. All durations become `0ms` under reduce-motion.
- **Back**: system back pops or dismisses the sheet. A check in progress is **not** cancelled by leaving the screen: it is a foreground job with its own notification and its own cancel (B37), and cancelling it by accident with a back press would be the wrong default.

---

## 6. Responsive

| Breakpoint | Behaviour | What collapses or disappears |
|---|---|---|
| **Mobile** `< 600dp` | The design target. Single column, `--space-lg` 16dp margins on the notice block and the bulk section, rows full-bleed with `--space-md` internal padding, `--space-3xl` 48dp top margin | Nothing — this is what ships |
| **Tablet** `600–1023dp` | **Identical single column, centred, capped.** The column stops at the `--reader-md` measure width and centres. **This is deliberately not a tablet layout** (ADR-010, C3): there is no two-column novel grid and no list-plus-detail split here, even though this is the screen where a two-column grid would be easiest to add and least worth adding — 23 rows is not a grid problem | Nothing collapses — the layout simply stops growing |
| **Desktop** `1024–1439dp` | Same single column, centred. Flutter desktop is out of scope (C3) | — |

`--bp-wide` `≥ 1440dp` follows the same capped-and-centred rule by declaration (`design-system.md` § 1.7).

- **Touch target**: 48dp minimum. Rows are 72dp; the check and schedule controls are 48dp tall even in their `loading` state, with the label hidden and the width locked so the app bar never reflows mid-check; bulk buttons are 44dp in a 48dp-tall row.
- **Overflow**: **guaranteed never to overflow.** The novel title truncates to two lines, the timestamp truncates at `--text-caption` with the relative form (*3 days ago*) which is short by construction, and the notice text wraps to at most three lines at 320dp with the link on its own line. Nothing here is ever truncated mid-number: the unopened count is a two- or three-digit integer in a fixed-width slot.

---

## 7. Accessibility

- [x] **Contrast 14.48:1** (day) / **12.00:1** (night) for novel titles — `--color-text-primary` `#1A1714` / `#E8E4DD`, measured.
- [x] **Contrast 6.22:1** / **6.01:1** for the count and the timestamp — `--color-text-secondary` `#5A524A` / `#A8A29A`. Both are the numbers the reader came for, so both are body-text tokens and never the disabled one.
- [x] **Contrast 6.07:1** / **8.86:1** for the focus ring, non-text per WCAG 1.4.11 at 3:1.
- [x] **No state by colour alone**: the unopened count is a **number inside a pill**; `Never checked` is **wording** in the information token; `Could not check` is an icon **and** words in the error token; a running download is a determinate **line** plus a percentage in the semantics label. The screen never distinguishes a state with a hue alone.
- [x] **Keyboard navigation complete** over the app-bar controls, the notice link, every row, and the sheet's four actions; focus visible at 2dp, never removed; modal focus trapped in the sheet and restored to the row that opened it.
- [x] **Semantics per row**, one node: *"The Ascension of the Ninth Son, by Ilan W., Royal Road, 12 not opened, last checked 3 days ago"* — and for a failed one, *"…12 not opened, could not check"* — because "we lost contact" must reach a screen-reader user as words, since the visual difference is a hue and a chip.
- [x] **Semantics for the check**: the button's label is always *Check for new chapters*, never a bare icon, and its `loading` state keeps an accessibility label of *Checking, 7 of 23 novels* so the progress is not visual-only.
- [x] **Live region** on `persistentStatus` while a check runs, so the counter and its completion are announced. A check that takes forty seconds and says nothing is a check a screen-reader user cannot tell from a frozen app.
- [x] **Text alternative for covers**: decorative, `excludeSemantics` — the title beside them is the information.
- [x] **Language and reading direction** correct: all chrome follows the app locale (B28) with French fallback; relative timestamps are localised, and `dir` follows the language with no LTR assumption in the row's fact wrapping.
- [x] **Reduce-motion honoured**: the sheet still slides in 0ms, chip selection has no tween, and no list animation exists to disable.

---

## 8. Data

| Field | Type | Origin | Required | Possible error |
|---|---|---|---|---|
| `novel.id`, `novel.title`, `novel.author` | `String`, `String`, `String?` | local, verbatim from the site | id, title | author absent → the subtitle slot is omitted, row keeps 72dp |
| `novel.sourceName` | `String` | local | yes | Always shown: two novels with the same title must be tellable apart (B40, E17) |
| `novel.coverPath` | `String?` | local cache | no | Absent → initials block |
| `novel.unopenedCount` | `int` | **local**, over stored chapter-list metadata | yes | Exact, never an estimate, never stale (B14, B48) |
| `novel.lastCheckedAt` | `DateTime?` | local | no | `null` → **Never checked** (B49) |
| `novel.lastCheckError` | `String?` | local | no | → *Could not check*; a vanished novel → *No longer at <site>* (B22, E9) |
| `novel.siteChapterCount` | `int` | last successful check, stored locally | yes | **Used only for the schedule link's information and for reporting what a check found — never for the unopened count**, which is local (B48) |
| `novel.unopenedDownloaded` | `int` | local | yes | — |
| `novel.downloadProgress` | `double?` | live queue state | no | `null` → no bar in `trailing` |
| `schedule` | `enum(never, 12h, 24h, 48h, 72h, weekly)` | `shared_preferences`, **default `never`** | yes | Never → nothing is ever checked unless the reader taps (B35) |
| `lastRunAt`, `lastRunOutcome` | `DateTime?`, `enum` | local | no | `null` → the terminal line reads *No check has ever been run* (B49) |
| `connection` | `bool` | platform | yes | False → the offline sentence; never a row-level change |

- **Loading**: **the list loads in one block from the local store** — no paging, no per-row queries, no network. A check is a foreground job whose progress is displayed in `persistentStatus` and in the OS notification (B37); the list behind it does not reload, because the counts do not depend on it (B48).
- **Cache / offline**: **zero required network calls to open this screen** (C14). With the radio off the screen shows every novel, every exact count and every timestamp; only the check and the downloads are unavailable, and each says so in its own sentence.
- **Sensitive data**: nothing is transmitted and there is no analytics (B29). Logs carry novel ids, source names and check outcomes — **never chapter titles, never chapter text**, and never a request URL containing a reader-supplied query. There is no share or export action (B30).

---

## 9. Traceability

| ID | Origin | Manifestation on this screen |
|---|---|---|
| B11 | PRD | **Membership is read-only here.** No keep, no unkeep, no follow — keeping happens on the novel's own screen, so there is one list and one act |
| B13 | PRD | A count is the number of chapters not opened; both mark-as-read actions write the same field opening a chapter writes |
| B14 | PRD | Each row's number is exact and local; it is the number the story's success criterion SC-3 checks |
| B15 | PRD | Offline, every count is still shown and each novel's last-checked time — or **Never checked** — is still shown, and the check button says it needs a connection. The screen never presents "no new chapters" as a fresh answer |
| B16 | PRD | **Continue reading** opens the reader at the stored position, per novel, from the position record |
| B17 | PRD | Continue comes from the **reading-position record**, not from this list — the list may be aged out or cleared (B47) and the position may not (B46) |
| B22 | PRD | A site that could not be read is a `failed` chip worded *Could not check*, and a line above the list — never an empty row and never a zero count |
| B24 | PRD | The check button is the retry for every failed row, and the local store's own failure has its own sentence and retry |
| B26 | PRD | The whole screen re-themes on the phone's setting, with the in-app override one tap from the reader |
| B28 | PRD | Every string is ARB with French fallback, including the notice, the terminal line and both confirms |
| B35 | PRD | The **ScheduleNotice** states the default is off and that opening the app is not a check; the interval picker's default is Never and choosing it actively disables the schedule |
| B36 | PRD | The labelled check action is always available, whatever the schedule; **pull-to-refresh is absent**, so that opening the app is visibly not a trigger |
| B37 | PRD | A running check is cancellable from `persistentStatus`, and cancelling one run does not touch the schedule. The notification itself is an OS surface, and this screen does not pretend to render it |
| B38 | PRD | Check in the app bar, downloads per row and in a separate section under a rule; the running line says *nothing is downloaded*; the check is unconfirmed while downloads are confirmed |
| B39 | PRD | The progress counter has no cap, the terminal line reads *All 23 novels checked · none skipped*, and **no control anywhere offers a partial check** |
| B48 | PRD | Every count is computed locally and is displayed with no reference to a check; the failed rows keep their exact counts beside *Could not check* |
| B49 | PRD | **Never checked** is a chip of its own in the information token, wording only, and it survives in both the filled and the empty states — including the sub-case where nothing is unopened and the app has still not looked |
| E4 | PRD | A site whose layout changed is reported per row as a failure with the check button as its retry; it is never an empty row |
| E5 | PRD | Offline, the screen is the same list with one added sentence, plus per-action wording; nothing is hidden and no count changes |
| E8 | PRD | A page that loads with none of the expected chapter elements is a check failure, not "nothing new" |
| E9 | PRD | A novel the site has dropped reads *No longer at Royal Road* on its row, and keeps its exact local count |
| E12 | PRD | A language change re-localises the screen — including relative timestamps and both confirms — with no loss of the list |
| E16 | PRD | A chapter the site published after the last check stays invisible until a check finds it, and the row's count and timestamp never imply otherwise |
| E20 | PRD | The library-wide download refused for storage says why, enqueues nothing, and leaves every row's state untouched |

---

## 10. Gate checklist

- [x] All nine states described with a concrete rendering; the two that have a second rendering say **why** (loading is skeletons vs a running check, and empty-no-data is "checked and nothing" vs "never checked and nothing").
- [x] Every interactive element has a behaviour, a feedback, a resulting state and a rule ID.
- [x] Responsive defined at **every** breakpoint of the design system; the two larger ones say "identical, stop widening" — ADR-010, and the rejected two-column grid is named so it is not re-proposed.
- [x] Anti-generic section checked **and justified**; the assumed choices are stated (check and download never share a button group, and no row ever shows a spinner).
- [x] No design value left "to be defined". Every colour, size, duration and easing cited exists in `design-system.md` with its value.
- [x] Every B/E/C ID on this screen appears in § 9.
- [x] `forge-guard placeholders` reports nothing here.
- [x] Consistent with `design-system.md`: `StatusChip` is rendered in six of its declared variants and none outside them; the check's in-progress state reuses the `never-checked` presentation rather than inventing a seventh variant — see § 11.2. `--color-border-strong` is deliberately **not** cited: it marks a selected row, and this screen has no selection, because a long-press opens one novel's action sheet rather than selecting a set.
- [x] Material 3 primitives only (`CustomScrollView`, `ListView.builder`, `TextButton`, `OutlinedButton`, `AlertDialog`, `ModalBottomSheet`, `SnackBar`, `LinearProgressIndicator`, `FilterChip`) — ADR-001.
- [x] **Every token cited by this screen exists in the design system, with the value it is given here.** The full citation table is § 12.
- [x] **v1 reading is scroll-only** (ADR-009): this screen contains no page-turn, slide or swipe-to-turn affordance, not even disabled. It links into the reader and specifies nothing about how the reader reads.
- [x] **No gamification** (anti-references): no streak, no badge as a reward, no "you have unread!" celebration, no illustration. The count is a fact, not an achievement.

---

## 11. Sub-surfaces of this screen

### 11.1 `NovelActionSheet`

A `ModalBottomSheet` on `--color-surface-raised`, `--shadow-sheet`, `--radius-lg`, opened by long-pressing a row. Its header is the novel's title at `--text-h4` with its site, so the sheet is never ambiguous about what it acts on. Four actions, each 48dp:

| Action | Does | Rule |
|---|---|---|
| **Continue reading** | Opens the reader at the novel's stored position | B16, B46 |
| **Download new chapters** | Opens B18's sheet scoped to all unopened chapters, then its confirm | B18, B38 |
| **Mark as read** | Confirm naming the count, then the same field opening a chapter writes | B13, B14 |
| **Open the novel** | Pushes `/library/novel/:novelId` | — |

There is deliberately **no remove, no keep and no share** in it. Removing from the library happens on the novel's own screen with B32's promise attached to it (there is no backup, ADR-010), and B30 makes sharing out impossible.

**States**: *Loading* — none, and the reason is that every label is a local fact plus one enabled/disabled decision; *Filled* — as above; *Empty* — **not a state**, and it is worth saying why: a novel with zero unopened chapters still offers **Continue reading** and **Open the novel**, because those are the two actions that remain true when the count is zero. Hiding a sheet because a number is zero would hide the reader's way back into the book; *Load error* — none; *Submit error* — the download's refusal is its confirm's dialog (§ 4) and the sheet stays open beneath it; *Success* — the sheet closes and the affected row's chip changes, which is the confirmation; *Offline* — **Continue reading** and **Open the novel** stay enabled because both work offline, **Download new chapters** is `disabled` at 48dp with *Downloading needs a connection*, and **Mark as read** stays enabled because it is a local write. *Read-only* — none.

### 11.2 A note on the in-progress check state, and on a divergence in the design system

**The check in progress reuses the `never-checked` presentation** — the information token, wording only — because it is the same class of fact: *the app does not currently know what the site has*. Inventing a seventh `StatusChip` variant for a transient that lasts seconds and that the reader can cancel would add a component state no other screen needs, and the design system is explicit that screens must not invent components. The per-novel position during a check lives in `persistentStatus` as a counter, which is where a screen-level fact belongs.

**One divergence found, recorded rather than silently resolved.** `design-system.md` § 1.1 lists `never-checked` under `--color-warning`'s usage column, while § 2.5 declares `StatusChip`'s `never-checked` variant as **info**. This screen follows § 2.5, the component contract, because it is the more specific claim and because *info* is the right register for "we have not looked" — a warning colour would present the reader's own default (B35) as a fault. The colour table's usage cell is the thing that should change; this is left to the design system's owner rather than decided here.

---

## 12. Tokens this screen cites

Every value below is the one `design-system.md` declares, so `design-check tokens-used` can re-derive it. Only the colour rows are contrast-measured.

| Token | Day | Night | Measured (day / night) | Where it appears here |
|---|---|---|---|---|
| `--color-background` | `#F5F2ED` | `#121315` | — | Page field behind the full-bleed rows |
| `--color-surface` | `#FBF9F6` | `#1A1C1F` | — | Row strips, skeleton lines |
| `--color-surface-raised` | `#FEFCF9` | `#232629` | — | Schedule notice, `NovelActionSheet`, dialogs, the snackbar |
| `--color-surface-sunken` | `#EBE7E0` | `#0C0D0F` | — | Cover placeholder block, progress track, disabled action fill |
| `--color-text-primary` | `#1A1714` | `#E8E4DD` | **14.48:1** / **12.00:1** | Novel titles, screen title, sheet header |
| `--color-text-secondary` | `#5A524A` | `#A8A29A` | **6.22:1** / **6.01:1** | **The unopened count**, the last-checked timestamp, author line, the notice text |
| `--color-text-disabled` | `#6E665C` | `#948E87` | **4.58:1** / **4.69:1** | Initials block, disabled bulk actions while a download runs |
| `--color-text-inverse` | `#FDFAF6` | `#17181A` | **5.54:1** / **7.27:1** | Label inside the accent count pill |
| `--color-accent` | `#8A4B12` | `#E3A857` | **5.50:1** / **7.25:1** | Count pill fill, determinate progress bar, the check button's label, the focus ring |
| `--color-success` | `#40713A` | `#7FBE72` | **4.68:1** / **6.89:1** | `downloaded` chip on a fully downloaded novel |
| `--color-warning` | `#8A5A12` | `#E0AC47` | **4.80:1** / **7.36:1** | A download stopped part-way (connection lost, storage exhausted) |
| `--color-error` | `#8A3228` | `#EE8B76` | **6.64:1** / **6.22:1** | `failed` chip icon and words — *Could not check* — and the storage dialog |
| `--color-info` | `#426986` | `#7FB3DA` | **4.74:1** / **6.78:1** | **`Never checked`** chip and the in-progress check wording |
| `--color-border` | `#D9D3C9` | `#2E3237` | exempt | Rules between rows, and the rule that separates the bulk section from the list |
| `--color-border-field` | `#8F8778` | `#6B6560` | **3.18:1** / **3.24:1** | `secondary` bulk button outlines |
| `--color-border-focus` | `#8A4B12` | `#E3A857` | **6.07:1** / **8.86:1** | 2dp focus ring on every focusable element |

Non-colour tokens cited: `--text-h1` `#31 / 38`; `--text-h2` `#25 / 32`; `--text-h4` `#18 / 24`; `--text-body-sm` `#14 / 20`; `--text-caption` `#12 / 16`; `--text-overline` `#11 / 16` (600, 0.08em); `--space-xs` `4dp`; `--space-sm` `8dp`; `--space-md` `12dp`; `--space-lg` `16dp`; `--space-xl` `24dp`; `--space-2xl` `32dp`; `--space-3xl` `48dp`; `--radius-sm` `4dp`; `--radius-md` `8dp`; `--radius-lg` `16dp`; `--radius-full` `999dp`; `--border-width` `1dp`; `--border-width-strong` `2dp`; `--shadow-sheet` `0 8 24 rgba(0,0,0,0.18)`; `--shadow-dialog` `0 16 48 rgba(0,0,0,0.24)`; `--duration-fast` `120ms`; `--duration-normal` `200ms`; `--ease-standard` `cubic-bezier(0.2, 0, 0, 1)`.