// Copyright 2025 EPI Team
// SPDX-License-Identifier: MIT

// Pigeon bridge definition for LUMARA native LLM interface
// This file generates type-safe Dart, Swift, and Kotlin code
//
// Generate code with:
// flutter pub run pigeon --input tool/bridge.dart

import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(PigeonOptions(
  dartOut: 'lib/lumara/llm/bridge.pigeon.dart',
  dartOptions: DartOptions(),
  swiftOut: 'ios/Runner/Bridge.pigeon.swift',
  swiftOptions: SwiftOptions(),
  kotlinOut: 'android/app/src/main/kotlin/com/example/my_app/Bridge.pigeon.kt',
  kotlinOptions: KotlinOptions(),
))

/// Self-test result from native side
class SelfTestResult {
  final bool ok;
  final String message;
  final String platform;
  final String version;

  SelfTestResult({
    required this.ok,
    required this.message,
    required this.platform,
    required this.version,
  });
}

/// Model metadata returned by availableModels
class ModelInfo {
  final String id;
  final String name;
  final String format; // "mlx", "gguf"
  final String path;
  final int? sizeBytes;
  final String? checksum;

  ModelInfo({
    required this.id,
    required this.name,
    required this.format,
    required this.path,
    this.sizeBytes,
    this.checksum,
  });
}

/// Registry response containing installed models and active model
class ModelRegistry {
  final List<ModelInfo?> installed;
  final String? active;

  ModelRegistry({
    required this.installed,
    this.active,
  });
}

/// Model status response
class ModelStatus {
  final String folder;
  final bool loaded;
  final List<String?> missing;
  final String format; // "mlx", "gguf"

  ModelStatus({
    required this.folder,
    required this.loaded,
    required this.missing,
    required this.format,
  });
}

/// Generation parameters
class GenParams {
  final int maxTokens;
  final double temperature;
  final double topP;
  final double repeatPenalty;
  final int seed;

  GenParams({
    required this.maxTokens,
    required this.temperature,
    this.topP = 0.9,
    this.repeatPenalty = 1.1,
    this.seed = 101,
  });
}

/// Generation result with diagnostics
class GenResult {
  final String text;
  final int tokensIn;
  final int tokensOut;
  final int latencyMs;
  final String provider; // "mlx", "gguf", "cloud", "rule"

  GenResult({
    required this.text,
    required this.tokensIn,
    required this.tokensOut,
    required this.latencyMs,
    required this.provider,
  });
}

/// Native LLM interface - implemented on iOS (Swift) and Android (Kotlin)
@HostApi()
abstract class LumaraNative {
  /// Self-test: verify native bridge is working
  SelfTestResult selfTest();

  /// List all installed models (reads registry)
  ModelRegistry availableModels();

  /// Initialize a specific model (loads into memory)
  /// Returns true if successful, throws PlatformException on error
  bool initModel(String modelId);

  /// Get detailed status of a specific model
  ModelStatus getModelStatus(String modelId);

  /// Stop the currently running model (frees memory)
  void stopModel();

  /// Generate text with the active model
  /// Throws PlatformException if no model is loaded or generation fails
  GenResult generateText(String prompt, GenParams params);

  /// Get model root path (Application Support/Models)
  String getModelRootPath();

  /// Get absolute path for a specific model
  String getActiveModelPath(String modelId);

  /// Set active model in registry (doesn't load it)
  void setActiveModel(String modelId);

  /// Download model from URL (e.g., Google Drive)
  /// Returns true if download started successfully
  bool downloadModel(String modelId, String downloadUrl);

  /// Check if model is already downloaded
  bool isModelDownloaded(String modelId);

  /// Cancel ongoing model download
  void cancelModelDownload();

  /// Delete a downloaded model
  void deleteModel(String modelId);

  /// Clear all corrupted downloads and GGUF models
  void clearCorruptedDownloads();

  /// Clear specific corrupted GGUF model
  void clearCorruptedGGUFModel(String modelId);

  // --- Future streaming support ---
  // Stream<String> generateTextStream(String prompt, GenParams params);
}

/// Progress callback from native to Flutter
/// Used to report model loading and download progress
@FlutterApi()
abstract class LumaraNativeProgress {
  /// Report model loading progress
  /// - modelId: ID of the model being loaded
  /// - value: Progress percentage (0-100)
  /// - message: Optional status message
  void modelProgress(String modelId, int value, String? message);

  /// Report model download progress
  /// - modelId: ID of the model being downloaded
  /// - progress: Download progress (0.0-1.0)
  /// - message: Status message (e.g., "Downloading: 50.2 / 900 MB")
  void downloadProgress(String modelId, double progress, String message);
}

/// Vision API result for OCR text extraction
class VisionOcrResult {
  final String text;
  final double confidence;
  final List<VisionTextBlock> blocks;

  VisionOcrResult({
    required this.text,
    required this.confidence,
    required this.blocks,
  });
}

/// Vision API text block for OCR results
class VisionTextBlock {
  final String text;
  final double confidence;
  final VisionRect boundingBox;

  VisionTextBlock({
    required this.text,
    required this.confidence,
    required this.boundingBox,
  });
}

/// Vision API rectangle for bounding boxes
class VisionRect {
  final double x;
  final double y;
  final double width;
  final double height;

  VisionRect({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });
}

/// Vision API result for object detection
class VisionObjectResult {
  final List<VisionDetectedObject> objects;

  VisionObjectResult({
    required this.objects,
  });
}

/// Vision API detected object
class VisionDetectedObject {
  final String label;
  final double confidence;
  final VisionRect boundingBox;

  VisionDetectedObject({
    required this.label,
    required this.confidence,
    required this.boundingBox,
  });
}

/// Vision API result for face detection
class VisionFaceResult {
  final List<VisionDetectedFace> faces;

  VisionFaceResult({
    required this.faces,
  });
}

/// Vision API detected face
class VisionDetectedFace {
  final double confidence;
  final VisionRect boundingBox;

  VisionDetectedFace({
    required this.confidence,
    required this.boundingBox,
  });
}

/// Vision API result for image classification
class VisionClassificationResult {
  final List<VisionClassification> classifications;

  VisionClassificationResult({
    required this.classifications,
  });
}

/// Vision API image classification
class VisionClassification {
  final String identifier;
  final double confidence;

  VisionClassification({
    required this.identifier,
    required this.confidence,
  });
}

/// Native Vision API interface - implemented on iOS (Swift) and Android (Kotlin)
@HostApi()
abstract class VisionApi {
  /// Extract text from image using iOS Vision framework
  VisionOcrResult extractText(String imagePath);

  /// Detect objects in image using iOS Vision framework
  VisionObjectResult detectObjects(String imagePath);

  /// Detect faces in image using iOS Vision framework
  VisionFaceResult detectFaces(String imagePath);

  /// Classify image using iOS Vision framework
  VisionClassificationResult classifyImage(String imagePath);
}
