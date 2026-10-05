// Lumen Tale — transport policy constants.
//
// The three numbers no document in this project fixes. They live in one place
// because "where is the minimum delay between two requests" is a question with
// one answer, and two answers would be two politeness policies.
//
// Plan `http-client` § 2.4. Covers C7 and `17-security.md` rules 3 and 6.

final class HttpPolicy {
  const HttpPolicy._();

  /// C7 — the minimum interval between two request **starts** to the same host.
  ///
  /// `17-security.md` rule 6 says "rate limit and back off" without giving a
  /// number; `architecture.md` § 2.3 says "enforced in one place". One second is
  /// the unit that makes "we are not hammering the site" assertable in a test,
  /// and the test is the only proof a delay exists.
  static const Duration minIntervalPerHost = Duration(seconds: 1);

  /// The wait applied when a 429 (or a 503) arrives **without** a readable
  /// `Retry-After`.
  ///
  /// An absent header is not a zero. Guessing zero would turn "the site asked us
  /// to stop" into "we tried again immediately", which is the behaviour C7
  /// exists to prevent.
  static const Duration fallbackRetryAfter = Duration(seconds: 30);

  /// The ceiling on an accepted `Retry-After`.
  ///
  /// A site answering `Retry-After: 86400` cannot lock the app until tomorrow:
  /// the value is clamped here, and `source-unavailable.md` § 5 counts down over
  /// **60 seconds**, which is the most the screen ever shows.
  static const Duration maxRetryAfter = Duration(minutes: 10);

  /// `17-security.md` rule 3 — the ceiling on an HTML body read into memory. A
  /// source returning a 500 MB "chapter" is a bug or an attack.
  ///
  /// This ceiling is **transport**, not persistence: it protects memory. The
  /// persistence ceiling belongs to `2-3` / `5-1` (`07-downloads-offline.md`) and
  /// is a different number for a different reason.
  static const int maxBodyBytes = 4 * 1024 * 1024;
}

/// The three timeouts.
///
/// `17-security.md` asks "Does any new network call lack a timeout, a User-Agent,
/// or rate limiting?" — that is a review question, so all three answers sit in one
/// named constant rather than being spelled at each call site.
final class HttpTimeouts {
  const HttpTimeouts._();

  /// Connect + TLS + request. Ten seconds: past that the phone is in a tunnel or
  /// the site is dead, and both present as "no connection".
  static const Duration connect = Duration(seconds: 10);

  /// Sending the request. A GET has no body, so this matches [connect].
  static const Duration send = Duration(seconds: 10);

  /// Receiving the response. Twenty seconds: a catalogue page legitimately takes
  /// longer than ten to come down, and killing a read because the server is slow
  /// would produce a `NoConnection` that is not one.
  static const Duration receive = Duration(seconds: 20);
}

/// The injected clock and sleep, so the rate limiter is testable without waiting
/// a real second.
///
/// A real `DateTime.now()` and a real `Future.delayed` would make every timing
/// test either slow or flaky, and a slow test is a test that gets deleted. This
/// is the seam `http-client` § 3.2's "horloge injectée" refers to.
typedef Clock = DateTime Function();

typedef Sleeper = Future<void> Function(Duration);

DateTime systemClock() => DateTime.now();

Future<void> systemSleep(Duration duration) {
  if (duration <= Duration.zero) return Future<void>.value();
  return Future<void>.delayed(duration);
}
