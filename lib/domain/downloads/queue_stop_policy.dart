// Lumen Tale — what stops the queue, decided **by cause** and never by severity.
//
// `5-3` § 3.2. Pure Dart; no network, no database, no file.
//
// ## ⚠️ **BY CAUSE, NEVER BY "HOW BAD IS IT"**
//
// The instinct is `if (attempts > 3) break`. That produces a queue that **stops** on a
// chapter that is hard and **carries on** through a site that is dead — the exact inverse
// of B22. The distinction is not severity; it is whether the *next* request has any chance
// of a different answer.
//
// ## ⚠️ **A `switch` OVER A CLOSED ENUM WITH NO `default`, AND THAT IS THE POINT**
//
// § 11.1 asserts *"adding a code breaks the compilation"*. A `_ => false` arm would make
// every future code silently non-stopping, and the person adding it would find out from a
// reader's screenshot. The unknown-string branch lives **above** the switch, in
// `QueueFailureCode.parse`, so "a code this build does not have" is answered without
// weakening the exhaustiveness of "a code this build does have".

import 'package:lumen_tale/domain/downloads/queue_failure_code.dart';

/// Whether the queue must stop after a failure carrying [errorCode].
///
/// ⚠️ **THE FIVE `true`s ARE EACH A RULE, NOT A TUNABLE.** They are spelled out in the
/// comments below because a reader who finds this function later must be able to see why
/// each one stops, and a threshold that could be tuned is a threshold somebody will tune
/// for the wrong reason.
bool shouldStopQueue(String errorCode) {
  final QueueFailureCode? code = QueueFailureCode.parse(errorCode);
  if (code == null) {
    // ⚠️ **AN UNREADABLE CODE NEVER STOPS A QUEUE.** B24: an `error_code` written by a build
    // we do not know is not "unknown", it is *unreadable*, and guessing that it was fatal
    // would stop a queue over a value this build cannot interpret. It is one failed
    // chapter, which is what a failed chapter has always been.
    return false;
  }

  return switch (code) {
    // E7/E5 — the next chapter would fail identically and the reader would watch a queue
    // produce nothing but failures.
    QueueFailureCode.noConnection => true,

    // `17-security.md` rule 6 — `429` carries `Retry-After`; the answer is to WAIT, and a
    // queue that keeps fetching is a queue hammering a site that just asked it to stop.
    QueueFailureCode.rateLimited => true,

    // B22 — forty-eight chapters failing to parse is ONE site that changed, and one row
    // saying so beats forty-eight rows saying the same thing.
    QueueFailureCode.sourceLayoutChanged => true,

    // B3 — the novel names a source this build no longer contains. Every chapter of it
    // fails identically, so this is the same situation wearing a different code.
    QueueFailureCode.sourceUnavailable => true,

    // E20 — continuing would empty the phone.
    QueueFailureCode.storageFull => true,

    // B19 — `5-2` deletes the rows rather than marking them, so this value is never written
    // to a row. It is here because the *policy* has an answer, and a policy that has no
    // answer for a code the app can produce is a policy waiting to be wrong.
    QueueFailureCode.cancelled => true,

    // E8 — the site read this chapter and published nothing for it. The next chapter is a
    // different URL on a page that answered.
    QueueFailureCode.sourceEmpty => false,

    // E18 — this chapter converted to no prose. E22 forbids treating a short chapter as a
    // broken one, so a threshold being applied must never end a 400-chapter novel.
    QueueFailureCode.noRealText => false,

    // E9 — the site says this item is gone. The rest of the queue is unaffected.
    QueueFailureCode.itemRemovedAtSource => false,

    // B22 — the body did not survive parsing. One file, one failure.
    QueueFailureCode.parseFailed => false,

    // ⚠️ **THE ONLY `false` THAT IS A CLAIM.** "This app cannot say what happened" does not
    // entitle it to decide the queue's future.
    QueueFailureCode.causeUnknown => false,
  };
}
