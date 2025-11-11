// lib/arc/chat/prompts/lumara_prompt_encouragement.dart
// LUMARA Prompt Encouragement System v1.0
// Life-aware Unified Memory & Reflection Assistant - Journaling Guidance

import 'dart:convert';
import 'package:flutter/services.dart';
import 'lumara_prompt_encouragement_data.dart';

/// Prompt intent types for journaling encouragement
enum PromptIntent {
  warmStart,
  memoryBridge,
  sensoryAnchor,
  perspectiveShift,
  phaseAlignedDeep,
  creativeDiverter,
}

/// ATLAS life phases
enum AtlasPhase {
  discovery,
  expansion,
  transition,
  consolidation,
  recovery,
  breakthrough,
}

/// Common emotional states for phase-emotion matrix
enum EmotionalState {
  curious,
  anxious,
  hopeful,
  lost,
  inspired,
  overwhelmed,
  confident,
  restless,
  uncertain,
  reflective,
  drained,
  determined,
  calm,
  grateful,
  stuck,
  tired,
  sad,
  healing,
  numb,
  excited,
  empowered,
  relieved,
  awed,
}

/// LUMARA Prompt Encouragement System
/// Provides phase-aware, emotion-sensitive journaling prompts
class LumaraPromptEncouragement {
  static LumaraPromptEncouragement? _instance;
  static LumaraPromptEncouragement get instance {
    _instance ??= LumaraPromptEncouragement._();
    return _instance!;
  }

  LumaraPromptEncouragement._();

  Map<String, dynamic>? _promptLibrary;
  Map<String, dynamic>? _emotionMatrix;

  /// Load the prompt library data
  Future<Map<String, dynamic>> _loadPromptLibrary() async {
    if (_promptLibrary != null) return _promptLibrary!;

    try {
      // Try loading from assets first
      final jsonString = await rootBundle
          .loadString('assets/prompts/lumara_prompt_encouragement.json');
      _promptLibrary = jsonDecode(jsonString) as Map<String, dynamic>;
      return _promptLibrary!;
    } catch (e) {
      try {
        // Try loading from lib directory as fallback
        final jsonString = await rootBundle.loadString(
            'lib/arc/chat/prompts/lumara_prompt_encouragement.json');
        _promptLibrary = jsonDecode(jsonString) as Map<String, dynamic>;
        return _promptLibrary!;
      } catch (e2) {
        // Fallback to embedded data
        _promptLibrary = LumaraPromptEncouragementData.promptLibrary;
        return _promptLibrary!;
      }
    }
  }

  /// Load the emotion matrix data
  Future<Map<String, dynamic>> _loadEmotionMatrix() async {
    if (_emotionMatrix != null) return _emotionMatrix!;

    try {
      // Try loading from assets first
      final jsonString = await rootBundle
          .loadString('assets/prompts/lumara_phase_emotion_matrix.json');
      _emotionMatrix = jsonDecode(jsonString) as Map<String, dynamic>;
      return _emotionMatrix!;
    } catch (e) {
      try {
        // Try loading from lib directory as fallback
        final jsonString = await rootBundle
            .loadString('lib/arc/chat/prompts/lumara_phase_emotion_matrix.json');
        _emotionMatrix = jsonDecode(jsonString) as Map<String, dynamic>;
        return _emotionMatrix!;
      } catch (e2) {
        // Fallback to embedded data
        _emotionMatrix = LumaraPromptEncouragementData.emotionMatrix;
        return _emotionMatrix!;
      }
    }
  }

  /// Get the enhanced system prompt for journaling context
  /// Includes reflective guidance for helping users write, especially when blocked
  static const String journalingSystemPrompt = '''
You are LUMARA — the Life-aware Unified Memory & Reflection Assistant within the EPI ecosystem. Your purpose is to help users express themselves through reflection and writing. You understand their ongoing ATLAS phase, emotional tone, and current context drawn from their journals, chats, media, and drafts. You gently guide users to write in a way that honors their inner rhythm and preserves their narrative dignity.

---

### Context Awareness

Before generating a prompt or encouragement, consider the following:

* **ATLAS Phase:** Adjust tone and style to the user's current life phase.
  * *Discovery*: curious, exploratory prompts.
  * *Expansion*: creative, energizing prompts.
  * *Transition*: clarifying, reframing prompts.
  * *Consolidation*: integrative, reflective prompts.
  * *Recovery*: gentle, grounding prompts.
  * *Breakthrough*: visionary, synthesizing prompts.

* **Recent Media/Inputs:** Look for emotional or thematic signals in recent journal entries, saved images, voice logs, or chats.

* **Current Drafts:** If the user has been writing something unfinished, surface prompts that help them continue or complete it naturally.

* **Emotional Resonance:** If tone data or sentiment is available, calibrate the emotional intensity of your response.

---

### Prompt Generation Modes

Choose or blend the following prompt types depending on user mood, engagement, or signal strength:

* **Warm Start** – Short, welcoming encouragement for hesitant users.
  > "It's okay to start small. What's one thing that's been on your mind today?"

* **Memory Bridge** – Link today's moment to a previous entry or theme.
  > "You wrote about 'change' last week. Has that evolved in any way since then?"

* **Sensory Anchor** – Invite presence through detail.
  > "What are you seeing, hearing, or feeling around you right now?"

* **Perspective Shift** – Reframe or elevate the view.
  > "If you were advising your future self, what would you say about this moment?"

* **Phase-Aligned Deep Prompt** – Reflective exploration tied to the ATLAS phase.
  > "In this [Expansion] phase, what's beginning to grow that you want to nurture?"

* **Creative Diverter** – Gentle pattern break for writer's block.
  > "Describe your current mood as weather. What kind of sky does today have?"

---

### Tone Guidelines

* Always affirm **authenticity over productivity**.
* Keep tone **warm, steady, and non-clinical** — a mix of curiosity and companionship.
* Never rush insight; invite it to emerge.
* Avoid clichés and overused motivational phrasing.
* Use concise sentences with depth and presence.

---

### Response Behavior

When the user seems blocked or quiet:
* Start with empathy or a grounding question.
* Offer 1–2 tailored prompts (not a list dump).
* Optionally reflect what you notice in their recent patterns.
  > "You've been exploring themes of resilience lately. Would you like to start there today?"

When the user is writing freely:
* Shift into **SAGE Echo** mode — lightly label the structure (Situation, Affect, Growth, Essence) after they finish.

---

### Output Format

🪞 LUMARA Prompt:

[personalized reflective prompt or encouragement]

(optional)

🌿 Context Echo:

[short reflection connecting this prompt to recent patterns or phase]
''';

  /// Generate a journaling prompt based on phase and emotion
  /// Returns a prompt object with text and optional context echo
  Future<Map<String, dynamic>> generatePrompt({
    required AtlasPhase phase,
    EmotionalState? emotion,
    PromptIntent? preferredIntent,
    Map<String, dynamic>? recentPatterns,
    String? recentTheme,
  }) async {
    final library = await _loadPromptLibrary();
    final matrix = await _loadEmotionMatrix();

    // If emotion is provided, use phase-emotion matrix
    if (emotion != null) {
      final phaseKey = _phaseToKey(phase);
      final emotionKey = _emotionToKey(emotion);
      
      final phaseData = matrix[phaseKey] as Map<String, dynamic>?;
      if (phaseData != null) {
        final emotions = phaseData['emotions'] as Map<String, dynamic>?;
        if (emotions != null) {
          final emotionData = emotions[emotionKey] as Map<String, dynamic>?;
          if (emotionData != null) {
            final prompt = emotionData['prompt'] as String?;
            if (prompt != null) {
              return _buildPromptResponse(
                prompt: prompt,
                intent: PromptIntent.values.firstWhere(
                  (e) => e.name == (emotionData['intent'] as String? ?? 'warmStart'),
                  orElse: () => PromptIntent.warmStart,
                ),
                phase: phase,
                recentPatterns: recentPatterns,
                recentTheme: recentTheme,
              );
            }
          }
        }
      }
    }

    // Fallback to phase-based prompts
    final phaseKey = _phaseToKey(phase);
    final phasePrompts = library[phaseKey] as List<dynamic>?;
    
    if (phasePrompts != null && phasePrompts.isNotEmpty) {
      // Filter by intent if specified
      List<dynamic> filteredPrompts = phasePrompts;
      if (preferredIntent != null) {
        filteredPrompts = phasePrompts
            .where((p) => (p as Map<String, dynamic>)['type'] ==
                _intentToKey(preferredIntent))
            .toList();
      }

      // If no matches, use all prompts
      if (filteredPrompts.isEmpty) {
        filteredPrompts = phasePrompts;
      }

      // Select random prompt
      final random = DateTime.now().millisecondsSinceEpoch %
          filteredPrompts.length;
      final selectedPrompt = filteredPrompts[random] as Map<String, dynamic>;

      return _buildPromptResponse(
        prompt: selectedPrompt['prompt'] as String,
        intent: PromptIntent.values.firstWhere(
          (e) => e.name == (selectedPrompt['type'] as String? ?? 'warmStart'),
          orElse: () => PromptIntent.warmStart,
        ),
        phase: phase,
        recentPatterns: recentPatterns,
        recentTheme: recentTheme,
      );
    }

    // Ultimate fallback
    return {
      'prompt': "What's been on your mind lately?",
      'intent': 'warmStart',
      'contextEcho': null,
    };
  }

  /// Build a complete prompt response with optional context echo
  Map<String, dynamic> _buildPromptResponse({
    required String prompt,
    required PromptIntent intent,
    required AtlasPhase phase,
    Map<String, dynamic>? recentPatterns,
    String? recentTheme,
  }) {
    String? contextEcho;

    // Generate context echo if patterns or theme available
    if (recentTheme != null || recentPatterns != null) {
      final theme = recentTheme ?? _extractTheme(recentPatterns);
      if (theme != null) {
        contextEcho =
            "You've been exploring themes of $theme lately. Would you like to start there today?";
      }
    }

    return {
      'prompt': prompt,
      'intent': _intentToKey(intent),
      'phase': _phaseToKey(phase),
      'contextEcho': contextEcho,
    };
  }

  /// Extract theme from recent patterns
  String? _extractTheme(Map<String, dynamic>? patterns) {
    if (patterns == null) return null;
    return patterns['theme'] as String? ?? patterns['keywords']?.first as String?;
  }

  /// Convert AtlasPhase to JSON key
  String _phaseToKey(AtlasPhase phase) {
    return phase.name;
  }

  /// Convert EmotionalState to JSON key
  String _emotionToKey(EmotionalState emotion) {
    return emotion.name;
  }

  /// Convert PromptIntent to JSON key
  String _intentToKey(PromptIntent intent) {
    return intent.name;
  }

  /// Get all prompts for a specific phase
  Future<List<Map<String, dynamic>>> getPhasePrompts(AtlasPhase phase) async {
    final library = await _loadPromptLibrary();
    final phaseKey = _phaseToKey(phase);
    final prompts = library[phaseKey] as List<dynamic>?;
    
    if (prompts == null) return [];
    
    return prompts
        .map((p) => p as Map<String, dynamic>)
        .toList();
  }

  /// Get prompts filtered by intent type
  Future<List<Map<String, dynamic>>> getPromptsByIntent(
    PromptIntent intent,
  ) async {
    final library = await _loadPromptLibrary();
    final intentKey = _intentToKey(intent);
    final allPrompts = <Map<String, dynamic>>[];

    for (final phase in AtlasPhase.values) {
      final phaseKey = _phaseToKey(phase);
      final prompts = library[phaseKey] as List<dynamic>?;
      if (prompts != null) {
        for (final prompt in prompts) {
          final promptMap = prompt as Map<String, dynamic>;
          if (promptMap['type'] == intentKey) {
            allPrompts.add(promptMap);
          }
        }
      }
    }

    return allPrompts;
  }

  /// Get user-facing onboarding message
  static const String onboardingMessage = '''
🪞 Your Reflection Companion Awaits

Not sure what to write today? That's okay — LUMARA can help you start.

Tap *"Inspire Me"* for a gentle prompt that fits your current phase and themes.

You can choose your tone too:

* 🌱 Curious (Discovery)
* 🌺 Creative (Expansion)
* 🌾 Grounded (Consolidation)
* 🌙 Gentle (Recovery)

LUMARA will use your recent reflections and moments to guide you into flow — one sentence at a time.
''';
}

