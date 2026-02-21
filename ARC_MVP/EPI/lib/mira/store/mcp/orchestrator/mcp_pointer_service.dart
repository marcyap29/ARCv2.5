import 'dart:io';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:mime/mime.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import '../models/mcp_schemas.dart';

/// MCP Pointer management service for media references
class McpPointerService {
  static const _uuid = Uuid();

  /// Create a new MCP pointer for media content
  static Future<McpPointer> createPointer({
    required String uri,
    required String mediaType,
    required Map<String, dynamic> descriptor,
    required Map<String, dynamic> integrity,
    required Map<String, dynamic> privacy,
    Map<String, dynamic>? samplingManifest,
  }) async {
    try {
      // Generate unique pointer ID
      final pointerId = _uuid.v4();
      
      // Extract file information
      final file = File(uri);
      final fileExists = await file.exists();
      
      // Calculate integrity hash if file exists
      String? sha256Hash;
      if (fileExists) {
        final fileBytes = await file.readAsBytes();
        final hash = sha256.convert(fileBytes);
        sha256Hash = hash.toString();
      }
      
      // Determine MIME type
      final mimeType = lookupMimeType(uri) ?? _getDefaultMimeType(mediaType);
      
      // Get file size for descriptor
      int? fileSize;
      if (fileExists) {
        final stat = await file.stat();
        fileSize = stat.size;
      }
      
      // Prepare descriptor metadata with duration info if available
      final descriptorMetadata = Map<String, dynamic>.from(descriptor);
      if (descriptor['duration_s'] != null) {
        descriptorMetadata['duration_s'] = descriptor['duration_s'];
      }
      
      // Create descriptor
      final mcpDescriptor = McpDescriptor(
        mimeType: mimeType,
        length: fileSize ?? descriptor['sizeBytes'] as int?,
        metadata: descriptorMetadata,
      );
      
      // Create integrity information
      final fileBytesCount = fileExists && fileSize != null ? fileSize : 0;
      final mcpIntegrity = McpIntegrity(
        contentHash: sha256Hash ?? integrity['sha256'] ?? integrity['contentHash'] ?? '',
        bytes: fileBytesCount,
        mime: mimeType,
        createdAt: fileExists ? await file.lastModified() : DateTime.now(),
      );
      
      // Create privacy settings
      final mcpPrivacy = McpPrivacy(
        containsPii: privacy['piiDetected'] ?? privacy['containsPii'] ?? false,
        facesDetected: privacy['facesDetected'] ?? false,
        locationPrecision: privacy['locationPrecision'] as String?,
        sharingPolicy: privacy['sharingPolicy'] ?? 'private',
      );
      
      // Create sampling manifest (required, but can be empty)
      final mcpSamplingManifest = McpSamplingManifest(
        keyframes: (samplingManifest?['keyframes'] as List<dynamic>?)
            ?.map((kf) {
              final timestamp = kf['timestamp'];
              // Convert to double - handle both Duration and numeric values
              double timestampValue;
              if (timestamp is Duration) {
                timestampValue = timestamp.inMilliseconds.toDouble();
              } else if (timestamp is num) {
                timestampValue = timestamp.toDouble();
              } else {
                timestampValue = 0.0;
              }
              return McpKeyframe(
                timestamp: timestampValue,
                description: kf['description'] as String? ?? kf['uri'] as String?,
                metadata: Map<String, dynamic>.from(kf['metadata'] ?? {}),
              );
            })
            .toList() ?? [],
        spans: (samplingManifest?['spans'] as List<dynamic>?)
            ?.map((span) {
              final start = span['start'];
              final end = span['end'];
              // Convert to int - handle both Duration and numeric values
              int startValue;
              int endValue;
              if (start is Duration) {
                startValue = start.inMilliseconds;
              } else if (start is num) {
                startValue = start.toInt();
              } else {
                startValue = 0;
              }
              if (end is Duration) {
                endValue = end.inMilliseconds;
              } else if (end is num) {
                endValue = end.toInt();
              } else {
                endValue = 0;
              }
              return McpSpan(
                start: startValue,
                end: endValue,
                type: span['label'] as String? ?? span['type'] as String?,
                metadata: Map<String, dynamic>.from(span['metadata'] ?? {}),
              );
            })
            .toList() ?? [],
        metadata: samplingManifest != null 
            ? Map<String, dynamic>.from(samplingManifest)
            : {},
      );
      
      // Create provenance information
      final provenance = McpProvenance(
        source: 'EPI_Multimodal_Orchestrator',
        device: await _getDeviceInfo(),
        app: 'EPI',
        importMethod: 'mcp_pointer_service',
      );
      
      return McpPointer(
        id: pointerId,
        mediaType: mediaType,
        sourceUri: uri,
        descriptor: mcpDescriptor,
        integrity: mcpIntegrity,
        privacy: mcpPrivacy,
        samplingManifest: mcpSamplingManifest,
        provenance: provenance,
        createdAt: DateTime.now(),
      );
    } catch (e) {
      throw Exception('Failed to create MCP pointer: $e');
    }
  }

  /// Resolve pointer to actual media content
  static Future<PointerResolution> resolvePointer(McpPointer pointer) async {
    try {
      final sourceUri = pointer.sourceUri;
      if (sourceUri == null) {
        return PointerResolution(
          success: false,
          error: 'Media file URI is null',
          content: null,
          metadata: {},
        );
      }
      
      final file = File(sourceUri);
      final exists = await file.exists();
      
      if (!exists) {
        return PointerResolution(
          success: false,
          error: 'Media file not found: $sourceUri',
          content: null,
          metadata: {},
        );
      }
      
      // Check integrity if available
      if (pointer.integrity.contentHash.isNotEmpty) {
        final fileBytes = await file.readAsBytes();
        final hash = sha256.convert(fileBytes);
        final currentHash = hash.toString();
        
        if (currentHash != pointer.integrity.contentHash) {
          return PointerResolution(
            success: false,
            error: 'Integrity check failed: hash mismatch',
            content: null,
            metadata: {},
          );
        }
      }
      
      // Read content based on media type
      Uint8List? content;
      Map<String, dynamic> metadata = {};
      
      switch (pointer.mediaType) {
        case 'image':
          content = await file.readAsBytes();
          metadata = await _extractImageMetadata(file);
          break;
        case 'video':
          content = await file.readAsBytes();
          metadata = await _extractVideoMetadata(file);
          break;
        case 'audio':
          content = await file.readAsBytes();
          metadata = await _extractAudioMetadata(file);
          break;
        default:
          content = await file.readAsBytes();
          metadata = await _extractFileMetadata(file);
      }
      
      return PointerResolution(
        success: true,
        error: null,
        content: content,
        metadata: metadata,
      );
    } catch (e) {
      return PointerResolution(
        success: false,
        error: 'Failed to resolve pointer: $e',
        content: null,
        metadata: {},
      );
    }
  }

  /// Generate thumbnail for pointer
  static Future<ThumbnailResult> generateThumbnail(
    McpPointer pointer,
    String size,
  ) async {
    try {
      final resolution = await resolvePointer(pointer);
      if (!resolution.success || resolution.content == null) {
        return ThumbnailResult(
          success: false,
          error: resolution.error ?? 'Failed to resolve pointer',
          thumbnailUri: null,
        );
      }
      
      // Create thumbnail based on media type and size
      String thumbnailUri;
      switch (pointer.mediaType) {
        case 'image':
          thumbnailUri = await _generateImageThumbnail(
            resolution.content!,
            size,
            pointer.id,
          );
          break;
        case 'video':
          thumbnailUri = await _generateVideoThumbnail(
            resolution.content!,
            size,
            pointer.id,
          );
          break;
        case 'audio':
          thumbnailUri = await _generateAudioThumbnail(
            pointer,
            size,
          );
          break;
        default:
          thumbnailUri = await _generateFileThumbnail(
            pointer,
            size,
          );
      }
      
      return ThumbnailResult(
        success: true,
        error: null,
        thumbnailUri: thumbnailUri,
      );
    } catch (e) {
      return ThumbnailResult(
        success: false,
        error: 'Failed to generate thumbnail: $e',
        thumbnailUri: null,
      );
    }
  }

  /// Clean up temporary files
  static Future<void> cleanupTempFiles(List<String> uris) async {
    for (final uri in uris) {
      try {
        final file = File(uri);
        if (await file.exists()) {
          await file.delete();
        }
      } catch (e) {
        // Log error but continue cleanup
        print('Failed to cleanup temp file $uri: $e');
      }
    }
  }

  // Helper methods

  static String _getDefaultMimeType(String mediaType) {
    switch (mediaType) {
      case 'image':
        return 'image/jpeg';
      case 'video':
        return 'video/mp4';
      case 'audio':
        return 'audio/m4a';
      default:
        return 'application/octet-stream';
    }
  }

  static Future<String> _getDeviceInfo() async {
    // TODO: Integrate with device_info_plus
    return 'EPI_Device';
  }

  static Future<Map<String, dynamic>> _extractImageMetadata(File file) async {
    final stat = await file.stat();
    return {
      'sizeBytes': stat.size,
      'lastModified': stat.modified.toIso8601String(),
      'mimeType': lookupMimeType(file.path) ?? 'image/jpeg',
    };
  }

  static Future<Map<String, dynamic>> _extractVideoMetadata(File file) async {
    final stat = await file.stat();
    return {
      'sizeBytes': stat.size,
      'lastModified': stat.modified.toIso8601String(),
      'mimeType': lookupMimeType(file.path) ?? 'video/mp4',
    };
  }

  static Future<Map<String, dynamic>> _extractAudioMetadata(File file) async {
    final stat = await file.stat();
    return {
      'sizeBytes': stat.size,
      'lastModified': stat.modified.toIso8601String(),
      'mimeType': lookupMimeType(file.path) ?? 'audio/m4a',
    };
  }

  static Future<Map<String, dynamic>> _extractFileMetadata(File file) async {
    final stat = await file.stat();
    return {
      'sizeBytes': stat.size,
      'lastModified': stat.modified.toIso8601String(),
      'mimeType': lookupMimeType(file.path) ?? 'application/octet-stream',
    };
  }

  static Future<String> _generateImageThumbnail(
    Uint8List content,
    String size,
    String pointerId,
  ) async {
    // TODO: Implement actual image thumbnail generation
    // For now, return placeholder
    final tempDir = await getTemporaryDirectory();
    final thumbnailFile = File('${tempDir.path}/thumb_${pointerId}_$size.jpg');
    await thumbnailFile.writeAsBytes(content); // Placeholder
    return thumbnailFile.path;
  }

  static Future<String> _generateVideoThumbnail(
    Uint8List content,
    String size,
    String pointerId,
  ) async {
    // TODO: Implement actual video thumbnail generation using FFmpeg
    final tempDir = await getTemporaryDirectory();
    final thumbnailFile = File('${tempDir.path}/thumb_${pointerId}_$size.jpg');
    await thumbnailFile.writeAsBytes(content); // Placeholder
    return thumbnailFile.path;
  }

  static Future<String> _generateAudioThumbnail(
    McpPointer pointer,
    String size,
  ) async {
    // Generate audio waveform thumbnail
    final tempDir = await getTemporaryDirectory();
    final thumbnailFile = File('${tempDir.path}/thumb_${pointer.id}_$size.png');
    // TODO: Generate actual waveform thumbnail
    return thumbnailFile.path;
  }

  static Future<String> _generateFileThumbnail(
    McpPointer pointer,
    String size,
  ) async {
    // Generate file type icon thumbnail
    final tempDir = await getTemporaryDirectory();
    final thumbnailFile = File('${tempDir.path}/thumb_${pointer.id}_$size.png');
    // TODO: Generate actual file type icon
    return thumbnailFile.path;
  }
}

/// Result of pointer resolution
class PointerResolution {
  final bool success;
  final String? error;
  final Uint8List? content;
  final Map<String, dynamic> metadata;

  PointerResolution({
    required this.success,
    required this.error,
    required this.content,
    required this.metadata,
  });
}

/// Result of thumbnail generation
class ThumbnailResult {
  final bool success;
  final String? error;
  final String? thumbnailUri;

  ThumbnailResult({
    required this.success,
    required this.error,
    required this.thumbnailUri,
  });
}

