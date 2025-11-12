// lib/shared/ui/insights/unified_insights_view.dart
// Unified Insights View - Combines Phase, Health, and Analytics into a single section

import 'package:flutter/material.dart';
import 'package:my_app/ui/phase/phase_analysis_view.dart';
import 'package:my_app/arc/ui/health/health_view.dart';
import 'package:my_app/insights/analytics_page.dart';
import 'package:my_app/shared/app_colors.dart';
import 'package:my_app/shared/ui/settings/settings_view.dart';

class UnifiedInsightsView extends StatefulWidget {
  const UnifiedInsightsView({super.key});

  @override
  State<UnifiedInsightsView> createState() => _UnifiedInsightsViewState();
}

class _UnifiedInsightsViewState extends State<UnifiedInsightsView>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this); // Phase + Health + Analytics
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: kcBackgroundColor,
        elevation: 0,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SettingsView(),
                ),
              );
            },
            tooltip: 'Settings',
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Tab bar for Phase, Health, and Analytics
            Container(
              color: kcBackgroundColor,
              child: TabBar(
                controller: _tabController,
                isScrollable: true,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.grey,
                indicatorColor: Colors.purple,
                indicatorWeight: 3,
                labelPadding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                labelStyle: const TextStyle(fontSize: 13),
                unselectedLabelStyle: const TextStyle(fontSize: 13),
                tabs: const [
                  Tab(
                    icon: Icon(Icons.auto_awesome, size: 18),
                    text: 'Phase',
                  ),
                  Tab(
                    icon: Icon(Icons.favorite, size: 18),
                    text: 'Health',
                  ),
                  Tab(
                    icon: Icon(Icons.analytics, size: 18),
                    text: 'Analytics',
                  ),
                ],
              ),
            ),
            // Tab bar view content
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: const [
                  // Phase Analysis tab
                  PhaseAnalysisView(),
                  // Health tab
                  HealthView(),
                  // Analytics tab
                  AnalyticsPage(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

