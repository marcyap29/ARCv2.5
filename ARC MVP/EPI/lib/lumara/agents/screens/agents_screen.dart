import 'package:flutter/material.dart';
import 'package:my_app/arc/chat/ui/lumara_settings_screen.dart';
import 'package:my_app/arc/chat/ui/research_screen.dart';
import 'package:my_app/arc/chat/ui/writing_screen.dart';
import 'package:my_app/lumara/agents/services/agents_connection_service.dart';
import 'package:my_app/shared/app_colors.dart';

/// Main Agents screen: single list of agents with connection status.
/// Each card shows Connected/Not connected and one-tap Use or Connect.
class AgentsScreen extends StatefulWidget {
  const AgentsScreen({super.key});

  @override
  State<AgentsScreen> createState() => _AgentsScreenState();
}

class _AgentsScreenState extends State<AgentsScreen> {
  Map<String, AgentConnectionState> _connectionStates = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _refreshConnections();
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
        title: Text(
          'Agents',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
                color: kcPrimaryTextColor,
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
                  _AgentConnectionCard(
                    icon: Icons.edit_note,
                    title: 'Writing',
                    subtitle: 'LinkedIn, Substack, technical docs in your voice',
                    state: _connectionStates[AgentsConnectionService.writingAgentId],
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
                ],
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
  final VoidCallback onUse;
  final VoidCallback onConnect;

  const _AgentConnectionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.state,
    required this.onUse,
    required this.onConnect,
  });

  @override
  Widget build(BuildContext context) {
    final isConnected = state?.isConnected ?? false;

    return Card(
      margin: EdgeInsets.zero,
      color: kcSurfaceAltColor,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
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
                _ConnectionChip(connected: isConnected),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (isConnected)
                  FilledButton.icon(
                    onPressed: onUse,
                    icon: const Icon(Icons.open_in_new, size: 18),
                    label: const Text('Use'),
                    style: FilledButton.styleFrom(
                      backgroundColor: kcPrimaryColor,
                      foregroundColor: Colors.white,
                    ),
                  )
                else
                  OutlinedButton.icon(
                    onPressed: onConnect,
                    icon: const Icon(Icons.settings, size: 18),
                    label: const Text('Connect'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: kcPrimaryColor,
                      side: BorderSide(color: kcPrimaryColor),
                    ),
                  ),
              ],
            ),
            if (!isConnected && state?.message != null) ...[
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
