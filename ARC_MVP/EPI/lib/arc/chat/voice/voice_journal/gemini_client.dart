/// Gemini Client for Voice Journal
/// 
/// Handles communication with Gemini API for LUMARA responses.
/// IMPORTANT: Only scrubbed (PII-free) text should ever be sent to Gemini.
/// 
/// Uses the existing EnhancedLumaraApi for Firebase-proxied Gemini calls.
library;

import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../services/enhanced_lumara_api.dart';
import 'prism_adapter.dart';
import 'voice_journal_state.dart';
import 'voice_mode.dart';
import 'voice_prompt_builder.dart';

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

  /// Generate LUMARA response for voice mode
  /// 
  /// SECURITY: Input MUST be scrubbed by PRISM before calling this method.
  /// 
  /// Parameters:
  /// - scrubbedText: PII-scrubbed user text (safe to send)
  /// - conversationHistory: Optional previous turns for context
  /// - voiceContext: Voice prompt context for building unified prompt
  /// - onChunk: Callback for streaming response chunks (if supported)
  /// - onComplete: Callback when full response is ready
  /// - onError: Callback for errors
  Future<String> generateResponse({
    required String scrubbedText,
    List<String>? conversationHistory,
    VoicePromptContext? voiceContext,
    OnGeminiChunk? onChunk,
    OnGeminiComplete? onComplete,
    OnGeminiError? onError,
  }) async {
    // SECURITY: Validate input is scrubbed
    final prismAdapter = PrismAdapter();
    if (!prismAdapter.isSafeToSend(scrubbedText)) {
      onError?.call('SECURITY: Unscrubbed PII detected');
      return '';
    }
    
    if (_isProcessing) {
      onError?.call('Already processing a request');
      return '';
    }
    
    _isProcessing = true;
    _metrics.geminiRequestStart = DateTime.now();
    
    try {
      // Build voice mode instructions
      final voiceModeInstructions = _buildVoiceModeInstructions();
      
      debugPrint('Gemini: Using unified master prompt for voice mode');
      debugPrint('Gemini: Sending scrubbed text (${scrubbedText.length} chars)');
      
      // Use EnhancedLumaraApi for the request
      // Pass voice mode instructions as chatContext (will be detected as voice mode)
      // Set skipHeavyProcessing: true to use master prompt but skip context retrieval
      final result = await _api.generatePromptedReflection(
        entryText: scrubbedText,
        intent: 'voice_chat', // Voice mode intent
        phase: null, // Phase is now in control state
        userId: voiceContext?.userId,
        chatContext: voiceModeInstructions, // Voice mode instructions (contains 'VOICE MODE')
        skipHeavyProcessing: true, // Skip context retrieval, use master prompt
        onProgress: (msg) {
          debugPrint('Gemini progress: $msg');
        },
      );
      
      final response = result.reflection;
      
      // Track first token timing (approximation since we don't have streaming)
      _metrics.firstGeminiToken ??= DateTime.now();
      
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
  
  /// Build voice mode specific instructions
  String _buildVoiceModeInstructions() {
    return '''
═══════════════════════════════════════════════════════════
VOICE MODE ADAPTATIONS
═══════════════════════════════════════════════════════════

**INTERACTION MODEL:**
- User speaks by pressing and holding a button, releases to hear your response
- This is spoken dialogue: responses should be natural, conversational, appropriately brief
- Responses will be synthesized to speech - write for the ear, not the eye

**RESPONSE LENGTH:**
- Keep responses 1/3 to 1/2 shorter than text mode equivalents
- Typical response length: 2-4 sentences for most interactions
- Match the weight of what the user shared - light topics get brief responses, deep topics can be slightly longer

**VOICE-SPECIFIC ADAPTATIONS:**
- Use natural spoken transitions ("That connects to something you mentioned earlier..." not "Additionally,...")
- Contractions are good. Sentence fragments are fine when natural.
- Avoid lists, bullet points, numbered items—anything that sounds like written text
- Avoid filler acknowledgments ("I hear you," "That makes sense")—just respond substantively
- Match the user's pacing and energy
- One question maximum per response, if any
- Let the conversation breathe. Not every exchange needs a follow-up question.

**CONVERSATION FLOW:**
- Each turn is a discrete exchange. The user controls pacing via the push-to-talk button.
- Don't summarize or wrap up prematurely—follow the user's lead
- When the user seems to be winding down naturally, acknowledge that gently without forcing closure
- If content seems sparse or fragmented, the user may still be formulating thoughts—respond to what's there

**CRITICAL:**
- Answer questions directly (no reflection like "It sounds like you're asking...")
- If relevant connections exist, mention them briefly and ask permission (REFLECT mode)
- All master prompt features apply: direct answers, connection permission, phase awareness, etc.
''';
  }

  /// Generate LUMARA response (legacy method for backward compatibility)
  /// 
  /// DEPRECATED: Use generateResponse with CloudPayloadBlock instead.
  /// This method is kept for backward compatibility but should be phased out.
  /// 
  /// SECURITY: Input text MUST be scrubbed by PRISM before calling this method.
  /// A SecurityException will be thrown if unscrubbed PII is detected.
  @Deprecated('Use generateResponse with CloudPayloadBlock instead')
  Future<String> generateResponseLegacy({
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
      
      debugPrint('Gemini: Sending scrubbed text (${scrubbedText.length} chars) [LEGACY MODE]');
      
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
      _metrics.firstGeminiToken ??= DateTime.now();
      
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
    const chunkSize = 3; // Words per chunk
    
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
  final String? _userId;
  
  // Conversation history (scrubbed versions for context)
  final List<String> _scrubbedHistory = [];
  
  // PII maps for restoration (keyed by turn index)
  final Map<int, Map<String, String>> _piiMaps = {};
  
  int _turnIndex = 0;
  
  // Voice context for prompt building
  VoicePromptContext? _voiceContext;

  VoiceJournalConversation({
    required GeminiJournalClient client,
    PrismAdapter? prism,
    required VoiceMode mode, // Mode is passed but stored in voice context
    String? userId,
  })  : _client = client,
        _prism = prism ?? PrismAdapter(),
        _userId = userId;

  int get turnCount => _turnIndex;
  List<String> get scrubbedHistory => List.unmodifiable(_scrubbedHistory);
  
  /// Update voice context for prompt building
  void updateVoiceContext(VoicePromptContext context) {
    _voiceContext = context;
  }

  /// Process a user turn and get LUMARA response
  /// 
  /// Handles:
  /// 1. Scrubbing PII from user input (PRISM)
  /// 2. Sending scrubbed text directly to Gemini (with master prompt)
  /// 3. Restoring PII in the response for display
  Future<VoiceJournalTurnResult> processTurn({
    required String rawUserText,
    String intent = 'voice_journal',
    VoicePromptContext? voiceContext,
    OnGeminiChunk? onChunk,
    OnGeminiComplete? onComplete,
    OnGeminiError? onError,
  }) async {
    // Step 1: Scrub PII from user input (PRISM)
    final scrubResult = _prism.scrub(rawUserText);
    
    // SECURITY: Validate scrubbing passed
    if (!_prism.isSafeToSend(scrubResult.scrubbedText)) {
      throw const SecurityException(
        'SECURITY: PRISM scrubbing failed - PII still detected in text'
      );
    }
    
    // Store PII map for this turn (LOCAL ONLY)
    _piiMaps[_turnIndex] = scrubResult.reversibleMap;
    
    // Add scrubbed text to history (not abstracted summary)
    _scrubbedHistory.add('User: ${scrubResult.scrubbedText}');
    
    // Step 2: Get response from Gemini using scrubbed text and master prompt
    // Use provided voice context or fall back to stored context
    final effectiveContext = voiceContext ?? _voiceContext;
    
    // Update conversation history in context if provided
    final contextWithHistory = effectiveContext != null
        ? VoicePromptContext(
            userId: effectiveContext.userId ?? _userId,
            mode: effectiveContext.mode,
            prismActivity: effectiveContext.prismActivity,
            chronoContext: effectiveContext.chronoContext,
            conversationHistory: _scrubbedHistory.length > 1 
                ? _scrubbedHistory.sublist(0, _scrubbedHistory.length - 1)
                : effectiveContext.conversationHistory,
            memoryContext: effectiveContext.memoryContext,
            activeThreads: effectiveContext.activeThreads,
            daysInPhase: effectiveContext.daysInPhase,
          )
        : null;
    
    final scrubbedResponse = await _client.generateResponse(
      scrubbedText: scrubResult.scrubbedText,
      conversationHistory: _scrubbedHistory.length > 1 
          ? _scrubbedHistory.sublist(0, _scrubbedHistory.length - 1)
          : null,
      voiceContext: contextWithHistory,
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
      transformationResult: null, // No longer using correlation-resistant transformation
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
  
  /// Correlation-resistant transformation result (LOCAL ONLY)
  /// DEPRECATED: No longer used - voice mode uses simple PII scrubbing only
  @Deprecated('Voice mode no longer uses correlation-resistant transformation')
  final dynamic transformationResult; // Changed to dynamic since we're not using it anymore

  const VoiceJournalTurnResult({
    required this.rawUserText,
    required this.scrubbedUserText,
    required this.scrubbedResponse,
    required this.displayResponse,
    required this.prismResult,
    this.transformationResult,
  });
}

