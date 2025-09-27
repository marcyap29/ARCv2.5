// lib/features/insights/pattern_analysis_service.dart
// Service to analyze real journal data for patterns visualization
// Replaces hardcoded mock data with actual keyword analysis

import 'dart:math';
import 'package:my_app/arc/core/journal_repository.dart';
import 'package:my_app/models/journal_entry_model.dart';
import 'package:my_app/atlas/phase_detection/your_patterns_view.dart';

/// Service for analyzing journal patterns from real data
class PatternAnalysisService {
  final JournalRepository _journalRepository;

  PatternAnalysisService(this._journalRepository);

  /// MINIMAL VIABLE FUNCTION - Count keywords, analyze emotions, return nodes
  (List<KeywordNode>, List<KeywordEdge>) analyzePatterns({
    double minWeight = 0.1,
    int maxNodes = 8,
  }) {
    print('DEBUG: PatternAnalysisService - Starting minimal analysis');
    
    final entries = _journalRepository.getAllJournalEntries();
    print('DEBUG: Found ${entries.length} journal entries');

    if (entries.isEmpty) {
      print('DEBUG: No entries, returning test data');
      return _createTestPatternData();
    }

    // STEP 1: Simple keyword counting
    final keywordCounts = _countKeywords(entries);
    print('DEBUG: Found ${keywordCounts.length} unique keywords');

    // STEP 2: Get top keywords
    final sortedKeywords = keywordCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topKeywords = sortedKeywords.take(maxNodes).map((e) => e.key).toList();

    // STEP 3: Analyze emotions for these keywords
    final keywordEmotions = _analyzeKeywordEmotions(entries, topKeywords);
    print('DEBUG: Analyzed emotions for ${keywordEmotions.length} keywords');

    // STEP 4: Analyze phases for these keywords
    final keywordPhases = _analyzeKeywordPhases(entries, topKeywords);
    print('DEBUG: Analyzed phases for ${keywordPhases.length} keywords');

    // STEP 5: Create enhanced nodes with emotions and phases
    final nodes = _createEnhancedNodes(keywordCounts, keywordEmotions, keywordPhases, maxNodes);
    print('DEBUG: Created ${nodes.length} enhanced nodes');

    // STEP 6: Analyze co-occurrence edges
    final edges = _analyzeCoOccurrenceEdges(entries, nodes, minWeight);
    print('DEBUG: Created ${edges.length} co-occurrence edges');

    return (nodes, edges);
  }

  /// STEP 1: Count keyword frequencies
  Map<String, int> _countKeywords(List<JournalEntry> entries) {
    final counts = <String, int>{};
    
    for (final entry in entries) {
      for (final keyword in entry.keywords) {
        counts[keyword] = (counts[keyword] ?? 0) + 1;
      }
    }
    
    return counts;
  }

  /// STEP 2: Create basic KeywordNode objects from counts (DEPRECATED - use _createEnhancedNodes)
  List<KeywordNode> _createBasicNodes(Map<String, int> keywordCounts, int maxNodes) {
    final nodes = <KeywordNode>[];
    
    // Sort by frequency and take top keywords
    final sortedKeywords = keywordCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    final topKeywords = sortedKeywords.take(maxNodes).toList();
    
    for (int i = 0; i < topKeywords.length; i++) {
      final entry = topKeywords[i];
      final keyword = entry.key;
      final frequency = entry.value;
      
      // Create simple time series (just frequency repeated)
      final series = List<double>.filled(5, frequency.toDouble());
      
      final node = KeywordNode(
        id: keyword,
        label: keyword,
        frequency: frequency, // Keep as int
        recencyScore: 1.0,
        emotion: 'neutral', // Will be improved in next step
        phase: 'Discovery', // Will be improved in next step
        excerpts: ['Keyword: $keyword'],
        series: series.map((e) => e.round()).toList(), // Convert double to int
      );
      
      nodes.add(node);
      print('DEBUG: Created node for "$keyword" with frequency $frequency');
    }
    
    return nodes;
  }

  /// STEP 5: Create enhanced KeywordNode objects with emotions and phases
  List<KeywordNode> _createEnhancedNodes(
    Map<String, int> keywordCounts, 
    Map<String, String> keywordEmotions,
    Map<String, String> keywordPhases,
    int maxNodes
  ) {
    final nodes = <KeywordNode>[];
    
    // Sort by frequency and take top keywords
    final sortedKeywords = keywordCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    final topKeywords = sortedKeywords.take(maxNodes).toList();
    
    for (int i = 0; i < topKeywords.length; i++) {
      final entry = topKeywords[i];
      final keyword = entry.key;
      final frequency = entry.value;
      final emotion = keywordEmotions[keyword] ?? 'neutral';
      final phase = keywordPhases[keyword] ?? 'Discovery';
      
      // Create simple time series (just frequency repeated)
      final series = List<double>.filled(5, frequency.toDouble());
      
      final node = KeywordNode(
        id: keyword,
        label: keyword,
        frequency: frequency,
        recencyScore: 1.0,
        emotion: emotion, // Now using analyzed emotion
        phase: phase, // Now using analyzed phase
        excerpts: ['Keyword: $keyword'],
        series: series.map((e) => e.round()).toList(), // Convert double to int
      );
      
      nodes.add(node);
      print('DEBUG: Created enhanced node for "$keyword" with frequency $frequency, emotion: $emotion, phase: $phase');
    }
    
    return nodes;
  }

  /// STEP 3: Analyze emotions for keywords
  Map<String, String> _analyzeKeywordEmotions(List<JournalEntry> entries, List<String> keywords) {
    final keywordEmotions = <String, Map<String, int>>{};
    
    // Initialize emotion counts for each keyword
    for (final keyword in keywords) {
      keywordEmotions[keyword] = {
        'positive': 0,
        'negative': 0,
        'reflective': 0,
        'neutral': 0,
      };
    }
    
    // Count emotions for each keyword
    for (final entry in entries) {
      if (entry.keywords.isEmpty) continue;
      
      final emotion = _inferEmotion(entry);
      
      for (final keyword in entry.keywords) {
        if (keywordEmotions.containsKey(keyword)) {
          keywordEmotions[keyword]![emotion] = (keywordEmotions[keyword]![emotion] ?? 0) + 1;
        }
      }
    }
    
    // Find dominant emotion for each keyword
    final result = <String, String>{};
    for (final entry in keywordEmotions.entries) {
      final keyword = entry.key;
      final emotions = entry.value;
      
      // Find emotion with highest count
      String dominantEmotion = 'neutral';
      int maxCount = 0;
      
      for (final emotionEntry in emotions.entries) {
        if (emotionEntry.value > maxCount) {
          maxCount = emotionEntry.value;
          dominantEmotion = emotionEntry.key;
        }
      }
      
      result[keyword] = dominantEmotion;
      print('DEBUG: Keyword "$keyword" -> emotion: $dominantEmotion (count: $maxCount)');
    }
    
    return result;
  }

  /// STEP 4: Analyze phases for keywords
  Map<String, String> _analyzeKeywordPhases(List<JournalEntry> entries, List<String> keywords) {
    final keywordPhases = <String, Map<String, int>>{};
    
    // Initialize phase counts for each keyword
    for (final keyword in keywords) {
      keywordPhases[keyword] = {
        'Discovery': 0,
        'Expansion': 0,
        'Transition': 0,
        'Consolidation': 0,
        'Recovery': 0,
        'Breakthrough': 0,
      };
    }
    
    // Count phases for each keyword
    for (final entry in entries) {
      if (entry.keywords.isEmpty) continue;
      
      final phase = _inferPhase(entry);
      
      for (final keyword in entry.keywords) {
        if (keywordPhases.containsKey(keyword)) {
          keywordPhases[keyword]![phase] = (keywordPhases[keyword]![phase] ?? 0) + 1;
        }
      }
    }
    
    // Find dominant phase for each keyword
    final result = <String, String>{};
    for (final entry in keywordPhases.entries) {
      final keyword = entry.key;
      final phases = entry.value;
      
      // Find phase with highest count
      String dominantPhase = 'Discovery';
      int maxCount = 0;
      
      for (final phaseEntry in phases.entries) {
        if (phaseEntry.value > maxCount) {
          maxCount = phaseEntry.value;
          dominantPhase = phaseEntry.key;
        }
      }
      
      result[keyword] = dominantPhase;
      print('DEBUG: Keyword "$keyword" -> phase: $dominantPhase (count: $maxCount)');
    }
    
    return result;
  }

  /// Infer phase from journal entry
  String _inferPhase(JournalEntry entry) {
    // Use emotion and content to infer phase
    final emotion = entry.emotion?.toLowerCase() ?? '';
    final content = entry.content.toLowerCase();

    // Phase keyword mapping
    if (content.contains('breakthrough') || content.contains('clarity') ||
        content.contains('insight') || emotion.contains('enlightened')) {
      return 'Breakthrough';
    }
    if (content.contains('healing') || content.contains('rest') ||
        content.contains('recover') || emotion.contains('calm')) {
      return 'Recovery';
    }
    if (content.contains('transition') || content.contains('change') ||
        content.contains('uncertain') || emotion.contains('anxious')) {
      return 'Transition';
    }
    if (content.contains('growing') || content.contains('expanding') ||
        content.contains('confident') || emotion.contains('excited')) {
      return 'Expansion';
    }
    if (content.contains('organizing') || content.contains('stable') ||
        content.contains('routine') || emotion.contains('focused')) {
      return 'Consolidation';
    }

    // Default to Discovery
    return 'Discovery';
  }

  /// Infer emotion category from journal entry
  String _inferEmotion(JournalEntry entry) {
    final emotion = entry.emotion?.toLowerCase() ?? '';
    final content = entry.content.toLowerCase();

    // High amplitude positive emotions
    if (emotion.contains('ecstatic') || emotion.contains('overjoyed') ||
        emotion.contains('excited') || emotion.contains('joyful') ||
        content.contains('amazing') || content.contains('fantastic') ||
        content.contains('wonderful') || content.contains('breakthrough') ||
        content.contains('success') || content.contains('achievement')) {
      return 'positive';
    }

    // Reflective emotions
    if (emotion.contains('thoughtful') || emotion.contains('contemplative') ||
        emotion.contains('reflective') || emotion.contains('pensive') ||
        content.contains('thinking') || content.contains('pondering') ||
        content.contains('realize') || content.contains('understand') ||
        content.contains('clarity') || content.contains('insight')) {
      return 'reflective';
    }

    // Negative emotions
    if (emotion.contains('sad') || emotion.contains('angry') ||
        emotion.contains('frustrated') || emotion.contains('anxious') ||
        content.contains('difficult') || content.contains('struggling') ||
        content.contains('worry') || content.contains('stress')) {
      return 'negative';
    }

    // Default to neutral
    return 'neutral';
  }

  /// STEP 6: Analyze co-occurrence edges between keywords
  List<KeywordEdge> _analyzeCoOccurrenceEdges(
    List<JournalEntry> entries, 
    List<KeywordNode> nodes, 
    double minWeight
  ) {
    final edges = <KeywordEdge>[];
    final nodeIds = nodes.map((n) => n.id).toSet();
    
    // Build co-occurrence matrix
    final coOccurrenceMatrix = <String, Map<String, double>>{};
    
    for (final entry in entries) {
      final keywords = entry.keywords.where((k) => nodeIds.contains(k)).toList();
      
      // Count co-occurrences within each entry
      for (int i = 0; i < keywords.length; i++) {
        for (int j = i + 1; j < keywords.length; j++) {
          final keywordA = keywords[i];
          final keywordB = keywords[j];
          
          coOccurrenceMatrix.putIfAbsent(keywordA, () => {});
          coOccurrenceMatrix.putIfAbsent(keywordB, () => {});
          
          final currentWeight = coOccurrenceMatrix[keywordA]![keywordB] ?? 0.0;
          coOccurrenceMatrix[keywordA]![keywordB] = currentWeight + 1.0;
          coOccurrenceMatrix[keywordB]![keywordA] = currentWeight + 1.0;
        }
      }
    }
    
    // Find maximum co-occurrence for normalization
    double maxCoOccurrence = 0.0;
    for (final connections in coOccurrenceMatrix.values) {
      for (final weight in connections.values) {
        maxCoOccurrence = max(maxCoOccurrence, weight);
      }
    }
    
    if (maxCoOccurrence == 0.0) {
      print('DEBUG: No co-occurrences found');
      return edges;
    }
    
    // Create edges from co-occurrence matrix
    final processedPairs = <String>{};
    
    for (final entry in coOccurrenceMatrix.entries) {
      final keywordA = entry.key;
      for (final connection in entry.value.entries) {
        final keywordB = connection.key;
        final rawWeight = connection.value;
        
        // Avoid duplicate edges
        final pairKey = keywordA.compareTo(keywordB) < 0
          ? '$keywordA-$keywordB'
          : '$keywordB-$keywordA';
        
        if (processedPairs.contains(pairKey)) continue;
        processedPairs.add(pairKey);
        
        // Normalize weight
        final normalizedWeight = rawWeight / maxCoOccurrence;
        
        if (normalizedWeight >= minWeight) {
          edges.add(KeywordEdge(
            a: keywordA,
            b: keywordB,
            weight: normalizedWeight,
          ));
          print('DEBUG: Created edge $keywordA -> $keywordB with weight $normalizedWeight');
        }
      }
    }
    
    return edges;
  }
}

/// Create test pattern data for debugging when no journal entries exist
(List<KeywordNode>, List<KeywordEdge>) _createTestPatternData() {
  print('DEBUG: Creating test pattern data with realistic keywords');

  final testNodes = [
    KeywordNode(
      id: 'breakthrough',
      label: 'breakthrough',
      frequency: 8, // Use int
      recencyScore: 0.9,
      emotion: 'positive',
      phase: 'Breakthrough',
      excerpts: ['Had a major breakthrough in understanding myself', 'Finally broke through that barrier', 'The insight came suddenly'],
      series: [1, 2, 4, 6, 8], // Use int
    ),
    KeywordNode(
      id: 'growth',
      label: 'growth',
      frequency: 6, // Use int
      recencyScore: 0.8,
      emotion: 'positive',
      phase: 'Expansion',
      excerpts: ['Feeling real growth happening', 'Personal growth accelerating'],
      series: [2, 3, 4, 5, 6], // Use int
    ),
    KeywordNode(
      id: 'insight',
      label: 'insight',
      frequency: 5, // Use int
      recencyScore: 0.7,
      emotion: 'reflective',
      phase: 'Discovery',
      excerpts: ['New insight about my patterns', 'Deep insight emerged today'],
      series: [1, 1, 3, 4, 5], // Use int
    ),
  ];

  final testEdges = [
    KeywordEdge(a: 'breakthrough', b: 'clarity', weight: 0.9),
    KeywordEdge(a: 'breakthrough', b: 'insight', weight: 0.7),
    KeywordEdge(a: 'growth', b: 'insight', weight: 0.6),
  ];

  print('DEBUG: Created ${testNodes.length} test nodes and ${testEdges.length} test edges');
  return (testNodes, testEdges);
}