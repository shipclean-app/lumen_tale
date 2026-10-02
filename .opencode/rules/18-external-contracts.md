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

Nothing is recorded yet — no source is implemented yet. The first entry is created when the first source lands. Record `Permission` **before** writing the scraper, not after.