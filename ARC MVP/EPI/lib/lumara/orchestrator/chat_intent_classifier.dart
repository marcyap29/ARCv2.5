// lib/lumara/orchestrator/chat_intent_classifier.dart
// Chat-based intent classification for LUMARA: routes user messages to
// reflection, research, writing, pattern, or journaling.

import 'dart:convert';

/// Chat intent types (distinct from [lumara/models/intent_type.dart] command intents).
enum ChatIntentType {
  reflection,
  research,
  writing,
  pattern,
  journaling,
}

/// Classified user intent with confidence and parameters.
class UserIntent {
  final ChatIntentType type;
  final String originalMessage;
  final Map<String, dynamic> parameters;
  final Duration estimatedDuration;
  final double confidence;

  const UserIntent({
    required this.type,
    required this.originalMessage,
    this.parameters = const {},
    required this.estimatedDuration,
    required this.confidence,
  });
}

/// LLM call signature for intent classification.
typedef ChatIntentLlmGenerate = Future<String> Function({
  required String systemPrompt,
  required String userPrompt,
  int? maxTokens,
});

/// Classifies user chat messages into intent for agent routing.
class ChatIntentClassifier {
  final ChatIntentLlmGenerate _generate;

  ChatIntentClassifier({required ChatIntentLlmGenerate generate}) : _generate = generate;

  static const String _systemPrompt = r'''
You are LUMARA's intent classifier. Classify user messages into intent types.

## INTENT TYPES

**reflection** - Normal conversation, thinking out loud, processing emotions
Examples: "I'm feeling uncertain about the SBIR deadline", "Help me think through this decision"

**research** - Requests to investigate topics, gather information, analyze landscapes
Triggers: "research", "investigate", "analyze", "find out about", "what do we know about"
Examples: "Research SBIR requirements", "Investigate competitive landscape for AI memory systems"

**writing** - Requests to create content (LinkedIn, articles, docs)
Triggers: "write", "draft", "create a post", "compose"
Examples: "Write a LinkedIn post about CHRONICLE", "Draft an article on temporal intelligence"

**pattern** - Requests to analyze historical patterns across time (future)
Triggers: "when have I", "what patterns", "analyze my history"
Examples: "When have I felt like this before?", "What patterns emerge in Transition phase?"

**journaling** - Explicit journal entry creation
Triggers: "journal entry", "record that", "add to journal"

## CONFIDENCE SCORING
- 0.9+ : Very clear trigger words, unambiguous
- 0.7-0.9 : Strong indicators but some ambiguity
- 0.5-0.7 : Weak signals, could be multiple types
- < 0.5 : Very ambiguous, default to reflection

## PARAMETERS TO EXTRACT

For research:
- depth: "brief", "comprehensive", "deep"
- scope: specific topics mentioned
- urgency: time sensitivity

For writing:
- content_type: "linkedin", "substack", "technical"
- topic: what it's about
- context: any research to reference

## OUTPUT FORMAT (valid JSON only, no markdown)
{
  "type": "research|writing|pattern|reflection|journaling",
  "confidence": 0.95,
  "estimated_minutes": 10,
  "parameters": {},
  "reasoning": "Brief explanation"
}
''';

  Future<UserIntent> classifyIntent(String message) async {
    final userPrompt = 'User message: "${message.replaceAll('"', '\\"')}"\n\nClassify this intent now. Reply with only the JSON object.';
    String raw;
    try {
      raw = await _generate(
        systemPrompt: _systemPrompt,
        userPrompt: userPrompt,
        maxTokens: 400,
      );
    } catch (e) {
      return UserIntent(
        type: ChatIntentType.reflection,
        originalMessage: message,
        estimatedDuration: const Duration(minutes: 1),
        confidence: 0.0,
      );
    }
    return _parseResponse(raw.trim(), message);
  }

  UserIntent _parseResponse(String raw, String originalMessage) {
    try {
      // Strip markdown code block if present
      String jsonStr = raw;
      if (jsonStr.contains('```')) {
        final start = jsonStr.indexOf('{');
        final end = jsonStr.lastIndexOf('}');
        if (start != -1 && end != -1 && end > start) {
          jsonStr = jsonStr.substring(start, end + 1);
        }
      }
      final map = _parseJsonObject(jsonStr);
      if (map == null) {
        return _fallback(originalMessage);
      }
      final typeStr = (map['type'] as String? ?? 'reflection').toString().toLowerCase();
      final confidence = (map['confidence'] is num)
          ? (map['confidence'] as num).toDouble()
          : 0.5;
      final estimatedMinutes = (map['estimated_minutes'] is num)
          ? (map['estimated_minutes'] as num).toInt()
          : 5;
      final parameters = map['parameters'] is Map<String, dynamic>
          ? map['parameters'] as Map<String, dynamic>
          : <String, dynamic>{};
      return UserIntent(
        type: _parseIntentType(typeStr),
        originalMessage: originalMessage,
        parameters: parameters,
        estimatedDuration: Duration(minutes: estimatedMinutes.clamp(1, 60)),
        confidence: confidence.clamp(0.0, 1.0),
      );
    } catch (_) {
      return _fallback(originalMessage);
    }
  }

  Map<String, dynamic>? _parseJsonObject(String s) {
    try {
      final decoded = jsonDecode(s) as Map<String, dynamic>?;
      return decoded;
    } catch (_) {
      return null;
    }
  }

  ChatIntentType _parseIntentType(String typeString) {
    switch (typeString.toLowerCase()) {
      case 'research':
        return ChatIntentType.research;
      case 'writing':
        return ChatIntentType.writing;
      case 'pattern':
        return ChatIntentType.pattern;
      case 'journaling':
        return ChatIntentType.journaling;
      default:
        return ChatIntentType.reflection;
    }
  }

  UserIntent _fallback(String originalMessage) {
    return UserIntent(
      type: ChatIntentType.reflection,
      originalMessage: originalMessage,
      estimatedDuration: const Duration(minutes: 2),
      confidence: 0.5,
    );
  }
}
