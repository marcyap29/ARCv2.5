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
    let bridge = LLMBridge()
    LumaraNativeSetup.setUp(
      binaryMessenger: controller.binaryMessenger,
      api: bridge
    )

    NSLog("[AppDelegate] LLMBridge registered via Pigeon ✅")

    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
