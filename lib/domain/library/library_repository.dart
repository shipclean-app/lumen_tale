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
