// forge:slice 3-2
// Lumen Tale — `ChapterEntry`, the row the chapter tile renders, and
// `ChapterListFetchResult`, the count printed above it.
//
// Pure Dart: no widget binding, no database, no network. Every row below is a rule a reader
// can see on a tile — a rendered label, a count, an identity, a partial copy — which is why
// several of them assert what is **not** shown rather than what is.
//
// ## The rows that carry the slice
//
// | rule | the row |
// |---|---|
// | B10 — `-1` never reaches a tile, `0` stays `0` | *an unreadable number is an em dash, and `0` renders as `0`* |
// | E3 — the count is **chapters**, never the site's pages | *three entries count three; a chapter over three pages counts once* |
// | `08-coding-standards.md` — never expose a mutable collection | *the entries list throws on `add`* |
// | a value is compared, never identified | *equal fields are equal and hash alike, and every field is in the identity* |
// | `copyWith` is a **partial** change | *only the fields it was given move* |
// | null means *unchanged*, never *cleared* | *`copyWith(isRead: null)` keeps the mark* |
// | B9 — `ordinal` is the site's order and nothing re-sorts it | *`copyWithOrdinal` moves the position, never the number* |
// | a log line has to identify its chapter | *`toString` carries the ordinal and the name* |
//
// ⚠️ **The `-1` row never hands `-1` to the type.** `chapter_entry.dart` says the sentinel
// "never reaches the screen", and that holds by construction rather than by a branch: the
// mapper in `data/library/drift_chapter_list_repository.dart` turns `-1` into `null` — that
// conversion is asserted there — so `null` is the only form of *the site published nothing
// readable* a tile can ever be handed. This file therefore pins the **end** of that contract
// (for every state a site can produce, no label spells the sentinel) and never constructs the
// case the upstream rows already own. The sentinel's spelling is built from
// `ChapterRecognition.unparseable` rather than typed, so moving that constant moves this row
// with it.

import 'package:flutter_test/flutter_test.dart';
import 'package:lumen_tale/core/error/source_failure.dart';
import 'package:lumen_tale/domain/library/chapter_entry.dart';
import 'package:lumen_tale/domain/sources/models/chapter.dart';

/// The storage sentinel exactly as a tile would have to spell it if it ever leaked.
///
/// ⚠️ Built from the constant rather than written as `'-1'`. The literal lives in three layers
/// and this row is about *which of them may show it*, so a hand-typed copy would be the one
/// thing in the file free to disagree with the other two.
final String sentinelLabel = '${ChapterRecognition.unparseable.round()}';

/// One entry, with each field spellable at the call site that cares about it.
///
/// ⚠️ **The defaults are a plain unread, undownloaded chapter numbered `1`.** A default set of
/// `true`s would make the interesting case — the row that proves a copy left seven fields
/// alone — the one needing seven arguments, and the linter is right to say so at every call
/// site. The row that needs a *populated* entry names every field it populates; the row that
/// needs an empty one inherits it.
ChapterEntry entry({
  String id = 'c-1',
  String name = 'Chapter 1',
  double? number = 1,
  int ordinal = 0,
  bool isRead = false,
  bool isDownloaded = false,
  double? downloadProgress,
  SourceFailure? downloadFailure,
}) => ChapterEntry(
  id: id,
  name: name,
  number: number,
  ordinal: ordinal,
  isRead: isRead,
  isDownloaded: isDownloaded,
  downloadProgress: downloadProgress,
  downloadFailure: downloadFailure,
);

/// The `null` a caller passes to mean *nothing to say*.
///
/// ⚠️ **A function rather than a literal, and the linter is the reason.** `copyWith` takes a
/// `bool?` defaulting to `null`, so `avoid_redundant_argument_values` reads a literal `null` —
/// or a `const` local holding one — as *delete this argument*. That advice is true of the call
/// and wrong about the row: what this suite pins is what a null does to the field, and a call
/// with the argument removed would pin nothing at all. A call is not a constant expression, so
/// the value is still a null and the argument is still visibly there.
bool? noChange() => null;

void main() {
  group('B10 — the number as the tile shows it', () {
    test('an unreadable number is an EM DASH', () {
      // ⚠️ `null` is *unreadable*, not *zero*. The em dash is what says so on a tile, and the
      // site's own wording stays whole inside `name` beside it.
      expect(
        entry(number: null).numberLabel,
        '—',
        reason:
            'the site published nothing readable, and a dash says exactly that',
      );
      expect(
        entry(number: null).numberLabel,
        isNot(sentinelLabel),
        reason: 'a tile reading -1 shows an integer the site never published',
      );
      expect(
        entry(number: null).numberLabel,
        isNot('0'),
        reason:
            '⚠️ 0 is a real chapter, and conflating the two is the B10 violation',
      );
    });

    test('⚠️ 0 is a real chapter, and the em dash is not 0', () {
      // ⚠️ **The row a falsy check destroys.** `number == null` is the only unreadable state;
      // writing `number == 0 || number == null` hides an extra, an omake and an author's note
      // behind a dash that claims the site said nothing.
      expect(
        entry(number: 0).numberLabel,
        '0',
        reason: 'the site numbered it 0, and that number is shown as it is',
      );
      expect(
        entry(number: 0).numberLabel,
        isNot('—'),
        reason: 'the null branch must not be reachable through a falsy 0',
      );
      expect(
        entry(number: 0).number,
        0,
        reason:
            'the stored value stays 0 too, so the tile and the row cannot disagree',
      );
    });

    test('a whole number drops the decimal point it was stored with', () {
      expect(
        entry(number: 12).numberLabel,
        '12',
        reason: "'12.0' would tell the reader the site published a float",
      );
    });

    test('⚠️ a fraction is shown as the site published it, never rounded', () {
      expect(
        entry(number: 12.5).numberLabel,
        '12.5',
        reason:
            'rounding to 12 or 13 is renumbering, which B10 forbids by name',
      );
    });

    test('⚠️ no state a site can produce renders the storage sentinel', () {
      for (final double? number in <double?>[null, 0, 1, 12, 12.5, 480]) {
        expect(
          entry(number: number).numberLabel,
          isNot(sentinelLabel),
          reason:
              'number=$number is a state the tile can reach, and a column default is not '
              'a chapter number',
        );
      }
    });
  });

  group('E3 — the count is CHAPTERS, never the site pages', () {
    test('three chapters count as three', () {
      final ChapterListFetchResult three = ChapterListFetchResult(
        entries: <ChapterEntry>[
          entry(),
          entry(id: 'c-2', ordinal: 1),
          entry(id: 'c-3', ordinal: 2),
        ],
      );

      expect(
        three.chapterCount,
        3,
        reason: 'the badge above the list says how many chapters there are',
      );
      expect(
        three.chapterCount,
        three.entries.length,
        reason:
            '⚠️ entries are the only thing it can count, so it cannot reach a page count',
      );
    });

    test('⚠️ a chapter spread over three site pages is counted ONCE', () {
      // ⚠️ **The page-joining already happened, in `2-2`.** `ChapterEntry` carries no page at
      // all, so the count cannot see those three pages even in principle — and that is the
      // whole of E3. Counting pages here would report a 480-chapter novel as 1 100.
      final ChapterListFetchResult joined = ChapterListFetchResult(
        entries: <ChapterEntry>[
          entry(id: 'c-12', name: 'Chapter 12', number: 12),
        ],
      );

      expect(
        joined.chapterCount,
        1,
        reason:
            'a chapter is one row, whatever the site needed three pages for',
      );
      expect(
        joined.entries,
        hasLength(1),
        reason: 'the same fact, read from the list the tile actually renders',
      );
    });

    test('an empty list counts ZERO', () {
      // ⚠️ **Zero and one are different novels to a reader**, and a hardcoded count would make
      // them the same novel. `B22`: a site that was never read never reaches this type at all.
      final ChapterListFetchResult none = ChapterListFetchResult(
        entries: const <ChapterEntry>[],
      );

      expect(
        none.chapterCount,
        0,
        reason: 'no entries is no chapters, and it must never read as one',
      );
      expect(
        none.entries,
        isEmpty,
        reason: 'and nothing was invented to reach that 0',
      );
    });
  });

  group('the list the tile renders is a value', () {
    test('⚠️ adding an entry throws, and leaves the list as it was', () {
      final ChapterListFetchResult result = ChapterListFetchResult(
        entries: <ChapterEntry>[
          entry(),
          entry(id: 'c-2', ordinal: 1),
        ],
      );

      // ⚠️ **A read that can be edited is a read the list no longer describes.** Whoever
      // holds the result holds a chapter list, and a chapter list is not theirs to change.
      expect(
        () => result.entries.add(entry(id: 'c-3')),
        throwsUnsupportedError,
        reason:
            'the entries are a value, not a buffer the caller may write into',
      );
      expect(
        result.entries.clear,
        throwsUnsupportedError,
        reason:
            '⚠️ clear() is the quiet one: it would empty every tile in place',
      );
      expect(
        result.entries,
        hasLength(2),
        reason:
            'both operations threw, so nothing was added and nothing was removed',
      );
    });
  });

  group('equality — a value is compared, never identified', () {
    test(
      'two separately built entries with the same fields are equal and hash alike',
      () {
        // ⚠️ **One from a helper, one from the constructor.** Equality has to survive the way
        // the rows are actually built: `==` on identity would pass a suite that only ever
        // compared one object with itself, and a value that cannot be compared cannot go in a
        // `Set`, cannot key a `Map`, and cannot be asserted on.
        final ChapterEntry fromStorage = entry(
          id: 'c-7',
          name: 'Chapter 7',
          number: 7,
          ordinal: 3,
          isRead: true,
          isDownloaded: true,
          downloadProgress: 0.5,
          downloadFailure: const NoConnection(host: 'www.example.test'),
        );
        const ChapterEntry fromSource = ChapterEntry(
          id: 'c-7',
          name: 'Chapter 7',
          number: 7,
          ordinal: 3,
          isRead: true,
          isDownloaded: true,
          downloadProgress: 0.5,
          downloadFailure: NoConnection(host: 'www.example.test'),
        );

        expect(
          fromStorage,
          equals(fromSource),
          reason:
              'a re-read of the same novel must not look like a different chapter',
        );
        expect(
          fromStorage.hashCode,
          equals(fromSource.hashCode),
          reason:
              'an equal value used as a Set member or a Map key depends on this agreeing',
        );
      },
    );

    test('⚠️ every field is part of the identity', () {
      // ⚠️ **One field moved at a time, and the base is `entry()` with no arguments at all.**
      // The first version of this row spelled the base out (`c-7`, `Chapter 7`, number `7`,
      // ordinal `3`) and then built the variants through the same helper, whose defaults were
      // something else entirely — so `entry(number: 8)` differed from the base in the number
      // *and* the id *and* the name *and* the ordinal. It passed while `number` was deleted
      // from `operator ==`: a variant that differs in four places cannot tell which field the
      // identity dropped. Building the base from the same no-argument call makes the one-field
      // claim true by construction rather than by reading eight lines carefully.
      final ChapterEntry base = entry();
      final Map<String, ChapterEntry> oneFieldMoved = <String, ChapterEntry>{
        'id': entry(id: 'c-2'),
        'name': entry(name: 'Chapter 2'),
        'number': entry(number: 2),
        'ordinal': entry(ordinal: 1),
        'isRead': entry(isRead: true),
        'isDownloaded': entry(isDownloaded: true),
        'downloadProgress': entry(downloadProgress: 0.5),
        'downloadFailure': entry(downloadFailure: const CauseUnknown()),
      };

      for (final MapEntry<String, ChapterEntry> moved
          in oneFieldMoved.entries) {
        expect(
          moved.value,
          isNot(base),
          reason:
              '${moved.key} is part of the identity, so an entry that differs in it alone '
              'must not compare equal',
        );
      }
    });
  });

  group('copyWith — a partial change, and only a partial one', () {
    test('⚠️ copyWith(isRead: true) moves the mark and NOTHING else', () {
      // ⚠️ **Started unread**, which is the default, so the row reads as the reader's
      // situation: a chapter marked while downloading, with a progress bar on it.
      final ChapterEntry before = entry(
        id: 'c-5',
        name: 'Chapter 5',
        number: 5,
        ordinal: 2,
        isDownloaded: true,
        downloadProgress: 0.75,
        downloadFailure: const CauseUnknown(),
      );
      final ChapterEntry after = before.copyWith(isRead: true);

      expect(
        after.isRead,
        isTrue,
        reason: 'the one field the caller was given',
      );
      expect(
        after.id,
        before.id,
        reason:
            'B3 — the id is derived from the novel and the url, and is never rewritten',
      );
      expect(
        after.name,
        before.name,
        reason:
            'B10 — the site own title is verbatim, and a mark does not reword it',
      );
      expect(
        after.number,
        before.number,
        reason: 'B9 — a copy cannot re-derive what the site published',
      );
      expect(
        after.ordinal,
        before.ordinal,
        reason:
            '⚠️ B9 — a mark is not a re-sort, and moving the tile is not its business',
      );
      expect(
        after.isDownloaded,
        before.isDownloaded,
        reason:
            'B6 — the mark and the download state are two facts that change separately',
      );
      expect(
        after.downloadProgress,
        before.downloadProgress,
        reason:
            'progress is live, and a copy that zeroed it would blink the bar off',
      );
      expect(
        after.downloadFailure,
        before.downloadFailure,
        reason:
            'a failure that vanishes with an unrelated edit is one nobody can report',
      );
    });

    test('several fields at once change exactly those, and only those', () {
      final ChapterEntry before = entry(
        id: 'c-9',
        name: 'Chapter 9',
        number: 9,
        ordinal: 4,
      );
      final ChapterEntry after = before.copyWith(
        isRead: true,
        isDownloaded: true,
        downloadProgress: 0.25,
      );

      expect(after.isRead, isTrue, reason: 'it was given a mark');
      expect(
        after.isDownloaded,
        isTrue,
        reason: 'it was given the download mark',
      );
      expect(after.downloadProgress, 0.25, reason: 'it was given a progress');
      expect(
        after.downloadFailure,
        isNull,
        reason:
            '⚠️ null means unchanged, and this one was never set to begin with',
      );
      expect(
        after.id,
        before.id,
        reason: 'B3 — not a parameter, so not changeable',
      );
      expect(after.name, before.name, reason: 'B10 — not a parameter either');
      expect(
        after.number,
        before.number,
        reason: 'B9 — not a parameter either',
      );
      expect(
        after.ordinal,
        before.ordinal,
        reason: 'B9 — the site order, once more',
      );
    });

    test('⚠️ null means UNCHANGED, so copyWith(isRead: null) keeps the mark', () {
      // ⚠️ **This is the contract that decides the API.** There is no way to say *mark this
      // unread* through `copyWith`, and that is deliberate: `null` is "the caller had nothing
      // to say", and reading it as *false* would let any unrelated edit wipe a reader's marks.
      expect(
        entry(isRead: true).copyWith(isRead: noChange()).isRead,
        isTrue,
        reason:
            'a null argument is not a false, and it must not clear a real mark',
      );
      expect(
        entry().copyWith(isRead: noChange()).isRead,
        isFalse,
        reason: 'the same contract where the mark was already false',
      );
    });

    test('a copyWith given nothing at all is the same value', () {
      final ChapterEntry before = entry(id: 'c-4', number: 4, ordinal: 1);
      expect(
        before.copyWith(),
        equals(before),
        reason:
            'four null arguments mean four unchanged fields, which is the same value',
      );
    });
  });

  group('B9 — copyWithOrdinal moves the position, never the number', () {
    test('the ordinal moves and every other field survives', () {
      final ChapterEntry before = entry(
        id: 'c-3',
        name: 'Chapter 3',
        number: 3,
        ordinal: 1,
        isRead: true,
        isDownloaded: true,
        downloadProgress: 0.5,
        downloadFailure: const NoConnection(host: 'www.example.test'),
      );
      final ChapterEntry moved = before.copyWithOrdinal(8);

      expect(
        moved.ordinal,
        8,
        reason: 'the position is the only thing the caller asked to change',
      );
      expect(
        moved.id,
        before.id,
        reason: 'a moved chapter is the same chapter',
      );
      expect(
        moved.name,
        before.name,
        reason: 'B10 — the title moves with it, unchanged',
      );
      expect(
        moved.number,
        before.number,
        reason: 'B9 — re-ordering never renumbers',
      );
      expect(
        moved.isRead,
        before.isRead,
        reason: 'the mark travels with the chapter',
      );
      expect(
        moved.isDownloaded,
        before.isDownloaded,
        reason: 'B6 — the download mark travels with it too',
      );
      expect(
        moved.downloadProgress,
        before.downloadProgress,
        reason: 'a live progress belongs to the chapter, not to the position',
      );
      expect(
        moved.downloadFailure,
        before.downloadFailure,
        reason: 'and so does the failure it would show',
      );
    });

    test('⚠️ re-ordering a chapter does not renumber it', () {
      // ⚠️ **The mistake this method exists next to.** A chapter that jumps to position 7 is
      // still the chapter the site published as 12, and a tile reading 7 there is a chapter
      // number the site never wrote.
      final ChapterEntry moved = entry(
        id: 'c-12',
        name: 'Chapter 12',
        number: 12,
      ).copyWithOrdinal(7);

      expect(moved.ordinal, 7, reason: 'the seventh position in the site list');
      expect(
        moved.number,
        12,
        reason: 'B9: the site published 12, and a position cannot change that',
      );
      expect(
        moved.numberLabel,
        '12',
        reason:
            '⚠️ so the tile keeps showing 12 rather than the ordinal it was given',
      );
    });
  });

  group('a log line has to identify its chapter', () {
    test('toString carries the ordinal and the name', () {
      // ⚠️ **No other digits appear in this `toString`** — the two flags print as words — so
      // the '42' below can only have come from the ordinal. That is what makes the assertion
      // about the ordinal rather than about the substring.
      final String line = entry(
        id: 'c-42',
        name: 'The Long Road',
        ordinal: 42,
      ).toString();

      expect(
        line,
        contains('42'),
        reason:
            'the ordinal is the position, and without it a log line names no position',
      );
      expect(
        line,
        contains('The Long Road'),
        reason:
            'the site own title is what makes the line searchable after the fact',
      );
    });
  });
}
