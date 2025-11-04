/// LUMARA Context Builder for On-Device LLMs
/// 
/// Builds structured context blocks that help small models understand user state

class LumaraContextBuilder {
  final String userName;
  final String currentPhase;
  final List<String> recentKeywords;
  final List<String> memorySnippets;
  final List<String> journalExcerpts;

  LumaraContextBuilder({
    required this.userName,
    required this.currentPhase,
    this.recentKeywords = const [],
    this.memorySnippets = const [],
    this.journalExcerpts = const [],
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
    
    // Constraints
    buffer.writeln('[CONSTRAINTS]');
    buffer.writeln('- On-device only. No internet. Keep answers compact.');
    buffer.writeln('- If information is missing, state what\'s missing in one bullet.');
    
    return buffer.toString();
  }

  /// Build a minimal context block when no data is available
  String buildMinimalContextBlock() {
    return '''[USER_PROFILE]
name: $userName
phase_preference: steady, structured
style_preferences: no em dashes; avoid "not X, Y"; reflective but clear
current_phase: $currentPhase
recent_keywords: none
memory_snippets: none

[JOURNAL_CONTEXT]
No recent journal entries

[CONSTRAINTS]
- On-device only. No internet. Keep answers compact.
- If information is missing, state what's missing in one bullet.''';
  }
}
