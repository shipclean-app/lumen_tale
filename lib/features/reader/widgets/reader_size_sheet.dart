// forge:slice 2-8
// Lumen Tale — the reader's `sizeButton` sheet: five steps, and the current one checked.
//
// ## ⚠️ It has NO local "pending" selection, and that is the whole design
//
// `settings-reader.md` § 4 (Submit error) states the invariant: **"the screen never shows
// a size or a theme it does not hold."** A sheet with a `_selected` field it updates on tap
// and rolls back on failure can be a frame away from holding what it shows — and the
// specimen is on the same stored value, so the two would disagree with each other and
// with the chapter.
//
// So the sheet renders the **stored** value — watched, not handed in — and nothing else.
// The write happens upstream (`ReaderTextScaleNotifier.select` writes, then mutates), so a
// failure cannot move the state and there is nothing here to undo. What the sheet does own
// is the one thing a control must do on its own: refuse a second tap while one is in
// flight. The failure itself is named by [ReaderControls], which owns the copy.
//
// ## ⚠️ `onSelected` throws, and this catches `Object`
//
// `ThemePersistenceException` is deliberately **not** an `AppException` — it is "the OS
// declined to write a byte", not a cause the UI maps by kind — so a narrower `on` clause
// would let it escape as an unhandled async error on a modal route, which is a silent
// no-op. The reader's tap would appear to have done nothing at all.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:lumen_tale/app/theme/lumen_colors.dart';
import 'package:lumen_tale/app/theme/lumen_radius.dart';
import 'package:lumen_tale/app/theme/lumen_spacing.dart';
import 'package:lumen_tale/app/theme/motion.dart';
import 'package:lumen_tale/app/theme/reader_display_copy.dart';
import 'package:lumen_tale/app/theme/reader_scale.dart';
import 'package:lumen_tale/app/theme/shadows.dart';
import 'package:lumen_tale/app/theme/theme_providers.dart';
import 'package:lumen_tale/l10n/generated/app_localizations.dart';

/// ⚠️ **A 56dp row, pinned with `minTileHeight` because that is what it is FOR.** Measured
/// rather than guessed: `dense: true` alone gives 64 for a two-line tile, and a visual
/// density is a *preference* applied to padding, so reaching a number through it means a
/// fractional density no reader of this file could explain. § 6's floor is 48; a step
/// carries a name **and** a pixel figure, so it is two lines and 56 is the Material
/// default for exactly that shape.
const double kReaderStepTileHeight = 56;

/// Opens the sheet. Returns the step the reader committed, or `null` if dismissed.
///
/// ⚠️ **A top-level function, not a static on [ReaderSizeSheet].** `ReaderSizeSheet.show(…)`
/// parses as a **named constructor** — the `Type.name(...)` form is always a constructor —
/// so a static method is unreachable under the spelling a caller naturally reaches for and
/// the analyzer says *"doesn't have a constructor named show"*. `settings_choice_sheet.dart`
/// records the same trap being hit for the same reason.
Future<void> showReaderSizeSheet(
  BuildContext context, {
  required Future<void> Function(ReaderTextScale step) onSelected,
}) {
  final LumenMotion motion = LumenMotion.of(context);
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    // ⚠️ **Transparent, because this sheet supplies its own surface.** The default is an
    // opaque sheet background, which would be a third surface this design system does not
    // have — and `reader.md` § 12 lists `--color-surface-raised` as the sheet's own.
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.32),
    // ⚠️ **`sheetAnimationStyle`, and not the framework default.** § 1.6: every duration
    // becomes `0ms` under the system's reduce-animations setting, and a bottom sheet that
    // still slides after the reader has asked the phone to stop moving things is the
    // framework default doing what the design system forbids. The style is read here, from
    // the caller's context, because the builder inside the route has no `LumenMotion` yet.
    sheetAnimationStyle: AnimationStyle(
      duration: motion.duration(context, motion.normal),
      reverseDuration: motion.duration(context, motion.fast),
      curve: motion.curve(context, motion.standard),
    ),
    builder: (BuildContext context) => ReaderSizeSheet(onSelected: onSelected),
  );
}

/// The five steps, in `ReaderTextScale`'s own order.
///
/// ## ⚠️ The checked step is WATCHED, and the plan's `current` prop is GONE
///
/// § 4.2 gives this widget a `current: ReaderTextScale` parameter, and it is wrong for a
/// route: the sheet's builder runs ONCE, so a value captured when it opened is a snapshot.
/// The first version did exactly that, and the defect stayed invisible until a row wrote a
/// step and then looked at the check — which had not moved while the store already held the
/// new value. A sheet showing 18 pt over an app holding 26 pt is § 4's worst outcome,
/// produced by a signature rather than by a decision.
///
/// So the stored step is watched from the provider that owns it, and the only thing handed in
/// is the write.
class ReaderSizeSheet extends ConsumerStatefulWidget {
  const ReaderSizeSheet({required this.onSelected, super.key});

  /// Applies a step. **Throws** on a failed write; [ReaderControls] names the failure.
  final Future<void> Function(ReaderTextScale step) onSelected;

  @override
  ConsumerState<ReaderSizeSheet> createState() => _ReaderSizeSheetState();
}

class _ReaderSizeSheetState extends ConsumerState<ReaderSizeSheet> {
  /// The step whose write is in flight, so a second tap cannot race the first.
  ReaderTextScale? _writing;

  /// The **stored** step. See the class header: there is deliberately no pending value.
  ReaderTextScale get _current => ref.watch(readerTextScaleProvider);

  Future<void> _choose(ReaderTextScale step) async {
    // ⚠️ **The same step twice is not a write.** § 5: *"the same step while already
    // selected → nothing. No write, no animation, no toast."* Re-writing a value the app
    // already holds costs a disk round trip to change nothing.
    if (step == _current || _writing != null) {
      return;
    }
    setState(() => _writing = step);

    try {
      await widget.onSelected(step);
    } on Object {
      // ⚠️ **Nothing is rolled back here, and that is why this handler is two lines.**
      // `_current` never moved: the notifier writes before it mutates, so the provider still
      // holds the stored step. Re-reading the store here would be a second source of the
      // same value.
      //
      // ⚠️ **The failure is NOT reported from here.** `settings-reader.md` § 4 (Submit error)
      // names ONE mechanism for this screen — a SnackBar naming what failed, with *Try
      // again* — and it is raised by `ReaderControls`, which owns the copy and the action.
      // An inline error line here as well would be the second mechanism for one failure, and
      // the reader would read the same refusal twice.
      if (!mounted) {
        return;
      }
    } finally {
      if (mounted) {
        setState(() => _writing = null);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final LumenColors colors = LumenColors.of(context);
    final LumenSpacing spacing = LumenSpacing.of(context);
    final LumenRadius radius = LumenRadius.of(context);

    return DecoratedBox(
      // ⚠️ **The shadow is `--shadow-sheet`, applied by a `DecoratedBox` and not by
      // `Material.elevation`.** § 1.4 keeps exactly two shadows in this app and gives them
      // fixed values; a Material elevation picks its own and would be a third.
      decoration: BoxDecoration(
        color: colors.surfaceRaised,
        borderRadius: BorderRadius.vertical(top: Radius.circular(radius.lg)),
        boxShadow: LumenShadows.of(context).sheet,
      ),
      child: Material(
        type: MaterialType.transparency,
        child: SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.only(bottom: spacing.md),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    spacing.lg,
                    spacing.lg,
                    spacing.lg,
                    spacing.sm,
                  ),
                  child: Text(
                    l10n.readerSizeSheetTitle,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    padding: EdgeInsets.zero,
                    // ⚠️ **The five members of the enum, in its declaration order.** The
                    // ladder is `ReaderTextScale`'s to define; a list here would be a
                    // second answer to "how many sizes are there", and a sixth step added
                    // to the enum would render a sheet that cannot reach it.
                    children: <Widget>[
                      for (final ReaderTextScale step in ReaderTextScale.values)
                        _ReaderSizeStep(
                          step: step,
                          selected: step == _current,
                          busy: step == _writing,
                          onTap: () => _choose(step),
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    spacing.lg,
                    spacing.sm,
                    spacing.lg,
                    0,
                  ),
                  child: Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: TextButton(
                      onPressed: () =>
                          // ⚠️ **Pops with no value.** The sheet is not a form: the write
                          // happened on the tap, so a returned "result" would be a second
                          // channel for a value the caller already holds.
                          Navigator.of(context).pop(),
                      child: Text(l10n.commonCancel),
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
}

/// One step: its name, its pixel figure, and whether it is the stored one.
class _ReaderSizeStep extends StatelessWidget {
  const _ReaderSizeStep({
    required this.step,
    required this.selected,
    required this.busy,
    required this.onTap,
  });

  final ReaderTextScale step;
  final bool selected;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final String name = l10n.readerSizeLabel(step);
    final String points = l10n.readerSizeStepPoints(
      pointSizeOf(step).toString(),
    );

    return Semantics(
      // ⚠️ **ONE node, labelled in words, and it says whether it is selected.** § 5:
      // *"Large, 20 pixels, not selected."* `ListTile` alone would announce the name and
      // the figure and leave the selection to a flag, and `excludeSemantics` is what stops
      // the tile's own nodes from being announced as a second, contradictory pair.
      container: true,
      button: true,
      selected: selected,
      inMutuallyExclusiveGroup: true,
      label: l10n.readerSizeStepSemantics(
        name,
        // ⚠️ **The SPOKEN figure, not the printed one.** § 5 writes "20 pixels"; the tile
        // prints "20pt". An abbreviation a screen reader has to guess at is not the same
        // string, so it is not the same key.
        l10n.readerSizePixelsSpoken(pointSizeOf(step).toString()),
        selected ? l10n.readerSizeStepSelected : l10n.readerSizeStepNotSelected,
      ),
      excludeSemantics: true,
      // ⚠️ **The tap is on BOTH.** A screen reader activates the semantics action and
      // never reaches the widget; a finger reaches the `ListTile` and never the semantics
      // node. Wiring one and not the other is how a control ends up announcing an action
      // it does not have.
      onTap: onTap,
      child: ListTile(
        key: ValueKey<String>('reader-size-step-${step.name}'),
        minTileHeight: kReaderStepTileHeight,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        selected: selected,
        // ⚠️ **A check, not a tint alone.** `14-design-tokens.md` §Accessibility: selection
        // is never carried by colour on its own. The accent colour is there too; the glyph
        // is what makes it readable without it.
        leading: SizedBox(
          width: 24,
          child: busy
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(
                  Icons.check,
                  size: 20,
                  // ⚠️ **Painted in the accent, not swapped for another glyph.** The five
                  // rows keep one rhythm and the eye does not jump sideways when the check
                  // appears; the unselected rows carry the same icon at zero alpha.
                  color: selected
                      ? LumenColors.of(context).accent
                      : const Color(0x00000000),
                ),
        ),
        title: Text(name, style: Theme.of(context).textTheme.bodyLarge),
        // ⚠️ **The figure is its own line and it never truncates.** § 6: it is the one
        // thing the reader can check against the phone's own font slider, so a step whose
        // figure is cut off is worse than a taller row.
        subtitle: Text(
          points,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: LumenColors.of(context).textSecondary,
          ),
        ),
        onTap: onTap,
      ),
    );
  }
}
