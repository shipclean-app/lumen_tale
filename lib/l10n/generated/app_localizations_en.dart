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
}
