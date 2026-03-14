import Flutter
import UIKit
import CoreImage

/// 정지 이미지 실시간 필터 프리뷰 렌더러
/// 이미지를 메모리(CIImage)에 로드한 뒤, 파라미터 변경 시 즉시 재렌더 → FlutterTexture로 제공
final class MFImagePreviewRenderer: NSObject, FlutterTexture {

    // MARK: - Engine
    private let lutEngine = MFLUTEngine()
    private var pendingLutFile: String?

    // MARK: - Source
    private var sourceCIImage: CIImage?
    private(set) var outputWidth:  Int = 0
    private(set) var outputHeight: Int = 0

    // MARK: - Current Params
    private var currentAdjustments: [String: Double] = [:]

    // MARK: - Buffer
    private var bufferPool: CVPixelBufferPool?
    private let lock = NSLock()
    private var latestBuffer: CVPixelBuffer?

    // MARK: - Lifecycle
    private var isDisposed = false

    // MARK: - Render Throttle (슬라이더 이벤트 폭발 방지)
    private var renderScheduled = false

    // MARK: - Background Render Queue (CIContext.render → 메인 스레드 블로킹 방지)
    private static let renderQueue = DispatchQueue(
        label: "com.moodfilm.imagePreview.render",
        qos: .userInteractive
    )

    // MARK: - Texture
    var textureId: Int64 = -1
    weak var textureRegistry: FlutterTextureRegistry?

    // MARK: - Setup

    /// 이미지 파일 로드 (백그라운드에서 호출 가능)
    /// 최대 1080px로 다운스케일하여 메모리 사용 최적화
    func loadImage(from path: String, maxSize: Int = 1080) -> Bool {
        guard let uiImage = UIImage(contentsOfFile: path) else { return false }
        var image = uiImage

        let longest = max(image.size.width, image.size.height)
        if longest > CGFloat(maxSize) {
            let scale = CGFloat(maxSize) / longest
            let newSize = CGSize(
                width:  (image.size.width  * scale).rounded(),
                height: (image.size.height * scale).rounded()
            )
            UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
            image.draw(in: CGRect(origin: .zero, size: newSize))
            if let scaled = UIGraphicsGetImageFromCurrentImageContext() { image = scaled }
            UIGraphicsEndImageContext()
        }

        let ciOptions: [CIImageOption: Any] = [.colorSpace: CGColorSpace(name: CGColorSpace.sRGB)!]
        guard var ci = CIImage(image: image, options: ciOptions) else { return false }

        let orient = CGImagePropertyOrientation(image.imageOrientation)
        if orient != .up { ci = ci.oriented(orient) }

        sourceCIImage = ci
        outputWidth   = Int(ci.extent.width.rounded())
        outputHeight  = Int(ci.extent.height.rounded())
        createPool(width: outputWidth, height: outputHeight)
        return true
    }

    func start(registry: FlutterTextureRegistry) -> Int64 {
        textureRegistry = registry
        textureId = registry.register(self)
        return textureId
    }

    // MARK: - Public Update API (메인 스레드에서 호출)

    func update(lutFile: String, intensity: Float,
                adjustments: [String: Double], effects: [String: Double]) {
        guard !isDisposed else { return }

        currentAdjustments = adjustments

        lutEngine.brightnessIntensity = Float(effects["brightness"] ?? 0)
        lutEngine.contrastIntensity   = Float(effects["contrast"]   ?? 0)
        lutEngine.saturationIntensity = Float(effects["saturation"] ?? 0)
        lutEngine.softnessIntensity   = Float(effects["softness"]   ?? 0)
        lutEngine.beautyIntensity     = Float(effects["beauty"]     ?? 0)
        lutEngine.glowIntensity       = Float(effects["dreamyGlow"] ?? effects["glow"] ?? 0)
        lutEngine.grainIntensity      = Float(effects["filmGrain"]  ?? 0)
        lutEngine.lightLeakIntensity  = Float(effects["lightLeak"]  ?? 0)

        if lutFile.isEmpty {
            lutEngine.intensity = 0.0
            scheduleRender()
        } else if lutEngine.isLUTCached(named: lutFile) {
            pendingLutFile = lutFile
            lutEngine.loadLUT(named: lutFile)
            lutEngine.intensity = intensity
            scheduleRender()
        } else {
            pendingLutFile = lutFile
            let file = lutFile
            let intens = intensity
            DispatchQueue.global(qos: .userInteractive).async { [weak self] in
                guard let self = self, !self.isDisposed else { return }
                self.lutEngine.preloadToCache(named: file)
                DispatchQueue.main.async { [weak self] in
                    guard let self = self, !self.isDisposed else { return }
                    guard self.pendingLutFile == file else { return }
                    self.lutEngine.loadLUT(named: file)
                    self.lutEngine.intensity = intens
                    self.scheduleRender()
                }
            }
        }
    }

    // MARK: - Render

    /// 같은 run loop에서 중복 render 방지
    private func scheduleRender() {
        guard !isDisposed, !renderScheduled else { return }
        renderScheduled = true
        DispatchQueue.main.async { [weak self] in
            guard let self = self, !self.isDisposed else {
                self?.renderScheduled = false
                return
            }
            self.renderScheduled = false
            self.renderAsync()
        }
    }

    /// CIFilter 체인 구성은 메인 스레드에서, GPU 렌더는 백그라운드에서 실행
    private func renderAsync() {
        guard !isDisposed,
              let src = sourceCIImage,
              let pool = bufferPool else { return }

        // CIImage는 immutable → 메인 스레드에서 필터 체인 구성 후 백그라운드로 전달 (thread-safe)
        var ci = MFLUTEngine.applyAdjustments(to: src, adjustments: currentAdjustments)
        ci = lutEngine.apply(to: ci)

        let outW = outputWidth
        let outH = outputHeight
        let tid  = textureId

        Self.renderQueue.async { [weak self] in
            guard let self = self, !self.isDisposed else { return }

            var dst: CVPixelBuffer?
            CVPixelBufferPoolCreatePixelBuffer(nil, pool, &dst)
            guard let out = dst else { return }

            MFLUTEngine.ciContext.render(
                ci, to: out,
                bounds: CGRect(origin: .zero, size: CGSize(width: outW, height: outH)),
                colorSpace: CGColorSpace(name: CGColorSpace.sRGB)!
            )

            self.lock.lock()
            self.latestBuffer = out
            self.lock.unlock()

            // textureFrameAvailable은 어느 스레드에서도 호출 가능
            if !self.isDisposed, tid >= 0 {
                self.textureRegistry?.textureFrameAvailable(tid)
            }
        }
    }

    // MARK: - FlutterTexture

    func copyPixelBuffer() -> Unmanaged<CVPixelBuffer>? {
        lock.lock()
        defer { lock.unlock() }
        guard !isDisposed, let buf = latestBuffer else { return nil }
        return Unmanaged.passRetained(buf)
    }

    // MARK: - Dispose

    func dispose() {
        isDisposed = true          // 가장 먼저 설정 → 진행 중 비동기 콜백 차단
        pendingLutFile = nil
        if textureId >= 0 {
            textureRegistry?.unregisterTexture(textureId)
            textureId = -1
        }
        sourceCIImage = nil
        lock.lock()
        latestBuffer  = nil
        lock.unlock()
        bufferPool    = nil
    }

    // MARK: - Pool

    private func createPool(width: Int, height: Int) {
        let attrs: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey  as String: width,
            kCVPixelBufferHeightKey as String: height,
            kCVPixelBufferMetalCompatibilityKey  as String: true,
            kCVPixelBufferIOSurfacePropertiesKey as String: [:] as [String: Any],
        ]
        CVPixelBufferPoolCreate(nil, nil, attrs as CFDictionary, &bufferPool)
    }

}
