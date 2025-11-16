/// LUMARA Context Builder for On-Device LLMs
/// 
/// Builds structured context blocks that help small models understand user state

class LumaraContextBuilder {
  final String userName;
  final String currentPhase;
  final List<String> recentKeywords;
  final List<String> memorySnippets;
  final List<String> journalExcerpts;
  final List<String> favoriteExamples; // Favorite LUMARA reply examples for style guidance

  LumaraContextBuilder({
    required this.userName,
    required this.currentPhase,
    this.recentKeywords = const [],
    this.memorySnippets = const [],
    this.journalExcerpts = const [],
    this.favoriteExamples = const [],
  });

  /// Build the complete context block
  String buildContextBlock() {
    final buffer = StringBuffer();
    
    // User Profile
    buffer.writeln('[USER_PROFILE]');
    buffer.writeln('name: $userName');
    buffer.writeln('phase_preference: steady, structured');
    buffer.writeln('style_preferences: no em dashes; avoid "not X, Y"; reflective but clear');
    buffer.writeln('current_phase: $currentPhase');
    
    if (recentKeywords.isNotEmpty) {
      buffer.writeln('recent_keywords: ${recentKeywords.take(10).join(', ')}');
    } else {
      buffer.writeln('recent_keywords: none');
    }
    
    if (memorySnippets.isNotEmpty) {
      buffer.writeln('memory_snippets:');
      for (final snippet in memorySnippets.take(8)) {
        buffer.writeln('- $snippet');
      }
    } else {
      buffer.writeln('memory_snippets: none');
    }
    
    buffer.writeln();
    
    // Journal Context
    buffer.writeln('[JOURNAL_CONTEXT]');
    if (journalExcerpts.isNotEmpty) {
      for (final excerpt in journalExcerpts.take(3)) {
        buffer.writeln('$excerpt');
        buffer.writeln();
      }
    } else {
      buffer.writeln('No recent journal entries');
    }
    
    buffer.writeln();
    
    // Favorites Style Examples
    if (favoriteExamples.isNotEmpty) {
      buffer.writeln('[FAVORITE_STYLE_EXAMPLES_START]');
      for (final example in favoriteExamples) {
        buffer.writeln(example);
        buffer.writeln('---');
      }
      buffer.writeln('[FAVORITE_STYLE_EXAMPLES_END]');
      buffer.writeln();
    }
    
    // Constraints
    buffer.writeln('[CONSTRAINTS]');
    buffer.writeln('- On-device only. No internet. Keep answers compact.');
    buffer.writeln('- If information is missing, state what\'s missing in one bullet.');
    
    return buffer.toString();
  }

  /// Build a minimal context block when no data is available
  String buildMinimalContextBlock() {
    final favoritesSection = favoriteExamples.isNotEmpty
        ? '\n[FAVORITE_STYLE_EXAMPLES_START]\n${favoriteExamples.join('\n---\n')}\n[FAVORITE_STYLE_EXAMPLES_END]\n'
        : '';
    
    return '''[USER_PROFILE]
name: $userName
phase_preference: steady, structured
style_preferences: no em dashes; avoid "not X, Y"; reflective but clear
current_phase: $currentPhase
recent_keywords: none
memory_snippets: none

[JOURNAL_CONTEXT]
No recent journal entries$favoritesSection
[CONSTRAINTS]
- On-device only. No internet. Keep answers compact.
- If information is missing, state what's missing in one bullet.''';
  }
}
