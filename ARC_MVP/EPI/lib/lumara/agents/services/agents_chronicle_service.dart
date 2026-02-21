import 'package:my_app/lumara/agents/models/research_models.dart';
import 'package:my_app/lumara/agents/models/content_draft.dart';
import 'package:my_app/lumara/agents/research/research_artifact_repository.dart';
import 'package:my_app/lumara/agents/writing/writing_draft_repository.dart';
import 'package:my_app/lumara/agents/writing/writing_models.dart';
import 'package:my_app/services/firebase_auth_service.dart';

/// Service to load Research reports and Writing drafts from CHRONICLE (or local storage).
class AgentsChronicleService {
  AgentsChronicleService._();
  static final AgentsChronicleService instance = AgentsChronicleService._();

  WritingDraftRepository get _writingRepo => WritingDraftRepositoryImpl();

  Future<String> _getCurrentUserId() async {
    final uid = FirebaseAuthService.instance.currentUser?.uid;
    return uid ?? 'default_user';
  }

  /// Load research reports for the current user (active and archived).
  Future<List<ResearchReport>> getResearchReports(String userId, {bool includeArchived = true}) async {
    final list = await ResearchArtifactRepository.instance.listForUser(userId, includeArchived: includeArchived);
    return list.map((a) => ResearchReport(
      id: a.sessionId,
      query: a.query,
      summary: a.summary,
      detailedFindings: '',
      generatedAt: a.timestamp,
      phase: _phaseNameToAtlas(a.phaseName),
      archived: a.archived,
      archivedAt: a.archivedAt,
    )).toList();
  }

  static AtlasPhase _phaseNameToAtlas(String name) {
    switch (name.toLowerCase()) {
      case 'recovery': return AtlasPhase.recovery;
      case 'transition': return AtlasPhase.transition;
      case 'discovery': return AtlasPhase.discovery;
      case 'expansion': return AtlasPhase.expansion;
      case 'breakthrough': return AtlasPhase.breakthrough;
      case 'consolidation': return AtlasPhase.consolidation;
      default: return AtlasPhase.discovery;
    }
  }

  /// Archive a research report.
  Future<void> archiveResearchReport(String userId, String sessionId) async {
    await ResearchArtifactRepository.instance.archiveArtifact(userId, sessionId);
  }

  /// Unarchive a research report.
  Future<void> unarchiveResearchReport(String userId, String sessionId) async {
    await ResearchArtifactRepository.instance.unarchiveArtifact(userId, sessionId);
  }

  /// Permanently delete a research report.
  Future<void> deleteResearchReport(String userId, String sessionId) async {
    await ResearchArtifactRepository.instance.deleteArtifact(userId, sessionId);
  }

  /// Load content drafts for the current user (active and archived).
  Future<List<ContentDraft>> getContentDrafts(String userId, {bool includeArchived = true}) async {
    final list = await _writingRepo.listDrafts(userId, includeArchived: includeArchived);
    return list.map((s) => ContentDraft(
      id: s.draftId,
      title: s.title,
      preview: s.preview,
      updatedAt: s.updatedAt ?? s.createdAt,
      createdAt: s.createdAt,
      status: s.status == DraftStatus.finished ? ContentDraftStatus.finished : ContentDraftStatus.draft,
      archived: s.archived,
      archivedAt: s.archivedAt,
      wordCount: s.wordCount,
      contentType: s.phase,
    )).toList();
  }

  /// Mark a writing draft as finished.
  Future<void> markDraftFinished(String userId, String draftId) async {
    await _writingRepo.markFinished(userId, draftId);
  }

  /// Archive a writing draft.
  Future<void> archiveDraft(String userId, String draftId) async {
    await _writingRepo.archiveDraft(userId, draftId);
  }

  /// Unarchive a writing draft.
  Future<void> unarchiveDraft(String userId, String draftId) async {
    await _writingRepo.unarchiveDraft(userId, draftId);
  }

  /// Permanently delete a writing draft.
  Future<void> deleteDraft(String userId, String draftId) async {
    await _writingRepo.deleteDraft(userId, draftId);
  }

  /// Get current user id for callers that need it.
  Future<String> getCurrentUserId() => _getCurrentUserId();
}
