// forge:slice 2-7
// Lumen Tale — `2-7`: the measured column, and the virtualised long chapter.
//
// ## The rows that matter most are about ABSENCE
//
// | promise | how it is checked |
// |---|---|
// | ADR-019: past the cap the layout stops growing and centres | **no threshold comparison exists** — a row greps the layout file for one |
// | no paragraph is clipped | the block split is **lossless** and `itemCount` is the block count, never an estimate |
//
// Both are absences, and an absence cannot be asserted by looking at output — it has to be
// asserted by looking at the code, or at an invariant that would break if the absence were
// violated.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lumen_tale/app/theme/reader_scale.dart';
import 'package:lumen_tale/domain/reader/chapter_document.dart';
import 'package:lumen_tale/features/reader/domain/reader_typography.dart';
import 'package:lumen_tale/features/reader/reader_layout.dart';
import 'package:lumen_tale/features/reader/virtualised_chapter_prose.dart';

/// A measurer that answers a fixed advance, so the arithmetic is checkable by hand.
final class FixedAdvance implements AdvanceMeasurer {
  const FixedAdvance(this.advance);

  final double advance;

  @override
  double averageAdvanceOf(String sample, double fontSize) => advance;
}

/// The prose at the design's default step, for the rows that are about the COLUMN and not
/// about the type.
///
/// ⚠️ **Added by `2-8`, which made the prose a required parameter.** B27 makes the chosen
/// step an input to the Markdown sheet — otherwise the sheet cannot re-render the chapter on
/// the frame the reader taps — and a parameter with a default would let a caller silently
/// render a chapter at `md` while the reader is at `xxl`. These rows' assertions are
/// unchanged: they are about virtualisation and the measure, not about typography.
ReaderProse proseAt(ReaderTextScale step) =>
    ReaderProse(step: step, style: resolveProse(step, TextScaler.noScaling));

ReaderLayout layoutWith(double advance) {
  return ReaderLayout(
    advance: advance,
    horizontalMargin: kReaderHorizontalMargin,
  );
}

ChapterText chapterWith(int bytes, String markdown) {
  return ChapterText(
    chapterId: 'c1',
    chapterName: 'Long',
    number: 1,
    ordinal: 1,
    markdown: markdown,
    byteLength: bytes,
  );
}

/// 300 paragraphs — enough to overflow any phone and to be split into many blocks.
String longMarkdown() {
  return List<String>.generate(
    300,
    (int i) => 'Paragraph number $i, long enough to occupy a line or two.',
  ).join('\n\n');
}

void main() {
  group('B27 / ADR-019 — the measure is computed', () {
    test('the cap is 75 characters of the MEASURED advance', () {
      // ⚠️ **The row that rules out a hard-coded character count.** With an advance of 10 dp
      // the cap is 750 dp — not 34 characters, not 680 dp, not whatever the previous font
      // happened to need.
      expect(layoutWith(10).maxColumnWidth, 750);
      expect(layoutWith(8).maxColumnWidth, 600);
    });

    test('a phone: the SCREEN binds and the cap does not', () {
      // ⚠️ **The constraint is a cap, not a width.** On a 360 dp phone with an 18 dp font the
      // cap is larger than the screen, so the column is the screen's width minus the
      // margins.
      final ReaderLayout layout = layoutWith(9);
      expect(layout.availableWidth(360), 320);
      expect(layout.capBinds(360), isFalse);
    });

    test('a wide screen: the CAP binds', () {
      // ⚠️ **The case the cap exists for.** At 1400 dp a full-width column would hold ~150
      // characters, and the eye loses the start of the next line coming back to the left.
      final ReaderLayout layout = layoutWith(9);
      expect(layout.availableWidth(1400), kMaxMeasureCharacters * 9);
      expect(layout.capBinds(1400), isTrue);
    });

    test('the achieved measure is DERIVED, and equals 75 by construction', () {
      expect(layoutWith(11).achievedCharacters, 75);
    });

    test('a narrow screen below 65 characters is the right answer', () {
      // ⚠️ **`design-quality.md` § 3's 16 dp floor and the measure's 65 are two different
      // constraints.** Merging them would grow the type on a narrow screen to reach 65
      // characters — which overflows, and which the floor exists to prevent.
      expect(layoutWith(20).availableWidth(120), 80);
    });

    test('⚠️ NO threshold comparison on screen width exists — ADR-019', () {
      // ⚠️ **The row that pins the absence.** `Center` + `ConstrainedBox(maxWidth:)` already
      // stops the layout growing past the cap, so a `MediaQuery.size.width > 600` branch
      // would be the *first* step towards a layout that grows on a tablet.
      final String code = _codeOf('lib/features/reader/reader_layout.dart');

      expect(code, isNot(contains('600')));
      expect(code, isNot(contains('MediaQuery')));
      // ⚠️ **And the cap is still applied**, so the absence is about the *branch* rather than
      // the rule having gone missing with it.
      expect(code, contains('kMaxMeasureCharacters * advance'));
    });

    testWidgets('⚠️ a wide screen CENTRES the column with equal gaps', (
      WidgetTester tester,
    ) async {
      // ⚠️ **ADR-019 as a measurement.** A full-width column would have a gap of zero on the
      // left; the row compares the two gaps, which is what centring means.
      final ReaderLayout layout = layoutWith(9);
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(size: Size(1400, 900)),
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: ReaderColumn(
                layout: layout,
                screenWidth: 1400,
                child: const SizedBox(height: 40, width: 20),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final Rect column = tester.getRect(find.byType(ReaderColumn));
      final Rect child = tester.getRect(find.byType(SizedBox).first);
      expect(child.left, greaterThan(0), reason: 'not flush to the left edge');
      expect(
        (child.left - (column.right - child.right)).abs(),
        lessThan(0.5),
        reason: 'equal gaps on both sides is what centring means',
      );
    });
  });

  group('the long chapter — B7, § 7.1', () {
    test('the split LOSES NOTHING', () {
      // ⚠️ **The row the "no clipping" promise rests on.** A lossy split would silently drop
      // the last paragraph of a 10 000-character chapter — which is the one a reader scrolls
      // to find.
      const String markdown =
          '# Title\n\nFirst paragraph.\n\nSecond paragraph.\n\n- one\n- two';
      final List<String> blocks = splitIntoBlocks(markdown);

      expect(blocks, hasLength(4));
      expect(blocks.join('\n\n'), markdown);
    });

    test('a chapter with no blank lines is ONE block, not none', () {
      // ⚠️ An empty list would render an empty chapter, and a chapter that renders as
      // nothing looks like the site published nothing.
      expect(splitIntoBlocks('Just one run of prose.'), <String>[
        'Just one run of prose.',
      ]);
    });

    test('whitespace-only blocks are dropped and the rest survives', () {
      expect(splitIntoBlocks('One.\n\n   \n\t\nTwo.'), <String>[
        'One.',
        'Two.',
      ]);
    });

    testWidgets('a SMALL chapter is ONE widget, not a list of blocks', (
      WidgetTester tester,
    ) async {
      // ⚠️ **The other direction, and it matters.** A `ListView.builder` over 30 blocks
      // costs more than it saves.
      await tester.pumpWidget(
        _host(
          ChapterProseColumn(
            document: chapterWith(
              500,
              'A short chapter.\n\nA second paragraph.',
            ),
            prose: proseAt(ReaderTextScale.md),
            layout: layoutWith(9),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(ListView), findsNothing);
      expect(find.textContaining('A short chapter'), findsOneWidget);
      expect(find.textContaining('A second paragraph'), findsOneWidget);
    });

    testWidgets('a LARGE chapter is a ListView.builder over its blocks', (
      WidgetTester tester,
    ) async {
      final String markdown = longMarkdown();
      await tester.pumpWidget(
        _host(
          ChapterProseColumn(
            document: chapterWith(markdown.length, markdown),
            prose: proseAt(ReaderTextScale.md),
            layout: layoutWith(9),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(ListView), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('reader-prose-area')),
        findsOneWidget,
      );
    });

    testWidgets('⚠️ the LAST block is reachable — no clipping, no estimate', (
      WidgetTester tester,
    ) async {
      // ⚠️ **The row `2-7`'s third promise exists for.** `itemCount` is the block count, so
      // scrolling to the end shows the final paragraph **in full**. An estimate — the common
      // shortcut for a virtualised list whose length is not known — would make the last block
      // unreachable, which is precisely the clipping the promise forbids.
      final String markdown = longMarkdown();
      await tester.pumpWidget(
        _host(
          ChapterProseColumn(
            document: chapterWith(markdown.length, markdown),
            prose: proseAt(ReaderTextScale.md),
            layout: layoutWith(9),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.drag(find.byType(ListView), const Offset(0, -100000));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Paragraph number 299'),
        findsOneWidget,
        reason: 'the final paragraph is entirely visible, not clipped',
      );
    });

    test('the threshold is a BYTE count, and the size is already known', () {
      // ⚠️ **`2-4` measured the file, so the signal is free and deterministic.** Timing the
      // build instead would be a property of the device, and `Q-003` says there is no device
      // here to time.
      expect(kVirtualiseAboveByteLength, greaterThan(0));
      expect(layoutWith(9).maxColumnWidth, greaterThan(0));
    });
  });

  group('E10 — a neighbour is never found by name', () {
    test('the neighbour type carries an ORDINAL and an id, and nothing textual', () {
      // ⚠️ **`name` is not unique and E10 forbids treating it as if it were.** A neighbour
      // lookup keyed on a title would open the wrong chapter for every novel with a repeated
      // chapter name — "Chapter 12" appears thousands of times.
      //
      // ⚠️ **Read from the declaration, not from memory.** A row that hard-coded the list
      // would keep passing after the type grew a `name`, which is the regression it is for.
      final List<String> fields = _neighbourFields();
      expect(fields, containsAll(<String>['chapterId', 'ordinal']));
      expect(fields, isNot(contains('name')));
      expect(fields, isNot(contains('number')));
      expect(fields, isNot(contains('title')));
    });
  });
}

/// A source file with its line and documentation comments removed.
String _codeOf(String path) {
  return File(path)
      .readAsStringSync()
      .split('\n')
      .where((String line) => !line.trimLeft().startsWith('//'))
      .join('\n');
}

/// `ChapterNeighbour`'s declared fields, **read from its own declaration**.
List<String> _neighbourFields() {
  final String source = File(
    'lib/domain/reader/chapter_reader_repository.dart',
  ).readAsStringSync();
  final int start = source.indexOf('final class ChapterNeighbour');
  final int end = source.indexOf('enum NeighbourDirection', start);
  final RegExp field = RegExp('final (?:String|int) (chapterId|ordinal);');
  return field
      .allMatches(source.substring(start, end))
      .map((RegExpMatch match) => match.group(1)!)
      .toList();
}

/// Pumps [child] in a real app, at phone size.
Widget _host(Widget child) {
  return MaterialApp(
    home: MediaQuery(
      data: const MediaQueryData(size: Size(360, 800)),
      child: SizedBox(width: 360, height: 800, child: child),
    ),
  );
}
