// Lumen Tale — why a foreground check stopped, as a value the DOMAIN owns.
//
// `6-10` § 2.2 and § 7's last trap. Pure Dart: **no plugin import, no Flutter**, and
// that is the whole reason this file exists rather than an alias of the plugin's enum.
//
// ## ⚠️ MARKED CLAIM: THIS DUPLICATES `workmanager_platform_interface`'s `StopReason`
//
// `6-10` § 2.2 writes `import
// 'package:workmanager_platform_interface/workmanager_platform_interface.dart' show
// StopReason;` **inside `domain/`**. That cannot be built, for two reasons, and both are
// structural rather than stylistic:
//
//  1. **`workmanager_platform_interface` is not a declared dependency.** Importing a
//     transitive package fires `depend_on_referenced_packages`; the plugin is declared,
//     its platform interface is not, and it is not this slice's job to add one.
//  2. **The transitively reachable alternative drags Flutter into `domain/`.**
//     `package:workmanager/workmanager.dart` re-exports `workmanager_api.g.dart`, whose
//     Pigeon surface imports `package:flutter/services.dart`. So importing the *declared*
//     package from `domain/` pulls `flutter/widgets.dart` in through the back door, and
//     `02-architecture.md` states plainly that `domain` must stay free of Flutter imports.
//     The same interactor (`CheckLibrary`) has to run in the **background isolate** too,
//     which is the reason `library_check.dart` calls itself "strictly pure"; one plugin
//     import here would make that impossible to maintain.
//
// So `domain/` declares its **own** enum with the plugin's ten values, and
// `core/background/workmanager_check_job_engine.dart` holds the **exhaustive `switch`**
// between the two. The duplication is deliberate, it is one file, and it is guarded twice:
//
//   * the mapping `switch` has **no `default`**, so a new plugin value breaks the build;
//   * `test/core/background/check_stop_reason_parity_test.dart` reads the **installed**
//     package and asserts the two sets of names are equal, so a rename breaks a test.
//
// ## ⚠️ MARKED CLAIM: THE ORDER MATCHES THE PLUGIN'S, AND `wireValue` IS THE INDEX
//
// `reportProgress` carries a `Map<String, dynamic>` into an Android notification surface,
// and C2 / `17-security.md` rule 4 permit **integers only** — Android draws that
// notification on a locked screen, and a novel id or a title there is a leak toward
// whoever is holding the phone. A stop reason therefore crosses as an `int`, and this
// enum's declaration order is part of its contract: `wireValue` is the index, and the
// reader on the other end rebuilds the value from the same table.

/// Why Android stopped the foreground check before it finished.
///
/// ⚠️ **TEN VALUES, AND EVERY ONE IS NAMED.** `6-10` § 7's last trap: a `switch` on this
/// with a `default` that says *"failed"* produces exactly the silent screen C12 forbids —
/// a reader on a borrowed phone (C5, the only technical user cannot write code) has no
/// way to describe *"the phone put the app to sleep"* as *"it failed"*. Ten reasons, ten
/// sentences, no catch-all.
enum CheckStopReason {
  /// Android 11 and earlier, or a platform with no equivalent: WorkManager reports no
  /// reason at all. The sentence says so rather than inventing a cause.
  unknown,

  /// The work ran past the time Android allows a foreground service to run.
  timeout,

  /// Something of higher priority took the phone. **The app is not at fault**, and the
  /// sentence must not suggest it was.
  preempt,

  /// ⚠️ **The reader's own gesture.** `cancel()` released the interlock and then asked
  /// WorkManager to stop, so this is `6-10`'s § 3.3 branch 2 — and it is the one reason
  /// whose sentence is *"cancelled"* rather than *"stopped"*.
  cancelledByApp,

  /// ⚠️ **THE ONE REASON THAT IS NOT AN INTERRUPTION AT ALL.** The reader cancelled, the
  /// system ignored it, and the worker **ran to completion**. The pass therefore holds
  /// real results the reader did not ask for, and `6-10` reports it as a success with a
  /// sentence that says *"finished after you cancelled it"* — never *"cancelled"*, which
  /// would send them looking for changes that are already saved.
  systemIgnoredCancelledByApp,

  /// The app is in a background restriction state (battery saver, data saver on some
  /// OEMs). Android paused the work rather than killing it.
  backgroundRestriction,

  /// The device reported an estimated GPU memory limit. One of ten, and it gets its own
  /// sentence rather than the generic one.
  estimatedAppGpuLimit,

  /// The device entered a state that stops work — battery saver being the ordinary case.
  deviceState,

  /// The app entered App Standby.
  appStandby,

  /// The device entered Doze.
  deviceIdle;

  /// The **integer** this reason travels as.
  ///
  /// ⚠️ **A RAW INDEX, NOT A `rawValue`.** The plugin's own `StopReason` carries the
  /// Android constant; this enum is deliberately not ordered by it, and adopting the
  /// plugin's numbering would make a future plugin insert look like a silent
  /// reinterpretation. `fromWireValue` below refuses anything it does not recognise, so a
  /// malformed map is dropped rather than rendered as *unknown*.
  int get wireValue => index;

  /// The reason [value] names, or `null` when it names none.
  ///
  /// ⚠️ **`null` AND NOT [unknown].** Collapsing an unrecognised value into
  /// `StopReason.unknown` is what the plugin itself does, and it is precisely the move
  /// § 7's last trap forbids: two different facts — *"Android said nothing"* and *"Android
  /// said something this build has never heard of"* — would reach the screen as one
  /// sentence. Dropping the value leaves the last real progress standing, which is the
  /// honest state.
  static CheckStopReason? fromWireValue(int value) {
    for (final CheckStopReason reason in CheckStopReason.values) {
      if (reason.wireValue == value) return reason;
    }
    return null;
  }
}
