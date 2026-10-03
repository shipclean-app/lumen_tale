// Lumen Tale — the three states a read can end in.
//
// `architecture.md` § 2.2: "The single most load-bearing foundation, and the one
// that cannot be built from a library."
//
// ⚠️ **Nothing in this project returns a bare list from a read, and nothing
// returns null.** B22 is the rule; this type is its expression in the type system,
// so "genuinely nothing" and "could not read" cannot be written the same way — and
// cannot be written the same way by accident, which is the only way it ever
// happened.

import 'package:lumen_tale/core/error/source_failure.dart';

/// The outcome of reading a page from a site. Three states, never two.
sealed class BrowseOutcome<T> {
  const BrowseOutcome();
}

/// The site was read successfully. [items] may legitimately be empty.
final class BrowseSucceeded<T> extends BrowseOutcome<T> {
  const BrowseSucceeded(this.items);

  /// Unmodifiable by contract: an outcome is a value, and a caller that mutates
  /// one has turned a read into an edit. `List.unmodifiable` at every construction
  /// site.
  final List<T> items;
}

/// The site could not be read. [reason] is typed, never a bare string (B24).
final class BrowseFailed<T> extends BrowseOutcome<T> {
  const BrowseFailed(this.reason, {required this.retriable});

  /// One of the six `SourceFailure` causes. Never a `String`: § 5.2 forbids a
  /// platform that interprets a source's free text, and a free-text reason would
  /// leave `isRetriable` undecidable.
  final SourceFailure reason;

  /// B24 — "together with a way to try again".
  ///
  /// ⚠️ **Never free.** § 3.4 of the plan pins it to [SourceFailure.isRetriable]
  /// and one test asserts they never disagree, because a screen that decides for
  /// itself will happily offer a button that cannot repair anything.
  final bool retriable;
}

/// Read, and there is genuinely nothing — distinct from failure, and only
/// available where the site supplies its own empty-result signal.
final class BrowseEmpty<T> extends BrowseOutcome<T> {
  const BrowseEmpty({required this.siteSuppliedSignal});

  /// **Non-nullable, deliberately.**
  ///
  /// `BrowseEmpty` exists *only* where the site provides the signal, so an empty
  /// outcome without one is not a fourth state to represent — it is a missing
  /// discriminant, and `architecture.md` § 2.2 says so in as many words. Making
  /// this nullable would let the one state B22 forbids be constructed directly.
  final String siteSuppliedSignal;
}
