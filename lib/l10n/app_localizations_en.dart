// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Like it!';

  @override
  String get photo => 'Photo';

  @override
  String get video => 'Video';

  @override
  String get softness => 'Softness';

  @override
  String get beauty => 'Beauty';

  @override
  String get brightness => 'Brightness';

  @override
  String get contrast => 'Contrast';

  @override
  String get saturation => 'Saturation';

  @override
  String get glow => 'Glow';

  @override
  String get swipeToChangeFilter => 'Swipe to change filter';

  @override
  String get original => 'Original';

  @override
  String timerSeconds(int seconds) {
    return '${seconds}s';
  }

  @override
  String get settings => 'Settings';

  @override
  String get camera => 'Camera';

  @override
  String get silentShutter => 'Silent Shutter';

  @override
  String get silentShutterSubtitle =>
      'Take photos without shutter sound (1920×1080)';

  @override
  String get appInfo => 'App Info';

  @override
  String get version => 'Version';

  @override
  String get privacyPolicy => 'Privacy Policy';

  @override
  String get termsOfService => 'Terms of Service';

  @override
  String get contactUs => 'Contact Us';

  @override
  String get contactEmailSubject => 'Like it! Inquiry';

  @override
  String get filterLibrary => 'Filter Library';

  @override
  String get favorites => 'Favorites';

  @override
  String get noFavoriteFilters => 'No favorite filters yet';

  @override
  String get reset => 'Reset';

  @override
  String get deletePhoto => 'Delete Photo';

  @override
  String get deletePhotoConfirm => 'Delete this photo from gallery?';

  @override
  String get cancel => 'Cancel';

  @override
  String get delete => 'Delete';

  @override
  String get saving => 'Saving...';

  @override
  String get savedToGallery => 'Saved to gallery';

  @override
  String get saveFailed => 'Failed to save';

  @override
  String get freeform => 'Free';

  @override
  String get square => 'Square';

  @override
  String get apply => 'Apply';

  @override
  String get filterTab => 'Filter';

  @override
  String get effectTab => 'Effect';

  @override
  String get cropTab => 'Crop';

  @override
  String get preparingShare => 'Preparing to share...';

  @override
  String get shareFailed => 'Share failed';

  @override
  String get fileNotFound => 'File not found';

  @override
  String get onboardingTagline => 'One tap.\nBeautiful photos.';

  @override
  String get getStarted => 'Get Started';
}
