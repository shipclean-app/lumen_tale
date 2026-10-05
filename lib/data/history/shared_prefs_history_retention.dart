// Lumen Tale — where the retention window is kept, and the count that must run BEFORE
// a purge.
//
// `data/` → `core` + `domain` (`02-architecture.md`).
//
// ## Why this file needs a repository at all
//
// [HistoryRetentionStore.countOlderThan] counts entries **about to** leave the window,
// because after a purge the answer is always zero. That is true about the past and
// useless about the decision the reader is making in front of them — so the store
// needs to reach the rows, which is what makes it more than a preference accessor.
//
// The dependency is declared and narrow: a **function** that counts, not a repository.
// `HistoryRepository` has no count method and adding one would put a "how many" onto
// an interface whose other methods are all "give me" or "delete", and the reader-facing
// question belongs to the screen while the counting belongs to whoever holds the rows.

import 'package:drift/drift.dart';
import 'package:lumen_tale/core/database/app_database.dart';
import 'package:lumen_tale/domain/history/history_repository.dart';
import 'package:lumen_tale/domain/history/history_retention.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Counts journal entries older than a cutoff.
///
/// ⚠️ A type and not a bare `Future<int> Function(DateTime)`: a bare function
/// parameter is a shape every caller can satisfy and nothing documents, and this one
/// carries the rule *strictly before the cutoff* inside its name.
typedef HistoryOlderThanCounter =
    Future<int> Function(DateTime cutoff, {required bool exclusive});

final class SharedPrefsHistoryRetentionStore implements HistoryRetentionStore {
  SharedPrefsHistoryRetentionStore(this._prefs, this._countOlderThan);

  final SharedPreferences _prefs;

  final HistoryOlderThanCounter _countOlderThan;

  /// ⚠️ Namespaced under `app.` like `theme-type`'s two keys, so the settings store has
  /// one convention and not two. `07-downloads-offline.md` rule 3 namespaces the
  /// *source* preferences `source_<id>`; this is app-level, not per-source.
  static const String retentionKey = 'app.historyRetention';

  @override
  Future<HistoryRetention> read() async {
    return HistoryRetention.fromStorage(_prefs.getString(retentionKey));
  }

  @override
  Future<void> write(HistoryRetention window) async {
    // `setString` returns `Future<bool>` and a `false` is a **platform refusal**, not an
    // exception. Ignoring it would leave the screen showing a window that was never
    // stored — which is the exact state C8 forbids: a displayed setting that the app
    // cannot honour.
    //
    // B24, and the same contract as `SharedPrefsThemePreferences`: the failure must be
    // **visible**, so the caller's control snaps back and says why.
    final bool ok = await _prefs.setString(retentionKey, window.name);
    if (!ok) {
      throw SettingsPersistenceException(retentionKey, window.name);
    }
  }

  @override
  Future<int> countOlderThan(DateTime cutoff) {
    // ⚠️ **Strictly** older, matching the purge predicate exactly.
    //
    // The purge deletes `opened_at < cutoff`, so a count of "what will go" computed as
    // `<= cutoff` would announce one entry **more** than will disappear. A reader who
    // reads a notice saying "three entries will be dropped" and watches two vanish has
    // been told a falsehood by a count, and the count is the part that is supposed to
    // be the honest one.
    return _countOlderThan(cutoff, exclusive: true);
  }
}

/// The refusal a `shared_preferences` write can make, typed.
///
/// ⚠️ **Not** an `AppException`: that hierarchy is for failures the UI maps to a
/// message by *cause* (B22), and this cause is "the operating system declined to write
/// a byte". The two are different kinds of thing, and merging them would make
/// `13-error-handling.md` rule 5's mapping carry a case it has no sentence for.
final class SettingsPersistenceException implements Exception {
  const SettingsPersistenceException(this.key, this.value);

  /// The preference key. A **key**, never a value the reader typed.
  final String key;

  /// The value that was refused. The enum's `name`, never free text.
  final String value;

  @override
  String toString() => 'SettingsPersistenceException($key)';
}

/// The drift-backed counter [SharedPrefsHistoryRetentionStore] is given.
///
/// ⚠️ **A separate top-level function rather than a method on the repository**, for the
/// reason in this file's header: `HistoryRepository` has no count method and does not
/// acquire one. Adding one would put a "how many" onto an interface whose methods are
/// otherwise "give me" or "delete", and every implementation of it would then have to
/// answer a question the screen — not the journal — is asking.
Future<int> countHistoryEntriesOlderThan(
  AppDatabase db,
  DateTime cutoff, {
  required bool exclusive,
}) async {
  // ⚠️ **The predicate is built by drift's builder, not written as SQL text.**
  //
  // A first version interpolated `'${exclusive ? '<' : '<='}'` into a `customSelect`
  // and left a comment saying it mirrored `purgeOlderThan`. That is two statements of
  // one rule, one of them a string, and a test cannot compare them without parsing SQL.
  // Here the expression **is** the statement: `purgeOlderThan` uses
  // `isSmallerThanValue`, and so does this, so the announcement count and the delete
  // predicate are the same expression over the same column.
  final Expression<bool> predicate = exclusive
      ? db.historyEntries.openedAt.isSmallerThanValue(cutoff)
      : db.historyEntries.openedAt.isSmallerOrEqualValue(cutoff);

  final Expression<int> count = db.historyEntries.id.count();

  final TypedResult row =
      await (db.selectOnly(db.historyEntries)
            ..addColumns(<Expression<Object>>[count])
            ..where(predicate))
          .getSingle();

  // ⚠️ **`?? 0`, and the fallback is load-bearing.** `COUNT(*)` is never NULL — SQLite
  // returns 0 over an empty range — but drift types the read as `int?` because it
  // cannot know which expressions are non-nullable.
  //
  // A nullable count makes "how many will be dropped?" a **screen's decision**: the
  // screen would have to decide whether `null` means zero, means unknown, or means
  // show nothing, and the three readings produce three different notices. B48's
  // argument, verbatim, and this is the same one — the number must not be a decision.
  //
  // The notice is the one thing on this screen that must never be ambiguous: a reader
  // deciding whether to shorten their history needs a count, and "we could not count"
  // is not an answer they can act on.
  return row.read(count) ?? 0;
}
