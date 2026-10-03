import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_fr.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('fr'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Lumen Tale'**
  String get appTitle;

  /// No description provided for @navLibrary.
  ///
  /// In en, this message translates to:
  /// **'Library'**
  String get navLibrary;

  /// No description provided for @navBrowse.
  ///
  /// In en, this message translates to:
  /// **'Browse'**
  String get navBrowse;

  /// No description provided for @navUpdates.
  ///
  /// In en, this message translates to:
  /// **'Updates'**
  String get navUpdates;

  /// No description provided for @navHistory.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get navHistory;

  /// No description provided for @navMore.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get navMore;

  /// No description provided for @navDownloads.
  ///
  /// In en, this message translates to:
  /// **'Downloads'**
  String get navDownloads;

  /// No description provided for @navSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get navSettings;

  /// No description provided for @commonRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get commonRetry;

  /// No description provided for @commonCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get commonCancel;

  /// No description provided for @commonBack.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get commonBack;

  /// No description provided for @commonErrorTitle.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong'**
  String get commonErrorTitle;

  /// No description provided for @commonErrorBody.
  ///
  /// In en, this message translates to:
  /// **'The operation could not be completed.'**
  String get commonErrorBody;

  /// No description provided for @libraryEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'Your library is empty'**
  String get libraryEmptyTitle;

  /// No description provided for @libraryEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Add a novel from Browse to start reading.'**
  String get libraryEmptyBody;

  /// No description provided for @browseEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'No source is available yet.'**
  String get browseEmptyBody;

  /// Number of chapters available for a novel.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No chapters} =1{1 chapter} other{{count} chapters}}'**
  String chapterCount(int count);

  /// Accessibility label for a novel cover thumbnail.
  ///
  /// In en, this message translates to:
  /// **'Cover of {title}'**
  String coverSemanticsLabel(String title);

  /// E5. The sentence says what stays usable, not only what failed.
  ///
  /// In en, this message translates to:
  /// **'No connection. Your downloaded chapters stay readable.'**
  String get errorNoConnection;

  /// C7. A 429 with no usable Retry-After header.
  ///
  /// In en, this message translates to:
  /// **'The site asked us to slow down. Try again shortly.'**
  String get errorRateLimited;

  /// C7. The duration comes from the site's Retry-After header, never from a guess.
  ///
  /// In en, this message translates to:
  /// **'The site asked us to slow down. Try again in {seconds} seconds.'**
  String errorRateLimitedIn(int seconds);

  /// E4 / SC-6. Nothing to retry: this is a defect to report.
  ///
  /// In en, this message translates to:
  /// **'This site has changed its layout. The app can no longer read it.'**
  String get errorSourceLayoutChanged;

  /// A non-success status. Retriable later, so Retry is honest.
  ///
  /// In en, this message translates to:
  /// **'This site is not responding. Try again later.'**
  String get errorSourceUnavailable;

  /// E9. One item vanished; the sentence says so, or the reader thinks data was lost.
  ///
  /// In en, this message translates to:
  /// **'This novel is no longer on the site. The rest of your library is untouched.'**
  String get errorItemRemovedAtSource;

  /// C8. The only cause whose sentence contains an action that actually works.
  ///
  /// In en, this message translates to:
  /// **'Storage is full. Free some space, then try again.'**
  String get errorStorageFull;

  /// C12. The action is report, because nothing can repair a failed conversion.
  ///
  /// In en, this message translates to:
  /// **'A file for this novel could not be read. Please report it to whoever maintains this app.'**
  String get errorParseFailed;

  /// B22. 'Your other sources': one site failing is not the app failing.
  ///
  /// In en, this message translates to:
  /// **'This site could not be read. Your other sources work normally.'**
  String get errorSiteUnreadable;

  /// A startup failure, therefore never a screen state. See the comment on main().
  ///
  /// In en, this message translates to:
  /// **'Your settings could not be loaded.'**
  String get errorSettingsLoad;

  /// The control snaps back and says why: showing a value it could not store is worse than a visible failure.
  ///
  /// In en, this message translates to:
  /// **'This setting could not be saved. It will keep its previous value.'**
  String get errorSettingsWrite;

  /// B46: reading position is not involved, and the sentence must not let the reader think it is.
  ///
  /// In en, this message translates to:
  /// **'History could not be cleared.'**
  String get errorHistoryClear;

  /// B48: an uncertain count says it is uncertain; it is never estimated.
  ///
  /// In en, this message translates to:
  /// **'That count could not be computed.'**
  String get errorCountUnavailable;

  /// A warning, not an error: the app works, the phone decided.
  ///
  /// In en, this message translates to:
  /// **'Notifications are turned off in your phone\'s settings.'**
  String get warningNotifications;

  /// Exists so the mapping is complete; 13-error-handling.md rule 7 means cancelled, not failed.
  ///
  /// In en, this message translates to:
  /// **'Check cancelled.'**
  String get checkCancelled;

  /// B22: the third state, distinct from failure, and available only where the site supplies its own signal.
  ///
  /// In en, this message translates to:
  /// **'This site has nothing to show here.'**
  String get browseEmpty;

  /// Almost never displayed; it exists so the mapping is exhaustive and testable.
  ///
  /// In en, this message translates to:
  /// **'Read successfully.'**
  String get browseSucceeded;

  /// One of the four DownloadState values. B37: the queue is visible and cancellable before the first byte.
  ///
  /// In en, this message translates to:
  /// **'Queued for download'**
  String get downloadQueued;

  /// The in-progress state. The percentage is a number, never an estimate of the time left.
  ///
  /// In en, this message translates to:
  /// **'Downloading'**
  String get downloadDownloading;

  /// B6: the word appears only after the atomic rename, so the file is whole.
  ///
  /// In en, this message translates to:
  /// **'Downloaded'**
  String get downloadDone;

  /// Retriable because nothing was written: the write is atomic.
  ///
  /// In en, this message translates to:
  /// **'Download interrupted. You can try it again.'**
  String get downloadFailed;

  /// The action for errorStorageFull. It works, so it is offered.
  ///
  /// In en, this message translates to:
  /// **'Free space'**
  String get actionFreeSpace;

  /// The action for errorParseFailed and errorSourceLayoutChanged. No Retry button repairs either.
  ///
  /// In en, this message translates to:
  /// **'Report the problem'**
  String get actionReportBug;

  /// Screen title
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get historyTitle;

  /// B10 / E2: the site published no title for this chapter. Rendered here, NEVER as an index and never as a generated number - a fabricated title is a sentence the app invented and the reader would believe.
  ///
  /// In en, this message translates to:
  /// **'Untitled'**
  String get historyUntitledChapter;

  /// A novel whose stored title is empty. The same rule as the chapter: a placeholder, never an index.
  ///
  /// In en, this message translates to:
  /// **'Untitled'**
  String get historyUntitledNovel;

  /// Accessibility label while the list loads. Eight skeletons, no cover - the `history` variant of NovelRow declares no cover slot, and a loading state that shows one promises an image the filled rows will not have.
  ///
  /// In en, this message translates to:
  /// **'Loading history'**
  String get historyLoadingTitle;

  /// US-12 distinguishes 'never opened anything' from 'opened things and then cleared them'. This is the FIRST; the second is historyClearedTitle.
  ///
  /// In en, this message translates to:
  /// **'Nothing read yet'**
  String get historyEmptyTitle;

  /// Says what the screen is FOR, in the reader's terms, and states the order it will be in.
  ///
  /// In en, this message translates to:
  /// **'The chapters you open appear here, newest first.'**
  String get historyEmptyBody;

  /// The empty action depends on a LOCAL FACT: this one when the library is empty, historyEmptyActionLibrary when it is not. A fixed string would point at a library the reader does not have.
  ///
  /// In en, this message translates to:
  /// **'Browse a source'**
  String get historyEmptyActionBrowse;

  /// The other half of the same local fact. Deciding by what is already on the phone is the difference between 'where do I go next' and 'here is a button'.
  ///
  /// In en, this message translates to:
  /// **'Open your library'**
  String get historyEmptyActionLibrary;

  /// Empty - no data (a). history.md § 4 splits this state in two because being cleared BY THE READER and being AGED OUT are different events with different emotional weight.
  ///
  /// In en, this message translates to:
  /// **'History cleared'**
  String get historyClearedTitle;

  /// B46 said out loud, on the screen where the fear lives. Repeated in the clear confirmation, in this state, and in the store-failure sentence - four times, because it is the thing a reader on a device with no backup is actually afraid of.
  ///
  /// In en, this message translates to:
  /// **'Your library, your downloads and every remembered position were kept.'**
  String get historyClearedBody;

  /// Empty - no data (b). Distinct from historyClearedTitle because nobody did this on purpose.
  ///
  /// In en, this message translates to:
  /// **'Everything older than one year was dropped'**
  String get historyAgedOutTitle;

  /// Both empty-no-data states say WHAT SURVIVED. An empty list after a destructive action that says nothing is the moment a reader goes looking for what else just disappeared.
  ///
  /// In en, this message translates to:
  /// **'Your reading positions were kept.'**
  String get historyAgedOutBody;

  /// Load error. The only failure this screen can have is its own local store - nothing on it ever needed a network (C14).
  ///
  /// In en, this message translates to:
  /// **'Your history could not be read'**
  String get historyLoadErrorTitle;

  /// Unusually specific because the fear here is data loss and this app has no backup (ADR-010). Naming the three survivals by name is what stops the reader assuming the worst.
  ///
  /// In en, this message translates to:
  /// **'Your library, your downloaded chapters and every remembered reading position are unaffected.'**
  String get historyLoadErrorBody;

  /// B47 stated on the screen where the fear lives: the list is bounded, and something else is not.
  ///
  /// In en, this message translates to:
  /// **'History is bounded by time'**
  String get historyNoticeTitle;

  /// B46 in one line.
  ///
  /// In en, this message translates to:
  /// **'Clearing it never moves a remembered reading position.'**
  String get historyNoticeBody;

  /// A row WITH this label goes somewhere - it opens the sheet. The absence of a chevron would say the value can be changed in place, which it cannot.
  ///
  /// In en, this message translates to:
  /// **'Keep history for'**
  String get historyRetentionLabel;

  /// The action that opens SettingsChoiceSheet. 'Change' rather than 'Keep for one year': the value is printed next to it, and a label repeating it would be two places to update on every window change.
  ///
  /// In en, this message translates to:
  /// **'Change'**
  String get historyRetentionChange;

  /// The only destructive action on the most read-only screen in the app, and it says exactly what it clears. Never 'OK', never 'Delete'.
  ///
  /// In en, this message translates to:
  /// **'Clear history'**
  String get historyClearAction;

  /// A question, not a statement. 'Clear history?' lets the reader cancel without reading the body.
  ///
  /// In en, this message translates to:
  /// **'Clear history?'**
  String get historyClearDialogTitle;

  /// Clear confirmation
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No entries will be removed.} =1{One entry will be removed.} other{{count} entries will be removed.}} Your library, your downloads and every remembered reading position will be kept.'**
  String historyClearDialogBody(int count);

  /// The destructive button, in full. 'OK' on a dialog that empties a reader's log is a button asking them to trust a process they have just been told nothing about.
  ///
  /// In en, this message translates to:
  /// **'Clear history'**
  String get historyClearDialogConfirm;

  /// B47's stated bound, at the END of the list, so a reader who scrolls to the bottom finds the limit rather than having it announced only at the top. There is no unbounded case, so this sentence is never absent: a screen that claimed a bound it was not applying is the exact failure B47 was written to avoid.
  ///
  /// In en, this message translates to:
  /// **'This is the oldest entry kept. Entries older than {window} are dropped, oldest first.'**
  String historyTerminalLine(String window);

  /// design-system.md § 2.12's SettingsChoiceSheet. `3-7` renders its rows from the SAME HistoryRetention enum, which is what makes 'the same five windows' a fact rather than a promise.
  ///
  /// In en, this message translates to:
  /// **'Keep history for'**
  String get historySheetTitle;

  /// The sentence above the options, BEFORE the reader chooses. It names the window currently highlighted and promises positions are untouched.
  ///
  /// In en, this message translates to:
  /// **'Entries older than {window} will be dropped, oldest first. Your reading positions are never affected.'**
  String historySheetWarning(String window);

  /// The same sentence when the chosen window would drop nothing. A reader must not be told entries will be dropped when none will.
  ///
  /// In en, this message translates to:
  /// **'No entries will be dropped. Your reading positions are never affected.'**
  String get historySheetWarningNone;

  /// Success. It repeats the promise from the empty state, because a reader who has just emptied a list is exactly the reader who will wonder what else went with it.
  ///
  /// In en, this message translates to:
  /// **'History cleared. Your reading positions were kept.'**
  String get historySnackCleared;

  /// Submit error: the list did NOT change. An optimistic empty list is a record of something that never happened.
  ///
  /// In en, this message translates to:
  /// **'History was not cleared.'**
  String get historySnackNotCleared;

  /// Success after a window change. It NAMES the new window, because a screen saying 'one year' in the notice and 'three months' in the snackbar is two lies.
  ///
  /// In en, this message translates to:
  /// **'History is now kept for {window}.'**
  String historySnackWindowChanged(String window);

  /// The five window names are DATA, not screen copy: HistoryRetention.cutoffFrom is computed from the enum's Duration, and this string is only what a reader reads. Two representations of one window, and a test asserts the enum has exactly these five members.
  ///
  /// In en, this message translates to:
  /// **'one week'**
  String get historyWindowOneWeek;

  /// See historyWindowOneWeek.
  ///
  /// In en, this message translates to:
  /// **'one month'**
  String get historyWindowOneMonth;

  /// See historyWindowOneWeek.
  ///
  /// In en, this message translates to:
  /// **'three months'**
  String get historyWindowThreeMonths;

  /// The default window. HistoryRetention.defaultWindow is this member, and a test asserts it rather than trusting the string.
  ///
  /// In en, this message translates to:
  /// **'one year'**
  String get historyWindowOneYear;

  /// The longest window the design offers. There is deliberately no sixth: design-system.md § 2.12 forbids a 'forever' option on any bounded list, because an unbounded value next to bounded ones teaches the reader the bounds are negotiable.
  ///
  /// In en, this message translates to:
  /// **'two years'**
  String get historyWindowTwoYears;

  /// The first day header. NOT concatenated from a month name and a number: 'Today' is a word, it takes an article in some languages and an inflection in others, and a concatenation is wrong in both. E12 requires a language change to re-label the headers, which a concatenated string cannot do.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get historyDayToday;

  /// The second day header, and a separate key for the same reason as historyDayToday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get historyDayYesterday;

  /// Every older day header. `{date}` arrives ALREADY localised from MaterialLocalizations.formatMediumDate - this key is a hole for a platform-formatted date, not a sentence, which is why the value is the same in both files.
  ///
  /// In en, this message translates to:
  /// **'{date}'**
  String historyDayOn(String date);

  /// The row's trailing time under a minute old. Deliberately the only bucketing below an hour: a reader who opened four chapters in ten minutes sees the same word on all four, and a count that ticks upward every second would make the list move under them.
  ///
  /// In en, this message translates to:
  /// **'Just now'**
  String get historyJustNow;

  /// Minutes, with a French plural rule (`=1` vs `other`) - French has no singular-only form and a reader watching 'Il y a 1 minutes' learns to distrust the rest of the screen.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 minute ago} other{{count} minutes ago}}'**
  String historyMinutesAgo(int count);

  /// Hours, same plural rule. There is deliberately NO days-ago key: past yesterday the DAY GROUP HEADER already carries the date, and repeating it in the row would say the same thing twice on every line.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 hour ago} other{{count} hours ago}}'**
  String historyHoursAgo(int count);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'fr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'fr':
      return AppLocalizationsFr();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
