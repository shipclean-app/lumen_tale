// Lumen Tale — the two doubles `6-4`'s tests share.
//
// ⚠️ **NOT A TEST FILE.** It carries no `// forge:slice` marker on purpose: the Forge
// guard resolves a slice's tests through that marker, and a file with no `test()` in it
// would otherwise count as a file that declares the slice and verifies nothing.
//
// ## Why a hand-written spy and not `mocktail`
//
// Both of these need to do something no mock can: **count**, and **be a real
// `ParsedHttpSource`** so B38's "the only methods this slice calls" claim is measured on
// the actual contract rather than on a proxy of it. `10-testing.md` §4 prefers in-memory
// fakes for exactly this case.
//
// | fake | what it stands in for | the claim it carries |
// |---|---|---|
// | [SpySource] | a site | B38 — which contract methods were called, and how often |
// | [RecordingStore] | the `6-3 → 6-4` boundary | B49 — **which** writes happened, per novel |

// `sort_constructors_first` is a project rule, and a fake with fields declared after its
// constructor trips it; both classes below declare fields first for that reason.

import 'package:lumen_tale/core/error/source_failure.dart';
import 'package:lumen_tale/domain/library/library_repository.dart';
import 'package:lumen_tale/domain/sources/browse_outcome.dart';
import 'package:lumen_tale/domain/sources/models/chapter.dart';
import 'package:lumen_tale/domain/sources/models/filter.dart';
import 'package:lumen_tale/domain/sources/models/novel.dart';
import 'package:lumen_tale/domain/sources/models/novels_page.dart';
import 'package:lumen_tale/domain/sources/models/update.dart';
import 'package:lumen_tale/domain/sources/source.dart';
import 'package:lumen_tale/domain/sources/source_id.dart';
import 'package:lumen_tale/domain/updates/library_check.dart';

/// A site that answers whatever the test tells it to, and records everything asked of it.
///
/// ⚠️ **`fetchChapterContent` COUNTS AND THEN THROWS.** The B38 claim is that this pass
/// never asks a site for a chapter body. A counter that silently returned a value would
/// make the violation silent too — so the call both records itself and aborts the read it
/// was not supposed to make, and the pass reports the source as broken. A test that
/// asserted only the count would still catch it; one that asserted only the outcome would
/// not.
final class SpySource implements ParsedHttpSource {
  SpySource({this.sourceId = 'src-a', this.host = 'site.test'});

  /// The registry id. Not an `@override`: `Source.id` is a getter and this is the field
  /// behind it.
  final String sourceId;

  /// The host [baseUrl] is built from, so `hostOf` — and therefore the rate-limit slot a
  /// `429` is recorded against — resolves to something a test can read back.
  final String host;

  /// What `getNovelDetails` answers. `null` means *the novel is still there*: the spy
  /// echoes the probe it was handed, which is the honest healthy answer.
  BrowseOutcome<Novel>? details;

  /// What `getChapterList` answers. `null` means *an empty but read page*.
  BrowseOutcome<List<Chapter>>? chapters;

  /// Thrown **instead of** an answer, so `13-error-handling.md` rule 1 and B23 are
  /// testable with a source that misbehaves the way a real one does.
  ///
  /// ⚠️ **TYPED `Exception`, NOT `Object`.** A bare `Exception` is precisely what rule 1
  /// forbids a *source* to throw, so this column is how a row reproduces the defect
  /// deliberately; the wider `Object` would also let a fixture throw a bare `String`, and
  /// `only_throw_errors` is right to object to that.
  Exception? throwFromDetails;
  Exception? throwFromChapters;

  /// Per-novel overrides for [details] and [chapters].
  ///
  /// ⚠️ **A WHOLE-SITE [details] FAILS EVERY NOVEL IT SERVES.** The B39 row needs *one*
  /// novel failing and the others succeeding, and a site that cannot be read cannot fail
  /// only one of its novels — so the per-novel answers live here and [details] stays the
  /// whole-site default.
  Map<String, BrowseOutcome<Novel>> detailsFor =
      <String, BrowseOutcome<Novel>>{};
  Map<String, BrowseOutcome<List<Chapter>>> chaptersFor =
      <String, BrowseOutcome<List<Chapter>>>{};

  /// Ids for which the site genuinely cannot be read, as opposed to a page whose shape is
  /// wrong. Reachable only as a [NoConnection] — a transport failure belongs to the host,
  /// not to one row of it.
  Set<String> offlineFor = <String>{};

  /// Awaited before every `getNovelDetails`. The C7 row uses it to acquire the **shared**
  /// limiter exactly the way `SourceHttpClient`'s interceptor does, so "no request during
  /// the wait" is measured at the request entrance rather than asserted.
  Future<void> Function()? beforeDetails;

  /// Every contract method that was entered, in order. § 3.3's "the only network calls
  /// are two" is read off this list.
  final List<String> calls = <String>[];

  /// B38's row, counted.
  int contentCalls = 0;

  /// The `Novel` the interactor handed over on the last `getNovelDetails`.
  ///
  /// ⚠️ **KEPT BECAUSE THE PROBE IS A CLAIM.** A `Novel` has `author`, `description`,
  /// `coverUrl` and `status`, and the probe the interactor builds decides what each of
  /// them says before the site has said anything (`03-source-system.md` rule 8).
  Novel? lastDetailsProbe;

  /// The `Novel` the chapter list was read for — the site\'s answer, not the probe.
  Novel? lastChapterListNovel;

  @override
  String get id => sourceId;

  @override
  String get name => 'Spy Site';

  @override
  String get lang => 'en';

  @override
  bool get supportsLatest => false;

  @override
  bool get supportsSearch => false;

  @override
  FilterList get filterList => FilterList(const <Filter<Object?>>[]);

  @override
  String get baseUrl => 'https://$host';

  @override
  int get versionId => 1;

  @override
  Future<BrowseOutcome<Novel>> getNovelDetails(Novel novel) async {
    calls.add('getNovelDetails');
    lastDetailsProbe = novel;
    await beforeDetails?.call();
    final Exception? thrown = throwFromDetails;
    if (thrown != null) throw thrown;
    return detailsFor[novel.id] ??
        details ??
        (offlineFor.contains(novel.id)
            ? const BrowseFailed<Novel>(
                NoConnection(host: 'site.test'),
                retriable: true,
              )
            : BrowseSucceeded<Novel>(<Novel>[novel]));
  }

  @override
  Future<BrowseOutcome<List<Chapter>>> getChapterList(Novel novel) async {
    calls.add('getChapterList');
    lastChapterListNovel = novel;
    final Exception? thrown = throwFromChapters;
    if (thrown != null) throw thrown;
    return chaptersFor[novel.id] ??
        chapters ??
        const BrowseSucceeded<List<Chapter>>(<List<Chapter>>[]);
  }

  @override
  Future<BrowseOutcome<String>> fetchChapterContent(Chapter chapter) async {
    contentCalls++;
    calls.add('fetchChapterContent');
    throw StateError(
      'B38: a check never reads a chapter body; $sourceId was asked for '
      '${chapter.id}',
    );
  }

  // ── the rest of the contract. A check must never reach them, and `calls` proves it.

  @override
  Future<BrowseOutcome<NovelsPage>> getPopularNovels(int page) async {
    calls.add('getPopularNovels');
    return const BrowseFailed<NovelsPage>(CauseUnknown(), retriable: false);
  }

  @override
  Future<BrowseOutcome<NovelsPage>> getLatestNovels(int page) async {
    calls.add('getLatestNovels');
    return const BrowseFailed<NovelsPage>(CauseUnknown(), retriable: false);
  }

  @override
  Future<BrowseOutcome<NovelsPage>> searchNovels(
    int page,
    String query,
    FilterList filters,
  ) async {
    calls.add('searchNovels');
    return const BrowseFailed<NovelsPage>(CauseUnknown(), retriable: false);
  }

  @override
  Future<BrowseOutcome<NovelUpdate>> getNovelUpdate(
    Novel novel,
    List<Chapter> chapters, {
    required bool fetchDetails,
    required bool fetchChapters,
  }) async {
    calls.add('getNovelUpdate');
    return const BrowseFailed<NovelUpdate>(CauseUnknown(), retriable: false);
  }
}

/// The `6-3 → 6-4` boundary, in memory, recording every write.
///
/// ⚠️ **THE POINT IS THE NEGATIVE SPACE.** `recordChecked` and `recordCheckFailure` are
/// recorded *separately* because B49's whole claim is which of the two a given branch
/// called: a check that could not look must leave `lastCheckedAt` absent. A single
/// `Set<DateTime>` of "touched" rows could not tell those apart.
final class RecordingCheckStore implements LibraryCheckStore {
  RecordingCheckStore({
    List<LibraryNovelRef>? novels,
    this.sourceEnabled = true,
  }) : novels = novels ?? <LibraryNovelRef>[];

  List<LibraryNovelRef> novels;

  bool sourceEnabled;

  /// Thrown by `listLibraryNovels`, so § 3.1's "a local store failure is the screen's
  /// error state, not a per-novel failure" row has something to throw.
  ///
  /// ⚠️ **AN UNWRAPPED DRIFT ERROR, ON PURPOSE.** The interactor's job for this call is to
  /// re-type whatever the store raised into a [DatabaseException]; a fixture that threw a
  /// tidy `AppException` would make that wrapper look like a no-op.
  Object? throwFromList;

  final List<String> calls = <String>[];

  /// B49 — written by `recordChecked` **only**.
  final Map<String, DateTime> checkedAt = <String, DateTime>{};

  /// B22 / B24 — written by `recordCheckFailure` **only**, typed, never a free string.
  final Map<String, CheckFailureKind> failures = <String, CheckFailureKind>{};

  /// B3 — the chapter ids this store already holds, so `mergeChapterList` can report rows
  /// *actually added* the way the drift one does.
  final Set<String> knownChapterIds = <String>{};

  /// Everything handed to `mergeChapterList`, flattened, in order.
  final List<NewChapter> merged = <NewChapter>[];

  @override
  Future<List<LibraryNovelRef>> listLibraryNovels() async {
    calls.add('listLibraryNovels');
    final Object? thrown = throwFromList;
    if (thrown != null) Error.throwWithStackTrace(thrown, StackTrace.current);
    return List<LibraryNovelRef>.unmodifiable(novels);
  }

  @override
  Future<bool> isSourceEnabled(String sourceId) async {
    calls.add('isSourceEnabled');
    return sourceEnabled;
  }

  @override
  Future<void> recordChecked(String novelId, DateTime at) async {
    calls.add('recordChecked');
    checkedAt[novelId] = at;
  }

  @override
  Future<void> recordCheckFailure(String novelId, CheckFailureKind kind) async {
    calls.add('recordCheckFailure');
    failures[novelId] = kind;
  }

  @override
  Future<int> mergeChapterList(String novelId, List<NewChapter> fresh) async {
    calls.add('mergeChapterList');
    merged.addAll(fresh);
    int added = 0;
    for (final NewChapter chapter in fresh) {
      if (knownChapterIds.add(chapter.id)) added++;
    }
    return added;
  }
}

/// A library novel the store hands over, with the stored relative url.
LibraryNovelRef refOf(int index, {String sourceId = 'src-a'}) =>
    LibraryNovelRef(
      novelId: 'n$index',
      sourceId: sourceId,
      title: 'Novel $index',
      url: '/fiction/$index/novel-$index',
    );

/// [count] library novels, numbered `n1 … n<count>`.
List<LibraryNovelRef> refsOf(int count, {String sourceId = 'src-a'}) =>
    List<LibraryNovelRef>.generate(
      count,
      (int i) => refOf(i + 1, sourceId: sourceId),
      growable: false,
    );

/// One chapter as a site would publish it.
///
/// [number] defaults to the index so a test can state a site whose order and numbers
/// disagree — Royal Road's is exactly that shape (B9).
Chapter chapterOf(String novelId, int index, {double? number, String? name}) =>
    Chapter(
      id: SourceId.forChapter(
        novelId: novelId,
        relativeUrl: '/fiction/$novelId/chapter/$index',
      ),
      novelId: novelId,
      url: '/fiction/$novelId/chapter/$index',
      name: name ?? 'Chapter $index',
      number: number ?? index.toDouble(),
    );
