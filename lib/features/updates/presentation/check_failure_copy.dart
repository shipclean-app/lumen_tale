// Lumen Tale — `CheckFailureKind` in words, and the three lines a pass says out loud.
//
// `6-4`. Presentation copy, so it lives under `features/`. It imports **no other
// feature** — the failure vocabulary is `domain`'s and the sentences are ARB's.
//
// ## ⚠️ **NO NEW KEY FOR A SENTENCE THE PROJECT ALREADY OWNS**
//
// `design-system.md` § 2.12: *two lists of the same values in two places is two truths*.
// The app already owns a sentence for each of the six causes — `errorNoConnection`,
// `errorRateLimited`, `errorSourceLayoutChanged`, `errorSourceUnavailable`,
// `errorItemRemovedAtSource`, `errorParseFailed` — and it owns the check's three lines as
// `checkProgressNothingDownloaded`, `checkTerminalComplete`, `checkTerminalInterrupted`
// and `checkTerminalWithFailures`. This file therefore **maps onto existing keys**; the
// only strings `6-4` added are the lines themselves, and they are shared with `6-10`,
// whose notification says the same two facts.
//
// ## ⚠️ EVERY sentence must be READABLE ALOUD, AND NONE MAY NAME A SELECTOR
//
// C12: a reader who has to describe the failure to the person who owns the phone has to
// have words. `18-external-contracts.md` records the selector that broke in
// `failedSelector` for the OWNER's benefit — it never reaches a screen, because
// `17-security.md` rule 4 forbids a raw CSS selector in user-visible text and a reader
// cannot act on one anyway. A test asserts all six values have a sentence in English AND
// in French and that none of the twelve contains a character sequence shaped like a CSS
// selector.
//
// ## ⚠️ THE PROGRESS LINE SAYS BOTH RULES IN ONE SENTENCE
//
// § 3.4: *Checking 7 of 23 novels · nothing is downloaded*. The counter is B39's only
// visible proof — a pass that quietly visited only the first fifty novels looks identical
// from outside — and the second clause is B38, which is why there is no confirmation
// dialog (a check costs no data and no storage, so a dialog saying it did would be a lie).
// **Never a truncated plural, never `50+`.**

import 'package:lumen_tale/domain/updates/library_check.dart';
import 'package:lumen_tale/l10n/generated/app_localizations.dart';

/// `CheckFailureKind` → the sentence a reader reads, **exhaustive, no `default`**.
extension CheckFailureCopy on AppLocalizations {
  /// One sentence per cause, in the reader's language.
  ///
  /// ⚠️ **Adding a `CheckFailureKind` value breaks this switch at compile time**, which
  /// is the point: a cause with no sentence would otherwise render as the generic one, and
  /// the generic one is a claim this app cannot make.
  String checkFailureSentence(CheckFailureKind kind) => switch (kind) {
    // E5. The phone, not the site — and the sentence says nothing about the library,
    // because nothing about it changed.
    CheckFailureKind.noConnection => errorNoConnection,
    // C7. The site asked for patience; the reader needs to know the wait is the site's
    // decision and not a broken app.
    CheckFailureKind.rateLimited => errorRateLimited,
    // E4. The one cause that is this app's own fault, and the sentence says so.
    CheckFailureKind.sourceLayoutChanged => errorSourceLayoutChanged,
    // A refusal, an outage, or an anti-bot challenge this app will not climb (ADR-014).
    CheckFailureKind.sourceUnavailable => errorSourceUnavailable,
    // E9. The author withdrew the novel; the downloaded chapters stay readable, and this
    // sentence is not an apology for them.
    CheckFailureKind.itemRemovedAtSource => errorItemRemovedAtSource,
    // E8. The page answered and could not be read.
    CheckFailureKind.parseFailed => errorParseFailed,
  };

  /// The running-check line: *Checking 7 of 23 novels · nothing is downloaded*.
  ///
  /// ⚠️ **Both numbers, verbatim and uncapped.** § 3.4 forbids `50+` and a truncated
  /// plural; the total is fixed at the start of the pass and the progress is
  /// [LibraryCheckProgress.done].
  ///
  /// ⚠️ **The shared key `checkProgressNothingDownloaded`, not a second one.** `6-10`'s
  /// notification says the same two facts, and two keys holding the same sentence in two
  /// languages is two truths about what a check tells the reader.
  String checkProgressLine(LibraryCheckProgress progress) =>
      checkProgressNothingDownloaded(progress.done, progress.total);

  /// The terminal line, and **it has three shapes because a pass has three endings**.
  ///
  /// | the pass | the line | rule |
  /// |---|---|---|
  /// | interrupted | *Check stopped at 7 of 23 novels.* | B37 — a stopped pass is never reported as a finished one |
  /// | finished, some failed | *Checked 19 of 23 novels · 4 could not be checked.* | B22 — the failure count is **never** folded into a success |
  /// | finished, none failed | *All 23 novels checked · none skipped.* | B39 — `none skipped` is the claim the reader cannot verify otherwise |
  ///
  /// ⚠️ **The order of the three branches is load-bearing.** Interrupted is tested first
  /// because an interrupted pass can also have failures, and reporting it as "checked 7 of
  /// 23" would hide the fact that it stopped.
  String checkTerminalLine(LibraryCheckResult result) {
    if (result.interrupted) {
      return checkTerminalInterrupted(result.perNovel.length, result.total);
    }
    if (result.failedCount > 0) {
      return checkTerminalWithFailures(
        result.checkedCount,
        result.total,
        result.failedCount,
      );
    }
    return checkTerminalComplete(result.total);
  }
}
