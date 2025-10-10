import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Register native LLM bridge using Pigeon
    let controller = window?.rootViewController as! FlutterViewController
    let bridge = LLMBridge.shared
    LumaraNativeSetup.setUp(
      binaryMessenger: controller.binaryMessenger,
      api: bridge
    )

    // Create and wire up progress API for model loading callbacks
    let progressApi = LumaraNativeProgress(binaryMessenger: controller.binaryMessenger)
    bridge.setProgressApi(progressApi)

    NSLog("[AppDelegate] LLMBridge registered via Pigeon with progress API ✅")

    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
