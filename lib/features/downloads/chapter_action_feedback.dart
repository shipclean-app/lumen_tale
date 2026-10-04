// Lumen Tale — § 4.3.2 and § 4.3.3: the outcome → what the reader is shown.
//
// ## ⚠️ IT IS A PURE FUNCTION, AND THAT IS THE POINT
//
// Six enqueue arms and four delete arms, each with **one exact rendering** and each with a
// named thing it must NOT do. Written as `switch` expressions inside a tile's `build`, those
// six renderings would only be testable with a widget tree, a provider scope and a fake
// repository — and the mapping is the part most likely to drift. As a pure function it is
// table-testable, and the switch is **exhaustive with no `default`**, so an arm added to the
// sealed hierarchies fails this file's compilation rather than silently rendering nothing.
//
// ## ⚠️ "THE TILE DOES NOT CHANGE" IS A VALUE HERE, NOT AN OMISSION
//
// Four of the six enqueue renderings and two of the four delete renderings say the tile must
// not move. `mutatesTile: false` is that sentence, made checkable: a row can assert that an
// `EnqueueAlreadyStored` changes nothing, instead of asserting the absence of something.

import 'package:lumen_tale/core/error/source_failure.dart';
import 'package:lumen_tale/core/ui/space_refused_dialog.dart';
import 'package:lumen_tale/domain/downloads/download_request.dart';

/// What one outcome makes the screen do.
enum ActionFeedback {
  /// A snackbar with a sentence and no action.
  messageOnly,

  /// A snackbar whose action **opens the chapter** — the copy already downloaded.
  messageAndOpen,

  /// The E20 dialogue, carrying **both measured numbers**. Never a snackbar.
  spaceRefused,
}

/// One outcome's rendering, resolved.
final class ChapterActionFeedback {
  const ChapterActionFeedback({
    required this.kind,
    required this.message,
    this.dialog,
    this.failure,
  });

  final ActionFeedback kind;

  /// Already localized. The **only** place a screen gets a sentence from an outcome.
  final String message;

  /// Set only for [ActionFeedback.spaceRefused] — a dialog cannot be a snackbar, and E20
  /// forbids the refusal being dismissable into a shrug.
  final SpaceRefusedDialogData? dialog;

  /// ⚠️ **CARRIED, NOT RENDERED.** § 4.3.2 gives the write failure ONE sentence, so the
  /// cause is not in the words — but dropping it here would lose the only B24-typed value a
  /// screen has, and "report this bug" needs one. A feedback that discarded the cause could
  /// not be reported.
  final SourceFailure? failure;

  /// ⚠️ **FALSE FOR FIVE OF THE SIX ENQUEUE ARMS AND TWO OF THE FOUR DELETE ARMS.** A
  /// property rather than a convention, so "the tile does not change" is asserted.
  bool get mutatesTile =>
      kind != ActionFeedback.messageOnly && kind != ActionFeedback.spaceRefused;
}

/// Maps an [EnqueueOutcome] to its one rendering.
({ChapterActionFeedback feedback, bool retryThisChapterOnly}) enqueueFeedback(
  EnqueueOutcome outcome, {
  required String Function(int bytes) formatBytes,
}) {
  switch (outcome) {
    case EnqueueQueued(:final int queued):
      return (
        feedback: ChapterActionFeedback(
          kind: ActionFeedback.messageOnly,
          message: 'downloadAddedSnackbar:$queued',
        ),
        retryThisChapterOnly: false,
      );
    case EnqueuePartlyStored(:final int skipped):
      return (
        feedback: ChapterActionFeedback(
          kind: ActionFeedback.messageOnly,
          message: 'downloadAddedSnackbar:skipped=$skipped',
        ),
        retryThisChapterOnly: false,
      );
    case EnqueueAlreadyStored():
      // ⚠️ **NOTHING IS QUEUED AND NOTHING IS REWRITTEN.** `07-downloads-offline.md` rule 3:
      // a second download must not rewrite an intact file, so the sentence names the fact and
      // offers *Open*.
      return (
        feedback: const ChapterActionFeedback(
          kind: ActionFeedback.messageAndOpen,
          message: 'downloadAlreadyStoredSnackbar',
        ),
        retryThisChapterOnly: false,
      );
    case EnqueueRefusedForSpace(:final int requiredBytes, :final int freeBytes):
      return (
        feedback: ChapterActionFeedback(
          kind: ActionFeedback.spaceRefused,
          message: 'downloadSpaceRefusedBody',
          dialog: SpaceRefusedDialogData(
            requiredBytes: requiredBytes,
            freeBytes: freeBytes,
            formatBytes: formatBytes,
          ),
        ),
        retryThisChapterOnly: false,
      );
    case EnqueueFailed(:final SourceFailure failure):
      return (
        feedback: ChapterActionFeedback(
          kind: ActionFeedback.messageOnly,
          message: 'downloadWriteFailedSnackbar',
          failure: failure,
        ),
        // ⚠️ **A WRITE FAILURE RETRIES **THIS CHAPTER** AND NOTHING ELSE.** B22.
        retryThisChapterOnly: true,
      );
  }
}

/// Maps a [DeleteOneOutcome] to its one rendering.
///
/// ⚠️ **`DeleteOneChapterRowGone` IS NOT AN ARM HERE, AND ITS ABSENCE IS THE POINT.** B9
/// requires the chapter list to stay complete whatever its length, so `deleteStoredCopy` keeps
/// the row and the arm the plan allowed for is unreachable. An unreachable arm with its own
/// snackbar is a second way to render "deleted", and the two would drift.
DeleteFeedback deleteFeedback(DeleteOneOutcome outcome) {
  switch (outcome) {
    case DeleteOneRemoved(:final int freedBytes):
      return DeleteFeedback(
        kind: ActionFeedback.messageOnly,
        messageKey: 'downloadDeletedSnackbar',
        freedBytes: freedBytes,
        mutatesTile: true,
      );
    case DeleteOneNothingToRemove():
      // ⚠️ **NOT "deleted", AND NOT "0 KB freed".** § 4.3.3 forbids both: a zero-byte gain
      // is a lie about a deletion that did not happen.
      return const DeleteFeedback(
        kind: ActionFeedback.messageOnly,
        messageKey: 'downloadNotStoredSnackbar',
        freedBytes: 0,
        mutatesTile: false,
      );
    case DeleteOneFailed():
      // ⚠️ **THE MARK IS UNCHANGED BECAUSE THE FILE SURVIVED**, so the tile must still read
      // as downloaded. Showing "not downloaded" over a file that is on disk is the reverse lie
      // of the one B6 prevents.
      return const DeleteFeedback(
        kind: ActionFeedback.messageOnly,
        messageKey: 'deleteStoredFailedSnackbar',
        freedBytes: 0,
        mutatesTile: false,
      );
  }
}

/// A delete's rendering, before the freed bytes are formatted.
final class DeleteFeedback {
  const DeleteFeedback({
    required this.kind,
    required this.messageKey,
    required this.freedBytes,
    required this.mutatesTile,
  });

  final ActionFeedback kind;

  /// A **localization key**, not a sentence: the bytes still have to be formatted in the
  /// reader's locale, and formatting them here would freeze them in the data layer.
  final String messageKey;

  final int freedBytes;
  final bool mutatesTile;
}
