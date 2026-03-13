import AVFoundation
import CoreImage
import Flutter

/// 동영상 실시간 필터 렌더러
/// AVPlayerItemVideoOutput으로 각 프레임을 가져와 MFLUTEngine으로 처리 후 FlutterTexture에 제공
final class MFVideoFilterPlayer: NSObject, FlutterTexture {

    // MARK: – AVFoundation
    private let player: AVPlayer
    private let videoOutput: AVPlayerItemVideoOutput

    // MARK: – Filter (메인 스레드에서만 접근)
    private let lutEngine = MFLUTEngine()
    private var needsRefresh = false
    // 비동기 LUT 로딩 중인 파일 추적 — 스크롤 중 취소 여부 판단용
    private var pendingLutFile: String?
    private var pendingIntensity: Float = 1.0

    // MARK: – 회전 보정 (CIImage y-up 좌표계용)
    private var ciVideoTransform: CGAffineTransform = .identity
    private var outputWidth:  Int = 0
    private var outputHeight: Int = 0

    // MARK: – Display Link
    private var displayLink: CADisplayLink?

    // MARK: – Buffers
    private let lock = NSLock()
    private var latestBuffer: CVPixelBuffer?
    private var lastSourceBuffer: CVPixelBuffer?
    private var bufferPool: CVPixelBufferPool?

    // MARK: – Texture
    var textureId: Int64 = -1
    weak var textureRegistry: FlutterTextureRegistry?

    // MARK: – Init

    init(url: URL) {
        let pixelBufferAttributes: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferMetalCompatibilityKey as String: true,
            kCVPixelBufferIOSurfacePropertiesKey as String: [:] as [String: Any],
        ]
        videoOutput = AVPlayerItemVideoOutput(pixelBufferAttributes: pixelBufferAttributes)

        let item = AVPlayerItem(url: url)
        item.add(videoOutput)
        player = AVPlayer(playerItem: item)
        player.actionAtItemEnd = .none

        super.init()

        // 비디오 트랙의 preferredTransform 읽기 (로컬 파일 → 동기 가능)
        if let track = item.asset.tracks(withMediaType: .video).first {
            let natural = track.naturalSize
            ciVideoTransform = Self.ciTransform(from: track.preferredTransform, naturalSize: natural)
            let rotated = natural.applying(track.preferredTransform)
            outputWidth  = Int(abs(rotated.width).rounded())
            outputHeight = Int(abs(rotated.height).rounded())
        }

        NotificationCenter.default.addObserver(
            self, selector: #selector(itemDidEnd),
            name: .AVPlayerItemDidPlayToEndTime, object: item
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        displayLink?.invalidate()
    }

    @objc private func itemDidEnd() {
        player.seek(to: .zero) { [weak self] _ in
            self?.player.play()
        }
    }

    // MARK: – Public API

    func start(registry: FlutterTextureRegistry) -> Int64 {
        textureRegistry = registry
        textureId = registry.register(self)
        displayLink = CADisplayLink(target: self, selector: #selector(tick(_:)))
        displayLink?.preferredFramesPerSecond = 30
        displayLink?.add(to: .main, forMode: .common)
        player.play()
        return textureId
    }

    /// 회전 보정 후 표시 크기
    var videoSize: CGSize {
        if outputWidth > 0 && outputHeight > 0 {
            return CGSize(width: outputWidth, height: outputHeight)
        }
        return CGSize(width: 1080, height: 1920)
    }

    // 메인 스레드에서 호출
    func updateFilter(lutFile: String, intensity: Float) {
        pendingLutFile = lutFile
        pendingIntensity = intensity

        if lutFile.isEmpty {
            lutEngine.intensity = 0.0
            needsRefresh = true
            return
        }

        if lutEngine.isLUTCached(named: lutFile) {
            // 캐시 히트: 즉시 적용 (< 1ms, 메인 스레드 블록 없음)
            lutEngine.loadLUT(named: lutFile)
            lutEngine.intensity = intensity
            needsRefresh = true
        } else {
            // 캐시 미스: 백그라운드에서 로딩 — 메인 스레드 블록 없이 현재 필터 유지
            let capturedFile = lutFile
            let capturedIntensity = intensity
            DispatchQueue.global(qos: .userInteractive).async { [weak self] in
                guard let self = self else { return }
                self.lutEngine.preloadToCache(named: capturedFile)
                DispatchQueue.main.async {
                    // 스크롤 중 다른 필터로 변경됐으면 적용하지 않음
                    guard self.pendingLutFile == capturedFile else { return }
                    self.lutEngine.loadLUT(named: capturedFile)
                    self.lutEngine.intensity = capturedIntensity
                    self.needsRefresh = true
                }
            }
        }
    }

    // 메인 스레드에서 호출
    func updateEffects(_ effects: [String: Double]) {
        lutEngine.brightnessIntensity = Float(effects["brightness"] ?? 0)
        lutEngine.contrastIntensity   = Float(effects["contrast"] ?? 0)
        lutEngine.saturationIntensity = Float(effects["saturation"] ?? 0)
        lutEngine.softnessIntensity   = Float(effects["softness"] ?? 0)
        lutEngine.beautyIntensity     = Float(effects["beauty"] ?? 0)
        lutEngine.glowIntensity       = Float(effects["dreamyGlow"] ?? effects["glow"] ?? 0)
        lutEngine.grainIntensity      = Float(effects["filmGrain"] ?? 0)
        lutEngine.lightLeakIntensity  = Float(effects["lightLeak"] ?? 0)
        needsRefresh = true
    }

    func play()  { player.play() }
    func pause() { player.pause() }

    /// 백그라운드에서 LUT 캐시를 미리 채움 — 첫 필터 선택 시 메인 스레드 지연 방지
    func preloadLUTs(_ names: [String]) {
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self = self else { return }
            for name in names {
                self.lutEngine.preloadToCache(named: name)
            }
        }
    }

    func seek(to seconds: Double) {
        player.seek(to: CMTime(seconds: seconds, preferredTimescale: 600))
    }

    func dispose() {
        displayLink?.invalidate()
        displayLink = nil
        player.pause()
        if textureId >= 0 {
            textureRegistry?.unregisterTexture(textureId)
            textureId = -1
        }
    }

    // MARK: – FlutterTexture

    func copyPixelBuffer() -> Unmanaged<CVPixelBuffer>? {
        lock.lock()
        defer { lock.unlock() }
        guard let buf = latestBuffer else { return nil }
        return Unmanaged.passRetained(buf)
    }

    // MARK: – Display Link Tick (메인 스레드)

    @objc private func tick(_ link: CADisplayLink) {
        let itemTime = videoOutput.itemTime(forHostTime: link.timestamp)

        var src: CVPixelBuffer?
        if videoOutput.hasNewPixelBuffer(forItemTime: itemTime) {
            src = videoOutput.copyPixelBuffer(forItemTime: itemTime, itemTimeForDisplay: nil)
            if let buf = src { lastSourceBuffer = buf }
        } else if needsRefresh, let last = lastSourceBuffer {
            src = last
            needsRefresh = false
        }

        guard let srcBuffer = src else { return }
        processFrame(srcBuffer)
    }

    // MARK: – Frame Processing (메인 스레드)

    private func processFrame(_ src: CVPixelBuffer) {
        var ciImage = CIImage(cvPixelBuffer: src)

        // 1. 먼저 회전 보정 — 이펙트(LightLeak, Glow 등)가 올바른 방향으로 적용되도록
        if ciVideoTransform != .identity {
            ciImage = ciImage.transformed(by: ciVideoTransform)
        }

        // 2. 회전된 이미지에 LUT + 이펙트 적용
        ciImage = lutEngine.apply(to: ciImage)

        let outW = outputWidth  > 0 ? outputWidth  : Int(ciImage.extent.width.rounded())
        let outH = outputHeight > 0 ? outputHeight : Int(ciImage.extent.height.rounded())

        // 3. 버퍼 풀 (처음 한 번만 생성, 출력 크기 기준)
        if bufferPool == nil { createPool(width: outW, height: outH) }
        guard let pool = bufferPool else { return }

        var dst: CVPixelBuffer?
        CVPixelBufferPoolCreatePixelBuffer(nil, pool, &dst)
        guard let out = dst else { return }

        // 4. CIImage → CVPixelBuffer 렌더
        MFLUTEngine.ciContext.render(
            ciImage, to: out,
            bounds: CGRect(origin: .zero, size: CGSize(width: outW, height: outH)),
            colorSpace: CGColorSpaceCreateDeviceRGB()
        )

        lock.lock()
        latestBuffer = out
        lock.unlock()

        textureRegistry?.textureFrameAvailable(textureId)
    }

    // MARK: – UIKit preferredTransform → CIImage 좌표계 변환
    //
    // AVFoundation preferredTransform은 UIKit y-down 좌표계 기준.
    // CIImage는 y-up 좌표계이므로 같은 회전각을 적용하면 상하가 반전됨.
    // 회전 각도를 추출 후 CIImage 전용 행렬로 재구성.
    //
    //   UIKit 90°  (b=1)  → CIImage 90° CW:  {a:0, b:-1, c:1,  d:0,  tx:0, ty:W}
    //   UIKit -90° (b=-1) → CIImage 90° CCW: {a:0, b:1,  c:-1, d:0,  tx:H, ty:0}
    //   UIKit 180°        → CIImage 180°:    {a:-1,b:0,  c:0,  d:-1, tx:W, ty:H}
    //
    private static func ciTransform(from t: CGAffineTransform, naturalSize s: CGSize) -> CGAffineTransform {
        let W = s.width   // naturalSize.width  (예: 1920)
        let H = s.height  // naturalSize.height (예: 1080)
        let angle = atan2(t.b, t.a)
        let halfPi = CGFloat.pi / 2

        if abs(angle - halfPi) < 0.1 {
            // UIKit 90° (b≈1) → 화면에서 90° CW 표시 → CIImage 90° CW
            return CGAffineTransform(a: 0, b: -1, c: 1, d: 0, tx: 0, ty: W)
        } else if abs(angle + halfPi) < 0.1 {
            // UIKit -90° (b≈-1) → 화면에서 90° CCW 표시 → CIImage 90° CCW
            return CGAffineTransform(a: 0, b: 1, c: -1, d: 0, tx: H, ty: 0)
        } else if abs(abs(angle) - .pi) < 0.1 {
            // UIKit 180° → CIImage 180°
            return CGAffineTransform(a: -1, b: 0, c: 0, d: -1, tx: W, ty: H)
        }
        return .identity
    }

    private func createPool(width: Int, height: Int) {
        let attrs: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: width,
            kCVPixelBufferHeightKey as String: height,
            kCVPixelBufferMetalCompatibilityKey as String: true,
            kCVPixelBufferIOSurfacePropertiesKey as String: [:] as [String: Any],
        ]
        CVPixelBufferPoolCreate(nil, nil, attrs as CFDictionary, &bufferPool)
    }
}
