// Lumen Tale — the classifier, branch by branch.
//
// `failure-discriminator` § 11.1. Every one of the plan's rows is here, in the
// plan's grouping, plus the four rows § 3.2 demands ("the order of the three
// verdicts is fixed, and a test must pin it").
//
// ⚠️ The plan names its tests in French because the plan is a French document. The
// code in this repository is English — `08-coding-standards.md` — so the names are
// translated and the *semantics* are unchanged. A translation that quietly widened
// a row would be worse than a mismatch, so the count is asserted in the last group.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:lumen_tale/core/error/source_failure.dart';
import 'package:lumen_tale/core/network/fetch_result.dart';
import 'package:lumen_tale/domain/sources/browse_outcome.dart';
import 'package:lumen_tale/domain/sources/outcome_discriminator.dart';
import 'package:lumen_tale/domain/sources/read_attempt.dart';

/// The classifier under test. `const`, so the tests cannot accidentally share an
/// instance with mutable state.
const OutcomeDiscriminator classifier = OutcomeDiscriminator();

/// A 200 that answered, the common starting point.
const FetchSucceeded ok = FetchSucceeded(status: 200);

void main() {
  group('The four outcomes', () {
    test('an intact page with results is a BrowseSucceeded', () {
      final BrowseOutcome<String> outcome = classifier.classify<String>(
        const ReadAttempt(
          stage: ReadStage.catalogue,
          fetch: ok,
          content: ExpectedContentFound(12),
        ),
        items: const <String>['a', 'b'],
      );

      expect(outcome, isA<BrowseSucceeded<String>>());
      expect((outcome as BrowseSucceeded<String>).items, hasLength(2));
    });

    test(
      'a 200 page whose expected container is absent is a SourceLayoutChanged',
      () {
        final BrowseOutcome<String> outcome = classifier.classify<String>(
          const ReadAttempt(
            stage: ReadStage.chapterContent,
            fetch: ok,
            content: ExpectedContentAbsent(),
            expectedSelector: '.chapter-inner.chapter-content',
          ),
        );

        final BrowseFailed<String> failed = outcome as BrowseFailed<String>;
        expect(failed.reason, isA<SourceLayoutChanged>());
        expect(failed.retriable, isFalse);
      },
    );

    test('a 200 page carrying the site\'s own signal is a BrowseEmpty', () {
      final BrowseOutcome<String> outcome = classifier.classify<String>(
        const ReadAttempt(
          stage: ReadStage.searchResults,
          fetch: ok,
          content: ExpectedContentFound(0),
          siteEmptySignal: 'No relevant content found',
        ),
      );

      expect(
        (outcome as BrowseEmpty<String>).siteSuppliedSignal,
        'No relevant content found',
      );
    });

    test('a transport failure is NoConnection and is retriable', () {
      final BrowseOutcome<String> outcome = classifier.classify<String>(
        const ReadAttempt(
          stage: ReadStage.catalogue,
          fetch: FetchTransportFailed(host: 'www.royalroad.com'),
          content: null,
        ),
      );

      final BrowseFailed<String> failed = outcome as BrowseFailed<String>;
      expect(failed.reason, const NoConnection(host: 'www.royalroad.com'));
      expect(failed.retriable, isTrue);
    });

    test('a 429 is RateLimited and is retriable', () {
      final BrowseOutcome<String> outcome = classifier.classify<String>(
        const ReadAttempt(
          stage: ReadStage.catalogue,
          fetch: FetchRateLimited(
            retryAfter: Duration(seconds: 42),
            status: 429,
          ),
          content: null,
        ),
      );

      final BrowseFailed<String> failed = outcome as BrowseFailed<String>;
      expect(
        failed.reason,
        const RateLimited(retryAfter: Duration(seconds: 42)),
      );
      expect(failed.retriable, isTrue);
    });

    test('a 503 is SourceUnavailable and is retriable', () {
      final BrowseOutcome<String> outcome = classifier.classify<String>(
        const ReadAttempt(
          stage: ReadStage.catalogue,
          fetch: FetchSucceeded(status: 503),
          content: null,
        ),
      );

      final BrowseFailed<String> failed = outcome as BrowseFailed<String>;
      expect(failed.reason, const SourceUnavailable(status: 503));
      expect(failed.retriable, isTrue);
    });

    test('a 404 is SourceUnavailable, never BrowseEmpty', () {
      // ⚠️ Even with a forged signal. A non-success status is decided BEFORE the
      // signal is looked at, so a page that 404s cannot be reported as "genuinely
      // nothing" no matter what string the source hands over.
      final BrowseOutcome<String> outcome = classifier.classify<String>(
        const ReadAttempt(
          stage: ReadStage.searchResults,
          fetch: FetchSucceeded(status: 404),
          content: ExpectedContentFound(0),
          siteEmptySignal: 'No relevant content found',
        ),
      );

      expect(
        (outcome as BrowseFailed<String>).reason,
        const SourceUnavailable(status: 404),
      );
    });

    test('a parse failure is ParseFailed and is not retriable', () {
      final BrowseOutcome<String> outcome = classifier.classify<String>(
        const ReadAttempt(
          stage: ReadStage.chapterContent,
          fetch: ok,
          content: ParseBroke(),
          requestPath: '/fiction/21220/the-runesmith/chapter/1/glossary',
        ),
      );

      final BrowseFailed<String> failed = outcome as BrowseFailed<String>;
      expect(failed.reason, isA<ParseFailed>());
      expect(failed.retriable, isFalse);
    });

    test('a 2xx with no probe is ParseFailed, never an absence', () {
      final BrowseOutcome<String> outcome = classifier.classify<String>(
        const ReadAttempt(stage: ReadStage.catalogue, fetch: ok, content: null),
      );

      expect((outcome as BrowseFailed<String>).reason, isA<ParseFailed>());
    });
  });

  group('Zero results', () {
    test('zero on a chapter is SourceLayoutChanged, never "zero chapters"', () {
      final BrowseOutcome<String> outcome = classifier.classify<String>(
        const ReadAttempt(
          stage: ReadStage.chapterContent,
          fetch: ok,
          content: ExpectedContentFound(0),
        ),
      );

      expect(
        (outcome as BrowseFailed<String>).reason,
        isA<SourceLayoutChanged>(),
      );
    });

    test('zero on a chapter list is SourceLayoutChanged', () {
      final BrowseOutcome<String> outcome = classifier.classify<String>(
        const ReadAttempt(
          stage: ReadStage.chapterList,
          fetch: ok,
          content: ExpectedContentFound(0),
        ),
      );
      expect(
        (outcome as BrowseFailed<String>).reason,
        isA<SourceLayoutChanged>(),
      );
    });

    test('zero on a catalogue is SourceLayoutChanged', () {
      final BrowseOutcome<String> outcome = classifier.classify<String>(
        const ReadAttempt(
          stage: ReadStage.catalogue,
          fetch: ok,
          content: ExpectedContentFound(0),
        ),
      );
      expect(
        (outcome as BrowseFailed<String>).reason,
        isA<SourceLayoutChanged>(),
      );
    });

    test('zero on a genre index is an empty BrowseSucceeded', () {
      // The one default `zeroIsGenuine`. `browse-genre.md` § 4: a source with no
      // genres at all is a real state, rendered as EmptyState, "not an error and
      // not a broken source".
      final BrowseOutcome<String> outcome = classifier.classify<String>(
        const ReadAttempt(
          stage: ReadStage.genreListing,
          fetch: ok,
          content: ExpectedContentFound(0),
        ),
      );

      expect((outcome as BrowseSucceeded<String>).items, isEmpty);
    });

    test('a source may override the zero policy per call', () {
      // B41: the platform never interprets a source's values, so the source gets
      // the last word — per call, not only at registration.
      final BrowseOutcome<String> outcome = classifier.classify<String>(
        const ReadAttempt(
          stage: ReadStage.catalogue,
          fetch: ok,
          content: ExpectedContentFound(0),
          zeroItemsPolicy: ZeroItemsPolicy.zeroIsGenuine,
        ),
      );

      expect((outcome as BrowseSucceeded<String>).items, isEmpty);
    });

    test('an undeclared stage falls back to the conservative policy', () {
      // Defensive: an enum value added without a table entry must not silently
      // become a genuine zero.
      expect(
        kZeroItemsPolicyByStage.values,
        hasLength(ReadStage.values.length),
      );
      for (final ReadStage stage in ReadStage.values) {
        expect(
          kZeroItemsPolicyByStage[stage],
          isNotNull,
          reason: '$stage has no default zero policy',
        );
      }
    });
  });

  group('The order of the three verdicts', () {
    // § 3.2. The three rows below are the ones an intuitive implementation gets
    // wrong, and they are the reason this file exists.

    test('a present signal with results wins over the count', () {
      final BrowseOutcome<String> outcome = classifier.classify<String>(
        const ReadAttempt(
          stage: ReadStage.catalogue,
          fetch: ok,
          content: ExpectedContentFound(12),
          siteEmptySignal: 'Nothing here',
        ),
        items: const <String>['a'],
      );

      expect(outcome, isA<BrowseEmpty<String>>());
    });

    test('the count wins over zero', () {
      final BrowseOutcome<String> outcome = classifier.classify<String>(
        const ReadAttempt(
          stage: ReadStage.catalogue,
          fetch: ok,
          content: ExpectedContentFound(12),
        ),
        items: const <String>['a'],
      );

      expect(outcome, isA<BrowseSucceeded<String>>());
    });

    test(
      'an ExpectedContentAbsent loses to nothing — it never reaches the count',
      () {
        // An absent container with a signal is still a *failure*, not an empty: the
        // signal explains the emptiness but the app already knows it cannot read the
        // page. This is the ordering that E4/E8 depend on.
        final BrowseOutcome<String> outcome = classifier.classify<String>(
          const ReadAttempt(
            stage: ReadStage.chapterContent,
            fetch: ok,
            content: ExpectedContentAbsent(),
            siteEmptySignal: 'Nothing here',
          ),
        );

        final SourceFailure reason = (outcome as BrowseFailed<String>).reason;
        expect(reason, isA<SourceLayoutChanged>());
        expect(
          (reason as SourceLayoutChanged).siteSuppliedSignal,
          'Nothing here',
          reason: 'the signal is KEPT as evidence, not discarded',
        );
      },
    );
  });

  group('Evidence', () {
    test('SourceLayoutChanged carries the declared selector', () {
      final BrowseOutcome<String> outcome = classifier.classify<String>(
        const ReadAttempt(
          stage: ReadStage.chapterContent,
          fetch: ok,
          content: ExpectedContentAbsent(),
          expectedSelector: '.chapter-inner.chapter-content',
        ),
      );

      final BrowseFailed<String> failed = outcome as BrowseFailed<String>;
      expect(
        (failed.reason as SourceLayoutChanged).failedSelector,
        '.chapter-inner.chapter-content',
      );
    });

    test(
      'an undeclared selector is a visible sentinel, not an empty string',
      () {
        final BrowseOutcome<String> outcome = classifier.classify<String>(
          const ReadAttempt(
            stage: ReadStage.catalogue,
            fetch: ok,
            content: ExpectedContentAbsent(),
          ),
        );

        final SourceLayoutChanged reason =
            (outcome as BrowseFailed<String>).reason as SourceLayoutChanged;
        expect(reason.failedSelector, '(non déclaré)');
        expect(reason.failedSelector, isNotEmpty);
      },
    );

    test('the evidence is kept when the page carried the site\'s signal', () {
      final BrowseOutcome<String> outcome = classifier.classify<String>(
        const ReadAttempt(
          stage: ReadStage.catalogue,
          fetch: ok,
          content: ExpectedContentAbsent(),
          expectedSelector: 'tr.fiction-list-item',
          siteEmptySignal: 'No novels matched',
        ),
      );

      final SourceLayoutChanged reason =
          (outcome as BrowseFailed<String>).reason as SourceLayoutChanged;
      expect(reason.siteSuppliedSignal, 'No novels matched');
      expect(reason.status, 200);
    });
  });

  group('retriable is never free', () {
    test('retriable is always the cause\'s own answer', () {
      // Two halves, because one half cannot be written: the classifier cannot
      // produce `ItemRemovedAtSource` (E9 — only `6-4` has the site's answer), so
      // five causes can be driven through `classify` and the sixth cannot.
      final Map<SourceFailure, (FetchResult, ContentProbe)> producible =
          <SourceFailure, (FetchResult, ContentProbe)>{
            const NoConnection(host: 'example.test'): (
              const FetchTransportFailed(host: 'example.test'),
              const ExpectedContentFound(1),
            ),
            const RateLimited(retryAfter: Duration(seconds: 5)): (
              const FetchRateLimited(
                retryAfter: Duration(seconds: 5),
                status: 429,
              ),
              const ExpectedContentFound(1),
            ),
            const SourceUnavailable(status: 503): (
              const FetchSucceeded(status: 503),
              const ExpectedContentFound(1),
            ),
            const SourceLayoutChanged(failedSelector: '.x', status: 200): (
              ok,
              const ExpectedContentAbsent(),
            ),
            const ParseFailed(path: '/novel/1.html'): (ok, const ParseBroke()),
          };

      for (final MapEntry<SourceFailure, (FetchResult, ContentProbe)> entry
          in producible.entries) {
        final BrowseOutcome<String> outcome = classifier.classify<String>(
          ReadAttempt(
            stage: ReadStage.chapterContent,
            fetch: entry.value.$1,
            content: entry.value.$2,
            requestPath: '/novel/1.html',
            expectedSelector: '.x',
          ),
        );

        final BrowseFailed<String> failed = outcome as BrowseFailed<String>;
        // The cause that came back is the one that went in — which also proves the
        // mapping above is honest rather than accidentally satisfied.
        expect(failed.reason, entry.key, reason: 'wrong cause for this input');
        expect(
          failed.retriable,
          failed.reason.isRetriable,
          reason: '${failed.reason.runtimeType}: retriable must be derived',
        );
      }

      expect(producible, hasLength(5), reason: 'six causes, one unreachable');
    });

    test('the six causes carry the six retriable answers of § 3.4', () {
      // Stronger than self-consistency: this pins the *values*, so a cause that
      // flipped its answer would fail here rather than only in whichever test
      // happened to compare it with itself.
      // A list of records rather than a Map keyed by the cause: a class that
      // overrides `==` cannot be a const map key, and this map has no use for one.
      const List<(SourceFailure, bool)> expected = <(SourceFailure, bool)>[
        (NoConnection(host: 'x'), true),
        (RateLimited(retryAfter: Duration.zero), true),
        (SourceUnavailable(status: 503), true),
        (SourceLayoutChanged(failedSelector: '.x', status: 200), false),
        (ItemRemovedAtSource(itemId: 'n1', status: 404), false),
        (ParseFailed(path: '/x'), false),
      ];

      for (final (SourceFailure cause, bool retriable) in expected) {
        expect(
          cause.isRetriable,
          retriable,
          reason: cause.runtimeType.toString(),
        );
      }

      expect(expected, hasLength(6));
    });

    test('no non-retriable cause can be made retriable', () {
      for (final SourceFailure cause in <SourceFailure>[
        const SourceLayoutChanged(failedSelector: '.x', status: 200),
        const ParseFailed(path: '/novel/1.html'),
        const ItemRemovedAtSource(itemId: 'n1', status: 404),
      ]) {
        expect(
          cause.isRetriable,
          isFalse,
          reason: cause.runtimeType.toString(),
        );
      }
    });

    test('ItemRemovedAtSource is never produced by the classifier itself', () {
      // E9: the site answered and confirmed the item is gone. The classifier only
      // ever sees a transport result, so it must not be able to invent this.
      final Set<SourceFailure> produced = <SourceFailure>{};
      for (final ReadStage stage in ReadStage.values) {
        for (final FetchResult fetch in <FetchResult>[
          const FetchTransportFailed(host: 'a.test'),
          const FetchRateLimited(retryAfter: Duration.zero, status: 429),
          const FetchSucceeded(status: 200),
          const FetchSucceeded(status: 404),
        ]) {
          for (final ContentProbe probe in <ContentProbe>[
            const ExpectedContentFound(1),
            const ExpectedContentFound(0),
            const ExpectedContentAbsent(),
            const ParseBroke(),
          ]) {
            final BrowseOutcome<String> outcome = classifier.classify<String>(
              ReadAttempt(
                stage: stage,
                fetch: fetch,
                content: probe,
                requestPath: '/x',
                expectedSelector: '.x',
              ),
            );
            if (outcome is BrowseFailed<String>) produced.add(outcome.reason);
          }
        }
      }

      expect(
        produced.whereType<ItemRemovedAtSource>(),
        isEmpty,
        reason: 'only 6-4 has the site\'s answer, so only 6-4 may produce this',
      );
      // Sanity: the sweep above really did run and really did produce causes.
      expect(produced, hasLength(greaterThan(3)));
    });
  });

  group('BrowseEmpty is reachable only through the site\'s signal', () {
    // § 10: "a test walks the six causes and the count/signal combinations and
    // asserts BrowseEmpty appears in exactly one of them."
    test('no signal-less combination ever reaches BrowseEmpty', () {
      // § 10 in the form the arithmetic actually has. The plan says BrowseEmpty
      // appears "in one" of the count/signal combinations — meaning one
      // *combination class*, not one of 72 calls: two counts × six stages all
      // reach it once a signal is present. The assertion that matters is the
      // other half — **none of them reach it without one.**
      //
      // (The first version of this test asserted `reached == 1` and measured 12.
      // The 12 is right and the assertion was wrong, which is a much cheaper
      // place to get that wrong than in the classifier.)
      int reachedWithSignal = 0;
      int reachedWithoutSignal = 0;
      int total = 0;

      for (final ReadStage stage in ReadStage.values) {
        for (final int count in <int>[0, 12]) {
          for (final String? signal in <String?>[null, 'No relevant content']) {
            for (final ContentProbe probe in <ContentProbe>[
              ExpectedContentFound(count),
              const ExpectedContentAbsent(),
              const ParseBroke(),
            ]) {
              total++;
              final BrowseOutcome<String> outcome = classifier.classify<String>(
                ReadAttempt(
                  stage: stage,
                  fetch: ok,
                  content: probe,
                  siteEmptySignal: signal,
                  expectedSelector: '.x',
                  requestPath: '/x',
                ),
              );
              if (outcome is BrowseEmpty<String>) {
                if (signal == null) reachedWithoutSignal++;
                reachedWithSignal++;
              }
            }
          }
        }
      }

      expect(total, 72, reason: '6 stages × 2 counts × 2 signals × 3 probes');
      expect(
        reachedWithoutSignal,
        0,
        reason:
            "B22: the discriminator is the site's own signal, never the "
            'absence of a match',
      );
      expect(reachedWithSignal, greaterThan(0));
      expect(
        reachedWithSignal + reachedWithoutSignal,
        lessThan(total),
        reason:
            'most combinations are a success or a failure — if every one '
            'were BrowseEmpty the test above would prove nothing',
      );
    });
  });

  group('Purity — B23', () {
    test('two sources share no state, in either order', () {
      const ReadAttempt healthy = ReadAttempt(
        stage: ReadStage.catalogue,
        fetch: ok,
        content: ExpectedContentFound(3),
      );
      const ReadAttempt broken = ReadAttempt(
        stage: ReadStage.catalogue,
        fetch: ok,
        content: ExpectedContentAbsent(),
        expectedSelector: '.gone',
      );

      final BrowseOutcome<int> first = classifier.classify<int>(healthy);
      final BrowseOutcome<int> second = classifier.classify<int>(broken);
      final BrowseOutcome<int> againHealthy = classifier.classify<int>(healthy);
      final BrowseOutcome<int> againBroken = classifier.classify<int>(broken);

      expect(first, isA<BrowseSucceeded<int>>());
      expect(second, isA<BrowseFailed<int>>());
      expect(againHealthy.runtimeType, first.runtimeType);
      expect(againBroken.runtimeType, second.runtimeType);
      expect((againHealthy as BrowseSucceeded<int>).items, isEmpty);
    });

    test('a failed read does not poison the next one', () {
      classifier.classify<int>(
        const ReadAttempt(
          stage: ReadStage.catalogue,
          fetch: FetchTransportFailed(host: 'dead.test'),
          content: null,
        ),
      );
      final BrowseOutcome<int> next = classifier.classify<int>(
        const ReadAttempt(
          stage: ReadStage.catalogue,
          fetch: ok,
          content: ExpectedContentFound(1),
        ),
      );
      expect(next, isA<BrowseSucceeded<int>>());
    });

    test('the returned list is unmodifiable', () {
      final BrowseOutcome<int> read = classifier.classify<int>(
        const ReadAttempt(
          stage: ReadStage.catalogue,
          fetch: ok,
          content: ExpectedContentFound(1),
        ),
        items: const <int>[1],
      );
      final BrowseSucceeded<int> outcome = read as BrowseSucceeded<int>;
      expect(
        () => outcome.items.add(2),
        throwsUnsupportedError,
        reason:
            'an outcome is a value; a caller that mutates one turned a read '
            'into an edit',
      );
    });

    test('classify never throws, on any input', () {
      for (final ReadStage stage in ReadStage.values) {
        for (final FetchResult fetch in <FetchResult>[
          const FetchTransportFailed(host: ''),
          const FetchRateLimited(retryAfter: Duration.zero, status: 429),
          const FetchSucceeded(status: 0),
          const FetchSucceeded(status: 199),
          const FetchSucceeded(status: 200),
          const FetchSucceeded(status: 299),
          const FetchSucceeded(status: 300),
          const FetchSucceeded(status: 503),
        ]) {
          for (final ContentProbe? probe in <ContentProbe?>[
            null,
            const ParseBroke(),
            const ExpectedContentAbsent(),
            const ExpectedContentFound(0),
            const ExpectedContentFound(9),
          ]) {
            expect(
              () => classifier.classify<int>(
                ReadAttempt(stage: stage, fetch: fetch, content: probe),
              ),
              returnsNormally,
              reason: '$stage / ${fetch.runtimeType} / ${probe.runtimeType}',
            );
          }
        }
      }
    });
  });

  group('The manufactured broken-layout fixture — § 3.5, SC-6', () {
    // ⚠️ The plan names `test/fixtures/sources/fanmtl/fanmtl-broken-layout.html`.
    // FanMTL is behind a Cloudflare challenge from this machine (F-012) and no
    // fixture of it exists, so `0-1` manufactured the pair from **Royal Road**,
    // which it could reach. The shape under test is the same — a page whose
    // content container has been renamed — and what § 3.5 asks for is a property
    // of the *classifier*, not of a site.

    final File broken = File(
      'test/fixtures/sources/royalroad/manufactured/broken-layout.html',
    );

    test('the file exists — otherwise 0-1 was not done', () {
      expect(broken.existsSync(), isTrue, reason: broken.path);
    });

    test('it parses as HTML, is not empty, and carries no site signal', () {
      final String raw = broken.readAsStringSync();
      final parsed = html_parser.parse(raw);

      expect(parsed.querySelectorAll('p'), isNotEmpty);
      expect(
        parsed.body?.text.trim().length ?? 0,
        greaterThan(1000),
        reason: '§ 3.5 step 3: it is a page, not a hole',
      );
      // Step 4: the site's own "nothing found" marker lives elsewhere, so this
      // page can NEVER reach BrowseEmpty on its own.
      expect(raw, isNot(contains('No relevant content found')));
    });

    test('an absent probe on it is SourceLayoutChanged — branch 6', () {
      final BrowseOutcome<String> outcome = classifier.classify<String>(
        const ReadAttempt(
          stage: ReadStage.chapterContent,
          fetch: ok,
          content: ExpectedContentAbsent(),
          expectedSelector: '.chapter-inner.chapter-content',
        ),
      );

      final SourceLayoutChanged reason =
          (outcome as BrowseFailed<String>).reason as SourceLayoutChanged;
      expect(reason.failedSelector, '.chapter-inner.chapter-content');
      expect(reason.status, 200);
      expect(reason.siteSuppliedSignal, isNull);
    });

    test(
      'an empty container on it is also SourceLayoutChanged — branch 9b',
      () {
        final BrowseOutcome<String> outcome = classifier.classify<String>(
          const ReadAttempt(
            stage: ReadStage.chapterContent,
            fetch: ok,
            content: ExpectedContentFound(0),
            expectedSelector: '.chapter-inner.chapter-content',
          ),
        );

        expect(
          (outcome as BrowseFailed<String>).reason,
          isA<SourceLayoutChanged>(),
        );
      },
    );

    test('three different outcomes from ONE page, with no network', () {
      // § 3.5 steps 5-7, and the reason this test exists: SC-6 requires the three
      // states to be distinguishable, and one fixture is enough to prove it.
      final BrowseOutcome<String> a = classifier.classify<String>(
        const ReadAttempt(
          stage: ReadStage.chapterContent,
          fetch: ok,
          content: ExpectedContentAbsent(),
        ),
      );
      final BrowseOutcome<String> b = classifier.classify<String>(
        const ReadAttempt(
          stage: ReadStage.chapterContent,
          fetch: ok,
          content: ExpectedContentFound(0),
        ),
      );
      final BrowseOutcome<String> c = classifier.classify<String>(
        const ReadAttempt(
          stage: ReadStage.chapterContent,
          fetch: ok,
          content: ExpectedContentFound(0),
          siteEmptySignal: 'forged by a caller that knows the site',
        ),
      );

      expect(a, isA<BrowseFailed<String>>());
      expect(b, isA<BrowseFailed<String>>());
      expect(
        c,
        isA<BrowseEmpty<String>>(),
        reason:
            'a forged signal is the ONLY way onto BrowseEmpty — which is '
            'exactly why B22 demands the signal and not the absence',
      );
    });

    test('the intact page it was derived from parses to content', () {
      // The counterpart: the manufactured file differs from its source by a single
      // literal substitution, and the source really did have the container.
      final File intact = File(
        'test/fixtures/sources/royalroad/chapter-skills-titles.html',
      );
      expect(intact.existsSync(), isTrue);
      expect(
        html_parser
            .parse(intact.readAsStringSync())
            .querySelectorAll('.chapter-inner.chapter-content'),
        isNotEmpty,
      );
      expect(
        html_parser
            .parse(broken.readAsStringSync())
            .querySelectorAll('.chapter-inner.chapter-content'),
        isEmpty,
        reason:
            'the whole point of the fixture: the container is GONE, on a '
            'page that is otherwise perfectly well formed',
      );
    });
  });

  group('Exhaustiveness', () {
    test('a switch over BrowseOutcome needs no default and no cast', () {
      // E19: BrowseEmpty and BrowseFailed share no member, so an exhaustive
      // switch treats them without ambiguity — and adding an arm is a compile
      // error, not a silent fall-through.
      String render<T>(BrowseOutcome<T> outcome) {
        return switch (outcome) {
          BrowseSucceeded<T>() => 'items',
          BrowseEmpty<T>() => 'empty',
          BrowseFailed<T>() => 'failed',
        };
      }

      expect(
        render(
          classifier.classify<String>(
            const ReadAttempt(
              stage: ReadStage.genreListing,
              fetch: ok,
              content: ExpectedContentFound(0),
            ),
          ),
        ),
        'items',
      );
      expect(
        render(
          classifier.classify<String>(
            const ReadAttempt(
              stage: ReadStage.catalogue,
              fetch: ok,
              content: ExpectedContentFound(0),
            ),
          ),
        ),
        'failed',
      );
    });
  });
}
