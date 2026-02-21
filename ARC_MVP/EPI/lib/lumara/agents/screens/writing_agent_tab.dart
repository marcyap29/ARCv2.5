import 'package:flutter/material.dart';
import 'package:my_app/arc/chat/ui/writing_screen.dart';
import 'package:my_app/lumara/agents/models/content_draft.dart';
import 'package:my_app/lumara/agents/services/agents_chronicle_service.dart';
import 'package:my_app/lumara/agents/widgets/content_draft_card.dart';
import 'package:my_app/shared/app_colors.dart';

class WritingAgentTab extends StatefulWidget {
  const WritingAgentTab({super.key});

  @override
  State<WritingAgentTab> createState() => _WritingAgentTabState();
}

class _WritingAgentTabState extends State<WritingAgentTab> {
  Future<List<ContentDraft>> _loadDrafts() async {
    final userId = await AgentsChronicleService.instance.getCurrentUserId();
    return AgentsChronicleService.instance.getContentDrafts(userId);
  }

  void _refresh() => setState(() {});

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.edit_off,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No content drafts yet',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: kcPrimaryTextColor,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Ask LUMARA to write content for you',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: kcSecondaryColor,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (context) => const WritingScreen(),
                ),
              ).then((_) => _refresh());
            },
            icon: const Icon(Icons.edit_note),
            label: const Text('Open Writing Agent'),
            style: ElevatedButton.styleFrom(
              backgroundColor: kcPrimaryColor,
              foregroundColor: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.lightbulb_outline),
            label: const Text('See Examples'),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title, List<ContentDraft> drafts) {
    if (drafts.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: kcSecondaryColor,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: drafts.length,
          itemBuilder: (context, index) {
            return ContentDraftCard(
              draft: drafts[index],
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (context) => const WritingScreen(),
                  ),
                ).then((_) => _refresh());
              },
              onMarkFinished: () => _markFinished(drafts[index]),
              onArchive: () => _archive(drafts[index]),
              onUnarchive: () => _unarchive(drafts[index]),
              onDelete: () => _delete(drafts[index]),
              onChanged: _refresh,
            );
          },
        ),
      ],
    );
  }

  Future<void> _markFinished(ContentDraft draft) async {
    final userId = await AgentsChronicleService.instance.getCurrentUserId();
    await AgentsChronicleService.instance.markDraftFinished(userId, draft.id);
    _refresh();
  }

  Future<void> _archive(ContentDraft draft) async {
    final userId = await AgentsChronicleService.instance.getCurrentUserId();
    await AgentsChronicleService.instance.archiveDraft(userId, draft.id);
    _refresh();
  }

  Future<void> _unarchive(ContentDraft draft) async {
    final userId = await AgentsChronicleService.instance.getCurrentUserId();
    await AgentsChronicleService.instance.unarchiveDraft(userId, draft.id);
    _refresh();
  }

  Future<void> _delete(ContentDraft draft) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete draft?'),
        content: Text('Delete "${draft.title}"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final userId = await AgentsChronicleService.instance.getCurrentUserId();
    await AgentsChronicleService.instance.deleteDraft(userId, draft.id);
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<ContentDraft>>(
      future: _loadDrafts(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final all = snapshot.data ?? [];
        if (all.isEmpty) return _buildEmptyState(context);

        final active = all.where((d) => !d.archived).toList();
        final archived = all.where((d) => d.archived).toList();

        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSection('Active', active),
              _buildSection('Archived', archived),
            ],
          ),
        );
      },
    );
  }
}
