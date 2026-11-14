package com.example.fashion_marketplace

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.os.Handler
import android.os.Looper
import com.google.mediapipe.framework.image.BitmapImageBuilder
import com.google.mediapipe.tasks.core.BaseOptions
import com.google.mediapipe.tasks.vision.core.RunningMode
import com.google.mediapipe.tasks.vision.poselandmarker.PoseLandmarker
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.concurrent.Executors

/** Serial inference off the UI thread; never opens a second camera or uploads images. */
class BodyAnalysisHandler(private val context: Context) : MethodChannel.MethodCallHandler {
    private val executor = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())
    private var detector: PoseLandmarker? = null

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "analyze" -> {
                val bytes = call.arguments as? ByteArray
                if (bytes == null || bytes.size > 12 * 1024 * 1024) {
                    result.error("invalid_frame", "Invalid frame", null)
                    return
                }
                executor.execute {
                    try {
                        if (detector == null) {
                            val options = PoseLandmarker.PoseLandmarkerOptions.builder()
                                .setBaseOptions(BaseOptions.builder()
                                    .setModelAssetPath("flutter_assets/assets/models/pose_landmarker_lite.task")
                                    .build())
                                .setRunningMode(RunningMode.IMAGE)
                                .setNumPoses(3)
                                .setMinPoseDetectionConfidence(0.5f)
                                .setMinPosePresenceConfidence(0.5f)
                                .build()
                            detector = PoseLandmarker.createFromOptions(context, options)
                        }
                        val decoded = BitmapFactory.decodeByteArray(bytes, 0, bytes.size)
                            ?: error("Unreadable frame")
                        val scale = minOf(1f, 640f / maxOf(decoded.width, decoded.height))
                        val bitmap = if (scale < 1f) Bitmap.createScaledBitmap(decoded,
                            (decoded.width * scale).toInt(), (decoded.height * scale).toInt(), true)
                            else decoded
                        val image = BitmapImageBuilder(bitmap).build()
                        val poses = try {
                            detector!!.detect(image).landmarks().map { pose ->
                                pose.map { point -> mapOf(
                                    "x" to point.x().toDouble(), "y" to point.y().toDouble(),
                                    "z" to point.z().toDouble(),
                                    "visibility" to minOf(point.visibility().orElse(0f),
                                        point.presence().orElse(0f)).toDouble()) }
                            }
                        } finally {
                            image.close()
                            if (bitmap !== decoded) bitmap.recycle()
                            decoded.recycle()
                        }
                        main.post { result.success(poses) }
                    } catch (_: Throwable) {
                        main.post { result.error("analysis_failed", "Body analysis unavailable", null) }
                    } finally {
                        // flutter_webrtc 0.12 writes its snapshot here; remove it after use.
                        File(context.cacheDir, "captureFrame.png").delete()
                    }
                }
            }
            "close" -> executor.execute {
                try {
                    detector?.close()
                } catch (_: Throwable) {}
                detector = null
                File(context.cacheDir, "captureFrame.png").delete()
                main.post { result.success(null) }
            }
            else -> result.notImplemented()
        }
    }

    fun dispose() {
        executor.execute {
            try {
                detector?.close()
            } catch (_: Throwable) {}
            detector = null
        }
        executor.shutdown()
    }
}
