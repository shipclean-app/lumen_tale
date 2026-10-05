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

  /// The clipboard button. C9 says the owner must be able to determine which version is installed, and pasting a version into a bug report is how that happens.
  ///
  /// In en, this message translates to:
  /// **'Copy version number'**
  String get aboutCopyVersion;

  /// A count that could not be computed, and NOT a zero. The distinction is the whole reason the three figures are evidence for B31: a zero says 'you have none' and a dash says 'we could not look', and a reader who took the first for the second would re-download a library they still have.
  ///
  /// In en, this message translates to:
  /// **'—'**
  String get aboutDataCountUnavailable;

  ///
  ///
  /// In en, this message translates to:
  /// **'Downloaded chapters'**
  String get aboutDataDownloaded;

  /// E11, in full and unhedged. This app has no backup (ADR-010), so the disclosure belongs on the page that shows what would be lost — and it names the exact operation that does NOT lose it, because a disclosure that only lists risks reads as an apology.
  ///
  /// In en, this message translates to:
  /// **'Nothing here is backed up anywhere. If you uninstall Lumen Tale or lose this phone, all three numbers go to zero and no copy exists. Installing a new version over this one does not touch them — that is the only guarantee this app makes about your data.'**
  String get aboutDataE11;

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
  /// **'Reading positions'**
  String get aboutDataPositions;

  /// B34 + C3 + C9: the app IS the file. 'There is no app store' is not a limitation to apologise for — it is why there is no account and no server holding anything.
  ///
  /// In en, this message translates to:
  /// **'This app runs on Android phones only. A new build is produced every time a change is merged, and you install it from the file by hand. There is no app store and no store account.'**
  String get aboutDeliveryBody;

  /// B31, and the one sentence § 4bis kept when it removed `UpdateBlock`. It is the only guarantee this app makes about the reader's data, so it is read out loud here rather than discovered after an upgrade.
  ///
  /// In en, this message translates to:
  /// **'Installing a new version keeps your library, your downloads, your reading positions and your history. Nothing is replaced or re-downloaded.'**
  String get aboutGuarantee;

  ///
  ///
  /// In en, this message translates to:
  /// **'WHAT LEAVES THIS DEVICE'**
  String get aboutPrivacyLabel;

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

  /// The falsifiable form of the privacy claim. A promise that cannot be tested by the reader is marketing; airplane mode is the test, and it takes thirty seconds.
  ///
  /// In en, this message translates to:
  /// **'Check it yourself: switch the phone to airplane mode, then open the app. Your library, your downloads and your reading positions are all there. Nothing is missing, because nothing was ever sent.'**
  String get aboutPrivacyVerify;

  /// How this build reached the reader. Three facts in one line, because a reader who installed a file by hand needs to know that is normal.
  ///
  /// In en, this message translates to:
  /// **'Android phone · built automatically · no store'**
  String get aboutProvenance;

  ///
  ///
  /// In en, this message translates to:
  /// **'Version number copied.'**
  String get aboutSnackCopied;

  /// B43: the reader can determine which version is installed. `buildName` and `buildNumber` arrive from Flutter's build-time Dart defines (`FLUTTER_BUILD_NAME` / `FLUTTER_BUILD_NUMBER`, ADR-011) — the app reads pubspec at build time and never parses a file at runtime.
  ///
  /// In en, this message translates to:
  /// **'Version {buildName} · build {buildNumber}'**
  String aboutVersion(String buildName, String buildNumber);

  /// A real failure mode: the defines are absent in a plain `flutter test` and in an IDE run. **The rest of the screen renders completely** — `Version —` is forbidden, because an em dash looks like a version and C9 requires the version to be determinable.
  ///
  /// In en, this message translates to:
  /// **'The installed version number could not be read.'**
  String get aboutVersionUnreadable;

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

  ///
  ///
  /// In en, this message translates to:
  /// **'Lumen Tale'**
  String get appTitle;

  ///
  ///
  /// In en, this message translates to:
  /// **'Browse another tag'**
  String get browseActionBrowseAnother;

  ///
  ///
  /// In en, this message translates to:
  /// **'Open library'**
  String get browseActionOpenLibrary;

  ///
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get browseActionRetry;

  /// B22: the third state, distinct from failure, and available only where the site supplies its own signal.
  ///
  /// In en, this message translates to:
  /// **'This site has nothing to show here.'**
  String get browseEmpty;

  ///
  ///
  /// In en, this message translates to:
  /// **'No source is available yet.'**
  String get browseEmptyBody;

  ///
  ///
  /// In en, this message translates to:
  /// **'{source} publishes no novel under that tag. Try another tag.'**
  String browseEmptyTagBody(Object source);

  /// ⚠️ **The tag is echoed back**, because a reader who has forgotten what they tapped needs to be told — and an empty-state sentence that does not name the tag could belong to any screen.
  ///
  /// In en, this message translates to:
  /// **'Nothing tagged {tag}'**
  String browseEmptyTagTitle(Object tag);

  ///
  ///
  /// In en, this message translates to:
  /// **'That novel is no longer on the site'**
  String get browseFailureItemRemoved;

  ///
  ///
  /// In en, this message translates to:
  /// **'The site\'s layout changed'**
  String get browseFailureLayoutChanged;

  ///
  ///
  /// In en, this message translates to:
  /// **'No connection'**
  String get browseFailureNoConnection;

  ///
  ///
  /// In en, this message translates to:
  /// **'The page could not be read'**
  String get browseFailureParse;

  /// ⚠️ **The site's own rate limit is named, not "error".** `17-security.md` rule 6 honours `Retry-After` rather than guessing, and a reader who is told the site asked us to slow down waits; one told "error" presses retry and makes it worse.
  ///
  /// In en, this message translates to:
  /// **'The site asked us to slow down'**
  String get browseFailureRateLimited;

  ///
  ///
  /// In en, this message translates to:
  /// **'The site is unavailable'**
  String get browseFailureUnavailable;

  /// ⚠️ **Not "no connection".** `CauseUnknown` means the app cannot read its own record; it does not mean the phone is offline, and a reader sent to check a setting that is already correct learns to distrust every error this app shows.
  ///
  /// In en, this message translates to:
  /// **'The app cannot read its own record of this failure'**
  String get browseFailureUnknownCause;

  ///
  ///
  /// In en, this message translates to:
  /// **'That is everything this tag publishes'**
  String get browseFooterEnd;

  ///
  ///
  /// In en, this message translates to:
  /// **'Loading more…'**
  String get browseFooterLoadingMore;

  /// ⚠️ **`Your library is unaffected`**, and it is not reassurance for its own sake: SC-6 exists because a site that cannot be read looks like a broken app, and the reader's first fear is their library.
  ///
  /// In en, this message translates to:
  /// **'{source} could not be reached. Your library is unaffected.'**
  String browseNoConnectionBody(Object source);

  ///
  ///
  /// In en, this message translates to:
  /// **'No connection'**
  String get browseNoConnectionTitle;

  /// Shown only when the source declares `supportsSearch`; the field is **absent** otherwise, never disabled.
  ///
  /// In en, this message translates to:
  /// **'Search this site'**
  String get browseSearchHint;

  /// ⚠️ **The query is quoted AND the site is named.** The site's own marker is the reason this state exists at all, and a reader needs to see what they asked for before they decide the site is at fault.
  ///
  /// In en, this message translates to:
  /// **'Searching {source} for \"{query}\" returned nothing.'**
  String browseSiteSaidNothingBody(Object query, Object source);

  ///
  ///
  /// In en, this message translates to:
  /// **'The site says it has nothing'**
  String get browseSiteSaidNothingTitle;

  /// ⚠️ **Two sentences a reader needs and cannot guess.** `Nothing is wrong with your library` comes first because the failure looks like a bug in the app, and `nothing was downloaded` because the fear is that a check ate their downloads. This is SC-6's only surface.
  ///
  /// In en, this message translates to:
  /// **'The page loaded, but the part that lists novels was not on it. Nothing is wrong with your library, and nothing was downloaded.'**
  String get browseSourceUnavailableBody;

  ///
  ///
  /// In en, this message translates to:
  /// **'{source} could not be read'**
  String browseSourceUnavailableTitle(Object source);

  /// Almost never displayed; it exists so the mapping is exhaustive and testable.
  ///
  /// In en, this message translates to:
  /// **'Read successfully.'**
  String get browseSucceeded;

  ///
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get browseTileAdd;

  ///
  ///
  /// In en, this message translates to:
  /// **'In your library'**
  String get browseTileKept;

  ///
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get browseTileOpen;

  ///
  ///
  /// In en, this message translates to:
  /// **'Browse'**
  String get browseTitle;

  ///
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get causeActionBack;

  ///
  ///
  /// In en, this message translates to:
  /// **'Browse another site'**
  String get causeActionBrowseOther;

  ///
  ///
  /// In en, this message translates to:
  /// **'Copy this'**
  String get causeActionCopyThis;

  ///
  ///
  /// In en, this message translates to:
  /// **'Open library'**
  String get causeActionOpenLibrary;

  ///
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get causeActionTryAgain;

  ///
  ///
  /// In en, this message translates to:
  /// **'The site says so in its own words. Your saved copy is untouched.'**
  String get causeContentRemovedBody;

  ///
  ///
  /// In en, this message translates to:
  /// **'REMOVED FROM THE SOURCE'**
  String get causeContentRemovedKicker;

  /// ⚠️ **The caption that replaces the button.** There is no retry here and a greyed-out one would tell a reader the app is considering an action it will not take. The words say why.
  ///
  /// In en, this message translates to:
  /// **'There is nothing to try again here.'**
  String get causeContentRemovedNoRetry;

  ///
  ///
  /// In en, this message translates to:
  /// **'This is no longer on {source}'**
  String causeContentRemovedTitle(Object source);

  ///
  ///
  /// In en, this message translates to:
  /// **'What happened'**
  String get causeEvidenceHeading;

  /// ⚠️ **"A fault in the copy this app HAS of {source} — not in {source}".** E8's whole point: the reader did not break anything and the site did not break anything. A message that says "{source} is broken" transfers the fault to the site, which is the wrong party and the one the reader cannot report to.
  ///
  /// In en, this message translates to:
  /// **'This is a fault in the copy this app has of {source} — not in {source}, and nothing is to do with how you use it. {retryNote}'**
  String causeLayoutChangedBody(Object retryNote, Object source);

  /// ⚠️ **A sentence the reader can read ALOUD**, which is C12: the reader is often on a phone they cannot type on, and "the pages of X have changed" is something a person can act on while "HTTP 200" is not.
  ///
  /// In en, this message translates to:
  /// **'Say: \"the pages of {source} have changed and the app can no longer read them.\"'**
  String causeLayoutChangedDictation(Object source);

  ///
  ///
  /// In en, this message translates to:
  /// **'THE PAGES OF THIS SITE HAVE CHANGED'**
  String get causeLayoutChangedKicker;

  /// ⚠️ **Said BEFORE the button, and it hedges honestly.** A site mid-deployment is a temporary state, and "sometimes it resolves on its own. Rarely." is a sentence that sets the expectation a retry needs to be fair.
  ///
  /// In en, this message translates to:
  /// **'Sometimes it resolves on its own. Rarely.'**
  String get causeLayoutChangedRetryNote;

  ///
  ///
  /// In en, this message translates to:
  /// **'The pages of this site have changed'**
  String get causeLayoutChangedTitle;

  ///
  ///
  /// In en, this message translates to:
  /// **'Nothing was lost. Your library and your downloaded chapters are exactly as they were.'**
  String get causeNoConnectionBody;

  ///
  ///
  /// In en, this message translates to:
  /// **'NO CONNECTION'**
  String get causeNoConnectionKicker;

  ///
  ///
  /// In en, this message translates to:
  /// **'No connection to {host}'**
  String causeNoConnectionTitle(Object host);

  ///
  ///
  /// In en, this message translates to:
  /// **'The site refused or is down. Nothing about your library was touched.'**
  String get causeSiteUnavailableBody;

  ///
  ///
  /// In en, this message translates to:
  /// **'THE SITE IS NOT ANSWERING'**
  String get causeSiteUnavailableKicker;

  ///
  ///
  /// In en, this message translates to:
  /// **'{source} is not answering'**
  String causeSiteUnavailableTitle(Object source);

  /// ⚠️ **"It will not guess", stated as a virtue.** This is the only screen that admits the app does not know, and saying so plainly is what stops a reader assuming the app knows and is being coy.
  ///
  /// In en, this message translates to:
  /// **'It kept a record it can no longer read, so it will not guess. The app will not invent a diagnosis.'**
  String get causeUnreadableRecordBody;

  ///
  ///
  /// In en, this message translates to:
  /// **'THIS SITE COULD NOT BE READ'**
  String get causeUnreadableRecordKicker;

  ///
  ///
  /// In en, this message translates to:
  /// **'This app cannot say what happened'**
  String get causeUnreadableRecordTitle;

  /// Number of chapters available for a novel.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No chapters} =1{1 chapter} other{{count} chapters}}'**
  String chapterCount(int count);

  ///
  ///
  /// In en, this message translates to:
  /// **'{count} other chapters'**
  String chapterCountPlural(Object count);

  ///
  ///
  /// In en, this message translates to:
  /// **'1 other chapter'**
  String get chapterCountSingular;

  ///
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get chapterListActionBack;

  ///
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get chapterListActionRetry;

  /// B12 — slot 1 while the novel is NOT in the library. The only path into the library from this screen.
  ///
  /// In en, this message translates to:
  /// **'Add to library'**
  String get chapterListAddToLibrary;

  /// B12 — slot 1 when the novel is in the library and a position exists.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get chapterListContinue;

  /// B12/B10 — what a screen reader announces. The visible label is the word 'Continue' alone, which tells a sighted reader where the tap goes and a blind reader nothing; this names the chapter and how far into it the position is.
  ///
  /// In en, this message translates to:
  /// **'Continue, {chapter}, {percent} through this chapter'**
  String chapterListContinueSemantics(String chapter, int percent);

  /// B18 — slot 2 in its idle state. Opens the bulk download sheet, which is 5-1's queue behind a surface this slice renders.
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get chapterListDownloadAction;

  ///
  ///
  /// In en, this message translates to:
  /// **'Download all'**
  String get chapterListDownloadAll;

  /// ⚠️ **"The site said so itself."** This is the ONLY place in the app where an empty result is a real answer, and the sentence names the site as the source of the claim — otherwise a reader compares it with an unrelated empty tag and concludes the app is broken.
  ///
  /// In en, this message translates to:
  /// **'The site said so itself. This is what it publishes for this novel, and it is not an error.'**
  String get chapterListEmptyAtSourceBody;

  ///
  ///
  /// In en, this message translates to:
  /// **'{source} publishes no chapters'**
  String chapterListEmptyAtSourceTitle(Object source);

  ///
  ///
  /// In en, this message translates to:
  /// **'{count} chapters on {source}'**
  String chapterListHeaderAtSource(Object count, Object source);

  ///
  ///
  /// In en, this message translates to:
  /// **'{count} chapters'**
  String chapterListHeaderCount(Object count);

  ///
  ///
  /// In en, this message translates to:
  /// **'Go to the current chapter'**
  String get chapterListJumpToCurrent;

  ///
  ///
  /// In en, this message translates to:
  /// **'Load the chapter list'**
  String get chapterListLoadAction;

  ///
  ///
  /// In en, this message translates to:
  /// **'This app has never fetched the chapters of this novel. Nothing has been stored, and nothing was lost.'**
  String get chapterListLoadExplainer;

  ///
  ///
  /// In en, this message translates to:
  /// **'Mark all as read'**
  String get chapterListMarkAllRead;

  /// B13 — the confirmation for slot 3. It NAMES THE COUNT in the title, because a title is what a reader reads first and 'are you sure?' does not say what is about to change.
  ///
  /// In en, this message translates to:
  /// **'Mark the {count} chapters you have not opened as read?'**
  String chapterListMarkAllReadConfirm(int count);

  /// ⚠️ **"Your progress has NOT been deleted."** An invariant a reader cannot see is an invariant they learn to distrust. Saying the app has not touched their progress is what stops them re-adding the novel to 'fix' it.
  ///
  /// In en, this message translates to:
  /// **'A chapter you have read is no longer in the list {source} publishes. The app has not deleted your progress.'**
  String chapterListMarkedReadFailedBody(Object source);

  ///
  ///
  /// In en, this message translates to:
  /// **'The app\'s records disagree'**
  String get chapterListMarkedReadFailedTitle;

  /// ⚠️ **It says what loading DOES before offering it.** B12's whole point is that a list nobody asked for is not an empty list, and a reader who sees an empty area and one button cannot tell whether the button will create something or reveal something. This sentence says: it asks the site, and it stores.
  ///
  /// In en, this message translates to:
  /// **'This novel is in your library, but its chapter list has not been fetched yet. Loading it asks {source} for the list and stores it on this phone.'**
  String chapterListNeverLoadedBody(Object source);

  ///
  ///
  /// In en, this message translates to:
  /// **'The chapters were never loaded'**
  String get chapterListNeverLoadedTitle;

  ///
  ///
  /// In en, this message translates to:
  /// **'The chapter list has never been fetched, and {source} cannot be reached right now. Nothing about your library is affected.'**
  String chapterListNoConnectionBody(Object source);

  ///
  ///
  /// In en, this message translates to:
  /// **'No connection'**
  String get chapterListNoConnectionTitle;

  /// B13 — slot 3 when every chapter has been opened. DISABLED, never absent: an action row that reflows when a counter reaches zero moves the control under the reader's thumb.
  ///
  /// In en, this message translates to:
  /// **'Nothing unopened'**
  String get chapterListNothingUnopened;

  /// B12 — slot 1 when the novel IS in the library and there is no reading position.
  ///
  /// In en, this message translates to:
  /// **'Read from the start'**
  String get chapterListReadFromStart;

  ///
  ///
  /// In en, this message translates to:
  /// **'This download needs about {bytes} and there is not that much room. Nothing was queued.'**
  String chapterListSpaceRefusedBody(Object bytes);

  ///
  ///
  /// In en, this message translates to:
  /// **'Not enough space'**
  String get chapterListSpaceRefusedTitle;

  /// ⚠️ **"The app has NOT done that", stated explicitly.** This is the only state where loading again would be *destructive*, and a screen that offers the button without saying so would quietly replace a copy the reader cannot read with one they can — which loses the unread marks along with it.
  ///
  /// In en, this message translates to:
  /// **'The chapter list is stored on this phone, and the app can no longer read it. Loading it again from {source} would replace it, so the app has not done that.'**
  String chapterListStoredUnreadableBody(Object source);

  ///
  ///
  /// In en, this message translates to:
  /// **'This app cannot read its own copy'**
  String get chapterListStoredUnreadableTitle;

  ///
  ///
  /// In en, this message translates to:
  /// **'{displayed} of {total} chapters'**
  String chapterListTailMarker(Object displayed, Object total);

  ///
  ///
  /// In en, this message translates to:
  /// **'The page loaded and the chapter list was not on it. Your library is untouched and nothing was downloaded.'**
  String get chapterListUnreadableBody;

  ///
  ///
  /// In en, this message translates to:
  /// **'{source} could not be read'**
  String chapterListUnreadableTitle(Object source);

  /// ⚠️ **B10: shown when the site published no title at all.** Never an index, never a generated "Chapter 12" — a fabricated title is a sentence the app invented and the reader would believe.
  ///
  /// In en, this message translates to:
  /// **'Untitled'**
  String get chapterListUntitled;

  ///
  ///
  /// In en, this message translates to:
  /// **'Downloaded'**
  String get chapterTileDownloaded;

  ///
  ///
  /// In en, this message translates to:
  /// **'Not downloaded'**
  String get chapterTileNotDownloaded;

  ///
  ///
  /// In en, this message translates to:
  /// **'Unread'**
  String get chapterTileUnread;

  ///
  ///
  /// In en, this message translates to:
  /// **'Checking, {done} of {total} novels'**
  String checkActionSemantics(int done, int total);

  ///
  ///
  /// In en, this message translates to:
  /// **'Stop the check'**
  String get checkCancelAction;

  /// Exists so the mapping is complete; 13-error-handling.md rule 7 means cancelled, not failed.
  ///
  /// In en, this message translates to:
  /// **'Check cancelled.'**
  String get checkCancelled;

  ///
  ///
  /// In en, this message translates to:
  /// **'Check cancelled · your library is unchanged'**
  String get checkCancelledByReader;

  ///
  ///
  /// In en, this message translates to:
  /// **'Checked {total} novels · {discovered} you had not opened'**
  String checkDiscovered(int total, int discovered);

  /// ⚠️ **NOT 'nothing is new'.** The distinction B49 is about: this sentence may only be said when the app actually looked. `libraryTileUnopened`'s `=0` arm says 'No new chapters' for a single novel, and it is allowed there because that row carries the novel's own verification chip beside it.
  ///
  /// In en, this message translates to:
  /// **'Checked {total} novels · nothing you had not opened'**
  String checkDiscoveredNothing(int total);

  /// ⚠️ **Never 'cancelled'.** `StopReason.systemIgnoredCancelledByApp` means the work **finished**: the reader now holds results they did not ask for, and telling them 'cancelled' would make them look for changes that are already saved.
  ///
  /// In en, this message translates to:
  /// **'Check finished after you cancelled it.'**
  String get checkFinishedAfterCancel;

  ///
  ///
  /// In en, this message translates to:
  /// **'Checking needs a connection.'**
  String get checkNeedsConnection;

  ///
  ///
  /// In en, this message translates to:
  /// **'Library checks'**
  String get checkNotificationChannelName;

  /// B37 says *visible*, not *blocking* — so a denied permission must NOT stop the check. The line therefore names what the reader loses (the notification) and not the state of a permission they cannot see.
  ///
  /// In en, this message translates to:
  /// **'The check will run, but Android will not show its notification: nothing will tell you when it finishes.'**
  String get checkNotificationPermissionWarning;

  ///
  ///
  /// In en, this message translates to:
  /// **'Open notification settings'**
  String get checkNotificationSettingsAction;

  ///
  ///
  /// In en, this message translates to:
  /// **'Checking your library'**
  String get checkNotificationTitle;

  ///
  ///
  /// In en, this message translates to:
  /// **'Check for new chapters'**
  String get checkNowAction;

  ///
  ///
  /// In en, this message translates to:
  /// **'Checking {done} of {total} novels'**
  String checkProgress(int done, int total);

  /// ⚠️ **THE SENTENCE `6-10`'s NOTIFICATION AND `6-4`'s STATUS LINE SHARE.** B39's counter and B38's promise in one clause, and one key rather than two: a notification that says 'checking 7 of 23' and a status line that says 'checking 7 of 23 · nothing is downloaded' are two claims about one run.
  ///
  /// In en, this message translates to:
  /// **'Checking {done} of {total} novels · nothing is downloaded'**
  String checkProgressNothingDownloaded(int done, int total);

  ///
  ///
  /// In en, this message translates to:
  /// **'The check needs to be started again from here — the phone closed the job.'**
  String get checkQueuedNotice;

  ///
  ///
  /// In en, this message translates to:
  /// **'Check stopped — the phone put the app to sleep. Try again.'**
  String get checkStoppedAppStandby;

  ///
  ///
  /// In en, this message translates to:
  /// **'Check stopped — Android paused it. Tap check to finish.'**
  String get checkStoppedBackgroundRestriction;

  ///
  ///
  /// In en, this message translates to:
  /// **'Check cancelled · your library is unchanged'**
  String get checkStoppedCancelledByApp;

  /// Same French sentence as `checkStoppedAppStandby` **on purpose**: Doze and App Standby are one thing to a reader — the phone put the app to sleep — and two different sentences for one cause is two truths about one phone's state.
  ///
  /// In en, this message translates to:
  /// **'Check stopped — the phone put the app to sleep. Try again.'**
  String get checkStoppedDeviceIdle;

  ///
  ///
  /// In en, this message translates to:
  /// **'Check stopped — the phone is saving power. Try again.'**
  String get checkStoppedDeviceState;

  ///
  ///
  /// In en, this message translates to:
  /// **'Check stopped — the phone ran out of memory for it. Try again.'**
  String get checkStoppedGpuLimit;

  ///
  ///
  /// In en, this message translates to:
  /// **'Check stopped — Android gave the phone to something else.'**
  String get checkStoppedPreempt;

  ///
  ///
  /// In en, this message translates to:
  /// **'Check finished after you cancelled it.'**
  String get checkStoppedSystemIgnoredCancel;

  ///
  ///
  /// In en, this message translates to:
  /// **'Check took longer than Android allows and was stopped. Try again.'**
  String get checkStoppedTimeout;

  ///
  ///
  /// In en, this message translates to:
  /// **'Check stopped — Android did not say why. Tap check to finish.'**
  String get checkStoppedUnknown;

  ///
  ///
  /// In en, this message translates to:
  /// **'All {total} novels checked · none skipped.'**
  String checkTerminalComplete(int total);

  ///
  ///
  /// In en, this message translates to:
  /// **'Check stopped at {done} of {total} novels.'**
  String checkTerminalInterrupted(int done, int total);

  /// B22 in one line: the failure count is **beside** the success count and never inside it. 'Checked 23 of 23 novels' when four sites could not be read is the exact presentation B22 exists to forbid.
  ///
  /// In en, this message translates to:
  /// **'Checked {checked} of {total} novels · {failed} could not be checked.'**
  String checkTerminalWithFailures(int checked, int total, int failed);

  ///
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get commonBack;

  ///
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get commonCancel;

  ///
  ///
  /// In en, this message translates to:
  /// **'The operation could not be completed.'**
  String get commonErrorBody;

  ///
  ///
  /// In en, this message translates to:
  /// **'Something went wrong'**
  String get commonErrorTitle;

  ///
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get commonOk;

  ///
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get commonRetry;

  /// Accessibility label for a novel cover thumbnail.
  ///
  /// In en, this message translates to:
  /// **'Cover of {title}'**
  String coverSemanticsLabel(String title);

  ///
  ///
  /// In en, this message translates to:
  /// **'This chapter\'s text will be erased from this phone.\nThe {siblingCount} other chapters of this novel are not touched.\n{freedBytes} will be freed.'**
  String deleteStoredBody(Object freedBytes, Object siblingCount);

  ///
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get deleteStoredConfirm;

  ///
  ///
  /// In en, this message translates to:
  /// **'Could not delete this chapter. Nothing was changed.'**
  String get deleteStoredFailedSnackbar;

  ///
  ///
  /// In en, this message translates to:
  /// **'Delete chapter {ordinal}?'**
  String deleteStoredTitle(Object ordinal);

  ///
  ///
  /// In en, this message translates to:
  /// **'Download added'**
  String get downloadAddedSnackbar;

  ///
  ///
  /// In en, this message translates to:
  /// **'This chapter is already in the queue'**
  String get downloadAlreadyQueuedSnackbar;

  ///
  ///
  /// In en, this message translates to:
  /// **'This chapter is already downloaded'**
  String get downloadAlreadyStoredSnackbar;

  ///
  ///
  /// In en, this message translates to:
  /// **'Chapter deleted — {freedBytes} freed'**
  String downloadDeletedSnackbar(Object freedBytes);

  /// B6: the word appears only after the atomic rename, so the file is whole.
  ///
  /// In en, this message translates to:
  /// **'Downloaded'**
  String get downloadDone;

  /// The in-progress state. The percentage is a number, never an estimate of the time left.
  ///
  /// In en, this message translates to:
  /// **'Downloading'**
  String get downloadDownloading;

  /// Retriable because nothing was written: the write is atomic.
  ///
  /// In en, this message translates to:
  /// **'Download interrupted. You can try it again.'**
  String get downloadFailed;

  ///
  ///
  /// In en, this message translates to:
  /// **'Downloading requires a connection.'**
  String get downloadNeedsConnectionSnackbar;

  ///
  ///
  /// In en, this message translates to:
  /// **'Not downloaded'**
  String get downloadNotDownloadedLabel;

  ///
  ///
  /// In en, this message translates to:
  /// **'This chapter was not downloaded.'**
  String get downloadNotStoredSnackbar;

  /// One of the four DownloadState values. B37: the queue is visible and cancellable before the first byte.
  ///
  /// In en, this message translates to:
  /// **'Queued for download'**
  String get downloadQueued;

  ///
  ///
  /// In en, this message translates to:
  /// **'Delete a downloaded chapter, then try again.'**
  String get downloadSpaceRefusedAction;

  ///
  ///
  /// In en, this message translates to:
  /// **'This download needs {requiredBytes}, and this phone has {freeBytes} free.'**
  String downloadSpaceRefusedBody(Object freeBytes, Object requiredBytes);

  ///
  ///
  /// In en, this message translates to:
  /// **'The download could not be added. Nothing was changed.'**
  String get downloadWriteFailedSnackbar;

  /// B48: an uncertain count says it is uncertain; it is never estimated.
  ///
  /// In en, this message translates to:
  /// **'That count could not be computed.'**
  String get errorCountUnavailable;

  /// B46: reading position is not involved, and the sentence must not let the reader think it is.
  ///
  /// In en, this message translates to:
  /// **'History could not be cleared.'**
  String get errorHistoryClear;

  /// E9. One item vanished; the sentence says so, or the reader thinks data was lost.
  ///
  /// In en, this message translates to:
  /// **'This novel is no longer on the site. The rest of your library is untouched.'**
  String get errorItemRemovedAtSource;

  /// E5. The sentence says what stays usable, not only what failed.
  ///
  /// In en, this message translates to:
  /// **'No connection. Your downloaded chapters stay readable.'**
  String get errorNoConnection;

  /// C12. The action is report, because nothing can repair a failed conversion.
  ///
  /// In en, this message translates to:
  /// **'A file for this novel could not be read. Please report it to whoever maintains this app.'**
  String get errorParseFailed;

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

  /// A startup failure, therefore never a screen state. See the comment on main(). ⚠️ `6-7` § 3.2 rule 2: EVERY failure sentence names what survived, and in a product with no backup (ADR-010) a sentence that names nothing reads as data loss. This one says the library, the downloads and the reading positions are stored separately, which is the fact that makes it survivable. § 10.16 then requires it to be a BLOCK rather than a one-line banner at 200 % type — so the second clause is load-bearing twice.
  ///
  /// In en, this message translates to:
  /// **'Your settings could not be read from this phone. Your library, downloads and reading positions are untouched.'**
  String get errorSettingsLoad;

  /// The control snaps back and says why: showing a value it could not store is worse than a visible failure.
  ///
  /// In en, this message translates to:
  /// **'This setting could not be saved. It will keep its previous value.'**
  String get errorSettingsWrite;

  /// B22, and the load-bearing half of it: 'not the same as a site with no chapters'. 'Your other sources': one site failing is not the app failing. ⚠️ The distinction B22 exists for is between 'the site answered and had nothing' and 'the site did not answer'; a sentence that only said 'unavailable' would let a reader conclude their novel has no chapters.
  ///
  /// In en, this message translates to:
  /// **'This site could not be read. That is not the same as a site with no chapters. Your other sources work normally.'**
  String get errorSiteUnreadable;

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

  /// C8. The only cause whose sentence contains an action that actually works.
  ///
  /// In en, this message translates to:
  /// **'Storage is full. Free some space, then try again.'**
  String get errorStorageFull;

  /// Both empty-no-data states say WHAT SURVIVED. An empty list after a destructive action that says nothing is the moment a reader goes looking for what else just disappeared.
  ///
  /// In en, this message translates to:
  /// **'Your reading positions were kept.'**
  String get historyAgedOutBody;

  /// Empty - no data (b). Distinct from historyClearedTitle because nobody did this on purpose.
  ///
  /// In en, this message translates to:
  /// **'Everything older than one year was dropped'**
  String get historyAgedOutTitle;

  /// The only destructive action on the most read-only screen in the app, and it says exactly what it clears. Never 'OK', never 'Delete'.
  ///
  /// In en, this message translates to:
  /// **'Clear history'**
  String get historyClearAction;

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

  /// A question, not a statement. 'Clear history?' lets the reader cancel without reading the body.
  ///
  /// In en, this message translates to:
  /// **'Clear history?'**
  String get historyClearDialogTitle;

  /// B46 said out loud, on the screen where the fear lives. Repeated in the clear confirmation, in this state, and in the store-failure sentence - four times, because it is the thing a reader on a device with no backup is actually afraid of.
  ///
  /// In en, this message translates to:
  /// **'Your library, your downloads and every remembered position were kept.'**
  String get historyClearedBody;

  /// Empty - no data (a). history.md § 4 splits this state in two because being cleared BY THE READER and being AGED OUT are different events with different emotional weight.
  ///
  /// In en, this message translates to:
  /// **'History cleared'**
  String get historyClearedTitle;

  /// Every older day header. `{date}` arrives ALREADY localised from MaterialLocalizations.formatMediumDate - this key is a hole for a platform-formatted date, not a sentence, which is why the value is the same in both files.
  ///
  /// In en, this message translates to:
  /// **'{date}'**
  String historyDayOn(String date);

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

  /// Says what the screen is FOR, in the reader's terms, and states the order it will be in.
  ///
  /// In en, this message translates to:
  /// **'The chapters you open appear here, newest first.'**
  String get historyEmptyBody;

  /// US-12 distinguishes 'never opened anything' from 'opened things and then cleared them'. This is the FIRST; the second is historyClearedTitle.
  ///
  /// In en, this message translates to:
  /// **'Nothing read yet'**
  String get historyEmptyTitle;

  /// Hours, same plural rule. There is deliberately NO days-ago key: past yesterday the DAY GROUP HEADER already carries the date, and repeating it in the row would say the same thing twice on every line.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 hour ago} other{{count} hours ago}}'**
  String historyHoursAgo(int count);

  /// The row's trailing time under a minute old. Deliberately the only bucketing below an hour: a reader who opened four chapters in ten minutes sees the same word on all four, and a count that ticks upward every second would make the list move under them.
  ///
  /// In en, this message translates to:
  /// **'Just now'**
  String get historyJustNow;

  /// Unusually specific because the fear here is data loss and this app has no backup (ADR-010). Naming the three survivals by name is what stops the reader assuming the worst.
  ///
  /// In en, this message translates to:
  /// **'Your library, your downloaded chapters and every remembered reading position are unaffected.'**
  String get historyLoadErrorBody;

  /// Load error. The only failure this screen can have is its own local store - nothing on it ever needed a network (C14).
  ///
  /// In en, this message translates to:
  /// **'Your history could not be read'**
  String get historyLoadErrorTitle;

  /// Accessibility label while the list loads. Eight skeletons, no cover - the `history` variant of NovelRow declares no cover slot, and a loading state that shows one promises an image the filled rows will not have.
  ///
  /// In en, this message translates to:
  /// **'Loading history'**
  String get historyLoadingTitle;

  /// Minutes, with a French plural rule (`=1` vs `other`) - French has no singular-only form and a reader watching 'Il y a 1 minutes' learns to distrust the rest of the screen.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 minute ago} other{{count} minutes ago}}'**
  String historyMinutesAgo(int count);

  /// B46 in one line.
  ///
  /// In en, this message translates to:
  /// **'Clearing it never moves a remembered reading position.'**
  String get historyNoticeBody;

  /// B47 stated on the screen where the fear lives: the list is bounded, and something else is not.
  ///
  /// In en, this message translates to:
  /// **'History is bounded by time'**
  String get historyNoticeTitle;

  /// The action that opens SettingsChoiceSheet. 'Change' rather than 'Keep for one year': the value is printed next to it, and a label repeating it would be two places to update on every window change.
  ///
  /// In en, this message translates to:
  /// **'Change'**
  String get historyRetentionChange;

  /// A row WITH this label goes somewhere - it opens the sheet. The absence of a chevron would say the value can be changed in place, which it cannot.
  ///
  /// In en, this message translates to:
  /// **'Keep history for'**
  String get historyRetentionLabel;

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

  /// B47's stated bound, at the END of the list, so a reader who scrolls to the bottom finds the limit rather than having it announced only at the top. There is no unbounded case, so this sentence is never absent: a screen that claimed a bound it was not applying is the exact failure B47 was written to avoid.
  ///
  /// In en, this message translates to:
  /// **'This is the oldest entry kept. Entries older than {window} are dropped, oldest first.'**
  String historyTerminalLine(String window);

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

  /// See historyWindowOneWeek.
  ///
  /// In en, this message translates to:
  /// **'one month'**
  String get historyWindowOneMonth;

  /// The five window names are DATA, not screen copy: HistoryRetention.cutoffFrom is computed from the enum's Duration, and this string is only what a reader reads. Two representations of one window, and a test asserts the enum has exactly these five members.
  ///
  /// In en, this message translates to:
  /// **'one week'**
  String get historyWindowOneWeek;

  /// The default window. HistoryRetention.defaultWindow is this member, and a test asserts it rather than trusting the string.
  ///
  /// In en, this message translates to:
  /// **'one year'**
  String get historyWindowOneYear;

  /// See historyWindowOneWeek.
  ///
  /// In en, this message translates to:
  /// **'three months'**
  String get historyWindowThreeMonths;

  /// The longest window the design offers. There is deliberately no sixth: design-system.md § 2.12 forbids a 'forever' option on any bounded list, because an unbounded value next to bounded ones teaches the reader the bounds are negotiable.
  ///
  /// In en, this message translates to:
  /// **'two years'**
  String get historyWindowTwoYears;

  ///
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get libraryActionCancel;

  /// ⚠️ **`It is still listed in Browse`**, because B24's submit-error state says the row is still there and nothing is optimistic. A failure that reads as "gone" teaches a reader not to trust the screen.
  ///
  /// In en, this message translates to:
  /// **'The novel could not be added. It is still listed in Browse.'**
  String get libraryAddFailed;

  ///
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get libraryAddFailedRetry;

  /// An **overline**, 11/16, 600 weight, and it is a LABEL rather than a sentence — the tile under it carries the words.
  ///
  /// In en, this message translates to:
  /// **'CONTINUE READING'**
  String get libraryContinueOverline;

  ///
  ///
  /// In en, this message translates to:
  /// **'Add a novel from Browse to start reading.'**
  String get libraryEmptyBody;

  ///
  ///
  /// In en, this message translates to:
  /// **'Browse a source'**
  String get libraryEmptyBrowseAction;

  ///
  ///
  /// In en, this message translates to:
  /// **'Your library is empty'**
  String get libraryEmptyTitle;

  ///
  ///
  /// In en, this message translates to:
  /// **'Downloaded'**
  String get libraryFacetDownloaded;

  ///
  ///
  /// In en, this message translates to:
  /// **'Show'**
  String get libraryFacetGroup;

  ///
  ///
  /// In en, this message translates to:
  /// **'Has unopened chapters'**
  String get libraryFacetHasUnopened;

  ///
  ///
  /// In en, this message translates to:
  /// **'Not downloaded'**
  String get libraryFacetNotDownloaded;

  ///
  ///
  /// In en, this message translates to:
  /// **'Site'**
  String get libraryFacetSite;

  ///
  ///
  /// In en, this message translates to:
  /// **'{count} filters on'**
  String libraryFilterCount(int count);

  ///
  ///
  /// In en, this message translates to:
  /// **'Chapters already downloaded are still on this phone and still readable.'**
  String get libraryLoadErrorBody;

  ///
  ///
  /// In en, this message translates to:
  /// **'Your library could not be read'**
  String get libraryLoadErrorTitle;

  ///
  ///
  /// In en, this message translates to:
  /// **'Clear filters'**
  String get libraryNoDataClearFilters;

  ///
  ///
  /// In en, this message translates to:
  /// **'No kept novel matches the filters'**
  String get libraryNoDataTitle;

  ///
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get libraryRemoveAction;

  /// ⚠️ **The number appears INSIDE every plural branch, and that is the bug a row caught.** With the count only in the placeholder selector and never in the branches, the sentence renders "Its downloaded chapters and your reading history stay" — no figure at all, in a dialog whose whole purpose is to quote one. B32 is a promise about what survives, and "nothing" survives it as well as 148 chapters do.
  ///
  /// In en, this message translates to:
  /// **'{title} leaves your library. Its {count, plural, =0{no downloaded chapters} =1{1 downloaded chapter} other{{count} downloaded chapters}} and your reading history stay on this phone.'**
  String libraryRemoveBody(num count, Object title);

  /// Shown after a removal, and it says **nothing was deleted**. B32 is a promise the reader should be able to see, not a rule they have to trust.
  ///
  /// In en, this message translates to:
  /// **'Nothing was deleted. The chapters are still here.'**
  String get libraryRemoveKept;

  ///
  ///
  /// In en, this message translates to:
  /// **'Remove from library?'**
  String get libraryRemoveTitle;

  ///
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get libraryRemoveUndo;

  ///
  ///
  /// In en, this message translates to:
  /// **'{title} was removed'**
  String libraryRemoved(Object title);

  ///
  ///
  /// In en, this message translates to:
  /// **'Could not check'**
  String get libraryRowCouldNotCheck;

  ///
  ///
  /// In en, this message translates to:
  /// **'All chapters downloaded'**
  String get libraryRowDownloadComplete;

  ///
  ///
  /// In en, this message translates to:
  /// **'Never checked'**
  String get libraryRowNeverChecked;

  ///
  ///
  /// In en, this message translates to:
  /// **'Stopped'**
  String get libraryRowStopped;

  ///
  ///
  /// In en, this message translates to:
  /// **'Stopped · no connection'**
  String get libraryRowStoppedConnection;

  ///
  ///
  /// In en, this message translates to:
  /// **'Stopped · storage full'**
  String get libraryRowStoppedStorage;

  /// B45 made structural rather than asserted (ADR-024: `author` and `description` are stored and unindexed), and this line is where the reader is told. A limit the app does not state is a limit a reader discovers by searching for a pen name and getting nothing.
  ///
  /// In en, this message translates to:
  /// **'Titles only — the app does not keep authors, genres or descriptions as searchable fields.'**
  String get libraryScopeLine;

  ///
  ///
  /// In en, this message translates to:
  /// **'Clear search'**
  String get librarySearchClearAction;

  ///
  ///
  /// In en, this message translates to:
  /// **'Search by title'**
  String get librarySearchHint;

  /// B22 and B19: a **local** search has no failure state, so its empty list must not borrow the vocabulary of a failed site query. 'No results' would tell a reader a source had gone unreadable when the library is simply on this phone.
  ///
  /// In en, this message translates to:
  /// **'No kept novel matches \"{query}\"'**
  String librarySearchNoMatchTitle(String query);

  ///
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No novel} =1{1 novel} other{{count} novels}}'**
  String librarySearchResults(int count);

  ///
  ///
  /// In en, this message translates to:
  /// **'Search your library by title'**
  String get librarySearchSemantics;

  ///
  ///
  /// In en, this message translates to:
  /// **'Add anyway'**
  String get librarySimilarAddAnyway;

  ///
  ///
  /// In en, this message translates to:
  /// **'\"{existing}\" on {source} has the same title as \"{incoming}\" on {incomingSource}.'**
  String librarySimilarBody(
    Object existing,
    Object incoming,
    Object incomingSource,
    Object source,
  );

  /// ⚠️ **Said BEFORE the choice, not after it.** "Add anyway" reads like a merge; this line is what makes it a second row.
  ///
  /// In en, this message translates to:
  /// **'Nothing will be merged — they stay two separate novels.'**
  String get librarySimilarExplain;

  ///
  ///
  /// In en, this message translates to:
  /// **'Open the existing one'**
  String get librarySimilarOpenExisting;

  /// ⚠️ **B40's dialog asks a question the reader can answer, so it names BOTH novels and BOTH sites.** "Is this the same novel?" is unanswerable without knowing which site published which.
  ///
  /// In en, this message translates to:
  /// **'A novel with this title is already in your library'**
  String get librarySimilarTitle;

  ///
  ///
  /// In en, this message translates to:
  /// **'Last read'**
  String get librarySortLastRead;

  ///
  ///
  /// In en, this message translates to:
  /// **'Recently added'**
  String get librarySortRecentlyAdded;

  ///
  ///
  /// In en, this message translates to:
  /// **'Site'**
  String get librarySortSite;

  ///
  ///
  /// In en, this message translates to:
  /// **'Sort and filter'**
  String get librarySortTitle;

  ///
  ///
  /// In en, this message translates to:
  /// **'Title A–Z'**
  String get librarySortTitleAz;

  ///
  ///
  /// In en, this message translates to:
  /// **'Unopened chapters'**
  String get librarySortUnopened;

  /// ⚠️ **A WORD, not a dash.** ADR-024: the author is displayed, never searched, and a site may publish none. An em dash is what a rendering fallback produces; a sentence says the library does not know, which is the actual fact.
  ///
  /// In en, this message translates to:
  /// **'Author unknown'**
  String get libraryTileAuthorMissing;

  /// **The mark's count, not the files'** (B48, ADR-022). An interrupted download has no mark, so this figure never counts a chapter the reader cannot open.
  ///
  /// In en, this message translates to:
  /// **'{downloaded} of {total} downloaded'**
  String libraryTileProgress(Object downloaded, Object total);

  ///
  ///
  /// In en, this message translates to:
  /// **'Not downloaded yet'**
  String get libraryTileUndownloaded;

  ///
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No new chapters} =1{1 new chapter} other{{count} new chapters}}'**
  String libraryTileUnopened(num count);

  /// ⚠️ **Identical in meaning to `navLibrary`, and separate anyway.** The tab label and the screen title are two surfaces, and the design gives the screen a `--text-h1` title bar. Merging them would make one string serve a 13 dp tab and a 31 dp title.
  ///
  /// In en, this message translates to:
  /// **'Library'**
  String get libraryTitle;

  ///
  ///
  /// In en, this message translates to:
  /// **'{count} chapters you have not opened'**
  String libraryUnopenedBadgeSemantics(int count);

  ///
  ///
  /// In en, this message translates to:
  /// **'Browse'**
  String get navBrowse;

  ///
  ///
  /// In en, this message translates to:
  /// **'Downloads'**
  String get navDownloads;

  ///
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get navHistory;

  ///
  ///
  /// In en, this message translates to:
  /// **'Library'**
  String get navLibrary;

  ///
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get navMore;

  ///
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get navSettings;

  ///
  ///
  /// In en, this message translates to:
  /// **'Updates'**
  String get navUpdates;

  ///
  ///
  /// In en, this message translates to:
  /// **'Novel'**
  String get novelDetailsTitle;

  /// Step 1's primary action. NOT "Get started" — § 2.1 decision 3: a button reading "Get started" in front of a second step teaches the reader that the button lied.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get onboardingButtonNext;

  /// Step 1 ONLY. `onboarding.md` § 2.1 decision 2: step 2 is the disclosure, and skipping a disclosure while showing it is a contradiction.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get onboardingButtonSkip;

  /// Step 2's only control. No Skip, no close button, no dismiss affordance of any kind.
  ///
  /// In en, this message translates to:
  /// **'Start reading'**
  String get onboardingButtonStart;

  /// B7 in full, plus B4 and B29 in one clause: "there is no account, no server, and nothing is sent anywhere". A reader who was lent this file is looking for a sign-in wall, and finding none is worth saying out loud. TWO SENTENCES IN BOTH LANGUAGES, and the count is asserted — this is not a place a compressed translation is acceptable.
  ///
  /// In en, this message translates to:
  /// **'Keep a novel here once and it opens with the connection switched off — on a train, on a plane, with no data used. Nothing is uploaded: there is no account, no server, and nothing is sent anywhere.'**
  String get onboardingStep1Body;

  /// B7, and the ONLY `--text-h1` in the app (31/38 at 700). The one thing a reader cannot guess: offline reading is announced nowhere in this product, on purpose. `onboarding.md` § 2: "A first-run screen that renders its promise in body text has already decided it is not the point of the app."
  ///
  /// In en, this message translates to:
  /// **'It reads with no signal.'**
  String get onboardingStep1Headline;

  /// B7. The app's own name, as a `--text-overline` kicker. Identical in both languages — a product name is not translated, and translating it would make step 1 say something false about which app this is.
  ///
  /// In en, this message translates to:
  /// **'LUMEN TALE'**
  String get onboardingStep1Kicker;

  /// E11. `--text-h2` 25/32 at 700 — one step below the promise, because the hierarchy is part of the argument: the screen's biggest words belong to what it is selling, and what it owes the reader is a warning.
  ///
  /// In en, this message translates to:
  /// **'There is no backup.'**
  String get onboardingStep2Headline;

  /// E11. Uppercase, `--text-overline`. Distinct from step 1's kicker on purpose: `onboarding.md` § 7 requires step position to be legible with no colour at all, so the two kickers must not be the same word.
  ///
  /// In en, this message translates to:
  /// **'BEFORE YOU START'**
  String get onboardingStep2Kicker;

  /// The step dots' only accessible name. `14-design-tokens.md` forbids colour carrying state alone, and a pair of unlabelled circles is colour carrying it alone.
  ///
  /// In en, this message translates to:
  /// **'Step {current} of {total}'**
  String onboardingStepPosition(int current, int total);

  ///
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get readerActionBack;

  ///
  ///
  /// In en, this message translates to:
  /// **'Download again'**
  String get readerActionDownloadAgain;

  ///
  ///
  /// In en, this message translates to:
  /// **'Download this chapter'**
  String get readerActionDownloadChapter;

  ///
  ///
  /// In en, this message translates to:
  /// **'Open downloads'**
  String get readerActionOpenDownloads;

  ///
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get readerActionRetry;

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

  /// Shown UNDER the disabled primary action (§ 3.5), never as a replacement for it. A disabled button with no reason is a button the reader assumes is broken.
  ///
  /// In en, this message translates to:
  /// **'Downloading needs a connection'**
  String get readerDownloadNeedsConnection;

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

  ///
  ///
  /// In en, this message translates to:
  /// **'Nothing was saved, so there is nothing to read.'**
  String get readerFileEmptyBody;

  /// ⚠️ **Distinct from 'corrupt'.** Zero bytes is the signature of an INTERRUPTED write, so the sentence is about the recording and the action is a re-download.
  ///
  /// In en, this message translates to:
  /// **'This chapter\'s recording was interrupted'**
  String get readerFileEmptyTitle;

  /// ⚠️ **Says the DOWNLOAD SUCCEEDED and the FILE is missing.** `architecture.md` § 8 names this divergence. The other phrasing — 'this chapter is unavailable' — would tell the reader the download failed, which is false, and a reader who re-downloads on that sentence is doing the right thing for the wrong reason.
  ///
  /// In en, this message translates to:
  /// **'The download succeeded. The file is what is missing.'**
  String get readerFileMissingBody;

  ///
  ///
  /// In en, this message translates to:
  /// **'This chapter had been downloaded, but its text is no longer on this phone'**
  String get readerFileMissingTitle;

  ///
  ///
  /// In en, this message translates to:
  /// **'The app does not know whether the file is intact.'**
  String get readerLoadFailedBody;

  /// ⚠️ **'Could not be opened', not 'is corrupt'.** This is the absence of a conclusion: the app could not find out which of the other states it is. Saying 'corrupt' would be a guess, and the guess would pick the wrong action.
  ///
  /// In en, this message translates to:
  /// **'This chapter could not be opened'**
  String get readerLoadFailedTitle;

  /// The constraint this screen enforces: the reader never fetches. § 3.1's 'ChapterNotStored' branch emits an intent and 3-3 executes it.
  ///
  /// In en, this message translates to:
  /// **'Only chapters already on this phone can be read here.'**
  String get readerNotStoredBody;

  /// ⚠️ **Empty-data, NOT an empty screen.** US-05: the reader must be able to SEE that 'not downloaded' differs from 'empty' and from 'failed'.
  ///
  /// In en, this message translates to:
  /// **'This chapter is not downloaded'**
  String get readerNotStoredTitle;

  ///
  ///
  /// In en, this message translates to:
  /// **'Both are needed: the chapter has to be downloaded once, and downloading needs a connection.'**
  String get readerOfflineAbsentBody;

  /// ⚠️ **BOTH facts in one sentence, and each is on its own insufficient.** 'Not downloaded' leaves the reader wondering whether the button will work; 'offline' leaves them wondering whether the chapter is theirs. B24 asks for the sentence that names both.
  ///
  /// In en, this message translates to:
  /// **'This chapter is not downloaded and there is no connection'**
  String get readerOfflineAbsentTitle;

  /// ⚠️ **One ephemeral line, on the FIRST offline display of a session only.** § 3.5 forbids a banner, a gradient and any 'OFFLINE MODE' — this is a sentence that appears once and does not persist, because a persistent badge would be the third thing competing with the prose for the reader's attention.
  ///
  /// In en, this message translates to:
  /// **'You are reading your downloads'**
  String get readerOfflineBanner;

  ///
  ///
  /// In en, this message translates to:
  /// **'The link may have been saved before the chapter was removed.'**
  String get readerRowGoneBody;

  /// ⚠️ **Not a failure.** A stale identifier is a state of the world — a deep link followed earlier, or a navigation stack restored. It gets its own render and a way back, never an ErrorState, because an ErrorState would report THIS APP as broken for a link the reader followed.
  ///
  /// In en, this message translates to:
  /// **'This chapter no longer exists in your library'**
  String get readerRowGoneTitle;

  ///
  ///
  /// In en, this message translates to:
  /// **'Text size: {name}'**
  String readerSizeButtonTooltip(String name);

  /// ⚠️ **The SPOKEN figure, and deliberately not the same string.** § 5's announcement is *"Large, 20 pixels, not selected"*; `20pt` read aloud is an abbreviation a screen reader has to guess at. One number, two renderings, two keys — a translation cannot merge them.
  ///
  /// In en, this message translates to:
  /// **'{px} pixels'**
  String readerSizePixelsSpoken(String px);

  ///
  ///
  /// In en, this message translates to:
  /// **'Text size'**
  String get readerSizeSheetTitle;

  /// ⚠️ **Its own key, never the empty string.** "Not selected" is a claim, and a label that goes silent on the four unselected steps is indistinguishable from one that failed to render.
  ///
  /// In en, this message translates to:
  /// **'not selected'**
  String get readerSizeStepNotSelected;

  /// ⚠️ **The EYE's figure.** `settings-reader.md` § 6: it is the one thing the reader can check against the phone's own font slider, so it must never truncate and never be a bare number.
  ///
  /// In en, this message translates to:
  /// **'{px}pt'**
  String readerSizeStepPoints(String px);

  /// The positive half of `readerSizeStepSemantics`. Never signalled by colour alone — `14-design-tokens.md` §Accessibility.
  ///
  /// In en, this message translates to:
  /// **'selected'**
  String get readerSizeStepSelected;

  /// One focusable node per step, announcing `{name}`, `{pixels}` and whether it is selected. ⚠️ **A single ICU sentence rather than three concatenated strings**: the order and the punctuation are the translator's, and `name, pixels, state` does not survive a language that does not use commas.
  ///
  /// In en, this message translates to:
  /// **'{name}, {pixels}, {state}'**
  String readerSizeStepSemantics(String name, String pixels, String state);

  /// ⚠️ **Names the CURRENT value, not the next one.** The button cycles, so a label naming the result ("Switch to night") would be true for one press and false for the next two — and the reader mid-chapter cannot see which.
  ///
  /// In en, this message translates to:
  /// **'Theme: {name}'**
  String readerThemeButtonTooltip(String name);

  ///
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get settingsButtonCancel;

  ///
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get settingsButtonRetry;

  ///
  ///
  /// In en, this message translates to:
  /// **'No colour filters — sepia, greyscale, inverted.'**
  String get settingsDeferredFilters;

  /// ⚠️ **The eighth, and the prose says seven.** `settings-reader.md` § 3 counts `DeferredItem × 7` while § 4.1 and § 11 both list eight absences. The copy table wins, and dropping this one would forget the font picker — the absence a reader who has used another reader is most likely to look for.
  ///
  /// In en, this message translates to:
  /// **'No font picker — the reader uses a serif, decided once. A reading face you can choose is a v2 candidate, not a v1 control.'**
  String get settingsDeferredFonts;

  ///
  ///
  /// In en, this message translates to:
  /// **'No text justification. Justified prose at this measure creates rivers, and rivers are worse than a ragged edge.'**
  String get settingsDeferredJustification;

  ///
  ///
  /// In en, this message translates to:
  /// **'No line-height control. It is held at 1.72 at every size on purpose, so the rhythm does not change when the size does.'**
  String get settingsDeferredLineHeight;

  ///
  ///
  /// In en, this message translates to:
  /// **'No reading modes — reading is one continuous scroll.'**
  String get settingsDeferredModes;

  ///
  ///
  /// In en, this message translates to:
  /// **'No orientation or rotation lock.'**
  String get settingsDeferredOrientation;

  ///
  ///
  /// In en, this message translates to:
  /// **'No paragraph spacing control — the 1.72 line-height already sets the rhythm.'**
  String get settingsDeferredParagraphSpacing;

  ///
  ///
  /// In en, this message translates to:
  /// **'No swipe or tap page-turn.'**
  String get settingsDeferredSwipe;

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

  /// ⚠️ **The count is in the TITLE**, not the body. This dialog's one job is to say how much is about to be destroyed, and a title is what a reader reads before they read anything else. `3-7`'s Loading state exists only for the COUNT this sentence waits on.
  ///
  /// In en, this message translates to:
  /// **'Clear {count} entries?'**
  String settingsDialogClearHistoryTitle(String count);

  /// The ghost link into About, and its label is the QUESTION it answers (B31's guarantee). A link labelled 'About' would compete with the row above it.
  ///
  /// In en, this message translates to:
  /// **'What survives an update'**
  String get settingsDisclosureAboutLink;

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

  /// A count that could not be obtained, and **never `0`** (B48). § 4 (Load error, declined) scopes the failure to the one row that owns it: a failed `COUNT` renders this word on its own line and disables the clear row, rather than blanking eight correct rows.
  ///
  /// In en, this message translates to:
  /// **'Count unavailable'**
  String get settingsErrorCountUnavailable;

  /// A failed write, shown **beside** the control and never by tinting it — a red control reads as 'this setting is now off' rather than 'this setting could not be saved'.
  ///
  /// In en, this message translates to:
  /// **'This setting could not be saved. Nothing was changed.'**
  String get settingsErrorWrite;

  ///
  ///
  /// In en, this message translates to:
  /// **'APP'**
  String get settingsGroupApp;

  ///
  ///
  /// In en, this message translates to:
  /// **'NOT IN THIS VERSION'**
  String get settingsGroupDeferred;

  ///
  ///
  /// In en, this message translates to:
  /// **'HISTORY'**
  String get settingsGroupHistory;

  ///
  ///
  /// In en, this message translates to:
  /// **'READING'**
  String get settingsGroupReading;

  ///
  ///
  /// In en, this message translates to:
  /// **'TEXT SIZE'**
  String get settingsGroupSize;

  ///
  ///
  /// In en, this message translates to:
  /// **'THEME'**
  String get settingsGroupTheme;

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
  /// **'Clear reading history'**
  String get settingsRowClearHistoryLabel;

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

  /// Tells the reader where the control actually is, because there isn't one here. A read-only row with no explanation reads as a disabled control.
  ///
  /// In en, this message translates to:
  /// **'Follows your phone. Change it in Android\'s language settings.'**
  String get settingsRowLanguageHint;

  /// **Read-only, and visibly so**: no chevron, no ripple, no pressed state. B28 forbids an in-app language picker — the platform owns this value and a second source of truth for it is a bug waiting to happen.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settingsRowLanguageLabel;

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
  /// **'Keep history for'**
  String get settingsRowRetentionLabel;

  ///
  ///
  /// In en, this message translates to:
  /// **'Large'**
  String get settingsSizeLg;

  ///
  ///
  /// In en, this message translates to:
  /// **'Medium'**
  String get settingsSizeMd;

  ///
  ///
  /// In en, this message translates to:
  /// **'Small'**
  String get settingsSizeSm;

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

  /// The second clause is **mandatory and is the entire success message**, because B46 makes position the thing the reader must believe survived. A generic 'History cleared' leaves the reader fearing they lost their place, which is the app's core promise (B16).
  ///
  /// In en, this message translates to:
  /// **'Reading history cleared. Your reading positions were kept.'**
  String get settingsSnackHistoryCleared;

  /// ⚠️ **Under the specimen only, and `null` when the stand-in is shown.** B44: the seed is site content displayed as published, so naming the book it came from is the only way the reader knows they are looking at their own download and not at marketing copy.
  ///
  /// In en, this message translates to:
  /// **'From \"{novel}\" · {chapter}'**
  String settingsSpecimenCredit(String novel, String chapter);

  /// B28's honest empty. It is `--text-caption`, it is ONE line, and it names the sample as a sample — a specimen that pretends to be content would be the misrepresentation § 2.1 exists to prevent.
  ///
  /// In en, this message translates to:
  /// **'You have not downloaded anything yet — this is what the reader will look like.'**
  String get settingsSpecimenEmptyNote;

  /// ⚠️ **`--color-warning`, never `--color-error`.** Nothing failed that the reader asked for: the setting saved, only the seed is unreadable. An error here reads as *the setting did not save*, which is false.
  ///
  /// In en, this message translates to:
  /// **'A chapter saved on this phone could not be read. Showing a sample instead.'**
  String get settingsSpecimenSeedFailed;

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
  /// **'Settings'**
  String get settingsTitle;

  ///
  ///
  /// In en, this message translates to:
  /// **'Try again in {seconds}s'**
  String sourceUnavailableRetryIn(Object seconds);

  /// ⚠️ **The whole reason this screen exists.** SC-6's damage is not the failure — it is a reader concluding their library is gone. The three figures are LOCAL counts (B14, B48), so they are true without a network and they are the sentence that ends the fear.
  ///
  /// In en, this message translates to:
  /// **'Your {library} novels and {downloaded} downloaded chapters are on this phone and are readable now, with or without {source}.'**
  String sourceUnavailableStillWorksBody(
    Object downloaded,
    Object library,
    Object source,
  );

  /// ⚠️ **A count of zero says "nothing was lost" rather than nothing.** The empty case and the failure case read alike otherwise, and a reader who has just seen a failure cannot tell "empty" from "gone".
  ///
  /// In en, this message translates to:
  /// **'Nothing is stored yet — and nothing was lost by this failure.'**
  String get sourceUnavailableStillWorksEmpty;

  ///
  ///
  /// In en, this message translates to:
  /// **'What still works'**
  String get sourceUnavailableStillWorksHeading;

  ///
  ///
  /// In en, this message translates to:
  /// **'The site asked us to wait {seconds}s.'**
  String sourceUnavailableWaitingForSite(Object seconds);

  ///
  ///
  /// In en, this message translates to:
  /// **'{count} B'**
  String unitBytes(Object count);

  ///
  ///
  /// In en, this message translates to:
  /// **'{count} GB'**
  String unitGigabytes(Object count);

  ///
  ///
  /// In en, this message translates to:
  /// **'{count} KB'**
  String unitKilobytes(Object count);

  ///
  ///
  /// In en, this message translates to:
  /// **'{count} MB'**
  String unitMegabytes(Object count);

  /// A warning, not an error: the app works, the phone decided.
  ///
  /// In en, this message translates to:
  /// **'Notifications are turned off in your phone\'s settings.'**
  String get warningNotifications;

  /// `downloads.md` § 9 (E18): 'The attempt count is shown, because a threshold being applied is a thing the reader deserves to know about' — and C12, because 'it failed twice' and 'it failed once' are not described the same way.
  ///
  /// In en, this message translates to:
  /// **'Tried {count} times'**
  String downloadsAttemptCount(Object count);

  /// B19's cancellation, and the only destructive control on the screen — hence the confirmation dialog rather than a button.
  ///
  /// In en, this message translates to:
  /// **'Cancel download'**
  String get downloadsCancelAction;

  /// `downloads.md` § 4 *Submit error (a)*, verbatim in substance: the ONE submission in the app whose failure must INVERT the display, because a queue shown as cancelled while it keeps writing chapters is what B19 forbids.
  ///
  /// In en, this message translates to:
  /// **'Could not cancel. The download is still running.'**
  String get downloadsCancelFailedSnackbar;

  /// B19: the reader needs to know what SURVIVED. A cancellation that reported nothing would leave them wondering whether chapter 12 was deleted.
  ///
  /// In en, this message translates to:
  /// **'Download cancelled — {kept} chapters kept.'**
  String downloadsCancelledKept(Object kept);

  /// The one action an empty state offers: the discover loop, not an explanation.
  ///
  /// In en, this message translates to:
  /// **'Browse sources'**
  String get downloadsEmptyActionBrowse;

  /// The body's sentence. `downloads.md` § 4: 'Downloaded chapters read with no signal at all' — the benefit, not the mechanism.
  ///
  /// In en, this message translates to:
  /// **'Downloaded chapters read with no signal at all. Start one from any novel\'s page.'**
  String get downloadsEmptyBody;

  /// `downloads.md` § 4 *Empty — never visited*. The body states the BENEFIT in the reader's terms, because that is the one thing a download queue is for.
  ///
  /// In en, this message translates to:
  /// **'Nothing is downloaded yet'**
  String get downloadsEmptyTitle;

  /// The failed row's chapter name — the SITE's own title (B10). `downloads.md` § 3: 'Every failed row names the chapter, not just the novel'.
  ///
  /// In en, this message translates to:
  /// **'Chapter: {name}'**
  String downloadsFailedRowTitle(Object name);

  /// `downloads.md` § 3's `COULD NOT DOWNLOAD` overline, and § 4: the section is NOT rendered at all when empty.
  ///
  /// In en, this message translates to:
  /// **'COULD NOT DOWNLOAD'**
  String get downloadsFailedSectionLabel;

  /// C8: both numbers EXACT. `downloaded` is `count(state='done')`, never 13 after a failure and never 11 after a cancellation. Declared with `placeholders` because a translated placeholder NAME would ADD a parameter rather than rename one (B28).
  ///
  /// In en, this message translates to:
  /// **'{downloaded} of {total} downloaded'**
  String downloadsHeaderCounts(Object downloaded, Object total);

  /// E7, and the reason it is the FIRST line under the title in EVERY state. `flows.md` § 4.4 calls this 'the single most likely over-promise in the product': every competing reader ships a background download service, so the default expectation is that closing the app just moves the bar somewhere invisible.
  ///
  /// In en, this message translates to:
  /// **'Downloads continue only while the app is open.'**
  String get downloadsInProcessNotice;

  /// The `· 1 in progress` half of the header. B18 makes it at most one, so the string carries the number and the row carries the chapter.
  ///
  /// In en, this message translates to:
  /// **'· {count} in progress'**
  String downloadsInProgressSuffix(Object count);

  /// The reassurance, and it is load-bearing: with no backup (ADR-010) the reader's first assumption is data loss. Nothing was deleted, and nothing can be fetched until the records can be read.
  ///
  /// In en, this message translates to:
  /// **'Nothing has been deleted. This app cannot see what it has already stored, and nothing can be fetched until it can.'**
  String get downloadsLoadErrorBody;

  /// B24: 'Any action that can fail shows an error the user can read and act on, together with a way to try again.'
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get downloadsLoadErrorRetry;

  /// `downloads.md` § 4 *Load error*: a real failure with a consequence worth stating precisely — the records could not be read, which is not the same as there being none.
  ///
  /// In en, this message translates to:
  /// **'Lumen Tale could not read its download records'**
  String get downloadsLoadErrorTitle;

  /// B19: 'Stop before the next chapter'. C11: 48dp, and no gesture — a swipe that stopped a queue would be a swipe nobody asked for.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get downloadsPauseAction;

  /// E7/B19. `--color-warning` PLUS this word PLUS an icon: `14-design-tokens.md` § Accessibility forbids a colour-only state.
  ///
  /// In en, this message translates to:
  /// **'Paused'**
  String get downloadsPausedLabel;

  /// The `DOWNLOAD QUEUE` overline. `--text-overline`, 600, letter-spaced.
  ///
  /// In en, this message translates to:
  /// **'DOWNLOAD QUEUE'**
  String get downloadsQueueSectionLabel;

  /// B21: continue FROM the chapter it stopped at, never from chapter one.
  ///
  /// In en, this message translates to:
  /// **'Resume'**
  String get downloadsResumeAction;

  /// B24/B5: 'Re-fetch that chapter alone, and only that one.' NOT a retry-everything control — one chapter's typed failure says nothing about the other 47.
  ///
  /// In en, this message translates to:
  /// **'Retry this chapter'**
  String get downloadsRetryAction;

  /// The status word while the loop is moving. Shown as a word and not only as a bar, for the same reason as Paused.
  ///
  /// In en, this message translates to:
  /// **'Downloading'**
  String get downloadsRunningLabel;

  /// `downloads.md` § 7: the determinate bar's SPOKEN value, 'Chapter 13 of 50, 41 per cent'. `14-design-tokens.md` § Accessibility and `16-i18n.md` rule 7: a semantics label is localized like any other string. A percentage inside a ring is unreadable by a screen reader and useless at 2dp — this is the alternative.
  ///
  /// In en, this message translates to:
  /// **'Chapter {position} of {total}, {percent} per cent'**
  String downloadsSemanticsChapterProgress(
    Object percent,
    Object position,
    Object total,
  );

  /// The same spoken value with NO percentage, and `downloads.md` § 8 is explicit that `0` must never stand in for one: a bar at zero that never moves is a bar that lies.
  ///
  /// In en, this message translates to:
  /// **'Chapter {position} of {total}, downloading'**
  String downloadsSemanticsProgressUndetermined(Object position, Object total);

  /// E7's state. C12: the reader must be able to say 'the downloads stopped' aloud to whoever owns the phone.
  ///
  /// In en, this message translates to:
  /// **'Stopped'**
  String get downloadsStoppedLabel;

  /// E7/E5. `downloads.md` § 4 *Offline*: the reason in WORDS, not an icon alone — C11 is a one-handed, often-glanced context at night.
  ///
  /// In en, this message translates to:
  /// **'No connection'**
  String get downloadsStoppedNoConnection;

  /// E20. `downloads.md` § 9 refuses to DISPLAY free space — the app has no honest way to read it without a platform channel it has not earned — so the honest sentence is the fact and the action, and no figure.
  ///
  /// In en, this message translates to:
  /// **'The phone is out of storage. Free up some space, then resume.'**
  String get downloadsStoppedOutOfStorage;

  /// `17-security.md` rule 6 and `5-3` § 3.2: the site sent 429 with Retry-After, and the answer is to WAIT for the time the site named — never a guessed one.
  ///
  /// In en, this message translates to:
  /// **'The site asked us to wait until {time}.'**
  String downloadsStoppedRateLimited(Object time);

  /// B22: ONE line for a broken site, not one per chapter. C12 needs the sentence to be sayable, and it names the SITE.
  ///
  /// In en, this message translates to:
  /// **'Lumen Tale could not read {source}.'**
  String downloadsStoppedSourceUnreadable(Object source);

  /// E20's ONE measured figure: what the chapter the app was writing needs. It is NOT free space, which `downloads.md` § 9 refuses to display at all — a stale number is worse than none.
  ///
  /// In en, this message translates to:
  /// **'This chapter needs {bytes}.'**
  String downloadsStorageNeeded(Object bytes);

  /// The screen's title. `downloads.md` § 3: a title bar back to /more.
  ///
  /// In en, this message translates to:
  /// **'Downloads'**
  String get downloadsTitle;

  /// E7, and the sentence that closes the trap. `downloads.md` § 4 says it goes on the line BELOW the reason, in the stopped state — the reader is most likely to wonder exactly here.
  ///
  /// In en, this message translates to:
  /// **'It will not continue on its own when the signal comes back.'**
  String get downloadsWillNotContinueOnItsOwn;

  /// The confirmation WITHOUT a chapter in flight. `{kept}` is the number that survives, and it is a count rather than a pre-built phrase so no caller can decorate it.
  ///
  /// In en, this message translates to:
  /// **'The {kept} chapters already downloaded are kept. Nothing else is fetched.'**
  String queueCancelBody(Object kept);

  /// The confirmation WITH a chapter in flight. `downloads.md` § 5: the dialog names the chapter, so the confirmation is about a specific thing — and `{name}` is the site's own title (B10), not a placeholder this app invented.
  ///
  /// In en, this message translates to:
  /// **'\'{name}\' is being downloaded. It will be discarded. The {kept} chapters already downloaded are kept.'**
  String queueCancelBodyWithChapter(Object kept, Object name);

  /// The filled button. `commonCancel` is the other one, and the pair is the whole dialogue: two exits, no dead end, no silent consent.
  ///
  /// In en, this message translates to:
  /// **'Cancel the download'**
  String get queueCancelConfirm;

  /// B19's confirmation. `downloads.md` § 7: 'Destructive actions are confirmed and named' — a generic 'Are you sure?' is a statement about nothing.
  ///
  /// In en, this message translates to:
  /// **'Cancel this download?'**
  String get queueCancelTitle;

  /// E9 for `item_removed_at_source`. The site's own answer, so the reader is not asked to retry something the site has confirmed is gone.
  ///
  /// In en, this message translates to:
  /// **'The site says this chapter has been removed.'**
  String get queueCauseItemRemovedAtSource;

  /// B24/C12 for `no_connection`: a sentence a borrowed-device reader can read aloud to the owner, and an action they can take.
  ///
  /// In en, this message translates to:
  /// **'The connection dropped while this chapter was being downloaded.'**
  String get queueCauseNoConnection;

  /// E18 for `no_real_text`, and E22's half of the bargain: a short chapter must never be mistaken for a broken one, so the sentence is about THIS chapter.
  ///
  /// In en, this message translates to:
  /// **'This chapter had no readable text on the page.'**
  String get queueCauseNoRealText;

  /// B22 for `parse_failed`: the app's own failure, named as its own. `C5` says a failure the reader cannot report is a failure nobody will fix.
  ///
  /// In en, this message translates to:
  /// **'This chapter\'s text could not be built.'**
  String get queueCauseParseFailed;

  /// B24 for `rate_limited`. `17-security.md` rule 6: the answer is to wait, never to hammer — and the sentence must not sound like the site is broken.
  ///
  /// In en, this message translates to:
  /// **'The site asked us to slow down.'**
  String get queueCauseRateLimited;

  /// E8/B22 for `source_empty`. The distinction from 'the app has nothing' is the whole point: the SITE said so itself.
  ///
  /// In en, this message translates to:
  /// **'The site published nothing for this chapter.'**
  String get queueCauseSourceEmpty;

  /// B22 for `source_layout_changed`, E4. 'this app cannot read this site any more' is a report the owner can act on; 'download failed' is not.
  ///
  /// In en, this message translates to:
  /// **'This site has changed its layout, so this app can no longer read it.'**
  String get queueCauseSourceLayoutChanged;

  /// B3 for `source_unavailable`: the novel names a site this build no longer contains, which is a statement about the app rather than about the chapter.
  ///
  /// In en, this message translates to:
  /// **'This novel\'s site is not in this version of the app.'**
  String get queueCauseSourceUnavailable;

  /// E20 for `storage_full`. NEVER a free-space figure — `downloads.md` § 9 — and never 'try again', which would send the reader round the same loop.
  ///
  /// In en, this message translates to:
  /// **'The phone ran out of storage.'**
  String get queueCauseStorageFull;

  /// The only honest sentence for an unreadable code. `queue_run_state_deriver.dart` maps one to `QueueStopReason.unknown` and this is what the reader is shown — it does not guess, and C12 accepts a true 'the app cannot say' over a plausible fiction.
  ///
  /// In en, this message translates to:
  /// **'This app cannot say what went wrong.'**
  String get queueCauseUnknown;

  /// E9's action for a chapter the site says is gone. NOT a retry — the site has confirmed the item is not coming back, so re-fetching it would fail identically. Navigation is honest: the reader can look at the novel's chapter list.
  ///
  /// In en, this message translates to:
  /// **'Open the novel'**
  String get downloadsOpenNovelAction;
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
