import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Provenance tracker for chat data export
class ChatProvenanceTracker {
  static ChatProvenanceTracker? _instance;

  Map<String, dynamic>? _cachedProvenance;

  ChatProvenanceTracker._();

  static ChatProvenanceTracker get instance {
    _instance ??= ChatProvenanceTracker._();
    return _instance!;
  }

  /// Get provenance metadata for exports
  Future<Map<String, dynamic>> getProvenanceMetadata() async {
    _cachedProvenance ??= await _buildProvenance();
    return Map.from(_cachedProvenance!);
  }

  /// Build provenance information
  Future<Map<String, dynamic>> _buildProvenance() async {
    final provenance = <String, dynamic>{
      'source': 'LUMARA',
      'timestamp': DateTime.now().toUtc().toIso8601String(),
    };

    try {
      // Get app version
      final packageInfo = await PackageInfo.fromPlatform();
      provenance['app_version'] = packageInfo.version;
      provenance['build_number'] = packageInfo.buildNumber;
      provenance['app_name'] = packageInfo.appName;
    } catch (e) {
      print('ProvenanceTracker: Failed to get package info: $e');
    }

    try {
      // Get device info
      final deviceInfo = DeviceInfoPlugin();

      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        provenance['device'] = {
          'platform': 'android',
          'model': androidInfo.model,
          'manufacturer': androidInfo.manufacturer,
          'version': androidInfo.version.release,
          'sdk_int': androidInfo.version.sdkInt,
        };
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        provenance['device'] = {
          'platform': 'ios',
          'name': iosInfo.name,
          'model': iosInfo.model,
          'system_name': iosInfo.systemName,
          'system_version': iosInfo.systemVersion,
        };
      } else {
        provenance['device'] = {
          'platform': Platform.operatingSystem,
          'version': Platform.operatingSystemVersion,
        };
      }
    } catch (e) {
      print('ProvenanceTracker: Failed to get device info: $e');
      provenance['device'] = {
        'platform': Platform.operatingSystem,
      };
    }

    // Add export context
    provenance['export_context'] = {
      'feature': 'chat_memory',
      'format': 'mcp_v1',
      'schema_versions': {
        'node': 'v2',
        'edge': 'v1',
        'chat_session': 'v1',
        'chat_message': 'v1',
      },
    };

    return provenance;
  }

  /// Clear cached provenance (for testing)
  void clearCache() {
    _cachedProvenance = null;
  }
}