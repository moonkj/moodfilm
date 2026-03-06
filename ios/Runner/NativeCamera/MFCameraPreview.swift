import MetalKit
import CoreImage
import Flutter

/// Metal 기반 카메라 프리뷰 렌더러
/// Flutter Texture 레지스트리에 등록되어 Flutter 위젯에서 표시
class MFCameraPreview: NSObject, FlutterTexture {

    private let textureRegistry: FlutterTextureRegistry
    var textureId: Int64 = -1

    private var metalDevice: MTLDevice?
    private var commandQueue: MTLCommandQueue?
    private var currentPixelBuffer: CVPixelBuffer?
    private let lock = NSLock()

    init(textureRegistry: FlutterTextureRegistry) {
        self.textureRegistry = textureRegistry
        self.metalDevice = MTLCreateSystemDefaultDevice()
        self.commandQueue = metalDevice?.makeCommandQueue()
        super.init()
        textureId = textureRegistry.register(self)
    }

    // MARK: - FlutterTexture

    func copyPixelBuffer() -> Unmanaged<CVPixelBuffer>? {
        lock.lock()
        defer { lock.unlock() }
        guard let buffer = currentPixelBuffer else { return nil }
        return Unmanaged.passRetained(buffer)
    }

    // MARK: - 프레임 업데이트

    func update(pixelBuffer: CVPixelBuffer) {
        lock.lock()
        currentPixelBuffer = pixelBuffer
        lock.unlock()
        textureRegistry.textureFrameAvailable(textureId)
    }

    // MARK: - 해제

    func dispose() {
        textureRegistry.unregisterTexture(textureId)
    }
}
