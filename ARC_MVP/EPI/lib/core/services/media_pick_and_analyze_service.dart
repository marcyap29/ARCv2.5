/// Shared media pick and analyze service
///
/// Reuses the same architecture as reflections/journal:
/// - ImagePicker for gallery/camera
/// - IOSVisionOrchestrator for analysis (OCR, objects, faces, labels)
/// - MediaAltTextGenerator for keyword extraction
///
/// Used by both journal/reflections and chat to minimize duplication.
library;

import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:my_app/core/services/photo_library_service.dart';
import 'package:my_app/mira/store/mcp/orchestrator/ios_vision_orchestrator.dart';
import 'package:my_app/services/media_alt_text_generator.dart';

/// Result of picking and analyzing an image
class AnalyzedMedia {
  final String imagePath;
  final Map<String, dynamic> analysisResult;
  final String altText;
  final String keywords;

  const AnalyzedMedia({
    required this.imagePath,
    required this.analysisResult,
    required this.altText,
    required this.keywords,
  });
}

class MediaPickAndAnalyzeService {
  static final MediaPickAndAnalyzeService _instance =
      MediaPickAndAnalyzeService._internal();
  factory MediaPickAndAnalyzeService() => _instance;
  MediaPickAndAnalyzeService._internal();

  final ImagePicker _picker = ImagePicker();
  final IOSVisionOrchestrator _orchestrator = IOSVisionOrchestrator();

  /// Pick image from gallery, analyze, and return result with keywords.
  /// Returns null if user cancels or analysis fails.
  Future<AnalyzedMedia?> pickFromGallery() async {
    final hasPermissions = await PhotoLibraryService.requestPermissions();
    if (!hasPermissions) return null;

    final images = await _picker.pickMultiImage();
    if (images.isEmpty) return null;
    return _analyzeImage(images.first.path);
  }

  /// Pick single image from gallery
  Future<AnalyzedMedia?> pickSingleFromGallery() async {
    final hasPermissions = await PhotoLibraryService.requestPermissions();
    if (!hasPermissions) return null;

    final image = await _picker.pickImage(source: ImageSource.gallery);
    if (image == null) return null;
    return _analyzeImage(image.path);
  }

  /// Capture from camera, analyze, and return result
  Future<AnalyzedMedia?> captureFromCamera() async {
    final image = await _picker.pickImage(source: ImageSource.camera);
    if (image == null) return null;
    return _analyzeImage(image.path);
  }

  /// Analyze an existing image file (used by journal and chat)
  Future<AnalyzedMedia?> analyzeImagePath(String imagePath) async {
    return _analyzeImage(imagePath);
  }

  Future<AnalyzedMedia?> _analyzeImage(String imagePath) async {
    final file = File(imagePath);
    if (!await file.exists()) return null;

    try {
      final result = await _orchestrator.processPhoto(
        imagePath: imagePath,
        ocrEngine: 'ios_vision',
        language: 'auto',
        maxProcessingMs: 1500,
      );

      if (result['success'] != true) return null;

      DateTime? capturedAt;
      final capturedAtStr = result['capturedAt'] as String?;
      if (capturedAtStr != null && capturedAtStr.isNotEmpty) {
        capturedAt = DateTime.tryParse(capturedAtStr);
      }
      final location = result['location'] as String?;

      final altText = MediaAltTextGenerator.generateAltText(
        result,
        capturedAt: capturedAt,
        location: location,
      );

      final concise = MediaAltTextGenerator.generateConcise(
        result,
        capturedAt: capturedAt,
        location: location,
      );
      final keywords = concise ?? altText;

      return AnalyzedMedia(
        imagePath: imagePath,
        analysisResult: result,
        altText: altText,
        keywords: keywords,
      );
    } catch (e) {
      return null;
    }
  }
}
