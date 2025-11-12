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

  @override
  void initState() {
    super.initState();
    // Tab controller length: Timeline + LUMARA (if enabled) = 1 or 2
    final tabCount = AppFlags.isLumaraEnabled ? 2 : 1;
    _tabController = TabController(length: tabCount, vsync: this);
    
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
                ],
              ),
            ),
            // Tab bar view content
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: AppFlags.isLumaraEnabled
                    ? [
                        // Timeline tab
                        const TimelineView(),
                        // LUMARA tab
                        BlocProvider<LumaraAssistantCubit>.value(
                          value: _lumaraCubit!,
                          child: const LumaraAssistantScreen(),
                        ),
                      ]
                    : [
                        // Timeline tab only
                        const TimelineView(),
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

