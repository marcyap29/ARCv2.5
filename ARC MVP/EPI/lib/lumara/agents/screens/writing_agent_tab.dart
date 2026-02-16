import 'package:flutter/material.dart';
import 'package:my_app/lumara/agents/models/content_draft.dart';
import 'package:my_app/lumara/agents/services/agents_chronicle_service.dart';
import 'package:my_app/lumara/agents/widgets/content_draft_card.dart';
import 'package:my_app/arc/chat/ui/writing_screen.dart';
import 'package:my_app/shared/app_colors.dart';

class WritingAgentTab extends StatelessWidget {
  const WritingAgentTab({super.key});

  Future<List<ContentDraft>> _loadDrafts() async {
    final userId = await AgentsChronicleService.instance.getCurrentUserId();
    return AgentsChronicleService.instance.getContentDrafts(userId);
  }

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
              );
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

  Widget _buildDraftList(BuildContext context, List<ContentDraft> drafts) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
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
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<ContentDraft>>(
      future: _loadDrafts(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return _buildEmptyState(context);
        }

        return _buildDraftList(context, snapshot.data!);
      },
    );
  }
}
