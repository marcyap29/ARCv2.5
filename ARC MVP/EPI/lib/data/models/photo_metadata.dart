
/// Metadata for a photo in the iOS Photo Library
/// 
/// This class stores the essential information needed to identify and reconnect
/// to a photo after export/import cycles, without storing the actual photo data.
class PhotoMetadata {
  /// The local identifier from PHAsset (e.g., "ABC123-DEF456-GHI789")
  final String localIdentifier;
  
  /// When the photo was originally taken/created
  final DateTime? creationDate;
  
  /// When the photo was last modified
  final DateTime? modificationDate;
  
  /// Original filename (e.g., "IMG_1234.JPG")
  final String? filename;
  
  /// File size in bytes
  final int? fileSize;
  
  /// Width in pixels
  final int? pixelWidth;
  
  /// Height in pixels
  final int? pixelHeight;
  
  /// Perceptual hash for duplicate detection and matching
  final String? perceptualHash;
  
  /// Timestamp in milliseconds for precise iOS filtering
  final int? timestampMs;
  
  /// Cloud identifier for cross-device stability (iCloud Photos)
  final String? cloudIdentifier;

  const PhotoMetadata({
    required this.localIdentifier,
    this.creationDate,
    this.modificationDate,
    this.filename,
    this.fileSize,
    this.pixelWidth,
    this.pixelHeight,
    this.perceptualHash,
    this.timestampMs,
    this.cloudIdentifier,
  });

  /// Convert to JSON for MCP storage
  Map<String, dynamic> toJson() {
    return {
      'local_identifier': localIdentifier,
      'creation_date': creationDate?.toIso8601String(),
      'modification_date': modificationDate?.toIso8601String(),
      'filename': filename,
      'file_size': fileSize,
      'pixel_width': pixelWidth,
      'pixel_height': pixelHeight,
      'perceptual_hash': perceptualHash,
      'timestampMs': timestampMs,
      'cloud_identifier': cloudIdentifier,
    };
  }

  /// Create from JSON (from MCP import)
  factory PhotoMetadata.fromJson(Map<String, dynamic> json) {
    return PhotoMetadata(
      localIdentifier: json['local_identifier'] as String,
      creationDate: json['creation_date'] != null 
          ? DateTime.parse(json['creation_date'] as String)
          : null,
      modificationDate: json['modification_date'] != null
          ? DateTime.parse(json['modification_date'] as String)
          : null,
      filename: json['filename'] as String?,
      fileSize: json['file_size'] as int?,
      pixelWidth: json['pixel_width'] as int?,
      pixelHeight: json['pixel_height'] as int?,
      perceptualHash: json['perceptual_hash'] as String?,
      timestampMs: json['timestampMs'] as int?,
      cloudIdentifier: json['cloud_identifier'] as String?,
    );
  }

  /// Create a copy with some fields updated
  PhotoMetadata copyWith({
    String? localIdentifier,
    DateTime? creationDate,
    DateTime? modificationDate,
    String? filename,
    int? fileSize,
    int? pixelWidth,
    int? pixelHeight,
    String? perceptualHash,
    int? timestampMs,
    String? cloudIdentifier,
  }) {
    return PhotoMetadata(
      localIdentifier: localIdentifier ?? this.localIdentifier,
      creationDate: creationDate ?? this.creationDate,
      modificationDate: modificationDate ?? this.modificationDate,
      filename: filename ?? this.filename,
      fileSize: fileSize ?? this.fileSize,
      pixelWidth: pixelWidth ?? this.pixelWidth,
      pixelHeight: pixelHeight ?? this.pixelHeight,
      perceptualHash: perceptualHash ?? this.perceptualHash,
      timestampMs: timestampMs ?? this.timestampMs,
      cloudIdentifier: cloudIdentifier ?? this.cloudIdentifier,
    );
  }

  /// Check if this metadata has enough information for matching
  bool get hasMinimumData {
    return localIdentifier.isNotEmpty && 
           (creationDate != null || filename != null || fileSize != null);
  }

  /// Get a human-readable description for debugging
  String get description {
    final parts = <String>[];
    parts.add('ID: $localIdentifier');
    if (filename != null) parts.add('File: $filename');
    if (creationDate != null) parts.add('Created: ${creationDate!.toIso8601String()}');
    if (fileSize != null) parts.add('Size: ${fileSize!} bytes');
    if (pixelWidth != null && pixelHeight != null) {
      parts.add('Dimensions: ${pixelWidth!}x${pixelHeight!}');
    }
    return parts.join(', ');
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PhotoMetadata &&
        other.localIdentifier == localIdentifier &&
        other.creationDate == creationDate &&
        other.modificationDate == modificationDate &&
        other.filename == filename &&
        other.fileSize == fileSize &&
        other.pixelWidth == pixelWidth &&
        other.pixelHeight == pixelHeight &&
        other.perceptualHash == perceptualHash &&
        other.cloudIdentifier == cloudIdentifier;
  }

  @override
  int get hashCode {
    return Object.hash(
      localIdentifier,
      creationDate,
      modificationDate,
      filename,
      fileSize,
      pixelWidth,
      pixelHeight,
      perceptualHash,
      cloudIdentifier,
    );
  }

  @override
  String toString() {
    return 'PhotoMetadata($description)';
  }
}
