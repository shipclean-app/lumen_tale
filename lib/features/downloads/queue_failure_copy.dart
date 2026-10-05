// Lumen Tale — one `error_code` → one sentence and one action. The mapping, as data.
//
// ## ⚠️ **A PURE FUNCTION, FOR THE SAME REASON `chapter_action_feedback.dart` IS**
//
// Six enqueue arms and four delete arms there, each with exactly one rendering. Written as a
// `switch` inside a tile's `build`, those renderings would only be testable with a widget
// tree and a provider scope — and the mapping is the part most likely to drift. Here the
// `switch` is **exhaustive with no `default`**, so a code added to `QueueFailureCode` breaks
// this file's compilation rather than rendering nothing.
//
// ## ⚠️ **EVERY CODE GETS A SENTENCE. THAT IS THE WHOLE OF B24.**
//
// `B24`: *"Any action that can fail shows an error the user can read and act on, together
// with a way to try again. No action fails silently."* `C12` sharpens it: the sentence must
// be one a borrowed-device reader can **say aloud** to whoever owns the phone. A `failed` row
// with no sentence is the state B22 exists to prevent.
//
// ## ⚠️ **THE ACTION IS CHOSEN BY CAUSE AND NOT BY "IS THERE A BUTTON"**
//
// Three, and each has a reason a reader can be given:
//
//  * **retryChapter** — the chapter might succeed on a second request (E8, E18, a parse
//    failure on one file);
//  * **resumeQueue** — the queue stopped, and this chapter is the reason it stopped, so the
//    honest action is the queue's (*Resume* after freeing space, after waiting for
//    `Retry-After`, after the signal returns);
//  * **openNovel** — E9: the site has confirmed the item is gone, so retrying would fail
//    identically and **naming a retry would be a promise the site has already refused**.

import 'package:lumen_tale/domain/downloads/queue_failure_code.dart';
import 'package:lumen_tale/l10n/generated/app_localizations.dart';

/// What a failed row offers. **Three, and no fourth without an argument.**
enum QueueFailureAction {
  /// Re-fetch **this chapter alone** — `downloads.md` § 5, and B5's no-speculative-fetching.
  retryChapter,

  /// Wake the stopped queue. The one action E7/E20 both need.
  resumeQueue,

  /// Look at the novel. E9's honest answer when the site has confirmed the chapter is gone.
  openNovel,
}

/// One code's rendering, resolved.
final class QueueFailureCopy {
  const QueueFailureCopy({
    required this.sentence,
    required this.action,
    required this.actionLabel,
  });

  /// Already localized. **The only** place a screen gets a sentence from a code.
  final String sentence;

  final QueueFailureAction action;

  /// ⚠️ **CARRIED RATHER THAN RESOLVED**, because the label is localized and this file is a
  /// `switch` over a domain enum with no `BuildContext`. The caller passes [l10n].
  final String actionLabel;

  @override
  String toString() => 'QueueFailureCopy(${action.name})';
}

/// Maps [code] to its one sentence and one action.
///
/// ⚠️ **`switch` OVER A CLOSED ENUM WITH NO `default`, AND THAT IS THE POINT.** § 11.1's
/// exhaustiveness row: adding a code has to break this file until somebody decides what a
/// reader is told about it.
QueueFailureCopy queueFailureCopy(
  QueueFailureCode code,
  AppLocalizations l10n,
) {
  final (String sentence, QueueFailureAction action) = switch (code) {
    QueueFailureCode.noConnection => (
      // ⚠️ **THE SENTENCE NAMES THE CONNECTION AND NOT THE CHAPTER.** "This chapter could not
      // be downloaded" would invite a retry; "the connection dropped" invites waiting, and
      // waiting is the right response (E7/E5).
      l10n.queueCauseNoConnection,
      QueueFailureAction.resumeQueue,
    ),
    QueueFailureCode.rateLimited => (
      l10n.queueCauseRateLimited,
      QueueFailureAction.resumeQueue,
    ),
    QueueFailureCode.sourceLayoutChanged => (
      // ⚠️ **C5: 'this app can no longer read it' IS A REPORT THE OWNER CAN ACT ON.** It names
      // the fault and it is true; the app does not guess which selector broke.
      l10n.queueCauseSourceLayoutChanged,
      QueueFailureAction.resumeQueue,
    ),
    QueueFailureCode.sourceUnavailable => (
      l10n.queueCauseSourceUnavailable,
      QueueFailureAction.resumeQueue,
    ),
    QueueFailureCode.storageFull => (
      // ⚠️ **NEVER "TRY AGAIN".** E20: the next request would fail the same way, and
      // `downloads.md` § 4 says the resume action is *"free up some space, then resume"*.
      l10n.queueCauseStorageFull,
      QueueFailureAction.resumeQueue,
    ),
    QueueFailureCode.cancelled => (
      // ⚠️ **UNREACHABLE AS A ROW, AND IT IS STILL MAPPED.** `5-2`'s cancellation DELETES the
      // rows. A policy with no answer for a code the vocabulary can express is a policy
      // waiting to be wrong, and a `default` here would be the arm that gets it.
      l10n.queueCauseUnknown,
      QueueFailureAction.resumeQueue,
    ),
    QueueFailureCode.sourceEmpty => (
      l10n.queueCauseSourceEmpty,
      QueueFailureAction.retryChapter,
    ),
    QueueFailureCode.noRealText => (
      // ⚠️ **ABOUT **THIS** CHAPTER, AND NOT ABOUT THE SITE.** E22: a short chapter must never
      // be told apart from a broken one, so the sentence is scoped to the chapter.
      l10n.queueCauseNoRealText,
      QueueFailureAction.retryChapter,
    ),
    QueueFailureCode.parseFailed => (
      l10n.queueCauseParseFailed,
      QueueFailureAction.retryChapter,
    ),
    QueueFailureCode.itemRemovedAtSource => (
      l10n.queueCauseItemRemovedAtSource,
      // ⚠️ **AND NOT A RETRY.** E9 and `downloads.md` § 9: the site answered and confirmed
      // the item is gone, so a Retry button would be an action the app knows cannot work.
      QueueFailureAction.openNovel,
    ),
    QueueFailureCode.causeUnknown => (
      // ⚠️ **A CLAIM, NOT A DEFAULT.** `source_failure.dart` says the same: "this app cannot
      // say" is weaker than any specific cause and is the only one that is true.
      l10n.queueCauseUnknown,
      QueueFailureAction.retryChapter,
    ),
  };

  return QueueFailureCopy(
    sentence: sentence,
    action: action,
    actionLabel: switch (action) {
      QueueFailureAction.retryChapter => l10n.downloadsRetryAction,
      QueueFailureAction.resumeQueue => l10n.downloadsResumeAction,
      QueueFailureAction.openNovel => l10n.downloadsOpenNovelAction,
    },
  );
}

/// The copy for a code **this build does not have**, which `QueueFailureCode.parse` answers
/// with `null` rather than with `causeUnknown`.
///
/// ⚠️ **A SEPARATE ENTRY POINT, NOT A `?? causeUnknown` AT THE CALL SITE.** `parse`'s own doc
/// says a column written by an older build is *unreadable* rather than unknown, and
/// pretending otherwise would report a cause nobody observed (B24).
QueueFailureCopy queueFailureCopyForStoredCode(
  String stored,
  AppLocalizations l10n,
) => queueFailureCopy(
  QueueFailureCode.parse(stored) ?? QueueFailureCode.causeUnknown,
  l10n,
);
