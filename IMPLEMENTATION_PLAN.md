# MoodFilm 상세 구현 계획서
> 계획서 v2.0 기반 + 아키텍트 검토 의견 통합
> 작성: 2026.03

---

## 1. 계획서 검토 — 강점 및 보완점

### 강점 (유지)
- BerryFilm 성공 요인 역공학 분석 탁월 — "색감 브랜드 > 필터 수" 전략 명확
- Flutter + Native Plugin 하이브리드 결정 타당 (1인 개발 현실 반영)
- LUT 파이프라인 설계 구체적 (.cube → CIColorCube 플로우)
- Liquid Glass 대응 선제적으로 반영 (경쟁사 대비 빠른 대응)
- 12주 스프린트 현실적 분배

### 보완이 필요한 부분
1. **Native Plugin 인터페이스** — Method Channel 설계가 명시 없음
2. **데이터 모델** — FilterModel, 로컬 저장 스키마 미정의
3. **상태 관리 구조** — Riverpod Provider 트리 설계 없음
4. **테스트 전략** — QA 주차에 "테스트"만 명시, 구체적 기준 없음
5. **앱 크기 관리** — LUT 30개 × 1.5MB = 45MB, 번들 전략 필요
6. **온보딩 플로우** — CTA 설계 있으나 실제 구현 스펙 없음
7. **에러 핸들링** — 카메라 권한 거부, 저장 실패 등 엣지케이스 미설계

---

## 2. 추가 아이디어 (차별화 포인트)

### [아이디어 1] "Mood Match" — on-device AI 필터 추천
- 사진/프리뷰를 Vision 프레임워크로 분석 (밝기, 색온도, 피부 영역 감지)
- 분위기에 맞는 필터 3개 자동 추천 → 상단 pill 형태로 표시
- **완전 on-device** (CoreML) — 프라이버시 강조, 서버 비용 Zero
- 구현: `VNGenerateImageFeaturePrintRequest` + cosine similarity
- 적용 시점: v1.3 (런칭 후 3개월)

### [아이디어 2] "오늘의 필터" iOS 위젯
- 홈/잠금화면 위젯 → 오늘의 추천 필터 썸네일 표시
- 탭 시 해당 필터 활성화된 상태로 카메라 바로 실행 (딥링크)
- **리텐션 드라이버** — 앱 열지 않아도 매일 노출
- 구현: WidgetKit + AppIntent (`OpenCameraWithFilterIntent`)
- 적용 시점: v1.2

### [아이디어 3] "ColorGrid" 피드 미리보기
- 최근 9장 사진을 3×3 그리드로 배치 → 인스타그램 피드 색감 통일성 미리보기
- 현재 선택 필터 적용 시 피드가 어떻게 보일지 실시간 렌더링
- **SNS 바이럴 콘텐츠** — "MoodFilm으로 피드 통일했어요" 공유 유도
- 구현: PHFetchResult + thumbnail 배치 + 필터 썸네일 오버레이
- 적용 시점: v1.2

### [아이디어 4] 필터 Intensity 기억
- 각 필터별 마지막 사용 강도를 Hive에 저장
- 필터 선택 시 마지막 강도로 바로 적용 — UX 마찰 제거
- 구현 비용: 낮음, UX 임팩트: 높음
- **MVP에 포함 권장**

### [아이디어 5] Split-View Before/After
- Edit 화면 Before/After를 수직 분할선 드래그 방식으로 비교
- BerryFilm "길게 누르기" 대비 더 직관적이고 오래 비교 가능
- 구현: GestureDetector + ClipRect + 분할선 오버레이
- 적용 시점: MVP (편집 화면 차별화)

### [아이디어 6] Dynamic Island 카운트다운
- 셀프타이머 3초/10초 작동 시 Dynamic Island에 카운트다운 애니메이션
- ActivityKit Live Activity 활용
- iOS 16.1+ 지원 기기에서만 활성화 (graceful fallback)
- 적용 시점: v1.1

---

## 3. 기술 스택 확정

```
Flutter: 3.27+ (stable)
Dart: 3.6+
iOS 최소 지원: iOS 17.0 (Liquid Glass: iOS 26 conditional)
Xcode: 16.3+

# 상태관리
riverpod: ^2.6.1
flutter_riverpod: ^2.6.1
riverpod_generator: ^2.4.0  # code gen

# 라우팅
go_router: ^14.0.0

# 네이티브 카메라
camera: ^0.11.0  # 기반, Native Plugin으로 오버라이드

# 로컬 저장
hive_flutter: ^1.1.0
hive_generator: ^2.0.1

# 인앱 결제
purchases_flutter: ^8.0.0  # RevenueCat

# 분석/크래시
firebase_analytics: ^11.0.0
firebase_crashlytics: ^4.0.0

# 이미지 처리
image_picker: ^1.1.0  # 갤러리 import
photo_manager: ^3.5.0  # 더 강력한 갤러리 접근
share_plus: ^10.0.0

# 개발 도구
flutter_lints: ^5.0.0
build_runner: ^2.4.0
```

---

## 4. 프로젝트 구조 (Feature-first 확장)

```
lib/
├── main.dart
├── app.dart                          # MaterialApp + ProviderScope
│
├── core/
│   ├── constants/
│   │   ├── app_colors.dart           # 컬러 시스템 (계획서 6-4 기반)
│   │   ├── app_typography.dart       # Pretendard + SF Pro 폰트
│   │   └── app_dimensions.dart       # 버튼 크기, 패딩 등
│   ├── theme/
│   │   ├── app_theme.dart            # Light/Dark theme
│   │   └── liquid_glass_decorations.dart  # Glassmorphism 컴포넌트
│   ├── models/
│   │   ├── filter_model.dart         # FilterModel + FilterCategory
│   │   ├── filter_pack_model.dart    # 월간 드롭 팩
│   │   ├── effect_model.dart         # EffectModel (Glow, Grain 등)
│   │   └── user_preferences.dart     # Hive 저장 사용자 설정
│   ├── services/
│   │   ├── iap_service.dart          # RevenueCat 래퍼
│   │   ├── analytics_service.dart    # Firebase 이벤트
│   │   └── storage_service.dart      # Hive 초기화 + CRUD
│   └── utils/
│       ├── haptic_utils.dart          # 햅틱 피드백 헬퍼
│       └── permission_utils.dart      # 카메라/갤러리 권한
│
├── features/
│   ├── camera/
│   │   ├── presentation/
│   │   │   ├── camera_screen.dart
│   │   │   ├── widgets/
│   │   │   │   ├── camera_preview_widget.dart
│   │   │   │   ├── filter_scroll_bar.dart      # 하단 필터 스크롤
│   │   │   │   ├── shutter_button.dart
│   │   │   │   ├── exposure_indicator.dart      # EV floating indicator
│   │   │   │   └── camera_controls_overlay.dart
│   │   ├── providers/
│   │   │   ├── camera_provider.dart
│   │   │   └── active_filter_provider.dart
│   │   └── models/
│   │       └── camera_state.dart
│   │
│   ├── editor/
│   │   ├── presentation/
│   │   │   ├── editor_screen.dart
│   │   │   ├── widgets/
│   │   │   │   ├── adjustment_sliders.dart     # 6종 슬라이더
│   │   │   │   ├── effect_panel.dart
│   │   │   │   ├── split_compare_view.dart     # [추가] 분할 비교
│   │   │   │   └── filter_tab_bar.dart
│   │   ├── providers/
│   │   │   └── editor_provider.dart
│   │   └── models/
│   │       └── edit_state.dart
│   │
│   ├── filter_library/
│   │   ├── presentation/
│   │   │   ├── filter_library_screen.dart
│   │   │   └── widgets/
│   │   │       ├── filter_grid_item.dart
│   │   │       └── filter_category_tabs.dart
│   │   ├── providers/
│   │   │   └── filter_library_provider.dart
│   │
│   ├── onboarding/
│   │   ├── presentation/
│   │   │   ├── onboarding_screen.dart
│   │   │   └── paywall_screen.dart
│   │   └── providers/
│   │       └── onboarding_provider.dart
│   │
│   └── settings/
│       ├── presentation/
│       │   └── settings_screen.dart
│       └── providers/
│           └── settings_provider.dart
│
└── native_plugins/
    ├── camera_engine/
    │   ├── camera_engine.dart         # Method Channel 인터페이스
    │   └── camera_engine_platform_interface.dart
    └── filter_engine/
        ├── filter_engine.dart         # LUT 처리 채널
        └── filter_engine_impl.dart

ios/
└── Runner/
    ├── NativeCamera/
    │   ├── MFCameraEngine.swift        # AVFoundation 래퍼
    │   ├── MFCaptureSession.swift
    │   └── MFFilterPreview.swift       # MTKView 실시간 렌더
    ├── FilterEngine/
    │   ├── MFLUTEngine.swift           # CIColorCube + filter chain
    │   ├── MFEffectPipeline.swift      # Glow, Grain, Light Leak
    │   └── MFMetalRenderer.swift       # Metal shader (선택적)
    └── Plugins/
        ├── CameraEnginePlugin.swift    # FlutterPlugin 구현
        └── FilterEnginePlugin.swift
```

---

## 5. 데이터 모델 설계

### FilterModel
```dart
@HiveType(typeId: 0)
class FilterModel extends HiveObject {
  @HiveField(0) final String id;          // 'milk', 'cream' 등
  @HiveField(1) final String name;        // 'Milk'
  @HiveField(2) final String category;    // 'warm', 'cool', 'film', 'aesthetic'
  @HiveField(3) final String lutFileName; // 'milk.cube'
  @HiveField(4) final bool isPro;
  @HiveField(5) final bool isFavorite;
  @HiveField(6) final double lastIntensity; // [추가] 마지막 사용 강도
  @HiveField(7) final String? packId;     // 월간 드롭 팩 소속
  @HiveField(8) final bool isNew;         // NEW 배지
}
```

### ActiveFilterState (Riverpod)
```dart
@riverpod
class ActiveFilter extends _$ActiveFilter {
  // 카메라 화면 현재 선택 필터 + 강도
  FilterModel? filter;
  double intensity;  // 0.0 ~ 1.0
  Map<EffectType, double> effects;  // Glow, Grain, etc.
}
```

### UserPreferences (Hive)
```dart
@HiveType(typeId: 1)
class UserPreferences extends HiveObject {
  @HiveField(0) bool hasSeenOnboarding;
  @HiveField(1) String? lastUsedFilterId;
  @HiveField(2) bool isProUser;
  @HiveField(3) Map<String, double> filterIntensities;  // filterId → intensity
  @HiveField(4) List<String> favoriteFilterIds;
  @HiveField(5) bool hasSeenDreamyGlowTip;
}
```

---

## 6. Native Plugin — Method Channel 인터페이스

### CameraEngine Channel
```dart
// Flutter 측
class CameraEngine {
  static const _channel = MethodChannel('com.moodfilm/camera_engine');

  Future<void> initialize({bool frontCamera = true}) =>
    _channel.invokeMethod('initialize', {'frontCamera': frontCamera});

  Future<void> setFilter(String lutFileName, double intensity) =>
    _channel.invokeMethod('setFilter', {
      'lutFile': lutFileName,
      'intensity': intensity,
    });

  Future<String?> capturePhoto() =>
    _channel.invokeMethod('capturePhoto');

  Future<void> setExposure(double ev) =>
    _channel.invokeMethod('setExposure', {'ev': ev});

  // 실시간 프리뷰는 Texture 위젯으로 렌더링
  Future<int> getTextureId() =>
    _channel.invokeMethod('getTextureId');
}
```

### iOS Swift 구현 핵심
```swift
// MFCameraEngine.swift
class MFCameraEngine: NSObject, FlutterPlugin {
    private var captureSession: AVCaptureSession?
    private var lutEngine: MFLUTEngine?
    private var metalView: MTKView?
    private var textureRegistry: FlutterTextureRegistry?

    // CIContext는 싱글톤 — 생성 비용이 높음
    static let ciContext = CIContext(
        mtlDevice: MTLCreateSystemDefaultDevice()!,
        options: [.workingColorSpace: CGColorSpaceCreateDeviceRGB()]
    )

    func setFilter(lutFile: String, intensity: Float) {
        // LUT lazy loading — 메모리 < 150MB 유지
        lutEngine?.loadLUT(named: lutFile)
        lutEngine?.intensity = intensity
    }
}
```

---

## 7. LUT 파일 관리 전략 (앱 크기 최적화)

### 번들 전략
```
번들 포함 (무료 8개 × 1.5MB ≈ 12MB):
  Warm: Milk, Cream, Butter
  Cool: Sky, Cloud
  Film: Disposable
  Aesthetic: Soft Pink, Lavender

On-demand (Pro 구독 시 다운로드, 12개 × 1.5MB ≈ 18MB):
  나머지 12개 필터
  → CloudFront CDN, 필터별 개별 다운로드
  → 로컬 캐시: Documents/LUTs/

월간 드롭 팩 (서버 다운로드):
  4개 × 1.5MB = 6MB/팩
  → 구독자 전용 CDN URL
```

### 앱 크기 목표
- 초기 다운로드: < 25MB (번들 LUT 12MB + 앱)
- 설치 후 Pro 활성화 시 추가 18MB 다운로드

### LUT 최적화
```swift
// .cube → 바이너리 사전 변환으로 로딩 40% 단축
// Build Script에서 자동 변환
// cube_to_binary.py → LUTs/*.bin 생성
// 런타임: bin 파일 mmap으로 zero-copy 로딩
```

---

## 8. 주차별 상세 구현 태스크

### Phase 1: Foundation (Week 1-3)

**W1 — 프로젝트 셋업**
- [ ] Flutter 프로젝트 생성 (Feature-first 폴더 구조)
- [ ] pubspec.yaml 패키지 설정 (Riverpod, Hive, go_router, RevenueCat)
- [ ] GitHub Actions CI: `flutter analyze` + `flutter test` on PR
- [ ] Fastlane 설정: TestFlight 자동 배포
- [ ] Hive 어댑터 코드 생성 (FilterModel, UserPreferences)
- [ ] AppColors, AppTypography 토큰화 (계획서 6-4 기준)
- [ ] go_router 기본 라우트 설계 (/, /camera, /editor, /library, /settings)
- **완료 기준:** `flutter run`으로 빈 카메라 화면 표시

**W2 — 카메라 엔진 (Native Plugin)**
- [ ] iOS: AVCaptureSession 설정 (전면/후면, 30fps)
- [ ] Flutter Texture 위젯으로 실시간 프리뷰 연결
- [ ] Method Channel 인터페이스 구현 (initialize, capture, flip)
- [ ] 카메라 권한 요청 + 거부 시 안내 화면
- [ ] 서터 버튼 → PHPhotoLibrary 저장 + 햅틱
- [ ] 전면 시 미러링 보정 (자연스러운 셀카)
- **완료 기준:** 실기기에서 사진 촬영 → 갤러리 저장

**W3 — LUT 필터 엔진**
- [ ] CIColorCube LUT 로딩 시스템
- [ ] 실시간 CIFilter 체인 (ColorCube → Exposure → Contrast → Output)
- [ ] MTKView GPU 렌더링 파이프라인 (목표: 30fps @ iPhone 12+)
- [ ] 필터 전환 crossfade 200ms 애니메이션
- [ ] 기본 필터 8개 .cube 파일 제작 (Milk, Cream, Butter, Sky, Cloud, Disposable, Soft Pink, Lavender)
- [ ] 성능 프로파일링 (Xcode Instruments: GPU frame capture)
- **완료 기준:** 8개 필터 전환 < 100ms, 30fps 유지

---

### Phase 2: Core Features (Week 4-6)

**W4 — 필터 20종 완성**
- [ ] 나머지 12개 필터 .cube 파일 제작/튜닝
  - Warm: Honey, Peach
  - Cool: Ocean, Mint, Ice
  - Film: Film98, Film03, Retro CCD, Kodak Soft
  - Aesthetic: Dusty Blue, Cafe Mood, Seoul Night
- [ ] 각 필터 셀카 피부톤 최적화 테스트 (red -5~-10%, highlight +10~20%)
- [ ] 필터 썸네일 생성 (60×60pt, 샘플 이미지 적용)
- [ ] 하단 필터 스크롤 바 UI (원형/사각 썸네일, 선택 상태)
- [ ] 필터 강도 조절 (CIFilter blending: original × (1-intensity) + filtered × intensity)
- [ ] **[추가] 필터별 마지막 강도 Hive 저장**
- **완료 기준:** 20개 필터 스크롤 선택 동작, 강도 슬라이더

**W5 — 편집 화면**
- [ ] PHPickerViewController 갤러리 Import
- [ ] Editor 화면 레이아웃 (상단 이미지 16:9, 하단 도구 패널)
- [ ] 필터 탭 (카메라 화면과 동일 스크롤 바)
- [ ] 조정 탭 6종 슬라이더 (Exposure, Contrast, Warmth, Saturation, Grain, Fade)
  - 슬라이더 디자인: 라벤더 트랙, 크림 원형 핸들, floating label
- [ ] **[추가] Split-View Before/After** — 분할선 드래그 비교
- [ ] 원본 해상도 JPEG/HEIF 저장 + 공유 시트
- **완료 기준:** 갤러리 사진 Import → 필터 + 슬라이더 → 저장

**W6 — 이펙트 시스템**
- [ ] Dreamy Glow (시그니처): CIBloom + Gaussian Blur 조합 0~100%
- [ ] Film Grain: CIRandomGenerator + CIBlendMode 0~100%
- [ ] Dust Texture: 오버레이 이미지 블렌딩 (Pro)
- [ ] Light Leak: 그라디언트 오버레이 (Pro)
- [ ] Date Stamp: 촬영 날짜 텍스트 오버레이 (Pro, 폰트: SF Mono)
- [ ] 이펙트 + 필터 합성 파이프라인 통합
- [ ] 이펙트 강도 슬라이더 (이펙트 탭)
- **완료 기준:** Dreamy Glow 촬영 화면에서 실시간 동작

---

### Phase 3: Polish & Business (Week 7-9)

**W7 — UI/UX 완성**
- [ ] Quiet Luxury 디자인 시스템 전체 적용
  - Primary #FBF5EE, Accent #C8A2D0, 나머지 토큰 전부
- [ ] Liquid Glass 패널 (backdrop-filter blur 12-20px, opacity 0.08-0.15)
- [ ] 모션 디자인 스펙 전체 구현 (계획서 6-7 기준)
  - 필터 전환 crossfade 200ms easeInOut
  - 셔터 탭 scale bounce 0.92→1.0 150ms spring(0.6)
  - 촬영 완료 thumbnail fly 300ms spring(0.8)
- [ ] 제스처 인터랙션 완성 (좌우 스와이프, 상하 EV, 핀치 줌, 더블탭)
- [ ] 햅틱 피드백 전체 연결
- [ ] Reduce Motion 대응 (spring → crossfade 100ms)
- [ ] VoiceOver 레이블 전체 설정
- **완료 기준:** 디자인 리뷰 통과 (계획서 6-1 원칙 체크리스트)

**W8 — 필터 라이브러리**
- [ ] 카테고리 탭 (Warm | Cool | Film | Aesthetic | Favorites)
- [ ] 2열 그리드 레이아웃, 각 셀 샘플 이미지 + 필터명 + Pro 배지
- [ ] NEW 배지 (라벤더 배경, 흰 텍스트, 둥근 pill)
- [ ] 즐겨찾기 하트 탭 → Hive 저장 → 카메라 화면 우선 표시
- [ ] Pro 잠금 필터 lock 아이콘 + 탭 시 paywall로 이동
- [ ] 필터 프리뷰 탭 시 확대 → 적용 버튼
- **완료 기준:** 라이브러리 → 카메라 화면 필터 적용 플로우

**W9 — IAP + 온보딩**
- [ ] RevenueCat 설정 (Pro Monthly ₩2,900 / Annual ₩14,900 / Lifetime ₩29,900)
- [ ] Paywall 화면 (Dreamy Glow 샘플 + 필터 미리보기 + 플랜 선택)
- [ ] 7일 무료 체험 구현 (Pro 필터 탭 → 잠금 → 무료 체험 CTA)
- [ ] 구독 복원 기능
- [ ] 온보딩 Progressive Disclosure:
  - 첫 실행: 카메라 바로 시작 (온보딩 강제 없음)
  - 첫 필터 전환 시: 힌트 애니메이션 (반투명 화살표)
  - 첫 Dreamy Glow 사용 시: 시그니처 소개 배너 (3초 자동 소멸)
  - 첫 Pro 탭 시: 7일 무료 체험 CTA
- [ ] 설정 화면 (구독 관리, 개인정보, 문의, 앱 버전)
- **완료 기준:** End-to-end 결제 플로우 Sandbox 테스트 통과

---

### Phase 4: QA & Launch (Week 10-12)

**W10 — 성능 테스트 + 최적화**
- [ ] 기기별 성능 테스트 매트릭스:

  | 기기 | 30fps | 캡처 < 0.5s | 메모리 < 150MB | 필터 전환 < 100ms |
  |------|-------|-------------|----------------|-------------------|
  | iPhone 12 | ? | ? | ? | ? |
  | iPhone 14 | ? | ? | ? | ? |
  | iPhone 15 Pro | ? | ? | ? | ? |
  | iPhone 16 | ? | ? | ? | ? |

- [ ] CIContext 싱글톤 확인 (반복 생성 여부 체크)
- [ ] LUT 캐시 전략 (즐겨찾기 필터 사전 로드)
- [ ] MTLTexture 재사용 풀 구현
- [ ] 메모리 누수 점검 (Instruments: Leaks, Allocations)
- [ ] 앱 크기 확인 (목표 < 25MB, App Thinning 적용)
- [ ] Crashlytics 연동 확인

**W11 — App Store 준비**
- [ ] 스크린샷 5장 (Before/After 포맷, 파스텔 배경)
  - 카메라 화면 with Milk 필터
  - 편집 화면 슬라이더
  - 필터 라이브러리 그리드
  - Dreamy Glow 효과 비교
  - ColorGrid 피드 미리보기 (있으면)
- [ ] 앱 프리뷰 영상 30초 (필터 스크롤 → 셀카 촬영 → 결과물)
- [ ] ASO 키워드 최적화 (감성필터, 셀카필터, 색감보정, 한국감성, 뽀용)
- [ ] 개인정보처리방침 + 이용약관 페이지
- [ ] 앱 아이콘 최종 확인 (크림→라벤더 그라디언트 + 달 심볼)
- [ ] App Store 심사 메모 (카메라 권한 사용 목적 설명)

**W12 — 소프트 런칭**
- [ ] TestFlight 베타 50명 배포 (인플루언서 시딩 대상)
- [ ] 피드백 수집 → 치명적 버그 핫픽스
- [ ] App Store 제출 + 심사 대기 (평균 24-48시간)
- [ ] 런칭 콘텐츠 예약 게시 (인스타그램 릴스 5개, 틱톡 3개)
- [ ] @moodfilm.app 인스타그램 계정 운영 시작

---

## 9. 성능 최적화 체크리스트

### iOS Native 레이어
```swift
// 1. CIContext 싱글톤 (가장 중요)
// BAD: 매 프레임 생성
// GOOD: AppDelegate에서 한 번만 생성

// 2. CIImage 지연 평가 활용
// CIFilter 체인은 render() 호출 전까지 실제 계산 안 함
// 여러 필터 체이닝 후 한 번에 render

// 3. MTLTexture 재사용
var texturePool: [MTLTexture] = []  // 크기별 풀 관리

// 4. 비동기 캡처
// 캡처는 백그라운드 큐, UI 업데이트만 메인 큐

// 5. LUT lazy loading
var lutCache: NSCache<NSString, CIFilter>  // 최대 5개 캐시
```

### Flutter 레이어
```dart
// 1. const 위젯 적극 활용
const FilterScrollBar(...)  // 재빌드 방지

// 2. RepaintBoundary로 필터 스크롤 분리
RepaintBoundary(child: FilterScrollBar(...))

// 3. Riverpod select로 필요한 상태만 구독
ref.watch(activeFilterProvider.select((s) => s.filterId))

// 4. 이미지 썸네일 precache
precacheImage(AssetImage('assets/thumbnails/milk.jpg'), context)
```

---

## 10. 런칭 후 업데이트 로드맵 (보완)

### v1.0 (런칭, Week 12)
- 카메라 + 필터 20종 + 편집 + 라이브러리
- Dreamy Glow 시그니처 이펙트
- Freemium (8 무료 / Pro 구독)
- iOS 전용

### v1.1 (런칭+1개월)
- 동영상 촬영 + 필터 무음 서터 개선
- Spring Blossom Pack (4종 신규 필터)
- **Dynamic Island 카운트다운** [추가 아이디어 6]

### v1.2 (런칭+2개월)
- **"오늘의 필터" iOS 위젯** [추가 아이디어 2]
- **ColorGrid 피드 미리보기** [추가 아이디어 3]
- 비교 모드 개선 (Split-View 드래그)
- Summer Film Pack (4종)

### v1.3 (런칭+3개월)
- **"Mood Match" AI 필터 추천** [추가 아이디어 1] (on-device CoreML)
- Y2K Digital Pack (4종)
- 공유 기능 강화 (ColorGrid 공유)
- Android 버전 출시

### v2.0 (런칭+6개월)
- 커스텀 필터 생성 (기존 필터 베이스 + 슬라이더 저장)
- 커뮤니티 필터 공유
- ProRAW 지원 (프로 사용자층 확장)
- **Mood Journal** — 필터별 사진 컬렉션 미니 갤러리

---

## 11. 에러 핸들링 (미설계 구간 보완)

### 카메라 권한 거부
```dart
// PermissionStatus.denied → 안내 다이얼로그
// → "설정에서 허용" 버튼 → openAppSettings()
// 카메라 없이 편집 전용 모드 진입 허용
```

### LUT 파일 로드 실패
```dart
// .cube 파일 손상/없음 → 기본 Identity LUT 적용
// Firebase Analytics에 오류 이벤트 로깅
// 사용자에게는 "필터를 불러오는 중..." 표시
```

### 저장 실패 (갤러리 권한 또는 용량)
```dart
// 임시 파일로 저장 후 공유 시트 제공
// "갤러리 접근 권한이 필요합니다" 토스트
```

### IAP 로드 실패
```dart
// 네트워크 오류 시 마지막 구독 상태 Hive에서 캐시 사용
// "결제 서비스 연결 실패" + 재시도 버튼
```

### 메모리 경고
```swift
// didReceiveMemoryWarning: LUT 캐시 전체 비우기
// 즐겨찾기 필터만 재로드
```

---

## 12. App Store 심사 리스크 대응

| 리스크 | 대응 |
|--------|------|
| 카메라 권한 심사 | NSCameraUsageDescription 명확히 기재 |
| IAP 설명 부족 | Pro 기능 목록 명시, 자동 갱신 설명 |
| Freemium 오해 | 무료 기능 범위를 첫 화면에서 명확히 표시 |
| 개인정보 없음 처리 | 카메라 데이터 서버 전송 없음 명시 |
| 아동 등급 | 17세 미만 → 4+ 등급 유지 (필터 앱) |

---

## 13. 핵심 의사결정 요약 (계획서 확정 사항)

| 항목 | 결정 | 근거 |
|------|------|------|
| 플랫폼 | Flutter + Native Plugin | 1인 개발 속도 + 카메라 성능 균형 |
| 필터 수 | MVP 20종 | "색감 브랜드 > 필터 수" 원칙 |
| 수익 모델 | Freemium + 구독 + Lifetime | 신규 앱 진입 장벽 최소화 |
| 런칭 순서 | iOS → Android (3개월 후) | iOS 검증 후 확장 |
| 시그니처 | Dreamy Glow (CIBloom + Blur) | BerryFilm의 뽀용 대비 차별화 |
| 마케팅 | SNS 유기적 성장 Zero Budget | 필터 앱 특성상 SNS 바이럴 최적 |

---

*이 계획서는 구현 진행에 따라 업데이트됩니다.*
