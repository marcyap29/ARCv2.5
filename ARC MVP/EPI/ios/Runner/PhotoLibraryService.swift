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
        case "getPhotoMetadata":
            getPhotoMetadata(call: call, result: result)
        case "findPhotoByMetadata":
            findPhotoByMetadata(call: call, result: result)
        case "findPhotoByPerceptualHash":
            findPhotoByPerceptualHash(call: call, result: result)
        case "relinkByMetadata":
            relinkByMetadata(call: call, result: result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    // MARK: - Helper Functions
    private func stripPhScheme(_ photoId: String) -> String {
        return photoId.hasPrefix("ph://") ? String(photoId.dropFirst(5)) : photoId
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
        requestOptions.isNetworkAccessAllowed = true

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
                var placeholder: PHObjectPlaceholder?
                PHPhotoLibrary.shared().performChanges({
                    let creationRequest = PHAssetCreationRequest.forAsset()
                    creationRequest.addResource(with: .photo, fileURL: URL(fileURLWithPath: imagePath), options: nil)
                    placeholder = creationRequest.placeholderForCreatedAsset
                }) { success, error in
                    if success, let placeholder = placeholder {
                        // Use the placeholder's local identifier immediately
                        let photoId = "ph://\(placeholder.localIdentifier)"
                        print("✅ PhotoLibraryService: Successfully saved photo with localIdentifier: \(placeholder.localIdentifier)")
                        print("✅ PhotoLibraryService: Returning photoId: \(photoId)")
                            result(photoId)
                    } else {
                        print("❌ PhotoLibraryService: Failed to save photo - error: \(error?.localizedDescription ?? "Unknown error")")
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
        let localIdentifier = stripPhScheme(photoId)

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
        
        let localIdentifier = stripPhScheme(photoId)
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

        let localIdentifier = stripPhScheme(photoId)
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
        
        let localIdentifier = stripPhScheme(photoId)
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
    
    // MARK: - Get Photo Metadata
    private func getPhotoMetadata(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let photoId = args["photoId"] as? String else {
            result(FlutterError(code: "INVALID_ARGUMENTS", message: "Missing photoId", details: nil))
            return
        }
        
        print("🔍 PhotoLibraryService: getPhotoMetadata called for photoId: \(photoId)")
        
        // Check photo library permission status
        let authStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        guard authStatus == .authorized || authStatus == .limited else {
            print("❌ PhotoLibraryService: Permission denied - status: \(authStatus.rawValue)")
            result(FlutterError(code: "PERMISSION_DENIED", message: "Photo library permission not granted", details: nil))
            return
        }
        
        let localIdentifier = stripPhScheme(photoId)
        print("🔍 PhotoLibraryService: Looking for localIdentifier: \(localIdentifier)")
        
        let fetchOptions = PHFetchOptions()
        let assets = PHAsset.fetchAssets(withLocalIdentifiers: [localIdentifier], options: fetchOptions)
        
        print("🔍 PhotoLibraryService: Found \(assets.count) assets with localIdentifier: \(localIdentifier)")
        
        guard let asset = assets.firstObject else {
            print("❌ PhotoLibraryService: No asset found for localIdentifier: \(localIdentifier)")
            result(FlutterError(code: "PHOTO_NOT_FOUND", message: "Photo not found in library", details: nil))
            return
        }
        
        print("✅ PhotoLibraryService: Found asset with localIdentifier: \(asset.localIdentifier)")
        
        // Extract metadata from PHAsset using PHAssetResource
        var metadata: [String: Any] = [:]
        metadata["local_identifier"] = asset.localIdentifier
        metadata["creation_date"] = asset.creationDate?.iso8601String
        metadata["modification_date"] = asset.modificationDate?.iso8601String
        metadata["pixel_width"] = asset.pixelWidth
        metadata["pixel_height"] = asset.pixelHeight

        let resources = PHAssetResource.assetResources(for: asset)
        let primary = resources.first
        metadata["filename"] = primary?.originalFilename
        metadata["uniform_type_identifier"] = primary?.uniformTypeIdentifier

        // Optional: approximate byte size via streaming later if needed; keep nil here.
        metadata["file_size"] = nil

        // Generate small perceptual hash (dHash) on a tiny rendition; allow iCloud fetch
        let imageManager = PHImageManager.default()
        let requestOptions = PHImageRequestOptions()
        requestOptions.isSynchronous = true
        requestOptions.deliveryMode = .fastFormat
        requestOptions.isNetworkAccessAllowed = true

        let targetSize = CGSize(width: 8, height: 8)
        imageManager.requestImage(for: asset,
                                  targetSize: targetSize,
                                  contentMode: .aspectFill,
                                  options: requestOptions) { image, _ in
            if let image = image, let hash = self.generatePerceptualHash(for: image) {
                metadata["perceptual_hash"] = hash
            }
            result(metadata)
        }
    }
    
    // MARK: - Find Photo by Metadata
    private func findPhotoByMetadata(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let metadata = args["metadata"] as? [String: Any] else {
            result(FlutterError(code: "INVALID_ARGUMENTS", message: "Missing metadata", details: nil))
            return
        }

        // Use the robust relink helper and return with ph:// prefix
        relinkByMetadata(call: call) { localId in
            result(localId != nil ? "ph://\(localId!)" : nil)
        }
    }
    
    // MARK: - Find Photo by Perceptual Hash
    private func findPhotoByPerceptualHash(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let hash = args["hash"] as? String else {
            result(FlutterError(code: "INVALID_ARGUMENTS", message: "Missing hash", details: nil))
            return
        }
        
        // Check photo library permission status
        let authStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        guard authStatus == .authorized || authStatus == .limited else {
            result(FlutterError(code: "PERMISSION_DENIED", message: "Photo library permission not granted", details: nil))
            return
        }
        
        // Fetch all photos from library
        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        fetchOptions.fetchLimit = 100 // Only check recent 100 photos for performance
        
        let allPhotos = PHAsset.fetchAssets(with: .image, options: fetchOptions)
        let imageManager = PHImageManager.default()
        let requestOptions = PHImageRequestOptions()
        requestOptions.isSynchronous = true
        requestOptions.deliveryMode = .fastFormat
        requestOptions.isNetworkAccessAllowed = true
        
        let targetSize = CGSize(width: 8, height: 8)
        
        // Search for matching hash
        var foundMatch: String? = nil
        
        allPhotos.enumerateObjects { (asset, index, stop) in
            imageManager.requestImage(for: asset, targetSize: targetSize, contentMode: .aspectFill, options: requestOptions) { image, info in
                if let image = image,
                   let assetHash = self.generatePerceptualHash(for: image),
                   assetHash == hash {
                    foundMatch = "ph://\(asset.localIdentifier)"
                    stop.pointee = true
                }
            }
        }
        
        result(foundMatch)
    }

    // MARK: - Relink by Metadata (portable) - FIXED VERSION
    private func relinkByMetadata(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let meta = args["metadata"] as? [String: Any] else {
            result(FlutterError(code: "INVALID_ARGUMENTS", message: "Missing metadata", details: nil))
            return
        }

        // Check photo library permission status
        let authStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        guard authStatus == .authorized || authStatus == .limited else {
            result(FlutterError(code: "PERMISSION_DENIED", message: "Photo library permission not granted", details: nil))
            return
        }

        // Parse inputs with better error handling
        let creationIso = meta["creation_date"] as? String
        let targetWidth  = meta["pixel_width"]  as? Int
        let targetHeight = meta["pixel_height"] as? Int
        let filename     = meta["filename"]     as? String
        let targetHash   = meta["perceptual_hash"] as? String
        let timestampMs  = meta["timestampMs"] as? Int

        print("🔍 PhotoLibraryService: Searching for photo with:")
        print("  - creationIso: \(creationIso ?? "nil")")
        print("  - filename: \(filename ?? "nil")")
        print("  - dimensions: \(targetWidth ?? 0)x\(targetHeight ?? 0)")
        print("  - timestampMs: \(timestampMs ?? 0)")

        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]

        var predicateParts: [String] = []
        var predicateArgs: [Any] = []

        // Build precise date filter (±1 second instead of ±3 minutes)
        if let iso = creationIso, let date = ISO8601DateFormatter().date(from: iso) {
            let lower = date.addingTimeInterval(-1.0)
            let upper = date.addingTimeInterval(1.0)
            predicateParts.append("(creationDate >= %@) AND (creationDate <= %@)")
            predicateArgs.append(lower as NSDate)
            predicateArgs.append(upper as NSDate)
        } else if let ts = timestampMs {
            let date = Date(timeIntervalSince1970: TimeInterval(ts) / 1000.0)
            let lower = date.addingTimeInterval(-1.0)
            let upper = date.addingTimeInterval(1.0)
            predicateParts.append("(creationDate >= %@) AND (creationDate <= %@)")
            predicateArgs.append(lower as NSDate)
            predicateArgs.append(upper as NSDate)
        }

        // Add filename filter if available
        if let filename = filename, !filename.isEmpty {
            predicateParts.append("filename == %@")
            predicateArgs.append(filename)
        }

        // Apply predicate if we have any filters
        if !predicateParts.isEmpty {
            fetchOptions.predicate = NSPredicate(format: predicateParts.joined(separator: " AND "), argumentArray: predicateArgs)
        }

        let fetch = PHAsset.fetchAssets(with: .image, options: fetchOptions)
        print("🔍 PhotoLibraryService: Found \(fetch.count) assets matching criteria")

        guard let asset = fetch.firstObject else {
            print("⚠️ PhotoLibraryService: No matching asset found for filename=\(filename ?? "nil") creationIso=\(creationIso ?? "nil") ts=\(timestampMs ?? 0)")
            result(nil)
            return
        }

        // Additional validation: check dimensions if provided
        if let targetWidth = targetWidth, let targetHeight = targetHeight {
            if asset.pixelWidth != targetWidth || asset.pixelHeight != targetHeight {
                print("⚠️ PhotoLibraryService: Asset dimensions don't match: \(asset.pixelWidth)x\(asset.pixelHeight) vs \(targetWidth)x\(targetHeight)")
                result(nil)
                return
            }
        }

        // Additional validation: check filename if provided
        if let filename = filename, !filename.isEmpty {
            let resources = PHAssetResource.assetResources(for: asset)
            let actualFilename = resources.first?.originalFilename
            if actualFilename != filename {
                print("⚠️ PhotoLibraryService: Filename doesn't match: '\(actualFilename ?? "nil")' vs '\(filename)'")
                result(nil)
                return
            }
        }

        print("✅ PhotoLibraryService: Found matching asset: \(asset.localIdentifier)")
        logCandidateMatch(asset, filename)
        result(asset.localIdentifier)
    }

    // MARK: - Debug Helper
    private func logCandidateMatch(_ asset: PHAsset, _ filename: String?) {
        let formatter = ISO8601DateFormatter()
        let dateStr = asset.creationDate.map { formatter.string(from: $0) } ?? "unknown"
        print("📸 PhotoLibraryService: Matched asset id=\(asset.localIdentifier), filename=\(filename ?? "nil"), creationDate=\(dateStr), dimensions=\(asset.pixelWidth)x\(asset.pixelHeight)")
    }
}

// MARK: - Date Extension for ISO8601
extension Date {
    var iso8601String: String {
        let formatter = ISO8601DateFormatter()
        return formatter.string(from: self)
    }
}
