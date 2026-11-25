package com.example.fashion_marketplace

import android.content.Context
import android.graphics.Color
import android.os.Handler
import android.os.Looper
import android.view.TextureView
import android.view.View
import android.view.ViewGroup
import android.widget.FrameLayout
import com.alivc.rtc.AliRtcEngine
import com.alivc.rtc.AliRtcEngineEventListener
import com.alivc.rtc.AliRtcEngineNotify
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory

/**
 * Native Android bridge for Vidu S2-Editing Real-Time Virtual Try-On (AliRTC).
 *
 * Renders both local camera preview and remote AI-edited video stream inside a
 * single Flutter PlatformView (`fashion/vidu_rtc_view`) using TextureViews so
 * Flutter overlays, animations, and instant before/after comparison work smoothly.
 */
class ViduLiveRtcHandler(private val appContext: Context) :
    MethodChannel.MethodCallHandler,
    EventChannel.StreamHandler {

    private val mainHandler = Handler(Looper.getMainLooper())
    private var engine: AliRtcEngine? = null
    private var eventSink: EventChannel.EventSink? = null

    private var containerView: FrameLayout? = null
    private var localTextureView: TextureView? = null
    private var remoteTextureView: TextureView? = null

    private var targetRenderUid: String = ""
    private var boundRemoteUid: String? = null
    private var hasRemoteFrame: Boolean = false
    private var showOriginal: Boolean = false
    private var isFrontCamera: Boolean = true
    private var previewStarted: Boolean = false
    private var joinedChannel: Boolean = false

    fun createPlatformView(context: Context): PlatformView {
        val root = FrameLayout(context).apply {
            setBackgroundColor(Color.BLACK)
            layoutParams = ViewGroup.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT,
            )
        }
        containerView = root
        ensureTextureViews(context)
        rebindViewsIfNeeded()
        if (previewStarted) {
            try {
                engine?.startPreview()
            } catch (_: Throwable) {}
        }

        return object : PlatformView {
            override fun getView(): View = root
            override fun dispose() {
                if (containerView === root) {
                    containerView = null
                    localTextureView = null
                    remoteTextureView = null
                }
            }
        }
    }

    private fun ensureTextureViews(context: Context) {
        val root = containerView ?: return
        if (localTextureView != null && remoteTextureView != null) return

        root.removeAllViews()
        val matchParent = FrameLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT,
            ViewGroup.LayoutParams.MATCH_PARENT,
        )

        val localTv = TextureView(context).apply {
            layoutParams = matchParent
            visibility = View.VISIBLE
        }
        val remoteTv = TextureView(context).apply {
            layoutParams = FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT,
            )
            visibility = if (hasRemoteFrame && !showOriginal) View.VISIBLE else View.INVISIBLE
        }

        root.addView(localTv)
        root.addView(remoteTv)
        localTextureView = localTv
        remoteTextureView = remoteTv
    }

    private fun rebindViewsIfNeeded() {
        val rtc = engine ?: return
        val localTv = localTextureView
        if (localTv != null) {
            val localCanvas = AliRtcEngine.AliRtcVideoCanvas().apply {
                view = localTv
                renderMode = AliRtcEngine.AliRtcRenderMode.AliRtcRenderModeClip
                mirrorMode = AliRtcEngine.AliRtcRenderMirrorMode.AliRtcRenderMirrorModeOnlyFront
            }
            rtc.setLocalViewConfig(localCanvas, AliRtcEngine.AliRtcVideoTrack.AliRtcVideoTrackCamera)
        }
        val uid = boundRemoteUid
        val remoteTv = remoteTextureView
        if (uid != null && remoteTv != null) {
            val remoteCanvas = AliRtcEngine.AliRtcVideoCanvas().apply {
                view = remoteTv
                renderMode = AliRtcEngine.AliRtcRenderMode.AliRtcRenderModeClip
                mirrorMode = AliRtcEngine.AliRtcRenderMirrorMode.AliRtcRenderMirrorModeAllDisable
            }
            rtc.setRemoteViewConfig(remoteCanvas, uid, AliRtcEngine.AliRtcVideoTrack.AliRtcVideoTrackCamera)
        }
        updateLayerVisibility()
    }

    private fun updateLayerVisibility() {
        mainHandler.post {
            val remoteTv = remoteTextureView ?: return@post
            remoteTv.visibility =
                if (hasRemoteFrame && !showOriginal) View.VISIBLE else View.INVISIBLE
        }
    }

    private fun emit(type: String, extras: Map<String, Any?> = emptyMap()) {
        mainHandler.post {
            val payload = HashMap<String, Any?>()
            payload["type"] = type
            payload.putAll(extras)
            eventSink?.success(payload)
        }
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "startPreview" -> {
                val preferFront = call.argument<Boolean>("useFrontCamera") ?: true
                mainHandler.post {
                    try {
                        startCameraPreview(preferFront)
                        result.success(true)
                    } catch (e: Throwable) {
                        result.error("preview_failed", e.message ?: "AliRTC preview failed", null)
                    }
                }
            }

            "join" -> {
                val token = call.argument<String>("token")?.trim().orEmpty()
                val channelId = call.argument<String>("channelId")?.trim().orEmpty()
                val userId = call.argument<String>("userId")?.trim().orEmpty()
                val renderUid = call.argument<String>("renderUid")?.trim().orEmpty()
                val dataSaver = call.argument<Boolean>("dataSaver") ?: true
                val preferFront = call.argument<Boolean>("useFrontCamera") ?: true
                if (token.isEmpty()) {
                    result.error("invalid_args", "Missing AliRTC token", null)
                    return
                }
                mainHandler.post {
                    try {
                        joinChannel(
                            token = token,
                            channelId = channelId,
                            userId = userId,
                            renderUid = renderUid,
                            dataSaver = dataSaver,
                            preferFront = preferFront,
                        )
                        result.success(true)
                    } catch (e: Throwable) {
                        result.error("join_failed", e.message ?: "AliRTC join failed", null)
                    }
                }
            }

            "switchCamera" -> {
                mainHandler.post {
                    try {
                        val rtc = engine
                        if (rtc != null) {
                            rtc.switchCamera()
                            val dir = rtc.currentCameraDirection
                            isFrontCamera =
                                dir != AliRtcEngine.AliRtcCameraDirection.CAMERA_REAR
                        } else {
                            isFrontCamera = !isFrontCamera
                        }
                        result.success(isFrontCamera)
                    } catch (e: Throwable) {
                        result.error("switch_camera_failed", e.message, null)
                    }
                }
            }

            "setShowOriginal" -> {
                val original = call.argument<Boolean>("showOriginal") ?: false
                showOriginal = original
                updateLayerVisibility()
                result.success(null)
            }

            "setBandwidthMode" -> {
                val dataSaver = call.argument<Boolean>("dataSaver") ?: true
                mainHandler.post {
                    try {
                        applyVideoEncoderProfile(dataSaver)
                        result.success(null)
                    } catch (e: Throwable) {
                        result.error("encoder_failed", e.message, null)
                    }
                }
            }

            "leave" -> {
                mainHandler.post {
                    teardownEngine()
                    result.success(null)
                }
            }

            else -> result.notImplemented()
        }
    }

    private fun applyVideoEncoderProfile(dataSaver: Boolean) {
        val rtc = engine ?: return
        val cfg = AliRtcEngine.AliRtcVideoEncoderConfiguration().apply {
            if (dataSaver) {
                dimensions = AliRtcEngine.AliRtcVideoDimensions(544, 952)
                frameRate = 15
                bitrate = 800
                minBitrate = 250
            } else {
                dimensions = AliRtcEngine.AliRtcVideoDimensions(720, 1280)
                frameRate = 24
                bitrate = 1800
                minBitrate = 500
            }
        }
        rtc.setVideoEncoderConfiguration(cfg)
    }

    private fun ensureEngine(): AliRtcEngine {
        val existing = engine
        if (existing != null) return existing
        val rtc = AliRtcEngine.getInstance(appContext)
            ?: throw IllegalStateException("AliRtcEngine unavailable")
        engine = rtc

        rtc.setRtcEngineEventListener(object : AliRtcEngineEventListener() {
            override fun onJoinChannelResult(
                result: Int,
                channel: String?,
                userIdCb: String?,
                elapsed: Int,
            ) {
                if (result == 0) {
                    emit("joined", mapOf("channel" to (channel ?: "")))
                } else {
                    emit(
                        "error",
                        mapOf("code" to result, "message" to "AliRTC join failed ($result)"),
                    )
                }
            }

            override fun onOccurError(error: Int, message: String?) {
                emit("error", mapOf("code" to error, "message" to (message ?: "RTC error $error")))
            }

            override fun onConnectionStatusChange(
                status: AliRtcEngine.AliRtcConnectionStatus?,
                reason: AliRtcEngine.AliRtcConnectionStatusChangeReason?,
            ) {
                emit(
                    "connectionStatus",
                    mapOf(
                        "status" to (status?.name ?: "unknown"),
                        "reason" to (reason?.name ?: "unknown"),
                    ),
                )
            }
        })

        rtc.setRtcEngineNotify(object : AliRtcEngineNotify() {
            override fun onRemoteUserOnLineNotify(uid: String?, elapsed: Int) {
                if (uid != null) {
                    emit("remoteOnline", mapOf("uid" to uid))
                }
            }

            override fun onRemoteUserOffLineNotify(
                uid: String?,
                reason: AliRtcEngine.AliRtcUserOfflineReason?,
            ) {
                if (uid != null && uid == boundRemoteUid) {
                    hasRemoteFrame = false
                    boundRemoteUid = null
                    updateLayerVisibility()
                    emit("remoteOffline", mapOf("uid" to uid))
                }
            }

            override fun onRemoteTrackAvailableNotify(
                uid: String?,
                audioTrack: AliRtcEngine.AliRtcAudioTrack?,
                videoTrack: AliRtcEngine.AliRtcVideoTrack?,
            ) {
                if (uid == null) return
                val isTarget =
                    targetRenderUid.isEmpty() ||
                        uid == targetRenderUid ||
                        boundRemoteUid == null
                if (!isTarget) return
                val hasCamera =
                    videoTrack == AliRtcEngine.AliRtcVideoTrack.AliRtcVideoTrackCamera ||
                        videoTrack == AliRtcEngine.AliRtcVideoTrack.AliRtcVideoTrackBoth
                if (hasCamera) {
                    mainHandler.post {
                        attachRemoteStream(uid)
                    }
                }
            }

            override fun onFirstRemoteVideoFrameDrawn(
                uid: String?,
                videoTrack: AliRtcEngine.AliRtcVideoTrack?,
                width: Int,
                height: Int,
                elapsed: Int,
            ) {
                if (uid == null) return
                val isTarget =
                    targetRenderUid.isEmpty() ||
                        uid == targetRenderUid ||
                        uid == boundRemoteUid
                if (!isTarget) return
                hasRemoteFrame = true
                updateLayerVisibility()
                emit(
                    "remoteFirstFrame",
                    mapOf("uid" to uid, "width" to width, "height" to height),
                )
            }
        })

        rtc.setChannelProfile(AliRtcEngine.AliRTCSdkChannelProfile.AliRTCSdkCommunication)
        rtc.setAudioOnlyMode(false)
        rtc.setDefaultSubscribeAllRemoteAudioStreams(false)
        rtc.setDefaultSubscribeAllRemoteVideoStreams(true)
        return rtc
    }

    private fun startCameraPreview(preferFront: Boolean) {
        if (joinedChannel) {
            teardownEngine()
        }
        isFrontCamera = preferFront
        hasRemoteFrame = false
        showOriginal = false
        val rtc = ensureEngine()
        val root = containerView
        if (root != null) {
            ensureTextureViews(root.context)
            rebindViewsIfNeeded()
        }
        rtc.startPreview()
        previewStarted = true
        if (!preferFront && rtc.currentCameraDirection == AliRtcEngine.AliRtcCameraDirection.CAMERA_FRONT) {
            rtc.switchCamera()
        } else if (preferFront && rtc.currentCameraDirection == AliRtcEngine.AliRtcCameraDirection.CAMERA_REAR) {
            rtc.switchCamera()
        }
        updateLayerVisibility()
    }

    private fun joinChannel(
        token: String,
        channelId: String,
        userId: String,
        renderUid: String,
        dataSaver: Boolean,
        preferFront: Boolean,
    ) {
        if (joinedChannel) {
            teardownEngine()
        }
        targetRenderUid = renderUid
        boundRemoteUid = null
        hasRemoteFrame = false
        showOriginal = false
        isFrontCamera = preferFront

        val rtc = ensureEngine()
        applyVideoEncoderProfile(dataSaver)

        val root = containerView
        if (root != null) {
            ensureTextureViews(root.context)
            rebindViewsIfNeeded()
        }

        if (!previewStarted) {
            rtc.startPreview()
            previewStarted = true
        }
        if (!preferFront && rtc.currentCameraDirection == AliRtcEngine.AliRtcCameraDirection.CAMERA_FRONT) {
            rtc.switchCamera()
        } else if (preferFront && rtc.currentCameraDirection == AliRtcEngine.AliRtcCameraDirection.CAMERA_REAR) {
            rtc.switchCamera()
        }
        rtc.publishLocalVideoStream(true)
        rtc.publishLocalAudioStream(false)
        joinedChannel = true

        // Single-parameter Base64 V2 token from Vidu already encapsulates appId,
        // channelId, userId, timestamp, and signature; pass null for channelId/userId.
        val joinCode = rtc.joinChannel(
            token,
            null,
            null,
            userId.ifEmpty { "customer" },
        )
        if (joinCode != 0) {
            joinedChannel = false
            throw IllegalStateException("AliRTC joinChannel returned error code $joinCode")
        }
    }

    private fun attachRemoteStream(uid: String) {
        val rtc = engine ?: return
        val remoteTv = remoteTextureView ?: return
        boundRemoteUid = uid
        val remoteCanvas = AliRtcEngine.AliRtcVideoCanvas().apply {
            view = remoteTv
            renderMode = AliRtcEngine.AliRtcRenderMode.AliRtcRenderModeClip
            mirrorMode = AliRtcEngine.AliRtcRenderMirrorMode.AliRtcRenderMirrorModeAllDisable
        }
        rtc.setRemoteViewConfig(remoteCanvas, uid, AliRtcEngine.AliRtcVideoTrack.AliRtcVideoTrackCamera)
        rtc.subscribeRemoteVideoStream(uid, AliRtcEngine.AliRtcVideoTrack.AliRtcVideoTrackCamera, true)
    }

    private fun teardownEngine() {
        previewStarted = false
        joinedChannel = false
        val rtc = engine ?: return
        engine = null
        boundRemoteUid = null
        hasRemoteFrame = false
        try {
            rtc.stopPreview()
        } catch (_: Throwable) {}
        try {
            rtc.leaveChannel()
        } catch (_: Throwable) {}
        try {
            rtc.destroy()
        } catch (_: Throwable) {}
        updateLayerVisibility()
    }

    fun dispose() {
        mainHandler.post {
            teardownEngine()
            eventSink = null
        }
    }
}

class ViduRtcViewFactory(
    private val handler: ViduLiveRtcHandler,
) : PlatformViewFactory(StandardMessageCodec.INSTANCE) {
    override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
        return handler.createPlatformView(context)
    }
}
