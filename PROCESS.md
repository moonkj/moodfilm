# MoodFilm 개발 진행 현황
> 마지막 업데이트: 2026-03-07 (세션 6)

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

### ⏳ W4 — 필터 20종 완성
- [x] 나머지 12종 LUT .cube 파일 제작 (tools/generate_luts.py로 전체 20종 생성)
- [x] 셀카 피부톤 최적화 → tools/generate_luts.py 파라미터로 반영
- [ ] 썸네일 20개 추가 (실기기 필요)

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

### ✅ W7 — UI/UX 완성 (부분 완료)
- [x] `withOpacity()` → `withValues(alpha:)` 전체 교체 (Flutter 3.x 코딩 규칙)
- [x] VoiceOver Semantics 레이블 (셔터, 설정, 카메라 전환, 필터 아이템)
- [ ] Liquid Glass 전체 적용 확인
- [ ] 모션 디자인 스펙 전체 구현 (계획서 6-7 기준)
- [ ] Reduce Motion 대응

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

## Phase 4: QA & Launch (W10-12) — 예정

### ⏳ W10 — 성능 테스트
- [ ] 기기별 테스트 (iPhone 12 / 14 / 15 Pro / 16)
- [ ] Instruments 메모리/GPU 프로파일링

### ⏳ W11 — App Store 준비
- [ ] 스크린샷 5장
- [ ] 프리뷰 영상 30초
- [ ] ASO 최적화

### ⏳ W12 — 소프트 런칭
- [ ] TestFlight 베타 50명
- [ ] App Store 제출

---

## 런칭 후 로드맵

| 버전 | 시점 | 주요 내용 |
|------|------|-----------|
| v1.1 | 런칭+1개월 | 동영상 필터 녹화 (W6b), Spring Blossom Pack, Dynamic Island 카운트다운 |
| v1.2 | 런칭+2개월 | 오늘의 필터 위젯 (WidgetKit), ColorGrid 피드 미리보기 |
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
| 2026-03-06 | iOS 최소 버전 | 17.0 (Liquid Glass는 iOS 26 조건부 적용) |
| 2026-03-06 | Firebase 초기화 | main.dart에서 주석 처리. GoogleService-Info.plist 추가 후 활성화 필요 |
| 2026-03-06 | 수익 모델 | 구독(월간/연간) 제거 → 1회 구매 ₩29,900 (`lifetime`)으로 단순화 |
| 2026-03-07 | 수익 모델 재확정 | IAP 완전 제거 → App Store 유료 앱으로 전환. 모든 필터 무제한 제공 |
| 2026-03-07 | EditorScreen | 열릴 때/슬라이더 변경 시 자동 필터 프리뷰 생성 (이전: Long press만 가능) |

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

## 다음 세션에서 할 일

1. **카메라 화면 비율 선택** — 세로: Full/9:16/3:4, 가로: 1:1/4:3/16:9 모드 추가 + 회전 버튼 제거
2. **필터 썸네일 20개** — 실기기에서 필터 적용 후 스크린샷으로 `assets/thumbnails/<id>.jpg` 생성
3. **App Store Connect 유료 앱 설정** — 앱 가격 설정 (₩4,900 ~ ₩9,900 tier 결정)
4. **W7 Liquid Glass + 모션** — 전체 화면 Liquid Glass 적용 확인, 모션 디자인 완성
5. **W10 성능 테스트** — 실기기 Instruments 프로파일링
