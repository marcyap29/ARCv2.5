// lib/lumara/v2/services/lumara_service.dart
// Core service layer for LUMARA v2.0

import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import '../config/lumara_config.dart';
import '../prompts/lumara_prompts.dart';
import '../../../models/journal_entry_model.dart';
import '../../../models/draft_model.dart';
import '../../chat/chat_models.dart';
import '../data/lumara_context.dart';
import '../data/lumara_media.dart';
import '../../../services/gemini_send.dart';
import '../../../services/llm_bridge_adapter.dart';

/// Core service layer for LUMARA v2.0
class LumaraService {
  final LumaraConfig _config;
  
  // Repositories
  late final JournalRepository _journalRepo;
  late final DraftRepository _draftRepo;
  late final ChatRepository _chatRepo;
  
  // LLM Services
  late final ArcLLM _arcLLM;
  
  // State
  bool _isInitialized = false;
  bool _isReady = false;
  
  LumaraService(this._config);
  
  /// Initialize the service
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      debugPrint('LUMARA Service: Initializing...');
      
      // Initialize repositories
      _journalRepo = JournalRepository();
      _draftRepo = DraftRepository();
      _chatRepo = ChatRepository();
      
      // Initialize LLM
      _arcLLM = provideArcLLM();
      
      _isInitialized = true;
      _isReady = true;
      
      debugPrint('LUMARA Service: Initialized successfully');
    } catch (e) {
      debugPrint('LUMARA Service: Initialization failed: $e');
      _isReady = false;
      rethrow;
    }
  }
  
  /// Check if service is ready
  bool get isReady => _isReady;
  
  /// Get journal entries
  Future<List<JournalEntry>> getJournalEntries({
    int? limit,
    DateTime? since,
    String? phase,
    List<String>? keywords,
  }) async {
    try {
      final entries = _journalRepo.getAllJournalEntries();
      
      // Apply filters
      var filteredEntries = entries;
      
      if (since != null) {
        filteredEntries = filteredEntries.where((e) => e.createdAt.isAfter(since)).toList();
      }
      
      if (phase != null) {
        filteredEntries = filteredEntries.where((e) => 
          e.metadata?['phase'] == phase).toList();
      }
      
      if (keywords != null && keywords.isNotEmpty) {
        filteredEntries = filteredEntries.where((e) => 
          e.keywords.any((k) => keywords.contains(k))).toList();
      }
      
      // Sort by date (newest first)
      filteredEntries.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      
      // Apply limit
      if (limit != null && limit > 0) {
        filteredEntries = filteredEntries.take(limit).toList();
      }
      
      return filteredEntries;
    } catch (e) {
      debugPrint('LUMARA Service: Error getting journal entries: $e');
      return [];
    }
  }
  
  /// Get drafts
  Future<List<DraftEntry>> getDrafts({
    int? limit,
    DateTime? since,
  }) async {
    try {
      final drafts = _draftRepo.getAllDrafts();
      
      // Apply filters
      var filteredDrafts = drafts;
      
      if (since != null) {
        filteredDrafts = filteredDrafts.where((d) => d.createdAt.isAfter(since)).toList();
      }
      
      // Sort by date (newest first)
      filteredDrafts.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      
      // Apply limit
      if (limit != null && limit > 0) {
        filteredDrafts = filteredDrafts.take(limit).toList();
      }
      
      return filteredDrafts;
    } catch (e) {
      debugPrint('LUMARA Service: Error getting drafts: $e');
      return [];
    }
  }
  
  /// Get chat history
  Future<List<ChatSession>> getChatHistory({
    int? limit,
    DateTime? since,
  }) async {
    try {
      final sessions = _chatRepo.getAllSessions();
      
      // Apply filters
      var filteredSessions = sessions;
      
      if (since != null) {
        filteredSessions = filteredSessions.where((s) => 
          s.createdAt.isAfter(since)).toList();
      }
      
      // Sort by date (newest first)
      filteredSessions.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      
      // Apply limit
      if (limit != null && limit > 0) {
        filteredSessions = filteredSessions.take(limit).toList();
      }
      
      return filteredSessions;
    } catch (e) {
      debugPrint('LUMARA Service: Error getting chat history: $e');
      return [];
    }
  }
  
  /// Get current phase
  Future<String?> getCurrentPhase() async {
    try {
      // Try to get from user profile first
      final userBox = Hive.box<UserProfile>('user_profile');
      final profile = userBox.get('profile');
      
      if (profile?.currentPhase != null && profile!.currentPhase.isNotEmpty) {
        return profile.currentPhase;
      }
      
      // Fallback: analyze recent journal entries
      final recentEntries = await getJournalEntries(limit: 10);
      if (recentEntries.isNotEmpty) {
        return _analyzePhaseFromEntries(recentEntries);
      }
      
      return 'Discovery'; // Default phase
    } catch (e) {
      debugPrint('LUMARA Service: Error getting current phase: $e');
      return 'Discovery';
    }
  }
  
  /// Get phase history
  Future<List<Map<String, dynamic>>> getPhaseHistory({
    int? limit,
    DateTime? since,
  }) async {
    try {
      final entries = await getJournalEntries(since: since, limit: limit);
      final phaseHistory = <Map<String, dynamic>>[];
      
      for (final entry in entries) {
        final phase = entry.metadata?['phase'] ?? _analyzePhaseFromContent(entry.content);
        phaseHistory.add({
          'date': entry.createdAt.toIso8601String(),
          'phase': phase,
          'entryId': entry.id,
        });
      }
      
      return phaseHistory;
    } catch (e) {
      debugPrint('LUMARA Service: Error getting phase history: $e');
      return [];
    }
  }
  
  /// Search across all data sources
  Future<List<Map<String, dynamic>>> search({
    required String query,
    List<String>? sources,
    int? limit,
    DateTime? since,
  }) async {
    try {
      final results = <Map<String, dynamic>>[];
      
      if (sources == null || sources.contains('journal')) {
        final entries = await getJournalEntries(since: since, limit: limit);
        for (final entry in entries) {
          if (entry.content.toLowerCase().contains(query.toLowerCase()) ||
              entry.keywords.any((k) => k.toLowerCase().contains(query.toLowerCase()))) {
            results.add({
              'type': 'journal',
              'id': entry.id,
              'content': entry.content,
              'date': entry.createdAt.toIso8601String(),
              'keywords': entry.keywords,
              'phase': entry.metadata?['phase'],
            });
          }
        }
      }
      
      if (sources == null || sources.contains('drafts')) {
        final drafts = await getDrafts(since: since, limit: limit);
        for (final draft in drafts) {
          if (draft.content.toLowerCase().contains(query.toLowerCase())) {
            results.add({
              'type': 'draft',
              'id': draft.id,
              'content': draft.content,
              'date': draft.createdAt.toIso8601String(),
            });
          }
        }
      }
      
      if (sources == null || sources.contains('chats')) {
        final sessions = await getChatHistory(since: since, limit: limit);
        for (final session in sessions) {
          for (final message in session.messages) {
            if (message.content.toLowerCase().contains(query.toLowerCase())) {
              results.add({
                'type': 'chat',
                'id': message.id,
                'content': message.content,
                'date': message.timestamp.toIso8601String(),
                'sessionId': session.id,
                'role': message.role.name,
              });
            }
          }
        }
      }
      
      // Sort by date (newest first)
      results.sort((a, b) => b['date'].compareTo(a['date']));
      
      return results;
    } catch (e) {
      debugPrint('LUMARA Service: Error searching: $e');
      return [];
    }
  }
  
  /// Build comprehensive context for a query
  Future<LumaraContextData> buildContextForQuery({
    required String query,
    int maxEntries = 50,
    int daysBack = 30,
  }) async {
    try {
      final since = DateTime.now().subtract(Duration(days: daysBack));
      
      // Get all relevant data
      final journalEntries = await getJournalEntries(
        limit: maxEntries,
        since: since,
      );
      
      final drafts = await getDrafts(
        limit: maxEntries ~/ 2,
        since: since,
      );
      
      final chatSessions = await getChatHistory(
        limit: maxEntries ~/ 2,
        since: since,
      );
      
      final currentPhase = await getCurrentPhase();
      final phaseHistory = await getPhaseHistory(since: since);
      
      // Get media items (simplified for now)
      final mediaItems = <Map<String, dynamic>>[];
      
      return LumaraContextData(
        journalEntries: journalEntries,
        drafts: drafts,
        chatSessions: chatSessions,
        currentPhase: currentPhase,
        phaseHistory: phaseHistory,
        mediaItems: mediaItems,
        metadata: {
          'query': query,
          'maxEntries': maxEntries,
          'daysBack': daysBack,
          'generatedAt': DateTime.now().toIso8601String(),
        },
      );
    } catch (e) {
      debugPrint('LUMARA Service: Error building context: $e');
      return LumaraContextData.empty();
    }
  }
  
  /// Generate LUMARA response
  Future<String> generateResponse({
    required String query,
    LumaraContextData? context,
    String? phase,
  }) async {
    try {
      // Build context if not provided
      final contextData = context ?? await buildContextForQuery(query: query);
      
      // Get current phase if not provided
      final currentPhase = phase ?? await getCurrentPhase() ?? 'Discovery';
      
      // Build prompt
      final prompt = LumaraPrompts.buildPrompt(
        query: query,
        context: contextData,
        phase: currentPhase,
      );
      
      // Generate response using Gemini
      final response = await geminiSend(
        system: LumaraPrompts.systemPrompt,
        user: prompt,
      );
      
      return response;
    } catch (e) {
      debugPrint('LUMARA Service: Error generating response: $e');
      return 'I apologize, but I encountered an error while processing your request. Please try again.';
    }
  }
  
  /// Media access methods (simplified implementations)
  Future<List<LumaraPhoto>> getPhotos({
    int? limit,
    DateTime? since,
    String? journalEntryId,
    List<String>? keywords,
  }) async {
    // TODO: Implement photo access
    return [];
  }
  
  Future<List<LumaraAudio>> getAudioRecordings({
    int? limit,
    DateTime? since,
    String? journalEntryId,
  }) async {
    // TODO: Implement audio access
    return [];
  }
  
  Future<List<LumaraVideo>> getVideoRecordings({
    int? limit,
    DateTime? since,
    String? journalEntryId,
  }) async {
    // TODO: Implement video access
    return [];
  }
  
  Future<LumaraMediaAnalysis> analyzeMedia(LumaraMediaItem media) async {
    // TODO: Implement media analysis
    return LumaraMediaAnalysis.empty();
  }
  
  Future<String?> getMediaPath(String mediaId) async {
    // TODO: Implement media path resolution
    return null;
  }
  
  /// Helper methods
  String _analyzePhaseFromEntries(List<JournalEntry> entries) {
    // Simple phase analysis based on content keywords
    final content = entries.map((e) => e.content).join(' ').toLowerCase();
    
    if (content.contains('breakthrough') || content.contains('amazing') || content.contains('incredible')) {
      return 'Breakthrough';
    } else if (content.contains('recovery') || content.contains('healing') || content.contains('rest')) {
      return 'Recovery';
    } else if (content.contains('transition') || content.contains('change') || content.contains('moving')) {
      return 'Transition';
    } else if (content.contains('consolidation') || content.contains('stable') || content.contains('settled')) {
      return 'Consolidation';
    } else if (content.contains('expansion') || content.contains('growing') || content.contains('learning')) {
      return 'Expansion';
    } else {
      return 'Discovery';
    }
  }
  
  String _analyzePhaseFromContent(String content) {
    final lowerContent = content.toLowerCase();
    
    if (lowerContent.contains('breakthrough') || lowerContent.contains('amazing') || lowerContent.contains('incredible')) {
      return 'Breakthrough';
    } else if (lowerContent.contains('recovery') || lowerContent.contains('healing') || lowerContent.contains('rest')) {
      return 'Recovery';
    } else if (lowerContent.contains('transition') || lowerContent.contains('change') || lowerContent.contains('moving')) {
      return 'Transition';
    } else if (lowerContent.contains('consolidation') || lowerContent.contains('stable') || lowerContent.contains('settled')) {
      return 'Consolidation';
    } else if (lowerContent.contains('expansion') || lowerContent.contains('growing') || lowerContent.contains('learning')) {
      return 'Expansion';
    } else {
      return 'Discovery';
    }
  }
  
  /// Shutdown the service
  Future<void> shutdown() async {
    _isReady = false;
    debugPrint('LUMARA Service: Shutdown complete');
  }
}
