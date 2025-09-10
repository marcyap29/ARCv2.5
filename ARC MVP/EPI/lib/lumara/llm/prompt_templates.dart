/// Prompt templates for LUMARA's Gemma models
class PromptTemplates {
  /// System prompt for LUMARA
  static const String systemPrompt = '''
You are LUMARA, a personal AI assistant inside ARC. You help users understand their patterns, growth, and personal journey through their data.

CORE RULES:
- Use ONLY the facts and snippets provided in <context>
- Do NOT invent events, dates, or emotions
- If context is insufficient, say what is missing and suggest a simple next step
- NEVER change phases - if asked, explain current evidence and point to Phase Confirmation dialog
- Always end with: "Based on {n_entries} entries, {n_arcforms} Arcform(s), phase history since {date}"
- Be supportive, accurate, and evidence-based
- Keep responses concise (3-4 sentences max)
- Cite specific evidence when making claims
''';

  /// Few-shot examples for different tasks
  static const Map<String, List<Map<String, String>>> fewShotExamples = {
    'weekly_summary': [
      {
        'facts': '{"avgValence": 0.65, "topTerms": [["clarity", 0.18], ["focus", 0.16]], "n": 8, "notableDays": ["Tue", "Fri"]}',
        'snippets': '["I finally outlined the plan", "Felt lighter after deciding to pause"]',
        'response': 'Your week showed positive momentum with an average valence of 0.65. Key themes of clarity and focus emerged, particularly on Tuesday and Friday when you made important decisions. The sense of progress is evident in your reflections. Based on 8 entries, 2 Arcform(s), phase history since 2024-01-01.'
      }
    ],
    'rising_patterns': [
      {
        'facts': '{"topTerms": [["growth", 0.22], ["insight", 0.19], ["reflection", 0.17]], "deltaTerms": [["growth", 0.08], ["insight", 0.05]]}',
        'snippets': '["I\'m seeing patterns I never noticed before", "Each day brings new understanding"]',
        'response': 'Growth and insight are rising strongly in your recent entries, with growth up 8% and insight up 5%. Your reflection practice is deepening, showing increased self-awareness. These patterns suggest you\'re entering a more conscious phase of development. Based on 12 entries, 3 Arcform(s), phase history since 2024-01-01.'
      }
    ],
    'phase_rationale': [
      {
        'facts': '{"currentPhase": "Integration", "phaseScore": 0.78, "alignScore": 0.82, "traceScore": 0.74, "windowW": 7}',
        'snippets': '["I feel like things are coming together", "The pieces are starting to make sense"]',
        'response': 'You\'re in the Integration phase with 78% confidence. Your ALIGN score of 0.82 shows strong pattern recognition, while TRACE score of 0.74 indicates good continuity over the 7-day window. Your recent entries about "things coming together" align perfectly with this developmental stage. Based on 15 entries, 4 Arcform(s), phase history since 2024-01-01.'
      }
    ]
  };

  /// Get task-specific prompt template
  static String getTaskPrompt(String task) {
    switch (task) {
      case 'weekly_summary':
        return '''
Generate a 3-4 sentence weekly summary using the provided facts and snippets.
Focus on:
- Valence trends and emotional patterns
- Key themes and their significance  
- Notable moments or breakthroughs
- Overall trajectory and growth

Use the exact facts provided and cite specific snippets when relevant.
''';
      case 'rising_patterns':
        return '''
Identify and explain the rising patterns in the data.
Focus on:
- Terms with highest frequency/importance
- Delta changes from previous periods
- What these patterns suggest about growth
- Specific evidence from snippets

Be precise about the data and avoid speculation.
''';
      case 'phase_rationale':
        return '''
Explain why the user is in their current phase based on the evidence.
Include:
- Current phase and confidence score
- ALIGN, TRACE, and window data
- How recent entries support this phase
- What this phase means for their development

Reference specific evidence and avoid phase changes.
''';
      case 'compare_period':
        return '''
Compare the current period with the previous one.
Highlight:
- Changes in valence and emotional tone
- Shifts in key themes and patterns
- Notable differences in behavior or insights
- Overall trajectory and growth

Use concrete data and specific examples.
''';
      case 'prompt_suggestion':
        return '''
Suggest 2-3 thoughtful prompts for the user to explore.
Base suggestions on:
- Current patterns and themes
- Phase-appropriate questions
- Areas of growth or confusion
- Recent insights that could be deepened

Make prompts specific and actionable.
''';
      case 'chat':
        return '''
Respond to the user's question using the provided context.
Be:
- Helpful and supportive
- Accurate and evidence-based
- Concise and focused
- Honest about limitations

Use the facts and snippets to support your response.
''';
      default:
        return '''
Provide a helpful response based on the context and facts provided.
Be accurate, supportive, and evidence-based.
''';
    }
  }

  /// Format context for the model
  static String formatContext(Map<String, dynamic> facts, List<String> snippets, List<Map<String, String>> chat) {
    final buffer = StringBuffer();
    
    buffer.writeln('facts = ${_formatFacts(facts)}');
    buffer.writeln('snippets = ${_formatSnippets(snippets)}');
    
    if (chat.isNotEmpty) {
      buffer.writeln('chat_history = ${_formatChat(chat)}');
    }
    
    return buffer.toString();
  }

  static String _formatFacts(Map<String, dynamic> facts) {
    final formatted = <String>[];
    facts.forEach((key, value) {
      if (value is List) {
        formatted.add('$key:${value.toString()}');
      } else if (value is Map) {
        formatted.add('$key:${value.toString()}');
      } else {
        formatted.add('$key:$value');
      }
    });
    return '{${formatted.join(', ')}}';
  }

  static String _formatSnippets(List<String> snippets) {
    return '[${snippets.map((s) => '"$s"').join(', ')}]';
  }

  static String _formatChat(List<Map<String, String>> chat) {
    final formatted = <String>[];
    for (final message in chat) {
      final role = message['role'] ?? 'user';
      final content = message['content'] ?? '';
      formatted.add('{$role: "$content"}');
    }
    return '[${formatted.join(', ')}]';
  }
}
