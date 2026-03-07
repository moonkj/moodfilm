import Flutter
import UIKit
import CoreImage
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
        case "generateThumbnail":
            handleGenerateThumbnail(call: call, result: result)
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

        let hasEffect = (intensity > 0 && !lutFile.isEmpty)
            || lutEngine.glowIntensity > 0
            || lutEngine.grainIntensity > 0
            || lutEngine.beautyIntensity > 0
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

        // Exposure (CIExposureAdjust)
        if let ev = adjustments["exposure"], ev != 0 {
            if let filter = CIFilter(name: "CIExposureAdjust") {
                filter.setValue(result, forKey: kCIInputImageKey)
                filter.setValue(ev, forKey: kCIInputEVKey)
                result = filter.outputImage ?? result
            }
        }

        // Contrast + Saturation (CIColorControls)
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

        // Warmth (CITemperatureAndTint) — warmth 값을 온도 오프셋으로 변환
        if let warmth = adjustments["warmth"], warmth != 0 {
            if let filter = CIFilter(name: "CITemperatureAndTint") {
                filter.setValue(result, forKey: kCIInputImageKey)
                // neutral = CIVector(x: 6500 + warmth*1500, y: 0)
                let temp = 6500.0 + warmth * 1500.0
                filter.setValue(CIVector(x: temp, y: 0), forKey: "inputNeutral")
                filter.setValue(CIVector(x: 6500, y: 0), forKey: "inputTargetNeutral")
                result = filter.outputImage ?? result
            }
        }

        // Fade (밝기 + 알파 블렌드로 구현)
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
}
