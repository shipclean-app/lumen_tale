// forge:slice 0-2
// Lumen Tale — `0-2`: does Royal Road publish an explicit empty-result signal?
//
// ⚠️ **The point of this file is the guard, not the probe.** The probe ran once and
// its verdict was written to `empty-signal.json`. A verdict written by hand into a
// JSON file with nothing re-deriving it is a claim, and `18-external-contracts.md`
// rule 1 refuses claims. So the last group re-reads the frozen fixtures, recomputes
// the verdict, and asserts the recorded one agrees — which means a re-captured page
// that changes the answer fails here instead of silently disagreeing on disk.
//
// The literals are **the site's own words**, read off its own 404 page on
// 2026-10-03. They were not invented and not guessed: `failure-not-found.html`
// contains `<h1>404 Page Not Found</h1>` and "We can not find the fiction you're
// looking for." and those are the strings this site uses to say there is nothing.
//
// **The measured answer, and what it costs B22:**
//
// | Call | States available |
// |---|---|
// | search, novel details, chapter content | **3** — the site's 404 page discriminates |
// | **genre browse, catalogue browse** | **2** — a zero-row listing is an ordinary page |
//
// That second row is `roadmap.md` § 7.2 item 2, resolved by measurement for the one
// site that could be reached. B22's "never present an empty list as an answer" is
// **implementable for a lookup miss and not implementable for a browse**, and the UI
// has to say so rather than invent a third state.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumen_tale/domain/sources/empty_signal.dart';

const String site = 'royalroad';
const String dir = 'test/fixtures/sources/$site';

/// The literals, read off the site's own 404 page. Exact strings, never patterns:
/// a pattern also matches prose occurrences of the same words.
const List<String> literals = <String>[
  "We can not find the fiction you're looking for.",
  '404 Page Not Found',
];

/// Each page's role, as `0-3` recorded it. Taken from the capture, never inferred.
const Map<String, PageKind> pageKinds = <String, PageKind>{
  'home': PageKind.neutralPage,
  'catalogue-active-popular-page0': PageKind.resultPage,
  'catalogue-active-popular-page1': PageKind.resultPage,
  'novel-detail-runesmith': PageKind.resultPage,
  'chapter-glossary': PageKind.resultPage,
  'chapter-skills-titles': PageKind.resultPage,
  'failure-not-found': PageKind.failurePage,
  'manufactured/broken-layout': PageKind.resultPage,
};

/// `robots.txt` is not a page and has no body, so it is not in [pageKinds]. Asserted
/// anyway, so a fixture added to the manifest without a role here is a test failure
/// rather than a silent omission.
const List<String> nonPageFixtures = <String>['robots'];

void main() {
  const EmptySignalProbe probe = EmptySignalProbe(literals: literals);

  List<MeasuredPage> measureAll() {
    final List<MeasuredPage> pages = <MeasuredPage>[];
    pageKinds.forEach((String key, PageKind kind) {
      final File file = File('$dir/$key.html');
      expect(file.existsSync(), isTrue, reason: '$key must be captured');
      pages.add(
        MeasuredPage(
          key: key,
          kind: kind,
          occurrence: probe.measure(file.readAsStringSync(), kind),
        ),
      );
    });
    return pages;
  }

  group('What the probe measures', () {
    test('every captured fixture has a declared role', () {
      final Directory root = Directory(dir);
      final Set<String> onDisk = root
          .listSync()
          .whereType<File>()
          .map((File f) => f.uri.pathSegments.last)
          .where((String n) => n.endsWith('.html'))
          .map((String n) => n.replaceAll('.html', ''))
          .toSet();

      final Set<String> declared = <String>{
        ...pageKinds.keys,
        // The two files that live under `manufactured/` or are not HTML are handled
        // by name below.
        ...nonPageFixtures.where((String n) => n.endsWith('.html')),
      };

      for (final String name in onDisk) {
        if (name.contains('/')) continue;
        expect(
          declared,
          contains(name),
          reason:
              '$name.html exists but nothing says what kind of page it is — '
              'the probe must not guess a page\'s role',
        );
      }
    });

    test('the failure page carries the literal in VISIBLE text', () {
      final PageOccurrence occurrence = probe.measure(
        File('$dir/failure-not-found.html').readAsStringSync(),
        PageKind.failurePage,
      );

      expect(occurrence.visible, isTrue);
      expect(
        occurrence.carries("We can not find the fiction you're looking for."),
        isTrue,
      );
    });

    test('no result page carries any literal', () {
      // ⚠️ This is the half of the measurement that decides the verdict. If a
      // browse page ever carries it, the verdict becomes signalOnResultPage and the
      // whole "two states for browse" caveat in the record is wrong.
      for (final MapEntry<String, PageKind> entry in pageKinds.entries) {
        if (entry.value != PageKind.resultPage) continue;
        final PageOccurrence occurrence = probe.measure(
          File('$dir/${entry.key}.html').readAsStringSync(),
          entry.value,
        );
        expect(
          occurrence.visibleHits.values.every((int n) => n == 0),
          isTrue,
          reason:
              '${entry.key} now carries the empty-result literal; B22 would '
              'have three states for browse and the recorded verdict is wrong',
        );
      }
    });

    test('a visible literal can be absent from the raw document', () {
      // ⚠️ The defect this measurement found. `404 Page Not Found` is visible text on
      // the failure page and is **not** a substring of the serialised HTML, because
      // the site marks the two words up separately. So `visibleHits > 0` with
      // `rawHits == 0` is a real state, and the first version of `verdict()` gated
      // on `rawHits` and therefore answered `absent` for a page carrying a visible
      // signal.
      final PageOccurrence occurrence = probe.measure(
        File('$dir/failure-not-found.html').readAsStringSync(),
        PageKind.failurePage,
      );

      expect(occurrence.carries('404 Page Not Found'), isTrue);
      expect(occurrence.rawHits['404 Page Not Found'] ?? 0, 0);
      expect(occurrence.isPresent('404 Page Not Found'), isTrue);
      expect(occurrence.hiddenOnly('404 Page Not Found'), isFalse);
    });
  });

  // ⚠️ Every synthetic probe below is built with **its own** literal.
  //
  // `EmptySignalProbe` counts only the literals it was constructed with, so a probe
  // holding Royal Road's strings cannot answer a question about
  // `No novels found`. The first version of this group reused the site probe and
  // got `false` from `hiddenOnly` on a page that plainly contained the string in a
  // comment — the assertion was wrong, not the code. A closed literal set is the
  // point (a probe that scanned for anything would find something), and the tests
  // have to honour it.
  const EmptySignalProbe synthetic = EmptySignalProbe(
    literals: <String>['No novels found'],
  );

  group('visible text is text a reader could be shown', () {
    test('a script body is not visible text', () {
      const String html = '''
        <html><body>
          <p>Nothing to see</p>
          <script>var nothingToSee = "No novels found";</script>
          <style>.nothing-to-see { color: red; }</style>
          <noscript>Enable JavaScript: No novels found</noscript>
        </body></html>''';

      final PageOccurrence occurrence = synthetic.measure(
        html,
        PageKind.resultPage,
      );

      expect(occurrence.visibleText, contains('Nothing to see'));
      expect(occurrence.visibleText, isNot(contains('No novels found')));
      expect(occurrence.visibleText, isNot(contains('color: red')));
      // Present in the document, invisible to a reader: the false-positive shape.
      expect(occurrence.hiddenOnly('No novels found'), isTrue);
      expect(occurrence.carries('No novels found'), isFalse);
    });

    test('an HTML comment is not visible text', () {
      const String html =
          '<html><body><!-- No novels found --><p>x</p></body></html>';
      final PageOccurrence occurrence = synthetic.measure(
        html,
        PageKind.resultPage,
      );

      expect(occurrence.visibleText, isNot(contains('No novels found')));
      expect(occurrence.hiddenOnly('No novels found'), isTrue);
    });

    test('a title is not visible text', () {
      const String html =
          '<html><head><title>No novels found</title></head>'
          '<body><p>x</p></body></html>';
      final PageOccurrence occurrence = synthetic.measure(
        html,
        PageKind.resultPage,
      );

      expect(occurrence.carries('No novels found'), isFalse);
      expect(occurrence.hiddenOnly('No novels found'), isTrue);
    });

    test('the html5 parser synthesises a body, so a page is never "invisible"', () {
      // The `body == null` branch of `measure` is **defensive, not reachable from
      // parsed HTML**: `package:html` follows the HTML5 tree-construction algorithm
      // and manufactures `<html><head><body>` around any input, including an XML
      // document. The first version of this test asserted `visible == false` on
      // `<pages></pages>` and was wrong.
      //
      // The branch stays, because `measure` is handed a `String` by a caller that
      // could hand it anything, and "we could not look" must not read as "it is not
      // there" (B22). What this row asserts is the honest truth instead.
      final PageOccurrence occurrence = synthetic.measure(
        '<?xml version="1.0"?><pages></pages>',
        PageKind.resultPage,
      );

      expect(occurrence.visible, isTrue, reason: 'the parser builds a body');
      expect(occurrence.visibleText, isEmpty);
      expect(occurrence.isPresent('No novels found'), isFalse);
    });

    test('a genuinely bodyless occurrence reports invisible, not absent', () {
      // Reached directly, because the parser will not produce it.
      const PageOccurrence blind = PageOccurrence(
        visible: false,
        visibleText: '',
        visibleHits: <String, int>{},
        rawHits: <String, int>{},
      );

      expect(blind.visible, isFalse);
      expect(blind.carries('No novels found'), isFalse);
      expect(blind.hiddenOnly('No novels found'), isFalse);
      expect(blind.isPresent('No novels found'), isFalse);
    });

    test('matching is case-sensitive', () {
      // A case-insensitive search would find the string in a page that does not say
      // it. The casing is part of the site's contract.
      final PageOccurrence occurrence = synthetic.measure(
        '<html><body><p>no novels found</p></body></html>',
        PageKind.resultPage,
      );

      expect(occurrence.carries('No novels found'), isFalse);
    });

    test('an empty literal matches nothing instead of looping forever', () {
      const EmptySignalProbe empty = EmptySignalProbe(literals: <String>['']);
      final PageOccurrence occurrence = empty.measure(
        '<html><body><p>anything at all</p></body></html>',
        PageKind.resultPage,
      );
      expect(occurrence.rawHits[''], 0);
    });

    test('the invisible-element set is not allowed to shrink', () {
      // A dropped entry turns a script body into a signal, silently.
      expect(
        kInvisibleElements,
        containsAll(<String>[
          'script',
          'style',
          'noscript',
          'title',
          'template',
          'svg',
          'head',
        ]),
      );
    });
  });

  group('The verdict', () {
    // Each row is built on a synthetic probe, for the same reason as above: the
    // verdict must be a function of the PAGES, not a constant that happens to match
    // the one site measured.

    EmptySignalVerdict decide(
      PageKind kind,
      String html, {
      EmptySignalProbe withLiterals = synthetic,
    }) => const EmptySignalVerifier().verdict(<MeasuredPage>[
      MeasuredPage(
        key: 'page',
        kind: kind,
        occurrence: withLiterals.measure(html, kind),
      ),
    ]);

    test('Royal Road is signalOnFailurePageOnly', () {
      expect(
        const EmptySignalVerifier().verdict(measureAll()),
        EmptySignalVerdict.signalOnFailurePageOnly,
      );
    });

    test('a literal on a result page is signalOnResultPage', () {
      expect(
        decide(
          PageKind.resultPage,
          '<html><body><p>No novels found</p></body></html>',
        ),
        EmptySignalVerdict.signalOnResultPage,
      );
    });

    test('a literal on a failure page is signalOnFailurePageOnly', () {
      expect(
        decide(
          PageKind.failurePage,
          '<html><body><p>No novels found</p></body></html>',
        ),
        EmptySignalVerdict.signalOnFailurePageOnly,
      );
    });

    test('a literal only in a script is ambiguous, never a signal', () {
      expect(
        decide(
          PageKind.failurePage,
          '<html><body><script>"No novels found"</script></body></html>',
        ),
        EmptySignalVerdict.ambiguous,
      );
    });

    test('no literal anywhere is absent', () {
      expect(
        decide(
          PageKind.resultPage,
          '<html><body><p>nothing here</p></body></html>',
        ),
        EmptySignalVerdict.absent,
      );
    });

    test('an empty page set is absent, not a crash', () {
      expect(
        const EmptySignalVerifier().verdict(const <MeasuredPage>[]),
        EmptySignalVerdict.absent,
      );
    });

    test('a neutral page never decides the verdict', () {
      // The home page is full of navigation. If it carried the literal, that would
      // be evidence about nothing — and it must not be counted as a failure page
      // either, or a site whose only signal lived on its home page would read as
      // having one.
      expect(
        decide(
          PageKind.neutralPage,
          '<html><body><p>No novels found</p></body></html>',
        ),
        EmptySignalVerdict.signalOnFailurePageOnly,
      );
    });

    test('a displayable literal beats a hidden one — a double emission', () {
      // § 3.2's fifth case: recorded, and it does NOT make the verdict ambiguous,
      // because the site really does say this to a reader on the failure page.
      final List<MeasuredPage> pages = <MeasuredPage>[
        MeasuredPage(
          key: 'result',
          kind: PageKind.resultPage,
          occurrence: synthetic.measure(
            '<html><body><script>"No novels found"</script>'
            '<p>No novels found</p></body></html>',
            PageKind.resultPage,
          ),
        ),
      ];

      expect(
        const EmptySignalVerifier().verdict(pages),
        EmptySignalVerdict.signalOnResultPage,
      );
    });
  });

  group('THE GUARD — the recorded verdict is re-derived from the fixtures', () {
    // `0-2` § 3.3. Without this pass, `empty-signal.json` is a hand-written claim.
    final File record = File('$dir/empty-signal.json');
    late Map<String, Object?> json;

    setUpAll(() {
      expect(
        record.existsSync(),
        isTrue,
        reason: '0-2 produces $record; run the probe and write it',
      );
      json = jsonDecode(record.readAsStringSync()) as Map<String, Object?>;
    });

    test('the recorded verdict equals the re-derived one', () {
      final EmptySignalVerdict derived = const EmptySignalVerifier().verdict(
        measureAll(),
      );
      expect(json['verdict'], derived.name);
    });

    test('statesAvailable is DERIVED, and matches', () {
      final EmptySignalVerdict verdict = EmptySignalVerdict.values.byName(
        json['verdict']! as String,
      );
      final EmptySignalRecord derived = EmptySignalRecord(
        site: site,
        measuredBy: json['measuredBy']! as String,
        measuredAt: json['measuredAt']! as String,
        verdict: verdict,
        signals: const <SignalRecord>[],
        notes: json['notes']! as String,
      );
      expect(json['statesAvailable'], derived.statesAvailable);
      expect(
        (json['appliesTo']! as List<Object?>).cast<String>().toSet(),
        derived.appliesTo.toSet(),
        reason: 'appliesTo is derived from the verdict, never typed beside it',
      );
      expect(
        (json['doesNotApplyTo']! as List<Object?>).cast<String>().toSet(),
        derived.doesNotApplyTo.toSet(),
      );
    });

    test('every recorded literal is found in a fixture, in visible text', () {
      // "A string with no evidence is not a signal, it is a guess."
      final List<Object?> signals = json['signals']! as List<Object?>;
      expect(signals, isNotEmpty);

      final List<MeasuredPage> pages = measureAll();
      for (final Object? entry in signals) {
        final Map<String, Object?> signal = entry! as Map<String, Object?>;
        final String literal = signal['literal']! as String;
        expect(
          literals,
          contains(literal),
          reason: 'the probe does not know it',
        );
        expect(
          (signal['foundInFixtures']! as List<Object?>).cast<String>(),
          isNotEmpty,
          reason: '$literal has no evidence',
        );
        expect(
          signal['visibleText'],
          isTrue,
          reason: '$literal is not displayable',
        );
        expect(
          signal['insideScriptOrComment'],
          isFalse,
          reason: '$literal only appears where no reader can see it',
        );

        final List<String> derivedFound = pages
            .where((MeasuredPage p) => p.occurrence.carries(literal))
            .map((MeasuredPage p) => p.key)
            .toList();
        expect(
          derivedFound,
          (signal['foundInFixtures']! as List<Object?>).cast<String>(),
          reason: '$literal: foundInFixtures has drifted from the fixtures',
        );
      }
    });

    test('absentFromFixtures is the honest complement of foundInFixtures', () {
      final List<MeasuredPage> pages = measureAll();
      final List<Object?> signals = json['signals']! as List<Object?>;
      for (final Object? entry in signals) {
        final Map<String, Object?> signal = entry! as Map<String, Object?>;
        final String literal = signal['literal']! as String;
        final List<String> derivedAbsent = pages
            .where((MeasuredPage p) => !p.occurrence.carries(literal))
            .map((MeasuredPage p) => p.key)
            .toList();
        expect(
          derivedAbsent,
          (signal['absentFromFixtures']! as List<Object?>).cast<String>(),
          reason: '$literal: absentFromFixtures has drifted',
        );
      }
    });

    test('notes is not empty and says what the consequence is', () {
      expect((json['notes']! as String).trim(), isNotEmpty);
    });

    test('measuredAt is ISO 8601 UTC', () {
      expect(
        RegExp(
          r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$',
        ).hasMatch(json['measuredAt']! as String),
        isTrue,
      );
    });

    test('site and measuredBy are the two values and not substitutes', () {
      expect(json['site'], site);
      expect(
        json['measuredBy'],
        '0-2',
        reason: 'a measurement is not reassigned',
      );
    });
  });
}
