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
        case "getCloudIdentifier":
            getCloudIdentifier(call: call, result: result)
        case "findPhotoByCloudIdentifier":
            findPhotoByCloudIdentifier(call: call, result: result)
        case "robustPhotoRelink":
            robustPhotoRelink(call: call, result: result)
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

    // MARK: - Relink by Metadata (portable)
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

        // Parse inputs
        let creationIso = meta["creation_date"] as? String
        let targetWidth  = meta["pixel_width"]  as? Int
        let targetHeight = meta["pixel_height"] as? Int
        let filename     = meta["filename"]     as? String
        let targetHash   = meta["perceptual_hash"] as? String

        let fetchOpts = PHFetchOptions()
        // Date window: ±3 minutes around creationDate if provided
        if let creationIsoString = creationIso, let date = ISO8601DateFormatter().date(from: creationIsoString) {
            let fromDate = date.addingTimeInterval(-180)
            let toDate   = date.addingTimeInterval( 180)
            fetchOpts.predicate = NSPredicate(format: "creationDate >= %@ AND creationDate <= %@", fromDate as NSDate, toDate as NSDate)
        }
        fetchOpts.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        fetchOpts.fetchLimit = 200

        let results = PHAsset.fetchAssets(with: .image, options: fetchOpts)
        if results.count == 0 { result(nil); return }

        // Pass 1: dimension filter
        var candidates: [PHAsset] = []
        results.enumerateObjects { asset, _, _ in
            if let targetWidth = targetWidth, let targetHeight = targetHeight {
                if asset.pixelWidth == targetWidth && asset.pixelHeight == targetHeight {
                    candidates.append(asset)
                }
            } else {
                candidates.append(asset)
            }
        }
        if candidates.isEmpty { result(nil); return }

        // Pass 2: filename refinement
        if let name = filename {
            let exact = candidates.first(where: { PHAssetResource.assetResources(for: $0).first?.originalFilename == name })
            if let hit = exact {
                result(hit.localIdentifier); return
            }
        }

        // Pass 3: perceptual hash (if present)
        if let target = targetHash {
            let opts = PHImageRequestOptions()
            opts.isSynchronous = true
            opts.deliveryMode = .fastFormat
            opts.isNetworkAccessAllowed = true
            let targetSize = CGSize(width: 8, height: 8)
            for asset in candidates {
                var matched = false
                PHImageManager.default().requestImage(for: asset, targetSize: targetSize, contentMode: .aspectFill, options: opts) { img, _ in
                    if let img = img, let hash = self.generatePerceptualHash(for: img), hash == target {
                        matched = true
                    }
                }
                if matched { result(asset.localIdentifier); return }
            }
        }

        // Last resort: best candidate by recency
        result(candidates.first?.localIdentifier)
    }
    
    // MARK: - Cloud Identifier Support
    
    /// Get cloud identifier for a local photo
    private func getCloudIdentifier(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let localId = args["localId"] as? String else {
            result(FlutterError(code: "INVALID_ARGUMENTS", message: "Missing localId", details: nil))
            return
        }
        
        let localIdentifier = stripPhScheme(localId)
        let assets = PHAsset.fetchAssets(withLocalIdentifiers: [localIdentifier], options: nil)
        
        guard let asset = assets.firstObject else {
            result(nil)
            return
        }

        // Get cloud identifier for the asset
        // Note: Cloud identifier APIs are complex and require async/await in modern iOS
        // For now, return nil as this is a fallback feature
        result(nil)
    }
    
    /// Find photo by cloud identifier
    private func findPhotoByCloudIdentifier(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let cloudIdString = args["cloudId"] as? String else {
            result(FlutterError(code: "INVALID_ARGUMENTS", message: "Missing cloudId", details: nil))
            return
        }
        
        // Note: Cloud identifier APIs are complex and require async/await in modern iOS
        // For now, return nil as this is a fallback feature
        result(nil)
    }
    
    /// Robust photo relinking using the 4-step algorithm
    private func robustPhotoRelink(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let metadata = args["metadata"] as? [String: Any] else {
            result(FlutterError(code: "INVALID_ARGUMENTS", message: "Missing metadata", details: nil))
            return
        }

        let localId = metadata["local_identifier"] as? String ?? ""
        let cloudId = metadata["cloud_identifier"] as? String
        let creationDate = metadata["creation_date"] as? String
        let pixelWidth = metadata["pixel_width"] as? Int
        let pixelHeight = metadata["pixel_height"] as? Int
        let filename = metadata["filename"] as? String
        let perceptualHash = metadata["perceptual_hash"] as? String
        
        // Step 1: Try local identifier first
        if !localId.isEmpty {
            let assets = PHAsset.fetchAssets(withLocalIdentifiers: [localId], options: nil)
            if assets.firstObject != nil {
                result("ph://\(localId)")
                return
            }
        }

        // Step 2: Cloud identifier lookup not available (requires async/await)
        // Skip to heuristic search

        // Step 3: Heuristic search
        performHeuristicSearch(creationDate: creationDate, pixelWidth: pixelWidth, pixelHeight: pixelHeight, filename: filename, perceptualHash: perceptualHash, result: result)
    }
    
    /// Perform heuristic search for photo matching
    private func performHeuristicSearch(creationDate: String?, pixelWidth: Int?, pixelHeight: Int?, filename: String?, perceptualHash: String?, result: @escaping FlutterResult) {
        var predicates: [NSPredicate] = []
        
        // Add creation date predicate
        if let creationDate = creationDate,
           let date = ISO8601DateFormatter().date(from: creationDate) {
            let tolerance: TimeInterval = 60 // 1 minute tolerance
            let startDate = date.addingTimeInterval(-tolerance)
            let endDate = date.addingTimeInterval(tolerance)
            predicates.append(NSPredicate(format: "creationDate >= %@ AND creationDate <= %@", startDate as NSDate, endDate as NSDate))
        }
        
        // Add filename predicate
        if let filename = filename {
            predicates.append(NSPredicate(format: "filename == %@", filename))
        }
        
        // Add pixel dimensions predicate
        if let width = pixelWidth, let height = pixelHeight {
            predicates.append(NSPredicate(format: "pixelWidth == %d AND pixelHeight == %d", width, height))
        }
        
        // Combine predicates
        let fetchOptions = PHFetchOptions()
        if !predicates.isEmpty {
            fetchOptions.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
        }
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        
        let assets = PHAsset.fetchAssets(with: .image, options: fetchOptions)
        
        if assets.count == 0 {
            result(nil)
            return
        }
        
        // If we have a perceptual hash, try to match it
        if let perceptualHash = perceptualHash {
            let candidates = (0..<assets.count).compactMap { assets.object(at: $0) }
            let opts = PHImageRequestOptions()
            opts.isSynchronous = true
            opts.deliveryMode = .fastFormat
            opts.isNetworkAccessAllowed = true
            let targetSize = CGSize(width: 8, height: 8)
            
            for asset in candidates {
                var matched = false
                PHImageManager.default().requestImage(for: asset, targetSize: targetSize, contentMode: .aspectFill, options: opts) { img, _ in
                    if let img = img, let hash = self.generatePerceptualHash(for: img), hash == perceptualHash {
                        matched = true
                    }
                }
                if matched {
                    result("ph://\(asset.localIdentifier)")
                    return
                }
            }
        }
        
        // Step 4: Return best candidate or nil
        if let bestMatch = assets.firstObject {
            result("ph://\(bestMatch.localIdentifier)")
        } else {
            result(nil)
        }
    }
}

// MARK: - Date Extension for ISO8601
extension Date {
    var iso8601String: String {
        let formatter = ISO8601DateFormatter()
        return formatter.string(from: self)
    }
}
