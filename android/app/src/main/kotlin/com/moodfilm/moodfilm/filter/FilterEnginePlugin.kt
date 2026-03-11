package com.moodfilm.moodfilm.filter

import android.content.ContentValues
import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Matrix
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import android.util.Log
import androidx.exifinterface.media.ExifInterface
import com.moodfilm.moodfilm.camera.MFGLRenderer
import com.moodfilm.moodfilm.camera.MFLUTEngine
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.io.File
import java.io.FileOutputStream

/**
 * 갤러리 이미지 정적 처리용 Filter Engine
 * iOS FilterEnginePlugin.swift 대응
 * Channel: com.moodfilm/filter_engine
 *
 * - 갤러리에서 선택한 사진에 LUT 필터 적용 후 저장
 * - 에디터 화면 배치 필터 처리
 */
class FilterEnginePlugin : FlutterPlugin, MethodChannel.MethodCallHandler {

    private lateinit var channel: MethodChannel
    private lateinit var binding: FlutterPlugin.FlutterPluginBinding

    companion object {
        private const val TAG = "FilterEnginePlugin"
        private const val CHANNEL = "com.moodfilm/filter_engine"
    }

    override fun onAttachedToEngine(flutterBinding: FlutterPlugin.FlutterPluginBinding) {
        binding = flutterBinding
        channel = MethodChannel(flutterBinding.binaryMessenger, CHANNEL)
        channel.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "processImage"      -> handleProcessImage(call, result)
            "generateThumbnail" -> handleGenerateThumbnail(call, result)
            else                -> result.notImplemented()
        }
    }

    // ─── 이미지 처리 ─────────────────────────────────────────────────────────

    /**
     * iOS FilterEnginePlugin processImage 대응
     * [imagePath]: 원본 이미지 파일 경로
     * [lutFile]: .cube 파일명 (빈 문자열 = 필터 없음)
     * [intensity]: 0.0 ~ 1.0
     * [saveToGallery]: 갤러리 저장 여부
     * Returns: 처리된 임시 파일 경로
     */
    private fun handleProcessImage(call: MethodCall, result: MethodChannel.Result) {
        // Dart FilterEngine.processImage 가 'sourcePath' 키로 전달 (imagePath 아님)
        val imagePath = call.argument<String>("sourcePath") ?: run {
            result.error("INVALID_ARGS", "sourcePath 필요", null)
            return
        }
        val lutFile = call.argument<String>("lutFile") ?: ""
        val intensity = (call.argument<Double>("intensity") ?: 1.0).toFloat()
        val saveToGallery = call.argument<Boolean>("saveToGallery") ?: false

        // Dart가 adjustments 맵으로 전달 {'brightness': 0.3, 'contrast': -0.2, ...}
        @Suppress("UNCHECKED_CAST")
        val adjustments = call.argument<Map<String, Any>>("adjustments") ?: emptyMap()
        val brightness = (adjustments["brightness"] as? Double ?: 0.0).toFloat()
        val contrast = (adjustments["contrast"] as? Double ?: 0.0).toFloat()
        val saturation = (adjustments["saturation"] as? Double ?: 0.0).toFloat()

        CoroutineScope(Dispatchers.IO).launch {
            val outputPath = processImage(
                context = binding.applicationContext,
                imagePath = imagePath,
                lutFile = lutFile,
                intensity = intensity,
                brightness = brightness,
                contrast = contrast,
                saturation = saturation,
                saveToGallery = saveToGallery
            )
            withContext(Dispatchers.Main) {
                if (outputPath != null) result.success(outputPath)
                else result.error("PROCESS_FAILED", "이미지 처리 실패", null)
            }
        }
    }

    /**
     * 에디터 썸네일 생성 (200×200 저해상도 처리)
     */
    private fun handleGenerateThumbnail(call: MethodCall, result: MethodChannel.Result) {
        // Dart FilterEngine.generateThumbnail 가 'sourcePath' 키로 전달
        val imagePath = call.argument<String>("sourcePath") ?: run {
            result.error("INVALID_ARGS", "sourcePath 필요", null)
            return
        }
        val lutFile = call.argument<String>("lutFile") ?: ""
        val intensity = (call.argument<Double>("intensity") ?: 1.0).toFloat()

        CoroutineScope(Dispatchers.IO).launch {
            val outputPath = generateThumbnail(
                context = binding.applicationContext,
                imagePath = imagePath,
                lutFile = lutFile,
                intensity = intensity
            )
            withContext(Dispatchers.Main) {
                if (outputPath != null) result.success(outputPath)
                else result.error("THUMBNAIL_FAILED", "썸네일 생성 실패", null)
            }
        }
    }

    // ─── 처리 로직 ───────────────────────────────────────────────────────────

    private fun processImage(
        context: Context,
        imagePath: String,
        lutFile: String,
        intensity: Float,
        brightness: Float,
        contrast: Float,
        saturation: Float,
        saveToGallery: Boolean
    ): String? {
        return try {
            var bitmap = BitmapFactory.decodeFile(imagePath) ?: return null

            // EXIF 방향 보정
            bitmap = correctOrientation(bitmap, imagePath)

            // LUT 적용 (MFLUTEngine CPU 경로)
            if (lutFile.isNotEmpty()) {
                // 임시 렌더러 없이 직접 LUT 로드 + 적용
                val engine = createTempEngine(context, lutFile, intensity, brightness, contrast, saturation)
                bitmap = engine.applyToBitmap(bitmap)
            } else if (brightness != 0f || contrast != 0f || saturation != 0f) {
                val engine = createTempEngine(context, "", 0f, brightness, contrast, saturation)
                bitmap = engine.applyToBitmap(bitmap)
            }

            // 파일 저장
            val outFile = File(context.cacheDir, "likeit_edit_${System.currentTimeMillis()}.jpg")
            FileOutputStream(outFile).use { bitmap.compress(Bitmap.CompressFormat.JPEG, 95, it) }
            bitmap.recycle()

            // 갤러리 저장 (saveToGallery: true 시)
            if (saveToGallery) {
                saveImageToGallery(context, outFile)
            }

            outFile.absolutePath
        } catch (e: Exception) {
            Log.e(TAG, "processImage 실패: ${e.message}")
            null
        }
    }

    private fun generateThumbnail(
        context: Context,
        imagePath: String,
        lutFile: String,
        intensity: Float
    ): String? {
        return try {
            // 저해상도로 디코드 (썸네일 최적화)
            val options = BitmapFactory.Options().apply {
                inSampleSize = 4  // 1/4 크기로 빠르게 디코드
            }
            var bitmap = BitmapFactory.decodeFile(imagePath, options) ?: return null
            bitmap = correctOrientation(bitmap, imagePath)

            if (lutFile.isNotEmpty()) {
                val engine = createTempEngine(context, lutFile, intensity, 0f, 0f, 0f)
                bitmap = engine.applyToBitmap(bitmap)
            }

            val outFile = File(context.cacheDir, "likeit_thumb_${System.currentTimeMillis()}.jpg")
            FileOutputStream(outFile).use { bitmap.compress(Bitmap.CompressFormat.JPEG, 85, it) }
            bitmap.recycle()

            outFile.absolutePath
        } catch (e: Exception) {
            Log.e(TAG, "generateThumbnail 실패: ${e.message}")
            null
        }
    }

    /**
     * 렌더러 없이 CPU LUT 전용 엔진 생성
     * (FilterEnginePlugin은 GL 컨텍스트 없이 CPU 경로만 사용)
     */
    private fun createTempEngine(
        context: Context,
        lutFile: String,
        intensity: Float,
        brightness: Float,
        contrast: Float,
        saturation: Float
    ): MFLUTEngine {
        // MFGLRenderer는 실제 렌더링에만 사용, CPU 경로는 renderer=null 시뮬레이션
        // 단순화: CpuOnlyLUTEngine 사용 (MFLUTEngine에서 GL 부분만 분리한 버전)
        return CpuOnlyLUTEngine(context, lutFile, intensity, brightness, contrast, saturation)
    }

    private fun correctOrientation(bitmap: Bitmap, filePath: String): Bitmap {
        return try {
            val exif = ExifInterface(filePath)
            val orientation = exif.getAttributeInt(
                ExifInterface.TAG_ORIENTATION, ExifInterface.ORIENTATION_NORMAL
            )
            val matrix = Matrix()
            when (orientation) {
                ExifInterface.ORIENTATION_ROTATE_90  -> matrix.postRotate(90f)
                ExifInterface.ORIENTATION_ROTATE_180 -> matrix.postRotate(180f)
                ExifInterface.ORIENTATION_ROTATE_270 -> matrix.postRotate(270f)
                else -> return bitmap
            }
            val result = Bitmap.createBitmap(bitmap, 0, 0, bitmap.width, bitmap.height, matrix, true)
            bitmap.recycle()
            result
        } catch (e: Exception) { bitmap }
    }

    private fun saveImageToGallery(context: Context, file: File) {
        val fileName = "likeit_${System.currentTimeMillis()}.jpg"
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val values = ContentValues().apply {
                put(MediaStore.Images.Media.DISPLAY_NAME, fileName)
                put(MediaStore.Images.Media.MIME_TYPE, "image/jpeg")
                put(MediaStore.Images.Media.RELATIVE_PATH, "${Environment.DIRECTORY_DCIM}/Likeit")
                put(MediaStore.Images.Media.IS_PENDING, 1)
            }
            val uri = context.contentResolver.insert(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, values) ?: return
            context.contentResolver.openOutputStream(uri)?.use { file.inputStream().copyTo(it) }
            values.clear(); values.put(MediaStore.Images.Media.IS_PENDING, 0)
            context.contentResolver.update(uri, values, null, null)
        }
    }
}

/**
 * GL 렌더러 없이 CPU만 사용하는 LUT 엔진 (FilterEnginePlugin 전용)
 * MFLUTEngine에서 GL 의존성 제거 버전
 */
private class CpuOnlyLUTEngine(
    private val context: Context,
    private val lutFile: String,
    private val intensity: Float,
    private val brightness: Float,
    private val contrast: Float,
    private val saturation: Float
) {
    private var lutData: FloatArray? = null
    private var lutSize: Int = 0

    init {
        if (lutFile.isNotEmpty()) loadLUT(lutFile)
    }

    private fun loadLUT(fileName: String) {
        try {
            val assetPath = "flutter_assets/assets/luts/$fileName"
            val content = context.assets.open(assetPath).bufferedReader().readText()
            parseCubeFile(content)?.let { (data, size) ->
                lutData = data; lutSize = size
            }
        } catch (e: Exception) {
            Log.e("CpuOnlyLUTEngine", "LUT 로드 실패: ${e.message}")
        }
    }

    private fun parseCubeFile(content: String): Pair<FloatArray, Int>? {
        var size = 0
        val values = mutableListOf<Float>()
        for (line in content.lines()) {
            val t = line.trim()
            if (t.startsWith("#") || t.isEmpty()) continue
            if (t.startsWith("LUT_3D_SIZE")) { size = t.split(" ").lastOrNull()?.toIntOrNull() ?: 0; continue }
            val parts = t.split("\\s+".toRegex()).mapNotNull { it.toFloatOrNull() }
            if (parts.size >= 3) { values.add(parts[0]); values.add(parts[1]); values.add(parts[2]) }
        }
        return if (size > 0 && values.size == size * size * size * 3) Pair(values.toFloatArray(), size) else null
    }

    fun applyToBitmap(src: Bitmap): Bitmap {
        val w = src.width; val h = src.height
        val result = src.copy(Bitmap.Config.ARGB_8888, true)
        val pixels = IntArray(w * h)
        result.getPixels(pixels, 0, w, 0, 0, w, h)
        val lut = lutData; val s = lutSize; val hasLut = lut != null && intensity > 0f

        for (i in pixels.indices) {
            val p = pixels[i]
            var r = android.graphics.Color.red(p) / 255f
            var g = android.graphics.Color.green(p) / 255f
            var b = android.graphics.Color.blue(p) / 255f
            val a = android.graphics.Color.alpha(p)

            if (hasLut && lut != null) {
                val lutRgb = trilinear(lut, s, r, g, b)
                r = lerp(r, lutRgb[0], intensity); g = lerp(g, lutRgb[1], intensity); b = lerp(b, lutRgb[2], intensity)
            }
            r += brightness * 0.5f; g += brightness * 0.5f; b += brightness * 0.5f
            if (contrast != 0f) { r = (r - 0.5f) * (1f + contrast) + 0.5f; g = (g - 0.5f) * (1f + contrast) + 0.5f; b = (b - 0.5f) * (1f + contrast) + 0.5f }
            if (saturation != 0f) { val gray = r * 0.299f + g * 0.587f + b * 0.114f; val s2 = 1f + saturation; r = lerp(gray, r, s2); g = lerp(gray, g, s2); b = lerp(gray, b, s2) }

            pixels[i] = android.graphics.Color.argb(a, (r.coerceIn(0f, 1f) * 255).toInt(), (g.coerceIn(0f, 1f) * 255).toInt(), (b.coerceIn(0f, 1f) * 255).toInt())
        }
        result.setPixels(pixels, 0, w, 0, 0, w, h)
        return result
    }

    private fun trilinear(lut: FloatArray, size: Int, r: Float, g: Float, b: Float): FloatArray {
        val s = size - 1
        val ri = (r * s).coerceIn(0f, s.toFloat()); val gi = (g * s).coerceIn(0f, s.toFloat()); val bi = (b * s).coerceIn(0f, s.toFloat())
        val r0 = ri.toInt().coerceAtMost(s - 1); val g0 = gi.toInt().coerceAtMost(s - 1); val b0 = bi.toInt().coerceAtMost(s - 1)
        val rf = ri - r0; val gf = gi - g0; val bf = bi - b0
        fun sample(ri: Int, gi: Int, bi: Int): FloatArray { val i = (bi * size * size + gi * size + ri) * 3; return floatArrayOf(lut[i], lut[i + 1], lut[i + 2]) }
        val c000 = sample(r0, g0, b0); val c100 = sample(r0 + 1, g0, b0); val c010 = sample(r0, g0 + 1, b0); val c110 = sample(r0 + 1, g0 + 1, b0)
        val c001 = sample(r0, g0, b0 + 1); val c101 = sample(r0 + 1, g0, b0 + 1); val c011 = sample(r0, g0 + 1, b0 + 1); val c111 = sample(r0 + 1, g0 + 1, b0 + 1)
        return FloatArray(3) { ch ->
            lerp(lerp(lerp(c000[ch], c100[ch], rf), lerp(c010[ch], c110[ch], rf), gf),
                 lerp(lerp(c001[ch], c101[ch], rf), lerp(c011[ch], c111[ch], rf), gf), bf)
        }
    }
    private fun lerp(a: Float, b: Float, t: Float) = a + (b - a) * t
}
