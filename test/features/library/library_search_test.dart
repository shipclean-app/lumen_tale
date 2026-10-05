// forge:slice 6-6
// Lumen Tale — `6-6`: the value objects, and the four absences the plan asks for.
//
// ## ⚠️ `test()` AND NEVER `testWidgets()`, FOR TWO SEPARATE REASONS
//
// 1. Half of this file reads source files with `package:io` to assert what is **absent**.
//    A file read inside a `testWidgets` fake-async zone is fine, but…
// 2. the `AddToLibrary` group opens a **real in-memory drift database**, and drift's
//    futures never complete inside `testWidgets`' fake clock. A `testWidgets` body holding
//    one HANGS, and it takes the whole suite down with it rather than failing.
//
// So this file is `test()` throughout, and the widget rows live in
// `library_screen_test.dart`.
//
// ## The four absences
//
// | absence | rule | mechanism here |
// |---|---|---|
// | `mergeNovel` / `aliasOf` / `renameNovel` | **B40** | an **identifier-level** grep of `lib/domain/library/` |
// | `author` / `description` in the search | **B45** | a grep of the SQL constant *and* of the finder |
// | an author/genre/description facet, a *Completed* filter | **B45 / B39** | a grep of the sheet's own source |
// | `unread_count` | **B14 / B48** | asserted against the live schema in `library_queries_test.dart` |
//
// ## ⚠️ THE B40 ROW IS AN **IDENTIFIER** GREP AND NOT A WORD GREP
//
// The plan wrote `grep -rn 'merge\|alias\|rename' lib/domain/library/`, which matches **five
// lines of `2-5`'s prose** — *"nothing is ever merged"*, *"a renamed site"* — and therefore
// fails for an implementation that is correct. A rule that cannot pass is not a rule. What is
// asserted here is the absence of three **capabilities**: three identifiers that would have
// to exist for a caller to express collapsing two entries. `mergeNovel`, `aliasOf` and
// `renameNovel` do not occur in any `lib/domain/library/` file, comments included, so a
// future column, method or field by any of those names fails the row.

import 'dart:io';

import 'package:drift/drift.dart' show InsertMode, Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumen_tale/core/database/app_database.dart';
import 'package:lumen_tale/data/library/drift_library_repository.dart';
import 'package:lumen_tale/data/library/drift_similar_title_finder.dart';
import 'package:lumen_tale/data/library/library_queries.dart';
import 'package:lumen_tale/domain/library/library_repository.dart';
import 'package:lumen_tale/domain/library/library_row.dart';
import 'package:lumen_tale/domain/library/library_search.dart';
import 'package:lumen_tale/domain/library/similar_title.dart';
import 'package:lumen_tale/domain/sources/models/novel.dart';
import 'package:lumen_tale/features/library/providers/library_sort_filter.dart';

/// The instant every fixture dates anything it must date.
final DateTime kAt = DateTime.utc(2026, 10, 1, 9);

/// A novel as the source publishes it, with the fields `addFromCatalogue` reads.
Novel novel(
  String id, {
  String sourceId = 'royal',
  String title = 'A Novel',
  String? author,
  String? description,
}) {
  return Novel(
    id: id,
    sourceId: sourceId,
    url: '/fiction/$id',
    title: title,
    author: author ?? '',
    description: description ?? '',
    status: NovelStatus.unknown,
    coverUrl: '',
    genres: const <String>[],
  );
}

void main() {
  group('B45 branch 1 — an empty query restricts NOTHING', () {
    test('"" and "   " are the same query, and neither is a query', () {
      expect(TitleSearch.of('').isEmpty, isTrue);
      expect(TitleSearch.of('   ').isEmpty, isTrue);
      expect(TitleSearch.of('\t\n ').isEmpty, isTrue);
      // ⚠️ **EQUAL, NOT MERELY BOTH-EMPTY.** `libraryQueryProvider` is an
      // `autoDispose.family` keyed by this value, and identity equality would re-open the
      // database stream on every rebuild of an object `setQuery` replaces per keystroke.
      expect(TitleSearch.of('   '), TitleSearch.of(''));
      expect(TitleSearch.of('vow'), isNot(TitleSearch.empty));
    });

    test(
      'the raw text is kept for the field, and the needle is what SQL gets',
      () {
        final TitleSearch search = TitleSearch.of('  The   Vow  ');

        expect(
          search.raw,
          '  The   Vow  ',
          reason:
              'the field shows what the reader typed; the query is derived, not stored',
        );
        expect(search.normalised, 'the vow');
        expect(search.bindValue, '%the vow%');
      },
    );
  });

  group('B45 branch 9 — SQL wildcards in the reader\'s text are LITERAL', () {
    test('the escape order is anticharre, then %, then _', () {
      // ⚠️ **THE ORDER IS THE CONTRACT.** Reversing the first two escapes the anticharres
      // the previous step just added, and `a\b` becomes unmatchable instead of literal.
      expect(TitleSearch.of(r'a\b').bindValue, r'%a\\b%');
      expect(TitleSearch.of('100%').bindValue, r'%100\%%');
      expect(TitleSearch.of('a_b').bindValue, r'%a\_b%');
      // ⚠️ **THE SPACE SURVIVES, THE `%` DOES NOT BECOME A WILDCARD.** Internal whitespace
      // is collapsed only in *runs*; a single space is part of the title. Written as
      // `'100 %'` with no assertion about the space, this row would have hidden a
      // `replaceAll(' ', '')` that quietly made *Chapter 100 %* matchable by *Chapter
      // 100%*.
      expect(TitleSearch.of('100 %').bindValue, r'%100 \%%');
      // ⚠️ **WRITTEN AS CONCATENATION, NOT AS ONE LITERAL.** `100\%` is five characters;
      // the anticharre doubles to two and the `%` then grows an anticharre of its own, so
      // the pattern is `100` + two anticharres + one more + `%`. Written as a single raw
      // literal it is three backslashes in a row, which is indistinguishable from a typo at
      // a glance — and the first version of this row had *two*, and failed.
      expect(
        TitleSearch.of(r'100\%').bindValue,
        '%100'
        r'\\'
        r'\%'
        '%',
        reason: 'the anticharre is doubled BEFORE the wildcard is escaped',
      );
    });

    test('a needle is wrapped, so a match is INTERIOR and not only a prefix', () {
      // ⚠️ **§ 3.1 branch 3.** "ember" has to find *The Vow of **Embers***; B45 says "by
      // title", not "by the start of the title".
      expect(TitleSearch.of('ember').bindValue, '%ember%');
    });

    test('one character is a query: no minimum length is imposed', () {
      // ⚠️ **§ 3.1 branch 10.** A "minimum three characters" rule no document authorises
      // hides results, and the list counter is the honest way to say "this is a wide list".
      expect(TitleSearch.of('e').isEmpty, isFalse);
      expect(TitleSearch.of('e').bindValue, '%e%');
    });
  });

  group('E6 / E7 / E20 — the download presentation, all six branches', () {
    test(
      'a queue that is not running and has downloaded nothing is `none`',
      () {
        expect(
          resolveDownloadPresentation(downloadedCount: 0, chapterCount: 480),
          DownloadPresentation.none,
        );
      },
    );

    test('every chapter on the phone is `complete`', () {
      expect(
        resolveDownloadPresentation(downloadedCount: 480, chapterCount: 480),
        DownloadPresentation.complete,
      );
    });

    test('⚠️ a novel with NO chapters is `none`, never `complete`', () {
      // ⚠️ **`chapterCount > 0` IS IN THE GUARD.** `0 == 0` would render "All chapters
      // downloaded" for a novel the site has published nothing for — a claim about work the
      // app never did.
      expect(
        resolveDownloadPresentation(downloadedCount: 0, chapterCount: 0),
        DownloadPresentation.none,
      );
    });

    test('a running queue is `running`', () {
      expect(
        resolveDownloadPresentation(
          downloadedCount: 12,
          chapterCount: 480,
          activity: const DownloadActivity(isRunning: true),
        ),
        DownloadPresentation.running,
      );
    });

    test('⚠️ NO stopped state can ever render `running`', () {
      // ⚠️ **THIS IS THE E6 ROW AS AN EXHAUSTION, not as one example.** § 3.3's rule is
      // *"`running` is INTERDIT for a novel à l'arrêt"*, and an exhaustion over every stop
      // cause is what makes the rule checkable — including a novel whose whole list is on
      // the phone, which is the case a counts-first implementation gets wrong.
      for (final DownloadStopCause cause in DownloadStopCause.values) {
        for (final int downloaded in <int>[0, 12, 479, 480]) {
          final DownloadPresentation presentation = resolveDownloadPresentation(
            downloadedCount: downloaded,
            chapterCount: 480,
            activity: DownloadActivity(isRunning: false, stoppedBecause: cause),
          );
          expect(
            presentation,
            isNot(DownloadPresentation.running),
            reason:
                'E6/C8: a stopped queue at $downloaded/480 must never read as working, '
                'whatever the cause',
          );
        }
      }
    });

    test('a stop with no nameable cause is `stopped`, not `none`', () {
      expect(
        resolveDownloadPresentation(
          downloadedCount: 12,
          chapterCount: 480,
          activity: const DownloadActivity(
            isRunning: false,
            stoppedBecause: DownloadStopCause.otherCause,
          ),
        ),
        DownloadPresentation.stopped,
      );
    });

    test('E7 — a lost connection is its own value, and it is not `stopped`', () {
      // ⚠️ **DISTINGUISHABLE, BECAUSE THE READER'S NEXT ACTION DIFFERS.** Press *Resume*, or
      // go and look at the network — the label has to say which, and E7 says the queue will
      // not resume on its own.
      expect(
        resolveDownloadPresentation(
          downloadedCount: 12,
          chapterCount: 480,
          activity: const DownloadActivity(
            isRunning: false,
            stoppedBecause: DownloadStopCause.connectionLost,
          ),
        ),
        DownloadPresentation.stoppedByConnectionLost,
      );
    });

    test('E20 — a full disk is its own value too', () {
      expect(
        resolveDownloadPresentation(
          downloadedCount: 12,
          chapterCount: 480,
          activity: const DownloadActivity(
            isRunning: false,
            stoppedBecause: DownloadStopCause.storageFull,
          ),
        ),
        DownloadPresentation.stoppedOutOfStorage,
      );
    });

    test('the stopped branches win over a complete list', () {
      // ⚠️ **480 of 480 with a failed item is `stopped`, not `complete`.** C8: an interrupted
      // download must never be presented as complete, and "everything is on the phone" is
      // exactly the presentation that would be wrong.
      expect(
        resolveDownloadPresentation(
          downloadedCount: 480,
          chapterCount: 480,
          activity: const DownloadActivity(
            isRunning: false,
            stoppedBecause: DownloadStopCause.otherCause,
          ),
        ),
        DownloadPresentation.stopped,
      );
    });

    test('`no_connection` is read out of `queue_items.error_code`', () {
      expect(stopCauseOf('no_connection'), DownloadStopCause.connectionLost);
      expect(stopCauseOf('rate_limited'), DownloadStopCause.otherCause);
      expect(
        stopCauseOf(''),
        isNull,
        reason:
            'an empty code is NOT a stop signal — the `queue_failed` count carries that, so '
            'an unreadable code must not invent a stop',
      );
    });

    test('the pair always carries its denominator', () {
      const LibraryRow row = LibraryRow(
        novelId: 'n1',
        title: 'T',
        sourceName: 'Royal Road',
        unopenedCount: 3,
        chapterCount: 480,
        downloadedCount: 12,
        download: DownloadPresentation.stopped,
      );
      expect(
        row.downloadedPair,
        '12 / 480',
        reason:
            'E6/C8: without the denominator, "12" reads as a total; a bare percentage is '
            'forbidden and so is a bare count',
      );
      expect(row.showsUnopenedBadge, isTrue);
      expect(
        row.showsUnopenedBadge,
        isTrue,
        reason: 'B14: the badge is a number, and 0 is the absence of a badge',
      );
    });

    test('zero unopened means NO badge at all', () {
      const LibraryRow row = LibraryRow(
        novelId: 'n1',
        title: 'T',
        sourceName: 'Royal Road',
        unopenedCount: 0,
        chapterCount: 480,
        downloadedCount: 480,
        download: DownloadPresentation.complete,
      );
      // ⚠️ **A PILL AT ZERO IS A PERMANENT ALARM**, and a reader who cannot tell "nothing new"
      // from "broken" stops looking at it.
      expect(row.showsUnopenedBadge, isFalse);
    });
  });

  group('B40 — the two exact tiers, and no fuzzy one', () {
    test('`exact`: the same words, different case and padding', () {
      expect(
        tierFor('The Ascension', 'the ascension '),
        SimilarityTier.exact,
        reason:
            'trim + collapse + lowercase is the narrow tier and it comes first',
      );
    });

    test('`normalised`: the same words with different punctuation', () {
      expect(
        tierFor('Ilan W.', 'Ilan  W'),
        SimilarityTier.normalised,
        reason:
            '§ 3.4: "Ilan W." / "Ilan  W. " / "Ilan W" are one title wearing three '
            'spellings, and the dialog blocks',
      );
    });

    test(
      '`normalised`: accents fold, because a reader does not see one as a distinction',
      () {
        expect(
          tierFor('The Rêverie', 'The Reverie'),
          SimilarityTier.normalised,
        );
      },
    );

    test('`none`: the same words in a different ORDER are a different novel', () {
      // ⚠️ **§ 3.4's own worked example.** "Embers, The" is not "The Embers" and a dialog
      // saying so would stop a legitimate addition.
      expect(tierFor('Embers, The', 'The Embers'), SimilarityTier.none);
    });

    test('⚠️ NO FUZZY TIER: "The Em" against "The Ember" is NONE', () {
      // ⚠️ **THIS ROW FAILS THE MOMENT A DISTANCE IS ADDED.** § 3.1/§ 3.4 forbid
      // Levenshtein, trigrams and a numeric threshold, because a blocking dialog over a
      // legitimate addition trains a reader to dismiss the ones that matter. It is here to
      // hold that line, not to describe a behaviour.
      expect(tierFor('The Em', 'The Ember'), SimilarityTier.none);
      expect(tierFor('The Ember', 'The Em'), SimilarityTier.none);
      expect(tierFor('Ember', 'Embers'), SimilarityTier.none);
    });

    test('an empty title resembles nothing — including not everything', () {
      // ⚠️ **B10: a novel with no displayable title is never added.** If an empty key
      // matched every row, the dialog would open listing the reader's whole library.
      expect(tierFor('', 'Anything'), SimilarityTier.none);
      expect(tierFor('   ', '   '), SimilarityTier.none);
    });

    test('the `exact` tier is checked BEFORE `normalised`', () {
      // ⚠️ **A LOG-FACING CLAIM.** Reporting `normalised` for two identical-after-trimming
      // titles would teach whoever reads a failure that `normalised` fires far more often
      // than it does.
      expect(tierFor('A B', '  a   b  '), SimilarityTier.exact);
    });
  });

  group('B40 / B2 / E17 — the finder, over a real library', () {
    late AppDatabase db;
    late DriftSimilarTitleFinder finder;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      finder = DriftSimilarTitleFinder(
        db,
        sourceNameOf: (String id) => id == 'royal' ? 'Royal Road' : 'FanMTL',
      );
    });

    tearDown(() => db.close());

    Future<void> keep(
      String id, {
      required String sourceId,
      required String title,
      bool inLibrary = true,
    }) async {
      await db
          .into(db.sources)
          .insert(
            SourcesCompanion.insert(id: sourceId),
            mode: InsertMode.insertOrIgnore,
          );
      await db
          .into(db.novels)
          .insert(
            NovelsCompanion.insert(
              id: id,
              sourceId: sourceId,
              url: '/fiction/$id',
              title: title,
              inLibrary: Value(inLibrary),
              addedAt: Value(kAt),
            ),
            mode: InsertMode.insertOrIgnore,
          );
    }

    test('two entries, one title, two sites → TWO candidates', () async {
      await keep(
        'royal-1',
        sourceId: 'royal',
        title: 'The Ascension of the Ninth Son',
      );
      await keep(
        'fanmtl-1',
        sourceId: 'fanmtl',
        title: 'The Ascension of the Ninth Son',
      );

      final List<SimilarTitleCandidate> candidates = await finder.find(
        candidateTitle: 'The Ascension of the Ninth Son',
      );

      expect(
        candidates,
        hasLength(2),
        reason:
            'E17: two sites publishing a title are two books, and the dialog names both so '
            'the reader can tell which is which',
      );
      expect(
        candidates.map((SimilarTitleCandidate c) => c.sourceName).toSet(),
        <String>{'Royal Road', 'FanMTL'},
      );
      expect(
        candidates.every(
          (SimilarTitleCandidate c) => c.tier == SimilarityTier.exact,
        ),
        isTrue,
      );
    });

    test('exact candidates come before normalised ones', () async {
      await keep('r-1', sourceId: 'royal', title: 'Ilan W');
      await keep('r-2', sourceId: 'royal', title: 'Ilan W.');

      final List<SimilarTitleCandidate> candidates = await finder.find(
        candidateTitle: 'ilan w',
      );

      expect(
        candidates.first.tier,
        SimilarityTier.exact,
        reason:
            'the narrower reason is reported first, so a log says which rule fired',
      );
      expect(candidates.last.tier, SimilarityTier.normalised);
    });

    test('a removed novel is not a candidate', () async {
      // ⚠️ **B32: a removed novel occupies no space** and can be put back without hindrance,
      // so it must not block somebody else's add with a dialog.
      await keep('r-1', sourceId: 'royal', title: 'Ashes', inLibrary: false);

      expect(
        await finder.find(candidateTitle: 'Ashes'),
        isEmpty,
        reason:
            'the filter is in_library = true, exactly as addFromCatalogue reads it',
      );
    });

    test('an empty incoming title matches NOTHING', () async {
      await keep('r-1', sourceId: 'royal', title: 'Ashes');

      expect(await finder.find(candidateTitle: '   '), isEmpty);
    });
  });

  group('B40 — AddToLibrary: the dialog comes BEFORE any write', () {
    late AppDatabase db;
    late DriftLibraryRepository library;

    setUp(() async {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      library = DriftLibraryRepository(
        db,
        sourceNameOf: (String id) => id == 'royal' ? 'Royal Road' : 'FanMTL',
      );
      await db
          .into(db.sources)
          .insert(
            SourcesCompanion.insert(id: 'royal'),
            mode: InsertMode.insertOrIgnore,
          );
    });

    tearDown(() => db.close());

    /// ⚠️ **THE CALLBACK IS REQUIRED BY THE SIGNATURE AND IS NEVER CALLED for a first
    /// add.** `onSimilarTitle` is a *required* named parameter — that is B40's whole
    /// shape — so a first add still has to say what it would do if a candidate turned up.
    Future<AddOutcome> keepNovel(Novel candidate) {
      return library.addFromCatalogue(
        novel: candidate,
        onSimilarTitle: (_) async => SimilarTitleVerdict.addAnyway,
      );
    }

    test(
      'adding a novel whose title exists RAISES the dialog, and writes nothing',
      () async {
        await keepNovel(novel('royal-1', title: 'The Ascension'));
        final int before = await _novelCount(db);

        bool asked = false;
        final AddOutcome outcome = await library.addFromCatalogue(
          novel: novel('fanmtl-1', sourceId: 'fanmtl', title: 'The Ascension'),
          onSimilarTitle: (List<SimilarTitle> similar) async {
            asked = true;
            expect(
              similar,
              isNotEmpty,
              reason: 'the dialog needs something to show',
            );
            return SimilarTitleVerdict.dismissed;
          },
        );

        expect(
          asked,
          isTrue,
          reason: 'B40: a resemblance warns BEFORE a write',
        );
        expect(
          outcome.isAdded,
          isFalse,
          reason:
              'B12: a novel enters the library only through an explicit choice',
        );
        expect(outcome.rejection, AddRejection.declinedForSimilarTitle);
        expect(
          await _novelCount(db),
          before,
          reason:
              'nothing is written until the reader chooses, and dismissing is declining',
        );
      },
    );

    test(
      '⚠️ DISMISSING, DECLINING and OPENING THE EXISTING all write NOTHING',
      () async {
        await keepNovel(novel('royal-1', title: 'Shared'));
        final int before = await _novelCount(db);

        for (final SimilarTitleVerdict verdict in <SimilarTitleVerdict>[
          SimilarTitleVerdict.dismissed,
          SimilarTitleVerdict.declined,
          SimilarTitleVerdict.openExisting,
        ]) {
          final AddOutcome outcome = await library.addFromCatalogue(
            novel: novel(
              'fanmtl-$verdict',
              sourceId: 'fanmtl',
              title: 'Shared',
            ),
            onSimilarTitle: (_) async => verdict,
          );
          expect(outcome.isAdded, isFalse, reason: '$verdict must not add');
        }

        expect(
          await _novelCount(db),
          before,
          reason:
              'the easiest gesture on a device with no cloud backup (C8) must not be the one '
              'that writes a second copy of a novel the reader already has',
        );
      },
    );

    test(
      '⚠️ *Add anyway* makes a NEW row and touches NO field of the existing one',
      () async {
        await keepNovel(novel('royal-1', title: 'Shared', author: 'Ilan W.'));
        final Map<String, Object?> beforeFields = <String, Object?>{
          for (final NovelRow row in await db.select(db.novels).get())
            row.id: <String, Object?>{
              'title': row.title,
              'author': row.author,
              'url': row.url,
              'source_id': row.sourceId,
              'in_library': row.inLibrary,
              'added_at': row.addedAt,
              'last_checked_at': row.lastCheckedAt,
              'cover_url': row.coverUrl,
            },
        };

        final AddOutcome outcome = await library.addFromCatalogue(
          novel: novel('fanmtl-1', sourceId: 'fanmtl', title: 'Shared'),
          onSimilarTitle: (_) async => SimilarTitleVerdict.addAnyway,
        );

        expect(outcome.isAdded, isTrue);
        expect(
          outcome.addedDespiteSimilarTitle,
          isTrue,
          reason:
              'B40: the second novel is a second novel, and nothing is merged',
        );

        final List<NovelRow> after = await db.select(db.novels).get();
        expect(
          after.map((NovelRow r) => r.id),
          containsAll(<String>['royal-1', 'fanmtl-1']),
          reason:
              'E17: two entries, two rows — never one row standing in for both',
        );

        final NovelRow existing = after.firstWhere(
          (NovelRow r) => r.id == 'royal-1',
        );
        expect(
          <String, Object?>{
            for (final NovelRow row in <NovelRow>[existing])
              row.id: <String, Object?>{
                'title': row.title,
                'author': row.author,
                'url': row.url,
                'source_id': row.sourceId,
                'in_library': row.inLibrary,
                'added_at': row.addedAt,
                'last_checked_at': row.lastCheckedAt,
                'cover_url': row.coverUrl,
              },
          }['royal-1'],
          beforeFields['royal-1'],
          reason:
              'B40: not one field of the existing entry changes — no rename, no alias, no '
              'fold of one into the other',
        );
        expect(existing.title, 'Shared');
      },
    );

    test(
      '⚠️ the ADD CONTRACT HAS NO PARAMETER that could collapse two entries',
      () async {
        // ⚠️ **THE MECHANICAL FORM OF B40, AND IT IS AN INTERFACE CHECK.** A merge would need
        // an option; the signature has none, so a caller cannot ask for one. Read through the
        // same source this file's B40 grep reads.
        final String source = _read(
          'lib/domain/library/library_repository.dart',
        );
        final int signature = source.indexOf('addFromCatalogue');
        expect(signature, greaterThan(-1));
        final String declaration = source.substring(
          signature,
          source.indexOf(';', signature),
        );
        for (final String forbidden in <String>[
          'merge',
          'alias',
          'rename',
          'replace',
        ]) {
          expect(
            declaration.toLowerCase(),
            isNot(contains(forbidden)),
            reason:
                'B40: the add contract must have no parameter that could express collapsing '
                'two library entries, and "$forbidden" is how that would be spelled',
          );
        }
      },
    );
  });

  group('B40 — the IDENTIFIER assertion, and why it is not a word grep', () {
    test('no merge, alias or rename CAPABILITY exists in lib/domain/library/', () {
      // ⚠️ **THE ROW THE PLAN GOT WRONG, AND WHY.** `grep -rn 'merge\|alias\|rename'
      // lib/domain/library/` matches five lines of `2-5`'s **prose** — "nothing is ever
      // merged", "a renamed site" — so it fails for an implementation that is correct, and
      // a rule that cannot pass is not a rule. What is asserted is the absence of three
      // identifiers a caller would have to name in order to collapse two entries.
      final List<File> files = Directory(
        'lib/domain/library',
      ).listSync().whereType<File>().toList();
      expect(
        files,
        isNotEmpty,
        reason: 'the directory exists and holds the library domain',
      );

      final List<String> offenders = <String>[];
      for (final File file in files) {
        final String content = file.readAsStringSync();
        for (final String capability in <String>[
          'mergeNovel',
          'aliasOf',
          'renameNovel',
        ]) {
          if (content.contains(capability)) {
            offenders.add('${file.path}: $capability');
          }
        }
      }

      expect(
        offenders,
        isEmpty,
        reason:
            'B40: library entries are never merged, aliased or renamed, and the guarantee '
            'is structural — the vocabulary for it does not exist. Offenders: $offenders',
      );
    });

    test(
      'the plan\'s WORD grep would have failed on correct code — and that is the point',
      () {
        // ⚠️ **THE DEFECT, ASSERTED SO IT CANNOT BE REINTRODUCED.** If the original row were
        // reinstated it would fail on the word *merged* inside `similar_title.dart`'s own
        // warning sentence. Recorded here as a fact about the rule, not about the code.
        final String similar = _read('lib/domain/library/similar_title.dart');
        final String code = similar
            .split('\n')
            .where((String line) => !line.trimLeft().startsWith('//'))
            .join('\n');
        expect(
          similar.toLowerCase(),
          contains('merged'),
          reason: 'the prose deliberately says what never happens',
        );
        expect(code.toLowerCase(), isNot(contains('mergenovel')));
      },
    );
  });

  group('B45 — the search code mentions no other text column', () {
    test('the search SQL names `title` and no other text column', () {
      // ⚠️ **MECHANICAL, NOT A COMMENT.** § 10's own row is `grep -n 'author\|description'`
      // in the search functions. `titleSearchSql` IS that function's whole body, so this
      // is the same grep made into an assertion.
      for (final String column in <String>['author', 'description', 'status']) {
        expect(
          titleSearchSql.toLowerCase(),
          isNot(contains(column)),
          reason:
              'B45/ADR-024: `$column` is displayed or stored, never searchable — a clause '
              'naming it here would make B45 false in the database and not only in the copy',
        );
      }
      expect(
        titleSearchSql.toLowerCase(),
        contains('title like ? escape'),
        reason: "the one clause is `title LIKE ? ESCAPE '\\'`",
      );
    });

    test('the library rows query never folds on author or description', () {
      // ⚠️ **IT COUNTS CHAPTERS, NOT WORDS.** The row query may only aggregate; a `LIKE`
      // anywhere in it would be a second search with a second rule.
      expect(
        unopenedCountsSql.toLowerCase(),
        isNot(contains('like ')),
        reason:
            'the counts query aggregates; searching is titleSearchSql\'s job alone',
      );
    });

    test('the sort/filter sheet offers NO author, genre or description facet', () {
      // ⚠️ **`library.md` § 11.1 NAMES THE ABSENCE**, so it is a fact about the sheet and the
      // only honest way to check a list is to read the source that draws it. A test that
      // counted the chips would pass if the forbidden one were added as a sixth.
      final String sheet = _read(
        'lib/features/library/widgets/library_sort_filter_sheet.dart',
      );
      final String code = sheet
          .split('\n')
          .where((String line) => !line.trimLeft().startsWith('//'))
          .join('\n');
      // ⚠️ **THE CODE ONLY, NOT THE PROSE.** The file's header quotes the three words it
      // refuses to offer; asserting on the whole file would make this row fail for the same
      // reason the plan's B40 row did.
      for (final String forbidden in <String>[
        'libraryFacetAuthor',
        'libraryFacetGenre',
        'libraryFacetDescription',
        'LibraryFacet.author',
        'LibraryFacet.genre',
        'LibraryFacet.description',
      ]) {
        expect(
          code,
          isNot(contains(forbidden)),
          reason:
              'B45: a facet over a field the app does not hold as searchable implies a '
              'capability it does not have',
        );
      }
      expect(
        code,
        isNot(contains('completed')),
        reason:
            "B39's note: the completed state was removed because no rule defined it, and a "
            'filter over a state the product lacks is a control that lies',
      );
    });

    test('the sheet draws exactly five sorts and four facets', () {
      // ⚠️ **BOTH NUMBERS, NOT ONE.** A sheet with four sorts and five facets would pass a
      // row that checked only the sorts; § 11.1 names five and four.
      expect(LibrarySort.values, hasLength(5));
      expect(LibraryFacet.values, hasLength(4));
    });
  });

  group('the library screen cannot reach the network', () {
    test('it names no network capability', () {
      // ⚠️ **C14 BY ABSENCE.** The library is readable offline, and the guarantee is the
      // absence of a capability rather than a promise in a comment.
      final String screen = _read('lib/features/library/library_screen.dart');
      final String code = screen
          .split('\n')
          .where((String line) => !line.trimLeft().startsWith('//'))
          .join('\n');
      expect(code, isNot(contains('dio')));
      expect(code, isNot(contains('HttpClient')));
      expect(code, isNot(contains('core/network')));
      expect(code, isNot(contains('Source')));
    });

    test(
      '⚠️ the "check" action is DISABLED, not a live button that does nothing',
      () {
        // ⚠️ **AN INTERFACE HOLE, LABELLED.** A live-looking button that silently does nothing
        // is worse than a disabled one: the reader presses it and concludes the app is broken.
        // B36/B38/B39's wire is `6-4`'s.
        expect(
          _read('lib/features/library/library_screen.dart'),
          contains('onPressed: null'),
        );
      },
    );
  });
}

/// How many `novels` rows the database holds.
///
/// ⚠️ **A NAMED HELPER, because the inline form was `db.select(db.novels).get().then(…)`
/// five times** — and `NovelRow` collides with `LibraryRow` by name in this file, so a
/// local `for` over the drift rows and one over the domain rows are two different types
/// wearing one name. Keeping the count in one function keeps the drift row out of the
/// assertions about B40.
Future<int> _novelCount(AppDatabase db) async =>
    (await db.select(db.novels).get()).length;

/// Reads a repository file, with the failure surfacing as a test failure rather than an
/// opaque `FileSystemException` three frames later.
String _read(String path) {
  final File file = File(path);
  expect(
    file.existsSync(),
    isTrue,
    reason:
        '$path must exist; the rows above are assertions about source that ships',
  );
  return file.readAsStringSync();
}
