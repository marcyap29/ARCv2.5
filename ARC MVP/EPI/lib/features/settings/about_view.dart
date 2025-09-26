import 'package:flutter/material.dart';
import 'package:my_app/services/app_info_service.dart';

class AboutView extends StatefulWidget {
  const AboutView({super.key});

  @override
  State<AboutView> createState() => _AboutViewState();
}

class _AboutViewState extends State<AboutView> {
  Map<String, dynamic>? _appInfo;
  Map<String, dynamic>? _appStats;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAppInfo();
  }

  Future<void> _loadAppInfo() async {
    final appInfo = await AppInfoService.getAppInfo();
    final appStats = await AppInfoService.getAppStatistics();
    
    if (mounted) {
      setState(() {
        _appInfo = appInfo;
        _appStats = appStats;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text(
          'About',
          style: TextStyle(color: Colors.white),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Colors.blue),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // App Header
                Card(
                  color: Colors.grey[900],
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: Colors.blue.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Icon(
                            Icons.auto_awesome,
                            color: Colors.blue,
                            size: 40,
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'EPI ARC MVP',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Evolving Personal Intelligence',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        if (_appInfo != null && _appInfo!['version'] != null)
                          Text(
                            'Version ${_appInfo!['version']} (${_appInfo!['build_number']})',
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: 14,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // App Information
                if (_appInfo != null) ...[
                  _buildInfoSection(
                    'App Information',
                    Icons.info,
                    [
                      _buildInfoRow('App Name', _appInfo!['app_name'] ?? 'Unknown'),
                      _buildInfoRow('Package', _appInfo!['package_name'] ?? 'Unknown'),
                      _buildInfoRow('Version', _appInfo!['version'] ?? 'Unknown'),
                      _buildInfoRow('Build', _appInfo!['build_number'] ?? 'Unknown'),
                      if (_appInfo!['installer_store'] != null)
                        _buildInfoRow('Store', _appInfo!['installer_store']),
                    ],
                  ),
                ],

                const SizedBox(height: 16),

                // Device Information
                if (_appInfo != null && _appInfo!['device'] != null) ...[
                  _buildInfoSection(
                    'Device Information',
                    Icons.phone_android,
                    [
                      _buildInfoRow('Platform', _appInfo!['device']['platform'] ?? 'Unknown'),
                      _buildInfoRow('Model', _appInfo!['device']['model'] ?? 'Unknown'),
                      if (_appInfo!['device']['systemName'] != null)
                        _buildInfoRow('System', _appInfo!['device']['systemName']),
                      if (_appInfo!['device']['systemVersion'] != null)
                        _buildInfoRow('Version', _appInfo!['device']['systemVersion']),
                      _buildInfoRow(
                        'Device Type',
                        _appInfo!['device']['isPhysicalDevice'] == true ? 'Physical' : 'Simulator',
                      ),
                    ],
                  ),
                ],

                const SizedBox(height: 16),

                // App Statistics
                if (_appStats != null) ...[
                  _buildInfoSection(
                    'App Statistics',
                    Icons.analytics,
                    [
                      _buildInfoRow('Total Sessions', _appStats!['total_sessions'].toString()),
                      _buildInfoRow('Total Entries', _appStats!['total_entries'].toString()),
                      _buildInfoRow('Total Arcforms', _appStats!['total_arcforms'].toString()),
                      _buildInfoRow('First Launch', _formatDate(_appStats!['first_launch'])),
                      _buildInfoRow('Last Launch', _formatDate(_appStats!['last_launch'])),
                    ],
                  ),
                ],

                const SizedBox(height: 16),

                // Features
                if (_appStats != null && _appStats!['features_used'] != null) ...[
                  _buildInfoSection(
                    'Features',
                    Icons.star,
                    _appStats!['features_used'].map<Widget>((feature) => 
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.check_circle,
                              color: Colors.green,
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              feature,
                              style: const TextStyle(color: Colors.white70),
                            ),
                          ],
                        ),
                      ),
                    ).toList(),
                  ),
                ],

                const SizedBox(height: 16),

                // Credits
                _buildInfoSection(
                  'Credits',
                  Icons.people,
                  [
                    _buildInfoRow('Development', 'Claude Code Assistant'),
                    _buildInfoRow('Framework', 'Flutter'),
                    _buildInfoRow('State Management', 'Bloc/Cubit'),
                    _buildInfoRow('Storage', 'Hive'),
                    _buildInfoRow('UI/UX', 'Material Design 3'),
                  ],
                ),

                const SizedBox(height: 32),
              ],
            ),
    );
  }

  Widget _buildInfoSection(String title, IconData icon, List<Widget> children) {
    return Card(
      color: Colors.grey[900],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: Colors.blue, size: 20),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(String? dateString) {
    if (dateString == null) return 'Unknown';
    try {
      final date = DateTime.parse(dateString);
      return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    } catch (e) {
      return 'Unknown';
    }
  }
}
