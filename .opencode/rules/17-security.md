# Security

**One owner.** Path-sanitisation, secret-handling, and third-party-content rules used to be scattered across `07-downloads-offline.md`, `09-widgets-ui.md`, and `11-git-workflow.md`. They live here; those files cross-reference this one. Do not restate a rule from this file elsewhere.

## Untrusted input: everything from a source

Every string that came from a scraped website — a chapter name, a novel title, a cover URL, a `memo` value — is **untrusted input**, because it came from a third party that does not share this user's interests.

1. **Never build a filesystem path from a raw source-provided string.** Sanitize to a safe slug first: strip path separators, `..`, control characters, and reserved characters (`< > : " / \ | ? *` and leading/trailing whitespace/dots). Join only after sanitizing, and verify the resolved path is still inside the downloads root. A malicious or merely broken site must not be able to write outside `<appSupport>/downloads/`.
2. **Never let source data reach a shell, a SQL string, or an eval-like sink.** Drift queries use bound parameters; there is no string-concatenated SQL anywhere in this codebase.
3. **Cap the size of anything fetched or persisted.** A source returning a 500 MB "chapter" is a bug or an attack; the download pipeline enforces a per-chapter size ceiling and fails the chapter rather than filling the disk.
4. **Parse defensively.** HTML from a source is not valid HTML. Never assume a selector matched — an unmatched selector is an error path, not an empty result.

## Network posture

5. **Identify honestly.** Send a descriptive User-Agent naming the app and offering a contact path — `Mozilla/5.0 (compatible; LumenTale/0.1; personal reader)`. **Never impersonate a browser or another reader to evade a site's blocking.** This is not caution, it is measured: on Novel Fire the honest UA gets **200 and the full page**, while a Chrome/Android string gets **403 with `cf-mitigated: challenge` and Turnstile markup** (ADR-014). Pretending to be a browser is what triggers the block. FanMTL and Royal Road serve both without a challenge, so nothing in v1 needs a bypass.
   - **Do not port Mihon's Cloudflare WebView bypass.** It loads the URL in a real `WebView` to harvest a `cf_clearance` cookie. It is well-judged code — it aborts on interactive challenges rather than defeating them — and it is still wrong here: it would add `webview_flutter` and a hidden-WebView path no current site exercises, and its User-Agent is the one Novel Fire rejects. ADR-014.
   - **If a site ever challenges our honest UA**: record it in `18-external-contracts.md`, then **stop and ask the owner.** The contract promises we escalate to nobody without asking. The answer is *drop the source* or *amend this rule with a new ADR* — never a silent implementation detail.
6. **Rate limit and back off.** Shared rate limiting lives in `core/network/`. Respect `Retry-After`, and stop hammering a site that is failing rather than retrying in a loop.
7. **TLS only.** No plain-HTTP fetch, no disabled certificate validation, no trust-all `dio` interceptor. There is no legitimate reason for any of these in a reader app.

## Data at rest

8. **No secrets at rest.** Never persist cookies, auth tokens, or session identifiers. A reader is an anonymous client; if a source needs a credential, it belongs in the platform keystore, never in a download folder or a `metadata.json`.
9. **No raw page HTML in metadata.** `metadata.json` holds display metadata only: title, chapter number, source id, timestamps. Scraped HTML is transient — it is converted to Markdown and discarded.
10. **Covers and images come from arbitrary hosts.** Treat every downloaded image as untrusted content (see rule 1 for paths, and `04-html-to-markdown.md` rule 3 for whether to keep images at all).

## Secrets and dependencies

11. **Never commit secrets.** No API keys, tokens, `.env` files with real values, or signing material. `build/`, `.dart_tool/`, `.env`, and `*.jks` / `*.keystore` stay untracked.
12. **Never hand-edit `pubspec.yaml`.** `08-coding-standards.md` §Dependencies owns the mechanism (`flutter pub add` / `remove`). A version constraint typed by hand is an unreviewed supply-chain decision.
13. **Never add a native/FFI dependency to dodge a pure-Dart problem** without an ADR in `DECISIONS.md` recording the build-toolchain cost. `04-html-to-markdown.md` §The converter is ours is the worked example: the FFI options were rejected precisely because of this rule.
14. **Reading third-party code is not copying it.** External references guide structure and patterns only — never a runtime dependency. Check licences before substantial reuse. Copy-paste "as-is" is forbidden. This applies to source scrapes and to other developers' rule sets alike.

## Third-party content

15. **Scraped content belongs to its author and its site.** Store what the user needs to read the chapter they asked for, no more. Do not build redistribution features (sharing, exporting to a public format) in v1 — see `01-project-vision.md` §Non-goals.
16. **Only scrape sites that permit it.** Per-site permission is tracked in `18-external-contracts.md`; a site recorded there as disallowed is not implemented, regardless of how easy it would be.

## Reviewing a change in this area

- Does any new `path.join` take a source-provided component? → rule 1.
- Does any new network call lack a timeout, a User-Agent, or rate limiting? → rules 5–7.
- Does any new persisted blob contain content from a site? → rules 8–9.
- Does the change add a dependency? → rules 12–13.