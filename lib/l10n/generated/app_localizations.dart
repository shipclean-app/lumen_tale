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

  /// B43: the reader can determine which version is installed. `buildName` and `buildNumber` arrive from Flutter's build-time Dart defines (`FLUTTER_BUILD_NAME` / `FLUTTER_BUILD_NUMBER`, ADR-011) — the app reads pubspec at build time and never parses a file at runtime.
  ///
  /// In en, this message translates to:
  /// **'Version {buildName} · build {buildNumber}'**
  String aboutVersion(String buildName, String buildNumber);

  /// How this build reached the reader. Three facts in one line, because a reader who installed a file by hand needs to know that is normal.
  ///
  /// In en, this message translates to:
  /// **'Android phone · built automatically · no store'**
  String get aboutProvenance;

  /// The clipboard button. C9 says the owner must be able to determine which version is installed, and pasting a version into a bug report is how that happens.
  ///
  /// In en, this message translates to:
  /// **'Copy version number'**
  String get aboutCopyVersion;

  /// A real failure mode: the defines are absent in a plain `flutter test` and in an IDE run. **The rest of the screen renders completely** — `Version —` is forbidden, because an em dash looks like a version and C9 requires the version to be determinable.
  ///
  /// In en, this message translates to:
  /// **'The installed version number could not be read.'**
  String get aboutVersionUnreadable;

  ///
  ///
  /// In en, this message translates to:
  /// **'Version number copied.'**
  String get aboutSnackCopied;

  /// B31, and the one sentence § 4bis kept when it removed `UpdateBlock`. It is the only guarantee this app makes about the reader's data, so it is read out loud here rather than discovered after an upgrade.
  ///
  /// In en, this message translates to:
  /// **'Installing a new version keeps your library, your downloads, your reading positions and your history. Nothing is replaced or re-downloaded.'**
  String get aboutGuarantee;

  /// The recessed block's overline. Read as a heading.
  ///
  /// In en, this message translates to:
  /// **'YOUR DATA ON THIS DEVICE'**
  String get aboutDataLabel;

  ///
  ///
  /// In en, this message translates to:
  /// **'Library'**
  String get aboutDataLibrary;

  ///
  ///
  /// In en, this message translates to:
  /// **'Downloaded chapters'**
  String get aboutDataDownloaded;

  ///
  ///
  /// In en, this message translates to:
  /// **'Reading positions'**
  String get aboutDataPositions;

  /// A count that could not be computed, and NOT a zero. The distinction is the whole reason the three figures are evidence for B31: a zero says 'you have none' and a dash says 'we could not look', and a reader who took the first for the second would re-download a library they still have.
  ///
  /// In en, this message translates to:
  /// **'—'**
  String get aboutDataCountUnavailable;

  /// E11, in full and unhedged. This app has no backup (ADR-010), so the disclosure belongs on the page that shows what would be lost — and it names the exact operation that does NOT lose it, because a disclosure that only lists risks reads as an apology.
  ///
  /// In en, this message translates to:
  /// **'Nothing here is backed up anywhere. If you uninstall Lumen Tale or lose this phone, all three numbers go to zero and no copy exists. Installing a new version over this one does not touch them — that is the only guarantee this app makes about your data.'**
  String get aboutDataE11;

  ///
  ///
  /// In en, this message translates to:
  /// **'WHAT LEAVES THIS DEVICE'**
  String get aboutPrivacyLabel;

  ///
  ///
  /// In en, this message translates to:
  /// **'A chapter\'s page — but only after you asked for it.'**
  String get aboutPrivacySent1;

  /// ⚠️ **Written for a control § 4bis removed.** The sentence is about a button this screen does not have. It is kept because the block's claim is about the APP's network posture rather than about the button: the app sends nothing on its own account, and if a version check returns the reader must already know that one request is the whole of it. If the check is ever built, this sentence is its first line and it is already true.
  ///
  /// In en, this message translates to:
  /// **'One request to check whether a newer version exists — only if you tap \"Check for a new version\".'**
  String get aboutPrivacySent2;

  ///
  ///
  /// In en, this message translates to:
  /// **'Your library'**
  String get aboutPrivacyNever1;

  ///
  ///
  /// In en, this message translates to:
  /// **'Your reading positions'**
  String get aboutPrivacyNever2;

  ///
  ///
  /// In en, this message translates to:
  /// **'Your history'**
  String get aboutPrivacyNever3;

  ///
  ///
  /// In en, this message translates to:
  /// **'Your error logs'**
  String get aboutPrivacyNever4;

  ///
  ///
  /// In en, this message translates to:
  /// **'Crash reports'**
  String get aboutPrivacyNever5;

  ///
  ///
  /// In en, this message translates to:
  /// **'Analytics'**
  String get aboutPrivacyNever6;

  ///
  ///
  /// In en, this message translates to:
  /// **'A device identifier'**
  String get aboutPrivacyNever7;

  /// The falsifiable form of the privacy claim. A promise that cannot be tested by the reader is marketing; airplane mode is the test, and it takes thirty seconds.
  ///
  /// In en, this message translates to:
  /// **'Check it yourself: switch the phone to airplane mode, then open the app. Your library, your downloads and your reading positions are all there. Nothing is missing, because nothing was ever sent.'**
  String get aboutPrivacyVerify;

  /// B34 + C3 + C9: the app IS the file. 'There is no app store' is not a limitation to apologise for — it is why there is no account and no server holding anything.
  ///
  /// In en, this message translates to:
  /// **'This app runs on Android phones only. A new build is produced every time a change is merged, and you install it from the file by hand. There is no app store and no store account.'**
  String get aboutDeliveryBody;

  ///
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// ⚠️ **Identical in the French file.** The `Language` row reports the phone's language, not the app's, and a reader on an English UI with a French phone must see "Français". B28: the app follows the phone.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get settingsLanguageEnglish;

  /// ⚠️ **Identical in the English file**, for the same reason. A value that changes with the ARB would be the app naming the phone's language in the app's language, which is a different claim.
  ///
  /// In en, this message translates to:
  /// **'Français'**
  String get settingsLanguageFrench;

  ///
  ///
  /// In en, this message translates to:
  /// **'READING'**
  String get settingsGroupReading;

  ///
  ///
  /// In en, this message translates to:
  /// **'HISTORY'**
  String get settingsGroupHistory;

  ///
  ///
  /// In en, this message translates to:
  /// **'APP'**
  String get settingsGroupApp;

  ///
  ///
  /// In en, this message translates to:
  /// **'Reader appearance'**
  String get settingsRowAppearanceLabel;

  /// Both halves on one line: `{theme}` and `{size}` are the two values the reader set, and `{pt}` is the resolved point size. ⚠️ **The value line truncates, not the label** — § 4.1 says so, and it is a consequence of French running longer than English, not a defect.
  ///
  /// In en, this message translates to:
  /// **'{theme} · {size} ({pt} pt)'**
  String settingsRowAppearanceValue(String theme, String size, String pt);

  ///
  ///
  /// In en, this message translates to:
  /// **'Day'**
  String get settingsThemeDay;

  ///
  ///
  /// In en, this message translates to:
  /// **'Night'**
  String get settingsThemeNight;

  /// B26's `system` value, named for what it does. NOT 'Automatic': a reader who reads *Automatic* does not learn that the app follows the phone.
  ///
  /// In en, this message translates to:
  /// **'Follow the phone'**
  String get settingsThemeSystem;

  ///
  ///
  /// In en, this message translates to:
  /// **'Small'**
  String get settingsSizeSm;

  ///
  ///
  /// In en, this message translates to:
  /// **'Medium'**
  String get settingsSizeMd;

  ///
  ///
  /// In en, this message translates to:
  /// **'Large'**
  String get settingsSizeLg;

  ///
  ///
  /// In en, this message translates to:
  /// **'Larger'**
  String get settingsSizeXl;

  ///
  ///
  /// In en, this message translates to:
  /// **'Largest'**
  String get settingsSizeXxl;

  ///
  ///
  /// In en, this message translates to:
  /// **'Reading history'**
  String get settingsRowHistoryLabel;

  /// `{count}` and `{relative}`. ⚠️ **Never a zero here** — `settingsRowHistoryValueEmpty` is a separate key, because `{count} entries · oldest {relative}` with a zero has no oldest to name.
  ///
  /// In en, this message translates to:
  /// **'{count} entries · oldest {relative}'**
  String settingsRowHistoryValue(String count, String relative);

  /// The zero. French takes the singular on zero ('0 entrée'), which is a plural-rule difference and not a typo.
  ///
  /// In en, this message translates to:
  /// **'0 entries'**
  String get settingsRowHistoryValueEmpty;

  ///
  ///
  /// In en, this message translates to:
  /// **'Keep history for'**
  String get settingsRowRetentionLabel;

  ///
  ///
  /// In en, this message translates to:
  /// **'Clear reading history'**
  String get settingsRowClearHistoryLabel;

  /// ⚠️ **The count is in the TITLE**, not the body. This dialog's one job is to say how much is about to be destroyed, and a title is what a reader reads before they read anything else. `3-7`'s Loading state exists only for the COUNT this sentence waits on.
  ///
  /// In en, this message translates to:
  /// **'Clear {count} entries?'**
  String settingsDialogClearHistoryTitle(String count);

  /// B46, and the second clause is the whole sentence: reading positions are not in this list. `clearAll()` deletes exactly one table and a row asserts the positions survive.
  ///
  /// In en, this message translates to:
  /// **'Reading positions are not part of this list and will not be touched.'**
  String get settingsDialogClearHistoryBody;

  /// ⚠️ **`Clear`, not `OK`, and not `Delete`** — it names the object. And § 4 (Empty — no data) forbids the dialog opening at all when the count is zero, so a reader is never asked to confirm destroying nothing.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get settingsDialogClearHistoryConfirm;

  /// The second clause is **mandatory and is the entire success message**, because B46 makes position the thing the reader must believe survived. A generic 'History cleared' leaves the reader fearing they lost their place, which is the app's core promise (B16).
  ///
  /// In en, this message translates to:
  /// **'Reading history cleared. Your reading positions were kept.'**
  String get settingsSnackHistoryCleared;

  /// **Read-only, and visibly so**: no chevron, no ripple, no pressed state. B28 forbids an in-app language picker — the platform owns this value and a second source of truth for it is a bug waiting to happen.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settingsRowLanguageLabel;

  /// Tells the reader where the control actually is, because there isn't one here. A read-only row with no explanation reads as a disabled control.
  ///
  /// In en, this message translates to:
  /// **'Follows your phone. Change it in Android\'s language settings.'**
  String get settingsRowLanguageHint;

  ///
  ///
  /// In en, this message translates to:
  /// **'How this app works'**
  String get settingsRowOnboardingLabel;

  ///
  ///
  /// In en, this message translates to:
  /// **'Show the two introduction screens again'**
  String get settingsRowOnboardingValue;

  ///
  ///
  /// In en, this message translates to:
  /// **'About Lumen Tale'**
  String get settingsRowAboutLabel;

  /// The same `{buildName}` · build `{buildNumber}` pair `3-5` shows, from the same `AppRoutes`-level source. Two spellings of the version on two pages would be two truths about which build is installed (C9).
  ///
  /// In en, this message translates to:
  /// **'Version {buildName} · build {buildNumber}'**
  String settingsRowAboutValue(String buildName, String buildNumber);

  ///
  ///
  /// In en, this message translates to:
  /// **'Nothing here is backed up. If you uninstall Lumen Tale or lose this phone, your library, your downloads and your reading positions are gone, and no copy exists anywhere.'**
  String get settingsDisclosureE11;

  /// The footer, and it exists because of what it admits: the app cannot detect an uninstall as it happens, so the disclosure has to happen **before** rather than after. A disclosure that says 'you cannot undo this' without saying why is read as an apology.
  ///
  /// In en, this message translates to:
  /// **'The app cannot warn you at the moment you uninstall — the phone does that, outside the app. So it is said here, before, rather than after.'**
  String get settingsDisclosureE11Footer;

  /// The ghost link into About, and its label is the QUESTION it answers (B31's guarantee). A link labelled 'About' would compete with the row above it.
  ///
  /// In en, this message translates to:
  /// **'What survives an update'**
  String get settingsDisclosureAboutLink;

  /// A failed write, shown **beside** the control and never by tinting it — a red control reads as 'this setting is now off' rather than 'this setting could not be saved'.
  ///
  /// In en, this message translates to:
  /// **'This setting could not be saved. Nothing was changed.'**
  String get settingsErrorWrite;

  /// A count that could not be obtained, and **never `0`** (B48). § 4 (Load error, declined) scopes the failure to the one row that owns it: a failed `COUNT` renders this word on its own line and disables the clear row, rather than blanking eight correct rows.
  ///
  /// In en, this message translates to:
  /// **'Count unavailable'**
  String get settingsErrorCountUnavailable;

  ///
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get settingsButtonRetry;

  ///
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get settingsButtonCancel;

  /// ⚠️ **One ephemeral line, on the FIRST offline display of a session only.** § 3.5 forbids a banner, a gradient and any 'OFFLINE MODE' — this is a sentence that appears once and does not persist, because a persistent badge would be the third thing competing with the prose for the reader's attention.
  ///
  /// In en, this message translates to:
  /// **'You are reading your downloads'**
  String get readerOfflineBanner;

  /// ⚠️ **Empty-data, NOT an empty screen.** US-05: the reader must be able to SEE that 'not downloaded' differs from 'empty' and from 'failed'.
  ///
  /// In en, this message translates to:
  /// **'This chapter is not downloaded'**
  String get readerNotStoredTitle;

  /// The constraint this screen enforces: the reader never fetches. § 3.1's 'ChapterNotStored' branch emits an intent and 3-3 executes it.
  ///
  /// In en, this message translates to:
  /// **'Only chapters already on this phone can be read here.'**
  String get readerNotStoredBody;

  /// ⚠️ **BOTH facts in one sentence, and each is on its own insufficient.** 'Not downloaded' leaves the reader wondering whether the button will work; 'offline' leaves them wondering whether the chapter is theirs. B24 asks for the sentence that names both.
  ///
  /// In en, this message translates to:
  /// **'This chapter is not downloaded and there is no connection'**
  String get readerOfflineAbsentTitle;

  /// No description provided for @readerOfflineAbsentBody.
  ///
  /// In en, this message translates to:
  /// **'Both are needed: the chapter has to be downloaded once, and downloading needs a connection.'**
  String get readerOfflineAbsentBody;

  /// No description provided for @readerFileMissingTitle.
  ///
  /// In en, this message translates to:
  /// **'This chapter had been downloaded, but its text is no longer on this phone'**
  String get readerFileMissingTitle;

  /// ⚠️ **Says the DOWNLOAD SUCCEEDED and the FILE is missing.** `architecture.md` § 8 names this divergence. The other phrasing — 'this chapter is unavailable' — would tell the reader the download failed, which is false, and a reader who re-downloads on that sentence is doing the right thing for the wrong reason.
  ///
  /// In en, this message translates to:
  /// **'The download succeeded. The file is what is missing.'**
  String get readerFileMissingBody;

  /// ⚠️ **Distinct from 'corrupt'.** Zero bytes is the signature of an INTERRUPTED write, so the sentence is about the recording and the action is a re-download.
  ///
  /// In en, this message translates to:
  /// **'This chapter\'s recording was interrupted'**
  String get readerFileEmptyTitle;

  /// No description provided for @readerFileEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Nothing was saved, so there is nothing to read.'**
  String get readerFileEmptyBody;

  /// B18 / E18 — the file is there and holds no readable prose. The only action is to download it again.
  ///
  /// In en, this message translates to:
  /// **'This chapter\'s saved copy is not readable'**
  String get readerFileCorruptNotMarkdown;

  /// A truncation mid-character: the final file was still renamed although the write was cut short.
  ///
  /// In en, this message translates to:
  /// **'This chapter\'s saved copy ends mid-sentence'**
  String get readerFileCorruptTruncated;

  /// ⚠️ **The action here is RETRY, not re-download.** The copy may be intact and the filesystem merely refused; offering a re-download would suggest the file is at fault when it may not be.
  ///
  /// In en, this message translates to:
  /// **'This chapter\'s file could not be opened'**
  String get readerFileCorruptUnreadableIo;

  /// ⚠️ **Not a failure.** A stale identifier is a state of the world — a deep link followed earlier, or a navigation stack restored. It gets its own render and a way back, never an ErrorState, because an ErrorState would report THIS APP as broken for a link the reader followed.
  ///
  /// In en, this message translates to:
  /// **'This chapter no longer exists in your library'**
  String get readerRowGoneTitle;

  /// No description provided for @readerRowGoneBody.
  ///
  /// In en, this message translates to:
  /// **'The link may have been saved before the chapter was removed.'**
  String get readerRowGoneBody;

  /// ⚠️ **'Could not be opened', not 'is corrupt'.** This is the absence of a conclusion: the app could not find out which of the other states it is. Saying 'corrupt' would be a guess, and the guess would pick the wrong action.
  ///
  /// In en, this message translates to:
  /// **'This chapter could not be opened'**
  String get readerLoadFailedTitle;

  /// No description provided for @readerLoadFailedBody.
  ///
  /// In en, this message translates to:
  /// **'The app does not know whether the file is intact.'**
  String get readerLoadFailedBody;

  /// No description provided for @readerActionDownloadChapter.
  ///
  /// In en, this message translates to:
  /// **'Download this chapter'**
  String get readerActionDownloadChapter;

  /// No description provided for @readerActionDownloadAgain.
  ///
  /// In en, this message translates to:
  /// **'Download again'**
  String get readerActionDownloadAgain;

  /// No description provided for @readerActionOpenDownloads.
  ///
  /// In en, this message translates to:
  /// **'Open downloads'**
  String get readerActionOpenDownloads;

  /// No description provided for @readerActionBack.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get readerActionBack;

  /// No description provided for @readerActionRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get readerActionRetry;

  /// Shown UNDER the disabled primary action (§ 3.5), never as a replacement for it. A disabled button with no reason is a button the reader assumes is broken.
  ///
  /// In en, this message translates to:
  /// **'Downloading needs a connection'**
  String get readerDownloadNeedsConnection;

  /// ⚠️ **The placeholder is a `String`, not a number, and that is load-bearing.** `chapters.number` is a `RealColumn` (a `double`), and an ICU `{number}` bound to a double renders "Chapter 12.0" — which asserts a decimal place the site never printed. The formatting lives in Dart (`formatChapterNumber`), where a whole value drops its fraction and a fractional one keeps it. Rule 9 is about *displaying* the site's number, and 12.0 is not what the site wrote.
  ///
  /// In en, this message translates to:
  /// **'Chapter {number}'**
  String readerChapterNumber(String number);

  /// The word used when the site's number could not be parsed. Not a number and not an ellipsis: the reader is told the chapter has no number rather than shown a `0`.
  ///
  /// In en, this message translates to:
  /// **'Chapter'**
  String get readerChapterNumberUnreadable;
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
