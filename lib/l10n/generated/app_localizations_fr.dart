// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get aboutCopyVersion => 'Copier le numéro de version';

  @override
  String get aboutDataCountUnavailable => '—';

  @override
  String get aboutDataDownloaded => 'Chapitres téléchargés';

  @override
  String get aboutDataE11 =>
      'Rien ici n\'est sauvegardé nulle part. Si vous désinstallez Lumen Tale ou perdez ce téléphone, ces trois nombres tombent à zéro et aucune copie n\'existe. Installer une nouvelle version par-dessus celle-ci n\'y touche pas : c\'est la seule garantie que cette application fait sur vos données.';

  @override
  String get aboutDataLabel => 'VOS DONNÉES SUR CE TÉLÉPHONE';

  @override
  String get aboutDataLibrary => 'Bibliothèque';

  @override
  String get aboutDataPositions => 'Positions de lecture';

  @override
  String get aboutDeliveryBody =>
      'Cette application fonctionne uniquement sur les téléphones Android. Une nouvelle version est produite à chaque modification fusionnée, et vous l\'installez depuis le fichier, à la main. Il n\'y a ni magasin d\'applications ni compte de magasin.';

  @override
  String get aboutGuarantee =>
      'L\'installation d\'une nouvelle version conserve votre bibliothèque, vos téléchargements, vos positions de lecture et votre historique. Rien n\'est remplacé ni retéléchargé.';

  @override
  String get aboutPrivacyLabel => 'CE QUI QUITTE CE TÉLÉPHONE';

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
  String get aboutPrivacySent1 =>
      'La page d\'un chapitre — mais seulement après que vous l\'avez demandée.';

  @override
  String get aboutPrivacySent2 =>
      'Une requête pour savoir si une nouvelle version existe — uniquement si vous touchez « Rechercher une nouvelle version ».';

  @override
  String get aboutPrivacyVerify =>
      'Vérifiez vous-même : passez le téléphone en mode avion, puis ouvrez l\'application. Votre bibliothèque, vos téléchargements et vos positions de lecture sont tous là. Il ne manque rien, parce que rien n\'a jamais été envoyé.';

  @override
  String get aboutProvenance =>
      'Téléphone Android · compilé automatiquement · aucun magasin';

  @override
  String get aboutSnackCopied => 'Numéro de version copié.';

  @override
  String aboutVersion(String buildName, String buildNumber) {
    return 'Version $buildName · build $buildNumber';
  }

  @override
  String get aboutVersionUnreadable =>
      'Le numéro de version installé n\'a pas pu être lu.';

  @override
  String get actionFreeSpace => 'Libérer de la place';

  @override
  String get actionReportBug => 'Signaler le problème';

  @override
  String get appTitle => 'Lumen Tale';

  @override
  String get browseActionBrowseAnother => 'Parcourir un autre tag';

  @override
  String get browseActionLoadMore => 'Charger plus';

  @override
  String get browseActionOpenLibrary => 'Ouvrir la bibliothèque';

  @override
  String get browseActionRetry => 'Réessayer';

  @override
  String get browseEmpty => 'Ce site n\'a rien à montrer ici.';

  @override
  String get browseEmptyBody => 'Aucune source n\'est encore disponible.';

  @override
  String browseEmptyTagBody(Object source) {
    return '$source ne publie aucun roman sous ce tag. Essayez un autre tag.';
  }

  @override
  String browseEmptyTagTitle(Object tag) {
    return 'Rien avec le tag $tag';
  }

  @override
  String get browseFailureItemRemoved => 'Ce roman n\'est plus sur le site';

  @override
  String get browseFailureLayoutChanged => 'La mise en page du site a changé';

  @override
  String get browseFailureNoConnection => 'Pas de connexion';

  @override
  String get browseFailureParse => 'La page n\'a pas pu être lue';

  @override
  String get browseFailureRateLimited => 'Le site nous a demandé de ralentir';

  @override
  String get browseFailureUnavailable => 'Le site est indisponible';

  @override
  String get browseFailureUnknownCause =>
      'L\'application ne peut pas lire son propre enregistrement de cet échec';

  @override
  String get browseFooterEnd => 'Voilà tout ce que ce tag publie';

  @override
  String get browseFooterLoadingMore => 'Chargement…';

  @override
  String browseNoConnectionBody(Object source) {
    return '$source n\'a pas pu être joint. Votre bibliothèque n\'est pas touchée.';
  }

  @override
  String get browseNoConnectionTitle => 'Pas de connexion';

  @override
  String get browseSearchHint => 'Rechercher sur ce site';

  @override
  String browseSiteSaidNothingBody(Object query, Object source) {
    return 'La recherche de \"$query\" sur $source n\'a rien donné.';
  }

  @override
  String get browseSiteSaidNothingTitle => 'Le site dit n\'avoir rien';

  @override
  String get browseSourceUnavailableBody =>
      'La page s\'est chargée, mais la partie qui liste les romans n\'y était pas. Votre bibliothèque n\'est pas touchée et rien n\'a été téléchargé.';

  @override
  String browseSourceUnavailableTitle(Object source) {
    return '$source n\'a pas pu être lu';
  }

  @override
  String get browseSucceeded => 'Lecture réussie.';

  @override
  String get browseTileAdd => 'Ajouter';

  @override
  String get browseTileKept => 'Dans votre bibliothèque';

  @override
  String get browseTileOpen => 'Ouvrir';

  @override
  String get browseTitle => 'Parcourir';

  @override
  String get causeActionBack => 'Retour';

  @override
  String get causeActionBrowseOther => 'Parcourir un autre site';

  @override
  String get causeActionCopyThis => 'Copier ceci';

  @override
  String get causeActionOpenLibrary => 'Ouvrir la bibliothèque';

  @override
  String get causeActionTryAgain => 'Réessayer';

  @override
  String get causeContentRemovedBody =>
      'Le site le dit dans ses propres mots. Votre copie enregistrée n\'est pas touchée.';

  @override
  String get causeContentRemovedKicker => 'RETIRÉ DE LA SOURCE';

  @override
  String get causeContentRemovedNoRetry => 'Il n\'y a rien à réessayer ici.';

  @override
  String causeContentRemovedTitle(Object source) {
    return 'Ce n\'est plus sur $source';
  }

  @override
  String get causeEvidenceHeading => 'Ce qui s\'est passé';

  @override
  String causeLayoutChangedBody(Object retryNote, Object source) {
    return 'C\'est une faute dans la copie que l\'application a de $source — pas dans $source, et rien n\'est dû à votre utilisation. $retryNote';
  }

  @override
  String causeLayoutChangedDictation(Object source) {
    return 'Dites : « les pages de $source ont changé et l\'application ne peut plus les lire ».';
  }

  @override
  String get causeLayoutChangedKicker => 'LES PAGES DE CE SITE ONT CHANGÉ';

  @override
  String get causeLayoutChangedRetryNote =>
      'Parfois cela se résout tout seul. Rarement.';

  @override
  String get causeLayoutChangedTitle => 'Les pages de ce site ont changé';

  @override
  String get causeNoConnectionBody =>
      'Rien n\'a été perdu. Votre bibliothèque et vos chapitres téléchargés sont exactement ce qu\'ils étaient.';

  @override
  String get causeNoConnectionKicker => 'PAS DE CONNEXION';

  @override
  String causeNoConnectionTitle(Object host) {
    return 'Pas de connexion à $host';
  }

  @override
  String get causeSiteUnavailableBody =>
      'Le site a refusé ou est hors service. Rien de votre bibliothèque n\'a été touché.';

  @override
  String get causeSiteUnavailableKicker => 'LE SITE NE RÉPOND PAS';

  @override
  String causeSiteUnavailableTitle(Object source) {
    return '$source ne répond pas';
  }

  @override
  String get causeUnreadableRecordBody =>
      'Elle a gardé un enregistrement qu\'elle ne peut plus lire, et elle ne devinera pas. L\'application n\'invente pas de diagnostic.';

  @override
  String get causeUnreadableRecordKicker => 'CE SITE N\'A PAS PU ÊTRE LU';

  @override
  String get causeUnreadableRecordTitle =>
      'Cette application ne peut pas dire ce qui s\'est passé';

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
  String chapterCountPlural(Object count) {
    return '$count autres chapitres';
  }

  @override
  String get chapterCountSingular => '1 autre chapitre';

  @override
  String get chapterListActionBack => 'Retour';

  @override
  String get chapterListActionRetry => 'Réessayer';

  @override
  String get chapterListAddToLibrary => 'Ajouter à la bibliothèque';

  @override
  String get chapterListContinue => 'Continuer';

  @override
  String chapterListContinueSemantics(String chapter, int percent) {
    return 'Continuer, $chapter, $percent de ce chapitre';
  }

  @override
  String get chapterListDownloadAction => 'Télécharger';

  @override
  String get chapterListDownloadAll => 'Tout télécharger';

  @override
  String get chapterListEmptyAtSourceBody =>
      'Le site le dit lui-même. C\'est ce qu\'il publie pour ce roman, et ce n\'est pas une erreur.';

  @override
  String chapterListEmptyAtSourceTitle(Object source) {
    return '$source ne publie aucun chapitre';
  }

  @override
  String chapterListHeaderAtSource(Object count, Object source) {
    return '$count chapitres sur $source';
  }

  @override
  String chapterListHeaderCount(Object count) {
    return '$count chapitres';
  }

  @override
  String get chapterListJumpToCurrent => 'Aller au chapitre actuel';

  @override
  String get chapterListLoadAction => 'Charger la liste des chapitres';

  @override
  String get chapterListLoadExplainer =>
      'Cette application n\'a jamais récupéré les chapitres de ce roman. Rien n\'a été enregistré, et rien n\'a été perdu.';

  @override
  String get chapterListMarkAllRead => 'Tout marquer comme lu';

  @override
  String chapterListMarkAllReadConfirm(int count) {
    return 'Marquer les $count chapitres que vous n\'avez pas ouverts comme lus ?';
  }

  @override
  String chapterListMarkedReadFailedBody(Object source) {
    return 'Un chapitre que vous avez lu ne figure plus dans la liste publiée par $source. L\'application n\'a pas supprimé votre progression.';
  }

  @override
  String get chapterListMarkedReadFailedTitle =>
      'Les enregistrements de l\'application se contredisent';

  @override
  String chapterListNeverLoadedBody(Object source) {
    return 'Ce roman est dans votre bibliothèque, mais sa liste de chapitres n\'a pas encore été récupérée. La charger demande la liste à $source et la conserve sur ce téléphone.';
  }

  @override
  String get chapterListNeverLoadedTitle =>
      'Les chapitres n\'ont jamais été chargés';

  @override
  String chapterListNoConnectionBody(Object source) {
    return 'La liste des chapitres n\'a jamais été récupérée, et $source n\'est pas joignable maintenant. Votre bibliothèque n\'est pas touchée.';
  }

  @override
  String get chapterListNoConnectionTitle => 'Pas de connexion';

  @override
  String get chapterListNothingUnopened => 'Rien de non ouvert';

  @override
  String get chapterListReadFromStart => 'Lire depuis le début';

  @override
  String chapterListSpaceRefusedBody(Object bytes) {
    return 'Ce téléchargement demande environ $bytes et il n\'y a pas cette place. Rien n\'a été mis en file.';
  }

  @override
  String get chapterListSpaceRefusedTitle => 'Pas assez de place';

  @override
  String chapterListStoredUnreadableBody(Object source) {
    return 'La liste des chapitres est enregistrée sur ce téléphone, et l\'application ne peut plus la lire. La recharger depuis $source la remplacerait, donc l\'application ne l\'a pas fait.';
  }

  @override
  String get chapterListStoredUnreadableTitle =>
      'Cette application ne peut pas lire sa propre copie';

  @override
  String chapterListTailMarker(Object displayed, Object total) {
    return '$displayed chapitres sur $total';
  }

  @override
  String get chapterListUnreadableBody =>
      'La page s\'est chargée et la liste des chapitres n\'y était pas. Votre bibliothèque n\'est pas touchée et rien n\'a été téléchargé.';

  @override
  String chapterListUnreadableTitle(Object source) {
    return '$source n\'a pas pu être lu';
  }

  @override
  String get chapterListUntitled => 'Sans titre';

  @override
  String get chapterTileDownloaded => 'Téléchargé';

  @override
  String get chapterTileNotDownloaded => 'Non téléchargé';

  @override
  String get chapterTileUnread => 'Non lu';

  @override
  String checkActionSemantics(int done, int total) {
    return 'Vérification en cours, $done sur $total romans';
  }

  @override
  String get checkCancelAction => 'Arrêter la vérification';

  @override
  String get checkCancelled => 'Vérification annulée.';

  @override
  String get checkCancelledByReader =>
      'Vérification annulée · votre bibliothèque n\'est pas modifiée';

  @override
  String checkDiscovered(int total, int discovered) {
    return '$total romans vérifiés · $discovered que vous n\'aviez pas ouverts';
  }

  @override
  String checkDiscoveredNothing(int total) {
    return '$total romans vérifiés · rien que vous n\'ayez pas ouvert';
  }

  @override
  String get checkFinishedAfterCancel =>
      'La vérification s\'est terminée après votre annulation.';

  @override
  String get checkNeedsConnection => 'La vérification nécessite une connexion.';

  @override
  String get checkNotificationChannelName => 'Vérifications de la bibliothèque';

  @override
  String get checkNotificationPermissionWarning =>
      'La vérification s\'exécutera, mais Android n\'affichera pas sa notification : rien ne vous dira quand elle se termine.';

  @override
  String get checkNotificationSettingsAction =>
      'Ouvrir les paramètres de notification';

  @override
  String get checkNotificationTitle => 'Vérification de votre bibliothèque';

  @override
  String get checkNowAction => 'Vérifier les nouveaux chapitres';

  @override
  String checkProgress(int done, int total) {
    return 'Vérification : $done sur $total romans';
  }

  @override
  String checkProgressNothingDownloaded(int done, int total) {
    return 'Vérification : $done sur $total romans · rien n\'est téléchargé';
  }

  @override
  String get checkQueuedNotice =>
      'La vérification doit être relancée depuis ici : le téléphone a fermé la tâche.';

  @override
  String get checkStoppedAppStandby =>
      'Vérification arrêtée — le téléphone a mis l\'application en veille. Réessayez.';

  @override
  String get checkStoppedBackgroundRestriction =>
      'Vérification arrêtée — Android l\'a mise en pause. Relancez-la pour terminer.';

  @override
  String get checkStoppedCancelledByApp =>
      'Vérification annulée · votre bibliothèque n\'est pas modifiée';

  @override
  String get checkStoppedDeviceIdle =>
      'Vérification arrêtée — le téléphone a mis l\'application en veille. Réessayez.';

  @override
  String get checkStoppedDeviceState =>
      'Vérification arrêtée — le téléphone économise son énergie. Réessayez.';

  @override
  String get checkStoppedGpuLimit =>
      'Vérification arrêtée — le téléphone n\'a plus de mémoire pour elle. Réessayez.';

  @override
  String get checkStoppedPreempt =>
      'Vérification arrêtée — Android a donné le téléphone à autre chose.';

  @override
  String get checkStoppedSystemIgnoredCancel =>
      'La vérification s\'est terminée après votre annulation.';

  @override
  String get checkStoppedTimeout =>
      'La vérification a dépassé le temps accordé par Android et a été arrêtée. Réessayez.';

  @override
  String get checkStoppedUnknown =>
      'Vérification arrêtée — Android n\'a pas dit pourquoi. Relancez-la pour terminer.';

  @override
  String checkTerminalComplete(int total) {
    return '$total romans vérifiés, aucun ignoré.';
  }

  @override
  String checkTerminalInterrupted(int done, int total) {
    return 'Vérification arrêtée à $done romans sur $total.';
  }

  @override
  String checkTerminalWithFailures(int checked, int total, int failed) {
    return '$checked romans vérifiés sur $total · $failed n\'ont pas pu être vérifiés.';
  }

  @override
  String get commonBack => 'Retour';

  @override
  String get commonCancel => 'Annuler';

  @override
  String get commonErrorBody => 'L\'opération n\'a pas pu être terminée.';

  @override
  String get commonErrorTitle => 'Une erreur est survenue';

  @override
  String get commonOk => 'OK';

  @override
  String get commonRetry => 'Réessayer';

  @override
  String coverSemanticsLabel(String title) {
    return 'Couverture de $title';
  }

  @override
  String deleteStoredBody(Object freedBytes, Object siblingCount) {
    return 'Le texte de ce chapitre sera effacé de ce téléphone.\nLes $siblingCount autres chapitres de ce roman ne sont pas touchés.\n$freedBytes seront libérés.';
  }

  @override
  String get deleteStoredConfirm => 'Supprimer';

  @override
  String get deleteStoredFailedSnackbar =>
      'Impossible de supprimer ce chapitre. Rien n\'a été modifié.';

  @override
  String deleteStoredTitle(Object ordinal) {
    return 'Supprimer le chapitre $ordinal ?';
  }

  @override
  String get downloadAddedSnackbar => 'Téléchargement ajouté';

  @override
  String get downloadAlreadyQueuedSnackbar =>
      'Ce chapitre est déjà dans la file d\'attente';

  @override
  String get downloadAlreadyStoredSnackbar => 'Ce chapitre est déjà téléchargé';

  @override
  String downloadDeletedSnackbar(Object freedBytes) {
    return 'Chapitre supprimé — $freedBytes libérés';
  }

  @override
  String get downloadDone => 'Téléchargé';

  @override
  String get downloadDownloading => 'Téléchargement en cours';

  @override
  String get downloadFailed =>
      'Téléchargement interrompu. Vous pouvez le relancer.';

  @override
  String get downloadNeedsConnectionSnackbar =>
      'Le téléchargement nécessite une connexion.';

  @override
  String get downloadNotDownloadedLabel => 'Non téléchargé';

  @override
  String get downloadNotStoredSnackbar =>
      'Ce chapitre n\'était pas téléchargé.';

  @override
  String get downloadQueued => 'Téléchargement en attente';

  @override
  String get downloadSpaceRefusedAction =>
      'Supprimez un chapitre téléchargé, puis réessayez.';

  @override
  String downloadSpaceRefusedBody(Object freeBytes, Object requiredBytes) {
    return 'Ce téléchargement nécessite $requiredBytes, et ce téléphone dispose de $freeBytes libres.';
  }

  @override
  String get downloadWriteFailedSnackbar =>
      'Le téléchargement n\'a pas pu être ajouté. Rien n\'a été modifié.';

  @override
  String downloadsAttemptCount(Object count) {
    return 'Tenté $count fois';
  }

  @override
  String get downloadsCancelAction => 'Annuler le téléchargement';

  @override
  String get downloadsCancelFailedSnackbar =>
      'Impossible d\'annuler. Le téléchargement est toujours en cours.';

  @override
  String downloadsCancelledKept(Object kept) {
    return 'Téléchargement annulé — $kept chapitres conservés.';
  }

  @override
  String get downloadsEmptyActionBrowse => 'Parcourir les sources';

  @override
  String get downloadsEmptyBody =>
      'Les chapitres téléchargés se lisent sans aucune connexion. Lancez-en un depuis la page d\'un roman.';

  @override
  String get downloadsEmptyTitle => 'Rien n\'est encore téléchargé';

  @override
  String downloadsFailedRowTitle(Object name) {
    return 'Chapitre : $name';
  }

  @override
  String get downloadsFailedSectionLabel => 'TÉLÉCHARGEMENT IMPOSSIBLE';

  @override
  String downloadsHeaderCounts(Object downloaded, Object total) {
    return '$downloaded sur $total téléchargés';
  }

  @override
  String get downloadsInProcessNotice =>
      'Les téléchargements ne continuent que tant que l\'application est ouverte.';

  @override
  String downloadsInProgressSuffix(Object count) {
    return '· $count en cours';
  }

  @override
  String get downloadsLoadErrorBody =>
      'Rien n\'a été supprimé. Cette application ne voit pas ce qu\'elle a déjà enregistré, et rien ne peut être récupéré tant qu\'elle ne le voit pas.';

  @override
  String get downloadsLoadErrorRetry => 'Réessayer';

  @override
  String get downloadsLoadErrorTitle =>
      'Lumen Tale n\'a pas pu lire ses enregistrements de téléchargement';

  @override
  String get downloadsOpenNovelAction => 'Ouvrir le roman';

  @override
  String get downloadsPauseAction => 'Pause';

  @override
  String get downloadsPausedLabel => 'En pause';

  @override
  String get downloadsQueueSectionLabel => 'FILE DE TÉLÉCHARGEMENT';

  @override
  String get downloadsResumeAction => 'Reprendre';

  @override
  String get downloadsRetryAction => 'Réessayer ce chapitre';

  @override
  String get downloadsRunningLabel => 'Téléchargement en cours';

  @override
  String downloadsSemanticsChapterProgress(
    Object percent,
    Object position,
    Object total,
  ) {
    return 'Chapitre $position sur $total, $percent pour cent';
  }

  @override
  String downloadsSemanticsProgressUndetermined(Object position, Object total) {
    return 'Chapitre $position sur $total, téléchargement en cours';
  }

  @override
  String get downloadsStoppedLabel => 'Arrêté';

  @override
  String get downloadsStoppedNoConnection => 'Aucune connexion';

  @override
  String get downloadsStoppedOutOfStorage =>
      'Le téléphone n\'a plus de stockage. Libérez de l\'espace, puis reprenez.';

  @override
  String downloadsStoppedRateLimited(Object time) {
    return 'Le site nous a demandé d\'attendre jusqu\'à $time.';
  }

  @override
  String downloadsStoppedSourceUnreadable(Object source) {
    return 'Lumen Tale n\'a pas pu lire $source.';
  }

  @override
  String downloadsStorageNeeded(Object bytes) {
    return 'Ce chapitre nécessite $bytes.';
  }

  @override
  String get downloadsTitle => 'Téléchargements';

  @override
  String get downloadsWillNotContinueOnItsOwn =>
      'Il ne reprendra pas tout seul quand le signal reviendra.';

  @override
  String get errorCountUnavailable => 'Ce compte n\'a pas pu être calculé.';

  @override
  String get errorHistoryClear => 'L\'historique n\'a pas pu être effacé.';

  @override
  String get errorItemRemovedAtSource =>
      'Ce roman n\'existe plus sur le site. Le reste de votre bibliothèque n\'est pas touché.';

  @override
  String get errorNoConnection =>
      'Pas de connexion. Vos chapitres téléchargés restent lisibles.';

  @override
  String get errorParseFailed =>
      'Un fichier de ce roman n\'a pas pu être lu. Signalez-le au responsable de l\'application.';

  @override
  String get errorRateLimited =>
      'Le site demande de ralentir. Réessayez dans un instant.';

  @override
  String errorRateLimitedIn(int seconds) {
    return 'Le site demande de ralentir. Réessayez dans $seconds secondes.';
  }

  @override
  String get errorSettingsLoad =>
      'Vos réglages n\'ont pas pu être lus depuis ce téléphone. Votre bibliothèque, vos téléchargements et vos positions de lecture ne sont pas touchés.';

  @override
  String get errorSettingsWrite =>
      'Ce réglage n\'a pas pu être enregistré. Il reprendra sa valeur précédente.';

  @override
  String get errorSiteUnreadable =>
      'Ce site n\'a pas pu être lu. Ce n\'est pas la même chose qu\'un site sans chapitres. Les autres sources fonctionnent normalement.';

  @override
  String get errorSourceLayoutChanged =>
      'Ce site a changé de présentation. L\'application ne peut plus le lire.';

  @override
  String get errorSourceUnavailable =>
      'Ce site ne répond pas. Réessayez plus tard.';

  @override
  String get errorStorageFull =>
      'L\'espace de stockage est plein. Libérez de la place, puis relancez.';

  @override
  String get historyAgedOutBody =>
      'Vos positions de lecture ont été conservées.';

  @override
  String get historyAgedOutTitle =>
      'Tout ce qui datait de plus d\'un an a été supprimé';

  @override
  String get historyClearAction => 'Effacer l\'historique';

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
  String get historyClearDialogTitle => 'Effacer l\'historique ?';

  @override
  String get historyClearedBody =>
      'Votre bibliothèque, vos téléchargements et toutes vos positions de lecture ont été conservés.';

  @override
  String get historyClearedTitle => 'Historique effacé';

  @override
  String historyDayOn(String date) {
    return '$date';
  }

  @override
  String get historyDayToday => 'Aujourd\'hui';

  @override
  String get historyDayYesterday => 'Hier';

  @override
  String get historyEmptyActionBrowse => 'Parcourir une source';

  @override
  String get historyEmptyActionLibrary => 'Ouvrir votre bibliothèque';

  @override
  String get historyEmptyBody =>
      'Les chapitres que vous ouvrez apparaissent ici, du plus récent au plus ancien.';

  @override
  String get historyEmptyTitle => 'Rien de lu pour l\'instant';

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
  String get historyJustNow => 'À l\'instant';

  @override
  String get historyLoadErrorBody =>
      'Votre bibliothèque, vos chapitres téléchargés et toutes vos positions de lecture ne sont pas affectés.';

  @override
  String get historyLoadErrorTitle => 'Votre historique n\'a pas pu être lu';

  @override
  String get historyLoadingTitle => 'Chargement de l\'historique';

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
  String get historyNoticeBody =>
      'Effacer l\'historique ne déplace jamais une position de lecture retenue.';

  @override
  String get historyNoticeTitle => 'L\'historique est borné par le temps';

  @override
  String get historyRetentionChange => 'Changer';

  @override
  String get historyRetentionLabel => 'Durée de conservation';

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
  String historyTerminalLine(String window) {
    return 'Voici l\'entrée la plus ancienne conservée. Les entrées de plus de $window seront supprimées, les plus anciennes d\'abord.';
  }

  @override
  String get historyTitle => 'Historique';

  @override
  String get historyUntitledChapter => 'Sans titre';

  @override
  String get historyUntitledNovel => 'Sans titre';

  @override
  String get historyWindowOneMonth => 'un mois';

  @override
  String get historyWindowOneWeek => 'une semaine';

  @override
  String get historyWindowOneYear => 'un an';

  @override
  String get historyWindowThreeMonths => 'trois mois';

  @override
  String get historyWindowTwoYears => 'deux ans';

  @override
  String get libraryActionCancel => 'Annuler';

  @override
  String get libraryAddFailed =>
      'Le roman n\'a pas pu être ajouté. Il est toujours listé dans Parcourir.';

  @override
  String get libraryAddFailedRetry => 'Réessayer';

  @override
  String get libraryContinueOverline => 'CONTINUE LA LECTURE';

  @override
  String get libraryEmptyBody =>
      'Ajoutez un roman depuis Parcourir pour commencer à lire.';

  @override
  String get libraryEmptyBrowseAction => 'Parcourir un site';

  @override
  String get libraryEmptyTitle => 'Votre bibliothèque est vide';

  @override
  String get libraryFacetDownloaded => 'Téléchargés';

  @override
  String get libraryFacetGroup => 'Afficher';

  @override
  String get libraryFacetHasUnopened => 'Avec des chapitres non ouverts';

  @override
  String get libraryFacetNotDownloaded => 'Non téléchargés';

  @override
  String get libraryFacetSite => 'Site';

  @override
  String libraryFilterCount(int count) {
    return '$count filtres actifs';
  }

  @override
  String get libraryLoadErrorBody =>
      'Les chapitres déjà téléchargés sont toujours sur ce téléphone et restent lisibles.';

  @override
  String get libraryLoadErrorTitle => 'Votre bibliothèque n\'a pas pu être lue';

  @override
  String get libraryNoDataClearFilters => 'Effacer les filtres';

  @override
  String get libraryNoDataTitle =>
      'Aucun roman gardé ne correspond aux filtres';

  @override
  String get libraryRemoveAction => 'Retirer';

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
  String get libraryRemoveKept =>
      'Rien n\'a été supprimé. Les chapitres sont toujours là.';

  @override
  String get libraryRemoveTitle => 'Retirer de la bibliothèque ?';

  @override
  String get libraryRemoveUndo => 'Annuler';

  @override
  String libraryRemoved(Object title) {
    return '$title a été retiré';
  }

  @override
  String get libraryRowCouldNotCheck => 'Vérification impossible';

  @override
  String get libraryRowDownloadComplete =>
      'Tous les chapitres sont téléchargés';

  @override
  String get libraryRowNeverChecked => 'Jamais vérifiée';

  @override
  String get libraryRowStopped => 'Arrêté';

  @override
  String get libraryRowStoppedConnection => 'Arrêté · pas de connexion';

  @override
  String get libraryRowStoppedStorage => 'Arrêté · stockage plein';

  @override
  String get libraryScopeLine =>
      'Titres uniquement — l\'application ne conserve ni auteurs, ni genres, ni descriptions comme champs cherchables.';

  @override
  String get librarySearchClearAction => 'Effacer la recherche';

  @override
  String get librarySearchHint => 'Rechercher par titre';

  @override
  String librarySearchNoMatchTitle(String query) {
    return 'Aucun roman gardé ne correspond à « $query »';
  }

  @override
  String librarySearchResults(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count romans',
      one: '1 roman',
      zero: 'Aucun roman',
    );
    return '$_temp0';
  }

  @override
  String get librarySearchSemantics =>
      'Rechercher dans votre bibliothèque par titre';

  @override
  String get librarySimilarAddAnyway => 'Ajouter quand même';

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
  String get librarySimilarExplain =>
      'Rien ne sera fusionné — ils restent deux romans distincts.';

  @override
  String get librarySimilarOpenExisting => 'Ouvrir celui qui existe';

  @override
  String get librarySimilarTitle =>
      'Un roman portant ce titre est déjà dans votre bibliothèque';

  @override
  String get librarySortLastRead => 'Dernière lecture';

  @override
  String get librarySortRecentlyAdded => 'Ajoutés récemment';

  @override
  String get librarySortSite => 'Site';

  @override
  String get librarySortTitle => 'Tri et filtres';

  @override
  String get librarySortTitleAz => 'Titre A–Z';

  @override
  String get librarySortUnopened => 'Chapitres non ouverts';

  @override
  String get libraryTileAuthorMissing => 'Auteur inconnu';

  @override
  String libraryTileProgress(Object downloaded, Object total) {
    return '$downloaded sur $total téléchargés';
  }

  @override
  String get libraryTileUndownloaded => 'Pas encore téléchargé';

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
  String get libraryTitle => 'Bibliothèque';

  @override
  String libraryUnopenedBadgeSemantics(int count) {
    return '$count chapitres que vous n\'avez pas ouverts';
  }

  @override
  String get navBrowse => 'Parcourir';

  @override
  String get navDownloads => 'Téléchargements';

  @override
  String get navHistory => 'Historique';

  @override
  String get navLibrary => 'Bibliothèque';

  @override
  String get navMore => 'Plus';

  @override
  String get navSettings => 'Paramètres';

  @override
  String get navUpdates => 'Mises à jour';

  @override
  String get novelDetailsTitle => 'Roman';

  @override
  String get onboardingButtonNext => 'Suivant';

  @override
  String get onboardingButtonSkip => 'Passer';

  @override
  String get onboardingButtonStart => 'Commencer à lire';

  @override
  String get onboardingStep1Body =>
      'Gardez un roman ici une fois et il s\'ouvre, connexion coupée — dans un train, dans un avion, sans DATA consommée. Rien n\'est envoyé : il n\'y a pas de compte, pas de serveur, et rien ne part.';

  @override
  String get onboardingStep1Headline => 'Il lit sans réseau.';

  @override
  String get onboardingStep1Kicker => 'LUMEN TALE';

  @override
  String get onboardingStep2Headline => 'Il n\'y a aucune sauvegarde.';

  @override
  String get onboardingStep2Kicker => 'AVANT DE COMMENCER';

  @override
  String onboardingStepPosition(int current, int total) {
    return 'Étape $current sur $total';
  }

  @override
  String queueCancelBody(Object kept) {
    return 'Les $kept chapitres déjà téléchargés sont conservés. Aucun autre n\'est récupéré.';
  }

  @override
  String queueCancelBodyWithChapter(Object kept, Object name) {
    return '« $name » est en cours de téléchargement. Il sera abandonné. Les $kept chapitres déjà téléchargés sont conservés.';
  }

  @override
  String get queueCancelConfirm => 'Annuler le téléchargement';

  @override
  String get queueCancelTitle => 'Annuler ce téléchargement ?';

  @override
  String get queueCauseItemRemovedAtSource =>
      'Le site indique que ce chapitre a été supprimé.';

  @override
  String get queueCauseNoConnection =>
      'La connexion a été interrompue pendant le téléchargement de ce chapitre.';

  @override
  String get queueCauseNoRealText =>
      'Ce chapitre n\'avait aucun texte lisible sur la page.';

  @override
  String get queueCauseParseFailed =>
      'Le texte de ce chapitre n\'a pas pu être composé.';

  @override
  String get queueCauseRateLimited => 'Le site nous a demandé de ralentir.';

  @override
  String get queueCauseSourceEmpty =>
      'Le site n\'a rien publié pour ce chapitre.';

  @override
  String get queueCauseSourceLayoutChanged =>
      'Ce site a changé de mise en page : l\'application ne peut plus le lire.';

  @override
  String get queueCauseSourceUnavailable =>
      'Le site de ce roman n\'est pas dans cette version de l\'application.';

  @override
  String get queueCauseStorageFull => 'Le téléphone n\'a plus de stockage.';

  @override
  String get queueCauseUnknown =>
      'L\'application ne peut pas dire ce qui a échoué.';

  @override
  String get readerActionBack => 'Revenir';

  @override
  String get readerActionDownloadAgain => 'Télécharger à nouveau';

  @override
  String get readerActionDownloadChapter => 'Télécharger ce chapitre';

  @override
  String get readerActionOpenDownloads => 'Ouvrir les téléchargements';

  @override
  String get readerActionRetry => 'Réessayer';

  @override
  String readerChapterNumber(String number) {
    return 'Chapitre $number';
  }

  @override
  String get readerChapterNumberUnreadable => 'Chapitre';

  @override
  String get readerDownloadNeedsConnection =>
      'Télécharger nécessite une connexion';

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
  String get readerFileEmptyBody =>
      'Rien n\'a été enregistré, donc il n\'y a rien à lire.';

  @override
  String get readerFileEmptyTitle =>
      'L\'enregistrement de ce chapitre s\'est interrompu';

  @override
  String get readerFileMissingBody =>
      'Le téléchargement a réussi. C\'est le fichier qui manque.';

  @override
  String get readerFileMissingTitle =>
      'Ce chapitre avait été téléchargé, mais son texte n\'est plus sur ce téléphone';

  @override
  String get readerLoadFailedBody =>
      'L\'application ne sait pas si le fichier est intact.';

  @override
  String get readerLoadFailedTitle => 'Ce chapitre n\'a pas pu être ouvert';

  @override
  String get readerNotStoredBody =>
      'Seuls les chapitres déjà présents sur ce téléphone peuvent être lus ici.';

  @override
  String get readerNotStoredTitle => 'Ce chapitre n\'est pas téléchargé';

  @override
  String get readerOfflineAbsentBody =>
      'Il faut les deux : le chapitre doit avoir été téléchargé une fois, et un téléchargement demande une connexion.';

  @override
  String get readerOfflineAbsentTitle =>
      'Ce chapitre n\'est pas téléchargé et il n\'y a pas de connexion';

  @override
  String get readerOfflineBanner => 'Vous lisez vos téléchargements';

  @override
  String get readerRowGoneBody =>
      'Le lien a peut-être été enregistré avant le retrait du chapitre.';

  @override
  String get readerRowGoneTitle =>
      'Ce chapitre n\'existe plus dans votre bibliothèque';

  @override
  String readerSizeButtonTooltip(String name) {
    return 'Taille du texte : $name';
  }

  @override
  String readerSizePixelsSpoken(String px) {
    return '$px pixels';
  }

  @override
  String get readerSizeSheetTitle => 'Taille du texte';

  @override
  String get readerSizeStepNotSelected => 'non sélectionné';

  @override
  String readerSizeStepPoints(String px) {
    return '$px pt';
  }

  @override
  String get readerSizeStepSelected => 'sélectionné';

  @override
  String readerSizeStepSemantics(String name, String pixels, String state) {
    return '$name, $pixels, $state';
  }

  @override
  String readerThemeButtonTooltip(String name) {
    return 'Thème : $name';
  }

  @override
  String get settingsButtonCancel => 'Annuler';

  @override
  String get settingsButtonRetry => 'Réessayer';

  @override
  String get settingsDeferredFilters =>
      'Pas de filtres de couleur : sépia, niveaux de gris, inversé.';

  @override
  String get settingsDeferredFonts =>
      'Pas de choix de police : le lecteur utilise un serif, décidé une fois. Une face de lecture au choix est une candidate pour la v2, pas un contrôle de la v1.';

  @override
  String get settingsDeferredJustification =>
      'Pas de justification du texte. Un texte justifié à cette longueur de ligne crée des rivières, bien pires qu\'une bordure irrégulière.';

  @override
  String get settingsDeferredLineHeight =>
      'Pas de réglage d\'interligne. Il est maintenu à 1,72 à toutes les tailles, volontairement, pour que le rythme ne change pas avec la taille.';

  @override
  String get settingsDeferredModes =>
      'Pas de mode de lecture : la lecture est un défilement continu unique.';

  @override
  String get settingsDeferredOrientation =>
      'Pas de verrouillage d\'orientation.';

  @override
  String get settingsDeferredParagraphSpacing =>
      'Pas de réglage de l\'espacement des paragraphes : l\'interligne de 1,72 fixe déjà le rythme.';

  @override
  String get settingsDeferredSwipe =>
      'Pas de changement de page par balayage ou toucher.';

  @override
  String get settingsDialogClearHistoryBody =>
      'Les positions de lecture ne font pas partie de cette liste et ne seront pas touchées.';

  @override
  String get settingsDialogClearHistoryConfirm => 'Effacer';

  @override
  String settingsDialogClearHistoryTitle(String count) {
    return 'Effacer $count entrées ?';
  }

  @override
  String get settingsDisclosureAboutLink => 'Ce qui survit à une mise à jour';

  @override
  String get settingsDisclosureE11 =>
      'Rien ici n\'est sauvegardé. Si vous désinstallez Lumen Tale ou perdez ce téléphone, votre bibliothèque, vos téléchargements et vos positions de lecture sont perdus, et aucune copie n\'existe ailleurs.';

  @override
  String get settingsDisclosureE11Footer =>
      'L\'application ne peut pas vous avertir au moment où vous désinstallez : c\'est le téléphone qui le fait, en dehors de l\'application. C\'est donc dit ici, avant, plutôt qu\'après.';

  @override
  String get settingsErrorCountUnavailable => 'Nombre indisponible';

  @override
  String get settingsErrorWrite =>
      'Ce paramètre n\'a pas pu être enregistré. Rien n\'a été modifié.';

  @override
  String get settingsGroupApp => 'APPLICATION';

  @override
  String get settingsGroupDeferred => 'PAS DANS CETTE VERSION';

  @override
  String get settingsGroupHistory => 'HISTORIQUE';

  @override
  String get settingsGroupReading => 'LECTURE';

  @override
  String get settingsGroupSize => 'TAILLE DU TEXTE';

  @override
  String get settingsGroupTheme => 'THÈME';

  @override
  String get settingsLanguageEnglish => 'English';

  @override
  String get settingsLanguageFrench => 'Français';

  @override
  String get settingsRowAboutLabel => 'À propos de Lumen Tale';

  @override
  String settingsRowAboutValue(String buildName, String buildNumber) {
    return 'Version $buildName · build $buildNumber';
  }

  @override
  String get settingsRowAppearanceLabel => 'Apparence du lecteur';

  @override
  String settingsRowAppearanceValue(String theme, String size, String pt) {
    return '$theme · $size ($pt pt)';
  }

  @override
  String get settingsRowClearHistoryLabel => 'Effacer l\'historique de lecture';

  @override
  String get settingsRowHistoryLabel => 'Historique de lecture';

  @override
  String settingsRowHistoryValue(String count, String relative) {
    return '$count entrées · la plus ancienne $relative';
  }

  @override
  String get settingsRowHistoryValueEmpty => '0 entrée';

  @override
  String get settingsRowLanguageHint =>
      'Suit votre téléphone. Changez-la dans les paramètres de langue d\'Android.';

  @override
  String get settingsRowLanguageLabel => 'Langue';

  @override
  String get settingsRowOnboardingLabel =>
      'Comment fonctionne cette application';

  @override
  String get settingsRowOnboardingValue =>
      'Revoir les deux écrans d\'introduction';

  @override
  String get settingsRowRetentionLabel => 'Conserver l\'historique pendant';

  @override
  String get settingsSizeLg => 'Grand';

  @override
  String get settingsSizeMd => 'Moyen';

  @override
  String get settingsSizeSm => 'Petit';

  @override
  String get settingsSizeXl => 'Plus grand';

  @override
  String get settingsSizeXxl => 'Le plus grand';

  @override
  String get settingsSnackHistoryCleared =>
      'Historique de lecture effacé. Vos positions de lecture ont été conservées.';

  @override
  String settingsSpecimenCredit(String novel, String chapter) {
    return 'Extrait de « $novel » · $chapter';
  }

  @override
  String get settingsSpecimenEmptyNote =>
      'Vous n\'avez encore rien téléchargé : c\'est ainsi que le lecteur se comportera.';

  @override
  String get settingsSpecimenSeedFailed =>
      'Un chapitre enregistré sur ce téléphone n\'a pas pu être lu. Un exemple est affiché à la place.';

  @override
  String get settingsThemeDay => 'Jour';

  @override
  String get settingsThemeNight => 'Nuit';

  @override
  String get settingsThemeSystem => 'Suivre le téléphone';

  @override
  String get settingsTitle => 'Réglages';

  @override
  String sourceUnavailableRetryIn(Object seconds) {
    return 'Réessayer dans $seconds s';
  }

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
  String get sourceUnavailableStillWorksHeading => 'Ce qui fonctionne toujours';

  @override
  String sourceUnavailableWaitingForSite(Object seconds) {
    return 'Le site nous a demandé d\'attendre $seconds s.';
  }

  @override
  String unitBytes(Object count) {
    return '$count o';
  }

  @override
  String unitGigabytes(Object count) {
    return '$count Go';
  }

  @override
  String unitKilobytes(Object count) {
    return '$count Ko';
  }

  @override
  String unitMegabytes(Object count) {
    return '$count Mo';
  }

  @override
  String get warningNotifications =>
      'Les notifications sont désactivées dans les réglages du téléphone.';
}
