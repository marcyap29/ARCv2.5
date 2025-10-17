import 'dart:convert';
import 'package:hive/hive.dart';

part 'arcform_snapshot.g.dart';

@HiveType(typeId: 17)
class ArcformPhaseSnapshot extends HiveObject {
  @HiveField(0)
  final String phase;
  
  @HiveField(1)
  final String geometryJson; // Store as JSON string, not Map
  
  @HiveField(2)
  final DateTime timestamp;
  
  @HiveField(3)
  final String? description;

  ArcformPhaseSnapshot({
    required this.phase,
    required this.geometryJson,
    required this.timestamp,
    this.description,
  });

  factory ArcformPhaseSnapshot.fromMap(Map<String, dynamic> map) {
    return ArcformPhaseSnapshot(
      phase: map['phase'] as String? ?? 'unknown',
      geometryJson: map['geometry'] is String 
          ? map['geometry'] as String 
          : (map['geometry'] != null ? jsonEncode(map['geometry']) : '{}'),
      timestamp: DateTime.tryParse(map['timestamp'] as String? ?? '') ?? DateTime.now(),
      description: map['description'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'phase': phase,
      'geometry': geometryJson,
      'timestamp': timestamp.toIso8601String(),
      'description': description,
    };
  }

  // Helper to get geometry as Map
  Map<String, dynamic> get geometryMap {
    try {
      return jsonDecode(geometryJson) as Map<String, dynamic>;
    } catch (e) {
      return <String, dynamic>{};
    }
  }

  // Helper to update geometry
  ArcformPhaseSnapshot copyWithGeometry(Map<String, dynamic> newGeometry) {
    return ArcformPhaseSnapshot(
      phase: phase,
      geometryJson: jsonEncode(newGeometry),
      timestamp: timestamp,
      description: description,
    );
  }

  @override
  String toString() {
    return 'ArcformSnapshot(phase: $phase, timestamp: $timestamp, description: $description)';
  }
}
