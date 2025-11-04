/// Abstract interface for all model adapters
/// This allows switching between rule-based, on-device, and cloud models seamlessly
abstract class ModelAdapter {
  /// Generate text from computed facts and snippets
  /// 
  /// [task] - The type of task (e.g., "weekly_summary", "rising_patterns", "phase_rationale", "compare_period", "prompt", "chat")
  /// [facts] - Computed statistics and data (e.g., {avgValence: 0.62, topTerms: [...]})
  /// [snippets] - Short quotes from user's data
  /// [chat] - Chat history for conversational tasks
  Stream<String> realize({
    required String task,
    required Map<String, dynamic> facts,
    required List<String> snippets,
    required List<Map<String, String>> chat,
  });
}

