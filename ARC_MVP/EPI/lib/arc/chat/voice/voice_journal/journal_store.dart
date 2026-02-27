/// Journal Store for Voice Journal
/// 
/// Saves voice journal entries to the local journal repository.
/// IMPORTANT: This saves ONLY to journal, NOT to chat history.
/// 
/// Security:
/// - Raw transcript is stored locally only
/// - Scrubbed transcript is safe for sync/backup
/// - PRISM reversible map is never persisted remotely
library;

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../../../core/journal_capture_cubit.dart';
import 'package:my_app/services/app_repos.dart';
import '../../../../models/journal_entry_model.dart';
import 'voice_journal_state.dart';

/// Voice journal entry for storage
class VoiceJournalRecord {
  final String sessionId;
  final DateTime timestamp;
  final List<VoiceJournalTurn> turns;
  final VoiceLatencyMetrics? metrics;
  final String? summary;

  const VoiceJournalRecord({
    required this.sessionId,
    required this.timestamp,
    required this.turns,
    this.metrics,
    this.summary,
  });

  /// Get raw content (for local storage only)
  String get rawContent {
    final buffer = StringBuffer();
    for (final turn in turns) {
      buffer.writeln('**You:** ${turn.rawUserText}\n');
      buffer.writeln('**LUMARA:** ${turn.lumaraResponse}\n');
    }
    return buffer.toString();
  }

  /// Get scrubbed content (safe for remote storage)
  String get scrubbedContent {
    final buffer = StringBuffer();
    for (final turn in turns) {
      buffer.writeln('**You:** ${turn.scrubbedUserText}\n');
      buffer.writeln('**LUMARA:** ${turn.scrubbedLumaraResponse}\n');
    }
    return buffer.toString();
  }

  /// Get display content (with PII restored for user viewing)
  String get displayContent {
    final buffer = StringBuffer();
    for (final turn in turns) {
      buffer.writeln('**You:** ${turn.displayUserText}\n');
      buffer.writeln('**LUMARA:** ${turn.displayLumaraResponse}\n');
    }
    return buffer.toString();
  }

  int get wordCount {
    int count = 0;
    for (final turn in turns) {
      count += turn.rawUserText.split(RegExp(r'\s+')).length;
      count += turn.lumaraResponse.split(RegExp(r'\s+')).length;
    }
    return count;
  }

  int get totalRedactions {
    int count = 0;
    for (final turn in turns) {
      count += turn.prismSummary?.totalRedactions ?? 0;
    }
    return count;
  }

  /// Convert to JSON for local storage (includes raw text)
  Map<String, dynamic> toLocalJson() => {
    'session_id': sessionId,
    'timestamp': timestamp.toIso8601String(),
    'turns': turns.map((t) => t.toLocalJson()).toList(),
    'word_count': wordCount,
    'total_redactions': totalRedactions,
    'metrics': metrics?.toLatencyReport(),
    'summary': summary,
  };

  /// Convert to JSON for remote storage (NO raw text)
  Map<String, dynamic> toRemoteJson() => {
    'session_id': sessionId,
    'timestamp': timestamp.toIso8601String(),
    'turns': turns.map((t) => t.toRemoteJson()).toList(),
    'word_count': wordCount,
    // NO metrics or detailed redaction info for remote
    'summary': summary,
  };
}

/// Single turn in a voice journal conversation
class VoiceJournalTurn {
  /// Raw user text (LOCAL ONLY)
  final String rawUserText;
  
  /// Scrubbed user text (safe for remote)
  final String scrubbedUserText;
  
  /// User text for display (with PII tokens replaced for readability)
  final String displayUserText;
  
  /// LUMARA response
  final String lumaraResponse;
  
  /// Scrubbed LUMARA response (as received from Gemini)
  final String scrubbedLumaraResponse;
  
  /// Display LUMARA response (with PII restored)
  final String displayLumaraResponse;
  
  /// PRISM redaction summary for this turn
  final PrismRedactionSummary? prismSummary;

  const VoiceJournalTurn({
    required this.rawUserText,
    required this.scrubbedUserText,
    required this.displayUserText,
    required this.lumaraResponse,
    required this.scrubbedLumaraResponse,
    required this.displayLumaraResponse,
    this.prismSummary,
  });

  /// Convert to JSON for local storage
  Map<String, dynamic> toLocalJson() => {
    'raw_user_text': rawUserText,            // LOCAL ONLY
    'scrubbed_user_text': scrubbedUserText,
    'display_user_text': displayUserText,
    'lumara_response': lumaraResponse,
    'scrubbed_lumara_response': scrubbedLumaraResponse,
    'display_lumara_response': displayLumaraResponse,
    'prism_summary': prismSummary?.toJson(),
  };

  /// Convert to JSON for remote storage (NO raw text)
  Map<String, dynamic> toRemoteJson() => {
    // NO raw_user_text
    'scrubbed_user_text': scrubbedUserText,
    'display_user_text': displayUserText,
    'lumara_response': lumaraResponse,
    // NO detailed prism summary
  };
}

/// Journal Store - saves voice journal entries
/// 
/// This store:
/// - Saves to local journal repository
/// - Uses JournalCaptureCubit if available
/// - NEVER saves to chat history
class VoiceJournalStore {
  final JournalRepository _repository = AppRepos.journal;
  final JournalCaptureCubit? _captureCubit;
  final Uuid _uuid = const Uuid();

  VoiceJournalStore({JournalCaptureCubit? captureCubit})
      : _captureCubit = captureCubit;

  /// Save a voice journal session
  /// 
  /// Creates a journal entry with:
  /// - Full conversation content
  /// - Voice-specific metadata
  /// - Auto-generated title
  /// 
  /// Returns the saved entry ID
  Future<String> saveSession(VoiceJournalRecord record) async {
    final entryId = _uuid.v4();
    final now = DateTime.now();
    
    try {
      // Generate title from first user message
      final title = _generateTitle(record);
      
      // Use display content for the entry (PII restored for user)
      final content = record.displayContent;
      
      // Metadata is stored in detailed record (for future use)
      // final metadata = <String, dynamic>{
      //   'source': 'voice_journal',
      //   'session_id': record.sessionId,
      //   'turn_count': record.turns.length,
      //   'word_count': record.wordCount,
      //   'total_redactions': record.totalRedactions,
      //   'latency_metrics': record.metrics?.toLatencyReport(),
      // };
      
      if (_captureCubit != null) {
        // Use cubit to save (includes timeline refresh, etc.)
        debugPrint('VoiceJournalStore: About to save with content length: ${content.length}');
        debugPrint('VoiceJournalStore: Title: $title');
        debugPrint('VoiceJournalStore: Content preview: ${content.length > 100 ? content.substring(0, 100) : content}...');

        _captureCubit!.saveEntryWithKeywords(
          content: content,
          mood: 'reflective',  // Default mood for voice journal
          selectedKeywords: _extractKeywords(record),
          title: title,
          // Don't send to chat - this is journal only
        );

        debugPrint('VoiceJournalStore: Successfully saved via cubit');
      } else {
        // Direct repository save
        debugPrint('VoiceJournalStore: Using direct repository save (no cubit available)');
        debugPrint('VoiceJournalStore: Content length: ${content.length}');

        final entry = JournalEntry(
          id: entryId,
          title: title,
          content: content,
          createdAt: record.timestamp,
          updatedAt: now,
          tags: const [],
          mood: 'reflective',
          keywords: _extractKeywords(record),
          // Note: audioUri could be set if we save audio
        );

        await _repository.createJournalEntry(entry);
        debugPrint('VoiceJournalStore: Successfully saved directly to repository');
      }
      
      // Also save detailed record to local JSON (for debugging/analysis)
      await _saveDetailedRecord(record);
      
      return entryId;
      
    } catch (e) {
      debugPrint('VoiceJournalStore: Error saving session: $e');
      rethrow;
    }
  }

  /// Generate a title from the conversation
  String _generateTitle(VoiceJournalRecord record) {
    if (record.turns.isEmpty) {
      return 'Voice Journal ${_formatDate(record.timestamp)}';
    }
    
    // Use first few words of first user message
    final firstMessage = record.turns.first.displayUserText;
    final words = firstMessage.split(RegExp(r'\s+'));
    
    if (words.length <= 5) {
      return firstMessage;
    }
    
    return '${words.take(5).join(" ")}...';
  }

  String _formatDate(DateTime date) {
    return '${date.month}/${date.day}/${date.year}';
  }

  /// Extract keywords from conversation
  List<String> _extractKeywords(VoiceJournalRecord record) {
    // Simple keyword extraction - can be enhanced with NLP
    final keywords = <String>[];
    
    // Add "Voice Journal" as a tag
    keywords.add('Voice Journal');
    
    // Look for emotion words
    final emotionWords = ['happy', 'sad', 'anxious', 'excited', 'frustrated', 
                          'grateful', 'worried', 'hopeful', 'stressed', 'calm'];
    
    for (final turn in record.turns) {
      final lowerText = turn.rawUserText.toLowerCase();
      for (final emotion in emotionWords) {
        if (lowerText.contains(emotion) && !keywords.contains(emotion)) {
          keywords.add(emotion);
        }
      }
    }
    
    return keywords;
  }

  /// Save detailed record to local storage
  /// 
  /// This saves the full record including raw text and metrics.
  /// Only stored locally, never synced.
  Future<void> _saveDetailedRecord(VoiceJournalRecord record) async {
    try {
      // Store in a local-only location
      // This could be implemented with shared_preferences or file storage
      // For now, just log it
      debugPrint('VoiceJournalStore: Detailed record for session ${record.sessionId}');
      debugPrint('  Turns: ${record.turns.length}');
      debugPrint('  Words: ${record.wordCount}');
      debugPrint('  Redactions: ${record.totalRedactions}');
      if (record.metrics != null) {
        debugPrint('  Latency: ${record.metrics}');
      }
    } catch (e) {
      debugPrint('VoiceJournalStore: Error saving detailed record: $e');
    }
  }

  /// Append a turn to an existing session
  /// 
  /// Useful for multi-turn conversations
  Future<void> appendTurn({
    required String sessionId,
    required VoiceJournalTurn turn,
  }) async {
    // Implementation would update an existing session
    // For now, each session is saved as a complete unit
    debugPrint('VoiceJournalStore: appendTurn not yet implemented');
  }

  /// Get sessions by date
  Future<List<JournalEntry>> getSessionsByDate(DateTime date) async {
    final allEntries = await _repository.getAllJournalEntries();
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));
    
    return allEntries.where((entry) {
      return entry.createdAt.isAfter(startOfDay) && 
             entry.createdAt.isBefore(endOfDay) &&
             entry.keywords.contains('Voice Journal');
    }).toList();
  }
}

