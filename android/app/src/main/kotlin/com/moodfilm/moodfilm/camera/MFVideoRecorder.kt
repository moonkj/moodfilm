package com.moodfilm.moodfilm.camera

import android.media.MediaCodec
import android.media.MediaCodecInfo
import android.media.MediaFormat
import android.media.MediaMuxer
import android.os.Handler
import android.os.HandlerThread
import android.util.Log

/**
 * MediaCodec + MediaMuxer 기반 동영상 녹화
 * iOS MFVideoRecorder.swift (AVAssetWriter + AVAssetWriterInput) 대응
 *
 * MVP: 별도 영상 인코딩 스레드에서 MediaCodec draining
 * 실제 비디오 데이터는 CameraX VideoCapture UseCase로 연결 (향후 개선)
 *
 * 현재 구현: 단순 파일 경로 관리 + 시작/정지 인터페이스 제공
 * (CameraX VideoCapture로의 전환은 W16에서 완성)
 */
class MFVideoRecorder {

    private var outputPath: String? = null
    private var startTimeMs: Long = 0
    var isRecording: Boolean = false
        private set

    private var drainThread: HandlerThread? = null
    private var drainHandler: Handler? = null

    private var mediaCodec: MediaCodec? = null
    private var mediaMuxer: MediaMuxer? = null
    private var videoTrackIndex: Int = -1
    private var muxerStarted: Boolean = false

    // 완료 콜백
    private var stopCallback: ((String?) -> Unit)? = null

    companion object {
        private const val TAG = "MFVideoRecorder"
        private const val MIME_TYPE = "video/avc" // H.264
        private const val BIT_RATE = 8_000_000    // 8 Mbps
        private const val FRAME_RATE = 30
        private const val I_FRAME_INTERVAL = 1
    }

    /**
     * 녹화 시작
     * iOS startRecording(outputPath:videoSize:) 대응
     */
    fun start(outputPath: String, width: Int = 1920, height: Int = 1080) {
        if (isRecording) return
        this.outputPath = outputPath
        this.startTimeMs = System.currentTimeMillis()

        try {
            setupMediaCodec(width, height)
            setupMediaMuxer(outputPath)
            startDrainThread()
            isRecording = true
            Log.d(TAG, "녹화 시작: $outputPath")
        } catch (e: Exception) {
            Log.e(TAG, "녹화 시작 실패: ${e.message}")
            release()
        }
    }

    /**
     * 녹화 정지
     * iOS stopRecording(completion:) 대응
     */
    fun stop(completion: (String?) -> Unit) {
        if (!isRecording) { completion(null); return }
        stopCallback = completion
        isRecording = false

        drainHandler?.post {
            try {
                drainEncoder(endOfStream = true)
                mediaMuxer?.stop()
                mediaMuxer?.release()
                Log.d(TAG, "녹화 완료: $outputPath")
                Handler(android.os.Looper.getMainLooper()).post {
                    completion(outputPath)
                }
            } catch (e: Exception) {
                Log.e(TAG, "녹화 정지 실패: ${e.message}")
                Handler(android.os.Looper.getMainLooper()).post {
                    completion(null)
                }
            } finally {
                release()
            }
        }
    }

    // ─── MediaCodec 설정 ──────────────────────────────────────────────────────

    private fun setupMediaCodec(width: Int, height: Int) {
        val format = MediaFormat.createVideoFormat(MIME_TYPE, width, height).apply {
            setInteger(MediaFormat.KEY_COLOR_FORMAT,
                MediaCodecInfo.CodecCapabilities.COLOR_FormatSurface)
            setInteger(MediaFormat.KEY_BIT_RATE, BIT_RATE)
            setInteger(MediaFormat.KEY_FRAME_RATE, FRAME_RATE)
            setInteger(MediaFormat.KEY_I_FRAME_INTERVAL, I_FRAME_INTERVAL)
        }

        mediaCodec = MediaCodec.createEncoderByType(MIME_TYPE).also { codec ->
            codec.configure(format, null, null, MediaCodec.CONFIGURE_FLAG_ENCODE)
            // NOTE: createInputSurface()는 GL 렌더링 연동 시 사용
            // 현재 MVP: CameraX와 별도 연동 없이 파일 경로만 관리
            codec.start()
        }
    }

    private fun setupMediaMuxer(outputPath: String) {
        mediaMuxer = MediaMuxer(outputPath, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)
    }

    // ─── Encoder Drain 스레드 ─────────────────────────────────────────────────

    private fun startDrainThread() {
        drainThread = HandlerThread("mf-video-drain").also { it.start() }
        drainHandler = Handler(drainThread!!.looper)
        scheduleDrain()
    }

    private fun scheduleDrain() {
        if (!isRecording) return
        drainHandler?.postDelayed({
            drainEncoder(endOfStream = false)
            scheduleDrain()
        }, 33) // ~30fps
    }

    private fun drainEncoder(endOfStream: Boolean) {
        val codec = mediaCodec ?: return
        val muxer = mediaMuxer ?: return

        if (endOfStream) {
            codec.signalEndOfInputStream()
        }

        val bufferInfo = MediaCodec.BufferInfo()
        while (true) {
            val encoderStatus = codec.dequeueOutputBuffer(bufferInfo, 10_000)
            when {
                encoderStatus == MediaCodec.INFO_TRY_AGAIN_LATER -> {
                    if (!endOfStream) break
                }
                encoderStatus == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED -> {
                    if (!muxerStarted) {
                        videoTrackIndex = muxer.addTrack(codec.outputFormat)
                        muxer.start()
                        muxerStarted = true
                    }
                }
                encoderStatus >= 0 -> {
                    val encodedData = codec.getOutputBuffer(encoderStatus) ?: continue

                    if (bufferInfo.flags and MediaCodec.BUFFER_FLAG_CODEC_CONFIG != 0) {
                        bufferInfo.size = 0
                    }

                    if (bufferInfo.size > 0 && muxerStarted) {
                        encodedData.position(bufferInfo.offset)
                        encodedData.limit(bufferInfo.offset + bufferInfo.size)
                        muxer.writeSampleData(videoTrackIndex, encodedData, bufferInfo)
                    }

                    codec.releaseOutputBuffer(encoderStatus, false)

                    if (bufferInfo.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0) break
                }
            }
        }
    }

    private fun release() {
        try { mediaCodec?.stop() } catch (_: Exception) {}
        try { mediaCodec?.release() } catch (_: Exception) {}
        mediaCodec = null
        mediaMuxer = null
        videoTrackIndex = -1
        muxerStarted = false
        drainThread?.quitSafely()
        drainThread = null
        drainHandler = null
    }
}
