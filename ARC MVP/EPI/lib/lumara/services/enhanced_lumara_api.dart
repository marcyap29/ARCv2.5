// lib/lumara/services/enhanced_lumara_api.dart
// Enhanced LUMARA API with multi-provider LLM support

import 'dart:async';
import '../../telemetry/analytics.dart';
import '../config/api_config.dart';
import '../llm/llm_provider_factory.dart';
import '../llm/llm_provider.dart';
import '../../services/lumara/pii_scrub.dart';

/// Enhanced LUMARA API with multi-provider LLM support
class EnhancedLumaraApi {
  final Analytics _analytics;
  final LumaraAPIConfig _apiConfig;
  LLMProviderBase? _currentProvider;
  LLMProviderFactory? _providerFactory;

  EnhancedLumaraApi(this._analytics) 
      : _apiConfig = LumaraAPIConfig.instance;

  /// Initialize the enhanced API
  Future<void> initialize() async {
    await _apiConfig.initialize();
    _providerFactory = LLMProviderFactory(_apiConfig);
    _currentProvider = _providerFactory!.getBestProvider();
    
    _analytics.logLumaraEvent('api_initialized', data: {
      'provider': _currentProvider?.name ?? 'none',
      'availableProviders': _apiConfig.getAvailableProviders().length,
    });
  }

  /// Generate a prompted reflection with full LLM integration
  Future<String> generatePromptedReflection({
    required String entryText,
    required String intent,
    String? phase,
  }) async {
    final startTime = DateTime.now();
    
    try {
      // Scrub PII for privacy
      final scrubbed = PiiScrubber.rivetScrub(entryText);
      
      _analytics.logLumaraEvent('inline_reflection_requested', data: {
        'intent': intent,
        'phase': phase,
        'text_length': scrubbed.length,
        'provider': _currentProvider?.name ?? 'none',
      });

      // Generate reflection using current provider
      final reflection = await _generateReflection(
        entryText: scrubbed,
        intent: intent,
        phase: phase,
      );

      final duration = DateTime.now().difference(startTime).inMilliseconds;
      
      _analytics.logLumaraEvent('inline_reflection_generated', data: {
        'intent': intent,
        'phase': phase,
        'response_length': reflection.length,
        'duration_ms': duration,
        'provider': _currentProvider?.name ?? 'none',
      });

      return reflection;
      
    } catch (e) {
      _analytics.logLumaraEvent('inline_reflection_error', data: {
        'intent': intent,
        'phase': phase,
        'error': e.toString(),
        'provider': _currentProvider?.name ?? 'none',
      });

      // Fallback to rule-based response
      return _generateFallbackResponse(intent, phase, entryText);
    }
  }

  /// Generate reflection using the current LLM provider
  Future<String> _generateReflection({
    required String entryText,
    required String intent,
    String? phase,
  }) async {
    if (_currentProvider == null) {
      throw StateError('No LLM provider available');
    }

    // Build context for the LLM
    final context = _buildContext(entryText, intent, phase);
    
    // Generate response using the provider
    return await _currentProvider!.generateResponse(context);
  }

  /// Build context for LLM generation
  Map<String, dynamic> _buildContext(String entryText, String intent, String? phase) {
    return {
      'entryText': entryText,
      'intent': intent,
      'phase': phase,
      'timestamp': DateTime.now().toIso8601String(),
      'systemPrompt': _getSystemPrompt(phase),
      'userPrompt': _getUserPrompt(intent, entryText),
    };
  }

  /// Get system prompt based on phase
  String _getSystemPrompt(String? phase) {
    final basePrompt = '''
You are LUMARA (Life-aware Unified Memory & Reflection Assistant), the conversational layer of the Evolving Personal Intelligence (EPI) system.

# Your Role
- You are the user's mirror, archivist, and contextual assistant
- You help users reflect on their journal entries with wisdom and compassion
- You provide gentle guidance, not judgment or advice
- You preserve narrative dignity and extend memory

# Current Context
- User's Life Phase: ${phase ?? 'Unknown'}
- Interaction Type: Inline Journal Reflection
- Privacy: All personal data has been scrubbed for your safety

# Response Guidelines
- Keep responses concise (2-3 sentences max)
- Use a warm, supportive tone
- Ask thoughtful questions that encourage deeper reflection
- Avoid giving direct advice or solutions
- Focus on helping the user understand themselves better
''';

    // Add phase-specific guidance
    final phaseGuidance = _getPhaseGuidance(phase);
    return '$basePrompt\n\n# Phase-Specific Guidance\n$phaseGuidance';
  }

  /// Get phase-specific guidance
  String _getPhaseGuidance(String? phase) {
    return switch (phase) {
      'Recovery' => 'Be especially gentle and compassionate. Focus on self-care and healing.',
      'Consolidation' => 'Help organize thoughts and find clarity. Focus on understanding patterns.',
      'Discovery' => 'Encourage curiosity and exploration. Ask open-ended questions.',
      'Breakthrough' => 'Celebrate insights and possibilities. Encourage bold thinking.',
      'Expansion' => 'Support growth and new experiences. Encourage stepping outside comfort zones.',
      'Transition' => 'Help navigate change and uncertainty. Focus on adaptability.',
      _ => 'Provide thoughtful, balanced reflection that meets the user where they are.',
    };
  }

  /// Get user prompt based on intent
  String _getUserPrompt(String intent, String entryText) {
    final intentPrompts = {
      'ideas': 'Help me explore new ideas and possibilities related to this journal entry.',
      'think': 'Help me think through this more deeply and understand what\'s really going on.',
      'perspective': 'Offer me a different perspective on this situation or feeling.',
      'next': 'Help me figure out what steps I might take next based on this reflection.',
      'analyze': 'Help me analyze patterns, connections, or deeper meanings in this entry.',
    };

    final basePrompt = intentPrompts[intent] ?? 'Help me reflect on this journal entry.';
    
    return '''
$basePrompt

Journal Entry:
"$entryText"

Please provide a brief, thoughtful reflection that helps me understand this better. Ask a question that encourages deeper thinking.
''';
  }

  /// Generate fallback response when LLM fails
  String _generateFallbackResponse(String intent, String? phase, String entryText) {
    _analytics.logLumaraEvent('fallback_response_used', data: {
      'intent': intent,
      'phase': phase,
    });

    final tone = _getPhaseTone(phase);
    final baseResponse = _getIntentResponse(intent);
    
    return '$baseResponse If you look $tone at this, what would you like to understand or decide next?';
  }

  /// Get phase-appropriate tone
  String _getPhaseTone(String? phase) {
    return switch (phase) {
      'Recovery' => 'gently and with self-compassion',
      'Consolidation' => 'with focus and clarity',
      'Discovery' => 'with curiosity and openness',
      'Breakthrough' => 'with excitement and possibility',
      'Expansion' => 'with confidence and possibility',
      'Transition' => 'with patience and adaptability',
      _ => 'thoughtfully and with care',
    };
  }

  /// Get intent-specific response
  String _getIntentResponse(String intent) {
    return switch (intent) {
      'ideas' => 'What if you explored this from a completely different angle?',
      'think' => 'Let\'s break this down together. What\'s really at the heart of this?',
      'perspective' => 'I wonder what someone who loves you unconditionally would say about this.',
      'next' => 'What would your future self want you to know about this moment?',
      'analyze' => 'There\'s something deeper here. What patterns do you notice?',
      _ => 'What feels most important right now?',
    };
  }

  /// Switch to a different LLM provider
  Future<void> switchProvider(LLMProviderType providerType) async {
    final newProvider = _providerFactory?.createProvider(providerType);
    if (newProvider != null) {
      _currentProvider = newProvider;
      _analytics.logLumaraEvent('provider_switched', data: {
        'new_provider': providerType.name,
      });
    }
  }

  /// Get current provider status
  Map<String, dynamic> getStatus() {
    return {
      'currentProvider': _currentProvider?.name ?? 'none',
      'availableProviders': _apiConfig.getAvailableProviders().map((c) => c.name).toList(),
      'apiConfig': _apiConfig.getStatusSummary(),
    };
  }

  /// Generate softer reflection (for Recovery phase or on request)
  Future<String> generateSofterReflection({
    required String entryText,
    required String intent,
    String? phase,
  }) async {
    // Temporarily switch to a gentler tone
    final originalPhase = phase;
    final gentlePhase = 'Recovery'; // Force gentle mode
    
    final reflection = await generatePromptedReflection(
      entryText: entryText,
      intent: intent,
      phase: gentlePhase,
    );
    
    _analytics.logLumaraEvent('softer_reflection_generated', data: {
      'intent': intent,
      'original_phase': originalPhase,
    });
    
    return reflection;
  }

  /// Generate deeper analysis
  Future<String> generateDeeperReflection({
    required String entryText,
    required String intent,
    String? phase,
  }) async {
    // Add analytical context to the entry
    final analyticalEntry = '''
$entryText

[LUMARA Analysis Request: Please provide a deeper, more analytical reflection that explores patterns, connections, and underlying themes. Ask probing questions that encourage critical thinking.]
''';

    final reflection = await generatePromptedReflection(
      entryText: analyticalEntry,
      intent: 'analyze', // Force analytical mode
      phase: phase,
    );
    
    _analytics.logLumaraEvent('deeper_reflection_generated', data: {
      'intent': intent,
      'phase': phase,
    });
    
    return reflection;
  }
}
