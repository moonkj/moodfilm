#!/usr/bin/env python3
"""
MoodFilm LUT Generator
각 필터에 맞는 17×17×17 3D LUT .cube 파일 생성
"""

import os
import math

OUTPUT_DIR = os.path.join(os.path.dirname(__file__), '..', 'assets', 'luts')
LUT_SIZE = 17  # 17×17×17 (17³ = 4913 entries)


def clamp(v, lo=0.0, hi=1.0):
    return max(lo, min(hi, v))


def apply_gamma(v, gamma):
    """Gamma correction (gamma < 1 = brighter midtones)"""
    if v <= 0:
        return 0.0
    return v ** gamma


def apply_saturation(r, g, b, sat):
    """채도 조정 (1.0 = 원본, 0.0 = 흑백)"""
    luma = 0.2126 * r + 0.7152 * g + 0.0722 * b
    return (
        luma + (r - luma) * sat,
        luma + (g - luma) * sat,
        luma + (b - luma) * sat,
    )


def apply_curves(v, shadows, midtones, highlights):
    """Shadow/Midtone/Highlight 분리 색조 적용"""
    # 각 구간에 가중치 적용
    shadow_w = max(0.0, 1.0 - v * 3.0)
    highlight_w = max(0.0, v * 3.0 - 2.0)
    mid_w = 1.0 - shadow_w - highlight_w
    return v + shadows * shadow_w + midtones * mid_w + highlights * highlight_w


def process(r, g, b, params):
    """필터 파라미터로 RGB 변환"""
    temp = params.get('temp', 0.0)       # 색온도: + = 따뜻, - = 차갑
    tint = params.get('tint', 0.0)       # 틴트: + = 마젠타, - = 그린
    sat = params.get('sat', 1.0)         # 채도
    fade = params.get('fade', 0.0)       # 페이드 (shadows lift)
    contrast = params.get('contrast', 1.0)
    gamma = params.get('gamma', 1.0)     # gamma < 1 = brighter
    gain = params.get('gain', 1.0)       # 전체 밝기
    lift = params.get('lift', 0.0)       # 그림자 레벨

    # Shadow tint (하이라이트 - 그림자 분리)
    shadow_r = params.get('shadow_r', 0.0)
    shadow_g = params.get('shadow_g', 0.0)
    shadow_b = params.get('shadow_b', 0.0)
    highlight_r = params.get('highlight_r', 0.0)
    highlight_g = params.get('highlight_g', 0.0)
    highlight_b = params.get('highlight_b', 0.0)

    # 1. 색온도 (R/B 조정)
    r += temp
    b -= temp

    # 2. 틴트 (G vs R+B)
    r += tint * 0.3
    g -= tint * 0.7
    b += tint * 0.3

    # 3. Shadow/Highlight 분리 틴트
    luma = 0.2126 * clamp(r) + 0.7152 * clamp(g) + 0.0722 * clamp(b)
    shadow_w = max(0.0, (1.0 - luma * 2.5))
    highlight_w = max(0.0, (luma * 2.5 - 1.5))
    r += shadow_r * shadow_w + highlight_r * highlight_w
    g += shadow_g * shadow_w + highlight_g * highlight_w
    b += shadow_b * shadow_w + highlight_b * highlight_w

    # 4. Gamma
    r, g, b = (
        apply_gamma(clamp(r), gamma),
        apply_gamma(clamp(g), gamma),
        apply_gamma(clamp(b), gamma),
    )

    # 5. Lift (shadows up)
    r = r + lift * (1.0 - r)
    g = g + lift * (1.0 - g)
    b = b + lift * (1.0 - b)

    # 6. Fade (linear lift)
    r = r * (1.0 - fade) + fade * 0.5
    g = g * (1.0 - fade) + fade * 0.5
    b = b * (1.0 - fade) + fade * 0.5

    # 7. Contrast (중앙 0.5 기준)
    r = (r - 0.5) * contrast + 0.5
    g = (g - 0.5) * contrast + 0.5
    b = (b - 0.5) * contrast + 0.5

    # 8. Gain
    r, g, b = r * gain, g * gain, b * gain

    # 9. Saturation
    r, g, b = apply_saturation(clamp(r), clamp(g), clamp(b), sat)

    return clamp(r), clamp(g), clamp(b)


# ── 필터 파라미터 정의 ──────────────────────────────────────────────────────

FILTERS = {
    # Warm Tone
    'milk': {
        'temp': 0.06, 'tint': 0.01,
        'sat': 0.88, 'fade': 0.07, 'contrast': 0.93, 'gamma': 0.96,
        'lift': 0.04, 'gain': 1.0,
        'shadow_r': 0.02, 'shadow_b': -0.01,
        'highlight_r': 0.01,
    },
    'cream': {
        'temp': 0.10, 'tint': 0.02,
        'sat': 0.85, 'fade': 0.05, 'contrast': 0.92, 'gamma': 0.94,
        'lift': 0.03, 'gain': 1.03,
        'shadow_r': 0.03, 'shadow_g': 0.01,
        'highlight_r': 0.02, 'highlight_g': 0.01,
    },
    'butter': {
        'temp': 0.16, 'tint': 0.04,
        'sat': 0.92, 'fade': 0.04, 'contrast': 1.03, 'gamma': 0.90,
        'lift': 0.02, 'gain': 1.06,
        'shadow_r': 0.04, 'shadow_g': 0.02, 'shadow_b': -0.02,
        'highlight_r': 0.03, 'highlight_g': 0.01,
    },
    'honey': {
        'temp': 0.22, 'tint': -0.02,
        'sat': 1.12, 'fade': 0.02, 'contrast': 1.08, 'gamma': 0.88,
        'lift': 0.01, 'gain': 1.08,
        'shadow_r': 0.05, 'shadow_g': 0.02, 'shadow_b': -0.04,
        'highlight_r': 0.04, 'highlight_b': -0.02,
    },
    'peach': {
        'temp': 0.12, 'tint': 0.07,
        'sat': 1.02, 'fade': 0.06, 'contrast': 0.97, 'gamma': 0.93,
        'lift': 0.04, 'gain': 1.03,
        'shadow_r': 0.04, 'shadow_g': 0.01, 'shadow_b': -0.01,
        'highlight_r': 0.03, 'highlight_b': 0.01,
    },

    # Cool Tone
    'sky': {
        'temp': -0.09, 'tint': -0.04,
        'sat': 0.90, 'fade': 0.04, 'contrast': 0.95, 'gamma': 0.97,
        'lift': 0.02, 'gain': 1.01,
        'shadow_b': 0.03, 'shadow_r': -0.01,
        'highlight_b': 0.02,
    },
    'ocean': {
        'temp': -0.18, 'tint': -0.07,
        'sat': 1.08, 'fade': 0.01, 'contrast': 1.08, 'gamma': 0.93,
        'lift': 0.0, 'gain': 1.04,
        'shadow_b': 0.06, 'shadow_r': -0.03,
        'highlight_b': 0.04, 'highlight_r': -0.02,
    },
    'mint': {
        'temp': -0.06, 'tint': -0.09,
        'sat': 0.87, 'fade': 0.05, 'contrast': 0.94, 'gamma': 1.01,
        'lift': 0.03, 'gain': 1.0,
        'shadow_g': 0.03, 'shadow_b': 0.02,
        'highlight_g': 0.02, 'highlight_b': 0.01,
    },
    'cloud': {
        'temp': -0.04, 'tint': 0.0,
        'sat': 0.72, 'fade': 0.10, 'contrast': 0.88, 'gamma': 1.05,
        'lift': 0.06, 'gain': 1.0,
        'shadow_b': 0.02,
        'highlight_b': 0.01,
    },
    'ice': {
        'temp': -0.13, 'tint': -0.04,
        'sat': 0.80, 'fade': 0.06, 'contrast': 0.91, 'gamma': 1.07,
        'lift': 0.04, 'gain': 1.02,
        'shadow_b': 0.04, 'shadow_r': -0.02,
        'highlight_b': 0.03, 'highlight_r': -0.01,
    },

    # Film
    'film98': {
        'temp': 0.04, 'tint': 0.02,
        'sat': 0.78, 'fade': 0.12, 'contrast': 0.88, 'gamma': 0.97,
        'lift': 0.05, 'gain': 0.95,
        'shadow_r': 0.03, 'shadow_b': -0.01,
        'highlight_r': 0.01, 'highlight_g': 0.01,
    },
    'film03': {
        'temp': 0.02, 'tint': 0.07,
        'sat': 1.03, 'fade': 0.07, 'contrast': 0.98, 'gamma': 0.95,
        'lift': 0.04, 'gain': 0.98,
        'shadow_r': 0.02, 'shadow_b': 0.02,
        'highlight_r': 0.02, 'highlight_b': -0.01,
    },
    'disposable': {
        'temp': 0.10, 'tint': 0.01,
        'sat': 1.08, 'fade': 0.08, 'contrast': 1.03, 'gamma': 0.93,
        'lift': 0.05, 'gain': 0.99,
        'shadow_r': 0.04, 'shadow_b': -0.02,
        'highlight_r': 0.02,
    },
    'retro_ccd': {
        'temp': -0.02, 'tint': -0.05,
        'sat': 1.18, 'fade': 0.04, 'contrast': 1.12, 'gamma': 0.90,
        'lift': 0.02, 'gain': 1.04,
        'shadow_g': 0.02, 'shadow_b': 0.01,
        'highlight_g': 0.01, 'highlight_b': -0.01,
    },
    'kodak_soft': {
        'temp': 0.08, 'tint': 0.01,
        'sat': 0.86, 'fade': 0.09, 'contrast': 0.91, 'gamma': 0.99,
        'lift': 0.05, 'gain': 0.99,
        'shadow_r': 0.03, 'shadow_g': 0.01,
        'highlight_r': 0.01,
    },

    # ── MoodFilm 시그니처 ──────────────────────────────────────────────────
    # "Mood" — 앱 대표 필터: 따뜻한 페이드 + 쿨 하이라이트 크로스 프로세스
    # 피부톤 살리면서 드리미한 필름 감성. 셀카/인물 최적.
    'mood': {
        'temp': 0.06, 'tint': 0.03,
        'sat': 0.80, 'fade': 0.13, 'contrast': 0.88, 'gamma': 0.94,
        'lift': 0.07, 'gain': 0.97,
        'shadow_r': 0.04, 'shadow_g': 0.01, 'shadow_b': -0.01,
        'highlight_b': 0.02, 'highlight_r': 0.01,
    },
    # "Dream" — 에디토리얼 시그니처: 보랏빛 안개 + 리프트된 그림자
    # 몽환적이고 부드러운 감성. 배경/풍경/OOTD 최적.
    'dream': {
        'temp': -0.02, 'tint': 0.06,
        'sat': 0.75, 'fade': 0.14, 'contrast': 0.86, 'gamma': 1.02,
        'lift': 0.08, 'gain': 0.96,
        'shadow_r': 0.02, 'shadow_b': 0.03, 'shadow_g': 0.01,
        'highlight_b': 0.03, 'highlight_r': 0.02,
    },

    # Aesthetic
    'soft_pink': {
        'temp': 0.04, 'tint': 0.11,
        'sat': 0.73, 'fade': 0.08, 'contrast': 0.87, 'gamma': 1.02,
        'lift': 0.05, 'gain': 1.0,
        'shadow_r': 0.04, 'shadow_b': 0.02,
        'highlight_r': 0.03, 'highlight_b': 0.01,
    },
    'lavender': {
        'temp': -0.04, 'tint': 0.09,
        'sat': 0.79, 'fade': 0.07, 'contrast': 0.90, 'gamma': 1.0,
        'lift': 0.04, 'gain': 1.0,
        'shadow_b': 0.04, 'shadow_r': 0.02,
        'highlight_b': 0.03, 'highlight_r': 0.01,
    },
    'dusty_blue': {
        'temp': -0.11, 'tint': 0.01,
        'sat': 0.77, 'fade': 0.09, 'contrast': 0.89, 'gamma': 1.0,
        'lift': 0.05, 'gain': 0.98,
        'shadow_b': 0.04, 'shadow_g': 0.01,
        'highlight_b': 0.03,
    },
    'cafe_mood': {
        'temp': 0.15, 'tint': 0.04,
        'sat': 0.83, 'fade': 0.07, 'contrast': 1.0, 'gamma': 0.91,
        'lift': 0.06, 'gain': 0.97,
        'shadow_r': 0.05, 'shadow_g': 0.02, 'shadow_b': -0.02,
        'highlight_r': 0.02, 'highlight_g': 0.01,
    },
    'seoul_night': {
        'temp': -0.07, 'tint': -0.03,
        'sat': 1.22, 'fade': 0.01, 'contrast': 1.18, 'gamma': 0.85,
        'lift': 0.0, 'gain': 1.08,
        'shadow_b': 0.05, 'shadow_r': -0.02,
        'highlight_r': 0.04, 'highlight_g': 0.01, 'highlight_b': -0.02,
    },
}


def generate_cube(name, params):
    """17×17×17 .cube 파일 생성"""
    size = LUT_SIZE
    lines = [
        f'# MoodFilm Filter — {name}',
        f'TITLE "{name}"',
        f'LUT_3D_SIZE {size}',
        '',
    ]

    for bi in range(size):
        for gi in range(size):
            for ri in range(size):
                r = ri / (size - 1)
                g = gi / (size - 1)
                b = bi / (size - 1)
                ro, go, bo = process(r, g, b, params)
                lines.append(f'{ro:.6f} {go:.6f} {bo:.6f}')

    return '\n'.join(lines)


if __name__ == '__main__':
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    for name, params in FILTERS.items():
        path = os.path.join(OUTPUT_DIR, f'{name}.cube')
        content = generate_cube(name, params)
        with open(path, 'w') as f:
            f.write(content)
        print(f'✓ {name}.cube')

    print(f'\n완료: {len(FILTERS)}개 LUT 파일 생성 → {OUTPUT_DIR}')
