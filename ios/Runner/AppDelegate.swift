import AliVCSDK_ARTC
import AudioToolbox
import Flutter
import UIKit
import UserNotifications
import MediaPipeTasksVision

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var bodyAnalysis: BodyAnalysisHandler?
  private var viduLiveRtc: ViduLiveRtcHandler?
  private var apnsChannel: FlutterMethodChannel?
  private var apnsToken: String?
  private var savedScreenBrightness: CGFloat?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    UNUserNotificationCenter.current().delegate = self
    application.registerForRemoteNotifications()
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    let userInfo = notification.request.content.userInfo
    // Only defer to FirebaseMessaging plugin for actual FCM messages; local and
    // direct APNs notifications should always present banner, list, sound, badge.
    if userInfo["gcm.message_id"] != nil {
      super.userNotificationCenter(
        center,
        willPresent: notification,
        withCompletionHandler: completionHandler
      )
      return
    }
    if #available(iOS 14.0, *) {
      completionHandler([.banner, .list, .sound, .badge])
    } else {
      completionHandler([.alert, .sound, .badge])
    }
  }

  override func application(
    _ application: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
  ) {
    let token = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
    apnsToken = token
    DispatchQueue.main.async { [weak self] in
      self?.apnsChannel?.invokeMethod("onToken", arguments: token)
    }
    super.application(application, didRegisterForRemoteNotificationsWithDeviceToken: deviceToken)
  }

  override func application(
    _ application: UIApplication,
    didFailToRegisterForRemoteNotificationsWithError error: Error
  ) {
    super.application(application, didFailToRegisterForRemoteNotificationsWithError: error)
  }

  override func application(
    _ application: UIApplication,
    didReceiveRemoteNotification userInfo: [AnyHashable: Any],
    fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
  ) {
    DispatchQueue.main.async { [weak self] in
      self?.apnsChannel?.invokeMethod("onMessage", arguments: userInfo)
    }
    super.application(application, didReceiveRemoteNotification: userInfo, fetchCompletionHandler: completionHandler)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    if let apnsRegistrar = engineBridge.pluginRegistry.registrar(forPlugin: "FashionApnsBridge") {
      let channel = FlutterMethodChannel(name: "fashion/apns", binaryMessenger: apnsRegistrar.messenger())
      apnsChannel = channel
      channel.setMethodCallHandler { [weak self] call, result in
        switch call.method {
        case "getToken":
          result(self?.apnsToken)
        case "register":
          DispatchQueue.main.async {
            UIApplication.shared.registerForRemoteNotifications()
          }
          result(nil)
        default:
          result(FlutterMethodNotImplemented)
        }
      }
    }

    if let soundRegistrar = engineBridge.pluginRegistry.registrar(forPlugin: "FashionTryonSound") {
      let soundChannel = FlutterMethodChannel(name: "fashion/tryon_sound", binaryMessenger: soundRegistrar.messenger())
      soundChannel.setMethodCallHandler { call, result in
        switch call.method {
        case "tick":
          AudioServicesPlaySystemSound(1104)
          result(nil)
        case "go":
          AudioServicesPlaySystemSound(1113)
          result(nil)
        default:
          result(FlutterMethodNotImplemented)
        }
      }
    }

    if let brightnessRegistrar = engineBridge.pluginRegistry.registrar(forPlugin: "FashionScreenBrightness") {
      let brightnessChannel = FlutterMethodChannel(
        name: "fashion/screen_brightness",
        binaryMessenger: brightnessRegistrar.messenger()
      )
      brightnessChannel.setMethodCallHandler { [weak self] call, result in
        DispatchQueue.main.async {
          switch call.method {
          case "setMax":
            if self?.savedScreenBrightness == nil {
              self?.savedScreenBrightness = UIScreen.main.brightness
            }
            UIScreen.main.brightness = 1.0
            result(nil)
          case "restore":
            if let prev = self?.savedScreenBrightness {
              UIScreen.main.brightness = prev
              self?.savedScreenBrightness = nil
            }
            result(nil)
          default:
            result(FlutterMethodNotImplemented)
          }
        }
      }
    }

    if let viduRegistrar = engineBridge.pluginRegistry.registrar(forPlugin: "FashionViduLiveRtc") {
      let viduHandler = ViduLiveRtcHandler()
      viduLiveRtc = viduHandler
      let viduMethods = FlutterMethodChannel(
        name: "fashion/vidu_rtc/methods",
        binaryMessenger: viduRegistrar.messenger()
      )
      viduMethods.setMethodCallHandler { call, result in
        viduHandler.handle(call, result: result)
      }
      let viduEvents = FlutterEventChannel(
        name: "fashion/vidu_rtc/events",
        binaryMessenger: viduRegistrar.messenger()
      )
      viduEvents.setStreamHandler(viduHandler)
      viduRegistrar.register(
        ViduRtcViewFactory(handler: viduHandler),
        withId: "fashion/vidu_rtc_view"
      )
    }

    guard let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "FashionBodyAnalysis") else { return }
    let handler = BodyAnalysisHandler()
    bodyAnalysis = handler
    let channel = FlutterMethodChannel(name: "fashion/body_analysis", binaryMessenger: registrar.messenger())
    channel.setMethodCallHandler { call, result in handler.handle(call, result: result) }
  }
}

// MARK: - Native iOS AliRTC bridge for Vidu S2-Editing Real-Time Virtual Try-On

private final class ViduRtcContainerView: UIView {
  let localView = UIView()
  let remoteView = UIView()

  override init(frame: CGRect) {
    super.init(frame: frame)
    backgroundColor = .black
    clipsToBounds = true
    localView.backgroundColor = .black
    remoteView.backgroundColor = .clear
    addSubview(localView)
    addSubview(remoteView)
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func layoutSubviews() {
    super.layoutSubviews()
    localView.frame = bounds
    remoteView.frame = bounds
  }
}

private final class ViduLiveRtcHandler: NSObject, FlutterStreamHandler, AliRtcEngineDelegate {
  private var engine: AliRtcEngine?
  private var eventSink: FlutterEventSink?

  private weak var containerView: ViduRtcContainerView?
  private weak var localRenderView: UIView?
  private weak var remoteRenderView: UIView?

  private var targetRenderUid: String = ""
  private var boundRemoteUid: String?
  private var hasRemoteFrame: Bool = false
  private var showOriginal: Bool = false
  private var isFrontCamera: Bool = true
  private var previewStarted: Bool = false
  private var joinedChannel: Bool = false
  private var remoteFallbackWorkItem: DispatchWorkItem?

  func createPlatformView(frame: CGRect) -> FlutterPlatformView {
    let initialBounds = frame.isEmpty ? CGRect(x: 0, y: 0, width: 320, height: 480) : frame
    let root = ViduRtcContainerView(frame: initialBounds)
    root.remoteView.isHidden = !(hasRemoteFrame && !showOriginal)

    containerView = root
    localRenderView = root.localView
    remoteRenderView = root.remoteView
    rebindViewsIfNeeded()
    if previewStarted, let rtc = engine {
      rtc.startPreview()
    }

    return ViduRtcPlatformView(rootView: root, handler: self)
  }

  func detachPlatformViewIfCurrent(_ view: UIView) {
    if containerView === view {
      containerView = nil
      localRenderView = nil
      remoteRenderView = nil
    }
  }

  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    eventSink = events
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    eventSink = nil
    return nil
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any]
    switch call.method {
    case "startPreview":
      let preferFront = (args?["useFrontCamera"] as? Bool) ?? true
      DispatchQueue.main.async { [weak self] in
        guard let self = self else {
          result(false)
          return
        }
        do {
          try self.startCameraPreview(preferFront: preferFront)
          result(true)
        } catch {
          result(FlutterError(code: "preview_failed", message: error.localizedDescription, details: nil))
        }
      }

    case "join":
      let token = (args?["token"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
      let channelId = (args?["channelId"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
      let userId = (args?["userId"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
      let renderUid = (args?["renderUid"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
      let dataSaver = (args?["dataSaver"] as? Bool) ?? true
      let preferFront = (args?["useFrontCamera"] as? Bool) ?? true
      guard !token.isEmpty else {
        result(FlutterError(code: "invalid_args", message: "Missing AliRTC token", details: nil))
        return
      }
      DispatchQueue.main.async { [weak self] in
        guard let self = self else {
          result(FlutterError(code: "disposed", message: "Handler disposed", details: nil))
          return
        }
        do {
          try self.joinChannel(
            token: token,
            channelId: channelId,
            userId: userId,
            renderUid: renderUid,
            dataSaver: dataSaver,
            preferFront: preferFront
          )
          result(true)
        } catch {
          result(FlutterError(code: "join_failed", message: error.localizedDescription, details: nil))
        }
      }

    case "switchCamera":
      DispatchQueue.main.async { [weak self] in
        guard let self = self else {
          result(true)
          return
        }
        if let rtc = self.engine {
          rtc.switchCamera()
          self.isFrontCamera = rtc.getCurrentCameraDirection() != .back
        } else {
          self.isFrontCamera.toggle()
        }
        result(self.isFrontCamera)
      }

    case "setShowOriginal":
      let original = (args?["showOriginal"] as? Bool) ?? false
      DispatchQueue.main.async { [weak self] in
        self?.showOriginal = original
        self?.updateLayerVisibility()
        result(nil)
      }

    case "setBandwidthMode":
      let dataSaver = (args?["dataSaver"] as? Bool) ?? true
      DispatchQueue.main.async { [weak self] in
        self?.applyVideoEncoderProfile(dataSaver: dataSaver)
        result(nil)
      }

    case "leave":
      DispatchQueue.main.async { [weak self] in
        self?.teardownEngine()
        result(nil)
      }

    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func emit(_ type: String, extras: [String: Any] = [:]) {
    DispatchQueue.main.async { [weak self] in
      var payload: [String: Any] = ["type": type]
      for (k, v) in extras {
        payload[k] = v
      }
      self?.eventSink?(payload)
    }
  }

  private func updateLayerVisibility() {
    DispatchQueue.main.async { [weak self] in
      guard let self = self, let remoteView = self.remoteRenderView else { return }
      remoteView.isHidden = !(self.hasRemoteFrame && !self.showOriginal)
    }
  }

  private func rebindViewsIfNeeded() {
    guard let rtc = engine else { return }
    if let localView = localRenderView {
      let localCanvas = AliVideoCanvas()
      localCanvas.view = localView
      localCanvas.renderMode = .auto
      localCanvas.mirrorMode = .onlyFrontCameraPreviewEnabled
      localCanvas.rotationMode = ._0
      rtc.setLocalViewConfig(localCanvas, for: .camera)
    }
    if let uid = boundRemoteUid, let remoteView = remoteRenderView {
      let remoteCanvas = AliVideoCanvas()
      remoteCanvas.view = remoteView
      remoteCanvas.renderMode = .auto
      remoteCanvas.mirrorMode = .allDisabled
      remoteCanvas.rotationMode = ._0
      rtc.setRemoteViewConfig(remoteCanvas, uid: uid, for: .camera)
    }
    updateLayerVisibility()
  }

  private func applyVideoEncoderProfile(dataSaver: Bool) {
    guard let rtc = engine else { return }
    let cfg = AliRtcVideoEncoderConfiguration()
    if dataSaver {
      cfg.dimensions = CGSize(width: 544, height: 952)
      cfg.frameRate = 15
      cfg.bitrate = 800
    } else {
      cfg.dimensions = CGSize(width: 720, height: 1280)
      cfg.frameRate = 24
      cfg.bitrate = 1800
    }
    cfg.orientationMode = .adaptive
    rtc.setVideoEncoderConfiguration(cfg)
  }

  private func ensureEngine() throws -> AliRtcEngine {
    if let existing = engine {
      return existing
    }
    let maybeEngine: AliRtcEngine? = AliRtcEngine.sharedInstance(self, extras: nil)
    guard let rtc = maybeEngine else {
      throw NSError(
        domain: "ViduLiveRtc",
        code: -1,
        userInfo: [NSLocalizedDescriptionKey: "AliRtcEngine unavailable"]
      )
    }
    engine = rtc
    rtc.setChannelProfile(.interactivelive)
    rtc.setClientRole(.roleInteractive)
    rtc.setDefaultSubscribeAllRemoteAudioStreams(false)
    rtc.setDefaultSubscribeAllRemoteVideoStreams(true)
    rtc.subscribeAllRemoteVideoStreams(true)
    return rtc
  }

  private func startCameraPreview(preferFront: Bool) throws {
    if joinedChannel {
      teardownEngine()
    }
    isFrontCamera = preferFront
    hasRemoteFrame = false
    showOriginal = false
    let rtc = try ensureEngine()
    rebindViewsIfNeeded()
    rtc.startPreview()
    previewStarted = true
    if !preferFront && rtc.getCurrentCameraDirection() == .front {
      rtc.switchCamera()
    } else if preferFront && rtc.getCurrentCameraDirection() == .back {
      rtc.switchCamera()
    }
    updateLayerVisibility()
  }

  private func joinChannel(
    token: String,
    channelId: String,
    userId: String,
    renderUid: String,
    dataSaver: Bool,
    preferFront: Bool
  ) throws {
    if joinedChannel {
      teardownEngine()
    }
    targetRenderUid = renderUid
    boundRemoteUid = nil
    hasRemoteFrame = false
    showOriginal = false
    isFrontCamera = preferFront

    let rtc = try ensureEngine()
    applyVideoEncoderProfile(dataSaver: dataSaver)
    rebindViewsIfNeeded()

    if !previewStarted {
      rtc.startPreview()
      previewStarted = true
    }
    if !preferFront && rtc.getCurrentCameraDirection() == .front {
      rtc.switchCamera()
    } else if preferFront && rtc.getCurrentCameraDirection() == .back {
      rtc.switchCamera()
    }
    rtc.publishLocalVideoStream(true)
    rtc.publishLocalAudioStream(false)
    joinedChannel = true

    // Single-parameter Base64 V2 token from Vidu already encapsulates appId,
    // channelId, userId, timestamp, and signature; pass nil for channelId/userId.
    let displayName = userId.isEmpty ? "customer" : userId
    let joinCode = rtc.joinChannel(token, channelId: nil, userId: nil, name: displayName) {
      [weak self] errCode, _, _, _ in
      guard let self = self else { return }
      if errCode == 0 {
        self.emit("joined", extras: ["channel": channelId])
      } else {
        self.emit("error", extras: [
          "code": Int(errCode),
          "message": "AliRTC join failed (\(errCode))",
        ])
      }
    }
    if joinCode != 0 {
      joinedChannel = false
      throw NSError(
        domain: "ViduLiveRtc",
        code: Int(joinCode),
        userInfo: [NSLocalizedDescriptionKey: "AliRTC joinChannel returned error code \(joinCode)"]
      )
    }
  }

  private func attachRemoteStream(uid: String) {
    guard let rtc = engine else { return }
    boundRemoteUid = uid
    if let remoteView = remoteRenderView {
      let remoteCanvas = AliVideoCanvas()
      remoteCanvas.view = remoteView
      remoteCanvas.renderMode = .auto
      remoteCanvas.mirrorMode = .allDisabled
      remoteCanvas.rotationMode = ._0
      rtc.setRemoteViewConfig(remoteCanvas, uid: uid, for: .camera)
    }
    // Safety fallback in case onFirstRemoteVideoFrameDrawn is delayed on iOS.
    cancelRemoteFallback()
    let work = DispatchWorkItem { [weak self] in
      guard let self = self, self.boundRemoteUid == uid, !self.hasRemoteFrame else { return }
      self.markRemoteFrameReady(uid: uid, width: 0, height: 0)
    }
    remoteFallbackWorkItem = work
    DispatchQueue.main.asyncAfter(deadline: .now() + 1.2, execute: work)
  }

  private func markRemoteFrameReady(uid: String, width: Int, height: Int) {
    cancelRemoteFallback()
    let wasReady = hasRemoteFrame
    hasRemoteFrame = true
    updateLayerVisibility()
    if !wasReady {
      emit("remoteFirstFrame", extras: ["uid": uid, "width": width, "height": height])
    }
  }

  private func cancelRemoteFallback() {
    remoteFallbackWorkItem?.cancel()
    remoteFallbackWorkItem = nil
  }

  private func teardownEngine() {
    cancelRemoteFallback()
    previewStarted = false
    joinedChannel = false
    guard let rtc = engine else { return }
    engine = nil
    boundRemoteUid = nil
    hasRemoteFrame = false
    rtc.stopPreview()
    rtc.leaveChannel()
    AliRtcEngine.destroy()
    updateLayerVisibility()
  }

  // MARK: - AliRtcEngineDelegate

  func onRemoteUser(onLineNotify uid: String, elapsed: Int32) {
    emit("remoteOnline", extras: ["uid": uid])
  }

  func onRemoteUserOffLineNotify(_ uid: String, offlineReason reason: AliRtcUserOfflineReason) {
    DispatchQueue.main.async { [weak self] in
      guard let self = self, uid == self.boundRemoteUid else { return }
      self.hasRemoteFrame = false
      self.boundRemoteUid = nil
      self.cancelRemoteFallback()
      self.updateLayerVisibility()
      self.emit("remoteOffline", extras: ["uid": uid])
    }
  }

  func onRemoteTrackAvailableNotify(
    _ uid: String,
    audioTrack: AliRtcAudioTrack,
    videoTrack: AliRtcVideoTrack
  ) {
    DispatchQueue.main.async { [weak self] in
      guard let self = self else { return }
      let isTarget =
        self.targetRenderUid.isEmpty ||
        uid == self.targetRenderUid ||
        self.boundRemoteUid == nil
      guard isTarget else { return }
      if videoTrack == .camera || videoTrack == .both {
        self.attachRemoteStream(uid: uid)
      } else if uid == self.boundRemoteUid {
        self.engine?.setRemoteViewConfig(nil, uid: uid, for: .camera)
        self.hasRemoteFrame = false
        self.cancelRemoteFallback()
        self.updateLayerVisibility()
      }
    }
  }

  func onFirstRemoteVideoFrameDrawn(
    _ uid: String,
    videoTrack: AliRtcVideoTrack,
    width: Int32,
    height: Int32,
    elapsed: Int32
  ) {
    DispatchQueue.main.async { [weak self] in
      guard let self = self else { return }
      let isTarget =
        self.targetRenderUid.isEmpty ||
        uid == self.targetRenderUid ||
        uid == self.boundRemoteUid
      guard isTarget else { return }
      self.markRemoteFrameReady(uid: uid, width: Int(width), height: Int(height))
    }
  }

  func onOccurError(_ error: Int32, message: String) {
    emit("error", extras: [
      "code": Int(error),
      "message": message.isEmpty ? "RTC error \(error)" : message,
    ])
  }
}

private final class ViduRtcPlatformView: NSObject, FlutterPlatformView {
  private let rootView: UIView
  private weak var handler: ViduLiveRtcHandler?

  init(rootView: UIView, handler: ViduLiveRtcHandler) {
    self.rootView = rootView
    self.handler = handler
    super.init()
  }

  func view() -> UIView {
    return rootView
  }

  deinit {
    let viewToDetach = rootView
    let h = handler
    DispatchQueue.main.async {
      h?.detachPlatformViewIfCurrent(viewToDetach)
    }
  }
}

private final class ViduRtcViewFactory: NSObject, FlutterPlatformViewFactory {
  private unowned let handler: ViduLiveRtcHandler

  init(handler: ViduLiveRtcHandler) {
    self.handler = handler
    super.init()
  }

  func create(
    withFrame frame: CGRect,
    viewIdentifier viewId: Int64,
    arguments args: Any?
  ) -> FlutterPlatformView {
    return handler.createPlatformView(frame: frame)
  }

  func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
    return FlutterStandardMessageCodec.sharedInstance()
  }
}

// Uses the same camera snapshot and bundled model as Android; no second camera.
private final class BodyAnalysisHandler {
  private let queue = DispatchQueue(label: "fashion.body-analysis", qos: .userInitiated)
  private var detector: PoseLandmarker?

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard call.method == "analyze" || call.method == "close" else {
      result(FlutterMethodNotImplemented)
      return
    }
    queue.async {
      let temporaryFrame = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("captureFrame.png")
      defer { try? FileManager.default.removeItem(at: temporaryFrame) }
      if call.method == "close" {
        self.detector = nil
        DispatchQueue.main.async { result(nil) }
        return
      }
      do {
        guard let bytes = call.arguments as? FlutterStandardTypedData,
              bytes.data.count <= 12 * 1024 * 1024,
              let source = UIImage(data: bytes.data) else {
          throw NSError(domain: "BodyAnalysis", code: 1)
        }
        if self.detector == nil {
          let key = FlutterDartProject.lookupKey(forAsset: "assets/models/pose_landmarker_lite.task")
          guard let model = Bundle.main.path(forResource: key, ofType: nil) else {
            throw NSError(domain: "BodyAnalysis", code: 2)
          }
          let options = PoseLandmarkerOptions()
          options.baseOptions.modelAssetPath = model
          options.runningMode = .image
          options.numPoses = 3
          options.minPoseDetectionConfidence = 0.5
          options.minPosePresenceConfidence = 0.5
          self.detector = try PoseLandmarker(options: options)
        }
        let scale = min(1, 640 / max(source.size.width, source.size.height))
        let size = CGSize(width: source.size.width * scale, height: source.size.height * scale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let image = UIGraphicsImageRenderer(size: size, format: format).image { _ in
          source.draw(in: CGRect(origin: .zero, size: size))
        }
        let output = try self.detector!.detect(image: MPImage(uiImage: image))
        let poses = output.landmarks.map { pose in pose.map { p in
          ["x": Double(p.x), "y": Double(p.y), "z": Double(p.z),
           "visibility": min(p.visibility?.doubleValue ?? 0, p.presence?.doubleValue ?? 0)]
        }}
        DispatchQueue.main.async { result(poses) }
      } catch {
        DispatchQueue.main.async { result(FlutterError(code: "analysis_failed", message: "Body analysis unavailable", details: nil)) }
      }
    }
  }
}
