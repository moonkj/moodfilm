// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Japanese (`ja`).
class AppLocalizationsJa extends AppLocalizations {
  AppLocalizationsJa([String locale = 'ja']) : super(locale);

  @override
  String get appTitle => 'Like it!';

  @override
  String get photo => '写真';

  @override
  String get video => '動画';

  @override
  String get softness => 'なめらか';

  @override
  String get beauty => '美肌';

  @override
  String get brightness => '明るさ';

  @override
  String get contrast => 'コントラスト';

  @override
  String get saturation => '彩度';

  @override
  String get glow => 'グロー';

  @override
  String get swipeToChangeFilter => 'スワイプでフィルター変更';

  @override
  String get original => 'オリジナル';

  @override
  String timerSeconds(int seconds) {
    return '$seconds秒';
  }

  @override
  String get settings => '設定';

  @override
  String get camera => 'カメラ';

  @override
  String get silentShutter => 'サイレントシャッター';

  @override
  String get silentShutterSubtitle => 'シャッター音なしで撮影 (1920×1080)';

  @override
  String get appInfo => 'アプリ情報';

  @override
  String get version => 'バージョン';

  @override
  String get privacyPolicy => 'プライバシーポリシー';

  @override
  String get termsOfService => '利用規約';

  @override
  String get contactUs => 'お問い合わせ';

  @override
  String get contactEmailSubject => 'Like it! お問い合わせ';

  @override
  String get filterLibrary => 'フィルターライブラリ';

  @override
  String get favorites => 'お気に入り';

  @override
  String get noFavoriteFilters => 'お気に入りフィルターがありません';

  @override
  String get reset => 'リセット';

  @override
  String get deletePhoto => '写真を削除';

  @override
  String get deletePhotoConfirm => 'ギャラリーからこの写真を削除しますか？';

  @override
  String get cancel => 'キャンセル';

  @override
  String get delete => '削除';

  @override
  String get saving => '保存中...';

  @override
  String get savedToGallery => 'ギャラリーに保存しました';

  @override
  String get saveFailed => '保存に失敗しました';

  @override
  String get freeform => 'フリー';

  @override
  String get square => '正方形';

  @override
  String get apply => '適用';

  @override
  String get filterTab => 'フィルター';

  @override
  String get effectTab => 'エフェクト';

  @override
  String get cropTab => 'トリミング';

  @override
  String get preparingShare => '共有の準備中...';

  @override
  String get shareFailed => '共有に失敗しました';

  @override
  String get fileNotFound => 'ファイルが見つかりません';

  @override
  String get onboardingTagline => 'ワンタップで\nキレイな写真に。';

  @override
  String get getStarted => 'はじめる';

  @override
  String selectedCount(int count) {
    return '$count件選択済み';
  }

  @override
  String get select => '選択';

  @override
  String get album => 'アルバム';

  @override
  String get selectFilter => 'フィルターを選択';

  @override
  String get galleryPermissionRequired => 'ギャラリーへのアクセス許可が必要です';

  @override
  String get allowInSettings => '設定で許可する';

  @override
  String get noPhotos => '写真がありません';

  @override
  String deleteCountTitle(int count) {
    return '$count件を削除';
  }

  @override
  String get deleteSelectedConfirm => '選択したアイテムをギャラリーから削除します。\nこの操作は取り消せません。';

  @override
  String deletedCount(int count) {
    return '$count件を削除しました';
  }

  @override
  String batchSavedCount(int count) {
    return '$count枚をギャラリーに保存しました';
  }

  @override
  String processingProgress(int processed, int total) {
    return '$processed / $total 処理中...';
  }
}
