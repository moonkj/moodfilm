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
        return CIContext(
            mtlDevice: device,
            options: [
                .workingColorSpace: CGColorSpaceCreateDeviceRGB(),
                .outputColorSpace: CGColorSpaceCreateDeviceRGB(),
                .useSoftwareRenderer: false,
            ]
        )
    }()

    // MARK: - LUT 캐시 (최대 8개 — 즐겨찾기 + 최근 사용)
    private var lutCache = NSCache<NSString, CIFilter>()
    private var currentLUTFilter: CIFilter?
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
        filter?.setValue(CGColorSpaceCreateDeviceRGB(), forKey: "inputColorSpace")

        return filter
    }

    // MARK: - 필터 파이프라인 적용

    /// CIImage에 현재 LUT + 이펙트 파이프라인 적용
    func apply(to image: CIImage) -> CIImage {
        var result = image

        // 1. LUT 필터 적용 (강도 블렌딩)
        if let lutFilter = currentLUTFilter, intensity > 0 {
            lutFilter.setValue(result, forKey: kCIInputImageKey)
            if let filtered = lutFilter.outputImage {
                if intensity >= 1.0 {
                    result = filtered
                } else {
                    // intensity 블렌딩: filtered * intensity + original * (1 - intensity)
                    // filtered 이미지의 alpha를 intensity로 설정한 뒤 source-over 합성
                    if let alphaFilter = CIFilter(name: "CIColorMatrix"),
                       let composite = CIFilter(name: "CISourceOverCompositing") {
                        alphaFilter.setValue(filtered, forKey: kCIInputImageKey)
                        alphaFilter.setValue(CIVector(x: 1, y: 0, z: 0, w: 0), forKey: "inputRVector")
                        alphaFilter.setValue(CIVector(x: 0, y: 1, z: 0, w: 0), forKey: "inputGVector")
                        alphaFilter.setValue(CIVector(x: 0, y: 0, z: 1, w: 0), forKey: "inputBVector")
                        alphaFilter.setValue(CIVector(x: 0, y: 0, z: 0, w: CGFloat(intensity)), forKey: "inputAVector")
                        if let semiTransparent = alphaFilter.outputImage {
                            composite.setValue(semiTransparent, forKey: kCIInputImageKey)
                            composite.setValue(result, forKey: kCIInputBackgroundImageKey)
                            result = composite.outputImage ?? result
                        }
                    }
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

        return result
    }

    // MARK: - 시그니처 이펙트: Dreamy Glow
    // CIBloom + Gaussian Blur 조합으로 사진 전체에 몽환적인 빛번짐

    private func applyDreamyGlow(to image: CIImage, intensity: Float) -> CIImage {
        // CIBloom: radius = intensity * 20, inputIntensity = intensity * 0.8
        guard let bloomFilter = CIFilter(name: "CIBloom") else { return image }
        bloomFilter.setValue(image, forKey: kCIInputImageKey)
        bloomFilter.setValue(intensity * 20.0, forKey: kCIInputRadiusKey)
        bloomFilter.setValue(intensity * 0.8, forKey: kCIInputIntensityKey)

        guard let bloomed = bloomFilter.outputImage else { return image }

        // Gaussian Blur로 부드러운 빛번짐 강화
        guard let blurFilter = CIFilter(name: "CIGaussianBlur") else { return bloomed }
        blurFilter.setValue(bloomed, forKey: kCIInputImageKey)
        blurFilter.setValue(intensity * 3.0, forKey: kCIInputRadiusKey)

        guard let blurred = blurFilter.outputImage else { return bloomed }

        // 원본 이미지 위에 glow 레이어 overlay blend
        guard let overlayFilter = CIFilter(name: "CIOverlayBlendMode") else { return blurred }
        overlayFilter.setValue(blurred.cropped(to: image.extent), forKey: kCIInputImageKey)
        overlayFilter.setValue(image, forKey: kCIInputBackgroundImageKey)

        return overlayFilter.outputImage?.cropped(to: image.extent) ?? image
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
        blurFilter.setValue(image, forKey: kCIInputImageKey)
        blurFilter.setValue(intensity * 5.0, forKey: kCIInputRadiusKey)
        guard let blurred = blurFilter.outputImage?.cropped(to: image.extent) else { return image }

        // 원본과 블러를 alpha로 블렌딩 (intensity * 0.55 비율)
        guard let alphaFilter = CIFilter(name: "CIColorMatrix"),
              let composite = CIFilter(name: "CISourceOverCompositing") else { return image }
        alphaFilter.setValue(blurred, forKey: kCIInputImageKey)
        alphaFilter.setValue(CIVector(x: 1, y: 0, z: 0, w: 0), forKey: "inputRVector")
        alphaFilter.setValue(CIVector(x: 0, y: 1, z: 0, w: 0), forKey: "inputGVector")
        alphaFilter.setValue(CIVector(x: 0, y: 0, z: 1, w: 0), forKey: "inputBVector")
        alphaFilter.setValue(CIVector(x: 0, y: 0, z: 0, w: CGFloat(intensity * 0.55)), forKey: "inputAVector")
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
            blurFilter.setValue(result, forKey: kCIInputImageKey)
            blurFilter.setValue(intensity * 4.0, forKey: kCIInputRadiusKey)
            if let blurred = blurFilter.outputImage?.cropped(to: image.extent) {
                // 소프트 라이트로 원본과 블렌딩 (intensity * 0.5 opacity)
                if let alphaFilter = CIFilter(name: "CIColorMatrix"),
                   let composite = CIFilter(name: "CISourceOverCompositing") {
                    alphaFilter.setValue(blurred, forKey: kCIInputImageKey)
                    alphaFilter.setValue(CIVector(x: 1, y: 0, z: 0, w: 0), forKey: "inputRVector")
                    alphaFilter.setValue(CIVector(x: 0, y: 1, z: 0, w: 0), forKey: "inputGVector")
                    alphaFilter.setValue(CIVector(x: 0, y: 0, z: 1, w: 0), forKey: "inputBVector")
                    alphaFilter.setValue(CIVector(x: 0, y: 0, z: 0, w: CGFloat(intensity * 0.45)), forKey: "inputAVector")
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
            colorFilter.setValue(CGFloat(intensity) * 0.08, forKey: kCIInputBrightnessKey)
            colorFilter.setValue(1.0 + CGFloat(intensity) * 0.06, forKey: kCIInputSaturationKey)
            result = colorFilter.outputImage?.cropped(to: image.extent) ?? result
        }

        // 3. 따뜻한 피부톤 (CITemperatureAndTint)
        if let tempFilter = CIFilter(name: "CITemperatureAndTint") {
            tempFilter.setValue(result, forKey: kCIInputImageKey)
            let temp = 6500.0 + CGFloat(intensity) * 500.0
            tempFilter.setValue(CIVector(x: temp, y: 0), forKey: "inputNeutral")
            tempFilter.setValue(CIVector(x: 6500, y: 0), forKey: "inputTargetNeutral")
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
            // front: 저Y → display 왼쪽(원본), 고Y → display 오른쪽(필터)
            originalPart = original.cropped(to: CGRect(
                x: extent.minX, y: extent.minY,
                width: extent.width, height: splitY - extent.minY))
            filteredPart = filtered.cropped(to: CGRect(
                x: extent.minX, y: splitY,
                width: extent.width, height: extent.maxY - splitY))
        } else {
            // back: 고Y → display 왼쪽(원본), 저Y → display 오른쪽(필터)
            originalPart = original.cropped(to: CGRect(
                x: extent.minX, y: splitY,
                width: extent.width, height: extent.maxY - splitY))
            filteredPart = filtered.cropped(to: CGRect(
                x: extent.minX, y: extent.minY,
                width: extent.width, height: splitY - extent.minY))
        }

        guard let composite = CIFilter(name: "CISourceOverCompositing") else { return filtered }
        composite.setValue(originalPart, forKey: kCIInputImageKey)
        composite.setValue(filteredPart, forKey: kCIInputBackgroundImageKey)
        return composite.outputImage?.cropped(to: extent) ?? filtered
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
}
