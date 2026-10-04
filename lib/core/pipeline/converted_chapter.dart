// Lumen Tale — what a conversion produced, and the one threshold that decides whether a
// chapter is real.
//
// `04-html-to-markdown.md` § 3.5. E22 and E18 in one expression.
//
// ## Why "no real text" is a threshold and not an emptiness check
//
// A page that converted to **zero** paragraphs and zero breaks may still hold prose: a
// chapter published as one unbroken run with no `<p>` and no `<br>` emits `paragraphCount
// == 0` while being a perfectly readable chapter. Checking `paragraphCount == 0` alone
// would throw that chapter away, and FanMTL's shape is exactly why.
//
// So the threshold is **all three** conditions together, and `textLength` is the one that
// carries the weight.

/// The converter's output, and the counts that let a pipeline decide about it.
final class ConvertedChapter {
  const ConvertedChapter({
    required this.markdown,
    required this.paragraphCount,
    required this.lineBreakCount,
    required this.plainTextLength,
    required this.imagesKept,
  });

  /// The Markdown. **Deterministic**: the same HTML produces these bytes every time.
  final String markdown;

  final int paragraphCount;

  /// `<br>`s emitted as **hard** breaks — one `<br>`, not the `pendingBreak == 2` pair.
  final int lineBreakCount;

  /// The visible text's length, tags excluded. The figure that carries E22's weight.
  final int plainTextLength;

  /// ⚠️ **`0` by default**, because rule 3 drops images. A non-zero value means the
  /// source asked to keep them.
  final int imagesKept;

  /// ⚠️ **Three conditions together, and none of them alone.**
  ///
  /// ```text
  /// paragraphCount == 0 && lineBreakCount == 0 && plainTextLength < 100
  /// ```
  ///
  /// A chapter that is genuinely below this is reported as a **failure** by the pipeline,
  /// never as an empty chapter — because "this site could not be read" and "this chapter
  /// is blank" are different claims, and B22 says the difference is the site's own signal.
  bool get belowThreshold =>
      paragraphCount == 0 && lineBreakCount == 0 && plainTextLength < 100;

  @override
  String toString() =>
      'ConvertedChapter($paragraphCount ¶, $lineBreakCount ⏎, $plainTextLength chars, '
      '$imagesKept images)';
}

/// The threshold's two halves, named.
///
/// Exposed so a row can state them individually rather than only their conjunction, and
/// so a change to the number is one edit with a test rather than a constant buried in a
/// getter.
const int kMinTextLengthForARealChapter = 100;

/// ⚠️ **A deliberate over-estimate, and here is why.**
///
/// A chapter that reaches 100 visible characters has told the converter it holds prose.
/// Anything less is not *proven* empty — it is **unproven**, and the safe reading of an
/// unproven chapter is a failure the reader can see and retry, not an empty chapter they
/// cannot distinguish from a blank one.
const int kMinParagraphsForARealChapter = 1;
