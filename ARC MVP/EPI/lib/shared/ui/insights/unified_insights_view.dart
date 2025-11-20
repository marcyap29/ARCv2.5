// lib/shared/ui/insights/unified_insights_view.dart
// Unified Insights View - Combines Phase, Health, and Analytics into a single section

import 'package:flutter/material.dart';
import 'package:my_app/ui/phase/phase_analysis_view.dart';

class UnifiedInsightsView extends StatefulWidget {
  const UnifiedInsightsView({super.key});

  @override
  State<UnifiedInsightsView> createState() => _UnifiedInsightsViewState();
}

class _UnifiedInsightsViewState extends State<UnifiedInsightsView>
    with TickerProviderStateMixin {
  TabController? _tabController;
  int _previousIndex = 0;
  bool _isNavigatingToSettings = false;
  bool _advancedAnalyticsEnabled = false;
  bool _isLoadingPreference = true;
  bool _isInitialLoad = true;

  @override
  void initState() {
    super.initState();
    _loadPreference();
  }

  // No longer need any of the tab controller logic

  @override
  Widget build(BuildContext context) {
    // No longer need tab controller or preference loading
    // Just show PhaseAnalysisView directly
    return Scaffold(
      body: SafeArea(
        child: const PhaseAnalysisView(),
      ),
    );
  }
}

