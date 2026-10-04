// Lumen Tale — what the library screen shows, which is a THIRD type.
//
// `2-5` § 2.2. Three types for three questions, and merging them is how `features/` ends up
// importing drift:
//
// | type | the question it answers |
// |---|---|
// | `Novel` | what the **site** publishes |
// | `NovelRow` (drift) | what the **database** holds |
// | `LibraryEntry` | what the **library screen** displays |
//
// `02-architecture.md` forbids `features/` importing drift, so the screen cannot take the row.

/// One row of the library, as the screen shows it.
final class LibraryEntry {
  const LibraryEntry({
    required this.id,
    required this.sourceId,
    required this.sourceName,
    required this.title,
    required this.inLibrary,
    required this.unopenedCount,
    required this.chapterCount,
    required this.downloadedCount,
    this.author,
    this.coverUrl,
    this.addedAt,
    this.lastCheckedAt,
  });

  /// B3 — stable between sessions, and this is what the route carries.
  final String id;

  /// B2 — the originating site, never deduced from the title.
  final String sourceId;

  /// Resolved by the registry for display. **The name itself comes from the compiled registry
  /// (ADR-013), not from a column** — a stored name freezes, and a renamed site would keep
  /// answering with the old thing.
  final String sourceName;

  /// B40 — shown verbatim. Never normalised, never rewritten: the normalisation in
  /// `normalizeForSimilarity` exists to find a collision, never to be displayed.
  final String title;

  /// ADR-024 — **displayed, never searched**. Nullable because a site may publish no author,
  /// and a library that shows a dash where the site showed nothing is inventing a fact.
  final String? author;

  final String? coverUrl;

  /// B11 — keeping and following are one act, so one flag.
  final bool inLibrary;

  /// B14 / B48 — `count(chapters.is_read = 0)` for this novel.
  ///
  /// ⚠️ **Derived, never stored, never estimated, never stale.** A stored unread count drifts
  /// the moment a chapter is opened, and a badge that disagrees with the chapter list is worse
  /// than no badge.
  final int unopenedCount;

  /// The site's own chapter count, for the "148 sur 480" pair.
  final int chapterCount;

  /// B48 — `count(downloaded_at is not null)`.
  ///
  /// ⚠️ **The mark, not the file.** ADR-022 makes the mark the fact; an interrupted download
  /// has no mark (E6), and B33's deliberate deletion clears it — so an existence probe could
  /// not tell "removed on purpose" from "lost".
  final int downloadedCount;

  /// Null while `inLibrary` is false, which is what `architecture.md` § 4.1 requires.
  final DateTime? addedAt;

  /// B49 — **null means "never checked"**, which is a different claim from "checked at the
  /// epoch". A catalogue browse is not a novel check.
  final DateTime? lastCheckedAt;

  /// The "148 sur 480" pair, or `null` when the site published no count.
  String? get progressLabel =>
      chapterCount <= 0 ? null : '$downloadedCount / $chapterCount';

  @override
  bool operator ==(Object other) =>
      other is LibraryEntry &&
      other.id == id &&
      other.inLibrary == inLibrary &&
      other.unopenedCount == unopenedCount &&
      other.downloadedCount == downloadedCount &&
      other.title == title &&
      other.addedAt == addedAt;

  @override
  int get hashCode => Object.hash(
    id,
    inLibrary,
    unopenedCount,
    downloadedCount,
    title,
    addedAt,
  );

  @override
  String toString() =>
      'LibraryEntry($title, inLibrary: $inLibrary, unread: $unopenedCount)';
}
