import 'package:flutter/material.dart';
import 'package:my_app/insights/analytics_page.dart';
import 'package:my_app/arc/ui/health/health_detail_view.dart';
import 'package:my_app/arc/ui/health/health_settings_dialog.dart';
import 'package:my_app/ui/health/health_detail_screen.dart';
import 'package:my_app/shared/app_colors.dart';

class HealthView extends StatefulWidget {
  const HealthView({super.key});

  @override
  State<HealthView> createState() => _HealthViewState();
}

class _HealthViewState extends State<HealthView> {
  int _selected = 0; // 0: Overview, 1: Details, 2: Analytics
  final _healthSummaryKey = GlobalKey<State<HealthSummaryBody>>();

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
    return DefaultTabController(
      length: 3,
      initialIndex: _selected,
      child: Scaffold(
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
          bottom: TabBar(
            isScrollable: true,
            onTap: (i) => setState(() => _selected = i),
            tabs: const [
              Tab(icon: Icon(Icons.favorite_outline, size: 20), text: 'Overview'),
              Tab(icon: Icon(Icons.show_chart, size: 20), text: 'Details'),
              Tab(icon: Icon(Icons.stacked_line_chart, size: 20), text: 'Analytics'),
            ],
          ),
        ),
        body: Container(
          color: kcBackgroundColor,
          child: TabBarView(
            physics: const BouncingScrollPhysics(),
            children: [
              // Show the Health Summary content directly in the Overview tab
              HealthSummaryBody(key: _healthSummaryKey, pointerJson: const {}),
              // Show the Health Detail Screen in the Details tab
              const _HealthDetailsTab(),
              // Render Analytics content directly within the Health tab
              const AnalyticsContent(),
            ],
          ),
        ),
      ),
    );
  }
}

/// Wrapper widget for Health Details tab content
class _HealthDetailsTab extends StatefulWidget {
  const _HealthDetailsTab();

  @override
  State<_HealthDetailsTab> createState() => _HealthDetailsTabState();
}

class _HealthDetailsTabState extends State<_HealthDetailsTab> {
  @override
  Widget build(BuildContext context) {
    // Use HealthDetailScreen but without the Scaffold (since we're in a TabBarView)
    // We need to extract just the body content
    return const HealthDetailScreenBody(daysBack: 30);
  }
}

