// forge:slice 2-8
// Lumen Tale — `design-system.md` § 2.6 `ReaderControls`: back, size, theme, and nothing else.
//
// ## ⚠️ It lives in `features/reader/`, not in `core/ui/`, and that is a rule not a taste
//
// The plan's § 4.1 puts it in `core/ui/`. `02-architecture.md` says of `core/ui/`:
// *"it receives resolved values — it never calls a repository or a notifier"*, and
// `09-widgets-ui.md` rule 13 is narrower and explicit: *"into `core/ui/` if **shared across
// features**"*. This cluster is not shared — `settings-reader.md` § 3 **forbids** rendering
// it on the settings page ("two identical-looking things and the one distinction that
// separates them" would blur), so it has exactly one caller, and that caller is the reader.
//
// And it could not be shared even if it were: [sizeButton] and [themeButton] write the two
// stored values, which means the cluster calls notifiers. A `core/ui/` widget that called a
// notifier would be the thing `02-architecture.md` describes.
//
// ## ⚠️ THREE buttons, and the other three slots are absent on purpose
//
// § 2.6 names six slots: `progressSlider`, `chapterTitle`, `sizeButton`, `themeButton`,
// `chapterListButton`, `backButton`. Only the three whose behaviour exists are rendered.
// A control that does not work yet is worse than a control that has not been written
// (`settings.md`'s `Check now` precedent, finding F-012), so `progressSlider`,
// `chapterTitle` and `chapterListButton` arrive with the slices that own them.
//
// ## ⚠️ The two writes PROPAGATE, and the caller owns the sentence
//
// `ThemePersistenceException` is not an `AppException`, so there is no `on AppException` to
// catch here — § 3.4's `showSnackbar('error.write')` runs where the failure can be named
// and a *Try again* offered. This cluster's job is to be a control: apply the value, or
// refuse.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:lumen_tale/app/theme/lumen_colors.dart';
import 'package:lumen_tale/app/theme/lumen_spacing.dart';
import 'package:lumen_tale/app/theme/motion.dart';
import 'package:lumen_tale/app/theme/reader_display_copy.dart';
import 'package:lumen_tale/app/theme/reader_scale.dart';
import 'package:lumen_tale/app/theme/shadows.dart';
import 'package:lumen_tale/app/theme/theme_override.dart';
import 'package:lumen_tale/core/ui/app_error_copy.dart';
import 'package:lumen_tale/features/reader/domain/reader_preferences_controller.dart';
import 'package:lumen_tale/features/reader/domain/reader_theme_resolver.dart';
import 'package:lumen_tale/features/reader/widgets/reader_size_sheet.dart';
import 'package:lumen_tale/l10n/generated/app_localizations.dart';

/// The reader's revealed chrome.
///
/// ⚠️ **A `ConsumerWidget`, so it reads the stored values and writes through the seam.**
/// `05-state-management.md` rule 6: widgets consume providers and call notifiers. Its
/// `scale` and `themeOverride` are therefore *not* parameters — a caller that passed them
/// in would be a second answer to "what is stored", and the reader screen would have to
/// read the same two providers and hand them down.
class ReaderControls extends ConsumerWidget {
  const ReaderControls({
    required this.visible,
    required this.onBack,
    super.key,
  });

  /// Whether the reader has revealed the chrome. **Ephemeral** (`2-4` § 5): it is the
  /// screen's `State`, so returning to a chapter finds the controls hidden again.
  final bool visible;

  /// Leaves the chapter. Nothing is written here — `2-4`: the position was already written
  /// at the last settle, and a back press that writes is a write on the hot path.
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ReaderPreferencesController controller = ref.watch(
      readerPreferencesControllerProvider,
    );
    return _ChromeReveal(
      visible: visible,
      child: DecoratedBox(
        // ⚠️ **`--color-surface-raised`, one of only two things in the app with a shadow**
        // (`reader.md` § 2: the other is a dialog). The chrome floats over the prose; it is
        // the reader's raised surface, not the reader's own.
        decoration: BoxDecoration(
          color: LumenColors.of(context).surfaceRaised,
          boxShadow: LumenShadows.of(context).sheet,
        ),
        child: SafeArea(
          top: false,
          bottom: false,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: LumenSpacing.of(context).sm,
              vertical: LumenSpacing.of(context).xs2,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: <Widget>[
                IconButton(
                  key: const ValueKey<String>('reader-controls.back'),
                  onPressed: onBack,
                  icon: const Icon(Icons.arrow_back),
                  tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                ),
                _SizeButton(
                  scale: controller.scale,
                  onSelected: (ReaderTextScale step) async {
                    await _select(context, () => controller.selectScale(step));
                  },
                ),
                _ThemeButton(
                  value: controller.themeOverride,
                  // ⚠️ **The cycle, and nothing else.** `reader_theme_resolver.dart` owns
                  // the order; a second `switch` here would be a second definition of what
                  // one tap does, and the settings page's segments would be free to
                  // disagree about it.
                  onTap: () => _select(
                    context,
                    () => controller.selectOverride(
                      cycleThemeOverride(controller.themeOverride),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Runs a write and, if it fails, says so **with a way to try again**.
  ///
  /// ⚠️ **`on Object`, and a SnackBar rather than a field-level line.** The size sheet has
  /// its own inline error because it is still on screen when the write lands; the theme
  /// button has no surface of its own, so the failure needs a sentence that survives the
  /// chrome being dismissed. `settings.md` § 4 asks for a SnackBar on
  /// `--color-surface-raised` with `--shadow-sheet` naming what failed and offering *Try
  /// again* — and `13-error-handling.md` rule 5 says the sentence comes from the one mapper
  /// in `core/ui/`, which is [AppErrorCopy].
  Future<void> _select(
    BuildContext context,
    Future<void> Function() write,
  ) async {
    try {
      await write();
    } on Object {
      if (!context.mounted) {
        return;
      }
      final AppLocalizations l10n = AppLocalizations.of(context);
      final String? retry = l10n.recovery(AppErrorString.settingsWriteFailed);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.message(AppErrorString.settingsWriteFailed)),
          action: retry == null
              ? null
              : SnackBarAction(
                  label: retry,
                  // ⚠️ **Retry the WRITE, not the reader.** `tryAgain` is the same
                  // operation the failed tap attempted; re-reading the document would
                  // succeed and change nothing, which is the "a retry that cannot help"
                  // defect C12 exists to prevent.
                  onPressed: () => _select(context, write),
                ),
        ),
      );
    }
  }
}

/// The `sizeButton`: a glyph, and the five steps behind it.
class _SizeButton extends StatelessWidget {
  const _SizeButton({required this.scale, required this.onSelected});

  final ReaderTextScale scale;
  final Future<void> Function(ReaderTextScale step) onSelected;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return IconButton(
      key: const ValueKey<String>('reader-controls.size'),
      onPressed: () async {
        // ⚠️ **Only the write is handed in.** The checked step is watched by the sheet
        // itself: a modal route's builder runs once, so a `current:` captured here would be
        // a snapshot of the value at the moment the reader tapped the button.
        await showReaderSizeSheet(context, onSelected: onSelected);
      },
      icon: const Icon(Icons.format_size),
      // ⚠️ **The label names the CURRENT value**, for the same reason the theme button's
      // does: a label naming the *result* of the tap is true once and false twice.
      tooltip: l10n.readerSizeButtonTooltip(l10n.readerSizeLabel(scale)),
    );
  }
}

/// The `themeButton`: one tap, and the cycle is the button's whole behaviour.
class _ThemeButton extends StatelessWidget {
  const _ThemeButton({required this.value, required this.onTap});

  final ThemeOverride value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return IconButton(
      key: const ValueKey<String>('reader-controls.theme'),
      onPressed: onTap,
      // ⚠️ **The glyph is exhaustive over the three members, with no `default`.** A fourth
      // override is a compile error here rather than a button that shows day's sun while
      // the app is in night.
      icon: switch (value) {
        ThemeOverride.system => const Icon(Icons.brightness_auto_outlined),
        ThemeOverride.day => const Icon(Icons.light_mode_outlined),
        ThemeOverride.night => const Icon(Icons.dark_mode_outlined),
      },
      tooltip: l10n.readerThemeButtonTooltip(l10n.themeLabel(value)),
    );
  }
}

/// The chrome's reveal: `--duration-slow` in, **instant** under reduce-motion.
///
/// ## ⚠️ The reveal is the ONLY thing on the reader that animates
///
/// § 3.3: a change of **size** is 0 ms, a change of **theme** is 0 ms with no cross-fade, and
/// the *reveal of these controls* is `--duration-slow` 320 ms — or `0ms` when the reader has
/// asked the phone to stop moving things. A reader who judges a character needs to see it
/// **be** the new size; a fade on the prose is the one cost they cannot afford at 2am.
class _ChromeReveal extends StatefulWidget {
  const _ChromeReveal({required this.visible, required this.child});

  final bool visible;
  final Widget child;

  @override
  State<_ChromeReveal> createState() => _ChromeRevealState();
}

class _ChromeRevealState extends State<_ChromeReveal>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 320),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // ⚠️ **The duration is re-read on every dependency change**, because it is
    // `MediaQuery.disableAnimationsOf(context)` — a context read, not a parameter. Reading
    // it once in `initState` would fix 320 ms on a phone that has animations switched off.
    final LumenMotion motion = LumenMotion.of(context);
    _controller.duration = motion.duration(context, motion.slow);
    _controller.value = widget.visible ? 1 : 0;
  }

  @override
  void didUpdateWidget(_ChromeReveal oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.visible == oldWidget.visible) {
      return;
    }
    // ⚠️ **Forward with `animateTo`, back with `animateBack`.** A `TweenAnimationBuilder`
    // would re-run from wherever it was, so hiding mid-reveal would jump — and the chrome
    // is toggled by the reader tapping the prose, which is exactly what happens mid-reveal.
    if (widget.visible) {
      _controller.animateTo(1, curve: LumenMotion.of(context).standard);
    } else {
      _controller.animateBack(0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // ⚠️ **A `ListenableBuilder` around the `IgnorePointer` and nothing else.** The fade and
    // the clip listen to the controller themselves; what cannot listen is a **parameter**, and
    // `ignoring` is one — a bare `IgnorePointer(ignoring: _controller.value == 0)` captures
    // the value once and goes on swallowing the reading zone's taps after the chrome has gone.
    return ListenableBuilder(
      key: const ValueKey<String>('reader-controls.reveal'),
      listenable: _controller,
      builder: (BuildContext context, Widget? child) => IgnorePointer(
        // ⚠️ **Hidden means untappable, not invisible.** Opacity alone would leave an
        // invisible chrome eating taps on the prose beneath it — the reading zone's own
        // gesture — and three focus stops a switch-access reader can still reach.
        ignoring: _controller.value == 0,
        // ⚠️ **And hidden means NOT IN THE TREE**, once the animation has finished. The
        // fade needs the child to exist while it runs, so it is dropped at rest rather than
        // during — which keeps `2-4`'s "a second tap removes the chrome" true and stops a
        // hidden bar from costing the prose a row of screen height in the semantics tree.
        child: _controller.value == 0 ? const SizedBox.shrink() : child,
      ),
      child: FadeTransition(
        opacity: _controller,
        child: SizeTransition(
          // ⚠️ **`alignment`, and not the deprecated `axisAlignment`.** `topStart` rather
          // than `topLeft`, because the row inside is laid out with
          // `MainAxisAlignment.end` and is therefore direction-aware: a chrome that opened
          // from the left in an RTL locale would move opposite to its own contents.
          alignment: AlignmentDirectional.topStart,
          sizeFactor: _controller,
          child: widget.child,
        ),
      ),
    );
  }
}
