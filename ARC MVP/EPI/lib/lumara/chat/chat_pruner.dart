import 'dart:async';
import 'chat_repo.dart';
import 'chat_archive_policy.dart';

/// Service responsible for pruning chat sessions according to archive policy
class ChatPruner {
  final ChatRepo _chatRepo;
  Timer? _prunerTimer;
  DateTime? _lastPruneTime;

  ChatPruner(this._chatRepo);

  /// Start the automatic pruner (runs daily)
  void startAutomaticPruning() {
    if (_prunerTimer?.isActive == true) {
      print('ChatPruner: Already running');
      return;
    }

    // Run immediately on start, then daily
    _runPruning();

    _prunerTimer = Timer.periodic(ChatArchivePolicy.kPrunerInterval, (_) {
      _runPruning();
    });

    print('ChatPruner: Started automatic pruning (every ${ChatArchivePolicy.kPrunerInterval.inDays} days)');
  }

  /// Stop the automatic pruner
  void stopAutomaticPruning() {
    _prunerTimer?.cancel();
    _prunerTimer = null;
    print('ChatPruner: Stopped automatic pruning');
  }

  /// Run pruning manually
  Future<PruneResult> runPruning() async {
    return _runPruning();
  }

  /// Internal pruning logic
  Future<PruneResult> _runPruning() async {
    final startTime = DateTime.now();

    try {
      print('ChatPruner: Starting pruning run...');

      // Get stats before pruning
      final statsBefore = await _chatRepo.getStats();

      // Run the pruning
      await _chatRepo.pruneByPolicy(
        maxAge: const Duration(days: ChatArchivePolicy.kArchiveAfterDays),
      );

      // Get stats after pruning
      final statsAfter = await _chatRepo.getStats();

      final result = PruneResult(
        success: true,
        archivedCount: (statsAfter['archived_sessions'] ?? 0) - (statsBefore['archived_sessions'] ?? 0),
        totalSessions: statsAfter['total_sessions'] ?? 0,
        activeSessions: statsAfter['active_sessions'] ?? 0,
        archivedSessions: statsAfter['archived_sessions'] ?? 0,
        duration: DateTime.now().difference(startTime),
        timestamp: startTime,
      );

      _lastPruneTime = startTime;

      if (result.archivedCount > 0) {
        print('ChatPruner: Archived ${result.archivedCount} sessions in ${result.duration.inMilliseconds}ms');
      }

      return result;
    } catch (e) {
      print('ChatPruner: Pruning failed: $e');

      return PruneResult(
        success: false,
        error: e.toString(),
        duration: DateTime.now().difference(startTime),
        timestamp: startTime,
      );
    }
  }

  /// Get the last pruning result
  DateTime? get lastPruneTime => _lastPruneTime;

  /// Check if pruner is running
  bool get isRunning => _prunerTimer?.isActive == true;

  /// Dispose resources
  void dispose() {
    stopAutomaticPruning();
  }
}

/// Result of a pruning operation
class PruneResult {
  final bool success;
  final int archivedCount;
  final int totalSessions;
  final int activeSessions;
  final int archivedSessions;
  final Duration duration;
  final DateTime timestamp;
  final String? error;

  const PruneResult({
    required this.success,
    this.archivedCount = 0,
    this.totalSessions = 0,
    this.activeSessions = 0,
    this.archivedSessions = 0,
    required this.duration,
    required this.timestamp,
    this.error,
  });

  @override
  String toString() {
    if (!success) {
      return 'PruneResult(failed: $error, duration: ${duration.inMilliseconds}ms)';
    }

    return 'PruneResult(archived: $archivedCount, total: $totalSessions, active: $activeSessions, archived: $archivedSessions, duration: ${duration.inMilliseconds}ms)';
  }
}