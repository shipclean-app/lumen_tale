// Lumen Tale — local schema (drift / SQLite)
//
// Every field below is traceable to a PRD rule. The authority for a field
// being here is `architecture.md` § 4; the authority for its behaviour is the
// rule cited in its comment. A field with no rule behind it is a field nobody
// asked for.
//
// This file is the schema. `.forge/architecture.md` § 4.3 must stay in step
// with it, and `06-database.md` owns the migration discipline.

import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';

part 'app_database.g.dart';

/// Chapter lifecycle inside the download queue.
///
/// `queued` and `downloading` are deliberately distinct: B19 lets the reader
/// pause a queue, and a paused item is `queued` with the queue stopped, not a
/// fourth state. Collapsing them would make "paused" unrepresentable.
enum DownloadState {
  /// B18 — enqueued, in reading order, not started.
  queued,

  /// B18 — B19 — currently fetching.
  downloading,

  /// B6 — the chapter is present and complete on the phone.
  done,

  /// B24 — the last attempt failed; `queueItems.errorCode` says why.
  failed,
}

/// Stores the enum by **name**, not by ordinal.
///
/// Read from the installed package rather than from memory: in drift 2.35.1
/// `textEnum<T>()` is declared `ColumnBuilder<String> textEnum<T extends Enum>()`
/// (`lib/src/dsl/table.dart:157`) — a String builder with a phantom type
/// parameter, so it does **not** give a `Column<DownloadState>`.
class DownloadStateConverter extends TypeConverter<DownloadState, String> {
  const DownloadStateConverter();

  @override
  DownloadState fromSql(String fromDb) => DownloadState.values.byName(fromDb);

  @override
  String toSql(DownloadState value) => value.name;
}

/// A novel as the app knows it.
///
/// B2 — a novel belongs to exactly one site. `sourceId` is therefore part of
/// the identity, never derived from the title.
@DataClassName('NovelRow')
class Novels extends Table {
  /// B3 — stable across sessions and restarts. MD5 of
  /// `'${name.toLowerCase()}/$lang/$versionId'` per `03-source-system.md`
  /// rule 1, combined with the source's own id. Never hand-written.
  TextColumn get id => text()();

  /// B2 — the one site this novel came from. B40 forbids merging two sites'
  /// novels, so this is part of the primary identity and never nullable.
  TextColumn get sourceId => text()();

  /// `03-source-system.md` rule 3 — relative (path + query), never a full URL.
  /// Hosts change; a stored absolute URL breaks silently.
  TextColumn get url => text()();

  /// B10-adjacent — displayed verbatim as the site presents it. Never
  /// normalised, title-cased or trimmed beyond leading/trailing whitespace.
  TextColumn get title => text()();

  /// `03-source-system.md` rule 8 — site-specific strings mapped into the
  /// shared enum. Empty means the site did not say.
  TextColumn get status => text().withDefault(const Constant(''))();

  /// Nullable because a site often omits it, and an invented cover is worse
  /// than none. Null means "this novel has no cover", not "we failed".
  TextColumn get coverUrl => text().nullable()();

  /// B11 — keeping a novel in the library and following it are the same act.
  /// One flag, not two.
  BoolColumn get inLibrary => boolean().withDefault(const Constant(false))();

  /// B49 — when this novel was last checked against its site. **Null means
  /// "never checked"** and that distinction is load-bearing: B48 forbids
  /// presenting a local count as if it came from a check.
  DateTimeColumn get lastCheckedAt => dateTime().nullable()();

  /// B12 — when the reader added it, used only for B17's history ordering and
  /// a tie-break. Null while `inLibrary` is false.
  DateTimeColumn get addedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};

  /// The library is a filtered, sorted view of this table. `inLibrary` is in
  /// the index because every library query filters on it first.
  @override
  List<Set<Column>> get uniqueKeys => [];
}

/// One chapter of one novel.
///
/// B9 — the list is shown complete, whatever its length, so there is no
/// truncation column and no page table. A 900-chapter novel is 900 rows.
@DataClassName('ChapterRow')
class Chapters extends Table {
  /// B3 — stable. Derived from the novel's id plus the chapter's own url.
  TextColumn get id => text()();

  /// CASCADE on delete: B32 — removing a novel removes its chapter *records*,
  /// but never its downloaded files. The files are keyed by path and are not
  /// touched by this delete; see `07-downloads-offline.md`.
  TextColumn get novelId =>
      text().references(Novels, #id, onDelete: KeyAction.cascade)();

  /// B10 — displayed exactly as the site presents it.
  TextColumn get name => text()();

  /// `03-source-system.md` rule 9 — `ChapterRecognition`. **-1 means
  /// unparseable and must render as an em dash, never as 0.** 0 is a real
  /// chapter number (an extra, an omake, an author's note) and collapsing the
  /// two is a B10 violation.
  RealColumn get number => real().withDefault(const Constant(-1))();

  /// Relative url, per `03-source-system.md` rule 3.
  TextColumn get url => text()();

  /// B13 — a chapter counts as new until the reader opens it; opening it
  /// clears it. This is the whole of B14's counting model: the unread count is
  /// `count(isRead == false)`, **derived, never stored**, so it cannot drift
  /// from the chapters it counts (B48).
  BoolColumn get isRead => boolean().withDefault(const Constant(false))();

  /// When it became read. Null while `isRead` is false.
  DateTimeColumn get readAt => dateTime().nullable()();

  /// **B6's mark.** Null means "not downloaded". Non-null means the `.md` file
  /// was wholly present when this was written.
  ///
  /// The mark is **written after** the atomic rename in `2-3`, never before.
  /// That ordering is the whole of B6's intent: a crash between the two steps
  /// leaves a file with no mark, which is the safe direction — the chapter
  /// offers itself for download rather than opening as if it were complete.
  /// The reverse — a mark with no file — is unreachable, which is what makes
  /// B6 expressible rather than merely true of the happy path.
  ///
  /// Without this column the mark was a per-row filesystem probe, and that was
  /// the defect: B33 deletes one chapter's copy, so a probe could not
  /// distinguish "deleted on purpose" from "file lost", and probing 10 000 rows
  /// put B9's complete-list requirement at risk (see ADR-021).
  DateTimeColumn get downloadedAt => dateTime().nullable()();

  /// B9 — reading order is the site's order, so it is an explicit ordinal and
  /// not something re-derived from `number`. Sites interleave volumes,
  /// side stories and numeric gaps; re-sorting by number would reorder them.
  IntColumn get ordinal => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Reading position, one row per chapter the reader has opened.
///
/// B16 — remembered **per chapter**. B46 — a position is not history: this
/// table is written on every scroll settle and never read as a record of what
/// was read.
@DataClassName('PositionRow')
class ReadingPositions extends Table {
  TextColumn get chapterId =>
      text().references(Chapters, #id, onDelete: KeyAction.cascade)();

  /// B16 / ADR-009 — a **scroll offset**, not a page index and not a page
  /// number. ADR-009 defers paged modes to v2, and an offset is the only
  /// representation v2 can resume from without converting it.
  RealColumn get offset => real().withDefault(const Constant(0))();

  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {chapterId};
}

/// What the reader opened, in reverse order.
///
/// B17 — recently opened chapters, most recent first. B47 — bounded by
/// **time**, not by count, so there is no `LIMIT` anywhere in this table's
/// access and no `position` column.
@DataClassName('HistoryRow')
class HistoryEntries extends Table {
  TextColumn get id => text()();

  /// RESTRICT, not CASCADE. B32 — removing a novel keeps its downloaded
  /// chapters, and the history of what was read survives that too. A cascade
  /// here would delete the reader's record as a side effect of a file
  /// operation, which is B32's exact failure.
  TextColumn get novelId =>
      text().references(Novels, #id, onDelete: KeyAction.restrict)();

  TextColumn get chapterId =>
      text().references(Chapters, #id, onDelete: KeyAction.cascade)();

  /// B17 — the ordering column, descending.
  DateTimeColumn get openedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// The download queue.
///
/// B18 — a novel downloads as a queue, **one chapter at a time, in reading
/// order**. There is deliberately no concurrency column: B18 makes it a
/// constant, and a constant expressed as a column would be something an
/// implementation could change.
@DataClassName('QueueRow')
class QueueItems extends Table {
  TextColumn get id => text()();

  TextColumn get chapterId =>
      text().references(Chapters, #id, onDelete: KeyAction.cascade)();

  /// Declared `TextColumn`, not `DownloadState`: `ColumnBuilder.map` is a
  /// phantom-typed builder whose declared return is `ColumnBuilder<T>` of the
  /// *underlying* type, so a non-String type here fails `flutter analyze`
  /// before drift_dev ever runs. drift's own example is the same shape — the
  /// table declares `TextColumn`, and the generator is what makes the generated
  /// row expose `DownloadState`.
  TextColumn get state => text()
      .map(const DownloadStateConverter())
      .withDefault(const Constant('queued'))();

  /// B18 — insertion order. This, not `ordinal`, is what the queue reads, so
  /// a reader's hand-picked order is honoured.
  IntColumn get queuePosition => integer()();

  DateTimeColumn get addedAt => dateTime()();

  DateTimeColumn get startedAt => dateTime().nullable()();

  DateTimeColumn get finishedAt => dateTime().nullable()();

  /// B20 — an interrupted download resumes rather than restarting, so the
  /// attempt count is what distinguishes a resume from a fresh fetch.
  IntColumn get attempts => integer().withDefault(const Constant(0))();

  /// B24 / B22 — a typed code from `13-error-handling.md`'s hierarchy, so the
  /// UI can tell *why* something failed. "failed" with no reason is exactly
  /// the state B22 exists to prevent.
  TextColumn get errorCode =>
      text().nullable().withDefault(const Constant(''))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Per-source state the app owns: enabled, last check, last failure.
///
/// Not a copy of the source registry — that is code (ADR-013). This is the
/// **local** state of each compiled-in source.
@DataClassName('SourceRow')
class Sources extends Table {
  /// `03-source-system.md` rule 1 — the registry id, never hand-written.
  TextColumn get id => text()();

  BoolColumn get enabled => boolean().withDefault(const Constant(true))();

  /// B49 — null means "never checked", which is what the UI must show.
  DateTimeColumn get lastCheckedAt => dateTime().nullable()();

  /// B22 — the last failure's typed code, so `sources` can render `unavailable`
  /// without having just attempted a fetch.
  TextColumn get lastErrorCode =>
      text().nullable().withDefault(const Constant(''))();

  /// `03-source-system.md` rule 6 — `ConfigurableSource` values, namespaced
  /// `source_<id>`. JSON text, opaque to the platform: B41's rule that the
  /// platform never interprets a source's own values applies to filters, and
  /// it applies here too.
  TextColumn get settings => text().withDefault(const Constant('{}'))();

  @override
  Set<Column> get primaryKey => {id};
}

/// The app's local database.
///
/// **Version 1 is the first shipped schema.** `06-database.md` owns migrations:
/// a version bump ships a `MigrationStrategy` step, and
/// `dart run drift_dev schema dump lib/core/database/app_database.dart
/// lib/core/database/schema.json` exports the snapshot committed beside this
/// file. **Two arguments** — with one it prints usage and exits 0, so it looks
/// like it ran. B31 is the reason that discipline is not
/// optional — installing a new version over an existing one must preserve every
/// row, so a migration that drops a table is a migration that breaks the one
/// promise this app makes that its competitors break.
@DriftDatabase(
  tables: [
    Novels,
    Chapters,
    ReadingPositions,
    HistoryEntries,
    QueueItems,
    Sources,
  ],
)
class AppDatabase extends _$AppDatabase {
  /// `LazyDatabase`, not an eagerly-opened executor: resolving the support
  /// directory crosses a platform channel, and doing that in the constructor
  /// would touch the platform before anything has asked for a query.
  AppDatabase() : super(_openLazy());

  /// In-memory instance for tests. Named so a test cannot accidentally open
  /// the reader's real library.
  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    // B31 — beforeOpen is the only place a schema mistake can be caught
    // while the data is still intact. A destructive step here would be the
    // single worst line in the codebase, so there is deliberately no
    // `onUpgrade` implementation yet: version 1 has no predecessor, and
    // adding one is the first thing to do with the next table.
    onCreate: (m) async => m.createAll(),
  );
}

/// Opens the real database file, under the platform's *application support*
/// directory rather than its documents or cache directory.
///
/// **Support, not cache.** The OS may evict anything in the cache directory,
/// and B7 requires a stored chapter to stay readable — so a database that
/// holds the library, the reading positions and the history must not live
/// somewhere the system is allowed to reclaim. This one line is B7 and B31
/// applying to storage location rather than to code.
LazyDatabase _openLazy() => LazyDatabase(() async {
  final dir = await getApplicationSupportDirectory();
  return NativeDatabase.createInBackground(
    File('${dir.path}/lumen.db'),
    setup: _setup,
  );
});

/// **This is the single most important function in the database layer.**
///
/// SQLite ships with foreign-key enforcement **off**, per connection, and it is
/// not part of the file format: a database created with the pragma on opens
/// with it off unless every connection turns it on again. Without the line
/// below, every `references(...)` in this file is *declared* and then *never
/// enforced* -- the `CASCADE` that clears a novel's chapters, and more
/// importantly the `RESTRICT` on `history_entries.novelId` that is **B32's only
/// enforcement**. B32 would read correctly in the schema, in the review and in
/// the documentation, and would not hold.
///
/// Two tests caught this: one asserting the cascade, one asserting that the
/// RESTRICT refuses the delete. Both failed against a schema that looked
/// perfect. A `CHECK` nobody has executed is SKILL.md 4.5's exact failure --
/// and this one is worse, because the failure is invisible rather than loud:
/// the app behaves as if the constraints were there.
///
/// `foreign_keys` is asserted to be 1 in `app_database_test.dart`, so a future
/// refactor that drops this line fails a test instead of silently disabling
/// B32.
/// Synchronous, and it takes sqlite3's own [Database] -- `DatabaseSetup` is
/// declared `void Function(Database database)` (`lib/native.dart:30`), so an
/// `await` here does not compile and is not wanted.
void _setup(Database db) {
  db.execute('PRAGMA foreign_keys = ON');
}
