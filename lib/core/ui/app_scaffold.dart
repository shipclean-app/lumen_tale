// Lumen Tale — the one scaffold every screen returns.
//
// `.forge/design/design-system.md` § 2.8, with its six slots and three states.
//
// ⚠️ **This is the only `Scaffold` in the app.** `AppShell` is a `Column`, not a
// `Scaffold` (see `app_shell.dart`): two stacked `Scaffold`s means two
// `SafeArea`s and the shell's nav bar ends up under the screen's own.

import 'package:flutter/material.dart';

/// The app's screen frame. Six slots, three states.
///
/// **A screen sets `titleBar` OR `readerChrome`, never both** — that is the
/// component's whole rule, and it is why the reader is a screen with its own
/// chrome rather than a title bar plus a toolbar.
class AppScaffold extends StatelessWidget {
  const AppScaffold({
    super.key,
    this.titleBar,
    required this.content,
    this.floatingAction,
    this.bottomNav,
    this.persistentStatus,
    this.readerChrome,
    this.showBottomNav = true,
    this.state = AppScaffoldState.normal,
  });

  /// The title bar. `null` in the [AppScaffoldState.immersive] state.
  final PreferredSizeWidget? titleBar;

  /// The screen itself.
  final Widget content;

  /// A single action, bottom-right. One, never two: a screen with two would be a
  /// screen with a decision to make that the frame should not make.
  final Widget? floatingAction;

  /// The bottom navigation, on main destinations only.
  ///
  /// Supplied by [AppShell], never by a feature. It is a slot here rather than
  /// something the shell reaches into, because `design-system.md` § 2.8 names it.
  final Widget? bottomNav;

  /// Download progress, above [bottomNav] — § 2.8's `persistentStatus` slot.
  /// Owned by the downloads slice; wired here, empty until then.
  final Widget? persistentStatus;

  /// The reader's own chrome. **Mutually exclusive with [titleBar].**
  final PreferredSizeWidget? readerChrome;

  /// Whether to draw [bottomNav] at all.
  ///
  /// ⚠️ **Ignored in [AppScaffoldState.immersive].** `/reader/…` and `/onboarding`
  /// are outside the shell, so `AppShell` never reaches them and passes no bar —
  /// but `showBottomNav` defaults to `true`, and a screen that forgets to set the
  /// state would still get one. `design-system.md` § 2.8 is explicit: `immersive`
  /// replaces `titleBar` **and** `bottomNav`, unconditionally. So the state wins,
  /// and the flag is only consulted in the states where a bar is possible.
  final bool showBottomNav;

  final AppScaffoldState state;

  /// The nav to draw, or `null`. One place decides, and it is here.
  Widget? get _bottomNavigationBar => switch (state) {
    // `immersive` never shows a bottom nav, whatever was passed.
    AppScaffoldState.immersive => null,
    _ =>
      showBottomNav && bottomNav != null
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                // Above the bar, never below: § 2.8's `busy` state puts download
                // progress where the reader looks for the bar it is waiting behind.
                // Above the bar, never below: § 2.8's `busy` state puts download
                // progress where the reader looks for the bar it is waiting behind.
                ?persistentStatus,
                bottomNav!,
              ],
            )
          : null,
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: switch (state) {
        AppScaffoldState.immersive => readerChrome,
        _ => titleBar,
      },
      // `09-widgets-ui.md` § Platform behaviour: `SafeArea(bottom: false)` when
      // the nav is present, because the nav handles its own inset. Leaving the
      // inset in as well double-pads the content by one gesture bar.
      body: SafeArea(bottom: _bottomNavigationBar != null, child: content),
      floatingActionButton: floatingAction,
      bottomNavigationBar: _bottomNavigationBar,
    );
  }
}

/// The three states `design-system.md` § 2.8 names, and no others.
///
/// The enum is `final`, so a fourth state cannot be added by accident — a state
/// with no design behind it is a state nobody specified.
enum AppScaffoldState {
  /// `titleBar` + `content` + `bottomNav`.
  normal,

  /// `readerChrome` instead of `titleBar`, **and** no `bottomNav`.
  immersive,

  /// A download is running: [AppScaffold.persistentStatus] appears above
  /// [AppScaffold.bottomNav].
  busy,
}
