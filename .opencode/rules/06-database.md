# Database (drift)

SQLite via `drift`. Mirrors Mihon's schema (manga/chapter/library/history/source tables), adapted for web novels.

## Suggested initial tables

- `NovelsTable` — sourceId, url, title, author, artist, status, description, genres (List<String> as JSON), coverUrl, coverLastModified, initialized, updateStrategy, memo (JSON), timestamps (dateAdded, lastModifiedAt, favoriteModifiedAt), version.
- `ChaptersTable` — novelId (FK, CASCADE), url, name, number (double), scanlator, dateUpload, read, bookmark, lastPageRead, downloaded, dateFetch, memo, version. Unique index on `(novelId, url)`.
- `LibraryTable` — v1 can be a simple `favorite` boolean on novels; a dedicated categories table only if needed.
- `HistoryTable` — novelId, chapterId, lastReadAt, timeRead, chapterIndex.
- `SourcesTable` — sourceId (PK), name, lang, enabled, installed.
- `DownloadsTable` — chapterId, state, progress, path.

## Rules

1. **Migrations**: use `schemaVersion` + `MigrationStrategy` with `beforeOpen`. Never drop tables silently in a release; always write an explicit migration step.
2. **Schema snapshots**: keep drift schema snapshots (e.g. `drift_schemas/`) when the `drift_dev` schema-steps workflow is enabled, so future migrations are generated from diffs.
3. **Streams**: prefer query streams for anything reactive; avoid manual refresh hacks.
4. **Mappers**: DB entities and domain models are distinct types. Mapping lives in `data/mappers/`. Domain never knows about DB rows.
5. **Boolean flags**: `read` / `bookmark` / `downloaded` are plain booleans on chapters (Mihon uses bitmasks; we prefer clarity in v1).
6. **Timestamps**: store UTC epoch millis; format at the UI layer with `intl`.
7. **Indexes**: index hot query paths — chapters by `(novelId, number)`, history by `lastReadAt`, novels by `title` / `status`.
8. **No N+1**: fetch chapter counts for the library via aggregate queries (a `libraryView`-style query), never per-row loops.
9. **JSON columns**: `genres` and `memo` are stored as JSON strings via a drift `TypeConverter`.
