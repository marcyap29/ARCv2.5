// lib/arc/chat/services/lumara_intent_classifier.dart
// Keyword-based intent classification for routing chat to agents or reflection.

/// High-level intent for LUMARA chat routing.
enum LumaraIntent {
  /// Handle in chat (conversation, reflection)
  conversational,
  emotionalSupport,
  patternQuery,
  phaseQuery,
  timelineQuery,

  /// Route to agents
  writingTask,
  researchTask,

  /// Open long-form reflection mode
  longFormReflection,
}

/// Classifies user input to decide: chat vs Writing Agent vs Research Agent.
class LumaraIntentClassifier {
  LumaraIntentClassifier();

  static const _writingTriggers = [
    'write a',
    'write me',
    'draft a',
    'draft me',
    'create a',
    'help me write',
    'generate a',
    'substack',
    'linkedin post',
    'blog post',
    'article about',
    'newsletter',
    'tweet thread',
    'technical doc',
    'resume',
    'cover letter',
  ];

  static const _researchTriggers = [
    'research',
    'find information',
    'look up',
    'investigate',
    'analyze the market',
    'competitive',
    'what does the data say',
    'find sources',
    'deep dive',
    'report on',
  ];

  static final _sourceMaterialPatterns = [
    RegExp(r'.{500,}', dotAll: true),
    RegExp(r'#{1,3}\s+\w+'),
    RegExp(r'\[.+\]\(.+\)'),
    RegExp(r'^\s*[-•]\s+.+$', multiLine: true),
  ];

  LumaraIntent classify(String input) {
    final lower = input.trim().toLowerCase();
    if (lower.isEmpty) return LumaraIntent.conversational;

    final hasSourceMaterial = _containsSourceMaterial(input);
    final hasWritingTask =
        _writingTriggers.any((t) => lower.contains(t));
    final hasResearchTask =
        _researchTriggers.any((t) => lower.contains(t));

    if (hasSourceMaterial && hasWritingTask) {
      return LumaraIntent.writingTask;
    }
    if (hasWritingTask) {
      return LumaraIntent.writingTask;
    }
    if (hasResearchTask) {
      return LumaraIntent.researchTask;
    }

    return LumaraIntent.conversational;
  }

  bool _containsSourceMaterial(String input) {
    if (input.length < 500) return false;
    return _sourceMaterialPatterns.any((p) => p.hasMatch(input));
  }
}
