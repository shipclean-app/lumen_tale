// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get aboutCopyVersion => 'Copy version number';

  @override
  String get aboutDataCountUnavailable => '—';

  @override
  String get aboutDataDownloaded => 'Downloaded chapters';

  @override
  String get aboutDataE11 =>
      'Nothing here is backed up anywhere. If you uninstall Lumen Tale or lose this phone, all three numbers go to zero and no copy exists. Installing a new version over this one does not touch them — that is the only guarantee this app makes about your data.';

  @override
  String get aboutDataLabel => 'YOUR DATA ON THIS DEVICE';

  @override
  String get aboutDataLibrary => 'Library';

  @override
  String get aboutDataPositions => 'Reading positions';

  @override
  String get aboutDeliveryBody =>
      'This app runs on Android phones only. A new build is produced every time a change is merged, and you install it from the file by hand. There is no app store and no store account.';

  @override
  String get aboutGuarantee =>
      'Installing a new version keeps your library, your downloads, your reading positions and your history. Nothing is replaced or re-downloaded.';

  @override
  String get aboutPrivacyLabel => 'WHAT LEAVES THIS DEVICE';

  @override
  String get aboutPrivacyNever1 => 'Your library';

  @override
  String get aboutPrivacyNever2 => 'Your reading positions';

  @override
  String get aboutPrivacyNever3 => 'Your history';

  @override
  String get aboutPrivacyNever4 => 'Your error logs';

  @override
  String get aboutPrivacyNever5 => 'Crash reports';

  @override
  String get aboutPrivacyNever6 => 'Analytics';

  @override
  String get aboutPrivacyNever7 => 'A device identifier';

  @override
  String get aboutPrivacySent1 =>
      'A chapter\'s page — but only after you asked for it.';

  @override
  String get aboutPrivacySent2 =>
      'One request to check whether a newer version exists — only if you tap \"Check for a new version\".';

  @override
  String get aboutPrivacyVerify =>
      'Check it yourself: switch the phone to airplane mode, then open the app. Your library, your downloads and your reading positions are all there. Nothing is missing, because nothing was ever sent.';

  @override
  String get aboutProvenance =>
      'Android phone · built automatically · no store';

  @override
  String get aboutSnackCopied => 'Version number copied.';

  @override
  String aboutVersion(String buildName, String buildNumber) {
    return 'Version $buildName · build $buildNumber';
  }

  @override
  String get aboutVersionUnreadable =>
      'The installed version number could not be read.';

  @override
  String get actionFreeSpace => 'Free space';

  @override
  String get actionReportBug => 'Report the problem';

  @override
  String get appTitle => 'Lumen Tale';

  @override
  String get browseActionBrowseAnother => 'Browse another tag';

  @override
  String get browseActionOpenLibrary => 'Open library';

  @override
  String get browseActionRetry => 'Retry';

  @override
  String get browseEmpty => 'This site has nothing to show here.';

  @override
  String get browseEmptyBody => 'No source is available yet.';

  @override
  String browseEmptyTagBody(Object source) {
    return '$source publishes no novel under that tag. Try another tag.';
  }

  @override
  String browseEmptyTagTitle(Object tag) {
    return 'Nothing tagged $tag';
  }

  @override
  String get browseFailureItemRemoved => 'That novel is no longer on the site';

  @override
  String get browseFailureLayoutChanged => 'The site\'s layout changed';

  @override
  String get browseFailureNoConnection => 'No connection';

  @override
  String get browseFailureParse => 'The page could not be read';

  @override
  String get browseFailureRateLimited => 'The site asked us to slow down';

  @override
  String get browseFailureUnavailable => 'The site is unavailable';

  @override
  String get browseFailureUnknownCause =>
      'The app cannot read its own record of this failure';

  @override
  String get browseFooterEnd => 'That is everything this tag publishes';

  @override
  String get browseFooterLoadingMore => 'Loading more…';

  @override
  String browseNoConnectionBody(Object source) {
    return '$source could not be reached. Your library is unaffected.';
  }

  @override
  String get browseNoConnectionTitle => 'No connection';

  @override
  String get browseSearchHint => 'Search this site';

  @override
  String browseSiteSaidNothingBody(Object query, Object source) {
    return 'Searching $source for \"$query\" returned nothing.';
  }

  @override
  String get browseSiteSaidNothingTitle => 'The site says it has nothing';

  @override
  String get browseSourceUnavailableBody =>
      'The page loaded, but the part that lists novels was not on it. Nothing is wrong with your library, and nothing was downloaded.';

  @override
  String browseSourceUnavailableTitle(Object source) {
    return '$source could not be read';
  }

  @override
  String get browseSucceeded => 'Read successfully.';

  @override
  String get browseTileAdd => 'Add';

  @override
  String get browseTileKept => 'In your library';

  @override
  String get browseTileOpen => 'Open';

  @override
  String get browseTitle => 'Browse';

  @override
  String get causeActionBack => 'Back';

  @override
  String get causeActionBrowseOther => 'Browse another site';

  @override
  String get causeActionCopyThis => 'Copy this';

  @override
  String get causeActionOpenLibrary => 'Open library';

  @override
  String get causeActionTryAgain => 'Try again';

  @override
  String get causeContentRemovedBody =>
      'The site says so in its own words. Your saved copy is untouched.';

  @override
  String get causeContentRemovedKicker => 'REMOVED FROM THE SOURCE';

  @override
  String get causeContentRemovedNoRetry =>
      'There is nothing to try again here.';

  @override
  String causeContentRemovedTitle(Object source) {
    return 'This is no longer on $source';
  }

  @override
  String get causeEvidenceHeading => 'What happened';

  @override
  String causeLayoutChangedBody(Object retryNote, Object source) {
    return 'This is a fault in the copy this app has of $source — not in $source, and nothing is to do with how you use it. $retryNote';
  }

  @override
  String causeLayoutChangedDictation(Object source) {
    return 'Say: \"the pages of $source have changed and the app can no longer read them.\"';
  }

  @override
  String get causeLayoutChangedKicker => 'THE PAGES OF THIS SITE HAVE CHANGED';

  @override
  String get causeLayoutChangedRetryNote =>
      'Sometimes it resolves on its own. Rarely.';

  @override
  String get causeLayoutChangedTitle => 'The pages of this site have changed';

  @override
  String get causeNoConnectionBody =>
      'Nothing was lost. Your library and your downloaded chapters are exactly as they were.';

  @override
  String get causeNoConnectionKicker => 'NO CONNECTION';

  @override
  String causeNoConnectionTitle(Object host) {
    return 'No connection to $host';
  }

  @override
  String get causeSiteUnavailableBody =>
      'The site refused or is down. Nothing about your library was touched.';

  @override
  String get causeSiteUnavailableKicker => 'THE SITE IS NOT ANSWERING';

  @override
  String causeSiteUnavailableTitle(Object source) {
    return '$source is not answering';
  }

  @override
  String get causeUnreadableRecordBody =>
      'It kept a record it can no longer read, so it will not guess. The app will not invent a diagnosis.';

  @override
  String get causeUnreadableRecordKicker => 'THIS SITE COULD NOT BE READ';

  @override
  String get causeUnreadableRecordTitle => 'This app cannot say what happened';

  @override
  String chapterCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count chapters',
      one: '1 chapter',
      zero: 'No chapters',
    );
    return '$_temp0';
  }

  @override
  String chapterCountPlural(Object count) {
    return '$count other chapters';
  }

  @override
  String get chapterCountSingular => '1 other chapter';

  @override
  String get chapterListActionBack => 'Back';

  @override
  String get chapterListActionRetry => 'Try again';

  @override
  String get chapterListAddToLibrary => 'Add to library';

  @override
  String get chapterListContinue => 'Continue';

  @override
  String chapterListContinueSemantics(String chapter, int percent) {
    return 'Continue, $chapter, $percent through this chapter';
  }

  @override
  String get chapterListDownloadAction => 'Download';

  @override
  String get chapterListDownloadAll => 'Download all';

  @override
  String get chapterListEmptyAtSourceBody =>
      'The site said so itself. This is what it publishes for this novel, and it is not an error.';

  @override
  String chapterListEmptyAtSourceTitle(Object source) {
    return '$source publishes no chapters';
  }

  @override
  String chapterListHeaderAtSource(Object count, Object source) {
    return '$count chapters on $source';
  }

  @override
  String chapterListHeaderCount(Object count) {
    return '$count chapters';
  }

  @override
  String get chapterListJumpToCurrent => 'Go to the current chapter';

  @override
  String get chapterListLoadAction => 'Load the chapter list';

  @override
  String get chapterListLoadExplainer =>
      'This app has never fetched the chapters of this novel. Nothing has been stored, and nothing was lost.';

  @override
  String get chapterListMarkAllRead => 'Mark all as read';

  @override
  String chapterListMarkAllReadConfirm(int count) {
    return 'Mark the $count chapters you have not opened as read?';
  }

  @override
  String chapterListMarkedReadFailedBody(Object source) {
    return 'A chapter you have read is no longer in the list $source publishes. The app has not deleted your progress.';
  }

  @override
  String get chapterListMarkedReadFailedTitle => 'The app\'s records disagree';

  @override
  String chapterListNeverLoadedBody(Object source) {
    return 'This novel is in your library, but its chapter list has not been fetched yet. Loading it asks $source for the list and stores it on this phone.';
  }

  @override
  String get chapterListNeverLoadedTitle => 'The chapters were never loaded';

  @override
  String chapterListNoConnectionBody(Object source) {
    return 'The chapter list has never been fetched, and $source cannot be reached right now. Nothing about your library is affected.';
  }

  @override
  String get chapterListNoConnectionTitle => 'No connection';

  @override
  String get chapterListNothingUnopened => 'Nothing unopened';

  @override
  String get chapterListReadFromStart => 'Read from the start';

  @override
  String chapterListSpaceRefusedBody(Object bytes) {
    return 'This download needs about $bytes and there is not that much room. Nothing was queued.';
  }

  @override
  String get chapterListSpaceRefusedTitle => 'Not enough space';

  @override
  String chapterListStoredUnreadableBody(Object source) {
    return 'The chapter list is stored on this phone, and the app can no longer read it. Loading it again from $source would replace it, so the app has not done that.';
  }

  @override
  String get chapterListStoredUnreadableTitle =>
      'This app cannot read its own copy';

  @override
  String chapterListTailMarker(Object displayed, Object total) {
    return '$displayed of $total chapters';
  }

  @override
  String get chapterListUnreadableBody =>
      'The page loaded and the chapter list was not on it. Your library is untouched and nothing was downloaded.';

  @override
  String chapterListUnreadableTitle(Object source) {
    return '$source could not be read';
  }

  @override
  String get chapterListUntitled => 'Untitled';

  @override
  String get chapterTileDownloaded => 'Downloaded';

  @override
  String get chapterTileNotDownloaded => 'Not downloaded';

  @override
  String get chapterTileUnread => 'Unread';

  @override
  String checkActionSemantics(int done, int total) {
    return 'Checking, $done of $total novels';
  }

  @override
  String get checkCancelAction => 'Stop the check';

  @override
  String get checkCancelled => 'Check cancelled.';

  @override
  String get checkCancelledByReader =>
      'Check cancelled · your library is unchanged';

  @override
  String checkDiscovered(int total, int discovered) {
    return 'Checked $total novels · $discovered you had not opened';
  }

  @override
  String checkDiscoveredNothing(int total) {
    return 'Checked $total novels · nothing you had not opened';
  }

  @override
  String get checkFinishedAfterCancel =>
      'Check finished after you cancelled it.';

  @override
  String get checkNeedsConnection => 'Checking needs a connection.';

  @override
  String get checkNotificationChannelName => 'Library checks';

  @override
  String get checkNotificationPermissionWarning =>
      'The check will run, but Android will not show its notification: nothing will tell you when it finishes.';

  @override
  String get checkNotificationSettingsAction => 'Open notification settings';

  @override
  String get checkNotificationTitle => 'Checking your library';

  @override
  String get checkNowAction => 'Check for new chapters';

  @override
  String checkProgress(int done, int total) {
    return 'Checking $done of $total novels';
  }

  @override
  String checkProgressNothingDownloaded(int done, int total) {
    return 'Checking $done of $total novels · nothing is downloaded';
  }

  @override
  String get checkQueuedNotice =>
      'The check needs to be started again from here — the phone closed the job.';

  @override
  String get checkStoppedAppStandby =>
      'Check stopped — the phone put the app to sleep. Try again.';

  @override
  String get checkStoppedBackgroundRestriction =>
      'Check stopped — Android paused it. Tap check to finish.';

  @override
  String get checkStoppedCancelledByApp =>
      'Check cancelled · your library is unchanged';

  @override
  String get checkStoppedDeviceIdle =>
      'Check stopped — the phone put the app to sleep. Try again.';

  @override
  String get checkStoppedDeviceState =>
      'Check stopped — the phone is saving power. Try again.';

  @override
  String get checkStoppedGpuLimit =>
      'Check stopped — the phone ran out of memory for it. Try again.';

  @override
  String get checkStoppedPreempt =>
      'Check stopped — Android gave the phone to something else.';

  @override
  String get checkStoppedSystemIgnoredCancel =>
      'Check finished after you cancelled it.';

  @override
  String get checkStoppedTimeout =>
      'Check took longer than Android allows and was stopped. Try again.';

  @override
  String get checkStoppedUnknown =>
      'Check stopped — Android did not say why. Tap check to finish.';

  @override
  String checkTerminalComplete(int total) {
    return 'All $total novels checked · none skipped.';
  }

  @override
  String checkTerminalInterrupted(int done, int total) {
    return 'Check stopped at $done of $total novels.';
  }

  @override
  String checkTerminalWithFailures(int checked, int total, int failed) {
    return 'Checked $checked of $total novels · $failed could not be checked.';
  }

  @override
  String get commonBack => 'Back';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonErrorBody => 'The operation could not be completed.';

  @override
  String get commonErrorTitle => 'Something went wrong';

  @override
  String get commonOk => 'OK';

  @override
  String get commonRetry => 'Retry';

  @override
  String coverSemanticsLabel(String title) {
    return 'Cover of $title';
  }

  @override
  String deleteStoredBody(Object freedBytes, Object siblingCount) {
    return 'This chapter\'s text will be erased from this phone.\nThe $siblingCount other chapters of this novel are not touched.\n$freedBytes will be freed.';
  }

  @override
  String get deleteStoredConfirm => 'Delete';

  @override
  String get deleteStoredFailedSnackbar =>
      'Could not delete this chapter. Nothing was changed.';

  @override
  String deleteStoredTitle(Object ordinal) {
    return 'Delete chapter $ordinal?';
  }

  @override
  String get downloadAddedSnackbar => 'Download added';

  @override
  String get downloadAlreadyQueuedSnackbar =>
      'This chapter is already in the queue';

  @override
  String get downloadAlreadyStoredSnackbar =>
      'This chapter is already downloaded';

  @override
  String downloadDeletedSnackbar(Object freedBytes) {
    return 'Chapter deleted — $freedBytes freed';
  }

  @override
  String get downloadDone => 'Downloaded';

  @override
  String get downloadDownloading => 'Downloading';

  @override
  String get downloadFailed => 'Download interrupted. You can try it again.';

  @override
  String get downloadNeedsConnectionSnackbar =>
      'Downloading requires a connection.';

  @override
  String get downloadNotDownloadedLabel => 'Not downloaded';

  @override
  String get downloadNotStoredSnackbar => 'This chapter was not downloaded.';

  @override
  String get downloadQueued => 'Queued for download';

  @override
  String get downloadSpaceRefusedAction =>
      'Delete a downloaded chapter, then try again.';

  @override
  String downloadSpaceRefusedBody(Object freeBytes, Object requiredBytes) {
    return 'This download needs $requiredBytes, and this phone has $freeBytes free.';
  }

  @override
  String get downloadWriteFailedSnackbar =>
      'The download could not be added. Nothing was changed.';

  @override
  String get errorCountUnavailable => 'That count could not be computed.';

  @override
  String get errorHistoryClear => 'History could not be cleared.';

  @override
  String get errorItemRemovedAtSource =>
      'This novel is no longer on the site. The rest of your library is untouched.';

  @override
  String get errorNoConnection =>
      'No connection. Your downloaded chapters stay readable.';

  @override
  String get errorParseFailed =>
      'A file for this novel could not be read. Please report it to whoever maintains this app.';

  @override
  String get errorRateLimited =>
      'The site asked us to slow down. Try again shortly.';

  @override
  String errorRateLimitedIn(int seconds) {
    return 'The site asked us to slow down. Try again in $seconds seconds.';
  }

  @override
  String get errorSettingsLoad =>
      'Your settings could not be read from this phone. Your library, downloads and reading positions are untouched.';

  @override
  String get errorSettingsWrite =>
      'This setting could not be saved. It will keep its previous value.';

  @override
  String get errorSiteUnreadable =>
      'This site could not be read. That is not the same as a site with no chapters. Your other sources work normally.';

  @override
  String get errorSourceLayoutChanged =>
      'This site has changed its layout. The app can no longer read it.';

  @override
  String get errorSourceUnavailable =>
      'This site is not responding. Try again later.';

  @override
  String get errorStorageFull =>
      'Storage is full. Free some space, then try again.';

  @override
  String get historyAgedOutBody => 'Your reading positions were kept.';

  @override
  String get historyAgedOutTitle =>
      'Everything older than one year was dropped';

  @override
  String get historyClearAction => 'Clear history';

  @override
  String historyClearDialogBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count entries will be removed.',
      one: 'One entry will be removed.',
      zero: 'No entries will be removed.',
    );
    return '$_temp0 Your library, your downloads and every remembered reading position will be kept.';
  }

  @override
  String get historyClearDialogConfirm => 'Clear history';

  @override
  String get historyClearDialogTitle => 'Clear history?';

  @override
  String get historyClearedBody =>
      'Your library, your downloads and every remembered position were kept.';

  @override
  String get historyClearedTitle => 'History cleared';

  @override
  String historyDayOn(String date) {
    return '$date';
  }

  @override
  String get historyDayToday => 'Today';

  @override
  String get historyDayYesterday => 'Yesterday';

  @override
  String get historyEmptyActionBrowse => 'Browse a source';

  @override
  String get historyEmptyActionLibrary => 'Open your library';

  @override
  String get historyEmptyBody =>
      'The chapters you open appear here, newest first.';

  @override
  String get historyEmptyTitle => 'Nothing read yet';

  @override
  String historyHoursAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count hours ago',
      one: '1 hour ago',
    );
    return '$_temp0';
  }

  @override
  String get historyJustNow => 'Just now';

  @override
  String get historyLoadErrorBody =>
      'Your library, your downloaded chapters and every remembered reading position are unaffected.';

  @override
  String get historyLoadErrorTitle => 'Your history could not be read';

  @override
  String get historyLoadingTitle => 'Loading history';

  @override
  String historyMinutesAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count minutes ago',
      one: '1 minute ago',
    );
    return '$_temp0';
  }

  @override
  String get historyNoticeBody =>
      'Clearing it never moves a remembered reading position.';

  @override
  String get historyNoticeTitle => 'History is bounded by time';

  @override
  String get historyRetentionChange => 'Change';

  @override
  String get historyRetentionLabel => 'Keep history for';

  @override
  String get historySheetTitle => 'Keep history for';

  @override
  String historySheetWarning(String window) {
    return 'Entries older than $window will be dropped, oldest first. Your reading positions are never affected.';
  }

  @override
  String get historySheetWarningNone =>
      'No entries will be dropped. Your reading positions are never affected.';

  @override
  String get historySnackCleared =>
      'History cleared. Your reading positions were kept.';

  @override
  String get historySnackNotCleared => 'History was not cleared.';

  @override
  String historySnackWindowChanged(String window) {
    return 'History is now kept for $window.';
  }

  @override
  String historyTerminalLine(String window) {
    return 'This is the oldest entry kept. Entries older than $window are dropped, oldest first.';
  }

  @override
  String get historyTitle => 'History';

  @override
  String get historyUntitledChapter => 'Untitled';

  @override
  String get historyUntitledNovel => 'Untitled';

  @override
  String get historyWindowOneMonth => 'one month';

  @override
  String get historyWindowOneWeek => 'one week';

  @override
  String get historyWindowOneYear => 'one year';

  @override
  String get historyWindowThreeMonths => 'three months';

  @override
  String get historyWindowTwoYears => 'two years';

  @override
  String get libraryActionCancel => 'Cancel';

  @override
  String get libraryAddFailed =>
      'The novel could not be added. It is still listed in Browse.';

  @override
  String get libraryAddFailedRetry => 'Retry';

  @override
  String get libraryContinueOverline => 'CONTINUE READING';

  @override
  String get libraryEmptyBody => 'Add a novel from Browse to start reading.';

  @override
  String get libraryEmptyBrowseAction => 'Browse a source';

  @override
  String get libraryEmptyTitle => 'Your library is empty';

  @override
  String get libraryFacetDownloaded => 'Downloaded';

  @override
  String get libraryFacetGroup => 'Show';

  @override
  String get libraryFacetHasUnopened => 'Has unopened chapters';

  @override
  String get libraryFacetNotDownloaded => 'Not downloaded';

  @override
  String get libraryFacetSite => 'Site';

  @override
  String libraryFilterCount(int count) {
    return '$count filters on';
  }

  @override
  String get libraryLoadErrorBody =>
      'Chapters already downloaded are still on this phone and still readable.';

  @override
  String get libraryLoadErrorTitle => 'Your library could not be read';

  @override
  String get libraryNoDataClearFilters => 'Clear filters';

  @override
  String get libraryNoDataTitle => 'No kept novel matches the filters';

  @override
  String get libraryRemoveAction => 'Remove';

  @override
  String libraryRemoveBody(num count, Object title) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count downloaded chapters',
      one: '1 downloaded chapter',
      zero: 'no downloaded chapters',
    );
    return '$title leaves your library. Its $_temp0 and your reading history stay on this phone.';
  }

  @override
  String get libraryRemoveKept =>
      'Nothing was deleted. The chapters are still here.';

  @override
  String get libraryRemoveTitle => 'Remove from library?';

  @override
  String get libraryRemoveUndo => 'Undo';

  @override
  String libraryRemoved(Object title) {
    return '$title was removed';
  }

  @override
  String get libraryRowCouldNotCheck => 'Could not check';

  @override
  String get libraryRowDownloadComplete => 'All chapters downloaded';

  @override
  String get libraryRowNeverChecked => 'Never checked';

  @override
  String get libraryRowStopped => 'Stopped';

  @override
  String get libraryRowStoppedConnection => 'Stopped · no connection';

  @override
  String get libraryRowStoppedStorage => 'Stopped · storage full';

  @override
  String get libraryScopeLine =>
      'Titles only — the app does not keep authors, genres or descriptions as searchable fields.';

  @override
  String get librarySearchClearAction => 'Clear search';

  @override
  String get librarySearchHint => 'Search by title';

  @override
  String librarySearchNoMatchTitle(String query) {
    return 'No kept novel matches \"$query\"';
  }

  @override
  String librarySearchResults(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count novels',
      one: '1 novel',
      zero: 'No novel',
    );
    return '$_temp0';
  }

  @override
  String get librarySearchSemantics => 'Search your library by title';

  @override
  String get librarySimilarAddAnyway => 'Add anyway';

  @override
  String librarySimilarBody(
    Object existing,
    Object incoming,
    Object incomingSource,
    Object source,
  ) {
    return '\"$existing\" on $source has the same title as \"$incoming\" on $incomingSource.';
  }

  @override
  String get librarySimilarExplain =>
      'Nothing will be merged — they stay two separate novels.';

  @override
  String get librarySimilarOpenExisting => 'Open the existing one';

  @override
  String get librarySimilarTitle =>
      'A novel with this title is already in your library';

  @override
  String get librarySortLastRead => 'Last read';

  @override
  String get librarySortRecentlyAdded => 'Recently added';

  @override
  String get librarySortSite => 'Site';

  @override
  String get librarySortTitle => 'Sort and filter';

  @override
  String get librarySortTitleAz => 'Title A–Z';

  @override
  String get librarySortUnopened => 'Unopened chapters';

  @override
  String get libraryTileAuthorMissing => 'Author unknown';

  @override
  String libraryTileProgress(Object downloaded, Object total) {
    return '$downloaded of $total downloaded';
  }

  @override
  String get libraryTileUndownloaded => 'Not downloaded yet';

  @override
  String libraryTileUnopened(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count new chapters',
      one: '1 new chapter',
      zero: 'No new chapters',
    );
    return '$_temp0';
  }

  @override
  String get libraryTitle => 'Library';

  @override
  String libraryUnopenedBadgeSemantics(int count) {
    return '$count chapters you have not opened';
  }

  @override
  String get navBrowse => 'Browse';

  @override
  String get navDownloads => 'Downloads';

  @override
  String get navHistory => 'History';

  @override
  String get navLibrary => 'Library';

  @override
  String get navMore => 'More';

  @override
  String get navSettings => 'Settings';

  @override
  String get navUpdates => 'Updates';

  @override
  String get novelDetailsTitle => 'Novel';

  @override
  String get onboardingButtonNext => 'Next';

  @override
  String get onboardingButtonSkip => 'Skip';

  @override
  String get onboardingButtonStart => 'Start reading';

  @override
  String get onboardingStep1Body =>
      'Keep a novel here once and it opens with the connection switched off — on a train, on a plane, with no data used. Nothing is uploaded: there is no account, no server, and nothing is sent anywhere.';

  @override
  String get onboardingStep1Headline => 'It reads with no signal.';

  @override
  String get onboardingStep1Kicker => 'LUMEN TALE';

  @override
  String get onboardingStep2Headline => 'There is no backup.';

  @override
  String get onboardingStep2Kicker => 'BEFORE YOU START';

  @override
  String onboardingStepPosition(int current, int total) {
    return 'Step $current of $total';
  }

  @override
  String get readerActionBack => 'Back';

  @override
  String get readerActionDownloadAgain => 'Download again';

  @override
  String get readerActionDownloadChapter => 'Download this chapter';

  @override
  String get readerActionOpenDownloads => 'Open downloads';

  @override
  String get readerActionRetry => 'Retry';

  @override
  String readerChapterNumber(String number) {
    return 'Chapter $number';
  }

  @override
  String get readerChapterNumberUnreadable => 'Chapter';

  @override
  String get readerDownloadNeedsConnection => 'Downloading needs a connection';

  @override
  String get readerFileCorruptNotMarkdown =>
      'This chapter\'s saved copy is not readable';

  @override
  String get readerFileCorruptTruncated =>
      'This chapter\'s saved copy ends mid-sentence';

  @override
  String get readerFileCorruptUnreadableIo =>
      'This chapter\'s file could not be opened';

  @override
  String get readerFileEmptyBody =>
      'Nothing was saved, so there is nothing to read.';

  @override
  String get readerFileEmptyTitle =>
      'This chapter\'s recording was interrupted';

  @override
  String get readerFileMissingBody =>
      'The download succeeded. The file is what is missing.';

  @override
  String get readerFileMissingTitle =>
      'This chapter had been downloaded, but its text is no longer on this phone';

  @override
  String get readerLoadFailedBody =>
      'The app does not know whether the file is intact.';

  @override
  String get readerLoadFailedTitle => 'This chapter could not be opened';

  @override
  String get readerNotStoredBody =>
      'Only chapters already on this phone can be read here.';

  @override
  String get readerNotStoredTitle => 'This chapter is not downloaded';

  @override
  String get readerOfflineAbsentBody =>
      'Both are needed: the chapter has to be downloaded once, and downloading needs a connection.';

  @override
  String get readerOfflineAbsentTitle =>
      'This chapter is not downloaded and there is no connection';

  @override
  String get readerOfflineBanner => 'You are reading your downloads';

  @override
  String get readerRowGoneBody =>
      'The link may have been saved before the chapter was removed.';

  @override
  String get readerRowGoneTitle =>
      'This chapter no longer exists in your library';

  @override
  String readerSizeButtonTooltip(String name) {
    return 'Text size: $name';
  }

  @override
  String readerSizePixelsSpoken(String px) {
    return '$px pixels';
  }

  @override
  String get readerSizeSheetTitle => 'Text size';

  @override
  String get readerSizeStepNotSelected => 'not selected';

  @override
  String readerSizeStepPoints(String px) {
    return '${px}pt';
  }

  @override
  String get readerSizeStepSelected => 'selected';

  @override
  String readerSizeStepSemantics(String name, String pixels, String state) {
    return '$name, $pixels, $state';
  }

  @override
  String readerThemeButtonTooltip(String name) {
    return 'Theme: $name';
  }

  @override
  String get settingsButtonCancel => 'Cancel';

  @override
  String get settingsButtonRetry => 'Try again';

  @override
  String get settingsDeferredFilters =>
      'No colour filters — sepia, greyscale, inverted.';

  @override
  String get settingsDeferredFonts =>
      'No font picker — the reader uses a serif, decided once. A reading face you can choose is a v2 candidate, not a v1 control.';

  @override
  String get settingsDeferredJustification =>
      'No text justification. Justified prose at this measure creates rivers, and rivers are worse than a ragged edge.';

  @override
  String get settingsDeferredLineHeight =>
      'No line-height control. It is held at 1.72 at every size on purpose, so the rhythm does not change when the size does.';

  @override
  String get settingsDeferredModes =>
      'No reading modes — reading is one continuous scroll.';

  @override
  String get settingsDeferredOrientation => 'No orientation or rotation lock.';

  @override
  String get settingsDeferredParagraphSpacing =>
      'No paragraph spacing control — the 1.72 line-height already sets the rhythm.';

  @override
  String get settingsDeferredSwipe => 'No swipe or tap page-turn.';

  @override
  String get settingsDialogClearHistoryBody =>
      'Reading positions are not part of this list and will not be touched.';

  @override
  String get settingsDialogClearHistoryConfirm => 'Clear';

  @override
  String settingsDialogClearHistoryTitle(String count) {
    return 'Clear $count entries?';
  }

  @override
  String get settingsDisclosureAboutLink => 'What survives an update';

  @override
  String get settingsDisclosureE11 =>
      'Nothing here is backed up. If you uninstall Lumen Tale or lose this phone, your library, your downloads and your reading positions are gone, and no copy exists anywhere.';

  @override
  String get settingsDisclosureE11Footer =>
      'The app cannot warn you at the moment you uninstall — the phone does that, outside the app. So it is said here, before, rather than after.';

  @override
  String get settingsErrorCountUnavailable => 'Count unavailable';

  @override
  String get settingsErrorWrite =>
      'This setting could not be saved. Nothing was changed.';

  @override
  String get settingsGroupApp => 'APP';

  @override
  String get settingsGroupDeferred => 'NOT IN THIS VERSION';

  @override
  String get settingsGroupHistory => 'HISTORY';

  @override
  String get settingsGroupReading => 'READING';

  @override
  String get settingsGroupSize => 'TEXT SIZE';

  @override
  String get settingsGroupTheme => 'THEME';

  @override
  String get settingsLanguageEnglish => 'English';

  @override
  String get settingsLanguageFrench => 'Français';

  @override
  String get settingsRowAboutLabel => 'About Lumen Tale';

  @override
  String settingsRowAboutValue(String buildName, String buildNumber) {
    return 'Version $buildName · build $buildNumber';
  }

  @override
  String get settingsRowAppearanceLabel => 'Reader appearance';

  @override
  String settingsRowAppearanceValue(String theme, String size, String pt) {
    return '$theme · $size ($pt pt)';
  }

  @override
  String get settingsRowClearHistoryLabel => 'Clear reading history';

  @override
  String get settingsRowHistoryLabel => 'Reading history';

  @override
  String settingsRowHistoryValue(String count, String relative) {
    return '$count entries · oldest $relative';
  }

  @override
  String get settingsRowHistoryValueEmpty => '0 entries';

  @override
  String get settingsRowLanguageHint =>
      'Follows your phone. Change it in Android\'s language settings.';

  @override
  String get settingsRowLanguageLabel => 'Language';

  @override
  String get settingsRowOnboardingLabel => 'How this app works';

  @override
  String get settingsRowOnboardingValue =>
      'Show the two introduction screens again';

  @override
  String get settingsRowRetentionLabel => 'Keep history for';

  @override
  String get settingsSizeLg => 'Large';

  @override
  String get settingsSizeMd => 'Medium';

  @override
  String get settingsSizeSm => 'Small';

  @override
  String get settingsSizeXl => 'Larger';

  @override
  String get settingsSizeXxl => 'Largest';

  @override
  String get settingsSnackHistoryCleared =>
      'Reading history cleared. Your reading positions were kept.';

  @override
  String settingsSpecimenCredit(String novel, String chapter) {
    return 'From \"$novel\" · $chapter';
  }

  @override
  String get settingsSpecimenEmptyNote =>
      'You have not downloaded anything yet — this is what the reader will look like.';

  @override
  String get settingsSpecimenSeedFailed =>
      'A chapter saved on this phone could not be read. Showing a sample instead.';

  @override
  String get settingsThemeDay => 'Day';

  @override
  String get settingsThemeNight => 'Night';

  @override
  String get settingsThemeSystem => 'Follow the phone';

  @override
  String get settingsTitle => 'Settings';

  @override
  String sourceUnavailableRetryIn(Object seconds) {
    return 'Try again in ${seconds}s';
  }

  @override
  String sourceUnavailableStillWorksBody(
    Object downloaded,
    Object library,
    Object source,
  ) {
    return 'Your $library novels and $downloaded downloaded chapters are on this phone and are readable now, with or without $source.';
  }

  @override
  String get sourceUnavailableStillWorksEmpty =>
      'Nothing is stored yet — and nothing was lost by this failure.';

  @override
  String get sourceUnavailableStillWorksHeading => 'What still works';

  @override
  String sourceUnavailableWaitingForSite(Object seconds) {
    return 'The site asked us to wait ${seconds}s.';
  }

  @override
  String unitBytes(Object count) {
    return '$count B';
  }

  @override
  String unitGigabytes(Object count) {
    return '$count GB';
  }

  @override
  String unitKilobytes(Object count) {
    return '$count KB';
  }

  @override
  String unitMegabytes(Object count) {
    return '$count MB';
  }

  @override
  String get warningNotifications =>
      'Notifications are turned off in your phone\'s settings.';

  @override
  String downloadsAttemptCount(Object count) {
    return 'Tried $count times';
  }

  @override
  String get downloadsCancelAction => 'Cancel download';

  @override
  String get downloadsCancelFailedSnackbar =>
      'Could not cancel. The download is still running.';

  @override
  String downloadsCancelledKept(Object kept) {
    return 'Download cancelled — $kept chapters kept.';
  }

  @override
  String get downloadsEmptyActionBrowse => 'Browse sources';

  @override
  String get downloadsEmptyBody =>
      'Downloaded chapters read with no signal at all. Start one from any novel\'s page.';

  @override
  String get downloadsEmptyTitle => 'Nothing is downloaded yet';

  @override
  String downloadsFailedRowTitle(Object name) {
    return 'Chapter: $name';
  }

  @override
  String get downloadsFailedSectionLabel => 'COULD NOT DOWNLOAD';

  @override
  String downloadsHeaderCounts(Object downloaded, Object total) {
    return '$downloaded of $total downloaded';
  }

  @override
  String get downloadsInProcessNotice =>
      'Downloads continue only while the app is open.';

  @override
  String downloadsInProgressSuffix(Object count) {
    return '· $count in progress';
  }

  @override
  String get downloadsLoadErrorBody =>
      'Nothing has been deleted. This app cannot see what it has already stored, and nothing can be fetched until it can.';

  @override
  String get downloadsLoadErrorRetry => 'Try again';

  @override
  String get downloadsLoadErrorTitle =>
      'Lumen Tale could not read its download records';

  @override
  String get downloadsPauseAction => 'Pause';

  @override
  String get downloadsPausedLabel => 'Paused';

  @override
  String get downloadsQueueSectionLabel => 'DOWNLOAD QUEUE';

  @override
  String get downloadsResumeAction => 'Resume';

  @override
  String get downloadsRetryAction => 'Retry this chapter';

  @override
  String get downloadsRunningLabel => 'Downloading';

  @override
  String downloadsSemanticsChapterProgress(
    Object percent,
    Object position,
    Object total,
  ) {
    return 'Chapter $position of $total, $percent per cent';
  }

  @override
  String downloadsSemanticsProgressUndetermined(Object position, Object total) {
    return 'Chapter $position of $total, downloading';
  }

  @override
  String get downloadsStoppedLabel => 'Stopped';

  @override
  String get downloadsStoppedNoConnection => 'No connection';

  @override
  String get downloadsStoppedOutOfStorage =>
      'The phone is out of storage. Free up some space, then resume.';

  @override
  String downloadsStoppedRateLimited(Object time) {
    return 'The site asked us to wait until $time.';
  }

  @override
  String downloadsStoppedSourceUnreadable(Object source) {
    return 'Lumen Tale could not read $source.';
  }

  @override
  String downloadsStorageNeeded(Object bytes) {
    return 'This chapter needs $bytes.';
  }

  @override
  String get downloadsTitle => 'Downloads';

  @override
  String get downloadsWillNotContinueOnItsOwn =>
      'It will not continue on its own when the signal comes back.';

  @override
  String queueCancelBody(Object kept) {
    return 'The $kept chapters already downloaded are kept. Nothing else is fetched.';
  }

  @override
  String queueCancelBodyWithChapter(Object kept, Object name) {
    return '\'$name\' is being downloaded. It will be discarded. The $kept chapters already downloaded are kept.';
  }

  @override
  String get queueCancelConfirm => 'Cancel the download';

  @override
  String get queueCancelTitle => 'Cancel this download?';

  @override
  String get queueCauseItemRemovedAtSource =>
      'The site says this chapter has been removed.';

  @override
  String get queueCauseNoConnection =>
      'The connection dropped while this chapter was being downloaded.';

  @override
  String get queueCauseNoRealText =>
      'This chapter had no readable text on the page.';

  @override
  String get queueCauseParseFailed =>
      'This chapter\'s text could not be built.';

  @override
  String get queueCauseRateLimited => 'The site asked us to slow down.';

  @override
  String get queueCauseSourceEmpty =>
      'The site published nothing for this chapter.';

  @override
  String get queueCauseSourceLayoutChanged =>
      'This site has changed its layout, so this app can no longer read it.';

  @override
  String get queueCauseSourceUnavailable =>
      'This novel\'s site is not in this version of the app.';

  @override
  String get queueCauseStorageFull => 'The phone ran out of storage.';

  @override
  String get queueCauseUnknown => 'This app cannot say what went wrong.';

  @override
  String get downloadsOpenNovelAction => 'Open the novel';
}
