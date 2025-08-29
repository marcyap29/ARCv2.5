import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

/// State for ARC MVP functionality
abstract class ArcformMVPState extends Equatable {
  const ArcformMVPState();

  @override
  List<Object?> get props => [];
}

class ArcformMVPInitial extends ArcformMVPState {
  const ArcformMVPInitial();
}

class ArcformMVPLoading extends ArcformMVPState {
  const ArcformMVPLoading();
}

class ArcformMVPLoaded extends ArcformMVPState {
  final List<Map<String, dynamic>> snapshots;
  final String selectedGeometry;
  final bool hasRecentEntry;

  const ArcformMVPLoaded({
    required this.snapshots,
    required this.selectedGeometry,
    required this.hasRecentEntry,
  });

  @override
  List<Object?> get props => [snapshots, selectedGeometry, hasRecentEntry];
}

class ArcformMVPError extends ArcformMVPState {
  final String message;

  const ArcformMVPError(this.message);

  @override
  List<Object?> get props => [message];
}

/// Cubit for managing ARC MVP functionality
class ArcformMVPCubit extends Cubit<ArcformMVPState> {
  static const String _snapshotBoxName = 'arcform_snapshots';
  
  ArcformMVPCubit() : super(const ArcformMVPInitial());

  /// Initialize the ARC MVP system
  Future<void> initialize() async {
    emit(const ArcformMVPLoading());
    
    try {
      // Load existing snapshots
      final snapshots = await _loadSnapshots();
      
      // Check if there are recent entries
      final hasRecentEntry = await _checkForRecentEntries();
      
      emit(ArcformMVPLoaded(
        snapshots: snapshots,
        selectedGeometry: 'spiral',
        hasRecentEntry: hasRecentEntry,
      ));
    } catch (e) {
      emit(ArcformMVPError('Failed to initialize ARC MVP: $e'));
    }
  }

  /// Create an Arcform from journal entry data
  Future<void> createArcformFromEntry({
    required String entryId,
    required String title,
    required String content,
    required String mood,
    required List<String> keywords,
  }) async {
    try {
      // Determine geometry pattern
      final geometry = _determineGeometry(content, keywords);
      
      // Generate color map
      final colorMap = _generateColorMap(keywords);
      
      // Generate edges
      final edges = _generateEdges(keywords);
      
      // Create snapshot data
      final snapshotData = {
        'id': const Uuid().v4(),
        'entryId': entryId,
        'title': title,
        'content': content,
        'mood': mood,
        'keywords': keywords,
        'geometry': geometry,
        'colorMap': colorMap,
        'edges': edges,
        'phaseHint': _determinePhaseHint(content, keywords),
        'createdAt': DateTime.now().toIso8601String(),
      };
      
      // Save to Hive
      await _saveSnapshot(snapshotData);
      
      // Reload state
      await initialize();
    } catch (e) {
      emit(ArcformMVPError('Failed to create Arcform: $e'));
    }
  }

  /// Change the selected geometry pattern
  void changeGeometry(String geometry) {
    if (state is ArcformMVPLoaded) {
      final currentState = state as ArcformMVPLoaded;
      emit(currentState.copyWith(selectedGeometry: geometry));
    }
  }

  /// Load snapshots from Hive
  Future<List<Map<String, dynamic>>> _loadSnapshots() async {
    try {
      final box = await Hive.openBox(_snapshotBoxName);
      final snapshots = <Map<String, dynamic>>[];
      
      for (final key in box.keys) {
        final snapshot = box.get(key);
        if (snapshot is Map) {
          snapshots.add(Map<String, dynamic>.from(snapshot));
        }
      }
      
      // Sort by creation date (newest first)
      snapshots.sort((a, b) {
        final aDate = DateTime.tryParse(a['createdAt'] ?? '') ?? DateTime.now();
        final bDate = DateTime.tryParse(b['createdAt'] ?? '') ?? DateTime.now();
        return bDate.compareTo(aDate);
      });
      
      return snapshots;
    } catch (e) {
      return [];
    }
  }

  /// Check for recent journal entries
  Future<bool> _checkForRecentEntries() async {
    try {
      final journalBox = await Hive.openBox('journal_entries');
      return journalBox.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  /// Save snapshot to Hive
  Future<void> _saveSnapshot(Map<String, dynamic> snapshotData) async {
    final box = await Hive.openBox(_snapshotBoxName);
    await box.put(snapshotData['id'], snapshotData);
  }

  /// Determine geometry pattern based on content and keywords
  String _determineGeometry(String content, List<String> keywords) {
    final contentLength = content.length;
    final keywordCount = keywords.length;
    
    if (contentLength > 500 && keywordCount > 7) {
      return 'fractal';
    } else if (contentLength > 300 && keywordCount > 5) {
      return 'branch';
    } else if (keywordCount > 3) {
      return 'flower';
    } else {
      return 'spiral';
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
}

/// Extension for ArcformMVPLoaded state
extension ArcformMVPLoadedExtension on ArcformMVPLoaded {
  ArcformMVPLoaded copyWith({
    List<Map<String, dynamic>>? snapshots,
    String? selectedGeometry,
    bool? hasRecentEntry,
  }) {
    return ArcformMVPLoaded(
      snapshots: snapshots ?? this.snapshots,
      selectedGeometry: selectedGeometry ?? this.selectedGeometry,
      hasRecentEntry: hasRecentEntry ?? this.hasRecentEntry,
    );
  }
}
