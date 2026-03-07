# MoodFilm Project Memory

## 프로젝트 개요
- 앱 이름: MoodFilm — 감성 필터 카메라 앱
- 비전: "한 번의 탭으로, 내 사진이 예뻐지는 경험"
- 타겟: 15-25세 여성, 인스타그램/틱톡, 셀카 중심, 한국 감성
- 1인 개발 프로젝트

## 기술 스택
- Flutter 3.27+ + Riverpod 3.0 + go_router
- iOS Native Plugin: AVFoundation + CIFilter/Metal + MTKView
- LUT 기반 필터 (.cube 포맷, CIColorCube)
- RevenueCat (IAP), Firebase (Analytics + Crashlytics), Hive (로컬 저장)

## 아키텍처
- Flutter + Native Plugin 하이브리드 (기존 코드베이스 Riverpod 활용)
- Feature-first 폴더 구조
- Method Channel: com.moodfilm/camera_engine, com.moodfilm/filter_engine

## 핵심 파일
- /Users/kjmoon/MoodFilm/IMPLEMENTATION_PLAN.md — 상세 구현 계획서

## 계획서 원본
- /Users/kjmoon/Downloads/MoodFilm_v2_개발계획서.pdf (20페이지)

## 필터 시스템
- MVP 20종 (Warm 5 / Cool 5 / Film 5 / Aesthetic 5)
- 무료 8종 번들, 나머지 12종 Pro 다운로드
- 시그니처: Dreamy Glow (CIBloom + Gaussian Blur)

## 수익 모델
- Free: 기본 8필터 + 2이펙트
- Pro 월간: ₩2,900 / 연간: ₩14,900 / Lifetime: ₩29,900

## 12주 스프린트 구조
- W1-3: Foundation (프로젝트 셋업, 카메라 엔진, LUT 엔진)
- W4-6: Core Features (필터 20종, 편집 화면, 이펙트)
- W7-9: Polish & Business (UI 완성, 라이브러리, IAP)
- W10-12: QA & Launch

## 추가 아이디어 (구현 계획서에 반영)
1. Mood Match — on-device CoreML 필터 추천 (v1.3)
2. 오늘의 필터 위젯 — WidgetKit (v1.2)
3. ColorGrid 피드 미리보기 (v1.2)
4. 필터 강도 기억 — Hive 저장 (MVP)
5. Split-View Before/After 비교 (MVP)
6. Dynamic Island 카운트다운 (v1.1)
