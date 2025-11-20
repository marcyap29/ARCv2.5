// lib/shared/ui/journal/unified_journal_view.dart
// Unified Journal View - Combines Timeline and LUMARA into a single section

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:my_app/arc/ui/timeline/timeline_view.dart';
import 'package:my_app/arc/chat/ui/lumara_assistant_screen.dart';
import 'package:my_app/arc/chat/bloc/lumara_assistant_cubit.dart';
import 'package:my_app/arc/chat/data/context_provider.dart';
import 'package:my_app/arc/chat/data/context_scope.dart';
import 'package:my_app/core/app_flags.dart';
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
  LumaraAssistantCubit? _lumaraCubit;
  int _previousIndex = 0;
  bool _isNavigatingToSettings = false;

  @override
  void initState() {
    super.initState();
    // Tab controller length: Timeline + LUMARA (if enabled) + Settings = 2 or 3
    final tabCount = AppFlags.isLumaraEnabled ? 3 : 2;
    _tabController = TabController(length: tabCount, vsync: this);
    _tabController.addListener(_handleTabChange);
    
    // Initialize LUMARA cubit if enabled
    if (AppFlags.isLumaraEnabled) {
      _lumaraCubit = LumaraAssistantCubit(
        contextProvider: ContextProvider(LumaraScope.defaultScope),
      );
      _lumaraCubit!.initializeLumara();
    }
  }

  void _handleTabChange() {
    if (!mounted) return;
    
    final tabCount = AppFlags.isLumaraEnabled ? 3 : 2;
    
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
    _lumaraCubit?.close();
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
            // Tab bar for Timeline and LUMARA
            Container(
              padding: const EdgeInsets.only(bottom: 2), // Reduced bottom padding
              color: kcBackgroundColor,
              child: SizedBox(
                height: 32, // Reduced height to save vertical space
                child: TabBar(
                  controller: _tabController,
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.grey,
                  indicatorColor: Colors.purple,
                  indicatorWeight: 2,
                  labelPadding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 0), // Reduced vertical padding
                  labelStyle: const TextStyle(fontSize: 12), // Reduced font size
                  unselectedLabelStyle: const TextStyle(fontSize: 12), // Reduced font size
                  tabs: [
                    const Tab(
                      icon: Icon(Icons.timeline, size: 14), // Reduced icon size
                      text: 'Timeline',
                    ),
                    if (AppFlags.isLumaraEnabled)
                      const Tab(
                        icon: Icon(Icons.psychology, size: 14), // Reduced icon size
                        text: 'LUMARA',
                      ),
                    const Tab(
                      icon: Icon(Icons.settings, size: 14), // Reduced icon size
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
                children: AppFlags.isLumaraEnabled
                    ? [
                        // Timeline tab
                        const TimelineView(),
                        // LUMARA tab
                        BlocProvider<LumaraAssistantCubit>.value(
                          value: _lumaraCubit!,
                          child: const LumaraAssistantScreen(),
                        ),
                        // Settings placeholder (will navigate instead)
                        const SizedBox.shrink(),
                      ]
                    : [
                        // Timeline tab only
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

