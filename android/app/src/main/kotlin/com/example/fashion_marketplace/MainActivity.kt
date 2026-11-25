package com.example.fashion_marketplace

import android.media.AudioManager
import android.media.ToneGenerator
import android.os.Build
import android.os.Bundle
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var bodyAnalysis: BodyAnalysisHandler? = null
    private var viduLiveRtc: ViduLiveRtcHandler? = null
    private var toneGenerator: ToneGenerator? = null

    private fun getToneGenerator(): ToneGenerator? {
        if (toneGenerator == null) {
            toneGenerator = try {
                ToneGenerator(AudioManager.STREAM_MUSIC, 65)
            } catch (_: Throwable) {
                null
            }
        }
        return toneGenerator
    }

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

        val viduHandler = ViduLiveRtcHandler(applicationContext)
        viduLiveRtc = viduHandler
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "fashion/vidu_rtc/methods")
            .setMethodCallHandler(viduHandler)
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, "fashion/vidu_rtc/events")
            .setStreamHandler(viduHandler)
        flutterEngine.platformViewsController.registry.registerViewFactory(
            "fashion/vidu_rtc_view",
            ViduRtcViewFactory(viduHandler),
        )

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "fashion/tryon_sound")
            .setMethodCallHandler { call, result ->
                try {
                    when (call.method) {
                        "tick" -> {
                            getToneGenerator()?.startTone(ToneGenerator.TONE_PROP_BEEP, 55)
                            result.success(null)
                        }
                        "go" -> {
                            getToneGenerator()?.startTone(ToneGenerator.TONE_PROP_ACK, 130)
                            result.success(null)
                        }
                        else -> result.notImplemented()
                    }
                } catch (_: Throwable) {
                    result.success(null)
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "fashion/screen_brightness")
            .setMethodCallHandler { call, result ->
                runOnUiThread {
                    try {
                        val attrs = window.attributes
                        when (call.method) {
                            "setMax" -> {
                                attrs.screenBrightness = 1.0f
                                window.attributes = attrs
                                result.success(null)
                            }
                            "restore" -> {
                                attrs.screenBrightness =
                                    WindowManager.LayoutParams.BRIGHTNESS_OVERRIDE_NONE
                                window.attributes = attrs
                                result.success(null)
                            }
                            else -> result.notImplemented()
                        }
                    } catch (_: Throwable) {
                        result.success(null)
                    }
                }
            }
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "fashion/body_analysis")
            .setMethodCallHandler(null)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "fashion/vidu_rtc/methods")
            .setMethodCallHandler(null)
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, "fashion/vidu_rtc/events")
            .setStreamHandler(null)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "fashion/tryon_sound")
            .setMethodCallHandler(null)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "fashion/screen_brightness")
            .setMethodCallHandler(null)
        viduLiveRtc?.dispose()
        viduLiveRtc = null
        try {
            toneGenerator?.release()
        } catch (_: Throwable) {}
        toneGenerator = null
        bodyAnalysis?.dispose()
        bodyAnalysis = null
        super.cleanUpFlutterEngine(flutterEngine)
    }
}
