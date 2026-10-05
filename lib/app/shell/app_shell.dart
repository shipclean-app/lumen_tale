// Lumen Tale — the bottom navigation bar, and nothing else.
//
// Five destinations, ADR-018's order, one `NavigationBar`. No drawer:
// `design-system.md` § 3.1 — "a drawer would hide the destinations that carry the
// loop".

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:lumen_tale/app/router/app_nav_destinations.dart';
import 'package:lumen_tale/l10n/generated/app_localizations.dart';

/// ⚠️ **No rail, ever — ADR-019.** ≥600dp the bar stays at the bottom and stays
/// five items (`design-system.md` § 3.2). There is **no** width at which a rail
/// becomes correct here, and that is the reason the omission is written down
/// rather than left implicit: putting a rail back is not a responsive decision,
/// it is the thing ADR-019 removed.
///
/// ⚠️ **Not a `Scaffold`.** Every screen already returns an `AppScaffold`, which is
/// one. A `Scaffold` here would stack a second one, give the child two
/// `SafeArea`s, and put the nav bar underneath the screen's own — three symptoms
/// and one cause.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Expanded(child: navigationShell),
        _BottomNav(
          currentIndex: navigationShell.currentIndex,
          onSelected: (int index) => navigationShell.goBranch(
            index,
            // Tapping the tab the reader is already on pops that branch to its
            // root. It is the platform behaviour, and it is the only way back from
            // a deep stack with no back button in reach (C11: reading is one-handed).
            initialLocation: index == navigationShell.currentIndex,
          ),
          destinations: appNavDestinations,
        ),
      ],
    );
  }
}

/// The `NavigationBar`. **Private on purpose** — the bar is `AppShell`'s
/// implementation, and a public `NavigationBar` in `app/` would be a second way to
/// build the same thing, free to disagree about order.
class _BottomNav extends StatelessWidget {
  const _BottomNav({
    required this.currentIndex,
    required this.onSelected,
    required this.destinations,
  });

  final int currentIndex;
  final ValueChanged<int> onSelected;
  final List<AppNavDestination> destinations;

  @override
  Widget build(BuildContext context) {
    // Read once, not cached per destination: a cached `String` label would keep
    // the previous language's text after E12's switch.
    final AppLocalizations l10n = AppLocalizations.of(context);

    return NavigationBar(
      selectedIndex: currentIndex,
      // `design-system.md` § 3.4: horizontal slide, `--duration-normal` 200ms.
      // `go_router` owns the transition; this widget adds no `AnimationController`
      // on top of it, because a second animation over the same transition is a
      // duration the design system does not declare.
      onDestinationSelected: onSelected,
      destinations: <NavigationDestination>[
        for (final AppNavDestination destination in destinations)
          NavigationDestination(
            icon: Icon(destination.icon),
            selectedIcon: Icon(destination.selectedIcon),
            // Never a literal — `16-i18n.md` rule 1, B28.
            label: destination.label(l10n),
          ),
      ],
    );
  }
}
