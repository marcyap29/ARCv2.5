import 'package:equatable/equatable.dart';

/// Manifest for a media pack containing full-resolution photos
class MediaPackManifest extends Equatable {
  final String id;
  final DateTime from;
  final DateTime to;
  final Map<String, MediaPackItem> items;

  const MediaPackManifest({
    required this.id,
    required this.from,
    required this.to,
    required this.items,
  });

  factory MediaPackManifest.fromJson(Map<String, dynamic> json) {
    final itemsMap = <String, MediaPackItem>{};
    final itemsJson = json['items'] as Map<String, dynamic>;
    
    for (final entry in itemsJson.entries) {
      itemsMap[entry.key] = MediaPackItem.fromJson(entry.value as Map<String, dynamic>);
    }

    return MediaPackManifest(
      id: json['id'] as String,
      from: DateTime.parse(json['from'] as String),
      to: DateTime.parse(json['to'] as String),
      items: itemsMap,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'from': from.toIso8601String(),
      'to': to.toIso8601String(),
      'items': items.map((key, value) => MapEntry(key, value.toJson())),
    };
  }

  /// Get total size of all items in this pack
  int get totalSize {
    return items.values.fold(0, (sum, item) => sum + item.bytes);
  }

  /// Get count of items in this pack
  int get itemCount => items.length;

  @override
  List<Object?> get props => [id, from, to, items];
}

/// Individual media item within a media pack
class MediaPackItem extends Equatable {
  final String path;
  final int bytes;
  final String format;

  const MediaPackItem({
    required this.path,
    required this.bytes,
    required this.format,
  });

  factory MediaPackItem.fromJson(Map<String, dynamic> json) {
    return MediaPackItem(
      path: json['path'] as String,
      bytes: json['bytes'] as int,
      format: json['format'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'path': path,
      'bytes': bytes,
      'format': format,
    };
  }

  @override
  List<Object?> get props => [path, bytes, format];
}

/// Configuration for media pack creation
class MediaPackConfig extends Equatable {
  final int maxSizeBytes;
  final int maxItems;
  final String format;
  final int quality;
  final int maxEdge;

  const MediaPackConfig({
    required this.maxSizeBytes,
    required this.maxItems,
    required this.format,
    required this.quality,
    required this.maxEdge,
  });

  factory MediaPackConfig.fromJson(Map<String, dynamic> json) {
    return MediaPackConfig(
      maxSizeBytes: json['maxSizeBytes'] as int,
      maxItems: json['maxItems'] as int,
      format: json['format'] as String,
      quality: json['quality'] as int,
      maxEdge: json['maxEdge'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'maxSizeBytes': maxSizeBytes,
      'maxItems': maxItems,
      'format': format,
      'quality': quality,
      'maxEdge': maxEdge,
    };
  }

  @override
  List<Object?> get props => [maxSizeBytes, maxItems, format, quality, maxEdge];

  /// Default media pack configuration
  static const MediaPackConfig defaultConfig = MediaPackConfig(
    maxSizeBytes: 100 * 1024 * 1024, // 100MB
    maxItems: 1000,
    format: 'jpg',
    quality: 85,
    maxEdge: 2048,
  );
}
