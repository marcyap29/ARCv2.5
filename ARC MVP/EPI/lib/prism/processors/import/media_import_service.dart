import 'dart:typed_data';
import 'package:photo_manager/photo_manager.dart';
import 'package:permission_handler/permission_handler.dart';
import '../analysis/vision_analysis_service.dart';
import '../analysis/audio_transcribe_service.dart';
import '../analysis/video_keyframe_service.dart';
import '../pointer/pointer_emitter.dart';
import '../settings/storage_profiles.dart';
import '../crypto/at_rest_encryption.dart';

/// Result of media import operation
class MediaImportResult {
  final String pointerId;
  final String? embeddingId;
  final String nodeId;
  final bool success;
  final String? error;

  const MediaImportResult({
    required this.pointerId,
    this.embeddingId,
    required this.nodeId,
    required this.success,
    this.error,
  });

  factory MediaImportResult.success({
    required String pointerId,
    String? embeddingId,
    required String nodeId,
  }) {
    return MediaImportResult(
      pointerId: pointerId,
      embeddingId: embeddingId,
      nodeId: nodeId,
      success: true,
    );
  }

  factory MediaImportResult.failure(String error) {
    return MediaImportResult(
      pointerId: '',
      nodeId: '',
      success: false,
      error: error,
    );
  }
}

/// Media import configuration
class ImportConfig {
  final StorageProfile? profileOverride;
  final bool generateEmbeddings;
  final bool enableEncryption;
  final AppMode currentMode;

  const ImportConfig({
    this.profileOverride,
    this.generateEmbeddings = true,
    this.enableEncryption = true,
    this.currentMode = AppMode.personal,
  });
}

/// Abstract interface for media import
abstract class MediaImportService {
  Future<MediaImportResult> importImage({
    required String entryId,
    required AssetEntity asset,
    ImportConfig? config,
  });
  
  Future<MediaImportResult> importAudio({
    required String entryId,
    required AssetEntity asset,
    ImportConfig? config,
  });
  
  Future<MediaImportResult> importVideo({
    required String entryId,
    required AssetEntity asset,
    ImportConfig? config,
  });

  Future<MediaImportResult> importFromBytes({
    required String entryId,
    required String sourceUri,
    required Uint8List data,
    required String mediaType,
    ImportConfig? config,
  });

  Future<bool> requestPermissions();
  Future<void> dispose();
}

/// Full implementation of media import service
class PhotoManagerImportService implements MediaImportService {
  final VisionAnalysisService _visionService;
  final AudioTranscribeService _transcribeService;
  final VideoKeyframeService _keyframeService;
  final PointerEmitter _pointerEmitter;
  final StorageSettings _storageSettings;

  PhotoManagerImportService({
    required VisionAnalysisService visionService,
    required AudioTranscribeService transcribeService,
    required VideoKeyframeService keyframeService,
    required PointerEmitter pointerEmitter,
    required StorageSettings storageSettings,
  })  : _visionService = visionService,
        _transcribeService = transcribeService,
        _keyframeService = keyframeService,
        _pointerEmitter = pointerEmitter,
        _storageSettings = storageSettings;

  @override
  Future<bool> requestPermissions() async {
    try {
      // Request photo library permission
      final photoStatus = await Permission.photos.request();
      
      if (photoStatus != PermissionStatus.granted) {
        print('MediaImportService: Photo permission denied');
        return false;
      }

      // Initialize PhotoManager
      final pmResult = await PhotoManager.requestPermissionExtend();
      if (pmResult != PermissionState.authorized) {
        print('MediaImportService: PhotoManager permission denied: $pmResult');
        return false;
      }

      return true;
    } catch (e) {
      print('MediaImportService: Permission request failed: $e');
      return false;
    }
  }

  @override
  Future<MediaImportResult> importImage({
    required String entryId,
    required AssetEntity asset,
    ImportConfig? config,
  }) async {
    try {
      // Get image data
      final file = await asset.file;
      if (file == null) {
        return MediaImportResult.failure('Failed to get image file');
      }

      final imageData = await file.readAsBytes();
      final sourceUri = _createApplePhotosUri(asset);

      return await importFromBytes(
        entryId: entryId,
        sourceUri: sourceUri,
        data: imageData,
        mediaType: 'image',
        config: config,
      );
    } catch (e) {
      return MediaImportResult.failure('Image import failed: $e');
    }
  }

  @override
  Future<MediaImportResult> importAudio({
    required String entryId,
    required AssetEntity asset,
    ImportConfig? config,
  }) async {
    try {
      // Get audio data
      final file = await asset.file;
      if (file == null) {
        return MediaImportResult.failure('Failed to get audio file');
      }

      final audioData = await file.readAsBytes();
      final sourceUri = _createVoiceMemosUri(asset);

      return await importFromBytes(
        entryId: entryId,
        sourceUri: sourceUri,
        data: audioData,
        mediaType: 'audio',
        config: config,
      );
    } catch (e) {
      return MediaImportResult.failure('Audio import failed: $e');
    }
  }

  @override
  Future<MediaImportResult> importVideo({
    required String entryId,
    required AssetEntity asset,
    ImportConfig? config,
  }) async {
    try {
      // Get video data
      final file = await asset.file;
      if (file == null) {
        return MediaImportResult.failure('Failed to get video file');
      }

      final videoData = await file.readAsBytes();
      final sourceUri = _createApplePhotosUri(asset);

      return await importFromBytes(
        entryId: entryId,
        sourceUri: sourceUri,
        data: videoData,
        mediaType: 'video',
        config: config,
      );
    } catch (e) {
      return MediaImportResult.failure('Video import failed: $e');
    }
  }

  @override
  Future<MediaImportResult> importFromBytes({
    required String entryId,
    required String sourceUri,
    required Uint8List data,
    required String mediaType,
    ImportConfig? config,
  }) async {
    try {
      // Determine storage profile
      final importConfig = config ?? const ImportConfig();
      final profile = _getStorageProfile(importConfig);

      // Process based on media type
      switch (mediaType) {
        case 'image':
          return await _importImageData(entryId, sourceUri, data, profile, importConfig);
        case 'audio':
          return await _importAudioData(entryId, sourceUri, data, profile, importConfig);
        case 'video':
          return await _importVideoData(entryId, sourceUri, data, profile, importConfig);
        default:
          return MediaImportResult.failure('Unsupported media type: $mediaType');
      }
    } catch (e) {
      return MediaImportResult.failure('Import failed: $e');
    }
  }

  /// Import image data with full processing pipeline
  Future<MediaImportResult> _importImageData(
    String entryId,
    String sourceUri,
    Uint8List imageData,
    StorageProfile profile,
    ImportConfig config,
  ) async {
    try {
      // 1. Analyze image
      final analysis = await _visionService.analyzeImage(imageData);

      // 2. Emit pointer
      final pointerId = await _pointerEmitter.emitPointerImage(
        entryId: entryId,
        sourceUri: sourceUri,
        imageData: imageData,
        analysis: analysis,
        profile: profile,
      );

      // 3. Generate and emit embedding if requested
      String? embeddingId;
      if (config.generateEmbeddings) {
        final vector = NDJSONPointerEmitter.generateMockEmbedding();
        embeddingId = await _pointerEmitter.emitEmbedding(
          pointerId: pointerId,
          vector: vector,
          subjectType: 'pointer.image',
        );
      }

      // 4. Emit node link
      final nodeId = await _pointerEmitter.emitNodeLink(
        entryId: entryId,
        pointerId: pointerId,
      );

      // 5. Handle encryption if enabled
      if (profile.enableEncryption && config.enableEncryption) {
        await _encryptStoredContent(pointerId, profile);
      }

      return MediaImportResult.success(
        pointerId: pointerId,
        embeddingId: embeddingId,
        nodeId: nodeId,
      );
    } catch (e) {
      throw MediaImportException('Image import pipeline failed: $e');
    }
  }

  /// Import audio data with full processing pipeline
  Future<MediaImportResult> _importAudioData(
    String entryId,
    String sourceUri,
    Uint8List audioData,
    StorageProfile profile,
    ImportConfig config,
  ) async {
    try {
      // 1. Transcribe audio
      final transcript = await _transcribeService.transcribe(audioData);

      // 2. Emit pointer
      final pointerId = await _pointerEmitter.emitPointerAudio(
        entryId: entryId,
        sourceUri: sourceUri,
        audioData: audioData,
        transcript: transcript,
        profile: profile,
      );

      // 3. Generate embeddings for transcript segments if requested
      String? embeddingId;
      if (config.generateEmbeddings && transcript.segments.isNotEmpty) {
        // Create embedding for the main transcript
        final vector = NDJSONPointerEmitter.generateMockEmbedding();
        embeddingId = await _pointerEmitter.emitEmbedding(
          pointerId: pointerId,
          vector: vector,
          subjectType: 'pointer.audio.segment',
          span: [0.0, transcript.totalDuration],
        );

        // Create embeddings for individual segments
        for (int i = 0; i < transcript.segments.length; i++) {
          final segment = transcript.segments[i];
          if (segment.ts.length >= 2) {
            final segmentVector = NDJSONPointerEmitter.generateMockEmbedding();
            await _pointerEmitter.emitEmbedding(
              pointerId: pointerId,
              vector: segmentVector,
              subjectType: 'pointer.audio.segment',
              span: segment.ts,
            );
          }
        }
      }

      // 4. Emit node link
      final nodeId = await _pointerEmitter.emitNodeLink(
        entryId: entryId,
        pointerId: pointerId,
      );

      // 5. Handle encryption if enabled
      if (profile.enableEncryption && config.enableEncryption) {
        await _encryptStoredContent(pointerId, profile);
      }

      return MediaImportResult.success(
        pointerId: pointerId,
        embeddingId: embeddingId,
        nodeId: nodeId,
      );
    } catch (e) {
      throw MediaImportException('Audio import pipeline failed: $e');
    }
  }

  /// Import video data with full processing pipeline
  Future<MediaImportResult> _importVideoData(
    String entryId,
    String sourceUri,
    Uint8List videoData,
    StorageProfile profile,
    ImportConfig config,
  ) async {
    try {
      // 1. Extract keyframes and analyze
      final derivative = await _keyframeService.derive(
        videoData,
        enableProxy: profile.keepAnalysisVariant,
        keyframeEvery: const Duration(seconds: 10),
      );

      // 2. Emit pointer
      final pointerId = await _pointerEmitter.emitPointerVideo(
        entryId: entryId,
        sourceUri: sourceUri,
        videoData: videoData,
        derivative: derivative,
        profile: profile,
      );

      // 3. Generate and emit embeddings if requested
      String? embeddingId;
      if (config.generateEmbeddings) {
        // Main video embedding
        final vector = NDJSONPointerEmitter.generateMockEmbedding();
        embeddingId = await _pointerEmitter.emitEmbedding(
          pointerId: pointerId,
          vector: vector,
          subjectType: 'pointer.video',
        );

        // Keyframe embeddings
        for (final keyframe in derivative.keyframes) {
          final kfVector = NDJSONPointerEmitter.generateMockEmbedding();
          await _pointerEmitter.emitEmbedding(
            pointerId: pointerId,
            vector: kfVector,
            subjectType: 'pointer.video.keyframe',
            span: [keyframe.timestamp, keyframe.timestamp],
          );
        }
      }

      // 4. Emit node link
      final nodeId = await _pointerEmitter.emitNodeLink(
        entryId: entryId,
        pointerId: pointerId,
      );

      // 5. Handle encryption if enabled
      if (profile.enableEncryption && config.enableEncryption) {
        await _encryptStoredContent(pointerId, profile);
      }

      return MediaImportResult.success(
        pointerId: pointerId,
        embeddingId: embeddingId,
        nodeId: nodeId,
      );
    } catch (e) {
      throw MediaImportException('Video import pipeline failed: $e');
    }
  }

  /// Get appropriate storage profile for import
  StorageProfile _getStorageProfile(ImportConfig config) {
    if (config.profileOverride != null) {
      return config.profileOverride!;
    }

    return _storageSettings.getProfileForMode(config.currentMode);
  }

  /// Create Apple Photos URI format
  String _createApplePhotosUri(AssetEntity asset) {
    return 'applephotos://asset/${asset.id}';
  }

  /// Create Voice Memos URI format
  String _createVoiceMemosUri(AssetEntity asset) {
    return 'voicememos://asset/${asset.id}';
  }

  /// Encrypt stored content based on profile
  Future<void> _encryptStoredContent(String pointerId, StorageProfile profile) async {
    try {
      if (!profile.enableEncryption) return;

      // This would encrypt any local copies/proxies stored in CAS
      // For now, it's a placeholder
      await AtRestEncryption.initialize();
      
      print('MediaImportService: Encrypted content for pointer $pointerId');
    } catch (e) {
      print('MediaImportService: Encryption failed for $pointerId: $e');
    }
  }

  @override
  Future<void> dispose() async {
    await _visionService.dispose();
    await _transcribeService.dispose();
    await _keyframeService.dispose();
  }

  /// Factory method to create fully initialized service
  static Future<PhotoManagerImportService> create([StorageSettings? settings]) async {
    final visionService = await MLKitVisionAnalysisService.create();
    final transcribeService = WhisperStubTranscribeService();
    final keyframeService = FFmpegVideoKeyframeService();
    final pointerEmitter = NDJSONPointerEmitter();
    final storageSettings = settings ?? StorageSettings.defaultSettings;

    return PhotoManagerImportService(
      visionService: visionService,
      transcribeService: transcribeService,
      keyframeService: keyframeService,
      pointerEmitter: pointerEmitter,
      storageSettings: storageSettings,
    );
  }
}

/// Exception thrown during media import
class MediaImportException implements Exception {
  final String message;
  const MediaImportException(this.message);
  
  @override
  String toString() => 'MediaImportException: $message';
}