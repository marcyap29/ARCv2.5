// lib/services/swarmspace/swarmspace_client.dart
//
// SwarmSpace plugin client for LUMARA.
//
// Calls the swarmspaceRouter Firebase Cloud Function via **direct HTTP POST**
// with manually attached ID token — same approach as groq_send.dart.
// This bypasses Firebase SDK's httpsCallable/GTMSessionFetcher, which causes
// "already running" and UNAUTHENTICATED when multiple calls run in parallel.
//
// Usage:
//   final result = await SwarmSpaceClient.instance.invoke(
//     'brave-search',
//     {'query': 'my search query'},
//   );

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:my_app/services/firebase_auth_service.dart';
import 'package:my_app/services/firebase_service.dart';

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

/// Cloud Function URL — same region/project as proxyGroq.
const _swarmspaceRouterUrl =
    'https://us-central1-arc-epi.cloudfunctions.net/swarmspaceRouter';

/// SwarmSpace client — singleton.
/// Uses direct HTTP + manual ID token (bypasses GTMSessionFetcher).
class SwarmSpaceClient {
  SwarmSpaceClient._();
  static final SwarmSpaceClient instance = SwarmSpaceClient._();

  // Local quota cache — updated after each invocation for UI display
  final Map<String, SwarmSpaceQuota> _quotaCache = {};

  /// Invoke a SwarmSpace plugin via the Firebase router function.
  ///
  /// Uses direct HTTP POST with manually attached auth token to avoid
  /// GTMSessionFetcher conflicts when Research Agent runs parallel searches.
  ///
  /// [pluginId] — e.g. 'brave-search', 'weather', 'gemini-flash'
  /// [params]   — plugin-specific request body (see each plugin's input_schema)
  Future<SwarmSpaceResult> invoke(
    String pluginId,
    Map<String, dynamic> params,
  ) async {
    await FirebaseService.instance.ensureReady();
    final firebaseUser = FirebaseAuthService.instance.currentUser;
    if (firebaseUser == null) {
      return SwarmSpaceResult.error('Not authenticated. Sign in to use SwarmSpace.');
    }
    // Force refresh to avoid stale token (Firebase docs recommend for callables)
    final idToken = await firebaseUser.getIdToken(true);
    if (idToken == null || idToken.isEmpty) {
      return SwarmSpaceResult.error('Could not obtain auth token. Try signing out and back in.');
    }

    final requestData = <String, dynamic>{
      'plugin_id': pluginId,
      'params': params,
    };

    final client = HttpClient();
    try {
      final uri = Uri.parse(_swarmspaceRouterUrl);
      final request = await client.postUrl(uri);
      request.headers.set(HttpHeaders.contentTypeHeader, 'application/json; charset=utf-8');
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $idToken');
      request.write(jsonEncode({'data': requestData}));

      final httpResponse = await request.close().timeout(
        const Duration(seconds: 25),
        onTimeout: () {
          throw const SocketException('swarmspaceRouter request timed out');
        },
      );

      final body = await httpResponse.transform(utf8.decoder).join();

      if (httpResponse.statusCode != 200) {
        String errorMsg = 'SwarmSpace HTTP ${httpResponse.statusCode}';
        try {
          final errData = jsonDecode(body) as Map<String, dynamic>;
          final errObj = errData['error'] as Map<String, dynamic>?;
          errorMsg = errObj?['message'] as String? ?? errorMsg;
          final details = errObj?['details'] as Map<String, dynamic>?;

          if (details != null && details['quota'] != null) {
            final quota = SwarmSpaceQuota.fromJson(
              Map<String, dynamic>.from(details['quota'] as Map),
            );
            _quotaCache[pluginId] = quota;
          }
        } catch (_) {}

        if (kDebugMode) {
          print('SwarmSpace: invoke($pluginId) error: $errorMsg');
          if (httpResponse.statusCode == 401 && body.isNotEmpty) {
            final preview = body.length > 300 ? '${body.substring(0, 300)}...' : body;
            print('SwarmSpace: 401 response body: $preview');
          }
        }
        return SwarmSpaceResult.error(errorMsg);
      }

      final data = jsonDecode(body) as Map<String, dynamic>;
      final resultData = (data['result'] as Map<String, dynamic>?) ?? data;
      final swResult = SwarmSpaceResult.fromData(
        Map<String, dynamic>.from(resultData),
      );

      if (swResult.quota != null) {
        _quotaCache[pluginId] = swResult.quota!;
      }

      return swResult;
    } on SocketException catch (e) {
      if (kDebugMode) print('SwarmSpace: invoke($pluginId) network error: $e');
      return SwarmSpaceResult.error('Network error: $e');
    } catch (e) {
      if (kDebugMode) print('SwarmSpace: invoke($pluginId) unexpected error: $e');
      return SwarmSpaceResult.error('Unexpected error: $e');
    } finally {
      client.close();
    }
  }

  /// Check if a plugin is available for the current user's tier.
  /// Calls swarmspacePluginStatus — lightweight, no quota consumed.
  /// Uses direct HTTP to avoid GTMSessionFetcher conflicts.
  Future<bool> isPluginAvailable(String pluginId) async {
    try {
      final firebaseUser = FirebaseAuthService.instance.currentUser;
      if (firebaseUser == null) return false;
      final idToken = await firebaseUser.getIdToken();
      if (idToken == null || idToken.isEmpty) return false;

      const url = 'https://us-central1-arc-epi.cloudfunctions.net/swarmspacePluginStatus';
      final client = HttpClient();
      try {
        final uri = Uri.parse(url);
        final request = await client.postUrl(uri);
        request.headers.set(HttpHeaders.contentTypeHeader, 'application/json; charset=utf-8');
        request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $idToken');
        request.write(jsonEncode({'data': {'plugin_id': pluginId}}));

        final httpResponse = await request.close().timeout(
          const Duration(seconds: 10),
          onTimeout: () => throw const SocketException('swarmspacePluginStatus timed out'),
        );
        final body = await httpResponse.transform(utf8.decoder).join();

        if (httpResponse.statusCode != 200) return false;
        final data = jsonDecode(body) as Map<String, dynamic>;
        final resultData = (data['result'] as Map<String, dynamic>?) ?? data;
        return resultData['available'] == true;
      } finally {
        client.close();
      }
    } catch (_) {
      return false;
    }
  }

  /// Get cached quota for a plugin (updated after each invocation).
  SwarmSpaceQuota? getCachedQuota(String pluginId) => _quotaCache[pluginId];
}
