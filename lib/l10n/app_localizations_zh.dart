// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => 'Like it!';

  @override
  String get photo => '照片';

  @override
  String get video => '视频';

  @override
  String get softness => '柔嫩';

  @override
  String get beauty => '美白';

  @override
  String get brightness => '亮度';

  @override
  String get contrast => '对比度';

  @override
  String get saturation => '饱和度';

  @override
  String get glow => '光晕';

  @override
  String get swipeToChangeFilter => '滑动切换滤镜';

  @override
  String get original => '原图';

  @override
  String timerSeconds(int seconds) {
    return '$seconds秒';
  }

  @override
  String get settings => '设置';

  @override
  String get camera => '相机';

  @override
  String get silentShutter => '静音快门';

  @override
  String get silentShutterSubtitle => '无声拍摄 (1920×1080)';

  @override
  String get appInfo => '应用信息';

  @override
  String get version => '版本';

  @override
  String get privacyPolicy => '隐私政策';

  @override
  String get termsOfService => '使用条款';

  @override
  String get contactUs => '联系我们';

  @override
  String get contactEmailSubject => 'Like it! 咨询';

  @override
  String get filterLibrary => '滤镜库';

  @override
  String get favorites => '收藏';

  @override
  String get noFavoriteFilters => '暂无收藏滤镜';

  @override
  String get reset => '重置';

  @override
  String get deletePhoto => '删除照片';

  @override
  String get deletePhotoConfirm => '从相册删除这张照片？';

  @override
  String get cancel => '取消';

  @override
  String get delete => '删除';

  @override
  String get saving => '保存中...';

  @override
  String get savedToGallery => '已保存到相册';

  @override
  String get saveFailed => '保存失败';

  @override
  String get freeform => '自由';

  @override
  String get square => '正方形';

  @override
  String get apply => '应用';

  @override
  String get filterTab => '滤镜';

  @override
  String get effectTab => '效果';

  @override
  String get cropTab => '裁剪';

  @override
  String get preparingShare => '准备分享...';

  @override
  String get shareFailed => '分享失败';

  @override
  String get fileNotFound => '找不到文件';

  @override
  String get onboardingTagline => '一键拍出\n好看的照片。';

  @override
  String get getStarted => '开始使用';
}
