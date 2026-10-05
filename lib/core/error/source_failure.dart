// Lumen Tale — the typed causes of a failed read.
//
// `architecture.md` § 5.2: "core/error — one type per cause, each with its
// recovery. B22 needs causes distinguished, not collapsed."
//
// ⚠️ A cause NEVER carries a sentence. It carries the *facts* the screen needs in
// order to write its evidence line (`source-unavailable.md` § 8, `causeEvidence`),
// and the screen is what turns them into words — in French and in English (B28).
// A `String` diagnostic here would be exactly the "errorCode free-text field the
// platform interprets" § 5.2 forbids by name, and it would make `isRetriable`
// undecidable.
//
// `StorageFull` is deliberately absent: § 5.2's list covers *reads*. A full disk is
// a write failure and belongs to `5-3`. Putting it here would let a
// `BrowseFailed` claim the site could not be read when the disk is full.
//
// ⚠️ **`==` and `hashCode` are hand-written here, deliberately.** `08-coding-standards.md`
// rule 15 says domain models are `freezed` classes with generated equality — and
// these are not freezed classes, for two reasons that are visible in the
// dependency table. `core/` is the leaf layer and imports nothing from `lib/`, so
// an annotation-driven `part` file in `core/error` would put a codegen dependency
// at the bottom of the graph. And each of these is five final fields of primitive
// type; `freezed` would emit more code than it replaces, plus a `copyWith` on a
// type where "copy it with a different retryAfter" is never a thing anyone wants.
//
// They are written anyway, because the first version of the test suite failed on
// them: `expect(cause, const NoConnection(host: 'x'))` compares with `==`, and two
// identical failures compared unequal. A value carrier whose equality is identity
// cannot go in a `Set`, cannot be compared by a screen, and cannot be asserted on —
// so "it is a value" would have been a comment rather than a property.

/// A typed cause of a read failure.
///
/// B22 needs causes distinguished, not collapsed: three of the six have no retry
/// worth offering and one of those has nothing wrong with it at all.
sealed class SourceFailure {
  const SourceFailure();

  /// Whether a second identical request is worth making.
  ///
  /// Derived from the type, and **the type is the only place it is written**.
  /// `BrowseFailed` carries a `retriable` field as well; the two must always
  /// agree, and a test asserts that across all six causes.
  bool get isRetriable;
}

/// `architecture.md` § 5.2: "NoConnection | — | later, on its own". E5.
///
/// Carries the host only — never a full URL, which would put a reader-supplied
/// path or query in an error surface (C5, `17-security.md` rule 1).
final class NoConnection extends SourceFailure {
  const NoConnection({required this.host});

  /// The hostname the transport failed against, e.g. `www.fanmtl.com`.
  ///
  /// Never a path, never a query, never anything the reader typed.
  final String host;

  @override
  bool get isRetriable => true;

  @override
  bool operator ==(Object other) => other is NoConnection && other.host == host;

  @override
  int get hashCode => Object.hash(NoConnection, host);
}

/// `architecture.md` § 5.2: "RateLimited(retryAfter) | duration | after
/// Retry-After | wait". `17-security.md` rule 6 — honoured, never guessed.
///
/// No `host`: a 429 belongs to a host, not to a source, and the limiter's slot
/// table already keys on it. A second copy of a fact that exists is a second
/// thing free to disagree (`fetch_result.dart` says the same of its own case).
final class RateLimited extends SourceFailure {
  const RateLimited({required this.retryAfter});

  /// How long the site asked us to wait. `Duration.zero` is legal and means the
  /// site sent no usable `Retry-After`.
  final Duration retryAfter;

  @override
  bool get isRetriable => true;

  @override
  bool operator ==(Object other) =>
      other is RateLimited && other.retryAfter == retryAfter;

  @override
  int get hashCode => Object.hash(RateLimited, retryAfter);
}

/// `architecture.md` § 5.2: "SourceLayoutChanged | selector that failed | no |
/// nothing — report the bug". **E4, E8, SC-6.**
///
/// This is the cause that exists because of `0-1`'s manufactured fixture: a page
/// that returned 200, parsed cleanly, and held none of the elements the app looks
/// for.
final class SourceLayoutChanged extends SourceFailure {
  const SourceLayoutChanged({
    required this.failedSelector,
    required this.status,
    this.siteSuppliedSignal,
  });

  /// The source's own selector, verbatim, so the owner can read it against the
  /// fixture and see which one came back empty.
  ///
  /// Never an exception string, never a stack trace, never page content (C6).
  final String failedSelector;

  /// The HTTP status of the response that was read.
  ///
  /// Always present here: this cause requires a response that actually arrived.
  final int status;

  /// The site's own explicit empty-result marker, **when the page carried one
  /// that was not the selector the source expected to match**.
  ///
  /// This is what makes SC-6 *demonstrable* rather than asserted: the reason the
  /// page is being read as broken is that the site said so in its own words, and
  /// that string is kept instead of discarded. Null in the far more common case
  /// where the site said nothing at all.
  final String? siteSuppliedSignal;

  @override
  bool get isRetriable => false;

  @override
  bool operator ==(Object other) =>
      other is SourceLayoutChanged &&
      other.failedSelector == failedSelector &&
      other.status == status &&
      other.siteSuppliedSignal == siteSuppliedSignal;

  @override
  int get hashCode => Object.hash(
    SourceLayoutChanged,
    failedSelector,
    status,
    siteSuppliedSignal,
  );
}

/// `architecture.md` § 5.2: "SourceUnavailable | status | later | back off".
///
/// Also the cause an anti-bot challenge is reported as. ADR-014: this app does
/// not attempt to get past one, and `source-unavailable.md` § 5 requires the
/// challenge to be **named** rather than hidden — which is why [isChallenge]
/// exists as a field instead of the string being thrown away.
final class SourceUnavailable extends SourceFailure {
  const SourceUnavailable({required this.status, this.isChallenge = false});

  final int status;

  /// True when the body was an interactive anti-bot challenge rather than a plain
  /// refusal or an outage.
  ///
  /// Measured from the body by the source that read it, never inferred from the
  /// status alone: 403 is a challenge far more often than it is a refusal.
  final bool isChallenge;

  @override
  bool get isRetriable => true;

  @override
  bool operator ==(Object other) =>
      other is SourceUnavailable &&
      other.status == status &&
      other.isChallenge == isChallenge;

  @override
  int get hashCode => Object.hash(SourceUnavailable, status, isChallenge);
}

/// `architecture.md` § 5.2: "ItemRemovedAtSource | which item | no | go back; the
/// rest is unaffected". **E9.**
///
/// `source-unavailable.md` § 2.1: for this cause there is **no retry button at
/// all** — not a disabled one — because the site answered and confirmed the item
/// is gone.
final class ItemRemovedAtSource extends SourceFailure {
  const ItemRemovedAtSource({required this.itemId, required this.status});

  /// The app's own id for the item — a novel id, never a site URL (C5).
  final String itemId;

  final int status;

  @override
  bool get isRetriable => false;

  @override
  bool operator ==(Object other) =>
      other is ItemRemovedAtSource &&
      other.itemId == itemId &&
      other.status == status;

  @override
  int get hashCode => Object.hash(ItemRemovedAtSource, itemId, status);
}

/// `architecture.md` § 5.2: "ParseFailed | file path | no | report the bug".
///
/// B22's third arm: "a parse error … → the site could not be read".
final class ParseFailed extends SourceFailure {
  const ParseFailed({required this.path});

  /// The path the parse failed on: a site-relative request path while reading a
  /// source, a support-relative file path while reading a stored chapter.
  ///
  /// Never an absolute path — `17-security.md` rule 4 — and never page content.
  final String path;

  @override
  bool get isRetriable => false;

  @override
  bool operator ==(Object other) => other is ParseFailed && other.path == path;

  @override
  int get hashCode => Object.hash(ParseFailed, path);
}

/// The app cannot say what happened, because it cannot read its own record of the failure.
///
/// ⚠️ **Its own case, and it is a claim rather than a default.** A reader who is told "the site
/// changed" and is then told the site is fine, and then is told the network is down, has been
/// told three things and believes none. Saying *this app cannot say* is weaker than any of
/// them and is the only one that is true.
///
/// It exists in `core/error` rather than in a feature because `SourceFailure` is sealed here,
/// and a vocabulary that lives apart from the type it extends cannot be exhaustive.
final class CauseUnknown extends SourceFailure {
  const CauseUnknown();

  /// ⚠️ **Not retriable, and that is a claim.** An app that does not know what happened cannot
  /// know whether trying again would help — and a retry button here would be the app guessing
  /// twice.
  @override
  bool get isRetriable => false;

  @override
  bool operator ==(Object other) => other is CauseUnknown;

  @override
  int get hashCode => 0;

  @override
  String toString() => 'CauseUnknown';
}
