// lib/mira/core/flags.dart
// Feature flags for MIRA system capabilities
// Controls incremental rollout of advanced features while maintaining stability

class MiraFlags {
  /// Enable basic MIRA semantic graph functionality
  final bool miraEnabled;

  /// Enable advanced features: topic clustering, episode building, complex analytics
  final bool miraAdvancedEnabled;

  /// Enable vector embeddings and similarity search
  final bool retrievalEnabled;

  /// Use SQLite instead of Hive for storage (future implementation)
  final bool useSqliteRepo;

  const MiraFlags({
    this.miraEnabled = true,
    this.miraAdvancedEnabled = false,
    this.retrievalEnabled = false,
    this.useSqliteRepo = false,
  });

  /// Create flags with advanced features enabled
  const MiraFlags.advanced({
    this.miraEnabled = true,
    this.miraAdvancedEnabled = true,
    this.retrievalEnabled = true,
    this.useSqliteRepo = false,
  });

  /// Create flags with all features disabled (fallback mode)
  const MiraFlags.disabled()
      : miraEnabled = false,
        miraAdvancedEnabled = false,
        retrievalEnabled = false,
        useSqliteRepo = false;

  /// Default configuration
  static MiraFlags defaults() => const MiraFlags();

  @override
  String toString() => 'MiraFlags(mira: $miraEnabled, advanced: $miraAdvancedEnabled, '
      'retrieval: $retrievalEnabled, sqlite: $useSqliteRepo)';
}