/// Intent types for LUMARA orchestrator routing.
///
/// Used by [CommandIntent] and subsystems to determine
/// which subsystem(s) can handle a user query.
enum IntentType {
  /// "Tell me about January" / "What did I write last month?"
  temporalQuery,

  /// "What themes recur?" / "Analyze recurring patterns"
  patternAnalysis,

  /// "How have I changed since 2020?"
  developmentalArc,

  /// "Have I dealt with this before?"
  historicalParallel,

  /// "Compare 2024 vs 2025"
  comparison,

  /// "What did I write last Tuesday?"
  specificRecall,

  /// Recent context for reflection (default when no temporal intent)
  recentContext,

  /// "Decision support for [topic]" - multi-subsystem
  decisionSupport,

  /// AURORA: "Show usage patterns"
  usagePatterns,

  /// AURORA: "When is optimal time for X?"
  optimalTiming,
}
