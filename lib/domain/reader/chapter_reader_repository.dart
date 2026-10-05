// Lumen Tale — the reader's repository. **`2-4` § 3.2: the network guarantee lives in
// this TYPE, not in a code review.**
//
// ## What makes "zero network calls" structural rather than promised
//
// There are **no** parameters here for a source, a URL, or a revalidation nonce, and the
// implementation takes no `dio`, no `HttpClient` and no `SourceManager`. So:
//
// ```text
// grep -rn "core/network"          lib/domain/reader   → no results
// grep -rn "dio\|HttpClient"       lib/domain/reader   → no results
// grep -rn "SourceManager\|sources" lib/domain/reader  → no results
// ```
//
// A row asserts those greps stay empty **and** a fake `dio` counts zero requests while a
// downloaded chapter is opened with connectivity off. The first is what stops the dependency
// being added; the second is what proves the behaviour.
//
// ⚠️ **What would NOT be a proof:** "the app does not normally fetch in this case." A request
// counter in a test is a proof; a sentence is not. And a conditional `if (no file) try
// fetching anyway` would pass a review while breaking the promise — which is why the
// capability is absent from the signature rather than merely unused in the body.
//
// ## What `2-4` deliberately does not do
//
// It **retrieves nothing**. An unstored chapter offers "Download this chapter" and `3-3`
// executes it. An implementation that fetched here would have two paths, and the zero-counter
// test would only ever prove one of them.

import 'package:lumen_tale/domain/library/reading_position_store.dart';
import 'package:lumen_tale/domain/reader/chapter_document.dart';

/// Reading a chapter that is **already on this phone**. Nothing else.
abstract interface class ChapterReaderRepository {
  /// Decides which reading state [chapterId] is in, and returns it.
  ///
  /// ⚠️ **No write to `chapters.downloadedAt`, ever.** That is `2-3`'s half of ADR-022 and
  /// the repository that reads this mark must not be able to set it — a reader that marked
  /// as it read would re-mark a chapter whose file it had just found missing.
  /// ⚠️ **`chapterId` and `hasConnection`, and NOTHING ELSE.**
  ///
  /// `2-3` names a stored file after the chapter's **ordinal**, and the ordinal belongs to
  /// the row this method has already read. Passing `novelId` and `ordinal` in would let a
  /// caller open chapter A's file under chapter B's ordinal — a wrong chapter, with correct
  /// looking data and no error anywhere. So the two are derived from the row, and a caller
  /// that gets them wrong cannot.
  Future<ChapterDocument> readChapter({
    required String chapterId,
    required bool hasConnection,
  });

  /// B13 — marks the chapter opened. **Idempotent**: an already-read chapter does not get
  /// its `read_at` rewritten, or "opened when" would change on every reopening and B17's
  /// ordering of `history_entries` by `opened_at` would stop meaning anything.
  Future<void> markOpened(String chapterId);

  /// The neighbouring chapter **by ordinal**, `null` at either end.
  ///
  /// ⚠️ **Never by `number`, never by `name`.** `number` is `-1` when unparseable and
  /// restarts at zero per volume; `name` is not unique, and E10 forbids treating it as if
  /// it were. `2-7` needs this to scroll on from one chapter into the next.
  Future<ChapterNeighbour?> neighbour({
    required String chapterId,
    required NeighbourDirection direction,
  });

  /// B16/B17 — the position operations, **delegated and not re-declared**.
  ///
  /// ⚠️ **`ReadingPositionStore` already owns these**, and `2-6`'s `restorePosition` reads
  /// the same rows. Declaring `readPosition`/`writePosition` here as well would give one
  /// concept two interfaces, and the only thing that decides which one a caller used is
  /// which file it imported. So the screen composes the store instead, and this interface
  /// stays three methods wide — which is also what makes its surface auditable by eye.
  ReadingPositionStore get positions;
}

/// A neighbouring chapter's identity.
final class ChapterNeighbour {
  const ChapterNeighbour({required this.chapterId, required this.ordinal});

  final String chapterId;

  /// B9 — the ordinal, carried so `2-7` can render "next" without a second query.
  final int ordinal;

  @override
  bool operator ==(Object other) =>
      other is ChapterNeighbour &&
      other.chapterId == chapterId &&
      other.ordinal == ordinal;

  @override
  int get hashCode => Object.hash(chapterId, ordinal);

  @override
  String toString() => 'ChapterNeighbour($chapterId, #$ordinal)';
}

enum NeighbourDirection { previous, next }
