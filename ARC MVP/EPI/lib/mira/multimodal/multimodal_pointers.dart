// lib/mira/multimodal/multimodal_pointers.dart
// Multimodal Pointers for MIRA Memory
// Supports text, image, audio with embedding references and normalized timestamps

import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import '../core/schema_v2.dart';
import '../../lumara/chat/ulid.dart';

/// Media type enumeration
enum MediaType {
  text,
  image,
  audio,
  video,
  document,
  unknown,
}

/// Embedding reference for multimodal content
class EmbeddingReference {
  final String id;
  final String model;
  final String modality; // text, image, audio
  final List<double> values;
  final DateTime createdAt;
  final String? sourceUri;
  final Map<String, dynamic> metadata;

  const EmbeddingReference({
    required this.id,
    required this.model,
    required this.modality,
    required this.values,
    required this.createdAt,
    this.sourceUri,
    this.metadata = const {},
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'model': model,
    'modality': modality,
    'values': values,
    'created_at': createdAt.toUtc().toIso8601String(),
    if (sourceUri != null) 'source_uri': sourceUri,
    'metadata': metadata,
  };

  factory EmbeddingReference.fromJson(Map<String, dynamic> json) => EmbeddingReference(
    id: json['id'] as String,
    model: json['model'] as String,
    modality: json['modality'] as String,
    values: List<double>.from(json['values'] as List),
    createdAt: DateTime.parse(json['created_at'] as String),
    sourceUri: json['source_uri'] as String?,
    metadata: Map<String, dynamic>.from(json['metadata'] ?? {}),
  );
}

/// EXIF data for media files
class ExifData {
  final DateTime? creationTime;
  final DateTime? modificationTime;
  final String? cameraMake;
  final String? cameraModel;
  final String? software;
  final Map<String, double>? gpsCoordinates;
  final int? width;
  final int? height;
  final String? orientation;
  final Map<String, dynamic> rawData;

  const ExifData({
    this.creationTime,
    this.modificationTime,
    this.cameraMake,
    this.cameraModel,
    this.software,
    this.gpsCoordinates,
    this.width,
    this.height,
    this.orientation,
    this.rawData = const {},
  });

  /// Normalize timestamp to UTC
  DateTime? get normalizedCreationTime {
    if (creationTime == null) return null;
    return creationTime!.toUtc();
  }

  /// Normalize modification time to UTC
  DateTime? get normalizedModificationTime {
    if (modificationTime == null) return null;
    return modificationTime!.toUtc();
  }

  Map<String, dynamic> toJson() => {
    if (creationTime != null) 'creation_time': creationTime!.toUtc().toIso8601String(),
    if (modificationTime != null) 'modification_time': modificationTime!.toUtc().toIso8601String(),
    if (cameraMake != null) 'camera_make': cameraMake,
    if (cameraModel != null) 'camera_model': cameraModel,
    if (software != null) 'software': software,
    if (gpsCoordinates != null) 'gps_coordinates': gpsCoordinates,
    if (width != null) 'width': width,
    if (height != null) 'height': height,
    if (orientation != null) 'orientation': orientation,
    'raw_data': rawData,
  };

  factory ExifData.fromJson(Map<String, dynamic> json) => ExifData(
    creationTime: json['creation_time'] != null 
        ? DateTime.parse(json['creation_time'] as String) 
        : null,
    modificationTime: json['modification_time'] != null 
        ? DateTime.parse(json['modification_time'] as String) 
        : null,
    cameraMake: json['camera_make'] as String?,
    cameraModel: json['camera_model'] as String?,
    software: json['software'] as String?,
    gpsCoordinates: json['gps_coordinates'] != null 
        ? Map<String, double>.from(json['gps_coordinates'] as Map) 
        : null,
    width: json['width'] as int?,
    height: json['height'] as int?,
    orientation: json['orientation'] as String?,
    rawData: Map<String, dynamic>.from(json['raw_data'] ?? {}),
  );
}

/// Enhanced multimodal pointer with embedding references
class MultimodalPointer {
  final String id;
  final String schemaId;
  final MediaType mediaType;
  final String sourceUri;
  final String mimeType;
  final int? fileSize;
  final String? sha256;
  final ExifData? exifData;
  final List<EmbeddingReference> embeddingRefs;
  final Map<String, dynamic> metadata;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isTombstoned;
  final DateTime? deletedAt;
  final Provenance provenance;

  const MultimodalPointer({
    required this.id,
    required this.schemaId,
    required this.mediaType,
    required this.sourceUri,
    required this.mimeType,
    this.fileSize,
    this.sha256,
    this.exifData,
    this.embeddingRefs = const [],
    this.metadata = const {},
    required this.createdAt,
    required this.updatedAt,
    this.isTombstoned = false,
    this.deletedAt,
    required this.provenance,
  });

  /// Create a new multimodal pointer
  factory MultimodalPointer.create({
    required MediaType mediaType,
    required String sourceUri,
    required String mimeType,
    required String source,
    required String operation,
    String? traceId,
    int? fileSize,
    String? sha256,
    ExifData? exifData,
    List<EmbeddingReference>? embeddingRefs,
    Map<String, dynamic>? metadata,
  }) {
    final now = DateTime.now().toUtc();
    return MultimodalPointer(
      id: ULID.generate(),
      schemaId: 'mira.multimodal_pointer@${MiraVersion.MIRA_VERSION}',
      mediaType: mediaType,
      sourceUri: sourceUri,
      mimeType: mimeType,
      fileSize: fileSize,
      sha256: sha256,
      exifData: exifData,
      embeddingRefs: embeddingRefs ?? [],
      metadata: metadata ?? {},
      createdAt: now,
      updatedAt: now,
      provenance: Provenance.create(
        source: source,
        operation: operation,
        traceId: traceId,
      ),
    );
  }

  /// Convert to JSON for serialization
  Map<String, dynamic> toJson() => {
    'id': id,
    'schema_id': schemaId,
    'media_type': mediaType.name,
    'source_uri': sourceUri,
    'mime_type': mimeType,
    if (fileSize != null) 'file_size': fileSize,
    if (sha256 != null) 'sha256': sha256,
    if (exifData != null) 'exif_data': exifData!.toJson(),
    'embedding_refs': embeddingRefs.map((e) => e.toJson()).toList(),
    'metadata': metadata,
    'created_at': createdAt.toUtc().toIso8601String(),
    'updated_at': updatedAt.toUtc().toIso8601String(),
    'is_tombstoned': isTombstoned,
    if (deletedAt != null) 'deleted_at': deletedAt!.toUtc().toIso8601String(),
    'provenance': provenance.toJson(),
  };

  /// Create from JSON
  factory MultimodalPointer.fromJson(Map<String, dynamic> json) => MultimodalPointer(
    id: json['id'] as String,
    schemaId: json['schema_id'] as String? ?? 'mira.multimodal_pointer@0.1.0',
    mediaType: MediaType.values.firstWhere(
      (e) => e.name == json['media_type'],
      orElse: () => MediaType.unknown,
    ),
    sourceUri: json['source_uri'] as String,
    mimeType: json['mime_type'] as String,
    fileSize: json['file_size'] as int?,
    sha256: json['sha256'] as String?,
    exifData: json['exif_data'] != null 
        ? ExifData.fromJson(json['exif_data'] as Map<String, dynamic>) 
        : null,
    embeddingRefs: (json['embedding_refs'] as List<dynamic>? ?? [])
        .map((e) => EmbeddingReference.fromJson(e as Map<String, dynamic>))
        .toList(),
    metadata: Map<String, dynamic>.from(json['metadata'] ?? {}),
    createdAt: DateTime.parse(json['created_at'] as String),
    updatedAt: DateTime.parse(json['updated_at'] as String),
    isTombstoned: json['is_tombstoned'] as bool? ?? false,
    deletedAt: json['deleted_at'] != null 
        ? DateTime.parse(json['deleted_at'] as String) 
        : null,
    provenance: Provenance.fromJson(json['provenance'] as Map<String, dynamic>),
  );

  /// Create a copy with updated fields
  MultimodalPointer copyWith({
    String? id,
    String? schemaId,
    MediaType? mediaType,
    String? sourceUri,
    String? mimeType,
    int? fileSize,
    String? sha256,
    ExifData? exifData,
    List<EmbeddingReference>? embeddingRefs,
    Map<String, dynamic>? metadata,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isTombstoned,
    DateTime? deletedAt,
    Provenance? provenance,
  }) => MultimodalPointer(
    id: id ?? this.id,
    schemaId: schemaId ?? this.schemaId,
    mediaType: mediaType ?? this.mediaType,
    sourceUri: sourceUri ?? this.sourceUri,
    mimeType: mimeType ?? this.mimeType,
    fileSize: fileSize ?? this.fileSize,
    sha256: sha256 ?? this.sha256,
    exifData: exifData ?? this.exifData,
    embeddingRefs: embeddingRefs ?? this.embeddingRefs,
    metadata: metadata ?? Map<String, dynamic>.from(this.metadata),
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? DateTime.now().toUtc(),
    isTombstoned: isTombstoned ?? this.isTombstoned,
    deletedAt: deletedAt ?? this.deletedAt,
    provenance: provenance ?? this.provenance,
  );

  /// Add embedding reference
  MultimodalPointer addEmbeddingReference(EmbeddingReference embedding) {
    final updatedRefs = List<EmbeddingReference>.from(embeddingRefs)..add(embedding);
    return copyWith(embeddingRefs: updatedRefs);
  }

  /// Remove embedding reference
  MultimodalPointer removeEmbeddingReference(String embeddingId) {
    final updatedRefs = embeddingRefs.where((e) => e.id != embeddingId).toList();
    return copyWith(embeddingRefs: updatedRefs);
  }

  /// Get embedding references by modality
  List<EmbeddingReference> getEmbeddingsByModality(String modality) {
    return embeddingRefs.where((e) => e.modality == modality).toList();
  }

  /// Get normalized creation time from EXIF or fallback to pointer creation time
  DateTime get normalizedCreationTime {
    return exifData?.normalizedCreationTime ?? createdAt;
  }

  /// Check if pointer is active (not tombstoned)
  bool get isActive => !isTombstoned;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MultimodalPointer && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'MultimodalPointer($id, ${mediaType.name}:$sourceUri)';
}

/// Multimodal pointer manager
class MultimodalPointerManager {
  final Map<String, MultimodalPointer> _pointers;
  final Map<String, EmbeddingReference> _embeddings;

  MultimodalPointerManager() : _pointers = {}, _embeddings = {};

  /// Create a new multimodal pointer
  MultimodalPointer createPointer({
    required MediaType mediaType,
    required String sourceUri,
    required String mimeType,
    required String source,
    required String operation,
    String? traceId,
    int? fileSize,
    String? sha256,
    ExifData? exifData,
    Map<String, dynamic>? metadata,
  }) {
    final pointer = MultimodalPointer.create(
      mediaType: mediaType,
      sourceUri: sourceUri,
      mimeType: mimeType,
      source: source,
      operation: operation,
      traceId: traceId,
      fileSize: fileSize,
      sha256: sha256,
      exifData: exifData,
      metadata: metadata,
    );

    _pointers[pointer.id] = pointer;
    return pointer;
  }

  /// Add embedding reference to a pointer
  MultimodalPointer addEmbedding({
    required String pointerId,
    required String model,
    required String modality,
    required List<double> values,
    String? sourceUri,
    Map<String, dynamic>? metadata,
  }) {
    final embedding = EmbeddingReference(
      id: ULID.generate(),
      model: model,
      modality: modality,
      values: values,
      createdAt: DateTime.now().toUtc(),
      sourceUri: sourceUri,
      metadata: metadata ?? {},
    );

    _embeddings[embedding.id] = embedding;

    final pointer = _pointers[pointerId];
    if (pointer != null) {
      final updatedPointer = pointer.addEmbeddingReference(embedding);
      _pointers[pointerId] = updatedPointer;
      return updatedPointer;
    }

    throw Exception('Pointer not found: $pointerId');
  }

  /// Get pointer by ID
  MultimodalPointer? getPointer(String id) => _pointers[id];

  /// Get all pointers
  List<MultimodalPointer> getAllPointers() => _pointers.values.toList();

  /// Get pointers by media type
  List<MultimodalPointer> getPointersByMediaType(MediaType mediaType) {
    return _pointers.values.where((p) => p.mediaType == mediaType).toList();
  }

  /// Get pointers with embeddings for specific modality
  List<MultimodalPointer> getPointersWithEmbeddings(String modality) {
    return _pointers.values.where((p) => 
      p.embeddingRefs.any((e) => e.modality == modality)
    ).toList();
  }

  /// Tombstone a pointer
  MultimodalPointer tombstonePointer(String id) {
    final pointer = _pointers[id];
    if (pointer == null) {
      throw Exception('Pointer not found: $id');
    }

    final tombstonedPointer = pointer.copyWith(
      isTombstoned: true,
      deletedAt: DateTime.now().toUtc(),
    );

    _pointers[id] = tombstonedPointer;
    return tombstonedPointer;
  }

  /// Get embedding by ID
  EmbeddingReference? getEmbedding(String id) => _embeddings[id];

  /// Get all embeddings
  List<EmbeddingReference> getAllEmbeddings() => _embeddings.values.toList();

  /// Get embeddings by modality
  List<EmbeddingReference> getEmbeddingsByModality(String modality) {
    return _embeddings.values.where((e) => e.modality == modality).toList();
  }

  /// Compute SHA-256 hash for file content
  static String computeFileHash(Uint8List content) {
    final bytes = sha256.convert(content).bytes;
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  /// Parse EXIF data from image metadata
  static ExifData? parseExifData(Map<String, dynamic> rawExif) {
    if (rawExif.isEmpty) return null;

    DateTime? creationTime;
    DateTime? modificationTime;
    String? cameraMake;
    String? cameraModel;
    String? software;
    Map<String, double>? gpsCoordinates;
    int? width;
    int? height;
    String? orientation;

    // Parse creation time
    final createTimeStr = rawExif['DateTime'] as String? ?? 
                         rawExif['DateTimeOriginal'] as String? ??
                         rawExif['CreateDate'] as String?;
    if (createTimeStr != null) {
      try {
        creationTime = DateTime.parse(createTimeStr);
      } catch (e) {
        // Try alternative formats
        try {
          creationTime = DateTime.parse(createTimeStr.replaceAll(':', '-'));
        } catch (e) {
          // Ignore parsing errors
        }
      }
    }

    // Parse modification time
    final modTimeStr = rawExif['ModifyDate'] as String? ?? 
                      rawExif['DateTimeDigitized'] as String?;
    if (modTimeStr != null) {
      try {
        modificationTime = DateTime.parse(modTimeStr);
      } catch (e) {
        try {
          modificationTime = DateTime.parse(modTimeStr.replaceAll(':', '-'));
        } catch (e) {
          // Ignore parsing errors
        }
      }
    }

    // Parse camera info
    cameraMake = rawExif['Make'] as String?;
    cameraModel = rawExif['Model'] as String?;
    software = rawExif['Software'] as String?;

    // Parse GPS coordinates
    final lat = rawExif['GPSLatitude'] as double?;
    final lon = rawExif['GPSLongitude'] as double?;
    if (lat != null && lon != null) {
      gpsCoordinates = {'latitude': lat, 'longitude': lon};
    }

    // Parse dimensions
    width = rawExif['ImageWidth'] as int? ?? rawExif['ExifImageWidth'] as int?;
    height = rawExif['ImageHeight'] as int? ?? rawExif['ExifImageHeight'] as int?;

    // Parse orientation
    final orientationValue = rawExif['Orientation'] as int?;
    if (orientationValue != null) {
      orientation = orientationValue.toString();
    }

    return ExifData(
      creationTime: creationTime,
      modificationTime: modificationTime,
      cameraMake: cameraMake,
      cameraModel: cameraModel,
      software: software,
      gpsCoordinates: gpsCoordinates,
      width: width,
      height: height,
      orientation: orientation,
      rawData: rawExif,
    );
  }

  /// Get statistics
  Map<String, dynamic> getStatistics() => {
    'total_pointers': _pointers.length,
    'active_pointers': _pointers.values.where((p) => p.isActive).length,
    'tombstoned_pointers': _pointers.values.where((p) => p.isTombstoned).length,
    'total_embeddings': _embeddings.length,
    'embeddings_by_modality': {
      for (final modality in ['text', 'image', 'audio'])
        modality: _embeddings.values.where((e) => e.modality == modality).length,
    },
    'pointers_by_media_type': {
      for (final type in MediaType.values)
        type.name: _pointers.values.where((p) => p.mediaType == type).length,
    },
  };
}
