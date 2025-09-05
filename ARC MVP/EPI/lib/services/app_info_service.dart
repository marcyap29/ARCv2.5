import 'package:package_info_plus/package_info_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'dart:io';

class AppInfoService {
  static Future<Map<String, dynamic>> getAppInfo() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final deviceInfo = DeviceInfoPlugin();
      
      Map<String, dynamic> deviceData = {};
      if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        deviceData = {
          'platform': 'iOS',
          'model': iosInfo.model,
          'systemName': iosInfo.systemName,
          'systemVersion': iosInfo.systemVersion,
          'isPhysicalDevice': iosInfo.isPhysicalDevice,
        };
      } else if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        deviceData = {
          'platform': 'Android',
          'model': androidInfo.model,
          'brand': androidInfo.brand,
          'version': androidInfo.version.release,
          'isPhysicalDevice': androidInfo.isPhysicalDevice,
        };
      }
      
      return {
        'app_name': packageInfo.appName,
        'package_name': packageInfo.packageName,
        'version': packageInfo.version,
        'build_number': packageInfo.buildNumber,
        'build_signature': packageInfo.buildSignature,
        'installer_store': packageInfo.installerStore,
        'device': deviceData,
        'timestamp': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      return {
        'error': 'Failed to get app info: $e',
        'timestamp': DateTime.now().toIso8601String(),
      };
    }
  }
  
  static Future<Map<String, dynamic>> getAppStatistics() async {
    try {
      // This would typically come from analytics or local storage
      return {
        'total_sessions': 0,
        'total_entries': 0,
        'total_arcforms': 0,
        'first_launch': DateTime.now().toIso8601String(),
        'last_launch': DateTime.now().toIso8601String(),
        'features_used': [
          'Journal Capture',
          'Arcform Visualization',
          'Timeline View',
          'Insights Analysis',
          'Settings & Privacy',
        ],
      };
    } catch (e) {
      return {
        'error': 'Failed to get app statistics: $e',
        'timestamp': DateTime.now().toIso8601String(),
      };
    }
  }
}
