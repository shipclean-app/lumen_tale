// Lumen Tale — the only two queries this slice writes, and they are written out.
//
// `6-6` § 2.1. `data/` → `core` + `domain` (`02-architecture.md`).
//
// ## ⚠️ Raw SQL, and the reason is a SPELLING drift does not have
//
// `06-database.md` rule 8 forbids a Dart-side loop over chapters, and `6-3` already
// established that drift's expression builder has no readable spelling for a
// conditional aggregate inside a `LEFT JOIN`. A readable query that is right beats an
// elegant builder call that has to be decoded twice — so the SQL is the specification
// here, and the part of the specification the builder cannot express is exactly the part
// that matters.
//
// ## ⚠️ THREE DEFECTS IN THE PLAN'S OWN SQL, AND ALL THREE WOULD HAVE PASSED SILENTLY
//
// 1. **§ 2.1's `unopened_count` was `COUNT(c.id)` — the chapter count, aliased twice.**
//    It is the same expression as `chapter_count`, so the badge would have shown *how
//    many chapters the novel has* while claiming to show *how many you have not opened*.
//    § 3.2's own pseudocode says `COUNT(*)` under `is_read = 0`; § 2.1's SQL never
//    mentions `is_read`. The row below reads `is_read`, and the test
//    *3 unopened, open 1, badge 3 → 2* is what holds it there.
// 2. **`:needle` is not drift 2.35.1's syntax.** `customSelect` binds `List<Variable>`
//    positionally and writes `?`; there is no `Variable.named` in this version. The
//    plan's own `titleNeedle(...)` helper returns a *positional* `Variable<String>`, so
//    its SQL and its Dart disagree with each other. `?` it is.
// 3. **`ESCAPE '\'` before `COLLATE NOCASE`, in that order**, because that is SQLite's
//    grammar (`expr LIKE expr [ESCAPE expr] [COLLATE name]`). Reversed, SQLite rejects
//    the statement at prepare time — which is the one failure here that would *not* have
//    been silent.
//
// ## ⚠️ `readsFrom` IS NOT OPTIONAL
//
// A drift stream whose `readsFrom` omits a table it reads emits once and never again.
// Both queries below read `novels`, `chapters`, `sources`, `queue_items` and
// `reading_positions`; the callers pass all five.

/// **Q1 — one aggregate for the WHOLE library.** B14, B6, B48, B49, B22, E6, E7.
///
/// ⚠️ **One row per library novel and one pass over `chapters` for all of them** — never
/// three aggregates per novel. `06-database.md` rule 8, and B9's 10 000 chapters per
/// novel: a library of 200 novels was 600 queries here, and this is 1.
///
/// ⚠️ **`COUNT(c.id)`, NOT `COUNT(*)`.** With a `LEFT JOIN`, `COUNT(*)` returns **1** for a
/// novel that has no chapter at all — a novel with no chapters would render a badge
/// reading *1 unopened*. A wrong number is worse than an absent one, and this is the
/// exact place the plan's § 3.2 warns about.
///
/// ⚠️ **`COALESCE(…, 0)` AND `ELSE 0`, and they are redundant on purpose.** `6-3`
/// measured that removing either leaves every row green, so claiming a test proves
/// either is required would be claiming something false. Two cheap guards on one
/// property; the property — a counter is `0`, never `null` — is what gets asserted.
///
/// ⚠️ **`queue_failed` AND `queue_error_code` ARE SEPARATE, AND THEY MUST BE.** A failed
/// queue item with an empty `error_code` is still a **stopped** queue — E6 is an
/// interrupted transfer, not a named cause — so a single column that only reports a
/// non-empty code would render it as `none`, i.e. as a queue that is merely not running
/// yet, on a novel the reader has already seen stall.
///
/// ⚠️ **THE QUEUE AND THE READING POSITION ARE SCALAR SUBQUERIES, NOT JOINS.** Both hang
/// off `chapters` by a second foreign key, so a second `LEFT JOIN` would multiply the
/// chapter rows and every `COUNT` here would become a fiction.
///
/// ⚠️ **`s.last_error_code` is the SOURCE's, so one broken site marks every novel it
/// published — which is what `6-4` writes and what B22 asks the row to show.**
const String unopenedCountsSql = '''
    SELECT n.id                                                  AS novel_id,
           n.title                                               AS title,
           n.author                                              AS author,
           n.cover_url                                           AS cover_url,
           n.source_id                                           AS source_id,
           n.added_at                                            AS added_at,
           n.last_checked_at                                     AS last_checked_at,
           s.last_error_code                                      AS last_error_code,
           COUNT(c.id)                                           AS total,
           COALESCE(SUM(CASE WHEN c.is_read = 0
                             THEN 1 ELSE 0 END), 0)              AS unopened,
           COALESCE(SUM(CASE WHEN c.downloaded_at IS NOT NULL
                             THEN 1 ELSE 0 END), 0)              AS downloaded,
           (SELECT COUNT(*)
              FROM queue_items q
              JOIN chapters qc ON qc.id = q.chapter_id
             WHERE qc.novel_id = n.id
               AND q.state = 'downloading')                      AS queue_running,
           (SELECT COUNT(*)
              FROM queue_items q
              JOIN chapters qc ON qc.id = q.chapter_id
             WHERE qc.novel_id = n.id
               AND q.state = 'failed')                           AS queue_failed,
           (SELECT q.error_code
              FROM queue_items q
              JOIN chapters qc ON qc.id = q.chapter_id
             WHERE qc.novel_id = n.id
               AND q.state = 'failed'
               AND q.error_code IS NOT NULL
               AND q.error_code <> ''
             ORDER BY q.queue_position DESC
             LIMIT 1)                                            AS queue_error_code,
           (SELECT MAX(rp.updated_at)
              FROM reading_positions rp
              JOIN chapters rc ON rc.id = rp.chapter_id
             WHERE rc.novel_id = n.id)                           AS last_read_at
      FROM novels n
      LEFT JOIN sources s ON s.id = n.source_id
      LEFT JOIN chapters c ON c.novel_id = n.id
     WHERE n.in_library = ?
     GROUP BY n.id
     ORDER BY n.added_at DESC, n.id ASC
    ''';

/// The one query a library title search runs. B45.
///
/// ⚠️ **THE `WHERE` IS THE IMPLEMENTATION OF B45, and there is no second clause to
/// relax.** No `author`, no `description`, no `status`, no `source_id`, no `OR`, no
/// `COALESCE`, no `UNION` — B45 says *title only*, and ADR-024 makes the absence of an
/// index on the other two columns part of that promise: an index nobody created cannot
/// be turned into a capability nobody promised.
///
/// ⚠️ **`ESCAPE '\'` IS NOT OPTIONAL AND `'\n'` IS NOT INVENTED BY THE APP.** SQLite string
/// literals do not process backslash escapes, so `'\'` is the one-character anticharre.
/// Without the clause the needle `%100\%%` reads as `%` + `100` + literal `%` + `%`, and
/// the query *"Chapter 100%"* returns *Chapter 1000* as well — **nothing fails**, the list
/// is simply false. That is the worst shape a search bug can take.
///
/// ⚠️ **`COLLATE NOCASE` FOLDS ASCII ONLY.** `sqlite3` 3.7.0 exposes no ICU, so `reunion`
/// does not find *Réunion*. `6-6` § 7 records that as an open question with a closing
/// trigger (reopening `schemaVersion` for a shadow column) rather than a silent fix.
/// ## ⚠️ **THE STRING BELOW IS RAW (`r'''`), AND THAT IS NOT A STYLE CHOICE**
///
/// A non-raw `'''` string processes `\'` as an escaped quote, so the SQL would arrive as
/// `ESCAPE ''` — an empty anticharre, and SQLite refuses it at prepare time with *"ESCAPE
/// expression must be a single character"*. The raw string is what makes `'\'` reach
/// SQLite as the one character it has to be.
const String titleSearchSql = r'''
    SELECT n.id AS novel_id
      FROM novels n
     WHERE n.in_library = ?
       AND n.title LIKE ? ESCAPE '\' COLLATE NOCASE
     ORDER BY n.added_at DESC, n.id ASC
    ''';
