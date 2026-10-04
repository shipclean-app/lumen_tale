// Lumen Tale — the shape every one of the six reads has, written once.
//
// `03-source-system.md`. A source's read is always the same four steps and they are easy
// to get subtly wrong in five different ways, so they live here once and a source
// supplies only the parts that differ:
//
//   **fetch** → **probe with the source's own selectors** → **build a [ReadAttempt]** →
//   **classify**.
//
// ## The five ways it goes wrong, and what stops each
//
//  1. **Probing with the wrong selector for the stage.** `stage` is not a label; it
//     picks [kZeroItemsPolicyByStage], and getting it wrong is how a legitimately empty
//     genre index is reported as a broken site. [classifyRead] takes the probe and the
//     stage together so they cannot be swapped.
//  2. **Losing the site's own empty signal.** It is the FIRST discriminant inside the
//     classifier, before the count — and a source that drops it on the floor cannot
//     produce `BrowseEmpty` at all.
//  3. **Not declaring the selector that failed.** `SourceLayoutChanged` carries it as
//     evidence so an owner can read it against the fixture; a source that forgets
//     produces `(non déclaré)`.
//  4. **Echoing a reader's query into the evidence.** `requestPath` is site-relative and
//     **carries no query string** (C5, `17-security.md` rule 1) — a failure line is
//     something an owner reads, and a reader's search term in one is a small leak.
//  5. **Deciding the outcome itself.** A source that branches on `rows.isEmpty` before
//     calling the classifier has re-implemented B22 in a place with no tests. This class
//     makes that the only path: it takes items and returns the verdict.

import 'package:lumen_tale/core/network/http_response.dart';
import 'package:lumen_tale/domain/sources/browse_outcome.dart';
import 'package:lumen_tale/domain/sources/outcome_discriminator.dart';
import 'package:lumen_tale/domain/sources/read_attempt.dart';

/// Turns a fetched page into an outcome, with nothing decided in advance.
final class ReadPipeline {
  const ReadPipeline._();

  /// Classifies one read.
  ///
  /// [probe] is what the **source's own selectors** found. [expectedSelector] is the
  /// selector, echoed for the evidence line. [siteEmptySignal] is the site's own
  /// verbatim marker — `null` when the site publishes none, which is Royal Road's
  /// browse side and the reason `BrowseEmpty` is unreachable there.
  static BrowseOutcome<T> classifyRead<T>({
    required HttpResponse response,
    required ReadStage stage,
    required ContentProbe probe,
    required String expectedSelector,
    String? siteEmptySignal,
    ZeroItemsPolicy? zeroItemsPolicy,
    String? requestPath,
    List<T> items = const [],
  }) {
    return const OutcomeDiscriminator().classify<T>(
      ReadAttempt(
        stage: stage,
        fetch: response.outcome,
        content: probe,
        siteEmptySignal: siteEmptySignal,
        zeroItemsPolicy: zeroItemsPolicy,
        expectedSelector: expectedSelector,
        requestPath: requestPath,
      ),
      items: items,
    );
  }

  /// The probe for "my selector matched", carrying how many rows it found.
  ///
  /// ⚠️ **The count is what the classifier's third arm reads**, so it must be the count
  /// the source actually produced — not `items.length`, and never `1` to mean "found".
  static ContentProbe found(int itemCount) => ExpectedContentFound(itemCount);

  /// The probe for "the page answered and none of my selectors are there".
  ///
  /// ⚠️ **Not a parse failure.** E4/E8/SC-6: the page parsed fine and held nothing I
  /// expected, which is a *layout change* — the state that must be reported rather than
  /// shown as an empty list.
  static ContentProbe absent() => const ExpectedContentAbsent();

  /// The probe for "the body did not survive parsing at all".
  static ContentProbe broke() => const ParseBroke();
}
