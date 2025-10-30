import 'dart:convert';

/// MCP Manifest for standardized Memory Container Protocol packages
class McpManifest {
  final String format;
  final int version;
  final String subtype;
  final DateTime createdUtc;
  final Map<String, int> counts;
  final Map<String, dynamic>? metadata;

  McpManifest({
    required this.format,
    required this.version,
    required this.subtype,
    required this.createdUtc,
    required this.counts,
    this.metadata,
  });

  /// Create a journal manifest
  factory McpManifest.journal({
    required int entryCount,
    required int photoCount,
    Map<String, dynamic>? metadata,
  }) {
    return McpManifest(
      format: 'mcp',
      version: 1,
      subtype: 'journal',
      createdUtc: DateTime.now().toUtc(),
      counts: {
        'entries': entryCount,
        'photos': photoCount,
      },
      metadata: metadata,
    );
  }

  /// Parse manifest from JSON
  factory McpManifest.fromJson(Map<String, dynamic> json) {
    return McpManifest(
      format: json['format'] as String,
      version: json['version'] as int,
      subtype: json['subtype'] as String,
      createdUtc: DateTime.parse(json['created_utc'] as String),
      counts: Map<String, int>.from(json['counts'] as Map<String, dynamic>),
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'format': format,
      'version': version,
      'subtype': subtype,
      'created_utc': createdUtc.toIso8601String(),
      'counts': counts,
      if (metadata != null) 'metadata': metadata,
    };
  }

  /// Convert to JSON string
  String toJsonString() {
    return jsonEncode(toJson());
  }

  /// Validate manifest format
  bool isValid() {
    return format == 'mcp' && 
           version == 1 && 
           subtype.isNotEmpty &&
           counts.isNotEmpty;
  }

  /// Get entry count
  int get entryCount => counts['entries'] ?? 0;

  /// Get photo count
  int get photoCount => counts['photos'] ?? 0;

  @override
  String toString() {
    return 'McpManifest(format: $format, version: $version, subtype: $subtype, entries: $entryCount, photos: $photoCount)';
  }
}
