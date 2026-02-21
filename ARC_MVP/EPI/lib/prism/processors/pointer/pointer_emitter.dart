import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:uuid/uuid.dart';
import 'package:device_info_plus/device_info_plus.dart';
import '../analysis/vision_analysis_service.dart';
import '../analysis/audio_transcribe_service.dart';
import '../analysis/video_keyframe_service.dart';
import '../crypto/hash_utils.dart';
import '../settings/storage_profiles.dart';
import 'pointer_models.dart';

/// Abstract interface for emitting MCP-compliant pointers
abstract class PointerEmitter {
  Future<String> emitPointerImage({
    required String entryId,
    required String sourceUri,
    required Uint8List imageData,
    required ImageAnalysisResult analysis,
    required StorageProfile profile,
  });
  
  Future<String> emitPointerAudio({
    required String entryId,
    required String sourceUri,
    required Uint8List audioData,
    required AudioTranscript transcript,
    required StorageProfile profile,
  });
  
  Future<String> emitPointerVideo({
    required String entryId,
    required String sourceUri,
    required Uint8List videoData,
    required VideoDerivative derivative,
    required StorageProfile profile,
  });
  
  Future<String> emitEmbedding({
    required String pointerId,
    required List<double> vector,
    required String subjectType,
    List<double>? span,
  });
  
  Future<String> emitNodeLink({
    required String entryId,
    required String pointerId,
  });
}

/// NDJSON-based MCP pointer emitter
class NDJSONPointerEmitter implements PointerEmitter {
  static const String _outboxDirectoryName = 'mcp_outbox';
  static const String _outboxFileName = 'pointers.ndjson';
  
  final Uuid _uuid = const Uuid();
  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();

  /// Get the MCP outbox directory
  Future<Directory> get _outboxDirectory async {
    final appDir = await getApplicationSupportDirectory();
    final outboxDir = Directory(path.join(appDir.path, _outboxDirectoryName));
    
    if (!await outboxDir.exists()) {
      await outboxDir.create(recursive: true);
    }
    
    return outboxDir;
  }

  /// Get the outbox file for writing NDJSON lines
  Future<File> get _outboxFile async {
    final outboxDir = await _outboxDirectory;
    return File(path.join(outboxDir.path, _outboxFileName));
  }

  @override
  Future<String> emitPointerImage({
    required String entryId,
    required String sourceUri,
    required Uint8List imageData,
    required ImageAnalysisResult analysis,
    required StorageProfile profile,
  }) async {
    try {
      final pointerId = HashUtils.generatePointerId();
      final hash = HashUtils.sha256Hash(imageData);
      final now = DateTime.now();

      // Create sampling manifest based on storage profile
      final samplingManifest = await _createImageSamplingManifest(
        imageData,
        analysis,
        profile,
        hash,
      );

      // Create integrity data
      final integrity = IntegrityData(
        sha256: hash,
        bytes: imageData.length,
        createdAt: now,
      );

      // Create privacy data
      final privacy = PrivacyData(
        containsFaces: analysis.faces != null && analysis.faces!.count > 0,
        locationPrecision: analysis.exif?.gps != null ? 'city' : null,
      );

      // Create provenance data
      final provenance = await _createProvenanceData();

      // Create image descriptor
      final descriptor = ImageDescriptor(
        width: analysis.width,
        height: analysis.height,
        mime: analysis.mimeType,
        exif: analysis.exif,
        faces: analysis.faces,
        ocr: analysis.ocr,
        labels: analysis.labels,
      );

      // Create pointer
      final pointer = ImagePointer(
        id: pointerId,
        type: 'pointer.image.v1',
        sourceUri: sourceUri,
        descriptor: descriptor,
        samplingManifest: samplingManifest,
        integrity: integrity,
        privacy: privacy,
        provenance: provenance,
      );

      // Emit to NDJSON
      await _writeNDJSONLine(pointer.toJson());
      
      return pointerId;
    } catch (e) {
      throw PointerEmissionException('Failed to emit image pointer: $e');
    }
  }

  @override
  Future<String> emitPointerAudio({
    required String entryId,
    required String sourceUri,
    required Uint8List audioData,
    required AudioTranscript transcript,
    required StorageProfile profile,
  }) async {
    try {
      final pointerId = HashUtils.generatePointerId();
      final hash = HashUtils.sha256Hash(audioData);
      final now = DateTime.now();

      // Create audio descriptor
      final descriptor = AudioDescriptor(
        durationSec: transcript.totalDuration,
        sampleRate: transcript.sampleRate,
        channels: transcript.channels,
        mime: 'audio/m4a', // Assume M4A format
      );

      // Create sampling manifest
      final samplingManifest = AudioSamplingManifest(
        vad: const VADWindow(windowSec: 30),
        transcript: transcript.segments,
      );

      // Create integrity data
      final integrity = IntegrityData(
        sha256: hash,
        bytes: audioData.length,
        createdAt: now,
      );

      // Create privacy data
      final privacy = PrivacyData(
        piiHint: transcript.hasPiiHint,
      );

      // Create provenance data
      final provenance = await _createProvenanceData(app: 'voicememos');

      // Create pointer
      final pointer = AudioPointer(
        id: pointerId,
        type: 'pointer.audio.v1',
        sourceUri: sourceUri,
        descriptor: descriptor,
        samplingManifest: samplingManifest,
        integrity: integrity,
        privacy: privacy,
        provenance: provenance,
      );

      // Emit to NDJSON
      await _writeNDJSONLine(pointer.toJson());
      
      return pointerId;
    } catch (e) {
      throw PointerEmissionException('Failed to emit audio pointer: $e');
    }
  }

  @override
  Future<String> emitPointerVideo({
    required String entryId,
    required String sourceUri,
    required Uint8List videoData,
    required VideoDerivative derivative,
    required StorageProfile profile,
  }) async {
    try {
      final pointerId = HashUtils.generatePointerId();
      final hash = HashUtils.sha256Hash(videoData);
      final now = DateTime.now();

      // Create video descriptor
      final descriptor = VideoDescriptor(
        durationSec: derivative.metadata.duration,
        width: derivative.metadata.width,
        height: derivative.metadata.height,
        fps: derivative.metadata.fps.round(),
        audio: derivative.metadata.audioChannels != null 
            ? AudioChannels(channels: derivative.metadata.audioChannels!)
            : null,
      );

      // Create keyframes for sampling manifest
      final keyframes = derivative.keyframes.map((kf) => Keyframe(
        t: kf.timestamp,
        thumbUri: kf.casUri,
      )).toList();

      // Create sampling manifest
      final samplingManifest = VideoSamplingManifest(
        keyframes: keyframes,
        captions: derivative.captions,
      );

      // Create integrity data
      final integrity = IntegrityData(
        sha256: hash,
        bytes: videoData.length,
        createdAt: now,
      );

      // Check for faces in keyframes (simplified)
      final containsFaces = derivative.keyframes.isNotEmpty; // Stub check

      // Create privacy data
      final privacy = PrivacyData(
        containsFaces: containsFaces,
      );

      // Create provenance data
      final provenance = await _createProvenanceData(app: 'photos');

      // Create pointer
      final pointer = VideoPointer(
        id: pointerId,
        type: 'pointer.video.v1',
        sourceUri: sourceUri,
        descriptor: descriptor,
        samplingManifest: samplingManifest,
        integrity: integrity,
        privacy: privacy,
        provenance: provenance,
      );

      // Emit to NDJSON
      await _writeNDJSONLine(pointer.toJson());
      
      return pointerId;
    } catch (e) {
      throw PointerEmissionException('Failed to emit video pointer: $e');
    }
  }

  @override
  Future<String> emitEmbedding({
    required String pointerId,
    required List<double> vector,
    required String subjectType,
    List<double>? span,
  }) async {
    try {
      final embeddingId = HashUtils.generateEmbeddingId();

      // Create embedding model info
      const model = EmbeddingModel(
        name: 'qwen3-embed-0.6b',
        dim: 768,
        version: 'v1',
      );

      // Create embedding subject
      final subject = EmbeddingSubject(
        type: subjectType,
        ref: pointerId,
        span: span,
      );

      // Create embedding
      final embedding = Embedding(
        id: embeddingId,
        type: 'embedding.v1',
        vector: vector,
        model: model,
        subject: subject,
      );

      // Emit to NDJSON
      await _writeNDJSONLine(embedding.toJson());
      
      return embeddingId;
    } catch (e) {
      throw PointerEmissionException('Failed to emit embedding: $e');
    }
  }

  @override
  Future<String> emitNodeLink({
    required String entryId,
    required String pointerId,
  }) async {
    try {
      final nodeId = HashUtils.generateNodeId();
      final now = DateTime.now();

      // Create node links
      final links = NodeLinks(
        entryId: entryId,
        pointerId: pointerId,
      );

      // Create node metadata
      final meta = NodeMeta(
        tags: ['journal', _getMediaTypeFromPointerId(pointerId)],
        createdAt: now,
      );

      // Create node
      final node = Node(
        id: nodeId,
        type: 'node.v1',
        role: 'media_link',
        links: links,
        meta: meta,
      );

      // Emit to NDJSON
      await _writeNDJSONLine(node.toJson());
      
      return nodeId;
    } catch (e) {
      throw PointerEmissionException('Failed to emit node link: $e');
    }
  }

  /// Create image sampling manifest based on storage profile
  Future<SamplingManifest> _createImageSamplingManifest(
    Uint8List imageData,
    ImageAnalysisResult analysis,
    StorageProfile profile,
    String hash,
  ) async {
    final thumbnails = <Thumbnail>[];

    // Always create 256px thumbnail
    if (profile.keepThumbnails) {
      final thumbnailData = await _createThumbnail(imageData, 256);
      final thumbnailUri = await CASStore.store('img', '256', thumbnailData);
      thumbnails.add(Thumbnail(size: 256, uri: thumbnailUri));
    }

    // Create 1024px variant if balanced or hi-fidelity
    if (profile.keepAnalysisVariant && 
        (profile.policy == StoragePolicy.balanced || profile.policy == StoragePolicy.hiFidelity)) {
      final analysisData = await _createThumbnail(imageData, 1024);
      final analysisUri = await CASStore.store('img', '1024', analysisData);
      thumbnails.add(Thumbnail(size: 1024, uri: analysisUri));
    }

    return SamplingManifest(
      policy: profile.policy.toString().split('.').last,
      thumbnails: thumbnails.isNotEmpty ? thumbnails : null,
    );
  }

  /// Create thumbnail of specified size (stub implementation)
  Future<Uint8List> _createThumbnail(Uint8List imageData, int size) async {
    // In reality, would use image processing library to resize
    // For now, return original data (stub)
    return imageData;
  }

  /// Create provenance data for current device/app
  Future<ProvenanceData> _createProvenanceData({String app = 'photos'}) async {
    String deviceId = 'unknown';
    
    try {
      if (Platform.isIOS) {
        final iosInfo = await _deviceInfo.iosInfo;
        deviceId = iosInfo.model;
      } else if (Platform.isAndroid) {
        final androidInfo = await _deviceInfo.androidInfo;
        deviceId = androidInfo.model;
      }
    } catch (e) {
      print('PointerEmitter: Failed to get device info: $e');
    }

    return ProvenanceData(
      device: deviceId,
      app: app,
    );
  }

  /// Write NDJSON line to outbox file
  Future<void> _writeNDJSONLine(Map<String, dynamic> data) async {
    final file = await _outboxFile;
    final jsonLine = '${jsonEncode(data)}\n';
    
    await file.writeAsString(
      jsonLine,
      mode: FileMode.append,
      encoding: utf8,
    );
    
    print('PointerEmitter: Emitted NDJSON line to ${file.path}');
  }

  /// Infer media type from pointer ID (simple heuristic)
  String _getMediaTypeFromPointerId(String pointerId) {
    // This is a simplistic approach - in reality you'd track this properly
    return 'media'; // Generic fallback
  }

  /// Clear the outbox (for testing or cleanup)
  Future<void> clearOutbox() async {
    try {
      final file = await _outboxFile;
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      print('PointerEmitter: Error clearing outbox: $e');
    }
  }

  /// Get outbox contents for inspection
  Future<List<Map<String, dynamic>>> readOutbox() async {
    try {
      final file = await _outboxFile;
      if (!await file.exists()) {
        return [];
      }

      final lines = await file.readAsLines(encoding: utf8);
      final entries = <Map<String, dynamic>>[];

      for (final line in lines) {
        if (line.trim().isNotEmpty) {
          try {
            final data = jsonDecode(line) as Map<String, dynamic>;
            entries.add(data);
          } catch (e) {
            print('PointerEmitter: Error parsing NDJSON line: $e');
          }
        }
      }

      return entries;
    } catch (e) {
      print('PointerEmitter: Error reading outbox: $e');
      return [];
    }
  }

  /// Generate mock embedding vector (stub)
  static List<double> generateMockEmbedding({int dimensions = 768}) {
    final vector = <double>[];
    final random = DateTime.now().millisecondsSinceEpoch;
    
    for (int i = 0; i < dimensions; i++) {
      // Simple pseudo-random generation based on index and timestamp
      final value = ((random + i) % 1000) / 500.0 - 1.0; // Range [-1, 1]
      vector.add(value);
    }
    
    return vector;
  }
}

/// Exception thrown during pointer emission
class PointerEmissionException implements Exception {
  final String message;
  const PointerEmissionException(this.message);
  
  @override
  String toString() => 'PointerEmissionException: $message';
}