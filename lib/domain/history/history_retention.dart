// Lumen Tale — B47: the journal is bounded by **time**, never by a count.
//
// Why an enum and not a `Duration`: because a raw `Duration` accepts
// `Duration(days: 45)`, and a window nothing in the product offers is a value no
// screen can render. An enum makes the set of choices closed **and** testable — a
// free number is a value with no row in `SettingsChoiceSheet`, and a sheet with a
// missing row is a settings screen that cannot show its own setting.
//
// ⚠️ **There is no "keep everything".** `design-system.md` § 2.12 says v1 has exactly
// one *kind* of single-value choice, and its five values are these. Adding a
// sixth unbounded one would give the reader a way to say "keep forever" to a
// product that stores nothing remotely (C8, ADR-010) — a promise with no
// consequence behind it.
//
// Pure Dart. No Flutter import.

/// The five windows `design-system.md` § 2.12 specifies.
///
/// Ordered shortest to longest, and the order is **the sheet's row order** — not
/// alphabetical, not by likelihood. A reader scanning for "one year" should find the
/// same position whether they are reading the enum or the screen.
enum HistoryRetention {
  oneWeek,
  oneMonth,
  threeMonths,

  /// B47's default, and the *conservative* end of the range a reader is offered.
  oneYear,
  twoYears;

  /// How far back the window reaches.
  Duration get window => switch (this) {
    HistoryRetention.oneWeek => const Duration(days: 7),
    HistoryRetention.oneMonth => const Duration(days: 30),
    HistoryRetention.threeMonths => const Duration(days: 90),
    HistoryRetention.oneYear => const Duration(days: 365),
    HistoryRetention.twoYears => const Duration(days: 730),
  };

  /// B47: *one year* is the **default, not the implementer's choice**. It is the
  /// conservative end of the band every platform bounds activity history to, and a
  /// reader who has chosen nothing has chosen the bounded one.
  static const HistoryRetention defaultWindow = HistoryRetention.oneYear;

  /// The instant before which an entry is out of the window.
  ///
  /// **Never stored.** Compared against `opened_at` on every read, which is why a
  /// reader who later lengthens their window sees a boundary move rather than a
  /// column change.
  DateTime cutoffFrom(DateTime now) => now.subtract(window);

  /// The value to persist when nothing has been stored yet.
  ///
  /// ⚠️ **Returning the default here means a *read* writes nothing.** The rule is the
  /// same as `theme-type`'s: the default is the **absence** of a key, so "has the
  /// reader chosen anything?" stays answerable.
  static HistoryRetention fromStorage(String? stored) {
    if (stored == null) return defaultWindow;
    for (final HistoryRetention value in values) {
      if (value.name == stored) return value;
    }
    // A stored value the enum no longer has. The window is **widened back to the
    // default**, never narrowed to something arbitrary: a reader whose preference
    // cannot be read gets the conservative window rather than a guess.
    return defaultWindow;
  }
}
