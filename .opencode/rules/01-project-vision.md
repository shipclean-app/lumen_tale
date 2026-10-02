# Project Vision

## What Lumen Tale is

Lumen Tale is a **Web Novel reader** for mobile (Flutter). Users aggregate their favorite web novels in one place, browse catalogue sources, fetch chapter content, read it, and store it for **offline** reading.

It is inspired by [Mihon](https://github.com/mihonapp/mihon) (a manga reader) but targets **web novels**:

- Mihon sources produce **image pages**; Lumen Tale sources produce **chapter HTML content**.
- Mihon ships a dynamic **extension** system; Lumen Tale **v1 has no extension system** — sources are plain Dart classes implementing an abstract `Source`, registered statically.

## Content pipeline (core value proposition)

```
Source website (HTML)
  → Source.fetchChapterContent(chapter)     raw HTML
  → clean: strip nav, ads, scripts, boilerplate (per-source selectors)
  → convert: HTML → Markdown (in-repo converter on `html`, per-source overrides)
  → persist: chapter .md file + metadata on disk
  → render: Markdown reader (flutter_markdown_plus)
```

This pipeline is the heart of the product. Every source-specific rule must preserve this contract.

## MVP scope (v1)

- Add sources (static registry) and browse their catalogues (popular / latest / search).
- Add novels to the library.
- Fetch, convert, and download chapters as Markdown.
- Read chapters online and offline.
- Track read progress (history, "continue reading", unread badges).
- Update the library (check for new chapters).
- Source configuration (per-source preferences).

## Non-goals for v1 (do not build)

- Dynamic extension loading / plugin packages.
- Cross-device sync / accounts.
- EPUB/archive local sources (a local source may come later).
- Tracker integrations.
