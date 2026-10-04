// Lumen Tale — the decision that happens **before any screen is built**.
//
// `3-4` § 3.1. E11 needs the disclosure made *before* an uninstall, and the only moment the
// app can force a screen alone is first run, so the decision belongs in the router's
// `redirect` and not in `main()`.
//
// ## ⚠️ WHY A TOP-LEVEL MUTABLE HOLDER, AND WHY THAT IS NOT SLOPPINESS
//
// `appRouter` is a **top-level `final`** — `app_router.dart`'s header gives the reason, and
// it is a good one: a router rebuilt on a locale change starts at `initialLocation` and the
// reader loses their place. A top-level final also cannot read a Riverpod container, so the
// flag reader has to arrive from outside. `screen_registry.dart` already solves exactly this
// in the same directory with the same two tables and the same justification, and `main.dart`
// is already the composition root that fills them. A third mechanism would be worse than a
// second one.
//
// ## ⚠️ THE GATE **LATCHES**, AND THAT IS THE WHOLE OF ITS CORRECTNESS
//
// go_router runs `redirect` on **every** navigation, not once at launch. A gate that merely
// answered "is the flag set?" would therefore re-evaluate on every route change, and the
// first branch of § 3.3 branch 5 — a flag write that failed, so the reader is on
// `/library` with `seen == false` — would bounce them back into onboarding every time they
// pressed a tab. § 3.3 is explicit: *"a flag that can re-show a skipped screen is a bug, not
// a safety."*
//
// So the gate answers **once**, latches, and never reads the flag again for the life of the
// process. That also makes the cold-start decision the only decision: a deep link is not a
// first run.

import 'package:flutter/widgets.dart';

import 'package:lumen_tale/app/router/app_routes.dart';

/// Answers the router's cold-start question.
abstract interface class StartupGate {
  /// The location to cold-start on, or **`null`** to leave the router alone.
  ///
  /// Returning `null` means "no opinion", and it is the answer for both "the reader has
  /// seen the disclosure" and "there is nothing left to decide".
  Future<String?> resolve(String matchedLocation);

  /// ⚠️ **THE SAME ANSWER, WITHOUT THE `await` — and the router calls THIS one.**
  ///
  /// A `Future`-returning redirect costs a microtask even when it never awaits anything,
  /// because go_router awaits the redirect before it builds the first page.
  /// `test/app/shell/app_shell_test.dart` is the row that measures it: *"outside the shell
  /// the reader has no transition in"* pumps **once** and asserts the tab bar is gone, which
  /// only holds if the redirect costs nothing.
  ///
  /// ⚠️ **THEREFORE A GATE MUST BE ABLE TO ANSWER WITHOUT READING.** That is why
  /// `installStartupGate` seeds it before installing: an installed gate has already read the
  /// flag, so `resolveNow` is a lookup rather than a question.
  String? resolveNow(String matchedLocation);
}

/// The gate E11 requires: **the flag, read once, and it fails open.**
///
/// ⚠️ **THREE BRANCHES, AND THE ERROR ONE IS THE IMPORTANT ONE** (§ 3.1):
///
/// ```text
/// read throws / answers false  ->  /onboarding    (never /library)
/// not seen                     ->  /onboarding
/// seen                         ->  null
/// ```
///
/// `onboarding.md` § 4, *Load error*: *"the failure of a **flag** must not skip a
/// **disclosure**."* Showing two sentences to a reader who has already read them costs ten
/// seconds; never showing them to one who has not costs data nobody warned them about. The
/// error cost is measured and named rather than absorbed.
final class OnboardingStartupGate implements StartupGate {
  OnboardingStartupGate(this._readSeen);

  /// ⚠️ **A `Future<bool>` TAKEN AS A VALUE, NOT A `Future<bool> Function()`.** The store is
  /// resolved at the composition root, where the `SharedPreferences` instance already
  /// exists, so a closure would only re-derive something the caller holds.
  final Future<bool> Function() _readSeen;

  /// The stored answer, read once at bootstrap. Public so `installStartupGate` can seed
  /// the gate without reaching into its own closure.
  Future<bool> readSeenOnce() => _readSeen();

  bool _decided = false;

  /// Whether the cold-start question has been answered. Exposed so the rows that assert the
  /// latch can read it without inferring it from a second call's behaviour.
  bool get hasDecided => _decided;

  /// ⚠️ **THE ANSWER, ALREADY HELD — and this is what keeps `resolve` SYNCHRONOUS.**
  ///
  /// `main()` awaits `SharedPreferences.getInstance()` **before** `runApp`, so the flag can
  /// be read there and handed in. `resolve` then returns without awaiting, and go_router
  /// builds the first page in the frame it is asked for.
  ///
  /// ⚠️ **THE FIRST VERSION AWAITED, AND IT COST TWO REAL THINGS.** `test/app/shell`
  /// asserts that opening a chapter shows NO transition and that the shell's bar is gone
  /// after **one** `pump()`; an async redirect yields first, so the reader had not mounted
  /// and the bar was still in the tree. `test/widget_test.dart`'s bootstrap rows failed the
  /// same way. Neither is a test that should have been weakened — the reader opening a
  /// chapter in one frame is the property `0-5` wrote down, and a gate may not tax it.
  bool? _answer;

  /// Seeds the gate with the answer read at bootstrap.
  ///
  /// ⚠️ **`false` is the FAIL-OPEN branch and it is seeded too.** A flag that could not be
  /// read must still show the disclosure (`onboarding.md` § 4), so the bootstrap seeds `false`
  /// on a read error rather than leaving the gate undecided.
  void seed({required bool seen}) => _answer = seen;

  @override
  Future<String?> resolve(String matchedLocation) async {
    // ⚠️ **THE LATCH IS CHECKED *BEFORE* THE READ, and moving it after cost five reads.**
    // When the latch lived inside the decision, every call re-read the flag first and only
    // then discovered the question was already spent: `reader.calls` came back **5** where
    // § 3.3 branch 5 requires **1**. "Read once per process" is a property of *asking*, not
    // of deciding, so the gate must not ask a question it already has the answer to.
    if (_decided) {
      return null;
    }

    // ⚠️ **THE SEEDED ANSWER IS TAKEN NEXT, because it needs no `await`.** A
    // `Future<String?> resolve` is already a microtask even when it returns without awaiting
    // anything, and go_router `await`s the redirect — so an async signature taxes the first
    // frame whether or not it reads anything. The bootstrap read happens before `runApp`, so
    // the async signature is reached only by a caller that installed the gate without
    // seeding it.
    final bool? seeded = _answer;
    if (seeded == null) {
      bool seen;
      try {
        seen = await _readSeen();
      } on Object {
        // ⚠️ **BRANCH 1, AND THE `catch` IS NOT DEFENSIVENESS FOR ITS OWN SAKE.**
        // `readFailsOpen()` is contractually incapable of throwing, so this arm is
        // unreachable *through the store*. It stays because the gate takes a bare
        // `Future<bool> Function()`: a caller that supplies a different reader — a test, or a
        // future store — must not be able to turn a flag failure into an exception, because
        // go_router turns a throwing `redirect` into an **error page** (verified in
        // `configuration.dart`, `applyTopLegacyRedirect`'s `catchError`). An exception here
        // would be the exact opposite of showing the disclosure.
        seen = false;
      }
      return decide(matchedLocation, seen: seen);
    }
    return decide(matchedLocation, seen: seeded);
  }

  @override
  String? resolveNow(String matchedLocation) {
    // ⚠️ **THE SAME LATCH-FIRST ORDER AS `resolve`.** A synchronous gate that re-decided
    // would be no gate at all; one that read would be impossible, since reading is the one
    // thing it cannot do.
    if (_decided) {
      return null;
    }
    return decide(matchedLocation, seen: _answer ?? false);
  }

  /// The whole decision, and it is **synchronous**: the latch, the two exemptions, and the
  /// one branch.
  ///
  /// ⚠️ **ONE IMPLEMENTATION, TWO ENTRY POINTS.** `resolve` and `resolveNow` are the same
  /// decision reached two ways, and an earlier version had the logic written twice. Two
  /// copies of a redirect's branches are two sets of rules, and they drift the first time
  /// one of them gains an exemption — which is exactly what happened: `resolve` had the
  /// `/onboarding` exemption and `resolveNow` did not.
  String? decide(String matchedLocation, {required bool seen}) {
    if (_decided) {
      return null;
    }
    // ⚠️ **LATCHED *BEFORE* ANY BRANCH, AND LATCHED EVEN FOR `/onboarding` ITSELF.**
    //
    // Latching only on a decision would leave the gate open on the one route that must
    // never redirect: the reader who was pushed `/onboarding?step=disclosure` from Settings
    // and then pressed `Start reading`, whose flag write failed, would be sent straight back
    // into the disclosure by the very navigation that was meant to end it.
    _decided = true;

    // ⚠️ **NEVER REDIRECT *AWAY FROM* `/onboarding`.** The disclosure is the one destination
    // this app must not take back from a reader, and matching on the path prefix rather
    // than on equality is what lets `?step=disclosure` through as well.
    if (matchedLocation.startsWith(AppRoutes.onboarding)) {
      return null;
    }

    // ⚠️ **AND NEVER *INTO* A READER.** `/reader/…` is a STANDALONE route outside the shell,
    // reached by `push` from four places, and it is the one destination a reader asked for by
    // name. A cold-start gate that captured it would answer "start reading" with the
    // disclosure — and because the gate latches, the chapter would then open anyway, so the
    // reader sees the disclosure flash in front of the chapter they tapped.
    //
    // `test/app/shell/app_shell_test.dart` is the row that caught this: the gate arrived with
    // the disclosure exemption and not this one.
    //
    // ⚠️ **`AppRoutes.readerRoot`, NOT `AppRoutes.reader`, AND THE DIFFERENCE IS THE WHOLE
    // RULE.** `reader` is the **pattern** `'/reader/:novelId/:chapterId'`, and
    // `'/reader/n1/c1'.startsWith('/reader/:novelId/:chapterId')` is `false` — so the
    // exemption as first written never fired, while reading exactly like one that always
    // does. `test/features/onboarding/onboarding_startup_gate_test.dart` caught it on its
    // first run; `AppRoutes.readerRoot` now exists because a prefix needs a name.
    if (matchedLocation.startsWith(AppRoutes.readerRoot)) {
      return null;
    }

    return seen ? null : AppRoutes.onboarding;
  }
}

StartupGate? _installed;

/// Installs the gate. **`main()` does this, once, before `runApp`.**
///
/// ⚠️ **A `null` GATE IS "NO OPINION", NOT "SHOW ONBOARDING".** A missing installation must
/// not be the thing that decides a first run: it would mean the reader is sent to
/// `/onboarding` by an app whose flag store is fine. It is why `main()`'s call is asserted
/// by count in `test/app/shell/app_shell_test.dart` — the failure mode of a missing
/// installation is invisible at runtime, which is precisely what a count catches.
Future<void> installStartupGate(StartupGate gate) async {
  _installed = gate;
  if (gate is! OnboardingStartupGate) return;
  try {
    // ⚠️ **A READ ERROR SEEDS `false`.** `onboarding.md` § 4: the failure of a FLAG must not
    // skip a disclosure. Deciding it HERE rather than inside `resolve` is what lets
    // `resolve` stay synchronous, and so lets the reader mount in its first frame.
    gate.seed(seen: await gate.readSeenOnce());
  } on Object {
    gate.seed(seen: false);
  }
}

/// The installed gate, or `null` when nothing is installed.
StartupGate? get installedStartupGate => _installed;

/// Clears the installation. **Tests only.**
@visibleForTesting
void clearStartupGate() => _installed = null;
