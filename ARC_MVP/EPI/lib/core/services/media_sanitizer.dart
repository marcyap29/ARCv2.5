import 'dart:typed_data';
import 'package:image/image.dart' as img;

/// Service for sanitizing media files
/// Handles EXIF removal, image downscaling, and size validation
class MediaSanitizer {
  static const int _maxImageWidth = 2048;
  static const int _maxImageHeight = 2048;
  static const int _maxFileSizeBytes = 10 * 1024 * 1024; // 10MB
  static const int _jpegQuality = 85;
  
  /// Sanitize image data by removing EXIF and downscaling if needed
  Future<Uint8List> sanitizeImage(Uint8List imageData) async {
    try {
      // Decode the image
      final image = img.decodeImage(imageData);
      if (image == null) {
        throw const MediaSanitizerException('Failed to decode image');
      }
      
      // Check if image needs downscaling
      bool needsDownscaling = image.width > _maxImageWidth || image.height > _maxImageHeight;
      
      if (needsDownscaling) {
        // Calculate new dimensions maintaining aspect ratio
        final aspectRatio = image.width / image.height;
        int newWidth, newHeight;
        
        if (aspectRatio > 1) {
          // Landscape
          newWidth = _maxImageWidth;
          newHeight = (_maxImageWidth / aspectRatio).round();
        } else {
          // Portrait or square
          newHeight = _maxImageHeight;
          newWidth = (_maxImageHeight * aspectRatio).round();
        }
        
        // Resize image
        final resizedImage = img.copyResize(
          image,
          width: newWidth,
          height: newHeight,
          interpolation: img.Interpolation.cubic,
        );
        
        print('MediaSanitizer: Downscaled image from ${image.width}x${image.height} to ${resizedImage.width}x${resizedImage.height}');
        
        // Encode as JPEG with quality setting (this removes EXIF)
        final sanitizedData = Uint8List.fromList(
          img.encodeJpg(resizedImage, quality: _jpegQuality)
        );
        
        // Validate final size
        if (sanitizedData.length > _maxFileSizeBytes) {
          throw MediaSanitizerException('Image still too large after downscaling: ${sanitizedData.length} bytes');
        }
        
        return sanitizedData;
      } else {
        // Image doesn't need downscaling, just re-encode to remove EXIF
        final sanitizedData = Uint8List.fromList(
          img.encodeJpg(image, quality: _jpegQuality)
        );
        
        // Validate final size
        if (sanitizedData.length > _maxFileSizeBytes) {
          throw MediaSanitizerException('Image too large: ${sanitizedData.length} bytes');
        }
        
        return sanitizedData;
      }
      
    } catch (e) {
      print('MediaSanitizer: Error sanitizing image: $e');
      throw MediaSanitizerException('Failed to sanitize image: $e');
    }
  }
  
  /// Validate file size
  bool validateFileSize(Uint8List data) {
    return data.length <= _maxFileSizeBytes;
  }
  
  /// Get file size in human-readable format
  String getFileSizeString(int bytes) {
    if (bytes < 1024) {
      return '${bytes}B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)}KB';
    } else {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
    }
  }
  
  /// Check if image needs sanitization
  Future<bool> needsSanitization(Uint8List imageData) async {
    try {
      final image = img.decodeImage(imageData);
      if (image == null) return true;
      
      // Check if image is too large
      bool tooLarge = image.width > _maxImageWidth || image.height > _maxImageHeight;
      
      // Check if file size is too large
      bool fileTooLarge = imageData.length > _maxFileSizeBytes;
      
      return tooLarge || fileTooLarge;
    } catch (e) {
      print('MediaSanitizer: Error checking if image needs sanitization: $e');
      return true; // Assume it needs sanitization if we can't check
    }
  }
  
  /// Get image dimensions
  Future<Map<String, int>?> getImageDimensions(Uint8List imageData) async {
    try {
      final image = img.decodeImage(imageData);
      if (image == null) return null;
      
      return {
        'width': image.width,
        'height': image.height,
      };
    } catch (e) {
      print('MediaSanitizer: Error getting image dimensions: $e');
      return null;
    }
  }
  
  /// Create a thumbnail for an image
  Future<Uint8List> createThumbnail(Uint8List imageData, {int maxSize = 200}) async {
    try {
      final image = img.decodeImage(imageData);
      if (image == null) {
        throw const MediaSanitizerException('Failed to decode image for thumbnail');
      }
      
      // Calculate thumbnail dimensions maintaining aspect ratio
      final aspectRatio = image.width / image.height;
      int thumbWidth, thumbHeight;
      
      if (aspectRatio > 1) {
        // Landscape
        thumbWidth = maxSize;
        thumbHeight = (maxSize / aspectRatio).round();
      } else {
        // Portrait or square
        thumbHeight = maxSize;
        thumbWidth = (maxSize * aspectRatio).round();
      }
      
      // Create thumbnail
      final thumbnail = img.copyResize(
        image,
        width: thumbWidth,
        height: thumbHeight,
        interpolation: img.Interpolation.cubic,
      );
      
      // Encode as JPEG
      return Uint8List.fromList(img.encodeJpg(thumbnail, quality: 80));
      
    } catch (e) {
      print('MediaSanitizer: Error creating thumbnail: $e');
      throw MediaSanitizerException('Failed to create thumbnail: $e');
    }
  }
  
  /// Validate audio file format and size
  bool validateAudio(Uint8List audioData) {
    // Check file size
    if (!validateFileSize(audioData)) {
      return false;
    }
    
    // Check if it's a valid audio format by looking at file headers
    // M4A files typically start with specific bytes
    if (audioData.length >= 4) {
      // Check for common audio file signatures
      final header = audioData.sublist(0, 4);
      
      // M4A/MP4 files often start with specific patterns
      // This is a basic check - in production you might want more robust validation
      return true; // For now, accept all files under size limit
    }
    
    return false;
  }
  
  /// Validate video file format and size
  bool validateVideo(Uint8List videoData) {
    // Check file size
    if (!validateFileSize(videoData)) {
      return false;
    }
    
    // Basic video file validation
    if (videoData.length >= 4) {
      // Check for common video file signatures
      final header = videoData.sublist(0, 4);
      
      // MP4 files often start with specific patterns
      // This is a basic check - in production you might want more robust validation
      return true; // For now, accept all files under size limit
    }
    
    return false;
  }
}

/// Exception thrown by MediaSanitizer operations
class MediaSanitizerException implements Exception {
  final String message;
  const MediaSanitizerException(this.message);
  
  @override
  String toString() => 'MediaSanitizerException: $message';
}
