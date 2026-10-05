// Lumen Tale — "can this phone reach the network right now?", as a question with one honest
// default answer.
//
// ## ⚠️ **THIS IS NOT A PLATFORM CHANNEL, AND § 7.5 OF `5-3` FORBIDS ONE**
//
// `downloads.md` § 9: *"Free space is not displayed — the app has no honest way to read it
// without a platform channel it has not earned."* The same argument applies to reachability:
// v1 ships **no** connectivity plugin, and `09-widgets-ui.md` § Platform behaviour says
// *"No homebrew `MethodChannel` without a strong reason"*. Adding one to answer this
// question would be a socket permission on a reading app for a question the fetch answers
// anyway.
//
// ## ⚠️ **SO THE DEFAULT IS `true`, AND THE REAL ANSWER COMES FROM THE FETCH**
//
// `resume()` asks this before starting a chapter, and a `true` here does not mean "there is
// a network" — it means *"no evidence to the contrary, and refusing to try would be a
// silent no-op"*. B24 forbids the alternative: a *Resume* that does nothing is exactly the
// control `5-2` § 7 calls a silent no-op.
//
// The honest offline answer is produced two chapters later in the same flow: the request
// fails with `NoConnection`, `5-3` § 3.2's `shouldStopQueue('no_connection')` is `true`, and
// the queue reads **stopped — no connection** with a *Resume*. **Same state, same words,
// reached from evidence rather than from a guess** — which is why the seam is an interface
// at all: a test can drive the refused branch, and production drives the observed one.

/// Whether the app should attempt a request right now.
abstract interface class ConnectionProbe {
  /// `false` means *do not start a chapter*. `true` means *no evidence against trying*.
  bool get hasConnection;
}

/// ⚠️ **THE PRODUCTION DEFAULT, AND ITS NAME IS THE DOCUMENTATION.**
///
/// It never refuses, because a v1 build with no connectivity plugin cannot know. Everything
/// the reader is told about a stopped queue is derived from what actually failed.
final class OptimisticConnectionProbe implements ConnectionProbe {
  const OptimisticConnectionProbe();

  @override
  bool get hasConnection => true;
}
