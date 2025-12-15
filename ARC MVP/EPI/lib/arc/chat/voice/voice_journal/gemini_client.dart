/// Gemini Client for Voice Journal
/// 
/// Handles communication with Gemini API for LUMARA responses.
/// IMPORTANT: Only scrubbed (PII-free) text should ever be sent to Gemini.
/// 
/// Uses the existing EnhancedLumaraApi for Firebase-proxied Gemini calls.

import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../services/enhanced_lumara_api.dart';
import 'prism_adapter.dart';
import 'voice_journal_state.dart';

/// Configuration for Gemini client
class GeminiConfig {
  /// System prompt for voice journal context
  final String systemPrompt;
  
  /// Maximum response tokens
  final int maxTokens;
  
  /// Temperature for response generation
  final double temperature;

  const GeminiConfig({
    this.systemPrompt = '''You are LUMARA, a compassionate and insightful journaling assistant. 
You help users reflect on their thoughts and feelings through their voice journal entries.
Keep responses conversational, warm, and concise (2-3 sentences).
Ask thoughtful follow-up questions to encourage deeper reflection.
Focus on emotions, patterns, and growth opportunities.
Never repeat back what the user said verbatim.''',
    this.maxTokens = 256,
    this.temperature = 0.7,
  });
}

/// Callback types for Gemini events
typedef OnGeminiChunk = void Function(String chunk);
typedef OnGeminiComplete = void Function(String fullResponse);
typedef OnGeminiError = void Function(String error);

/// Gemini Client for Voice Journal
/// 
/// SECURITY: Always validate that input is scrubbed before sending.
/// This client will throw a SecurityException if unscrubbed PII is detected.
class GeminiJournalClient {
  final EnhancedLumaraApi _api;
  final GeminiConfig _config;
  final VoiceLatencyMetrics _metrics;
  
  bool _isProcessing = false;

  GeminiJournalClient({
    required EnhancedLumaraApi api,
    GeminiConfig config = const GeminiConfig(),
    VoiceLatencyMetrics? metrics,
  })  : _api = api,
        _config = config,
        _metrics = metrics ?? VoiceLatencyMetrics();

  bool get isProcessing => _isProcessing;

  /// Generate LUMARA response for journal entry
  /// 
  /// SECURITY: Input text MUST be scrubbed by PRISM before calling this method.
  /// A SecurityException will be thrown if unscrubbed PII is detected.
  /// 
  /// Parameters:
  /// - scrubbedText: PII-scrubbed transcript (safe to send to Gemini)
  /// - conversationHistory: Optional previous turns for context
  /// - onChunk: Callback for streaming response chunks (if supported)
  /// - onComplete: Callback when full response is ready
  /// - onError: Callback for errors
  Future<String> generateResponse({
    required String scrubbedText,
    List<String>? conversationHistory,
    OnGeminiChunk? onChunk,
    OnGeminiComplete? onComplete,
    OnGeminiError? onError,
  }) async {
    // SECURITY GUARDRAIL: Validate input is scrubbed
    VoiceJournalSecurityGuard.validateBeforeGemini(scrubbedText);
    
    if (_isProcessing) {
      onError?.call('Already processing a request');
      return '';
    }
    
    _isProcessing = true;
    _metrics.geminiRequestStart = DateTime.now();
    
    try {
      // Build context from conversation history
      String chatContext = _config.systemPrompt;
      if (conversationHistory != null && conversationHistory.isNotEmpty) {
        chatContext += '\n\nPrevious conversation:\n${conversationHistory.join("\n")}';
      }
      
      debugPrint('Gemini: Sending scrubbed text (${scrubbedText.length} chars)');
      
      // Use EnhancedLumaraApi for the request
      final result = await _api.generatePromptedReflection(
        entryText: scrubbedText,
        intent: 'voice_journal',  // Specific intent for voice journaling
        phase: null,
        userId: null,
        chatContext: chatContext,
        onProgress: (msg) {
          debugPrint('Gemini progress: $msg');
        },
      );
      
      final response = result.reflection;
      
      // Track first token timing (approximation since we don't have streaming)
      if (_metrics.firstGeminiToken == null) {
        _metrics.firstGeminiToken = DateTime.now();
      }
      
      // Simulate streaming by chunking the response
      if (onChunk != null) {
        await _simulateStreaming(response, onChunk);
      }
      
      onComplete?.call(response);
      
      _isProcessing = false;
      return response;
      
    } catch (e) {
      debugPrint('Gemini error: $e');
      _isProcessing = false;
      
      final errorMsg = 'Failed to get LUMARA response: $e';
      onError?.call(errorMsg);
      
      // Return a fallback response
      return "I'm here to listen. Could you tell me more about what's on your mind?";
    }
  }

  /// Simulate streaming by chunking the response
  /// 
  /// Since the current API doesn't support true streaming, we simulate it
  /// by breaking the response into chunks. This provides a better UX.
  Future<void> _simulateStreaming(String response, OnGeminiChunk onChunk) async {
    // Split response into words and group into chunks
    final words = response.split(' ');
    final chunkSize = 3; // Words per chunk
    
    for (int i = 0; i < words.length; i += chunkSize) {
      final end = (i + chunkSize > words.length) ? words.length : i + chunkSize;
      final chunk = words.sublist(i, end).join(' ');
      
      // Track first chunk timing
      if (i == 0 && _metrics.firstGeminiToken == null) {
        _metrics.firstGeminiToken = DateTime.now();
      }
      
      onChunk(chunk + (end < words.length ? ' ' : ''));
      
      // Small delay between chunks to simulate streaming
      await Future.delayed(const Duration(milliseconds: 50));
    }
  }

  /// Generate a quick acknowledgment (for immediate feedback)
  /// 
  /// Returns a short acknowledgment while the full response is being generated.
  String getQuickAcknowledgment() {
    final acknowledgments = [
      "I hear you...",
      "I understand...",
      "That makes sense...",
      "I'm reflecting on that...",
      "Let me think about that...",
    ];
    return acknowledgments[DateTime.now().millisecond % acknowledgments.length];
  }

  /// Cancel ongoing request (if supported)
  void cancel() {
    _isProcessing = false;
    // Note: Current API doesn't support cancellation
    // This is here for future streaming implementation
  }
}

/// Voice Journal conversation manager
/// 
/// Manages multi-turn conversations for voice journal sessions.
/// Tracks conversation history and handles PII restoration in responses.
class VoiceJournalConversation {
  final GeminiJournalClient _client;
  final PrismAdapter _prism;
  
  // Conversation history (scrubbed versions for context)
  final List<String> _scrubbedHistory = [];
  
  // PII maps for restoration (keyed by turn index)
  final Map<int, Map<String, String>> _piiMaps = {};
  
  int _turnIndex = 0;

  VoiceJournalConversation({
    required GeminiJournalClient client,
    PrismAdapter? prism,
  })  : _client = client,
        _prism = prism ?? PrismAdapter();

  int get turnCount => _turnIndex;
  List<String> get scrubbedHistory => List.unmodifiable(_scrubbedHistory);

  /// Process a user turn and get LUMARA response
  /// 
  /// Handles:
  /// 1. Scrubbing PII from user input
  /// 2. Sending scrubbed input to Gemini
  /// 3. Restoring PII in the response for display
  Future<VoiceJournalTurnResult> processTurn({
    required String rawUserText,
    OnGeminiChunk? onChunk,
    OnGeminiComplete? onComplete,
    OnGeminiError? onError,
  }) async {
    // Step 1: Scrub PII from user input
    final scrubResult = _prism.scrub(rawUserText);
    
    // Store PII map for this turn
    _piiMaps[_turnIndex] = scrubResult.reversibleMap;
    
    // Add scrubbed user text to history
    _scrubbedHistory.add('User: ${scrubResult.scrubbedText}');
    
    // Step 2: Get response from Gemini
    final scrubbedResponse = await _client.generateResponse(
      scrubbedText: scrubResult.scrubbedText,
      conversationHistory: _scrubbedHistory.length > 1 
          ? _scrubbedHistory.sublist(0, _scrubbedHistory.length - 1)
          : null,
      onChunk: onChunk,
      onComplete: onComplete,
      onError: onError,
    );
    
    // Add scrubbed response to history
    _scrubbedHistory.add('LUMARA: $scrubbedResponse');
    
    // Step 3: Restore PII in response for display
    // Note: Response may contain PII tokens that need restoration
    final displayResponse = _prism.restore(
      scrubbedResponse,
      scrubResult.reversibleMap,
    );
    
    _turnIndex++;
    
    return VoiceJournalTurnResult(
      rawUserText: rawUserText,
      scrubbedUserText: scrubResult.scrubbedText,
      scrubbedResponse: scrubbedResponse,
      displayResponse: displayResponse,
      prismResult: scrubResult,
    );
  }

  /// Clear conversation history
  void clear() {
    _scrubbedHistory.clear();
    _piiMaps.clear();
    _turnIndex = 0;
  }
}

/// Result of a single voice journal turn
class VoiceJournalTurnResult {
  /// Original user text (LOCAL ONLY - never send to server)
  final String rawUserText;
  
  /// Scrubbed user text (safe for external use)
  final String scrubbedUserText;
  
  /// Scrubbed LUMARA response (as received from Gemini)
  final String scrubbedResponse;
  
  /// Display response (with PII restored for user display)
  final String displayResponse;
  
  /// PRISM scrubbing result
  final PrismResult prismResult;

  const VoiceJournalTurnResult({
    required this.rawUserText,
    required this.scrubbedUserText,
    required this.scrubbedResponse,
    required this.displayResponse,
    required this.prismResult,
  });
}

