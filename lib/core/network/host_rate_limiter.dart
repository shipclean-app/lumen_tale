// Lumen Tale — the per-host rate limiter.
//
// ⚠️ The limiter is NOT a retry. It spaces requests **the reader asked for**. The
// difference is total: the limiter changes WHEN a request goes out, never WHETHER
// it goes out. There is no retry policy anywhere in this file, and § 3.6 says
// why that is a decision rather than an omission.
//
// Plan `http-client` § 3.2. Covers C7, B23.

import 'package:lumen_tale/core/network/http_policy.dart';

/// Per-host politeness state.
class HostRateLimiter {
  HostRateLimiter({Clock? clock, Sleeper? sleep})
    : _clock = clock ?? systemClock,
      _sleep = sleep ?? systemSleep;

  final Clock _clock;
  final Sleeper _sleep;

  /// One slot per host, **never** a global.
  ///
  /// B23: two sites must share nothing. A global limiter is one where a slow
  /// site delays another site — and worse, shared state between two sources,
  /// which `failure-discriminator` § 3.6 forbids outright.
  final Map<String, _SlotState> _slots = <String, _SlotState>{};

  /// How many hosts have a slot. A test asserts this is 2 after touching two
  /// hosts, because "per host and never global" is otherwise a claim.
  int get slotCount => _slots.length;

  /// When this host is next allowed to start a request, or `null`.
  ///
  /// Exposed for the cancellation test: a cancellation during the wait must not
  /// clear the window, so a test has to be able to see that it is still set.
  DateTime? blockedUntil(String host) => _slots[host]?.blockedUntil;

  /// Opens a window on one host: no request starts before [until].
  ///
  /// Host-scoped on purpose. `block(h1)` followed by `acquire(h2)` must not wait.
  void block(String host, {required DateTime until}) {
    _slot(host).blockedUntil = until;
  }

  /// Waits until this host may start a request, then marks the start.
  ///
  /// Called from the single request interceptor, so this is C7's one entrance to
  /// the network for the whole application.
  Future<void> acquire(String host) async {
    final slot = _slot(host);
    final now = _clock();

    // ── branch 1: the site asked us to stop (429 + Retry-After) ───────────
    final blockedUntil = slot.blockedUntil;
    if (blockedUntil != null) {
      final wait = blockedUntil.difference(now);
      if (wait > Duration.zero) {
        await _sleep(wait);
        // ⚠️ The window is NOT cleared after the sleep. A request cancelled
        // during the sleep must not be able to leave immediately afterwards:
        // cancellation is not permission to start.
      } else {
        // The window has passed.
        slot.blockedUntil = null;
      }
    }

    // ── branch 2: the minimum interval ────────────────────────────────────
    final lastStart = slot.lastStart;
    if (lastStart != null) {
      final elapsed = now.difference(lastStart);
      final remaining = HttpPolicy.minIntervalPerHost - elapsed;
      if (remaining > Duration.zero) {
        await _sleep(remaining);
      }
    }

    // Set at the START of the request, not the end: what a site measures is the
    // gap between two sends, not how long the service took.
    slot.lastStart = _clock();
  }

  _SlotState _slot(String host) => _slots.putIfAbsent(host, _SlotState.new);
}

class _SlotState {
  _SlotState({this.lastStart, this.blockedUntil});

  DateTime? lastStart;
  DateTime? blockedUntil;
}
