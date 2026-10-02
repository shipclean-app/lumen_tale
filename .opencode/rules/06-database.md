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
2. **Schema snapshots are mandatory, not conditional**: `drift_dev` is a dev dependency and the snapshot is committed at `lib/core/database/schema.json`. After any table change run `dart run build_runner build`, then `dart run drift_dev schema dump lib/core/database/app_database.dart lib/core/database/schema.json` to export the new structure. **Both** arguments are required; with one the command prints usage and exits 0, so it looks like it ran. `test/core/database/schema_snapshot_test.dart` fails when the snapshot and the live schema disagree, so an un-re-dumped table change is caught by a test. A migration written without a snapshot cannot be regenerated, so it is a one-way door. Related: `dart run drift_dev make-migrations` scaffolds the migration utilities; `dart run drift_dev analyze` lints the generated database code.
3. **Streams**: prefer query streams for anything reactive; avoid manual refresh hacks.
4. **Mappers**: see `02-architecture.md` §Repository pattern — that section owns the boundary rule (interfaces in `domain`, implementations in `data`, mapping in `data/mappers/`, no DB types in features). Only the drift-specific mechanics are here, below.
5. **Boolean flags**: `read` / `bookmark` / `downloaded` are plain booleans on chapters (Mihon uses bitmasks; we prefer clarity in v1).
6. **Timestamps**: store UTC epoch millis; format at the UI layer with `intl`.
7. **Indexes**: index hot query paths — chapters by `(novelId, number)`, history by `lastReadAt`, novels by `title` / `status`.
8. **No N+1**: fetch chapter counts for the library via aggregate queries (a `libraryView`-style query), never per-row loops.
9. **JSON columns**: `genres` and `memo` are stored as JSON strings via a drift `TypeConverter`.

## Mappers (drift-specific mechanics)

The mapper *boundary* is owned by `02-architecture.md` §Repository pattern. These are the drift concerns that boundary doesn't cover:

- Mappers handle: timestamps (epoch millis ↔ `DateTime`), JSON columns (`genres`, `memo`), enum ↔ int codes.
- Domain never imports drift — a freezed model has no `TableRow` in its signature.
- Repositories return domain types or `Stream<T>`; never expose `TableRow` / `QueryRow` / `Map<String, dynamic>` to features.
- Every mapper ships unit tests, round-tripping a row ↔ domain model (see `10-testing.md`).