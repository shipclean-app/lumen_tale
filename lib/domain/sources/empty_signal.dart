// Lumen Tale — does this site publish its own "there is nothing here"?
//
// `0-2`, the slice that discharges `roadmap.md` § 7.2 item 2. B22 makes the
// site's own explicit empty-result signal the discriminator between *nothing* and
// *could not read*, so before a single source is written someone has to go and look
// at whether the signal exists.
//
// ⚠️ **This is a measurement, delivered as code, and it is in `lib/` on purpose.**
// `0-2` § 4 says so: the file would otherwise be a script in `test/` that nobody
// re-runs, and the verdict in `empty-signal.json` would be a hand-written claim
// about pages nobody looked at again. `flutter analyze` covers it, and the guard
// test in `test/domain/sources/empty_signal_test.dart` re-derives the verdict from
// the frozen fixtures on every run.
//
// Pure Dart: `domain` carries zero Flutter imports (`02-architecture.md`), which is
// what lets this run with no widget binding.

import 'package:html/dom.dart';
import 'package:html/parser.dart' show parse;

/// What a page carries about "there is genuinely nothing here".
///
/// B22's three-state world exists only where the site supplies the signal. This
/// enum is what decides whether it can for a given site, and it is measured rather
/// than assumed.
enum EmptySignalVerdict {
  /// The literal appears in the visible text of a page the site serves as a
  /// failure page, and does not appear on any page the site serves as a populated
  /// result. Three states are available — for the calls that can reach that page,
  /// and only those.
  signalOnFailurePageOnly,

  /// The literal appears on pages the site serves as **populated browse results**.
  /// Three states are available everywhere, which would be a stronger site than
  /// either one measured so far is.
  signalOnResultPage,

  /// The literal appears nowhere in the fixtures. Two states only, and B22 as
  /// written is not implementable for this source.
  absent,

  /// The literal appears in more than one kind of page, or only inside a
  /// `<script>` / `<style>` / `<title>` / comment. **Never resolved by guessing** —
  /// an ambiguous signal would make `BrowseEmpty` fire on pages where it means the
  /// opposite.
  ambiguous,
}

/// The page kinds a fixture set can hold. Only three, because only three matter to
/// B22's discriminator.
enum PageKind { resultPage, failurePage, neutralPage }

/// One measurement over one page. Pure Dart, four fields, no state.
final class EmptySignalProbe {
  const EmptySignalProbe({required this.literals});

  /// The exact strings the site is claimed to publish.
  ///
  /// Never patterns. A pattern also matches prose occurrences of the same words,
  /// and a signal that matches "no novels here in this paragraph" is not a signal —
  /// it is a coincidence. § 2.1.
  final List<String> literals;

  /// Measures one fixture.
  ///
  /// [kind] is what the **manifest** says the page is, never what this probe infers:
  /// a page's role is a site fact observed at capture time, and a probe that
  /// re-derived the role from the page it is judging would be judging its own
  /// hypothesis. The parameter is therefore **deliberately unused here** — it stays
  /// in the signature because `EmptySignalVerdict` needs it, and saying so is
  /// cheaper than an implementer "fixing" it by computing something.
  PageOccurrence measure(String html, PageKind kind) {
    final Document document = parse(html);
    final Element? body = document.body;
    if (body == null) {
      // A document with no <body> cannot carry a reader-visible signal. It is still
      // a measurement: "we could not look" and "it is not there" are different
      // answers, and B22 lives on that difference.
      return const PageOccurrence(
        visible: false,
        visibleText: '',
        visibleHits: <String, int>{},
        rawHits: <String, int>{},
      );
    }

    final String visible = visibleTextOf(body);
    final String raw = collapseWhitespace(document.outerHtml);
    return PageOccurrence(
      visible: true,
      visibleText: visible,
      visibleHits: _countAll(raw: visible),
      rawHits: _countAll(raw: raw),
    );
  }

  /// The text a reader would see: text nodes only, skipping the elements that carry
  /// text no reader sees.
  ///
  /// ⚠️ `Element.text` is **not** this. In `package:html` a `<script>`'s body is
  /// parsed into an ordinary `Text` child, so `body.text` returns JavaScript. A
  /// string found there could never be shown to the reader, and C12 requires a
  /// failure message that can be read aloud to someone who has to describe it.
  static String visibleTextOf(Element element) {
    final StringBuffer out = StringBuffer();
    _collectVisible(element, out);
    return collapseWhitespace(out.toString());
  }

  static void _collectVisible(Node node, StringBuffer out) {
    for (final Node child in node.nodes) {
      if (child.nodeType == Node.TEXT_NODE) {
        out.write((child as Text).data);
        continue;
      }
      if (child.nodeType != Node.ELEMENT_NODE) {
        // Comments, doctypes, processing instructions. A string inside a comment is
        // not a message to the reader.
        continue;
      }
      final String? name = (child as Element).localName;
      if (name != null && kInvisibleElements.contains(name)) continue;
      _collectVisible(child, out);
    }
  }

  static String collapseWhitespace(String input) =>
      input.replaceAll(RegExp(r'\s+'), ' ').trim();

  Map<String, int> _countAll({required String raw}) {
    final Map<String, int> counts = <String, int>{};
    for (final String literal in literals) {
      final String needle = collapseWhitespace(literal);
      if (needle.isEmpty) {
        counts[literal] = 0;
        continue;
      }
      int count = 0;
      int from = raw.indexOf(needle);
      while (from >= 0) {
        count++;
        // +1, not +needle.length: a zero-length needle would loop forever, and the
        // empty literal is refused above rather than defended against here.
        from = raw.indexOf(needle, from + needle.length);
      }
      counts[literal] = count;
    }
    return counts;
  }
}

/// The elements whose text no reader sees. Public because a test needs to assert the
/// set has not quietly shrunk — a dropped entry turns a script into a signal.
const Set<String> kInvisibleElements = <String>{
  'script',
  'style',
  'noscript',
  'title',
  'template',
  'svg',
  'head',
};

/// What one page carried.
final class PageOccurrence {
  const PageOccurrence({
    required this.visible,
    required this.visibleText,
    required this.visibleHits,
    required this.rawHits,
  });

  /// `false` when the document has no `<body>` — nothing could be looked at.
  /// **Never** conflated with an absence.
  final bool visible;
  final String visibleText;

  /// Literal → occurrences in what a reader would see.
  final Map<String, int> visibleHits;

  /// Literal → occurrences in the raw serialised document, scripts, styles, titles
  /// and comments included. Kept because "it is in the page twice, once in a
  /// script" is a fact worth keeping, and because the difference between the two
  /// maps is exactly what catches a false positive.
  final Map<String, int> rawHits;

  /// True only for a literal a reader could actually be shown.
  bool carries(String literal) => (visibleHits[literal] ?? 0) > 0;

  /// True when the literal is in the page but nowhere a reader would see it — the
  /// false-positive shape, and the one that must force `ambiguous` rather than a
  /// signal.
  bool hiddenOnly(String literal) =>
      (rawHits[literal] ?? 0) > 0 && (visibleHits[literal] ?? 0) == 0;

  /// True when the literal is in the page at all, visible or not.
  ///
  /// ⚠️ **This is `rawHits > 0 || visibleHits > 0`, not `rawHits > 0`**, and the
  /// reason was measured rather than reasoned: Royal Road's 404 page carries the
  /// visible text `404 Page Not Found`, and `404 Page Not Found` is **not** a
  /// substring of the serialised document — `<h1>404</h1><h1>Page Not Found</h1>`
  /// has tags where the reader has a space. So a literal may be displayable and not
  /// raw-present, and the first version of `verdict()` gated on `rawHits` and
  /// therefore reported `absent` for a page carrying a visible signal. Two methods
  /// of one class answering differently about the same page is the defect; the
  /// narrow test is what caused it.
  bool isPresent(String literal) =>
      (rawHits[literal] ?? 0) > 0 || (visibleHits[literal] ?? 0) > 0;
}

/// The recorded measurement of one site. This is the shape written to
/// `<site>/empty-signal.json`, and [EmptySignalRecord.rederive] recomputes it from
/// the fixtures so the file cannot drift away from them.
final class EmptySignalRecord {
  const EmptySignalRecord({
    required this.site,
    required this.measuredBy,
    required this.measuredAt,
    required this.verdict,
    required this.signals,
    required this.notes,
  });

  /// The fixture folder name.
  final String site;

  /// The slice that took the measurement. Never reassigned — a measurement belongs
  /// to the slice that made it.
  final String measuredBy;

  /// ISO 8601 UTC. `18-external-contracts.md` rule 1 — provenance.
  final String measuredAt;

  final EmptySignalVerdict verdict;

  /// One entry per literal. Never a pattern.
  final List<SignalRecord> signals;

  /// The consequence `failure-discriminator` and `3-1` must respect, in one sentence.
  final String notes;

  /// **Derived from [verdict], never typed.** It is the number
  /// `failure-discriminator` and `3-1` need, and a hand-typed copy is free to
  /// disagree with the verdict beside it.
  int get statesAvailable => switch (verdict) {
    EmptySignalVerdict.signalOnFailurePageOnly => 3,
    EmptySignalVerdict.signalOnResultPage => 3,
    EmptySignalVerdict.absent => 2,
    EmptySignalVerdict.ambiguous => 2,
  };

  /// The call kinds for which `BrowseEmpty` is available.
  ///
  /// ⚠️ **Derived from [verdict] alone, and this is the measured half of B22's
  /// limitation.** A `signalOnFailurePageOnly` site discriminates only on the calls
  /// that can reach its failure page. Browsing a catalogue that legitimately has
  /// zero rows has **two** states, not three, and `3-1` has to say so out loud
  /// rather than render "no results" over a suspected break.
  List<String> get appliesTo => switch (verdict) {
    EmptySignalVerdict.signalOnResultPage => const <String>[
      'genreBrowse',
      'catalogueBrowse',
      'search',
      'novelDetails',
      'chapterContent',
    ],
    // Measured on Royal Road 2026-10-03: the one literal the site publishes lives on
    // its 404 page, which is served for an unknown path — a search miss, a fiction
    // id that is gone, a chapter that no longer exists. It says nothing about a
    // catalogue page that simply holds no rows.
    EmptySignalVerdict.signalOnFailurePageOnly => const <String>[
      'search',
      'novelDetails',
      'chapterContent',
    ],
    EmptySignalVerdict.absent => const <String>[],
    EmptySignalVerdict.ambiguous => const <String>[],
  };

  /// The call kinds for which it is **not**. The most important field in the file:
  /// it is what stops a zero-row catalogue page from being rendered as "no results".
  ///
  /// Derived as the complement of [appliesTo] over the same closed set, never typed
  /// separately — two hand-written lists that must stay in step are two lists that
  /// will not.
  List<String> get doesNotApplyTo => const <String>[
    'genreBrowse',
    'catalogueBrowse',
    'search',
    'novelDetails',
    'chapterContent',
  ].where((String kind) => !appliesTo.contains(kind)).toList(growable: false);
}

/// One literal, and the evidence for or against it.
final class SignalRecord {
  const SignalRecord({
    required this.literal,
    required this.foundInFixtures,
    required this.absentFromFixtures,
    required this.visibleText,
    required this.insideScriptOrComment,
  });

  /// The string, exactly as the site writes it.
  final String literal;

  /// Fixture keys where it was found in visible text. **Must be non-empty**: a
  /// string with no evidence is not a signal, it is a guess.
  final List<String> foundInFixtures;

  /// Fixture keys where it was looked for and not found. The half that prevents a
  /// false positive.
  final List<String> absentFromFixtures;

  /// `true` if the string is in a reader's visible text. `false` ⇒ it is not a
  /// displayable signal and the entry is rejected by the guard.
  final bool visibleText;

  /// Deliberate redundancy with [visibleText]: this is what makes the false positive
  /// visible to a human rereading the file.
  final bool insideScriptOrComment;
}

/// Turns per-page measurements into a verdict. The five exits of `0-2` § 3.2.
final class EmptySignalVerifier {
  const EmptySignalVerifier();

  /// Decides the verdict for a whole fixture set, **not** file by file.
  ///
  /// [pages] is the fixture set with each page's role taken from the manifest.
  EmptySignalVerdict verdict(List<MeasuredPage> pages) {
    bool carriesOn(PageOccurrence occurrence, bool Function(String) test) =>
        occurrence.rawHits.keys.any(
          (String literal) => occurrence.visible && test(literal),
        );

    final bool anywherePresent = pages.any(
      (MeasuredPage p) => carriesOn(p.occurrence, p.occurrence.isPresent),
    );

    if (!anywherePresent) {
      // § 3.2 A1 — the literal is nowhere at all. Two states only, and B22 as
      // written is not implementable for this source. `roadmap.md` § 7.2 item 2.
      return EmptySignalVerdict.absent;
    }

    final bool displayableAnywhere = pages.any(
      (MeasuredPage p) => carriesOn(p.occurrence, p.occurrence.carries),
    );

    if (!displayableAnywhere) {
      // § 3.2 A2 — in the page, nowhere a reader would see it. "It is in the page"
      // is NOT "it is said to the reader", and counting it as a signal is exactly
      // the confusion that makes a broken site render "no results".
      return EmptySignalVerdict.ambiguous;
    }

    // A literal that is displayable somewhere AND hidden-only elsewhere is a
    // **double emission** (§ 3.2's fifth case): recorded, and it does not make the
    // verdict ambiguous, because the site really does say this to a reader.
    final bool onResultPage = pages.any(
      (MeasuredPage p) =>
          p.kind == PageKind.resultPage &&
          carriesOn(p.occurrence, p.occurrence.carries),
    );

    // § 3.2 B2 / B3. `neutralPage` deliberately decides nothing: a home page that
    // happens to hold the string is not evidence about result pages.
    return onResultPage
        ? EmptySignalVerdict.signalOnResultPage
        : EmptySignalVerdict.signalOnFailurePageOnly;
  }
}

/// One page, its role as the manifest declared it, and what the probe found.
final class MeasuredPage {
  const MeasuredPage({
    required this.key,
    required this.kind,
    required this.occurrence,
  });

  /// The manifest key, so a verdict can name its own evidence.
  final String key;
  final PageKind kind;
  final PageOccurrence occurrence;
}
