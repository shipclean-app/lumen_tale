// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Lumen Tale';

  @override
  String get navLibrary => 'Library';

  @override
  String get navBrowse => 'Browse';

  @override
  String get navUpdates => 'Updates';

  @override
  String get navHistory => 'History';

  @override
  String get navMore => 'More';

  @override
  String get navDownloads => 'Downloads';

  @override
  String get navSettings => 'Settings';

  @override
  String get commonRetry => 'Retry';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonBack => 'Back';

  @override
  String get commonErrorTitle => 'Something went wrong';

  @override
  String get commonErrorBody => 'The operation could not be completed.';

  @override
  String get libraryEmptyTitle => 'Your library is empty';

  @override
  String get libraryEmptyBody => 'Add a novel from Browse to start reading.';

  @override
  String get browseEmptyBody => 'No source is available yet.';

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
  String coverSemanticsLabel(String title) {
    return 'Cover of $title';
  }

  @override
  String get errorNoConnection =>
      'No connection. Your downloaded chapters stay readable.';

  @override
  String get errorRateLimited =>
      'The site asked us to slow down. Try again shortly.';

  @override
  String errorRateLimitedIn(int seconds) {
    return 'The site asked us to slow down. Try again in $seconds seconds.';
  }

  @override
  String get errorSourceLayoutChanged =>
      'This site has changed its layout. The app can no longer read it.';

  @override
  String get errorSourceUnavailable =>
      'This site is not responding. Try again later.';

  @override
  String get errorItemRemovedAtSource =>
      'This novel is no longer on the site. The rest of your library is untouched.';

  @override
  String get errorStorageFull =>
      'Storage is full. Free some space, then try again.';

  @override
  String get errorParseFailed =>
      'A file for this novel could not be read. Please report it to whoever maintains this app.';

  @override
  String get errorSiteUnreadable =>
      'This site could not be read. Your other sources work normally.';

  @override
  String get errorSettingsLoad => 'Your settings could not be loaded.';

  @override
  String get errorSettingsWrite =>
      'This setting could not be saved. It will keep its previous value.';

  @override
  String get errorHistoryClear => 'History could not be cleared.';

  @override
  String get errorCountUnavailable => 'That count could not be computed.';

  @override
  String get warningNotifications =>
      'Notifications are turned off in your phone\'s settings.';

  @override
  String get checkCancelled => 'Check cancelled.';

  @override
  String get browseEmpty => 'This site has nothing to show here.';

  @override
  String get browseSucceeded => 'Read successfully.';

  @override
  String get downloadQueued => 'Queued for download';

  @override
  String get downloadDownloading => 'Downloading';

  @override
  String get downloadDone => 'Downloaded';

  @override
  String get downloadFailed => 'Download interrupted. You can try it again.';

  @override
  String get actionFreeSpace => 'Free space';

  @override
  String get actionReportBug => 'Report the problem';

  @override
  String get historyTitle => 'History';

  @override
  String get historyUntitledChapter => 'Untitled';

  @override
  String get historyUntitledNovel => 'Untitled';

  @override
  String get historyLoadingTitle => 'Loading history';

  @override
  String get historyEmptyTitle => 'Nothing read yet';

  @override
  String get historyEmptyBody =>
      'The chapters you open appear here, newest first.';

  @override
  String get historyEmptyActionBrowse => 'Browse a source';

  @override
  String get historyEmptyActionLibrary => 'Open your library';

  @override
  String get historyClearedTitle => 'History cleared';

  @override
  String get historyClearedBody =>
      'Your library, your downloads and every remembered position were kept.';

  @override
  String get historyAgedOutTitle =>
      'Everything older than one year was dropped';

  @override
  String get historyAgedOutBody => 'Your reading positions were kept.';

  @override
  String get historyLoadErrorTitle => 'Your history could not be read';

  @override
  String get historyLoadErrorBody =>
      'Your library, your downloaded chapters and every remembered reading position are unaffected.';

  @override
  String get historyNoticeTitle => 'History is bounded by time';

  @override
  String get historyNoticeBody =>
      'Clearing it never moves a remembered reading position.';

  @override
  String get historyRetentionLabel => 'Keep history for';

  @override
  String get historyRetentionChange => 'Change';

  @override
  String get historyClearAction => 'Clear history';

  @override
  String get historyClearDialogTitle => 'Clear history?';

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
  String historyTerminalLine(String window) {
    return 'This is the oldest entry kept. Entries older than $window are dropped, oldest first.';
  }

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
  String get historyWindowOneWeek => 'one week';

  @override
  String get historyWindowOneMonth => 'one month';

  @override
  String get historyWindowThreeMonths => 'three months';

  @override
  String get historyWindowOneYear => 'one year';

  @override
  String get historyWindowTwoYears => 'two years';

  @override
  String get historyDayToday => 'Today';

  @override
  String get historyDayYesterday => 'Yesterday';

  @override
  String historyDayOn(String date) {
    return '$date';
  }

  @override
  String get historyJustNow => 'Just now';

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
  String aboutVersion(String buildName, String buildNumber) {
    return 'Version $buildName · build $buildNumber';
  }

  @override
  String get aboutProvenance =>
      'Android phone · built automatically · no store';

  @override
  String get aboutCopyVersion => 'Copy version number';

  @override
  String get aboutVersionUnreadable =>
      'The installed version number could not be read.';

  @override
  String get aboutSnackCopied => 'Version number copied.';

  @override
  String get aboutGuarantee =>
      'Installing a new version keeps your library, your downloads, your reading positions and your history. Nothing is replaced or re-downloaded.';

  @override
  String get aboutDataLabel => 'YOUR DATA ON THIS DEVICE';

  @override
  String get aboutDataLibrary => 'Library';

  @override
  String get aboutDataDownloaded => 'Downloaded chapters';

  @override
  String get aboutDataPositions => 'Reading positions';

  @override
  String get aboutDataCountUnavailable => '—';

  @override
  String get aboutDataE11 =>
      'Nothing here is backed up anywhere. If you uninstall Lumen Tale or lose this phone, all three numbers go to zero and no copy exists. Installing a new version over this one does not touch them — that is the only guarantee this app makes about your data.';

  @override
  String get aboutPrivacyLabel => 'WHAT LEAVES THIS DEVICE';

  @override
  String get aboutPrivacySent1 =>
      'A chapter\'s page — but only after you asked for it.';

  @override
  String get aboutPrivacySent2 =>
      'One request to check whether a newer version exists — only if you tap \"Check for a new version\".';

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
  String get aboutPrivacyVerify =>
      'Check it yourself: switch the phone to airplane mode, then open the app. Your library, your downloads and your reading positions are all there. Nothing is missing, because nothing was ever sent.';

  @override
  String get aboutDeliveryBody =>
      'This app runs on Android phones only. A new build is produced every time a change is merged, and you install it from the file by hand. There is no app store and no store account.';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsLanguageEnglish => 'English';

  @override
  String get settingsLanguageFrench => 'Français';

  @override
  String get settingsGroupReading => 'READING';

  @override
  String get settingsGroupHistory => 'HISTORY';

  @override
  String get settingsGroupApp => 'APP';

  @override
  String get settingsRowAppearanceLabel => 'Reader appearance';

  @override
  String settingsRowAppearanceValue(String theme, String size, String pt) {
    return '$theme · $size ($pt pt)';
  }

  @override
  String get settingsThemeDay => 'Day';

  @override
  String get settingsThemeNight => 'Night';

  @override
  String get settingsThemeSystem => 'Follow the phone';

  @override
  String get settingsSizeSm => 'Small';

  @override
  String get settingsSizeMd => 'Medium';

  @override
  String get settingsSizeLg => 'Large';

  @override
  String get settingsSizeXl => 'Larger';

  @override
  String get settingsSizeXxl => 'Largest';

  @override
  String get settingsRowHistoryLabel => 'Reading history';

  @override
  String settingsRowHistoryValue(String count, String relative) {
    return '$count entries · oldest $relative';
  }

  @override
  String get settingsRowHistoryValueEmpty => '0 entries';

  @override
  String get settingsRowRetentionLabel => 'Keep history for';

  @override
  String get settingsRowClearHistoryLabel => 'Clear reading history';

  @override
  String settingsDialogClearHistoryTitle(String count) {
    return 'Clear $count entries?';
  }

  @override
  String get settingsDialogClearHistoryBody =>
      'Reading positions are not part of this list and will not be touched.';

  @override
  String get settingsDialogClearHistoryConfirm => 'Clear';

  @override
  String get settingsSnackHistoryCleared =>
      'Reading history cleared. Your reading positions were kept.';

  @override
  String get settingsRowLanguageLabel => 'Language';

  @override
  String get settingsRowLanguageHint =>
      'Follows your phone. Change it in Android\'s language settings.';

  @override
  String get settingsRowOnboardingLabel => 'How this app works';

  @override
  String get settingsRowOnboardingValue =>
      'Show the two introduction screens again';

  @override
  String get settingsRowAboutLabel => 'About Lumen Tale';

  @override
  String settingsRowAboutValue(String buildName, String buildNumber) {
    return 'Version $buildName · build $buildNumber';
  }

  @override
  String get settingsDisclosureE11 =>
      'Nothing here is backed up. If you uninstall Lumen Tale or lose this phone, your library, your downloads and your reading positions are gone, and no copy exists anywhere.';

  @override
  String get settingsDisclosureE11Footer =>
      'The app cannot warn you at the moment you uninstall — the phone does that, outside the app. So it is said here, before, rather than after.';

  @override
  String get settingsDisclosureAboutLink => 'What survives an update';

  @override
  String get settingsErrorWrite =>
      'This setting could not be saved. Nothing was changed.';

  @override
  String get settingsErrorCountUnavailable => 'Count unavailable';

  @override
  String get settingsButtonRetry => 'Try again';

  @override
  String get settingsButtonCancel => 'Cancel';

  @override
  String get readerOfflineBanner => 'You are reading your downloads';

  @override
  String get readerNotStoredTitle => 'This chapter is not downloaded';

  @override
  String get readerNotStoredBody =>
      'Only chapters already on this phone can be read here.';

  @override
  String get readerOfflineAbsentTitle =>
      'This chapter is not downloaded and there is no connection';

  @override
  String get readerOfflineAbsentBody =>
      'Both are needed: the chapter has to be downloaded once, and downloading needs a connection.';

  @override
  String get readerFileMissingTitle =>
      'This chapter had been downloaded, but its text is no longer on this phone';

  @override
  String get readerFileMissingBody =>
      'The download succeeded. The file is what is missing.';

  @override
  String get readerFileEmptyTitle =>
      'This chapter\'s recording was interrupted';

  @override
  String get readerFileEmptyBody =>
      'Nothing was saved, so there is nothing to read.';

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
  String get readerRowGoneTitle =>
      'This chapter no longer exists in your library';

  @override
  String get readerRowGoneBody =>
      'The link may have been saved before the chapter was removed.';

  @override
  String get readerLoadFailedTitle => 'This chapter could not be opened';

  @override
  String get readerLoadFailedBody =>
      'The app does not know whether the file is intact.';

  @override
  String get readerActionDownloadChapter => 'Download this chapter';

  @override
  String get readerActionDownloadAgain => 'Download again';

  @override
  String get readerActionOpenDownloads => 'Open downloads';

  @override
  String get readerActionBack => 'Back';

  @override
  String get readerActionRetry => 'Retry';

  @override
  String get readerDownloadNeedsConnection => 'Downloading needs a connection';

  @override
  String readerChapterNumber(String number) {
    return 'Chapter $number';
  }

  @override
  String get readerChapterNumberUnreadable => 'Chapter';

  @override
  String get libraryTitle => 'Library';

  @override
  String get libraryContinueOverline => 'CONTINUE READING';

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
  String get libraryTileAuthorMissing => 'Author unknown';

  @override
  String libraryTileProgress(Object downloaded, Object total) {
    return '$downloaded of $total downloaded';
  }

  @override
  String get libraryTileUndownloaded => 'Not downloaded yet';

  @override
  String get libraryRemoveTitle => 'Remove from library?';

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
  String get libraryRemoveAction => 'Remove';

  @override
  String get libraryRemoveKept =>
      'Nothing was deleted. The chapters are still here.';

  @override
  String get libraryRemoveUndo => 'Undo';

  @override
  String libraryRemoved(Object title) {
    return '$title was removed';
  }

  @override
  String get librarySimilarTitle =>
      'A novel with this title is already in your library';

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
  String get librarySimilarOpenExisting => 'Open the existing one';

  @override
  String get librarySimilarAddAnyway => 'Add anyway';

  @override
  String get librarySimilarExplain =>
      'Nothing will be merged — they stay two separate novels.';

  @override
  String get libraryLoadErrorTitle => 'Your library could not be read';

  @override
  String get libraryAddFailed =>
      'The novel could not be added. It is still listed in Browse.';

  @override
  String get libraryAddFailedRetry => 'Retry';

  @override
  String get libraryActionCancel => 'Cancel';

  @override
  String get browseTitle => 'Browse';

  @override
  String browseSourceUnavailableTitle(Object source) {
    return '$source could not be read';
  }

  @override
  String get browseSourceUnavailableBody =>
      'The page loaded, but the part that lists novels was not on it. Nothing is wrong with your library, and nothing was downloaded.';

  @override
  String browseEmptyTagTitle(Object tag) {
    return 'Nothing tagged $tag';
  }

  @override
  String browseEmptyTagBody(Object source) {
    return '$source publishes no novel under that tag. Try another tag.';
  }

  @override
  String get browseSiteSaidNothingTitle => 'The site says it has nothing';

  @override
  String browseSiteSaidNothingBody(Object query, Object source) {
    return 'Searching $source for \"$query\" returned nothing.';
  }

  @override
  String get browseNoConnectionTitle => 'No connection';

  @override
  String browseNoConnectionBody(Object source) {
    return '$source could not be reached. Your library is unaffected.';
  }

  @override
  String get browseActionRetry => 'Retry';

  @override
  String get browseActionOpenLibrary => 'Open library';

  @override
  String get browseActionBrowseAnother => 'Browse another tag';

  @override
  String get browseFailureLayoutChanged => 'The site\'s layout changed';

  @override
  String get browseFailureRateLimited => 'The site asked us to slow down';

  @override
  String get browseFailureNoConnection => 'No connection';

  @override
  String get browseFailureUnavailable => 'The site is unavailable';

  @override
  String get browseFailureParse => 'The page could not be read';

  @override
  String get browseFailureItemRemoved => 'That novel is no longer on the site';

  @override
  String get browseTileKept => 'In your library';

  @override
  String get browseTileAdd => 'Add';

  @override
  String get browseTileOpen => 'Open';

  @override
  String get browseFooterLoadingMore => 'Loading more…';

  @override
  String get browseFooterEnd => 'That is everything this tag publishes';
}
