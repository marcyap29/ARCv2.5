import 'package:my_app/arc/chat/data/context_scope.dart';
import 'package:my_app/models/journal_entry_model.dart';
import 'package:my_app/services/user_phase_service.dart';
import 'package:my_app/arc/core/journal_repository.dart';
import 'package:my_app/services/phase_regime_service.dart';
import 'package:my_app/services/analytics_service.dart';
import 'package:my_app/services/rivet_sweep_service.dart';
import '../chat/chat_repo.dart';
import '../chat/chat_repo_impl.dart';

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
    // Get phase information from nodes
    final phaseNodes = nodes.where((n) => n['type'] == 'phase' || n['type'] == 'phase_history').toList();
    final currentPhaseNode = phaseNodes.firstWhere(
      (n) => n['meta']?['current'] == true,
      orElse: () => {},
    );
    final currentPhase = currentPhaseNode['text'] as String? ?? 'Discovery';
    
    // Count unique phases in history
    final uniquePhases = phaseNodes
        .where((n) => n['meta']?['current'] != true)
        .map((n) => n['text'] as String?)
        .where((p) => p != null)
        .toSet()
        .length;
    
    if (uniquePhases > 0) {
      return 'Based on $totalEntries entries, current phase: $currentPhase, $uniquePhases phase${uniquePhases > 1 ? 's' : ''} in history since ${startDate.toIso8601String().split('T')[0]}.';
    } else {
      return 'Based on $totalEntries entries, current phase: $currentPhase, phase history since ${startDate.toIso8601String().split('T')[0]}.';
    }
  }
}

/// Provides context data for LUMARA based on scope and time range
class ContextProvider {
  final LumaraScope _scope;
  final JournalRepository _journalRepository;
  final ChatRepo _chatRepo;

  ContextProvider(this._scope) 
      : _journalRepository = JournalRepository(),
        _chatRepo = ChatRepoImpl.instance;
  
  /// Build context window for LUMARA processing
  /// [scope] - Optional scope to use. If provided, uses this scope instead of the stored scope.
  Future<ContextWindow> buildContext({
    int daysBack = 14,
    int maxEntries = 200,
    LumaraScope? scope,
  }) async {
    // Use provided scope or fall back to stored scope
    final effectiveScope = scope ?? _scope;
    
    final now = DateTime.now();
    final startDate = now.subtract(Duration(days: daysBack));

    final nodes = <Map<String, dynamic>>[];
    final edges = <Map<String, dynamic>>[];

    // Get real journal entries if journal scope is enabled
    if (effectiveScope.hasScope('journal')) {
      final realEntries = await _getRealJournalEntries(daysBack, maxEntries);
      nodes.addAll(realEntries);
    }
    
    // Real phase data if phase scope is enabled
    if (effectiveScope.hasScope('phase')) {
      final phaseData = await _generatePhaseData();
      nodes.addAll(phaseData);
    }
    
    // Mock arcform data if arcforms scope is enabled
    if (effectiveScope.hasScope('arcforms')) {
      final arcformData = await _generateMockArcformData();
      nodes.addAll(arcformData);
    }
    
    // Mock voice transcripts if voice scope is enabled
    if (effectiveScope.hasScope('voice')) {
      nodes.addAll(_generateMockVoiceData());
    }
    
    // Mock media captions if media scope is enabled
    if (effectiveScope.hasScope('media')) {
      nodes.addAll(_generateMockMediaData());
    }
    
    // Add recent chat sessions for conversation continuity
    if (effectiveScope.hasScope('chat') || effectiveScope.hasScope('journal')) {
      final chatSessions = await _getRecentChatSessions(limit: 5);
      nodes.addAll(chatSessions);
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
  
  /// Get recent chat sessions for context
  Future<List<Map<String, dynamic>>> _getRecentChatSessions({int limit = 25}) async {
    final chatNodes = <Map<String, dynamic>>[];
    
    try {
      final sessions = await _chatRepo.listActive();
      // Sort by most recent (assuming sessions have updatedAt or similar)
      sessions.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      
      // Get up to limit most recent sessions (max 25)
      final sessionsToInclude = sessions.take(limit).toList();
      
      // Archive sessions after the 25th
      if (sessions.length > 25) {
        final sessionsToArchive = sessions.skip(25).toList();
        for (final session in sessionsToArchive) {
          try {
            await _chatRepo.archiveSession(session.id, true);
            print('ContextProvider: Archived session ${session.id} (${session.subject})');
          } catch (e) {
            print('ContextProvider: Error archiving session ${session.id}: $e');
          }
        }
      }
      
      // Get up to limit most recent sessions
      for (final session in sessionsToInclude) {
        try {
          // Get up to 25 messages from each session for context
          final messages = await _chatRepo.getMessages(session.id, lazy: false);
          final recentMessages = messages.take(25).toList();
          
          if (recentMessages.isNotEmpty) {
            final messageText = recentMessages.map((m) {
              final role = m.role == 'user' ? 'user' : 'assistant';
              return '$role: ${m.content}';
            }).join('\n');
            
            chatNodes.add({
              'id': 'chat_${session.id}',
              'type': 'chat',
              'text': 'Session: "${session.subject}" (${session.updatedAt.toLocal().toString().split(' ')[0]}):\n$messageText',
              'meta': {
                'session_id': session.id,
                'subject': session.subject,
                'date': session.updatedAt.toIso8601String(),
                'message_count': recentMessages.length,
              },
            });
          }
        } catch (e) {
          print('ContextProvider: Error getting messages for session ${session.id}: $e');
        }
      }
      
      print('ContextProvider: Added ${chatNodes.length} recent chat sessions to context');
    } catch (e) {
      print('ContextProvider: Error getting recent chat sessions: $e');
    }
    
    return chatNodes;
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
    // Try to get current phase from PhaseRegimeService first (most accurate)
    String currentPhase = 'Discovery';
    try {
      final analyticsService = AnalyticsService();
      final rivetSweepService = RivetSweepService(analyticsService);
      final phaseRegimeService = PhaseRegimeService(analyticsService, rivetSweepService);
      await phaseRegimeService.initialize();
      
      final currentRegime = phaseRegimeService.phaseIndex.currentRegime;
      if (currentRegime != null) {
        // Convert PhaseLabel enum to string (e.g., PhaseLabel.discovery -> "discovery")
        currentPhase = currentRegime.label.toString().split('.').last;
        // Capitalize first letter
        currentPhase = currentPhase[0].toUpperCase() + currentPhase.substring(1);
        print('ContextProvider: Using current phase from PhaseRegimeService: $currentPhase');
      } else {
        // Fallback: get most recent regime if no current ongoing regime
        final allRegimes = phaseRegimeService.phaseIndex.allRegimes;
        if (allRegimes.isNotEmpty) {
          final sortedRegimes = List.from(allRegimes)..sort((a, b) => b.start.compareTo(a.start));
          final mostRecentRegime = sortedRegimes.first;
          currentPhase = mostRecentRegime.label.toString().split('.').last;
          currentPhase = currentPhase[0].toUpperCase() + currentPhase.substring(1);
          print('ContextProvider: No current regime, using most recent: $currentPhase');
        } else {
          // Final fallback to UserPhaseService
          currentPhase = await UserPhaseService.getCurrentPhase();
          print('ContextProvider: No regimes found, using UserPhaseService: $currentPhase');
        }
      }
    } catch (e) {
      print('ContextProvider: Error getting phase from PhaseRegimeService: $e');
      // Fallback to UserPhaseService
      currentPhase = await UserPhaseService.getCurrentPhase();
      print('ContextProvider: Fallback to UserPhaseService: $currentPhase');
    }
    
    print('ContextProvider: Final current phase: $currentPhase');

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
