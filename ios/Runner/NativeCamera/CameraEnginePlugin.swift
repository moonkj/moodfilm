import Flutter
import UIKit
import AVFoundation
import Photos

/// Flutter ↔ Native 카메라 엔진 Method Channel 핸들러
class CameraEnginePlugin: NSObject, FlutterPlugin {

    private var cameraSession: MFCameraSession?
    private var cameraPreview: MFCameraPreview?
    private var textureRegistry: FlutterTextureRegistry?
    private var pendingCapturResult: FlutterResult?

    static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(
            name: "com.moodfilm/camera_engine",
            binaryMessenger: registrar.messenger()
        )
        let instance = CameraEnginePlugin()
        instance.textureRegistry = registrar.textures()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    // MARK: - Method Channel 핸들러

    func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {

        case "initialize":
            handleInitialize(call: call, result: result)

        case "dispose":
            handleDispose(result: result)

        case "setFilter":
            handleSetFilter(call: call, result: result)

        case "setEffect":
            handleSetEffect(call: call, result: result)

        case "capturePhoto":
            handleCapturePhoto(result: result)

        case "capturePhotoSilent":
            handleCapturePhotoSilent(result: result)

        case "pauseSession":
            cameraSession?.stop()
            result(nil)

        case "resumeSession":
            cameraSession?.start()
            result(nil)

        case "flipCamera":
            cameraSession?.flipCamera()
            result(nil)

        case "setExposure":
            if let args = call.arguments as? [String: Any],
               let ev = args["ev"] as? Double {
                cameraSession?.setExposure(Float(ev))
            }
            result(nil)

        case "setZoom":
            if let args = call.arguments as? [String: Any],
               let zoom = args["zoom"] as? Double {
                cameraSession?.setZoom(CGFloat(zoom))
            }
            result(nil)

        case "setFocusPoint":
            if let args = call.arguments as? [String: Any],
               let x = args["x"] as? Double,
               let y = args["y"] as? Double {
                cameraSession?.setFocusPoint(x: CGFloat(x), y: CGFloat(y))
            }
            result(nil)

        case "isFrontCamera":
            result(cameraSession != nil)

        case "setSplitMode":
            if let args = call.arguments as? [String: Any] {
                let position = args["position"] as? Double ?? -1.0
                let isFront = args["isFrontCamera"] as? Bool ?? true
                cameraSession?.lutEngine.splitPosition = Float(position)
                cameraSession?.lutEngine.isFrontCamera = isFront
            }
            result(nil)

        case "setAspectRatio":
            if let args = call.arguments as? [String: Any],
               let ratio = args["ratio"] as? String {
                cameraSession?.currentAspectRatio = ratio
            }
            result(nil)

        case "setLivePhotoEnabled":
            if let args = call.arguments as? [String: Any],
               let enabled = args["enabled"] as? Bool {
                cameraSession?.setLivePhotoEnabled(enabled)
            }
            result(nil)

        case "startRecording":
            handleStartRecording(result: result)

        case "stopRecording":
            handleStopRecording(result: result)

        default:
            result(FlutterMethodNotImplemented)
        }
    }

    // MARK: - 초기화

    private func handleInitialize(call: FlutterMethodCall, result: @escaping FlutterResult) {
        NSLog("[CameraEnginePlugin] handleInitialize 시작")
        guard let registry = textureRegistry else {
            NSLog("[CameraEnginePlugin] ❌ textureRegistry 없음")
            result(FlutterError(code: "NO_REGISTRY", message: "TextureRegistry 없음", details: nil))
            return
        }

        let args = call.arguments as? [String: Any]
        let frontCamera = args?["frontCamera"] as? Bool ?? true
        NSLog("[CameraEnginePlugin] frontCamera=%d, 권한 요청 중...", frontCamera ? 1 : 0)

        // 카메라 권한 요청 (notDetermined 포함)
        AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
            NSLog("[CameraEnginePlugin] 권한 결과: granted=%d", granted ? 1 : 0)
            guard granted else {
                DispatchQueue.main.async {
                    result(FlutterError(code: "PERMISSION_DENIED", message: "카메라 권한이 없습니다", details: nil))
                }
                return
            }

            DispatchQueue.main.async {
                guard let self = self else { return }

                let preview = MFCameraPreview(textureRegistry: registry)
                NSLog("[CameraEnginePlugin] MFCameraPreview 생성 textureId=%lld", preview.textureId)
                let session = MFCameraSession()
                session.delegate = self

                self.cameraPreview = preview
                self.cameraSession = session

                NSLog("[CameraEnginePlugin] session.setup() 호출 중...")
                session.setup(frontCamera: frontCamera) { success in
                    NSLog("[CameraEnginePlugin] session.setup() 완료 success=%d", success ? 1 : 0)
                    guard success else {
                        result(FlutterError(code: "SETUP_FAILED", message: "카메라 설정 실패", details: nil))
                        return
                    }
                    session.start()
                    NSLog("[CameraEnginePlugin] session.start() 호출됨, textureId=%lld 반환", preview.textureId)
                    result(preview.textureId)
                }
            }
        }
    }

    // MARK: - 해제

    private func handleDispose(result: FlutterResult) {
        cameraSession?.stop()
        cameraPreview?.dispose()
        cameraSession = nil
        cameraPreview = nil
        result(nil)
    }

    // MARK: - 필터 설정

    private func handleSetFilter(call: FlutterMethodCall, result: FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let lutFile = args["lutFile"] as? String,
              let intensity = args["intensity"] as? Double else {
            result(FlutterError(code: "INVALID_ARGS", message: "lutFile, intensity 필요", details: nil))
            return
        }

        // 빈 파일명 = 필터 없음
        if lutFile.isEmpty {
            cameraSession?.lutEngine.intensity = 0.0
        } else {
            cameraSession?.lutEngine.loadLUT(named: lutFile)
            cameraSession?.lutEngine.intensity = Float(intensity)
        }
        result(nil)
    }

    // MARK: - 이펙트 설정

    private func handleSetEffect(call: FlutterMethodCall, result: FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let effectType = args["effectType"] as? String,
              let intensity = args["intensity"] as? Double else {
            result(nil)
            return
        }

        switch effectType {
        case "dreamyGlow", "glow":
            cameraSession?.lutEngine.glowIntensity = Float(intensity)
        case "filmGrain":
            cameraSession?.lutEngine.grainIntensity = Float(intensity)
        case "beauty":
            cameraSession?.lutEngine.beautyIntensity = Float(intensity)
        case "lightLeak":
            cameraSession?.lutEngine.lightLeakIntensity = Float(intensity)
        case "softness":
            cameraSession?.lutEngine.softnessIntensity = Float(intensity)
        case "brightness":
            cameraSession?.lutEngine.brightnessIntensity = Float(intensity)
        case "contrast":
            cameraSession?.lutEngine.contrastIntensity = Float(intensity)
        case "saturation":
            cameraSession?.lutEngine.saturationIntensity = Float(intensity)
        default:
            break
        }
        result(nil)
    }

    // MARK: - 사진 촬영

    private func handleCapturePhoto(result: @escaping FlutterResult) {
        pendingCapturResult = result
        cameraSession?.capturePhoto()
    }

    // MARK: - 무음 촬영 (현재 프레임 → 갤러리 저장)

    private func handleCapturePhotoSilent(result: @escaping FlutterResult) {
        guard let session = cameraSession else {
            result(FlutterError(code: "NO_SESSION", message: "카메라 세션 없음", details: nil))
            return
        }
        session.captureSilentPhoto { [weak self] path in
            guard let path = path else {
                result(FlutterError(code: "CAPTURE_FAILED", message: "무음 촬영 실패", details: nil))
                return
            }
            PHPhotoLibrary.requestAuthorization { status in
                guard status == .authorized || status == .limited else {
                    DispatchQueue.main.async { result(path) }
                    return
                }
                PHPhotoLibrary.shared().performChanges({
                    PHAssetChangeRequest.creationRequestForAssetFromImage(atFileURL: URL(fileURLWithPath: path))
                }) { _, _ in
                    DispatchQueue.main.async { result(path) }
                }
            }
        }
    }

    // MARK: - 동영상 녹화

    private func handleStartRecording(result: @escaping FlutterResult) {
        guard let session = cameraSession else {
            result(FlutterError(code: "NO_SESSION", message: "카메라 세션 없음", details: nil))
            return
        }
        let outputPath = NSTemporaryDirectory() + "moodfilm_video_\(Int(Date().timeIntervalSince1970)).mp4"
        session.startRecording(outputPath: outputPath)
        result(outputPath)
    }

    private func handleStopRecording(result: @escaping FlutterResult) {
        guard let session = cameraSession else {
            result(FlutterError(code: "NO_SESSION", message: "카메라 세션 없음", details: nil))
            return
        }
        session.stopRecording { [weak self] path in
            guard let path = path else {
                print("[CameraEnginePlugin] 녹화 실패: AVAssetWriter status != completed")
                result(FlutterError(code: "RECORD_FAILED", message: "녹화 저장 실패", details: nil))
                return
            }
            // 갤러리 저장
            PHPhotoLibrary.requestAuthorization { status in
                guard status == .authorized || status == .limited else {
                    print("[CameraEnginePlugin] 사진 라이브러리 권한 없음: \(status.rawValue)")
                    DispatchQueue.main.async { result(path) }
                    return
                }
                PHPhotoLibrary.shared().performChanges({
                    PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: URL(fileURLWithPath: path))
                }) { success, error in
                    if !success {
                        print("[CameraEnginePlugin] 갤러리 저장 실패: \(error?.localizedDescription ?? "unknown")")
                    }
                    DispatchQueue.main.async { result(path) }
                }
            }
        }
    }
}

// MARK: - MFCameraSessionDelegate

extension CameraEnginePlugin: MFCameraSessionDelegate {

    func cameraSession(_ session: MFCameraSession, didOutput pixelBuffer: CVPixelBuffer) {
        cameraPreview?.update(pixelBuffer: pixelBuffer)
    }

    func cameraSession(_ session: MFCameraSession, didCapturePhoto path: String, livePhotoMovieURL: URL?) {
        PHPhotoLibrary.requestAuthorization { status in
            guard status == .authorized || status == .limited else {
                DispatchQueue.main.async {
                    self.pendingCapturResult?(path)
                    self.pendingCapturResult = nil
                }
                return
            }

            PHPhotoLibrary.shared().performChanges({
                if let movURL = livePhotoMovieURL {
                    // 라이브포토: JPEG + MOV 쌍으로 저장
                    let req = PHAssetCreationRequest.forAsset()
                    req.addResource(with: .photo, fileURL: URL(fileURLWithPath: path), options: nil)
                    let movOptions = PHAssetResourceCreationOptions()
                    movOptions.shouldMoveFile = true
                    req.addResource(with: .pairedVideo, fileURL: movURL, options: movOptions)
                } else {
                    PHAssetChangeRequest.creationRequestForAssetFromImage(
                        atFileURL: URL(fileURLWithPath: path))
                }
            }) { _, _ in
                DispatchQueue.main.async {
                    self.pendingCapturResult?(path)
                    self.pendingCapturResult = nil
                }
            }
        }
    }

    func cameraSession(_ session: MFCameraSession, didFailWithError error: Error) {
        DispatchQueue.main.async {
            self.pendingCapturResult?(
                FlutterError(code: "CAPTURE_FAILED", message: error.localizedDescription, details: nil)
            )
            self.pendingCapturResult = nil
        }
    }
}
