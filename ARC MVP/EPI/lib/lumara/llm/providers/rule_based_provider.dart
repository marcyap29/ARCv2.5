// lib/lumara/llm/providers/rule_based_provider.dart
// Rule-based fallback provider implementation

import '../llm_provider.dart';
import '../../config/api_config.dart';

/// Rule-based fallback provider
class RuleBasedProvider extends LLMProviderBase {
  RuleBasedProvider(LumaraAPIConfig apiConfig) : super(apiConfig, 'Rule-Based Responses', true);

  @override
  LLMProvider getProviderType() => LLMProvider.ruleBased;

  @override
  Future<bool> isAvailable() async {
    return true; // Always available as fallback
  }

  @override
  Future<String> generateResponse(Map<String, dynamic> context) async {
    final intent = context['intent'] as String;
    final phase = context['phase'] as String?;

    // Generate contextual response based on intent and phase
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

  @override
  Map<String, dynamic> getStatus() {
    return {
      ...super.getStatus(),
      'isAvailable': true,
      'type': 'fallback',
    };
  }
}
