---
type: benchmarks
status: approved
generated_at: 2026-10-02
---

# Benchmarks — Lumen Tale

> Two reference products, read rather than assumed. Mihon was cloned and inspected at source (`db45dda`, 2026-10-02) — every Mihon claim below cites a file. Dreame/Webnovel claims come from their own store listings and published comparisons, dated 2026-09/10.
>
> **Purpose:** to say what "good enough" means for this archetype, and where the gap we can actually exploit is.

---

## 1. Archetype

`mobile_consumer` — bottom nav, 3–5 entries, a lifestyle loop (commute, evenings, bed) rather than a task loop. The reader is not *doing* something at a screen; they are reading in the gaps of their day.

## 2. Reference products

### 2.1 Mihon — the structural reference (cloned, source-verified)

Free, open-source Android reader for **comics and novels**, ~63 screens, plugin ecosystem of user-installed sources.

| Dimension | Mihon |
|---|---|
| Content | Manga **and** web novels, via user-installed source extensions |
| Storage | Per-chapter image files, **CBZ by default** (`saveChaptersAsCBZ`, default `true`) |
| Library | 4 filter toggles (downloaded/unread/started/bookmarked/completed), 10 sort modes, 4 display modes |
| Updates | **Off by default** (`autoUpdateInterval = 0`); never/12/24/48/72h/weekly |
| Downloads | Never "download everything": next / next 5,10,25 / **all unread** / hand-picked set |
| Reader | Image pager; reading modes, orientation, colour filter (`presentation/reader/`) |
| Sync | None. No account. |
| Network posture | Honest UA; `CloudflareInterceptor` harvests a `cf_clearance` cookie via an off-screen WebView — **we deliberately do not port this** (ADR-014) |

**What it proves is possible** and **what it costs.** The read path, the queue semantics, and the atomic temp-dir-then-rename download discipline are all directly reusable and are the basis for our B6, B18, B35 and B38.

**Where it is worse than the commercial apps:** no paged/slide reading modes for text, no cloud sync, no discovery of any kind — its whole browse surface is *your installed sources*.

### 2.2 Dreame / Webnovel — the competitive baseline

The user reads on these today, so they define "good enough". Both are subscription + in-app-currency apps.

**Dreame** (`com.dreame.reader`, v5.32.0, 2026-09-29): 100M+ readers, 500k+ novels.

- **Reading modes:** "choose between **flipping, sliding, or scrolling**" — all three, plus font, text size, margins, alignment, brightness, background colour.
- **Offline:** single and batch caching to local — the vendor listing states, in translation, "read offline with no network".
- **Sync:** cloud progress storage, tied to an account.
- **Social:** comments, author replies, daily rewards, personalised recommendations.

**Webnovel:** deepest catalogue of translated Chinese web novels; "batch-download an entire volume with one tap"; reliable background download — the comparison that favours it over Dreame is explicit that "**Dreame's offline access felt clunkier, requiring you to stay on a specific screen. Webnovel just works in the background**".

### 2.3 The gap we can actually exploit

Across the published comparisons of these five apps, the single most repeated serious failure is **not** ads or paywalls — it is data loss around the reinstall:

> "Paid coins are a stored balance with no consumer protection, and reviewers describe them **vanishing on updates, expiring on a timer, or failing to restore across reinstalls and devices**… The lack of reliable cross-device sync and a working restore-purchases flow turns paid content into something that can disappear."

> "**will not restore after a reinstall**"

They cannot fix it, because their library lives on their server and is coupled to an account and a payment system. Ours lives on the device, and **B31** makes an upgrade provably non-destructive: *installing a new version over an existing one preserves the library, every downloaded chapter, all reading positions and the history.*

**That is the wedge, and it is evidenced rather than asserted.** It is also why ADR-010 (personal use, no export) is a genuine constraint and not merely a scoping convenience: we are asking the reader to give up the safety net those apps provide.

## 3. Parity grid

| Capability | Mihon | Dreame / Webnovel | Lumen Tale v1 | v2 |
|---|---|---|---|---|
| Continuous scroll | — (image pager) | yes | **yes** | yes |
| Paged / slide modes | yes | yes (all 3) | **no** | **yes** (ADR-009) |
| Reading modes + orientation + colour filter | yes | partial | no | **yes** |
| Offline reading | yes | yes | **yes — the product** | yes |
| Background download | yes (foreground service) | yes | **no — in-process queue, no background executor (E7)** | yes |
| New-chapter detection | yes, off by default | yes | **yes, off by default** | yes |
| Cloud sync / account | no | **yes** | **no — deliberate** | reconsider |
| Social / comments / rewards | no | **yes** | **no — out of scope** | no |
| New-chapter notification | yes | **yes** | **no — forced by B35** (ADR-020) | yes |
| In-app purchases / coins | no | **yes** | **no — personal use** | no |
| Localisation | many locales via i18n | EN + many | **FR + EN** | more |
| Library survives reinstall | yes (local) | **no — the top complaint** | **yes, guaranteed (B31)** | yes |
| Tablet layout | partial | yes | **no — phones only, single column capped and centred** | possible (ADR-019) |

## 4. Divergences we assume, and their cost

| We do not ship | Cost to us | Why it is the right call |
|---|---|---|
| Accounts / cloud sync | Reader cannot switch phones without re-downloading | Nothing to leak, nothing to pay for, nothing to host (C2). Removes the entire class of "my library vanished" failures outright |
| Export / backup | Reader cannot take their library elsewhere; **an uninstall destroys it** | ADR-010: personal use only. A no-backup app that also can't export is a real constraint — mitigated only by B31 guaranteeing the app never destroys it |
| Reading modes beyond scroll | Reader must wait for v2 for a feature competitors ship today | ADR-009: the reader is the largest subsystem and feeds the pipeline. v1 scroll-only is the lowest-risk order |
| Second-source depth | Three sites in v1 (B1) triples the scraping surface | ADR-013 makes sources adapters over one contract, so a second site is selectors, not a rewrite |
| Store distribution | No other users; every fix is a manual reinstall | ADR-011. Removes a paid account and a review process |

## 4b. Costs of the capabilities v1 declines

> `§ 3` records *whether* a capability ships. A `no` there with no cost recorded here is a divergence nobody has paid for. These are the ones the parity grid marked `no` and the earlier draft of this file had not costed.

| Declined | What it costs the reader | Why v1 declines it |
|---|---|---|
| **New-chapter notification** | **A serialised novel's reader must open the app to learn a chapter is out.** For a title that updates daily that is a daily visit they may not have made | **Forced, not chosen.** ADR-020: B35 makes automatic checking opt-in, so with the default running there is nothing to detect and therefore nothing to announce. Reachable as soon as the reader opts into a schedule; slice `6-4` owns it |
| **Background download** | **The reader must keep the app alive for a queue to progress.** The comparison at § 2.2 says this of Dreame verbatim — *"Dreame's offline access felt clunkier, requiring you to stay on a specific screen"* — and we are on the wrong side of that line | E7: the queue is in-process with no background executor. A real cost, accepted rather than papered over |
| **Paged and slide reading modes** | Long sessions in the only modes our competitors' most-used feature offers are unavailable. Both commercial apps ship three modes | ADR-009: the reader is the largest subsystem and feeds the pipeline; scroll-only is the lowest-risk order. The position is stored as a **scroll offset**, so v2 resumes rather than converts |
| **Tablet layout** | A reader on a tablet gets a phone layout, centred. Not broken — not adapted | ADR-019: phones only. Past `--bp-mobile` the layout stops growing rather than reflowing |
| **Social, comments, rewards** | The reader has nobody to discuss a serial with. For a hobby that is social, that is the whole social half | Out of scope (ADR-010). Refused along with gamification generally — `stats.md` § 2.1 gives six mechanics we declined, streak first |
| **In-app purchases** | Nothing — and that is the point | ADR-010: personal use. Also the reason our library cannot suffer the failure in § 2.3 |

## 5. What this changes about our sequencing

1. **The offline read path is the product, not a feature.** Both commercial apps treat offline as a checkbox; our owner's stated "wow moment" is *"a downloaded novel opens with no signal"*. The offline path is therefore built and proven **before** browse polish.
2. **Reinstall-safety is a headline guarantee, not a footnote.** B31 is the one place where the competition's worst documented failure is structurally impossible for us. It deserves an explicit acceptance criterion and must not be traded away for anything.
3. **Reading modes are a known parity gap, deferred on purpose** (ADR-009). Recording it here prevents it being quietly forgotten, and the storage position is already shaped for it (scroll offset, not page index — ADR-009).
4. **Dark mode and text size are table stakes and both competitors ship them**, one of them with a discoverability complaint. ADR-009's in-app reader controls (B26, B27) are a parity requirement with a UX edge, not a nice-to-have.

## 6. Method note

Mihon claims are source-verified with file paths and defaults. Dreame/Webnovel claims are from vendor store listings and dated third-party comparisons; they describe *advertised and reviewed* behaviour, not source code, and are labelled as such. Where a claim could not be verified to the standard of the Mihon claims, it is not used as a design input.