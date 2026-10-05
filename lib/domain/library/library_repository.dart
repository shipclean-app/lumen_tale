// Lumen Tale — the library, and the four things a reader can do to it.
//
// `2-5` § 2.2. `domain/library/` — **not** `data/`, because this is the interface `features/`
// programs against and neither the screen nor the interactors should know it is drift.
//
// ## ⚠️ ONE membership write method, and the TYPE is what enforces B12
//
// `addFromCatalogue(Novel)` — not `addById`, not `addMany`, not `setFollowed`. B12 says a
// novel enters the library through an **explicit action on a novel the reader opened from a
// site**, and the only way to say that in a signature is for the parameter to be the novel
// **itself**. An identifier could have come from a list, a restored navigation stack or a deep
// link, and none of those three is a reader's action on a novel they have seen.
//
// ## ⚠️ The removal is an UPDATE, and that is not a style choice
//
// `chapters.novelId` is `ON DELETE CASCADE` and `history_entries.novelId` is
// `ON DELETE RESTRICT`, so `DELETE FROM novels` would erase the chapter metadata B14/B48
// count, and would **fail outright** as soon as one chapter had been opened. B32 says the
// downloads stay. All three facts hold at once only because the removal is
// `inLibrary = false`.
//
// ## ⚠️ Nothing here can reach the network
//
// No `dio`, no `HttpClient`, no `SourceManager` — and no parameter that would let a caller
// supply one. The only component that talks to a site is the "check for new chapters"
// button, which is an **interface hole**: B36/B38/B39's wire belongs to `6-3`/`6-4`/`6-10`,
// and `2-5` makes it visible and wired without executing it.

import 'package:lumen_tale/domain/library/library_entry.dart';
import 'package:lumen_tale/domain/library/similar_title.dart';
import 'package:lumen_tale/domain/sources/models/novel.dart';
import 'package:lumen_tale/domain/updates/library_check.dart';

/// B11, B12, B32 — the library.
abstract interface class LibraryRepository {
  /// The library, reactively. **Zero network calls by construction** (C14).
  Stream<List<LibraryEntry>> watchLibrary();

  /// B12 — [novel] comes from a catalogue result the reader opened.
  ///
  /// B40 — [onSimilarTitle] is called **before any write**, with the entries whose titles
  /// resemble the incoming one; the caller decides. Nothing is written when the title is
  /// empty, and nothing is written when the caller declines.
  Future<AddOutcome> addFromCatalogue({
    required Novel novel,
    required Future<SimilarTitleVerdict> Function(List<SimilarTitle> similar)
    onSimilarTitle,
  });

  /// The stored novel, or `null` when this id is not in the database.
  ///
  /// ⚠️ **It exists because `3-2`'s action row needs to know WHAT it is offering, and B12's
  /// button needs something to add.** `addFromCatalogue` takes a source-domain [Novel], so a
  /// screen reached from History — where the novel *is* stored — had no way to produce one.
  ///
  /// ⚠️ **A novel that is NOT in the library returns `null`, and that is not a defect.** It
  /// is the state B12's button appears in: there is no row to read, which is why the
  /// catalogue must carry the [Novel] it was given rather than expecting to look it up.
  /// See `Q-028` in `DECISIONS.md` — the first version of that question proposed reading the
  /// novel back by id *as the way to add one*, and that cannot work, because the row is
  /// absent precisely when the button is needed.
  ///
  /// ⚠️ **Null is a normal answer, not a failure**, so this returns a value and never
  /// throws: a stale identifier or a restored stack is a state of the world.
  Future<Novel?> readNovel(String novelId);

  /// B32 — removes the entry.
  ///
  /// ⚠️ **Deletes no `chapters` row, no `.md` file, no `history_entries` row and no
  /// `reading_positions` row.** Returns the number of downloaded chapters, read by SQL
  /// aggregate **before** the write so the dialog can quote a true figure.
  Future<RemoveOutcome> removeFromLibrary(String novelId);

  /// Undoes [removeFromLibrary]. **Restores the entry and nothing else** — and there is
  /// nothing else, because the removal destroyed nothing (B32).
  Future<void> restoreToLibrary(String novelId);

  /// B48 — the exact count of chapters whose mark is set, by SQL aggregate.
  Future<int> countDownloadedChapters(String novelId);

  /// B2 — the display name of a registered source, or `null` for an id no longer
  /// registered.
  ///
  /// ⚠️ **Resolved by the registry, not by a database column** (ADR-013). Storing a source's
  /// name would freeze it: a site renamed, and the library would keep calling it the old
  /// thing.
  String? sourceNameOf(String sourceId);
}

/// Why a novel was not added.
enum AddRejection {
  /// The site published no usable title, or no URL to reopen the page with.
  ///
  /// ⚠️ **A rejection, not a warning.** B10: a novel without a name is not displayable, and
  /// B12: an empty row in a library is not a discovery. Nothing is written at all.
  emptyTitle,

  /// B40 — the reader was offered the existing entries and chose not to add a second.
  ///
  /// ⚠️ **Declining is the DEFAULT**, and so is dismissing the dialog. The easiest gesture on
  /// a device with no cloud backup (C8) must not be the one that adds.
  declinedForSimilarTitle,

  /// B24 — the write failed. **The row is still there**, at `inLibrary == false`; nothing is
  /// optimistic.
  storeUnwritable,
}

/// The result of an add, and every branch of § 3.1.
final class AddOutcome {
  const AddOutcome._({
    this.rejection,
    this.similar,
    this.addedDespiteSimilarTitle = false,
    this.wasAlreadyInLibrary = false,
  });

  /// The novel is in the library. [wasAlreadyInLibrary] is the **idempotent** branch — B11:
  /// keeping and following are one act, so a second tap is a no-op and **not** an error, and
  /// **not** a toast.
  const AddOutcome.added({
    bool alreadyInLibrary = false,
    bool despiteSimilarTitle = false,
  }) : this._(
         wasAlreadyInLibrary: alreadyInLibrary,
         addedDespiteSimilarTitle: despiteSimilarTitle,
       );

  /// Nothing was written.
  const AddOutcome.rejected(
    AddRejection reason, {
    List<SimilarTitle>? similarTitles,
  }) : this._(rejection: reason, similar: similarTitles);

  final AddRejection? rejection;

  /// The entries the reader was offered, when the rejection was [AddRejection
  /// .declinedForSimilarTitle]. Carried on the outcome so the screen can show what it would
  /// have added — the dialog is not a separate object the caller has to keep alive.
  final List<SimilarTitle>? similar;

  /// ⚠️ **B40: "nothing is ever merged".** The second entry is a second entry, and this flag
  /// is what lets the screen say so after the fact.
  final bool addedDespiteSimilarTitle;

  final bool wasAlreadyInLibrary;

  bool get isAdded => rejection == null;

  @override
  String toString() => isAdded
      ? 'AddOutcome.added(already: $wasAlreadyInLibrary, '
            'despiteSimilar: $addedDespiteSimilarTitle)'
      : 'AddOutcome.rejected(${rejection!.name})';
}

/// The result of a removal, and every branch of § 3.3.
final class RemoveOutcome {
  const RemoveOutcome({
    required this.downloadedChapterCount,
    required this.wasAlreadyRemoved,
  });

  /// ⚠️ **Read BEFORE the write**, so the dialog quotes a figure that was true when the reader
  /// was asked. B48: derived, exact, never estimated.
  final int downloadedChapterCount;

  /// The idempotent branch: two library extinctions must not produce two confirmations.
  final bool wasAlreadyRemoved;
}

/// The local reads and writes a **check** needs — the `6-3 → 6-4` boundary.
///
/// ⚠️ **B38 IS THE ABSENCE OF METHODS, NOT THE PRESENCE OF DISCIPLINE.** There is no
/// `enqueue`, no `download`, no `writeChapterBody` and no `markDownloaded` here, so a
/// slice that needs one cannot add it without every reader of this file being a reader of
/// that decision. `drift_library_check_store.dart` is the only implementation and its
/// only writes are `novels.last_checked_at`, `sources.last_error_code` and `chapters`
/// rows.
abstract interface class LibraryCheckStore {
  /// Every novel with `in_library = 1`, in library order, as a snapshot.
  ///
  /// ⚠️ **NO OTHER PREDICATE.** Not "not checked recently", not "not finished", not
  /// "first fifty". B39 — *no novel is skipped for any reason* — and a filter here would
  /// be exactly the skip the rule forbids while staying invisible: `run()` would report a
  /// total the reader never chose.
  ///
  /// ⚠️ **Taken once per pass.** A library that gains a novel mid-pass does not get it into
  /// this run, because the total has already been shown on screen.
  Future<List<LibraryNovelRef>> listLibraryNovels();

  /// Whether this source is switched on **locally**.
  ///
  /// ⚠️ **A FIFTH METHOD, AND IT IS HERE RATHER THAN ON `Source`.** § 3.2's guard 0 asks
  /// whether a source is enabled, and `enabled` is a column on `sources` — the registry
  /// has no such flag, and putting one on `Source` would make a code-side setting look
  /// like a platform feature (B41).
  ///
  /// ⚠️ **AN ID WITH NO ROW IS ENABLED.** `sources` is only written once something has
  /// been said about a source, so a fresh install has no rows at all; reading "absent" as
  /// "off" would make every novel fail its first check with nothing on screen to explain
  /// it.
  Future<bool> isSourceEnabled(String sourceId);

  /// Records that [novelId] was looked at, at [at]. **B49.**
  ///
  /// ⚠️ **Called on success, and on E9 alone.** Never on a failure that means "we could
  /// not look": writing the timestamp there would make "we could not look" render as "we
  /// looked and there was nothing", which is the exact substitution B49 forbids.
  ///
  /// ⚠️ **It also clears `sources.last_error_code` for [novelId]'s OWN source and only
  /// that one** (§ 3.2 branch 6, B23): a broken site does not stop being broken because
  /// another site succeeded.
  Future<void> recordChecked(String novelId, DateTime at);

  /// Records the typed cause for [novelId]. **B22 / B24.**
  ///
  /// Writes `sources.last_error_code` for the novel's source so `updates.md` can show
  /// *Could not check* without having attempted a fetch, and it **never** writes
  /// `last_checked_at`.
  ///
  /// ⚠️ **`failedSelector` IS NOT A PARAMETER.** The selector is evidence for the OWNER
  /// (`18-external-contracts.md`, C5), not state a reader can be shown, so it rides on
  /// `NovelCheckFailed` and stops there. Storing it in a column would make that column
  /// carry a CSS class name, which is what `architecture.md` § 5.2 forbids.
  Future<void> recordCheckFailure(String novelId, CheckFailureKind kind);

  /// Merges a freshly read chapter list into `chapters`, returning rows **actually
  /// added**.
  ///
  /// ⚠️ **`INSERT OR IGNORE` on `chapters.id`, and nothing else.** The id is
  /// `SourceId.forChapter`, so a chapter already held cannot duplicate (B3); and because
  /// `IGNORE` never updates, an existing row keeps `is_read`, `read_at` and
  /// `downloaded_at` exactly as the reader left them (B13, B6, E16).
  Future<int> mergeChapterList(String novelId, List<NewChapter> fresh);
}

/// A library novel, reduced to what a check reads.
///
/// ⚠️ **No cover, no description, no chapter count.** Each of those would be a second
/// query per novel inside a loop that visits every novel — N+1 on a library the reader
/// chose to keep, which B9 says may hold 10 000 chapters per novel
/// (`06-database.md` rule 8).
final class LibraryNovelRef {
  const LibraryNovelRef({
    required this.novelId,
    required this.sourceId,
    required this.title,
    required this.url,
  });

  /// B3 — the stored, derived id.
  final String novelId;

  /// B2 — the one site this novel came from, resolved through `SourceManager`.
  final String sourceId;

  /// B10 — the site's own text, verbatim, as stored.
  final String title;

  /// The stored relative path, so the source can reopen the page. **Reconstruction is the
  /// source's job** — `HttpSource` composes `'$baseUrl$path'`, and a hand-joined absolute
  /// URL here would be the one place in the app that knows how a site spells its own URLs.
  final String url;

  @override
  String toString() => 'LibraryNovelRef($novelId, $sourceId)';
}
