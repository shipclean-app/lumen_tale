// Lumen Tale — "once, on display", as a two-line class a row can drive directly.
//
// ## Why this is extracted rather than a field on the screen's `State`
//
// B13's rule is *once*, and the first implementation kept it as a `bool` on
// `_ReaderScreenState`. That is correct code and an **untestable rule**: provoking a rebuild
// of `ReaderScreen.build` without also replacing its `ConsumerState` needs a provider that
// watches something, and the screen watches two providers that are both injected — so the
// guard could only be exercised by replacing the whole tree, which resets the flag and
// proves nothing.
//
// A sabotage that removed the guard passed every row.
//
// This class has no widget, no container and no lifecycle. A row drives it directly, and
// the screen's flag becomes a call.

/// Lets one action happen exactly once, and reports whether this call was the one.
final class OnceGate {
  bool _spent = false;

  /// Whether the action has already run.
  bool get isSpent => _spent;

  /// Runs [action] only if it has not run before, and returns whether it ran.
  ///
  /// ⚠️ **`isSpent` flips BEFORE [action] runs, not after.** An action that throws and then
  /// is retried would otherwise run twice, and the write B13 guards is exactly the sort of
  /// thing that throws — a closed database, a full disk. Whether a *failed* mark should be
  /// retried on the next rebuild is `3-3`'s question; what is decided here is only that this
  /// screen does not call it twice for one display.
  bool run(void Function() action) {
    if (_spent) {
      return false;
    }
    _spent = true;
    action();
    return true;
  }
}
