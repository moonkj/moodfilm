import CoreImage
import UIKit

/// LUT(.cube) 기반 CIColorCube 필터 엔진
/// 싱글톤 CIContext로 GPU 파이프라인 관리
class MFLUTEngine {

    // MARK: - 싱글톤 CIContext (생성 비용이 높으므로 앱 전체 공유)
    static let ciContext: CIContext = {
        guard let device = MTLCreateSystemDefaultDevice() else {
            return CIContext()
        }
        let sRGB = CGColorSpace(name: CGColorSpace.sRGB)!
        return CIContext(
            mtlDevice: device,
            options: [
                .workingColorSpace: sRGB,
                .outputColorSpace: sRGB,
                .useSoftwareRenderer: false,
            ]
        )
    }()

    // MARK: - LUT 캐시 (최대 8개 — 즐겨찾기 + 최근 사용)
    private var lutCache = NSCache<NSString, CIFilter>()
    private var currentLUTFilter: CIFilter?
    private var currentLUTName: String = "" // 필터별 개성 보정에 사용
    var intensity: Float = 1.0

    // MARK: - 현재 이펙트 강도
    var glowIntensity: Float = 0.0
    var grainIntensity: Float = 0.0
    var beautyIntensity: Float = 0.0
    var lightLeakIntensity: Float = 0.0
    var softnessIntensity: Float = 0.0
    var brightnessIntensity: Float = 0.0  // -1.0 ~ 1.0
    var contrastIntensity: Float = 0.0    // -1.0 ~ 1.0
    var saturationIntensity: Float = 0.0  // -1.0 ~ 1.0

    // MARK: - Before/After 스플릿 (splitPosition < 0 = 비활성)
    var splitPosition: Float = -1.0
    var isFrontCamera: Bool = false

    /// LUT 필터가 실제로 로드되어 있는지 여부
    var hasLUT: Bool { return currentLUTFilter != nil }

    init() {
        lutCache.countLimit = 8
    }

    // MARK: - LUT 로딩

    /// .cube 파일을 로드하여 CIColorCubeWithColorSpace 필터 생성
    func loadLUT(named lutFileName: String) {
        currentLUTName = (lutFileName as NSString).deletingPathExtension
        let cacheKey = NSString(string: lutFileName)

        // 캐시 히트
        if let cached = lutCache.object(forKey: cacheKey) {
            currentLUTFilter = cached
            return
        }

        // Flutter 에셋은 App.framework/flutter_assets/ 에 위치 (Flutter 임베딩 구조)
        let resourceName = (lutFileName as NSString).deletingPathExtension
        let appFrameworkBundle = Bundle(url: Bundle.main.bundleURL
            .appendingPathComponent("Frameworks/App.framework"))
        let resolvedURL = appFrameworkBundle?.url(forResource: resourceName, withExtension: "cube",
                                                   subdirectory: "flutter_assets/assets/luts")
            ?? Bundle.main.url(forResource: resourceName, withExtension: "cube",
                               subdirectory: "flutter_assets/assets/luts")
            ?? Bundle.main.url(forResource: resourceName, withExtension: "cube",
                               subdirectory: "luts")
        guard let url = resolvedURL, let filter = buildLUTFilter(from: url) else {
            print("[MFLUTEngine] LUT 파일 로드 실패: \(lutFileName)")
            currentLUTFilter = nil
            return
        }

        lutCache.setObject(filter, forKey: cacheKey)
        currentLUTFilter = filter
    }

    /// .cube 파일 파싱 → CIColorCubeWithColorSpace 필터 생성
    private func buildLUTFilter(from url: URL) -> CIFilter? {
        guard let fileContent = try? String(contentsOf: url, encoding: .utf8) else { return nil }

        var size = 0
        var cubeData: [Float] = []

        for line in fileContent.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("#") || trimmed.isEmpty { continue }

            if trimmed.hasPrefix("LUT_3D_SIZE") {
                let parts = trimmed.components(separatedBy: " ")
                size = Int(parts.last ?? "0") ?? 0
                cubeData.reserveCapacity(size * size * size * 4)
                continue
            }

            let values = trimmed.components(separatedBy: " ").compactMap { Float($0) }
            if values.count >= 3 {
                cubeData.append(values[0]) // R
                cubeData.append(values[1]) // G
                cubeData.append(values[2]) // B
                cubeData.append(1.0)       // A
            }
        }

        guard size > 0, cubeData.count == size * size * size * 4 else { return nil }

        let cubeDataCount = size * size * size * 4
        var floatData = cubeData
        let data = Data(bytes: &floatData, count: cubeDataCount * MemoryLayout<Float>.size)

        let filter = CIFilter(name: "CIColorCubeWithColorSpace")
        filter?.setValue(size, forKey: "inputCubeDimension")
        filter?.setValue(data as AnyObject, forKey: "inputCubeData")
        filter?.setValue(CGColorSpace(name: CGColorSpace.sRGB)!, forKey: "inputColorSpace")

        return filter
    }

    // MARK: - 필터 파이프라인 적용

    /// CIImage에 현재 LUT + 이펙트 파이프라인 적용
    func apply(to image: CIImage) -> CIImage {
        var result = image
        let originalExtent = image.extent  // 원본 extent 저장 — 마지막에 크롭 기준으로 사용

        // 1. LUT 필터 적용 (강도 블렌딩) + 채도/대비 부스트
        // LUT 적용 + 필터 개성 보정 → 강도 블렌딩 순서 (개성이 intensity에 비례하도록)
        if let lutFilter = currentLUTFilter, intensity > 0 {
            let base = result
            lutFilter.setValue(base, forKey: kCIInputImageKey)
            if let filtered = lutFilter.outputImage {
                // 개성 보정을 먼저 LUT 이미지에 적용 (blend 전)
                let filteredWithPersonality = applyFilterPersonality(to: filtered, extent: filtered.extent)

                // 그 다음 intensity로 blend → 개성 효과도 intensity에 비례
                result = intensity >= 1.0
                    ? filteredWithPersonality
                    : lerpCI(fg: filteredWithPersonality, bg: base, alpha: CGFloat(intensity))

                // 미세 부스트 (LUT 고유 색감 보존 — intensity에 비례)
                let boost = CGFloat(min(intensity, 1.0))
                if boost > 0, let vivid = CIFilter(name: "CIColorControls") {
                    vivid.setValue(result, forKey: kCIInputImageKey)
                    vivid.setValue(1.0 + boost * 0.08, forKey: kCIInputContrastKey)
                    vivid.setValue(1.0 + boost * 0.10, forKey: kCIInputSaturationKey)
                    result = vivid.outputImage?.cropped(to: result.extent) ?? result
                }
            }
        }

        // 2. 색보정 조정 (brightness / contrast / saturation)
        let hasColorAdjust = brightnessIntensity != 0 || contrastIntensity != 0 || saturationIntensity != 0
        if hasColorAdjust, let colorFilter = CIFilter(name: "CIColorControls") {
            colorFilter.setValue(result, forKey: kCIInputImageKey)
            // brightness: -1~1 → CIColorControls range: -1~1
            colorFilter.setValue(CGFloat(brightnessIntensity * 0.5), forKey: kCIInputBrightnessKey)
            // contrast: -1~1 → CIColorControls range: 0~4 (1 = 기본)
            colorFilter.setValue(1.0 + CGFloat(contrastIntensity), forKey: kCIInputContrastKey)
            // saturation: -1~1 → CIColorControls range: 0~2 (1 = 기본)
            colorFilter.setValue(1.0 + CGFloat(saturationIntensity), forKey: kCIInputSaturationKey)
            result = colorFilter.outputImage?.cropped(to: result.extent) ?? result
        }

        // 3. Softness (솜결) — 부드러운 피부 소프트닝
        if softnessIntensity > 0 {
            result = applySoftness(to: result, intensity: softnessIntensity)
        }

        // 4. Dreamy Glow 이펙트 (시그니처)
        if glowIntensity > 0 {
            result = applyDreamyGlow(to: result, intensity: glowIntensity)
        }

        // 5. Film Grain
        if grainIntensity > 0 {
            result = applyFilmGrain(to: result, intensity: grainIntensity)
        }

        // 6. Beauty (뽀샤시)
        if beautyIntensity > 0 {
            result = applyBeauty(to: result, intensity: beautyIntensity)
        }

        // 7. Light Leak
        if lightLeakIntensity > 0 {
            result = applyLightLeak(to: result, intensity: lightLeakIntensity)
        }

        // 8. Before/After 스플릿
        if splitPosition >= 0 {
            result = applyBeforeAfterSplit(original: image, filtered: result,
                                           position: CGFloat(splitPosition))
        }

        // 최종 안전장치: 어떤 이펙트도 원본 extent 밖으로 번지지 않도록 크롭
        return result.cropped(to: originalExtent)
    }

    // MARK: - 시그니처 이펙트: Dreamy Glow
    // CIBloom + Gaussian Blur 조합으로 사진 전체에 몽환적인 빛번짐

    private func applyDreamyGlow(to image: CIImage, intensity: Float) -> CIImage {
        // 지수 곡선 적용: 낮은 값에서 부드럽게, 1.0에서 최대
        // pow(x, 1.5): 0.3→0.16, 0.5→0.35, 0.7→0.59, 1.0→1.0
        let eased = pow(intensity, 1.5)

        guard let bloomFilter = CIFilter(name: "CIBloom") else { return image }
        bloomFilter.setValue(image, forKey: kCIInputImageKey)
        bloomFilter.setValue(eased * 14.0, forKey: kCIInputRadiusKey)
        bloomFilter.setValue(eased * 0.75, forKey: kCIInputIntensityKey)

        guard let bloomed = bloomFilter.outputImage else { return image }

        // Gaussian Blur로 부드러운 빛번짐 강화
        guard let blurFilter = CIFilter(name: "CIGaussianBlur") else { return bloomed }
        blurFilter.setValue(bloomed, forKey: kCIInputImageKey)
        blurFilter.setValue(eased * 2.5, forKey: kCIInputRadiusKey)

        guard let blurred = blurFilter.outputImage else { return bloomed }

        // Overlay blend: glow 레이어를 원본에 합성
        guard let overlayFilter = CIFilter(name: "CIOverlayBlendMode") else { return blurred }
        overlayFilter.setValue(blurred.cropped(to: image.extent), forKey: kCIInputImageKey)
        overlayFilter.setValue(image, forKey: kCIInputBackgroundImageKey)
        guard let glowResult = overlayFilter.outputImage?.cropped(to: image.extent) else { return image }

        // eased 값으로 glow 결과의 알파를 제어 → 원본과 부드럽게 블렌딩
        // CIOverlayBlendMode는 강도 파라미터가 없으므로 CIColorMatrix로 알파 조정 후 SourceOver 합성
        guard let alphaFilter = CIFilter(name: "CIColorMatrix") else { return glowResult }
        alphaFilter.setValue(glowResult, forKey: kCIInputImageKey)
        alphaFilter.setValue(CIVector(x: 1, y: 0, z: 0, w: 0), forKey: "inputRVector")
        alphaFilter.setValue(CIVector(x: 0, y: 1, z: 0, w: 0), forKey: "inputGVector")
        alphaFilter.setValue(CIVector(x: 0, y: 0, z: 1, w: 0), forKey: "inputBVector")
        alphaFilter.setValue(CIVector(x: 0, y: 0, z: 0, w: CGFloat(eased)), forKey: "inputAVector")
        guard let fadedGlow = alphaFilter.outputImage else { return glowResult }

        guard let composite = CIFilter(name: "CISourceOverCompositing") else { return glowResult }
        composite.setValue(fadedGlow, forKey: kCIInputImageKey)
        composite.setValue(image, forKey: kCIInputBackgroundImageKey)
        return composite.outputImage?.cropped(to: image.extent) ?? glowResult
    }

    // MARK: - Film Grain 이펙트

    private func applyFilmGrain(to image: CIImage, intensity: Float) -> CIImage {
        guard let noiseFilter = CIFilter(name: "CIRandomGenerator"),
              let noiseImage = noiseFilter.outputImage else { return image }

        // 노이즈 크기와 위치 조정
        let scaledNoise = noiseImage
            .transformed(by: CGAffineTransform(scaleX: 1.5, y: 1.5))
            .cropped(to: image.extent)

        // 모노크롬 변환
        guard let monoFilter = CIFilter(name: "CIColorMatrix") else { return image }
        monoFilter.setValue(scaledNoise, forKey: kCIInputImageKey)
        monoFilter.setValue(CIVector(x: 0.33, y: 0.33, z: 0.33, w: 0), forKey: "inputRVector")
        monoFilter.setValue(CIVector(x: 0.33, y: 0.33, z: 0.33, w: 0), forKey: "inputGVector")
        monoFilter.setValue(CIVector(x: 0.33, y: 0.33, z: 0.33, w: 0), forKey: "inputBVector")
        monoFilter.setValue(CIVector(x: 0, y: 0, z: 0, w: CGFloat(intensity * 0.4)), forKey: "inputAVector")

        guard let grain = monoFilter.outputImage else { return image }

        // Soft Light blend
        guard let blendFilter = CIFilter(name: "CISoftLightBlendMode") else { return image }
        blendFilter.setValue(grain, forKey: kCIInputImageKey)
        blendFilter.setValue(image, forKey: kCIInputBackgroundImageKey)

        return blendFilter.outputImage?.cropped(to: image.extent) ?? image
    }

    // MARK: - Softness (솜결) 이펙트
    // 원본과 블러를 블렌딩해 피부를 부드럽게 — Beauty보다 자연스러운 소프트닝

    private func applySoftness(to image: CIImage, intensity: Float) -> CIImage {
        guard let blurFilter = CIFilter(name: "CIGaussianBlur") else { return image }
        // clampedToExtent(): 경계 바깥을 투명(검정)이 아닌 가장자리 픽셀로 채워 검은 테두리 방지
        blurFilter.setValue(image.clampedToExtent(), forKey: kCIInputImageKey)
        blurFilter.setValue(intensity * 10.0, forKey: kCIInputRadiusKey)  // radius: 최대 10
        guard let blurred = blurFilter.outputImage?.cropped(to: image.extent) else { return image }

        // 원본과 블러를 alpha로 블렌딩 (intensity * 0.75 비율)
        guard let alphaFilter = CIFilter(name: "CIColorMatrix"),
              let composite = CIFilter(name: "CISourceOverCompositing") else { return image }
        alphaFilter.setValue(blurred, forKey: kCIInputImageKey)
        alphaFilter.setValue(CIVector(x: 1, y: 0, z: 0, w: 0), forKey: "inputRVector")
        alphaFilter.setValue(CIVector(x: 0, y: 1, z: 0, w: 0), forKey: "inputGVector")
        alphaFilter.setValue(CIVector(x: 0, y: 0, z: 1, w: 0), forKey: "inputBVector")
        alphaFilter.setValue(CIVector(x: 0, y: 0, z: 0, w: CGFloat(intensity * 0.75)), forKey: "inputAVector")
        guard let semiBlur = alphaFilter.outputImage else { return image }
        composite.setValue(semiBlur, forKey: kCIInputImageKey)
        composite.setValue(image, forKey: kCIInputBackgroundImageKey)
        return composite.outputImage?.cropped(to: image.extent) ?? image
    }

    // MARK: - Beauty (뽀샤시) 이펙트
    // 피부 보정: 부드럽게 + 밝게 + 따뜻하게 + 은은한 빛번짐

    private func applyBeauty(to image: CIImage, intensity: Float) -> CIImage {
        var result = image

        // 1. 피부 소프트닝: Gaussian Blur를 원본과 부드럽게 블렌딩
        if let blurFilter = CIFilter(name: "CIGaussianBlur"),
           let blendFilter = CIFilter(name: "CISoftLightBlendMode") {
            blurFilter.setValue(result.clampedToExtent(), forKey: kCIInputImageKey)
            blurFilter.setValue(intensity * 7.0, forKey: kCIInputRadiusKey)
            if let blurred = blurFilter.outputImage?.cropped(to: image.extent) {
                // 소프트 라이트로 원본과 블렌딩
                if let alphaFilter = CIFilter(name: "CIColorMatrix"),
                   let composite = CIFilter(name: "CISourceOverCompositing") {
                    alphaFilter.setValue(blurred, forKey: kCIInputImageKey)
                    alphaFilter.setValue(CIVector(x: 1, y: 0, z: 0, w: 0), forKey: "inputRVector")
                    alphaFilter.setValue(CIVector(x: 0, y: 1, z: 0, w: 0), forKey: "inputGVector")
                    alphaFilter.setValue(CIVector(x: 0, y: 0, z: 1, w: 0), forKey: "inputBVector")
                    alphaFilter.setValue(CIVector(x: 0, y: 0, z: 0, w: CGFloat(intensity * 0.65)), forKey: "inputAVector")
                    if let semiBlur = alphaFilter.outputImage {
                        composite.setValue(semiBlur, forKey: kCIInputImageKey)
                        composite.setValue(result, forKey: kCIInputBackgroundImageKey)
                        result = composite.outputImage?.cropped(to: image.extent) ?? result
                    }
                }
            }
        }

        // 2. 밝기 + 채도 미세 보정 (CIColorControls)
        if let colorFilter = CIFilter(name: "CIColorControls") {
            colorFilter.setValue(result, forKey: kCIInputImageKey)
            colorFilter.setValue(CGFloat(intensity) * 0.16, forKey: kCIInputBrightnessKey)
            colorFilter.setValue(1.0 + CGFloat(intensity) * 0.06, forKey: kCIInputSaturationKey)
            result = colorFilter.outputImage?.cropped(to: image.extent) ?? result
        }

        // 3. 따뜻한 피부톤 (CITemperatureAndTint)
        // inputNeutral=중립(6500K), inputTargetNeutral=목표 색온도(더 높을수록 따뜻하게)
        if let tempFilter = CIFilter(name: "CITemperatureAndTint") {
            tempFilter.setValue(result, forKey: kCIInputImageKey)
            tempFilter.setValue(CIVector(x: 6500, y: 0), forKey: "inputNeutral")
            tempFilter.setValue(CIVector(x: 6500.0 + CGFloat(intensity) * 600.0, y: 0), forKey: "inputTargetNeutral")
            result = tempFilter.outputImage?.cropped(to: image.extent) ?? result
        }

        // 4. 은은한 Bloom (뽀샤시 발광)
        if let bloomFilter = CIFilter(name: "CIBloom") {
            bloomFilter.setValue(result, forKey: kCIInputImageKey)
            bloomFilter.setValue(intensity * 6.0, forKey: kCIInputRadiusKey)
            bloomFilter.setValue(intensity * 0.4, forKey: kCIInputIntensityKey)
            result = bloomFilter.outputImage?.cropped(to: image.extent) ?? result
        }

        return result
    }

    // MARK: - Light Leak 이펙트
    // 필름 카메라 빛번짐: 모서리에 따뜻한 주황/노랑 빛 오버레이 (Screen blend)

    private func applyLightLeak(to image: CIImage, intensity: Float) -> CIImage {
        let extent = image.extent
        let w = extent.width
        let h = extent.height

        // 좌상단 큰 원형 그라디언트 (주황빛)
        guard let grad1 = CIFilter(name: "CIRadialGradient") else { return image }
        let radius1 = w * 0.55
        grad1.setValue(CIVector(x: extent.minX + w * 0.1, y: extent.maxY - h * 0.1), forKey: "inputCenter")
        grad1.setValue(radius1 * 0.3, forKey: "inputRadius0")
        grad1.setValue(radius1, forKey: "inputRadius1")
        grad1.setValue(CIColor(red: 1.0, green: 0.68, blue: 0.25, alpha: CGFloat(intensity) * 0.65), forKey: "inputColor0")
        grad1.setValue(CIColor(red: 1.0, green: 0.68, blue: 0.25, alpha: 0.0), forKey: "inputColor1")
        guard let leak1 = grad1.outputImage?.cropped(to: extent) else { return image }

        // 우하단 작은 원형 그라디언트 (노랑빛)
        guard let grad2 = CIFilter(name: "CIRadialGradient") else { return image }
        let radius2 = w * 0.35
        grad2.setValue(CIVector(x: extent.maxX - w * 0.08, y: extent.minY + h * 0.12), forKey: "inputCenter")
        grad2.setValue(radius2 * 0.2, forKey: "inputRadius0")
        grad2.setValue(radius2, forKey: "inputRadius1")
        grad2.setValue(CIColor(red: 1.0, green: 0.85, blue: 0.35, alpha: CGFloat(intensity) * 0.45), forKey: "inputColor0")
        grad2.setValue(CIColor(red: 1.0, green: 0.85, blue: 0.35, alpha: 0.0), forKey: "inputColor1")
        guard let leak2 = grad2.outputImage?.cropped(to: extent) else { return image }

        // 두 그라디언트 합성
        guard let addComp = CIFilter(name: "CIAdditionCompositing") else { return image }
        addComp.setValue(leak1, forKey: kCIInputImageKey)
        addComp.setValue(leak2, forKey: kCIInputBackgroundImageKey)
        guard let leakLayer = addComp.outputImage?.cropped(to: extent) else { return image }

        // Screen blend로 이미지 위에 빛번짐 적용
        guard let screen = CIFilter(name: "CIScreenBlendMode") else { return image }
        screen.setValue(leakLayer, forKey: kCIInputImageKey)
        screen.setValue(image, forKey: kCIInputBackgroundImageKey)
        return screen.outputImage?.cropped(to: extent) ?? image
    }

    // MARK: - Before/After 스플릿 합성
    // Flutter에서 BoxFit.cover 크롭 보정된 nativePos(0~1)를 받음
    // back  카메라: RotatedBox(CW90°) → 버퍼 저Y=display 우, 고Y=display 좌
    //               nativePos = 1 - display_x → splitY = H * nativePos
    //               display 왼쪽(원본) = 고Y 영역 [splitY, maxY)
    //               display 오른쪽(필터) = 저Y 영역 [minY, splitY)
    // front 카메라: RotatedBox + scale(-1,1) → 버퍼 저Y=display 좌, 고Y=display 우
    //               nativePos = display_x → splitY = H * nativePos
    //               display 왼쪽(원본) = 저Y 영역 [minY, splitY)
    //               display 오른쪽(필터) = 고Y 영역 [splitY, maxY)

    private func applyBeforeAfterSplit(original: CIImage, filtered: CIImage,
                                       position: CGFloat) -> CIImage {
        let extent = original.extent
        let splitY = extent.minY + extent.height * position

        let originalPart: CIImage
        let filteredPart: CIImage

        if isFrontCamera {
            // front: RotatedBox(CW90°) + scale(-1,1) 미러
            // 저Y→회전후LEFT→미러후RIGHT(필터), 고Y→회전후RIGHT→미러후LEFT(원본)
            originalPart = original.cropped(to: CGRect(
                x: extent.minX, y: splitY,
                width: extent.width, height: extent.maxY - splitY))
            filteredPart = filtered.cropped(to: CGRect(
                x: extent.minX, y: extent.minY,
                width: extent.width, height: splitY - extent.minY))
        } else {
            // back: RotatedBox(CW90°)
            // 저Y→회전후LEFT(원본), 고Y→회전후RIGHT(필터)
            originalPart = original.cropped(to: CGRect(
                x: extent.minX, y: extent.minY,
                width: extent.width, height: splitY - extent.minY))
            filteredPart = filtered.cropped(to: CGRect(
                x: extent.minX, y: splitY,
                width: extent.width, height: extent.maxY - splitY))
        }

        guard let composite = CIFilter(name: "CISourceOverCompositing") else { return filtered }
        composite.setValue(originalPart, forKey: kCIInputImageKey)
        composite.setValue(filteredPart, forKey: kCIInputBackgroundImageKey)
        return composite.outputImage?.cropped(to: extent) ?? filtered
    }

    // MARK: - 정지 이미지 조정값 파이프라인 (FilterEnginePlugin + MFImagePreviewRenderer 공유)

    /// CIFilter 조정값을 이미지에 적용 (exposure / highlights / shadows / contrast / saturation /
    /// temperature / tint / skinTone / sharpness / vignette / fade)
    static func applyAdjustments(to image: CIImage, adjustments: [String: Double]) -> CIImage {
        var result = image
        let extent = image.extent

        if let ev = adjustments["exposure"], ev != 0 {
            if let f = CIFilter(name: "CIExposureAdjust") {
                f.setValue(result, forKey: kCIInputImageKey)
                f.setValue(ev * 2.0, forKey: kCIInputEVKey)
                result = f.outputImage ?? result
            }
        }

        let highlights = adjustments["highlights"] ?? 0
        let shadows    = adjustments["shadows"]    ?? 0
        if highlights != 0 || shadows != 0 {
            if let f = CIFilter(name: "CIHighlightShadowAdjust") {
                f.setValue(result, forKey: kCIInputImageKey)
                f.setValue(1.0 + Float(highlights) * 0.7, forKey: "inputHighlightAmount")
                f.setValue(Float(shadows) * 0.7,          forKey: "inputShadowAmount")
                result = f.outputImage ?? result
            }
        }

        let contrast   = adjustments["contrast"]   ?? 0
        let saturation = adjustments["saturation"] ?? 0
        if contrast != 0 || saturation != 0 {
            if let f = CIFilter(name: "CIColorControls") {
                f.setValue(result, forKey: kCIInputImageKey)
                f.setValue(1.0 + contrast,   forKey: kCIInputContrastKey)
                f.setValue(1.0 + saturation, forKey: kCIInputSaturationKey)
                result = f.outputImage ?? result
            }
        }

        let temperature = adjustments["temperature"] ?? adjustments["warmth"] ?? 0
        let tint        = adjustments["tint"]        ?? 0
        if temperature != 0 || tint != 0 {
            if let f = CIFilter(name: "CITemperatureAndTint") {
                f.setValue(result, forKey: kCIInputImageKey)
                let temp = 6500.0 + temperature * 1500.0
                f.setValue(CIVector(x: temp, y: 0),              forKey: "inputNeutral")
                f.setValue(CIVector(x: 6500.0, y: tint * 50.0), forKey: "inputTargetNeutral")
                result = f.outputImage ?? result
            }
        }

        if let skinTone = adjustments["skinTone"], skinTone != 0 {
            if let f = CIFilter(name: "CIHueAdjust") {
                f.setValue(result, forKey: kCIInputImageKey)
                f.setValue(Float(skinTone) * 0.15, forKey: kCIInputAngleKey)
                result = f.outputImage ?? result
            }
        }

        if let sharpness = adjustments["sharpness"], sharpness != 0 {
            if sharpness > 0 {
                if let f = CIFilter(name: "CISharpenLuminance") {
                    f.setValue(result, forKey: kCIInputImageKey)
                    f.setValue(Float(sharpness) * 1.5, forKey: kCIInputSharpnessKey)
                    result = f.outputImage?.cropped(to: extent) ?? result
                }
            } else {
                if let f = CIFilter(name: "CIGaussianBlur") {
                    f.setValue(result, forKey: kCIInputImageKey)
                    f.setValue(Float(-sharpness) * 4.0, forKey: kCIInputRadiusKey)
                    result = f.outputImage?.cropped(to: extent) ?? result
                }
            }
        }

        if let vignette = adjustments["vignette"], vignette > 0 {
            if let f = CIFilter(name: "CIVignette") {
                f.setValue(result, forKey: kCIInputImageKey)
                f.setValue(Float(vignette) * 2.0,       forKey: kCIInputIntensityKey)
                f.setValue(Float(1.0 - vignette * 0.3), forKey: kCIInputRadiusKey)
                result = f.outputImage ?? result
            }
        }

        if let fade = adjustments["fade"], fade > 0 {
            if let f = CIFilter(name: "CIColorMatrix") {
                f.setValue(result, forKey: kCIInputImageKey)
                let fv = CGFloat(fade * 0.3)
                f.setValue(CIVector(x: 1-fv, y: 0,    z: 0,    w: 0), forKey: "inputRVector")
                f.setValue(CIVector(x: 0,    y: 1-fv, z: 0,    w: 0), forKey: "inputGVector")
                f.setValue(CIVector(x: 0,    y: 0,    z: 1-fv, w: 0), forKey: "inputBVector")
                f.setValue(CIVector(x: fv,   y: fv,   z: fv,   w: 0), forKey: "inputBiasVector")
                result = f.outputImage ?? result
            }
        }

        return result
    }

    // MARK: - 내부 블렌딩 유틸

    /// CIImage 두 장을 alpha 비율로 선형 블렌딩 (0=bg, 1=fg)
    private func lerpCI(fg: CIImage, bg: CIImage, alpha: CGFloat) -> CIImage {
        guard alpha > 0 else { return bg }
        guard alpha < 1 else { return fg }
        guard let af = CIFilter(name: "CIColorMatrix"),
              let comp = CIFilter(name: "CISourceOverCompositing") else { return fg }
        af.setValue(fg, forKey: kCIInputImageKey)
        af.setValue(CIVector(x: 1, y: 0, z: 0, w: 0), forKey: "inputRVector")
        af.setValue(CIVector(x: 0, y: 1, z: 0, w: 0), forKey: "inputGVector")
        af.setValue(CIVector(x: 0, y: 0, z: 1, w: 0), forKey: "inputBVector")
        af.setValue(CIVector(x: 0, y: 0, z: 0, w: alpha), forKey: "inputAVector")
        guard let semi = af.outputImage else { return fg }
        comp.setValue(semi, forKey: kCIInputImageKey)
        comp.setValue(bg, forKey: kCIInputBackgroundImageKey)
        return comp.outputImage ?? fg
    }

    // MARK: - 필터별 개성 보정
    // LUT가 약하거나 비슷한 필터들을 코드 레벨에서 차별화

    private func applyFilterPersonality(to image: CIImage, extent: CGRect) -> CIImage {
        var result = image

        // 색보정 헬퍼
        func colorControls(contrast: CGFloat = 1.0, saturation: CGFloat = 1.0, brightness: CGFloat = 0.0) -> CIImage {
            guard let f = CIFilter(name: "CIColorControls") else { return result }
            f.setValue(result, forKey: kCIInputImageKey)
            if contrast != 1.0    { f.setValue(contrast, forKey: kCIInputContrastKey) }
            if saturation != 1.0  { f.setValue(saturation, forKey: kCIInputSaturationKey) }
            if brightness != 0.0  { f.setValue(brightness, forKey: kCIInputBrightnessKey) }
            return f.outputImage?.cropped(to: extent) ?? result
        }

        func temperature(target: CGFloat) -> CIImage {
            guard let f = CIFilter(name: "CITemperatureAndTint") else { return result }
            f.setValue(result, forKey: kCIInputImageKey)
            f.setValue(CIVector(x: 6500, y: 0), forKey: "inputNeutral")
            f.setValue(CIVector(x: target, y: 0), forKey: "inputTargetNeutral")
            return f.outputImage?.cropped(to: extent) ?? result
        }

        func colorMatrix(rScale: CGFloat = 1, gScale: CGFloat = 1, bScale: CGFloat = 1,
                         rBias: CGFloat = 0, gBias: CGFloat = 0, bBias: CGFloat = 0) -> CIImage {
            guard let f = CIFilter(name: "CIColorMatrix") else { return result }
            f.setValue(result, forKey: kCIInputImageKey)
            f.setValue(CIVector(x: rScale, y: 0, z: 0, w: 0), forKey: "inputRVector")
            f.setValue(CIVector(x: 0, y: gScale, z: 0, w: 0), forKey: "inputGVector")
            f.setValue(CIVector(x: 0, y: 0, z: bScale, w: 0), forKey: "inputBVector")
            f.setValue(CIVector(x: rBias, y: gBias, z: bBias, w: 0), forKey: "inputBiasVector")
            return f.outputImage?.cropped(to: extent) ?? result
        }

        switch currentLUTName {

        // ─── Warm 계열 ────────────────────────────────────────────────────
        case "mood":
            // 시그니처: 따뜻한 드리미 필름 — 은은한 온기 + 부드러운 밝음
            result = temperature(target: 7000)
            result = colorControls(contrast: 1.06, saturation: 0.96, brightness: 0.03)

        case "milk":
            // 우유빛: 탈포화 + 밝음 + 살짝 따뜻
            result = colorControls(saturation: 0.82, brightness: 0.06)
            result = temperature(target: 6800)

        case "cream":
            // 크림색 오후: 크리미 웜톤
            result = temperature(target: 7100)
            result = colorMatrix(rBias: 0.012, gBias: 0.008)
            result = colorControls(brightness: 0.03)

        case "butter":
            // 버터 노란빛: 강한 골든 톤
            result = temperature(target: 7400)
            result = colorMatrix(rBias: 0.022, gBias: 0.015, bBias: -0.012)
            result = colorControls(saturation: 1.10)

        case "honey":
            // 골든아워 꿀빛: 앰버 + 채도 + 강도 높음
            result = temperature(target: 7600)
            result = colorMatrix(rBias: 0.028, gBias: 0.012, bBias: -0.018)
            result = colorControls(contrast: 1.06, saturation: 1.15)

        case "peach":
            // 복숭아 핑크: 핑크 편향 + 따뜻함
            result = temperature(target: 7300)
            result = colorMatrix(rBias: 0.018, gBias: 0.005, bBias: -0.008)
            result = colorControls(saturation: 1.08, brightness: 0.02)

        // ─── Cool 계열 ────────────────────────────────────────────────────
        case "ice":
            // 겨울 크리스프: 차갑고 선명, 아이시 블루
            result = temperature(target: 5700)
            result = colorControls(contrast: 1.12, saturation: 1.06, brightness: 0.04)
            result = colorMatrix(bBias: 0.018)

        case "sky":
            // 맑은 하늘: 청량하고 밝음
            result = temperature(target: 5900)
            result = colorControls(contrast: 1.08, saturation: 1.05, brightness: 0.04)
            result = colorMatrix(gBias: 0.004, bBias: 0.010)

        case "ocean":
            // 깊은 바다: 강한 쿨톤 + 대비
            result = temperature(target: 5500)
            result = colorControls(contrast: 1.18, saturation: 0.92)
            result = colorMatrix(rScale: 0.95, bScale: 1.04, bBias: 0.018)

        case "mint":
            // 민트 쿨: 그린-블루 틴트 + 청량함
            result = temperature(target: 5800)
            result = colorMatrix(gScale: 1.02, bScale: 1.02, gBias: 0.012, bBias: 0.006)
            result = colorControls(saturation: 0.90, brightness: 0.03)

        // ─── Aesthetic 계열 ───────────────────────────────────────────────
        case "dream":
            // 보랏빛 몽환: 블루-퍼플 헤이즈 + 소프트
            result = colorMatrix(rScale: 0.97, gScale: 0.96, bScale: 1.04, bBias: 0.015)
            result = colorControls(contrast: 0.94, saturation: 0.92, brightness: 0.03)

        // ─── LUT 거의 identity → 코드로 색감 완전 정의 ──────────────────────
        case "vivid":
            // 팝아트 선명함 — 전 채널 균등 채도, R 클리핑 방지
            result = colorControls(contrast: 1.30, saturation: 1.32)
            result = colorMatrix(rScale: 0.96, gScale: 1.01, bScale: 1.03) // R 억제·B 살짝+

        case "retro_ccd":
            // 구형 디지털 카메라 — 탈포화·그린 캐스트·쿨 화이트
            result = colorControls(contrast: 1.22, saturation: 0.80)
            result = colorMatrix(gScale: 1.02, bBias: 0.015)              // CCD 특유 그린+쿨
            result = temperature(target: 6100)

        case "film03":
            // Y2K 파스텔 페이드 — 쿨 하이라이트·약한 채도
            result = colorMatrix(rScale: 0.95, gScale: 0.96, bScale: 0.94,
                                 rBias: 0.04, gBias: 0.04, bBias: 0.07)   // 쿨 파스텔 리프트
            result = colorControls(contrast: 1.12, saturation: 0.88)

        // ─── 쌍둥이 차별화 ────────────────────────────────────────────────
        case "lavender":
            // dream(블루)과 차별화: R+B 동시 올려 따뜻한 퍼플
            result = colorMatrix(rScale: 1.03, gScale: 0.97, bScale: 1.03,
                                 rBias: 0.015, gBias: 0.0, bBias: 0.025)

        case "winter":
            // cloud보다 선명·깨끗한 쿨화이트
            result = colorControls(contrast: 1.18, saturation: 1.08)
            result = colorMatrix(bBias: 0.008)                            // 아주 약한 아이시 블루

        case "cloud":
            // muted 흐린 하늘 — 대비↓ 채도↓ 약간 밝게
            result = colorControls(contrast: 0.90, saturation: 0.86, brightness: 0.04)

        case "kodak_soft":
            // 코닥 필름 — 강한 웜 페이드 + 쉐도우 리프트 + 탈포화
            result = temperature(target: 7500)
            result = colorMatrix(rBias: 0.045, gBias: 0.030, bBias: 0.012) // 진한 필름 페이드
            result = colorControls(contrast: 1.20, saturation: 0.72)

        case "film98":
            // 90년대 필름 — 강한 대비 + 웜 마트 페이드
            result = colorControls(contrast: 1.24)
            result = colorMatrix(rScale: 0.97, gScale: 0.97, bScale: 0.97,
                                 rBias: 0.022, gBias: 0.012, bBias: 0.003) // 웜 페이드

        case "disposable":
            // 일회용 카메라 — 채도·대비 과장, 그린-옐로 캐스트
            result = colorControls(contrast: 1.18, saturation: 1.15)
            result = colorMatrix(gScale: 1.01, rBias: 0.006, gBias: 0.010, bBias: -0.012)

        case "mocha":
            // 커피브라운 무드 — 강한 탈포화 + 진한 온기 + 브라운 채널 편향
            result = temperature(target: 7800)
            result = colorMatrix(rBias: 0.035, gBias: 0.015, bBias: -0.025) // 브라운 틴트
            result = colorControls(contrast: 1.20, saturation: 0.65)

        case "latte":
            // 크리미 카페 — mocha보다 밝고 더 크리미한 웜톤
            result = temperature(target: 7000)
            result = colorControls(contrast: 1.04, saturation: 0.88, brightness: 0.04)

        case "soft_pink":
            // 로즈핑크 — R+B 동시 올려 핑크(레드 아님), G 살짝 내려
            result = colorMatrix(rScale: 1.02, gScale: 0.97, bScale: 1.00,
                                 rBias: 0.012, gBias: 0.003, bBias: 0.020) // 로즈핑크 틴트

        case "pale":
            // 창백한 쿨톤 — 탈포화·밝음·약간 차갑게
            result = colorControls(saturation: 0.75, brightness: 0.05)
            result = temperature(target: 6200)

        case "blossom":
            // 벚꽃 봄빛 — 핑크-피치, 은은하게 밝게
            result = colorMatrix(rScale: 1.02, gScale: 0.98, bScale: 1.01,
                                 rBias: 0.018, gBias: 0.006, bBias: 0.016) // 피치-핑크
            result = colorControls(brightness: 0.03)

        case "dusty_blue":
            // 빈티지 블루 — 탈포화·대비 약하게, 먼지낀 느낌
            result = colorControls(contrast: 0.96, saturation: 0.80)

        default:
            break
        }

        return result
    }

    // MARK: - 캐시 관리

    func clearCache() {
        lutCache.removeAllObjects()
        currentLUTFilter = nil
    }

    func preloadLUTs(_ lutFileNames: [String]) {
        for name in lutFileNames {
            loadLUT(named: name)
        }
    }

    /// LUT가 캐시에 있는지 확인 (메인 스레드에서 호출)
    func isLUTCached(named lutFileName: String) -> Bool {
        return lutCache.object(forKey: NSString(string: lutFileName)) != nil
    }

    /// 백그라운드 스레드에서 안전하게 캐시만 채움 — currentLUTFilter 변경 없음
    /// NSCache는 스레드 안전(thread-safe)하므로 동시 접근 가능
    func preloadToCache(named lutFileName: String) {
        let cacheKey = NSString(string: lutFileName)
        guard lutCache.object(forKey: cacheKey) == nil else { return }

        let resourceName = (lutFileName as NSString).deletingPathExtension
        let appFrameworkBundle = Bundle(url: Bundle.main.bundleURL
            .appendingPathComponent("Frameworks/App.framework"))
        let resolvedURL = appFrameworkBundle?.url(forResource: resourceName, withExtension: "cube",
                                                   subdirectory: "flutter_assets/assets/luts")
            ?? Bundle.main.url(forResource: resourceName, withExtension: "cube",
                               subdirectory: "flutter_assets/assets/luts")
            ?? Bundle.main.url(forResource: resourceName, withExtension: "cube",
                               subdirectory: "luts")
        guard let url = resolvedURL, let filter = buildLUTFilter(from: url) else { return }
        lutCache.setObject(filter, forKey: cacheKey)
    }
}
