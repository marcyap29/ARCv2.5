import 'package:collection/collection.dart';
import 'package:hive/hive.dart';
import 'package:my_app/models/reflection_session.dart';

class ReflectionSessionRepository {
  final Box<ReflectionSession> _box;

  ReflectionSessionRepository(this._box);

  Future<ReflectionSession?> getActiveSession(String entryId) async {
    return _box.values.firstWhereOrNull(
      (s) => s.entryId == entryId && !s.isPaused,
    );
  }

  /// Puts or overwrites a session in the box (use for new sessions).
  Future<void> putSession(ReflectionSession session) async {
    await _box.put(session.id, session);
  }

  Future<void> saveSession(ReflectionSession session) async {
    await session.save();
  }

  Future<void> pauseSession(String sessionId, Duration duration) async {
    final session = _box.values.firstWhereOrNull((s) => s.id == sessionId);
    if (session != null) {
      session.pausedUntil = DateTime.now().add(duration);
      await session.save();
    }
  }

  Future<List<ReflectionSession>> getRecentSessions(
    String userId, {
    int days = 7,
  }) async {
    final cutoff = DateTime.now().subtract(Duration(days: days));
    return _box.values
        .where((s) => s.userId == userId && s.startTime.isAfter(cutoff))
        .toList();
  }
}
