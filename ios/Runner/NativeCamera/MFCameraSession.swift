import AVFoundation
import CoreImage
import ImageIO
import Photos
import UIKit

protocol MFCameraSessionDelegate: AnyObject {
    func cameraSession(_ session: MFCameraSession, didOutput pixelBuffer: CVPixelBuffer)
    /// 사진 캡처 완료 (라이브포토: livePhotoMovieURL != nil)
    func cameraSession(_ session: MFCameraSession, didCapturePhoto path: String, livePhotoMovieURL: URL?)
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

    var currentAspectRatio: String = "full" // 화면 비율 ('full', '9:16', '3:4', '1:1', '4:3', '16:9')
    var isLivePhotoEnabled: Bool = false

    // MARK: - 비율별 크롭 Rect 계산 (landscape 버퍼 기준)
    // captureOutput(프리뷰)과 photoOutput(사진)에서 공유 사용
    func cropRect(for ratio: String, imageSize: CGSize) -> CGRect {
        let w = imageSize.width
        let h = imageSize.height

        switch ratio {
        case "full", "16:9":
            return CGRect(origin: .zero, size: imageSize)
        case "9:16":
            let targetW = h * 9.0 / 16.0
            let x = (w - targetW) / 2.0
            return CGRect(x: x, y: 0, width: targetW, height: h)
        case "3:4":
            let targetW = h * 3.0 / 4.0
            let x = (w - targetW) / 2.0
            return CGRect(x: x, y: 0, width: targetW, height: h)
        case "1:1":
            let side = min(w, h)
            let x = (w - side) / 2.0
            let y = (h - side) / 2.0
            return CGRect(x: x, y: y, width: side, height: side)
        case "4:3":
            let targetW = h * 4.0 / 3.0
            if targetW <= w {
                let x = (w - targetW) / 2.0
                return CGRect(x: x, y: 0, width: targetW, height: h)
            } else {
                let targetH = w * 3.0 / 4.0
                let y = (h - targetH) / 2.0
                return CGRect(x: 0, y: y, width: w, height: targetH)
            }
        default:
            return CGRect(origin: .zero, size: imageSize)
        }
    }

    // MARK: - 무음 촬영용 최신 프레임 버퍼
    private var latestProcessedBuffer: CVPixelBuffer?

    // MARK: - 라이브포토 MOV 임시 경로
    private var livePhotoMovieURL: URL?
    // 라이브포토 완성 대기: JPEG와 MOV 둘 다 완료돼야 PHPhotoLibrary에 저장
    private var pendingLivePhotoJPEGPath: String?

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
        if photoOut.isLivePhotoCaptureSupported {
            photoOut.isLivePhotoCaptureEnabled = isLivePhotoEnabled
        }
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
        guard let photoOutput = photoOutput else { return }
        let settings = AVCapturePhotoSettings()
        settings.isHighResolutionPhotoEnabled = true

        // 라이브포토 활성화: isLivePhotoCaptureEnabled 확인 (supported + enabled 둘 다 필요)
        if photoOutput.isLivePhotoCaptureEnabled {
            let movURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("moodfilm_live_\(Int(Date().timeIntervalSince1970)).mov")
            livePhotoMovieURL = movURL
            settings.livePhotoMovieFileURL = movURL
        } else {
            livePhotoMovieURL = nil
        }

        photoOutput.capturePhoto(with: settings, delegate: self)
    }

    // MARK: - 라이브포토 활성화 설정

    func setLivePhotoEnabled(_ enabled: Bool) {
        guard let photoOutput = photoOutput else { return }
        isLivePhotoEnabled = enabled && photoOutput.isLivePhotoCaptureSupported
        sessionQueue.async {
            photoOutput.isLivePhotoCaptureEnabled = self.isLivePhotoEnabled
        }
    }

    // MARK: - 동영상 녹화

    func startRecording(outputPath: String) {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            self.recorder.startRecording(
                outputPath: outputPath,
                videoSize: CGSize(width: 1920, height: 1080)
            )
        }
    }

    func stopRecording(completion: @escaping (String?) -> Void) {
        // processingQueue로 직렬화: 진행 중인 appendVideoBuffer가 모두 끝난 뒤 stop
        processingQueue.async { [weak self] in
            guard let self = self else { completion(nil); return }
            self.recorder.stopRecording { url in
                completion(url?.path)
            }
        }
    }

    // MARK: - 무음 촬영 (현재 프레임 버퍼 저장)
    func captureSilentPhoto(completion: @escaping (String?) -> Void) {
        processingQueue.async { [weak self] in
            guard let self = self,
                  let buffer = self.latestProcessedBuffer else {
                DispatchQueue.main.async { completion(nil) }
                return
            }

            var ciImage = CIImage(cvPixelBuffer: buffer)

            // 비율 크롭 적용
            let cropR = self.cropRect(for: self.currentAspectRatio, imageSize: ciImage.extent.size)
            ciImage = ciImage.cropped(to: cropR)

            // CIImage → CGImage → UIImage (EXIF 방향 포함하여 portrait 저장)
            guard let cgImg = MFLUTEngine.ciContext.createCGImage(ciImage, from: ciImage.extent) else {
                DispatchQueue.main.async { completion(nil) }
                return
            }
            let orientation: UIImage.Orientation = self.isFront ? .leftMirrored : .right
            let uiImage = UIImage(cgImage: cgImg, scale: 1.0, orientation: orientation)

            guard let jpegData = uiImage.jpegData(compressionQuality: 0.95) else {
                DispatchQueue.main.async { completion(nil) }
                return
            }

            let tempDir = FileManager.default.temporaryDirectory
            let fileName = "moodfilm_\(Int(Date().timeIntervalSince1970)).jpg"
            let filePath = tempDir.appendingPathComponent(fileName)

            do {
                try jpegData.write(to: filePath)
                DispatchQueue.main.async { completion(filePath.path) }
            } catch {
                DispatchQueue.main.async { completion(nil) }
            }
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

        // 프리뷰: 항상 원본 1920×1080 버퍼 전달 (비율 크롭은 Flutter 레이어에서 처리)
        // 크롭은 실제 사진/동영상 저장 시에만 적용 (photoOutput 참조)
        // LUT 필터와 이펙트를 독립적으로 체크 (AND 조건 제거)
        let hasLUTFilter = lutEngine.intensity > 0 && lutEngine.hasLUT
        let hasEffect = lutEngine.glowIntensity > 0 || lutEngine.grainIntensity > 0 || lutEngine.beautyIntensity > 0
        let needsFilter = hasLUTFilter || hasEffect

        let outputBuffer: CVPixelBuffer
        if needsFilter {
            var ciImage = CIImage(cvPixelBuffer: pixelBuffer)
            ciImage = lutEngine.apply(to: ciImage)

            // extent 대신 원본 버퍼 크기 사용 (CIFilter extent 변동 방지)
            let outW = CVPixelBufferGetWidth(pixelBuffer)
            let outH = CVPixelBufferGetHeight(pixelBuffer)
            var processed: CVPixelBuffer?
            let attrs: [String: Any] = [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
                kCVPixelBufferMetalCompatibilityKey as String: true,
                kCVPixelBufferIOSurfacePropertiesKey as String: [:],
            ]
            let status = CVPixelBufferCreate(kCFAllocatorDefault, outW, outH,
                                kCVPixelFormatType_32BGRA, attrs as CFDictionary, &processed)
            if status == kCVReturnSuccess, let proc = processed {
                MFLUTEngine.ciContext.render(ciImage, to: proc,
                                             bounds: CGRect(x: 0, y: 0, width: outW, height: outH),
                                             colorSpace: CGColorSpaceCreateDeviceRGB())
                outputBuffer = proc
            } else {
                print("[MFCameraSession] CVPixelBufferCreate 실패: \(status)")
                outputBuffer = pixelBuffer
            }
        } else {
            outputBuffer = pixelBuffer
        }

        // 무음 촬영을 위한 최신 버퍼 저장
        latestProcessedBuffer = outputBuffer

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

    // 사진 촬영 시 클래스 레벨 cropRect(for:imageSize:) 사용
    // (4032×3024 등 풀해상도에도 동일한 비율 로직 적용)

    func photoOutput(_ output: AVCapturePhotoOutput,
                     didFinishProcessingPhoto photo: AVCapturePhoto,
                     error: Error?) {
        if let error = error {
            delegate?.cameraSession(self, didFailWithError: error)
            return
        }

        guard let imageData = photo.fileDataRepresentation(),
              var ciImage = CIImage(data: imageData) else { return }
        // ciImage.extent = 카메라 raw landscape (e.g. iPhone 12: 4032×3024), origin (0,0)
        // UIImage.Orientation.right 적용 후 portrait 3:4로 표시됨 → 프리뷰(3:4 컨테이너)와 비율 일치

        // 사용자 지정 aspect ratio 크롭 (1:1, 9:16 등 선택 시 적용)
        if currentAspectRatio != "full" && currentAspectRatio != "16:9" {
            var ratioRect = cropRect(for: currentAspectRatio, imageSize: ciImage.extent.size)
            ratioRect = ratioRect.offsetBy(dx: ciImage.extent.origin.x, dy: ciImage.extent.origin.y)
            ciImage = ciImage.cropped(to: ratioRect)
        }

        // Step 3: LUT 필터 적용
        let filteredImage = lutEngine.apply(to: ciImage)

        // Step 4: CGImage → UIImage(portrait orientation) → JPEG
        // UIImage.jpegData()는 orientation을 EXIF에 포함 → 갤러리 표시 방향 정상
        guard let cgImg = MFLUTEngine.ciContext.createCGImage(
            filteredImage, from: filteredImage.extent) else { return }
        let orientation: UIImage.Orientation = isFront ? .leftMirrored : .right
        let uiImage = UIImage(cgImage: cgImg, scale: 1.0, orientation: orientation)
        guard let jpegData = uiImage.jpegData(compressionQuality: 0.95) else { return }

        // Step 5: 임시 파일 저장
        let tempDir = FileManager.default.temporaryDirectory
        let fileName = "moodfilm_\(Int(Date().timeIntervalSince1970)).jpg"
        let filePath = tempDir.appendingPathComponent(fileName)

        do {
            try jpegData.write(to: filePath)

            if livePhotoMovieURL != nil {
                // 라이브포토: MOV 파일이 완성될 때까지 대기
                // didFinishProcessingLivePhotoToMovieFileAt 콜백에서 최종 저장
                pendingLivePhotoJPEGPath = filePath.path
            } else {
                // 일반 촬영: 바로 저장
                delegate?.cameraSession(self, didCapturePhoto: filePath.path, livePhotoMovieURL: nil)
            }
        } catch {
            delegate?.cameraSession(self, didFailWithError: error)
        }
    }

    // MOV 파일 완성 콜백 — JPEG와 MOV 둘 다 준비됐을 때 delegate 호출
    func photoOutput(_ output: AVCapturePhotoOutput,
                     didFinishProcessingLivePhotoToMovieFileAt outputFileURL: URL,
                     duration: CMTime,
                     photoDisplayTime: CMTime,
                     resolvedSettings: AVCaptureResolvedPhotoSettings,
                     error: Error?) {
        guard let jpegPath = pendingLivePhotoJPEGPath else { return }
        pendingLivePhotoJPEGPath = nil
        livePhotoMovieURL = nil

        if let err = error {
            // MOV 실패 시 일반 사진으로 저장
            print("[MFCameraSession] Live Photo MOV 실패: \(err). 일반 사진으로 저장.")
            delegate?.cameraSession(self, didCapturePhoto: jpegPath, livePhotoMovieURL: nil)
        } else {
            delegate?.cameraSession(self, didCapturePhoto: jpegPath, livePhotoMovieURL: outputFileURL)
        }
    }
}
