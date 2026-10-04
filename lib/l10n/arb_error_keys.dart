// Lumen Tale — which ARB keys are the failure and status vocabulary.
//
// `6-7` § 2.2, and the classification the completeness barrier needs.
//
// ## ⚠️ It lives in `lib/l10n/`, NOT in `lib/core/utils/i18n/` where the plan wrote it
//
// The plan's § 2.2 puts `ArbKey` under `core/utils/i18n/`. `AGENTS.md`'s layer table says
// `core/` "→ external packages only", and this file describes the **ARB vocabulary** — so
// putting it in `core/` would make a leaf layer depend on the l10n directory, which is the
// boundary `tool/check_boundaries.py` exists to refuse.
//
// `lib/l10n/` is where the sibling ARB rule already lives (`arb_key_derivation.dart`), and
// the two answer the same question from the same side of the boundary: *what does an ARB key
// mean*. One directory, one subject.
//
// ## Why this is code and not a `Set` written inside the test
//
// The classification decides which keys get the strictest checks — parity, a sentence rather
// than a label, no URL and no class name. A list written inside a test is a list only that
// test can see, so the next test to need the same answer writes a second, different one, and
// the two disagree silently. A rule that must be applied in two places belongs in one place.

/// The ARB key prefixes that carry a **failure, a status, or a warning**.
///
/// `6-7` § 2.2 calls this `mustBeBilingual`, and it is the plan's own `isErrorString` prefix
/// set: `error`, `warning`, `browse`, `download`, `check`. `action` is **not** in it, because
/// `actionFreeSpace` / `actionReportBug` are the sentences an error *offers*, not the error
/// itself, and § 3.2 lists them under a different heading.
///
/// These five are the prefixes whose absence in one file produces a **silent** screen: the
/// `gen-l10n` untranslated report only names a key missing from a translation, so a French
/// gap inside an error sentence is a reader staring at an English error on a French phone.
const Set<String> errorArbKeyPrefixes = <String>{
  'error',
  'warning',
  'browse',
  'download',
  'check',
};

/// Whether [key] belongs to the failure/status vocabulary.
///
/// `true` for `errorNoConnection`, `downloadQueued`, `checkStoppedPreempt` — and `false` for
/// `navLibrary`, `settingsTitle`, `coverSemanticsLabel`, which are copy but not failure copy.
///
/// The match is a prefix, which is why the prefixes above are **bare** words: `error*` has to
/// match `errorCountUnavailable` without matching `errorsEnabled`. Every key carrying one of
/// these five prefixes today starts with the prefix followed by a capital, so a word-boundary
/// check would also work — the prefix test is the simpler of the two and the one the plan
/// specifies.
bool isErrorArbKey(String key) {
  for (final String prefix in errorArbKeyPrefixes) {
    if (key.startsWith(prefix)) return true;
  }
  return false;
}

/// Every ARB key in [keys] that belongs to the failure/status vocabulary, sorted.
///
/// Sorted so a failure report names the same keys in the same order on every run — a list
/// whose order changes between runs is a list nobody compares against a previous failure.
List<String> errorArbKeys(Iterable<String> keys) =>
    keys.where(isErrorArbKey).toList()..sort();
