// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get appTitle => 'Like it!';

  @override
  String get photo => 'Photo';

  @override
  String get video => 'Vidéo';

  @override
  String get softness => 'Douceur';

  @override
  String get beauty => 'Éclat';

  @override
  String get brightness => 'Luminosité';

  @override
  String get contrast => 'Contraste';

  @override
  String get saturation => 'Saturation';

  @override
  String get glow => 'Glow';

  @override
  String get swipeToChangeFilter => 'Glisser pour changer de filtre';

  @override
  String get original => 'Original';

  @override
  String timerSeconds(int seconds) {
    return '${seconds}s';
  }

  @override
  String get settings => 'Paramètres';

  @override
  String get camera => 'Caméra';

  @override
  String get silentShutter => 'Obturateur silencieux';

  @override
  String get silentShutterSubtitle => 'Prendre des photos sans son (1920×1080)';

  @override
  String get appInfo => 'Infos app';

  @override
  String get version => 'Version';

  @override
  String get privacyPolicy => 'Politique de confidentialité';

  @override
  String get termsOfService => 'Conditions d\'utilisation';

  @override
  String get contactUs => 'Nous contacter';

  @override
  String get contactEmailSubject => 'Like it! Contact';

  @override
  String get filterLibrary => 'Bibliothèque de filtres';

  @override
  String get favorites => 'Favoris';

  @override
  String get noFavoriteFilters => 'Aucun filtre favori';

  @override
  String get reset => 'Réinitialiser';

  @override
  String get deletePhoto => 'Supprimer la photo';

  @override
  String get deletePhotoConfirm => 'Supprimer cette photo de la galerie ?';

  @override
  String get cancel => 'Annuler';

  @override
  String get delete => 'Supprimer';

  @override
  String get saving => 'Enregistrement...';

  @override
  String get savedToGallery => 'Enregistré dans la galerie';

  @override
  String get saveFailed => 'Échec de l\'enregistrement';

  @override
  String get freeform => 'Libre';

  @override
  String get square => 'Carré';

  @override
  String get apply => 'Appliquer';

  @override
  String get filterTab => 'Filtre';

  @override
  String get effectTab => 'Effet';

  @override
  String get cropTab => 'Recadrer';

  @override
  String get preparingShare => 'Préparation du partage...';

  @override
  String get shareFailed => 'Échec du partage';

  @override
  String get fileNotFound => 'Fichier introuvable';

  @override
  String get onboardingTagline => 'Un tap.\nDes photos magnifiques.';

  @override
  String get getStarted => 'Commencer';
}
