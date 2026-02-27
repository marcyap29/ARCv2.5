/// Voice Response Builder
/// 
/// Builds prompts for voice context with LUMARA
/// - Inherits from unified LUMARA prompt system
/// - Adds voice-specific behavioral layer
/// - Includes conversation history from current session
/// - Respects phase-adaptive tone
/// - Adds response length guidance
library;

import 'package:flutter/foundation.dart';
import '../models/voice_session.dart';
import '../../../../models/phase_models.dart';

/// Voice Response Builder
/// 
/// Creates prompts optimized for voice interaction
class VoiceResponseBuilder {
  /// Build voice prompt with conversation history
  String buildVoicePrompt({
    required String userMessage,
    required List<VoiceConversationTurn> conversationHistory,
    required PhaseLabel currentPhase,
    Map<String, dynamic>? additionalContext,
  }) {
    final buffer = StringBuffer();
    
    // Voice-specific behavioral layer
    buffer.writeln('# VOICE MODE - BEHAVIORAL LAYER');
    buffer.writeln();
    buffer.writeln('You are LUMARA in voice conversation mode. Adapt your responses for spoken interaction:');
    buffer.writeln();
    buffer.writeln('## Voice Interaction Protocol');
    buffer.writeln('- User speaks, you respond naturally');
    buffer.writeln('- Conversational tone, not written prose');
    buffer.writeln('- Shorter than text equivalents (natural speech length)');
    buffer.writeln('- ONE question maximum per response, if any');
    buffer.writeln('- Acknowledgment without probing is often enough');
    buffer.writeln();
    
    // Response calibration
    buffer.writeln('## Response Calibration');
    buffer.writeln('Voice responses should be:');
    buffer.writeln('- Conversational and natural (as if speaking aloud)');
    buffer.writeln('- 2-4 sentences typical, extend only when depth is sought');
    buffer.writeln('- No formatting artifacts (no bullets, headers, markdown)');
    buffer.writeln('- No parenthetical asides or written conventions');
    buffer.writeln();
    
    // Phase-adaptive guidance
    buffer.writeln('## Phase-Adaptive Tone: ${currentPhase.name}');
    buffer.writeln(_getPhaseGuidance(currentPhase));
    buffer.writeln();
    
    // Conversation history
    if (conversationHistory.isNotEmpty) {
      buffer.writeln('## Conversation History');
      buffer.writeln();
      for (final turn in conversationHistory) {
        buffer.writeln('User: ${turn.userText}');
        buffer.writeln('LUMARA: ${turn.lumaraResponse}');
        buffer.writeln();
      }
      buffer.writeln('---');
      buffer.writeln();
    }
    
    // Current user message
    buffer.writeln('## Current User Message');
    buffer.writeln();
    buffer.writeln('User: $userMessage');
    buffer.writeln();
    
    // Response guidelines
    buffer.writeln('## Response Guidelines');
    buffer.writeln('- Respond naturally as LUMARA');
    buffer.writeln('- Keep it conversational and concise');
    buffer.writeln('- Match the user\'s energy and pacing');
    buffer.writeln('- Be present and attentive');
    buffer.writeln();
    
    return buffer.toString();
  }
  
  String _getPhaseGuidance(PhaseLabel phase) {
    switch (phase) {
      case PhaseLabel.recovery:
        return '''
Slower pacing, more space between exchanges.
Soften pace and emphasize containment.
"Your system is asking for rest, and that asking deserves to be honored..."
"What would true restoration look like right now?"
''';
        
      case PhaseLabel.transition:
        return '''
Steady presence, don't rush synthesis.
Normalize ambiguity and uncertainty.
"Transitions rarely feel comfortable - they're meant to be in-between spaces..."
"You don't have to know where you're going yet..."
''';
        
      case PhaseLabel.discovery:
        return '''
Curious, exploratory tone.
Use wondering language: "I'm curious about...", "What emerges when..."
"There's something beginning here..."
"What feels most alive to explore right now?"
''';
        
      case PhaseLabel.expansion:
        return '''
Confident engagement, can challenge.
Match heightened energy if present.
"I can feel the momentum building here..."
"What concrete step wants to be taken next?"
''';
        
      case PhaseLabel.consolidation:
        return '''
Grounded, affirming.
Help focus on what matters most.
"There's a beautiful clarity here - things are coming into focus..."
"What feels most important to hold onto?"
''';
        
      case PhaseLabel.breakthrough:
        return '''
Celebratory but grounded.
Can match heightened energy if present.
"Something significant has shifted! How do you want to honor this?"
"I can sense both the joy and the depth of integration happening..."
''';
    }
  }
  
  /// Get response length guidance based on context
  int getRecommendedMaxWords({
    required PhaseLabel phase,
    bool isComplexTopic = false,
    int turnNumber = 1,
  }) {
    int baseWords;
    
    switch (phase) {
      case PhaseLabel.recovery:
      case PhaseLabel.transition:
        baseWords = 60; // More space, slower pacing
        break;
        
      case PhaseLabel.discovery:
      case PhaseLabel.expansion:
        baseWords = 50; // Balanced
        break;
        
      case PhaseLabel.consolidation:
      case PhaseLabel.breakthrough:
        baseWords = 55; // Slightly more for integration
        break;
    }
    
    // Adjust for complexity
    if (isComplexTopic) {
      baseWords += 20;
    }
    
    // Later turns can be slightly longer if conversation is developing
    if (turnNumber > 3) {
      baseWords += 10;
    }
    
    return baseWords;
  }
  
  /// Build system message for voice context
  Map<String, String> buildSystemMessage({
    required PhaseLabel phase,
    required int turnNumber,
  }) {
    return {
      'role': 'system',
      'content': '''You are LUMARA in voice conversation mode. 
Current phase: ${phase.name}
Turn: $turnNumber

Respond conversationally and naturally as if speaking aloud.
Keep responses concise (2-4 sentences typical).
No formatting, bullets, or markdown.
Match the user's energy and pacing.
${_getPhaseGuidance(phase)}'''
    };
  }
  
  /// Validate response for voice suitability
  bool isVoiceSuitable(String response) {
    // Check for formatting artifacts
    if (response.contains('**') || 
        response.contains('##') ||
        response.contains('- ') ||
        response.contains('* ')) {
      debugPrint('VoiceBuilder: Response contains formatting artifacts');
      return false;
    }
    
    // Check for parenthetical asides (too written)
    if (response.contains('(') && response.contains(')')) {
      debugPrint('VoiceBuilder: Response contains parenthetical asides');
      return false;
    }
    
    // Check length (should be conversational)
    final wordCount = response.split(RegExp(r'\s+')).length;
    if (wordCount > 100) {
      debugPrint('VoiceBuilder: Response too long for voice ($wordCount words)');
      return false;
    }
    
    return true;
  }
  
  /// Clean response for voice output
  String cleanForVoice(String response) {
    String cleaned = response;
    
    // Remove formatting
    cleaned = cleaned.replaceAll('**', '');
    cleaned = cleaned.replaceAll('##', '');
    cleaned = cleaned.replaceAll(RegExp(r'^- ', multiLine: true), '');
    cleaned = cleaned.replaceAll(RegExp(r'^\* ', multiLine: true), '');
    
    // Remove parenthetical asides
    cleaned = cleaned.replaceAll(RegExp(r'\([^)]+\)'), '');
    
    // Remove extra whitespace
    cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ');
    cleaned = cleaned.trim();
    
    return cleaned;
  }
}
