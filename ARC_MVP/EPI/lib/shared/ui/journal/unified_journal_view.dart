// lib/shared/ui/journal/unified_journal_view.dart
// Unified Journal View - Combines Timeline and Voice Notes into a single section

import 'package:flutter/material.dart';
import 'package:my_app/arc/ui/timeline/timeline_with_ideas_view.dart';

class UnifiedJournalView extends StatefulWidget {
  const UnifiedJournalView({super.key});

  @override
  State<UnifiedJournalView> createState() => _UnifiedJournalViewState();
}

class _UnifiedJournalViewState extends State<UnifiedJournalView> {

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: SafeArea(
        top: false,
        bottom: true,
        child: TimelineWithIdeasView(), // Shows Timeline + Voice Notes tabs
      ),
    );
  }
}

