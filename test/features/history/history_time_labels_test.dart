// Lumen Tale — `history.md`'s day headers and row times, at the boundaries.
//
// ## These are widget-free helpers that only fail at a boundary
//
// `dayGroupLabel` and `relativeTimeLabel` take `now` explicitly *because* their
// interesting behaviour is all in the boundaries: 23:59 → 00:00, midnight local vs
// UTC, a clock behind the last write. A helper that read a clock could not be tested
// on any of them — which is why this file exists as pure rows rather than as part of
// the screen's widget test.
//
// ## E12 is a row here, not a hope
//
// "A language change re-localises the screen" is a claim about *words chosen at build
// time*: `Today` and `Yesterday` are keys, and everything older is the platform's own
// medium date. A concatenation would be English-shaped and would survive E12 while
// being wrong in French.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumen_tale/domain/history/history_entry.dart';
import 'package:lumen_tale/domain/history/history_grouping.dart';
import 'package:lumen_tale/features/history/history_time_labels.dart';
import 'package:lumen_tale/l10n/generated/app_localizations.dart';

HistoryEntry entryOpenedAt(DateTime at) => HistoryEntry(
  id: 'h1',
  novelId: 'n1',
  novelTitle: 'A Novel',
  chapterId: 'c1',
  chapterTitle: 'Chapter one',
  openedAt: at,
);

/// A group with **no entries**, which is all a label needs.
///
/// The default exists because every call site in this file is testing a *label*, and
/// a caller that passed an empty list to say "I am not testing the entries" was
/// carrying a fact about itself in a second argument.
HistoryDayGroup groupOn(
  DateTime day, [
  List<HistoryEntry> entries = const <HistoryEntry>[],
]) => HistoryDayGroup(date: day, entries: entries);

Future<AppLocalizations> l10nOf(Locale locale) =>
    AppLocalizations.delegate.load(locale);

void main() {
  late AppLocalizations en;
  late AppLocalizations fr;
  late MaterialLocalizations platform;

  setUpAll(() async {
    en = await l10nOf(const Locale('en'));
    fr = await l10nOf(const Locale('fr'));
    platform = await GlobalMaterialLocalizations.delegate.load(
      const Locale('en'),
    );
  });

  group('the day header', () {
    test('today and yesterday are WORDS, not formatted dates', () {
      // A concatenation would be English-shaped and would survive E12 while being
      // wrong in French — "Aujourd'hui 3 octobre" is not a French sentence.
      expect(
        dayGroupLabel(
          en,
          platform,
          groupOn(DateTime(2026, 10, 3)),
          DateTime(2026, 10, 3, 9),
        ),
        'Today',
      );
      expect(
        dayGroupLabel(
          en,
          platform,
          groupOn(DateTime(2026, 10, 2)),
          DateTime(2026, 10, 3, 9),
        ),
        'Yesterday',
      );
    });

    test('the words are the app locale, not English in both', () {
      expect(
        dayGroupLabel(
          fr,
          platform,
          groupOn(DateTime(2026, 10, 3)),
          DateTime(2026, 10, 3, 9),
        ),
        "Aujourd'hui",
      );
      expect(
        dayGroupLabel(
          fr,
          platform,
          groupOn(DateTime(2026, 10, 2)),
          DateTime(2026, 10, 3, 9),
        ),
        'Hier',
      );
    });

    test('anything older is the platform date, through the placeholder', () {
      final String label = dayGroupLabel(
        en,
        platform,
        groupOn(DateTime(2026, 9, 28)),
        DateTime(2026, 10, 3, 9),
      );
      // ⚠️ **The date comes from the platform, and the platform's SHORT format is not
      // a sentence this app wrote.** `Thu, Oct 1` is `en_US`'s answer; asserting the
      // exact string would pin the app to one locale's idea of a date and fail on a
      // platform update. What is under test is *whose* choice it is.
      expect(label, isNot(contains('{')));
      expect(label, isNot(contains('historyDayOn')));
      expect(label, isNotEmpty);
    });

    test('the boundary is the LOCAL day, not the instant', () {
      // ⚠️ **The row this file exists for.** An entry opened at 00:30 local belongs to
      // *today*, and an instant-comparison against the current time would say it is
      // the same day as the previous group while the reader's calendar says
      // otherwise.
      final DateTime justAfterMidnight = DateTime(2026, 10, 3, 0, 30);
      expect(
        dayGroupLabel(
          en,
          platform,
          groupOn(localMidnightOf(justAfterMidnight)),
          justAfterMidnight,
        ),
        'Today',
      );
    });

    test('a 23:50 opening is YESTERDAY even though it is ten minutes old', () {
      // The gap between "ten minutes ago" and "yesterday" is a header, and getting it
      // wrong puts a ten-minute-old chapter under the wrong day's heading.
      final DateTime lateLastNight = DateTime(2026, 10, 2, 23, 50);
      expect(
        dayGroupLabel(
          en,
          platform,
          groupOn(localMidnightOf(lateLastNight)),
          DateTime(2026, 10, 3, 0, 5),
        ),
        'Yesterday',
      );
    });
  });

  group('the row time — three buckets and no fourth', () {
    final DateTime now = DateTime(2026, 10, 3, 12);

    test('under a minute is "just now", not "0 minutes ago"', () {
      expect(
        relativeTimeLabel(en, now.subtract(const Duration(seconds: 20)), now),
        'Just now',
      );
      expect(
        relativeTimeLabel(en, now.subtract(const Duration(seconds: 59)), now),
        'Just now',
      );
    });

    test('minutes carry the count, with the singular as its own form', () {
      expect(
        relativeTimeLabel(en, now.subtract(const Duration(minutes: 1)), now),
        '1 minute ago',
      );
      expect(
        relativeTimeLabel(en, now.subtract(const Duration(minutes: 7)), now),
        '7 minutes ago',
      );
      expect(
        relativeTimeLabel(fr, now.subtract(const Duration(minutes: 7)), now),
        'Il y a 7 minutes',
      );
    });

    test('hours carry the count', () {
      expect(
        relativeTimeLabel(en, now.subtract(const Duration(hours: 1)), now),
        '1 hour ago',
      );
      expect(
        relativeTimeLabel(en, now.subtract(const Duration(hours: 5)), now),
        '5 hours ago',
      );
    });

    test('past local midnight there is NO relative time at all', () {
      // ⚠️ **The absence is a decision.** The header already carries the date, and a
      // row that also said "2 days ago" would print the same fact twice on every
      // line. And a relative time keyed on `Duration` rather than the local calendar
      // would put "9 hours ago" under a header reading *Yesterday* — yesterday's row
      // quoting a number from today.
      expect(relativeTimeLabel(en, DateTime(2026, 10, 2, 3), now), '');
      expect(relativeTimeLabel(en, DateTime(2026, 10, 1, 23), now), '');
    });

    test('23 hours ago under a YESTERDAY header is not 23 hours ago', () {
      // 23:50 yesterday → 09:50 today is ten minutes, and the header says Yesterday.
      // The reverse case is the one that bites: an entry at 01:00 yesterday read at
      // 22:00 today is 21 hours old and belongs to yesterday.
      final DateTime yesterdayEarly = DateTime(2026, 10, 2, 1);
      expect(
        relativeTimeLabel(en, yesterdayEarly, DateTime(2026, 10, 2, 22)),
        '21 hours ago',
      );
      expect(
        relativeTimeLabel(en, yesterdayEarly, DateTime(2026, 10, 3, 22)),
        '',
        reason: 'the local calendar moved on; the header carries the date now',
      );
    });

    test(
      'a clock behind the last write reads as "just now", never as a negative',
      () {
        // A manual clock correction, or an NTP fix after a reboot, can put `now` before
        // `openedAt`. "opened in -4 minutes" is a sentence no reader can act on.
        expect(
          relativeTimeLabel(en, now.add(const Duration(minutes: 4)), now),
          'Just now',
        );
      },
    );

    test('nothing here leaks a Duration, an enum name or a negative sign', () {
      for (final AppLocalizations l10n in <AppLocalizations>[en, fr]) {
        for (final DateTime at in <DateTime>[
          now,
          now.subtract(const Duration(seconds: 1)),
          now.subtract(const Duration(minutes: 3)),
          now.subtract(const Duration(hours: 3)),
          now.subtract(const Duration(days: 3)),
          now.add(const Duration(days: 3)),
        ]) {
          final String label = relativeTimeLabel(l10n, at, now);
          expect(label, isNot(contains('-')));
          expect(label, isNot(contains('Duration')));
          expect(label, isNot(contains('DateTime')));
        }
      }
    });
  });

  group('the pairing, which is what the screen actually renders', () {
    test('a group header and a row time never state the same fact twice', () {
      // Today: header "Today", row "5 hours ago". Yesterday: header "Yesterday", row
      // "" — the header is the only place the date appears.
      final DateTime now = DateTime(2026, 10, 3, 17);
      final DateTime fiveHoursAgo = now.subtract(const Duration(hours: 5));

      expect(
        dayGroupLabel(
          en,
          platform,
          groupOn(localMidnightOf(fiveHoursAgo)),
          now,
        ),
        'Today',
      );
      expect(relativeTimeLabel(en, fiveHoursAgo, now), '5 hours ago');

      final DateTime lastNight = DateTime(2026, 10, 2, 23, 10);
      expect(
        dayGroupLabel(en, platform, groupOn(localMidnightOf(lastNight)), now),
        'Yesterday',
      );
      expect(relativeTimeLabel(en, lastNight, now), '');
    });
  });
}
