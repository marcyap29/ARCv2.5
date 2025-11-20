// lib/shared/ui/journal/unified_journal_view.dart
// Unified Journal View - Timeline only (LUMARA moved to bottom navigation)

import 'package:flutter/material.dart';
import 'package:my_app/arc/ui/timeline/timeline_view.dart';

class UnifiedJournalView extends StatelessWidget {
  const UnifiedJournalView({super.key});

  @override
  Widget build(BuildContext context) {
    // LUMARA is now in the bottom navigation bar, so this view only shows Timeline
    return const TimelineView();
  }
}

