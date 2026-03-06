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
                    // intensity 블렌딩: original * (1 - intensity) + filtered * intensity
                    let blend = CIFilter(name: "CIBlend")
                    blend?.setValue(filtered, forKey: kCIInputImageKey)
                    blend?.setValue(result, forKey: kCIInputBackgroundImageKey)
                    if let blended = blend?.outputImage {
                        result = blended
                    }
                }
            }
        }

        // 2. Dreamy Glow 이펙트 (시그니처)
        if glowIntensity > 0 {
            result = applyDreamyGlow(to: result, intensity: glowIntensity)
        }

        // 3. Film Grain
        if grainIntensity > 0 {
            result = applyFilmGrain(to: result, intensity: grainIntensity)
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
