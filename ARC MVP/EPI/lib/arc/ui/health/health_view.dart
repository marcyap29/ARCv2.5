import 'package:flutter/material.dart';
import 'package:my_app/insights/analytics_page.dart';
import 'package:my_app/arc/ui/health/health_detail_view.dart';
import 'package:my_app/arc/ui/health/health_settings_dialog.dart';
import 'package:my_app/shared/app_colors.dart';

class HealthView extends StatefulWidget {
  const HealthView({super.key});

  @override
  State<HealthView> createState() => _HealthViewState();
}

class _HealthViewState extends State<HealthView> {
  int _selected = 0; // 0: Health Insights, 1: Analytics

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
                'Health Insights',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              SizedBox(height: 8),
              Text(
                'View your daily health summary including steps, heart rate, and a 7-day overview. Tap the chart icon to see detailed metrics over time with interactive charts.',
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
      length: 2,
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
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => const HealthSettingsDialog(),
                );
              },
            ),
          ],
          bottom: TabBar(
            isScrollable: true,
            onTap: (i) => setState(() => _selected = i),
            tabs: const [
              Tab(icon: Icon(Icons.favorite_outline, size: 20), text: 'Health Insights'),
              Tab(icon: Icon(Icons.stacked_line_chart, size: 20), text: 'Analytics'),
            ],
          ),
        ),
        body: Container(
          color: kcBackgroundColor,
          child: TabBarView(
            physics: const BouncingScrollPhysics(),
            children: [
              // Show the Health Summary content directly in the Health Insights tab
              const HealthSummaryBody(pointerJson: {}),
              // Render Analytics content directly within the Health tab
              const AnalyticsContent(),
            ],
          ),
        ),
      ),
    );
  }
}


