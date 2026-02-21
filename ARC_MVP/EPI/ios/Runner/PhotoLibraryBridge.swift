import Foundation
import Flutter
import Photos

@objc class PhotoLibraryBridge: NSObject, FlutterPlugin {
  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "photo_library", binaryMessenger: registrar.messenger())
    let instance = PhotoLibraryBridge()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "photoExistsInLibrary":
      guard let args = call.arguments as? [String: Any],
            let photoId = args["photoId"] as? String else {
        result(false)
        return
      }
      photoExistsInLibrary(photoId: photoId, result)
      
    case "findPhotoByMetadata":
      guard let args = call.arguments as? [String: Any],
            let meta = args["metadata"] as? [String: Any] else {
        result(nil)
        return
      }
      findPhotoByMetadata(meta: meta, result)
      
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func photoExistsInLibrary(photoId: String, _ result: @escaping FlutterResult) {
    let prefix = "ph://"
    guard photoId.hasPrefix(prefix) else {
      result(false)
      return
    }
    
    let id = String(photoId.dropFirst(prefix.count))
    let assets = PHAsset.fetchAssets(withLocalIdentifiers: [id], options: nil)
    result(assets.firstObject != nil)
  }

  private func findPhotoByMetadata(meta: [String: Any], _ result: @escaping FlutterResult) {
    var start: Date? = nil
    var end: Date? = nil
    
    if let iso = meta["creation_date"] as? String,
       let dt = ISO8601DateFormatter().date(from: iso) {
      start = dt.addingTimeInterval(-180)  // ±3 minutes
      end = dt.addingTimeInterval(+180)
    }

    let fetchOptions = PHFetchOptions()
    if let s = start, let e = end {
      fetchOptions.predicate = NSPredicate(
        format: "creationDate >= %@ AND creationDate <= %@", s as NSDate, e as NSDate
      )
    }
    fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]

    let assets = PHAsset.fetchAssets(with: .image, options: fetchOptions)
    guard let asset = assets.firstObject else {
      result(nil)
      return
    }
    
    result("ph://\(asset.localIdentifier)")
  }
}
