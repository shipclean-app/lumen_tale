// forge:slice 5-3
// Lumen Tale — `hasRealText`: E18's threshold, and E22's bargain on the other side of it.
//
// `5-3` § 11.1. Pure Dart.
//
// | rule | the row |
// |---|---|
// | E18 | 2 000 characters over several paragraphs → **true** |
// | E22 | a legitimate 480-character *Extra* → **true** |
// | E22, E18 | a one-line 140-character author's note → **true** |
// | E18 | 99 characters → **false** |
// | E18 | `''` → **false** |
// | E18 | 60 characters of "Sponsored" with no line break → **false** |

import 'package:flutter_test/flutter_test.dart';
import 'package:lumen_tale/core/utils/reader_cleanliness.dart';

/// A paragraph of [n] visible characters, which is what a real chapter is made of.
String prose(int n) => 'x' * n;

void main() {
  group('E18 — real chapters pass', () {
    test('⚠️ a 2 000-character chapter in several paragraphs → true', () {
      final String markdown = '${prose(900)}\n\n${prose(900)}\n\n${prose(200)}';

      expect(
        hasRealText(markdown),
        isTrue,
        reason:
            'E18: the ordinary case, and the reason the threshold exists at all — a threshold '
            'that rejected normal chapters would empty every novel on the phone',
      );
    });
  });

  group('E22 — a SHORT chapter is still a chapter', () {
    test('⚠️ a legitimate 480-character Extra → true', () {
      expect(
        hasRealText('## Extra\n\n${prose(460)}'),
        isTrue,
        reason:
            'E22, verbatim in substance: *"a legitimately short chapter is common on these '
            'sites — end notes, an Extra, an author’s afterword — and must never be mistaken '
            'for a broken one."* 480 ≥ 100 and there is a line break, so both conditions hold',
      );
    });

    // ⚠️ **THE ROW THAT KILLS THE `&&` MISREADING.** § 3.7 spells the defect out: a predicate
    // demanding a paragraph **and** 100 characters would reject this chapter.
    test('⚠️ a ONE-LINE 140-character author note → true', () {
      expect(
        hasRealText('${prose(140)}\n'),
        isTrue,
        reason:
            'E22 + `5-3` § 3.3: the threshold is on the **total**, not on the number of '
            'paragraphs. A translator note published as a single line of 140 characters is '
            'legitimate content, and an `&&` reading of the rule would turn it into a failure',
      );
    });
  });

  group('E18 — nothing readable survives', () {
    test('⚠️ 99 visible characters → false', () {
      expect(
        hasRealText('${prose(99)}\n'),
        isFalse,
        reason:
            'E18: "fewer than 100 characters of text in total … below that threshold the '
            'chapter is not stored as complete." 99 is under, and the function must not round '
            'it up',
      );
    });

    test('⚠️ the empty string → false', () {
      expect(
        hasRealText(''),
        isFalse,
        reason:
            'E18: a page whose article element is absent converts to an empty string. '
            'Storing it would produce a `.md` marked downloaded that opens empty, which is the '
            'exact state B6 exists to make unreachable',
      );
    });

    test('⚠️ whitespace only → false', () {
      expect(
        hasRealText('   \n\n \t \n'),
        isFalse,
        reason:
            'a page of placeholders and no text has a length and no **visible** characters; '
            'counting whitespace is how a broken page passes a threshold',
      );
    });

    test('⚠️ 60 characters of "Sponsored" with NO line break → false', () {
      expect(
        hasRealText('Sponsored ${'x' * 49}'),
        isFalse,
        reason:
            'E18: a page holding only placeholders. The paragraph-or-linebreak condition is '
            'what refuses it — 60 < 100 alone would also refuse it, and § 3.3 says the count '
            'is not the only guard precisely because the other cases need the second one',
      );
    });

    test('⚠️ 140 characters of Markdown SYNTAX and no prose → false', () {
      // ⚠️ **THE ROW THE SYNTAX STRIPPING EXISTS FOR.** A page full of `*` and `#` is 140
      // characters long and has nothing a reader could read; counting raw length would pass it
      // and store a chapter that opens as a column of punctuation.
      final String punctuationOnly = '${'*' * 140}\n';

      expect(
        punctuationOnly.length,
        greaterThanOrEqualTo(minimumReadableCharacters),
        reason:
            'witness — the raw length IS over the threshold, so this case is decided by the '
            '**visible** count and by nothing else',
      );
      expect(
        hasRealText(punctuationOnly),
        isFalse,
        reason:
            'C8: a `.md` marked downloaded that opens as punctuation is a chapter the app '
            'presents as complete and is not. `visibleCharacterCount` strips Markdown syntax '
            'for exactly this page',
      );
    });
  });

  group('§ 3.3 — the threshold is a NAMED CONSTANT, and the boundary is 100', () {
    test('⚠️ exactly `minimumReadableCharacters` visible characters → true', () {
      final String markdown = '${'y' * minimumReadableCharacters}\n';

      expect(
        visibleCharacterCount(markdown),
        minimumReadableCharacters,
        reason:
            'witness — the fixture really is exactly at the threshold, so the row below is '
            'decided by the comparison and not by an off-by-one in the fixture',
      );
      expect(
        hasRealText(markdown),
        isTrue,
        reason:
            'E18: "fewer than 100 characters" is refused, so **100 itself is kept**. An '
            'off-by-one that dropped 100 would reject the shortest legitimate chapter',
      );
    });
  });
}
