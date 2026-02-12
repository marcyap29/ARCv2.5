/// Service that classifies LUMARA chat sessions into phases.
///
/// Each chat (regardless of number of exchanges) receives one phase designation.
/// The phase can be reclassified when the chat is revisited and content changes.
library;

import 'package:my_app/arc/chat/chat/chat_repo.dart';
import 'package:my_app/prism/atlas/phase/phase_inference_service.dart';

class ChatPhaseService {
  final ChatRepo _chatRepo;

  ChatPhaseService(this._chatRepo);

  /// Classify (or reclassify) the phase for [sessionId] based on the
  /// concatenated text of all user + assistant messages in the session.
  ///
  /// Reclassification is skipped when:
  ///  - The session does not exist.
  ///  - There are no messages.
  ///  - The user has manually overridden the phase (`userPhaseOverride`).
  ///
  /// Returns the detected phase label, or `null` if classification was skipped.
  Future<String?> classifySessionPhase(String sessionId) async {
    final session = await _chatRepo.getSession(sessionId);
    if (session == null) return null;

    // Respect manual user override — never auto-reclassify
    if (session.userPhaseOverride != null &&
        session.userPhaseOverride!.isNotEmpty) {
      return session.userPhaseOverride;
    }

    final messages = await _chatRepo.getMessages(sessionId, lazy: false);
    if (messages.isEmpty) return null;

    // Concatenate all message text (both user & assistant) for holistic analysis
    final combinedText = messages.map((m) => m.textContent).join('\n');

    // Use the same inference pipeline that journal entries use
    final result = await PhaseInferenceService.inferPhaseForEntrySimple(
      entryContent: combinedText,
    );

    // Persist phase on the session
    await _chatRepo.updateSessionPhase(
      sessionId,
      autoPhase: result.phase,
      autoPhaseConfidence: result.confidence,
    );

    print('ChatPhaseService: Session $sessionId → ${result.phase} '
        '(confidence: ${result.confidence.toStringAsFixed(2)})');

    return result.phase;
  }

  /// Manually set a phase override for a chat session.
  /// Once set, auto-reclassification is bypassed until the override is cleared.
  Future<void> setUserPhaseOverride(
      String sessionId, String phaseLabel) async {
    final session = await _chatRepo.getSession(sessionId);
    if (session == null) return;

    final existing = session.metadata ?? {};
    final merged = {
      ...existing,
      'userPhaseOverride': phaseLabel,
    };

    // Use updateSessionMetadata to persist
    await _chatRepo.updateSessionMetadata(sessionId, merged);
    print('ChatPhaseService: User override for $sessionId → $phaseLabel');
  }

  /// Clear the manual phase override, allowing auto-classification again.
  Future<void> clearUserPhaseOverride(String sessionId) async {
    final session = await _chatRepo.getSession(sessionId);
    if (session == null) return;

    final existing = Map<String, dynamic>.from(session.metadata ?? {});
    existing.remove('userPhaseOverride');

    await _chatRepo.updateSessionMetadata(sessionId, existing);
    print('ChatPhaseService: Cleared user override for $sessionId');

    // Re-run auto classification
    await classifySessionPhase(sessionId);
  }

  /// Batch-classify all sessions that don't yet have a phase.
  /// Useful for backfilling existing chats.
  Future<int> backfillAllSessions() async {
    final sessions = await _chatRepo.listAll(includeArchived: true);
    int classified = 0;

    for (final session in sessions) {
      if (session.displayPhase != null &&
          session.displayPhase!.isNotEmpty) {
        continue; // Already has a phase
      }
      final phase = await classifySessionPhase(session.id);
      if (phase != null) classified++;
    }

    print('ChatPhaseService: Backfilled $classified / ${sessions.length} sessions');
    return classified;
  }
}
