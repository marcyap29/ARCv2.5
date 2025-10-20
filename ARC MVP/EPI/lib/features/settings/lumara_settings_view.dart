import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../shared/app_colors.dart';
import '../../shared/text_style.dart';
import '../../lumara/services/enhanced_lumara_api.dart';
import '../../telemetry/analytics.dart';

class LumaraSettingsView extends StatefulWidget {
  const LumaraSettingsView({super.key});

  @override
  State<LumaraSettingsView> createState() => _LumaraSettingsViewState();
}

class _LumaraSettingsViewState extends State<LumaraSettingsView> {
  final _analytics = Analytics();
  final _enhancedApi = EnhancedLumaraApi(Analytics());
  
  // Settings state
  String? _mcpBundlePath;
  double _similarityThreshold = 0.55;
  int _lookbackYears = 5;
  int _maxMatches = 5;
  bool _crossModalEnabled = true;
  bool _isInitialized = false;
  int _nodeCount = 0;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    // TODO: Load from SharedPreferences or similar
    // For now, use defaults
    setState(() {
      _isInitialized = true;
    });
  }

  Future<void> _saveSettings() async {
    // TODO: Save to SharedPreferences
    _analytics.logLumaraEvent('settings_updated', data: {
      'similarityThreshold': _similarityThreshold,
      'lookbackYears': _lookbackYears,
      'maxMatches': _maxMatches,
      'crossModalEnabled': _crossModalEnabled,
    });
  }

  Future<void> _selectMcpBundle() async {
    // TODO: Implement file picker for MCP bundle selection
    // For now, show a placeholder dialog
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select MCP Bundle'),
        content: const Text('MCP bundle selection will be implemented in a future update. For now, LUMARA will work with any previously imported data.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _indexCurrentBundle() async {
    if (_mcpBundlePath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select an MCP bundle first'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      setState(() {
        _isInitialized = false;
      });

      await _enhancedApi.indexMcpBundle(_mcpBundlePath!);
      
      final status = _enhancedApi.getStatus();
      setState(() {
        _nodeCount = status['nodeCount'] ?? 0;
        _isInitialized = true;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Successfully indexed $_nodeCount nodes from MCP bundle'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      setState(() {
        _isInitialized = true;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to index bundle: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kcBackgroundColor,
      appBar: AppBar(
        backgroundColor: kcBackgroundColor,
        elevation: 0,
        title: Text(
          'LUMARA Settings',
          style: heading1Style(context).copyWith(
            color: kcPrimaryTextColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        iconTheme: const IconThemeData(color: kcPrimaryTextColor),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status Section
            _buildSection(
              context,
              title: 'Status',
              children: [
                _buildStatusCard(),
              ],
            ),

            const SizedBox(height: 32),

            // Data Source Section
            _buildSection(
              context,
              title: 'Data Source',
              children: [
                _buildSettingsTile(
                  context,
                  title: 'MCP Bundle Path',
                  subtitle: _mcpBundlePath ?? 'No bundle selected',
                  icon: Icons.folder,
                  onTap: _selectMcpBundle,
                ),
                _buildActionButton(
                  context,
                  title: 'Index Current Bundle',
                  subtitle: 'Process MCP bundle for reflection data',
                  icon: Icons.refresh,
                  onTap: _indexCurrentBundle,
                  enabled: _mcpBundlePath != null,
                ),
              ],
            ),

            const SizedBox(height: 32),

            // Reflection Settings Section
            _buildSection(
              context,
              title: 'Reflection Settings',
              children: [
                _buildSliderTile(
                  context,
                  title: 'Similarity Threshold',
                  subtitle: 'Minimum similarity score for matching entries (${_similarityThreshold.toStringAsFixed(2)})',
                  value: _similarityThreshold,
                  min: 0.1,
                  max: 1.0,
                  divisions: 18,
                  onChanged: (value) {
                    setState(() {
                      _similarityThreshold = value;
                    });
                    _saveSettings();
                  },
                ),
                _buildSliderTile(
                  context,
                  title: 'Lookback Period',
                  subtitle: 'Years of history to search ($_lookbackYears years)',
                  value: _lookbackYears.toDouble(),
                  min: 1,
                  max: 10,
                  divisions: 9,
                  onChanged: (value) {
                    setState(() {
                      _lookbackYears = value.round();
                    });
                    _saveSettings();
                  },
                ),
                _buildSliderTile(
                  context,
                  title: 'Max Matches',
                  subtitle: 'Maximum number of similar entries to find ($_maxMatches)',
                  value: _maxMatches.toDouble(),
                  min: 1,
                  max: 20,
                  divisions: 19,
                  onChanged: (value) {
                    setState(() {
                      _maxMatches = value.round();
                    });
                    _saveSettings();
                  },
                ),
                _buildSwitchTile(
                  context,
                  title: 'Cross-Modal Awareness',
                  subtitle: 'Include photos, audio, and video in reflection analysis',
                  value: _crossModalEnabled,
                  onChanged: (value) {
                    setState(() {
                      _crossModalEnabled = value;
                    });
                    _saveSettings();
                  },
                ),
              ],
            ),

            const SizedBox(height: 32),

            // About LUMARA Section
            _buildSection(
              context,
              title: 'About LUMARA',
              children: [
                _buildInfoCard(),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _isInitialized ? Colors.green.withValues(alpha: 0.1) : Colors.orange.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _isInitialized ? Colors.green.withValues(alpha: 0.3) : Colors.orange.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            _isInitialized ? Icons.check_circle : Icons.warning,
            color: _isInitialized ? Colors.green : Colors.orange,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isInitialized ? 'LUMARA Active' : 'LUMARA Not Initialized',
                  style: heading3Style(context).copyWith(
                    color: kcPrimaryTextColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _isInitialized 
                    ? 'Indexed $_nodeCount reflective nodes'
                    : 'No data indexed yet',
                  style: bodyStyle(context).copyWith(
                    color: kcSecondaryTextColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.blue.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.auto_awesome,
                color: Colors.blue,
                size: 24,
              ),
              const SizedBox(width: 12),
              Text(
                'LUMARA v2.0',
                style: heading3Style(context).copyWith(
                  color: kcPrimaryTextColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'LUMARA is your multimodal reflective partner that connects your current thoughts to historical insights across text, photos, audio, and video.',
            style: bodyStyle(context).copyWith(
              color: kcSecondaryTextColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Features:',
            style: bodyStyle(context).copyWith(
              color: kcPrimaryTextColor,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '• Semantic similarity matching\n• Phase-aware reflection prompts\n• Cross-modal pattern detection\n• 3-5 year historical lookback',
            style: bodyStyle(context).copyWith(
              color: kcSecondaryTextColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(BuildContext context, {
    required String title,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: heading2Style(context).copyWith(
            color: kcPrimaryTextColor,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        ...children,
      ],
    );
  }

  Widget _buildSettingsTile(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    VoidCallback? onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
        ),
      ),
      child: ListTile(
        leading: Icon(
          icon,
          color: kcAccentColor,
          size: 24,
        ),
        title: Text(
          title,
          style: heading3Style(context).copyWith(
            color: kcPrimaryTextColor,
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: bodyStyle(context).copyWith(
            color: kcSecondaryTextColor,
          ),
        ),
        trailing: onTap != null
            ? const Icon(
                Icons.arrow_forward_ios,
                color: kcSecondaryTextColor,
                size: 16,
              )
            : null,
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 8,
        ),
      ),
    );
  }

  Widget _buildActionButton(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
    bool enabled = true,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: enabled 
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.grey.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: enabled 
              ? Colors.white.withValues(alpha: 0.1)
              : Colors.grey.withValues(alpha: 0.3),
        ),
      ),
      child: ListTile(
        leading: Icon(
          icon,
          color: enabled ? kcAccentColor : Colors.grey,
          size: 24,
        ),
        title: Text(
          title,
          style: heading3Style(context).copyWith(
            color: enabled ? kcPrimaryTextColor : Colors.grey,
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: bodyStyle(context).copyWith(
            color: enabled ? kcSecondaryTextColor : Colors.grey,
          ),
        ),
        trailing: enabled
            ? const Icon(
                Icons.arrow_forward_ios,
                color: kcSecondaryTextColor,
                size: 16,
              )
            : null,
        onTap: enabled ? onTap : null,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 8,
        ),
      ),
    );
  }

  Widget _buildSliderTile(
    BuildContext context, {
    required String title,
    required String subtitle,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required ValueChanged<double> onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.tune,
                color: kcAccentColor,
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: heading3Style(context).copyWith(
                        color: kcPrimaryTextColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: bodyStyle(context).copyWith(
                        color: kcSecondaryTextColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Slider(
            value: value,
            min: min,
            max: max,
            divisions: divisions,
            activeColor: kcAccentColor,
            inactiveColor: Colors.grey.withValues(alpha: 0.3),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildSwitchTile(
    BuildContext context, {
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
        ),
      ),
      child: SwitchListTile(
        title: Text(
          title,
          style: heading3Style(context).copyWith(
            color: kcPrimaryTextColor,
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: bodyStyle(context).copyWith(
            color: kcSecondaryTextColor,
          ),
        ),
        value: value,
        onChanged: onChanged,
        activeColor: kcAccentColor,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 8,
        ),
      ),
    );
  }
}