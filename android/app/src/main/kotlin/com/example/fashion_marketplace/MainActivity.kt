package com.example.fashion_marketplace

import android.os.Build
import android.os.Bundle
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var bodyAnalysis: BodyAnalysisHandler? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Allow drawing into camera cutout area on devices with notches/hole punch
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            window.attributes.layoutInDisplayCutoutMode =
                WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_SHORT_EDGES
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        bodyAnalysis = BodyAnalysisHandler(applicationContext)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "fashion/body_analysis")
            .setMethodCallHandler(bodyAnalysis)
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "fashion/body_analysis")
            .setMethodCallHandler(null)
        bodyAnalysis?.dispose()
        bodyAnalysis = null
        super.cleanUpFlutterEngine(flutterEngine)
    }
}
