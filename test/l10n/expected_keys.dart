// Lumen Tale — `6-7`'s inventory: the ARB keys this slice owns, declared once.
//
// ## Why this file exists
//
// B28 asks for **completeness**, and completeness is a property of the whole product rather
// than of one slice — so `6-7` § 7 keeps the cheapest reversible option: the inventory of
// the failure/status vocabulary is **declared here**, and the barrier
// (`translation_completeness_test.dart`) reads it.
//
// Declared, not derived, because the distinction it exists to draw cannot be derived from a
// key's spelling: `downloadDone` and `downloadFailed` share a prefix, and one is a status
// label while the other is a sentence a reader must be able to describe out loud (C12).
//
// ## ⚠️ It is an inventory this slice OWNS, not of every key in the ARB
//
// `6-7` § 9 Phase 1 proposed `expected_keys.dart` as "the list of expected keys, empty at the
// start, added by each screen slice", with the test asserting the ARBs contain **exactly** it.
// That was the right idea and the wrong mechanism here: at the moment of writing the two ARB
// files hold 387 keys owned by eight slices being written **concurrently**, and an exact-equality
// assertion would fail the moment any of them wrote one more key — a red test owned by nobody,
// blaming the file this slice owns.
//
// So the direction is inverted: **every key declared here must exist in both ARBs.** That
// catches the failure the rule exists for — a key this slice promised, absent from one file
// after a concurrent write, which is exactly how `6-7` lost twenty-one of `3-3`'s messages —
// and it cannot be made false by another slice doing its own work. Screen slices still add
// their own copy to their own tests; this list is the part of the product whose absence is a
// *silent* screen.

/// The § 3.2 sentences: a failure the reader must be able to describe out loud.
///
/// **The rule these answer to is "a failure sentence is never a bare label"** — see
/// `translation_completeness_test.dart`, which states why the count is measured in WORDS and
/// not in the plan's `[.!:]` clauses. Every key here must be at least `minimumSentenceWords`
/// in **both** languages.
///
/// The seven causes of `architecture.md` § 5.2 come first, in its order, then B22's three
/// states, then the failures that have no site behind them.
const List<String> errorSentenceKeys = <String>[
  // ── the seven causes of `architecture.md` § 5.2 ──────────────────────────────
  'errorNoConnection',
  'errorRateLimited',
  'errorRateLimitedIn',
  'errorSourceLayoutChanged',
  'errorSourceUnavailable',
  'errorItemRemovedAtSource',
  'errorStorageFull',
  'errorParseFailed',

  // ── B22: the states a browse screen must not confuse for one another ──────────
  'browseEmpty',
  'errorSiteUnreadable',
  'downloadFailed',

  // ── the cancellation, in the form the reader is actually shown it ────────────
  // ⚠️ `checkCancelled` is the SHORT status line and lives in `statusLabelKeys`;
  // § 3.2 specifies the full sentence ("Check cancelled. Your library is
  // unchanged.") and the design split it in two. The half that carries the rule —
  // *your library is unchanged* — is what this list holds, so the rule is checked
  // against the string a reader reads rather than against the label above it.
  'checkCancelledByReader',

  // ── failures with no site behind them ───────────────────────────────────────
  'errorSettingsLoad',
  'errorSettingsWrite',
  'errorHistoryClear',
  'errorCountUnavailable',
  'warningNotifications',
];

/// The § 3.2 **status labels**: a state a reader reads at a glance, not a sentence.
///
/// Each entry is here with its reason, and the reason is the test. A label that grows a
/// second clause becomes a sentence and moves to [errorSentenceKeys]; the barrier fails if a
/// key appears in neither list, so this cannot quietly become a dumping ground.
const Map<String, String> statusLabelKeys = <String, String>{
  'browseSucceeded':
      '§ 3.2 specifies NO text for this row — "a result has no message" — and the key '
      'exists only so the mapping is exhaustive. A sentence here would announce a success '
      'to a screen that already shows one.',
  'downloadQueued':
      '§ 3.2 specifies `Queued` / `En file d\'attente`. It is a queue position read at a '
      'glance; the plan asks for it as a label and a longer string here would push the '
      'chapter title off the row.',
  'downloadDownloading':
      '§ 3.2 specifies `Downloading {current} of {total}`; the progress itself is drawn by '
      'the row, so the string is the state and the numbers are the row\'s.',
  'downloadDone':
      '§ 3.2 specifies `Downloaded` / `Téléchargé`. B6 makes it a mark written after the '
      'atomic rename, and a mark is one word.',
  'checkCancelled':
      'The STATUS line of a cancelled check, above the sentence that says what survived '
      '(`checkCancelledByReader`). § 3.2 specifies the full sentence; the design put '
      'its two halves on two lines, so the short one is a label and the long one is '
      'the sentence — and the sentence is the one this list checks.',
};

/// The four `DownloadState` values of `DownloadState` — B28 names them explicitly.
///
/// *« including all error and download-status messages »*. They are listed separately from
/// [statusLabelKeys] because § 10.6 asks for them as a group: four states, four distinct
/// strings, in both languages.
const List<String> downloadStateKeys = <String>[
  'downloadQueued',
  'downloadDownloading',
  'downloadDone',
  'downloadFailed',
];

/// B22's three states, which must stay three **different** keys.
///
/// *« When a site cannot be read the app states that it could not read it, and never
/// presents an empty list as an answer. »* Collapsing any two of these into one key makes the
/// distinction invisible in the reader's language.
const List<String> browseResultKeys = <String>[
  'browseEmpty', // the site was read and said it had nothing
  'errorSiteUnreadable', // the site could not be read at all
  'browseSucceeded', // the site was read and had results
];

/// The phrase B22 turns on, in both languages.
///
/// § 11.1 names it as the row: *"a sentence that distinguishes it explicitly from 'no
/// chapters'"*. Asserted as a substring rather than as the whole string, because the clause
/// is what carries the rule and the sentence is allowed to say more.
const Map<String, String> browseUnreadableDistinguishingClause =
    <String, String>{'en': 'not the same as', 'fr': 'pas la même chose'};

/// The five navigation destinations of `design-system.md` § 3.2 — ADR-018.
///
/// `navMore` was **missing** until this slice: the shell had six labels and five tabs, and a
/// tab without a label is a visible defect rather than a missing translation.
const List<String> navDestinationKeys = <String>[
  'navLibrary',
  'navUpdates',
  'navHistory',
  'navBrowse',
  'navMore',
];

/// E11's disclosure, in full, in the places it is shown.
///
/// *« the one place in this app where a compressed translation would be a weaker
/// disclosure »* (`onboarding.md` § 4.1). So the rule is not "both languages exist" but
/// **both languages carry the same number of sentences**.
const List<String> e11DisclosureKeys = <String>[
  'aboutDataE11',
  'settingsDisclosureE11',
  'settingsDisclosureE11Footer',
];

/// Placeholder names that must never appear in a failure or status sentence.
///
/// B29 and B44: no chapter prose, no chapter title, no request URL ever reaches a message.
/// The mechanical form of that rule is a **name**, because a placeholder is the only way a
/// sentence can carry anything dynamic — and `{site}`-shaped names are allowed while
/// `{chapterText}`-shaped ones are not.
///
/// `{query}` is NOT banned, and the reason is worth stating because it looks like it should
/// be: `browseSiteSaidNothingBody` echoes the reader's own words back so they can see a typo.
/// B41 says those words leave the app byte for byte, and B29 is about data *leaving the
/// device* — showing a reader their own query on their own screen sends nothing anywhere.
const Set<String> bannedProsePlaceholderNames = <String>{
  'chapterText',
  'content',
  'body',
  'html',
  'excerpt',
  'snippet',
  'prose',
  'markup',
  'raw',
  'responseBody',
};

/// The `FailureEvidence.sentence()` implementations that are still hardcoded English.
///
/// ⚠️ **A RECORDED DEFECT, not an approval — and it is `3-6`'s, not `6-7`'s.**
///
/// `lib/features/source_unavailable/failure_cause.dart` returns English sentences
/// (`'The site answered HTTP $status.'`) and `source_unavailable_screen.dart` both renders
/// one (line 291) and copies it to the clipboard (line 389). B28 covers that as squarely as it
/// covers a `Text(…)`, so the barrier does **not** pass it by ignoring it: the entry is keyed
/// by evidence CLASS, so an eighth evidence type fails the row and has to be given a reason.
/// `3-6` is `validated`, so rewriting its screen and its assertions from here is the wrong
/// owner; the finding is recorded instead.
///
/// The alternative considered and rejected: drop `sentence()` from the barrier's vocabulary
/// altogether. That would make the row green by looking at less, which is the exact shape of
/// "the guard passes and the defect stays".
///
/// `_NoEvidence` is in the list for the same reason as the six public ones: it returns
/// `'The app kept a record of this failure it can no longer read.'`, and a private class is
/// still rendered.
const Set<String> knownHardcodedEvidenceClasses = <String>{
  'NoConnectionEvidence',
  'LoadedButEmptyEvidence',
  'HttpStatusEvidence',
  'AntiBotChallengeEvidence',
  'SiteNotFoundSignalEvidence',
  'ParseOutcomeEvidence',
  '_NoEvidence',
};

/// The `failureKickers` map — the same defect, in its second form.
///
/// `source_unavailable_screen.dart:146` renders `failureKickers[cause]` as the screen's
/// overline, and all five values are hardcoded English. Same reasoning as
/// [knownHardcodedEvidenceClasses]: recorded per key rather than waved through, so adding a
/// sixth cause to the map fails the row.
const Set<String> knownHardcodedFailureKickers = <String>{
  'noConnection',
  'layoutChanged',
  'siteUnavailable',
  'contentRemoved',
  'unreadableRecord',
};
