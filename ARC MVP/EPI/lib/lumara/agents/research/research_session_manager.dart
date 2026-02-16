// lib/lumara/agents/research/research_session_manager.dart
// Manages multi-turn research sessions and persists to CHRONICLE (artifact repo).

import 'package:my_app/models/phase_models.dart';

import 'research_artifact_repository.dart';
import 'research_models.dart';

/// Manages research session state and persistence.
class ResearchSessionManager {
  final ResearchArtifactRepository _artifactRepo = ResearchArtifactRepository();
  final Map<String, ResearchSession> _sessions = {};

  static String _generateSessionId() {
    return 'RSH-${DateTime.now().year}-${DateTime.now().millisecondsSinceEpoch}';
  }

  Future<ResearchSession> createSession({
    required String userId,
    required String initialQuery,
    PhaseLabel phase = PhaseLabel.discovery,
    double readinessScore = 50.0,
  }) async {
    final session = ResearchSession(
      id: _generateSessionId(),
      userId: userId,
      queries: [initialQuery],
      createdAt: DateTime.now(),
      phase: phase,
      readinessScore: readinessScore,
    );
    _sessions[session.id] = session;
    return session;
  }

  ResearchSession? getSession(String sessionId) => _sessions[sessionId];

  Future<void> addFollowUp({
    required String sessionId,
    required String followUpQuery,
  }) async {
    final session = _sessions[sessionId];
    if (session == null) return;
    session.queries.add(followUpQuery);
  }

  Future<void> saveSession({
    required ResearchSession session,
    required ResearchReport finalReport,
  }) async {
    final artifact = ResearchArtifact(
      sessionId: session.id,
      query: session.queries.isNotEmpty ? session.queries.first : finalReport.query,
      report: finalReport,
      timestamp: DateTime.now(),
      phase: finalReport.phase,
    );
    await _artifactRepo.storeArtifact(userId: session.userId, artifact: artifact);
    session.status = SessionStatus.completed;
  }

  void updateSessionWithReport(ResearchSession session, ResearchReport report) {
    session.synthesisHistory.add(report);
  }
}
