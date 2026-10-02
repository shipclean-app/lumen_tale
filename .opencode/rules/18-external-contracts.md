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
| Royal Road | **unknown — not yet checked** | Must be fetched and judged before any claim. |
| Novel Fire | **unknown — not yet checked** | Blocked additionally by Q-004. |

Until both remaining sites are measured, v1 can claim **genre browsing for all three** and **search for none of them**. That is a correct v1, not a gap: it is what the contract promises when `supportsSearch` is false.

---

## Recorded sites

### FanMTL — https://www.fanmtl.com — **FIRST SOURCE**

- **Permission**: permitted. Its `robots.txt` is an **EmpireCMS** file. The `User-agent: *` block disallows exactly seven paths — `/d/`, `/e/class/`, `/e/config/`, `/e/data/`, `/e/enews/`, `/e/update/` (plus `Allow: /ads.txt`). **Novel and chapter content under `/novel/` and `/list/` is not among them.** Note precisely which paths are listed: `/e/search/` is **not** disallowed, so search is not robots-blocked here — see quirk 6. The site also publishes `/terms-of-service.html` and `/dmca.html`; re-read both before shipping. Re-check `robots.txt` on every release and honour a change.
- **Scope**: fan-fiction / web novels. Genre taxonomy is Chinese-derived. **Eight genres, not nine**: `xianxia`, `xuanhuan`, `shounen`, `shoujo`, `romance`, `contemporary-romance`, `action`, `wuxia`. An earlier note here said nine — it had counted the `all` pseudo-entry as a genre, which it is not, and a screen cannot render nine labels when the site supplies eight.
- **Last verified**: 2026-10-02
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
  7. **B22's discriminator is satisfiable here.** FanMTL's own failure page carries the explicit string *"No relevant content found"*, which is a real site-supplied empty-result signal — exactly the distinction B22 requires between "genuinely nothing" and "could not read". It is reachable even though the search itself is not. **Do not read it as "no results" on a browse page** — it lives on the search failure page, so it discriminates for search calls only; for genre browsing, an empty tag page is judged by page shape (no novel rows), not by this string.

- **Pending promotion**: `04-html-to-markdown.md` §The converter is ours §Required behaviour — the `<br><br>` → paragraph rule and the `.chapter-content` selector are **general** enough to promote. Site-specific selectors stay here.

### Royal Road — https://www.royalroad.com

- **Permission**: permitted for a user-installed reader. Its `robots.txt` (`User-agent: *`) disallows only `/fiction/chapter/*/vote`, `/fictions/review/`, `/forums/report/*`, `/report/*` — voting, reviews and reports. **Fiction listings and chapter content are not disallowed.** The AI-training crawlers (GPTBot, CCBot, Google-Extended, ClaudeBot, Bytespider, …) are disallowed in separate blocks; that is a training-crawler rule, not a reader rule, and does not apply to a client the user installed.
- **Status**: **in v1** (ADR-013), second source, an adapter over the platform contract.
- **Scope**: English web novels. Verified live: catalogue at `/fictions/best-rated`, `/fictions/latest-updates`; fiction page at `/fiction/<id>/<slug>`; chapter at `/fiction/<id>/<slug>/chapter/<chapterId>/<slug>`. Pagination and filter parameters to be discovered during implementation.
- **Cloudflare: present, not challenging.** Measured 2026-10-02 on the home page, the best-rated catalogue, and a real chapter page (`/fiction/21220/mother-of-learning/chapter/301778/1-good-morning-brother`): **200 with no `cf-mitigated` header and no Turnstile markup, under both an honest and a browser-like User-Agent.** No bypass needed.
- **Last verified**: 2026-10-02
- **Quirks**: two, both measured live on 2026-10-02 while writing the `6-1` plan, and **both are load-bearing** rather than incidental:

  | Finding | Where | Why it matters more than a quirk |
  |---|---|---|
  | **`table#chapters` carries `data-chapters="109"`** | the fiction page's chapter table | **This makes B9 mechanically checkable instead of asserted.** B9 requires the chapter list to be the site's complete order; the site publishes its own count, so "40 rows parsed but the attribute says 109" is a detectable truncation rather than something a reviewer has to notice. This is the only source so far that offers its own completeness witness — FanMTL does not |
  | **A `200` with zero rows carries the site's own empty signal** | `div.fiction-list#result > div.text-center > h3`, text `There is nothing here :(` | **This is what makes B22's third state available for Royal Road.** B22 requires *could not read* and *no results* to be different screens, and a site that volunteers an empty-result marker is the only way to tell them apart without guessing. FanMTL's equivalent is unmeasured — that is `0-2`'s whole job |

  **Promotion**: both belong in `18-external-contracts.md` because they are per-site facts that will change without notice, and a selector is not the place to record why a selector exists. The **cross-site rule** they add: *a source must record whether the site publishes its own empty-result signal, and must not infer one from an empty parse.* That rule is what `0-2` is measuring for FanMTL and what `6-11` will measure for search reachability.
- **Pending promotion**: the two rules above, once `2-1`/`6-1` land and `0-2`/`6-11` report.

### Novel Fire — https://novelfire.net

- **Permission**: unknown. **Blocked on the project owner confirming terms** (Q-004).
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