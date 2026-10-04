// forge:slice 6-4
// Lumen Tale — `6-4`: the pass itself. § 3.1's loop, § 3.2's eight branches, and the two
// cancellation gates.
//
// ## Why the store is a fake here and a real database there
//
// This file tests the **loop**, and a loop is only legible when every write it makes is
// visible. `RecordingCheckStore` records `recordChecked` and `recordCheckFailure`
// **separately**, because B49's whole claim is *which of the two* a branch called — a check
// that could not look must leave `last_checked_at` absent, and one merged "touched" set
// could not tell those apart. The drift store's own rows are asserted in
// `drift_library_check_store_test.dart`, and the end-to-end rows — `queue_items` untouched,
// `is_read` untouched, no `DELETE` — in `check_never_downloads_test.dart`.
//
// ## The rows that carry the slice
//
// | rule | the row |
// |---|---|
// | **B39** | *23 novels produce 23 entries, and one per emission* | a novel whose site is broken is **still** an entry |
// | **B36** | *a check starts only from an explicit action* | reading the provider starts nothing; `start()` is the only caller |
// | **B38** | *the only contract methods a check calls are two* | `getNovelDetails` then `getChapterList`, once each per novel |
// | **B49** | *"we could not look" must never render as "we looked"* | six of the eight branches write **no** timestamp; E9 alone does |
// | **B22** | *a broken site is never "0 new chapters"* | `parseFailed` and `sourceLayoutChanged` are failures, not zeros |
// | **C7** | *a `429` waits, and it does not skip* | the shared limiter is fed and the next novel **waits** |

import 'package:flutter_test/flutter_test.dart';
import 'package:lumen_tale/core/error/app_exception.dart';
import 'package:lumen_tale/core/error/source_failure.dart';
import 'package:lumen_tale/core/network/host_rate_limiter.dart';
import 'package:lumen_tale/data/sources/source_manager.dart';
import 'package:lumen_tale/data/updates/drift_check_library.dart';
import 'package:lumen_tale/domain/library/library_repository.dart';
import 'package:lumen_tale/domain/sources/browse_outcome.dart';
import 'package:lumen_tale/domain/sources/models/chapter.dart';
import 'package:lumen_tale/domain/sources/models/novel.dart';
import 'package:lumen_tale/domain/sources/source.dart';
import 'package:lumen_tale/domain/sources/source_id.dart';
import 'package:lumen_tale/domain/updates/library_check.dart';

import 'check_fakes.dart';

/// A fixed instant, so no branch that turns on *when* depends on the clock.
final DateTime kNow = DateTime.utc(2026, 10, 4, 9);

/// One rig: the interactor, the site it reads, the store it writes and the limiter it feeds.
///
/// ⚠️ **THE CLOCK IS INJECTED AND THE SLEEP IS RECORDED.** Three of the eight branches
/// turn on *when* the check happened (B49's timestamp) and one turns on how long it waited
/// (C7), so a rig with a hidden `DateTime.now()` and a real `Future.delayed` could only
/// assert both by being slow.
class _Rig {
  _Rig({
    List<LibraryNovelRef>? novels,
    SpySource? site,
    bool sourceEnabled = true,
    this.sources,
  }) : site = site ?? SpySource(),
       store = RecordingCheckStore(
         novels: novels,
         sourceEnabled: sourceEnabled,
       ) {
    // ⚠️ **THE SLEEP RECORDS INSTEAD OF WAITING.** A `Sleeper` that really slept would
    // make C7's claim — *which* wait was asked for — a timing observation, and a 2-minute
    // `Retry-After` would make the suite two minutes slower for nothing. Built here rather
    // than in the initialiser list because it closes over `waits`.
    limiter = HostRateLimiter(
      clock: () => kNow,
      sleep: (Duration d) async => waits.add(d),
    );
    check = DriftCheckLibrary(
      store: store,
      sources: sources ?? SourceManager(<Source>[this.site]),
      rateLimiter: limiter,
      clock: () => kNow,
    );
  }

  final SpySource site;
  final RecordingCheckStore store;

  /// Every wait the limiter was asked for, in order. C7 reads this.
  final List<Duration> waits = <Duration>[];

  late final HostRateLimiter limiter;

  /// A registry the rig does not own, for the one row that needs a source whose id does
  /// **not** resolve.
  final SourceManager? sources;

  late final DriftCheckLibrary check;

  /// The emissions, and **how many contract calls had happened when each was made**.
  ///
  /// ⚠️ **THE SECOND LIST IS THE INTERESTING ONE.** § 2.2 requires the first emission
  /// *before any network call* and to carry the real `total`, so a screen can say
  /// "Checking 0 of 23" instead of finding out the library's size after the first fetch.
  final List<LibraryCheckProgress> emissions = <LibraryCheckProgress>[];
  final List<int> callsAtEmission = <int>[];

  void onProgress(LibraryCheckProgress progress) {
    emissions.add(progress);
    callsAtEmission.add(site.calls.length);
  }

  /// A `cancellation` that answers `true` on its [cancelAt]-th poll, and counts its polls.
  ///
  /// ⚠️ **THE POLLS ARE COUNTED, NOT JUST THE OUTCOME.** § 2.2 asks for the door to be
  /// consulted before every novel *and* after every network call; a single flag checked
  /// once per iteration cannot express that, and a test that only checked the verdict
  /// would pass either way.
  Future<bool> Function() cancellationAt(int cancelAt) {
    int polls = 0;
    return () async {
      polls++;
      return polls >= cancelAt;
    };
  }
}

/// The one constructor every row goes through. A **function** rather than
/// `_Rig(...)` spelled at each call site, because the argument that varies is the site and
/// the library, and a shorthand keeps each test reading as its own claim.
_Rig _rig({
  List<LibraryNovelRef>? novels,
  SpySource? site,
  bool sourceEnabled = true,
  SourceManager? sources,
}) => _Rig(
  novels: novels,
  site: site,
  sourceEnabled: sourceEnabled,
  sources: sources,
);

/// `getChapterList` answering with [pages] — one batch per page, which is the shape
/// `BrowseOutcome<List<Chapter>>` actually carries.
BrowseSucceeded<List<Chapter>> chaptersOf(List<List<Chapter>> pages) =>
    BrowseSucceeded<List<Chapter>>(pages);

/// Never cancelled. Written as a function so a test cannot "cancel" by omission.
Future<bool> neverCancelled() async => false;

void main() {
  group('B39 — every library novel is visited, and the list is the proof', () {
    test('23 novels produce exactly 23 entries and a total of 23', () async {
      final _Rig r = _rig(novels: refsOf(23));

      final LibraryCheckResult result = await r.check.run(
        onProgress: r.onProgress,
        cancellation: neverCancelled,
      );

      expect(
        result.perNovel.length,
        23,
        reason:
            'B39: one entry per library novel — a skip would shorten this list',
      );
      expect(
        result.total,
        23,
        reason: 'and the total is the same number, so the two cannot disagree',
      );
      expect(result.interrupted, isFalse);
      expect(
        r.store.calls.where((String c) => c == 'mergeChapterList').length,
        23,
        reason: 'each novel was read, not just counted',
      );
    });

    test('a novel whose site is broken is STILL an entry, and the loop continues', () async {
      // ⚠️ **THE ROW MOST LIKELY TO BE WRITTEN THE OTHER WAY.** "Skip the novels that
      // failed" is the obvious optimisation, and B39 — *no novel is skipped **for any
      // reason*** — exists to forbid it. A skip is invisible from a total, which is why
      // this asserts the length and the failed entry.
      final _Rig r = _rig(novels: refsOf(3));
      // ⚠️ **ONE NOVEL, NOT THE SITE.** A site that fails for every novel it serves would
      // produce `failedCount == 3` and this row would pass while proving nothing about the
      // loop continuing. Only novel 2's read fails, so "the loop kept going past a failure"
      // is the thing being measured.
      r.site.detailsFor = <String, BrowseOutcome<Novel>>{
        'n2': const BrowseFailed<Novel>(
          SourceLayoutChanged(failedSelector: 'table#chapters', status: 200),
          retriable: false,
        ),
      };

      final LibraryCheckResult first = await r.check.run(
        onProgress: r.onProgress,
        cancellation: neverCancelled,
      );

      expect(first.perNovel.length, 3);
      expect(first.failedCount, 1);
      expect(first.checkedCount, 2);
      expect(
        first.perNovel.whereType<NovelCheckFailed>().single.sourceId,
        'src-a',
        reason:
            'and the failed entry names the site, so the code lands on its row',
      );
      expect(
        first.perNovel[2],
        isA<NovelChecked>(),
        reason:
            '⚠️ the THIRD novel was read after the second failed — that is what "the loop '
            'continues" means, and it is invisible in a total',
      );

      // A second pass with a healthy site, so the counts are not read as a partial pass.
      final _Rig healthy = _rig(novels: refsOf(3));
      healthy.site.details = null;
      final LibraryCheckResult second = await healthy.check.run(
        onProgress: healthy.onProgress,
        cancellation: neverCancelled,
      );
      expect(
        second.checkedCount,
        3,
        reason:
            'B39: a broken site never stops the pass for the other novels (B23)',
      );
    });

    test(
      'a library of only failing novels reports 0 checked and N failed',
      () async {
        final _Rig r = _rig(novels: refsOf(2));
        r.site.details = const BrowseFailed<Novel>(
          NoConnection(host: 'site.test'),
          retriable: true,
        );

        final LibraryCheckResult result = await r.check.run(
          onProgress: r.onProgress,
          cancellation: neverCancelled,
        );

        expect(result.checkedCount, 0);
        expect(result.failedCount, 2);
        expect(
          result.interrupted,
          isFalse,
          reason: 'nothing was cancelled — the pass finished and read nothing',
        );
        expect(
          result.discoveredChapters,
          0,
          reason:
              'and "found nothing" here is a failure count, not a chapter count',
        );
      },
    );

    test(
      'an empty library reports total 0, one emission, and no failure',
      () async {
        final _Rig r = _rig(novels: refsOf(0));

        final LibraryCheckResult result = await r.check.run(
          onProgress: r.onProgress,
          cancellation: neverCancelled,
        );

        expect(result.total, 0);
        expect(result.perNovel, isEmpty);
        expect(result.interrupted, isFalse);
        expect(
          r.emissions,
          <LibraryCheckProgress>[
            const LibraryCheckProgress(
              total: 0,
              done: 0,
              inFlightNovelId: null,
            ),
          ],
          reason:
              'the counter is drawn for an empty library too, and it reads 0 of 0',
        );
        expect(
          r.site.calls,
          isEmpty,
          reason: 'B36/C2: an empty pass issues no request at all',
        );
      },
    );

    test('the first emission knows the total and precedes every network call', () async {
      final _Rig r = _rig(novels: refsOf(23));

      await r.check.run(onProgress: r.onProgress, cancellation: neverCancelled);

      expect(
        r.emissions.first.total,
        23,
        reason: '§ 2.2 — the total holds from the first emission',
      );
      expect(
        r.callsAtEmission.first,
        0,
        reason:
            '⚠️ and it was emitted BEFORE the first request, so the screen never shows '
            '"0 of" and then jumps to 23',
      );
      expect(
        r.emissions,
        hasLength(24),
        reason: 'one opening emission plus one per novel',
      );
      expect(
        r.emissions.map((LibraryCheckProgress p) => p.done).toList(),
        <int>[
          0,
          0,
          1,
          2,
          3,
          4,
          5,
          6,
          7,
          8,
          9,
          10,
          11,
          12,
          13,
          14,
          15,
          16,
          17,
          18,
          19,
          20,
          21,
          22,
        ],
        reason:
            'B39 § 3.4: the counter rises by exactly one per novel. The TWO leading '
            'zeros are the opening emission (which names no novel) and the emission for '
            'novel 1 (which is the first novel not yet done) — they are distinguishable '
            'only by `inFlightNovelId`, which is why a test that read `done` alone would '
            'see a stall and a test that read the list length would see a jump',
      );
      expect(
        r.emissions
            .skip(1)
            .map((LibraryCheckProgress p) => p.inFlightNovelId)
            .toList(),
        <String?>[for (int i = 1; i <= 23; i++) 'n$i'],
        reason:
            'and the 23 loop emissions name the 23 novels, so the counter and the '
            'novel being read are the same statement about the same pass',
      );
      expect(
        r.emissions.map((LibraryCheckProgress p) => p.total).toSet(),
        <int>{23},
        reason: 'and the total never moves while the reader watches it',
      );
    });

    test(
      'the novel being read is named, and it is null before and after the pass',
      () async {
        final _Rig r = _rig(novels: refsOf(3));

        await r.check.run(
          onProgress: r.onProgress,
          cancellation: neverCancelled,
        );

        expect(r.emissions.first.inFlightNovelId, isNull);
        expect(r.emissions[1].inFlightNovelId, 'n1');
        expect(r.emissions[3].inFlightNovelId, 'n3');
      },
    );
  });

  group('B37 — the reader\'s own gesture stops the pass, and is reported as stopped', () {
    test(
      'cancelled before the first novel: nothing visited, interrupted',
      () async {
        final _Rig r = _rig(novels: refsOf(5));

        final LibraryCheckResult result = await r.check.run(
          onProgress: r.onProgress,
          cancellation: r.cancellationAt(1),
        );

        expect(
          result.perNovel,
          isEmpty,
          reason: 'B37: the gate before the first novel had already fired',
        );
        expect(
          result.interrupted,
          isTrue,
          reason: 'and a stopped pass is never reported as a finished one (C8)',
        );
        expect(
          result.total,
          5,
          reason: 'the promise was 5 and is still reported as 5',
        );
        expect(
          r.site.calls,
          isEmpty,
          reason: 'a cancel before the first novel issues no request at all',
        );
      },
    );

    test('cancelled at novel 3: the two finished novels are kept and reported', () async {
      final _Rig r = _rig(novels: refsOf(5));

      // ⚠️ **POLL 5, NOT POLL 3 — AND THE COUNT IS THE POINT.** § 2.2 consults the door
      // *twice* per novel, so "the gate before novel 3" is the fifth poll. Writing `3`
      // here looks like the obvious thing and stops the pass after **one** novel — which
      // still reports `interrupted: true` and would pass a test that only checked the
      // flag. The two-gate rule is invisible to a test written as "cancel on the 3rd".
      final LibraryCheckResult result = await r.check.run(
        onProgress: r.onProgress,
        cancellation: r.cancellationAt(5),
      );

      expect(
        result.perNovel.length,
        2,
        reason: 'B39: the pass stopped between novels, and the gap is visible',
      );
      expect(result.interrupted, isTrue);
    });

    test('cancelled DURING a novel: that novel finishes before the pass stops', () async {
      // ⚠️ **THE ROW ABOUT NOT ABANDONING A HALF-WRITTEN NOVEL.** § 2.2: the door is
      // polled after each network call as well, so an interruption made mid-request stops
      // the pass at the NEXT gate — never by dropping a novel whose writes are already in
      // flight. Poll 2 is the gate *after* novel 1's two reads.
      final _Rig r = _rig(novels: refsOf(5));

      final LibraryCheckResult result = await r.check.run(
        onProgress: r.onProgress,
        cancellation: r.cancellationAt(2),
      );

      expect(
        result.perNovel.length,
        1,
        reason:
            'the novel in flight when the tap happened was finished, not abandoned',
      );
      expect(result.interrupted, isTrue);
      expect(
        r.store.calls.contains('recordChecked'),
        isTrue,
        reason:
            'and its writes landed: a half-written novel would be a lie either way',
      );
    });

    test(
      'cancelled during the LAST novel: still interrupted, not "all checked"',
      () async {
        // § 3.1 gate 3. Without it the reader taps during novel 2 of 2 and is told
        // *All 2 novels checked · none skipped.*
        final _Rig r = _rig(novels: refsOf(2));

        final LibraryCheckResult result = await r.check.run(
          onProgress: r.onProgress,
          cancellation: r.cancellationAt(5),
        );

        expect(result.perNovel.length, 2);
        expect(
          result.interrupted,
          isTrue,
          reason:
              'every novel was visited, and the pass was still stopped short of "done"',
        );
      },
    );

    test(
      'the door is polled before every novel AND after every novel\'s reads',
      () async {
        final _Rig r = _rig(novels: refsOf(3));
        int polls = 0;

        await r.check.run(
          onProgress: r.onProgress,
          cancellation: () async {
            polls++;
            return false;
          },
        );

        // 3 novels × (gate 1 + gate 2) + the closing gate 3.
        expect(
          polls,
          7,
          reason:
              '§ 2.2: a cancellation made DURING a request must not take one more novel, '
              'so the door is consulted twice per novel and once at the end',
        );
      },
    );
  });

  group('B22/B49 — one novel, eight branches, and which of them writes a timestamp', () {
    test(
      'a healthy site: chapters merged, the novel stamped, nothing else called',
      () async {
        final _Rig r = _rig(novels: refsOf(1));
        r.site.chapters = chaptersOf(<List<Chapter>>[
          <Chapter>[chapterOf('n1', 1), chapterOf('n1', 2), chapterOf('n1', 3)],
        ]);

        final LibraryCheckResult result = await r.check.run(
          onProgress: r.onProgress,
          cancellation: neverCancelled,
        );

        final NovelChecked checked = result.perNovel.single as NovelChecked;
        expect(checked.newChaptersFound, 3);
        expect(checked.siteChapterCount, 3);
        expect(checked.checkedAt, kNow);
        expect(
          r.store.checkedAt['n1'],
          kNow,
          reason: 'B49: a site that answered is stamped with when we looked',
        );
        expect(
          r.store.calls,
          containsAllInOrder(<String>[
            'listLibraryNovels',
            'isSourceEnabled',
            'mergeChapterList',
            'recordChecked',
          ]),
          reason: 'B38 § 3.3: the writes are these four and no other',
        );
      },
    );

    test(
      'a re-check that adds no row is NovelChecked(0), and is still stamped',
      () async {
        final _Rig r = _rig(novels: refsOf(1));
        r.site.chapters = chaptersOf(<List<Chapter>>[
          <Chapter>[chapterOf('n1', 1)],
        ]);
        r.store.knownChapterIds.addAll(<String>{
          SourceId.forChapter(
            novelId: 'n1',
            relativeUrl: '/fiction/n1/chapter/1',
          ),
        });

        final LibraryCheckResult result = await r.check.run(
          onProgress: r.onProgress,
          cancellation: neverCancelled,
        );

        final NovelChecked checked = result.perNovel.single as NovelChecked;
        expect(
          checked.newChaptersFound,
          0,
          reason:
              'B48: "new" means rows ADDED, not chapters the site still publishes',
        );
        expect(
          checked.siteChapterCount,
          1,
          reason:
              'and the site\'s own count is kept beside it for the screen to compare',
        );
        expect(
          r.store.checkedAt.containsKey('n1'),
          isTrue,
          reason:
              'B49: a check that found nothing is still a check that happened',
        );
      },
    );

    test(
      'B22 — only a site that DECLARES emptiness produces NovelChecked(0, 0)',
      () async {
        final _Rig r = _rig(novels: refsOf(1));
        r.site.chapters = const BrowseEmpty<List<Chapter>>(
          siteSuppliedSignal: 'No relevant content found',
        );

        final LibraryCheckResult result = await r.check.run(
          onProgress: r.onProgress,
          cancellation: neverCancelled,
        );

        expect(
          result.perNovel.single,
          isA<NovelChecked>(),
          reason:
              'B22: the site said "nothing here" in its own words, so zero is a fact',
        );
        expect((result.perNovel.single as NovelChecked).newChaptersFound, 0);
        expect(result.failedCount, 0);
        expect(
          r.store.checkedAt.containsKey('n1'),
          isTrue,
          reason: 'we did look, and we saw the site\'s own empty signal',
        );
      },
    );

    test(
      'E4 — a changed layout is a FAILURE, and the selector rides along',
      () async {
        final _Rig r = _rig(novels: refsOf(1));
        r.site.details = const BrowseFailed<Novel>(
          SourceLayoutChanged(failedSelector: 'table#chapters', status: 200),
          retriable: false,
        );

        final LibraryCheckResult result = await r.check.run(
          onProgress: r.onProgress,
          cancellation: neverCancelled,
        );

        final NovelCheckFailed failed =
            result.perNovel.single as NovelCheckFailed;
        expect(
          failed.kind,
          CheckFailureKind.sourceLayoutChanged,
          reason: 'E4 is critical and must never read as "nothing new"',
        );
        expect(
          failed.failedSelector,
          'table#chapters',
          reason:
              'C5: the selector is the artefact that makes the site repairable',
        );
        expect(
          r.store.checkedAt.containsKey('n1'),
          isFalse,
          reason:
              '⚠️ B49: we could not read the page, so we did not check the novel',
        );
        expect(
          r.store.failures['n1'],
          CheckFailureKind.sourceLayoutChanged,
          reason:
              'B24: a typed code is written so the row can say so without a fetch',
        );
        expect(
          r.site.calls.contains('getChapterList'),
          isFalse,
          reason:
              'there is no chapter list to read on a page that could not be parsed',
        );
      },
    );

    test(
      'E4 from the chapter list too: same verdict, and still no timestamp',
      () async {
        // § 10's row names `getChapterList` specifically, and the two reads fail
        // independently — a detail page that parses while the chapter table does not is the
        // common shape of E4.
        final _Rig r = _rig(novels: refsOf(1));
        r.site.chapters = const BrowseFailed<List<Chapter>>(
          SourceLayoutChanged(failedSelector: 'tr.chapter-row', status: 200),
          retriable: false,
        );

        final LibraryCheckResult result = await r.check.run(
          onProgress: r.onProgress,
          cancellation: neverCancelled,
        );

        final NovelCheckFailed failed =
            result.perNovel.single as NovelCheckFailed;
        expect(failed.kind, CheckFailureKind.sourceLayoutChanged);
        expect(failed.failedSelector, 'tr.chapter-row');
        expect(
          r.store.checkedAt.containsKey('n1'),
          isFalse,
          reason:
              'B49: "the table moved" is not "we looked and there was nothing"',
        );
      },
    );

    test(
      'E8 — a page that parses into nothing is `parseFailed`, NEVER NovelChecked(0)',
      () async {
        // § 7's explicit pitfall: a source with no empty-signal of its own returns an empty
        // page as `ParseFailed`, and flattening that into a zero is B22's failure in its
        // purest form — a broken site announcing "no new chapters" to every novel it holds.
        final _Rig r = _rig(novels: refsOf(1));
        r.site.details = const BrowseFailed<Novel>(
          ParseFailed(path: '/fiction/1'),
          retriable: false,
        );

        final LibraryCheckResult result = await r.check.run(
          onProgress: r.onProgress,
          cancellation: neverCancelled,
        );

        expect(
          result.perNovel.single,
          isA<NovelCheckFailed>(),
          reason:
              'B22/E8: no expected element was found, which is a broken page',
        );
        expect(
          (result.perNovel.single as NovelCheckFailed).kind,
          CheckFailureKind.parseFailed,
          reason: 'E8 and E4 share a verdict family and differ in their cause',
        );
        expect(r.store.checkedAt.containsKey('n1'), isFalse);
        expect(r.store.calls.contains('mergeChapterList'), isFalse);
      },
    );

    test(
      'E9 — the novel is gone: the ONLY failure that stamps the novel',
      () async {
        // E9 is the one branch where the site *answered* and told us the novel is not there.
        final _Rig r = _rig(novels: refsOf(1));
        r.site.details = const BrowseFailed<Novel>(
          ItemRemovedAtSource(itemId: 'n1', status: 404),
          retriable: false,
        );

        final LibraryCheckResult result = await r.check.run(
          onProgress: r.onProgress,
          cancellation: neverCancelled,
        );

        expect(
          (result.perNovel.single as NovelCheckFailed).kind,
          CheckFailureKind.itemRemovedAtSource,
          reason: 'E9 has its own verdict: "no longer at <site>" is actionable',
        );
        expect(
          r.store.checkedAt['n1'],
          kNow,
          reason:
              'B49: we looked, and we saw — so the timestamp is the honest one',
        );
        expect(
          r.store.failures['n1'],
          CheckFailureKind.itemRemovedAtSource,
          reason:
              'B24: and the typed code still lands, so the row can say *Could not check*',
        );
      },
    );

    test(
      'B15 — no connection: the timestamp stays absent and the code is written',
      () async {
        final _Rig r = _rig(novels: refsOf(1));
        r.site.details = const BrowseFailed<Novel>(
          NoConnection(host: 'site.test'),
          retriable: true,
        );

        final LibraryCheckResult result = await r.check.run(
          onProgress: r.onProgress,
          cancellation: neverCancelled,
        );

        expect(
          (result.perNovel.single as NovelCheckFailed).kind,
          CheckFailureKind.noConnection,
          reason:
              'B15: the phone, not the site — and the local chapters stay readable',
        );
        expect(
          r.store.checkedAt.containsKey('n1'),
          isFalse,
          reason:
              '⚠️ B49: stamping here would make "we could not look" render as "we looked '
              'and there was nothing", the exact substitution the rule exists to stop',
        );
        expect(
          r.store.failures['n1'],
          CheckFailureKind.noConnection,
          reason:
              'B22/B24: the typed cause is what the row renders without a fetch',
        );
      },
    );

    test(
      'a source the reader switched off fails as unavailable, with NO request',
      () async {
        // § 3.2 guard 0. The guard runs **before** the first network call, so "off" costs
        // no data — which is the difference between a source being off and a site being
        // down, and it is why the verdict is not `noConnection`.
        final _Rig r = _rig(novels: refsOf(1), sourceEnabled: false);

        final LibraryCheckResult result = await r.check.run(
          onProgress: r.onProgress,
          cancellation: neverCancelled,
        );

        expect(
          (result.perNovel.single as NovelCheckFailed).kind,
          CheckFailureKind.sourceUnavailable,
          reason: 'a source that is off is not a site that is broken',
        );
        expect(
          r.site.calls,
          isEmpty,
          reason:
              'B36/C2: the guard is local, so nothing was fetched to discover it',
        );
        expect(r.store.checkedAt.containsKey('n1'), isFalse, reason: 'B49');
      },
    );

    test(
      'a source id that no longer resolves is a verdict, never a crash',
      () async {
        // § 3.2 guard 0, first arm — and the reason it is `itemRemovedAtSource` and NOT
        // `sourceUnavailable`: "retry" would be advice that can never work.
        final SpySource orphan = SpySource(sourceId: 'other');
        final _Rig r = _rig(
          novels: refsOf(1, sourceId: 'gone'),
          sources: SourceManager(<Source>[orphan]),
        );

        final LibraryCheckResult result = await r.check.run(
          onProgress: r.onProgress,
          cancellation: neverCancelled,
        );

        expect(
          (result.perNovel.single as NovelCheckFailed).kind,
          CheckFailureKind.itemRemovedAtSource,
          reason:
              'a novel nobody can read is the reader\'s one actionable fact: it is gone',
        );
        expect(
          orphan.calls,
          isEmpty,
          reason:
              'and a source that does not own the novel is never asked about it',
        );
      },
    );

    test(
      '13-error-handling.md rule 1 — a source throwing a bare Exception is a verdict',
      () async {
        // § 3.2 branch 7. A throw that reached the notifier would abort a 23-novel pass
        // because of one misbehaving site — the opposite of B23.
        final _Rig r = _rig(novels: refsOf(3));
        r.site.throwFromDetails = Exception('the site adapter fell over');

        final LibraryCheckResult result = await r.check.run(
          onProgress: r.onProgress,
          cancellation: neverCancelled,
        );

        expect(
          result.perNovel.length,
          3,
          reason:
              'B23: one broken site never stops the pass over the other novels',
        );
        expect(
          result.perNovel.every(
            (NovelCheckOutcome o) =>
                o is NovelCheckFailed && o.kind == CheckFailureKind.parseFailed,
          ),
          isTrue,
          reason:
              'rule 1: the app cannot say what happened, and it says exactly that',
        );
        expect(result.interrupted, isFalse);
      },
    );

    test(
      'a store that cannot be read is the SCREEN\'s error, not 23 site failures',
      () async {
        // § 3.1's last row. Reporting it per novel would blame twenty-three sites for a
        // phone that ran out of space.
        final _Rig r = _rig(novels: refsOf(23));
        r.store.throwFromList = StateError('the database file is gone');

        await expectLater(
          r.check.run(onProgress: r.onProgress, cancellation: neverCancelled),
          throwsA(
            isA<DatabaseException>().having(
              (DatabaseException e) => e.cause,
              'cause',
              isA<StateError>(),
            ),
          ),
          reason:
              'rule 2: the driver error is wrapped and kept as `cause`, so no caller '
              'ever sees SqliteException',
        );
        expect(
          r.site.calls,
          isEmpty,
          reason: 'and nothing was fetched, because the pass never began',
        );
      },
    );

    test('a cancellation is re-thrown, never reported as a site failure', () async {
      // § 2.2's one exception to "every failure is a result". Rule 7 needs the caller to
      // be able to tell the reader's own gesture from a dead site.
      final _Rig r = _rig(novels: refsOf(2));
      r.site.throwFromDetails = const CancelledException();

      await expectLater(
        r.check.run(onProgress: r.onProgress, cancellation: neverCancelled),
        throwsA(isA<CancelledException>()),
        reason:
            'rule 7: a cancellation must not be classified as a verdict about a site',
      );
    });
  });

  group('B38 — the only contract methods a check calls are two', () {
    test(
      'a full pass calls getNovelDetails then getChapterList, once each per novel',
      () async {
        final _Rig r = _rig(novels: refsOf(3));

        await r.check.run(
          onProgress: r.onProgress,
          cancellation: neverCancelled,
        );

        expect(
          r.site.calls,
          <String>[
            'getNovelDetails',
            'getChapterList',
            'getNovelDetails',
            'getChapterList',
            'getNovelDetails',
            'getChapterList',
          ],
          reason:
              '§ 2.3/§ 3.3: no catalogue, no search, no update, and above all no '
              'fetchChapterContent — the check reads lists and nothing else',
        );
        expect(
          r.site.contentCalls,
          0,
          reason: 'B38: a chapter BODY is never requested by a check',
        );
      },
    );

    test(
      'the chapter list\'s batches are flattened and the ordinal runs across them',
      () async {
        // ⚠️ **A PAGE BOUNDARY IS A FETCH ARTEFACT.** Royal Road's fiction page holds the
        // whole table, but a paginated site hands several batches; restarting the ordinal at
        // each page would make every page the same order and B9 unsayable.
        final _Rig r = _rig(novels: refsOf(1));
        r.site.chapters = chaptersOf(<List<Chapter>>[
          <Chapter>[chapterOf('n1', 1), chapterOf('n1', 2)],
          <Chapter>[chapterOf('n1', 3)],
        ]);

        await r.check.run(
          onProgress: r.onProgress,
          cancellation: neverCancelled,
        );

        expect(r.store.merged.map((NewChapter c) => c.ordinal).toList(), <int>[
          0,
          1,
          2,
        ], reason: 'B9: the ordinal is the position in the site\'s whole list');
        expect(
          r.store.merged.map((NewChapter c) => c.url).toList(),
          <String>[
            '/fiction/n1/chapter/1',
            '/fiction/n1/chapter/2',
            '/fiction/n1/chapter/3',
          ],
          reason: '03-source-system.md rule 3: relative paths, stored verbatim',
        );
      },
    );

    test(
      'the chapter id is DERIVED from the novel and the url, never minted',
      () async {
        final _Rig r = _rig(novels: refsOf(1));
        r.site.chapters = chaptersOf(<List<Chapter>>[
          <Chapter>[chapterOf('n1', 7)],
        ]);

        await r.check.run(
          onProgress: r.onProgress,
          cancellation: neverCancelled,
        );

        expect(
          r.store.merged.single.id,
          SourceId.forChapter(
            novelId: 'n1',
            relativeUrl: '/fiction/n1/chapter/7',
          ),
          reason:
              'B3: that derivation is what makes INSERT OR IGNORE idempotent',
        );
      },
    );

    test(
      'B10 — an unreadable number stays -1 and a null title stays empty',
      () async {
        final _Rig r = _rig(novels: refsOf(1));
        // A site that publishes no title at all: the label is `null`, not an index.
        r.site.chapters = BrowseSucceeded<List<Chapter>>(<List<Chapter>>[
          <Chapter>[
            Chapter(
              id: 'c1',
              novelId: 'n1',
              url: '/fiction/n1/chapter/1',
              name: null,
              number: -1,
            ),
          ],
        ]);

        await r.check.run(
          onProgress: r.onProgress,
          cancellation: neverCancelled,
        );

        final NewChapter merged = r.store.merged.single;
        expect(
          merged.number,
          -1.0,
          reason:
              'B10: `-1` means the site published no number; `0` is a real chapter',
        );
        expect(
          merged.name,
          isEmpty,
          reason:
              'B10: a site that published no title gets no fabricated one (rule 8)',
        );
      },
    );

    test('the probe handed to the site invents nothing the app never read', () async {
      // ⚠️ **THE PROBE IS A NOVEL, AND A NOVEL HAS AUTHOR FIELDS.** `03-source-system.md`
      // rule 8 — *empty means the site did not say* — and ADR-024. A probe that filled
      // `author` from the stored title would fabricate B10 text, hand it to
      // `getNovelDetails`, and the row that comes back could then be stored as if the site
      // had published it. The stored relative url is likewise handed over **as stored**,
      // never re-joined against `baseUrl` (`HttpSource` owns that spelling).
      final _Rig r = _rig(novels: refsOf(1));

      await r.check.run(onProgress: r.onProgress, cancellation: neverCancelled);

      final Novel probe = r.site.lastDetailsProbe!;
      expect(
        probe.id,
        'n1',
        reason: 'B3 — the stored id is the identity handed over',
      );
      expect(
        probe.url,
        '/fiction/1/novel-1',
        reason: 'rule 3: relative, never re-joined',
      );
      expect(
        probe.author,
        isNull,
        reason: 'rule 8: the app never read an author',
      );
      expect(probe.description, isNull, reason: 'and never a description');
      expect(probe.coverUrl, isNull, reason: 'and never a cover');
      expect(
        probe.status,
        NovelStatus.unknown,
        reason: 'and not "ongoing" either',
      );
      expect(
        probe.genres,
        isEmpty,
        reason: 'and no genre the site did not publish',
      );
      expect(
        probe.title,
        'Novel 1',
        reason: 'the stored title IS the site\'s own text',
      );
    });
  });

  group('C7 — a 429 feeds the SHARED limiter, and the next novel waits', () {
    test(
      'the wait is the site\'s own Retry-After, recorded on the shared limiter',
      () async {
        // ⚠️ **FEEDING IT IS THE WHOLE CLAIM.** A limiter private to this class would stop
        // nothing: B39 says a pass visits every novel, so two novels from one rate-limited
        // site are read back to back unless the window is shared with `SourceHttpClient`.
        const Duration retryAfter = Duration(minutes: 2);
        final _Rig r = _rig(novels: refsOf(2));
        r.site.details = const BrowseFailed<Novel>(
          RateLimited(retryAfter: retryAfter),
          retriable: true,
        );
        r.site.beforeDetails = () => r.limiter.acquire('site.test');

        final LibraryCheckResult result = await r.check.run(
          onProgress: r.onProgress,
          cancellation: neverCancelled,
        );

        expect(
          (result.perNovel.first as NovelCheckFailed).kind,
          CheckFailureKind.rateLimited,
          reason:
              'C7: a 429 is never a zero new chapters, and never a no-connection',
        );
        expect(
          r.limiter.blockedUntil('site.test'),
          kNow.add(retryAfter),
          reason:
              '17-security.md rule 6: the duration is the header\'s, read never guessed',
        );
        expect(
          r.waits.contains(retryAfter),
          isTrue,
          reason:
              'and the NEXT request to that host waited it out — "we do not insist" is '
              'only true if the following novel actually waits',
        );
        expect(
          result.perNovel.length,
          2,
          reason: 'B39: rate limiting delays the pass, it never SKIPS a novel',
        );
        expect(result.failedCount, 2);
      },
    );

    test('a non-429 failure feeds the limiter nothing', () async {
      final _Rig r = _rig(novels: refsOf(1));
      r.site.details = const BrowseFailed<Novel>(
        NoConnection(host: 'site.test'),
        retriable: true,
      );

      await r.check.run(onProgress: r.onProgress, cancellation: neverCancelled);

      expect(
        r.limiter.blockedUntil('site.test'),
        isNull,
        reason:
            '17-security.md rule 6: back off on a site that ASKED; a dead socket did not',
      );
    });
  });

  group('the two failure tables are total, and each cause is typed', () {
    test('every `SourceFailure` cause maps to exactly one `CheckFailureKind`', () {
      // § 3.2's `map(reason)`. A cause with no arm would be a verdict chosen by whoever
      // wrote the next `switch`, which is why this is a table and not a chain of elses.
      //
      // ⚠️ **TWO LISTS SIDE BY SIDE, NOT A MAP.** `SourceFailure` overrides `==` and
      // `hashCode`, and a Dart `Map` keyed by those types can only be `final` — which reads
      // as a computed structure rather than the literal table it is. Two lists make the
      // correspondence positional and auditable.
      final List<SourceFailure> causes = <SourceFailure>[
        const NoConnection(host: 'h'),
        const RateLimited(retryAfter: Duration(seconds: 1)),
        const SourceLayoutChanged(failedSelector: 'tr', status: 200),
        const SourceUnavailable(status: 503),
        const ItemRemovedAtSource(itemId: 'i', status: 404),
        const ParseFailed(path: '/p'),
        const CauseUnknown(),
      ];
      final List<CheckFailureKind> verdicts = <CheckFailureKind>[
        CheckFailureKind.noConnection,
        CheckFailureKind.rateLimited,
        CheckFailureKind.sourceLayoutChanged,
        CheckFailureKind.sourceUnavailable,
        CheckFailureKind.itemRemovedAtSource,
        CheckFailureKind.parseFailed,
        // ⚠️ `CauseUnknown` is the cause that exists so the app can say it cannot say.
        CheckFailureKind.parseFailed,
      ];

      expect(
        causes.map(checkFailureKindOf).toList(),
        verdicts,
        reason:
            'architecture.md § 5.2 — seven causes reach the table by construction, and '
            'none of them falls through a `default` arm to a verdict nobody chose',
      );
      expect(
        causes.map((SourceFailure f) => f.runtimeType).toSet().length,
        causes.length,
        reason:
            'and the table is exercised on all seven arms, not on a convenient few',
      );
    });

    test(
      'every `AppException` maps to a verdict, and a store failure blames the app',
      () {
        final List<AppException> thrown = <AppException>[
          const NetworkException('down'),
          const SourceException('unparseable'),
          const DatabaseException('write failed'),
          const ChapterNotAvailableException('no body'),
          const CancelledException(),
        ];
        final List<CheckFailureKind> verdicts = <CheckFailureKind>[
          CheckFailureKind.noConnection,
          CheckFailureKind.parseFailed,
          CheckFailureKind.parseFailed,
          CheckFailureKind.parseFailed,
          // ⚠️ Unreachable in practice: `_checkOne` rethrows `CancelledException` before
          // this table is consulted (rule 7). It is here because the hierarchy is sealed
          // and the mapping must be total.
          CheckFailureKind.parseFailed,
        ];

        expect(
          thrown.map(kindOfAppException).toList(),
          verdicts,
          reason:
              '§ 3.2 branch 7 — and rule 7 keeps the cancellation arm unreachable, because '
              '`_checkOne` rethrows it before the table is ever consulted',
        );
      },
    );
  });
}
