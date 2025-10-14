import Foundation
import Photos
import UIKit
import CommonCrypto

@objc class PhotoLibraryService: NSObject {

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
        case "findDuplicatePhoto":
            findDuplicatePhoto(call: call, result: result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    // MARK: - Perceptual Hash Generation
    private func generatePerceptualHash(for image: UIImage) -> String? {
        // Resize image to 8x8 for perceptual hashing
        let size = CGSize(width: 8, height: 8)
        UIGraphicsBeginImageContextWithOptions(size, true, 1.0)
        defer { UIGraphicsEndImageContext() }

        image.draw(in: CGRect(origin: .zero, size: size))
        guard let resizedImage = UIGraphicsGetImageFromCurrentImageContext(),
              let cgImage = resizedImage.cgImage else {
            return nil
        }

        // Convert to grayscale and get pixel data
        let width = cgImage.width
        let height = cgImage.height
        let bytesPerPixel = 1
        let bytesPerRow = bytesPerPixel * width
        let bitsPerComponent = 8

        var pixelData = [UInt8](repeating: 0, count: width * height)

        let colorSpace = CGColorSpaceCreateDeviceGray()
        guard let context = CGContext(
            data: &pixelData,
            width: width,
            height: height,
            bitsPerComponent: bitsPerComponent,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else {
            return nil
        }

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        // Calculate average pixel value
        let sum = pixelData.reduce(0, { $0 + Int($1) })
        let average = sum / pixelData.count

        // Generate hash based on pixels above/below average
        var hash: UInt64 = 0
        for (index, pixel) in pixelData.enumerated() {
            if pixel > average {
                hash |= (1 << index)
            }
        }

        // Convert to hex string
        return String(format: "%016llx", hash)
    }

    // MARK: - Find Duplicate Photo
    private func findDuplicatePhoto(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let imagePath = args["imagePath"] as? String else {
            result(FlutterError(code: "INVALID_ARGUMENTS", message: "Missing imagePath", details: nil))
            return
        }

        guard let image = UIImage(contentsOfFile: imagePath),
              let targetHash = generatePerceptualHash(for: image) else {
            result(FlutterError(code: "HASH_FAILED", message: "Could not generate perceptual hash", details: nil))
            return
        }

        // Check photo library permission status
        let authStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        guard authStatus == .authorized || authStatus == .limited else {
            // No permission - can't check for duplicates, return nil (treat as not found)
            result(nil)
            return
        }

        // Fetch all photos from library
        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        fetchOptions.fetchLimit = 100 // Only check recent 100 photos for performance

        let allPhotos = PHAsset.fetchAssets(with: .image, options: fetchOptions)

        // Check each photo for matching hash
        var foundMatch: String? = nil
        let imageManager = PHImageManager.default()
        let requestOptions = PHImageRequestOptions()
        requestOptions.isSynchronous = true
        requestOptions.deliveryMode = .fastFormat
        requestOptions.isNetworkAccessAllowed = false

        let targetSize = CGSize(width: 8, height: 8)

        allPhotos.enumerateObjects { (asset, index, stop) in
            imageManager.requestImage(
                for: asset,
                targetSize: targetSize,
                contentMode: .aspectFill,
                options: requestOptions
            ) { (thumbnailImage, info) in
                guard let thumbnailImage = thumbnailImage,
                      let photoHash = self.generatePerceptualHash(for: thumbnailImage) else {
                    return
                }

                // Compare hashes (exact match for now, could use Hamming distance for similarity)
                if photoHash == targetHash {
                    foundMatch = "ph://\(asset.localIdentifier)"
                    stop.pointee = true
                }
            }
        }

        result(foundMatch)
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
        
        // Request photo library permission using iOS 14+ API
        PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
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

        // Check photo library permission status
        let authStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        guard authStatus == .authorized || authStatus == .limited else {
            result(FlutterError(code: "PERMISSION_DENIED", message: "Photo library permission not granted", details: nil))
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

        // Check photo library permission status
        let authStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        guard authStatus == .authorized || authStatus == .limited else {
            result(FlutterError(code: "PERMISSION_DENIED", message: "Photo library permission not granted", details: nil))
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

            // Convert to image without alpha channel to avoid iOS warning
            // Create a new context without alpha
            let imageSize = image.size
            let imageScale = image.scale

            UIGraphicsBeginImageContextWithOptions(imageSize, true, imageScale) // true = opaque
            defer { UIGraphicsEndImageContext() }

            // Draw white background first (for images with transparency)
            UIColor.white.setFill()
            UIRectFill(CGRect(origin: .zero, size: imageSize))

            // Draw the image on top
            image.draw(at: .zero)

            guard let opaqueImage = UIGraphicsGetImageFromCurrentImageContext() else {
                result(FlutterError(code: "CONVERSION_FAILED", message: "Could not create opaque image", details: nil))
                return
            }

            // Save thumbnail to temporary directory
            let tempDir = NSTemporaryDirectory()
            let fileName = "\(localIdentifier)_thumb_\(size).jpg"
            let tempPath = (tempDir as NSString).appendingPathComponent(fileName)
            
            print("DEBUG: Creating thumbnail at path: \(tempPath)")
            print("DEBUG: Image size: \(imageSize), scale: \(imageScale)")
            print("DEBUG: Opaque image created: \(opaqueImage != nil)")

            if let imageData = opaqueImage.jpegData(compressionQuality: 0.8) {
                print("DEBUG: JPEG data created, size: \(imageData.count) bytes")
                do {
                    // Ensure the directory exists
                    let tempURL = URL(fileURLWithPath: tempPath)
                    let directory = tempURL.deletingLastPathComponent()
                    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: nil)
                    
                    try imageData.write(to: tempURL)
                    print("DEBUG: Thumbnail saved successfully to: \(tempPath)")
                    result(tempPath)
                } catch {
                    print("DEBUG: Failed to save thumbnail: \(error.localizedDescription)")
                    result(FlutterError(code: "SAVE_FAILED", message: "Could not save thumbnail: \(error.localizedDescription)", details: nil))
                }
            } else {
                print("DEBUG: Failed to create JPEG data from opaque image")
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
