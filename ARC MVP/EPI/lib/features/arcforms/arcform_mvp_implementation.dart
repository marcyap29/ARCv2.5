import 'package:flutter/material.dart';

/// Simple ARC MVP Implementation
/// This file provides the core functionality for creating and managing Arcforms
/// without complex dependencies that might cause import issues.

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
        return 'Spiral';
      case ArcformGeometry.flower:
        return 'Flower';
      case ArcformGeometry.branch:
        return 'Branch';
      case ArcformGeometry.weave:
        return 'Weave';
      case ArcformGeometry.glowCore:
        return 'Glow Core';
      case ArcformGeometry.fractal:
        return 'Fractal';
    }
  }
  
  String get description {
    switch (this) {
      case ArcformGeometry.spiral:
        return 'Nodes arranged in a spiral pattern';
      case ArcformGeometry.flower:
        return 'Nodes arranged like petals of a flower';
      case ArcformGeometry.branch:
        return 'Nodes arranged in branching patterns';
      case ArcformGeometry.weave:
        return 'Nodes arranged in interconnected weave';
      case ArcformGeometry.glowCore:
        return 'Nodes arranged around a central core';
      case ArcformGeometry.fractal:
        return 'Nodes arranged in fractal patterns';
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
  });

  /// Create from journal entry data
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

/// Simple keyword extraction utility
class SimpleKeywordExtractor {
  /// Extract keywords from text
  static List<String> extractKeywords(String text) {
    final words = text
        .split(RegExp(r'\s+'))
        .where((word) {
          // Filter out common words and keep only words with 3+ characters
          final commonWords = {
            'the', 'and', 'or', 'but', 'in', 'on', 'at', 'to', 'for', 'of',
            'with', 'by', 'a', 'an', 'is', 'are', 'was', 'were', 'this', 'that',
            'have', 'has', 'had', 'will', 'would', 'could', 'should', 'may',
            'might', 'can', 'do', 'does', 'did', 'get', 'gets', 'got', 'go',
            'goes', 'went', 'gone', 'see', 'sees', 'saw', 'seen', 'know',
            'knows', 'knew', 'known', 'think', 'thinks', 'thought', 'feel',
            'feels', 'felt', 'want', 'wants', 'wanted', 'need', 'needs',
            'needed', 'like', 'likes', 'liked', 'love', 'loves', 'loved'
          };
          return word.length >= 3 && !commonWords.contains(word.toLowerCase());
        })
        .map((word) => word.toLowerCase().replaceAll(RegExp(r'[^\w]'), ''))
        .toSet()
        .toList();

    // Take first 10 unique words as suggested keywords
    return words.take(10).toList();
  }
}

/// Usage Example:
/// 
/// ```dart
/// // Create ARC MVP service
/// final arcformService = ArcformMVPService();
/// 
/// // Extract keywords from journal entry
/// final keywords = SimpleKeywordExtractor.extractKeywords(journalText);
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
