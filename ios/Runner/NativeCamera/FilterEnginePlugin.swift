import Flutter
import UIKit
import CoreImage
import AVFoundation
import Photos

/// 갤러리 이미지 필터 처리 플러그인
/// Full-resolution 이미지에 LUT + CIFilter 조정값 적용 후 저장
class FilterEnginePlugin: NSObject, FlutterPlugin {

    private let lutEngine = MFLUTEngine()

    static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(
            name: "com.moodfilm/filter_engine",
            binaryMessenger: registrar.messenger()
        )
        let instance = FilterEnginePlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "processImage":
            handleProcessImage(call: call, result: result)
        case "processVideo":
            handleProcessVideo(call: call, result: result)
        case "generateThumbnail":
            handleGenerateThumbnail(call: call, result: result)
        case "extractVideoFrame":
            handleExtractVideoFrame(call: call, result: result)
        default:
            result(FlutterMethodNotImplemented)
        }
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

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            guard let outputPath = self.processImage(
                sourcePath: sourcePath,
                lutFile: lutFile,
                intensity: Float(intensity),
                adjustments: adjustments,
                effects: effects
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
        effects: [String: Double]
    ) -> String? {
        guard let uiImage = UIImage(contentsOfFile: sourcePath) else { return nil }
        // Device RGB로 고정 — 카메라 CVPixelBuffer 파이프라인과 컬러 스페이스 통일
        let ciOptions: [CIImageOption: Any] = [.colorSpace: CGColorSpaceCreateDeviceRGB()]
        guard var ciImage = CIImage(image: uiImage, options: ciOptions) else { return nil }

        // 1. 조정값 적용 (CIFilters)
        ciImage = applyAdjustments(to: ciImage, adjustments: adjustments)

        // 2. LUT 필터 + 이펙트 적용 (빈 lutFile = 필터 없음)
        if !lutFile.isEmpty {
            lutEngine.loadLUT(named: lutFile)
            lutEngine.intensity = intensity
        } else {
            lutEngine.intensity = 0.0
        }
        lutEngine.glowIntensity = Float(effects["dreamyGlow"] ?? 0)
        lutEngine.grainIntensity = Float(effects["filmGrain"] ?? 0)
        lutEngine.beautyIntensity = Float(effects["beauty"] ?? 0)
        lutEngine.lightLeakIntensity = Float(effects["lightLeak"] ?? 0)

        let hasEffect = (intensity > 0 && !lutFile.isEmpty)
            || lutEngine.glowIntensity > 0
            || lutEngine.grainIntensity > 0
            || lutEngine.beautyIntensity > 0
            || lutEngine.lightLeakIntensity > 0
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

        let outputImage = UIImage(cgImage: cgImage, scale: uiImage.scale, orientation: uiImage.imageOrientation)
        guard let jpegData = outputImage.jpegData(compressionQuality: 0.95) else { return nil }

        let outputPath = NSTemporaryDirectory() + "moodfilm_\(Int(Date().timeIntervalSince1970)).jpg"
        do {
            try jpegData.write(to: URL(fileURLWithPath: outputPath))
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

        let thumbOptions: [CIImageOption: Any] = [.colorSpace: CGColorSpaceCreateDeviceRGB()]
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

    // MARK: - 조정값 CIFilter 파이프라인

    private func applyAdjustments(to image: CIImage, adjustments: [String: Double]) -> CIImage {
        var result = image
        let extent = image.extent

        // 1. Exposure (CIExposureAdjust)
        if let ev = adjustments["exposure"], ev != 0 {
            if let filter = CIFilter(name: "CIExposureAdjust") {
                filter.setValue(result, forKey: kCIInputImageKey)
                filter.setValue(ev * 2.0, forKey: kCIInputEVKey)
                result = filter.outputImage ?? result
            }
        }

        // 2. Highlights + Shadows (CIHighlightShadowAdjust)
        let highlights = adjustments["highlights"] ?? 0
        let shadows = adjustments["shadows"] ?? 0
        if highlights != 0 || shadows != 0 {
            if let filter = CIFilter(name: "CIHighlightShadowAdjust") {
                filter.setValue(result, forKey: kCIInputImageKey)
                // inputHighlightAmount: 0~2, default 1.0 (낮을수록 하이라이트 복구)
                filter.setValue(1.0 + Float(highlights) * 0.7, forKey: "inputHighlightAmount")
                // inputShadowAmount: -1~1, default 0 (양수 = 그림자 밝히기)
                filter.setValue(Float(shadows) * 0.7, forKey: "inputShadowAmount")
                result = filter.outputImage ?? result
            }
        }

        // 3. Contrast + Saturation (CIColorControls)
        let contrast = adjustments["contrast"] ?? 0
        let saturation = adjustments["saturation"] ?? 0
        if contrast != 0 || saturation != 0 {
            if let filter = CIFilter(name: "CIColorControls") {
                filter.setValue(result, forKey: kCIInputImageKey)
                filter.setValue(1.0 + contrast, forKey: kCIInputContrastKey)
                filter.setValue(1.0 + saturation, forKey: kCIInputSaturationKey)
                result = filter.outputImage ?? result
            }
        }

        // 4. Temperature + Tint (CITemperatureAndTint)
        // "temperature" 키 우선, 없으면 이전 "warmth" 키 호환
        let temperature = adjustments["temperature"] ?? adjustments["warmth"] ?? 0
        let tint = adjustments["tint"] ?? 0
        if temperature != 0 || tint != 0 {
            if let filter = CIFilter(name: "CITemperatureAndTint") {
                filter.setValue(result, forKey: kCIInputImageKey)
                let temp = 6500.0 + temperature * 1500.0
                filter.setValue(CIVector(x: temp, y: 0), forKey: "inputNeutral")
                filter.setValue(CIVector(x: 6500.0, y: tint * 50.0), forKey: "inputTargetNeutral")
                result = filter.outputImage ?? result
            }
        }

        // 5. Skin Tone — CIHueAdjust: 피부 오렌지/핑크 계열 미세 보정
        if let skinTone = adjustments["skinTone"], skinTone != 0 {
            if let filter = CIFilter(name: "CIHueAdjust") {
                filter.setValue(result, forKey: kCIInputImageKey)
                filter.setValue(Float(skinTone) * 0.15, forKey: kCIInputAngleKey)
                result = filter.outputImage ?? result
            }
        }

        // 6. Sharpness / Blur (양수=선명, 음수=흐림)
        if let sharpness = adjustments["sharpness"], sharpness != 0 {
            if sharpness > 0 {
                if let filter = CIFilter(name: "CISharpenLuminance") {
                    filter.setValue(result, forKey: kCIInputImageKey)
                    filter.setValue(Float(sharpness) * 1.5, forKey: kCIInputSharpnessKey)
                    result = filter.outputImage?.cropped(to: extent) ?? result
                }
            } else {
                if let filter = CIFilter(name: "CIGaussianBlur") {
                    filter.setValue(result, forKey: kCIInputImageKey)
                    filter.setValue(Float(-sharpness) * 4.0, forKey: kCIInputRadiusKey)
                    result = filter.outputImage?.cropped(to: extent) ?? result
                }
            }
        }

        // 7. Vignette (CIVignette)
        if let vignette = adjustments["vignette"], vignette > 0 {
            if let filter = CIFilter(name: "CIVignette") {
                filter.setValue(result, forKey: kCIInputImageKey)
                filter.setValue(Float(vignette) * 2.0, forKey: kCIInputIntensityKey)
                filter.setValue(Float(1.0 - vignette * 0.3), forKey: kCIInputRadiusKey)
                result = filter.outputImage ?? result
            }
        }

        // 8. Fade (CIColorMatrix — 밝기 압축으로 페이드 효과)
        if let fade = adjustments["fade"], fade > 0 {
            if let filter = CIFilter(name: "CIColorMatrix") {
                filter.setValue(result, forKey: kCIInputImageKey)
                let f = CGFloat(fade * 0.3)
                filter.setValue(CIVector(x: 1-f, y: 0, z: 0, w: 0), forKey: "inputRVector")
                filter.setValue(CIVector(x: 0, y: 1-f, z: 0, w: 0), forKey: "inputGVector")
                filter.setValue(CIVector(x: 0, y: 0, z: 1-f, w: 0), forKey: "inputBVector")
                filter.setValue(CIVector(x: f, y: f, z: f, w: 0), forKey: "inputBiasVector")
                result = filter.outputImage ?? result
            }
        }

        return result
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
