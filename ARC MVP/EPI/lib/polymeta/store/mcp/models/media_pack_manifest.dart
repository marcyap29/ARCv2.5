/// Media pack manifest model
class MediaPackManifest {
  final String id;
  final String name;
  final List<String> mediaIds;
  final DateTime createdAt;
  final Map<String, dynamic> metadata;
  final Map<String, MediaPackItem> items;

  const MediaPackManifest({
    required this.id,
    required this.name,
    required this.mediaIds,
    required this.createdAt,
    required this.metadata,
    required this.items,
  });

  /// Convert to JSON map
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'mediaIds': mediaIds,
    'createdAt': createdAt.toIso8601String(),
    'metadata': metadata,
    'items': items.map((key, value) => MapEntry(key, value.toJson())),
  };

  /// Create from JSON map
  factory MediaPackManifest.fromJson(Map<String, dynamic> json) {
    final itemsMap = <String, MediaPackItem>{};
    if (json['items'] is Map) {
      final itemsJson = json['items'] as Map<String, dynamic>;
      itemsJson.forEach((key, value) {
        if (value is Map<String, dynamic>) {
          itemsMap[key] = MediaPackItem.fromJson(value);
        }
      });
    }
    
    return MediaPackManifest(
      id: json['id'] as String,
      name: json['name'] as String,
      mediaIds: (json['mediaIds'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList(),
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
      metadata: json['metadata'] as Map<String, dynamic>? ?? {},
      items: itemsMap,
    );
  }
}

/// Media pack item model
class MediaPackItem {
  final String path;
  final Map<String, dynamic>? metadata;

  const MediaPackItem({
    required this.path,
    this.metadata,
  });

  /// Convert to JSON map
  Map<String, dynamic> toJson() => {
    'path': path,
    if (metadata != null && metadata!.isNotEmpty) 'metadata': metadata,
  };

  /// Create from JSON map
  factory MediaPackItem.fromJson(Map<String, dynamic> json) {
    return MediaPackItem(
      path: json['path'] as String,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }
}

