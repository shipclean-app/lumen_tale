// Lumen Tale — the queue's binding of `2-2`'s converter.
//
// ## ⚠️ ONE CLASS, AND IT IS ALMOST EMPTY
//
// `convertChapter` is already a top-level pure function in `core/pipeline`, so this
// adapter exists only to give it the port's method shape. It is one line of behaviour
// and a comment, and that is deliberate: a second implementation of the cleaning rules
// would be a second dialect of `04-html-to-markdown.md`, and the pipeline is the one
// transformation this app must be able to reproduce byte for byte.
//
// ## ⚠️ **`keepImages` IS LEFT AT ITS DEFAULT, `false`**
//
// `ConversionRequest.keepImages` documents the reason: *"the **download** pipeline
// fetches the files — not this converter"*. Nothing in `5-1` fetches an image, so
// passing `true` here would put `![…](…)` references to files the app never
// downloaded, and the reader would see broken images in an offline chapter.

import 'package:lumen_tale/core/pipeline/converted_chapter.dart';
import 'package:lumen_tale/core/pipeline/html_to_markdown.dart';
import 'package:lumen_tale/core/pipeline/removal_rule.dart';
import 'package:lumen_tale/domain/downloads/chapter_markdown_converter.dart';

final class PipelineChapterConverter implements ChapterMarkdownConverter {
  const PipelineChapterConverter();

  @override
  ConvertedChapter convert({
    required String rawHtml,
    required String baseUrl,
  }) => convertChapter(ConversionRequest(rawHtml: rawHtml, baseUrl: baseUrl));
}
