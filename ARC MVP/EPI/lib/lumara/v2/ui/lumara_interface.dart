// lib/lumara/v2/ui/lumara_interface.dart
// Unified interface for all LUMARA interactions

import 'dart:async';
import 'package:flutter/foundation.dart';
import '../services/lumara_service.dart';
import '../data/lumara_context.dart';
import '../data/lumara_media.dart';
import '../prompts/lumara_prompts.dart';

/// Unified interface for all LUMARA interactions
class LumaraInterface {
  final LumaraService _service;
  final LumaraContext _context;
  final LumaraMedia _media;
  
  LumaraInterface(this._service, this._context, this._media);
  
  /// Generate a response to a user query
  Future<LumaraResponse> ask({
    required String query,
    LumaraScope? scope,
    String? phase,
    int maxContextEntries = 50,
    int contextDaysBack = 30,
  }) async {
    try {
      debugPrint('LUMARA Interface: Processing query: "$query"');
      
      // Build context based on scope
      final contextData = await _buildContextForScope(
        scope: scope ?? LumaraScope.all(),
        query: query,
        maxEntries: maxContextEntries,
        daysBack: contextDaysBack,
      );
      
      // Generate response
      final response = await _service.generateResponse(
        query: query,
        context: contextData,
        phase: phase,
      );
      
      return LumaraResponse(
        content: response,
        context: contextData,
        metadata: {
          'query': query,
          'scope': scope?.toJson(),
          'phase': phase,
          'generatedAt': DateTime.now().toIso8601String(),
        },
      );
    } catch (e) {
      debugPrint('LUMARA Interface: Error processing query: $e');
      return LumaraResponse.error('I encountered an error while processing your request. Please try again.');
    }
  }
  
  /// Generate a reflection for journal content
  Future<LumaraReflection> reflect({
    required String journalContent,
    LumaraReflectionType type = LumaraReflectionType.general,
    String? phase,
    List<String>? keywords,
  }) async {
    try {
      debugPrint('LUMARA Interface: Generating ${type.name} reflection');
      
      // Build context focused on the journal content
      final contextData = await _buildContextForReflection(
        journalContent: journalContent,
        phase: phase,
        keywords: keywords,
      );
      
      // Generate reflection using specialized prompt
      final prompt = LumaraPrompts.buildReflectionPrompt(
        content: journalContent,
        type: type,
        context: contextData,
        phase: phase,
      );
      
      final response = await _service.generateResponse(
        query: prompt,
        context: contextData,
        phase: phase,
      );
      
      return LumaraReflection(
        content: response,
        type: type,
        context: contextData,
        metadata: {
          'journalContent': journalContent,
          'type': type.name,
          'phase': phase,
          'keywords': keywords,
          'generatedAt': DateTime.now().toIso8601String(),
        },
      );
    } catch (e) {
      debugPrint('LUMARA Interface: Error generating reflection: $e');
      return LumaraReflection.error('I encountered an error while generating your reflection. Please try again.');
    }
  }
  
  /// Get suggestions for journal writing
  Future<List<LumaraSuggestion>> getSuggestions({
    String? phase,
    List<String>? recentTopics,
    int count = 5,
  }) async {
    try {
      debugPrint('LUMARA Interface: Getting suggestions');
      
      // Build context for suggestions
      final contextData = await _buildContextForSuggestions(
        phase: phase,
        recentTopics: recentTopics,
      );
      
      // Generate suggestions using specialized prompt
      final prompt = LumaraPrompts.buildSuggestionsPrompt(
        context: contextData,
        phase: phase,
        recentTopics: recentTopics,
        count: count,
      );
      
      final response = await _service.generateResponse(
        query: prompt,
        context: contextData,
        phase: phase,
      );
      
      // Parse suggestions from response
      final suggestions = _parseSuggestions(response);
      
      return suggestions;
    } catch (e) {
      debugPrint('LUMARA Interface: Error getting suggestions: $e');
      return [];
    }
  }
  
  /// Analyze media content
  Future<LumaraMediaAnalysis> analyzeMedia(LumaraMediaItem media) async {
    try {
      return await _media.analyzeMedia(media);
    } catch (e) {
      debugPrint('LUMARA Interface: Error analyzing media: $e');
      return LumaraMediaAnalysis.empty();
    }
  }
  
  /// Search across all data sources
  Future<List<LumaraSearchResult>> search({
    required String query,
    LumaraScope? scope,
    int limit = 20,
    DateTime? since,
  }) async {
    try {
      debugPrint('LUMARA Interface: Searching for "$query"');
      
      final sources = scope?.enabledSources ?? ['journal', 'drafts', 'chats', 'media'];
      
      final results = await _service.search(
        query: query,
        sources: sources,
        limit: limit,
        since: since,
      );
      
      return results.map((result) => LumaraSearchResult.fromJson(result)).toList();
    } catch (e) {
      debugPrint('LUMARA Interface: Error searching: $e');
      return [];
    }
  }
  
  /// Get context access
  LumaraContext get context => _context;
  
  /// Get media access
  LumaraMedia get media => _media;
  
  /// Helper methods
  Future<LumaraContextData> _buildContextForScope({
    required LumaraScope scope,
    required String query,
    required int maxEntries,
    required int daysBack,
  }) async {
    final since = DateTime.now().subtract(Duration(days: daysBack));
    
    final journalEntries = scope.journal 
        ? await _context.getJournalEntries(limit: maxEntries, since: since)
        : <JournalEntry>[];
    
    final drafts = scope.drafts 
        ? await _context.getDrafts(limit: maxEntries ~/ 2, since: since)
        : <DraftEntry>[];
    
    final chatSessions = scope.chats 
        ? await _context.getChatHistory(limit: maxEntries ~/ 2, since: since)
        : <ChatSession>[];
    
    final currentPhase = scope.phase ? await _context.getCurrentPhase() : null;
    final phaseHistory = scope.phase 
        ? await _context.getPhaseHistory(limit: maxEntries ~/ 4, since: since)
        : <Map<String, dynamic>>[];
    
    return LumaraContextData(
      journalEntries: journalEntries,
      drafts: drafts,
      chatSessions: chatSessions,
      currentPhase: currentPhase,
      phaseHistory: phaseHistory,
      mediaItems: [], // TODO: Add media items based on scope
      metadata: {
        'query': query,
        'scope': scope.toJson(),
        'maxEntries': maxEntries,
        'daysBack': daysBack,
        'generatedAt': DateTime.now().toIso8601String(),
      },
    );
  }
  
  Future<LumaraContextData> _buildContextForReflection({
    required String journalContent,
    String? phase,
    List<String>? keywords,
  }) async {
    // Get recent entries for context
    final recentEntries = await _context.getJournalEntries(limit: 10);
    final currentPhase = phase ?? await _context.getCurrentPhase() ?? 'Discovery';
    
    return LumaraContextData(
      journalEntries: recentEntries,
      drafts: [],
      chatSessions: [],
      currentPhase: currentPhase,
      phaseHistory: [],
      mediaItems: [],
      metadata: {
        'journalContent': journalContent,
        'phase': currentPhase,
        'keywords': keywords,
        'generatedAt': DateTime.now().toIso8601String(),
      },
    );
  }
  
  Future<LumaraContextData> _buildContextForSuggestions({
    String? phase,
    List<String>? recentTopics,
  }) async {
    // Get recent entries to understand current patterns
    final recentEntries = await _context.getJournalEntries(limit: 20);
    final currentPhase = phase ?? await _context.getCurrentPhase() ?? 'Discovery';
    
    return LumaraContextData(
      journalEntries: recentEntries,
      drafts: [],
      chatSessions: [],
      currentPhase: currentPhase,
      phaseHistory: [],
      mediaItems: [],
      metadata: {
        'phase': currentPhase,
        'recentTopics': recentTopics,
        'generatedAt': DateTime.now().toIso8601String(),
      },
    );
  }
  
  List<LumaraSuggestion> _parseSuggestions(String response) {
    // Simple parsing of suggestions from response
    // TODO: Implement more sophisticated parsing
    final lines = response.split('\n').where((line) => line.trim().isNotEmpty).toList();
    final suggestions = <LumaraSuggestion>[];
    
    for (int i = 0; i < lines.length && i < 5; i++) {
      final line = lines[i].trim();
      if (line.isNotEmpty) {
        suggestions.add(LumaraSuggestion(
          text: line,
          type: LumaraSuggestionType.prompt,
          metadata: {'index': i},
        ));
      }
    }
    
    return suggestions;
  }
}

/// LUMARA response
class LumaraResponse {
  final String content;
  final LumaraContextData? context;
  final Map<String, dynamic> metadata;
  final bool isError;
  
  const LumaraResponse({
    required this.content,
    this.context,
    this.metadata = const {},
    this.isError = false,
  });
  
  factory LumaraResponse.error(String message) {
    return LumaraResponse(
      content: message,
      isError: true,
      metadata: {'error': true},
    );
  }
}

/// LUMARA reflection
class LumaraReflection {
  final String content;
  final LumaraReflectionType type;
  final LumaraContextData? context;
  final Map<String, dynamic> metadata;
  final bool isError;
  
  const LumaraReflection({
    required this.content,
    required this.type,
    this.context,
    this.metadata = const {},
    this.isError = false,
  });
  
  factory LumaraReflection.error(String message) {
    return LumaraReflection(
      content: message,
      type: LumaraReflectionType.general,
      isError: true,
      metadata: {'error': true},
    );
  }
}

/// LUMARA suggestion
class LumaraSuggestion {
  final String text;
  final LumaraSuggestionType type;
  final Map<String, dynamic> metadata;
  
  const LumaraSuggestion({
    required this.text,
    required this.type,
    this.metadata = const {},
  });
}

/// LUMARA search result
class LumaraSearchResult {
  final String type;
  final String id;
  final String content;
  final DateTime date;
  final Map<String, dynamic> metadata;
  
  const LumaraSearchResult({
    required this.type,
    required this.id,
    required this.content,
    required this.date,
    this.metadata = const {},
  });
  
  factory LumaraSearchResult.fromJson(Map<String, dynamic> json) {
    return LumaraSearchResult(
      type: json['type'] as String,
      id: json['id'] as String,
      content: json['content'] as String,
      date: DateTime.parse(json['date'] as String),
      metadata: json['metadata'] as Map<String, dynamic>? ?? {},
    );
  }
}

/// Reflection types
enum LumaraReflectionType {
  general,
  emotional,
  analytical,
  creative,
  supportive,
}

/// Suggestion types
enum LumaraSuggestionType {
  prompt,
  question,
  activity,
  reflection,
}
