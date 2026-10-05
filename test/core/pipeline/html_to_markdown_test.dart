// forge:slice 2-2
// Lumen Tale — `2-2`, the HTML→Markdown converter, and the rule it exists for.
//
// ## The fixture shape that decided the design
//
// FanMTL emits **zero** `<p>`. A converter that asks "is this node a `<p>`" sees no `<p>`
// on a real chapter and emits the whole chapter as one paragraph — which **looks**
// correct at a glance and fails structurally. So every row about paragraphs here runs on
// `<br><br>`-shaped input, and there is a dedicated fixture group for it.

import 'package:flutter_test/flutter_test.dart';
import 'package:lumen_tale/core/pipeline/converted_chapter.dart';
import 'package:lumen_tale/core/pipeline/html_to_markdown.dart';
import 'package:lumen_tale/core/pipeline/removal_rule.dart';

const String baseUrl = 'https://www.royalroad.com';

ConvertedChapter convert(String html, {List<RemovalRule> removals = const []}) {
  return convertChapter(
    ConversionRequest(
      rawHtml: html,
      baseUrl: baseUrl,
      additionalRemovals: removals,
    ),
  );
}

void main() {
  group('`<br><br>` is a paragraph — § 3.2, the central rule', () {
    test('two breaks then text makes a NEW paragraph', () {
      // ⚠️ **The row the whole converter exists for.** With zero `<p>` in the input, this
      // is the only thing that creates a paragraph.
      final ConvertedChapter out = convert(
        '<div>First line<br><br>Second line<br><br>Third line</div>',
      );
      expect(out.paragraphCount, 3);
      expect(
        out.markdown.split('\n\n').where((String s) => s.trim().isNotEmpty),
        hasLength(3),
      );
    });

    test('one break is a HARD break, not a paragraph', () {
      // Two trailing spaces then a newline: that is what tells a renderer not to join the
      // lines back together.
      final ConvertedChapter out = convert('<div>First<br>Second</div>');
      expect(out.paragraphCount, 1);
      expect(out.lineBreakCount, 1);
      expect(out.markdown, contains('First  \nSecond'));
    });

    test('a third break changes nothing', () {
      final ConvertedChapter three = convert('<div>A<br><br><br>B</div>');
      final ConvertedChapter two = convert('<div>A<br><br>B</div>');
      expect(three.paragraphCount, two.paragraphCount);
      expect(three.markdown, two.markdown);
    });

    test('a trailing <br><br> does NOT leave two empty lines', () {
      // The pending break disappears with the stack. A chapter ending in <br><br> must
      // not end in blank lines the reader scrolls through.
      final ConvertedChapter out = convert('<div>Only line<br><br></div>');
      expect(out.markdown.trimRight(), 'Only line');
      expect(out.markdown.endsWith('\n\n'), isFalse);
    });

    test('a <p> is a paragraph too, and the two rules do not double-count', () {
      final ConvertedChapter out = convert('<div><p>One</p><p>Two</p></div>');
      expect(out.paragraphCount, 2);
    });
  });

  group('block elements', () {
    test('headings, with the level bounded to six', () {
      final ConvertedChapter out = convert(
        '<div><h1>Title</h1><h3>Sub</h3></div>',
      );
      expect(out.markdown, contains('# Title'));
      expect(out.markdown, contains('### Sub'));
    });

    test('blockquote: every line carries the marker', () {
      // ⚠️ Writing `> ` once at the start is the common shortcut, and it produces a
      // Markdown blockquote whose second line falls out of it.
      final ConvertedChapter out = convert(
        '<div><blockquote>First<br>Second</blockquote></div>',
      );
      final List<String> quoted = out.markdown
          .split('\n')
          .where((String l) => l.trim().isNotEmpty)
          .toList();
      expect(quoted, everyElement(startsWith('> ')));
    });

    test('hr, and it is surrounded by blank lines', () {
      final ConvertedChapter out = convert('<div>A<hr>B</div>');
      expect(out.markdown, contains('\n\n---\n\n'));
    });

    test('an unlisted wrapper passes its prose through', () {
      // Rule 8 (no data loss) outranks tidiness: dropping unlisted subtrees would lose
      // prose, and prose is the product.
      final ConvertedChapter out = convert(
        '<div><section><span>Kept</span></section></div>',
      );
      expect(out.markdown, contains('Kept'));
    });
  });

  group('lists', () {
    test('an unordered list, nested, indented two spaces per level', () {
      final ConvertedChapter out = convert(
        '<div><ul><li>One<ul><li>Deep</li></ul></li><li>Two</li></ul></div>',
      );
      expect(out.markdown, contains('- One'));
      expect(out.markdown, contains('  - Deep'));
    });

    test('an ordered list numbers, and a nested one RESTARTS at 1', () {
      final ConvertedChapter out = convert(
        '<div><ol><li>One<ol><li>Deep</li></ol></li><li>Two</li></ol></div>',
      );
      expect(out.markdown, contains('1. One'));
      expect(
        out.markdown,
        contains('   1. Deep'),
        reason: 'a nested list restarts',
      );
      expect(out.markdown, contains('2. Two'));
    });
  });

  group('inline elements', () {
    test('emphasis, strong, strikethrough', () {
      final ConvertedChapter out = convert(
        '<div><em>a</em> <strong>b</strong> <del>c</del></div>',
      );
      expect(out.markdown, contains('*a*'));
      expect(out.markdown, contains('**b**'));
      expect(out.markdown, contains('~~c~~'));
    });

    test('code and pre are NEVER escaped', () {
      // ⚠️ A chapter about shell quoting must survive intact.
      final ConvertedChapter out = convert('<div><code>a * b _ c</code></div>');
      expect(out.markdown, contains('`a * b _ c`'));

      final ConvertedChapter pre = convert(
        '<div><pre>if a * b:\n    c_d()</pre></div>',
      );
      expect(pre.markdown, contains('if a * b:'));
      expect(pre.markdown, contains('c_d()'));
      expect(pre.markdown, isNot(contains(r'\_')));
    });

    test('a link resolves against baseUrl', () {
      final ConvertedChapter out = convert(
        '<div><a href="/fiction/1/x">Chapter</a></div>',
      );
      expect(
        out.markdown,
        contains('[Chapter](https://www.royalroad.com/fiction/1/x)'),
      );
    });

    test('⚠️ javascript: is NEVER rendered', () {
      // A link is navigation; a `javascript:` href is code pretending to be a place.
      final ConvertedChapter out = convert(
        '<div><a href="javascript:alert(1)">Click</a></div>',
      );
      expect(out.markdown, isNot(contains('javascript')));
      expect(out.markdown, isNot(contains('alert')));
      // ⚠️ **And the label survives as plain text** — the words are the author's.
      expect(out.markdown, contains('Click'));
    });

    test('a data: URL is dropped too', () {
      final ConvertedChapter out = convert(
        '<div><a href="data:text/html,<b>x">Label</a></div>',
      );
      expect(out.markdown, isNot(contains('data:')));
    });
  });

  group('images — rule 3, drop by default', () {
    test('the default keeps none', () {
      final ConvertedChapter out = convert(
        '<div><img src="/a.png" alt="x"></div>',
      );
      expect(out.imagesKept, 0);
      expect(out.markdown, isNot(contains('![')));
    });

    test('a source may keep them, and the src is resolved', () {
      final ConvertedChapter out = convertChapter(
        const ConversionRequest(
          rawHtml: '<div><img src="/cover.jpg" alt="cover"></div>',
          baseUrl: baseUrl,
          keepImages: true,
        ),
      );
      expect(out.imagesKept, 1);
      expect(
        out.markdown,
        contains('![cover](https://www.royalroad.com/cover.jpg)'),
      );
    });

    test('an unresolvable src is dropped and NOT counted', () {
      // ⚠️ An `![](…)` the reader will also see broken is worse than no image.
      final ConvertedChapter out = convertChapter(
        const ConversionRequest(
          rawHtml: '<div><img alt="no src"></div>',
          baseUrl: baseUrl,
          keepImages: true,
        ),
      );
      expect(out.imagesKept, 0);
      expect(out.markdown, isNot(contains('![')));
    });
  });

  group('tables — three branches', () {
    test('a regular table becomes a Markdown table', () {
      final ConvertedChapter out = convert(
        '<div><table><tr><th>A</th><th>B</th></tr><tr><td>1</td><td>2</td></tr></table></div>',
      );
      expect(out.markdown, contains('| A | B |'));
      expect(out.markdown, contains('|---|---|'));
      expect(out.markdown, contains('| 1 | 2 |'));
    });

    test('an IRREGULAR table falls back to paragraphs, and loses no text', () {
      // ⚠️ **Rule 8: the shape is lost, the text never is.** The separator is an em dash
      // and not a pipe, because a pipe inside prose reads as a table row to every
      // renderer and this fallback is prose.
      final ConvertedChapter out = convert(
        '<div><table><tr><td>A</td><td>B</td></tr><tr><td>1</td></tr></table></div>',
      );
      expect(out.markdown, isNot(contains('|---')));
      expect(out.markdown, contains('A — B'));
      expect(out.markdown, contains('1'));
    });

    test('over 200 rows the fallback is unconditional', () {
      final StringBuffer rows = StringBuffer();
      for (int i = 0; i < kMaxTableRows + 5; i++) {
        rows.write('<tr><td>r$i</td></tr>');
      }
      final ConvertedChapter out = convert('<div><table>$rows</table></div>');
      expect(out.markdown, isNot(contains('|---')), reason: 'unconditional');
      expect(out.markdown, contains('r0'));
      expect(out.markdown, contains('r${kMaxTableRows + 4}'));
    });
  });

  group('removals', () {
    test('script and style go with their SUBTREE', () {
      // ⚠️ Their text is code, not prose. Dropping only the tags would leave a reader
      // staring at a page of JavaScript.
      final ConvertedChapter out = convert(
        '<div>Keep<script>var a = 1;</script><style>.a{}</style></div>',
      );
      expect(out.markdown, contains('Keep'));
      expect(out.markdown, isNot(contains('var a')));
      expect(out.markdown, isNot(contains('.a{}')));
    });

    test('a source adds its own, and the defaults are NOT replaced', () {
      // ⚠️ **The union, never a replacement.** A source cannot re-introduce a `<script>`
      // by omitting it, because omitting is not an operation the type offers.
      final ConvertedChapter out = convert(
        '<div>Keep<script>bad()</script><div class="rr-share">SHARE</div></div>',
        removals: const <RemovalRule>[
          RemovalRule(
            selector: '.rr-share',
            why: 'Royal Road\'s share widget.',
          ),
        ],
      );
      expect(out.markdown, isNot(contains('SHARE')));
      expect(out.markdown, isNot(contains('bad()')));
      expect(out.markdown, contains('Keep'));
    });

    test('a non-subtree removal keeps its TEXT', () {
      final ConvertedChapter out = convert(
        '<div>Before<form><span>placeholder text</span></form>After</div>',
      );
      expect(out.markdown, contains('placeholder text'));
    });

    test('every default rule has a non-empty why', () {
      // A removal nobody can justify is a removal nobody should be able to change.
      for (final RemovalRule rule in <RemovalRule>[
        ...kDefaultRemovals,
        ...kConventionRemovals,
      ]) {
        expect(rule.why.trim(), isNotEmpty, reason: rule.selector);
        expect(rule.selector.trim(), isNotEmpty);
      }
    });
  });

  group('escaping — only where it changes the sense', () {
    test('a markdown character adjacent to text IS escaped', () {
      final ConvertedChapter out = convert('<div>a*b and c_d</div>');
      expect(out.markdown, contains(r'a\*b'));
      expect(out.markdown, contains(r'c\_d'));
    });

    test('⚠️ a lone asterisk between spaces stays readable', () {
      // ⚠️ **The compromise, locked down.** A chapter *about* markdown must not be made
      // into noise; a blanket escape turns "he said * * *" into escaped punctuation the
      // reader has to read past.
      final ConvertedChapter out = convert('<div>he said * loudly</div>');
      expect(out.markdown, contains('he said * loudly'));
    });

    test('an unescaped character is never left able to become a rule', () {
      // A `#` at the start of a line would become a heading; adjacent-to-text means it is
      // escaped.
      final ConvertedChapter out = convert('<div>tag#1 here</div>');
      expect(out.markdown, contains(r'tag\#1'));
    });
  });

  group('whitespace', () {
    test('runs of whitespace inside a text node become ONE space', () {
      final ConvertedChapter out = convert('<div>a   \n\t  b</div>');
      expect(out.markdown, contains('a b'));
    });

    test('never two blank lines in a row', () {
      final ConvertedChapter out = convert(
        '<div><p>A</p><p></p><p></p><p>B</p></div>',
      );
      expect(out.markdown.contains('\n\n\n'), isFalse);
    });
  });

  group('the threshold — E22 in three conditions', () {
    test('a chapter with no <p> and no <br> is NOT below the threshold', () {
      // ⚠️ **The row that stops a real chapter being thrown away.** FanMTL's shape means a
      // readable chapter carries neither tag, so a check on "zero `<p>`" would discard it.
      //
      // `paragraphCount` is **1**, not 0: the opening run of text is a paragraph as a
      // reader sees it, and the converter counts paragraphs rather than counting tags.
      // That is why the threshold's three conditions are a **conjunction** and not a
      // single test — `plainTextLength` is the one carrying the weight, exactly as § 3.5
      // says, and a chapter here has 200 visible characters against a threshold of 100.
      final ConvertedChapter out = convert('<div>${'x' * 200}</div>');
      expect(out.lineBreakCount, 0);
      expect(
        out.plainTextLength,
        greaterThanOrEqualTo(kMinTextLengthForARealChapter),
      );
      expect(out.belowThreshold, isFalse);
    });

    test(
      'the count is paragraphs as a reader sees them, not tags in the source',
      () {
        // ⚠️ **The row that separates the two readings**, because they differ exactly here:
        // three visible paragraphs, one `<p>` and one `<br><br>`.
        final ConvertedChapter out = convert(
          '<div><p>One</p>Two<br><br>Three</div>',
        );
        expect(out.paragraphCount, 3);
      },
    );

    test('a page with no real text IS below it', () {
      final ConvertedChapter out = convert('<div></div>');
      expect(out.belowThreshold, isTrue);
    });

    test('the threshold is all three conditions together', () {
      ConvertedChapter at({
        required int paragraphs,
        required int breaks,
        required int length,
      }) => ConvertedChapter(
        markdown: '',
        paragraphCount: paragraphs,
        lineBreakCount: breaks,
        plainTextLength: length,
        imagesKept: 0,
      );

      expect(at(paragraphs: 0, breaks: 0, length: 99).belowThreshold, isTrue);
      expect(at(paragraphs: 0, breaks: 0, length: 100).belowThreshold, isFalse);
      expect(at(paragraphs: 1, breaks: 0, length: 0).belowThreshold, isFalse);
      expect(at(paragraphs: 0, breaks: 1, length: 0).belowThreshold, isFalse);
    });
  });

  group('determinism', () {
    test('the same HTML twice is byte-identical', () {
      const String html =
          '<div><h2>C</h2><p>Text with <em>emphasis</em> and a '
          '<a href="/x">link</a>.</p><ul><li>a</li><li>b</li></ul></div>';
      expect(convert(html).markdown, convert(html).markdown);
    });

    test('a 10 000-entry list does not overflow the stack — E1', () {
      // ⚠️ **The reason the walk is iterative.** Recursion over `Element.children` is
      // shorter and throws on a real chapter.
      final StringBuffer items = StringBuffer();
      for (int i = 0; i < 10000; i++) {
        items.write('<li>Item $i</li>');
      }
      ConvertedChapter? out;
      expect(
        () => out = convert('<div><ul>$items</ul></div>'),
        returnsNormally,
      );
      expect(out!.markdown, contains('Item 9999'));
    });

    test('malformed HTML never throws', () {
      // A converter that threw would turn a site's layout change into a crash.
      for (final String html in <String>[
        '<div><p>unclosed',
        '<p>no body',
        '',
        '<div><b><i>mismatched</b></i></div>',
        'not html at all',
      ]) {
        expect(() => convert(html), returnsNormally, reason: html);
      }
    });
  });
}
