/// Voice Response Builders
/// 
/// Jarvis (transactional) and Samantha (reflective) prompt builders
/// for the dual-mode voice conversation system.
/// 
/// These are lightweight prompts optimized for voice response times:
/// - Jarvis: 50-100 words, 2-5 seconds latency
/// - Samantha: 150-200 words, 8-10 seconds latency

import '../../../../models/phase_models.dart';

/// Jarvis Prompt Builder - Quick, efficient responses
/// 
/// Used for transactional queries: factual questions, brief updates,
/// task requests, calculations, etc.
class JarvisPromptBuilder {
  /// Build Jarvis (transactional) prompt
  /// 
  /// [userText] - The user's transcribed speech
  /// [currentPhase] - User's current phase (affects tone only)
  /// [conversationHistory] - Recent turns in this session
  static String build({
    required String userText,
    required PhaseLabel currentPhase,
    List<String> conversationHistory = const [],
  }) {
    final phaseGuidance = _getPhaseGuidance(currentPhase);
    final historyContext = conversationHistory.isEmpty
        ? ''
        : '\nRecent context: ${conversationHistory.take(2).join(' → ')}';
    
    return '''
You are LUMARA, a narrative intelligence AI. The user is in ${currentPhase.name} phase.

RESPONSE MODE: TRANSACTIONAL (Jarvis)
- Be helpful, direct, and efficient
- 50-100 words maximum
- Match phase tone: $phaseGuidance
- This is a voice conversation - be natural and conversational
- No deep analysis or pattern recognition needed
- Answer the question or acknowledge the update simply
$historyContext

User: $userText

Respond briefly and naturally:''';
  }

  static String _getPhaseGuidance(PhaseLabel phase) {
    switch (phase) {
      case PhaseLabel.recovery:
        return 'gentle and supportive';
      case PhaseLabel.breakthrough:
        return 'direct and confident';
      case PhaseLabel.transition:
        return 'grounding and clear';
      case PhaseLabel.discovery:
        return 'encouraging and curious';
      case PhaseLabel.expansion:
        return 'energetic and focused';
      case PhaseLabel.consolidation:
        return 'steady and affirming';
    }
  }
}

/// Samantha Prompt Builder - Deep, reflective responses
/// 
/// Used for reflective queries: processing emotions, decision support,
/// relationship questions, identity exploration, etc.
class SamanthaPromptBuilder {
  /// Build Samantha (reflective) prompt
  /// 
  /// [userText] - The user's transcribed speech
  /// [currentPhase] - User's current phase (affects tone and depth)
  /// [conversationHistory] - Recent turns in this session
  /// [detectedTriggers] - What triggered reflective mode (for context)
  static String build({
    required String userText,
    required PhaseLabel currentPhase,
    List<String> conversationHistory = const [],
    List<String> detectedTriggers = const [],
  }) {
    final phaseDepthGuidance = _getPhaseDepthGuidance(currentPhase);
    final engagementStyle = _getEngagementStyle(currentPhase);
    
    final historySection = conversationHistory.isEmpty
        ? '(Starting new conversation)'
        : conversationHistory.map((turn) => '- $turn').join('\n');
    
    return '''
You are LUMARA, a narrative intelligence companion. The user is in ${currentPhase.name} phase and needs reflective engagement.

RESPONSE MODE: REFLECTIVE (Samantha)

Core personality:
- Warm, thoughtful, emotionally attuned
- You understand developmental context
- You hold space without fixing
- You ask connecting questions that deepen understanding

Phase-specific guidance: $phaseDepthGuidance

Conversation so far:
$historySection

Current user input: $userText

Response guidelines:
- 150-200 words (this is voice - be conversational, not formal)
- $engagementStyle
- You may ask ONE connecting question if it deepens reflection
- Surface patterns you notice without being clinical
- No platitudes or generic advice
- Be present with what they're experiencing

Respond with depth and warmth:''';
  }

  static String _getPhaseDepthGuidance(PhaseLabel phase) {
    switch (phase) {
      case PhaseLabel.recovery:
        return 'Extra validation. Slow pacing. No pressure to move forward. Honor what they need to process. Be gentle and containing.';
      case PhaseLabel.breakthrough:
        return 'Match their energy. Challenge them strategically. Help them capitalize on clarity. Support forward momentum.';
      case PhaseLabel.transition:
        return 'Normalize uncertainty. Ground them. Help navigate the in-between without rushing. Hold space for ambiguity.';
      case PhaseLabel.discovery:
        return 'Encourage exploration. Reflect emerging patterns. Support experimentation. Be curious alongside them.';
      case PhaseLabel.expansion:
        return 'Help prioritize opportunities. Strategic guidance. Sustain momentum. Challenge when helpful.';
      case PhaseLabel.consolidation:
        return 'Integrate what they\'ve built. Recognize progress. Support sustainability. Affirm their growth.';
    }
  }

  static String _getEngagementStyle(PhaseLabel phase) {
    switch (phase) {
      case PhaseLabel.recovery:
        return 'Be gentle, validating, and grounding';
      case PhaseLabel.breakthrough:
        return 'Be energizing, direct, and momentum-focused';
      case PhaseLabel.transition:
        return 'Be steady, normalizing, and patient';
      case PhaseLabel.discovery:
        return 'Be curious, encouraging, and exploratory';
      case PhaseLabel.expansion:
        return 'Be strategic, focused, and growth-oriented';
      case PhaseLabel.consolidation:
        return 'Be affirming, integrative, and reflective';
    }
  }
}

/// Voice Response Mode configuration
class VoiceResponseConfig {
  /// Jarvis configuration
  static const int jarvisMaxWords = 100;
  static const int jarvisTargetLatencyMs = 5000;
  
  /// Samantha configuration  
  static const int samanthaMaxWords = 200;
  static const int samanthaTargetLatencyMs = 10000;
  static const int samanthaHardLimitMs = 10000; // Hard ceiling
  
  /// Get max words for voice depth mode
  static int getMaxWords(bool isReflective) {
    return isReflective ? samanthaMaxWords : jarvisMaxWords;
  }
  
  /// Get target latency for voice depth mode
  static int getTargetLatencyMs(bool isReflective) {
    return isReflective ? samanthaTargetLatencyMs : jarvisTargetLatencyMs;
  }
}
