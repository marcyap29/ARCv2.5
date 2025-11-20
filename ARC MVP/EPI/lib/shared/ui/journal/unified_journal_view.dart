// lib/shared/ui/journal/unified_journal_view.dart
// Unified Journal View - Combines Timeline and LUMARA into a single section

import 'package:flutter/material.dart';
import 'package:my_app/arc/ui/timeline/timeline_view.dart';
import 'package:my_app/shared/app_colors.dart';
import 'package:my_app/shared/ui/settings/settings_view.dart';

class UnifiedJournalView extends StatefulWidget {
  const UnifiedJournalView({super.key});

  @override
  State<UnifiedJournalView> createState() => _UnifiedJournalViewState();
}

class _UnifiedJournalViewState extends State<UnifiedJournalView> {

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        top: false,
        bottom: true,
        child: const TimelineView(), // Directly show TimelineView without tab bar
      ),
    );
  }
}

