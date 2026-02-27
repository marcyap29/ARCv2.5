import 'context_scope.dart';
import 'package:my_app/services/user_phase_service.dart';
import 'package:my_app/arc/core/journal_repository.dart';

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
  final JournalRepository _journalRepository;

  ContextProvider(this._scope) : _journalRepository = JournalRepository();
  
  /// Build context window for LUMARA processing
  Future<ContextWindow> buildContext({
    int daysBack = 14,
    int maxEntries = 200,
  }) async {
    final now = DateTime.now();
    final startDate = now.subtract(Duration(days: daysBack));

    final nodes = <Map<String, dynamic>>[];
    final edges = <Map<String, dynamic>>[];

    // Get real journal entries if journal scope is enabled
    if (_scope.hasScope('journal')) {
      final realEntries = await _getRealJournalEntries(daysBack, maxEntries);
      nodes.addAll(realEntries);
    }
    
    // Real phase data if phase scope is enabled
    if (_scope.hasScope('phase')) {
      final phaseData = await _generatePhaseData();
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
  
  /// Get real journal entries from repository
  Future<List<Map<String, dynamic>>> _getRealJournalEntries(int daysBack, int maxEntries) async {
    final entries = <Map<String, dynamic>>[];

    try {
      // Get all journal entries from repository
      final allEntries = await _journalRepository.getAllJournalEntries();
      print('LUMARA Context: Found ${allEntries.length} total journal entries');

      // Debug: Print details of first few entries
      for (int i = 0; i < allEntries.length && i < 5; i++) {
        final entry = allEntries[i];
        print('LUMARA Context: Entry $i - ID: ${entry.id}, Date: ${entry.createdAt}, Phase: ${entry.metadata?['phase']}, Content length: ${entry.content.length}');
      }

      // Sort by creation date (newest first)
      allEntries.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      // Take the most recent entries up to maxEntries
      final recentEntries = allEntries.take(maxEntries).toList();
      print('LUMARA Context: Using ${recentEntries.length} recent entries for context');

      for (final entry in recentEntries) {
        entries.add({
          'id': entry.id,
          'type': 'journal',
          'text': entry.content,
          'meta': {
            'date': entry.createdAt.toIso8601String(),
            'valence': 0.0, // emotion is a string, not an object with valence
            'labels': entry.keywords,
            'keywords': entry.keywords.map((k) => [k, 1.0]).toList(),
            'private': false,
            'phase': entry.metadata?['phase'] as String? ?? _determinePhaseFromContent(entry), // get phase from metadata or analyze from content
            'sage': entry.sageAnnotation?.toJson() ?? {},
          },
        });
      }

      print('LUMARA Context: Created ${entries.length} journal context nodes');
    } catch (e) {
      print('LUMARA Context: Error getting journal entries: $e');
      // Return empty list on error
    }

    return entries;
  }
  
  /// Generate phase data using real journal entries
  Future<List<Map<String, dynamic>>> _generatePhaseData() async {
    final currentPhase = await UserPhaseService.getCurrentPhase();
    print('ContextProvider: Using actual current phase: $currentPhase');

    final phaseNodes = <Map<String, dynamic>>[];

    // Always include current phase as the primary phase node
    phaseNodes.add({
      'id': 'p_current',
      'type': 'phase',
      'text': currentPhase,
      'meta': {
        'current': true,
        'source': 'user_setting',
        'align': 0.74,
        'trace': 0.71,
        'window': 2,
        'independent': 1,
      },
    });

    // Get phase history from real journal entries
    try {
      final allEntries = await _journalRepository.getAllJournalEntries();
      // Get phase history from all journal entries (using content analysis)
      final entriesWithPhases = allEntries.toList();

      // Sort by creation date (newest first)
      entriesWithPhases.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      print('ContextProvider: Found ${entriesWithPhases.length} entries with phases');

      // Debug: Print entries with phases
      for (final entry in entriesWithPhases.take(5)) {
        final contentPreview = entry.content.length > 50 ? entry.content.substring(0, 50) : entry.content;
        final analyzedPhase = entry.metadata?['phase'] ?? _determinePhaseFromContent(entry);
        print('ContextProvider: Entry with phase - Date: ${entry.createdAt}, Phase: $analyzedPhase (from ${entry.metadata?['phase'] != null ? 'metadata' : 'content'}), Content: "$contentPreview..."');
      }

      // Add unique phases from entries as history (excluding current phase)
      final seenPhases = <String>{currentPhase}; // Don't duplicate current phase
      int historyIndex = 0;

      for (final entry in entriesWithPhases) {
        final entryPhase = entry.metadata?['phase'] as String? ?? _determinePhaseFromContent(entry);
        if (!seenPhases.contains(entryPhase) && historyIndex < 5) { // Limit to 5 historical phases
          seenPhases.add(entryPhase);

          final now = DateTime.now();
          final daysAgo = now.difference(entry.createdAt).inDays;

          phaseNodes.add({
            'id': 'p_history_$historyIndex',
            'type': 'phase_history',
            'text': entryPhase,
            'meta': {
              'current': false,
              'source': 'entry_analysis',
              'days_ago': daysAgo,
              'confidence': 0.8, // High confidence since it's from actual entries
              'entry_date': entry.createdAt.toIso8601String(),
            },
          });
          historyIndex++;
        }
      }

      print('ContextProvider: Added $historyIndex historical phases from real entries');
    } catch (e) {
      print('ContextProvider: Error getting phase history: $e');
    }

    return phaseNodes;
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

  /// Determine phase from journal entry content (same logic as Timeline)
  String _determinePhaseFromContent(dynamic entry) {
    return _determinePhaseFromText(entry.content);
  }

  /// Analyze phase from text content
  String _determinePhaseFromText(String content) {
    final text = content.toLowerCase();

    if (text.contains('discover') || text.contains('explore') || text.contains('new') || text.contains('beginning')) {
      return 'Discovery';
    } else if (text.contains('grow') || text.contains('expand') || text.contains('possibility') || text.contains('energy')) {
      return 'Expansion';
    } else if (text.contains('change') || text.contains('transition') || text.contains('moving') || text.contains('shift')) {
      return 'Transition';
    } else if (text.contains('integrate') || text.contains('wisdom') || text.contains('balance') || text.contains('center')) {
      return 'Consolidation';
    } else if (text.contains('heal') || text.contains('recover') || text.contains('restore') || text.contains('rest')) {
      return 'Recovery';
    } else if (text.contains('breakthrough') || text.contains('transcend') || text.contains('quantum') || text.contains('beyond')) {
      return 'Breakthrough';
    }

    return 'Discovery'; // Default fallback
  }
}
