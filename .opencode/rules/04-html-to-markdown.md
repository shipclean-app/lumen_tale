# HTML → Markdown Pipeline

The core transformation of the product. Given a chapter page (HTML), produce clean Markdown.

## Contract

`Source.fetchChapterContent(chapter)` returns the raw chapter HTML (the article). Conversion happens in a shared service (`core`):

```
raw HTML
  → select article body (source-specific `chapterContentSelector`)
  → clean: drop <script>, <style>, <iframe>, <nav>, ads, share buttons, comments
  → fix relative image/link URLs against baseUrl
  → html2md with per-source overrides
  → normalize whitespace, collapse blank lines
  → Markdown
```

## Rules

1. **Extract first, convert after**: always extract the article element via the source's selector before converting. Never convert the whole page.
2. **Cleaning is per-source**: each source provides the selectors/classes to strip (ads, "next chapter", comment sections, etc.). Centralize common patterns in the shared cleaner, but allow source overrides.
3. **Images**: keep images only when they are part of the story (rare for web novels). If kept, rewrite `src` to absolute URLs and download them in the download pipeline. By default, drop decorative images.
4. **Paged chapters**: when a chapter is split across multiple pages, the source must fetch all pages and concatenate content in order before conversion. The `Page` model exists for this.
5. **Encoding**: always decode with the charset from the server (`Content-Type`) or meta tags; fall back to UTF-8. Never assume ASCII.
6. **Entities & Unicode**: normalize common entities; keep Unicode punctuation. Escape Markdown-reserved characters only where required for valid output.
7. **Deterministic output**: same HTML in → same Markdown out, so re-fetching produces stable diffs.
8. **No data loss**: preserve code blocks, quotes, and tables with the correct Markdown syntax.
9. **Testing**: every source ships parsing fixtures + unit tests asserting selectors, cleaning, and conversion (see `10-testing.md`).

## Recommended libs

- `html` — DOM parsing + CSS selectors (equivalent of Jsoup).
- `html2md` — baseline conversion; wrap it so per-source overrides are easy.
