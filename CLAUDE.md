# MoodFilm — CLAUDE.md
> 이 파일은 Claude Code가 세션 간 컨텍스트를 유지하기 위한 프로젝트 규칙서입니다.

---

## 프로젝트 개요

**앱 이름:** MoodFilm
**설명:** 감성 필터 카메라 앱 — "한 번의 탭으로, 내 사진이 예뻐지는 경험"
**타겟:** 15-25세 여성, 인스타그램/틱톡, 셀카 중심, 한국 감성
**개발 형태:** 1인 개발
**플랫폼:** iOS 우선 → 런칭 후 3개월 뒤 Android
**최소 iOS 버전:** iOS 17.0

---

## 기술 스택

| 영역 | 기술 |
|------|------|
| 프레임워크 | Flutter 3.41.2 (Dart 3.11.0) |
| 상태관리 | flutter_riverpod ^2.6.1 (StateNotifierProvider, 코드 gen 없음) |
| 라우팅 | go_router ^14.6.3 |
| 로컬 저장 | hive_flutter ^1.1.0 + hive_generator ^2.0.1 |
| 인앱결제 | purchases_flutter ^8.7.0 (RevenueCat) |
| 분석/크래시 | firebase_core + firebase_analytics + firebase_crashlytics |
| 이미지 | photo_manager ^3.6.3, share_plus ^10.1.4 |
| 코드 gen | build_runner ^2.4.13 |
| iOS 카메라 | AVFoundation + CIFilter + MTKView (Native Plugin) |
| iOS 필터 | CIColorCube LUT (.cube 포맷) + Metal |
| Method Channel | com.moodfilm/camera_engine, com.moodfilm/filter_engine |

---

## 폴더 구조 규칙

Feature-first 아키텍처를 따릅니다.

```
lib/
├── main.dart                    # 앱 진입점 (Hive init, ProviderScope)
├── app.dart                     # MaterialApp.router
├── core/
│   ├── constants/               # AppColors, AppTypography, AppDimensions
│   ├── models/                  # Hive 모델 (FilterModel, EffectType, UserPreferences)
│   ├── services/                # StorageService, router.dart
│   ├── theme/                   # AppTheme, LiquidGlassContainer
│   └── utils/                   # HapticUtils
├── features/
│   ├── camera/                  # 카메라 촬영 화면 (메인)
│   ├── editor/                  # 편집 화면
│   ├── filter_library/          # 필터 라이브러리
│   ├── onboarding/              # 온보딩 + Paywall
│   └── settings/                # 설정
└── native_plugins/
    ├── camera_engine/           # CameraEngine Method Channel (Flutter 측)
    └── filter_engine/           # FilterEngine Method Channel (Flutter 측)

ios/Runner/
├── NativeCamera/
│   ├── MFLUTEngine.swift        # LUT 파싱 + CIColorCube + 이펙트 파이프라인
│   ├── MFCameraSession.swift    # AVFoundation 캡처 세션
│   ├── MFCameraPreview.swift    # FlutterTexture 렌더러
│   └── CameraEnginePlugin.swift # FlutterPlugin (Method Channel 핸들러)
└── FilterEngine/                # (W5 예정) 편집화면 Full-res 처리
```

---

## 코딩 규칙

### Dart/Flutter
- StateNotifier 직접 작성 (riverpod_generator 사용 안 함 — hive_generator와 analyzer 충돌)
- `withOpacity()` 대신 `withValues(alpha: ...)` 사용 (Flutter 3.x 권장)
- const 위젯 최대 활용
- 파일당 단일 책임: 화면/위젯/provider/model 분리
- Hive 모델 변경 시 반드시 `build_runner build` 실행

### Swift (iOS)
- `MFLUTEngine.ciContext` 는 싱글톤 — 절대 재생성하지 않음
- CIFilter 체인은 render() 직전까지 lazy evaluation 활용
- 모든 카메라 세션 작업은 `sessionQueue` (백그라운드 DispatchQueue)에서 실행
- UI 업데이트는 반드시 `DispatchQueue.main.async`

### 디자인 토큰 (항상 상수 사용)
```dart
AppColors.primary      // #FBF5EE 크림 화이트
AppColors.accent       // #C8A2D0 라벤더
AppColors.cameraBg     // #000000
AppColors.textPrimary  // #3D3531
AppColors.proBadge     // #D4A574 골드
```

---

## 필터 시스템 규칙

- MVP 20종 고정 (Warm 5 / Cool 5 / Film 5 / Aesthetic 5)
- 무료 8종: Milk, Cream, Sky, Cloud, Film98, Disposable, Soft Pink, Lavender
- Pro 12종: 나머지 전부
- LUT 파일: `assets/luts/*.cube` (64x64x64 3D LUT, 약 1.5MB/개)
- 썸네일: `assets/thumbnails/<filterId>.jpg` (60x60pt)
- 필터 강도: 0.0 ~ 1.0, 마지막 강도 Hive에 저장 (`UserPreferences.filterIntensities`)
- 시그니처 이펙트: **Dreamy Glow** (CIBloom + Gaussian Blur) — 절대 삭제 금지

---

## 수익 모델

| 플랜 | 가격 | RevenueCat ID |
|------|------|---------------|
| Free | 무료 | - |
| Pro (1회 구매) | ₩29,900 | `lifetime` |

- 구독 없음, 1회 구매로 모든 필터 영구 사용
- RevenueCat entitlement ID: `pro`
- `UserPreferences.isProUser` boolean으로 잠금 해제 관리

---

## 라우트 목록

| 경로 | 이름 | 화면 |
|------|------|------|
| `/` | camera | CameraScreen (메인) |
| `/editor` | editor | EditorScreen (extra: imagePath) |
| `/library` | library | FilterLibraryScreen |
| `/settings` | settings | SettingsScreen |
| `/onboarding` | onboarding | OnboardingScreen |
| `/paywall` | paywall | PaywallScreen (extra: source) |

---

## Hive typeId 테이블

| 타입 | typeId |
|------|--------|
| FilterCategory (enum) | 0 |
| FilterModel | 1 |
| EffectType (enum) | 2 |
| UserPreferences | 3 |

새 Hive 타입 추가 시 typeId 4부터 순차 할당.

---

## 성능 목표 (W10 테스트 기준)

| 항목 | 목표 |
|------|------|
| 실시간 프리뷰 | 30fps 이상 (iPhone 12+) |
| 사진 캡처 | < 0.5초 |
| 필터 전환 | < 100ms |
| 메모리 사용 | < 150MB |
| 앱 시작 | < 2초 |
| 앱 크기 (초기 다운로드) | < 25MB |

---

## 빌드 명령어

```bash
# 패키지 설치
flutter pub get

# Hive 어댑터 코드 생성 (모델 변경 시 필수)
flutter pub run build_runner build --delete-conflicting-outputs

# 정적 분석
flutter analyze

# iOS 실기기 실행
flutter run -d <device_id>

# iOS 릴리즈 빌드
flutter build ios --release
```

---

## TDD 방침

### Red → Green → Refactor 사이클
1. 🔴 **RED**: 테스트 먼저 작성 → `flutter test` 실행 → 실패 확인
2. 🟢 **GREEN**: 테스트를 통과하는 최소한의 코드 작성 → 재실행 확인
3. 🔵 **REFACTOR**: 테스트가 통과한 상태에서 코드 품질 개선

### 커버리지 목표: 70%+
```bash
flutter test --coverage
genhtml coverage/lcov.info -o coverage/html
open coverage/html/index.html
```

### 테스트 대상 우선순위
| 우선순위 | 대상 | 이유 |
|---------|------|------|
| 1 | Provider (CameraProvider, UserPreferences) | 상태 로직 핵심 |
| 2 | 모델 (FilterModel, FilterData) | 데이터 정합성 |
| 3 | 유틸 (HapticUtils, StorageService) | 순수 함수 테스트 용이 |
| 4 | Widget 스모크 테스트 | 기본 렌더링 확인 |

### 테스트 파일 위치
```
test/
├── features/
│   ├── camera/providers/camera_provider_test.dart
│   └── editor/editor_screen_test.dart
├── core/
│   ├── models/filter_model_test.dart
│   └── services/storage_service_test.dart
└── widget_test.dart
```

### 규칙
- Native Plugin (Method Channel) 호출은 `MockMethodChannel`로 대체
- Hive는 `hive_test` 패키지 또는 in-memory box 사용
- 테스트명: `한국어로 동작을 서술` (예: `'필터 선택 시 activeFilter가 업데이트된다'`)

---

## 주의사항

1. **Firebase 초기화**: `main.dart`에서 주석 처리됨. `google-services.json` / `GoogleService-Info.plist` 추가 후 활성화 필요
2. **Xcode 설정**: `ios/Runner/NativeCamera/` 폴더의 Swift 파일들을 Xcode에서 Runner 타겟에 수동 추가 필요
3. **Pretendard 폰트**: `assets/fonts/` 에 `.otf` 파일 4개 직접 추가 필요 (라이선스: OFL)
4. **LUT 파일**: W4에서 제작. 현재 `assets/luts/` 폴더는 비어있음
5. **riverpod_generator 미사용**: hive_generator ^2.0.1과 analyzer 버전 충돌로 제외. Provider는 모두 수동 작성
6. **iOS 최소 버전**: Podfile에서 `platform :ios, '17.0'` 설정 확인 필요
