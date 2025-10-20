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
    
    // Register Vision API using Pigeon
    let visionApi = VisionApiImpl()
    VisionApiSetup.setUp(
      binaryMessenger: controller.binaryMessenger,
      api: visionApi
    )
    
    NSLog("[AppDelegate] VisionApi registered via Pigeon ✅")
    
    // Register PhotoLibraryService via MethodChannel
    let photoLibraryChannel = FlutterMethodChannel(name: "photo_library_service", binaryMessenger: controller.binaryMessenger)
    let photoLibraryService = PhotoLibraryService()
    photoLibraryChannel.setMethodCallHandler { (call, result) in
        photoLibraryService.handle(call, result: result)
    }
    NSLog("[AppDelegate] PhotoLibraryService registered via MethodChannel ✅")

    // Register PhotoChannel for content-addressed media
    PhotoChannel.register(with: self.registrar(forPlugin: "PhotoChannel")!)
    NSLog("[AppDelegate] PhotoChannel registered ✅")

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
          } else if call.method == "getVideoIdentifierAndOpen" {
            if let videoPath = call.arguments as? String {
              self?.getVideoIdentifierAndOpen(videoPath) { success in
                result(success)
              }
            } else {
              result(false)
            }
          } else if call.method == "getMediaIdentifierAndOpen" {
            if let mediaPath = call.arguments as? String {
              self?.getMediaIdentifierAndOpen(mediaPath) { success in
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
    
    // Request photo library access using iOS 14+ API
    PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
      DispatchQueue.main.async {
        guard status == .authorized || status == .limited else {
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
  
  // Method to get video identifier and open specific video
  @objc func getVideoIdentifierAndOpen(_ videoPath: String, completion: @escaping (Bool) -> Void) {
    // Extract filename from path
    let fileName = URL(fileURLWithPath: videoPath).lastPathComponent
    
    // Request photo library access using iOS 14+ API
    PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
      DispatchQueue.main.async {
        guard status == .authorized || status == .limited else {
          completion(false)
          return
        }
        
        // Search for the video by filename
        let fetchOptions = PHFetchOptions()
        fetchOptions.predicate = NSPredicate(format: "filename == %@", fileName)
        let assets = PHAsset.fetchAssets(with: .video, options: fetchOptions)
        
        if let asset = assets.firstObject {
          // Found the video, try to open it
          let options = PHVideoRequestOptions()
          options.isNetworkAccessAllowed = false
          options.deliveryMode = .highQualityFormat
            
          PHImageManager.default().requestAVAsset(
            forVideo: asset,
            options: options
          ) { avAsset, audioMix, info in
            DispatchQueue.main.async {
              if avAsset != nil {
                // Video found and loaded, now try to open it
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
          }
        } else {
          // Video not found in library, try fallback methods
          completion(false)
        }
      }
    }
  }
  
  // Method to get media identifier and open specific media (photos or videos)
  @objc func getMediaIdentifierAndOpen(_ mediaPath: String, completion: @escaping (Bool) -> Void) {
    // Extract filename from path
    let fileName = URL(fileURLWithPath: mediaPath).lastPathComponent
    let fileExtension = URL(fileURLWithPath: mediaPath).pathExtension.lowercased()
    
    // Request photo library access using iOS 14+ API
    PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
      DispatchQueue.main.async {
        guard status == .authorized || status == .limited else {
          completion(false)
          return
        }
        
        // Determine media type based on file extension
        let mediaType: PHAssetMediaType
        if ["jpg", "jpeg", "png", "heic", "gif", "bmp", "tiff"].contains(fileExtension) {
          mediaType = .image
        } else if ["mp4", "mov", "avi", "m4v", "3gp", "mkv"].contains(fileExtension) {
          mediaType = .video
        } else {
          // For audio files or other types, try to open directly
          completion(false)
          return
        }
        
        // Search for the media by filename
        let fetchOptions = PHFetchOptions()
        fetchOptions.predicate = NSPredicate(format: "filename == %@", fileName)
        let assets = PHAsset.fetchAssets(with: mediaType, options: fetchOptions)
        
        if let asset = assets.firstObject {
          // Found the media, try to open it
          if mediaType == .image {
            let options = PHImageRequestOptions()
            options.isSynchronous = false
            options.deliveryMode = .highQualityFormat
              
            PHImageManager.default().requestImage(
              for: asset,
              targetSize: CGSize(width: 1000, height: 1000),
              contentMode: .aspectFit,
              options: options
            ) { image, info in
              DispatchQueue.main.async {
                if image != nil {
                  // Media found and loaded, now try to open it
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
            }
          } else if mediaType == .video {
            let options = PHVideoRequestOptions()
            options.isNetworkAccessAllowed = false
            options.deliveryMode = .highQualityFormat
              
            PHImageManager.default().requestAVAsset(
              forVideo: asset,
              options: options
            ) { avAsset, audioMix, info in
              DispatchQueue.main.async {
                if avAsset != nil {
                  // Video found and loaded, now try to open it
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
            }
          }
        } else {
          // Media not found in library, try fallback methods
          completion(false)
        }
      }
    }
  }
}
