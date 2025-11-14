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
  String _selectedMainView = 'overview'; // 'overview', 'details', or 'medications' - combined into single bar
  String _selectedHealthView = 'overview'; // 'overview' or 'details' - persists across rebuilds
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
        title: const Text(''), // Removed redundant "Health" title
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
            // Horizontally scrollable button bar combining Overview, Details, and Medications
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
              child: SizedBox(
                height: 36, // Reduced height for compact bar
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildHealthButton('overview', 'Overview', Icons.favorite_outline),
                      const SizedBox(width: 8),
                      _buildHealthButton('details', 'Details', Icons.show_chart),
                      const SizedBox(width: 8),
                      _buildHealthButton('medications', 'Medications', Icons.medication_liquid),
                    ],
                  ),
                ),
              ),
            ),
            // Content based on selection
            Expanded(
              child: _buildContentForHealthView(_selectedMainView),
            ),
          ],
        ),
      ),
    );
  }

  /// Build health navigation button
  Widget _buildHealthButton(String value, String label, IconData icon) {
    final isSelected = _selectedMainView == value;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedMainView = value;
          // If switching to overview or details, update health view to match
          if (value == 'overview' || value == 'details') {
            _selectedHealthView = value;
          }
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? Colors.purple.withOpacity(0.3) : Colors.grey.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? Colors.purple : Colors.grey.withOpacity(0.3),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: isSelected ? Colors.white : Colors.grey),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                color: isSelected ? Colors.white : Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build content based on selected health view
  Widget _buildContentForHealthView(String view) {
    // Update selectedHealthView to match the main view when needed
    if ((view == 'overview' || view == 'details') && _selectedHealthView != view) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _selectedHealthView = view;
          });
        }
      });
    }
    
    switch (view) {
      case 'overview':
      case 'details':
        return _buildCombinedHealthTab();
      case 'medications':
        return const MedicationManager();
      default:
        return _buildCombinedHealthTab();
    }
  }

  /// Combined Health Tab (Overview + Details)
  /// Navigation now handled at top level, this just shows the content
  Widget _buildCombinedHealthTab() {
    // Show content based on selectedHealthView (overview or details)
    if (_selectedHealthView == 'details') {
      return _HealthDetailsTab(
        key: _healthDetailsKey,
        daysBack: _daysBack,
        onDaysChanged: (days) {
          setState(() {
            _daysBack = days;
          });
        },
      );
    } else {
      // Default to overview
      return HealthSummaryBody(key: _healthSummaryKey, pointerJson: const {});
    }
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

