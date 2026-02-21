// lib/lumara/services/reflective_prompt_generator.dart
// Generate contextual prompts from matched nodes

import '../models/reflective_node.dart';

class ReflectivePromptGenerator {
  List<String> generatePrompts({
    required String currentEntry,
    required List<MatchedNode> matches,
    required String intent,
    PhaseHint? currentPhase,
  }) {
    if (matches.isEmpty) {
      return _fallbackPrompts(intent, currentPhase);
    }
    
    final prompts = <String>[];
    
    // Template 1: Temporal connection
    if (matches.isNotEmpty) {
      final topMatch = matches.first;
      final dateStr = _formatApproxDate(topMatch.approxDate);
      prompts.add(
        "You explored something similar around $dateStr. "
        "What from that moment still feels useful now?"
      );
    }
    
    // Template 2: Keyword/theme resonance
    if (matches.length > 1) {
      final keywords = _extractCommonKeywords(matches);
      if (keywords.isNotEmpty) {
        prompts.add(
          "You highlighted '${keywords.first}' before. "
          "Does that value feel relevant today?"
        );
      }
    }
    
    // Template 3: Phase-aware reflection
    if (currentPhase != null) {
      prompts.add(_generatePhasePrompt(currentPhase, matches));
    }
    
    // Template 4: Cross-modal pattern
    if (_hasMultipleModalTypes(matches)) {
      prompts.add(
        "This theme appears across your writing and media. "
        "What pattern do you notice emerging?"
      );
    }
    
    return prompts.take(3).toList();
  }
  
  String _generatePhasePrompt(PhaseHint phase, List<MatchedNode> matches) {
    switch (phase) {
      case PhaseHint.recovery:
        return "If this is a recovery moment, what do you want to carry forward, and what can be set down?";
      case PhaseHint.breakthrough:
        return "Earlier breakthroughs often come back in new forms. What feels familiar and what feels new this time?";
      case PhaseHint.consolidation:
        return "When this tone showed up before, you moved toward clarity. Does that direction still feel right?";
      case PhaseHint.transition:
        return "This feels like a transition moment. What from your past transitions can guide you now?";
      case PhaseHint.expansion:
        return "You're in an expansion phase. What new possibilities are calling to you?";
      case PhaseHint.discovery:
        return "What are you discovering about yourself in this moment?";
    }
  }
  
  List<String> _fallbackPrompts(String intent, PhaseHint? phase) {
    // Return generic but meaningful prompts when no matches
    return [
      "This feels like a starting point for something new. What are you noticing?",
      "What would it look like to trust yourself completely in this moment?",
    ];
  }
  
  String _formatApproxDate(DateTime? date) {
    if (date == null) return "a past moment";
    
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inDays < 7) {
      return "this week";
    } else if (difference.inDays < 30) {
      return "last month";
    } else if (difference.inDays < 365) {
      final months = (difference.inDays / 30).round();
      return "$months months ago";
    } else {
      final years = (difference.inDays / 365).round();
      return "$years years ago";
    }
  }
  
  List<String> _extractCommonKeywords(List<MatchedNode> matches) {
    final keywordCounts = <String, int>{};
    
    for (final match in matches) {
      if (match.excerpt != null) {
        final words = match.excerpt!
            .toLowerCase()
            .replaceAll(RegExp(r'[^\w\s]'), ' ')
            .split(RegExp(r'\s+'))
            .where((word) => word.length > 3)
            .toList();
        
        for (final word in words) {
          keywordCounts[word] = (keywordCounts[word] ?? 0) + 1;
        }
      }
    }
    
    // Return top 3 most common keywords
    final sortedKeywords = keywordCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    return sortedKeywords.take(3).map((e) => e.key).toList();
  }
  
  bool _hasMultipleModalTypes(List<MatchedNode> matches) {
    final types = matches.map((m) => m.sourceType).toSet();
    return types.length > 1;
  }
}