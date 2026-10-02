---
type: prd
status: draft
generated_at: 2026-10-02
version: 2
---

# Product Requirements Document — Lumen Tale

> This document describes WHAT the product does, FOR WHOM, and WHY.
> It does NOT describe how it will be implemented (technology, architecture, visual design).
>
> Every business rule, edge case and constraint carries a stable identifier (B*, E*, C*)
> that serves as the backbone for traceability across the whole project.

---

## 1. Executive summary

### 1.1 Problem

Web novels — the long, serialised stories published on sites like FanMTL and Royal Road — are read today inside a phone browser. Those pages are ad-heavy, split across awkward pagination, and the browser forgets where you were as soon as you close the tab. Reading a 400-chapter novel online therefore costs a lot of mobile data and requires a connection the entire time, even though the story never actually changes. The novel exists only as those web pages; there is no copy anywhere else.

### 1.2 Solution

Lumen Tale fetches a chapter from its site, turns the page into clean readable text, keeps it on the phone, and reads it in a purpose-built reader. Once a novel is downloaded, it needs no internet again — for as long as the app stays installed on that phone.
**One-line promise:** *Read a web novel once, and it stays readable without a signal, with no signal.*

### 1.3 Target users

A personal-use app. There is exactly one real user: the project owner, a French-speaking heavy web-novel reader who reads in long sessions on a phone, across several sites, in both French and English, frequently with poor or no connectivity. A small circle of friends and family to whom the owner may lend the app file have identical needs and no special rights.

There are deliberately **no other personas**: no administrator, no support team, no paying customer, no content moderator, no account holder — because there is no public distribution, no server and no account.

### 1.4 Differentiation

Commercial web-novel apps (Dreame, Webnovel, NovelBin and similar) have polished readers, cloud sync of the reader's library, social features and large content catalogues. They structurally cannot offer what Lumen Tale offers: the reader reads from **their own list of sites**, nothing is uploaded to anyone's server, there is **no account at all**, and their reading data never leaves their phone — and is, by deliberate design, not exportable either.

---

## 2. Users and personas

| Persona | Role | Context | Technical level | Main need | Usage frequency |
|---|---|---|---|---|---|
| **Anaïs — the owner** | Primary reader, sole maintainer of the app | One-handed, on a phone; commutes and evenings, often at night or in transit; frequently poor or no connectivity | Comfortable installing an app from a file; **cannot write code** | Read novels offline, at their own font size, in dark mode, and never lose their place | Daily, in long sessions |
| **Borrowed-device reader** (friend or family member) | Occasional reader on a phone, using a copy of the same file | Same as above, outside transit | Same as above: installs from a file, no coding, no account, no special rights | Read the same novels offline with the same comfort | A few times a week |
| **No such persona** | Administrator | — | — | There is no server, no administration, no user management | — |
| **No such persona** | Support agent | — | — | There is no support function; the app reports its own failures on the device | — |
| **No such persona** | Content moderator | — | — | No content is published by anyone; content is read privately from third-party sites | — |
| **No such persona** | Paying customer | — | — | The app is not sold, not published, and has no purchase path | — |

---

## 3. User stories

<!-- Priority: P1 (must have), P2 (should have), P3 (could have), P4 (not now) -->

### US-01: Browse a site's catalogue

- **As a** reader
- **I want** to open a site and scroll through the novels it lists
- **So that** I can discover something new to read

**Priority**: P1
**Dependencies**: US-16

**Acceptance criteria**:
- [x] The app offers a choice of sites, and each available site opens a catalogue of novels with a title and, where the site provides one, a cover and a short description.
- [x] Tapping a novel in a catalogue opens that novel, and the novel shown is the one that was tapped (never a different novel with a similar title).
- [x] A catalogue that is still loading shows a visible loading state; a catalogue that failed to load shows an error the user can read and a way to try again (B24).
- [x] Every string in the catalogue is shown in the app's current language (B28).

---

### US-02: Search within a site

- **As a** reader
- **I want** to search inside one site by typing a title
- **So that** I can find a specific novel I already know about

**Priority**: P1
**Dependencies**: US-01, US-16

**Acceptance criteria**:
- [x] Typing text and submitting shows matching novels from the site currently selected, and only from that site (B2, B41).
- [x] A search that matches nothing shows an explicit "no results" message that is visibly different from a failure message (E19).
- [x] A search that fails shows an error with a retry, never an empty list (B22).
- [x] Selecting a site again and running the same search runs it against that site.

---

### US-03: See a novel's details and its full chapter list

- **As a** reader
- **I want** to see a novel's description and its whole list of chapters
- **So that** I can pick up where I left off or jump to a specific chapter

**Priority**: P1
**Dependencies**: US-01, US-16

**Acceptance criteria**:
- [x] The chapter list shows every chapter the site lists, in the site's reading order, with the site's own title for each (B9, B10).
- [x] A novel with 120 chapters and a novel with several thousand chapters both produce a complete, scrollable list without freezing, dropping entries, or truncating the list (E1).
- [x] Chapter titles such as "Chapter 1", "Ch. 12.5", "Vol 3", "Extra", "Omake" and untitled chapters are all displayed as-is and are all selectable (E2).
- [x] When the chapter list cannot be read from the site, the app says so explicitly and does not display an empty list (B22, E4).

---

### US-04: Read a chapter in the app's reader

- **As a** reader
- **I want** to open a chapter and read it as clean text with no ads, menus or site furniture
- **So that** reading is comfortable and focused

**Priority**: P1
**Dependencies**: US-03, US-15

**Acceptance criteria**:
- [x] Opening a chapter displays its title and its body text, with no advertisements, navigation links, comment sections, cookie banners or share widgets (B5).
- [x] A chapter split across several pages on the site appears as one continuous piece of text, with the pages joined in their original order (B8, E3).
- [x] Closing and reopening the chapter shows the same content again from the stored copy or from the site.
- [x] In portrait, a chapter of 10 000 characters scrolls with no horizontal scrollbar and no clipped final paragraph; in landscape the same chapter stays fully readable.

---

### US-05: Read a downloaded chapter with the connection off

- **As a** reader on a train, a plane or a night with no signal
- **I want** to open a novel I downloaded and read it with the network switched off
- **So that** I can read without connectivity and without spending mobile data

**Priority**: P1 *(the "wow" moment — the single most important story in this document)*
**Dependencies**: US-06, US-07, US-04

**Acceptance criteria**:
- [x] With the connection switched off, a downloaded novel opens from the library and every downloaded chapter of it opens and scrolls to the end (B6).
- [x] Nothing on that path — opening the novel, listing its chapters, reading a chapter — requires a network call (C14).
- [x] Not-yet-downloaded chapters of the same novel are visibly marked as such and are not silently skipped or replaced with blank text.
- [x] The reading position of the chapter is preserved across the offline session (B16).

---

### US-06: Download a single chapter for offline reading

- **As a** reader about to lose connectivity
- **I want** to download one chapter to the phone
- **So that** I can read it later without signal

**Priority**: P1
**Dependencies**: US-03, US-16

**Acceptance criteria**:
- [x] The user can start a download of a single chapter from that chapter's place in the novel's chapter list.
- [x] The chapter is marked as downloaded only once it is completely present on the phone; an interrupted download leaves it marked as not downloaded (B6, E6).
- [x] With the connection off, a chapter marked as downloaded opens and displays its full text (B6).
- [x] Deleting the downloaded copy of a chapter frees its space and leaves the other chapters of the novel untouched (B33).

---

### US-07: Download a whole novel as a queue

- **As a** reader who has just discovered a long novel
- **I want** to download the entire novel in one action and let it run
- **So that** the whole story is available offline without me babysitting it

**Priority**: P1
**Dependencies**: US-06

**Acceptance criteria**:
- [x] The user can start a whole-novel download from the novel's page; the app confirms before starting because it will use data and storage (B18).
- [x] Chapters are fetched one at a time in reading order, and the app shows how many are done and how many remain (B18).
- [x] The user can pause and resume the queue, and can cancel it; cancelling leaves every unfinished chapter unmarked (B19).
- [x] Fifty chapters can be downloaded and then read with the network off (§10 criterion SC-2).
- [x] Closing the app in the middle of the queue does not restart the novel from chapter one when the app is opened again (B21, E15).

---

### US-08: Watch and control a running download

- **As a** reader who started a queue
- **I want** to see the download's progress and stop it if I need to
- **So that** I keep control of my data usage and storage

**Priority**: P1
**Dependencies**: US-07

**Acceptance criteria**:
- [x] A visible indicator shows the current download in progress with its progress and its target novel.
- [x] The user can cancel a running download and it stops promptly; the cancelled chapter is not marked as downloaded (B19).
- [x] When the connection is lost mid-queue, the app says so and does not present the partial queue as complete (E7).
- [x] If the phone runs out of storage mid-queue, the app stops, says why, and keeps the chapters already completed (E20).

---

### US-09: Keep a novel in my library

- **As a** reader
- **I want** to keep the novels I care about in my library
- **So that** I find them again in one place

**Priority**: P2
**Dependencies**: US-03

**Acceptance criteria**:
- [x] A novel can be added to the library and removed from it, and keeping it is the same action as following it (B11).
- [x] The library lists every kept novel with its title and cover, and shows an unread/new indicator when the novel has chapters the user has not opened (B14).
- [x] The library is available with the connection off and opens without any network call (C14).
- [x] Removing a novel from the library **keeps** its downloaded chapters on the phone; deleting them is a separate, explicit choice that is off by default (B32, B33).

---

### US-10: See which followed novels have new chapters

- **As a** reader with novels in my library
- **I want** to be told which of my novels have chapters I have not read
- **So that** I know what is new without visiting each site

**Priority**: P2
**Dependencies**: US-09

**Acceptance criteria**:
- [x] A single view lists every library novel that has at least one chapter the reader has not opened, showing that count. The list does **not** depend on whether a check has run: a novel never checked appears with its count and "never checked" beside it (B48, B49).
- [x] The counts come from the chapters themselves, so opening any chapter clears its new marker and the counts update across the app accordingly (B13). Opening the novel's page does not itself mark chapters as seen.
- [x] With the connection off, the view shows the last known result and says it may be out of date; it never claims there is nothing new (B15).
- [x] A novel whose site cannot be reached is visibly marked as unverified rather than counted as having no new chapters (B22).

---

### US-11: Resume exactly where I stopped

- **As a** reader who was interrupted
- **I want** to reopen a chapter and land back at the paragraph I was reading
- **So that** I never lose my place

**Priority**: P2
**Dependencies**: US-04

**Acceptance criteria**:
- [x] Reopening a chapter that was previously read returns to the last position within that chapter (B16).
- [x] Positions are kept separately per chapter; reading chapter 12 does not move the remembered position in chapter 13 (B16).
- [x] Returning to a novel offers to continue at the most recently read chapter (B17).
- [x] A stored position survives the app being closed and reopened, and survives a new version of the app being installed (B31).

---

### US-12: Review what I read recently

- **As a** reader
- **I want** to see the chapters I opened recently
- **So that** I can find again something I read but have not finished

**Priority**: P2
**Dependencies**: US-04, US-11

**Acceptance criteria**:
- [x] A history view lists recently opened chapters, most recent first, each identifying its novel and its chapter title (B17).
- [x] Opening an entry from history opens that chapter, following the same resume behaviour as US-11 (B16).
- [x] The history is readable with the connection off (C14).
- [x] The list keeps at most 200 entries, dropping the oldest first, and offers to clear the list entirely (B46); the cap is 200 entries (B46).

---

### US-13: Use the whole app in French or in English

- **As a** French-speaking or English-speaking reader
- **I want** the entire app — every screen and every error message — in my language
- **So that** nothing is unreadable or confusing

**Priority**: P2
**Dependencies**: US-16

**Acceptance criteria**:
- [x] Every user-visible string exists in French and in English, including all error messages and all download-status messages (B28).
- [x] Changing the phone's language is reflected in the app, including its error messages, with no loss of library or progress (E12).
- [x] The app follows the phone's language setting, and a language it does not recognise falls back to French. There is no in-app language switch (B28).
- [x] No screen ever displays a string in a locale other than the active one, an empty label, or a raw error string passed through from a site (B28).

---

### US-14: Read at night in dark mode

- **As a** reader reading in bed or in transit at night
- **I want** the app to be dark when my phone is dark
- **So that** reading at night is comfortable for my eyes

**Priority**: P2
**Dependencies**: US-04

**Acceptance criteria**:
- [x] With the phone in dark mode, every screen of the app, including the reader, is dark (B26).
- [x] Text and controls remain legible against their background in dark mode.
- [x] Switching the phone between light and dark while reading applies immediately and does not move the reading position (E13).
- [x] The user can override dark/light inside the app without changing the phone's setting (B26).

---

### US-15: Read at my own text size

- **As a** reader who needs large or small text
- **I want** the reader's text size to follow my phone's setting and to be adjustable inside the app
- **So that** a chapter is comfortable to read

**Priority**: P2
**Dependencies**: US-04

**Acceptance criteria**:
- [x] The reader's text size follows the phone's font-size setting (B27).
- [x] The user can increase or decrease the reader's text size inside the app, and the choice survives closing the app (B27).
- [x] Changing the phone's font size while reading applies to the reader and does not lose the reading position (E14).
- [x] At the largest text size the reader still shows text without clipping, overlap or horizontal scrolling of the body text.

---

### US-16: Be told when a site stops working, instead of seeing nothing

- **As a** reader — or the owner, debugging the app alone
- **I want** a clear failure message when a site cannot be read
- **So that** I never mistake a broken site for a novel with no chapters

**Priority**: P1
**Dependencies**: none

**Acceptance criteria**:
- [x] When a site changes its pages in a way the app can no longer read, the app displays a failure message that says the site could not be read; it never displays an empty catalogue, an empty chapter list, or "0 results" (B22).
- [x] A failure message identifies which site failed and offers a way to try again (B24).
- [x] A failure on one site leaves the other sites fully usable, and leaves downloaded content readable (B23).
- [x] Every failure message exists in French and in English (B28).

---

### US-17: Get a new version of the app as a file I install myself

- **As a** reader who cannot write code
- **I want** the app to be delivered to me as a file that installs over my existing copy
- **So that** when a site breaks and the app is fixed, I receive the fix myself

**Priority**: P1
**Dependencies**: US-16

**Acceptance criteria**:
- [x] A new version of the app is produced as an installable file that the owner can install on the phone by hand, with no app store and no store account (B31, C3).
- [x] Installing a new version over the previous one keeps the library, the downloaded chapters, the reading positions and the history (B31).
- [x] The owner can determine which version is installed on the phone (C9).
- [x] The build is repeatable automatically; it does not require the owner to perform a manual procedure (C9).

---

## 4. Business rules

<!-- One row per rule. IDs B1, B2, B3... never reused. -->

| ID | Rule | Linked user story | Notes |
|---|---|---|---|
| B1 | v1 ships exactly two sites: FanMTL and Royal Road. A third (Novel Fire) is conditional on its terms of service being confirmed. **There is no deadline.** If unconfirmed, it is absent from v1 and v1 does not count it against its own success (E21). | US-01, US-16 | Explicitly agreed with the owner |
| B2 | A novel belongs to exactly one site. The app never merges or mixes two sites' novels, even when their titles are identical (E17). | US-01, US-03 | |
| B3 | A novel's and a chapter's identity are stable across sessions and across restarts of the app, so the library always points back at the same novel and the same chapter. | US-03, US-09, US-17 | |
| B4 | The app has no account and no sign-in. Nothing it does is gated behind an identity, and there is no identity stored on the device. | all | Product expression of the privacy constraint C2 |
| B5 | Nothing is fetched from a site unless the user asked for it. There is no bulk or speculative background fetching of chapter content. | US-04, US-06 | Storage constraint C4 |
| B6 | A chapter is stored atomically: it is either completely present on the phone and readable, or it is not stored. A partially stored chapter is never shown as downloaded and never opens as if complete (E6, E18). | US-06, US-07 | Data-loss constraint C8 |
| B7 | Once a chapter is stored, it is readable with no connection, independently of the site's current reachability or of any future change to that site. | US-05 | The "wow" moment |
| B8 | A chapter spread over several pages on a site is presented to the reader as one continuous chapter, with the pages joined in their original order (E3). | US-04 | |
| B9 | A novel's chapter list is shown complete, in reading order, whatever its length. The bound is explicit: a novel of **10 000 chapters** must still list completely, in order, without freezing or dropping entries; above that the app says so rather than silently truncating (E1). No entry is dropped, truncated, or replaced by a "show more". | US-03 | |
| B10 | Chapter titles and numbering are displayed exactly as the site presents them. The app never renumbers, reorders, deduplicates, or hides them, including irregular forms such as "Chapter 1", "Ch. 12.5", "Vol 3", "Extra", "Omake", and untitled chapters (E2, E10). | US-03 | |
| B11 | Keeping a novel in the library and following a novel are the same thing; there is no separate follow control and no second list. | US-09, US-10 | |
| B12 | A novel enters the library only through an explicit user action on a novel the user opened from a site. | US-09 | |
| B13 | A chapter counts as new until the user has opened it; opening it clears its new marker. | US-10 | |
| B14 | The number of new chapters shown for a novel equals the chapters in it that the user has not opened. The count is never an estimate and never a stale number presented as fresh. | US-09, US-10 | Success criterion SC-3 |
| B15 | Checking a library novel for new chapters requires a connection. With no connection the app shows the last known result and labels it as possibly out of date; it never presents "no new chapters" as a fresh answer. | US-10 | |
| B16 | The reading position is remembered separately for each chapter, and reopening a read chapter returns to that position. | US-05, US-11 | |
| B17 | Reading history lists recently opened chapters in reverse order, most recent first, and returning to a novel offers the most recently read chapter of that novel. | US-11, US-12 | Capped at **200 entries**, oldest dropped first, and clearable by the reader |
| B18 | Downloading a novel enqueues its chapters one at a time in reading order. The bulk choices offered are: the next chapter, the next 5 / 10 / 25 chapters, **all unread chapters**, or an explicit set the user selected by hand. There is no "download every chapter including ones already read" shortcut — that is reachable only by selecting every chapter deliberately. | US-07 | Resolved from Mihon: a 6-option download menu plus multi-select download |
| B19 | A download queue can be paused and cancelled. Paused, cancelled and unfinished chapters are never marked as downloaded, and a cancellation takes effect without a further action, and no further chapter is fetched after it. | US-07, US-08 | |
| B20 | A download interrupted by loss of connection or by the app closing leaves the affected chapter unstorable-as-complete; the chapter is fetched again from the start rather than completed from a partial state. | US-06, US-08 | |
| B21 | A download queue survives the app being closed and reopened: it continues from where it stopped rather than restarting the novel. | US-07, US-08 | |
| B22 | When a site cannot be read the app states that it could not read it, and never presents an empty list as an answer. **"Could not read" and "genuinely nothing" are distinguished like this:** the response parsed successfully AND carries the site's own explicit empty-result signal → genuine nothing, shown as a clear "no results". A successful response whose expected content elements are simply absent, a parse error, or a non-success status → the site could not be read, reported as a failure with a retry. **The discriminator is the site's own empty-result signal, never the absence of a match.** | US-16 | **Clarified by red-team:** the old wording made a genuine zero-result search indistinguishable from a broken site |
| B23 | A failure on one site never blocks the other sites, and never makes stored chapters unreadable. If a site becomes unreachable, changes, or is removed from the app entirely, the chapters already downloaded stay readable on the phone, and the other sites carry on working. | US-09, US-12 | Extended by the red-team pass so it actually covers a site that is removed from the app entirely, which is what this rule was being cited for |
| B24 | Any action that can fail shows an error the user can read and act on, together with a way to try again. No action fails silently to a blank screen or a silent spinner. | US-01, US-16 | Direct consequence of "no server, no telemetry" (C6) |
| B25 | Reading is a continuous scroll. There is no page-turn mode, no side-by-side layout, and no colour filter in v1. | US-04 | See §9 |
| B26 | The app follows the phone's light/dark setting, and the user may override light/dark inside the app without changing the phone's setting. | US-14 | Required by the project rules: `09-widgets-ui.md` §Reader UX and `14-design-tokens.md`. Not an open assumption |
| B27 | The reader follows the phone's font-size setting, and the user may adjust the text size inside the app; the in-app choice survives closing the app. | US-15 | Required by the project rules: `09-widgets-ui.md` §Reader UX and `14-design-tokens.md`. Not an open assumption |
| B28 | Every user-visible string exists in French and in English, including all error and download-status messages. The app's language follows the phone's language setting, and an unrecognised language falls back to French. | US-13 | **No in-app language switch.** Mihon has an app-language screen; we deliberately do not, because no project rule provides for one |
| B29 | No user data leaves the device: no library, no reading progress, no history, no diagnostics, no analytics, no crash reports, no telemetry of any kind. | all | Product expression of C2 |
| B30 | The app's content is private to the device: no chapter can be shared out of the app, and a novel cannot be sent, exported, or copied elsewhere. | all | |
| B31 | A new version of the app is delivered as an installable file. Installing a new version over an existing one preserves the library, every downloaded chapter, all reading positions and the history. | US-17 | No backup exists, so upgrade safety is the only preservation guarantee the app can offer (C8) |
| B32 | Removing a novel from the library **keeps its downloaded chapters on the phone**. Deleting those chapters is a separate choice the user makes explicitly, off by default. No path removes a novel and silently destroys chapters that cannot be recovered. | US-09 | **Corrected.** Mihon never auto-deletes downloads on removal; with no backup and no export, the opposite is unrecoverable loss |
| B33 | The downloaded copy of a single chapter can be deleted on its own, leaving the other chapters of the novel untouched. | US-06 | |
| B34 | The app runs on Android phones only and is delivered as an installable file built automatically. No app store, no store account, no public distribution. | US-17 | See also C3, C9 |


| B35 | **Checking for new chapters is off by default.** The app never checks on its own unless the user turns it on and picks an interval: never, every 12, 24, 48 or 72 hours, or weekly. Choosing "never" actively disables the scheduled check rather than merely skipping it. | US-10 | Mihon `LibraryPreferences.autoUpdateInterval`, default `0` |
| B36 | A manual action — "update library" — is available whether or not the schedule is on. **Opening the app is not a trigger for a check.** | US-10 | Mihon has no foreground/app-open trigger at all; we inherit that gap rather than close it |
| B37 | A scheduled or manual check runs as a foreground job with a visible notification the user can cancel. Cancelling one run does not disable the schedule. | US-10 | Mihon `LibraryUpdateWorker`: foreground service, notification with a cancel action |
| B38 | **A new-chapter check never starts downloading.** Checking and downloading are separate and never overlap: the check reads chapter lists and nothing else. It never enqueues, defers or triggers a download — a download starts only when the user asks for one (B5). | US-07, US-10 | **The highest-value Mihon invariant for this product.** Mihon's own stated reason: "We don't want to start downloading while the library is updating, because websites may not like it and they could ban the user." See C7 |
| B39 | An automatic check visits every novel in the library **except those the reader has completed**, which it skips as a courtesy to the site. A novel is never skipped because it has unread chapters, and never because it has not been read yet. | US-10 | **Rewritten to remove the B14 conflict.** Mihon skips "has unread", because there the user is actively reading and will meet the chapters anyway. That reasoning inverts for us: the download queue is the product, so the novels being read are exactly the ones whose new chapters matter most. Skipping them would leave a reader's own download queue silently stale |
| B40 | Library entries are **never renamed, aliased or merged.** Two novels with the same or a similar title stay separate. Adding one that resembles an existing entry warns and offers to open the existing entry or add anyway — nothing is ever merged. | US-09 | Mihon has no title field at all and no merge path; it only warns |
| B41 | Searching inside a site searches whatever that site searches. The app does not split a query into title, author and description, nor decide which of those a site matches; it passes the reader's words to the site. | US-02 | Mihon passes one opaque query string per source, with no app-level field decomposition |

| B43 | The app shows which version is installed, on a dedicated about screen. | US-17 | Mihon `AboutScreen` |
| B44 | **Content read from a site is only ever text.** Markup, styling, script, or any URL supplied by a site is never executed, never loaded, and never followed as an instruction — it is shown as literal characters or discarded. A site cannot make the app fetch anything, run anything, or change any setting by what it returns. | US-05, US-16 | **Added by red-team:** scraped content is the most likely hostile input to a scraper and the document did not mention it. Enforces C1/C4 in §7.2 |
| B45 | The library search covers the fields the app actually stores — title, author, and genre where the site provided them — and nothing more. It never claims to search a field the app does not hold. | US-09 | **Rewritten by red-team:** B42 promised a search over fields no requirement established were stored |
| B47 | **The history list is bounded by time, not by count.** Entries older than **one year** are dropped, oldest first. The reader may change that window or clear the list entirely. | US-12 | **Standard, not a guess.** Mihon bounds nothing — its history table has no `LIMIT` and no retention window, cleared only by hand — so there is no precedent to copy. Every platform that does bound activity history bounds it by **time** (Safari and Chrome offer "delete history older than…"; Google account activity defaults to 18 months; Android usage stats keeps about a year). **Time, not count, because a count cap punishes heavy readers — precisely our user — while time bounds unbounded growth without punishing use.** One year is the longest default any of those platforms uses and is long enough that no real reader ever reaches it: the cap exists to bound a pathological table, not to be felt. |
| B48 | **The new-chapter count is a local fact and never depends on a check.** It is the number of chapters the reader has not opened. The app always knows this number exactly, because it counts what it has stored — it is never an estimate and never goes stale. | US-10, US-11 | **This is what dissolves the B14/B39 conflict.** Once the count is purely local, a skipped novel's count is still correct; nothing about the count can be made wrong by whether a check ran |
| B49 | A novel also shows **when it was last checked against its site**, or "never checked" if it has not been. The app never implies there is nothing new for a novel it has not checked — it says it has not looked. | US-10 | Closes B15: staleness is made **visible** rather than denied. Two separate facts, two separate displays: how many you have not opened, and how recently we confirmed what exists |
| B46 | **Reading position and reading history are different things and are never conflated.** The position — which chapter, and how far into it — is held for every novel forever and is **never trimmed by any retention rule**, because it is what "pick up where you left off" depends on and there is no backup of it. The history *list* — a log of what was opened, browsable by date — is bounded separately (B47). | US-11, US-12 | **Split by red-team finding:** one rule was covering both, and any cap applied to it would have quietly destroyed reading positions |
## 5. Constraints

<!-- One row per constraint. IDs C1, C2, C3... -->

| ID | Constraint | Type | Impact |
|---|---|---|---|
| C1 | Legal — reading is for personal use only, from sites whose rules permit automated reading. Verified for FanMTL and Royal Road; unconfirmed for Novel Fire (B1). No redistribution of any content. | legal | The owner personally accepts the risk of reading sites written by other people. Sets the ceiling on scope: nothing may be built that republishes or shares content. |
| C2 | Privacy — no account, no server, no telemetry of any kind. Reading data never leaves the phone (B4, B29). | legal | Every feature must be complete without any server round-trip. No analytics, no crash reporting, no remote configuration, no usage measurement. |
| C3 | Platform — Android phones only. The owner cannot build or test iPhone apps at all. Delivered as an installable file, installed by hand (B34). | technique | No iOS, no tablet layout, no desktop, no web. The phone is the only verification target. |
| C4 | Content ownership — store only what is needed to read a chapter the user asked for, keep it on the device, and remove it when the user removes the chapter. **Removing a novel does not remove what has been downloaded** — that is a separate, explicit choice (B5, B32, B33). | legal | Bounds storage growth and keeps the app from accumulating content nobody asked for. |
| C5 | User skill — the only technical user cannot write code. Repairing a site that has changed must be deliverable to them as a new installable file with no manual step on their side (US-17). | métier | Every maintenance action funnels through "build a new file". There is no remote fix, no configuration the user can perform. |
| C6 | No server, no support, no telemetry means the app has no way to learn why it failed. Failures must therefore be recognisable on the device and reported there (B24, B22). | technique | Determinism and honest error states become a product requirement, not a nicety. |
| C7 | Source reliability — sites change their pages without warning and can stop working overnight. The app silently returning nothing is the main failure mode to avoid (B22, E4). | métier | Drives US-16, E4, E8, E9 and the verification of SC-1. |
| C8 | Data loss is structurally accepted — there is no backup and no export (B31, C2). An interrupted or partially written download must therefore never be presented as complete (B6, E6, E7). | métier | No recovery exists, so the app must be incapable of creating a false state of completeness. |
| C9 | Delivery — the app must be buildable without a store account and installable from a file on the owner's phone, repeatedly, without the owner performing a manual procedure (US-17). | technique | Puts "one verified install on the owner's phone" (SC-5) on the critical path. |
| C10 | Novel Fire's terms of service must be confirmed by the owner before its scraper is written. **There is no deadline.** FanMTL is the first source and does not wait on this; Novel Fire ships whenever, or never. | Time | Novel Fire is strictly additive: it can never delay or block v1, because FanMTL is the first source and does not wait on this decision |
| C11 | Usage context — reading happens one-handed, on a phone, at night or in transit, frequently with poor or no connectivity (C11 also constrains gestures, text size and error legibility). | métier | Features that assume steady connectivity or two hands are out of place. |
| C12 | Privacy of failure reporting — because a borrowed-device reader cannot send anything back (C2), the app must make its own failure state obvious enough for that reader to describe it to the owner **in words** — a message that can be read aloud and reported back — and actionable, not merely present. | métier | Constrains error wording and what the owner can learn from a friend. |
| C13 | One device, one reader — lending the app file is the whole distribution model. There is no multi-user support, no per-user data, no shared library, no migration of a reader's progress between two people's devices. | métier | No login, no profiles, no sync. See §9. |
| C14 | No network call may be required to open the app, open the library, list stored chapters, open history, or read a stored chapter (B7). | technique | This is the measurable form of the "wow" moment and is verified by SC-2. |

---

## 6. Edge cases

<!-- One row per edge case. IDs E1, E2, E3... -->

| ID | Case | Trigger | Expected behaviour | Severity |
|---|---|---|---|---|
| E1 | Chapter list of extreme length | A novel with 120 chapters, or one with several thousand | The complete list is displayed in reading order, remains scrollable and responsive, and nothing is dropped or truncated (B9) | medium |
| E2 | Inconsistent chapter titles and numbering | Titles such as "Chapter 1", "Ch. 12.5", "Vol 3", "Extra", "Omake", or none at all | Displayed verbatim; all are selectable and openable; none is discarded for being irregular (B10) | high |
| E3 | Chapter split across several pages | A site's chapter continues onto a second and third page | The pages are joined in their original order into one continuous chapter before reading (B8) | high |
| E4 | Site layout changed between releases | A site reorganises its pages; the app can no longer read it | The app detects this and reports "this site could not be read"; it never shows an empty catalogue or an empty chapter list as if the novel had none (B22) | critical |
| E5 | No connection while browsing or searching | The user is offline and opens a catalogue or runs a search | A clear "no connection" message with a retry; the library and every stored chapter remain fully usable (B23, C14) | high |
| E6 | Download interrupted partway | The connection drops, or the app is killed, while a chapter is being saved | The chapter is not marked as downloaded, never opens with partial text, and is fetched again from the start (B6, B20) | critical |
| E7 | Connection lost mid-queue | The connection drops while a whole-novel queue is running | The queue **stops**, says why, and keeps every chapter already completed. It does **not** resume on its own when the connection returns: the download queue runs in-process and has no background executor. The reader resumes it (B19, B21) | medium |
| E8 | A site returns nothing where content is expected | A site's page loads but contains none of the expected items | Treated as a suspected break, not as "no results", and reported as a failure (B22) | high |
| E9 | A followed novel disappears from its site | The site removes, renames or hides a novel the reader kept | **When the reader is online**, the app says the novel is no longer available at that site. **With the connection off, the app makes no claim about the site at all** — it shows only the stored chapters and says their state is as last seen. Either way every stored chapter stays readable (B7, B23, C14) | medium |
| E10 | The same chapter listed twice by a site | A site's chapter list contains two entries with the same title | Both are displayed as the site lists them; the app neither merges them nor silently drops one (B10) | low |
| E11 | The app is uninstalled or the phone is lost | The reader removes the app or loses the device | **Nothing can warn the reader at the moment of removal** — the device performs an uninstall, outside the app, and there is no hook for it. The disclosure is therefore made **earlier**: on first run and in settings, stating plainly that the library is not recoverable. The app does not pretend to have an uninstall hook (§9) | high |
| E12 | The phone's language changes | The reader switches the phone from French to English or back | The app's text, including every error message, follows the new language, with no loss of library, downloads or progress (B28) | medium |
| E13 | Dark/light mode changes mid-read | The user flips the phone's theme while a chapter is open | The change applies immediately and the reading position is preserved (B26) | low |
| E14 | Font size changes mid-read | The user changes the phone's font size while a chapter is open | The reader's text resizes immediately, no text is clipped or overlapped, and the reading position is preserved (B27) | low |
| E15 | The app is closed or the phone restarts mid-queue | A fifty-chapter download is interrupted by the app being closed or the phone rebooting | The queue continues from the chapter it reached when the app is opened again; it does not restart the novel (B21) | high |
| E16 | A library novel gains new chapters between visits | The site publishes a chapter after the user last checked | The new chapters appear as new on the next successful check; every already-stored chapter is unchanged and remains readable (B13, B14) | medium |
| E17 | Two novels with the same title, from different sites | The library or a catalogue holds two identically titled novels | They remain two distinct novels, each opening its own site; they are never merged (B2) | low |
| E18 | A chapter page contains no real text | The site returns a page whose article element is absent, empty, or holds only placeholders | **A chapter is "no real text" when nothing readable survives cleaning** — no paragraph, no line break, and fewer than 100 characters of text in total. Below that threshold the chapter is not stored as complete; it is reported as a failure with a retry (B6, B22). The threshold exists because a legitimately short chapter is common on these sites — end notes, an "Extra", an author's afterword — and must never be mistaken for a broken one (see E22) | high |
| E19 | A search genuinely matches nothing | The search is well-formed and the site has no match | An explicit "no results" message, visibly distinct from a failure message (B22, US-02) | medium |
| E20 | The phone runs out of storage mid-download | A queue exhausts the available space | The queue stops, says why, keeps every already-completed chapter, and never records a partial chapter as complete (B6) | high |
| E21 | Novel Fire's terms are not confirmed | The decision in C10 arrives negative | Novel Fire does not ship, is not advertised anywhere in the app, and v1's success is judged without it (B1) | medium |
| E22 | A chapter is legitimately very short | The site publishes an end note, an "Extra", an "Omake", or a volume-closing note — real content of a few lines | Stored and read like any other chapter. The E18 threshold must **not** discard it: the test is whether readable text survived cleaning, not how much of it there was (B10) | medium |

---

## 7. Non-functional requirements

### 7.1 Performance

Targets are stated as **measurable frame-budget numbers** where a number exists to be had, and are labelled as targets rather than measurements. Three of them are not yet measurable and are marked as such below rather than dressed up with an adjective: list responsiveness on a very long novel, download-progress cadence, and how quickly a cancelled queue actually stops. **A requirement that reads well but cannot fail is not a requirement**, and those three are listed so Phase 4 either gives them a number or drops them. The owner supplied no number, so these are taken from the two published definitions rather than invented:

- **Android**, on rendering performance: *"your app must render frames in under 16ms to achieve 60 frames per second… If you are trying to achieve 90 fps, then this window drops to 11ms, and for 120 fps it's 8ms."* Overrunning the window by even 1ms means the frame is **dropped entirely**, which is what the reader perceives as stutter.
- **Flutter**, in the installed SDK (`scheduler/binding.dart`, the `addTimingsCallback` documentation): a frame is late if `FrameTiming.buildDuration` or `FrameTiming.rasterDuration` exceeds the frame budget — 16ms at 60Hz — and the interaction is late if `FrameTiming.totalSpan` exceeds it, *even when no frame was actually dropped*. The SDK notes that in the latter case *"animations will be smooth but touch input will feel more sluggish."*

Consequently:

- **Scrolling a downloaded chapter drops no frames at the device's own refresh rate.** The budget is half the refresh period: 16ms at 60Hz, 11ms at 90Hz, 8ms at 120Hz. The target is stated against the refresh rate rather than against 60Hz specifically, because a 120Hz phone makes 16ms a target that passes while feeling slow. Measured by the SDK's own frame timings: no reported frame has `buildDuration` or `rasterDuration` over that budget. This is the "wow" path (B7) and the one the owner named as the reason to install the app.
- **Touch response while scrolling stays within budget**, which is a *separate* condition from smoothness: `totalSpan` must stay within 16ms even on frames that render in time. Dropping this check is how an app passes a smoothness test while feeling sluggish.
- **Opening a downloaded chapter performs no network call at all** and reads only local storage (B6, B7). Being fast is not the same as being offline; §7.5 makes the offline guarantee and this section makes it fast.
- **Not yet measurable.** Browsing a catalogue and opening a chapter list of several thousand chapters must stay usable (E1, B9). The threshold and the device it is measured on are left to Phase 4, which must either set a number here or delete the line.
- **Not yet measurable.** Download progress is visible while the queue runs and is not only shown at the end (US-08). The required update frequency is left to Phase 4, which must set a number or drop the line.
- **These numbers are targets, not measurements.** They become a verified claim only once the app runs on a real device, which is the same measurement that closes Q-003. Until then they are a definition of "fast" against which a later measurement can be judged, not proof.


### 7.2 Security

- No account, no sign-in, and no credential of any kind is stored or exchanged (B4, C2).
- No data leaves the device: no library, no progress, no history, no diagnostics, no telemetry, no crash reports (B29, C2).
- Downloaded content stays in the app's own storage, and nothing else on the device can read it (C4, B30). **Removing a novel or a chapter from the library does not delete what has been downloaded** — that is a separate, explicit choice (B32, B33).
- Nothing the app reads from a site is treated as a trusted instruction to the device; content read from a site can only become text the reader sees (C1, C4).
- The app is not distributed through any store and has no public entry point (C3, C9).

### 7.3 Accessibility

- Text in the reader is legible against its background in both light and dark mode, including at the smallest and largest supported text sizes (B26, B27).
- The reader's text size follows the phone's font-size setting (B27, E14).
- No state is conveyed by colour alone: a chapter marked as downloaded, a novel marked as new, and a failed site must each be distinguishable without relying on colour.
- Every control is reachable and operable one-handed, which is the reader's normal posture (C11).
- Every failure message states what happened and what the reader can do next (B24).

### 7.4 Internationalization

- French and English are both complete, with no missing, untranslated, or partially translated text anywhere in the app (B28).
- All error and download-status messages are translated, not only navigation and labels (B28).
- The app follows the phone's language setting, and a language it does not recognise falls back to French (B28, E12). There is no in-app language switch; see §12.
- Chapter content itself is never translated or altered by the app — it is displayed as the site published it, in whatever language it was written (B10).

### 7.5 Availability / resilience

- Once stored, content stays readable regardless of the state of any site (B7, B23).
- No screen may fail to a blank page or an indefinite spinner (B24).
- A site that has broken must be identifiable as broken, on the device, by anyone holding the phone (B22, C6, C12).
- Interruption is expected, not exceptional: an interrupted download, an interrupted fetch, or an interrupted write must never leave the app in a state that claims more than it holds (B6, B20, E6, E7).
- Upgrading the app must never destroy the library, the downloads, the reading positions, or the history (B31).

---

## 8. Risks and unknowns

| Risk | Probability | Impact | Mitigation |
|---|---|---|---|
| A site reorganises its pages and the app silently returns nothing | HIGH | HIGH | B22, B24, US-16, E4, E8: an empty result is never presented as truth; the failure is reported on the device. Verified by **SC-6**, which exists for this and for no other purpose. |
| Only one person can fix a broken source, and that person is the owner | HIGH | HIGH | C5, US-17: the fix ships as an installable file. Accepted as a cost of the personal-use model; the app is designed to fail loudly rather than quietly so the owner learns of it from use. |
| Data is lost with no backup and no export | HIGH | HIGH | B6, B20, E6, E7, E20, C8: the app cannot represent a partial state as complete. The loss itself is an accepted consequence (§9), not a defect to be engineered away. |
| Scraping third-party sites carries legal risk | MEDIUM | HIGH | C1, C4: personal reading only, no redistribution, nothing left on the device beyond what was asked for. The owner accepts the risk personally. |
| Novel Fire's terms of service prove unacceptable | MEDIUM | LOW | C10, B1, E21: a legal decision with no deadline; it never gates v1, because FanMTL is the first source and does not wait on it and is excluded from v1's success. |
| The owner cannot judge how much effort a site repair will take, or how often they will be needed | HIGH | MEDIUM | Recorded as an unknown (§8 Inconnues). No mitigation is possible before the first year of data exists; surfaced rather than hidden. |
| Reader comfort regresses (dark mode, text size) and breaks the "wow" moment | LOW | HIGH | US-05, US-14, US-15 and §7.3: the offline reading path is the highest-priority story and is verified with the network off (SC-2). |
| Errors on a borrowed-device reader cannot be reported back without telemetry | HIGH | LOW | C2, C12: the app's failure states are worded so a reader can describe them in words. No telemetry is added to solve this. |
| Downloads drain the battery or the reader's data allowance | MEDIUM | MEDIUM | Recorded as an unknown; the queue is per-chapter, pausable and cancellable (B18, B19), so the reader can bound the cost. |

### Unknowns

- **Novel Fire's terms of service are unconfirmed.** This is the one input the project is waiting on, and it is a legal judgement the owner makes — not a product question. **There is no deadline**: FanMTL is the first source and does not wait on it, and Novel Fire ships whenever the terms are confirmed or does not ship at all, without counting against v1 (B1, C10, E21).
- ⚠️ **We have never measured how often these sites change their pages over a year.** The real maintenance cost of v1 is therefore unknown and cannot be estimated from the current sample of two working sites.
- ⚠️ **The battery cost of downloads has never been measured.** Nothing in this document can tell the owner whether a fifty-chapter download is acceptable overnight on their phone.
- Several product assumptions were made by the analyst where the interview was silent. Each is **recorded in the note of the rule it affects** and is **not** treated as decided until that rule is approved.

---

## 9. Out of scope (explicitly)

**Withdrawn requirements.** These carried an ID, were written, and were withdrawn by the red-team pass because they could not be verified or were contradicted by another rule. **The ID is retained and is never reused for anything else** — that is what makes the withdrawal traceable and stops a later requirement silently inheriting its number.

- **B42** — Local library search over explicit field prefixes (title, author, genre, source). **Withdrawn**: no requirement established that author, genre or description are stored, and no acceptance criterion tested it, so the rule was unverifiable as written. Replaced by **B45**, which promises only fields the app actually holds.

<!--
  This section lists **exclusions**, not withdrawals. The distinction is what
  makes the rest of the project readable, and it shows in the use of the ID.

  **An exclusion that was never a requirement carries no ID.** It describes what
  the product will not do. There is no ID, nothing to trace, nothing to verify.

  **A withdrawal keeps its ID** — and the requirement then disappears from
  sections 4, 5 and 6. That is the only rule that keeps a withdrawal traceable.

  **None of the items below was ever an established requirement.** Each was raised,
  discussed and consciously signed out by the owner during the interview. There
  is no approved deliverable resting on any of them, so none carries an ID, and
  none of these IDs is reused for anything else.
-->

- Accounts, sign-in, and cloud synchronisation of any kind — reason: a personal-use app on a single device with no server, and no feature in this document depends on them.
- Tracker integrations (Anilist, MyAnimeList and similar) — reason: never a requirement; the reader does not track what they read.
- Sharing a chapter, or exporting a novel to a file — reason: content belongs to its authors and sites, and nothing may leave the device.
- Backup and restore — reason: deliberately declined, together with export. The consequence — uninstalling the app or losing the phone destroys the library permanently — is stated openly in the edge-case table rather than hidden.
- Paged reading mode, side-by-side reading modes, and colour filters — reason: the reader scrolls continuously in v1.
- Reading the reader's own .txt, EPUB or PDF files — reason: the app reads web novels from sites; it is not a document reader.
- Tablet-optimised layout — reason: phone only for now.
- Publication on any app store — reason: the app is built automatically and installed by hand; there is no store account and no public distribution. The delivery commitment that remains is written as a positive obligation elsewhere in this document.
- Desktop and web versions — reason: phone only for now.

*Only the single **withdrawal** above carries an identifier, because it was once a written requirement; every other item here was raised, discussed and consciously signed out by the owner during the interview and was never an approved requirement, so none leaves a trace to follow. The related facts that survive as positive obligations live in §4 and §5 and nowhere else.*

---

## 10. Success criteria

<!-- How will we know the product succeeded? -->

- **SC-1 — Sources work end to end.** FanMTL and Royal Road can each be browsed, searched within, and their chapters read end to end. Novel Fire also, **if its terms of service have been confirmed by then** — there is no deadline, and if they are never confirmed, Novel Fire simply does not count against v1. FanMTL is the first source regardless.
- **SC-2 — Offline reading is proven.** Fifty chapters can be downloaded and then read **with the network off** — verified by actually switching off connectivity on the device, not by assuming the file exists.
- **SC-3 — The app's own records are correct.** Library, history, and unread badges are correct.
- **SC-4 — Both languages are complete.** French and English are both complete, including error messages.
- **SC-5 — It runs on the owner's phone.** One verified install on the owner's own phone, from an automatically built APK.
- **SC-6 — A broken site is reported, never presented as empty.** This is the single most likely way the app fails in real use, and it is the one thing a success list that only tests the happy path would miss. Given a captured fixture of a site whose layout has changed, the app shows a failure the reader can act on — and never an empty catalogue, never an empty chapter list, and never the text "0 results". A genuine zero-result search is still shown as "no results", because B22 requires those two states to be distinguishable.

---

## 11. Glossary

| Term | Definition |
|---|---|
| **Site (source)** | One of the websites the app can read. v1: FanMTL and Royal Road; conditionally Novel Fire (B1). |
| **Novel** | A single story on a single site. Belongs to exactly one site (B2). |
| **Chapter** | One readable unit of a novel — one or more pages on its site, presented as one continuous piece of text (B8). |
| **Catalogue** | The list of novels a site publishes (US-01). |
| **Stored chapter** | A chapter whose full text is present on the phone, and which is therefore readable with no connection (B6, B7). |
| **Library** | The list of novels the reader has chosen to keep. It is also the "followed" list — there is no second concept (B11). |
| **New / unread chapter** | A chapter the reader has not opened yet. Opening it clears the marker (B13). |
| **Download queue** | The ordered list of chapters being fetched, one at a time, in reading order (B18). |
| **Reading position** | Where the reader stopped inside one chapter, remembered per chapter (B16). |
| **History** | The reverse-chronological list of chapters the reader opened recently (B17). |
| **Reader** | The screen the chapter text is read in. Continuous scroll, no page-turn, no colour filter (B25). |
| **Offline** | With no usable network connection. Nothing on the read path may require the network (C14). |
| **The "wow" moment** | A downloaded novel opens with no signal. It is the reason the app exists and it is the highest-priority outcome (US-05). |

---

## 12. Points to clarify

<!-- Every unresolved ambiguity. Never mixed into the established facts above. -->

**None outstanding.** All fourteen questions raised at draft are now closed:

- **Twelve were answered by reading Mihon**, the declared reference project (`DECISIONS.md` ADR-008), and are recorded as business rules or as notes on the rules they changed. The table of which question landed where has been folded into each rule's own note.
- **The Novel Fire deadline** — removed by the owner. There is no deadline: FanMTL is the first source and does not wait on it, and Novel Fire ships whenever its terms are confirmed or never (C10, SC-1).
- **The offline read-path performance target** — answered from published standards rather than a number the owner could supply. §7.1 now carries Android's published frame windows (16ms / 11ms / 8ms) and Flutter's own definition of a late frame versus a late interaction, both measured with the SDK's `FrameTiming`. Those are *targets*; they become verified only once measured on a real device, which is what closes Q-003.

Three contradictions between the PRD's own sections were found and fixed during this pass, each of which a structural check passes without noticing: §7.2 still described downloaded content as being removed with the library, which contradicted the corrected B32; §7.4 still promised an in-app language override that B28 no longer allows; and §7.1 pointed at a §12 item that no longer existed.

## Gate checklist

- [x] The problem is defined concretely, not in jargon.
- [x] All user types are identified, including admin, support, moderator — including their explicit absence.
- [x] Every user story has verifiable acceptance criteria.
- [x] Every business rule has a stable ID (B1–B43), contiguous, none reused.
- [x] Every identified edge case has a stable ID (E1–E21).
- [x] Every constraint has a stable ID (C1–C14).
- [x] Non-functional requirements cover performance, security, accessibility, internationalisation and availability.
- [x] Risks and unknowns are listed.
- [x] Out of scope is explicit.
- [x] No rule or constraint is left implicit.

**Status**: `draft` → awaiting validation.