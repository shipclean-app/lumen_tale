# HTML → Markdown Pipeline

The core transformation of the product. Given a chapter page (HTML), produce clean Markdown.

## Contract

`Source.fetchChapterContent(chapter)` returns the raw chapter HTML (the article). Conversion happens in a shared service under `core/` — `core/pipeline/`, owned by no single feature:

```
raw HTML
  → select article body (source-specific `chapterContentSelector`)
  → clean: drop <script>, <style>, <iframe>, <nav>, ads, share buttons, comments
  → fix relative image/link URLs against baseUrl
  → HTML DOM → Markdown (the converter below)
  → normalize whitespace, collapse blank lines
  → Markdown
```

## The converter is ours, built on `html`

**There is no `html2md` dependency, and there must not be one.** The package `html2md` declares `sdk: >=2.12.0 <3.0.0` on every published version — it is Dart 2 only and cannot resolve on this project. Every Dart-3-capable HTML→Markdown package on pub.dev is a native/FFI binding (`h2m`, `html_to_markdown_rust`, `html_to_markdown_ffi`); the pure-Dart ones are Markdown *renderers*, not converters. Adding a Rust/FFI toolchain to a mobile reader for this step is the wrong trade.

So the conversion is written directly against `package:html`, which is already a dependency and is already used for the selectors and the cleaning pass. There is no baseline converter to "wrap" — the `Element` walk **is** the converter.

**Why this is not premature reinvention:** the input is a narrow, well-understood subset (chapter bodies: paragraphs, `<br>`, headings, emphasis, links, images, blockquotes, lists, tables), and per-source override behaviour is a requirement, not a nice-to-have. A converter we own is the only way `03-source-system.md` §Rules can let each source adjust conversion without forking a third-party package.

### Required behaviour

- Walk the `Element` tree from the extracted article node; emit Markdown as a `StringBuffer`.
- Inline: `p`, `br` → hard break, `h1`–`h6`, `em`/`i`, `strong`/`b`, `code`, `a` (resolve `href` against `baseUrl`), `img` (resolve `src`, subject to the image rule below), `del`/`s`.
- Block: headings, paragraphs, `blockquote`, `ul`/`ol` (nested, with correct indentation), `pre`/`code` fences, `hr`, `table` (pipe tables; fall back to paragraph text if the table is too irregular to represent).
- Drop by default: `script`, `style`, `noscript`, `iframe`, `object`, `embed`, `svg`, `nav`, `aside`, `footer`, `form`, `button`, and every node a source marked as removable.
- **Escaping:** escape Markdown-reserved characters in text nodes only, and only where an escape would otherwise change meaning. Never escape inside `pre`/`code`.
- **Whitespace:** collapse runs of whitespace in text nodes; trim block edges; never emit more than one consecutive blank line.
- **Deterministic:** the same input HTML always produces byte-identical output, so re-fetching a chapter yields a stable diff.

### Testing the converter

The converter is ours, so it is ours to test — it is P0 coverage in `10-testing.md`. Ship fixture HTML per source (`test/fixtures/sources/<name>/`) plus dedicated converter fixtures covering: nested lists, tables, entities, code blocks, images, and a document with everything stripped.

## Rules

1. **Extract first, convert after**: always extract the article element via the source's selector before converting. Never convert the whole page.
2. **Cleaning is per-source**: each source provides the selectors/classes to strip (ads, "next chapter", comment sections, etc.). Centralize common patterns in the shared cleaner, but allow source overrides.
3. **Images**: keep images only when they are part of the story (rare for web novels). If kept, rewrite `src` to absolute URLs and download them in the download pipeline. By default, drop decorative images.
4. **Paged chapters**: when a chapter is split across multiple pages, the source must fetch all pages and concatenate content in order before conversion. The `Page` model exists for this.
5. **Encoding**: always decode with the charset from the server (`Content-Type`) or meta tags; fall back to UTF-8. Never assume ASCII.
6. **Entities & Unicode**: `package:html` decodes entities during parsing; keep Unicode punctuation. Do not double-decode.
7. **Deterministic output**: same HTML in → same Markdown out, so re-fetching produces stable diffs.
8. **No data loss**: preserve code blocks, quotes, and tables with correct Markdown syntax.
9. **Testing**: every source ships parsing fixtures + unit tests asserting selectors, cleaning, and conversion (see `10-testing.md`). The converter itself has its own fixture suite independent of any source.