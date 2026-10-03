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
}
