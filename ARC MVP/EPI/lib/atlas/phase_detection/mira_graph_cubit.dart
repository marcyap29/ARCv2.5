import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../arc/core/journal_repository.dart';
import '../../arc/models/journal_entry_model.dart';

/// State for MIRA graph visualization
abstract class MiraGraphState extends Equatable {
  const MiraGraphState();

  @override
  List<Object?> get props => [];
}

class MiraGraphInitial extends MiraGraphState {}

class MiraGraphLoading extends MiraGraphState {}

class MiraGraphLoaded extends MiraGraphState {
  final List<MiraGraphNode> nodes;
  final List<MiraGraphEdge> edges;
  final Map<String, List<JournalEntry>> keywordToEntries;

  const MiraGraphLoaded({
    required this.nodes,
    required this.edges,
    required this.keywordToEntries,
  });

  @override
  List<Object?> get props => [nodes, edges, keywordToEntries];
}

class MiraGraphError extends MiraGraphState {
  final String message;

  const MiraGraphError(this.message);

  @override
  List<Object?> get props => [message];
}

/// A node in the MIRA graph visualization
class MiraGraphNode {
  final String id;
  final String label;
  final int frequency;
  final double size;
  final Offset position;
  final Color color;

  const MiraGraphNode({
    required this.id,
    required this.label,
    required this.frequency,
    required this.size,
    required this.position,
    required this.color,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MiraGraphNode &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}

/// An edge in the MIRA graph visualization
class MiraGraphEdge {
  final String fromNodeId;
  final String toNodeId;
  final int cooccurrenceCount;
  final double thickness;
  final Color color;

  const MiraGraphEdge({
    required this.fromNodeId,
    required this.toNodeId,
    required this.cooccurrenceCount,
    required this.thickness,
    required this.color,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MiraGraphEdge &&
          runtimeType == other.runtimeType &&
          fromNodeId == other.fromNodeId &&
          toNodeId == other.toNodeId;

  @override
  int get hashCode => fromNodeId.hashCode ^ toNodeId.hashCode;
}

/// Cubit for managing MIRA graph state and data
class MiraGraphCubit extends Cubit<MiraGraphState> {
  final JournalRepository _journalRepository;
  final int _maxNodes;
  final int _minCooccurrence;

  MiraGraphCubit({
    JournalRepository? journalRepository,
    int maxNodes = 25,
    int minCooccurrence = 2,
  }) : _journalRepository = journalRepository ?? JournalRepository(),
       _maxNodes = maxNodes,
       _minCooccurrence = minCooccurrence,
       super(MiraGraphInitial());

  /// Load graph data from journal entries
  Future<void> loadGraph() async {
    emit(MiraGraphLoading());

    try {
      final entries = _journalRepository.getAllJournalEntriesSync();
      print('DEBUG: MIRA Graph - Found ${entries.length} journal entries');
      
      if (entries.isEmpty) {
        print('DEBUG: MIRA Graph - No entries found, showing empty state');
        emit(const MiraGraphLoaded(
          nodes: [],
          edges: [],
          keywordToEntries: {},
        ));
        return;
      }

      // Extract keywords and compute frequencies
      final keywordFrequencies = <String, int>{};
      final keywordToEntries = <String, List<JournalEntry>>{};

      for (final entry in entries) {
        for (final keyword in entry.keywords) {
          if (keyword.isNotEmpty) {
            keywordFrequencies[keyword] = (keywordFrequencies[keyword] ?? 0) + 1;
            keywordToEntries.putIfAbsent(keyword, () => []).add(entry);
          }
        }
      }

      // Get top keywords
      final sortedKeywords = keywordFrequencies.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      
      print('DEBUG: MIRA Graph - Found ${keywordFrequencies.length} unique keywords');
      print('DEBUG: MIRA Graph - Top keywords: ${sortedKeywords.take(5).map((e) => '${e.key}:${e.value}').join(', ')}');
      
      final topKeywords = sortedKeywords.take(_maxNodes).toList();

      if (topKeywords.isEmpty) {
        print('DEBUG: MIRA Graph - No keywords found, showing empty state');
        emit(const MiraGraphLoaded(
          nodes: [],
          edges: [],
          keywordToEntries: {},
        ));
        return;
      }

      // Create nodes
      final nodes = <MiraGraphNode>[];
      final keywordIds = <String>[];
      
      for (int i = 0; i < topKeywords.length; i++) {
        final keyword = topKeywords[i];
        final frequency = keyword.value;
        
        // Calculate position in concentric circles
        final radius = _calculateRadius(i, topKeywords.length);
        final angle = _calculateAngle(i, topKeywords.length);
        final position = Offset(
          radius * math.cos(angle),
          radius * math.sin(angle),
        );

        // Calculate node size based on frequency
        final maxFreq = topKeywords.first.value;
        final minFreq = topKeywords.last.value;
        final normalizedFreq = maxFreq > minFreq 
            ? (frequency - minFreq) / (maxFreq - minFreq)
            : 1.0;
        final size = 20.0 + (normalizedFreq * 30.0); // 20-50px range

        // Calculate color based on frequency
        final color = _calculateNodeColor(normalizedFreq);

        final node = MiraGraphNode(
          id: keyword.key,
          label: keyword.key,
          frequency: frequency,
          size: size,
          position: position,
          color: color,
        );

        nodes.add(node);
        keywordIds.add(keyword.key);
      }

      // Create edges based on co-occurrence
      final edges = <MiraGraphEdge>[];
      final cooccurrenceMatrix = <String, Map<String, int>>{};

      for (final entry in entries) {
        final entryKeywords = entry.keywords.where((k) => keywordIds.contains(k)).toList();
        
        for (int i = 0; i < entryKeywords.length; i++) {
          for (int j = i + 1; j < entryKeywords.length; j++) {
            final keyword1 = entryKeywords[i];
            final keyword2 = entryKeywords[j];
            
            cooccurrenceMatrix.putIfAbsent(keyword1, () => {});
            cooccurrenceMatrix[keyword1]![keyword2] = 
                (cooccurrenceMatrix[keyword1]![keyword2] ?? 0) + 1;
            
            cooccurrenceMatrix.putIfAbsent(keyword2, () => {});
            cooccurrenceMatrix[keyword2]![keyword1] = 
                (cooccurrenceMatrix[keyword2]![keyword1] ?? 0) + 1;
          }
        }
      }

      // Create edges for significant co-occurrences
      for (final keyword1 in keywordIds) {
        final cooccurrences = cooccurrenceMatrix[keyword1] ?? {};
        for (final keyword2 in cooccurrences.keys) {
          final count = cooccurrences[keyword2]!;
          if (count >= _minCooccurrence) {
            final thickness = math.min(5.0, 1.0 + (count * 0.5));
            final edge = MiraGraphEdge(
              fromNodeId: keyword1,
              toNodeId: keyword2,
              cooccurrenceCount: count,
              thickness: thickness,
              color: const Color(0xFF4F46E5).withOpacity(0.6),
            );
            edges.add(edge);
          }
        }
      }

      emit(MiraGraphLoaded(
        nodes: nodes,
        edges: edges,
        keywordToEntries: keywordToEntries,
      ));

    } catch (e) {
      emit(MiraGraphError('Failed to load graph: $e'));
    }
  }

  /// Calculate radius for node positioning
  double _calculateRadius(int index, int totalNodes) {
    if (totalNodes <= 1) return 0.0;
    
    // Use concentric circles based on frequency rank
    if (index < 5) return 80.0; // Inner circle
    if (index < 15) return 140.0; // Middle circle
    return 200.0; // Outer circle
  }

  /// Calculate angle for node positioning
  double _calculateAngle(int index, int totalNodes) {
    if (totalNodes <= 1) return 0.0;
    
    // Distribute nodes evenly around the circle
    return (2 * math.pi * index) / totalNodes;
  }

  /// Calculate node color based on frequency
  Color _calculateNodeColor(double normalizedFrequency) {
    // Use a gradient from cool to warm colors based on frequency
    if (normalizedFrequency < 0.33) {
      return const Color(0xFF4F46E5).withOpacity(0.7); // Cool blue
    } else if (normalizedFrequency < 0.66) {
      return const Color(0xFF7C3AED).withOpacity(0.8); // Purple
    } else {
      return const Color(0xFFD1B3FF).withOpacity(0.9); // Warm accent
    }
  }

  /// Get entries for a specific keyword
  List<JournalEntry> getEntriesForKeyword(String keyword) {
    final state = this.state;
    if (state is MiraGraphLoaded) {
      return state.keywordToEntries[keyword] ?? [];
    }
    return [];
  }

  /// Get entries that contain both keywords (for edge interactions)
  List<JournalEntry> getEntriesForEdge(String keyword1, String keyword2) {
    final entries1 = getEntriesForKeyword(keyword1);
    final entries2 = getEntriesForKeyword(keyword2);
    
    // Find intersection
    final ids1 = entries1.map((e) => e.id).toSet();
    return entries2.where((e) => ids1.contains(e.id)).toList();
  }
}
