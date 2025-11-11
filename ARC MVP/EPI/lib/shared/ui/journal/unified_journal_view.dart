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
import 'package:my_app/ui/journal/journal_screen.dart';
import 'package:my_app/services/journal_session_cache.dart';
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

  @override
  void initState() {
    super.initState();
    // Tab controller length: Timeline + LUMARA (if enabled) + Settings = 2 or 3
    final tabCount = AppFlags.isLumaraEnabled ? 3 : 2;
    _tabController = TabController(length: tabCount, vsync: this);
    _tabController.addListener(() {
      // Navigate to Settings when Settings tab is selected
      if (_tabController.index == tabCount - 1) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const SettingsView(),
          ),
        ).then((_) {
          // Return to previous tab after Settings is closed
          if (mounted) {
            _tabController.animateTo(_previousIndex);
          }
        });
      } else {
        // Track previous index (excluding Settings tab)
        _previousIndex = _tabController.index;
      }
    });
    
    // Initialize LUMARA cubit if enabled
    if (AppFlags.isLumaraEnabled) {
      _lumaraCubit = LumaraAssistantCubit(
        contextProvider: ContextProvider(LumaraScope.defaultScope),
      );
      _lumaraCubit!.initializeLumara();
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _lumaraCubit?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Tab bar for Timeline and LUMARA
            Container(
              color: kcBackgroundColor,
              child: TabBar(
                controller: _tabController,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.grey,
                indicatorColor: Colors.purple,
                indicatorWeight: 3,
                labelPadding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                labelStyle: const TextStyle(fontSize: 12),
                unselectedLabelStyle: const TextStyle(fontSize: 12),
                tabs: [
                  const Tab(
                    icon: Icon(Icons.timeline, size: 18),
                    text: 'Timeline',
                  ),
                  if (AppFlags.isLumaraEnabled)
                    const Tab(
                      icon: Icon(Icons.psychology, size: 18),
                      text: 'LUMARA',
                    ),
                  const Tab(
                    icon: Icon(Icons.settings, size: 18),
                    text: 'Settings',
                  ),
                ],
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

