// Lumen Tale — B37's envelope, as values: the permission, the counter, and the three endings.
//
// `6-10` § 2.2. Pure Dart — no Flutter, no plugin, no drift. `02-architecture.md` makes
// `domain` the pure layer, and `library_check.dart` states the reason this file holds to
// it: the same pass runs in the main isolate **and** in the background isolate, so one
// Flutter import here would make the foreground job impossible to build.
//
// ## ⚠️ MARKED CLAIM: `CheckJobInterrupted.reason` IS `domain`'s OWN ENUM
//
// `6-10` § 2.2 types it as the plugin's `StopReason`. See `check_stop_reason.dart`'s
// header for the two structural reasons that cannot be built (an undeclared package, and
// Flutter arriving through `workmanager`'s re-export of its Pigeon surface). The plugin's
// type is converted once, in `core/background/`, by a `switch` with no `default`.

import 'package:lumen_tale/domain/updates/check_stop_reason.dart';

/// The state of the notification permission, as Android reports it.
///
/// ⚠️ **THREE STATES PLUS "NOT APPLICABLE", NOT TWO.** *"Will it show a dialog if I ask
/// again"* and *"refused"* are different situations: the first has a dialog in front of
/// it and the second has none. `settings.md` § 4 requires an *Open notification settings*
/// link, and that link exists **because** the second state has no dialog left to show —
/// collapsing the two would leave a control leading to a dialog Android will not open.
enum NotificationPermission {
  /// Android 12 and earlier: the runtime permission does not exist and a foreground
  /// service notification is always shown. **No request is made**, and `settings.md` § 11
  /// lists "asking on screen entry" among the deliberate absences.
  notApplicable,

  /// Granted. The pass starts with no dialog.
  granted,

  /// Refused, and Android will still show one dialog if asked.
  canAskAgain,

  /// Refused for good: Android will not show a dialog again. Only a deep link into the
  /// system's own settings can change it — which is the link `settings.md` § 4 asks for.
  refusedPermanently,
}

/// Where a check pass has got to, in **novels**.
///
/// ⚠️ **TWO INTEGERS AND NO MORE — AND THAT IS THE C2 CLAIM.** This is the type whose
/// values cross the isolate boundary, and `17-security.md` rule 4 is about exactly this:
/// Android draws the check's notification on a locked screen, so anything that could name
/// a book is a leak toward whoever is holding the phone. `6-4`'s own
/// `LibraryCheckProgress` carries an `inFlightNovelId` **on purpose** and its header says
/// it never leaves this process; a second progress type with no such field is what makes
/// that promise enforceable rather than aspirational.
final class CheckJobProgress {
  const CheckJobProgress({required this.done, required this.total});

  /// Novels finished so far, successes and failures alike (`6-4` counts both).
  final int done;

  /// The library's size when the pass began. **Fixed for the whole pass**, because a
  /// total that could move would make *"Checking 7 of 23"* become *"Checking 7 of 24"*
  /// while the reader watches it (B39).
  final int total;

  /// B39's evidence as one number, and `remaining` is never rendered — an uncapped count
  /// is a claim about a library this app cannot enumerate.
  int get remaining => total - done;

  @override
  bool operator ==(Object other) =>
      other is CheckJobProgress && other.done == done && other.total == total;

  @override
  int get hashCode => Object.hash(done, total);

  @override
  String toString() => 'CheckJobProgress($done/$total)';
}

/// The three sentences the foreground notification is built from, resolved in the reader's
/// language **before** the job is registered.
///
/// ⚠️ **`core/background/` HOLDS NO STRING.** `6-10` § 11.3's `6-7 → 6-10` row: the
/// notification text comes from `AppLocalizations` in both languages, and a literal in
/// `core/` would be an English sentence in a French application. The values are carried
/// across as data because `ForegroundServiceConfig` is built in `core/`, and the object
/// that fills them is built from `AppLocalizations` at the composition root.
///
/// ⚠️ **NEVER STORED.** `6-10` § 5's table puts the notification text in the *never
/// stored* row: there is no preference, no column and no file, so there is nothing to go
/// stale when the app is next launched in another language.
final class CheckJobNotificationCopy {
  const CheckJobNotificationCopy({
    required this.title,
    required this.text,
    required this.channelName,
  });

  /// *Checking your library* — the title the reader sees in the drawer.
  final String title;

  /// The body. `6-10` § 10 asks for this to track the counter; see
  /// `6-10` § 7's second open question, recorded in `SESSION_LOG.md`, because
  /// `workmanager` 0.10.10 builds this notification **once** and `reportProgress` cannot
  /// rewrite it.
  final String text;

  /// *Library checks* — the channel's user-visible name, which is a **system setting** the
  /// reader can rename and Android then shows in its own channel screen. A localised name
  /// is the difference between a channel this app created and one it merely uses.
  final String channelName;

  @override
  bool operator ==(Object other) =>
      other is CheckJobNotificationCopy &&
      other.title == title &&
      other.text == text &&
      other.channelName == channelName;

  @override
  int get hashCode => Object.hash(title, text, channelName);

  @override
  String toString() =>
      'CheckJobNotificationCopy($title / $text / $channelName)';
}

/// How a pass ended.
///
/// ⚠️ **THREE ARMS, NOT A BOOLEAN.** *"the reader cancelled it"*, *"Android stopped it"*
/// and *"it finished"* are three facts a reader must be able to tell apart, and `6-10`
/// § 7's last trap plus C8 both exist because a pass that stopped must never be rendered
/// as one that finished. A `bool interrupted` cannot answer that; a sealed union is three
/// states that cannot be confused for one another, and adding a fourth makes every
/// `switch` over it fail to compile.
sealed class CheckJobOutcome {
  const CheckJobOutcome();
}

/// The pass visited every novel in the library.
final class CheckJobSucceeded extends CheckJobOutcome {
  const CheckJobSucceeded({
    required this.checkedNovelCount,
    required this.failedNovelCount,
    required this.discovered,
  });

  /// Novels the app looked at.
  final int checkedNovelCount;

  /// Novels whose site could not be read. **Beside** the success count and never inside
  /// it: B22 is the rule that a broken site is not *0 new chapters*.
  final int failedNovelCount;

  /// Chapters **found by this pass** — rows added, not the library's unopened total,
  /// which is local, exact and unchanged by a check (B48).
  final int discovered;

  @override
  bool operator ==(Object other) =>
      other is CheckJobSucceeded &&
      other.checkedNovelCount == checkedNovelCount &&
      other.failedNovelCount == failedNovelCount &&
      other.discovered == discovered;

  @override
  int get hashCode =>
      Object.hash(checkedNovelCount, failedNovelCount, discovered);

  @override
  String toString() =>
      'CheckJobSucceeded(checked: $checkedNovelCount, failed: $failedNovelCount, '
      'discovered: $discovered)';
}

/// The pass stopped **before** seeing every novel.
///
/// ⚠️ **BOTH NUMBERS, AND THAT IS THE POINT.** C8: the reader must be able to hear *"it
/// only looked at 7 of 23"* rather than receive a summary of seven novels presented as
/// the whole tour. `6-4`'s `LibraryCheckResult` already carries both; this arm carries
/// them across the isolate boundary so a background pass can say the same thing.
final class CheckJobInterrupted extends CheckJobOutcome {
  const CheckJobInterrupted({
    required this.reason,
    required this.reachedNovelCount,
    required this.totalNovelCount,
  });

  /// ⚠️ **`null` MEANS *THE READER DID IT*, and `domain` cannot name that better.**
  /// `6-10` § 3.3 branch 2 is a cancellation the reader asked for, and `13-error-handling`
  /// rule 7 says it is not a failure — so it is the absence of a platform reason rather
  /// than a twelfth reason pretending to be one.
  final CheckStopReason? reason;

  final int reachedNovelCount;
  final int totalNovelCount;

  /// ⚠️ **NOT `reason == cancelledByApp`.** The reader's own gesture arrives as `null`:
  /// `cancel()` releases the interlock **before** it asks WorkManager to stop, so the
  /// loop usually ends at its next gate and the pass reports `interrupted` with no
  /// platform reason at all. A predicate that only recognised the platform's spelling
  /// would answer `false` for the cancellation the reader actually made.
  bool get cancelledByReader => reason == null;

  @override
  bool operator ==(Object other) =>
      other is CheckJobInterrupted &&
      other.reason == reason &&
      other.reachedNovelCount == reachedNovelCount &&
      other.totalNovelCount == totalNovelCount;

  @override
  int get hashCode => Object.hash(reason, reachedNovelCount, totalNovelCount);

  @override
  String toString() =>
      'CheckJobInterrupted(${reason?.name ?? 'reader'}, '
      '$reachedNovelCount/$totalNovelCount)';
}

/// The pass never started at all: the permission was refused, or the job could not be
/// registered.
///
/// ⚠️ **`canFallBackInProcess` IS A CAPABILITY, NOT A DECISION.** `6-10` § 3.4's fallback
/// runs the **same** `CheckLibrary` in the main isolate, and it can only do so because the
/// app is in the foreground — it just answered a tap. The flag says so; the controller
/// performs the fallback exactly once and never alongside the foreground job, because two
/// isolates writing `last_checked_at` for one library is a class of bug no integration
/// test catches.
final class CheckJobCouldNotStart extends CheckJobOutcome {
  const CheckJobCouldNotStart(
    this.reason, {
    required this.canFallBackInProcess,
  });

  /// ⚠️ **A SENTENCE, NEVER `e.toString()`.** `13-error-handling` rule 3 forbids
  /// propagating a stack trace or an exception's own rendering into anything a screen
  /// can show; C12 asks for something a reader can say aloud. The typed cause is logged
  /// through `core/utils/logger.dart` at the site that caught it.
  final String reason;

  final bool canFallBackInProcess;

  @override
  bool operator ==(Object other) =>
      other is CheckJobCouldNotStart &&
      other.reason == reason &&
      other.canFallBackInProcess == canFallBackInProcess;

  @override
  int get hashCode => Object.hash(reason, canFallBackInProcess);

  @override
  String toString() =>
      'CheckJobCouldNotStart($reason, fallback: $canFallBackInProcess)';
}
