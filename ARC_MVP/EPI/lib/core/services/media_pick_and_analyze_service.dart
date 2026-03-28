/// Shared LUMARA image flow: robust gallery/camera picking + on-device Vision analysis.
///
/// Used by **reflections (journal)**, **LUMARA chat** attachments, and **research**
/// document scan (pick-only with resize). One [ImagePicker] instance avoids divergent
/// behavior; [IOSVisionOrchestrator] + [MediaAltTextGenerator] stay in one place.
library;

import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:my_app/core/services/photo_library_service.dart';
import 'package:my_app/core/services/robust_gallery_picker.dart';
import 'package:my_app/mira/store/mcp/orchestrator/ios_vision_orchestrator.dart';
import 'package:my_app/services/media_alt_text_generator.dart';
import 'package:my_app/state/journal_entry_state.dart';

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

  /// Journal entry attachment — same Vision payload chat uses, shared mapping.
  PhotoAttachment toPhotoAttachment() {
    DateTime? capturedAt;
    final capturedAtStr = analysisResult['capturedAt'] as String?;
    if (capturedAtStr != null && capturedAtStr.isNotEmpty) {
      capturedAt = DateTime.tryParse(capturedAtStr);
    }
    return PhotoAttachment(
      type: 'photo_analysis',
      imagePath: imagePath,
      analysisResult: analysisResult,
      timestamp: capturedAt?.millisecondsSinceEpoch ??
          DateTime.now().millisecondsSinceEpoch,
      altText: altText,
      photoId: 'photo_${DateTime.now().microsecondsSinceEpoch}',
      sha256: null,
    );
  }
}

class MediaPickAndAnalyzeService {
  static final MediaPickAndAnalyzeService _instance =
      MediaPickAndAnalyzeService._internal();
  factory MediaPickAndAnalyzeService() => _instance;
  MediaPickAndAnalyzeService._internal();

  final ImagePicker _picker = ImagePicker();
  final IOSVisionOrchestrator _orchestrator = IOSVisionOrchestrator();

  // --- Shared picking (caller may request [PhotoLibraryService] first; journal/chat do) ---

  /// Multi-select from gallery (robust iOS metadata handling).
  Future<List<XFile>> pickMultiPhotosFromGallery() =>
      RobustGalleryPicker.pickMulti(_picker);

  Future<XFile?> pickCameraPhoto() => RobustGalleryPicker.pickCamera(_picker);

  Future<XFile?> pickVideoFromGallery() =>
      _picker.pickVideo(source: ImageSource.gallery);

  /// Gallery or camera with optional downscale; requests photo library access first.
  /// For flows that run their own processing (e.g. research [parseDocument]).
  Future<XFile?> pickSourceImageWithPermission({
    required ImageSource source,
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
  }) async {
    final ok = await PhotoLibraryService.requestPermissions();
    if (!ok) return null;
    if (source == ImageSource.gallery) {
      return RobustGalleryPicker.pickSingleGallery(
        _picker,
        maxWidth: maxWidth,
        maxHeight: maxHeight,
        imageQuality: imageQuality,
      );
    }
    return RobustGalleryPicker.pickCamera(
      _picker,
      maxWidth: maxWidth,
      maxHeight: maxHeight,
      imageQuality: imageQuality,
    );
  }

  /// Pick image from gallery, analyze, and return result with keywords.
  /// Returns null if user cancels or analysis fails.
  Future<AnalyzedMedia?> pickFromGallery() async {
    final hasPermissions = await PhotoLibraryService.requestPermissions();
    if (!hasPermissions) return null;

    final images = await RobustGalleryPicker.pickMulti(_picker);
    if (images.isEmpty) return null;
    return _analyzeImage(images.first.path);
  }

  /// Pick single image from gallery
  Future<AnalyzedMedia?> pickSingleFromGallery() async {
    final hasPermissions = await PhotoLibraryService.requestPermissions();
    if (!hasPermissions) return null;

    final image = await RobustGalleryPicker.pickSingleGallery(_picker);
    if (image == null) return null;
    return _analyzeImage(image.path);
  }

  /// Capture from camera, analyze, and return result
  Future<AnalyzedMedia?> captureFromCamera() async {
    final image = await RobustGalleryPicker.pickCamera(_picker);
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
