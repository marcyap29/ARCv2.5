// lib/services/swarmspace/swarmspace_client.dart
//
// SwarmSpace plugin client for LUMARA.
//
// Calls the swarmspaceRouter Firebase Cloud Function — same pattern as
// how LUMARA already calls proxyGemini and sendChatMessage.
// Firebase handles auth token injection automatically.
//
// Usage:
//   final result = await SwarmSpaceClient.instance.invoke(
//     'brave-search',
//     {'query': 'my search query'},
//   );

import 'package:cloud_functions/cloud_functions.dart';

/// Result of a SwarmSpace plugin invocation.
class SwarmSpaceResult {
  final bool success;
  final Map<String, dynamic>? data;
  final String? error;
  final SwarmSpaceQuota? quota;

  const SwarmSpaceResult({
    required this.success,
    this.data,
    this.error,
    this.quota,
  });

  factory SwarmSpaceResult.fromData(Map<String, dynamic> data) {
    final quotaRaw = data['quota'];
    final quota = quotaRaw is Map<String, dynamic>
        ? SwarmSpaceQuota.fromJson(quotaRaw)
        : null;
    return SwarmSpaceResult(success: true, data: data, quota: quota);
  }

  factory SwarmSpaceResult.error(String message) {
    return SwarmSpaceResult(success: false, error: message);
  }
}

/// Quota state from a plugin response.
class SwarmSpaceQuota {
  final int limit;
  final int used;
  final int remaining;
  final DateTime? resetsAt;

  const SwarmSpaceQuota({
    required this.limit,
    required this.used,
    required this.remaining,
    this.resetsAt,
  });

  factory SwarmSpaceQuota.fromJson(Map<String, dynamic> json) {
    return SwarmSpaceQuota(
      limit: (json['limit'] as num?)?.toInt() ?? 0,
      used: (json['used'] as num?)?.toInt() ?? 0,
      remaining: (json['remaining'] as num?)?.toInt() ?? 0,
      resetsAt: json['resets_at'] != null
          ? DateTime.tryParse(json['resets_at'] as String)
          : null,
    );
  }

  bool get isExhausted => remaining <= 0;

  @override
  String toString() => '$used/$limit used ($remaining remaining)';
}

/// SwarmSpace client — singleton.
/// Wraps Firebase callable functions — no manual auth headers needed.
class SwarmSpaceClient {
  SwarmSpaceClient._();
  static final SwarmSpaceClient instance = SwarmSpaceClient._();

  // Local quota cache — updated after each invocation for UI display
  final Map<String, SwarmSpaceQuota> _quotaCache = {};

  /// Invoke a SwarmSpace plugin via the Firebase router function.
  ///
  /// [pluginId] — e.g. 'brave-search', 'weather', 'gemini-flash'
  /// [params]   — plugin-specific request body (see each plugin's input_schema)
  ///
  /// Firebase automatically attaches the user's auth token.
  /// The router validates it, checks tier, then forwards to the right worker.
  Future<SwarmSpaceResult> invoke(
    String pluginId,
    Map<String, dynamic> params,
  ) async {
    try {
      final callable = FirebaseFunctions.instance
          .httpsCallable('swarmspaceRouter');

      // This is identical to how your app calls sendChatMessage / proxyGemini
      final result = await callable.call<Map<String, dynamic>>({
        'plugin_id': pluginId,
        'params': params,
      });

      final data = Map<String, dynamic>.from(result.data as Map);
      final swResult = SwarmSpaceResult.fromData(data);

      // Cache quota for UI
      if (swResult.quota != null) {
        _quotaCache[pluginId] = swResult.quota!;
      }

      return swResult;
    } on FirebaseFunctionsException catch (e) {
      // Quota exceeded — expected, not a crash
      if (e.code == 'resource-exhausted') {
        final details = e.details as Map<String, dynamic>?;
        final quotaRaw = details?['quota'];
        final quota = quotaRaw is Map<String, dynamic>
            ? SwarmSpaceQuota.fromJson(Map<String, dynamic>.from(quotaRaw))
            : null;
        if (quota != null) _quotaCache[pluginId] = quota;
        return SwarmSpaceResult.error(e.message ?? 'Quota exceeded');
      }

      // Tier insufficient — user needs to upgrade
      if (e.code == 'permission-denied') {
        return SwarmSpaceResult.error(
          e.message ?? 'This feature requires a plan upgrade',
        );
      }

      return SwarmSpaceResult.error(e.message ?? 'Plugin error: ${e.code}');
    } catch (e) {
      return SwarmSpaceResult.error('Unexpected error: $e');
    }
  }

  /// Check if a plugin is available for the current user's tier.
  /// Calls swarmspacePluginStatus — lightweight, no quota consumed.
  Future<bool> isPluginAvailable(String pluginId) async {
    try {
      final callable = FirebaseFunctions.instance
          .httpsCallable('swarmspacePluginStatus');
      final result = await callable.call<Map<String, dynamic>>({
        'plugin_id': pluginId,
      });
      final data = result.data as Map<String, dynamic>;
      return data['available'] == true;
    } catch (_) {
      return false;
    }
  }

  /// Get cached quota for a plugin (updated after each invocation).
  SwarmSpaceQuota? getCachedQuota(String pluginId) => _quotaCache[pluginId];
}
