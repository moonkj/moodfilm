// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Korean (`ko`).
class AppLocalizationsKo extends AppLocalizations {
  AppLocalizationsKo([String locale = 'ko']) : super(locale);

  @override
  String get appTitle => 'Like it!';

  @override
  String get photo => '사진';

  @override
  String get video => '동영상';

  @override
  String get softness => '솜결';

  @override
  String get beauty => '뽀얀';

  @override
  String get brightness => '밝기';

  @override
  String get contrast => '대비';

  @override
  String get saturation => '채도';

  @override
  String get glow => '글로우';

  @override
  String get swipeToChangeFilter => '스와이프하여 필터 변경';

  @override
  String get original => '원본';

  @override
  String timerSeconds(int seconds) {
    return '$seconds초';
  }

  @override
  String get settings => '설정';

  @override
  String get camera => '카메라';

  @override
  String get silentShutter => '무음 셔터';

  @override
  String get silentShutterSubtitle => '촬영음 없이 사진 찍기 (1920×1080 저장)';

  @override
  String get appInfo => '앱 정보';

  @override
  String get version => '버전';

  @override
  String get privacyPolicy => '개인정보처리방침';

  @override
  String get termsOfService => '이용약관';

  @override
  String get contactUs => '문의하기';

  @override
  String get contactEmailSubject => 'Like it! 문의';

  @override
  String get filterLibrary => '필터 라이브러리';

  @override
  String get favorites => '즐겨찾기';

  @override
  String get noFavoriteFilters => '즐겨찾기한 필터가 없습니다';

  @override
  String get reset => '초기화';

  @override
  String get deletePhoto => '사진 삭제';

  @override
  String get deletePhotoConfirm => '갤러리에서 이 사진을 삭제할까요?';

  @override
  String get cancel => '취소';

  @override
  String get delete => '삭제';

  @override
  String get saving => '저장 중...';

  @override
  String get savedToGallery => '갤러리에 저장되었습니다';

  @override
  String get saveFailed => '저장에 실패했습니다';

  @override
  String get freeform => '자유형';

  @override
  String get square => '정방형';

  @override
  String get apply => '적용';

  @override
  String get filterTab => '필터';

  @override
  String get effectTab => '효과';

  @override
  String get cropTab => '자르기';

  @override
  String get preparingShare => '공유 준비 중...';

  @override
  String get shareFailed => '공유에 실패했습니다';

  @override
  String get fileNotFound => '파일을 찾을 수 없습니다';

  @override
  String get onboardingTagline => '한 번의 탭으로,\n내 사진이 예뻐지는 경험';

  @override
  String get getStarted => '시작하기';

  @override
  String selectedCount(int count) {
    return '$count장 선택됨';
  }

  @override
  String get select => '선택';

  @override
  String get album => '앨범';

  @override
  String get selectFilter => '필터 선택';

  @override
  String get galleryPermissionRequired => '갤러리 접근 권한이 필요합니다';

  @override
  String get allowInSettings => '설정에서 허용하기';

  @override
  String get noPhotos => '사진이 없습니다';

  @override
  String deleteCountTitle(int count) {
    return '$count개 삭제';
  }

  @override
  String get deleteSelectedConfirm => '선택한 항목을 갤러리에서 삭제합니다.\n이 작업은 되돌릴 수 없습니다.';

  @override
  String deletedCount(int count) {
    return '$count개를 삭제했습니다';
  }

  @override
  String batchSavedCount(int count) {
    return '$count장을 갤러리에 저장했습니다';
  }

  @override
  String processingProgress(int processed, int total) {
    return '$processed / $total 처리 중...';
  }
}
