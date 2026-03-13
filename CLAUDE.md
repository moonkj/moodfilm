# Like it! — CLAUDE.md
> 이 파일은 Claude Code가 세션 간 컨텍스트를 유지하기 위한 프로젝트 규칙서입니다.

---

## ⚠️ 필수 워크플로우 (코드 수정 시 반드시 실행)

**코드를 수정한 모든 세션은 반드시 아래 순서로 마무리한다. 빠뜨리면 세션이 완료된 것이 아니다.**

### 세션 종료 체크리스트
1. **PROCESS.md 헤더 업데이트**: `마지막 업데이트: 세션 N` → `세션 N+1`
2. **PROCESS.md 세션 내용 추가**: 변경 파일, 문제/해결, 설치 기록 등
3. **git add + git commit**: 수정된 파일 전체 (PROCESS.md 포함)

### 세션 번호 규칙
- PROCESS.md 상단 `마지막 업데이트` 줄에서 현재 세션 번호 확인
- 코드 변경이 있으면 +1 올려서 기록

> 사용자가 명시적으로 요청하지 않아도, 코드 수정 후 이 체크리스트를 자동으로 실행한다.

---

## 프로젝트 개요

**앱 이름:** Like it! (구 MoodFilm)
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
| 폰트 | google_fonts ^6.2.1 (Nunito — 앱 타이틀용) |
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

- 총 26종 (Warm / Cool / Film / Aesthetic 각 5~8종)
- 무료/Pro 구분 없음 — 앱 1회 구매 시 전체 26종 사용 가능
- FilterModel.isPro 필드는 내부 관리용으로만 존재 (UI 잠금 표시 불필요)
- LUT 파일: `assets/luts/*.cube` (33×33×33 3D LUT)
- 썸네일: `assets/thumbnails/<filterId>.jpg` (60x60pt)
- 필터 강도: 0.0 ~ 1.0, 마지막 강도 Hive에 저장 (`UserPreferences.filterIntensities`)
- 시그니처 이펙트: **Dreamy Glow** (CIBloom + Gaussian Blur) — 절대 삭제 금지

### 이펙트 시스템 (카메라 실시간)
| effectType 키 | 한국어 | 범위 | Swift 프로퍼티 |
|---|---|---|---|
| `brightness` | 밝기 | -1.0~1.0 | `brightnessIntensity` |
| `contrast` | 대비 | -1.0~1.0 | `contrastIntensity` |
| `saturation` | 채도 | -1.0~1.0 | `saturationIntensity` |
| `softness` | 솜결 | 0.0~1.0 | `softnessIntensity` |
| `beauty` | 뽀얀 | 0.0~1.0 | `beautyIntensity` |
| `glow` / `dreamyGlow` | 글로우 | 0.0~1.0 | `glowIntensity` |
| `filmGrain` | 필름그레인 | 0.0~1.0 | `grainIntensity` |
| `lightLeak` | 라이트릭 | 0.0~1.0 | `lightLeakIntensity` |

- 카메라 시작 시 기본값: 솜결 30%, 뽀얀 25% (`_applyDefaultEffects()`)
- `"glow"` 와 `"dreamyGlow"` 는 동일하게 처리 (두 키 모두 허용)

---

## 수익 모델

| 플랜 | 가격 | 비고 |
|------|------|------|
| 앱 1회 구매 | ₩2,200 | 전체 26종 필터 영구 사용 |

- 구독 없음, 무료 체험 없음 — 앱 구매 = 전체 기능 즉시 사용
- RevenueCat product ID: `lifetime`, entitlement ID: `pro`
- `UserPreferences.isProUser` boolean으로 구매 여부 관리
- paywall_screen.dart 가격 표시: ₩2,200

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
3. **Pretendard 폰트**: `assets/fonts/` 에 `.otf` 파일 4개 직접 추가 필요 (라이선스: OFL) — 미추가 시 시스템 폰트 사용
4. **LUT 파일**: `assets/luts/` 에 30종 `.cube` 파일 존재 (33×33×33 포맷)
5. **riverpod_generator 미사용**: hive_generator ^2.0.1과 analyzer 버전 충돌로 제외. Provider는 모두 수동 작성
6. **iOS 최소 버전**: iOS 16.0 (W11에서 17→16 변경). Podfile `platform :ios, '16.0'`
7. **앱 이름 변경**: 표시명 "Like it!", Bundle ID는 `com.moodfilm.moodfilm` 유지 (App Store 연동)
8. **Dart 패키지명**: `pubspec.yaml name: moodfilm` 유지 — 변경 시 모든 `package:moodfilm/` import 수정 필요
9. **실기기 설치**: `flutter build ios --release` → `xcrun devicectl device install app --device 00008150-001128391EF0401C build/ios/iphoneos/Runner.app`
10. **갤러리 배치 필터 저장**: `FilterEngine.processImage()` 호출 시 `saveToGallery: true` 명시 필요 (기본값 false)

---

## 개발 워크플로우 (역할 기반)

모든 기능 구현 요청은 아래 순서로 진행한다. 각 단계의 산출물을 명확히 출력한 뒤 다음 단계로 이동.

> **기본 진행**: (1) UX → (2) 설계자 → (3) 코드 작성자 → (4) 디버거 → (5) 테스트 작성자 → (6) 리뷰어
> **성능/최적화 요청 시**: (6) 리뷰어 앞에 (7) 성능·최적화 담당 추가
> **문서화 요청 시**: (6) 리뷰어 뒤에 (8) 문서화 담당 추가

### (1) UX 설계자 (UX Designer)
- 사용자 시나리오와 유저 플로우를 정의한다.
- 각 화면의 목표, 필요한 정보, 주요 액션을 와이어프레임 수준으로 설명한다.
- 빈 상태, 로딩, 에러 등 예외적인 UX 상태를 미리 정의한다.
- 사용자가 가장 쉽게 수행해야 할 핵심 행동의 우선순위를 정한다.
- UX 설계가 필요 없을 시 바로 설계자로 이동한다.

### (2) 설계자 (Architect)
- 사용자의 요청을 분석한다.
- 핵심 기능, 요구사항, 입·출력 정의, 기술 스택, 구현 단계를 계획한다.
- 구체적이고 실행 가능한 설계안을 목록 형태로 작성한다.
- 산출물: "설계 요약"

### (3) 코드 작성자 (Coder)
- 설계자의 계획에 따라 실제 코드를 작성한다.
- 코드는 완전하게 실행 가능한 형태로 제시하며, 필요 시 간단한 주석만 포함한다.
- 기존 컨벤션(AppColors, Riverpod 패턴 등) 준수.
- 산출물: 코드 블록 (Swift / Dart 등)

### (4) 코드 디버거 (Debugger)
- 코드 작성자의 결과를 세밀히 점검한다.
- 논리 오류, 실행 오류, 예외 상황, 미처 처리되지 않은 조건 등을 분석한다.
- 문제점을 목록화하고, 수정이 필요한 부분을 제안한다. 수정 후 코드 작성자 단계로 복귀.
- 오류 없으면 이 단계 생략.
- 산출물: "버그 리포트 및 수정 제안"

### (5) 테스트 작성자 (Test Engineer, 선택)
- 버그 가능성이 높거나 중요한 로직을 테스트 대상으로 선정한다.
- 단위 테스트, 위젯 테스트, 통합 테스트 중 적합한 방식을 제안한다.
- 핵심 시나리오에 대한 테스트 코드 예시 또는 테스트 케이스(입력–기대 결과)를 작성한다.
- 향후 리팩터링 시 동작을 보장할 수 있는 안전망을 설계한다.
- 테스트 문제 시 다시 디버거로 이동한다.

### (6) 리뷰어 (Reviewer)
- 최종 코드를 품질 관점(가독성, 유지보수성, 확장성)에서 검토한다.
- "좋은 점"과 "개선할 부분"을 각각 항목별로 정리한다.
- **개선할 부분이 존재하면 즉시 설계자(2단계)로 복귀하여 개선 사이클을 다시 수행한다.**
  - 개선 사이클 재진입 시 출력 헤더에 `(개선 R2)`, `(개선 R3)` 등 라운드를 표기한다.
  - 개선할 부분이 없을 때만 최종 완료로 처리한다.
- 산출물: "코드 리뷰 결과"

### (7) 성능·최적화 담당 (Performance Engineer)
- 렌더링/리빌드 횟수, 비동기 처리, 캐싱 전략 점검.
- Flutter: `ListView.builder`, `const` 위젯, 상태 범위 최소화 등.
- API: 디바운싱, pagination, lazy loading, 캐시.
- 성능/최적화 관련 요청 시에만 역할 수행. 리뷰어(6) 전에 진행.

### (8) 문서화 담당 (Doc Writer)
- 클래스/위젯 역할, 주요 의존성, 설정 방법, 주의사항을 짧게 정리.
- GitHub README 또는 Notion에 바로 복붙 가능한 형태로 작성.
- 최종 정리 요청 시에만 역할 수행.
