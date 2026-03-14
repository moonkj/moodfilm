import Flutter
import UIKit
import CoreImage
import AVFoundation
import Photos

// UIImage.Orientation → CGImagePropertyOrientation 변환 (rawValue가 다름)
// private → internal: MFImagePreviewRenderer에서도 사용
extension CGImagePropertyOrientation {
    init(_ uiOrientation: UIImage.Orientation) {
        switch uiOrientation {
        case .up:            self = .up
        case .upMirrored:    self = .upMirrored
        case .down:          self = .down
        case .downMirrored:  self = .downMirrored
        case .left:          self = .left
        case .leftMirrored:  self = .leftMirrored
        case .right:         self = .right
        case .rightMirrored: self = .rightMirrored
        @unknown default:    self = .up
        }
    }
}

/// 갤러리 이미지 필터 처리 플러그인
/// Full-resolution 이미지에 LUT + CIFilter 조정값 적용 후 저장
class FilterEnginePlugin: NSObject, FlutterPlugin {

    private let lutEngine = MFLUTEngine()
    private var textureRegistry: FlutterTextureRegistry?
    private var videoPlayer: MFVideoFilterPlayer?
    private var imageRenderer: MFImagePreviewRenderer?
    private var lastProcessedImagePath: String?  // 임시 파일 누적 방지

    static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(
            name: "com.moodfilm/filter_engine",
            binaryMessenger: registrar.messenger()
        )
        let instance = FilterEnginePlugin()
        instance.textureRegistry = registrar.textures()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "initImagePreview":
            handleInitImagePreview(call: call, result: result)
        case "updateImagePreview":
            handleUpdateImagePreview(call: call, result: result)
        case "disposeImagePreview":
            imageRenderer?.dispose(); imageRenderer = nil; result(nil)
        case "processImage":
            handleProcessImage(call: call, result: result)
        case "processVideo":
            handleProcessVideo(call: call, result: result)
        case "trimVideo":
            handleTrimVideo(call: call, result: result)
        case "getVideoDuration":
            if let args = call.arguments as? [String: Any],
               let path = args["path"] as? String {
                let asset = AVURLAsset(url: URL(fileURLWithPath: path))
                let seconds = CMTimeGetSeconds(asset.duration)
                result(seconds.isNaN || seconds.isInfinite ? 0.0 : seconds)
            } else { result(0.0) }
        case "generateThumbnail":
            handleGenerateThumbnail(call: call, result: result)
        case "extractVideoFrame":
            handleExtractVideoFrame(call: call, result: result)
        case "startVideoPreview":
            handleStartVideoPreview(call: call, result: result)
        case "stopVideoPreview":
            videoPlayer?.dispose(); videoPlayer = nil; result(nil)
        case "setVideoPreviewFilter":
            handleSetVideoPreviewFilter(call: call, result: result)
        case "setVideoPreviewEffects":
            handleSetVideoPreviewEffects(call: call, result: result)
        case "playVideoPreview":
            videoPlayer?.play(); result(nil)
        case "pauseVideoPreview":
            videoPlayer?.pause(); result(nil)
        case "seekVideoPreview":
            if let args = call.arguments as? [String: Any],
               let seconds = args["seconds"] as? Double {
                videoPlayer?.seek(to: seconds)
            }
            result(nil)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    // MARK: - Image Preview (실시간 Texture 기반)

    private func handleInitImagePreview(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let sourcePath = args["sourcePath"] as? String,
              let registry = textureRegistry else {
            result(FlutterError(code: "INVALID_ARGS", message: "sourcePath 필요", details: nil))
            return
        }

        let lutFile     = args["lutFile"]      as? String ?? ""
        let intensity   = Float(args["intensity"] as? Double ?? 1.0)
        let adjustments = args["adjustments"]  as? [String: Double] ?? [:]
        let effects     = args["effects"]      as? [String: Double] ?? [:]

        imageRenderer?.dispose()
        let renderer = MFImagePreviewRenderer()

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard self != nil else { return }
            guard renderer.loadImage(from: sourcePath) else {
                DispatchQueue.main.async {
                    result(FlutterError(code: "LOAD_FAILED", message: "이미지 로드 실패", details: nil))
                }
                return
            }
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                let textureId = renderer.start(registry: registry)
                renderer.update(lutFile: lutFile, intensity: intensity,
                                adjustments: adjustments, effects: effects)
                self.imageRenderer = renderer
                result([
                    "textureId": textureId,
                    "width":     renderer.outputWidth,
                    "height":    renderer.outputHeight,
                ])
            }
        }
    }

    private func handleUpdateImagePreview(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any] else { result(nil); return }
        let lutFile     = args["lutFile"]      as? String ?? ""
        let intensity   = Float(args["intensity"] as? Double ?? 1.0)
        let adjustments = args["adjustments"]  as? [String: Double] ?? [:]
        let effects     = args["effects"]      as? [String: Double] ?? [:]
        imageRenderer?.update(lutFile: lutFile, intensity: intensity,
                              adjustments: adjustments, effects: effects)
        result(nil)
    }

    // MARK: - Video Preview

    private func handleStartVideoPreview(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let videoPath = args["videoPath"] as? String else {
            result(FlutterError(code: "INVALID_ARGS", message: "videoPath 필요", details: nil))
            return
        }
        guard let registry = textureRegistry else {
            result(FlutterError(code: "NO_REGISTRY", message: "TextureRegistry 없음", details: nil))
            return
        }

        videoPlayer?.dispose()

        let url = URL(fileURLWithPath: videoPath)
        let player = MFVideoFilterPlayer(url: url)

        let lutFile  = args["lutFile"]   as? String ?? ""
        let intensity = Float(args["intensity"] as? Double ?? 1.0)
        let effects  = args["effects"]  as? [String: Double] ?? [:]
        player.updateFilter(lutFile: lutFile, intensity: intensity)
        player.updateEffects(effects)

        let textureId = player.start(registry: registry)
        videoPlayer = player

        // 백그라운드에서 모든 LUT 파일 캐시 선점 — 첫 필터 전환 시 버벅임 방지
        let preloadLuts = args["preloadLuts"] as? [String] ?? []
        if !preloadLuts.isEmpty {
            player.preloadLUTs(preloadLuts)
        }

        let size = player.videoSize
        result([
            "textureId": textureId,
            "width":     Int(size.width),
            "height":    Int(size.height),
        ])
    }

    private func handleSetVideoPreviewFilter(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any] else { result(nil); return }
        let lutFile   = args["lutFile"]   as? String ?? ""
        let intensity = Float(args["intensity"] as? Double ?? 1.0)
        videoPlayer?.updateFilter(lutFile: lutFile, intensity: intensity)
        result(nil)
    }

    private func handleSetVideoPreviewEffects(call: FlutterMethodCall, result: @escaping FlutterResult) {
        let effects = (call.arguments as? [String: Any])?.compactMapValues { $0 as? Double } ?? [:]
        videoPlayer?.updateEffects(effects)
        result(nil)
    }

    // MARK: - processImage

    private func handleProcessImage(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let sourcePath = args["sourcePath"] as? String,
              let lutFile = args["lutFile"] as? String,
              let intensity = args["intensity"] as? Double else {
            result(FlutterError(code: "INVALID_ARGS", message: "sourcePath, lutFile, intensity 필요", details: nil))
            return
        }

        let adjustments = args["adjustments"] as? [String: Double] ?? [:]
        let effects = args["effects"] as? [String: Double] ?? [:]
        let saveToGallery = args["saveToGallery"] as? Bool ?? false
        let maxSize = args["maxSize"] as? Int  // nil = 풀해상도, 정수 = 빠른 프리뷰용 다운스케일

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            guard let outputPath = self.processImage(
                sourcePath: sourcePath,
                lutFile: lutFile,
                intensity: Float(intensity),
                adjustments: adjustments,
                effects: effects,
                maxSize: maxSize
            ) else {
                DispatchQueue.main.async {
                    result(FlutterError(code: "PROCESS_FAILED", message: "이미지 처리 실패", details: nil))
                }
                return
            }

            guard saveToGallery else {
                DispatchQueue.main.async { result(outputPath) }
                return
            }

            // 갤러리 저장
            PHPhotoLibrary.requestAuthorization { status in
                guard status == .authorized || status == .limited else {
                    DispatchQueue.main.async { result(outputPath) }
                    return
                }
                PHPhotoLibrary.shared().performChanges({
                    PHAssetChangeRequest.creationRequestForAssetFromImage(
                        atFileURL: URL(fileURLWithPath: outputPath)
                    )
                }) { _, _ in
                    DispatchQueue.main.async { result(outputPath) }
                }
            }
        }
    }

    private func processImage(
        sourcePath: String,
        lutFile: String,
        intensity: Float,
        adjustments: [String: Double],
        effects: [String: Double],
        maxSize: Int? = nil
    ) -> String? {
        guard var uiImage = UIImage(contentsOfFile: sourcePath) else { return nil }

        // 빠른 프리뷰용 다운스케일 — maxSize가 있으면 longest edge를 제한
        if let maxSize = maxSize {
            let longest = max(uiImage.size.width, uiImage.size.height)
            let scale = CGFloat(maxSize) / longest
            if scale < 1.0 {
                let newSize = CGSize(
                    width: (uiImage.size.width * scale).rounded(),
                    height: (uiImage.size.height * scale).rounded()
                )
                UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
                uiImage.draw(in: CGRect(origin: .zero, size: newSize))
                if let scaled = UIGraphicsGetImageFromCurrentImageContext() {
                    uiImage = scaled
                }
                UIGraphicsEndImageContext()
            }
        }

        let ciOptions: [CIImageOption: Any] = [.colorSpace: CGColorSpace(name: CGColorSpace.sRGB)!]
        guard var ciImage = CIImage(image: uiImage, options: ciOptions) else { return nil }

        // UIImage orientation 보정: CIImage는 픽셀 기준이므로 orientation을 무시함.
        // 세로 사진(orientation=.right 등)이 landscape CIImage로 처리되면 이펙트 위치가 틀림.
        // oriented()를 적용하면 이후 모든 이펙트가 올바른(portrait) 방향으로 적용됨.
        let ciOrientation = CGImagePropertyOrientation(uiImage.imageOrientation)
        if ciOrientation != .up {
            ciImage = ciImage.oriented(ciOrientation)
        }

        // 1. 조정값 적용 (CIFilters)
        ciImage = MFLUTEngine.applyAdjustments(to: ciImage, adjustments: adjustments)

        // 2. LUT 필터 + 이펙트 적용 (빈 lutFile = 필터 없음)
        if !lutFile.isEmpty {
            lutEngine.loadLUT(named: lutFile)
            lutEngine.intensity = intensity
        } else {
            lutEngine.intensity = 0.0
        }
        lutEngine.glowIntensity        = Float(effects["dreamyGlow"] ?? effects["glow"] ?? 0)
        lutEngine.grainIntensity       = Float(effects["filmGrain"] ?? 0)
        lutEngine.beautyIntensity      = Float(effects["beauty"] ?? 0)
        lutEngine.lightLeakIntensity   = Float(effects["lightLeak"] ?? 0)
        lutEngine.softnessIntensity    = Float(effects["softness"] ?? 0)
        lutEngine.brightnessIntensity  = Float(effects["brightness"] ?? 0)
        lutEngine.contrastIntensity    = Float(effects["contrast"] ?? 0)
        lutEngine.saturationIntensity  = Float(effects["saturation"] ?? 0)

        let hasEffect = (intensity > 0 && !lutFile.isEmpty)
            || lutEngine.glowIntensity > 0
            || lutEngine.grainIntensity > 0
            || lutEngine.beautyIntensity > 0
            || lutEngine.lightLeakIntensity > 0
            || lutEngine.softnessIntensity > 0
            || lutEngine.brightnessIntensity != 0
            || lutEngine.contrastIntensity != 0
            || lutEngine.saturationIntensity != 0
        if hasEffect {
            ciImage = lutEngine.apply(to: ciImage)
        }

        // 3. CIImage → CGImage → UIImage → JPEG 저장
        let outputSize = CGSize(
            width: ciImage.extent.width,
            height: ciImage.extent.height
        )
        guard let cgImage = MFLUTEngine.ciContext.createCGImage(ciImage, from: ciImage.extent) else {
            return nil
        }

        // CIImage.oriented()로 이미 방향 보정됨 → orientation은 .up
        let outputImage = UIImage(cgImage: cgImage, scale: uiImage.scale, orientation: .up)
        guard let jpegData = outputImage.jpegData(compressionQuality: 0.95) else { return nil }

        // 이전 임시 파일 삭제 (누적 방지)
        if let prev = lastProcessedImagePath {
            try? FileManager.default.removeItem(atPath: prev)
        }
        let outputPath = NSTemporaryDirectory() + "moodfilm_\(Int(Date().timeIntervalSince1970)).jpg"
        do {
            try jpegData.write(to: URL(fileURLWithPath: outputPath))
            lastProcessedImagePath = outputPath
            return outputPath
        } catch {
            print("[FilterEnginePlugin] 저장 실패: \(error)")
            return nil
        }
    }

    // MARK: - processVideo

    private func handleProcessVideo(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let sourcePath = args["sourcePath"] as? String,
              let lutFile = args["lutFile"] as? String,
              let intensity = args["intensity"] as? Double else {
            result(FlutterError(code: "INVALID_ARGS", message: "sourcePath, lutFile, intensity 필요", details: nil))
            return
        }

        let effects = args["effects"] as? [String: Double] ?? [:]
        let saveToGallery = args["saveToGallery"] as? Bool ?? true

        let sourceURL = URL(fileURLWithPath: sourcePath)
        let asset = AVURLAsset(url: sourceURL)

        // 각 프레임에 적용할 LUT 엔진 (인스턴스 캡처용)
        let engine = MFLUTEngine()
        if !lutFile.isEmpty {
            engine.loadLUT(named: lutFile)
            engine.intensity = Float(intensity)
        } else {
            engine.intensity = 0.0
        }
        engine.brightnessIntensity = Float(effects["brightness"] ?? 0)
        engine.contrastIntensity = Float(effects["contrast"] ?? 0)
        engine.saturationIntensity = Float(effects["saturation"] ?? 0)
        engine.softnessIntensity = Float(effects["softness"] ?? 0)
        engine.beautyIntensity = Float(effects["beauty"] ?? 0)
        engine.glowIntensity = Float(effects["dreamyGlow"] ?? effects["glow"] ?? 0)
        engine.grainIntensity = Float(effects["filmGrain"] ?? 0)
        engine.lightLeakIntensity = Float(effects["lightLeak"] ?? 0)

        // AVVideoComposition으로 각 프레임에 CIFilter 적용
        let composition = AVVideoComposition(asset: asset) { request in
            let filtered = engine.apply(to: request.sourceImage.clampedToExtent())
                .cropped(to: request.sourceImage.extent)
            request.finish(with: filtered, context: nil)
        }

        let outputPath = NSTemporaryDirectory() + "moodfilm_video_\(Int(Date().timeIntervalSince1970)).mp4"
        let outputURL = URL(fileURLWithPath: outputPath)
        try? FileManager.default.removeItem(at: outputURL)

        guard let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetHighestQuality) else {
            result(FlutterError(code: "EXPORT_FAILED", message: "AVAssetExportSession 생성 실패", details: nil))
            return
        }

        exportSession.videoComposition = composition
        exportSession.outputURL = outputURL
        exportSession.outputFileType = .mp4

        exportSession.exportAsynchronously {
            guard exportSession.status == .completed else {
                DispatchQueue.main.async {
                    result(FlutterError(
                        code: "EXPORT_FAILED",
                        message: exportSession.error?.localizedDescription ?? "내보내기 실패",
                        details: nil
                    ))
                }
                return
            }

            guard saveToGallery else {
                DispatchQueue.main.async { result(outputPath) }
                return
            }

            PHPhotoLibrary.requestAuthorization { status in
                guard status == .authorized || status == .limited else {
                    DispatchQueue.main.async { result(outputPath) }
                    return
                }
                PHPhotoLibrary.shared().performChanges({
                    PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: outputURL)
                }) { _, _ in
                    DispatchQueue.main.async { result(outputPath) }
                }
            }
        }
    }

    // MARK: - trimVideo

    private func handleTrimVideo(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let sourcePath   = args["sourcePath"]    as? String,
              let startSeconds = args["startSeconds"]  as? Double,
              let endSeconds   = args["endSeconds"]    as? Double else {
            result(FlutterError(code: "INVALID_ARGS", message: "sourcePath, startSeconds, endSeconds 필요", details: nil))
            return
        }

        let saveToGallery = args["saveToGallery"] as? Bool ?? true
        let sourceURL = URL(fileURLWithPath: sourcePath)
        let asset     = AVURLAsset(url: sourceURL)

        let startTime = CMTime(seconds: startSeconds, preferredTimescale: 600)
        let endTime   = CMTime(seconds: endSeconds,   preferredTimescale: 600)
        let timeRange = CMTimeRange(start: startTime, end: endTime)

        let outputPath = NSTemporaryDirectory() + "moodfilm_trim_\(Int(Date().timeIntervalSince1970)).mp4"
        let outputURL  = URL(fileURLWithPath: outputPath)
        try? FileManager.default.removeItem(at: outputURL)

        guard let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetHighestQuality) else {
            result(FlutterError(code: "EXPORT_FAILED", message: "AVAssetExportSession 생성 실패", details: nil))
            return
        }

        exportSession.outputURL      = outputURL
        exportSession.outputFileType = .mp4
        exportSession.timeRange      = timeRange

        exportSession.exportAsynchronously {
            guard exportSession.status == .completed else {
                DispatchQueue.main.async {
                    result(FlutterError(code: "EXPORT_FAILED",
                                        message: exportSession.error?.localizedDescription ?? "트림 실패",
                                        details: nil))
                }
                return
            }

            guard saveToGallery else {
                DispatchQueue.main.async { result(outputPath) }
                return
            }

            PHPhotoLibrary.requestAuthorization { status in
                guard status == .authorized || status == .limited else {
                    DispatchQueue.main.async { result(outputPath) }
                    return
                }
                PHPhotoLibrary.shared().performChanges({
                    PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: outputURL)
                }) { _, _ in
                    DispatchQueue.main.async { result(outputPath) }
                }
            }
        }
    }

    // MARK: - generateThumbnail

    private func handleGenerateThumbnail(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let sourcePath = args["sourcePath"] as? String,
              let lutFile = args["lutFile"] as? String else {
            result(FlutterError(code: "INVALID_ARGS", message: "sourcePath, lutFile 필요", details: nil))
            return
        }

        let size = args["size"] as? Int ?? 120

        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self = self else { return }

            guard let bytes = self.generateThumbnail(
                sourcePath: sourcePath,
                lutFile: lutFile,
                size: size
            ) else {
                DispatchQueue.main.async {
                    result(FlutterError(code: "THUMBNAIL_FAILED", message: "썸네일 생성 실패", details: nil))
                }
                return
            }

            DispatchQueue.main.async { result(bytes) }
        }
    }

    private func generateThumbnail(sourcePath: String, lutFile: String, size: Int) -> FlutterStandardTypedData? {
        guard let uiImage = UIImage(contentsOfFile: sourcePath) else { return nil }

        // 썸네일 크기로 리사이즈
        let scale = CGFloat(size) / max(uiImage.size.width, uiImage.size.height)
        let thumbSize = CGSize(
            width: uiImage.size.width * scale,
            height: uiImage.size.height * scale
        )
        UIGraphicsBeginImageContextWithOptions(thumbSize, false, 1.0)
        uiImage.draw(in: CGRect(origin: .zero, size: thumbSize))
        let thumbImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        let thumbOptions: [CIImageOption: Any] = [.colorSpace: CGColorSpace(name: CGColorSpace.sRGB)!]
        guard let thumb = thumbImage, var ciImage = CIImage(image: thumb, options: thumbOptions) else { return nil }

        // LUT 적용
        lutEngine.loadLUT(named: lutFile)
        lutEngine.intensity = 1.0
        lutEngine.glowIntensity = 0
        lutEngine.grainIntensity = 0
        ciImage = lutEngine.apply(to: ciImage)

        guard let cgImage = MFLUTEngine.ciContext.createCGImage(ciImage, from: ciImage.extent) else {
            return nil
        }

        let resultImage = UIImage(cgImage: cgImage)
        guard let jpegData = resultImage.jpegData(compressionQuality: 0.8) else { return nil }

        return FlutterStandardTypedData(bytes: jpegData)
    }

    // MARK: - extractVideoFrame

    private func handleExtractVideoFrame(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let sourcePath = args["sourcePath"] as? String else {
            result(FlutterError(code: "INVALID_ARGS", message: "sourcePath 필요", details: nil))
            return
        }

        DispatchQueue.global(qos: .userInitiated).async {
            let url = URL(fileURLWithPath: sourcePath)
            let asset = AVURLAsset(url: url)
            let generator = AVAssetImageGenerator(asset: asset)
            generator.appliesPreferredTrackTransform = true
            generator.maximumSize = CGSize(width: 1080, height: 1920)

            do {
                let cgImage = try generator.copyCGImage(at: .zero, actualTime: nil)
                let uiImage = UIImage(cgImage: cgImage)
                guard let data = uiImage.jpegData(compressionQuality: 0.92) else {
                    DispatchQueue.main.async { result(nil) }
                    return
                }
                let outputPath = NSTemporaryDirectory() + "vframe_\(Int(Date().timeIntervalSince1970)).jpg"
                try data.write(to: URL(fileURLWithPath: outputPath))
                DispatchQueue.main.async { result(outputPath) }
            } catch {
                DispatchQueue.main.async { result(nil) }
            }
        }
    }
}
