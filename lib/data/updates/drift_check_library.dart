// Lumen Tale — the loop. `6-4` § 3.1 and § 3.2, branch by branch.
//
// `data/` → `core` + `domain`. Pure Dart except for the clock and the store, which is
// why `6-10` can run this exact object in a background isolate with a fresh database.
//
// ## ⚠️ TWO CANCELLATION GATES PER NOVEL, NOT ONE
//
// § 2.2's contract says the door is consulted *"before each novel"* **and** — in its
// own next sentence — *"an implementation must also consult it after each network
// call, so a cancellation made during a request does not take one more novel than it
// had"*. So the pass polls `cancellation()` twice per novel and once more after the
// loop. Without the second poll the reader cancels during novel 3 and is told about
// novel 4's result; without the third, a cancel during novel 23 is reported as
// *All 23 novels checked*.
//
// ## ⚠️ EVERY FAILURE IS A RESULT, AND NONE OF THEM THROWS
//
// `13-error-handling.md` rule 1 plus B23: one site being down must not abort a pass over
// the other 22. The `catch` clauses below are therefore the **last** thing in each step
// and they produce a [NovelCheckFailed] — including for a bare `Exception` thrown by a
// source, because a source that throws something untyped is a site defect and must be
// reported as one rather than crash the pass (C12: the reader can describe it).
//
// The ONE exception is `CancelledException`, which is rethrown: rule 7 says a
// cancellation is the reader's own gesture and must never surface as a site failure.
//
// ## ⚠️ THE ONLY NETWORK CALLS ARE TWO, AND THEY ARE NAMED HERE
//
// `getNovelDetails` and `getChapterList`. `ParsedHttpSource.fetchChapterContent` appears
// nowhere in this file, `queue_items` is never touched, and `6-10` § 3.2 calls *this*
// method rather than a second loop. `test/data/updates/check_never_downloads_test.dart`
// renders those three absences as grep assertions.

import 'dart:async';

import 'package:lumen_tale/core/error/app_exception.dart';
import 'package:lumen_tale/core/error/source_failure.dart';
import 'package:lumen_tale/core/network/host_rate_limiter.dart';
import 'package:lumen_tale/data/sources/source_manager.dart';
import 'package:lumen_tale/domain/library/library_repository.dart';
import 'package:lumen_tale/domain/sources/browse_outcome.dart';
import 'package:lumen_tale/domain/sources/models/chapter.dart';
import 'package:lumen_tale/domain/sources/models/novel.dart';
import 'package:lumen_tale/domain/sources/source.dart';
import 'package:lumen_tale/domain/sources/source_id.dart';
import 'package:lumen_tale/domain/updates/check_library.dart';
import 'package:lumen_tale/domain/updates/library_check.dart';

final class DriftCheckLibrary implements CheckLibrary {
  DriftCheckLibrary({
    required LibraryCheckStore store,
    required SourceManager sources,
    required HostRateLimiter rateLimiter,
    DateTime Function()? clock,
  }) : _store = store,
       _sources = sources,
       _rateLimiter = rateLimiter,
       _clock = clock ?? DateTime.now;

  final LibraryCheckStore _store;
  final SourceManager _sources;

  /// The **shared** per-host limiter.
  ///
  /// ⚠️ **IT IS FED, NEVER READ.** A pass that sees a `429` records the site's own
  /// `Retry-After` on the limiter every `HttpClient` already acquires from, and does
  /// nothing else. Two reasons it is not read here:
  ///
  /// * **it would double the wait.** `SourceHttpClient`'s request interceptor calls
  ///   `acquire(host)` on every request; acquiring again in this class would space two
  ///   requests to the same site twice over.
  /// * **it would throttle nothing.** A limiter private to this class cannot stop the
  ///   *next novel's* request, which is the one C7 is about — a pass visits every novel
  ///   (B39), and two novels from one rate-limited site would be read back to back.
  ///
  /// Feeding the shared limiter is what makes "no further request during the wait"
  /// true for the rest of the pass, and it is asserted by a test that reads
  /// [HostRateLimiter.blockedUntil].
  final HostRateLimiter _rateLimiter;

  /// ⚠️ **A CLOCK IS A CONSTRUCTOR PARAMETER, NOT A CALL TO `DateTime.now` INSIDE.**
  /// `library_update_fact.dart` § "No clock" says a method with a hidden clock cannot be
  /// tested or reasoned about; the same applies here, where three branches turn on *when*
  /// the check happened. `6-10`'s background isolate passes its own.
  final DateTime Function() _clock;

  @override
  Future<LibraryCheckResult> run({
    required void Function(LibraryCheckProgress) onProgress,
    required Future<bool> Function() cancellation,
  }) async {
    final DateTime startedAt = _clock();

    // ⚠️ **`DatabaseException` IS ALLOWED TO ESCAPE, AND IT IS THE ONLY THING THAT IS.**
    // The store is local; an unreadable local store is the screen's `ErrorState`, not a
    // per-novel failure — reporting it as "23 novels could not be checked" would blame
    // twenty-three sites for a phone that ran out of space.
    final List<LibraryNovelRef> novels = await _list();

    final int total = novels.length;
    final List<NovelCheckOutcome> results = <NovelCheckOutcome>[];

    // ⚠️ **THE FIRST EMISSION IS BEFORE ANY NETWORK CALL, AND IT ALREADY CARRIES `total`.**
    // § 2.2: *`total` holds from the first emission, so the screen can render "0 of 23"
    // without waiting* — and finding out the library is 23 novels is a local query. The
    // first version of this line emitted `total: 0`, which is a count the reader would
    // watch jump from nothing to the real number a frame later.
    onProgress(
      LibraryCheckProgress(total: total, done: 0, inFlightNovelId: null),
    );

    for (final LibraryNovelRef novel in novels) {
      // ── gate 1 — between two novels (§ 3.1) ─────────────────────────────
      if (await cancellation()) {
        return _interrupted(startedAt, total, results);
      }

      onProgress(
        LibraryCheckProgress(
          total: total,
          done: results.length,
          inFlightNovelId: novel.novelId,
        ),
      );

      results.add(await _checkOne(novel));

      // ── gate 2 — after this novel's network calls (§ 2.2) ───────────────
      if (await cancellation()) {
        return _interrupted(startedAt, total, results);
      }
    }

    // ── gate 3 — after the last novel ────────────────────────────────────────
    // ⚠️ **A CANCELLATION MADE DURING THE FINAL REQUEST MUST STILL COUNT.** Without this
    // line the reader cancels during novel 23 and is told *All 23 novels checked*.
    final bool interrupted = await cancellation();

    return LibraryCheckResult(
      startedAt: startedAt,
      finishedAt: _clock(),
      total: total,
      perNovel: List<NovelCheckOutcome>.unmodifiable(results),
      interrupted: interrupted,
    );
  }

  LibraryCheckResult _interrupted(
    DateTime startedAt,
    int total,
    List<NovelCheckOutcome> results,
  ) {
    return LibraryCheckResult(
      startedAt: startedAt,
      finishedAt: _clock(),
      total: total,
      // ⚠️ **SHORTER THAN `total`, AND THAT IS THE POINT.** C8: an interrupted pass is
      // reported as interrupted, with both numbers, and never as a success.
      perNovel: List<NovelCheckOutcome>.unmodifiable(results),
      interrupted: true,
    );
  }

  /// `listLibraryNovels` re-typed, so a drift failure becomes a [DatabaseException].
  ///
  /// ⚠️ **The store's own contract already forbids throwing bare**; this exists so the
  /// *kind* of failure is in the domain vocabulary at the boundary rather than being
  /// whatever drift happened to raise three layers down.
  Future<List<LibraryNovelRef>> _list() async {
    try {
      return await _store.listLibraryNovels();
    } on AppException {
      rethrow;
    } on Object catch (error) {
      throw DatabaseException(
        'the library could not be listed for a check',
        cause: error,
      );
    }
  }

  /// § 3.2 — **the eight branches, in the order the pseudocode reaches them.**
  Future<NovelCheckOutcome> _checkOne(LibraryNovelRef novel) async {
    final Source? source = _sources.byId(novel.sourceId);

    // ── branch 0a — the id resolves to nothing (B24) ───────────────────────
    // ⚠️ **`itemRemovedAtSource`, NOT `sourceUnavailable`.** A source that no longer
    // resolves means the novel cannot be read *at all* — and E9's vocabulary ("no longer at
    // <site>") is what the reader can act on. A "site unavailable" line would tell them to
    // retry, and retrying will never help.
    if (source == null) {
      return _fail(novel, CheckFailureKind.itemRemovedAtSource);
    }

    // ── branch 0b — the reader switched this source off ─────────────────────
    if (!await _store.isSourceEnabled(novel.sourceId)) {
      // ⚠️ **`last_checked_at` is NOT written.** "We did not look" is not "we looked and
      // found nothing" — B49, and the whole reason the column is nullable.
      return _fail(novel, CheckFailureKind.sourceUnavailable);
    }

    try {
      return await _checkThrough(novel, source);
    } on CancelledException {
      // Rule 7: a cancellation is the reader's gesture, not a verdict about a site.
      rethrow;
    } on AppException catch (error) {
      // ── branch 7 — a typed exception from the store or a source ────────────
      return _fail(novel, kindOfAppException(error));
    } on Object {
      // ⚠️ **A BARE `Object`, MAPPED, NEVER RETHROWN.** `13-error-handling.md` rule 1: a
      // source that throws an untyped error is a broken source, and B23 says a broken site
      // does not stop the pass. `parseFailed` is the honest verdict — the app cannot say
      // what happened, and saying so beats an exception that reaches a reader as a crash.
      return _fail(novel, CheckFailureKind.parseFailed);
    }
  }

  /// Branches 1–5: the novel is readable, or fails in a way we can name.
  Future<NovelCheckOutcome> _checkThrough(
    LibraryNovelRef novel,
    Source source,
  ) async {
    // ⚠️ **THE STORED URL IS HANDED OVER, NEVER RE-JOINED.** `HttpSource` composes
    // `'$baseUrl$path'`; a URL assembled here would be the one place that knows how a site
    // spells its own paths, and `03-source-system.md` rule 3 keeps the stored value relative.
    final Novel probe = _probeFor(novel);

    // ── branch 1–4: `getNovelDetails` decides whether the novel is still there ──
    final BrowseOutcome<Novel> details = await source.getNovelDetails(probe);

    switch (details) {
      // ── E9 — the site answered, and the novel is gone ──────────────────────
      case BrowseFailed<Novel>(reason: ItemRemovedAtSource()):
        // ⚠️ **THE ONE FAILURE THAT WRITES `last_checked_at`.** We looked, and we saw. E9's
        // chapters and their `.md` files are untouched — this class has no `DELETE`.
        await _store.recordChecked(novel.novelId, _clock());
        await _store.recordCheckFailure(
          novel.novelId,
          CheckFailureKind.itemRemovedAtSource,
        );
        return NovelCheckFailed(
          kind: CheckFailureKind.itemRemovedAtSource,
          sourceId: novel.sourceId,
        );

      // ── E4 — the page parsed and held none of the elements the source selects ──
      case BrowseFailed<Novel>(reason: final SourceLayoutChanged changed):
        return _fail(
          novel,
          CheckFailureKind.sourceLayoutChanged,
          selector: changed.failedSelector,
        );

      // ── branch 3 — E8, and every other read failure, mapped by CAUSE ──────
      case BrowseFailed<Novel>(reason: final SourceFailure failure):
        return _failWithCause(novel, failure);

      // ⚠️ **`BrowseEmpty` on the DETAILS page is a failure, not a zero.** A site that
      // declares "nothing here" about a novel the reader is holding has told us it cannot
      // find the novel, and E9 is the honest reading. Only a chapter LIST may legitimately
      // be empty.
      case BrowseEmpty<Novel>():
        return _fail(novel, CheckFailureKind.itemRemovedAtSource);

      case BrowseSucceeded<Novel>(items: final List<Novel> items):
        return _checkChapters(novel, source, items);
    }
  }

  /// Branches 5–6: the chapter list.
  Future<NovelCheckOutcome> _checkChapters(
    LibraryNovelRef novel,
    Source source,
    List<Novel> details,
  ) async {
    final Novel current = details.isEmpty ? _probeFor(novel) : details.first;

    final BrowseOutcome<List<Chapter>> chapters = await source.getChapterList(
      current,
    );

    switch (chapters) {
      case BrowseFailed<List<Chapter>>(reason: final SourceFailure failure):
        return _failWithCause(novel, failure);

      // ⚠️ **B22's ONE LEGITIMATE ZERO.** `BrowseEmpty` exists *only* where the site
      // supplies its own empty-result signal, so reaching it means the site said so in its
      // own words. A source without such a signal returns `BrowseFailed(ParseFailed)` for an
      // empty page instead, and lands in the branch above — which is the difference between
      // "checked, the site lists no chapters" and "the page could not be read".
      case BrowseEmpty<List<Chapter>>():
        final DateTime now = _clock();
        await _store.recordChecked(novel.novelId, now);
        return NovelChecked(
          newChaptersFound: 0,
          siteChapterCount: 0,
          checkedAt: now,
        );

      // ⚠️ **`items` IS `List<List<Chapter>>`, AND THAT IS NOT A TYPO IN THE PLAN.**
      // `BrowseOutcome<List<Chapter>>` makes the success payload a list of *lists*, so a
      // site that splits one page into several hands over several batches of chapters.
      // `drift_chapter_list_repository.dart` reads the same shape for the same reason.
      case BrowseSucceeded<List<Chapter>>(
        items: final List<List<Chapter>> pages,
      ):
        // ⚠️ **THE ORDINAL COUNTS ACROSS THE BATCHES, NOT WITHIN ONE.** A page boundary
        // is a fetch artefact; the site's chapter order runs through it, so a per-page
        // index would restart the sequence and make every page the same order.
        final List<Chapter> published = <Chapter>[
          for (final List<Chapter> page in pages) ...page,
        ];

        // ⚠️ **`null` NAME BECOMES THE EMPTY STRING, AND THE NUMBER IS THE SITE'S.** B10:
        // the label is the site's text and the `-1` sentinel is preserved; the loader
        // renders *Untitled* for the empty name.
        final List<NewChapter> fresh = <NewChapter>[
          for (int i = 0; i < published.length; i++)
            NewChapter(
              // B3 — derived from the novel id and the relative url, never minted.
              id: SourceId.forChapter(
                novelId: novel.novelId,
                relativeUrl: published[i].url,
              ),
              url: published[i].url,
              name: published[i].name ?? '',
              number: published[i].number,
              // B9 — the position in the list the site published, never re-derived from
              // `number`. Royal Road orders its table by publication date.
              ordinal: i,
            ),
        ];

        final int added = await _store.mergeChapterList(novel.novelId, fresh);
        final DateTime now = _clock();

        // ⚠️ **SUCCESS CLEARS THIS SOURCE'S ERROR, AND ONLY THIS SOURCE'S.** § 3.2 branch 6.
        await _store.recordChecked(novel.novelId, now);
        return NovelChecked(
          newChaptersFound: added,
          siteChapterCount: published.length,
          checkedAt: now,
        );
    }
  }

  /// Writes the typed cause and builds the outcome. ⚠️ **Never writes `last_checked_at`.**
  Future<NovelCheckFailed> _fail(
    LibraryNovelRef novel,
    CheckFailureKind kind, {
    String? selector,
  }) async {
    await _store.recordCheckFailure(novel.novelId, kind);
    return NovelCheckFailed(
      kind: kind,
      sourceId: novel.sourceId,
      failedSelector: selector,
    );
  }

  /// The same, for a cause that arrived as a [SourceFailure].
  ///
  /// ⚠️ **The `Retry-After` is recorded on the SHARED limiter here and nowhere else.**
  /// C7 / `17-security.md` rule 6: the wait is the site's own header, read and never
  /// guessed, and "we do not insist" is only true if the *next* request — the next
  /// novel's, from the same host — actually waits.
  ///
  /// ⚠️ **THE SELECTOR SURVIVES HERE, AND THIS FUNCTION IS WHERE IT WAS BEING LOST.**
  /// E4 can arrive from *either* read: the detail page's `getNovelDetails` or the
  /// chapter table's `getChapterList`. Both produce a [SourceLayoutChanged], and that cause
  /// carries the one field that makes the site repairable — `failedSelector`. The first
  /// version of this mapping read `checkFailureKindOf(failure)` and stopped, so an E4 from
  /// the chapter list produced a `sourceLayoutChanged` with **no selector**: the verdict was
  /// right and the evidence was gone. C5 requires repairing a changed site to be
  /// deliverable as a file, and a file cannot be written without knowing which selector came
  /// back empty. § 11.1 lists this as its own row for exactly that reason.
  Future<NovelCheckFailed> _failWithCause(
    LibraryNovelRef novel,
    SourceFailure failure,
  ) async {
    if (failure case final RateLimited limited) {
      _rateLimiter.block(
        hostOf(_sources.byId(novel.sourceId)),
        until: _clock().add(limited.retryAfter),
      );
    }
    return _fail(
      novel,
      checkFailureKindOf(failure),
      // ⚠️ **`null` for every other cause, and that is not an omission.** Only a selector
      // that failed identifies a broken selector; a dropped connection broke nothing
      // selectable, and carrying a stale string would point the owner at the wrong line.
      selector: switch (failure) {
        SourceLayoutChanged(:final String failedSelector) => failedSelector,
        _ => null,
      },
    );
  }

  /// The `Novel` handed to the source, built from the **stored** row.
  ///
  /// ⚠️ **`name: null` AND THE STORED URL.** A check must not present a fabricated title:
  /// `getNovelDetails` re-reads the page, and the row it returns is the site's answer, not
  /// this probe's. The probe exists only to carry the identity.
  Novel _probeFor(LibraryNovelRef novel) => Novel(
    id: novel.novelId,
    sourceId: novel.sourceId,
    url: novel.url,
    title: novel.title,
    // ⚠️ **EVERY FIELD THE APP DID NOT READ STAYS AT "THE SITE DID NOT SAY IT".**
    // `author`, `description` and `coverUrl` are `null`; `status` is
    // [NovelStatus.unknown] and not `ongoing` — ADR-024's "displayed, never searched"
    // and rule 8's "empty means the site did not say". Filling `author` from the stored
    // title would be fabricating B10 verbatim site text.
    author: null,
    description: null,
    status: NovelStatus.unknown,
    coverUrl: null,
    genres: const <String>[],
  );
}

/// The host whose limiter slot a `429` belongs to.
///
/// ⚠️ **`HttpSource`'s `baseUrl`, and the source's own id as the fallback.**
/// `HostRateLimiter` is keyed by host (B23: two sites share nothing), and a source that
/// is not an `HttpSource` has no host to key on — so its slot is its id, which is still
/// per-source and still shared with nobody.
String hostOf(Source? source) => switch (source) {
  HttpSource(:final String baseUrl) => Uri.parse(baseUrl).host,
  _ => source?.id ?? '',
};

/// The `AppException` → `CheckFailureKind` mapping, as a **function** so a test can read
/// the whole table without running a pass.
CheckFailureKind kindOfAppException(AppException error) => switch (error) {
  NetworkException() => CheckFailureKind.noConnection,
  // ⚠️ **`SourceException` IS A PARSE FAILURE AND `DatabaseException` IS ONE TOO**, and the
  // second is the weaker claim: a store that cannot be written is the app's own problem,
  // reported as "the app could not read this novel" rather than blaming a site that may
  // have answered perfectly. `error.cause` keeps the real type for the log.
  SourceException() || DatabaseException() => CheckFailureKind.parseFailed,
  // ⚠️ **`ChapterNotAvailableException` IS A SITE DEFECT HERE, NOT A DOWNLOAD ONE.** It
  // means a chapter body was needed and absent; `6-4` never reads a body (B38), so
  // reaching it is a source that did something this slice did not ask for.
  ChapterNotAvailableException() => CheckFailureKind.parseFailed,
  // ⚠️ **Unreachable: `_checkOne` rethrows `CancelledException` before this switch.** It
  // is here because the hierarchy is sealed and the switch must be total; a cancellation
  // reaching here would be reported as a verdict about a site, which rule 7 forbids.
  CancelledException() => CheckFailureKind.parseFailed,
};

/// The `SourceFailure` → `CheckFailureKind` mapping, as a **function** so a test can read
/// the whole table without running a pass.
///
/// ⚠️ **`ItemRemovedAtSource` IS `itemRemovedAtSource`, and `ParseFailed` IS `parseFailed`** —
/// E9 and E8 are the two edges this table exists for, and an `architecture.md` § 5.2 cause
/// with no arm here would be a verdict chosen by whoever wrote the `switch` next.
CheckFailureKind checkFailureKindOf(SourceFailure failure) => switch (failure) {
  NoConnection() => CheckFailureKind.noConnection,
  RateLimited() => CheckFailureKind.rateLimited,
  SourceLayoutChanged() => CheckFailureKind.sourceLayoutChanged,
  SourceUnavailable() => CheckFailureKind.sourceUnavailable,
  ItemRemovedAtSource() => CheckFailureKind.itemRemovedAtSource,
  ParseFailed() => CheckFailureKind.parseFailed,
  // ⚠️ **THE APP CANNOT SAY.** `CauseUnknown` is its own class for exactly this, and the
  // verdict says so rather than blaming the network for a page the app misread.
  CauseUnknown() => CheckFailureKind.parseFailed,
};
