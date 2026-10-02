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

Two sites were selected for v1 on 2026-10-02. **FanMTL** is now the **first** source. Royal Road and Novel Fire status: see Q-004 / the ADR-011 note below.

---

## Recorded sites

### FanMTL — https://www.fanmtl.com — **FIRST SOURCE**

- **Permission**: permitted. Its `robots.txt` is an **EmpireCMS** file whose `User-agent: *` block disallows only `/d/`, `/e/class/`, `/e/config/`, `/e/data/`, `/e/enews/`, `/e/update/` — CMS and admin directories. **Novel and chapter content live under `/novel/` and `/list/`, neither of which is disallowed.** The site also publishes `/terms-of-service.html` and `/dmca.html`; re-read both before shipping. Re-check `robots.txt` on every release and honour a change.
- **Cloudflare: present, and not blocking.** Every response carried `server: cloudflare` and a `cf-ray` header — Cloudflare **is** in front of this site. But with an honest, self-identifying User-Agent (`Mozilla/5.0 (compatible; LumenTale/0.1; personal reader)`) no challenge or block was served on any request, on the home page, the novel page or a chapter page. `17-security.md` rule 5 stands: identify honestly, and if Cloudflare ever starts challenging us, that is a decision by the site — do not escalate to browser impersonation, and do **not** port Mihon's WebView bypass (ADR-014).
- **Scope**: fan-fiction / web novels. Genre taxonomy is Chinese-derived: `xianxia`, `xuanhuan`, `shounen`, `shoujo`, `romance`, `contemporary-romance`, `action`.
- **Last verified**: 2026-10-02
- **URL structure** (verified by fetching, not guessed):

  | Purpose | Pattern | Example |
  |---|---|---|
  | Novel detail + chapter list | `/novel/<id>.html` | `/novel/ke383028.html` |
  | Chapter body | `/novel/<id>_<n>.html` | `/novel/ke383028_1.html` |
  | Catalogue / tag / pagination | `/list/<tag>/<sort>-<page>.html` | `/list/xianxia/all-lastdotime-0.html` |
  | Latest chapters | `/updates/` | |
  | Search | `/search.html` | |

  The trailing integer in `/list/...` is the **0-based page number** — note this differs from the 1-based `page` argument in the `Source` contract. Convert at the boundary.

- **Quirks** — all confirmed against live HTML, all of which the implementation must handle:

  1. **Prose is NOT in `<p>` elements.** A chapter contains **0 `<p>` tags**; paragraphs are bare text nodes separated by `<br><br>`. Our converter's paragraph rule must therefore be *"`br br` → paragraph break"*, not only *"`<p>` → paragraph"*. Getting this wrong turns a whole chapter into one run-on block, and it will still look superficially correct in a smoke test.
  2. **`#chapter-article` contains the chrome, not the article.** It wraps `<header class="chapter-header">` (novel title `h1`, chapter title `h2`) and `<aside class="control-action">` (font selector — Default/Dyslexic/Roboto/Lora — plus Prev/Next and night-mode). The **body is `<div class="chapter-content">`**, nested inside `<section class="page-in content-wrap">`. Select `.chapter-content`, not `#chapter-article`, or the reader ships with a font-picker in the text.
  3. **An ad `<script>` sits inside the content div**: `<div align="center"><script src=/d/js/ad/page_01.js></script></div>`. The cleaner already drops `<script>` elements. Note the path is under `/d/`, which robots.txt disallows — we must never *fetch* it, and dropping the tag is what prevents that.
  4. **`&nbsp;` is not used**; separators are plain `<br><br>`. Whitespace normalisation has no entity to decode here.
  5. **Cloudflare, as above** — present, currently not challenging.

- **Pending promotion**: `04-html-to-markdown.md` §The converter is ours §Required behaviour — the `<br><br>` → paragraph rule and the `.chapter-content` selector are **general** enough to promote. Site-specific selectors stay here.

### Royal Road — https://www.royalroad.com

- **Permission**: permitted for a user-installed reader. Its `robots.txt` (`User-agent: *`) disallows only `/fiction/chapter/*/vote`, `/fictions/review/`, `/forums/report/*`, `/report/*` — voting, reviews and reports. **Fiction listings and chapter content are not disallowed.** The AI-training crawlers (GPTBot, CCBot, Google-Extended, ClaudeBot, Bytespider, …) are disallowed in separate blocks; that is a training-crawler rule, not a reader rule, and does not apply to a client the user installed.
- **Status**: **in v1** (ADR-013), second source, an adapter over the platform contract.
- **Scope**: English web novels. Verified live: catalogue at `/fictions/best-rated`, `/fictions/latest-updates`; fiction page at `/fiction/<id>/<slug>`; chapter at `/fiction/<id>/<slug>/chapter/<chapterId>/<slug>`. Pagination and filter parameters to be discovered during implementation.
- **Cloudflare: present, not challenging.** Measured 2026-10-02 on the home page, the best-rated catalogue, and a real chapter page (`/fiction/21220/mother-of-learning/chapter/301778/1-good-morning-brother`): **200 with no `cf-mitigated` header and no Turnstile markup, under both an honest and a browser-like User-Agent.** No bypass needed.
- **Last verified**: 2026-10-02
- **Quirks**: none blocking — not yet implemented.
- **Pending promotion**: none.

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