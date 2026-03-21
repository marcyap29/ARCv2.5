import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:my_app/arc/chat/ui/lumara_settings_screen.dart';
import 'package:my_app/arc/chat/ui/research_screen.dart';
import 'package:my_app/arc/chat/ui/writing_screen.dart';
import 'package:my_app/lumara/agents/screens/plugin_activity_screen.dart';
import 'package:my_app/lumara/agents/screens/plugin_catalog_screen.dart';
import 'package:my_app/lumara/agents/screens/vision_ocr_screen.dart';
import 'package:my_app/lumara/agents/widgets/agent_tip_banner.dart';
import 'package:my_app/services/swarmspace/agents_connection_service.dart';
import 'package:my_app/shared/app_colors.dart';
import 'package:my_app/shared/text_style.dart';
import 'package:my_app/shared/ui/home/home_cubit.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Main Agents screen: single list of agents with connection status.
/// Each card shows Connected/Not connected and one-tap Use or Connect.
class AgentsScreen extends StatefulWidget {
  const AgentsScreen({super.key});

  @override
  State<AgentsScreen> createState() => _AgentsScreenState();
}

const String _prefToggleWriting = 'agent_toggle_writing';
const String _prefToggleResearch = 'agent_toggle_research';
const String _prefToggleImageAnalyzer = 'agent_toggle_image_analyzer';

class _AgentsScreenState extends State<AgentsScreen> {
  Map<String, AgentConnectionState> _connectionStates = {};
  bool _loading = true;
  bool _userToggleWriting = false;
  bool _userToggleResearch = false;
  bool _userToggleImageAnalyzer = false;

  @override
  void initState() {
    super.initState();
    _refreshConnections();
    _loadTogglePrefs();
  }

  Future<void> _loadTogglePrefs() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _userToggleWriting = prefs.getBool(_prefToggleWriting) ?? false;
      _userToggleResearch = prefs.getBool(_prefToggleResearch) ?? false;
      _userToggleImageAnalyzer = prefs.getBool(_prefToggleImageAnalyzer) ?? false;
    });
  }

  Future<void> _setToggleWriting(bool value) async {
    setState(() => _userToggleWriting = value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefToggleWriting, value);
  }

  Future<void> _setToggleResearch(bool value) async {
    setState(() => _userToggleResearch = value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefToggleResearch, value);
  }

  Future<void> _setToggleImageAnalyzer(bool value) async {
    setState(() => _userToggleImageAnalyzer = value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefToggleImageAnalyzer, value);
  }

  Future<void> _refreshConnections() async {
    setState(() => _loading = true);
    final states = await AgentsConnectionService.instance.checkAllConnections();
    if (mounted) {
      setState(() {
        _connectionStates = states;
        _loading = false;
      });
    }
  }

  void _openConnectSettings() {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (context) => const LumaraSettingsScreen(),
      ),
    ).then((_) => _refreshConnections());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kcBackgroundColor,
      appBar: AppBar(
        backgroundColor: kcBackgroundColor,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: kcPrimaryTextColor),
        title: Text(
          'Agents',
          style: heading1Style(context).copyWith(
            color: kcPrimaryTextColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _refreshConnections,
            tooltip: 'Refresh connection status',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _refreshConnections,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  const AgentTipBanner(),
                  const SizedBox(height: 12),
                  _AgentConnectionCard(
                    icon: Icons.edit_note,
                    title: 'Writing',
                    subtitle: 'LinkedIn, Substack, technical docs in your voice',
                    state: _connectionStates[AgentsConnectionService.writingAgentId],
                    useButtonLabel: 'Go to Writing',
                    showConnectToggle: true,
                    userToggleOn: _userToggleWriting,
                    onToggleChanged: _setToggleWriting,
                    onUse: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (context) => const WritingScreen(),
                        ),
                      );
                    },
                    onConnect: _openConnectSettings,
                  ),
                  const SizedBox(height: 12),
                  _AgentConnectionCard(
                    icon: Icons.search,
                    title: 'Research',
                    subtitle: 'Deep research with sources and reports',
                    state: _connectionStates[AgentsConnectionService.researchAgentId],
                    useButtonLabel: 'Go to Research',
                    showConnectToggle: true,
                    userToggleOn: _userToggleResearch,
                    onToggleChanged: _setToggleResearch,
                    onUse: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (context) => const ResearchScreen(),
                        ),
                      );
                    },
                    onConnect: _openConnectSettings,
                  ),
                  const SizedBox(height: 12),
                  _AgentConnectionCard(
                    icon: Icons.image_search_outlined,
                    title: 'Image Analysis',
                    subtitle:
                        'Ask questions about photos—species, places, objects—or extract text. Powered by vision models.',
                    state: _connectionStates[AgentsConnectionService.imageAnalyzerAgentId],
                    useButtonLabel: 'Open Image Analyzer',
                    showConnectToggle: true,
                    userToggleOn: _userToggleImageAnalyzer,
                    onToggleChanged: _setToggleImageAnalyzer,
                    onUse: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (context) => const VisionOcrScreen(),
                        ),
                      );
                    },
                    onConnect: _openConnectSettings,
                  ),
                  const SizedBox(height: 12),
                  _ActivityCard(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (context) => const PluginActivityScreen(),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  _CapabilitiesCatalogCard(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (context) => const PluginCatalogScreen(),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  _AgentConnectionCard(
                    icon: Icons.folder_outlined,
                    title: 'Outputs',
                    subtitle: 'View and manage all agent outputs',
                    state: AgentConnectionState(
                      agentId: 'outputs',
                      status: AgentConnectionStatus.connected,
                    ),
                    useButtonLabel: 'Go to Outputs',
                    onUse: () {
                      context.read<HomeCubit>().changeTab(2);
                    },
                    onConnect: _openConnectSettings,
                  ),
                ],
              ),
            ),
    );
  }
}

/// Card that opens the Plugin Activity screen (PRISM Phase 1).
class _ActivityCard extends StatelessWidget {
  final VoidCallback onTap;

  const _ActivityCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      color: kcSurfaceAltColor,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: kcPrimaryColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.history, color: kcPrimaryColor, size: 26),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Plugin Activity',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: kcPrimaryTextColor,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Recent SwarmSpace plugin calls and consent',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: kcSecondaryTextColor),
            ],
          ),
        ),
      ),
    );
  }
}

/// Card that opens the SwarmSpace plugin catalog.
class _CapabilitiesCatalogCard extends StatelessWidget {
  final VoidCallback onTap;

  const _CapabilitiesCatalogCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      color: kcSurfaceAltColor,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: kcPrimaryColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.extension, color: kcPrimaryColor, size: 26),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'All SwarmSpace Capabilities',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: kcPrimaryTextColor,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Weather, currency, news, search & more — view catalog',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: kcSecondaryTextColor),
            ],
          ),
        ),
      ),
    );
  }
}

class _AgentConnectionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final AgentConnectionState? state;
  final String useButtonLabel;
  final bool showConnectToggle;
  final bool userToggleOn;
  final void Function(bool)? onToggleChanged;
  final VoidCallback onUse;
  final VoidCallback onConnect;

  const _AgentConnectionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.state,
    this.useButtonLabel = 'Use',
    this.showConnectToggle = false,
    this.userToggleOn = false,
    this.onToggleChanged,
    required this.onUse,
    required this.onConnect,
  });

  @override
  Widget build(BuildContext context) {
    final serviceConnected = state?.isConnected ?? false;
    final isConnected = serviceConnected || userToggleOn;

    final connectGrayed = !isConnected && !userToggleOn;

    return Card(
      margin: EdgeInsets.zero,
      color: kcSurfaceAltColor,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: kcPrimaryColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: kcPrimaryColor, size: 26),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: kcPrimaryTextColor,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _ConnectionChip(connected: isConnected),
            if (showConnectToggle && onToggleChanged != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Switch(
                    value: userToggleOn,
                    onChanged: onToggleChanged,
                    activeTrackColor: kcPrimaryColor.withOpacity(0.5),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Use this agent',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (isConnected)
                  FilledButton.icon(
                    onPressed: onUse,
                    icon: const Icon(Icons.open_in_new, size: 18),
                    label: Text(useButtonLabel),
                    style: FilledButton.styleFrom(
                      backgroundColor: kcPrimaryColor,
                      foregroundColor: Colors.white,
                    ),
                  )
                else
                  OutlinedButton.icon(
                    onPressed: connectGrayed ? null : onConnect,
                    icon: Icon(Icons.settings, size: 18, color: connectGrayed ? Colors.grey : kcPrimaryColor),
                    label: const Text('Connect'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: connectGrayed ? Colors.grey : kcPrimaryColor,
                      side: BorderSide(color: connectGrayed ? Colors.grey : kcPrimaryColor),
                    ),
                  ),
              ],
            ),
            if (!serviceConnected && state?.message != null) ...[
              const SizedBox(height: 8),
              Text(
                state!.message!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontStyle: FontStyle.italic,
                    ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ConnectionChip extends StatelessWidget {
  final bool connected;

  const _ConnectionChip({required this.connected});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: connected
            ? Colors.green.withOpacity(0.15)
            : Colors.grey.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            connected ? Icons.check_circle : Icons.cloud_off,
            size: 16,
            color: connected ? Colors.green : Colors.grey,
          ),
          const SizedBox(width: 6),
          Text(
            connected ? 'Connected' : 'Not connected',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: connected ? Colors.green : Colors.grey,
                  fontWeight: FontWeight.w500,
                ),
          ),
        ],
      ),
    );
  }
}
