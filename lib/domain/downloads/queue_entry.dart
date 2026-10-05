// Lumen Tale — one row of `queue_items`, seen by the domain.
//
// `5-1` § 2.2. The type the queue's own loop, the downloads screen and the novel's
// progress line all read, so it carries the joined `chapters`/`novels` facts a tile
// would otherwise have to query for itself.
//
// ## ⚠️ `novelId`, `chapterName` and the rest are NOT COLUMNS OF `queue_items`
//
// `queue_items` holds `id`, `chapter_id`, `state`, `queue_position`, `added_at`,
// `started_at`, `finished_at`, `attempts` and `error_code` — nine columns, and the
// seventh of them is a constant expressed as a column only because an implementation
// could change it (`app_database.dart` § QueueItems). Everything else here is joined
// from `chapters` and `novels` by `data/mappers/queue_mapper.dart`, because a
// `TableRow` must never cross `data/` → `features/` (`02-architecture.md`
// §Repository pattern) and a screen must never have to know that the queue has a
// chapter on the other end of a foreign key.
//
// ## ⚠️ THREE JOINED FIELDS ARE NOT IN THE PLAN'S LIST, AND EACH IS REQUIRED
//
// `sourceId`, `chapterUrl` and `ordinal` are additions to § 2.2, and § 3.3's own
// pseudocode needs the first of them (`cleanAndConvert(html, source: item.sourceId)`).
// Without them the runner could not resolve the `Source` that owns the chapter, could
// not build the `Chapter` the source's `fetchChapterContent` takes, and could not tell
// `2-3`'s `ChapterStore` where to write. They are properties of the chapter, joined
// like `chapterName`, and inventing three more queries to avoid three fields would be
// three chances to disagree with the row they came from.
//
// ## ⚠️ `chapterNumber` IS NULLABLE, NOT `int`
//
// § 2.2 writes `required int chapterNumber`, and that spelling cannot be honoured: the
// column's `-1` means **unparseable** (`03-source-system.md` rule 9) and `0` is a real
// chapter — an extra, an omake, an author's note. A `required int` carries `-1` to the
// screen, which is exactly what `ChapterEntry.number` and `ChapterListTile` exist to
// prevent. So the sentinel is mapped to `null` here, in the one place that knows it,
// and the plan's `int` is the storage fact rather than the domain one.
//
// ## ⚠️ HAND-WRITTEN, NOT `freezed`, and `ChapterEntry` is the reason
//
// The plan writes this as `@freezed`. `freezed` is a dev dependency and no type in
// `lib/` uses it; `LibraryEntry`, `ChapterEntry` and `HistoryEntry` are all hand-written
// values with `operator ==` and `hashCode`. One dialect per concern (`AGENTS.md`
// priority 4) beats the plan's spelling, and introducing the only `part` file in
// `domain/` would also make `dart run build_runner` a prerequisite for reading this one.

import 'package:lumen_tale/core/database/app_database.dart';

/// A line of the download queue, with the chapter it belongs to.
final class QueueEntry {
  const QueueEntry({
    required this.id,
    required this.chapterId,
    required this.novelId,
    required this.novelTitle,
    required this.chapterName,
    required this.sourceId,
    required this.chapterUrl,
    required this.ordinal,
    required this.chapterNumber,
    required this.state,
    required this.queuePosition,
    required this.addedAt,
    required this.attempts,
    required this.errorCode,
    this.startedAt,
    this.finishedAt,
  });

  /// `queue_items.id` — **generated at enqueue, never the chapter id.** Two queues of
  /// the same chapter must be able to coexist, and with the chapter id as the primary
  /// key the second would overwrite the first.
  final String id;

  /// The chapter this item will fetch.
  final String chapterId;

  final String novelId;

  /// The novel's own title, so a queue row names the book without a second query.
  final String novelTitle;

  /// B10 — the site's own title, verbatim.
  final String chapterName;

  /// B2 — the one site this novel came from. The loop resolves the `Source` from it,
  /// and a novel whose source no longer resolves is a **failure with a typed cause**
  /// rather than a crash (`SourceManager.byId` returns `null` for exactly that).
  final String sourceId;

  /// `03-source-system.md` rule 3 — relative (`path + query`), never a full URL. It is
  /// what the source's `fetchChapterContent` receives and what `ConversionRequest`
  /// resolves `href` and `src` against.
  final String chapterUrl;

  /// B9 — the site's own order. The filename `2-3` writes is built from this and
  /// **never** from [chapterNumber].
  final int ordinal;

  /// The number as the site published it, `-1` mapped to `null`. See the class header.
  final double? chapterNumber;

  /// `DownloadState` **by name** — `DownloadStateConverter` is name-based, and an
  /// ordinal written to this column would silently shift after any enum reordering.
  final DownloadState state;

  /// B18 — insertion order, and what the queue **reads**. A hand-picked order is only
  /// honoured because this column is not `chapters.ordinal`.
  final int queuePosition;

  final DateTime addedAt;
  final DateTime? startedAt;
  final DateTime? finishedAt;

  /// B20 — one increment per `queued → downloading`. This is what distinguishes a
  /// resumed attempt from a fresh one after E15's process kill.
  final int attempts;

  /// A [QueueFailureCode] name, never free text (B24 / C12).
  final String errorCode;

  /// B6 — `true` when the `.md` was wholly present when the mark was written, which
  /// means **`2-3` finished**, and never when this queue reached `done`.
  ///
  /// ⚠️ ⚠️ **THIS IS NOT A FIELD, AND ITS ABSENCE IS THE SLICE'S CENTRAL CLAIM.**
  /// `chapters.downloadedAt` is read by joining `chapters`; it is never written from
  /// here or from anywhere in `5-1`. The mark belongs to `2-3`, **after** the atomic
  /// rename, and the ORDER of those two writes **is** B6 (ADR-022) — see § 3.4 and the
  /// test that greps `lib/` for a third write site.
  bool get isDone => state == DownloadState.done;

  @override
  bool operator ==(Object other) =>
      other is QueueEntry &&
      other.id == id &&
      other.chapterId == chapterId &&
      other.novelId == novelId &&
      other.novelTitle == novelTitle &&
      other.chapterName == chapterName &&
      other.sourceId == sourceId &&
      other.chapterUrl == chapterUrl &&
      other.ordinal == ordinal &&
      other.chapterNumber == chapterNumber &&
      other.state == state &&
      other.queuePosition == queuePosition &&
      other.addedAt == addedAt &&
      other.startedAt == startedAt &&
      other.finishedAt == finishedAt &&
      other.attempts == attempts &&
      other.errorCode == errorCode;

  @override
  int get hashCode => Object.hash(
    id,
    chapterId,
    novelId,
    novelTitle,
    chapterName,
    sourceId,
    chapterUrl,
    ordinal,
    chapterNumber,
    state,
    queuePosition,
    addedAt,
    startedAt,
    finishedAt,
    attempts,
    errorCode,
  );

  /// ⚠️ **Ids and the chapter's title, never a URL.** `13-error-handling.md` rule 6 and
  /// C5: a log line is something an owner reads aloud, and a reader's chapter name is
  /// not evidence of anything a log should carry.
  @override
  String toString() =>
      'QueueEntry($id, $chapterName, $state, position: $queuePosition)';
}
