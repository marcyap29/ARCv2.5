// lib/lumara/agents/services/agents_connection_service.dart
//
// Replaces the original AgentsConnectionService.
// Now checks SwarmSpace plugin availability instead of raw Groq/Gemini key presence.
// The Agents tab is removed — this service is used internally by the orchestrator
// to decide which plugins are available and to surface capability prompts to the user.

import 'package:my_app/services/swarmspace/swarmspace_client.dart';

/// Connection status for a SwarmSpace plugin.
enum AgentConnectionStatus { connected, notConnected, tierUpgradeRequired }

/// Result of checking whether an agent/plugin is ready.
class AgentConnectionState {
  final String agentId;
  final AgentConnectionStatus status;
  final String? message;
  final SwarmSpaceQuota? quota;

  const AgentConnectionState({
    required this.agentId,
    required this.status,
    this.message,
    this.quota,
  });

  bool get isConnected => status == AgentConnectionStatus.connected;
  bool get needsUpgrade => status == AgentConnectionStatus.tierUpgradeRequired;
}

/// Checks SwarmSpace plugin availability for LUMARA's agents.
///
/// The Writing agent needs: gemini-flash (synthesis) + optional url-reader
/// The Research agent needs: brave-search or tavily-search (web) + wikipedia
///
/// LUMARA surfaces capability prompts ("I could help you better with X enabled")
/// rather than showing an Agents tab.
class AgentsConnectionService {
  AgentsConnectionService._();
  static final AgentsConnectionService instance = AgentsConnectionService._();

  // Plugin IDs
  static const String _braveSearch = 'brave-search';
  static const String _tavilySearch = 'tavily-search';
  static const String _exaSearch = 'exa-search';
  static const String _geminiFlash = 'gemini-flash';
  static const String _urlReader = 'url-reader';
  static const String _wikipedia = 'wikipedia';
  static const String _news = 'news';

  // Public agent IDs (used as keys in results map)
  static const String writingAgentId = 'writing';
  static const String researchAgentId = 'research';
  static const String newsAgentId = 'news';

  final SwarmSpaceClient _client = SwarmSpaceClient.instance;

  /// Check if the Writing agent has what it needs.
  /// Requires: gemini-flash (for synthesis).
  /// Optional: url-reader (for reading linked content before drafting).
  Future<AgentConnectionState> checkWritingConnection() async {
    try {
      final available = await _client.isPluginAvailable(_geminiFlash);
      if (!available) {
        return AgentConnectionState(
          agentId: writingAgentId,
          status: AgentConnectionStatus.notConnected,
          message: 'Writing synthesis requires an active SwarmSpace connection.',
        );
      }
      final quota = _client.getCachedQuota(_geminiFlash);
      if (quota != null && quota.isExhausted) {
        return AgentConnectionState(
          agentId: writingAgentId,
          status: AgentConnectionStatus.connected,
          message: 'Daily writing quota reached. Resets at midnight UTC.',
          quota: quota,
        );
      }
      return AgentConnectionState(
        agentId: writingAgentId,
        status: AgentConnectionStatus.connected,
        quota: quota,
      );
    } catch (e) {
      return AgentConnectionState(
        agentId: writingAgentId,
        status: AgentConnectionStatus.notConnected,
        message: 'Unable to check: $e',
      );
    }
  }

  /// Check if the Research agent has what it needs.
  /// Free tier: brave-search + wikipedia (both always available).
  /// Standard tier: tavily-search (AI-optimized results).
  /// Premium tier: exa-search (neural semantic search).
  Future<AgentConnectionState> checkResearchConnection() async {
    try {
      // Brave is always available on free tier — if it's reachable, research works.
      final braveAvailable = await _client.isPluginAvailable(_braveSearch);
      if (!braveAvailable) {
        return AgentConnectionState(
          agentId: researchAgentId,
          status: AgentConnectionStatus.notConnected,
          message: 'Research requires a SwarmSpace connection.',
        );
      }

      // Check if higher-tier search is available (better results)
      final tavilyAvailable = await _client.isPluginAvailable(_tavilySearch);
      final quota = _client.getCachedQuota(
        tavilyAvailable ? _tavilySearch : _braveSearch,
      );

      return AgentConnectionState(
        agentId: researchAgentId,
        status: AgentConnectionStatus.connected,
        message: tavilyAvailable
            ? 'AI-optimized search active'
            : null,
        quota: quota,
      );
    } catch (e) {
      return AgentConnectionState(
        agentId: researchAgentId,
        status: AgentConnectionStatus.notConnected,
        message: 'Unable to check: $e',
      );
    }
  }

  /// Check news plugin availability.
  Future<AgentConnectionState> checkNewsConnection() async {
    try {
      final available = await _client.isPluginAvailable(_news);
      return AgentConnectionState(
        agentId: newsAgentId,
        status: available
            ? AgentConnectionStatus.connected
            : AgentConnectionStatus.notConnected,
        quota: _client.getCachedQuota(_news),
      );
    } catch (e) {
      return AgentConnectionState(
        agentId: newsAgentId,
        status: AgentConnectionStatus.notConnected,
        message: 'Unable to check: $e',
      );
    }
  }

  /// Check all agents. Returns map agentId → state.
  Future<Map<String, AgentConnectionState>> checkAllConnections() async {
    final results = await Future.wait([
      checkWritingConnection(),
      checkResearchConnection(),
      checkNewsConnection(),
    ]);
    return {
      writingAgentId: results[0],
      researchAgentId: results[1],
      newsAgentId: results[2],
    };
  }

  /// Get a human-readable capability prompt for LUMARA to surface to the user.
  /// Called by the orchestrator when it detects a relevant intent but a plugin
  /// isn't available or has limited quota.
  ///
  /// Returns null if no prompt is needed (plugin is available and has quota).
  Future<String?> getCapabilityPrompt(String pluginId) async {
    final available = await _client.isPluginAvailable(pluginId);
    if (available) {
      final quota = _client.getCachedQuota(pluginId);
      if (quota != null && quota.isExhausted) {
        return 'I could help you with this better, but the $pluginId quota '
            'has been reached for today. It resets at midnight UTC.';
      }
      return null; // Available and has quota — no prompt needed
    }

    switch (pluginId) {
      case _tavilySearch:
      case _exaSearch:
        return 'I could do deeper research on this with an upgraded SwarmSpace plan. '
            'For now I\'ll use standard web search.';
      case _urlReader:
        return 'I could read that page directly with a SwarmSpace standard plan. '
            'Want me to proceed with what I know?';
      default:
        return 'The $pluginId capability isn\'t available right now. '
            'I\'ll do my best without it.';
    }
  }
}
