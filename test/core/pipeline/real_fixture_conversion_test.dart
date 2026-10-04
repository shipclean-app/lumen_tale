// forge:slice 2-1, 2-2
// Lumen Tale — `2-2` against **real captured bytes**, not synthetic HTML.
//
// ## Why this file exists beside `html_to_markdown_test.dart`
//
// The synthetic rows prove the *rules*. This file proves the rules survive contact with a
// site. `2-1` returns `div.chapter-inner.chapter-content`'s inner HTML from a real capture,
// and this runs **those bytes** through the converter. A selector that matches and a
// converter that cannot read what the selector matched are two different failures, and
// only one of them is caught by a fixture made of `<div>`s.
//
// The extraction here is deliberately **the same selector `2-1` uses**, read from the
// same file, so a change to one without the other fails a row rather than quietly making
// this test easier.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;
import 'package:lumen_tale/core/pipeline/converted_chapter.dart';
import 'package:lumen_tale/core/pipeline/html_to_markdown.dart';
import 'package:lumen_tale/core/pipeline/removal_rule.dart';
import 'package:lumen_tale/sources/implementations/royal_road_source.dart';

const String baseUrl = 'https://www.royalroad.com';

String fixture(String name) =>
    File('test/fixtures/sources/royalroad/$name').readAsStringSync();

/// Exactly what `2-1`'s `fetchChapterContent` returns for [captureName]: the body's
/// `innerHtml`, and nothing else.
String chapterBytesOf(String captureName) {
  final dom.Document document = html_parser.parse(fixture(captureName));
  final dom.Element? body = document.querySelector(
    RoyalRoadSelectors.chapterBody,
  );
  expect(
    body,
    isNotNull,
    reason: 'the fixture must match the source\'s selector',
  );
  return body!.innerHtml;
}

ConvertedChapter convertCaptured(
  String captureName, {
  List<RemovalRule> removals = const <RemovalRule>[],
}) {
  return convertChapter(
    ConversionRequest(
      rawHtml: chapterBytesOf(captureName),
      baseUrl: baseUrl,
      additionalRemovals: removals,
    ),
  );
}

void main() {
  group('a real chapter, converted', () {
    test('a glossary chapter is above the threshold and holds real prose', () {
      final ConvertedChapter out = convertCaptured('chapter-glossary.html');
      expect(
        out.belowThreshold,
        isFalse,
        reason: 'a real page that reports as empty is SC-6 in its purest form',
      );
      expect(out.plainTextLength, greaterThan(100));
      expect(out.paragraphCount, greaterThan(0));
    });

    test('the same for a second, longer capture', () {
      final ConvertedChapter out = convertCaptured(
        'chapter-skills-titles.html',
      );
      expect(out.belowThreshold, isFalse);
      expect(out.plainTextLength, greaterThan(100));
    });

    test('⚠️ no raw HTML survives into the Markdown', () {
      // The one thing a converter must never do: hand the reader a tag.
      for (final String capture in <String>[
        'chapter-glossary.html',
        'chapter-skills-titles.html',
      ]) {
        final String markdown = convertCaptured(capture).markdown;
        for (final String tag in const <String>[
          '<div',
          '<span',
          '<script',
          '<style',
          '</p>',
          '<br',
        ]) {
          expect(
            markdown,
            isNot(contains(tag)),
            reason: '$capture leaked $tag',
          );
        }
      }
    });

    test('⚠️ and no site furniture survives', () {
      // The removals are applied to the extracted body, so anything the site put inside
      // the article container is still furniture.
      final String markdown = convertCaptured('chapter-glossary.html').markdown;
      expect(markdown, isNot(contains('chapter-inner')));
      expect(markdown.toLowerCase(), isNot(contains('share')));
    });

    test('converting twice is byte-identical — determinism', () {
      expect(
        convertCaptured('chapter-glossary.html').markdown,
        convertCaptured('chapter-glossary.html').markdown,
      );
    });

    test('a whole chapter never overflows the stack — E1', () {
      // The real bytes are ~160 KB of markup; a recursive walk would be the first thing
      // to try.
      expect(
        () => convertCaptured('chapter-skills-titles.html'),
        returnsNormally,
      );
    });

    test('the Markdown holds the chapter\'s own words, not a placeholder', () {
      // A converter that produced 200 characters of boilerplate would pass every count
      // above, so the row checks that real prose is present.
      //
      // ⚠️ **The threshold is 500, not 1000, and the reason is that this capture is a
      // GLOSSARY.** It is a real chapter and it is genuinely short; a row asserting 1000
      // would be asserting that every Royal Road chapter is a thousand characters long,
      // which is false and would fail the day a short prologue was published.
      final ConvertedChapter glossary = convertCaptured(
        'chapter-glossary.html',
      );
      expect(glossary.markdown.length, greaterThan(500));
      final ConvertedChapter long = convertCaptured(
        'chapter-skills-titles.html',
      );
      expect(long.markdown.length, greaterThan(2000));
      // Every chapter on this site opens with prose rather than markup, so a Markdown
      // full of `#`, `|` and `[` would mean the walk is emitting structure it invented.
      final int structureChars = glossary.markdown
          .split('')
          .where((String c) => '#|[]*`'.contains(c))
          .length;
      expect(
        structureChars / glossary.markdown.length,
        lessThan(0.02),
        reason: 'a prose chapter is almost entirely prose',
      );
    });
  });

  group('a manufactured broken layout', () {
    test('the converter sees a page with no article at all', () {
      // `0-1` manufactures this fixture by renaming the content container's class. It is
      // the generic test: **this file must not know which selector broke.**
      final dom.Document document = html_parser.parse(
        fixture('manufactured/broken-layout.html'),
      );
      expect(
        document.querySelector(RoyalRoadSelectors.chapterBody),
        isNull,
        reason:
            'the fixture must NOT match the source selector — that is its purpose',
      );
    });

    test(
      '⚠️ and converting it ANYWAY produces plenty of prose — which is the point',
      () {
        // ⚠️ **This row says the uncomfortable thing out loud.**
        //
        // `0-1` manufactures this fixture by renaming the content container's class, and it
        // is a **catalogue** page — 109 `<p>` elements and 34 000 characters of text. Handed
        // to the converter whole, it converts to a long, confident, entirely wrong chapter.
        //
        // So **the threshold cannot be what protects the product here**, and no converter
        // can: given a page full of prose it will faithfully convert the prose. What protects
        // the reader is `2-1`'s selector returning nothing, which the row above asserts.
        //
        // A converter that "detected" this page would be guessing, and a guess that turns a
        // long catalogue page into a short chapter is the mirror image of SC-6.
        final ConvertedChapter out = convertChapter(
          ConversionRequest(
            rawHtml: fixture('manufactured/broken-layout.html'),
            baseUrl: baseUrl,
          ),
        );
        expect(out.belowThreshold, isFalse);
        expect(out.plainTextLength, greaterThan(1000));
      },
    );
  });
}
