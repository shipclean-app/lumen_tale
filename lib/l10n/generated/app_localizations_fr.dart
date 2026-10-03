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
}
