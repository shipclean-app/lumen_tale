// Lumen Tale — what part of a chapter page is the prose, and what must never
// reach the reader.
//
// Slice `0-4`. Pure Dart, zero Flutter imports (`02-architecture.md`): `domain`
// carries no Flutter import, so `2-2`'s cleaner can be tested as a plain unit and the
// `source-unavailable` sheet can name a failed selector without a `MaterialApp`.
//
// ## Why this file is a VALUE and not a service
//
// `04-html-to-markdown.md` rule 2: *cleaning is per source* — "each source provides
// the selectors/classes to strip". That rule was written before anything had read a
// real chapter page, so it named a mechanism and not a value. This is the value: the
// `2-2` cleaner takes one as a parameter, so the SAME cleaner serves every source with
// a different classification and there is exactly one implementation of "strip the
// furniture" in the repository.
//
// ## `selectContent` returns `null`, and `null` MEANS something
//
// E4 and B22: when a site reorganises its pages, the app must say *this site could
// not be read* and never show an empty catalogue as if the novel had none. That
// distinction is only possible if "the container is absent" is a value the caller can
// branch on. So the absent case is `null` and nothing else — not an empty `Element`,
// not an empty string, and **not an exception**, because a thrown exception in the
// middle of a fetch pipeline is what turns a layout change into a crash.
//
// C6/C12 follow from it: the caller turns this `null` into
// `SourceLayoutChanged(selector: …)`, which carries **the selector that failed** — a
// string the reader can read aloud and report to the owner.
//
// ## The constructor asserts, and one of them is a `const` compile error
//
// A contract nobody checks is a comment. The three invariants below are checked at the
// point of construction rather than by a caller who might forget:
//
//  * a non-`const` invocation with a blank selector / blank notes / a duplicate
//    selector throws an `AssertionError` at run time;
//  * a **`const` invocation** with a blank string is a **compile-time** error, because
//    a `const` constructor's initializers are evaluated by the compiler.
//
// ⚠️ **`removableSelectors.toSet()` is deliberately NOT in an initializer assert.**
// `toSet()` is a method call, and a method call is not a constant expression, so
// putting it there makes the whole class un-`const` and every `const` use of it a
// compile error. The duplicate check therefore lives on the class as a static method
// ([assertNoDuplicateSelectors]) which the test calls — see the note there. This is
// the one place `0-4`'s § 3.5 listing could not be delivered literally, and the reason
// is the language, not the intent.
//
// ## The classification table is NOT in this file
//
// `0-4` § 3.6: the full per-element classification lives in
// `18-external-contracts.md` § FanMTL "Content vs furniture", where a reader can
// compare each row against a real page. This file carries the types that table is made
// of ([ClassifiedElement], [ElementVerdict]) and the FanMTL policy value — a constant
// every source is reviewable against, which is why `2-1` instantiates it rather than
// re-deriving it.

import 'package:html/dom.dart';

/// What part of a chapter page is the prose, and what must never reach the reader.
///
/// `04-html-to-markdown.md` rule 2 — cleaning is per source; this is one source's
/// answer, as data.
final class ChapterContentPolicy {
  const ChapterContentPolicy({
    required this.sourceId,
    required this.contentSelector,
    required this.removableSelectors,
    required this.paragraphRule,
    required this.notes,
  }) : assert(
         contentSelector != '',
         'B44: a content selector is not a way to select nothing',
       ),
       assert(
         notes != '',
         '18-external-contracts.md rule 1: no provenance, no entry',
       );

  /// The registry id of the source this policy belongs to. Never hand-written
  /// (`03-source-system.md` rule 1) — a source passes its own `id` straight through.
  final String sourceId;

  /// Selects the node whose subtree is the chapter's prose.
  ///
  /// **Exactly one** node per chapter page, or the policy is wrong: see
  /// [ChapterContentPolicy.selectContent], which returns `null` when the count is not
  /// one.
  ///
  /// For FanMTL this is `.chapter-content`, **not** `#chapter-article`
  /// (`18-external-contracts.md` quirk 2 — the latter wraps the page chrome).
  final String contentSelector;

  /// Nodes to drop **before** conversion, in this order.
  ///
  /// The cleaner walks these **inside the content node**, never against the whole page,
  /// so a selector cannot reach furniture outside the prose. An entry here must be
  /// exercisable: see [assertNoDuplicateSelectors] and the note on this field.
  final List<String> removableSelectors;

  /// How a paragraph break is recognised. Not a boolean, because the answer has three
  /// shapes rather than two and choosing wrongly turns a whole chapter into one
  /// run-on paragraph that still reads plausibly.
  final ParagraphRule paragraphRule;

  /// What the classification decided and **on what evidence** — the fixture keys it was
  /// read from. `18-external-contracts.md` rule 1: an entry without provenance is a
  /// guess with a confident tone.
  final String notes;

  /// The prose node for [document], or `null` when the container is absent.
  ///
  /// **`null` is the E4 signal and it is not an error.** The caller turns it into a
  /// failure with a retry (`architecture.md` § 5.2). It must never become an empty
  /// chapter: B22's whole point is that "no results" and "could not read" are
  /// different answers.
  ///
  /// ⚠️ **`null` when the selector matches MORE than one node too**, not only when it
  /// matches none. MEASURED 2026-10-05 on `chapter-prose`: `.chapter-content` matches
  /// exactly one, and an exact-match selector is what makes that checkable — Royal
  /// Road needs `.chapter-inner.chapter-content` for the same reason, because
  /// `div.chapter-content` matches zero there. Two matches means the site duplicated
  /// the container, and taking the first would silently drop half the chapter.
  Element? selectContent(Document document) {
    final List<Element> found = document.querySelectorAll(contentSelector);
    if (found.length != 1) return null;
    return found.single;
  }

  /// Refuses a [removableSelectors] list carrying the same selector twice.
  ///
  /// ⚠️ **A method and not an initializer assert, and the reason is the compiler.**
  /// `toSet()` is a method call, which is not a constant expression, so an initializer
  /// `assert` calling it would make this class un-`const` — every `const` policy would
  /// then fail to compile. The invariant is therefore checked here, once, by whoever
  /// builds a list, and [0-4]'s test asserts it on the FanMTL value.
  ///
  /// The invariant exists because `0-4` § 3.2 calls out the exact mistake: listing
  /// `aside` twice is harmless at run time and fatal at review, because a list with a
  /// duplicate can no longer be justified entry by entry.
  static void assertNoDuplicateSelectors(List<String> selectors) {
    assert(
      selectors.toSet().length == selectors.length,
      'a duplicate in removableSelectors is a list that cannot be justified '
      'entry by entry',
    );
  }

  @override
  String toString() =>
      'ChapterContentPolicy($sourceId, content: $contentSelector, '
      'remove: $removableSelectors, paragraphs: ${paragraphRule.name})';
}

/// How paragraphs are delimited in a source's chapter HTML.
///
/// The distinction is load-bearing. `04-html-to-markdown.md` states it as a required
/// behaviour with its own reason: a converter that only knows `<p>` renders an entire
/// chapter as one run-on paragraph **and still looks plausible in a smoke test**.
enum ParagraphRule {
  /// `<p>` elements only.
  pElementsOnly,

  /// A bare text node delimited by **two consecutive `<br>`** is a paragraph; a single
  /// `<br>` is a line break. MEASURED on `chapter-prose` (see `ParagraphRule.decide`).
  brBrDelimitedText,

  /// Both, applied in that precedence: `<p>` first, then `br br` on what is left.
  /// Correct for a site that mixes the two, and the default when a source has not been
  /// classified.
  pThenBrBr;

  /// The rule a chapter page's own markup implies, from two measurements.
  ///
  /// ⚠️ **`pCount` counts `<p>` elements that hold visible text.** MEASURED 2026-10-05:
  /// `chapter-prose` parses to **one** `<p>` element and it is **empty** — the site's
  /// prose is bare text separated by `<br><br>`, and it closes the last run with a
  /// stray `</p>`, which `package:html` turns into an empty `<p>`. Counting elements
  /// rather than paragraphs would read that page as `<p>`-delimited and pick the wrong
  /// rule for the one page in the capture that has no `<p>` at all.
  ///
  /// | observation | rule |
  /// |---|---|
  /// | no paragraph `<p>`, at least one `<br><br>` run | [brBrDelimitedText] |
  /// | paragraph `<p>`, no `<br><br>` run | [pElementsOnly] |
  /// | both | [pThenBrBr] — `<p>` first, then `br br` on the rest |
  /// | neither | [pThenBrBr] **and** the classification carries an INDETERMINATE row |
  ///
  /// The last row is E4, not "a source without paragraphs": a page with no `<p>` and
  /// no `<br><br>` has no paragraph structure at all, which is what a changed template
  /// looks like.
  static ParagraphRule decide({
    required int paragraphElementCount,
    required int brBrRunCount,
  }) {
    if (paragraphElementCount == 0 && brBrRunCount > 0) {
      return brBrDelimitedText;
    }
    if (paragraphElementCount > 0 && brBrRunCount == 0) {
      return pElementsOnly;
    }
    return pThenBrBr;
  }
}

/// One element of a chapter page, and what was decided about it.
///
/// The third verdict is the reason this is an enum with three values and not a
/// boolean: an element nobody could classify is **neither** removed **nor** kept as
/// prose, and a two-valued type cannot say so.
enum ElementVerdict {
  /// Prose. It reaches the reader.
  content,

  /// Furniture. It must not reach the reader.
  furniture,

  /// Undecided, and **left undecided on purpose**.
  ///
  /// `0-4` § 3.4: an element whose nature cannot be determined without reading it — a
  /// decorative `<img>`, a link whose text is a chapter title — stays here. Deciding it
  /// without evidence would be an invention, and this slice has no licence to invent.
  indeterminate,
}

/// One row of the classification table `0-4` produces.
///
/// The table itself is documentation (`18-external-contracts.md` § FanMTL "Content vs
/// furniture"); this is the shape a row has, so a row cannot be written without saying
/// what it is and which capture it came from.
final class ClassifiedElement {
  const ClassifiedElement({
    required this.selector,
    required this.verdict,
    required this.reason,
    required this.evidenceKey,
  });

  /// A CSS selector matching this element **and nothing else** on the page. A selector
  /// matching two elements is not a classification of an element; it is a
  /// classification of a coincidence.
  final String selector;

  final ElementVerdict verdict;

  /// Why, in one sentence, in terms a re-capture can check. A description of the
  /// observation, not a justification of taste.
  final String reason;

  /// The manifest key of the fixture this was read from. Never empty: an element
  /// classified from memory is a guess.
  final String evidenceKey;

  /// Whether this element is furniture. Convenience for the table's own reader; the
  /// authoritative comparison is against [ElementVerdict].
  bool get isFurniture => verdict == ElementVerdict.furniture;

  @override
  String toString() =>
      'ClassifiedElement($selector, ${verdict.name}, evidence: $evidenceKey)';
}
