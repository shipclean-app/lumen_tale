// Lumen Tale — how a `DateTime` becomes the two words a history row carries.
//
// ⚠️ **It moved here from `features/history/`, and it is not a provider.** This is
// presentation copy for a timestamp, so `features/settings` was importing a whole
// FEATURE to format a date — which `02-architecture.md` forbids and which
// `tool/check_boundaries.py` reported on every run. Labels belong with labels; the
// history *providers* it used to sit beside now live in `data/history/`.
//
// ⚠️ **Two different questions, two different helpers, and they are not
// interchangeable.** A day-group header answers *"which day was this"*; a row's
// trailing time answers *"how long ago"*. The design gives the row a **relative**
// time and the header a **localised day**, and swapping them produces a screen that
// says *Yesterday* four times and *just now* for a chapter opened this morning.
//
// ## Both take `now` explicitly
//
// A helper that read a clock would be untestable exactly where it matters — at the
// 23:59 → 00:00 boundary, at a DST jump, and at the "is this yesterday?" edge — and
// this is a screen whose only job is getting those boundaries right. `groupByLocalDay`
// already takes `now` for the same reason.
//
// ## Neither ever reaches for `DateFormat` directly
//
// E12: a language change must re-label the screen with no change to any timestamp.
// A date formatted by a locale-tagged `DateFormat` cached at construction would not,
// and `MaterialLocalizations.formatMediumDate` is already resolved for the app's
// locale by the time the widget tree runs.

import 'package:flutter/material.dart';
import 'package:lumen_tale/domain/history/history_grouping.dart';
import 'package:lumen_tale/l10n/generated/app_localizations.dart';

/// The header for [group]'s day.
///
/// *Today* and *Yesterday* are **words**, so they are keys and not formatted dates: a
/// concatenation like `$day $month` is grammatical in English and wrong in French,
/// and this screen is French-first (B28).
///
/// Anything older is `formatMediumDate`, which is the platform's own medium date for
/// the app's locale — *3 Oct 2026* in English, *3 oct. 2026* in French. Choosing it
/// means the app does not carry a date format of its own.
String dayGroupLabel(
  AppLocalizations l10n,
  MaterialLocalizations platform,
  HistoryDayGroup group,
  DateTime now,
) {
  if (isSameLocalDay(group.date, localMidnightOf(now))) {
    return l10n.historyDayToday;
  }
  if (isSameLocalDay(
    group.date,
    localMidnightOf(now.subtract(const Duration(days: 1))),
  )) {
    return l10n.historyDayYesterday;
  }
  return l10n.historyDayOn(platform.formatMediumDate(group.date));
}

/// The trailing time on a row.
///
/// ## Three buckets, and there is deliberately no fourth
///
/// *just now* · *N minutes ago* · *N hours ago*. Then **nothing**.
///
/// Past midnight the day header already says the date, and a row that also said
/// *"2 days ago"* would print the same fact twice on every line — which is how a log
/// stops being scannable. The absence is a decision with a reason, not a gap.
String relativeTimeLabel(
  AppLocalizations l10n,
  DateTime openedAt,
  DateTime now,
) {
  final Duration elapsed = now.difference(openedAt);

  // ⚠️ **A negative duration is clamped to zero, not rendered.** The phone's clock
  // can be behind the last write — a manual correction, an NTP fix after a reboot —
  // and "opened in -4 minutes" is a sentence no reader can act on. `just now` is the
  // honest reading of a gap smaller than a minute.
  if (elapsed.inMinutes < 1) {
    return l10n.historyJustNow;
  }
  if (elapsed.inHours < 1) {
    return l10n.historyMinutesAgo(elapsed.inMinutes);
  }
  // ⚠️ **24 hours is the cut, and it is the local calendar's, not `Duration`'s.**
  // `inHours < 24` would put "23 hours ago" on a row whose header reads *Yesterday* —
  // two answers to one question — and worse, an entry opened at 23:50 and read at
  // 08:00 would say "9 hours ago" under a header reading *Yesterday*, which is
  // yesterday's row saying a number from today.
  if (isSameLocalDay(openedAt, now)) {
    return l10n.historyHoursAgo(elapsed.inHours);
  }
  return '';
}

// ## Why there is no clock time anywhere on this screen
//
// A first version wanted `DateFormat.Hm()` on the row instead of a relative time,
// because `RowTertiary` fits one. A clock time is *worse* for a log: it says "23:47"
// for an entry opened yesterday at 23:47 and the reader cannot tell which, and it
// never updates, so a row that said "just now" at breakfast is lying by lunchtime.
// The relative time is the answer that stays true while the screen is open.
