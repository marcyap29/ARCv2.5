import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    let controller = window?.rootViewController as? FlutterViewController
    if controller == nil {
      NSLog("[AppDelegate] ERROR: rootViewController is not FlutterViewController")
    }

    // Register QwenBridge native plugin
    if let registrar = self.registrar(forPlugin: "QwenBridge") {
      QwenBridge.register(with: registrar)
      NSLog("[AppDelegate] QwenBridge.register() via registrar ✅")
    } else {
      NSLog("[AppDelegate] ERROR: registrar(forPlugin:) returned nil")
    }

    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}