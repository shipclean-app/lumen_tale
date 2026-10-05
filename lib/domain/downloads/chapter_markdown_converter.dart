// Lumen Tale — `2-2`'s step, as the one thing the loop needs from it.
//
// `5-1` § 3.3 calls it `cleanAndConvert`. The implementation is `core/pipeline`'s
// `convertChapter`, which cleans and converts in one pass over the parsed document and
// **never throws for malformed input** — an unreadable chapter comes back below the
// threshold, and the pipeline reports it as a failure rather than as an empty chapter.
//
// ## ⚠️ IT IS AN INTERFACE, NOT A FUNCTION VALUE
//
// So a test can interpose a converter that produces a chapter with no prose — which is
// how § 10's E18 criterion ("a fetch that succeeds and converts to nothing is
// `failed` + `no_real_text`, **not** stored") is exercised without crafting HTML that
// defeats the real converter.

import 'package:lumen_tale/core/pipeline/converted_chapter.dart';

/// Chapter HTML in, Markdown and its counts out.
abstract interface class ChapterMarkdownConverter {
  /// ⚠️ **NEVER THROWS.** A source whose layout changed must produce a chapter below the
  /// threshold, not an exception: an exception here would escape the loop, stop the
  /// whole queue, and turn one broken site into one broken novel.
  ConvertedChapter convert({required String rawHtml, required String baseUrl});
}
