// lib/lumara/agents/writing/draft_editor_screen.dart
//
// Phase 5b: Inline editing, format badge, Regenerate / Copy / Save to Outputs,
// version history, character or word count.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gap/gap.dart';

import 'package:my_app/arc/outputs/output_tagging.dart';
import 'package:my_app/arc/outputs/outputs_chronicle_service.dart';
import 'package:my_app/arc/outputs/outputs_models.dart';
import 'package:my_app/arc/outputs/outputs_repository.dart';
import 'package:my_app/lumara/agents/writing/pipeline_draft.dart';
import 'package:my_app/lumara/social/late_profile_service.dart';
import 'package:my_app/lumara/social/publish_sheet.dart';
import 'package:my_app/lumara/social/social_accounts_screen.dart';
import 'package:my_app/services/swarmspace/prism_service.dart';

class DraftEditorScreen extends StatefulWidget {
  const DraftEditorScreen({
    super.key,
    required this.draft,
    this.onRegenerate,
  });

  final PipelineDraft draft;
  /// When set, Regenerate runs the pipeline and updates this draft (appends current body to versions).
  final Future<PipelineDraft?> Function(PipelineDraft current)? onRegenerate;

  @override
  State<DraftEditorScreen> createState() => _DraftEditorScreenState();
}

class _DraftEditorScreenState extends State<DraftEditorScreen> {
  late TextEditingController _bodyController;
  late PipelineDraft _draft;
  bool _saving = false;
  bool _regenerating = false;
  bool _publishing = false;

  static const int _blueskyLimit = 300;
  static const int _threadsLimit = 500;

  @override
  void initState() {
    super.initState();
    _draft = widget.draft;
    _bodyController = TextEditingController(text: widget.draft.body);
  }

  @override
  void dispose() {
    _bodyController.dispose();
    super.dispose();
  }

  int? get _charLimit {
    switch (_draft.format) {
      case WritingFormat.bluesky:
        return _blueskyLimit;
      case WritingFormat.threads:
        return _threadsLimit;
      default:
        return null;
    }
  }

  void _copy() {
    final text = _bodyController.text;
    if (text.isNotEmpty) {
      Clipboard.setData(ClipboardData(text: text));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Copied')),
      );
    }
  }

  void _showNoAccountsSheet() {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Connect a social account first',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'Open Settings to connect LinkedIn, Bluesky, Threads, Twitter/X and more.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const SocialAccountsScreen(),
                    ),
                  );
                },
                icon: const Icon(Icons.settings, size: 18),
                label: const Text('Go to Settings'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _addPublishedTagBestEffort() async {
    try {
      final items = await OutputsRepository.instance.getItems();
      final draft = _draft.copyWith(body: _bodyController.text);
      final matches = items
          .where((i) =>
              i.agentKey == 'writing' &&
              i.folderKey == draft.folderKey &&
              i.title == draft.topic)
          .toList();
      if (matches.isEmpty) return;
      matches.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      final item = matches.first;
      final tags = List<String>.from(item.userTags);
      if (tags.contains('published')) return;
      tags.add('published');
      await OutputsRepository.instance.updateUserTags(item.id, tags);
    } catch (_) {
      // best-effort: do not surface
    }
  }

  Future<void> _publish() async {
    List<SocialAccount> accounts;
    try {
      accounts = await LateProfileService.instance.getConnectedAccounts(context);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to load connected accounts')),
        );
      }
      return;
    }
    if (!mounted) return;
    if (accounts.isEmpty) {
      _showNoAccountsSheet();
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => PublishSheet(
        draftBody: _bodyController.text,
        format: _draft.format,
        accounts: accounts,
        onPublish: (result) async {
          if (!mounted) return;
          setState(() => _publishing = true);
          try {
            final params = <String, dynamic>{
              '_action': 'publish',
              'content': _bodyController.text,
              'platforms': result.accounts
                  .map((a) => {'platform': a.platform, 'accountId': a.id})
                  .toList(),
            };
            if (result.scheduledFor != null) {
              params['scheduledFor'] = result.scheduledFor!.toUtc().toIso8601String();
            }
            final prismResult = await PrismService.instance.authoriseAndCall(
              pluginId: 'social-publisher',
              params: params,
              context: context,
            );
            if (!mounted) return;
            if (prismResult.isDenied) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Publish cancelled')),
              );
              return;
            }
            final res = prismResult.result;
            if (res == null || !res.success) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(res?.error ?? 'Publish failed'),
                ),
              );
              return;
            }
            final status = res.data?['status'] as String?;
            if (status == 'scheduled') {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Scheduled!')),
              );
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Published!')),
              );
            }
            _addPublishedTagBestEffort();
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Publish failed: $e')),
              );
            }
          } finally {
            if (mounted) setState(() => _publishing = false);
          }
        },
      ),
    );
  }

  Future<void> _saveToOutputs() async {
    setState(() => _saving = true);
    try {
      final draft = _draft.copyWith(body: _bodyController.text);
      final folderKey = draft.folderKey;
      final item = OutputItem(
        id: '',
        agentKey: 'writing',
        folderKey: folderKey,
        title: draft.topic,
        createdAt: DateTime.now(),
        contentJson: jsonEncode(draft.toJson()),
        autoTags: pathTags('writing', folderKey),
        userTags: [],
      );
      final saved = await OutputsRepository.instance.save(item);
      OutputsChronicleService.instance.onOutputSaved(
        type: 'output_created',
        item: saved,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Saved to Outputs')),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showVersionHistory() {
    if (_draft.versions.isEmpty) return;
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Version history',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            ..._draft.versions.asMap().entries.map((e) {
              final preview = e.value.length > 80 ? '${e.value.substring(0, 80)}...' : e.value;
              return ListTile(
                title: Text('Version ${e.key + 1}'),
                subtitle: Text(preview),
                onTap: () {
                  _bodyController.text = e.value;
                  setState(() {});
                  Navigator.pop(ctx);
                },
              );
            }),
            const Gap(16),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final charLimit = _charLimit;
    final charCount = _bodyController.text.length;
    final overLimit = charLimit != null && charCount > charLimit;
    final wordCount = _bodyController.text.trim().isEmpty
        ? 0
        : _bodyController.text.trim().split(RegExp(r'\s+')).length;

    return Scaffold(
      appBar: AppBar(
        title: Text(_draft.topic),
        actions: [
          if (_draft.versions.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.history),
              onPressed: _showVersionHistory,
              tooltip: 'Version history',
            ),
          TextButton.icon(
            onPressed: _saving ? null : _saveToOutputs,
            icon: _saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save, size: 18),
            label: Text(_saving ? 'Saving...' : 'Save'),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Row(
              children: [
                Chip(
                  label: Text(_formatLabel(_draft.format)),
                  backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                ),
              ],
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: TextField(
                  controller: _bodyController,
                  textCapitalization: TextCapitalization.sentences,
                  maxLines: null,
                  expands: true,
                  textAlignVertical: TextAlignVertical.top,
                  decoration: const InputDecoration(
                    hintText: 'Edit your draft...',
                    border: OutlineInputBorder(),
                    alignLabelWithHint: true,
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ),
          ),
          if (charLimit != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                '$charCount / $charLimit',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: overLimit ? Theme.of(context).colorScheme.error : null,
                    ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                '$wordCount words',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          const Gap(8),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  OutlinedButton.icon(
                    onPressed: _regenerating || widget.onRegenerate == null
                        ? null
                        : () async {
                            setState(() => _regenerating = true);
                            try {
                              final next = await widget.onRegenerate!(_draft);
                              if (next != null && mounted) {
                                setState(() {
                                  _draft = next;
                                  _bodyController.text = next.body;
                                });
                              }
                            } finally {
                              if (mounted) setState(() => _regenerating = false);
                            }
                          },
                    icon: _regenerating
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.refresh, size: 16),
                    label: Text('Regenerate', style: Theme.of(context).textTheme.labelSmall),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: _copy,
                    icon: const Icon(Icons.copy, size: 16),
                    label: Text('Copy', style: Theme.of(context).textTheme.labelSmall),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: _publishing ? null : _publish,
                    icon: _publishing
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.publish, size: 16),
                    label: Text('Publish', style: Theme.of(context).textTheme.labelSmall),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                  Tooltip(
                    message: 'Save to Outputs',
                    child: FilledButton.icon(
                      onPressed: _saving ? null : _saveToOutputs,
                      icon: const Icon(Icons.save, size: 16),
                      label: Text('Save', style: Theme.of(context).textTheme.labelSmall),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatLabel(WritingFormat format) {
    switch (format) {
      case WritingFormat.article:
        return 'Article';
      case WritingFormat.linkedin:
        return 'LinkedIn';
      case WritingFormat.substack:
        return 'Substack';
      case WritingFormat.bluesky:
        return 'Bluesky';
      case WritingFormat.threads:
        return 'Threads';
    }
  }

}
