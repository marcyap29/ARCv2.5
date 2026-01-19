/// Voice Timeline Storage
/// 
/// Saves voice sessions to timeline as JournalEntry objects
/// - Marks entries as voice conversations
/// - Formats transcript as conversation
/// - Scrubs PII via PRISM before storage (consistent with regular entries)
/// - Stores session metadata
/// - Integrates with existing timeline system

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/voice_session.dart';
import '../../../../models/journal_entry_model.dart';
import '../../../../arc/internal/mira/journal_repository.dart';
import '../../../internal/echo/prism_adapter.dart';

/// Voice Timeline Storage
/// 
/// Handles saving voice sessions to the journal/timeline
/// PII is scrubbed before storage, consistent with regular journal entries
class VoiceTimelineStorage {
  final JournalRepository _journalRepository;
  final PrismAdapter _prism;
  
  VoiceTimelineStorage({
    required JournalRepository journalRepository,
    PrismAdapter? prism,
  }) : _journalRepository = journalRepository,
       _prism = prism ?? PrismAdapter();
  
  /// Save voice session to timeline
  /// 
  /// Creates a JournalEntry with:
  /// - metadata['entryType'] = 'voice_conversation'
  /// - metadata['voiceSession'] = session details
  /// - content = formatted conversation transcript
  Future<String> saveVoiceSession(VoiceSession session) async {
    try {
      final entryId = const Uuid().v4();
      
      // Format conversation transcript
      final transcript = _formatConversationTranscript(session);
      
      // Create title from first user message
      final title = _generateTitle(session);
      
      // Build metadata
      final metadata = _buildMetadata(session);
      
      // Create JournalEntry
      final entry = JournalEntry(
        id: entryId,
        title: title,
        content: transcript,
        createdAt: session.startTime,
        updatedAt: session.endTime ?? DateTime.now(),
        tags: ['voice', 'conversation', 'lumara'],
        mood: '', // Can be inferred from phase
        phase: session.detectedPhase.name,
        autoPhase: session.detectedPhase.name,
        autoPhaseConfidence: 0.9, // High confidence for voice
        metadata: metadata,
        keywords: await _extractKeywords(session),
      );
      
      // Save to repository
      await _journalRepository.createJournalEntry(entry);
      
      debugPrint('VoiceStorage: Session saved to timeline (entry ID: $entryId)');
      return entryId;
      
    } catch (e) {
      debugPrint('VoiceStorage: Error saving session: $e');
      rethrow;
    }
  }
  
  /// Format conversation as readable transcript
  /// PII is scrubbed from user text before storage (same as regular entries)
  String _formatConversationTranscript(VoiceSession session) {
    final buffer = StringBuffer();
    
    // Add session header
    buffer.writeln('Voice Conversation with LUMARA');
    buffer.writeln('Duration: ${_formatDuration(session.totalDuration)}');
    buffer.writeln('Turns: ${session.turnCount}');
    buffer.writeln();
    buffer.writeln('---');
    buffer.writeln();
    
    // Add each turn
    for (var i = 0; i < session.turns.length; i++) {
      final turn = session.turns[i];
      
      // Add turn number for longer conversations
      if (session.turnCount > 3) {
        buffer.writeln('[Turn ${i + 1}]');
      }
      
      // Scrub PII from user text before storage (consistent with regular entries)
      final scrubbedUserText = _prism.scrub(turn.userText).scrubbedText;
      
      buffer.writeln('You: $scrubbedUserText');
      buffer.writeln();
      buffer.writeln('LUMARA: ${turn.lumaraResponse}');
      buffer.writeln();
      
      // Add separator between turns
      if (i < session.turns.length - 1) {
        buffer.writeln('---');
        buffer.writeln();
      }
    }
    
    return buffer.toString().trim();
  }
  
  /// Generate title from first user message
  /// PII is scrubbed from title (same as regular entries)
  String _generateTitle(VoiceSession session) {
    if (session.turns.isEmpty) {
      return 'Voice Conversation';
    }
    
    // Scrub PII from first user text before using as title
    final firstUserText = _prism.scrub(session.turns.first.userText).scrubbedText;
    
    // Take first sentence or first 50 characters
    String title;
    
    // Try to get first sentence
    final sentenceEnd = firstUserText.indexOf(RegExp(r'[.!?]'));
    if (sentenceEnd > 0 && sentenceEnd < 100) {
      title = firstUserText.substring(0, sentenceEnd + 1).trim();
    } else {
      // Take first 50 characters
      title = firstUserText.length > 50
          ? '${firstUserText.substring(0, 47)}...'
          : firstUserText;
    }
    
    return title;
  }
  
  /// Build metadata for voice entry
  Map<String, dynamic> _buildMetadata(VoiceSession session) {
    return {
      'entryType': 'voice_conversation',
      'voiceSession': {
        'sessionId': session.sessionId,
        'turnCount': session.turnCount,
        'totalDurationMs': session.totalDuration.inMilliseconds,
        'detectedPhase': session.detectedPhase.name,
        'startTime': session.startTime.toIso8601String(),
        'endTime': session.endTime?.toIso8601String(),
      },
      'isVoiceEntry': true,
    };
  }
  
  /// Extract keywords from conversation
  /// PII is scrubbed before keyword extraction
  Future<List<String>> _extractKeywords(VoiceSession session) async {
    // Get all text from session and scrub PII
    final allText = session.getAllText();
    final scrubbedText = _prism.scrub(allText).scrubbedText;
    
    // Simple keyword extraction (can be enhanced with NLP)
    final words = scrubbedText.toLowerCase()
        .replaceAll(RegExp(r'[^\w\s]'), '')
        .split(RegExp(r'\s+'))
        .where((w) => w.length > 3)
        .toSet()
        .toList();
    
    // Take most relevant words (simplified - could use TF-IDF)
    words.shuffle();
    return words.take(10).toList();
  }
  
  /// Format duration as human-readable string
  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    
    if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    } else {
      return '${seconds}s';
    }
  }
  
  /// Get voice entry from timeline by entry ID
  Future<JournalEntry?> getVoiceEntry(String entryId) async {
    try {
      return await _journalRepository.getJournalEntryById(entryId);
    } catch (e) {
      debugPrint('VoiceStorage: Error getting entry: $e');
      return null;
    }
  }
  
  /// Get all voice entries from timeline
  Future<List<JournalEntry>> getAllVoiceEntries() async {
    try {
      final allEntries = await _journalRepository.getAllJournalEntries();
      return allEntries.where(_isVoiceEntry).toList();
    } catch (e) {
      debugPrint('VoiceStorage: Error getting voice entries: $e');
      return [];
    }
  }
  
  /// Check if an entry is a voice conversation
  bool _isVoiceEntry(JournalEntry entry) {
    return entry.metadata?['entryType'] == 'voice_conversation' ||
           entry.metadata?['isVoiceEntry'] == true;
  }
  
  /// Get voice session details from entry metadata
  Map<String, dynamic>? getVoiceSessionDetails(JournalEntry entry) {
    if (!_isVoiceEntry(entry)) return null;
    return entry.metadata?['voiceSession'] as Map<String, dynamic>?;
  }
  
  /// Update voice entry (e.g., add notes)
  Future<void> updateVoiceEntry(String entryId, JournalEntry updatedEntry) async {
    try {
      await _journalRepository.updateJournalEntry(updatedEntry);
      debugPrint('VoiceStorage: Voice entry updated');
    } catch (e) {
      debugPrint('VoiceStorage: Error updating entry: $e');
      rethrow;
    }
  }
  
  /// Delete voice entry
  Future<void> deleteVoiceEntry(String entryId) async {
    try {
      await _journalRepository.deleteJournalEntry(entryId);
      debugPrint('VoiceStorage: Voice entry deleted');
    } catch (e) {
      debugPrint('VoiceStorage: Error deleting entry: $e');
      rethrow;
    }
  }
}

/// Helper class for voice entry statistics
class VoiceEntryStats {
  final int totalConversations;
  final int totalTurns;
  final Duration totalDuration;
  final Map<String, int> turnsByPhase;
  
  const VoiceEntryStats({
    required this.totalConversations,
    required this.totalTurns,
    required this.totalDuration,
    required this.turnsByPhase,
  });
  
  factory VoiceEntryStats.fromEntries(List<JournalEntry> voiceEntries) {
    int totalConversations = voiceEntries.length;
    int totalTurns = 0;
    Duration totalDuration = Duration.zero;
    Map<String, int> turnsByPhase = {};
    
    for (final entry in voiceEntries) {
      final sessionData = entry.metadata?['voiceSession'] as Map<String, dynamic>?;
      if (sessionData != null) {
        final turnCount = sessionData['turnCount'] as int? ?? 0;
        final durationMs = sessionData['totalDurationMs'] as int? ?? 0;
        final phase = sessionData['detectedPhase'] as String? ?? 'unknown';
        
        totalTurns += turnCount;
        totalDuration += Duration(milliseconds: durationMs);
        turnsByPhase[phase] = (turnsByPhase[phase] ?? 0) + turnCount;
      }
    }
    
    return VoiceEntryStats(
      totalConversations: totalConversations,
      totalTurns: totalTurns,
      totalDuration: totalDuration,
      turnsByPhase: turnsByPhase,
    );
  }
}
