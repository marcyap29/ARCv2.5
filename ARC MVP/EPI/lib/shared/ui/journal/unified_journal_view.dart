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
    // Tab controller length depends on whether LUMARA is enabled
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
                tabs: [
                  const Tab(
                    icon: Icon(Icons.timeline, size: 24),
                    text: 'Timeline',
                  ),
                  if (AppFlags.isLumaraEnabled)
                    const Tab(
                      icon: Icon(Icons.psychology, size: 24),
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
      // Floating action button for new journal entry
      floatingActionButton: AppFlags.isLumaraEnabled
          ? FloatingActionButton(
              onPressed: () async {
                // Clear any existing session cache to ensure fresh start
                await JournalSessionCache.clearSession();
                
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const JournalScreen(),
                  ),
                );
              },
              backgroundColor: Colors.purple,
              child: const Icon(Icons.add, color: Colors.white),
            )
          : null,
    );
  }
}

