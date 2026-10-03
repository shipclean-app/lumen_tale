// Lumen Tale — the single-value picker for a `navigate` row that cannot name its own
// answer in the value line.
//
// `design-system.md` § 2.12. Its rows ARE `HistoryRetention`'s values and its warning
// sentence comes from `HistoryRetentionStore.countOlderThan`, both declared in `6-5`
// — so **this file is owned by `6-5`, not by `3-7`**, and `3-7` imports it. That is
// the only direction the edge can take: `3-7` already reads `HistoryRetention` and
// `HistoryRetentionStore` from `6-5`, so the reverse edge would close a cycle.
//
// ## Why it is generic over `T` and not a `HistoryRetention` sheet
//
// § 2.12 says the shape is for "a set of short named values with nothing to
// demonstrate" and names **one** such value in v1. Writing the widget against that
// enum would make the *component* a second statement of which five windows exist,
// beside the enum — and a sixth window added to `HistoryRetention` would then need
// three edits where the design says a screen may not restate the list at all.
//
// So the widget knows nothing about time. It takes options, a selection, a label
// function, and a warning function; `6-5` supplies all four from the enum. A
// reviewer can see there is no list of windows in this file, which is the property
// the rule exists to protect.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:lumen_tale/app/theme/lumen_colors.dart';
import 'package:lumen_tale/app/theme/lumen_radius.dart';
import 'package:lumen_tale/app/theme/lumen_spacing.dart';
import 'package:lumen_tale/app/theme/shadows.dart';
import 'package:lumen_tale/l10n/generated/app_localizations.dart';

/// One row of the sheet.
@immutable
class SettingsChoiceOption<T> {
  const SettingsChoiceOption({
    required this.value,
    required this.label,
    this.description,
    this.enabled = true,
  });

  /// The value this row selects. Written back to the store, never rendered.
  final T value;

  /// What the reader reads. Localized by the caller, never an enum `name`.
  final String label;

  /// Optional second line. `null` for retention — the warning sentence above the
  /// rows already carries the effect, and repeating it per row would say the same
  /// thing five times.
  final String? description;

  /// § 2.12's `disabled` state: the label goes `--color-text-disabled` and the row is
  /// not selectable.
  ///
  /// ⚠️ **A real state, not a defensive one.** v1 has no disabled retention window,
  /// and a row that exists because a caller might someday want one is not the same as
  /// a row that renders a value the app cannot honour.
  final bool enabled;
}

/// The sheet.
///
/// [onSelected] **applies** the value — it is the write, not a notification of a
/// decision the caller has already made. The reason is § 11.1's *Submit error* state:
/// *"a preference write that fails keeps the sheet open on the **previous** window
/// with a field-level error, and never applies a window the app cannot remember."*
/// A sheet that popped before the write and told the caller afterwards has already
/// closed by the time the failure arrives, so the promise could not be kept.
class SettingsChoiceSheet<T extends Object> extends StatefulWidget {
  const SettingsChoiceSheet({
    super.key,
    required this.title,
    required this.options,
    required this.selected,
    required this.labelOf,
    required this.warningFor,
    required this.onSelected,
    this.descriptionOf,
  });

  /// The sheet's own title. A sheet does not get its title from the screen that
  /// opened it — the same five windows have two call sites, and one of them shows
  /// this sheet from inside a notice rather than from under a row label.
  final String title;

  /// The rows, in display order. Never reordered by the sheet.
  final List<SettingsChoiceOption<T>> options;

  /// The **committed** value. The checkmark follows this, not a local preview, so a
  /// failed write snaps it back rather than leaving a checkmark on a value the app
  /// cannot remember.
  final T selected;

  /// The reader-facing name of a value, for the warning sentence.
  ///
  /// ⚠️ Takes a `T` and returns a **localized** `String`, and that signature is the
  /// contract: `threeMonths` inside a French sentence is a string the app learned
  /// from its own code.
  final String Function(T value) labelOf;

  /// The sentence above the rows, rewritten as the selection moves.
  ///
  /// A `String Function(T)` and not a `String`, for § 11.1's *"the sentence is
  /// rewritten in place as the selection moves"* — a fixed sentence would describe
  /// the committed window while the reader is looking at a different one.
  final String Function(T value) warningFor;

  /// The per-row effect line. `null` renders no description, which is the state
  /// retention is in.
  final String? Function(T value)? descriptionOf;

  /// Applies a value. Throwing leaves the sheet open with a field-level error and
  /// the committed value unchanged — B24, C8.
  final Future<void> Function(T value) onSelected;

  @override
  State<SettingsChoiceSheet<T>> createState() => _SettingsChoiceSheetState<T>();
}

/// Opens the sheet. Returns the committed value, or `null` if dismissed.
///
/// ⚠️ **A top-level function, not a static on [SettingsChoiceSheet].**
/// `SettingsChoiceSheet<T>.show(…)` parses as a **named constructor** in Dart — the
/// `Type.name(...)` form is always a constructor — so a static method is unreachable
/// under the spelling a caller naturally reaches for, and the analyzer says
/// *"doesn't have a constructor named show"*. The call site said what it meant; the
/// language disagreed.
Future<T?> showSettingsChoiceSheet<T extends Object>(
  BuildContext context, {
  required String title,
  required List<SettingsChoiceOption<T>> options,
  required T selected,
  required String Function(T value) labelOf,
  required String Function(T value) warningFor,
  required Future<void> Function(T value) onSelected,
  String? Function(T value)? descriptionOf,
}) {
  return showModalBottomSheet<T>(
    context: context,
    // ⚠️ `isScrollControlled` so a short sheet does not take the whole screen, and
    // `backgroundColor: Colors.transparent` because the sheet's own `DecoratedBox`
    // supplies the raised surface. A `showModalBottomSheet` default of white-on-white
    // would be a third surface this design system does not have.
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.32),
    builder: (BuildContext context) => SettingsChoiceSheet<T>(
      title: title,
      options: options,
      selected: selected,
      labelOf: labelOf,
      warningFor: warningFor,
      descriptionOf: descriptionOf,
      onSelected: onSelected,
    ),
  );
}

class _SettingsChoiceSheetState<T extends Object>
    extends State<SettingsChoiceSheet<T>> {
  /// The committed value. `null` until the first successful write.
  ///
  /// ⚠️ **Not the same field as a "pending" selection.** There is no pending
  /// selection: a tap *commits*, and a commit either lands or throws. A sheet with a
  /// local preview and an *Apply* button would have a state where the reader has
  /// chosen something the app has not stored — which is exactly the state C8
  /// forbids, reached one step earlier.
  T? _committed;

  /// § 11.1's *field-level error*. Non-null only after a failed write.
  String? _error;

  /// The row being written, so a second tap cannot race the first.
  ///
  /// ⚠️ `null` means idle. Without it a double-tap on a slow disk writes twice and
  /// can leave the store holding the second value while the sheet shows the first.
  T? _writing;

  @override
  void initState() {
    super.initState();
    _committed = widget.selected;
  }

  @override
  void didUpdateWidget(SettingsChoiceSheet<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    // ⚠️ Adopt the parent's value only when it is **not** ours: the parent does not
    // rebuild while a write is in flight, and a `didUpdateWidget` that reset
    // `_committed` unconditionally would undo the rollback below.
    if (!identical(oldWidget.selected, widget.selected) && _error == null) {
      _committed = widget.selected;
    }
  }

  Future<void> _choose(SettingsChoiceOption<T> option) async {
    // ⚠️ **The only place a choice is refused**, and it refuses on two counts:
    // `enabled` is the row's own claim (a disabled option is not a choice), and
    // `_writing` is the re-entrancy claim (a second tap on a slow disk would write
    // twice and can leave the store holding the second value while the sheet shows
    // the first).
    if (!option.enabled || identical(_writing, option.value)) {
      return;
    }

    final T previous = _committed as T;
    if (identical(previous, option.value) && _error == null) {
      return;
    }

    setState(() {
      _writing = option.value;
      _error = null;
    });

    try {
      await widget.onSelected(option.value); // throws before any state mutation
      if (!mounted) {
        return;
      }
      // C8: only now does the sheet know the value exists.
      setState(() {
        _committed = option.value;
        _writing = null;
      });
    } on Object {
      // ⚠️ **Catch `Object`, not `Exception` and not `AppException`.**
      //
      // The failure this state exists for is `SettingsPersistenceException`, which is
      // deliberately *not* an `AppException` (`shared_prefs_history_retention.dart`):
      // it is "the OS declined to write a byte", not a cause the UI maps by kind. A
      // narrower `on` clause would let that one escape as an unhandled async error,
      // which on a modal sheet means a silent no-op — the sheet would sit there
      // looking unchanged with no explanation, and the reader's tap would have
      // appeared to do nothing at all.
      if (!mounted) {
        return;
      }
      setState(() {
        _committed = previous; // the snap-back: B24, C8
        _writing = null;
        _error = AppLocalizations.of(context).errorSettingsWrite;
      });
    }
  }

  final Map<T, FocusNode> _focusNodes = <T, FocusNode>{};

  FocusNode _focusNodeFor(SettingsChoiceOption<T> option) =>
      _focusNodes.putIfAbsent(option.value, () => FocusNode(debugLabel: 'row'));

  /// § 2.12's `focused` state: **arrow keys move, `Enter` selects** — and they
  /// **wrap**, so ↓ on the last enabled row reaches the first and ↑ on the first
  /// reaches the last.
  ///
  /// ⚠️ A picker whose arrow keys stop at the ends is a dead end a keyboard user has
  /// to discover and then work around forever, and the wrap is two more lines than
  /// the clamp.
  void _moveFocus(int delta) {
    if (_writing != null || widget.options.isEmpty) {
      return;
    }
    final int firstEnabled = widget.options.indexWhere(
      (SettingsChoiceOption<T> option) => option.enabled,
    );
    if (firstEnabled < 0) {
      return; // every row disabled: nothing to move to
    }

    // ⚠️ **The current row is the FOCUSED one, not the committed one.**
    //
    // On this screen focus and selection are different things: pressing ↓ moves
    // focus and selects nothing. Tracking `_committed` here would make ↓ alternate
    // between the committed row and the next one, forever — from *one year*, ↓ would
    // land on *two years* twice and never reach *one week*.
    final FocusNode? primary = FocusManager.instance.primaryFocus;
    final int focused = widget.options.indexWhere(
      (SettingsChoiceOption<T> option) =>
          option.enabled && identical(_focusNodes[option.value], primary),
    );
    final int committed = widget.options.indexWhere(
      (SettingsChoiceOption<T> option) => identical(option.value, _committed),
    );
    final int from = focused >= 0
        ? focused
        : (committed >= 0 ? committed : firstEnabled);

    final int count = widget.options.length;
    final int wrapped = ((from + delta) % count + count) % count;

    // ⚠️ **Walk in the direction of travel until a row is enabled.**
    //
    // Falling back to "the first enabled row" would jump *backwards* past the rows
    // between, so ↓ onto a disabled row could move focus up the list — the arrow the
    // reader pressed would carry them the other way. Walking keeps the key's meaning
    // and terminates because the caller has already established that at least one row
    // is enabled.
    int target = wrapped;
    while (!widget.options[target].enabled) {
      target = ((target + delta) % count + count) % count;
    }
    _focusNodeFor(widget.options[target]).requestFocus();
  }

  void _selectFocused(T value) {
    _choose(
      widget.options.firstWhere(
        (SettingsChoiceOption<T> option) => identical(option.value, value),
      ),
    );
  }

  @override
  void dispose() {
    for (final FocusNode node in _focusNodes.values) {
      node.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final LumenColors colors = LumenColors.of(context);
    final LumenSpacing spacing = LumenSpacing.of(context);
    final LumenRadius radius = LumenRadius.of(context);
    final T committed = _committed as T;

    return DecoratedBox(
      // ⚠️ **The shadow is `--shadow-sheet`, and it is applied by a `DecoratedBox`,
      // not by `Material.elevation`.** § 1.4 keeps exactly two shadows in this app
      // and gives them fixed values; a Material elevation would pick its own and
      // there would be a third shadow nobody approved.
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
                    spacing.md,
                  ),
                  child: Text(
                    widget.title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                // ⚠️ **The warning sentence, above the rows, keyed on the committed
                // value.** It is the whole reason this sheet exists rather than a
                // plain radio group: the reader must see the effect of a window
                // *before* choosing it, and the effect is a sentence, not a name.
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: spacing.lg),
                  child: Text(
                    widget.warningFor(committed),
                    key: const Key('settingsChoiceSheet.warning'),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                if (_error != null)
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      spacing.lg,
                      spacing.md,
                      spacing.lg,
                      0,
                    ),
                    child: Text(
                      _error!,
                      key: const Key('settingsChoiceSheet.error'),
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: colors.error),
                    ),
                  ),
                Flexible(
                  child: Focus(
                    // ⚠️ The arrow keys are handled **here**, at the sheet, rather than
                    // on each row: a row that handled its own arrows would have to
                    // know its own position in the list, which is state the sheet owns.
                    onKeyEvent: (FocusNode node, KeyEvent event) {
                      if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
                        return KeyEventResult.ignored;
                      }
                      switch (event.logicalKey) {
                        case LogicalKeyboardKey.arrowDown:
                          _moveFocus(1);
                          return KeyEventResult.handled;
                        case LogicalKeyboardKey.arrowUp:
                          _moveFocus(-1);
                          return KeyEventResult.handled;
                        default:
                          return KeyEventResult.ignored;
                      }
                    },
                    child: ListView.builder(
                      shrinkWrap: true,
                      padding: EdgeInsets.only(top: spacing.sm),
                      itemCount: widget.options.length,
                      itemBuilder: (BuildContext context, int index) {
                        final SettingsChoiceOption<T> option =
                            widget.options[index];
                        return _ChoiceRow<T>(
                          option: option,
                          selected: identical(option.value, committed),
                          busy: identical(option.value, _writing),
                          focusNode: _focusNodeFor(option),
                          onTap: () => _choose(option),
                          description: widget.descriptionOf?.call(option.value),
                          onActivate: () => _selectFocused(option.value),
                        );
                      },
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    spacing.lg,
                    spacing.md,
                    spacing.lg,
                    0,
                  ),
                  child: Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pop(committed),
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

/// One row: a radio, a label, an optional effect line.
///
/// Split out of the sheet so it can hold its own `pressed` state — a sheet that
/// tracks press state for all five rows in one `State` would rebuild all five when
/// one is pressed.
class _ChoiceRow<T extends Object> extends StatefulWidget {
  const _ChoiceRow({
    required this.option,
    required this.selected,
    required this.busy,
    required this.focusNode,
    required this.onTap,
    required this.onActivate,
    required this.description,
  });

  final SettingsChoiceOption<T> option;
  final bool selected;
  final bool busy;
  final FocusNode focusNode;
  final VoidCallback onTap;
  final VoidCallback onActivate;
  final String? description;

  @override
  State<_ChoiceRow<T>> createState() => _ChoiceRowState<T>();
}

class _ChoiceRowState<T extends Object> extends State<_ChoiceRow<T>> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final LumenColors colors = LumenColors.of(context);
    final LumenSpacing spacing = LumenSpacing.of(context);

    final Color labelColor = !widget.option.enabled
        ? colors.textDisabled
        : colors.textPrimary;
    final Color descriptionColor = !widget.option.enabled
        ? colors.textDisabled
        : colors.textSecondary;

    return Semantics(
      // § 2.12's four states in the semantics tree as well as in the pixels: a radio
      // row is a `radio` with `inMutuallyExclusiveGroup`, and the disabled row is
      // `enabled: false` so a screen reader refuses it rather than announcing a row
      // that does nothing.
      inMutuallyExclusiveGroup: true,
      checked: widget.selected,
      enabled: widget.option.enabled,
      selected: widget.selected,
      label: widget.option.label,
      child: Focus(
        focusNode: widget.focusNode,
        canRequestFocus: widget.option.enabled,
        onKeyEvent: (FocusNode node, KeyEvent event) {
          if (event is KeyDownEvent &&
              (event.logicalKey == LogicalKeyboardKey.enter ||
                  event.logicalKey == LogicalKeyboardKey.space)) {
            widget.onActivate();
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: GestureDetector(
          onTapDown: widget.option.enabled
              ? (TapDownDetails _) => setState(() => _pressed = true)
              : null,
          onTapUp: widget.option.enabled
              ? (TapUpDetails _) => setState(() => _pressed = false)
              : null,
          onTapCancel: widget.option.enabled
              ? () => setState(() => _pressed = false)
              : null,
          onTap: widget.onTap,
          // ⚠️ **The press feedback is gated, the tap is not.** A disabled control
          // must not acknowledge a finger — no sunken surface, no ripple — and it
          // must also not be *reachable*, so the tap is wired unconditionally and the
          // refusal lives in one place: [\_SettingsChoiceSheetState.\_choose], which is
          // the state machine's rule rather than the row's presentation.
          //
          // Gating `onTap` here instead would make the row the second place that
          // decides "may this be chosen", and the two would be free to disagree.
          child: Container(
            constraints: const BoxConstraints(minHeight: 48),
            color: _pressed ? colors.surfaceSunken : Colors.transparent,
            padding: EdgeInsets.symmetric(
              horizontal: spacing.lg,
              vertical: spacing.md,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Padding(
                  padding: EdgeInsets.only(top: spacing.xs2),
                  child: ExcludeSemantics(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: widget.selected
                                ? colors.accent
                                : colors.borderField,
                            width: 2,
                          ),
                          color: widget.selected
                              ? colors.accent
                              : Colors.transparent,
                        ),
                        child: widget.selected
                            ? Icon(
                                Icons.check,
                                size: 14,
                                color: colors.surfaceRaised,
                              )
                            : null,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: spacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        widget.option.label,
                        style: Theme.of(
                          context,
                        ).textTheme.bodyLarge?.copyWith(color: labelColor),
                      ),
                      if (widget.description != null) ...<Widget>[
                        SizedBox(height: spacing.xs),
                        Text(
                          widget.description!,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: descriptionColor),
                        ),
                      ],
                    ],
                  ),
                ),
                if (widget.busy)
                  Padding(
                    padding: EdgeInsets.only(left: spacing.sm),
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: colors.accent,
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
