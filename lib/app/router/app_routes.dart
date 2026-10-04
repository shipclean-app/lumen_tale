// Lumen Tale — every path in the app, in one place.
//
// `09-widgets-ui.md` convention 10: route paths are **centralised**; a feature
// never writes a literal like `'/novel/$id'`. This file is that place.
//
// ⚠️ **The paths are transcribed from `.forge/design/design-system.md` § 3.5, and
// this file does not choose them.** That table is reconciled against the
// eighteen screen files in *both* directions, which is the only reason it can be
// trusted as a list: a one-way reconciliation reports zero on the half it does
// not look at, and that has already happened four times in this project.
//
// ## The fifteen routes, and the three that are deliberately absent
//
// § 3.5 lists fifteen. Absent, on purpose:
//
// - `/library/novel/:novelId/chapter/:chapterId` — **removed** from § 3.5 on
//   2026-10-02: it appeared there and in **no** screen file, and every screen that
//   opens a chapter pushes `/reader/:novelId/:chapterId` (three call sites, zero
//   for the other form). Two URLs for one destination is a route table with two
//   truths. `0-5` § 7 question 1 asked who owned it; the design system had
//   already answered.
// - `/more/sources` and `/more/stats` — **removed** with slices `6-9` and `6-8`,
//   and no v1 rule needs them. Declaring them would produce two reachable
//   destinations that lead to nothing.
//
// ## Patterns and locations come from the same roots
//
// A `GoRoute.path` is a **pattern** (`/browse/:sourceId`); `go()` takes a
// **location** (`/browse/fanmtl`). They differ by exactly the `:param`, and a
// builder that interpolates from the pattern produces
// `/browse/:sourceId/fanmtl` — which **matches** the route, resolves to the
// literal source id ":sourceId", and opens a screen for a source that does not
// exist. Nothing throws. Every root below is therefore written once and both
// forms are derived from it, so the mistake has nowhere to be made.

/// Every path, and the builders that produce them.
///
/// **Builders, never interpolation at the call site.** `go_router`'s `go()` wants
/// a location string; a feature that builds one by hand re-implements this file
/// with less care, and a path that drifts between the table and a call site is a
/// route that 404s on a release nobody tested.
abstract final class AppRoutes {
  const AppRoutes._();

  // ── roots, written once ─────────────────────────────────────────────────
  static const String _novelRoot = '$library/novel';
  static const String _sourceRoot = browse;
  static const String _genreRoot = '$_sourceRoot/:sourceId/genre';

  /// `/reader` — the **root**, as a location prefix.
  ///
  /// ## ⚠️ PUBLIC, BECAUSE SOMETHING OUTSIDE THIS FILE NEEDS THE ROOT AND NOT THE PATTERN
  ///
  /// [reader] is `'/reader/:novelId/:chapterId'` — a **pattern**. Comparing a pattern against
  /// a matched location matches nothing: `'/reader/n1/c1'.startsWith('/reader/:novelId/
  /// :chapterId')` is `false`, so a rule written that way is a rule that never fires and
  /// reads as one that always does.
  ///
  /// The cold-start gate needs exactly that root, because the whole question it asks is *"is
  /// this navigation inside the reader?"* — a property of the first segment, before the
  /// parameters exist. `3-4` wrote the exemption against [reader] and the test
  /// `test/features/onboarding/onboarding_startup_gate_test.dart` caught it on the first run.
  ///
  /// So the root is a named constant, [reader] is derived from it, and nothing in the app
  /// spells `/reader` in a second place.
  static const String readerRoot = '/reader';

  // ── the five bottom-nav destinations ────────────────────────────────────
  //
  // The ORDER of these constants is not what fixes the bar's order — ADR-018's
  // is, and `AppNavDestination.rank` asserts it against `state.json`'s `set-nav`
  // record. What these constants carry is that every tab root has one spelling.
  static const String library = '/library';
  static const String updates = '/updates';
  static const String history = '/history';
  static const String browse = '/browse';
  static const String more = '/more';

  // ── patterns, for `GoRoute.path` ─────────────────────────────────────────
  static const String novelDetails = '$_novelRoot/:novelId';
  static const String sourceBrowse = '$_sourceRoot/:sourceId';
  static const String sourceGenre = '$_genreRoot/:genre';
  static const String sourceUnavailable = '$_sourceRoot/:sourceId/unavailable';
  static const String downloads = '$more/downloads';
  static const String settings = '$more/settings';
  static const String settingsReader = '$settings/reader';
  static const String settingsAbout = '$settings/about';

  // ── OUTSIDE the shell — no tab bar ──────────────────────────────────────
  static const String reader = '$readerRoot/:novelId/:chapterId';
  static const String onboarding = '/onboarding';

  /// ⚠️ **THE QUERY PARAMETER THAT MEANS "OPEN ON STEP 2".** It is the **location** form of
  /// [onboarding], not a second route: one path, two locations, so `design-system.md` § 3.5's
  /// table stays at fifteen rows and a deep link to `/onboarding` still matches.
  ///
  /// The value is derived from the route constant, never spelled twice — § 9's rule is that
  /// `AppRoutes` is the only file that knows a path, and a hand-written
  /// `'/onboarding?step=disclosure'` here would be a second spelling that a rename of
  /// [onboarding] would silently orphan.
  static const String onboardingStepQuery = 'step';

  /// The value of [onboardingStepQuery] that opens on the disclosure.
  static const String disclosureStepValue = 'disclosure';

  // ⚠️ **A FUNCTION, LIKE EVERY OTHER LOCATION BUILDER BELOW** — `settingsReaderPath()`,
  // `downloadsPath()` — so nothing calls `GoRouter.push` with an interpolated literal.
  static String onboardingDisclosurePath() =>
      '$onboarding?$onboardingStepQuery=$disclosureStepValue';

  // ── locations, for `go()` ───────────────────────────────────────────────
  //
  // ⚠️ Ids are **not** URL-encoded, and that is a property rather than an
  // oversight: every id in this app is a 32-character MD5 (`SourceId`), so it
  // holds no character a path segment would need to escape. A builder that
  // started calling `Uri.encodeComponent` would be hiding a change of id scheme
  // instead of handling one — and it would then disagree with the stored id,
  // which is the thing that actually breaks.

  static String novelDetailsFor(String novelId) => '$_novelRoot/$novelId';

  static String sourceBrowseFor(String sourceId) => '$_sourceRoot/$sourceId';

  static String sourceGenreFor(String sourceId, String genre) =>
      '$_sourceRoot/$sourceId/genre/$genre';

  static String sourceUnavailableFor(String sourceId) =>
      '$_sourceRoot/$sourceId/unavailable';

  /// `/reader/<novelId>/<chapterId>` — the destination three screens push.
  static String readerFor(String novelId, String chapterId) =>
      '$readerRoot/$novelId/$chapterId';

  static String settingsReaderPath() => settingsReader;

  static String settingsAboutPath() => settingsAbout;

  static String downloadsPath() => downloads;
}
