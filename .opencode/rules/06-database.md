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
5. **Boolean flags**: `isRead` is a plain boolean on `chapters` (Mihon uses bitmasks; we prefer clarity in v1). **`downloaded` is not one** — it is `downloadedAt`, a nullable datetime, null meaning *not downloaded*, and it is written **after** the file's atomic rename.

   > **Amended 2026-10-02 (ADR-022).** The rule previously said `downloaded` was a plain boolean, and the committed schema had **no download mark at all** — "downloaded" was a per-row filesystem probe. That cannot express **B33** (one chapter's copy deleted on its own), which makes a deliberate deletion indistinguishable from never having downloaded, and it puts **B9**'s 10 000-chapter requirement at risk. A boolean would not have helped either: it cannot say *when*, so "downloaded then deleted" still shares a value with "never downloaded".
6. **Timestamps**: store UTC epoch millis; format at the UI layer with `intl`.
7. **Indexes**: index hot query paths — chapters by `(novelId, number)`, history by `lastReadAt`, novels by `title` / `status`.
8. **No N+1**: fetch chapter counts for the library via aggregate queries (a `libraryView`-style query), never per-row loops.

   > **Where this lives: slice `6-3`.** B14 and B48 both require the count to be exact on a novel that may hold 10 000 chapters (B9), and a per-row loop is what makes that number wrong rather than slow. `6-3` is the slice that owns the counting model, so the aggregate is its responsibility and its test asserts the *count*, not the timing — a timing assertion on a query shape belongs to `15-performance.md`.
7. **Indexes on hot paths**, declared with the schema and not added later: `chapters(novelId, ordinal)` for the chapter list (**B9**'s complete list), `chapters(novelId, isRead)` for **B14**/**B48**'s derived count, `history_entries(openedAt)` for **B17**'s reverse-chronological list, `novels(title)` for **B45**'s title-only search, `queue_items(state)` for the paused/queued filter.

   > **Status 2026-10-02: they exist now, and they did not an hour ago.** This rule file had been promising them since before any table did, while the committed schema had **zero** indexes — a rule satisfied by nothing and contradicted by the code. All five are declared with `@TableIndex` on their table classes, in `local-store`, and recorded in `schema.json`. They are additive DDL, so **B31 is untouched**: an index is not a column, no row's meaning changes, and `schemaVersion` stays 1.
   >
   > **Proved two ways, and the second is the point.** `drift_dev schema dump` records indexes alongside tables, so `schema_snapshot_test.dart` catches one that is *removed* — it had to be taught to skip non-table entities, which it now does. But the snapshot held **no index entities at all** until these five existed, and an empty category in a snapshot reads exactly like a covered one. So `app_database_test.dart` reads `sqlite_master` directly, the same way the foreign-key pragma is asserted: that catches an index declared in Dart and **never created**, which no snapshot can see.
   >
   > **Two placement traps, both hit.** `@TableIndex` is `@Target({TargetKind.classType})` — the annotation goes **above** `class X extends Table {`, never inside the body, and drift silently emits no index when it is inside. And a wrong getter name produces `CREATE INDEX x ON t ()` — valid enough to compile, fatal at `createAll()`. Neither raises an analyzer diagnostic.

9. **JSON columns**: `genres` and `memo` are stored as JSON strings via a drift `TypeConverter`.

   > **Amended 2026-10-02 — partly amended, and the rest is still aspirational.** The suggested table above lists `author`, `artist`, `description` and `genres`. **`author` and `description` now exist** (ADR-024): five screen files bind `novel.author` and `novel-details.md` said outright that it is *stored*, so the design had a field with no column. They are **display-only and unindexed** — B45's promise is title-only search, and `idx_novels_title` is how that promise is enforced rather than merely asserted.
   >
   > **`artist`, `genres` and `memo` remain out.** `genres` was the premise **B42** was withdrawn on, and **B45** replaced it with title-only search for exactly that reason; there is no `memo` in the product at all. The drift `TypeConverter` technique is sound and stays as guidance — but a column name in a suggested table is a *hypothesis*, and one that survives unexamined long enough gets implemented.

## Mappers (drift-specific mechanics)

The mapper *boundary* is owned by `02-architecture.md` §Repository pattern. These are the drift concerns that boundary doesn't cover:

- Mappers handle: timestamps (epoch millis ↔ `DateTime`), JSON columns (`genres`, `memo`), enum ↔ int codes.
- Domain never imports drift — a freezed model has no `TableRow` in its signature.
- Repositories return domain types or `Stream<T>`; never expose `TableRow` / `QueryRow` / `Map<String, dynamic>` to features.
- Every mapper ships unit tests, round-tripping a row ↔ domain model (see `10-testing.md`).