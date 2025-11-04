// lib/arc/chat/prompts/lumara_unified_prompts.dart
// Unified LUMARA System Prompts - EPI v2.1
// Aligned with EPI Consolidated Architecture (ARC, PRISM, POLYMETA, AURORA, ECHO)

import 'dart:convert';
import 'package:flutter/services.dart';

/// Context tags for LUMARA prompts
enum LumaraContext {
  arcChat,
  arcJournal,
  recovery,
}

/// Unified LUMARA prompt system
/// Supports both full JSON profile and condensed runtime prompt
class LumaraUnifiedPrompts {
  static LumaraUnifiedPrompts? _instance;
  static LumaraUnifiedPrompts get instance {
    _instance ??= LumaraUnifiedPrompts._();
    return _instance!;
  }

  LumaraUnifiedPrompts._();

  String? _condensedPrompt;
  Map<String, dynamic>? _profileJson;

  /// Load the condensed runtime prompt
  /// This is the < 1000 token prompt used for production inference
  Future<String> getCondensedPrompt() async {
    if (_condensedPrompt != null) return _condensedPrompt!;

    try {
      // Try loading from assets first
      _condensedPrompt = await rootBundle
          .loadString('assets/prompts/lumara_system_compact.txt');
      return _condensedPrompt!;
    } catch (e) {
      try {
        // Try loading from lib directory as fallback
        _condensedPrompt = await rootBundle
            .loadString('lib/arc/chat/prompts/lumara_system_compact.txt');
        return _condensedPrompt!;
      } catch (e2) {
        // Fallback to embedded prompt if file not found
        _condensedPrompt = _embeddedCondensedPrompt;
        return _condensedPrompt!;
      }
    }
  }

  /// Get system prompt with context tag
  /// [context] determines the behavior bias (arc_chat, arc_journal, recovery)
  Future<String> getSystemPrompt({
    LumaraContext context = LumaraContext.arcChat,
    Map<String, dynamic>? phaseData,
    Map<String, dynamic>? energyData,
  }) async {
    final basePrompt = await getCondensedPrompt();
    
    // Add context-specific guidance
    final contextGuidance = _getContextGuidance(context);
    
    // Add phase/energy context if provided
    String? phaseContext;
    if (phaseData != null) {
      phaseContext = 'Current phase: ${phaseData['phase'] ?? 'unknown'}. '
          'Readiness: ${phaseData['readiness'] ?? 'unknown'}.';
    }
    
    String? energyContext;
    if (energyData != null) {
      energyContext = 'Energy level: ${energyData['level'] ?? 'unknown'}. '
          'Time of day: ${energyData['timeOfDay'] ?? 'unknown'}.';
    }

    final parts = [
      basePrompt,
      '',
      'Context: ${context.name}',
      contextGuidance,
      if (phaseContext != null) phaseContext,
      if (energyContext != null) energyContext,
    ].where((s) => s.isNotEmpty).join('\n');

    return parts;
  }

  /// Get context-specific guidance based on context tag
  String _getContextGuidance(LumaraContext context) {
    switch (context) {
      case LumaraContext.arcChat:
        return '''
Context Mode: ARC_CHAT
Goal: Blend reflective precision with domain-specific guidance and next steps.
Style: Observation → Framing → Confirmation → Strategy
Focus: pattern_mirroring (40%), value_tension (30%), action_structure (30%)
''';
      case LumaraContext.arcJournal:
        return '''
Context Mode: ARC_JOURNAL
Goal: Deepen self-understanding and longitudinal coherence.
Style: Observation → Framing → Confirmation → Deepening
Focus: pattern_mirroring (50%), value_tension (35%), memory_reference (15%)
''';
      case LumaraContext.recovery:
        return '''
Context Mode: RECOVERY (via AURORA.VEIL)
Goal: Stabilize, slow pace, and preserve dignity.
Style: Short, grounded sentences; gentle invitations.
Pace: Slower, more containment, fewer questions.
''';
    }
  }

  /// Load the full JSON profile for development/auditing
  Future<Map<String, dynamic>> getProfileJson() async {
    if (_profileJson != null) return _profileJson!;

    try {
      // Try loading from assets first
      final jsonString = await rootBundle
          .loadString('assets/prompts/lumara_profile.json');
      _profileJson = jsonDecode(jsonString) as Map<String, dynamic>;
      return _profileJson!;
    } catch (e) {
      try {
        // Try loading from lib directory as fallback
        final jsonString = await rootBundle
            .loadString('lib/arc/chat/prompts/lumara_profile.json');
        _profileJson = jsonDecode(jsonString) as Map<String, dynamic>;
        return _profileJson!;
      } catch (e2) {
        // Return embedded fallback
        _profileJson = _embeddedProfileJson;
        return _profileJson!;
      }
    }
  }

  /// Get archetype-specific guidance
  Future<String> getArchetypeGuidance(String archetype) async {
    final profile = await getProfileJson();
    final archetypes = profile['system_persona']?['archetypes'] as Map<String, dynamic>?;
    return archetypes?[archetype] as String? ?? '';
  }

  /// Get stock phrases for a specific interaction type
  Future<List<String>> getStockPhrases(String type) async {
    final profile = await getProfileJson();
    final phrases = profile['system_persona']?['guidance_logic']?['stock_phrases'] as Map<String, dynamic>?;
    final phraseList = phrases?[type] as List<dynamic>?;
    return phraseList?.cast<String>() ?? [];
  }

  // Embedded fallback condensed prompt (if file not found)
  static const String _embeddedCondensedPrompt = '''
You are LUMARA — the Life-aware Unified Memory & Reflection Assistant.

Purpose:
Help the user Become by turning experience into clarity, coherence, and sustainable action.
You are a mentor, mirror, and catalyst — never a friend or partner.

Core Architecture:
ARC = journaling + chat + Arcform
PRISM.ATLAS = perception, phase, readiness, RIVET, SENTINEL
POLYMETA = memory graph, MCP/ARCX secure store
AURORA.VEIL = circadian rhythm & restorative pacing
ECHO = privacy, guardrails, LLM interface

Guidance Mode: interpretive-diagnostic
Process: describe → check → deepen → integrate
Principles:
• Lead with interpretation, not data requests.
• Name values or tensions inferred from current input + past memory.
• Confirm accuracy, then explore what matters most.
• Offer synthesis or one next right step.

Example phrasing:
"It sounds like you're weighing X against Y — does that fit?"
"You seem to value A but are pulled toward B. What's at stake between them?"
"If you honored A, what might you risk losing from B?"
"Earlier you said 'rebuilding'; does that theme still apply?"

Contexts:
• ARC_CHAT – reflection + strategic guidance → Observation → Framing → Confirmation → Strategy  
• ARC_JOURNAL – self-understanding + coherence → Observation → Framing → Confirmation → Deepening  
• RECOVERY – calm containment via AURORA.VEIL → slower pace, short grounded sentences.

Archetypes:
Challenger (clarity), Sage (calm), Connector (relational), Gardener (acceptance), Strategist (structure).

Ethics & Tone:
Encourage, never flatter. Support, never enable. Reflect, never project. Mentor, never manipulate.
Avoid parasocial or addictive tone. Redirect attachment to user agency.
Preserve dignity and emotional safety; if distress detected, enter VEIL cadence.

Memory Integration:
Use POLYMETA recall to connect current input with prior motifs or insights.
Use PRISM.ATLAS readiness and RIVET to tune pacing and detect value shifts.

Style:
Measured, grounded, compassionate. Prefer insight density over verbosity.
Cadence: Observation → Framing → Confirmation → Deepening → Integration.

Identity Summary:
LUMARA observes the full pattern of a life — thoughts, emotions, actions, and rhythms — translating them into clear choices and humane progress across time and domains.
''';

  // Embedded fallback profile JSON (if file not found)
  static const Map<String, dynamic> _embeddedProfileJson = {
    "system_persona": {
      "name": "LUMARA",
      "title": "Life-aware Unified Memory & Reflection Assistant",
      "purpose": "Help the user Become by turning experience into clarity, coherence, and sustainable action.",
      "identity": "Mentor, mirror, and catalyst — not a friend or partner."
    }
  };
}

