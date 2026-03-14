class AppDimensions {
  AppDimensions._();

  // 서터 버튼
  static const double shutterButtonSize = 76.0;
  static const double shutterButtonInner = 64.0;

  // 필터 썸네일 (직사각형, 세로 비율 3:4)
  static const double filterThumbnailWidth = 52.0;
  static const double filterThumbnailHeight = 70.0;
  static const double filterThumbnailWidthSelected = 58.0;
  static const double filterThumbnailHeightSelected = 78.0;
  // 하위 호환 (정사각형 사용처 대비)
  static const double filterThumbnailSize = 52.0;
  static const double filterThumbnailSizeSelected = 58.0;

  // 하단 필터 바 (선택된 필터 78 + 간격 4 + 텍스트 2줄 28 + 여유 2 = 112, 패딩 8 포함 → 120)
  static const double filterBarHeight = 120.0;
  static const double filterBarPaddingV = 4.0;

  // 갤러리 썸네일 (카메라 화면 우측 하단)
  static const double galleryThumbnailSize = 44.0;

  // 상단 컨트롤 바
  static const double topBarHeight = 56.0;

  // 최소 터치 타겟 (접근성)
  static const double minTouchTarget = 44.0;

  // 카드 radius
  static const double cardRadius = 16.0;
  static const double chipRadius = 100.0; // pill

  // 슬라이더
  static const double sliderTrackHeight = 2.0;
  static const double sliderThumbSize = 20.0;

  // Glassmorphism blur
  static const double glassBlurLight = 12.0;
  static const double glassBlurHeavy = 20.0;

  // 패딩
  static const double paddingS = 8.0;
  static const double paddingM = 16.0;
  static const double paddingL = 24.0;
}
