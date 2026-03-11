package com.moodfilm.moodfilm.camera

import android.Manifest
import android.app.Activity
import android.content.pm.PackageManager
import android.util.Log
import androidx.core.content.ContextCompat
import androidx.lifecycle.LifecycleOwner
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch

/**
 * Flutter ↔ Android 카메라 엔진 Method Channel 핸들러
 * iOS CameraEnginePlugin.swift 1:1 대응
 * Channel: com.moodfilm/camera_engine
 */
class CameraEnginePlugin : FlutterPlugin, MethodChannel.MethodCallHandler, ActivityAware {

    private lateinit var channel: MethodChannel
    private lateinit var binding: FlutterPlugin.FlutterPluginBinding

    private var activity: Activity? = null

    private var cameraPreview: MFCameraPreview? = null
    private var glRenderer: MFGLRenderer? = null
    private var lutEngine: MFLUTEngine? = null
    private var cameraSession: MFCameraSession? = null

    companion object {
        private const val TAG = "CameraEnginePlugin"
        private const val CHANNEL = "com.moodfilm/camera_engine"
    }

    // ─── FlutterPlugin ────────────────────────────────────────────────────────

    override fun onAttachedToEngine(flutterBinding: FlutterPlugin.FlutterPluginBinding) {
        binding = flutterBinding
        channel = MethodChannel(flutterBinding.binaryMessenger, CHANNEL)
        channel.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }

    // ─── ActivityAware (CameraX LifecycleOwner 획득) ──────────────────────────

    override fun onAttachedToActivity(activityBinding: ActivityPluginBinding) {
        activity = activityBinding.activity
    }

    override fun onDetachedFromActivity() {
        activity = null
    }

    override fun onReattachedToActivityForConfigChanges(activityBinding: ActivityPluginBinding) {
        activity = activityBinding.activity
    }

    override fun onDetachedFromActivityForConfigChanges() {
        activity = null
    }

    // ─── Method Channel 핸들러 ────────────────────────────────────────────────

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "initialize"          -> handleInitialize(call, result)
            "dispose"             -> handleDispose(result)
            "setFilter"           -> handleSetFilter(call, result)
            "setEffect"           -> handleSetEffect(call, result)
            "capturePhoto"        -> handleCapturePhoto(result)
            "capturePhotoSilent"  -> handleCapturePhotoSilent(result)
            "pauseSession"        -> { cameraSession?.stop(); result.success(null) }
            "resumeSession"       -> { cameraSession?.start(); result.success(null) }
            "flipCamera"          -> { cameraSession?.flipCamera(); result.success(null) }
            "setExposure"         -> handleSetExposure(call, result)
            "setZoom"             -> handleSetZoom(call, result)
            "setFocusPoint"       -> handleSetFocusPoint(call, result)
            "isFrontCamera"       -> result.success(cameraSession != null)
            "setSplitMode"        -> handleSetSplitMode(call, result)
            "setAspectRatio"      -> handleSetAspectRatio(call, result)
            "startRecording"      -> handleStartRecording(result)
            "stopRecording"       -> handleStopRecording(result)
            "setLivePhotoEnabled" -> result.success(null) // Android 미지원, 무시
            else                  -> result.notImplemented()
        }
    }

    // ─── 초기화 ───────────────────────────────────────────────────────────────

    private fun handleInitialize(call: MethodCall, result: MethodChannel.Result) {
        Log.d(TAG, "handleInitialize 시작")

        val ctx = binding.applicationContext
        val act = activity

        if (act == null) {
            result.error("NO_ACTIVITY", "Activity 없음", null)
            return
        }

        // 카메라 권한 확인
        if (ContextCompat.checkSelfPermission(ctx, Manifest.permission.CAMERA)
            != PackageManager.PERMISSION_GRANTED) {
            result.error("PERMISSION_DENIED", "카메라 권한 없음", null)
            return
        }

        val frontCamera = call.argument<Boolean>("frontCamera") ?: true
        Log.d(TAG, "frontCamera=$frontCamera")

        // 기존 세션 정리
        cleanupSession()

        // Flutter Texture 생성
        val preview = MFCameraPreview(binding.textureRegistry)
        val renderer = MFGLRenderer(preview.getSurfaceTexture())
        val engine = MFLUTEngine(ctx, renderer)

        val lifecycleOwner = act as? LifecycleOwner ?: run {
            result.error("NO_LIFECYCLE", "Activity가 LifecycleOwner를 구현하지 않음", null)
            return
        }

        val session = MFCameraSession(ctx, lifecycleOwner, renderer, engine)
        session.onPhotoCaptured = { path ->
            CoroutineScope(Dispatchers.Main).launch {
                // CameraEnginePlugin이 capturePhoto result를 직접 반환
                pendingCaptureResult?.success(path)
                pendingCaptureResult = null
            }
        }
        session.onCaptureError = { msg ->
            CoroutineScope(Dispatchers.Main).launch {
                pendingCaptureResult?.error("CAPTURE_FAILED", msg, null)
                pendingCaptureResult = null
            }
        }

        cameraPreview = preview
        glRenderer = renderer
        lutEngine = engine
        cameraSession = session

        // 카메라 세션 시작
        session.setup(frontCamera) { success ->
            if (success) {
                Log.d(TAG, "카메라 세션 준비 완료, textureId=${preview.textureId}")
                result.success(preview.textureId)
            } else {
                result.error("SETUP_FAILED", "카메라 설정 실패", null)
                cleanupSession()
            }
        }
    }

    // ─── 해제 ─────────────────────────────────────────────────────────────────

    private fun handleDispose(result: MethodChannel.Result) {
        cleanupSession()
        result.success(null)
    }

    private fun cleanupSession() {
        cameraSession?.stop()
        cameraPreview?.dispose()
        glRenderer?.release()
        cameraSession = null
        cameraPreview = null
        glRenderer = null
        lutEngine = null
    }

    // ─── 필터 설정 ────────────────────────────────────────────────────────────

    private fun handleSetFilter(call: MethodCall, result: MethodChannel.Result) {
        val lutFile = call.argument<String>("lutFile") ?: ""
        val intensity = (call.argument<Double>("intensity") ?: 1.0).toFloat()

        val engine = lutEngine ?: run { result.success(null); return }

        if (lutFile.isEmpty()) {
            engine.clearLUT()
            engine.intensity = 0f
        } else {
            engine.loadLUT(lutFile)
            engine.intensity = intensity
        }
        result.success(null)
    }

    // ─── 이펙트 설정 (iOS handleSetEffect 1:1 대응) ───────────────────────────

    private fun handleSetEffect(call: MethodCall, result: MethodChannel.Result) {
        val effectType = call.argument<String>("effectType") ?: run { result.success(null); return }
        val intensity = (call.argument<Double>("intensity") ?: 0.0).toFloat()
        val engine = lutEngine ?: run { result.success(null); return }

        when (effectType) {
            "dreamyGlow", "glow" -> engine.glowIntensity = intensity
            "filmGrain"          -> engine.grainIntensity = intensity
            "beauty"             -> engine.beautyIntensity = intensity
            "lightLeak"          -> engine.lightLeakIntensity = intensity
            "softness"           -> engine.softnessIntensity = intensity
            "brightness"         -> engine.brightnessIntensity = intensity
            "contrast"           -> engine.contrastIntensity = intensity
            "saturation"         -> engine.saturationIntensity = intensity
        }
        result.success(null)
    }

    // ─── 사진 촬영 ────────────────────────────────────────────────────────────

    // 촬영 결과 대기 콜백 (iOS pendingCaptureResult 대응)
    private var pendingCaptureResult: MethodChannel.Result? = null

    private fun handleCapturePhoto(result: MethodChannel.Result) {
        val session = cameraSession ?: run {
            result.error("NO_SESSION", "카메라 세션 없음", null)
            return
        }
        pendingCaptureResult = result
        session.capturePhoto()
    }

    private fun handleCapturePhotoSilent(result: MethodChannel.Result) {
        val session = cameraSession ?: run {
            result.error("NO_SESSION", "카메라 세션 없음", null)
            return
        }
        session.captureSilentPhoto { path ->
            if (path != null) result.success(path)
            else result.error("CAPTURE_FAILED", "무음 촬영 실패", null)
        }
    }

    // ─── 카메라 제어 ──────────────────────────────────────────────────────────

    private fun handleSetExposure(call: MethodCall, result: MethodChannel.Result) {
        val ev = (call.argument<Double>("ev") ?: 0.0).toFloat()
        cameraSession?.setExposure(ev)
        result.success(null)
    }

    private fun handleSetZoom(call: MethodCall, result: MethodChannel.Result) {
        val zoom = (call.argument<Double>("zoom") ?: 1.0).toFloat()
        cameraSession?.setZoom(zoom)
        result.success(null)
    }

    private fun handleSetFocusPoint(call: MethodCall, result: MethodChannel.Result) {
        val x = (call.argument<Double>("x") ?: 0.5).toFloat()
        val y = (call.argument<Double>("y") ?: 0.5).toFloat()
        cameraSession?.setFocusPoint(x, y)
        result.success(null)
    }

    private fun handleSetSplitMode(call: MethodCall, result: MethodChannel.Result) {
        val position = (call.argument<Double>("position") ?: -1.0).toFloat()
        val isFront = call.argument<Boolean>("isFrontCamera") ?: true
        lutEngine?.splitPosition = position
        lutEngine?.isFrontCamera = isFront
        result.success(null)
    }

    private fun handleSetAspectRatio(call: MethodCall, result: MethodChannel.Result) {
        val ratio = call.argument<String>("ratio") ?: "full"
        cameraSession?.currentAspectRatio = ratio
        result.success(null)
    }

    // ─── 동영상 녹화 ──────────────────────────────────────────────────────────

    private fun handleStartRecording(result: MethodChannel.Result) {
        val session = cameraSession ?: run {
            result.error("NO_SESSION", "카메라 세션 없음", null)
            return
        }
        val path = "${binding.applicationContext.cacheDir}/likeit_video_${System.currentTimeMillis()}.mp4"
        session.startRecording(path)
        result.success(path)
    }

    private fun handleStopRecording(result: MethodChannel.Result) {
        val session = cameraSession ?: run {
            result.error("NO_SESSION", "카메라 세션 없음", null)
            return
        }
        session.stopRecording { path ->
            if (path != null) result.success(path)
            else result.error("RECORD_FAILED", "녹화 저장 실패", null)
        }
    }
}
