# Downloads & Offline Reading

Unlike Mihon (which downloads image pages), Lumen Tale downloads **chapter Markdown files** plus optional embedded images and covers.

## Storage layout

```
<appSupport>/
├── downloads/
│   └── <sourceId>/<novelId>/
│       └── <chapterNumber padded>/chapter.md   (+ metadata.json, images/)
└── covers/
    └── <novelId>.jpg
```

Use `path_provider` (`getApplicationSupportDirectory`) + `path` for joining.

## Rules

1. **Single source of truth**: the DB row (`downloaded` flag + `DownloadsTable` state) owns the download state; files on disk are derived artifacts.
2. **Progress**: expose a Riverpod provider streaming per-chapter download progress (bytes / percent) and reuse it in the UI.
3. **Idempotent re-download**: if the file exists and the DB says `downloaded`, do not refetch. Offer an explicit "re-download" that wipes and refetches.
4. **Atomic writes**: write to `*.tmp`, then rename. Never leave a partial `.md` behind.
5. **Cancellation**: support cancelling a queue; clean up partial files.
6. **Covers**: download through the source cover URL via `cached_network_image` and persist a local copy under `covers/`.
7. **Offline reading**: the reader reads the local `.md` when `downloaded`; otherwise it fetches live (and never writes unless asked).
8. **Updates**: the library update flow fetches chapter lists; auto-download of new chapters is **off by default**. Scheduled (background) update checks are a separate concern owned by `15-performance.md` §Background work — this file owns the user-initiated download queue only.
9. **Filename sanitization**: owned by `17-security.md` rule 1 — source-provided strings are untrusted input and are slugged before any `path.join`. This is the rule that keeps a malicious or misconfigured site from writing outside the downloads root.
10. **No sensitive data**: owned by `17-security.md` rules 8–9 — no cookies, tokens, or raw page HTML in persisted metadata. `metadata.json` holds display metadata only (title, number, source id, timestamps).
11. **Cleanup**: removing a novel or source deletes its folder and DB rows; the download queue must not crash on missing files (treat them as already removed).
