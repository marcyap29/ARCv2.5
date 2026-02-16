import 'package:my_app/lumara/agents/models/research_models.dart';
import 'package:my_app/lumara/agents/models/content_draft.dart';
import 'package:my_app/services/firebase_auth_service.dart';

/// Service to load Research reports and Writing drafts from CHRONICLE (or local storage).
/// Stub implementation returns empty lists until backend is connected.
class AgentsChronicleService {
  AgentsChronicleService._();
  static final AgentsChronicleService instance = AgentsChronicleService._();

  Future<String> _getCurrentUserId() async {
    final uid = FirebaseAuthService.instance.currentUser?.uid;
    return uid ?? 'default_user';
  }

  /// Load research reports for the current user. Returns empty until ATLAS/CHRONICLE integration.
  Future<List<ResearchReport>> getResearchReports(String userId) async {
    // TODO: Query CHRONICLE or ATLAS research store by userId
    return [];
  }

  /// Load content drafts for the current user. Returns empty until Writing Agent storage is wired.
  Future<List<ContentDraft>> getContentDrafts(String userId) async {
    // TODO: Query CHRONICLE or Writing draft store by userId
    return [];
  }

  /// Get current user id for callers that need it.
  Future<String> getCurrentUserId() => _getCurrentUserId();
}
