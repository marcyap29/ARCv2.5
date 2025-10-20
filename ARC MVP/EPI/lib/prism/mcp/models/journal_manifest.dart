import 'package:equatable/equatable.dart';

/// Manifest for the main MCP journal bundle
class JournalManifest extends Equatable {
  final int version;
  final DateTime createdAt;
  final List<MediaPackRef> mediaPacks;
  final ThumbnailConfig thumbnails;

  const JournalManifest({
    required this.version,
    required this.createdAt,
    required this.mediaPacks,
    required this.thumbnails,
  });

  factory JournalManifest.fromJson(Map<String, dynamic> json) {
    return JournalManifest(
      version: json['version'] as int,
      createdAt: DateTime.parse(json['createdAt'] as String),
      mediaPacks: (json['mediaPacks'] as List<dynamic>)
          .map((pack) => MediaPackRef.fromJson(pack as Map<String, dynamic>))
          .toList(),
      thumbnails: ThumbnailConfig.fromJson(json['thumbnails'] as Map<String, dynamic>),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'version': version,
      'createdAt': createdAt.toIso8601String(),
      'mediaPacks': mediaPacks.map((pack) => pack.toJson()).toList(),
      'thumbnails': thumbnails.toJson(),
    };
  }

  @override
  List<Object?> get props => [version, createdAt, mediaPacks, thumbnails];
}

/// Reference to a media pack from the journal manifest
class MediaPackRef extends Equatable {
  final String id;
  final String filename;
  final DateTime from;
  final DateTime to;

  const MediaPackRef({
    required this.id,
    required this.filename,
    required this.from,
    required this.to,
  });

  factory MediaPackRef.fromJson(Map<String, dynamic> json) {
    return MediaPackRef(
      id: json['id'] as String,
      filename: json['filename'] as String,
      from: DateTime.parse(json['from'] as String),
      to: DateTime.parse(json['to'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'filename': filename,
      'from': from.toIso8601String(),
      'to': to.toIso8601String(),
    };
  }

  @override
  List<Object?> get props => [id, filename, from, to];
}

/// Configuration for thumbnail generation
class ThumbnailConfig extends Equatable {
  final int size;
  final String format;
  final int quality;

  const ThumbnailConfig({
    required this.size,
    required this.format,
    required this.quality,
  });

  factory ThumbnailConfig.fromJson(Map<String, dynamic> json) {
    return ThumbnailConfig(
      size: json['size'] as int,
      format: json['format'] as String,
      quality: json['quality'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'size': size,
      'format': format,
      'quality': quality,
    };
  }

  @override
  List<Object?> get props => [size, format, quality];

  /// Default thumbnail configuration
  static const ThumbnailConfig defaultConfig = ThumbnailConfig(
    size: 768,
    format: 'jpg',
    quality: 85,
  );
}
