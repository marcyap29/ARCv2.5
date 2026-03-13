// lib/lumara/agents/screens/plugin_activity_screen.dart
//
// Plugin Activity — local SharedPreferences counter with monthly reset.
// No Firestore. Shows total and per-plugin counts for the current month.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:my_app/services/swarmspace/plugin_activity_log_service.dart';
import 'package:my_app/shared/app_colors.dart';
import 'package:my_app/shared/text_style.dart';

/// Display names for plugins (PLUGIN_REGISTRY alignment).
const Map<String, String> _pluginDisplayNames = {
  'brave-search': 'Brave Search',
  'semantic-scholar': 'Semantic Scholar',
  'gemini-flash': 'Gemini Flash',
  'vision-ocr': 'Vision/Scanning',
  'url-reader': 'URL Reader',
  'media-upload': 'Media Upload',
  'tavily-search': 'Tavily Search',
  'exa-search': 'Exa Search',
  'perplexity-sonar': 'Perplexity Sonar',
  'weather': 'Weather',
  'wikipedia': 'Wikipedia',
  'currency': 'Currency',
  'news': 'News',
};

String _displayName(String pluginId) =>
    _pluginDisplayNames[pluginId] ??
    pluginId.split('-').map((s) => s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}').join(' ');

class PluginActivityScreen extends StatefulWidget {
  const PluginActivityScreen({super.key});

  @override
  State<PluginActivityScreen> createState() => _PluginActivityScreenState();
}

class _PluginActivityScreenState extends State<PluginActivityScreen> {
  Map<String, int> _counts = {};
  int _total = 0;
  DateTime _nextReset = DateTime.now();
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final counts = await PluginActivityLogService.instance.getActivityCounts();
    final total = await PluginActivityLogService.instance.getTotalThisMonth();
    final nextReset = PluginActivityLogService.instance.getNextResetDate();
    if (mounted) {
      setState(() {
        _counts = counts;
        _total = total;
        _nextReset = nextReset;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final monthYear = DateFormat('MMMM yyyy').format(now);
    final resetStr = DateFormat('d MMMM yyyy').format(_nextReset);

    return Scaffold(
      backgroundColor: kcBackgroundColor,
      appBar: AppBar(
        backgroundColor: kcBackgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
          color: kcPrimaryTextColor,
        ),
        title: Text(
          'Plugin Activity — $monthYear',
          style: heading2Style(context).copyWith(
            color: kcPrimaryTextColor,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _load,
            tooltip: 'Refresh',
            color: kcPrimaryTextColor,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Resets $resetStr',
                      style: bodyStyle(context).copyWith(
                        color: kcSecondaryTextColor,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (_total == 0) ...[
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Text(
                            'No plugin activity this month',
                            style: bodyStyle(context).copyWith(
                              color: kcSecondaryTextColor,
                              fontSize: 16,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ] else ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                        decoration: BoxDecoration(
                          color: kcSurfaceAltColor,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Total calls this month',
                              style: bodyStyle(context).copyWith(
                                color: kcPrimaryTextColor,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              '$_total',
                              style: heading2Style(context).copyWith(
                                color: kcPrimaryColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      ...(_counts.entries.toList()
                        ..sort((a, b) => b.value.compareTo(a.value)))
                          .map((e) => _PluginRow(
                                pluginId: e.key,
                                displayName: _displayName(e.key),
                                count: e.value,
                                maxCount: _counts.values.isEmpty ? 1 : _counts.values.reduce((a, b) => a > b ? a : b),
                              )),
                    ],
                  ],
                ),
              ),
            ),
    );
  }
}

class _PluginRow extends StatelessWidget {
  const _PluginRow({
    required this.pluginId,
    required this.displayName,
    required this.count,
    required this.maxCount,
  });

  final String pluginId;
  final String displayName;
  final int count;
  final int maxCount;

  @override
  Widget build(BuildContext context) {
    final barWidth = maxCount > 0 ? (count / maxCount).clamp(0.0, 1.0) : 0.0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              displayName,
              style: bodyStyle(context).copyWith(
                color: kcPrimaryTextColor,
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '$count',
            style: bodyStyle(context).copyWith(
              color: kcSecondaryTextColor,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 3,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: barWidth,
                minHeight: 6,
                backgroundColor: kcSurfaceAltColor,
                valueColor: const AlwaysStoppedAnimation<Color>(kcPrimaryColor),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
