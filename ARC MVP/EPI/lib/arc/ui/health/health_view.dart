import 'package:flutter/material.dart';
import 'package:my_app/arc/ui/health/health_detail_view.dart';
import 'package:my_app/arc/ui/health/health_settings_dialog.dart';
import 'package:my_app/arc/ui/health/medication_manager.dart';
import 'package:my_app/ui/health/health_detail_screen.dart';
import 'package:my_app/shared/app_colors.dart';

class HealthView extends StatefulWidget {
  const HealthView({super.key});

  @override
  State<HealthView> createState() => _HealthViewState();
}

class _HealthViewState extends State<HealthView> {
  String _selectedMainView = 'health'; // 'health' or 'medications'
  int _daysBack = 30; // 30, 60, or 90 days for health details
  final _healthSummaryKey = GlobalKey<State<HealthSummaryBody>>();
  final _healthDetailsKey = GlobalKey<State<HealthDetailScreenBody>>();

  void _showInfoDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        title: const Text('Health Tab Overview'),
        content: const SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Overview',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              SizedBox(height: 8),
              Text(
                'View your daily health summary including steps, heart rate, and a 7-day overview.',
                style: TextStyle(fontSize: 14),
              ),
              SizedBox(height: 16),
              Text(
                'Details',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              SizedBox(height: 8),
              Text(
                'See detailed metrics over time with interactive charts for steps, energy, sleep, heart rate, and more.',
                style: TextStyle(fontSize: 14),
              ),
              SizedBox(height: 16),
              Text(
                'Analytics',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              SizedBox(height: 8),
              Text(
                'Deep dive into health analytics, trends, and patterns across your health data.',
                style: TextStyle(fontSize: 14),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Health'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            tooltip: 'Health tab overview',
            onPressed: () => _showInfoDialog(context),
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Health Settings',
            onPressed: () async {
              await showDialog(
                context: context,
                builder: (context) => const HealthSettingsDialog(),
              );
              // Refresh health summary after dialog closes
              final state = _healthSummaryKey.currentState;
              if (state is RefreshableHealthSummary) {
                state.refreshHealthData();
              }
            },
          ),
        ],
      ),
      body: Container(
        color: kcBackgroundColor,
        child: Column(
          children: [
            // SegmentedButton for main view selection
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
              child: SegmentedButton<String>(
                segments: const [
                  ButtonSegment(
                    value: 'health',
                    label: Text('Health'),
                    icon: Icon(Icons.favorite_outline, size: 18),
                  ),
                  ButtonSegment(
                    value: 'medications',
                    label: Text('Medications'),
                    icon: Icon(Icons.medication_liquid, size: 18),
                  ),
                ],
                selected: {_selectedMainView},
                onSelectionChanged: (Set<String> selected) {
                  setState(() {
                    _selectedMainView = selected.first;
                  });
                },
              ),
            ),
            // Content based on selection
            Expanded(
              child: _selectedMainView == 'health'
                  ? _buildCombinedHealthTab()
                  : const MedicationManager(),
            ),
          ],
        ),
      ),
    );
  }

  /// Combined Health Tab (Overview + Details)
  /// Uses SegmentedButton instead of nested TabBar to avoid double navigation
  Widget _buildCombinedHealthTab() {
    return _CombinedHealthTabContent(
      healthSummaryKey: _healthSummaryKey,
      healthDetailsKey: _healthDetailsKey,
      daysBack: _daysBack,
      onDaysChanged: (days) {
        setState(() {
          _daysBack = days;
        });
      },
    );
  }
}

/// Combined Health Tab Content with SegmentedButton (no nested TabBar)
class _CombinedHealthTabContent extends StatefulWidget {
  final GlobalKey<State<HealthSummaryBody>> healthSummaryKey;
  final GlobalKey<State<HealthDetailScreenBody>> healthDetailsKey;
  final int daysBack;
  final ValueChanged<int> onDaysChanged;

  const _CombinedHealthTabContent({
    required this.healthSummaryKey,
    required this.healthDetailsKey,
    required this.daysBack,
    required this.onDaysChanged,
  });

  @override
  State<_CombinedHealthTabContent> createState() => _CombinedHealthTabContentState();
}

class _CombinedHealthTabContentState extends State<_CombinedHealthTabContent> {
  String _selectedView = 'overview';

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // SegmentedButton instead of TabBar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
          child: SegmentedButton<String>(
            segments: const [
              ButtonSegment(
                value: 'overview',
                label: Text('Overview'),
                icon: Icon(Icons.favorite_outline, size: 18),
              ),
              ButtonSegment(
                value: 'details',
                label: Text('Details'),
                icon: Icon(Icons.show_chart, size: 18),
              ),
            ],
            selected: {_selectedView},
            onSelectionChanged: (Set<String> selected) {
              setState(() {
                _selectedView = selected.first;
              });
            },
          ),
        ),
        // Content based on selection
        Expanded(
          child: _selectedView == 'overview'
              ? HealthSummaryBody(key: widget.healthSummaryKey, pointerJson: const {})
              : _HealthDetailsTab(
                  key: widget.healthDetailsKey,
                  daysBack: widget.daysBack,
                  onDaysChanged: widget.onDaysChanged,
                ),
        ),
      ],
    );
  }
}

/// Wrapper widget for Health Details tab content
class _HealthDetailsTab extends StatefulWidget {
  final int daysBack;
  final ValueChanged<int> onDaysChanged;
  
  const _HealthDetailsTab({
    super.key,
    required this.daysBack,
    required this.onDaysChanged,
  });

  @override
  State<_HealthDetailsTab> createState() => _HealthDetailsTabState();
}

class _HealthDetailsTabState extends State<_HealthDetailsTab> {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Days selector
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          color: Theme.of(context).scaffoldBackgroundColor,
          child: SafeArea(
            bottom: false,
            child: Row(
              children: [
                const Text(
                  'Time Range:',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: SegmentedButton<int>(
                    segments: const [
                      ButtonSegment(value: 30, label: Text('30')),
                      ButtonSegment(value: 60, label: Text('60')),
                      ButtonSegment(value: 90, label: Text('90')),
                    ],
                    selected: {widget.daysBack},
                    onSelectionChanged: (Set<int> selected) {
                      if (selected.isNotEmpty) {
                        widget.onDaysChanged(selected.first);
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
        // Health detail content
        Expanded(
          child: HealthDetailScreenBody(
            key: ValueKey(widget.daysBack), // Force rebuild when daysBack changes
            daysBack: widget.daysBack,
          ),
        ),
      ],
    );
  }
}

