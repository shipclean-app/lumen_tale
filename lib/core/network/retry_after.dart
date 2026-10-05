// Lumen Tale — `Retry-After`, both formats, and the trap of reading one.
//
// HTTP says two different things with this header, and the trap is reading only
// one of them.
//
// Plan `http-client` § 3.3. Covers C7 and `17-security.md` rule 6.

import 'dart:io' show HttpException, HttpDate;

import 'package:lumen_tale/core/network/http_policy.dart';

/// Reads a `Retry-After` header into a clamped [Duration].
///
/// [headerValue] is the raw header, `null` when absent. [now] is the injected
/// clock, because the HTTP-date format is meaningless without a reference point.
///
/// Never throws and never returns a negative duration: an unparseable header is
/// not an error to report, it is a fact about the site, and the app answers it
/// with the fallback rather than with a failure.
Duration parseRetryAfter(String? headerValue, {required DateTime now}) {
  final raw = headerValue?.trim();
  if (raw == null || raw.isEmpty) return HttpPolicy.fallbackRetryAfter;

  // ── format 1: delta-seconds ─────────────────────────────────────────────
  // `Retry-After: 120` → 120 seconds.
  if (_isAllDigits(raw)) {
    return _clamp(Duration(seconds: int.parse(raw)));
  }

  // A leading `-` is a delta-seconds value the site got wrong, or a deliberate
  // "retry immediately". Either way the answer is a ZERO delay and never a
  // negative one: `Future.delayed` with a negative duration is a silent zero,
  // so a negative value here would erase "the site asked us to stop" without
  // leaving a trace. Handled before the date branch, because `-5` is not a date
  // and would otherwise fall through to the fallback — which would make a site
  // answering `-5` wait 30 seconds for no stated reason.
  if (raw.startsWith('-') && _isAllDigits(raw.substring(1))) {
    return Duration.zero;
  }

  // ── format 2: an HTTP-date ──────────────────────────────────────────────
  // `Retry-After: Wed, 21 Oct 2026 07:28:00 GMT`
  //
  // ⚠️ This format EXISTS. An implementation that reads only delta-seconds
  // produces an arbitrary delay on exactly the servers that send dates.
  final at = _tryParseHttpDate(raw);
  if (at != null) {
    final delta = at.difference(now);
    // A date already in the past is a ZERO delay, not a negative one.
    // `Future.delayed` with a negative duration is a silent zero, which would
    // make "the site asked us to stop" disappear in under a second.
    return _clamp(delta.isNegative ? Duration.zero : delta);
  }

  // ── branch 3: absent or unreadable ──────────────────────────────────────
  // Nothing is invented. The fallback applies, and what the screen shows says
  // the site indicated nothing.
  return HttpPolicy.fallbackRetryAfter;
}

bool _isAllDigits(String value) {
  if (value.isEmpty) return false;
  for (final unit in value.codeUnits) {
    if (unit < 0x30 || unit > 0x39) return false;
  }
  return true;
}

DateTime? _tryParseHttpDate(String value) {
  try {
    return HttpDate.parse(value);
  } on HttpException {
    // ⚠️ `HttpDate.parse` throws **HttpException**, not FormatException — read
    // out of `dart:_http`, not guessed. A first draft of this function caught
    // FormatException, so the `catch` never fired and an unreadable
    // `Retry-After` propagated an `HttpException` straight out of the
    // transport, through `get()`, to the caller. The plan's branch 3 ("absent
    // or unreadable → the fallback") was unreachable, and the test that was
    // supposed to prove it is what caught the difference.
    return null;
  } on FormatException {
    return null;
  }
}

/// A site cannot lock the app until tomorrow by asking nicely.
Duration _clamp(Duration duration) {
  if (duration > HttpPolicy.maxRetryAfter) return HttpPolicy.maxRetryAfter;
  return duration;
}
