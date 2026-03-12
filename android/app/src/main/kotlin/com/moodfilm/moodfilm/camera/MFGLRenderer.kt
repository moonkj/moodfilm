package com.moodfilm.moodfilm.camera

import android.graphics.SurfaceTexture
import android.opengl.EGL14
import android.opengl.EGLConfig
import android.opengl.EGLContext
import android.opengl.EGLDisplay
import android.opengl.EGLExt
import android.opengl.EGLSurface
import android.opengl.GLES11Ext
import android.opengl.GLES30
import android.os.Handler
import android.os.HandlerThread
import android.view.Surface
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.nio.FloatBuffer

/**
 * OpenGL ES 3.0 기반 카메라 렌더링 엔진
 *
 * 파이프라인:
 *   카메라 → cameraSurfaceTexture (External OES) → GLSL LUT+이펙트 → Flutter SurfaceTexture
 *
 * iOS 대응: MFLUTEngine.apply(to:) + CIContext.render() 전체 파이프라인
 */
class MFGLRenderer(private val outputSurfaceTexture: SurfaceTexture) {

    // ─── EGL 상태 ────────────────────────────────────────────────────────────
    private var eglDisplay: EGLDisplay = EGL14.EGL_NO_DISPLAY
    private var eglContext: EGLContext = EGL14.EGL_NO_CONTEXT
    private var eglSurface: EGLSurface = EGL14.EGL_NO_SURFACE
    private var eglConfig: EGLConfig? = null

    // ─── GL 리소스 ───────────────────────────────────────────────────────────
    private var shaderProgram: Int = 0
    private var vbo: Int = 0

    // Uniform locations
    private var uTexTransform: Int = -1
    private var uCameraTexture: Int = -1
    private var uLutTexture: Int = -1
    private var uHasLUT: Int = -1
    private var uLutIntensity: Int = -1
    private var uBrightness: Int = -1
    private var uContrast: Int = -1
    private var uSaturation: Int = -1
    private var uGlowIntensity: Int = -1
    private var uGrainIntensity: Int = -1
    private var uBeautyIntensity: Int = -1
    private var uSoftnessIntensity: Int = -1
    private var uLightLeakIntensity: Int = -1
    private var uTime: Int = -1
    private var uSplitPosition: Int = -1
    private var uIsFrontCamera: Int = -1

    // ─── 카메라 입력 External OES 텍스처 ────────────────────────────────────
    private var cameraTextureId: Int = 0
    private var cameraSurfaceTexture: SurfaceTexture? = null

    // SurfaceTexture 변환 행렬 (카메라 버퍼 → 텍스처 좌표 보정)
    private val texTransformMatrix = FloatArray(16)

    // ─── LUT 텍스처 ─────────────────────────────────────────────────────────
    private var lutTextureId: Int = 0
    var hasLUT: Boolean = false

    // ─── 이펙트 상태 (iOS MFLUTEngine 프로퍼티 대응) ─────────────────────────
    @Volatile var lutIntensity: Float = 0f
    @Volatile var brightness: Float = 0f
    @Volatile var contrast: Float = 0f
    @Volatile var saturation: Float = 0f
    @Volatile var glowIntensity: Float = 0f
    @Volatile var grainIntensity: Float = 0f
    @Volatile var beautyIntensity: Float = 0f
    @Volatile var softnessIntensity: Float = 0f
    @Volatile var lightLeakIntensity: Float = 0f
    @Volatile var splitPosition: Float = -1f
    @Volatile var isFrontCamera: Boolean = true

    private var frameCount: Int = 0

    // ─── GL 전용 스레드 ──────────────────────────────────────────────────────
    private var glThread: HandlerThread? = null
    private var glHandler: Handler? = null

    // ─── Vertex Shader ───────────────────────────────────────────────────────
    private val VERTEX_SHADER = """
        #version 300 es
        in vec2 aPosition;
        uniform mat4 uTexTransform;
        out vec2 vTexCoord;
        void main() {
            gl_Position = vec4(aPosition, 0.0, 1.0);
            vec4 tc = uTexTransform * vec4(aPosition.x * 0.5 + 0.5, aPosition.y * 0.5 + 0.5, 0.0, 1.0);
            vTexCoord = tc.xy;
        }
    """.trimIndent()

    // ─── Fragment Shader (LUT 3D + 전체 이펙트 파이프라인) ───────────────────
    private val FRAGMENT_SHADER = """
        #version 300 es
        #extension GL_OES_EGL_image_external_essl3 : require
        precision mediump float;

        uniform samplerExternalOES uCameraTexture;
        uniform highp sampler3D uLutTexture;
        uniform bool uHasLUT;
        uniform float uLutIntensity;
        uniform float uBrightness;
        uniform float uContrast;
        uniform float uSaturation;
        uniform float uGlowIntensity;
        uniform float uGrainIntensity;
        uniform float uBeautyIntensity;
        uniform float uSoftnessIntensity;
        uniform float uLightLeakIntensity;
        uniform float uTime;
        uniform float uSplitPosition;
        uniform bool uIsFrontCamera;

        in vec2 vTexCoord;
        out vec4 fragColor;

        // 33×33×33 LUT trilinear 샘플링 (GPU가 자동 처리)
        vec3 applyLUT(vec3 color) {
            float scale = 32.0 / 33.0;
            float offset = 0.5 / 33.0;
            return texture(uLutTexture, color * scale + offset).rgb;
        }

        vec3 adjustSaturation(vec3 color, float amount) {
            float gray = dot(color, vec3(0.299, 0.587, 0.114));
            return mix(vec3(gray), color, 1.0 + amount);
        }

        // Screen 블렌드 모드 (Light Leak)
        vec3 screenBlend(vec3 base, vec3 top, float alpha) {
            vec3 screen = 1.0 - (1.0 - base) * (1.0 - top);
            return mix(base, screen, alpha);
        }

        // 간단한 해시 (Film Grain 노이즈)
        float hash(vec2 p) {
            return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
        }

        void main() {
            vec2 uv = vTexCoord;

            // 항상 원본 샘플링 (split 모드에서 참조)
            vec3 original = texture(uCameraTexture, uv).rgb;
            vec3 rgb = original;

            // 1. LUT 적용 (iOS MFLUTEngine.apply step 1)
            if (uHasLUT && uLutIntensity > 0.0) {
                vec3 lutColor = applyLUT(rgb);
                rgb = mix(rgb, lutColor, uLutIntensity);
            }

            // 2. Brightness (iOS: brightnessIntensity * 0.5 → CIColorControls)
            rgb += uBrightness * 0.5;

            // 3. Contrast (iOS: 1.0 + contrastIntensity → CIColorControls)
            rgb = (rgb - 0.5) * (1.0 + uContrast) + 0.5;

            // 4. Saturation (iOS: 1.0 + saturationIntensity → CIColorControls)
            if (uSaturation != 0.0) {
                rgb = adjustSaturation(rgb, uSaturation);
            }

            // 5. Softness 솜결 (iOS: Gaussian Blur + alpha blend * 0.75)
            //    GPU Blur는 비용이 크므로 채도감소 + 밝기 미세 보정으로 근사
            if (uSoftnessIntensity > 0.0) {
                vec3 soft = adjustSaturation(rgb, -uSoftnessIntensity * 0.1);
                soft += uSoftnessIntensity * 0.04;
                rgb = mix(rgb, soft, uSoftnessIntensity * 0.75);
            }

            // 6. Glow 드리미글로우 (iOS: CIBloom + Gaussian + Overlay)
            //    밝은 영역 추출 후 overlay blend 근사
            if (uGlowIntensity > 0.0) {
                // 지수 곡선(x^1.5): 낮은 값 부드럽게, 1.0에서 최대
                float easedGlow = uGlowIntensity * sqrt(uGlowIntensity);
                vec3 bright = max(rgb - 0.5, 0.0) * 2.0;
                // Overlay blend
                vec3 overlay = mix(
                    2.0 * rgb * bright,
                    1.0 - 2.0 * (1.0 - rgb) * (1.0 - bright),
                    step(0.5, bright)
                );
                rgb = mix(rgb, overlay, easedGlow * 0.5);
            }

            // 7. Film Grain (iOS: CIRandomGenerator + Soft Light blend)
            if (uGrainIntensity > 0.0) {
                float noise = hash(uv + vec2(uTime * 0.01)) * 2.0 - 1.0;
                rgb += noise * uGrainIntensity * 0.12;
            }

            // 8. Beauty 뽀샤시 (iOS: blur 45% + brightness + saturation + bloom)
            if (uBeautyIntensity > 0.0) {
                rgb += uBeautyIntensity * 0.08;
                // 따뜻한 피부톤 (약간 주황 방향)
                rgb.r += uBeautyIntensity * 0.02;
                rgb.b -= uBeautyIntensity * 0.01;
                rgb = adjustSaturation(rgb, uBeautyIntensity * 0.06);
                // 은은한 bloom 근사 (중앙 밝게)
                float dist = length(uv - 0.5) * 2.0;
                rgb += (1.0 - dist * 0.7) * uBeautyIntensity * 0.03;
            }

            // 9. Light Leak (iOS: CIRadialGradient + Screen blend)
            if (uLightLeakIntensity > 0.0) {
                // 좌상단 주황
                float d1 = length(uv - vec2(0.1, 0.9));
                float leak1 = smoothstep(0.55, 0.0, d1) * uLightLeakIntensity * 0.65;
                rgb = screenBlend(rgb, vec3(1.0, 0.68, 0.25), leak1);
                // 우하단 노랑
                float d2 = length(uv - vec2(0.92, 0.12));
                float leak2 = smoothstep(0.35, 0.0, d2) * uLightLeakIntensity * 0.45;
                rgb = screenBlend(rgb, vec3(1.0, 0.85, 0.35), leak2);
            }

            rgb = clamp(rgb, 0.0, 1.0);

            // 10. Before/After Split (iOS: applyBeforeAfterSplit)
            // 버퍼는 landscape(1920×1080), RotatedBox(CW90°)으로 portrait 표시
            // tex Y축 = display X축
            // back:  low Y→display 왼쪽(원본), high Y→display 오른쪽(필터)
            // front: low Y→display 오른쪽(필터, 미러 후), high Y→display 왼쪽(원본)
            if (uSplitPosition >= 0.0) {
                bool showOriginal;
                if (uIsFrontCamera) {
                    showOriginal = (uv.y >= uSplitPosition);
                } else {
                    showOriginal = (uv.y < (1.0 - uSplitPosition));
                }
                fragColor = vec4(showOriginal ? original : rgb, 1.0);
            } else {
                fragColor = vec4(rgb, 1.0);
            }
        }
    """.trimIndent()

    // ─── 퍼블릭 API ─────────────────────────────────────────────────────────

    /**
     * GL 스레드 시작 + EGL/OpenGL 초기화
     * [onCameraInputSurfaceReady]: GL 준비 완료 후 카메라가 연결할 Surface 반환
     */
    fun start(onCameraInputSurfaceReady: (Surface) -> Unit) {
        glThread = HandlerThread("mf-gl-render").also { it.start() }
        glHandler = Handler(glThread!!.looper)

        glHandler!!.post {
            initEGL()
            initGL()
            createCameraInputTexture(onCameraInputSurfaceReady)
        }
    }

    /** LUT 3D 텍스처 업로드 (GL 스레드에서 호출) */
    fun uploadLUT(cubeData: FloatArray, size: Int) {
        glHandler?.post {
            // 기존 텍스처 삭제
            if (lutTextureId != 0) {
                GLES30.glDeleteTextures(1, intArrayOf(lutTextureId), 0)
            }
            val texIds = IntArray(1)
            GLES30.glGenTextures(1, texIds, 0)
            lutTextureId = texIds[0]

            GLES30.glBindTexture(GLES30.GL_TEXTURE_3D, lutTextureId)
            GLES30.glTexParameteri(GLES30.GL_TEXTURE_3D, GLES30.GL_TEXTURE_MIN_FILTER, GLES30.GL_LINEAR)
            GLES30.glTexParameteri(GLES30.GL_TEXTURE_3D, GLES30.GL_TEXTURE_MAG_FILTER, GLES30.GL_LINEAR)
            GLES30.glTexParameteri(GLES30.GL_TEXTURE_3D, GLES30.GL_TEXTURE_WRAP_S, GLES30.GL_CLAMP_TO_EDGE)
            GLES30.glTexParameteri(GLES30.GL_TEXTURE_3D, GLES30.GL_TEXTURE_WRAP_T, GLES30.GL_CLAMP_TO_EDGE)
            GLES30.glTexParameteri(GLES30.GL_TEXTURE_3D, GLES30.GL_TEXTURE_WRAP_R, GLES30.GL_CLAMP_TO_EDGE)

            val buf = ByteBuffer.allocateDirect(cubeData.size * 4)
                .order(ByteOrder.nativeOrder())
                .asFloatBuffer()
                .put(cubeData)
            buf.position(0)

            // GL_RGB16F: half-float 정밀도, ES 3.0에서 LINEAR 필터 지원
            GLES30.glTexImage3D(
                GLES30.GL_TEXTURE_3D, 0, GLES30.GL_RGB16F,
                size, size, size, 0,
                GLES30.GL_RGB, GLES30.GL_FLOAT, buf
            )
            hasLUT = true
        }
    }

    /** LUT 초기화 */
    fun clearLUT() {
        glHandler?.post {
            hasLUT = false
            lutIntensity = 0f
        }
    }

    /** 리소스 해제 */
    fun release() {
        glHandler?.post {
            if (lutTextureId != 0) GLES30.glDeleteTextures(1, intArrayOf(lutTextureId), 0)
            if (cameraTextureId != 0) GLES30.glDeleteTextures(1, intArrayOf(cameraTextureId), 0)
            if (shaderProgram != 0) GLES30.glDeleteProgram(shaderProgram)
            if (vbo != 0) GLES30.glDeleteBuffers(1, intArrayOf(vbo), 0)
            cameraSurfaceTexture?.release()
            EGL14.eglMakeCurrent(eglDisplay, EGL14.EGL_NO_SURFACE, EGL14.EGL_NO_SURFACE, EGL14.EGL_NO_CONTEXT)
            EGL14.eglDestroySurface(eglDisplay, eglSurface)
            EGL14.eglDestroyContext(eglDisplay, eglContext)
            EGL14.eglTerminate(eglDisplay)
        }
        glThread?.quitSafely()
    }

    // ─── 내부 구현 ───────────────────────────────────────────────────────────

    private fun initEGL() {
        eglDisplay = EGL14.eglGetDisplay(EGL14.EGL_DEFAULT_DISPLAY)
        EGL14.eglInitialize(eglDisplay, null, 0, null, 0)

        // OpenGL ES 3.0 config (EGL_OPENGL_ES3_BIT = 0x40)
        val attribList = intArrayOf(
            EGL14.EGL_RED_SIZE, 8,
            EGL14.EGL_GREEN_SIZE, 8,
            EGL14.EGL_BLUE_SIZE, 8,
            EGL14.EGL_ALPHA_SIZE, 8,
            EGL14.EGL_RENDERABLE_TYPE, EGLExt.EGL_OPENGL_ES3_BIT_KHR,
            EGL14.EGL_NONE
        )
        val configs = arrayOfNulls<EGLConfig>(1)
        val numConfigs = IntArray(1)
        EGL14.eglChooseConfig(eglDisplay, attribList, 0, configs, 0, 1, numConfigs, 0)
        eglConfig = configs[0]!!

        val contextAttribs = intArrayOf(EGL14.EGL_CONTEXT_CLIENT_VERSION, 3, EGL14.EGL_NONE)
        eglContext = EGL14.eglCreateContext(eglDisplay, eglConfig, EGL14.EGL_NO_CONTEXT, contextAttribs, 0)

        // Flutter의 SurfaceTexture를 렌더링 대상으로 설정
        outputSurfaceTexture.setDefaultBufferSize(1920, 1080)
        val surfaceAttribs = intArrayOf(EGL14.EGL_NONE)
        eglSurface = EGL14.eglCreateWindowSurface(eglDisplay, eglConfig, outputSurfaceTexture, surfaceAttribs, 0)

        EGL14.eglMakeCurrent(eglDisplay, eglSurface, eglSurface, eglContext)
    }

    private fun initGL() {
        shaderProgram = createProgram(VERTEX_SHADER, FRAGMENT_SHADER)

        // Uniform 위치 캐시
        uTexTransform = GLES30.glGetUniformLocation(shaderProgram, "uTexTransform")
        uCameraTexture = GLES30.glGetUniformLocation(shaderProgram, "uCameraTexture")
        uLutTexture = GLES30.glGetUniformLocation(shaderProgram, "uLutTexture")
        uHasLUT = GLES30.glGetUniformLocation(shaderProgram, "uHasLUT")
        uLutIntensity = GLES30.glGetUniformLocation(shaderProgram, "uLutIntensity")
        uBrightness = GLES30.glGetUniformLocation(shaderProgram, "uBrightness")
        uContrast = GLES30.glGetUniformLocation(shaderProgram, "uContrast")
        uSaturation = GLES30.glGetUniformLocation(shaderProgram, "uSaturation")
        uGlowIntensity = GLES30.glGetUniformLocation(shaderProgram, "uGlowIntensity")
        uGrainIntensity = GLES30.glGetUniformLocation(shaderProgram, "uGrainIntensity")
        uBeautyIntensity = GLES30.glGetUniformLocation(shaderProgram, "uBeautyIntensity")
        uSoftnessIntensity = GLES30.glGetUniformLocation(shaderProgram, "uSoftnessIntensity")
        uLightLeakIntensity = GLES30.glGetUniformLocation(shaderProgram, "uLightLeakIntensity")
        uTime = GLES30.glGetUniformLocation(shaderProgram, "uTime")
        uSplitPosition = GLES30.glGetUniformLocation(shaderProgram, "uSplitPosition")
        uIsFrontCamera = GLES30.glGetUniformLocation(shaderProgram, "uIsFrontCamera")

        // Fullscreen quad VBO [-1,-1] ~ [1,1]
        val quadVertices = floatArrayOf(-1f, -1f, 1f, -1f, -1f, 1f, 1f, 1f)
        val vbos = IntArray(1)
        GLES30.glGenBuffers(1, vbos, 0)
        vbo = vbos[0]
        GLES30.glBindBuffer(GLES30.GL_ARRAY_BUFFER, vbo)
        val vertexBuf = ByteBuffer.allocateDirect(quadVertices.size * 4)
            .order(ByteOrder.nativeOrder()).asFloatBuffer().put(quadVertices)
        vertexBuf.position(0)
        GLES30.glBufferData(GLES30.GL_ARRAY_BUFFER, quadVertices.size * 4, vertexBuf, GLES30.GL_STATIC_DRAW)
    }

    private fun createCameraInputTexture(onReady: (Surface) -> Unit) {
        // External OES 텍스처 생성 (카메라 입력)
        val texIds = IntArray(1)
        GLES30.glGenTextures(1, texIds, 0)
        cameraTextureId = texIds[0]
        GLES30.glBindTexture(GLES11Ext.GL_TEXTURE_EXTERNAL_OES, cameraTextureId)
        GLES30.glTexParameteri(GLES11Ext.GL_TEXTURE_EXTERNAL_OES, GLES30.GL_TEXTURE_MIN_FILTER, GLES30.GL_LINEAR)
        GLES30.glTexParameteri(GLES11Ext.GL_TEXTURE_EXTERNAL_OES, GLES30.GL_TEXTURE_MAG_FILTER, GLES30.GL_LINEAR)

        cameraSurfaceTexture = SurfaceTexture(cameraTextureId).also { st ->
            st.setDefaultBufferSize(1920, 1080)
            // 새 카메라 프레임 도착 시 GL 스레드에서 바로 렌더링
            st.setOnFrameAvailableListener({ renderFrame() }, glHandler!!)
        }

        val inputSurface = Surface(cameraSurfaceTexture!!)
        // 메인 스레드로 콜백 (CameraX는 메인 스레드에서 Surface 제공)
        android.os.Handler(android.os.Looper.getMainLooper()).post {
            onReady(inputSurface)
        }
    }

    /** 카메라 프레임 → GL 렌더링 → Flutter SurfaceTexture 갱신 */
    fun renderFrame() {
        cameraSurfaceTexture?.updateTexImage()
        cameraSurfaceTexture?.getTransformMatrix(texTransformMatrix)

        GLES30.glViewport(0, 0, 1920, 1080)
        GLES30.glClearColor(0f, 0f, 0f, 1f)
        GLES30.glClear(GLES30.GL_COLOR_BUFFER_BIT)

        GLES30.glUseProgram(shaderProgram)

        // 텍스처 0: 카메라 External OES
        GLES30.glActiveTexture(GLES30.GL_TEXTURE0)
        GLES30.glBindTexture(GLES11Ext.GL_TEXTURE_EXTERNAL_OES, cameraTextureId)
        GLES30.glUniform1i(uCameraTexture, 0)
        GLES30.glUniformMatrix4fv(uTexTransform, 1, false, texTransformMatrix, 0)

        // 텍스처 1: LUT 3D
        GLES30.glActiveTexture(GLES30.GL_TEXTURE1)
        GLES30.glBindTexture(GLES30.GL_TEXTURE_3D, if (hasLUT) lutTextureId else 0)
        GLES30.glUniform1i(uLutTexture, 1)
        GLES30.glUniform1i(uHasLUT, if (hasLUT && lutIntensity > 0f) 1 else 0)
        GLES30.glUniform1f(uLutIntensity, lutIntensity)

        // 이펙트 uniforms
        GLES30.glUniform1f(uBrightness, brightness)
        GLES30.glUniform1f(uContrast, contrast)
        GLES30.glUniform1f(uSaturation, saturation)
        GLES30.glUniform1f(uGlowIntensity, glowIntensity)
        GLES30.glUniform1f(uGrainIntensity, grainIntensity)
        GLES30.glUniform1f(uBeautyIntensity, beautyIntensity)
        GLES30.glUniform1f(uSoftnessIntensity, softnessIntensity)
        GLES30.glUniform1f(uLightLeakIntensity, lightLeakIntensity)
        GLES30.glUniform1f(uTime, (frameCount++ % 10000).toFloat())
        GLES30.glUniform1f(uSplitPosition, splitPosition)
        GLES30.glUniform1i(uIsFrontCamera, if (isFrontCamera) 1 else 0)

        // Fullscreen quad 드로우
        GLES30.glBindBuffer(GLES30.GL_ARRAY_BUFFER, vbo)
        val posLoc = GLES30.glGetAttribLocation(shaderProgram, "aPosition")
        GLES30.glEnableVertexAttribArray(posLoc)
        GLES30.glVertexAttribPointer(posLoc, 2, GLES30.GL_FLOAT, false, 8, 0)
        GLES30.glDrawArrays(GLES30.GL_TRIANGLE_STRIP, 0, 4)
        GLES30.glDisableVertexAttribArray(posLoc)

        EGL14.eglSwapBuffers(eglDisplay, eglSurface)
    }

    // ─── 쉐이더 컴파일 유틸 ─────────────────────────────────────────────────

    private fun compileShader(type: Int, src: String): Int {
        val shader = GLES30.glCreateShader(type)
        GLES30.glShaderSource(shader, src)
        GLES30.glCompileShader(shader)
        val status = IntArray(1)
        GLES30.glGetShaderiv(shader, GLES30.GL_COMPILE_STATUS, status, 0)
        if (status[0] == 0) {
            val log = GLES30.glGetShaderInfoLog(shader)
            GLES30.glDeleteShader(shader)
            throw RuntimeException("[MFGLRenderer] 쉐이더 컴파일 실패: $log")
        }
        return shader
    }

    private fun createProgram(vertSrc: String, fragSrc: String): Int {
        val vert = compileShader(GLES30.GL_VERTEX_SHADER, vertSrc)
        val frag = compileShader(GLES30.GL_FRAGMENT_SHADER, fragSrc)
        val prog = GLES30.glCreateProgram()
        GLES30.glAttachShader(prog, vert)
        GLES30.glAttachShader(prog, frag)
        GLES30.glLinkProgram(prog)
        val status = IntArray(1)
        GLES30.glGetProgramiv(prog, GLES30.GL_LINK_STATUS, status, 0)
        if (status[0] == 0) {
            val log = GLES30.glGetProgramInfoLog(prog)
            GLES30.glDeleteProgram(prog)
            throw RuntimeException("[MFGLRenderer] 프로그램 링크 실패: $log")
        }
        GLES30.glDeleteShader(vert)
        GLES30.glDeleteShader(frag)
        return prog
    }
}
