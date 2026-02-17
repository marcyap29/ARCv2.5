import 'package:my_app/arc/chat/config/api_config.dart';

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

/// Checks whether each LUMARA agent has required services connected (e.g. API keys).
/// Used by the Agents tab to show connection status and "Connect" action.
class AgentsConnectionService {
  AgentsConnectionService._();
  static final AgentsConnectionService instance = AgentsConnectionService._();

  static const String writingAgentId = 'writing';
  static const String researchAgentId = 'research';

  /// Ensure API config is loaded, then check Writing agent (uses Groq).
  Future<AgentConnectionState> checkWritingConnection() async {
    try {
      await LumaraAPIConfig.instance.initialize();
      final apiKey = LumaraAPIConfig.instance.getApiKey(LLMProvider.groq);
      final connected = apiKey != null && apiKey.trim().isNotEmpty;
      return AgentConnectionState(
        agentId: writingAgentId,
        status: connected ? AgentConnectionStatus.connected : AgentConnectionStatus.notConnected,
        message: connected ? null : 'Set Groq API key in LUMARA settings',
      );
    } catch (e) {
      return AgentConnectionState(
        agentId: writingAgentId,
        status: AgentConnectionStatus.notConnected,
        message: 'Unable to check: $e',
      );
    }
  }

  /// Research agent uses same cloud API (Groq) for now.
  Future<AgentConnectionState> checkResearchConnection() async {
    try {
      await LumaraAPIConfig.instance.initialize();
      final apiKey = LumaraAPIConfig.instance.getApiKey(LLMProvider.groq);
      final connected = apiKey != null && apiKey.trim().isNotEmpty;
      return AgentConnectionState(
        agentId: researchAgentId,
        status: connected ? AgentConnectionStatus.connected : AgentConnectionStatus.notConnected,
        message: connected ? null : 'Set Groq API key in LUMARA settings',
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
