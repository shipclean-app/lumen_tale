# External System Contracts — scraped novel sites

Each source in `sources/implementations/` is an integration with **a third-party website we do not control**. That makes every source an external-system contract: the site's real behaviour is only partly documented, and it changes without notice.

This file is the project's **findings store** for those discoveries, and it has a promotion path. A finding that never reaches a rule file is a diary entry that competes with the rules instead of informing them.

## Per-site record

Add a section per site once it is implemented. Record **behaviour**, not the workaround you happened to use — a recorded behaviour tells a future session what to re-check when the site changes; a recorded workaround just becomes wrong.

```markdown
### <site name> — <base url>

- **Permission**: permitted / disallowed / unknown
- **Rate limit observed**: <what the site actually tolerates>
- **Last verified**: <YYYY-MM-DD>
- **Quirks**: <discovered behaviour, one bullet each>
- **Pending promotion**: <rule file + rule, or "none">
```

Rules for this store:

1. **Every entry carries its confirmation**: when it was observed, and against which version of the site (or which fixture). An entry with no provenance is a guess with a confident tone.
2. **Every quirk names its promotion target.** A quirk that is true beyond one site becomes a rule in the owning file (`03-source-system.md`, `04-html-to-markdown.md`, `17-security.md`); the entry stays as its provenance. A quirk that is genuinely site-specific stays here and is **not** promoted — the test is whether the statement holds beyond this one deployment.
3. **Known-and-always-true behaviour is not a finding.** It goes straight into the rule files. This store accumulates only what had to be discovered.
4. **Layout drift is the expected failure mode.** When a site's markup changes, the symptom is a source silently returning zero results or a chapter body that cleans to nothing. Treat "the source returned an empty list" as a *suspected layout change* before treating it as "no results exist".

## Cross-site rules

These are in `03-source-system.md` (contract) and `17-security.md` (posture); they are listed here as the discovery surface, not as a second home.

- Only scrape sites that permit it. **Permission is a gate, not a preference** — a site recorded as `disallowed` is never implemented.
- Identify honestly, rate limit, back off on `Retry-After` (`17-security.md` rules 5–6).
- The platform never interprets filter values; a source declares and interprets its own filters (`03-source-system.md` rule 5).
- Source ids are derived from `name/lang/versionId`; bump `versionId` when URLs break so a user's stored novel keeps resolving (`03-source-system.md` rule 1).

## Open items

Two further sites were selected for v1 on 2026-10-02. **FanMTL** is the **first** source. Royal Road and Novel Fire status: see Q-004 / the ADR-011 note below.

**Search reachability is measured per site and recorded per site.** ADR-015 makes `supportsSearch` a declared promise, so each site needs its own fetch-and-verify pass before search can be claimed for it. Current state:

| Site | `supportsSearch` | Basis |
|---|---|---|
| FanMTL | **false** | Measured 2026-10-02. GET and POST both 404 with a meta-refresh, including for a query that should match, session or no session. Genre browsing works and is the intended path. |
| Royal Road | **true** | **Measured 2026-10-03 by `6-11`.** `/fictions/search?title=<q>` returns 200 and 20 rows for two queries that MUST match, with every sampled title carrying the queried words; the control query that cannot match returns 0 rows with the site's own "No results matching these criteria were found" marker. The **rows and the titles** are the verdict — a 200 and a count of 20 are not. See *Royal Road — the search side DOES have an empty marker* below. |
| Novel Fire | **unknown — and NOT because it was never checked** | `6-11` checked on 2026-10-03: `/`, `/search` and `/search?keywords=litrpg` all answer **403** with a `Just a moment...` interstitial carrying `challenges.cloudflare.com`, on the honest UA. **A 403 challenge is not `false`** — rule 5a's list is 404, meta-refresh, timeout, empty page, and a challenge is none of those; the site declined to be read at all. Also blocked on Q-004. |

**v1 therefore claims genre browsing for all three, and search for Royal Road only.** That
is a correct v1, not a gap: `supportsSearch = false` means the UI offers genres instead
of a search box (rule 5a), and a site whose search is **unmeasured** must not be shown a
search box, because the flag is a promise and an unmeasured promise is a guess.

⚠️ **Two flags, two reasons, one table.** FanMTL is `false` because its endpoint is
**absent**; Novel Fire is unknown because its endpoint is **unreadable**. They look
similar in this table and they are different facts: the first is a property of the site
that will still be true next month, and the second is a property of *this network on this
day* that a phone on the owner's own connection may answer. Collapsing them would record a
guess as a property of the site.

---

## Recorded sites

### FanMTL — https://www.fanmtl.com — **FIRST SOURCE**

- **Permission**: permitted. Its `robots.txt` is an **EmpireCMS** file. The `User-agent: *` block disallows exactly seven paths — `/d/`, `/e/class/`, `/e/config/`, `/e/data/`, `/e/enews/`, `/e/update/` (plus `Allow: /ads.txt`). **Novel and chapter content under `/novel/` and `/list/` is not among them.** Note precisely which paths are listed: `/e/search/` is **not** disallowed, so search is not robots-blocked here — see quirk 6. The site also publishes `/terms-of-service.html` and `/dmca.html`; re-read both before shipping. Re-check `robots.txt` on every release and honour a change.
- **Scope**: fan-fiction / web novels. Genre taxonomy is Chinese-derived. **Eight genres, not nine**: `xianxia`, `xuanhuan`, `shounen`, `shoujo`, `romance`, `contemporary-romance`, `action`, `wuxia`. An earlier note here said nine — it had counted the `all` pseudo-entry as a genre, which it is not, and a screen cannot render nine labels when the site supplies eight.
- **Last verified**: 2026-10-04 — **reachable again.** Every path this section documents answered **200** to the honest User-Agent `LumenTale/0.1.0 (personal reader)`, and `0-1` froze fourteen fixtures from it. Reachability on 2026-10-03 was the opposite; see § Re-measurement 2026-10-03 and § FanMTL — re-measured 2026-10-04.
- **URL structure** (verified by fetching, not guessed):

  | Purpose | Pattern | Example |
  |---|---|---|
  | Novel detail + chapter list | `/novel/<id>.html` | `/novel/ke383028.html` |
  | Chapter body | `/novel/<id>_<n>.html` | `/novel/ke383028_1.html` |
  | Catalogue / tag / pagination | `/list/<tag>/<sort>-<page>.html` | `/list/xianxia/all-lastdotime-0.html` |
  | Latest chapters | `/updates/` | |
  | Genre index | `/browsetags/` | **8 genres** plus an `all` pseudo-entry — the primary discovery path |
  | Search | `/search.html` (form) → posts to `/e/search/index.php` — **both unreachable, see quirk 6**. Do not implement. | |

  The trailing integer in `/list/...` is the **0-based page number** — note this differs from the 1-based `page` argument in the `Source` contract. Convert at the boundary.

- **Quirks** — all confirmed against live HTML, all of which the implementation must handle:

  1. **Prose is NOT in `<p>` elements.** A chapter contains **0 `<p>` tags**; paragraphs are bare text nodes separated by `<br><br>`. Our converter's paragraph rule must therefore be *"`br br` → paragraph break"*, not only *"`<p>` → paragraph"*. Getting this wrong turns a whole chapter into one run-on block, and it will still look superficially correct in a smoke test.
  2. **`#chapter-article` contains the chrome, not the article.** It wraps `<header class="chapter-header">` (novel title `h1`, chapter title `h2`) and `<aside class="control-action">` (font selector — Default/Dyslexic/Roboto/Lora — plus Prev/Next and night-mode). The **body is `<div class="chapter-content">`**, nested inside `<section class="page-in content-wrap">`. Select `.chapter-content`, not `#chapter-article`, or the reader ships with a font-picker in the text.
  3. **An ad `<script>` sits inside the content div**: `<div align="center"><script src=/d/js/ad/page_01.js></script></div>`. The cleaner already drops `<script>` elements. Note the path is under `/d/`, which robots.txt disallows — we must never *fetch* it, and dropping the tag is what prevents that.
  4. **`&nbsp;` is not used**; separators are plain `<br><br>`. Whitespace normalisation has no entity to decode here.
  5. **Cloudflare, as above** — present, currently not challenging.
  6. **Text search is not reachable by an automated client; tag browsing is.** Measured 2026-10-02: the search form posts to `/e/search/index.php`, but GET returns 404 with a JavaScript meta-refresh, and POST returns the same 404 **even for a query that should match**, with and without a prior session (the site sets no cookies on `/` or `/search.html`). So FanMTL text search does not work for us — this is a reachability problem, **not** a robots.txt one. **What does work:** `/browsetags/` exposes **8 genres** (`action`, `wuxia`, `xianxia`, `xuanhuan`, `shounen`, `romance`, `contemporary-romance`, `shoujo`) plus one `all` pseudo-entry that is the unfiltered catalogue rather than a genre, and `/list/<tag>/<sort>-<page>.html` returns a full page of novels (30 per page, 123 catalogue links observed). **On FanMTL, "find a novel" therefore means browsing tags, not typing a query.** → **`supportsSearch = false`** (ADR-015). Genre browsing is not a consolation prize here; it is how the site is meant to be used, and a novel's detail-page genres are the good way in (browse the genre, never search for the tag).
  7. ⚠️ **`chapter-multipage-p1` AND `chapter-multipage-p2` ARE NOT IN THE CAPTURE — NAMED ABSENCE.** `0-1`'s § 3.3 marked three lines *"à découvrir"*: `chapter-list-page1`, `chapter-multipage-p1` and `chapter-multipage-p2`. Only the first was resolved: `chapter-list-page1` is a declared entry in `test/fixtures/sources/fanmtl/manifest.json` with a path read off the site's own pager hrefs. **The two multipage-chapter keys are ABSENT and this sentence is why.** They were not resolved and they are not declared, so the manifest holds fourteen entries and none of them is a chapter body reached by paging. `test/fixtures/fanmtl_manifest_test.dart` asserts each of the three is *either* resolved with a real URL *or* named here — **never closed by silence**, because a silence nobody wrote down is indistinguishable from an oversight. ⚠️ **This is a GAP, NOT A FINDING THAT THEY DO NOT EXIST.** The pager for a chapter list was observed (`/list/<tag>/<sort>-<page>.html`, 0-based) and `novel-detail` declares `data-chapters="716"` against 716 distinct chapter hrefs, so multipage chapter bodies are plausible and simply were not captured. Closing this means capturing `chapter-multipage-p1` and `chapter-multipage-p2` from a fiction whose chapter list spans pages, or recording that no v1 fiction does.
  8. **B22's discriminator is satisfiable here.** FanMTL's own failure page carries the explicit string *"No relevant content found"*, which is a real site-supplied empty-result signal — exactly the distinction B22 requires between "genuinely nothing" and "could not read". It is reachable even though the search itself is not. **Do not read it as "no results" on a browse page** — it lives on the search failure page, so it discriminates for search calls only; for genre browsing, an empty tag page is judged by page shape (no novel rows), not by this string.

- **Pending promotion**: `04-html-to-markdown.md` §The converter is ours §Required behaviour — the `<br><br>` → paragraph rule and the `.chapter-content` selector are **general** enough to promote. Site-specific selectors stay here.

### Royal Road — https://www.royalroad.com

- **Permission**: permitted for a user-installed reader. Its `robots.txt` (`User-agent: *`) disallows only `/fiction/chapter/*/vote`, `/fictions/review/`, `/forums/report/*`, `/report/*` — voting, reviews and reports. **Fiction listings and chapter content are not disallowed.** The AI-training crawlers (GPTBot, CCBot, Google-Extended, ClaudeBot, Bytespider, …) are disallowed in separate blocks; that is a training-crawler rule, not a reader rule, and does not apply to a client the user installed.
- **Status**: **in v1** (ADR-013), second source, an adapter over the platform contract.
- **Scope**: English web novels. Verified live: catalogue at `/fictions/best-rated`, `/fictions/latest-updates`; fiction page at `/fiction/<id>/<slug>`; chapter at `/fiction/<id>/<slug>/chapter/<chapterId>/<slug>`. **Pagination was "to be discovered during implementation" as of 2026-10-02 and HAS NOW BEEN MEASURED** — see *Royal Road — the URLs moved, measured 2026-10-03* below, which supersedes this line. Catalogue pagination is `?page=N`, **1-based**; the fiction page's pager is `?reviews=N`, and the **chapter table is not paginated at all**.
- **Cloudflare: present, not challenging.** Measured 2026-10-02 on the home page, the best-rated catalogue, and a real chapter page (`/fiction/21220/mother-of-learning/chapter/301778/1-good-morning-brother`): **200 with no `cf-mitigated` header and no Turnstile markup, under both an honest and a browser-like User-Agent.** No bypass needed.
- **Last verified**: 2026-10-02
- **Quirks**: two, both measured live on 2026-10-02 while writing the `6-1` plan, and **both are load-bearing** rather than incidental:

  | Finding | Where | Why it matters more than a quirk |
  |---|---|---|
  | **`table#chapters` carries `data-chapters`** | the fiction page's chapter table | **This makes B9 mechanically checkable instead of asserted.** B9 requires the chapter list to be the site's complete order; the site publishes its own count, so "40 rows parsed but the attribute says 716" is a detectable truncation rather than something a reviewer has to notice. This is the only source so far that offers its own completeness witness — FanMTL does not. **Re-measured 2026-10-03: `data-chapters="716"`, exactly 716 rows, 716 distinct chapter hrefs.** The `109` above was from a smaller fiction on 2026-10-02; the *mechanism* is confirmed and the number was always per-fiction |
  | ~~**A `200` with zero rows carries the site's own empty signal**~~ | — | **⚠️ RETRACTED 2026-10-03 by measurement.** The selector `div.fiction-list#result > div.text-center > h3` with text `There is nothing here :(` matches **nothing** on the live site, and a zero-row catalogue carries no marker of any kind. The claim was recorded from documentation, never from a capture. See *Royal Road — the URLs moved* below, and `test/fixtures/sources/royalroad/empty-signal.json` for what the site does publish |

  **Promotion**: `18-external-contracts.md` because they are per-site facts that will
  change without notice, and a selector is not the place to record why a selector
  exists. The **cross-site rule** they add: *a source must record whether the site
  publishes its own empty-result signal, and must not infer one from an empty parse.*
  That rule is what `0-2` measured for Royal Road
  (`test/fixtures/sources/royalroad/empty-signal.json`) and what `6-11` will measure for
  search reachability.
- **Pending promotion**: the two rules above, once `2-1`/`6-1` land and `0-2`/`6-11` report.

### Novel Fire — https://novelfire.net

- **Permission**: unknown. **Blocked on the project owner confirming terms** (Q-004).
- **⚠️ `supportsSearch`: STILL UNMEASURED, and the reason changed on 2026-10-03.**
  `6-11` fetched the site's own search with the honest UA on 2026-10-03 and got, for
  **every** path tried — `/`, `/search`, `/search?keywords=litrpg` —

  | Path | Result |
  |---|---|
  | `https://novelfire.net/` | **403**, `Just a moment...`, `challenges.cloudflare.com` in `script-src` |
  | `https://novelfire.net/search` | **403**, same interstitial |
  | `https://novelfire.net/search?keywords=litrpg` | **403**, same interstitial, 5 420 bytes |

  ⚠️ **A challenge is NOT `supportsSearch = false`.** Rule 5a says a 404, a
  meta-refresh, a timeout or an empty page means the endpoint is not there. A **403
  interstitial** is none of those: the site declined to be read at all, so there is no
  evidence about search. Writing `false` from this would be exactly the guess ADR-015
  exists to forbid, and it would permanently disable a search box for a site nobody
  managed to look at. The honest entry stays **unmeasured**, and ADR-014's 2026-10-02
  row ("200 with an honest UA") is now stale for this site — the same day FanMTL moved
  to 403.

- **Cloudflare: present — and impersonating a browser makes it WORSE.** Measured 2026-10-02 against the home page:

  | User-Agent | Result |
  |---|---|
  | `Mozilla/5.0 (compatible; LumenTale/0.1; personal reader)` | **200**, full page, no challenge |
  | Chrome/Android browser string | **403**, `cf-mitigated: challenge`, Turnstile markup |

  The honest client is let through; the one pretending to be a browser is challenged. This is the empirical justification for `17-security.md` rule 5, and the reason Mihon's WebView bypass must **not** be ported here. See ADR-014.
- **Domain volatility — confirmed.** The site has moved across domains repeatedly. On 2026-10-02: `novelfire.net` → HTTP 200, `novelfire.xyz` → HTTP 200, and `novelfire.bz`, `novelfire.one`, `novelfire.la`, `novelfire.info` → **NXDOMAIN**. A domain given in a URL, an issue, or an old document is not evidence the site is there.
- **Status**: **in v1** (ADR-013), implemented as an adapter over the platform contract. Still blocked on Q-004.
- **Last verified**: 2026-10-02
- **Quirks**: domain churn (above). Cloudflare that punishes browser impersonation (above). Aggregator — chapter pages may be proxied from origin sites, so chapter HTML may differ per fiction and the converter's per-source overrides will earn their keep here.
- **Pending promotion**: `17-security.md` rule 5 — the Novel Fire measurement is general enough to become the worked example there.
---

## Re-measurement 2026-10-03 — both v1 sites moved, and Wave 0 is blocked

Measured from the development machine with the **honest** User-Agent
`LumenTale/0.1.0 (personal reader)` — the one ADR-014 measured as correct, and the
one `17-security.md` rule 5 requires. No browser impersonation was tried, and none
will be.

| Site | Path | Result |
|---|---|---|
| FanMTL | `/` | **403** — Cloudflare interstitial, `challenges.cloudflare.com` in `script-src` |
| FanMTL | `/robots.txt` | **403** |
| FanMTL | `/list/xianxia/all-lastdotime-0.html` | **403** — the catalogue path this file documents |
| FanMTL | `/browsetags/` | **403** — the one path this file says works |
| FanMTL | `/browsetags/all.html` | **403** |
| Royal Road | `/` | **302** → `/home`, then **200**, 118 173 bytes, real markup |
| Royal Road | `/fiction/1` | **404**, 0 novel rows |
| Royal Road | `/fictions/ratings` | **404**, 0 rows |
| Royal Road | `/fiction/best-rated` | **404**, 0 rows |
| Royal Road | `/fiction/updates` | **404**, 0 rows |
| Royal Road | `/fiction/ratings` | **404**, 0 rows |

**What this invalidates, precisely.** ADR-014's measurement table records FanMTL and
Royal Road as *"200, no challenge"* and *"200, no `cf-mitigated`, no Turnstile"*
respectively, measured 2026-10-02. One day later FanMTL challenges an honest client on
every path, and Royal Road's catalogue and chapter paths 404. **The site changed; the
client did not.**

**What it does not change, and must not be read as changing:**

- **No bypass is warranted or wanted.** ADR-014 already rejected Mihon's WebView
  technique on measurement, and C2's no-telemetry constraint plus `17-security.md`
  rule 7 put a challenge-solving WebView out of scope independently. A Cloudflare
  interstitial is the site declining; the correct response is to record it, not to
  defeat it.
- **The selectors in this file are not thereby wrong.** `div.fiction-list` and
  `.chapter-content` were verified against real pages on 2026-10-02. They are
  unreachable *now*. That is a reachability fact, not a markup fact, and the two must
  not be conflated — a selector rewritten to fit an interstitial would be a selector
  written against an error page.

**Consequence for the plan.** `roadmap.md` § 2 puts fixture capture in **Wave 0**,
before any feature code, precisely so HTML surprises land early. Slice `0-1` cannot
capture a catalogue page or a chapter body for **either** v1 site as measured from the
development machine. `0-1` therefore cannot proceed to its own § 11, and `0-2`
through `0-4` depend on its fixtures.

**Recorded as F-012 (FanMTL 403) and F-013 (Royal Road 404).** The decision on how to
capture is the owner's; the cheapest honest option is capturing from the owner's own
phone, which already carries whatever cookie the challenge requires, and which is the
same method ADR-014's own measurement used.

⚠️ **F-012 IS RESOLVED — see § FanMTL — re-measured 2026-10-04, at the end of this file.**
The **same honest User-Agent**, one day later, received **200 on every documented FanMTL
path**. Nothing was bypassed, no browser was impersonated and no cookie was carried: the
challenge simply was not being served then. **F-013 is resolved too** — Royal Road's
catalogue and chapter paths answer 200, and `0-3` froze nine fixtures from them.


## Royal Road — the URLs moved, measured 2026-10-03

Supersedes the URL claims in the section above. Every one of these was **fetched**, and
the `?page=N` form is what the site's own navigation uses.

| What | Live URL (2026-10-03) |
|---|---|
| Entry point | `/` **302** → `/home` (200, 118 173 bytes) |
| Popular catalogue, page 1 | `/fictions/active-popular` |
| Popular catalogue, page N | `/fictions/active-popular?page=N` — **a query, not a path segment** |
| Other catalogue tabs | `/fictions/best-rated`, `/fictions/latest-updates`, `/fictions/rising-stars`, `/fictions/trending`, `/fictions/weekly-popular`, `/fictions/complete`, `/fictions/new`, `/fictions/active-popular` |
| Search | `/fictions/search` |
| Novel detail | `/fiction/<id>/<slug>` |
| **Chapter** | `/fiction/<id>/<slug>/chapter/<n>/<chapter-slug>` — **five segments** |

**The three-segment chapter form 404s.** `/fiction/33844/the-runesmith/chapter/526587`
returns `Not Found | Royal Road`. The fifth segment is the chapter's own slug, and the
site publishes it in `tr[data-url]`. **A chapter URL that 404s is indistinguishable from
a chapter that does not exist**, which is B22's third state — so the fifth segment is
part of the contract, not a nicety.

**The body container is `div.chapter-inner.chapter-content`.** An exact
`class="chapter-content"` match finds **nothing**: measured zero paragraphs on a page
that has 106 of them. The class sits on a div that *also* carries `chapter-inner`.

**⚠️ B22's third state has NO site-supplied marker on the BROWSE side of this site.**
Measured: a zero-row catalogue (`/fictions/search?tags_add=99nonexistenttag`, HTTP 200,
239 765 bytes) carries no "nothing here", no "no results", no "no fictions". **This
contradicts what the section above anticipated** — it recorded that this site's empty
catalogue volunteers an empty marker. It does not. `2-1` must therefore distinguish
*"could not read"* from *"no results"* by **page shape** (rows present, container
present), never by a marker string, because there is no marker to find. A marker-based
implementation would classify every empty catalogue as "no results", including one that
failed to parse.

---

## Royal Road — the catalogue row's anatomy, re-derived from the frozen fixtures 2026-10-04

**Measured, not recalled.** Every selector below was found by reading
`test/fixtures/sources/royalroad/catalogue-active-popular-page1.html`, and the counts were
checked against that fixture's own `manifest.json` (`novelRowsExact: 20` — **20 rows, 20
distinct `/fiction/<id>` hrefs, and page 0 shares none with page 1**).

| Fact | Selector / value | Why it matters more than a selector |
|---|---|---|
| **The catalogue row carries NO author** | a row contains cover `img`, `h2.fiction-title > a`, the tags block, `div.row.stats` and `div#description-<id>` — and **no author element of any kind** | `Novel.author` is `String?` and **stays `null` after a catalogue read**. A source that filled it from the novel's *slug* or from the title would be fabricating B10 verbatim site text. The author arrives only from the **detail** page |
| **The author lives on the detail page, under `/profile/`, not `/author/`** | `div.fic-title h4 span a[href^="/profile/"]` → `Kuropon` | `/author/<id>` is the shape every other site uses and **matches nothing here**. A source written from the habit would parse `null` and, under `ZeroItemsPolicy.zeroIsBroken`, report a healthy novel as a broken one |
| **The novel title is `h1.font-white`** | `The Runesmith` | `og:title` is **absent**, so there is no metadata fallback |
| **The cover's `alt` is the novel title, not the author's** | `alt="The Runesmith"` | So `alt` cannot stand in for a missing author — a shortcut that looks reasonable and is wrong |
| **The chapter table is complete and self-reporting** | `table#chapters[data-chapters="716"]`, and **716** `tr[data-url]` rows | B9's completeness witness. This is the only source so far that publishes its own count |
| **`tr[data-url]` carries the FULL five-segment chapter URL** | `/fiction/<id>/<slug>/chapter/<n>/<chapter-slug>` | The **fifth segment is present in the row**, so a source never has to construct it — and constructing it is what produces the 404 that B22's third state cannot distinguish from a missing chapter |
| **Stats live in `div.row.stats` as `<i class="fa fa-…">` + `<span>`** | `fa-users` → Followers · `fa-star` → Rating (title attribute, **not** the span) · `fa-book` → Pages · `fa-eye` → Views · `fa-list` → Chapters · `fa-calendar` → `time[unixtime]` | **The rating's number is in the `title` attribute of the star `span`, not in its text.** `fa-star`'s text is empty, so a source reading the span reports a rating of `0` for a fiction rated `4.73` |
| **`tr.fiction-list-item` matches ZERO and the page has no `<table>` at all** | `div.fiction-list#result > div.fiction-list-item.row` | The cross-site shape every other source uses is the one that does not match here |

**The promotion target this satisfies**: every selector `2-1` writes must be traceable to a
frozen fixture rather than to a habit borrowed from another site. The two rows above — the
absent author and the `/profile/`-not-`/author/` split — are the ones a habit would have
got wrong, and neither is discoverable without reading the capture.

## Royal Road — the chapter table is ordered by PUBLICATION, not by number, measured 2026-10-04

**Found because a test failed with the opposite expectation**, which is the only reason it
is worth writing down. The Runesmith capture's first three `tr[data-url]` numbers are
**`526587`, `568159`, `520102`** — measured, and **not ascending**.

Royal Road orders `table#chapters` by publication date. A source that sorted by chapter
number, or renumbered rows `1, 2, 3…`, would produce an order the site never published —
and **every chapter would still be present**, so nothing would look wrong. B9 requires the
site's own complete order; this is the case where getting it wrong is invisible.

The capture's **first row is a glossary** (`data-content="0"`), so renumbering would also
silently claim the glossary is chapter 1.

**The cross-site rule this adds:** *a chapter list is the site's order, and the site may
order it by something other than the number in the URL.* `number` is a **sortable hint**,
never an index to assign from. A row now asserts the first three numbers are exactly
`[526587, 568159, 520102]` **and that they are not ascending**, so a future change in the
site's order fails a test that says so rather than passing silently.

## Royal Road — the search side DOES have an empty marker, measured 2026-10-03 (`6-11`)

**This is the other half of the row above, and the two must not be merged.** The
measurement above is about the **browse** side. `6-11` fetched the site's own **search**
with the honest UA and the answer is the opposite.

| Path tried (honest UA, `curl -L`, no session) | Result |
|---|---|
| `/fictions/search?title=litrpg` | **200**, 250 980 bytes, **20 rows**, titles carrying "LitRPG" |
| `/fictions/search?title=system+fantasy` | **200**, 251 066 bytes, **20 rows**, titles carrying "System Fantasy" / "Progression" |
| `/fictions/search?title=zzzqqqxxnotanovelname` | **200**, 97 498 bytes, **0 rows**, and the site's own marker |

**`supportsSearch = true` for Royal Road.** ADR-015's criterion is *"results a reader
would call useful"*, and a count of 20 is not that — so the **titles** were read: all
ten sampled titles carry the queried words. The control query is what makes that mean
anything; without it, "20 rows for `litrpg`" and "the page always shows 20 rows" are the
same observation.

**The zero-row search carries the site's own marker:**

```
div.search-item.clearfix > h4.font-red-sunglo
  "No results matching these criteria were found"
```

Present **once** on the zero-row page, **zero** times on either 20-row page, and in
**visible text**. A marker that appears everywhere discriminates nothing, so it is
recorded on both sides and re-derived from the capture by
`test/fixtures/royalroad_search_test.dart`.

⚠️ **This row corrects a claim made earlier the same day.** The first reading of
`6-11`'s recorded verdict said the marker did **not** exist — and it listed
`"No results"` among the markers it had checked while asserting that no checked marker
was present. The list contained its own answer. The assertion was written from the
conclusion, and it failed on the first run against the page it was written from. See
`SESSION_LOG.md` session 12.

**Consequence, and it is per stage, per source.** `ReadStage.searchResults` becomes
`zeroIsGenuine` for Royal Road and `BrowseEmpty` becomes **reachable there, on search
only**. The browse side stays `zeroIsBroken`: a zero-row catalogue page carries no
marker, so it is *reported* rather than shown as an empty page. **One stage becoming
genuine must not become a policy on all seven**, which is precisely why
`kZeroItemsPolicyByStage` is declared per call by the source that made the request.

**What was NOT measured**, and is therefore not claimed: POST vs GET (the GET works, and
rule 5a asks about the endpoint); author search, tag search and combined filters; and
rate limiting — finding out whether repeated searches earn a 429 is not something to
find out by hammering.

**Frozen capture**: `test/fixtures/sources/royalroad/search/` (three pages, 596 KB) and
`verdict.json`. The limit of a frozen fixture is written into the file: the test
re-derives the verdict **from the capture**, so a change in the capture is caught — and a
change in the **live** site is not, because nothing re-fetches.

**Pagination is real and checkable.** `/fictions/active-popular` and `?page=2` return
byte-different pages with 20 distinct fiction rows each — verified by hashing the sorted
`/fiction/<id>` hrefs of each.

**`table#chapters` carries `data-chapters`, and it is exact.** The detail page for
*The Runesmith* declares `data-chapters="716"` and lists 716 `tr.chapter-row` elements.
This is the site's own completeness witness, so a truncation is **detectable** rather
than something a reviewer has to notice.

**robots.txt, honoured and captured.** The `User-agent: *` block disallows four paths —
`/fiction/chapter/*/vote`, `/fictions/review/`, `/forums/report/*`, `/report/*` — and
**none of the paths captured here**. Fourteen named agents (GPTBot, CCBot, ClaudeBot,
Google-Extended, Applebot-Extended, Amazonbot, Bytespider, meta-externalagent, …) are
`Disallow: /` wholesale; we are among none of them and impersonate none of them, per
`17-security.md` rule 5 and ADR-014.

## Royal Road — pagination, measured 2026-10-03 (`0-3`)

Supersedes *"Pagination and filter parameters to be discovered during implementation"*.
Nine fixtures frozen; `test/fixtures/royalroad_pagination_test.dart` re-derives every
number below from them on each run, so a re-capture that changes one fails the suite
instead of quietly invalidating this section.

| List | Paged? | Parameter | Marker class | Window |
|---|---|---|---|---|
| `/fictions/<sort>` | **yes** | **`?page=N`, 1-based** (`page=1` is the *first* page) | `<li class="page-active">` — **not** `active` | 5 numbered + `Next ›` + `Last ›` |
| `/fiction/<id>/<slug>` reviews tab | **yes** | `?reviews=N`, 1-based | same | 5 + `Next` + `Last` (55 pages) |
| **`/fiction/<id>/<slug>` chapter table** | **NO** | — | — | **716 rows, all of them, `data-chapters="716"`** |

**The chapter list is whole on one page.** This is the single most useful thing `0-3`
found: completeness is not a suspicion, it is **arithmetic**. A parse yielding 400 of
716 chapters is detectably incomplete, and no pagination logic is needed to know.

**⚠️ Three things a probe written from the prose gets wrong, all measured:**

| Written as | Actually | Consequence of trusting the prose |
|---|---|---|
| catalogue rows are `tr.fiction-list-item` | `div.fiction-list-item.row`, **20/page**, and the page has **no `<table>` at all** | a probe reports 0 rows, calls the page empty, and hands `0-2` an "absent" verdict for a full catalogue |
| numbered anchors carry an offset | there is **no offset**; the parameter is `?page=N` | `?page=` is never found, pagination reads as absent, and the source silently reads page 1 forever |
| the current page is `li.active` | `li.page-active` | every page reads as page 1 |

**`javascript:;` anchors exist on the page — outside `ul.pagination`.** A whole-page
anchor sweep counts them as pages. Anchors must be scoped to `ul.pagination`; inside
that container there are none.

**⚠️ `0-3` § 3.2.1's confirmation rule is WRONG for this site, and the deviation is
recorded rather than hidden.** The rule is `secondPageItemCount > firstPageItemCount`.
Royal Road serves **20 items on every listing page**, so the rule is false on a site
whose pagination demonstrably works: page 1 holds 20 novels, page 2 holds 20
*different* novels (verified by hashing sorted `/fiction/<id>` hrefs). Applying the rule
literally would record working pagination as unconfirmed, and `2-1` would then treat
`?page=N` as decoration — a failure that looks like "the source returned everything"
while dropping 99 % of the catalogue.

**Confirmation is therefore a set comparison, not a count comparison**: two pages holding
different items confirm pagination. Both counts are still recorded beside it so a
reader can check the reasoning.

**Promotion**: `0-3`'s finding, verified against fixtures, that *a probe must scope its
anchors to the pagination container* and *a fixed page size is the normal case, not
evidence of absence*. The second is cross-site and belongs in the source contract: a
source that treats "the same number of items" as "there is no page 2" will work on one
site and fail on every other.

---

## FanMTL — re-measured 2026-10-04: reachable, and fourteen fixtures frozen (`0-1`)

**Measured, not recalled.** Every number below was produced by reading the frozen bytes in
`test/fixtures/sources/fanmtl/` — and `test/fixtures/fanmtl_manifest_test.dart`
re-derives the counts on every run, so a re-capture that changes one fails the suite
instead of quietly invalidating this section.

**The honest User-Agent worked, and that is the whole finding.** `LumenTale/0.1.0
(personal reader)` — ADR-014's measured-correct client, never a browser's — received
**200 on every documented path** on 2026-10-04. Twenty-four hours earlier the same client
received **403 with a Cloudflare interstitial on every one of them**. No bypass was
attempted, none is wanted, and none would have been legal under ADR-014: *the site was
declining on that day and stopped declining on this one.* A Cloudflare challenge is
therefore **not** a stable property of a site, and a source written from one day's 403 is
written from a measurement that has already expired.

| Path | 2026-10-03 | 2026-10-04 |
|---|---|---|
| `/robots.txt` | 403 | **200**, 187 bytes |
| `/browsetags/` | 403 | **200**, 17,712 bytes |
| `/list/xianxia/all-lastdotime-0.html` | 403 | **200**, 40,672 bytes |
| `/novel/ke383028.html` | not measured | **200**, 45,881 bytes |
| `/novel/ke383028_1.html` | not measured | **200**, 23,931 bytes |
| `/e/search/index.php` | not measured | **404**, 2,954 bytes — *the same 404 quirk 6 records* |

### Permission, re-read 2026-10-04 — and one path that is easy to get wrong

`robots.txt` is 12 lines. The `User-agent: *` block allows everything except **six**
EmpireCMS admin prefixes: `/d/`, `/e/class/`, `/e/config/`, `/e/data/`, `/e/enews/`,
`/e/update/`, plus `Allow: /ads.txt`.

⚠️ **`/e/extend/` is NOT among them, and it is the chapter list.** The chapter-list pager
lives at `/e/extend/fy.php?page=N&wjm=<novelId>`, which a reader who only memorised the
six names would plausibly refuse — or, worse, allow without noticing they had not
checked. `/list/`, `/novel/` and `/browsetags/` are permitted for the same reason.
**Promotion**: `17-security.md` rule 5 — *read robots.txt, do not recall it* — with this
as the worked example of a permitted path hiding inside a namespace whose siblings are
all forbidden.

### The three "à découvrir" lines of `0-1` § 3.3, closed

§ 7 forbids manufacturing a fixture for a line the documents cannot answer. Each is closed
here by a real href read off a real page, or by a measured negative — never by silence.

| Line | Outcome | Evidence |
|---|---|---|
| `catalogue-all-page0` | **RESOLVED** | `/browsetags/` publishes the `all` pseudo-entry as `/list/all/all-newstime-0.html`. Followed, not constructed. Note the sort segment differs from a genre page's: `all`+`newstime`, where a genre page is `<genre>`+`lastdotime`. |
| `chapter-list-page1` | **RESOLVED** | `novel-detail.html`'s pager publishes `/e/extend/fy.php?page=N&wjm=ke383028`, **0-based**, 19 pages. Page 0 holds chapters 1-100 — **the same rows the novel page already shows**. |
| `chapter-multipage-p1` / `-p2` | **NOT FOUND** | See E3 below. |

### E3 — a chapter is NEVER split across pages on this site

`chapter-prose.html` carries **zero** occurrences of `page_next`, `下一页`, `part_` or any
other continuation affordance; its only navigation is `div.chapternav` with prev/next
**chapter** links. Fifteen chapters across the novel were sampled and every one of them is
a single page.

**So E3 does not apply to FanMTL, and `2-1` has nothing to write for it.** `B8` (join the
pages in order) is a contract a source implements *if the site has pages to join*; here it
has none, and a source that manufactures a second fetch per chapter would be issuing a
request for a document that does not exist. **This is a fact about the site, not a missing
fixture** — the line is closed *by a finding*, which is what § 7 asks for.

### E22 — there is NO Extra, Omake or end note on this site either

**Measured negative, exhaustively.** All **1,966** chapter titles of `ke383028` were read,
across all 19 chapter-list pages, and **not one** is an Extra, Omake, side story, volume
note, prologue, epilogue, afterword or announcement — checked in English *and* in Chinese
(`番外`, `外传`, `后记`, `尾声`, `感言`, `公告`, `序章`, `楔子`). Every one of the 1,919
distinct titles this site publishes for that novel begins with `Chapter <n>` or
`Chapter <n>:`. Four other novels' full or final chapter lists (`kks45522`, `kks45517`,
`kks38611`, `kks34257`, `kks33392`) were checked the same way, with the same result.

⚠️ **Fifteen chapter bodies were measured: 22,837 to 24,892 bytes.** The *shortest* chapter
this novel publishes is 22 KB. FanMTL publishes only numbered chapters of a full length, so
**E22's trigger never fires on this source**.

**What `0-1` froze, and why it is not what § 3.3 asked for.** § 3.3 asks for `chapter-short`
to be *"an Extra / Omake / end note, chosen from the real list"*, and § 10 asks its notes to
name the exact title of a chapter of that kind. **Neither is obtainable from this site**, and
inventing one would be precisely the fabrication § 7 forbids. So `chapter-short` is the
**shortest chapter the captured novel actually publishes** — `Chapter 1960 Titans (Part 1)`,
named exactly, from the real list — and `chapter-long` is the longest of the fifteen
measured. The pair is a genuine threshold control in the only direction the site allows:
**nothing FanMTL publishes is anywhere near E18's 100-character floor**, so a source that
discards chapters under 100 characters discards nothing on this source, and that is now a
measured statement rather than an assumption.

⚠️ **Promotion**: `E22`'s negative control is not portable. On Royal Road the equivalent
control is a real short chapter; on FanMTL it is the *shortest* chapter, which is 200× the
threshold. A source-level "minimum length" guard therefore needs a fixture that is genuinely
below the floor before it can be claimed to have one, and **neither v1 site currently
provides that fixture**. Recorded as an open question for `2-2`.

### E4 — the plan's substitution target does not exist on a catalogue page

`0-1` § 3.2 builds the SC-6 artefact by copying `catalogue-genre-page0.html` and renaming
`chapter-content` → `chapter-content-v2`. **Measured 2026-10-04: `chapter-content` occurs
ZERO times in any list, catalogue, novel-detail or chapter-list page.** It exists on
chapter pages only, exactly once each.

Applied to the plan's own source file the substitution has no target, so the artefact would
have been a byte-identical copy of a healthy page — and the "zero novel rows" it exists to
demonstrate would have been zero *before* the edit. **The container an adapter actually
reads on a catalogue page is `div.novel-item`, 30 of them**, so that is the pair: 30
substitutions, 40,672 → 40,762 bytes, and `novel-item-v2` → `novel-item` restores the source
byte for byte. § 3.2's *mechanism* is unchanged and its three acceptance criteria are met
against the class that measurement says is the real one.

**Promotion**: `04-html-to-markdown.md` and `03-source-system.md` — *a selector is a claim
about markup, and the markup is the only evidence*. § 3.2 was written before any FanMTL page
had been captured and asserted a class name from a quirk list; the quirk list was right about
*chapter* pages and had been generalised to *catalogue* pages without a measurement.

### Two more measured facts a probe written from the prose gets wrong

| Written as | Actually | Consequence of trusting the prose |
|---|---|---|
| the chapter list is on the novel page | it is on the novel page **and** on `/e/extend/fy.php?page=0` — the same 100 rows twice | a source reading both counts 200 chapters where the novel has 1,966, and 100 of them twice |
| the novel page publishes a chapter count | it publishes **nothing**; 1,966 is known only by paging to the end | there is no `data-chapters="716"` equivalent here, so completeness is arithmetic against the *last page*, never against a self-reported total |
| `?page=999` past the end is an error | it returns **200** and 1,228 bytes holding only a pager | "page 20 of 19" reads as *an empty chapter list* rather than as a failure — B22's forbidden answer, reached by asking for a page that was never there |
| chapter-list hrefs are the list | every pager page also carries a `Latest Release:` link to the novel's **newest** chapter | reading hrefs instead of rows finds chapter 1966 on all 19 pages, and a disjointness check fails on a link that is not a row |

**Promotion**: `0-3`'s finding, independently arrived at on the second site, that *a probe
must read the row, not every href on the page*. It is now cross-site and belongs in the
source contract.

### Rate limit observed

None hit. Twenty-four requests across the capture and the discovery probes, 3–4 seconds
apart, all 200 (or the documented 404), no `429`, no `Retry-After`. `tool/capture.py` holds
the fixed delay and the `429`/`403`/`5xx` branches so the next capture is not a bare `curl`.
