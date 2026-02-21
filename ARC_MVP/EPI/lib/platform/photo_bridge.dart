import 'dart:typed_data';
import 'package:flutter/services.dart';

/// Bridge for accessing photo library data from iOS
class PhotoBridge {
  static const MethodChannel _channel = MethodChannel('com.orbitalai/photos');

  /// Get photo bytes from iOS Photo Library
  ///
  /// [localIdentifier] - The PHAsset local identifier
  /// Returns a map with 'bytes' (Uint8List) and 'ext' (String)
  static Future<Map<String, dynamic>?> getPhotoBytes(String localIdentifier) async {
    try {
      final result = await _channel.invokeMethod('getPhotoBytes', {
        'localIdentifier': localIdentifier,
      });

      if (result is Map) {
        // Convert FlutterStandardTypedData to Uint8List if needed
        final bytes = result['bytes'];
        final Uint8List actualBytes;

        if (bytes is Uint8List) {
          actualBytes = bytes;
        } else if (bytes != null) {
          // Handle FlutterStandardTypedData
          actualBytes = bytes as Uint8List;
        } else {
          print('PhotoBridge: No bytes returned for $localIdentifier');
          return null;
        }

        return {
          'bytes': actualBytes,
          'ext': result['ext'] as String? ?? 'jpg',
          'orientation': result['orientation'] as int? ?? 1,
        };
      }
      return null;
    } catch (e) {
      print('PhotoBridge: Error getting photo bytes for $localIdentifier: $e');
      return null;
    }
  }

  /// Get photo metadata from iOS Photo Library
  /// 
  /// [localIdentifier] - The PHAsset local identifier
  /// Returns a map with photo metadata
  static Future<Map<String, dynamic>?> getPhotoMetadata(String localIdentifier) async {
    try {
      final result = await _channel.invokeMethod('getPhotoMetadata', {
        'localIdentifier': localIdentifier,
      });
      
      if (result is Map<String, dynamic>) {
        return result;
      }
      return null;
    } catch (e) {
      print('PhotoBridge: Error getting photo metadata: $e');
      return null;
    }
  }

  /// Extract local identifier from ph:// URI
  static String? extractLocalIdentifier(String uri) {
    if (uri.startsWith('ph://')) {
      return uri.substring(5); // Remove 'ph://' prefix
    }
    return null;
  }

  /// Check if URI is a photo library reference
  static bool isPhotoLibraryUri(String uri) {
    return uri.startsWith('ph://');
  }

  /// Check if URI is a file path
  static bool isFilePath(String uri) {
    return uri.startsWith('file://') || (!uri.contains('://') && uri.contains('/'));
  }

  /// Check if URI is a network URL
  static bool isNetworkUrl(String uri) {
    return uri.startsWith('http://') || uri.startsWith('https://');
  }
}
