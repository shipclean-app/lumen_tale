// Lumen Tale — the use case, as an interface.
//
// `6-4` § 2.2. One method, and the implementation lives in `data/` so that
// `6-10`'s background isolate can build it with a fresh `AppDatabase` and run the
// **same** code as the in-process path.
//
// ## ⚠️ `cancellation` IS A FUNCTION, NOT A FLAG
//
// Two reasons, and they are different. First, the flag has to be readable by an isolate
// that does not share this process's memory — so it is a closure over
// `shared_preferences`, not a field. Second, and this is the rule the plan states: it
// is consulted **after every network call as well as before every novel**, because an
// interruption made during a request must not take one more novel than it already had.
// A boolean field checked once per iteration cannot express that.

import 'package:lumen_tale/domain/updates/library_check.dart';

abstract interface class CheckLibrary {
  /// Runs **one** pass over **every** novel in the library (B39).
  ///
  /// ⚠️ **The only entry point in the app, and it has exactly two callers**: a tap on a
  /// *Check* control, and `6-10`'s foreground job, which is that same tap. Nothing at
  /// start-up, nothing on resume, nothing on a list scroll and nothing on a tab change
  /// calls it (B36). ADR-023 withdrew the schedule, so there is no second caller to
  /// discipline.
  ///
  /// [onProgress] is called **before** the first network call and once per novel
  /// thereafter, so `total` is known from the first emission and the screen can say
  /// *Checking 0 of 23 novels* rather than waiting to find out how long the library is.
  ///
  /// Returns a [LibraryCheckResult] rather than throwing for a per-novel failure: one
  /// site being broken is a **result**, and a throw would make the reader watch a pass
  /// abort for something they can see named and retry.
  Future<LibraryCheckResult> run({
    required void Function(LibraryCheckProgress) onProgress,
    required Future<bool> Function() cancellation,
  });
}
