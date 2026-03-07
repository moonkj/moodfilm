import AVFoundation
import CoreImage

/// LUT 필터 적용된 영상을 AVAssetWriter로 파일에 저장
/// MFCameraSession에서 각 프레임(CVPixelBuffer + CMSampleBuffer)을 받아 처리
class MFVideoRecorder: NSObject {

    private var assetWriter: AVAssetWriter?
    private var videoInput: AVAssetWriterInput?
    private var audioInput: AVAssetWriterInput?
    private var adaptor: AVAssetWriterInputPixelBufferAdaptor?

    private(set) var isRecording = false
    private var sessionStarted = false
    private var startTime: CMTime = .invalid
    private var outputURL: URL?
    private var stopCompletion: ((URL?) -> Void)?

    // MARK: - 녹화 시작

    func startRecording(outputPath: String, videoSize: CGSize) {
        guard !isRecording else { return }

        let url = URL(fileURLWithPath: outputPath)
        // 기존 파일 제거
        try? FileManager.default.removeItem(at: url)

        guard let writer = try? AVAssetWriter(outputURL: url, fileType: .mp4) else {
            print("[MFVideoRecorder] AVAssetWriter 생성 실패")
            return
        }

        // 영상 입력 설정 (H.264, 1080p)
        let width = Int(videoSize.width)
        let height = Int(videoSize.height)
        let videoSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: width,
            AVVideoHeightKey: height,
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: 10_000_000,
                AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
            ],
        ]
        let vInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        vInput.expectsMediaDataInRealTime = true
        // 세로 방향 보정 (카메라 버퍼는 가로 landscape로 들어옴)
        vInput.transform = CGAffineTransform(rotationAngle: .pi / 2)

        let pixelBufferAttrs: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: width,
            kCVPixelBufferHeightKey as String: height,
            kCVPixelBufferIOSurfacePropertiesKey as String: [:],
        ]
        let adapt = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: vInput,
            sourcePixelBufferAttributes: pixelBufferAttrs
        )

        // 오디오 입력 설정 (AAC)
        let audioSettings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: 44100.0,
            AVNumberOfChannelsKey: 1,
            AVEncoderBitRateKey: 96_000,
        ]
        let aInput = AVAssetWriterInput(mediaType: .audio, outputSettings: audioSettings)
        aInput.expectsMediaDataInRealTime = true

        if writer.canAdd(vInput) { writer.add(vInput) }
        if writer.canAdd(aInput) { writer.add(aInput) }

        writer.startWriting()

        assetWriter = writer
        videoInput = vInput
        audioInput = aInput
        adaptor = adapt
        outputURL = url
        sessionStarted = false
        isRecording = true
    }

    // MARK: - 영상 프레임 추가

    func appendVideoBuffer(_ buffer: CVPixelBuffer, timestamp: CMTime) {
        guard isRecording,
              let writer = assetWriter,
              let vInput = videoInput,
              let adapt = adaptor else { return }

        // 첫 프레임: 세션 시작 시간 고정
        if !sessionStarted {
            writer.startSession(atSourceTime: timestamp)
            startTime = timestamp
            sessionStarted = true
        }

        guard writer.status == .writing, vInput.isReadyForMoreMediaData else { return }
        adapt.append(buffer, withPresentationTime: timestamp)
    }

    // MARK: - 오디오 샘플 추가

    func appendAudioBuffer(_ sampleBuffer: CMSampleBuffer) {
        guard isRecording, sessionStarted,
              let writer = assetWriter,
              let aInput = audioInput,
              writer.status == .writing,
              aInput.isReadyForMoreMediaData else { return }

        // 세션 시작 시간(첫 비디오 프레임 PTS) 이전의 오디오 샘플 드롭
        // → AVAssetWriter는 startSession 이전 타임스탬프를 거부하고 .failed 상태로 전환됨
        let pts = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        guard CMTimeCompare(pts, startTime) >= 0 else { return }

        aInput.append(sampleBuffer)
    }

    // MARK: - 녹화 종료

    func stopRecording(completion: @escaping (URL?) -> Void) {
        guard isRecording, let writer = assetWriter else {
            completion(nil)
            return
        }

        isRecording = false
        let url = outputURL

        videoInput?.markAsFinished()
        audioInput?.markAsFinished()

        writer.finishWriting { [weak self] in
            guard let self = self else { return }
            let success = writer.status == .completed
            DispatchQueue.main.async {
                completion(success ? url : nil)
            }
            // 상태 초기화
            self.assetWriter = nil
            self.videoInput = nil
            self.audioInput = nil
            self.adaptor = nil
            self.outputURL = nil
            self.sessionStarted = false
        }
    }
}
