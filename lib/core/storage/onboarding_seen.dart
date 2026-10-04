// Lumen Tale — one boolean: has the first launch already happened?
//
// `3-4` § 2.1. `core/storage` owns *where a preference lives*, and this file is that
// fact expressed once — the same job `shared_preferences_provider.dart` does for the
// instance itself.
//
// ## ⚠️ THE WHOLE PERSISTED SURFACE OF THIS SCREEN IS ONE BOOLEAN
//
// `3-4` § 3.4 argues why, and the argument is worth keeping next to the code:
//
//     seen == false  ->  two screens replay, ten seconds, the disclosure is made
//                        again. Recoverable.
//     seen == true   ->  nothing replays, and the disclosure was seen.
//
// There is no third case. A system that wrote `{ seenStep: 2 }` would add exactly one
// value — the one that *promises* a resume — and would then need a rule for when it
// expires. Nobody has written that rule, and its absence is the same class of hole
// ADR-023 closed for B35.
//
// ## ⚠️ `readFailsOpen` is a NAME, and the name is the requirement
//
// E11: **nothing can warn the reader at the moment of removal**, so the disclosure has
// to happen *before*. That makes the direction of every failure here load-bearing:
//
// - a read that fails must answer **`false`**, so onboarding is SHOWN. Two sentences to
//   somebody who has already read them is recoverable; never showing them to somebody
//   who has not is not.
// - a write that fails must answer **`false`**, so the caller transitions anyway
//   (§ 3.3 branch 5) and the screen replays **once**. Not trapping a reader in an
//   onboarding flow is worth more than a flag that is certainly written.
//
// `onboarding.md` § 4, *Load error*: *"the failure of a flag must not skip a
// disclosure."* That sentence is the whole contract of this file.

import 'package:shared_preferences/shared_preferences.dart';

/// The key of the "the first launch has happened" flag.
const String onboardingSeenKey = 'onboarding.seen';

/// Reading and writing that one flag.
abstract interface class OnboardingSeenStore {
  /// `true` if the first launch has already happened.
  ///
  /// **On a read failure, answers `false` and does not throw.** See the file header:
  /// the failure of a flag must not skip a disclosure.
  Future<bool> readFailsOpen();

  /// Poses the flag.
  ///
  /// ⚠️ **`true` when the write succeeded, `false` when it did not — and the caller
  /// transitions either way.** The method never throws: an exception here would have to
  /// be caught by three call sites to become the same `false`, and a store that can
  /// throw is a store whose `false` can be forgotten.
  Future<bool> write();
}

/// The store, over the `SharedPreferences` instance the bootstrap already resolved.
final class SharedPreferencesOnboardingSeenStore
    implements OnboardingSeenStore {
  const SharedPreferencesOnboardingSeenStore(this._prefs);

  final SharedPreferences _prefs;

  @override
  Future<bool> readFailsOpen() async {
    try {
      // `getBool` THROWS when the stored value is not a bool — which is a real case,
      // because the key is a plain string in a file that a future build could write a
      // different type into. A cast error is a read failure, and a read failure
      // answers `false`.
      return _prefs.getBool(onboardingSeenKey) ?? false;
    } on Object {
      return false;
    }
  }

  @override
  Future<bool> write() async {
    try {
      return await _prefs.setBool(onboardingSeenKey, true);
    } on Object {
      return false;
    }
  }
}
