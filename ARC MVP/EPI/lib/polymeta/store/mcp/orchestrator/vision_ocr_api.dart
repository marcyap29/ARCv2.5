import 'package:pigeon/pigeon.dart';

/// Pigeon API for comprehensive iOS Vision framework
@HostApi()
abstract class VisionApi {
  /// Extract text from image using iOS Vision framework
  VisionOcrResult extractText(String imagePath);
  
  /// Detect objects in image using iOS Vision framework
  VisionObjectResult detectObjects(String imagePath);
  
  /// Detect faces in image using iOS Vision framework
  VisionFaceResult detectFaces(String imagePath);
  
  /// Classify image content using iOS Vision framework
  VisionClassificationResult classifyImage(String imagePath);
}

/// Result from Vision OCR
class VisionOcrResult {
  const VisionOcrResult({
    required this.success,
    required this.text,
    required this.confidence,
    this.error,
  });

  final bool success;
  final String text;
  final double confidence;
  final String? error;
}

/// Result from Vision Object Detection
class VisionObjectResult {
  const VisionObjectResult({
    required this.success,
    required this.objects,
    this.error,
  });

  final bool success;
  final List<VisionObject> objects;
  final String? error;
}

/// Detected object
class VisionObject {
  const VisionObject({
    required this.label,
    required this.confidence,
    required this.boundingBox,
  });

  final String label;
  final double confidence;
  final VisionRect boundingBox;
}

/// Result from Vision Face Detection
class VisionFaceResult {
  const VisionFaceResult({
    required this.success,
    required this.faces,
    this.error,
  });

  final bool success;
  final List<VisionFace> faces;
  final String? error;
}

/// Detected face
class VisionFace {
  const VisionFace({
    required this.boundingBox,
    required this.landmarks,
    required this.contours,
    required this.headEulerAngleY,
    required this.headEulerAngleZ,
    required this.smilingProbability,
    required this.leftEyeOpenProbability,
    required this.rightEyeOpenProbability,
  });

  final VisionRect boundingBox;
  final List<VisionLandmark> landmarks;
  final List<VisionContour> contours;
  final double headEulerAngleY;
  final double headEulerAngleZ;
  final double smilingProbability;
  final double leftEyeOpenProbability;
  final double rightEyeOpenProbability;
}

/// Result from Vision Image Classification
class VisionClassificationResult {
  const VisionClassificationResult({
    required this.success,
    required this.labels,
    this.error,
  });

  final bool success;
  final List<VisionLabel> labels;
  final String? error;
}

/// Classification label
class VisionLabel {
  const VisionLabel({
    required this.label,
    required this.confidence,
  });

  final String label;
  final double confidence;
}

/// Rectangle for bounding boxes
class VisionRect {
  const VisionRect({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  final double x;
  final double y;
  final double width;
  final double height;
}

/// Landmark point
class VisionLandmark {
  const VisionLandmark({
    required this.type,
    required this.x,
    required this.y,
  });

  final String type;
  final double x;
  final double y;
}

/// Contour points
class VisionContour {
  const VisionContour({
    required this.type,
    required this.points,
  });

  final String type;
  final List<VisionPoint> points;
}

/// Point coordinates
class VisionPoint {
  const VisionPoint({
    required this.x,
    required this.y,
  });

  final double x;
  final double y;
}
