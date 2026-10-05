// Lumen Tale — "did any readable text survive?", the E18 threshold, and nothing else.
//
// `5-3` § 3.3. `core/utils/` — the home `02-architecture.md` § Directory authorities gives
// the logger, and a general utility rather than a downloads concept: the same question is
// asked of any converted chapter, whoever converted it.
//
// ## ⚠️ **THE QUESTION IS "DID ANY READABLE TEXT SURVIVE", NOT "WAS THERE MUCH"**
//
// E18's own words: *"A chapter is 'no real text' when nothing readable survives cleaning —
// no paragraph, no line break, and fewer than 100 characters of text in total."* The test
// is about **existence**, and the count is the floor beneath which existence is not
// established.
//
// ## ⚠️ **THE PARAGRAPH CONDITION IS AN `||`, NOT AN `&&`, AND THAT IS E22**
//
// `5-3` § 7 spells out the defect both spellings invite:
//
//   * **`&&`** — "a paragraph AND 100 characters" rejects a one-line, 140-character
//     translation note, which is legitimate content on these sites;
//   * **the count alone** — a 140-character *Sponsored* strip passes.
//
// So the paragraph-or-linebreak condition asks *whether the text is broken into prose at
// all*, and the character count asks *whether there is enough of it to be a chapter*.
//
// ## ⚠️ **THE THRESHOLD IS A NAMED CONSTANT AND NOT A LITERAL**, so changing it is one edit
// with a row that names the number, rather than a constant buried in a getter.

/// E18 — below this many visible characters, a chapter is not stored as complete.
const int minimumReadableCharacters = 100;

/// Whether [markdown] holds a chapter's worth of readable text.
///
/// ⚠️ **MARKDOWN IS CHECKED, NOT THE RAW HTML.** `2-2` has already cleaned and converted by
/// the time anything asks, and the question is about what a reader would see. A tag count
/// would answer a different question and would call a page of `<div>`s a chapter.
bool hasRealText(String markdown) {
  if (markdown.trim().isEmpty) {
    return false;
  }
  // ⚠️ **`\n` AND NOT `\r\n`.** A converter that emits CRLF would have every paragraph split
  // by a bare `\n` too, so the coarse separator is both sufficient and insensitive to the
  // platform's line ending.
  final bool hasStructure = markdown.contains('\n');
  if (!hasStructure) {
    return false;
  }
  return visibleCharacterCount(markdown) >= minimumReadableCharacters;
}

/// The visible characters: whitespace collapsed, Markdown syntax not counted.
///
/// ⚠️ **MARKDOWN SYNTAX IS REMOVED BEFORE COUNTING, AND THAT IS THE POINT OF THE FUNCTION.**
/// A page whose converter produced 120 `#` and `*` characters has no readable text, and a
/// threshold applied to raw length would pass it. `converted_chapter.dart` computes the same
/// figure inside the pipeline; this is the standalone form the pipeline's own decision and
/// this file cannot disagree with, so it is spelled once here and referenced there.
int visibleCharacterCount(String markdown) {
  final String withoutSyntax = markdown
      .replaceAll(RegExp(r'[#*_>`~\[\]()]'), '')
      .replaceAll(RegExp(r'!?\[[^\]]*\]\([^)]*\)'), '');
  return withoutSyntax.replaceAll(RegExp(r'\s'), '').length;
}
