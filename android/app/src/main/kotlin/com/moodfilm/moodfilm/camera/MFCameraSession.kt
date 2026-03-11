package com.moodfilm.moodfilm.camera

import android.content.ContentValues
import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Matrix
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import android.view.Surface
import androidx.camera.core.CameraSelector
import androidx.camera.core.FocusMeteringAction
import androidx.camera.core.ImageCapture
import androidx.camera.core.ImageCaptureException
import androidx.camera.core.Preview
import androidx.camera.core.SurfaceOrientedMeteringPointFactory
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.core.content.ContextCompat
import androidx.exifinterface.media.ExifInterface
import androidx.lifecycle.LifecycleOwner
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.io.File
import java.io.FileOutputStream

/**
 * CameraX 기반 카메라 세션
 * iOS MFCameraSession.swift 대응
 *
 * - CameraX Preview → MFGLRenderer 카메라 입력 Surface
 * - ImageCapture → LUT 후처리 → 갤러리 저장
 */
class MFCameraSession(
    private val context: Context,
    private val lifecycleOwner: LifecycleOwner,
    private val glRenderer: MFGLRenderer,
    val lutEngine: MFLUTEngine
) {
    private var cameraProvider: ProcessCameraProvider? = null
    private var imageCapture: ImageCapture? = null
    private var videoRecorder: MFVideoRecorder? = null

    private var isFront: Boolean = true
    private var cameraInputSurface: Surface? = null

    var currentAspectRatio: String = "full"
    var isRecording: Boolean = false

    // 콜백
    var onPhotoCaptured: ((String) -> Unit)? = null
    var onCaptureError: ((String) -> Unit)? = null

    // ─── 초기화 ────────────────────────────────────────────────────────────────

    /**
     * iOS session.setup(frontCamera:completion:) 대응
     * GL 렌더러가 준비한 카메라 입력 Surface를 CameraX에 연결
     */
    fun setup(frontCamera: Boolean, onReady: (Boolean) -> Unit) {
        isFront = frontCamera
        lutEngine.isFrontCamera = frontCamera

        // GL 렌더러가 카메라 입력 Surface 준비 완료 시 CameraX 바인딩
        glRenderer.start { surface ->
            cameraInputSurface = surface
            bindCameraX(frontCamera, onReady)
        }
    }

    private fun bindCameraX(frontCamera: Boolean, onResult: (Boolean) -> Unit) {
        val future = ProcessCameraProvider.getInstance(context)
        future.addListener({
            try {
                val provider = future.get()
                cameraProvider = provider
                bindUseCases(provider, frontCamera)
                onResult(true)
            } catch (e: Exception) {
                android.util.Log.e("MFCameraSession", "CameraX 초기화 실패: ${e.message}")
                onResult(false)
            }
        }, ContextCompat.getMainExecutor(context))
    }

    private fun bindUseCases(provider: ProcessCameraProvider, frontCamera: Boolean) {
        provider.unbindAll()

        val selector = if (frontCamera)
            CameraSelector.DEFAULT_FRONT_CAMERA
        else
            CameraSelector.DEFAULT_BACK_CAMERA

        // Preview → GL 렌더러의 카메라 입력 Surface 제공
        val preview = Preview.Builder()
            .setTargetResolution(android.util.Size(1920, 1080))
            .build()
            .also { p ->
                val surface = cameraInputSurface ?: return
                p.setSurfaceProvider { request ->
                    request.provideSurface(surface, ContextCompat.getMainExecutor(context)) {}
                }
            }

        // 사진 캡처 (iOS photoOutput 대응)
        imageCapture = ImageCapture.Builder()
            .setCaptureMode(ImageCapture.CAPTURE_MODE_MAXIMIZE_QUALITY)
            .build()

        try {
            val camera = provider.bindToLifecycle(
                lifecycleOwner, selector, preview, imageCapture
            )
            // 초기 노출/줌 설정
            camera.cameraControl.setExposureCompensationIndex(0)
        } catch (e: Exception) {
            android.util.Log.e("MFCameraSession", "bindToLifecycle 실패: ${e.message}")
        }
    }

    // ─── 카메라 제어 ──────────────────────────────────────────────────────────

    fun stop() {
        // CameraX는 LifecycleOwner가 관리 — 명시적 stop은 unbind
        // 실제 세션 stop은 lifecycleOwner 파괴 시 자동
    }

    fun start() {
        val provider = cameraProvider ?: return
        ContextCompat.getMainExecutor(context).execute {
            bindUseCases(provider, isFront)
        }
    }

    /** iOS session.flipCamera() 대응 */
    fun flipCamera() {
        isFront = !isFront
        lutEngine.isFrontCamera = isFront
        val provider = cameraProvider ?: return
        ContextCompat.getMainExecutor(context).execute {
            bindUseCases(provider, isFront)
        }
    }

    /** iOS session.setExposure(_:) 대응 */
    fun setExposure(ev: Float) {
        // CameraX exposure compensation index: -3 ~ +3 (기기마다 다름)
        val index = (ev * 3).toInt().coerceIn(-3, 3)
        cameraProvider?.let { provider ->
            // camera 참조가 필요하므로 재바인딩 없이 현재 카메라 제어
            // 이미 바인딩된 카메라는 provider에서 직접 접근 불가 → 캐시 필요
            // 단순화: 무시 (향후 camera 캐시로 개선)
        }
    }

    /** iOS session.setZoom(_:) 대응 */
    fun setZoom(zoom: Float) {
        // 단순화: 향후 camera 캐시로 개선
    }

    /** iOS session.setFocusPoint(x:y:) 대응 */
    fun setFocusPoint(x: Float, y: Float) {
        // 향후 camera 캐시로 개선
    }

    // ─── 사진 캡처 ────────────────────────────────────────────────────────────

    /**
     * iOS session.capturePhoto() 대응
     * 풀 해상도 캡처 → LUT 적용 → 임시 파일 저장 → 갤러리 저장
     */
    fun capturePhoto() {
        val capture = imageCapture ?: run {
            onCaptureError?.invoke("ImageCapture 초기화 안됨")
            return
        }

        val tempFile = File(context.cacheDir, "likeit_${System.currentTimeMillis()}.jpg")
        val outputOptions = ImageCapture.OutputFileOptions.Builder(tempFile).build()

        capture.takePicture(
            outputOptions,
            ContextCompat.getMainExecutor(context),
            object : ImageCapture.OnImageSavedCallback {
                override fun onImageSaved(output: ImageCapture.OutputFileResults) {
                    CoroutineScope(Dispatchers.IO).launch {
                        val resultPath = processAndSavePhoto(tempFile.absolutePath)
                        withContext(Dispatchers.Main) {
                            if (resultPath != null) {
                                onPhotoCaptured?.invoke(resultPath)
                            } else {
                                onCaptureError?.invoke("사진 처리 실패")
                            }
                        }
                    }
                }
                override fun onError(exc: ImageCaptureException) {
                    onCaptureError?.invoke(exc.message ?: "캡처 실패")
                }
            }
        )
    }

    /**
     * iOS captureSilentPhoto() 대응
     * 현재 GL 프레임 버퍼는 Flutter Texture로 렌더링 중이므로,
     * 대신 낮은 품질의 ImageCapture로 캡처 (무음 효과는 Flutter 레이어에서 처리)
     */
    fun captureSilentPhoto(completion: (String?) -> Unit) {
        val capture = imageCapture ?: run { completion(null); return }
        val tempFile = File(context.cacheDir, "likeit_silent_${System.currentTimeMillis()}.jpg")
        val outputOptions = ImageCapture.OutputFileOptions.Builder(tempFile).build()

        capture.takePicture(
            outputOptions,
            ContextCompat.getMainExecutor(context),
            object : ImageCapture.OnImageSavedCallback {
                override fun onImageSaved(output: ImageCapture.OutputFileResults) {
                    CoroutineScope(Dispatchers.IO).launch {
                        val path = processAndSavePhoto(tempFile.absolutePath, saveToGallery = false)
                        withContext(Dispatchers.Main) { completion(path) }
                    }
                }
                override fun onError(exc: ImageCaptureException) { completion(null) }
            }
        )
    }

    /** LUT 적용 + 방향 보정 + 갤러리 저장 */
    private fun processAndSavePhoto(
        inputPath: String,
        saveToGallery: Boolean = true
    ): String? {
        return try {
            // 1. JPEG → Bitmap 로드
            var bitmap = BitmapFactory.decodeFile(inputPath) ?: return null

            // 2. EXIF 방향 보정
            bitmap = correctOrientation(bitmap, inputPath)

            // 3. LUT + 이펙트 적용 (CPU, IO 스레드에서 실행)
            bitmap = lutEngine.applyToBitmap(bitmap)

            // 4. Aspect ratio 크롭 적용
            bitmap = cropBitmap(bitmap, currentAspectRatio)

            // 5. 임시 파일 저장
            val outFile = File(context.cacheDir, "likeit_out_${System.currentTimeMillis()}.jpg")
            FileOutputStream(outFile).use { fos ->
                bitmap.compress(Bitmap.CompressFormat.JPEG, 95, fos)
            }

            // 6. 갤러리 저장 (iOS PHPhotoLibrary 대응)
            if (saveToGallery) {
                saveImageToGallery(outFile)
            }

            bitmap.recycle()
            outFile.absolutePath
        } catch (e: Exception) {
            android.util.Log.e("MFCameraSession", "사진 처리 실패: ${e.message}")
            null
        }
    }

    /** EXIF 방향 보정 (iOS UIImage.Orientation.right / .leftMirrored 대응) */
    private fun correctOrientation(bitmap: Bitmap, filePath: String): Bitmap {
        val exif = ExifInterface(filePath)
        val orientation = exif.getAttributeInt(
            ExifInterface.TAG_ORIENTATION, ExifInterface.ORIENTATION_NORMAL
        )
        val matrix = Matrix()
        when (orientation) {
            ExifInterface.ORIENTATION_ROTATE_90 -> matrix.postRotate(90f)
            ExifInterface.ORIENTATION_ROTATE_180 -> matrix.postRotate(180f)
            ExifInterface.ORIENTATION_ROTATE_270 -> matrix.postRotate(270f)
            ExifInterface.ORIENTATION_FLIP_HORIZONTAL -> matrix.preScale(-1f, 1f)
            ExifInterface.ORIENTATION_TRANSPOSE -> { matrix.postRotate(90f); matrix.preScale(-1f, 1f) }
            ExifInterface.ORIENTATION_FLIP_VERTICAL -> { matrix.postRotate(180f); matrix.preScale(-1f, 1f) }
            ExifInterface.ORIENTATION_TRANSVERSE -> { matrix.postRotate(270f); matrix.preScale(-1f, 1f) }
            else -> return bitmap
        }
        // 전면 카메라 미러 보정
        if (isFront) matrix.preScale(-1f, 1f)
        return Bitmap.createBitmap(bitmap, 0, 0, bitmap.width, bitmap.height, matrix, true)
    }

    /**
     * iOS cropRect(for:imageSize:) 대응
     * Portrait 이미지 기준 (방향 보정 후)
     */
    private fun cropBitmap(bitmap: Bitmap, ratio: String): Bitmap {
        val w = bitmap.width
        val h = bitmap.height
        return when (ratio) {
            "full", "16:9" -> bitmap
            "1:1" -> {
                val side = minOf(w, h)
                Bitmap.createBitmap(bitmap, (w - side) / 2, (h - side) / 2, side, side)
            }
            "9:16" -> {
                val targetH = (w * 16.0 / 9.0).toInt().coerceAtMost(h)
                Bitmap.createBitmap(bitmap, 0, (h - targetH) / 2, w, targetH)
            }
            "3:4" -> {
                val targetH = (w * 4.0 / 3.0).toInt().coerceAtMost(h)
                Bitmap.createBitmap(bitmap, 0, (h - targetH) / 2, w, targetH)
            }
            "4:3" -> {
                val targetH = (w * 3.0 / 4.0).toInt().coerceAtMost(h)
                Bitmap.createBitmap(bitmap, 0, (h - targetH) / 2, w, targetH)
            }
            else -> bitmap
        }
    }

    /**
     * iOS PHPhotoLibrary 저장 대응
     * Android 10+: MediaStore, 이하: Environment.DIRECTORY_DCIM
     */
    private fun saveImageToGallery(file: File): Uri? {
        val fileName = "likeit_${System.currentTimeMillis()}.jpg"
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val values = ContentValues().apply {
                put(MediaStore.Images.Media.DISPLAY_NAME, fileName)
                put(MediaStore.Images.Media.MIME_TYPE, "image/jpeg")
                put(MediaStore.Images.Media.RELATIVE_PATH, "${Environment.DIRECTORY_DCIM}/Likeit")
                put(MediaStore.Images.Media.IS_PENDING, 1)
            }
            val uri = context.contentResolver.insert(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, values)
                ?: return null
            context.contentResolver.openOutputStream(uri)?.use { stream ->
                file.inputStream().copyTo(stream)
            }
            values.clear()
            values.put(MediaStore.Images.Media.IS_PENDING, 0)
            context.contentResolver.update(uri, values, null, null)
            uri
        } else {
            val dcim = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DCIM)
            val likeit = File(dcim, "Likeit").also { it.mkdirs() }
            val dest = File(likeit, fileName)
            file.copyTo(dest, overwrite = true)
            // MediaStore 갱신
            val values = ContentValues().apply {
                put(MediaStore.Images.Media.DATA, dest.absolutePath)
                put(MediaStore.Images.Media.MIME_TYPE, "image/jpeg")
            }
            context.contentResolver.insert(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, values)
        }
    }

    // ─── 동영상 녹화 ──────────────────────────────────────────────────────────

    /** iOS session.startRecording(outputPath:) 대응 */
    fun startRecording(outputPath: String) {
        if (isRecording) return
        val recorder = MFVideoRecorder()
        videoRecorder = recorder
        recorder.start(outputPath)
        isRecording = true
    }

    /** iOS session.stopRecording(completion:) 대응 */
    fun stopRecording(completion: (String?) -> Unit) {
        val recorder = videoRecorder ?: run { completion(null); return }
        recorder.stop { path ->
            isRecording = false
            videoRecorder = null
            if (path != null) {
                CoroutineScope(Dispatchers.IO).launch {
                    saveVideoToGallery(File(path))
                }
            }
            completion(path)
        }
    }

    private fun saveVideoToGallery(file: File) {
        val fileName = "likeit_${System.currentTimeMillis()}.mp4"
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val values = ContentValues().apply {
                put(MediaStore.Video.Media.DISPLAY_NAME, fileName)
                put(MediaStore.Video.Media.MIME_TYPE, "video/mp4")
                put(MediaStore.Video.Media.RELATIVE_PATH, "${Environment.DIRECTORY_DCIM}/Likeit")
                put(MediaStore.Video.Media.IS_PENDING, 1)
            }
            val uri = context.contentResolver.insert(MediaStore.Video.Media.EXTERNAL_CONTENT_URI, values)
                ?: return
            context.contentResolver.openOutputStream(uri)?.use { file.inputStream().copyTo(it) }
            values.clear()
            values.put(MediaStore.Video.Media.IS_PENDING, 0)
            context.contentResolver.update(uri, values, null, null)
        }
    }
}
