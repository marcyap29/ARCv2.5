
/// Simple ARC MVP Implementation
/// This file provides the core functionality for creating and managing Arcforms
/// without complex dependencies that might cause import issues.
library;

/// Geometry patterns for Arcform visualization
enum ArcformGeometry {
  spiral,
  flower,
  branch,
  weave,
  glowCore,
  fractal,
}

/// Extension for geometry pattern utilities
extension ArcformGeometryExtension on ArcformGeometry {
  String get name {
    switch (this) {
      case ArcformGeometry.spiral:
        return 'Discovery';
      case ArcformGeometry.flower:
        return 'Expansion';
      case ArcformGeometry.branch:
        return 'Transition';
      case ArcformGeometry.weave:
        return 'Consolidation';
      case ArcformGeometry.glowCore:
        return 'Recovery';
      case ArcformGeometry.fractal:
        return 'Breakthrough';
    }
  }
  
  String get description {
    switch (this) {
      case ArcformGeometry.spiral:
        return 'Exploring new insights and beginnings';
      case ArcformGeometry.flower:
        return 'Expanding awareness and growth';
      case ArcformGeometry.branch:
        return 'Navigating transitions and choices';
      case ArcformGeometry.weave:
        return 'Integrating experiences and wisdom';
      case ArcformGeometry.glowCore:
        return 'Healing and restoring balance';
      case ArcformGeometry.fractal:
        return 'Breaking through to new levels';
    }
  }
}

/// Simple Arcform data structure
class SimpleArcform {
  final String id;
  final String title;
  final String content;
  final String mood;
  final List<String> keywords;
  final ArcformGeometry geometry;
  final Map<String, String> colorMap;
  final List<List<dynamic>> edges;
  final String phaseHint;
  final DateTime createdAt;
  final bool isGeometryAuto; // New field for Prompt 23

  SimpleArcform({
    required this.id,
    required this.title,
    required this.content,
    required this.mood,
    required this.keywords,
    required this.geometry,
    required this.colorMap,
    required this.edges,
    required this.phaseHint,
    required this.createdAt,
    this.isGeometryAuto = true, // Default to auto-detected
  });

  /// Create from journal entry data with auto-detected geometry
  factory SimpleArcform.fromJournalEntry({
    required String entryId,
    required String title,
    required String content,
    required String mood,
    required List<String> keywords,
  }) {
    final geometry = _determineGeometry(content, keywords);
    final colorMap = _generateColorMap(keywords);
    final edges = _generateEdges(keywords);
    final phaseHint = _determinePhaseHint(content, keywords);

    return SimpleArcform(
      id: entryId,
      title: title,
      content: content,
      mood: mood,
      keywords: keywords,
      geometry: geometry,
      colorMap: colorMap,
      edges: edges,
      phaseHint: phaseHint,
      createdAt: DateTime.now(),
      isGeometryAuto: true, // Auto-detected
    );
  }

  /// Create from journal entry data with manual geometry override
  factory SimpleArcform.fromJournalEntryWithManualGeometry({
    required String entryId,
    required String title,
    required String content,
    required String mood,
    required List<String> keywords,
    required ArcformGeometry manualGeometry,
  }) {
    final colorMap = _generateColorMap(keywords);
    final edges = _generateEdges(keywords);
    final phaseHint = _determinePhaseHint(content, keywords);

    return SimpleArcform(
      id: entryId,
      title: title,
      content: content,
      mood: mood,
      keywords: keywords,
      geometry: manualGeometry,
      colorMap: colorMap,
      edges: edges,
      phaseHint: phaseHint,
      createdAt: DateTime.now(),
      isGeometryAuto: false, // Manually selected
    );
  }

  /// Convert to JSON for storage
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'mood': mood,
      'keywords': keywords,
      'geometry': geometry.name,
      'colorMap': colorMap,
      'edges': edges,
      'phaseHint': phaseHint,
      'createdAt': createdAt.toIso8601String(),
      'isGeometryAuto': isGeometryAuto,
    };
  }

  /// Create from JSON
  factory SimpleArcform.fromJson(Map<String, dynamic> json) {
    return SimpleArcform(
      id: json['id'] as String,
      title: json['title'] as String,
      content: json['content'] as String,
      mood: json['mood'] as String,
      keywords: List<String>.from(json['keywords'] as List),
      geometry: _geometryFromString(json['geometry'] as String),
      colorMap: Map<String, String>.from(json['colorMap'] as Map),
      edges: List<List<dynamic>>.from(json['edges'] as List),
      phaseHint: json['phaseHint'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      isGeometryAuto: json['isGeometryAuto'] as bool? ?? true,
    );
  }

  /// Copy with new geometry (for manual override)
  SimpleArcform copyWithGeometry(ArcformGeometry newGeometry) {
    return SimpleArcform(
      id: id,
      title: title,
      content: content,
      mood: mood,
      keywords: keywords,
      geometry: newGeometry,
      colorMap: colorMap,
      edges: edges,
      phaseHint: phaseHint,
      createdAt: createdAt,
      isGeometryAuto: false, // Mark as manually overridden
    );
  }
}

/// ARC MVP Service - Core functionality for creating and managing Arcforms
class ArcformMVPService {
  static final ArcformMVPService _instance = ArcformMVPService._internal();
  factory ArcformMVPService() => _instance;
  ArcformMVPService._internal();

  /// Create an Arcform from journal entry data
  SimpleArcform createArcformFromEntry({
    required String entryId,
    required String title,
    required String content,
    required String mood,
    required List<String> keywords,
  }) {
    return SimpleArcform.fromJournalEntry(
      entryId: entryId,
      title: title,
      content: content,
      mood: mood,
      keywords: keywords,
    );
  }

  /// Create an Arcform from journal entry data with explicit phase
  SimpleArcform createArcformFromEntryWithPhase({
    required String entryId,
    required String title,
    required String content,
    required String mood,
    required List<String> keywords,
    required String phase,
    required bool userConsentedPhase,
  }) {
    // Map phase to geometry
    final geometry = _phaseToGeometry(phase);
    final colorMap = _generateColorMap(keywords);
    final edges = _generateEdges(keywords);
    final phaseHint = phase; // Use the actual phase name as hint

    return SimpleArcform(
      id: entryId,
      title: title,
      content: content,
      mood: mood,
      keywords: keywords,
      geometry: geometry,
      colorMap: colorMap,
      edges: edges,
      phaseHint: phaseHint,
      createdAt: DateTime.now(),
      isGeometryAuto: !userConsentedPhase, // Auto if not user-consented
    );
  }

  /// Create an Arcform from journal entry data with explicit phase and manual geometry override
  SimpleArcform createArcformFromEntryWithPhaseAndGeometry({
    required String entryId,
    required String title,
    required String content,
    required String mood,
    required List<String> keywords,
    required String phase,
    required ArcformGeometry overrideGeometry,
    required bool userConsentedPhase,
  }) {
    final colorMap = _generateColorMap(keywords);
    final edges = _generateEdges(keywords);
    final phaseHint = phase; // Use the actual phase name as hint

    return SimpleArcform(
      id: entryId,
      title: title,
      content: content,
      mood: mood,
      keywords: keywords,
      geometry: overrideGeometry, // Use the manually selected geometry
      colorMap: colorMap,
      edges: edges,
      phaseHint: phaseHint,
      createdAt: DateTime.now(),
      isGeometryAuto: false, // Mark as manually overridden
    );
  }

  /// Generate demo Arcform data
  SimpleArcform createDemoArcform() {
    return SimpleArcform.fromJournalEntry(
      entryId: 'demo_${DateTime.now().millisecondsSinceEpoch}',
      title: 'Demo Reflection',
      content: 'This is a sample journal entry to demonstrate the ARC MVP functionality. It shows how keywords are extracted and visualized as meaningful patterns.',
      mood: 'reflective',
      keywords: ['reflection', 'growth', 'awareness', 'insight', 'journey', 'transformation'],
    );
  }
}

/// Utility functions for Arcform creation

/// Map ATLAS phase to geometry
ArcformGeometry _phaseToGeometry(String phase) {
  switch (phase) {
    case 'Discovery':
      return ArcformGeometry.spiral;
    case 'Expansion':
      return ArcformGeometry.flower;
    case 'Transition':
      return ArcformGeometry.branch;
    case 'Consolidation':
      return ArcformGeometry.weave;
    case 'Recovery':
      return ArcformGeometry.glowCore;
    case 'Breakthrough':
      return ArcformGeometry.fractal;
    default:
      return ArcformGeometry.spiral; // Default to Discovery
  }
}

/// Determine geometry pattern based on content and keywords
ArcformGeometry _determineGeometry(String content, List<String> keywords) {
  final contentLength = content.length;
  final keywordCount = keywords.length;
  
  if (contentLength > 500 && keywordCount > 7) {
    return ArcformGeometry.fractal;
  } else if (contentLength > 300 && keywordCount > 5) {
    return ArcformGeometry.branch;
  } else if (keywordCount > 3) {
    return ArcformGeometry.flower;
  } else {
    return ArcformGeometry.spiral;
  }
}

/// Generate color map for keywords
Map<String, String> _generateColorMap(List<String> keywords) {
  final colors = [
    '#4F46E5', // Primary blue
    '#7C3AED', // Purple
    '#D1B3FF', // Light purple
    '#6BE3A0', // Green
    '#F7D774', // Yellow
    '#FF6B6B', // Red
    '#FF8E53', // Orange
    '#4ECDC4', // Teal
  ];
  
  final colorMap = <String, String>{};
  for (int i = 0; i < keywords.length; i++) {
    colorMap[keywords[i]] = colors[i % colors.length];
  }
  
  return colorMap;
}

/// Generate edges between keywords
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

/// Determine ATLAS phase hint
String _determinePhaseHint(String content, List<String> keywords) {
  final lowerContent = content.toLowerCase();
  
  if (lowerContent.contains('growth') || lowerContent.contains('learn') || lowerContent.contains('improve')) {
    return 'Discovery';
  } else if (lowerContent.contains('challenge') || lowerContent.contains('struggle') || lowerContent.contains('difficult')) {
    return 'Integration';
  } else if (lowerContent.contains('gratitude') || lowerContent.contains('appreciate') || lowerContent.contains('blessed')) {
    return 'Transcendence';
  } else {
    return 'Discovery';
  }
}

/// Convert geometry string to enum
ArcformGeometry _geometryFromString(String geometry) {
  switch (geometry.toLowerCase()) {
    case 'spiral':
      return ArcformGeometry.spiral;
    case 'flower':
      return ArcformGeometry.flower;
    case 'branch':
      return ArcformGeometry.branch;
    case 'weave':
      return ArcformGeometry.weave;
    case 'glowcore':
      return ArcformGeometry.glowCore;
    case 'fractal':
      return ArcformGeometry.fractal;
    default:
      return ArcformGeometry.spiral;
  }
}

/// Simple storage simulation (replace with actual Hive implementation)
class SimpleArcformStorage {
  static final Map<String, SimpleArcform> _storage = {};
  
  /// Save Arcform
  static void saveArcform(SimpleArcform arcform) {
    _storage[arcform.id] = arcform;
  }
  
  /// Load Arcform by ID
  static SimpleArcform? loadArcform(String id) {
    return _storage[id];
  }
  
  /// Load all Arcforms
  static List<SimpleArcform> loadAllArcforms() {
    return _storage.values.toList();
  }
  
  /// Delete Arcform
  static void deleteArcform(String id) {
    _storage.remove(id);
  }
  
  /// Clear all data
  static void clear() {
    _storage.clear();
  }
}

/// Usage Example:
/// 
/// ```dart
/// // Create ARC MVP service
/// final arcformService = ArcformMVPService();
/// 
/// // Extract keywords from journal entry using EnhancedKeywordExtractor
/// import 'package:my_app/prism/extractors/enhanced_keyword_extractor.dart';
/// import 'package:my_app/arc/ui/arcforms/phase_recommender.dart';
/// 
/// final currentPhase = PhaseRecommender.recommend(
///   emotion: '',
///   reason: '',
///   text: journalText,
/// );
/// final response = EnhancedKeywordExtractor.extractKeywords(
///   entryText: journalText,
///   currentPhase: currentPhase,
/// );
/// final keywords = response.chips.isNotEmpty 
///     ? response.chips 
///     : response.candidates.take(10).map((c) => c.keyword).toList();
/// 
/// // Create Arcform
/// final arcform = arcformService.createArcformFromEntry(
///   entryId: 'entry_123',
///   title: 'My Reflection',
///   content: journalText,
///   mood: 'calm',
///   keywords: keywords,
/// );
/// 
/// // Save to storage
/// SimpleArcformStorage.saveArcform(arcform);
/// 
/// // Load all Arcforms
/// final allArcforms = SimpleArcformStorage.loadAllArcforms();
/// ```
