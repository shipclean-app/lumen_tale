---
type: screen
slug: downloads
title: More — Downloads
module: more
status: approved
generated_at: 2026-10-02
derived_from:
  - .forge/prd.md
  - .forge/design/design-system.md
rule_ids:
  - B5
  - B18
  - B19
  - B20
  - B21
  - B22
  - B23
  - B24
  - B28
  - B32
  - B33
  - B38
  - C4
  - C8
  - C11
edge_case_ids:
  - E6
  - E7
  - E15
  - E18
  - E20
flow: download-loop
---

# Screen — More · Downloads

> The source of truth for generating this screen. **This is the screen most likely to over-promise**, because E7 removes the background executor a reader expects. The standing notice in § 3 exists because of that, not in spite of it.

---

## 1. Role of the screen

| | |
|---|---|
| **App archetype** | `mobile_consumer` |
| **Module** | more — **rank 5** of 5 in the navigation, and **in overflow**, not a tab |
| **Route** | `/more/downloads` |
| **Type** | page, pushed inside the More tab |
| **Users** | the reader, in the five minutes after starting a long download, and the borrowed-device reader who needs to say what happened |
| **User stories served** | US-07, US-08, US-06 |
| **Business rules** | B5 B18 B19 B20 B21 B22 B23 B24 B28 B32 B33 B38 C4 C8 C11 |
| **Edge cases** | E6 E7 E15 E18 E20 |

**In one sentence**: this screen lets the reader watch one serial queue move, stop it, resume it, see what failed, and free a chapter's space — while being told, permanently, that it only moves while the app is open.

### 1.1 Why this screen is in overflow and not a tab — the reason, argued

`design-system.md` § 3.2 puts Downloads in overflow because **a download is a *state of a novel the reader already has*, not a place to go.** Three consequences, and they shape every section below:

1. **Progress is surfaced in three better places, and this screen is not one of them.** The library row shows a `StatusChip` (`downloading` with a determinate bar), the novel's own page shows the queue it belongs to, and `AppScaffold`'s `persistentStatus` slot puts the running queue in front of the reader **on every screen**. This screen exists for the two things those three cannot do: **the queue's controls** (pause, resume, cancel) and **the failed-items list**.
2. **It is not a destination the reader browses toward.** Nothing leads here. `persistentStatus` leads here when tapped, and that is the only entry — which is also why it is rank 5 and never could be a fifth tab: a tab is a place, and this is a state.
3. **Making it a tab would put "a novel you are already reading" in the same list as "the things you are looking for"**, and the navigation order is a statement about what matters (ADR-018). Downloads would then compete for a slot with Updates, which is the app's only pull-loop.

---

## 2. Visual direction for this screen

| | |
|---|---|
| **Mood** | quiet, warm, unhurried |
| **Density** **dense** | this is a status surface, glanced at rather than read. Three sections of rows, 56dp each, with the counts on one line and the chapter on the next. The one exception is the running row, which is **72dp** because it carries a determinate bar and a byte figure and the reader comes here to look at precisely that row. |
| **Contrast level** **high** | status words carry the meaning, so they are never the faintest thing on the row. `--color-text-primary` measures 14.48:1 by day; the failure wording in `--color-error` measures 6.64:1 and never appears without an icon beside it. |
| **Surface** | rows on `--color-surface` `#FBF9F6` / `#1A1C1F` over `--color-background` `#F5F2ED` / `#121315`. **Flat, `--color-border` rule between rows, no card, no shadow.** The one exception is the sheet a long-press opens, which floats and takes `--shadow-sheet`. |
| **Accent used** | `--color-accent` `#8A4B12` / `#E3A857` — **only** on the determinate progress line of the chapter being fetched, and on the `primary` **Resume** button. Not on section labels, not on completed rows, not on the counts. A row that is finished is not accented: an accent stripe on 40 completed rows would be a progress bar for a queue that is not running. |
| **Photographic treatment** | **none.** No cover thumbnails in the queue or completed lists. The novel's title is in `--text-h3` at 600 and that is what identifies it — a 32dp cover per row is decoration on a list of five, and a broken cover on a status surface is a second thing to wonder about. |
| **Reference** | Apple Books' download list and Kindle's *Manage Your Content and Devices* — flat rows, honest counts, and a progress line that is a line rather than a ring with a percentage inside it. |

### 2.1 Anti-generic — mandatory

This screen must not resemble any of these defects:

- [x] **No pure white `#FFFFFF` background** — `--color-background` is `#F5F2ED` / `#121315`, with rows on the `--color-surface` step.
- [x] **No shadowed card for every row.** Flat rows and a `--color-border` rule. The sheet is the only floating thing, and it is the only place `--shadow-sheet` appears on this screen.
- [x] **Not uniform.** The running row is 72dp and carries a 2dp determinate line; every other row is 56dp with no line. The section labels are `--text-overline` `#11/16` in 600 with `0.08em`; the novel title is `--text-h3` `#20/26` at 600; the counts and the bytes are `--text-caption` `#12/16`. Hierarchy is a ratio of scales, and the one row that matters most is visibly taller than its neighbours rather than carrying an extra badge.
- [x] **No generic grey `#6B7280`** — the separator is `#D9D3C9` / `#2E3237`, secondary text `#5A524A` / `#A8A29A`, disabled text `#6E665C` / `#948E87`.
- [x] **No symmetric centring as the layout.** Sections are left-aligned, counts are right-aligned on the row's trailing edge, and the progress line spans the row's full inner width. The empty state is centred because an empty state is a sentence to a person, not a layout to a grid.
- [x] **No generic spot illustration** — none. The two empty states are a sentence and one button. The failure row is an icon **and** a sentence **and** a retry.
- [x] **Not one typeface at one weight** — 600 uppercase letter-spaced labels, 600 titles, 400 captions. The distinction between "what is happening" and "how much of it there is" is a weight and a scale change, not a colour change.

**Assumed, non-neutral choice**: **a permanent `--text-caption` line sits directly under this screen's title, in every single state, saying that downloads continue only while the app is open — and the queue's status wording for a stopped queue says in the same sentence that it will not restart by itself.** Every competing reader ships a background download service, so the default expectation this screen fights is that closing the app just means the bar moves somewhere you cannot see. The cheapest way to ship v1 would have been a notification saying *Downloading…* and a queue that stopped silently when the process died — which is precisely the over-promise `flows.md` § 4.4 names as "the single most likely over-promise in the product". So the limitation is not a footnote in settings and not a modal the reader saw once: **it is the first line under the title, it is always there, and it is repeated inside the stopped state** where the reader is most likely to wonder. The second half of the choice is that **progress is never a single aggregate bar over the novel.** B18 makes the queue serial — one chapter at a time, in reading order — so an aggregate bar would be a claim about parallelism the app does not have. The counts are in the header (*12 of 50 downloaded · 1 in progress*) and the bar belongs to **the chapter being fetched**, with its own title and its own byte figure.

---

## 3. Anatomy

```
AppScaffold (titleBar + content + bottomNav)
├── TitleBar                    "Downloads" --text-h1; back to /more
├── InProcessNotice             --text-caption, --color-text-secondary
│                              "Downloads continue only while the app is open."   ALWAYS
├── QueueSection                rendered only when a queue exists
│   ├── SectionLabel            --text-overline "DOWNLOAD QUEUE"
│   ├── QueueHeader             novel title --text-h3 + counts --text-caption
│   │                          "12 of 50 downloaded · 1 in progress"
│   ├── QueueRow (running)      72dp · 2dp determinate --color-accent line
│   │                          current chapter title --text-body-sm + bytes --text-caption
│   ├── QueueRow (paused)       --color-warning icon + "Paused" + Resume
│   ├── QueueRow (stopped)      --color-error icon + the reason + Resume
│   └── QueueActions            Pause · Cancel        (Cancel is a confirm dialog)
├── CompletedSection            --text-overline "DOWNLOADED ON THIS PHONE"
│   └── CompletedRow            novel title + "48 chapters · 12.4 MB" + Delete downloads
├── FailedSection               --text-overline "COULD NOT DOWNLOAD" — only when non-empty
│   └── FailedRow               chapter title + --color-error icon + wording + Retry
└── SnackBarHost                --color-surface-raised, --shadow-sheet
```

| # | Component | Role | Source |
|---|---|---|---|
| 1 | `ChapterListTile` variant `list` | One chapter inside the sheet a long-press opens, and the shape the running row borrows | `design-system.md` § 2.2 |
| 2 | `StatusChip` | `downloading` on the library row, `failed` here — **not** on this screen's own rows, which say their status in words | `design-system.md` § 2.5 |
| 3 | `PrimaryButton` / `TextButton` | **Resume**, **Check again**, **Retry**; `TextButton` for Pause and Cancel | `design-system.md` § 2.3 |
| 4 | `EmptyState` | Both empty variants | `design-system.md` § 2.7 |
| 5 | `ErrorState` | The records could not be read | `design-system.md` § 2.7 |
| 6 | `LoadingState` | Never used whole-screen here — see § 4 | `design-system.md` § 2.7 |
| 7 | `AppScaffold` | Title bar, content, bottom nav, `persistentStatus` | `design-system.md` § 2.8 |

**Where progress is shown, so it is shown once.** `design-system.md` § 3.2 lists three surfaces for progress — the library row, the novel's page, and the persistent status bar — and this screen is where the reader *goes*, not a fourth place a bar is duplicated into. The `persistentStatus` bar carries the same determinate line while it is visible; this screen is what it opens.

---

## 4. States — all nine, no exceptions

| State | Trigger | Rendering | Reader feedback |
|---|---|---|---|
| **Loading** | **Never a whole-screen loader, and that is a decision.** The queue is local records, so the rows render on the first frame. The **only** slow thing is the storage total: it is a walk of the downloads directory, and on a novel of several hundred chapters it is real I/O | The queue and completed rows render immediately with their exact counts. The one byte figure that is not yet known shows `--text-caption` *calculating…* **in place**, and replaces itself when the walk finishes. `LoadingState` is therefore used **only for the footer skeleton** of an in-flight page fetch, and a centred spinner appears nowhere on this screen | A row never blinks out to wait for a number. The count is exact and immediate; the size is admitted to be arriving |
| **Filled** | A queue is running, paused, stopped or interrupted | § 3. The counts line reads *12 of 50 downloaded · 1 in progress* — **both numbers exact, neither an estimate** (C8). The running row shows the chapter title it is fetching and its byte progress. Below the queue, **Completed** lists what is on this phone, and **Failed** appears only when something failed. Every failed row names the **chapter**, not just the novel | — |
| **Empty — never visited** | Nothing has ever been downloaded | `EmptyState`: `--text-h3` *Nothing is downloaded yet*, `--text-body-sm` body — *Downloaded chapters read with no signal at all. Start one from any novel's page.* — and one `primary` **Browse sources** → `/browse`. **The body states the benefit in the reader's terms, because that is the one thing a download queue is for** | The primary action starts the discover loop rather than explaining the queue |
| **Empty — no data** | **Every downloaded chapter has been deleted** — the reader has been here before and this is what it looks like afterwards | The same `EmptyState` layout with **different copy**: *Everything you downloaded has been deleted*, body — *Your library and your reading positions are unchanged.* — and `primary` **Browse sources**. The two empty states are told apart by **what happened**, not by decoration: one says nothing ever happened, the other says something did and the reader chose it. There is no icon, no illustration and no congratulation in either | — |
| **Load error** | The local records cannot be read — a real failure with a consequence worth stating precisely | `ErrorState`: *Lumen Tale could not read its download records*, `secondary` **Try again**, and a body that says **the files are still on the phone** — *Nothing has been deleted. This app cannot see what it has already stored, and nothing can be fetched until it can.* **If a download was running, the screen says so and does not pretend the queue is empty** — *A download was in progress and has stopped.* An empty queue here would be a claim about a queue the app cannot currently see | The copy is written to stop the reader from doing something irreversible while the app is confused |
| **Submit error** | Four submissions, four honest failures | **(a) Cancel fails** — the most important one on this screen: the queue **keeps running**, the switch springs back, and a snackbar says *Could not cancel. The download is still running.* Showing a cancelled queue that is not cancelled would leave chapters being written the reader believes are safe (B19). **(b) Pause / Resume write fails** — the row's status word does not change, snackbar names the failure. **(c) Delete a chapter's record fails** — the chapter **stays** `downloaded`, snackbar *Could not delete that chapter. Nothing was changed.* **(d) Clear the failed list fails** — the list stays. In every case the screen's state is the state it was in before the tap, plus one sentence | Each failure names what is still true. None of them leaves a control showing a state the app does not hold |
| **Success** | Two successes, and only one of them announces itself | **A chapter finishing says nothing.** Fifty chapters must not produce fifty snackbars; the count in the header simply increments and the bar leaves the row. **The queue completing** produces one snackbar — *The Healer Has Returned is downloaded — 50 chapters.* — with **Open** → the novel's page. **A cancelled queue** produces *Download cancelled — 12 chapters kept*, because the reader needs to know what survived (B19). **Deleting one chapter's download produces a confirmation snackbar with no Undo**, and that asymmetry is deliberate — see § 4 below | — |
| **Offline / permissions** | **The connection drops mid-queue — E7, and the state this screen exists to get right** | The queue **stops**, says why, and **keeps every chapter already completed**. The running row becomes `--color-error` icon **+ words**: *Stopped — no connection. 12 of 50 chapters are downloaded.* and, beneath it, **the sentence that closes the trap: *It will not continue on its own when the signal comes back.*** One `primary` **Resume**. **Nothing resumes automatically** — E7 is explicit, and auto-resume is the promise this app must not make. The standing `InProcessNotice` is still above it, so the reader has been told before the moment it mattered. **No permission prompt exists anywhere on this screen** — there is no background service to notify about, so there is nothing to request; B37's notification belongs to the scheduled update check, a different flow | The stopped state is **not** an error banner over a still-moving list. The list stops. That is the whole behaviour, and the UI states it rather than animating around it |
| **Read-only** | **The chapter being fetched is mid-write** | The running row's controls are **absent, not disabled**. A chapter is stored atomically — wholly present or wholly absent (B20, C8) — so there is no meaningful state to cancel *the write*: cancelling the **queue** is meaningful and remains available one level up, and it discards the partial file rather than completing from it. **No per-chapter cancel, no pause mid-file, no "keep the half"**, because none of those is a state the storage format can represent honestly | — |

> Every one of the nine has a rendering or an argued reason for having none. The only outright absence is `LoadingState` as a whole-screen state, and it is stated: the data is local and the rows are immediate; only a page fetch uses a skeleton.

**Why a deleted chapter has no Undo, while removing a novel from the library does.** B32 makes removing a novel reversible in the only sense that matters — nothing is destroyed, so the novel can simply be added again. Deleting a chapter's download **is** the destruction: there is no backup and no export (B31, C8), so an Undo would have to promise to refetch content that may have changed, or vanish. The screen therefore **confirms first**, in a `--shadow-dialog` `AlertDialog` whose body names the chapter and says the other chapters are untouched (**B33**) and that the space is only reclaimed if the site still has it later. It does not confirm deletion of a whole novel's downloads as a single sweep — the sheet's header action asks for an explicit per-novel confirmation instead, because that sweep is the one action on this screen with no partial undo.

---

## 5. Interactions

| Element | Event | Behaviour | Visual feedback | Resulting state | Rule |
|---|---|---|---|---|---|
| `persistentStatus` bar | tap | Navigate here | Standard push `--duration-normal` 200ms | Filled | — |
| `Resume` | tap | Continue **from the chapter it stopped at** — never from chapter one | Button → spinner, label hidden, width locked; the bar returns | Running | **B21**, **B20** |
| `Pause` | tap | Stop before the next chapter. The chapter in flight finishes; **no further chapter is fetched after it** | Status word becomes *Paused*, `--color-warning` icon; `Pause` becomes `Resume` | Paused | **B19** |
| `Cancel` | tap | Confirm dialog (`--shadow-dialog`), then stop immediately. **Every unfinished chapter returns to not-downloaded** and its partial file is discarded | Dialog, then the whole QueueSection is removed and a snackbar reports what was kept | Filled | **B19** |
| `Cancel` — write fails | tap | No state change | Snackbar *Could not cancel. The download is still running.* | Submit error | **B19**, **B24** |
| `QueueRow` | tap | Open the novel's page, where the queue's chapters are listed | Row `pressed`: `--color-surface-sunken` | Filled → next screen | **B18** |
| `FailedRow` | tap | Open the novel's page **at that chapter** | Row `pressed` | Filled → next screen | **B18** |
| `Retry` on a failed row | tap | Re-fetch that chapter alone, and only that one. It re-enters the queue and runs in reading order among the others | Row becomes a running row with a determinate line | Running | **B5**, **B18** |
| `Retry` on a failed row — fails again | tap | — | Row returns to `failed` with the wording unchanged and the attempt count bumped | Filled, failed row | **B24**, **E18** |
| `CompletedRow` | tap | Open the novel's page | Row `pressed` | Filled → next screen | **B32** |
| `CompletedRow` | long-press | Open a `--shadow-sheet` bottom sheet listing **that novel's stored chapters**, in reading order, each a `ChapterListTile` `list` with a 48dp trailing delete — **this is B33's surface** | Sheet slides up `--duration-normal` 200ms | Filled + sheet | **B33** |
| Delete one chapter (in the sheet) | tap | `AlertDialog` naming the chapter, saying the other chapters are untouched, then delete the file and the record | Dialog; the tile leaves the sheet | Filled, storage recalculated | **B33**, **C4** |
| `Delete downloads` for the whole novel | tap | A second, explicitly worded confirmation, then remove every stored chapter of that novel. **It does not remove the novel from the library** | Dialog; the row leaves Completed | Filled | **B33**, **B32** |
| `Delete downloads` — write fails | tap | Nothing is deleted | Snackbar *Could not delete that chapter. Nothing was changed.* | Submit error | **B24**, **C8** |
| Queue or completed list | scroll | Both lists scroll under one screen. A queue has **no pagination**: its length is known from its records | — | — | **B18** |
| Long-press on a queue row | gesture | **Nothing.** No drag, no reorder — **B18 fixes the order as reading order**, and a reorder affordance would be a promise the queue does not keep | — | — | **B18** |
| Title bar | tap | **No action.** No sort, no bulk-select, no "clear all" | — | — | — |
| System back | gesture | Return to `/more` | Standard pop | Previous screen | — |

- **Focus / keyboard**: D-pad moves row by row; `Enter` activates the row's primary action and `long-press`'s sheet on a completed row; `Esc` closes the sheet, then a dialog, in that order. Focus is a 2dp `--color-border-focus` `#8A4B12` / `#E3A857` ring at a 2dp offset and is drawn on the **trailing action**, so a keyboard user can skip past rows without opening thirty novels.
- **Gestures**: vertical scroll, system back, and long-press on a completed row. **No swipe-to-cancel, no swipe-to-delete** — a destructive action that fires on a horizontal swipe inside a scrolling list is a chapter deleted by accident, and with no backup the mistake is unrecoverable (C8). **No pull-to-refresh**: there is nothing to refresh, because a queue is local state and the only network this screen causes is one the reader started.
- **Animations**: the determinate progress line moves at the cadence the download reports; row presses `--duration-fast` 120ms; sheet and dialog `--duration-normal` 200ms `--ease-standard`; the progress line **does not** animate on its own and there is no indeterminate shimmer on this screen — a bar that moves when nothing is being fetched is a lie. All durations become `0ms` under reduce-motion, and the progress line keeps updating because data is not decoration.
- **Back**: system back returns to `/more`. **Nothing is saved on the way out** — the queue's state is already in its records, and a back press must not be a write on the hot path.

---

## 6. Responsive

| Breakpoint | Behaviour | What collapses or disappears |
|---|---|---|
| **Mobile** `< 600dp` | Single column, `--space-lg` 16dp margins, rows full-bleed with `--space-md` 12dp internal padding. Queue actions are a trailing `Pause` / `Cancel` pair, each 48dp | Nothing. This is the design target and the only width v1 ships (C3) |
| **Tablet** `600–1023dp` | Identical single column, **centred and capped at the mobile measure**. **Explicitly not a tablet layout** — ADR-010 excluded it and `design-system.md` § 1.7 says `< 600dp` is *the only layout v1 ships* | Nothing collapses. The sections stop growing and centre |
| **Desktop** `1024–1439dp` | Same. Flutter desktop is out of scope (C3) | — |

- **Touch target**: 48dp minimum on every row, every trailing action, every section-level button and the snackbar's **Open** and **Undo**. A disabled action — and there is exactly one class of them, a `Pause` on a queue that is not running — stays **48dp tall** so the row does not jump under the reader's finger.
- **Overflow**: guaranteed never to overflow. The queue header's counts line truncates from the left so the **novel title** always survives, because a header reading `…of 50 downloaded · 1 in progress` still tells the reader what is happening. A novel title at `--text-h3` truncates to one line and its **full title is the row's accessible label**. No row scrolls horizontally, the determinate line is width-constrained rather than fixed, and the sheet's chapter list is virtualised so a novel of several thousand chapters opens without building ten thousand tiles.
- **Text scale**: at the largest OS text scale the 56dp rows grow and the counts line wraps under the title. The running row's 2dp progress line **stays 2dp** — it is a measurement, and scaling it with the reader's font would make the queue look stuck.

---

## 7. Accessibility

- [x] **Contrast 14.48:1** (day) / **12.00:1** (night) for novel and chapter titles — measured, not asserted.
- [x] **Contrast 6.22:1** / **6.01:1** for `--color-text-secondary`, which carries every count, every byte figure and the standing notice.
- [x] **Contrast 4.80:1** / **7.36:1** for `--color-warning` on *Paused*, and **6.64:1** / **6.22:1** for `--color-error` on *Stopped* and every failed row.
- [x] **The progress line is a non-text component**: `--color-accent` `#8A4B12` / `#E3A857` at **5.50:1** / **7.25:1** against the page, measured as a component at the 3:1 of WCAG 1.4.11, with the track in `--color-surface-sunken`.
- [x] **Focus visible** at 2dp with a 2dp offset, never removed, and placed on the trailing action so it does not force the reader through every row.
- [x] **Keyboard navigation complete** across rows and their actions; `Esc` unwinds sheet then dialog; the sheet traps focus while it is open, which matters because it is the surface where a chapter is deleted.
- [x] **No state is carried by colour alone.** *Paused* is `--color-warning` **plus an icon plus a word**; *Stopped* is `--color-error` plus an icon plus a word plus the sentence about not resuming by itself; a failed chapter is an icon, a chapter title and a reason. Everything survives greyscale and a screen reader.
- [x] **The progress line has a spoken equivalent**: the determinate bar is exposed as a value with a real accessibility label — *Chapter 13 of 50, 41 per cent* — updated as the fetch progresses. A percentage inside a ring is unreadable by a screen reader and useless at 2dp; this is the alternative.
- [x] **Destructive actions are confirmed and named**: the dialog names the chapter, so the confirmation is a statement about a specific thing rather than a generic *Are you sure?*. **A borrowed-device reader (C13) can describe any state of this screen in words**, which is C12's requirement applied to the screen where the worst thing that can happen is unrecoverable.
- [x] **Language and reading direction correct**: the app's locale follows the phone (B28), including every status word and every error sentence. Novel and chapter titles are shown in the **site's** words because they are the site's content (B10); only the app's own words are localised. `dir` follows the language, and the sheet's chapter list follows it too.
- [x] **Reduce-motion honoured**: presses are instant; the progress line keeps updating, because it is data.

---

## 8. Data

| Field | Type | Origin | Required | Possible error |
|---|---|---|---|---|
| `queue.novelId` | `String` | local | yes | Never absent — a queue without a novel is dropped and logged locally, never rendered as an orphan row |
| `queue.chapterIds` | `List<String>` | local, **in reading order** | yes | Empty → the queue section is not rendered; the reader is told nothing, because there is nothing running |
| `queue.status` | `enum(running, paused, stopped, interrupted)` | local | yes | `interrupted` is the state after the process died and is **always** reset to `paused` on open, never to `running` (E7, E15) |
| `queue.doneCount` | `int` | local | yes | Counted from stored chapters, **never an estimate** (C8, and B14's logic applied to a queue) |
| `queue.totalCount` | `int` | local | yes | Absent → the header drops the *of N* and shows the count alone. `0` is never substituted for unknown |
| `queue.stopReason` | `enum(no_connection, out_of_storage, cancelled)` | local | no | Absent → the generic stopped sentence, which says nothing is downloading and does not guess why |
| `activeChapter.title` | `String` | the site, verbatim | yes | Displayed exactly as the site presents it (B10) |
| `activeChapter.progress` | `double` 0..1 | the fetch | yes | Reported monotonically; a reported value that moves backwards re-renders from the record rather than animating backwards |
| `activeChapter.bytes` | `int` | the fetch | no | Absent → the byte figure is omitted rather than showing `0`, which is a claim |
| `completed.novels` | `List<Novel>` | local records | yes | Read-only from this screen's perspective |
| `completed.chapterCount` | `int` | local | yes | Exact. A novel partially downloaded shows `12 of 48 chapters` and **says so in the row**, never `48` |
| `completed.bytes` | `int` | filesystem walk | no | Pending → *calculating…*, replaced in place |
| `failed.chapters` | `List<Chapter>` | local | no | Empty → the **Failed** section is not rendered at all |
| `failed.reason` | `enum(no_connection, source_unreadable, out_of_storage, no_real_text)` | local | no | `no_real_text` is E18's threshold and is reported as a **failure with a retry**, never stored as a complete chapter |
| `novel.inLibrary` | `bool` | local | no | **Never gates this screen.** A novel removed from the library keeps its downloads (B32) and therefore keeps its row here — this list is keyed on **stored chapters**, not on library membership |

- **Loading**: **nothing is paged.** A queue is a fixed list from the records and a completed list is a local read. The only network this screen causes is one the reader started: fetching the chapters a queue is fetching, one at a time (B18).
- **Cache / offline**: **the entire screen works from local records with the radio off** — it is a view over what is already on the phone, which is why it is the screen that keeps working when nothing else does. The one thing it cannot do offline is **resume**, and it says so: `Resume` is present and attempting it while offline produces the stopped state with *No connection*, not a silent no-op.
- **Sensitive data**: **no chapter text is read, rendered or logged here, and no file content is ever loaded to compute a size** — the size is a filesystem attribute. There is no telemetry, so a failure report names the **novel and the chapter**, never the content. A queue's existence is the reader's reading habits expressed as state, and B29 means none of it leaves the device.

---

## 9. Traceability

| ID | Origin | Manifestation on this screen |
|---|---|---|
| **B5** | PRD | The only requests this screen causes are ones the reader started: resume, retry, and the chapters of the queue itself. Opening it fetches nothing, and it pulls to refresh nothing |
| **B18** | PRD | The counts line shows **both** numbers exactly; the bar belongs to the chapter being fetched; `Retry` re-enters the queue in reading order; long-press cannot reorder it. **No aggregate bar exists**, because the queue is serial and a single bar would imply a parallelism the app does not have |
| **B19** | PRD | `Pause` stops before the next chapter and nothing is fetched after it. `Cancel` takes effect immediately, discards the in-flight partial, and reports what was kept. A failed cancel shows a **still-running** queue, never a cancelled-looking one |
| **B20** | PRD | The interrupted chapter is not stored as complete: its row's controls are absent while the write is in progress, and an interrupted chapter is fetched again **from the start** rather than completed from a partial state |
| **B21** | PRD | On reopen the queue renders as **paused with its position intact** — *12 of 50 downloaded* — and never restarts at chapter one. What survives the process is the **definition** of the queue; what does not survive is its **execution**, and the notice says so |
| **B22** | PRD | **Every download from one source failing is reported as one source failure, not as forty-eight failed chapters.** A single row reading *Lumen Tale could not read FanMTL* replaces forty-eight rows of the same error — which is the difference between a source being broken and a queue being unlucky, and the reader can act on the first and not the second |
| **B23** | PRD | The Load error states that nothing has been deleted and that the library is unaffected. Losing contact, or losing the ability to read a site, never costs the reader a stored chapter |
| **B24** | PRD | Every failure offers an action: **Try again** for unreadable records, **Resume** for a stopped queue, **Retry** for a failed chapter. Nothing here fails to a silent no-op |
| **B28** | PRD | Every status word — *Paused*, *Stopped*, *calculating…*, *it will not continue on its own* — exists in French and English, because a status the reader cannot read is a status they cannot act on |
| **B32** | PRD | Removing a novel from the library **keeps its downloads**, and its row stays on this screen. The row is keyed on stored chapters, never on library membership, and the whole-novel delete confirmation says explicitly that it does not remove the novel from the library |
| **B33** | PRD | **Long-press a completed novel → a sheet of its stored chapters → delete one.** The dialog names the chapter and says the other chapters are untouched. There is no undo, because there is no backup |
| **B38** | PRD | **This screen has no "check for new chapters" and no download-from-here trigger of any kind.** Checking and downloading are separate actions that never overlap, and the absence of a check button here is the implementation |
| **C4** | PRD | A chapter's stored copy leaves the phone only when the reader explicitly deletes it, and only that chapter's |
| **C8** | PRD | The screen is built so it **cannot represent a partial state as complete**: counts are exact and local, the bar belongs to one chapter, a partially downloaded novel says `12 of 48 chapters`, and a chapter with no real text is a failure rather than a stored chapter (E18) |
| **C11** | PRD | Every control is 48dp and reachable one-handed, rows are 56dp so a whole queue fits a screen, and no destructive action is bound to a swipe |
| **E6** | PRD | An interrupted chapter is not marked as downloaded and never opens with partial text. It re-enters as `failed` with a retry, not as a chapter in the Completed section |
| **E7** | PRD | **The state this screen exists to get right.** Connection lost mid-queue → the queue stops, says why, keeps what it completed, and **does not resume on its own**. The permanent `InProcessNotice` is the standing half of that promise |
| **E15** | PRD | The app closed or the phone rebooted mid-queue → on reopen the queue is **paused at the chapter it reached**, never restarted, and the notice explains why it was not running |
| **E18** | PRD | A chapter page that cleans to no real text is reported as a **failed chapter with a retry**, and is never stored as complete. The attempt count is shown, because a threshold being applied is a thing the reader deserves to know about |
| **E20** | PRD | Storage exhausted → the queue stops with the reason *the phone is out of storage*, keeps every completed chapter, records nothing partial as complete, and the resume action says *free up space on the phone, then resume*. **Free space is not displayed** — the app has no honest way to read it without a platform channel it has not earned |

---

## 10. Gate checklist

- [x] All nine states described, with a concrete rendering or an argued reason for having none. Only `LoadingState` as a whole-screen state is absent, and it is explained: the data is local and the rows are immediate.
- [x] Every interactive element has a behaviour, a feedback, a resulting state and a rule ID.
- [x] Responsive defined at **every** breakpoint in the design system — and the two larger ones say "identical, stop widening", which is ADR-010, not an omission.
- [x] Anti-generic section checked **and justified**; the assumed choice is stated (a permanent in-process notice, no auto-resume, and no aggregate bar).
- [x] No design value left "to be defined". Every colour, size, duration and easing cited exists in `design-system.md` with a value.
- [x] Every B/E/C ID on this screen appears in § 9.
- [x] `forge-guard placeholders` reports nothing here.
- [x] Consistent with `design-system.md`: `ChapterListTile` is rendered only in its `list` variant, the determinate line matches its `downloading` state's 2dp `--color-accent`, and `--shadow-sheet` and `--shadow-dialog` are used only on the two things that genuinely float.
- [x] **Every token cited by this screen exists in the design system, with the value it is given here.** The full citation table is § 12.

---

## 11. Claims this screen refuses to make

**Absent, not disabled** — a disabled control is a promise about a version that does not exist:

| Absent | Why |
|---|---|
| Any "downloads continue in the background" wording, notification, or progress-while-closed | **E7.** There is no background executor in v1. `benchmarks.md` § 3 records background download as **absent**, against both benchmarks |
| Auto-resume when the connection returns | E7 says the reader resumes. Auto-resume is the promise that turns an interrupted queue into a silent data cost |
| A single aggregate progress bar | B18 — the queue is serial. A bar over the whole novel would claim parallelism the app does not have |
| Concurrent downloads, a speed figure, an ETA | Not in any rule, and not measurable from a serial in-process queue (`roadmap.md` § 7.1's honest "not yet measurable") |
| Download scheduling — "download novel X overnight" | Same reason as the above, stated once more: there is nothing running at 3am |
| Free storage space display | It would need a platform channel the app has not earned (`09-widgets-ui.md`), and a stale number is worse than none. The screen says *the phone is out of storage* and tells the reader to free space |
| Undo on a deleted chapter | C8 — no backup, no export. An Undo would be a promise to refetch content that may have changed or vanished |
| "Check for new chapters" or "download new chapters" | **B38.** Checking never downloads and downloading never checks; the two actions are separate and never overlap |
| Per-chapter cancel, pause-mid-file, or resume-mid-file | B20 and C8 — a chapter is wholly stored or wholly absent. There is no honest partial state to expose |
| Bulk select, drag to reorder, swipe to delete | B18 fixes the order as reading order, and C8 makes a swipe-deleted chapter unrecoverable |
| Share, export, or send a downloaded novel anywhere | B30. The correct UI for this rule is the share sheet that never appears |
| A progress ring with a percentage inside it | Unreadable by a screen reader and useless at 2dp. The determinate line plus a spoken value is the accessible form |

---

## 12. Tokens this screen cites

Every value below is the one the design system declares, so `design-check tokens-used` can re-derive it. Non-colour tokens are listed for completeness; only the colour rows are contrast-measured.

| Token | Day | Night | Measured (day / night) | Where it appears here |
|---|---|---|---|---|
| `--color-background` | `#F5F2ED` | `#121315` | — | The page field behind all three sections |
| `--color-surface` | `#FBF9F6` | `#1A1C1F` | — | Every queue, completed and failed row |
| `--color-surface-sunken` | `#EBE7E0` | `#0C0D0F` | — | Row `pressed`; the **track** of the determinate progress line |
| `--color-surface-raised` | `#FEFCF9` | `#232629` | — | The chapter sheet and the snackbar — the two things that float |
| `--color-text-primary` | `#1A1714` | `#E8E4DD` | **14.48:1** / **12.00:1** | Novel titles, the active chapter title, the Load error's title |
| `--color-text-secondary` | `#5A524A` | `#A8A29A` | **6.22:1** / **6.01:1** | Every count, every byte figure, the standing `InProcessNotice` |
| `--color-text-disabled` | `#6E665C` | `#948E87` | **4.58:1** / **4.69:1** | A `Pause` on a queue that is not running, and a `Retry` already in flight |
| `--color-text-inverse` | `#FDFAF6` | `#17181A` | **5.54:1** / **7.27:1** | The `Resume` and **Open** labels; the confirm dialog's filled action |
| `--color-accent` | `#8A4B12` | `#E3A857` | **5.50:1** / **7.25:1** | The determinate progress line, and **nothing else** — never a completed row |
| `--color-success` | `#40713A` | `#7FBE72` | **4.68:1** / **6.89:1** | The Downloaded section's icon beside a fully-downloaded novel's row |
| `--color-warning` | `#8A5A12` | `#E0AC47` | **4.80:1** / **7.36:1** | *Paused* — icon plus wording |
| `--color-error` | `#8A3228` | `#EE8B76` | **6.64:1** / **6.22:1** | *Stopped*, every failed row, the storage and source-failure wording |
| `--color-info` | `#426986` | `#7FB3DA` | **4.74:1** / **6.78:1** | The single-source-failure row's icon — a notice about the site, not an error in the queue |
| `--color-border` | `#D9D3C9` | `#2E3237` | exempt | The rule between rows, and above each section |
| `--color-border-focus` | `#8A4B12` | `#E3A857` | **6.07:1** / **8.86:1** | 2dp focus ring on trailing actions, buttons, dialogs and sheet tiles |

Non-colour tokens cited: `--text-h1` `#31/38`; `--text-h3` `#20/26`; `--text-body` `#16/24`; `--text-body-sm` `#14/20`; `--text-caption` `#12/16`; `--text-overline` `#11/16`; `--space-md` `12dp`; `--space-lg` `16dp`; `--space-xl` `24dp`; `--radius-sm` `4dp`; `--radius-md` `8dp`; `--radius-lg` `16dp`; `--border-width` `1dp`; `--border-width-strong` `2dp`; `--duration-fast` `120ms`; `--duration-normal` `200ms`; `--ease-standard` `cubic-bezier(0.2, 0, 0, 1)`; `--shadow-sheet` `0 8 24 rgba(0,0,0,0.18)`; `--shadow-dialog` `0 16 48 rgba(0,0,0,0.24)`.