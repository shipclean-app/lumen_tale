// Lumen Tale — one shared boolean, and it is the only thing two isolates agree on.
//
// `6-10` § 2.1. `core/`, because `core` is the only layer that may depend on
// `shared_preferences`, and this is nothing but a dependency on `shared_preferences`.
//
// ## ⚠️ MARKED CLAIM: THE FLAG IS A BOOLEAN, NOT A TIMESTAMP AND NOT A COUNTER
//
// `6-10` § 3.3 closes with the reason: a timestamp would require a duration of
// validity, and a duration of validity would be a second rule about checking that nobody
// wrote down. A boolean cannot expire — it is released at start-up, at the end of the
// pass, and by a cancellation, and those three are the whole of its lifecycle.
//
// A flag holding anything else (a novel id, a counter, a phase) would be a **second copy
// of the state of the check**, and two copies across two isolates drift the first time
// one of them fails to write. This flag answers exactly one question: *is a pass in
// flight right now?*

import 'package:shared_preferences/shared_preferences.dart';

/// The one key. ⚠️ **A CONSTANT, NEVER A STRING LITERAL AT A CALL SITE** — the two
/// isolates read this file, and a typo in one of them is a lock neither side can see.
const String checkRunningKey = 'check.job.running';

/// The one-flight lock, shared by both isolates.
///
/// ⚠️ **`acquire()` IS A READ-THEN-WRITE, AND THE WINDOW IS STATED RATHER THAN HIDDEN.**
/// `shared_preferences` offers no compare-and-set, so this cannot be atomic. The first
/// version wrote `true` unconditionally and read back — which "looks" atomic and is not: the
/// read-back returns what the writer just wrote, so `acquire()` could **never** return
/// `false`, and the caller's single-flight gate was decorative. A test row
/// (*`acquire` succeeds on a free flag and refuses once it is held*) caught it.
///
/// The read is therefore the decision and the write the claim. Two isolates calling
/// `acquire` in the same instant can both read `false`; the window is a millisecond between
/// a reader's two taps or between a tap and a job the platform has just enqueued. It is not
/// closable with `shared_preferences`, and closing it would mean a lock file — a second
/// mechanism for one boolean. C7 is met because both callers are the *same tap*: the platform
/// only starts a job this app registered, and this app registered it under this flag.
abstract interface class CheckJobInterlock {
  /// Takes the lock if it is free. `false` means a pass is already in flight.
  Future<bool> acquire();

  /// Releases the lock.
  ///
  /// ⚠️ **IDEMPOTENT, AND IT MUST STAY THAT WAY.** `cancel()`, the normal end of the pass
  /// and `onTaskStopped` all reach it, and on Android 11 and earlier two of those
  /// callbacks can arrive for one stop. A `release()` that threw on the second call would
  /// turn "the pass ended" into "the app crashed", which is `6-10` § 3.3 branches 7 and 8
  /// failing to do the only thing they exist for.
  Future<void> release();

  /// `true` when a pass is in flight or a killed isolate left the flag set. Read at
  /// start-up to clean up after a background isolate the system took away (§ 3.3, branches
  /// 7 and 8).
  Future<bool> isHeld();
}

/// The production interlock: `shared_preferences`, because it is the **only** storage both
/// isolates can see.
///
/// ⚠️ **A DRIFT ROW WOULD NOT DO, AND WOULD NOT EVEN BE WRITTEN.** The database file is
/// reachable from the background isolate, but the check's own rows are what two writers of
/// one pass would corrupt, and putting a lock in the table a pass writes is the worst of
/// both worlds. `shared_preferences` is a separate file, and it is why this class is worth
/// twenty lines.
final class SharedPreferencesCheckJobInterlock implements CheckJobInterlock {
  const SharedPreferencesCheckJobInterlock(this._prefs);

  final SharedPreferences _prefs;

  @override
  Future<bool> acquire() async {
    // ⚠️ **THE READ COMES FIRST, AND IT IS THE DECISION.** See the header: the read-back
    // after a write is not a witness, it is the writer agreeing with itself.
    if (await isHeld()) {
      return false;
    }
    await _prefs.setBool(checkRunningKey, true);
    return true;
  }

  @override
  Future<void> release() => _prefs.setBool(checkRunningKey, false);

  @override
  Future<bool> isHeld() async => _prefs.getBool(checkRunningKey) ?? false;
}

/// Clears a flag left behind by a background isolate the system killed.
///
/// ⚠️ **RELEASES AND REGISTERS NOTHING.** `6-10` § 3.3 branches 7 and 8: an isolate that
/// is killed runs no `finally` and fires no `onTaskStopped`, so the flag is the only
/// evidence that anything was in flight. Releasing it makes the next pass possible.
///
/// The two things it must **not** do are recorded here because both are one line away:
///
///  * it must **not** resume the interrupted pass. B20 — an interrupted operation is done
///    again from the start when the reader asks, never completed from a partial state;
///  * it must **not** register anything. That would make opening the app a trigger,
///    which is B36's rule and ADR-023's reason there is no schedule to re-arm.
///
/// Returns `true` when it actually found a stale flag, so a test can tell the cleanup
/// path from the quiet one instead of asserting nothing happened.
Future<bool> releaseStaleCheckJobFlag(CheckJobInterlock interlock) async {
  if (!await interlock.isHeld()) {
    return false;
  }
  await interlock.release();
  return true;
}
