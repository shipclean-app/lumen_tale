// Lumen Tale — the About screen's providers: three local counts and nothing else.
//
// ## No network provider exists in this file, and that is the point
//
// `settings-about.md` § 4bis removed the version check from v1: B29 — no user data
// leaves the device — is satisfied while the app sends nothing, and a provider that
// could be made to send something is a place to be careless. There is no
// `versionCheckProvider` here to be wired up later by accident; adding one is a
// decision with a slice behind it.
//
// ## Three separate queries, deliberately
//
// A single `SELECT` with three sub-selects is cheaper and makes the three figures one
// answer: one slow query would put all three in `loading`, and one failure would blank
// all three. The design says *"one local query per figure"*, and the real reason is the
// failure shape — a reader who cannot see their position count must still see their
// library count.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:lumen_tale/data/library/local_counts.dart';
import 'package:lumen_tale/features/about/about_screen.dart';
import 'package:lumen_tale/features/history/history_providers.dart';

/// How many novels are in the library.
final aboutLibraryCountProvider = FutureProvider<int>(
  (Ref ref) => countLibraryNovels(ref.watch(appDatabaseProvider)),
);

/// How many chapters are downloaded.
///
/// ⚠️ **The `chapters` table, and NOT a `downloaded` column.** The column does not exist
/// yet — `8-1`'s slice owns it — and this screen must not invent one. A reader told
/// "Downloaded chapters 0" when three chapters are on disk has been told a falsehood by
/// a count, which is the failure the whole block exists to prevent.
final aboutDownloadedCountProvider = FutureProvider<int>(
  (Ref ref) => countKnownChapters(ref.watch(appDatabaseProvider)),
);

/// How many reading positions exist — **B31's third figure, and the one that matters
/// most**, because it is the only one a reader cannot recreate: a library can be
/// re-added and a chapter re-downloaded, and a scroll offset cannot.
final aboutPositionsCountProvider = FutureProvider<int>(
  (Ref ref) => countReadingPositions(ref.watch(appDatabaseProvider)),
);

/// The three, assembled — but **not watched as one**, so a failure in one stays local to
/// its own row.
final aboutCountsProvider = Provider<AboutCounts>(
  (Ref ref) => AboutCounts(
    library: ref.watch(aboutLibraryCountProvider),
    downloaded: ref.watch(aboutDownloadedCountProvider),
    positions: ref.watch(aboutPositionsCountProvider),
  ),
);
