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
        guard let registry = textureRegistry else {
            result(FlutterError(code: "NO_REGISTRY", message: "TextureRegistry 없음", details: nil))
            return
        }

        let args = call.arguments as? [String: Any]
        let frontCamera = args?["frontCamera"] as? Bool ?? true

        // 카메라 권한 요청 (notDetermined 포함)
        AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
            guard granted else {
                DispatchQueue.main.async {
                    result(FlutterError(code: "PERMISSION_DENIED", message: "카메라 권한이 없습니다", details: nil))
                }
                return
            }

            DispatchQueue.main.async {
                guard let self = self else { return }

                let preview = MFCameraPreview(textureRegistry: registry)
                let session = MFCameraSession()
                session.delegate = self

                self.cameraPreview = preview
                self.cameraSession = session

                session.setup(frontCamera: frontCamera) { success in
                    guard success else {
                        result(FlutterError(code: "SETUP_FAILED", message: "카메라 설정 실패", details: nil))
                        return
                    }
                    session.start()
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

        cameraSession?.lutEngine.loadLUT(named: lutFile)
        cameraSession?.lutEngine.intensity = Float(intensity)
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
        case "dreamyGlow":
            cameraSession?.lutEngine.glowIntensity = Float(intensity)
        case "filmGrain":
            cameraSession?.lutEngine.grainIntensity = Float(intensity)
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
                result(FlutterError(code: "RECORD_FAILED", message: "녹화 저장 실패", details: nil))
                return
            }
            // 갤러리 저장
            PHPhotoLibrary.requestAuthorization { status in
                guard status == .authorized || status == .limited else {
                    DispatchQueue.main.async { result(path) }
                    return
                }
                PHPhotoLibrary.shared().performChanges({
                    PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: URL(fileURLWithPath: path))
                }) { _, _ in
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

    func cameraSession(_ session: MFCameraSession, didCapturePhoto path: String) {
        // 갤러리 저장
        PHPhotoLibrary.requestAuthorization { status in
            guard status == .authorized || status == .limited else {
                DispatchQueue.main.async {
                    self.pendingCapturResult?(path) // 저장 실패해도 경로 반환
                    self.pendingCapturResult = nil
                }
                return
            }

            PHPhotoLibrary.shared().performChanges({
                PHAssetChangeRequest.creationRequestForAssetFromImage(atFileURL: URL(fileURLWithPath: path))
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
