// Lumen Tale — the two facts B49 keeps apart, in one value and never one column.
//
// `updates.md` § 4 renders them as two separate chips on the same row, and that is the
// shape of the data too: a **count** and a **verification**, neither derivable from the
// other. Putting them together here is a convenience for the four surfaces that read
// them; putting them in one column would be a design mistake, and this file is where
// that boundary is written down.
//
// Pure Dart. `domain` carries no Flutter import (`02-architecture.md`).

import 'package:lumen_tale/core/error/source_failure.dart';

/// What the app knows about **when it last looked** at a novel. B49.
///
/// Sealed, because "never looked", "epoch 0" and "this instant" are three different
/// claims and the reader must be able to tell them apart. The same argument
/// `failure-discriminator` makes about a read outcome, and for the same reason: a
/// nullable `DateTime` would let `null` render as "just now" in one place and "never
/// checked" in another.
sealed class Verification {
  const Verification();

  /// B49: *The app never implies there is nothing new for a novel it has not checked —
  /// it says it has not looked.*
  ///
  /// Every surface must branch on this. A screen that renders a count without also
  /// rendering its freshness is claiming the count implies freshness, which is exactly
  /// what B49 forbids.
  bool get saysSomethingAboutFreshness;
}

/// `lastCheckedAt is null`.
///
/// **Never** rendered as an epoch, **never** as "just now", and **never** omitted —
/// `library.md` § 8: *null renders **Never checked***.
final class NeverChecked extends Verification {
  const NeverChecked();

  @override
  bool get saysSomethingAboutFreshness => false;

  @override
  bool operator ==(Object other) => other is NeverChecked;

  @override
  int get hashCode => (NeverChecked).hashCode;

  @override
  String toString() => 'NeverChecked';
}

/// The novel was checked at this instant, and the check **succeeded**.
final class CheckedAt extends Verification {
  const CheckedAt(this.at);

  final DateTime at;

  @override
  bool get saysSomethingAboutFreshness => true;

  @override
  bool operator ==(Object other) => other is CheckedAt && other.at == at;

  @override
  int get hashCode => Object.hash(CheckedAt, at);

  @override
  String toString() => 'CheckedAt($at)';
}

/// The last attempt to check this novel **failed**. B22 is what makes this
/// distinguishable from "checked and there is nothing new", and **E9** is one of its
/// causes.
///
/// ⚠️ **A failure never changes `unopenedCount`.** `updates.md` § 4 is explicit: *the
/// line above the list is the heart of the screen: losing contact with a site changes
/// the **verification**, never the **number**.* A number that moves because a check
/// failed is a number the reader cannot reason about.
final class CouldNotCheck extends Verification {
  const CouldNotCheck(this.failure);

  /// Typed, never a string: `13-error-handling.md` rule 5 and `architecture.md` § 5.2.
  final SourceFailure failure;

  @override
  bool get saysSomethingAboutFreshness => true;

  @override
  bool operator ==(Object other) =>
      other is CouldNotCheck && other.failure == failure;

  @override
  int get hashCode => Object.hash(CouldNotCheck, failure);

  @override
  String toString() => 'CouldNotCheck(${failure.runtimeType})';
}

/// The local counting model, as one novel's worth of it.
final class LibraryUpdateFact {
  const LibraryUpdateFact({
    required this.novelId,
    required this.unopenedCount,
    required this.totalCount,
    required this.downloadedUnopenedCount,
    required this.verification,
  });

  final String novelId;

  /// **B14 / B48 — derived, never stored.** How many chapters of this novel the reader
  /// has not opened. Exact, never an estimate, never stale.
  ///
  /// Computed over **chapter-list metadata**, so it is correct for a novel with **zero
  /// downloaded chapters**. There is no `unreadCount` column anywhere in the schema,
  /// and `architecture.md` § 4.7 says why: *a stored count is a second source of truth
  /// free to disagree with the rows it counts.*
  final int unopenedCount;

  /// `COUNT(chapters.id)` for this novel. **Not** a check result — it is what the app
  /// last learned the site listed, held locally.
  final int totalCount;

  /// How many of the unopened are also on the phone.
  ///
  /// `library.md` § 8 renders this as *12 of 480 downloaded* — a pair, never a partial
  /// number presented as complete.
  final int downloadedUnopenedCount;

  /// **B49 — the verification half.** Carried here and not nullable, so no caller can
  /// read a count without also being able to say what is known about its freshness.
  final Verification verification;

  /// Chapters the reader **has** opened. Derived as the complement, so it cannot
  /// disagree with [unopenedCount] — two stored numbers that add up to [totalCount] is
  /// precisely the construction B48 forbids.
  int get openedCount => totalCount - unopenedCount;

  /// ⚠️ **Not** a promise that downloading everything will make `unopenedCount` zero.
  /// Opening is a local act, and B14's count is about chapters, not about the network.
  int get unreadAndDownloaded => downloadedUnopenedCount;

  @override
  bool operator ==(Object other) =>
      other is LibraryUpdateFact &&
      other.novelId == novelId &&
      other.unopenedCount == unopenedCount &&
      other.totalCount == totalCount &&
      other.downloadedUnopenedCount == downloadedUnopenedCount &&
      other.verification == verification;

  @override
  int get hashCode => Object.hash(
    novelId,
    unopenedCount,
    totalCount,
    downloadedUnopenedCount,
    verification,
  );

  @override
  String toString() =>
      'LibraryUpdateFact($novelId, unopened=$unopenedCount/$totalCount, '
      '$verification)';
}

/// The interface `domain` owns for the counting model; `data` implements it
/// (`02-architecture.md` § Repository pattern).
///
/// ⚠️ **No method takes a connection flag, and no method takes a clock.** Both
/// omissions are load-bearing:
///
/// * **No connection flag** is **B38** — « a check never downloads ». This model has no
///   path to `queue_items` at all, so it cannot be made to download by giving it a
///   permission. `architecture.md` § 6.6 records that a `6-3 → 5-2` edge once existed,
///   said nothing, cost nothing, and pushed half of SC-3 to three quarters of a
///   twelve-wave graph. The structural answer is what this interface is.
/// * **No clock** — `updatedAt`-shaped facts are **inputs** ([markOpened]'s `at`,
///   `6-4`'s `lastCheckedAt`), never something the model reads from a clock. A method
///   with a hidden clock cannot be tested and cannot be reasoned about.
abstract interface class UnopenedCountRepository {
  /// The fact for one novel, or `null` when the novel is unknown.
  Future<LibraryUpdateFact?> factFor(String novelId);

  /// The fact for every kept novel, ordered by unopened count descending.
  ///
  /// B39's `TerminalLine` says *All 23 novels checked · none skipped* — and that honesty
  /// is the **caller's** to keep. This returns the library as it is, complete, and never
  /// filters by recency or by "probably finished".
  Stream<List<LibraryUpdateFact>> watchLibraryFacts();

  /// **B13** — a chapter was opened, so its marker is cleared.
  ///
  /// Idempotent in its **effect** and in `readAt`: re-opening an already-read chapter
  /// writes nothing, so `readAt` stays the instant it was first reached. B14's count is
  /// unaffected by whether the chapter was downloaded.
  Future<void> markOpened(String chapterId, {required DateTime at});

  /// `updates.md` § 3 `BulkSection`: *Mark everything as read*, for one novel.
  ///
  /// ⚠️ Touches `is_read` and `read_at` **only**. It must never write
  /// `novels.last_checked_at` — a bulk local write is not a check, and B49 says a novel
  /// is only ever *checked* when the app looked at its site. That is why `6-3` does not
  /// declare an edge to `6-4`: the two facts are written by different code.
  Future<int> markAllOpened(String novelId, {required DateTime at});
}
