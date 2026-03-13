import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:my_app/arc/agents/drafts/agent_draft.dart';
import 'package:my_app/arc/agents/drafts/draft_repository.dart';
import 'package:my_app/arc/agents/drafts/new_draft_screen.dart';
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

class _AgentsScreenState extends State<AgentsScreen> {
  Map<String, AgentConnectionState> _connectionStates = {};
  bool _loading = true;
  bool _userToggleWriting = false;
  bool _userToggleResearch = false;

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
    return DefaultTabController(
      length: 3,
      child: Scaffold(
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
          bottom: TabBar(
            labelColor: kcPrimaryColor,
            unselectedLabelColor: Theme.of(context).colorScheme.onSurfaceVariant,
            tabs: const [
              Tab(text: 'Agents'),
              Tab(text: 'Drafts'),
              Tab(text: 'Published'),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _loading ? null : _refreshConnections,
              tooltip: 'Refresh connection status',
            ),
          ],
        ),
        body: TabBarView(
          children: [
            _loading
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
                          title: 'Writer',
                          subtitle: 'LinkedIn, Substack, technical docs in your voice',
                          state: _connectionStates[AgentsConnectionService.writingAgentId],
                          useButtonLabel: 'Go to Writer',
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
                        _VisionOcrCard(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute<void>(
                                builder: (context) => const VisionOcrScreen(),
                              ),
                            );
                          },
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
            const _DraftsTab(),
            const _ArchiveTab(),
          ],
        ),
      ),
    );
  }
}

/// Tab that lists saved agent drafts with Copy and actions.
class _DraftsTab extends StatefulWidget {
  const _DraftsTab();

  @override
  State<_DraftsTab> createState() => _DraftsTabState();
}

class _DraftsTabState extends State<_DraftsTab> {
  Future<List<AgentDraft>> _loadDrafts() =>
      DraftRepository.instance.getAllDrafts();

  void _refresh() => setState(() {});

  Future<void> _openNewDraft() async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (context) => const NewDraftScreen()),
    );
    if (saved == true) _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<AgentDraft>>(
      future: _loadDrafts(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final drafts = snapshot.data ?? [];
        return RefreshIndicator(
          onRefresh: () async => _refresh(),
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: OutlinedButton.icon(
                    onPressed: _openNewDraft,
                    icon: const Icon(Icons.add, size: 20),
                    label: const Text('Write your own draft'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      foregroundColor: kcPrimaryColor,
                    ),
                  ),
                ),
              ),
              if (drafts.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.description_outlined, size: 64, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text(
                          'No drafts yet',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(color: kcPrimaryTextColor),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Drafts from chat or the Writer will appear here.\nUse the button above to paste your own.',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: kcSecondaryColor),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => _DraftCard(
                        draft: drafts[index],
                        onDeleted: _refresh,
                        onUpdated: _refresh,
                        onArchived: _refresh,
                      ),
                      childCount: drafts.length,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _DraftCard extends StatelessWidget {
  final AgentDraft draft;
  final VoidCallback onDeleted;
  final VoidCallback onUpdated;
  final VoidCallback? onArchived;

  const _DraftCard({
    required this.draft,
    required this.onDeleted,
    required this.onUpdated,
    this.onArchived,
  });

  String _formatDate(DateTime d) =>
      DateFormat('MMM d, y • h:mm a').format(d);

  @override
  Widget build(BuildContext context) {
    final voiceMatch = draft.metadata['voiceMatch'];
    final themeMatch = draft.metadata['themeMatch'];
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: kcSurfaceAltColor,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Icon(
          draft.agentType == AgentType.writing ? Icons.edit_note : Icons.search,
          color: kcPrimaryColor,
          size: 28,
        ),
        title: Text(
          draft.title,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: kcPrimaryTextColor,
              ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              _formatDate(draft.createdAt),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            if (voiceMatch != null || themeMatch != null) ...[
              const SizedBox(height: 2),
              Text(
                'Voice: ${voiceMatch ?? '—'}% • Theme: ${themeMatch ?? '—'}%',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.green[700],
                      fontSize: 12,
                    ),
              ),
            ],
          ],
        ),
        trailing: PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert),
          onSelected: (value) => _handleAction(context, value),
          itemBuilder: (context) => [
            const PopupMenuItem(value: 'view', child: Text('View / Edit')),
            const PopupMenuItem(value: 'copy', child: Text('Copy to clipboard')),
            if (onArchived != null)
              const PopupMenuItem(value: 'archive', child: Text('Archive')),
            const PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: Colors.red))),
          ],
        ),
        onTap: () => _openViewEdit(context),
      ),
    );
  }

  Future<void> _openViewEdit(BuildContext context) async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (context) => NewDraftScreen(draft: draft)),
    );
    if (saved == true && context.mounted) onUpdated();
  }

  Future<void> _handleAction(BuildContext context, String value) async {
    if (value == 'view') {
      _openViewEdit(context);
    } else if (value == 'copy') {
      _copyAndSnackbar(context);
    } else if (value == 'archive' && onArchived != null) {
      await DraftRepository.instance.archiveDraft(draft.id);
      onArchived!();
    } else if (value == 'delete') {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Delete draft?'),
          content: Text('Delete "${draft.title}"? This cannot be undone.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Delete'),
            ),
          ],
        ),
      );
      if (ok == true && context.mounted) {
        await DraftRepository.instance.deleteDraft(draft.id);
        onDeleted();
      }
    }
  }

  void _copyAndSnackbar(BuildContext context) {
    Clipboard.setData(ClipboardData(text: draft.content));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Copied to clipboard')),
    );
  }
}

/// Tab that lists published drafts. Published entries are saved to the timeline.
class _ArchiveTab extends StatefulWidget {
  const _ArchiveTab();

  @override
  State<_ArchiveTab> createState() => _ArchiveTabState();
}

class _ArchiveTabState extends State<_ArchiveTab> {
  Future<List<AgentDraft>> _loadArchived() =>
      DraftRepository.instance.getArchivedDrafts();

  void _refresh() => setState(() {});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<AgentDraft>>(
      future: _loadArchived(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final archived = snapshot.data ?? [];
        if (archived.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.publish_outlined, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  'No published entries',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(color: kcPrimaryTextColor),
                ),
                const SizedBox(height: 8),
                Text(
                  'Published entries are saved to the timeline. Move drafts here from the Drafts tab.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: kcSecondaryColor),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }
        return RefreshIndicator(
          onRefresh: () async => _refresh(),
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: archived.length,
            itemBuilder: (context, index) {
              final draft = archived[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                color: kcSurfaceAltColor,
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: Icon(
                    draft.agentType == AgentType.writing ? Icons.edit_note : Icons.search,
                    color: kcPrimaryColor,
                    size: 28,
                  ),
                  title: Text(
                    draft.title,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: kcPrimaryTextColor,
                        ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    DateFormat('MMM d, y • h:mm a').format(draft.archivedAt ?? draft.createdAt),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                  trailing: PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert),
                    onSelected: (value) => _handleArchiveAction(context, value, draft),
                    itemBuilder: (context) => [
                      const PopupMenuItem(value: 'copy', child: Text('Copy to clipboard')),
                      const PopupMenuItem(value: 'unarchive', child: Text('Restore to Drafts')),
                      const PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: Colors.red))),
                    ],
                  ),
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: draft.content));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Copied to clipboard')),
                    );
                  },
                ),
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _handleArchiveAction(BuildContext context, String value, AgentDraft draft) async {
    if (value == 'copy') {
      Clipboard.setData(ClipboardData(text: draft.content));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Copied to clipboard')),
      );
    } else if (value == 'unarchive') {
      await DraftRepository.instance.unarchiveDraft(draft.id);
      _refresh();
    } else if (value == 'delete') {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Delete draft?'),
          content: Text('Permanently delete "${draft.title}"?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Delete'),
            ),
          ],
        ),
      );
      if (ok == true && context.mounted) {
        await DraftRepository.instance.deleteDraft(draft.id);
        _refresh();
      }
    }
  }
}

/// Card that opens the Vision/Scanning screen.
class _VisionOcrCard extends StatelessWidget {
  final VoidCallback onTap;

  const _VisionOcrCard({required this.onTap});

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
                child: const Icon(Icons.document_scanner, color: kcPrimaryColor, size: 26),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Vision/Scanning',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: kcPrimaryTextColor,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Extract text or describe images (Vision API + Gemini)',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: kcSecondaryColor),
            ],
          ),
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
                if (showConnectToggle && onToggleChanged != null)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Switch(
                      value: userToggleOn,
                      onChanged: onToggleChanged,
                      activeTrackColor: kcPrimaryColor.withOpacity(0.5),
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
                    label: Text(useButtonLabel),
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
                      side: const BorderSide(color: kcPrimaryColor),
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
