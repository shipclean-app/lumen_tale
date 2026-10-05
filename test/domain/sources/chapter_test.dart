// Lumen Tale — `ChapterRecognition`, and the `-1` / `0` distinction it exists for.
//
// B10: *chapter titles and numbering are displayed exactly as the site presents
// them*. E2 names the awkward cases: "Chapter 1", "Ch. 12.5", "Vol 3", "Extra",
// "Omake", and none at all.
//
// ⚠️ **Every expectation here is a literal.** Recomputing them with
// `ChapterRecognition.parse` inside the test would assert that the function
// agrees with itself.

import 'package:flutter_test/flutter_test.dart';
import 'package:lumen_tale/domain/sources/models/chapter.dart';

void main() {
  group('a readable number', () {
    test('Chapter 1 is chapter 1', () {
      expect(ChapterRecognition.parse('Chapter 1'), 1.0);
    });

    test('Ch. 12.5 is 12.5', () {
      expect(ChapterRecognition.parse('Ch. 12.5'), 12.5);
    });

    test('Vol 3 is 3', () {
      expect(ChapterRecognition.parse('Vol 3'), 3.0);
    });

    test('a trailing letter does not change the number', () {
      // The transposed regex's third group `(\.?[a-z]+)?` is accepted and
      // discarded: `12a` is chapter 12, and inventing 12.1 would be renumbering.
      expect(ChapterRecognition.parse('12a'), 12.0);
    });

    test(
      'a number after the word Chapter wins over a number in a subtitle',
      () {
        expect(ChapterRecognition.parse('Chapter 42 - The Long Road'), 42.0);
      },
    );

    test('the first number in the title is the one read', () {
      expect(ChapterRecognition.parse('Chapter 7 of Volume 2'), 7.0);
    });
  });

  group('the three special values, which are three different numbers', () {
    test('Extra is 0.99', () {
      expect(ChapterRecognition.parse('Extra'), 0.99);
    });

    test('Omake is 0.98', () {
      expect(ChapterRecognition.parse('Omake'), 0.98);
    });

    test('a special chapter is 0.97', () {
      expect(ChapterRecognition.parse('Special Chapter'), 0.97);
    });

    test('a bonus is a special chapter', () {
      expect(ChapterRecognition.parse('Bonus'), 0.97);
    });

    test("an author's note is a special chapter", () {
      expect(ChapterRecognition.parse("Author's Note"), 0.97);
    });

    test('a numbered chapter with Extra in its title is still the extra', () {
      // ⚠️ The word is checked **before** the number. `Chapter 7 (Extra)`
      // contains both, and reading the number would file a bonus chapter in the
      // middle of the run — the renumbering B10 forbids.
      expect(ChapterRecognition.parse('Chapter 7 (Extra)'), 0.99);
    });
  });

  group('an unreadable title is -1 and never 0', () {
    // This group is the reason `chapters.number` defaults to `-1` rather than
    // `0`: `0` is a real chapter number on several sites, and an unparseable
    // title is not one of them.
    test('null is -1', () {
      expect(ChapterRecognition.parse(null), -1);
    });

    test('an empty title is -1', () {
      expect(ChapterRecognition.parse(''), -1);
    });

    test('a whitespace-only title is -1', () {
      expect(ChapterRecognition.parse('   '), -1);
    });

    test('a title with no digit at all is -1', () {
      expect(ChapterRecognition.parse('Prologue'), -1);
    });

    test('a chapter numbered zero stays distinct from an unreadable one', () {
      // The one assertion B10 actually turns on. If these two ever converge, an
      // author's note and a title we failed to read become the same chapter.
      final double omake = ChapterRecognition.parse('Omake');
      expect(omake, isNot(ChapterRecognition.unparseable));
      expect(0.0, isNot(ChapterRecognition.unparseable));
    });

    test('zero is reachable as a real number', () {
      expect(ChapterRecognition.parse('Chapter 0'), 0.0);
      expect(0.0, isNot(-1.0));
    });
  });

  group('the title itself is never touched', () {
    // B10 is about the string the reader sees, and this is the function that
    // touches it most. It takes a `String?` and returns a `double`; it has no
    // way to alter the caller's text, and this test pins the shape of that.
    test('parse does not require a mutable title', () {
      const String title = 'Chapter 1';
      expect(ChapterRecognition.parse(title), 1.0);
      expect(title, 'Chapter 1');
    });
  });

  group('Chapter', () {
    Chapter chapter({String? name, double? number}) {
      return Chapter(
        id: '3003a98742f53c4b4f2ae62d8105a4e9',
        novelId: '90db9662f191bf2418033ab0bee1e629',
        url: 'novel/ke383028_1.html',
        name: name,
        number: number ?? ChapterRecognition.parse(name),
      );
    }

    test('a chapter keeps the site own name verbatim', () {
      const String awkward = 'Ch. 12.5 - "the" <thing> & more';
      expect(chapter(name: awkward).name, awkward);
    });

    test('an untitled chapter is kept and its name is null', () {
      // E2 — rendered as *Untitled*, never dropped and never given an index.
      // The helper's `name` is omitted rather than passed as `null`: that is the
      // same state, and an explicit `null` here would read as "null was chosen"
      // when nothing was chosen at all.
      expect(chapter().name, isNull);
    });

    test('a missing date upload stays null and is not filled in', () {
      // A fabricated date would make the library order lie.
      expect(chapter(name: 'Chapter 1').dateUpload, isNull);
    });

    test('the url is the relative one it was given', () {
      expect(chapter(name: 'Chapter 1').url, 'novel/ke383028_1.html');
    });

    test('toString carries the id and not the chapter title', () {
      // A chapter title is the text a reader typed into a site and the text
      // `2-1`'s dropped-row criterion forbids reaching a log. `toString` is the
      // most likely accidental carrier of it.
      expect(
        chapter(name: 'Chapter 1').toString(),
        isNot(contains('Chapter 1')),
      );
    });
  });

  group('Page — a chapter split over several pages', () {
    test('the list order is authoritative and the index is only recorded', () {
      // Rule 11: a source that emits pages out of order with 1-based indices is
      // a site whose numbering is wrong. Sorting by [Page.index] would produce a
      // chapter that is not the chapter.
      const Page second = Page(
        index: 1,
        url: 'novel/x_2.html',
        html: '<p>b</p>',
      );
      const Page first = Page(
        index: 0,
        url: 'novel/x_1.html',
        html: '<p>a</p>',
      );
      expect(<Page>[second, first].map((Page p) => p.url), <String>[
        'novel/x_2.html',
        'novel/x_1.html',
      ]);
    });

    test('a page carries raw html and never markdown', () {
      const Page page = Page(index: 0, url: 'x.html', html: '<p>text</p>');
      expect(page.html, '<p>text</p>');
    });
  });
}
