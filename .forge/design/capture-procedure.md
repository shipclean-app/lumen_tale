---
type: note
status: draft
---

# Capturing a site's fixtures — the procedure, and why it is not a `curl`

`0-1` captures one real site so the Source contract can be written and tested
against bytes rather than against prose. **Most sites are a `curl`.** One is not, and
this file is about that one.

## The rule

> **A fixture is a page the owner read, saved whole, unmodified.**
> Never a page a client defeated a challenge to obtain.

ADR-014 measured that an honest `User-Agent` is let through where a browser string is
challenged, and rejected Mihon's WebView bypass on that evidence. `17-security.md` rule 5
requires the honest agent. C1 permits reading for personal use; it does not permit
defeating a site's bot protection to obtain it programmatically. A `cf_clearance` cookie
belongs to a browser session and must never enter a repository — and the builder
**refuses any fixture containing one**, which is the same rule enforced at build time
rather than trusted to review.

## Measured 2026-10-03

| Site | Result with `LumenTale/0.1.0 (personal reader)` |
|---|---|
| **FanMTL** | **403 + Cloudflare interstitial on every path**, including `/robots.txt` and `/favicon.ico`, and with no UA and with a browser UA. **Finding F-012.** |
| **Royal Road** | **200**, and captured in full — 9 fixtures, 2 045 855 bytes |

So FanMTL is captured by the owner and Royal Road by `curl`, and `0-1` is satisfied by
either.

## If a site answers 403 with a challenge

1. Open the page in **your own browser**. Solve whatever it asks. You are a reader
   doing what a reader does.
2. **Chrome → Ctrl+S → "Webpage, HTML Only".**
3. Drop the file into `test/fixtures/sources/<site>/` under the name
   `manifest.in.json` declares.
4. `python3 tool/build_manifest.py <site>`
5. `flutter test test/fixtures/`

**Use "HTML Only".** The other two modes are unusable and the builder refuses them:

| Mode | Why it is refused |
|---|---|
| Webpage, Single File | Resources are inlined, so `bytes` measures something no request will ever return again. |
| Webpage, Complete | Writes a sibling folder of assets into the repository. |
| `.mht` / `.mhtml` | A MIME envelope, not HTML. Unwrapping it by hand is an edit nobody recorded. |

## What the builder refuses, and why each exists

`tool/build_manifest.py` computes `bytes` and `sha256` **from the file**, so they cannot
disagree with it. § 3.2 makes `bytes` the one field an automatic guard asserts, and a
hand-typed hash is a promise about a file rather than a fact about one — so supplying
either is refused.

| Refusal | Rule |
|---|---|
| `bytes` / `sha256` supplied | Measured, never typed. |
| absolute `url` | `03-source-system.md` rules 2-3. A stored absolute URL breaks silently when the host changes. |
| `kind` outside the closed list | § 2.2. A free string becomes a taxonomy nobody maintains. |
| malformed `capturedAt` | `18-external-contracts.md` rule 1 — provenance. Omitting it is fine; supplying a bad one is not. |
| empty `notes` | § 2.2. `notes` records what was **observed**, not a workaround. |
| a session cookie or `cf_clearance` | C2, B4. A committed token is the one artefact that can carry reading data off the phone. |
| a browser-save wrapper | The bytes are Chrome's preamble, not the server's. |
| `.mht` / `.mhtml` | A MIME envelope. |
| a declared file that is absent | A missing capture must not become a silent skip. |

Every one of these is **proven to fire** by `test/fixtures/manifest_builder_test.dart`,
which stages a throwaway site per row. Three of them were found not to fire and fixed:
the `capturedAt` check missed the top level of the spec, and the wrapper check required a
byte adjacency Chrome does not emit.

## What `notes` must contain

`notes` is the only field a machine cannot derive, and it is the one that makes a
capture useful a year later. Write **what you observed**, not what you did:

- the selector that finds the thing, **including every class on the element**
- the row or character count **you counted by hand**
- whether the site publishes its own completeness count

Royal Road's capture is the worked example, and three of its findings contradict
documents written earlier the same day:

| Finding | Why it matters |
|---|---|
| Chapter URLs have **five** segments | The three-segment form 404s, and a 404 is indistinguishable from a chapter that does not exist — B22's third state. |
| The body container is `chapter-inner chapter-content` | An exact `class="chapter-content"` match finds **zero** paragraphs on a page with 106. A zero-parse looks exactly like an empty chapter. |
| **No empty-result marker on a zero-row catalogue** | `18-external-contracts.md` recorded that there is one. There is not, so the third state must be judged by **page shape**. |

## Never

- **Never fabricate a fixture to make a suite green.** `kind: manufactured` exists so a
  manufactured artefact can never be mistaken for a capture, and exactly one artefact may
  be manufactured: the broken-layout pair, built from a real capture by a single literal
  substitution.
- **Never write a selector from the documentation.** Three documented shapes were wrong
  on the live site, and two of them fail *silently* as "no results".
- **Never let a session cookie into a capture**, however convenient it would be.