import Foundation
import Photos
import UIKit

@objc class PhotoLibraryService: NSObject {
    
    // MARK: - Method Channel
    private static let channelName = "photo_library_service"
    private static var methodChannel: FlutterMethodChannel?
    
    @objc static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: channelName, binaryMessenger: registrar.messenger())
        let instance = PhotoLibraryService()
        registrar.addMethodCallDelegate(instance, channel: channel)
        methodChannel = channel
    }
    
    // MARK: - Method Call Handler
    func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "savePhotoToLibrary":
            savePhotoToLibrary(call: call, result: result)
        case "loadPhotoFromLibrary":
            loadPhotoFromLibrary(call: call, result: result)
        case "photoExistsInLibrary":
            photoExistsInLibrary(call: call, result: result)
        case "getPhotoThumbnail":
            getPhotoThumbnail(call: call, result: result)
        case "deletePhotoFromLibrary":
            deletePhotoFromLibrary(call: call, result: result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    // MARK: - Save Photo to Library
    private func savePhotoToLibrary(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let imagePath = args["imagePath"] as? String else {
            result(FlutterError(code: "INVALID_ARGUMENTS", message: "Missing imagePath", details: nil))
            return
        }
        
        guard let image = UIImage(contentsOfFile: imagePath) else {
            result(FlutterError(code: "INVALID_IMAGE", message: "Could not load image from path: \(imagePath)", details: nil))
            return
        }
        
        // Request photo library permission
        PHPhotoLibrary.requestAuthorization { status in
            DispatchQueue.main.async {
                guard status == .authorized || status == .limited else {
                    result(FlutterError(code: "PERMISSION_DENIED", message: "Photo library permission denied", details: nil))
                    return
                }
                
                // Save image to photo library
                PHPhotoLibrary.shared().performChanges({
                    let creationRequest = PHAssetCreationRequest.forAsset()
                    creationRequest.addResource(with: .photo, fileURL: URL(fileURLWithPath: imagePath), options: nil)
                }) { success, error in
                    if success {
                        // Get the created asset's local identifier
                        let fetchOptions = PHFetchOptions()
                        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
                        fetchOptions.fetchLimit = 1
                        
                        let assets = PHAsset.fetchAssets(with: .image, options: fetchOptions)
                        if let asset = assets.firstObject {
                            let photoId = "ph://\(asset.localIdentifier)"
                            result(photoId)
                        } else {
                            result(FlutterError(code: "SAVE_FAILED", message: "Could not retrieve saved photo", details: nil))
                        }
                    } else {
                        result(FlutterError(code: "SAVE_FAILED", message: error?.localizedDescription ?? "Unknown error", details: nil))
                    }
                }
            }
        }
    }
    
    // MARK: - Load Photo from Library
    private func loadPhotoFromLibrary(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let photoId = args["photoId"] as? String else {
            result(FlutterError(code: "INVALID_ARGUMENTS", message: "Missing photoId", details: nil))
            return
        }
        
        // Extract local identifier from photo ID
        let localIdentifier = photoId.replacingOccurrences(of: "ph://", with: "")
        
        let fetchOptions = PHFetchOptions()
        let assets = PHAsset.fetchAssets(withLocalIdentifiers: [localIdentifier], options: fetchOptions)
        
        guard let asset = assets.firstObject else {
            result(FlutterError(code: "PHOTO_NOT_FOUND", message: "Photo not found in library", details: nil))
            return
        }
        
        // Request full resolution image
        let imageManager = PHImageManager.default()
        let requestOptions = PHImageRequestOptions()
        requestOptions.isSynchronous = false
        requestOptions.deliveryMode = .highQualityFormat
        requestOptions.isNetworkAccessAllowed = true
        
        imageManager.requestImage(for: asset, targetSize: PHImageManagerMaximumSize, contentMode: .aspectFit, options: requestOptions) { image, info in
            guard let image = image else {
                result(FlutterError(code: "LOAD_FAILED", message: "Could not load image", details: nil))
                return
            }
            
            // Save to temporary directory
            let tempDir = NSTemporaryDirectory()
            let fileName = "\(localIdentifier).jpg"
            let tempPath = (tempDir as NSString).appendingPathComponent(fileName)
            
            if let imageData = image.jpegData(compressionQuality: 0.9) {
                do {
                    try imageData.write(to: URL(fileURLWithPath: tempPath))
                    result(tempPath)
                } catch {
                    result(FlutterError(code: "SAVE_FAILED", message: "Could not save image to temp directory", details: nil))
                }
            } else {
                result(FlutterError(code: "CONVERSION_FAILED", message: "Could not convert image to JPEG", details: nil))
            }
        }
    }
    
    // MARK: - Check if Photo Exists
    private func photoExistsInLibrary(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let photoId = args["photoId"] as? String else {
            result(FlutterError(code: "INVALID_ARGUMENTS", message: "Missing photoId", details: nil))
            return
        }
        
        let localIdentifier = photoId.replacingOccurrences(of: "ph://", with: "")
        let fetchOptions = PHFetchOptions()
        let assets = PHAsset.fetchAssets(withLocalIdentifiers: [localIdentifier], options: fetchOptions)
        
        result(assets.count > 0)
    }
    
    // MARK: - Get Photo Thumbnail
    private func getPhotoThumbnail(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let photoId = args["photoId"] as? String,
              let size = args["size"] as? Int else {
            result(FlutterError(code: "INVALID_ARGUMENTS", message: "Missing photoId or size", details: nil))
            return
        }
        
        let localIdentifier = photoId.replacingOccurrences(of: "ph://", with: "")
        let fetchOptions = PHFetchOptions()
        let assets = PHAsset.fetchAssets(withLocalIdentifiers: [localIdentifier], options: fetchOptions)
        
        guard let asset = assets.firstObject else {
            result(FlutterError(code: "PHOTO_NOT_FOUND", message: "Photo not found in library", details: nil))
            return
        }
        
        let imageManager = PHImageManager.default()
        let requestOptions = PHImageRequestOptions()
        requestOptions.isSynchronous = false
        requestOptions.deliveryMode = .fastFormat
        requestOptions.isNetworkAccessAllowed = true
        
        let targetSize = CGSize(width: size, height: size)
        
        imageManager.requestImage(for: asset, targetSize: targetSize, contentMode: .aspectFill, options: requestOptions) { image, info in
            guard let image = image else {
                result(FlutterError(code: "THUMBNAIL_FAILED", message: "Could not generate thumbnail", details: nil))
                return
            }
            
            // Save thumbnail to temporary directory
            let tempDir = NSTemporaryDirectory()
            let fileName = "\(localIdentifier)_thumb_\(size).jpg"
            let tempPath = (tempDir as NSString).appendingPathComponent(fileName)
            
            if let imageData = image.jpegData(compressionQuality: 0.8) {
                do {
                    try imageData.write(to: URL(fileURLWithPath: tempPath))
                    result(tempPath)
                } catch {
                    result(FlutterError(code: "SAVE_FAILED", message: "Could not save thumbnail", details: nil))
                }
            } else {
                result(FlutterError(code: "CONVERSION_FAILED", message: "Could not convert thumbnail to JPEG", details: nil))
            }
        }
    }
    
    // MARK: - Delete Photo from Library
    private func deletePhotoFromLibrary(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let photoId = args["photoId"] as? String else {
            result(FlutterError(code: "INVALID_ARGUMENTS", message: "Missing photoId", details: nil))
            return
        }
        
        let localIdentifier = photoId.replacingOccurrences(of: "ph://", with: "")
        let fetchOptions = PHFetchOptions()
        let assets = PHAsset.fetchAssets(withLocalIdentifiers: [localIdentifier], options: fetchOptions)
        
        guard let asset = assets.firstObject else {
            result(false)
            return
        }
        
        PHPhotoLibrary.shared().performChanges({
            PHAssetChangeRequest.deleteAssets([asset] as NSArray)
        }) { success, error in
            DispatchQueue.main.async {
                result(success)
            }
        }
    }
}
