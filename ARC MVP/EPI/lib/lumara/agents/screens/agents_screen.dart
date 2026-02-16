import 'package:flutter/material.dart';
import 'package:my_app/lumara/agents/screens/research_agent_tab.dart';
import 'package:my_app/lumara/agents/screens/writing_agent_tab.dart';
import 'package:my_app/shared/app_colors.dart';

/// Main Agents workspace: sub-tabs for Research and Writing.
class AgentsScreen extends StatefulWidget {
  const AgentsScreen({super.key});

  @override
  State<AgentsScreen> createState() => _AgentsScreenState();
}

class _AgentsScreenState extends State<AgentsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kcBackgroundColor,
      appBar: AppBar(
        backgroundColor: kcBackgroundColor,
        elevation: 0,
        title: Text(
          'Agents',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
                color: kcPrimaryTextColor,
              ),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: kcPrimaryColor,
          unselectedLabelColor: kcSecondaryColor,
          indicatorColor: kcPrimaryColor,
          tabs: const [
            Tab(icon: Icon(Icons.search), text: 'Research'),
            Tab(icon: Icon(Icons.edit_note), text: 'Writing'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          ResearchAgentTab(),
          WritingAgentTab(),
        ],
      ),
    );
  }
}
