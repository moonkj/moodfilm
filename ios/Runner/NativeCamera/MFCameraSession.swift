import AVFoundation
import CoreImage
import ImageIO
import UIKit

protocol MFCameraSessionDelegate: AnyObject {
    func cameraSession(_ session: MFCameraSession, didOutput pixelBuffer: CVPixelBuffer)
    func cameraSession(_ session: MFCameraSession, didCapturePhoto path: String)
    func cameraSession(_ session: MFCameraSession, didFailWithError error: Error)
}

/// AVFoundation 기반 카메라 세션 관리
/// - 30fps 실시간 프리뷰
/// - LUT 필터 실시간 적용
/// - Full-resolution 사진 캡처
class MFCameraSession: NSObject {

    // MARK: - Properties
    weak var delegate: MFCameraSessionDelegate?
    let lutEngine = MFLUTEngine()

    private let captureSession = AVCaptureSession()
    private var videoOutput: AVCaptureVideoDataOutput?
    private var audioOutput: AVCaptureAudioDataOutput?
    private var photoOutput: AVCapturePhotoOutput?
    private var currentDevice: AVCaptureDevice?
    private var isFront = true

    private let sessionQueue = DispatchQueue(label: "com.moodfilm.camera.session", qos: .userInitiated)
    private let processingQueue = DispatchQueue(label: "com.moodfilm.camera.processing", qos: .userInitiated)

    var currentExposure: Float = 0.0 // -2EV ~ +2EV
    var currentZoom: CGFloat = 1.0

    // MARK: - 동영상 녹화
    private let recorder = MFVideoRecorder()
    var isRecording: Bool { recorder.isRecording }

    // MARK: - Setup

    func setup(frontCamera: Bool, completion: @escaping (Bool) -> Void) {
        isFront = frontCamera
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            let success = self.configureSession(frontCamera: frontCamera)
            DispatchQueue.main.async { completion(success) }
        }
    }

    private func configureSession(frontCamera: Bool) -> Bool {
        captureSession.beginConfiguration()
        // 프리뷰는 hd1920x1080으로 성능 확보, 사진은 isHighResolution으로 풀해상도 유지
        captureSession.sessionPreset = .hd1920x1080

        // 이전 입력 제거
        captureSession.inputs.forEach { captureSession.removeInput($0) }
        captureSession.outputs.forEach { captureSession.removeOutput($0) }

        // 카메라 디바이스 선택
        let position: AVCaptureDevice.Position = frontCamera ? .front : .back
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position),
              let input = try? AVCaptureDeviceInput(device: device) else {
            captureSession.commitConfiguration()
            return false
        }

        currentDevice = device

        if captureSession.canAddInput(input) {
            captureSession.addInput(input)
        }

        // 비디오 출력 (실시간 프레임)
        let videoOut = AVCaptureVideoDataOutput()
        videoOut.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        videoOut.setSampleBufferDelegate(self, queue: processingQueue)
        videoOut.alwaysDiscardsLateVideoFrames = true

        if captureSession.canAddOutput(videoOut) {
            captureSession.addOutput(videoOut)
        }
        videoOutput = videoOut

        // 오디오 입력 + 출력 (녹화용)
        if let audioDev = AVCaptureDevice.default(for: .audio),
           let audioIn = try? AVCaptureDeviceInput(device: audioDev),
           captureSession.canAddInput(audioIn) {
            captureSession.addInput(audioIn)
        }
        let audioOut = AVCaptureAudioDataOutput()
        audioOut.setSampleBufferDelegate(self, queue: processingQueue)
        if captureSession.canAddOutput(audioOut) {
            captureSession.addOutput(audioOut)
        }
        audioOutput = audioOut

        // 사진 출력
        let photoOut = AVCapturePhotoOutput()
        photoOut.isHighResolutionCaptureEnabled = true
        if captureSession.canAddOutput(photoOut) {
            captureSession.addOutput(photoOut)
        }
        photoOutput = photoOut

        captureSession.commitConfiguration()
        return true
    }

    func start() {
        sessionQueue.async { [weak self] in
            self?.captureSession.startRunning()
        }
    }

    func stop() {
        sessionQueue.async { [weak self] in
            self?.captureSession.stopRunning()
        }
    }

    // MARK: - 카메라 제어

    func flipCamera() {
        isFront = !isFront
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            _ = self.configureSession(frontCamera: self.isFront)
            if !self.captureSession.isRunning {
                self.captureSession.startRunning()
            }
        }
    }

    func setExposure(_ ev: Float) {
        guard let device = currentDevice else { return }
        currentExposure = ev
        sessionQueue.async {
            do {
                try device.lockForConfiguration()
                device.setExposureTargetBias(ev) { _ in }
                device.unlockForConfiguration()
            } catch {
                print("[MFCameraSession] 노출 조정 실패: \(error)")
            }
        }
    }

    func setZoom(_ zoom: CGFloat) {
        guard let device = currentDevice else { return }
        let clampedZoom = min(max(zoom, 1.0), device.activeFormat.videoMaxZoomFactor)
        currentZoom = clampedZoom
        sessionQueue.async {
            do {
                try device.lockForConfiguration()
                device.videoZoomFactor = clampedZoom
                device.unlockForConfiguration()
            } catch {
                print("[MFCameraSession] 줌 설정 실패: \(error)")
            }
        }
    }

    func setFocusPoint(x: CGFloat, y: CGFloat) {
        guard let device = currentDevice, device.isFocusPointOfInterestSupported else { return }
        let point = CGPoint(x: x, y: y)
        sessionQueue.async {
            do {
                try device.lockForConfiguration()
                device.focusPointOfInterest = point
                device.focusMode = .autoFocus
                device.unlockForConfiguration()
            } catch {
                print("[MFCameraSession] 포커스 설정 실패: \(error)")
            }
        }
    }

    // MARK: - 사진 촬영

    func capturePhoto() {
        let settings = AVCapturePhotoSettings()
        settings.isHighResolutionPhotoEnabled = true
        photoOutput?.capturePhoto(with: settings, delegate: self)
    }

    // MARK: - 동영상 녹화

    func startRecording(outputPath: String) {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            // 오디오 세션을 녹화 모드로 전환 (sessionQueue에서 실행 → 메인 스레드 block 방지)
            let audioSession = AVAudioSession.sharedInstance()
            try? audioSession.setCategory(.playAndRecord, options: [.defaultToSpeaker, .allowBluetooth])
            try? audioSession.setActive(true)

            self.recorder.startRecording(
                outputPath: outputPath,
                videoSize: CGSize(width: 1920, height: 1080)
            )
        }
    }

    func stopRecording(completion: @escaping (String?) -> Void) {
        recorder.stopRecording { url in
            completion(url?.path)
        }
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate + AVCaptureAudioDataOutputSampleBufferDelegate

extension MFCameraSession: AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureAudioDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {

        // 오디오 버퍼 처리 (녹화에만 사용)
        if output === audioOutput {
            recorder.appendAudioBuffer(sampleBuffer)
            return
        }

        // 영상 버퍼 처리
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        let needsProcessing = lutEngine.intensity > 0 && (
            lutEngine.hasLUT || lutEngine.glowIntensity > 0 ||
            lutEngine.grainIntensity > 0 || lutEngine.beautyIntensity > 0
        )

        let outputBuffer: CVPixelBuffer
        if needsProcessing {
            let ciImage = lutEngine.apply(to: CIImage(cvPixelBuffer: pixelBuffer))
            var processed: CVPixelBuffer?
            let attrs: [String: Any] = [
                kCVPixelBufferMetalCompatibilityKey as String: true,
                kCVPixelBufferIOSurfacePropertiesKey as String: [:],
            ]
            CVPixelBufferCreate(kCFAllocatorDefault,
                                CVPixelBufferGetWidth(pixelBuffer),
                                CVPixelBufferGetHeight(pixelBuffer),
                                kCVPixelFormatType_32BGRA,
                                attrs as CFDictionary,
                                &processed)
            if let proc = processed {
                MFLUTEngine.ciContext.render(ciImage, to: proc,
                                             bounds: CIImage(cvPixelBuffer: pixelBuffer).extent,
                                             colorSpace: CGColorSpaceCreateDeviceRGB())
                outputBuffer = proc
            } else {
                outputBuffer = pixelBuffer
            }
        } else {
            outputBuffer = pixelBuffer
        }

        // 프리뷰 업데이트
        delegate?.cameraSession(self, didOutput: outputBuffer)

        // 녹화 중이면 recorder에 전달
        if recorder.isRecording {
            let timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
            recorder.appendVideoBuffer(outputBuffer, timestamp: timestamp)
        }
    }
}

// MARK: - AVCapturePhotoCaptureDelegate

extension MFCameraSession: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput,
                     didFinishProcessingPhoto photo: AVCapturePhoto,
                     error: Error?) {
        if let error = error {
            delegate?.cameraSession(self, didFailWithError: error)
            return
        }

        guard var imageData = photo.fileDataRepresentation(),
              let ciImage = CIImage(data: imageData) else { return }

        // Full-res LUT 필터 적용
        let filteredImage = lutEngine.apply(to: ciImage)

        // JPEG 변환
        if let jpegData = MFLUTEngine.ciContext.jpegRepresentation(
            of: filteredImage,
            colorSpace: CGColorSpaceCreateDeviceRGB(),
            options: [kCGImageDestinationLossyCompressionQuality as CIImageRepresentationOption: 0.95]
        ) {
            imageData = jpegData
        }

        // 임시 파일 저장
        let tempDir = FileManager.default.temporaryDirectory
        let fileName = "moodfilm_\(Int(Date().timeIntervalSince1970)).jpg"
        let filePath = tempDir.appendingPathComponent(fileName)

        do {
            try imageData.write(to: filePath)
            delegate?.cameraSession(self, didCapturePhoto: filePath.path)
        } catch {
            delegate?.cameraSession(self, didFailWithError: error)
        }
    }
}
