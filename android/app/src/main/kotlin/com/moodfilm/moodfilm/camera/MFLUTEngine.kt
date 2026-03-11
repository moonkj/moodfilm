package com.moodfilm.moodfilm.camera

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Color
import android.util.LruCache
import java.io.BufferedReader
import java.io.InputStreamReader

/**
 * iOS MFLUTEngine 대응 Kotlin 클래스
 *
 * - Flutter 에셋 .cube 파일 파싱
 * - MFGLRenderer로 LUT 3D 텍스처 업로드
 * - 이펙트 강도 관리 (GL uniform 세팅)
 * - CPU 경로 LUT 적용 (사진 캡처 시 full-res 처리용)
 */
class MFLUTEngine(
    private val context: Context,
    private val renderer: MFGLRenderer
) {
    // 현재 LUT 정보
    private var currentLutFileName: String = ""
    private var currentLutData: FloatArray? = null
    private var currentLutSize: Int = 0

    // LUT 캐시 (최대 8개, iOS NSCache 대응)
    private val lutCache = LruCache<String, Pair<FloatArray, Int>>(8)

    // ─── 이펙트 상태 (iOS MFLUTEngine 프로퍼티 대응) ─────────────────────────
    var intensity: Float = 1.0f
        set(value) { field = value; renderer.lutIntensity = value }

    var glowIntensity: Float = 0.0f
        set(value) { field = value; renderer.glowIntensity = value }

    var grainIntensity: Float = 0.0f
        set(value) { field = value; renderer.grainIntensity = value }

    var beautyIntensity: Float = 0.0f
        set(value) { field = value; renderer.beautyIntensity = value }

    var lightLeakIntensity: Float = 0.0f
        set(value) { field = value; renderer.lightLeakIntensity = value }

    var softnessIntensity: Float = 0.0f
        set(value) { field = value; renderer.softnessIntensity = value }

    var brightnessIntensity: Float = 0.0f
        set(value) { field = value; renderer.brightness = value }

    var contrastIntensity: Float = 0.0f
        set(value) { field = value; renderer.contrast = value }

    var saturationIntensity: Float = 0.0f
        set(value) { field = value; renderer.saturation = value }

    var splitPosition: Float = -1.0f
        set(value) { field = value; renderer.splitPosition = value }

    var isFrontCamera: Boolean = true
        set(value) { field = value; renderer.isFrontCamera = value }

    val hasLUT: Boolean get() = currentLutData != null

    // ─── LUT 로딩 ─────────────────────────────────────────────────────────────

    /**
     * iOS MFLUTEngine.loadLUT(named:) 대응
     * Flutter 에셋 경로: flutter_assets/assets/luts/<name>.cube
     */
    fun loadLUT(lutFileName: String) {
        if (lutFileName.isEmpty()) {
            clearLUT()
            return
        }
        if (lutFileName == currentLutFileName && hasLUT) return

        // 캐시 확인
        lutCache.get(lutFileName)?.let { (data, size) ->
            currentLutFileName = lutFileName
            currentLutData = data
            currentLutSize = size
            renderer.hasLUT = true
            renderer.uploadLUT(data, size)
            return
        }

        // Flutter 에셋 로드 (ios: App.framework/flutter_assets/ 대응)
        val assetPath = "flutter_assets/assets/luts/$lutFileName"
        try {
            val stream = context.assets.open(assetPath)
            val content = BufferedReader(InputStreamReader(stream)).readText()
            stream.close()

            val parsed = parseCubeFile(content) ?: run {
                android.util.Log.e("MFLUTEngine", "LUT 파싱 실패: $lutFileName")
                return
            }
            val (data, size) = parsed

            lutCache.put(lutFileName, Pair(data, size))
            currentLutFileName = lutFileName
            currentLutData = data
            currentLutSize = size
            renderer.hasLUT = true
            renderer.uploadLUT(data, size)
        } catch (e: Exception) {
            android.util.Log.e("MFLUTEngine", "LUT 파일 열기 실패: $lutFileName — ${e.message}")
        }
    }

    fun clearLUT() {
        currentLutFileName = ""
        currentLutData = null
        currentLutSize = 0
        renderer.clearLUT()
    }

    // ─── .cube 파일 파싱 (iOS buildLUTFilter(from:) 1:1 대응) ─────────────────

    /**
     * 파싱 결과: Pair(cubeData: FloatArray[size*size*size*3], size: Int)
     * iOS: cubeData는 RGBA 4채널이었으나 Android OpenGL은 RGB 3채널 사용
     */
    private fun parseCubeFile(content: String): Pair<FloatArray, Int>? {
        var size = 0
        val values = mutableListOf<Float>()

        for (line in content.lines()) {
            val trimmed = line.trim()
            if (trimmed.startsWith("#") || trimmed.isEmpty()) continue

            if (trimmed.startsWith("LUT_3D_SIZE")) {
                size = trimmed.split(" ").lastOrNull()?.toIntOrNull() ?: 0
                continue
            }

            // 숫자 행 파싱 (R G B)
            val parts = trimmed.split("\\s+".toRegex()).mapNotNull { it.toFloatOrNull() }
            if (parts.size >= 3) {
                values.add(parts[0]) // R
                values.add(parts[1]) // G
                values.add(parts[2]) // B
            }
        }

        if (size <= 0 || values.size != size * size * size * 3) return null
        return Pair(values.toFloatArray(), size)
    }

    // ─── CPU LUT 적용 (사진 캡처 full-res 처리) ─────────────────────────────

    /**
     * iOS photoOutput(_:didFinishProcessingPhoto:) 내 lutEngine.apply(to:) 대응
     * Bitmap 픽셀에 현재 LUT + 기본 색보정 적용
     * 참고: 느릴 수 있으므로 백그라운드 스레드에서 호출
     */
    fun applyToBitmap(src: Bitmap): Bitmap {
        val w = src.width
        val h = src.height
        val result = src.copy(Bitmap.Config.ARGB_8888, true)
        val pixels = IntArray(w * h)
        result.getPixels(pixels, 0, w, 0, 0, w, h)

        val lutData = currentLutData
        val lutSize = currentLutSize
        val hasLut = lutData != null && intensity > 0f

        for (i in pixels.indices) {
            val p = pixels[i]
            var r = Color.red(p) / 255f
            var g = Color.green(p) / 255f
            var b = Color.blue(p) / 255f
            val a = Color.alpha(p)

            // 1. LUT 적용 (trilinear 보간)
            if (hasLut && lutData != null) {
                val lutRGB = trilinearSample(lutData, lutSize, r, g, b)
                r = lerp(r, lutRGB[0], intensity)
                g = lerp(g, lutRGB[1], intensity)
                b = lerp(b, lutRGB[2], intensity)
            }

            // 2. Brightness (iOS: brightnessIntensity * 0.5)
            r += brightnessIntensity * 0.5f
            g += brightnessIntensity * 0.5f
            b += brightnessIntensity * 0.5f

            // 3. Contrast (iOS: (val - 0.5) * (1 + contrast) + 0.5)
            if (contrastIntensity != 0f) {
                r = (r - 0.5f) * (1f + contrastIntensity) + 0.5f
                g = (g - 0.5f) * (1f + contrastIntensity) + 0.5f
                b = (b - 0.5f) * (1f + contrastIntensity) + 0.5f
            }

            // 4. Saturation
            if (saturationIntensity != 0f) {
                val gray = r * 0.299f + g * 0.587f + b * 0.114f
                val s = 1f + saturationIntensity
                r = lerp(gray, r, s)
                g = lerp(gray, g, s)
                b = lerp(gray, b, s)
            }

            // 5. Beauty 뽀샤시
            if (beautyIntensity > 0f) {
                r = (r + beautyIntensity * 0.08f + beautyIntensity * 0.02f)
                g = g + beautyIntensity * 0.08f
                b = (b + beautyIntensity * 0.08f - beautyIntensity * 0.01f)
            }

            // 6. Light Leak은 CPU 처리가 복잡하므로 사진에서는 생략 (프리뷰에서만)

            pixels[i] = Color.argb(
                a,
                (r.coerceIn(0f, 1f) * 255).toInt(),
                (g.coerceIn(0f, 1f) * 255).toInt(),
                (b.coerceIn(0f, 1f) * 255).toInt()
            )
        }
        result.setPixels(pixels, 0, w, 0, 0, w, h)
        return result
    }

    /**
     * 33×33×33 LUT trilinear 보간
     * iOS CIColorCubeWithColorSpace + GPU trilinear 동일 결과
     */
    private fun trilinearSample(lut: FloatArray, size: Int, r: Float, g: Float, b: Float): FloatArray {
        val s = size - 1

        // 각 축의 정수/소수 인덱스
        val ri = (r * s).coerceIn(0f, s.toFloat())
        val gi = (g * s).coerceIn(0f, s.toFloat())
        val bi = (b * s).coerceIn(0f, s.toFloat())

        val r0 = ri.toInt().coerceAtMost(s - 1)
        val g0 = gi.toInt().coerceAtMost(s - 1)
        val b0 = bi.toInt().coerceAtMost(s - 1)
        val r1 = r0 + 1
        val g1 = g0 + 1
        val b1 = b0 + 1

        val rf = ri - r0
        val gf = gi - g0
        val bf = bi - b0

        fun idx(ri: Int, gi: Int, bi: Int) = (bi * size * size + gi * size + ri) * 3

        fun sample(ri: Int, gi: Int, bi: Int): FloatArray {
            val i = idx(ri, gi, bi)
            return floatArrayOf(lut[i], lut[i + 1], lut[i + 2])
        }

        // 8개 꼭짓점 보간
        val c000 = sample(r0, g0, b0); val c100 = sample(r1, g0, b0)
        val c010 = sample(r0, g1, b0); val c110 = sample(r1, g1, b0)
        val c001 = sample(r0, g0, b1); val c101 = sample(r1, g0, b1)
        val c011 = sample(r0, g1, b1); val c111 = sample(r1, g1, b1)

        val result = FloatArray(3)
        for (ch in 0..2) {
            val c00 = lerp(c000[ch], c100[ch], rf)
            val c01 = lerp(c001[ch], c101[ch], rf)
            val c10 = lerp(c010[ch], c110[ch], rf)
            val c11 = lerp(c011[ch], c111[ch], rf)
            val c0 = lerp(c00, c10, gf)
            val c1 = lerp(c01, c11, gf)
            result[ch] = lerp(c0, c1, bf)
        }
        return result
    }

    private fun lerp(a: Float, b: Float, t: Float) = a + (b - a) * t
}
