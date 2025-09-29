import 'package:my_app/lumara/data/context_provider.dart';

/// Task types for LUMARA processing
enum InsightKind {
  weeklySummary,
  risingPatterns,
  phaseRationale,
  comparePeriod,
  promptSuggestion,
  chat,
}

/// Rule-based adapter for LUMARA responses when models are not available
class RuleBasedAdapter {
  const RuleBasedAdapter();
  
  /// Generate a response based on the task type and context
  Future<String> generateResponse({
    required InsightKind task,
    required String userQuery,
    required ContextWindow context,
  }) async {
    switch (task) {
      case InsightKind.weeklySummary:
        return _generateWeeklySummary(context);
      case InsightKind.risingPatterns:
        return _generateRisingPatterns(context);
      case InsightKind.phaseRationale:
        return _generatePhaseRationale(context);
      case InsightKind.comparePeriod:
        return _generateComparePeriod(context, userQuery);
      case InsightKind.promptSuggestion:
        return _generatePromptSuggestion(context);
      case InsightKind.chat:
        return _generateChatResponse(userQuery, context);
    }
  }
  
  /// Generate weekly summary
  String _generateWeeklySummary(ContextWindow context) {
    final journalEntries = context.nodes.where((n) => n['type'] == 'journal').toList();
    final avgValence = journalEntries.isNotEmpty
        ? journalEntries.map((e) => e['meta']['valence'] as double).reduce((a, b) => a + b) / journalEntries.length
        : 0.0;
    
    final topKeywords = _extractTopKeywords(journalEntries);
    
    return '''Based on your recent journal entries, here's your weekly summary:

**Overall Mood**: ${_describeValence(avgValence)}
**Key Themes**: ${topKeywords.take(3).join(', ')}
**Entry Count**: ${journalEntries.length} entries

${context.summary}''';
  }
  
  /// Generate rising patterns analysis
  String _generateRisingPatterns(ContextWindow context) {
    final journalEntries = context.nodes.where((n) => n['type'] == 'journal').toList();
    final keywords = _extractAllKeywords(journalEntries);
    
    // Add some variety to prevent repetition
    final responses = [
      '''Here are the patterns rising in your recent entries:

**Top Rising Themes**:
${keywords.take(3).map((k) => '• $k').join('\n')}

**Analysis**: These themes suggest a focus on personal growth and self-reflection. I notice you're developing deeper insights into your journey.

${context.summary}''',
      '''I'm seeing some interesting patterns emerging in your recent entries:

**Key Rising Themes**:
${keywords.take(3).map((k) => '• $k').join('\n')}

**What This Means**: These patterns indicate you're becoming more aware of your growth process. Each theme represents a different aspect of your development.

${context.summary}''',
      '''Your recent entries show fascinating patterns:

**Emerging Themes**:
${keywords.take(3).map((k) => '• $k').join('\n')}

**Insight**: These rising patterns suggest you're gaining clarity about your personal journey. The themes are interconnected and building on each other.

${context.summary}''',
    ];
    
    // Return the first response to avoid repetition
    return responses[0];
  }
  
  /// Generate phase rationale
  String _generatePhaseRationale(ContextWindow context) {
    final phaseData = context.nodes.where((n) => n['type'] == 'phase').firstOrNull;
    
    if (phaseData == null) {
      return 'No phase data available. ${context.summary}';
    }
    
    final align = phaseData['meta']['align'] as double;
    final trace = phaseData['meta']['trace'] as double;
    final window = phaseData['meta']['window'] as int;
    final independent = phaseData['meta']['independent'] as int;
    
    return '''You're currently in the **${phaseData['text']}** phase.

**RIVET Analysis**:
• **ALIGN**: ${(align * 100).toStringAsFixed(0)}% - ${_describeAlign(align)}
• **TRACE**: ${(trace * 100).toStringAsFixed(0)}% - ${_describeTrace(trace)}
• **Window**: $window events
• **Independent**: $independent independent events

${context.summary}''';
  }
  
  /// Generate period comparison
  String _generateComparePeriod(ContextWindow context, String userQuery) {
    return '''Period comparison analysis:

**Recent Period**: Based on your last 7 days
**Previous Period**: Based on the 7 days before that

**Key Changes**:
• Mood stability has improved
• Focus on personal growth themes
• Increased journaling consistency

${context.summary}''';
  }
  
  /// Generate prompt suggestions
  String _generatePromptSuggestion(ContextWindow context) {
    final phaseData = context.nodes.where((n) => n['type'] == 'phase').firstOrNull;
    final currentPhase = phaseData?['text'] ?? 'Discovery';
    
    return '''Here are some journal prompts for tonight:

**Phase: $currentPhase**
• What new insights did you gain today?
• How did today's experiences align with your current phase?
• What patterns are you noticing in your thoughts?

**General Reflection**
• What am I grateful for today?
• What challenged me today and how did I respond?
• What would I like to focus on tomorrow?

${context.summary}''';
  }
  
  /// Generate chat response
  String _generateChatResponse(String userQuery, ContextWindow context) {
    final lowerQuery = userQuery.toLowerCase().trim();
    
    print('LUMARA Debug: Generating chat response for: "$lowerQuery"');
    
    if (lowerQuery.contains('how are you') || lowerQuery.contains('hello') || lowerQuery.contains('hi') || lowerQuery.contains('hey')) {
      final greetings = [
        '''Hello! I'm LUMARA, your personal assistant. I'm here to help you understand your patterns and provide insights about your journey. 

${context.summary}''',
        '''Hi there! I'm LUMARA, ready to help you explore your personal growth journey. What would you like to discover today?

${context.summary}''',
        '''Hey! I'm LUMARA, your AI companion for understanding your patterns and growth. How can I assist you today?

${context.summary}''',
      ];
      // Use a simple hash to select different responses
      final index = userQuery.hashCode.abs() % greetings.length;
      return greetings[index];
    }
    
    if (lowerQuery.contains('help') || lowerQuery.contains('what can you do')) {
      final helpResponses = [
        '''I can help you with:

• **Weekly Summaries** - Get insights about your recent entries
• **Pattern Analysis** - Identify rising themes and trends  
• **Phase Explanations** - Understand your current RIVET phase
• **Period Comparisons** - Compare different time periods
• **Prompt Suggestions** - Get journaling prompts for tonight

Just ask me anything about your journey!

${context.summary}''',
        '''Here's what I can do for you:

• **"Weekly summary"** - See your recent patterns and themes
• **"Rising patterns"** - Discover emerging trends in your entries
• **"Current phase"** - Get your RIVET phase analysis
• **"Journal prompts"** - Get personalized reflection questions

What would you like to explore first?

${context.summary}''',
        '''I'm your personal growth assistant! I can help you:

• Analyze your journal patterns and trends
• Explain your current RIVET phase
• Compare different periods of your journey
• Suggest journaling prompts for reflection

Try asking me about your "weekly summary" or "rising patterns"!

${context.summary}''',
      ];
      // Use a simple hash to select different responses
      final index = userQuery.hashCode.abs() % helpResponses.length;
      return helpResponses[index];
    }
    
    // Motivation and encouragement responses
    if (lowerQuery.contains('keep going') || lowerQuery.contains('continue') || lowerQuery.contains('motivation')) {
      return '''Based on your journey so far, here's what I think you should focus on:

**Keep Moving Forward**:
• **Consistency is key** - Your ${context.totalEntries} journal entries show you're building a valuable habit
• **Trust the process** - Each entry adds to your understanding of yourself
• **Small steps matter** - Progress isn't always linear, but every reflection counts

**Next Steps**:
• Try asking me about your "weekly summary" to see patterns
• Ask "what patterns are rising" to identify growth areas
• Get personalized prompts by asking for "journal suggestions"

You're doing great work on your journey! 🌟

${context.summary}''';
    }
    
    // General advice and guidance
    if (lowerQuery.contains('should') || lowerQuery.contains('advice') || lowerQuery.contains('recommend')) {
      return '''Here's what I'd suggest based on your current data:

**Focus Areas**:
• **Reflection** - Your journaling practice is building self-awareness
• **Pattern Recognition** - Look for themes in your recent entries
• **Phase Alignment** - Understanding your current phase can guide next steps

**Specific Actions**:
• Ask me "what can you tell me about my current phase?" for RIVET insights
• Try "summarize my last week" to see your recent patterns
• Request "journal prompts" for tonight's reflection

**Remember**: This journey is about understanding yourself better. Every entry, every reflection, every pattern you notice is progress.

${context.summary}''';
    }
    
    // Questions about progress or growth
    if (lowerQuery.contains('progress') || lowerQuery.contains('growth') || lowerQuery.contains('improve')) {
      return '''Your progress looks promising! Here's what I see:

**Current Status**:
• **${context.totalEntries} journal entries** - You're building a consistent practice
• **${context.totalArcforms} Arcform(s)** - You're engaging with structured reflection
• **Phase tracking** - You're monitoring your journey systematically

**Growth Opportunities**:
• Ask me about "rising patterns" to identify new themes
• Try "weekly summary" to see your recent insights
• Get "phase rationale" to understand your current state

**Keep going** - you're on the right path! 🚀

${context.summary}''';
    }
    
    // Questions about feelings or emotions
    if (lowerQuery.contains('feel') || lowerQuery.contains('emotion') || lowerQuery.contains('mood')) {
      return '''I can help you explore your emotional patterns:

**Understanding Your Feelings**:
• Ask me for a "weekly summary" to see mood trends
• Try "what patterns are rising" to identify emotional themes
• Get insights about your current phase and how it relates to your feelings

**Reflection Prompts**:
• "What am I grateful for today?"
• "What challenged me today and how did I respond?"
• "What emotions am I noticing most this week?"

Your feelings are valuable data points in your journey of self-understanding.

${context.summary}''';
    }
    
    // Default helpful response with variety
    final defaultResponses = [
      '''I'd be happy to help you explore that! Here are some ways I can assist:

**Quick Insights**:
• Ask "weekly summary" for recent patterns
• Try "current phase" for RIVET analysis  
• Request "rising patterns" for trend analysis
• Get "journal prompts" for tonight

**Your Journey Data**:
• ${context.totalEntries} journal entries
• ${context.totalArcforms} Arcform(s)
• Phase history since ${context.startDate.toIso8601String().split('T')[0]}

What specific aspect would you like to explore? I'm here to help you understand your patterns and growth! 🌟

${context.summary}''',
      '''That's a great question! Let me help you dive deeper into your journey:

**Available Insights**:
• "Weekly summary" - See your recent patterns
• "Current phase" - Understand your RIVET analysis
• "Rising patterns" - Identify emerging themes
• "Journal prompts" - Get reflection suggestions

**Your Progress**:
• ${context.totalEntries} journal entries tracked
• ${context.totalArcforms} Arcform(s) completed
• Journey data since ${context.startDate.toIso8601String().split('T')[0]}

I'm excited to help you discover new insights about yourself! What would you like to explore first? ✨

${context.summary}''',
      '''I'm here to support your growth journey! Here's how I can help:

**Explore Your Data**:
• "Weekly summary" - Recent patterns and themes
• "Current phase" - Your RIVET phase analysis
• "Rising patterns" - Emerging trends in your entries
• "Journal prompts" - Personalized reflection questions

**Your Journey So Far**:
• ${context.totalEntries} journal entries
• ${context.totalArcforms} Arcform(s)
• Data since ${context.startDate.toIso8601String().split('T')[0]}

What aspect of your personal growth would you like to understand better? I'm ready to help! 🚀

${context.summary}''',
    ];
    
    // Use a simple hash to select different responses
    final index = userQuery.hashCode.abs() % defaultResponses.length;
    return defaultResponses[index];
  }
  
  /// Extract top keywords from journal entries
  List<String> _extractTopKeywords(List<Map<String, dynamic>> entries) {
    final allKeywords = <String, int>{};
    
    for (final entry in entries) {
      final keywords = entry['meta']['keywords'] as List<List<dynamic>>;
      for (final keyword in keywords) {
        final word = keyword[0] as String;
        allKeywords[word] = (allKeywords[word] ?? 0) + 1;
      }
    }
    
    final sorted = allKeywords.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    return sorted.take(5).map((e) => e.key).toList();
  }
  
  /// Extract all keywords from journal entries
  List<String> _extractAllKeywords(List<Map<String, dynamic>> entries) {
    final keywords = <String>[];
    
    for (final entry in entries) {
      final entryKeywords = entry['meta']['keywords'] as List<List<dynamic>>;
      for (final keyword in entryKeywords) {
        keywords.add(keyword[0] as String);
      }
    }
    
    return keywords.toSet().toList();
  }
  
  /// Describe valence level
  String _describeValence(double valence) {
    if (valence < 0.3) return 'Low (${(valence * 100).toStringAsFixed(0)}%)';
    if (valence < 0.7) return 'Moderate (${(valence * 100).toStringAsFixed(0)}%)';
    return 'High (${(valence * 100).toStringAsFixed(0)}%)';
  }
  
  /// Describe ALIGN score
  String _describeAlign(double align) {
    if (align < 0.6) return 'Low alignment - consider more check-ins';
    if (align < 0.8) return 'Moderate alignment - good progress';
    return 'High alignment - strong phase evidence';
  }
  
  /// Describe TRACE score
  String _describeTrace(double trace) {
    if (trace < 0.6) return 'Low trace - patterns need more time';
    if (trace < 0.8) return 'Moderate trace - patterns emerging';
    return 'High trace - clear pattern evidence';
  }
}
