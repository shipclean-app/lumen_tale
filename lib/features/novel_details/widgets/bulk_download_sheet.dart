// Lumen Tale — `BulkDownloadSheet`: B18's six choices, each with its count.
//
// `5-1` § 4.2 / § 4.3, from `novel-details.md` § 11.1. `features/novel_details/widgets/` —
// it is a novel's sheet, and it opens from the novel's own `Slot 2`.
//
// ## ⚠️ IT COMPUTES NOTHING
//
// Every count on every row is `resolveBulkChoice(choice).length`, produced by
// `domain/downloads/bulk_choice_rows.dart` before this widget is built. A `min(5, total)`
// written here would be a second implementation of the resolver's `take(count)`, and a
// displayed count that disagrees with the enqueued one is the defect C8 names — one that
// only shows up on the fortieth chapter of a download nobody is watching.
//
// ## ⚠️ THE LABELS COME IN, AND THE ARB LIVES WITH THE CALLER
//
// [labelOf] is the same shape `SettingsChoiceSheet.labelOf` uses. The widget holds no
// string of its own but *Cancel*, so the six rows' French wording is one file's business
// and a seventh choice cannot be added here without the words existing.
//
// ## ⚠️ **`Empty` IS NOT A STATE, AND `Offline` IS ONE**
//
// § 11.1 verbatim: *"Empty — not a state, because a novel with zero unopened chapters
// still has Next chapter available and the sheet says so rather than presenting an empty
// list of options"*; *"Offline — identical, with every option disabled at 48dp and one
// sentence"*. So [offline] disables the rows and shows one sentence, and a novel with
// nothing to download keeps all five rows visible with their counts at zero.
//
// ## ⚠️ **NO `EMPTY` STATE, NO `LOADING` STATE, AND NO `LOAD ERROR` STATE**
//
// Every count comes from stored chapter metadata the caller already holds, so there is
// nothing to load and nothing that can fail to load. Writing those states would be three
// widgets nothing could ever reach.

import 'package:flutter/material.dart';
import 'package:lumen_tale/app/theme/lumen_colors.dart';
import 'package:lumen_tale/app/theme/lumen_spacing.dart';
import 'package:lumen_tale/domain/downloads/bulk_choice.dart';
import 'package:lumen_tale/domain/downloads/bulk_choice_rows.dart';
import 'package:lumen_tale/l10n/generated/app_localizations.dart';

/// § 11.1 — every option is disabled **at 48dp**, in every state.
const double kBulkDownloadRowHeight = 48;

/// B18's choices, as radio rows with their counts, and one confirm.
class BulkDownloadSheet extends StatefulWidget {
  const BulkDownloadSheet({
    required this.rows,
    required this.onConfirm,
    required this.labelOf,
    required this.confirmLabelOf,
    super.key,
    this.offline = false,
  });

  /// The rows and their **exact** counts, from `bulkChoiceRows`.
  final List<BulkChoiceRow> rows;

  /// ⚠️ **APPLIES THE CHOICE**, like `SettingsChoiceSheet.onSelected` and for § 11.1's
  /// same reason: *"the confirm's refusal path is § 4's storage dialog, and the sheet
  /// stays open with its chosen option intact."* A sheet that popped before the write and
  /// reported afterwards has already closed by the time the failure arrives.
  final Future<void> Function(BulkChoice choice) onConfirm;

  /// The reader's words for a row. Never an enum `name` (B28).
  final String Function(BulkChoice choice) labelOf;

  /// The confirm's label, which **names the count**: *Download 212 chapters…*
  final String Function(int count) confirmLabelOf;

  /// § 11.1's *Offline* state: every option disabled, one sentence, nothing else.
  final bool offline;

  @override
  State<BulkDownloadSheet> createState() => _BulkDownloadSheetState();
}

class _BulkDownloadSheetState extends State<BulkDownloadSheet> {
  /// ⚠️ **`NextChapter`, NAMED.** § 11.1: the sheet opens on *Next chapter*. Deriving it
  /// from `rows.first` would let a reordered list change what the reader is about to be
  /// asked to confirm.
  BulkChoice _choice = const NextChapter();

  bool _busy = false;

  Future<void> _confirm() async {
    // ⚠️ **THE TWO GATES ARE HERE AND NOT IN THE WIDGET TREE.** A disabled confirm must
    // not acknowledge a finger, and re-entrancy must be refused in one place — a button
    // that can be pressed twice writes two queues.
    final BulkChoiceSelection selection = BulkChoiceSelection.of(
      _choice,
      widget.rows,
    );
    if (!selection.canConfirm || _busy || widget.offline) {
      return;
    }

    setState(() => _busy = true);
    try {
      await widget.onConfirm(
        selection.choice,
      ); // throws before any state mutation
      if (mounted) {
        Navigator.of(context).pop();
      }
    } on Object {
      // ⚠️ **CAUGHT AND THE SHEET STAYS OPEN, WITH ITS CHOICE INTACT** — § 11.1's *Submit
      // error*, and C8's rule that a control must not display a value it cannot keep.
      // `3-3`'s `EnqueueRefusedForSpace` arrives here and becomes § 4's storage dialog.
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations copy = AppLocalizations.of(context);
    final LumenSpacing spacing = LumenSpacing.of(context);
    final BulkChoiceSelection selection = BulkChoiceSelection.of(
      _choice,
      widget.rows,
    );

    return SafeArea(
      top: false,
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
              copy.chapterListDownloadAll,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          // ⚠️ **ONE SENTENCE OFFLINE, AND NOTHING ELSE CHANGES.** § 11.1: the state is
          // *"identical, with every option disabled at 48dp and one sentence"*. No
          // disabled-looking banner, no modal, no second explanation.
          if (widget.offline)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: spacing.lg),
              child: Text(
                copy.downloadNeedsConnectionSnackbar,
                key: const Key('bulkDownloadSheet.offline'),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: widget.rows.length,
              itemBuilder: (BuildContext context, int index) {
                final BulkChoiceRow row = widget.rows[index];
                return _ChoiceRow(
                  key: Key('bulkDownloadSheet.row.$index'),
                  label: row.label,
                  count: row.count,
                  selected: row.choice == _choice,
                  enabled: !widget.offline,
                  onTap: () => setState(() => _choice = row.choice),
                );
              },
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              spacing.lg,
              spacing.md,
              spacing.lg,
              spacing.sm,
            ),
            child: FilledButton(
              // ⚠️ **DISABLED, NOT HIDDEN, AT ZERO.** § 11.1 has no empty state for the
              // sheet, so the confirm stays and says there is nothing to do — the same
              // rule `pinned_action_row.dart` follows for *Mark all as read*.
              onPressed: selection.canConfirm && !widget.offline && !_busy
                  ? _confirm
                  : null,
              child: Text(
                widget.confirmLabelOf(selection.count),
                key: const Key('bulkDownloadSheet.confirm'),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              spacing.lg,
              spacing.xs,
              spacing.lg,
              spacing.md,
            ),
            child: TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(copy.commonCancel),
            ),
          ),
        ],
      ),
    );
  }
}

/// One radio row: a label, **its count**, and nothing else.
///
/// ⚠️ **THE COUNT IS ALWAYS RENDERED, INCLUDING AT ZERO.** § 11.1 wants a count beside
/// every row, and a row whose count is hidden at zero is a row whose meaning changes
/// with the novel — which is how a reader concludes the app cannot tell them whether
/// there is anything left.
class _ChoiceRow extends StatelessWidget {
  const _ChoiceRow({
    required this.label,
    required this.count,
    required this.selected,
    required this.enabled,
    required this.onTap,
    super.key,
  });

  final String label;
  final int count;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final LumenColors colors = LumenColors.of(context);
    final LumenSpacing spacing = LumenSpacing.of(context);
    final Color labelColor = enabled ? colors.textPrimary : colors.textDisabled;

    return Semantics(
      // § 11.1's rows are radios, and a disabled one is `enabled: false` so a screen
      // reader refuses it rather than announcing a row that does nothing.
      inMutuallyExclusiveGroup: true,
      checked: selected,
      enabled: enabled,
      selected: selected,
      label: label,
      value: '$count',
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          // ⚠️ **`kBulkDownloadRowHeight`, AND IT IS NOT CONDITIONAL.** § 11.1's offline
          // state is *"every option disabled at 48dp"* — a disabled row that shrank would
          // move the row beneath the reader's thumb at the moment they are reaching for
          // it. C11: one-handed, at night, in transit.
          constraints: const BoxConstraints(minHeight: kBulkDownloadRowHeight),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: spacing.lg,
              vertical: spacing.md,
            ),
            child: Row(
              children: <Widget>[
                Radio<bool>(
                  value: true,
                  groupValue: selected,
                  onChanged: enabled ? (bool _) => onTap() : null,
                ),
                SizedBox(width: spacing.sm),
                Expanded(
                  child: Text(
                    label,
                    style: Theme.of(
                      context,
                    ).textTheme.bodyLarge?.copyWith(color: labelColor),
                  ),
                ),
                SizedBox(width: spacing.sm),
                // ⚠️ **`enabled` DOES NOT GREY THE COUNT OUT.** The count is evidence about
                // the novel, and evidence does not become unreadable when the control is
                // unavailable — a reader deciding whether to go and find a connection is
                // reading the number, not tapping the row.
                Text(
                  '$count',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: colors.textSecondary,
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

/// Opens the sheet. Returns `null` when dismissed.
///
/// ⚠️ **A TOP-LEVEL FUNCTION, NOT A STATIC.** `BulkDownloadSheet.show(…)` parses as a
/// **named constructor** in Dart — the `Type.name(...)` form is always a constructor — so
/// a static method is unreachable under the spelling a caller naturally reaches for.
/// `settings_choice_sheet.dart` records the same trap and the same fix.
Future<void> showBulkDownloadSheet(
  BuildContext context, {
  required List<BulkChoiceRow> rows,
  required String Function(BulkChoice choice) labelOf,
  required String Function(int count) confirmLabelOf,
  required Future<void> Function(BulkChoice choice) onConfirm,
  bool offline = false,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (BuildContext context) => BulkDownloadSheet(
      rows: rows,
      labelOf: labelOf,
      confirmLabelOf: confirmLabelOf,
      onConfirm: onConfirm,
      offline: offline,
    ),
  );
}
