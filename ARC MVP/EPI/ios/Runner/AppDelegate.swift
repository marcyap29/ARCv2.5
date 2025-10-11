import Flutter
import UIKit
import Photos

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
    
    // Register Photos method channel
    let photosChannel = FlutterMethodChannel(name: "com.epi.arcmvp/photos", binaryMessenger: controller.binaryMessenger)
    photosChannel.setMethodCallHandler { [weak self] (call, result) in
      if call.method == "getPhotoIdentifierAndOpen" {
        if let imagePath = call.arguments as? String {
          self?.getPhotoIdentifierAndOpen(imagePath) { success in
            result(success)
          }
        } else {
          result(false)
        }
      } else {
        result(FlutterMethodNotImplemented)
      }
    }

    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
  
  // Method to get photo identifier and open specific photo
  @objc func getPhotoIdentifierAndOpen(_ imagePath: String, completion: @escaping (Bool) -> Void) {
    // Extract filename from path
    let fileName = URL(fileURLWithPath: imagePath).lastPathComponent
    
    // Request photo library access
    PHPhotoLibrary.requestAuthorization { status in
      DispatchQueue.main.async {
        guard status == .authorized else {
          completion(false)
          return
        }
        
        // Search for the photo by filename
        let fetchOptions = PHFetchOptions()
        fetchOptions.predicate = NSPredicate(format: "filename == %@", fileName)
        let assets = PHAsset.fetchAssets(with: .image, options: fetchOptions)
        
        if let asset = assets.firstObject {
          // Found the photo, try to open it
          let options = PHImageRequestOptions()
          options.isSynchronous = false
          options.deliveryMode = .highQualityFormat
            
          PHImageManager.default().requestImage(
            for: asset,
            targetSize: CGSize(width: 1000, height: 1000),
            contentMode: .aspectFit,
            options: options
          ) { image, info in
            if image != nil {
              // Photo found and loaded, now try to open it
              let photosURL = URL(string: "photos-redirect://")!
              if UIApplication.shared.canOpenURL(photosURL) {
                UIApplication.shared.open(photosURL)
                completion(true)
              } else {
                completion(false)
              }
            } else {
              completion(false)
            }
          }
        } else {
          // Photo not found in library, try fallback methods
          completion(false)
        }
      }
    }
  }
}
