# MoodFilm 개발 진행 현황
> 마지막 업데이트: 2026-03-08 (세션 13, 업데이트 4)

---

## 전체 진행률

```
Phase 1: Foundation      [██████████] W1-W3 완료
Phase 2: Core Features   [░░░░░░░░░░] W4-6 예정
Phase 3: Polish          [░░░░░░░░░░] W7-9 예정
Phase 4: QA & Launch     [░░░░░░░░░░] W10-12 예정
```

---

## Phase 1: Foundation (W1-3)

### ✅ W1 — 프로젝트 셋업 (완료)

**완료 항목:**
- [x] Flutter 프로젝트 생성 (`com.moodfilm`, iOS+Android)
- [x] Feature-first 폴더 구조 전체 생성
- [x] pubspec.yaml 패키지 설정 (flutter_riverpod, go_router, hive_flutter, purchases_flutter, firebase, photo_manager 등)
- [x] `flutter pub get` 성공 + `flutter analyze` error 0개
- [x] Hive 코드 생성 (`build_runner build`) 완료
- [x] **디자인 토큰:** AppColors, AppTypography, AppDimensions (계획서 6-4 기반)
- [x] **테마:** AppTheme (Light/Dark), LiquidGlassContainer (Glassmorphism)
- [x] **데이터 모델:** FilterModel, EffectType, UserPreferences (Hive TypeAdapter 자동 생성)
- [x] **라우터:** go_router 6개 라우트 설정 (/, /editor, /library, /settings, /onboarding, /paywall)
- [x] **앱 진입점:** main.dart (Hive init, ProviderScope) + app.dart (MaterialApp.router)
- [x] **Native Plugin 인터페이스:** CameraEngine, FilterEngine (Method Channel)
- [x] **iOS Swift — MFLUTEngine:** .cube 파싱, CIColorCube, Dreamy Glow, Film Grain
- [x] **iOS Swift — MFCameraSession:** AVFoundation 30fps, 전면/후면, 캡처
- [x] **iOS Swift — MFCameraPreview:** FlutterTexture 렌더러
- [x] **iOS Swift — CameraEnginePlugin:** FlutterPlugin Method Channel 핸들러
- [x] **CameraScreen:** 풀스크린 프리뷰, 제스처 (스와이프/상하/핀치/더블탭), 상단/하단 컨트롤
- [x] **ShutterButton:** scale bounce 애니메이션 (0.92→1.0, 150ms spring)
- [x] **FilterScrollBar:** 수평 스크롤, 즐겨찾기 우선 정렬, Pro 잠금 오버레이, NEW 배지
- [x] **ExposureIndicator:** EV floating indicator (상하 스와이프 연동)
- [x] **CameraProvider:** StateNotifier, 필터/이펙트/촬영/줌/노출 상태 관리
- [x] **EditorScreen:** 탭 바 (필터/조정/이펙트), Split-View Before/After 드래그 비교
- [x] **FilterLibraryScreen:** 카테고리 탭 5개, 2열 그리드, 즐겨찾기, Pro/NEW 배지
- [x] **SettingsScreen:** 구독 상태, 앱 정보
- [x] **OnboardingScreen:** Progressive Disclosure (강제 없음)
- [x] **PaywallScreen:** 3플랜 선택 (월간/연간/평생), 7일 무료 체험
- [x] **Info.plist:** 카메라/갤러리/마이크 권한 설명 추가, 세로 모드 고정

**해결한 이슈:**
- `hive_generator ^2.0.1` + `build_runner ^2.4.14` analyzer 충돌 → `build_runner ^2.4.13`으로 해결
- `riverpod_generator` + `hive_generator` analyzer 충돌 → riverpod_generator 제외, Provider 수동 작성
- `custom_lint` + `hive_generator` analyzer 충돌 → custom_lint 제외

---

### ✅ W2 — 카메라 엔진 실기기 연결 (완료)

**완료 항목:**
- [x] Xcode에서 `ios/Runner/NativeCamera/` Swift 파일 4개를 Runner 타겟에 추가
- [x] `ios/Podfile`에 `platform :ios, '17.0'` 설정
- [x] Xcode 프로젝트 빌드 확인 (Swift 컴파일 오류 수정)
- [x] 실기기에서 카메라 프리뷰 표시 확인
- [x] 전면/후면 전환 동작 확인 (방향 버그 수정 완료)
- [x] 셔터 버튼 → 사진 촬영 → 갤러리 저장 확인
- [x] 필터 전환 → LUT 적용 확인
- [x] 노출 조정 (상하 스와이프) 동작 확인

**해결한 이슈:**
- 전면카메라 좌우반전: `scale(-1, 1)` + `RotatedBox(1)` 조합으로 수정
- 후면카메라: `RotatedBox(1)` only (scale 없음) = 정상
- 전환 글리치: `isFlipping` + `Future.delayed(500ms)` 오버레이로 해결
- 전후면 전환 카드 플립 애니메이션: Y축 3D 회전 (midpoint에서 카메라 swap)

**실기기 릴리즈 빌드 설치 방법:**

```bash
# 1. 디버그 빌드 (개발 중 빠른 테스트)
flutter run

# 2. 릴리즈 빌드 직접 설치 (성능 테스트용, USB 연결 필요)
flutter run --release

# 3. IPA 빌드 후 Xcode로 설치
flutter build ios --release --no-codesign
# → Xcode 열기 → Product → Archive → Distribute App → Direct Install
```

> **팁:** `flutter run --release`는 Xcode 서명 설정이 되어 있으면 USB 연결 기기에 바로 설치됨.
> TestFlight 없이 팀 내 기기에 배포할 때는 Xcode Archive → Ad Hoc 또는 Development 배포 사용.

---

### ✅ W3 — LUT 필터 엔진 (완료)

- [x] 무료 8종 LUT .cube 파일 (`assets/luts/`: milk, cream, sky, cloud, film98, disposable, soft_pink, lavender)
- [x] 필터 전환 crossfade 200ms 애니메이션 (white flash 30ms→200ms fade)
- [x] 필터 강도 슬라이더 (상단 tune 버튼 → AnimatedContainer 슬라이더)
- [ ] CIColorCube 실시간 30fps 성능 확인 (실기기 테스트 필요)
- [ ] 썸네일 이미지 8개 생성 → `assets/thumbnails/`

---

## Phase 2: Core Features (W4-6) — 예정

### ✅ W4 — 필터 22종 완성
- [x] 나머지 12종 LUT .cube 파일 제작 (tools/generate_luts.py로 전체 22종 생성)
- [x] 셀카 피부톤 최적화 → tools/generate_luts.py 파라미터로 반영
- [x] 썸네일 22종 생성 (assets/thumbnails/, 60x60 JPG, 필터 색감 반영)

### ⏳ W5 — 편집 화면 완성
- [x] `FilterEnginePlugin.swift` Native 구현 (Full-res 처리 + 갤러리 저장)
- [x] EditorScreen 저장 버튼 실제 연결 (`FilterEngine.processImage()`)
- [x] 6종 슬라이더 CIFilter 연결 (Exposure, Contrast, Warmth, Saturation, Grain, Fade)
- [x] 갤러리 Import (photo_manager 연동) — GalleryPickerScreen, /gallery 라우트, 카메라 갤러리 버튼 연결
- [x] Split-View Before/After 개선 (filtered image 실제 반영)
- [x] **갤러리 일괄 필터 적용** — 다중 선택 모드, 필터 바텀시트 선택, 일괄 FilterEngine.processImage 처리 → 갤러리 저장

### ✅ W5b — 실시간 필터 프리뷰
- [x] **카메라 프리뷰 실시간 LUT 적용** — AVSampleBufferDisplayLayer + CIColorCube Metal 렌더링
  - MFCameraSession에서 CVPixelBuffer → CIImage → LUT → Metal 텍스처로 출력
  - Flutter Texture 위젯 대신 Metal 기반 실시간 렌더링 파이프라인 구축
  - 목표: 30fps @ iPhone 14 이상, 전환 crossfade 유지
  - 기술 스택: AVCaptureVideoDataOutput → CIFilter(LUT) → CIContext(metal) → CVPixelBuffer → FlutterTexture

### ✅ W6 — 이펙트 시스템
- [x] Dreamy Glow 슬라이더 (EditorScreen 이펙트 탭, FilterEngine.processImage effects 연결)
- [x] Film Grain 슬라이더 연동
- [x] 이펙트 탭 UI 완성
- [ ] Dust Texture (Pro, 오버레이 이미지) — v1.1
- [ ] Light Leak (Pro, 그라디언트) — v1.1
- [ ] Date Stamp (Pro, 날짜 텍스트) — v1.1

### ✅ W6b — 동영상 필터 녹화
- [x] **AVAssetWriter 기반 필터 녹화** — 실시간 LUT 적용 + 동영상 저장
  - MFCameraSession에 녹화 모드 추가 (captureVideo start/stop)
  - AVAssetWriter + AVAssetWriterInput (H.264/HEVC) + AVAssetWriterInputPixelBufferAdaptor
  - 각 프레임: CVPixelBuffer → CIImage → LUT → CIContext.render → AVAssetWriterInputPixelBufferAdaptor
  - 오디오: AVCaptureAudioDataOutput 병렬 처리
  - 완성 파일 → 갤러리 저장 (PHPhotoLibrary)
  - Flutter: 녹화 버튼 (길게 누르기 or 별도 버튼), 타이머, 진행률 표시
  - 목표: 1080p 30fps H.264, 최대 60초

---

## Phase 3: Polish & Business (W7-9) — 예정

### ✅ W7 — UI/UX 완성
- [x] `withOpacity()` → `withValues(alpha:)` 전체 교체 (Flutter 3.x 코딩 규칙)
- [x] VoiceOver Semantics 레이블 (셔터, 설정, 카메라 전환, 필터 아이템)
- [x] Liquid Glass 전체 적용 확인 (카메라 사이드버튼 glass, 에디터 dark pill)
- [x] 모션 디자인: Haptic Feedback 전체 연결 (셔터/전환/필터/즐겨찾기), 필터이름 AnimatedSwitcher
- [x] Reduce Motion 대응: MediaQuery.disableAnimations → AnimationController duration 0

### ✅ W8 — 필터 라이브러리 완성
- [x] 필터 스크롤바 끝 "전체" 버튼 → /library 이동
- [x] 필터 라이브러리 → 필터 선택 시 카메라에 적용 + pop
- [x] Pro 필터 탭 → Paywall 이동
- [x] 즐겨찾기 실시간 반영 (favoritesVersion 트리거)

### ✅ W9 — 수익 모델 확정
- [x] **수익 모델: App Store 유료 앱 (IAP 없음)** — 앱 자체를 유료로 판매
- [x] 앱 내 구매 기능 전체 제거 (PaywallScreen, IapService, Pro 잠금 제거)
- [x] 모든 필터 20종 무제한 사용 (Pro 게이트 해제)
- [x] Settings 구매 섹션 제거 → 앱 정보만 표시

---

## Phase 4: QA & Launch (W10-14) — 진행 중

### ⏳ W10 — 성능 테스트
- [ ] 기기별 테스트 (iPhone 12 / 14 / 15 Pro / 16)
- [ ] Instruments 메모리/GPU 프로파일링

### ✅ W11 — BerryFilm 벤치마킹 기능 추가 (세션 11)
> BerryFilm(₩3,300, 4.8★, 40종) 분석 결과 반영

- [x] **iOS 최소버전 17 → 16** — Podfile + project.pbxproj 3곳 수정 (잠재 사용자 ~15% 확대)
- [x] **필터 30종으로 확장** (22종 → +8종: latte, mocha, pale, winter, bronze, noir, blossom, vivid)
  - 33×33×33 `.cube` LUT 파일 8종 Python 스크립트로 생성
  - 60×60 JPG 썸네일 8종 생성
  - `filter_model.dart` 등록 + `defaultIntensities` 추가
- [x] **Light Leak 이펙트** — `MFLUTEngine.applyLightLeak()` 구현
  - `CIRadialGradient` 2개 (주황 좌상단 + 노랑 우하단) + Screen blend
  - `CameraEnginePlugin` / `FilterEnginePlugin` 양쪽에 `lightLeak` 케이스 추가
  - `EditorScreen` 이펙트 탭에 Light Leak 슬라이더 추가

### ✅ W12 — 라이브포토 지원 (세션 11 연속)
> BerryFilm 동등 기능, 핵심 차별점

- [x] **Swift (MFCameraSession.swift)**
  - `isLivePhotoEnabled` 프로퍼티 + `setLivePhotoEnabled()` 메서드
  - `capturePhoto()`: 라이브포토 활성화 시 `livePhotoMovieFileURL` MOV 임시경로 주입
  - delegate 메서드 `didCapturePhoto(path:livePhotoMovieURL:)` 로 통합
  - `CameraEnginePlugin`: `PHAssetCreationRequest` `.photo` + `.pairedVideo` 쌍으로 갤러리 저장
- [x] **Flutter**
  - `UserPreferences`: `@HiveField(10) bool isLivePhotoEnabled` 추가
  - `CameraEngine.setLivePhotoEnabled(bool)` 메서드 추가
  - `CameraScreen` 사이드 버튼에 라이브포토 토글 (`motion_photos_on` 아이콘)
  - `SettingsScreen`: 라이브포토 토글 추가
  - 무음셔터 ↔ 라이브포토 상호 배타 처리 (양쪽에서 자동 해제)
  - 카메라 초기화 시 라이브포토 상태 복원
- [x] `build_runner build` — `user_preferences.g.dart` HiveField(10) 재생성
- [x] `flutter analyze`: 0 issues

### ✅ W13 — UI 개선 및 버그 수정 (세션 13)

- [x] **Before/After 스플릿 뷰 렌더링 버그 수정**
  - 원인: Stack에 명시적 크기 없음 → ClipRect 너비 변화에 따라 Stack 전체가 줄어들어 Positioned.fill 이미지도 함께 사라지는 현상
  - 수정: `SizedBox(width: w, height: h)` 로 Stack 크기 고정
- [x] **EditorScreen 이펙트 이름 변경** — '뽀용' → '솜결' (순우리말, 브랜드 감성 일치)
- [x] **앱 이름 변경** — MoodFilm → 라이크잇 (Like it!)
- [x] **GalleryPickerScreen 리디자인**
  - 상단 헤더: `Like it!` 브랜딩 (흰색 이탤릭 볼드 + accent `!`)
  - 기존 3열 균등 그리드 → 2열 벽돌 격자 (Masonry Grid)
  - 각 셀 높이 = `asset.width / asset.height` 비율로 계산, 짧은 컬럼에 우선 배분
  - 썸네일 `BorderRadius(6)` 라운딩
- [x] **갤러리 썸네일 깜박임 수정** — `_thumbCache` (Map) 부모 상태에서 관리, 재빌드 시 캐시 즉시 복원
- [x] **뽀얀 이펙트 추가** — 기존 `_fade` (CIColorMatrix 화이트 바이어스) UI 노출, 솜결 옆에 배치
  - 효과 순서: 밝기 → 대비 → 채도 → 솜결 → 뽀얀 → 글로우
- [x] **TDD 전면 도입** (CLAUDE.md TDD 방침 추가 + 테스트 4파일 신규 작성)
  - `test/core/models/filter_model_test.dart` — FilterModel, FilterData 15 tests
  - `test/features/camera/models/camera_state_test.dart` — CameraState 초기값/계산속성/copyWith/AspectRatio 32 tests
  - `test/core/models/user_preferences_test.dart` — UserPreferences 순수 로직 + Hive 연동 24 tests
  - `test/features/camera/providers/camera_notifier_test.dart` — CameraNotifier 채널/StorageService 28 tests
  - `test/widget_test.dart` — AppColors + FilterModel 위젯 렌더링 7 tests (기존 placeholder 교체)
  - **전체 106 tests, 0 failures** (`flutter test` 통과)
  - StorageService 테스트 픽스: `path_provider` 채널 mock + `StorageService.init()` 경유로 `_prefsBox` 올바르게 초기화

---

### ⏳ W14 — App Store 준비 (세션 14)

**가격:** ₩2,500 (Tier 2, 목표 ₩2,200에 가장 근접한 Apple 한국 티어)

**스크린샷 5장 구성 (6.5" + 5.5"):**

| 순서 | 화면 | 메시지 |
|------|------|--------|
| 1 | 카메라 + 필터 적용 중 | "탭 한 번으로 감성 사진" |
| 2 | 필터 바 30종 스크롤 | "30가지 감성 필터" |
| 3 | Before/After Split View | "내 사진이 이렇게 달라져요" |
| 4 | 에디터 슬라이더 | "세밀한 편집까지" |
| 5 | 갤러리 완성본 | "갤러리 사진도 OK" |

**메타데이터:**
- 앱 이름: `MoodFilm - 감성 필터 카메라`
- 부제목: `뽀얗고 감성적인 사진`
- 키워드: `필터카메라,감성필터,사진필터,셀카필터,필름감성,인스타감성,LUT필터,카메라앱,사진편집,무드필터`
- 카테고리: 사진 및 비디오 (Photography)
- 연령등급: 4+

**App Store Connect 체크리스트:**
- [ ] 앱 레코드 생성 (bundle ID: com.moodfilm.moodfilm)
- [ ] 가격 Tier 2 (₩2,500) 설정
- [ ] 앱 설명 (한국어 4000자)
- [ ] 키워드 입력
- [ ] 스크린샷 업로드 (6.5" × 5장, 5.5" × 5장)
- [ ] 개인정보처리방침 URL (GitHub Pages 또는 Notion)
- [ ] 아이콘 1024×1024 JPG (알파채널 없음)
- [ ] 빌드 업로드 (Xcode Archive → Distribute → App Store Connect)

### ⏳ W15 — TestFlight + App Store 제출 (세션 15)

**심사 거절 위험 요소 사전 점검:**

| 항목 | 대응 |
|------|------|
| 카메라 권한 설명 | Info.plist 구체적 설명 완료 |
| 개인정보처리방침 URL | 생성 필요 |
| 미구현 탭/버튼 | PaywallScreen 등 제거 확인 |
| 아이콘 알파채널 | 1024×1024 JPG 확인 |
| 크래시 | TestFlight 내부 테스터 검증 |

- [ ] TestFlight 내부 테스터 (본인 + 지인 5~10명)
- [ ] 크래시 / 버그 수정
- [ ] App Store 제출 → 심사 대기 (보통 24~48시간)

---

## 런칭 후 로드맵

| 버전 | 시점 | 주요 내용 |
|------|------|-----------|
| v1.1 | 런칭+1개월 | 매달 신규 필터 2~3종 업데이트, Dust Texture / Date Stamp 이펙트 |
| v1.2 | 런칭+2개월 | 오늘의 필터 위젯 (WidgetKit), 홈화면 바로가기 |
| v1.3 | 런칭+3개월 | Mood Match AI 필터 추천 (on-device CoreML), Android 출시 |
| v2.0 | 런칭+6개월 | 커스텀 필터 생성, 커뮤니티 공유, Mood Journal |

---

## 세션 5 변경사항 (2026-03-07)

- **더블필터링 버그 수정**: 카메라에서 LUT가 이미 적용된 JPEG을 저장하므로, EditorScreen은 기본적으로 필터 미적용(`_editorNoFilter = true`) 상태로 시작
- **"없음" 버튼 추가**: FilterScrollBar에 `_NoFilterItem` 위젯 추가 — 카메라/에디터 모두 적용
- **카메라 가운데 "MoodFilm" 텍스트 제거**
- **버튼 레이아웃 변경**: 비교(compare) 버튼을 tune 버튼 위로 이동; 카메라 전/후면 전환 버튼을 필터 버튼 옆에 추가
- **Split View 방향 수정**: 왼쪽=원본(before), 오른쪽=필터(after) — `MFLUTEngine.applyBeforeAfterSplit` beforeRect/afterRect 재계산
- **필터 기본 강도 최적화**: 100% → 50-75% 트렌드 기반 개별 최적화 (`FilterData.defaultIntensities`)
- **`CameraState.clearFilter`**: `copyWith`에 `clearFilter: bool` 파라미터 추가해 `activeFilter = null` 설정 가능
- **빌드 오류 수정**: `user_preferences.dart`에 `filter_model.dart` import 누락 추가

---

## 알려진 이슈 / 결정 사항

| 날짜 | 항목 | 결정 |
|------|------|------|
| 2026-03-06 | riverpod_generator 제외 | hive_generator와 analyzer 버전 충돌. Provider 수동 작성으로 대체 |
| 2026-03-06 | build_runner 버전 | ^2.4.13 사용 (^2.4.14는 hive_generator와 충돌) |
| 2026-03-08 | iOS 최소 버전 | 16.0 (W11에서 변경 완료) |
| 2026-03-06 | Firebase 초기화 | main.dart에서 주석 처리. GoogleService-Info.plist 추가 후 활성화 필요 |
| 2026-03-06 | 수익 모델 | 구독(월간/연간) 제거 → 1회 구매 ₩29,900 (`lifetime`)으로 단순화 |
| 2026-03-07 | 수익 모델 재확정 | IAP 완전 제거 → App Store 유료 앱으로 전환. 모든 필터 무제한 제공 |
| 2026-03-07 | EditorScreen | 열릴 때/슬라이더 변경 시 자동 필터 프리뷰 생성 (이전: Long press만 가능) |
| 2026-03-07 | 앱 가격 확정 | ₩2,500 (Tier 2, 목표 ₩2,200 → 가장 근접한 Apple KR 티어) |
| 2026-03-07 | 필터 확장 계획 | 22종 → 30종 (W11), 매달 2~3종 업데이트 (런칭 후) |
| 2026-03-07 | BerryFilm 벤치마킹 | 라이브포토(W12), Light Leak(W11), 필터 30종(W11), iOS 16 지원(W11) |

---







## 세션 6 변경사항 (2026-03-07)

### UI/UX 개선 (에디터 + 카메라)

**에디터 Split-View 수정:**
- 이미지 교체: 배경=원본(before), 왼쪽 클립=필터 적용본(after) — 이전 반대였던 것 수정
- 라벨 위치 변경: 상단 고정 → 분할 원(핸들) 옆에 동적으로 배치 (필터명 왼쪽, 원본 오른쪽)
- 하단 패널 애니메이션: `OverflowBox + ClipRect`로 아래에서 슬라이드업 (이전: 위에서 나타남)

**카메라 Split-View 수정:**
- 분할선 라벨 위치: 상단(top:60) → 핸들 원 옆으로 이동 (동적 위치)
- 라벨 좌우 교체: 필터명 왼쪽 / 원본 오른쪽 (native 실제 렌더링 기준으로 교정)
- 드래그 방향 수정: 전면 카메라 `nativePos = raw` → `1 - raw` 로 변경 (스와이프 방향과 화면 일치)

**카메라 버튼 레이아웃 변경:**
- 비교(compare) + 밝기(tune) 버튼을 상단에서 제거 → 화면 우측 32% 위치 플로팅 버튼으로 이동
- 셔터 버튼 정중앙 고정: `spaceEvenly` → `Expanded + Align` 으로 변경 (좌우 비대칭 해소)

**스플릿뷰 5초 자동 UI 숨김:**
- 스플릿 모드 진입 후 5초 비활동 시 셔터 버튼만 남기고 전체 UI 자동 숨김
- 화면 탭 또는 분할선 드래그 시 UI 복원 + 타이머 재시작

**버그 수정:**
- `Positioned` 위젯을 `AnimatedOpacity` 안에 감싸서 발생한 카메라 회색 화면 버그 수정
  → `AnimatedOpacity`를 `Positioned` 내부로 이동

---

## 세션 7 변경사항 (2026-03-07)

### 카메라 UI 전면 개편 (BerryFilm 스타일)

**레이아웃 구조 변경:**
- 풀스크린 오버레이 → BerryFilm 스타일: 상단 카메라 프리뷰(3:4) + 하단 흰색 컨트롤 영역으로 분리
- 프리뷰 영역: `SizedBox(width: screenW, height: screenW * 4/3)` 고정 비율
- 하단 컨트롤 영역: 배경 흰색, 필터명/강도 슬라이더, 모드탭, 셔터행
- 화면 비율 선택 버튼 제거 (기본값: 3:4)

**셔터 버튼:**
- 셔터 행: `Row(Expanded[갤러리], 셔터(center), Expanded[Row(필터버튼, 전환버튼)])`
- 셔터 색상 수정 (흰 배경에서 보이도록): 외곽 `Color(0xFFB0AAA5)`, 내부 `Color(0xFFF5F2EF)` + 그림자
- 흰 배경에서 ShutterButton 사라지는 버그 수정

**필터 바 토글:**
- 필터 바 기본 숨김, 셔터 옆 필터 버튼으로 토글
- `_showFilterPanel` 상태로 AnimatedContainer 슬라이드업/다운

**사이드 버튼 이동:**
- 설정/비교(compare)/밝기(tune) 버튼: 상단 → 카메라 프리뷰 우하단 `Positioned(right:10, bottom:12)`
- 스플릿 모드 자동 UI 숨김 제거 — 항상 전체 UI 표시

### 카메라 기본 비율 변경

- `CameraState` 기본 `aspectRatio`: `CameraAspectRatio.full` → `CameraAspectRatio.ratio3_4`

### Split View 버그 수정

**전면/후면 카메라 전환 후 분할선 틀어짐 수정:**
- `_computeNativeSplitPos`: `isFront ? (1.0 - pos) : pos` (후면은 직접 매핑)
- `_handleCameraFlip()` 후 새 `isFront` 값으로 split 위치 재전송

### 무음 셔터 기능 추가

**설정 화면:**
- `SettingsScreen` → `StatefulWidget`으로 변경
- "카메라" 섹션 + 무음 셔터 `SwitchListTile` 추가

**데이터 모델:**
- `UserPreferences`에 `@HiveField(9) bool isSilentShutter` 추가 (기본값: `false`)
- `user_preferences.g.dart`: `fields[9] as bool? ?? false` null 안전 처리 (기존 Hive 데이터 호환)

**Flutter:**
- `CameraEngine.capturePhotoSilent()` 메서드 추가 (`capturePhotoSilent` Method Channel)
- `CameraProvider.capturePhoto()`: `isSilentShutter` 여부에 따라 무음/일반 촬영 분기

**iOS Native:**
- `MFCameraSession.latestProcessedBuffer`: 최신 처리된 CVPixelBuffer 저장 (매 프레임 업데이트)
- `MFCameraSession.captureSilentPhoto()`: 최신 버퍼 → 비율 크롭 → UIImage JPEG 저장
  - 전면: `.leftMirrored` (EXIF 5 = 90°CW + 좌우반전) — 위아래 반전 버그 수정
  - 후면: `.right` (EXIF 6 = 90°CW)
- `CameraEnginePlugin`: `capturePhotoSilent` 케이스 추가, `PHPhotoLibrary` 갤러리 저장 연결

### 버그 수정

| 버그 | 원인 | 수정 |
|------|------|------|
| 앱 흰화면/크래시 | `fields[9] as bool` — null as bool TypeError | `fields[9] as bool? ?? false` |
| 전면 무음 촬영 위아래 반전 | `.rightMirrored` = 90°CCW + flip | `.leftMirrored` = 90°CW + flip |
| 후면 카메라 스플릿 반전 | `_computeNativeSplitPos`에서 front/back 동일 공식 | `isFront ? 1-pos : pos` 분기 |
| 카메라 전환 후 스플릿 틀어짐 | 전환 후 새 isFront로 native pos 재전송 안함 | `_handleCameraFlip` 후 재전송 |
| 셔터 버튼 안보임 | `AppColors.shutter = white` on white bg | 회색 테두리 + 연한 내부 + 그림자 |

---

---

## 세션 8 변경사항 (2026-03-07)

### 동영상 필터 처리 추가

**Native (FilterEnginePlugin.swift):**
- `import AVFoundation` 추가
- `handleProcessVideo` 메서드 추가:
  - `AVVideoComposition(asset:applyingCIFiltersWithHandler:)` — 각 프레임에 CIColorCube LUT 적용
  - `AVAssetExportSession` (AVAssetExportPresetHighestQuality) → 임시 MP4로 내보내기
  - `PHPhotoLibrary.performChanges` → 갤러리 저장
  - 완료 시 저장된 파일 경로 반환

**Flutter (filter_engine.dart):**
- `FilterEngine.processVideo()` static 메서드 추가
  - 파라미터: `sourcePath`, `lutFileName`, `intensity`, `effects`, `saveToGallery`
  - Method Channel: `processVideo`

### VideoPlayerScreen 필터 UI 추가 (신규 파일)

- `lib/features/gallery/presentation/video_player_screen.dart` 신규 생성
- AppBar "필터 적용" TextButton → 바텀시트에서 필터 선택
- `_applyFilter(FilterModel filter)` → `FilterEngine.processVideo()` 호출 + 처리 중 오버레이 표시
- `_VideoFilterPickerSheet` — 무료 필터 가로 스크롤 목록

### 갤러리 일괄 필터: 동영상 자동 건너뜀

- `_applyBatchFilter`에서 `AssetType.video` 자산은 건너뛰고 `_processedCount` 증가 후 다음으로 진행

### 갤러리 삭제 버그 수정

**원인:** `deleteWithIds` 후 `PHAssetChangeRequest` 완료 전 `getAssetListPaged` 재호출 → count 동일 → 실패 판정

**수정 내용:**
- 낙관적 UI 업데이트: `deleteWithIds` 호출 후 즉시 `_assets`에서 제거
- `PhotoManager.addChangeCallback(_onPhotosChanged)` + `startChangeNotify()` 추가 → iOS Photos 변경 시 `_quietReload()` 자동 트리거
- "삭제 실패 또는 취소되었습니다" 오류 메시지 제거 → 항상 "X개를 삭제했습니다" 표시

### 갤러리 사진 탭 → 잘못된 사진 표시 버그 수정

**원인:** Flutter가 GridView 아이템 재사용 시 `_AssetThumbnailState._bytes`가 이전 항목 데이터를 유지

**수정:**
- `_AssetThumbnail`에 `ValueKey(asset.id)` 추가 → 재사용 방지
- `_AssetThumbnail` 생성자에 `super.key` 추가
- `didUpdateWidget` 오버라이드: `asset.id` 변경 시 `_bytes = null` 리셋 후 재로드

### 에디터 → 카메라로 돌아가는 네비게이션 버그 수정

**원인:** `_selectAsset`에서 `context.pop()` 후 `context.push('/editor')` → 갤러리 스택이 pop됨

**수정:** `context.pop()` 제거 → 갤러리를 유지한 채 `/editor` push

### 에디터 버튼 가시성 개선 (어두운 동그란 버튼 스타일)

**원인:** `LiquidGlassPill` (흰색 8% opacity) → 밝은 사진 위에서 안 보임

**수정:**
- `_darkCircleBtn(IconData, VoidCallback)` 헬퍼 추가: 40×40px 반투명 검은 원 (`Colors.black.withValues(alpha:0.5)`) + 흰색 테두리 0.5px
- `_darkPillBtn(String, VoidCallback)` 헬퍼 추가: 저장 버튼 pill 스타일
- X 버튼, 저장 버튼: LiquidGlassPill → `_darkCircleBtn` / `_darkPillBtn` 교체
- 탭 버튼 (필터/조정/이펙트): 48px 원 + 활성 시 `AppColors.accent.withValues(alpha:0.3)`, 비활성 시 검은 반투명

### 버그 수정 요약

| 버그 | 원인 | 수정 |
|------|------|------|
| 갤러리 삭제 후 그대로 보임 | iOS 캐시 미반영 시 낙관적 업데이트 미사용 | optimistic UI + changeCallback 자동 동기화 |
| 잘못된 사진 표시 | GridView 아이템 재사용, 상태 미초기화 | ValueKey + didUpdateWidget 리셋 |
| 에디터 종료 시 카메라로 이동 | context.pop()이 갤러리를 스택에서 제거 | context.pop() 제거 |
| 에디터 버튼 안 보임 | LiquidGlassPill 투명도 부족 | 어두운 반투명 원/pill 스타일로 교체 |
| 일괄 필터 적용 시 동영상에서 멈춤 | 동영상 자산에 이미지 처리 시도 | 동영상 건너뜀 처리 |

---

## 세션 11 변경사항 (2026-03-08)

### W11: BerryFilm 벤치마킹 기능 추가

**iOS 최소버전 17 → 16:**
- `ios/Podfile`: `platform :ios, '16.0'`
- `ios/Runner.xcodeproj/project.pbxproj`: `IPHONEOS_DEPLOYMENT_TARGET = 16.0` (3곳)

**필터 30종 확장 (+8종):**
- 신규 필터: latte, mocha (Warm), pale, winter (Cool), bronze, noir (Film), blossom, vivid (Aesthetic)
- 33×33×33 `.cube` LUT 파일 Python 스크립트로 생성 (`/tmp/gen_luts_w11.py`)
- 60×60 JPG 썸네일 Python+PIL로 생성 (`/tmp/gen_thumbs_w11.py`, venv 환경)
- `filter_model.dart`: 8종 `FilterModel` 등록 + `defaultIntensities` 추가 (모두 `isNew: true`, `isPro: true`)

**Light Leak 이펙트:**
- `MFLUTEngine`: `lightLeakIntensity: Float` 프로퍼티 + `applyLightLeak()` 메서드
  - `CIRadialGradient` 2개: 좌상단 주황(α=intensity×0.65) + 우하단 노랑(α=intensity×0.45)
  - `CIAdditionCompositing` → `CIScreenBlendMode` 으로 이미지에 합성
  - 파이프라인 5번 위치 (Beauty 다음, Split 전)
- `CameraEnginePlugin`: `setEffect` switch에 `"lightLeak"` 케이스 추가
- `FilterEnginePlugin`: `processImage` + `processVideo` 양쪽에 `lightLeakIntensity` 연결
- `EditorScreen`: `_lightLeak` 상태변수 + `_hasEffects()` / `_resetEffects()` 반영 + `wb_sunny_rounded` 슬라이더 행 추가

### W12: 라이브포토 지원

**Swift 구현:**
- `MFCameraSession` delegate 메서드 `didCapturePhoto(path:livePhotoMovieURL:)` 로 통합 (기존 path-only 제거)
- `isLivePhotoEnabled`, `livePhotoMovieURL` 프로퍼티 추가
- `setLivePhotoEnabled(_:)`: `photoOutput.isLivePhotoCaptureEnabled` 설정
- `capturePhoto()`: 라이브포토 ON 시 `livePhotoMovieFileURL` MOV 임시경로 주입
- `configureSession`: photoOut 추가 시 `isLivePhotoCaptureEnabled` 동기화
- `MFCameraSession.swift`: `import Photos` 추가
- `CameraEnginePlugin`: `setLivePhotoEnabled` Method 핸들러 추가
  - `didCapturePhoto` delegate: `livePhotoMovieURL != nil` 시 `PHAssetCreationRequest.forAsset()` + `.pairedVideo` 저장, 아닐 시 기존 `creationRequestForAssetFromImage`

**Flutter 구현:**
- `UserPreferences`: `@HiveField(10) bool isLivePhotoEnabled` 추가 (기본 false)
- `user_preferences.g.dart`: build_runner 재생성
- `CameraEngine`: `setLivePhotoEnabled(bool)` 메서드 추가
- `camera_provider.dart`: 초기화 시 `prefs.isLivePhotoEnabled && !prefs.isSilentShutter` 조건으로 복원
- `CameraScreen` 사이드 버튼: `motion_photos_on_rounded` 아이콘 토글 (무음셔터 자동 해제)
- `SettingsScreen`: 라이브포토 `SwitchListTile` 추가 (무음셔터 ON 시 라이브포토 자동 해제, 반대도 동일)

**결과:** `flutter analyze` 0 issues, git commit `9b25a02`

---

## 세션 12 변경사항 (2026-03-08)

### EditorScreen 완전 리디자인 (갤러리 사진 클릭 시)

**UI 구조 변경:**
- 배경: 검정 → **흰색**
- 상단 바: ← 뒤로 / 🗑️ 삭제 / ↓ 저장 (심플 아이콘)
- 이미지 영역: 패딩+rounded corners(14), **항상 Before/After 스플릿 뷰** (왼쪽=원본, 오른쪽=필터)
- 조정 행: 5개 파라미터 수평 배치 (밝기/대비/채도/뽀용/글로우), 활성 항목 분홍 pill로 값 표시
- 슬라이더: 분홍 테마 (`#D4A0B0` active / `#8A6870` thumb)
- 하단 탭: 필터 / 효과 2개로 단순화

**삭제 기능 추가:**
- `EditorScreen.assetId` 파라미터 추가 (optional)
- 갤러리에서 올 때만 🗑️ 버튼 표시 → `PhotoManager.editor.deleteWithIds`

**라우터 + 갤러리 업데이트:**
- `router.dart`: extra `Map<String, String?>` 처리 (`path` + `assetId`)
- `gallery_picker_screen.dart`: `context.push('/editor', extra: {'path': ..., 'assetId': ...})`

### 사진 저장 EXIF 버그 수정 (MFCameraSession.swift)

**문제:** `ciContext.jpegRepresentation`은 EXIF orientation 메타데이터를 제거 → 저장 사진이 가로(landscape)로 저장됨

**수정:** `UIImage.jpegData(compressionQuality:)` 방식으로 변경
- `UIImage(cgImage: cgImg, scale: 1.0, orientation: isFront ? .leftMirrored : .right)` → `jpegData()`
- EXIF orientation JPEG에 포함 → 갤러리에서 **세로(portrait 3:4)** 로 올바르게 표시

**동작 흐름:**
1. `CIImage(data: imageData)` — raw landscape extent (e.g. 4032×3024)
2. 사용자 aspect ratio 크롭 (1:1/9:16 등 선택 시)
3. LUT 필터 적용
4. `createCGImage` → `UIImage(.right)` → `jpegData()` — portrait EXIF 포함

### camera_provider.dart

- `initialize()` 시 `setAspectRatio(state.aspectRatio.nativeKey)` 추가 — 초기화 후 프리뷰와 사진 저장 비율 동기화

## 다음 세션에서 할 일 (W13)

1. **App Store Connect 앱 레코드 생성** — Bundle ID: com.moodfilm.moodfilm, 가격 Tier 2 (₩2,500)
2. **개인정보처리방침 URL** — GitHub Pages 또는 Notion으로 생성
3. **앱 아이콘 1024×1024** — JPG, 알파채널 없음
4. **스크린샷 5장** — 6.5" + 5.5" Simulator로 생성
5. **메타데이터 입력** — 앱 이름, 설명, 키워드
6. **Xcode Archive → App Store Connect 업로드**
