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
}
