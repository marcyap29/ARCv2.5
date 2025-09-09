import 'dart:typed_data';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as img;
import '../pointer/pointer_models.dart';

/// Result of image analysis operations
class ImageAnalysisResult {
  final FaceAnalysis? faces;
  final OCRResult? ocr;
  final List<String>? labels;
  final ExifData? exif;
  final int width;
  final int height;
  final String mimeType;

  const ImageAnalysisResult({
    this.faces,
    this.ocr,
    this.labels,
    this.exif,
    required this.width,
    required this.height,
    required this.mimeType,
  });
}

/// Abstract interface for vision analysis
abstract class VisionAnalysisService {
  Future<ImageAnalysisResult> analyzeImage(Uint8List imageBytes);
  Future<void> dispose();
}

/// Implementation using Google ML Kit
class MLKitVisionAnalysisService implements VisionAnalysisService {
  final TextRecognizer _textRecognizer;
  final FaceDetector _faceDetector;

  MLKitVisionAnalysisService._({
    required TextRecognizer textRecognizer,
    required FaceDetector faceDetector,
  })  : _textRecognizer = textRecognizer,
        _faceDetector = faceDetector;

  /// Factory constructor to create initialized service
  static Future<MLKitVisionAnalysisService> create() async {
    final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
    final faceDetector = FaceDetector(
      options: FaceDetectorOptions(
        enableClassification: false,
        enableLandmarks: false,
        enableContours: false,
        enableTracking: false,
      ),
    );

    return MLKitVisionAnalysisService._(
      textRecognizer: textRecognizer,
      faceDetector: faceDetector,
    );
  }

  @override
  Future<ImageAnalysisResult> analyzeImage(Uint8List imageBytes) async {
    try {
      // Decode image to get dimensions and format info
      final decodedImage = img.decodeImage(imageBytes);
      if (decodedImage == null) {
        throw VisionAnalysisException('Failed to decode image');
      }

      final width = decodedImage.width;
      final height = decodedImage.height;
      
      // Determine MIME type (simplified detection)
      String mimeType = 'image/jpeg'; // Default assumption
      if (imageBytes.length > 4) {
        if (imageBytes[0] == 0x89 && imageBytes[1] == 0x50 && imageBytes[2] == 0x4E && imageBytes[3] == 0x47) {
          mimeType = 'image/png';
        } else if (imageBytes[0] == 0xFF && imageBytes[1] == 0xD8) {
          mimeType = 'image/jpeg';
        }
      }

      // Create InputImage from bytes
      final inputImage = InputImage.fromBytes(
        bytes: imageBytes,
        metadata: InputImageMetadata(
          size: Size(width.toDouble(), height.toDouble()),
          rotation: InputImageRotation.rotation0deg,
          format: InputImageFormat.yuv420,
          bytesPerRow: width * 4, // Approximate for RGBA
        ),
      );

      // Perform OCR
      OCRResult? ocrResult;
      try {
        final recognizedText = await _textRecognizer.processImage(inputImage);
        if (recognizedText.text.isNotEmpty) {
          ocrResult = OCRResult(text: recognizedText.text);
        }
      } catch (e) {
        print('MLKitVisionAnalysisService: OCR failed: $e');
      }

      // Perform face detection
      FaceAnalysis? faceAnalysis;
      try {
        final faces = await _faceDetector.processImage(inputImage);
        if (faces.isNotEmpty) {
          faceAnalysis = FaceAnalysis(count: faces.length);
        }
      } catch (e) {
        print('MLKitVisionAnalysisService: Face detection failed: $e');
      }

      // Extract EXIF data (stub implementation)
      ExifData? exifData;
      try {
        exifData = await _extractExifData(imageBytes);
      } catch (e) {
        print('MLKitVisionAnalysisService: EXIF extraction failed: $e');
      }

      // Generate labels (stub implementation)
      List<String>? labels;
      try {
        labels = await _generateLabels(decodedImage, ocrResult, faceAnalysis);
      } catch (e) {
        print('MLKitVisionAnalysisService: Label generation failed: $e');
      }

      return ImageAnalysisResult(
        faces: faceAnalysis,
        ocr: ocrResult,
        labels: labels,
        exif: exifData,
        width: width,
        height: height,
        mimeType: mimeType,
      );
    } catch (e) {
      throw VisionAnalysisException('Image analysis failed: $e');
    }
  }

  /// Extract EXIF data from image bytes (stub implementation)
  Future<ExifData?> _extractExifData(Uint8List imageBytes) async {
    // This is a stub implementation
    // In a real app, you would use a library like 'exif' to extract metadata
    
    // For now, just return basic data with current timestamp
    return ExifData(
      takenAt: DateTime.now(), // Placeholder
      gps: null, // Would extract GPS coordinates if present
    );
  }

  /// Generate semantic labels for the image (stub implementation)
  Future<List<String>?> _generateLabels(
    img.Image image,
    OCRResult? ocrResult,
    FaceAnalysis? faceAnalysis,
  ) async {
    final labels = <String>[];

    // Basic heuristics for label generation
    if (faceAnalysis != null && faceAnalysis.count > 0) {
      labels.add('person');
      if (faceAnalysis.count > 1) {
        labels.add('group');
      }
    }

    if (ocrResult != null && ocrResult.text.isNotEmpty) {
      labels.add('text');
      
      // Look for common keywords in OCR text
      final text = ocrResult.text.toLowerCase();
      if (text.contains('menu') || text.contains('restaurant') || text.contains('food')) {
        labels.add('food');
      }
      if (text.contains('sign') || text.contains('street')) {
        labels.add('sign');
      }
      if (text.contains('document') || text.contains('letter')) {
        labels.add('document');
      }
    }

    // Basic color analysis
    final dominantColors = _analyzeDominantColors(image);
    if (dominantColors.contains('green')) {
      labels.add('nature');
    }
    if (dominantColors.contains('blue')) {
      labels.add('sky');
    }

    return labels.isNotEmpty ? labels : null;
  }

  /// Analyze dominant colors in the image (simplified)
  List<String> _analyzeDominantColors(img.Image image) {
    final colors = <String>[];
    
    // Sample pixels to analyze color distribution
    int greenCount = 0;
    int blueCount = 0;
    int redCount = 0;
    
    const sampleSize = 100;
    final stepX = image.width ~/ 10;
    final stepY = image.height ~/ 10;
    
    for (int y = 0; y < image.height; y += stepY) {
      for (int x = 0; x < image.width; x += stepX) {
        if (x < image.width && y < image.height) {
          final pixel = image.getPixel(x, y);
          final r = img.getRed(pixel);
          final g = img.getGreen(pixel);
          final b = img.getBlue(pixel);
          
          if (g > r && g > b && g > 100) greenCount++;
          if (b > r && b > g && b > 100) blueCount++;
          if (r > g && r > b && r > 100) redCount++;
        }
      }
    }
    
    const threshold = 5;
    if (greenCount > threshold) colors.add('green');
    if (blueCount > threshold) colors.add('blue');
    if (redCount > threshold) colors.add('red');
    
    return colors;
  }

  @override
  Future<void> dispose() async {
    await _textRecognizer.close();
    await _faceDetector.close();
  }
}

/// Stub implementation for testing/fallback
class StubVisionAnalysisService implements VisionAnalysisService {
  @override
  Future<ImageAnalysisResult> analyzeImage(Uint8List imageBytes) async {
    // Decode image for basic info
    final decodedImage = img.decodeImage(imageBytes);
    if (decodedImage == null) {
      throw VisionAnalysisException('Failed to decode image');
    }

    // Return minimal analysis result
    return ImageAnalysisResult(
      width: decodedImage.width,
      height: decodedImage.height,
      mimeType: 'image/jpeg',
      faces: null,
      ocr: null,
      labels: ['unknown'],
      exif: ExifData(takenAt: DateTime.now()),
    );
  }

  @override
  Future<void> dispose() async {
    // Nothing to dispose in stub
  }
}

/// Exception thrown during vision analysis
class VisionAnalysisException implements Exception {
  final String message;
  const VisionAnalysisException(this.message);
  
  @override
  String toString() => 'VisionAnalysisException: $message';
}