// Lumen Tale — the contract `features/updates` programs against for B37.
//
// `6-10` § 2.2. Pure Dart, and the implementation is
// `core/background/foreground_check_job.dart` because `core` is the only layer allowed to
// import an external plugin — `02-architecture.md`'s dependency table says `core` may
// depend on external packages only, and a plugin is one.
//
// ## ⚠️ MARKED CLAIM: `dispose()` IS ON THE INTERFACE, NOT ONLY ON THE IMPLEMENTATION
//
// The two streams below are the app's only view of a pass that runs in **another
// isolate**, so their lifetime cannot be the widget's. `05-state-management.md` rule 10
// asks a `keepAlive` provider for a written reason and a matching teardown: this is it.
// Keeping `dispose` off the interface would force the provider to know the concrete class
// to close what the interface opened — which is the same "a caller cannot do three things
// and forget the third" defect `invalidateLibraryProviders` documents.

import 'dart:async';

import 'package:lumen_tale/domain/updates/check_job.dart';

/// Starts, watches and stops **one** manual check pass (B37, B36).
///
/// ⚠️ **THE SINGLE GESTURE. There is no schedule** (ADR-023 withdrew B35), so every call
/// to [start] originates from a reader's tap and from nothing else: not start-up, not
/// resume, not a list scroll, not a tab change.
abstract interface class CheckJobController {
  /// Asks for the notification permission if one is needed, then starts **one** pass as a
  /// foreground job.
  ///
  /// ⚠️ **CALLING IT TWICE DOES NOT START TWO PASSES.** The second call returns `null`
  /// without doing anything — not an error, because a pass is already running and the
  /// button is already in its loading state. C7 is the reason it must be `null` rather
  /// than a second pass: a double tap would double the traffic to every site and
  /// interleave two writers of `last_checked_at`.
  ///
  /// Returns `null` when the pass has started, and a [CheckJobCouldNotStart] when it could
  /// not. The **terminal** outcome does not come back here: it arrives on [outcomes],
  /// because this call returns as soon as the job is registered and a background isolate
  /// may run for minutes.
  Future<CheckJobOutcome?> start({
    required CheckJobNotificationCopy notification,
  });

  /// Cancels **this** pass, and nothing else.
  ///
  /// ⚠️ **RELEASES THE INTERLOCK FIRST, AND THAT ORDER IS THE RULE.** A background
  /// isolate killed by the system runs **no `finally`**, so relying on the platform's
  /// `onTaskStopped` to let go would leave the flag set for ever and refuse every future
  /// pass with no explanation. Releasing first makes the pass's own cancellation gate see
  /// the gesture even if the platform never calls back.
  ///
  /// Touches no preference, no library row and no download work: `cancelByUniqueName` is
  /// targeted by name, never `cancelAll()` (E7 — the download queue is in-process, and a
  /// `cancelAll()` would start killing it the day anything else used this plugin).
  Future<void> cancel();

  /// The permission as the system reports it now, for `settings.md` § 4's warning row.
  Future<NotificationPermission> permissionState();

  /// The counter, for `AppScaffold.persistentStatus`: *Checking 7 of 23 novels · nothing
  /// is downloaded* — B39 and B38 in one sentence.
  ///
  /// ⚠️ **NOT THE PASS'S RESULT.** `6-4`'s own `libraryCheckProgressProvider` already
  /// serves the in-process fallback; this one is fed by the background isolate's
  /// `reportProgress` and is the only thing that can move while the app is in the
  /// notification shade.
  Stream<CheckJobProgress> get progress;

  /// How the pass ended — **including** the endings that are not successes.
  ///
  /// ⚠️ **THIS STREAM EXISTS BECAUSE § 10's "an interrupted pass is never rendered as a
  /// successful one" IS NOT ENFORCEABLE WITHOUT IT.** `start` returns before the pass
  /// runs, so without a terminal channel a stopped pass would simply stop being drawn and
  /// the reader would be left with the last progress line they saw — *"Checking 7 of
  /// 23"*, with no statement that it never finished.
  Stream<CheckJobOutcome> get outcomes;

  /// Closes [progress] and [outcomes].
  ///
  /// ⚠️ **IDEMPOTENT, and the composition root owns it.** `ProviderContainer.dispose()`
  /// calls this through `ref.onDispose`; a second call must not throw, or a container
  /// torn down twice takes the test suite with it.
  void dispose();
}

/// Runs the pass **in this isolate** when the foreground job cannot be registered.
///
/// ⚠️ **AN INTERFACE WITH ONE PRODUCTION IMPLEMENTATION, AND THAT IS THE POINT.**
/// `6-10` § 3.4 forbids writing a second implementation of `6-4`'s loop "for the
/// background isolate": two implementations of a rule half of SC-3 depends on diverge
/// invisibly, because both produce a plausible result. This seam carries a single
/// `Future<void>` so the fallback is a **call into `6-4`'s notifier** — the same object
/// the button used before this slice existed — and a test can count that it ran once.
abstract interface class CheckJobFallback {
  /// Runs one pass in the main isolate. Called **at most once per [CheckJobController.start]**,
  /// and never while a foreground job is registered.
  Future<void> runInProcess();
}
