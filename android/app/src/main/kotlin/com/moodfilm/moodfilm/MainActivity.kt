package com.moodfilm.moodfilm

import com.moodfilm.moodfilm.camera.CameraEnginePlugin
import com.moodfilm.moodfilm.filter.FilterEnginePlugin
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        flutterEngine.plugins.add(CameraEnginePlugin())
        flutterEngine.plugins.add(FilterEnginePlugin())
    }
}
