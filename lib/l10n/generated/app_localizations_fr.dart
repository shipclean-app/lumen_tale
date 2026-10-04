// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get appTitle => 'Lumen Tale';

  @override
  String get navLibrary => 'Bibliothèque';

  @override
  String get navBrowse => 'Parcourir';

  @override
  String get navUpdates => 'Mises à jour';

  @override
  String get navHistory => 'Historique';

  @override
  String get navMore => 'Plus';

  @override
  String get navDownloads => 'Téléchargements';

  @override
  String get navSettings => 'Paramètres';

  @override
  String get commonRetry => 'Réessayer';

  @override
  String get commonCancel => 'Annuler';

  @override
  String get commonBack => 'Retour';

  @override
  String get commonErrorTitle => 'Une erreur est survenue';

  @override
  String get commonErrorBody => 'L\'opération n\'a pas pu être terminée.';

  @override
  String get libraryEmptyTitle => 'Votre bibliothèque est vide';

  @override
  String get libraryEmptyBody =>
      'Ajoutez un roman depuis Parcourir pour commencer à lire.';

  @override
  String get browseEmptyBody => 'Aucune source n\'est encore disponible.';

  @override
  String chapterCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count chapitres',
      one: '1 chapitre',
      zero: 'Aucun chapitre',
    );
    return '$_temp0';
  }

  @override
  String coverSemanticsLabel(String title) {
    return 'Couverture de $title';
  }

  @override
  String get errorNoConnection =>
      'Pas de connexion. Vos chapitres téléchargés restent lisibles.';

  @override
  String get errorRateLimited =>
      'Le site demande de ralentir. Réessayez dans un instant.';

  @override
  String errorRateLimitedIn(int seconds) {
    return 'Le site demande de ralentir. Réessayez dans $seconds secondes.';
  }

  @override
  String get errorSourceLayoutChanged =>
      'Ce site a changé de présentation. L\'application ne peut plus le lire.';

  @override
  String get errorSourceUnavailable =>
      'Ce site ne répond pas. Réessayez plus tard.';

  @override
  String get errorItemRemovedAtSource =>
      'Ce roman n\'existe plus sur le site. Le reste de votre bibliothèque n\'est pas touché.';

  @override
  String get errorStorageFull =>
      'L\'espace de stockage est plein. Libérez de la place, puis relancez.';

  @override
  String get errorParseFailed =>
      'Un fichier de ce roman n\'a pas pu être lu. Signalez-le au responsable de l\'application.';

  @override
  String get errorSiteUnreadable =>
      'Ce site n\'a pas pu être lu. Les autres sources fonctionnent normalement.';

  @override
  String get errorSettingsLoad => 'Vos réglages n\'ont pas pu être chargés.';

  @override
  String get errorSettingsWrite =>
      'Ce réglage n\'a pas pu être enregistré. Il reprendra sa valeur précédente.';

  @override
  String get errorHistoryClear => 'L\'historique n\'a pas pu être effacé.';

  @override
  String get errorCountUnavailable => 'Ce compte n\'a pas pu être calculé.';

  @override
  String get warningNotifications =>
      'Les notifications sont désactivées dans les réglages du téléphone.';

  @override
  String get checkCancelled => 'Vérification annulée.';

  @override
  String get browseEmpty => 'Ce site n\'a rien à montrer ici.';

  @override
  String get browseSucceeded => 'Lecture réussie.';

  @override
  String get downloadQueued => 'Téléchargement en attente';

  @override
  String get downloadDownloading => 'Téléchargement en cours';

  @override
  String get downloadDone => 'Téléchargé';

  @override
  String get downloadFailed =>
      'Téléchargement interrompu. Vous pouvez le relancer.';

  @override
  String get actionFreeSpace => 'Libérer de la place';

  @override
  String get actionReportBug => 'Signaler le problème';

  @override
  String get historyTitle => 'Historique';

  @override
  String get historyUntitledChapter => 'Sans titre';

  @override
  String get historyUntitledNovel => 'Sans titre';

  @override
  String get historyLoadingTitle => 'Chargement de l\'historique';

  @override
  String get historyEmptyTitle => 'Rien de lu pour l\'instant';

  @override
  String get historyEmptyBody =>
      'Les chapitres que vous ouvrez apparaissent ici, du plus récent au plus ancien.';

  @override
  String get historyEmptyActionBrowse => 'Parcourir une source';

  @override
  String get historyEmptyActionLibrary => 'Ouvrir votre bibliothèque';

  @override
  String get historyClearedTitle => 'Historique effacé';

  @override
  String get historyClearedBody =>
      'Votre bibliothèque, vos téléchargements et toutes vos positions de lecture ont été conservés.';

  @override
  String get historyAgedOutTitle =>
      'Tout ce qui datait de plus d\'un an a été supprimé';

  @override
  String get historyAgedOutBody =>
      'Vos positions de lecture ont été conservées.';

  @override
  String get historyLoadErrorTitle => 'Votre historique n\'a pas pu être lu';

  @override
  String get historyLoadErrorBody =>
      'Votre bibliothèque, vos chapitres téléchargés et toutes vos positions de lecture ne sont pas affectés.';

  @override
  String get historyNoticeTitle => 'L\'historique est borné par le temps';

  @override
  String get historyNoticeBody =>
      'Effacer l\'historique ne déplace jamais une position de lecture retenue.';

  @override
  String get historyRetentionLabel => 'Durée de conservation';

  @override
  String get historyRetentionChange => 'Changer';

  @override
  String get historyClearAction => 'Effacer l\'historique';

  @override
  String get historyClearDialogTitle => 'Effacer l\'historique ?';

  @override
  String historyClearDialogBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count entrées seront supprimées.',
      one: 'Une entrée sera supprimée.',
      zero: 'Aucune entrée ne sera supprimée.',
    );
    return '$_temp0 Votre bibliothèque, vos téléchargements et toutes vos positions de lecture seront conservés.';
  }

  @override
  String get historyClearDialogConfirm => 'Effacer l\'historique';

  @override
  String historyTerminalLine(String window) {
    return 'Voici l\'entrée la plus ancienne conservée. Les entrées de plus de $window seront supprimées, les plus anciennes d\'abord.';
  }

  @override
  String get historySheetTitle => 'Durée de conservation';

  @override
  String historySheetWarning(String window) {
    return 'Les entrées de plus de $window seront supprimées, les plus anciennes d\'abord. Vos positions de lecture ne sont jamais affectées.';
  }

  @override
  String get historySheetWarningNone =>
      'Aucune entrée ne sera supprimée. Vos positions de lecture ne sont jamais affectées.';

  @override
  String get historySnackCleared =>
      'Historique effacé. Vos positions de lecture ont été conservées.';

  @override
  String get historySnackNotCleared => 'L\'historique n\'a pas été effacé.';

  @override
  String historySnackWindowChanged(String window) {
    return 'L\'historique est désormais conservé $window.';
  }

  @override
  String get historyWindowOneWeek => 'une semaine';

  @override
  String get historyWindowOneMonth => 'un mois';

  @override
  String get historyWindowThreeMonths => 'trois mois';

  @override
  String get historyWindowOneYear => 'un an';

  @override
  String get historyWindowTwoYears => 'deux ans';

  @override
  String get historyDayToday => 'Aujourd\'hui';

  @override
  String get historyDayYesterday => 'Hier';

  @override
  String historyDayOn(String date) {
    return '$date';
  }

  @override
  String get historyJustNow => 'À l\'instant';

  @override
  String historyMinutesAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Il y a $count minutes',
      one: 'Il y a 1 minute',
    );
    return '$_temp0';
  }

  @override
  String historyHoursAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Il y a $count heures',
      one: 'Il y a 1 heure',
    );
    return '$_temp0';
  }

  @override
  String aboutVersion(String buildName, String buildNumber) {
    return 'Version $buildName · build $buildNumber';
  }

  @override
  String get aboutProvenance =>
      'Téléphone Android · compilé automatiquement · aucun magasin';

  @override
  String get aboutCopyVersion => 'Copier le numéro de version';

  @override
  String get aboutVersionUnreadable =>
      'Le numéro de version installé n\'a pas pu être lu.';

  @override
  String get aboutSnackCopied => 'Numéro de version copié.';

  @override
  String get aboutGuarantee =>
      'L\'installation d\'une nouvelle version conserve votre bibliothèque, vos téléchargements, vos positions de lecture et votre historique. Rien n\'est remplacé ni retéléchargé.';

  @override
  String get aboutDataLabel => 'VOS DONNÉES SUR CE TÉLÉPHONE';

  @override
  String get aboutDataLibrary => 'Bibliothèque';

  @override
  String get aboutDataDownloaded => 'Chapitres téléchargés';

  @override
  String get aboutDataPositions => 'Positions de lecture';

  @override
  String get aboutDataCountUnavailable => '—';

  @override
  String get aboutDataE11 =>
      'Rien ici n\'est sauvegardé nulle part. Si vous désinstallez Lumen Tale ou perdez ce téléphone, ces trois nombres tombent à zéro et aucune copie n\'existe. Installer une nouvelle version par-dessus celle-ci n\'y touche pas : c\'est la seule garantie que cette application fait sur vos données.';

  @override
  String get aboutPrivacyLabel => 'CE QUI QUITTE CE TÉLÉPHONE';

  @override
  String get aboutPrivacySent1 =>
      'La page d\'un chapitre — mais seulement après que vous l\'avez demandée.';

  @override
  String get aboutPrivacySent2 =>
      'Une requête pour savoir si une nouvelle version existe — uniquement si vous touchez « Rechercher une nouvelle version ».';

  @override
  String get aboutPrivacyNever1 => 'Votre bibliothèque';

  @override
  String get aboutPrivacyNever2 => 'Vos positions de lecture';

  @override
  String get aboutPrivacyNever3 => 'Votre historique';

  @override
  String get aboutPrivacyNever4 => 'Vos journaux d\'erreurs';

  @override
  String get aboutPrivacyNever5 => 'Rapports de plantage';

  @override
  String get aboutPrivacyNever6 => 'Suivi d\'audience';

  @override
  String get aboutPrivacyNever7 => 'Un identifiant d\'appareil';

  @override
  String get aboutPrivacyVerify =>
      'Vérifiez vous-même : passez le téléphone en mode avion, puis ouvrez l\'application. Votre bibliothèque, vos téléchargements et vos positions de lecture sont tous là. Il ne manque rien, parce que rien n\'a jamais été envoyé.';

  @override
  String get aboutDeliveryBody =>
      'Cette application fonctionne uniquement sur les téléphones Android. Une nouvelle version est produite à chaque modification fusionnée, et vous l\'installez depuis le fichier, à la main. Il n\'y a ni magasin d\'applications ni compte de magasin.';

  @override
  String get settingsTitle => 'Réglages';

  @override
  String get settingsLanguageEnglish => 'English';

  @override
  String get settingsLanguageFrench => 'Français';

  @override
  String get settingsGroupReading => 'LECTURE';

  @override
  String get settingsGroupHistory => 'HISTORIQUE';

  @override
  String get settingsGroupApp => 'APPLICATION';

  @override
  String get settingsRowAppearanceLabel => 'Apparence du lecteur';

  @override
  String settingsRowAppearanceValue(String theme, String size, String pt) {
    return '$theme · $size ($pt pt)';
  }

  @override
  String get settingsThemeDay => 'Jour';

  @override
  String get settingsThemeNight => 'Nuit';

  @override
  String get settingsThemeSystem => 'Suivre le téléphone';

  @override
  String get settingsSizeSm => 'Petit';

  @override
  String get settingsSizeMd => 'Moyen';

  @override
  String get settingsSizeLg => 'Grand';

  @override
  String get settingsSizeXl => 'Plus grand';

  @override
  String get settingsSizeXxl => 'Le plus grand';

  @override
  String get settingsRowHistoryLabel => 'Historique de lecture';

  @override
  String settingsRowHistoryValue(String count, String relative) {
    return '$count entrées · la plus ancienne $relative';
  }

  @override
  String get settingsRowHistoryValueEmpty => '0 entrée';

  @override
  String get settingsRowRetentionLabel => 'Conserver l\'historique pendant';

  @override
  String get settingsRowClearHistoryLabel => 'Effacer l\'historique de lecture';

  @override
  String settingsDialogClearHistoryTitle(String count) {
    return 'Effacer $count entrées ?';
  }

  @override
  String get settingsDialogClearHistoryBody =>
      'Les positions de lecture ne font pas partie de cette liste et ne seront pas touchées.';

  @override
  String get settingsDialogClearHistoryConfirm => 'Effacer';

  @override
  String get settingsSnackHistoryCleared =>
      'Historique de lecture effacé. Vos positions de lecture ont été conservées.';

  @override
  String get settingsRowLanguageLabel => 'Langue';

  @override
  String get settingsRowLanguageHint =>
      'Suit votre téléphone. Changez-la dans les paramètres de langue d\'Android.';

  @override
  String get settingsRowOnboardingLabel =>
      'Comment fonctionne cette application';

  @override
  String get settingsRowOnboardingValue =>
      'Revoir les deux écrans d\'introduction';

  @override
  String get settingsRowAboutLabel => 'À propos de Lumen Tale';

  @override
  String settingsRowAboutValue(String buildName, String buildNumber) {
    return 'Version $buildName · build $buildNumber';
  }

  @override
  String get settingsDisclosureE11 =>
      'Rien ici n\'est sauvegardé. Si vous désinstallez Lumen Tale ou perdez ce téléphone, votre bibliothèque, vos téléchargements et vos positions de lecture sont perdus, et aucune copie n\'existe ailleurs.';

  @override
  String get settingsDisclosureE11Footer =>
      'L\'application ne peut pas vous avertir au moment où vous désinstallez : c\'est le téléphone qui le fait, en dehors de l\'application. C\'est donc dit ici, avant, plutôt qu\'après.';

  @override
  String get settingsDisclosureAboutLink => 'Ce qui survit à une mise à jour';

  @override
  String get settingsErrorWrite =>
      'Ce paramètre n\'a pas pu être enregistré. Rien n\'a été modifié.';

  @override
  String get settingsErrorCountUnavailable => 'Nombre indisponible';

  @override
  String get settingsButtonRetry => 'Réessayer';

  @override
  String get settingsButtonCancel => 'Annuler';

  @override
  String get readerOfflineBanner => 'Vous lisez vos téléchargements';

  @override
  String get readerNotStoredTitle => 'Ce chapitre n\'est pas téléchargé';

  @override
  String get readerNotStoredBody =>
      'Seuls les chapitres déjà présents sur ce téléphone peuvent être lus ici.';

  @override
  String get readerOfflineAbsentTitle =>
      'Ce chapitre n\'est pas téléchargé et il n\'y a pas de connexion';

  @override
  String get readerOfflineAbsentBody =>
      'Il faut les deux : le chapitre doit avoir été téléchargé une fois, et un téléchargement demande une connexion.';

  @override
  String get readerFileMissingTitle =>
      'Ce chapitre avait été téléchargé, mais son texte n\'est plus sur ce téléphone';

  @override
  String get readerFileMissingBody =>
      'Le téléchargement a réussi. C\'est le fichier qui manque.';

  @override
  String get readerFileEmptyTitle =>
      'L\'enregistrement de ce chapitre s\'est interrompu';

  @override
  String get readerFileEmptyBody =>
      'Rien n\'a été enregistré, donc il n\'y a rien à lire.';

  @override
  String get readerFileCorruptNotMarkdown =>
      'La copie enregistrée de ce chapitre est illisible';

  @override
  String get readerFileCorruptTruncated =>
      'La copie enregistrée de ce chapitre s\'arrête au milieu d\'une phrase';

  @override
  String get readerFileCorruptUnreadableIo =>
      'Le fichier de ce chapitre n\'a pas pu être ouvert';

  @override
  String get readerRowGoneTitle =>
      'Ce chapitre n\'existe plus dans votre bibliothèque';

  @override
  String get readerRowGoneBody =>
      'Le lien a peut-être été enregistré avant le retrait du chapitre.';

  @override
  String get readerLoadFailedTitle => 'Ce chapitre n\'a pas pu être ouvert';

  @override
  String get readerLoadFailedBody =>
      'L\'application ne sait pas si le fichier est intact.';

  @override
  String get readerActionDownloadChapter => 'Télécharger ce chapitre';

  @override
  String get readerActionDownloadAgain => 'Télécharger à nouveau';

  @override
  String get readerActionOpenDownloads => 'Ouvrir les téléchargements';

  @override
  String get readerActionBack => 'Revenir';

  @override
  String get readerActionRetry => 'Réessayer';

  @override
  String get readerDownloadNeedsConnection =>
      'Télécharger nécessite une connexion';

  @override
  String readerChapterNumber(String number) {
    return 'Chapitre $number';
  }

  @override
  String get readerChapterNumberUnreadable => 'Chapitre';

  @override
  String get libraryTitle => 'Bibliothèque';

  @override
  String get libraryContinueOverline => 'CONTINUE LA LECTURE';

  @override
  String libraryTileUnopened(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count nouveaux chapitres',
      one: '1 nouveau chapitre',
      zero: 'Aucun nouveau chapitre',
    );
    return '$_temp0';
  }

  @override
  String get libraryTileAuthorMissing => 'Auteur inconnu';

  @override
  String libraryTileProgress(Object downloaded, Object total) {
    return '$downloaded sur $total téléchargés';
  }

  @override
  String get libraryTileUndownloaded => 'Pas encore téléchargé';

  @override
  String get libraryRemoveTitle => 'Retirer de la bibliothèque ?';

  @override
  String libraryRemoveBody(num count, Object title) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count chapitres téléchargés',
      one: '1 chapitre téléchargé',
      zero: 'chapitre téléchargé',
    );
    return '$title quitte votre bibliothèque. Ses $_temp0 et votre historique de lecture restent sur ce téléphone.';
  }

  @override
  String get libraryRemoveAction => 'Retirer';

  @override
  String get libraryRemoveKept =>
      'Rien n\'a été supprimé. Les chapitres sont toujours là.';

  @override
  String get libraryRemoveUndo => 'Annuler';

  @override
  String libraryRemoved(Object title) {
    return '$title a été retiré';
  }

  @override
  String get librarySimilarTitle =>
      'Un roman portant ce titre est déjà dans votre bibliothèque';

  @override
  String librarySimilarBody(
    Object existing,
    Object incoming,
    Object incomingSource,
    Object source,
  ) {
    return '« $existing » sur $source porte le même titre que « $incoming » sur $incomingSource.';
  }

  @override
  String get librarySimilarOpenExisting => 'Ouvrir celui qui existe';

  @override
  String get librarySimilarAddAnyway => 'Ajouter quand même';

  @override
  String get librarySimilarExplain =>
      'Rien ne sera fusionné — ils restent deux romans distincts.';

  @override
  String get libraryLoadErrorTitle => 'Votre bibliothèque n\'a pas pu être lue';

  @override
  String get libraryAddFailed =>
      'Le roman n\'a pas pu être ajouté. Il est toujours listé dans Parcourir.';

  @override
  String get libraryAddFailedRetry => 'Réessayer';

  @override
  String get libraryActionCancel => 'Annuler';

  @override
  String get browseTitle => 'Parcourir';

  @override
  String browseSourceUnavailableTitle(Object source) {
    return '$source n\'a pas pu être lu';
  }

  @override
  String get browseSourceUnavailableBody =>
      'La page s\'est chargée, mais la partie qui liste les romans n\'y était pas. Votre bibliothèque n\'est pas touchée et rien n\'a été téléchargé.';

  @override
  String browseEmptyTagTitle(Object tag) {
    return 'Rien avec le tag $tag';
  }

  @override
  String browseEmptyTagBody(Object source) {
    return '$source ne publie aucun roman sous ce tag. Essayez un autre tag.';
  }

  @override
  String get browseSiteSaidNothingTitle => 'Le site dit n\'avoir rien';

  @override
  String browseSiteSaidNothingBody(Object query, Object source) {
    return 'La recherche de \"$query\" sur $source n\'a rien donné.';
  }

  @override
  String get browseNoConnectionTitle => 'Pas de connexion';

  @override
  String browseNoConnectionBody(Object source) {
    return '$source n\'a pas pu être joint. Votre bibliothèque n\'est pas touchée.';
  }

  @override
  String get browseActionRetry => 'Réessayer';

  @override
  String get browseActionOpenLibrary => 'Ouvrir la bibliothèque';

  @override
  String get browseActionBrowseAnother => 'Parcourir un autre tag';

  @override
  String get browseFailureLayoutChanged => 'La mise en page du site a changé';

  @override
  String get browseFailureRateLimited => 'Le site nous a demandé de ralentir';

  @override
  String get browseFailureNoConnection => 'Pas de connexion';

  @override
  String get browseFailureUnavailable => 'Le site est indisponible';

  @override
  String get browseFailureParse => 'La page n\'a pas pu être lue';

  @override
  String get browseFailureItemRemoved => 'Ce roman n\'est plus sur le site';

  @override
  String get browseTileKept => 'Dans votre bibliothèque';

  @override
  String get browseTileAdd => 'Ajouter';

  @override
  String get browseTileOpen => 'Ouvrir';

  @override
  String get browseFooterLoadingMore => 'Chargement…';

  @override
  String get browseFooterEnd => 'Voilà tout ce que ce tag publie';

  @override
  String get causeNoConnectionKicker => 'PAS DE CONNEXION';

  @override
  String get causeLayoutChangedKicker => 'LES PAGES DE CE SITE ONT CHANGÉ';

  @override
  String get causeSiteUnavailableKicker => 'LE SITE NE RÉPOND PAS';

  @override
  String get causeContentRemovedKicker => 'RETIRÉ DE LA SOURCE';

  @override
  String get causeUnreadableRecordKicker => 'CE SITE N\'A PAS PU ÊTRE LU';

  @override
  String causeNoConnectionTitle(Object host) {
    return 'Pas de connexion à $host';
  }

  @override
  String get causeNoConnectionBody =>
      'Rien n\'a été perdu. Votre bibliothèque et vos chapitres téléchargés sont exactement ce qu\'ils étaient.';

  @override
  String get causeLayoutChangedTitle => 'Les pages de ce site ont changé';

  @override
  String causeLayoutChangedBody(Object retryNote, Object source) {
    return 'C\'est une faute dans la copie que l\'application a de $source — pas dans $source, et rien n\'est dû à votre utilisation. $retryNote';
  }

  @override
  String get causeLayoutChangedRetryNote =>
      'Parfois cela se résout tout seul. Rarement.';

  @override
  String causeLayoutChangedDictation(Object source) {
    return 'Dites : « les pages de $source ont changé et l\'application ne peut plus les lire ».';
  }

  @override
  String causeSiteUnavailableTitle(Object source) {
    return '$source ne répond pas';
  }

  @override
  String get causeSiteUnavailableBody =>
      'Le site a refusé ou est hors service. Rien de votre bibliothèque n\'a été touché.';

  @override
  String causeContentRemovedTitle(Object source) {
    return 'Ce n\'est plus sur $source';
  }

  @override
  String get causeContentRemovedBody =>
      'Le site le dit dans ses propres mots. Votre copie enregistrée n\'est pas touchée.';

  @override
  String get causeContentRemovedNoRetry => 'Il n\'y a rien à réessayer ici.';

  @override
  String get causeUnreadableRecordTitle =>
      'Cette application ne peut pas dire ce qui s\'est passé';

  @override
  String get causeUnreadableRecordBody =>
      'Elle a gardé un enregistrement qu\'elle ne peut plus lire, et elle ne devinera pas. L\'application n\'invente pas de diagnostic.';

  @override
  String get causeEvidenceHeading => 'Ce qui s\'est passé';

  @override
  String get causeActionTryAgain => 'Réessayer';

  @override
  String get causeActionCopyThis => 'Copier ceci';

  @override
  String get causeActionBack => 'Retour';

  @override
  String get causeActionBrowseOther => 'Parcourir un autre site';

  @override
  String get causeActionOpenLibrary => 'Ouvrir la bibliothèque';

  @override
  String get sourceUnavailableStillWorksHeading => 'Ce qui fonctionne toujours';

  @override
  String sourceUnavailableStillWorksBody(
    Object downloaded,
    Object library,
    Object source,
  ) {
    return 'Vos $library romans et $downloaded chapitres téléchargés sont sur ce téléphone et sont lisibles maintenant, avec ou sans $source.';
  }

  @override
  String get sourceUnavailableStillWorksEmpty =>
      'Rien n\'est encore enregistré — et rien n\'a été perdu par cet échec.';

  @override
  String sourceUnavailableRetryIn(Object seconds) {
    return 'Réessayer dans $seconds s';
  }

  @override
  String sourceUnavailableWaitingForSite(Object seconds) {
    return 'Le site nous a demandé d\'attendre $seconds s.';
  }

  @override
  String get browseFailureUnknownCause =>
      'L\'application ne peut pas lire son propre enregistrement de cet échec';

  @override
  String get browseSearchHint => 'Rechercher sur ce site';

  @override
  String get novelDetailsTitle => 'Roman';

  @override
  String chapterListHeaderCount(Object count) {
    return '$count chapitres';
  }

  @override
  String chapterListHeaderAtSource(Object count, Object source) {
    return '$count chapitres sur $source';
  }

  @override
  String get chapterListLoadAction => 'Charger la liste des chapitres';

  @override
  String get chapterListLoadExplainer =>
      'Cette application n\'a jamais récupéré les chapitres de ce roman. Rien n\'a été enregistré, et rien n\'a été perdu.';

  @override
  String get chapterListNeverLoadedTitle =>
      'Les chapitres n\'ont jamais été chargés';

  @override
  String chapterListNeverLoadedBody(Object source) {
    return 'Ce roman est dans votre bibliothèque, mais sa liste de chapitres n\'a pas encore été récupérée. La charger demande la liste à $source et la conserve sur ce téléphone.';
  }

  @override
  String get chapterListNoConnectionTitle => 'Pas de connexion';

  @override
  String chapterListNoConnectionBody(Object source) {
    return 'La liste des chapitres n\'a jamais été récupérée, et $source n\'est pas joignable maintenant. Votre bibliothèque n\'est pas touchée.';
  }

  @override
  String chapterListEmptyAtSourceTitle(Object source) {
    return '$source ne publie aucun chapitre';
  }

  @override
  String get chapterListEmptyAtSourceBody =>
      'Le site le dit lui-même. C\'est ce qu\'il publie pour ce roman, et ce n\'est pas une erreur.';

  @override
  String chapterListUnreadableTitle(Object source) {
    return '$source n\'a pas pu être lu';
  }

  @override
  String get chapterListUnreadableBody =>
      'La page s\'est chargée et la liste des chapitres n\'y était pas. Votre bibliothèque n\'est pas touchée et rien n\'a été téléchargé.';

  @override
  String get chapterListStoredUnreadableTitle =>
      'Cette application ne peut pas lire sa propre copie';

  @override
  String chapterListStoredUnreadableBody(Object source) {
    return 'La liste des chapitres est enregistrée sur ce téléphone, et l\'application ne peut plus la lire. La recharger depuis $source la remplacerait, donc l\'application ne l\'a pas fait.';
  }

  @override
  String get chapterListMarkedReadFailedTitle =>
      'Les enregistrements de l\'application se contredisent';

  @override
  String chapterListMarkedReadFailedBody(Object source) {
    return 'Un chapitre que vous avez lu ne figure plus dans la liste publiée par $source. L\'application n\'a pas supprimé votre progression.';
  }

  @override
  String get chapterListSpaceRefusedTitle => 'Pas assez de place';

  @override
  String chapterListSpaceRefusedBody(Object bytes) {
    return 'Ce téléchargement demande environ $bytes et il n\'y a pas cette place. Rien n\'a été mis en file.';
  }

  @override
  String chapterListTailMarker(Object displayed, Object total) {
    return '$displayed chapitres sur $total';
  }

  @override
  String get chapterListJumpToCurrent => 'Aller au chapitre actuel';

  @override
  String get chapterListUntitled => 'Sans titre';

  @override
  String get chapterListAddToLibrary => 'Ajouter à la bibliothèque';

  @override
  String get chapterListReadFromStart => 'Lire depuis le début';

  @override
  String get chapterListContinue => 'Continuer';

  @override
  String chapterListContinueSemantics(String chapter, int percent) {
    return 'Continuer, $chapter, $percent de ce chapitre';
  }

  @override
  String get chapterListNothingUnopened => 'Rien de non ouvert';

  @override
  String get chapterListDownloadAction => 'Télécharger';

  @override
  String chapterListMarkAllReadConfirm(int count) {
    return 'Marquer les $count chapitres que vous n\'avez pas ouverts comme lus ?';
  }

  @override
  String get chapterListMarkAllRead => 'Tout marquer comme lu';

  @override
  String get chapterListDownloadAll => 'Tout télécharger';

  @override
  String get chapterTileUnread => 'Non lu';

  @override
  String get chapterTileNotDownloaded => 'Non téléchargé';

  @override
  String get chapterTileDownloaded => 'Téléchargé';

  @override
  String get chapterListActionRetry => 'Réessayer';

  @override
  String get chapterListActionBack => 'Retour';
}
