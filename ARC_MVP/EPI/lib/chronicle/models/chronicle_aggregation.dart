import 'chronicle_layer.dart';

/// CHRONICLE Aggregation Model
/// 
/// Represents a synthesized aggregation at any layer (monthly, yearly, multi-year).
/// Contains metadata, content (markdown), and source tracking.

class ChronicleAggregation {
  /// The layer this aggregation belongs to
  final ChronicleLayer layer;

  /// Period identifier (e.g., "2025-01" for monthly, "2025" for yearly, "2020-2024" for multi-year)
  final String period;

  /// When this aggregation was synthesized
  final DateTime synthesisDate;

  /// Number of source entries aggregated
  final int entryCount;

  /// Compression ratio achieved (tokens in aggregation / tokens in source entries)
  final double compressionRatio;

  /// Markdown content of the aggregation
  final String content;

  /// IDs of source entries (for Layer 0) or source aggregations (for higher layers)
  final List<String> sourceEntryIds;

  /// Whether user has edited this aggregation
  final bool userEdited;

  /// Version number (increments on re-synthesis or user edit)
  final int version;

  /// User ID this aggregation belongs to
  final String userId;

  const ChronicleAggregation({
    required this.layer,
    required this.period,
    required this.synthesisDate,
    required this.entryCount,
    required this.compressionRatio,
    required this.content,
    required this.sourceEntryIds,
    this.userEdited = false,
    this.version = 1,
    required this.userId,
  });

  /// Create a copy with modified fields
  ChronicleAggregation copyWith({
    ChronicleLayer? layer,
    String? period,
    DateTime? synthesisDate,
    int? entryCount,
    double? compressionRatio,
    String? content,
    List<String>? sourceEntryIds,
    bool? userEdited,
    int? version,
    String? userId,
  }) {
    return ChronicleAggregation(
      layer: layer ?? this.layer,
      period: period ?? this.period,
      synthesisDate: synthesisDate ?? this.synthesisDate,
      entryCount: entryCount ?? this.entryCount,
      compressionRatio: compressionRatio ?? this.compressionRatio,
      content: content ?? this.content,
      sourceEntryIds: sourceEntryIds ?? this.sourceEntryIds,
      userEdited: userEdited ?? this.userEdited,
      version: version ?? this.version,
      userId: userId ?? this.userId,
    );
  }

  /// Convert to JSON for serialization
  Map<String, dynamic> toJson() {
    return {
      'layer': layer.name,
      'period': period,
      'synthesisDate': synthesisDate.toIso8601String(),
      'entryCount': entryCount,
      'compressionRatio': compressionRatio,
      'content': content,
      'sourceEntryIds': sourceEntryIds,
      'userEdited': userEdited,
      'version': version,
      'userId': userId,
    };
  }

  /// Create from JSON
  factory ChronicleAggregation.fromJson(Map<String, dynamic> json) {
    return ChronicleAggregation(
      layer: ChronicleLayerHelpers.fromJson(json['layer'] as String),
      period: json['period'] as String,
      synthesisDate: DateTime.parse(json['synthesisDate'] as String),
      entryCount: json['entryCount'] as int,
      compressionRatio: (json['compressionRatio'] as num).toDouble(),
      content: json['content'] as String,
      sourceEntryIds: List<String>.from(json['sourceEntryIds'] as List),
      userEdited: json['userEdited'] as bool? ?? false,
      version: json['version'] as int? ?? 1,
      userId: json['userId'] as String,
    );
  }

  @override
  String toString() {
    return 'ChronicleAggregation(layer: ${layer.displayName}, period: $period, entries: $entryCount, compression: ${(compressionRatio * 100).toStringAsFixed(1)}%)';
  }
}
