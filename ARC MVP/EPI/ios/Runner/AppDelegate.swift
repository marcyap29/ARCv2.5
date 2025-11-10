import Flutter
import UIKit
import Photos

@main
@objc class AppDelegate: FlutterAppDelegate {
  // ARCX import channel
  private let arcxChannelName = "arcx/import"
  private var arcxMethodChannel: FlutterMethodChannel?
  
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
    
    // Register ARCX import channel
    arcxMethodChannel = FlutterMethodChannel(name: arcxChannelName, binaryMessenger: controller.binaryMessenger)
    NSLog("[AppDelegate] ARCX import channel registered ✅")
    
    // Register ARCX crypto channel
    let arcxCryptoChannel = FlutterMethodChannel(name: "arcx/crypto", binaryMessenger: controller.binaryMessenger)
    arcxCryptoChannel.setMethodCallHandler { (call, result) in
      self.handleARCXCryptoCall(call: call, result: result)
    }
    NSLog("[AppDelegate] ARCX crypto channel registered ✅")

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
    
    // Register HealthKit medications channel
    let healthKitChannel = FlutterMethodChannel(name: "epi.healthkit/bridge", binaryMessenger: controller.binaryMessenger)
    healthKitChannel.setMethodCallHandler { (call, result) in
        if call.method == "fetchMedications" {
            if #available(iOS 16.0, *) {
                HealthKitManager.shared.fetchMedications { medications, error in
                    if let error = error {
                        result(FlutterError(code: "FETCH_FAILED", message: error.localizedDescription, details: nil))
                    } else {
                        result(medications)
                    }
                }
            } else {
                result(FlutterError(code: "UNSUPPORTED", message: "Medications require iOS 16.0 or later", details: nil))
            }
        } else {
            result(FlutterMethodNotImplemented)
        }
    }
    NSLog("[AppDelegate] HealthKit medications channel registered ✅")

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
  
  // Handle opening .arcx files from AirDrop, Files app, etc.
  override func application(
    _ app: UIApplication,
    open url: URL,
    options: [UIApplication.OpenURLOptionsKey : Any] = [:]
  ) -> Bool {
    guard url.pathExtension.lowercased() == "arcx" else { return false }
    
    NSLog("[AppDelegate] Opening ARCX file: \(url.path)")
    
    do {
      let fm = FileManager.default
      let importsDir = try fm.url(
        for: .documentDirectory,
        in: .userDomainMask,
        appropriateFor: nil,
        create: true
      ).appendingPathComponent("Imports", isDirectory: true)
      
      if !fm.fileExists(atPath: importsDir.path) {
        try fm.createDirectory(at: importsDir, withIntermediateDirectories: true, attributes: [
          FileAttributeKey.protectionKey: FileProtectionType.complete
        ])
      }
      
      let destUrl = importsDir.appendingPathComponent(url.lastPathComponent)
      if fm.fileExists(atPath: destUrl.path) { try fm.removeItem(at: destUrl) }
      try fm.copyItem(at: url, to: destUrl)
      try fm.setAttributes([.protectionKey: FileProtectionType.complete], ofItemAtPath: destUrl.path)
      
      // Look for sibling .manifest.json
      let manifestUrl = destUrl.deletingPathExtension().appendingPathExtension("manifest.json")
      var manifestPath: String? = nil
      if fm.fileExists(atPath: manifestUrl.path) {
        try fm.setAttributes([.protectionKey: FileProtectionType.complete], ofItemAtPath: manifestUrl.path)
        manifestPath = manifestUrl.path
      }
      
      NSLog("[AppDelegate] ARCX file copied to sandbox: \(destUrl.path)")
      
      arcxMethodChannel?.invokeMethod("onOpenARCX", arguments: [
        "arcxPath": destUrl.path,
        "manifestPath": manifestPath as Any
      ])
      
      return true
    } catch {
      NSLog("[AppDelegate] ARCX import failed: \(error)")
      return false
    }
  }
  
  // Handle ARCX crypto calls
  private func handleARCXCryptoCall(call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "signData":
      guard let args = call.arguments as? [String: Any],
            let data = args["data"] as? FlutterStandardTypedData else {
        result(FlutterError(code: "INVALID_ARGS", message: "Expected data", details: nil))
        return
      }
      
      do {
        let signature = try ARCXCrypto.signData(Data(data.data))
        result(signature)
      } catch {
        result(FlutterError(code: "SIGN_FAILED", message: error.localizedDescription, details: nil))
      }
      
    case "verifySignature":
      guard let args = call.arguments as? [String: Any],
            let data = args["data"] as? FlutterStandardTypedData,
            let signatureB64 = args["signatureB64"] as? String else {
        result(FlutterError(code: "INVALID_ARGS", message: "Expected data and signature", details: nil))
        return
      }
      
      do {
        let isValid = try ARCXCrypto.verifySignature(data: Data(data.data), signature: signatureB64)
        result(isValid)
      } catch {
        result(FlutterError(code: "VERIFY_FAILED", message: error.localizedDescription, details: nil))
      }
      
    case "encryptAEAD":
      guard let args = call.arguments as? [String: Any],
            let plaintext = args["plaintext"] as? FlutterStandardTypedData else {
        result(FlutterError(code: "INVALID_ARGS", message: "Expected plaintext", details: nil))
        return
      }
      
      do {
        let ciphertext = try ARCXCrypto.encryptAEAD(Data(plaintext.data))
        result(FlutterStandardTypedData(bytes: ciphertext))
      } catch {
        result(FlutterError(code: "ENCRYPT_FAILED", message: error.localizedDescription, details: nil))
      }
      
    case "decryptAEAD":
      guard let args = call.arguments as? [String: Any],
            let ciphertext = args["ciphertext"] as? FlutterStandardTypedData else {
        result(FlutterError(code: "INVALID_ARGS", message: "Expected ciphertext", details: nil))
        return
      }
      
      do {
        let plaintext = try ARCXCrypto.decryptAEAD(Data(ciphertext.data))
        result(FlutterStandardTypedData(bytes: plaintext))
      } catch {
        result(FlutterError(code: "DECRYPT_FAILED", message: error.localizedDescription, details: nil))
      }
      
    case "getSigningPublicKeyFingerprint":
      do {
        let fingerprint = try ARCXCrypto.getSigningPublicKeyFingerprint()
        result(fingerprint)
      } catch {
        result(FlutterError(code: "FINGERPRINT_FAILED", message: error.localizedDescription, details: nil))
      }
    
    case "deriveKeyPBKDF2":
      guard let args = call.arguments as? [String: Any],
            let password = args["password"] as? String,
            let salt = args["salt"] as? FlutterStandardTypedData,
            let iterations = args["iterations"] as? Int else {
        result(FlutterError(code: "INVALID_ARGS", message: "Expected password, salt, and iterations", details: nil))
        return
      }
      
      do {
        let saltData = Data(salt.data)
        let key = try ARCXCrypto.deriveKeyPBKDF2(password: password, salt: saltData, iterations: iterations)
        let keyData = key.withUnsafeBytes { Data($0) }
        result(FlutterStandardTypedData(bytes: keyData))
      } catch {
        result(FlutterError(code: "DERIVATION_FAILED", message: error.localizedDescription, details: nil))
      }
    
    case "encryptWithPassword":
      guard let args = call.arguments as? [String: Any],
            let plaintext = args["plaintext"] as? FlutterStandardTypedData,
            let password = args["password"] as? String else {
        result(FlutterError(code: "INVALID_ARGS", message: "Expected plaintext and password", details: nil))
        return
      }
      
      do {
        let (ciphertext, salt) = try ARCXCrypto.encryptWithPassword(Data(plaintext.data), password: password)
        result([
          "ciphertext": FlutterStandardTypedData(bytes: ciphertext),
          "salt": FlutterStandardTypedData(bytes: salt)
        ])
      } catch {
        result(FlutterError(code: "ENCRYPT_FAILED", message: error.localizedDescription, details: nil))
      }
    
    case "decryptWithPassword":
      guard let args = call.arguments as? [String: Any],
            let ciphertext = args["ciphertext"] as? FlutterStandardTypedData,
            let password = args["password"] as? String,
            let salt = args["salt"] as? FlutterStandardTypedData else {
        result(FlutterError(code: "INVALID_ARGS", message: "Expected ciphertext, password, and salt", details: nil))
        return
      }
      
      do {
        let ciphertextData = Data(ciphertext.data)
        let saltData = Data(salt.data)
        let plaintext = try ARCXCrypto.decryptWithPassword(ciphertextData, password: password, salt: saltData)
        result(FlutterStandardTypedData(bytes: plaintext))
      } catch {
        result(FlutterError(code: "DECRYPT_FAILED", message: error.localizedDescription, details: nil))
      }
    
    case "generateSalt":
      do {
        let salt = try ARCXCrypto.generateSalt()
        result(FlutterStandardTypedData(bytes: salt))
      } catch {
        result(FlutterError(code: "SALT_GEN_FAILED", message: error.localizedDescription, details: nil))
      }
    
    case "encryptChunk":
      guard let args = call.arguments as? [String: Any],
            let plaintext = args["plaintext"] as? FlutterStandardTypedData,
            let key = args["key"] as? FlutterStandardTypedData,
            let nonce = args["nonce"] as? FlutterStandardTypedData,
            let aad = args["aad"] as? FlutterStandardTypedData else {
        result(FlutterError(code: "INVALID_ARGS", message: "Expected plaintext, key, nonce, and aad", details: nil))
        return
      }
      
      do {
        let plaintextData = Data(plaintext.data)
        let keyData = Data(key.data)
        let nonceData = Data(nonce.data)
        let aadData = Data(aad.data)
        
        let ciphertext = try ARCXCrypto.encryptChunkBytes(plaintextData, keyData: keyData, nonce: nonceData, aad: aadData)
        result(FlutterStandardTypedData(bytes: ciphertext))
      } catch {
        result(FlutterError(code: "ENCRYPT_CHUNK_FAILED", message: error.localizedDescription, details: nil))
      }
    
    case "decryptChunk":
      guard let args = call.arguments as? [String: Any],
            let ciphertext = args["ciphertext"] as? FlutterStandardTypedData,
            let key = args["key"] as? FlutterStandardTypedData,
            let nonce = args["nonce"] as? FlutterStandardTypedData,
            let aad = args["aad"] as? FlutterStandardTypedData else {
        result(FlutterError(code: "INVALID_ARGS", message: "Expected ciphertext, key, nonce, and aad", details: nil))
        return
      }
      
      do {
        let ciphertextData = Data(ciphertext.data)
        let keyData = Data(key.data)
        let nonceData = Data(nonce.data)
        let aadData = Data(aad.data)
        
        let plaintext = try ARCXCrypto.decryptChunkBytes(ciphertextData, keyData: keyData, nonce: nonceData, aad: aadData)
        result(FlutterStandardTypedData(bytes: plaintext))
      } catch {
        result(FlutterError(code: "DECRYPT_CHUNK_FAILED", message: error.localizedDescription, details: nil))
      }
      
    default:
      result(FlutterMethodNotImplemented)
    }
  }
}
