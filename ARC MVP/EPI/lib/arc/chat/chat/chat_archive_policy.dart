/// Archive policy constants for chat sessions
class ChatArchivePolicy {
  /// Number of days after which non-pinned sessions are auto-archived
  static const int kArchiveAfterDays = 30;

  /// Retention tag applied to auto-archived sessions
  static const String kRetentionTag = 'auto-archive-30d';

  /// How often to run the pruner (daily)
  static const Duration kPrunerInterval = Duration(days: 1);

  /// Maximum number of sessions to process per pruner run (for performance)
  static const int kMaxSessionsPerPrunerRun = 100;

  /// Archive cutoff date from now
  static DateTime getArchiveCutoffDate() {
    return DateTime.now().subtract(const Duration(days: kArchiveAfterDays));
  }

  /// Check if a session should be archived based on policy
  static bool shouldArchive(DateTime updatedAt, bool isPinned, bool isArchived) {
    if (isPinned || isArchived) return false;
    return updatedAt.isBefore(getArchiveCutoffDate());
  }
}