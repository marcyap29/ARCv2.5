import 'package:my_app/lumara/data/context_scope.dart';
import 'package:my_app/services/user_phase_service.dart';

/// Context window for LUMARA processing
class ContextWindow {
  final List<Map<String, dynamic>> nodes;
  final List<Map<String, dynamic>> edges;
  final int totalEntries;
  final int totalArcforms;
  final DateTime startDate;
  final DateTime endDate;
  
  const ContextWindow({
    required this.nodes,
    required this.edges,
    required this.totalEntries,
    required this.totalArcforms,
    required this.startDate,
    required this.endDate,
  });
  
  /// Get a summary of the context
  String get summary {
    return 'Based on $totalEntries journal entries, $totalArcforms Arcform(s), phase history since ${startDate.toIso8601String().split('T')[0]}.';
  }
}

/// Provides context data for LUMARA based on scope and time range
class ContextProvider {
  final LumaraScope _scope;
  
  const ContextProvider(this._scope);
  
  /// Build context window for LUMARA processing
  Future<ContextWindow> buildContext({
    int daysBack = 14,
    int maxEntries = 200,
  }) async {
    // For now, return a simple mock context
    // This will be replaced with actual data retrieval later
    final now = DateTime.now();
    final startDate = now.subtract(Duration(days: daysBack));
    
    final nodes = <Map<String, dynamic>>[];
    final edges = <Map<String, dynamic>>[];
    
    // Mock journal entries if journal scope is enabled
    if (_scope.hasScope('journal')) {
      nodes.addAll(_generateMockJournalEntries(daysBack));
    }
    
    // Mock phase data if phase scope is enabled
    if (_scope.hasScope('phase')) {
      final phaseData = await _generateMockPhaseData();
      nodes.addAll(phaseData);
    }
    
    // Mock arcform data if arcforms scope is enabled
    if (_scope.hasScope('arcforms')) {
      final arcformData = await _generateMockArcformData();
      nodes.addAll(arcformData);
    }
    
    // Mock voice transcripts if voice scope is enabled
    if (_scope.hasScope('voice')) {
      nodes.addAll(_generateMockVoiceData());
    }
    
    // Mock media captions if media scope is enabled
    if (_scope.hasScope('media')) {
      nodes.addAll(_generateMockMediaData());
    }
    
    return ContextWindow(
      nodes: nodes,
      edges: edges,
      totalEntries: nodes.where((n) => n['type'] == 'journal').length,
      totalArcforms: nodes.where((n) => n['type'] == 'arcform').length,
      startDate: startDate,
      endDate: now,
    );
  }
  
  /// Generate mock journal entries for testing
  List<Map<String, dynamic>> _generateMockJournalEntries(int daysBack) {
    final entries = <Map<String, dynamic>>[];
    final now = DateTime.now();
    
    for (int i = 0; i < 5; i++) {
      final date = now.subtract(Duration(days: i * 2));
      entries.add({
        'id': 'j_${date.toIso8601String().split('T')[0]}',
        'type': 'journal',
        'text': 'Sample journal entry from ${date.toIso8601String().split('T')[0]}. This is a test entry for LUMARA context.',
        'meta': {
          'date': date.toIso8601String(),
          'valence': 0.5 + (i * 0.1),
          'labels': ['test', 'sample'],
          'keywords': [
            ['clarity', 0.8],
            ['focus', 0.6],
            ['growth', 0.4],
          ],
          'private': false,
        },
      });
    }
    
    return entries;
  }
  
  /// Generate mock phase data for testing
  Future<List<Map<String, dynamic>>> _generateMockPhaseData() async {
    // Get the actual current phase instead of hardcoding 'Discovery'
    final currentPhase = await UserPhaseService.getCurrentPhase();
    print('ContextProvider: Using actual current phase: $currentPhase');

    return [
      {
        'id': 'p_current',
        'type': 'phase',
        'text': currentPhase,
        'meta': {
          'align': 0.74,
          'trace': 0.71,
          'window': 2,
          'independent': 1,
        },
      },
    ];
  }
  
  /// Generate mock arcform data for testing
  Future<List<Map<String, dynamic>>> _generateMockArcformData() async {
    // Get the actual current phase for arcform data too
    final currentPhase = await UserPhaseService.getCurrentPhase();

    return [
      {
        'id': 'a_001',
        'type': 'arcform',
        'text': 'Sample arcform snapshot',
        'meta': {
          'phase': currentPhase,
          'keywords': ['clarity', 'focus', 'growth'],
          'geometry': 'circle',
        },
      },
    ];
  }
  
  /// Generate mock voice data for testing
  List<Map<String, dynamic>> _generateMockVoiceData() {
    return [
      {
        'id': 'v_001',
        'type': 'voice',
        'text': 'Sample voice transcript from yesterday',
        'meta': {
          'date': DateTime.now().subtract(const Duration(days: 1)).toIso8601String(),
          'duration': 120,
        },
      },
    ];
  }
  
  /// Generate mock media data for testing
  List<Map<String, dynamic>> _generateMockMediaData() {
    return [
      {
        'id': 'm_001',
        'type': 'media',
        'text': 'Sample media caption from a photo',
        'meta': {
          'date': DateTime.now().subtract(const Duration(days: 2)).toIso8601String(),
          'type': 'image',
          'caption': 'A beautiful sunset over the mountains',
        },
      },
    ];
  }
  
  /// Get context summary for display
  Future<String> getContextSummary() async {
    final context = await buildContext();
    return context.summary;
  }
}
