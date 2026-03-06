# MoodFilm 개발 진행 현황
> 마지막 업데이트: 2026-03-06 (세션 2)

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
- [ ] 나머지 12종 LUT .cube 파일 제작
- [ ] 셀카 피부톤 최적화 (red -5~-10%, highlight +10~20%)
- [ ] 썸네일 12개 추가

### ⏳ W5 — 편집 화면 완성
- [x] `FilterEnginePlugin.swift` Native 구현 (Full-res 처리 + 갤러리 저장)
- [x] EditorScreen 저장 버튼 실제 연결 (`FilterEngine.processImage()`)
- [x] 6종 슬라이더 CIFilter 연결 (Exposure, Contrast, Warmth, Saturation, Grain, Fade)
- [ ] 갤러리 Import (photo_manager 연동)
- [ ] Split-View Before/After 개선 (filtered image 실제 반영)

### ⏳ W6 — 이펙트 시스템
- [ ] Dreamy Glow 실시간 강도 조절
- [ ] Film Grain 연동
- [ ] Dust Texture (Pro, 오버레이 이미지)
- [ ] Light Leak (Pro, 그라디언트)
- [ ] Date Stamp (Pro, 날짜 텍스트)
- [ ] 이펙트 탭 UI 완성

---

## Phase 3: Polish & Business (W7-9) — 예정

### ⏳ W7 — UI/UX 완성
- [ ] Liquid Glass 전체 적용 확인
- [ ] 모션 디자인 스펙 전체 구현 (계획서 6-7 기준)
- [ ] Reduce Motion 대응
- [ ] VoiceOver 레이블 전체

### ⏳ W8 — 필터 라이브러리 완성
- [ ] 필터 적용 → 카메라 화면 연동 완성
- [ ] 즐겨찾기 실시간 반영

### ⏳ W9 — IAP + 온보딩
- [ ] RevenueCat 설정 (App Store Connect 상품 등록)
- [ ] Paywall 실제 결제 연동 (Sandbox 테스트)
- [ ] 구독 복원
- [ ] 온보딩 힌트 시퀀스 완성

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
| v1.1 | 런칭+1개월 | 동영상 촬영, Spring Blossom Pack, Dynamic Island 카운트다운 |
| v1.2 | 런칭+2개월 | 오늘의 필터 위젯 (WidgetKit), ColorGrid 피드 미리보기 |
| v1.3 | 런칭+3개월 | Mood Match AI 필터 추천 (on-device CoreML), Android 출시 |
| v2.0 | 런칭+6개월 | 커스텀 필터 생성, 커뮤니티 공유, Mood Journal |

---

## 알려진 이슈 / 결정 사항

| 날짜 | 항목 | 결정 |
|------|------|------|
| 2026-03-06 | riverpod_generator 제외 | hive_generator와 analyzer 버전 충돌. Provider 수동 작성으로 대체 |
| 2026-03-06 | build_runner 버전 | ^2.4.13 사용 (^2.4.14는 hive_generator와 충돌) |
| 2026-03-06 | iOS 최소 버전 | 17.0 (Liquid Glass는 iOS 26 조건부 적용) |
| 2026-03-06 | Firebase 초기화 | main.dart에서 주석 처리. GoogleService-Info.plist 추가 후 활성화 필요 |

---

## 다음 세션에서 할 일

1. Pretendard 폰트 파일 4개 `assets/fonts/`에 추가
2. LUT 썸네일 이미지 8개 `assets/thumbnails/`에 추가
3. CIColorCube 실시간 30fps 성능 측정 (실기기)
4. 갤러리 Import (photo_manager 연동) — W5
5. W4: 나머지 12종 LUT .cube 파일 제작
