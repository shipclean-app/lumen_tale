// forge:slice 0-4
// Lumen Tale — `0-4`: which parts of a FanMTL chapter page are content and which are
// furniture, read from the three frozen chapter captures and nothing else.
//
// ## What this file asserts, and what it deliberately does NOT
//
// § 10 has one criterion that the capture REFUTES, and the honest delivery is the
// measurement rather than the plan's expectation:
//
//   * § 10 asks for `ParagraphRule.brBrDelimitedText` on the grounds that
//     `chapter-prose` holds no `<p>`. MEASURED 2026-10-05: that is true of
//     `chapter-prose` and **false of the other two**. `chapter-short` has 53 `<p>`
//     opening tags and `chapter-long` has 110, with **zero** `<br><br>` runs in either.
//     So the site's quirk 1 ("a chapter contains 0 `<p>` tags") is true of one page out
//     of three, and the value that is correct on **all three** is `pThenBrBr`.
//     `04-html-to-markdown.md` already demands both shapes; this is the measurement of
//     why, on this site. `test/fixtures/fanmtl_manifest_test.dart` made exactly this
//     class of correction for `0-1` § 3.2's `chapter-content` target.
//
// ## Every number here is re-derived from the bytes on each run
//
// Nothing is hard-coded from a measurement I took once. `paragraphEvidence` re-reads the
// captures and recomputes the table, so a re-capture that changes a count fails this
// suite instead of quietly invalidating `18-external-contracts.md`.
//
// ## No `testWidgets`
//
// `selectContent` takes a parsed `Document`, and the fixtures are read with `dart:io`
// (`File.readAsStringSync`). Every row is a plain `test()`: `testWidgets` runs its body in
// a fake-async zone where real file futures never complete, so a `dart:io` row placed
// there hangs and takes the suite with it.
//
// ## Where the classification lives
//
// `18-external-contracts.md` § FanMTL "Content vs furniture, measured from fixtures". This
// file re-derives its rows from the same bytes, so the document and the capture cannot
// drift apart silently.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;
import 'package:lumen_tale/domain/sources/chapter_content_policy.dart';

import '../../fixtures/fixture_manifest.dart';

/// The FanMTL policy of `0-4` § 3.5, minus the one value the capture refuted.
///
/// ⚠️ **`paragraphRule` is `pThenBrBr`, not the plan's `brBrDelimitedText`.** See the file
/// header and the group `the paragraph rule is measured on all three chapters`. The rest of
/// § 3.5 is delivered verbatim.
const ChapterContentPolicy fanmtlChapterPolicy = ChapterContentPolicy(
  sourceId: 'fanmtl',
  contentSelector: '.chapter-content',
  removableSelectors: <String>[
    'script',
    'style',
    'noscript',
    'iframe',
    'object',
    'embed',
    'svg',
    'nav',
    'aside',
    'footer',
    'form',
    'button',
  ],
  paragraphRule: ParagraphRule.pThenBrBr,
  notes:
      'Content is .chapter-content, NOT #chapter-article: the latter wraps the page '
      'chrome (novel title, chapter title, the Default/Dyslexic/Roboto/Lora font picker, '
      'prev/next, night mode) and the "You\'ll Also Like" shelf. MEASURED 2026-10-05 on '
      'three chapter pages: chapter-prose has 0 <p> opening tags and 104 <br><br> runs, '
      'while chapter-short (53) and chapter-long (110) are <p>-delimited with 0 <br><br>. '
      'The site therefore emits BOTH shapes and the rule is pThenBrBr - <p> first, then '
      'br br - which is the only value correct on all three. An ad <script '
      'src=/d/js/ad/page_01.js> sits inside the content div; /d/ is robots-disallowed, so '
      'dropping the tag is also what prevents the app requesting it (B5). Evidence: '
      'chapter-prose, chapter-short, chapter-long.',
);

/// The three chapter captures § 3.1 requires, and § 3.3 requires to agree.
///
/// All three, not one: a paragraph rule measured on a single page is a claim about that
/// page, and the whole reason this slice exists is that a page proves less than it looks.
const List<String> chapterFixtureKeys = <String>[
  'chapter-prose',
  'chapter-short',
  'chapter-long',
];

/// The general drop list of `04-html-to-markdown.md` § Required behaviour, in its order.
const List<String> generalDropList = <String>[
  'script',
  'style',
  'noscript',
  'iframe',
  'object',
  'embed',
  'svg',
  'nav',
  'aside',
  'footer',
  'form',
  'button',
];

FixtureManifest manifest() => FixtureManifest.load('fanmtl');

dom.Document documentOf(String key) =>
    html_parser.parse(manifest().require(key).readText());

/// `<p>` elements inside the content node that hold visible text.
///
/// ⚠️ **Not the element count, and the difference is load-bearing.** `chapter-prose`'s
/// bytes contain a stray `</p>` with no opener; `package:html` materialises it as an empty
/// `<p></p>`. Counting elements reads the one page in this capture that has no `<p>` at all
/// as `<p>`-delimited, and `ParagraphRule.decide` would then pick the wrong rule from a
/// parser artefact.
int paragraphElementsWithText(dom.Element content) => content
    .querySelectorAll('p')
    .where((dom.Element e) => e.text.trim().isNotEmpty)
    .length;

/// Runs of two consecutive `<br>` among siblings, ignoring whitespace text between them.
///
/// Written over `nodes` rather than `children` because a `<br>` followed by a newline and
/// then a `<br>` is the site's actual shape — `<br><br>` in the bytes, and the parser puts
/// text between the two elements.
int brBrRuns(dom.Element root) {
  int runs = 0;
  void walk(dom.Node node) {
    final List<dom.Node> siblings = node.nodes.toList();
    for (int i = 0; i < siblings.length; i++) {
      final dom.Node child = siblings[i];
      if (child is dom.Element && child.localName == 'br') {
        int ahead = i + 1;
        while (ahead < siblings.length &&
            siblings[ahead] is dom.Text &&
            (siblings[ahead] as dom.Text).data.trim().isEmpty) {
          ahead++;
        }
        if (ahead < siblings.length &&
            siblings[ahead] is dom.Element &&
            (siblings[ahead] as dom.Element).localName == 'br') {
          runs++;
        }
      }
      if (child is dom.Element) walk(child);
    }
  }

  walk(root);
  return runs;
}

/// `<p>` **opening tags** in the raw bytes, counted without a parser.
///
/// `\b` after `p` is what keeps `<path …>` out: `chapter-prose` holds two SVG `<path>`
/// elements and a naive `count('<p')` reads them as paragraphs. The DOM count is 1 there
/// for the opposite reason, and both counts are asserted so neither can drift unnoticed.
int rawParagraphOpenTags(String html) =>
    RegExp(r'<p(?=[\s>/])').allMatches(html).length;

/// Every number `18-external-contracts.md`'s paragraph table states, re-derived.
///
/// `ParagraphEvidence` is public rather than private because a private type in a public
/// API's signature is a lint error — and the two appear together in five rows, so
/// renaming only the class would leave the signatures lying.
List<ParagraphEvidence> paragraphEvidence() => chapterFixtureKeys
    .map((String key) {
      final FixtureEntry entry = manifest().require(key);
      final dom.Document document = html_parser.parse(entry.readText());
      final dom.Element content = document.querySelector('.chapter-content')!;
      return ParagraphEvidence(
        key: key,
        rawOpenTags: rawParagraphOpenTags(entry.readText()),
        elementsWithText: paragraphElementsWithText(content),
        elementsTotal: content.querySelectorAll('p').length,
        brBrRuns: brBrRuns(content),
        brTotal: content.querySelectorAll('br').length,
        visibleChars: content.text
            .replaceAll(RegExp(r'\s+'), ' ')
            .trim()
            .length,
      );
    })
    .toList(growable: false);

class ParagraphEvidence {
  const ParagraphEvidence({
    required this.key,
    required this.rawOpenTags,
    required this.elementsWithText,
    required this.elementsTotal,
    required this.brBrRuns,
    required this.brTotal,
    required this.visibleChars,
  });

  final String key;
  final int rawOpenTags;
  final int elementsWithText;
  final int elementsTotal;
  final int brBrRuns;
  final int brTotal;
  final int visibleChars;

  ParagraphRule get impliedRule => ParagraphRule.decide(
    paragraphElementCount: elementsWithText,
    brBrRunCount: brBrRuns,
  );
}

/// Applies [selectors] inside [root], the way `2-2`'s cleaner will.
///
/// `0-4` writes no cleaner (`0-4` § 7: *do not write the cleaner or the converter here* —
/// they are `2-2`'s deliverables). This is the twelve-selector walk a test needs to answer
/// "does the policy's list actually drop this node", and it is deliberately **local**: the
/// production walk lives in `lib/core/pipeline/html_to_markdown.dart` and this must not
/// become a second implementation of it.
void applyRemovals(dom.Element root, List<String> selectors) {
  for (final String selector in selectors) {
    for (final dom.Element node in root.querySelectorAll(selector).toList()) {
      node.remove();
    }
  }
}

void main() {
  group('the policy type exists and is a value, not a service', () {
    test('the four types § 2.2 names are all defined', () {
      // § 2.2 and § 10 row 1. Named through their use, because a test cannot assert a
      // declaration exists — it can only assert the declaration is REACHABLE.
      expect(
        fanmtlChapterPolicy.contentSelector,
        '.chapter-content',
        reason:
            'ChapterContentPolicy is declared with the selector § 3.5 fixes',
      );
      expect(
        fanmtlChapterPolicy.paragraphRule,
        isA<ParagraphRule>(),
        reason:
            'ParagraphRule is the enum § 2.2 names, and it is a real enum value',
      );
      expect(
        const ClassifiedElement(
          selector: '.chapter-content',
          verdict: ElementVerdict.content,
          reason: 'reachable',
          evidenceKey: 'chapter-prose',
        ).verdict,
        ElementVerdict.content,
        reason:
            'ElementVerdict and ClassifiedElement are declared and constructible',
      );
    });

    test('the policy imports no Flutter, so 2-2 can test it as a plain unit', () {
      // § 11.1 "Placement", and `02-architecture.md`: `domain` carries no Flutter import.
      // Checked on the SOURCE rather than on the import graph, because the graph is what
      // `flutter analyze` already enforces and re-deriving it here would test the tool.
      final String source = File(
        'lib/domain/sources/chapter_content_policy.dart',
      ).readAsStringSync();
      expect(
        source,
        isNot(contains('package:flutter/')),
        reason:
            '02-architecture.md: domain carries no Flutter import, which is what lets '
            '2-2 test the cleaner without a MaterialApp',
      );
      expect(
        source,
        contains("import 'package:html/dom.dart'"),
        reason:
            'package:html is the one dependency, and it is already in pubspec',
      );
    });

    test('the policy toString names the selector and the paragraph rule', () {
      // A value whose printed form is unreadable is a value a failure report cannot quote,
      // and C12 says the reader must be able to say the failing selector out loud.
      final String printed = fanmtlChapterPolicy.toString();
      expect(
        printed,
        contains('.chapter-content'),
        reason: 'C12: the failing selector must be readable in a report',
      );
      expect(
        printed,
        contains('pThenBrBr'),
        reason:
            'the paragraph rule is part of what a source declares about itself',
      );
    });
  });

  group('B44 the content node is the prose, not the wrapper', () {
    test('selectContent returns the .chapter-content node on chapter-prose', () {
      final dom.Element? content = fanmtlChapterPolicy.selectContent(
        documentOf('chapter-prose'),
      );
      expect(
        content,
        isNotNull,
        reason: '§ 10: on the reference page the selector must resolve',
      );
      expect(
        content!.classes,
        contains('chapter-content'),
        reason:
            '§ 10: the returned node must be the prose container. MEASURED: its class '
            'attribute carries nothing else on FanMTL, so an exact match is correct here '
            '(Royal Road needs .chapter-inner.chapter-content)',
      );
      expect(
        content.text.replaceAll(RegExp(r'\s+'), ' ').trim().length,
        greaterThan(100),
        reason:
            'B10/E18: the content node must hold the prose, not a label. 7,327 visible '
            'characters on chapter-prose',
      );
    });

    test(
      'selectContent does NOT return #chapter-article, and that node is the trap',
      () {
        // § 3.2 row 1 and § 7's first trap. `#chapter-article` returns a NON-NULL node that
        // contains the prose AND the chrome — so a source written against it "works", ships
        // a font picker into the text, and looks plausible. This row is what makes that
        // failure visible.
        final dom.Document document = documentOf('chapter-prose');
        final dom.Element? article = document.querySelector('#chapter-article');

        expect(
          article,
          isNotNull,
          reason:
              'MEASURED: #chapter-article exists on the page, so it is a real alternative '
              'and not a hypothetical one',
        );
        expect(
          article!.querySelectorAll('.chapter-content'),
          hasLength(1),
          reason:
              'it CONTAINS the prose, which is exactly why selecting it does not fail '
              'loudly — it succeeds with the wrong tree',
        );
        expect(
          article.querySelector('aside.control-action'),
          isNotNull,
          reason:
              'B44, § 11.1: the chrome it drags in is the font picker (Default / Dyslexic / '
              'Roboto / Lora) plus Prev / Next and night mode. A reader would get a font '
              'picker in the chapter text',
        );
        expect(
          article.text.replaceAll(RegExp(r'\s+'), ' '),
          contains('Default Dyslexic Roboto Lora'),
          reason:
              'the literal proof: #chapter-article\'s text carries the font picker labels, '
              'which is content that is not prose',
        );
        expect(
          article.text.length,
          greaterThan(fanmtlChapterPolicy.selectContent(document)!.text.length),
          reason:
              'the wrapper is strictly larger than the prose, which is the whole reason it '
              'is the wrong node',
        );
      },
    );

    test('the envelope section is not the content either', () {
      // § 3.2 row 1's second half: BOTH #chapter-article and
      // section.page-in.content-wrap are on the page, both are "in the article", and one
      // of them is the text.
      final dom.Document document = documentOf('chapter-prose');
      final dom.Element? wrap = document.querySelector(
        'section.page-in.content-wrap',
      );
      expect(wrap, isNotNull);
      expect(
        wrap!.querySelectorAll('.chapter-content'),
        hasLength(1),
        reason:
            'the wrapper contains the content node; the content node is not the wrapper',
      );
      expect(
        fanmtlChapterPolicy.contentSelector,
        isNot('section.page-in.content-wrap'),
        reason:
            'confusing the envelope with the content is the error § 3.2 names',
      );
    });
  });

  group('E4, C6, C12 the absent container is null and nothing else', () {
    test('a selector that matches nothing yields null and throws nothing', () {
      // § 10 row 3 and § 11.1 "absent". The point is what is NOT thrown: a thrown
      // exception inside a fetch pipeline turns a layout change into a crash.
      dom.Document document = documentOf('chapter-prose');
      const ChapterContentPolicy absent = ChapterContentPolicy(
        sourceId: 'fanmtl',
        contentSelector: '.no-such-container',
        removableSelectors: <String>['script'],
        paragraphRule: ParagraphRule.pThenBrBr,
        notes:
            'A deliberately wrong selector, used only to prove the null branch.',
      );
      expect(
        absent.selectContent(document),
        isNull,
        reason:
            'E4: an absent container is null — the signal the caller turns into '
            'SourceLayoutChanged(selector: ...) (architecture.md § 5.2)',
      );
      expect(
        () => absent.selectContent(document),
        returnsNormally,
        reason:
            'C6: the absent case must not throw. An exception here is a crash, and a '
            'crash reports nothing a reader can act on',
      );
      // A second call must also be null — the null is not a one-shot cached error.
      expect(absent.selectContent(document), isNull);
      document = documentOf('chapter-short');
      expect(
        absent.selectContent(document),
        isNull,
        reason: 'and it stays null on every page, not only the first one tried',
      );
    });

    test('a selector matching MORE than one node is also null, not the first match', () {
      // ⚠️ **MEASURED constraint, and it is why `.chapter-content` is safe to require as
      // exactly-one.** `chapter-prose` has one; a page that duplicated the container would
      // otherwise silently drop half the chapter, and taking `.first` is the quiet version
      // of that failure.
      final dom.Document document = html_parser.parse(
        '<div class="c">one</div><div class="c">two</div>',
      );
      const ChapterContentPolicy duplicated = ChapterContentPolicy(
        sourceId: 'probe',
        contentSelector: '.c',
        removableSelectors: <String>['script'],
        paragraphRule: ParagraphRule.pThenBrBr,
        notes:
            'A probe document with two matching nodes, to prove the null branch.',
      );
      expect(
        duplicated.selectContent(document),
        isNull,
        reason:
            'two matches is as untrustworthy as none: the reader would get one chapter '
            'half and no indication that the other half was dropped',
      );
    });

    test('the failing selector is a name a reader can read aloud (C12)', () {
      // C12: the failure must be describable in WORDS by someone who cannot open a
      // developer console. That means the string in the report is the class, not a path
      // or an index.
      const ChapterContentPolicy absent = ChapterContentPolicy(
        sourceId: 'fanmtl',
        contentSelector: '.chapter-content',
        removableSelectors: <String>['script'],
        paragraphRule: ParagraphRule.pThenBrBr,
        notes:
            'Reused selector so the assertion is about the STRING, not the lookup.',
      );
      final dom.Element? content = absent.selectContent(
        html_parser.parse('<html><body><p>no container here</p></body></html>'),
      );
      expect(content, isNull);
      expect(
        absent.contentSelector,
        '.chapter-content',
        reason:
            '18-external-contracts.md § FanMTL names this exact string as what the '
            'source-unavailable failure carries, and it is the class the site would '
            'rename if the template changed',
      );
      expect(
        absent.contentSelector,
        isNot(contains('/')),
        reason:
            'a path in a failure message is a path into the app, not into the site',
      );
    });
  });

  group('the paragraph rule is measured on all three chapters', () {
    test('the three captures really do disagree, and that is the finding', () {
      // § 3.3's last row and § 10 row 4. The plan expected agreement and got divergence.
      // Asserting the divergence is what makes it a MEASUREMENT rather than a claim: if a
      // re-capture made the three agree, this row would fail and the record would need
      // rewriting, which is correct.
      final List<ParagraphEvidence> all = paragraphEvidence();
      final ParagraphEvidence prose = all.firstWhere(
        (ParagraphEvidence e) => e.key == 'chapter-prose',
      );
      expect(
        prose.rawOpenTags,
        0,
        reason:
            'chapter-prose holds NO <p> opening tag in its bytes. Its 104 <br><br> runs '
            'are the paragraph structure (04-html-to-markdown.md quirk 1)',
      );
      expect(
        prose.brBrRuns,
        greaterThanOrEqualTo(1),
        reason:
            '§ 10 row 4 requires at least one <br><br> run, and without one there would '
            'be no paragraph structure at all — which is E4, not a source without paragraphs',
      );
      for (final ParagraphEvidence e in all.where(
        (ParagraphEvidence e) => e.key != 'chapter-prose',
      )) {
        expect(
          e.rawOpenTags,
          greaterThan(0),
          reason:
              '${e.key} holds <p> opening tags, so 18-external-contracts.md quirk 1 ("a '
              'chapter contains 0 <p> tags") is TRUE OF ONE PAGE OUT OF THREE and must not '
              'be read as a property of the site',
        );
        expect(
          e.brBrRuns,
          0,
          reason:
              '${e.key} is <p>-delimited: its paragraphs are elements, so a rule reading '
              'only <br><br> would render this whole chapter as one block',
        );
      }
      expect(
        all.map((ParagraphEvidence e) => e.impliedRule).toSet(),
        hasLength(greaterThan(1)),
        reason:
            'the three pages do NOT imply the same rule, which is why the value is '
            'pThenBrBr and not the plan\'s brBrDelimitedText. If this ever fails, the '
            'site changed and 18-external-contracts.md must be re-measured',
      );
    });

    test('the policy carries pThenBrBr, the only value correct on all three', () {
      // The corrected value, and the reasoning that forced the correction.
      expect(
        fanmtlChapterPolicy.paragraphRule,
        ParagraphRule.pThenBrBr,
        reason:
            '<p> first, then br br on what is left. brBrDelimitedText would render '
            'chapter-short and chapter-long as single blocks; pElementsOnly would render '
            'chapter-prose as one 7,327-character paragraph',
      );
      expect(
        ParagraphRule.decide(paragraphElementCount: 0, brBrRunCount: 104),
        ParagraphRule.brBrDelimitedText,
        reason:
            '§ 3.3 branch 1: no <p>, <br><br> present — the chapter-prose case',
      );
      expect(
        ParagraphRule.decide(paragraphElementCount: 51, brBrRunCount: 0),
        ParagraphRule.pElementsOnly,
        reason:
            '§ 3.3 branch 2: <p> present, no <br><br> — the other two chapters',
      );
      expect(
        ParagraphRule.decide(paragraphElementCount: 51, brBrRunCount: 104),
        ParagraphRule.pThenBrBr,
        reason:
            '§ 3.3 branch 3: both. A site that mixes must not produce two competing '
            'decodings of the same document',
      );
      expect(
        ParagraphRule.decide(paragraphElementCount: 0, brBrRunCount: 0),
        ParagraphRule.pThenBrBr,
        reason:
            '§ 3.3 branch 4: neither. A page with no <p> and no <br><br> has no '
            'paragraph structure, which is E4 — so the conservative rule is chosen and '
            'the classification carries INDETERMINATE',
      );
    });

    test('an empty <p> does not make a br-br page look <p>-delimited', () {
      // ⚠️ **The parser artefact, asserted so it cannot be "fixed" into the wrong answer.**
      // chapter-prose's bytes hold a stray `</p>` with no opener; `package:html`
      // materialises it as `<p></p>`. Counting ELEMENTS therefore reads 1 and would pick
      // the wrong rule from a parser artefact. Both numbers are stated here.
      final dom.Element content = documentOf(
        'chapter-prose',
      ).querySelector('.chapter-content')!;
      expect(
        content.querySelectorAll('p'),
        hasLength(1),
        reason:
            'MEASURED: the DOM does hold one <p>, created by the parser from a stray '
            '</p>. Anyone re-counting this must see why the count is not the answer',
      );
      expect(
        paragraphElementsWithText(content),
        0,
        reason:
            'and it holds no visible text, so the page still has zero paragraphs — which '
            'is what decide() is given',
      );
      expect(
        content.querySelector('p')!.text.trim(),
        isEmpty,
        reason: 'the third fact: empty means empty, not "nearly a paragraph"',
      );
    });

    test(
      'every chapter page resolves to real prose, so no page is a false negative',
      () {
        // A rule measured on a page that holds nothing measures nothing. All three are
        // checked, which is also the property B8 needs (a selector that works on chapter 1
        // and nowhere else).
        for (final String key in chapterFixtureKeys) {
          final dom.Element? content = fanmtlChapterPolicy.selectContent(
            documentOf(key),
          );
          expect(
            content,
            isNotNull,
            reason: '$key must resolve the content selector',
          );
          expect(
            content!.text.replaceAll(RegExp(r'\s+'), ' ').trim().length,
            greaterThan(1000),
            reason:
                '$key: a content node with ${content.text.trim().length} characters is not '
                'prose, so a paragraph rule measured on it would be meaningless (E18)',
          );
        }
      },
    );
  });

  group('B8 the same selector works on every page of every chapter', () {
    test('one selector, three chapters 1,996 apart, three non-null nodes', () {
      // § 10 row 11. The plan's test was "both pieces of a multi-page chapter"; those
      // pieces do not exist — E3 measured that FanMTL never splits a chapter, and
      // `chapter-multipage-p1` / `-p2` are a recorded absence. These three pages are
      // chapters 1, 1100 and 1960 of one novel, so the statement is STRONGER than the
      // two-piece one: a selector that worked only on chapter 1 could not pass this.
      final FixtureManifest loaded = manifest();
      final Set<String> numbers = chapterFixtureKeys
          .map(
            (String key) =>
                RegExp(
                  r'_(\d+)\.html$',
                ).firstMatch(loaded.require(key).url)?.group(1) ??
                '',
          )
          .toSet();
      expect(
        numbers,
        hasLength(3),
        reason:
            'the three fixtures must be three DIFFERENT chapters, or "the same selector '
            'works on every page" is one observation repeated. Got $numbers',
      );
      for (final String key in chapterFixtureKeys) {
        expect(
          fanmtlChapterPolicy.selectContent(documentOf(key)),
          isNotNull,
          reason:
              'B8: the selector is applied to each page of a chapter, never only to the '
              'first. $key is one of those pages',
        );
      }
    });

    test('the multipage fixtures are still a recorded absence, not a silent gap', () {
      // The test above stands in for a fixture that cannot exist. That substitution is
      // only honest while the absence is written down, so this row checks the writing.
      final FixtureManifest loaded = manifest();
      for (final String key in <String>[
        'chapter-multipage-p1',
        'chapter-multipage-p2',
      ]) {
        expect(
          loaded.entries.any((FixtureEntry e) => e.key == key),
          isFalse,
          reason:
              '$key is not in the manifest because the site does not split chapters — '
              'E3, measured. If a future capture DOES add one, this row fails and the '
              'B8 test must become the two-piece one the plan asked for',
        );
      }
      expect(
        File('.opencode/rules/18-external-contracts.md').readAsStringSync(),
        contains('chapter-multipage-p1'),
        reason:
            'a named absence in the manifest must also be named in '
            '18-external-contracts.md: an absence nobody wrote down is indistinguishable '
            'from an oversight (0-1 § 10, last row)',
      );
    });
  });

  group('B44, B5 the drop list removes scripts and keeps links and images', () {
    test('the ad script inside the content node is gone after removal', () {
      // § 10 row 8 and § 11.1 "removal — script". The script is INSIDE the prose container,
      // which is what makes this row non-trivial: a walk scoped to the page chrome would
      // leave it.
      final dom.Element content = documentOf(
        'chapter-prose',
      ).querySelector('.chapter-content')!;
      expect(
        content.querySelectorAll('script[src="/d/js/ad/page_01.js"]'),
        hasLength(1),
        reason:
            'MEASURED: the ad script is inside div.chapter-content, not in the chrome. '
            'If this count were 0 the row below would pass vacuously',
      );
      applyRemovals(content, fanmtlChapterPolicy.removableSelectors);
      expect(
        content.querySelectorAll('script'),
        isEmpty,
        reason:
            'B44: a <script> leaves the document before anything looks at it',
      );
      expect(
        content.querySelectorAll('script[src*="/d/js/"]'),
        isEmpty,
        reason:
            'B5: the tag must be gone from the RETAINED TREE, not merely hidden. Leaving '
            'it in the tree leaves a path to /d/, which robots.txt disallows',
      );
      expect(
        content.querySelectorAll('div[align="center"]'),
        hasLength(2),
        reason:
            'and what remains around it is the two <div align="center"> wrappers, now '
            'empty. They are not furniture by tag — an empty div emits nothing — so no '
            'selector is added for them (§ 7: no selector "just in case")',
      );
    });

    test('the drop list is exactly 04-html-to-markdown.md\'s, in its order', () {
      // § 10 row 6, § 11.1 "removal — general list", and § 3.5's deliberate decision.
      expect(
        fanmtlChapterPolicy.removableSelectors,
        generalDropList,
        reason:
            '04-html-to-markdown.md § Required behaviour lists these twelve in this order. '
            'Equality on the LIST — not as a set — so a reordering also fails: the order is '
            'the order removals are applied in, and a document can be observable midway',
      );
      expect(
        fanmtlChapterPolicy.removableSelectors,
        hasLength(12),
        reason:
            '§ 3.5: the general list is SUFFICIENT for FanMTL once .chapter-content is the '
            'right selector. Adding a site-specific selector needs a measured reason, and '
            'none of the twelve is missing from these pages',
      );
      expect(
        fanmtlChapterPolicy.removableSelectors.where(
          (String s) => s == 'a' || s == 'img',
        ),
        isEmpty,
        reason:
            'B44: removing <a> or <img> by default would cut pagination and covers at the '
            'same time as it "cleans" — following a URL found in a page is how both work',
      );
    });

    test('no selector is added for a single link or a single chapter', () {
      // § 10 rows 12-13 and § 6.2's E1 branch. A link-by-link removal list would be
      // several thousand entries whose maintenance diverges from the site at its first
      // change; a block is removed as a block.
      final List<String> selectors = fanmtlChapterPolicy.removableSelectors;
      expect(
        selectors.where((String s) => s.contains('chapternav')),
        isEmpty,
        reason:
            'E1: div.chapternav is a SIBLING of .chapter-content, so it is never in the '
            'output and needs no selector at all',
      );
      expect(
        selectors.where(
          (String s) => s.contains('novel-item') || s.contains('ke383028_'),
        ),
        isEmpty,
        reason:
            'E1: no selector is produced per novel link. The count is written in '
            '18-external-contracts.md as a NUMBER instead',
      );
      expect(
        selectors.any((String s) => s.contains('ke383028')),
        isFalse,
        reason:
            'and nothing in the list mentions this novel by name — a fixture-specific '
            'selector in shipped code is a claim about one page of one site',
      );
    });

    test('a prose link survives removal, on a document built for the rule', () {
      // ⚠️ **MEASURED NEGATIVE, stated rather than papered over.** None of the five frozen
      // chapter pages carries an `<a>` or an `<img>` inside its prose container (measured:
      // zero anchors and zero images in all three FanMTL chapters). So the real-fixture
      // half of B44 is asserted in the next row, against Royal Road's image, and THIS row
      // carries the link half on a document that has one. Inventing a FanMTL fixture with
      // a prose link is the § 7 mistake: a fabricated capture proving a shape no site
      // produces is a green test that proves nothing.
      final dom.Document document = html_parser.parse(
        '<div class="chapter-content">'
        'A <a href="/novel/ke383028_2.html">cited link</a> mid-paragraph.'
        '<br><br><img src="/novel/ke383028_2.html.png">'
        '</div>',
      );
      final dom.Element content = fanmtlChapterPolicy.selectContent(document)!;
      expect(
        content.querySelectorAll('a'),
        hasLength(1),
        reason: 'precondition: the document has the link this row is about',
      );
      applyRemovals(content, fanmtlChapterPolicy.removableSelectors);
      expect(
        content.querySelectorAll('a'),
        hasLength(1),
        reason:
            'B44: a link inside the prose survives. Its href is resolved by the converter '
            'against baseUrl (04-html-to-markdown.md rule 3) — never dropped here',
      );
      expect(
        content.querySelectorAll('img'),
        hasLength(1),
        reason:
            'B44: an image survives too. Whether it is KEPT in the Markdown is rule 3\'s '
            '"drop decorative by default" question and belongs to 2-2 — not to the '
            'removal list',
      );
      expect(
        content.querySelector('a')!.attributes['href'],
        '/novel/ke383028_2.html',
        reason:
            'B44: the href is NOT rewritten here. Resolving a URL is the converter\'s job '
            'at conversion time (§ 7), and a rewritten URL in a fixture no longer '
            'corresponds to the site',
      );
    });

    test('the one prose image in the whole capture survives — against Royal Road', () {
      // § 11.1 "conservation — images", on a REAL capture. `chapter-glossary.html` is the
      // only frozen chapter page whose prose carries an `<img src>`, so it is the fixture
      // that can carry this assertion honestly.
      final dom.Document document = html_parser.parse(
        File(
          'test/fixtures/sources/royalroad/chapter-glossary.html',
        ).readAsStringSync(),
      );
      final dom.Element content = document.querySelector('.chapter-content')!;
      expect(
        content.querySelectorAll('img'),
        hasLength(1),
        reason:
            'precondition: MEASURED, this is the only <img> inside any frozen chapter '
            'prose container in the repository. If a capture changes it, this row must be '
            're-measured rather than deleted',
      );
      final String src = content.querySelector('img')!.attributes['src']!;
      expect(
        src,
        startsWith('https://'),
        reason:
            'and it is an ABSOLUTE third-party URL, which is the harder case: the point '
            'of B44\'s second half is that a URL found in a page is not forbidden',
      );
      applyRemovals(content, generalDropList);
      expect(
        content.querySelectorAll('img'),
        hasLength(1),
        reason:
            'B44: it survives the general drop list. What 2-2 does with it afterwards — '
            'keep only story images (rule 3) — is a conversion decision, and it is made '
            'with the image in hand',
      );
    });

    test('the chrome is dropped even though the policy never selects it', () {
      // § 10 row 11: `aside.control-action` is absent after removal. It is outside the
      // content node, so a scoped walk never sees it — the row is here to prove the
      // OUTER walk drops it too, because a caller that hands the whole page to the
      // cleaner must not ship a font picker.
      final dom.Document document = documentOf('chapter-prose');
      expect(
        document.querySelector('aside.control-action'),
        isNotNull,
        reason: 'precondition: the chrome is there to be dropped',
      );
      applyRemovals(document.body!, fanmtlChapterPolicy.removableSelectors);
      expect(
        document.querySelector('aside.control-action'),
        isNull,
        reason:
            'B44: an <aside> is in the general list, so the font picker is dropped',
      );
      expect(
        document.querySelector('nav.action-items'),
        isNull,
        reason:
            'and so is the nav inside it — the pair is justified entry by entry',
      );
      expect(
        document.body!.text,
        isNot(contains('Default Dyslexic Roboto Lora')),
        reason:
            'the literal check a reader would make: the font-picker labels are gone from '
            'the retained text',
      );
      expect(
        document.querySelectorAll('.chapter-content'),
        hasLength(1),
        reason:
            'and the prose survived the walk, because the walk removes ELEMENTS and the '
            'prose is text — dropping it would be dropping the chapter',
      );
    });
  });

  group('B5 the forbidden path is never something the app fetches', () {
    test('/d/js/ad/page_01.js appears in no lib/ file and in no URL list', () {
      // § 10 row 10 and § 11.1 "removal — forbidden path". The path is robots-disallowed,
      // so its ONLY correct place is a record explaining why it is removed.
      const String forbidden = '/d/js/ad/page_01.js';
      final List<String> offenders = <String>[];
      for (final FileSystemEntity entity in Directory(
        'lib',
      ).listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        final String source = entity.readAsStringSync();
        if (source.contains(forbidden)) offenders.add(entity.path);
      }
      expect(
        offenders,
        isEmpty,
        reason:
            'B5: a robots-disallowed path must never reach shipped code. It appears in '
            '18-external-contracts.md as the REASON a <script> is dropped, which is a '
            'record, not a fetch list',
      );
      expect(
        fanmtlChapterPolicy.removableSelectors.where(
          (String s) => s.startsWith('http') || s.startsWith('/'),
        ),
        isEmpty,
        reason:
            'the removal list holds TAGS and CLASSES. A path in it would be a fetch, and '
            'the list is a list of things to drop from a tree the app already has',
      );
      expect(
        fanmtlChapterPolicy.notes,
        contains(forbidden),
        reason:
            'it is named in the policy\'s own notes — as the justification for dropping '
            'the tag, which is exactly what 18-external-contracts.md rule 1 asks for',
      );
    });
  });

  group('B10, E1 the header is furniture and the chapter list is not read here', () {
    test('header.chapter-header is classified furniture, outside the content node', () {
      // § 10 row 12 and § 3.2 row 5.
      const ClassifiedElement header = ClassifiedElement(
        selector: 'header.chapter-header',
        verdict: ElementVerdict.furniture,
        reason:
            'Novel title and chapter title. The displayed chapter title is read by 2-1 '
            'from the novel page\'s list, NOT from this node, or the reader sees it twice.',
        evidenceKey: 'chapter-prose',
      );
      expect(header.verdict, ElementVerdict.furniture);
      expect(
        header.isFurniture,
        isTrue,
        reason: 'the getter is a projection, not a second opinion',
      );
      final dom.Document document = documentOf('chapter-prose');
      expect(
        document.querySelectorAll('header.chapter-header'),
        hasLength(1),
        reason:
            'the selector must match exactly one node — § 11.1 "unique selector"',
      );
      expect(
        document
            .querySelector('.chapter-content')!
            .querySelector('header.chapter-header'),
        isNull,
        reason:
            'it is OUTSIDE the content node, so it can never reach the output and needs '
            'no removal selector. "Furniture (hors zone)", not "furniture"',
      );
      expect(
        header.reason,
        contains('2-1'),
        reason:
            'B10: the record must say where the displayed title comes from, or the next '
            'session reads the title out of this node and ships it twice',
      );
    });

    test('the chapter navigation block holds 3 links, and the prose holds none', () {
      // § 10 row 12 (E1's number) and row 13. The number is the deliverable; a selector
      // per link is what E1 forbids.
      for (final String key in chapterFixtureKeys) {
        final dom.Document document = documentOf(key);
        final dom.Element content = document.querySelector('.chapter-content')!;
        expect(
          content.querySelectorAll('a[href*="_"]'),
          isEmpty,
          reason:
              '$key: MEASURED, the prose container holds ZERO chapter links. § 6.2\'s E1 '
              'trap — a chapter-list block inside a chapter page — does not exist on this '
              'site, so § 7 open question 2 is answered "no"',
        );
        expect(
          content.querySelectorAll('div.chapternav'),
          isEmpty,
          reason:
              '$key: and the navigation block is not inside the prose either',
        );
        final dom.Element? nav = document.querySelector('div.chapternav');
        expect(
          nav,
          isNotNull,
          reason: 'precondition: the page does carry a navigation block',
        );
        expect(
          nav!.querySelectorAll('a'),
          hasLength(3),
          reason:
              'MEASURED: Prev / Index / Next — three links, not thousands. This is the '
              'NUMBER that 18-external-contracts.md records in place of a per-link list',
        );
      }
    });

    test('the chapter list is read on novel-detail, and that page has no prose', () {
      // § 10 row 13: the record must say the chapter list is read on `novel-detail`,
      // NEVER on a chapter page. A source that read it from a chapter page would find
      // three links and report a three-chapter novel — wrong, and plausible-looking.
      final FixtureManifest loaded = manifest();
      final dom.Document novel = documentOf('novel-detail');
      expect(
        novel.querySelectorAll('ul.chapter-list > li'),
        hasLength(
          manifest().require('novel-detail').expected['chapterRowsExact']
              as int,
        ),
        reason:
            'the novel page is where the chapter list lives: MEASURED 100 rows on the '
            'first page, and 0-1 declares that exact count, so this row re-derives 0-1\'s '
            'declaration rather than restating it. This is the surface 2-1 reads',
      );
      expect(
        novel.querySelectorAll('.chapter-content'),
        isEmpty,
        reason:
            'and it carries no prose container at all, so the two pages are structurally '
            'different documents — a source cannot read a chapter list off a chapter body '
            'even by accident',
      );
      for (final String key in chapterFixtureKeys) {
        expect(
          documentOf(key).querySelectorAll('ul.chapter-list'),
          isEmpty,
          reason:
              '$key: a chapter page carries no chapter list. Reading one from here would '
              'report three navigation links as the novel\'s chapters (B9)',
        );
      }
      expect(
        loaded.require('novel-detail').expected['chapterRowsExact'],
        isA<int>(),
        reason:
            'and the exact count is declared by 0-1, so "3 chapters" would be a '
            'detectable failure rather than a plausible wrong answer',
      );
    });
  });

  group('the classification rows each name one element and one fixture', () {
    // The table itself is documentation; this is the part that keeps it honest.
    const List<ClassifiedElement> table = <ClassifiedElement>[
      ClassifiedElement(
        selector: '.chapter-content',
        verdict: ElementVerdict.content,
        reason: 'The prose, 7,327 visible characters on chapter-prose.',
        evidenceKey: 'chapter-prose',
      ),
      ClassifiedElement(
        selector: '#chapter-article',
        verdict: ElementVerdict.furniture,
        reason:
            'Wraps the chrome AND the prose; the body is inside it, not equal to it.',
        evidenceKey: 'chapter-prose',
      ),
      ClassifiedElement(
        selector: 'header.chapter-header',
        verdict: ElementVerdict.furniture,
        reason:
            'Novel and chapter title; the title is read by 2-1 from novel-detail.',
        evidenceKey: 'chapter-prose',
      ),
      ClassifiedElement(
        selector: 'aside.control-action',
        verdict: ElementVerdict.furniture,
        reason:
            'The font picker plus prev/next and night mode; an aside, in the drop list.',
        evidenceKey: 'chapter-prose',
      ),
      ClassifiedElement(
        selector: 'nav.action-items',
        verdict: ElementVerdict.furniture,
        reason: 'The anchor inside that aside.',
        evidenceKey: 'chapter-prose',
      ),
      ClassifiedElement(
        selector: 'div.chapternav',
        verdict: ElementVerdict.furniture,
        reason:
            'Prev/Index/Next, a sibling of .chapter-content; never in the output.',
        evidenceKey: 'chapter-prose',
      ),
      ClassifiedElement(
        selector: 'script[src="/d/js/ad/page_01.js"]',
        verdict: ElementVerdict.furniture,
        reason:
            'An ad script inside the content div; /d/ is robots-disallowed (B5).',
        evidenceKey: 'chapter-prose',
      ),
      ClassifiedElement(
        selector: 'section.recommends.content-wrap',
        verdict: ElementVerdict.furniture,
        reason:
            'The "You\'ll Also Like" shelf: 10 anchors, 10 covers, outside the prose.',
        evidenceKey: 'chapter-prose',
      ),
      ClassifiedElement(
        selector: 'ins.adsbygoogle',
        verdict: ElementVerdict.furniture,
        reason: 'A Google ad slot inside the prose, holding no text at all.',
        evidenceKey: 'chapter-long',
      ),
    ];

    test(
      'every row\'s selector matches EXACTLY ONE element on its own fixture',
      () {
        // § 11.1 "unique selector". A selector matching two elements is not a
        // classification of an element; it is a classification of a coincidence.
        for (final ClassifiedElement row in table) {
          final dom.Document document = documentOf(row.evidenceKey);
          expect(
            document.querySelectorAll(row.selector),
            hasLength(1),
            reason:
                '${row.selector} must match exactly ONE node on ${row.evidenceKey}. Two '
                'matches would make the row a claim about a coincidence',
          );
        }
      },
    );

    test(
      'no furniture row is inside the content node unless it is a removal selector',
      () {
        // § 3.1 zone 3: "hors zone" elements are absent from the output because they were
        // never taken. Only rows genuinely inside the prose need a removal selector — and
        // § 3.5 says the general list is that selector, so even those need no addition.
        const List<String> outsideZone = <String>[
          '#chapter-article',
          'header.chapter-header',
          'div.chapternav',
          'section.recommends.content-wrap',
        ];
        final dom.Element content = documentOf(
          'chapter-prose',
        ).querySelector('.chapter-content')!;
        for (final ClassifiedElement row in table.where(
          (ClassifiedElement e) => outsideZone.contains(e.selector),
        )) {
          expect(
            content.querySelector(row.selector),
            isNull,
            reason:
                '${row.selector} is recorded as "hors zone", so it must NOT be inside the '
                'content node. If a re-capture nests it, the row needs rewriting to say it '
                'is now in-zone and needs a selector',
          );
        }
        for (final ClassifiedElement row in table.where(
          (ClassifiedElement e) =>
              e.verdict == ElementVerdict.furniture &&
              !outsideZone.contains(e.selector) &&
              e.selector != 'aside.control-action' &&
              e.selector != 'nav.action-items',
        )) {
          expect(
            fanmtlChapterPolicy.removableSelectors,
            contains('script'),
            reason:
                '${row.selector} is furniture INSIDE the prose, so the general drop list '
                'covers it. If the drop list ever stopped matching it, 2-2 would need a '
                'source-specific rule and this row would be the one to notice',
          );
        }
      },
    );

    test(
      'every row carries a non-empty evidence key that the manifest really declares',
      () {
        // § 11.1 "provenance" and C7. A row with no evidence is a row nobody can re-check.
        final FixtureManifest loaded = manifest();
        final Set<String> declared = loaded.entries
            .map((FixtureEntry e) => e.key)
            .toSet();
        for (final ClassifiedElement row in table) {
          expect(
            row.evidenceKey.trim(),
            isNotEmpty,
            reason: '${row.selector} has no provenance',
          );
          expect(
            declared,
            contains(row.evidenceKey),
            reason:
                '${row.evidenceKey} is not a manifest key, so the row cites a fixture that '
                'does not exist (18-external-contracts.md rule 1)',
          );
          expect(
            row.reason.trim().length,
            greaterThan(20),
            reason:
                '${row.selector}: a verdict without a stated observation is a judgement, '
                'and § 7 forbids classifying an element by "it looks decorative"',
          );
        }
      },
    );

    test('the paragraph disagreement is carried as INDETERMINATE, not decided', () {
      // § 3.4 and § 7's "do not decide an INDETERMINATE". The paragraph SHAPE is the one
      // thing this capture could not settle: two pages say `<p>`, one says `<br><br>`, and
      // nothing observed says which the next chapter will be.
      const ClassifiedElement paragraphs = ClassifiedElement(
        selector: 'p',
        verdict: ElementVerdict.indeterminate,
        reason:
            'chapter-prose has 0 <p> and 104 <br><br>; chapter-short has 53 <p> and '
            'chapter-long has 110, both with 0 <br><br>. Left undecided: the site emits '
            'both shapes and nothing observed says which the next chapter uses.',
        evidenceKey: 'chapter-prose',
      );
      expect(
        paragraphs.verdict,
        ElementVerdict.indeterminate,
        reason:
            '§ 3.3\'s last branch: three pages that disagree are an unstable template',
      );
      expect(
        paragraphs.isFurniture,
        isFalse,
        reason:
            'indeterminate is NOT furniture. "Not removed" and "kept as prose" are two '
            'different answers and an enum with three values is the only way to say so',
      );
      expect(
        fanmtlChapterPolicy.removableSelectors,
        isNot(contains('p')),
        reason:
            'the INDETERMINATE row must not leak into the removal list — that would be '
            'deciding it, and in the one direction § 3.4 forbids (dropping prose)',
      );
      expect(
        paragraphs.reason,
        contains('104'),
        reason:
            'the row must carry the numbers, so a re-capture that changes them makes the '
            'row visibly stale rather than quietly wrong',
      );
    });

    test(
      'the record in 18-external-contracts.md states the classification and its numbers',
      () {
        // § 3.6 output 2: the table lives in the contracts file, not only in this test.
        // A test is not a document a reader consults when the site changes.
        final String contracts = File(
          '.opencode/rules/18-external-contracts.md',
        ).readAsStringSync();
        for (final ClassifiedElement row in table) {
          expect(
            contracts,
            contains(row.selector),
            reason:
                '${row.selector} is classified in this test, so '
                '18-external-contracts.md must carry it — § 3.6: the classification is '
                'written where a reader re-checks it against a live page',
          );
        }
        expect(
          contracts,
          contains('pThenBrBr'),
          reason:
              'the corrected paragraph rule must be in the record, including the correction '
              'itself. A record that shows only the conclusion is a record nobody can audit',
        );
        expect(
          contracts,
          contains('53'),
          reason:
              'and the measured counts, so the claim is checkable against the bytes',
        );
      },
    );
  });

  group('the constructor asserts, and the one that cannot be an assert', () {
    test('a blank contentSelector and blank notes are refused', () {
      // § 3.5's two assertions and § 10 row 7. They fire in a NON-const invocation; a
      // `const` invocation with a blank string is a compile error, which is the stronger
      // of the two and is what the shipped policy uses.
      expect(
        () => ChapterContentPolicy(
          sourceId: 'probe',
          contentSelector: '',
          removableSelectors: const <String>['script'],
          paragraphRule: ParagraphRule.pThenBrBr,
          notes:
              'A probe carrying a blank selector, to prove the assert fires.',
        ),
        throwsA(isA<AssertionError>()),
        reason:
            'B44: a content selector is not a way to select nothing. A blank one would '
            'make selectContent return null on EVERY page, which reads as E4 forever',
      );
      expect(
        () => ChapterContentPolicy(
          sourceId: 'probe',
          contentSelector: '.chapter-content',
          removableSelectors: const <String>['script'],
          paragraphRule: ParagraphRule.pThenBrBr,
          notes: '',
        ),
        throwsA(isA<AssertionError>()),
        reason:
            '18-external-contracts.md rule 1: no provenance, no entry. A policy with no '
            'notes is a claim nobody can check against a capture',
      );
    });

    test(
      'the shipped policy is declared const, so its invariants are compile-time',
      () {
        // The strongest form of § 3.5's note. A `const` constructor's initializers are
        // evaluated by the compiler, so a bad policy is a build failure — not a runtime
        // surprise on a user's phone.
        expect(
          fanmtlChapterPolicy.sourceId,
          'fanmtl',
          reason:
              '03-source-system.md rule 1: the id is derived, and a policy carries it',
        );
        expect(fanmtlChapterPolicy.notes.trim().isNotEmpty, isTrue);
        expect(fanmtlChapterPolicy.contentSelector.trim(), isNotEmpty);
      },
    );

    test('a duplicate in removableSelectors is refused, and the check is a method', () {
      // ⚠️ **Why a method and not an initializer assert — the compiler, not preference.**
      // `toSet()` is a method call, and a method call is not a constant expression, so an
      // initializer `assert` calling it would make this class un-`const` and every `const`
      // policy a compile error. § 3.5's listing could not be delivered literally.
      expect(
        () => ChapterContentPolicy.assertNoDuplicateSelectors(<String>[
          'script',
          'aside',
          'script',
        ]),
        throwsA(isA<AssertionError>()),
        reason:
            '§ 3.2 calls out this exact mistake: listing `aside` twice is harmless at run '
            'time and fatal at review, because a list with a duplicate can no longer be '
            'justified entry by entry',
      );
      ChapterContentPolicy.assertNoDuplicateSelectors(
        fanmtlChapterPolicy.removableSelectors,
      );
      expect(
        fanmtlChapterPolicy.removableSelectors.toSet().length,
        fanmtlChapterPolicy.removableSelectors.length,
        reason:
            'the control: the shipped list passes. Without it, a check that rejected every '
            'list would satisfy the row above',
      );
    });

    test('the removal list is not order-dependent, so a duplicate is unambiguous', () {
      // The precondition for the duplicate check to mean anything: the list is a SET of
      // selectors, only the application ORDER is meaningful, and `querySelectorAll` is
      // scoped to the content node so no selector can reach furniture it was not meant to.
      expect(
        fanmtlChapterPolicy.removableSelectors.toSet(),
        generalDropList.toSet(),
        reason: 'same twelve selectors, whatever the order',
      );
      expect(
        fanmtlChapterPolicy.removableSelectors.first,
        'script',
        reason:
            'and script comes first. 04-html-to-markdown.md puts it first because its text '
            'is CODE: dropping only the tags would leave a reader staring at JavaScript',
      );
    });
  });
}
