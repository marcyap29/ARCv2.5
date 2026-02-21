import 'package:my_app/arc/chat/services/lumara_cloud_generate.dart';

/// Connection status for an agent (needs cloud API to run).
enum AgentConnectionStatus {
  connected,
  notConnected,
}

/// Result of checking whether an agent is ready to use.
class AgentConnectionState {
  final String agentId;
  final AgentConnectionStatus status;
  final String? message;

  const AgentConnectionState({
    required this.agentId,
    required this.status,
    this.message,
  });

  bool get isConnected => status == AgentConnectionStatus.connected;
}

/// Checks whether each LUMARA agent can use the same cloud API as LUMARA chat
/// (Groq or Gemini key, or Firebase proxy when signed in). No separate API key needed for agents.
class AgentsConnectionService {
  AgentsConnectionService._();
  static final AgentsConnectionService instance = AgentsConnectionService._();

  static const String writingAgentId = 'writing';
  static const String researchAgentId = 'research';

  /// Uses same cloud availability as LUMARA: Groq key, Gemini key, or signed-in proxy.
  Future<AgentConnectionState> checkWritingConnection() async {
    try {
      final connected = await isLumaraCloudAvailable();
      return AgentConnectionState(
        agentId: writingAgentId,
        status: connected ? AgentConnectionStatus.connected : AgentConnectionStatus.notConnected,
        message: connected ? null : 'Sign in or add Groq/Gemini in Settings → LUMARA to use agents',
      );
    } catch (e) {
      return AgentConnectionState(
        agentId: writingAgentId,
        status: AgentConnectionStatus.notConnected,
        message: 'Unable to check: $e',
      );
    }
  }

  /// Same cloud as LUMARA (Groq/Gemini/proxy).
  Future<AgentConnectionState> checkResearchConnection() async {
    try {
      final connected = await isLumaraCloudAvailable();
      return AgentConnectionState(
        agentId: researchAgentId,
        status: connected ? AgentConnectionStatus.connected : AgentConnectionStatus.notConnected,
        message: connected ? null : 'Sign in or add Groq/Gemini in Settings → LUMARA to use agents',
      );
    } catch (e) {
      return AgentConnectionState(
        agentId: researchAgentId,
        status: AgentConnectionStatus.notConnected,
        message: 'Unable to check: $e',
      );
    }
  }

  /// Check all agents. Returns a map agentId -> state.
  Future<Map<String, AgentConnectionState>> checkAllConnections() async {
    final writing = await checkWritingConnection();
    final research = await checkResearchConnection();
    return {
      writingAgentId: writing,
      researchAgentId: research,
    };
  }
}
