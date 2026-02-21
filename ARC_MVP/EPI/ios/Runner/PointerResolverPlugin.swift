import Flutter
import Photos
import UIKit

@available(iOS 9.0, *)
class PointerResolverPlugin: NSObject, FlutterPlugin {
    
    static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "pointer_resolver", binaryMessenger: registrar.messenger())
        let instance = PointerResolverPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }
    
    func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "loadBytesFromPHAsset":
            loadBytesFromPHAsset(call: call, result: result)
        case "openInPhotosApp":
            openInPhotosApp(call: call, result: result)
        case "isPHAssetAvailable":
            isPHAssetAvailable(call: call, result: result)
        case "requestPhotoLibraryPermission":
            requestPhotoLibraryPermission(result: result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    private func loadBytesFromPHAsset(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let localIdentifier = args["localIdentifier"] as? String else {
            result(FlutterError(code: "INVALID_ARGUMENT", message: "Missing localIdentifier", details: nil))
            return
        }
        
        let maxBytes = args["maxBytes"] as? Int
        
        let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [localIdentifier], options: nil)
        guard let asset = fetchResult.firstObject else {
            result(FlutterError(code: "ASSET_NOT_FOUND", message: "PHAsset not found", details: nil))
            return
        }
        
        let options = PHImageRequestOptions()
        options.isSynchronous = false
        options.isNetworkAccessAllowed = true
        options.deliveryMode = .highQualityFormat
        
        if asset.mediaType == .image {
            PHImageManager.default().requestImageDataAndOrientation(for: asset, options: options) { data, _, _, _ in
                DispatchQueue.main.async {
                    guard let imageData = data else {
                        result(FlutterError(code: "LOAD_ERROR", message: "Failed to load image data", details: nil))
                        return
                    }
                    
                    let finalData: Data
                    if let maxBytes = maxBytes, imageData.count > maxBytes {
                        finalData = imageData.prefix(maxBytes)
                    } else {
                        finalData = imageData
                    }
                    
                    result(FlutterStandardTypedData(bytes: finalData))
                }
            }
        } else if asset.mediaType == .video {
            let videoOptions = PHVideoRequestOptions()
            videoOptions.isNetworkAccessAllowed = true
            
            PHImageManager.default().requestAVAsset(forVideo: asset, options: videoOptions) { avAsset, _, _ in
                DispatchQueue.main.async {
                    guard let urlAsset = avAsset as? AVURLAsset else {
                        result(FlutterError(code: "LOAD_ERROR", message: "Failed to get video URL", details: nil))
                        return
                    }
                    
                    do {
                        let videoData = try Data(contentsOf: urlAsset.url)
                        let finalData: Data
                        if let maxBytes = maxBytes, videoData.count > maxBytes {
                            finalData = videoData.prefix(maxBytes)
                        } else {
                            finalData = videoData
                        }
                        
                        result(FlutterStandardTypedData(bytes: finalData))
                    } catch {
                        result(FlutterError(code: "LOAD_ERROR", message: "Failed to load video data: \(error)", details: nil))
                    }
                }
            }
        } else if asset.mediaType == .audio {
            let audioOptions = PHVideoRequestOptions() // PHVideoRequestOptions works for audio too
            audioOptions.isNetworkAccessAllowed = true
            
            PHImageManager.default().requestAVAsset(forVideo: asset, options: audioOptions) { avAsset, _, _ in
                DispatchQueue.main.async {
                    guard let urlAsset = avAsset as? AVURLAsset else {
                        result(FlutterError(code: "LOAD_ERROR", message: "Failed to get audio URL", details: nil))
                        return
                    }
                    
                    do {
                        let audioData = try Data(contentsOf: urlAsset.url)
                        let finalData: Data
                        if let maxBytes = maxBytes, audioData.count > maxBytes {
                            finalData = audioData.prefix(maxBytes)
                        } else {
                            finalData = audioData
                        }
                        
                        result(FlutterStandardTypedData(bytes: finalData))
                    } catch {
                        result(FlutterError(code: "LOAD_ERROR", message: "Failed to load audio data: \(error)", details: nil))
                    }
                }
            }
        } else {
            result(FlutterError(code: "UNSUPPORTED_TYPE", message: "Unsupported media type", details: nil))
        }
    }
    
    private func openInPhotosApp(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let localIdentifier = args["localIdentifier"] as? String else {
            result(FlutterError(code: "INVALID_ARGUMENT", message: "Missing localIdentifier", details: nil))
            return
        }
        
        // Try to open specific asset in Photos app
        let photosUrlString = "photos-redirect://asset?identifier=\(localIdentifier)"
        if let photosUrl = URL(string: photosUrlString),
           UIApplication.shared.canOpenURL(photosUrl) {
            UIApplication.shared.open(photosUrl) { success in
                result(success)
            }
        } else {
            // Fallback to opening Photos app
            let fallbackUrlString = "photos-redirect://"
            if let fallbackUrl = URL(string: fallbackUrlString),
               UIApplication.shared.canOpenURL(fallbackUrl) {
                UIApplication.shared.open(fallbackUrl) { success in
                    result(success)
                }
            } else {
                result(FlutterError(code: "OPEN_ERROR", message: "Cannot open Photos app", details: nil))
            }
        }
    }
    
    private func isPHAssetAvailable(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let localIdentifier = args["localIdentifier"] as? String else {
            result(false)
            return
        }
        
        let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [localIdentifier], options: nil)
        result(fetchResult.count > 0)
    }
    
    private func requestPhotoLibraryPermission(result: @escaping FlutterResult) {
        let status = PHPhotoLibrary.authorizationStatus()
        
        switch status {
        case .authorized, .limited:
            result("authorized")
        case .denied, .restricted:
            result("denied")
        case .notDetermined:
            PHPhotoLibrary.requestAuthorization { newStatus in
                DispatchQueue.main.async {
                    switch newStatus {
                    case .authorized, .limited:
                        result("authorized")
                    case .denied, .restricted:
                        result("denied")
                    default:
                        result("denied")
                    }
                }
            }
        @unknown default:
            result("denied")
        }
    }
}