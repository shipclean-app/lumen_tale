// Lumen Tale — the ONE place a failure becomes a sentence.
//
// `13-error-handling.md` rule 5: *"one place maps exceptions → localized messages,
// in `core/ui/`"*, and rule 3: *"never propagate stacktraces or `e.toString()` to
// the UI"*. Both rules are structural, and this file is what makes them hold.
//
// ## Why an enum and not a `String` key
//
// A widget that writes `errorRateLimited` as a literal key has done half the job and
// can get the other half wrong: it can offer **Retry** where nothing is retriable. The
// enum is the *shape of the failure*, and both the sentence and the action come from
// it — so a screen cannot invent either.
//
// ## `SourceFailure` is mapped here too, and it is not the same thing as
// `AppException`
//
// - a **read** returns `BrowseFailed(reason)`, carrying a `SourceFailure`. Nothing
//   throws it. It is the seven causes of `architecture.md` § 5.2.
// - a **write** throws an `AppException`. `13-error-handling.md` says to keep that
//   hierarchy small, and each subclass exists because a caller catches it specifically.
//
// Both end up on screen, so both are mapped here — from two clearly separate types,
// never from one after the other. See `app_exception.dart` for why the two must not
// be merged.

import 'package:lumen_tale/core/error/app_exception.dart';
import 'package:lumen_tale/core/error/source_failure.dart';
import 'package:lumen_tale/l10n/generated/app_localizations.dart';

/// The shapes a failure can take on screen.
///
/// **Exhaustive by construction**: the enum is closed and both mapping functions below
/// are total, so adding a cause without adding a sentence is a compile error rather
/// than a screen that says nothing.
enum AppErrorString {
  // ── the seven causes of `architecture.md` § 5.2, in its order ────────────
  noConnection,
  rateLimited,
  sourceLayoutChanged,
  sourceUnavailable,
  itemRemovedAtSource,
  storageFull,
  parseFailed,

  // ── the other `AppException` subclasses ──────────────────────────────────
  databaseUnavailable,
  chapterNotAvailable,
  settingsWriteFailed,

  // ── B22's three states, which are results and not exceptions ─────────────
  browseEmpty,
  browseFailed,
  browseSucceeded,

  // ── the four `DownloadState` values ──────────────────────────────────────
  downloadQueued,
  downloadDownloading,
  downloadDone,
  downloadFailed,

  // ── results with no site behind them ─────────────────────────────────────
  checkCancelled,
  historyClearFailed,
  historyCountUnavailable,
  notificationPermissionDenied,
  settingsLoadFailed,
}

/// Failure → sentence, failure → what the reader can do.
///
/// One extension on `AppLocalizations`, so **the locale follows the phone** (E12) and
/// no caller can hold a sentence in one language while the app is in another.
extension AppErrorCopy on AppLocalizations {
  /// The sentence. **Never** a class name, never a code, never `toString()`
  /// (rule 3).
  ///
  /// [retryAfter] is honoured only for [AppErrorString.rateLimited], and it comes
  /// from the site's `Retry-After` header — C7 and `17-security.md` rule 6 say the
  /// duration is **read, never guessed**.
  String message(AppErrorString which, {Duration? retryAfter}) {
    return switch (which) {
      AppErrorString.noConnection => errorNoConnection,
      AppErrorString.rateLimited =>
        retryAfter == null
            ? errorRateLimited
            : errorRateLimitedIn(retryAfter.inSeconds),
      AppErrorString.sourceLayoutChanged => errorSourceLayoutChanged,
      AppErrorString.sourceUnavailable => errorSourceUnavailable,
      AppErrorString.itemRemovedAtSource => errorItemRemovedAtSource,
      AppErrorString.storageFull => errorStorageFull,
      AppErrorString.parseFailed => errorParseFailed,
      AppErrorString.databaseUnavailable => errorSiteUnreadable,
      AppErrorString.chapterNotAvailable => errorSiteUnreadable,
      AppErrorString.settingsWriteFailed => errorSettingsWrite,
      AppErrorString.browseEmpty => browseEmpty,
      AppErrorString.browseFailed => errorSiteUnreadable,
      AppErrorString.browseSucceeded => browseSucceeded,
      AppErrorString.downloadQueued => downloadQueued,
      AppErrorString.downloadDownloading => downloadDownloading,
      AppErrorString.downloadDone => downloadDone,
      AppErrorString.downloadFailed => downloadFailed,
      AppErrorString.checkCancelled => checkCancelled,
      AppErrorString.historyClearFailed => errorHistoryClear,
      AppErrorString.historyCountUnavailable => errorCountUnavailable,
      AppErrorString.notificationPermissionDenied => warningNotifications,
      AppErrorString.settingsLoadFailed => errorSettingsLoad,
    };
  }

  /// What the reader can do about it. `null` means **there is nothing**, and that is
  /// the correct answer more often than it is comfortable.
  ///
  /// This is `architecture.md` § 5.2's "Recoverable by retry" column, rendered
  /// executable — and C12's requirement that a failure state be *actionable*, not
  /// merely present. A `null` here is a deliberate blank where a `Retry` button would
  /// be a lie: no retry repairs a changed layout or a failed conversion.
  String? recovery(AppErrorString which) {
    return switch (which) {
      // Later, on its own. E5.
      AppErrorString.noConnection => commonRetry,
      // Wait — B37 and `17-security.md` rule 6: the *header* says when. Offering a
      // button that retries early is how a rate limit gets worse.
      AppErrorString.rateLimited => null,
      // Nothing. Report the bug.
      AppErrorString.sourceLayoutChanged => actionReportBug,
      // Back off.
      AppErrorString.sourceUnavailable => commonRetry,
      // Go back; the rest is unaffected — and the sentence says so.
      AppErrorString.itemRemovedAtSource => commonBack,
      // Free space, then resume.
      AppErrorString.storageFull => actionFreeSpace,
      // Report. A retry cannot repair a bad conversion.
      AppErrorString.parseFailed => actionReportBug,
      AppErrorString.databaseUnavailable => commonRetry,
      AppErrorString.chapterNotAvailable => commonBack,
      // B24's pattern: the control snapped back, so the sentence explains it.
      AppErrorString.settingsWriteFailed => commonRetry,
      // Nothing — "empty" is an answer, not a failure.
      AppErrorString.browseEmpty => null,
      AppErrorString.browseFailed => commonRetry,
      AppErrorString.browseSucceeded => null,
      AppErrorString.downloadQueued => commonCancel,
      AppErrorString.downloadDownloading => commonCancel,
      AppErrorString.downloadDone => null,
      // Nothing was written, so nothing is lost and starting again is free.
      AppErrorString.downloadFailed => commonRetry,
      // Rule 7: cancelled is not failed, so there is nothing to say and nothing to do.
      AppErrorString.checkCancelled => null,
      AppErrorString.historyClearFailed => commonRetry,
      // A count that cannot be computed cannot be retried into existence; the honest
      // action is none, and the sentence says it is uncertain.
      AppErrorString.historyCountUnavailable => null,
      // The decision is in the phone's settings, not in this app.
      AppErrorString.notificationPermissionDenied => null,
      // A bootstrap failure. Retrying the screen would not reload the store.
      AppErrorString.settingsLoadFailed => null,
    };
  }

  /// An `AppException` → its shape. Total, because the hierarchy is `sealed`.
  ///
  /// ⚠️ `CancelledException` maps to [AppErrorString.checkCancelled] rather than to a
  /// failure, because rule 7 says the caller distinguishes the two — and a screen that
  /// shows an error for a cancellation teaches the reader that their own tap broke
  /// something.
  AppErrorString forAppException(AppException error) {
    return switch (error) {
      NetworkException() => AppErrorString.noConnection,
      SourceException() => AppErrorString.sourceUnavailable,
      DatabaseException() => AppErrorString.databaseUnavailable,
      ChapterNotAvailableException() => AppErrorString.chapterNotAvailable,
      CancelledException() => AppErrorString.checkCancelled,
    };
  }

  /// A `SourceFailure` → its shape.
  ///
  /// ⚠️ **Six arms, not seven.** `architecture.md` § 5.2's table has seven rows, and
  /// `StorageFull` is the seventh — but it is **not a source read**, so it cannot be a
  /// `SourceFailure`, and `failure-discriminator` did not create one. A storage
  /// failure reaches this mapper through a **write**: a `DatabaseException`, or a
  /// download that ran out of room. Inventing a `StorageFull extends SourceFailure`
  /// here would put "the phone is full" in a taxonomy whose whole subject is *a site
  /// that could not be read*, and every reader of § 5.2 would then believe the row
  /// and the hierarchy agree. They do not, and the difference is the useful part.
  ///
  /// The other six are the site causes and are exhaustive: the hierarchy is sealed, so
  /// adding a seventh arm here is forced by a compile error rather than forgotten.
  AppErrorString forSourceFailure(SourceFailure failure) {
    return switch (failure) {
      NoConnection() => AppErrorString.noConnection,
      RateLimited() => AppErrorString.rateLimited,
      SourceLayoutChanged() => AppErrorString.sourceLayoutChanged,
      SourceUnavailable() => AppErrorString.sourceUnavailable,
      ItemRemovedAtSource() => AppErrorString.itemRemovedAtSource,
      ParseFailed() => AppErrorString.parseFailed,
    };
  }

  /// A `DatabaseException` → its shape, refined by what the caller knows.
  ///
  /// The default is [AppErrorString.databaseUnavailable]. A caller that knows the
  /// failure was **running out of room** must say so with
  /// [AppErrorString.storageFull], because that is the one whose sentence contains an
  /// action that works — C8.
  AppErrorString forDatabaseException(DatabaseException error) {
    return AppErrorString.databaseUnavailable;
  }
}
