// Lumen Tale — the journal's contract, and what it deliberately does not take.
//
// `6-5` § 3.1–3.3. **No method here accepts a reading position, and none returns
// one** — except [readResumePoints], which is a separate query whose only purpose is
// to display one. That asymmetry is B46's implementation: the journal is bounded and
// erasable, the position is neither, so "resume where I stopped" is two queries and
// cannot be a join.
//
// Pure Dart: no drift, no Flutter (`02-architecture.md` — `domain` carries neither).

import 'package:lumen_tale/domain/history/history_entry.dart';
import 'package:lumen_tale/domain/history/history_retention.dart';

/// Read, write, and retain the journal.
abstract interface class HistoryRepository {
  /// The journal, newest first, bounded by [cutoff].
  ///
  /// ⚠️ **There is no `limit`, and there is no way to ask for one.** B47 bounds this
  /// list by *time*; a count bound is precisely the behaviour B47 refuses, and it
  /// punishes the intensive reader — who is the user this product is for. If a screen
  /// needs to render fewer rows, that is `ListView.builder`, which is a rendering
  /// decision, not a query.
  Future<List<HistoryEntry>> readEntries({required DateTime cutoff});

  /// Writes one line. Called by the slice that **opens** a chapter, never by the one
  /// that reads the journal.
  ///
  /// ⚠️ **Never writes `reading_positions`.** Opening a chapter writes the position
  /// through `2-6`'s own path; doing both here would make this journal a second
  /// source of truth for where the reader stopped, and B46's whole content is that
  /// it is not.
  Future<void> recordOpened({
    required String novelId,
    required String chapterId,
    required DateTime openedAt,
  });

  /// Deletes every entry older than [cutoff]. Returns how many.
  ///
  /// ⚠️ **One statement, over `history_entries` and nothing else.** No join with
  /// `reading_positions` appears in this method, and that absence is the whole of
  /// B46 — made falsifiable by reading the code rather than by believing a comment.
  /// A join here would be readable, reversible, testable, and would still destroy the
  /// reader's place in a product with no backup at all (C8).
  Future<int> purgeOlderThan(DateTime cutoff);

  /// Deletes the **whole** journal. Returns how many. Never touches positions.
  ///
  /// Distinct from [purgeOlderThan] on purpose: "erase everything" and "keep the last
  /// three months" are two different intentions, and the reader gets both.
  Future<int> clearAll();

  /// B17's second sentence — *"the chapter read most recently for a novel comes from
  /// the position record, not from this list"*.
  ///
  /// Expected shape: `reading_positions ⋈ chapters ⋈ novels`, ordered by
  /// `reading_positions.updated_at` descending. **No row of `history_entries` is read
  /// here.** If this ever derives "last chapter" by joining the journal, it is wrong —
  /// and clearing the journal is the one action a reader will take that would make it
  /// visibly wrong.
  Future<List<NovelResumePoint>> readResumePoints();
}

/// Where the retention window is kept. `shared_preferences`, never a table.
///
/// ⚠️ A table would make it per-library state; it is a device-level preference, and
/// two readers of one device are not a thing this product has (C13).
abstract interface class HistoryRetentionStore {
  /// The chosen window, or `HistoryRetention.defaultWindow` when nothing was chosen.
  Future<HistoryRetention> read();

  Future<void> write(HistoryRetention window);

  /// How many entries are **about to** fall outside [cutoff] — not how many have.
  ///
  /// The screen says this *before* the reader chooses
  /// (`history.md` § 11.1: *Entries older than three months will be dropped, oldest
  /// first*). Counting after the purge would report zero every time, which is a true
  /// statement about the past and a useless one about the decision.
  Future<int> countOlderThan(DateTime cutoff);
}
