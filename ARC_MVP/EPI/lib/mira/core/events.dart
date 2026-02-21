// lib/mira/core/events.dart
// Append-only event log for MIRA operations
// Enables replay, audit trails, and idempotent processing

import 'dart:convert';
import 'package:crypto/crypto.dart';

/// An event in the MIRA system representing a processing milestone
class MiraEvent {
  /// Unique identifier for this event
  final String id;

  /// Type of event (e.g., 'entry_processed', 'keywords_extracted')
  final String type;

  /// Event payload data (minimal for efficiency)
  final Map<String, dynamic> payload;

  /// When this event occurred
  final DateTime ts;

  /// Checksum of payload for integrity verification
  final String checksum;

  const MiraEvent({
    required this.id,
    required this.type,
    required this.payload,
    required this.ts,
    required this.checksum,
  });

  /// Create event with automatic checksum generation
  factory MiraEvent.create({
    required String id,
    required String type,
    required Map<String, dynamic> payload,
    DateTime? timestamp,
  }) {
    final ts = timestamp ?? DateTime.now().toUtc();
    final payloadJson = jsonEncode(payload);
    final checksum = sha1.convert(utf8.encode(payloadJson)).toString();

    return MiraEvent(
      id: id,
      type: type,
      payload: payload,
      ts: ts,
      checksum: checksum,
    );
  }

  /// Verify event integrity
  bool verifyChecksum() {
    final payloadJson = jsonEncode(payload);
    final computedChecksum = sha1.convert(utf8.encode(payloadJson)).toString();
    return computedChecksum == checksum;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MiraEvent && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'MiraEvent($id, $type, ${ts.toIso8601String()})';
}

/// Generate event ID for entry processing completion
String entryProcessedEventId(String entryId) => 'entry_processed:$entryId';

/// Generate event ID for keyword extraction
String keywordsExtractedEventId(String entryId) => 'keywords_extracted:$entryId';

/// Generate event ID for phase detection
String phaseDetectedEventId(String entryId) => 'phase_detected:$entryId';

/// Generate event ID for emotion analysis
String emotionsAnalyzedEventId(String entryId) => 'emotions_analyzed:$entryId';

/// Generate event ID for topic clustering
String topicsClusteredEventId(String timestamp) => 'topics_clustered:$timestamp';

/// Generate event ID for episode building
String episodesBuiltEventId(String timestamp) => 'episodes_built:$timestamp';

/// Generate event ID for MCP export
String mcpExportedEventId(String bundleId) => 'mcp_exported:$bundleId';

/// Generate event ID for MCP import
String mcpImportedEventId(String bundleId) => 'mcp_imported:$bundleId';

/// Common event factory methods
class MiraEvents {
  /// Create entry processed event
  static MiraEvent entryProcessed({
    required String entryId,
    required int keywordCount,
    required int emotionCount,
    String? phaseHint,
  }) {
    return MiraEvent.create(
      id: entryProcessedEventId(entryId),
      type: 'entry_processed',
      payload: {
        'entry_id': entryId,
        'keyword_count': keywordCount,
        'emotion_count': emotionCount,
        'phase_hint': phaseHint,
      },
    );
  }

  /// Create keywords extracted event
  static MiraEvent keywordsExtracted({
    required String entryId,
    required List<String> keywords,
  }) {
    return MiraEvent.create(
      id: keywordsExtractedEventId(entryId),
      type: 'keywords_extracted',
      payload: {
        'entry_id': entryId,
        'keywords': keywords,
        'count': keywords.length,
      },
    );
  }

  /// Create phase detected event
  static MiraEvent phaseDetected({
    required String entryId,
    required String phase,
    required double confidence,
  }) {
    return MiraEvent.create(
      id: phaseDetectedEventId(entryId),
      type: 'phase_detected',
      payload: {
        'entry_id': entryId,
        'phase': phase,
        'confidence': confidence,
      },
    );
  }

  /// Create emotions analyzed event
  static MiraEvent emotionsAnalyzed({
    required String entryId,
    required Map<String, double> emotions,
  }) {
    return MiraEvent.create(
      id: emotionsAnalyzedEventId(entryId),
      type: 'emotions_analyzed',
      payload: {
        'entry_id': entryId,
        'emotions': emotions,
        'count': emotions.length,
      },
    );
  }

  /// Create MCP export event
  static MiraEvent mcpExported({
    required String bundleId,
    required String exportPath,
    required Map<String, int> counts,
  }) {
    return MiraEvent.create(
      id: mcpExportedEventId(bundleId),
      type: 'mcp_exported',
      payload: {
        'bundle_id': bundleId,
        'export_path': exportPath,
        'counts': counts,
      },
    );
  }

  /// Create MCP import event
  static MiraEvent mcpImported({
    required String bundleId,
    required String importPath,
    required Map<String, int> counts,
  }) {
    return MiraEvent.create(
      id: mcpImportedEventId(bundleId),
      type: 'mcp_imported',
      payload: {
        'bundle_id': bundleId,
        'import_path': importPath,
        'counts': counts,
      },
    );
  }
}