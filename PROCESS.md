# MoodFilm 개발 진행 현황
> 마지막 업데이트: 2026-03-11 (세션 27)

---

## 전체 진행률

```
Phase 1: Foundation      [██████████] W1-W3 완료
Phase 2: Core Features   [██████████] W4-W6 완료
Phase 3: Polish          [██████████] W7-W9 완료
Phase 4: QA & Launch     [█████████░] W10-W15 완료 / App Store 심사 대기 중
```

> 마지막 작업 세션: 세션 27 (2026-03-11) — App Store 제출 완료 (빌드 업로드, GitHub Pages, 스크린샷)

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
- [x] **수익 모델: 1회 구매 ₩2,200 → 전체 26종 필터 영구 사용** (구독 없음, 무료 체험 없음)
- [x] RevenueCat IAP 유지 (`lifetime` product, `pro` entitlement)
- [x] PaywallScreen: 가격 ₩2,200 표시, 1회 구매 안내
- [x] 모든 필터 26종 구매 후 무제한 사용
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

### ✅ W14 — App Store 준비 (세션 14~26)

**가격:** ₩2,200 (RevenueCat `lifetime` 1회 구매, 전체 26종 영구 사용)

**스크린샷 5장 구성 (6.5" + 5.5"):**

| 순서 | 화면 | 메시지 |
|------|------|--------|
| 1 | 카메라 + 필터 적용 중 | "탭 한 번으로 감성 사진" |
| 2 | 필터 바 26종 스크롤 | "26가지 감성 필터" |
| 3 | Before/After Split View | "내 사진이 이렇게 달라져요" |
| 4 | 에디터 슬라이더 | "세밀한 편집까지" |
| 5 | 갤러리 완성본 | "갤러리 사진도 OK" |

**메타데이터:**
- 앱 이름: `Like it! - 감성 필터 카메라`
- 부제목: `뽀얗고 감성적인 사진`
- 키워드: `필터카메라,감성필터,사진필터,셀카필터,필름감성,인스타감성,LUT필터,카메라앱,사진편집,무드필터`
- 카테고리: 사진 및 비디오 (Photography)
- 연령등급: 4+
- 지원 언어: 한국어·영어·일본어·중국어·프랑스어·힌디어

**App Store Connect 체크리스트:**
- [ ] 앱 레코드 생성 (bundle ID: com.moodfilm.moodfilm)
- [ ] 가격 ₩2,200 설정
- [ ] 앱 설명 (한국어 4000자)
- [ ] 키워드 입력
- [ ] 스크린샷 업로드 (6.5" × 5장, 5.5" × 5장)
- [ ] 개인정보처리방침 URL (GitHub Pages 또는 Notion)
- [ ] 아이콘 1024×1024 JPG (알파채널 없음)
- [ ] 빌드 업로드 (Xcode Archive → Distribute → App Store Connect)

### ✅ W15 — App Store 제출 (세션 27, 2026-03-11)

**심사 거절 위험 요소 사전 점검:**

| 항목 | 대응 |
|------|------|
| 카메라 권한 설명 | Info.plist 구체적 설명 완료 |
| 개인정보처리방침 URL | GitHub Pages 생성 완료 |
| 미구현 탭/버튼 | PaywallScreen 등 제거 확인 |
| 아이콘 알파채널 | 1024×1024 JPG 확인 |
| 크래시 | TestFlight 내부 테스터 검증 |

- [x] GitHub Pages 생성 — `https://moonkj.github.io/likeit-support/`
- [x] 개인정보처리방침 URL — `https://moonkj.github.io/likeit-support/privacy_policy.html`
- [x] 지원 URL — `https://moonkj.github.io/likeit-support/support.html`
- [x] 문의 이메일 — `imurmkj@gmail.com`
- [x] App Store Connect 메타데이터 6개 언어 작성 (한/영/일/중/불/힌)
- [x] 스크린샷 변환 — 1320×2868 JPG, 알파채널 제거 (`/Downloads/screenshots_fixed/`)
- [x] IPA 빌드 업로드 — xcrun altool, 41MB, Delivery UUID: b5f41d63
- [ ] App Store 심사 대기 (24~48시간)

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
| 2026-03-06 | 수익 모델 | 구독(월간/연간) 제거 → 1회 구매 방식으로 단순화 |
| 2026-03-07 | 수익 모델 확정 | RevenueCat IAP `lifetime` 1회 구매 ₩2,200 → 전체 26종 영구 사용 (freemium 아님) |
| 2026-03-07 | EditorScreen | 열릴 때/슬라이더 변경 시 자동 필터 프리뷰 생성 (이전: Long press만 가능) |
| 2026-03-07 | 필터 수 확정 | 30종 → cafe_mood·seoul_night·bronze·noir 제거 → **26종** (세션 15) |
| 2026-03-07 | BerryFilm 벤치마킹 | Light Leak(W11), 필터 확장(W11), iOS 16 지원(W11) / 라이브포토(W12→제거) |
| 2026-03-10 | 현지화 | 6개국 언어 (한·영·일·중·불·힌) 지원, 아이패드 타겟 제거 |

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

## 세션 14 변경사항 (2026-03-08) — 흰화면 버그 수정

### 문제: 앱 실행 시 흰 화면만 표시

**원인 1 — Flutter Texture 투명 렌더링:**
- `Texture(textureId)` 위젯은 첫 프레임이 도착하기 전까지 투명하게 렌더링됨
- 카메라가 textureId를 반환했지만 아직 프레임이 없는 구간 → 투명 Texture 아래 흰 `Scaffold(backgroundColor: Colors.white)` 배경이 노출
- 카메라 세션 자체에 문제가 있어 프레임이 아예 안 오는 경우에도 동일 현상

**원인 2 — Hive 박스 손상 시 앱 크래시:**
- `await StorageService.init()`에 예외 처리 없음 → Hive 박스 손상 시 `main()` 크래시 → `runApp()` 미실행 → 흰 화면

### 수정

**`camera_screen.dart` — 프리뷰 Stack 검은 배경 추가:**
```dart
Stack(
  fit: StackFit.expand,
  children: [
    const ColoredBox(color: Colors.black), // 추가: Texture 투명 시 흰 배경 방지
    _buildCameraPreview(cameraState),
    ...
  ],
)
```

**`main.dart` — Hive 초기화 에러 처리:**
```dart
try {
  await StorageService.init();
} catch (_) {
  await Hive.deleteBoxFromDisk('user_preferences'); // 손상 박스 삭제
  await StorageService.init(); // 기본값으로 재초기화
}
```

**결과:** `flutter clean` + `flutter run --release` → 앱 정상 구동 확인

---

## 다음 세션에서 할 일 (W16 — 심사 대응 및 출시)

1. **App Store 심사 결과 확인** — 승인 또는 거절 사유 대응
2. **거절 시 수정 후 재제출** — 심사관 피드백 기반
3. **승인 후 출시** — 판매 가능 날짜 설정 또는 즉시 출시
4. **출시 후 모니터링** — 크래시, 리뷰, 전환율 확인

---

## 세션 15 변경사항 (2026-03-08) — UI 전면 개편

### 필터바 UI 개편

- **썸네일 직사각형(3:4)**: `filterThumbnailWidth=52, filterThumbnailHeight=70` (AppDimensions)
- **이름 분리**: 썸네일 아래 별도 텍스트 레이블 (AppColors.textPrimary/textSecondary)
- **자동 스크롤 제거**: 필터 선택 시 스크롤 이동 없음 (ScrollController 제거)
- **Disposable → Lomo** 이름 변경 (`filter_model.dart`)
- **필터 삭제**: cafe_mood, seoul_night, bronze, noir 4종 제거 → 필터 26종

### 비교(Split) 모드 개선

- 비교 모드 중 촬영 시 구분선 없이 필터만 적용된 사진 저장 (native에 `position: -1.0` 전달 후 복원)

### 에디터 화면 기능 추가

- **비교 토글 버튼** (`compare_rounded`): `_showSplit` 상태로 이미지 Before/After 전환
- **공유 버튼** (`ios_share_rounded`): `share_plus`로 이미지 공유 (`_shareImage()`)

### 라이브포토 기능 전체 제거

- `UserPreferences.isLivePhotoEnabled` (@HiveField(10)) 필드 삭제 (index 10 예약)
- `CameraEngine.setLivePhotoEnabled()` 메서드 삭제
- 카메라 사이드 버튼 라이브포토 토글 제거
- 설정 화면 라이브포토 SwitchListTile 제거
- 재구현 가이드는 `## 라이브포토 기능 — 제거됨` 섹션 참조

### 카메라 하단 레이아웃 재편

**버튼 순서:** `[갤러리, 필터] [셔터/동영상] [색보정효과, 카메라전환]`

- **좌측**: 갤러리 + 필터(`auto_awesome`) 버튼
- **중앙**: 셔터(사진 모드) / 동영상 녹화 버튼
- **우측**: 색보정 효과(`auto_fix_high_rounded`) + 카메라전환

### 색보정 효과 패널 (카메라 내)

- **패널 토글**: `_showEffectsPanel` 상태, 필터 패널과 상호 배타적
- **구조**: 6개 버튼 탭 선택 + 단일 슬라이더 (에디터와 동일)
- **항목**: 밝기, 대비, 채도, 솜결(grain), 뽀얀(fade), 글로우(glow)
- 패널 열릴 때 사진/동영상 탭과 간격 12px 추가 (`SizedBox(height: _showEffectsPanel ? 12 : 4)`)

### 강도 슬라이더 위치

- 프리뷰 우측 사이드 버튼 (설정 버튼 위) — `_showIntensitySlider` 토글

### 갤러리(GalleryPickerScreen) 리디자인

- **배경**: 흰색 (`Colors.white`)
- **그리드**: 2컬럼 → **3컬럼 마소니 그리드** (`gap=2.0`, shortest-column 알고리즘)
- **동영상 재생시간 뱃지**: 우하단 `mm:ss` 형식 (`_formatDuration`)
- **하단 탭 바**: 앨범 탭(선택됨) + 카메라 탭 (`_buildBottomTabBar()`)
- **텍스트/아이콘**: 라이트 테마 (`Color(0xFF3D3531)`)

### 버튼 디자인 개편

**셔터 버튼 (`shutter_button.dart`):**
- 외곽 민트 그라디언트 링: `Color(0xFF5CE8D8)` → `Color(0xFF8FF5EC)`, 두께 ~3.5px
- 외부: 80px (`shutterButtonSize+4`), 내부: 73px (`shutterButtonInner+9`)
- 내부 원: 흰색→크림 그라디언트 + 라벤더 글로우 그림자

**동영상 버튼 (`_buildVideoRecordButton`):**
- **민트 링 없음** — 동영상 모드는 링 제거
- 대기 중: 큰 빨간 원 (74px), 빨간 글로우 그림자 (`Colors.red.withValues(alpha:0.4)`)
- 녹화 중: 흰 원 배경 + 빨간 사각형(28px, radius:6) — 정지 아이콘

---

## 세션 16 변경사항

### 에디터 / 갤러리 UX 개선

**효과 로딩 오버레이 위치 수정:**
- 기존: `SafeArea` 전체를 덮는 반투명 오버레이 → 전체화면 깜빡거림
- 수정: `_buildImageSection()` 내부 `Stack`으로 이동 → 이미지 영역에만 표시

**필터 전체보기("전체") 버튼 제거:**
- `FilterScrollBar`에서 `_AllFiltersButton` 클래스 삭제
- `go_router` import 제거, `itemCount`에서 +1 제거

**갤러리 상단 바 버튼 스타일 통일:**
- 다중선택 모드 공유·삭제 버튼: `IconButton` → 회색 원 `GestureDetector` + `Container`
- 에디터 삭제 버튼: `IconButton` → 회색 원 Container, 아이콘 빨간색

**공유 기능 — 필터+효과 적용 결과물 공유:**
- 에디터: 필터·효과 있으면 `FilterEngine.processImage()` 후 공유, 없으면 원본 즉시 공유
- 동영상 플레이어: 필터·효과 있으면 `FilterEngine.processVideo(saveToGallery: false)` 후 공유
- 갤러리 목록 다중선택: 원본 파일 공유

**사진 크롭 문제 수정 (에디터):**
- `Image.file()` `BoxFit.cover` → `BoxFit.contain` + `height: double.infinity`
- letterbox 배경: `Positioned.fill` + `ColoredBox(Color(0xFFF5F2EF))` 추가

**패널 고정 높이 — 이미지 위로 올라가는 문제 해결:**
- 에디터/동영상 플레이어: 필터·효과 패널을 `SizedBox(height: 152)`로 감쌈
- 탭 전환 시 이미지 크기 변화 없음

**탭 버튼 터치 영역 개선:**
- `GestureDetector`에 `behavior: HitTestBehavior.opaque` 추가
- 패딩 `horizontal: 24` → `horizontal: 32, vertical: 8`

**전체 초기화 버튼 (필터 + 효과):**
- 에디터·동영상 플레이어 상단 바에 "초기화" pill 버튼 추가
- 필터 또는 효과 중 하나라도 적용 시 표시
- 탭 시 `clearFilter()` + 모든 효과값 0 초기화

**필터 강도 슬라이더 (에디터·동영상 플레이어):**
- 필터 선택 시 FilterScrollBar 아래에 강도 슬라이더 표시
- `cameraProvider.setFilterIntensity()` 연동
- 에디터: `onChangeEnd` → `_generatePreview()` 트리거

---

## 라이브포토 기능 — 제거됨 (향후 구현 예정)

### 제거 이유
- 앱 스토어 출시 전 기능 간소화
- 무음셔터와 상호 배타 로직 복잡성
- 추후 별도 업데이트로 추가 예정

### 제거된 항목
- `UserPreferences.isLivePhotoEnabled` (@HiveField(10)) — 필드 삭제, index 10은 예약됨
- `CameraEngine.setLivePhotoEnabled(bool)` — 메서드 삭제
- 카메라 화면 사이드 버튼 "라이브포토"
- 설정 화면 "라이브포토" SwitchListTile

### 재구현 시 필요 작업
1. `UserPreferences`에 `@HiveField(10) bool isLivePhotoEnabled` 재추가 (index 10 그대로 사용)
2. `CameraEngine.setLivePhotoEnabled(bool)` 메서드 재추가
3. `MFCameraSession.swift` — `isLivePhotoEnabled`, `setLivePhotoEnabled()`, `livePhotoMovieURL` 로직 복원
4. `CameraEnginePlugin.swift` — `setLivePhotoEnabled` case 핸들러 + `didCapturePhoto` delegate에서 PHAssetCreationRequest pairedVideo 복원
5. 카메라 화면 사이드 버튼 추가 + 무음셔터 상호배타 처리
6. 설정 화면 토글 추가

### Swift 구현 핵심 (메모)
```swift
// MFCameraSession.swift
var isLivePhotoEnabled: Bool = false
private var livePhotoMovieURL: URL?

func capturePhoto() {
    if isLivePhotoEnabled && photoOutput.isLivePhotoCaptureSupported {
        let movURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".mov")
        livePhotoMovieURL = movURL
        settings.livePhotoMovieFileURL = movURL
    }
}

// CameraEnginePlugin.swift — didCapturePhoto delegate
if let movURL = livePhotoMovieURL {
    // PHAssetCreationRequest + pairedVideo
    request.addResource(with: .photo, fileURL: photoURL, options: nil)
    let videoOptions = PHAssetResourceCreationOptions()
    videoOptions.shouldMoveFile = true
    request.addResource(with: .pairedVideo, fileURL: movURL, options: videoOptions)
}
```

---

## 세션 17 변경사항 (2026-03-08) — 카메라 UX 개선

### 카메라 화면 강도 슬라이더 레이아웃 수정
- **문제:** 강도 버튼 탭 시 슬라이더가 Column에 삽입되어 셔터 버튼 등이 아래로 밀림
- **해결:** `AnimatedContainer` 제거 → 카메라 프리뷰 Stack의 `Positioned` 오버레이로 이동
- 슬라이더 스타일: 반투명 검정 pill 배경 (`Colors.black.withValues(alpha: 0.45)`)
- 위치: 프리뷰 하단 52px 위 (`top: safeTop + previewH - 52`)

### 카메라 사이드 버튼 위치 조정 (강도/비교/설정)
- 기존: `Positioned(right:10, bottom:12)` — 슬라이더와 겹침
- 수정: `Positioned(right:10, bottom:68)` — 슬라이더 위 충분한 여백

### 사진/동영상 텍스트 위치 고정
- **문제:** 필터 패널(100px)↔효과 패널(~140px) 전환 시 텍스트 위치 변동
- **해결:** 두 패널을 `SizedBox(height: 116)` + `AnimatedSwitcher`로 고정
- 탭 전환해도 모드 텍스트·셔터 버튼 위치 변동 없음

### 스플릿 비교 라벨 겹침 버그 수정
- **문제:** 스플릿 라인을 우측 끝으로 이동 시 "원본" 라벨이 선 왼쪽으로 튀어나옴
- **해결:** `Positioned` 개별 clamp 방식 → `Row(SizedBox, SizedBox)` 분할 레이아웃으로 교체
- 라벨이 항상 선의 각자 영역 안에 배치됨 (overflow 시 자동으로 공간 없어져 숨겨짐)

### 갤러리 일괄 필터 선택 바텀시트 썸네일 수정
- **문제:** `_FilterPickerSheet` 필터 아이템이 `Icons.filter_rounded` 플레이스홀더만 표시
- **해결:** `Image.asset(f.thumbnailAssetPath)` + `ClipRRect`로 실제 썸네일 이미지 로드
- errorBuilder: 썸네일 로드 실패 시 fallback 아이콘 표시

---

## 세션 18 변경사항 (2026-03-09) — 앱 이름·아이콘·이펙트·폰트

### 앱 아이콘 교체
- iOS AppIcon.appiconset 전체 사이즈 (1024 포함) 교체 — 하트 렌즈 아이콘
- Android mipmap-hdpi/mdpi/xhdpi/xxhdpi/xxxhdpi 교체
- 마스터 원본: `icon_master_1024.png` (소프트 피치 배경 + 라벤더 렌즈 + 하트)

### 앱 이름 MoodFilm → Like it! 변경
- iOS Info.plist: CFBundleDisplayName, CFBundleName, NSCameraUsageDescription
- Android AndroidManifest.xml: android:label
- pubspec.yaml: description
- `lib/app.dart`: 클래스명 `MoodFilmApp` → `LikeItApp`, title
- `lib/main.dart`: `LikeItApp()` 참조
- 온보딩·페이월·필터모델 문자열 전체 수정
- **유지:** Bundle ID `com.moodfilm.moodfilm`, pubspec name `moodfilm`, Method Channel 명

### 카메라 이펙트 버그 수정
- `"glow"` 키 → `"dreamyGlow"`와 동일 처리 (Flutter ↔ Swift 불일치 해소)
- `softness` / `brightness` / `contrast` / `saturation` Swift 처리 추가
  - `applySoftness()`: Gaussian blur(radius×10) + alpha 블렌딩(0.75)
  - 색보정: `CIColorControls` (brightness×0.5, contrast 1+v, saturation 1+v)
- `MFCameraSession.hasEffect` 조건에 신규 이펙트 추가

### 카메라 기본 이펙트값 설정
- 솜결(softness) 기본 30%, 뽀얀(beauty) 기본 25%
- 카메라 초기화 후 `_applyDefaultEffects()` 자동 호출
- 백그라운드 복귀(`didChangeAppLifecycleState resumed`) 시 재적용

### Nunito 폰트 적용 (google_fonts ^6.2.1)
- 갤러리 타이틀 "Like it!": italic bold → Nunito w800 (부드럽고 귀여운 느낌)
- 온보딩 타이틀: AppTypography.h1 → Nunito w800 size 36
- "Like it" 다크(`#3D3531`), "!" 라벤더 accent(`#C8A2D0`) 색상 유지

### 갤러리 배치 필터 저장 버그 수정
- 다중선택 → 필터 적용 후 갤러리에 저장 안 되는 버그
- `FilterEngine.processImage()` 호출 시 `saveToGallery: true` 명시 (기본값 false였음)

---

## 세션 19 (2026-03-09) — 카메라 타이머 기능

### 구현 내용
- 카메라 우측 사이드 버튼에 타이머 버튼 추가 (강도 버튼 위)
- 탭할 때마다 `off → 3초 → 5초 → 10초 → off` 순환
- 버튼 내부에 설정된 초 숫자 표시 (`3s`, `5s`, `10s`) / off 시 아이콘 표시
- 활성화 시 accent 색상으로 강조

### 카운트다운 동작
- 셔터 탭 → 프리뷰 중앙에 큰 숫자(110px) 카운트다운 표시
- 매초 햅틱 피드백(`HapticUtils.filterChange`)
- 카운트다운 중 셔터 재탭 → 즉시 취소
- 0이 되면 자동 촬영 + 스플릿 모드 처리

### 변경 파일
- `lib/features/camera/presentation/camera_screen.dart`
  - 상태변수: `_timerSeconds`, `_timerCountdown`, `_countdownTimer`, `_isCountingDown`
  - `_timerSideBtn()`: 타이머 사이드 버튼 위젯
  - `_handleShutterTap()`: 타이머 분기 + 카운트다운 로직
  - `_doCapturePhoto()`: 촬영 로직 분리 (스플릿 모드 포함)
  - 카운트다운 오버레이: 프리뷰 Stack 내 `IgnorePointer` 중앙 텍스트
  - `ShutterButton.isCapturing`: 카운트다운 중에도 눌림 상태로 표시

---

## 세션 20 (2026-03-09) — 에디터 자르기 기능 + UX 개선

### 에디터 자르기(Crop) 기능 신규 추가
- 에디터 하단 탭 바에 "자르기" 탭 추가 (필터/효과/자르기 3탭)
- 비율 선택: 자유형 / 정방형(1:1) / 4:5 / 9:16 / 3:4 / 16:9 / 4:3
- 인터랙티브 크롭 오버레이: 마스크 + 3×3 가이드라인 + 코너 핸들
- 코너 핸들 드래그로 크롭 영역 조절 (비율 잠금 시 종횡비 유지)
- 크롭 영역 내부 드래그로 위치 이동
- 비율 선택 시 최대 크기로 중앙 자동 적용 (`normRatio = ratio / imgAspect`)
- "적용" → `dart:ui` `Canvas.drawImageRect`로 크롭 후 PNG 임시 저장
- 크롭 적용 후 `_croppedSourcePath` 업데이트, 이후 필터/효과는 크롭본에 적용

### 에디터 UX 개선
- **에디터 전체 초기화 버튼 제거**: 상단에 "초기화" 버튼 이미 있으므로 슬라이더 아래 "전체 초기화" 제거
- **효과 슬라이더 위치 조정**: `padding.top` 12 → 24 (아이콘 행과 간격 증가)
- **필터 강도 슬라이더 % 표시**: 슬라이더 오른쪽에 `xx%` 텍스트 추가

### 필터 썸네일 교체 (dream 이미지)
- `mocha`, `latte`, `peach` 썸네일을 dream 이미지(벚꽃 배경 여성) 기반으로 재생성
  - mocha: 브라운 채도↓ + 어둡게
  - latte: 밝고 크림빛 + 채도↓
  - peach: 핑크 따뜻한 톤
- `lavender`, `milk` 썸네일을 kodak_soft 이미지(서울 야경 여성) 기반으로 재생성
  - lavender: 보라빛 tint (r×1.05, g×0.78, b×1.35)
  - milk: 뿌연 화이트 (채도 45%로 낮춤, 밝기 +25%)

### 필터 순서 재편
- dream, peach, latte, mocha 그룹 (벚꽃 배경)
- cream, lomo, retro_ccd 그룹 (컬리 웨이브 실내)
- kodak_soft, butter, film98, mint, cloud 그룹 (단발 야외)
- vivid, ice, sky, ocean, winter, dusty_blue 그룹 (블루셔츠 스튜디오)
- mood, soft_pink, blossom 그룹 (오프숄더 보케)
- honey, film03, pale 그룹 (베이지 스웨터 골든 보케)
- kodak_soft, milk, lavender: mocha 오른쪽으로 이동 (서울 야경 그룹)

## 세션 21 (2026-03-10) — 커버리지 테스트 + 공유 버그 수정

### 테스트 커버리지 70.1% 달성 (162개 모두 통과)
- **수정**: `filter_model_test.dart` 필터 수 기대값 30 → 26 (실제 필터 수 반영)
- **수정**: `camera_state_test.dart` `isFrontCamera` 기대값 true → false (기본값 반영)
- **추가**: `test/core/utils/haptic_utils_test.dart` — HapticUtils 6개 메서드 전체 커버
- **추가**: `camera_engine_test.dart` — `pauseSession`, `resumeSession`, `setFilter`, `setEffect` 테스트
- **추가**: `camera_state_test.dart` — `nativeKey` 전 케이스, `ratio` 추가 케이스
- **추가**: `camera_notifier_test.dart` — `isSilentShutter=true` 경로 커버 (capturePhotoSilent)
- 커버리지: 67.5% → 70.1% (285 → 296 / 422 라인)

### 에디터 공유 기능 버그 수정
**증상**: 공유 버튼 탭 시 아무 반응 없음 → `PlatformException: sharePositionOrigin must be set`

**원인**: iOS에서 `Share.shareXFiles`는 `sharePositionOrigin` (공유 시트 팝오버 기준점) 필수

**수정 내용** (`editor_screen.dart`):
- `GlobalKey _shareButtonKey` 추가 → 공유 버튼에 key 연결
- `_shareOriginRect()` 메서드: RenderBox로 버튼의 화면 위치(Rect) 계산
- 모든 `Share.shareXFiles` 호출에 `sharePositionOrigin: origin` 전달
- `_mimeType(path)` 헬퍼: 확장자별 MIME 타입 반환 (jpg/png/heic)
- `_showSnackBar()` 헬퍼: 에러/일반 스낵바 통합
- 파일 존재 확인 (`File(src).existsSync()`) 후 공유
- 프리뷰(`_filteredPreviewPath`) 재사용 — 공유 시 불필요한 재처리 방지
- `dart:math` 미사용 import 제거

## 세션 22 (2026-03-10) — 효과 순서 변경 + 공유 버그 수정

### 카메라/에디터 효과 순서 변경
- **카메라 화면** (`camera_screen.dart` `_effectItems`): 밝기→대비→채도→솜결→뽀얀→글로우 → **솜결→뽀얀→밝기→대비→채도→글로우**
- **에디터 화면** (`editor_screen.dart` `_params`): 동일하게 변경 (`_getParamValue` / `_setParamValueDirectly` 인덱스 동기화)

---

## 세션 23 (2026-03-10) — 스플래시 화면 + 필터 썸네일 인물 교체

### 스플래시 화면 신규 추가
- `/splash` 라우트 추가 (`initialLocation: '/splash'`)
- `SplashScreen` 위젯 신규 생성 (`lib/features/splash/presentation/splash_screen.dart`)
  - `AnimationController` 3초 (fade-in 20% → hold 60% → fade-out 20%)
  - 완료 시 `context.go('/')` → 카메라 화면으로 이동
  - 카메라 화면 진입 시 `CustomTransitionPage` 600ms fade 트랜지션 적용
- 스플래시 이미지: `assets/images/splash_logo.png` (카메라 렌즈 + "Like it!" + "감성 필터 카메라", `BoxFit.cover`)
- 배경색: `#FBF5EE` (크림 화이트)

### 필터 썸네일 전체 교체 (인물 사진 기반)
- 소스: 8명 인물 그리드 이미지 (2×4, 704×1531px)
- Python/PIL로 자동 처리: 인물 자르기 → 정방형 크롭(얼굴 위쪽 기준) → 180×180 리사이즈 → 필터 색감 적용 → JPEG 저장
- **인물-필터 배정** (26종):

| 인물 | 필터 |
|------|------|
| 1번 (1행 좌) | dream · peach · latte |
| 2번 (1행 우) | mocha · kodak_soft · milk |
| 3번 (2행 좌) | lavender · vivid · ice |
| 4번 (2행 우) | cream · disposable · retro_ccd |
| 5번 (3행 좌) | butter · film98 · mint |
| 6번 (3행 우) | cloud · sky · ocean |
| 7번 (4행 좌) | winter · dusty_blue · mood · soft_pink |
| 8번 (4행 우) | blossom · honey · film03 · pale |

- 필터별 색감 변환: warm(적색 채널 강화), cool(청색 채널 강화), film(대비+그레인), aesthetic(채도↓+밝기↑)

---

## 세션 24 (2026-03-10) — 카메라 UX 개선 + 비교 스플릿 방향 수정

### 카메라 사이드 버튼 "강도" → "필터효과" 이름 변경
- `_sideLabeledBtn` label + `_showSideBtnLabel` 호출 텍스트 변경

### 비교 스플릿 라벨 위치: 원 아래 → 원과 수평
- `_buildSplitOverlay`: `top: cy + 42` → `top: cy + 9`
- 라벨을 원(36px) 너비 기준 좌우로 배치 (SizedBox로 원 건너뜀)
- 왼쪽: "원본", 오른쪽: 필터이름

### 비교 스플릿 방향 수정 (왼쪽=원본, 오른쪽=필터)
- 기존: 왼쪽=필터, 오른쪽=원본 → 갤러리/에디터와 반대였음
- **Swift `MFLUTEngine.applyBeforeAfterSplit` 수정:**
  - 후면: `originalPart=[minY, splitY)` (저Y→회전후LEFT), `filteredPart=[splitY, maxY)` (고Y→회전후RIGHT)
  - 전면: `originalPart=[splitY, maxY)` (고Y→회전+미러후LEFT), `filteredPart=[minY, splitY)` (저Y→회전+미러후RIGHT)
- Flutter `_computeNativeSplitPos`: 원래대로 유지 (front: `1-pos`, back: `pos`)

### 동영상 녹화 중 비교선 숨김
- `_buildPreviewStack`: `if (_isSplitMode && !cameraState.isRecording)` 조건 추가
- 동영상 녹화 시작 시 `CameraEngine.setSplitMode(position: -1.0)` → 전체 필터 적용
- 동영상 녹화 종료 시 스플릿 위치 복원

---

## 세션 25 (2026-03-10) — 전체 코드 디버깅 (7개 버그 수정 + analyze clean)

### Critical 버그 수정
- **camera_provider**: `beauty` 기본값 0.45 제거 → `camera_screen`의 `_applyDefaultEffects()`(0.25)와 충돌했던 이중 설정 해소

### High 버그 수정
- **CameraEnginePlugin.swift**: 갤러리 권한 거부 시 성공 반환 → `PERMISSION_DENIED` 에러 반환으로 수정
- **camera_provider**: `initialize()` 중복 호출 가드 추가 → race condition 방지
- **camera_provider**: `startRecording()` await 추가 + 실패 시 `isRecording` 리셋

### Medium 버그 수정
- **router.dart**: `extra` unsafe cast → `is String` 타입 체크로 변경
- **camera_screen**: lifecycle resumed `.then()` 내부 `mounted` 체크 추가
- **camera_screen**: `_checkOnboardingHints` Hive save를 `mounted` 체크 이전으로 이동

### 정적 분석 clean
- `flutter analyze`: 13개 이슈 → 0개 (unused import, curly braces, underscore naming 전부 수정)

---

## 세션 26 (2026-03-10) — 6개국 현지화 + 아이패드 제거

### 6개 언어 현지화 (flutter_localizations + ARB)
- **패키지 추가**: `intl: ^0.19.0`, `generate: true` in pubspec.yaml
- **l10n.yaml** 신규 생성: `arb-dir: lib/l10n`, `nullable-getter: false`
- **ARB 파일** 6종 생성: `app_en.arb` (57개 키, 템플릿) + `app_ko/ja/zh/fr/hi.arb`
  - 지원 키: UI 레이블, 카메라/에디터/필터/설정/온보딩 전체 문자열
  - Parameterized: `timerSeconds` (`{seconds}` int 플레이스홀더)
- **`lib/app.dart`**: `localizationsDelegates` + `supportedLocales` 추가
- **시스템 언어 자동 감지**: 한국어·영어·일본어·중국어·프랑스어·힌디어 지원
- 적용 화면: `camera_screen`, `editor_screen`, `filter_library_screen`, `onboarding_screen`, `settings_screen`

### Pro/페이월 관련 내용 전체 삭제
- ARB 파일에서 Pro 키 제거 (`likeItPro`, `proFeature1-5`, `proPurchaseNote`, `buyNow`, `restorePurchase`)
- `paywall_screen.dart`: l10n 참조 → 하드코딩 영어 문자열로 교체

### 아이패드 제거
- `ios/Runner.xcodeproj/project.pbxproj`: `TARGETED_DEVICE_FAMILY = "1,2"` → `"1"` (3곳)

### 앱스토어 메타데이터 업데이트
- `store_assets/app_store_metadata.md`: 6개 언어 앱 설명·부제목·키워드 전체 작성

### 에디터 효과/자르기 이름 현지화 (버그 수정)
- `_params` 레코드에서 `label` 필드 제거 → `_paramLabel(i, l10n)` 메서드로 현지화
  (솜결→Softness/なめらか/柔嫩/Douceur/सॉफ्टनेस 등 6개 언어)
- `_aspectOptions` → `_aspectRatios` + `_aspectLabels(l10n)` 분리
  (자유형→Free/フリー/自由/Libre/फ्री, 정방형→Square/正方形 등)

### 갤러리 화면 전체 현지화 (버그 수정)
- `gallery_picker_screen.dart`: 한국어 하드코딩 전체 제거 → `AppLocalizations` 적용
- ARB 6종에 신규 키 11개 추가:
  `selectedCount`, `select`, `album`, `selectFilter`,
  `galleryPermissionRequired`, `allowInSettings`, `noPhotos`,
  `deleteCountTitle`, `deleteSelectedConfirm`, `deletedCount`,
  `batchSavedCount`, `processingProgress`


---

## 세션 27 변경사항 (2026-03-11) — App Store 제출

### GitHub Pages 생성
- 레포지토리: `https://github.com/moonkj/likeit-support` (공개)
- 지원 페이지: `https://moonkj.github.io/likeit-support/support.html`
- 개인정보처리방침: `https://moonkj.github.io/likeit-support/privacy_policy.html`
- 문의 이메일: `imurmkj@gmail.com`
- 6개 언어 탭 전환 지원 (한/영/일/중/불/힌)

### App Store Connect 메타데이터 (6개 언어)
- 앱 이름: 라이크잇! - 감성 필터 카메라 / Like it! - Aesthetic Filter Camera 등
- 프로모션 텍스트, 설명, 키워드 6개 언어 완성
- 저작권: © 2026 Kyeongju Moon

### 스크린샷 변환
- 원본 PNG (1260×2736, 알파채널 있음) → JPG (1320×2868, 알파채널 없음)
- 변환 경로: `/Downloads/screenshots_fixed/` (24장: en/ja/zh/fr/hi/store 각 4장)

### IPA 빌드 업로드
- 도구: `xcrun altool --upload-app`
- 파일: `build/archive/export/Like it!.ipa` (41MB)
- Delivery UUID: `b5f41d63-6d83-4e1c-b72a-80b744f314ac`
- 전송 속도: 1.3MB/s, 33초 소요
- 상태: UPLOAD SUCCEEDED → App Store Connect 처리 중
