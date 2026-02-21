import '../model_adapter.dart';

/// Rule-based adapter - no LLM, uses templates
class RuleBasedAdapter implements ModelAdapter {
  @override
  Stream<String> realize({
    required String task,
    required Map<String, dynamic> facts,
    required List<String> snippets,
    required List<Map<String, String>> chat,
  }) async* {
    // Generate response from template
    final response = _generateFromTemplate(task, facts, snippets);
    
    // Stream the response word by word for consistency with other adapters
    final words = response.split(' ');
    for (int i = 0; i < words.length; i++) {
      yield words[i] + (i < words.length - 1 ? ' ' : '');
      // Small delay to simulate streaming
      await Future.delayed(const Duration(milliseconds: 30));
    }
  }

  String _generateFromTemplate(String task, Map<String, dynamic> facts, List<String> snippets) {
    switch (task) {
      case 'weekly_summary':
        return _generateWeeklySummary(facts, snippets);
      case 'rising_patterns':
        return _generateRisingPatterns(facts, snippets);
      case 'phase_rationale':
        return _generatePhaseRationale(facts, snippets);
      case 'compare':
        return _generateCompare(facts, snippets);
      case 'prompt_suggestion':
        return _generatePromptSuggestion(facts, snippets);
      default:
        return _generateDefault(facts, snippets);
    }
  }

  String _generateWeeklySummary(Map<String, dynamic> facts, List<String> snippets) {
    final avgValence = facts['avgValence'] as double? ?? 0.0;
    final topTerms = facts['topTerms'] as List<dynamic>? ?? [];
    final n = facts['n'] as int? ?? 0;
    final notableDays = facts['notableDays'] as List<String>? ?? [];

    final valenceDesc = avgValence > 0.6 ? 'positive' : avgValence > 0.4 ? 'neutral' : 'reflective';
    final termList = topTerms.take(3).map((t) => t is List ? t[0] : t.toString()).join(', ');
    
    return 'In the last 7 days your tone trended $valenceDesc (avg ${avgValence.toStringAsFixed(2)}). '
           'Rising themes: $termList. '
           '${notableDays.isNotEmpty ? 'Notable moments on ${notableDays.join(' and ')}.' : ''} '
           'Based on $n entries.';
  }

  String _generateRisingPatterns(Map<String, dynamic> facts, List<String> snippets) {
    final topTerms = facts['topTerms'] as List<dynamic>? ?? [];
    
    return 'Here are the patterns rising in your recent entries:\n\n'
           '**Top Rising Themes**:\n'
           '${topTerms.take(3).map((t) => '• ${t is List ? t[0] : t}').join('\n')}\n\n'
           '**Analysis**: These themes suggest a focus on personal growth and self-reflection. '
           'I notice you\'re developing deeper insights into your journey.';
  }

  String _generatePhaseRationale(Map<String, dynamic> facts, List<String> snippets) {
    final currentPhase = facts['currentPhase'] as String? ?? 'unknown';
    final phaseScore = facts['phaseScore'] as double? ?? 0.0;
    
    return 'You\'re currently in the **$currentPhase** phase (confidence: ${(phaseScore * 100).toInt()}%). '
           'This phase is characterized by focused reflection and growth. '
           'Your recent entries show strong alignment with this developmental stage.';
  }

  String _generateCompare(Map<String, dynamic> facts, List<String> snippets) {
    final comparison = facts['comparison'] as String? ?? 'general comparison';
    return 'Looking at your progress, $comparison. '
           'This shows meaningful growth in your reflective practice.';
  }

  String _generatePromptSuggestion(Map<String, dynamic> facts, List<String> snippets) {
    final suggestions = facts['suggestions'] as List<String>? ?? ['Continue reflecting on your patterns'];
    return 'Based on your recent entries, here are some prompts to explore:\n\n'
           '${suggestions.map((s) => '• $s').join('\n')}';
  }

  String _generateDefault(Map<String, dynamic> facts, List<String> snippets) {
    return 'I\'ve analyzed your data and found some interesting patterns. '
           'Your recent entries show thoughtful reflection and growth.';
  }
}

