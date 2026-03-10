// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Hindi (`hi`).
class AppLocalizationsHi extends AppLocalizations {
  AppLocalizationsHi([String locale = 'hi']) : super(locale);

  @override
  String get appTitle => 'Like it!';

  @override
  String get photo => 'फ़ोटो';

  @override
  String get video => 'वीडियो';

  @override
  String get softness => 'सॉफ्टनेस';

  @override
  String get beauty => 'ब्यूटी';

  @override
  String get brightness => 'ब्राइटनेस';

  @override
  String get contrast => 'कंट्रास्ट';

  @override
  String get saturation => 'सेचुरेशन';

  @override
  String get glow => 'ग्लो';

  @override
  String get swipeToChangeFilter => 'फ़िल्टर बदलने के लिए स्वाइप करें';

  @override
  String get original => 'ओरिजिनल';

  @override
  String timerSeconds(int seconds) {
    return '${seconds}s';
  }

  @override
  String get settings => 'सेटिंग्स';

  @override
  String get camera => 'कैमरा';

  @override
  String get silentShutter => 'साइलेंट शटर';

  @override
  String get silentShutterSubtitle => 'बिना आवाज़ के फ़ोटो लें (1920×1080)';

  @override
  String get appInfo => 'ऐप जानकारी';

  @override
  String get version => 'वर्शन';

  @override
  String get privacyPolicy => 'गोपनीयता नीति';

  @override
  String get termsOfService => 'सेवा की शर्तें';

  @override
  String get contactUs => 'संपर्क करें';

  @override
  String get contactEmailSubject => 'Like it! पूछताछ';

  @override
  String get filterLibrary => 'फ़िल्टर लाइब्रेरी';

  @override
  String get favorites => 'पसंदीदा';

  @override
  String get noFavoriteFilters => 'कोई पसंदीदा फ़िल्टर नहीं';

  @override
  String get reset => 'रीसेट';

  @override
  String get deletePhoto => 'फ़ोटो हटाएं';

  @override
  String get deletePhotoConfirm => 'गैलरी से यह फ़ोटो हटाएं?';

  @override
  String get cancel => 'रद्द करें';

  @override
  String get delete => 'हटाएं';

  @override
  String get saving => 'सेव हो रहा है...';

  @override
  String get savedToGallery => 'गैलरी में सेव हुआ';

  @override
  String get saveFailed => 'सेव नहीं हुआ';

  @override
  String get freeform => 'फ्री';

  @override
  String get square => 'स्क्वेयर';

  @override
  String get apply => 'लागू करें';

  @override
  String get filterTab => 'फ़िल्टर';

  @override
  String get effectTab => 'इफ़ेक्ट';

  @override
  String get cropTab => 'क्रॉप';

  @override
  String get preparingShare => 'शेयर की तैयारी...';

  @override
  String get shareFailed => 'शेयर नहीं हुआ';

  @override
  String get fileNotFound => 'फ़ाइल नहीं मिली';

  @override
  String get onboardingTagline => 'एक टैप में\nखूबसूरत तस्वीरें।';

  @override
  String get getStarted => 'शुरू करें';
}
