// Lumen Tale — the six radio rows of B18, and the numbers beside them.
//
// `5-1` § 3.1's closing note and § 4.3. Pure Dart: **no Flutter, no ARB, no widget.**
//
// ## ⚠️ THE COUNT IS `resolveBulkChoice(choice).length`, AND NOTHING ELSE
//
// `novel-details.md` § 11.1: *"each with a running chapter count beside it"*. The
// number a reader SEES and the number the queue APPLIES come from the same call:
//
// ```text
// display count  =  resolveBulkChoice(choice, chapters: …).length
// enqueued count =  resolveBulkChoice(choice, chapters: …).length   ← same expression
// ```
//
// So this file cannot compute `min(5, total)` in one place and hand the widget a
// different figure: a `min` written here would be a second implementation of the
// resolver's `take(count)`, and the two would be free to disagree — a defect that
// shows up on the fortieth chapter of a download nobody is watching.
//
// ## ⚠️ **THE LABELS ARE THE CALLER'S, AND THAT IS WHY THIS FILE HAS NO ARB IMPORT**
//
// `domain/` carries no Flutter import (`02-architecture.md`), so a label cannot come
// from `AppLocalizations` here. It is a parameter — the same shape
// `core/ui/settings_choice_sheet.dart` uses (`labelOf`, `warningFor`), and for the same
// reason: the widget knows nothing about *which* six rows exist, and the screen that
// shows them owns their words.
//
// A consequence worth stating: adding a seventh choice would add a row here **and** a
// string in the caller, and `test/…/bulk_choice_rows_test.dart` asserts the count is
// five (six minus `HandPicked`, which is not reached from the sheet — see below).

import 'package:lumen_tale/domain/downloads/bulk_choice.dart';
import 'package:lumen_tale/domain/downloads/bulk_choice_resolver.dart';

/// One radio row: a choice, the reader's words for it, and how many chapters it resolves
/// to **right now**.
final class BulkChoiceRow {
  const BulkChoiceRow({
    required this.choice,
    required this.label,
    required this.count,
  });

  final BulkChoice choice;

  /// The caller's localized words. Never an enum `name` — B28.
  final String label;

  /// ⚠️ **`resolveBulkChoice(choice, chapters: chapters).length`.** Exact, derived, and
  /// never cached: a novel whose chapters were loaded a moment ago and a novel whose
  /// list changed since must not show the same figure.
  final int count;

  /// Nothing to download for this row. ⚠️ **The row still RENDERS** — B18's sheet has no
  /// empty state (`novel-details.md` § 11.1: *"a novel with zero unopened chapters still
  /// has Next chapter available and the sheet says so"*), so a zero is a sentence, not
  /// a reason to hide a control.
  bool get isEmpty => count == 0;

  @override
  bool operator ==(Object other) =>
      other is BulkChoiceRow &&
      other.choice == choice &&
      other.label == label &&
      other.count == count;

  @override
  int get hashCode => Object.hash(choice, label, count);

  @override
  String toString() => 'BulkChoiceRow($label: $count)';
}

/// The rows the sheet renders, in `novel-details.md` § 11.1's order.
///
/// ⚠️ **`HandPicked` IS DELIBERATELY ABSENT, so this is FIVE rows and B18 has SIX
/// choices.** § 11.1: *"the sixth choice is reached by long-pressing tiles, not from
/// this sheet, so that 'a set the user selected by hand' is literally hand-selected."*
/// Listing it would offer a sheet row that can only ever resolve to "nothing", because
/// the sheet holds no selection.
List<BulkChoiceRow> bulkChoiceRows({
  required List<DownloadableChapter> chapters,
  required String Function(BulkChoice choice) labelOf,
}) {
  return <BulkChoiceRow>[
    for (final BulkChoice choice in kBulkChoices)
      BulkChoiceRow(
        choice: choice,
        label: labelOf(choice),
        // ⚠️ **THE SAME CALL THE ENQUEUE MAKES.** Not a count, not an estimate, and not
        // a `min` — see the file header.
        count: resolveBulkChoice(choice, chapters: chapters).length,
      ),
  ];
}

/// The row the sheet opens on, and the count its confirm names.
///
/// ⚠️ **`NextChapter` AND NOT `rows.first`.** The plan's first row and its default agree
/// today; making the default *derived from the list* would let a reordered list silently
/// change what a reader is about to be asked to confirm, and `novel-details.md` § 11.1
/// names *Next chapter* as the choice the sheet opens on.
final class BulkChoiceSelection {
  const BulkChoiceSelection({required this.choice, required this.count});

  /// The reader's chosen row.
  final BulkChoice choice;

  /// ⚠️ **`rows.firstWhere((r) => r.choice == choice).count`** — recomputed at selection
  /// time rather than stored, because the count is a function of the chapters and a
  /// stored figure is a second source of truth (C8).
  factory BulkChoiceSelection.of(BulkChoice choice, List<BulkChoiceRow> rows) {
    final BulkChoiceRow row = rows.firstWhere(
      (BulkChoiceRow r) => r.choice == choice,
    );
    return BulkChoiceSelection(choice: choice, count: row.count);
  }

  /// ⚠️ **THE CONFIRM NAMES THIS NUMBER.** `Download 212 chapters…` — the number the
  /// reader was shown, not a second one computed here. A confirm whose count differs
  /// from the row beside it is B18 broken in the one place the reader could have caught
  /// it.
  final int count;

  /// Nothing to download: the confirm is **disabled**, and the sheet says why. It is not
  /// an error dialog (§ 3.1 branch 2).
  bool get canConfirm => count > 0;

  @override
  bool operator ==(Object other) =>
      other is BulkChoiceSelection &&
      other.choice == choice &&
      other.count == count;

  @override
  int get hashCode => Object.hash(choice, count);

  @override
  String toString() => 'BulkChoiceSelection($choice: $count)';
}

/// The reader's chosen chapter ids, in the order they were chosen.
///
/// ⚠️ **`ids` AND NOT A `Set` AT THE INTERFACE.** `novel-details.md` § 11.3 declares
/// **no reordering gesture** in the selection bar, so the insertion order *is* the
/// order B18 wants the queue to run, and `resolveBulkChoice`'s `HandPicked` branch
/// preserves it deliberately.
final class HandPickedSelection {
  HandPickedSelection(List<String> chapterIds)
    : ids = List<String>.unmodifiable(chapterIds);

  final List<String> ids;

  int get count => ids.length;

  bool get isEmpty => ids.isEmpty;

  /// The choice itself. ⚠️ **REFUSES AN EMPTY SELECTION**, because `HandPicked([])`'s own
  /// assertion fires — and a confirm button that is disabled at zero should never be able
  /// to reach this call at all.
  BulkChoice toChoice() => HandPicked(ids);
}
