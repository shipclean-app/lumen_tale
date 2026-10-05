// Lumen Tale — the day a line belongs to, computed and never stored.
//
// B17 orders by `opened_at` descending; B47 bounds by `opened_at`. **The day is
// neither of those**, and this file exists because it is the one thing in the
// journal that a naive implementation stores.
//
// ## Why it is never stored
//
// An entry opened at 23:40 belongs to *yesterday* under one timezone and to *today*
// under another. A stored day header is a fact about the moment the row was written,
// not about when the reader did the reading — so after a flight, or a DST boundary,
// a row sits under the wrong date and **no amount of re-reading the data fixes it**,
// because the data no longer says when the reader was there.
//
// So: the day is derived from `openedAt` and the phone's current calendar, on every
// read. A timezone change re-labels the groups, which is correct — the reader's
// "today" genuinely did change.
//
// Pure Dart, and it takes **no clock**: the caller passes `now`. A function that read
// a clock would be untestable at a boundary, and a boundary is exactly where this
// has to be right.

import 'package:lumen_tale/domain/history/history_entry.dart';

/// One day's worth of entries, newest first within the group.
final class HistoryDayGroup {
  const HistoryDayGroup({required this.date, required this.entries});

  /// Midnight, **local**, of the day this group holds.
  ///
  /// Local, because the header a reader reads is their own calendar's, and the same
  /// `openedAt` belongs to two different days in two different places.
  final DateTime date;

  final List<HistoryEntry> entries;

  @override
  String toString() => 'HistoryDayGroup($date, ${entries.length} entries)';
}

/// Splits [entries] — newest first — into consecutive local days.
///
/// [entries] must already be ordered `openedAt` descending; the order is **not**
/// re-established here, because sorting a caller's list is a mutation and `6-5` § 3.1
/// fixes the ordering in SQL where the index lives.
///
/// Two entries at the same millisecond have an **indeterminate** relative order, and
/// this function does not pretend otherwise: they land in the same group and keep the
/// order they arrived in. B17 says "most recent first", not "and here is a
/// tie-breaker" — inventing one would be a fact this layer does not have.
List<HistoryDayGroup> groupByLocalDay(List<HistoryEntry> entries) {
  final List<HistoryDayGroup> groups = <HistoryDayGroup>[];

  for (final HistoryEntry entry in entries) {
    final DateTime day = localMidnightOf(entry.openedAt);
    if (groups.isNotEmpty && isSameLocalDay(groups.last.date, day)) {
      groups.last.entries.add(entry);
      continue;
    }
    groups.add(HistoryDayGroup(date: day, entries: <HistoryEntry>[entry]));
  }

  return groups;
}

/// Midnight local time on the day [instant] falls in.
DateTime localMidnightOf(DateTime instant) {
  return DateTime(instant.year, instant.month, instant.day);
}

/// Two local midnights on the same calendar day.
///
/// ⚠️ **Compared field by field, not with `isAtSameMomentAs`**, and that is the
/// whole point of the helper. `DateTime(2026, 10, 3)` and
/// `DateTime.utc(2026, 10, 3)` are the same *instant* and different *days*: the first
/// is midnight in the phone's zone, the second is midnight UTC. A reader in Paris
/// opens a chapter at 00:30 local and the row must be under `3`, not under `2` — and
/// the instant comparison says it is the same day as the previous row while the
/// reader's calendar says otherwise.
bool isSameLocalDay(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

/// How many entries are older than [cutoff].
///
/// B47's *announcement* path, and it exists as its own function so the screen can
/// count before the purge — after a purge the answer is always zero, which is true
/// about the past and useless about the decision (`history.md` § 11.1).
int countOlderThan(List<HistoryEntry> entries, DateTime cutoff) {
  return entries
      .where((HistoryEntry entry) => entry.openedAt.isBefore(cutoff))
      .length;
}
