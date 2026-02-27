// lib/shared/ui/insights/unified_insights_view.dart
// Unified Insights View - Shows PhaseAnalysisView directly

import 'package:flutter/material.dart';
import 'package:my_app/ui/phase/phase_analysis_view.dart';

class UnifiedInsightsView extends StatefulWidget {
  const UnifiedInsightsView({super.key});

  @override
  State<UnifiedInsightsView> createState() => _UnifiedInsightsViewState();
}

class _UnifiedInsightsViewState extends State<UnifiedInsightsView> {
  @override
  Widget build(BuildContext context) {
    // Directly show PhaseAnalysisView - no tabs needed
    return const Scaffold(
      body: SafeArea(
        child: PhaseAnalysisView(),
      ),
    );
  }
}
