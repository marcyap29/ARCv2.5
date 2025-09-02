import 'package:hive/hive.dart';
import 'package:my_app/models/journal_entry_model.dart';
import 'package:my_app/models/arcform_snapshot_model.dart';
import 'package:uuid/uuid.dart';

/// Service responsible for creating and managing Arcforms
/// This is the core of the ARC MVP functionality
class ArcformService {
  static const String _snapshotBoxName = 'arcform_snapshots';
  
  /// Creates an Arcform snapshot from a journal entry
  /// This is the main pipeline: entry → keywords → Arcform snapshot
  Future<ArcformSnapshot> createArcformFromEntry(
    JournalEntry entry,
    List<String> keywords,
  ) async {
    try {
      // Generate geometry pattern based on keywords and content
      final geometry = _determineGeometry(entry, keywords);
      
      // Generate color mapping for keywords
      final colorMap = _generateColorMap(keywords);
      
      // Generate edges between related keywords
      final edges = _generateEdges(keywords);
      
      // Create the snapshot
      final snapshot = ArcformSnapshot(
        id: const Uuid().v4(),
        arcformId: entry.id,
        data: {
          'keywords': keywords,
          'geometry': geometry.name,
          'colorMap': colorMap,
          'edges': edges,
          'mood': entry.mood,
          'phaseHint': _determinePhaseHint(entry, keywords),
        },
        timestamp: DateTime.now(),
        notes: 'Generated from journal entry: ${entry.title}',
      );
      
      // Save to Hive
      final box = await Hive.openBox<ArcformSnapshot>(_snapshotBoxName);
      await box.put(snapshot.id, snapshot);
      
      return snapshot;
    } catch (e) {
      throw Exception('Failed to create Arcform: $e');
    }
  }
  
  /// Determines the geometry pattern based on entry content and keywords
  GeometryPattern _determineGeometry(JournalEntry entry, List<String> keywords) {
    // Simple heuristic: analyze content length and keyword count
    final contentLength = entry.content.length;
    final keywordCount = keywords.length;
    
    if (contentLength > 500 && keywordCount > 7) {
      return GeometryPattern.fractal;
    } else if (contentLength > 300 && keywordCount > 5) {
      return GeometryPattern.branch;
    } else if (keywordCount > 3) {
      return GeometryPattern.flower;
    } else {
      return GeometryPattern.spiral;
    }
  }
  
  /// Generates a color map for keywords based on emotional content
  Map<String, String> _generateColorMap(List<String> keywords) {
    final colors = [
      '#4F46E5', // Primary blue
      '#7C3AED', // Purple
      '#D1B3FF', // Light purple
      '#6BE3A0', // Green
      '#F7D774', // Yellow
      '#FF6B6B', // Red
    ];
    
    final colorMap = <String, String>{};
    for (int i = 0; i < keywords.length; i++) {
      colorMap[keywords[i]] = colors[i % colors.length];
    }
    
    return colorMap;
  }
  
  /// Generates edges between related keywords
  List<List<dynamic>> _generateEdges(List<String> keywords) {
    final edges = <List<dynamic>>[];
    
    // Create connections between adjacent keywords
    for (int i = 0; i < keywords.length - 1; i++) {
      edges.add([i, i + 1, 0.8]); // [source, target, weight]
    }
    
    // Create some cross-connections for visual interest
    if (keywords.length > 3) {
      edges.add([0, keywords.length - 1, 0.6]); // Connect first and last
      if (keywords.length > 5) {
        edges.add([1, keywords.length - 2, 0.5]); // Connect second and second-to-last
      }
    }
    
    return edges;
  }
  
  /// Determines the ATLAS phase hint based on entry content
  String _determinePhaseHint(JournalEntry entry, List<String> keywords) {
    final content = entry.content.toLowerCase();
    
    if (content.contains('growth') || content.contains('learn') || content.contains('improve')) {
      return 'Discovery';
    } else if (content.contains('challenge') || content.contains('struggle') || content.contains('difficult')) {
      return 'Integration';
    } else if (content.contains('gratitude') || content.contains('appreciate') || content.contains('blessed')) {
      return 'Transcendence';
    } else {
      return 'Discovery';
    }
  }
  
  /// Retrieves all Arcform snapshots for a user
  Future<List<ArcformSnapshot>> getAllSnapshots() async {
    try {
      final box = await Hive.openBox<ArcformSnapshot>(_snapshotBoxName);
      return box.values.toList();
    } catch (e) {
      return [];
    }
  }
  
  /// Retrieves Arcform snapshots for a specific journal entry
  Future<List<ArcformSnapshot>> getSnapshotsForEntry(String entryId) async {
    try {
      final box = await Hive.openBox<ArcformSnapshot>(_snapshotBoxName);
      return box.values.where((snapshot) => snapshot.arcformId == entryId).toList();
    } catch (e) {
      return [];
    }
  }
  
  /// Deletes an Arcform snapshot
  Future<void> deleteSnapshot(String snapshotId) async {
    try {
      final box = await Hive.openBox<ArcformSnapshot>(_snapshotBoxName);
      await box.delete(snapshotId);
    } catch (e) {
      throw Exception('Failed to delete snapshot: $e');
    }
  }
}

/// Geometry patterns for Arcform visualization
enum GeometryPattern {
  spiral,
  flower,
  branch,
  weave,
  glowCore,
  fractal,
}

extension GeometryPatternExtension on GeometryPattern {
  String get name {
    switch (this) {
      case GeometryPattern.spiral:
        return 'Spiral';
      case GeometryPattern.flower:
        return 'Flower';
      case GeometryPattern.branch:
        return 'Branch';
      case GeometryPattern.weave:
        return 'Weave';
      case GeometryPattern.glowCore:
        return 'Glow Core';
      case GeometryPattern.fractal:
        return 'Fractal';
    }
  }
  
  String get description {
    switch (this) {
      case GeometryPattern.spiral:
        return 'Nodes arranged in a spiral pattern';
      case GeometryPattern.flower:
        return 'Nodes arranged like petals of a flower';
      case GeometryPattern.branch:
        return 'Nodes arranged in branching patterns';
      case GeometryPattern.weave:
        return 'Nodes arranged in interconnected weave';
      case GeometryPattern.glowCore:
        return 'Nodes arranged around a central core';
      case GeometryPattern.fractal:
        return 'Nodes arranged in fractal patterns';
    }
  }
}
