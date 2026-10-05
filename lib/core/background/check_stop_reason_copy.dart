// Lumen Tale — ten stop reasons, ten sentences, and the one that is not a stop.
//
// `6-10` § 7's last trap, and C12.
//
// ## ⚠️ MARKED CLAIM: `core/background/`, NOT `core/ui/app_error_copy.dart`
//
// `13-error-handling.md` rule 5 owns *exceptions* → sentences, and `app_error_copy.dart`
// is exhaustive over `AppException` and `SourceFailure`. A `CheckStopReason` is neither: it
// is a platform's verdict on a job, it arrives on a stream rather than in an `AsyncError`,
// and it has **ten** values of which six are named. Adding it to that file would put a
// background-job vocabulary in a file whose header promises the two exception families and
// would make the two look interchangeable to a reader — they are not, because a
// `StopReason` has a sentence for *every* value and `causeUnknown` exists precisely because
// most exceptions do not.
//
// ## ⚠️ MARKED CLAIM: EVERY VALUE IS NAMED AND THE `switch` HAS NO `default`
//
// C12: a reader on a borrowed phone has to be able to *say* what happened to whoever owns
// it. One unnamed reason is one state that reader cannot describe, and `6-10` § 10's row
// demands that adding a value to the package fails a build rather than falling through to
// *"stopped"*. `CheckStopReason` has ten values; the ARB has ten keys; the switch names
// all ten.

import 'package:lumen_tale/domain/updates/check_stop_reason.dart';
import 'package:lumen_tale/l10n/generated/app_localizations.dart';

/// Every [CheckStopReason] in words.
extension CheckStopReasonCopy on AppLocalizations {
  /// ⚠️ **EXHAUSTIVE, NO `default`, ONE SENTENCE PER VALUE — ALL TEN.**
  ///
  /// The five C12 calls out separately — `deviceIdle`, `appStandby`, `deviceState`,
  /// `backgroundRestriction`, `timeout` — each say something different, and
  /// `test/core/background/check_stop_reason_copy_test.dart` asserts the five are pairwise
  /// **distinct strings**, because *"the phone did something"* is the answer this slice
  /// exists not to give.
  ///
  /// ⚠️ **`systemIgnoredCancelledByApp` IS A SUCCESS SENTENCE, DELIBERATELY.** It shares
  /// its key with the finished-after-cancel line because the fact it reports *is* that the
  /// pass finished: the reader now holds results they did not ask for, and *"cancelled"*
  /// would send them looking for changes that are already saved.
  String checkStoppedSentence(CheckStopReason reason) => switch (reason) {
    // Android 11 and earlier report nothing. The sentence admits that rather than
    // inventing a cause — a guess here is C12's exact failure.
    CheckStopReason.unknown => checkStoppedUnknown,
    // The app's own time limit, and the reader's next move is to try again.
    CheckStopReason.timeout => checkStoppedTimeout,
    // Something else got the phone. **Not our fault**, and the sentence must not imply it
    // was.
    CheckStopReason.preempt => checkStoppedPreempt,
    // The reader's own gesture: cancelled, library unchanged, no error surface (rule 7).
    CheckStopReason.cancelledByApp => checkStoppedCancelledByApp,
    // ⚠️ **"finished after you cancelled it", NOT "cancelled".** See the header.
    CheckStopReason.systemIgnoredCancelledByApp =>
      checkStoppedSystemIgnoredCancel,
    // Android paused the work — the pass can be finished by tapping check again.
    CheckStopReason.backgroundRestriction => checkStoppedBackgroundRestriction,
    // The phone ran out of memory for it. One of ten, and it gets its own sentence.
    CheckStopReason.estimatedAppGpuLimit => checkStoppedGpuLimit,
    // Battery saver and its relatives.
    CheckStopReason.deviceState => checkStoppedDeviceState,
    // Doze and App Standby share a sentence **on purpose** (`6-7` wrote it that way):
    // one thing happened to the phone, and two sentences for one cause would be two truths
    // about one phone's state.
    CheckStopReason.appStandby => checkStoppedAppStandby,
    CheckStopReason.deviceIdle => checkStoppedDeviceIdle,
  };
}
