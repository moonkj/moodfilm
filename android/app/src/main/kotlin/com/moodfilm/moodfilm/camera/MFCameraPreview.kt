package com.moodfilm.moodfilm.camera

import android.graphics.SurfaceTexture
import io.flutter.view.TextureRegistry

/**
 * Flutter FlutterTexture 브릿지
 *
 * iOS MFCameraPreview.swift 대응:
 * - iOS: CVPixelBuffer → FlutterExternalTexture → textureId
 * - Android: SurfaceTexture → EGLWindowSurface (MFGLRenderer가 렌더링) → Flutter Texture widget
 *
 * Flutter Texture widget은 textureId로 이 SurfaceTexture를 읽는다.
 * MFGLRenderer.renderFrame()에서 EGL14.eglSwapBuffers() 호출 시 자동으로 프레임 갱신.
 */
class MFCameraPreview(textureRegistry: TextureRegistry) {

    private val surfaceTextureEntry: TextureRegistry.SurfaceTextureEntry =
        textureRegistry.createSurfaceTexture()

    /** Flutter Texture 위젯에 전달할 ID (iOS preview.textureId 대응) */
    val textureId: Long = surfaceTextureEntry.id()

    /** MFGLRenderer의 EGL 렌더링 대상 SurfaceTexture */
    fun getSurfaceTexture(): SurfaceTexture = surfaceTextureEntry.surfaceTexture()

    /** 리소스 해제 (iOS preview.dispose() 대응) */
    fun dispose() {
        surfaceTextureEntry.release()
    }
}
