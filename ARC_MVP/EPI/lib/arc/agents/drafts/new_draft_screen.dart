// lib/arc/agents/drafts/new_draft_screen.dart
// Manual draft creation: paste or type content for use as swap by Writing/Research agents.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:my_app/arc/agents/drafts/agent_draft.dart';
import 'package:my_app/arc/agents/drafts/draft_repository.dart';
import 'package:my_app/shared/app_colors.dart';

class NewDraftScreen extends StatefulWidget {
  /// When set, opens in view/edit mode for this draft; otherwise create new.
  final AgentDraft? draft;

  const NewDraftScreen({super.key, this.draft});

  @override
  State<NewDraftScreen> createState() => _NewDraftScreenState();
}

class _NewDraftScreenState extends State<NewDraftScreen> {
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  bool _saving = false;

  bool get _isEditing => widget.draft != null;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    final d = widget.draft;
    if (d != null) {
      _titleController.text = d.title;
      _contentController.text = d.content;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    super.dispose();
  }

  Future<void> _save() async {
    final content = _contentController.text.trim();
    if (content.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add some content to save a draft')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final title = _titleController.text.trim();
      if (_isEditing) {
        await DraftRepository.instance.updateDraft(
          draftId: widget.draft!.id,
          content: content,
          title: title.isNotEmpty ? title : widget.draft!.title,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Draft updated.')),
          );
          Navigator.pop(context, true);
        }
      } else {
        await DraftRepository.instance.saveDraft(
          agentType: AgentType.writing,
          content: content,
          originalPrompt: title.isNotEmpty ? title : 'Manual draft',
          metadata: {'source': 'manual'},
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Draft saved. Agents can use it as reference.')),
          );
          Navigator.pop(context, true);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kcBackgroundColor,
      appBar: AppBar(
        backgroundColor: kcBackgroundColor,
        elevation: 0,
        title: Text(
          _isEditing ? 'Edit draft' : 'New draft',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
                color: kcPrimaryTextColor,
              ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _isEditing
                  ? 'Edit title and content. Changes are saved when you tap Save.'
                  : 'Add a draft for agents to use as reference (e.g. paste from Substack, notes).',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: kcSecondaryColor),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _titleController,
              decoration: InputDecoration(
                labelText: 'Title (optional)',
                hintText: 'e.g. Substack post draft',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: kcSurfaceAltColor,
              ),
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _contentController,
              decoration: InputDecoration(
                labelText: 'Content',
                hintText: 'Paste or type your draft here...',
                alignLabelWithHint: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: kcSurfaceAltColor,
              ),
              maxLines: 16,
              minLines: 8,
              textCapitalization: TextCapitalization.sentences,
            ),
          ],
        ),
      ),
    );
  }
}
