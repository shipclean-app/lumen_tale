// Lumen Tale — one pass over the library, as values.
//
// `6-4` § 2.2. Pure Dart: no Flutter, no drift, no network. `02-architecture.md` makes
// `domain` the pure layer, and the reason this file is *strictly* pure is `6-10`:
// the same interactor runs in the main isolate and in the background isolate, so a
// single Flutter import here would make the foreground job impossible.
//
// ## ⚠️ The result is a LIST, and its length is the evidence
//
// B39 — *a check visits every novel; no novel is skipped for any reason* — cannot be
// asserted from a total alone, because a total is also what a loop that skipped half
// its novels would have been configured with. [LibraryCheckResult.perNovel] has one
// entry per novel **including the ones that failed**, and its length is what the test
// reads. A pass that quietly dropped a novel is invisible everywhere else.
//
// ## ⚠️ "checked and found nothing" and "could not check" are DIFFERENT TYPES
//
// B22. [NovelCheckOutcome] is sealed and has two arms, and `newChaptersFound == 0`
// is a legitimate value of [NovelChecked] — it is a result, not an absence. Neither
// arm can be expressed as the other, which is the whole point: an `int` would say
// "0 new chapters" about a site that could not be reached.

import 'package:lumen_tale/core/error/app_exception.dart' as errors;

/// Why one novel's check failed.
///
/// ⚠️ **Six values, and a case outside the list is a case nobody thought about.**
/// `architecture.md` § 5.2's taxonomy filtered to what a *check* can produce:
/// `storageFull` is a write failure and belongs to `5-3`, and a parse failure of a
/// **stored file** is `6-2`'s — neither can happen here, because this slice reads a
/// site and writes rows.
///
/// This is a re-declaration rather than a reuse of `SourceFailure` on purpose. A
/// stored failure carries a host, a status and a selector, and three of those six
/// are not about a novel — `6-3`'s [CouldNotCheck] holds the site's cause and this
/// holds the per-novel verdict, because B22 needs *both* "which site" and "which
/// novel", and one enum cannot answer two questions without a `which` parameter.
enum CheckFailureKind {
  /// E5 / B15 — no connection. **`last_checked_at` stays `null`**: we did not look.
  noConnection,

  /// C7 — a `429`, carrying `Retry-After` from the header. The pass gives the wait
  /// back to the reader rather than insisting.
  rateLimited,

  /// E4 — the page parsed and held none of the elements the source selects. Never
  /// "nothing new": that is the one answer a broken site must not produce.
  sourceLayoutChanged,

  /// A 5xx, a disabled source, or one whose id no longer resolves.
  sourceUnavailable,

  /// E9 — the site answered, and the novel is gone. **The only failure that writes
  /// `last_checked_at`**, because we did look and did see.
  itemRemovedAtSource,

  /// E8 — the page loaded and produced nothing readable.
  parseFailed,
}

/// The result for **one** novel. Two arms, and neither can be built from the other.
sealed class NovelCheckOutcome {
  const NovelCheckOutcome();
}

/// The site was read.
///
/// ⚠️ [newChaptersFound] may legitimately be `0`. That is what a check found, and
/// rendering it as an absence is B22's failure in its purest form.
final class NovelChecked extends NovelCheckOutcome {
  const NovelChecked({
    required this.newChaptersFound,
    required this.siteChapterCount,
    required this.checkedAt,
  });

  /// Rows **actually added** by `mergeChapterList`, not "how many the site listed".
  ///
  /// ⚠️ The distinction is the whole of B14/B48: re-checking a novel whose chapters
  /// are all known finds *zero new rows* while its unopened count is unchanged, and a
  /// pass that reported the site's chapter count here would make every check announce
  /// a library's entire length as new.
  final int newChaptersFound;

  /// What the site published, for `updates.md`'s own comparison. Never stored.
  final int siteChapterCount;

  final DateTime checkedAt;

  @override
  bool operator ==(Object other) =>
      other is NovelChecked &&
      other.newChaptersFound == newChaptersFound &&
      other.siteChapterCount == siteChapterCount &&
      other.checkedAt == checkedAt;

  @override
  int get hashCode =>
      Object.hash(NovelChecked, newChaptersFound, siteChapterCount, checkedAt);

  @override
  String toString() =>
      'NovelChecked(new: $newChaptersFound, site: $siteChapterCount)';
}

/// The site could not be read.
///
/// ⚠️ [failedSelector] is filled for [CheckFailureKind.sourceLayoutChanged] only, and
/// it is the ONE artefact this failure produces: C5 says repairing a site must be
/// deliverable as a file, so the selector that came back empty is the evidence the
/// owner needs, and it is never rendered as prose (C12) — a CSS class name in a
/// sentence is not something a reader can describe.
final class NovelCheckFailed extends NovelCheckOutcome {
  const NovelCheckFailed({
    required this.kind,
    required this.sourceId,
    this.failedSelector,
  });

  final CheckFailureKind kind;

  /// B2 — which site, so `sources.last_error_code` can be written for **that** source
  /// and one broken site does not mark another's novels (`6-4` § 3.2 branch 6).
  final String sourceId;

  final String? failedSelector;

  @override
  bool operator ==(Object other) =>
      other is NovelCheckFailed &&
      other.kind == kind &&
      other.sourceId == sourceId &&
      other.failedSelector == failedSelector;

  @override
  int get hashCode =>
      Object.hash(NovelCheckFailed, kind, sourceId, failedSelector);

  @override
  String toString() => 'NovelCheckFailed(${kind.name}, $sourceId)';
}

/// A chapter the site publishes and the app does not yet hold.
///
/// ⚠️ **This is not a chapter body.** No text, no HTML, no absolute URL — only what
/// creating a `chapters` row needs. B38 is the mechanical reason: a value that could
/// carry a body is a value a check could start filling in.
final class NewChapter {
  const NewChapter({
    required this.id,
    required this.url,
    required this.name,
    required this.number,
    required this.ordinal,
  });

  /// B3 — `SourceId.forChapter(novelId, url)`, computed by the interactor.
  ///
  /// ⚠️ **Derived, never minted here.** It is what makes `INSERT OR IGNORE` on
  /// `chapters.id` a no-op for a chapter already held, which is B3's stability claim
  /// and the reason re-checking a novel cannot duplicate its list.
  final String id;

  /// Relative (`path + query`), `03-source-system.md` rule 3. Never a full URL.
  final String url;

  /// B10 — the site's own text, verbatim, and the **empty string** rather than an
  /// index when the site published none. `drift_chapter_list_repository.dart` renders
  /// *Untitled* for it; a fabricated title would be a sentence the app invented.
  final String name;

  /// `-1` when the site published no readable number. **Never `0`**: `0.99` is a real
  /// extra chapter and `-1` is "the site did not say" (`ChapterRecognition`).
  final double number;

  /// B9 — the site's own position. Never re-derived from [number].
  final int ordinal;

  @override
  String toString() => 'NewChapter($ordinal: $name)';
}

/// Progress of one pass, counted **in novels**.
///
/// ⚠️ [total] is fixed for the whole pass and never re-read. B39 is a promise about the
/// snapshot the reader was shown when they tapped, and a total that could rise mid-pass
/// would make "7 of 23" become "7 of 24" while the reader watches — a count that moves
/// under them is not the evidence B39 wants.
final class LibraryCheckProgress {
  const LibraryCheckProgress({
    required this.total,
    required this.done,
    required this.inFlightNovelId,
  });

  /// The library's size when the pass began.
  final int total;

  /// Novels **finished**, successes and failures alike.
  ///
  /// ⚠️ **Failures count as done.** A site that is broken would otherwise keep the
  /// counter turning for ever, and the reader would be watching a pass that can never
  /// finish because of something that will not fix itself.
  final int done;

  /// The novel being read now, or `null` before the first and after the last.
  ///
  /// ⚠️ **Never leaves this process.** It is not reported to the foreground job: a
  /// novel id in a `reportProgress` map becomes a string in an Android notification,
  /// which is drawn on a locked screen (C2, `17-security.md` rule 4).
  final String? inFlightNovelId;

  bool get isComplete => done >= total;

  /// B39's evidence, as one number: **the counter rises by exactly one per novel**.
  int get remaining => total - done;

  /// ⚠️ **VALUE EQUALITY, BECAUSE ITS TWO SIBLINGS HAVE IT.** `NovelChecked` and
  /// `NovelCheckFailed` below both compare by value, and this is the third arm of the same
  /// immutable family — a progress snapshot that cannot be compared is a snapshot a test can
  /// only assert field by field, which is how a counter's *total* ends up asserted while its
  /// `inFlightNovelId` is not. All three fields are scalars, so the derivation is total.
  @override
  bool operator ==(Object other) =>
      other is LibraryCheckProgress &&
      other.total == total &&
      other.done == done &&
      other.inFlightNovelId == inFlightNovelId;

  @override
  int get hashCode => Object.hash(total, done, inFlightNovelId);

  @override
  String toString() =>
      'LibraryCheckProgress($done/$total, inFlight: $inFlightNovelId)';
}

/// The result of one whole pass, and everything `6-10` needs to say about it.
final class LibraryCheckResult {
  const LibraryCheckResult({
    required this.startedAt,
    required this.finishedAt,
    required this.total,
    required this.perNovel,
    required this.interrupted,
  });

  final DateTime startedAt;
  final DateTime finishedAt;

  /// The snapshot B39 promised. Carried **on the result** because an interrupted pass
  /// is precisely the case where `perNovel.length` is *not* this number, and C8 says
  /// "it looked at 7 of 23" must be sayable.
  final int total;

  /// One entry per novel — **including the failed ones**.
  ///
  /// ⚠️ Shorter than [total] only when [interrupted], and that is a fact the reader is
  /// told rather than a defect the type hides.
  final List<NovelCheckOutcome> perNovel;

  /// `true` when the pass stopped before [total].
  ///
  /// ⚠️ **An interrupted pass is never reported as a successful one.** `6-10` § 3.3's
  /// branches 2, 3, 4, 5, 7 and 8 all produce this, and C8 is the rule they exist for.
  final bool interrupted;

  int get checkedCount => perNovel.whereType<NovelChecked>().length;

  int get failedCount => perNovel.whereType<NovelCheckFailed>().length;

  /// Chapters **discovered by this pass** — rows added, not the library's unopened
  /// total.
  ///
  /// ⚠️ B48: the unopened count is local, exact, and does not depend on any check. So
  /// a second number exists for "what did this pass find", and conflating the two would
  /// make the reader believe their badge moved because a check ran.
  int get discoveredChapters => perNovel.whereType<NovelChecked>().fold(
    0,
    (int sum, NovelChecked e) => sum + e.newChaptersFound,
  );

  @override
  String toString() =>
      'LibraryCheckResult(${perNovel.length}/$total, checked: $checkedCount, '
      'failed: $failedCount, interrupted: $interrupted)';
}

/// The run itself did not finish — the reader stopped it.
///
/// `13-error-handling.md` rule 7: cancellation is its own type, so the caller tells
/// "cancelled" from "failed" and shows no error.
///
/// ⚠️ **`AppException` is `sealed` in `core/error/`, so this file declares no seventh
/// subclass.** A `sealed` class cannot be extended outside its own library, and
/// `CancelledException` already carries exactly this meaning — a second cancellation type
/// would be two vocabulneraries for one gesture, and the caller's `on CancelledException`
/// would only catch one of them.
///
/// ⚠️ **The rows already written stay written.** A novel checked before the tap is a fact
/// about the site rather than a loss, and B7/B32 keep its chapters readable either way.
typedef CheckCancelledException = errors.CancelledException;
