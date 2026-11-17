import Flutter
import UIKit
import UserNotifications
import MediaPipeTasksVision

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var bodyAnalysis: BodyAnalysisHandler?
  private var apnsChannel: FlutterMethodChannel?
  private var apnsToken: String?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    UNUserNotificationCenter.current().delegate = self
    application.registerForRemoteNotifications()
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
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

    guard let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "FashionBodyAnalysis") else { return }
    let handler = BodyAnalysisHandler()
    bodyAnalysis = handler
    let channel = FlutterMethodChannel(name: "fashion/body_analysis", binaryMessenger: registrar.messenger())
    channel.setMethodCallHandler { call, result in handler.handle(call, result: result) }
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
