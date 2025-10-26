// lib/lumara/v2/data/lumara_context.dart
// Unified context access for all LUMARA data sources

import 'dart:async';
import 'package:flutter/foundation.dart';
import '../services/lumara_service.dart';
import '../../../models/journal_entry_model.dart';
import '../../../models/draft_model.dart';
import '../../chat/chat_models.dart';

/// Unified context access for LUMARA
class LumaraContext {
  final LumaraService _service;
  
  LumaraContext(this._service);
  
  /// Get journal entries with optional filters
  Future<List<JournalEntry>> getJournalEntries({
    int? limit,
    DateTime? since,
    String? phase,
    List<String>? keywords,
  }) async {
    try {
      return await _service.getJournalEntries(
        limit: limit,
        since: since,
        phase: phase,
        keywords: keywords,
      );
    } catch (e) {
      debugPrint('LUMARA Context: Error getting journal entries: $e');
      return [];
    }
  }
  
  /// Get drafts
  Future<List<DraftEntry>> getDrafts({
    int? limit,
    DateTime? since,
  }) async {
    try {
      return await _service.getDrafts(
        limit: limit,
        since: since,
      );
    } catch (e) {
      debugPrint('LUMARA Context: Error getting drafts: $e');
      return [];
    }
  }
  
  /// Get chat history
  Future<List<ChatSession>> getChatHistory({
    int? limit,
    DateTime? since,
  }) async {
    try {
      return await _service.getChatHistory(
        limit: limit,
        since: since,
      );
    } catch (e) {
      debugPrint('LUMARA Context: Error getting chat history: $e');
      return [];
    }
  }
  
  /// Get current phase
  Future<String?> getCurrentPhase() async {
    try {
      return await _service.getCurrentPhase();
    } catch (e) {
      debugPrint('LUMARA Context: Error getting current phase: $e');
      return null;
    }
  }
  
  /// Get phase history
  Future<List<Map<String, dynamic>>> getPhaseHistory({
    int? limit,
    DateTime? since,
  }) async {
    try {
      return await _service.getPhaseHistory(
        limit: limit,
        since: since,
      );
    } catch (e) {
      debugPrint('LUMARA Context: Error getting phase history: $e');
      return [];
    }
  }
  
  /// Search across all data sources
  Future<List<Map<String, dynamic>>> search({
    required String query,
    List<String>? sources, // ['journal', 'drafts', 'chats', 'media']
    int? limit,
    DateTime? since,
  }) async {
    try {
      return await _service.search(
        query: query,
        sources: sources,
        limit: limit,
        since: since,
      );
    } catch (e) {
      debugPrint('LUMARA Context: Error searching: $e');
      return [];
    }
  }
  
  /// Get comprehensive context for a specific query
  Future<LumaraContextData> getContextForQuery({
    required String query,
    int maxEntries = 50,
    int daysBack = 30,
  }) async {
    try {
      return await _service.buildContextForQuery(
        query: query,
        maxEntries: maxEntries,
        daysBack: daysBack,
      );
    } catch (e) {
      debugPrint('LUMARA Context: Error building context: $e');
      return LumaraContextData.empty();
    }
  }
}

/// Comprehensive context data for LUMARA queries
class LumaraContextData {
  final List<JournalEntry> journalEntries;
  final List<DraftEntry> drafts;
  final List<ChatSession> chatSessions;
  final String? currentPhase;
  final List<Map<String, dynamic>> phaseHistory;
  final List<Map<String, dynamic>> mediaItems;
  final Map<String, dynamic> metadata;
  
  const LumaraContextData({
    required this.journalEntries,
    required this.drafts,
    required this.chatSessions,
    this.currentPhase,
    required this.phaseHistory,
    required this.mediaItems,
    required this.metadata,
  });
  
  factory LumaraContextData.empty() {
    return const LumaraContextData(
      journalEntries: [],
      drafts: [],
      chatSessions: [],
      phaseHistory: [],
      mediaItems: [],
      metadata: {},
    );
  }
  
  /// Get total entry count
  int get totalEntries => journalEntries.length + drafts.length + chatSessions.length;
  
  /// Get date range
  Map<String, DateTime?> get dateRange {
    final allDates = <DateTime>[];
    
    allDates.addAll(journalEntries.map((e) => e.createdAt));
    allDates.addAll(drafts.map((d) => d.createdAt));
    allDates.addAll(chatSessions.map((c) => c.createdAt));
    
    if (allDates.isEmpty) return {'start': null, 'end': null};
    
    allDates.sort();
    return {
      'start': allDates.first,
      'end': allDates.last,
    };
  }
  
  /// Convert to JSON for API calls
  Map<String, dynamic> toJson() {
    return {
      'journalEntries': journalEntries.map((e) => e.toJson()).toList(),
      'drafts': drafts.map((d) => d.toJson()).toList(),
      'chatSessions': chatSessions.map((c) => c.toJson()).toList(),
      'currentPhase': currentPhase,
      'phaseHistory': phaseHistory,
      'mediaItems': mediaItems,
      'metadata': {
        ...metadata,
        'totalEntries': totalEntries,
        'dateRange': dateRange.map((k, v) => MapEntry(k, v?.toIso8601String())),
      },
    };
  }
}
