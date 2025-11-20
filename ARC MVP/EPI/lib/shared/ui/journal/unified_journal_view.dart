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

class _UnifiedJournalViewState extends State<UnifiedJournalView>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _previousIndex = 0;
  bool _isNavigatingToSettings = false;

  @override
  void initState() {
    super.initState();
    // Tab controller length: Timeline + Settings = 2 (LUMARA moved to bottom navigation)
    final tabCount = 2;
    _tabController = TabController(length: tabCount, vsync: this);
    _tabController.addListener(_handleTabChange);
  }

  void _handleTabChange() {
    if (!mounted) return;
    
    final tabCount = 2; // Timeline + Settings
    
    // Navigate to Settings when Settings tab is selected
    if (_tabController.index == tabCount - 1 && !_isNavigatingToSettings) {
      _isNavigatingToSettings = true;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const SettingsView(),
        ),
      ).then((_) {
        // Return to previous tab after Settings is closed
        if (mounted) {
          _isNavigatingToSettings = false;
          // Temporarily remove listener to prevent triggering during animateTo
          _tabController.removeListener(_handleTabChange);
          _tabController.animateTo(_previousIndex);
          // Re-add listener after animation
          Future.delayed(const Duration(milliseconds: 300), () {
            if (mounted) {
              _tabController.addListener(_handleTabChange);
            }
          });
        }
      });
    } else if (_tabController.index != tabCount - 1) {
      // Track previous index (excluding Settings tab)
      _previousIndex = _tabController.index;
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        top: false, // Remove top SafeArea padding to raise the tab bar
        bottom: true, // Keep bottom SafeArea padding
        child: Column(
          children: [
            // Tab bar for Timeline and Settings
            Container(
              padding: const EdgeInsets.only(bottom: 4), // Add bottom padding to raise text above bar
              color: kcBackgroundColor,
              child: SizedBox(
                height: 42, // Increased height to accommodate icon+text+padding without overflow
                child: TabBar(
                  controller: _tabController,
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.grey,
                  indicatorColor: Colors.purple,
                  indicatorWeight: 2, // Reduced from 3 to 2
                  labelPadding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 2), // Added vertical padding to raise text
                  labelStyle: const TextStyle(fontSize: 13), // Increased from 11 to 13 for better readability
                  unselectedLabelStyle: const TextStyle(fontSize: 13), // Increased from 11 to 13 for better readability
                  tabs: [
                    const Tab(
                      icon: Icon(Icons.timeline, size: 16), // Reduced from 18 to 16
                      text: 'Timeline',
                    ),
                    const Tab(
                      icon: Icon(Icons.settings, size: 16), // Reduced from 18 to 16
                      text: 'Settings',
                    ),
                  ],
                ),
              ),
            ),
            // Tab bar view content
            Expanded(
              child: TabBarView(
                controller: _tabController,
                physics: const NeverScrollableScrollPhysics(), // Disable swipe to prevent accessing Settings tab
                children: [
                  // Timeline tab
                  const TimelineView(),
                  // Settings placeholder (will navigate instead)
                  const SizedBox.shrink(),
                ],
              ),
            ),
          ],
        ),
      ),
      // FAB moved to center of bottom navigation bar
    );
  }
}

