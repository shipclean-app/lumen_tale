// Lumen Tale — the five bottom-nav destinations, as data.
//
// ⚠️ **The order comes from `state.json`'s `set-nav` record and from ADR-018, and
// it is not re-derived here.** Two sources already say it, and they agree:
// `design-system.md` § 3.2 (rank, frequency, centrality, EN/FR labels) and the
// machine-readable `index.nav`. A third derivation would be a second source of
// truth for nav order — which is the exact defect ADR-018 was written to end, and
// re-introducing it inside the slice that implements it would be the worst
// possible place to do it.
//
// `rank` is therefore **asserted against declaration order in both directions**,
// so if anyone adds an enum value in the wrong place the test fails rather than
// the bar silently reordering.

import 'package:flutter/material.dart';

import 'package:lumen_tale/app/router/app_routes.dart';
import 'package:lumen_tale/l10n/generated/app_localizations.dart';

/// One bottom-nav destination.
enum AppNavDestination {
  /// Rank 1, frequency 5, centrality 5. **Opens the loop**: a returning reader's
  /// most frequent action is resuming, not discovering. First because it has the
  /// highest frequency *and* because it is the only screen that can open the
  /// loop rather than summarise it — `archetypes.md` § 2's "écran d'accueil qui
  /// est un sommaire".
  library(
    path: AppRoutes.library,
    rank: 1,
    frequency: 5,
    centrality: 5,
    icon: Icons.auto_stories_outlined,
    selectedIcon: Icons.auto_stories,
  ),

  /// Rank 2, frequency 4, centrality 4. "Did my serialised novels move?" — the
  /// new-before-past rule.
  updates(
    path: AppRoutes.updates,
    rank: 2,
    frequency: 4,
    centrality: 4,
    icon: Icons.new_releases_outlined,
    selectedIcon: Icons.new_releases,
  ),

  /// Rank 3, frequency 4, centrality 2. Also a resume surface, but **past** tense,
  /// so it sits below Updates.
  history(
    path: AppRoutes.history,
    rank: 3,
    frequency: 4,
    centrality: 2,
    icon: Icons.history_outlined,
    selectedIcon: Icons.history,
  ),

  /// Rank 4, frequency 3, centrality 3. The only way to add a novel.
  browse(
    path: AppRoutes.browse,
    rank: 4,
    frequency: 3,
    centrality: 3,
    icon: Icons.explore_outlined,
    selectedIcon: Icons.explore,
  ),

  /// Rank 5, frequency 2, centrality 1. Lifecycle and configuration, lowest
  /// frequency **by design**: nothing in here is part of the reading loop.
  more(
    path: AppRoutes.more,
    rank: 5,
    frequency: 2,
    centrality: 1,
    icon: Icons.more_horiz_outlined,
    selectedIcon: Icons.more_horiz,
  );

  const AppNavDestination({
    required this.path,
    required this.rank,
    required this.frequency,
    required this.centrality,
    required this.icon,
    required this.selectedIcon,
  });

  /// The tab root. A location, always — never a pattern.
  final String path;

  /// 1-based position in the bar. `state.json`'s `set-nav` `rank`, transcribed.
  final int rank;

  /// How often the reader uses this destination. Recorded because the order is an
  /// argument: a reader who cannot see why Library is first cannot tell whether
  /// the order was reasoned or defaulted.
  final int frequency;

  /// How much of the loop depends on it. Centrality is not frequency, and
  /// conflating them is how a "check my library" screen ends up above "browse for
  /// something new".
  final int centrality;

  /// ⚠️ **`design-system.md` § 3.2 gives labels, not icons.** These are this
  /// slice's choice, from the bundled Material set (`conventions.md`: "Icons:
  /// Material Icons (bundled)"), one outlined/filled pair per destination. The
  /// design rule they must respect is "no icon-in-a-circle as decoration", which
  /// a Material `NavigationBar` satisfies by construction — it draws no circle.
  final IconData icon;
  final IconData selectedIcon;

  /// The localized label. **Never a literal** — `16-i18n.md` rule 1, and B28:
  /// every user-visible string exists in French and English.
  ///
  /// `navMore` is read here and is written by this slice, in both ARB files in the
  /// same commit (`16-i18n.md` rule 2). It was missing: `0-5` § 7 question 3
  /// recorded that four of the five tab labels existed and the fifth did not, and
  /// a fifth tab with no label in two languages violates B28 directly — the test
  /// in `test/app/router/app_router_test.dart` is what made it visible.
  String label(AppLocalizations l10n) => switch (this) {
    AppNavDestination.library => l10n.navLibrary,
    AppNavDestination.updates => l10n.navUpdates,
    AppNavDestination.history => l10n.navHistory,
    AppNavDestination.browse => l10n.navBrowse,
    AppNavDestination.more => l10n.navMore,
  };
}

/// The order ADR-018 fixes.
///
/// `AppNavDestination.values` is declaration order, which **is** the rank order —
/// and that equivalence is asserted in both directions in the test, so an enum
/// value added in the wrong place fails rather than reordering the bar quietly.
const List<AppNavDestination> appNavDestinations = AppNavDestination.values;
