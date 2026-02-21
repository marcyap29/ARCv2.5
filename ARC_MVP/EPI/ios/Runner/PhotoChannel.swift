import Photos
import Flutter

/// Swift bridge for accessing photo library data
public class PhotoChannel: NSObject {
  public static func register(with registrar: FlutterPluginRegistrar) {
    let ch = FlutterMethodChannel(
      name: "com.orbitalai/photos", 
      binaryMessenger: registrar.messenger()
    )
    let inst = PhotoChannel()
    ch.setMethodCallHandler(inst.handle)
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "getPhotoBytes":
      guard let args = call.arguments as? [String: Any],
            let localId = args["localIdentifier"] as? String else {
        result(FlutterError(
          code: "ARG", 
          message: "Missing localIdentifier", 
          details: nil
        ))
        return
      }
      fetchBytes(localId: localId, result: result)
    case "getPhotoMetadata":
      guard let args = call.arguments as? [String: Any],
            let localId = args["localIdentifier"] as? String else {
        result(FlutterError(
          code: "ARG", 
          message: "Missing localIdentifier", 
          details: nil
        ))
        return
      }
      fetchMetadata(localId: localId, result: result)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func fetchBytes(localId: String, result: @escaping FlutterResult) {
    let assets = PHAsset.fetchAssets(withLocalIdentifiers: [localId], options: nil)
    guard let asset = assets.firstObject else { 
      result(nil)
      return 
    }

    let opts = PHImageRequestOptions()
    opts.isNetworkAccessAllowed = true
    opts.deliveryMode = .highQualityFormat
    opts.isSynchronous = false

    PHImageManager.default().requestImageDataAndOrientation(
      for: asset, 
      options: opts
    ) { data, uti, orientation, info in
      guard let data = data else { 
        result(nil)
        return 
      }
      
      let ext: String
      if let uti = uti {
        if uti.lowercased().contains("heic") {
          ext = "heic"
        } else if uti.lowercased().contains("jpeg") || uti.lowercased().contains("jpg") {
          ext = "jpg"
        } else if uti.lowercased().contains("png") {
          ext = "png"
        } else if uti.lowercased().contains("webp") {
          ext = "webp"
        } else {
          ext = "jpg" // Default fallback
        }
      } else {
        ext = "jpg"
      }
      
      result([
        "bytes": FlutterStandardTypedData(bytes: data),
        "ext": ext,
        "orientation": orientation.rawValue
      ])
    }
  }

  private func fetchMetadata(localId: String, result: @escaping FlutterResult) {
    let assets = PHAsset.fetchAssets(withLocalIdentifiers: [localId], options: nil)
    guard let asset = assets.firstObject else { 
      result(nil)
      return 
    }

    let metadata: [String: Any] = [
      "localIdentifier": asset.localIdentifier,
      "creationDate": asset.creationDate?.timeIntervalSince1970 ?? 0,
      "modificationDate": asset.modificationDate?.timeIntervalSince1970 ?? 0,
      "width": asset.pixelWidth,
      "height": asset.pixelHeight,
      "duration": asset.duration,
      "mediaType": asset.mediaType.rawValue,
      "mediaSubtypes": asset.mediaSubtypes.rawValue,
      "isFavorite": asset.isFavorite,
      "isHidden": asset.isHidden,
      "burstIdentifier": asset.burstIdentifier ?? "",
      "representsBurst": asset.representsBurst,
    ]

    result(metadata)
  }
}
