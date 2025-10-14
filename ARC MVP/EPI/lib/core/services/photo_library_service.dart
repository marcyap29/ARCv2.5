import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

/// Service for managing photos in the iOS Photo Library
/// 
/// This service handles:
/// - Saving photos to the device photo library
/// - Loading photos from the photo library
/// - Managing photo library permissions
/// - Converting between file paths and photo library identifiers
class PhotoLibraryService {
  static const MethodChannel _channel = MethodChannel('photo_library_service');
  
  /// Request photo library permissions
  /// Returns true if permissions are granted, false otherwise
  ///
  /// Note: On iOS 14+, the actual permission prompt is handled by the native
  /// PhotoLibrary framework using PHPhotoLibrary.requestAuthorization(for: .readWrite)
  /// This ensures proper registration in iOS Settings → Photos
  static Future<bool> requestPermissions() async {
    try {
      print('PhotoLibraryService: Starting permission request process...');

      // Check current status
      final status = await Permission.photos.status;
      print('PhotoLibraryService: Current status - Photos: $status');

      // If already granted or limited, we're good
      if (status.isGranted || status.isLimited) {
        print('PhotoLibraryService: Permission already granted');
        return true;
      }

      // If permanently denied, user needs to go to Settings
      if (status.isPermanentlyDenied) {
        print('PhotoLibraryService: Permission permanently denied - user must enable in Settings');
        return false;
      }

      // Request permission
      // Note: This uses the iOS 14+ API internally via permission_handler
      print('PhotoLibraryService: Requesting photos permission...');
      final result = await Permission.photos.request();
      print('PhotoLibraryService: Photos permission result: $result');

      return result.isGranted || result.isLimited;
    } catch (e) {
      print('PhotoLibraryService: Error requesting permissions: $e');
      return false;
    }
  }
  
  /// Check if permissions are permanently denied and need manual settings access
  static Future<bool> arePermissionsPermanentlyDenied() async {
    try {
      final status = await Permission.photos.status;
      return status.isPermanentlyDenied;
    } catch (e) {
      print('PhotoLibraryService: Error checking permanent denial: $e');
      return false;
    }
  }
  
  /// Open app settings for manual permission granting
  static Future<bool> openSettings() async {
    try {
      print('PhotoLibraryService: Opening iOS Settings app...');
      // Use the global openAppSettings function from permission_handler package
      final opened = await openAppSettings();
      if (opened) {
        print('PhotoLibraryService: Successfully opened iOS Settings');
      } else {
        print('PhotoLibraryService: Failed to open iOS Settings');
      }
      return opened;
    } catch (e) {
      print('PhotoLibraryService: Error opening settings: $e');
      return false;
    }
  }
  
  /// Save a photo to the device photo library
  ///
  /// [imagePath] - Path to the image file to save
  /// Returns the photo library identifier (e.g., "ph://12345678-1234-1234-1234-123456789012")
  ///
  /// Note: Permissions are handled by the native iOS layer using
  /// PHPhotoLibrary.requestAuthorization(for: .readWrite)
  static Future<String?> savePhotoToLibrary(String imagePath) async {
    try {
      // Save photo to library using native iOS method
      // The native layer will request permissions if needed
      final result = await _channel.invokeMethod('savePhotoToLibrary', {
        'imagePath': imagePath,
      });

      if (result is String && result.isNotEmpty) {
        print('PhotoLibraryService: Photo saved to library with ID: $result');
        return result;
      } else {
        throw Exception('Failed to save photo to library');
      }
    } catch (e) {
      print('PhotoLibraryService: Error saving photo to library: $e');
      return null;
    }
  }
  
  /// Load a photo from the device photo library
  /// 
  /// [photoId] - Photo library identifier
  /// Returns the local file path where the photo can be accessed
  static Future<String?> loadPhotoFromLibrary(String photoId) async {
    try {
      // Check if we have photo library read permission
      final permission = await Permission.photos.status;
      if (!permission.isGranted) {
        throw Exception('Photo library read permission not granted');
      }
      
      // Load photo from library using native iOS method
      final result = await _channel.invokeMethod('loadPhotoFromLibrary', {
        'photoId': photoId,
      });
      
      if (result is String && result.isNotEmpty) {
        print('PhotoLibraryService: Photo loaded from library: $result');
        return result;
      } else {
        throw Exception('Failed to load photo from library');
      }
    } catch (e) {
      print('PhotoLibraryService: Error loading photo from library: $e');
      return null;
    }
  }
  
  /// Check if a photo exists in the library
  /// 
  /// [photoId] - Photo library identifier
  /// Returns true if the photo exists and is accessible
  static Future<bool> photoExistsInLibrary(String photoId) async {
    try {
      final permission = await Permission.photos.status;
      if (!permission.isGranted) {
        return false;
      }
      
      final result = await _channel.invokeMethod('photoExistsInLibrary', {
        'photoId': photoId,
      });
      
      return result == true;
    } catch (e) {
      print('PhotoLibraryService: Error checking photo existence: $e');
      return false;
    }
  }
  
  /// Get a thumbnail for a photo in the library
  /// 
  /// [photoId] - Photo library identifier
  /// [size] - Desired thumbnail size (width and height)
  /// Returns the local file path to the thumbnail
  static Future<String?> getPhotoThumbnail(String photoId, {int size = 200}) async {
    try {
      final permission = await Permission.photos.status;
      if (!permission.isGranted) {
        throw Exception('Photo library permission not granted');
      }
      
      final result = await _channel.invokeMethod('getPhotoThumbnail', {
        'photoId': photoId,
        'size': size,
      });
      
      if (result is String && result.isNotEmpty) {
        return result;
      } else {
        throw Exception('Failed to get photo thumbnail');
      }
    } catch (e) {
      print('PhotoLibraryService: Error getting photo thumbnail: $e');
      return null;
    }
  }
  
  /// Delete a photo from the library (if we have permission)
  /// 
  /// [photoId] - Photo library identifier
  /// Returns true if the photo was successfully deleted
  static Future<bool> deletePhotoFromLibrary(String photoId) async {
    try {
      final permission = await Permission.photos.status;
      if (!permission.isGranted) {
        return false;
      }
      
      final result = await _channel.invokeMethod('deletePhotoFromLibrary', {
        'photoId': photoId,
      });
      
      return result == true;
    } catch (e) {
      print('PhotoLibraryService: Error deleting photo from library: $e');
      return false;
    }
  }
  
  /// Check if photo library access is available
  static Future<bool> isPhotoLibraryAvailable() async {
    try {
      final permission = await Permission.photos.status;
      return permission.isGranted;
    } catch (e) {
      print('PhotoLibraryService: Error checking photo library availability: $e');
      return false;
    }
  }
}
