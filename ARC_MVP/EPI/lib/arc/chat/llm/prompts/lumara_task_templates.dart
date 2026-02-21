/// LUMARA Task Templates for On-Device LLMs
/// 
/// Provides structured task wrappers that help small models produce better outputs

class LumaraTaskTemplates {
  static const String generalChat = '''
[TASK]
type: answer
goal: Provide a direct, accurate answer with minimal steps.
format: title + 3–6 bullets + tiny Next steps.
''';

  static const String summarizeText = '''
[TASK]
type: summarize
goal: 5-bullet summary + 1-sentence takeaway.
constraints: retain numbers, entities, and dates.
''';

  static const String rewriteText = '''
[TASK]
type: rewrite
goal: Rewrite for clarity and steady tone. No em dashes.
deliverables:
- REWRITE (final text)
- CHANGES (3 bullets)
''';

  static const String createPlan = '''
[TASK]
type: plan
goal: 5-step plan, each step one sentence with [ ] checkbox.
include: Risks (1–2 bullets), Success criteria (1–2 bullets).
''';

  static const String extractKeywords = '''
[TASK]
type: extract_keywords
goal: Return 7–10 keywords ranked with scores 0–1.
format:
1) table: keyword | score | why
2) one-line theme
''';

  static const String reflectJournal = '''
[TASK]
type: reflect
goal: Provide a concise reflection and one follow-up prompt for journaling.
format: Reflection (2-3 sentences) + Journal prompt (1 question).
''';

  static const String analyzePatterns = '''
[TASK]
type: analyze
goal: Analyze patterns in the provided context and suggest insights.
format: Pattern (1-2 sentences) + Insight (1-2 sentences) + Action (1-2 bullets).
''';

  /// Task type shortcuts for intent routing
  static const Map<String, String> taskShortcuts = {
    'explain': generalChat,
    'what': generalChat,
    'why': generalChat,
    'how': generalChat,
    'summarize': summarizeText,
    'tl;dr': summarizeText,
    'key points': summarizeText,
    'rewrite': rewriteText,
    'polish': rewriteText,
    'make clearer': rewriteText,
    'plan': createPlan,
    'steps': createPlan,
    'roadmap': createPlan,
    'tags': extractKeywords,
    'keywords': extractKeywords,
    'themes': extractKeywords,
    'reflect': reflectJournal,
    'journal': reflectJournal,
    'analyze': analyzePatterns,
    'patterns': analyzePatterns,
  };

  /// Get task template by type
  static String getTaskTemplate(String taskType) {
    return taskShortcuts[taskType.toLowerCase()] ?? generalChat;
  }

  /// Detect task type from user message
  static String detectTaskType(String userMessage) {
    final message = userMessage.toLowerCase();
    
    // Check for specific keywords
    for (final entry in taskShortcuts.entries) {
      if (message.contains(entry.key)) {
        return entry.key;
      }
    }
    
    // Default to general chat
    return 'explain';
  }
}
