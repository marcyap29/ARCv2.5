import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:my_app/services/analytics_service.dart';
import 'package:my_app/core/analytics/analytics_consent.dart';
import 'package:my_app/shared/app_colors.dart';
import 'package:my_app/shared/text_style.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// QA screen for debugging and device information
/// Implements P15 requirements for analytics & QA
class QAScreen extends StatefulWidget {
  const QAScreen({super.key});

  @override
  State<QAScreen> createState() => _QAScreenState();
}

class _QAScreenState extends State<QAScreen> {
  Map<String, dynamic> _deviceInfo = {};
  Map<String, dynamic> _appInfo = {};
  Map<String, dynamic> _analyticsInfo = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDeviceInfo();
  }

  Future<void> _loadDeviceInfo() async {
    try {
      final deviceInfo = DeviceInfoPlugin();
      final packageInfo = await PackageInfo.fromPlatform();
      
      Map<String, dynamic> deviceData = {};
      
      if (Theme.of(context).platform == TargetPlatform.iOS) {
        final iosInfo = await deviceInfo.iosInfo;
        deviceData = {
          'platform': 'iOS',
          'model': iosInfo.model,
          'systemName': iosInfo.systemName,
          'systemVersion': iosInfo.systemVersion,
          'name': iosInfo.name,
          'localizedModel': iosInfo.localizedModel,
          'identifierForVendor': iosInfo.identifierForVendor,
          'isPhysicalDevice': iosInfo.isPhysicalDevice,
        };
      } else if (Theme.of(context).platform == TargetPlatform.android) {
        final androidInfo = await deviceInfo.androidInfo;
        deviceData = {
          'platform': 'Android',
          'model': androidInfo.model,
          'brand': androidInfo.brand,
          'device': androidInfo.device,
          'product': androidInfo.product,
          'androidId': androidInfo.id,
          'version': androidInfo.version.release,
          'sdkInt': androidInfo.version.sdkInt,
          'isPhysicalDevice': androidInfo.isPhysicalDevice,
        };
      }

      final appData = {
        'appName': packageInfo.appName,
        'packageName': packageInfo.packageName,
        'version': packageInfo.version,
        'buildNumber': packageInfo.buildNumber,
        'buildSignature': packageInfo.buildSignature,
      };

      final analyticsData = AnalyticsService.getAnalyticsSummary();

      setState(() {
        _deviceInfo = deviceData;
        _appInfo = appData;
        _analyticsInfo = analyticsData;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _deviceInfo = {'error': 'Failed to load device info: $e'};
        _appInfo = {'error': 'Failed to load app info: $e'};
        _analyticsInfo = {'error': 'Failed to load analytics info: $e'};
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kcSurfaceColor,
      appBar: AppBar(
        title: Text(
          'QA & Debug',
          style: heading2Style(context).copyWith(color: kcPrimaryColor),
        ),
        backgroundColor: kcSurfaceColor,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: kcPrimaryColor),
            onPressed: () {
              setState(() {
                _isLoading = true;
              });
              _loadDeviceInfo();
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: kcPrimaryColor),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildAnalyticsConsentCard(),
                  const SizedBox(height: 16),
                  _buildDeviceInfoCard(),
                  const SizedBox(height: 16),
                  _buildAppInfoCard(),
                  const SizedBox(height: 16),
                  _buildAnalyticsCard(),
                  const SizedBox(height: 16),
                  _buildSampleSeederCard(),
                ],
              ),
            ),
    );
  }

  Widget _buildAnalyticsConsentCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.analytics, color: kcPrimaryColor),
                const SizedBox(width: 8),
                Text(
                  'Analytics Consent',
                  style: heading3Style(context).copyWith(color: kcPrimaryColor),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Status: ${AnalyticsConsent.hasConsent() ? "Enabled" : "Disabled"}',
                    style: bodyStyle(context),
                  ),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (AnalyticsConsent.hasConsent()) {
                      await AnalyticsConsent.revokeConsent();
                    } else {
                      await AnalyticsConsent.grantConsent();
                    }
                    setState(() {});
                  },
                  child: Text(
                    AnalyticsConsent.hasConsent() ? 'Disable' : 'Enable',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeviceInfoCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.phone_android, color: kcPrimaryColor),
                const SizedBox(width: 8),
                Text(
                  'Device Information',
                  style: heading3Style(context).copyWith(color: kcPrimaryColor),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.copy),
                  onPressed: () => _copyToClipboard(_deviceInfo),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ..._deviceInfo.entries.map((entry) => _buildInfoRow(entry.key, entry.value.toString())),
          ],
        ),
      ),
    );
  }

  Widget _buildAppInfoCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.info, color: kcPrimaryColor),
                const SizedBox(width: 8),
                Text(
                  'App Information',
                  style: heading3Style(context).copyWith(color: kcPrimaryColor),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.copy),
                  onPressed: () => _copyToClipboard(_appInfo),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ..._appInfo.entries.map((entry) => _buildInfoRow(entry.key, entry.value.toString())),
          ],
        ),
      ),
    );
  }

  Widget _buildAnalyticsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.bar_chart, color: kcPrimaryColor),
                const SizedBox(width: 8),
                Text(
                  'Analytics Data',
                  style: heading3Style(context).copyWith(color: kcPrimaryColor),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.copy),
                  onPressed: () => _copyToClipboard(_analyticsInfo),
                ),
                IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    AnalyticsService.clearAnalytics();
                    _loadDeviceInfo();
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            ..._analyticsInfo.entries.map((entry) => _buildInfoRow(entry.key, entry.value.toString())),
          ],
        ),
      ),
    );
  }

  Widget _buildSampleSeederCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.data_object, color: kcPrimaryColor),
                const SizedBox(width: 8),
                Text(
                  'Sample Data Seeder',
                  style: heading3Style(context).copyWith(color: kcPrimaryColor),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Generate sample journal entries and arcforms for testing.',
              style: bodyStyle(context),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                ElevatedButton(
                  onPressed: () {
                    // TODO: Implement sample data seeder
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Sample seeder not yet implemented')),
                    );
                  },
                  child: const Text('Generate Sample Data'),
                ),
                const SizedBox(width: 16),
                OutlinedButton(
                  onPressed: () {
                    // TODO: Implement data clearing
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Data clearing not yet implemented')),
                    );
                  },
                  child: const Text('Clear All Data'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String key, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$key:',
                          style: bodyStyle(context).copyWith(
              fontWeight: FontWeight.w500,
              color: kcSecondaryTextColor,
            ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: bodyStyle(context),
            ),
          ),
        ],
      ),
    );
  }

  void _copyToClipboard(Map<String, dynamic> data) {
    final text = data.entries
        .map((entry) => '${entry.key}: ${entry.value}')
        .join('\n');
    
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Copied to clipboard')),
    );
  }
}
