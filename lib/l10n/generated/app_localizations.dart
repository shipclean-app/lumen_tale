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
